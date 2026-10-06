-- Animation clip (not a test): a scripted fight played by the real simulation, both bodies
-- posed by the real Animator (tests/ClipKit.luau), filmed by the in-game side camera, one
-- frame every STEP ticks. Writes frames for tools/storyboard.py, which makes an animated GIF:
--   luau tests/AnimClip.luau -a KIT [SCRIPT] [POSERATE] [STEP] [ZOOM] > clip.txt
--   python3 tools/storyboard.py clip.txt clip.gif
-- SCRIPT: showcase (default), combo, heavy, moves, routes, walk, hit (KIT is the one hit), or a
-- route of L and R (e.g. LLRRLR: pressed from close, each key once the blow before has hit).
-- POSERATE: poses per second (15 by default, 60 = FLUIDE).
local Config = require("../src/shared/CombatConfig")
local ClipKit = require("./ClipKit")
local WeaponKit = require("./WeaponKit")

local args = { ... }
local kitName = args[1] or "KAI"
local scriptName = args[2] or "showcase"
local poseRate = tonumber(args[3]) or Config.PoseRate
local step = tonumber(args[4]) or 2
local zoom = tonumber(args[5]) or 1 -- 2 = twice as close as the game camera (to judge the poses)

-- The side camera of CameraController (16:9 screen), eased like in game.
local camCenter, camDistance
local function camera(a, b, dt)
	local fov = Config.CameraFOV
	local top = math.max(a.y, b.y) + 7
	local cx, cy = (a.x + b.x) / 2, top / 2 + 0.5
	local halfWidth = math.abs(a.x - b.x) / 2 + Config.CameraMargin
	local distanceX = halfWidth / (math.tan(math.rad(fov / 2)) * 16 / 9)
	local distanceY = (top / 2 + 4) / math.tan(math.rad(fov / 2))
	local required = math.max(Config.CameraMinDistance, distanceX, distanceY)
	local alpha = 1 - math.exp(-10 * dt)
	camCenter = if camCenter then { camCenter[1] + (cx - camCenter[1]) * alpha, camCenter[2] + (cy - camCenter[2]) * alpha }
		else { cx, cy }
	camDistance = if not camDistance or required > camDistance then required else camDistance + (required - camDistance) * alpha
	return camCenter[1], camCenter[2], camDistance, fov
end

local function fmt(n) return string.format("%.3f", n) end
ClipKit.play(kitName, scriptName, poseRate, function(info)
	local views, parts, tick = info.views, info.parts, info.tick
	local cx, cy, distance, fov = camera(views[1], views[2], 1 / 60)
	if tick % step ~= 0 then return end
	local a = views[info.attacker]
	local b = views[info.defender]
	local label = string.format("%s%s/%s", a.state, if a.move then "_" .. a.move .. ":" .. a.moveFrame else "", b.state)
	print(string.format("FRAME %d %s %s 0 0000000000 0 -", tick, label, fmt(fov)))
	-- (zoomed in, the camera aims at chest height instead of the middle of the frame)
	local y = cy + (3.2 + math.max(views[1].y, views[2].y) * 0.5 - cy) * (1 - 1 / zoom)
	print("CAM " .. table.concat({ fmt(cx), fmt(y), fmt(distance / zoom), fmt(cx), fmt(y), "0" }, " "))
	for slot = 1, 2 do
		for name, part in parts[slot] do
			local out = {}
			for i = 1, 12 do out[i] = fmt(part.cframe[i]) end
			print(string.format("PART %d %s %s %s %s %s", slot, name, table.concat(out, " "),
				fmt(part.size[1]), fmt(part.size[2]), fmt(part.size[3])))
		end
		for _, piece in WeaponKit.pieces(views[slot].kit, parts[slot], nil, { view = views[slot], time = tick / 60 }) do
			local out = {}
			for i = 1, 12 do out[i] = fmt(piece.cframe[i]) end
			print(string.format("PART %d %s %s %s %s %s %s", slot, piece.name, table.concat(out, " "),
				fmt(piece.size[1]), fmt(piece.size[2]), fmt(piece.size[3]), piece.color))
		end
	end
end)
