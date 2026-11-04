-- The held weapons against their own fighter's body (not a test): SHIN's katana, RAIJIN's
-- spear, YUKINA's fans, KAZAN's claws. A scripted fight played by the real simulation, the
-- body posed by the real Animator (tests/ClipKit.luau), the weapon placed in the hand like
-- the RigBuilder does (tests/WeaponKit.luau). For every frame: does the weapon go through the
-- body (its head, torso, hips, legs, or the other arm)? The hand that holds it and its forearm
-- do not count (the grip is in them).
--   luau tests/WeaponClearance.luau -a KIT|all [SCRIPT] [why]
local MoveData = require("../src/shared/MoveData")
local K = require("../src/shared/Kinematics")
local WeaponSpec = require("../src/shared/WeaponSpec")
local ClipKit = require("./ClipKit")
local WeaponKit = require("./WeaponKit")

local args = { ... }
local WeaponClearance = {}
WeaponClearance.KITS = { "SHIN", "RAIJIN", "YUKINA", "KAZAN" }
WeaponClearance.DEPTH = 0.08 -- (studs inside a part before it counts: the surfaces touching do not)

local HOLD = {
	RightHand = { RightHand = true, RightLowerArm = true },
	LeftHand = { LeftHand = true, LeftLowerArm = true },
}
-- (RAIJIN holds his spear with both hands, the rear one on the shaft: PoseLibrary BOTH_HANDS)
local SECOND_GRIP = { RAIJIN = { LeftHand = true, LeftLowerArm = true } }

-- How deep a point is inside a box (> 0 inside), from its frame and size.
local function depth(frame, size, x, y, z)
	local lx, ly, lz = K.point(K.inverse(frame), x, y, z)
	return math.min(size[1] / 2 - math.abs(lx), size[2] / 2 - math.abs(ly), size[3] / 2 - math.abs(lz))
end

-- Points along a weapon piece: its long axis, 9 points, and its corners at the ends.
local function samples(piece)
	local c, s = piece.cframe, piece.size
	local out = {}
	local long = if s[3] >= s[1] and s[3] >= s[2] then 3 elseif s[2] >= s[1] then 2 else 1
	for i = 0, 8 do
		local u = (i / 8 - 0.5)
		local l = { 0, 0, 0 }
		l[long] = u * s[long] * 0.95
		table.insert(out, { K.point(c, l[1], l[2], l[3]) })
	end
	return out
end

function WeaponClearance.measure(kit, script, onFrame)
	local spec = WeaponSpec[kit]
	local out = { frames = 0, through = 0, deepest = 0, parts = {} }
	ClipKit.play(kit, script, 60, function(info)
		local parts = info.parts[1]
		local pieces = WeaponKit.pieces(kit, parts, nil, nil)
		out.frames += 1
		local worst, where = 0, nil
		for _, piece in pieces do
			local hand = if piece.name:sub(-1) == "2" and spec.pair then spec.pair.hand else spec.hand
			for _, p in samples(piece) do
				for name, part in parts do
					if not (HOLD[hand] and HOLD[hand][name]) and not (SECOND_GRIP[kit] and SECOND_GRIP[kit][name]) then
						local d = depth(part.cframe, part.size, p[1], p[2], p[3])
						if d > worst then worst, where = d, name end
					end
				end
			end
		end
		if worst > WeaponClearance.DEPTH then
			out.through += 1
			out.parts[where] = (out.parts[where] or 0) + 1
		end
		out.deepest = math.max(out.deepest, worst)
		if onFrame then onFrame(info, worst, where) end
	end)
	return out
end

if args[1] then
	local kits = if args[1] == "all" then WeaponClearance.KITS else { args[1] }
	local scripts = if args[2] and args[2] ~= "all" then { args[2] } else { "showcase", "routes", "moves", "walk" }
	local total, frames = 0, 0
	for _, kit in kits do
		for _, s in scripts do
			local q = WeaponClearance.measure(kit, s, if args[3] == "why" then function(info, d, where)
				if d > WeaponClearance.DEPTH then
					print(string.format("  %s t%d %s  %s %.2f", kit, info.tick, tostring(info.keys[1]), tostring(where), d))
				end
			end else nil)
			local list = {}
			for name, n in q.parts do table.insert(list, name .. " " .. n) end
			table.sort(list)
			print(string.format("%-7s %-9s %4d frames  through her/his body %3d (deepest %.2f)  %s", kit, s, q.frames, q.through, q.deepest,
				table.concat(list, ", ")))
			total += q.through
			frames += q.frames
		end
	end
	print(string.format("TOTAL %d frames, through the body %d", frames, total))
end

return WeaponClearance
