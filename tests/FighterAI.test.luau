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

test("LÉGENDE earns ÉVEIL ÉCARLATE and nails its rhythm prompts", function()
	local found, grade = false, nil
	for seed = 1, 12 do
		local world = Sim.newWorld(Config, MoveData, false)
		world.phase = "Fight"
		world.fighters[1].x, world.fighters[2].x = -2, 2
		local brain = FighterAI.new(4, seed * 5)
		for _ = 1, 60 * 60 do
			world.fighters[2].meter = Config.MaxMeter
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
	-- Same kit (KAI) on both sides: only the brains differ.
	local wins = 0
	for seed = 1, 6 do
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
	expect(wins >= 3, "the last boss's AI (KUROEN SHIN) won only " .. wins .. " of 6 against LÉGENDE")
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
	expect(shin.reaction < asura.reaction and shin.read > asura.read, "KUROEN SHIN's eye and reads must be sharper than ASURA's")
	-- (Wilhem: « comment SHIN bloque tout, tout le temps ? »): rolled once per blow, a share of
	-- them gets through his guard, more of the lows
	expect(shin.guardOnce and shin.block <= 0.85 and shin.lowBlock < shin.block, "KUROEN SHIN must not guard every blow")
	expect(asura.reaction <= FighterAI.Levels[4].reaction and asura.block >= FighterAI.Levels[4].block,
		"ASURA's brain must stay at least LÉGENDE's")
	-- the boss's health left against LÉGENDE teams of 3 (the same teams, the same seeds)
	local function left(boss)
		local sum = 0
		local teams = { { "TARO", "VENOM", "HIBIKI" }, { "KAI", "RYUKEN", "HIBECARES" }, { "KUROEN", "GORAN", "YUKINA" } }
		for t, team in teams do
			for i = 1, 3 do
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
		return sum / 9
	end
	local a, k = left("ASURA"), left("KUROEN SHIN")
	expect(k > a, string.format("KUROEN SHIN (%.2f) must end with more left than ASURA (%.2f) against the same teams", k, a))
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
	expect(high > 0.65 and high < 0.92, string.format("KUROEN SHIN guards %.0f %% of the high blows", high * 100))
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

T.finish()
