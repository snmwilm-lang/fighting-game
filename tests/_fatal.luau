local Config = require("../src/shared/CombatConfig")
local MoveData = require("../src/shared/MoveData")
local Sim = require("../src/shared/CombatSimulation")
for _, kit in MoveData.KitOrder do
	local w = Sim.newWorld(Config, MoveData, false); Sim.setKits(w, kit, "KAI"); w.phase = "Fight"
	Sim.debugCinematic(w, 1, "Fatal", nil, nil)
	local n, ko = 0, false
	while w.cinematic and n < 2000 do n += 1; for _, e in Sim.step(w, { Sim.neutralInput(), Sim.neutralInput() }) do if e.ko then ko = true end end end
	print(kit, MoveData.Kits[kit].Ultimates.Fatal, "hp left", w.fighters[2].hp, "/", w.fighters[2].maxHp, ko)
end
