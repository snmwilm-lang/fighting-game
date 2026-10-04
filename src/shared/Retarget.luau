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

-- Style of the R6 retarget (the R6 fighting look: low wide stance, fists up in front).
-- ARM_REACH: where a rigid arm aims along the virtual forearm (0 = elbow, 1 = fist).
-- STANCE_DEPTH: share of the virtual hip height kept by planted legs (lower = wider stance).
Retarget.ARM_REACH = 0.7
Retarget.STANCE_DEPTH = 0.88
-- ARM_GUARD_PITCH: a bent virtual arm (a guard) becomes a rigid arm pointed at the opponent,
-- this many degrees under the horizontal; it straightens toward the fist as the arm extends.
Retarget.ARM_GUARD_PITCH = 38
-- LEG_KEEP: share of the gap between the virtual hip height and the full leg length that a
-- planted rigid leg keeps (0 = the virtual height: wide compass legs; 1 = always straight).
Retarget.LEG_KEEP = 0.75
-- CHEST_SHARE: how much the rigid R6 torso turns like the virtual chest (the rest like the hips).
Retarget.CHEST_SHARE = 0.7

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
	return { kin = kin, r6 = r6, virtual = virtual, spec = spec }
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
	RootJoint C0, then the R6 parts and the virtual R15 parts in the same space (a weapon is
	held by the virtual hand, wrist included: see AnimationController, WeaponKit). `altitude` is the fighter's height above the floor.
]]
function Retarget.solve(rt, pose, altitude)
	local kin, r6, virtual = rt.kin, rt.r6, rt.virtual
	local v = kin.solve(virtual, pose, 0)
	-- One rigid torso for the virtual hips and chest: turned mostly like the chest
	-- (CHEST_SHARE), since it carries the whole twist of a punch, hung on the virtual waist.
	local lower, upper = v.LowerTorso, v.UpperTorso
	local cw = Retarget.CHEST_SHARE
	local lw = 1 - cw
	local torso = aimFrame(lower[5] * lw + upper[5] * cw, lower[8] * lw + upper[8] * cw, lower[11] * lw + upper[11] * cw,
		lower[6] * lw + upper[6] * cw, lower[9] * lw + upper[9] * cw, lower[12] * lw + upper[12] * cw)
	local waist = virtual.joints.Waist.c0
	local wx, wy, wz = kin.point(lower, waist[1], waist[2], waist[3])
	local below = r6.sizes.Torso[2] * 0.2 -- the waist sits this far below the torso's centre
	local jitter = pose.Root and pose.Root[6] or 0
	torso[1], torso[2], torso[3] = wx + torso[5] * below + jitter, wy + torso[8] * below, wz + torso[11] * below
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
	local function reach(limb)
		local joint, size = joints[limb.joint], r6.sizes[limb.part]
		local c1 = kin.inverse(joint.c1inv)
		return -c1[1], -size[2] / 2 - c1[2], -c1[3] -- pivot -> bottom centre, part space
	end
	local function aim(limb, target, zRef)
		local joint = joints[limb.joint]
		if not joint or not target then return end
		local ux, uy, uz = reach(limb)
		local px, py, pz = kin.point(torso, joint.c0[1], joint.c0[2], joint.c0[3])
		local world = aimFrame(px - target[1], py - target[2], pz - target[3], zRef[1], zRef[2], zRef[3])
		local localFrame = aimFrame(-ux, -uy, -uz, 0, 0, 1)
		place(limb.joint, kin.mul(world, kin.inverse(localFrame)))
	end
	-- A rigid arm aims at the middle of the virtual forearm: along the fist when the arm is
	-- straight (punches), forward when it is bent, so a guard raises the arms instead of
	-- pointing them at the chin through the head.
	local function between(a, b, t)
		return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
	end
	-- Arms: toward the forearm, turned like it.
	for _, arm in ARMS do
		local hand, forearm = v[arm.side .. "Hand"], v[arm.side .. "LowerArm"]
		if hand and forearm then
			local size, lowerSize = virtual.sizes[arm.side .. "Hand"], virtual.sizes[arm.side .. "LowerArm"]
			local fist = { kin.point(hand, 0, -size[2] / 2, 0) }
			local elbow = { kin.point(forearm, 0, lowerSize[2] / 2, 0) }
			-- Straight arm (punch): toward the fist; bent arm (guard): toward the elbow.
			local sh = virtual.joints[arm.side .. "Shoulder"].c0
			local sx, sy, sz = kin.point(upper, sh[1], sh[2], sh[3])
			local reachTotal = virtual.sizes[arm.side .. "UpperArm"][2] + lowerSize[2] + size[2]
			local fx, fy, fz = fist[1] - sx, fist[2] - sy, fist[3] - sz
			-- (a guard holds the fist at 45-75 % of the arm's reach, a strike at about 95 %)
			local straight = math.clamp((math.sqrt(fx * fx + fy * fy + fz * fz) / reachTotal - 0.78) / 0.15, 0, 1)
			-- A fist raised above the head (overheads, victory) keeps its own line.
			straight = math.max(straight, math.clamp((fy - 1.4) / 0.5, 0, 1))
			local mid = between(elbow, fist, Retarget.ARM_REACH)
			-- From the virtual shoulder toward that point, as far as the arm is long (its fist
			-- in the bind pose: the shoulder pivot sits 5 % below the top, see virtualSpec).
			local shoulder = virtual.joints[arm.side .. "Shoulder"].c0
			local ox, oy, oz = kin.point(upper, shoulder[1], shoulder[2], shoulder[3])
			local dx, dy, dz = normalize(mid[1] - ox, mid[2] - oy, mid[3] - oz)
			-- Bent arm (guard): the R6 guard, toward the opponent (the chest's front) and pitched
			-- down, never at the face nor out to the side.
			if straight < 1 then
				-- chest forward (-Z), turned a little toward the body's centre line (+-X)
				local inward = if arm.side == "Left" then 0.22 else -0.22
				local hx, hz = -upper[6] + upper[4] * inward, -upper[12] + upper[10] * inward
				local hl = math.sqrt(hx * hx + hz * hz)
				if hl < 1e-3 then hx, hz, hl = 0, -1, 1 end
				local pitch = math.rad(Retarget.ARM_GUARD_PITCH)
				local gx, gy, gz = hx / hl * math.cos(pitch), -math.sin(pitch), hz / hl * math.cos(pitch)
				dx, dy, dz = normalize(gx + (dx - gx) * straight, gy + (dy - gy) * straight, gz + (dz - gz) * straight)
			end
			local length = r6.sizes[arm.part][2] * 0.95
			aim(arm, { ox + dx * length, oy + dy * length, oz + dz * length }, { forearm[6], forearm[9], forearm[12] })
		end
	end
	-- Legs. A rigid R6 leg cannot fold, so a bent virtual leg is turned into a splayed one of
	-- full length: planted, its tip stays at the sole's height and goes out horizontally
	-- toward the foot (the hips keep the virtual height, so a crouch lowers the body and the
	-- legs splay forward and back); in the air (chambers, jumps) it points along the middle
	-- of the shin. A straight leg lands exactly on the sole either way.
	local floorY = virtual.floor
	local legs, stance = {}, 0
	for _, leg in LEGS do
		local foot, shin, hipJoint = v[leg.side .. "Foot"], v[leg.side .. "LowerLeg"], virtual.joints[leg.side .. "Hip"]
		if foot and shin and hipJoint and joints[leg.joint] then
			local size, shinSize = virtual.sizes[leg.side .. "Foot"], virtual.sizes[leg.side .. "LowerLeg"]
			local sole = { kin.point(foot, 0, -size[2] / 2, 0) }
			local knee = { kin.point(shin, 0, shinSize[2] / 2, 0) }
			local hx, hy, hz = kin.point(lower, hipJoint.c0[1], hipJoint.c0[2], hipJoint.c0[3])
			local length = r6.sizes[leg.part][2] -- the virtual leg's full length (virtualSpec)
			-- Planted: same height as the sole, horizontally toward it (or the knee).
			-- A bent planted leg sinks a little further (STANCE_DEPTH); a straight one does not.
			local sx, sy, sz = sole[1] - hx, sole[2] - hy, sole[3] - hz
			local bend = math.clamp((1 - math.sqrt(sx * sx + sy * sy + sz * sz) / length) / 0.1, 0, 1)
			local drop = math.min((hy - sole[2]) * (1 + (Retarget.STANCE_DEPTH - 1) * bend), length)
			stance = math.max(stance, drop / length)
			table.insert(legs, { leg = leg, foot = foot, sole = sole, knee = knee, hip = { hx, hy, hz }, length = length, drop = drop })
		end
	end
	-- Only a standing stance straightens (its higher hip above 60 % of the leg: guards sit at
	-- 66-79 %); crouches and low moves (54 % or less) keep their depth.
	local keep = Retarget.LEG_KEEP * math.clamp((stance - 0.54) / 0.06, 0, 1)
	for _, l in legs do
		local leg, foot, sole, knee, length = l.leg, l.foot, l.sole, l.knee, l.length
		local hx, hy, hz = l.hip[1], l.hip[2], l.hip[3]
		local drop = l.drop + (length - l.drop) * keep
		local out = math.sqrt(math.max(0, length * length - drop * drop))
		local ox, oz = sole[1] - hx, sole[3] - hz
		local flat = math.sqrt(ox * ox + oz * oz)
		if flat < 1e-3 then ox, oz = knee[1] - hx, knee[3] - hz; flat = math.sqrt(ox * ox + oz * oz) end
		if flat < 1e-3 then ox, oz, flat = 0, -1, 1 end
		local planted = { hx + ox / flat * out, hy - drop, hz + oz / flat * out }
		-- In the air: along the middle of the shin, as far as the leg is long.
		local mid = between(knee, sole, 0.5)
		local dx, dy, dz = normalize(mid[1] - hx, mid[2] - hy, mid[3] - hz)
		local air = { hx + dx * length, hy + dy * length, hz + dz * length }
		local w = math.clamp((floorY + 0.6 - sole[2]) / 0.4, 0, 1)
		aim(leg, between(air, planted, w), { foot[6], foot[9], foot[12] })
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
	return c0, lift, parts, v
end

return Retarget
