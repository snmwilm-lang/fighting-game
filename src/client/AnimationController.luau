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

local rad = math.rad

local AnimationController = {}
AnimationController.__index = AnimationController

function AnimationController.new(model)
	local skeleton, motors, rigType = RigReader.skeleton(model)
	local self = setmetatable({ model = model, joints = {}, tails = {} }, AnimationController)
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
	-- Root height that rests the bind pose's feet on the floor, measured on this body.
	self.rootHeight = if self.retarget then -skeleton.floor else self.animator.rootHeight
	-- Cloth tails (sash, headband) hang from Welds named TailJoint (see RigBuilder).
	for _, d in model:GetDescendants() do
		if d:IsA("Weld") and d.Name == "TailJoint" and d.Part0 and d.Part1 then
			table.insert(self.tails, {
				weld = d, base = d.C0, anchor = d.Part0, length = d.Part1.Size.Y,
				swingX = { x = 0, v = 0 }, swingZ = { x = 0, v = 0 }, seed = #self.tails * 1.7,
			})
		end
	end
	return self
end

-- view: the displayed snapshot of this fighter ({ state, move, moveFrame, x, y, vx, vy,
-- facing, hitstop, combo, victory, intro, pose }); other: the opponent's view.
function AnimationController:update(view, other, dt, now, poseRate, cinematic)
	local pose, lift = self.animator:step(view, other, dt, now, poseRate, cinematic)
	if self.retarget then
		local c0 = Retarget.solve(self.retarget, pose, view.y or 0)
		for name, info in self.joints do
			local value = c0[name]
			if value then info.joint.C0 = CFrame.new(table.unpack(value)) end
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
		local localVelocity = anchor.CFrame:VectorToObjectSpace(velocity)
		local flutter = math.sin(now * 7 + tail.seed) * 3 + math.sin(now * 11.3 + tail.seed * 2) * 1.5
		local targetX = math.clamp(localVelocity.Z * 2.4, -70, 70) + flutter
		local targetZ = math.clamp(-localVelocity.X * 2.4, -55, 55) + flutter * 0.4
		local ax = Kinematics.spring(tail.swingX, targetX, dt, 1.7, 0.28)
		local az = Kinematics.spring(tail.swingZ, targetZ, dt, 1.5, 0.3)
		tail.weld.C0 = tail.base * CFrame.Angles(rad(ax), 0, rad(az))
	end
end

return AnimationController
