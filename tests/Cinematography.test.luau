-- Framing checks of every cinematic with the real rig: the director stages each tick, the
-- animator poses both KAI block bodies (forward kinematics, limbs included) and every shot
-- must keep the camera out of the bodies, its subject on screen and readable.
-- Run from the repository root: luau tests/Cinematography.test.luau
local Config = require("../src/shared/CombatConfig")
local MoveData = require("../src/shared/MoveData")
local Kit = require("./CinematicKit")
local T = require("./TestKit")
local test, expect = T.test, T.expect
local KITS = table.clone(MoveData.KitOrder) -- (and the bosses)
for name, data in MoveData.Kits do
	if data.Boss then table.insert(KITS, name) end
end

-- KAI's K.O. scene (Wilhem's storyboard) has deliberate macro shots (hand, feet, face); the
-- other kits' K.O. scenes are composed shots, checked like any other.
local MACRO = { ["ko-fall"] = true, ["ko-hand"] = true, ["ko-scene1"] = true, ["ko-feet"] = true, ["ko-face"] = true,
	["ko-scene2"] = true, ["ko-back"] = true, ["ko-wide"] = true }
local function macro(name)
	return MACRO[name] == true
end

-- (mirror: the attacker strikes from the right; wall: its back to the wall of its side,
-- CinematicKit.play)
local function check(kit, kind, style, hp, center, mirror, wall)
	local failures = {}
	local function fail(info, text)
		if #failures < 6 then
			table.insert(failures, string.format("t%d %s: %s", info.tick, info.frame.shot.name, text))
		end
	end
	Kit.play(kit, kind, style, hp, center, function(info)
		local s = info.frame.shot
		local cam = info.cam
		-- (a FATAL FINISHER's close-ups hang on a part, and its first person is the target's
		-- eyes, its head and arms not drawn: macro shots too; its wide shots are checked in full)
		local over = info.frame.overlay or {}
		local close = macro(s.name) or s.close == true or over.firstPerson ~= nil
		local near = math.huge
		for slot, parts in info.parts do
			if info.views[slot].hidden then continue end
			for name, part in parts do
				local unseen = over.firstPerson == slot and (name == "Head" or name:find("Arm") or name:find("Hand"))
				if not unseen then near = math.min(near, Kit.boxDistance(part, cam[1], cam[2], cam[3])) end
			end
		end
		-- (in first person the attacker's hook sweeps across the lens, as the scene wants: 0.25,
		-- still well beyond the camera's near plane, 0.1)
		local limit = if over.firstPerson then 0.25 elseif close then 0.35 else 1.5
		if near < limit then fail(info, string.format("camera %.2f stud from a body", near)) end
		if cam[2] < 0.3 then fail(info, string.format("camera under the floor (%.2f)", cam[2])) end
		local project = Kit.projector(cam, info.target, s.fov, s.roll)
		local fx, fy = project(info.focus[1], info.focus[2], info.focus[3])
		if not fx or math.abs(fx) > 1 or math.abs(fy) > 0.78 then fail(info, "the focus point is off screen") end
		if not close then
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
	end, mirror, wall)
	return failures
end

-- The match's mini intro (Wilhem: « des mini scènes d'intro, toutes petites »): each fighter
-- in his own entrance pose, framed in full, the camera out of the bodies, short enough to
-- leave "ROUND" and "FIGHT" to the usual camera.
test("the match's mini intro: every fighter on screen in his own pose, short, only at a match's very start", function()
	local Director = require("../src/shared/CinematicDirector")
	local Sim = require("../src/shared/CombatSimulation")
	expect(Director.INTRO_SCENE <= Config.IntroTicks - 20, "the intro scene leaves no time to the ROUND / FIGHT call")
	for _, kit in KITS do
		local pose = Director.INTRO_POSE[kit]
		expect(pose ~= nil, kit .. " has no entrance pose")
		local failures, seen, shadow = {}, { 0, 0 }, {}
		Kit.playIntro(kit, "KAI", function(info)
			local s = info.frame.shot
			local slot = if info.tick < Director.INTRO_SCENE / 2 then 1 else 2
			seen[slot] += 1
			local v = info.views[slot]
			if Director.INTRO_ACTION[v.kit] then
				-- (TARO shadowboxes: his own blows in his shot)
				if v.state == "Attack" then shadow[v.move] = true end
			elseif v.pose ~= Director.INTRO_POSE[v.kit] then
				table.insert(failures, "t" .. info.tick .. " not in its entrance pose")
			end
			local cam = info.cam
			local near = math.huge
			for _, parts in info.parts do
				for _, part in parts do near = math.min(near, Kit.boxDistance(part, cam[1], cam[2], cam[3])) end
			end
			if near < 1.5 then table.insert(failures, string.format("t%d camera %.2f stud from a body", info.tick, near)) end
			local project = Kit.projector(cam, info.target, s.fov, s.roll)
			local minX, maxX, minY, maxY = Kit.bodyBounds(project, info.parts[slot])
			if not minX or minX < -1 or maxX > 1 or minY < -1 or maxY > 1 then
				table.insert(failures, "t" .. info.tick .. " the fighter is not whole in the frame")
			end
		end)
		expect(seen[1] > 20 and seen[2] > 20, kit .. ": both fighters are not shown in turn")
		if Director.INTRO_ACTION[kit] then
			local blows = 0
			for _ in shadow do blows += 1 end
			expect(blows >= 2, kit .. " does not shadowbox in his intro")
		end
		expect(#failures == 0, kit .. "\n         " .. table.concat(failures, "\n         ", 1, math.min(#failures, 5)))
	end
	-- only at a match's start (round 1): not at round 2, nor at a relay's next fighter; never in training
	local world = Sim.newWorld(Config, MoveData, false)
	Sim.setKits(world, "KAI", "TARO")
	expect(Director.introScene(world, Config) == 0, "no intro at the match's start")
	world.round = 2
	expect(Director.introScene(world, Config) == nil, "an intro at round 2 of a duel")
	local relay = Sim.newWorld(Config, MoveData, false)
	Sim.setLineup(relay, { "KAI", "TARO" }, { "SHIN", "VENOM" })
	expect(Director.introScene(relay, Config) == 0, "no intro at a relay's start")
	relay.round = 2
	expect(Director.introScene(relay, Config) == nil, "an intro again for a relay's next fighter")
	world.round, world.training = 1, true
	expect(Director.introScene(world, Config) == nil, "an intro in training")
end)

for _, kit in KITS do
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

-- (the lab always puts the attacker on the left: NOVA's FATAL ERROR, staged from her measured
-- gauntlet on each side, is checked striking from the right too)
for _, center in { 0, Config.ArenaMinX + 3 } do
	local name = string.format("NOVA Fatal (K.O.) from the right at x=%d", center)
	test(name .. ": camera clear of the bodies, subject on screen", function()
		local failures = check("NOVA", "Fatal", nil, 300, center, true)
		expect(#failures == 0, name .. "\n         " .. table.concat(failures, "\n         "))
	end)
end

-- Every FATAL FINISHER with the attacker's back to the wall, on both sides: the lab never
-- stages it (debugCinematic keeps the fight 4 studs from the walls, the attacker on the left),
-- the game does whenever the killing COUP FATAL starts there. A scene staged far from the
-- target must stand back from the wall as a whole (B-011: SHIN's iai pinned at the wall put
-- the camera of his eye in the target's arm); from the right, every finisher is also played
-- mirrored (B-010: TARO's hook by the lens of the target's eyes).
for _, kit in KITS do
	if not MoveData.Kits[kit].Finisher then continue end
	for _, mirror in { false, true } do
		local name = string.format("%s FATAL FINISHER, its back to the %s wall", kit, if mirror then "right" else "left")
		test(name .. ": camera clear of the bodies, subject on screen", function()
			local failures = check(kit, "Fatal", nil, 300, 0, mirror, true)
			expect(#failures == 0, name .. "\n         " .. table.concat(failures, "\n         "))
		end)
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
	for _, kit in KITS do
		local route = MoveData.Kits[kit].FullRoutes[1].name
		for _, case in { { "Rush" }, { "Awaken", route }, { "Gate" }, { "Gate", nil, 1 }, { "Awaken", route, 1 }, { "Fatal" }, { "Fatal", nil, 1 } } do
			local bad = overlappedHands(kit, case[1], case[2], case[3])
			expect(#bad == 0, string.format("%s %s%s: %s", kit, case[1], if case[3] then " (K.O.)" else "", table.concat(bad, ", ")))
		end
	end
end)

-- FATAL FINISHERS (Finishers.luau): each one its own scene, cut like the others, and the K.O.
-- itself. Their sounds are the names SoundController:cinematicSound plays, each from the
-- palette (SoundPalette): the attacker's own matter for whoosh and heavy.
local FINISHER_SOUNDS = { whoosh = "heavySwing", heavy = "heavyHit", slash = "BlockSteel", boom = "Explosion", charge = "SuperFlash",
	beam = "Cinematic" }
test("every FATAL FINISHER is its own scene: own shots and name, no strobe, the K.O. with its name after the blow, the target down", function()
	local Palette = require("../src/shared/SoundPalette")
	-- (a move's name without its kanji: "零 · ZERO ABSOLU: ECLIPSE" is ZERO ABSOLU: ECLIPSE)
	local moveNames = {}
	for id, m in MoveData.Moves do
		moveNames[(m.name or ""):gsub("^.* · ", "")] = MoveData.MoveKit[id]
	end
	local owners, names = {}, {}
	for _, kit in KITS do
		local data = MoveData.Kits[kit].Finisher
		if not data then continue end
		expect(not names[data.Name], kit .. " takes the finisher name of " .. tostring(names[data.Name]))
		local owner = moveNames[data.Name]
		expect(owner == nil or owner == kit, string.format("%s: its finisher has the name of a move of %s (%s)", kit, tostring(owner), data.Name))
		names[data.Name] = kit
		local shots, last, since, short, played = {}, nil, 0, 0, false
		local koAt, koName, lastPose, sounds = nil, nil, nil, {}
		Kit.play(kit, "Fatal", nil, 300, 0, function(info)
			local frame = info.frame
			played = played or info.cin.finisher == true
			if frame.shot.name ~= last then
				if last then
					local length = info.tick - since
					expect(length >= 5, string.format("%s: the shot %s lasts %d ticks", kit, last, length))
					if length < 9 then short += 1 end
				end
				last, since = frame.shot.name, info.tick
				shots[frame.shot.name] = true
			end
			local ko = frame.overlay and frame.overlay.ko
			if ko and not koAt then koAt, koName = info.tick, ko.sub end
			for _, fx in frame.fx do
				if fx.kind == "sfx" then sounds[fx.sound] = true end
			end
			lastPose = info.views[info.cin.defender].pose
		end)
		expect(played, kit .. ": the lab's killing COUP FATAL did not play its finisher")
		local count = 0
		for name in shots do
			count += 1
			expect(owners[name] == nil, string.format("%s borrows the finisher shot %s of %s", kit, name, tostring(owners[name])))
			owners[name] = kit
		end
		expect(count >= 6, kit .. ": only " .. count .. " shots in its finisher")
		expect(short <= 2, kit .. ": " .. short .. " shots under 9 ticks")
		expect(koAt and koAt >= data.FinalTick and koName == data.Name,
			string.format("%s: the K.O. (%s at %s) before its blow (%d) or without its name", kit, tostring(koName), tostring(koAt), data.FinalTick))
		expect(lastPose == "DownFace", kit .. ": the target is not down at the end (" .. tostring(lastPose) .. ")")
		local own = Palette.MATERIALS[kit] or Palette.MATERIALS.KAI
		for sound in sounds do
			local key = FINISHER_SOUNDS[sound]
			expect(key ~= nil, kit .. ": the sound " .. tostring(sound) .. " is not one of the finishers'")
			if key then expect(own[key] or Palette.ACTIONS[key], kit .. ": " .. sound .. " has no sound in the palette") end
		end
	end
end)

-- NOVA 機 · FATAL ERROR: her drones, her rail, the target's crash; on both sides of the arena.
test("NOVA's FATAL ERROR: eight drones ring the target, dock in a rail at her gauntlet, 3 2 1 0, the shot through it, it glitches and falls", function()
	local data = MoveData.Kits.NOVA.Finisher
	local F = data.FinalTick
	local function dist(p, q)
		return math.sqrt((p[1] - q[1]) ^ 2 + (p[2] - q[2]) ^ 2 + (p[3] - q[3]) ^ 2)
	end
	-- distance from a point to the segment a-b
	local function toSegment(p, a, b)
		local ab, ap = { b[1] - a[1], b[2] - a[2], b[3] - a[3] }, { p[1] - a[1], p[2] - a[2], p[3] - a[3] }
		local t = math.clamp((ap[1] * ab[1] + ap[2] * ab[2] + ap[3] * ab[3]) / math.max(1e-6, ab[1] ^ 2 + ab[2] ^ 2 + ab[3] ^ 2), 0, 1)
		return dist(p, { a[1] + ab[1] * t, a[2] + ab[2] * t, a[3] + ab[3] * t })
	end
	for _, mirror in { false, true } do
		local side = if mirror then "from the right" else "from the left"
		local ringed, docked, nearHand, count, through, glitch, guard, moves = 0, 0, math.huge, {}, false, {}, false, {}
		local lastPose, koName
		Kit.play("NOVA", "Fatal", nil, 300, 0, function(info)
			local frame, A, D = info.frame, info.cin.attacker, info.cin.defender
			local function at(point) return { Kit.resolve(point, info.parts) } end
			local chest = { info.parts[D].UpperTorso.cframe[1], info.parts[D].UpperTorso.cframe[2], info.parts[D].UpperTorso.cframe[3] }
			local hand = { info.parts[A].LeftHand.cframe[1], info.parts[A].LeftHand.cframe[2], info.parts[A].LeftHand.cframe[3] }
			if info.views[A].move then moves[info.views[A].move] = true end
			if info.tick < F and info.views[D].pose == "Block" then guard = true end
			if info.tick == 200 then
				-- (the drones: small balls of her colour round the target)
				for _, sh in frame.shapes or {} do
					if sh.kind == "sphere" and sh.radius <= 0.2 then
						local p = at(sh.pos)
						local flat = math.sqrt((p[1] - chest[1]) ^ 2 + (p[3] - chest[3]) ^ 2)
						if flat > 3 and flat < 7 then ringed += 1 end
					end
				end
			elseif info.tick == 330 then
				-- (the rail: rings turned along the shot, between her gauntlet and the target)
				for _, sh in frame.shapes or {} do
					if sh.kind == "ring" and math.abs(sh.normal.x) > 0.9 and sh.radius > 0.6 and sh.radius < 1.2 then
						local p = at(sh.pos)
						if toSegment(p, hand, chest) < 0.6 and dist(p, chest) > 1.2 then -- (not the lock on its chest)
							docked += 1
							nearHand = math.min(nearHand, dist(p, hand))
						end
					end
				end
			elseif info.tick == F then
				-- (the shot: one line through its chest on to the wall)
				for _, sh in frame.shapes or {} do
					if sh.kind == "slash" then
						local from, to = at(sh.from), at(sh.to)
						if toSegment(chest, from, to) < 0.8 and math.abs(to[1]) >= Config.ArenaMaxX - 1 then through = true end
					end
				end
			end
			local caption = frame.overlay and frame.overlay.caption
			if caption and caption.text ~= count[#count] then
				expect(info.tick < F, side .. ": the count goes on after the shot")
				table.insert(count, caption.text)
			end
			for _, fx in frame.fx do
				if fx.kind == "afterimage" and fx.slot == D and info.tick > F then glitch[fx.color] = true end
			end
			lastPose = info.views[D].pose
			koName = frame.overlay and frame.overlay.ko and frame.overlay.ko.sub or koName
		end, mirror)
		expect(ringed == 8, side .. ": " .. ringed .. " drones round the target, not eight")
		expect(docked == 8 and nearHand < 1.5, string.format("%s: %d rings in the rail, the first %.2f stud from her gauntlet", side, docked, nearHand))
		expect(table.concat(count, " ") == "3 2 1 0", side .. ": the count reads " .. table.concat(count, " "))
		expect(through, side .. ": the shot does not go through the target to the wall")
		local colours = 0
		for _ in glitch do colours += 1 end
		expect(colours >= 2, side .. ": the target does not glitch in her two colours")
		expect(guard, side .. ": the target never raises its guard")
		expect(moves.NovaSentinel and moves[MoveData.Kits.NOVA.Roles.KiBlast], side .. ": she does not launch her drones and hold her cannon (her own moves)")
		expect(lastPose == "DownFace" and koName == data.Name, side .. ": no K.O. " .. data.Name .. " with the target down")
	end
end)

test("one K.O. on screen: the HUD keeps quiet when the K.O. scene ends the match (1v1 rounds, relays)", function()
	local Director = require("../src/shared/CinematicDirector")
	local cfg = { RoundsToWin = 2 }
	local function world(wins, team, index)
		local l = { wins = 0, team = team, teamIndex = index }
		return { fighters = { { wins = wins }, l } }
	end
	expect(not Director.matchDecided(world(1), cfg, 1), "round 1 won: the HUD says K.O.")
	expect(Director.matchDecided(world(2), cfg, 1), "match won: the K.O. scene says it")
	expect(not Director.matchDecided(world(2), cfg, 0), "a draw: never a K.O. scene")
	expect(not Director.matchDecided(world(3, { "KAI", "TARO" }, 2), cfg, 1), "relay: a fighter left, the HUD says K.O.")
	expect(Director.matchDecided(world(0, { "KAI", "TARO" }, 3), cfg, 1), "relay: nobody left, the K.O. scene")
	local w = world(2)
	w.training = true
	expect(not Director.matchDecided(w, cfg, 1), "training: no K.O. scene")
end)

T.finish()
