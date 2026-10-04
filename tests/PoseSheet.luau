-- Pose sheet (not a test): the same poses on an R6 body (left) and on the R15 KAI rig (right),
-- animated by the real Animator (and the R6 retarget). Writes frames for tools/storyboard.py:
--   luau tests/PoseSheet.luau -a [KIT] [yaw] > sheet.txt
--   python3 tools/storyboard.py sheet.txt sheet.png
-- yaw: camera angle in degrees around the bodies (0 = from the arena camera side).
local Config = require("../src/shared/CombatConfig")
local MoveData = require("../src/shared/MoveData")
local RigSpec = require("../src/shared/RigSpec")
local K = require("../src/shared/Kinematics")
local Poses = require("../src/shared/PoseLibrary")
local Animator = require("../src/shared/Animator")
local Retarget = require("../src/shared/Retarget")
local WeaponKit = require("./WeaponKit")

local args = { ... }
-- KIT or KIT:STANCE (TARO:CLASSIQUE, TARO:ESQUIVE)
local kitName, stanceName = string.match(args[1] or "KAI", "^([^:]+):?(.*)$")
stanceName = if stanceName ~= "" then stanceName else nil
local yaw = math.rad(tonumber(args[2]) or 20)
local kit = MoveData.Kits[kitName]

local function r6Skeleton()
	local sizes, joints = {}, {}
	for name, p in RigSpec.R6.parts do sizes[name] = table.clone(p.size) end
	for _, j in RigSpec.R6.joints do
		table.insert(joints, { name = j.name, part0 = j.part0, part1 = j.part1, c0 = table.clone(j.c0), c1 = table.clone(j.c1) })
	end
	return K.skeleton(joints, sizes)
end

local R15 = K.fromSpec(RigSpec.KAI)
local function newAnimator(skeleton)
	return Animator.new({ poses = Poses, moves = MoveData.Moves, kin = K, config = Config, skeleton = skeleton,
		kits = MoveData.Kits, moveKit = MoveData.MoveKit })
end

-- Root frame facing +X (toward the opponent), turned 3/4 toward the camera like in game.
local function rootFrame(x, y, height)
	local h = math.rad(Config.ModelYaw)
	local dx, dz = math.cos(h), math.sin(h)
	return { x, y + height, 0, -dz, 0, -dx, 0, 1, 0, dx, 0, -dz }
end

local function role(id)
	return kit.Roles and kit.Roles[id] or id
end

-- Situations: a view sequence (function of the tick) and the tick shown.
local cases = {}
local function add(name, show, view)
	table.insert(cases, { name = name, show = show, view = view })
end
local function still(state, extra)
	return function()
		local v = { state = state, x = 0, y = 0, vx = 0, vy = 0, facing = 1, hitstop = 0, combo = 0 }
		for k, x in extra or {} do v[k] = x end
		return v
	end
end
local function attack(id, at)
	id = role(id)
	local m = MoveData.Moves[id]
	if not m then return nil end
	local frame = m.startup + (at or 1)
	return function(t)
		return { state = "Attack", move = id, moveFrame = math.max(0, t - (40 - frame)), x = 0, y = if m.air then 2 else 0,
			vx = 0, vy = 0, facing = 1, hitstop = 0, combo = 0 }
	end, 40
end
add("Idle", 40, still("Idle"))
add("Walking", 47, still("Walking", { vx = Config.WalkSpeed or 8 }))
add("Crouching", 40, still("Crouching"))
add("Blocking", 40, still("Blocking"))
add("Jumping", 40, still("Jumping", { y = 3, vy = 20 }))
add("Hitstun", 40, still("Hitstun", { combo = 1 }))
for _, id in { "Jab", "Cross", "Elbow", "Kick", "Uppercut", "SpinKick", "Hammer", "Sweep", "LowKick", "AirKick", "BodyBlow",
	"KiBlast" } do
	local f, show = attack(id)
	if f then add(role(id), show, f) end
end
if stanceName == "CLASSIQUE" then
	local f, show = attack("TaroChampion")
	if f then add("TaroChampion", show, f) end
end
local weave = kit.Stances and kit.Stances.ESQUIVE and kit.Stances.ESQUIVE.Weave
if weave and stanceName ~= "CLASSIQUE" then -- the boxer: weave (forward dash) and DEMPSEY ROLL
	add("Weave", 4, still("Dashing", { vx = kit.Stats.DashSpeed, weave = true }))
	for _, id in { weave.Hook, "TaroDempseyR", weave.Finish } do
		local f, show = attack(id)
		if f then add(id, show, f) end
	end
end

local function fmt(n) return string.format("%.3f", n) end
local tick = 0
for _, case in cases do
	local r6 = r6Skeleton()
	local rt = Retarget.new(K, r6)
	local anims = { newAnimator(rt.virtual), newAnimator(R15) }
	local other = { state = "Idle", x = 3, y = 0, vx = 0, vy = 0, facing = -1, hitstop = 0, combo = 0 }
	local parts, shown = { {}, {} }, {}
	for t = 0, case.show do
		local view = case.view(t)
		view.kit, view.stance = kitName, stanceName
		local r6View, r15View = table.clone(view), table.clone(view)
		r6View.x, r15View.x = view.x - 3.2, view.x + 3.2
		local otherA, otherB = table.clone(other), table.clone(other)
		otherA.x, otherB.x = r6View.x + 3, r15View.x + 3
		local pose = anims[1]:step(r6View, otherA, 1 / 60, t / 60, 60, false)
		local poseB, liftB = anims[2]:step(r15View, otherB, 1 / 60, t / 60, 60, false)
		if t == case.show then
			shown = { r6View, r15View }
			local _, lift, solved, virtual = Retarget.solve(rt, pose, view.y)
			local root = rootFrame(r6View.x, view.y, -r6.floor + lift)
			for name, f in solved do
				local size = r6.sizes[name]
				if size then parts[1][name] = { cframe = K.mul(root, f), size = size } end
			end
			-- (the weapon is held by the virtual R15 hand, as in the game)
			for _, side in { "LeftHand", "RightHand" } do
				parts[1]["@" .. side] = { cframe = K.mul(root, virtual[side]), size = rt.virtual.sizes[side] }
			end
			local solvedB = K.solve(R15, poseB, liftB)
			local rootB = rootFrame(r15View.x, view.y, Config.RootHeight)
			for name, f in solvedB do
				local size = R15.sizes[name]
				if size and name ~= "HumanoidRootPart" then parts[2][name] = { cframe = K.mul(rootB, f), size = size } end
			end
		end
	end
	tick += 1
	local cx, cy, cz = math.sin(yaw) * 17, 3.4, math.cos(yaw) * 17
	print(string.format("FRAME %d %s 36 0 000000 0 -", tick, case.name))
	print(string.format("CAM %s %s %s 0 3 0", fmt(cx), fmt(cy), fmt(cz)))
	for slot = 1, 2 do
		for name, part in parts[slot] do
			if name:sub(1, 1) == "@" then continue end
			local out = {}
			for i = 1, 12 do out[i] = fmt(part.cframe[i]) end
			print(string.format("PART %d %s %s %s %s %s", slot, (name:gsub(" ", "_")), table.concat(out, " "),
				fmt(part.size[1]), fmt(part.size[2]), fmt(part.size[3])))
		end
		-- The kit's weapon in the hand (SHIN's katana, DAICHA's orb), in its own colours.
		for _, piece in WeaponKit.pieces(kitName, parts[slot], nil, { view = shown[slot], time = case.show / 60 }) do
			local out = {}
			for i = 1, 12 do out[i] = fmt(piece.cframe[i]) end
			print(string.format("PART %d %s %s %s %s %s %s", slot, piece.name, table.concat(out, " "),
				fmt(piece.size[1]), fmt(piece.size[2]), fmt(piece.size[3]), piece.color))
		end
	end
end
