-- Reads the skeleton of a live fighter rig (KAI or a Roblox R15 avatar): its 15 Motor6D
-- (C0 / C1) and the size of each body part, in the format of the pure Kinematics module.
-- Used by the server (to measure and scale avatars) and by the client AnimationController.
local Shared = script.Parent
local Kinematics = require(Shared.Kinematics)
local RigSpec = require(Shared.RigSpec)

local RigReader = {}

-- Returns the skeleton (nil when a joint is missing) and the joint name -> Motor6D map.
function RigReader.skeleton(model)
	local joints, sizes, motors = {}, {}, {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and table.find(RigSpec.JOINTS, d.Name) and d.Part0 and d.Part1 and not motors[d.Name] then
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
	if #joints < #RigSpec.JOINTS then return nil, motors end
	local ok, skeleton = pcall(Kinematics.skeleton, joints, sizes)
	return if ok then skeleton else nil, motors
end

-- Standing height of the body in its bind pose: sole to the top of the head (no accessory).
function RigReader.height(skeleton)
	local head, size = skeleton.bind.Head, skeleton.sizes.Head
	if not head or not size then return nil end
	return head[2] + size[2] / 2 - skeleton.floor
end

return RigReader
