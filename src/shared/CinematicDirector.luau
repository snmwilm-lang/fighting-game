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

local function attack(view, moves, id, active)
	view.state, view.move = "Attack", id
	view.moveFrame = if active then moves[id].startup + 1 else moves[id].startup
end

-- ===================================================================== KAIEN RUSH

local function rush(ctx, frame, a, d, tick, dir)
	local moves, data = ctx.moveData.Moves, ctx.moveData.Cinematics.KaienRush
	local cin = ctx.cin
	local A, D = cin.attacker, cin.defender
	local k = hitsBefore(data.Hits, tick)
	if tick < data.FinalTick - 16 then
		if k == 0 then
			a.x = d.x - dir * 2.8
			attack(a, moves, "KaienRush", true)
		else
			local behind = k % 2 == 0
			a.x = d.x + (if behind then dir else -dir) * 2.6
			a.y = if k % 3 == 0 then 1.6 else 0
			a.facing = if behind then -dir else dir
			attack(a, moves, RUSH[(k - 1) % #RUSH + 1], true)
		end
		d.state = "Hitstun"
		d.hitstop = if k > 0 and tick - data.Hits[k] < 6 then 1 else 0
		a.ghost = true
	elseif tick < data.FinalTick then
		a.x, a.y, a.facing = d.x - dir * 2.8, 0, dir
		attack(a, moves, "Smash", false)
		d.state, d.hitstop = "Hitstun", 0
	else
		a.x, a.y, a.facing = d.x - dir * 2.8, 0, dir
		attack(a, moves, "Smash", true)
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
local function style(ctx, frame, a, d, tick, dir, name)
	local moves, data = ctx.moveData.Moves, ctx.moveData.Cinematics.Awakening
	local cin, anchors, config = ctx.cin, ctx.anchors, ctx.config
	local A, D = cin.attacker, cin.defender
	local color = Director.STYLE_COLORS[name] or RED
	local start, final = data.Hits[#data.Hits] + 4, data.FinalTick
	local p = progress(tick, start, final)
	d.state = "Hitstun"
	if name == "TORNADE" then
		-- Rising spin: both fighters climb inside a tornado of ki.
		d.y = lerp(0, 9, p)
		a.x, a.y, a.facing = d.x - dir * 1.8, d.y - 0.5, dir
		a.state, a.move = "Attack", "DragonTornado"
		a.moveFrame = moves.DragonTornado.startup + 1 + (math.floor(tick / 4) % 2) * moves.DragonTornado.hitInterval
		if tick % 6 == 0 then
			table.insert(frame.fx, { key = "ring" .. tick, kind = "tornadoRing", pos = v(d.x, d.y + 1, 0), color = color })
		end
		-- Half orbit on the far side of the target, so KAI never stands between it and the lens.
		local angle = dir * (-0.2 + 1.5 * p)
		frame.shot = shot("tornade-orbit", P(D, "UpperTorso", v(math.sin(angle) * 11, 1, math.cos(angle) * 11)), P(D, "UpperTorso"), 50)
	elseif name == "RAFALE" then
		-- Barrage: a hundred fists in front of the target.
		a.x, a.y, a.facing = d.x - dir * 2.2, 0, dir
		a.state, a.move = "Attack", "KiFlurry"
		a.moveFrame = moves.KiFlurry.startup + 1 + (math.floor(tick / 2) % 2) * moves.KiFlurry.hitInterval
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
			attack(a, moves, "DragonFist", false)
			table.insert(frame.fx, { key = "dragon-charge", kind = "spark", pos = v(a.x, 2, 0), color = color, scale = 1.6 })
			frame.shot = shot("dragon-charge", P(A, "Head", v(dir * 2.5, -1.6, 4)), P(A, "Head"), 34, math.rad(8 * dir))
		else
			local q = progress(tick, start + (final - start) * 0.7, final)
			a.y, d.y = lerp(0, 6, q), lerp(0, 11, q)
			attack(a, moves, "DragonFist", true)
			table.insert(frame.fx, { key = "dragon-helix", kind = "dragonHelix", pos = v(d.x, 0, 0), color = color })
			frame.shot = shot("dragon-rise", At(v(d.x - dir * 3, 0.6, 6)), P(D, "UpperTorso"), 62, math.rad(12 * dir))
		end
	elseif name == "FOUDRE" then
		-- Leap into the storm, dive with lightning.
		if p < 0.65 then
			a.x, a.y, a.facing = d.x - dir * 1.5, lerp(1, 12, p / 0.65), dir
			a.state, a.move, a.moveFrame = "Attack", "AirSmash", 1
			if tick % 5 == 0 then
				table.insert(frame.fx, { key = "bolt" .. tick, kind = "lightning", from = v(d.x + ((tick * 37) % 9 - 4), 30, -4),
					to = v(a.x, a.y + 3, 0), color = color })
			end
			frame.shot = shot("foudre-sky", P(D, "UpperTorso", v(-dir * 3, -3, 6)), P(A, "Head"), 60, math.rad(10 * dir))
		else
			a.x, a.y, a.facing = d.x - dir * 1.8, lerp(12, d.y + 1, (p - 0.65) / 0.35), dir
			attack(a, moves, "AirSmash", true)
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
			attack(a, moves, "SpinKick", p >= 0.4)
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
			attack(a, moves, "Hammer", false)
			frame.shot = shot("lune-moon", P(D, "UpperTorso", v(dir * 4, -2.4, 9)), At(v(d.x, 11, -4)), 58)
		else
			a.y = lerp(10, d.y + 1, (p - 0.7) / 0.3)
			attack(a, moves, "Hammer", true)
			a.ghost = true
			frame.shot = shot("lune-dive", P(D, "UpperTorso", v(-dir * 5, 3, 6)), P(D, "UpperTorso"), 46)
		end
	else
		a.x, a.y, a.facing = d.x - dir * 1.5, lerp(1, 11, p), dir
		a.state, a.move, a.moveFrame = "Attack", "AirSmash", 1
		frame.shot = shot("style-default", P(D, "UpperTorso", v(-dir * 3, -3, 6)), P(A, "Head"), 60)
	end
end

local function awakening(ctx, frame, a, d, tick, dir)
	local moves, data = ctx.moveData.Moves, ctx.moveData.Cinematics.Awakening
	local cin = ctx.cin
	local A, D = cin.attacker, cin.defender
	local name = cin.style or "TORNADE"
	local color = Director.STYLE_COLORS[name] or RED
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
	elseif tick < data.Hits[#data.Hits] + 4 then
		-- 4. Strikes: a hard cut to a new camera angle on every hit.
		local k = math.max(1, hitsBefore(data.Hits, tick))
		local behind = k % 2 == 0
		a.x = d.x + (if behind then dir else -dir) * 2.5
		a.y = if k % 3 == 0 then 2 else 0
		a.facing = if behind then -dir else dir
		attack(a, moves, RUSH[(k * 3) % #RUSH + 1], true)
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
		style(ctx, frame, a, d, tick, dir, name)
	elseif tick < data.FinalTick + 14 then
		-- 7. Impact: wide frame, shockwave in the colour of the style.
		table.insert(frame.fx, { key = "eveil-impact", kind = "shockwave", pos = v(d.x, 0, 0), color = color })
		frame.shot = shot("eveil-impact", At(v(d.x, 9, 34)), At(v(d.x, 3, 0)), 46)
	else
		-- 8. Aftermath: KAI lands in a kiai, the target flies away (or falls for the K.O. scene).
		a.y, a.facing, a.pose = 0, dir, "Kiai"
		frame.title = { text = moves.Awakening.name, color = color, sub = name }
		frame.shot = shot("eveil-aftermath", P(A, "UpperTorso", v(-dir * 4, 3, 26)), P(A, "UpperTorso"), 42)
	end
end

-- ===================================================================== PORTE DES CIEUX

local function kaiten(ctx, frame, a, d, tick, dir)
	local moves, data = ctx.moveData.Moves, ctx.moveData.Cinematics.Kaiten
	local cin, anchors = ctx.cin, ctx.anchors
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
		attack(a, moves, if second then "Cross" else "Jab", true)
		frame.shot = shot("porte-setup" .. (if second then "2" else "1"),
			P(D, "Head", v(if second then dir * 3 else -dir * 3, 0.5, 4)), P(D, "Head"), 36)
	elseif tick < data.FinalTick then
		-- 6. Wind-up on the fist, everything stops: press R at the climax.
		d.x, d.y, d.state = gateX - dir * 1.5, 2.5, "Hitstun"
		a.x, a.y, a.facing = d.x - dir * 2.6, 1.6, dir
		attack(a, moves, "Finale", false)
		frame.grade.mono = tick >= data.PromptTicks[1] - 4
		frame.shot = shot("porte-fist", P(A, "RightHand", v(dir * 1.2, 0.3, 2.2)), P(A, "RightHand"), 22, math.rad(4))
	elseif tick < data.FinalTick + 22 then
		-- 7. The single blow: the gate shatters behind the target.
		a.x, a.y, a.facing = gateX - dir * 4.1, 1.6, dir
		attack(a, moves, "Finale", true)
		table.insert(frame.fx, { key = "shatter", kind = "gateShatter", color = energy })
		table.insert(frame.fx, { key = "shatter-wave", kind = "shockwave", pos = v(gateX, 3, -1), color = energy })
		frame.shot = shot("porte-shatter", At(v(gateX + dir * 4, 5, 18)), At(v(gateX - dir * 2, 4, 0)), 60)
	else
		-- 8. The world comes back.
		a.y, a.facing, a.pose = 0, dir, "Kiai"
		frame.title = { text = "開天", color = RED, sub = "PORTE DES CIEUX" }
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
	if cin.move == "Awakening" then
		awakening(ctx, frame, a, d, ctx.tick, dir)
	elseif cin.move == "Kaiten" then
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
