-- Framing checks of every cinematic with the real rig: the director stages each tick, the
-- animator poses both KAI block bodies (forward kinematics, limbs included) and every shot
-- must keep the camera out of the bodies, its subject on screen and readable.
-- Run from the repository root: luau tests/Cinematography.test.luau
local Config = require("../src/shared/CombatConfig")
local MoveData = require("../src/shared/MoveData")
local Kit = require("./CinematicKit")
local T = require("./TestKit")
local test, expect = T.test, T.expect

-- KAI's K.O. scene (Wilhem's storyboard) has deliberate macro shots (hand, feet, face); the
-- other kits' K.O. scenes are composed shots, checked like any other.
local MACRO = { ["ko-fall"] = true, ["ko-hand"] = true, ["ko-scene1"] = true, ["ko-feet"] = true, ["ko-face"] = true,
	["ko-scene2"] = true, ["ko-back"] = true, ["ko-wide"] = true }
local function macro(name)
	return MACRO[name] == true
end

local function check(kit, kind, style, hp, center)
	local failures = {}
	local function fail(info, text)
		if #failures < 6 then
			table.insert(failures, string.format("t%d %s: %s", info.tick, info.frame.shot.name, text))
		end
	end
	Kit.play(kit, kind, style, hp, center, function(info)
		local s = info.frame.shot
		local cam = info.cam
		local near = math.huge
		for _, parts in info.parts do
			for _, part in parts do near = math.min(near, Kit.boxDistance(part, cam[1], cam[2], cam[3])) end
		end
		if near < (if macro(s.name) then 0.35 else 1.5) then fail(info, string.format("camera %.2f stud from a body", near)) end
		if cam[2] < 0.3 then fail(info, string.format("camera under the floor (%.2f)", cam[2])) end
		local project = Kit.projector(cam, info.target, s.fov, s.roll)
		local fx, fy = project(info.focus[1], info.focus[2], info.focus[3])
		if not fx or math.abs(fx) > 1 or math.abs(fy) > 0.78 then fail(info, "the focus point is off screen") end
		if not macro(s.name) then
			local slot = s.focus.slot or info.cin.defender
			local minX, maxX, minY, maxY = Kit.bodyBounds(project, info.parts[slot])
			if not minX then
				fail(info, "the subject is behind the camera")
			else
				local h = (maxY - minY) / 2
				if h > 2.2 then fail(info, string.format("the subject is %.1f times the frame height", h)) end
				if maxX < -1 or minX > 1 or maxY < -0.78 or minY > 0.78 then fail(info, "the subject is out of the frame") end
			end
		end
	end)
	return failures
end

for _, kit in MoveData.KitOrder do
	local route = MoveData.Kits[kit].FullRoutes[1].name
	for _, case in { { "Rush" }, { "Awaken", route }, { "Gate" }, { "Gate", nil, 300 }, { "Awaken", route, 300 }, { "Fatal" },
		{ "Fatal", nil, 300 } } do
		for _, center in { 0, Config.ArenaMaxX - 3 } do
			local name = string.format("%s %s%s at x=%d", kit, case[1], if case[3] then " (K.O.)" else "", center)
			test(name .. ": camera clear of the bodies, subject on screen", function()
				local failures = check(kit, case[1], case[2], case[3], center)
				expect(#failures == 0, name .. "\n         " .. table.concat(failures, "\n         "))
			end)
		end
	end
end

test("every finale of KAI's ÉVEIL is well framed", function()
	for _, r in MoveData.Kits.KAI.FullRoutes do
		local failures = check("KAI", "Awaken", r.name, nil, 0)
		expect(#failures == 0, r.name .. "\n         " .. table.concat(failures, "\n         "))
	end
end)

-- Both hands read: a shot never looks along the arms so that one fist hides the other (two
-- hands far apart drawn on top of each other read as hands joined). SHIN's iai is the one
-- pose where both hands meet at the hilt on purpose.
local function overlappedHands(kit, kind, style, hp)
	local shots = {}
	Kit.play(kit, kind, style, hp, 0, function(info)
		local s = info.frame.shot
		local project = Kit.projector(info.cam, info.target, s.fov, s.roll or 0)
		for slot = 1, 2 do
			local l, r = info.parts[slot].LeftHand, info.parts[slot].RightHand
			local lx, ly, ld = project(l.cframe[1], l.cframe[2], l.cframe[3])
			local rx, ry, rd = project(r.cframe[1], r.cframe[2], r.cframe[3])
			if lx and rx and math.abs(lx) < 1 and math.abs(ly) < 1 and info.views[slot].pose ~= "Iai" then
				local apart = math.sqrt((l.cframe[1] - r.cframe[1]) ^ 2 + (l.cframe[2] - r.cframe[2]) ^ 2 + (l.cframe[3] - r.cframe[3]) ^ 2)
				local hand = l.size[2] / ((ld + rd) / 2) / math.tan(math.rad(s.fov) / 2)
				local onScreen = math.sqrt(((lx - rx) * 16 / 9) ^ 2 + (ly - ry) ^ 2)
				if hand > 0.03 and apart > 2 and onScreen < hand * 1.3 then
					local key = s.name .. " (slot " .. slot .. ")"
					shots[key] = (shots[key] or 0) + 1
				end
			end
		end
	end)
	local bad = {}
	for key, n in shots do
		if n > 6 then table.insert(bad, key .. " x" .. n) end
	end
	return bad
end

test("both hands read in every shot: no angle hides one fist behind the other", function()
	for _, kit in MoveData.KitOrder do
		local route = MoveData.Kits[kit].FullRoutes[1].name
		for _, case in { { "Rush" }, { "Awaken", route }, { "Gate" }, { "Gate", nil, 1 }, { "Awaken", route, 1 }, { "Fatal" }, { "Fatal", nil, 1 } } do
			local bad = overlappedHands(kit, case[1], case[2], case[3])
			expect(#bad == 0, string.format("%s %s%s: %s", kit, case[1], if case[3] then " (K.O.)" else "", table.concat(bad, ", ")))
		end
	end
end)

T.finish()
