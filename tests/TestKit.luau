-- Minimal test helpers shared by the offline test files.
local Sim = require("../src/shared/CombatSimulation")

local TestKit = { passed = 0, failed = 0 }

function TestKit.test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		TestKit.passed += 1
		print("  ok   " .. name)
	else
		TestKit.failed += 1
		print("  FAIL " .. name .. "\n       " .. tostring(err))
	end
end

function TestKit.expect(cond, message)
	if not cond then error(message, 2) end
end

function TestKit.input(fields)
	local i = Sim.neutralInput()
	for k, v in fields or {} do i[k] = v end
	return i
end

function TestKit.finish()
	print(string.format("%d passed, %d failed", TestKit.passed, TestKit.failed))
	if TestKit.failed > 0 then error("tests failed") end
end

return TestKit
