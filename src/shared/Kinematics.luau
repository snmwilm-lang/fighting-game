--[[
	Pure rig math, shared by the client animation runtime and the offline tests: no Roblox
	API, no require.

	A transform is a 12-number array in CFrame:GetComponents() order:
	  { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 }   (row-major rotation)
	`angles(rx, ry, rz)` matches CFrame.Angles (Rx * Ry * Rz, radians).

	A skeleton is the list of joints of a rig (Motor6D-like: part0, part1, C0, C1) and the
	size of every part. `solve` runs forward kinematics for a pose (joint -> degrees, Root also
	-> dy, dz offsets) in the HumanoidRootPart space; the same formula as Roblox applies:
	  part1 = part0 * C0 * offset * C1:Inverse()
	From the bind pose the skeleton derives everything the animation needs to fit any body:
	the floor height under the root, the leg lengths for the IK, the head pivot.
]]
local K = {}

local rad, cos, sin, atan2, sqrt, abs = math.rad, math.cos, math.sin, math.atan2, math.sqrt, math.abs

K.IDENTITY = table.freeze({ 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 })

function K.translation(x, y, z)
	return { x, y, z, 1, 0, 0, 0, 1, 0, 0, 0, 1 }
end

function K.angles(rx, ry, rz)
	local cx, sx, cy, sy, cz, sz = cos(rx), sin(rx), cos(ry), sin(ry), cos(rz), sin(rz)
	return {
		0, 0, 0,
		cy * cz, -cy * sz, sy,
		cx * sz + sx * sy * cz, cx * cz - sx * sy * sz, -sx * cy,
		sx * sz - cx * sy * cz, sx * cz + cx * sy * sz, cx * cy,
	}
end

function K.mul(a, b)
	local a00, a01, a02, a10, a11, a12, a20, a21, a22 = a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11], a[12]
	local b00, b01, b02, b10, b11, b12, b20, b21, b22 = b[4], b[5], b[6], b[7], b[8], b[9], b[10], b[11], b[12]
	local bx, by, bz = b[1], b[2], b[3]
	return {
		a[1] + a00 * bx + a01 * by + a02 * bz,
		a[2] + a10 * bx + a11 * by + a12 * bz,
		a[3] + a20 * bx + a21 * by + a22 * bz,
		a00 * b00 + a01 * b10 + a02 * b20, a00 * b01 + a01 * b11 + a02 * b21, a00 * b02 + a01 * b12 + a02 * b22,
		a10 * b00 + a11 * b10 + a12 * b20, a10 * b01 + a11 * b11 + a12 * b21, a10 * b02 + a11 * b12 + a12 * b22,
		a20 * b00 + a21 * b10 + a22 * b20, a20 * b01 + a21 * b11 + a22 * b21, a20 * b02 + a21 * b12 + a22 * b22,
	}
end

function K.inverse(a)
	local x, y, z = a[1], a[2], a[3]
	local r00, r01, r02, r10, r11, r12, r20, r21, r22 = a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11], a[12]
	return {
		-(r00 * x + r10 * y + r20 * z), -(r01 * x + r11 * y + r21 * z), -(r02 * x + r12 * y + r22 * z),
		r00, r10, r20, r01, r11, r21, r02, r12, r22,
	}
end

function K.point(a, x, y, z)
	return a[1] + a[4] * x + a[5] * y + a[6] * z, a[2] + a[7] * x + a[8] * y + a[9] * z,
		a[3] + a[10] * x + a[11] * y + a[12] * z
end

-- Direction (rotation only).
function K.vector(a, x, y, z)
	return a[4] * x + a[5] * y + a[6] * z, a[7] * x + a[8] * y + a[9] * z, a[10] * x + a[11] * y + a[12] * z
end

-- Lowest y of a box of half extents (hx, hy, hz) placed at `t`: the corners need not be listed.
function K.boxBottom(t, hx, hy, hz)
	return t[2] - (abs(t[7]) * hx + abs(t[8]) * hy + abs(t[9]) * hz)
end

-- Joint offset of a pose entry (degrees; Root also carries dy, dz and an optional jitter x).
function K.offset(name, v)
	if not v then return K.IDENTITY end
	local t = K.angles(rad(v[1] or 0), rad(v[2] or 0), rad(v[3] or 0))
	if name == "Root" then
		t[1], t[2], t[3] = v[6] or 0, v[4] or 0, v[5] or 0
	end
	return t
end

local LEG_SIDES = { "Left", "Right" }

-- joints: { { name, part0, part1, c0, c1 } } in any order; sizes: part -> { x, y, z }.
function K.skeleton(joints, sizes, rootPart)
	rootPart = rootPart or "HumanoidRootPart"
	local byName, order, placed = {}, {}, { [rootPart] = true }
	local pending = table.clone(joints)
	while #pending > 0 do
		local progressed = false
		for i = #pending, 1, -1 do
			local j = pending[i]
			if placed[j.part0] then
				local entry = { name = j.name, part0 = j.part0, part1 = j.part1, c0 = j.c0, c1inv = K.inverse(j.c1) }
				table.insert(order, entry)
				byName[j.name] = entry
				placed[j.part1] = true
				table.remove(pending, i)
				progressed = true
			end
		end
		if not progressed then break end -- joints not connected to the root are ignored
	end
	local skel = { order = order, joints = byName, sizes = sizes, root = rootPart }
	local bind = K.solve(skel, {}, 0)
	skel.floor = K.lowest(skel, bind)
	skel.legs = {}
	for _, side in LEG_SIDES do
		local hip, knee, ankle = byName[side .. "Hip"], byName[side .. "Knee"], byName[side .. "Ankle"]
		if hip and knee and ankle then
			-- Bone vectors expressed in the frame where each joint rotation applies.
			local _, v1y, v1z = K.point(hip.c1inv, knee.c0[1], knee.c0[2], knee.c0[3])
			local _, v2y, v2z = K.point(knee.c1inv, ankle.c0[1], ankle.c0[2], ankle.c0[3])
			local footSize = sizes[ankle.part1]
			local ax, ay, az = K.point(bind[ankle.part0], ankle.c0[1], ankle.c0[2], ankle.c0[3])
			local footBottom = if footSize
				then K.boxBottom(bind[ankle.part1], footSize[1] / 2, footSize[2] / 2, footSize[3] / 2)
				else ay
			local hx, hy, hz = K.point(bind[hip.part0], hip.c0[1], hip.c0[2], hip.c0[3])
			local foot = bind[ankle.part1]
			local half = if footSize then { footSize[1] / 2, footSize[2] / 2, footSize[3] / 2 } else { 0, 0, 0 }
			skel.legs[side] = {
				hip = hip, knee = knee, ankle = ankle, foot = ankle.part1,
				thigh = sqrt(v1y * v1y + v1z * v1z), shin = sqrt(v2y * v2y + v2z * v2z),
				thighAngle = atan2(-v1z, -v1y), shinAngle = atan2(-v2z, -v2y),
				ankleHeight = ay - footBottom, ankleZ = az, ankleX = ax,
				hipX = hx, hipY = hy, hipZ = hz,
				-- Foot box around the ankle pivot (bind), for toe / heel contact when pitched.
				footOffset = if foot then { foot[1] - ax, foot[2] - ay, foot[3] - az } else { 0, 0, 0 },
				footHalf = half,
			}
		end
	end
	local left, right = skel.legs.Left, skel.legs.Right
	skel.legLength = if left and right then (left.thigh + left.shin + right.thigh + right.shin) / 2 else 2.3
	local neck = byName.Neck
	if neck then
		local hx, hy, hz = K.point(bind[neck.part0], neck.c0[1], neck.c0[2], neck.c0[3])
		skel.neckPivot = { hx, hy, hz }
		local head = bind[neck.part1]
		skel.headCenter = { head[1], head[2], head[3] }
	end
	skel.bind = bind
	return skel
end

-- Skeleton of a rig described by RigSpec (part centers and joint pivots, axis-aligned bind).
function K.fromSpec(spec)
	local joints, sizes = {}, {}
	for name, p in spec.parts do sizes[name] = p.size end
	for _, j in spec.joints do
		local a, b, pivot = spec.parts[j.part0].pos, spec.parts[j.part1].pos, j.pivot
		table.insert(joints, {
			name = j.name, part0 = j.part0, part1 = j.part1,
			c0 = K.translation(pivot[1] - a[1], pivot[2] - a[2], pivot[3] - a[3]),
			c1 = K.translation(pivot[1] - b[1], pivot[2] - b[2], pivot[3] - b[3]),
		})
	end
	return K.skeleton(joints, sizes)
end

-- Forward kinematics: part -> transform in the root part's space. `lift` raises the whole
-- body above the root (grounding), whatever the Root joint's own C0 rotation.
function K.solve(skel, pose, lift)
	local out = { [skel.root] = K.IDENTITY }
	for _, j in skel.order do
		local parent = out[j.part0]
		if parent then
			local t = K.mul(K.mul(K.mul(parent, j.c0), K.offset(j.name, pose[j.name])), j.c1inv)
			if j.name == "Root" and lift and lift ~= 0 then t[2] += lift end
			out[j.part1] = t
		end
	end
	return out
end

-- Lowest point of the body (every part but the invisible root box).
function K.lowest(skel, solved)
	local low = math.huge
	for part, t in solved do
		local size = skel.sizes[part]
		if part ~= skel.root and size then
			low = math.min(low, K.boxBottom(t, size[1] / 2, size[2] / 2, size[3] / 2))
		end
	end
	return low
end

function K.footBottom(skel, solved, side)
	local leg = skel.legs[side]
	local t = leg and solved[leg.foot]
	if not t then return nil end
	local size = skel.sizes[leg.foot]
	return K.boxBottom(t, size[1] / 2, size[2] / 2, size[3] / 2)
end

-- Pitch of a frame (radians): elevation of its forward axis (-Z), whatever its yaw.
local function pitch(t)
	return math.asin(math.clamp(-t[9], -1, 1))
end
K.pitch = pitch

--[[
	Two-bone leg IK in the sagittal plane. (tx, ty, tz) is the ankle pivot in the root space;
	the pose's Root offset is taken into account. Writes the hip / knee / ankle angles of
	`side` into `pose` (degrees): knee bending forward, leg spread outward by `spread`
	degrees, foot pitched by `footPitch` degrees from flat (positive = toes up).
	The hip rotates as Rx(h) * Rz(spread), so a spread leg swings in a tilted plane: the knee
	angle is found by bisection on the exact leg length, which stays valid for avatars whose
	bones are not perfectly vertical in their bind pose.
]]
function K.solveLeg(skel, pose, side, tx, ty, tz, footPitch, spread)
	local leg = skel.legs[side]
	if not leg then return end
	local root = skel.joints.Root
	local pelvis = K.mul(K.mul(root.c0, K.offset("Root", pose.Root)), root.c1inv)
	local hipFrame = K.mul(pelvis, leg.hip.c0)
	local _, y, z = K.point(K.inverse(hipFrame), tx, ty, tz)
	spread = (if side == "Left" then -1 else 1) * (spread or 5)
	local cs = cos(rad(spread))
	local l1, l2, a1, a2 = leg.thigh, leg.shin, leg.thighAngle, leg.shinAngle
	local function reach(k)
		return -cs * (l1 * cos(a1) + l2 * cos(a2 + k)), -(l1 * sin(a1) + l2 * sin(a2 + k))
	end
	local function length(k)
		local wy, wz = reach(k)
		return sqrt(wy * wy + wz * wz)
	end
	local d = sqrt(y * y + z * z)
	local lo, hi = -math.pi + 0.06, 0
	local k
	if d >= length(hi) then
		k = hi
	elseif d <= length(lo) then
		k = lo
	else
		for _ = 1, 26 do
			local mid = (lo + hi) / 2
			if length(mid) > d then hi = mid else lo = mid end
		end
		k = (lo + hi) / 2
	end
	local wy, wz = reach(k)
	local h = atan2(-z, -y) - atan2(-wz, -wy)
	local a = -(h + k) - pitch(hipFrame) + rad(footPitch or 0)
	pose[side .. "Hip"] = { math.deg(h), 0, spread }
	pose[side .. "Knee"] = { math.deg(k), 0, 0 }
	pose[side .. "Ankle"] = { math.deg(a), 0, -spread } -- the sole stays flat under a spread leg
end

--[[
	Ankle position (y, z in the root space) of a foot that rolls on the floor like a real one:
	the flat foot would have its ankle at depth `z` and its sole `lift` studs above the floor;
	a pitched foot pivots on its heel (toes up, positive pitch) or on its toe (heel raised),
	so the point touching the floor never slides.
]]
function K.rollFoot(skel, leg, z, lift, pitch)
	local o, h = leg.footOffset, leg.footHalf
	local cornerY = o[2] - h[2]
	local cornerZ = if (pitch or 0) < 0 then o[3] - h[3] else o[3] + h[3] -- toe, else heel
	local ankleY = skel.floor + (lift or 0) - cornerY
	local pivotY, pivotZ = ankleY + cornerY, z + cornerZ
	local c, s = cos(rad(pitch or 0)), sin(rad(pitch or 0))
	local ay, az = -cornerY, -cornerZ
	return pivotY + c * ay - s * az, pivotZ + s * ay + c * az
end

-- Plants a foot: flat-foot ankle depth `z` (root space, -Z forward), foot pitched by `pitch`
-- degrees and rolled on its heel or toe, sole `lift` studs above the floor of the bind pose.
function K.plantLeg(skel, pose, side, z, lift, pitch, spread)
	local leg = skel.legs[side]
	if not leg then return end
	local y, rz = K.rollFoot(skel, leg, z, lift, pitch)
	K.solveLeg(skel, pose, side, leg.ankleX, y, rz, pitch, spread)
end

-- Neck correction (degrees) that turns the face toward a point of the root space.
function K.lookCorrection(skel, solved, tx, ty, tz)
	local neck = skel.joints.Neck
	local head = neck and solved[neck.part1]
	if not head then return 0, 0 end
	local hx, hy, hz = head[1], head[2], head[3] -- the eyes, near the head center
	local fx, fy, fz = K.vector(head, 0, 0, -1) -- face direction
	local dx, dy, dz = tx - hx, ty - hy, tz - hz
	local facePitch = atan2(fy, sqrt(fx * fx + fz * fz))
	local wantPitch = atan2(dy, sqrt(dx * dx + dz * dz))
	local faceYaw, wantYaw = atan2(-fx, -fz), atan2(-dx, -dz)
	local yaw = (wantYaw - faceYaw + math.pi) % (2 * math.pi) - math.pi
	return math.deg(wantPitch - facePitch), math.deg(yaw)
end

--[[
	Damped spring (semi-implicit Euler, fixed sub-steps so any frame rate is stable).
	s = { x = value, v = velocity }; frequency in Hz; damping 1 = critical, < 1 = wobble.
]]
function K.spring(s, target, dt, frequency, damping)
	dt = math.clamp(dt, 0, 0.1)
	local omega = 2 * math.pi * frequency
	local steps = math.max(1, math.ceil(dt * 240))
	local h = dt / steps
	for _ = 1, steps do
		s.v += (omega * omega * (target - s.x) - 2 * damping * omega * s.v) * h
		s.x += s.v * h
	end
	return s.x
end

return K
