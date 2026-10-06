-- Plays a cinematic offline with the real simulation, director, animator and rig forward
-- kinematics, and gives every staged frame with the world boxes of both bodies and the
-- camera. Used by tests/Cinematography.test.luau (framing checks) and tests/Storyboard.luau
-- (contact sheets rendered by tools/storyboard.py).
local Config = require("../src/shared/CombatConfig")
local MoveData = require("../src/shared/MoveData")
local CharacterData = require("../src/shared/CharacterData")
local Sim = require("../src/shared/CombatSimulation")
local Director = require("../src/shared/CinematicDirector")
local RigSpec = require("../src/shared/RigSpec")
local K = require("../src/shared/Kinematics")
local Poses = require("../src/shared/PoseLibrary")
local Animator = require("../src/shared/Animator")

local Kit = {}
local SKELETON = K.fromSpec(RigSpec.KAI)

-- Root frame of a rig as the client places it (3/4 turn toward the camera, or lookDir).
local function rootFrame(view, heading)
	local dx, dz
	if view.lookDir then
		dx, dz = view.lookDir.x, view.lookDir.z
	else
		local h = heading + math.rad(Config.ModelYaw) * math.cos(heading)
		dx, dz = math.cos(h), math.sin(h)
	end
	local l = math.sqrt(dx * dx + dz * dz)
	dx, dz = dx / l, dz / l
	return { view.x, view.y + Config.RootHeight, view.z or 0, -dz, 0, -dx, 0, 1, 0, dx, 0, -dz }
end

local function resolve(point, parts)
	if point.position then return point.position.x, point.position.y, point.position.z or 0 end
	local p = parts[point.slot][point.part]
	local t = p.cframe
	return t[1] + point.offset.x, t[2] + point.offset.y, t[3] + (point.offset.z or 0)
end
Kit.resolve = resolve

--[[
	onFrame(info) for every tick: info = { tick, frame, views, parts = { [slot] = { [part] =
	{ cframe, size } } }, cam = { x, y, z }, target = { x, y, z }, focus = { x, y, z } }.
	center: x where the fight happens; hp: the target's health (low = FINAL FINISH).
]]
function Kit.play(kit, kind, style, hp, center, onFrame)
	local world = Sim.newWorld(Config, MoveData, true)
	Sim.setKits(world, kit, "KAI")
	world.phase = "Fight"
	world.fighters[1].x, world.fighters[2].x = center - 1.3, center + 1.3
	Sim.debugCinematic(world, 1, kind, style, hp)
	local anims, headings, anchors = {}, {}, {}
	for i = 1, 2 do
		anims[i] = Animator.new({ poses = Poses, moves = MoveData.Moves, kin = K, config = Config, skeleton = SKELETON,
			kits = MoveData.Kits, moveKit = MoveData.MoveKit })
	end
	local tick = 0
	while world.cinematic do
		local cin = world.cinematic
		local views = {}
		for i, f in world.fighters do
			views[i] = { x = f.x, y = f.y, vx = f.vx, vy = f.vy, facing = f.facing, state = f.state, move = f.move,
				moveFrame = f.moveFrame, hp = f.hp, wins = f.wins, hitstop = f.hitstop, combo = f.comboHits, kit = f.kit }
		end
		local frame = Director.cinematic({ cin = cin, tick = cin.tick, views = views, anchors = anchors, moveData = MoveData,
			config = Config, characters = CharacterData })
		if frame then
			local parts, poses = {}, {}
			for i = 1, 2 do
				local v = views[i]
				local goal = if v.facing > 0 then 0 else math.pi
				headings[i] = if headings[i] then headings[i] + (goal - headings[i]) * 0.4 else goal
				local pose, lift = anims[i]:step(v, views[3 - i], 1 / 60, tick / 60, 60, true)
				poses[i] = pose
				local solved = K.solve(SKELETON, pose, lift)
				local root = rootFrame(v, headings[i])
				parts[i] = {}
				for name, t in solved do
					local size = SKELETON.sizes[name]
					if size and name ~= "HumanoidRootPart" then parts[i][name] = { cframe = K.mul(root, t), size = size } end
				end
			end
			local s = frame.shot
			local cx, cy, cz = resolve(s.from, parts)
			local tx, ty, tz = resolve(s.to, parts)
			local fx, fy, fz = resolve(s.focus, parts)
			onFrame({ tick = cin.tick, frame = frame, views = views, parts = parts, poses = poses, cin = cin,
				cam = { cx, cy, cz }, target = { tx, ty, tz }, focus = { fx, fy, fz } })
		end
		tick += 1
		Sim.step(world, { Sim.neutralInput(), Sim.neutralInput() })
		if tick > 900 then break end
	end
end

-- The winner's K.O. scene (the end of a match: Director.ko), `kit` the winner, for the
-- `koCount`-th scene of the session (a kit with two victories shows them in turn). Same
-- onFrame(info) as Kit.play.
function Kit.playKO(kit, koCount, onFrame)
	local world = Sim.newWorld(Config, MoveData, true)
	Sim.setKits(world, kit, "KAI")
	world.fighters[1].x, world.fighters[2].x = -1.6, 1.6
	local anims, anchors = {}, {}
	for i = 1, 2 do
		anims[i] = Animator.new({ poses = Poses, moves = MoveData.Moves, kin = K, config = Config, skeleton = SKELETON,
			kits = MoveData.Kits, moveKit = MoveData.MoveKit })
	end
	for t = 0, Director.KO_SCENE do
		local views = {}
		for i, f in world.fighters do
			views[i] = { x = f.x, y = 0, vx = 0, vy = 0, facing = if i == 1 then 1 else -1, state = "Idle", hp = f.hp,
				wins = if i == 1 then Config.RoundsToWin else 0, hitstop = 0, combo = 0, kit = f.kit }
		end
		local ctx = { views = views, anchors = anchors, moveData = MoveData, config = Config, characters = CharacterData,
			koCount = koCount, tick = t }
		local frame = Director.ko(ctx, 1, 2, views[1], views[2], t)
		local parts = {}
		for i = 1, 2 do
			local v = views[i]
			local pose, lift = anims[i]:step(v, views[3 - i], 1 / 60, t / 60, 60, true)
			local solved = K.solve(SKELETON, pose, lift)
			local root = rootFrame(v, if v.facing > 0 then 0 else math.pi)
			parts[i] = {}
			for name, tr in solved do
				local size = SKELETON.sizes[name]
				if size and name ~= "HumanoidRootPart" then parts[i][name] = { cframe = K.mul(root, tr), size = size } end
			end
		end
		local s = frame.shot
		local cx, cy, cz = resolve(s.from, parts)
		local tx, ty, tz = resolve(s.to, parts)
		local fx, fy, fz = resolve(s.focus, parts)
		onFrame({ tick = t, frame = frame, views = views, parts = parts, cam = { cx, cy, cz }, target = { tx, ty, tz }, focus = { fx, fy, fz } })
	end
end

-- The match's mini intro (Director.intro): `kit` on the left, `foe` on the right, at their
-- spawns. Same onFrame(info) as Kit.play.
function Kit.playIntro(kit, foe, onFrame)
	local world = Sim.newWorld(Config, MoveData, false)
	Sim.setKits(world, kit, foe or "KAI")
	local anims, anchors = {}, {}
	for i = 1, 2 do
		anims[i] = Animator.new({ poses = Poses, moves = MoveData.Moves, kin = K, config = Config, skeleton = SKELETON,
			kits = MoveData.Kits, moveKit = MoveData.MoveKit })
	end
	local tick = 0
	while true do
		local t = Director.introScene(world, Config)
		if not t then break end
		local views = {}
		for i, f in world.fighters do
			views[i] = { x = f.x, y = 0, vx = 0, vy = 0, facing = f.facing, state = "Idle", hp = f.hp, wins = 0, hitstop = 0,
				combo = 0, kit = f.kit, intro = true }
		end
		local ctx = { views = views, anchors = anchors, moveData = MoveData, config = Config, characters = CharacterData, tick = t }
		local frame = Director.intro(ctx, views, t)
		local parts = {}
		for i = 1, 2 do
			local v = views[i]
			local pose, lift = anims[i]:step(v, views[3 - i], 1 / 60, tick / 60, 60, true)
			local solved = K.solve(SKELETON, pose, lift)
			local root = rootFrame(v, if v.facing > 0 then 0 else math.pi)
			parts[i] = {}
			for name, tr in solved do
				local size = SKELETON.sizes[name]
				if size and name ~= "HumanoidRootPart" then parts[i][name] = { cframe = K.mul(root, tr), size = size } end
			end
		end
		local s = frame.shot
		local cx, cy, cz = resolve(s.from, parts)
		local tx, ty, tz = resolve(s.to, parts)
		local fx, fy, fz = resolve(s.focus, parts)
		onFrame({ tick = t, frame = frame, views = views, parts = parts, cam = { cx, cy, cz }, target = { tx, ty, tz }, focus = { fx, fy, fz } })
		tick += 1
		Sim.step(world, { Sim.neutralInput(), Sim.neutralInput() })
		if tick > 400 then break end
	end
end

-- Distance from a point to a part's box (0 inside).
function Kit.boxDistance(part, x, y, z)
	local t, s = part.cframe, part.size
	local dx, dy, dz = x - t[1], y - t[2], z - t[3]
	-- Columns of the rotation are the box axes.
	local lx = dx * t[4] + dy * t[7] + dz * t[10]
	local ly = dx * t[5] + dy * t[8] + dz * t[11]
	local lz = dx * t[6] + dy * t[9] + dz * t[12]
	local ox = math.max(0, math.abs(lx) - s[1] / 2)
	local oy = math.max(0, math.abs(ly) - s[2] / 2)
	local oz = math.max(0, math.abs(lz) - s[3] / 2)
	return math.sqrt(ox * ox + oy * oy + oz * oz)
end

-- Camera basis and projection to normalized screen coordinates (x, y in [-1, 1] inside the
-- 16:9 frame; nil behind the camera).
function Kit.projector(cam, target, fov, roll)
	local fx, fy, fz = target[1] - cam[1], target[2] - cam[2], target[3] - cam[3]
	local l = math.sqrt(fx * fx + fy * fy + fz * fz)
	fx, fy, fz = fx / l, fy / l, fz / l
	local rx, ry, rz = fy * 0 - fz * 1, fz * 0 - fx * 0, fx * 1 - fy * 0 -- forward x up
	local rl = math.sqrt(rx * rx + ry * ry + rz * rz)
	if rl < 1e-6 then rx, ry, rz, rl = 1, 0, 0, 1 end
	rx, ry, rz = rx / rl, ry / rl, rz / rl
	local ux, uy, uz = ry * fz - rz * fy, rz * fx - rx * fz, rx * fy - ry * fx
	local c, s = math.cos(roll), math.sin(roll)
	rx, ry, rz, ux, uy, uz = rx * c + ux * s, ry * c + uy * s, rz * c + uz * s, ux * c - rx * s, uy * c - ry * s, uz * c - rz * s
	local tanHalf = math.tan(math.rad(fov) / 2)
	return function(x, y, z)
		local dx, dy, dz = x - cam[1], y - cam[2], z - cam[3]
		local depth = dx * fx + dy * fy + dz * fz
		if depth < 0.05 then return nil end
		return (dx * rx + dy * ry + dz * rz) / depth / tanHalf / (16 / 9), (dx * ux + dy * uy + dz * uz) / depth / tanHalf, depth
	end
end

-- Screen bounds of a body (every corner of every part). Returns minX, maxX, minY, maxY, or
-- nil if part of it is behind the camera.
function Kit.bodyBounds(project, parts)
	local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
	for _, part in parts do
		local t, s = part.cframe, part.size
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local lx, ly, lz = sx * s[1] / 2, sy * s[2] / 2, sz * s[3] / 2
					local x = t[1] + t[4] * lx + t[5] * ly + t[6] * lz
					local y = t[2] + t[7] * lx + t[8] * ly + t[9] * lz
					local z = t[3] + t[10] * lx + t[11] * ly + t[12] * lz
					local px, py = project(x, y, z)
					if not px then return nil end
					minX, maxX = math.min(minX, px), math.max(maxX, px)
					minY, maxY = math.min(minY, py), math.max(maxY, py)
				end
			end
		end
	end
	return minX, maxX, minY, maxY
end

return Kit
