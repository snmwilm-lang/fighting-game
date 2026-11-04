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
	STANCE = { at = { 0, 0.45, -0.95 }, dir = { 0, -0.12, -1 }, front = 1.25 },
	-- crouched: the same line, lower, the point a little up
	Crouch = { at = { 0, 0.25, -0.6 }, dir = { 0, 0, -1 }, front = 1.2 },
	-- the guard: the shaft held up across the front, a bar between him and the blow
	Block = { at = { 0.35, 0.35, -0.75 }, dir = { -0.25, 1, -0.45 }, front = 1.35 },
	CrouchBlock = { at = { 0.35, 0.3, -0.8 }, dir = { -0.25, 1, -0.55 }, front = 1.3 },
	-- Wilhem's sheet « RAIJIN AUTO-ATTAQUES ». M1 1 ESTOC: drawn back level, then a quick thrust.
	["Jab.Startup"] = { at = { 0, 0.25, 0.85 }, dir = { 0, 0.02, -1 }, front = 1.2 },
	["Jab.Active"] = { at = { 0, 0.55, -2.0 }, dir = { 0, 0.03, -1 }, front = 1.2 },
	-- 2 BALAYAGE: a short horizontal sweep, from his right across to his left
	["Cross.Startup"] = { at = { 0.1, 0.4, -0.4 }, dir = { 0.85, 0.08, -0.5 }, front = 1.1 },
	["Cross.Active"] = { at = { -0.1, 0.45, -0.7 }, dir = { -0.55, 0.05, -0.85 }, front = 1.1 },
	-- 3 COUP BAS: raised a little, then the point driven down at the floor before him
	["Elbow.Startup"] = { at = { 0, 0.6, -0.2 }, dir = { 0, 0.3, -1 }, front = 1.2 },
	["Elbow.Active"] = { at = { 0, 1.0, -0.5 }, dir = { 0, -0.55, -1 }, front = 1.2 },
	-- 4 ESTOC FINAL: drawn right back, then the deep thrust, a little up (it sends him back)
	["Kick.Startup"] = { at = { 0, 0.3, -0.35 }, dir = { 0, 0.05, -1 }, front = 1.1 },
	["Kick.Active"] = { at = { 0, 0.6, -1.2 }, dir = { 0, 0.22, -1 }, front = 1.2 },
	-- M2: PRÉPARATION the spear raised over his head and drawn back, then PERCÉE with all his weight
	["Smash.Startup"] = { at = { 0, 1.3, 0.3 }, dir = { 0, -0.15, -1 }, front = 1.2 },
	["Smash.Active"] = { at = { 0, 0.5, -1.3 }, dir = { 0, 0, -1 }, front = 1.2 },
	-- (Wilhem: « gère mieux le idle de la lance, aussi fluide que l'orbe de DAICHA ») the second
	-- key of his idle: the spear drawn back a little and its point raised, breathing in; the
	-- idle rhythm sways between the two, the point rising and falling at the opponent
	Idle2 = { at = { 0, 0.55, -0.8 }, dir = { 0, 0.06, -1 }, front = 1.25 },
	-- (Wilhem: « mets-lui une pose comme le bâton de Wukong sur les épaules ») at rest: the
	-- spear laid across his shoulders behind his neck, the right hand out on it by his right
	-- shoulder, the left wrist hung over it on the other side, the head out past his left
	-- (tilted across his back, the point out forward and up past his left shoulder: from the
	-- side camera a level shaft hid behind his head)
	Shoulders = { neck = true, at = { 0.9, 0.05, 0.55 }, dir = { -1, 0.32, -0.55 }, front = 1.9, frontMin = 1.4, frontMax = 2.3 },
	Shoulders2 = { neck = true, at = { 0.9, 0.12, 0.55 }, dir = { -1, 0.42, -0.55 }, front = 1.9, frontMin = 1.4, frontMax = 2.3 },
	-- (then, Wilhem's sheet « IDLE / MARCHE »: the spear on ONE shoulder, the right hand holding
	-- it just before that shoulder, the other arm hanging; walking, the same. Wilhem: « la pointe
	-- de la lance peut être vers l'arrière pendant l'idle » : the point back and up past his left
	-- shoulder, behind his head, the butt down in front)
	Carry = { neck = true, at = { 0.6, -0.1, -0.4 }, dir = { -0.45, 0.26, 0.86 }, rest = { 0.55, 0.05, 0 }, hang = { 8, -12, 14 } },
	Carry2 = { neck = true, at = { 0.6, -0.05, -0.38 }, dir = { -0.45, 0.32, 0.84 }, rest = { 0.55, 0.05, 0 }, hang = { 4, -14, 20 } },
	CarryRun = { neck = true, at = { 0.6, -0.1, -0.4 }, dir = { -0.45, 0.4, 0.8 }, rest = { 0.55, 0.05, 0 }, hang = { 8, -12, 14 } },
	-- running in: the spear carried level, a little up (the stride pumps the arms)
	RunUpper = { at = { 0, 0.5, -0.85 }, dir = { 0, 0.35, -1 }, front = 1.25 },
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
	local role, phase = string.match(key, "^(%a+)%.(%a+)$")
	local raw = if role then Poses["Raijin" .. role][phase]
		elseif key == "Idle2" or key == "Shoulders2" then Poses.Kits.RAIJIN.Idle[2]
		elseif key == "Shoulders" or key == "Carry" then Poses.Kits.RAIJIN.STANCE
		elseif key == "Carry2" then Poses.Kits.RAIJIN.Idle[2]
		elseif key == "CarryRun" then Poses.Kits.RAIJIN.RunUpper
		else Poses.Kits.RAIJIN[key]
	local base = anim:resolve(raw)
	local pose = table.clone(base)
	local t = RaijinHold.TARGETS[key]
	local arms = holdArms(a)
	if t and t.hang then
		-- (one hand on the spear: the other arm hangs, relaxed)
		arms.LeftShoulder, arms.LeftElbow, arms.LeftWrist = { t.hang[1], 0, t.hang[2] }, { t.hang[3], 0, 0 }, { 0, 0, 0 }
	end
	for k, v in arms do pose[k] = v end
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

-- How deep his arms go into his own torso, hips and head (summed over points along them).
local ARM_PARTS = { "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand" }
local CORE = { "UpperTorso", "LowerTorso", "Head" }
function RaijinHold.armsInBody(parts)
	local total = 0
	for _, name in ARM_PARTS do
		local arm = parts[name]
		if arm then
			local upper = string.find(name, "UpperArm") ~= nil
			for i = 0, 6 do
				local u = i / 6 - 0.5
				-- (the top of the upper arm sits in the shoulder: not counted)
				if not (upper and u > 0.15) then
					local x, y, z = K.point(arm.cframe, 0, u * arm.size[2], 0)
					for _, core in CORE do
						local c = parts[core]
						local lx, ly, lz = K.point(K.inverse(c.cframe), x, y, z)
						local d = math.min(c.size[1] / 2 + 0.05 - math.abs(lx), c.size[2] / 2 + 0.05 - math.abs(ly), c.size[3] / 2 + 0.05 - math.abs(lz))
						if d > 0 then total += d end
					end
				end
			end
		end
	end
	return total
end

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
	if t.neck then
		-- (from the base of his neck: the top of his chest)
		local nx, ny, nz = K.point(parts.UpperTorso.cframe, 0, parts.UpperTorso.size[2] / 2, 0)
		px, py, pz = nx + t.at[1] * side, ny + t.at[2], nz + t.at[3]
	end
	local d = norm({ t.dir[1] * side, t.dir[2], t.dir[3] })
	local cost = 3 * ((gx - px) ^ 2 + (gy - py) ^ 2 + (gz - pz) ^ 2)
	cost += RaijinHold.AIM * (1 - (ax * d[1] + ay * d[2] + az * d[3]))
	-- the front hand on the shaft, `front` up from the rear one
	-- the shaft resting on a shoulder (`rest`: a point of his chest's top, in its own axes)
	if t.rest then
		local rx, ry, rz = K.point(parts.UpperTorso.cframe, t.rest[1] * side * parts.UpperTorso.size[1] / 2,
			parts.UpperTorso.size[2] / 2 + t.rest[2], t.rest[3])
		local u = (rx - gx) * ax + (ry - gy) * ay + (rz - gz) * az
		local cx, cy, cz = gx + ax * u, gy + ay * u, gz + az * u
		local dist = math.sqrt((rx - cx) ^ 2 + (ry - cy) ^ 2 + (rz - cz) ^ 2)
		cost += 8 * (dist - 0.12) ^ 2
	end
	-- (anywhere from 0.7 to 1.8 up the shaft: the closest point of that stretch)
	local f = parts.LeftHand.cframe
	local along = math.clamp((f[1] - gx) * ax + (f[2] - gy) * ay + (f[3] - gz) * az, t.frontMin or 0.7, t.frontMax or 1.8)
	local fx, fy, fz = gx + ax * along, gy + ay * along, gz + az * along
	if not t.hang then cost += RaijinHold.FRONT * ((f[1] - fx) ^ 2 + (f[2] - fy) ^ 2 + (f[3] - fz) ^ 2) end
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
	-- (Wilhem: « il a ses bras dans le corps ») every arm, its whole length (the shoulder's
	-- own end aside), clear of his torso, hips and head
	local armsIn = RaijinHold.armsInBody(parts)
	cost += 30 * armsIn
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
	cost += 0.5 * (over(a[1], "RightShoulder") + over(a[3], "RightElbow") + over(a[4], "RightWrist") + over(a[5], "LeftShoulder")
		+ over(a[7], "LeftElbow"))
	if math.abs(a[2]) > 95 then cost += 0.5 * (math.abs(a[2]) - 95) end
	if math.abs(a[6]) > 130 then cost += 0.5 * (math.abs(a[6]) - 130) end
	for i = 8, 10 do
		if a[i] and math.abs(a[i]) > 70 then cost += 0.5 * (math.abs(a[i]) - 70) end
	end
	return cost, inside, math.sqrt((f[1] - fx) ^ 2 + (f[2] - fy) ^ 2 + (f[3] - fz) ^ 2), math.deg(math.acos(math.clamp(ax * d[1] + ay * d[2] + az * d[3], -1, 1))), armsIn
end

RaijinHold.CLEAR_ARMS = { "LeftHand", "RightHand", "LeftLowerArm", "RightLowerArm" }
RaijinHold.FRONT = tonumber(args[5]) or 12
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
	-- (the holds in PoseLibrary now: the start of every search)
	local current = {
		STANCE = { 0, -65, 68, -31, 62, 48, 7, -12, 70, -12 }, Crouch = { 19, -56, 81, -27, 39, 61, -1, 6, 70, 30 },
		Block = { 12, -18, 72, -1, 37, 76, 69, 16, -70, 6 }, CrouchBlock = { -10, -12, 112, -23, 64, 70, 13, 6, -60, 21 },
		RunUpper = { -18, -5, 103, -39, 82, 29, 54, 16, -59, -58 }, Idle2 = { 10, -61, 72, -27, 72, 49, 4, -3, 70, -12 },
		Shoulders = { 173, 92, 99, -18, 47, -9, 149, 70, -44, -8 }, Shoulders2 = { 173, 92, 99, -18, 47, -9, 149, 70, -44, -8 },
		Carry = { 168, 84, 155, -38, 8, -12, 14, -36, -70, 0 }, Carry2 = { 168, 84, 155, -39, 4, -14, 20, -36, -70, 0 },
		CarryRun = { 136, 39, 155, -20, 8, -12, 14, -60, -70, 0 },
		["Jab.Startup"] = { 15, -60, -5, 31, 87, 55, 1, -21, 69, -44 }, ["Jab.Active"] = { 45, -59, 6, -39, 65, 8, 30, -18, 3, 0 },
		["Cross.Startup"] = { 18, -59, -5, 31, -12, 74, 17, -19, 70, 44 }, ["Cross.Active"] = { 61, -59, 41, -70, -6, -35, 106, 33, -59, 9 },
		["Elbow.Startup"] = { -12, -65, 6, 27, 66, 41, 20, -38, -70, -24 }, ["Elbow.Active"] = { 182, -65, 155, 38, 63, 64, 44, -24, -26, -13 },
		["Kick.Startup"] = { 16, -58, 3, 34, 16, 55, 4, -17, 70, 34 }, ["Kick.Active"] = { 49, -54, -1, -23, -2, -71, 54, -5, -27, -54 },
		["Smash.Startup"] = { -50, 55, 115, -69, 15, 16, 80, 58, 26, -24 }, ["Smash.Active"] = { 25, -54, 95, -58, 88, 45, 6, 11, 47, -12 },
	}
	local keys = if args[1] == "all" then { "STANCE", "Idle2", "Crouch", "Block", "CrouchBlock", "RunUpper" }
		elseif args[1] == "sheet" then { "Jab.Startup", "Jab.Active", "Cross.Startup", "Cross.Active", "Elbow.Startup", "Elbow.Active",
			"Kick.Startup", "Kick.Active", "Smash.Startup", "Smash.Active" }
		else { args[1] }
	for _, key in keys do
		local c0, in0, f0, a0, arm0 = RaijinHold.cost(key, current[key])
		local start = table.clone(current[key])
		for i = 8, 10 do start[i] = start[i] or 0 end
		local best, cost = RaijinHold.solve(key, start, tonumber(args[3]) or 7)
		local _, inside, front, angle, arms = RaijinHold.cost(key, best)
		local r = {}
		for i, v in best do r[i] = tostring(math.floor(v + 0.5)) end
		print(string.format("%-11s before: cost %.2f (spear in body %.2f, arms in body %.2f, front hand %.2f off, aim %.0f°)", key, c0, in0, arm0, f0, a0))
		print(string.format("%-11s after:  cost %.2f (spear in body %.2f, arms in body %.2f, front hand %.2f off, aim %.0f°)   %s = { %s },", key, cost,
			inside, arms, front, angle, key, table.concat(r, ", ")))
	end
end

return RaijinHold
