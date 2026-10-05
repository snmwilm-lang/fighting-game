-- RAIJIN's spear holds, solved (not a test): for each of his guard poses, the arm angles that
-- put the spear where a spearman holds it, both hands on the shaft, the shaft clear of his
-- body. A target is a line: the rear (right) hand at a point of his hips/waist, the shaft
-- going a given way, the front (left) hand further up the shaft. Random-restart descent on
-- the 7 numbers of a hold (PoseLibrary KIT_HOLD: right shoulder rx, rz, elbow, wrist; left
-- shoulder rx, rz, elbow), measured on the real skeleton and the real WeaponSpec.
--   luau tests/RaijinHold.luau -a [KEY|all]
-- Prints the holds to paste in PoseLibrary (KIT_HOLD) and how well each one fits.
local Config = require("../src/shared/CombatConfig")
local MoveData = require("../src/shared/MoveData")
local RigSpec = require("../src/shared/RigSpec")
local K = require("../src/shared/Kinematics")
local Poses = require("../src/shared/PoseLibrary")
local Animator = require("../src/shared/Animator")
local WeaponKit = require("./WeaponKit")

local args = { ... }
local SKEL = K.fromSpec(RigSpec.KAI)
local LIMITS = Poses.LIMITS

local RaijinHold = {}

-- The targets, in his root space (-Z forward, +Y up), from his own hips: `at` = the rear hand
-- (x: toward his right hip, y: up from the hips, z: forward), `dir` = where the shaft points,
-- `front` = how far up the shaft the front hand holds (anywhere from 0.7 to 1.8 is accepted).
RaijinHold.TARGETS = {
	-- the ready stance: rear hand at the right hip, the point at the opponent's chest
	STANCE = { at = { 0, 0.3, -0.6 }, dir = { 0, -0.12, -1 }, front = 1.25 },
	-- crouched: the same line, lower, the point a little up
	Crouch = { at = { 0, 0.25, -0.6 }, dir = { 0, 0, -1 }, front = 1.2 },
	-- the guard: the shaft held up across the front, a bar between him and the blow
	Block = { at = { 0.35, 0.35, -0.75 }, dir = { -0.25, 1, -0.45 }, front = 1.35 },
	CrouchBlock = { at = { 0.35, 0.3, -0.8 }, dir = { -0.25, 1, -0.55 }, front = 1.3 },
	-- running in: the spear carried level, a little up (the stride pumps the arms)
	RunUpper = { at = { 0, 0.3, -0.6 }, dir = { 0, 0.1, -1 }, front = 1.25 },
}

local anim = Animator.new({ poses = Poses, moves = MoveData.Moves, kin = K, config = Config, skeleton = SKEL,
	kits = MoveData.Kits, moveKit = MoveData.MoveKit })
anim.kit = "RAIJIN"

-- (a hold: 7 numbers, or 10 with the turns: right shoulder twist, right wrist turn, left
-- shoulder twist; the same as PoseLibrary's `hold`)
local function holdArms(a)
	return {
		RightShoulder = { a[1], a[8] or 0, a[2] }, RightElbow = { a[3], 0, 0 }, RightWrist = { a[4], 0, a[9] or 0 },
		LeftShoulder = { a[5], a[10] or 0, a[6] }, LeftElbow = { a[7], 0, 0 }, LeftWrist = { 0, 0, 0 },
	}
end

-- His body posed with the hold `a` on the base pose `key`: { [name] = { cframe, size } }.
local function posed(key, a)
	local base = anim:resolve(Poses.Kits.RAIJIN[key])
	local pose = table.clone(base)
	for k, v in holdArms(a) do pose[k] = v end
	local solved = K.solve(SKEL, pose, 0)
	local parts = {}
	for name, f in solved do
		local size = SKEL.sizes[name]
		if size and name ~= "HumanoidRootPart" then parts[name] = { cframe = f, size = size } end
	end
	return parts
end

local function norm(v)
	local l = math.sqrt(v[1] ^ 2 + v[2] ^ 2 + v[3] ^ 2)
	return { v[1] / l, v[2] / l, v[3] / l }
end

local FREE = { RightHand = true, RightLowerArm = true, LeftHand = true, LeftLowerArm = true }

-- How far the hold `a` is from the target of `key` (0 = perfect), and its parts.
function RaijinHold.cost(key, a)
	local t = RaijinHold.TARGETS[key]
	local parts = posed(key, a)
	local grip = WeaponKit.grip("RAIJIN", parts)
	local gx, gy, gz = grip[1], grip[2], grip[3]
	local ax, ay, az = K.vector(grip, 0, 0, -1)
	-- the hips: between the upper legs' tops
	local lh, rh = parts.LeftUpperLeg.cframe, parts.RightUpperLeg.cframe
	local hx, hy, hz = (lh[1] + rh[1]) / 2, math.max(lh[2], rh[2]) + 0.6, (lh[3] + rh[3]) / 2
	local side = if rh[1] > lh[1] then 1 else -1
	local px, py, pz = hx + t.at[1] * side, hy + t.at[2], hz + t.at[3]
	local d = norm({ t.dir[1] * side, t.dir[2], t.dir[3] })
	local cost = 3 * ((gx - px) ^ 2 + (gy - py) ^ 2 + (gz - pz) ^ 2)
	cost += RaijinHold.AIM * (1 - (ax * d[1] + ay * d[2] + az * d[3]))
	-- the front hand on the shaft, `front` up from the rear one
	-- (anywhere from 0.7 to 1.8 up the shaft: the closest point of that stretch)
	local f = parts.LeftHand.cframe
	local along = math.clamp((f[1] - gx) * ax + (f[2] - gy) * ay + (f[3] - gz) * az, 0.7, 1.8)
	local fx, fy, fz = gx + ax * along, gy + ay * along, gz + az * along
	cost += 3 * ((f[1] - fx) ^ 2 + (f[2] - fy) ^ 2 + (f[3] - fz) ^ 2)
	-- the spear clear of his body, and of the floor
	local inside = 0
	for _, piece in WeaponKit.pieces("RAIJIN", parts) do
		local c, s = piece.cframe, piece.size
		for i = 0, 10 do
			local x, y, z = K.point(c, 0, 0, (i / 10 - 0.5) * s[3])
			if y < SKEL.floor + 0.25 then inside += (SKEL.floor + 0.25 - y) end
			for name, part in parts do
				if not FREE[name] then
					local lx, ly, lz = K.point(K.inverse(part.cframe), x, y, z)
					local dd = math.min(part.size[1] / 2 + 0.06 - math.abs(lx), part.size[2] / 2 + 0.06 - math.abs(ly),
						part.size[3] / 2 + 0.06 - math.abs(lz))
					if dd > 0 then inside += dd end
				end
			end
		end
	end
	cost += 20 * inside
	-- the arms clear of the body too (the hands not in the torso)
	for _, hand in RaijinHold.CLEAR_ARMS do
		local h = parts[hand].cframe
		for _, body in { "UpperTorso", "LowerTorso", "Head" } do
			local p = parts[body]
			local lx, ly, lz = K.point(K.inverse(p.cframe), h[1], h[2], h[3])
			local dd = math.min(p.size[1] / 2 + 0.15 - math.abs(lx), p.size[2] / 2 + 0.15 - math.abs(ly), p.size[3] / 2 + 0.15 - math.abs(lz))
			if dd > 0 then cost += 10 * dd end
		end
	end
	-- joint limits
	local function over(v, name)
		local r = LIMITS[name]
		if not r then return 0 end
		return math.max(0, r[1] - v, v - r[2])
	end
	cost += 0.05 * (over(a[1], "RightShoulder") + over(a[3], "RightElbow") + over(a[4], "RightWrist") + over(a[5], "LeftShoulder")
		+ over(a[7], "LeftElbow"))
	if math.abs(a[2]) > 95 then cost += 0.05 * (math.abs(a[2]) - 95) end
	if math.abs(a[6]) > 130 then cost += 0.05 * (math.abs(a[6]) - 130) end
	for i = 8, 10 do
		if a[i] and math.abs(a[i]) > 70 then cost += 0.05 * (math.abs(a[i]) - 70) end
	end
	return cost, inside, math.sqrt((f[1] - fx) ^ 2 + (f[2] - fy) ^ 2 + (f[3] - fz) ^ 2), math.deg(math.acos(math.clamp(ax * d[1] + ay * d[2] + az * d[3], -1, 1)))
end

RaijinHold.CLEAR_ARMS = { "LeftHand", "RightHand", "LeftLowerArm", "RightLowerArm" }
RaijinHold.AIM = tonumber(args[4]) or 20
RaijinHold.RESTARTS = tonumber(args[2]) or 6
function RaijinHold.solve(key, start, seed)
	-- (a small deterministic generator: the same holds every run)
	local state = seed or 7
	local rng = {}
	function rng:NextNumber(a, b)
		state = (state * 1103515245 + 12345) % 2147483648
		local u = state / 2147483648
		if a then return a + (b - a) * u end
		return u
	end
	local best, bestCost = start, RaijinHold.cost(key, start)
	for restart = 1, RaijinHold.RESTARTS do
		local cur = if restart == 1 then table.clone(start) else table.clone(best)
		if restart > 1 then
			for i = 1, #cur do cur[i] += rng:NextNumber(-40, 40) end
		end
		local curCost = RaijinHold.cost(key, cur)
		local sigma = 25
		for _ = 1, 900 do
			local cand = table.clone(cur)
			for i = 1, #cand do
				if rng:NextNumber() < 0.5 then cand[i] += rng:NextNumber(-1, 1) * sigma end
			end
			local c = RaijinHold.cost(key, cand)
			if c < curCost then cur, curCost = cand, c end
			sigma = math.max(0.5, sigma * 0.995)
		end
		if curCost < bestCost then best, bestCost = cur, curCost end
	end
	return best, bestCost
end

if args[1] then
	local current = {
		STANCE = { 0, -65, 68, -31, 62, 48, 7, -12, 70, -12 }, Crouch = { 19, -56, 81, -27, 39, 61, -1, 6, 70, 30 },
		Block = { 12, -18, 72, -1, 37, 76, 69, 16, -70, 6 }, CrouchBlock = { -10, -12, 112, -23, 64, 70, 13, 6, -60, 21 },
		RunUpper = { 0, -65, 68, -31, 62, 48, 7, -12, 70, -12 },
	}
	local keys = if args[1] == "all" then { "STANCE", "Crouch", "Block", "CrouchBlock", "RunUpper" } else { args[1] }
	for _, key in keys do
		local c0, in0, f0, a0 = RaijinHold.cost(key, current[key])
		local start = table.clone(current[key])
		for i = 8, 10 do start[i] = start[i] or 0 end
		local best, cost = RaijinHold.solve(key, start, tonumber(args[3]) or 7)
		local _, inside, front, angle = RaijinHold.cost(key, best)
		local r = {}
		for i, v in best do r[i] = tostring(math.floor(v + 0.5)) end
		print(string.format("%-11s before: cost %.2f (in body %.2f, front hand %.2f off, aim %.0f°)", key, c0, in0, f0, a0))
		print(string.format("%-11s after:  cost %.2f (in body %.2f, front hand %.2f off, aim %.0f°)   %s = { %s },", key, cost, inside,
			front, angle, key, table.concat(r, ", ")))
	end
end

return RaijinHold
