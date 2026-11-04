-- Boss duel check (not a test): full CPU-against-CPU matches between two kits (bosses
-- included), both sides in turn. Reports wins, timeouts, errors, NaN positions, a fighter
-- stuck in one state, and the bosses' own events (BURST, DIVINE INSTINCT, SECOND LIFE).
--   luau tests/BossDuel.luau -a "KUROEN SHIN" ASURA [matches] [level|BOSS]  (BOSS: each boss its own brain, as in CHALLENGE)
local Config = require("../src/shared/CombatConfig")
local MoveData = require("../src/shared/MoveData")
local Sim = require("../src/shared/CombatSimulation")
local FighterAI = require("../src/shared/FighterAI")

local args = { ... }
local A, B = args[1] or "KUROEN SHIN", args[2] or "ASURA"
local matches, level = tonumber(args[3]) or 20, tonumber(args[4]) or (if args[4] == "BOSS" then "BOSS" else 4)
local wins, draws, errors, nans, stuck, seconds = { [A] = 0, [B] = 0 }, 0, 0, 0, 0, 0
local left = { [A] = 0, [B] = 0 } -- (the winner's health left, summed)
local counts = {}
for i = 1, matches do
	local swap = i % 2 == 0
	local kit1, kit2 = if swap then B else A, if swap then A else B
	local ok, result = pcall(function()
		local world = Sim.newWorld(Config, MoveData, false)
		Sim.setKits(world, kit1, kit2)
		local function brain(kit, seed)
			return FighterAI.new(if level == "BOSS" then (if FighterAI.Bosses[kit] then kit else 4) else level, seed)
		end
		local brains = { brain(kit1, i), brain(kit2, i * 7 + 3) }
		local same, lastState = { 0, 0 }, { "", "" }
		for t = 1, 60 * 60 * 6 do
			for _, e in Sim.step(world, { brains[1]:think(world, 1), brains[2]:think(world, 2) }) do
				counts[e.kind] = (counts[e.kind] or 0) + 1
				if e.kind == "MatchEnd" then
					local w = world.fighters[e.winner]
					return { winner = e.winner, ticks = t, left = if w then math.max(0, w.hp) / w.maxHp else 0 }
				end
			end
			for s, f in world.fighters do
				if f.x ~= f.x or f.y ~= f.y then nans += 1 end
				-- (a fighter frozen in one non-neutral state for 15 s is stuck: the longest cinematic is ~12 s)
				if f.state == lastState[s] and f.state ~= "Idle" and f.state ~= "Walking" and f.state ~= "Crouching"
					and f.state ~= "Blocking" and f.state ~= "KO" and world.phase == "Fight" then
					same[s] += 1
					if same[s] == 900 then stuck += 1; print(string.format("  match %d: %s stuck in %s", i, f.kit, f.state)) end
				else
					same[s] = 0
				end
				lastState[s] = f.state
			end
		end
		return { winner = 0, ticks = 60 * 60 * 6 }
	end)
	if not ok then
		errors += 1
		print("  match " .. i .. " error: " .. tostring(result))
	elseif result.winner == 0 then
		draws += 1
	else
		local winner = if result.winner == 1 then kit1 else kit2
		wins[winner] += 1
		left[winner] += result.left or 0
		seconds += result.ticks / 60
	end
end
print(string.format("%s vs %s, %d matches (level %s): %s %d · %s %d · draws/timeouts %d · errors %d · NaN %d · stuck %d · %.0f s a match",
	A, B, matches, tostring(level), A, wins[A], B, wins[B], draws, errors, nans, stuck, seconds / math.max(1, wins[A] + wins[B])))
print(string.format("  winner's health left: %s %.0f %% · %s %.0f %%", A, 100 * left[A] / math.max(1, wins[A]), B,
	100 * left[B] / math.max(1, wins[B])))
local list = {}
for kind, n in counts do
	if kind == "Burst" or kind == "Evade" or kind == "AutoEvade" or kind == "Revive" or kind == "Domination" or kind == "GuardBreak"
		or kind == "Cinematic" then table.insert(list, kind .. " " .. n) end
end
table.sort(list)
print("  events: " .. table.concat(list, ", "))
