--[[
	Pure cinematic director: decides, for one rendered frame, where both fighters stand, which
	pose they hold, which camera shot is used and which effects / overlays are requested.
	No Roblox API and no require, so every cinematic can be replayed and checked offline
	(tests/CinematicDirector.test.luau, tests/Cinematography.test.luau with the real rig, and
	the storyboards of tests/Storyboard.luau). The client CinematicController executes it.

	Shots are composed, not placed by hand: frameOn() puts the camera at an angle around the
	subjects (relative to the attack direction), a pitch and the share of the frame they must
	fill, and keeps it clear of the bodies. Points can also be rig parts (Head, RightHand...)
	plus an offset, resolved by the client after the rigs are placed.
	Vectors are plain tables { x, y, z }; colours are hex strings.

	frame = {
		shot = { name, from, to, fov, roll, focus },  -- points: { slot, part, offset } or { position }
		grade = { crimson, void, mono },              -- colour grading switches
		kanjiBack = text?, title = { text, color, sub }?, hideTitle = bool?,
		fx = { { key, kind, ... } },                  -- effect requests, played once per key
		aura = slot?, fade = bool?,
		speedLines = color?,                          -- anime speed lines over the frame
		impact = { key, color }?,                     -- impact frame + zoom punch, once per key
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

local function smooth(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
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

-- ===================================================================== FRAMING

local ASPECT = 16 / 9
-- Vertical slices of a standing body (share of its height).
local BANDS = { full = { 0, 1.04 }, bust = { 0.44, 1.12 }, face = { 0.74, 1.04 }, waist = { 0.3, 0.85 }, legs = { 0, 0.55 } }

local function lying(view)
	return view.pose == "DownFace" or view.pose == "Launched" or view.state == "Launched" or view.state == "Knockdown"
		or (view.state == "KO" and view.pose ~= "StandTall")
end

-- Approximate volume of a staged body: { minX, minY, minZ, maxX, maxY, maxZ }.
local function volume(view, band)
	local x, y, z = view.x, view.y, view.z or 0
	if lying(view) then
		return { x - 1.8, y, z - 1, x + 1.8, y + 2.6, z + 1 }
	end
	local b = BANDS[band or "full"]
	return { x - 1.1, y + 5.7 * b[1], z - 0.9, x + 1.1, y + 5.7 * b[2], z + 0.9 }
end

--[[
	A composed shot of `subjects` (staged views, or { point = true, x, y, z } points).
	o.yaw: degrees around the vertical, relative to the attack: 0 = from the camera side of the
	arena (+Z), positive = swung toward the attacker's front (dir); o.pitch: degrees, positive
	looks down; o.fill: share of the frame height (or width) the subjects fill; o.band: body
	slice (full, bust, face, waist, legs); o.fov, o.roll (degrees); o.lift: aim offset in Y;
	o.clear: minimum distance to the subjects; o.focus: point of the depth of field.
]]
local function frameOn(name, dir, subjects, o)
	local minX, minY, minZ, maxX, maxY, maxZ = math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge
	for _, s in subjects do
		local box = if s.point then { s.x - 0.5, s.y - 0.5, (s.z or 0) - 0.5, s.x + 0.5, s.y + 0.5, (s.z or 0) + 0.5 }
			else volume(s, o.band)
		minX, minY, minZ = math.min(minX, box[1]), math.min(minY, box[2]), math.min(minZ, box[3])
		maxX, maxY, maxZ = math.max(maxX, box[4]), math.max(maxY, box[5]), math.max(maxZ, box[6])
	end
	local cx, cy, cz = (minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2
	local yaw, pitch = math.rad((o.yaw or 0) * dir), math.rad(o.pitch or 0)
	-- From the subjects toward the camera.
	local bx, by, bz = math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch)
	local rx, rz = math.cos(yaw), -math.sin(yaw) -- screen right
	local ux, uy, uz = -math.sin(pitch) * math.sin(yaw), math.cos(pitch), -math.sin(pitch) * math.cos(yaw)
	local halfW, halfH, halfD = 0, 0, 0
	for _, X in { minX, maxX } do
		for _, Y in { minY, maxY } do
			for _, Z in { minZ, maxZ } do
				local dx, dy, dz = X - cx, Y - cy, Z - cz
				halfW = math.max(halfW, math.abs(dx * rx + dz * rz))
				halfH = math.max(halfH, math.abs(dx * ux + dy * uy + dz * uz))
				halfD = math.max(halfD, math.abs(dx * bx + dy * by + dz * bz))
			end
		end
	end
	local fov = o.fov or 40
	local size = math.max(halfH, halfW / ASPECT)
	local distance = size / math.tan(math.rad(fov) / 2) / (o.fill or 0.8) + halfD
	distance = math.max(distance, halfD + (o.clear or 2.2))
	local ty = cy + (o.lift or 0)
	local camX, camY, camZ = cx + bx * distance, ty + by * distance, cz + bz * distance
	if camY < 0.45 then camY = 0.45 end -- never under the deck
	return shot(name, At(v(camX, camY, camZ)), At(v(cx, ty, cz)), fov, math.rad(o.roll or 0), o.focus)
end

-- ===================================================================== SHARED STAGING

-- The target's place when the cinematic starts: staged positions hang on it, so the smoothing
-- of the displayed views never makes them drift.
local function center(ctx, d)
	ctx.anchors.center = ctx.anchors.center or d.x
	return ctx.anchors.center
end

-- Places `a` on the far half of a circle around the target (angle 0 = in front of it on the
-- attack side, pi = behind it) and turns it toward the target. The camera, on the near
-- side, always sees the target.
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

local function spark(frame, key, pos, color, scale)
	table.insert(frame.fx, { key = key, kind = "spark", pos = pos, color = color, scale = scale or 1 })
end

local function impact(frame, key, pos, color, scale)
	table.insert(frame.fx, { key = key .. "-wave", kind = "shockwave", pos = v(pos.x, 0, 0), color = color })
	spark(frame, key .. "-spark", pos, color, scale or 2.4)
	frame.impact = { key = key, color = color }
end

-- A rotating set of strong angles for hard cuts on each hit of a barrage.
local CUTS = {
	{ yaw = 28, pitch = 8, fill = 0.78, fov = 42, roll = 0 },          -- three-quarter two-shot
	{ yaw = -30, pitch = 4, fill = 0.86, fov = 38, roll = -6 },        -- medium on the blows
	{ yaw = 8, pitch = 62, fill = 0.7, fov = 46, roll = 0 },           -- top-down
	{ yaw = 52, pitch = -10, fill = 0.85, fov = 48, roll = 10 },       -- low dutch angle
	{ yaw = -48, pitch = 14, fill = 0.62, fov = 40, roll = 0 },        -- wide from behind the attacker
}
local function cut(name, dir, a, d, k, tilt)
	local c = CUTS[(k - 1) % #CUTS + 1]
	return frameOn(name, dir, { a, d }, { yaw = c.yaw, pitch = c.pitch, fill = c.fill, fov = c.fov, roll = c.roll * (tilt or 1),
		band = c.band })
end

-- ===================================================================== KAIEN RUSH

local function rush(ctx, frame, a, d, tick, dir)
	local cin = ctx.cin
	local moves, data = ctx.moveData.Moves, ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local color = ctx.characters[A].Energy
	local cx = center(ctx, d)
	local k = hitsBefore(data.Hits, tick)
	local windup = data.FinalTick - 16
	if tick >= data.FinalTick then
		a.x, a.y, a.facing = cx - dir * 2.8, 0, dir
		attack(a, moves, role(ctx, "Smash"), true)
		if tick < data.FinalTick + 12 then
			impact(frame, "rush-final", v(cx, 3.6, 0.6), color, 3)
			frame.shot = frameOn("rush-impact", dir, { a, d }, { yaw = 62, pitch = 6, fill = 0.76, fov = 46, roll = 8, focus = P(D, "UpperTorso") })
		else
			frame.shot = frameOn("rush-follow", dir, { a, d }, { yaw = 12, pitch = 12, fill = 0.55, fov = 42, focus = P(D, "UpperTorso") })
		end
		return
	end
	d.x, d.state = cx, "Hitstun"
	if tick < 10 then
		-- 1. Ready: KAI far away, fists clenched, seen from the front.
		a.x, a.facing, a.pose = cx - dir * 9, dir, "Kiai"
		frame.aura = A
		frame.shot = frameOn("rush-ready", dir, { a }, { yaw = 32, pitch = -4, fill = 0.95, fov = 34, band = "bust", focus = P(A, "Head") })
	elseif tick < data.Hits[1] then
		-- 2. The dash, tracked from the side with speed lines.
		a.x, a.facing, a.pose = lerp(cx - dir * 9, cx - dir * 2.8, smooth(progress(tick, 10, data.Hits[1]))), dir, "Dash"
		a.ghost = true
		frame.speedLines = color
		frame.shot = frameOn("rush-dash", dir, { a }, { yaw = 4, pitch = -6, fill = 0.72, fov = 46, focus = P(A, "UpperTorso") })
	elseif tick < windup then
		-- 3. The barrage: KAI blinks around the target; a hard cut every third hit.
		local behind = k % 2 == 0
		a.x = cx + (if behind then dir else -dir) * 2.6
		a.y = if k % 3 == 0 then 1.6 else 0
		a.facing = if behind then -dir else dir
		attack(a, moves, role(ctx, RUSH[(k - 1) % #RUSH + 1]), true)
		a.ghost = true
		d.hitstop = if tick - data.Hits[k] < 6 then 1 else 0
		spark(frame, "rush-hit" .. k, v(cx, 3.4 + (k % 3) * 0.4, 0.6), color, 1.2)
		frame.speedLines = color
		if k % 3 == 0 then
			if tick - data.Hits[k] < 2 then frame.impact = { key = "rush-cut" .. k, color = color } end
			frame.shot = cut("rush-cut" .. ((k / 3 - 1) % #CUTS + 1), dir, a, d, k / 3)
		else
			local angle = lerp(-55, 55, progress(tick, data.Hits[1], windup))
			frame.shot = frameOn("rush-orbit", dir, { a, d }, { yaw = angle, pitch = 12 + math.sin(tick / 9) * 6, fill = 0.66,
				fov = 44, focus = P(D, "UpperTorso") })
		end
	else
		-- 4. Wind-up: back in front, the camera low behind KAI pushes in on both.
		a.x, a.y, a.facing = cx - dir * 2.8, 0, dir
		attack(a, moves, role(ctx, "Smash"), false)
		spark(frame, "rush-charge", v(a.x - dir * 0.6, 3, 0.6), color, 1.6)
		frame.shot = frameOn("rush-windup", dir, { a, d }, { yaw = -38, pitch = -7, fill = lerp(0.8, 1.02, progress(tick, windup, data.FinalTick)),
			fov = 40, focus = P(A, "UpperTorso") })
	end
end

-- ===================================================================== ÉVEIL ÉCARLATE

-- Finale picked by the route that was played.
-- `name` is the finale template (TORNADE, RAFALE, DRAGON, FOUDRE, MUR, LUNE) of the route.
local function style(ctx, frame, a, d, tick, dir, name, color)
	local cin, anchors, config = ctx.cin, ctx.anchors, ctx.config
	local moves, data = ctx.moveData.Moves, ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local cx = center(ctx, d)
	local tornado, flurry, fist = role(ctx, "DragonTornado"), role(ctx, "KiFlurry"), role(ctx, "DragonFist")
	local dive, heel, axe = role(ctx, "AirSmash"), role(ctx, "SpinKick"), role(ctx, "Hammer")
	local start, final = data.Hits[#data.Hits] + 4, data.FinalTick
	local p = progress(tick, start, final)
	d.x, d.state = cx, "Hitstun"
	if name == "TORNADE" then
		-- Rising spin: both fighters climb inside a tornado of ki; the camera circles them.
		d.y = lerp(0, 9, smooth(p))
		a.x, a.y, a.facing = cx - dir * 1.9, d.y - 0.5, dir
		a.state, a.move = "Attack", tornado
		a.moveFrame = moves[tornado].startup + 1 + (math.floor(tick / 4) % 2) * moves[tornado].hitInterval
		if tick % 6 == 0 then
			table.insert(frame.fx, { key = "ring" .. tick, kind = "tornadoRing", pos = v(cx, d.y + 1, 0), color = color })
		end
		frame.speedLines = color
		frame.shot = frameOn("tornade-orbit", dir, { a, d }, { yaw = lerp(-40, 70, p), pitch = lerp(-14, 10, p), fill = 0.72,
			fov = 50, focus = P(D, "UpperTorso") })
	elseif name == "RAFALE" then
		-- Barrage: a hundred fists in front of the target.
		a.x, a.y, a.facing = cx - dir * 2.3, 0, dir
		a.state, a.move = "Attack", flurry
		a.moveFrame = moves[flurry].startup + 1 + (math.floor(tick / 2) % 2) * moves[flurry].hitInterval
		if tick % 3 == 0 then
			spark(frame, "fist" .. tick, v(cx - dir * 0.6, 3.6 + (tick % 7) * 0.2, 0.5), color, 0.7)
		end
		frame.speedLines = color
		if p < 0.5 then
			frame.shot = frameOn("rafale-front", dir, { a, d }, { yaw = 58, pitch = 2, fill = 1.05, fov = 38, band = "bust", roll = -6,
				focus = P(A, "UpperTorso") })
		else
			frame.shot = frameOn("rafale-side", dir, { a, d }, { yaw = 0, pitch = 4, fill = lerp(0.8, 1.05, (p - 0.5) * 2), fov = 36,
				band = "bust", focus = P(D, "UpperTorso") })
		end
	elseif name == "DRAGON" then
		-- Crouched charge, then the rising dragon fist with a ki dragon spiralling up.
		a.x, a.facing = cx - dir * 1.7, dir
		if p < 0.6 then
			a.y = 0
			attack(a, moves, fist, false)
			spark(frame, "dragon-charge", v(a.x, 2, 0.4), color, 1.6)
			frame.shot = frameOn("dragon-charge", dir, { a, d }, { yaw = -36, pitch = -10, fill = lerp(0.85, 1, p / 0.6), fov = 40,
				focus = P(A, "UpperTorso") })
		else
			local q = smooth(progress(p, 0.6, 1))
			a.y, d.y = lerp(0, 6, q), lerp(0, 11, q)
			attack(a, moves, fist, true)
			table.insert(frame.fx, { key = "dragon-helix", kind = "dragonHelix", pos = v(cx, 0, 0), color = color })
			frame.impact = { key = "dragon-rise", color = color }
			frame.shot = frameOn("dragon-rise", dir, { a, d }, { yaw = -18, pitch = -24, fill = 0.78, fov = 58, roll = 12,
				focus = P(D, "UpperTorso") })
		end
	elseif name == "FOUDRE" then
		-- Leap into the storm, dive with lightning.
		if p < 0.62 then
			a.x, a.y, a.facing = cx - dir * 1.6, lerp(1, 12, smooth(p / 0.62)), dir
			a.state, a.move, a.moveFrame = "Attack", dive, 1
			if tick % 5 == 0 then
				table.insert(frame.fx, { key = "bolt" .. tick, kind = "lightning", from = v(cx + ((tick * 37) % 9 - 4), 30, -4),
					to = v(a.x, a.y + 3, 0), color = color })
			end
			frame.shot = frameOn("foudre-sky", dir, { a, d }, { yaw = -24, pitch = -26, fill = 0.7, fov = 56, roll = 8,
				focus = P(A, "UpperTorso") })
		else
			a.x, a.y, a.facing = cx - dir * 1.9, lerp(12, 1, smooth((p - 0.62) / 0.38)), dir
			attack(a, moves, dive, true)
			a.ghost = true
			frame.speedLines = color
			if tick % 3 == 0 then
				table.insert(frame.fx, { key = "bolt" .. tick, kind = "lightning", from = v(a.x, a.y + 12, 0), to = v(cx, 3, 0), color = color })
			end
			frame.shot = frameOn("foudre-dive", dir, { a, d }, { yaw = 44, pitch = 16, fill = 0.75, fov = 46, focus = P(D, "UpperTorso") })
		end
	elseif name == "MUR" then
		-- Spinning heel that sends the target across the arena into the wall.
		anchors.wall = anchors.wall or {
			from = cx, to = math.clamp(cx + dir * 14, config.ArenaMinX - 4, config.ArenaMaxX + 4),
		}
		local wallX = anchors.wall.to
		if p < 0.5 then
			a.x, a.y, a.facing = cx - dir * 2.5, 0, dir
			attack(a, moves, heel, p >= 0.36)
			frame.shot = frameOn("mur-kick", dir, { a, d }, { yaw = 30, pitch = -4, fill = 0.92, fov = 40, focus = P(A, "UpperTorso") })
		else
			local q = progress(p, 0.5, 1)
			d.x, d.y, d.pose = lerp(cx, wallX, smooth(q)), lerp(3, 4, q), "Launched"
			if q > 0.85 then
				table.insert(frame.fx, { key = "mur-wall", kind = "shockwave", pos = v(wallX, 4, 0), color = color })
				frame.impact = { key = "mur-wall", color = color }
			end
			frame.speedLines = color
			frame.shot = frameOn("mur-wall", dir, { d, { point = true, x = wallX, y = 4, z = 0 } }, { yaw = -30, pitch = 6, fill = 0.7,
				fov = 50, focus = P(D, "UpperTorso") })
		end
	elseif name == "LUNE" then
		-- A giant crescent rises behind KAI, then the axe kick from the moon.
		a.x, a.facing = cx - dir * 1.7, dir
		table.insert(frame.fx, { key = "lune-crescent", kind = "crescent", pos = v(cx, 13, -6), color = color, keep = true })
		if p < 0.65 then
			a.y = lerp(1, 10, smooth(p / 0.65))
			attack(a, moves, axe, false)
			frame.shot = frameOn("lune-moon", dir, { a, { point = true, x = cx, y = 13, z = -6 } }, { yaw = 20, pitch = -18, fill = 0.75,
				fov = 52, focus = P(A, "UpperTorso") })
		else
			a.y = lerp(10, 1.5, smooth((p - 0.65) / 0.35))
			attack(a, moves, axe, true)
			a.ghost = true
			frame.speedLines = color
			frame.shot = frameOn("lune-dive", dir, { a, d }, { yaw = -40, pitch = 18, fill = 0.78, fov = 46, focus = P(D, "UpperTorso") })
		end
	else
		a.x, a.y, a.facing = cx - dir * 1.6, lerp(1, 11, p), dir
		a.state, a.move, a.moveFrame = "Attack", dive, 1
		frame.shot = frameOn("style-default", dir, { a, d }, { yaw = 20, pitch = -12, fill = 0.7, fov = 52, focus = P(A, "UpperTorso") })
	end
end

local KIT = {} -- kit-specific ultimates, defined below

local function awakening(ctx, frame, a, d, tick, dir)
	local cin = ctx.cin
	local moves, data = ctx.moveData.Moves, ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local cx = center(ctx, d)
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
	d.x = cx
	if tick < 24 then
		-- 1. Close-up on the face, a giant kanji painted over the frame.
		frame.kanjiBack = ctx.characters[A].Kanji
		a.x, a.y, a.facing, a.pose = cx - dir * 9, 0, dir, "Kiai"
		d.state = "Hitstun"
		frame.shot = frameOn("eveil-eyes", dir, { a }, { yaw = 40, pitch = 6, fill = lerp(0.95, 1.12, tick / 24), fov = 30, band = "bust",
			focus = P(A, "Head") })
	elseif tick < 50 then
		-- 2. Low-angle hero shot while the aura erupts, slow push-in.
		a.x, a.y, a.facing, a.pose = cx - dir * 9, 0, dir, "Kiai"
		d.state = "Hitstun"
		frame.aura = A
		frame.shot = frameOn("eveil-hero", dir, { a }, { yaw = 26, pitch = -20, fill = lerp(0.82, 0.95, progress(tick, 24, 50)), fov = 44,
			roll = -6, focus = P(A, "Head") })
	elseif tick < data.Hits[1] then
		-- 3. Tracking shot of the dash.
		a.x, a.y, a.facing, a.pose = lerp(cx - dir * 9, cx - dir * 2.5, smooth(progress(tick, 50, data.Hits[1]))), 0, dir, "Dash"
		a.ghost = true
		d.state = "Hitstun"
		frame.speedLines = color
		frame.shot = frameOn("eveil-dash", dir, { a }, { yaw = 2, pitch = -4, fill = 0.7, fov = 44, focus = P(A, "UpperTorso") })
	elseif staged and tick < data.FinalTick then
		staged(ctx, frame, a, d, tick, dir, color)
	elseif tick < data.Hits[#data.Hits] + 4 then
		-- 4. Strikes: a hard cut to a new camera angle on every hit.
		local k = math.max(1, hitsBefore(data.Hits, tick))
		local behind = k % 2 == 0
		a.x = cx + (if behind then dir else -dir) * 2.5
		a.y = if k % 3 == 0 then 2 else 0
		a.facing = if behind then -dir else dir
		attack(a, moves, role(ctx, RUSH[(k * 3) % #RUSH + 1]), true)
		a.ghost = true
		d.state = "Hitstun"
		d.hitstop = if tick - data.Hits[k] < 6 then 1 else 0
		spark(frame, "eveil-hit" .. k, v(cx, 3.5, 0.6), color, 1.3)
		if tick - data.Hits[k] < 2 then frame.impact = { key = "eveil-hit" .. k, color = color } end
		frame.speedLines = color
		frame.shot = cut("eveil-strike" .. k, dir, a, d, k)
	elseif tick < data.FinalTick then
		style(ctx, frame, a, d, tick, dir, template, color)
	elseif tick < data.FinalTick + 14 then
		-- 7. Impact: wide frame, shockwave in the colour of the style.
		table.insert(frame.fx, { key = "eveil-impact", kind = "shockwave", pos = v(cx, 0, 0), color = color })
		frame.impact = { key = "eveil-impact", color = color }
		frame.shot = frameOn("eveil-impact", dir, { a, d }, { yaw = 14, pitch = 22, fill = 0.55, fov = 46, focus = P(D, "UpperTorso") })
	else
		-- 8. Aftermath: the fighter lands in a kiai, the target flies away (or falls).
		a.y, a.facing, a.pose = 0, dir, "Kiai"
		frame.title = { text = moves[cin.move].name, color = color, sub = name }
		frame.shot = frameOn("eveil-aftermath", dir, { a }, { yaw = 30, pitch = -6, fill = lerp(0.7, 0.82, progress(tick, data.FinalTick + 14,
			data.Length)), fov = 40, focus = P(A, "UpperTorso") })
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
	local gateTop = { point = true, x = gateX, y = 10, z = -1 }
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
		-- 2. A giant torii rises behind the target: low wide angle.
		a.x, a.facing, a.pose = originX - dir * 4, dir, "Kiai"
		d.x, d.state = originX, "Hitstun"
		table.insert(frame.fx, { key = "gate", kind = "gate", pos = v(gateX, 0, -1), dir = dir, color = energy, keep = true })
		frame.shot = frameOn("porte-rise", dir, { a, d, gateTop }, { yaw = -20, pitch = -14, fill = 0.82, fov = 52, roll = -5,
			focus = P(D, "UpperTorso") })
	elseif tick < 110 then
		-- 3. The gate opens; the target is dragged toward the crimson light, KAI walks after it.
		local p = progress(tick, 70, 110)
		table.insert(frame.fx, { key = "gate-open", kind = "gateOpen" })
		d.x, d.y, d.pose = lerp(originX, gateX - dir * 1.5, smooth(p)), lerp(0, 2.5, p), "Launched"
		a.x, a.facing, a.state, a.vx = lerp(originX - dir * 4, gateX - dir * 6, p), dir, "Walking", dir * 4
		frame.shot = frameOn("porte-back", dir, { a, gateTop }, { yaw = -58, pitch = -4, fill = 0.86, fov = 48, focus = P(A, "UpperTorso") })
	elseif tick < data.Hits[1] then
		-- 4. Inside the crimson world: KAI appears right in front of the target.
		frame.grade.crimson = true
		d.x, d.y, d.pose = gateX - dir * 1.5, 2.5, "Launched"
		a.x, a.y, a.facing, a.pose = d.x - dir * 2.6, 1.6, dir, "Kiai"
		a.ghost = true
		frame.shot = frameOn("porte-crimson", dir, { a }, { yaw = -40, pitch = -6, fill = 0.95, fov = 34, band = "bust", focus = P(A, "Head") })
	elseif tick < data.PromptTicks[1] - 14 then
		-- 5. Two blows to set it up.
		d.x, d.y = gateX - dir * 1.5, 2.5
		d.state, d.hitstop = "Hitstun", if (tick - data.Hits[1]) % 8 < 5 then 1 else 0
		a.x, a.y, a.facing = d.x - dir * 2.5, 1.6, dir
		local second = tick >= data.Hits[2]
		attack(a, moves, role(ctx, if second then "Cross" else "Jab"), true)
		spark(frame, "porte-hit" .. (if second then 2 else 1), v(d.x, 5, 0.6), energy, 1.2)
		frame.shot = frameOn("porte-setup" .. (if second then "2" else "1"), dir, { a, d },
			{ yaw = if second then 40 else -26, pitch = 4, fill = 0.92, fov = 38, focus = P(D, "UpperTorso") })
	elseif tick < data.FinalTick then
		-- 6. Wind-up, everything stops: press R at the climax. Slow push-in from below.
		d.x, d.y, d.state = gateX - dir * 1.5, 2.5, "Hitstun"
		a.x, a.y, a.facing = d.x - dir * 2.7, 1.6, dir
		attack(a, moves, role(ctx, "Finale"), false)
		frame.grade.mono = tick >= data.PromptTicks[1] - 4
		spark(frame, "porte-charge", v(a.x - dir * 0.6, 4.4, 0.6), energy, 1.8)
		frame.shot = frameOn("porte-fist", dir, { a, d }, { yaw = -34, pitch = -10, fill = lerp(0.85, 1.1, progress(tick,
			data.PromptTicks[1] - 14, data.FinalTick)), fov = 36, focus = P(A, "UpperTorso") })
	elseif tick < data.FinalTick + 22 then
		-- 7. The single blow: the gate shatters behind the target.
		a.x, a.y, a.facing = gateX - dir * 4.2, 1.6, dir
		attack(a, moves, role(ctx, "Finale"), true)
		table.insert(frame.fx, { key = "shatter", kind = "gateShatter", color = energy })
		table.insert(frame.fx, { key = "shatter-wave", kind = "shockwave", pos = v(gateX, 3, -1), color = energy })
		frame.impact = { key = "porte-shatter", color = energy }
		frame.shot = frameOn("porte-shatter", dir, { a, d, gateTop }, { yaw = 30, pitch = 6, fill = 0.8, fov = 54, focus = P(D, "UpperTorso") })
	else
		-- 8. The world comes back.
		a.y, a.facing, a.pose = 0, dir, "Kiai"
		local title = kitOf(ctx) and kitOf(ctx).GateTitle or { text = "開天", sub = "PORTE DES CIEUX" }
		frame.title = { text = title.text, color = RED, sub = title.sub }
		frame.shot = frameOn("porte-after", dir, { a }, { yaw = -24, pitch = -6, fill = 0.75, fov = 40, focus = P(A, "UpperTorso") })
	end
end

-- ===================================================================== KIT ULTIMATES
--[[
	TARO, ZEPHYR and AKEMI stage their three ultimates their own way (Wilhem's ultimate
	sheet); KAI keeps KAIEN RUSH, ÉVEIL ÉCARLATE and 開天. The authoritative timing (hits,
	prompt, final blow) is the same for every kit: only the staging differs.
	  TARO   1 RUSH DÉVASTATEUR     2 UPPERCUT CÉLESTE    3 TEMPÊTE DE CROCHETS
	  ZEPHYR 1 VENT TRANCHEUR       2 DRAGON ASCENDANT    3 CYCLONE FURIEUX
	  AKEMI  1 OMBRES MULTIPLES     2 TEMPS SUSPENDU      3 DANSE FANTÔME
]]

-- Rush opening shared by the kits: ready pose far away, then the dash.
local function rushOpening(ctx, frame, a, d, tick, dir, prefix, cx, color, startX)
	local data = ctx.moveData.Cinematics[ctx.cin.move]
	local A = ctx.cin.attacker
	if tick < 10 then
		a.x, a.facing, a.pose = cx - dir * startX, dir, "Kiai"
		frame.aura = A
		frame.shot = frameOn(prefix .. "-ready", dir, { a }, { yaw = 34, pitch = -4, fill = 0.95, fov = 34, band = "bust", focus = P(A, "Head") })
	else
		a.x, a.facing, a.pose = lerp(cx - dir * startX, cx - dir * 2.6, smooth(progress(tick, 10, data.Hits[1]))), dir, "Dash"
		a.ghost = true
		frame.speedLines = color
		frame.shot = frameOn(prefix .. "-dash", dir, { a }, { yaw = 4, pitch = -6, fill = 0.72, fov = 46, focus = P(A, "UpperTorso") })
	end
end

-- Rush ending shared by the kits: wind-up, impact, follow.
local function rushEnding(ctx, frame, a, d, tick, dir, prefix, cx, color, finisher)
	local data = ctx.moveData.Cinematics[ctx.cin.move]
	local moves = ctx.moveData.Moves
	local A, D = ctx.cin.attacker, ctx.cin.defender
	a.x, a.y, a.z, a.lookDir, a.facing = cx - dir * 2.7, 0, nil, nil, dir
	if tick < data.FinalTick then
		attack(a, moves, role(ctx, finisher), false)
		spark(frame, prefix .. "-charge", v(a.x - dir * 0.5, 3, 0.6), color, 1.6)
		frame.shot = frameOn(prefix .. "-windup", dir, { a, d }, { yaw = -38, pitch = -7,
			fill = lerp(0.8, 1.02, progress(tick, data.FinalTick - 16, data.FinalTick)), fov = 40, focus = P(A, "UpperTorso") })
	elseif tick < data.FinalTick + 12 then
		attack(a, moves, role(ctx, finisher), true)
		impact(frame, prefix .. "-final", v(cx, 3.8, 0.6), color, 3)
		frame.shot = frameOn(prefix .. "-impact", dir, { a, d }, { yaw = 62, pitch = 6, fill = 0.76, fov = 46, roll = 8, focus = P(D, "UpperTorso") })
	else
		attack(a, moves, role(ctx, finisher), true)
		frame.shot = frameOn(prefix .. "-follow", dir, { a, d }, { yaw = 12, pitch = 12, fill = 0.55, fov = 42, focus = P(D, "UpperTorso") })
	end
end

-- Common opening of the three gates: the kit's kanji burns on the floor, seen from above,
-- then a low hero shot of the attacker.
local function gateSeal(ctx, frame, a, d, cx, dir, prefix, tick)
	local A = ctx.cin.attacker
	a.x, a.facing, a.pose = cx - dir * 6.5, dir, "Kiai"
	d.x, d.state = cx, "Hitstun"
	if tick < 18 then
		local mid = (a.x + d.x) / 2
		table.insert(frame.fx, { key = "seal", kind = "kanjiSeal", pos = v(mid, 0.06, 0), color = ctx.characters[A].Energy,
			text = ctx.characters[A].Kanji, keep = true })
		frame.shot = shot(prefix .. "-seal", At(v(mid, 22, 2)), At(v(mid, 0, 0)), 50, math.rad(90))
	else
		frame.aura = A
		frame.shot = frameOn(prefix .. "-hero", dir, { a }, { yaw = -24, pitch = -18, fill = 0.88, fov = 44, roll = -5, focus = P(A, "Head") })
	end
end

-- Common end of the three gates: the two setup blows, the wind-up (press R at the climax),
-- the final blow, the title. `final` stages the final blow's effects.
local function gateEnd(ctx, frame, a, d, tick, dir, cx, prefix, final)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local color = ctx.characters[A].Energy
	d.x = cx
	a.z, a.lookDir = nil, nil
	if tick < data.PromptTicks[1] - 14 then
		d.state, d.hitstop = "Hitstun", if tick >= data.Hits[1] and (tick - data.Hits[1]) % 8 < 5 then 1 else 0
		a.x, a.facing = cx - dir * 2.5, dir
		local second = tick >= data.Hits[2]
		attack(a, moves, role(ctx, if second then "Cross" else "Jab"), tick >= data.Hits[1])
		if tick >= data.Hits[1] then spark(frame, prefix .. "-hit" .. (if second then 2 else 1), v(cx, 3.6, 0.6), color, 1.2) end
		frame.shot = frameOn(prefix .. "-setup" .. (if second then "2" else "1"), dir, { a, d },
			{ yaw = if second then 40 else 16, pitch = 4, fill = 0.84, fov = 38, focus = P(D, "UpperTorso") })
	elseif tick < data.FinalTick then
		d.state = "Hitstun"
		a.x, a.facing = cx - dir * 2.7, dir
		attack(a, moves, role(ctx, "Finale"), false)
		frame.grade.mono = tick >= data.PromptTicks[1] - 4
		spark(frame, prefix .. "-charge", v(a.x - dir * 0.5, 3, 0.6), color, 1.8)
		frame.shot = frameOn(prefix .. "-windup", dir, { a, d }, { yaw = -34, pitch = -10, fill = lerp(0.85, 1.1, progress(tick,
			data.PromptTicks[1] - 14, data.FinalTick)), fov = 36, focus = P(A, "UpperTorso") })
	elseif tick < data.FinalTick + 22 then
		a.x, a.facing = cx - dir * 2.7, dir
		attack(a, moves, role(ctx, "Finale"), true)
		final(color)
		frame.impact = { key = prefix .. "-final", color = color }
		frame.shot = frameOn(prefix .. "-final", dir, { a, d }, { yaw = 52, pitch = 8, fill = 0.66, fov = 50, roll = 7, focus = P(D, "UpperTorso") })
	else
		-- A step back from where the target lands.
		a.x, a.y, a.facing, a.pose = cx - dir * 4.2, 0, dir, "Kiai"
		local title = kitOf(ctx).GateTitle
		frame.title = { text = title.text, color = color, sub = title.sub }
		frame.shot = frameOn(prefix .. "-after", dir, { a }, { yaw = -24, pitch = -6, fill = 0.75, fov = 40, focus = P(A, "UpperTorso") })
	end
end

-- ---------------------------------------------------------------- TARO 火 · boxer

local TARO_RUSH = { "Jab", "Cross", "Elbow", "BodyBlow", "Kick", "SpinKick", "Uppercut" }

KIT.TARO = {}

-- RUSH DÉVASTATEUR: a straight charge, then punch after punch from the front, pushing in.
function KIT.TARO.Rush(ctx, frame, a, d, tick, dir)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local color = ctx.characters[A].Energy
	local cx = center(ctx, d)
	if tick < data.FinalTick then d.x = cx end -- then the simulation throws it
	if tick < data.FinalTick - 16 then d.state = "Hitstun" end
	if tick < data.Hits[1] then return rushOpening(ctx, frame, a, d, tick, dir, "taro-rush", cx, color, 8) end
	if tick >= data.FinalTick - 16 then return rushEnding(ctx, frame, a, d, tick, dir, "taro-rush", cx, color, "Smash") end
	local k = hitsBefore(data.Hits, tick)
	a.x, a.facing = cx - dir * 2.3, dir
	attack(a, moves, role(ctx, TARO_RUSH[(k - 1) % #TARO_RUSH + 1]), true)
	d.hitstop = if tick - data.Hits[k] < 5 then 1 else 0
	spark(frame, "taro-hit" .. k, v(cx - dir * 0.5, 3.4 + (k % 3) * 0.4, 0.6), color, 1.4)
	if tick - data.Hits[k] < 2 and k % 2 == 0 then frame.impact = { key = "taro-hit" .. k, color = color } end
	-- Alternating: tight on the fists from the front, low behind TARO, a wide breather.
	local view = k % 3
	if view == 1 then
		frame.shot = frameOn("taro-rush-front", dir, { a, d }, { yaw = 60, pitch = 2, fill = 1.05, fov = 38, band = "bust", roll = -5,
			focus = P(A, "UpperTorso") })
	elseif view == 2 then
		frame.shot = frameOn("taro-rush-low", dir, { a, d }, { yaw = -36, pitch = -9, fill = 0.92, fov = 44, focus = P(D, "UpperTorso") })
	else
		frame.shot = frameOn("taro-rush-wide", dir, { a, d }, { yaw = 10, pitch = 10, fill = 0.68, fov = 42, focus = P(D, "UpperTorso") })
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
		a.x, a.facing = cx - dir * 2.3, dir
		attack(a, moves, role(ctx, TARO_RUSH[(k * 2) % 4 + 1]), true)
		d.hitstop = if tick - data.Hits[k] < 6 then 1 else 0
		spark(frame, "celeste-hit" .. k, v(cx - dir * 0.5, 3.2, 0.6), color, 1.3)
		if tick - data.Hits[k] < 2 then frame.impact = { key = "celeste-hit" .. k, color = color } end
		frame.shot = cut("taro-celeste-blow" .. ((k - 1) % #CUTS + 1), dir, a, d, k)
		return
	end
	local p = progress(tick, start, final)
	a.x, a.facing = cx - dir * 1.8, dir
	if p < 0.25 then
		attack(a, moves, role(ctx, "Uppercut"), false)
		spark(frame, "celeste-charge", v(a.x, 1.6, 0.6), color, 1.8)
		frame.shot = frameOn("taro-celeste-charge", dir, { a, d }, { yaw = -36, pitch = -10, fill = lerp(0.85, 1, p / 0.25), fov = 40,
			focus = P(A, "UpperTorso") })
	elseif p < 0.6 then
		local q = smooth(progress(p, 0.25, 0.6))
		attack(a, moves, role(ctx, "Uppercut"), true)
		a.y, d.y = lerp(0, 3, q), lerp(0, 10, q)
		table.insert(frame.fx, { key = "celeste-pillar", kind = "dragonHelix", pos = v(cx, 0, 0), color = color })
		frame.impact = { key = "celeste-up", color = color }
		frame.shot = frameOn("taro-celeste-rise", dir, { a, d }, { yaw = -18, pitch = -26, fill = 0.78, fov = 58, roll = 12,
			focus = P(D, "UpperTorso") })
	else
		local q = progress(p, 0.6, 1)
		d.y, d.pose = 10, "Launched"
		a.x, a.y = cx - dir * 1.3, lerp(3, 12.5, smooth(math.min(1, q / 0.6)))
		attack(a, moves, role(ctx, "AirSmash"), q > 0.7)
		a.ghost = q > 0.7
		if q > 0.7 then frame.speedLines = color end
		frame.shot = frameOn("taro-celeste-air", dir, { a, d }, { yaw = 36, pitch = 18, fill = 0.75, fov = 48, focus = P(D, "UpperTorso") })
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
		gateSeal(ctx, frame, a, d, cx, dir, "taro-tempete", tick)
		return
	end
	if tick < data.Hits[1] - 6 then
		local p = progress(tick, 30, data.Hits[1] - 6)
		frame.grade.crimson = true
		d.x, d.state = cx, "Hitstun"
		local step = math.floor((tick - 30) / 7)
		d.hitstop = if (tick - 30) % 7 < 3 then 1 else 0
		around(a, cx, dir, (step * 0.9) % math.pi, 3.3)
		attack(a, moves, role(ctx, if step % 2 == 0 then "Elbow" else "Kick"), true)
		arc(frame, "tempete-hook" .. step, v(cx, 3.6, 0), 2.9, step * 70, step * 70 + 160, color, 1.2, dir)
		spark(frame, "tempete-hit" .. step, v(cx, 3.6, 0.6), color, 1.1)
		if step % 3 == 0 then
			table.insert(frame.fx, { key = "tempete-ring" .. step, kind = "tornadoRing", pos = v(cx, 2 + (step % 4) * 0.6, 0), color = color })
		end
		frame.speedLines = color
		frame.shot = frameOn("taro-tempete-whirl", dir, { a, d }, { yaw = lerp(-30, 40, p), pitch = 14 + math.sin(tick / 10) * 6,
			fill = lerp(0.62, 0.8, p), fov = 46, focus = P(D, "UpperTorso") })
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
	if tick < data.FinalTick then d.x = cx end -- then the simulation throws it
	if tick < data.FinalTick - 16 then d.state = "Hitstun" end
	if tick < data.Hits[1] then return rushOpening(ctx, frame, a, d, tick, dir, "zephyr-vent", cx, color, 7) end
	if tick >= data.FinalTick - 16 then return rushEnding(ctx, frame, a, d, tick, dir, "zephyr-vent", cx, color, "Kick") end
	-- A new kick every 4 ticks: twice the rhythm of the hits.
	local n = math.floor((tick - data.Hits[1]) / 4)
	a.x, a.facing = cx - dir * 2.7, dir
	attack(a, moves, role(ctx, ZEPHYR_RUSH[n % #ZEPHYR_RUSH + 1]), true)
	a.ghost = true
	d.hitstop = if (tick - data.Hits[1]) % 8 < 3 then 1 else 0
	arc(frame, "vent-blade" .. n, v(cx - dir * 0.5, 2.6 + (n % 3) * 0.6, 0.4), 2.6, -80 + (n % 4) * 30, 70 + (n % 4) * 30, color,
		(n % 3 - 1) * 0.5, dir)
	frame.speedLines = color
	local angle = lerp(-60, 60, progress(tick, data.Hits[1], data.FinalTick - 16))
	frame.shot = frameOn("zephyr-vent-orbit", dir, { a, d }, { yaw = angle, pitch = 8 + math.cos(tick / 8) * 6, fill = 0.74, fov = 44,
		roll = math.sin(tick / 12) * 6, focus = P(D, "UpperTorso") })
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
	local rise = smooth(progress(tick, data.Hits[1], start))
	d.y = lerp(0, 7, rise)
	if tick < start then
		local k = math.max(1, hitsBefore(data.Hits, tick))
		if k == 1 then
			a.x, a.y, a.facing = cx - dir * 1.9, 0, dir
			attack(a, moves, role(ctx, "Uppercut"), true)
			table.insert(frame.fx, { key = "dragon-wind", kind = "dragonHelix", pos = v(cx, 0, 0), color = color })
		else
			local behind = k % 2 == 0
			a.x, a.y = cx + (if behind then dir else -dir) * 2, d.y - 0.4
			a.facing = if behind then -dir else dir
			attack(a, moves, role(ctx, if k % 3 == 0 then "Kick" elseif behind then "AirKick2" else "AirKick"), true)
		end
		d.hitstop = if tick - data.Hits[k] < 5 then 1 else 0
		arc(frame, "dragon-kick" .. k, v(cx, d.y + 3, 0.4), 2.2, k * 50, k * 50 + 150, color, 0.6, dir)
		if tick - data.Hits[k] < 2 then frame.impact = { key = "dragon-kick" .. k, color = color } end
		frame.speedLines = color
		if k % 2 == 1 then
			frame.shot = frameOn("zephyr-dragon-under", dir, { a, d }, { yaw = -16, pitch = -28, fill = 0.75, fov = 56, roll = 8,
				focus = P(D, "UpperTorso") })
		else
			frame.shot = frameOn("zephyr-dragon-side", dir, { a, d }, { yaw = 28, pitch = 6, fill = 0.82, fov = 44, focus = P(D, "UpperTorso") })
		end
		return
	end
	local p = progress(tick, start, final)
	d.y = 7
	if p < 0.55 then
		local q = p / 0.55
		a.x, a.y, a.facing = cx - dir * 1.5, lerp(d.y - 0.4, d.y + 3.2, smooth(q)), dir
		local spin = role(ctx, "DragonTornado")
		a.state, a.move = "Attack", spin
		a.moveFrame = moves[spin].startup + 1 + (math.floor(tick / 3) % 2) * (moves[spin].hitInterval or 2)
		if tick % 5 == 0 then
			table.insert(frame.fx, { key = "dragon-ring" .. tick, kind = "tornadoRing", pos = v(cx, a.y + 1, 0), color = color })
		end
		frame.shot = frameOn("zephyr-dragon-spin", dir, { a, d }, { yaw = lerp(50, -30, q), pitch = -8, fill = 0.78, fov = 50,
			focus = P(D, "UpperTorso") })
	else
		local q = progress(p, 0.55, 1)
		a.x, a.y, a.facing = cx - dir * 1.3, lerp(d.y + 3.2, d.y + 0.6, smooth(q)), dir
		attack(a, moves, role(ctx, "AirSmash"), true)
		a.ghost = true
		frame.speedLines = color
		frame.shot = frameOn("zephyr-dragon-dive", dir, { a, d }, { yaw = -40, pitch = 22, fill = 0.8, fov = 46, focus = P(D, "UpperTorso") })
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
		gateSeal(ctx, frame, a, d, cx, dir, "zephyr-cyclone", tick)
		return
	end
	if tick < data.Hits[1] - 6 then
		local p = progress(tick, 30, data.Hits[1] - 6)
		d.x, d.state, d.pose = cx, "Hitstun", "Launched"
		d.y = lerp(0, 3.5, smooth(math.min(1, p * 2))) * (1 - progress(p, 0.85, 1))
		local angle = math.pi / 2 + math.sin(tick * 0.32) * 1.35
		around(a, cx, dir, angle, 3.3, d.y * 0.6)
		local spin = role(ctx, if math.floor(tick / 9) % 2 == 0 then "SpinKick" else "DragonTornado")
		attack(a, moves, spin, true)
		a.ghost = true
		if tick % 4 == 0 then
			table.insert(frame.fx, { key = "cyclone-ring" .. tick, kind = "tornadoRing", pos = v(cx, 0.5 + (tick % 24) * 0.25, 0), color = color })
		end
		frame.speedLines = color
		frame.shot = frameOn("zephyr-cyclone-vortex", dir, { a, d }, { yaw = math.sin(tick / 20) * 50, pitch = lerp(-10, 24, p),
			fill = 0.7, fov = 50, roll = math.sin(tick / 15) * 8, focus = P(D, "UpperTorso") })
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
	if tick < data.FinalTick then d.x = cx end -- then the simulation throws it
	if tick < data.FinalTick - 16 then d.state = "Hitstun" end
	if tick < data.Hits[1] then
		a.x, a.facing, a.pose = cx - dir * 7, dir, "Kiai"
		table.insert(frame.fx, { key = "ombres-seal", kind = "kanjiSeal", pos = v(a.x, 0.06, 0), color = color,
			text = ctx.characters[A].Kanji, keep = true })
		frame.aura = A
		frame.shot = frameOn("akemi-ombres-gather", dir, { a }, { yaw = 34, pitch = -6, fill = 0.92, fov = 36, band = "bust",
			focus = P(A, "Head") })
		return
	end
	if tick >= data.FinalTick - 16 then
		rushEnding(ctx, frame, a, d, tick, dir, "akemi-ombres", cx, color, "Smash")
		if tick >= data.FinalTick then
			table.insert(frame.fx, { key = "ombres-cut", kind = "lightning", from = v(cx - dir * 4, 6, 0), to = v(cx + dir * 4, 1, 0), color = color })
		end
		return
	end
	-- Each hit comes from another copy, somewhere on the far half of a circle.
	local k = hitsBefore(data.Hits, tick)
	around(a, cx, dir, ((k * 0.61) % 1) * math.pi, 2.6, if k % 4 == 0 then 1.4 else 0)
	attack(a, moves, role(ctx, AKEMI_STRIKES[(k - 1) % #AKEMI_STRIKES + 1]), true)
	a.ghost = true
	d.hitstop = if tick - data.Hits[k] < 5 then 1 else 0
	spark(frame, "ombres-hit" .. k, v(cx, 3.4, 0.6), color, 1.1)
	if tick - data.Hits[k] < 2 then
		table.insert(frame.fx, { key = "ombres-blink" .. k, kind = "lightning", from = v(cx - 3, 5.5, -1.5), to = v(cx + 3, 1.5, -1.5),
			color = color })
	end
	frame.grade.void = true
	frame.speedLines = color
	frame.shot = frameOn("akemi-ombres-orbit", dir, { a, d }, { yaw = lerp(-45, 45, progress(tick, data.Hits[1], data.FinalTick - 16)),
		pitch = 30, fill = 0.72, fov = 46, focus = P(D, "UpperTorso") })
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
	if tick < data.Hits[1] + 6 then
		a.x, a.facing, a.pose = cx - dir * 3, dir, "Evade"
		a.ghost = true
		table.insert(frame.fx, { key = "temps-bubble", kind = "shockwave", pos = v(cx, 0, 0), color = color })
		frame.shot = frameOn("akemi-temps-dodge", dir, { a, d }, { yaw = -38, pitch = 2, fill = 0.88, fov = 38,
			focus = P(A, "UpperTorso") })
	elseif tick < start then
		local k = math.max(1, hitsBefore(data.Hits, tick))
		around(a, cx, dir, if k % 2 == 0 then math.pi * 0.8 else math.pi * 0.2, 3.1)
		attack(a, moves, role(ctx, AKEMI_STRIKES[(k - 1) % #AKEMI_STRIKES + 1]), tick - data.Hits[k] >= 2)
		a.ghost = true
		spark(frame, "temps-hit" .. k, v(cx, 3.3, 0.6), color, 1)
		frame.shot = frameOn("akemi-temps-slow", dir, { a, d }, { yaw = lerp(-50, 50, progress(tick, data.Hits[1], start)), pitch = 6,
			fill = 0.85, fov = 40, focus = P(D, "UpperTorso") })
	else
		local p = progress(tick, start, final)
		-- Behind the target, back turned: the cuts appear all at once as time resumes.
		a.x, a.z, a.lookDir, a.facing, a.pose = cx + dir * 3.8, nil, nil, dir, "StandTall"
		if p > 0.7 then
			frame.grade.mono = false
			frame.impact = { key = "temps-resume", color = color }
			table.insert(frame.fx, { key = "temps-cut1", kind = "lightning", from = v(cx - 2.5, 6, 0.3), to = v(cx + 2.5, 1, 0.3), color = color })
			table.insert(frame.fx, { key = "temps-cut2", kind = "lightning", from = v(cx + 2.5, 6, 0.3), to = v(cx - 2.5, 1, 0.3), color = color })
		end
		frame.shot = frameOn("akemi-temps-back", dir, { a, d }, { yaw = 58, pitch = -4, fill = lerp(0.82, 0.96, p), fov = 40,
			focus = P(A, "UpperTorso") })
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
		gateSeal(ctx, frame, a, d, cx, dir, "akemi-danse", tick)
		return
	end
	if tick < data.Hits[1] - 6 then
		frame.grade.void = true
		d.x, d.state = cx, "Hitstun"
		local step = math.floor((tick - 30) / 11)
		local t = (tick - 30) % 11
		local angle = if step % 2 == 0 then math.pi * 0.08 else math.pi * 0.92
		around(a, cx, dir, angle, 3.1)
		if t < 4 then
			a.pose = "Evade"
		else
			attack(a, moves, role(ctx, AKEMI_STRIKES[step % #AKEMI_STRIKES + 1]), true)
		end
		a.ghost = true
		d.hitstop = if t >= 4 and t < 7 then 1 else 0
		if t == 4 then frame.impact = { key = "danse-hit" .. step, color = color } end
		if step > 0 then
			local from = if step % 2 == 0 then cx + dir * 2.4 else cx - dir * 2.4
			table.insert(frame.fx, { key = "danse-blink" .. step, kind = "lightning", from = v(from, 3.5, -0.8), to = v(a.x, 3.5, a.z),
				color = color })
		end
		local side = if step % 2 == 0 then 1 else -1
		frame.shot = frameOn("akemi-danse-" .. (if side > 0 then "a" else "b"), dir, { a, d }, { yaw = side * 16, pitch = 10,
			fill = 0.82, fov = 42, roll = side * 6, focus = P(D, "UpperTorso") })
		return
	end
	gateEnd(ctx, frame, a, d, tick, dir, cx, "akemi-danse", function(c)
		impact(frame, "danse-final", v(cx, 3.6, 0.6), c, 2.8)
		table.insert(frame.fx, { key = "danse-cut", kind = "lightning", from = v(cx - 3, 6.5, 0.4), to = v(cx + 3, 0.5, 0.4), color = c })
	end)
end

Director.KIT_ULTIMATES = KIT

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
		-- (camera on the outer side: the fallen body lies on the inner one)
		frame.shot = shot("ko-feet", P(W, "LeftFoot", v(side * 1.5, 0.35, 2.4)), P(W, "RightFoot"), 32)
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
