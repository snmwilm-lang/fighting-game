-- Win rate of one kit against every other (CPU LEGEND vs CPU LEGEND, not a test):
--   luau tests/KitReport.luau -a KIT [matches]
local Balance = require("./BalanceKit")
local MoveData = require("../src/shared/MoveData")
local args = { ... }
local who, n = args[1], tonumber(args[2]) or 40
local total, count = 0, 0
for _, other in MoveData.KitOrder do
	if other ~= who then
		local wins = 0
		for i = 1, n do
			local swap = i % 2 == 0
			local w = Balance.match(if swap then other else who, if swap then who else other, 4, i * 101 + #other * 13)
			if w == (if swap then 2 else 1) then wins += 1 elseif w == 0 then wins += 0.5 end
		end
		total += wins / n; count += 1
		print(string.format("%s %d%%", other, math.floor(wins / n * 100 + 0.5)))
	end
end
print(string.format("\n%s average %d%%", who, math.floor(total / count * 100 + 0.5)))
