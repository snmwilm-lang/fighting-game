-- Motion quality of the cinematics (not a test), like tests/AnimQuality.luau for the fights:
--   clip   share of one body's sample points inside the other's torso, hips or head (mean, worst)
--   jumps  a body moving more than 1.2 studs in one tick inside a shot without being a ghost
--          (a blink drawn as one is fine; a visible teleport is not)
--   pops   a joint jumping more than 35 degrees in one tick inside a shot
--   luau tests/CinematicQuality.luau -a [KIT|all]
local MoveData = require("../src/shared/MoveData")
local Kit = require("./CinematicKit")

local args = { ... }
local kits = if not args[1] or args[1] == "all" then MoveData.KitOrder else { args[1] }
local CORE = { UpperTorso = true, LowerTorso = true, Head = true }
local JOINTS = { "Waist", "Neck", "LeftShoulder", "RightShoulder", "LeftElbow", "RightElbow", "LeftHip", "RightHip", "LeftKnee", "RightKnee" }

local function inside(part, x, y, z)
	local c, s = part.cframe, part.size
	local dx, dy, dz = x - c[1], y - c[2], z - c[3]
	local lx = c[4] * dx + c[7] * dy + c[10] * dz
	local ly = c[5] * dx + c[8] * dy + c[11] * dz
	local lz = c[6] * dx + c[9] * dy + c[12] * dz
	return math.abs(lx) <= s[1] / 2 and math.abs(ly) <= s[2] / 2 and math.abs(lz) <= s[3] / 2
end
local function clipShare(a, b)
	local total, hits = 0, 0
	for _, part in a do
		local c = part.cframe
		local p = { c[1], c[2], c[3] }
		total += 1
		for name, other in b do
			if CORE[name] and inside(other, p[1], p[2], p[3]) then hits += 1 break end
		end
	end
	return if total > 0 then hits / total else 0
end

print(string.format("%-10s %-7s %6s %6s %6s %6s  worst", "kit", "kind", "clip", "max", "jumps", "pops"))
for _, kit in kits do
	for _, kind in { "Rush", "Awaken", "Gate", "KO" } do
		local style = MoveData.Kits[kit].FullRoutes[1].name
		local clipSum, clipN, clipMax, jumps, pops, worst = 0, 0, 0, 0, 0, {}
		local last = {}
		local playKind, hp = kind, nil
		if kind == "KO" then playKind, hp = "Gate", 300 end
		Kit.play(kit, playKind, style, hp, 0, function(info)
			if kind == "KO" and not (info.frame.shot.name:find("^ko") or info.frame.title and info.frame.title.text == "K.O.") then
				-- only the K.O. scene
			end
			local shot = info.frame.shot.name
			for slot = 1, 2 do
				local v = info.views[slot]
				local prev = last[slot]
				if prev and prev.shot == shot then
					local d = math.sqrt((v.x - prev.x) ^ 2 + (v.y - prev.y) ^ 2 + ((v.z or 0) - (prev.z or 0)) ^ 2)
					if d > 1.2 and not v.ghost and not prev.ghost and v.y < 50 and prev.y < 50 then
						jumps += 1
						table.insert(worst, string.format("t%d s%d %s jump %.1f", info.tick, slot, shot, d))
					end
					for _, name in JOINTS do
						local a, b = info.poses and info.poses[slot] and info.poses[slot][name], prev.pose and prev.pose[name]
						if a and b and math.abs(a[1] - b[1]) > 35 then pops += 1 end
					end
				end
				last[slot] = { x = v.x, y = v.y, z = v.z, ghost = v.ghost, shot = shot, pose = info.poses and info.poses[slot] }
			end
			local share = math.max(clipShare(info.parts[1], info.parts[2]), clipShare(info.parts[2], info.parts[1]))
			clipSum += share
			clipN += 1
			if share > clipMax then
				clipMax = share
				table.insert(worst, 1, string.format("t%d %s clip %.0f%%", info.tick, shot, share * 100))
			end
		end)
		print(string.format("%-10s %-7s %5.1f%% %5.1f%% %6d %6d  %s", kit, kind, clipSum / math.max(1, clipN) * 100, clipMax * 100,
			jumps, pops, table.concat(worst, " | ", 1, math.min(#worst, 4))))
	end
end
