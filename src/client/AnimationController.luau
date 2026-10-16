--[[
	Presentation only: the single writer of the rig's Motor6D.C0 (and of the cloth tails'
	Weld.C0). The animation itself is decided by the pure shared Animator (timelines, leg IK,
	springs, look-at, grounding), tested offline; this runtime only:
	  1. reads the rig's real joints (C0 / C1) and part sizes, so the same poses fit KAI and
	     any Roblox R15 avatar,
	  2. feeds the Animator the displayed snapshot each frame,
	  3. writes the joints, the grounding lift and the cloth sway.
	Poses never change simulation timing; attacks follow the authoritative move frame.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.CombatConfig)
local MoveData = require(Shared.MoveData)
local RigSpec = require(Shared.RigSpec)
local RigReader = require(Shared.RigReader)
local Kinematics = require(Shared.Kinematics)
local PoseLibrary = require(Shared.PoseLibrary)
local Animator = require(Shared.Animator)
local Retarget = require(Shared.Retarget)
local FourArms = require(Shared.FourArms)
local WeaponSpec = require(Shared.WeaponSpec)

local rad = math.rad

local AnimationController = {}
AnimationController.__index = AnimationController

function AnimationController.new(model)
	local skeleton, motors, rigType = RigReader.skeleton(model)
	-- complete: the real skeleton could be read. A body still replicating (R6 avatars arrive
	-- part by part) is read again by the caller until it is complete.
	local self = setmetatable({ model = model, joints = {}, tails = {}, complete = skeleton ~= nil, rigType = rigType }, AnimationController)
	for name, motor in motors do
		self.joints[name] = { joint = motor, base = motor.C0 }
	end
	local animated = skeleton
	if rigType == "R6" and skeleton then
		-- R6: the animation runs on a virtual R15 body with its proportions, then each rigid
		-- R6 limb is aimed along it (see Retarget).
		self.retarget = Retarget.new(Kinematics, skeleton)
		animated = self.retarget.virtual
	end
	animated = animated or Kinematics.fromSpec(RigSpec.KAI)
	self.animator = Animator.new({
		poses = PoseLibrary, moves = MoveData.Moves, kin = Kinematics, config = Config, skeleton = animated,
		kits = MoveData.Kits, moveKit = MoveData.MoveKit,
	})
	-- R6: a held weapon (katana, spear, fans) follows the virtual R15 hand, wrist included,
	-- instead of the rigid R6 arm: its pieces' welds are driven every frame (see update).
	local spec = WeaponSpec[model:GetAttribute("Kit") or ""]
	if self.retarget and spec and not spec.flies then
		self.weapons = {}
		for _, held in { spec, spec.pair } do
			local armName = if held.hand == "LeftHand" then "Left Arm" else "Right Arm"
			local arm = model:FindFirstChild(armName)
			if arm then
				for _, piece in held.pieces do
					for _, p in model:GetChildren() do
						local link = p.Name == piece.name and p:IsA("BasePart") and p:FindFirstChildOfClass("WeldConstraint")
						if link and link.Part0 == arm then
							link:Destroy()
							local weld = Instance.new("Weld")
							weld.Part0, weld.Part1, weld.C0 = arm, p, arm.CFrame:ToObjectSpace(p.CFrame)
							weld.Parent = p
							table.insert(self.weapons, { weld = weld, spec = held, arm = armName,
								offset = CFrame.new(piece.x or 0, piece.y or 0, piece.z or 0)
									* CFrame.Angles(math.rad(piece.rot and piece.rot[1] or 0), math.rad(piece.rot and piece.rot[2] or 0), math.rad(piece.rot and piece.rot[3] or 0)) })
						end
					end
				end
			end
		end
	end
	-- Root height that rests the bind pose's feet on the floor, measured on this body.
	self.rootHeight = if self.retarget then -skeleton.floor else self.animator.rootHeight
	-- Cloth tails (sash, headband) hang from Welds named TailJoint (see RigBuilder).
	for _, d in model:GetDescendants() do
		if d:IsA("Weld") and d.Name == "TailJoint" and d.Part0 and d.Part1 then
			table.insert(self.tails, {
				weld = d, base = d.C0, anchor = d.Part0, length = d.Part1.Size.Y,
				swingX = { x = 0, v = 0 }, swingZ = { x = 0, v = 0 }, seed = #self.tails * 1.7,
				hang = d.Part1:GetAttribute("Hang") == true,
			})
		end
	end
	return self
end

-- view: the displayed snapshot of this fighter ({ state, move, moveFrame, x, y, vx, vy,
-- facing, hitstop, combo, victory, intro, pose }); other: the opponent's view.
-- ASURA's second pair of arms (RigBuilder.addFourArms): they copy the real shoulders' swing
-- a few frames late and a little wider, so every blow seems to come twice.
-- ASURA's second pair of arms (RigBuilder.addFourArms): shoulder and elbow posed every frame
-- by the pure FourArms module (guard raised like the statues, strikes, the gatling's pistons),
-- eased so a change of key never snaps.
function AnimationController:swingFourArms(view, dt, now)
	local model = self.model
	if not model then return end
	if self.fourArms == nil then
		self.fourArms = false
		for _, name in { "Left", "Right" } do
			local shoulder = model:FindFirstChild("Asura" .. name, true)
			local elbow = model:FindFirstChild("Asura" .. name .. "Elbow", true)
			if shoulder and shoulder:IsA("Motor6D") and elbow and elbow:IsA("Motor6D") then
				self.fourArms = self.fourArms or {}
				-- (the build already turned them into their guard: start from the bare joint)
				local guard = FourArms.pose({ state = "Idle" }, 0, nil)[name]
				local side = if name == "Left" then -1 else 1
				local pitch, yaw, roll, bend, twist = FourArms.angles(side, guard)
				local turn = CFrame.Angles(0, rad(yaw), 0) * CFrame.Angles(rad(pitch), 0, 0) * CFrame.Angles(0, 0, rad(roll))
					* CFrame.Angles(0, rad(twist), 0)
				self.fourArms[name] = { shoulder = shoulder, elbow = elbow, side = side,
					shoulderBase = shoulder.C0 * turn:Inverse(), elbowBase = elbow.C0 * CFrame.Angles(rad(bend), 0, 0):Inverse(),
					angles = { guard[1], guard[2], guard[3], guard[4], guard[5] or 0 } }
			end
		end
	end
	if not self.fourArms then return end
	local target = FourArms.pose(view, now, MoveData.Moves)
	local fast = view.move == "AsuraGatling" or view.state == "Hitstun"
	local follow = 1 - math.exp(-(if fast then 30 else 12) * dt)
	for name, info in self.fourArms do
		local a, goal = info.angles, target[name]
		for i = 1, 5 do a[i] += ((goal[i] or 0) - a[i]) * follow end
		local pitch, yaw, roll, bend, twist = FourArms.angles(info.side, a)
		-- (the same order as FourArms.solve, which the tests check: roll, pitch, yaw; twist innermost)
		info.shoulder.C0 = info.shoulderBase * CFrame.Angles(0, rad(yaw), 0) * CFrame.Angles(rad(pitch), 0, 0) * CFrame.Angles(0, 0, rad(roll))
			* CFrame.Angles(0, rad(twist), 0)
		info.elbow.C0 = info.elbowBase * CFrame.Angles(rad(bend), 0, 0)
	end
end

function AnimationController:update(view, other, dt, now, poseRate, cinematic)
	local pose, lift = self.animator:step(view, other, dt, now, poseRate, cinematic)
	self:swingFourArms(view, dt, now)
	if self.retarget then
		local c0, _, parts, virtual = Retarget.solve(self.retarget, pose, view.y or 0)
		for name, info in self.joints do
			local value = c0[name]
			if value then info.joint.C0 = CFrame.new(table.unpack(value)) end
		end
		for _, held in self.weapons or {} do
			local hand, arm = virtual[held.spec.hand], parts[held.arm]
			if hand and arm then
				local size, g = self.retarget.virtual.sizes[held.spec.hand], held.spec.grip
				local grip = Kinematics.mul(Kinematics.mul(hand, Kinematics.translation(0, size[2] * g.y, g.z)),
					Kinematics.angles(rad(g.tilt), 0, 0))
				held.weld.C0 = CFrame.new(table.unpack(Kinematics.mul(Kinematics.inverse(arm), grip))) * held.offset
			end
		end
		self:swayTails(dt, now)
		return
	end
	for name, info in self.joints do
		local v = pose[name]
		local offset = CFrame.identity
		if v then
			offset = CFrame.Angles(rad(v[1] or 0), rad(v[2] or 0), rad(v[3] or 0))
			if name == "Root" then
				offset = CFrame.new(v[6] or 0, v[4] or 0, v[5] or 0) * offset
			end
		end
		if name == "Root" then
			info.joint.C0 = CFrame.new(0, lift, 0) * info.base * offset
		else
			info.joint.C0 = info.base * offset
		end
	end
	self:swayTails(dt, now)
end

-- Cloth sway: each tail lags behind the motion of the point it hangs from (springs), with a
-- light flutter. Purely cosmetic and local.
function AnimationController:swayTails(dt, now)
	if dt <= 0 then return end
	for _, tail in self.tails do
		local anchor = tail.anchor
		if not anchor.Parent then continue end
		local point = (anchor.CFrame * tail.base).Position
		local velocity = if tail.last then (point - tail.last) / dt else Vector3.zero
		tail.last = point
		if velocity.Magnitude > 80 then velocity = Vector3.zero end -- teleports (new round, blinks)
		-- (a hanging tail (Hang: YUKINA's tassels) always falls toward the floor, whatever its
		-- anchor's turn: it swings in world axes)
		local localVelocity = if tail.hang then velocity else anchor.CFrame:VectorToObjectSpace(velocity)
		local flutter = math.sin(now * 7 + tail.seed) * 3 + math.sin(now * 11.3 + tail.seed * 2) * 1.5
		local targetX = math.clamp(localVelocity.Z * 2.4, -70, 70) + flutter
		local targetZ = math.clamp(-localVelocity.X * 2.4, -55, 55) + flutter * 0.4
		local ax = Kinematics.spring(tail.swingX, targetX, dt, 1.7, 0.28)
		local az = Kinematics.spring(tail.swingZ, targetZ, dt, 1.5, 0.3)
		if tail.hang then
			tail.weld.C0 = anchor.CFrame:ToObjectSpace(CFrame.new(point)) * CFrame.Angles(rad(ax), 0, rad(az))
		else
			tail.weld.C0 = tail.base * CFrame.Angles(rad(ax), 0, rad(az))
		end
	end
end

return AnimationController
