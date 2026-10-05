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
	local events = run(world, 16, function(t) return { input({ light = t == 1 }), input({ block = true }) } end)
	expect(count(events, "Block") == 1 and count(events, "Hit") == 0, "expected a block")
	local chip = math.floor(Moves.Jab.damage * Config.BlockDamageRatio + 0.5)
	expect(world.fighters[2].hp == Config.MaxHealth - chip, "blocked damage " .. world.fighters[2].hp)
	expect(world.fighters[2].guard < Config.MaxGuard, "guard not spent")
end)

test("holding back guards (like every fighting game): high standing, low down-back, walking back when nothing comes", function()
	-- (fighter 2 stands on the right: back = axis +1)
	local world = closeWorld(3)
	local events = run(world, 16, function(t) return { input({ light = t == 1 }), input({ axis = 1 }) } end)
	expect(count(events, "Block") == 1 and count(events, "Hit") == 0, "holding back did not guard the jab")
	local free = closeWorld(3)
	local x0 = free.fighters[2].x
	run(free, 10, function() return { input(), input({ axis = 1 }) } end)
	expect(free.fighters[2].x > x0 + 0.5 and free.fighters[2].state == "Walking", "back no longer walks back when nothing comes")
	-- an attack coming: the walk stops into the guard (proximity guard)
	local near = closeWorld(3)
	local states = {}
	run(near, 6, function(t)
		if t > 1 then states[near.fighters[2].state] = true end
		return { input({ heavy = t == 1 }), input({ axis = 1 }) }
	end)
	expect(states.Blocking, "the guard does not come up when an attack is near")
	-- the sweep is low: standing back fails, down-back holds
	local standing = closeWorld(3)
	local e1 = run(standing, 60, function(t) local i = mash({ "R", "L" }, 6)(t); return { i[1], input({ axis = 1 }) } end)
	expect(string.find(hitMoves(e1), "Sweep") ~= nil, "standing back guarded a low: " .. hitMoves(e1))
	local low = closeWorld(3)
	local e2 = run(low, 60, function(t) local i = mash({ "R", "L" }, 6)(t); return { i[1], input({ axis = 1, crouch = t > 14 }) } end)
	expect(count(e2, "Block") == 2, "down-back did not hold the sweep")
	-- forward never guards; the rule can be switched off
	local forward = closeWorld(3)
	local e3 = run(forward, 16, function(t) return { input({ light = t == 1 }), input({ axis = -1 }) } end)
	expect(count(e3, "Hit") == 1, "walking forward guarded")
	local cfg = table.clone(Config)
	cfg.BackBlock = false
	local off = Sim.newWorld(cfg, MoveData, true)
	off.phase = "Fight"
	off.fighters[1].x, off.fighters[2].x = -1.5, 1.5
	local e4 = run(off, 16, function(t) return { input({ light = t == 1 }), input({ axis = 1 }) } end)
	expect(count(e4, "Hit") == 1, "BackBlock = false still guards")
end)

test("holding back never guards while being hit, knocked down or in the air", function()
	local world = closeWorld(3)
	-- a combo already landing: holding back from its second hit on changes nothing
	local held = false
	local events = run(world, 40, function(t)
		local i = mash({ "L", "L", "L" }, 7)(t)
		held = held or world.fighters[2].stun > 0 -- (from the first hit on)
		return { i[1], input({ axis = if held then 1 else 0 }) }
	end)
	expect(count(events, "Hit") >= 2, "back blocked out of hitstun: " .. hitMoves(events))
	local air = closeWorld(3)
	local e2 = run(air, 30, function(t) return { input({ light = t == 8 }), input({ jump = t == 1, axis = 1 }) } end)
	expect(count(e2, "Block") == 0, "a fighter in the air guarded by holding back")
end)

test("training: frame advantage after a hit or a guard (+ the attacker first, - the defender first), once per exchange", function()
	local function measure(block, training)
		local world = closeWorld(3, training)
		local events = run(world, 60, function(t) return { input({ light = t == 1 }), input({ block = block }) } end)
		local out = {}
		for _, e in events do if e.kind == "FrameAdvantage" then table.insert(out, e) end end
		return out
	end
	local onBlock, onHit = measure(true, true), measure(false, true)
	expect(#onBlock == 1 and #onHit == 1, "one measure per exchange: " .. #onBlock .. " / " .. #onHit)
	expect(onBlock[1].blocked and not onHit[1].blocked and onBlock[1].attacker == 1, "the measure's fields")
	expect(onBlock[1].frames % 1 == 0 and math.abs(onBlock[1].frames) <= 30, "a strange advantage: " .. onBlock[1].frames)
	expect(onHit[1].frames > onBlock[1].frames, "a jab is not better on hit than on block: " .. onHit[1].frames .. " vs " .. onBlock[1].frames)
	expect(#measure(true, false) == 0, "the advantage is measured outside TRAINING")
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

test("launch, rise, spike, bounce, pick up: L L R R L R reads like an anime combo (Wilhem's TARO example)", function()
	-- The launcher sends the target up; the rising strike carries the attacker up with it and
	-- spikes it into the floor; it bounces; the chase dives onto it; the finisher sends it
	-- away. Every blow lands close to the target (never from far below it).
	local world = closeWorld(3)
	local a, d = world.fighters[1], world.fighters[2]
	local keys, step, pressedFor = { "L", "L", "R", "R", "L", "R" }, 1, nil
	local risen, bounced, worst = 0, false, 0
	for _ = 1, 400 do
		local i = input()
		local key = a.move and (a.move .. tostring(a.moveContact ~= nil))
		if keys[step] and (step == 1 or (a.move and a.moveContact and key ~= pressedFor and a.moveHits >= (Moves[a.move].hits or 1))) then
			if keys[step] == "L" then i.light = true else i.heavy = true end
			pressedFor, step = key, step + 1
		end
		for _, e in Sim.step(world, { i, Sim.neutralInput() }) do
			if e.kind == "Hit" and (e.move == "DragonFist" or e.move == "KiChase" or e.move == "Finale") then
				worst = math.max(worst, math.abs(d.y - a.y))
			end
		end
		if a.move == "DragonFist" then risen = math.max(risen, a.y) end
		if d.justBounced or d.bounced then bounced = true end
	end
	expect(risen > 2, string.format("the rising strike stays on the floor (%.1f)", risen))
	expect(bounced, "the spike never bounces the target off the floor")
	expect(worst < 3.6, string.format("a blow lands %.1f studs above or below its target", worst))
end)

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

-- What an awakening deals with `missed` rhythm prompts missed (MaxHealthShare of the maximum
-- health, MissShare off the final blow per miss).
local function awakeningDamage(maxHp, missed)
	local cin = MoveData.Cinematics.Awakening
	local total = math.floor(maxHp * cin.MaxHealthShare)
	local share = math.floor(total * cin.HitShare)
	local final = total - share * #cin.Hits
	for _ = 1, missed do final = math.max(1, final - math.floor(maxHp * cin.MissShare)) end
	return share * #cin.Hits + final
end

for _, route in MoveData.FullRoutes do
	test("ÉVEIL ÉCARLATE earned on " .. route.name .. ": clean route ending on the right click, 3 bars", function()
		local world = closeWorld(3, false)
		local events, hpAtStart = playEarned(world, routeKeys(route, "R"))
		local start = find(events, "CinematicStart")
		expect(start and start.move == "Awakening", "no awakening (" .. compactRoute(events) .. ")")
		expect(start.style == route.name, "style " .. tostring(start.style))
		-- (no prompt pressed: the four are missed, the awakening only takes its floor)
		local expected = hpAtStart - awakeningDamage(Config.MaxHealth, 4)
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
		-- (the climax prompt is not pressed: the gate only half opens)
		local cin = MoveData.Cinematics.Kaiten
		local expected = hpAtStart - math.floor(Config.MaxHealth * cin.MaxHealthShare) + math.floor(Config.MaxHealth * cin.MissShare)
		expect(world.fighters[2].hp == expected, string.format("hp %d, expected %d", world.fighters[2].hp, expected))
	end)
end

test("PORTE DES CIEUX: the R key on the climax adds the bonus, and can KO", function()
	local world = closeWorld(3, false)
	world.fighters[2].hp = 900
	local events, hpAtStart = playEarned(world, routeKeys(MoveData.FullRoutes[3], "U"), { prompts = true, ticks = 1200 })
	local grade = find(events, "PromptGrade")
	expect(grade and grade.grade == "PERFECT", "gate prompt " .. tostring(grade and grade.grade))
	local cin = MoveData.Cinematics.Kaiten
	local expected = math.floor(Config.MaxHealth * cin.MaxHealthShare) + math.floor(Config.MaxHealth * cin.PerfectBonus)
	local dealt = 0
	for _, e in events do
		if e.kind == "Hit" and e.cinematic and e.move == "Kaiten" then dealt += e.damage end
	end
	expect(dealt == expected, string.format("dealt %d, expected %d (hp at start %d)", dealt, expected, hpAtStart))
	local low = closeWorld(3, false)
	low.fighters[2].hp = 300
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
			expect(grade and grade.grade == "PERFECT", kitName .. ": gate prompt " .. tostring(grade and grade.grade))
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

test("ÉVEIL ÉCARLATE: the rhythm prompts decide the damage (30 % perfect, 12 % all missed), KO only if it finishes", function()
	local maxHp = Config.MaxHealth
	local perfect, none = awakeningDamage(maxHp, 0), awakeningDamage(maxHp, 4)
	expect(math.abs(perfect / maxHp - 0.30) < 0.01, string.format("perfect awakening %.1f %%", perfect / maxHp * 100))
	expect(math.abs(none / maxHp - 0.12) < 0.01, string.format("awakening with every prompt missed %.1f %%", none / maxHp * 100))
	-- Perfect on a target with less health than that: FINAL FINISH.
	local world = closeWorld(3, false)
	world.fighters[2].hp = perfect + 150 -- (the route itself takes some of it before the cinematic)
	local events = playEarned(world, routeKeys(MoveData.FullRoutes[1], "R"), { prompts = true, ticks = 1100 })
	local start, finish, roundEnd = find(events, "CinematicStart"), find(events, "CinematicEnd"), find(events, "RoundEnd")
	expect(start, "no awakening")
	expect(roundEnd and roundEnd.winner == 1, "a perfect awakening did not KO a target it out-damages")
	expect(finish and finish.finish, "cinematic end not flagged as finish")
	-- Every prompt missed on the same target: it survives.
	local missed = closeWorld(3, false)
	missed.fighters[2].hp = perfect + 150
	local missedEvents, hpAtStart = playEarned(missed, routeKeys(MoveData.FullRoutes[1], "R"), { ticks = 1100 })
	expect(find(missedEvents, "CinematicStart"), "no awakening (prompts missed)")
	expect(not find(missedEvents, "RoundEnd"), "missing every prompt still KOed")
	expect(missed.fighters[2].hp == hpAtStart - none, string.format("hp %d after a missed awakening from %d", missed.fighters[2].hp,
		hpAtStart or -1))
end)

test("rhythm prompts: all on time is PARFAIT and gives a ki bar back", function()
	local world = closeWorld(3, false)
	local events = playEarned(world, routeKeys(MoveData.FullRoutes[2], "R"), { prompts = true })
	local grade = find(events, "PromptGrade")
	expect(grade and grade.grade == "PERFECT", "grade " .. tostring(grade and grade.grade))
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
	expect(grade and grade.grade == "GOOD", "mashing graded " .. tostring(grade and grade.grade))
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
	expect(not a.chainClean and a.dirtyReason == "TOO EARLY", "early link judged clean")
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

-- COUP FATAL (C): 3 bars, own health under FatalHealth, once per match.
local function fatalWorld(gap, foeHp)
	local world = closeWorld(gap, false)
	local f = world.fighters[1]
	f.meter, f.hp = Config.MaxMeter, math.floor(f.maxHp * Config.FatalHealth) - 10
	if foeHp then world.fighters[2].hp = foeHp end
	return world
end

-- Plays the fatal: `combo` = after a jab that hit; `prompt` = the C key on the climax.
local function playFatal(world, combo, prompt)
	local events, started = {}, false
	for t = 1, 1400 do
		local state = world.cinematic
		local i = input({})
		if combo then
			i.light = t == 1
			i.fatal = not started and t > 1 and t < 30
		else
			i.fatal = t == 1
		end
		if state and prompt and state.type == "Fatal" then
			local p = state.prompts[1]
			if p and state.nextPrompt == 1 and state.tick + 1 == p.tick then i.fatal = true end
		end
		for _, e in Sim.step(world, { i, Sim.neutralInput() }) do
			e.tick = t
			table.insert(events, e)
			if e.kind == "CinematicStart" then started = true end
		end
		if started and not world.cinematic and t > 60 then break end
	end
	local dealt = 0
	for _, e in events do
		if e.kind == "Hit" and e.cinematic then dealt += e.damage end
	end
	return events, dealt
end

test("COUP FATAL: only with the whole ki gauge, under 30 % of one's own health, once per match", function()
	local world = closeWorld(3, false)
	local f = world.fighters[1]
	f.meter = Config.MaxMeter
	local events = run(world, 20, function(t) return { input({ fatal = t == 1 }) } end)
	expect(count(events, "SuperFlash") == 0, "the COUP FATAL came out at full health")
	f.hp, f.meter = math.floor(f.maxHp * 0.25), 200
	events = run(world, 20, function(t) return { input({ fatal = t == 1 }) } end)
	expect(count(events, "SuperFlash") == 0, "the COUP FATAL came out with 2 bars")
	f.meter = Config.MaxMeter
	expect(Sim.fatalReady(world, f), "not ready with 3 bars at 25 % health")
	events = run(world, 20, function(t) return { input({ fatal = t == 1 }) } end)
	expect(count(events, "SuperFlash") == 1, "the COUP FATAL did not come out")
	expect(f.fatalUsed and f.meter == 0, "the COUP FATAL did not spend the gauge / its use")
	f.meter = Config.MaxMeter
	expect(not Sim.fatalReady(world, f), "a second COUP FATAL in the same match")
	for _, kit in MoveData.KitOrder do
		local id = MoveData.Kits[kit].Ultimates.Fatal
		expect(id and Moves[id] and Moves[id].fatal and MoveData.Cinematics[id] and MoveData.Cinematics[id].Type == "Fatal",
			kit .. " has no COUP FATAL")
	end
end)

test("COUP FATAL: 65 % from a combo, 40 % raw; the missed C prompt costs 40 % of it", function()
	local maxHp = Config.MaxHealth
	local cin = MoveData.Cinematics.Fatal
	local combo = math.floor(maxHp * cin.ComboShare)
	local raw = math.floor(maxHp * cin.RawShare)
	local _, dealt = playFatal(fatalWorld(3), false, true)
	expect(dealt == raw, string.format("raw, prompt hit: dealt %d, expected %d", dealt, raw))
	_, dealt = playFatal(fatalWorld(3), false, false)
	expect(dealt == raw - math.floor(raw * cin.MissRatio), string.format("raw, prompt missed: dealt %d", dealt))
	local world = fatalWorld(3, maxHp)
	local events
	events, dealt = playFatal(world, true, true)
	local start = find(events, "CinematicStart")
	expect(start and world.fighters[1].fatalCombo == nil, "no COUP FATAL from the combo")
	expect(dealt == combo, string.format("combo, prompt hit: dealt %d, expected %d", dealt, combo))
	expect(world.fighters[2].hp > 0 and not find(events, "RoundEnd"), "a full-health target did not survive it")
end)

test("COUP FATAL: kills only a target under half its health (its scene is the K.O. screen), lost if dodged", function()
	local high = fatalWorld(3, 900) -- (more than half: it hurts, it never kills)
	local highEvents = playFatal(high, true, true)
	expect(find(highEvents, "CinematicStart") and not find(highEvents, "RoundEnd") and high.fighters[2].hp > 0,
		"the COUP FATAL killed a target over half its health")
	local world = fatalWorld(3, 700)
	local events = playFatal(world, true, true)
	local start = find(events, "CinematicStart")
	expect(start and start.finish, "a killing COUP FATAL is not a finish")
	local roundEnd = find(events, "RoundEnd")
	expect(roundEnd and roundEnd.winner == 1, "the COUP FATAL did not KO")
	-- Thrown from too far: it misses, and the gauge and the match's COUP FATAL are gone.
	local far = fatalWorld(14)
	local missed = playFatal(far, false, false)
	expect(not find(missed, "CinematicStart"), "a COUP FATAL from afar connected")
	expect(far.fighters[1].meter == 0 and far.fighters[1].fatalUsed, "a missed COUP FATAL kept the gauge")
end)

test("a far player's missed QTE is judged before the final blow: the K.O. is decided once", function()
	for _, kind in { "Gate", "Fatal", "Awaken" } do
		for _, hp in { 200, 700 } do
			local world = closeWorld(3, false)
			world.fighters[1].latencyTicks = Config.MaxLatencyTicks or 12
			Sim.debugCinematic(world, 1, kind, MoveData.FullRoutes[1].name, hp)
			local events = {}
			for _ = 1, 2000 do
				for _, e in Sim.step(world, { Sim.neutralInput(), Sim.neutralInput() }) do table.insert(events, e) end
				if not world.cinematic then break end
			end
			local final, ended
			for _, e in events do
				if e.kind == "Hit" and e.cinematic and e.heavy then final = e end
				if e.kind == "CinematicEnd" then ended = e end
			end
			local judged = 0
			for _, e in events do
				if e.kind == "Prompt" then
					judged += 1
				end
			end
			expect(final and ended, kind .. ": the cinematic did not end")
			expect(judged == #MoveData.Cinematics[MoveData.Kits.KAI.Ultimates[kind]].PromptTicks, kind .. ": prompts left unjudged")
			expect((world.fighters[2].hp <= 0) == (ended.finish == true), string.format("%s at %d hp: finish flag %s but hp %d", kind, hp,
				tostring(ended.finish), world.fighters[2].hp))
			expect((final.ko == true) == (ended.finish == true), kind .. ": the final blow and the end disagree on the K.O.")
		end
	end
end)

test("training: the COUP FATAL can always be practised (full health, any number of times)", function()
	local world = closeWorld(3, true)
	local f = world.fighters[1]
	f.meter = Config.MaxMeter
	expect(f.hp == f.maxHp and Sim.fatalReady(world, f), "no COUP FATAL to practise in training at full health")
	f.fatalUsed = true
	expect(Sim.fatalReady(world, f), "training locks the COUP FATAL after one use")
	f.meter = 100
	expect(not Sim.fatalReady(world, f), "a COUP FATAL without its 3 bars, even in training")
end)

test("ULTIMES ON: the player's ki stays full and its health at 25 % (COUP FATAL ready), the opponent untouched", function()
	local world = closeWorld(3, false)
	world.ultimateConditions = 1
	local f, foe = world.fighters[1], world.fighters[2]
	f.meter = 0
	run(world, 2)
	expect(f.meter == Config.MaxMeter, "ULTIMES ON did not fill the gauge")
	expect(f.hp <= f.maxHp * Config.FatalHealth, "ULTIMES ON did not bring the health under the last-breath line")
	expect(foe.hp == foe.maxHp, "ULTIMES ON touched the opponent")
	expect(Sim.fatalReady(world, f), "ULTIMES ON: no COUP FATAL")
	local events = run(world, 30, function(t) return { input({ fatal = t == 1 }) } end)
	expect(count(events, "SuperFlash") == 1, "the COUP FATAL did not come out with ULTIMES ON")
end)

test("PERFECT: a round won without losing any health is flagged, not otherwise", function()
	local function finish(winnerHp)
		local world = closeWorld(3, false)
		world.fighters[1].hp = winnerHp or world.fighters[1].maxHp
		world.fighters[2].hp = 5
		local events = run(world, 40, function(t) return { input({ light = t == 1 }) } end)
		return find(events, "RoundEnd")
	end
	local clean = finish()
	expect(clean and clean.winner == 1 and clean.perfect, "a flawless round is not PERFECT")
	local hurt = finish(1000)
	expect(hurt and hurt.winner == 1 and not hurt.perfect, "a round won while hurt is PERFECT")
end)

test("guard: holding it against 10 s of mashing never breaks it and only chips", function()
	local world = closeWorld(2.6, false)
	local d = world.fighters[2]
	local events = run(world, 600, function(t)
		if math.abs(world.fighters[1].x - d.x) > 3.2 then world.fighters[1].x = d.x - 2.6 end
		return { input({ light = t % 4 == 1 }), input({ block = true }) }
	end)
	expect(count(events, "GuardBreak") == 0, "a jab mash broke the guard")
	expect(count(events, "Hit") == 0, "a hit went through the guard")
	expect(d.hp >= d.maxHp * 0.85, string.format("the guard let %d damage through", d.maxHp - d.hp))
end)

test("guard release: a jab started out of the guard comes out in GuardCancelStartup frames", function()
	local world = closeWorld(2.6, false)
	local a, d = world.fighters[1], world.fighters[2]
	-- One blocked jab, then the defender lets go and jabs back at once.
	local released, hitTick, releaseTick = false, nil, nil
	for t = 1, 60 do
		local free = d.stun == 0 and not d.move and t > 8
		local dIn = if free and not released then input({ light = true }) elseif released then input({}) else input({ block = true })
		if free and not released then released, releaseTick = true, t end
		for _, e in Sim.step(world, { input({ light = t == 1 }), dIn }) do
			if e.kind == "Hit" and e.attacker == 2 and not hitTick then hitTick = t end
		end
	end
	expect(releaseTick ~= nil and hitTick ~= nil, "the defender's jab out of the guard did not land")
	expect(hitTick - releaseTick <= Config.GuardCancelStartup + 1,
		string.format("out of the guard the jab took %d frames", hitTick - releaseTick))
	expect(Moves.Jab.startup > Config.GuardCancelStartup, "the guard release is not faster than a normal jab")
end)

test("wake-up: a short invincibility once back on its feet, ended by attacking", function()
	local world = closeWorld(2.6, false)
	local a, d = world.fighters[1], world.fighters[2]
	d.knockdown = 2
	-- The attacker mashes jabs through the whole wake-up: nothing lands until it is over.
	local firstHit, upTick = nil, nil
	for t = 1, 80 do
		for _, e in Sim.step(world, { input({ light = t % 3 == 1 }), Sim.neutralInput() }) do
			if e.kind == "Hit" and e.attacker == 1 and not firstHit then firstHit = t end
		end
		if not upTick and d.knockdown == 0 and d.getUp == 0 then upTick = t end
	end
	expect(upTick ~= nil and firstHit ~= nil, "the wake-up never ended or nothing ever hit")
	expect(firstHit - upTick >= Config.WakeInvulnTicks - 1,
		string.format("hit %d ticks after getting up (invincible for %d)", firstHit - upTick, Config.WakeInvulnTicks))
	-- Attacking out of the wake-up drops the invincibility.
	local w2 = closeWorld(2.6, false)
	local d2 = w2.fighters[2]
	d2.getUp = 1
	run(w2, 2, function() return { nil, input({ light = true }) } end)
	expect(d2.move ~= nil and d2.wakeInvuln == 0, "attacking kept the wake-up invincibility")
end)

test("teams (relay): a K.O. brings the next fighter in, the winner stays with its health", function()
	local world = Sim.newWorld(Config, MoveData, false)
	Sim.setTeams(world, { "KAI" }, { "TARO", "SHIN", "AKEMI" })
	expect(world.fighters[2].kit == "TARO" and Sim.teamLeft(world, 2) == 3, "the first fighter of team 2 should be TARO")
	local function knockOut(loser)
		world.phase = "Fight"
		world.fighters[3 - loser].hp = 900
		world.fighters[loser].hp = 0
		local events = {}
		for _ = 1, Config.KOTicks + 5 do
			for _, e in Sim.step(world, { Sim.neutralInput(), Sim.neutralInput() }) do table.insert(events, e) end
		end
		return events
	end
	local events = knockOut(2)
	local swap = find(events, "TeamSwap")
	expect(swap and swap.slot == 2 and swap.kit == "SHIN", "SHIN did not come in")
	local kai = world.fighters[1]
	expect(kai.kit == "KAI" and kai.hp == math.min(kai.maxHp, 900 + math.floor(kai.maxHp * Config.TeamHealOnKO)) or kai.hp > 900,
		"the winner did not keep its health (+ the K.O. heal): " .. kai.hp)
	expect(world.fighters[2].hp == world.fighters[2].maxHp, "the new fighter is not at full health")
	expect(find(events, "MatchEnd") == nil, "the match ended with fighters left")
	knockOut(2)
	expect(world.fighters[2].kit == "AKEMI", "AKEMI did not come in")
	local last = knockOut(2)
	local finish = find(last, "MatchEnd")
	expect(finish and finish.winner == 1, "the match did not end when team 2 had nobody left")
end)

test("teams (relay): the side whose team runs out loses, even with one fighter left on the other", function()
	local world = Sim.newWorld(Config, MoveData, false)
	Sim.setTeams(world, { "ZEPHYR", "RYUKEN" }, { "DAICHA" })
	world.phase = "Fight"
	world.fighters[1].hp = 0
	local ended = nil
	for _ = 1, 2000 do
		for _, e in Sim.step(world, { Sim.neutralInput(), Sim.neutralInput() }) do
			if e.kind == "TeamSwap" then expect(e.kit == "RYUKEN", "wrong next fighter") end
			if e.kind == "MatchEnd" then ended = e end
		end
		if world.phase == "Fight" and world.fighters[1].kit == "RYUKEN" and not ended then world.fighters[1].hp = 0 end
		if ended then break end
	end
	expect(ended and ended.winner == 2, "team 1 should lose once ZEPHYR and RYUKEN are out")
end)

test("versus line-ups: 1v1 is a best of three, 3v3 a relay won with three K.O. (up to five rounds)", function()
	local Director = require("../src/shared/CinematicDirector")
	local function knockOut(world, loser)
		world.phase = "Fight"
		world.fighters[3 - loser].hp = 900
		world.fighters[loser].hp = 0
		local events = {}
		for _ = 1, Config.KOTicks + 5 do
			for _, e in Sim.step(world, { Sim.neutralInput(), Sim.neutralInput() }) do table.insert(events, e) end
		end
		return events
	end
	local duel = Sim.newWorld(Config, MoveData, false)
	Sim.setLineup(duel, { "KAI" }, { "TARO" })
	expect(duel.teams == nil, "a 1v1 should not be a relay")
	expect(find(knockOut(duel, 2), "MatchEnd") == nil, "a 1v1 ended after one round")
	expect(find(knockOut(duel, 2), "MatchEnd") ~= nil, "a 1v1 did not end on the second round won")
	local relay = Sim.newWorld(Config, MoveData, false)
	Sim.setLineup(relay, { "KAI", "SHIN", "ZEPHYR" }, { "TARO", "AKEMI", "DAICHA" })
	expect(relay.teams ~= nil, "a 3v3 should be a relay")
	-- 2 K.O. each (four rounds), then the fifth decides; the victory scene waits for it.
	knockOut(relay, 2)
	knockOut(relay, 1)
	knockOut(relay, 2)
	relay.phase = "Fight"
	relay.fighters[2].hp, relay.fighters[1].hp = 900, 0
	Sim.step(relay, { Sim.neutralInput(), Sim.neutralInput() })
	expect(relay.phase == "KO" and Director.victoryScene(relay, Config) == nil, "the K.O. scene played with fighters left")
	for _ = 1, Config.KOTicks + 5 do Sim.step(relay, { Sim.neutralInput(), Sim.neutralInput() }) end
	local last = knockOut(relay, 2)
	local finish = find(last, "MatchEnd")
	expect(finish and finish.winner == 1 and relay.fighters[1].wins == 3, "the fifth round did not end the 3v3 with three K.O.")
end)

-- ===================================================================== Wilhem's third sheet: the passives
local function kitDuel(kit, other, gap)
	local world = Sim.newWorld(Config, MoveData, false)
	Sim.setKits(world, kit, other or "KAI")
	world.phase = "Fight"
	world.fighters[1].x, world.fighters[2].x = -gap / 2, gap / 2
	world.fighters[1].facing, world.fighters[2].facing = 1, -1
	return world
end
local PASSIVE = Sim.PASSIVE
local function jab(t) return { input({ light = t == 1 }) } end
local function special(t) return { input({ special = t == 1 }) } end
local function crouchSpecial(t) return { input({ special = t == 1, crouch = t <= 3 }) } end

test("RAIJIN SURCHARGE: 3 hits in a row charge the next technique (longer reach, more damage)", function()
	local w = kitDuel("RAIJIN", "KAI", 3)
	local a = w.fighters[1]
	a.charge = 2
	run(w, 30, jab)
	expect(a.overcharged, "the third hit did not charge SURCHARGE")
	local id = MoveData.Kits.RAIJIN.Starters.Ground.Special
	w.fighters[2].x = a.x + 3
	run(w, 2, special)
	expect(a.move == id and a.reachMove == a.moveSerial, "the technique did not take the charge")
	local _, far = Sim.hitbox(a, Moves[id])
	expect(far - a.x > Moves[id].hitbox.far * 1.3, "the charged technique does not reach farther")
	expect(not a.overcharged, "the charge was not spent")
end)

test("YUKINA GEL PROGRESSIF: 3 hits freeze the opponent (20 % slower)", function()
	local w = kitDuel("YUKINA", "KAI", 3)
	local d = w.fighters[2]
	d.frost = 2
	run(w, 40, jab)
	expect(d.chilled > 0 and d.frost == 0, "the third stack did not slow")
	local function walk(world)
		local f = world.fighters[2]
		f.stun, f.stunKind, f.state = 0, nil, "Idle"
		local x0 = f.x
		run(world, 20, { nil, input({ axis = 1 }) })
		return f.x - x0
	end
	local cold = walk(w)
	local warm = walk(kitDuel("YUKINA", "KAI", 3))
	expect(cold < warm * 0.85, string.format("a frozen opponent walks %.2f, a warm one %.2f", cold, warm))
end)

test("YUKINA MIROIR DE GLACE: a projectile goes back to its thrower", function()
	local w = kitDuel("YUKINA", "KAI", 9)
	local events = run(w, 90, function(t)
		return { input({ special = t == 8, crouch = t >= 6 and t <= 10 }), input({ special = t == 1, crouch = t <= 3 }) }
	end)
	expect(find(events, "Reflect") ~= nil, "the mirror did not send the blast back")
	expect(w.fighters[2].hp < w.fighters[2].maxHp and w.fighters[1].hp == w.fighters[1].maxHp, "the thrower was not hit by its own blast")
end)

test("VENOM CONTAMINATION: techniques poison (up to 3 charges), the poison never kills", function()
	local w = kitDuel("VENOM", "KAI", 3)
	local d = w.fighters[2]
	local events = run(w, 30, special)
	expect(find(events, "Hit") and d.poison == 1, "the technique did not poison")
	d.poison, d.hp = 3, 40
	local later = run(w, 200)
	expect(count(later, "Poison") >= 2, "the poison does not tick")
	expect(d.hp == 1 and d.state ~= "KO", "the poison killed")
	for _ = 1, 5 do PASSIVE.onHit(w, w.fighters[1], d, Moves[MoveData.Kits.VENOM.Starters.Ground.Special], nil, true, {}) end
	expect(d.poison == 3, "more than 3 poison charges")
end)

test("GORAN ANCRAGE: a heavy blow on the ground takes a hit without flinching; his grabs go through the guard", function()
	local w = kitDuel("GORAN", "KAI", 2.8)
	local g = w.fighters[1]
	local events = run(w, 40, function(t) return { input({ heavy = t == 1 }), input({ light = t == 2 }) } end)
	expect(find(events, "Armor") ~= nil, "no armor on GORAN's heavy blow")
	local hit = false
	for _, e in events do
		if e.kind == "Hit" and e.attacker == 1 then hit = true end
	end
	expect(hit, "GORAN's heavy blow was interrupted")
	expect(g.hp < g.maxHp, "the armor took no damage at all")
	local grab = kitDuel("GORAN", "KAI", 2.4)
	local ge = run(grab, 40, function(t) return { input({ special = t == 1, crouch = t <= 3 }), input({ block = true }) } end)
	expect(find(ge, "Hit") ~= nil and find(ge, "Block") == nil, "ÉTREINTE DU TITAN was blocked")
end)

test("the low guard is not a fortress: forward + R is an overhead, and crouching the guard wears faster", function()
	for _, kitName in MoveData.KitOrder do
		local w = kitDuel(kitName, "KAI", 3)
		local d = w.fighters[2]
		local events = run(w, 50, function(t) return { input({ heavy = t == 1, axis = 1 }), input({ block = true, crouch = true }) } end)
		local hit, blocked = find(events, "Hit"), find(events, "Block")
		expect(w.fighters[1].move == nil or Moves[w.fighters[1].move] ~= nil, kitName)
		expect(hit ~= nil and blocked == nil, kitName .. ": forward + R was blocked crouching (no overhead)")
		-- standing, the same overhead is blocked
		local w2 = kitDuel(kitName, "KAI", 3)
		local e2 = run(w2, 50, function(t) return { input({ heavy = t == 1, axis = 1 }), input({ block = true }) } end)
		expect(find(e2, "Block") ~= nil and find(e2, "Hit") == nil, kitName .. ": the overhead cannot be blocked standing")
	end
	-- a plain R (no direction) stays the kit's neutral heavy
	local w = kitDuel("KAI", "KAI", 3)
	run(w, 2, function(t) return { input({ heavy = t == 1 }) } end)
	expect(w.fighters[1].move == MoveData.Kits.KAI.Starters.Ground.Heavy, "R alone no longer gives the neutral heavy")
	-- the same blocked blow costs more guard crouching than standing
	local function wear(crouch)
		local wd = kitDuel("KAI", "KAI", 2.6)
		local g = wd.fighters[2]
		run(wd, 40, function(t) return { input({ heavy = t == 1 }), input({ block = true, crouch = crouch }) } end)
		return Config.MaxGuard - g.guard
	end
	expect(wear(true) > wear(false) * 1.3, "crouching, the guard does not wear faster")
end)

test("ASURA is massive, not taller: a wider body, the same height and reach; ASURA'S WRATH armors every grounded blow, four arms, no counter hit", function()
	local w = kitDuel("ASURA", "KAI", 3)
	local a, k = w.fighters[1], w.fighters[2]
	local al, ar, ab, at = Sim.hurtbox(a, Config)
	local kl, kr, kb, kt = Sim.hurtbox(k, Config)
	expect(ar - al > (kr - kl) * 1.15, "ASURA's body is not wider than KAI's")
	expect(math.abs((at - ab) - (kt - kb)) < 1e-6, "ASURA is taller than KAI")
	local stats, kai = MoveData.Kits.ASURA.Stats, MoveData.Kits.KAI.Stats
	expect(stats.MaxHealth >= kai.MaxHealth * 2 and (stats.DamageDealt or 1) > 1.3, "ASURA is not much stronger than KAI")
	-- his heavy grounded blow (Smash) takes a hit; his jab does not
	local function armored(id)
		a.state, a.move, a.moveFrame, a.moveSerial, a.armorMove = "Attack", id, 1, (a.moveSerial or 0) + 1, nil
		return PASSIVE.armor(w, k, a, Moves.Jab, {})
	end
	expect(armored("Smash"), "ASURA'S WRATH did not armor the Smash")
	expect(armored("Jab"), "ASURA'S WRATH does not armor every grounded blow (a boss, Wilhem: much stronger)")
	expect(not armored("AirKick"), "ASURA'S WRATH armors in the air")
	-- the four arms: a blow of his that lands is followed by the second pair (more damage)
	local function jabHit(kit)
		local w2 = kitDuel(kit, "KAI", 2.4)
		return find(run(w2, 20, function(t) return { input({ light = t == 1 }) } end), "Hit")
	end
	local ah, kh = jabHit("ASURA"), jabHit("KAI")
	expect(ah and kh and ah.arms and ah.damage > kh.damage * 1.6, "ASURA's second pair of arms does not follow his blows")
	-- a boss is never caught by a COUNTER HIT
	expect(MoveData.Kits.ASURA.Stats.NoCounter, "ASURA can be counter-hit")
end)

test("ASURA's SECOND LIFE: felled once, he rises in a black aura (half health, harder, faster), once per match", function()
	local w = kitDuel("KAI", "ASURA", 3)
	w.training = false
	local boss = w.fighters[2]
	boss.hp = 1
	local events = run(w, 30, function(t) return { input({ heavy = t == 1 }) } end)
	local ko = find(events, "Hit")
	expect(ko and not ko.ko, "the felling blow was announced as a K.O.")
	events = run(w, 400)
	expect(find(events, "Revive") ~= nil, "ASURA did not rise again")
	expect(find(events, "RoundEnd") == nil and w.phase == "Fight", "the round ended on his first fall")
	expect(boss.revived and boss.hp >= boss.maxHp * 0.45, "the second life is not half his health")
	expect(boss.state ~= "KO", "he stays down")
	-- risen, every grounded blow of his is armored, even a jab (he was a boss, he is a monster)
	boss.state, boss.move, boss.moveFrame, boss.moveSerial, boss.armorMove, boss.knockdown, boss.getUp = "Attack", "Jab", 1, 99, nil, 0, 0
	expect(PASSIVE.armor(w, w.fighters[1], boss, Moves.Jab, {}), "risen, his jab is not armored")
	boss.state, boss.move = "Idle", nil
	-- the second fall is the real one
	boss.hp = 1
	boss.wakeInvuln = 0
	local last = run(w, 200, function(t) return { input({ heavy = t == 1 }) } end)
	expect(find(last, "Revive") == nil, "a third life")
	expect(boss.hp <= 0, "the second fall did not fell him")
	-- kits without it fall at once
	local k = kitDuel("ASURA", "KAI", 3)
	expect(not Sim.canRevive(k.fighters[2]) and Sim.canRevive(k.fighters[1]), "SECOND LIFE is not ASURA's alone")
end)

test("ASURA against long reach: four arms reach farther, his forward dash charges through one blow", function()
	local w = kitDuel("ASURA", "KAI", 3)
	local a, k = w.fighters[1], w.fighters[2]
	local m = Moves.Jab
	local _, far = Sim.hitbox(a, m)
	k.facing = 1
	local _, kfar = Sim.hitbox(k, m)
	expect(far - a.x > (kfar - k.x) * 1.2, "ASURA's blows do not reach farther")
	-- dash in, poked: he takes the hit without flinching (once)
	local d = kitDuel("KAI", "ASURA", 4)
	local boss = d.fighters[2]
	local events = run(d, 30, function(t) return { input({ light = t == 3 }), input({ dash = t == 1, axis = -1 }) } end)
	expect(find(events, "Armor") ~= nil and boss.stun == 0, "ASURA's dash was stopped by a poke")
end)

test("ASTER MASSE VARIABLE: a technique that lands charges the next air attack (+30 %)", function()
	local w = kitDuel("ASTER", "KAI", 3)
	local a, d = w.fighters[1], w.fighters[2]
	PASSIVE.onHit(w, a, d, Moves[MoveData.Kits.ASTER.Starters.Ground.Special], nil, true, {})
	expect(a.massReady, "the technique did not charge MASSE VARIABLE")
	expect(math.abs(PASSIVE.bonus(w, a, Moves.AsterAirKick, nil) - 1.3) < 1e-6, "no bonus on the air attack")
	expect(not a.massReady and PASSIVE.bonus(w, a, Moves.AsterAirKick, nil) == 1, "the bonus was not spent")
	expect(PASSIVE.bonus(w, a, Moves.AsterJab, nil) == 1, "a ground attack took the air bonus")
end)

test("ASTER ATTRACTION: the projectile pulls the target in", function()
	local w = kitDuel("ASTER", "KAI", 8)
	local d = w.fighters[2]
	run(w, 40, crouchSpecial)
	expect(d.hp < d.maxHp and d.x < 4, string.format("the target was not pulled (x %.1f)", d.x))
end)

test("HIBIKI TEMPO: 3 hits in rhythm, then her recoveries run twice as fast", function()
	local w = kitDuel("HIBIKI", "KAI", 3)
	local a, d = w.fighters[1], w.fighters[2]
	for _ = 1, 3 do
		PASSIVE.onHit(w, a, d, Moves.HibikiJab, nil, true, {})
		w.tick += 20
	end
	expect(a.tempo > 0, "TEMPO did not start")
	local function lasts(world)
		local f = world.fighters[1]
		world.fighters[2].x = 20
		local n = 0
		run(world, 1, jab)
		while f.move and n < 200 do
			run(world, 1)
			n += 1
		end
		return n
	end
	local fast, normal = lasts(w), lasts(kitDuel("HIBIKI", "KAI", 3))
	expect(fast < normal, string.format("TEMPO jab lasts %d ticks, without %d", fast, normal))
end)

test("HIBIKI TEMPO: no new chain while it runs nor during its cooldown", function()
	local w = kitDuel("HIBIKI", "KAI", 3)
	local a, d = w.fighters[1], w.fighters[2]
	local passive = MoveData.Kits.HIBIKI.Passive
	local function chain()
		for _ = 1, passive.Chain do
			PASSIVE.onHit(w, a, d, Moves.HibikiJab, nil, true, {})
			w.tick += 20
		end
	end
	chain()
	expect(a.tempo > 0, "TEMPO did not start")
	local started = a.tempoReadyAt
	a.tempo = 0
	chain()
	expect(a.tempo == 0 and a.tempoReadyAt == started, "TEMPO restarted during its cooldown")
	w.tick = a.tempoReadyAt
	chain()
	expect(a.tempo > 0, "TEMPO never came back after its cooldown")
end)

-- ===================================================================== KUROEN 蝕 (DOMINATION)
local function kuroenWorld(gap)
	local w = kitDuel("KUROEN", "KAI", gap or 2.6)
	return w, w.fighters[1], w.fighters[2]
end

test("KUROEN DOMINATION: a clean combo of 4 raises it once per combo (max 3), a sloppy one never", function()
	local w, k, d = kuroenWorld()
	local jab = Moves[MoveData.Kits.KUROEN.Roles.Jab]
	local function combo(clean, hits)
		d.comboHits = 0
		for _ = 1, hits do
			k.chainClean = clean
			PASSIVE.onHit(w, k, d, jab, nil, true, {})
			d.comboHits += 1
		end
	end
	combo(true, 3)
	expect(k.domination == 0, "3 hits already raised DOMINATION")
	combo(true, 8)
	expect(k.domination == 1, "a long combo raised it more than once: " .. k.domination)
	combo(false, 6)
	expect(k.domination == 1, "a sloppy (spammed) combo raised it")
	combo(true, 4); combo(true, 4); combo(true, 4)
	expect(k.domination == 3, "DOMINATION goes past ÉCLIPSE (3): " .. k.domination)
end)

test("KUROEN DOMINATION fades: a combo taken costs a level, so do 6 s without landing a blow", function()
	local w, k = kuroenWorld(2.4)
	k.domination = 3
	local events = run(w, 40, function(t) return { nil, input({ light = t == 1 }) } end)
	expect(find(events, "Hit") ~= nil and k.domination == 2, "a combo taken did not cost exactly one level: " .. k.domination)
	w = kuroenWorld(8)
	k = w.fighters[1]
	k.domination = 2
	run(w, 350)
	expect(k.domination == 2, "faded before 6 s")
	run(w, 20)
	expect(k.domination == 1, "did not fade after 6 s without a hit")
end)

test("KUROEN DOMINATION I: CRIMSON STEP becomes EMPEROR STEP and spends the level; CRIMSON STEP is never invincible", function()
	local w, k = kuroenWorld(5)
	local step = Moves[MoveData.Kits.KUROEN.Starters.Ground.Special]
	expect(step.name == "CRIMSON STEP" and not step.invuln and step.recovery >= 28, "CRIMSON STEP is a free reversal or safe")
	run(w, 2, function(t) return { input({ special = t == 1 }) } end)
	expect(k.move == step.id, "no CRIMSON STEP at level 0")
	w, k = kuroenWorld(5)
	k.domination = 1
	local events = run(w, 2, function(t) return { input({ special = t == 1 }) } end)
	expect(k.move == "KuroenEmperorStep" and k.domination == 0, "level I did not give EMPEROR STEP (or did not spend it)")
	expect(find(events, "Domination") ~= nil, "the spent level is not shown")
end)

test("KUROEN DOMINATION II: a technique that hits cancels into another (one level); III: R on a hit is ZERO ABSOLU", function()
	local w, k = kuroenWorld(2.2)
	k.domination = 3
	local seen = {}
	run(w, 60, function(t)
		if k.move then seen[k.move] = true end
		local onHit = k.move == "KuroenEmperorStep" and k.moveContact == "Hit"
		return { input({ special = t == 1 or (onHit and t % 2 == 0) }) }
	end)
	expect(seen.KuroenEmperorStep, "no EMPEROR STEP")
	expect(k.domination <= 1, "the SUPREMACY cancel did not happen / spend: " .. k.domination)
	-- III
	w, k = kuroenWorld(2.4)
	k.domination, k.meter = 3, Config.MaxMeter
	local awaken = MoveData.Kits.KUROEN.Ultimates.Awaken
	run(w, 30, function(t)
		local hit = k.move == MoveData.Kits.KUROEN.Starters.Ground.Light and k.moveContact == "Hit"
		return { input({ light = t == 1, ultimate = hit }) }
	end)
	expect(w.cinematic ~= nil and w.cinematic.move == awaken or k.move == awaken, "ÉCLIPSE + R on a hit did not unleash ZERO ABSOLU")
	expect(k.domination == 0, "ZERO ABSOLU did not spend the three levels")
	-- below ÉCLIPSE, R is his EMPEROR RUSH
	w, k = kuroenWorld(2.4)
	k.domination, k.meter = 2, Config.MaxMeter
	run(w, 30, function(t)
		local hit = k.move == MoveData.Kits.KUROEN.Starters.Ground.Light and k.moveContact == "Hit"
		return { input({ light = t == 1, ultimate = hit }) }
	end)
	expect(not (w.cinematic and w.cinematic.move == awaken), "ZERO ABSOLU without ÉCLIPSE")
end)

test("KUROEN DOMINATION is never a damage bonus; TYRANT'S FIST stops if its first blow is blocked", function()
	local function jabDamage(level)
		local w, k = kuroenWorld(2.4)
		k.domination = level
		local e = find(run(w, 20, function(t) return { input({ light = t == 1 }) } end), "Hit")
		return e and e.damage
	end
	expect(jabDamage(0) and jabDamage(0) == jabDamage(3), "ÉCLIPSE changes the damage")
	local fist = Moves[MoveData.Kits.KUROEN.Roles.KiFlurry]
	expect(fist.confirm and fist.name == "TYRANT'S FIST", "TYRANT'S FIST has no confirm rule")
	local w, k = kuroenWorld(2.4)
	local blocked = run(w, 80, function(t)
		if t == 1 then k.move, k.moveFrame, k.moveHits, k.moveContact, k.state, k.moveSerial = fist.id, 0, 0, nil, "Attack", k.moveSerial + 1 end
		return { nil, input({ block = true }) }
	end)
	expect(count(blocked, "Block") == 1, "a blocked TYRANT'S FIST kept hitting: " .. count(blocked, "Block"))
	w, k = kuroenWorld(2.4)
	local landed = run(w, 80, function(t)
		if t == 1 then k.move, k.moveFrame, k.moveHits, k.moveContact, k.state, k.moveSerial = fist.id, 0, 0, nil, "Attack", k.moveSerial + 1 end
	end)
	expect(count(landed, "Hit") >= 4, "a TYRANT'S FIST that lands does not go on: " .. count(landed, "Hit"))
end)

test("KUROEN SHIN (boss): born at ÉCLIPSE, never loses DOMINATION, gets it back by itself; KUROEN's moves stay KUROEN's", function()
	local w = kitDuel("KUROEN SHIN", "KAI", 2.4)
	local boss = w.fighters[1]
	expect(boss.domination == 3, "KUROEN SHIN is not born at ÉCLIPSE")
	run(w, 40, function(t) return { nil, input({ light = t == 1 }) } end)
	expect(boss.domination == 3, "KUROEN SHIN lost DOMINATION when hit")
	boss.domination = 0
	run(w, 250)
	expect(boss.domination >= 1, "KUROEN SHIN's DOMINATION does not come back")
	expect(MoveData.MoveKit[MoveData.Kits["KUROEN SHIN"].Roles.Jab] == "KUROEN", "the boss took KUROEN's moves away")
	expect(not table.find(MoveData.KitOrder, "KUROEN SHIN"), "KUROEN SHIN is selectable")
	-- the normal KUROEN starts at 0
	local k = kitDuel("KUROEN", "KAI", 3)
	expect(k.fighters[1].domination == 0, "KUROEN is born with DOMINATION")
end)

test("ASURA's BURST: the 5th blow of a combo on him breaks it, the attacker is thrown back, stunned briefly; then a cooldown", function()
	local burst = MoveData.Kits.ASURA.Stats.Burst
	local function hitAt(combo)
		local w = kitDuel("KAI", "ASURA", 2.4)
		w.training = false
		local boss = w.fighters[2]
		local events = run(w, 30, function(t)
			if t == 1 then boss.comboHits, boss.stun, boss.stunKind = combo, 40, "Hit" end
			return { input({ light = t == 1 }) }
		end)
		return w, find(events, "Burst")
	end
	local _, early = hitAt(burst.Hits - 2) -- the 4th blow: no burst yet
	expect(not early, "ASURA burst before the " .. burst.Hits .. "th blow")
	local w, e = hitAt(burst.Hits - 1)
	expect(e and e.slot == 2, "the " .. burst.Hits .. "th blow did not make ASURA burst")
	local kai, boss = w.fighters[1], w.fighters[2]
	expect(boss.burstCooldown > 0 and boss.comboHits == 0 or boss.stun == 0, "ASURA is still held after his BURST")
	expect(burst.Stun <= 20, "the attacker stays stunned too long to guard after a BURST")
	expect(burst.Cooldown >= 600, "the BURST comes back too often to play around it")
	expect((MoveData.Kits.ASURA.Stats.DamageTaken or 1) < 1, "ASURA's hide takes full damage")
	-- a second long combo during the cooldown is not broken
	boss.comboHits, boss.stun, boss.stunKind = burst.Hits, 40, "Hit"
	local again = find(run(w, 30, function(t) return { input({ light = t == 1 }) } end), "Burst")
	expect(not again, "ASURA burst again during the cooldown")
end)

test("KUROEN SHIN's DIVINE INSTINCT: blows in neutral are evaded (2 charges), then they land; the charges come back", function()
	local w = kitDuel("KAI", "KUROEN SHIN", 2.4)
	w.training = false
	local boss = w.fighters[2]
	local spec = MoveData.Kits["KUROEN SHIN"].Stats.AutoEvade
	expect(spec and boss.evadeCharges == spec.Charges, "KUROEN SHIN has no DIVINE INSTINCT")
	local evades, hit = 0, nil
	for round = 1, 3 do
		w.fighters[1].x, boss.x = -1.2, 1.2
		local events = run(w, 60, function(t) return { input({ light = t == 1 }) } end)
		for _, e in events do
			if e.kind == "Evade" and e.defender == 2 then evades += 1 end
			if e.kind == "Hit" and e.defender == 2 and round == 3 then hit = e end
		end
	end
	expect(evades == spec.Charges, string.format("%d evades instead of %d", evades, spec.Charges))
	expect(hit, "the blow after the charges were spent did not land")
	run(w, spec.Cooldown * spec.Charges + 10)
	expect(boss.evadeCharges == spec.Charges, "the DIVINE INSTINCT charges did not come back")
end)

-- ===================================================================== KAZAN 鎖 (claws)
test("KAZAN's claws: no whip reach any more (short and middle range); SHACKLE HOOK catches and holds", function()
	local far = 0
	for _, id in MoveData.Kits.KAZAN.Roles do
		local m = Moves[id]
		if m.hitbox and (m.kind or "Normal") == "Normal" then far = math.max(far, m.hitbox.far) end
	end
	local spear = 0
	for _, id in MoveData.Kits.RAIJIN.Roles do
		local m = Moves[id]
		if m.hitbox and (m.kind or "Normal") == "Normal" then spear = math.max(spear, m.hitbox.far) end
	end
	expect(far < spear * 0.95 and far <= 4.9, string.format("KAZAN still reaches like a whip (%.2f)", far))
	local hook = Moves[MoveData.Kits.KAZAN.Starters.Crouch.Special]
	expect(hook.name == "SHACKLE HOOK" and not hook.projectile and hook.bind and hook.bind > hook.hitstun, "the hook does not catch")
	local w = kitDuel("KAZAN", "KAI", 3.2)
	local d = w.fighters[2]
	local events = run(w, 30, crouchSpecial)
	expect(find(events, "Hit") ~= nil and d.stun >= hook.hitstun, "SHACKLE HOOK did not hold the target")
end)

test("KAZAN ENTRAVE: 2 chain techniques on the target cut its next dash in half", function()
	local w = kitDuel("KAZAN", "KAI", 3)
	local a, d = w.fighters[1], w.fighters[2]
	local m = Moves[MoveData.Kits.KAZAN.Starters.Ground.Special]
	PASSIVE.onHit(w, a, d, m, nil, true, {})
	expect(not d.shackled, "one hit already shackles")
	PASSIVE.onHit(w, a, d, m, nil, true, {})
	expect(d.shackled, "two hits did not shackle")
	local events = run(w, 2, function(t) return { nil, input({ dash = t == 1, axis = -1 }) } end)
	expect(find(events, "ShackleDash") ~= nil and d.dashTicks <= math.ceil(Config.DashTicks / 2), "the dash was not cut")
	expect(not d.shackled, "the shackle was not spent")
end)

test("KUREN PACTE ÉCARLATE: each technique costs 3 % of his health (never below 1) and hits 30 % harder", function()
	local w = kitDuel("KUREN", "KAI", 3)
	local a = w.fighters[1]
	run(w, 2, special)
	expect(a.hp == a.maxHp - math.floor(a.maxHp * 0.03), "the pact cost " .. (a.maxHp - a.hp))
	expect(math.abs(PASSIVE.bonus(w, a, Moves[a.move], nil) - 1.3) < 1e-6, "no pact bonus on the technique")
	local low = kitDuel("KUREN", "KAI", 3)
	low.fighters[1].hp = 2
	run(low, 2, special)
	expect(low.fighters[1].hp == 1 and low.fighters[1].state ~= "KO", "the pact killed him")
end)

test("SYLVA RACINES VORACES: a trap on the floor slows and hurts; TERRITOIRE lengthens her reach", function()
	local w = kitDuel("SYLVA", "KAI", 8)
	local a, d = w.fighters[1], w.fighters[2]
	run(w, 40, crouchSpecial)
	local trap
	for _, p in w.projectiles do if p.data.trap then trap = p end end
	expect(trap ~= nil and trap.vx == 0, "no trap on the floor")
	run(w, 1, jab)
	expect(a.reachMove == a.moveSerial and a.reachScale > 1, "a trap nearby did not lengthen her reach")
	local events = run(w, 120, { nil, input({ axis = -1 }) })
	expect(find(events, "Hit") ~= nil and d.chilled > 0, "the trap did not catch the opponent")
end)

test("ELIAN IMPULSION VITALE heals; SECOND SOUFFLE: three times more once, under 30 %", function()
	local w = kitDuel("ELIAN", "KAI", 2.8)
	local a = w.fighters[1]
	a.hp = a.maxHp - 200
	run(w, 30, crouchSpecial)
	expect(a.hp == a.maxHp - 200 + math.floor(a.maxHp * 0.04 + 0.5), "the pulse healed " .. (a.hp - (a.maxHp - 200)))
	local low = kitDuel("ELIAN", "KAI", 2.8)
	local e = low.fighters[1]
	e.hp = math.floor(e.maxHp * 0.2)
	local before = e.hp
	run(low, 30, crouchSpecial)
	expect(e.hp - before == math.floor(e.maxHp * 0.12 + 0.5) and e.secondWindUsed, "SECOND SOUFFLE did not triple the heal")
end)

test("NOVA SENTINELLE: a drone fires three times on its own; 2 drones, back over time", function()
	local w = kitDuel("NOVA", "KAI", 8)
	local a = w.fighters[1]
	local events = run(w, 200, crouchSpecial)
	expect(find(events, "Drone") ~= nil and a.droneCharges <= 1, "no drone sent")
	expect(count(events, "DroneShot") == 3, "the drone fired " .. count(events, "DroneShot") .. " times")
	expect(#w.drones == 0, "the drone stayed after its shots")
	a.droneCharges, a.droneCharge = 0, 600
	local empty = run(w, 30, crouchSpecial)
	expect(find(empty, "Drone") == nil and find(empty, "PassiveEmpty") ~= nil, "a drone came out with no charge left")
end)

test("a target left launched on the floor with no speed (after a cinematic, a spike) lands at once, never hangs", function()
	local world = Sim.newWorld(Config, MoveData, false)
	world.phase = "Fight"
	local d = world.fighters[2]
	d.launched, d.y, d.vy = true, 0, 0
	Sim.step(world, { Sim.neutralInput(), Sim.neutralInput() })
	expect(not d.launched and d.state == "Knockdown", "still " .. d.state)
	-- spiked on the floor with a bounce pending: it bounces
	d.knockdown, d.getUp, d.state = 0, 0, "Idle"
	d.launched, d.y, d.vy, d.pendingBounce = true, 0, -30, true
	Sim.step(world, { Sim.neutralInput(), Sim.neutralInput() })
	expect(d.launched and d.vy > 0, "no bounce")
end)

test("COUNTER HIT: a blow that catches the opponent starting its own attack hits harder and stuns longer", function()
	local function exchange(late)
		local world = Sim.newWorld(Config, MoveData, false)
		world.phase = "Fight"
		local a, d = world.fighters[1], world.fighters[2]
		a.x, d.x = -1.5, 1.5
		local events = {}
		-- P2 starts its slow heavy blow and P1 jabs into its startup (`still`: P2 just stands).
		local i2 = Sim.neutralInput()
		i2.heavy = not late
		Sim.step(world, { Sim.neutralInput(), i2 })
		local i1 = Sim.neutralInput()
		i1.light = true
		for _ = 1, 30 do
			for _, e in Sim.step(world, { i1, Sim.neutralInput() }) do
				if e.kind == "Hit" and e.attacker == 1 then table.insert(events, e) end
			end
			i1 = Sim.neutralInput()
		end
		return events[1], d
	end
	local counter = exchange(false)
	local plain = exchange(true)
	expect(counter and counter.counter == true, "no counter hit on a startup")
	expect(plain and not plain.counter, "a counter hit on a neutral opponent")
	expect(counter.damage > plain.damage, string.format("counter %d, plain %d", counter.damage, plain.damage))
	expect(counter.damage <= plain.damage * 1.2, "a counter hit worth more than a read")
end)

test("COUNTER HIT is a read, never a cheat: not on a string's next blow, not on a jab, never inside a combo", function()
	local function caught(setup)
		local world = Sim.newWorld(Config, MoveData, false)
		world.phase = "Fight"
		local a, d = world.fighters[1], world.fighters[2]
		a.x, d.x = -1.5, 1.5
		local i2 = Sim.neutralInput()
		if setup == "jab" then i2.light = true else i2.heavy = true end
		Sim.step(world, { Sim.neutralInput(), i2 })
		if setup == "link" then d.moveFresh = false end -- (the heavy as the next blow of a string)
		local i1 = Sim.neutralInput()
		i1.light = true
		for _ = 1, 30 do
			for _, e in Sim.step(world, { i1, Sim.neutralInput() }) do
				if e.kind == "Hit" and e.attacker == 1 then return e end
			end
			i1 = Sim.neutralInput()
		end
		return nil
	end
	local fresh = caught("fresh")
	expect(fresh and fresh.counter, "a fresh slow blow read and caught is not a counter hit")
	local link = caught("link")
	expect(link == nil or not link.counter, "the next blow of a string was counter-hit (it would break combos)")
	local jab = caught("jab")
	expect(jab == nil or not jab.counter, "a jab trade gave a counter hit")
end)

T.finish()
