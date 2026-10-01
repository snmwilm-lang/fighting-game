-- Presentation only. Stepped joint poses never change simulation timing.
local AnimationController = {}
function AnimationController.new(model)
	local self = { joints = {}, model = model, lastPose = -1 }
	for _, joint in model:GetDescendants() do
		if joint:IsA("Motor6D") then self.joints[joint.Name] = { joint = joint, base = joint.C0 } end
	end
	return setmetatable(self, { __index = AnimationController })
end
function AnimationController:update(state, time, poseRate)
	local frame = math.floor(time * poseRate)
	if frame == self.lastPose and state == self.lastState then return end
	self.lastPose, self.lastState = frame, state
	local t = frame / poseRate
	local walk = if state == "Walking" then math.sin(t * 12) else 0
	local air = state == "Jumping" or state == "Falling"
	local crouch = state == "Crouching"
	local dash = state == "Dashing"
	local breathing = math.sin(t * 3) * 0.025
	local angles = {
		Root = CFrame.new(0, if crouch then -0.7 else breathing, 0),
		Waist = CFrame.Angles(math.rad(if dash then -23 elseif crouch then -14 else -5), 0, 0),
		Neck = CFrame.Angles(math.rad(5), 0, 0),
		LeftShoulder = CFrame.Angles(math.rad(52 + walk * 12), 0, math.rad(-10)),
		RightShoulder = CFrame.Angles(math.rad(68 - walk * 12), 0, math.rad(12)),
		LeftElbow = CFrame.Angles(math.rad(65), 0, 0),
		RightElbow = CFrame.Angles(math.rad(75), 0, 0),
		LeftHip = CFrame.Angles(math.rad(if crouch then 45 elseif air then 40 else walk * 26), 0, math.rad(-5)),
		RightHip = CFrame.Angles(math.rad(if crouch then 45 elseif air then -15 else -walk * 26), 0, math.rad(5)),
		LeftKnee = CFrame.Angles(math.rad(if crouch then -80 elseif air then -60 else -math.max(0, -walk) * 30), 0, 0),
		RightKnee = CFrame.Angles(math.rad(if crouch then -80 elseif air then -35 else -math.max(0, walk) * 30), 0, 0),
	}
	for name, info in self.joints do
		info.joint.C0 = info.base * (angles[name] or CFrame.identity)
	end
end
return AnimationController
