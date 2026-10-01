--[[
	Bind geometry of the KAI block rig, shared by the server RigBuilder (which builds the parts
	and the 15 Motor6D) and the offline animation tests (which rebuild the same skeleton with
	forward kinematics). Pure data: positions are part centers relative to the
	HumanoidRootPart in the bind pose, pivots are joint positions in the same space. Every
	part is axis-aligned in the bind pose; the rig faces -Z.
]]
local function v(x, y, z)
	return table.freeze({ x, y, z })
end

local parts = {
	HumanoidRootPart = { size = v(2, 2, 1), pos = v(0, 0, 0) },
	LowerTorso = { size = v(1.7, 0.65, 0.95), pos = v(0, 0, 0) },
	UpperTorso = { size = v(1.9, 1.4, 1), pos = v(0, 1, 0) },
	Head = { size = v(1.1, 1.1, 1), pos = v(0, 2.3, 0) },
}
local joints = {
	{ name = "Root", part0 = "HumanoidRootPart", part1 = "LowerTorso", pivot = v(0, 0, 0) },
	{ name = "Waist", part0 = "LowerTorso", part1 = "UpperTorso", pivot = v(0, 0.35, 0) },
	{ name = "Neck", part0 = "UpperTorso", part1 = "Head", pivot = v(0, 1.72, 0) },
}
for _, side in { "Left", "Right" } do
	local s = if side == "Left" then -1 else 1
	-- Sleeveless: bare arms, wrapped forearms and fists.
	parts[side .. "UpperArm"] = { size = v(0.7, 1.1, 0.76), pos = v(s * 1.37, 0.92, 0) }
	parts[side .. "LowerArm"] = { size = v(0.62, 0.95, 0.66), pos = v(s * 1.37, -0.08, 0) }
	parts[side .. "Hand"] = { size = v(0.74, 0.62, 0.76), pos = v(s * 1.37, -0.8, 0) }
	-- Baggy martial-arts pants, sneakers.
	parts[side .. "UpperLeg"] = { size = v(0.86, 1.25, 0.92), pos = v(s * 0.47, -0.95, 0) }
	parts[side .. "LowerLeg"] = { size = v(0.8, 1.05, 0.86), pos = v(s * 0.47, -2.08, 0) }
	parts[side .. "Foot"] = { size = v(0.8, 0.42, 1.2), pos = v(s * 0.47, -2.8, -0.15) }
	table.insert(joints, { name = side .. "Shoulder", part0 = "UpperTorso", part1 = side .. "UpperArm", pivot = v(s * 1.1, 1.5, 0) })
	table.insert(joints, { name = side .. "Elbow", part0 = side .. "UpperArm", part1 = side .. "LowerArm", pivot = v(s * 1.37, 0.4, 0) })
	table.insert(joints, { name = side .. "Wrist", part0 = side .. "LowerArm", part1 = side .. "Hand", pivot = v(s * 1.37, -0.55, 0) })
	table.insert(joints, { name = side .. "Hip", part0 = "LowerTorso", part1 = side .. "UpperLeg", pivot = v(s * 0.47, -0.3, 0) })
	table.insert(joints, { name = side .. "Knee", part0 = side .. "UpperLeg", part1 = side .. "LowerLeg", pivot = v(s * 0.47, -1.57, 0) })
	table.insert(joints, { name = side .. "Ankle", part0 = side .. "LowerLeg", part1 = side .. "Foot", pivot = v(s * 0.47, -2.6, 0) })
end
for _, p in parts do table.freeze(p) end
for _, j in joints do table.freeze(j) end

return table.freeze({
	KAI = table.freeze({
		parts = table.freeze(parts),
		joints = table.freeze(joints), -- parent first
		rootHeight = 3,
	}),
	-- The 15 joints every fighter rig must have (KAI and Roblox R15 avatars share the names).
	JOINTS = table.freeze({
		"Root", "Waist", "Neck", "LeftShoulder", "LeftElbow", "LeftWrist", "RightShoulder", "RightElbow",
		"RightWrist", "LeftHip", "LeftKnee", "LeftAnkle", "RightHip", "RightKnee", "RightAnkle",
	}),
})
