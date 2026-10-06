-- SHIN's guard, solved (not a test). Wilhem's sheet: the katana in both hands, the blade on a
-- diagonal, the legs wide, a blow meets the steel (sparks). Then Wilhem: « l'épée de SHIN, elle
-- garde comment ? reste cohérent »: held over his head it left his body open, so the hands are
-- before his chest and the blade rises across his front, before his face: it covers his
-- torso and his head from the opponent. For the guard poses (PoseLibrary Kits.SHIN Block / CrouchBlock), the arm
-- angles that put the right hand above his head, the blade along `dir`, the left hand on the
-- hilt under the right one, the arms clear of his head and body and the blade clear of him.
-- Random-restart descent on the 10 numbers of a hold (right shoulder rx, rz, elbow, wrist;
-- left shoulder rx, rz, elbow; right shoulder twist, right wrist turn, left shoulder twist).
--   luau tests/ShinGuard.luau -a [Block|CrouchBlock|all] [restarts] [seed]
local Config = require("../src/shared/CombatConfig")
local MoveData = require("../src/shared/MoveData")
local RigSpec = require("../src/shared/RigSpec")
local K = require("../src/shared/Kinematics")
local Poses = require("../src/shared/PoseLibrary")
local Animator = require("../src/shared/Animator")
local WeaponKit = require("./WeaponKit")
local RaijinHold = require("./RaijinHold")

local args = { ... }
local SKEL = K.fromSpec(RigSpec.KAI)
local LIMITS = Poses.LIMITS
local ShinGuard = {}

-- In his root space (-Z forward, +Y up, +X his right), from the centre of his head: `at` the
-- right hand, `dir` the blade (from the hilt to the point), `left` how far down the hilt
-- (toward the pommel) the left hand holds.
ShinGuard.TARGETS = {
	Block = { at = { 0.3, -1.25, -0.95 }, dir = { -0.45, 0.85, -0.25 }, left = 0.3 },
	CrouchBlock = { at = { 0.3, -1.2, -0.95 }, dir = { -0.45, 0.85, -0.25 }, left = 0.3 },
}

local anim = Animator.new({ poses = Poses, moves = MoveData.Moves, kin = K, config = Config, skeleton = SKEL,
	kits = MoveData.Kits, moveKit = MoveData.MoveKit })
anim.kit = "SHIN"

local function holdArms(a)
	return {
		RightShoulder = { a[1], a[8] or 0, a[2] }, RightElbow = { a[3], 0, 0 }, RightWrist = { a[4], 0, a[9] or 0 },
		LeftShoulder = { a[5], a[10] or 0, a[6] }, LeftElbow = { a[7], 0, 0 }, LeftWrist = { 0, 0, 0 },
	}
end

local function posed(key, a)
	local pose = table.clone(anim:resolve(Poses.Kits.SHIN[key]))
	for k, v in holdArms(a) do pose[k] = v end
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
local HELD = { RightHand = true, RightLowerArm = true, LeftHand = true, LeftLowerArm = true }

function ShinGuard.cost(key, a)
	local t = ShinGuard.TARGETS[key]
	local parts = posed(key, a)
	local grip = WeaponKit.grip("SHIN", parts)
	local gx, gy, gz = grip[1], grip[2], grip[3]
	local ax, ay, az = K.vector(grip, 0, 0, -1)
	local head = parts.Head.cframe
	local side = if parts.RightUpperArm.cframe[1] > parts.LeftUpperArm.cframe[1] then 1 else -1
	local px, py, pz = head[1] + t.at[1] * side, head[2] + t.at[2], head[3] + t.at[3]
	local d = norm({ t.dir[1] * side, t.dir[2], t.dir[3] })
	local cost = 3 * ((gx - px) ^ 2 + (gy - py) ^ 2 + (gz - pz) ^ 2)
	cost += 20 * (1 - (ax * d[1] + ay * d[2] + az * d[3]))
	-- the left hand on the hilt, under the right one
	local lx, ly, lz = gx - ax * t.left, gy - ay * t.left, gz - az * t.left
	local f = parts.LeftHand.cframe
	local off = math.sqrt((f[1] - lx) ^ 2 + (f[2] - ly) ^ 2 + (f[3] - lz) ^ 2)
	cost += 12 * off ^ 2
	-- the blade clear of his body (its hilt is in his hands)
	local inside = 0
	for _, piece in WeaponKit.pieces("SHIN", parts) do
		local c, s = piece.cframe, piece.size
		for i = 0, 6 do
			local x, y, z = K.point(c, 0, 0, (i / 6 - 0.5) * s[3])
			for name, part in parts do
				if not HELD[name] then
					local qx, qy, qz = K.point(K.inverse(part.cframe), x, y, z)
					local dd = math.min(part.size[1] / 2 + 0.06 - math.abs(qx), part.size[2] / 2 + 0.06 - math.abs(qy),
						part.size[3] / 2 + 0.06 - math.abs(qz))
					if dd > 0 then inside += dd end
				end
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
		+ over(a[7], "LeftElbow"))
	if math.abs(a[2]) > 95 then cost += 0.5 * (math.abs(a[2]) - 95) end
	if math.abs(a[6]) > 130 then cost += 0.5 * (math.abs(a[6]) - 130) end
	for i = 8, 10 do
		if math.abs(a[i]) > 70 then cost += 0.5 * (math.abs(a[i]) - 70) end
	end
	return cost, inside, off, math.deg(math.acos(math.clamp(ax * d[1] + ay * d[2] + az * d[3], -1, 1))), arms
end

function ShinGuard.solve(key, start, seed, restarts)
	local state = seed or 7
	local function rnd(a, b)
		state = (state * 1103515245 + 12345) % 2147483648
		return a + (b - a) * state / 2147483648
	end
	local best, bestCost = start, ShinGuard.cost(key, start)
	for restart = 1, restarts or 6 do
		local cur = table.clone(if restart == 1 then start else best)
		if restart > 1 then
			for i = 1, #cur do cur[i] += rnd(-40, 40) end
		end
		local curCost = ShinGuard.cost(key, cur)
		local sigma = 25
		for _ = 1, 900 do
			local cand = table.clone(cur)
			for i = 1, #cand do
				if rnd(0, 1) < 0.5 then cand[i] += rnd(-1, 1) * sigma end
			end
			local c = ShinGuard.cost(key, cand)
			if c < curCost then cur, curCost = cand, c end
			sigma = math.max(0.5, sigma * 0.995)
		end
		if curCost < bestCost then best, bestCost = cur, curCost end
	end
	return best, bestCost
end

if args[1] then
	-- (the starts: both arms raised over the head)
	local start = { 80, -20, 90, -70, 80, 30, 90, 0, 0, 0 }
	local keys = if args[1] == "all" then { "Block", "CrouchBlock" } else { args[1] }
	for _, key in keys do
		local best = ShinGuard.solve(key, start, tonumber(args[3]) or 7, tonumber(args[2]) or 6)
		local cost, inside, off, angle, arms = ShinGuard.cost(key, best)
		local r = {}
		for i, v in best do r[i] = tostring(math.floor(v + 0.5)) end
		print(string.format("%-11s cost %.2f (blade in body %.2f, arms in body %.2f, left hand %.2f off the hilt, aim %.0f°)   %s = { %s },",
			key, cost, inside, arms, off, angle, key, table.concat(r, ", ")))
	end
end

return ShinGuard
