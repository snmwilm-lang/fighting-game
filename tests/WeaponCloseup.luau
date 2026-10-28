-- Close-up of a held weapon on its own (not a test): its pieces as WeaponKit places them,
-- laid along -X, seen from a few angles. Writes frames for tools/storyboard.py:
--   luau tests/WeaponCloseup.luau -a KIT > weapon.txt
--   STORY_W=600 python3 tools/storyboard.py weapon.txt weapon.png
local K = require("../src/shared/Kinematics")
local WeaponSpec = require("../src/shared/WeaponSpec")

local args = { ... }
local kit = args[1] or "SHIN"
local spec = WeaponSpec[kit]
assert(spec, "no weapon for " .. kit)

local function fmt(v) return string.format("%.4f", v) end
-- the grip: the blade along -X (its -Z), its back (+Y) up, a little above the floor
local grip = K.mul(K.translation(0, 3, 0), K.angles(0, math.rad(90), 0))
local mid = (spec.base + spec.tip) / 2
local views = { { "side", 0, 0.3 }, { "three-quarter", 35, 0.8 }, { "hilt", 70, 0.5 }, { "back", 180, 0.4 } }
for tick, v in views do
	local yaw = math.rad(v[2])
	local d = math.max(2.6, math.abs(spec.tip - spec.base) * 1.15 + 1)
	local cx, cz = mid + math.sin(yaw) * d, math.cos(yaw) * d
	print(string.format("FRAME %d %s 36 0 000000 0 -", tick, v[1]))
	print(string.format("CAM %s %s %s %s 3 0", fmt(cx), fmt(3 + v[3]), fmt(cz), fmt(mid)))
	for _, p in spec.pieces do
		local r = p.rot or { 0, 0, 0 }
		local f = K.mul(K.mul(grip, K.translation(p.x or 0, p.y or 0, p.z or 0)), K.angles(math.rad(r[1]), math.rad(r[2]), math.rad(r[3])))
		local out = {}
		for i = 1, 12 do out[i] = fmt(f[i]) end
		local color = if p.color == "energy" then "8FD8FF" elseif p.color == "trim" then "C9A227" else p.color
		print(string.format("PART 1 Weapon%s %s %s %s %s %s", p.name, table.concat(out, " "), fmt(p.size[1]), fmt(p.size[2]), fmt(p.size[3]), color))
	end
end
