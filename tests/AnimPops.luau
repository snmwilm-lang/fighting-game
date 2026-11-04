-- The big jumps of the animation (not a test): every kit's scripted fights (tests/ClipKit.luau),
-- each tick a joint turns more than POP degrees (and the key is not a snap: impacts and hits
-- are meant to cut), grouped by the transition it happens in (Idle -> Move start, landing...):
-- what to smooth in the Animator for every kit at once.
--   luau tests/AnimPops.luau -a [POP] [list]
local MoveData = require("../src/shared/MoveData")
local ClipKit = require("./ClipKit")
local args = { ... }
local POP = tonumber(args[1]) or 28
local JOINTS = { "Waist", "Neck", "LeftShoulder", "RightShoulder", "LeftElbow", "RightElbow", "LeftHip", "RightHip", "LeftKnee", "RightKnee" }
local byTrans, total = {}, 0
local function phase(key)
	if not key then return "?" end
	local fam, rest = key:match("^([^:]+):?(.*)$")
	local p = rest and rest:match("^%a") or ""
	if MoveData.Moves[fam] then fam = "Move" end
	return fam .. ":" .. p
end
for _, kit in MoveData.KitOrder do
	for _, sc in { "showcase", "routes", "moves" } do
		local last, lastKey = nil, nil
		ClipKit.play(kit, sc, 60, function(info)
			local pose, key = info.poses[1], info.keys[1]
			if last then
				local worst = 0
				for _, j in JOINTS do
					local a, b = pose[j], last[j]
					if a and b then for i = 1, 3 do worst = math.max(worst, math.abs((a[i] or 0) - (b[i] or 0))) end end
				end
				local wj
				for _, j in JOINTS do
					local a, b = pose[j], last[j]
					if a and b then for i = 1, 3 do if math.abs((a[i] or 0) - (b[i] or 0)) == worst then wj = j .. i end end end
				end
				if worst > POP and not info.snaps[1] then
					if args[2] == "list" then print(string.format("%-9s %-8s t%d %s -> %s  %s %.0f", kit, sc, info.tick, tostring(lastKey), tostring(key), wj, worst)) end
					local t = phase(lastKey) .. " -> " .. phase(key)
					byTrans[t] = (byTrans[t] or 0) + 1
					total += 1
				end
			end
			last, lastKey = table.clone(pose), key
			for k, v in pose do last[k] = table.clone(v) end
		end)
	end
end
local list = {}
for t, n in byTrans do table.insert(list, { t, n }) end
table.sort(list, function(a, b) return a[2] > b[2] end)
print("total pops (kit side)", total)
for i = 1, math.min(25, #list) do print(string.format("%4d  %s", list[i][2], list[i][1])) end
