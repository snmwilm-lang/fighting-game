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
	for _, case in { { "Rush" }, { "Awaken", route }, { "Gate" }, { "Gate", nil, 300 }, { "Awaken", route, 300 } } do
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

T.finish()
