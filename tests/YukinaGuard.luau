-- YUKINA's guard, solved (not a test). Wilhem's sheet « GARDE / POSITION DE BASE »: both fans
-- open before her chest, side by side, one half-circle shield facing the opponent, the legs
-- wide and low. For the guard poses (PoseLibrary Kits.YUKINA Block / CrouchBlock), the arm
-- angles that put each fan's rivet before her chest, its sticks rising (the grip's -Z up),
-- its leaf facing the opponent (the grip's X along her forward line) and opening outward
-- (the right fan to her right, the left to her left), arms clear of her body.
-- Random-restart descent on the 10 numbers of a hold (right shoulder rx, rz, elbow, wrist;
-- left shoulder rx, rz, left elbow, left wrist; right shoulder twist, left shoulder twist).
--   luau tests/YukinaGuard.luau -a [Block|CrouchBlock|all] [restarts] [seed]
local Config = require("../src/shared/CombatConfig")
local MoveData = require("../src/shared/MoveData")
local RigSpec = require("../src/shared/RigSpec")
local K = require("../src/shared/Kinematics")
local Poses = require("../src/shared/PoseLibrary")
local Animator = require("../src/shared/Animator")
local WeaponSpec = require("../src/shared/WeaponSpec")
local WeaponKit = require("./WeaponKit")
local RaijinHold = require("./RaijinHold")

local args = { ... }
local SKEL = K.fromSpec(RigSpec.KAI)
local LIMITS = Poses.LIMITS
local YukinaGuard = {}

-- From the centre of her head, in her root space (-Z forward, +Y up, +X her right): `at` the
-- right fan's rivet (the left one mirrored), `up` how the sticks lean (x: outward share).
YukinaGuard.TARGETS = {
	Block = { at = { 0.2, -1.8, -1.05 }, lean = 0.25 },
	CrouchBlock = { at = { 0.2, -1.75, -1.05 }, lean = 0.25 },
}

local anim = Animator.new({ poses = Poses, moves = MoveData.Moves, kin = K, config = Config, skeleton = SKEL,
	kits = MoveData.Kits, moveKit = MoveData.MoveKit })
anim.kit = "YUKINA"

-- (the same 10 numbers as PoseLibrary's yukinaHold)
function YukinaGuard.arms(a)
	return {
		RightShoulder = { a[1], a[9], a[2] }, RightElbow = { a[3], 0, 0 }, RightWrist = { a[4], 0, 0 },
		LeftShoulder = { a[5], a[10], a[6] }, LeftElbow = { a[7], 0, 0 }, LeftWrist = { a[8], 0, 0 },
	}
end

local function posed(key, a)
	local pose = table.clone(anim:resolve(Poses.Kits.YUKINA[key]))
	for k, v in YukinaGuard.arms(a) do pose[k] = v end
	local parts = {}
	for name, f in K.solve(SKEL, pose, 0) do
		local size = SKEL.sizes[name]
		if size and name ~= "HumanoidRootPart" then parts[name] = { cframe = f, size = size } end
	end
	return parts
end

local function norm(v)
	local l = math.sqrt(v[1] ^ 2 + v[2] ^ 2 + v[3] ^ 2)
	return { v[1] / l, v[2] / l, v[3] / l }
end
local function dot(a, b) return a[1] * b[1] + a[2] * b[2] + a[3] * b[3] end
local HELD = { RightHand = true, RightLowerArm = true, LeftHand = true, LeftLowerArm = true }

function YukinaGuard.cost(key, a)
	local t = YukinaGuard.TARGETS[key]
	local parts = posed(key, a)
	local head = parts.Head.cframe
	local side = if parts.RightUpperArm.cframe[1] > parts.LeftUpperArm.cframe[1] then 1 else -1
	local cost, aim = 0, 0
	for i, spec in { WeaponSpec.YUKINA, WeaponSpec.YUKINA.pair } do
		local s = if i == 1 then side else -side -- (the left fan: mirrored)
		local grip = WeaponKit.grip("YUKINA", parts, spec)
		local px, py, pz = head[1] + t.at[1] * s, head[2] + t.at[2], head[3] + t.at[3]
		cost += 3 * ((grip[1] - px) ^ 2 + (grip[2] - py) ^ 2 + (grip[3] - pz) ^ 2)
		local up = norm({ -t.lean * s, 1, 0 }) -- (the sticks rise, leaning a little inward)
		local zAxis = { K.vector(grip, 0, 0, -1) }
		local xAxis = { K.vector(grip, 1, 0, 0) }
		local yAxis = { K.vector(grip, 0, 1, 0) }
		local a1 = 1 - dot(zAxis, up)
		local a2 = 1 - math.abs(xAxis[3]) -- (the leaf facing forward: its normal on the Z line)
		local a3 = math.max(0, -yAxis[1] * s) -- (opening outward)
		cost += 20 * a1 + 12 * a2 + 8 * a3
		aim += math.deg(math.acos(math.clamp(dot(zAxis, up), -1, 1)))
	end
	-- the fans and the arms clear of her body
	local inside = 0
	for _, piece in WeaponKit.pieces("YUKINA", parts) do
		local c, s = piece.cframe, piece.size
		local x, y, z = c[1], c[2], c[3]
		for name, part in parts do
			if not HELD[name] then
				local qx, qy, qz = K.point(K.inverse(part.cframe), x, y, z)
				local dd = math.min(part.size[1] / 2 + 0.06 - math.abs(qx), part.size[2] / 2 + 0.06 - math.abs(qy),
					part.size[3] / 2 + 0.06 - math.abs(qz))
				if dd > 0 then inside += dd end
			end
		end
	end
	cost += 20 * inside
	local arms = RaijinHold.armsInBody(parts)
	cost += 30 * arms
	local function over(v, name)
		local r = LIMITS[name]
		if not r then return 0 end
		return math.max(0, r[1] - v, v - r[2])
	end
	cost += 0.5 * (over(a[1], "RightShoulder") + over(a[3], "RightElbow") + over(a[4], "RightWrist") + over(a[5], "LeftShoulder")
		+ over(a[7], "LeftElbow") + over(a[8], "LeftWrist"))
	if math.abs(a[2]) > 95 then cost += 0.5 * (math.abs(a[2]) - 95) end
	if math.abs(a[6]) > 95 then cost += 0.5 * (math.abs(a[6]) - 95) end
	for i = 9, 10 do
		if math.abs(a[i]) > 70 then cost += 0.5 * (math.abs(a[i]) - 70) end
	end
	return cost, inside, arms, aim / 2
end

function YukinaGuard.solve(key, start, seed, restarts)
	local state = seed or 7
	local function rnd(lo, hi)
		state = (state * 1103515245 + 12345) % 2147483648
		return lo + (hi - lo) * state / 2147483648
	end
	local best, bestCost = start, YukinaGuard.cost(key, start)
	for restart = 1, restarts or 6 do
		local cur = table.clone(if restart == 1 then start else best)
		if restart > 1 then
			for i = 1, #cur do cur[i] += rnd(-40, 40) end
		end
		local curCost = YukinaGuard.cost(key, cur)
		local sigma = 25
		for _ = 1, 900 do
			local cand = table.clone(cur)
			for i = 1, #cand do
				if rnd(0, 1) < 0.5 then cand[i] += rnd(-1, 1) * sigma end
			end
			local c = YukinaGuard.cost(key, cand)
			if c < curCost then cur, curCost = cand, c end
			sigma = math.max(0.5, sigma * 0.995)
		end
		if curCost < bestCost then best, bestCost = cur, curCost end
	end
	return best, bestCost
end

if args[1] then
	-- (the start: both forearms raised before the chest)
	local start = { 70, 30, 100, -60, 70, -30, 100, -60, 0, 0 }
	local keys = if args[1] == "all" then { "Block", "CrouchBlock" } else { args[1] }
	for _, key in keys do
		local best = YukinaGuard.solve(key, start, tonumber(args[3]) or 7, tonumber(args[2]) or 6)
		local cost, inside, arms, aim = YukinaGuard.cost(key, best)
		local r = {}
		for i, v in best do r[i] = tostring(math.floor(v + 0.5)) end
		print(string.format("%-11s cost %.2f (fans in body %.2f, arms in body %.2f, sticks %.0f° off)   %s = { %s },",
			key, cost, inside, arms, aim, key, table.concat(r, ", ")))
	end
end

return YukinaGuard
