-- Boss report (not a test): KUROEN SHIN (or ASURA) against a player who works him (Wilhem,
-- 0.25.0: « un excellent joueur doit pouvoir le provoquer, créer une erreur et la punir »).
-- The opponent is the LÉGENDE CPU plus what a good player does: changes of rhythm, dashes in
-- and out, jumps and crouches, whiffs just short of him, KAI's feint, the GRAB when he guards.
--   luau tests/BossProvoke.luau -a [matches] [BOSS] [style]   style: provoke (default) | plain | beginner
local Config = require("../src/shared/CombatConfig")
local MoveData = require("../src/shared/MoveData")
local Sim = require("../src/shared/CombatSimulation")
local FighterAI = require("../src/shared/FighterAI")
local args = { ... }
local matches = tonumber(args[1]) or 4
local BOSS = args[2] or "KUROEN SHIN"
local STYLE = args[3] or "provoke"

local function provoker(seed)
	local brain = FighterAI.new(if STYLE == "beginner" then 2 else 4, seed)
	local state = seed
	local function rand()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
	local hold, holdTicks = nil, 0
	return function(world, slot)
		local input = brain:think(world, slot)
		if STYLE ~= "provoke" then return input end
		local me, boss = world.fighters[slot], world.fighters[3 - slot]
		local dist = math.abs(boss.x - me.x)
		local toward = if boss.x >= me.x then 1 else -1
		local free = not me.move and me.stun == 0 and not me.launched and me.knockdown == 0 and me.getUp == 0
		if holdTicks > 0 then
			holdTicks -= 1
			if free then
				for k, v in hold do input[k] = v end
			end
			return input
		end
		if not free or world.cinematic then return input end
		local r = rand()
		-- the boss guarding up close: the GRAB
		if boss.blocking and dist < 3.6 and r < 0.25 then
			input.grab, input.light, input.heavy = true, false, false
			return input
		end
		-- neutral: work him (a few times a second)
		if dist > 3 and dist < 9 and r < 0.035 then
			local pick = rand()
			if pick < 0.3 then
				hold, holdTicks = { axis = -toward, dash = true }, 2 -- dash out
			elseif pick < 0.55 then
				hold, holdTicks = { axis = toward, dash = true }, 2 -- dash in
			elseif pick < 0.7 then
				hold, holdTicks = { crouch = true }, 10 + math.floor(rand() * 14) -- height
			elseif pick < 0.85 and dist > 4.6 and dist < 6 then
				hold, holdTicks = { heavy = true }, 1 -- a whiff just short of him (bait)
			else
				hold, holdTicks = { axis = -toward }, 6 + math.floor(rand() * 12) -- walk out (distance)
			end
			for k, v in hold do input[k] = v end
			return input
		end
		-- a change of rhythm: a pause before pressing on
		if (input.light or input.heavy) and r < 0.1 and dist > 2.5 then
			input.light, input.heavy = false, false
			hold, holdTicks = { block = true }, 4 + math.floor(rand() * 10)
		end
		return input
	end
end

local total, blocks, guarded = 0, 0, 0
local stats = { grabs = 0, hits = 0, bossHits = 0, rounds = 0, playerRounds = 0, bossLeft = 0 }
for i, kit in MoveData.KitOrder do
	local wins = 0
	for n = 1, matches do
		local world = Sim.newWorld(Config, MoveData, false)
		Sim.setKits(world, BOSS, kit)
		local boss = FighterAI.new(BOSS, n * 31 + i)
		local player = provoker(n * 7 + 3 + i * 13)
		for _ = 1, 60 * 60 * 6 do
			local done = false
			for _, e in Sim.step(world, { boss:think(world, 1), player(world, 2) }) do
				if e.kind == "MatchEnd" then
					if e.winner == 1 then wins += 1 elseif e.winner == 0 then wins += 0.5 end
					done = true
				elseif e.kind == "Hit" and e.attacker == 2 then
					stats.hits += 1
					if e.move == "Grab" then stats.grabs += 1 end
				elseif e.kind == "Block" and e.defender == 1 then
					blocks += 1
				elseif e.kind == "Hit" and e.attacker == 1 then
					stats.bossHits += 1
				elseif e.kind == "RoundEnd" then
					stats.rounds += 1
					if e.winner == 2 then stats.playerRounds += 1 end
					local b = world.fighters[1]
					stats.bossLeft += math.max(0, b.hp) / b.maxHp
				end
				if (e.kind == "Hit" or e.kind == "Block") and e.defender == 1 then guarded += 1 end
			end
			if done then break end
		end
	end
	total += wins
	print(string.format("%s vs %-10s %3d%%", BOSS, kit, math.floor(wins / matches * 100 + 0.5)))
end
print(string.format("%s overall %d%% (%s) · rounds taken by the player %d%% · boss health left %d%% · boss guarded %d%% · player hits %d (grabs %d)",
	BOSS, math.floor(total / (matches * #MoveData.KitOrder) * 100 + 0.5), STYLE,
	math.floor(stats.playerRounds / math.max(1, stats.rounds) * 100 + 0.5), math.floor(stats.bossLeft / math.max(1, stats.rounds) * 100 + 0.5),
	math.floor(blocks / math.max(1, guarded) * 100 + 0.5), stats.hits, stats.grabs))
