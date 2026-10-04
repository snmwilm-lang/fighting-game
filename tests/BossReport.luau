-- Boss report (not a test): ASURA with the boss AI against every kit played by LÉGENDE.
--   luau tests/BossReport.luau -a [matches] [BOSS]   (ASURA or "KUROEN SHIN")
local Config = require("../src/shared/CombatConfig")
local MoveData = require("../src/shared/MoveData")
local Sim = require("../src/shared/CombatSimulation")
local FighterAI = require("../src/shared/FighterAI")
local args = { ... }
local matches = tonumber(args[1]) or 10
local BOSS = args[2] or "ASURA"
local total = 0
for _, kit in MoveData.KitOrder do
	local wins = 0
	for n = 1, matches do
		local world = Sim.newWorld(Config, MoveData, false)
		Sim.setKits(world, BOSS, kit)
		local brains = { FighterAI.new("ASURA", n * 31), FighterAI.new(4, n * 7 + 3) }
		for _ = 1, 60 * 60 * 6 do
			local done = false
			for _, e in Sim.step(world, { brains[1]:think(world, 1), brains[2]:think(world, 2) }) do
				if e.kind == "MatchEnd" then
					if e.winner == 1 then wins += 1 elseif e.winner == 0 then wins += 0.5 end
					done = true
				end
			end
			if done then break end
		end
	end
	total += wins
	print(string.format("%s vs %-10s %3d%%", BOSS, kit, math.floor(wins / matches * 100 + 0.5)))
end
print(string.format("%s overall %d%%", BOSS, math.floor(total / (matches * #MoveData.KitOrder) * 100 + 0.5)))
