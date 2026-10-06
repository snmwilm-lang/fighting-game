-- Motion quality report (not a test): plays scripted fights (tests/ClipKit.luau) and measures
-- what makes an animation look messy:
--   pops     a joint jumping more than POP degrees in one tick when the key is not a snap
--            (impacts and hits are meant to cut), counted at FLUIDE so the steps don't count
--   jitter   a joint going back and forth within three ticks (vibration)
--   clip     how deep the bodies sink into each other: share of one body's sample points
--            inside the other's torso, hips or head (mean over close-range ticks, and worst)
--   luau tests/AnimQuality.luau -a [KIT|all] [SCRIPT]
local MoveData = require("../src/shared/MoveData")
local ClipKit = require("./ClipKit")

local args = { ... }
local kits = if not args[1] or args[1] == "all" then MoveData.KitOrder else { args[1] }
local scripts = if args[2] then { args[2] } else { "showcase", "routes", "moves", "hit" }

local POP = 28
local JOINTS = { "Waist", "Neck", "LeftShoulder", "RightShoulder", "LeftElbow", "RightElbow", "LeftHip", "RightHip",
	"LeftKnee", "RightKnee" }
local CORE = { UpperTorso = true, LowerTorso = true, Head = true }

-- Is the point inside the box (cframe = position + rotation rows, size)?
local function inside(part, x, y, z, shrink)
	local c, s = part.cframe, part.size
	local dx, dy, dz = x - c[1], y - c[2], z - c[3]
	-- local coordinates: R^T * d (columns of the rotation are the part axes)
	local lx = c[4] * dx + c[7] * dy + c[10] * dz
	local ly = c[5] * dx + c[8] * dy + c[11] * dz
	local lz = c[6] * dx + c[9] * dy + c[12] * dz
	return math.abs(lx) <= s[1] / 2 * shrink and math.abs(ly) <= s[2] / 2 * shrink and math.abs(lz) <= s[3] / 2 * shrink
end

-- Sample points of a part: its centre and 8 corners pulled in to 60 %.
local function samples(part)
	local c, s = part.cframe, part.size
	local out = { { c[1], c[2], c[3] } }
	for _, sx in { -0.3, 0.3 } do
		for _, sy in { -0.3, 0.3 } do
			for _, sz in { -0.3, 0.3 } do
				local lx, ly, lz = sx * s[1], sy * s[2], sz * s[3]
				table.insert(out, { c[1] + c[4] * lx + c[5] * ly + c[6] * lz, c[2] + c[7] * lx + c[8] * ly + c[9] * lz,
					c[3] + c[10] * lx + c[11] * ly + c[12] * lz })
			end
		end
	end
	return out
end

local function clipShare(a, b)
	local total, hits = 0, 0
	for _, part in a do
		for _, p in samples(part) do
			total += 1
			for name, other in b do
				if CORE[name] and inside(other, p[1], p[2], p[3], 1) then
					hits += 1
					break
				end
			end
		end
	end
	return if total > 0 then hits / total else 0
end

print(string.format("%-10s %-9s %6s %6s %8s %8s  worst pops", "kit", "script", "pops", "jitter", "clip", "clipMax"))
for _, kit in kits do
	for _, scriptName in scripts do
		local last, before = { {}, {} }, { {}, {} }
		local pops, jitter, clipSum, clipN, clipMax, clipAt = 0, 0, 0, 0, 0, ""
		local worst = {}
		ClipKit.play(kit, scriptName, 60, function(info)
			for slot = 1, 2 do
				local pose = info.poses[slot]
				for _, name in JOINTS do
					local v = pose[name]
					if v then
						for axis = 1, 3 do
							local key = name .. axis
							local now, prev, prev2 = v[axis] or 0, last[slot][key], before[slot][key]
							if prev then
								local d = now - prev
								if math.abs(d) > POP and not info.snaps[slot] then
									pops += 1
									table.insert(worst, { d = math.abs(d), text = string.format("t%d s%d %s %+.0f %s", info.tick, slot, key, d,
										tostring(info.keys[slot])) })
								end
								if prev2 then
									local d1 = prev - prev2
									if d * d1 < 0 and math.abs(d) > 4 and math.abs(d1) > 4 and not info.snaps[slot] then jitter += 1 end
								end
							end
							before[slot][key], last[slot][key] = prev, now
						end
					end
				end
			end
			local a, b = info.views[1], info.views[2]
			if math.abs(a.x - b.x) < 4.5 and math.abs(a.y - b.y) < 3 then
				local share = math.max(clipShare(info.parts[1], info.parts[2]), clipShare(info.parts[2], info.parts[1]))
				clipSum += share
				clipN += 1
				if share > clipMax then
					clipMax = share
					clipAt = string.format("t%d %s/%s", info.tick, tostring(info.keys[1]), tostring(info.keys[2]))
				end
			end
		end)
		table.sort(worst, function(x, y) return x.d > y.d end)
		local list = {}
		for i = 1, math.min(tonumber(args[3]) or 3, #worst) do list[i] = worst[i].text end
		print(string.format("%-10s %-9s %6d %6d %7.1f%% %7.1f%%  %s  [clip %s]", kit, scriptName, pops, jitter,
			if clipN > 0 then clipSum / clipN * 100 else 0, clipMax * 100, table.concat(list, " | "), clipAt))
	end
end
