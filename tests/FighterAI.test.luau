-- Offline tests for the CPU opponent. Run from the repository root:
--   luau tests/FighterAI.test.luau
local Config = require("../src/shared/CombatConfig")
local MoveData = require("../src/shared/MoveData")
local Sim = require("../src/shared/CombatSimulation")
local FighterAI = require("../src/shared/FighterAI")
local T = require("./TestKit")
local test, expect, input = T.test, T.expect, T.input

local function versus(level1, level2, seed, ticks)
	local world = Sim.newWorld(Config, MoveData, false)
	local brains = { level1 and FighterAI.new(level1, seed), level2 and FighterAI.new(level2, seed * 7 + 3) }
	local stats = { damage = { 0, 0 }, blocks = { 0, 0 }, routes = {}, ultimates = 0, rounds = 0 }
	for _ = 1, ticks do
		local inputs = {}
		for slot = 1, 2 do
			inputs[slot] = if brains[slot] then brains[slot]:think(world, slot) else Sim.neutralInput()
			local i = inputs[slot]
			assert(type(i.axis) == "number" and i.axis >= -1 and i.axis <= 1, "bad axis")
		end
		for _, e in Sim.step(world, inputs) do
			if e.kind == "Hit" then
				stats.damage[e.attacker] += e.damage
				stats.routes[e.move] = (stats.routes[e.move] or 0) + 1
			elseif e.kind == "Block" then
				stats.blocks[e.defender] += 1
			elseif e.kind == "CinematicStart" then
				stats.ultimates += 1
			elseif e.kind == "RoundEnd" then
				stats.rounds += 1
			end
		end
	end
	return stats, world
end

print("FighterAI")

test("every level fights a standing opponent and deals damage", function()
	for level = 1, #FighterAI.Levels do
		local stats = versus(level, nil, 11, 60 * 30)
		expect(stats.damage[1] > 0, FighterAI.Levels[level].name .. " dealt no damage")
	end
end)

test("CPU vs CPU plays full matches without errors", function()
	for level = 1, #FighterAI.Levels do
		local stats = versus(level, level, level * 13, 60 * 180)
		expect(stats.rounds >= 1, FighterAI.Levels[level].name .. " never finished a round")
	end
end)

test("LÉGENDE beats FACILE over several matches", function()
	local legend, easy = 0, 0
	for seed = 1, 4 do
		local stats = versus(4, 1, seed, 60 * 90)
		legend += stats.damage[1]
		easy += stats.damage[2]
	end
	expect(legend > easy * 1.5, string.format("legend %d vs easy %d", legend, easy))
end)

test("higher levels guard more against the same pressure", function()
	local function blockRate(level)
		local world = Sim.newWorld(Config, MoveData, true)
		world.fighters[1].x, world.fighters[2].x = -1.5, 1.5
		local brain = FighterAI.new(level, 5)
		local blocks, hits = 0, 0
		for t = 1, 60 * 40 do
			local cpu = brain:think(world, 2)
			cpu.light, cpu.heavy, cpu.special, cpu.ultimate, cpu.dash, cpu.jump, cpu.axis = false, false, false, false, false, false, 0
			for _, e in Sim.step(world, { input({ light = t % 50 == 1 }), cpu }) do
				if e.kind == "Block" then blocks += 1 elseif e.kind == "Hit" then hits += 1 end
			end
			world.fighters[1].x, world.fighters[2].x = -1.5, 1.5
		end
		return blocks / math.max(1, blocks + hits)
	end
	local easy, legend = blockRate(1), blockRate(4)
	expect(legend > easy + 0.3, string.format("block rate easy %.2f, legend %.2f", easy, legend))
end)

test("LÉGENDE uses combo routes and the ultimate", function()
	local stats = versus(4, 2, 3, 60 * 180)
	local used = 0
	for _ in stats.routes do used += 1 end
	expect(used >= 5, "only " .. used .. " different moves landed")
	expect(stats.ultimates >= 1, "never landed an ultimate")
end)

test("under constant pressure every CPU level fights back", function()
	-- A player who only attacks: walks in and strings JAB > CROSS > COUDE every 30 ticks.
	for level = 1, #FighterAI.Levels do
		local world = Sim.newWorld(Config, MoveData, false)
		world.phase = "Fight"
		world.fighters[1].x, world.fighters[2].x = -2, 2
		local brain = FighterAI.new(level, 9)
		local cpuDamage, cpuHits = 0, 0
		for t = 1, 60 * 45 do
			local p = t % 30
			local player = input({ axis = 1, light = p == 1 or p == 7 or p == 13 })
			for _, e in Sim.step(world, { player, brain:think(world, 2) }) do
				if e.kind == "Hit" and e.attacker == 2 then cpuDamage += e.damage; cpuHits += 1 end
			end
		end
		expect(cpuHits >= 3, FighterAI.Levels[level].name .. " only hit back " .. cpuHits .. " times")
	end
end)

test("CPU zones with ki blasts at long range", function()
	local world = Sim.newWorld(Config, MoveData, false)
	world.phase = "Fight"
	world.fighters[1].x, world.fighters[2].x = -20, 20
	local brain = FighterAI.new(4, 21)
	local blasts = 0
	for _ = 1, 60 * 20 do
		for _, e in Sim.step(world, { input({ axis = -1 }), brain:think(world, 2) }) do
			if e.kind == "Projectile" and e.attacker == 2 then blasts += 1 end
		end
		world.fighters[1].x = math.min(world.fighters[1].x, world.fighters[2].x - 12)
	end
	expect(blasts >= 1, "LÉGENDE never threw a ki blast")
end)

test("the same seed replays the same fight", function()
	local a = versus(3, 2, 42, 60 * 30)
	local b = versus(3, 2, 42, 60 * 30)
	expect(a.damage[1] == b.damage[1] and a.damage[2] == b.damage[2], "non-deterministic CPU")
end)

T.finish()
