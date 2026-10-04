-- Boss against LEGEND teams of 3 (not a test): luau tests/BossTeamReport.luau -a [BOSS] [matches per team].
-- The AI is not a human: even the older ASURA that testers beat in ~15 tries read 0 here.
local Config = require("../src/shared/CombatConfig")
local MoveData = require("../src/shared/MoveData")
local Sim = require("../src/shared/CombatSimulation")
local FighterAI = require("../src/shared/FighterAI")
local args = { ... }
local BOSS, matches = args[1] or "ASURA", tonumber(args[2]) or 12
local teams = { { "TARO", "VENOM", "HIBIKI" }, { "KAI", "RYUKEN", "HIBECARES" }, { "KUROEN", "GORAN", "YUKINA" } }
local playerWins, n = 0, 0
for t, team in teams do
	for i = 1, matches do
		local world = Sim.newWorld(Config, MoveData, false)
		Sim.setKits(world, BOSS, team[1])
		Sim.setLineup(world, { BOSS }, team)
		local brains = { FighterAI.new("ASURA", i * 31 + t), FighterAI.new(4, i * 7 + 3 + t) }
		for _ = 1, 60 * 60 * 10 do
			local done = false
			for _, e in Sim.step(world, { brains[1]:think(world, 1), brains[2]:think(world, 2) }) do
				if e.kind == "MatchEnd" then
					if e.winner == 2 then playerWins += 1 end
					done = true
				end
			end
			if done then break end
		end
		n += 1
	end
end
print(string.format("%s: a LEGEND team of 3 wins %d / %d", BOSS, playerWins, n))
