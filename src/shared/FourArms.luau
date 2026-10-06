--[[
	ASURA's second pair of arms (pure Luau: no Roblox API, no require). The block body and every
	avatar get two extra jointed arms (RigBuilder.addFourArms): an upper arm on a shoulder joint
	under the real shoulders, a forearm on an elbow joint, and a wrapped fist. This module
	decides, for one rendered frame, the angles of those joints from the fighter's view (state,
	move, move frame) and the clock; the client applies them (AnimationController) and the tests
	check them (tests/Animation.test.luau: they rise in guard, strike during attacks, piston in
	the gatling, never go through the body).

	Angles in degrees. Shoulder: pitch (positive swings the arm forward, toward -Z, the front of
	the rig), yaw (positive turns it inward, across the chest), roll (positive lifts it out to
	its own side), twist (about the arm itself: 90 turns the elbow so that an arm held out to
	the side folds its forearm UP, the statue's guard). Elbow: bend (positive folds the
	forearm). Rest = hanging down.

	  FourArms.SPEC                         -- joints and segments (torso space, studs)
	  FourArms.pose(view, now, moves)       -- { Left = { pitch, yaw, roll, bend }, Right = ... }
	  FourArms.solve(spec, arms)            -- elbow and fist positions in torso space (tests)
]]
local FourArms = {}

-- The extra shoulders: out of his flanks, on each side of the ribs under the real shoulders
-- (Wilhem: "ils sortent des côtés"); x is a multiple of the torso's half width, so it fits any
-- body; y and z in studs, scaled the same way.
FourArms.SPEC = {
	shoulder = { x = 1.1, y = -0.55, z = 0.05 },
	upper = 1.2, -- shoulder to elbow
	fore = 0.95, -- elbow to the centre of the fist
}

-- Key poses of each arm ({ pitch, yaw, roll, bend, twist }); Left and Right are mirrored by
-- the client (yaw, roll and twist take the side's sign).
local KEYS = {
	-- The guard of the deity statues, in two tiers (Wilhem: « ses bras, la deuxième paire,
	-- rends-la agréable »: beside the head they tangled with the real guard): the real arms
	-- guard the face, the extra pair stands lower and wider, out to the sides, forearms rising
	-- a little, fists at his belt and ahead of his hips. It breathes between the two keys.
	guard = { 30, 5, 65, 60, 30 },
	guardHigh = { 34, 6, 62, 66, 30 },
	-- An attack: drawn back, then thrown straight at the target.
	draw = { 20, 10, 60, 110, 0 },
	strike = { 88, 0, 32, 4, 0 },
	-- The gatling: pistons between pulled and thrown, out of phase.
	piston = { 70, 4, 42, 100, 0 },
	thrown = { 92, 2, 30, 2, 0 },
	-- The block: fists brought in front of the flanks, under the real guard.
	block = { 50, 30, 60, 90, 0 },
	-- Hit: flung back and out.
	hit = { -24, 0, 70, 30, 0 },
	-- Down: limp on the floor.
	limp = { 4, 0, 50, 12, 0 },
	-- Airborne: spread high like wings.
	air = { 100, 0, 70, 34, 0 },
	-- Running: swung back, ready.
	run = { -10, 0, 44, 70, 0 },
	-- Victory / taunt: all raised to the sky.
	sky = { 168, 0, 30, 14, 0 },
	-- The scenes of his ultimates (CinematicDirector poses): standing tall, the arms hang
	-- loose and heavy at his sides; arms crossed, the extra pair crosses under the first; the
	-- power gathering (kiai), spread wide like a deity's halo; kneeling, fists on the ground.
	proud = { 8, 0, 34, 26, 0 },
	crossed = { 80, 20, 45, 120, -80 },
	flare = { 22, 0, 96, 30, 0 },
	kneel = { 34, 0, 22, 30, 0 },
}

-- Staged poses of a scene -> the extra arms' key (others: the guard).
local SCENE = {
	StandTall = "proud", Idle = "proud", Walking = "run", Dash = "run",
	ArmsCrossed = "crossed",
	Kiai = "flare", WindGather = "flare", Levitate = "flare", Colossus = "flare", KiBeamDown = "flare",
	Kneel = "kneel",
	Launched = "hit",
}
FourArms.SCENE = SCENE
FourArms.KEYS = KEYS

local function mix(a, b, t)
	local out = {}
	for i = 1, 5 do out[i] = a[i] + (b[i] - a[i]) * t end
	return out
end

local function smooth(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local LYING = { Knockdown = true, KO = true, GetUp = true }
local HIT = { Hitstun = true, Launched = true, Crumple = true, GuardBroken = true }
local BLOCK = { Blocking = true, CrouchBlocking = true, Blockstun = true, CrouchBlockstun = true }

-- One arm's angles. `side`: -1 left, 1 right; `phase`: the arm's own offset in time, so the
-- two pairs never move as one.
local function arm(view, now, moves, side)
	local state = view.state or "Idle"
	local breathe = math.sin(now * 2.2 + (if side < 0 then 0 else 1.7))
	if view.victory or view.pose == "Victory" or view.pose == "Roar" then
		return mix(KEYS.sky, KEYS.guardHigh, 0.15 + 0.15 * breathe)
	end
	if LYING[state] or view.pose == "DownFace" then return KEYS.limp end
	local scene = view.pose and SCENE[view.pose]
	if scene then
		-- (alive: a slow sway, each arm on its own rhythm)
		return mix(KEYS[scene], KEYS.guardHigh, if scene == "flare" then 0.12 + 0.1 * breathe else 0.04 + 0.04 * breathe)
	end
	if HIT[state] then return KEYS.hit end
	if BLOCK[state] then return KEYS.block end
	local m = view.move and moves and moves[view.move]
	if state == "Attack" and not m then
		-- A blow staged by a scene without frame data: a flurry, the two arms out of phase.
		local beat = (now * 5 + (if side < 0 then 0 else 0.5)) % 1
		return mix(KEYS.draw, KEYS.strike, if beat < 0.4 then smooth(beat / 0.4) else 1 - smooth((beat - 0.4) / 0.6))
	end
	if state == "Attack" and m then
		local frame = view.moveFrame or 0
		if view.move == "AsuraGatling" then
			-- Pistons: each arm thrown and pulled back many times a second, out of phase.
			if frame <= m.startup then return mix(KEYS.guard, KEYS.piston, smooth(frame / math.max(1, m.startup))) end
			local beat = (now * 9 + (if side < 0 then 0 else 0.5)) % 1
			local t = if beat < 0.45 then smooth(beat / 0.45) else 1 - smooth((beat - 0.45) / 0.55)
			return mix(KEYS.piston, KEYS.thrown, t)
		end
		-- The pair that strikes alternates from one move to the next (the move's serial is not
		-- known here: its frame data decides), the other keeps the guard.
		local striker = if ((m.startup + m.active) % 2 == 0) then 1 else -1
		if m.heavy or m.kind == "Ultimate" then striker = side end -- (heavy: both)
		local lead = side == striker
		local active = m.startup + m.active
		if frame <= m.startup then
			local t = smooth(frame / math.max(1, m.startup))
			return if lead then mix(KEYS.guard, KEYS.draw, t) else mix(KEYS.guard, KEYS.guardHigh, t)
		elseif frame <= active + 2 then
			-- (a lagging follow: the extra arm lands a beat after the real one)
			local t = smooth((frame - m.startup) / math.max(2, m.active))
			return if lead then mix(KEYS.draw, KEYS.strike, t) else KEYS.guardHigh
		else
			local total = active + m.recovery
			local t = smooth((frame - active - 2) / math.max(1, total - active - 2))
			return if lead then mix(KEYS.strike, KEYS.guard, t) else mix(KEYS.guardHigh, KEYS.guard, t)
		end
	end
	if state == "Jumping" or state == "Falling" then return KEYS.air end
	if state == "Walking" or state == "Dashing" then
		local swing = math.sin(now * 8 + (if side < 0 then 0 else math.pi))
		return mix(KEYS.run, KEYS.guard, 0.5 + 0.3 * swing)
	end
	-- Guard: breathing, each arm on its own rhythm.
	return mix(KEYS.guard, KEYS.guardHigh, 0.5 + 0.5 * breathe)
end

function FourArms.pose(view, now, moves)
	return { Left = arm(view, now, moves, -1), Right = arm(view, now, moves, 1) }
end

-- Rotation of a vector by the shoulder: roll about Z (out to the side), then pitch about X
-- (forward), then yaw about Y (inward), angles in degrees. The client builds the same
-- rotation: CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0) * CFrame.Angles(0, 0, roll).
local function rotate(v, pitch, yaw, roll)
	local x, y, z = v[1], v[2], v[3]
	local r = math.rad(roll)
	x, y = x * math.cos(r) - y * math.sin(r), x * math.sin(r) + y * math.cos(r)
	local p = math.rad(pitch)
	y, z = y * math.cos(p) - z * math.sin(p), y * math.sin(p) + z * math.cos(p)
	local w = math.rad(yaw)
	x, z = x * math.cos(w) + z * math.sin(w), -x * math.sin(w) + z * math.cos(w)
	return { x, y, z }
end
FourArms.rotate = rotate

-- The joint angles of a side as the client applies them: yaw, roll and twist take the side's
-- sign (inward across the chest, out to its own side, the elbow turned so the forearm rises).
function FourArms.angles(side, a)
	return a[1], side * a[2], side * a[3], a[4], -side * (a[5] or 0)
end

-- The shoulder's rotation as the client builds it, applied to a vector of the upper arm:
-- CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0) * CFrame.Angles(0, 0, roll)
-- * CFrame.Angles(0, twist, 0).
local function shoulderTurn(v, pitch, yaw, roll, twist)
	local t = math.rad(twist)
	local x, z = v[1] * math.cos(t) + v[3] * math.sin(t), -v[1] * math.sin(t) + v[3] * math.cos(t)
	return rotate({ x, v[2], z }, pitch, yaw, roll)
end
FourArms.shoulderTurn = shoulderTurn

-- Elbow and fist of each arm in torso space (torso half width `half`, default 1).
function FourArms.solve(spec, arms, half)
	half = half or 1
	local out = {}
	for name, a in arms do
		local side = if name == "Left" then -1 else 1
		local pitch, yaw, roll, bend, twist = FourArms.angles(side, a)
		local base = { side * spec.shoulder.x * half, spec.shoulder.y, spec.shoulder.z }
		local upper = shoulderTurn({ 0, -spec.upper, 0 }, pitch, yaw, roll, twist)
		local elbow = { base[1] + upper[1], base[2] + upper[2], base[3] + upper[3] }
		-- The forearm bends at the elbow (about the upper arm's X), then follows the shoulder.
		local fore = shoulderTurn(rotate({ 0, -spec.fore, 0 }, bend, 0, 0), pitch, yaw, roll, twist)
		local fist = { elbow[1] + fore[1], elbow[2] + fore[2], elbow[3] + fore[3] }
		out[name] = { shoulder = base, elbow = elbow, fist = fist }
	end
	return out
end

return FourArms
