-- Offline tests for the authoritative simulation. Run from the repository root:
--   luau tests/CombatSimulation.test.luau
local Config = require("../src/shared/CombatConfig")
local MoveData = require("../src/shared/MoveData")
local Sim = require("../src/shared/CombatSimulation")
local T = require("./TestKit")

local test, expect, input = T.test, T.expect, T.input
local Moves = MoveData.Moves

local function closeWorld(gap, training)
	local world = Sim.newWorld(Config, MoveData, if training == nil then true else training)
	world.phase = "Fight"
	world.fighters[1].x, world.fighters[2].x = -gap / 2, gap / 2
	return world
end

local function run(world, ticks, inputs)
	local all = {}
	for t = 1, ticks do
		local i = if type(inputs) == "function" then inputs(t) else inputs
		local events = Sim.step(world, { (i and i[1]) or Sim.neutralInput(), (i and i[2]) or Sim.neutralInput() })
		for _, e in events do
			e.tick = t
			table.insert(all, e)
		end
	end
	return all
end

local function count(events, kind)
	local n = 0
	for _, e in events do if e.kind == kind then n += 1 end end
	return n
end

local function find(events, kind)
	for _, e in events do if e.kind == kind then return e end end
	return nil
end

-- Mash a sequence of buttons (L, R, E = special, U = ultimate), one press every `every` ticks.
local function mash(sequence, every, extra)
	local presses = {}
	local t = 1
	for _, button in sequence do
		presses[t] = button
		t += every
	end
	return function(tick)
		local i = input(extra)
		local b = presses[tick]
		if b == "L" then i.light = true
		elseif b == "R" then i.heavy = true
		elseif b == "E" then i.special = true
		elseif b == "U" then i.ultimate = true end
		return { i }
	end
end

local function hitMoves(events)
	local moves = {}
	for _, e in events do
		if e.kind == "Hit" and not e.cinematic then table.insert(moves, e.move) end
	end
	return table.concat(moves, ",")
end

print("CombatSimulation")

test("jab hits once, on the first active tick", function()
	local world = closeWorld(3)
	local events = run(world, 40, function(t) return { input({ light = t == 1 }) } end)
	expect(count(events, "Hit") == 1, "expected exactly one hit, got " .. count(events, "Hit"))
	expect(events[1].tick == Moves.Jab.startup + 1, "hit on tick " .. events[1].tick)
	expect(world.fighters[2].hp == Config.MaxHealth - Moves.Jab.damage, "damage " .. world.fighters[2].hp)
end)

test("hitstop freezes the move frame counter", function()
	local world = closeWorld(3)
	run(world, Moves.Jab.startup + 1, function(t) return { input({ light = t == 1 }) } end)
	local a = world.fighters[1]
	local frame = a.moveFrame
	expect(a.hitstop == Moves.Jab.hitstop, "hitstop " .. a.hitstop)
	run(world, a.hitstop)
	expect(a.moveFrame == frame, "frame advanced during hitstop")
	run(world, 1)
	expect(a.moveFrame == frame + 1, "frame did not resume")
end)

test("holding block reduces damage and spends guard", function()
	local world = closeWorld(3)
	local events = run(world, 40, function(t) return { input({ light = t == 1 }), input({ block = true }) } end)
	expect(count(events, "Block") == 1 and count(events, "Hit") == 0, "expected a block")
	local chip = math.floor(Moves.Jab.damage * Config.BlockDamageRatio + 0.5)
	expect(world.fighters[2].hp == Config.MaxHealth - chip, "blocked damage " .. world.fighters[2].hp)
	expect(world.fighters[2].guard < Config.MaxGuard, "guard not spent")
end)

test("blocked hits never KO", function()
	local world = closeWorld(3, false)
	world.fighters[2].hp = 5
	run(world, 60, function(t) return { input({ heavy = t == 1 }), input({ block = true }) } end)
	expect(world.fighters[2].hp == 1 and world.phase == "Fight", "chip damage killed")
end)

test("air kick cannot be crouch-blocked", function()
	local world = closeWorld(3)
	local events = run(world, 80, function(t)
		return { input({ jump = t == 1, light = t == 32 }), input({ block = true, crouch = true }) }
	end)
	expect(hitMoves(events) == "AirKick", "crouch block stopped an overhead: " .. hitMoves(events))
end)

test("sweep is low: standing guard fails, crouching guard holds", function()
	local standing = closeWorld(3)
	local e1 = run(standing, 60, mash({ "R", "L" }, 6))
	expect(hitMoves(e1) == "Smash,Sweep", "route was " .. hitMoves(e1))
	local guarded = closeWorld(3)
	local e2 = run(guarded, 60, function(t)
		local i = mash({ "R", "L" }, 6)(t)
		return { i[1], input({ block = true, crouch = t > 14 }) }
	end)
	expect(count(e2, "Block") == 2, "crouch guard did not hold the sweep")
end)

test("route L L L L: chain ends in a knockdown", function()
	local world = closeWorld(3)
	local events = run(world, 160, mash({ "L", "L", "L", "L", "L", "L", "L", "L" }, 6))
	expect(hitMoves(events) == "Jab,Cross,Elbow,Kick", "route was " .. hitMoves(events))
	local d = world.fighters[2]
	expect(d.knockdown > 0 or d.getUp > 0 or d.state == "Idle", "no knockdown")
	expect(Config.MaxHealth - d.hp < 45 + 55 + 60 + 80, "damage scaling not applied")
end)

test("route L R: body blow crumples, a new combo connects", function()
	local world = closeWorld(3)
	-- After the crumple, wait for recovery like a player would, then start a fresh combo.
	local presses = { [1] = "L", [7] = "R", [64] = "L", [70] = "L", [76] = "L" }
	local events = run(world, 110, function(t)
		local p = presses[t]
		return { input({ light = p == "L", heavy = p == "R" }) }
	end)
	local route = hitMoves(events)
	expect(route:sub(1, 12) == "Jab,BodyBlow", "route was " .. route)
	expect(#route > #"Jab,BodyBlow", "nothing connected after the crumple: " .. route)
	local last = events[#events]
	expect(last.combo and last.combo >= 3, "combo dropped after crumple")
end)

test("route L L R then jump: launcher into an air chain", function()
	local world = closeWorld(3)
	local presses = { [1] = "L", [7] = "L", [13] = "R" }
	local launchedAt
	local events = run(world, 160, function(t)
		local i = input()
		local p = presses[t]
		if p == "L" then i.light = true elseif p == "R" then i.heavy = true end
		local a = world.fighters[1]
		if a.move == "Uppercut" and a.moveContact == "Hit" and not launchedAt then launchedAt = t end
		if launchedAt then
			local dt = t - launchedAt
			if dt == 16 then i.jump = true end
			if dt == 24 or dt == 30 or dt == 36 then i.light = true end
			if dt == 44 or dt == 50 then i.heavy = true end
		end
		return { i }
	end)
	local route = hitMoves(events)
	expect(count(events, "SuperJump") == 1, "no jump cancel")
	expect(route:find("Jab,Cross,Uppercut,AirKick", 1, true) == 1, "route was " .. route)
end)

test("route L L L R: spin kick wall-bounces in the corner", function()
	local world = closeWorld(3)
	world.fighters[1].x, world.fighters[2].x = Config.ArenaMaxX - 9, Config.ArenaMaxX - 6
	local events = run(world, 120, mash({ "L", "L", "L", "R", "R", "R" }, 6))
	expect(hitMoves(events) == "Jab,Cross,Elbow,SpinKick", "route was " .. hitMoves(events))
	expect(count(events, "WallBounce") == 1, "no wall bounce")
end)

test("route R R: axe kick ground-bounces", function()
	local world = closeWorld(3)
	local events = run(world, 120, mash({ "R", "R", "R" }, 8))
	expect(hitMoves(events) == "Smash,Hammer", "route was " .. hitMoves(events))
	local hammer
	for _, e in events do if e.move == "Hammer" and e.kind == "Hit" then hammer = e end end
	expect(hammer and hammer.bounce, "no ground bounce")
end)

test("crouching L starts a low kick that chains into the standing route", function()
	local world = closeWorld(3)
	local events = run(world, 60, function(t)
		return { input({ crouch = t <= 2, light = t == 1 or t == 7 or t == 13 }) }
	end)
	expect(hitMoves(events):sub(1, 13) == "LowKick,Cross", "route was " .. hitMoves(events))
end)

test("special E cancels a normal and is invincible at startup", function()
	local world = closeWorld(3)
	local events = run(world, 80, mash({ "L", "E", "E" }, 6))
	expect(hitMoves(events) == "Jab,Rising", "route was " .. hitMoves(events))
	local reversal = closeWorld(3)
	local e2 = run(reversal, 40, function(t) return { input({ light = t == 1 }), input({ special = t == 2 }) } end)
	expect(hitMoves(e2) == "Rising", "jab beat the invincible special: " .. hitMoves(e2))
end)

-- Plays a route like a player: the next button is pressed once the current move connects.
local function playRoute(world, keys, ticks)
	local events, step, pressedFor = {}, 1, nil
	for _ = 1, ticks or 400 do
		local a = world.fighters[1]
		local i = input()
		local key = a.move and (a.move .. tostring(a.moveContact ~= nil))
		local ready = step == 1 or (a.move and a.moveContact and key ~= pressedFor
			and a.moveHits >= (Moves[a.move].hits or 1))
		if keys[step] and ready then
			if keys[step] == "L" then i.light = true else i.heavy = true end
			pressedFor = key
			step += 1
		end
		for _, e in Sim.step(world, { i, Sim.neutralInput() }) do table.insert(events, e) end
	end
	return events
end

local function compactRoute(events)
	local list = {}
	for _, e in events do
		if e.kind == "Hit" and not e.cinematic and list[#list] ~= e.move then table.insert(list, e.move) end
	end
	return table.concat(list, ",")
end

local function skillTest(name, sequence, expectedRoute)
	test(name, function()
		local world = closeWorld(3)
		local events = playRoute(world, sequence, 300)
		expect(compactRoute(events) == expectedRoute, "route was " .. compactRoute(events))
		local skill = find(events, "Skill")
		expect(skill ~= nil, "no skill announced")
	end)
end

skillTest("skill L R L R: TORNADE DU DRAGON (multi-hit launcher)", { "L", "R", "L", "R" },
	"Jab,BodyBlow,PalmStrike,DragonTornado")
skillTest("skill R L R L: RAFALE DE KI", { "R", "L", "R", "L" },
	"Smash,Sweep,RisingWind,KiFlurry")
skillTest("skill L L R R: POING DU DRAGON", { "L", "L", "R", "R" },
	"Jab,Cross,Uppercut,DragonFist")
skillTest("skill R R L R: TALON FOUDRE into POING DU DRAGON", { "R", "R", "L", "R" },
	"Smash,Hammer,ThunderHeel,DragonFist")
skillTest("skill L L L L R: CROISSANT DE LUNE", { "L", "L", "L", "L", "R" },
	"Jab,Cross,Elbow,Kick,CrescentMoon")

test("multi-hit skills hit several times, once per interval", function()
	local world = closeWorld(3)
	local events = playRoute(world, { "L", "R", "L", "R" }, 300)
	local tornado = 0
	for _, e in events do
		if e.kind == "Hit" and e.move == "DragonTornado" then tornado += 1 end
	end
	expect(tornado == Moves.DragonTornado.hits, "tornado hit " .. tornado .. " times")
	expect(world.fighters[2].juggle <= Config.MaxJuggleHits, "juggle counted per hit")
end)

test("crouch + E fires a ki blast that travels and hits at range", function()
	local world = closeWorld(14)
	local events = run(world, 90, function(t) return { input({ crouch = t <= 2, special = t == 1 }) } end)
	expect(count(events, "Projectile") == 1, "no ki blast")
	expect(hitMoves(events) == "KiBlast", "ki blast did not hit: " .. hitMoves(events))
	expect(#world.projectiles == 0, "projectile not removed after the hit")
end)

test("only one ki blast on screen per fighter, and blasts can be guarded", function()
	local world = closeWorld(30)
	local events = run(world, 120, function(t)
		return { input({ crouch = true, special = t % 30 == 1 }), input({ block = true }) }
	end)
	expect(count(events, "Projectile") <= 2, "too many blasts")
	expect(count(events, "Block") >= 1 and count(events, "Hit") == 0, "blast not blocked")
end)

test("opposing ki blasts clash", function()
	local world = closeWorld(20)
	local events = run(world, 80, function(t)
		local i = input({ crouch = true, special = t == 1 })
		return { i, input({ crouch = true, special = t == 1 }) }
	end)
	expect(count(events, "Clash") == 1 and count(events, "Hit") == 0, "blasts did not clash")
end)

for _, route in MoveData.FullRoutes do
	test("6-press route " .. route.keys .. " (" .. route.name .. ") ends in COUP DE GRÂCE", function()
		local world = closeWorld(3)
		local keys = {}
		for k in route.keys:gmatch("%S") do table.insert(keys, k) end
		local events = playRoute(world, keys)
		expect(compactRoute(events) == table.concat(route.moves, ","), "route was " .. compactRoute(events))
	end)
end

-- Plays a full route cleanly (one press per link, after its hits) and keeps the meter full
-- until the 6th press; `mash` adds a spam press in the middle of the route.
local function playEarned(world, keys, options)
	options = options or {}
	local events, step, pressedFor, hpAtStart = {}, 1, nil, nil
	for t = 1, options.ticks or 900 do
		local a = world.fighters[1]
		local i = input()
		local key = a.move and (a.move .. tostring(a.moveContact ~= nil))
		local ready = step == 1 or (a.move and a.moveContact and key ~= pressedFor
			and a.moveHits >= (Moves[a.move].hits or 1))
		if keys[step] and ready then
			local k = keys[step]
			if k == "L" then i.light = true elseif k == "R" then i.heavy = true else i.ultimate = true end
			pressedFor = key
			step += 1
		elseif options.mash and step == 3 and t % 3 == 0 then
			i.light = true -- spam in the middle of the route
		end
		if step <= #keys and options.meter ~= false then a.meter = Config.MaxMeter end
		if world.cinematic and options.prompts then
			local state = world.cinematic
			local prompt = state.prompts[state.nextPrompt]
			if prompt and state.tick + 1 == prompt.tick + (options.offset or 0) then
				if prompt.button == "Light" then i.light = true
				elseif prompt.button == "Heavy" then i.heavy = true else i.ultimate = true end
			end
		end
		for _, e in Sim.step(world, { i, Sim.neutralInput() }) do
			table.insert(events, e)
			if e.kind == "CinematicStart" then hpAtStart = world.fighters[2].hp end
		end
	end
	return events, hpAtStart
end

local function routeKeys(route, last)
	local keys = {}
	for k in route.keys:gmatch("%S") do table.insert(keys, k) end
	keys[6] = last
	return keys
end

for _, route in MoveData.FullRoutes do
	test("ÉVEIL ÉCARLATE earned on " .. route.name .. ": clean route ending on the right click, 3 bars", function()
		local world = closeWorld(3, false)
		local events, hpAtStart = playEarned(world, routeKeys(route, "R"))
		local start = find(events, "CinematicStart")
		expect(start and start.move == "Awakening", "no awakening (" .. compactRoute(events) .. ")")
		expect(start.style == route.name, "style " .. tostring(start.style))
		local expected = hpAtStart - math.floor(hpAtStart * MoveData.Cinematics.Awakening.HealthRatio)
		expect(world.fighters[2].hp == expected, string.format("hp %d, expected %d", world.fighters[2].hp, expected))
		expect(find(events, "RoundEnd") == nil, "awakening killed a healthy target")
	end)
end

for _, route in MoveData.FullRoutes do
	test("PORTE DES CIEUX earned on " .. route.name .. ": clean route ending on the R key, 3 bars", function()
		local world = closeWorld(3, false)
		local events, hpAtStart = playEarned(world, routeKeys(route, "U"))
		local start = find(events, "CinematicStart")
		expect(start and start.move == "Kaiten", "no gate (" .. compactRoute(events) .. ")")
		local expected = hpAtStart - math.floor(Config.MaxHealth * MoveData.Cinematics.Kaiten.MaxHealthShare)
		expect(world.fighters[2].hp == expected, string.format("hp %d, expected %d", world.fighters[2].hp, expected))
	end)
end

test("PORTE DES CIEUX: the R key on the climax adds the bonus, and can KO", function()
	local world = closeWorld(3, false)
	world.fighters[2].hp = 900
	local events, hpAtStart = playEarned(world, routeKeys(MoveData.FullRoutes[3], "U"), { prompts = true, ticks = 1200 })
	local grade = find(events, "PromptGrade")
	expect(grade and grade.grade == "PARFAIT", "gate prompt " .. tostring(grade and grade.grade))
	local cin = MoveData.Cinematics.Kaiten
	local expected = math.floor(Config.MaxHealth * cin.MaxHealthShare) + math.floor(Config.MaxHealth * cin.PerfectBonus)
	local dealt = 0
	for _, e in events do
		if e.kind == "Hit" and e.cinematic and e.move == "Kaiten" then dealt += e.damage end
	end
	expect(dealt == expected, string.format("dealt %d, expected %d (hp at start %d)", dealt, expected, hpAtStart))
	local low = closeWorld(3, false)
	low.fighters[2].hp = 700
	local lowEvents = playEarned(low, routeKeys(MoveData.FullRoutes[3], "U"), { ticks = 1200 })
	local start = find(lowEvents, "CinematicStart")
	expect(start and start.finish and find(lowEvents, "RoundEnd"), "gate did not KO a weakened target")
end)

test("gate: a perfect gate only KOs if the blows left can finish (every kit)", function()
	for _, kitName in MoveData.KitOrder do
		local cin = MoveData.Cinematics[MoveData.Kits[kitName].Ultimates.Gate]
		local function play(hp)
			local world = Sim.newWorld(Config, MoveData, false)
			Sim.setKits(world, kitName, "KAI")
			world.phase = "Fight"
			local d = world.fighters[2]
			Sim.debugCinematic(world, 1, "Gate", nil, hp)
			local events = {}
			for _ = 1, math.ceil((cin.Length + cin.FinishExtra) / Config.CinematicTimeScale) + 40 do
				local state = world.cinematic
				local press = state ~= nil and state.tick + 1 == cin.PromptTicks[1]
				for _, e in Sim.step(world, { input({ ultimate = press }), input({}) }) do table.insert(events, e) end
			end
			local grade = find(events, "PromptGrade")
			expect(grade and grade.grade == "PARFAIT", kitName .. ": gate prompt " .. tostring(grade and grade.grade))
			return d.hp, events
		end
		local maxHp = MoveData.Kits.KAI.Stats.MaxHealth
		local full = math.floor(maxHp * cin.MaxHealthShare) + math.floor(maxHp * cin.PerfectBonus)
		local left = play(full + 25)
		expect(left == 25, string.format("%s: %d hp left instead of 25 (gate total %d)", kitName, left, full))
		local _, events = play(full - 10)
		expect(find(events, "RoundEnd"), kitName .. ": a perfect gate did not KO a target it out-damages")
	end
end)

test("KAIEN RUSH (R alone) stays the classic ultimate", function()
	local world = closeWorld(3, false)
	world.fighters[1].meter = Config.MaxMeter
	local events = run(world, 200, function(t) return { input({ ultimate = t == 1 }) } end)
	local start = find(events, "CinematicStart")
	expect(start and start.move == "KaienRush", "R alone did not play KAIEN RUSH")
end)

test("spamming during the route locks ÉVEIL ÉCARLATE (KAIEN RUSH instead)", function()
	local world = closeWorld(3, false)
	for _, last in { "R", "U" } do
		local world = closeWorld(3, false)
		local events = playEarned(world, routeKeys(MoveData.FullRoutes[1], last), { mash = true })
		local start = find(events, "CinematicStart")
		expect(not start or (start.move ~= "Awakening" and start.move ~= "Kaiten"), "earned ultimate despite mashing")
	end
end)

test("below 50 %: ÉVEIL ÉCARLATE is a FINAL FINISH (KO after the cinematic)", function()
	local world = closeWorld(3, false)
	world.fighters[2].hp = 480
	local events = playEarned(world, routeKeys(MoveData.FullRoutes[1], "R"), { ticks = 1100 })
	local start, finish, roundEnd = find(events, "CinematicStart"), find(events, "CinematicEnd"), find(events, "RoundEnd")
	expect(start and start.finish, "no FINAL FINISH")
	expect(roundEnd and roundEnd.winner == 1, "no KO")
	expect(finish and finish.finish, "cinematic end not flagged as finish")
end)

test("rhythm prompts: all on time is PARFAIT and gives a ki bar back", function()
	local world = closeWorld(3, false)
	local events = playEarned(world, routeKeys(MoveData.FullRoutes[2], "R"), { prompts = true })
	local grade = find(events, "PromptGrade")
	expect(grade and grade.grade == "PARFAIT", "grade " .. tostring(grade and grade.grade))
	expect(world.fighters[1].meter >= MoveData.Cinematics.Awakening.PerfectRefund, "no ki refund")
end)

test("rhythm prompts: mashing fails them", function()
	local world = closeWorld(3, false)
	local events = {}
	local keys = routeKeys(MoveData.FullRoutes[1], "R")
	local step, pressedFor = 1, nil
	for t = 1, 900 do
		local a = world.fighters[1]
		local i = input()
		local key = a.move and (a.move .. tostring(a.moveContact ~= nil))
		if keys[step] and (step == 1 or (a.move and a.moveContact and key ~= pressedFor
			and a.moveHits >= (Moves[a.move].hits or 1))) then
			local k = keys[step]
			if k == "L" then i.light = true elseif k == "R" then i.heavy = true else i.ultimate = true end
			pressedFor = key
			step += 1
		end
		if step <= 6 then a.meter = Config.MaxMeter end
		if world.cinematic then i.light, i.heavy = t % 2 == 0, t % 2 == 1 end
		for _, e in Sim.step(world, { i, Sim.neutralInput() }) do table.insert(events, e) end
	end
	local grade = find(events, "PromptGrade")
	expect(grade and grade.grade == "BON", "mashing graded " .. tostring(grade and grade.grade))
end)

test("6th press without 3 bars stays COUP DE GRÂCE", function()
	local world = closeWorld(3)
	world.fighters[1].meter = 0 -- the combo itself fills about half the meter
	local events = playRoute(world, { "L", "R", "L", "R", "L", "R" })
	expect(find(events, "CinematicStart") == nil, "unique attack without 3 bars")
end)

test("late press: a link pressed just after the move ended still continues the combo", function()
	local world = closeWorld(3)
	local a = world.fighters[1]
	local jabEnd
	local pressedAt
	local events = run(world, 80, function(t)
		local i = input({ light = t == 1 })
		if not jabEnd and t > 2 and a.move == nil then jabEnd = t end
		if jabEnd and not pressedAt and t == jabEnd + Config.LateCancelTicks - 2 then
			pressedAt = t
			i.light = true
		end
		return { i }
	end)
	expect(compactRoute(events) == "Jab,Cross", "late link was " .. compactRoute(events))
	expect(a.chainKeys == "LL", "chain keys " .. a.chainKeys)
end)

test("typing a whole route ahead loses presses: the route stops and earns nothing", function()
	local world = closeWorld(3, false)
	local a = world.fighters[1]
	a.meter = Config.MaxMeter
	local keys = { "L", "R", "L", "R", "L", "R" }
	local events = run(world, 600, function(t)
		local k = keys[t] -- one press per tick, the six presses before the first hit even lands
		return { input({ light = k == "L", heavy = k == "R" }) }
	end)
	local start = find(events, "CinematicStart")
	expect(start == nil, "typing ahead earned " .. tostring(start and start.move))
	expect(#compactRoute(events):split(",") < 6, "the whole route played from presses typed ahead")
end)

test("rhythm: a link typed before the attack is out still links, but is not clean", function()
	local world = closeWorld(3)
	local a = world.fighters[1]
	-- R pressed on the 3rd startup frame of the JAB (its fist is not out yet).
	local events = run(world, 70, function(t) return { input({ light = t == 1, heavy = t == 3 }) } end)
	expect(compactRoute(events) == "Jab,BodyBlow", "early link dropped: " .. compactRoute(events))
	expect(not a.chainClean and a.dirtyReason == "TROP TÔT", "early link judged clean")
	-- The same R pressed once the jab is out: clean.
	local good = closeWorld(3)
	run(good, 70, function(t) return { input({ light = t == 1, heavy = t == Moves.Jab.startup + 2 }) } end)
	expect(good.fighters[1].chainClean and good.fighters[1].chainKeys == "LR", "a link on rhythm was judged dirty")
end)

test("rhythm: a press made too long before the hit expires", function()
	local world = closeWorld(3)
	-- FRAPPE LOURDE has a long wind-up: R right after it starts is lost before the hit lands.
	local events = run(world, 90, function(t) return { input({ heavy = t == 1 or t == 2 }) } end)
	expect(compactRoute(events) == "Smash", "a press far ahead still linked: " .. compactRoute(events))
end)

test("changing your mind: a press during a whiffed attack does not fire afterwards", function()
	local world = closeWorld(14) -- out of range: the jab whiffs
	local a = world.fighters[1]
	local jabs = 0
	run(world, 60, function(t)
		if a.move == "Jab" and a.moveFrame == 1 then jabs += 1 end
		return { input({ light = t == 1 or t == 8 }) }
	end)
	expect(jabs == 1, "a press made during the whiff started another attack (" .. jabs .. " jabs)")
end)

test("changing your mind: guard, jump or dash drops the queued attacks", function()
	-- L at the very end of a whiffed jab is a deliberate press: it fires a second jab...
	local function jabs(field)
		local world = closeWorld(14)
		local a = world.fighters[1]
		local count = 0
		run(world, 60, function(t)
			if a.move == "Jab" and a.moveFrame == 1 then count += 1 end
			local i = input({ light = t == 1 or t == 15 })
			if field and t == 16 then i[field] = true end
			return { i }
		end)
		return count
	end
	expect(jabs(nil) == 2, "control: the late press did not fire")
	-- ...unless guard, jump or dash comes right after it.
	for _, field in { "block", "jump", "dash" } do
		expect(jabs(field) == 1, field .. " did not cancel the queued jab")
	end
end)

test("hitting every button at once is spam: earned ultimates locked", function()
	local world = closeWorld(3, false)
	local a = world.fighters[1]
	a.meter = Config.MaxMeter
	local keys = { "L", "R", "L", "R", "L", "R" }
	local events = run(world, 600, function(t)
		local k = keys[t]
		return { input({ light = k == "L" or t == 3, heavy = k == "R" or t == 3, special = t == 3 }) }
	end)
	local start = find(events, "CinematicStart")
	expect(not start or (start.move ~= "Awakening" and start.move ~= "Kaiten"), "spam earned an ultimate")
end)

test("a wrong button during the route makes it dirty", function()
	local world = closeWorld(3)
	local a = world.fighters[1]
	-- JAB then R (COUP AU FOIE) is a valid link: the route stays clean.
	run(world, 60, function(t) return { input({ light = t == 1, heavy = t == 1 + Moves.Jab.startup + 2 }) } end)
	expect(a.chainKeys:sub(1, 2) == "LR" and a.chainClean, "a valid link was judged dirty")
	local wrong = closeWorld(3)
	run(wrong, 60, function(t)
		-- After L R (COUP AU FOIE), R again is not a link of the BodyBlow: wrong button.
		return { input({ light = t == 1, heavy = t == 9 or t == 30 }) }
	end)
	expect(not wrong.fighters[1].chainClean, "a wrong button was judged clean")
end)

test("full routes survive slow reactions (latency) and different starting distances", function()
	for _, reaction in { 4, 10, 16 } do
		for _, gap in { 3, 4.4 } do
			for _, route in MoveData.FullRoutes do
				local world = closeWorld(gap)
				local keys = {}
				for k in route.keys:gmatch("%S") do table.insert(keys, k) end
				local step, pressedFor, waited = 1, nil, 0
				local events = {}
				for _ = 1, 500 do
					local a = world.fighters[1]
					local i = input()
					local key = a.move and (a.move .. tostring(a.moveContact ~= nil))
					if keys[step] and (step == 1 or (a.move and a.moveContact and key ~= pressedFor
						and a.moveHits >= (Moves[a.move].hits or 1))) then
						waited += 1
						if waited > reaction then
							if keys[step] == "L" then i.light = true else i.heavy = true end
							pressedFor, step, waited = key, step + 1, 0
						end
					end
					for _, e in Sim.step(world, { i, Sim.neutralInput() }) do table.insert(events, e) end
				end
				expect(compactRoute(events) == table.concat(route.moves, ","),
					string.format("%s dropped (reaction %d, gap %.1f): %s", route.name, reaction, gap, compactRoute(events)))
			end
		end
	end
end)

test("mashing while being hit does not attack on recovery", function()
	local world = closeWorld(3)
	local d = world.fighters[2]
	local attacked = false
	for t = 1, 60 do
		local mash = d.stun > Config.ReversalBufferTicks and t % 2 == 0
		Sim.step(world, { input({ light = t == 1 }), input({ light = mash, heavy = mash }) })
		if d.move then attacked = true end
	end
	expect(not attacked, "the hit fighter attacked on its own after recovering")
end)

test("a press in the last ticks of hitstun is a deliberate reversal", function()
	local world = closeWorld(3)
	local d = world.fighters[2]
	local pressed, reversal = false, false
	for t = 1, 60 do
		local press = not pressed and t > 8 and d.stun > 0 and d.stun <= Config.ReversalBufferTicks
		if press then pressed = true end
		Sim.step(world, { input({ light = t == 1 }), input({ special = press }) })
		if d.move == "Rising" then reversal = true end
	end
	expect(pressed and reversal, "reversal press was ignored")
end)

test("holding guard while recovering wins over a buffered attack", function()
	local world = closeWorld(3)
	local d = world.fighters[2]
	local attacked = false
	for t = 1, 60 do
		local press = d.stun > 0 and d.stun <= Config.ReversalBufferTicks
		Sim.step(world, { input({ light = t == 1 }), input({ light = press, block = d.stun <= Config.ReversalBufferTicks }) })
		if d.move then attacked = true end
	end
	expect(not attacked, "attack came out despite holding guard")
end)

test("training lab: every cinematic can be played directly", function()
	local cases = {
		{ "KaienRush" }, { "Kaiten" }, { "Kaiten", nil, 300 },
	}
	for _, route in MoveData.FullRoutes do
		table.insert(cases, { "Awakening", route.name })
		table.insert(cases, { "Awakening", route.name, 300 })
	end
	for _, case in cases do
		local world = closeWorld(10)
		local events = Sim.debugCinematic(world, 1, case[1], case[2], case[3])
		local start = find(events, "CinematicStart")
		expect(start and start.move == case[1] and start.style == case[2], "debug " .. case[1] .. " did not start")
		expect(start.finish == (case[3] ~= nil), "finish flag for " .. case[1] .. " " .. tostring(case[3]))
		local ended = false
		for _ = 1, 900 do
			for _, e in Sim.step(world, { Sim.neutralInput(), Sim.neutralInput() }) do
				if e.kind == "CinematicEnd" then ended = true end
			end
		end
		expect(ended and world.cinematic == nil, "debug " .. case[1] .. " never ended")
	end
end)

test("ultimate needs meter and spends it", function()
	local world = closeWorld(3)
	local e1 = run(world, 30, function(t) return { input({ ultimate = t == 1 }) } end)
	expect(count(e1, "SuperFlash") == 0, "ultimate started without meter")
	world.fighters[1].meter = 250
	local e2 = run(world, 5, function(t) return { input({ ultimate = t == 1 }) } end)
	expect(count(e2, "SuperFlash") == 1, "no super flash")
	expect(world.fighters[1].meter == 50, "meter " .. world.fighters[1].meter)
end)

test("combo into ultimate: L L then R-ultimate cancel", function()
	local world = closeWorld(3)
	world.fighters[1].meter = Config.MaxMeter
	local events = run(world, 260, mash({ "L", "L", "U", "U" }, 6))
	expect(find(events, "CinematicStart") ~= nil, "ultimate cancel did not connect: " .. hitMoves(events))
end)

test("latency: a far player's late link still connects (within the latency cap)", function()
	local function linkAfter(latency, late)
		local world = closeWorld(3)
		local f = world.fighters[1]
		f.latencyTicks = latency
		local ended, events = nil, {}
		for t = 1, 120 do
			local i = input({ light = t == 1 or (ended ~= nil and t == ended + late) })
			for _, e in Sim.step(world, { i, Sim.neutralInput() }) do table.insert(events, e) end
			if not ended and t > 2 and f.move == nil then ended = t end
		end
		local moves = {}
		for _, e in events do if e.kind == "Hit" then table.insert(moves, e.move) end end
		return moves[2]
	end
	local late = Config.LateCancelTicks + 4
	expect(linkAfter(0, late) == "Jab", "a press this late linked without latency: " .. tostring(linkAfter(0, late)))
	expect(linkAfter(8, late) == "Cross", "the far player's late press did not link: " .. tostring(linkAfter(8, late)))
	expect(linkAfter(40, Config.LateCancelTicks + Config.MaxLatencyTicks + 3) == "Jab", "the latency cap is not applied")
end)

test("latency: a QTE is judged at the cinematic tick the far player saw", function()
	local function judge(latency, seenOffset, lateBy)
		local world = closeWorld(3)
		Sim.debugCinematic(world, 1, "Awaken", MoveData.FullRoutes[1].name, 300)
		world.fighters[1].latencyTicks = latency
		local cin = MoveData.Cinematics[world.cinematic.move]
		local prompt = world.cinematic.prompts[1]
		local result
		for _ = 1, 600 do
			local state = world.cinematic
			if not state or result ~= nil then break end
			local i = Sim.neutralInput()
			if state.tick == prompt.tick + cin.PromptWindow + lateBy and state.nextPrompt == 1 then
				i[if prompt.button == "Light" then "light" elseif prompt.button == "Heavy" then "heavy" else "ultimate"] = true
				i.cinTick = state.tick - seenOffset
			end
			for _, e in Sim.step(world, { i, Sim.neutralInput() }) do
				if e.kind == "Prompt" and e.index == 1 then result = e.success end
			end
		end
		return result
	end
	local late = 4
	expect(judge(0, late + MoveData.Cinematics.Awakening.PromptWindow, late) == false, "a late press without latency succeeded")
	expect(judge(8, late + MoveData.Cinematics.Awakening.PromptWindow, late) == true, "the far player's on-time press (as seen) failed")
	expect(judge(8, 60, late) == false, "a press claimed far in the past was accepted")
end)

test("ultimate cinematic: scripted hits, timer paused, round ends only after it", function()
	local world = closeWorld(3, false)
	world.fighters[1].meter = Config.MaxMeter
	world.fighters[2].hp = 120
	local timer = world.timerTicks
	local events = {}
	for t = 1, 450 do
		local evs = Sim.step(world, { input({ ultimate = t == 1 }), Sim.neutralInput() })
		for _, e in evs do e.tick = t; table.insert(events, e) end
		if world.cinematic then
			expect(world.timerTicks == timer, "timer ran during the cinematic")
			expect(world.phase == "Fight", "round ended mid-cinematic")
		else
			timer = world.timerTicks
		end
	end
	local start, finish, roundEnd = find(events, "CinematicStart"), find(events, "CinematicEnd"), find(events, "RoundEnd")
	expect(start and finish, "cinematic did not run")
	local cinematicHits = 0
	for _, e in events do if e.cinematic then cinematicHits += 1 end end
	expect(cinematicHits == #MoveData.Cinematics.KaienRush.Hits + 1, "cinematic hits " .. cinematicHits)
	expect(roundEnd and roundEnd.tick >= finish.tick, "KO announced before the cinematic ended")
	expect(world.fighters[1].wins == 1, "no win after the ultimate KO")
end)

test("ultimate on a juggled target: both fighters on the same ground line, facing each other", function()
	for _, side in { -1, 1 } do
		local world = closeWorld(3, false)
		local a, d = world.fighters[1], world.fighters[2]
		a.meter = Config.MaxMeter
		-- Juggled target right at the wall, high in the air.
		d.x, a.x = side * (Config.ArenaMaxX - 0.1), side * (Config.ArenaMaxX - 1.6)
		a.facing = side
		d.y, d.vy, d.launched, d.state, d.stun, d.stunKind = 1.5, 4, true, "Hitstun", 40, "Hit"
		local started
		for t = 1, 120 do
			for _, e in Sim.step(world, { input({ ultimate = t == 1 }), Sim.neutralInput() }) do
				if e.kind == "CinematicStart" then started = true end
			end
			if started then break end
		end
		expect(started, string.format("ultimate did not connect on the juggled target (side %d) y=%.2f x=%.2f/%.2f %s %s",
			side, d.y, a.x, d.x, tostring(a.state), tostring(a.move)))
		expect(a.y == 0 and d.y == 0 and not d.launched, "fighters left in the air")
		expect(math.abs(math.abs(d.x - a.x) - Config.CinematicGap) < 1e-6, "gap " .. math.abs(d.x - a.x))
		expect(a.x >= Config.ArenaMinX and a.x <= Config.ArenaMaxX and d.x >= Config.ArenaMinX and d.x <= Config.ArenaMaxX,
			"cinematic placed a fighter outside the arena")
		expect(a.facing == -d.facing and a.facing == (if d.x > a.x then 1 else -1), "fighters do not face each other")
	end
end)

test("cinematics play in slow motion, slower still on the final blow, with unchanged damage", function()
	local world = closeWorld(3, false)
	Sim.debugCinematic(world, 1, "Rush")
	local cin = MoveData.Cinematics[MoveData.Kits.KAI.Ultimates.Rush]
	local d = world.fighters[2]
	local planned = 0
	for _, step in world.cinematic.plan do planned += step.damage end
	local hp, steps, slowAtFinal, slowBefore = d.hp, 0, 0, 0
	while world.cinematic do
		local scale = Sim.cinematicScale(world)
		local rel = world.cinematic.tick - world.cinematic.finalTick
		if rel == 0 then slowAtFinal = scale elseif rel == -20 then slowBefore = scale end
		Sim.step(world, { Sim.neutralInput(), Sim.neutralInput() })
		steps += 1
		expect(steps < 2000, "cinematic never ended")
	end
	expect(steps > cin.Length * 1.3, string.format("cinematic not slowed: %d steps for %d ticks", steps, cin.Length))
	expect(slowAtFinal < slowBefore and slowBefore < 1, "final blow not slower than the rest")
	expect(hp - d.hp == math.min(planned, hp), string.format("damage %d instead of %d", hp - d.hp, planned))
end)

test("blocked ultimate does not start the cinematic", function()
	local world = closeWorld(3)
	world.fighters[1].meter = Config.MaxMeter
	local events = run(world, 120, function(t) return { input({ ultimate = t == 1 }), input({ block = true }) } end)
	expect(count(events, "Block") == 1 and find(events, "CinematicStart") == nil, "blocked ultimate played the cinematic")
end)

test("meter grows on hits and caps at the maximum", function()
	local world = closeWorld(3, false)
	run(world, 40, function(t) return { input({ light = t == 1 }) } end)
	expect(world.fighters[1].meter > 0 and world.fighters[2].meter > 0, "no meter gain")
	world.fighters[1].meter = Config.MaxMeter - 1
	run(world, 40, function(t) return { input({ light = t == 1 }) } end)
	expect(world.fighters[1].meter <= Config.MaxMeter, "meter over the cap")
end)

test("juggles are limited", function()
	local world = closeWorld(3)
	local d = world.fighters[2]
	d.launched, d.juggle, d.y, d.vy = true, Config.MaxJuggleHits, 3, 5
	local events = run(world, 20, function(t) return { input({ light = t == 1 }) } end)
	expect(count(events, "Hit") == 0, "hit a target past the juggle limit")
end)

test("knocked-down fighter cannot be hit", function()
	local world = closeWorld(3)
	world.fighters[2].knockdown = 20
	local events = run(world, 20, function(t) return { input({ light = t == 1 }) } end)
	expect(count(events, "Hit") == 0, "hit a knocked-down fighter")
end)

test("repeated heavy blocks break the guard", function()
	local world = closeWorld(3)
	local broke = false
	for t = 1, 400 do
		local events = Sim.step(world, { input({ heavy = t % 45 == 1 }), input({ block = true }) })
		for _, e in events do if e.kind == "GuardBreak" then broke = true end end
		world.fighters[1].x, world.fighters[2].x = -1.5, 1.5
		if broke then break end
	end
	expect(broke, "guard never broke")
end)

test("facing stays locked during an attack", function()
	local world = closeWorld(3)
	local a = world.fighters[1]
	run(world, 2, function(t) return { input({ light = t == 1 }) } end)
	world.fighters[2].x = -10
	run(world, 3)
	expect(a.facing == 1, "turned during the jab")
end)

test("pushback in the corner moves the attacker instead", function()
	local world = closeWorld(3)
	world.fighters[1].x, world.fighters[2].x = Config.ArenaMaxX - 3, Config.ArenaMaxX
	run(world, 30, function(t) return { input({ light = t == 1 }) } end)
	expect(world.fighters[2].x == Config.ArenaMaxX, "defender left the wall")
	expect(world.fighters[1].x < Config.ArenaMaxX - 3, "attacker was not pushed back")
end)

test("KO ends the round once and awards a single win", function()
	local world = closeWorld(3, false)
	world.fighters[2].hp = 10
	local events = run(world, 60, function(t) return { input({ light = t % 4 == 1 }) } end)
	expect(count(events, "RoundEnd") == 1, "round ended " .. count(events, "RoundEnd") .. " times")
	expect(world.fighters[1].wins == 1 and world.fighters[2].wins == 0, "wins not awarded once")
	expect(world.fighters[2].state == "KO", "loser not KO")
end)

test("KO fighter cannot attack", function()
	local world = closeWorld(3, false)
	world.fighters[1].hp = 0
	world.fighters[1].state = "KO"
	local events = run(world, 30, function() return { input({ light = true }) } end)
	expect(count(events, "Hit") == 0, "KO fighter landed a hit")
end)

test("timeout gives the round to the healthier fighter", function()
	local world = closeWorld(10, false)
	world.timerTicks = 2
	world.fighters[1].hp = 500
	local roundEnd = find(run(world, 3), "RoundEnd")
	expect(roundEnd and roundEnd.reason == "Timeout" and roundEnd.winner == 2, "bad timeout result")
end)

test("double KO is a draw that scores for both", function()
	local world = closeWorld(3, false)
	world.fighters[1].hp, world.fighters[2].hp = 10, 10
	local events = run(world, 30, function(t) return { input({ light = t == 1 }), input({ light = t == 1 }) } end)
	local roundEnd = find(events, "RoundEnd")
	expect(roundEnd and roundEnd.winner == 0, "expected a draw")
	expect(world.fighters[1].wins == 1 and world.fighters[2].wins == 1, "draw not scored for both")
end)

test("two round wins end the match, then a fresh match starts", function()
	local world = closeWorld(3, false)
	world.fighters[1].wins = 1
	world.fighters[2].hp = 10
	local events = run(world, 30 + Config.KOTicks + Config.MatchEndTicks + 5,
		function(t) return { input({ light = t == 1 }) } end)
	expect(count(events, "MatchEnd") == 1, "match did not end")
	expect(world.fighters[1].wins == 0 and world.round == 1 and world.phase == "Intro", "match not reset")
	expect(world.fighters[1].meter == 0, "meter not reset with the match")
end)

test("training refills health and meter after the combo ends", function()
	local world = closeWorld(3)
	run(world, 40, function(t) return { input({ light = t == 1 }) } end)
	expect(world.fighters[2].hp < Config.MaxHealth, "no damage")
	run(world, Config.TrainingRefillTicks + 5)
	expect(world.fighters[2].hp == Config.MaxHealth, "health not refilled")
	expect(world.fighters[1].meter == Config.MaxMeter, "meter not refilled")
end)

test("fighters never cross on the ground and stay in the arena", function()
	local world = closeWorld(3)
	for _ = 1, 300 do
		Sim.step(world, { input({ axis = 1, dash = true }), input({ axis = -1 }) })
		local a, b = world.fighters[1], world.fighters[2]
		expect(b.x - a.x >= Config.PushWidth - 1e-6, "pushboxes overlapped")
		expect(a.x >= Config.ArenaMinX and b.x <= Config.ArenaMaxX, "left the arena")
	end
end)

T.finish()
