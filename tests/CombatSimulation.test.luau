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
	local presses = { [1] = "L", [7] = "R", [56] = "L", [62] = "L", [68] = "L" }
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

local function skillTest(name, sequence, every, expectedRoute, setup)
	test(name, function()
		local world = closeWorld(3)
		if setup then setup(world) end
		local events = run(world, 200, mash(sequence, every))
		local route = hitMoves(events)
		local compact = {}
		for move in route:gmatch("[^,]+") do
			if compact[#compact] ~= move then table.insert(compact, move) end
		end
		expect(table.concat(compact, ",") == expectedRoute, "route was " .. route)
		local skill = find(events, "Skill")
		expect(skill ~= nil, "no skill announced")
	end)
end

skillTest("skill L R L R: TORNADE DU DRAGON (multi-hit launcher)", { "L", "R", "L", "R" }, 6,
	"Jab,BodyBlow,PalmStrike,DragonTornado")
skillTest("skill R L R L: RAFALE DE KI", { "R", "L", "R", "L" }, 8,
	"Smash,Sweep,RisingWind,KiFlurry")
skillTest("skill L L R R: POING DU DRAGON", { "L", "L", "R", "R" }, 6,
	"Jab,Cross,Uppercut,DragonFist")
skillTest("skill R R L R: TALON FOUDRE into POING DU DRAGON", { "R", "R", "L", "R" }, 8,
	"Smash,Hammer,ThunderHeel,DragonFist")
skillTest("skill L L L L R: CROISSANT DE LUNE", { "L", "L", "L", "L", "R" }, 6,
	"Jab,Cross,Elbow,Kick,CrescentMoon")

test("multi-hit skills hit several times, once per interval", function()
	local world = closeWorld(3)
	local events = run(world, 200, mash({ "L", "R", "L", "R" }, 6))
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

for _, route in MoveData.FullRoutes do
	test("6-press route " .. route.keys .. " (" .. route.name .. ") ends in COUP DE GRÂCE", function()
		local world = closeWorld(3)
		local keys = {}
		for k in route.keys:gmatch("%S") do table.insert(keys, k) end
		local events = playRoute(world, keys)
		expect(compactRoute(events) == table.concat(route.moves, ","), "route was " .. compactRoute(events))
	end)
end

test("3 bars at the 6th press: ÉVEIL ÉCARLATE removes 95 % of the current health", function()
	local world = closeWorld(3, false)
	world.fighters[1].meter = Config.MaxMeter
	local hpAtStart
	local events = {}
	local keys = { "L", "R", "L", "R", "L", "R" }
	local step, pressedFor = 1, nil
	for _ = 1, 700 do
		local a = world.fighters[1]
		local i = input()
		local key = a.move and (a.move .. tostring(a.moveContact ~= nil))
		if keys[step] and (step == 1 or (a.move and a.moveContact and key ~= pressedFor
			and a.moveHits >= (Moves[a.move].hits or 1))) then
			if keys[step] == "L" then i.light = true else i.heavy = true end
			pressedFor = key
			step += 1
		end
		a.meter = math.max(a.meter, if step <= 6 then Config.MaxMeter else 0)
		for _, e in Sim.step(world, { i, Sim.neutralInput() }) do
			table.insert(events, e)
			if e.kind == "CinematicStart" then hpAtStart = world.fighters[2].hp end
		end
	end
	local start = find(events, "CinematicStart")
	expect(start and start.move == "Awakening" and not start.finish, "no awakening cinematic")
	local expected = hpAtStart - math.floor(hpAtStart * MoveData.Cinematics.Awakening.HealthRatio)
	expect(world.fighters[2].hp == expected, string.format("hp %d, expected %d", world.fighters[2].hp, expected))
	expect(find(events, "RoundEnd") == nil, "awakening killed a healthy target")
end)

test("below 50 %: ÉVEIL ÉCARLATE is a FINAL FINISH (KO after the cinematic)", function()
	local world = closeWorld(3, false)
	world.fighters[2].hp = 480
	local events = {}
	local keys = { "L", "R", "L", "R", "L", "R" }
	local step, pressedFor = 1, nil
	for _ = 1, 900 do
		local a = world.fighters[1]
		local i = input()
		local key = a.move and (a.move .. tostring(a.moveContact ~= nil))
		if keys[step] and (step == 1 or (a.move and a.moveContact and key ~= pressedFor
			and a.moveHits >= (Moves[a.move].hits or 1))) then
			if keys[step] == "L" then i.light = true else i.heavy = true end
			pressedFor = key
			step += 1
		end
		if step <= 6 then a.meter = Config.MaxMeter end
		for _, e in Sim.step(world, { i, Sim.neutralInput() }) do table.insert(events, e) end
	end
	local start, finish, roundEnd = find(events, "CinematicStart"), find(events, "CinematicEnd"), find(events, "RoundEnd")
	expect(start and start.finish, "no FINAL FINISH")
	expect(roundEnd and roundEnd.winner == 1, "no KO")
	expect(finish and finish.finish, "cinematic end not flagged as finish")
end)

test("6th press without 3 bars stays COUP DE GRÂCE", function()
	local world = closeWorld(3)
	world.fighters[1].meter = 0 -- the combo itself fills about half the meter
	local events = playRoute(world, { "L", "R", "L", "R", "L", "R" })
	expect(find(events, "CinematicStart") == nil, "unique attack without 3 bars")
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

test("ultimate cinematic: scripted hits, timer paused, round ends only after it", function()
	local world = closeWorld(3, false)
	world.fighters[1].meter = Config.MaxMeter
	world.fighters[2].hp = 120
	local timer = world.timerTicks
	local events = {}
	for t = 1, 300 do
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
