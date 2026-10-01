-- Offline tests of the four kits (KAI, TARO, ZEPHYR, AKEMI). Run from the repository root:
--   luau tests/Kits.test.luau
local Config = require("../src/shared/CombatConfig")
local MoveData = require("../src/shared/MoveData")
local Sim = require("../src/shared/CombatSimulation")
local T = require("./TestKit")
local test, expect, input = T.test, T.expect, T.input
local Moves, Kits = MoveData.Moves, MoveData.Kits

local function kitWorld(kit, foe, gap, training)
	local world = Sim.newWorld(Config, MoveData, if training == nil then true else training)
	Sim.setKits(world, kit, foe or "KAI")
	world.phase = "Fight"
	world.fighters[1].x, world.fighters[2].x = -gap / 2, gap / 2
	return world
end

local function run(world, ticks, inputs)
	local all = {}
	for t = 1, ticks do
		local i = if type(inputs) == "function" then inputs(t) else inputs
		for _, e in Sim.step(world, { (i and i[1]) or Sim.neutralInput(), (i and i[2]) or Sim.neutralInput() }) do
			e.tick = t
			table.insert(all, e)
		end
	end
	return all
end

local function find(events, kind)
	for _, e in events do if e.kind == kind then return e end end
	return nil
end

local function count(events, kind)
	local n = 0
	for _, e in events do if e.kind == kind then n += 1 end end
	return n
end

local function compactRoute(events)
	local list = {}
	for _, e in events do
		if e.kind == "Hit" and not e.cinematic and list[#list] ~= e.move then table.insert(list, e.move) end
	end
	return table.concat(list, ",")
end

local function split(keys)
	local list = {}
	for k in keys:gmatch("%S") do
		if k ~= "↑" then table.insert(list, k) end
	end
	return list
end

-- Plays keys like a player with rhythm: each press `reaction` ticks after the current move
-- connected (all its hits out). Optional: keep the meter full, answer the rhythm prompts.
local function play(world, keys, options)
	options = options or {}
	local events, step, pressedFor, waited = {}, 1, nil, 0
	for _ = 1, options.ticks or 700 do
		local a = world.fighters[1]
		local i = input()
		local key = a.move and (a.move .. tostring(a.moveContact ~= nil))
		local ready = step == 1 or (a.move and a.moveContact and key ~= pressedFor
			and a.moveHits >= (Moves[a.move].hits or 1))
		if keys[step] and ready then
			waited += 1
			if waited > (options.reaction or 0) then
				local k = keys[step]
				if k == "L" then i.light = true elseif k == "R" then i.heavy = true else i.ultimate = true end
				pressedFor, step, waited = key, step + 1, 0
			end
		end
		if options.meter and step <= #keys then a.meter = Config.MaxMeter end
		if world.cinematic and options.prompts then
			local state = world.cinematic
			local prompt = state.prompts[state.nextPrompt]
			if prompt and state.tick + 1 == prompt.tick then
				if prompt.button == "Light" then i.light = true
				elseif prompt.button == "Heavy" then i.heavy = true else i.ultimate = true end
			end
		end
		for _, e in Sim.step(world, { i, Sim.neutralInput() }) do table.insert(events, e) end
	end
	return events
end

print("Kits")

test("the four kits exist, with their own moves for every role", function()
	expect(#MoveData.KitOrder == 4, "kit count")
	for _, name in MoveData.KitOrder do
		local kit = Kits[name]
		expect(kit and kit.Stats.MaxHealth > 0, name .. " has no stats")
		for role, id in kit.Roles do
			expect(Moves[id], name .. ": role " .. role .. " has no move " .. tostring(id))
			if name ~= "KAI" then expect(id ~= role, name .. " reuses KAI's move " .. role) end
		end
		for _, kind in { "Rush", "Awaken", "Gate" } do
			local id = kit.Ultimates[kind]
			expect(MoveData.Cinematics[id] and MoveData.Cinematics[id].Type == kind, name .. " has no " .. kind .. " cinematic")
		end
	end
end)

for _, name in MoveData.KitOrder do
	test(name .. ": every 6-press route connects (reaction 4-14 ticks, two distances)", function()
		for _, route in Kits[name].FullRoutes do
			for _, reaction in { 4, 14 } do
				for _, gap in { 3, 4.4 } do
					local world = kitWorld(name, "KAI", gap)
					local events = play(world, split(route.keys), { reaction = reaction, ticks = 500 })
					expect(compactRoute(events) == table.concat(route.moves, ","),
						string.format("%s %s dropped (reaction %d, gap %.1f): %s", name, route.name, reaction, gap, compactRoute(events)))
				end
			end
		end
	end)

	test(name .. ": every short route and skill connects", function()
		for _, route in Kits[name].Routes do
			if not route.keys:find("↑") then
				local world = kitWorld(name, "KAI", 3)
				local events = play(world, split(route.keys), { reaction = 6, ticks = 400 })
				expect(compactRoute(events) == table.concat(route.moves, ","),
					string.format("%s %s: %s", name, route.name, compactRoute(events)))
				if route.name:find("★") then
					expect(find(events, "Skill") ~= nil, name .. " " .. route.name .. ": no skill announced")
				end
			end
		end
	end)

	test(name .. ": the three ultimates (R alone, clean route + right click, clean route + R)", function()
		local kit = Kits[name]
		local rush = kitWorld(name, "KAI", 3, false)
		rush.fighters[1].meter = Config.MaxMeter
		local e1 = play(rush, { "L", "L", "U" }, { ticks = 400 })
		local s1 = find(e1, "CinematicStart")
		expect(s1 and s1.move == kit.Ultimates.Rush, name .. ": no rush cinematic")
		for _, route in kit.FullRoutes do
			for _, last in { "R", "U" } do
				local world = kitWorld(name, "KAI", 3, false)
				local keys = split(route.keys)
				keys[6] = last
				local events = play(world, keys, { meter = true, prompts = true, ticks = 900 })
				local start = find(events, "CinematicStart")
				local expected = if last == "R" then kit.Ultimates.Awaken else kit.Ultimates.Gate
				expect(start and start.move == expected and start.style == route.name,
					string.format("%s %s + %s: %s (%s)", name, route.name, last, tostring(start and start.move), compactRoute(events)))
			end
		end
	end)

	test(name .. ": the lab plays its three cinematics", function()
		for _, kind in { "Rush", "Awaken", "Gate" } do
			local world = kitWorld(name, "KAI", 6, false)
			local events = Sim.debugCinematic(world, 1, kind, Kits[name].FullRoutes[1].name, nil)
			expect(world.cinematic and world.cinematic.move == Kits[name].Ultimates[kind], name .. " lab " .. kind)
			local _ = events
			for _ = 1, 600 do
				Sim.step(world, { Sim.neutralInput(), Sim.neutralInput() })
				if not world.cinematic then break end
			end
			expect(world.cinematic == nil, name .. " " .. kind .. " cinematic never ended")
		end
	end)
end

test("stats: health, walk speed and jump height differ per kit", function()
	local hp, speed, jump = {}, {}, {}
	for _, name in MoveData.KitOrder do
		local world = kitWorld(name, "KAI", 20)
		local a = world.fighters[1]
		hp[name] = a.hp
		local x0 = a.x
		run(world, 30, { input({ axis = 1 }) })
		speed[name] = a.x - x0
		local top = 0
		run(world, 60, function(t)
			top = math.max(top, a.y)
			return { input({ jump = t == 1 }) }
		end)
		jump[name] = top
	end
	expect(hp.TARO > hp.KAI and hp.KAI > hp.ZEPHYR and hp.ZEPHYR > hp.AKEMI, "health order")
	expect(speed.AKEMI > speed.KAI and speed.ZEPHYR > speed.KAI and speed.TARO < speed.KAI, "walk speed order")
	expect(jump.ZEPHYR > jump.KAI and jump.TARO < jump.KAI, "jump order")
end)

test("ZEPHYR outranges KAI and TARO from the same distance", function()
	local function lands(name, gap)
		local world = kitWorld(name, "KAI", gap)
		return count(run(world, 30, function(t) return { input({ light = t == 1 }) } end), "Hit") > 0
	end
	expect(lands("ZEPHYR", 5.4), "ZEPHYR's front kick does not reach")
	expect(not lands("KAI", 5.4) and not lands("TARO", 5.4), "punches reach as far as kicks")
end)

test("TARO: the guard takes less damage (garde de fer)", function()
	local function guardAfter(name)
		local world = kitWorld("KAI", name, 3)
		run(world, 40, function(t) return { input({ heavy = t == 1 }), input({ block = true }) } end)
		return world.fighters[2].guard
	end
	expect(guardAfter("TARO") > guardAfter("KAI"), "TARO's guard is not tougher")
end)

test("TARO: PARADE (crouch + E) counters a standing attack", function()
	local world = kitWorld("KAI", "TARO", 3)
	local events = run(world, 60, function(t)
		-- FRAPPE LOURDE winds up 13 ticks: the parry, pressed at tick 6, catches it.
		return { input({ heavy = t == 1 }), input({ crouch = t <= 7, special = t == 6 }) }
	end)
	expect(find(events, "Parry") ~= nil, "no parry")
	local hit = find(events, "Hit")
	expect(hit and hit.move == "TaroCounter" and hit.defender == 1, "the counter did not land")
	expect(world.fighters[2].hp == world.fighters[2].maxHp, "TARO took damage through the parry")
end)

test("TARO: a low attack beats the parry, and a whiffed parry can be punished", function()
	local low = kitWorld("KAI", "TARO", 3)
	local e1 = run(low, 40, function(t)
		return { input({ crouch = t <= 2, light = t == 2 }), input({ crouch = t <= 3, special = t == 1 }) }
	end)
	expect(find(e1, "Parry") == nil and find(e1, "Hit") ~= nil, "the low kick was parried")
	local whiff = kitWorld("KAI", "TARO", 3)
	local e2 = run(whiff, 60, function(t)
		return { input({ light = t == 24 }), input({ crouch = t <= 3, special = t == 1 }) }
	end)
	local hit = find(e2, "Hit")
	expect(hit and hit.attacker == 1, "the parry recovery was not punishable")
end)

test("TARO: the forward dash weaves under high attacks (slip + ki), lows still hit", function()
	local world = kitWorld("KAI", "TARO", 4)
	local taro = world.fighters[2]
	local events = run(world, 30, function(t)
		return { input({ light = t == 1 }), input({ dash = t == 1, axis = -1 }) }
	end)
	expect(find(events, "Slip") ~= nil, "the jab was not slipped")
	expect(find(events, "Hit") == nil and taro.hp == taro.maxHp, "the jab hit through the weave")
	expect(taro.meter > 0, "slipping gave no ki")
	local low = kitWorld("KAI", "TARO", 4)
	local e2 = run(low, 30, function(t)
		return { input({ crouch = t <= 3, light = t == 1 }), input({ dash = t == 1, axis = -1 }) }
	end)
	expect(find(e2, "Hit") ~= nil and find(e2, "Slip") == nil, "a low attack was slipped")
	-- Only toward the opponent: a back dash is not a weave.
	local back = kitWorld("KAI", "TARO", 4)
	run(back, 2, function() return { nil, input({ dash = true, axis = 1 }) } end)
	expect(back.fighters[2].weaveTicks == 0 and back.fighters[2].dashTicks > 0, "the back dash weaves")
	-- Not a KAI thing.
	local kai = kitWorld("TARO", "KAI", 4)
	run(kai, 2, function() return { nil, input({ dash = true, axis = -1 }) } end)
	expect(kai.fighters[2].weaveTicks == 0, "KAI weaves")
end)

local function dempsey(keys, ticks)
	local world = kitWorld("TARO", "KAI", 6)
	run(world, 3, function(t) return { input({ dash = t == 1, axis = 1 }) } end)
	local events = play(world, keys, { reaction = 3, ticks = ticks or 400 })
	local hooks = {}
	for _, e in events do
		if e.kind == "Hit" and e.attacker == 1 then table.insert(hooks, e.move) end
	end
	return hooks, world, events
end

test("TARO: DEMPSEY ROLL out of the weave: alternating hooks, then the finishing hook", function()
	local hooks = dempsey({ "L", "L", "L", "L", "L", "L", "R" })
	expect(table.concat(hooks, ",") == "TaroDempseyL,TaroDempseyR,TaroDempseyL,TaroDempseyR,TaroDempseyL,TaroDempseyR,TaroDempseyFinish",
		"roll: " .. table.concat(hooks, ","))
	-- Six hooks at most.
	local capped = dempsey({ "L", "L", "L", "L", "L", "L", "L", "L" })
	expect(#capped == 6, "the roll went on for " .. #capped .. " hooks")
	-- R straight out of the weave: the finishing hook alone.
	local finish, world = dempsey({ "R" }, 24)
	expect(finish[1] == "TaroDempseyFinish", "R out of the weave: " .. tostring(finish[1]))
	expect(world.fighters[2].launched, "the finishing hook did not send the target flying")
	-- Without the weave, L is still the jab.
	local plain = kitWorld("TARO", "KAI", 3)
	local events = run(plain, 30, function(t) return { input({ light = t == 1 }) } end)
	local hit = find(events, "Hit")
	expect(hit and hit.move == "TaroJab", "a plain L is no longer the jab")
end)

test("TARO: each DEMPSEY hook ducks under a high attack at its start", function()
	local world = kitWorld("KAI", "TARO", 3.4)
	local taro = world.fighters[2]
	taro.dempseyWindow = 10 -- as right after the weave
	local events = run(world, 20, function(t)
		-- KAI's jab is out (ticks 6-8) during the first frames of TARO's hook (pressed at 4).
		return { input({ light = t == 1 }), input({ light = t == 4 }) }
	end)
	expect(taro.move == nil or Moves[taro.move].dempsey, "TARO did not roll")
	local slipped = find(events, "Slip")
	local kaiHit = false
	for _, e in events do if e.kind == "Hit" and e.defender == 2 then kaiHit = true end end
	expect(slipped ~= nil and not kaiHit, "the jab hit TARO during the hook's start")
end)

test("AKEMI: VOILE D'OMBRE evades the first hit, then recharges", function()
	local world = kitWorld("KAI", "AKEMI", 3)
	local d = world.fighters[2]
	local events = run(world, 40, function(t) return { input({ light = t == 1 }) } end)
	expect(find(events, "Evade") ~= nil and find(events, "Hit") == nil, "the first jab was not evaded")
	expect(d.hp == d.maxHp, "damage through the evade")
	world.fighters[1].x = d.x - 3
	local again = run(world, 40, function(t) return { input({ light = t == 1 }) } end)
	expect(find(again, "Hit") ~= nil, "evaded again during the recharge")
	run(world, Kits.AKEMI.Passive.Cooldown, nil)
	world.fighters[1].x = d.x - 3
	local later = run(world, 40, function(t) return { input({ light = t == 1 }) } end)
	expect(find(later, "Evade") ~= nil, "the passive did not recharge")
end)

test("AKEMI: no evade while guarding, in a combo or against an ultimate", function()
	local guard = kitWorld("KAI", "AKEMI", 3)
	local e1 = run(guard, 40, function(t) return { input({ light = t == 1 }), input({ block = true }) } end)
	expect(find(e1, "Block") ~= nil and find(e1, "Evade") == nil, "a guarded hit was evaded")
	local combo = kitWorld("KAI", "AKEMI", 3)
	combo.fighters[2].evadeCharge = 999
	local e2 = play(combo, { "L", "L" }, { ticks = 60 })
	expect(find(e2, "Evade") == nil, "evaded while recharging")
	local ultimate = kitWorld("KAI", "AKEMI", 3)
	ultimate.fighters[1].meter = Config.MaxMeter
	local e3 = run(ultimate, 60, function(t) return { input({ ultimate = t == 1 }) } end)
	expect(find(e3, "Evade") == nil and find(e3, "CinematicStart") ~= nil, "the ultimate was evaded")
end)

test("AKEMI: the dash slips through attacks", function()
	local world = kitWorld("KAI", "AKEMI", 4)
	world.fighters[2].evadeCharge = 999 -- passive spent: only the dash protects
	local events = run(world, 30, function(t)
		return { input({ light = t == 1 }), input({ dash = t == 4, axis = -1 }) }
	end)
	expect(find(events, "Hit") == nil, "the dash did not slip through the jab")
end)

test("balance: no kit wins more than 65 % or less than 35 % against the field (CPU vs CPU)", function()
	local Balance = require("./BalanceKit")
	for _, level in { 3, 4 } do
		local matrix = Balance.matrix(level, 60) -- 30 matches per duel was within noise of the bounds
		for _, a in MoveData.KitOrder do
			local total, n = 0, 0
			for _, b in MoveData.KitOrder do
				if a ~= b then total += matrix[a][b]; n += 1 end
			end
			local average = total / n
			expect(average > 0.35 and average < 0.65,
				string.format("%s wins %d %% at level %d", a, math.floor(average * 100 + 0.5), level))
		end
	end
end)

T.finish()
