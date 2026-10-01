-- Storyboard of one cinematic, as the camera sees it (not a test). Writes frames for
-- tools/storyboard.py, which draws a contact sheet:
--   luau tests/Storyboard.luau -a KIT KIND [STYLE|-] [FINISH 0|1] [STEP] > story.txt
--   python3 tools/storyboard.py story.txt story.png
-- KIND: Rush, Awaken or Gate. Bodies are the KAI block rig posed by the real animator.
local Kit = require("./CinematicKit")
local args = { ... }
local kit, kind = args[1] or "KAI", args[2] or "Rush"
local style = if args[3] and args[3] ~= "-" then args[3] else nil
local hp = if args[4] == "1" then 300 else nil
local step = tonumber(args[5]) or 6

local function fmt(n) return string.format("%.3f", n) end
local seen = {}
Kit.play(kit, kind, style, hp, 0, function(info)
	local frame = info.frame
	for _, fx in frame.fx do
		if not seen[fx.key] then seen[fx.key] = { tick = info.tick, fx = fx } end
	end
	if info.tick % step ~= 0 then return end
	local s, g = frame.shot, frame.grade
	print(string.format("FRAME %d %s %s %s %d%d%d%d%d%d %d %s", info.tick, s.name, fmt(s.fov), fmt(s.roll),
		g.crimson and 1 or 0, g.void and 1 or 0, g.mono and 1 or 0, g.fire and 1 or 0, g.sky and 1 or 0, g.shadow and 1 or 0,
		if frame.speedLines then 1 else 0,
		if frame.title then frame.title.text else "-"))
	print("CAM " .. table.concat({ fmt(info.cam[1]), fmt(info.cam[2]), fmt(info.cam[3]),
		fmt(info.target[1]), fmt(info.target[2]), fmt(info.target[3]) }, " "))
	for slot = 1, 2 do
		for name, part in info.parts[slot] do
			local out = {}
			for i = 1, 12 do out[i] = fmt(part.cframe[i]) end
			print(string.format("PART %d %s %s %s %s %s", slot, name, table.concat(out, " "),
				fmt(part.size[1]), fmt(part.size[2]), fmt(part.size[3])))
		end
	end
	for _, entry in seen do
		local fx, age = entry.fx, info.tick - entry.tick
		if age <= 14 or fx.keep or fx.kind == "gate" then
			local function p(q)
				if type(q) == "number" then return fmt(q) .. " 0 0" end
				return if q then string.format("%s %s %s", fmt(q.x), fmt(q.y), fmt(q.z or 0)) else "0 0 0"
			end
			print(string.format("FX %s %d %s %s %s %s %s %s %s", fx.kind, age, p(fx.pos), p(fx.from), p(fx.to),
				fmt(fx.radius or 0), fx.color or "FFFFFF", fmt(fx.tilt or 0),
				fmt(if fx.kind == "arc" then (fx.dir or 1) else (fx.scale or 1))))
		end
	end
end)
