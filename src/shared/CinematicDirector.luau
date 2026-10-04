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
		black = 0..1?,                                -- the screen goes black (KAI's COUP FATAL)
		speedLines = color?,                          -- anime speed lines over the frame
		impact = { key, color }?,                     -- impact frame + zoom punch, once per key
	}
]]
local Director = {}

local RED = "E0102B"
Director.KO_SCENE = 200 -- ticks of the K.O. scene (same as the FINAL FINISH extension)
-- The normals KAI cycles through during the strikes of his ÉVEIL.
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

-- Fast out, slowing to the top of an arc (a body thrown up).
local function easeOutArc(t)
	t = math.clamp(t, 0, 1)
	return 1 - (1 - t) * (1 - t)
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
	local own = ctx.cin.kit and data.Kits and data.Kits[ctx.cin.kit]
	if own and own.Boss then return own end -- (a boss borrows another kit's moves)
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

-- A flat ring of light on the floor (or in the air) around x = cx.
local function ring(frame, key, cx, radius, y, color)
	arc(frame, key, v(cx, y, 0), radius, 0, 360, color, math.pi / 2, 1)
end

-- Room left behind the target toward the wall it is pushed to.
local function roomAhead(ctx, cx, dir)
	return math.max(0, if dir > 0 then ctx.config.ArenaMaxX - cx else cx - ctx.config.ArenaMinX)
end

-- A rotating set of strong angles for hard cuts on each hit of a barrage.
local CUTS = {
	{ yaw = 58, pitch = 8, fill = 0.78, fov = 42, roll = 0 },          -- three-quarter two-shot
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
	local H = data.Hits
	local k = hitsBefore(H, tick)
	local beat = if k > 0 then tick - H[k] else 0
	local peak = 13 -- how high the chase goes
	if tick < data.FinalTick then d.x, d.state = cx, "Hitstun" end
	-- KAIEN RUSH: the launcher, then a chase through the sky: KAI blinks around the target from
	-- every side, each clash a ring of ki in the air (filmed from below against the sky, then
	-- from above with the deck far down); he spikes it back to the deck, hovers high with his
	-- ki gathered in both hands and fires a beam of ki straight down on it.
	if tick < 10 then
		a.x, a.facing, a.pose = cx - dir * 9, dir, "Kiai"
		frame.aura = A
		frame.shot = frameOn("rush-ready", dir, { a }, { yaw = -132, pitch = -10, fill = 0.8, fov = 40, focus = P(A, "UpperTorso") })
	elseif tick < H[1] then
		a.x, a.facing, a.pose = lerp(cx - dir * 9, cx - dir * 2.4, smooth(progress(tick, 10, H[1]))), dir, "Dash"
		a.ghost = true
		frame.speedLines = color
		frame.shot = frameOn("rush-dash", dir, { a }, { yaw = 4, pitch = -6, fill = 0.72, fov = 46, focus = P(A, "UpperTorso") })
	elseif k == 1 then
		-- The launcher: the target leaves the deck.
		local p = progress(tick, H[1], H[2])
		a.x, a.facing, a.y = cx - dir * 2, dir, p * 2
		attack(a, moves, role(ctx, "Uppercut"), true)
		d.y, d.pose = lerp(0, 6, smooth(p)), "Launched"
		if beat < 2 then frame.impact = { key = "rush-launch", color = color } end
		spark(frame, "rush-launch", v(cx, 3, 0.6), color, 2)
		table.insert(frame.fx, { key = "rush-launch-wave", kind = "shockwave", pos = v(cx, 0, 0), color = color })
		frame.shot = frameOn("rush-launch", dir, { a, d }, { yaw = 24, pitch = -30, fill = 0.72, fov = 50, focus = P(D, "UpperTorso") })
	elseif k <= 9 then
		-- The sky chase: a blink to another side of the target at every blow.
		local p = progress(tick, H[2], H[10])
		d.y, d.pose = lerp(6, peak, p), "Launched"
		local angle = ((k * 0.37) % 1) * math.pi
		local over = if k % 3 == 0 then 1.8 elseif k % 3 == 1 then -1.2 else 0.2
		around(a, cx, dir, angle, 2.5, d.y + over)
		attack(a, moves, role(ctx, if over > 1 then "AirSmash" elseif k % 2 == 0 then "AirKick2" else "AirKick"), beat < 5)
		a.ghost = beat < 2
		d.hitstop = if beat < 4 then 1 else 0
		if beat < 2 then frame.impact = { key = "rush-clash" .. k, color = color } end
		ring(frame, "rush-clash" .. k, cx, 2.2 + (k % 2), d.y + 3, color)
		spark(frame, "rush-sky" .. k, v(cx, d.y + 3.4, 0.6), color, 1.4)
		frame.speedLines = color
		if k == 2 then
			frame.shot = frameOn("rush-launch", dir, { a, d }, { yaw = 24, pitch = -30, fill = 0.72, fov = 50, focus = P(D, "UpperTorso") })
		elseif k <= 5 then
			frame.shot = frameOn("rush-sky-below", dir, { a, d }, { yaw = lerp(-40, 40, p), pitch = -42, fill = 0.66, fov = 52,
				focus = P(D, "UpperTorso") })
		else
			frame.shot = frameOn("rush-sky-above", dir, { a, d }, { yaw = lerp(40, -20, p), pitch = 58, fill = 0.6, fov = 50,
				focus = P(D, "UpperTorso") })
		end
	elseif tick < H[11] + 8 then
		-- Spiked back down: the target falls the whole way to the deck.
		local p = progress(tick, H[10], H[11] + 6)
		a.x, a.facing, a.y = cx - dir * 1.4, dir, lerp(peak + 2, 2, p * p)
		a.z, a.lookDir = nil, nil
		attack(a, moves, role(ctx, "AirSmash"), true)
		d.y = lerp(peak, 0, p * p)
		d.pose = if p < 1 then "Launched" else "DownFace"
		a.ghost = true
		frame.speedLines = color
		if p >= 1 then
			impact(frame, "rush-meteor", v(cx, 0.6, 0.6), color, 2.6)
			for i = 1, 4 do ring(frame, "rush-crater" .. i, cx, i * 1.4, 0.1, color) end
		end
		frame.shot = frameOn("rush-meteor", dir, { a, d }, { yaw = 30, pitch = -10, fill = 0.62, fov = 52, focus = P(D, "UpperTorso") })
	elseif tick < data.FinalTick then
		-- He hovers high above it, ki gathered in both hands.
		local p = progress(tick, H[11] + 8, data.FinalTick)
		a.x, a.facing, a.y = cx - dir * 2.6, dir, lerp(2, 10, smooth(math.min(1, p * 2)))
		attack(a, moves, role(ctx, "KiBlast"), false)
		d.y, d.pose = 0, "DownFace"
		frame.aura = A
		spark(frame, "rush-gather" .. tick // 3, v(a.x + dir * 0.8, a.y + 3.2, 0.6), color, 0.6 + p * 1.6)
		frame.shot = frameOn("rush-gather", dir, { a }, { yaw = -30, pitch = -28, fill = lerp(0.75, 0.95, p), fov = 44, focus = P(A, "UpperTorso") })
	elseif tick < data.FinalTick + 16 then
		-- The beam of ki straight down on the target.
		a.x, a.facing, a.y = cx - dir * 2.6, dir, 10
		attack(a, moves, role(ctx, "KiBlast"), true)
		a.pose = "KiBeamDown" -- (bent over the target: the beam leaves his joined palms, straight down)
		table.insert(frame.fx, { key = "rush-beam", kind = "kiBeam", from = v(a.x + dir * 1.2, a.y + ctx.config.RootHeight - 0.9, 0.6),
			to = v(cx, 0.4, 0.4),
			color = color, scale = 1.6 })
		impact(frame, "rush-final", v(cx, 1, 0.6), color, 3)
		for i = 1, 3 do table.insert(frame.fx, { key = "rush-blast" .. i, kind = "tornadoRing", pos = v(cx, i * 1.2, 0), color = color }) end
		frame.shot = frameOn("rush-beam", dir, { a, d }, { yaw = 14, pitch = 0, fill = 0.6, fov = 50, focus = P(D, "UpperTorso") })
	else
		a.x, a.facing, a.y = cx - dir * 2.6, dir, lerp(10, 0, smooth(progress(tick, data.FinalTick + 16, data.Length - 6)))
		a.pose = "StandTall"
		frame.shot = frameOn("rush-follow", dir, { a, d }, { yaw = 12, pitch = 12, fill = 0.55, fov = 42, focus = P(A, "UpperTorso") })
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
		-- (a new angle every two blows: hard cuts, but never a strobe)
		local group = math.min(3, (k + 1) // 2)
		frame.shot = cut("eveil-strike" .. group, dir, a, d, group)
	elseif tick < data.FinalTick then
		style(ctx, frame, a, d, tick, dir, template, color)
	elseif tick < data.FinalTick + 14 then
		-- 7. Impact: wide frame, shockwave in the colour of the style.
		table.insert(frame.fx, { key = "eveil-impact", kind = "shockwave", pos = v(cx, 0, 0), color = color })
		frame.impact = { key = "eveil-impact", color = color }
		frame.shot = frameOn("eveil-impact", dir, { a, d }, { yaw = 14, pitch = 22, fill = 0.55, fov = 46, focus = P(D, "UpperTorso") })
	else
		-- 8. Aftermath: the fighter lands in a kiai, the target flies away (or falls).
		a.y, a.facing, a.pose = 0, dir, "StandTall"
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
		frame.shot = frameOn("porte-setup", dir, { a, d }, { yaw = lerp(-26, 40, progress(tick, data.Hits[1], data.PromptTicks[1] - 14)),
			pitch = 4, fill = 0.92, fov = 38, focus = P(D, "UpperTorso") })
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
		frame.shot = frameOn("porte-shatter", dir, { a, d, gateTop }, { yaw = 60, pitch = 6, fill = 0.8, fov = 54, focus = P(D, "UpperTorso") })
	else
		-- 8. The world comes back.
		a.y, a.facing, a.pose = 0, dir, "StandTall"
		local title = kitOf(ctx) and kitOf(ctx).GateTitle or { text = "開天", sub = "PORTE DES CIEUX" }
		frame.title = { text = title.text, color = RED, sub = title.sub }
		frame.shot = frameOn("porte-after", dir, { a }, { yaw = -44, pitch = -6, fill = 0.75, fov = 40, focus = P(A, "UpperTorso") })
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
-- Out of the frame (AKEMI between two strikes): far above the stage.
local function vanish(a)
	a.y, a.z, a.lookDir, a.pose, a.ghost = 120, nil, nil, "StandTall", false
end

local function title(ctx, frame, color, sub)
	local cin = ctx.cin
	frame.title = { text = ctx.moveData.Moves[cin.move].name, color = color, sub = sub }
end

-- ---------------------------------------------------------------- TARO 火 · boxer

KIT.TARO = {}

-- RUSH DÉVASTATEUR: a fight at the ropes. Gloves pounded together, the charge that drives the
-- target into the corner (ropes of fire behind it), then the DEMPSEY ROLL: TARO sways left
-- and right and hooks from each side, filmed from ringside like a broadcast, the
-- photographers' flashes going off; body blows that fold it over, the hook cocked back, and
-- the knockout hook through the ropes; the glove raised under the flashes.
function KIT.TARO.Rush(ctx, frame, a, d, tick, dir)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local color = ctx.characters[A].Energy
	local cx = center(ctx, d)
	local H = data.Hits
	frame.grade.fire, frame.handheld = true, 0.18
	local k = hitsBefore(H, tick)
	local beat = if k > 0 then tick - H[k] else 0
	local corner = cx + dir * math.min(4, math.max(0, roomAhead(ctx, cx, dir) - 1.6))
	local function flashes(key)
		-- The photographers at ringside.
		for i = 1, 2 do
			local seed = (#key * 7 + i * 13) % 11
			spark(frame, key .. "-" .. i, v(corner + (seed - 5) * 1.3, 3 + (seed % 4) * 0.8, -7 - (seed % 3)), "FFFFFF", 0.35)
		end
	end
	if tick >= 12 and tick < data.FinalTick + 6 then
		table.insert(frame.fx, { key = "taro-ropes", kind = "ropes", from = v(corner + dir * 1.3, 0, 2.4),
			to = v(corner + dir * 1.3, 0, -3.2), color = color, life = (data.FinalTick + 6 - 12) / 60 })
	end
	if tick < 12 then
		a.x, a.facing, a.pose = cx - dir * 5, dir, "GloveTap"
		if tick >= 4 then spark(frame, "taro-tap", v(a.x + dir * 0.6, 3.6, 0.6), color, 1.6) end
		frame.shot = frameOn("taro-rush-gloves", dir, { a }, { yaw = 42, pitch = -12, fill = 1.0, fov = 34, band = "bust",
			focus = P(A, "Head") })
	elseif tick < H[1] then
		-- The charge drives the target back into the corner.
		local p = smooth(progress(tick, 12, H[1]))
		d.x = lerp(cx, corner, p)
		a.x, a.facing = d.x - dir * 2.2, dir
		attack(a, moves, role(ctx, "Rising"), true)
		frame.speedLines = color
		frame.shot = frameOn("taro-rush-drive", dir, { a, d }, { yaw = 6, pitch = -4, fill = 0.7, fov = 44, focus = P(D, "UpperTorso") })
	elseif tick < data.FinalTick then
		d.x, d.state = corner, "Hitstun"
		if k <= 8 then
			-- The DEMPSEY ROLL: swaying in a figure eight, a hook from each side.
			local sway = math.sin((tick - H[1]) / 7.5 * math.pi)
			a.x, a.z = corner - dir * 2.2, sway * 0.9
			a.facing = dir
			a.lookDir = v(dir * 0.94, 0, -sway * 0.34)
			attack(a, moves, role(ctx, if k % 2 == 1 then "Cross" else "Elbow"), beat < 4)
			d.hitstop = if beat < 4 then 1 else 0
			if beat < 2 and k % 2 == 0 then frame.impact = { key = "taro-hook" .. k, color = color } end
			spark(frame, "taro-hook" .. k, v(corner - dir * 0.5, 3.8 + (k % 2) * 0.3, 0.6), color, 1.4)
			flashes("taro-flash" .. k)
			if k == 4 or k == 5 then
				frame.shot = frameOn("taro-rush-sway", dir, { a, d }, { yaw = 40 - sway * 12, pitch = -6, fill = 0.9, fov = 38, band = "bust",
					focus = P(A, "Head") })
			else
				frame.shot = frameOn("taro-rush-ringside", dir, { a, d }, { yaw = 16, pitch = -4, fill = 0.72, fov = 40,
					focus = P(D, "UpperTorso") })
			end
		elseif tick < H[#H] + 6 then
			-- Body blows fold it over the ropes.
			a.x, a.z, a.lookDir, a.facing = corner - dir * 2, nil, nil, dir
			attack(a, moves, role(ctx, "BodyBlow"), beat < 4)
			d.pose = if k >= 10 then "Kneel" else nil
			d.hitstop = if beat < 4 then 1 else 0
			if beat < 2 then frame.impact = { key = "taro-body" .. k, color = color } end
			spark(frame, "taro-body" .. k, v(corner - dir * 0.4, 2.8, 0.6), color, 1.6)
			flashes("taro-bodyflash" .. k)
			frame.shot = frameOn("taro-rush-body", dir, { a, d }, { yaw = -40, pitch = -10, fill = 0.9, fov = 38, band = "waist",
				focus = P(D, "UpperTorso") })
		else
			-- The hook cocked back, fire gathering in the glove.
			local p = progress(tick, H[#H] + 6, data.FinalTick)
			a.x, a.facing = corner - dir * 2.4, dir
			attack(a, moves, role(ctx, "Smash"), false)
			d.pose = "Kneel"
			frame.aura = A
			spark(frame, "taro-cock" .. tick // 4, v(a.x - dir * 0.7, 3.4, 0.6), color, 0.8 + p * 1.4)
			frame.shot = frameOn("taro-rush-cock", dir, { a }, { yaw = -50, pitch = -14, fill = lerp(0.8, 1.04, p), fov = 36, band = "bust",
				focus = P(A, "Head") })
		end
	elseif tick < data.FinalTick + 14 then
		-- The knockout hook through the ropes.
		a.x, a.facing = corner - dir * 2.4, dir
		attack(a, moves, role(ctx, "Smash"), true)
		impact(frame, "taro-knockout", v(corner, 3.6, 0.6), color, 3.2)
		for i = 1, 3 do ring(frame, "taro-blast" .. i, corner + dir * i * 1.2, 1 + i * 0.6, 3.4, color) end
		flashes("taro-koflash")
		frame.shot = frameOn("taro-rush-knockout", dir, { a, d }, { yaw = -58, pitch = 2, fill = 0.66, fov = 46, focus = P(D, "UpperTorso") })
	else
		a.x, a.facing, a.pose = corner - dir * 2.4, dir, "Victory"
		if tick % 4 == 0 then flashes("taro-cheer" .. tick) end
		frame.shot = frameOn("taro-rush-champion", dir, { a }, { yaw = 26, pitch = -16, fill = 0.82, fov = 40, focus = P(A, "Head") })
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
		if ((math.min(k, #data.Hits - 1) - 1) // 2) % 2 == 0 then -- (the last blow keeps the shot before)
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
		frame.shot = frameOn("taro-tempete-liver", dir, { a, d }, { yaw = 68, pitch = -6, fill = 0.78, fov = 38, focus = P(D, "UpperTorso") })
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

KIT.ZEPHYR = {}

-- VENT TRANCHEUR: he never closes in until the end. Far from the target he gathers the wind,
-- then kicks the air: every kick sends a crescent blade of wind across the deck (filmed over
-- his shoulder, then from the target's side with the blade coming at us); the blades cross
-- into a vortex that lifts the target; he crouches, dashes and passes through it in one
-- flying kick that splits the air; he lands on the far side with his back to it.
function KIT.ZEPHYR.Rush(ctx, frame, a, d, tick, dir)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local color = ctx.characters[A].Energy
	local cx = center(ctx, d)
	local H = data.Hits
	frame.grade.sky = true
	if tick < data.FinalTick then d.x, d.state = cx, "Hitstun" end
	local k = hitsBefore(H, tick)
	local beat = if k > 0 then tick - H[k] else 0
	local home = cx - dir * 8
	local KICKS = { "Kick", "SpinKick", "AirKick", "Kick", "AirKick2", "SpinKick", "AirKick", "Kick" }
	if tick < H[1] - 4 then
		a.x, a.facing, a.pose = home, dir, "WindGather"
		table.insert(frame.fx, { key = "vent-gather", kind = "dragonHelix", pos = v(home, 0, 0), color = color })
		frame.shot = frameOn("zephyr-vent-gather", dir, { a }, { yaw = 30, pitch = -10, fill = 0.85, fov = 42, focus = P(A, "UpperTorso") })
	elseif k <= 8 then
		-- A kick in the air, a blade of wind across the deck.
		local airborne = KICKS[math.max(1, k)]:find("Air") ~= nil
		a.x, a.facing, a.y = home, dir, if airborne then 1.6 * math.sin(math.min(1, beat / 8) * math.pi) else 0
		attack(a, moves, role(ctx, KICKS[math.max(1, k)]), beat < 5 or k == 0)
		if k >= 1 then
			local h = 2.4 + (k % 3) * 0.9
			table.insert(frame.fx, { key = "vent-blade" .. k, kind = "windBlade", from = v(home + dir * 1.2, h, 0.4),
				to = v(cx + dir * 1.5, h, 0.4), color = color, tilt = (k % 3 - 1) * 0.6, scale = 1 })
			d.y = lerp(0, 1.4, progress(tick, H[1], H[8]))
			d.hitstop = if beat < 4 then 1 else 0
			spark(frame, "vent-cut" .. k, v(cx, h + d.y, 0.6), color, 1)
		end
		if k == 3 or k == 4 then
			frame.shot = frameOn("zephyr-vent-incoming", dir, { d }, { yaw = 104, pitch = 2, fill = 0.7, fov = 40, focus = P(D, "UpperTorso") })
		else
			frame.shot = frameOn("zephyr-vent-volley", dir, { a, d }, { yaw = -50, pitch = 4, fill = 0.66, fov = 44, focus = P(A, "UpperTorso") })
		end
	elseif tick < H[#H] + 6 then
		-- The blades cross into a vortex that lifts the target.
		a.x, a.facing, a.y = home, dir, 0
		attack(a, moves, role(ctx, "DragonTornado"), beat < 6)
		d.y, d.pose = lerp(1.4, 4.5, progress(tick, H[9], H[#H] + 6)), "Launched"
		d.hitstop = if beat < 4 then 1 else 0
		for i = 0, 1 do
			table.insert(frame.fx, { key = "vent-cross" .. k .. i, kind = "windBlade", from = v(home + dir * 1.2, 1 + i * 5, 0.4),
				to = v(cx + dir * 1.5, 6 - i * 5 + d.y * 0.4, 0.4), color = color, tilt = if i == 0 then 0.8 else -0.8, scale = 1.2 })
		end
		if tick % 4 == 0 then table.insert(frame.fx, { key = "vent-vortex" .. tick, kind = "tornadoRing", pos = v(cx, d.y + 1, 0), color = color }) end
		frame.shot = frameOn("zephyr-vent-vortex", dir, { d, { point = true, x = cx, y = 0.5, z = 0 } }, { yaw = 20, pitch = -20, fill = 0.7,
			fov = 50, focus = P(D, "UpperTorso") })
	elseif tick < data.FinalTick then
		-- He crouches and dashes in.
		local p = progress(tick, H[#H] + 6, data.FinalTick)
		d.y, d.pose = 4.5, "Launched"
		a.x, a.facing = lerp(home, cx - dir * 3.4, p * p), dir
		a.pose = if p < 0.4 then "Crouch" else "Dash"
		a.ghost = p >= 0.4
		frame.speedLines = color
		frame.shot = frameOn("zephyr-vent-dash", dir, { a, d }, { yaw = 6, pitch = -6, fill = 0.6, fov = 50, focus = P(A, "UpperTorso") })
	elseif tick < data.FinalTick + 14 then
		-- Through it in one flying kick: the air splits behind him.
		local p = progress(tick, data.FinalTick, data.FinalTick + 5)
		a.x, a.facing, a.y = lerp(cx - dir * 3.4, cx + dir * 4, p), dir, 3.6
		attack(a, moves, role(ctx, "AirKick"), true)
		a.ghost = true
		d.y = math.max(d.y, 4.5)
		table.insert(frame.fx, { key = "vent-split", kind = "windBlade", from = v(cx - dir * 5, 6.4, 0.4), to = v(cx + dir * 6, 6.4, 0.4),
			color = color, tilt = 0, scale = 2.2 })
		impact(frame, "vent-pass", v(cx, 6.4, 0.6), color, 3)
		frame.shot = frameOn("zephyr-vent-pass", dir, { a, d }, { yaw = 4, pitch = -8, fill = 0.55, fov = 50, focus = P(D, "UpperTorso") })
	else
		a.x, a.y, a.facing, a.pose = cx + dir * 4.4, 0, -dir, "StandTall"
		a.lookDir = v(dir, 0, -0.4)
		frame.shot = frameOn("zephyr-vent-drift", dir, { a, d }, { yaw = lerp(-54, -6, progress(tick, data.FinalTick + 14, data.Length)),
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
		frame.shot = frameOn("zephyr-dragon-climb", dir, { a, d }, { yaw = lerp(50, -10, progress(tick, data.Hits[1], last + 4)),
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
		frame.shot = frameOn("zephyr-cyclone-gust", dir, { a, d }, { yaw = 76, pitch = 2, fill = 0.78, fov = 46, focus = P(D, "UpperTorso") })
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

-- OMBRES MULTIPLES: she steps aside into the dark; then strikes from a new place of a circle
-- around the target at every blow and leaves her shadow standing there; seen from above, the
-- circle of shadows closes on it; she stands back in front, sheathes slowly in black and
-- white, and every shadow strikes at once; she walks away.
local AKEMI_RING = { 0.1, 0.9, 0.3, 0.7, 0.5, 0.2, 0.8, 0.4 }

function KIT.AKEMI.Rush(ctx, frame, a, d, tick, dir)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local color = ctx.characters[A].Energy
	local cx = center(ctx, d)
	local H = data.Hits
	frame.grade.shadow = true
	if tick < data.FinalTick then d.x, d.state = cx, "Hitstun" end
	local k = hitsBefore(H, tick)
	local beat = if k > 0 then tick - H[k] else 0
	local function spot(i)
		local angle = AKEMI_RING[i] * math.pi
		return cx - dir * math.cos(angle) * 3.8, -math.abs(math.sin(angle)) * 3.8
	end
	if tick < 10 then
		a.x, a.facing, a.pose = cx - dir * 4, dir, "Evade"
		a.ghost = true
		frame.shot = frameOn("akemi-ombres-fade", dir, { a, d }, { yaw = 0, pitch = 0, fill = 0.7, fov = 36, focus = P(A, "UpperTorso") })
	elseif tick < H[1] then
		a.x, a.facing, a.pose = cx - dir * 4, dir, "Sheathe"
		frame.shot = frameOn("akemi-ombres-hilt", dir, { a }, { yaw = 40, pitch = -4, fill = 0.95, fov = 32, band = "bust", focus = P(A, "Head") })
	elseif k <= #AKEMI_RING then
		-- A strike from the next place of the circle; her shadow stays there.
		around(a, cx, dir, AKEMI_RING[k] * math.pi, 3.8, 0)
		attack(a, moves, role(ctx, AKEMI_STRIKES[(k - 1) % #AKEMI_STRIKES + 1]), beat < 5)
		a.ghost = beat < 2
		d.hitstop = if beat < 4 then 1 else 0
		if beat >= 3 then
			table.insert(frame.fx, { key = "ombres-shadow" .. k, kind = "afterimage", slot = A, color = color,
				life = (data.FinalTick + 4 - tick) / 60 })
		end
		spark(frame, "ombres-hit" .. k, v(cx, 3.4, 0.6), color, 0.9)
		if k >= 3 and k <= 6 then
			frame.shot = frameOn("akemi-ombres-circle", dir, { d, { point = true, x = cx - 4.4, y = 0.5, z = -3.8 },
				{ point = true, x = cx + 4.4, y = 0.5, z = -3.8 } }, { yaw = lerp(-30, 30, progress(tick, H[1], H[8])), pitch = 62, fill = 0.8,
				fov = 46, focus = P(D, "UpperTorso") })
		else
			frame.shot = frameOn("akemi-ombres-glimpse", dir, { a, d }, { yaw = 28, pitch = 8, fill = 0.8, fov = 38, focus = P(D, "UpperTorso") })
		end
	elseif tick < data.FinalTick then
		-- Back in front of it, she sheathes slowly; the world in black and white.
		a.x, a.facing, a.pose = cx - dir * 3.4, dir, "Sheathe"
		frame.grade.mono = true
		frame.shot = frameOn("akemi-ombres-sheathe", dir, { a, d }, { yaw = -14, pitch = 4, fill = lerp(0.7, 0.86, progress(tick, H[9],
			data.FinalTick)), fov = 36, focus = P(A, "Head") })
	elseif tick < data.FinalTick + 16 then
		-- Every shadow strikes at once.
		a.x, a.facing, a.pose = cx - dir * 3.4, dir, "Sheathe"
		impact(frame, "ombres-final", v(cx, 3.6, 0.6), color, 2.8)
		for i = 1, #AKEMI_RING do
			local x, z = spot(i)
			table.insert(frame.fx, { key = "ombres-strike" .. i, kind = "lightning", from = v(x, 3.4 + (i % 3) * 0.6, z),
				to = v(cx, 3.4, 0.2), color = color })
		end
		frame.shot = frameOn("akemi-ombres-burst", dir, { d, { point = true, x = cx - 4.4, y = 0.5, z = -3.8 },
			{ point = true, x = cx + 4.4, y = 0.5, z = -3.8 } }, { yaw = 8, pitch = 54, fill = 0.7, fov = 46, focus = P(D, "UpperTorso") })
	else
		a.x, a.y, a.facing, a.state, a.vx = lerp(cx - dir * 3.4, cx - dir * 6.4, progress(tick, data.FinalTick + 16, data.Length)), 0, -dir,
			"Walking", -dir * 3
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
		local views = { { yaw = 34, pitch = 6 }, { yaw = -24, pitch = 30 }, { yaw = 55, pitch = -6 }, { yaw = -64, pitch = 10 } }
		local g = ((math.min(k, #data.Hits - 1) - 1) // 2) % #views + 1 -- (the last blow keeps the shot before)
		local view = views[g]
		frame.shot = frameOn("akemi-temps-tableau" .. g, dir, { a, d }, { yaw = view.yaw, pitch = view.pitch,
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
		if (step // 2) % 2 == 0 then
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

-- ---------------------------------------------------------------- RYUKEN 拳 · force

KIT.RYUKEN = {}

-- FUREUR DU POING: he never lets go. The roar, CHARGE FRONTALE, then the target held up by the
-- collar and pounded at point-blank range (the camera in its face: every blow comes at us),
-- slammed into the deck and caught on the bounce with an uppercut (seen from above), juggled
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
	if tick < 12 then
		a.x, a.facing, a.pose = cx - dir * 6, dir, "Roar"
		frame.aura = A
		if tick % 4 == 0 then ring(frame, "fureur-roar" .. tick, a.x, 1.2 + tick * 0.2, 0.15, color) end
		frame.shot = frameOn("ryuken-fureur-roar", dir, { a }, { yaw = 30, pitch = -18, fill = lerp(0.9, 1.05, tick / 12), fov = 40,
			band = "bust", focus = P(A, "Head") })
	elseif tick < H[1] then
		-- CHARGE FRONTALE, shoulder first; the camera waits in front of him.
		a.x, a.facing = lerp(cx - dir * 6, cx - dir * 1.9, progress(tick, 12, H[1]) ^ 2), dir
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
		-- Caught on the bounce: the uppercut.
		local p = progress(tick, H[7], H[8])
		a.x, a.facing, a.y = cx - dir * 1.7, dir, math.sin(p * math.pi) * 1.2
		attack(a, moves, role(ctx, "Uppercut"), true)
		d.y, d.pose = lerp(0.4, 4.2, smooth(p)), "Launched"
		d.hitstop = if beat < 4 then 1 else 0
		if beat < 2 then frame.impact = { key = "fureur-bounce", color = color } end
		spark(frame, "fureur-bounce", v(cx - dir * 0.4, 2.6, 0.6), color, 2)
		-- (the slam's shot holds while it bounces: seen from above, it comes up at us)
		frame.shot = frameOn("ryuken-fureur-slam", dir, { a, d }, { yaw = 8, pitch = 62, fill = 0.66, fov = 46, focus = P(D, "UpperTorso") })
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
		if ((math.min(k, #data.Hits - 1) - 1) // 2) % 2 == 0 then -- (the last blow keeps the shot before)
			frame.shot = frameOn("ryuken-effondrement-body", dir, { a, d }, { yaw = 65, pitch = -2, fill = 0.98, fov = 36, band = "waist",
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
		frame.shot = frameOn("ryuken-round-guard", dir, { a, d }, { yaw = 48, pitch = 2, fill = 0.9, fov = 36, band = "bust",
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
		frame.shot = frameOn("ryuken-round-cock", dir, { a, d }, { yaw = 61, pitch = -10, fill = lerp(0.9, 1.12, progress(tick,
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
	if tick < 12 then
		a.x, a.facing, a.pose = cx - dir * 7, dir, "Iai"
		frame.shot = frameOn("shin-danse-iai", dir, { a }, { yaw = 6, pitch = -2, fill = 0.9, fov = 26, band = "bust", lift = IAI_DROP, focus = P(A, "Head") })
	elseif tick < H[1] then
		-- PAS DU VENT into the crossing behind the target.
		local p = smooth(progress(tick, 12, H[1]))
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
		frame.shot = frameOn("shin-tempete-rise", dir, { a }, { yaw = lerp(-55, 5, p), pitch = lerp(-12, 18, p), fill = 0.8, fov = 34,
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
		if k == 3 or k == 4 then
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
		frame.shot = frameOn("shin-tempete-still", dir, { a }, { yaw = lerp(45, 25, progress(tick, data.FinalTick + 16, data.Length)), pitch = -2,
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
		frame.shot = frameOn("shin-zero-cuts", dir, { a, d }, { yaw = 53, pitch = 4, fill = 0.82, fov = 32, focus = P(D, "UpperTorso") })
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
			frame.shot = frameOn("daicha-domaine-crown", dir, { a, d }, { yaw = -3, pitch = 12, fill = 0.68, fov = 44, roll = -8,
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
		if k == 3 or k == 4 then
			frame.shot = frameOn("daicha-riviere-under", dir, { a, d }, { yaw = 6, pitch = -22, fill = 0.7, fov = 46, roll = 180,
				focus = P(D, "UpperTorso") })
		else
			frame.shot = frameOn("daicha-riviere-strike", dir, { a, d }, { yaw = if mirror then 54 else -14, pitch = 6, fill = 0.74, fov = 40,
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
		local view = (step // 2) % 2 == 1 -- (the camera changes side every two blinks)
		frame.shot = frameOn(if view then "daicha-eclipse-mirror-r" else "daicha-eclipse-mirror-l", dir, { a, d },
			{ yaw = if view then 64 else -40, pitch = 4, fill = 0.72, fov = 40, roll = if view then -14 else 14, focus = P(D, "UpperTorso") })
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
		frame.shot = frameOn("daicha-eclipse-flash", dir, { a, d, { point = true, x = cx, y = 12, z = -6 } }, { yaw = 46, pitch = -10, fill = 0.6,
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
		if k == 2 or k == 3 then
			frame.shot = frameOn("hibecares-colosse-wave", dir, { a, d }, { yaw = 10, pitch = 48, fill = 0.66, fov = 46, focus = P(D, "UpperTorso") })
		else
			frame.shot = frameOn("hibecares-colosse-march", dir, { a, d }, { yaw = 69, pitch = -14, fill = 0.8, fov = 44, focus = P(A, "UpperTorso") })
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
		-- The punishment, one continuous swing: slammed down beside him, lifted overhead on an
		-- arc, and brought down on the other side, faster and faster, on every blow.
		local k = math.max(1, hitsBefore(data.Hits, tick))
		local beat = tick - data.Hits[k]
		local span = if data.Hits[k + 1] then data.Hits[k + 1] - data.Hits[k] else 8
		local u = beat / span
		local side = if k % 2 == 1 then 1 else -1
		a.x, a.facing = cx - dir * 0.6, dir
		local floorX, overX, nextX = a.x + side * dir * 2.6, a.x + dir * 0.4, a.x - side * dir * 2.6
		if u < 0.25 or not data.Hits[k + 1] then
			d.x, d.y, d.pose = floorX, 0, "DownFace"
			attack(a, moves, role(ctx, "Hammer"), true)
			debris(frame, "chatiment-slam" .. k, v(d.x, 0.3, 0.4), color, 0.9)
			table.insert(frame.fx, { key = "chatiment-dust" .. k, kind = "dust", pos = v(d.x, 0, 0), direction = side * dir })
			if beat < 2 then
				frame.impact = { key = "chatiment-slam" .. k, color = color }
				frame.quake = 0.9
			end
		elseif u < 0.75 then
			local q = easeOutArc((u - 0.25) / 0.5)
			d.x, d.y, d.pose = lerp(floorX, overX, q), 6.4 * math.sin(q * math.pi / 2), "Launched"
			attack(a, moves, role(ctx, "Hammer"), false)
		else
			local q = ((u - 0.75) / 0.25) ^ 2
			d.x, d.y, d.pose = lerp(overX, nextX, q), 6.4 * math.cos(q * math.pi / 2), "Launched"
			attack(a, moves, role(ctx, "Hammer"), true)
		end
		frame.shot = frameOn("hibecares-chatiment-punish", dir, { a, { point = true, x = a.x - dir * 3.2, y = 0.4, z = 0 },
			{ point = true, x = a.x + dir * 3.2, y = 0.4, z = 0 }, { point = true, x = overX, y = 8.4, z = 0 } },
			{ yaw = 16, pitch = -6, fill = 0.82, fov = 48, focus = P(A, "UpperTorso") })
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
		frame.shot = frameOn("hibecares-ruines-fist", dir, { a, d }, { yaw = 20, pitch = -30, fill = lerp(0.82, 1.0, progress(tick,
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
-- ===================================================================== COUP FATAL

--[[
	The last-breath blow (key C). Each kit has its own scene, and when the blow kills it IS the
	K.O. screen (no K.O. scene after it). One tight prompt (the C key) on the climax; the blow
	lands at FinalTick; the title comes FATAL_TITLE ticks later. Inspirations: Samurai
	Shodown's issen (SHIN), Street Fighter's raging demon (KAI), Mortal Kombat's fatal blows
	(slow, heavy, final), JoJo's stopped time (AKEMI).
	All in one table (the module is close to Luau's limit of local names).
]]
local FATAL = {}
local FATAL_TITLE = 40

-- A staged x kept inside the arena (scenes stand far apart).
function FATAL.inside(ctx, x)
	return math.clamp(x, ctx.config.ArenaMinX + 1, ctx.config.ArenaMaxX - 1)
end

-- The target after the blow: it falls (finish: it stays down) or ends on one knee.
function FATAL.fall(cin, d, tick, F, fromY)
	local p = progress(tick, F, F + 20)
	if p < 1 then
		d.y, d.pose = lerp(fromY or 0, 0, p * p), "Launched"
	elseif cin.finish then
		d.y, d.pose = 0, "DownFace"
	else
		d.y, d.pose = 0, "Kneel"
	end
end

-- The closing title: K.O. when the blow killed, the blow's name otherwise.
function FATAL.title(ctx, frame, tick, F, color)
	if tick < F + FATAL_TITLE then return end
	local name = ctx.moveData.Moves[ctx.cin.move].name
	if ctx.cin.finish then
		frame.title = { text = "K.O.", color = color, sub = name }
	else
		frame.title = { text = name, color = color, sub = "COUP FATAL" }
	end
end

-- KAI 滅 CIEL ÉTEINT: he walks on, glides into the target and the world goes black; only the
-- flashes of the blows are seen. The light comes back on his back, a kanji burning on it.
function FATAL.KAI(ctx, frame, a, d, tick, dir)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local color = ctx.characters[A].Energy
	local F = data.FinalTick
	local cx = center(ctx, d)
	frame.grade.void = tick < F
	if tick < F then d.x, d.state = cx, "Hitstun" end
	if tick < 36 then
		local p = progress(tick, 0, 36)
		a.x, a.facing, a.state, a.vx = FATAL.inside(ctx, lerp(cx - dir * 9, cx - dir * 5, p)), dir, "Walking", dir * 2
		table.insert(frame.fx, { key = "ciel-seal", kind = "kanjiSeal", pos = v(cx - dir * 7, 0.06, 0), color = color, text = "滅", keep = true })
		frame.shot = frameOn("kai-ciel-walk", dir, { a, d }, { yaw = 10, pitch = -12, fill = 0.7, fov = 40, focus = P(A, "UpperTorso") })
	elseif tick < 64 then
		a.x, a.facing, a.pose = cx - dir * 5, dir, "StandTall"
		frame.grade.crimson = true
		frame.shot = frameOn("kai-ciel-eyes", dir, { a }, { yaw = 24, pitch = -4, fill = 0.85, fov = 26, band = "bust", focus = P(A, "Head") })
	elseif tick < 84 then
		a.x, a.facing, a.pose = lerp(cx - dir * 5, cx - dir * 2.8, smooth(progress(tick, 64, 80))), dir, "Dash"
		a.ghost = true
		frame.speedLines = color
		frame.shot = frameOn("kai-ciel-glide", dir, { a, d }, { yaw = 10, pitch = 2, fill = 0.8, fov = 36, focus = P(D, "UpperTorso") })
	elseif tick < F then
		-- The black: only the flashes of a storm of blows.
		a.x, a.facing = cx - dir * 2.8, dir
		local k = (tick - 84) // 9
		attack(a, moves, role(ctx, RUSH[k % #RUSH + 1]), true)
		frame.black = 1
		if (tick - 84) % 9 == 0 then
			impact(frame, "ciel-flash" .. k, v(cx, 3 + (k % 3) * 0.5, 0.6), if k % 2 == 0 then "FFFFFF" else color, 1.2)
		end
		if tick >= 110 then frame.kanjiBack = "滅" end
		frame.shot = frameOn("kai-ciel-dark", dir, { a, d }, { yaw = -30, pitch = 4, fill = 0.7, fov = 40, focus = P(D, "UpperTorso") })
	else
		-- The light comes back: KAI's back, the kanji, the target at his feet.
		a.x, a.facing, a.pose = cx - dir * 2.8, dir, "StandTall"
		a.lookDir = v(dir * 0.15, 0, -1)
		d.x = cx + dir * 0.6
		FATAL.fall(cin, d, tick, F, 0.6)
		frame.black = 1 - smooth(progress(tick, F, F + 30))
		frame.kanjiBack = "滅"
		if tick < F + 30 then
			frame.shot = frameOn("kai-ciel-back", dir, { a }, { yaw = 8, pitch = -6, fill = 0.8, fov = 34, focus = P(A, "UpperTorso") })
		else
			frame.shot = frameOn("kai-ciel-wide", dir, { a, d }, { yaw = -14, pitch = 4, fill = 0.5, fov = 38, focus = P(A, "UpperTorso") })
		end
		FATAL.title(ctx, frame, tick, F, RED)
	end
end

-- TARO 終 DERNIÈRE CLOCHE: the last round. The bell, the weave, the hooks, the fist cocked in
-- black and white, then the punch that ends it under the camera flashes.
function FATAL.TARO(ctx, frame, a, d, tick, dir)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local color = ctx.characters[A].Energy
	local F, Pr = data.FinalTick, data.PromptTicks[1]
	local cx = center(ctx, d)
	frame.grade.fire, frame.handheld = true, 0.2
	if tick < F then d.x, d.state = cx, "Hitstun" end
	if tick < 30 then
		a.x, a.facing, a.pose = cx - dir * 3.2, dir, "GloveTap"
		d.state = "Idle"
		frame.shot = frameOn("taro-cloche-bell", dir, { a, d }, { yaw = 0, pitch = -6, fill = 0.55, fov = 36, focus = P(A, "UpperTorso") })
	elseif tick < 70 then
		-- The weave: the body rolls in a figure eight, a hook at each end.
		local k = (tick - 30) // 10
		a.x, a.facing = cx - dir * (3 - 0.2 * math.sin((tick - 30) / 10 * math.pi)), dir
		if (tick - 30) % 10 < 6 then
			a.state, a.move, a.weave, a.vx = "Dashing", nil, true, dir * 2
		else
			attack(a, moves, role(ctx, if k % 2 == 0 then "Elbow" else "Cross"), true)
			spark(frame, "cloche-weave" .. k, v(cx, 3.6, 0.6), color, 0.8)
		end
		frame.shot = frameOn("taro-cloche-weave", dir, { a, d }, { yaw = 25, pitch = -4, fill = 0.85, fov = 36, focus = P(D, "UpperTorso") })
	elseif tick < 110 then
		local k = (tick - 70) // 6
		a.x, a.facing = cx - dir * 2.9, dir
		attack(a, moves, role(ctx, if k % 2 == 0 then "Cross" else "Elbow"), true)
		d.hitstop = if (tick - 70) % 6 < 2 then 1 else 0
		if (tick - 70) % 6 == 0 then spark(frame, "cloche-hook" .. k, v(cx, 3.4 + (k % 2) * 0.4, 0.6), color, 1) end
		frame.shot = frameOn("taro-cloche-hooks", dir, { a, d }, { yaw = lerp(-40, 40, progress(tick, 70, 110)), pitch = -2, fill = 0.9,
			fov = 34, focus = P(D, "UpperTorso") })
	elseif tick < F then
		a.x, a.facing = cx - dir * 3, dir
		attack(a, moves, role(ctx, "Finale"), false)
		frame.grade.mono = tick >= Pr - 4
		frame.shot = frameOn("taro-cloche-cock", dir, { a }, { yaw = -40, pitch = -10, fill = lerp(0.75, 0.9, progress(tick, 110, F)), fov = 32,
			band = "bust", focus = P(A, "Head") })
	elseif tick < F + 26 then
		local p = progress(tick, F, F + 26)
		a.x, a.facing = cx - dir * 3, dir
		attack(a, moves, role(ctx, "Finale"), true)
		d.x, d.y, d.pose = FATAL.inside(ctx, lerp(cx, cx + dir * 7, smooth(p))), 4 * math.sin(p * math.pi), "Launched"
		impact(frame, "cloche-ko", v(cx, 3.6, 0.6), color, 3)
		for i = 1, 6 do -- the photographers' flashes round the ring
			if (tick - F) == i * 3 then spark(frame, "cloche-flash" .. i, v(cx + dir * (i % 3 - 1) * 6, 4 + (i % 2) * 2, -8), "FFFFFF", 0.6) end
		end
		frame.shot = frameOn("taro-cloche-ko", dir, { a, d }, { yaw = 20, pitch = -4, fill = 0.6, fov = 40, focus = P(D, "UpperTorso") })
	else
		a.x, a.facing, a.pose = cx - dir * 3, dir, "Victory"
		d.x = FATAL.inside(ctx, cx + dir * 7)
		FATAL.fall(cin, d, tick, F + 26, 0)
		frame.shot = frameOn("taro-cloche-after", dir, { a, d }, { yaw = -24, pitch = -8, fill = 0.55, fov = 38, focus = P(A, "UpperTorso") })
		FATAL.title(ctx, frame, tick, F, color)
	end
end

-- ZEPHYR 嵐 CHUTE DE LA LUNE: kicked into the night sky, the target meets him in front of a
-- full moon; he comes down with it, heel first, into the deck.
function FATAL.ZEPHYR(ctx, frame, a, d, tick, dir)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local color = ctx.characters[A].Energy
	local F = data.FinalTick
	local cx = center(ctx, d)
	frame.grade.sky = true
	local moon = { point = true, x = cx, y = 26, z = -14 }
	if tick >= 30 then
		table.insert(frame.fx, { key = "lune-moon", kind = "crescent", pos = v(moon.x, moon.y, moon.z), color = "FFF3D6", keep = true })
	end
	if tick < 30 then
		a.x, a.facing = cx - dir * 2.8, dir
		attack(a, moves, role(ctx, "Uppercut"), tick >= 10)
		d.x, d.y, d.state = cx, lerp(0, 6, smooth(progress(tick, 12, 30))), "Hitstun"
		d.pose = if tick >= 12 then "Launched" else nil
		frame.shot = frameOn("zephyr-lune-launch", dir, { a, d }, { yaw = 30, pitch = -10, fill = 0.8, fov = 40, focus = P(D, "UpperTorso") })
	elseif tick < 70 then
		local p = smooth(progress(tick, 30, 70))
		d.x, d.y, d.pose, d.state = cx, lerp(6, 16, p), "Launched", "Hitstun"
		a.x, a.y, a.facing, a.pose = cx - dir * 1.6, lerp(0, 19, p), dir, "Dash"
		frame.speedLines = color
		frame.shot = frameOn("zephyr-lune-rise", dir, { a, d }, { yaw = -20, pitch = -24, fill = 0.7, fov = 44, focus = P(A, "UpperTorso") })
	elseif tick < 128 then
		-- Above it, in front of the moon: the wind gathers round his leg.
		d.x, d.y, d.pose, d.state = cx, 16, "Launched", "Hitstun"
		a.x, a.y, a.facing, a.pose = cx - dir * 0.8, 20, dir, "WindGather"
		local k = (tick - 70) // 12
		if (tick - 70) % 12 == 0 then
			table.insert(frame.fx, { key = "lune-wind" .. k, kind = "windBlade", from = v(a.x - dir * 2, 21 + (k % 2), 0.4),
				to = v(a.x + dir * 2, 23 - (k % 2), 0.4), color = color, tilt = k * 0.7, scale = 0.8 })
		end
		frame.shot = frameOn("zephyr-lune-moon", dir, { a, moon }, { yaw = 10, pitch = -20, fill = 0.6, fov = 40, focus = P(A, "UpperTorso") })
	elseif tick < F then
		d.x, d.y, d.pose, d.state = cx, 16, "Launched", "Hitstun"
		a.x, a.y, a.facing = cx - dir * 0.8, 20, dir
		attack(a, moves, role(ctx, "Hammer"), false)
		frame.shot = frameOn("zephyr-lune-axe", dir, { a }, { yaw = 25, pitch = -6, fill = 0.9, fov = 30, focus = P(A, "UpperTorso") })
	elseif tick < F + 22 then
		local p = progress(tick, F, F + 14)
		a.x, a.y, a.facing = cx - dir * 0.8, lerp(20, 3.5, p * p), dir
		attack(a, moves, role(ctx, "Hammer"), true)
		d.x, d.y, d.pose = cx + dir * 0.6, lerp(16, 0, p * p), "Launched"
		a.ghost = p < 1
		frame.speedLines = color
		if p >= 1 then
			impact(frame, "lune-crater", v(cx, 0.6, 0.6), color, 3)
			for i = 1, 3 do ring(frame, "lune-ring" .. i, cx, i * 1.6, 0.1, color) end
			table.insert(frame.fx, { key = "lune-dust", kind = "dust", pos = v(cx, 0, 0), direction = dir })
		end
		frame.shot = frameOn("zephyr-lune-fall", dir, { a, d }, { yaw = 20, pitch = 6, fill = 0.6, fov = 44, focus = P(D, "UpperTorso") })
	else
		a.x, a.y, a.facing, a.pose = cx - dir * 3, 0, dir, "StandTall"
		d.x = cx + dir * 0.6
		FATAL.fall(cin, d, tick, F + 14, 0)
		frame.shot = frameOn("zephyr-lune-after", dir, { a, d }, { yaw = -39, pitch = 4, fill = 0.6, fov = 38, focus = P(A, "UpperTorso") })
		FATAL.title(ctx, frame, tick, F, color)
	end
end

-- AKEMI 刻 L'INSTANT VOLÉ: she stops time. The world goes grey and still, she walks round the
-- frozen target cutting it from every side, sheathes her blade behind it... and time comes
-- back with every cut at once.
function FATAL.AKEMI(ctx, frame, a, d, tick, dir)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local color = ctx.characters[A].Energy
	local F = data.FinalTick
	local cx = center(ctx, d)
	local stopped = tick >= 30 and tick < F
	frame.grade.mono = stopped
	if tick < F then
		d.x, d.state, d.pose = cx, "Hitstun", if stopped then "Dash" else nil
		d.hitstop = if stopped then 1 else 0
	end
	if tick < 30 then
		a.x, a.facing, a.pose = cx - dir * 3.2, dir, "Sheathe"
		frame.shot = frameOn("akemi-instant-tick", dir, { a, d }, { yaw = 30, pitch = 0, fill = 0.7, fov = 32, focus = P(A, "Head") })
	elseif tick < 110 then
		-- Round the still body, a cut at every step (her afterimages stay: time is stopped).
		local p = progress(tick, 30, 110)
		local k = (tick - 30) // 10
		around(a, cx, dir, lerp(0.08, 0.92, p) * math.pi, 3, 0)
		if (tick - 30) % 10 < 5 then
			attack(a, moves, role(ctx, AKEMI_STRIKES[k % #AKEMI_STRIKES + 1]), true)
		else
			a.state, a.move, a.vx = "Walking", nil, 2
		end
		if (tick - 30) % 20 == 0 then
			table.insert(frame.fx, { key = "instant-copy" .. k, kind = "afterimage", slot = A, color = color, life = 2.2 })
		end
		frame.shot = frameOn("akemi-instant-orbit", dir, { a, d }, { yaw = lerp(-10, 50, p), pitch = 10, fill = 0.7, fov = 40,
			focus = P(D, "UpperTorso") })
	elseif tick < F then
		a.x, a.z, a.lookDir, a.facing, a.pose = cx + dir * 3.4, nil, nil, dir, "Sheathe"
		frame.shot = frameOn("akemi-instant-back", dir, { a, d }, { yaw = -50, pitch = 2, fill = 0.6, fov = 34, focus = P(A, "Head") })
	elseif tick < F + 24 then
		-- Time comes back: every cut at once.
		a.x, a.facing, a.pose = cx + dir * 3.4, dir, "Sheathe"
		if tick == F then
			for i = 1, 5 do
				local angle = i * 0.63
				slash(frame, "instant-cut" .. i, v(cx - math.cos(angle) * 3, 3.4 - math.sin(angle) * 2.4, 0.5),
					v(cx + math.cos(angle) * 3, 3.4 + math.sin(angle) * 2.4, 0.5), color)
			end
		end
		impact(frame, "instant-resume", v(cx, 3.4, 0.6), color, 2.6)
		d.x = cx
		FATAL.fall(cin, d, tick, F + 6, 0.4)
		frame.shot = frameOn("akemi-instant-resume", dir, { a, d }, { yaw = 15, pitch = 2, fill = 0.65, fov = 36, focus = P(D, "UpperTorso") })
	else
		local p = progress(tick, F + 24, data.Length)
		a.x, a.facing, a.state, a.vx = cx + dir * lerp(3.4, 7, p), dir, "Walking", dir * 2
		d.x = cx
		FATAL.fall(cin, d, tick, F + 6, 0.4)
		frame.shot = frameOn("akemi-instant-leave", dir, { a, d }, { yaw = 25, pitch = 2, fill = 0.55, fov = 34, focus = P(A, "UpperTorso") })
		FATAL.title(ctx, frame, tick, F, color)
	end
end

-- RYUKEN 砕 POING DU MONDE: the roar, the fist charging until it smokes, then one punch that
-- goes through the target, the deck and the arena wall.
function FATAL.RYUKEN(ctx, frame, a, d, tick, dir)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local color = ctx.characters[A].Energy
	local F, Pr = data.FinalTick, data.PromptTicks[1]
	local cx = center(ctx, d)
	local wall = FATAL.inside(ctx, cx + dir * math.min(12, roomAhead(ctx, cx, dir)))
	frame.grade.rage = true
	if tick < F then d.x, d.state = cx, "Hitstun" end
	if tick < 36 then
		a.x, a.facing, a.pose = cx - dir * 3.2, dir, "Roar"
		frame.quake = if tick < 4 then 0.4 else nil
		frame.shot = frameOn("ryuken-monde-roar", dir, { a }, { yaw = 20, pitch = -14, fill = 0.85, fov = 34, focus = P(A, "Head") })
	elseif tick < 90 then
		a.x, a.facing = cx - dir * 3.2, dir
		attack(a, moves, role(ctx, "Finale"), false)
		frame.aura = A
		if tick % 6 == 0 then table.insert(frame.fx, { key = "monde-heat" .. tick, kind = "smoke", pos = v(a.x - dir * 0.6, 3, 0.5) }) end
		frame.shot = frameOn("ryuken-monde-charge", dir, { a, d }, { yaw = -34, pitch = -8, fill = 0.8, fov = 38, focus = P(A, "UpperTorso") })
	elseif tick < F then
		a.x, a.facing = cx - dir * 3.2, dir
		attack(a, moves, role(ctx, "Finale"), false)
		frame.grade.mono = tick >= Pr - 4
		frame.shot = frameOn("ryuken-monde-fist", dir, { a }, { yaw = 40, pitch = -4, fill = lerp(0.72, 0.85, progress(tick, 90, F)), fov = 32,
			band = "bust", focus = P(A, "Head") })
	elseif tick < F + 26 then
		local p = smooth(progress(tick, F, F + 18))
		a.x, a.facing = cx - dir * 3.2, dir
		attack(a, moves, role(ctx, "Finale"), true)
		d.x, d.y, d.pose = lerp(cx, wall, p), 2 * math.sin(p * math.pi), "Launched"
		d.ghost = p < 1
		if tick == F then
			rageFist(frame, "monde-fist", v(a.x + dir * 1, 3.4, 0.4), v(wall + dir * 6, 3.4, 0.4), color, 2.4)
			crack(frame, "monde-crack", v(cx - dir * 1, 0.05, 0), v(wall, 0.05, 0), color)
		end
		impact(frame, "monde-blow", v(cx, 3.4, 0.6), color, 3)
		frame.quake = if tick < F + 6 then 1 else nil
		frame.shot = frameOn("ryuken-monde-blow", dir, { a, d }, { yaw = 10, pitch = 2, fill = 0.5, fov = 46, focus = P(D, "UpperTorso") })
	else
		a.x, a.facing = cx - dir * 3.2, dir
		attack(a, moves, role(ctx, "Finale"), true)
		if tick % 8 == 0 then table.insert(frame.fx, { key = "monde-steam" .. tick, kind = "smoke", pos = v(a.x + dir * 0.9, 3.2, 0.4) }) end
		d.x = wall
		FATAL.fall(cin, d, tick, F + 26, 0.5)
		frame.shot = frameOn("ryuken-monde-after", dir, { a, d }, { yaw = 10, pitch = 2, fill = 0.5, fov = 40, focus = P(A, "UpperTorso") })
		FATAL.title(ctx, frame, tick, F, color)
	end
end

-- SHIN 一閃 ISSEN (Wilhem's idea): an old samurai film. Black and white, the two of them far
-- apart, the eyes, the hand on the hilt... nothing moves. Then he is across the screen, one red
-- line through the frame, the blade back in its sheath, and only then does the target fall.
function FATAL.SHIN(ctx, frame, a, d, tick, dir)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local F = data.FinalTick
	local cx = center(ctx, d)
	local blood = "C8102E"
	local far, beyond = FATAL.inside(ctx, cx - dir * 12), FATAL.inside(ctx, cx + dir * 10)
	frame.grade.mono = true
	if tick < F + 56 then d.x, d.y, d.state = cx, 0, "Idle" end -- (still standing until the sheath clicks)
	if tick < 40 then
		a.x, a.facing, a.pose = far, dir, "StandTall"
		frame.shot = frameOn("shin-issen-duel", dir, { a, d }, { yaw = 0, pitch = 1, fill = 0.32, fov = 30, focus = P(A, "UpperTorso") })
	elseif tick < 66 then
		a.x, a.facing, a.pose = far, dir, "Iai"
		frame.shot = frameOn("shin-issen-eyes", dir, { a }, { yaw = 20, pitch = 0, fill = 0.8, fov = 24, band = "bust", lift = IAI_DROP,
			focus = P(A, "Head") })
	elseif tick < 88 then
		a.x, a.facing, a.pose = far, dir, "Iai"
		frame.shot = frameOn("shin-issen-foe", dir, { d }, { yaw = -24, pitch = 0, fill = 0.8, fov = 24, band = "bust", focus = P(D, "Head") })
	elseif tick < 128 then
		a.x, a.facing, a.pose = far, dir, "Iai"
		frame.shot = frameOn("shin-issen-hilt", dir, { a }, { yaw = 34, pitch = -6, fill = lerp(0.85, 1.05, progress(tick, 88, 128)), fov = 24,
			band = "bust", lift = IAI_DROP, focus = P(A, "Head") })
	elseif tick < F then
		-- The still before the cut (the C key comes here).
		a.x, a.facing, a.pose = far, dir, "Iai"
		frame.shot = frameOn("shin-issen-still", dir, { a, d }, { yaw = 0, pitch = 1, fill = 0.32, fov = 30, focus = P(A, "UpperTorso") })
	elseif tick < F + 24 then
		-- He is already across: one red line through the whole frame.
		a.x, a.facing = beyond, dir
		attack(a, moves, role(ctx, "Finale"), true)
		a.ghost = tick < F + 3
		d.hitstop = 1
		slash(frame, "issen-line", v(cx - dir * 40, 3.6, 0.4), v(cx + dir * 40, 3.6, 0.4), blood)
		impact(frame, "issen-flash", v(cx, 3.6, 0.6), "FFFFFF", 2)
		frame.shot = frameOn("shin-issen-cut", dir, { a, d }, { yaw = 0, pitch = 1, fill = 0.32, fov = 30, focus = P(D, "UpperTorso") })
	elseif tick < F + 56 then
		a.x, a.facing, a.pose = beyond, dir, if tick < F + 36 then "Iai" else "Sheathe"
		d.hitstop = 1
		frame.shot = frameOn("shin-issen-sheathe", dir, { a }, { yaw = -30, pitch = -4, fill = 0.9, fov = 26, band = "bust",
			focus = P(A, "Head") })
	else
		-- The click of the sheath: the target falls.
		a.x, a.facing, a.pose = beyond, dir, "StandTall"
		d.x = cx
		FATAL.fall(cin, d, tick, F + 56, 0)
		frame.shot = frameOn("shin-issen-fall", dir, { a, d }, { yaw = -30, pitch = 1, fill = 0.32, fov = 30, focus = P(D, "UpperTorso") })
		FATAL.title(ctx, frame, tick, F + 30, blood)
	end
end

-- DAICHA 虚 NÉANT: a black sun opens behind the target and pulls it in, the orbs spinning
-- round it; he closes his hand and the void collapses on it.
function FATAL.DAICHA(ctx, frame, a, d, tick, dir)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local color = ctx.characters[A].Energy
	local F = data.FinalTick
	local cx = center(ctx, d)
	local hole = { point = true, x = cx + dir * 3, y = 9, z = -10 }
	frame.grade.inverse = tick < F + 24
	-- (the black sun lasts until the void collapses: life in seconds of slowed-down play)
	eclipse(frame, "neant-sun", v(hole.x, hole.y, hole.z), color, 0.9, (F + 24) / 60 / (ctx.config.CinematicTimeScale or 1))
	if tick < 36 then
		a.x, a.facing, a.pose = cx - dir * 5, dir, "Levitate"
		d.x, d.state = cx, "Hitstun"
		frame.shot = frameOn("daicha-neant-summon", dir, { a, hole }, { yaw = -20, pitch = -10, fill = 0.7, fov = 40, focus = P(A, "UpperTorso") })
	elseif tick < 100 then
		local p = smooth(progress(tick, 36, 100))
		a.x, a.facing, a.pose = cx - dir * 5, dir, "Levitate"
		d.x, d.y, d.state, d.pose = lerp(cx, cx + dir * 1.5, p), lerp(0, 5, p), "Hitstun", "Launched"
		if tick == 40 then orbs(frame, "neant-crown", v(d.x, 5.5, 0), 2.4, 6, color, 3, 0.6, 0, 0.5) end
		if (tick - 36) % 8 == 0 then
			table.insert(frame.fx, { key = "neant-dart" .. tick, kind = "orbDart", from = v(a.x + dir, 4, 0.4), to = v(d.x, d.y + 3, 0.4),
				color = color })
		end
		frame.shot = frameOn("daicha-neant-pull", dir, { a, d }, { yaw = 30, pitch = 2, fill = 0.55, fov = 40, focus = P(D, "UpperTorso") })
	elseif tick < F then
		a.x, a.facing = cx - dir * 5, dir
		attack(a, moves, role(ctx, "Finale"), false)
		d.x, d.y, d.state, d.pose = cx + dir * 1.5, 5, "Hitstun", "Launched"
		frame.grade.void = true
		frame.shot = frameOn("daicha-neant-grip", dir, { a }, { yaw = 24, pitch = -4, fill = 0.75, fov = 30, band = "bust", focus = P(A, "Head") })
	elseif tick < F + 24 then
		-- The void closes on it.
		a.x, a.facing = cx - dir * 5, dir
		attack(a, moves, role(ctx, "Finale"), true)
		d.x, d.y, d.pose = cx + dir * 1.5, 5, "Launched"
		impact(frame, "neant-collapse", v(hole.x, hole.y, 0.6), "0B0712", 3)
		frame.shot = frameOn("daicha-neant-collapse", dir, { a, d }, { yaw = 0, pitch = 0, fill = 0.6, fov = 40, focus = P(D, "UpperTorso") })
	else
		a.x, a.facing, a.pose = cx - dir * 5, dir, "Levitate"
		d.x = cx + dir * 1.5
		FATAL.fall(cin, d, tick, F + 24, 5)
		frame.shot = frameOn("daicha-neant-after", dir, { a, d }, { yaw = -16, pitch = 4, fill = 0.55, fov = 38, focus = P(A, "UpperTorso") })
		FATAL.title(ctx, frame, tick, F, color)
	end
end

-- HIBECARES 墓 TOMBEAU DES ROIS: the ruins rise round the arena, three steps shake the deck
-- and cage the target in stone, both fists come down and the stones close over it: a tomb.
function FATAL.HIBECARES(ctx, frame, a, d, tick, dir)
	local cin, moves = ctx.cin, ctx.moveData.Moves
	local data = ctx.moveData.Cinematics[cin.move]
	local A, D = cin.attacker, cin.defender
	local color = ctx.characters[A].Energy
	local F = data.FinalTick
	local cx = center(ctx, d)
	frame.grade.ruin = true
	if tick < F then d.x, d.state = cx, "Hitstun" end
	if tick < 36 then
		a.x, a.facing, a.pose = cx - dir * 4.5, dir, "Colossus"
		if tick == 0 then rocks(frame, "tombeau-ruins", cx, 10, 10, color) end
		frame.quake = if tick < 6 then 0.4 else nil
		frame.shot = frameOn("hibecares-tombeau-rise", dir, { a }, { yaw = 24, pitch = -26, fill = 0.85, fov = 40, focus = P(A, "Head") })
	elseif tick < 96 then
		-- Three steps: each one shakes the deck and a line of stone runs to the target.
		local p = progress(tick, 36, 96)
		a.x, a.facing, a.pose = lerp(cx - dir * 4.5, cx - dir * 3.2, p), dir, "Colossus"
		for i, at in { 46, 62, 78 } do
			if tick == at then
				table.insert(frame.fx, { key = "tombeau-line" .. i, kind = "rockLine", from = v(a.x, 0, 0), to = v(cx, 0, 0), count = 4,
					color = color, life = 1.6 })
				frame.quake = 0.6
			end
		end
		if tick == 82 then rocks(frame, "tombeau-cage", cx, 1.8, 6, color) end
		frame.shot = frameOn("hibecares-tombeau-steps", dir, { a, d }, { yaw = -30, pitch = -8, fill = 0.75, fov = 40, focus = P(D, "UpperTorso") })
	elseif tick < F then
		a.x, a.facing = cx - dir * 3.2, dir
		attack(a, moves, role(ctx, "Finale"), false)
		frame.shot = frameOn("hibecares-tombeau-raise", dir, { a }, { yaw = 30, pitch = -30, fill = 0.8, fov = 36, focus = P(A, "Head") })
	elseif tick < F + 24 then
		a.x, a.facing = cx - dir * 3.2, dir
		attack(a, moves, role(ctx, "Finale"), true)
		if tick == F then
			debris(frame, "tombeau-debris", v(cx, 3, 0.4), color, 2.2)
			crack(frame, "tombeau-crack", v(cx - dir * 4, 0.05, 0), v(cx + dir * 4, 0.05, 0), color)
			rocks(frame, "tombeau-lid", cx, 2.6, 8, color)
		end
		impact(frame, "tombeau-smash", v(cx, 2.4, 0.6), color, 3)
		frame.quake = if tick < F + 8 then 1 else nil
		d.x = cx
		FATAL.fall(cin, d, tick, F, 0)
		frame.shot = frameOn("hibecares-tombeau-smash", dir, { a, d }, { yaw = 20, pitch = 6, fill = 0.6, fov = 42, focus = P(D, "UpperTorso") })
	else
		a.x, a.facing, a.pose = cx - dir * 3.2, dir, "Colossus"
		d.x = cx
		FATAL.fall(cin, d, tick, F, 0)
		if tick % 10 == 0 then table.insert(frame.fx, { key = "tombeau-dust" .. tick, kind = "dust", pos = v(cx, 0, 0), direction = -dir }) end
		frame.shot = frameOn("hibecares-tombeau-after", dir, { a, d }, { yaw = -20, pitch = 10, fill = 0.5, fov = 40, focus = P(A, "UpperTorso") })
		FATAL.title(ctx, frame, tick, F, color)
	end
end
Director.FATAL = FATAL

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
		frame.shot = frameOn("ko-zephyr-orbit", dir, { w }, { yaw = lerp(-20, 80, progress(t, 100, 150)), pitch = 8,
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
		frame.shot = frameOn("ko-shin-horizon", dir, { w, l }, { yaw = 24, pitch = 2, fill = 0.3, fov = 26 })
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
		frame.shot = frameOn("ko-shin-leave", dir, { w }, { yaw = -80, pitch = 0, fill = 0.72, fov = 30, focus = P(W, "UpperTorso") })
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

-- ===================================================================== THEMED KITS

--[[
	ASURA and the kits of Wilhem's third sheet are staged by one director written in the spirit
	of the hand-made ones: a theme gives each kit its own grade, its own effects, its own way of
	fighting in each ultimate (an archetype), its own camera angles and poses, and every shot
	its own name. Archetypes:
	  lunge    blows from changing sides, a blur between them (a spear, blood lances)
	  orbit    circles the target and strikes on the way (fans of ice, a predator's claws)
	  zone     stays far away, everything flies to the target (sound waves, drones, threads)
	  grapple  seizes the target and slams it from one side to the other (a wrestler, four arms)
	  gatling  a storm of fists pinning the target in place (ASURA's four arms)
	  juggle   lifts the target higher and higher and follows it up (gravity)
	  pull     drags the target in on every blow (chains, vines, light)
	  thrust   a spear's reach: straight thrusts from out of range, a step further in each time
	  freeze   the target held still (ice, a seal of light) while the attacker flows round it
	  stalk    out of the shadows: low in front, then behind, the target staggering
	  beat     to a rhythm: the target hops on every beat, the floor pulses
	  dance    a puppet jerked from side to side on threads pulled from afar
	  swing    swung round the attacker at the end of a chain (or an arm)
	  rain     from above: the attacker strikes down out of the air, the sky pours on the target
	  roots    lifted a little higher at every blow by what grows out of the floor
	  pillar   pillars from the sky on the target, called from afar
	  crossfire  shots from every side at once (drones, thorns, falling stars)
	No two themes stage the same ultimate the same way, and each theme's four ultimates differ
	(tests/CinematicDirector.test.luau).
	A theme: id (shot prefix), grade, kanji, pose / rest (signature poses), seed / step (its walk
	through the camera presets), rush / awaken / gate / fatal (archetypes), blows (roles cycled
	by the barrages), fx = { line, burst, ground } (its own effect kinds), quake (heavy steps).
	All in one table (the module is close to Luau's limit of local names).
]]
local GEN = { THEMES = {} }

-- Two-shot presets { yaw, pitch, fill, fov }: a theme starts at `seed` and walks by `step`.
GEN.ANGLES = {
	{ 40, 6, 0.74, 42 }, { -32, 10, 0.8, 40 }, { 12, 52, 0.62, 46 }, { 48, -14, 0.8, 46 }, { -40, 18, 0.62, 42 },
	{ 24, -24, 0.8, 44 }, { -18, -8, 0.84, 38 }, { 54, 22, 0.66, 44 }, { 6, 30, 0.7, 40 }, { -46, -4, 0.7, 46 },
	{ 30, 60, 0.56, 48 }, { -8, -26, 0.78, 50 },
}
-- Hero shots of one fighter { yaw, pitch, fill, fov, band }.
GEN.SOLO = {
	{ 24, -26, 0.85, 40, "full" }, { -20, -10, 0.95, 30, "bust" }, { 10, -34, 0.8, 44, "full" },
	{ -30, 4, 1.0, 28, "bust" }, { 28, -6, 0.9, 32, "bust" }, { -12, -20, 0.85, 40, "full" },
}

function GEN.name(T, ult, name)
	return T.id .. "-" .. ult .. "-" .. name
end

-- Every generated shot goes through here: a kit can turn one of its shots (`turn`, keyed by
-- the shot's name without the kit's id, e.g. ["gate-advance"] = 30) where its own poses
-- would hide one hand behind the other from the preset angle.
function GEN.frame(T, name, dir, subjects, o)
	local turn = T.turn and T.turn[name:sub(#T.id + 2)]
	if turn then o.yaw = (o.yaw or 0) + turn end
	return frameOn(name, dir, subjects, o)
end

-- A two-shot of the attacker and the target, preset `i` of the theme's walk. The camera
-- looks at the fighter on its side of the pair (never through the other one).
-- Is the line from the camera to `view`'s chest clear of `other`'s body?
function GEN.seen(shot, view, other)
	local cam = shot.from.position
	if not cam then return true end
	local fx, fy, fz = view.x, (view.y or 0) + 4, view.z or 0
	local ox, oz = other.x, other.z or 0
	for k = 1, 9 do
		local t = k / 10
		local px, py, pz = cam.x + (fx - cam.x) * t, cam.y + (fy - cam.y) * t, (cam.z or 0) + (fz - (cam.z or 0)) * t
		local dx, dz = px - ox, pz - oz
		local oy = other.y or 0
		if py >= oy - 0.3 and py <= oy + 6 and dx * dx + dz * dz < 0.9 then return false end
	end
	return true
end

function GEN.two(ctx, T, ult, name, dir, a, d, i, o)
	local p = GEN.ANGLES[(T.seed + i * T.step) % #GEN.ANGLES + 1]
	o = o or {}
	local A, D = ctx.cin.attacker, ctx.cin.defender
	-- The preset's angle first, then swung round: the first framing whose subject (the
	-- target, else the attacker) is not hidden behind the other body (fighters circling the
	-- target come between it and the camera).
	local last
	for _, swing in { 0, 30, -30, 60, -60 } do
		local yaw = p[1] + swing
		for _, pick in { { D, d, a }, { A, a, d } } do
			last = GEN.frame(T, GEN.name(T, ult, name), dir, { a, d }, { yaw = yaw, pitch = p[2], fill = o.fill or p[3], fov = p[4],
				roll = o.roll, focus = P(pick[1], "UpperTorso") })
			if GEN.seen(last, pick[2], pick[3]) then return last end
		end
	end
	return last
end

-- A hero shot of one fighter (`slot`), preset `i`.
function GEN.solo(T, name, dir, view, slot, i, o)
	local p = GEN.SOLO[(T.seed + i) % #GEN.SOLO + 1]
	o = o or {}
	return GEN.frame(T, name, dir, { view }, { yaw = p[1], pitch = p[2], fill = o.fill or p[3], fov = p[4], band = p[5],
		focus = P(slot, if p[5] == "bust" then "Head" else "UpperTorso") })
end

-- One of the theme's own effects: `which` is line (from -> to), burst (at `to`) or ground
-- (a ring on the floor around `to`).
function GEN.fx(frame, T, which, key, from, to, color, extra)
	local request = { key = T.id .. "-" .. key, kind = T.fx[which], from = from, to = to, pos = to, color = color,
		radius = 2.4, count = 6, life = 1.2, scale = 1 }
	for k, value in extra or {} do request[k] = value end
	table.insert(frame.fx, request)
end

-- The ultimate's name: the theme's own (ASURA borrows KAI's moves) or the move's.
function GEN.moveName(ctx, T, kind)
	return T.names and T.names[kind] or ctx.moveData.Moves[ctx.cin.move].name
end

function GEN.place(ctx, x)
	return math.clamp(x, ctx.config.ArenaMinX + 1, ctx.config.ArenaMaxX - 1)
end

-- Where the attacker waits for an archetype: far for those who fight at range.
GEN.REACH = { zone = 6.5, pull = 5.5, thrust = 4.4, beat = 4.2, dance = 5.5, swing = 3.2, rain = 3.4, roots = 4.8, pillar = 6,
	crossfire = 6.5 }
function GEN.reach(style)
	return GEN.REACH[style] or 2.9
end

-- Blow k of a barrage in the archetype `style` (beat: ticks since it landed, tick: the scene
-- tick). Sets both views and asks for the theme's effects.
function GEN.strike(ctx, frame, T, style, a, d, k, beat, tick, cx, dir, color, key)
	local moves = ctx.moveData.Moves
	local id = role(ctx, T.blows[(k - 1) % #T.blows + 1])
	local live = beat < 4
	d.x, d.y, d.state, d.pose = cx, 0, "Hitstun", nil
	if style == "lunge" then
		-- A blow from a new side each time; the attacker blurs between them.
		local angles = { 0.35, 2.7, 1.1, 2.25, 0.7, 2.95, 1.6 }
		around(a, cx, dir, angles[(k - 1) % #angles + 1], 2.9)
		attack(a, moves, id, live)
		if beat < 3 then frame.speedLines = color end
		GEN.fx(frame, T, "line", key .. "-line" .. k, v(a.x, 3, a.z), v(cx, 3, 0), color)
		if beat < 2 then spark(frame, T.id .. key .. "-spark" .. k, v(cx, 3, 0.4), color, 1.2) end
	elseif style == "orbit" then
		-- Always moving round the target, striking on the way.
		around(a, cx, dir, math.pi / 2 + 1.3 * math.sin(tick * 0.09), 3.1)
		attack(a, moves, id, live)
		GEN.fx(frame, T, "line", key .. "-trail" .. k, v(a.x, 2.6, a.z), v(cx, 3, 0), color, { life = 0.8 })
		if beat < 6 then d.y = 0.4 * math.sin(beat / 6 * math.pi) end
	elseif style == "zone" then
		-- From afar: everything flies to the target, which recoils.
		a.x, a.facing, a.z = GEN.place(ctx, cx - dir * 6.5), dir, 0
		attack(a, moves, role(ctx, if k % 2 == 1 then "KiBlast" else "PalmStrike"), live)
		GEN.fx(frame, T, "line", key .. "-shot" .. k, v(a.x + dir, 3, 0), v(cx, 3, 0), color)
		d.x = cx + dir * 0.5 * math.max(0, 1 - beat / 6)
		if beat < 2 then spark(frame, T.id .. key .. "-hit" .. k, v(cx, 3, 0.5), color, 1) end
	elseif style == "grapple" then
		-- Seized and slammed down on one side, lifted behind, slammed on the other side.
		a.x, a.facing, a.z = cx - dir * 2.9, dir, 0
		local span = 8
		local u = math.min(1, beat / span)
		local side = if k % 2 == 1 then 1 else -1
		local floorX, nextX = a.x + side * dir * 2.8, a.x - side * dir * 2.8
		if u < 0.3 then
			d.x, d.y, d.z, d.pose = floorX, 0, 0, "DownFace"
			attack(a, moves, role(ctx, "Hammer"), true)
			if beat < 2 then
				frame.impact = { key = T.id .. key .. "-slam" .. k, color = color }
				frame.quake = if T.quake then 0.9 else 0.4
			end
			GEN.fx(frame, T, "ground", key .. "-slam" .. k, nil, v(floorX, 0, 0), color, { radius = 1.8 })
			GEN.fx(frame, T, "line", key .. "-grip" .. k, v(a.x, 3.4, 0), v(floorX, 0.6, 0), color, { life = 0.5 })
		else
			local q = (u - 0.3) / 0.7
			d.x, d.y, d.z, d.pose = lerp(floorX, nextX, smooth(q)), 5.4 * math.sin(q * math.pi), -2.4 * math.sin(q * math.pi), "Launched"
			attack(a, moves, role(ctx, "BodyBlow"), false)
		end
	elseif style == "juggle" then
		-- Higher at every blow; the attacker rises with it.
		local level = math.min(k, 9)
		d.y, d.pose = lerp((level - 1) * 0.9, level * 0.9, smooth(math.min(1, beat / 6))), "Launched"
		a.x, a.facing, a.z = cx - dir * 2.5, dir, 0
		a.y = math.max(0, d.y - 1.4)
		attack(a, moves, role(ctx, if k % 2 == 1 then "AirKick" else "AirKick2"), live)
		GEN.fx(frame, T, "ground", key .. "-well" .. k, nil, v(cx, d.y, 0), color, { radius = 1.6 })
		GEN.fx(frame, T, "line", key .. "-lift" .. k, v(cx, 0, 0), v(cx, d.y + 2, 0), color, { life = 0.6 })
	elseif style == "gatling" then
		-- A storm of fists from four arms: the target pinned in place, shaking under them.
		a.x, a.facing, a.z = cx - dir * 2.9, dir, 0
		attack(a, moves, role(ctx, if (tick // 3) % 2 == 0 then "Jab" else "Cross"), true)
		d.x = cx + dir * 0.15 * math.sin(tick * 1.7)
		for j = 0, 2 do
			GEN.fx(frame, T, "line", key .. "-fist" .. k .. "-" .. j, v(a.x + dir * 0.6, 2.2 + j * 0.8, (j - 1) * 0.9),
				v(cx, 2.4 + j * 0.7, 0.3), color, { life = 0.3, scale = 0.6 })
		end
		if beat < 2 then spark(frame, T.id .. key .. "-hit" .. k, v(cx, 3, 0.5), color, 1.4) end
		frame.speedLines = color
	elseif style == "thrust" then
		-- A spear's reach: straight thrusts from out of the target's range, each one a step
		-- further in, the target driven back along the line of the shaft.
		a.x, a.facing, a.z = GEN.place(ctx, cx - dir * (4.4 - 0.3 * ((k - 1) % 3))), dir, 0
		local thrusts = { "Jab", "BodyBlow", "Smash", "PalmStrike", "LowKick" } -- (its thrusting roles)
		attack(a, moves, role(ctx, thrusts[(k - 1) % #thrusts + 1]), live)
		d.x = cx + dir * 0.5 * math.max(0, 1 - beat / 6)
		GEN.fx(frame, T, "line", key .. "-thrust" .. k, v(a.x + dir, 3.1, 0), v(cx + dir * 1.4, 3.1, 0), color, { life = 0.4 })
		if beat < 2 then
			frame.speedLines = color
			spark(frame, T.id .. key .. "-pierce" .. k, v(cx, 3.1, 0.4), color, 1.3)
		end
	elseif style == "freeze" then
		-- The target held still (ice, a seal of light): no recoil at all while the attacker
		-- flows from one side to the other, the hold growing under it.
		around(a, cx, dir, if k % 2 == 1 then 0.45 else 2.7, 2.5)
		attack(a, moves, id, live)
		d.x, d.y = cx, 0
		GEN.fx(frame, T, "ground", key .. "-hold" .. k, nil, v(cx, 0, 0), color, { radius = 1 + 0.15 * math.min(k, 8), life = 0.8 })
		GEN.fx(frame, T, "line", key .. "-shard" .. k, v(a.x, 3, a.z), v(cx, 3, 0), color, { life = 0.3 })
		if beat < 2 then GEN.fx(frame, T, "burst", key .. "-crack" .. k, v(a.x, 3, a.z), v(cx, 3, 0), color, { scale = 0.8 }) end
	elseif style == "stalk" then
		-- Out of the shadows: low, in front, then behind, then in front again; the target
		-- staggers toward the side it was hit from.
		local behind = k % 2 == 0
		around(a, cx, dir, if behind then math.pi - 0.25 else 0.25, 2.5)
		attack(a, moves, id, live)
		d.x = cx + (if behind then dir else -dir) * 0.35 * math.sin(math.min(1, beat / 7) * math.pi)
		if beat < 3 then
			GEN.fx(frame, T, "line", key .. "-claw" .. k, v(cx - 0.6, 3.7, 0.5), v(cx + 0.6, 2.3, 0.5), color, { life = 0.4 })
		end
	elseif style == "beat" then
		-- To the rhythm: the target hops on every beat, the attacker strikes from its spot
		-- and the floor pulses under it.
		a.x, a.facing, a.z = GEN.place(ctx, cx - dir * 4.2), dir, 0
		attack(a, moves, role(ctx, if k % 2 == 1 then "Kick" else "Cross"), live)
		d.x, d.y = cx, 0.9 * math.sin(math.min(1, beat / 8) * math.pi)
		GEN.fx(frame, T, "ground", key .. "-pulse" .. k, nil, v(a.x, 0, 0), color, { radius = 1 + 0.25 * (k % 4), life = 0.5 })
		GEN.fx(frame, T, "line", key .. "-wave" .. k, v(a.x + dir, 2.8, 0), v(cx, 3, 0), color, { life = 0.4 })
	elseif style == "dance" then
		-- A puppet: the target jerked from one side to the other on its threads, the
		-- attacker pulling them from afar.
		a.x, a.facing, a.z = GEN.place(ctx, cx - dir * 5.5), dir, 0
		attack(a, moves, role(ctx, if k % 2 == 1 then "KiBlast" else "PalmStrike"), live)
		local side = if k % 2 == 1 then 1 else -1
		d.x, d.y = cx + dir * side * 1.1 * smooth(math.min(1, beat / 6)), 0.5 * math.sin(math.min(1, beat / 6) * math.pi)
		for j = 0, 1 do
			GEN.fx(frame, T, "line", key .. "-thread" .. k .. "-" .. j, v(a.x + dir * 0.8, 3.4 - j * 0.6, 0), v(d.x, 3.6 - j * 0.8, 0), color,
				{ life = 0.5, scale = 0.6 })
		end
	elseif style == "swing" then
		-- Caught at the end of a chain (or an arm) and swung round the attacker.
		a.x, a.facing, a.z = GEN.place(ctx, cx - dir * 3.2), dir, 0
		attack(a, moves, role(ctx, if k % 2 == 1 then "Hammer" else "Cross"), true)
		local turn = 0.6 * k + beat * 0.1
		d.x, d.z = a.x + dir * 3.4 * math.cos(turn), -math.abs(3.4 * math.sin(turn))
		d.y, d.pose = 1 + 0.6 * math.abs(math.sin(turn)), "Launched"
		GEN.fx(frame, T, "line", key .. "-chain" .. k, v(a.x + dir * 0.6, 3.2, 0), v(d.x, d.y + 2, d.z), color, { life = 0.3 })
	elseif style == "rain" then
		-- From above: the attacker strikes down out of the air, the sky pours on the target
		-- pinned to the floor.
		a.x, a.facing, a.z, a.y = cx - dir * 1.8, dir, 0, 3
		attack(a, moves, role(ctx, if k % 2 == 1 then "AirSmash" else "AirKick"), live)
		d.x, d.y = cx, 0
		local n = (k * 5) % 3 - 1
		GEN.fx(frame, T, "line", key .. "-fall" .. k, v(cx + n * 0.9, 11, 0), v(cx + n * 0.3, 1, 0), color, { life = 0.5 })
		if beat < 2 then spark(frame, T.id .. key .. "-splash" .. k, v(cx, 0.6, 0.4), color, 1.2) end
	elseif style == "roots" then
		-- Roots out of the floor lift the target a little higher at every blow; the attacker
		-- stays low, out of reach.
		a.x, a.facing, a.z = GEN.place(ctx, cx - dir * 4.8), dir, 0
		attack(a, moves, role(ctx, if k % 2 == 1 then "Sweep" else "PalmStrike"), live)
		d.x, d.y, d.pose = cx, math.min(3, k * 0.35) + 0.25 * math.sin(beat * 0.4), "Launched"
		GEN.fx(frame, T, "line", key .. "-root" .. k, v(cx + (if k % 2 == 0 then 1.3 else -1.3), 0, 0.6), v(cx, d.y + 2, 0), color,
			{ life = 0.7 })
		GEN.fx(frame, T, "ground", key .. "-bed" .. k, nil, v(cx, 0, 0), color, { radius = 1.8, life = 0.7 })
	elseif style == "pillar" then
		-- Pillars from the sky on the target, called from afar.
		a.x, a.facing, a.z = GEN.place(ctx, cx - dir * 6), dir, 0
		attack(a, moves, role(ctx, if k % 2 == 1 then "Rising" else "PalmStrike"), live)
		d.x, d.y = cx, 0
		GEN.fx(frame, T, "line", key .. "-pillar" .. k, v(cx, 12, 0), v(cx, 0, 0), color, { life = 0.6, scale = 1.6 })
		if beat < 2 then GEN.fx(frame, T, "ground", key .. "-strike" .. k, nil, v(cx, 0, 0), color, { radius = 2.2, life = 0.6 }) end
	elseif style == "crossfire" then
		-- Shots from every side at once (drones, thorns, gravity): the target rocks
		-- toward the side opposite each one.
		a.x, a.facing, a.z = GEN.place(ctx, cx - dir * 6.5), dir, 0
		attack(a, moves, role(ctx, if k % 2 == 1 then "KiBlast" else "Smash"), live)
		local from = ({ v(cx - dir * 4, 5, 0), v(cx + dir * 0.5, 7, -4), v(cx + dir * 3.5, 4.5, -2.5) })[(k - 1) % 3 + 1]
		GEN.fx(frame, T, "line", key .. "-cross" .. k, from, v(cx, 3, 0), color, { life = 0.4 })
		local push = if from.x > cx then -1 else 1
		d.x = cx + push * 0.4 * math.max(0, 1 - beat / 6)
		if beat < 2 then spark(frame, T.id .. key .. "-hit" .. k, v(cx, 3, 0.4), color, 1) end
	else -- pull
		-- Dragged in on every blow, then thrown back.
		a.x, a.facing, a.z = GEN.place(ctx, cx - dir * 5.5), dir, 0
		attack(a, moves, role(ctx, if k % 2 == 1 then "PalmStrike" else "Cross"), live)
		d.x = cx - dir * 1.4 * math.sin(math.min(1, beat / 8) * math.pi)
		GEN.fx(frame, T, "line", key .. "-pull" .. k, v(a.x + dir * 0.8, 3, 0), v(cx, 3, 0), color, { life = 0.6 })
	end
end

-- The attacker squared up before the final blow of an archetype.
function GEN.square(ctx, a, cx, dir, style)
	a.x, a.y, a.z, a.facing, a.lookDir = GEN.place(ctx, cx - dir * GEN.reach(style)), 0, 0, dir, nil
end

-- ---------------------------------------------------------------- OUVERTURES ET FINS
--[[
	Wilhem: « une ouverture et une fin propres à chacun... tous différentes ». Each themed kit
	opens and closes each of its four ultimates its own way (`open` / `finish`, one entry per
	ultimate): no two kits share an opening or an ending of the same ultimate, and a kit never
	repeats one (tests/CinematicDirector.test.luau). Twenty of each, all painted with the kit's
	own effects, poses and colour:
	  openings  descend (falls from the sky), emerge (rises out of the floor), backturn (back to
	            the target, turns round), stride (walks in, feet first), kneel (rises from one
	            knee), blink (in the target's face, then away), charge (runs in, skids), levitate,
	            meditate (arms crossed, eyes open), slam (strikes the floor), spin, silhouette
	            (black and white, then colour), gather (the power converges on it), target (the
	            target looks round for it), leap (a great jump in), kata (shadow-boxes), path (its
	            mark runs to the target), clones (afterimages close in), eyes (a close-up on the
	            face pulls back), storm (its effects rain on the arena first);
	  endings   crater (from the air, the target driven into the floor), passthrough (through the
	            target, which falls a beat later), skyward (sent high, watched falling),
	            blowaway (blown across the arena), pin (slammed down, stood over), turnaway
	            (turns its back and leaves), vanish (gone, then back at a distance), hover (floats
	            above the fallen target), stomp, bow, orbit (the camera circles the victor),
	            freeze (the impact frame held in black and white), rain (its effects pour on the
	            fallen target), walkpast, echo (the blow resounds three more times), bounce (the
	            target bounces twice), flourish (a last kata), seal (its kanji sealed on the
	            target), exit (walks out of the frame, the target left alone), slowmo.
]]
GEN.OPEN, GEN.END = {}, {}

-- One opening or ending scene: the shared values of the archetypes.
function GEN.scene(ctx, frame, T, a, d, tick, dir, ult, kind)
	local cin = ctx.cin
	return { ctx = ctx, frame = frame, T = T, a = a, d = d, tick = tick, dir = dir, ult = ult, kind = kind,
		cx = center(ctx, d), color = ctx.characters[cin.attacker].Energy, A = cin.attacker, D = cin.defender,
		data = ctx.moveData.Cinematics[cin.move], cin = cin }
end

function GEN.shot(I, part, subjects, o)
	return GEN.frame(I.T, GEN.name(I.T, I.ult, part), I.dir, subjects, o)
end

local function spot(x, y, z)
	return { point = true, x = x, y = y, z = z or 0 }
end

-- The attacker standing at x, facing the target.
function GEN.stand(I, x, pose)
	local a = I.a
	a.x, a.y, a.z, a.facing, a.lookDir, a.state, a.vx = x, 0, 0, I.dir, nil, "Idle", 0
	a.pose = pose
end

-- ---------------------------------------------------------------- openings
-- (I, p: 0..1 over the opening, home: where the attacker stands when it ends)

function GEN.OPEN.descend(I, p, home)
	local a, T = I.a, I.T
	local q = math.min(1, p / 0.55)
	GEN.stand(I, home, if q < 1 then "Levitate" elseif p < 0.78 then "Kneel" else T.pose)
	a.y = 12 * (1 - q) ^ 2
	if q >= 1 then
		if p < 0.64 then I.frame.quake = 0.9 end
		GEN.fx(I.frame, T, "ground", I.ult .. "-land", nil, v(home, 0, 0), I.color, { radius = 3, life = 1.4 })
		GEN.fx(I.frame, T, "burst", I.ult .. "-land-burst", v(home, 6, 0), v(home, 0.5, 0), I.color)
	else
		GEN.fx(I.frame, T, "line", I.ult .. "-fall", v(home, 16, 0), v(home, 1, 0), I.color, { life = 0.5 })
	end
	I.frame.shot = GEN.shot(I, "descend", { a, spot(home, 0.5) }, { yaw = 22, pitch = -16, fill = 0.72, fov = 46,
		focus = P(I.A, "UpperTorso") })
end

function GEN.OPEN.emerge(I, p, home)
	local a, T = I.a, I.T
	GEN.stand(I, home, T.pose)
	a.y = lerp(-5.8, 0, smooth(math.min(1, p / 0.6)))
	GEN.fx(I.frame, T, "ground", I.ult .. "-pool", nil, v(home, 0, 0), I.color, { radius = 2.6, life = 2 })
	if p >= 0.6 then GEN.fx(I.frame, T, "burst", I.ult .. "-out", v(home, 0, 0), v(home, 3, 0), I.color) end
	I.frame.shot = GEN.shot(I, "emerge", { a, spot(home, 0.4) }, { yaw = -24, pitch = 10, fill = 0.7, fov = 42,
		focus = P(I.A, "UpperTorso") })
end

function GEN.OPEN.backturn(I, p, home)
	local a, T, dir = I.a, I.T, I.dir
	local turn = smooth(math.clamp((p - 0.4) / 0.35, 0, 1))
	GEN.stand(I, home, if turn < 1 then T.rest else T.pose)
	local angle = math.pi * (1 - turn) -- pi: its back to the target; it turns round facing the camera
	a.lookDir = v(dir * math.cos(angle), 0, math.sin(angle))
	if turn >= 1 then GEN.fx(I.frame, T, "burst", I.ult .. "-turn", v(home, 0, 0), v(home, 3, 0), I.color) end
	I.frame.shot = GEN.shot(I, "backturn", { a }, { yaw = 48, pitch = 2, fill = 0.9, fov = 36, band = "bust",
		focus = P(I.A, "Head") })
end

function GEN.OPEN.stride(I, p, home)
	local a, T, dir = I.a, I.T, I.dir
	local from = GEN.place(I.ctx, home - dir * 4)
	local q = math.min(1, p / 0.8)
	GEN.stand(I, lerp(from, home, q), T.pose)
	if q < 1 then a.state, a.vx, a.pose = "Walking", dir * 2, nil end
	local stepN = math.floor(q * 5)
	GEN.fx(I.frame, T, "ground", I.ult .. "-step" .. stepN, nil, v(a.x, 0, 0), I.color, { radius = 0.9, count = 3, life = 0.8 })
	if p < 0.5 and I.long then
		I.frame.shot = GEN.shot(I, "stride-steps", { a }, { yaw = -20, pitch = -4, fill = 0.85, fov = 40, band = "waist",
			focus = P(I.A, "UpperTorso") })
	else
		I.frame.shot = GEN.shot(I, "stride", { a, I.d }, { yaw = -34, pitch = 6, fill = 0.66, fov = 42, focus = P(I.A, "UpperTorso") })
	end
end

function GEN.OPEN.kneel(I, p, home)
	local a, T = I.a, I.T
	GEN.stand(I, home, if p < 0.55 then "Kneel" elseif p < 0.72 then T.rest else T.pose)
	GEN.fx(I.frame, T, "ground", I.ult .. "-kneel", nil, v(home, 0, 0), I.color, { radius = 2.2, life = 1.6 })
	if p >= 0.55 then GEN.fx(I.frame, T, "burst", I.ult .. "-rise", v(home, 0, 0), v(home, 3, 0), I.color) end
	I.frame.shot = GEN.shot(I, "kneel", { a }, { yaw = -16, pitch = if p < 0.55 then 24 else -14, fill = 0.82, fov = 40,
		focus = P(I.A, "Head") })
end

function GEN.OPEN.blink(I, p, home)
	local a, T, dir, cx = I.a, I.T, I.dir, I.cx
	if p < 0.45 then
		-- an afterimage in the target's face
		GEN.stand(I, GEN.place(I.ctx, cx - dir * 1.2), T.pose)
		a.z, a.ghost = -1.4, true
		GEN.fx(I.frame, T, "burst", I.ult .. "-blink-in", v(a.x, 3, -1.4), v(a.x, 3, -1.4), I.color)
	else
		GEN.stand(I, home, T.pose)
		a.ghost = p < 0.55
		GEN.fx(I.frame, T, "burst", I.ult .. "-blink-out", v(home, 3, 0), v(home, 3, 0), I.color)
	end
	I.frame.shot = GEN.shot(I, "blink", { a, I.d }, { yaw = 30, pitch = 4, fill = 0.7, fov = 40, focus = P(I.D, "Head") })
end

function GEN.OPEN.charge(I, p, home)
	local a, T, dir = I.a, I.T, I.dir
	local from = GEN.place(I.ctx, home - dir * 10)
	local q = math.min(1, p / 0.62)
	GEN.stand(I, lerp(from, home, 1 - (1 - q) ^ 2), if q < 1 then "Dash" else T.pose)
	if q < 1 then
		I.frame.speedLines = I.color
	elseif p < 0.8 then
		GEN.fx(I.frame, T, "ground", I.ult .. "-skid", nil, v(home, 0, 0), I.color, { radius = 1.8, life = 1 })
		if p < 0.7 then I.frame.quake = 0.4 end
	end
	I.frame.shot = GEN.shot(I, "charge", { a, I.d }, { yaw = -40, pitch = 4, fill = 0.62, fov = 46, focus = P(I.A, "UpperTorso") })
end

function GEN.OPEN.levitate(I, p, home)
	local a, T = I.a, I.T
	local up = math.sin(math.min(1, p / 0.85) * math.pi)
	GEN.stand(I, home, if up > 0.15 then "Levitate" else T.pose)
	a.y = up * 2.4 + math.sin(I.tick * 0.2) * 0.12 * up
	I.frame.aura = I.A
	GEN.fx(I.frame, T, "ground", I.ult .. "-float", nil, v(home, 0, 0), I.color, { radius = 2, life = 2 })
	I.frame.shot = GEN.shot(I, "levitate", { a, spot(home, 0.5) }, { yaw = 28, pitch = -22, fill = 0.74, fov = 44,
		focus = P(I.A, "UpperTorso") })
end

function GEN.OPEN.meditate(I, p, home)
	local a, T = I.a, I.T
	GEN.stand(I, home, if p < 0.6 then "ArmsCrossed" else T.pose)
	if p >= 0.6 then
		GEN.fx(I.frame, T, "burst", I.ult .. "-wake", v(home, 0, 0), v(home, 4, 0), I.color, { scale = 1.6 })
		I.frame.aura = I.A
	end
	I.frame.shot = GEN.shot(I, "meditate", { a }, { yaw = -10, pitch = 0, fill = 0.95, fov = 30,
		band = "bust", focus = P(I.A, "Head") })
end

function GEN.OPEN.slam(I, p, home)
	local a, T = I.a, I.T
	GEN.stand(I, home, if p < 0.3 then T.rest elseif p >= 0.75 then T.pose else nil)
	if p >= 0.3 and p < 0.75 then attack(a, I.ctx.moveData.Moves, role(I.ctx, "Hammer"), p >= 0.42 and p < 0.6) end
	if p >= 0.45 then
		if p < 0.55 then I.frame.quake = 1.2 end
		GEN.fx(I.frame, T, "ground", I.ult .. "-slam", nil, v(home + I.dir, 0, 0), I.color, { radius = 4, count = 10, life = 1.6 })
		GEN.fx(I.frame, T, "burst", I.ult .. "-slam-burst", v(home + I.dir, 3, 0), v(home + I.dir, 0.3, 0), I.color)
	end
	I.frame.shot = GEN.shot(I, "slam", { a, spot(home + I.dir * 2, 0.3) }, { yaw = 36, pitch = -8, fill = 0.7, fov = 44,
		focus = P(I.A, "UpperTorso") })
end

function GEN.OPEN.spin(I, p, home)
	local a, T, dir = I.a, I.T, I.dir
	local q = math.min(1, p / 0.7)
	GEN.stand(I, home, if q < 1 then "WindGather" else T.pose)
	local angle = smooth(q) * math.pi * 4
	a.lookDir = v(dir * math.cos(angle), 0, math.sin(angle))
	local k = math.floor(q * 6)
	local around2 = k * 1.05
	GEN.fx(I.frame, T, "line", I.ult .. "-spin" .. k, v(home + math.cos(around2) * 2.5, 1 + k * 0.5, -math.abs(math.sin(around2)) * 2.5),
		v(home, 2.5, 0), I.color, { life = 0.4 })
	I.frame.shot = GEN.shot(I, "spin", { a }, { yaw = lerp(-40, 30, p), pitch = 8, fill = 0.8, fov = 40, focus = P(I.A, "UpperTorso") })
end

function GEN.OPEN.silhouette(I, p, home)
	local a, T = I.a, I.T
	GEN.stand(I, home, if p < 0.55 then T.rest else T.pose)
	I.frame.grade.mono = p < 0.55
	if p >= 0.55 then GEN.fx(I.frame, T, "burst", I.ult .. "-colour", v(home, 0, 0), v(home, 3, 0), I.color, { scale = 2 }) end
	if p < 0.55 and I.long then
		I.frame.shot = GEN.shot(I, "silhouette-wide", { a, I.d }, { yaw = 6, pitch = 2, fill = 0.48, fov = 38, focus = P(I.A, "UpperTorso") })
	else
		I.frame.shot = GEN.shot(I, "silhouette", { a }, { yaw = -26, pitch = -12, fill = 0.88, fov = 38, focus = P(I.A, "UpperTorso") })
	end
end

function GEN.OPEN.gather(I, p, home)
	local a, T = I.a, I.T
	GEN.stand(I, home, T.pose)
	I.frame.aura = I.A
	local k = math.floor(p * 8)
	if p < 0.75 then
		local angle = k * 0.8
		GEN.fx(I.frame, T, "line", I.ult .. "-gather" .. k, v(home + math.cos(angle) * 5, 1 + (k % 3) * 2.5, -math.abs(math.sin(angle)) * 5),
			v(home, 3, 0), I.color, { life = 0.5 })
	else
		GEN.fx(I.frame, T, "burst", I.ult .. "-gathered", v(home, 0, 0), v(home, 3, 0), I.color, { scale = 2 })
	end
	I.frame.shot = GEN.shot(I, "gather", { a }, { yaw = 14, pitch = 18, fill = lerp(0.7, 0.9, p), fov = 46, focus = P(I.A, "UpperTorso") })
end

function GEN.OPEN.target(I, p, home)
	local a, d, T, dir = I.a, I.d, I.T, I.dir
	if p < 0.55 then
		-- The target alone, looking round for it.
		vanish(a)
		d.state, d.pose = "Idle", nil
		local look = math.sin(p * 18)
		d.lookDir = v(-dir * math.cos(look * 0.9), 0, math.sin(look * 0.9))
		I.frame.shot = GEN.shot(I, "target", { d }, { yaw = -30, pitch = 4, fill = 0.9, fov = 36, band = "bust", focus = P(I.D, "Head") })
	else
		GEN.stand(I, home, T.pose)
		a.ghost = p < 0.62
		d.lookDir = nil
		GEN.fx(I.frame, T, "burst", I.ult .. "-here", v(home, 3, 0), v(home, 3, 0), I.color)
		I.frame.shot = GEN.shot(I, "target-found", { a, d }, { yaw = 40, pitch = 6, fill = 0.7, fov = 42, focus = P(I.A, "UpperTorso") })
	end
end

function GEN.OPEN.leap(I, p, home)
	local a, T, dir = I.a, I.T, I.dir
	local from = GEN.place(I.ctx, home - dir * 9)
	local q = math.min(1, p / 0.65)
	GEN.stand(I, lerp(from, home, q), if q < 1 then "Levitate" elseif p < 0.8 then "Kneel" else T.pose)
	a.y = math.sin(q * math.pi) * 7
	if q >= 1 and p < 0.72 then
		I.frame.quake = 0.8
		GEN.fx(I.frame, T, "ground", I.ult .. "-leap", nil, v(home, 0, 0), I.color, { radius = 3, life = 1.4 })
	end
	I.frame.shot = GEN.shot(I, "leap", { a, spot(home, 0.3), spot(from, 0.3) }, { yaw = -8, pitch = -6, fill = 0.66, fov = 46,
		focus = P(I.A, "UpperTorso") })
end

function GEN.OPEN.kata(I, p, home)
	local a, T = I.a, I.T
	local seq = { "Jab", "Cross", "Kick", "Elbow", "SpinKick" }
	local k = math.floor(p * 6) + 1
	GEN.stand(I, home, if k > #seq then T.pose else nil)
	if k <= #seq then
		attack(a, I.ctx.moveData.Moves, role(I.ctx, seq[k]), (p * 6) % 1 > 0.4)
		GEN.fx(I.frame, T, "line", I.ult .. "-kata" .. k, v(home, 3, 0), v(home + I.dir * 2, 3, 0), I.color, { life = 0.3 })
	end
	I.frame.shot = GEN.shot(I, "kata", { a }, { yaw = -36, pitch = 6, fill = 0.82, fov = 40, focus = P(I.A, "UpperTorso") })
end

function GEN.OPEN.path(I, p, home)
	local a, T, dir, cx = I.a, I.T, I.dir, I.cx
	GEN.stand(I, home, T.pose)
	local k = math.floor(math.min(1, p / 0.8) * 5)
	local x = lerp(home, cx, k / 5)
	GEN.fx(I.frame, T, "ground", I.ult .. "-path" .. k, nil, v(x, 0, 0), I.color, { radius = 1.2, count = 4, life = 1.6 })
	if k >= 5 then GEN.fx(I.frame, T, "burst", I.ult .. "-path-end", v(cx, 0, 0), v(cx, 3, 0), I.color) end
	I.frame.shot = GEN.shot(I, "path", { a, I.d }, { yaw = 4, pitch = 42, fill = 0.66, fov = 44, focus = P(I.A, "UpperTorso") })
end

function GEN.OPEN.clones(I, p, home)
	local a, T, dir = I.a, I.T, I.dir
	GEN.stand(I, home, T.pose)
	local q = math.min(1, p / 0.7)
	for i = 1, 4 do
		local angle = i * 1.4 + 0.3
		local r = lerp(6, 0.3, q)
		GEN.fx(I.frame, T, "burst", I.ult .. "-clone" .. i .. "-" .. math.floor(q * 4),
			v(home + math.cos(angle) * r, 3, -math.abs(math.sin(angle)) * r), v(home + math.cos(angle) * r, 3, -math.abs(math.sin(angle)) * r),
			I.color, { scale = 0.7 })
	end
	a.ghost = q < 1
	I.frame.shot = GEN.shot(I, "clones", { a, spot(home - dir * 3, 2, -3), spot(home + dir * 3, 2, -3) }, { yaw = 10, pitch = 14,
		fill = 0.7, fov = 44, focus = P(I.A, "UpperTorso") })
end

function GEN.OPEN.eyes(I, p, home)
	local a, T = I.a, I.T
	GEN.stand(I, home, T.pose)
	if p >= 0.5 then I.frame.aura = I.A end
	I.frame.shot = GEN.shot(I, "eyes", { a }, { yaw = -6, pitch = 0, fill = lerp(1.0, 0.7, smooth(p)), fov = lerp(24, 40, smooth(p)),
		band = if p < 0.5 then "bust" else "full", focus = P(I.A, "Head") })
end

function GEN.OPEN.storm(I, p, home)
	local a, T, cx = I.a, I.T, I.cx
	GEN.stand(I, home, if p < 0.7 then T.rest else T.pose)
	if I.tick % 4 == 0 and p < 0.85 then
		local n = (I.tick * 7) % 13
		local x = lerp(home, cx, n / 12) + (n % 3 - 1)
		GEN.fx(I.frame, T, "line", I.ult .. "-storm" .. I.tick, v(x, 10, -2 - n % 3), v(x, 0, -1 - n % 2), I.color, { life = 0.6 })
	end
	I.frame.shot = GEN.shot(I, "storm", { a, I.d, spot((home + cx) / 2, 7, -2) }, { yaw = -14, pitch = -4, fill = 0.56, fov = 46,
		focus = P(I.A, "UpperTorso") })
end

-- ---------------------------------------------------------------- endings
-- The blow (tick F .. F + I.B), then what follows. I.blow: the move of the blow; I.push and
-- I.lift: where the default blow sends the target; I.blowShot / I.preset: its shot.

-- How the target lies once it is over: face down, or on one knee when a COUP FATAL did not kill.
function GEN.lie(I, x)
	local d = I.d
	d.x, d.y = x, 0
	if I.kind == "Fatal" and not I.cin.finish then
		d.pose, d.lookDir = "Kneel", nil
	else
		d.pose, d.lookDir = "DownFace", v(0, 0, -1)
	end
end

-- The usual blow: squared up, the target thrown back in an arc.
function GEN.blow(I, e, o)
	o = o or {}
	local ctx, a, d, T, dir, cx = I.ctx, I.a, I.d, I.T, I.dir, I.cx
	GEN.square(ctx, a, cx, dir, I.style)
	attack(a, ctx.moveData.Moves, role(ctx, o.move or I.blow), true)
	local push, lift = o.push or I.push, o.lift or I.lift
	d.x, d.y, d.pose = cx + dir * push * smooth(e), math.sin(math.min(1, e / 0.9) * math.pi) * lift, "Launched"
	if e < 0.5 then impact(I.frame, T.id .. "-" .. I.ult .. "-final", v(cx, 3, 0.6), I.color, I.impact) end
	GEN.fx(I.frame, T, "burst", I.ult .. "-burst", v(a.x, 3, 0), v(cx, 3, 0), I.color, { scale = I.burst })
	if I.q < 5 then I.frame.quake = if T.quake then I.quake * 1.5 else I.quake end
	if not o.noShot then I.frame.shot = GEN.two(ctx, T, I.ult, I.blowShot, dir, a, d, I.preset) end
end

-- The attacker squared up and resting after the blow, the target down where it was thrown.
function GEN.settle(I, pose)
	GEN.square(I.ctx, I.a, I.cx, I.dir, I.style)
	I.a.pose = pose or I.T.rest
	GEN.lie(I, I.cx + I.dir * I.push)
end

function GEN.END.crater(I, e, after)
	local a, d, T, dir, cx = I.a, I.d, I.T, I.dir, I.cx
	if not after then
		GEN.square(I.ctx, a, cx, dir, I.style)
		a.x = GEN.place(I.ctx, cx - dir * lerp(GEN.reach(I.style), 1.6, e))
		a.y = math.sin(math.min(1, e / 0.7) * math.pi) * 4.5 + (if e < 0.35 then e * 4 else 0)
		a.ghost = true
		attack(a, I.ctx.moveData.Moves, role(I.ctx, "Hammer"), e >= 0.4)
		if e < 0.45 then
			d.x, d.y, d.pose = cx, 0, nil
		else
			GEN.lie(I, cx)
			d.pose = "DownFace"
			if e < 0.6 then I.frame.quake = 1.8 end
			impact(I.frame, T.id .. "-" .. I.ult .. "-crater", v(cx, 0.5, 0.4), I.color, I.impact)
			GEN.fx(I.frame, T, "ground", I.ult .. "-crater", nil, v(cx, 0, 0), I.color, { radius = 4.5, count = 12, life = 2.5 })
			GEN.fx(I.frame, T, "burst", I.ult .. "-burst", v(a.x, a.y + 3, 0), v(cx, 0.5, 0), I.color, { scale = I.burst })
		end
		I.frame.shot = GEN.two(I.ctx, T, I.ult, I.blowShot, dir, a, d, I.preset)
	else
		GEN.stand(I, GEN.place(I.ctx, cx - dir * 3), if e < 0.35 then "Kneel" else T.rest)
		GEN.lie(I, cx)
		I.frame.shot = GEN.shot(I, "crater", { a, d }, { yaw = 10, pitch = 64, fill = 0.6, fov = 44, focus = P(I.D, "UpperTorso") })
	end
end

function GEN.END.passthrough(I, e, after)
	local a, d, T, dir, cx = I.a, I.d, I.T, I.dir, I.cx
	local beyond = GEN.place(I.ctx, cx + dir * 3.4)
	if not after then
		local q = math.min(1, e / 0.4)
		GEN.stand(I, lerp(GEN.place(I.ctx, cx - dir * GEN.reach(I.style)), beyond, smooth(q)), nil)
		a.ghost = q < 1
		attack(a, I.ctx.moveData.Moves, role(I.ctx, I.blow), q < 1)
		if q < 1 then I.frame.speedLines = I.color end
		GEN.fx(I.frame, T, "line", I.ult .. "-through", v(cx - dir * 3, 3, 0), v(beyond, 3, 0), I.color, { life = 0.8 })
		d.x, d.y, d.state, d.pose = cx, 0, "Hitstun", nil
		-- (from the side: the dash crosses the frame instead of piling the bodies up)
		I.frame.shot = GEN.shot(I, "passthrough-dash", { d, spot(cx - dir * 3, 3), spot(beyond, 3) }, { yaw = -6, pitch = 4, fill = 0.62,
			fov = 42, focus = P(I.D, "UpperTorso") })
	else
		GEN.stand(I, beyond, T.rest)
		a.lookDir = v(dir, 0, 0.25)
		-- The target stands a beat, then the blow lands all at once.
		if e < 0.3 then
			d.x, d.y, d.state, d.pose = cx, 0, "Hitstun", nil
		else
			if e < 0.4 then
				impact(I.frame, T.id .. "-" .. I.ult .. "-late", v(cx, 3, 0.6), I.color, I.impact)
				GEN.fx(I.frame, T, "burst", I.ult .. "-burst", v(cx, 3, 0), v(cx, 3, 0), I.color, { scale = I.burst })
				I.frame.quake = I.quake
			end
			GEN.lie(I, cx)
		end
		I.frame.shot = GEN.shot(I, "passthrough", { a, d }, { yaw = 52, pitch = 4, fill = 0.7, fov = 40, focus = P(I.A, "Head") })
	end
end

function GEN.END.skyward(I, e, after)
	local a, d, T, dir, cx = I.a, I.d, I.T, I.dir, I.cx
	if not after then
		GEN.blow(I, e, { move = "Uppercut", push = 0.4, lift = 0, noShot = true })
		d.y = e * 6
		I.frame.shot = GEN.two(I.ctx, T, I.ult, I.blowShot, dir, a, d, I.preset)
	else
		GEN.settle(I, T.pose)
		local up = 6 + math.sin(math.min(1, e / 0.75) * math.pi) * 3
		if e < 0.75 then
			d.x, d.y, d.pose = cx + dir * 0.4, up * (1 - e / 0.75) + (if e < 0.4 then e * 4 else 0), "Launched"
		else
			GEN.lie(I, cx + dir * 0.4)
			if e < 0.85 then I.frame.quake = I.quake end
		end
		I.frame.shot = GEN.shot(I, "skyward", { a, d, spot(cx, 9) }, { yaw = -20, pitch = -28, fill = 0.66, fov = 48,
			focus = P(I.A, "UpperTorso") })
	end
end

function GEN.END.blowaway(I, e, after)
	local a, d, T, dir, cx = I.a, I.d, I.T, I.dir, I.cx
	local far = GEN.place(I.ctx, cx + dir * 7)
	if not after then
		GEN.blow(I, e, { push = 0, lift = 0, noShot = true })
		d.x, d.y, d.pose = lerp(cx, far, 1 - (1 - e) ^ 2), math.sin(e * math.pi) * 1.4, "Launched"
		GEN.fx(I.frame, T, "line", I.ult .. "-away", v(cx, 3, 0), v(far, 2, 0), I.color, { life = 0.6 })
		I.frame.shot = GEN.shot(I, "blowaway", { a, d, spot(far, 1) }, { yaw = -10, pitch = 6, fill = 0.6, fov = 46,
			focus = P(I.D, "UpperTorso") })
	else
		GEN.square(I.ctx, a, cx, dir, I.style)
		a.pose = T.pose
		GEN.lie(I, far)
		GEN.fx(I.frame, T, "ground", I.ult .. "-skid", nil, v(far, 0, 0), I.color, { radius = 2, life = 2 })
		I.frame.shot = GEN.shot(I, "blowaway-far", { a, d }, { yaw = -24, pitch = 10, fill = 0.48, fov = 40, focus = P(I.A, "UpperTorso") })
	end
end

function GEN.END.pin(I, e, after)
	local a, d, T, dir, cx = I.a, I.d, I.T, I.dir, I.cx
	if not after then
		GEN.square(I.ctx, a, cx, dir, I.style)
		attack(a, I.ctx.moveData.Moves, role(I.ctx, "Hammer"), true)
		if e < 0.35 then
			d.x, d.y, d.pose = cx, lerp(1.5, 0, e / 0.35), "Launched"
		else
			GEN.lie(I, cx)
			d.pose = "DownFace"
			if e < 0.5 then
				I.frame.quake = I.quake * 1.4
				impact(I.frame, T.id .. "-" .. I.ult .. "-pin", v(cx, 0.6, 0.4), I.color, I.impact)
				GEN.fx(I.frame, T, "burst", I.ult .. "-burst", v(a.x, 3, 0), v(cx, 0.6, 0), I.color, { scale = I.burst })
			end
		end
		I.frame.shot = GEN.two(I.ctx, T, I.ult, I.blowShot, dir, a, d, I.preset)
	else
		GEN.stand(I, GEN.place(I.ctx, cx - dir * 2.2), T.pose)
		a.lookDir = v(dir, 0, 0)
		GEN.lie(I, cx)
		GEN.fx(I.frame, T, "ground", I.ult .. "-pinned", nil, v(cx, 0, 0), I.color, { radius = 2.4, life = 3 })
		I.frame.shot = GEN.shot(I, "pin", { a, d }, { yaw = -30, pitch = 50, fill = 0.66, fov = 42, focus = P(I.A, "Head") })
	end
end

function GEN.END.turnaway(I, e, after)
	local a, d, T, dir, cx = I.a, I.d, I.T, I.dir, I.cx
	if not after then return GEN.blow(I, e) end
	local start = GEN.place(I.ctx, cx - dir * GEN.reach(I.style))
	local q = math.clamp((e - 0.2) / 0.7, 0, 1)
	GEN.stand(I, GEN.place(I.ctx, start - dir * 3 * q), T.rest)
	a.lookDir, a.facing = v(-dir, 0, 0), -dir
	if q > 0 and q < 1 then a.state, a.vx = "Walking", -dir * 2 end
	GEN.lie(I, cx + dir * I.push)
	I.frame.shot = GEN.shot(I, "turnaway", { a, d }, { yaw = -50, pitch = 2, fill = 0.66, fov = 38, focus = P(I.A, "Head") })
end

function GEN.END.vanish(I, e, after)
	local a, d, T, dir, cx = I.a, I.d, I.T, I.dir, I.cx
	if not after then return GEN.blow(I, e) end
	GEN.lie(I, cx + dir * I.push)
	if e < 0.6 then
		if e < 0.12 then
			GEN.square(I.ctx, a, cx, dir, I.style)
			a.pose = T.rest
			GEN.fx(I.frame, T, "burst", I.ult .. "-gone", v(a.x, 3, 0), v(a.x, 3, 0), I.color, { scale = 1.6 })
		else
			vanish(a)
		end
		I.frame.shot = GEN.shot(I, "vanish", { d }, { yaw = 20, pitch = 30, fill = 0.7, fov = 40, focus = P(I.D, "UpperTorso") })
	else
		GEN.stand(I, GEN.place(I.ctx, cx - dir * 6), T.pose)
		a.ghost = e < 0.68
		GEN.fx(I.frame, T, "burst", I.ult .. "-back", v(a.x, 3, 0), v(a.x, 3, 0), I.color)
		I.frame.shot = GEN.shot(I, "vanish-back", { a, d }, { yaw = -30, pitch = 8, fill = 0.6, fov = 40, focus = P(I.A, "UpperTorso") })
	end
end

function GEN.END.hover(I, e, after)
	local a, d, T, dir, cx = I.a, I.d, I.T, I.dir, I.cx
	if not after then return GEN.blow(I, e) end
	GEN.settle(I, "Levitate")
	a.y = smooth(math.min(1, e / 0.5)) * 3 + math.sin(I.tick * 0.2) * 0.1
	I.frame.aura = I.A
	GEN.fx(I.frame, T, "ground", I.ult .. "-under", nil, v(d.x, 0, 0), I.color, { radius = 2.6, life = 3 })
	I.frame.shot = GEN.shot(I, "hover", { a, d }, { yaw = 30, pitch = -18, fill = 0.66, fov = 44, focus = P(I.A, "UpperTorso") })
end

function GEN.END.stomp(I, e, after)
	local a, d, T, dir, cx = I.a, I.d, I.T, I.dir, I.cx
	if not after then return GEN.blow(I, e) end
	local x = cx + dir * I.push
	GEN.lie(I, x)
	local q = math.min(1, e / 0.35)
	GEN.stand(I, lerp(GEN.place(I.ctx, cx - dir * GEN.reach(I.style)), GEN.place(I.ctx, x - dir * 2.4), q), if e > 0.7 then T.pose else nil)
	if q < 1 then
		a.state, a.vx = "Walking", dir * 2
	elseif e <= 0.7 then
		attack(a, I.ctx.moveData.Moves, role(I.ctx, "Hammer"), e > 0.45)
		if e > 0.45 and e < 0.55 then
			I.frame.quake = I.quake * 1.5
			GEN.fx(I.frame, T, "ground", I.ult .. "-stomp", nil, v(x, 0, 0), I.color, { radius = 3.5, count = 10, life = 2 })
		end
	end
	I.frame.shot = GEN.shot(I, "stomp", { a, d }, { yaw = 26, pitch = -10, fill = 0.66, fov = 44, focus = P(I.A, "UpperTorso") })
end

function GEN.END.bow(I, e, after)
	local a, d, T, dir, cx = I.a, I.d, I.T, I.dir, I.cx
	if not after then return GEN.blow(I, e) end
	GEN.settle(I, if e < 0.25 then T.rest elseif e < 0.7 then "Kneel" else "StandTall")
	I.frame.shot = GEN.shot(I, "bow", { a, d }, { yaw = -36, pitch = 6, fill = 0.62, fov = 38, focus = P(I.A, "Head") })
end

function GEN.END.orbit(I, e, after)
	local a, d, T, dir, cx = I.a, I.d, I.T, I.dir, I.cx
	if not after then return GEN.blow(I, e) end
	GEN.settle(I, T.pose)
	GEN.fx(I.frame, T, "ground", I.ult .. "-orbit", nil, v(a.x, 0, 0), I.color, { radius = 2.2, life = 3 })
	I.frame.shot = GEN.shot(I, "orbit", { a }, { yaw = lerp(-70, 50, e), pitch = 10, fill = 0.86, fov = 40, focus = P(I.A, "Head") })
end

function GEN.END.freeze(I, e, after)
	local a, d, T, dir, cx = I.a, I.d, I.T, I.dir, I.cx
	if not after then
		-- The impact frame held, in black and white.
		local held = if e < 0.15 then e else 0.15
		GEN.blow(I, held)
		I.frame.grade.mono = e >= 0.15
		I.frame.shot = GEN.two(I.ctx, T, I.ult, I.blowShot, dir, a, d, I.preset)
	else
		GEN.square(I.ctx, a, cx, dir, I.style)
		attack(a, I.ctx.moveData.Moves, role(I.ctx, I.blow), e < 0.3)
		if e < 0.3 then
			local q = e / 0.3
			d.x, d.y, d.pose = cx + dir * I.push * q, math.sin((0.15 + q * 0.85) * math.pi) * I.lift, "Launched"
		else
			GEN.lie(I, cx + dir * I.push)
			a.pose = T.rest
		end
		I.frame.shot = GEN.shot(I, "freeze", { a, d }, { yaw = 34, pitch = 12, fill = 0.66, fov = 40, focus = P(I.D, "UpperTorso") })
	end
end

function GEN.END.rain(I, e, after)
	local a, d, T, dir, cx = I.a, I.d, I.T, I.dir, I.cx
	if not after then return GEN.blow(I, e) end
	GEN.settle(I, if e < 0.75 then "Kiai" else T.rest)
	if I.tick % 3 == 0 and e < 0.75 then
		local n = (I.tick * 5) % 7
		GEN.fx(I.frame, T, "line", I.ult .. "-rain" .. I.tick, v(d.x + (n - 3) * 0.5, 10, -1), v(d.x + (n - 3) * 0.3, 0.3, 0), I.color,
			{ life = 0.5 })
	end
	I.frame.shot = GEN.shot(I, "rain", { a, d, spot(d.x, 8, -1) }, { yaw = 12, pitch = 24, fill = 0.58, fov = 46, focus = P(I.D, "UpperTorso") })
end

function GEN.END.walkpast(I, e, after)
	local a, d, T, dir, cx = I.a, I.d, I.T, I.dir, I.cx
	if not after then return GEN.blow(I, e) end
	local x = cx + dir * I.push
	GEN.lie(I, x)
	local q = math.min(1, e / 0.8)
	GEN.stand(I, lerp(GEN.place(I.ctx, cx - dir * GEN.reach(I.style)), GEN.place(I.ctx, x + dir * 3.5), q), T.rest)
	a.z = -2 * math.sin(q * math.pi)
	if q < 1 then a.state, a.vx = "Walking", dir * 2 end
	I.frame.shot = GEN.shot(I, "walkpast", { a, d }, { yaw = -16, pitch = 8, fill = 0.62, fov = 40, focus = P(I.A, "UpperTorso") })
end

function GEN.END.echo(I, e, after)
	local a, d, T, dir, cx = I.a, I.d, I.T, I.dir, I.cx
	if not after then return GEN.blow(I, e) end
	GEN.settle(I, T.pose)
	-- The blow resounds three more times on the target.
	local k = math.floor(e * 4)
	if k >= 1 and k <= 3 and (e * 4) % 1 < 0.3 then
		impact(I.frame, T.id .. "-" .. I.ult .. "-echo" .. k, v(d.x, 1, 0.4), I.color, I.impact * 0.6)
		I.frame.quake = I.quake * 0.6
		d.y = 0.4
	end
	I.frame.shot = GEN.shot(I, "echo", { a, d }, { yaw = 40, pitch = 18, fill = 0.64, fov = 42, focus = P(I.D, "UpperTorso") })
end

function GEN.END.bounce(I, e, after)
	local a, d, T, dir, cx = I.a, I.d, I.T, I.dir, I.cx
	if not after then return GEN.blow(I, e) end
	GEN.settle(I, T.pose)
	local x = cx + dir * I.push
	if e < 0.6 then
		-- Twice off the floor, lower each time.
		local q = e / 0.6
		local hop = if q < 0.6 then math.sin(q / 0.6 * math.pi) * 2.2 else math.sin((q - 0.6) / 0.4 * math.pi) * 0.9
		d.x, d.y, d.pose = x + dir * q * 1.2, hop, "Launched"
		if hop < 0.15 then I.frame.quake = I.quake * 0.8 end
	else
		GEN.lie(I, x + dir * 1.2)
	end
	I.frame.shot = GEN.shot(I, "bounce", { a, d }, { yaw = -28, pitch = 4, fill = 0.6, fov = 42, focus = P(I.D, "UpperTorso") })
end

function GEN.END.flourish(I, e, after)
	local a, d, T, dir, cx = I.a, I.d, I.T, I.dir, I.cx
	if not after then return GEN.blow(I, e) end
	GEN.settle(I, nil)
	local seq = { "SpinKick", "Kick", "PalmStrike" }
	local k = math.floor(e * 4) + 1
	if k <= #seq then
		attack(a, I.ctx.moveData.Moves, role(I.ctx, seq[k]), (e * 4) % 1 > 0.4)
	else
		a.pose = T.pose
	end
	I.frame.shot = GEN.shot(I, "flourish", { a }, { yaw = 30, pitch = 4, fill = 0.82, fov = 40, focus = P(I.A, "UpperTorso") })
end

function GEN.END.seal(I, e, after)
	local a, d, T, dir, cx = I.a, I.d, I.T, I.dir, I.cx
	if not after then return GEN.blow(I, e) end
	GEN.settle(I, T.pose)
	if e >= 0.2 then
		table.insert(I.frame.fx, { key = T.id .. "-" .. I.ult .. "-seal", kind = "kanjiSeal", pos = v(d.x, 0.06, 0), color = I.color,
			text = T.kanji, keep = true })
	end
	I.frame.shot = GEN.shot(I, "seal", { a, d }, { yaw = 6, pitch = 58, fill = 0.62, fov = 44, focus = P(I.D, "UpperTorso") })
end

function GEN.END.exit(I, e, after)
	local a, d, T, dir, cx = I.a, I.d, I.T, I.dir, I.cx
	if not after then return GEN.blow(I, e) end
	local x = cx + dir * I.push
	GEN.lie(I, x)
	if e < 0.55 then
		local start = GEN.place(I.ctx, cx - dir * GEN.reach(I.style))
		GEN.stand(I, start, T.rest)
		a.z = 3 * smooth(e / 0.55)
		a.lookDir = v(0, 0, 1)
		a.state, a.vx = "Walking", 0
		I.frame.shot = GEN.shot(I, "exit", { a, d }, { yaw = -8, pitch = 6, fill = 0.6, fov = 40, focus = P(I.A, "Head") })
	else
		vanish(a)
		I.frame.shot = GEN.shot(I, "exit-alone", { d }, { yaw = 24, pitch = 14, fill = 0.66, fov = 38, focus = P(I.D, "UpperTorso") })
	end
end

function GEN.END.slowmo(I, e, after)
	local a, d, T, dir, cx = I.a, I.d, I.T, I.dir, I.cx
	if not after then
		-- the blow at a quarter speed, in silence
		GEN.blow(I, e * 0.3)
		I.frame.speedLines = I.color
		I.frame.shot = GEN.two(I.ctx, T, I.ult, I.blowShot, dir, a, d, I.preset, { fill = lerp(0.7, 0.9, e) })
	else
		GEN.square(I.ctx, a, cx, dir, I.style)
		attack(a, I.ctx.moveData.Moves, role(I.ctx, I.blow), e < 0.25)
		if e < 0.3 then
			local q = 0.3 + e / 0.3 * 0.7
			d.x, d.y, d.pose = cx + dir * I.push * smooth(q), math.sin(q * math.pi) * I.lift, "Launched"
			if e < 0.08 then I.frame.quake = I.quake * 1.4 end
		else
			GEN.lie(I, cx + dir * I.push)
			a.pose = T.pose
		end
		I.frame.shot = GEN.shot(I, "slowmo", { a, d }, { yaw = -44, pitch = 10, fill = 0.62, fov = 40, focus = P(I.A, "UpperTorso") })
	end
end

-- Plays the theme's ending of an ultimate from its final tick F: the blow (B ticks), then the
-- rest. o: blow, push, lift, blowShot, preset, impact, burst, quake.
function GEN.ending(ctx, frame, T, a, d, tick, dir, ult, kind, F, o)
	local I = GEN.scene(ctx, frame, T, a, d, tick, dir, ult, kind)
	for k, value in o do I[k] = value end
	I.style = T[string.lower(kind)]
	I.q = tick - F
	local style = T.finish[string.lower(kind)]
	if tick < F + I.B then
		GEN.END[style](I, progress(tick, F, F + I.B), false)
	else
		I.long = I.data.Length - F - I.B >= 30
		GEN.END[style](I, progress(tick, F + I.B, I.data.Length), true)
	end
end

-- Plays the theme's opening of an ultimate over ticks [0, to): home is where the attacker
-- stands when the next part begins.
function GEN.opening(ctx, frame, T, a, d, tick, dir, ult, kind, to, home)
	local I = GEN.scene(ctx, frame, T, a, d, tick, dir, ult, kind)
	I.long = to >= 40
	GEN.OPEN[T.open[string.lower(kind)]](I, progress(tick, 0, to), home)
end

-- ---------------------------------------------------------------- R

function GEN.Rush(T)
	return function(ctx, frame, a, d, tick, dir)
		local cin = ctx.cin
		local data = ctx.moveData.Cinematics[cin.move]
		local A, D = cin.attacker, cin.defender
		local color = ctx.characters[A].Energy
		local cx = center(ctx, d)
		local H, F = data.Hits, data.FinalTick
		local style = T.rush
		frame.grade[T.grade] = true
		local k = hitsBefore(H, tick)
		local beat = if k > 0 then tick - H[k] else 0
		if tick < H[1] then
			-- The kit's own opening.
			d.x, d.state = cx, "Hitstun"
			GEN.opening(ctx, frame, T, a, d, tick, dir, "rush", "Rush", H[1], GEN.place(ctx, cx - dir * (GEN.reach(style) + 1.5)))
		elseif tick < H[#H] + 4 then
			GEN.strike(ctx, frame, T, style, a, d, k, beat, tick, cx, dir, color, "rush")
			local part = if k <= 4 then "a" elseif k <= 8 then "b" else "c"
			local i = if k <= 4 then 1 elseif k <= 8 then 2 else 3
			frame.shot = GEN.two(ctx, T, "rush", "blows-" .. part, dir, a, d, i)
		elseif tick < F then
			-- The last breath before the final blow.
			local p = progress(tick, H[#H] + 4, F)
			GEN.square(ctx, a, cx, dir, style)
			attack(a, ctx.moveData.Moves, role(ctx, "Finale"), false)
			d.x, d.state, d.y = cx, "Hitstun", 0
			GEN.fx(frame, T, "ground", "rush-charge", nil, v(a.x, 0, 0), color, { radius = 1.6 })
			frame.shot = GEN.two(ctx, T, "rush", "charge", dir, a, d, 4, { fill = lerp(0.72, 0.86, p) })
		else
			-- The kit's own ending.
			GEN.ending(ctx, frame, T, a, d, tick, dir, "rush", "Rush", F, { B = 16, blow = "Finale", push = 1.2, lift = 2.2,
				blowShot = "final", preset = 5, impact = 3, burst = 2, quake = 0.6 })
		end
	end
end

-- ---------------------------------------------------------------- ÉVEIL

function GEN.Awaken(T)
	return function(ctx, frame, a, d, tick, dir, color)
		local cin = ctx.cin
		local data = ctx.moveData.Cinematics[cin.move]
		local A = cin.attacker
		local cx = center(ctx, d)
		local H, F = data.Hits, data.FinalTick
		local style = T.awaken
		frame.grade.crimson, frame.grade[T.grade] = false, true
		if tick < F then d.x, d.y, d.state = cx, 0, "Hitstun" end
		local k = hitsBefore(H, tick)
		if tick < 48 then
			-- The kit's own opening, its kanji behind it at first.
			if tick < 24 then frame.kanjiBack = T.kanji end
			GEN.opening(ctx, frame, T, a, d, tick, dir, "eveil", "Awaken", 48, GEN.place(ctx, cx - dir * 6.5))
		elseif tick < H[1] then
			local p = progress(tick, 48, H[1])
			a.x, a.facing, a.z, a.state, a.vx = lerp(GEN.place(ctx, cx - dir * 6.5), GEN.place(ctx, cx - dir * GEN.reach(style)), smooth(p)),
				dir, 0, "Walking", dir * 3
			GEN.fx(frame, T, "line", "eveil-reach", v(a.x, 3, 0), v(cx, 3, 0), color)
			frame.shot = GEN.two(ctx, T, "eveil", "approach", dir, a, d, 6)
		elseif tick < H[4] then
			GEN.strike(ctx, frame, T, style, a, d, k, tick - H[k], tick, cx, dir, color, "eveil")
			frame.shot = GEN.two(ctx, T, "eveil", "blows-a", dir, a, d, 7)
		elseif tick < H[#H] + 4 then
			GEN.strike(ctx, frame, T, style, a, d, k, tick - H[k], tick, cx, dir, color, "eveil")
			frame.shot = GEN.two(ctx, T, "eveil", "blows-b", dir, a, d, 8)
		elseif tick < F then
			-- Held in the air, the final blow drawn back.
			local p = progress(tick, H[#H] + 4, F)
			GEN.square(ctx, a, cx, dir, style)
			attack(a, ctx.moveData.Moves, role(ctx, "Finale"), false)
			d.y, d.pose = 1.6 + math.sin(p * math.pi) * 1.2, "Launched"
			GEN.fx(frame, T, "ground", "eveil-hold", nil, v(cx, 0, 0), color, { radius = 2.6 })
			frame.shot = GEN.two(ctx, T, "eveil", "hold", dir, a, d, 9, { fill = lerp(0.66, 0.82, p) })
		else
			if tick < F + 16 then GEN.fx(frame, T, "ground", "eveil-world", nil, v(cx, 0, 0), color, { radius = 4.5, count = 10 }) end
			GEN.ending(ctx, frame, T, a, d, tick, dir, "eveil", "Awaken", F, { B = 16, blow = "Finale", push = 1.6, lift = 2,
				blowShot = "final", preset = 10, impact = 3.4, burst = 2.4, quake = 0.8 })
			if tick >= F + 16 then
				frame.title = { text = GEN.moveName(ctx, T, "Awaken"), color = color, sub = T.kanji .. " · " .. kitOf(ctx).Name }
			end
		end
	end
end

-- ---------------------------------------------------------------- PORTE (the third ultimate)

function GEN.Gate(T)
	return function(ctx, frame, a, d, tick, dir)
		local cin = ctx.cin
		local data = ctx.moveData.Cinematics[cin.move]
		local A = cin.attacker
		local color = ctx.characters[A].Energy
		local cx = center(ctx, d)
		local F = data.FinalTick
		local style = T.gate
		frame.grade[T.grade] = true
		if tick < F then d.x, d.y, d.state = cx, 0, "Hitstun" end
		local far = GEN.place(ctx, cx - dir * 4.4)
		if tick < 70 then
			-- The theme takes the whole arena, then the kit's own opening.
			d.state = "Idle"
			if tick < 30 then
				GEN.fx(frame, T, "ground", "gate-world", nil, v((far + cx) / 2, 0, 0), color, { radius = 9, count = 14, life = 3 })
			end
			GEN.opening(ctx, frame, T, a, d, tick, dir, "gate", "Gate", 70, far)
		elseif tick < data.Hits[1] - 6 then
			local p = progress(tick, 70, data.Hits[1] - 6)
			a.x, a.facing, a.state, a.vx = lerp(far, GEN.place(ctx, cx - dir * GEN.reach(style)), p), dir, "Walking", dir * 2
			if tick % 6 == 0 then
				local n = (tick * 7) % 11
				GEN.fx(frame, T, "line", "gate-rain" .. tick, v(cx + (n - 5) * 0.7, 9, n % 3 - 1), v(cx + (n - 5) * 0.4, 0, 0), color,
					{ life = 0.7 })
			end
			frame.shot = GEN.two(ctx, T, "gate", "advance", dir, a, d, 2)
		elseif tick < data.PromptTicks[1] - 6 then
			local k = hitsBefore(data.Hits, tick)
			if k == 0 then
				GEN.square(ctx, a, cx, dir, style)
				attack(a, ctx.moveData.Moves, role(ctx, T.blows[1]), false)
			else
				GEN.strike(ctx, frame, T, style, a, d, k, tick - data.Hits[k], tick, cx, dir, color, "gate")
			end
			frame.shot = GEN.two(ctx, T, "gate", "blows", dir, a, d, 3)
		elseif tick < F then
			GEN.square(ctx, a, cx, dir, style)
			d.x, d.y, d.pose = cx, 0, nil
			attack(a, ctx.moveData.Moves, role(ctx, "Smash"), false)
			frame.grade.mono = tick >= data.PromptTicks[1] - 4
			frame.shot = GEN.two(ctx, T, "gate", "draw", dir, a, d, 4, { fill = lerp(0.78, 0.94,
				progress(tick, data.PromptTicks[1] - 6, F)) })
		else
			if tick < F + 22 then GEN.fx(frame, T, "ground", "gate-break", nil, v(cx, 0, 0), color, { radius = 6, count = 12 }) end
			GEN.ending(ctx, frame, T, a, d, tick, dir, "gate", "Gate", F, { B = 22, blow = "Smash", push = 1.4, lift = 2.6,
				blowShot = "break", preset = 5, impact = 3.8, burst = 2.6, quake = 1 })
			if tick >= F + 22 then
				local t = kitOf(ctx).GateTitle
				frame.title = { text = t.text, color = color, sub = t.sub }
			end
		end
	end
end

-- ---------------------------------------------------------------- COUP FATAL

function GEN.Fatal(T)
	return function(ctx, frame, a, d, tick, dir)
		local cin = ctx.cin
		local data = ctx.moveData.Cinematics[cin.move]
		local A = cin.attacker
		local color = ctx.characters[A].Energy
		local cx = center(ctx, d)
		local F = data.FinalTick
		local style = T.fatal
		frame.grade[T.grade] = true
		if tick < F then d.x, d.y, d.state = cx, 0, "Hitstun" end
		if tick < 70 then
			-- The kit's own opening, over its burning seal; the world turns crimson.
			table.insert(frame.fx, { key = T.id .. "-fatal-seal", kind = "kanjiSeal", pos = v(cx - dir * 6.5, 0.06, 0), color = color,
				text = T.kanji, keep = true })
			frame.grade.crimson = tick >= 40
			GEN.opening(ctx, frame, T, a, d, tick, dir, "fatal", "Fatal", 70, GEN.place(ctx, cx - dir * 5.5))
		elseif tick < 104 then
			-- Three blows of its own way of fighting: the target is taken.
			local hits = { 74, 84, 94 }
			local k = hitsBefore(hits, tick)
			if k == 0 then
				GEN.square(ctx, a, cx, dir, style)
				a.state, a.vx = "Walking", dir * 2
			else
				GEN.strike(ctx, frame, T, style, a, d, k, tick - hits[k], tick, cx, dir, color, "fatal")
			end
			frame.shot = GEN.two(ctx, T, "fatal", "take", dir, a, d, 7)
		elseif tick < F then
			GEN.square(ctx, a, cx, dir, style)
			d.x, d.y, d.pose = cx, 0, nil
			attack(a, ctx.moveData.Moves, role(ctx, "Finale"), false)
			GEN.fx(frame, T, "ground", "fatal-draw", nil, v(a.x, 0, 0), color, { radius = 2 })
			frame.speedLines = if tick >= 130 then color else nil
			frame.shot = GEN.two(ctx, T, "fatal", "draw", dir, a, d, 8, { fill = lerp(0.74, 0.92, progress(tick, 104, F)) })
		else
			GEN.ending(ctx, frame, T, a, d, tick, dir, "fatal", "Fatal", F, { B = 24, blow = "Finale", push = 0.6, lift = 1.8,
				blowShot = "blow", preset = 9, impact = 3.4, burst = 2.6, quake = 0.8 })
			if tick >= F + FATAL_TITLE then
				local name = GEN.moveName(ctx, T, "Fatal")
				frame.title = if cin.finish then { text = "K.O.", color = color, sub = name } else { text = name, color = color, sub = "COUP FATAL" }
			end
		end
	end
end

-- ---------------------------------------------------------------- K.O.

function GEN.KO(T)
	return function(ctx, frame, W, L, w, l, t, side)
		local color = ctx.characters[W].Energy
		local dir = -side
		frame.grade[T.grade] = t >= 30
		w.x, w.z = l.x + side * 3.4, -2.8
		w.lookDir = v(-side * 0.5, 0, 0.85)
		w.pose = T.rest
		if t < 30 then
			frame.grade.mono, frame.hideTitle = true, true
			l.y, l.pose = lerp(4, 0, t / 22), if t < 22 then "Launched" else "DownFace"
			frame.shot = frameOn("ko-" .. T.id .. "-fall", dir, { l }, { yaw = -24 - T.seed, pitch = -2, fill = 0.36, fov = 40, lift = 1.2 })
			return frame
		end
		l.y, l.pose = 0, "DownFace"
		if t < 70 then
			GEN.fx(frame, T, "ground", "ko-mark", nil, v(l.x, 0, 0), color, { radius = 2.3, life = 4 })
			if t < 40 then GEN.fx(frame, T, "burst", "ko-burst", v(w.x, 3, w.z), v(l.x, 1, 0), color) end
			frame.shot = frameOn("ko-" .. T.id .. "-mark", dir, { l, w }, { yaw = 30, pitch = 24 + T.seed, fill = 0.5, fov = 44 })
		elseif t < 112 then
			frame.shot = frameOn("ko-" .. T.id .. "-floor", dir, { l }, { yaw = 24, pitch = 6, fill = 0.66, fov = 40, focus = P(L, "Head") })
		elseif t < 150 then
			w.pose = T.pose
			frame.shot = frameOn("ko-" .. T.id .. "-stand", dir, { w }, { yaw = -34, pitch = -28, fill = 0.85, fov = 46, focus = P(W, "Head") })
		else
			w.pose = T.pose
			if t >= 188 then koEnd(ctx, frame, W, color) end
			frame.shot = frameOn("ko-" .. T.id .. "-wide", dir, { w, l }, { yaw = -20, pitch = 12, fill = 0.36, fov = 40 })
		end
		return frame
	end
end

-- Registers a themed kit: its three ultimates, its COUP FATAL and its K.O. scene.
function GEN.add(name, T)
	GEN.THEMES[name] = T
	KIT[name] = { Rush = GEN.Rush(T), Awaken = GEN.Awaken(T), Gate = GEN.Gate(T) }
	FATAL[name] = GEN.Fatal(T)
	KO[name] = GEN.KO(T)
end
Director.THEMES = GEN.THEMES
Director.OPEN, Director.END = GEN.OPEN, GEN.END
-- ASURA 阿: KAI out of the Gate of Heaven with four arms. A gatling of four fists (R), the target
-- thrown up higher at every blow (ÉVEIL), swung round at the end of his arms (PORTE), seized and
-- crushed (FATAL). Black and gold grade; golden fists of ki, a halo of four arms, a burning seal.
GEN.add("ASURA", {
	turn = { ["eveil-blows-b"] = 30, ["eveil-meditate"] = 30, ["fatal-blow"] = 30, ["fatal-stride"] = 30 },
	open = { rush = "slam", awaken = "meditate", gate = "silhouette", fatal = "stride" },
	finish = { rush = "stomp", awaken = "crater", gate = "blowaway", fatal = "pin" },
	id = "asura", grade = "asura", kanji = "阿", pose = "Roar", rest = "StandTall", seed = 2, step = 5, quake = true,
	rush = "gatling", awaken = "juggle", gate = "swing", fatal = "grapple",
	blows = { "Cross", "Uppercut", "Hammer", "Smash", "BodyBlow", "SpinKick", "Elbow" },
	fx = { line = "asuraFist", burst = "asuraHalo", ground = "asuraSeal" },
	names = { Rush = "GATLING DES QUATRE BRAS", Awaken = "MILLE BRAS", Fatal = "阿修羅 · COLÈRE FINALE" },
})

-- Wilhem's third sheet. Each kit: its grade, its own effects, its archetype for each ultimate.
-- RAIJIN 雷: the spear's reach, thrust after thrust, a step further in each time (R); the
-- storm strikes down from above (ÉVEIL); pillars of lightning called on the target (PORTE);
-- the sentence from every side (FATAL).
GEN.add("RAIJIN", {
	turn = { ["fatal-take"] = 30, ["gate-charge"] = -30 },
	open = { rush = "descend", awaken = "gather", gate = "charge", fatal = "backturn" },
	finish = { rush = "passthrough", awaken = "skyward", gate = "rain", fatal = "turnaway" },
	id = "raijin", grade = "storm", kanji = "雷", pose = "StandTall", rest = "StandTall", seed = 0, step = 11,
	rush = "thrust", awaken = "rain", gate = "pillar", fatal = "lunge",
	blows = { "Elbow", "Cross", "SpinKick", "Kick", "Uppercut", "Smash" },
	fx = { line = "spearBolt", burst = "thunderBurst", ground = "stormRing" },
})

-- YUKINA 雪: the target frozen still while she flows round it (R); ice shards from afar
-- (ÉVEIL); the frozen puppet jerked on its threads of frost (PORTE); the last waltz (FATAL).
GEN.add("YUKINA", {
	turn = { ["fatal-storm"] = 30, ["gate-walkpast"] = -30, ["rush-blows-a"] = 30, ["rush-freeze"] = 30 },
	open = { rush = "spin", awaken = "kneel", gate = "levitate", fatal = "storm" },
	finish = { rush = "freeze", awaken = "orbit", gate = "walkpast", fatal = "bow" },
	id = "yukina", grade = "frost", kanji = "雪", pose = "WindGather", rest = "StandTall", seed = 1, step = 11,
	rush = "freeze", awaken = "zone", gate = "dance", fatal = "orbit",
	blows = { "SpinKick", "Kick", "Cross", "AirKick", "Elbow", "Sweep" },
	fx = { line = "iceShard", burst = "frostBloom", ground = "iceGarden" },
})

-- VENOM 毒: the predator out of the shadows, in front, behind (R); the poisoned target
-- staggering like a puppet (ÉVEIL); the pounce from every side (PORTE); acid rain (FATAL).
GEN.add("VENOM", {
	turn = { ["eveil-target"] = -30, ["gate-blink"] = 30, ["rush-vanish-back"] = 30 },
	open = { rush = "emerge", awaken = "target", gate = "blink", fatal = "silhouette" },
	finish = { rush = "vanish", awaken = "turnaway", gate = "passthrough", fatal = "rain" },
	id = "venom", grade = "toxic", kanji = "毒", pose = "Roar", rest = "StandTall", seed = 14, step = 11,
	rush = "stalk", awaken = "dance", gate = "lunge", fatal = "rain",
	blows = { "Jab", "Cross", "Elbow", "BodyBlow", "Uppercut", "SpinKick" },
	fx = { line = "venomClaw", burst = "venomCloud", ground = "toxicPool" },
})

-- GORAN 剛: suplexes from side to side (R); the stomps make the ring jump (ÉVEIL); thrown to the
-- sky (PORTE); the giant swing (FATAL).
GEN.add("GORAN", {
	turn = { ["gate-blows"] = 30, ["gate-leap"] = 30, ["rush-blows-a"] = 30, ["rush-blows-b"] = 30, ["rush-blows-c"] = -30, ["rush-charge"] = 30 },
	open = { rush = "charge", awaken = "slam", gate = "leap", fatal = "kneel" },
	finish = { rush = "crater", awaken = "stomp", gate = "bounce", fatal = "blowaway" },
	id = "goran", grade = "titan", kanji = "剛", pose = "Colossus", rest = "StandTall", seed = 4, step = 7, quake = true,
	rush = "grapple", awaken = "beat", gate = "juggle", fatal = "swing",
	blows = { "BodyBlow", "Hammer", "Smash", "Uppercut", "Elbow" },
	fx = { line = "titanGrip", burst = "slamQuake", ground = "titanRing" },
})

-- ASTER 星: the target floats up, higher at every blow (R); he orbits it (ÉVEIL); the event
-- horizon pulls it in (PORTE); falling stars from every side (FATAL).
GEN.add("ASTER", {
	turn = { ["eveil-blows-b"] = -30, ["fatal-meditate"] = 30, ["fatal-take"] = -30, ["gate-advance"] = 30 },
	open = { rush = "levitate", awaken = "descend", gate = "gather", fatal = "meditate" },
	finish = { rush = "skyward", awaken = "hover", gate = "orbit", fatal = "crater" },
	id = "aster", grade = "cosmos", kanji = "星", pose = "Levitate", rest = "StandTall", seed = 5, step = 5,
	rush = "juggle", awaken = "orbit", gate = "pull", fatal = "crossfire",
	blows = { "PalmStrike", "AirKick", "Uppercut", "AirKick2", "Smash" },
	fx = { line = "gravityPull", burst = "starCollapse", ground = "gravityWell" },
})

-- HIBIKI 響: the target hops on her beat (R); waves of sound from every side (ÉVEIL); the
-- wall of sound from afar (PORTE); the last dance on her rhythm (FATAL).
GEN.add("HIBIKI", {
	turn = { ["eveil-freeze"] = 30, ["fatal-charge"] = 30, ["fatal-walkpast"] = -30, ["gate-blows"] = 30, ["rush-blows-c"] = 30 },
	open = { rush = "kata", awaken = "spin", gate = "slam", fatal = "charge" },
	finish = { rush = "echo", awaken = "freeze", gate = "stomp", fatal = "walkpast" },
	id = "hibiki", grade = "sonic", kanji = "響", pose = "Kiai", rest = "StandTall", seed = 6, step = 7,
	rush = "beat", awaken = "crossfire", gate = "zone", fatal = "dance",
	blows = { "Kick", "SpinKick", "Jab", "Cross", "Sweep" },
	fx = { line = "soundWave", burst = "soundRing", ground = "beatRing" },
})

-- MARION 糸: the puppet dances on its threads (R); swung round at the end of them (ÉVEIL); the
-- ball of the puppets around it (PORTE); lifted higher and higher (FATAL).
GEN.add("MARION", {
	turn = { ["eveil-approach"] = 30, ["eveil-blows-a"] = 30, ["eveil-final"] = 30, ["fatal-spin"] = 30, ["fatal-take"] = 30, ["gate-backturn"] = 30, ["gate-draw"] = 30 },
	open = { rush = "target", awaken = "levitate", gate = "backturn", fatal = "spin" },
	finish = { rush = "flourish", awaken = "pin", gate = "vanish", fatal = "hover" },
	id = "marion", grade = "puppet", kanji = "糸", pose = "WindGather", rest = "StandTall", seed = 7, step = 5,
	rush = "dance", awaken = "swing", gate = "orbit", fatal = "juggle",
	blows = { "PalmStrike", "Jab", "Cross", "SpinKick" },
	fx = { line = "threads", burst = "puppetBurst", ground = "stageRing" },
})

-- KAZAN 鎖: the target swung round on the chain (R); the chain's hook thrown straight (ÉVEIL);
-- seized and slammed (PORTE); dragged in on the chains (FATAL).
GEN.add("KAZAN", {
	turn = { ["eveil-blows-b"] = 30, ["eveil-charge"] = 30, ["gate-advance"] = 30, ["gate-break"] = -30, ["gate-target"] = -55, ["gate-target-found"] = 30, ["rush-stride"] = 30 },
	open = { rush = "stride", awaken = "charge", gate = "target", fatal = "slam" },
	finish = { rush = "pin", awaken = "blowaway", gate = "crater", fatal = "stomp" },
	id = "kazan", grade = "iron", kanji = "鎖", pose = "Roar", rest = "StandTall", seed = 8, step = 11,
	rush = "swing", awaken = "thrust", gate = "grapple", fatal = "pull",
	blows = { "Cross", "Hammer", "Smash", "Elbow" },
	fx = { line = "chainLine", burst = "ironBurst", ground = "prisonRing" },
})

-- KUREN 血: blood rains on the target (R); lances from every side (ÉVEIL); the vampire out of
-- the dark (PORTE); one lance straight through (FATAL).
GEN.add("KUREN", {
	open = { rush = "blink", awaken = "emerge", gate = "path", fatal = "descend" },
	finish = { rush = "rain", awaken = "vanish", gate = "turnaway", fatal = "passthrough" },
	turn = { ["eveil-approach"] = 30, ["fatal-blow"] = 30, ["rush-blows-c"] = 30 },
	id = "kuren", grade = "blood", kanji = "血", pose = "KiBeamDown", rest = "StandTall", seed = 9, step = 7,
	rush = "rain", awaken = "lunge", gate = "stalk", fatal = "thrust",
	blows = { "Cross", "Elbow", "Uppercut", "SpinKick", "PalmStrike" },
	fx = { line = "bloodSpear", burst = "bloodBloom", ground = "bloodPool" },
})

-- SYLVA 森: the roots lift the prey (R); the vines drag it in (ÉVEIL); thorns from every side
-- (PORTE); the huntress out of the leaves (FATAL).
GEN.add("SYLVA", {
	turn = { ["eveil-blows-a"] = 30, ["eveil-final"] = -30, ["fatal-target"] = -55, ["gate-blows"] = 30, ["rush-walkpast"] = 30 },
	open = { rush = "path", awaken = "backturn", gate = "emerge", fatal = "target" },
	finish = { rush = "walkpast", awaken = "rain", gate = "skyward", fatal = "exit" },
	id = "sylva", grade = "wild", kanji = "森", pose = "WindGather", rest = "StandTall", seed = 10, step = 5,
	rush = "roots", awaken = "pull", gate = "crossfire", fatal = "stalk",
	blows = { "Kick", "SpinKick", "Cross", "Sweep", "AirKick" },
	fx = { line = "vines", burst = "thornBurst", ground = "roots" },
})

-- ELIAN 癒: pillars of light on the target (R); held still by a seal of light (ÉVEIL); the
-- chime of the light, the target hopping on it (PORTE); the light from afar (FATAL).
GEN.add("ELIAN", {
	turn = { ["eveil-silhouette"] = 30, ["fatal-orbit"] = -30, ["gate-draw"] = 30, ["rush-blows-a"] = 30, ["rush-blows-b"] = 30, ["rush-meditate"] = 30 },
	open = { rush = "meditate", awaken = "silhouette", gate = "descend", fatal = "levitate" },
	finish = { rush = "hover", awaken = "bow", gate = "seal", fatal = "orbit" },
	id = "elian", grade = "holy", kanji = "癒", pose = "Kiai", rest = "StandTall", seed = 11, step = 7,
	rush = "pillar", awaken = "freeze", gate = "beat", fatal = "zone",
	blows = { "PalmStrike", "Uppercut", "Cross", "Smash" },
	fx = { line = "lightRay", burst = "lightPillar", ground = "haloRing" },
})

-- NOVA 機: the drones fire from every side (R); an orbital beam (ÉVEIL); a barrage from the sky
-- (PORTE); the gauntlets' machine-gun (FATAL).
GEN.add("NOVA", {
	turn = { ["eveil-eyes"] = 30, ["fatal-slowmo"] = -30, ["gate-storm"] = 30, ["rush-blows-b"] = 30 },
	open = { rush = "clones", awaken = "eyes", gate = "storm", fatal = "blink" },
	finish = { rush = "orbit", awaken = "passthrough", gate = "hover", fatal = "slowmo" },
	id = "nova", grade = "tech", kanji = "機", pose = "ArmsCrossed", rest = "StandTall", seed = 2, step = 11,
	rush = "crossfire", awaken = "pillar", gate = "rain", fatal = "gatling",
	blows = { "Jab", "Cross", "BodyBlow", "Smash", "Uppercut" },
	fx = { line = "droneShot", burst = "dronePulse", ground = "droneRing" },
})

-- The K.O. scene of the winner's kit. `t` runs from 0 to KO_SCENE ticks.
local function koScene(ctx, winner, loser, w, l, t)
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

-- ===================================================================== LIVING CAMERA

--[[
	No shot is a still: the camera drifts round its subject (DRIFT_YAW degrees a second, one way
	or the other) and pushes in a little (DRIFT_PUSH of the distance a second) for as long as
	the shot lasts, like the slow camera moves of animated films. Composed shots only (the
	macro shots aimed at rig parts stay as drawn); never under the deck.
]]
local DRIFT_YAW, DRIFT_PUSH, DRIFT_MAX = 6, 0.05, 1.6
local function drift(ctx, frame, tick)
	local s = frame and frame.shot
	if not s or not s.from.position or not s.to.position then return end
	local anchors = ctx.anchors
	if anchors.driftShot ~= s.name then anchors.driftShot, anchors.driftStart = s.name, tick end
	local t = math.clamp((tick - anchors.driftStart) / 60, 0, DRIFT_MAX)
	local sign = if #s.name % 2 == 0 then 1 else -1
	local f, to = s.from.position, s.to.position
	local dx, dy, dz = f.x - to.x, f.y - to.y, (f.z or 0) - (to.z or 0)
	local angle = math.rad(DRIFT_YAW * t * sign)
	local c, n = math.cos(angle), math.sin(angle)
	local k = 1 - DRIFT_PUSH * t
	local x, z = dx * c - dz * n, dx * n + dz * c
	s.from = At(v(to.x + x * k, math.max(0.45, to.y + dy * k), (to.z or 0) + z * k))
end
Director.drift = drift

--[[
	Clean staging, after every frame of a cinematic:
	  speed   a body that moves faster than SPEED studs a tick inside a shot is drawn with its
	          afterimages (ghost): a blink, a throw, a dive read as speed, never as a jump;
	  room    standing on the deck, the attacker never stands closer than ROOM studs to the
	          target (block bodies sink into each other below that): it steps back along the
	          line between them.
]]
local SPEED, ROOM = 0.9, 2.8
local function standing(view)
	return (view.y or 0) < 0.8 and not lying(view) and view.pose ~= "Launched"
end
local function clean(ctx, frame, a, d, tick)
	local anchors = ctx.anchors
	local dx, dz = a.x - d.x, (a.z or 0) - (d.z or 0)
	local gap = math.sqrt(dx * dx + dz * dz)
	if standing(a) and standing(d) and gap > 0.05 and gap < ROOM and not a.ghost then
		local k = ROOM / gap
		a.x = d.x + dx * k
		if a.z then a.z = (d.z or 0) + dz * k end
	end
	anchors.moved = anchors.moved or {}
	local shot = frame.shot and frame.shot.name
	for slot, view in { a, d } do
		local last = anchors.moved[slot]
		if last and last.shot == shot and tick > last.tick and tick - last.tick <= 3 and (view.y or 0) < 50 and last.y < 50 then
			local step = math.sqrt((view.x - last.x) ^ 2 + ((view.y or 0) - last.y) ^ 2 + ((view.z or 0) - last.z) ^ 2) / (tick - last.tick)
			if step > SPEED then view.ghost = true end
		end
		if not last or tick ~= last.tick then
			anchors.moved[slot] = { x = view.x, y = view.y or 0, z = view.z or 0, tick = tick, shot = shot }
		end
	end
end

function Director.ko(ctx, winner, loser, w, l, t)
	local frame = koScene(ctx, winner, loser, w, l, t)
	drift(ctx, frame, t)
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
	if data.Type == "Fatal" then
		local scene = kit and FATAL[kit.Name] or FATAL.KAI
		scene(ctx, frame, a, d, ctx.tick, dir)
	elseif data.Type == "Awaken" then
		awakening(ctx, frame, a, d, ctx.tick, dir)
	elseif own and own[data.Type] then
		own[data.Type](ctx, frame, a, d, ctx.tick, dir)
	elseif data.Type == "Gate" then
		kaiten(ctx, frame, a, d, ctx.tick, dir)
	else
		rush(ctx, frame, a, d, ctx.tick, dir)
	end
	clean(ctx, frame, a, d, ctx.tick)
	drift(ctx, frame, ctx.tick)
	return frame
end

-- Is a match-winning K.O. being shown? Returns winner, loser and the scene tick.
function Director.victoryScene(world, config)
	if world.training or world.cinematic then return nil end
	local winner = world.winner
	if not winner or winner <= 0 then return nil end
	local w = world.fighters[winner]
	if not w then return nil end
	-- A relay (simulation: world.teams; snapshot: each fighter's team and teamIndex): only
	-- when the loser's team has nobody left; else the last round to win.
	local l = world.fighters[3 - winner]
	local team = world.teams and world.teams[3 - winner]
	local size = if team then #team.kits elseif l and l.team then #l.team else nil
	local index = if team then team.index elseif l then l.teamIndex else nil
	if size then
		if (index or 1) <= size then return nil end
	elseif w.wins < config.RoundsToWin then
		return nil
	end
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
