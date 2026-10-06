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

test("LÉGENDE earns ÉVEIL ÉCARLATE and nails its rhythm prompts (when the prompts are on)", function()
	-- (the prompts are off in the game since 0.25.0: Config.CinematicPrompts)
	local PromptConfig = table.clone(Config)
	PromptConfig.CinematicPrompts = true
	local found, grade = false, nil
	for seed = 1, 12 do
		local world = Sim.newWorld(PromptConfig, MoveData, false)
		world.phase = "Fight"
		world.fighters[1].x, world.fighters[2].x = -2, 2
		local brain = FighterAI.new(4, seed * 5)
		for _ = 1, 60 * 60 do
			world.fighters[2].meter = PromptConfig.MaxMeter
			world.fighters[1].hp = math.max(world.fighters[1].hp, 900)
			for _, e in Sim.step(world, { Sim.neutralInput(), brain:think(world, 2) }) do
				if e.kind == "CinematicStart" and (e.move == "Awakening" or e.move == "Kaiten") then found = true end
				if e.kind == "PromptGrade" then grade = e.grade end
			end
			if grade then break end
		end
		if grade then break end
	end
	expect(found, "LÉGENDE never earned the awakening")
	expect(grade == "PERFECT" or grade == "GREAT", "LÉGENDE prompts graded " .. tostring(grade))
end)

-- One CPU (slot 1, kit `kit`) against a scripted opponent (slot 2, KAI); returns the events.
local function scripted(kit, level, seed, ticks, foeInput)
	local world = Sim.newWorld(Config, MoveData, true)
	Sim.setKits(world, kit, "KAI")
	world.phase = "Fight"
	local brain = FighterAI.new(level, seed)
	local events, walls = {}, 0
	for t = 1, ticks do
		local mine = brain:think(world, 1)
		if mine.crouch and mine.special then walls += 1 end
		for _, e in Sim.step(world, { mine, foeInput(t) }) do table.insert(events, e) end
	end
	return events, walls
end

test("DAICHA's CPU blinks through the opponent (OMBRE INVERSÉE); HIBECARES's CPU walls a crouching opponent", function()
	local blinks = 0 -- over a few seeds: whether one fight shows a blink is luck
	for seed = 1, 6 do
		for _, e in scripted("DAICHA", 4, seed, 60 * 20, function() return Sim.neutralInput() end) do
			if e.kind == "Blink" and not e.move then blinks += 1 end
		end
	end
	expect(blinks >= 2, "DAICHA's CPU (almost) never blinked through")
	-- A crouching opponent close by: a low is coming (too fast to see), the wall goes up.
	local _, walls = scripted("HIBECARES", 4, 5, 60 * 20, function() return input({ crouch = true }) end)
	expect(walls >= 1, "HIBECARES's CPU never put up the stone wall against a crouching opponent")
end)

-- Scripted "player habits" a human finds quickly; LÉGENDE must read and beat every one.
local function toward(me, foe) return if foe.x > me.x then 1 else -1 end
local EXPLOITS = {
	mash = function(w, s, t) -- walk in and mash jab / heavy
		local me, foe = w.fighters[s], w.fighters[3 - s]
		local i = Sim.neutralInput()
		if math.abs(foe.x - me.x) > 3 then i.axis = toward(me, foe) else i.light = t % 6 == 0; i.heavy = t % 6 == 3 end
		return i
	end,
	jump = function(w, s, t) -- jump-in heavies all day
		local me, foe = w.fighters[s], w.fighters[3 - s]
		local i = Sim.neutralInput()
		i.axis = toward(me, foe)
		if me.y <= 0 then i.jump = t % 4 == 0 else i.heavy = me.vy < 0 and math.abs(foe.x - me.x) < 4 end
		return i
	end,
	zoner = function(w, s, t) -- run away and throw projectiles
		local me, foe = w.fighters[s], w.fighters[3 - s]
		local i = Sim.neutralInput()
		if math.abs(foe.x - me.x) < 5 then i.axis = -toward(me, foe); i.jump = t % 40 == 0 else i.crouch = true; i.special = t % 10 == 0 end
		return i
	end,
	rush = function(w, s, t) -- dash in, L L R, then the invincible reversal
		local me, foe = w.fighters[s], w.fighters[3 - s]
		local i = Sim.neutralInput()
		local p = t % 30
		if math.abs(foe.x - me.x) > 3 then i.axis = toward(me, foe); i.dash = p == 0 else
			i.light = p == 0 or p == 8; i.heavy = p == 16; i.special = p == 26
		end
		return i
	end,
}

local function exploitWins(level, habit, matches)
	local order, wins = MoveData.KitOrder, 0
	for m = 1, matches do
		local world = Sim.newWorld(Config, MoveData, false)
		Sim.setKits(world, order[(m - 1) % 8 + 1], order[(m * 3 + 1) % 8 + 1])
		local brain, winner, t = FighterAI.new(level, m * 17 + 5), nil, 0
		while not winner and t < 60 * 60 * 6 do
			t += 1
			for _, e in Sim.step(world, { brain:think(world, 1), EXPLOITS[habit](world, 2, t) }) do
				if e.kind == "MatchEnd" then winner = e.winner end
			end
		end
		if winner == 1 then wins += 1 end
	end
	return wins / matches
end

test("LÉGENDE reads and beats the habits players abuse (mash, jump-ins, zoning, reversal rush)", function()
	for habit in EXPLOITS do
		local rate = exploitWins(4, habit, 8)
		expect(rate >= 0.85, string.format("LÉGENDE only wins %d %% against %s", rate * 100, habit))
	end
	-- And the levels are real steps: LÉGENDE does clearly better than FACILE against a masher.
	expect(exploitWins(1, "mash", 8) <= 0.25, "FACILE should lose to a masher (a beginner's level)")
end)

test("ASURA (CHALLENGE boss): far more health than any kit, and its AI beats LÉGENDE", function()
	local boss = MoveData.Kits.ASURA
	expect(boss and boss.Boss and not table.find(MoveData.KitOrder, "ASURA"), "ASURA must exist and stay out of the roster")
	for _, name in MoveData.KitOrder do
		expect(boss.Stats.MaxHealth > MoveData.Kits[name].Stats.MaxHealth * 1.5, "ASURA is not much tougher than " .. name)
	end
	-- Same kit (KAI) on both sides: only the brains differ (12 seeds: on 6 it was a coin toss).
	local wins = 0
	for seed = 1, 12 do
		local world = Sim.newWorld(Config, MoveData, false)
		Sim.setKits(world, "KAI", "KAI")
		local brains = { FighterAI.new("KUROEN SHIN", seed), FighterAI.new(4, seed * 7 + 3) }
		for _ = 1, 60 * 60 * 5 do
			local over = false
			for _, e in Sim.step(world, { brains[1]:think(world, 1), brains[2]:think(world, 2) }) do
				if e.kind == "MatchEnd" then
					if e.winner == 1 then wins += 1 end
					over = true
				end
			end
			if over then break end
		end
	end
	-- (his guard lets a share of blows through: on the same kit his brain at least matches LÉGENDE)
	expect(wins >= 6, "the last boss's AI (KUROEN SHIN) won only " .. wins .. " of 12 against LÉGENDE")
	-- ASURA himself (second life, armored charge) against long reach played by LÉGENDE: a boss
	local spear = 0
	for seed = 1, 6 do
		local world = Sim.newWorld(Config, MoveData, false)
		Sim.setKits(world, "ASURA", "RAIJIN")
		local brains = { FighterAI.new("ASURA", seed), FighterAI.new(4, seed * 7 + 3) }
		for _ = 1, 60 * 60 * 6 do
			local over = false
			for _, e in Sim.step(world, { brains[1]:think(world, 1), brains[2]:think(world, 2) }) do
				if e.kind == "MatchEnd" then
					if e.winner == 1 then spear += 1 end
					over = true
				end
			end
			if over then break end
		end
	end
	expect(spear >= 5, "ASURA won only " .. spear .. " of 6 against RAIJIN's spear")
	-- KUROEN SHIN, the second boss: broken (Wilhem: like Gogeta)
	local shin = 0
	for seed = 1, 6 do
		local world = Sim.newWorld(Config, MoveData, false)
		Sim.setKits(world, "KUROEN SHIN", MoveData.KitOrder[seed * 3 % #MoveData.KitOrder + 1])
		local brains = { FighterAI.new("ASURA", seed), FighterAI.new(4, seed * 7 + 3) }
		for _ = 1, 60 * 60 * 6 do
			local over = false
			for _, e in Sim.step(world, { brains[1]:think(world, 1), brains[2]:think(world, 2) }) do
				if e.kind == "MatchEnd" then
					if e.winner == 1 then shin += 1 end
					over = true
				end
			end
			if over then break end
		end
	end
	expect(shin >= 5, "KUROEN SHIN won only " .. shin .. " of 6 against LÉGENDE")
end)

-- Wilhem: « ils doivent pas être impossibles, juste très compliqués », KUROEN SHIN the stronger.
test("the bosses' brains: KUROEN SHIN sharper than ASURA, and harder on a LÉGENDE team", function()
	local asura, shin = FighterAI.Bosses.ASURA, FighterAI.Bosses["KUROEN SHIN"]
	expect(FighterAI.new("KUROEN SHIN", 1).level == shin and FighterAI.new("ASURA", 1).level == asura, "each boss has its own brain")
	expect(shin.reaction < asura.reaction, "KUROEN SHIN's eye must be sharper than ASURA's")
	-- (Wilhem: « même les coups aériens il bloque »): a jump-in is not read every time
	expect(shin.read < 1 and shin.antiAir < 1, "KUROEN SHIN reads every jump")
	-- (Wilhem: « comment SHIN bloque tout, tout le temps ? »): rolled once per blow, a share of
	-- them gets through his guard, more of the lows
	expect(shin.guardOnce and shin.block <= 0.85 and shin.lowBlock < shin.block, "KUROEN SHIN must not guard every blow")
	expect(asura.reaction <= FighterAI.Levels[4].reaction and asura.block >= FighterAI.Levels[4].block,
		"ASURA's brain must stay at least LÉGENDE's")
	-- the boss's health left against LÉGENDE teams of 3 (the same teams, the same seeds)
	-- (0.25.0: 8 matches per team instead of 3: on 3 the order was a draw of the seeds; measured
	-- on 20 per team, even 0.24.5 had them level, 1.67 against 1.65)
	local PER_TEAM = 8
	local function left(boss)
		local sum = 0
		local teams = { { "TARO", "VENOM", "HIBIKI" }, { "KAI", "RYUKEN", "HIBECARES" }, { "KUROEN", "GORAN", "YUKINA" } }
		for t, team in teams do
			for i = 1, PER_TEAM do
				local world = Sim.newWorld(Config, MoveData, false)
				Sim.setKits(world, boss, team[1])
				Sim.setLineup(world, { boss }, team)
				local brains = { FighterAI.new(boss, i * 31 + t), FighterAI.new(4, i * 7 + 3 + t) }
				for _ = 1, 60 * 60 * 10 do
					local over = false
					for _, e in Sim.step(world, { brains[1]:think(world, 1), brains[2]:think(world, 2) }) do
						if e.kind == "MatchEnd" then over = true end
					end
					if over then break end
				end
				local f = world.fighters[1]
				sum += math.max(0, f.hp) / f.maxHp + (if f.revived then 0 else 1) -- (a second life still to come counts)
			end
		end
		return sum / (3 * PER_TEAM)
	end
	local a, k = left("ASURA"), left("KUROEN SHIN")
	-- (at least as hard as ASURA, within the noise of 24 matches)
	expect(k >= a - 0.05, string.format("KUROEN SHIN (%.2f) must end with as much left as ASURA (%.2f) against the same teams", k, a))
end)

test("KUROEN SHIN's guard: rolled once per blow, so some blows land (high and low)", function()
	local world = Sim.newWorld(Config, MoveData, true)
	Sim.setKits(world, "KUROEN SHIN", "KAI")
	world.phase = "Fight"
	local guarded, total = { High = 0, Low = 0 }, { High = 0, Low = 0 }
	local brain = FighterAI.new("KUROEN SHIN", 7)
	for seed = 1, 200 do
		for _, guard in { "High", "Low" } do
			-- the same blow seen on 6 ticks in a row: one roll for all of them
			local first
			for tick = 1, 6 do
				local yes, low = brain:guardRoll({ move = "Jab", serial = seed * 2 + (if guard == "Low" then 1 else 0), guard = guard })
				local up = yes and (guard ~= "Low" or low)
				if first == nil then first = up end
				expect(up == first, "the guard was rolled again on the same blow")
			end
			total[guard] += 1
			if first then guarded[guard] += 1 end
		end
	end
	local high, low = guarded.High / total.High, guarded.Low / total.Low
	expect(high > 0.6 and high < 0.88, string.format("KUROEN SHIN guards %.0f %% of the high blows", high * 100))
	expect(low < high, string.format("KUROEN SHIN guards the lows (%.0f %%) as well as the highs", low * 100))
end)

test("the same seed replays the same fight", function()
	local a = versus(3, 2, 42, 60 * 30)
	local b = versus(3, 2, 42, 60 * 30)
	expect(a.damage[1] == b.damage[1] and a.damage[2] == b.damage[2], "non-deterministic CPU")
end)

test("ASURA against the wall: varied openers, never the same slow blow again and again (no cheese)", function()
	for _, guard in { "stand", "crouch" } do
		local world = Sim.newWorld(Config, MoveData, true)
		Sim.setKits(world, "ASURA", "RAIJIN")
		world.phase = "Fight"
		local a, b = world.fighters[1], world.fighters[2]
		local brain = FighterAI.new("ASURA", 11)
		local openers, total, wasFree = {}, 0, true
		for t = 1, 60 * 40 do
			if t % 90 == 1 then b.x, a.x, a.facing, b.facing = Config.ArenaMinX + 0.5, Config.ArenaMinX + 3.5, -1, 1 end
			local neutral = Sim.neutralInput()
			neutral.block, neutral.crouch = true, guard == "crouch"
			local before = a.moveSerial
			Sim.step(world, { brain:think(world, 1), neutral })
			if a.moveSerial ~= before and a.move and wasFree then
				openers[a.move] = (openers[a.move] or 0) + 1
				total += 1
			end
			wasFree = a.move == nil and a.stun == 0
		end
		local kinds, top, slow = 0, 0, 0
		for id, n in openers do
			kinds += 1
			top = math.max(top, n)
			if MoveData.Moves[id].startup >= 13 then slow += n end
		end
		expect(total >= 8, guard .. ": ASURA hardly attacks a cornered opponent (" .. total .. ")")
		expect(kinds >= 3, guard .. ": only " .. kinds .. " different openers")
		expect(top <= total * 0.6, guard .. ": one opener is " .. top .. " of " .. total)
		expect(slow <= total * 0.15, guard .. ": slow openers (free counter hits) " .. slow .. " of " .. total)
	end
end)

-- ===================================================================== KUROEN SHIN's mistakes (0.25.0)
-- Wilhem: « nerfer sa perfection, pas ses stats »: contextual mistakes, not a flat chance.
local function shinWorld()
	local world = Sim.newWorld(Config, MoveData, false)
	Sim.setKits(world, "KUROEN SHIN", "KAI")
	world.phase = "Fight"
	world.fighters[1].x, world.fighters[2].x = -1.8, 1.8
	return world
end

test("KUROEN SHIN's strain: a calm masher barely works him, a player who changes rhythm, dashes, jumps and crouches does", function()
	local function strainAgainst(script)
		local world = shinWorld()
		local brain = FighterAI.new("KUROEN SHIN", 5)
		local sum, n = 0, 0
		for t = 1, 60 * 20 do
			local foe = world.fighters[2]
			-- (the opponent is kept alive and close: only the boss's reading is measured)
			foe.hp = foe.maxHp
			world.fighters[1].hp = world.fighters[1].maxHp
			-- (the boss only watches: his own inputs are not played, his reading is measured)
			brain:think(world, 1)
			Sim.step(world, { Sim.neutralInput(), script(t, world) })
			if t > 120 then sum += brain.strain or 0; n += 1 end
		end
		return sum / n
	end
	local calm = strainAgainst(function(t) return input({ light = t % 24 == 0 }) end)
	local worked = strainAgainst(function(t, world)
		local cycle = t % 150
		local foe, boss = world.fighters[2], world.fighters[1]
		local away = if foe.x > boss.x then 1 else -1
		if cycle == 10 then return input({ dash = true, axis = away }) end
		if cycle == 40 then return input({ dash = true, axis = -away }) end
		if cycle >= 60 and cycle < 75 then return input({ crouch = true }) end
		if cycle == 90 then return input({ jump = true }) end
		return input({ light = cycle == 30 or cycle == 37 or cycle == 120 })
	end)
	expect(calm < 0.12, string.format("a calm masher works him too much (%.2f)", calm))
	expect(worked > calm * 2.5 and worked > 0.12, string.format("working him does not show (%.2f vs %.2f calm)", worked, calm))
	-- the strain fades when he is left alone
	local brain = FighterAI.new("KUROEN SHIN", 5)
	brain.strain = 1
	local world = shinWorld()
	for _ = 1, 240 do Sim.step(world, { brain:think(world, 1), Sim.neutralInput() }) end
	expect(brain.strain < 0.1, "the strain never fades")
	-- the other brains have none
	expect(FighterAI.Bosses.ASURA.mistakes == nil and FighterAI.Levels[4].mistakes == nil, "a brain other than KUROEN SHIN's makes his mistakes")
end)

test("KUROEN SHIN worked: later, guards less and the wrong height, shorter or fumbled combos, missed confirms", function()
	local function sample(strain)
		local brain = FighterAI.new("KUROEN SHIN", 11)
		local guards, wrong, reaction, length, fumbles, slips = 0, 0, 0, 0, 0, 0
		local fullRoutes = MoveData.Kits["KUROEN SHIN"].FullRoutes
		for i = 1, 400 do
			brain.strain = strain
			local yes, _, w = brain:guardRoll({ move = "Jab", serial = i, guard = "High" })
			if yes then guards += 1 end
			if w then wrong += 1 end
			reaction += brain:reactionTicks()
			brain:pickPlan(300, 100, fullRoutes, false, false)
			length += brain.planLength
			if brain.fumbleAt then fumbles += 1 end
			if brain.confirmSlip then slips += 1 end
		end
		return { guards = guards / 400, wrong = wrong / 400, reaction = reaction / 400, length = length / 400,
			fumbles = fumbles / 400, slips = slips / 400 }
	end
	local calm, worked = sample(0), sample(1)
	expect(worked.reaction >= calm.reaction + 3, "worked, he still reacts as fast")
	expect(worked.guards < calm.guards - 0.15, string.format("worked, he guards as much (%.2f vs %.2f)", worked.guards, calm.guards))
	expect(calm.wrong == 0 and worked.wrong > 0.1, "worked, he never guards the wrong height")
	expect(worked.length < calm.length, string.format("worked, his combos are as long (%.1f vs %.1f)", worked.length, calm.length))
	expect(worked.fumbles > calm.fumbles and worked.slips > calm.slips + 0.2, "worked, he fumbles and misses confirms as rarely")
	-- calm, the optimal routes most of the time (still the boss)
	expect(calm.length >= 4.5, string.format("calm, his combos are short (%.1f)", calm.length))
end)

test("KUROEN SHIN: bites on a feint when worked, the GRAB answers his guard, a beginner still loses", function()
	local function bites(strain)
		local brain, count = FighterAI.new("KUROEN SHIN", 3), 0
		for i = 1, 400 do
			brain.strain = strain
			if brain:bitesFeint({ feint = true, serial = i }) then count += 1 end
			brain:bitesFeint({ feint = true, serial = i }) -- (the same feint twice: one roll)
		end
		return count / 400
	end
	local calm, worked = bites(0), bites(1)
	expect(worked > calm * 2 and worked > 0.3, string.format("he does not bite on feints when worked (%.2f vs %.2f calm)", worked, calm))
	expect(FighterAI.new(4, 1):bitesFeint({ feint = true, serial = 1 }) == false, "LÉGENDE bites on feints the boss's way")
	-- in a fight: a feint seen up close, worked, and he answers with a slow blow
	local world = shinWorld()
	local brain = FighterAI.new("KUROEN SHIN", 2)
	local bit = false
	for i = 1, 40 do
		brain.strain = 1
		world.fighters[2].state, world.fighters[2].moveSerial = "Feint", i
		brain.plan = nil
		local out = brain:think(world, 1)
		if out.heavy and brain.bitKey == i then bit = true break end
	end
	expect(bit, "worked, he never bit on a feint in a fight")
	-- a player who grabs him when he guards up close lands grabs; a beginner (NORMAL) still loses
	local grabs, beginnerWins = 0, 0
	for seed = 1, 3 do
		local world = Sim.newWorld(Config, MoveData, false)
		Sim.setKits(world, "KUROEN SHIN", MoveData.KitOrder[seed])
		local boss, player = FighterAI.new("KUROEN SHIN", seed), FighterAI.new(4, seed * 7 + 3)
		local beginnerWorld = Sim.newWorld(Config, MoveData, false)
		Sim.setKits(beginnerWorld, "KUROEN SHIN", MoveData.KitOrder[seed])
		local boss2, beginner = FighterAI.new("KUROEN SHIN", seed), FighterAI.new(2, seed * 5)
		for _ = 1, 60 * 60 * 3 do
			local i = player:think(world, 2)
			local b = world.fighters[1]
			if b.blocking and math.abs(b.x - world.fighters[2].x) < 3.6 then i.grab = true end
			for _, e in Sim.step(world, { boss:think(world, 1), i }) do
				if e.kind == "Hit" and e.attacker == 2 and e.move == "Grab" then grabs += 1 end
			end
			for _, e in Sim.step(beginnerWorld, { boss2:think(beginnerWorld, 1), beginner:think(beginnerWorld, 2) }) do
				if e.kind == "MatchEnd" and e.winner == 2 then beginnerWins += 1 end
			end
		end
	end
	expect(grabs > 0, "the grab never caught his guard")
	expect(beginnerWins == 0, "a beginner beat KUROEN SHIN")
end)

test("the CPU grabs an opponent who sits in its guard up close (NORMAL and up), never EASY", function()
	local function grabs(level)
		local world = Sim.newWorld(Config, MoveData, true)
		world.phase = "Fight"
		world.fighters[1].x, world.fighters[2].x = -1.5, 1.5
		local count = 0
		for seed = 1, 3 do
		local brain = FighterAI.new(level, seed)
		world.fighters[1].x, world.fighters[2].x = -1.5, 1.5
		for _ = 1, 60 * 10 do
			world.fighters[1].hp, world.fighters[2].hp = world.fighters[1].maxHp, world.fighters[2].maxHp
			for _, e in Sim.step(world, { brain:think(world, 1), input({ block = true }) }) do
				if e.kind == "Hit" and e.move == "Grab" then count += 1 end
			end
		end
		end
		return count
	end
	expect(grabs(4) > 0 and grabs(3) > 0, "LÉGENDE / HARD never grab a turtling opponent")
	expect(grabs(1) == 0, "EASY grabs")
end)

T.finish()
