-- Offline tests for the authoritative simulation. Run from the repository root:
--   luau tests/CombatSimulation.test.luau
local Config = require("../src/shared/CombatConfig")
local MoveData = require("../src/shared/MoveData")
local Sim = require("../src/shared/CombatSimulation")

local passed, failed = 0, 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print("  ok   " .. name)
	else
		failed += 1
		print("  FAIL " .. name .. "\n       " .. tostring(err))
	end
end
local function expect(cond, message)
	if not cond then error(message, 2) end
end

local function input(fields)
	local i = Sim.neutralInput()
	for k, v in fields or {} do i[k] = v end
	return i
end

-- Training world with both fighters standing `gap` studs apart, facing each other.
local function closeWorld(gap, training)
	local world = Sim.newWorld(Config, MoveData, if training == nil then true else training)
	world.phase = "Fight"
	world.fighters[1].x, world.fighters[2].x = -gap / 2, gap / 2
	return world
end

local function run(world, ticks, inputs)
	local all = {}
	for t = 1, ticks do
		local i1 = if type(inputs) == "function" then inputs(t) else inputs
		local events = Sim.step(world, { (i1 and i1[1]) or Sim.neutralInput(), (i1 and i1[2]) or Sim.neutralInput() })
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

print("CombatSimulation")

test("jab hits once, on the first active tick", function()
	local world = closeWorld(3)
	local events = run(world, 40, function(t) return { input({ light = t == 1 }) } end)
	expect(count(events, "Hit") == 1, "expected exactly one hit, got " .. count(events, "Hit"))
	expect(events[1].tick == MoveData.Moves.Jab.startup + 1, "hit on tick " .. events[1].tick)
	expect(world.fighters[2].hp == Config.MaxHealth - MoveData.Moves.Jab.damage, "damage " .. world.fighters[2].hp)
end)

test("hitstop freezes the move frame counter", function()
	local world = closeWorld(3)
	run(world, MoveData.Moves.Jab.startup + 1, function(t) return { input({ light = t == 1 }) } end)
	local a = world.fighters[1]
	local frame = a.moveFrame
	expect(a.hitstop == MoveData.Moves.Jab.hitstop, "hitstop " .. a.hitstop)
	run(world, a.hitstop)
	expect(a.moveFrame == frame, "frame advanced during hitstop")
	run(world, 1)
	expect(a.moveFrame == frame + 1, "frame did not resume")
end)

test("holding block reduces damage and spends guard", function()
	local world = closeWorld(3)
	local events = run(world, 40, function(t) return { input({ light = t == 1 }), input({ block = true }) } end)
	expect(count(events, "Block") == 1 and count(events, "Hit") == 0, "expected a block")
	local chip = math.floor(MoveData.Moves.Jab.damage * Config.BlockDamageRatio + 0.5)
	expect(world.fighters[2].hp == Config.MaxHealth - chip, "blocked damage " .. world.fighters[2].hp)
	expect(world.fighters[2].guard < Config.MaxGuard, "guard not spent")
end)

test("air kick cannot be crouch-blocked", function()
	local world = closeWorld(3)
	local hit = false
	for t = 1, 80 do
		local p1 = input({ jump = t == 1, light = t == 32 }) -- strike on the way down
		local events = Sim.step(world, { p1, input({ block = true, crouch = true }) })
		for _, e in events do
			if e.kind == "Hit" and e.move == "AirKick" then hit = true end
		end
	end
	expect(hit, "crouch block stopped an overhead air kick")
end)

test("four lights then heavy chain into the launcher", function()
	local world = closeWorld(3)
	-- Mash: press the next button every 6 ticks; the buffer and cancel windows do the rest.
	local presses = { [1] = "light", [7] = "light", [13] = "light", [19] = "light", [25] = "light", [31] = "light", [37] = "light",
		[43] = "light", [49] = "heavy", [55] = "heavy", [61] = "heavy", [67] = "heavy" }
	local events = run(world, 140, function(t)
		local i = input()
		if presses[t] then i[presses[t]] = true end
		return { i }
	end)
	local moves = {}
	for _, e in events do
		if e.kind == "Hit" then table.insert(moves, e.move) end
	end
	local chain = table.concat(moves, ",")
	expect(chain == "Jab,Cross,Elbow,Kick,Rising", "combo was " .. chain)
	local last = events[#events]
	expect(last.combo == 5, "combo counter " .. tostring(last.combo))
	local unscaled = 45 + 55 + 60 + 75 + 100
	expect(Config.MaxHealth - world.fighters[2].hp < unscaled, "damage scaling not applied")
	expect(world.fighters[2].knockdown > 0 or world.fighters[2].getUp > 0 or world.fighters[2].state == "Idle",
		"launched target never landed")
end)

test("blocked hits never KO", function()
	local world = closeWorld(3, false)
	world.fighters[2].hp = 5
	run(world, 60, function(t) return { input({ heavy = t == 1 }), input({ block = true }) } end)
	expect(world.fighters[2].hp == 1 and world.phase == "Fight", "chip damage killed")
end)

test("knocked-down fighter cannot be hit", function()
	local world = closeWorld(3)
	local d = world.fighters[2]
	d.knockdown = 20
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
	world.fighters[2].x = -10 -- opponent jumps behind mid-attack
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
	local events = run(world, 3)
	local roundEnd
	for _, e in events do if e.kind == "RoundEnd" then roundEnd = e end end
	expect(roundEnd and roundEnd.reason == "Timeout" and roundEnd.winner == 2, "bad timeout result")
end)

test("double KO is a draw that scores for both", function()
	local world = closeWorld(3, false)
	world.fighters[1].hp, world.fighters[2].hp = 10, 10
	local events = run(world, 30, function(t) return { input({ light = t == 1 }), input({ light = t == 1 }) } end)
	local roundEnd
	for _, e in events do if e.kind == "RoundEnd" then roundEnd = e end end
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
end)

test("training refills health after the combo ends", function()
	local world = closeWorld(3)
	run(world, 40, function(t) return { input({ light = t == 1 }) } end)
	expect(world.fighters[2].hp < Config.MaxHealth, "no damage")
	run(world, Config.TrainingRefillTicks + 5)
	expect(world.fighters[2].hp == Config.MaxHealth, "health not refilled")
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

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then error("tests failed") end
