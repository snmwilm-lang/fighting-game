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
