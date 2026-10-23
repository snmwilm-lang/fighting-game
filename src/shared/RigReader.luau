-- Reads the skeleton of a live fighter rig (KAI, a Roblox R15 avatar or an R6 avatar): its
-- Motor6D (C0 / C1) and the size of each body part, in the format of the pure Kinematics
-- module. Used by the server (to measure and scale avatars) and by the client.
local Shared = script.Parent
local Kinematics = require(Shared.Kinematics)
local RigSpec = require(Shared.RigSpec)

local RigReader = {}

-- "R6" for a classic 6-part body, "R15" otherwise (KAI is an R15 rig).
function RigReader.rigType(model)
	return if model:FindFirstChild("Torso") and not model:FindFirstChild("UpperTorso") then "R6" else "R15"
end

-- Returns the skeleton (nil when a joint is missing), the joint name -> Motor6D map and the
-- rig type.
function RigReader.skeleton(model)
	local rigType = RigReader.rigType(model)
	local names = if rigType == "R6" then RigSpec.R6_JOINTS else RigSpec.JOINTS
	local joints, sizes, motors = {}, {}, {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and table.find(names, d.Name) and d.Part0 and d.Part1 and not motors[d.Name] then
			motors[d.Name] = d
			table.insert(joints, {
				name = d.Name, part0 = d.Part0.Name, part1 = d.Part1.Name,
				c0 = { d.C0:GetComponents() }, c1 = { d.C1:GetComponents() },
			})
			local a, b = d.Part0.Size, d.Part1.Size
			sizes[d.Part1.Name] = { b.X, b.Y, b.Z }
			sizes[d.Part0.Name] = sizes[d.Part0.Name] or { a.X, a.Y, a.Z }
		end
	end
	if #joints < #names then return nil, motors, rigType end
	local ok, skeleton = pcall(Kinematics.skeleton, joints, sizes)
	return if ok then skeleton else nil, motors, rigType
end

--[[
	The animation drives Motor6D joints with RigSpec's names. A body built by Roblox can
	arrive without them: Roblox's avatar joint upgrade replaces R15 Motor6D by
	AnimationConstraint (+ BallSocketConstraint), and some bodies carry a joint under another
	name. Every missing Motor6D is rebuilt between the same two parts, from their rig
	attachments (as Humanoid:BuildRigFromAttachments does), else from the standard R6 joint
	frames or the KAI rig's pivots scaled to the parts; the joints it replaces between those
	two parts are removed. Returns the number of joints rebuilt (0 for a body already fine).
	The server calls it on every body; a client only on a body whose joints never arrived.
]]
local function cframe(c, k)
	return CFrame.new(c[1] * k, c[2] * k, c[3] * k, c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12])
end
local REPLACED = { "AnimationConstraint", "BallSocketConstraint", "HingeConstraint", "Weld", "WeldConstraint", "Motor6D" }

function RigReader.ensureJoints(model)
	local rigType = RigReader.rigType(model)
	local list = if rigType == "R6" then RigSpec.R6.joints else RigSpec.KAI.joints
	local found = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 then found[d.Name] = d end
	end
	local rebuilt = 0
	for _, j in list do
		local part0, part1 = model:FindFirstChild(j.part0), model:FindFirstChild(j.part1)
		if not found[j.name] and part0 and part1 and part0:IsA("BasePart") and part1:IsA("BasePart") then
			local c0, c1
			local a0, a1 = part0:FindFirstChild(j.name .. "RigAttachment"), part1:FindFirstChild(j.name .. "RigAttachment")
			if a0 and a1 and a0:IsA("Attachment") and a1:IsA("Attachment") then
				c0, c1 = a0.CFrame, a1.CFrame
			elseif rigType == "R6" then
				local torso = model:FindFirstChild("Torso")
				local k = if torso and torso:IsA("BasePart") then torso.Size.Y / 2 else 1
				c0, c1 = cframe(j.c0, k), cframe(j.c1, k)
			else
				-- The KAI rig's pivot, placed on this body's part in proportion to its size.
				local spec = RigSpec.KAI.parts[j.part1]
				local s = part1.Size
				local offset = Vector3.new(
					(j.pivot[1] - spec.pos[1]) / spec.size[1] * s.X,
					(j.pivot[2] - spec.pos[2]) / spec.size[2] * s.Y,
					(j.pivot[3] - spec.pos[3]) / spec.size[3] * s.Z)
				local pivot = part1.CFrame * CFrame.new(offset)
				c0, c1 = part0.CFrame:ToObjectSpace(pivot), part1.CFrame:ToObjectSpace(pivot)
			end
			-- Whatever joined these two parts before goes (accessory welds join other parts).
			for _, d in model:GetDescendants() do
				for _, class in REPLACED do
					if d:IsA(class) then
						local p0, p1
						if d:IsA("Constraint") then
							p0 = d.Attachment0 and d.Attachment0.Parent
							p1 = d.Attachment1 and d.Attachment1.Parent
						else
							p0, p1 = d.Part0, d.Part1
						end
						if (p0 == part0 and p1 == part1) or (p0 == part1 and p1 == part0) then d:Destroy() end
						break
					end
				end
			end
			local motor = Instance.new("Motor6D")
			motor.Name, motor.Part0, motor.Part1, motor.C0, motor.C1 = j.name, part0, part1, c0, c1
			motor.Parent = if rigType == "R6" then part0 else part1
			found[j.name] = motor
			rebuilt += 1
		end
	end
	return rebuilt
end

-- R15 part names used by effects and cinematics, found on an R6 body too.
local R6_ALIASES = {
	UpperTorso = "Torso", LowerTorso = "Torso",
	LeftUpperArm = "Left Arm", LeftLowerArm = "Left Arm", LeftHand = "Left Arm",
	RightUpperArm = "Right Arm", RightLowerArm = "Right Arm", RightHand = "Right Arm",
	LeftUpperLeg = "Left Leg", LeftLowerLeg = "Left Leg", LeftFoot = "Left Leg",
	RightUpperLeg = "Right Leg", RightLowerLeg = "Right Leg", RightFoot = "Right Leg",
}
local TIPS = { LeftHand = true, RightHand = true, LeftFoot = true, RightFoot = true }

-- The part standing for an R15 part name and the world point it means (on an R6 limb, a hand
-- or a foot is the end of the arm or leg).
function RigReader.part(model, name)
	local part = model:FindFirstChild(name)
	if part and part:IsA("BasePart") then return part, part.Position end
	local alias = R6_ALIASES[name]
	part = alias and model:FindFirstChild(alias)
	if not part or not part:IsA("BasePart") then return nil, nil end
	if TIPS[name] then return part, (part.CFrame * CFrame.new(0, -part.Size.Y * 0.4, 0)).Position end
	return part, part.Position
end
RigReader.R6_ALIASES = R6_ALIASES

-- Standing height of the body in its bind pose: sole to the top of the head (no accessory).
function RigReader.height(skeleton)
	local head, size = skeleton.bind.Head, skeleton.sizes.Head
	if not head or not size then return nil end
	return head[2] + size[2] / 2 - skeleton.floor
end

return RigReader
