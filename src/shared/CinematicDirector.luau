--[[
	Pure cinematic director: decides, for one rendered frame, where both fighters stand, which
	pose they hold, which camera shot is used and which effects / overlays are requested.
	No Roblox API and no require, so every cinematic can be replayed and checked offline
	(tests/CinematicDirector.test.luau). The client CinematicController executes the result.

	Points are rig parts (Head, UpperTorso, RightHand, LeftFoot...) plus an offset, resolved by
	the client after the rigs are placed, so framing works on KAI and on any Roblox avatar.
	Vectors are plain tables { x, y, z }; colours are hex strings.

	frame = {
		shot = { name, from, to, fov, roll, focus },  -- points: { slot, part, offset } or { position }
		grade = { crimson, void, mono },              -- colour grading switches
		kanjiBack = text?, title = { text, color, sub }?, hideTitle = bool?,
		fx = { { key, kind, ... } },                  -- effect requests, played once per key
		aura = slot?, shake = number?, fade = bool?,
	}
]]
local Director = {}

local RED = "E0102B"
Director.KO_SCENE = 200 -- ticks of the K.O. scene (same as the FINAL FINISH extension)
-- Rush poses cycle through the active frames of the normals while KAI blinks around the target.
local RUSH = { "Jab", "Cross", "Kick", "Elbow", "AirKick", "SpinKick", "BodyBlow", "Uppercut", "AirKick2", "KiFlurry" }
Director.STYLE_COLORS = {
	TORNADE = "FF2A3D", RAFALE = "FF7A2A", DRAGON = "FF2A3D",
	FOUDRE = "8FD8FF", MUR = "FF2A3D", LUNE = "FFE9B0",
}

local function v(x, y, z)
	return { x = x, y = y, z = z or 0 }
end

local function P(slot, part, offset)
	return { slot = slot, part = part, offset = offset or v(0, 0, 0) }
end

local function At(position)
	return { position = position }
end

local function shot(name, from, to, fov, roll, focus)
	return { name = name, from = from, to = to, fov = fov, roll = roll or 0, focus = focus or to }
end

local function hitsBefore(hits, tick)
	local n = 0
	for _, t in hits do
		if t <= tick then n += 1 end
	end
	return n
end

local function lerp(a, b, t)
	return a + (b - a) * math.clamp(t, 0, 1)
end

local function progress(tick, from, to)
	return math.clamp((tick - from) / math.max(1, to - from), 0, 1)
end

local function newFrame()
	return { grade = { crimson = false, void = false, mono = false }, fx = {} }
end

-- The attacker's kit (MoveData.Kits): every kit stages its ultimates with its own moves
-- (role -> move id), colours and titles.
local function kitOf(ctx)
	local data = ctx.moveData
	local name = data.MoveKit and data.MoveKit[ctx.cin.move] or "KAI"
	return data.Kits and data.Kits[name]
end

local function role(ctx, id)
	local kit = kitOf(ctx)
	return kit and kit.Roles[id] or id
end

local function attack(view, moves, id, active)
	view.state, view.move = "Attack", id
	view.moveFrame = if active then moves[id].startup + 1 else moves[id].startup
end

-- ===================================================================== KIT ULTIMATES
--[[
	TARO, ZEPHYR and AKEMI stage their three ultimates their own way (Wilhem's ultimate
	sheet); KAI keeps KAIEN RUSH, ÉVEIL ÉCARLATE and 開天. The authoritative timing (hits,
	prompt, final blow) is the same for every kit: only the staging differs.
	  TARO   1 RUSH DÉVASTATEUR     2 UPPERCUT CÉLESTE    3 TEMPÊTE DE CROCHETS
	  ZEPHYR 1 VENT TRANCHEUR       2 DRAGON ASCENDANT    3 CYCLONE FURIEUX
	  AKEMI  1 OMBRES MULTIPLES     2 TEMPS SUSPENDU      3 DANSE FANTÔME
	Positions hang on anchors.center (the target's place when the cinematic starts), so the
	smoothing of the displayed views never makes them drift. A fighter circling the target
	stays on the far half (z <= 0): the camera, in front, always sees the target.
]]
local KIT = {}

local function center(ctx, d)
	ctx.anchors.center = ctx.anchors.center or d.x
	return ctx.anchors.center
end

-- Places `a` on the far half of a circle around the target (angle 0 = in front of it on the
-- attack side, pi = behind it) and turns it toward the target.
local function around(a, cx, dir, angle, radius, y)
	a.x = cx - dir * math.cos(angle) * radius
	a.z = -math.abs(math.sin(angle)) * radius
	a.y = y or 0
	local lx, lz = cx - a.x, -a.z
	local l = math.sqrt(lx * lx + lz * lz)
	if l > 1e-3 then a.lookDir = v(lx / l, 0, lz / l) end
	a.facing = if lx >= 0 then 1 else -1
end

local function arc(frame, key, pos, radius, from, to, color, tilt, dir)
	table.insert(frame.fx, { key = key, kind = "arc", pos = pos, radius = radius, from = from, to = to,
		color = color, tilt = tilt or 0, dir = dir or 1 })
end

local function impact(frame, key, pos, color, scale)
	table.insert(frame.fx, { key = key .. "-wave", kind = "shockwave", pos = v(pos.x, 0, 0), color = color })
	table.insert(frame.fx, { key = key .. "-spark", kind = "spark", pos = pos, color = color, scale = scale or 2.4 })
end

-- Common opening of the three gates: the kit's kanji burns on the floor, seen from above.
local function gateSeal(ctx, frame, a, d, cx, dir, prefix)
	local A = ctx.cin.attacker
	a.x, a.facing, a.pose = cx - dir * 4, dir, "Kiai"
	d.x, d.state = cx, "Hitstun"
	local mid = (a.x + d.x) / 2
	table.insert(frame.fx, { key = "seal", kind = "kanjiSeal", pos = v(mid, 0.06, 0), color = ctx.characters[A].Energy,
		text = ctx.characters[A].Kanji, keep = true })
	frame.shot = shot(prefix .. "-seal", At(v(mid, 22, 2)), At(v(mid, 0, 0)), 50, math.rad(90))
end

-- Common end of the three gates: the two setup blows, the wind-up (press R at the climax),
-- the final blow, the title. `final` stages the final blow's effects.
local function gateEnd(ctx, frame, a, d, tick, dir, cx, prefix, final)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local color = ctx.characters[A].Energy
	d.x = cx
	if tick < data.PromptTicks[1] - 14 then
		d.state, d.hitstop = "Hitstun", if tick >= data.Hits[1] and (tick - data.Hits[1]) % 8 < 5 then 1 else 0
		a.x, a.facing = cx - dir * 2.3, dir
		local second = tick >= data.Hits[2]
		attack(a, moves, role(ctx, if second then "Cross" else "Jab"), tick >= data.Hits[1])
		frame.shot = shot(prefix .. "-setup" .. (if second then "2" else "1"),
			P(D, "Head", v(if second then dir * 3 else -dir * 3, 0.5, 4.5)), P(D, "Head"), 36)
	elseif tick < data.FinalTick then
		d.state = "Hitstun"
		a.x, a.facing = cx - dir * 2.5, dir
		attack(a, moves, role(ctx, "Finale"), false)
		frame.grade.mono = tick >= data.PromptTicks[1] - 4
		table.insert(frame.fx, { key = "charge", kind = "spark", pos = v(a.x, 2.6, 0.4), color = color, scale = 1.4 })
		frame.shot = shot(prefix .. "-windup", P(A, "RightHand", v(dir * 1.2, 0.3, 2.4)), P(A, "RightHand"), 24, math.rad(4))
	elseif tick < data.FinalTick + 22 then
		a.x, a.facing = cx - dir * 2.5, dir
		attack(a, moves, role(ctx, "Finale"), true)
		final(color)
		frame.shot = shot(prefix .. "-final", At(v(cx + dir * 3, 5, 19)), At(v(cx - dir * 1, 3.5, 0)), 58)
	else
		a.y, a.facing, a.pose = 0, dir, "Kiai"
		local title = kitOf(ctx).GateTitle
		frame.title = { text = title.text, color = color, sub = title.sub }
		frame.shot = shot(prefix .. "-after", P(A, "UpperTorso", v(-dir * 3, 2.5, 22)), P(A, "UpperTorso"), 42)
	end
end

-- ---------------------------------------------------------------- TARO 火 · boxer

local TARO_RUSH = { "Jab", "Cross", "Elbow", "BodyBlow", "Kick", "SpinKick", "Uppercut" }

KIT.TARO = {}

-- RUSH DÉVASTATEUR: a straight charge, then punch after punch from the front.
function KIT.TARO.Rush(ctx, frame, a, d, tick, dir)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local color = ctx.characters[A].Energy
	local cx = center(ctx, d)
	local k = hitsBefore(data.Hits, tick)
	if tick >= data.FinalTick then
		a.x, a.facing = cx - dir * 2.4, dir
		attack(a, moves, role(ctx, "Smash"), true)
		impact(frame, "taro-rush-final", v(cx, 3.6, 0.6), color, 3)
		frame.shot = if tick < data.FinalTick + 12
			then shot("taro-rush-impact", P(D, "UpperTorso", v(-dir * 1.5, 0.4, 7)), P(D, "UpperTorso"), 54)
			else shot("taro-rush-wide", P(D, "UpperTorso", v(-dir * 6, 5, 30)), P(D, "UpperTorso"), 42)
		return
	end
	d.x, d.state = cx, "Hitstun"
	if tick < data.Hits[1] then
		a.x, a.facing, a.pose = lerp(cx - dir * 8, cx - dir * 2.3, progress(tick, 0, data.Hits[1])), dir, "Dash"
		a.ghost = true
		frame.shot = shot("taro-rush-charge", P(A, "UpperTorso", v(dir * 3, -1.4, 6.5)), P(A, "UpperTorso"), 38)
	elseif tick < data.FinalTick - 16 then
		a.x, a.facing = cx - dir * 2.2, dir
		attack(a, moves, role(ctx, TARO_RUSH[(k - 1) % #TARO_RUSH + 1]), true)
		d.hitstop = if tick - data.Hits[k] < 5 then 1 else 0
		table.insert(frame.fx, { key = "taro-hit" .. k, kind = "spark", pos = v(cx - dir * 0.5, 3.4 + (k % 3) * 0.4, 0.5),
			color = color, scale = 1.3 })
		if k % 2 == 1 then
			frame.shot = shot("taro-rush-front", P(D, "UpperTorso", v(-dir * 1.5, -0.8, 7.5)), P(D, "UpperTorso"), 42)
		else
			frame.shot = shot("taro-rush-low", P(A, "UpperTorso", v(-dir * 2.5, -2.4, 6)), P(D, "Head"), 50, math.rad(-8 * dir))
		end
	else
		a.x, a.facing = cx - dir * 2.6, dir
		attack(a, moves, role(ctx, "Smash"), false)
		table.insert(frame.fx, { key = "taro-charge", kind = "spark", pos = v(a.x - dir * 0.4, 3, 0.4), color = color, scale = 1.6 })
		frame.shot = shot("taro-rush-windup", P(A, "UpperTorso", v(-dir * 3, -1, 5)), P(D, "UpperTorso"),
			40 - 10 * progress(tick, data.FinalTick - 16, data.FinalTick))
	end
end

-- UPPERCUT CÉLESTE: body blows, a crouched charge, the uppercut that lifts the target in a
-- pillar of fire, then TARO leaps above it for the aerial finish.
function KIT.TARO.Awaken(ctx, frame, a, d, tick, dir, color)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local cx = center(ctx, d)
	local start, final = data.Hits[#data.Hits] + 4, data.FinalTick
	d.x, d.state = cx, "Hitstun"
	if tick < start then
		local k = math.max(1, hitsBefore(data.Hits, tick))
		a.x, a.facing = cx - dir * 2.2, dir
		attack(a, moves, role(ctx, TARO_RUSH[(k * 2) % 4 + 1]), true)
		d.hitstop = if tick - data.Hits[k] < 6 then 1 else 0
		table.insert(frame.fx, { key = "celeste-hit" .. k, kind = "spark", pos = v(cx - dir * 0.5, 3.2, 0.5), color = color, scale = 1.2 })
		local angles = { v(-dir * 4, 1.5, 5.5), v(dir * 3.5, 0.5, 4.5), v(-dir * 2, -2.4, 7) }
		frame.shot = shot("taro-celeste-blow" .. ((k - 1) % 3 + 1), P(D, "UpperTorso", angles[(k - 1) % 3 + 1]), P(D, "UpperTorso"), 40)
		return
	end
	local p = progress(tick, start, final)
	a.x, a.facing = cx - dir * 1.7, dir
	if p < 0.25 then
		attack(a, moves, role(ctx, "Uppercut"), false)
		table.insert(frame.fx, { key = "celeste-charge", kind = "spark", pos = v(a.x, 1.6, 0.4), color = color, scale = 1.8 })
		frame.shot = shot("taro-celeste-charge", P(A, "Head", v(dir * 2.5, -1.6, 4)), P(A, "Head"), 34, math.rad(8 * dir))
	elseif p < 0.6 then
		local q = progress(p, 0.25, 0.6)
		attack(a, moves, role(ctx, "Uppercut"), true)
		a.y, d.y = lerp(0, 3, q), lerp(0, 10, q)
		table.insert(frame.fx, { key = "celeste-pillar", kind = "dragonHelix", pos = v(cx, 0, 0), color = color })
		frame.shot = shot("taro-celeste-rise", At(v(cx - dir * 3, 0.6, 7)), P(D, "UpperTorso"), 62, math.rad(12 * dir))
	else
		local q = progress(p, 0.6, 1)
		d.y, d.pose = 10, "Launched"
		a.x, a.y = cx - dir * 1.2, lerp(3, 12.5, math.min(1, q / 0.6))
		attack(a, moves, role(ctx, "AirSmash"), q > 0.7)
		a.ghost = q > 0.7
		frame.shot = shot("taro-celeste-air", P(D, "UpperTorso", v(dir * 5, -2.5, 8)), P(A, "Head"), 55)
	end
end

-- TEMPÊTE DE CROCHETS: TARO whirls around the target, hook after hook, rings of fire.
function KIT.TARO.Gate(ctx, frame, a, d, tick, dir)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local D = cin.defender
	local color = ctx.characters[cin.attacker].Energy
	local cx = center(ctx, d)
	if tick < 30 then
		gateSeal(ctx, frame, a, d, cx, dir, "taro-tempete")
		return
	end
	if tick < data.Hits[1] - 6 then
		local p = progress(tick, 30, data.Hits[1] - 6)
		frame.grade.crimson = true
		d.x, d.state = cx, "Hitstun"
		local step = math.floor((tick - 30) / 7)
		d.hitstop = if (tick - 30) % 7 < 3 then 1 else 0
		around(a, cx, dir, (step * 0.9) % math.pi, 2.3)
		attack(a, moves, role(ctx, if step % 2 == 0 then "Elbow" else "Kick"), true)
		arc(frame, "tempete-hook" .. step, v(cx, 3.6, 0), 2.4, step * 70, step * 70 + 160, color, 1.2, dir)
		if step % 3 == 0 then
			table.insert(frame.fx, { key = "tempete-ring" .. step, kind = "tornadoRing", pos = v(cx, 2 + (step % 4) * 0.6, 0), color = color })
		end
		frame.shot = shot("taro-tempete-whirl", P(D, "UpperTorso", v(-dir * 2, 1.5, lerp(14, 9, p))), P(D, "UpperTorso"), 50)
		return
	end
	gateEnd(ctx, frame, a, d, tick, dir, cx, "taro-tempete", function(c)
		impact(frame, "tempete-final", v(cx, 3.6, 0.6), c, 3)
		table.insert(frame.fx, { key = "tempete-burst", kind = "tornadoRing", pos = v(cx, 3, 0), color = c })
	end)
end

-- ---------------------------------------------------------------- ZEPHYR 風 · kicks

local ZEPHYR_RUSH = { "Jab", "Cross", "Elbow", "Kick", "SpinKick", "Sweep" }

KIT.ZEPHYR = {}

-- VENT TRANCHEUR: an ultra-fast chain of kicks, a blade of wind on each one.
function KIT.ZEPHYR.Rush(ctx, frame, a, d, tick, dir)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local color = ctx.characters[A].Energy
	local cx = center(ctx, d)
	if tick >= data.FinalTick then
		a.x, a.facing = cx - dir * 2.6, dir
		attack(a, moves, role(ctx, "Kick"), true)
		impact(frame, "vent-final", v(cx, 4, 0.6), color, 2.8)
		arc(frame, "vent-final-arc", v(cx - dir * 0.4, 3.8, 0.4), 3.4, -70, 80, color, 0, dir)
		frame.shot = if tick < data.FinalTick + 12
			then shot("zephyr-vent-impact", P(D, "UpperTorso", v(-dir * 1.5, 0.4, 7)), P(D, "UpperTorso"), 54)
			else shot("zephyr-vent-wide", P(D, "UpperTorso", v(-dir * 6, 5, 30)), P(D, "UpperTorso"), 42)
		return
	end
	d.x, d.state = cx, "Hitstun"
	if tick < data.Hits[1] then
		a.x, a.facing, a.pose = lerp(cx - dir * 7, cx - dir * 2.6, progress(tick, 0, data.Hits[1])), dir, "Dash"
		a.ghost = true
		frame.shot = shot("zephyr-vent-dash", P(A, "UpperTorso", v(dir * 2, 0.6, 9)), P(A, "UpperTorso"), 40)
	elseif tick < data.FinalTick - 12 then
		-- A new kick every 4 ticks: twice the rhythm of the hits.
		local n = math.floor((tick - data.Hits[1]) / 4)
		a.x, a.facing = cx - dir * 2.6, dir
		attack(a, moves, role(ctx, ZEPHYR_RUSH[n % #ZEPHYR_RUSH + 1]), true)
		a.ghost = true
		d.hitstop = if (tick - data.Hits[1]) % 8 < 3 then 1 else 0
		arc(frame, "vent-blade" .. n, v(cx - dir * 0.5, 2.6 + (n % 3) * 0.6, 0.4), 2.6, -80 + (n % 4) * 30, 70 + (n % 4) * 30, color,
			(n % 3 - 1) * 0.5, dir)
		local angle = -1 + 2 * progress(tick, data.Hits[1], data.FinalTick - 12)
		frame.shot = shot("zephyr-vent-orbit", P(D, "UpperTorso", v(math.sin(angle) * 11, 2 + math.cos(angle * 2), math.cos(angle) * 11)),
			P(D, "UpperTorso"), 46)
	else
		a.x, a.facing = cx - dir * 2.6, dir
		attack(a, moves, role(ctx, "Kick"), false)
		frame.shot = shot("zephyr-vent-windup", P(A, "UpperTorso", v(-dir * 3, -1.2, 5.5)), P(D, "UpperTorso"), 36)
	end
end

-- DRAGON ASCENDANT: the rising kick throws the target up, ZEPHYR climbs with it kicking
-- from both sides inside a dragon of wind, then spins above and dives.
function KIT.ZEPHYR.Awaken(ctx, frame, a, d, tick, dir, color)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local D = cin.defender
	local cx = center(ctx, d)
	local start, final = data.Hits[#data.Hits] + 4, data.FinalTick
	d.x, d.state = cx, "Hitstun"
	local rise = progress(tick, data.Hits[1], start)
	d.y = lerp(0, 7, rise)
	if tick < start then
		local k = math.max(1, hitsBefore(data.Hits, tick))
		if k == 1 then
			a.x, a.y, a.facing = cx - dir * 1.8, 0, dir
			attack(a, moves, role(ctx, "Uppercut"), true)
			table.insert(frame.fx, { key = "dragon-wind", kind = "dragonHelix", pos = v(cx, 0, 0), color = color })
		else
			local behind = k % 2 == 0
			a.x, a.y = cx + (if behind then dir else -dir) * 1.9, d.y - 0.4
			a.facing = if behind then -dir else dir
			attack(a, moves, role(ctx, if k % 3 == 0 then "Kick" elseif behind then "AirKick2" else "AirKick"), true)
		end
		d.hitstop = if tick - data.Hits[k] < 5 then 1 else 0
		arc(frame, "dragon-kick" .. k, v(cx, d.y + 3, 0.4), 2.2, k * 50, k * 50 + 150, color, 0.6, dir)
		if k % 2 == 1 then
			frame.shot = shot("zephyr-dragon-under", At(v(cx - dir * 2, 0.8, 9)), P(D, "UpperTorso"), 60, math.rad(10 * dir))
		else
			frame.shot = shot("zephyr-dragon-side", P(D, "UpperTorso", v(-dir * 3, -1.5, 9)), P(D, "UpperTorso"), 46)
		end
		return
	end
	local p = progress(tick, start, final)
	d.y = 7
	if p < 0.55 then
		local q = p / 0.55
		a.x, a.y, a.facing = cx - dir * 1.4, lerp(d.y - 0.4, d.y + 3.2, q), dir
		local spin = role(ctx, "DragonTornado")
		a.state, a.move = "Attack", spin
		a.moveFrame = moves[spin].startup + 1 + (math.floor(tick / 3) % 2) * (moves[spin].hitInterval or 2)
		if tick % 5 == 0 then
			table.insert(frame.fx, { key = "dragon-ring" .. tick, kind = "tornadoRing", pos = v(cx, a.y + 1, 0), color = color })
		end
		frame.shot = shot("zephyr-dragon-spin", P(D, "UpperTorso", v(dir * 4, -2.5, 9)), P(D, "UpperTorso"), 56)
	else
		local q = progress(p, 0.55, 1)
		a.x, a.y, a.facing = cx - dir * 1.2, lerp(d.y + 3.2, d.y + 0.6, q), dir
		attack(a, moves, role(ctx, "AirSmash"), true)
		a.ghost = true
		frame.shot = shot("zephyr-dragon-dive", P(D, "UpperTorso", v(-dir * 5, 3, 7)), P(D, "UpperTorso"), 46)
	end
end

-- CYCLONE FURIEUX: a vortex lifts the target; ZEPHYR spins around it at full speed.
function KIT.ZEPHYR.Gate(ctx, frame, a, d, tick, dir)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local D = cin.defender
	local color = ctx.characters[cin.attacker].Energy
	local cx = center(ctx, d)
	if tick < 30 then
		gateSeal(ctx, frame, a, d, cx, dir, "zephyr-cyclone")
		return
	end
	if tick < data.Hits[1] - 6 then
		local p = progress(tick, 30, data.Hits[1] - 6)
		d.x, d.state, d.pose = cx, "Hitstun", "Launched"
		d.y = lerp(0, 3.5, math.min(1, p * 2)) * (1 - progress(p, 0.85, 1))
		local angle = math.pi / 2 + math.sin(tick * 0.32) * 1.35
		around(a, cx, dir, angle, 2.2, d.y * 0.6)
		local spin = role(ctx, if math.floor(tick / 9) % 2 == 0 then "SpinKick" else "DragonTornado")
		attack(a, moves, spin, true)
		a.ghost = true
		if tick % 4 == 0 then
			table.insert(frame.fx, { key = "cyclone-ring" .. tick, kind = "tornadoRing", pos = v(cx, 0.5 + (tick % 24) * 0.25, 0), color = color })
		end
		frame.shot = shot("zephyr-cyclone-vortex", P(D, "UpperTorso", v(-dir * 1.5, 4, 13)), P(D, "UpperTorso"), 52)
		return
	end
	gateEnd(ctx, frame, a, d, tick, dir, cx, "zephyr-cyclone", function(c)
		impact(frame, "cyclone-final", v(cx, 3.8, 0.6), c, 3.2)
		arc(frame, "cyclone-final-arc", v(cx - dir * 0.4, 3.6, 0.4), 3.6, -90, 90, c, 0, dir)
	end)
end

-- ---------------------------------------------------------------- AKEMI 影 · shadow

local AKEMI_STRIKES = { "Jab", "Kick", "SpinKick", "Elbow", "Cross", "BodyBlow" }

KIT.AKEMI = {}

-- OMBRES MULTIPLES: shadow copies strike from every side, then AKEMI reappears in front.
function KIT.AKEMI.Rush(ctx, frame, a, d, tick, dir)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local color = ctx.characters[A].Energy
	local cx = center(ctx, d)
	local k = hitsBefore(data.Hits, tick)
	if tick >= data.FinalTick then
		a.x, a.facing = cx - dir * 2.5, dir
		attack(a, moves, role(ctx, "Smash"), true)
		impact(frame, "ombres-final", v(cx, 3.6, 0.6), color, 2.8)
		table.insert(frame.fx, { key = "ombres-cut", kind = "lightning", from = v(cx - dir * 4, 6, 0), to = v(cx + dir * 4, 1, 0), color = color })
		frame.shot = if tick < data.FinalTick + 12
			then shot("akemi-ombres-impact", P(D, "UpperTorso", v(-dir * 1.5, 0.4, 7)), P(D, "UpperTorso"), 54)
			else shot("akemi-ombres-wide", P(D, "UpperTorso", v(-dir * 6, 5, 30)), P(D, "UpperTorso"), 42)
		return
	end
	d.x, d.state = cx, "Hitstun"
	if tick < data.Hits[1] then
		a.x, a.facing, a.pose = cx - dir * 6, dir, "Kiai"
		table.insert(frame.fx, { key = "ombres-seal", kind = "kanjiSeal", pos = v(a.x, 0.06, 0), color = color,
			text = ctx.characters[A].Kanji, keep = true })
		frame.shot = shot("akemi-ombres-gather", P(A, "Head", v(dir * 2.4, -0.4, 4.5)), P(A, "Head"), 30)
	elseif tick < data.FinalTick - 14 then
		-- Each hit comes from another copy, somewhere on the far half of a circle.
		around(a, cx, dir, ((k * 0.61) % 1) * math.pi, 2.4, if k % 4 == 0 then 1.4 else 0)
		attack(a, moves, role(ctx, AKEMI_STRIKES[(k - 1) % #AKEMI_STRIKES + 1]), true)
		a.ghost = true
		d.hitstop = if tick - data.Hits[k] < 5 then 1 else 0
		table.insert(frame.fx, { key = "ombres-hit" .. k, kind = "spark", pos = v(cx, 3.4, 0.5), color = color, scale = 1.1 })
		local angle = -0.8 + 1.6 * progress(tick, data.Hits[1], data.FinalTick - 14)
		frame.shot = shot("akemi-ombres-orbit", P(D, "UpperTorso", v(math.sin(angle) * 10, 6, math.cos(angle) * 10)), P(D, "UpperTorso"), 50)
	else
		a.x, a.facing, a.pose = cx - dir * 2.5, dir, "Kiai"
		a.ghost = true
		frame.shot = shot("akemi-ombres-return", P(A, "UpperTorso", v(-dir * 3, -0.8, 5.5)), P(D, "UpperTorso"), 38)
	end
end

-- TEMPS SUSPENDU: time stops (black and white); AKEMI slips past the target's blow and
-- strikes it again and again in slow motion, then stands behind it as time resumes.
function KIT.AKEMI.Awaken(ctx, frame, a, d, tick, dir, color)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local cx = center(ctx, d)
	local start, final = data.Hits[#data.Hits] + 4, data.FinalTick
	frame.grade.crimson, frame.grade.mono = false, true
	d.x, d.state, d.hitstop = cx, "Hitstun", 1
	if tick < data.Hits[1] + 4 then
		a.x, a.facing, a.pose = cx - dir * 1.4, dir, "Evade"
		a.ghost = true
		table.insert(frame.fx, { key = "temps-bubble", kind = "shockwave", pos = v(cx, 0, 0), color = color })
		frame.shot = shot("akemi-temps-dodge", P(A, "Head", v(dir * 2.6, 0.2, 4)), P(A, "Head"), 30)
	elseif tick < start then
		local k = math.max(1, hitsBefore(data.Hits, tick))
		around(a, cx, dir, if k % 2 == 0 then math.pi * 0.8 else math.pi * 0.2, 2.2)
		attack(a, moves, role(ctx, AKEMI_STRIKES[(k - 1) % #AKEMI_STRIKES + 1]), tick - data.Hits[k] >= 2)
		a.ghost = true
		table.insert(frame.fx, { key = "temps-hit" .. k, kind = "spark", pos = v(cx, 3.3, 0.5), color = color, scale = 1 })
		local angle = -0.9 + 1.8 * progress(tick, data.Hits[1], start)
		frame.shot = shot("akemi-temps-slow", P(D, "UpperTorso", v(math.sin(angle) * 9, 1.2, math.cos(angle) * 9)), P(D, "UpperTorso"), 40)
	else
		local p = progress(tick, start, final)
		-- Behind the target, back turned: the cuts appear at once.
		a.x, a.facing, a.pose = cx + dir * 2.6, dir, "StandTall"
		if p > 0.7 then
			frame.grade.mono = false
			table.insert(frame.fx, { key = "temps-cut1", kind = "lightning", from = v(cx - 2.5, 6, 0.3), to = v(cx + 2.5, 1, 0.3), color = color })
			table.insert(frame.fx, { key = "temps-cut2", kind = "lightning", from = v(cx + 2.5, 6, 0.3), to = v(cx - 2.5, 1, 0.3), color = color })
		end
		frame.shot = shot("akemi-temps-back", P(A, "UpperTorso", v(dir * 3, -1, 6)), P(A, "UpperTorso"), 44)
	end
end

-- DANSE FANTÔME: AKEMI dodges and reappears, strike after strike, each blink a flash.
function KIT.AKEMI.Gate(ctx, frame, a, d, tick, dir)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local D = cin.defender
	local color = ctx.characters[cin.attacker].Energy
	local cx = center(ctx, d)
	if tick < 30 then
		gateSeal(ctx, frame, a, d, cx, dir, "akemi-danse")
		return
	end
	if tick < data.Hits[1] - 6 then
		frame.grade.void = true
		d.x, d.state = cx, "Hitstun"
		local step = math.floor((tick - 30) / 11)
		local t = (tick - 30) % 11
		local angle = if step % 2 == 0 then math.pi * 0.15 else math.pi * 0.85
		around(a, cx, dir, angle, 2.3)
		if t < 4 then
			a.pose = "Evade"
		else
			attack(a, moves, role(ctx, AKEMI_STRIKES[step % #AKEMI_STRIKES + 1]), true)
		end
		a.ghost = true
		d.hitstop = if t >= 4 and t < 7 then 1 else 0
		if step > 0 then
			local from = if step % 2 == 0 then cx + dir * 2.2 else cx - dir * 2.2
			table.insert(frame.fx, { key = "danse-blink" .. step, kind = "lightning", from = v(from, 3.5, -0.8), to = v(a.x, 3.5, a.z),
				color = color })
		end
		local side = if step % 2 == 0 then 1 else -1
		frame.shot = shot("akemi-danse-" .. (if side > 0 then "a" else "b"), P(D, "UpperTorso", v(side * dir * 3.5, 1.4, 9)),
			P(D, "UpperTorso"), 46)
		return
	end
	gateEnd(ctx, frame, a, d, tick, dir, cx, "akemi-danse", function(c)
		impact(frame, "danse-final", v(cx, 3.6, 0.6), c, 2.8)
		table.insert(frame.fx, { key = "danse-cut", kind = "lightning", from = v(cx - 3, 6.5, 0.4), to = v(cx + 3, 0.5, 0.4), color = c })
	end)
end

Director.KIT_ULTIMATES = KIT

-- ===================================================================== KAIEN RUSH

local function rush(ctx, frame, a, d, tick, dir)
	local cin = ctx.cin
	local moves, data = ctx.moveData.Moves, ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local k = hitsBefore(data.Hits, tick)
	if tick < data.FinalTick - 16 then
		if k == 0 then
			a.x = d.x - dir * 2.8
			attack(a, moves, cin.move, true)
		else
			local behind = k % 2 == 0
			a.x = d.x + (if behind then dir else -dir) * 2.6
			a.y = if k % 3 == 0 then 1.6 else 0
			a.facing = if behind then -dir else dir
			attack(a, moves, role(ctx, RUSH[(k - 1) % #RUSH + 1]), true)
		end
		d.state = "Hitstun"
		d.hitstop = if k > 0 and tick - data.Hits[k] < 6 then 1 else 0
		a.ghost = true
	elseif tick < data.FinalTick then
		a.x, a.y, a.facing = d.x - dir * 2.8, 0, dir
		attack(a, moves, role(ctx, "Smash"), false)
		d.state, d.hitstop = "Hitstun", 0
	else
		a.x, a.y, a.facing = d.x - dir * 2.8, 0, dir
		attack(a, moves, role(ctx, "Smash"), true)
	end
	if tick < data.Hits[1] then
		frame.shot = shot("rush-closeup", P(A, "Head", v(dir * 3.4, -0.6, 5.5)), P(A, "Head"), 30)
	elseif tick < data.FinalTick - 16 then
		local angle = -1.15 + 2.3 * progress(tick, data.Hits[1], data.FinalTick - 16)
		frame.shot = shot("rush-orbit", P(D, "UpperTorso", v(math.sin(angle) * 12, 2.5 + math.sin(angle * 2) * 1.5, math.cos(angle) * 12)),
			P(D, "UpperTorso"), 46)
	elseif tick < data.FinalTick then
		frame.shot = shot("rush-windup", P(A, "UpperTorso", v(-dir * 5.5, -1.8, 5.5)), P(D, "UpperTorso"),
			38 - 10 * progress(tick, data.FinalTick - 16, data.FinalTick))
	elseif tick < data.FinalTick + 10 then
		frame.shot = shot("rush-impact", P(D, "UpperTorso", v(-dir * 1.5, 0.4, 7)), P(D, "UpperTorso"), 52)
	else
		frame.shot = shot("rush-wide", P(D, "UpperTorso", v(-dir * 6, 5, 30)), P(D, "UpperTorso"), 42)
	end
end

-- ===================================================================== ÉVEIL ÉCARLATE

-- Finale picked by the route that was played.
-- `name` is the finale template (TORNADE, RAFALE, DRAGON, FOUDRE, MUR, LUNE) of the route.
local function style(ctx, frame, a, d, tick, dir, name, color)
	local cin, anchors, config = ctx.cin, ctx.anchors, ctx.config
	local moves, data = ctx.moveData.Moves, ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local tornado, flurry, fist = role(ctx, "DragonTornado"), role(ctx, "KiFlurry"), role(ctx, "DragonFist")
	local dive, heel, axe = role(ctx, "AirSmash"), role(ctx, "SpinKick"), role(ctx, "Hammer")
	local start, final = data.Hits[#data.Hits] + 4, data.FinalTick
	local p = progress(tick, start, final)
	d.state = "Hitstun"
	if name == "TORNADE" then
		-- Rising spin: both fighters climb inside a tornado of ki.
		d.y = lerp(0, 9, p)
		a.x, a.y, a.facing = d.x - dir * 1.8, d.y - 0.5, dir
		a.state, a.move = "Attack", tornado
		a.moveFrame = moves[tornado].startup + 1 + (math.floor(tick / 4) % 2) * moves[tornado].hitInterval
		if tick % 6 == 0 then
			table.insert(frame.fx, { key = "ring" .. tick, kind = "tornadoRing", pos = v(d.x, d.y + 1, 0), color = color })
		end
		-- Half orbit on the far side of the target, so KAI never stands between it and the lens.
		local angle = dir * (-0.2 + 1.5 * p)
		frame.shot = shot("tornade-orbit", P(D, "UpperTorso", v(math.sin(angle) * 11, 1, math.cos(angle) * 11)), P(D, "UpperTorso"), 50)
	elseif name == "RAFALE" then
		-- Barrage: a hundred fists in front of the target.
		a.x, a.y, a.facing = d.x - dir * 2.2, 0, dir
		a.state, a.move = "Attack", flurry
		a.moveFrame = moves[flurry].startup + 1 + (math.floor(tick / 2) % 2) * moves[flurry].hitInterval
		if tick % 3 == 0 then
			table.insert(frame.fx, { key = "fist" .. tick, kind = "spark", pos = v(d.x - dir * 0.6, 3.6 + (tick % 7) * 0.2, 0.5), color = color, scale = 0.7 })
		end
		if p < 0.5 then
			frame.shot = shot("rafale-front", P(D, "Head", v(-dir * 4, 0.2, 2.5)), P(A, "UpperTorso"), 40, math.rad(-6))
		else
			frame.shot = shot("rafale-side", P(A, "UpperTorso", v(dir * 1, 0.5, 9)), P(D, "UpperTorso"), 36)
		end
	elseif name == "DRAGON" then
		-- Crouched charge, then the rising dragon fist with a ki dragon spiralling up.
		a.x, a.facing = d.x - dir * 1.6, dir
		if p < 0.7 then
			a.y = 0
			attack(a, moves, fist, false)
			table.insert(frame.fx, { key = "dragon-charge", kind = "spark", pos = v(a.x, 2, 0), color = color, scale = 1.6 })
			frame.shot = shot("dragon-charge", P(A, "Head", v(dir * 2.5, -1.6, 4)), P(A, "Head"), 34, math.rad(8 * dir))
		else
			local q = progress(tick, start + (final - start) * 0.7, final)
			a.y, d.y = lerp(0, 6, q), lerp(0, 11, q)
			attack(a, moves, fist, true)
			table.insert(frame.fx, { key = "dragon-helix", kind = "dragonHelix", pos = v(d.x, 0, 0), color = color })
			frame.shot = shot("dragon-rise", At(v(d.x - dir * 3, 0.6, 6)), P(D, "UpperTorso"), 62, math.rad(12 * dir))
		end
	elseif name == "FOUDRE" then
		-- Leap into the storm, dive with lightning.
		if p < 0.65 then
			a.x, a.y, a.facing = d.x - dir * 1.5, lerp(1, 12, p / 0.65), dir
			a.state, a.move, a.moveFrame = "Attack", dive, 1
			if tick % 5 == 0 then
				table.insert(frame.fx, { key = "bolt" .. tick, kind = "lightning", from = v(d.x + ((tick * 37) % 9 - 4), 30, -4),
					to = v(a.x, a.y + 3, 0), color = color })
			end
			frame.shot = shot("foudre-sky", P(D, "UpperTorso", v(-dir * 3, -3, 6)), P(A, "Head"), 60, math.rad(10 * dir))
		else
			a.x, a.y, a.facing = d.x - dir * 1.8, lerp(12, d.y + 1, (p - 0.65) / 0.35), dir
			attack(a, moves, dive, true)
			a.ghost = true
			if tick % 3 == 0 then
				table.insert(frame.fx, { key = "bolt" .. tick, kind = "lightning", from = v(a.x, a.y + 12, 0), to = v(d.x, d.y + 3, 0), color = color })
			end
			frame.shot = shot("foudre-dive", P(D, "UpperTorso", v(dir * 6, 4, 7)), P(D, "UpperTorso"), 44)
		end
	elseif name == "MUR" then
		-- Spinning heel that sends the target across the arena into the wall.
		anchors.wall = anchors.wall or {
			from = d.x, to = math.clamp(d.x + dir * 14, config.ArenaMinX - 4, config.ArenaMaxX + 4),
		}
		local wallX = anchors.wall.to
		if p < 0.55 then
			a.x, a.y, a.facing = d.x - dir * 2.4, 0, dir
			attack(a, moves, heel, p >= 0.4)
			frame.shot = shot("mur-kick", P(A, "UpperTorso", v(-dir * 2, -1, 7)), P(A, "UpperTorso"), 42)
		else
			local q = progress(tick, start + (final - start) * 0.55, final)
			d.x, d.y, d.pose = lerp(anchors.wall.from, wallX, q), lerp(3, 4, q), "Launched"
			if q > 0.85 then
				table.insert(frame.fx, { key = "mur-wall", kind = "shockwave", pos = v(wallX, 4, 0), color = color })
			end
			frame.shot = shot("mur-wall", At(v(wallX - dir * 2, 3.5, 7)), P(D, "UpperTorso"), 55)
		end
	elseif name == "LUNE" then
		-- A giant crescent rises behind KAI, then the axe kick from the moon.
		a.x, a.y, a.facing = d.x - dir * 1.6, lerp(1, 10, math.min(1, p / 0.7)), dir
		table.insert(frame.fx, { key = "lune-crescent", kind = "crescent", pos = v(d.x, 13, -6), color = color, keep = true })
		if p < 0.7 then
			attack(a, moves, axe, false)
			frame.shot = shot("lune-moon", P(D, "UpperTorso", v(dir * 4, -2.4, 9)), At(v(d.x, 11, -4)), 58)
		else
			a.y = lerp(10, d.y + 1, (p - 0.7) / 0.3)
			attack(a, moves, axe, true)
			a.ghost = true
			frame.shot = shot("lune-dive", P(D, "UpperTorso", v(-dir * 5, 3, 6)), P(D, "UpperTorso"), 46)
		end
	else
		a.x, a.y, a.facing = d.x - dir * 1.5, lerp(1, 11, p), dir
		a.state, a.move, a.moveFrame = "Attack", dive, 1
		frame.shot = shot("style-default", P(D, "UpperTorso", v(-dir * 3, -3, 6)), P(A, "Head"), 60)
	end
end

local function awakening(ctx, frame, a, d, tick, dir)
	local cin = ctx.cin
	local moves, data = ctx.moveData.Moves, ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	-- The route that was played picks the finale template and its colour.
	local kit = kitOf(ctx)
	local name = cin.style or (kit and kit.FullRoutes[1].name) or "TORNADE"
	local template = name
	for _, route in (kit and kit.FullRoutes or {}) do
		if route.name == name then template = route.finale or name end
	end
	local color = (kit and kit.Colors[template]) or Director.STYLE_COLORS[template] or RED
	-- TARO, ZEPHYR and AKEMI play their own ÉVEIL between the first hit and the final blow.
	local staged = kit and KIT[kit.Name] and KIT[kit.Name].Awaken
	frame.grade.crimson = tick >= 24 and tick < data.FinalTick + 40
	if tick < 24 then
		-- 1. Extreme close-up on the eyes, a giant kanji painted over the frame.
		frame.kanjiBack = ctx.characters[A].Kanji
		a.x, a.y, a.facing, a.pose = d.x - dir * 9, 0, dir, "Kiai"
		d.state = "Hitstun"
		frame.shot = shot("eveil-eyes", P(A, "Head", v(dir * 1.5, 0.15, 1.3)), P(A, "Head", v(0, 0.12, 0)), 16)
	elseif tick < 50 then
		-- 2. Low-angle hero shot while the crimson aura erupts.
		a.x, a.y, a.facing, a.pose = d.x - dir * 9, 0, dir, "Kiai"
		d.state = "Hitstun"
		frame.aura = A
		frame.shot = shot("eveil-hero", P(A, "LeftFoot", v(dir * 4, 0.6, 5)), P(A, "Head", v(0, 1.2, 0)), 48, math.rad(-8 * dir))
	elseif tick < data.Hits[1] then
		-- 3. Tracking shot of the dash.
		a.x, a.y, a.facing, a.pose = lerp(d.x - dir * 9, d.x - dir * 2.4, progress(tick, 50, data.Hits[1])), 0, dir, "Dash"
		a.ghost = true
		d.state = "Hitstun"
		frame.shot = shot("eveil-dash", P(A, "UpperTorso", v(dir * 2, 1, 13)), P(A, "UpperTorso"), 40)
	elseif staged and tick < data.FinalTick then
		staged(ctx, frame, a, d, tick, dir, color)
	elseif tick < data.Hits[#data.Hits] + 4 then
		-- 4. Strikes: a hard cut to a new camera angle on every hit.
		local k = math.max(1, hitsBefore(data.Hits, tick))
		local behind = k % 2 == 0
		a.x = d.x + (if behind then dir else -dir) * 2.5
		a.y = if k % 3 == 0 then 2 else 0
		a.facing = if behind then -dir else dir
		attack(a, moves, role(ctx, RUSH[(k * 3) % #RUSH + 1]), true)
		a.ghost = true
		d.state = "Hitstun"
		d.hitstop = if tick - data.Hits[k] < 6 then 1 else 0
		local angles = {
			{ v(-dir * 4, 2.5, 5), 40, math.rad(6) },   -- over the attacker's shoulder
			{ v(dir * 3.5, 0.5, 4.5), 34, 0 },         -- in the target's face
			{ v(0.3, 13, 1.5), 55, 0 },                -- top-down
			{ v(-dir * 2, -2.6, 7), 50, math.rad(-14) }, -- dutch angle from the floor
			{ v(dir * 9, 3, 9), 38, 0 },               -- wide three-quarter
		}
		local view = angles[(k - 1) % #angles + 1]
		frame.shot = shot("eveil-strike" .. k, P(D, "UpperTorso", view[1]), P(D, "UpperTorso"), view[2], view[3])
	elseif tick < data.FinalTick then
		style(ctx, frame, a, d, tick, dir, template, color)
	elseif tick < data.FinalTick + 14 then
		-- 7. Impact: wide frame, shockwave in the colour of the style.
		table.insert(frame.fx, { key = "eveil-impact", kind = "shockwave", pos = v(d.x, 0, 0), color = color })
		frame.shot = shot("eveil-impact", At(v(d.x, 9, 34)), At(v(d.x, 3, 0)), 46)
	else
		-- 8. Aftermath: KAI lands in a kiai, the target flies away (or falls for the K.O. scene).
		a.y, a.facing, a.pose = 0, dir, "Kiai"
		frame.title = { text = moves[cin.move].name, color = color, sub = name }
		frame.shot = shot("eveil-aftermath", P(A, "UpperTorso", v(-dir * 4, 3, 26)), P(A, "UpperTorso"), 42)
	end
end

-- ===================================================================== PORTE DES CIEUX

local function kaiten(ctx, frame, a, d, tick, dir)
	local cin, anchors = ctx.cin, ctx.anchors
	local moves, data = ctx.moveData.Moves, ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local energy = ctx.characters[A].Energy
	anchors.gateX = anchors.gateX or math.clamp(d.x + dir * 7, ctx.config.ArenaMinX - 2, ctx.config.ArenaMaxX + 2)
	local gateX = anchors.gateX
	local originX = gateX - dir * 7
	frame.grade.void = tick >= 20 and tick < data.FinalTick + 20
	if tick < 30 then
		-- 1. KAI joins his fists; a seal with his kanji burns on the floor (seen from above).
		a.x, a.facing, a.pose = originX - dir * 4, dir, "Kiai"
		d.x, d.state = originX, "Hitstun"
		local mid = (a.x + d.x) / 2
		table.insert(frame.fx, { key = "seal", kind = "kanjiSeal", pos = v(mid, 0.06, 0), color = energy,
			text = ctx.characters[A].Kanji, keep = true })
		frame.shot = shot("porte-seal", At(v(mid, 22, 2)), At(v(mid, 0, 0)), 50, math.rad(90))
	elseif tick < 70 then
		-- 2. A giant torii rises behind the target.
		a.x, a.facing, a.pose = originX - dir * 4, dir, "Kiai"
		d.x, d.state = originX, "Hitstun"
		table.insert(frame.fx, { key = "gate", kind = "gate", pos = v(gateX, 0, -1), dir = dir, color = energy, keep = true })
		frame.shot = shot("porte-rise", At(v(originX - dir * 9, 0.6, 12)), At(v(gateX, 7, -1)), 55, math.rad(-5 * dir))
	elseif tick < 110 then
		-- 3. The gate opens; the target is dragged toward the crimson light, KAI walks after it.
		local p = progress(tick, 70, 110)
		table.insert(frame.fx, { key = "gate-open", kind = "gateOpen" })
		d.x, d.y, d.pose = lerp(originX, gateX - dir * 1.5, p), lerp(0, 2.5, p), "Launched"
		a.x, a.facing, a.state, a.vx = lerp(originX - dir * 4, gateX - dir * 6, p), dir, "Walking", dir * 4
		frame.shot = shot("porte-back", P(A, "UpperTorso", v(-dir * 5, 1.2, 3)), At(v(gateX, 6, -1)), 48, 0, P(A, "UpperTorso"))
	elseif tick < data.Hits[1] then
		-- 4. Inside the crimson world: KAI appears right in front of the target.
		frame.grade.crimson = true
		d.x, d.y, d.pose = gateX - dir * 1.5, 2.5, "Launched"
		a.x, a.y, a.facing, a.pose = d.x - dir * 2.4, 1.6, dir, "Kiai"
		a.ghost = true
		frame.shot = shot("porte-crimson", P(A, "Head", v(dir * 2.5, 0.2, 3.5)), P(A, "Head"), 30)
	elseif tick < data.PromptTicks[1] - 14 then
		-- 5. Two blows to set it up.
		d.x, d.y = gateX - dir * 1.5, 2.5
		d.state, d.hitstop = "Hitstun", if (tick - data.Hits[1]) % 8 < 5 then 1 else 0
		a.x, a.y, a.facing = d.x - dir * 2.4, 1.6, dir
		local second = tick >= data.Hits[2]
		attack(a, moves, role(ctx, if second then "Cross" else "Jab"), true)
		frame.shot = shot("porte-setup" .. (if second then "2" else "1"),
			P(D, "Head", v(if second then dir * 3 else -dir * 3, 0.5, 4)), P(D, "Head"), 36)
	elseif tick < data.FinalTick then
		-- 6. Wind-up on the fist, everything stops: press R at the climax.
		d.x, d.y, d.state = gateX - dir * 1.5, 2.5, "Hitstun"
		a.x, a.y, a.facing = d.x - dir * 2.6, 1.6, dir
		attack(a, moves, role(ctx, "Finale"), false)
		frame.grade.mono = tick >= data.PromptTicks[1] - 4
		frame.shot = shot("porte-fist", P(A, "RightHand", v(dir * 1.2, 0.3, 2.2)), P(A, "RightHand"), 22, math.rad(4))
	elseif tick < data.FinalTick + 22 then
		-- 7. The single blow: the gate shatters behind the target.
		a.x, a.y, a.facing = gateX - dir * 4.1, 1.6, dir
		attack(a, moves, role(ctx, "Finale"), true)
		table.insert(frame.fx, { key = "shatter", kind = "gateShatter", color = energy })
		table.insert(frame.fx, { key = "shatter-wave", kind = "shockwave", pos = v(gateX, 3, -1), color = energy })
		frame.shot = shot("porte-shatter", At(v(gateX + dir * 4, 5, 18)), At(v(gateX - dir * 2, 4, 0)), 60)
	else
		-- 8. The world comes back.
		a.y, a.facing, a.pose = 0, dir, "Kiai"
		local title = kitOf(ctx) and kitOf(ctx).GateTitle or { text = "開天", sub = "PORTE DES CIEUX" }
		frame.title = { text = title.text, color = RED, sub = title.sub }
		frame.shot = shot("porte-after", P(A, "UpperTorso", v(-dir * 3, 2.5, 22)), P(A, "UpperTorso"), 42)
	end
end

-- ===================================================================== K.O. SCENE

-- The K.O. scene of Wilhem's storyboard. `t` runs from 0 to KO_SCENE ticks.
function Director.ko(ctx, winner, loser, w, l, t)
	local frame = newFrame()
	local anchors = ctx.anchors
	anchors.koSide = anchors.koSide or (if w.x >= l.x then 1 else -1)
	local side = anchors.koSide
	local W, L = winner, loser
	-- The loser lies face down, head toward the camera; the winner stands behind.
	l.state, l.lookDir, l.z = "KO", v(0, 0, 1), 0
	w.victory, w.state, w.vx = false, "Idle", 0
	w.x, w.y, w.z = l.x + side * 2.8, 0, -3.4
	w.lookDir = v(-side * 0.25, 0, 1)
	frame.grade.mono = t < 30
	if t < 30 then
		-- 0. The last fall, in slow motion and black and white.
		l.y, l.pose = lerp(3.5, 0, t / 26), if t < 24 then "Launched" else "DownFace"
		w.pose = "StandTall"
		frame.hideTitle = true
		frame.shot = shot("ko-fall", P(L, "Head", v(side * 2.5, 0.8, 3.2)), P(L, "Head"), 30, math.rad(-12))
		return frame
	end
	l.y, l.pose = 0, "DownFace"
	if t < 50 then
		-- 1. MAIN AU SOL: the loser's hand on the floor.
		w.pose = "StandTall"
		table.insert(frame.fx, { key = "ko-dust", kind = "dust", pos = v(l.x, 0, 0), direction = -side })
		frame.shot = shot("ko-hand", P(L, "RightHand", v(-1.3, 0.35, 1.6)), P(L, "RightHand"), 26)
	elseif t < 90 then
		-- 2. SCÈNE 1: loser in the foreground, winner standing, very low angle.
		w.pose = "StandTall"
		frame.shot = shot("ko-scene1", P(L, "Head", v(-side * 1.8, 0.35, 3.2)), P(W, "Head", v(0, -0.8, 0)), 58,
			math.rad(-4 * side), P(W, "UpperTorso"))
	elseif t < 108 then
		-- 3. DÉTAIL PIEDS: the winner's sneakers next to the fallen fighter.
		w.pose = "StandTall"
		frame.shot = shot("ko-feet", P(W, "LeftFoot", v(-side * 1.6, 0.35, 2.6)), P(W, "RightFoot"), 32)
	elseif t < 126 then
		-- 4. ZOOM VISAGE: the winner's face.
		w.pose = "ArmsCrossed"
		frame.shot = shot("ko-face", P(W, "Head", v(0.35, 0.05, 1.7)), P(W, "Head", v(0, 0.1, 0)), 18)
	elseif t < 160 then
		-- 5. SCÈNE 2: arms crossed, slight low angle, the K.O. in front.
		w.pose = "ArmsCrossed"
		frame.shot = shot("ko-scene2", P(W, "UpperTorso", v(-side * 1.2, -1.6, 7.5)), P(W, "UpperTorso", v(0, 0.3, 0)), 50,
			0, P(W, "UpperTorso"))
	elseif t < 176 then
		-- 6. DOS DU GAGNANT: he turns toward the torii and the sunset; we see his back.
		w.pose = "ArmsCrossed"
		w.lookDir = v(side * 0.15, 0, -1)
		frame.shot = shot("ko-back", P(W, "UpperTorso", v(side * 0.8, 0.9, 4.5)), At(v(w.x, 8, -60)), 50, 0, P(W, "UpperTorso"))
	elseif t < 188 then
		-- 7. PLAN LARGE ARÈNE.
		w.pose = "ArmsCrossed"
		frame.shot = shot("ko-wide", At(v(w.x, 10, 46)), At(v(w.x, 6, -20)), 38)
	else
		-- 8. FONDU NOIR / K.O.
		w.pose = "ArmsCrossed"
		frame.fade = true
		local data = ctx.characters[W]
		frame.title = { text = "K.O.", color = RED, sub = data.Name .. " " .. data.Skin .. " · VICTOIRE" }
		frame.shot = shot("ko-wide", At(v(w.x, 10, 46)), At(v(w.x, 6, -20)), 38)
	end
	return frame
end

-- ===================================================================== ENTRY POINTS

-- One frame of a cinematic. ctx = { cin, tick, views, anchors, moveData, config, characters }.
function Director.cinematic(ctx)
	local cin = ctx.cin
	local a, d = ctx.views[cin.attacker], ctx.views[cin.defender]
	if not a or not d then return nil end
	ctx.anchors.dir = ctx.anchors.dir or a.facing
	local dir = ctx.anchors.dir
	a.victory, a.pose, d.pose = false, nil, nil
	local data = ctx.moveData.Cinematics[cin.move]
	if cin.finish and ctx.tick >= data.Length then
		-- FINAL FINISH: the K.O. scene of the storyboard.
		return Director.ko(ctx, cin.attacker, cin.defender, a, d, math.min(ctx.tick - data.Length, Director.KO_SCENE))
	end
	local frame = newFrame()
	local kit = kitOf(ctx)
	local own = kit and KIT[kit.Name]
	if data.Type == "Awaken" then
		awakening(ctx, frame, a, d, ctx.tick, dir)
	elseif own and own[data.Type] then
		own[data.Type](ctx, frame, a, d, ctx.tick, dir)
	elseif data.Type == "Gate" then
		kaiten(ctx, frame, a, d, ctx.tick, dir)
	else
		rush(ctx, frame, a, d, ctx.tick, dir)
	end
	return frame
end

-- Is a match-winning K.O. being shown? Returns winner, loser and the scene tick.
function Director.victoryScene(world, config)
	if world.training or world.cinematic then return nil end
	local winner = world.winner
	if not winner or winner <= 0 then return nil end
	local w = world.fighters[winner]
	if not w or w.wins < config.RoundsToWin then return nil end
	local t
	if world.phase == "KO" then
		t = config.KOTicks - world.phaseTicks - 40 -- let the body land first
	elseif world.phase == "MatchEnd" then
		t = config.KOTicks - 40 + (config.MatchEndTicks - world.phaseTicks)
	else
		return nil
	end
	if t < 0 then return nil end
	return winner, 3 - winner, math.min(t, Director.KO_SCENE)
end

return Director
