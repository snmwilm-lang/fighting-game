-- Balance harness: CPU against CPU for every pair of kits, same level, both sides, several
-- seeds. Used by tests/Balance.luau (report) and tests/Kits.test.luau (regression limits).
local Config = require("../src/shared/CombatConfig")
local MoveData = require("../src/shared/MoveData")
local Sim = require("../src/shared/CombatSimulation")
local FighterAI = require("../src/shared/FighterAI")

local Balance = {}

-- One full match (rounds, timer). Returns the winning slot (0 = draw) and stats.
function Balance.match(kit1, kit2, level, seed)
	local world = Sim.newWorld(Config, MoveData, false)
	Sim.setKits(world, kit1, kit2)
	local brains = { FighterAI.new(level, seed), FighterAI.new(level, seed * 7 + 3) }
	local damage = { 0, 0 }
	for _ = 1, 60 * 60 * 6 do
		for _, e in Sim.step(world, { brains[1]:think(world, 1), brains[2]:think(world, 2) }) do
			if (e.kind == "Hit" or e.kind == "Block") and e.damage then
				damage[e.attacker] += e.damage
			end
			if e.kind == "MatchEnd" then return e.winner, damage end
		end
	end
	return 0, damage
end

-- Win rate of each kit against each other kit. Every pairing is played once (sides
-- alternate, seeds vary) and its reverse is the complement; mirrors are 50 % by definition.
function Balance.matrix(level, matches, kits)
	kits = kits or MoveData.KitOrder
	local result = {}
	for _, a in kits do result[a] = { [a] = 0.5 } end
	for i, a in kits do
		for j = i + 1, #kits do
			local b = kits[j]
			local wins = 0
			for n = 1, matches do
				local swap = n % 2 == 0
				local winner = Balance.match(if swap then b else a, if swap then a else b, level, n * 101 + i * 13 + j * 7)
				local aSlot = if swap then 2 else 1
				if winner == aSlot then wins += 1 elseif winner == 0 then wins += 0.5 end
			end
			result[a][b] = wins / matches
			result[b][a] = 1 - wins / matches
		end
	end
	return result
end

function Balance.report(level, matches)
	local kits = MoveData.KitOrder
	local m = Balance.matrix(level, matches)
	print(string.format("Niveau %s, %d matchs par duel (taux de victoire de la ligne contre la colonne)",
		FighterAI.Levels[level].name, matches))
	local header = string.format("%-8s", "")
	for _, b in kits do header ..= string.format("%8s", b) end
	print(header .. "   moyenne")
	for _, a in kits do
		local line, total, n = string.format("%-8s", a), 0, 0
		for _, b in kits do
			line ..= string.format("%7d%%", math.floor(m[a][b] * 100 + 0.5))
			if a ~= b then total += m[a][b]; n += 1 end
		end
		print(line .. string.format("   %3d%%", math.floor(total / n * 100 + 0.5)))
	end
	return m
end

return Balance
