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
		grade = { crimson, void, mono, fire, sky, shadow, -- colour grading switches
			rage, current, inverse, ruin },
		handheld = number?,                           -- constant camera sway (TARO)
		quake = number?,                              -- a jolt of the camera (HIBECARES' blows)
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
	-- Grades: crimson / void (KAI), fire (TARO), sky (ZEPHYR), shadow (AKEMI), rage (RYUKEN),
	-- current (SHIN), inverse (DAICHA), ruin (HIBECARES), mono.
	return { grade = { crimson = false, void = false, mono = false, fire = false, sky = false, shadow = false,
		rage = false, current = false, inverse = false, ruin = false }, fx = {} }
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
		-- (from behind: his silhouette and aura against the target far ahead)
		frame.shot = frameOn("rush-ready", dir, { a }, { yaw = -132, pitch = -10, fill = 0.8, fov = 40, focus = P(A, "UpperTorso") })
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
	if staged then
		staged(ctx, frame, a, d, tick, dir, color)
		return
	end
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
	TARO, ZEPHYR and AKEMI direct their three ultimates with their own film language, so no
	two characters' cinematics look alike (Wilhem: "each character 100 % different"):
	  TARO 火    boxing broadcast: low angles, handheld camera, shot / reverse shot, fire
	            grade. He never dashes nor blinks: he walks the target down and pushes it.
	            1 RUSH DÉVASTATEUR · 2 UPPERCUT CÉLESTE · 3 TEMPÊTE DE CROCHETS
	  ZEPHYR 風  aerial: long smooth crane and orbit moves, wide lenses, few cuts, sky grade.
	            Everything happens in the air: leaps, wind, vortex.
	            1 VENT TRANCHEUR · 2 DRAGON ASCENDANT · 3 CYCLONE FURIEUX
	  AKEMI 影   stealth: locked static frames, abrupt jump cuts, shadow grade; she is often
	            out of the frame, appears only to strike, stops time.
	            1 OMBRES MULTIPLES · 2 TEMPS SUSPENDU · 3 DANSE FANTÔME
	KAI keeps KAIEN RUSH, ÉVEIL ÉCARLATE and 開天 above. The authoritative timing (hits,
	prompts, final blow) is the same for every kit: only the staging differs.
]]

-- A horizontal ring (a full arc lying on the floor plane) around x = cx.
local function ring(frame, key, cx, radius, y, color)
	arc(frame, key, v(cx, y, 0), radius, 0, 360, color, math.pi / 2, 1)
end

-- Out of the frame (AKEMI between two strikes): far above the stage.
local function vanish(a)
	a.y, a.z, a.lookDir, a.pose, a.ghost = 120, nil, nil, "StandTall", false
end

local function title(ctx, frame, color, sub)
	local cin = ctx.cin
	frame.title = { text = ctx.moveData.Moves[cin.move].name, color = color, sub = sub }
end

-- ---------------------------------------------------------------- TARO 火 · boxer

local TARO_PUNCHES = { "Jab", "Cross", "Elbow", "BodyBlow", "Cross", "Elbow", "Kick", "SpinKick" }

KIT.TARO = {}

-- RUSH DÉVASTATEUR: gloves pounded together, a slow walk forward, then a barrage that drives
-- the target back across the deck, filmed from the side like a broadcast; the crouch, the
-- uppercut seen from the floor, and TARO's silhouette against the sky.
function KIT.TARO.Rush(ctx, frame, a, d, tick, dir)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local color = ctx.characters[A].Energy
	local cx = center(ctx, d)
	frame.grade.fire, frame.handheld = true, 0.18
	local k = hitsBefore(data.Hits, tick)
	local room = math.max(0, (if dir > 0 then ctx.config.ArenaMaxX - cx else cx - ctx.config.ArenaMinX) - 2)
	local push = math.min(k * 0.3, room)
	if tick < data.FinalTick then
		d.x, d.state = cx + dir * push, "Hitstun"
	end
	if tick < 12 then
		a.x, a.facing, a.pose = cx - dir * 6, dir, "GloveTap"
		if tick >= 4 then spark(frame, "taro-tap", v(a.x + dir * 0.6, 3.6, 0.6), color, 1.6) end
		frame.shot = frameOn("taro-rush-gloves", dir, { a }, { yaw = 42, pitch = -12, fill = 1.0, fov = 34, band = "bust",
			focus = P(A, "Head") })
	elseif tick < data.Hits[1] then
		-- The walk: the camera dollies back in front of him.
		a.x, a.facing, a.state, a.vx = lerp(cx - dir * 6, cx - dir * 2.3, progress(tick, 12, data.Hits[1])), dir, "Walking", dir * 6
		frame.shot = frameOn("taro-rush-walk", dir, { a, d }, { yaw = -58, pitch = -8, fill = 0.78, fov = 42, focus = P(A, "UpperTorso") })
	elseif tick < data.FinalTick - 16 then
		a.x, a.facing = d.x - dir * 2.6, dir
		attack(a, moves, role(ctx, TARO_PUNCHES[(k - 1) % #TARO_PUNCHES + 1]), true)
		d.hitstop = if tick - data.Hits[k] < 5 then 1 else 0
		spark(frame, "taro-hit" .. k, v(d.x - dir * 0.5, 3.4 + (k % 3) * 0.4, 0.6), color, 1.5)
		if tick - data.Hits[k] < 2 and k % 3 == 0 then frame.impact = { key = "taro-hit" .. k, color = color } end
		if k % 4 == 0 then
			frame.shot = frameOn("taro-rush-shoulder", dir, { a, d }, { yaw = -44, pitch = -6, fill = 0.95, fov = 38, band = "waist",
				focus = P(D, "UpperTorso") })
		else
			frame.shot = frameOn("taro-rush-broadcast", dir, { a, d }, { yaw = 20, pitch = 4, fill = 0.66, fov = 40, focus = P(D, "UpperTorso") })
		end
	elseif tick < data.FinalTick then
		a.x, a.facing = d.x - dir * 2, dir
		attack(a, moves, role(ctx, "Uppercut"), false)
		table.insert(frame.fx, { key = "taro-crouch", kind = "dust", pos = v(a.x, 0, 0), direction = dir })
		frame.shot = frameOn("taro-rush-crouch", dir, { a, d }, { yaw = 24, pitch = -24, fill = 0.9, fov = 44, roll = 6,
			focus = P(A, "UpperTorso") })
	elseif tick < data.FinalTick + 12 then
		a.x, a.facing = cx + dir * push - dir * 2, dir
		attack(a, moves, role(ctx, "Uppercut"), true)
		impact(frame, "taro-uppercut", v(cx + dir * push, 4.4, 0.6), color, 3)
		table.insert(frame.fx, { key = "taro-pillar", kind = "dragonHelix", pos = v(cx + dir * push, 0, 0), color = color })
		frame.shot = frameOn("taro-rush-skyward", dir, { a, d }, { yaw = 30, pitch = -40, fill = 0.72, fov = 54, focus = P(D, "UpperTorso") })
	else
		a.x, a.facing, a.pose = cx + dir * push - dir * 2, dir, "Victory"
		frame.shot = frameOn("taro-rush-silhouette", dir, { a, d }, { yaw = -122, pitch = -10, fill = 0.7, fov = 44, focus = P(A, "UpperTorso") })
	end
end

-- UPPERCUT CÉLESTE: a crater of fire opens around him (seen from above), the crane up his
-- body, the walk in, body blows filmed shot / reverse shot, the charge, the uppercut seen
-- from the floor, the meteor seen from above, the crater, the champion's pose.
function KIT.TARO.Awaken(ctx, frame, a, d, tick, dir, color)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local cx = center(ctx, d)
	local last = data.Hits[#data.Hits]
	frame.grade.crimson, frame.grade.fire, frame.handheld = false, true, 0.12
	if tick < data.FinalTick then d.x, d.state = cx, "Hitstun" end
	if tick < 30 then
		a.x, a.facing, a.pose = cx - dir * 7, dir, "Crouch"
		if tick % 6 == 0 then ring(frame, "celeste-crater" .. tick, a.x, 1.5 + tick * 0.08, 0.2, color) end
		frame.shot = frameOn("taro-celeste-crater", dir, { a }, { yaw = 6, pitch = 76, fill = 0.42, fov = 50, roll = tick * 0.6,
			focus = P(A, "UpperTorso") })
	elseif tick < 60 then
		a.x, a.facing, a.pose = cx - dir * 7, dir, "GloveTap"
		frame.aura = A
		local p = progress(tick, 30, 60)
		frame.shot = frameOn("taro-celeste-crane", dir, { a }, { yaw = 38, pitch = lerp(-34, 4, p), fill = lerp(0.85, 1.05, p), fov = 40,
			band = if p < 0.5 then "full" else "bust", focus = P(A, "Head") })
	elseif tick < data.Hits[1] then
		a.x, a.facing, a.state, a.vx = lerp(cx - dir * 7, cx - dir * 2.3, progress(tick, 60, data.Hits[1])), dir, "Walking", dir * 6
		frame.shot = frameOn("taro-celeste-walk", dir, { a, d }, { yaw = 0, pitch = 2, fill = 0.7, fov = 40, focus = P(A, "UpperTorso") })
	elseif tick < last + 4 then
		-- Body blows: shot over TARO's shoulder, then the reverse shot over the target's.
		local k = math.max(1, hitsBefore(data.Hits, tick))
		a.x, a.facing = cx - dir * 2.3, dir
		attack(a, moves, role(ctx, if k % 2 == 0 then "BodyBlow" else "Elbow"), true)
		d.hitstop = if tick - data.Hits[k] < 6 then 1 else 0
		spark(frame, "celeste-hit" .. k, v(cx - dir * 0.4, 3, 0.6), color, 1.4)
		if tick - data.Hits[k] < 2 then frame.impact = { key = "celeste-hit" .. k, color = color } end
		if k % 2 == 1 then
			frame.shot = frameOn("taro-celeste-ots", dir, { a, d }, { yaw = -32, pitch = -4, fill = 0.8, fov = 38, focus = P(D, "UpperTorso") })
		else
			frame.shot = frameOn("taro-celeste-reverse", dir, { a, d }, { yaw = 40, pitch = -4, fill = 0.8, fov = 38, focus = P(A, "UpperTorso") })
		end
	elseif tick < 140 then
		a.x, a.facing = cx - dir * 1.9, dir
		attack(a, moves, role(ctx, "Uppercut"), false)
		if tick % 5 == 0 then ring(frame, "celeste-swirl" .. tick, a.x, 1.6, 0.3 + (tick % 15) * 0.2, color) end
		frame.shot = frameOn("taro-celeste-charge", dir, { a }, { yaw = -44, pitch = -14, fill = 0.95, fov = 36, band = "bust",
			focus = P(A, "Head") })
	elseif tick < 152 then
		local q = smooth(progress(tick, 140, 152))
		a.x, a.facing = cx - dir * 1.8, dir
		attack(a, moves, role(ctx, "Uppercut"), true)
		a.y, d.y = lerp(0, 3, q), lerp(0, 10, q)
		table.insert(frame.fx, { key = "celeste-pillar", kind = "dragonHelix", pos = v(cx, 0, 0), color = color })
		frame.impact = { key = "celeste-up", color = color }
		frame.shot = frameOn("taro-celeste-skyward", dir, { a, d }, { yaw = 12, pitch = -58, fill = 0.7, fov = 60, focus = P(D, "UpperTorso") })
	elseif tick < data.FinalTick then
		d.y, d.pose = 10, "Launched"
		a.x, a.facing, a.y = cx - dir * 1.2, dir, lerp(3, 12.5, smooth(progress(tick, 152, data.FinalTick - 2)))
		attack(a, moves, role(ctx, "AirSmash"), tick >= data.FinalTick - 3)
		frame.shot = frameOn("taro-celeste-meteor", dir, { a, d }, { yaw = -20, pitch = 52, fill = 0.66, fov = 50, focus = P(A, "UpperTorso") })
	elseif tick < data.FinalTick + 16 then
		a.x, a.y, a.facing = cx - dir * 1.4, 0, dir
		attack(a, moves, role(ctx, "AirSmash"), true)
		impact(frame, "celeste-crash", v(cx, 1, 0.6), color, 3.4)
		for i = 1, 3 do table.insert(frame.fx, { key = "celeste-crack" .. i, kind = "dust", pos = v(cx + (i - 2) * 1.5, 0, 0), direction = i - 2 }) end
		frame.shot = frameOn("taro-celeste-impact", dir, { a, d }, { yaw = 4, pitch = 80, fill = 0.5, fov = 50, focus = P(A, "UpperTorso") })
	else
		a.y, a.facing, a.pose = 0, dir, "Victory"
		title(ctx, frame, color, "火 · TARO")
		frame.shot = frameOn("taro-celeste-champion", dir, { a }, { yaw = 34, pitch = -18, fill = 0.85, fov = 42, focus = P(A, "Head") })
	end
end

-- TEMPÊTE DE CROCHETS: a ring of fire closes around both fighters, the face-off in profile,
-- then TARO circles the target hook after hook, the liver blow, the cocked fist (press R)
-- and the hook that blows the ring apart.
function KIT.TARO.Gate(ctx, frame, a, d, tick, dir)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local color = ctx.characters[A].Energy
	local cx = center(ctx, d)
	frame.grade.fire, frame.handheld = true, 0.15
	if tick < data.FinalTick then d.x, d.state = cx, "Hitstun" end
	-- The ring of fire stays around the fight until the final blow.
	if tick < data.FinalTick and tick % 4 == 0 then ring(frame, "tempete-ring" .. tick, cx, lerp(9, 5.5, progress(tick, 0, 24)), 0.2, color) end
	if tick < 24 then
		a.x, a.facing, a.pose = cx - dir * 3.5, dir, "GloveTap"
		frame.shot = frameOn("taro-tempete-arena", dir, { a, d }, { yaw = 30, pitch = 30, fill = 0.42, fov = 50, focus = P(A, "UpperTorso") })
	elseif tick < 40 then
		a.x, a.facing, a.pose = cx - dir * 3.5, dir, "Block"
		frame.shot = frameOn("taro-tempete-faceoff", dir, { a, d }, { yaw = 0, pitch = -3, fill = 0.82, fov = 34, focus = P(A, "Head") })
	elseif tick < data.Hits[1] - 6 then
		local p = progress(tick, 40, data.Hits[1] - 6)
		local step = math.floor((tick - 40) / 7)
		d.hitstop = if (tick - 40) % 7 < 3 then 1 else 0
		around(a, cx, dir, (step * 0.9) % math.pi, 3.3)
		attack(a, moves, role(ctx, if step % 2 == 0 then "Elbow" else "Kick"), true)
		arc(frame, "tempete-hook" .. step, v(cx, 3.6, 0), 2.9, step * 70, step * 70 + 160, color, 1.2, dir)
		spark(frame, "tempete-hit" .. step, v(cx, 3.6, 0.6), color, 1.1)
		frame.shot = frameOn("taro-tempete-whirl", dir, { a, d }, { yaw = math.sin(tick / 9) * 55, pitch = 4, fill = lerp(0.66, 0.8, p),
			fov = 46, roll = math.sin(tick / 7) * 5, focus = P(D, "UpperTorso") })
	elseif tick < data.PromptTicks[1] - 14 then
		a.x, a.z, a.lookDir, a.facing = cx - dir * 2.3, nil, nil, dir
		local second = tick >= data.Hits[2]
		attack(a, moves, role(ctx, if second then "Elbow" else "BodyBlow"), tick >= data.Hits[1])
		if tick >= data.Hits[1] then spark(frame, "tempete-liver" .. (if second then 2 else 1), v(cx - dir * 0.4, 2.8, 0.6), color, 1.4) end
		frame.shot = frameOn("taro-tempete-liver", dir, { a, d }, { yaw = 48, pitch = -6, fill = 0.78, fov = 38, focus = P(D, "UpperTorso") })
	elseif tick < data.FinalTick then
		a.x, a.facing = cx - dir * 2.6, dir
		attack(a, moves, role(ctx, "Finale"), false)
		frame.grade.mono = tick >= data.PromptTicks[1] - 4
		spark(frame, "tempete-cock", v(a.x - dir * 0.8, 3.4, 0.6), color, 2)
		frame.shot = frameOn("taro-tempete-cock", dir, { a, d }, { yaw = -36, pitch = -16, fill = lerp(0.9, 1.08, progress(tick,
			data.PromptTicks[1] - 14, data.FinalTick)), fov = 36, focus = P(A, "UpperTorso") })
	elseif tick < data.FinalTick + 22 then
		a.x, a.facing = cx - dir * 2.6, dir
		attack(a, moves, role(ctx, "Finale"), true)
		impact(frame, "tempete-final", v(cx, 3.6, 0.6), color, 3.4)
		for i = 1, 4 do ring(frame, "tempete-burst" .. i, cx, 2 + i * 1.6, 0.3 + i * 0.5, color) end
		frame.shot = frameOn("taro-tempete-ko", dir, { a, d }, { yaw = 18, pitch = 22, fill = 0.52, fov = 50, focus = P(D, "UpperTorso") })
	else
		a.x, a.y, a.facing, a.pose = cx - dir * 4.2, 0, dir, "Victory"
		local t = kitOf(ctx).GateTitle
		frame.title = { text = t.text, color = color, sub = t.sub }
		frame.shot = frameOn("taro-tempete-champion", dir, { a }, { yaw = 30, pitch = -20, fill = 0.82, fov = 42, focus = P(A, "Head") })
	end
end

-- ---------------------------------------------------------------- ZEPHYR 風 · kicks

local ZEPHYR_KICKS = { "Jab", "Cross", "Elbow", "Kick", "SpinKick", "AirKick", "AirKick2" }

KIT.ZEPHYR = {}

-- VENT TRANCHEUR: a long leap from afar, one continuous sweeping orbit while he kicks from
-- the ground and the air, then he hangs in the sky (seen from below) and drops an axe kick
-- (seen from above), and lands softly while the camera drifts away.
function KIT.ZEPHYR.Rush(ctx, frame, a, d, tick, dir)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local color = ctx.characters[A].Energy
	local cx = center(ctx, d)
	frame.grade.sky = true
	if tick < data.FinalTick then d.x, d.state = cx, "Hitstun" end
	local k = hitsBefore(data.Hits, tick)
	if tick < data.Hits[1] then
		local p = progress(tick, 0, data.Hits[1])
		a.x, a.y, a.facing = lerp(cx - dir * 11, cx - dir * 2.7, p), math.sin(p * math.pi) * 5, dir
		a.pose = if p < 0.85 then "JumpApex" else nil
		if p >= 0.85 then attack(a, moves, role(ctx, "AirKick"), true) end
		a.ghost = true
		frame.shot = frameOn("zephyr-vent-leap", dir, { a, d }, { yaw = 8, pitch = 14, fill = 0.55, fov = 56, focus = P(A, "UpperTorso") })
	elseif tick < data.FinalTick - 16 then
		-- Ground and air in turn, switching sides every two kicks; one long camera move.
		local side = if math.floor((k - 1) / 2) % 2 == 0 then -1 else 1
		a.x, a.y = cx + side * dir * 2.6, if k % 2 == 0 then 1.8 else 0
		a.facing = -side * dir
		attack(a, moves, role(ctx, ZEPHYR_KICKS[(k - 1) % #ZEPHYR_KICKS + 1]), true)
		d.hitstop = if tick - data.Hits[k] < 3 then 1 else 0
		arc(frame, "vent-blade" .. k, v(cx, 2.6 + (k % 3) * 0.7, 0.4), 2.8, -80 + (k % 4) * 35, 80 + (k % 4) * 35, color, (k % 3 - 1) * 0.6, dir)
		frame.speedLines = color
		local p = progress(tick, data.Hits[1], data.FinalTick - 16)
		frame.shot = frameOn("zephyr-vent-sweep", dir, { a, d }, { yaw = lerp(-80, 80, p), pitch = 10 + math.sin(p * math.pi) * 14,
			fill = 0.62, fov = 52, focus = P(D, "UpperTorso") })
	elseif tick < data.FinalTick then
		local p = progress(tick, data.FinalTick - 16, data.FinalTick)
		a.x, a.y, a.facing = cx - dir * 1.6, lerp(0, 5, smooth(p)), dir
		attack(a, moves, role(ctx, "Hammer"), false)
		frame.shot = frameOn("zephyr-vent-sky", dir, { a, d }, { yaw = -16, pitch = -34, fill = 0.66, fov = 58, focus = P(A, "UpperTorso") })
	elseif tick < data.FinalTick + 12 then
		a.x, a.y, a.facing = cx - dir * 1.6, 1.2, dir
		attack(a, moves, role(ctx, "Hammer"), true)
		impact(frame, "vent-axe", v(cx, 3, 0.6), color, 2.8)
		arc(frame, "vent-axe-arc", v(cx - dir * 0.6, 3.6, 0.4), 3.4, 100, -40, color, 0, dir)
		frame.shot = frameOn("zephyr-vent-axe", dir, { a, d }, { yaw = 10, pitch = 66, fill = 0.6, fov = 50, focus = P(D, "UpperTorso") })
	else
		a.x, a.y, a.facing, a.pose = cx - dir * 2.4, 0, dir, "Victory"
		frame.shot = frameOn("zephyr-vent-drift", dir, { a, d }, { yaw = lerp(-24, 24, progress(tick, data.FinalTick + 12, data.Length)),
			pitch = 12, fill = 0.48, fov = 50, focus = P(A, "UpperTorso") })
	end
end

-- DRAGON ASCENDANT: the wind coils around him as the camera cranes up his body, a long low
-- glide, the rising kick and one continuous climb beside the target, the spin far above,
-- the dive, the touch-down, and ZEPHYR looking at the sky with his back to us.
function KIT.ZEPHYR.Awaken(ctx, frame, a, d, tick, dir, color)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local D = cin.defender
	local cx = center(ctx, d)
	local last = data.Hits[#data.Hits]
	frame.grade.crimson, frame.grade.sky = false, true
	if tick < data.FinalTick then d.x, d.state = cx, "Hitstun" end
	if tick < 36 then
		local p = progress(tick, 0, 36)
		a.x, a.facing, a.pose = cx - dir * 8, dir, "WindGather"
		table.insert(frame.fx, { key = "dragon-coil", kind = "dragonHelix", pos = v(a.x, 0, 0), color = color })
		frame.shot = frameOn("zephyr-dragon-coil", dir, { a }, { yaw = lerp(-10, 80, p), pitch = lerp(-24, 36, p), fill = 0.78, fov = 50,
			focus = P(cin.attacker, "UpperTorso") })
	elseif tick < data.Hits[1] then
		local p = progress(tick, 36, data.Hits[1])
		a.x, a.y, a.facing, a.pose = lerp(cx - dir * 8, cx - dir * 2, smooth(p)), 0.8, dir, "Dash"
		a.ghost = true
		frame.speedLines = color
		frame.shot = frameOn("zephyr-dragon-glide", dir, { a, d }, { yaw = -6, pitch = 4, fill = 0.6, fov = 54, focus = P(cin.attacker, "UpperTorso") })
	elseif tick < last + 4 then
		local k = math.max(1, hitsBefore(data.Hits, tick))
		d.y = lerp(0, 7, smooth(progress(tick, data.Hits[1], last + 4)))
		if k == 1 then
			a.x, a.y, a.facing = cx - dir * 1.9, 0, dir
			attack(a, moves, role(ctx, "Uppercut"), true)
		else
			local behind = k % 2 == 0
			a.x, a.y = cx + (if behind then dir else -dir) * 2.7, d.y - 0.4
			a.facing = if behind then -dir else dir
			attack(a, moves, role(ctx, if behind then "AirKick2" else "AirKick"), true)
		end
		d.hitstop = if tick - data.Hits[k] < 4 then 1 else 0
		arc(frame, "dragon-kick" .. k, v(cx, d.y + 3, 0.4), 2.3, k * 50, k * 50 + 160, color, 0.6, dir)
		table.insert(frame.fx, { key = "dragon-wind", kind = "dragonHelix", pos = v(cx, 0, 0), color = color })
		frame.shot = frameOn("zephyr-dragon-climb", dir, { a, d }, { yaw = lerp(30, -30, progress(tick, data.Hits[1], last + 4)),
			pitch = -12, fill = 0.7, fov = 54, focus = P(D, "UpperTorso") })
	elseif tick < 145 then
		local q = progress(tick, last + 4, 145)
		d.y = 7
		a.x, a.y, a.facing = cx - dir * 1.5, lerp(6.6, 10.4, smooth(q)), dir
		local spin = role(ctx, "DragonTornado")
		a.state, a.move = "Attack", spin
		a.moveFrame = moves[spin].startup + 1 + (math.floor(tick / 3) % 2) * (moves[spin].hitInterval or 2)
		if tick % 5 == 0 then ring(frame, "dragon-ring" .. tick, cx, 2.6, a.y + 1, color) end
		frame.shot = frameOn("zephyr-dragon-heights", dir, { a, d }, { yaw = lerp(70, 20, q), pitch = -6, fill = 0.7, fov = 54,
			focus = P(D, "UpperTorso") })
	elseif tick < data.FinalTick then
		d.y = 7
		a.x, a.y, a.facing = cx - dir * 1.3, lerp(10.4, 7.6, smooth(progress(tick, 145, data.FinalTick))), dir
		attack(a, moves, role(ctx, "AirSmash"), true)
		a.ghost = true
		frame.speedLines = color
		frame.shot = frameOn("zephyr-dragon-dive", dir, { a, d }, { yaw = -40, pitch = 48, fill = 0.72, fov = 48, focus = P(D, "UpperTorso") })
	elseif tick < data.FinalTick + 16 then
		a.x, a.y, a.facing, a.pose = cx - dir * 3.8, 0, dir, "Land"
		table.insert(frame.fx, { key = "dragon-touch", kind = "shockwave", pos = v(cx, 0, 0), color = color })
		frame.impact = { key = "dragon-touch", color = color }
		frame.shot = frameOn("zephyr-dragon-touchdown", dir, { a }, { yaw = 26, pitch = -6, fill = 0.8, fov = 44, focus = P(cin.attacker, "UpperTorso") })
	else
		-- His back to the camera, looking up at the sky where the target flew.
		a.x, a.y, a.facing, a.pose = cx - dir * 3.8, 0, dir, "StandTall"
		a.lookDir = v(dir * 0.3, 0, -1)
		title(ctx, frame, color, "風 · ZEPHYR")
		frame.shot = frameOn("zephyr-dragon-horizon", dir, { a }, { yaw = 0, pitch = -16, fill = 0.75, fov = 46, focus = P(cin.attacker, "UpperTorso") })
	end
end

-- CYCLONE FURIEUX: seen from very far, a cyclone forms over the deck; inside it the target
-- is lifted and ZEPHYR swings around it; the eye of the storm seen from below, the spin
-- kick, and the calm after the wind.
function KIT.ZEPHYR.Gate(ctx, frame, a, d, tick, dir)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local color = ctx.characters[A].Energy
	local cx = center(ctx, d)
	frame.grade.sky = true
	if tick < data.FinalTick then d.x, d.state = cx, "Hitstun" end
	if tick < data.FinalTick and tick % 3 == 0 then
		ring(frame, "cyclone" .. tick, cx, 2.2 + (tick % 21) * 0.18, 0.4 + (tick % 21) * 0.45, color)
	end
	if tick < 30 then
		a.x, a.facing, a.pose = cx - dir * 6, dir, "WindGather"
		frame.shot = frameOn("zephyr-cyclone-far", dir, { a, d, { point = true, x = cx, y = 11, z = 0 } }, { yaw = 14, pitch = 10,
			fill = 0.5, fov = 46, focus = P(D, "UpperTorso") })
	elseif tick < data.Hits[1] - 6 then
		local p = progress(tick, 30, data.Hits[1] - 6)
		d.pose = "Launched"
		d.y = lerp(0, 3.5, smooth(math.min(1, p * 2))) * (1 - progress(p, 0.85, 1))
		local angle = math.pi / 2 + math.sin(tick * 0.32) * 1.35
		around(a, cx, dir, angle, 4, d.y * 0.6)
		attack(a, moves, role(ctx, if math.floor(tick / 9) % 2 == 0 then "SpinKick" else "DragonTornado"), true)
		a.ghost = true
		frame.speedLines = color
		frame.shot = frameOn("zephyr-cyclone-inside", dir, { a, d }, { yaw = (tick * 2.2) % 120 - 60, pitch = lerp(-6, 20, p), fill = 0.66,
			fov = 54, roll = math.sin(tick / 15) * 8, focus = P(D, "UpperTorso") })
	elseif tick < data.PromptTicks[1] - 14 then
		d.y = 3
		a.x, a.y, a.z, a.lookDir, a.facing = cx - dir * 2.9, 2.6, nil, nil, dir
		local second = tick >= data.Hits[2]
		attack(a, moves, role(ctx, if second then "AirKick2" else "AirKick"), tick >= data.Hits[1])
		frame.shot = frameOn("zephyr-cyclone-gust", dir, { a, d }, { yaw = 46, pitch = 2, fill = 0.78, fov = 46, focus = P(D, "UpperTorso") })
	elseif tick < data.FinalTick then
		d.y = 3
		a.x, a.y, a.facing = cx - dir * 0.8, 8, dir
		attack(a, moves, role(ctx, "Hammer"), false)
		frame.grade.mono = tick >= data.PromptTicks[1] - 4
		frame.shot = frameOn("zephyr-cyclone-eye", dir, { a, d }, { yaw = 10, pitch = -62, fill = 0.66, fov = 58, focus = P(A, "UpperTorso") })
	elseif tick < data.FinalTick + 22 then
		a.x, a.y, a.facing = cx - dir * 1.4, lerp(8, 1, progress(tick, data.FinalTick, data.FinalTick + 8)), dir
		attack(a, moves, role(ctx, "Hammer"), true)
		impact(frame, "cyclone-final", v(cx, 3.8, 0.6), color, 3.2)
		for i = 1, 5 do ring(frame, "cyclone-burst" .. i, cx, 1.5 + i * 1.8, 0.4, color) end
		frame.shot = frameOn("zephyr-cyclone-burst", dir, { a, d }, { yaw = -30, pitch = 34, fill = 0.55, fov = 52, focus = P(D, "UpperTorso") })
	else
		a.x, a.y, a.facing, a.pose = cx - dir * 4, 0, dir, "StandTall"
		a.lookDir = v(-dir * 0.4, 0, -1)
		local t = kitOf(ctx).GateTitle
		frame.title = { text = t.text, color = color, sub = t.sub }
		frame.shot = frameOn("zephyr-cyclone-calm", dir, { a }, { yaw = lerp(10, -10, progress(tick, data.FinalTick + 22, data.Length)),
			pitch = 4, fill = lerp(0.6, 0.72, progress(tick, data.FinalTick + 22, data.Length)), fov = 46, focus = P(A, "UpperTorso") })
	end
end

-- ---------------------------------------------------------------- AKEMI 影 · shadow

local AKEMI_STRIKES = { "Jab", "Kick", "SpinKick", "Elbow", "Cross", "BodyBlow" }

KIT.AKEMI = {}

-- OMBRES MULTIPLES: AKEMI vanishes; a locked frame on the target alone, looking around;
-- shadows strike from everywhere (each a flash and gone); from above, the same; she stands
-- back to back with it in the dark; every cut opens at once.
function KIT.AKEMI.Rush(ctx, frame, a, d, tick, dir)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local color = ctx.characters[A].Energy
	local cx = center(ctx, d)
	frame.grade.shadow = true
	if tick < data.FinalTick then d.x, d.state = cx, "Hitstun" end
	local k = hitsBefore(data.Hits, tick)
	if tick < 10 then
		a.x, a.facing, a.pose = cx - dir * 4, dir, "Evade"
		a.ghost = true
		frame.shot = frameOn("akemi-ombres-fade", dir, { a, d }, { yaw = 0, pitch = 0, fill = 0.7, fov = 36, focus = P(A, "UpperTorso") })
	elseif tick < data.Hits[1] then
		vanish(a)
		-- The target alone, turning its head: where is she?
		d.state, d.lookDir = "Idle", v(math.cos(tick / 4) * 0.8, 0, 0.6)
		frame.shot = frameOn("akemi-ombres-alone", dir, { d }, { yaw = 20, pitch = -2, fill = 0.78, fov = 32, band = "bust",
			focus = P(D, "Head") })
	elseif tick < data.FinalTick - 22 then
		-- A shadow appears for four ticks, strikes and is gone.
		if tick - data.Hits[k] < 4 then
			around(a, cx, dir, ((k * 0.37) % 1) * math.pi, 2.7, if k % 3 == 0 then 1.4 else 0)
			attack(a, moves, role(ctx, AKEMI_STRIKES[(k - 1) % #AKEMI_STRIKES + 1]), true)
			a.ghost = true
		else
			vanish(a)
		end
		d.hitstop = if tick - data.Hits[k] < 4 then 1 else 0
		table.insert(frame.fx, { key = "ombres-cut" .. k, kind = "lightning", from = v(cx - 2.6, 5.6 - (k % 3), 0.4),
			to = v(cx + 2.6, 1.8 + (k % 2), 0.4), color = color })
		if k <= 6 then
			frame.shot = frameOn("akemi-ombres-locked", dir, { d }, { yaw = -14, pitch = 6, fill = 0.62, fov = 40, focus = P(D, "UpperTorso") })
		else
			frame.shot = frameOn("akemi-ombres-above", dir, { d }, { yaw = 10, pitch = 58, fill = 0.42, fov = 48, focus = P(D, "UpperTorso") })
		end
	elseif tick < data.FinalTick + 14 then
		-- Back to back in the dark; on the final tick every cut opens at once.
		a.x, a.z, a.lookDir, a.y, a.facing, a.pose = cx + dir * 2.7, nil, nil, 0, dir, "Sheathe"
		frame.grade.mono = tick < data.FinalTick
		if tick >= data.FinalTick then
			impact(frame, "ombres-final", v(cx, 3.6, 0.6), color, 2.6)
			for i = 1, 4 do
				table.insert(frame.fx, { key = "ombres-x" .. i, kind = "lightning", from = v(cx - 3 + i * 0.4, 6.5, 0.5),
					to = v(cx + 3 - i * 0.4, 0.8 + i * 0.3, 0.5), color = color })
			end
		end
		frame.shot = frameOn("akemi-ombres-backtoback", dir, { a, d }, { yaw = 14, pitch = -4, fill = 0.8, fov = 36, focus = P(A, "Head") })
	else
		a.x, a.y, a.facing, a.state, a.vx = lerp(cx + dir * 2.7, cx + dir * 5.4, progress(tick, data.FinalTick + 14, data.Length)), 0, dir,
			"Walking", dir * 3
		frame.shot = frameOn("akemi-ombres-leave", dir, { a }, { yaw = 64, pitch = -8, fill = 0.7, fov = 40, focus = P(A, "UpperTorso") })
	end
end

-- TEMPS SUSPENDU: the target charges; time stops (black and white) as AKEMI sidesteps;
-- a slow orbit around the frozen target while she walks around it; strike after strike
-- in still tableaux; she walks away sheathing; time resumes and every cut lands at once.
function KIT.AKEMI.Awaken(ctx, frame, a, d, tick, dir, color)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local cx = center(ctx, d)
	local last = data.Hits[#data.Hits]
	frame.grade.crimson, frame.grade.shadow = false, true
	if tick < 24 then
		-- The target lunges at her (still in colour).
		a.x, a.facing, a.pose = cx - dir * 4.4, dir, "Block"
		d.x, d.state, d.pose, d.facing = lerp(cx, cx - dir * 1.2, progress(tick, 0, 24)), "Hitstun", "Dash", -dir
		frame.shot = frameOn("akemi-temps-charge", dir, { a, d }, { yaw = 8, pitch = 0, fill = 0.78, fov = 40, focus = P(D, "UpperTorso") })
		return
	end
	local frozenX = cx - dir * 1.2
	if tick < data.FinalTick then d.x, d.facing, d.state, d.pose, d.hitstop = frozenX, -dir, "Hitstun", "Dash", 1 end
	frame.grade.mono = tick < 150
	if tick < 40 then
		-- Time stops: she slides aside, the bubble spreads.
		a.x, a.facing, a.pose = cx - dir * 4.2, dir, "Evade"
		a.z = -1.6
		a.ghost = true
		table.insert(frame.fx, { key = "temps-bubble", kind = "shockwave", pos = v(d.x, 0, 0), color = color })
		frame.shot = frameOn("akemi-temps-stop", dir, { a, d }, { yaw = -60, pitch = 4, fill = 0.82, fov = 38, focus = P(A, "UpperTorso") })
	elseif tick < data.Hits[1] then
		local p = progress(tick, 40, data.Hits[1])
		around(a, d.x, dir, lerp(0.15, 0.85, p) * math.pi, 3.2)
		a.state, a.move, a.vx = "Walking", nil, 2
		frame.shot = frameOn("akemi-temps-frozen", dir, { a, d }, { yaw = lerp(-70, 70, p), pitch = 8, fill = 0.7, fov = 42, focus = P(D, "UpperTorso") })
	elseif tick < last + 4 then
		local k = math.max(1, hitsBefore(data.Hits, tick))
		around(a, d.x, dir, ((k * 0.43) % 1) * math.pi, 3, if k == 4 then 1.2 else 0)
		attack(a, moves, role(ctx, AKEMI_STRIKES[(k - 1) % #AKEMI_STRIKES + 1]), true)
		spark(frame, "temps-hit" .. k, v(d.x, 3.2 + (k % 3) * 0.3, 0.6), color, 0.9)
		local views = { { yaw = 34, pitch = 6 }, { yaw = -24, pitch = 30 }, { yaw = 70, pitch = -6 }, { yaw = -64, pitch = 10 } }
		local view = views[(k - 1) % #views + 1]
		frame.shot = frameOn("akemi-temps-tableau" .. ((k - 1) % #views + 1), dir, { a, d }, { yaw = view.yaw, pitch = view.pitch,
			fill = 0.8, fov = 40, focus = P(D, "UpperTorso") })
	elseif tick < 150 then
		-- She walks away, sheathing; the target stays frozen behind her.
		local p = progress(tick, last + 4, 150)
		a.x, a.z, a.lookDir, a.y, a.facing = lerp(frozenX + dir * 2.4, frozenX + dir * 5.6, p), nil, nil, 0, dir
		if p < 0.8 then a.state, a.move, a.vx = "Walking", nil, dir * 2 else a.pose = "Sheathe" end
		frame.shot = frameOn("akemi-temps-walk", dir, { a }, { yaw = 62, pitch = -4, fill = 0.85, fov = 38, focus = P(A, "Head") })
	elseif tick < data.FinalTick + 14 then
		-- Time resumes: every cut lands at once.
		a.x, a.facing, a.pose = frozenX + dir * 5.6, dir, "Sheathe"
		frame.impact = { key = "temps-resume", color = color }
		for i = 1, 5 do
			table.insert(frame.fx, { key = "temps-cut" .. i, kind = "lightning", from = v(d.x - 2.4 + i * 0.3, 6.2, 0.4),
				to = v(d.x + 2.4 - i * 0.5, 0.8 + i * 0.4, 0.4), color = color })
		end
		frame.shot = frameOn("akemi-temps-resume", dir, { d }, { yaw = -50, pitch = 16, fill = 0.48, fov = 46, focus = P(D, "UpperTorso") })
	else
		a.x, a.y, a.facing, a.pose = frozenX + dir * 5.6, 0, dir, "Sheathe"
		title(ctx, frame, color, "影 · AKEMI")
		frame.shot = frameOn("akemi-temps-epilogue", dir, { a }, { yaw = 22, pitch = 2, fill = 0.72, fov = 36, focus = P(A, "Head") })
	end
end

-- DANSE FANTÔME: the lights go out, her seal burns under the target; she blinks from place
-- to place, each blink a bolt, the target turning to follow her; two strikes from behind;
-- crouched, blade hand ready (press R); a giant X across the frame.
function KIT.AKEMI.Gate(ctx, frame, a, d, tick, dir)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local color = ctx.characters[A].Energy
	local cx = center(ctx, d)
	frame.grade.shadow, frame.grade.void = true, tick < data.FinalTick
	if tick < data.FinalTick then d.x, d.state = cx, "Hitstun" end
	if tick < 24 then
		vanish(a)
		table.insert(frame.fx, { key = "danse-seal", kind = "kanjiSeal", pos = v(cx, 0.06, 0), color = color,
			text = ctx.characters[A].Kanji, keep = true })
		frame.shot = frameOn("akemi-danse-dark", dir, { d }, { yaw = 0, pitch = 70, fill = 0.5, fov = 46, roll = tick * 0.4,
			focus = P(D, "UpperTorso") })
	elseif tick < data.Hits[1] - 6 then
		local step = math.floor((tick - 24) / 11)
		local t = (tick - 24) % 11
		local angle = ({ 0.08, 0.92, 0.5, 0.2, 0.8, 0.35, 0.65, 0.05 })[step % 8 + 1] * math.pi
		around(a, cx, dir, angle, 3.7)
		if t < 3 then a.pose = "Evade" else attack(a, moves, role(ctx, AKEMI_STRIKES[step % #AKEMI_STRIKES + 1]), true) end
		a.ghost = true
		-- The target turns toward her.
		d.lookDir = v(a.x - cx, 0, (a.z or 0) * 0.5 + 0.5)
		d.hitstop = if t >= 3 and t < 6 then 1 else 0
		if t == 3 then frame.impact = { key = "danse-hit" .. step, color = color } end
		if step > 0 then
			table.insert(frame.fx, { key = "danse-blink" .. step, kind = "lightning", from = v(cx, 3.5, -2.5), to = v(a.x, 3.5, a.z or 0),
				color = color })
		end
		if step % 2 == 0 then
			frame.shot = frameOn("akemi-danse-pov", dir, { a, d }, { yaw = 100, pitch = 8, fill = 0.7, fov = 44, focus = P(A, "UpperTorso") })
		else
			frame.shot = frameOn("akemi-danse-wide", dir, { a, d }, { yaw = -8, pitch = 24, fill = 0.6, fov = 44, focus = P(D, "UpperTorso") })
		end
	elseif tick < data.PromptTicks[1] - 14 then
		d.lookDir = nil
		a.x, a.z, a.lookDir, a.facing = cx + dir * 2.3, nil, nil, -dir
		local second = tick >= data.Hits[2]
		attack(a, moves, role(ctx, if second then "Cross" else "Jab"), tick >= data.Hits[1])
		frame.shot = frameOn("akemi-danse-behind", dir, { a, d }, { yaw = 30, pitch = 4, fill = 0.78, fov = 38, focus = P(A, "UpperTorso") })
	elseif tick < data.FinalTick then
		d.lookDir = nil
		a.x, a.z, a.lookDir, a.facing, a.pose = cx - dir * 3.2, nil, nil, dir, "Crouch"
		frame.grade.mono = tick >= data.PromptTicks[1] - 4
		frame.shot = frameOn("akemi-danse-draw", dir, { a }, { yaw = -46, pitch = -8, fill = 0.85, fov = 36, focus = P(A, "Head") })
	elseif tick < data.FinalTick + 22 then
		a.x, a.facing = cx + dir * 3.2, -dir
		attack(a, moves, role(ctx, "Finale"), true)
		impact(frame, "danse-final", v(cx, 3.6, 0.6), color, 3)
		table.insert(frame.fx, { key = "danse-x1", kind = "lightning", from = v(cx - 5, 8, 0.4), to = v(cx + 5, 0.2, 0.4), color = color })
		table.insert(frame.fx, { key = "danse-x2", kind = "lightning", from = v(cx + 5, 8, 0.4), to = v(cx - 5, 0.2, 0.4), color = color })
		frame.shot = frameOn("akemi-danse-x", dir, { a, d }, { yaw = 0, pitch = 6, fill = 0.6, fov = 44, focus = P(D, "UpperTorso") })
	else
		a.x, a.y, a.facing, a.pose = cx + dir * 4.4, 0, -dir, "Sheathe"
		local t = kitOf(ctx).GateTitle
		frame.title = { text = t.text, color = color, sub = t.sub }
		frame.shot = frameOn("akemi-danse-bow", dir, { a }, { yaw = -30, pitch = -4, fill = 0.7, fov = 38, focus = P(A, "Head") })
	end
end

-- ---------------------------------------------------------------- second sheet
--[[
	The four fighters of Wilhem's second sheet, each with its own film language too:
	  RYUKEN 拳    brute force: crash zooms, extreme close-ups on the fists, an impact frame
	              on every blow, low angles, rage grade (hot red, hard contrast).
	              1 FUREUR DU POING · 2 EFFONDREMENT · 3 拳 DERNIER ROUND
	  SHIN 流      the blade: long lenses, smooth lateral tracking, few cuts, the iai freeze,
	              clean straight lines of light; current grade (cold steel blue).
	              1 DANSE DES COURANTS · 2 TEMPÊTE CONTINUE · 3 零 ZÉRO HORIZON
	  DAICHA 闇    inverted space: dutch angles, mirrored jump cuts, the camera upside down,
	              a black sun; inverse grade (deep violet).
	              1 DOMAINE OBSCUR · 2 RIVIÈRE D'OMBRES · 3 蝕 ÉCLIPSE TOTALE
	  HIBECARES 崩 the colossus: monumental low angles, stone pillars, dust and debris, the
	              deck shaking under every blow; ruin grade (dusty sepia).
	              1 COLOSSE ÉVEILLÉ · 2 CHÂTIMENT · 3 崩 RUINES DU MONDE
]]

-- Stone pillars bursting out of the floor on the far half of a ring (never between the
-- camera and the fighters); they sink back after `life` seconds, else stay to the end.
local function rocks(frame, key, cx, radius, count, color, life)
	table.insert(frame.fx, { key = key, kind = "rocks", pos = v(cx, 0, 0), radius = radius, count = count, color = color,
		life = life, keep = life == nil })
end

local function debris(frame, key, pos, color, scale)
	table.insert(frame.fx, { key = key, kind = "debris", pos = pos, color = color, scale = scale or 1 })
end

-- A glowing fissure along the floor.
local function crack(frame, key, from, to, color)
	table.insert(frame.fx, { key = key, kind = "crack", from = from, to = to, color = color })
end

-- A perfectly straight line of light (a blade cut).
local function slash(frame, key, from, to, color)
	table.insert(frame.fx, { key = key, kind = "cut", from = from, to = to, color = color })
end

-- A black sun with a burning corona; `life` seconds, else until the end of the scene.
local function eclipse(frame, key, pos, color, scale, life)
	table.insert(frame.fx, { key = key, kind = "eclipse", pos = pos, color = color, scale = scale or 1, life = life, keep = life == nil })
end

-- RYUKEN: a giant fist of ki (forearm, fist, knuckles) thrown from `from` to `to`.
local function rageFist(frame, key, from, to, color, scale)
	table.insert(frame.fx, { key = key, kind = "rageFist", from = from, to = to, color = color, scale = scale or 1 })
end

-- DAICHA: `count` orbs of shadow circling `pos` on a ring of `radius` tilted by `tilt` radians
-- (0 = flat), `spin` turns per second from the turn `phase`, for `life` seconds. crownAt
-- gives where each orb is (the client draws the same ring).
local function orbs(frame, key, pos, radius, count, color, life, spin, phase, tilt)
	table.insert(frame.fx, { key = key, kind = "orbs", pos = pos, radius = radius, count = count, color = color, life = life,
		spin = spin, phase = phase or 0, tilt = tilt or 0 })
end

local function crownAt(c, radius, count, i, turn, tilt)
	local angle = (turn + (i - 1) / count) * math.pi * 2
	return v(c.x + math.cos(angle) * radius, c.y + math.sin(angle) * radius * math.sin(tilt),
		(c.z or 0) + math.sin(angle) * radius * math.cos(tilt))
end

-- DAICHA: one orb of shadow darting from `from` into `to`.
local function orbDart(frame, key, from, to, color)
	table.insert(frame.fx, { key = key, kind = "orbDart", from = from, to = to, color = color })
end

-- SHIN: the water his steps leave on the deck, a smooth glowing stroke that fades in `life` s.
local function wake(frame, key, from, to, color, life)
	table.insert(frame.fx, { key = key, kind = "wake", from = from, to = to, color = color, life = life or 1.6 })
end

-- SHIN: a column of water spinning up from the floor at `pos` for `life` seconds.
local function waterspout(frame, key, pos, radius, height, color, life)
	table.insert(frame.fx, { key = key, kind = "waterspout", pos = pos, radius = radius, scale = height, color = color, life = life })
end

-- HIBECARES: stone pillars erupting one after the other along a line of the floor, sinking
-- back after `life` seconds.
local function rockLine(frame, key, from, to, count, color, life)
	table.insert(frame.fx, { key = key, kind = "rockLine", from = from, to = to, count = count, color = color, life = life or 1 })
end

-- Turns a staged fighter toward the point (x, z) of the floor.
local function faceTo(view, x, z)
	local lx, lz = x - view.x, z - (view.z or 0)
	local l = math.sqrt(lx * lx + lz * lz)
	if l > 1e-3 then view.lookDir = v(lx / l, 0, lz / l) end
	view.facing = if lx >= 0 then 1 else -1
end

-- Room left behind the target toward the wall it is pushed to.
local function roomAhead(ctx, cx, dir)
	return math.max(0, if dir > 0 then ctx.config.ArenaMaxX - cx else cx - ctx.config.ArenaMinX)
end

-- ---------------------------------------------------------------- RYUKEN 拳 · force

KIT.RYUKEN = {}

-- FUREUR DU POING: he never lets go. The roar, CHARGE FRONTALE, then the target held up by the
-- collar and pounded at point-blank range (the camera in its face: every blow comes at us),
-- slammed into the deck (seen from above), caught on the bounce with an uppercut, juggled
-- skyward from both sides (seen from the floor), spiked back down; his rage gathers in his
-- fist (crash zoom) and leaves it as a giant fist of ki that blasts the target across the
-- deck; steam rising off the gauntlet.
function KIT.RYUKEN.Rush(ctx, frame, a, d, tick, dir)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local color = ctx.characters[A].Energy
	local cx = center(ctx, d)
	local H = data.Hits
	frame.grade.rage = true
	if tick < data.FinalTick then d.x, d.state = cx, "Hitstun" end
	local k = hitsBefore(H, tick)
	local beat = if k > 0 then tick - H[k] else 0
	if tick < 14 then
		a.x, a.facing, a.pose = cx - dir * 6, dir, "Roar"
		frame.aura = A
		if tick % 4 == 0 then ring(frame, "fureur-roar" .. tick, a.x, 1.2 + tick * 0.2, 0.15, color) end
		frame.shot = frameOn("ryuken-fureur-roar", dir, { a }, { yaw = 30, pitch = -18, fill = lerp(0.9, 1.05, tick / 14), fov = 40,
			band = "bust", focus = P(A, "Head") })
	elseif tick < H[1] then
		-- CHARGE FRONTALE, shoulder first; the camera waits in front of him.
		a.x, a.facing = lerp(cx - dir * 6, cx - dir * 1.9, progress(tick, 14, H[1]) ^ 2), dir
		attack(a, moves, role(ctx, "Rising"), true)
		frame.speedLines = color
		table.insert(frame.fx, { key = "fureur-charge" .. tick // 4, kind = "dust", pos = v(a.x, 0, 0), direction = dir })
		frame.shot = frameOn("ryuken-fureur-charge", dir, { a, d }, { yaw = 64, pitch = -6, fill = 0.8, fov = 46, focus = P(A, "UpperTorso") })
	elseif k <= 5 then
		-- Held up by the collar and pounded, the fist pulled back between two blows; the
		-- camera in the target's face punches in on every blow.
		a.x, a.facing = cx - dir * 1.9, dir
		d.y = 0.5
		attack(a, moves, role(ctx, if k % 2 == 1 then "PalmStrike" else "BodyBlow"), beat < 4)
		d.hitstop = if beat < 5 then 1 else 0
		if beat < 2 then frame.impact = { key = "fureur-pound" .. k, color = color } end
		spark(frame, "fureur-pound" .. k, v(cx - dir * 0.5, if k % 2 == 1 then 4.4 else 3.2, 0.6), color, 1.5)
		frame.shot = frameOn("ryuken-fureur-hold", dir, { a, d }, { yaw = 124, pitch = -6, fill = if beat < 3 then 1.0 else 0.9,
			fov = 38, band = "bust", focus = P(A, "Head") })
	elseif k == 6 then
		-- Slammed into the deck, seen from above: the floor cracks all around it.
		a.x, a.facing = cx - dir * 1.9, dir
		attack(a, moves, role(ctx, "Hammer"), true)
		d.y, d.pose, d.lookDir = 0, "DownFace", v(0, 0, -1)
		d.hitstop = if beat < 5 then 1 else 0
		if beat < 2 then frame.impact = { key = "fureur-slam", color = color } end
		for i = 1, 5 do
			local angle = i / 5 * math.pi * 2 + 0.4
			crack(frame, "fureur-slam" .. i, v(cx, 0.05, -0.6), v(cx + math.cos(angle) * 4.5, 0.05, -0.6 + math.sin(angle) * 3), color)
		end
		table.insert(frame.fx, { key = "fureur-slam-wave", kind = "shockwave", pos = v(cx, 0, 0), color = color })
		debris(frame, "fureur-slam", v(cx, 0.4, 0), color, 1)
		frame.shot = frameOn("ryuken-fureur-slam", dir, { a, d }, { yaw = 8, pitch = 66, fill = 0.66, fov = 46, focus = P(D, "UpperTorso") })
	elseif k == 7 then
		-- Caught on the bounce: the uppercut, seen from the floor.
		local p = progress(tick, H[7], H[8])
		a.x, a.facing, a.y = cx - dir * 1.7, dir, math.sin(p * math.pi) * 1.2
		attack(a, moves, role(ctx, "Uppercut"), true)
		d.y, d.pose = lerp(0.4, 4.2, smooth(p)), "Launched"
		d.hitstop = if beat < 4 then 1 else 0
		if beat < 2 then frame.impact = { key = "fureur-bounce", color = color } end
		spark(frame, "fureur-bounce", v(cx - dir * 0.4, 2.6, 0.6), color, 2)
		frame.shot = frameOn("ryuken-fureur-bounce", dir, { a, d }, { yaw = 34, pitch = -28, fill = 0.74, fov = 50, focus = P(D, "UpperTorso") })
	elseif k <= 10 then
		-- Juggled skyward, from one side then the other, every blow higher.
		local p = progress(tick, H[8], H[11])
		d.y, d.pose = lerp(4.2, 7.4, p), "Launched"
		local behind = k == 9
		a.x, a.y = cx + (if behind then dir else -dir) * 1.9, d.y - 0.8
		a.facing = if behind then -dir else dir
		attack(a, moves, role(ctx, if behind then "AirKick2" else "AirKick"), beat < 5)
		d.hitstop = if beat < 4 then 1 else 0
		if beat < 2 then frame.impact = { key = "fureur-air" .. k, color = color } end
		spark(frame, "fureur-air" .. k, v(cx, d.y + 3.4, 0.6), color, 1.6)
		frame.speedLines = color
		frame.shot = frameOn("ryuken-fureur-juggle", dir, { a, d }, { yaw = lerp(-36, 36, p), pitch = -30, fill = 0.7, fov = 52,
			focus = P(D, "UpperTorso") })
	elseif tick < H[11] + 10 then
		-- Spiked back down from above him; the deck breaks where it lands.
		local p = progress(tick, H[11], H[11] + 7)
		a.x, a.facing, a.y = cx - dir * 1.5, dir, lerp(8.4, 0, p * p)
		attack(a, moves, role(ctx, "AirSmash"), true)
		d.y = lerp(7.4, 0, p * p)
		if p < 1 then
			d.pose = "Launched"
		else
			d.pose, d.lookDir = "DownFace", v(0, 0, -1)
			impact(frame, "fureur-spike", v(cx, 1, 0.6), color, 2.4)
			debris(frame, "fureur-spike", v(cx, 0.4, 0), color, 1.2)
		end
		frame.shot = frameOn("ryuken-fureur-spike", dir, { a, d }, { yaw = -12, pitch = 44, fill = 0.66, fov = 50, focus = P(D, "UpperTorso") })
	elseif tick < data.FinalTick then
		-- The rage gathers in his fist: a crash zoom while the ki closes in on it.
		local p = progress(tick, H[11] + 10, data.FinalTick)
		a.x, a.y, a.facing = cx - dir * 3.2, 0, dir
		attack(a, moves, role(ctx, "Smash"), false)
		d.y, d.pose = 0, "Kneel"
		frame.aura = A
		spark(frame, "fureur-gather" .. tick // 3, v(a.x - dir * 0.6, 3.2, 0.6), color, 0.6 + p * 1.6)
		if tick % 4 == 0 then
			table.insert(frame.fx, { key = "fureur-heat" .. tick, kind = "smoke", pos = v(a.x - dir * 0.5, 2.8, 0.5) })
		end
		frame.shot = frameOn("ryuken-fureur-gather", dir, { a }, { yaw = -54, pitch = -12, fill = lerp(0.8, 1.05, smooth(p)), fov = 36,
			band = "waist", focus = P(A, "RightHand") })
	elseif tick < data.FinalTick + 14 then
		-- The giant fist of rage blasts the target across the deck.
		local reach = math.min(8, roomAhead(ctx, cx, dir))
		a.x, a.y, a.facing = cx - dir * 3.2, 0, dir
		attack(a, moves, role(ctx, "Smash"), true)
		rageFist(frame, "fureur-fist", v(a.x + dir * 0.8, 3.4, 0.5), v(cx + dir * reach, 3.6, 0.5), color, 2.4)
		impact(frame, "fureur-giant", v(cx, 3.4, 0.6), color, 3.4)
		crack(frame, "fureur-furrow", v(a.x + dir, 0.05, 0), v(cx + dir * reach, 0.05, 0.4), color)
		debris(frame, "fureur-debris", v(cx, 0.5, 0), color, 1.4)
		frame.shot = frameOn("ryuken-fureur-blast", dir, { a, d, { point = true, x = cx + dir * reach, y = 3.5, z = 0.5 } },
			{ yaw = 10, pitch = 6, fill = 0.62, fov = 48, focus = P(D, "UpperTorso") })
	else
		a.x, a.y, a.facing, a.pose = cx - dir * 3.2, 0, dir, "Roar"
		if tick % 6 == 0 then
			table.insert(frame.fx, { key = "fureur-steam" .. tick, kind = "smoke", pos = v(a.x + dir * 0.7, 2.4, 0.4) })
		end
		frame.shot = frameOn("ryuken-fureur-steam", dir, { a }, { yaw = 34, pitch = -22, fill = 0.82, fov = 42, focus = P(A, "Head") })
	end
end

-- EFFONDREMENT: the cracked gauntlet in close-up, a blow on the floor that sends cracks to
-- the target, the charge, body blows until it drops to one knee, the leap seen from the
-- floor, the crater seen from straight above, RYUKEN standing in it.
function KIT.RYUKEN.Awaken(ctx, frame, a, d, tick, dir, color)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local cx = center(ctx, d)
	local last = data.Hits[#data.Hits]
	frame.grade.crimson, frame.grade.rage = false, true
	if tick < data.FinalTick then d.x, d.state = cx, "Hitstun" end
	if tick < 24 then
		frame.kanjiBack = ctx.characters[A].Kanji
		a.x, a.facing, a.pose = cx - dir * 7, dir, "Roar"
		if tick % 6 == 0 then spark(frame, "effondrement-ember" .. tick, v(a.x + dir * 0.6, 2.4, 0.8), color, 0.8) end
		frame.shot = frameOn("ryuken-effondrement-gauntlet", dir, { a }, { yaw = 52, pitch = -4, fill = 0.95, fov = 30, band = "waist",
			focus = P(A, "RightHand") })
	elseif tick < 50 then
		a.x, a.facing = cx - dir * 7, dir
		attack(a, moves, role(ctx, "Hammer"), tick >= 34)
		if tick >= 34 then
			for i = 1, 3 do
				crack(frame, "effondrement-crack" .. i, v(a.x + dir * 0.8, 0.05, 0), v(cx + dir * (i - 2) * 0.8, 0.05, (i - 2) * 1.6), color)
			end
			table.insert(frame.fx, { key = "effondrement-quake", kind = "shockwave", pos = v(a.x + dir, 0, 0), color = color })
			if tick < 36 then frame.impact = { key = "effondrement-quake", color = color } end
		end
		frame.shot = frameOn("ryuken-effondrement-quake", dir, { a, d }, { yaw = 16, pitch = 48, fill = 0.6, fov = 46, focus = P(A, "UpperTorso") })
	elseif tick < data.Hits[1] then
		a.x, a.facing = lerp(cx - dir * 7, cx - dir * 2.3, progress(tick, 50, data.Hits[1]) ^ 2), dir
		attack(a, moves, role(ctx, "Rising"), true)
		frame.speedLines = color
		frame.shot = frameOn("ryuken-effondrement-charge", dir, { a, d }, { yaw = 0, pitch = -8, fill = 0.72, fov = 44, focus = P(A, "UpperTorso") })
	elseif tick < last + 4 then
		-- Body blows: the target folds a little more each time and drops to one knee.
		local k = math.max(1, hitsBefore(data.Hits, tick))
		a.x, a.facing = cx - dir * 2.3, dir
		attack(a, moves, role(ctx, if k % 3 == 0 then "Elbow" elseif k % 2 == 0 then "Cross" else "BodyBlow"), true)
		d.hitstop = if tick - data.Hits[k] < 6 then 1 else 0
		if k >= 5 then d.pose = "Kneel" end
		if tick - data.Hits[k] < 2 then frame.impact = { key = "effondrement-hit" .. k, color = color } end
		spark(frame, "effondrement-hit" .. k, v(cx - dir * 0.5, if k >= 5 then 2.2 else 3, 0.6), color, 1.6)
		if k % 2 == 1 then
			frame.shot = frameOn("ryuken-effondrement-body", dir, { a, d }, { yaw = 40, pitch = -2, fill = 0.98, fov = 36, band = "waist",
				focus = P(D, "UpperTorso") })
		else
			frame.shot = frameOn("ryuken-effondrement-low", dir, { a, d }, { yaw = -30, pitch = -24, fill = 0.8, fov = 44, roll = -8,
				focus = P(A, "UpperTorso") })
		end
	elseif tick < data.FinalTick then
		-- The leap, both fists joined over his head, seen from the floor.
		local q = smooth(progress(tick, last + 4, data.FinalTick))
		d.pose = "Kneel"
		a.x, a.facing, a.y = cx - dir * 1.6, dir, math.sin(q * math.pi) * 6.5 + q * 0.5
		attack(a, moves, role(ctx, "AirSmash"), q > 0.75)
		frame.shot = frameOn("ryuken-effondrement-leap", dir, { a, d }, { yaw = 22, pitch = -34, fill = 0.7, fov = 52, focus = P(A, "UpperTorso") })
	elseif tick < data.FinalTick + 16 then
		a.x, a.y, a.facing = cx - dir * 1.6, 0, dir
		attack(a, moves, role(ctx, "AirSmash"), true)
		impact(frame, "effondrement-crater", v(cx, 1, 0.6), color, 3.4)
		for i = 1, 6 do
			local angle = i / 6 * math.pi * 2
			crack(frame, "effondrement-crater" .. i, v(cx, 0.05, 0), v(cx + math.cos(angle) * 6, 0.05, math.sin(angle) * 4), color)
		end
		debris(frame, "effondrement-debris", v(cx, 0.4, 0), color, 1.6)
		frame.shot = frameOn("ryuken-effondrement-crater", dir, { a, d }, { yaw = 6, pitch = 74, fill = 0.48, fov = 50, focus = P(D, "UpperTorso") })
	else
		a.x, a.y, a.facing, a.pose = cx - dir * 2.4, 0, dir, "Roar"
		title(ctx, frame, color, "拳 · RYUKEN")
		frame.shot = frameOn("ryuken-effondrement-standing", dir, { a }, { yaw = 26, pitch = -20, fill = 0.82, fov = 42, focus = P(A, "Head") })
	end
end

-- 拳 DERNIER ROUND: the stare-down in tight shot / reverse shot, his kanji burning under
-- him, the slow advance cracking the deck, a flurry on the guard, the guard broken (liver,
-- uppercut), the fist drawn back (press R) and the last punch that shatters the floor.
function KIT.RYUKEN.Gate(ctx, frame, a, d, tick, dir)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local color = ctx.characters[A].Energy
	local cx = center(ctx, d)
	frame.grade.rage = true
	if tick < data.FinalTick then d.x, d.state = cx, "Hitstun" end
	if tick < 30 then
		a.x, a.facing, a.pose = cx - dir * 4.5, dir, "Roar"
		d.state = "Idle"
		if tick < 15 then
			frame.shot = frameOn("ryuken-round-glare", dir, { a }, { yaw = 54, pitch = -4, fill = 1.0, fov = 30, band = "bust", focus = P(A, "Head") })
		else
			frame.shot = frameOn("ryuken-round-rival", dir, { d }, { yaw = -54, pitch = -4, fill = 1.0, fov = 30, band = "bust", focus = P(D, "Head") })
		end
	elseif tick < 60 then
		a.x, a.facing, a.pose = cx - dir * 4.5, dir, "Roar"
		frame.aura = A
		table.insert(frame.fx, { key = "round-seal", kind = "kanjiSeal", pos = v(a.x, 0.06, 0), color = color,
			text = ctx.characters[A].Kanji, keep = true })
		frame.shot = frameOn("ryuken-round-seal", dir, { a, d }, { yaw = -10, pitch = 66, fill = 0.55, fov = 46, roll = (tick - 30) * 0.5,
			focus = P(A, "UpperTorso") })
	elseif tick < 88 then
		-- The advance: one step at a time, the deck cracking under each one.
		local p = progress(tick, 60, 88)
		a.x, a.facing, a.state, a.vx = lerp(cx - dir * 4.5, cx - dir * 2.4, p), dir, "Walking", dir * 3
		local step = (tick - 60) // 9
		crack(frame, "round-step" .. step, v(a.x, 0.05, 0), v(a.x + dir * 2.2, 0.05, (step % 2 - 0.5) * 2), color)
		frame.shot = frameOn("ryuken-round-advance", dir, { a, d }, { yaw = -62, pitch = -10, fill = 0.82, fov = 40, focus = P(A, "UpperTorso") })
	elseif tick < data.Hits[1] - 4 then
		-- A flurry on the raised guard.
		local flurry = role(ctx, "KiFlurry")
		a.x, a.facing = cx - dir * 2.4, dir
		a.state, a.move = "Attack", flurry
		a.moveFrame = moves[flurry].startup + 1 + (tick // 2 % 2) * (moves[flurry].hitInterval or 2)
		d.state = "Blockstun"
		if tick % 3 == 0 then spark(frame, "round-guard" .. tick, v(cx - dir * 0.6, 3.6 + (tick % 5) * 0.15, 0.5), color, 0.8) end
		frame.shot = frameOn("ryuken-round-guard", dir, { a, d }, { yaw = 34, pitch = 2, fill = 0.9, fov = 36, band = "bust",
			focus = P(D, "UpperTorso") })
	elseif tick < data.PromptTicks[1] - 14 then
		-- The guard breaks: the liver, then the uppercut.
		a.x, a.facing = cx - dir * 2.4, dir
		local second = tick >= data.Hits[2]
		local landed = if second then data.Hits[2] else data.Hits[1]
		attack(a, moves, role(ctx, if second then "Uppercut" else "BodyBlow"), tick >= data.Hits[1])
		if tick >= data.Hits[1] then
			spark(frame, "round-break" .. landed, v(cx - dir * 0.4, if second then 4.4 else 2.8, 0.6), color, 1.8)
			if tick - landed < 2 then frame.impact = { key = "round-break" .. landed, color = color } end
		end
		frame.shot = frameOn("ryuken-round-break", dir, { a, d }, { yaw = -34, pitch = -12, fill = 0.88, fov = 38, roll = 8,
			focus = P(D, "UpperTorso") })
	elseif tick < data.FinalTick then
		a.x, a.facing = cx - dir * 2.6, dir
		attack(a, moves, role(ctx, "Finale"), false)
		frame.grade.mono = tick >= data.PromptTicks[1] - 4
		spark(frame, "round-cock", v(a.x - dir * 0.8, 3.4, 0.6), color, 2.2)
		frame.shot = frameOn("ryuken-round-cock", dir, { a, d }, { yaw = 46, pitch = -10, fill = lerp(0.9, 1.12, progress(tick,
			data.PromptTicks[1] - 14, data.FinalTick)), fov = 34, band = "bust", focus = P(A, "Head") })
	elseif tick < data.FinalTick + 22 then
		a.x, a.facing = cx - dir * 2.6, dir
		attack(a, moves, role(ctx, "Finale"), true)
		impact(frame, "round-final", v(cx, 3.6, 0.6), color, 3.6)
		debris(frame, "round-debris", v(cx, 0.5, 0), color, 2)
		for i = 1, 5 do
			local angle = (i - 3) * 0.5
			crack(frame, "round-shatter" .. i, v(cx - dir * 1.4, 0.05, 0), v(cx + dir * math.cos(angle) * 9, 0.05, math.sin(angle) * 5), color)
		end
		frame.shot = frameOn("ryuken-round-shatter", dir, { a, d }, { yaw = 12, pitch = 14, fill = 0.5, fov = 50, focus = P(D, "UpperTorso") })
	else
		-- The bell: his back to us, steam on the fists.
		a.x, a.y, a.facing, a.pose = cx - dir * 2.6, 0, dir, "StandTall"
		if tick % 7 == 0 then
			table.insert(frame.fx, { key = "round-steam" .. tick, kind = "smoke", pos = v(a.x + dir * 0.4, 2.4, 0.5) })
		end
		local t = kitOf(ctx).GateTitle
		frame.title = { text = t.text, color = color, sub = t.sub }
		frame.shot = frameOn("ryuken-round-bell", dir, { a }, { yaw = -140, pitch = -8, fill = 0.78, fov = 40, focus = P(A, "UpperTorso") })
	end
end

-- ---------------------------------------------------------------- SHIN 流 · blade

local SHIN_CUTS = { "Jab", "Cross", "Elbow", "Kick", "SpinKick", "Hammer", "BodyBlow", "Sweep" }
local IAI_DROP = -0.6 -- the iai crouch lowers the head: aim the bust shots lower

KIT.SHIN = {}

-- The figure eight of DANSE DES COURANTS: its lobes left and right of the target, crossing
-- just behind it (never between the camera and the target). turn 0 = the crossing, 1/4 = the
-- tip of a lobe, 1/2 = the crossing again...
local EIGHT_LOBE, EIGHT_BACK, EIGHT_WIDTH = 4, -1.7, 1.7
local SHIN_EIGHT = { "Jab", "Cross", "SpinKick", "Cross", "Jab", "Sweep", "Cross", "SpinKick", "Jab", "Cross", "Elbow" }

local function eightAt(cx, dir, turn)
	local t = turn * math.pi * 2
	return cx + dir * EIGHT_LOBE * math.sin(t), EIGHT_BACK - EIGHT_WIDTH * math.sin(2 * t)
end

-- How far round the eight SHIN is at `tick`: a quarter of it between two cuts.
local function eightTurn(hits, tick)
	local k = hitsBefore(hits, tick)
	if k < 1 then return 0 end
	if k >= #hits then return (#hits - 1) / 4 end
	return (k - 1 + (tick - hits[k]) / (hits[k + 1] - hits[k])) / 4
end

-- DANSE DES COURANTS: the iai in profile, PAS DU VENT, then a single take from above while he
-- draws a figure eight around the target at full speed, cutting it at every crossing and at
-- the tip of every lobe, his wake of water left on the deck; the last cut and the eight
-- rises into a waterspout that swallows the target; he leaps over it and cleaves it from the
-- sky; the water falls back in ripples around him.
function KIT.SHIN.Rush(ctx, frame, a, d, tick, dir)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local color = ctx.characters[A].Energy
	local cx = center(ctx, d)
	local H = data.Hits
	frame.grade.current = true
	if tick < data.FinalTick then d.x, d.state = cx, "Hitstun" end
	local k = hitsBefore(H, tick)
	local beat = if k > 0 then tick - H[k] else 0
	local stop, leap = cx - dir * 4.4, data.FinalTick - 10
	if tick < 14 then
		a.x, a.facing, a.pose = cx - dir * 7, dir, "Iai"
		frame.shot = frameOn("shin-danse-iai", dir, { a }, { yaw = 6, pitch = -2, fill = 0.9, fov = 26, band = "bust", lift = IAI_DROP, focus = P(A, "Head") })
	elseif tick < H[1] then
		-- PAS DU VENT into the crossing behind the target.
		local p = smooth(progress(tick, 14, H[1]))
		local ex, ez = eightAt(cx, dir, 0)
		a.x, a.z, a.facing = lerp(cx - dir * 7, ex, p), lerp(0, ez, p), dir
		attack(a, moves, role(ctx, "Rising"), true)
		frame.speedLines = color
		frame.shot = frameOn("shin-danse-glide", dir, { a, d }, { yaw = 0, pitch = 2, fill = 0.66, fov = 32, focus = P(D, "UpperTorso") })
	elseif k < #H then
		-- The figure eight, one take from above turning slowly: a cut at every quarter, a
		-- dash between two, the wake left on the deck.
		local turn = eightTurn(H, tick)
		local x, z = eightAt(cx, dir, turn)
		a.x, a.z = x, z
		a.ghost = true
		if beat < 4 then
			faceTo(a, cx, 0)
			attack(a, moves, role(ctx, SHIN_EIGHT[(k - 1) % #SHIN_EIGHT + 1]), true)
		else
			local px, pz = eightAt(cx, dir, turn - 0.02)
			faceTo(a, x + (x - px), z + (z - pz))
			a.pose = "Dash"
		end
		d.hitstop = if beat < 4 then 1 else 0
		local angle = k * 0.9
		slash(frame, "danse-cut" .. k, v(cx - math.cos(angle) * 2.4, 3.4 - math.sin(angle) * 2.4, 0.5),
			v(cx + math.cos(angle) * 2.4, 3.4 + math.sin(angle) * 2.4, 0.5), color)
		local px, pz = eightAt(cx, dir, eightTurn(H, tick - 2))
		wake(frame, "danse-wake" .. tick, v(px, 0.05, pz), v(x, 0.05, z), color, 1.8)
		local p = progress(tick, H[1], H[#H])
		frame.shot = frameOn("shin-danse-eight", dir, { d,
			{ point = true, x = cx - dir * (EIGHT_LOBE + 0.8), y = 0.5, z = EIGHT_BACK },
			{ point = true, x = cx + dir * (EIGHT_LOBE + 0.8), y = 0.5, z = EIGHT_BACK },
			{ point = true, x = cx, y = 0.5, z = EIGHT_BACK - EIGHT_WIDTH - 0.8 } },
			{ yaw = lerp(-35, 35, p), pitch = 64, fill = 0.84, fov = 44, focus = P(D, "UpperTorso") })
	elseif tick < leap then
		-- The last cut; the eight rises into a waterspout that swallows the target while he
		-- slides out of it, into iai.
		local p = progress(tick, H[#H], leap)
		local ex, ez = eightAt(cx, dir, (#H - 1) / 4)
		if beat < 4 then
			a.x, a.z = ex, ez
			faceTo(a, cx, 0)
			attack(a, moves, role(ctx, SHIN_EIGHT[#SHIN_EIGHT]), true)
			a.ghost = true
		else
			-- (round behind the target, never through it)
			local q = smooth(progress(tick, H[#H] + 4, leap))
			a.x, a.z, a.facing, a.pose = lerp(ex, stop, q), ez * (1 - q), dir, "Iai"
		end
		d.y, d.pose = lerp(0, 4.2, smooth(p)), "Launched"
		waterspout(frame, "danse-spout", v(cx, 0, 0), 2.4, 13, color, (data.FinalTick + 6 - H[#H]) / 60)
		frame.shot = frameOn("shin-danse-spout", dir, { a, d, { point = true, x = cx, y = 9, z = 0 } }, { yaw = -26, pitch = -20,
			fill = 0.84, fov = 46, focus = P(D, "UpperTorso") })
	elseif tick < data.FinalTick then
		-- He leaps over the waterspout, the blade raised, seen from the floor.
		local p = smooth(progress(tick, leap, data.FinalTick))
		d.y, d.pose = 4.2, "Launched"
		a.x, a.facing, a.y = lerp(stop, cx - dir * 1.2, p), dir, lerp(0, 9.6, p)
		attack(a, moves, role(ctx, "Hammer"), false)
		frame.shot = frameOn("shin-danse-leap", dir, { a, d }, { yaw = 22, pitch = -44, fill = 0.7, fov = 54, focus = P(A, "UpperTorso") })
	elseif tick < data.FinalTick + 14 then
		-- The cleave from the sky splits the waterspout; the water bursts out in rings.
		local p = progress(tick, data.FinalTick, data.FinalTick + 8)
		a.x, a.facing, a.y = cx - dir * 1.2, dir, lerp(9.6, 0, p * p)
		attack(a, moves, role(ctx, "Hammer"), true)
		d.y = math.max(d.y, lerp(4.2, 0, p))
		slash(frame, "danse-cleave", v(cx - dir * 2.6, 15, -0.6), v(cx + dir * 2.2, 0, 0.8), color)
		impact(frame, "danse-cleave", v(cx, 4.4, 0.6), color, 2.8)
		for i = 1, 4 do ring(frame, "danse-burst" .. i, cx, 1.6 + i * 1.3, i * 2.4, color) end
		frame.shot = frameOn("shin-danse-cleave", dir, { a, d, { point = true, x = cx, y = 13, z = 0 } }, { yaw = -8, pitch = -12,
			fill = 0.62, fov = 50, focus = P(D, "UpperTorso") })
	else
		-- Back on the deck, the blade flicked clean; the water falls back in ripples.
		a.x, a.y, a.facing, a.pose = cx - dir * 2.6, 0, dir, "StandTall"
		if tick % 5 == 0 then
			ring(frame, "danse-ripple" .. tick, cx + ((tick * 7) % 5 - 2) * 0.9, 0.6 + (tick % 3) * 0.5, 0.06, color)
		end
		frame.shot = frameOn("shin-danse-wake", dir, { a }, { yaw = lerp(50, 20, progress(tick, data.FinalTick + 14, data.Length)), pitch = 0,
			fill = 0.75, fov = 30, focus = P(A, "UpperTorso") })
	end
end

-- TEMPÊTE CONTINUE: his eyes, the current rising around him in rings while the camera
-- cranes up, PAS DU VENT, a storm of cuts all around the target (the camera orbiting the
-- other way, overhead every third), the current lifting the target, the rising slash (one
-- vertical line to the sky), a cross of light, SHIN still.
function KIT.SHIN.Awaken(ctx, frame, a, d, tick, dir, color)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local cx = center(ctx, d)
	local last = data.Hits[#data.Hits]
	frame.grade.crimson, frame.grade.current = false, true
	if tick < data.FinalTick then d.x, d.state = cx, "Hitstun" end
	if tick < 30 then
		frame.kanjiBack = ctx.characters[A].Kanji
		a.x, a.facing, a.pose = cx - dir * 7, dir, "Iai"
		frame.shot = frameOn("shin-tempete-eyes", dir, { a }, { yaw = 44, pitch = 0, fill = lerp(0.95, 1.05, tick / 30), fov = 24, band = "bust", lift = IAI_DROP,
			focus = P(A, "Head") })
	elseif tick < 56 then
		local p = progress(tick, 30, 56)
		a.x, a.facing, a.pose = cx - dir * 7, dir, "Iai"
		if tick % 4 == 0 then
			arc(frame, "tempete-current" .. tick, v(a.x, 0.4 + (tick - 30) * 0.18, 0), 1.6 + (tick % 8) * 0.1, 0, 300, color, math.pi / 2, 1)
		end
		frame.shot = frameOn("shin-tempete-rise", dir, { a }, { yaw = lerp(-30, 30, p), pitch = lerp(-12, 18, p), fill = 0.8, fov = 34,
			focus = P(A, "UpperTorso") })
	elseif tick < data.Hits[1] then
		a.x, a.facing = lerp(cx - dir * 7, cx - dir * 3, smooth(progress(tick, 56, data.Hits[1]))), dir
		attack(a, moves, role(ctx, "Rising"), true)
		frame.speedLines = color
		frame.shot = frameOn("shin-tempete-step", dir, { a, d }, { yaw = -4, pitch = 0, fill = 0.66, fov = 32, focus = P(A, "UpperTorso") })
	elseif tick < last + 4 then
		local k = math.max(1, hitsBefore(data.Hits, tick))
		local p = progress(tick, data.Hits[1], last + 4)
		around(a, cx, dir, lerp(0.1, 0.9, p) * math.pi, 3)
		attack(a, moves, role(ctx, SHIN_CUTS[(k * 3) % #SHIN_CUTS + 1]), true)
		d.hitstop = if tick - data.Hits[k] < 4 then 1 else 0
		arc(frame, "tempete-cut" .. k, v(cx, 3 + (k % 3) * 0.5, 0), 2.8, k * 55, k * 55 + 200, color, (k % 3 - 1) * 0.7, dir)
		if k % 3 == 0 then
			frame.shot = frameOn("shin-tempete-overhead", dir, { a, d }, { yaw = 10, pitch = 70, fill = 0.55, fov = 42, focus = P(D, "UpperTorso") })
		else
			frame.shot = frameOn("shin-tempete-orbit", dir, { a, d }, { yaw = lerp(60, -60, p), pitch = 6, fill = 0.66, fov = 36,
				focus = P(D, "UpperTorso") })
		end
	elseif tick < data.FinalTick - 12 then
		-- The current lifts the target; he waits under it, in iai.
		local p = progress(tick, last + 4, data.FinalTick - 12)
		a.x, a.z, a.lookDir, a.facing, a.pose = cx - dir * 1.8, nil, nil, dir, "Iai"
		d.y, d.pose = lerp(0, 3, smooth(p)), "Launched"
		if tick % 4 == 0 then ring(frame, "tempete-spiral" .. tick, cx, 2.2 - p * 0.6, 0.4 + p * 3 + (tick % 8) * 0.2, color) end
		frame.shot = frameOn("shin-tempete-lift", dir, { a, d }, { yaw = 30, pitch = -18, fill = 0.7, fov = 40, focus = P(A, "Head") })
	elseif tick < data.FinalTick then
		-- The rising slash: one vertical line from the floor to the sky.
		local q = smooth(progress(tick, data.FinalTick - 12, data.FinalTick))
		a.x, a.z, a.lookDir, a.facing = cx - dir * 1.8, nil, nil, dir
		a.y, d.y, d.pose = q * 5, 3 + q * 6, "Launched"
		attack(a, moves, role(ctx, "Uppercut"), true)
		slash(frame, "tempete-rise", v(cx, 0, 0.5), v(cx, 18, 0.5), color)
		frame.impact = { key = "tempete-rise", color = color }
		frame.shot = frameOn("shin-tempete-skyward", dir, { a, d }, { yaw = 14, pitch = -46, fill = 0.66, fov = 54, focus = P(D, "UpperTorso") })
	elseif tick < data.FinalTick + 16 then
		a.x, a.y, a.facing = cx - dir * 1.8, lerp(5, 0, progress(tick, data.FinalTick, data.FinalTick + 8)), dir
		attack(a, moves, role(ctx, "Uppercut"), true)
		slash(frame, "tempete-split", v(cx - 8, 7, 0.5), v(cx + 8, 7, 0.5), color)
		impact(frame, "tempete-split", v(cx, 7, 0.6), color, 3)
		frame.shot = frameOn("shin-tempete-split", dir, { a, d }, { yaw = -20, pitch = 10, fill = 0.5, fov = 46, focus = P(D, "UpperTorso") })
	else
		a.x, a.y, a.facing, a.pose = cx - dir * 2.6, 0, dir, "StandTall"
		title(ctx, frame, color, "流 · SHIN")
		frame.shot = frameOn("shin-tempete-still", dir, { a }, { yaw = lerp(20, -10, progress(tick, data.FinalTick + 16, data.Length)), pitch = -2,
			fill = 0.8, fov = 30, focus = P(A, "Head") })
	end
end

-- 零 ZÉRO HORIZON: two tiny figures on the horizon, 零 under his feet as he lowers into iai,
-- the long walk without hurry, two cuts too fast to see, the hand on the hilt (press R),
-- then one line from one end of the horizon to the other.
function KIT.SHIN.Gate(ctx, frame, a, d, tick, dir)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local color = ctx.characters[A].Energy
	local cx = center(ctx, d)
	frame.grade.current = true
	if tick < data.FinalTick then d.x, d.state = cx, "Hitstun" end
	if tick < 30 then
		a.x, a.facing, a.pose = cx - dir * 8, dir, "StandTall"
		d.state = "Idle"
		frame.shot = frameOn("shin-zero-horizon", dir, { a, d }, { yaw = 0, pitch = 1, fill = 0.26, fov = 28, focus = P(A, "UpperTorso") })
	elseif tick < 60 then
		a.x, a.facing, a.pose = cx - dir * 8, dir, "Iai"
		table.insert(frame.fx, { key = "zero-seal", kind = "kanjiSeal", pos = v(a.x, 0.06, 0), color = color, text = "零", keep = true })
		frame.shot = frameOn("shin-zero-breath", dir, { a }, { yaw = 16, pitch = 0, fill = lerp(0.75, 0.9, progress(tick, 30, 60)), fov = 26,
			band = "bust", lift = IAI_DROP, focus = P(A, "Head") })
	elseif tick < data.Hits[1] - 4 then
		local p = progress(tick, 60, data.Hits[1] - 4)
		a.x, a.facing, a.state, a.vx = lerp(cx - dir * 8, cx - dir * 3.2, p), dir, "Walking", dir * 3
		frame.shot = frameOn("shin-zero-walk", dir, { a, d }, { yaw = lerp(-10, 10, p), pitch = -2, fill = 0.6, fov = 30, focus = P(A, "UpperTorso") })
	elseif tick < data.PromptTicks[1] - 14 then
		a.x, a.facing = cx - dir * 3.2, dir
		local second = tick >= data.Hits[2]
		attack(a, moves, role(ctx, if second then "Cross" else "Jab"), true)
		arc(frame, "zero-cut" .. (if second then 2 else 1), v(cx, 3.6, 0.4), 3.2, if second then 200 else -20, if second then 20 else 160,
			color, 0.3, dir)
		frame.shot = frameOn("shin-zero-cuts", dir, { a, d }, { yaw = 38, pitch = 4, fill = 0.82, fov = 32, focus = P(D, "UpperTorso") })
	elseif tick < data.FinalTick then
		a.x, a.facing, a.pose = cx - dir * 3.4, dir, "Iai"
		frame.grade.mono = tick >= data.PromptTicks[1] - 4
		frame.shot = frameOn("shin-zero-hilt", dir, { a }, { yaw = 34, pitch = -6, fill = lerp(0.9, 1.05, progress(tick, data.PromptTicks[1] - 14,
			data.FinalTick)), fov = 26, band = "bust", lift = IAI_DROP, focus = P(A, "Head") })
	elseif tick < data.FinalTick + 22 then
		a.x, a.facing = cx + dir * 4, dir
		attack(a, moves, role(ctx, "Finale"), true)
		slash(frame, "zero-line", v(cx - 40, 3.6, 0.4), v(cx + 40, 3.6, 0.4), color)
		impact(frame, "zero-line", v(cx, 3.6, 0.6), "FFFFFF", 2.4)
		frame.shot = frameOn("shin-zero-line", dir, { a, d }, { yaw = 0, pitch = 1, fill = 0.3, fov = 28, focus = P(D, "UpperTorso") })
	else
		a.x, a.facing, a.pose = cx + dir * 4, dir, "StandTall"
		a.lookDir = v(dir * 0.2, 0, -1)
		local t = kitOf(ctx).GateTitle
		frame.title = { text = t.text, color = color, sub = t.sub }
		frame.shot = frameOn("shin-zero-after", dir, { a }, { yaw = -24, pitch = 0, fill = 0.7, fov = 30, focus = P(A, "UpperTorso") })
	end
end

-- ---------------------------------------------------------------- DAICHA 闇 · inverted shadow

local DAICHA_CLAWS = { "Jab", "Cross", "Elbow", "Kick", "SpinKick", "PalmStrike", "BodyBlow" }

KIT.DAICHA = {}

-- A pool of shadow on the floor where he rises.
local function pool(frame, key, a, color)
	arc(frame, key, v(a.x, 0.08, a.z or 0), 1.3, 0, 360, color, math.pi / 2, 1)
end

-- DOMAINE OBSCUR: he never touches the target. His seal spreads under it; his orb splits in
-- his raised hand, 2 then 4 orbs; they leave him and crown the target, darting into it one by
-- one (seen over his shoulder, then close); 8 orbs on two crossed rings (from straight above,
-- the camera turning with them); a vortex of orbs lifts the target (from below, the world
-- upside down); every orb flies up and merges into the SPHÈRE INVERSÉE, which falls on it;
-- the domain implodes.
function KIT.DAICHA.Rush(ctx, frame, a, d, tick, dir)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local color = ctx.characters[A].Energy
	local cx = center(ctx, d)
	local H = data.Hits
	frame.grade.inverse = true
	if tick < data.FinalTick then
		d.x, d.state = cx, "Hitstun"
		table.insert(frame.fx, { key = "domaine-seal", kind = "kanjiSeal", pos = v(cx, 0.06, 0), color = color,
			text = ctx.characters[A].Kanji, keep = true })
	end
	local k = hitsBefore(H, tick)
	local beat = if k > 0 then tick - H[k] else 0
	local home = cx - dir * 6.4
	local torso = v(cx, 3.6, 0.3)
	-- The formations: where they start, their centre, radius, orbs, spin (turns/s) and tilt.
	local crown = { from = H[1], to = H[5], c = v(cx, 3.6, 0), r = 2.6, n = 4, spin = 0.6, tilt = 0.2 }
	local swarm = { from = H[5], to = H[8] + 4, c = v(cx, 3.4, 0), r = 3, n = 4, spin = 0.9, tilt = 0.6 }
	local vortex = { from = H[8] + 4, to = H[11] + 4, c = v(cx, 4, 0), r = 2.2, n = 4, spin = 1.6, tilt = 0.08 }
	local function form(key, f, offsetY, sign, radius)
		local c = v(f.c.x, f.c.y + (offsetY or 0), 0)
		orbs(frame, key, c, radius or f.r, f.n, color, (f.to - f.from) / 60, f.spin * (sign or 1), 0, f.tilt * (sign or 1))
		return c
	end
	local function dart(key, f, c, i, sign, radius)
		local turn = f.spin * (sign or 1) * (tick - f.from) / 60
		orbDart(frame, key, crownAt(c, radius or f.r, f.n, i, turn, f.tilt * (sign or 1)), torso, color)
	end
	if tick < 12 then
		a.x, a.facing, a.pose = home, dir, "Levitate"
		frame.shot = frameOn("daicha-domaine-open", dir, { a }, { yaw = 36, pitch = -14, fill = 0.9, fov = 38, roll = 16, focus = P(A, "Head") })
	elseif tick < H[1] then
		-- His orb splits in his raised hand: 2 orbs, then 4.
		a.x, a.facing = home, dir
		attack(a, moves, role(ctx, "KiBlast"), false)
		local hand = v(home + dir * 0.9, 6.6, 0.3)
		if tick < 17 then
			orbs(frame, "domaine-split2", hand, 1.1, 2, color, 5 / 60, 1.4, 0, 0.5)
		else
			orbs(frame, "domaine-split4", hand, 1.5, 4, color, (H[1] - 17) / 60, 1.4, 0, 0.5)
		end
		frame.shot = frameOn("daicha-domaine-split", dir, { a, { point = true, x = hand.x, y = hand.y + 1.2, z = 0 } }, { yaw = 24,
			pitch = -6, fill = 0.9, fov = 38, band = "bust", roll = -12, focus = P(A, "Head") })
	elseif k < 5 then
		-- The crown: four orbs circle the target; on each blow one darts into it.
		a.x, a.facing = home, dir
		attack(a, moves, role(ctx, "Elbow"), beat < 4)
		local c = form("domaine-crown", crown)
		dart("domaine-dart" .. k, crown, c, (k - 1) % crown.n + 1)
		d.hitstop = if beat < 4 then 1 else 0
		if beat < 2 then spark(frame, "domaine-hit" .. k, torso, color, 1) end
		if k <= 2 then
			frame.shot = frameOn("daicha-domaine-crown", dir, { a, d }, { yaw = 12, pitch = 12, fill = 0.68, fov = 44, roll = -8,
				focus = P(D, "UpperTorso") })
		else
			frame.shot = frameOn("daicha-domaine-ring", dir, { d, { point = true, x = cx - crown.r, y = 3.6, z = 0 },
				{ point = true, x = cx + crown.r, y = 3.6, z = 0 } }, { yaw = 30, pitch = 14, fill = 0.8, fov = 40, roll = 10,
				focus = P(D, "UpperTorso") })
		end
	elseif tick < swarm.to then
		-- The swarm: eight orbs on two crossed rings, two darts a blow, seen from straight
		-- above with the camera turning with them.
		a.x, a.facing = home, dir
		attack(a, moves, role(ctx, "PalmStrike"), beat < 4)
		local c1 = form("domaine-swarm1", swarm, -0.4, 1)
		local c2 = form("domaine-swarm2", swarm, 0.4, -1)
		dart("domaine-dart" .. k .. "a", swarm, c1, k % swarm.n + 1, 1)
		dart("domaine-dart" .. k .. "b", swarm, c2, (k + 2) % swarm.n + 1, -1)
		d.hitstop = if beat < 4 then 1 else 0
		if beat < 2 then spark(frame, "domaine-hit" .. k, torso, color, 1.2) end
		frame.shot = frameOn("daicha-domaine-swarm", dir, { d, { point = true, x = cx - 3.4, y = 3.4, z = 0 },
			{ point = true, x = cx + 3.4, y = 3.4, z = 0 } }, { yaw = lerp(0, 140, progress(tick, swarm.from, swarm.to)), pitch = 76,
			fill = 0.72, fov = 44, focus = P(D, "UpperTorso") })
	elseif tick < vortex.to then
		-- The vortex: three spinning rings stacked up the target lift it off the deck.
		a.x, a.facing, a.pose = home, dir, "Levitate"
		d.y, d.pose = lerp(0, 2.2, smooth(progress(tick, vortex.from, vortex.to))), "Launched"
		local rings = {}
		for i = 1, 3 do
			rings[i] = form("domaine-vortex" .. i, vortex, (i - 2) * 2.2 + 0.4, if i == 2 then -1 else 1, vortex.r - (i - 1) * 0.3)
		end
		if k >= 9 then
			for i = 1, 3 do
				dart("domaine-dart" .. k .. "-" .. i, vortex, rings[i], (k + i) % vortex.n + 1, if i == 2 then -1 else 1, vortex.r - (i - 1) * 0.3)
			end
		end
		d.hitstop = if k >= 9 and beat < 4 then 1 else 0
		frame.shot = frameOn("daicha-domaine-under", dir, { d, { point = true, x = cx, y = 8, z = 0 } }, { yaw = 6, pitch = -24, fill = 0.68,
			fov = 50, roll = 180, focus = P(D, "UpperTorso") })
	elseif tick < data.FinalTick then
		-- Every orb flies up and merges into the black sphere over the target.
		local sky = v(cx, 10.5, 0)
		a.x, a.facing = home, dir
		attack(a, moves, role(ctx, "KiBlast"), false)
		d.y, d.pose = 2.2, "Launched"
		local n = tick - vortex.to
		local angle = n * 2.4
		orbDart(frame, "domaine-merge" .. n, v(cx + math.cos(angle) * 2.4, 1.6 + (n % 3) * 2.2, math.sin(angle) * 2.4), sky, color)
		eclipse(frame, "domaine-sphere", sky, color, 0.55, (data.FinalTick + 4 - vortex.to) / 60)
		frame.shot = frameOn("daicha-domaine-merge", dir, { a, d, { point = true, x = sky.x, y = sky.y + 2, z = 0 } }, { yaw = 20,
			pitch = -18, fill = 0.7, fov = 52, roll = -8, focus = P(D, "UpperTorso") })
	elseif tick < data.FinalTick + 12 then
		-- The sphere falls on it; the domain implodes.
		local p = progress(tick, data.FinalTick, data.FinalTick + 6)
		a.x, a.y, a.facing = home, 0, dir
		attack(a, moves, role(ctx, "KiBlast"), true)
		d.y = math.max(d.y, lerp(2.2, 0, p))
		orbDart(frame, "domaine-fall", v(cx, 10.5, 0), v(cx, 1, 0), color)
		eclipse(frame, "domaine-crush", v(cx, 1.4, 0), color, 0.5, 0.35)
		impact(frame, "domaine-slam", v(cx, 2, 0.6), color, 3)
		for i = 1, 4 do ring(frame, "domaine-implode" .. i, cx, 8 - i * 1.6, 0.1, color) end
		frame.shot = frameOn("daicha-domaine-crush", dir, { a, d }, { yaw = 4, pitch = 72, fill = 0.5, fov = 48, roll = 24, focus = P(D, "UpperTorso") })
	else
		a.x, a.y, a.facing, a.pose = home, 0, dir, "Levitate"
		frame.shot = frameOn("daicha-domaine-close", dir, { a }, { yaw = -34, pitch = -6, fill = 0.8, fov = 40, roll = -10, focus = P(A, "Head") })
	end
end

-- RIVIÈRE D'OMBRES: his eyes upside down turning right side up, a river of shadow flowing
-- along the floor to the target (filmed at floor level), the river dragging it to him, the
-- blows rising out of its own shadow at mirrored places, a violet helix lifting it, the
-- river pulling it back down into the floor.
function KIT.DAICHA.Awaken(ctx, frame, a, d, tick, dir, color)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local cx = center(ctx, d)
	local last = data.Hits[#data.Hits]
	local tx, home = cx - dir * 2, cx - dir * 5.6 -- where the river leaves the target, and DAICHA
	frame.grade.crimson, frame.grade.inverse = false, true
	if tick < data.FinalTick then d.x, d.state = cx, "Hitstun" end
	if tick < 24 then
		frame.kanjiBack = ctx.characters[A].Kanji
		a.x, a.facing, a.pose = home, dir, "Levitate"
		frame.shot = frameOn("daicha-riviere-gaze", dir, { a }, { yaw = 36, pitch = 2, fill = 1.05, fov = 28, band = "bust",
			roll = lerp(180, 0, smooth(progress(tick, 0, 24))), focus = P(A, "Head") })
	elseif tick < 46 then
		a.x, a.facing, a.pose = home, dir, "Levitate"
		local n = (tick - 24) // 3
		ring(frame, "riviere-flow" .. n, lerp(home, cx, (n % 8) / 7), 1.2, 0.08, color)
		frame.shot = frameOn("daicha-riviere-flow", dir, { a, d }, { yaw = 72, pitch = -2, fill = 0.7, fov = 44, focus = P(D, "UpperTorso") })
	elseif tick < data.Hits[1] then
		local p = smooth(progress(tick, 46, data.Hits[1]))
		a.x, a.facing, a.pose = home, dir, "Levitate"
		d.x, d.y, d.pose = lerp(cx, tx, p), 0.6, "Launched"
		if tick % 3 == 0 then ring(frame, "riviere-drag" .. tick, d.x, 1.6, 0.08, color) end
		frame.shot = frameOn("daicha-riviere-drag", dir, { a, d }, { yaw = -14, pitch = 12, fill = 0.66, fov = 42, roll = -14,
			focus = P(D, "UpperTorso") })
	elseif tick < last + 4 then
		local k = math.max(1, hitsBefore(data.Hits, tick))
		d.x, d.y = tx, lerp(0.6, 2, progress(tick, data.Hits[1], last))
		local mirror = k % 2 == 0
		around(a, tx, dir, (if mirror then 0.78 else 0.22) * math.pi, 2.7, d.y - 0.4)
		attack(a, moves, role(ctx, DAICHA_CLAWS[(k * 2) % #DAICHA_CLAWS + 1]), true)
		a.ghost = true
		d.hitstop = if tick - data.Hits[k] < 5 then 1 else 0
		if tick - data.Hits[k] < 2 then frame.impact = { key = "riviere-hit" .. k, color = color } end
		spark(frame, "riviere-hit" .. k, v(tx, d.y + 3.4, 0.6), color, 1.2)
		if k % 3 == 0 then
			frame.shot = frameOn("daicha-riviere-under", dir, { a, d }, { yaw = 6, pitch = -22, fill = 0.7, fov = 46, roll = 180,
				focus = P(D, "UpperTorso") })
		else
			frame.shot = frameOn("daicha-riviere-strike", dir, { a, d }, { yaw = if mirror then 34 else -34, pitch = 6, fill = 0.74, fov = 40,
				roll = if mirror then 12 else -12, focus = P(D, "UpperTorso") })
		end
	elseif tick < data.FinalTick then
		local p = progress(tick, last + 4, data.FinalTick)
		a.x, a.z, a.lookDir, a.y, a.facing, a.pose = tx - dir * 3, nil, nil, 0, dir, "Levitate"
		d.x, d.y, d.pose = tx, lerp(2, 8, smooth(p)), "Launched"
		table.insert(frame.fx, { key = "riviere-helix", kind = "dragonHelix", pos = v(tx, 0, 0), color = color })
		frame.shot = frameOn("daicha-riviere-helix", dir, { a, d }, { yaw = lerp(-40, 40, p), pitch = -18, fill = 0.66, fov = 50, focus = P(A, "Head") })
	elseif tick < data.FinalTick + 16 then
		a.x, a.y, a.facing = tx - dir * 3, 0, dir
		attack(a, moves, role(ctx, "Finale"), true)
		impact(frame, "riviere-fall", v(tx, 0.5, 0.6), color, 3)
		for i = 1, 3 do ring(frame, "riviere-swallow" .. i, tx, i * 1.8, 0.08, color) end
		frame.shot = frameOn("daicha-riviere-crash", dir, { a, d }, { yaw = -8, pitch = 66, fill = 0.5, fov = 46, roll = -20, focus = P(A, "UpperTorso") })
	else
		a.x, a.y, a.facing, a.pose = tx - dir * 3, 0, dir, "Levitate"
		title(ctx, frame, color, "闇 · DAICHA")
		frame.shot = frameOn("daicha-riviere-mirror", dir, { a }, { yaw = 30, pitch = -8, fill = 0.8, fov = 38, roll = 10, focus = P(A, "Head") })
	end
end

-- 蝕 ÉCLIPSE TOTALE: a black sun rises over the deck (seen from the floor), the target lifted
-- off the floor, DAICHA at every mirror of it (jump cuts), the claw and the dark mark, the
-- world upside down at totality (press R), the corona striking down in a flash.
function KIT.DAICHA.Gate(ctx, frame, a, d, tick, dir)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local color = ctx.characters[A].Energy
	local cx = center(ctx, d)
	frame.grade.inverse = true
	if tick < data.FinalTick then d.x, d.state = cx, "Hitstun" end
	eclipse(frame, "eclipse-sun", v(cx, 17, -8), color, 1)
	if tick < 30 then
		a.x, a.facing, a.pose = cx - dir * 5, dir, "Levitate"
		d.state = "Idle"
		frame.shot = frameOn("daicha-eclipse-sky", dir, { a, d, { point = true, x = cx, y = 17, z = -8 } }, { yaw = 12, pitch = -26, fill = 0.7,
			fov = 56, focus = P(A, "UpperTorso") })
	elseif tick < 70 then
		local p = progress(tick, 30, 70)
		a.x, a.facing, a.pose = cx - dir * 5, dir, "Levitate"
		d.y, d.pose = lerp(0, 2.6, smooth(p)), "Launched"
		frame.shot = frameOn("daicha-eclipse-lift", dir, { a, d }, { yaw = -20, pitch = -8, fill = 0.72, fov = 42, roll = lerp(0, 18, p),
			focus = P(D, "UpperTorso") })
	elseif tick < data.Hits[1] - 6 then
		local step = (tick - 70) // 7
		local mirror = step % 2 == 1
		d.y, d.pose = 2.6, "Launched"
		around(a, cx, dir, (if mirror then 0.75 else 0.25) * math.pi + (step % 3) * 0.08, 3, 1.2)
		a.pose, a.ghost = "Levitate", true
		pool(frame, "eclipse-pool" .. step, a, color)
		frame.shot = frameOn(if mirror then "daicha-eclipse-mirror-r" else "daicha-eclipse-mirror-l", dir, { a, d },
			{ yaw = if mirror then 52 else -52, pitch = 4, fill = 0.72, fov = 40, roll = if mirror then -14 else 14, focus = P(D, "UpperTorso") })
	elseif tick < data.PromptTicks[1] - 14 then
		d.y, d.pose = 2.6, "Launched"
		a.x, a.z, a.lookDir, a.y, a.facing = cx - dir * 2.6, nil, nil, 1.2, dir
		local second = tick >= data.Hits[2]
		attack(a, moves, role(ctx, if second then "PalmStrike" else "Jab"), tick >= data.Hits[1])
		if second then
			table.insert(frame.fx, { key = "eclipse-mark", kind = "kanjiSeal", pos = v(cx, 0.06, 0), color = color,
				text = ctx.characters[A].Kanji, keep = true })
		end
		frame.shot = frameOn("daicha-eclipse-mark", dir, { a, d }, { yaw = 30, pitch = 2, fill = 0.8, fov = 38, roll = 8, focus = P(D, "UpperTorso") })
	elseif tick < data.FinalTick then
		-- Totality: the world upside down, his hand raised to the black sun.
		d.y, d.pose = 2.6, "Launched"
		a.x, a.y, a.facing = cx - dir * 2.8, 0, dir
		attack(a, moves, role(ctx, "Finale"), false)
		frame.grade.mono = tick >= data.PromptTicks[1] - 4
		frame.shot = frameOn("daicha-eclipse-totality", dir, { a, d }, { yaw = -30, pitch = -14, fill = lerp(0.8, 1.0, progress(tick,
			data.PromptTicks[1] - 14, data.FinalTick)), fov = 38, roll = 180, focus = P(A, "UpperTorso") })
	elseif tick < data.FinalTick + 22 then
		a.x, a.facing = cx - dir * 2.8, dir
		attack(a, moves, role(ctx, "Finale"), true)
		impact(frame, "eclipse-flash", v(cx, 3.4, 0.6), color, 3.4)
		for i = 1, 3 do
			table.insert(frame.fx, { key = "eclipse-bolt" .. i, kind = "lightning", from = v(cx + (i - 2) * 3, 17, -8), to = v(cx, 3, 0.4), color = color })
		end
		frame.shot = frameOn("daicha-eclipse-flash", dir, { a, d, { point = true, x = cx, y = 12, z = -6 } }, { yaw = 16, pitch = -10, fill = 0.6,
			fov = 54, focus = P(D, "UpperTorso") })
	else
		a.x, a.y, a.facing, a.pose = cx - dir * 3.4, 0, dir, "Levitate"
		local t = kitOf(ctx).GateTitle
		frame.title = { text = t.text, color = color, sub = t.sub }
		frame.shot = frameOn("daicha-eclipse-dawn", dir, { a }, { yaw = 40, pitch = -12, fill = 0.78, fov = 40, focus = P(A, "Head") })
	end
end

-- ---------------------------------------------------------------- HIBECARES 崩 · colossus

KIT.HIBECARES = {}

-- COLOSSE ÉVEILLÉ: few blows, every one colossal. He wakes in a ring of stone (monumental low
-- angle) and walks: every step is a quake that raises a line of rock to the target, which
-- staggers; the first blow sends it tumbling across the deck; he follows without hurry (over
-- his shoulder), the deck jolting it at every step; the second blow drives it into the floor
-- (a crater of stone, from above); four stomps juggle it higher and higher on the quakes; both
-- fists wait for it to fall back, and the third blow makes the crater; the dust settles.
function KIT.HIBECARES.Rush(ctx, frame, a, d, tick, dir)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local color = ctx.characters[A].Energy
	local cx = center(ctx, d)
	local H = data.Hits
	frame.grade.ruin = true
	local k = hitsBefore(H, tick)
	local beat = if k > 0 then tick - H[k] else 0
	local far = cx + dir * math.min(3.2, math.max(0, roomAhead(ctx, cx, dir) - 2.5)) -- where the first blow sends it
	if tick < data.FinalTick then
		d.x, d.state = if k >= 4 then far else cx, "Hitstun"
	else
		-- (the target stays at least where the blows sent it)
		d.x = if dir > 0 then math.max(d.x, far) else math.min(d.x, far)
	end
	local function step(key, x)
		-- A step of the colossus: the deck jolts, a ring of dust under his foot.
		if beat < 2 then frame.quake = 0.8 end
		table.insert(frame.fx, { key = key, kind = "shockwave", pos = v(x, 0, 0), color = color })
		table.insert(frame.fx, { key = key .. "-dust", kind = "dust", pos = v(x, 0, 0), direction = dir })
	end
	if tick < 14 then
		a.x, a.facing, a.pose = cx - dir * 5.4, dir, "Colossus"
		rocks(frame, "colosse-ring", a.x, 3.4, 8, color, 0.6)
		if tick < 4 then frame.quake = 1 end
		frame.shot = frameOn("hibecares-colosse-wake", dir, { a }, { yaw = 26, pitch = -32, fill = 0.85, fov = 46, focus = P(A, "Head") })
	elseif k < 4 then
		-- The march: every step a quake, a line of rock erupting up to the target.
		a.x, a.facing, a.state, a.vx = lerp(cx - dir * 5.4, cx - dir * 2.6, progress(tick, 14, H[4])), dir, "Walking", dir * 2.5
		if k >= 1 then
			step("colosse-step" .. k, a.x)
			rockLine(frame, "colosse-line" .. k, v(a.x + dir * 0.8, 0, -1.8), v(cx + dir * 0.8, 0, -1.8), 4, color, 0.4)
			if beat < 6 then d.y = 0.6 * math.sin(beat / 6 * math.pi) end
		end
		if k == 0 then
			frame.shot = frameOn("hibecares-colosse-step", dir, { a }, { yaw = -36, pitch = -4, fill = 0.7, fov = 40, band = "legs",
				focus = P(A, "UpperTorso") })
		elseif k == 2 then
			frame.shot = frameOn("hibecares-colosse-wave", dir, { a, d }, { yaw = 10, pitch = 48, fill = 0.66, fov = 46, focus = P(D, "UpperTorso") })
		else
			frame.shot = frameOn("hibecares-colosse-march", dir, { a, d }, { yaw = 54, pitch = -14, fill = 0.8, fov = 44, focus = P(A, "UpperTorso") })
		end
	elseif k == 4 then
		-- The first blow: the target tumbles across the deck.
		local p = progress(tick, H[4], H[5])
		a.x, a.facing = cx - dir * 2.6, dir
		attack(a, moves, role(ctx, "Smash"), true)
		d.x, d.y, d.pose = lerp(cx, far, smooth(p)), math.sin(p * math.pi) * 1.8, "Launched"
		if beat < 3 then frame.quake = 1.2 end
		impact(frame, "colosse-blow1", v(cx - dir * 0.4, 3.4, 0.6), color, 3)
		frame.shot = frameOn("hibecares-colosse-blow", dir, { a, d }, { yaw = 16, pitch = 2, fill = 0.55, fov = 46, focus = P(D, "UpperTorso") })
	elseif k < 7 then
		-- He follows without hurry, over his shoulder; each step jolts the target off the deck.
		a.x, a.facing, a.state, a.vx = lerp(cx - dir * 2.6, far - dir * 2.4, progress(tick, H[5], H[7])), dir, "Walking", dir * 2
		step("colosse-pursuit" .. k, a.x)
		if k == 5 then
			d.pose, d.lookDir = "DownFace", v(0, 0, -1)
			d.y = 0.5 * math.max(0, 1 - beat / 4)
		else
			d.pose, d.y = "Kneel", 0.4 * math.max(0, 1 - beat / 4)
		end
		frame.shot = frameOn("hibecares-colosse-pursuit", dir, { a, d }, { yaw = -38, pitch = 6, fill = 0.7, fov = 44, focus = P(D, "UpperTorso") })
	elseif k == 7 then
		-- The second blow drives it into the floor: a crater ring of stone, from above.
		a.x, a.facing = far - dir * 2.4, dir
		attack(a, moves, role(ctx, "Hammer"), true)
		d.y, d.pose, d.lookDir = 0, "DownFace", v(0, 0, -1)
		if beat < 3 then frame.quake = 1.4 end
		impact(frame, "colosse-blow2", v(far, 1.2, 0.6), color, 3)
		rocks(frame, "colosse-crater1", far, 3, 7, color, 0.5)
		debris(frame, "colosse-blow2", v(far, 0.4, 0), color, 1.2)
		frame.shot = frameOn("hibecares-colosse-smash", dir, { a, d }, { yaw = 12, pitch = 56, fill = 0.6, fov = 46, focus = P(D, "UpperTorso") })
	elseif tick < H[#H] + 6 then
		-- Four stomps: each quake throws the target higher.
		a.x, a.facing = far - dir * 2.4, dir
		attack(a, moves, role(ctx, "ThunderHeel"), beat < 5)
		local level = k - 7
		d.y, d.pose = lerp((level - 1) * 1.6, level * 1.6, smooth(progress(beat, 0, 6))), "Launched"
		if beat < 2 then frame.quake = 1 end
		table.insert(frame.fx, { key = "colosse-stomp" .. k, kind = "shockwave", pos = v(a.x, 0, 0), color = color })
		debris(frame, "colosse-stomp" .. k, v(far, 0.3, 0.2), color, 0.8)
		crack(frame, "colosse-stomp" .. k, v(a.x + dir * 0.6, 0.05, 0), v(far + dir * 1.5, 0.05, (level % 2 - 0.5) * 2.4), color)
		frame.shot = frameOn("hibecares-colosse-stomp", dir, { a, d }, { yaw = 26, pitch = -16, fill = 0.62, fov = 50, focus = P(D, "UpperTorso") })
	elseif tick < data.FinalTick then
		-- Both fists raised, he waits for it to fall back to him.
		local p = progress(tick, H[#H] + 6, data.FinalTick)
		a.x, a.facing = far - dir * 2.2, dir
		attack(a, moves, role(ctx, "Hammer"), false)
		d.y, d.pose = lerp(6.4, 2.6, p * p), "Launched"
		frame.shot = frameOn("hibecares-colosse-raise", dir, { a, d }, { yaw = -30, pitch = -36, fill = 0.72, fov = 50, focus = P(A, "UpperTorso") })
	elseif tick < data.FinalTick + 14 then
		-- The third blow: the crater, the deck shaking.
		a.x, a.facing = far - dir * 2.2, dir
		attack(a, moves, role(ctx, "Hammer"), true)
		impact(frame, "colosse-crater", v(far, 1.6, 0.6), color, 3.4)
		rocks(frame, "colosse-crater", far, 4.6, 10, color)
		debris(frame, "colosse-burst", v(far, 0.5, 0), color, 1.8)
		if tick < data.FinalTick + 5 then frame.quake = 1.8 end
		frame.shot = frameOn("hibecares-colosse-crater", dir, { a, d }, { yaw = 10, pitch = 58, fill = 0.48, fov = 48, focus = P(D, "UpperTorso") })
	else
		a.x, a.facing, a.pose = far - dir * 2.2, dir, "Colossus"
		table.insert(frame.fx, { key = "colosse-settle" .. tick // 8, kind = "dust", pos = v(a.x + dir, 0, 0), direction = -dir })
		frame.shot = frameOn("hibecares-colosse-dust", dir, { a }, { yaw = 40, pitch = -18, fill = 0.7, fov = 44, focus = P(A, "Head") })
	end
end

-- CHÂTIMENT: the king in close-up from below, a stomp that splits the floor to the target,
-- SAISIE DESTRUCTRICE, then the punishment: lifted overhead and slammed down on one side,
-- then the other, on every blow; the target planted in the fissure, ONDE DE CHOC and a ring
-- of rock erupting under it.
function KIT.HIBECARES.Awaken(ctx, frame, a, d, tick, dir, color)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local cx = center(ctx, d)
	local last = data.Hits[#data.Hits]
	frame.grade.crimson, frame.grade.ruin = false, true
	if tick < data.FinalTick then d.x, d.state = cx, "Hitstun" end
	if tick < 24 then
		frame.kanjiBack = ctx.characters[A].Kanji
		a.x, a.facing, a.pose = cx - dir * 6.5, dir, "Colossus"
		frame.shot = frameOn("hibecares-chatiment-crown", dir, { a }, { yaw = 34, pitch = -26, fill = 1.0, fov = 34, band = "bust",
			focus = P(A, "Head") })
	elseif tick < 48 then
		a.x, a.facing = cx - dir * 6.5, dir
		attack(a, moves, role(ctx, "ThunderHeel"), tick >= 34)
		if tick >= 34 then
			crack(frame, "chatiment-fissure", v(a.x + dir, 0.05, 0), v(cx + dir * 1.5, 0.05, 0.3), color)
			if tick < 36 then
				frame.impact = { key = "chatiment-stomp", color = color }
				frame.quake = 1.2
			end
		end
		frame.shot = frameOn("hibecares-chatiment-stomp", dir, { a, d }, { yaw = 8, pitch = 18, fill = 0.6, fov = 44, focus = P(A, "UpperTorso") })
	elseif tick < data.Hits[1] then
		local p = progress(tick, 48, data.Hits[1])
		if p < 0.6 then
			a.x, a.facing, a.state, a.vx = lerp(cx - dir * 6.5, cx - dir * 2.2, p / 0.6), dir, "Walking", dir * 3
		else
			a.x, a.facing = cx - dir * 2.2, dir
			attack(a, moves, role(ctx, "BodyBlow"), true)
		end
		frame.shot = frameOn("hibecares-chatiment-seize", dir, { a, d }, { yaw = -46, pitch = -10, fill = 0.8, fov = 40, focus = P(A, "UpperTorso") })
	elseif tick < last + 4 then
		-- The punishment: overhead, then slammed down beside him, one side then the other.
		local k = math.max(1, hitsBefore(data.Hits, tick))
		local beat = tick - data.Hits[k]
		local side = if k % 2 == 1 then 1 else -1
		a.x, a.facing = cx - dir * 0.6, dir
		if beat < 4 then
			d.x, d.y, d.pose = a.x + side * dir * 2.6, 0, "DownFace"
			attack(a, moves, role(ctx, "Hammer"), true)
			debris(frame, "chatiment-slam" .. k, v(d.x, 0.3, 0.4), color, 0.9)
			table.insert(frame.fx, { key = "chatiment-dust" .. k, kind = "dust", pos = v(d.x, 0, 0), direction = side * dir })
			if beat < 2 then
				frame.impact = { key = "chatiment-slam" .. k, color = color }
				frame.quake = 0.9
			end
			frame.shot = frameOn("hibecares-chatiment-slam", dir, { a, d }, { yaw = 14, pitch = 34, fill = 0.62, fov = 44, focus = P(A, "UpperTorso") })
		else
			d.x, d.y, d.pose = a.x, 6.4, "Launched"
			attack(a, moves, role(ctx, "Hammer"), false)
			frame.shot = frameOn("hibecares-chatiment-lift", dir, { a, d }, { yaw = -24, pitch = -30, fill = 0.66, fov = 50, focus = P(A, "UpperTorso") })
		end
	elseif tick < data.FinalTick then
		local p = progress(tick, last + 4, data.FinalTick)
		a.x, a.facing = cx - dir * 0.6, dir
		d.x, d.y, d.pose = cx + dir * 2, 0, "DownFace"
		attack(a, moves, role(ctx, "Rising"), false)
		if tick % 6 == 0 then
			crack(frame, "chatiment-glow" .. tick, v(d.x - 3, 0.05, (tick % 12) * 0.2 - 1), v(d.x + 3, 0.05, 1 - (tick % 12) * 0.2), color)
		end
		frame.shot = frameOn("hibecares-chatiment-fissure", dir, { a, d }, { yaw = 30, pitch = -12, fill = lerp(0.62, 0.74, p), fov = 44,
			focus = P(A, "UpperTorso") })
	elseif tick < data.FinalTick + 16 then
		a.x, a.facing = cx - dir * 0.6, dir
		attack(a, moves, role(ctx, "Rising"), true)
		impact(frame, "chatiment-eruption", v(cx + dir * 2, 2, 0.6), color, 3.4)
		rocks(frame, "chatiment-eruption", cx + dir * 2, 2.6, 7, color)
		debris(frame, "chatiment-eruption", v(cx + dir * 2, 0.4, 0), color, 1.8)
		if tick < data.FinalTick + 4 then frame.quake = 1.6 end
		frame.shot = frameOn("hibecares-chatiment-eruption", dir, { a, d }, { yaw = -16, pitch = -16, fill = 0.55, fov = 50, focus = P(D, "UpperTorso") })
	else
		a.x, a.facing, a.pose = cx - dir * 1.6, dir, "Colossus"
		title(ctx, frame, color, "崩 · HIBECARES")
		frame.shot = frameOn("hibecares-chatiment-king", dir, { a }, { yaw = 28, pitch = -28, fill = 0.82, fov = 44, focus = P(A, "Head") })
	end
end

-- 崩 RUINES DU MONDE: from far away a ring of stone pillars bursts out around both fighters,
-- a second ring closer (low, inside it), the pillars collapse and stone rains while he walks
-- through it, two blows, the king's fist drawn back (press R), and the world breaks: cracks
-- to every side, the deck shaking; the king among the ruins.
function KIT.HIBECARES.Gate(ctx, frame, a, d, tick, dir)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local color = ctx.characters[A].Energy
	local cx = center(ctx, d)
	frame.grade.ruin = true
	if tick < data.FinalTick then d.x, d.state = cx, "Hitstun" end
	local mid = cx - dir * 2.2
	if tick < 30 then
		a.x, a.facing, a.pose = cx - dir * 4.4, dir, "Colossus"
		d.state = "Idle"
		rocks(frame, "ruines-ring", mid, 9, 14, color)
		if tick < 6 then frame.quake = 1.2 end
		frame.shot = frameOn("hibecares-ruines-far", dir, { a, d, { point = true, x = mid, y = 6, z = -9 } }, { yaw = 8, pitch = 6, fill = 0.42,
			fov = 40, focus = P(A, "UpperTorso") })
	elseif tick < 70 then
		local p = progress(tick, 30, 70)
		a.x, a.facing, a.pose = cx - dir * 4.4, dir, "Colossus"
		if tick >= 44 then rocks(frame, "ruines-ring2", mid, 6, 10, color) end
		if tick >= 44 and tick < 48 then frame.quake = 0.8 end
		frame.shot = frameOn("hibecares-ruines-arena", dir, { a, d }, { yaw = lerp(-50, 20, p), pitch = -18, fill = 0.66, fov = 48, focus = P(A, "Head") })
	elseif tick < data.Hits[1] - 6 then
		local p = progress(tick, 70, data.Hits[1] - 6)
		a.x, a.facing, a.state, a.vx = lerp(cx - dir * 4.4, cx - dir * 2.4, p), dir, "Walking", dir * 2
		if tick % 5 == 0 then
			local n = (tick * 7) % 11
			debris(frame, "ruines-rain" .. tick, v(cx + (n - 5) * 0.6, 6, n % 3 - 1), color, 0.8)
			frame.quake = 0.4
		end
		frame.shot = frameOn("hibecares-ruines-collapse", dir, { a, d }, { yaw = 24, pitch = 10, fill = 0.7, fov = 44, focus = P(D, "UpperTorso") })
	elseif tick < data.PromptTicks[1] - 14 then
		a.x, a.facing = cx - dir * 2.4, dir
		local second = tick >= data.Hits[2]
		attack(a, moves, role(ctx, if second then "Elbow" else "Cross"), tick >= data.Hits[1])
		if tick >= data.Hits[1] then debris(frame, "ruines-blow" .. (if second then 2 else 1), v(cx, 2.4, 0.5), color, 0.8) end
		frame.shot = frameOn("hibecares-ruines-blows", dir, { a, d }, { yaw = -36, pitch = -8, fill = 0.82, fov = 40, focus = P(D, "UpperTorso") })
	elseif tick < data.FinalTick then
		a.x, a.facing = cx - dir * 2.6, dir
		attack(a, moves, role(ctx, "Smash"), false)
		frame.grade.mono = tick >= data.PromptTicks[1] - 4
		frame.shot = frameOn("hibecares-ruines-fist", dir, { a, d }, { yaw = 40, pitch = -30, fill = lerp(0.82, 1.0, progress(tick,
			data.PromptTicks[1] - 14, data.FinalTick)), fov = 42, focus = P(A, "UpperTorso") })
	elseif tick < data.FinalTick + 22 then
		a.x, a.facing = cx - dir * 2.6, dir
		attack(a, moves, role(ctx, "Smash"), true)
		impact(frame, "ruines-world", v(cx, 3, 0.6), color, 3.8)
		for i = 1, 8 do
			local angle = i / 8 * math.pi * 2
			crack(frame, "ruines-crack" .. i, v(cx, 0.05, 0), v(cx + math.cos(angle) * 10, 0.05, math.sin(angle) * 6), color)
		end
		debris(frame, "ruines-burst", v(cx, 0.6, 0), color, 2.2)
		if tick < data.FinalTick + 6 then frame.quake = 2 end
		frame.shot = frameOn("hibecares-ruines-world", dir, { a, d }, { yaw = -10, pitch = 26, fill = 0.42, fov = 50, focus = P(D, "UpperTorso") })
	else
		a.x, a.y, a.facing, a.pose = cx - dir * 2.6, 0, dir, "Colossus"
		local t = kitOf(ctx).GateTitle
		frame.title = { text = t.text, color = color, sub = t.sub }
		frame.shot = frameOn("hibecares-ruines-throne", dir, { a }, { yaw = -30, pitch = -14, fill = 0.6, fov = 42, focus = P(A, "Head") })
	end
end

Director.KIT_ULTIMATES = KIT

-- ===================================================================== K.O. SCENE

--[[
	Every kit closes the match its own way (`t` runs from 0 to KO_SCENE ticks, the loser lies
	face down at z = 0, head toward the camera, `side` is the winner's side of the body):
	  KAI    Wilhem's storyboard: hand on the floor, sneakers, face, back to the sunset.
	  TARO   a boxing K.O.: the glove, the referee's count from 1 to 8 filmed like a broadcast,
	         the fist raised in a pillar of fire. Handheld, fire grade.
	  ZEPHYR the wind: the body seen from the sky, a gust sweeping the deck, ZEPHYR coming down
	         from above, a slow orbit, then the camera lifts toward the sky. Sky grade.
	  AKEMI  the shadow: locked frames, the stage empty, AKEMI appears behind the body, sheathes
	         her blade and the cut lands late; she is gone, only her seal remains. Shadow grade.
	  RYUKEN the smoking fist, the roar of RAGE over the body, his back turned. Rage grade.
	  SHIN   the blade flicked clean, the slow sheathe and its click, the horizon. Current grade.
	  DAICHA a pool of shadow swallows the body; his eyes in the dark. Inverse grade.
	  HIBECARES stone erupting around the body, the dust settling, the king. Ruin grade.
]]
local KO = {}

local function koEnd(ctx, frame, W, color)
	frame.fade = true
	local data = ctx.characters[W]
	frame.title = { text = "K.O.", color = color, sub = data.Name .. " " .. data.Skin .. " · VICTOIRE" }
end

function KO.TARO(ctx, frame, W, L, w, l, t, side)
	local color = ctx.characters[W].Energy
	local dir = -side -- from the winner toward the body
	frame.grade.fire, frame.handheld = t >= 30, if t < 130 then 0.22 else 0.1
	w.x, w.z = l.x + side * 2.4, -2.4
	w.lookDir = v(-side * 0.6, 0, 0.8)
	if t < 30 then
		-- 0. The fall, black and white, from the ring apron.
		frame.grade.mono, frame.hideTitle = true, true
		l.y, l.pose = lerp(3, 0, t / 24), if t < 22 then "Launched" else "DownFace"
		w.pose = "StandTall"
		frame.shot = frameOn("ko-taro-fall", dir, { l }, { yaw = 34, pitch = 6, fill = 0.34, fov = 34, roll = -8 * side, lift = 1.6 })
		return frame
	end
	l.y, l.pose = 0, "DownFace"
	if t < 60 then
		-- 1. GANTS: the gloves pounded together over the body, embers on each tap.
		w.pose = "GloveTap"
		if t >= 34 and (t - 34) % 10 == 0 then
			spark(frame, "ko-taro-tap" .. t, v(w.x - side * 0.5, 3.6, w.z + 0.6), color, 1.2)
		end
		frame.shot = frameOn("ko-taro-gloves", dir, { w }, { yaw = 26, pitch = 4, fill = 0.92, band = "bust", fov = 36,
			focus = P(W, "RightHand") })
	elseif t < 132 then
		-- 2. LE COMPTE: 1 to 8, filmed from the side like a broadcast; the body does not move.
		w.pose = if t < 96 then "StandTall" else "GloveTap"
		local n = math.min(8, (t - 60) // 9 + 1)
		frame.title = { text = tostring(n), color = color }
		frame.shot = frameOn("ko-taro-count", dir, { w, l }, { yaw = 4, pitch = 8, fill = 0.72, fov = 40,
			focus = P(L, "Head") })
	elseif t < 166 then
		-- 3. LE POING LEVÉ: seen from the floor, inside a pillar of fire.
		frame.hideTitle = true
		w.pose = "Victory"
		table.insert(frame.fx, { key = "ko-taro-pillar", kind = "dragonHelix", pos = v(w.x, 0, w.z), color = color })
		if t == 132 then impact(frame, "ko-taro-raise", v(w.x, 6, w.z), color, 1.6) end
		frame.shot = frameOn("ko-taro-raise", dir, { w }, { yaw = 22, pitch = -12, fill = 0.58, lift = 0.8, fov = 46, roll = 6 * side,
			focus = P(W, "Head") })
	elseif t < 188 then
		-- 4. CHAMPION: high and wide over the ring, the fallen fighter at his feet.
		w.pose = "Victory"
		frame.shot = frameOn("ko-taro-champion", dir, { w, l }, { yaw = -30, pitch = 34, fill = 0.48, fov = 40 })
	else
		w.pose = "Victory"
		koEnd(ctx, frame, W, color)
		frame.shot = frameOn("ko-taro-champion", dir, { w, l }, { yaw = -30, pitch = 34, fill = 0.48, fov = 40 })
	end
	return frame
end

function KO.ZEPHYR(ctx, frame, W, L, w, l, t, side)
	local color = ctx.characters[W].Energy
	local dir = -side
	frame.grade.sky = t >= 30
	w.x, w.z = l.x + side * 3, -2.8
	w.lookDir = v(-side * 0.5, 0, 0.85)
	if t < 30 then
		-- 0. The fall, seen from the sky, black and white.
		frame.grade.mono, frame.hideTitle = true, true
		l.y, l.pose = lerp(6, 0, t / 26), if t < 24 then "Launched" else "DownFace"
		vanish(w)
		frame.shot = frameOn("ko-zephyr-sky-fall", dir, { l }, { yaw = 10, pitch = 72, fill = 0.55, fov = 40 })
		return frame
	end
	l.y, l.pose = 0, "DownFace"
	if t < 58 then
		-- 1. RAFALE: a gust sweeps the deck, filmed at floor level along the body.
		vanish(w)
		if t == 30 then table.insert(frame.fx, { key = "ko-zephyr-dust", kind = "dust", pos = v(l.x, 0, 0), direction = dir }) end
		arc(frame, "ko-zephyr-gust", v(l.x, 0.6, 0), 3.2, -40, 220, color, math.pi / 2, dir)
		frame.speedLines = color
		frame.shot = frameOn("ko-zephyr-gust", dir, { l }, { yaw = 64, pitch = 6, fill = 0.72, fov = 44,
			focus = P(L, "Head") })
	elseif t < 100 then
		-- 2. DESCENTE: ZEPHYR comes down from the sky and lands beside the body.
		local k = progress(t, 58, 82)
		w.y = lerp(10, 0, smooth(k))
		w.pose = if k < 1 then "Fall" elseif t < 88 then "Land" else "WindGather"
		if t == 82 then impact(frame, "ko-zephyr-land", v(w.x, 0.4, w.z), color, 1.4) end
		frame.shot = frameOn("ko-zephyr-descend", dir, { w, l }, { yaw = 18, pitch = -14, fill = 0.66, fov = 48,
			focus = P(W, "Head") })
	elseif t < 150 then
		-- 3. LE VENT TOURNE: a slow orbit around ZEPHYR, the wind ring at his feet.
		w.pose = "WindGather"
		ring(frame, "ko-zephyr-ring", w.x, 2.2, 0.15, color)
		frame.shot = frameOn("ko-zephyr-orbit", dir, { w }, { yaw = lerp(-50, 50, progress(t, 100, 150)), pitch = 8,
			fill = 0.78, fov = 40, focus = P(W, "Head") })
	elseif t < 188 then
		-- 4. VERS LE CIEL: the camera lifts from the floor toward the sky.
		w.pose = "StandTall"
		local k = smooth(progress(t, 150, 188))
		frame.shot = frameOn("ko-zephyr-rise", dir, { w, l }, { yaw = -12, pitch = lerp(-18, 40, k), fill = lerp(0.62, 0.4, k),
			fov = 44, lift = lerp(1.5, 0, k) })
	else
		w.pose = "StandTall"
		koEnd(ctx, frame, W, color)
		frame.shot = frameOn("ko-zephyr-rise", dir, { w, l }, { yaw = -12, pitch = 40, fill = 0.4, fov = 44 })
	end
	return frame
end

function KO.AKEMI(ctx, frame, W, L, w, l, t, side)
	local color = ctx.characters[W].Energy
	local dir = -side
	frame.grade.shadow = t >= 30
	w.x, w.z = l.x + side * 1.8, -2.2
	w.lookDir = v(-side * 0.3, 0, 0.95)
	if t < 30 then
		-- 0. The fall in a locked frame; AKEMI is already gone.
		frame.grade.mono, frame.hideTitle = true, true
		l.y, l.pose = lerp(3, 0, t / 24), if t < 22 then "Launched" else "DownFace"
		vanish(w)
		frame.shot = frameOn("ko-akemi-fall", dir, { l }, { yaw = 0, pitch = 16, fill = 0.3, fov = 32, lift = 1.6 })
		return frame
	end
	l.y, l.pose = 0, "DownFace"
	if t < 60 then
		-- 1. LE VIDE: the body alone on the stage, nothing moves.
		vanish(w)
		frame.shot = frameOn("ko-akemi-empty", dir, { l }, { yaw = -20, pitch = 22, fill = 0.42, fov = 36 })
	elseif t < 96 then
		-- 2. APPARITION: she is behind the body, out of nothing.
		w.pose = "StandTall"
		if t == 60 then spark(frame, "ko-akemi-appear", v(w.x, 3, w.z), color, 1.8) end
		frame.shot = frameOn("ko-akemi-appear", dir, { w, l }, { yaw = -20, pitch = 22, fill = 0.55, fov = 36,
			focus = P(W, "Head") })
	elseif t < 132 then
		-- 3. LA LAME RENTRE: the blade sheathed... and only then the cut lands.
		w.pose = "Sheathe"
		if t == 118 then impact(frame, "ko-akemi-cut", v(l.x, 0.8, 0.4), color, 2) end
		frame.speedLines = if t >= 118 and t < 126 then color else nil
		frame.shot = frameOn("ko-akemi-sheathe", dir, { w }, { yaw = -36, pitch = 2, fill = 0.9, band = "bust", fov = 30,
			focus = P(W, "Head") })
	elseif t < 168 then
		-- 4. DOS TOURNÉ: she turns her back on the body, low static frame.
		w.pose = "StandTall"
		w.lookDir = v(side * 0.4, 0, -0.9)
		frame.shot = frameOn("ko-akemi-back", dir, { w, l }, { yaw = 24, pitch = -6, fill = 0.62, fov = 34,
			focus = P(W, "UpperTorso") })
	else
		-- 5. DISPARUE: only the body and her seal remain.
		vanish(w)
		table.insert(frame.fx, { key = "ko-akemi-seal", kind = "kanjiSeal", pos = v(l.x, 0.06, 0), color = color, text = "影" })
		if t >= 188 then koEnd(ctx, frame, W, color) end
		frame.shot = frameOn("ko-akemi-gone", dir, { l }, { yaw = 0, pitch = 48, fill = 0.4, fov = 36 })
	end
	return frame
end

-- Where a standing fighter's hand hangs (right = 1, left = -1), in world space, for effects.
local function hangingHand(view, right)
	local look = view.lookDir or v(view.facing or 1, 0, 0)
	local l = math.max(1e-3, math.sqrt(look.x * look.x + (look.z or 0) * (look.z or 0)))
	local fx, fz = look.x / l, (look.z or 0) / l
	return v(view.x - fz * 1.8 * right + fx * 1.4, 2.8, (view.z or 0) + fx * 1.8 * right + fz * 1.4)
end

-- RYUKEN: smoke rising off the cracked gauntlet, the roar of RAGE over the body, his face as
-- the rage goes out of it, his back turned. Rage grade.
function KO.RYUKEN(ctx, frame, W, L, w, l, t, side)
	local color = ctx.characters[W].Energy
	local dir = -side
	frame.grade.rage = t >= 30
	w.x, w.z = l.x + side * 2.2, -2.2
	w.lookDir = v(-side * 0.5, 0, 0.85)
	if t < 30 then
		-- 0. The fall at floor level, black and white; the deck cracks under the body.
		frame.grade.mono, frame.hideTitle = true, true
		l.y, l.pose = lerp(3.5, 0, t / 22), if t < 22 then "Launched" else "DownFace"
		w.pose = "StandTall"
		if t >= 22 then crack(frame, "ko-ryuken-crack", v(l.x - 3, 0.05, 0.4), v(l.x + 3, 0.05, -0.4), color) end
		frame.shot = frameOn("ko-ryuken-fall", dir, { l }, { yaw = 40, pitch = 4, fill = 0.36, fov = 36, roll = 10 * side, lift = 1.4 })
		return frame
	end
	l.y, l.pose = 0, "DownFace"
	if t < 64 then
		-- 1. LES POINGS: the fists, tight, smoking.
		w.pose = "StandTall"
		for i, hand in { -1, 1 } do
			table.insert(frame.fx, { key = "ko-ryuken-smoke" .. i .. "-" .. t // 6, kind = "smoke", pos = hangingHand(w, hand) })
		end
		frame.shot = frameOn("ko-ryuken-fist", dir, { w }, { yaw = 30, pitch = 4, fill = 0.9, band = "waist", lift = -0.8, fov = 30,
			focus = P(W, "RightHand") })
	elseif t < 104 then
		-- 2. LE RUGISSEMENT: the roar over the body, from the floor.
		w.pose = "Roar"
		table.insert(frame.fx, { key = "ko-ryuken-roar", kind = "shockwave", pos = v(w.x, 0, w.z), color = color })
		frame.shot = frameOn("ko-ryuken-roar", dir, { w, l }, { yaw = 18, pitch = -16, fill = 0.66, fov = 46, focus = P(W, "Head") })
	elseif t < 144 then
		-- 3. LE SOUFFLE: his face, the rage going out of it.
		w.pose = "StandTall"
		frame.shot = frameOn("ko-ryuken-face", dir, { w }, { yaw = 24, pitch = -4, fill = 0.62, band = "face", fov = 28, focus = P(W, "Head") })
	else
		-- 4. DOS TOURNÉ: he turns his back on the body, high and wide.
		w.pose = "StandTall"
		w.lookDir = v(side * 0.9, 0, -0.3)
		if t >= 188 then koEnd(ctx, frame, W, color) end
		frame.shot = frameOn("ko-ryuken-leave", dir, { w, l }, { yaw = -26, pitch = 26, fill = 0.5, fov = 42 })
	end
	return frame
end

-- SHIN: the blade still drawn, flicked clean; the slow sheathe and its click rippling the
-- floor like water; both on the horizon; he walks away. Current grade, long lenses.
function KO.SHIN(ctx, frame, W, L, w, l, t, side)
	local color = ctx.characters[W].Energy
	local dir = -side
	frame.grade.current = t >= 30
	w.x, w.z = l.x + side * 3.2, -1.6
	w.lookDir = v(-side, 0, 0.2)
	if t < 30 then
		-- 0. The fall in profile, long lens, black and white.
		frame.grade.mono, frame.hideTitle = true, true
		l.y, l.pose = lerp(3, 0, t / 24), if t < 22 then "Launched" else "DownFace"
		w.pose = "Iai"
		frame.shot = frameOn("ko-shin-fall", dir, { l }, { yaw = 80, pitch = 2, fill = 0.32, fov = 26, lift = 1.2 })
		return frame
	end
	l.y, l.pose = 0, "DownFace"
	if t < 70 then
		-- 1. LA LAME: still in iai over the body; one flick of the blade.
		w.pose = "Iai"
		if t >= 36 then arc(frame, "ko-shin-flick", v(w.x, 2.4, w.z), 2.2, 200, 330, color, 0.2, -side) end
		frame.shot = frameOn("ko-shin-blade", dir, { w }, { yaw = 50, pitch = 0, fill = 0.85, band = "bust", lift = IAI_DROP, fov = 26, focus = P(W, "Head") })
	elseif t < 112 then
		-- 2. LE FOURREAU: the blade slides home; at the click the floor ripples.
		w.pose = if t < 96 then "Iai" else "StandTall"
		if t >= 96 then
			local n = (t - 96) // 4
			ring(frame, "ko-shin-ripple" .. n, w.x, 1 + n * 0.9, 0.06, color)
			if t < 100 then frame.impact = { key = "ko-shin-click", color = color } end
		end
		frame.shot = frameOn("ko-shin-sheathe", dir, { w, l }, { yaw = -20, pitch = 8, fill = 0.62, fov = 32, focus = P(W, "UpperTorso") })
	elseif t < 150 then
		-- 3. L'HORIZON: both, very small, far away along the floor.
		w.pose = "StandTall"
		frame.shot = frameOn("ko-shin-horizon", dir, { w, l }, { yaw = 4, pitch = 2, fill = 0.3, fov = 26 })
	else
		-- 4. IL S'EN VA: he walks away into the background, tracked sideways.
		local k = progress(t, 150, 188)
		w.z, w.facing = lerp(-1.6, -5, k), side
		w.lookDir = v(side * 0.3, 0, -1)
		if t < 188 then
			w.state, w.vx = "Walking", side * 2
		else
			w.pose = "StandTall"
			koEnd(ctx, frame, W, color)
		end
		frame.shot = frameOn("ko-shin-leave", dir, { w }, { yaw = -70, pitch = 0, fill = 0.72, fov = 30, focus = P(W, "UpperTorso") })
	end
	return frame
end

-- DAICHA: upside down, the fall; a pool of shadow spreading under the body; his eyes in the
-- dark; the shadow swallows the body; DAICHA alone on his seal. Inverse grade.
function KO.DAICHA(ctx, frame, W, L, w, l, t, side)
	local color = ctx.characters[W].Energy
	local dir = -side
	frame.grade.inverse = t >= 30
	w.x, w.z = l.x + side * 2.6, -2.6
	w.lookDir = v(-side * 0.4, 0, 0.9)
	if t < 30 then
		-- 0. The fall, the world upside down, black and white.
		frame.grade.mono, frame.hideTitle = true, true
		l.y, l.pose = lerp(3, 0, t / 24), if t < 22 then "Launched" else "DownFace"
		w.pose = "Levitate"
		frame.shot = frameOn("ko-daicha-fall", dir, { l }, { yaw = 20, pitch = 10, fill = 0.34, fov = 34, roll = 180, lift = 1.4 })
		return frame
	end
	l.y, l.pose = 0, "DownFace"
	w.pose = "Levitate"
	if t < 70 then
		-- 1. L'OMBRE: a pool of shadow spreads under the body, seen from above, the frame turning.
		local n = (t - 30) // 6
		ring(frame, "ko-daicha-pool" .. n, l.x, 0.8 + n * 0.5, 0.06, color)
		frame.shot = frameOn("ko-daicha-pool", dir, { l }, { yaw = 0, pitch = 72, fill = 0.4, fov = 40, roll = -(t - 30) * 0.8 })
	elseif t < 110 then
		-- 2. LES YEUX: DAICHA in the dark, only his eyes glowing.
		if t >= 74 then spark(frame, "ko-daicha-eyes", v(w.x, 5.3, w.z + 0.5), color, 0.5) end
		frame.shot = frameOn("ko-daicha-eyes", dir, { w }, { yaw = 22, pitch = -6, fill = 0.85, band = "bust", fov = 28, roll = -8,
			focus = P(W, "Head") })
	elseif t < 150 then
		-- 3. ENGLOUTI: the shadow coils up around the body and swallows it.
		if t < 132 then
			table.insert(frame.fx, { key = "ko-daicha-swallow", kind = "dragonHelix", pos = v(l.x, 0, 0), color = color })
		else
			vanish(l)
		end
		frame.shot = frameOn("ko-daicha-swallow", dir, { w, { point = true, x = l.x, y = 0.4, z = 0 } }, { yaw = -24, pitch = 30, fill = 0.55,
			fov = 42, focus = P(W, "UpperTorso") })
	else
		-- 4. SEUL: DAICHA alone on his seal, a dutch angle.
		vanish(l)
		table.insert(frame.fx, { key = "ko-daicha-seal", kind = "kanjiSeal", pos = v(w.x, 0.06, w.z), color = color, text = "闇" })
		if t >= 188 then koEnd(ctx, frame, W, color) end
		frame.shot = frameOn("ko-daicha-alone", dir, { w }, { yaw = 30, pitch = -10, fill = 0.7, fov = 40, roll = 14, focus = P(W, "Head") })
	end
	return frame
end

-- HIBECARES: the deck caves in under the fall; stone erupts around the body; the dust
-- settles at floor level; the king from below; the ruins far and wide. Ruin grade.
function KO.HIBECARES(ctx, frame, W, L, w, l, t, side)
	local color = ctx.characters[W].Energy
	local dir = -side
	frame.grade.ruin = t >= 30
	w.x, w.z = l.x + side * 3.4, -2.8
	w.lookDir = v(-side * 0.5, 0, 0.85)
	w.pose = "Colossus"
	if t < 30 then
		-- 0. The fall, black and white, the deck caving in.
		frame.grade.mono, frame.hideTitle = true, true
		l.y, l.pose = lerp(4, 0, t / 22), if t < 22 then "Launched" else "DownFace"
		if t >= 22 then
			debris(frame, "ko-hibecares-impact", v(l.x, 0.3, 0), color, 1.2)
			if t < 26 then frame.quake = 1.4 end
		end
		frame.shot = frameOn("ko-hibecares-fall", dir, { l }, { yaw = -30, pitch = -2, fill = 0.36, fov = 40, lift = 1.2 })
		return frame
	end
	l.y, l.pose = 0, "DownFace"
	if t < 70 then
		-- 1. LES DÉCOMBRES: stone erupts in a ring around the body.
		rocks(frame, "ko-hibecares-rocks", l.x, 2.3, 7, color)
		if t < 34 then frame.quake = 1 end
		frame.shot = frameOn("ko-hibecares-rubble", dir, { l, w }, { yaw = 30, pitch = 24, fill = 0.5, fov = 44 })
	elseif t < 112 then
		-- 2. LA POUSSIÈRE: at floor level along the body, the dust settles.
		table.insert(frame.fx, { key = "ko-hibecares-dust" .. (t - 70) // 8, kind = "dust", pos = v(l.x, 0, 0), direction = side })
		frame.shot = frameOn("ko-hibecares-dust", dir, { l }, { yaw = 24, pitch = 6, fill = 0.66, fov = 40, focus = P(L, "Head") })
	elseif t < 150 then
		-- 3. LE ROI: monumental, from the floor.
		frame.shot = frameOn("ko-hibecares-king", dir, { w }, { yaw = -34, pitch = -30, fill = 0.85, fov = 46, focus = P(W, "Head") })
	else
		-- 4. LES RUINES: far and wide, the king and the body among the stones.
		if t >= 188 then koEnd(ctx, frame, W, color) end
		frame.shot = frameOn("ko-hibecares-ruins", dir, { w, l }, { yaw = -20, pitch = 12, fill = 0.36, fov = 40 })
	end
	return frame
end

-- The K.O. scene of the winner's kit. `t` runs from 0 to KO_SCENE ticks.
function Director.ko(ctx, winner, loser, w, l, t)
	local frame = newFrame()
	local anchors = ctx.anchors
	anchors.koSide = anchors.koSide or (if w.x >= l.x then 1 else -1)
	local side = anchors.koSide
	local W, L = winner, loser
	-- The loser lies face down, head toward the camera; the winner stands behind.
	l.state, l.lookDir, l.z = "KO", v(0, 0, 1), 0
	w.victory, w.state, w.vx, w.y = false, "Idle", 0, 0
	local own = KO[w.kit or (ctx.characters[W] and ctx.characters[W].Name) or "KAI"]
	if own then return own(ctx, frame, W, L, w, l, t, side) end
	-- KAI: Wilhem's storyboard.
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
