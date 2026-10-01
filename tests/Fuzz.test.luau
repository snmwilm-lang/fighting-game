-- Random-input stress test of the simulation: every kit pairing, random presses and moves
-- (including mashing, guard, jumps, dashes, ultimates), checking invariants every tick.
-- Run from the repository root: luau tests/Fuzz.test.luau
local Config = require("../src/shared/CombatConfig")
local MoveData = require("../src/shared/MoveData")
local Sim = require("../src/shared/CombatSimulation")
local FighterAI = require("../src/shared/FighterAI")
local T = require("./TestKit")
local test, expect = T.test, T.expect

local function finite(n)
	return type(n) == "number" and n == n and math.abs(n) < 1e6
end

-- A random player: holds directions and guard for a while, presses buttons in bursts.
local function randomPlayer(seed)
	local rng = Random and Random.new and Random.new(seed) or nil
	local state = seed
	local function rand()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
	local hold = { axis = 0, crouch = false, block = false, ticks = 0 }
	return function()
		hold.ticks -= 1
		if hold.ticks <= 0 then
			hold.ticks = 5 + math.floor(rand() * 40)
			hold.axis = ({ -1, 0, 0, 1, 1 })[1 + math.floor(rand() * 5)]
			hold.crouch = rand() < 0.15
			hold.block = rand() < 0.2
		end
		local input = Sim.neutralInput()
		input.axis, input.crouch, input.block = hold.axis, hold.crouch, hold.block
		local r = rand()
		if r < 0.06 then input.light = true
		elseif r < 0.10 then input.heavy = true
		elseif r < 0.12 then input.special = true
		elseif r < 0.13 then input.ultimate = true
		elseif r < 0.15 then input.jump = true
		elseif r < 0.16 then input.dash = true
		elseif r < 0.17 then input.light, input.heavy = true, true -- mashing two at once
		end
		return input
	end, rng
end

local STUCK_LIMIT = { Hitstun = 400, Launched = 400, Knockdown = 300, GetUp = 200, Blockstun = 200,
	CrouchBlockstun = 200, Attack = 300, Dashing = 120, Cinematic = 2000, Jumping = 300, Falling = 300 }

local function check(world, label, tick, last)
	local c = world.config
	for i, f in world.fighters do
		for _, key in { "x", "y", "vx", "vy", "pushVx", "hp", "meter", "guard" } do
			expect(finite(f[key]), string.format("%s t%d P%d %s not finite: %s", label, tick, i, key, tostring(f[key])))
		end
		expect(f.hp >= 0 and f.hp <= f.maxHp, string.format("%s t%d P%d hp %s", label, tick, i, tostring(f.hp)))
		expect(f.meter >= 0 and f.meter <= c.MaxMeter, string.format("%s t%d P%d meter %s", label, tick, i, tostring(f.meter)))
		expect(f.guard >= 0 and f.guard <= c.MaxGuard, string.format("%s t%d P%d guard %s", label, tick, i, tostring(f.guard)))
		expect(f.y >= -0.001, string.format("%s t%d P%d under the floor y=%.3f", label, tick, i, f.y))
		expect(f.x >= c.ArenaMinX - 0.01 and f.x <= c.ArenaMaxX + 0.01,
			string.format("%s t%d P%d out of the arena x=%.2f (%s)", label, tick, i, f.x, f.state))
		expect(#f.buffer <= c.BufferSize, string.format("%s t%d P%d buffer %d", label, tick, i, #f.buffer))
		if f.move then expect(world.moves[f.move] ~= nil, label .. " unknown move " .. tostring(f.move)) end
		-- Nobody stays in the same non-neutral state forever.
		local l = last[i]
		-- Chained attacks are fine: "stuck" is the same state with the same move.
		local key = f.state .. ":" .. tostring(f.move)
		if l.state == key then l.ticks += 1 else l.state, l.ticks = key, 0 end
		local limit = STUCK_LIMIT[f.state]
		if limit and world.phase == "Fight" then
			expect(l.ticks < limit, string.format("%s t%d P%d stuck in %s for %d ticks (move %s)", label, tick, i, f.state,
				l.ticks, tostring(f.move)))
		end
	end
	expect(#world.projectiles <= 6, label .. " too many projectiles: " .. #world.projectiles)
	if world.cinematic then
		expect(world.cinematic.tick <= world.cinematic.length + 1, label .. " cinematic overran")
	end
end

local failures = 0
test("random players: invariants hold for every kit pairing (versus and training)", function()
	for i, k1 in MoveData.KitOrder do
		for j, k2 in MoveData.KitOrder do
			for _, training in { false, true } do
				local world = Sim.newWorld(Config, MoveData, training)
				Sim.setKits(world, k1, k2)
				local p1 = randomPlayer(i * 977 + j * 31 + (if training then 7 else 0))
				local p2 = randomPlayer(j * 613 + i * 17 + 3)
				local last = { { ticks = 0 }, { ticks = 0 } }
				local label = string.format("%s vs %s%s", k1, k2, if training then " (training)" else "")
				local before = failures
				for tick = 1, 60 * 90 do
					local ok, err = pcall(Sim.step, world, { p1(), p2() })
					expect(ok, label .. " step error at tick " .. tick .. ": " .. tostring(err))
					if not ok then break end
					-- Lots of meter now and then, so ultimates get played.
					if tick % 900 == 0 then for _, f in world.fighters do f.meter = Config.MaxMeter end end
					check(world, label, tick, last)
				end
			end
		end
	end
end)

test("CPU against random player: invariants hold, ultimates and cinematics end", function()
	for i, kit in MoveData.KitOrder do
		local world = Sim.newWorld(Config, MoveData, false)
		Sim.setKits(world, kit, MoveData.KitOrder[(i % 4) + 1])
		local brain = FighterAI.new(4, i * 5)
		local p2 = randomPlayer(i * 123)
		local last = { { ticks = 0 }, { ticks = 0 } }
		local cinematics, ended = 0, 0
		for tick = 1, 60 * 120 do
			if tick % 600 == 0 then world.fighters[1].meter = Config.MaxMeter end
			for _, e in Sim.step(world, { brain:think(world, 1), p2() }) do
				if e.kind == "CinematicStart" then cinematics += 1 elseif e.kind == "CinematicEnd" then ended += 1 end
			end
			check(world, kit .. " CPU", tick, last)
		end
		expect(ended >= cinematics - 1, string.format("%s: %d cinematics started, %d ended", kit, cinematics, ended))
	end
end)

T.finish()
