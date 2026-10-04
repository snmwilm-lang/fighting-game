-- Spear fit (not a test): finds, for every key pose of RAIJIN, the arm angles that hold his
-- spear (WeaponSpec.RAIJIN, in the right hand) along the wanted line, the left hand riding the
-- shaft ahead of the right one. The bodies (root, waist, legs) are the poses' own; only the
-- arms are searched. Prints the HOLD table pasted into PoseLibrary (RAIJIN):
--   luau tests/SpearFit.luau [ROLE]
-- Targets per key: pitch / yaw of the spear in degrees (yaw 0 = straight at the opponent,
-- positive toward the fighter's right side), fwd = how far ahead the tip reaches (studs),
-- reach = the tip at least that far from the body (spins), one = held in the right hand only,
-- down = both arms pitched down (the guards: the R6 test wants them so).
-- The recoveries are not fitted: PoseLibrary eases them between the blow and the stance.
local Config = require("../src/shared/CombatConfig")
local MoveData = require("../src/shared/MoveData")
local RigSpec = require("../src/shared/RigSpec")
local K = require("../src/shared/Kinematics")
local Poses = require("../src/shared/PoseLibrary")
local Animator = require("../src/shared/Animator")
local WeaponSpec = require("../src/shared/WeaponSpec")

local KAI = K.fromSpec(RigSpec.KAI)
local anim = Animator.new({ poses = Poses, moves = MoveData.Moves, kin = K, config = Config, skeleton = KAI,
	kits = MoveData.Kits, moveKit = MoveData.MoveKit })
anim.kit = "RAIJIN"
local SPEC = WeaponSpec.RAIJIN
local BUTT, TIP = 1.7, -4.6

-- Thrusts, sweeps, overheads, rising strikes: the line of the spear at the wind-up and at
-- the blow (see the moves' names in PoseLibrary).
local T = {
	Jab = { Startup = { pitch = -6, yaw = 0, fwd = 3.2 }, Active = { pitch = -6, yaw = 0, fwd = 7.2 } },
	Cross = { Startup = { pitch = 4, yaw = 62 }, Active = { pitch = 0, yaw = -38, reach = 4.5 } },
	Elbow = { Startup = { pitch = -4, yaw = 0, fwd = 4 }, Active = { pitch = -28, yaw = 180, fwd = -2 } },
	Kick = { Startup = { pitch = 0, yaw = 80 }, Active = { pitch = 0, reach = 5 } },
	BodyBlow = { Startup = { pitch = -10, yaw = 0, fwd = 3.6 }, Active = { pitch = -18, yaw = 0, fwd = 7 } },
	Uppercut = { Startup = { pitch = -24, yaw = 0, fwd = 4 }, Active = { pitch = 56, yaw = 0, fwd = 3.5 } },
	PalmStrike = { Startup = { pitch = 0, yaw = 0, fwd = 2.4 }, Active = { pitch = -2, yaw = 0, fwd = 7.2 } },
	DragonTornado = { Startup = { pitch = -6, yaw = 64 }, Active = { pitch = 0, reach = 5 }, Active2 = { pitch = 0, reach = 5 } },
	DragonFist = { Startup = { pitch = -12, yaw = 0, fwd = 3.5 }, Active = { pitch = 60, yaw = 0, fwd = 3.5 },
		Active2 = { pitch = 82, yaw = 0 } },
	CrescentMoon = { Startup = { pitch = 10, yaw = 0, fwd = 3 }, Active = { pitch = -40, yaw = 0 }, Active2 = { reach = 3.5 } },
	RisingWind = { Startup = { pitch = -8, yaw = 40 }, Active = { pitch = 0, yaw = 52, reach = 4.5 }, Active2 = { pitch = 0, yaw = -52, reach = 4.5 } },
	KiFlurry = { Startup = { pitch = -2, yaw = 0, fwd = 3.6 }, Active = { pitch = -6, yaw = 0, fwd = 7 },
		Active2 = { pitch = 4, yaw = 6, fwd = 6.2 } },
	ThunderHeel = { Startup = { pitch = 62, yaw = 0 }, Active = { pitch = -42, yaw = 0, fwd = 5 } },
	SpinKick = { Startup = { pitch = -4, yaw = 64 }, Active = { pitch = -4, reach = 5 } },
	Smash = { Startup = { pitch = 0, yaw = 0, fwd = 2.8 }, Active = { pitch = -6, yaw = 0, fwd = 8.4 } },
	Hammer = { Startup = { pitch = 70, yaw = 0 }, Active = { pitch = -26, yaw = 0, fwd = 6 } },
	Sweep = { Startup = { pitch = -18, yaw = 62 }, Active = { pitch = -20, yaw = -42, reach = 4 } },
	LowKick = { Startup = { pitch = -12, yaw = 0, fwd = 2.2 }, Active = { pitch = -26, yaw = 0, fwd = 6.6 } },
	AirKick = { Startup = { pitch = -8, yaw = 0, fwd = 3 }, Active = { pitch = -40, yaw = 0, fwd = 5 } },
	AirKick2 = { Startup = { pitch = 0, yaw = 60 }, Active = { pitch = -10, yaw = -42, reach = 4 } },
	AirSmash = { Startup = { pitch = 70, yaw = 0 }, Active = { pitch = -60, yaw = 0, fwd = 3.5 } },
	Rising = { Startup = { pitch = -22, yaw = 0, fwd = 3 }, Active = { pitch = 80, yaw = 0 } },
	KiChase = { Startup = { pitch = -10, yaw = 0, fwd = 3 }, Active = { pitch = -16, yaw = 0, fwd = 7 } },
	Finale = { Startup = { pitch = 0, yaw = 0, fwd = 2 }, Active = { pitch = -4, yaw = 0, fwd = 8.8, one = true } },
	KiBlast = { Startup = { pitch = 8, yaw = 0, fwd = -0.5, one = true }, Active = { pitch = -4, yaw = 0, fwd = 5.5, one = true } },
	KaienRush = { Startup = { pitch = 86, one = true }, Active = { pitch = -4, yaw = 0, fwd = 8.6 } },
	Awakening = { Startup = { pitch = 86, one = true }, Active = { pitch = -30, yaw = 0, fwd = 7 } },
	Kaiten = { Startup = { pitch = 86, one = true }, Active = { pitch = -12, yaw = 0, fwd = 6.4 } },
	Fatal = { Startup = { pitch = 86, one = true }, Active = { pitch = -10, yaw = 0, fwd = 8, one = true } },
}
-- The kit's own poses (stance, guard, crouch, victory).
local KIT = {
	STANCE = { pitch = -16, yaw = 0, fwd = 4.4 },
	Crouch = { pitch = -12, yaw = 0, fwd = 4 },
	Block = { pitch = -22, yaw = 70, down = true },
	CrouchBlock = { pitch = -22, yaw = 70, down = true },
	Victory = { pitch = 86, one = true },
}

local J = KAI.joints
local function link(parent, name, value)
	local j = J[name]
	return K.mul(K.mul(K.mul(parent, j.c0), K.offset(name, value)), j.c1inv)
end
local function hand(torso, side, sh, el, wr)
	local a = link(torso, side .. "Shoulder", sh)
	local b = link(a, side .. "Elbow", el)
	return link(b, side .. "Wrist", wr)
end
local HAND = KAI.sizes.RightHand

-- Score of one right-arm hold against a target (lower is better) and the spear's line.
local function line(torso, r)
	local h = hand(torso, "Right", { r[1], 0, r[2] }, { r[3], 0, 0 }, { r[4], 0, 0 })
	local grip = K.mul(K.mul(h, K.translation(0, HAND[2] * SPEC.grip.y, SPEC.grip.z)), K.angles(math.rad(SPEC.grip.tilt), 0, 0))
	local bx, by, bz = K.point(grip, 0, 0, BUTT)
	local tx, ty, tz = K.point(grip, 0, 0, TIP)
	local gx, gy, gz = K.point(grip, 0, 0, 0)
	return { b = { bx, by, bz }, t = { tx, ty, tz }, g = { gx, gy, gz } }
end
local function angleError(l, target)
	local dx, dy, dz = l.t[1] - l.b[1], l.t[2] - l.b[2], l.t[3] - l.b[3]
	local len = math.sqrt(dx * dx + dy * dy + dz * dz)
	local pitch = math.deg(math.asin(dy / len))
	local e = 0
	if target.pitch then e += (pitch - target.pitch) ^ 2 end
	if target.yaw and math.abs(pitch) < 75 then
		local yaw = math.deg(math.atan2(dx, -dz))
		local d = (yaw - target.yaw + 540) % 360 - 180
		e += d * d
	end
	if target.fwd then e += ((-l.t[3]) - target.fwd) ^ 2 * 100 end
	if target.reach then
		local r = math.sqrt(l.t[1] ^ 2 + l.t[3] ^ 2)
		if r < target.reach then e += (target.reach - r) ^ 2 * 100 end
	end
	return e
end
-- Distance of the left hand to the shaft ahead of the right fist (0.5 to 2.6 studs along it).
local function onShaft(torso, l, s)
	local h = hand(torso, "Left", { l[1], 0, l[2] }, { l[3], 0, 0 }, nil)
	local dx, dy, dz = s.t[1] - s.g[1], s.t[2] - s.g[2], s.t[3] - s.g[3]
	local len = math.sqrt(dx * dx + dy * dy + dz * dz)
	dx, dy, dz = dx / len, dy / len, dz / len
	local px, py, pz = h[1] - s.g[1], h[2] - s.g[2], h[3] - s.g[3]
	local u = math.clamp(px * dx + py * dy + pz * dz, 0.5, 2.6)
	local cx, cy, cz = s.g[1] + dx * u - h[1], s.g[2] + dy * u - h[2], s.g[3] + dz * u - h[3]
	return math.sqrt(cx * cx + cy * cy + cz * cz)
end

local function search(ranges, score, best)
	local function rec(i, cur)
		if i > #ranges then
			local s = score(cur)
			if s < best.score then best.score, best.v = s, table.clone(cur) end
			return
		end
		local r = ranges[i]
		for v = r[1], r[2], r[3] do
			cur[i] = v
			rec(i + 1, cur)
		end
	end
	rec(1, {})
	return best
end
local function refine(best, score, step, limits)
	for _ = 1, 3 do
		local ranges = {}
		for i, v in best.v do
			ranges[i] = { math.max(limits[i][1], v - 2 * step), math.min(limits[i][2], v + 2 * step), step }
		end
		best = search(ranges, score, best)
		step /= 2
	end
	return best
end

local R_LIMITS = { { -60, 180 }, { -90, 110 }, { 0, 150 }, { -80, 40 } }
local L_LIMITS = { { -60, 180 }, { -110, 90 }, { 0, 150 } }
-- Natural arms: the shoulder not wrenched behind or far across, the elbow not folded tight.
local function natural(a, rollMax)
	return (a[3] / 150) ^ 2 * 4 + (math.max(0, math.abs(a[2]) - rollMax) / 10) ^ 2 * 6
		+ (math.max(0, -a[1] - 10) / 10) ^ 2 * 6
end
local function fit(pose, target)
	local resolved = anim:resolve(pose)
	local solved = K.solve(KAI, resolved, anim:groundLift(resolved, 0))
	local torso = solved.UpperTorso
	local function leftFor(s, coarse)
		local lScore = function(l)
			return onShaft(torso, l, s) ^ 2 * 100 + natural(l, 70) + (if target.down then (math.max(0, l[1] - 8) / 5) ^ 2 * 10 else 0)
		end
		local step = if coarse then 20 else 15
		local best = search({ { -40, 170, step }, { -100, 80, step }, { 0, 140, step } }, lScore, { score = math.huge })
		if not coarse then best = refine(best, lScore, 5, L_LIMITS) end
		return best
	end
	local function total(r)
		local s = line(torso, r)
		local e = angleError(s, target) + natural(r, 60)
		if target.down then e += (math.max(0, r[1] - 25) / 5) ^ 2 * 10 end
		if target.one then return e, s end
		return e + leftFor(s, true).score, s
	end
	-- The right arm's candidates that aim the spear well, then the pair that holds it best.
	local candidates = {}
	search({ { -40, 180, 15 }, { -90, 105, 15 }, { 0, 150, 15 }, { -80, 40, 20 } }, function(r)
		local e = angleError(line(torso, r), target) + natural(r, 60)
		table.insert(candidates, { e = e, v = table.clone(r) })
		return e
	end, { score = math.huge })
	table.sort(candidates, function(a, b) return a.e < b.e end)
	local best = { score = math.huge }
	for i = 1, math.min(120, #candidates) do
		local score = total(candidates[i].v)
		if score < best.score then best = { score = score, v = candidates[i].v } end
	end
	best = refine(best, function(r) return (total(r)) end, 5, R_LIMITS)
	local s = line(torso, best.v)
	local left = if target.one then nil else leftFor(s, false)
	local miss = if left then onShaft(torso, left.v, s) else 0
	return best.v, left and left.v, math.sqrt(math.max(0, angleError(s, target))), miss
end

local function round(v) return math.floor(v + 0.5) end
local function emit(name, key, pose, target)
	local r, l, err, miss = fit(pose, target)
	local text = string.format("{ %d, %d, %d, %d", round(r[1]), round(r[2]), round(r[3]), round(r[4]))
	if l then text ..= string.format(", %d, %d, %d", round(l[1]), round(l[2]), round(l[3])) end
	print(string.format("\t\t%s = %s }, -- error %.0f, left hand %.2f off the shaft", key, text, err, miss))
end

local only = ...
local roles = {}
for role in T do table.insert(roles, role) end
table.sort(roles)
if only ~= "kit" then print("local HOLD = {") end
for _, role in roles do
	if not only or only == role then
		local id = MoveData.Kits.RAIJIN.Roles[role]
		print(string.format("\t%s = {", role))
		for _, key in { "Startup", "Active", "Active2" } do
			local target = T[role][key]
			if target and Poses[id][key] then emit(role, key, Poses[id][key], target) end
		end
		print("\t},")
	end
end
if only ~= "kit" then print("}") end
if not only or only == "kit" then
	print("local KIT_HOLD = {")
	for key, target in KIT do
		local pose = Poses.Kits.RAIJIN[key]
		emit("kit", key, pose, target)
	end
	print("}")
end
