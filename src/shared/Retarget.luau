--[[
	R6 support, pure (no Roblox API, no require: Kinematics is passed in).

	An R6 body has 6 rigid parts and 6 joints: no waist, elbows, wrists, knees or ankles. The
	animation still runs on a virtual R15 skeleton with the proportions of the R6 body (so the
	Animator, its leg IK and its timelines work unchanged); each R6 limb is then aimed along
	its virtual limb: the arm from the shoulder to the fist, the leg from the hip to the sole,
	turned like the virtual forearm / foot. The torso follows the virtual chest, the head the
	virtual head. Finally the R6 body is grounded with its own geometry (its legs cannot bend,
	so a deep crouch splays them instead).

	  local rt = Retarget.new(Kinematics, r6Skeleton)   -- Kinematics.skeleton of the R6 joints
	  -- animate rt.virtual with the Animator, then:
	  local c0, lift = Retarget.solve(rt, pose, altitude) -- joint name -> C0 (12 numbers)
]]
local Retarget = {}

local ARMS = { { side = "Left", joint = "Left Shoulder", part = "Left Arm" }, { side = "Right", joint = "Right Shoulder", part = "Right Arm" } }
local LEGS = { { side = "Left", joint = "Left Hip", part = "Left Leg" }, { side = "Right", joint = "Right Hip", part = "Right Leg" } }

local function v3(t)
	return { t[1], t[2], t[3] }
end

-- Virtual R15 spec (RigSpec format) proportioned like an R6 skeleton in its bind pose.
function Retarget.virtualSpec(r6)
	local bind, sizes = r6.bind, r6.sizes
	local torso, ts = bind.Torso, sizes.Torso
	local tx, ty, tz = torso[1], torso[2], torso[3]
	local tw, th, td = ts[1], ts[2], ts[3]
	local lowerH = th * 0.3
	local bottom = ty - th / 2
	local head = bind.Head
	local parts = {
		HumanoidRootPart = { size = v3(sizes.HumanoidRootPart or { 2, 2, 1 }), pos = { 0, 0, 0 } },
		LowerTorso = { size = { tw * 0.9, lowerH, td }, pos = { tx, bottom + lowerH / 2, tz } },
		UpperTorso = { size = { tw, th - lowerH, td }, pos = { tx, bottom + lowerH + (th - lowerH) / 2, tz } },
		Head = { size = v3(sizes.Head), pos = { head[1], head[2], head[3] } },
	}
	local joints = {
		{ name = "Root", part0 = "HumanoidRootPart", part1 = "LowerTorso", pivot = parts.LowerTorso.pos },
		{ name = "Waist", part0 = "LowerTorso", part1 = "UpperTorso", pivot = { tx, bottom + lowerH, tz } },
		{ name = "Neck", part0 = "UpperTorso", part1 = "Head", pivot = { tx, ty + th / 2, tz } },
	}
	for _, arm in ARMS do
		local a, s = bind[arm.part], sizes[arm.part]
		local top, h = a[2] + s[2] / 2, s[2]
		local x, z = a[1], a[3]
		local side = arm.side
		parts[side .. "UpperArm"] = { size = { s[1], h * 0.45, s[3] }, pos = { x, top - h * 0.225, z } }
		parts[side .. "LowerArm"] = { size = { s[1] * 0.9, h * 0.375, s[3] * 0.9 }, pos = { x, top - h * 0.6375, z } }
		parts[side .. "Hand"] = { size = { s[1], h * 0.175, s[3] }, pos = { x, top - h * 0.9125, z } }
		table.insert(joints, { name = side .. "Shoulder", part0 = "UpperTorso", part1 = side .. "UpperArm", pivot = { x, top - h * 0.05, z } })
		table.insert(joints, { name = side .. "Elbow", part0 = side .. "UpperArm", part1 = side .. "LowerArm", pivot = { x, top - h * 0.45, z } })
		table.insert(joints, { name = side .. "Wrist", part0 = side .. "LowerArm", part1 = side .. "Hand", pivot = { x, top - h * 0.825, z } })
	end
	for _, leg in LEGS do
		local l, s = bind[leg.part], sizes[leg.part]
		local top, h = l[2] + s[2] / 2, s[2]
		local x, z = l[1], l[3]
		local side = leg.side
		parts[side .. "UpperLeg"] = { size = { s[1], h * 0.475, s[3] }, pos = { x, top - h * 0.2375, z } }
		parts[side .. "LowerLeg"] = { size = { s[1] * 0.9, h * 0.375, s[3] * 0.9 }, pos = { x, top - h * 0.6625, z } }
		parts[side .. "Foot"] = { size = { s[1], h * 0.15, s[3] }, pos = { x, top - h * 0.925, z } }
		table.insert(joints, { name = side .. "Hip", part0 = "LowerTorso", part1 = side .. "UpperLeg", pivot = { x, top, z } })
		table.insert(joints, { name = side .. "Knee", part0 = side .. "UpperLeg", part1 = side .. "LowerLeg", pivot = { x, top - h * 0.475, z } })
		table.insert(joints, { name = side .. "Ankle", part0 = side .. "LowerLeg", part1 = side .. "Foot", pivot = { x, top - h * 0.85, z } })
	end
	return { parts = parts, joints = joints }
end

function Retarget.new(kin, r6)
	local spec = Retarget.virtualSpec(r6)
	local virtual = kin.fromSpec(spec)
	-- Bind offset from the virtual chest to the R6 torso centre.
	local ut, torso = spec.parts.UpperTorso.pos, r6.bind.Torso
	return {
		kin = kin, r6 = r6, virtual = virtual, spec = spec,
		torsoOffset = { torso[1] - ut[1], torso[2] - ut[2], torso[3] - ut[3] },
	}
end

local function normalize(x, y, z)
	local l = math.sqrt(x * x + y * y + z * z)
	if l < 1e-6 then return 0, 0, 0, 0 end
	return x / l, y / l, z / l, l
end

-- Rotation whose +Y axis is (yx, yy, yz) and whose +Z axis is as close as possible to zRef.
local function aimFrame(yx, yy, yz, zx, zy, zz)
	yx, yy, yz = normalize(yx, yy, yz)
	local d = zx * yx + zy * yy + zz * yz
	zx, zy, zz = zx - d * yx, zy - d * yy, zz - d * yz
	local l
	zx, zy, zz, l = normalize(zx, zy, zz)
	if l < 1e-4 then
		-- zRef along the limb: any perpendicular will do.
		zx, zy, zz = normalize(-yy, yx, 0)
		if zx == 0 and zy == 0 then zx, zy, zz = 0, 0, 1 end
	end
	local xx, xy, xz = yy * zz - yz * zy, yz * zx - yx * zz, yx * zy - yy * zx
	return { 0, 0, 0, xx, yx, zx, xy, yy, zy, xz, yz, zz }
end

-- Rotation-only copy of the inverse of c1inv, i.e. the rotation of C1.
local function c1Rotation(kin, joint)
	return kin.rotation(kin.inverse(joint.c1inv))
end

--[[
	pose: the virtual R15 pose from the Animator (degrees). Returns the C0 of every R6 joint
	(12-number arrays, Motor6D.C0 components) and the grounding lift already included in the
	RootJoint C0. `altitude` is the fighter's height above the floor.
]]
function Retarget.solve(rt, pose, altitude)
	local kin, r6, virtual = rt.kin, rt.r6, rt.virtual
	local v = kin.solve(virtual, pose, 0)
	local o = rt.torsoOffset
	local torso = kin.mul(v.UpperTorso, kin.translation(o[1], o[2], o[3]))
	local jitter = pose.Root and pose.Root[6] or 0
	torso[1] += jitter
	local torsoInv = kin.inverse(torso)
	local joints = r6.joints
	local c0 = {}
	local parts = { Torso = torso }

	local function place(name, limbRotation)
		local joint = joints[name]
		if not joint then return end
		local rel = kin.mul(kin.rotation(torsoInv), limbRotation)
		local value = kin.mul(kin.translation(joint.c0[1], joint.c0[2], joint.c0[3]), kin.mul(rel, c1Rotation(kin, joint)))
		c0[name] = value
		parts[joint.part1] = kin.mul(kin.mul(torso, value), joint.c1inv)
	end
	-- Head: as the virtual head.
	place("Neck", kin.rotation(v.Head))
	-- A limb turns around its joint pivot, which sits on its top edge (not on its axis): the
	-- rotation brings the pivot -> bottom-centre line of the R6 part onto the pivot -> target
	-- line, twisted like the reference axis zRef.
	local function aim(limb, target, zRef)
		local joint = joints[limb.joint]
		if not joint or not target then return end
		local size = r6.sizes[limb.part]
		local c1 = kin.inverse(joint.c1inv)
		local ux, uy, uz = -c1[1], -size[2] / 2 - c1[2], -c1[3] -- pivot -> bottom centre, part space
		local px, py, pz = kin.point(torso, joint.c0[1], joint.c0[2], joint.c0[3])
		local tx, ty, tz = target[1], target[2], target[3]
		local world = aimFrame(px - tx, py - ty, pz - tz, zRef[1], zRef[2], zRef[3])
		local localFrame = aimFrame(-ux, -uy, -uz, 0, 0, 1)
		place(limb.joint, kin.mul(world, kin.inverse(localFrame)))
	end
	-- Arms: toward the fist, turned like the forearm.
	for _, arm in ARMS do
		local hand, lower = v[arm.side .. "Hand"], v[arm.side .. "LowerArm"]
		if hand and lower then
			local size = virtual.sizes[arm.side .. "Hand"]
			aim(arm, { kin.point(hand, 0, -size[2] / 2, 0) }, { lower[6], lower[9], lower[12] })
		end
	end
	-- Legs: toward the sole, turned like the foot.
	for _, leg in LEGS do
		local foot = v[leg.side .. "Foot"]
		if foot then
			local size = virtual.sizes[leg.side .. "Foot"]
			aim(leg, { kin.point(foot, 0, -size[2] / 2, 0) }, { foot[6], foot[9], foot[12] })
		end
	end

	-- Grounding with the R6 body itself.
	local lowest = math.huge
	for name, t in parts do
		local size = r6.sizes[name]
		if size then lowest = math.min(lowest, kin.boxBottom(t, size[1] / 2, size[2] / 2, size[3] / 2)) end
	end
	altitude = math.max(0, altitude or 0)
	local floor = r6.floor - altitude
	local weight = math.clamp(pose.Ground and pose.Ground[1] or 1, 0, 1) * math.clamp(1 - altitude / 0.8, 0, 1)
	local lift = weight * (floor - lowest)
	if lowest + lift < floor then lift = floor - lowest end

	-- RootJoint: Part1 = Part0 * C0 * C1^-1 with Part0 the root, so C0 = torso * C1.
	local root = joints.RootJoint
	local rootC0 = kin.mul(torso, kin.inverse(root.c1inv))
	rootC0[2] += lift
	c0.RootJoint = rootC0
	return c0, lift, parts
end

return Retarget
