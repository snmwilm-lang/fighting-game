-- Plays a scripted fight with the real simulation and both bodies posed by the real Animator,
-- tick by tick, for tests/AnimClip.luau (GIF clips) and tests/AnimQuality.luau (motion checks).
local Config = require("../src/shared/CombatConfig")
local MoveData = require("../src/shared/MoveData")
local Sim = require("../src/shared/CombatSimulation")
local RigSpec = require("../src/shared/RigSpec")
local K = require("../src/shared/Kinematics")
local Poses = require("../src/shared/PoseLibrary")
local Animator = require("../src/shared/Animator")

local ClipKit = {}
ClipKit.SKELETON = K.fromSpec(RigSpec.KAI)
local SKELETON = ClipKit.SKELETON

-- A script: { ticks, input fields held, press = button pressed on the first tick }.
local function press(button, ticks, extra)
	local s = { ticks or 12, press = button }
	for k, v in extra or {} do s[k] = v end
	return s
end
local function hold(ticks, extra)
	local s = { ticks }
	for k, v in extra or {} do s[k] = v end
	return s
end
ClipKit.SCRIPTS = {
	walk = { hold(20), hold(50, { axis = 1 }), hold(20), hold(40, { axis = -1 }), hold(20) },
	combo = { hold(16), press("light", 11), press("light", 11), press("light", 11), press("light", 40), hold(10) },
	heavy = { hold(16), press("heavy", 14), press("heavy", 50), hold(10), press("special", 60), hold(10) },
	moves = { hold(12), press("heavy", 46), press("special", 56), press("light", 30, { crouch = true }),
		press("heavy", 40, { crouch = true }), press("special", 60, { crouch = true }), hold(10) },
	showcase = { hold(24), hold(26, { axis = 1 }), hold(8), press("dash", 18), hold(10),
		press("light", 11), press("light", 11), press("light", 11), press("light", 36),
		press("heavy", 14), press("heavy", 46), hold(6), press("jump", 14), press("light", 30), hold(10),
		press("light", 30, { crouch = true }), hold(14), hold(24, { axis = -1 }), press("special", 54), hold(16) },
	-- (KIT is the one hit: KAI walks in and lands a combo, a heavy, a sweep and a launcher)
	hit = { hold(10), hold(24, { axis = 1 }), press("light", 11), press("light", 11), press("light", 11), press("light", 40),
		hold(20, { axis = 1 }), press("heavy", 40), hold(16, { axis = 1 }), press("heavy", 12), press("light", 60),
		hold(30, { axis = 1 }), press("heavy", 12, { crouch = true }), hold(70) },
	routes = { hold(10), press("light", 11), press("heavy", 12), press("light", 12), press("heavy", 50), hold(20, { axis = 1 }),
		press("heavy", 13), press("light", 13), press("heavy", 13), press("light", 50), hold(20, { axis = 1 }),
		press("light", 11), press("light", 11), press("heavy", 13), press("heavy", 50), hold(10) },
}

-- Root frame as the client places it (3/4 turn toward the camera, the heading easing round).
local function rootFrame(view, heading)
	local h = heading + math.rad(Config.ModelYaw) * math.cos(heading)
	local dx, dz = math.cos(h), math.sin(h)
	return { view.x, view.y + Config.RootHeight, view.z or 0, -dz, 0, -dx, 0, 1, 0, dx, 0, -dz }
end

--[[
	onTick(info) every tick: info = { tick, views, parts = { [slot] = { [part] = { cframe, size } } },
	poses, keys, snaps, attacker, defender }. victim: KIT is the one being hit (KAI attacks).
]]
function ClipKit.play(kitName, scriptName, poseRate, onTick)
	local script = ClipKit.SCRIPTS[scriptName] or ClipKit.SCRIPTS.showcase
	-- A route ("LLRRLR"): from close, each key pressed like a player, once the blow before has hit.
	local route = if scriptName:match("^[LR]+$") then {} else nil
	if route then
		for c in scriptName:gmatch("[LR]") do table.insert(route, c) end
		script = { { 300 } }
	end
	local step, pressedFor = 1, nil
	local victim = scriptName == "hit"
	local world = Sim.newWorld(Config, MoveData, true)
	local attacker, defender = 1, 2
	Sim.setKits(world, if victim then "KAI" else kitName, if victim then kitName else "KAI")
	world.phase = "Fight"
	world.fighters[1].x, world.fighters[2].x = -3.2, if route then -0.2 else 3.2
	local anims, headings = {}, {}
	for i = 1, 2 do
		anims[i] = Animator.new({ poses = Poses, moves = MoveData.Moves, kin = K, config = Config, skeleton = SKELETON,
			kits = MoveData.Kits, moveKit = MoveData.MoveKit })
	end
	local tick = 0
	for _, s in script do
		for t = 1, s[1] do
			local input = Sim.neutralInput()
			input.axis = s.axis or 0
			input.crouch = s.crouch or false
			input.block = s.block or false
			if s.press and t == 1 then input[s.press] = true end
			if route then
				local a = world.fighters[attacker]
				local key = a.move and (a.move .. tostring(a.moveContact ~= nil))
				if route[step] and (step == 1 or (a.move and a.moveContact and key ~= pressedFor
					and a.moveHits >= (MoveData.Moves[a.move].hits or 1))) then
					input[if route[step] == "L" then "light" else "heavy"] = true
					pressedFor, step = key, step + 1
				end
			end
			local inputs = { Sim.neutralInput(), Sim.neutralInput() }
			inputs[attacker] = input
			Sim.step(world, inputs)
			tick += 1
			local views = {}
			for i, f in world.fighters do
				views[i] = { x = f.x, y = f.y, vx = f.vx + (f.pushVx or 0), vy = f.vy, facing = f.facing, state = f.state,
					move = f.move, moveFrame = f.moveFrame, hitstop = f.hitstop, combo = f.comboHits, kit = f.kit,
					stance = f.stance, weave = (f.weaveTicks or 0) > 0 }
			end
			local parts, poses, keys, snaps = {}, {}, {}, {}
			local push = Animator.spacing(views[1].x, views[1].y, views[2].x, views[2].y)
			local side = if views[2].x >= views[1].x then 1 else -1
			local drawnX = { views[1].x - side * push, views[2].x + side * push }
			for i = 1, 2 do
				local v = views[i]
				local goal = if v.facing > 0 then 0 else math.pi
				headings[i] = if headings[i] then headings[i] + (goal - headings[i]) * math.min(1, 25 / 60) else goal
				local pose, lift = anims[i]:step(v, views[3 - i], 1 / 60, tick / 60, poseRate, false)
				poses[i], keys[i], snaps[i] = pose, anims[i].lastKey, anims[i].snapped
				local solved = K.solve(SKELETON, pose, lift)
				local root = rootFrame({ x = drawnX[i], y = v.y, z = v.z }, headings[i])
				parts[i] = {}
				for name, f in solved do
					local size = SKELETON.sizes[name]
					if size and name ~= "HumanoidRootPart" then parts[i][name] = { cframe = K.mul(root, f), size = size } end
				end
			end
			onTick({ tick = tick, views = views, parts = parts, poses = poses, keys = keys, snaps = snaps,
				attacker = attacker, defender = defender })
		end
	end
end

return ClipKit
