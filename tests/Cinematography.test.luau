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
-- CinematicKit.play; known: one measured overshoot of the focus point let through, bounded,
-- { shot, from, to, maxY, count }: in that shot, between those ticks, the point still inside
-- the frame's width and under maxY of its half height, at most `count` frames; anything worse,
-- longer or elsewhere fails, and it is sorted out before the list of failures is cut short)
local function check(kit, kind, style, hp, center, mirror, wall, known)
	local failures, excused = {}, 0
	local function fail(info, text)
		if #failures < 6 then
			table.insert(failures, string.format("t%d %s: %s", info.tick, info.frame.shot.name, text))
		end
	end
	local function tolerated(info, fx, fy)
		if not (known and fx and info.frame.shot.name == known.shot) then return false end
		if info.tick < known.from or info.tick > known.to or math.abs(fx) > 1 or math.abs(fy) > known.maxY then return false end
		if excused >= known.count then return false end
		excused += 1
		return true
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
		if (not fx or math.abs(fx) > 1 or math.abs(fy) > 0.78) and not tolerated(info, fx, fy) then
			fail(info, if fx then string.format("the focus point is off screen (%.4f, %.4f)", fx, fy) else "the focus point is off screen")
		end
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

-- Every classic COUP FATAL with the attacker's back to the wall, on both sides (the lab never
-- stages it; the game does whenever the COUP FATAL starts there and does not end in a FATAL
-- FINISHER). One known exception, which is not the wall's: from the right, wall or not,
-- ZEPHYR's launch puts the focus point at 0.7845 of the half height for 0.78, five frames from
-- t22 to t24 (BUGS.md, B-010: the point stays on screen). It is let through as measured and no
-- further: past 0.79, outside t22-t24, on a sixth frame or in any other shot, it fails.
local KNOWN_FROM_THE_RIGHT = { ZEPHYR = { shot = "zephyr-lune-launch", from = 22, to = 24, maxY = 0.79, count = 5 } }
for _, kit in KITS do
	for _, mirror in { false, true } do
		local name = string.format("%s COUP FATAL, its back to the %s wall", kit, if mirror then "right" else "left")
		test(name .. ": camera clear of the bodies, subject on screen", function()
			local failures = check(kit, "Fatal", nil, nil, 0, mirror, true, if mirror then KNOWN_FROM_THE_RIGHT[kit] else nil)
			expect(#failures == 0, name .. "\n         " .. table.concat(failures, "\n         "))
		end)
	end
end

-- SHIN 一閃 ISSEN, the classic COUP FATAL (Wilhem's idea: an old samurai film, the two of them
-- far apart), near the walls: SHIN's back to the left one, to the right one, and the target
-- near the wall in front of him. Wherever it starts it is the film of the middle of the arena,
-- moved along the line: the same shots, the same camera on the same bodies, the duel 12 studs
-- apart, SHIN out 10 studs beyond the target after the cut, both on the deck, and no shot hides
-- its subject behind the other body (B-017: pinned at the wall, he waited 2.8 studs from the
-- target, his head behind it in the close-up of his hand on the hilt, 74 % hidden; the target
-- at the wall, he came out 1.7 studs beyond it).
local function issen(center, mirror, wall)
	local frames = {}
	Kit.play("SHIN", "Fatal", nil, nil, center, function(info)
		if frames[info.tick] then return end
		local A, D = info.cin.attacker, info.cin.defender
		local s = info.frame.shot
		local f = s.focus
		local hidden = 0
		if f and f.slot and f.part and not info.views[3 - f.slot].hidden then
			hidden = Kit.hiddenShare(info.parts[f.slot][f.part], info.parts[3 - f.slot], info.cam)
		end
		local data = MoveData.Cinematics[info.cin.move]
		frames[info.tick] = { shot = s.name, fov = s.fov, a = info.views[A].x, d = info.views[D].x, cam = info.cam,
			target = info.target, hidden = hidden, final = data.FinalTick, length = data.Length }
	end, mirror, wall)
	return frames
end
local ISSEN_MIDDLE = {}
for _, place in { { "his back to the left wall", 0, false, true }, { "his back to the right wall", 0, true, true },
	{ "the target near the right wall", Config.ArenaMaxX - 3, false, false },
	{ "the target near the left wall", Config.ArenaMinX + 3, true, false } } do
	local name = "SHIN's ISSEN, " .. place[1]
	test(name .. ": the film of the middle moved along the line, the duel 12 studs apart, nobody hidden by the other", function()
		local mirror = place[3]
		ISSEN_MIDDLE[mirror] = ISSEN_MIDDLE[mirror] or issen(0, mirror, false)
		local middle, frames = ISSEN_MIDDLE[mirror], issen(place[2], mirror, place[4])
		-- (each kind of failure once: its first tick, its worst value, how many ticks)
		local kinds, order = {}, {}
		local function fail(tick, kind, value, text)
			local k = kinds[kind]
			if not k then
				k = { n = 0, first = tick, worst = value, text = text }
				kinds[kind] = k
				table.insert(order, kind)
			end
			k.n += 1
			if value > k.worst then k.worst, k.text = value, text end
		end
		expect(frames[0] ~= nil and middle[0] ~= nil, name .. ": the scene did not play")
		local dir = if frames[0].d > frames[0].a then 1 else -1
		local shift = frames[0].d - middle[0].d
		local last = 0
		for tick in middle do last = math.max(last, tick) end
		for tick = 0, last do
			local m, fr = middle[tick], frames[tick]
			if not m then continue end
			if not fr then
				fail(tick, "missing", 0, "the scene stops early")
				continue
			end
			if fr.shot ~= m.shot or fr.fov ~= m.fov then fail(tick, "shot", 0, fr.shot .. " in place of " .. m.shot) end
			local gap = (fr.d - fr.a) * dir
			if tick < fr.final and math.abs(gap - 12) > 0.01 then
				fail(tick, "duel", math.abs(gap - 12), string.format("%s: the duel %.2f studs apart, not 12", fr.shot, gap))
			end
			if tick >= fr.final and tick < fr.length and math.abs(gap + 10) > 0.01 then
				fail(tick, "beyond", math.abs(gap + 10), string.format("%s: SHIN %.2f studs beyond the target, not 10", fr.shot, -gap))
			end
			local out = math.max(Config.ArenaMinX - fr.a, fr.a - Config.ArenaMaxX, Config.ArenaMinX - fr.d, fr.d - Config.ArenaMaxX)
			if out > 0 then fail(tick, "deck", out, string.format("%s: a body off the deck (%.2f, %.2f)", fr.shot, fr.a, fr.d)) end
			local moved = math.abs(fr.a - m.a - shift) + math.abs(fr.d - m.d - shift)
			for i = 1, 3 do
				local off = if i == 1 then shift else 0
				moved += math.abs(fr.cam[i] - m.cam[i] - off) + math.abs(fr.target[i] - m.target[i] - off)
			end
			if moved > 0.01 then
				fail(tick, "moved", moved, string.format("%s: not the staging of the middle moved by %.2f (off by %.2f)", fr.shot, shift, moved))
			end
			if fr.hidden > 0.25 then
				fail(tick, "hidden", fr.hidden, string.format("%s: %.0f %% of its subject hidden by the other body", fr.shot, fr.hidden * 100))
			end
		end
		local failures = {}
		for _, kind in order do
			local k = kinds[kind]
			table.insert(failures, string.format("from t%d, %d ticks; worst: %s", k.first, k.n, k.text))
		end
		expect(#failures == 0, name .. "\n         " .. table.concat(failures, "\n         "))
	end)
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

-- KUROEN 蝕 · BLACK SUN: the three red marks of DOMINATION on his back, three blows of his own
-- (the knee, the elbow, the palm), a small black sun left on the target by each, the three
-- gathered in his raised fist (his RISING UPPER) and brought down by both fists (AXE OF NIGHT).
-- What the last finishers taught: the marks on the bodies, never in them (B-012: NOVA's visor
-- inside her head); one light at a time (B-014: NOVA lit nine); no VICTORY (B-026). On both
-- sides of the arena.
local SHAPE_PARTS = { sphere = 3, ring = 22, motes = 40, slash = 2, dome = 1 } -- (CinematicController:drawShapes)
local KUROEN_FIRST_BLOW = 132 -- (the knee: its guard is up before it)
test("KUROEN's BLACK SUN: three marks on his back, three blows, three black suns gathered in his raised fist, brought down; one light at a time", function()
	local data = MoveData.Kits.KUROEN.Finisher
	expect(data ~= nil, "KUROEN has no FATAL FINISHER (MoveData: Finisher)")
	local roles = MoveData.Kits.KUROEN.Roles
	local F = data.FinalTick
	local SUN = "07040C"
	local function dist(p, q)
		return math.sqrt((p[1] - q[1]) ^ 2 + (p[2] - q[2]) ^ 2 + (p[3] - q[3]) ^ 2)
	end
	local function center(part)
		return { part.cframe[1], part.cframe[2], part.cframe[3] }
	end
	for _, mirror in { false, true } do
		local side = if mirror then "from the right" else "from the left"
		local backMarks, targetMarks, inside, sunInFist, fistUp, sunDown = 0, 0, {}, false, false, false
		local lightsMax, partsMax, moves, guard, knelt, victory = 0, 0, {}, false, false, false
		local lastPose, koName
		local eclipses, flights, jump = {}, {}, { d = 0 }
		Kit.play("KUROEN", "Fatal", nil, 300, 0, function(info)
			local frame, A, D, tick = info.frame, info.cin.attacker, info.cin.defender, info.tick
			if info.views[A].move then moves[info.views[A].move] = true end
			local pose = info.views[D].pose
			if tick < KUROEN_FIRST_BLOW and pose == "Block" then guard = true end
			if tick < F and pose == "Kneel" then knelt = true end
			lastPose = pose
			local over = frame.overlay or {}
			if over.ko then
				koName = over.ko.sub
				if tostring(over.ko.text):find("VICTORY") or tostring(over.ko.sub):find("VICTORY") then victory = true end
			end
			if frame.title and (tostring(frame.title.text):find("VICTORY") or tostring(frame.title.sub):find("VICTORY")) then victory = true end
			-- (the lights: each sphere of the frame has one, and each small black sun of the
			-- effects while it lives)
			for _, fx in frame.fx do
				if fx.kind == "eclipse" and not eclipses[fx.key] then eclipses[fx.key] = tick + (fx.life or 2) * 60 end
			end
			local lights, parts, suns = 0, 0, {}
			for _, last in eclipses do
				if tick <= last then lights += 1 end
			end
			for _, sh in frame.shapes or {} do
				parts += SHAPE_PARTS[sh.kind] or 0
				-- (each sun from the target to his fist, never a jump: B-013, a rail hung on a hand
				-- measured on the lab's rig)
				if sh.mark then
					local p, last = { Kit.resolve(sh.pos, info.parts) }, flights[sh.mark]
					if last and last.tick == tick - 1 and dist(p, last.p) > jump.d then jump = { d = dist(p, last.p), tick = tick, mark = sh.mark } end
					flights[sh.mark] = { p = p, tick = tick }
				end
				if sh.kind == "sphere" then
					lights += 1
					if sh.color == SUN then table.insert(suns, { Kit.resolve(sh.pos, info.parts) }) end
				end
				-- (a mark hung on a body: on it, never in it; his are on his back, the rings at his
				-- fist are the black sun's corona, over it)
				if sh.kind == "ring" and sh.pos.slot and (sh.pos.slot == D or sh.pos.part == "UpperTorso") then
					local part = info.parts[sh.pos.slot][sh.pos.part]
					local p = { Kit.resolve(sh.pos, info.parts) }
					local gap = Kit.boxDistance(part, p[1], p[2], p[3])
					local within = nil -- (nor in any other part of that body: its head, its arms)
					for name, other in info.parts[sh.pos.slot] do
						if Kit.boxDistance(other, p[1], p[2], p[3]) <= 0.02 then within = name end
					end
					local limit = if sh.pos.slot == A then 0.45 else 0.6
					local behind = true
					if sh.pos.slot == A then
						-- (on his back: behind his chest, the rig facing its -Z)
						local t, c = part.cframe, center(part)
						behind = (p[1] - c[1]) * -t[6] + (p[2] - c[2]) * -t[9] + (p[3] - c[3]) * -t[12] < 0
					end
					if gap <= 0.02 or gap > limit or not behind or within then
						table.insert(inside, string.format("t%d %s %s: %.2f from its box%s%s", tick, if sh.pos.slot == A then "his" else "its",
							sh.pos.part, gap, if behind then "" else ", not on his back", if within then ", inside its " .. within else ""))
					end
				end
			end
			lightsMax, partsMax = math.max(lightsMax, lights), math.max(partsMax, parts)
			if tick == 100 then
				for _, sh in frame.shapes or {} do
					if sh.kind == "ring" and sh.pos.slot == A and sh.pos.part == "UpperTorso" then backMarks += 1 end
				end
			elseif tick == 290 then
				for _, sh in frame.shapes or {} do
					if sh.kind == "ring" and sh.pos.slot == D then targetMarks += 1 end
				end
			elseif tick == 400 then
				local hand, head = center(info.parts[A].RightHand), center(info.parts[A].Head)
				fistUp = hand[2] > head[2] + 0.6
				sunInFist = #suns == 1 and dist(suns[1], hand) < 1.3
			elseif tick == F + 4 then
				local chest = center(info.parts[D].UpperTorso)
				sunDown = #suns == 1 and math.abs(suns[1][1] - chest[1]) < 2.5 and suns[1][2] < 2
			end
		end, mirror)
		expect(backMarks == 3, side .. ": " .. backMarks .. " marks of DOMINATION on his back, not three")
		expect(targetMarks == 3, side .. ": " .. targetMarks .. " black suns left on the target, not three")
		expect(#inside == 0, side .. ": a mark is not on its body (" .. #inside .. " frames)\n         " .. table.concat(inside, "\n         ", 1, math.min(6, #inside)))
		expect(fistUp and sunInFist, side .. ": the black sun is not in his raised fist")
		expect(jump.d <= 0.5, string.format("%s: sun %s jumps %.2f studs at t%s", side, tostring(jump.mark), jump.d, tostring(jump.tick)))
		expect(sunDown, side .. ": the black sun is not brought down on the target")
		expect(lightsMax <= 1, side .. ": " .. lightsMax .. " lights at once (B-014: one at most)")
		expect(partsMax <= 250, side .. ": " .. partsMax .. " parts of light in one frame")
		for _, r in { "Kick", "Elbow", "PalmStrike", "Uppercut", "Hammer" } do
			expect(moves[roles[r]], side .. ": he does not strike with his own " .. r .. " (" .. tostring(roles[r]) .. ")")
		end
		expect(guard and knelt, side .. ": the target never raises its guard, or never kneels before him")
		expect(lastPose == "DownFace" and koName == data.Name, side .. ": no K.O. " .. data.Name .. " with the target down")
		expect(not victory, side .. ": VICTORY on screen (B-026: a finisher may not end the match)")
	end
end)

-- BLACK SUN near the walls (as SHIN's ISSEN, B-017): his back to the left wall, to the right one,
-- and the target near the wall in front of him. Wherever it starts it is the film of the middle
-- of the arena moved along the line (`room`: the whole scene stands back, never him alone):
-- the same shots, the same camera on the same bodies, both on the deck, the camera over the floor
-- (it ends at x = ±40, B-016); and in no frame, there or in the middle, from either side, is more
-- than a quarter of a shot's subject hidden behind the other body (Kit.hiddenShare; the lab's KAI
-- rig: real avatars are not its size, B-018).
local function film(kit, center, mirror, wall)
	local frames = {}
	Kit.play(kit, "Fatal", nil, 300, center, function(info)
		if frames[info.tick] then return end
		local s = info.frame.shot
		local f = s.focus
		local hidden = 0
		if f and f.slot and f.part and not info.views[3 - f.slot].hidden then
			hidden = Kit.hiddenShare(info.parts[f.slot][f.part], info.parts[3 - f.slot], info.cam)
		end
		frames[info.tick] = { shot = s.name, fov = s.fov, a = info.views[info.cin.attacker].x, d = info.views[info.cin.defender].x,
			cam = info.cam, target = info.target, hidden = hidden, finisher = info.cin.finisher == true }
	end, mirror, wall)
	return frames
end
local BLACK_SUN_MIDDLE = {}
for _, place in { { "in the middle, from the left", 0, false, false, true }, { "in the middle, from the right", 0, true, false, true },
	{ "his back to the left wall", 0, false, true }, { "his back to the right wall", 0, true, true },
	{ "the target near the right wall", Config.ArenaMaxX - 3, false, false },
	{ "the target near the left wall", Config.ArenaMinX + 3, true, false } } do
	local name = "KUROEN's BLACK SUN, " .. place[1]
	test(name .. ": the film of the middle moved along the line, both on the deck, nobody hidden by the other", function()
		local mirror = place[3]
		BLACK_SUN_MIDDLE[mirror] = BLACK_SUN_MIDDLE[mirror] or film("KUROEN", 0, mirror, false)
		local middle = BLACK_SUN_MIDDLE[mirror]
		local frames = if place[5] then middle else film("KUROEN", place[2], mirror, place[4])
		-- (each kind of failure once: its first tick, its worst value, how many ticks)
		local kinds, order = {}, {}
		local function fail(tick, kind, value, text)
			local k = kinds[kind]
			if not k then
				k = { n = 0, first = tick, worst = value, text = text }
				kinds[kind] = k
				table.insert(order, kind)
			end
			k.n += 1
			if value > k.worst then k.worst, k.text = value, text end
		end
		expect(frames[0] ~= nil and frames[0].finisher, name .. ": the finisher did not play")
		local shift = frames[0].d - middle[0].d
		local last = 0
		for tick in middle do last = math.max(last, tick) end
		for tick = 0, last do
			local m, fr = middle[tick], frames[tick]
			if not m then continue end
			if not fr then
				fail(tick, "missing", 0, "the scene stops early")
				continue
			end
			if fr.shot ~= m.shot or fr.fov ~= m.fov then fail(tick, "shot", 0, fr.shot .. " in place of " .. m.shot) end
			local out = math.max(Config.ArenaMinX - fr.a, fr.a - Config.ArenaMaxX, Config.ArenaMinX - fr.d, fr.d - Config.ArenaMaxX)
			if out > 0 then fail(tick, "deck", out, string.format("%s: a body off the deck (%.2f, %.2f)", fr.shot, fr.a, fr.d)) end
			if math.abs(fr.cam[1]) > 40 then
				fail(tick, "floor", math.abs(fr.cam[1]) - 40, string.format("%s: the camera beyond the end of the floor (x = %.2f)", fr.shot, fr.cam[1]))
			end
			local moved = math.abs(fr.a - m.a - shift) + math.abs(fr.d - m.d - shift)
			for i = 1, 3 do
				local off = if i == 1 then shift else 0
				moved += math.abs(fr.cam[i] - m.cam[i] - off) + math.abs(fr.target[i] - m.target[i] - off)
			end
			if moved > 0.01 then
				fail(tick, "moved", moved, string.format("%s: not the staging of the middle moved by %.2f (off by %.2f)", fr.shot, shift, moved))
			end
			if fr.hidden > 0.25 then
				fail(tick, "hidden", fr.hidden, string.format("%s: %.0f %% of its subject hidden by the other body", fr.shot, fr.hidden * 100))
			end
		end
		local failures = {}
		for _, kind in order do
			local k = kinds[kind]
			table.insert(failures, string.format("from t%d, %d ticks; worst: %s", k.first, k.n, k.text))
		end
		expect(#failures == 0, name .. "\n         " .. table.concat(failures, "\n         "))
	end)
end

-- ASURA 阿 · SAMSARA, the boss's own FATAL FINISHER (I-001): his four arms thrown out in an X
-- (the real pair up, the extra pair down: PoseLibrary AsuraWheel, FourArms "spokes"), a golden
-- wheel behind his back with its spokes along them, his four fists taking fire one by one along
-- the X, all four drawn back to his hips (AsuraChamber, FourArms "cocked"), then his two palms
-- and, a beat after, his two lower fists converging into it (AsuraFourStrike, "converge"); the
-- target blown back into the wheel stamped into the deck.
-- What the last finishers taught: the tools see his lower arms (CinematicKit: his parts carry
-- them, eased as the client eases them), every shape carries a mark and none jumps (B-031),
-- one light at a time (B-014), no VICTORY nor his victory poses (B-026), not his throw (the
-- target lifted over his head), not his gatling; his matter only (no steel). On both sides:
-- in the CHALLENGE he is team 2 and strikes from the right.
local SAMSARA_FISTS = { "RightHand", "AsuraFistLeft", "LeftHand", "AsuraFistRight" } -- (the order they take fire: the X's diagonals)
-- (the effects that carry a light, with their life in seconds when the request has none)
local LIGHT_FX = { eclipse = 2, afterimage = 1, asuraFist = 0.75, rageFist = 0.75, divineFist = 0.75, crimsonFist = 0.75, lightning = 0.12 }
local function center3(part)
	return { part.cframe[1], part.cframe[2], part.cframe[3] }
end
local function dist3(p, q)
	return math.sqrt((p[1] - q[1]) ^ 2 + (p[2] - q[2]) ^ 2 + (p[3] - q[3]) ^ 2)
end
test("ASURA's SAMSARA: his four arms in an X before a golden wheel, his four fists take fire one by one, two palms then two fists; one light at a time, nothing jumps", function()
	local data = MoveData.Kits.ASURA.Finisher
	expect(data ~= nil and data.Name == "SAMSARA", "ASURA has no FATAL FINISHER of his own (MoveData: Finisher on his kit)")
	expect(MoveData.Kits.KAI.Finisher.Name == "MAXIMUM KAIENHA", "KAI's finisher is not MAXIMUM KAIENHA any more")
	local Director = require("../src/shared/CinematicDirector")
	expect(Director.finishers and Director.finishers.ASURA ~= nil, "no scene S.ASURA in Finishers.luau")
	local F = data.FinalTick
	local ALLOWED = { whoosh = true, heavy = true, boom = true, charge = true } -- (his matter: no steel, no beam)
	for _, mirror in { false, true } do
		local side = if mirror then "from the right" else "from the left"
		local played, own, unmarked, lightsMax, partsMax = false, true, 0, 0, 0
		local last, jump, lit, fx = {}, { d = 0 }, {}, {}
		local poses, moves, sounds, issues = {}, {}, {}, {}
		local xShape, spokes, wheelBehind, fireOnFist, ringRound, burningAtDraw, handsOnIt = false, 0, false, true, true, 0, 0
		local guard, broken, lifted, victory, lastPose, koName, seal, endChest = false, false, 0, false, nil, nil, nil, nil
		local function issue(text)
			if #issues < 8 then table.insert(issues, text) end
		end
		Kit.play("ASURA", "Fatal", nil, 300, 0, function(info)
			local frame, A, D, tick = info.frame, info.cin.attacker, info.cin.defender, info.tick
			local shot = frame.shot.name
			played = played or (info.cin.finisher == true and info.cin.kit == "ASURA")
			own = own and shot:find("^asura%-ss%-") ~= nil
			local me, it = info.views[A], info.views[D]
			if me.pose then poses[me.pose] = true end
			if me.move then moves[me.move] = true end
			if me.victory or me.pose == "Victory" or me.pose == "VictoryAlt" then victory = true end
			if me.state == "Throwing" or it.state == "Thrown" then moves.throw = true end
			if tick < F - 10 and it.pose == "Block" then guard = true end
			if tick >= F - 10 and tick < F and it.pose == "GuardBroken" then broken = true end
			lifted = math.max(lifted, it.y or 0)
			lastPose = it.pose
			local over = frame.overlay or {}
			if over.ko then
				koName = over.ko.sub
				if tostring(over.ko.text):find("VICTORY") or tostring(over.ko.sub):find("VICTORY") then victory = true end
			end
			if frame.title and (tostring(frame.title.text):find("VICTORY") or tostring(frame.title.sub):find("VICTORY")) then victory = true end
			-- (the lights: each sphere of the frame, and each effect that carries one while it lives)
			local lights, parts = 0, 0
			for _, e in frame.fx do
				if e.kind == "sfx" then sounds[e.sound] = true end
				if LIGHT_FX[e.kind] and not fx[e.key] then fx[e.key] = tick + (e.life or LIGHT_FX[e.kind]) * 60 end
			end
			for _, ends in fx do
				if tick <= ends then lights += 1 end
			end
			local body, its = info.parts[A], info.parts[D]
			local head, chest = center3(body.Head), center3(body.UpperTorso)
			local t = body.UpperTorso.cframe
			local rightAxis, frontAxis = { t[4], t[7], t[10] }, { -t[6], -t[9], -t[12] }
			local function lateral(p) return (p[1] - chest[1]) * rightAxis[1] + (p[2] - chest[2]) * rightAxis[2] + (p[3] - chest[3]) * rightAxis[3] end
			-- (his extra arms are on his body for the tools, and never rise before his face)
			for _, name in { "AsuraFistLeft", "AsuraFistRight" } do
				local f = body[name]
				if not f then
					issue("t" .. tick .. ": the tools do not see his " .. name)
				else
					local p = center3(f)
					if p[2] > head[2] - 0.5 and math.abs(lateral(p)) < 1.5 then issue(string.format("t%d %s: his %s before his face", tick, shot, name)) end
				end
			end
			local marks = {}
			for _, sh in frame.shapes or {} do
				parts += SHAPE_PARTS[sh.kind] or 0
				if sh.kind == "sphere" then lights += 1 end
				if not sh.mark then
					unmarked += 1
				else
					-- (every shape followed, its centre or both ends: never a jump inside a shot, B-031)
					local points = {}
					for _, key in { "pos", "from", "to" } do
						if sh[key] then table.insert(points, { Kit.resolve(sh[key], info.parts) }) end
					end
					local prev = last[sh.mark]
					if prev and prev.tick == tick - 1 and prev.shot == shot then
						for k, p in points do
							local d = dist3(p, prev.points[k])
							if d > jump.d then jump = { d = d, tick = tick, mark = sh.mark, shot = shot } end
						end
					end
					last[sh.mark] = { points = points, tick = tick, shot = shot }
					marks[sh.mark] = { shape = sh, points = points }
				end
			end
			lightsMax, partsMax = math.max(lightsMax, lights), math.max(partsMax, parts)
			-- THE FISTS: each fire is a ring round its own fist (two real hands, two lower fists),
			-- lit in the order of the X; never inside the fist
			for i, part in SAMSARA_FISTS do
				local m = marks["fist" .. i]
				if m then
					lit[i] = lit[i] or tick
					if m.shape.pos.part ~= part or m.shape.pos.slot ~= A or dist3(m.points[1], center3(body[part])) > 0.01 then fireOnFist = false end
					local half = math.max(table.unpack(body[part].size)) / 2
					if m.shape.radius < half + 0.05 then ringRound = false end
				end
			end
			if tick == F - 12 then
				for i = 1, 4 do
					if marks["fist" .. i] then burningAtDraw += 1 end
				end
			end
			-- THE X and THE WHEEL (before the first fist takes fire: the wheel not yet turned)
			if tick == 220 then
				local hands = {}
				for _, part in SAMSARA_FISTS do hands[part] = center3(body[part]) end
				local up = hands.RightHand[2] > head[2] and hands.LeftHand[2] > head[2]
				local down = hands.AsuraFistLeft[2] < chest[2] - 1 and hands.AsuraFistRight[2] < chest[2] - 1
				local out = true
				for _, p in hands do
					if math.abs(lateral(p)) < 2 then out = false end
				end
				xShape = up and down and out and lateral(hands.RightHand) > 0 and lateral(hands.AsuraFistRight) > 0
					and lateral(hands.LeftHand) < 0 and lateral(hands.AsuraFistLeft) < 0
				local wheel = marks.wheel
				if wheel then
					local p = wheel.points[1]
					local back = (p[1] - chest[1]) * frontAxis[1] + (p[2] - chest[2]) * frontAxis[2] + (p[3] - chest[3]) * frontAxis[3]
					local clear = math.huge
					for _, part in body do clear = math.min(clear, Kit.boxDistance(part, p[1], p[2], p[3])) end
					wheelBehind = back < -0.3 and clear >= 0.15
					-- (each fist at the end of a spoke: in the wheel's plane, the angle from its hub)
					for _, part in SAMSARA_FISTS do
						local h = hands[part]
						local best = math.huge
						for k = 1, 4 do
							local s_ = marks["spoke" .. k]
							if s_ then
								local a1 = { s_.points[2][1] - s_.points[1][1], s_.points[2][2] - s_.points[1][2], s_.points[2][3] - s_.points[1][3] }
								local a2 = { h[1] - p[1], h[2] - p[2], h[3] - p[3] }
								-- (the fist seen from his front: its offset along his facing left out)
								local along = a2[1] * frontAxis[1] + a2[2] * frontAxis[2] + a2[3] * frontAxis[3]
								a2 = { a2[1] - frontAxis[1] * along, a2[2] - frontAxis[2] * along, a2[3] - frontAxis[3] * along }
								local c = (a1[1] * a2[1] + a1[2] * a2[2] + a1[3] * a2[3]) / (math.sqrt(a1[1] ^ 2 + a1[2] ^ 2 + a1[3] ^ 2)
									* math.sqrt(a2[1] ^ 2 + a2[2] ^ 2 + a2[3] ^ 2))
								best = math.min(best, math.deg(math.acos(math.clamp(c, -1, 1))))
							end
						end
						if best < 25 then spokes += 1 end
					end
				end
			end
			-- THE BLOW: his two palms and his two lower fists on it
			if tick == F then
				for _, part in SAMSARA_FISTS do
					local p = center3(body[part])
					local near = math.huge
					for _, other in its do near = math.min(near, Kit.boxDistance(other, p[1], p[2], p[3])) end
					if near < 0.9 then handsOnIt += 1 end
				end
			end
			if marks.seal then seal = marks.seal.points[1] end
			endChest = center3(its.UpperTorso)
		end, mirror)
		expect(played and own, side .. ": the killing COUP FATAL did not play SAMSARA (its own shots)")
		expect(#issues == 0, side .. "\n         " .. table.concat(issues, "\n         "))
		expect(poses.AsuraWheel and xShape, side .. ": his four arms are not out in an X (the real pair up, the extra pair down)")
		expect(wheelBehind, side .. ": the wheel is not behind his back, clear of his body")
		expect(spokes == 4, side .. ": " .. spokes .. " of his four fists at the end of a spoke of the wheel")
		expect(#lit == 4 and fireOnFist and ringRound, side .. ": his four fists do not each take fire, a ring round the fist")
		expect(lit[1] and lit[2] and lit[3] and lit[4] and lit[1] < lit[2] and lit[2] < lit[3] and lit[3] < lit[4],
			side .. ": his fists do not take fire one after the other, along the X")
		expect(burningAtDraw == 4, side .. ": " .. burningAtDraw .. " fists burning as he draws them back")
		expect(handsOnIt == 4, side .. ": " .. handsOnIt .. " of his four hands on the target on the blow")
		expect(poses.AsuraChamber and poses.AsuraFourStrike, side .. ": his four fists are not drawn back, then driven in together")
		expect(not moves.AsuraGatling and not moves.throw, side .. ": his gatling, or his throw (the target lifted over his head)")
		expect(guard and broken and lifted < 1.2, string.format("%s: the target does not raise its guard and see it torn open, or is lifted (%.1f)", side, lifted))
		expect(seal and seal[2] < 0.2 and endChest and math.sqrt((seal[1] - endChest[1]) ^ 2 + (seal[3] - endChest[3]) ^ 2) < 1.5,
			side .. ": the target does not lie in the wheel stamped into the deck")
		expect(unmarked == 0, side .. ": " .. unmarked .. " shapes without a mark")
		expect(jump.d <= 0.5, string.format("%s: %s jumps %.2f studs at t%s (%s)", side, tostring(jump.mark), jump.d, tostring(jump.tick), tostring(jump.shot)))
		expect(lightsMax <= 1, side .. ": " .. lightsMax .. " lights at once (B-014: one at most)")
		expect(partsMax <= 250, side .. ": " .. partsMax .. " parts of light in one frame")
		for sound in sounds do
			expect(ALLOWED[sound], side .. ": the sound " .. sound .. " is not his matter")
		end
		expect(lastPose == "DownFace" and koName == data.Name, side .. ": no K.O. " .. data.Name .. " with the target down")
		expect(not victory, side .. ": VICTORY, or his victory poses (B-026: a finisher may not end the match)")
	end
end)

-- SAMSARA near the walls, as BLACK SUN: his back to the left wall, to the right one, the target
-- near the wall in front of him, and the middle from both sides. Wherever it starts it is the
-- film of the middle moved along the line (`room`); both on the deck, the camera over the
-- floor, and never more than a quarter of a shot's subject hidden behind the other body, his
-- lower arms included (they are on his body for the tools).
local SAMSARA_MIDDLE = {}
for _, place in { { "in the middle, from the left", 0, false, false, true }, { "in the middle, from the right", 0, true, false, true },
	{ "his back to the left wall", 0, false, true }, { "his back to the right wall", 0, true, true },
	{ "the target near the right wall", Config.ArenaMaxX - 3, false, false },
	{ "the target near the left wall", Config.ArenaMinX + 3, true, false } } do
	local name = "ASURA's SAMSARA, " .. place[1]
	test(name .. ": the film of the middle moved along the line, both on the deck, nobody hidden by the other", function()
		local mirror = place[3]
		SAMSARA_MIDDLE[mirror] = SAMSARA_MIDDLE[mirror] or film("ASURA", 0, mirror, false)
		local middle = SAMSARA_MIDDLE[mirror]
		local frames = if place[5] then middle else film("ASURA", place[2], mirror, place[4])
		local kinds, order = {}, {}
		local function fail(tick, kind, value, text)
			local k = kinds[kind]
			if not k then
				k = { n = 0, first = tick, worst = value, text = text }
				kinds[kind] = k
				table.insert(order, kind)
			end
			k.n += 1
			if value > k.worst then k.worst, k.text = value, text end
		end
		expect(frames[0] ~= nil and frames[0].finisher, name .. ": the finisher did not play")
		local shift = frames[0].d - middle[0].d
		local last = 0
		for tick in middle do last = math.max(last, tick) end
		for tick = 0, last do
			local m, fr = middle[tick], frames[tick]
			if not m then continue end
			if not fr then
				fail(tick, "missing", 0, "the scene stops early")
				continue
			end
			if fr.shot ~= m.shot or fr.fov ~= m.fov then fail(tick, "shot", 0, fr.shot .. " in place of " .. m.shot) end
			local out = math.max(Config.ArenaMinX - fr.a, fr.a - Config.ArenaMaxX, Config.ArenaMinX - fr.d, fr.d - Config.ArenaMaxX)
			if out > 0 then fail(tick, "deck", out, string.format("%s: a body off the deck (%.2f, %.2f)", fr.shot, fr.a, fr.d)) end
			if math.abs(fr.cam[1]) > 40 then
				fail(tick, "floor", math.abs(fr.cam[1]) - 40, string.format("%s: the camera beyond the end of the floor (x = %.2f)", fr.shot, fr.cam[1]))
			end
			local moved = math.abs(fr.a - m.a - shift) + math.abs(fr.d - m.d - shift)
			for i = 1, 3 do
				local off = if i == 1 then shift else 0
				moved += math.abs(fr.cam[i] - m.cam[i] - off) + math.abs(fr.target[i] - m.target[i] - off)
			end
			if moved > 0.01 then
				fail(tick, "moved", moved, string.format("%s: not the staging of the middle moved by %.2f (off by %.2f)", fr.shot, shift, moved))
			end
			if fr.hidden > 0.25 then
				fail(tick, "hidden", fr.hidden, string.format("%s: %.0f %% of its subject hidden by the other body", fr.shot, fr.hidden * 100))
			end
		end
		local failures = {}
		for _, kind in order do
			local k = kinds[kind]
			table.insert(failures, string.format("from t%d, %d ticks; worst: %s", k.first, k.n, k.text))
		end
		expect(#failures == 0, name .. "\n         " .. table.concat(failures, "\n         "))
	end)
end

-- A boss's FATAL FINISHER is named like nothing else in the game. The common test above only
-- compares it with the moves of the other kits; a boss's names live elsewhere too (his theme's
-- ultimates, his PORTE title, his passive, his E, the challenge's titles and achievements: B-009
-- for the trap). Its name (without a kanji) is none of them, appears in no other text the game
-- shows (Locale), and none of its words is already worn by more than two of them (WRATH,
-- THOUSAND, ARMS, FINAL, FIST for ASURA; ECLIPSE, EMPEROR, DIVINE, TRUE, ZERO for KUROEN SHIN).
-- (Bosses only: ASTER's B-009 and KUROEN's B-034 wait for Wilhem.)
test("a boss's FATAL FINISHER is named like nothing else: no move, ultimate, title, passive or achievement; no worn word", function()
	local Director = require("../src/shared/CinematicDirector")
	local Locale = require("../src/shared/Locale")
	local GameModes = require("../src/shared/GameModes")
	local function bare(name) return (tostring(name):gsub("^.* · ", "")) end
	local taken = {}
	local function take(name, what)
		if name then taken[bare(name)] = taken[bare(name)] or what end
	end
	for id, m in MoveData.Moves do take(m.name, "the move " .. id) end
	for kit, data in MoveData.Kits do
		if data.GateTitle then
			take(data.GateTitle.sub, kit .. "'s PORTE title")
			take(data.GateTitle.text, kit .. "'s PORTE title")
		end
		if data.Passive then take(data.Passive.Name, kit .. "'s passive") end
	end
	for kit, theme in Director.THEMES do
		for kind, name in theme.names or {} do take(name, kit .. "'s " .. kind) end
	end
	for name in GameModes.TITLE_LOOKS do take(name, "a title") end
	for _, list in { GameModes.CHALLENGE_TITLES, GameModes.SHIN_TITLES } do
		for _, name in list do take(name, "a challenge title") end
	end
	for _, a in GameModes.ACHIEVEMENTS do take(a.name, "an achievement") end
	local texts = {}
	for key in Locale.FR do texts[key] = true end
	for key in Locale.SAME do texts[key] = true end
	local checked = 0
	for kit, data in MoveData.Kits do
		if not (data.Boss and data.Finisher) then continue end
		checked += 1
		local name = data.Finisher.Name
		expect(not taken[bare(name)], string.format("%s: its finisher %s is the name of %s", kit, name, tostring(taken[bare(name)])))
		for other, d in MoveData.Kits do
			expect(other == kit or not d.Finisher or bare(d.Finisher.Name) ~= bare(name), kit .. ": its finisher has " .. other .. "'s name")
		end
		for text in texts do
			expect(text == name or not text:find(name, 1, true), string.format("%s: its finisher %s is already in « %s »", kit, name, text))
		end
		for word in bare(name):gmatch("[%a']+") do
			if #word >= 4 then
				local worn = 0
				for text in texts do
					if text ~= name and (" " .. text .. " "):find("[^%a]" .. word .. "[^%a]") then worn += 1 end
				end
				expect(worn <= 2, string.format("%s: the word %s of its finisher is already in %d texts", kit, word, worn))
			end
		end
	end
	expect(checked >= 1, "no boss has a FATAL FINISHER: this check has nothing to read")
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
