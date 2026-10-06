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

-- Each kit's guard has its own rhythm between its two idle keys (rate, Hz) and a slow weight
-- shift from one foot to the other (shift, degrees): the boxer bounces, the swordsman barely
-- breathes, the colossus heaves.
local IDLE_RHYTHM = {
	KAI = { rate = 1.15, shift = 3 }, TARO = { rate = 1.9, shift = 4 }, TARO_CLASSIC = { rate = 1.4, shift = 3 },
	ZEPHYR = { rate = 1.35, shift = 5 }, AKEMI = { rate = 0.8, shift = 3 }, RYUKEN = { rate = 1.0, shift = 2 },
	SHIN = { rate = 0.55, shift = 1.5 }, DAICHA = { rate = 0.7, shift = 4 }, HIBECARES = { rate = 0.5, shift = 2.5 },
	ASURA = { rate = 0.9, shift = 3 }, ["KUROEN SHIN"] = { rate = 0.4, shift = 1 },
	RAIJIN = { rate = 1.25, shift = 3 }, YUKINA = { rate = 0.65, shift = 2 }, VENOM = { rate = 1.5, shift = 5 },
	GORAN = { rate = 0.55, shift = 3 }, ASTER = { rate = 0.45, shift = 2 }, HIBIKI = { rate = 2.0, shift = 4 },
	KUROEN = { rate = 0.95, shift = 3 }, KAZAN = { rate = 1.0, shift = 3.5 }, KUREN = { rate = 0.75, shift = 2.5 },
	SYLVA = { rate = 1.3, shift = 4 }, ELIAN = { rate = 0.6, shift = 1.5 }, NOVA = { rate = 1.1, shift = 3 },
}
Animator.IDLE_RHYTHM = IDLE_RHYTHM

-- Waiting poses (Wilhem: « des poses différentes dans le menu et le lobby, et quand il bouge pas
-- pendant les combats trop longtemps »): a fighter left still slips into one of his own poses,
-- holds it, comes back to his guard, then the next one. In a fight only after `after` seconds
-- without moving; in the menu and the lobby (view.showcase) almost at once. Cosmetic only.
Animator.WAITING = { after = 5, showcase = 1.5, cycle = 6.5, blendIn = 0.45, hold = 3.2, blendOut = 0.55 }
Animator.WAITING_POSES = {
	KAI = { "ArmsCrossed", "Kiai", "StandTall" }, TARO = { "GloveTap", "ArmsCrossed", "StandTall" },
	ZEPHYR = { "WindGather", "StandTall", "ArmsCrossed" }, AKEMI = { "ArmsCrossed", "StandTall", "WindGather" },
	RYUKEN = { "Roar", "GloveTap", "ArmsCrossed" }, SHIN = { "Sheathe", "StandTall", "Iai" },
	DAICHA = { "Levitate", "ArmsCrossed", "StandTall" }, HIBECARES = { "Colossus", "ArmsCrossed", "Roar" },
	RAIJIN = { "StandTall", "Kiai", "ArmsCrossed" }, YUKINA = { "Sheathe", "StandTall", "WindGather" },
	VENOM = { "ArmsCrossed", "GloveTap", "StandTall" }, GORAN = { "Roar", "Colossus", "ArmsCrossed" },
	ASTER = { "Levitate", "StandTall", "ArmsCrossed" }, HIBIKI = { "GloveTap", "WindGather", "StandTall" },
	KAZAN = { "Roar", "ArmsCrossed", "GloveTap" }, KUREN = { "Iai", "StandTall", "Sheathe" },
	SYLVA = { "WindGather", "ArmsCrossed", "StandTall" }, ELIAN = { "StandTall", "Sheathe", "ArmsCrossed" },
	NOVA = { "WindGather", "ArmsCrossed", "StandTall" }, KUROEN = { "ArmsCrossed", "StandTall", "Roar" },
	ASURA = { "Roar", "ArmsCrossed", "StandTall" }, ["KUROEN SHIN"] = { "StandTall", "ArmsCrossed", "Kiai" },
}

-- The waiting pose of a fighter still for `age` seconds: (name, weight 0..1) or nil.
function Animator.waiting(kit, age, showcase)
	local W = Animator.WAITING
	local t = age - (if showcase then W.showcase else W.after)
	if t <= 0 then return nil end
	local list = Animator.WAITING_POSES[kit] or Animator.WAITING_POSES.KAI
	local n = math.floor(t / W.cycle)
	local u = t - n * W.cycle
	local w
	if u < W.blendIn then
		w = u / W.blendIn
		w = w * w * (3 - 2 * w)
	elseif u < W.blendIn + W.hold then
		w = 1
	elseif u < W.blendIn + W.hold + W.blendOut then
		w = 1 - (u - W.blendIn - W.hold) / W.blendOut
		w = w * w * (3 - 2 * w)
	else
		return nil
	end
	return list[n % #list + 1], w
end

local SHAKE_STATES = { Hitstun = true, Launched = true, Blockstun = true, CrouchBlockstun = true, KO = true,
	Crumple = true, GuardBroken = true }
local LYING = { Knockdown = true, KO = true }
local BLEND_TIMES = { Gait = 0.12, Idle = 0.1, Air = 0.08 }

-- Overlap and follow-through: the upper body follows its key poses through springs, the arms
-- a little behind the torso and the hands and head behind the arms, so a motion drags,
-- overshoots and settles instead of stopping dead. { frequency (Hz), damping }.
local DRAG = {
	Waist = { 15, 0.8 }, LeftShoulder = { 12, 0.66 }, RightShoulder = { 12, 0.66 },
	LeftElbow = { 10, 0.6 }, RightElbow = { 10, 0.6 }, LeftWrist = { 9, 0.55 }, RightWrist = { 9, 0.55 },
	Neck = { 8, 0.62 },
}
local DRAG_NAMES = {}
for name in DRAG do table.insert(DRAG_NAMES, name) end
table.sort(DRAG_NAMES)
-- A leg that is not planted (a kick, a jump, a fall) follows through too; a planted one stays
-- exactly where the leg IK put it.
local LEG_DRAG = { 11, 0.65 }
local PLANT_IN = 0.07 -- seconds for a free leg to settle onto its planted IK pose
local LEGS = { Left = { "LeftHip", "LeftKnee", "LeftAnkle" }, Right = { "RightHip", "RightKnee", "RightAnkle" } }
local WHIP = 7 -- a snap (impact, hit) lands at once and carries on past it: per second of the jump
local CUT_DISTANCE = 2.5 -- the body moved further than this in one frame: a cut (blink, new round, shot)
Animator.DRAG = DRAG

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
		drag = {},
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
	local kits = self.poses.Kits
	if kits then
		-- The kit's stance variant first (TARO_CLASSIQUE), then the kit, then the default.
		local variant = not kit and self.stance and self.kit and kits[self.kit .. "_" .. self.stance]
		if variant and variant[name] then return variant[name] end
		local own = kits[kit or self.kit]
		if own and own[name] then return own[name] end
	end
	return self.poses[name]
end

-- Key poses of a move: its own, or its role's.
function Animator:moveSet(id)
	-- (a kit that fights with another's moves has its own version of them: ASURA)
	local kits = self.poses.Kits
	local own = kits and self.kit and kits[self.kit] and kits[self.kit].Moves
	return (own and own[id]) or self.poses[id] or (self.roleOf[id] and self.poses[self.roleOf[id]])
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

local COIL_AT = 0.45 -- share of the startup spent reaching the anticipation (then a moving hold)
local TENSION = 0.22 -- how much further the hold winds up, away from the strike, before the release
local UPPER = { "Waist", "Neck", "LeftShoulder", "RightShoulder", "LeftElbow", "RightElbow", "LeftWrist", "RightWrist" }

-- The anticipation pushed further away from the strike, upper body only (the legs and the
-- planted feet stay where the coil put them): the coil keeps tightening until the release.
function Animator:tension(id, coil, active)
	local key = id .. "T"
	local hit = self.exaggerated[key]
	if hit then return hit end
	hit = table.clone(coil)
	local limits = self.poses.LIMITS
	for _, name in UPPER do
		local c, a = coil[name], active[name]
		if c and a then
			local v = {}
			for i = 1, 3 do v[i] = (c[i] or 0) + ((c[i] or 0) - (a[i] or 0)) * TENSION end
			local range = limits[name]
			if range then v[1] = math.clamp(v[1], range[1], range[2]) end
			hit[name] = v
		end
	end
	self.exaggerated[key] = hit
	return hit
end

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
		-- (the anticipation reaches the coil on its LAST frame, so the moving hold starts from
		-- there: before, it stopped two thirds of the way and the rest jumped in one tick)
		local coilFrame = math.max(1, math.floor(S * COIL_AT))
		frame = math.max(frame, 0)
		if frame < coilFrame or (frame == coilFrame and coilFrame < S) then
			local t = quantize(frame / coilFrame, math.max(coilFrame, 2), poseRate)
			return lerpPose(stance, coil, easeOut(t)), id .. ":S" .. t, false
		end
		-- Moving hold: the wind-up tightens (slow in) until the strike leaves.
		local h = quantize((frame - coilFrame) / math.max(1, S - coilFrame), math.max(S - coilFrame, 2), poseRate)
		return lerpPose(coil, self:tension(id, coil, active), easeInOut(h)), id .. ":C" .. h, false
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

local TAKEOFF = 0.1 -- seconds of the push-off: the legs straighten out of the crouch

function Animator:air(vy)
	local up = self.config.JumpVelocity
	if vy > 0 then
		local t = 1 - clamp01(vy / up)
		local rise = lerpPose(self:resolve(self:base("JumpRise")), self:resolve(self:base("JumpApex")), easeInOut(t))
		local age = self.track.stateAge
		if self.track.state == "Jumping" and age < TAKEOFF then
			-- Push-off: out of the landing crouch, the legs straighten as the body leaves.
			return lerpPose(self:resolve(self:base("Land")), rise, easeOut(age / TAKEOFF))
		end
		return rise
	end
	return lerpPose(self:resolve(self:base("JumpApex")), self:resolve(self:base("Fall")), easeInOut(clamp01(-vy / up)))
end

function Animator:reaction(view, poseRate)
	local tr, poses = self.track, self.poses
	local move = tr.hitBy and self.moves[tr.hitBy]
	local kind = REACTION[tr.hitBy or ""]
		or (if move and move.guard == "Low" then "HitLow" elseif (view.combo or 0) % 2 == 0 then "HitHigh2" else "HitHigh")
	local base = self:resolve(self:base(kind))
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
		if staged.Stance and not view.ghost then
			-- A held stance of a scene (victory, roar, iai...) breathes: never a statue.
			return self:solveStance(self:breathe(staged, 0.7, stepped)), "Pose:" .. view.pose, false
		end
		return self:resolve(staged), "Pose:" .. view.pose, false
	end
	if state == "Attack" and view.move and self.moves[view.move] and self:moveSet(view.move) then
		return self:attack(view.move, view.moveFrame or 0, poseRate)
	end
	if view.victory then
		local u = clamp01(tr.victoryAge / 0.35)
		-- (a kit with two victories, ASURA: they alternate, one round in two)
		local victory = if (view.wins or 0) % 2 == 1 and self:base("VictoryAlt") then self:base("VictoryAlt") else self:base("Victory")
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
			local pose = editable(self:resolve(self:base("DashBack")), { "Root" })
			pose.Root[4] += 0.55 * self.scale * math.sin(math.pi * u)
			return pose, "DashBack", false
		end
		local dash = self:resolve(self:base("Dash"))
		if not view.weave then
			-- Lean into it, hold, and brake into a crouch at the end (the weight carries on).
			local u = clamp01(tr.stateAge / (self.config.DashTicks / 60))
			local stance = self:resolve(self:base("STANCE"))
			if u < 0.25 then
				return lerpPose(stance, dash, easeOut(u / 0.25)), "Dash", false
			elseif u > 0.7 then
				return lerpPose(dash, self:resolve(self:base("Land")), easeInOut((u - 0.7) / 0.3) * 0.75), "Dash", false
			end
		end
		if view.weave then
			-- Boxer's weave: the waist rolls left and right, a figure eight under the guard.
			local u = clamp01(tr.stateAge / (self.config.DashTicks / 60))
			dash = editable(dash, { "Waist" })
			dash.Waist[3] += 24 * math.sin(2 * math.pi * u)
			dash.Waist[2] += 14 * math.cos(2 * math.pi * u)
		end
		return dash, "Dash", false
	elseif state == "Blocking" then
		return self:solveStance(self:breathe(self:base("Block"), 0.35, stepped)), "Block", false
	elseif state == "CrouchBlocking" then
		return self:solveStance(self:breathe(self:base("CrouchBlock"), 0.35, stepped)), "CrouchBlock", false
	elseif state == "Evading" then
		-- (AKEMI's INSTINCT: the style of the dodge; the others slide back)
		local style = view.evadeStyle and self:base("Evade" .. view.evadeStyle)
		return self:resolve(style or self:base("Evade")), "Evade" .. (view.evadeStyle or ""), tr.stateAge < 0.02
	elseif state == "Feint" then
		-- (KAI's FEINT: the string stops, back toward the guard)
		return self:solveStance(self:base("Block")), "Feint", tr.stateAge < 0.02
	elseif state == "Blockstun" or state == "CrouchBlockstun" then
		local crouched = state == "CrouchBlockstun"
		local impact = self:resolve(self:base(if crouched then "CrouchBlockstun" else "Blockstun"))
		local guard = self:resolve(self:base(if crouched then "CrouchBlock" else "Block"))
		if (view.hitstop or 0) > 0 or tr.stateAge < 0.06 then return impact, state .. ":I", true end
		local u = quantize(clamp01((tr.stateAge - 0.06) / 0.25), 15, poseRate)
		return lerpPose(impact, guard, easeOut(u)), state .. ":R" .. u, false
	elseif state == "Hitstun" then
		return self:reaction(view, poseRate)
	elseif state == "Crumple" then
		local age = tr.stateAge
		if age < 0.15 then return self:resolve(self:base("CrumpleStart")), "Crumple:I", true end
		local u = quantize(clamp01((age - 0.15) / 0.35), 21, poseRate)
		return lerpPose(self:resolve(self:base("CrumpleStart")), self:resolve(self:base("Crumple")), easeInOut(u)), "Crumple:" .. u, false
	elseif state == "GuardBroken" then
		local pose = editable(self:resolve(self:base("GuardBroken")), { "Root", "Waist" })
		pose.Root[2] += 9 * math.sin(TAU * 1.4 * stepped)
		pose.Waist[3] += 7 * math.sin(TAU * 1.4 * stepped + 1)
		return pose, "GuardBroken", tr.stateAge < 0.02
	elseif state == "Launched" or (state == "KO" and (view.y or 0) > 0.3) then
		local fall = clamp01(-(view.vy or 0) / 30)
		return lerpPose(self:resolve(self:base("Launched")), self:resolve(self:base("LaunchedFall")), easeInOut(fall)), "Launched", false
	elseif LYING[state] then
		local age = math.min(tr.stateAge, tr.landAge)
		if age < 0.1 then return self:resolve(self:base("DownImpact")), "Down:I", true end
		local u = quantize(clamp01((age - 0.1) / 0.3), 18, poseRate)
		return lerpPose(self:resolve(self:base("DownImpact")), self:resolve(self:base("Down")), easeOut(u)), "Down:" .. u, false
	elseif state == "GetUp" then
		local u = clamp01(tr.stateAge / (self.config.GetUpTicks / 60))
		if u < 0.5 then
			local t = quantize(u / 0.5, 7, math.max(poseRate, 24))
			return lerpPose(self:resolve(self:base("Down")), self:resolve(self:base("Kneel")), easeInOut(t)), "GetUp:" .. t, false
		end
		local t = quantize((u - 0.5) / 0.5, 7, math.max(poseRate, 24))
		return lerpPose(self:resolve(self:base("Kneel")), self:resolve(self:base("STANCE")), easeOut(t)), "GetUp:K" .. t, false
	end
	-- Idle: the kit's rhythm between its two idle keys, and the weight shifting.
	local rhythm = (self.stance and IDLE_RHYTHM[self.kit .. "_" .. self.stance]) or IDLE_RHYTHM[self.kit] or IDLE_RHYTHM.KAI
	local phase = TAU * rhythm.rate * stepped
	local b = (1 - math.cos(phase)) / 2
	local idle = self:base("Idle")
	local pose = editable(lerpPose(idle[1], idle[2], b), { "Root", "Waist" })
	pose.Waist[3] += rhythm.shift * math.sin(phase * 0.5)
	pose.Root[2] += rhythm.shift * 0.6 * math.sin(phase * 0.5 + 1)
	local guard = self:solveStance(pose)
	-- Still for a while: one of his waiting poses (Animator.waiting).
	local name, w = nil, 0
	if not self.inCinematic then name, w = Animator.waiting(self.kit, tr.stateAge, view.showcase) end
	local target = name and self:base(name)
	if target and target.Root then
		local held = if target.Stance then self:solveStance(self:breathe(target, 0.7, stepped)) else self:resolve(target)
		return lerpPose(guard, held, w), "Waiting:" .. name .. (if w < 1 then ":" .. math.floor(w * 20) else ""), false
	end
	return guard, "Idle", false
end

-- ===================================================================== per-frame tracking

-- Follows the displayed snapshot: time in the current state, last hit, landing, walked
-- distance (in the rig's local space, so the planted foot stays still on screen).
function Animator:observe(view, dt, other)
	local tr = self.track
	self.kit = view.kit or self.kit
	self.stance = view.stance
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
	local dy = if tr.y then (view.y or 0) - tr.y else 0
	-- New round, blink, cinematic shot: a cut, not a motion.
	tr.cut = not tr.x or math.abs(dx) > CUT_DISTANCE or math.abs(dy) > CUT_DISTANCE
	if math.abs(dx) > 3 then dx = 0 end
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

-- ===================================================================== spacing

--[[
	Presentation spacing: at point-blank range the guard arms and the strikes of two bodies
	sink into each other (the pushboxes of the simulation are narrower than the bodies). Each
	body is drawn up to SPACING studs further from the other, fading out with the distance
	(and at a crossing, where the sides swap), so the separation shown always grows with the
	real one: no jump. Drawing only: positions, hitboxes and the camera keep the real ones.
	Returns how far each body is pushed away from the other.
]]
local SPACING, SPACING_NEAR, SPACING_FAR = 0.42, 2.4, 4.4
function Animator.spacing(ax, ay, bx, by)
	local d = math.abs(bx - ax)
	local fade = 1 - smoothstep(SPACING_NEAR, SPACING_FAR, d)
	local crossing = smoothstep(0.6, 1.6, d)
	local height = 1 - smoothstep(2.5, 4.5, math.abs(by - ay))
	return SPACING * fade * crossing * height
end

-- ===================================================================== overlap

-- Runs the upper-body joints of `pose` through their springs (see DRAG). `snap`: the key
-- changed this frame to an impact or a hit: the joints land on it at once and whip past it.
function Animator:overlap(pose, dt, snap, cut)
	local out = editable(pose, DRAG_NAMES)
	local limits, kin = self.poses.LIMITS, self.kin
	local function follow(name, tune, hold)
		local v = out[name]
		local axes = self.drag[name]
		if not axes then
			axes = {}
			for i = 1, 3 do axes[i] = { x = v[i] or 0, v = 0 } end
			self.drag[name] = axes
		end
		for i = 1, 3 do
			local target, s = v[i] or 0, axes[i]
			local jump = target - s.x
			if hold or cut or dt <= 0 then
				s.x, s.v = target, 0
			elseif snap then
				s.x, s.v = target, jump * WHIP
			else
				kin.spring(s, target, dt, tune[1], tune[2])
			end
			v[i] = s.x
		end
		local range = limits[name]
		if range then v[1] = math.clamp(v[1], range[1], range[2]) end
	end
	for _, name in DRAG_NAMES do follow(name, DRAG[name], false) end
	local plant = pose.Plant
	self.plantWeight = self.plantWeight or { 0, 0 }
	for i, side in { "Left", "Right" } do
		local planted = plant and (plant[i] or 0) >= 0.5
		-- A planted leg is exactly where the leg IK put it (no sliding foot); a free one
		-- follows through on its spring. Between the two it eases over a few frames (PLANT_IN):
		-- at once, the knee jumped by up to 60 degrees when a kick's leg came down to plant.
		local w = self.plantWeight[i]
		if cut or dt <= 0 then
			w = if planted then 1 else 0
		elseif planted then
			w = math.min(1, w + dt / PLANT_IN)
		else
			w = 0
		end
		self.plantWeight[i] = w
		for _, name in LEGS[side] do
			if pose[name] then
				local target = table.clone(pose[name])
				out[name] = table.clone(pose[name])
				follow(name, LEG_DRAG, w >= 1)
				if w > 0 and w < 1 then
					local v, k = out[name], easeInOut(w)
					for a = 1, 3 do v[a] = v[a] + ((target[a] or 0) - v[a]) * k end
				end
			end
		end
	end
	return out
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

-- The legs of a blow thrown in the air (see step): the lead knee up, the rear leg folded.
local AIR_TUCK = {
	LeftHip = { 72, 0, 0 }, LeftKnee = { -112, 0, 0 }, LeftAnkle = { 40, 0, 0 },
	RightHip = { 38, 0, 0 }, RightKnee = { -76, 0, 0 }, RightAnkle = { 38, 0, 0 },
}

function Animator:step(view, other, dt, time, poseRate, cinematic)
	local kin, skel, springs, tr = self.kin, self.skel, self.springs, self.track
	self:observe(view, dt, other)
	self.inCinematic = cinematic == true -- (no waiting pose while a cinematic stages the bodies)
	local target, key, snap = self:evaluate(view, time, poseRate)

	-- Landing squash on top of grounded stances (feet stay planted, knees absorb).
	if tr.landAge < 0.23 and (view.state == "Idle" or view.state == "Walking" or view.state == "Crouching"
		or view.state == "Blocking" or view.state == "CrouchBlocking") then
		-- (the knees take the weight over a couple of frames, not all on the first one: an
		-- instant squash read as a pop of the knees, every fighter, every landing)
		local w = smoothstep(0, 0.04, tr.landAge) * (1 - easeOut(clamp01((tr.landAge - 0.03) / 0.2))) * math.clamp(tr.landSpeed / 45, 0.35, 1)
		target = lerpPose(target, self:resolve(self:base("Land")), w * 0.85)
	end

	-- A blow made for the floor, thrown in the air (the fighter carried up by a rising strike,
	-- a chase or a finisher): the planted legs fold into a jump tuck, so he never stands on
	-- nothing.
	local altitude = view.y or 0
	-- (the tuck eases in and out: a rising strike lifts him 1 stud in 2 ticks, and the knees
	-- used to fold at once)
	local tuckWanted = if view.state == "Attack" and (target.Ground and target.Ground[1] or 1) > 0.5
		then clamp01((altitude - 0.4) / 1.2) else 0
	tr.tuck = (tr.tuck or 0) + (tuckWanted - (tr.tuck or 0)) * (1 - math.exp(-dt * 16))
	if tuckWanted == 0 and tr.tuck < 0.02 then tr.tuck = 0 end
	if tr.tuck > 0.001 then
		local w = tr.tuck
		target = table.clone(target)
		for joint, tuck in AIR_TUCK do
			local from = target[joint] or { 0, 0, 0 }
			target[joint] = { from[1] + (tuck[1] - from[1]) * w, from[2] * (1 - w), from[3] * (1 - w) }
		end
	end

	-- Blend between families; steps inside a family are held (anime timing).
	local snapped = false
	if key ~= self.lastKey then
		snapped = snap
		local family = key:match("^[^:]+")
		local last = self.lastKey and self.lastKey:match("^[^:]+")
		local instant = snap or family == last or not self.current
		local blending = self.blendTime ~= nil and self.blendTime > 0 and time - self.blendStart < self.blendTime
		if family == last and blending and not snap then
			-- A step inside the family while the blend into it still runs (walk -> low kick):
			-- keep blending from where it started, toward the new step (no pop on frame 2).
		else
			self.from = self.current
			self.blendStart = time
			self.blendTime = if instant then 0
				elseif tr.landAge == 0 then 0.05 -- (a landing: quick, into the squash, but not a cut)
				else BLEND_TIMES[family] or BLEND_TIMES[last or ""] or 0.07
		end
		self.lastKey = key
	end
	local t = if self.blendTime and self.blendTime > 0 then clamp01((time - self.blendStart) / self.blendTime) else 1
	local pose = if t < 1 and self.from then lerpPose(self.from, target, easeOut(t)) else target
	self.current = pose
	self.snapped = snapped
	pose = self:overlap(pose, dt, snapped, tr.cut)

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
