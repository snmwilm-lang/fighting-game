-- Storyboard of one cinematic, as the camera sees it (not a test). Writes frames for
-- tools/storyboard.py, which draws a contact sheet:
--   luau tests/Storyboard.luau -a KIT KIND [STYLE|-] [FINISH 0|1] [STEP] > story.txt
--   python3 tools/storyboard.py story.txt story.png
-- KIND: Rush, Awaken or Gate, or KO (the winner's K.O. scene at the end of a match; then the
-- third argument is the scene's number in the session: a kit with two victories alternates),
-- or Intro (the match's mini intro; the third argument is the opponent's kit).
-- Bodies are the KAI block rig posed by the real animator.
local Kit = require("./CinematicKit")
local WeaponKit = require("./WeaponKit")
local args = { ... }
local kit, kind = args[1] or "KAI", args[2] or "Rush"
local style = if args[3] and args[3] ~= "-" then args[3] else nil
local hp = if args[4] == "1" then 300 else nil
local step = tonumber(args[5]) or 6

local function fmt(n) return string.format("%.3f", n) end
local seen = {}
local play = if kind == "KO" then function(_, _, _, _, _, onFrame) Kit.playKO(kit, tonumber(args[3]) or 1, onFrame) end
	elseif kind == "Intro" then function(_, _, _, _, _, onFrame) Kit.playIntro(kit, args[3], onFrame) end
	else Kit.play
play(kit, kind, style, hp, 0, function(info)
	local frame = info.frame
	for _, fx in frame.fx do
		if not seen[fx.key] then
			seen[fx.key] = { tick = info.tick, fx = fx }
			if fx.kind == "afterimage" then
				-- AKEMI's shadow: a copy of the body as it is now.
				local copy = {}
				for name, part in info.parts[fx.slot] do copy[name] = { cframe = table.clone(part.cframe), size = part.size } end
				seen[fx.key].parts = copy
			end
		end
	end
	if info.tick % step ~= 0 then return end
	local s, g = frame.shot, frame.grade
	print(string.format("FRAME %d %s %s %s %d%d%d%d%d%d%d%d%d%d %d %s", info.tick, s.name, fmt(s.fov), fmt(s.roll),
		g.crimson and 1 or 0, g.void and 1 or 0, g.mono and 1 or 0, g.fire and 1 or 0, g.sky and 1 or 0, g.shadow and 1 or 0,
		g.rage and 1 or 0, g.current and 1 or 0, g.inverse and 1 or 0, g.ruin and 1 or 0,
		if frame.speedLines then 1 else 0,
		if frame.title then frame.title.text else "-"))
	print("CAM " .. table.concat({ fmt(info.cam[1]), fmt(info.cam[2]), fmt(info.cam[3]),
		fmt(info.target[1]), fmt(info.target[2]), fmt(info.target[3]) }, " "))
	-- (a FATAL FINISHER's direction: a fighter not drawn, the eyes of the other as the camera)
	local over = frame.overlay or {}
	for slot = 1, 2 do
		if info.views[slot].hidden then continue end
		for name, part in info.parts[slot] do
			if over.firstPerson == slot and (name == "Head" or name:find("Arm") or name:find("Hand")) then continue end
			local out = {}
			for i = 1, 12 do out[i] = fmt(part.cframe[i]) end
			print(string.format("PART %d %s %s %s %s %s", slot, name, table.concat(out, " "),
				fmt(part.size[1]), fmt(part.size[2]), fmt(part.size[3])))
		end
		-- The fighter's weapon in its hand (SHIN's katana, DAICHA's orb).
		for _, piece in WeaponKit.pieces(info.views[slot].kit, info.parts[slot], nil, { view = info.views[slot], time = info.tick / 60 }) do
			local out = {}
			for i = 1, 12 do out[i] = fmt(piece.cframe[i]) end
			print(string.format("PART %d %s %s %s %s %s %s", slot, piece.name, table.concat(out, " "),
				fmt(piece.size[1]), fmt(piece.size[2]), fmt(piece.size[3]), piece.color))
		end
	end
	-- The finishers' light (frame.shapes) and their overlay (the split, the K.O., the blur...)
	local function at(point)
		if not point then return "0 0 0" end
		if point.x then return string.format("%s %s %s", fmt(point.x), fmt(point.y), fmt(point.z or 0)) end
		local x, y, z = Kit.resolve(point, info.parts)
		return string.format("%s %s %s", fmt(x), fmt(y), fmt(z))
	end
	for _, sh in frame.shapes or {} do
		print(string.format("SHAPE %s %s %s %s %s %s %s %s %s", sh.kind, at(sh.pos or sh.from), at(sh.to or sh.normal),
			fmt(sh.radius or 0), fmt(sh.width or 0), sh.color or "FFFFFF", fmt(sh.alpha or 0),
			fmt(sh.core or sh.rings or sh.phase or 0), fmt(sh.count or 0)))
	end
	if frame.overlay then
		local split = over.split or {}
		local k = over.ko or {}
		print(string.format("OVERLAY %s %s %d %s %s %s %s %s %d %s", fmt(over.desat or 0), fmt(over.blur or 0), over.firstPerson or 0,
			fmt(split.line or -1), fmt(split.open or 0), fmt(split.join or 0), fmt(split.angle or 0), split.color or "FFFFFF",
			k.age or -1, (k.sub or "-"):gsub(" ", "_")))
		if over.caption then
			print(string.format("CAPTION %s %d %s %s", (over.caption.text:gsub(" ", "_")), over.caption.age or 99, over.caption.color or "FFFFFF",
				fmt(over.caption.fade or 0)))
		end
	end
	-- DAICHA's matter this frame (a ball, a disc, a puddle, a wave)
	for _, m in frame.matter or {} do
		local n = m.normal or { x = 0, y = 1, z = 0 }
		print(string.format("MATTER %s %s %s %s %s %s %s %s %s %s", m.shape, fmt(m.pos.x), fmt(m.pos.y), fmt(m.pos.z or 0), fmt(m.radius),
			fmt(m.height or 0), fmt(n.x), fmt(n.y), fmt(n.z or 0), m.color or "FFFFFF"))
	end
	for _, entry in seen do
		local fx, age = entry.fx, info.tick - entry.tick
		local shown = if fx.life then age <= fx.life * 60 else age <= 14 or fx.keep or fx.kind == "gate"
		if shown and entry.parts then
			for name, part in entry.parts do
				local out = {}
				for i = 1, 12 do out[i] = fmt(part.cframe[i]) end
				print(string.format("PART 1 %s %s %s %s %s 2A1838", name, table.concat(out, " "),
					fmt(part.size[1]), fmt(part.size[2]), fmt(part.size[3])))
			end
		elseif shown then
			local function p(q)
				if type(q) == "number" then return fmt(q) .. " 0 0" end
				return if q then string.format("%s %s %s", fmt(q.x), fmt(q.y), fmt(q.z or 0)) else "0 0 0"
			end
			-- (then the life in seconds, the spin in turns per second and the starting turn)
			print(string.format("FX %s %d %s %s %s %s %s %s %s %s %s %s", fx.kind, age, p(fx.pos), p(fx.from), p(fx.to),
				fmt(fx.radius or 0), fx.color or "FFFFFF", fmt(fx.tilt or 0),
				fmt(if fx.kind == "arc" then (fx.dir or 1) else (fx.count or fx.scale or 1)),
				fmt(fx.life or 0), fmt(fx.spin or 0), fmt(fx.phase or 0)))
		end
	end
end)
