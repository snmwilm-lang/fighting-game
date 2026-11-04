-- Run from the repository root: luau tests/PressQueue.test.luau
local Config = require("../src/shared/CombatConfig")
local MoveData = require("../src/shared/MoveData")
local Sim = require("../src/shared/CombatSimulation")
local PressQueue = require("../src/shared/PressQueue")
local T = require("./TestKit")
local test, expect = T.test, T.expect

test("packets: only short arrays of known buttons are accepted", function()
	expect(PressQueue.valid({ "light", "heavy" }), "a normal list is refused")
	expect(PressQueue.valid({}), "an empty list is refused")
	expect(not PressQueue.valid({ "light", "kick" }), "an unknown button is accepted")
	expect(not PressQueue.valid({ light = true }), "a map is accepted")
	expect(not PressQueue.valid({ "light", 3 }), "a number is accepted")
	expect(not PressQueue.valid("light"), "a string is accepted")
	local long = {}
	for i = 1, PressQueue.MAX_PACKET + 1 do long[i] = "light" end
	expect(not PressQueue.valid(long), "an oversized list is accepted")
end)

test("two presses between two ticks stay two presses, in their order", function()
	local q = PressQueue.new()
	PressQueue.push(q, { "heavy", "light" })
	PressQueue.push(q, { "light" })
	local order = {}
	for _ = 1, 5 do
		local input = Sim.neutralInput()
		local b = PressQueue.pop(q, input)
		if b then
			table.insert(order, b)
			local set = 0
			for _, field in { "light", "heavy", "special", "ultimate" } do
				if input[field] then set += 1 end
			end
			expect(set == 1, "more than one press handed in a single tick")
		end
	end
	expect(table.concat(order, " ") == "heavy light light", "order " .. table.concat(order, " "))
end)

test("overflow drops the oldest press", function()
	local q = PressQueue.new()
	local list = {}
	for i = 1, PressQueue.CAPACITY + 2 do list[i] = if i <= 2 then "heavy" else "light" end
	PressQueue.push(q, list)
	expect(#q.items == PressQueue.CAPACITY and q.items[1] == "light", "overflow kept the oldest presses")
end)

test("a heavy then a light, sent in one packet, play R then L in the simulation", function()
	local world = Sim.newWorld(Config, MoveData, true)
	local a, d = world.fighters[1], world.fighters[2]
	a.x, d.x = 0, 1.6
	local q = PressQueue.new()
	PressQueue.push(q, { "heavy", "light" })
	local starters = {}
	for _ = 1, 90 do
		local input = Sim.neutralInput()
		PressQueue.pop(q, input)
		Sim.step(world, { input, Sim.neutralInput() })
		if a.move and starters[#starters] ~= a.move then table.insert(starters, a.move) end
	end
	local kai = MoveData.Kits.KAI.Starters.Ground
	expect(starters[1] == kai.Heavy, "the first attack is " .. tostring(starters[1]) .. ", not the heavy one")
end)

T.finish()
