--[[
	Animator: the whole animation brain of one fighter rig, pure (no Roblox API, no require)
	so it is tested offline with forward kinematics. The client runtime only feeds it the
	displayed snapshot each frame and writes the result to the Motor6D joints.

	  local anim = Animator.new({ poses = PoseLibrary, moves = MoveData.Moves, kin = Kinematics,
	                              config = CombatConfig, skeleton = skel })
	  local pose, lift = anim:step(view, opponentView, dt, time, poseRate, cinematic)

	Layers, in order:
	  1. timeline   key poses picked from the authoritative state and move frame, with
	                anticipation (coil), impact smear, follow-through and settle; locomotion
	                and stances are generated with leg IK so the feet stay planted
	  2. blend      short eased cross-fade between pose families, held steps inside a family
	                (anime "on twos" look, see poseRate)
	  3. secondary  springs: lean from acceleration, hit recoil wobble, look at the opponent
	  4. grounding  the lowest point of the body rests on the floor, whatever the avatar size
	Presentation only: nothing here changes the simulation.
]]
local Animator = {}
Animator.__index = Animator

local TAU = 2 * math.pi
local DEFAULTS = { Ground = 1, Look = 1 }

local function clamp01(x)
	return math.clamp(x, 0, 1)
end

local function easeOut(t)
	return 1 - (1 - t) * (1 - t)
end

local function easeInOut(t)
	return t * t * (3 - 2 * t)
end

-- Ease out with a small overshoot: settles past the target, then back (springy return).
local function settle(t)
	local c1 = 0.9
	local u = t - 1
	return 1 + (c1 + 1) * u * u * u + c1 * u * u
end

local function smoothstep(a, b, x)
	return easeInOut(clamp01((x - a) / (b - a)))
end

-- Held steps: a progress quantized to the pose rate (anime "on twos / threes").
local function quantize(progress, ticks, poseRate)
	local steps = math.max(1, math.floor(ticks * poseRate / 60 + 0.5))
	return math.clamp(math.floor(progress * steps + 0.5) / steps, 0, 1)
end

local function lerpPose(a, b, t)
	local out = {}
	for name, vb in b do
		local va = a[name]
		if not va then
			local d = DEFAULTS[name] or 0
			va = { d, d, d, d, d }
		end
		local v = {}
		for i = 1, math.max(#va, #vb) do
			local x, y = va[i] or 0, vb[i] or 0
			v[i] = x + (y - x) * t
		end
		out[name] = v
	end
	for name, va in a do
		if not b[name] then
			local d = DEFAULTS[name] or 0
			local v = {}
			for i = 1, #va do v[i] = va[i] + (d - va[i]) * t end
			out[name] = v
		end
	end
	return out
end
Animator.lerpPose = lerpPose

-- Shallow copy where the arrays that will be edited are copied too.
local function editable(pose, names)
	local out = table.clone(pose)
	for _, name in names do
		local v = pose[name]
		out[name] = if v then table.clone(v) else { 0, 0, 0, 0, 0 }
	end
	return out
end

-- Reactions picked from the move that hit (presentation only).
local REACTION = {
	BodyBlow = "HitBody", KiFlurry = "HitBody", PalmStrike = "HitBody", Finale = "HitBody",
	Smash = "HitBody", KiBlast = "HitBody", Awakening = "HitBody", KaienRush = "HitBody",
	Sweep = "HitLow", LowKick = "HitLow",
}
Animator.REACTION = REACTION

-- Foot-locked gaits: the stance foot moves back exactly as far as the body moves forward.
-- travel = stance-phase foot travel (studs, scaled to the leg length), stance = share of the
-- cycle a foot is on the floor (under 0.5: a flight phase, a fighter's bounding run).
local GAITS = {
	forward = { travel = 2.0, stance = 0.34, lift = 0.62, drop = 0.42, bob = 0.12, center = -0.05,
		pump = 16, twist = 9, upper = "RunUpper", spread = 6 },
	back = { travel = 1.5, stance = 0.42, lift = 0.34, drop = 0.42, bob = 0.07, center = 0.12,
		pump = 6, twist = 5, upper = "BackUpper", spread = 7 },
}
Animator.GAITS = GAITS

local SHAKE_STATES = { Hitstun = true, Launched = true, Blockstun = true, CrouchBlockstun = true, KO = true,
	Crumple = true, GuardBroken = true }
local LYING = { Knockdown = true, KO = true }
local BLEND_TIMES = { Gait = 0.12, Idle = 0.1, Air = 0.08 }

function Animator.new(deps)
	local skel = deps.skeleton
	-- Kits: a move without its own poses uses the poses of its role (the KAI move of the
	-- same combo slot); stances, guards and runs come from the kit when it has its own.
	local roleOf, moveKit = {}, {}
	for kitName, kit in deps.kits or {} do
		for role, id in kit.Roles do
			roleOf[id], moveKit[id] = role, kitName
		end
	end
	for id, kitName in deps.moveKit or {} do moveKit[id] = moveKit[id] or kitName end
	local self = setmetatable({
		poses = deps.poses, moves = deps.moves, kin = deps.kin, config = deps.config, skel = skel,
		roleOf = roleOf, moveKit = moveKit, kit = "KAI",
		scale = (skel.legLength or 2.3) / 2.3,
		rootHeight = -skel.floor,
		cache = setmetatable({}, { __mode = "k" }),
		exaggerated = {},
		track = { stateAge = 0, hitAge = 10, landAge = 10, landSpeed = 0, walkDistance = 0, walkDir = 1,
			velocity = 0, accel = 0, victoryAge = 0 },
		springs = { lean = { x = 0, v = 0 }, recoil = { x = 0, v = 0 }, lookP = { x = 0, v = 0 }, lookY = { x = 0, v = 0 } },
	}, Animator)
	return self
end

-- ===================================================================== pose resolution

-- Applies the Stance (feet IK) channel for this rig and scales the Root offsets to its size.
function Animator:solveStance(pose)
	local kin, s = self.kin, self.scale
	local out = {}
	for k, v in pose do
		if k ~= "Stance" then out[k] = v end
	end
	local root = pose.Root
	if root and s ~= 1 then
		out.Root = { root[1] or 0, root[2] or 0, root[3] or 0, (root[4] or 0) * s, (root[5] or 0) * s, root[6] }
	end
	local stance = pose.Stance
	if stance then
		local spread = stance[5] or 5
		if not pose.LeftHip then kin.plantLeg(self.skel, out, "Left", stance[1] * s, 0, stance[3], spread) end
		if not pose.RightHip then kin.plantLeg(self.skel, out, "Right", stance[2] * s, 0, stance[4], spread) end
		out.Plant = { if pose.LeftHip then 0 else 1, if pose.RightHip then 0 else 1 }
	end
	return out
end

function Animator:resolve(pose)
	local cached = self.cache[pose]
	if not cached then
		cached = self:solveStance(pose)
		self.cache[pose] = cached
	end
	return cached
end

-- A base pose (STANCE, Idle, Block, RunUpper...) of a kit, or the shared one.
function Animator:base(name, kit)
	local own = self.poses.Kits and self.poses.Kits[kit or self.kit]
	return own and own[name] or self.poses[name]
end

-- Key poses of a move: its own, or its role's.
function Animator:moveSet(id)
	return self.poses[id] or (self.roleOf[id] and self.poses[self.roleOf[id]])
end

-- `key` pushed `amount` times as far from `base` (1 = key itself), joints clamped to LIMITS.
function Animator:exaggerate(base, key, amount)
	local out = lerpPose(base, key, amount)
	local limits = self.poses.LIMITS
	for name, range in limits do
		local v = out[name]
		if v then v[1] = math.clamp(v[1], range[1], range[2]) end
	end
	for _, channel in { "Ground", "Look", "Plant" } do
		if key[channel] then out[channel] = table.clone(key[channel]) end
	end
	-- Feet planted by IK stay exactly where the key put them: only the body is pushed.
	local plant = key.Plant
	if plant then
		for i, side in { "Left", "Right" } do
			if (plant[i] or 0) > 0.5 then
				for _, joint in { "Hip", "Knee", "Ankle" } do
					local v = key[side .. joint]
					if v then out[side .. joint] = table.clone(v) end
				end
			end
		end
		if key.Root and out.Root then
			out.Root[4], out.Root[5] = key.Root[4], key.Root[5]
		end
	end
	return out
end

function Animator:cachedExaggeration(id, base, key, amount)
	local hit = self.exaggerated[id]
	if not hit then
		hit = self:exaggerate(base, key, amount)
		self.exaggerated[id] = hit
	end
	return hit
end

-- Breathing / bouncing layer on a stance-family pose (before IK, so the feet stay planted).
function Animator:breathe(raw, amount, time)
	local b = (1 - math.cos(TAU * 0.85 * time)) / 2 * amount
	local out = editable(raw, { "Root", "Waist", "LeftShoulder", "RightShoulder", "LeftElbow", "RightElbow" })
	out.Root[4] = (out.Root[4] or 0) - 0.09 * b
	out.Waist[1] -= 2 * b
	out.LeftShoulder[1] += 4 * b
	out.RightShoulder[1] += 4 * b
	out.LeftElbow[1] -= 5 * b
	out.RightElbow[1] -= 5 * b
	return out
end

-- ===================================================================== timelines

local COIL_AT = 0.7 -- share of the startup spent reaching the anticipation peak (then held)

function Animator:attack(id, frame, poseRate)
	local m, set = self.moves[id], self:moveSet(id)
	local S, A, R = m.startup, m.active, m.recovery
	local stance = self:resolve(self:base("STANCE", self.moveKit[id]))
	local startup = self:resolve(set.Startup)
	local active = self:resolve(set.Active)
	local recovery = self:resolve(set.Recovery)
	if frame <= S then
		if m.meterCost then return startup, id .. ":K", false end -- held kiai during the super flash
		local coil = if set.Coil then self:resolve(set.Coil) else self:cachedExaggeration(id .. "C", stance, startup, 1.15)
		local u = math.max(frame, 0) / S
		if u < COIL_AT then
			local t = quantize(u / COIL_AT, S * COIL_AT, poseRate)
			return lerpPose(stance, coil, easeOut(t)), id .. ":S" .. t, false
		end
		return coil, id .. ":C", false
	end
	local a = frame - S
	local active2 = set.Active2 and m.hits and m.hits > 1 and self:resolve(set.Active2)
	if a <= A then
		local beat = if active2 then math.floor((a - 1) / m.hitInterval) else 0
		local second = active2 and beat % 2 == 1
		local key = if second then active2 else active
		local from = if second then active elseif beat > 0 then active2 or startup else startup
		local intoBeat = if active2 then (a - 1) % m.hitInterval else a - 1
		if intoBeat < 2 then
			-- Smear frame: the contact pose overshoots its line of action for two ticks.
			local impact
			if set.Impact and not second then
				impact = self:resolve(set.Impact)
			else
				impact = self:cachedExaggeration(id .. (if second then "I2" elseif beat > 0 then "I3" else "I"), from, key, 1.18)
			end
			return impact, id .. ":I" .. beat, true
		end
		return key, id .. ":A" .. beat, true
	end
	local last = active
	if active2 then
		local beats = math.floor((A - 1) / m.hitInterval)
		if beats % 2 == 1 then last = active2 end
	end
	local r = (a - A) / R
	if r < 0.4 then
		local t = quantize(r / 0.4, R * 0.4, poseRate)
		return lerpPose(last, recovery, easeOut(t)), id .. ":R" .. t, false
	end
	local t = quantize((r - 0.4) / 0.6, R * 0.6, poseRate)
	return lerpPose(recovery, stance, settle(t)), id .. ":E" .. t, false
end

function Animator:gait(time)
	local tr, kin, s = self.track, self.kin, self.scale
	local g = if tr.walkDir < 0 then GAITS.back else GAITS.forward
	local travel = g.travel * s
	local cycle = travel / g.stance -- locked feet: distance per cycle
	local phase = (tr.walkDistance / cycle) % 1
	local upper = self:base(g.upper)
	local pose = editable(upper, { "Root", "Waist", "LeftShoulder", "RightShoulder" })
	local stride = math.sin(TAU * phase)
	local arm = math.cos(TAU * phase) -- left foot in front at phase 0: left arm back
	local bob = math.cos(TAU * (2 * phase - g.stance)) -- 1 at mid-stance (lowest)
	-- The pelvis stays square over the planted feet (it only pitches into the run); the
	-- shoulders counter-rotate.
	pose.Root[4] = (-g.drop - g.bob * bob) * s
	pose.Waist[2] += g.twist * stride
	pose.LeftShoulder[1] -= g.pump * arm
	pose.RightShoulder[1] += g.pump * arm
	local breathing = 0.5 + 0.5 * math.sin(TAU * 0.85 * time)
	pose.Waist[1] -= breathing
	for side, offset in { Left = 0, Right = 0.5 } do
		local q = (phase + offset) % 1
		-- Ground position of the foot: still during the stance, eased to the next footprint
		-- during the swing (zero ground speed at lift-off and touch-down: no sliding).
		local ground = if q < g.stance then 0 else cycle * easeInOut((q - g.stance) / (1 - g.stance))
		local z = g.center * s + q * cycle - travel / 2 - ground
		local lift, pitch
		if q < g.stance then
			local u = q / g.stance
			lift = 0
			pitch = 10 * (1 - smoothstep(0, 0.3, u)) - 26 * smoothstep(0.55, 1, u) -- heel strike, toe off
		else
			local u = (q - g.stance) / (1 - g.stance)
			lift = g.lift * s * math.sin(math.pi * u)
			pitch = -26 * (1 - smoothstep(0, 0.5, u)) + 10 * smoothstep(0.7, 1, u)
		end
		kin.plantLeg(self.skel, pose, side, z, lift, pitch, g.spread)
	end
	pose.Ground = { 0 }
	pose.Look = { 1 }
	pose.Plant = { 1, 1 }
	return pose
end

function Animator:air(vy)
	local poses = self.poses
	local up = self.config.JumpVelocity
	if vy > 0 then
		local t = 1 - clamp01(vy / up)
		return lerpPose(self:resolve(poses.JumpRise), self:resolve(poses.JumpApex), easeInOut(t))
	end
	return lerpPose(self:resolve(poses.JumpApex), self:resolve(poses.Fall), easeInOut(clamp01(-vy / up)))
end

function Animator:reaction(view, poseRate)
	local tr, poses = self.track, self.poses
	local move = tr.hitBy and self.moves[tr.hitBy]
	local kind = REACTION[tr.hitBy or ""]
		or (if move and move.guard == "Low" then "HitLow" elseif (view.combo or 0) % 2 == 0 then "HitHigh2" else "HitHigh")
	local base = self:resolve(poses[kind])
	local stance = self:resolve(self:base("STANCE"))
	if (view.hitstop or 0) > 0 or tr.hitAge < 0.05 then
		return self:cachedExaggeration(kind .. "I", stance, base, 1.15), kind .. ":I", true
	end
	local u = quantize(clamp01((tr.hitAge - 0.05) / 0.4), 24, poseRate)
	return lerpPose(base, lerpPose(base, stance, 0.45), easeOut(u)), kind .. ":S" .. u, false
end

-- Key pose for the current state: (pose, key, snap). Keys sharing a family ("Jab:...") step
-- without blending; a snap key (impacts, hits) cuts instantly.
function Animator:evaluate(view, time, poseRate)
	local poses, tr = self.poses, self.track
	local state = view.state
	local stepped = math.floor(time * poseRate) / poseRate
	-- A staged pose (cinematics): the kit's own version first (its victory, guard...).
	local staged = view.pose and self:base(view.pose)
	if staged and staged.Root then
		return self:resolve(staged), "Pose:" .. view.pose, false
	end
	if state == "Attack" and view.move and self.moves[view.move] and self:moveSet(view.move) then
		return self:attack(view.move, view.moveFrame or 0, poseRate)
	end
	if view.victory then
		local u = clamp01(tr.victoryAge / 0.35)
		local victory = self:base("Victory")
		local pose = lerpPose(self:resolve(self:base("STANCE")), self:resolve(victory), settle(u))
		if u >= 1 then pose = self:solveStance(self:breathe(victory, 0.6, stepped)) end
		return pose, "Victory", false
	end
	if view.intro then
		return self:solveStance(self:breathe(poses.Kiai, 1.2, stepped)), "Intro", false
	end
	if state == "Walking" then
		return self:gait(time), "Gait", false
	elseif state == "Crouching" then
		return self:solveStance(self:breathe(self:base("Crouch"), 0.6, stepped)), "Crouch", false
	elseif state == "Jumping" or state == "Falling" then
		return self:air(view.vy or 0), "Air", false
	elseif state == "Dashing" then
		local back = (view.vx or 0) * (view.facing or 1) < 0
		if back then
			local u = clamp01(tr.stateAge / (self.config.DashTicks / 60))
			local pose = editable(self:resolve(poses.DashBack), { "Root" })
			pose.Root[4] += 0.55 * self.scale * math.sin(math.pi * u)
			return pose, "DashBack", false
		end
		return self:resolve(poses.Dash), "Dash", false
	elseif state == "Blocking" then
		return self:solveStance(self:breathe(self:base("Block"), 0.35, stepped)), "Block", false
	elseif state == "CrouchBlocking" then
		return self:solveStance(self:breathe(self:base("CrouchBlock"), 0.35, stepped)), "CrouchBlock", false
	elseif state == "Evading" then
		return self:resolve(poses.Evade), "Evade", tr.stateAge < 0.02
	elseif state == "Blockstun" or state == "CrouchBlockstun" then
		local crouched = state == "CrouchBlockstun"
		local impact = self:resolve(if crouched then poses.CrouchBlockstun else poses.Blockstun)
		local guard = self:resolve(self:base(if crouched then "CrouchBlock" else "Block"))
		if (view.hitstop or 0) > 0 or tr.stateAge < 0.06 then return impact, state .. ":I", true end
		local u = quantize(clamp01((tr.stateAge - 0.06) / 0.25), 15, poseRate)
		return lerpPose(impact, guard, easeOut(u)), state .. ":R" .. u, false
	elseif state == "Hitstun" then
		return self:reaction(view, poseRate)
	elseif state == "Crumple" then
		local age = tr.stateAge
		if age < 0.15 then return self:resolve(poses.CrumpleStart), "Crumple:I", true end
		local u = quantize(clamp01((age - 0.15) / 0.35), 21, poseRate)
		return lerpPose(self:resolve(poses.CrumpleStart), self:resolve(poses.Crumple), easeInOut(u)), "Crumple:" .. u, false
	elseif state == "GuardBroken" then
		local pose = editable(self:resolve(poses.GuardBroken), { "Root", "Waist" })
		pose.Root[2] += 9 * math.sin(TAU * 1.4 * stepped)
		pose.Waist[3] += 7 * math.sin(TAU * 1.4 * stepped + 1)
		return pose, "GuardBroken", tr.stateAge < 0.02
	elseif state == "Launched" or (state == "KO" and (view.y or 0) > 0.3) then
		local fall = clamp01(-(view.vy or 0) / 30)
		return lerpPose(self:resolve(poses.Launched), self:resolve(poses.LaunchedFall), easeInOut(fall)), "Launched", false
	elseif LYING[state] then
		local age = math.min(tr.stateAge, tr.landAge)
		if age < 0.1 then return self:resolve(poses.DownImpact), "Down:I", true end
		local u = quantize(clamp01((age - 0.1) / 0.3), 18, poseRate)
		return lerpPose(self:resolve(poses.DownImpact), self:resolve(poses.Down), easeOut(u)), "Down:" .. u, false
	elseif state == "GetUp" then
		local u = clamp01(tr.stateAge / (self.config.GetUpTicks / 60))
		if u < 0.5 then
			local t = quantize(u / 0.5, 7, math.max(poseRate, 24))
			return lerpPose(self:resolve(poses.Down), self:resolve(poses.Kneel), easeInOut(t)), "GetUp:" .. t, false
		end
		local t = quantize((u - 0.5) / 0.5, 7, math.max(poseRate, 24))
		return lerpPose(self:resolve(poses.Kneel), self:resolve(self:base("STANCE")), easeOut(t)), "GetUp:K" .. t, false
	end
	-- Idle: breathing between the two idle keys.
	local b = (1 - math.cos(TAU * 0.85 * stepped)) / 2
	local idle = self:base("Idle")
	return self:solveStance(lerpPose(idle[1], idle[2], b)), "Idle", false
end

-- ===================================================================== per-frame tracking

-- Follows the displayed snapshot: time in the current state, last hit, landing, walked
-- distance (in the rig's local space, so the planted foot stays still on screen).
function Animator:observe(view, dt, other)
	local tr = self.track
	self.kit = view.kit or self.kit
	if other and other.state == "Attack" and other.move then tr.hitBy = other.move end
	local moveRestarted = view.state == "Attack" and tr.move == view.move and (view.moveFrame or 0) < (tr.moveFrame or 0)
	if view.state ~= tr.state or view.move ~= tr.move or moveRestarted then
		tr.stateAge = 0
	else
		tr.stateAge += dt
	end
	tr.newHit = false
	local stunned = view.state == "Hitstun" or view.state == "Crumple" or view.state == "Launched" or view.state == "GuardBroken"
	if stunned and (view.state ~= tr.state or (view.combo or 0) ~= (tr.combo or 0)) then
		tr.hitAge, tr.newHit = 0, true
	else
		tr.hitAge += dt
	end
	local y = view.y or 0
	if (tr.y or 0) > 0.05 and y <= 0.01 then
		tr.landAge, tr.landSpeed = 0, math.abs(tr.vy or 0)
	else
		tr.landAge += dt
	end
	local facing = view.facing or 1
	local dx = if tr.x then (view.x or 0) - tr.x else 0
	if math.abs(dx) > 3 then dx = 0 end -- new round or cinematic blink: a cut, not a motion
	local yaw = math.rad(self.config.ModelYaw or 0)
	if view.state == "Walking" then
		local step = dx * facing / math.cos(yaw)
		tr.walkDistance += step
		if math.abs(step) > 1e-4 then tr.walkDir = if step > 0 then 1 else -1 end
	end
	local velocity = if dt > 0 then dx * facing / dt else 0
	local accel = if dt > 0 then (velocity - tr.velocity) / dt else 0
	tr.accel += (accel - tr.accel) * math.min(1, dt * 12)
	tr.velocity = velocity
	tr.victoryAge = if view.victory then tr.victoryAge + dt else 0
	tr.state, tr.move, tr.moveFrame, tr.combo = view.state, view.move, view.moveFrame, view.combo
	tr.x, tr.y, tr.vy = view.x, y, view.vy
end

-- ===================================================================== step

-- Point the head should look at, in the rig's root space (the rig is turned by ModelYaw
-- toward the camera, so the opponent sits slightly off its forward axis).
function Animator:lookTarget(view, other)
	local yaw = math.rad(self.config.ModelYaw or 0)
	local dx = (other.x or 0) - (view.x or 0)
	local head = self.skel.headCenter and self.skel.headCenter[2] or 2.3
	local dy = (other.y or 0) - (view.y or 0) + head
	if LYING[other.state] or other.state == "GetUp" then
		dy -= head + self.rootHeight - 0.6
	elseif other.state == "Crouching" or other.state == "CrouchBlocking" or other.state == "CrouchBlockstun" then
		dy -= 1.1 * self.scale
	end
	return -math.sin(yaw) * dx, dy, -math.cos(yaw) * (view.facing or 1) * dx
end

function Animator:step(view, other, dt, time, poseRate, cinematic)
	local kin, skel, springs, tr = self.kin, self.skel, self.springs, self.track
	self:observe(view, dt, other)
	local target, key, snap = self:evaluate(view, time, poseRate)

	-- Landing squash on top of grounded stances (feet stay planted, knees absorb).
	if tr.landAge < 0.2 and (view.state == "Idle" or view.state == "Walking" or view.state == "Crouching"
		or view.state == "Blocking" or view.state == "CrouchBlocking") then
		local w = (1 - easeOut(tr.landAge / 0.2)) * math.clamp(tr.landSpeed / 45, 0.35, 1)
		target = lerpPose(target, self:resolve(self.poses.Land), w * 0.85)
	end

	-- Blend between families; steps inside a family are held (anime timing).
	if key ~= self.lastKey then
		local family = key:match("^[^:]+")
		local last = self.lastKey and self.lastKey:match("^[^:]+")
		local instant = snap or family == last or not self.current or tr.landAge == 0
		self.from = self.current
		self.blendStart = time
		self.blendTime = if instant then 0 else BLEND_TIMES[family] or BLEND_TIMES[last or ""] or 0.07
		self.lastKey = key
	end
	local t = if self.blendTime and self.blendTime > 0 then clamp01((time - self.blendStart) / self.blendTime) else 1
	local pose = if t < 1 and self.from then lerpPose(self.from, target, easeOut(t)) else target
	self.current = pose

	-- Secondary motion (additive springs).
	if tr.newHit then springs.recoil.v += 320 end
	local lean = kin.spring(springs.lean, math.clamp(-tr.accel * 0.12, -9, 9), dt, 2.2, 0.55)
	local recoil = kin.spring(springs.recoil, 0, dt, 3.2, 0.32)
	local out = editable(pose, { "Root", "Waist", "Neck" })
	out.Waist[1] += lean + recoil
	out.Neck[1] += recoil * 0.6

	-- Look at the opponent: pitch fully, yaw a little (keeps the 3/4 view toward the camera).
	local lookWeight = if other and not cinematic then (pose.Look and pose.Look[1] or 1) else 0
	local wantP, wantY = 0, 0
	if lookWeight > 0.01 then
		local x, y, z = self:lookTarget(view, other)
		local p, w = kin.lookCorrection(skel, kin.solve(skel, out, 0), x, y, z)
		wantP = math.clamp(p, -35, 35) * lookWeight
		wantY = math.clamp(w * 0.3, -25, 25) * lookWeight
	end
	local neckRange = self.poses.LIMITS.Neck
	out.Neck[1] = math.clamp(out.Neck[1] + kin.spring(springs.lookP, wantP, dt, 4, 1), neckRange[1], neckRange[2])
	out.Neck[2] += kin.spring(springs.lookY, wantY, dt, 4, 1)

	-- Hitstop shake on the defender (impact frames).
	if (view.hitstop or 0) > 0 and SHAKE_STATES[view.state] then
		out.Root[6] = (math.floor(time * 60) % 2 * 2 - 1) * 0.12
	else
		out.Root[6] = 0
	end

	return out, self:groundLift(out, view.y or 0)
end

-- Root lift (studs) that rests the body on the floor: on its feet when they are planted by
-- IK (Plant channel), on its lowest point otherwise (lying, kneeling, kicks). Grounding fades
-- out with the altitude and with the pose's Ground channel (hops). The feet never sink; the
-- rest of a planted body may dip by its box corners only (real meshes are rounded).
local CORNER_TOLERANCE = 0.15

function Animator:groundLift(pose, altitude)
	local kin, skel = self.kin, self.skel
	local solved = kin.solve(skel, pose, 0)
	local body = kin.lowest(skel, solved)
	local left = kin.footBottom(skel, solved, "Left") or body
	local right = kin.footBottom(skel, solved, "Right") or body
	local feet = math.min(left, right)
	local planted = pose.Plant or {}
	local pl, pr = clamp01(planted[1] or 0), clamp01(planted[2] or 0)
	-- A kick plants only its support foot: the kicking foot does not carry the body.
	local support = if math.abs(pl - pr) < 0.01 then feet elseif pl > pr then left else right
	local plant = math.max(pl, pr)
	local reference = body + (support - body) * plant
	local floor = skel.floor - math.max(0, altitude)
	local weight = clamp01(pose.Ground and pose.Ground[1] or 1) * clamp01(1 - altitude / 0.8)
	local lift = weight * (floor - reference)
	if feet + lift < floor then lift = floor - feet end
	local tolerance = CORNER_TOLERANCE * plant
	if body + lift < floor - tolerance then lift = floor - tolerance - body end
	return lift
end
Animator.CORNER_TOLERANCE = CORNER_TOLERANCE

return Animator
