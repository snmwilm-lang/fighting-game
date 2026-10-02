-- Offline checks of every cinematic's camera work. Run from the repository root:
--   luau tests/CinematicDirector.test.luau
-- The real simulation plays each cinematic; the director stages each tick; rig parts are
-- approximated from the staged views. Each shot must keep the camera above the floor, out of
-- the bodies, inside the arena, and looking at its subject.
local Config = require("../src/shared/CombatConfig")
local MoveData = require("../src/shared/MoveData")
local CharacterData = require("../src/shared/CharacterData")
local Sim = require("../src/shared/CombatSimulation")
local Director = require("../src/shared/CinematicDirector")
local T = require("./TestKit")
local test, expect = T.test, T.expect

local function add(a, b) return { x = a.x + b.x, y = a.y + b.y, z = (a.z or 0) + (b.z or 0) } end
local function sub(a, b) return { x = a.x - b.x, y = a.y - b.y, z = (a.z or 0) - (b.z or 0) } end
local function scale(a, k) return { x = a.x * k, y = a.y * k, z = (a.z or 0) * k } end
local function dot(a, b) return a.x * b.x + a.y * b.y + (a.z or 0) * (b.z or 0) end
local function len(a) return math.sqrt(dot(a, a)) end
local function unit(a) local l = len(a) return if l > 0 then scale(a, 1 / l) else { x = 1, y = 0, z = 0 } end
local function finite(n) return n == n and math.abs(n) < 1e6 end
local function hitsBefore(hits, tick)
	local n = 0
	for _, t in hits do if t <= tick then n += 1 end end
	return n
end

local function lying(view)
	return view.pose == "DownFace" or view.state == "KO" and view.pose ~= "StandTall" or view.state == "Knockdown"
end

-- Approximate world positions of the rig parts the director aims at.
local function parts(view)
	local base = { x = view.x, y = view.y, z = view.z or 0 }
	local forward = if view.lookDir then unit(view.lookDir) else { x = view.facing or 1, y = 0, z = 0 }
	local right = { x = -forward.z, y = 0, z = forward.x }
	if lying(view) then
		return {
			Head = add(base, add(scale(forward, 2.4), { x = 0, y = 0.6, z = 0 })),
			UpperTorso = add(base, add(scale(forward, 1.2), { x = 0, y = 0.6, z = 0 })),
			RightHand = add(base, add(add(scale(forward, 2.6), scale(right, 1)), { x = 0, y = 0.3, z = 0 })),
			LeftFoot = add(base, add(scale(forward, -1.6), { x = 0, y = 0.3, z = 0 })),
			RightFoot = add(base, add(scale(forward, -1.6), { x = 0, y = 0.3, z = 0 })),
			lying = true,
		}
	end
	return {
		Head = add(base, { x = 0, y = 5.3, z = 0 }),
		UpperTorso = add(base, { x = 0, y = 4, z = 0 }),
		RightHand = add(base, add(scale(forward, 0.8), { x = 0, y = 2.6, z = 0 })),
		LeftFoot = add(base, add(scale(right, -0.5), { x = 0, y = 0.2, z = 0 })),
		RightFoot = add(base, add(scale(right, 0.5), { x = 0, y = 0.2, z = 0 })),
	}
end

local function resolve(point, rigParts)
	if point.position then return point.position end
	return add(rigParts[point.slot][point.part], point.offset)
end

local function segmentDistance(p, a, b)
	local ab, ap = sub(b, a), sub(p, a)
	local t = math.clamp(dot(ap, ab) / math.max(dot(ab, ab), 1e-6), 0, 1)
	return len(sub(p, add(a, scale(ab, t))))
end

-- Returns the problems of one frame (empty when the shot is fine).
local function checkFrame(frame, views)
	local problems = {}
	local shot = frame.shot
	if not shot then return { "no shot" } end
	local rigParts = { parts(views[1]), parts(views[2]) }
	local cam, target, focus = resolve(shot.from, rigParts), resolve(shot.to, rigParts), resolve(shot.focus, rigParts)
	for _, p in { cam, target, focus } do
		if not (finite(p.x) and finite(p.y) and finite(p.z)) then return { "non-finite point" } end
	end
	if cam.y < 0.15 then table.insert(problems, string.format("camera under the floor (y=%.2f)", cam.y)) end
	if len(sub(target, cam)) < 0.8 then table.insert(problems, "camera on top of its target") end
	if math.abs(cam.x) > 75 or cam.z < -12 or cam.z > 60 or cam.y > 40 then
		table.insert(problems, string.format("camera outside the arena (%.1f, %.1f, %.1f)", cam.x, cam.y, cam.z))
	end
	if dot(sub(focus, cam), sub(target, cam)) <= 0 then table.insert(problems, "focus behind the camera") end
	-- The subject must not be hidden by the other fighter (line of sight to the focus).
	local subject = shot.focus.slot
	if subject then
		local other = 3 - subject
		local o = rigParts[other]
		local base = { x = views[other].x, y = views[other].y, z = views[other].z or 0 }
		local a0, a1 = if o.lying then o.LeftFoot else base, if o.lying then o.Head else add(base, { x = 0, y = 5.6, z = 0 })
		local blocked = false
		for i = 1, 9 do
			local p = add(cam, scale(sub(focus, cam), i / 10))
			if segmentDistance(p, a0, a1) < (if o.lying then 0.35 else 0.55) then blocked = true end
		end
		if blocked then table.insert(problems, "subject hidden by fighter " .. other) end
	end
	for slot, view in views do
		local base = { x = view.x, y = view.y, z = view.z or 0 }
		local inside
		if rigParts[slot].lying then
			inside = segmentDistance(cam, rigParts[slot].LeftFoot, rigParts[slot].Head) < 0.45
		else
			inside = segmentDistance(cam, base, add(base, { x = 0, y = 5.6, z = 0 })) < 0.7
		end
		if inside then table.insert(problems, "camera inside fighter " .. slot) end
	end
	return problems
end

local function views(world)
	local list = {}
	for i, f in world.fighters do
		list[i] = { x = f.x, y = f.y, facing = f.facing, state = f.state, move = f.move, moveFrame = f.moveFrame,
			hp = f.hp, wins = f.wins, vx = f.vx }
	end
	return list
end

-- kind: "Rush", "Awaken" or "Gate", played by `kit` (KAI by default) against KAI.
local function playCinematic(kind, style, hp, center, kit)
	local world = Sim.newWorld(Config, MoveData, true)
	Sim.setKits(world, kit or "KAI", "KAI")
	local moveId = kind
	world.phase = "Fight"
	world.fighters[1].x, world.fighters[2].x = center - 1.3, center + 1.3
	Sim.debugCinematic(world, 1, moveId, style, hp)
	local anchors, failures, shots = {}, {}, {}
	while world.cinematic do
		local cin = world.cinematic
		local v = views(world)
		local frame = Director.cinematic({ cin = cin, tick = cin.tick, views = v, anchors = anchors,
			moveData = MoveData, config = Config, characters = CharacterData })
		if frame then
			shots[frame.shot.name] = true
			for _, problem in checkFrame(frame, v) do
				table.insert(failures, string.format("tick %d, shot %s: %s", cin.tick, frame.shot.name, problem))
			end
		end
		Sim.step(world, { Sim.neutralInput(), Sim.neutralInput() })
	end
	return failures, shots
end

local function report(name, failures)
	local lines = {}
	for i = 1, math.min(#failures, 6) do table.insert(lines, failures[i]) end
	expect(#failures == 0, name .. ": " .. #failures .. " bad frames\n         " .. table.concat(lines, "\n         "))
end

print("CinematicDirector")

for _, kit in MoveData.KitOrder do
	local routes = MoveData.Kits[kit].FullRoutes
	local cases = { { "Rush" }, { "Gate" }, { "Gate", nil, 300 }, { "Fatal" }, { "Fatal", nil, 300 }, { "Fatal", "raw" } }
	for _, route in routes do
		table.insert(cases, { "Awaken", route.name })
	end
	table.insert(cases, { "Awaken", routes[1].name, 300 })
	for _, case in cases do
		for _, center in { 0, Config.ArenaMaxX - 4, Config.ArenaMinX + 4 } do
			local name = string.format("%s %s%s%s at x=%d", kit, case[1], if case[2] then "/" .. case[2] else "",
				if case[3] then "/FINISH" else "", center)
			test(name .. ": every shot is well placed", function()
				local failures = playCinematic(case[1], case[2], case[3], center, kit)
				report(name, failures)
			end)
		end
	end
end

-- What a COUP FATAL shows: its shots, the title of its last tick, whether a K.O. scene followed.
local function fatalScene(kit, hp)
	local world = Sim.newWorld(Config, MoveData, true)
	Sim.setKits(world, kit, "KAI")
	world.phase = "Fight"
	world.fighters[1].x, world.fighters[2].x = -1.3, 1.3
	Sim.debugCinematic(world, 1, "Fatal", nil, hp)
	local anchors, shots, order, last, grades = {}, {}, {}, nil, {}
	while world.cinematic do
		local cin = world.cinematic
		local frame = Director.cinematic({ cin = cin, tick = cin.tick, views = views(world), anchors = anchors,
			moveData = MoveData, config = Config, characters = CharacterData })
		if frame then
			if not shots[frame.shot.name] then table.insert(order, frame.shot.name) end
			shots[frame.shot.name] = true
			for grade, on in frame.grade do if on then grades[grade] = true end end
			last = frame
		end
		Sim.step(world, { Sim.neutralInput(), Sim.neutralInput() })
	end
	return shots, order, last, grades, world
end

test("COUP FATAL: every kit has its own scene, which is its K.O. screen when it kills", function()
	local seen = {}
	for _, kit in MoveData.KitOrder do
		local shots, order, last, _, world = fatalScene(kit, 200)
		expect(#order >= 5, kit .. "'s COUP FATAL has only " .. #order .. " shots")
		for name in shots do
			expect(not name:find("^ko%-"), kit .. "'s COUP FATAL plays the generic K.O. scene (" .. name .. ")")
			expect(not seen[name], kit .. " borrows the shot " .. name .. " of " .. tostring(seen[name]))
			seen[name] = kit
		end
		expect(last and last.title and last.title.text == "K.O.", kit .. ": a killing COUP FATAL does not end on K.O.")
		expect(world.fighters[2].hp == 0, kit .. ": the target survived a COUP FATAL it should kill")
		local _, _, alive = fatalScene(kit, nil)
		local name = MoveData.Moves[MoveData.Kits[kit].Ultimates.Fatal].name
		expect(alive and alive.title and alive.title.text == name, kit .. ": a COUP FATAL that does not kill should end on its name")
	end
	-- SHIN's ISSEN is an old samurai film: black and white from the first frame to the last.
	local _, _, _, grades = fatalScene("SHIN", 200)
	expect(grades.mono, "SHIN's ISSEN is not in black and white")
end)

test("FINAL FINISH plays every shot of the K.O. storyboard", function()
	local _, shots = playCinematic("Awaken", "DRAGON", 150, 0) -- (no prompt pressed: 12 %, enough for 150 hp)
	for _, name in { "ko-fall", "ko-hand", "ko-scene1", "ko-feet", "ko-face", "ko-scene2", "ko-back", "ko-wide" } do
		expect(shots[name], "missing shot " .. name)
	end
end)

test("each kit's cinematics use its own moves", function()
	for _, kit in MoveData.KitOrder do
		local world = Sim.newWorld(Config, MoveData, true)
		Sim.setKits(world, kit, "KAI")
		world.phase = "Fight"
		Sim.debugCinematic(world, 1, "Awaken", MoveData.Kits[kit].FullRoutes[1].name, nil)
		local anchors = {}
		while world.cinematic do
			local cin = world.cinematic
			local v = views(world)
			Director.cinematic({ cin = cin, tick = cin.tick, views = v, anchors = anchors,
				moveData = MoveData, config = Config, characters = CharacterData })
			if v[1].state == "Attack" and v[1].move then
				expect(MoveData.MoveKit[v[1].move] == kit, kit .. " staged with " .. v[1].move)
			end
			Sim.step(world, { Sim.neutralInput(), Sim.neutralInput() })
		end
	end
end)

-- Every frame of one cinematic (name of each shot and the grades it used).
local function survey(kind, kit, style)
	local world = Sim.newWorld(Config, MoveData, true)
	Sim.setKits(world, kit, "KAI")
	world.phase = "Fight"
	Sim.debugCinematic(world, 1, kind, style, nil)
	local anchors, shots, frames, grades = {}, {}, 0, {}
	while world.cinematic do
		local cin = world.cinematic
		local frame = Director.cinematic({ cin = cin, tick = cin.tick, views = views(world), anchors = anchors,
			moveData = MoveData, config = Config, characters = CharacterData })
		if frame then
			frames += 1
			shots[frame.shot.name] = true
			for grade, on in frame.grade do
				if on then grades[grade] = (grades[grade] or 0) + 1 end
			end
		end
		Sim.step(world, { Sim.neutralInput(), Sim.neutralInput() })
	end
	return shots, frames, grades
end

test("every character's cinematics are its own: no shot shared between kits or ultimates", function()
	local owner = {}
	local SIGNATURE = { TARO = "fire", ZEPHYR = "sky", AKEMI = "shadow", RYUKEN = "rage", SHIN = "current", DAICHA = "inverse",
		HIBECARES = "ruin" }
	for _, kit in MoveData.KitOrder do
		for _, kind in { "Rush", "Awaken", "Gate" } do
			local shots, frames, grades = survey(kind, kit, MoveData.Kits[kit].FullRoutes[1].name)
			local own = 0
			for name in shots do
				local key = kit .. " " .. kind
				expect(not owner[name], string.format("%s reuses the shot %s of %s", key, name, tostring(owner[name])))
				owner[name] = key
				own += 1
			end
			expect(own >= 5, string.format("%s %s has only %d shots", kit, kind, own))
			local signature = SIGNATURE[kit]
			if signature then
				expect((grades[signature] or 0) >= frames * 0.8, string.format("%s %s: its %s grade is on %d of %d frames",
					kit, kind, signature, grades[signature] or 0, frames))
			end
			for other, grade in SIGNATURE do
				if other ~= kit then
					expect(not grades[grade], string.format("%s %s uses %s's %s grade", kit, kind, other, grade))
				end
			end
		end
	end
end)

test("each ÉVEIL route has its own finale", function()
	local seen = {}
	for _, route in MoveData.FullRoutes do
		local _, shots = playCinematic("Awaken", route.name, nil, 0)
		local own = {}
		for shotName in shots do
			if not shotName:find("^eveil") and not shotName:find("^ko") then table.insert(own, shotName) end
		end
		table.sort(own)
		local key = table.concat(own, ",")
		expect(#own > 0, route.name .. " has no finale shot")
		expect(not seen[key], route.name .. " reuses the finale of " .. tostring(seen[key]))
		seen[key] = route.name
	end
end)

test("match-winning K.O. scene is well placed for every kit, both winners and near the walls", function()
	for _, kit in MoveData.KitOrder do
	for _, winner in { 1, 2 } do
		for _, x in { 0, Config.ArenaMaxX - 2, Config.ArenaMinX + 2 } do
			local v = {
				{ x = x - 2, y = 0, facing = 1, state = "Idle", kit = kit },
				{ x = x + 2, y = 0, facing = -1, state = "Idle", kit = kit },
			}
			local anchors, failures = {}, {}
			for t = 0, Director.KO_SCENE do
				local staged = { table.clone(v[1]), table.clone(v[2]) }
				local frame = Director.ko({ anchors = anchors, moveData = MoveData, config = Config, characters = CharacterData },
					winner, 3 - winner, staged[winner], staged[3 - winner], t)
				for _, problem in checkFrame(frame, staged) do
					table.insert(failures, string.format("t %d, shot %s: %s", t, frame.shot.name, problem))
				end
			end
			report(string.format("%s K.O. scene winner %d at x=%d", kit, winner, x), failures)
		end
	end
	end
end)

test("each kit has its own K.O. scene: own shots, own grade, ends on K.O.", function()
	local owners, grades = {}, { KAI = nil, TARO = "fire", ZEPHYR = "sky", AKEMI = "shadow", RYUKEN = "rage", SHIN = "current",
		DAICHA = "inverse", HIBECARES = "ruin" }
	for _, kit in MoveData.KitOrder do
		local anchors, shots, graded, ended = {}, {}, false, false
		for t = 0, Director.KO_SCENE do
			local staged = { { x = -2, y = 0, facing = 1, state = "Idle", kit = kit }, { x = 2, y = 0, facing = -1, state = "Idle" } }
			local frame = Director.ko({ anchors = anchors, moveData = MoveData, config = Config, characters = CharacterData },
				1, 2, staged[1], staged[2], t)
			shots[frame.shot.name] = true
			if grades[kit] and frame.grade[grades[kit]] then graded = true end
			if frame.title and frame.title.text == "K.O." then ended = true end
		end
		expect(ended, kit .. ": the K.O. scene never shows K.O.")
		expect(grades[kit] == nil or graded, kit .. ": no " .. tostring(grades[kit]) .. " grade in its K.O. scene")
		local count = 0
		for name in shots do
			count += 1
			expect(owners[name] == nil, string.format("%s reuses %s's K.O. shot %s", kit, tostring(owners[name]), name))
			owners[name] = kit
		end
		expect(count >= 5, kit .. ": only " .. count .. " shots in its K.O. scene")
	end
end)

-- Plays one kit's rush (R) and sums up its staging: the effect kinds it asks for, how close
-- the attacker comes to the target before the final blow, how high the target goes, and on
-- how many blows the deck shakes.
local function rushStaging(kit)
	local world = Sim.newWorld(Config, MoveData, true)
	Sim.setKits(world, kit, "KAI")
	world.phase = "Fight"
	Sim.debugCinematic(world, 1, "Rush", nil, nil)
	local data = MoveData.Cinematics[MoveData.Kits[kit].Ultimates.Rush]
	local anchors, kinds, closest, highest, quakes = {}, {}, math.huge, 0, {}
	while world.cinematic do
		local cin = world.cinematic
		local v = views(world)
		local frame = Director.cinematic({ cin = cin, tick = cin.tick, views = v, anchors = anchors,
			moveData = MoveData, config = Config, characters = CharacterData })
		if frame then
			for _, fx in frame.fx do kinds[fx.kind] = true end
			if cin.tick < data.FinalTick then
				local a, d = v[1], v[2]
				closest = math.min(closest, math.sqrt((a.x - d.x) ^ 2 + ((a.z or 0) - (d.z or 0)) ^ 2))
				highest = math.max(highest, d.y)
			end
			if frame.quake then quakes[hitsBefore(data.Hits, cin.tick)] = true end
		end
		Sim.step(world, { Sim.neutralInput(), Sim.neutralInput() })
	end
	local shaken = 0
	for k in quakes do if k > 0 then shaken += 1 end end
	return { kinds = kinds, closest = closest, highest = highest, shaken = shaken }
end

test("the editing never strobes: no shot under 5 ticks, at most two under 9 ticks per cinematic", function()
	for _, kit in MoveData.KitOrder do
		local routes = if kit == "KAI" then MoveData.Kits.KAI.FullRoutes else { MoveData.Kits[kit].FullRoutes[1] }
		local cases = { { "Rush" }, { "Gate" }, { "Gate", nil, 300 } }
		for _, route in routes do
			table.insert(cases, { "Awaken", route.name })
			table.insert(cases, { "Awaken", route.name, 300 })
		end
		for _, case in cases do
			local world = Sim.newWorld(Config, MoveData, true)
			Sim.setKits(world, kit, "KAI")
			world.phase = "Fight"
			Sim.debugCinematic(world, 1, case[1], case[2], case[3])
			local anchors, last, since, short, shots = {}, nil, 0, 0, {}
			local name = string.format("%s %s%s%s", kit, case[1], if case[2] then "/" .. case[2] else "", if case[3] then "/FINISH" else "")
			while world.cinematic do
				local cin = world.cinematic
				local frame = Director.cinematic({ cin = cin, tick = cin.tick, views = views(world), anchors = anchors,
					moveData = MoveData, config = Config, characters = CharacterData })
				if frame and frame.shot.name ~= last then
					if last then table.insert(shots, { last, cin.tick - since }) end
					last, since = frame.shot.name, cin.tick
				end
				Sim.step(world, { Sim.neutralInput(), Sim.neutralInput() })
			end
			for _, s in shots do
				expect(s[2] >= 5, string.format("%s: the shot %s lasts %d ticks", name, s[1], s[2]))
				if s[2] < 9 then short += 1 end
			end
			expect(short <= 2, string.format("%s: %d shots under 9 ticks", name, short))
		end
	end
end)

test("clean staging: no body teleports inside a shot without its afterimages, no attacker glued to a standing target", function()
	for _, kit in MoveData.KitOrder do
		for _, kind in { "Rush", "Awaken", "Gate" } do
			local world = Sim.newWorld(Config, MoveData, true)
			Sim.setKits(world, kit, "KAI")
			world.phase = "Fight"
			Sim.debugCinematic(world, 1, kind, MoveData.Kits[kit].FullRoutes[1].name, nil)
			local anchors, last = {}, {}
			while world.cinematic do
				local cin = world.cinematic
				local v = views(world)
				local frame = Director.cinematic({ cin = cin, tick = cin.tick, views = v, anchors = anchors,
					moveData = MoveData, config = Config, characters = CharacterData })
				if frame then
					for slot = 1, 2 do
						local p = last[slot]
						local view = v[slot]
						if p and p.shot == frame.shot.name and view.y < 50 and p.y < 50 then
							local step = math.sqrt((view.x - p.x) ^ 2 + (view.y - p.y) ^ 2 + ((view.z or 0) - p.z) ^ 2)
							expect(step <= 0.9 or view.ghost, string.format("%s %s tick %d: fighter %d jumps %.1f studs in %s",
								kit, kind, cin.tick, slot, step, frame.shot.name))
						end
						last[slot] = { x = view.x, y = view.y, z = view.z or 0, shot = frame.shot.name }
					end
					local a, d = v[cin.attacker], v[cin.defender]
					local function standing(x)
						return x.y < 0.8 and x.pose ~= "Launched" and x.pose ~= "DownFace" and x.state ~= "Knockdown" and x.state ~= "KO"
							and x.state ~= "Launched"
					end
					if standing(a) and standing(d) and not a.ghost then
						local gap = math.sqrt((a.x - d.x) ^ 2 + ((a.z or 0) - (d.z or 0)) ^ 2)
						expect(gap >= 2.79 or gap < 0.06, string.format("%s %s tick %d: the attacker is %.2f studs from the target", kit, kind,
							cin.tick, gap))
					end
				end
				Sim.step(world, { Sim.neutralInput(), Sim.neutralInput() })
			end
		end
	end
end)

test("no shot is a still: the camera drifts and pushes in for as long as a shot lasts", function()
	local world = Sim.newWorld(Config, MoveData, true)
	Sim.setKits(world, "RYUKEN", "KAI")
	world.phase = "Fight"
	Sim.debugCinematic(world, 1, "Gate", nil, 300)
	local anchors, first, moved = {}, {}, 0
	while world.cinematic do
		local cin = world.cinematic
		local v = views(world)
		local frame = Director.cinematic({ cin = cin, tick = cin.tick, views = v, anchors = anchors,
			moveData = MoveData, config = Config, characters = CharacterData })
		local s = frame and frame.shot
		if s and s.from.position then
			local seen = first[s.name]
			if not seen then
				first[s.name] = { tick = cin.tick, at = s.from.position }
			elseif cin.tick - seen.tick == 20 then
				local p, q = seen.at, s.from.position
				if math.abs(p.x - q.x) + math.abs(p.y - q.y) + math.abs((p.z or 0) - (q.z or 0)) > 0.05 then moved += 1 end
			end
		end
		Sim.step(world, { Sim.neutralInput(), Sim.neutralInput() })
	end
	expect(moved >= 4, string.format("only %d shots move", moved))
end)

test("every rush (R) is staged its own way: own effects, own way of fighting", function()
	-- Each kit's rush asks for effects only it uses.
	local SIGNATURE = { KAI = { "kiBeam" }, TARO = { "ropes" }, ZEPHYR = { "windBlade" }, AKEMI = { "afterimage" },
		RYUKEN = { "rageFist" }, SHIN = { "wake", "waterspout" }, DAICHA = { "orbs", "orbDart" }, HIBECARES = { "rockLine" } }
	local staging = {}
	for _, kit in MoveData.KitOrder do staging[kit] = rushStaging(kit) end
	for kit, kinds in SIGNATURE do
		for _, kind in kinds do
			expect(staging[kit].kinds[kind], kit .. "'s rush never shows its " .. kind)
			for other in staging do
				if other ~= kit then expect(not staging[other].kinds[kind], other .. "'s rush borrows " .. kit .. "'s " .. kind) end
			end
		end
	end
	-- DAICHA never touches the target: his orbs do; RYUKEN juggles it up high; every step
	-- of HIBECARES shakes the deck.
	expect(staging.DAICHA.closest >= 4, string.format("DAICHA comes %.1f studs from the target", staging.DAICHA.closest))
	for kit, s in staging do
		expect(s.closest >= 1.2, string.format("%s's rush walks through the target (%.1f studs)", kit, s.closest))
	end
	expect(staging.RYUKEN.highest >= 6, string.format("RYUKEN only lifts the target %.1f studs", staging.RYUKEN.highest))
	-- KAI chases it high into the sky; ZEPHYR stays away until his last kick.
	expect(staging.KAI.highest >= 10, string.format("KAI only takes the target %.1f studs up", staging.KAI.highest))
	expect(staging.ZEPHYR.closest >= 3, string.format("ZEPHYR comes %.1f studs from the target", staging.ZEPHYR.closest))
	expect(staging.HIBECARES.shaken >= 8, string.format("the deck shakes on only %d of HIBECARES' blows", staging.HIBECARES.shaken))
end)

T.finish()
