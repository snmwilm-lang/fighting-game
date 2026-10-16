-- Balance report (not a pass/fail test): CPU against CPU for every pair of kits.
-- Run from the repository root:
--   luau tests/Balance.luau             (LÉGENDE, 120 matches per pairing)
--   luau tests/Balance.luau -a 3 200    (DIFFICILE, 200 matches per pairing)
local Balance = require("./BalanceKit")
local args = { ... }
Balance.report(tonumber(args[1]) or 4, tonumber(args[2]) or 120)
