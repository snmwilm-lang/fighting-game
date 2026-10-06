-- DAICHA's orb against her own body (not a test): a scripted fight played by the real
-- simulation, her body posed by the real Animator (tests/ClipKit.luau), the orb where
-- OrbFlight puts it, at the size it has. For every frame: how far the sphere's surface is
-- from each part of her body (a box). Prints, per part group, the frames where it is INSIDE
-- her (< 0) and where it is stuck to her (< MARGIN), and the closest it came:
--   luau tests/OrbClearance.luau -a SCRIPT|all [avoid|raw] [why]
local MoveData = require("../src/shared/MoveData")
local OrbFlight = require("../src/shared/OrbFlight")
local Animator = require("../src/shared/Animator")
local K = require("../src/shared/Kinematics")
local ClipKit = require("./ClipKit")
local WeaponKit = require("./WeaponKit")

local args = { ... }

local OrbClearance = {}
OrbClearance.MARGIN = 0.25 -- (studs between the sphere's surface and her body: closer, it looks stuck to her)
OrbClearance.avoid = args[2] ~= "raw" -- (raw: without OrbFlight.avoid, as before 0.23.5)

local ROLE_OF = {}
for role, id in MoveData.Kits.DAICHA.Roles do ROLE_OF[id] = role end

-- Her posed parts as OrbFlight.avoid's boxes (centre, unit axes, half sizes).
OrbClearance.boxes = WeaponKit.boxes

local GROUP = {
	LeftHand = "hands", RightHand = "hands", LeftLowerArm = "arms", RightLowerArm = "arms",
	LeftUpperArm = "arms", RightUpperArm = "arms", Head = "head", UpperTorso = "torso", LowerTorso = "torso",
	LeftUpperLeg = "legs", RightUpperLeg = "legs", LeftLowerLeg = "legs", RightLowerLeg = "legs", LeftFoot = "legs", RightFoot = "legs",
}

-- Distance from a point to a box (its frame and size): negative inside.
function OrbClearance.boxDistance(frame, size, x, y, z)
	local lx, ly, lz = K.point(K.inverse(frame), x, y, z)
	local dx, dy, dz = math.abs(lx) - size[1] / 2, math.abs(ly) - size[2] / 2, math.abs(lz) - size[3] / 2
	local outside = math.sqrt(math.max(dx, 0) ^ 2 + math.max(dy, 0) ^ 2 + math.max(dz, 0) ^ 2)
	return outside + math.min(math.max(dx, dy, dz), 0)
end

-- Where the orb is for her view (world, as ClipKit places her body: `bodyX` her drawn x).
function OrbClearance.orb(view, bodyX, time, from)
	local id = view.state == "Attack" and view.move or nil
	local move = id and MoveData.Moves[id]
	local o = OrbFlight.offset(view, move, id and ROLE_OF[id], time, from)
	local form = OrbFlight.form(view, move, id and ROLE_OF[id], time)
	return { bodyX + view.facing * o.fwd, view.y + o.up, (view.z or 0) + o.side }, form, o
end

function OrbClearance.measure(script, onFrame)
	local out = { frames = 0, inside = {}, stuck = {}, closest = {}, onScreen = 0 }
	ClipKit.play("DAICHA", script, 60, function(info)
		local v, w = info.views[1], info.views[2]
		local push = Animator.spacing(v.x, v.y, w.x, w.y)
		local side = if w.x >= v.x then 1 else -1
		local at, form, o = OrbClearance.orb(v, v.x - side * push, info.tick / 60)
		if form.shape ~= "ball" or form.radius < 0.05 then return end
		if OrbClearance.avoid then
			at = OrbFlight.avoid(at, form.radius, OrbClearance.boxes(info.parts[1]), OrbFlight.SCREEN_CLEARANCE,
				OrbFlight.avoidDirection(v.state, v.facing, o), true)
		end
		out.frames += 1
		-- (as the camera sees her: the sphere over her silhouette)
		local seen = OrbFlight.screenClearance(at[1], at[2], OrbClearance.boxes(info.parts[1]), form.radius)
		if seen < 0 then out.onScreen += 1 end
		local worst = {}
		for name, part in info.parts[1] do
			local group = GROUP[name]
			if group then
				local d = OrbClearance.boxDistance(part.cframe, part.size, at[1], at[2], at[3]) - form.radius
				worst[group] = math.min(worst[group] or math.huge, d)
			end
		end
		for group, d in worst do
			out.closest[group] = math.min(out.closest[group] or math.huge, d)
			if d < 0 then out.inside[group] = (out.inside[group] or 0) + 1 end
			if d < OrbClearance.MARGIN then out.stuck[group] = (out.stuck[group] or 0) + 1 end
		end
		if onFrame then onFrame(info.tick, v, worst) end
	end)
	return out
end

if args[1] then
	local scripts = if args[1] == "all" then { "showcase", "moves", "combo", "heavy", "routes", "walk" } else { args[1] }
	local total = { frames = 0, inside = 0, stuck = 0 }
	for _, s in scripts do
		local q = OrbClearance.measure(s, if args[3] == "why" then function(tick, v, worst)
			for group, d in worst do
				if d < OrbClearance.MARGIN then
					print(string.format("  t%d %s %s f%s  %s %.2f", tick, v.state, tostring(v.move), tostring(v.moveFrame), group, d))
				end
			end
		end else nil)
		local line = string.format("%-9s %4d frames  over her on screen %3d", s, q.frames, q.onScreen)
		total.screen = (total.screen or 0) + q.onScreen
		for _, g in { "hands", "arms", "torso", "head", "legs" } do
			line ..= string.format("  %s in %d stuck %d (%.2f)", g, q.inside[g] or 0, q.stuck[g] or 0, q.closest[g] or 99)
			total.inside += q.inside[g] or 0
			total.stuck += q.stuck[g] or 0
		end
		total.frames += q.frames
		print(line)
	end
	print(string.format("TOTAL %d frames: inside her %d, stuck to her %d, over her on screen %d", total.frames, total.inside, total.stuck, total.screen))
end

return OrbClearance
