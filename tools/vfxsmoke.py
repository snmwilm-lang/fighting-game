#!/usr/bin/env python3
"""Smoke test of client/VfxPack.luau (the bridge to Wilhem's VFX pack) on a fake engine.

    python3 tools/vfxsmoke.py        (needs `luau` on the PATH)

The bridge's source is wrapped in a function whose engine names (game, script, require, os,
warn, Vector3, CFrame) are fakes, and the pack's three modules are fakes that log their
calls: it checks the gating (nothing before the IDs, everything after, one missing texture
keeps only its fighter on the game's effects), the tier mapping, the body effects (trails,
aura, passive), the shots and the fallback after an error. The pack's own effects are not
drawn here (no Roblox): judge them in Studio.
"""
import os
import subprocess
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
HEAD = r'''
local VfxConfig = require("../src/shared/VfxConfig")
local calls, warned = {}, {}
local function log(s) table.insert(calls, s) end
local function vec(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, {
	__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end }) end
local Vector3 = { new = vec }
local CFrame = { lookAt = function(a, b) return { at = a, to = b } end, new = function(...) return { ... } end }
local meshes = { children = {} }
function meshes:FindFirstChild(n) return self.children[n] end
local fake = {
	VFX_Common = { ArcCFrame = function() return {} end, Parry = function() log("Parry") end, Guard = function() log("Guard") end,
		Boom = function() error("boom") end, Blank = function(key) log("Blank " .. key) end },
	VFX_Chars = {
		Impact = function(name, level) log("Impact " .. name .. " " .. level) end,
		Trail = function(name) return { On = function() log("TrailOn " .. name) end, Off = function() log("TrailOff " .. name) end, Destroy = function() end } end,
		Dash = function(name) log("Dash " .. name) end, Swing = function(name) log("Swing " .. name) end,
	},
	VFX_Specials = {
		Auras = { KAI = true, RYUKEN = true, KUROEN_SHIN = true }, Passives = { KAI = true, RYUKEN = true }, Skills = { TARO = true },
		Aura = function(name) return { SetLevel = function(l) log("Aura " .. name .. " " .. l) end, Destroy = function() end } end,
		Passive = function(name) return { Set = function(v) log("Set " .. name .. " " .. tostring(v)) end,
			Trigger = function() log("Trigger " .. name) end, Destroy = function() end } end,
		Skill = function(name) log("Skill " .. name) return { Destroy = function() end } end,
	},
}
local folder = { WaitForChild = function(_, n) return n end }
local script = { Parent = { WaitForChild = function() return folder end } }
local shared = { VfxConfig = "VfxConfig", CombatConfig = "CombatConfig" }
local Enum = { AssetFetchStatus = { Success = "Success", Failure = "Failure", TimedOut = "TimedOut" } }
local task = { spawn = function(f) f() end }
local failIds, slowIds = {}, {}
local contentProvider = { PreloadAsync = function(_, list, done)
	for _, id in list do
		done(id, if failIds[id] then Enum.AssetFetchStatus.Failure
			elseif slowIds[id] then Enum.AssetFetchStatus.TimedOut else Enum.AssetFetchStatus.Success)
	end
end }
local game = { GetService = function(_, name)
	if name == "ContentProvider" then return contentProvider end
	return {
		WaitForChild = function() return shared end,
		FindFirstChild = function(_, n) return if n == "VFX_Meshes" then meshes else nil end } end }
local function fakeRequire(x)
	if x == "VfxConfig" then return VfxConfig end
	if x == "CombatConfig" then return { MaxMeter = 300 } end
	return assert(fake[x], tostring(x))
end
local clock = 0
local os = { clock = function() return clock end }
local function warn(m) table.insert(warned, m) end
local function load(require)
'''
TAIL = r'''
end
local VfxPack = load(fakeRequire)
local failed = 0
local function check(ok, what)
	print((if ok then "  ok   " else "  FAIL ") .. what)
	if not ok then failed += 1 end
end
local effects = { reduced = false, camera = { shake = function() end } }
local pack = VfxPack.new(effects)
local color = { ToHex = function() return "FF2A3D" end }
local rig = { model = { Parent = true }, trails = { RightHand = { Attachment0 = 1, Attachment1 = 2 } } }
local saved, savedMeshes = table.clone(VfxConfig.TEXTURES), table.clone(VfxConfig.MESHES)
for k in VfxConfig.TEXTURES do VfxConfig.TEXTURES[k] = 0 end
for k in VfxConfig.MESHES do VfxConfig.MESHES[k] = 0 end
-- nothing uploaded: nothing from the pack
check(not pack:ready("KAI") and not pack:hit("KAI", "light", vec(), 1, color, 4, {}), "no IDs: the game draws the hit")
check(not pack:common("Parry", {}, color), "no IDs: the game draws the parry")
check(pack:update(rig, { kit = "KAI", meter = 300 }, nil, 0, color) == false and pack.loaded == nil, "no IDs: nothing dressed, the pack never loaded")
check(not pack:trail(rig, "RightHand", true), "no IDs: the game's trail")
-- the textures uploaded, the meshes not yet
for k in VfxConfig.TEXTURES do VfxConfig.TEXTURES[k] = 1 end
check(not pack:ready("KAI"), "the check waits 2 s before looking again")
clock = 3
check(pack:ready("KAI") and pack.loaded, "the textures uploaded: KAI is ready and the pack loaded, without the meshes")
check(not pack:common("Guard", {}, vec(), color), "no shield mesh yet: the game draws the guard")
check(not pack:swing("KAI", vec(), 0, color), "no slash mesh yet: the game draws the arc")
-- the meshes loaded too
for k in VfxConfig.MESHES do VfxConfig.MESHES[k] = 1 meshes.children[k] = true end
check(pack:common("Guard", {}, vec(), color) and calls[#calls] == "Guard", "the shield mesh there: the pack's guard")
check(pack:swing("KAI", vec(), 0, color) and calls[#calls] == "Swing KAI", "the slash mesh there: the pack's arc")
check(pack:hit("KAI", "ko", vec(1, 2, 0), -1, color, 8, {}) and calls[#calls] == "Impact KAI finisher", "a K.O. blow is the pack's finisher")
check(pack:hit("KAI", "heavy", vec(), 1, color, 4, {}) and calls[#calls] == "Impact KAI medium", "a strong blow is the pack's medium")
check(pack:update(rig, { kit = "KAI", meter = 210 }, nil, clock, color) and rig.pack.on, "KAI dressed")
check(table.find(calls, "Aura KAI 2") ~= nil, "aura level 2 at 210 of 300")
check(pack:trail(rig, "RightHand", true) and calls[#calls] == "TrailOn KAI", "the pack's trail lights")
check(pack:trail(rig, "RightHand", true) and calls[#calls] == "TrailOn KAI", "and is not lit twice")
check(pack:trigger(rig, "KAI", {}) and calls[#calls] == "Trigger KAI", "KAI's RESOLVE")
check(not pack:trigger(rig, "AKEMI"), "an evade is not KAI's to draw")
local ryu = { model = { Parent = true }, trails = {} }
pack:update(ryu, { kit = "RYUKEN", meter = 0, passive = 4 }, nil, clock, color)
check(table.find(calls, "Set RYUKEN 4") ~= nil, "RYUKEN's rage stacks")
local boss = { model = { Parent = true }, trails = {} }
check(pack:update(boss, { kit = "KUROEN SHIN", meter = 300 }, nil, clock, color) and table.find(calls, "Aura KUROEN_SHIN 3") ~= nil, "KUROEN SHIN by the pack's name")
check(pack:shot("TARO", color, {}) ~= nil and calls[#calls] == "Skill TARO", "TARO's shot by the pack")
check(pack:shot("KAI", color, {}) == nil, "KAI's KIKOHO stays Wilhem's ball")
check(not pack:common("Parry", nil), "no body: the game draws it, the pack stays on")
check(pack:common("Parry", {}, color) and calls[#calls] == "Parry", "the pack's parry")
check(not pack:common("Boom", {}) and not pack:ready("COMMON") and #warned == 1, "a failing effect: back to the game's effects, one warning")
check(pack:ready("KAI"), "a kit's own family stays on")
VfxConfig.TEXTURES.KAI_KI_POP_4x4 = 0
local fresh = VfxPack.new(effects)
check(not fresh:ready("KAI") and fresh:ready("TARO"), "one missing texture keeps only KAI on the game's effects")
-- a texture that does not load (a wrong ID): named in the output and left out, the pack stays on
VfxConfig.TEXTURES.KAI_KI_POP_4x4 = 1
VfxConfig.TEXTURES.TARO_FIRE_RING_4x4 = 777
failIds["rbxassetid://777"] = true
local before = #warned
local checked = VfxPack.new(effects)
check(checked:ready("KAI") and checked:ready("TARO"), "one texture did not load: the pack stays on for every fighter")
check(table.find(calls, "Blank TARO_FIRE_RING_4x4") ~= nil, "and that texture is left out of the effects")
check(#warned == before + 1 and string.find(warned[#warned], "TARO_FIRE_RING_4x4 rbxassetid://777", 1, true) ~= nil,
	"the texture that did not load is named")
-- a texture still loading (a slow connection) is not a failure
VfxConfig.TEXTURES.TARO_FIRE_RING_4x4 = 1
VfxConfig.TEXTURES.KAI_KI_POP_4x4 = 778
slowIds["rbxassetid://778"] = true
before = #warned
local slow = VfxPack.new(effects)
check(slow:ready("KAI") and #warned == before and not slow.failed.KAI_KI_POP_4x4, "a time-out is not a failure")
-- many textures that do not load: that fighter goes back to the game's effects, the others stay
local need = VfxConfig.kitNeed("TARO")
local lost = VfxPack.tolerated(#need.textures) + 1
for i = 1, lost do
	VfxConfig.TEXTURES[need.textures[#need.textures - i + 1]] = 900 + i
	failIds["rbxassetid://" .. (900 + i)] = true
end
local many = VfxPack.new(effects)
check(not many:ready("TARO"), ("%d of TARO's %d textures lost: TARO keeps the game's effects"):format(lost, #need.textures))
for k, id in saved do VfxConfig.TEXTURES[k] = id end
for k, id in savedMeshes do VfxConfig.MESHES[k] = id end
print(if failed == 0 then "VfxPack smoke: all passed" else ("VfxPack smoke: %d failed"):format(failed))
if failed > 0 then error("VfxPack smoke failed") end
'''


def main():
    body = open(os.path.join(ROOT, "src/client/VfxPack.luau"), encoding="utf-8").read()
    path = os.path.join(ROOT, "tests", "_vfxsmoke.luau")
    with open(path, "w", encoding="utf-8") as f:
        f.write(HEAD + body + TAIL)
    try:
        code = subprocess.call(["luau", path], cwd=ROOT)
    finally:
        os.remove(path)
    sys.exit(code)


if __name__ == "__main__":
    main()
