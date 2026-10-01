"""Builds the fighter bodies of src/server/RigBuilder.luau offline, with the small Roblox
stand-in of tools/RobloxMock.luau (no Studio):

    python3 tools/rigcheck.py check            # every kit and style: block body + outfit on R6 / R15
    python3 tools/rigcheck.py render out.png   # design sheet: each kit, front and back, block + R6

The Luau CLI cannot swap `require` or the Roblox globals inside a module, so this script
inlines RigBuilder into one file with the stand-ins as locals, runs it with `luau`, and (for
render) draws the parts with tools/storyboard.py. Needs Python 3 (and Pillow for render).
"""
import os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LUAU = os.environ.get('LUAU', 'luau')

DRIVER = r'''
local CharacterData = require("../src/shared/CharacterData")
local RigSpec = require("../src/shared/RigSpec")
local mode = ...
local failures = 0
local function fail(text)
	failures += 1
	print("FAIL " .. text)
end

-- A plain R6 body (the classic 2 x 2 x 1 torso), as a Roblox R6 avatar would have.
local R6_POS = { Torso = { 0, 0, 0 }, HumanoidRootPart = { 0, 0, 0 }, Head = { 0, 1.5, 0 },
	["Left Arm"] = { -1.5, 0, 0 }, ["Right Arm"] = { 1.5, 0, 0 }, ["Left Leg"] = { -0.5, -2, 0 }, ["Right Leg"] = { 0.5, -2, 0 } }
local function r6Body()
	local model = Instance.new("Model")
	for name, p in RigSpec.R6.parts do
		local part = Instance.new("Part")
		part.Name, part.Size = name, Vector3.new(p.size[1], p.size[2], p.size[3])
		local pos = R6_POS[name] or { 0, 0, 0 }
		part.CFrame = CFrame.new(pos[1], pos[2], pos[3])
		part.Color = Color3.fromHex("A3A2A5")
		part.Parent = model
	end
	local h = Instance.new("Humanoid")
	h.Parent = model
	return model
end

-- Every visible part is held to the body: by a joint, a weld, or a tail weld.
local function check(model, label)
	local held = {}
	for _, d in model:GetDescendants() do
		if d.ClassName == "WeldConstraint" or d.ClassName == "Weld" or d.ClassName == "Motor6D" then
			if d.Part1 then held[d.Part1] = true end
			if d.Part0 and d.ClassName ~= "Motor6D" then held[d.Part0] = true end
		end
	end
	local count = 0
	for _, p in Mock.parts(model) do
		count += 1
		if p.Name ~= "HumanoidRootPart" and not held[p] and not RigSpec.R6.parts[p.Name] and not p.Name:find("Torso$") then
			fail(label .. ": " .. p.Name .. " is not attached")
		end
		local s = p.Size
		if type(s) ~= "table" or type(s.X) ~= "number" or type(s.Y) ~= "number" or type(s.Z) ~= "number" then fail(string.format("%s: %s size %s %s %s", label, p.Name, tostring(s.X), tostring(s.Y), tostring(s.Z))); continue end
		if not (s.X > 0 and s.Y > 0 and s.Z > 0 and s.X < 20 and s.Y < 20 and s.Z < 20) then
			fail(string.format("%s: %s has a bad size %.2f %.2f %.2f", label, p.Name, s.X, s.Y, s.Z))
		end
		if p.CFrame.Position.Magnitude > 8 then fail(label .. ": " .. p.Name .. " is far from the body") end
	end
	return count
end

local function fmt(n) return string.format("%.3f", n) end
local tick = 0
local function emit(models, label, cam)
	tick += 1
	print(string.format("FRAME %d %s 30 0 000000 0 -", tick, label))
	print(string.format("CAM %s %s %s 0 0.2 0", fmt(cam[1]), fmt(cam[2]), fmt(cam[3])))
	for slot, entry in models do
		for _, p in Mock.parts(entry.model) do
			if (p.Transparency or 0) < 0.95 then
				local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = p.CFrame:GetComponents()
				print(string.format("PART %d %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s",
					slot, p.Name:gsub(" ", "_"), fmt(x + entry.dx), fmt(y), fmt(z),
					fmt(r00), fmt(r01), fmt(r02), fmt(r10), fmt(r11), fmt(r12), fmt(r20), fmt(r21), fmt(r22),
					fmt(p.Size.X), fmt(p.Size.Y), fmt(p.Size.Z), p.Color.hex))
			end
		end
	end
end

local KITS = { "KAI", "TARO", "ZEPHYR", "AKEMI", "RYUKEN", "SHIN", "DAICHA", "HIBECARES" }
for _, kit in KITS do
	for i, style in CharacterData.StyleOrder[kit] do
		CharacterData[1] = CharacterData.Skins[style]
		local ok, block = pcall(RigBuilder.build, 1, nil)
		if not ok then fail(kit .. " " .. style .. " block: " .. tostring(block)); continue end
		local n = check(block, kit .. " " .. style .. " block")
		local r6 = r6Body()
		local ok6, err6 = pcall(RigBuilder.applyKit, r6, 1)
		if not ok6 then fail(kit .. " " .. style .. " R6 outfit: " .. tostring(err6)) end
		check(r6, kit .. " " .. style .. " R6")
		-- An R15 avatar: the KAI block body stands in for its parts.
		CharacterData[1] = CharacterData.Skins.CLASSIQUE
		local r15 = RigBuilder.build(1, nil)
		CharacterData[1] = CharacterData.Skins[style]
		local ok15, err15 = pcall(RigBuilder.applyKit, r15, 1)
		if not ok15 then fail(kit .. " " .. style .. " R15 outfit: " .. tostring(err15)) end
		if mode == "check" then
			print(string.format("ok   %s %s: block %d parts", kit, style, n))
		elseif i == 1 then
			local models = { { model = block, dx = -1.7 }, { model = r6, dx = 1.7 } }
			emit(models, kit .. "-front", { -6, 1.4, -18 })
			emit(models, kit .. "-back", { 6, 1.8, 18 })
		end
	end
end
-- Roblox's avatar joint upgrade: the joints arrive as AnimationConstraints (with rig
-- attachments, or not) instead of Motor6D. RigReader.ensureJoints rebuilds the Motor6D so
-- the body can be animated, without moving any part.
local function near(a, b)
	local ax, ay, az, a1, a2, a3, a4, a5, a6, a7, a8, a9 = a:GetComponents()
	local bx, by, bz, b1, b2, b3, b4, b5, b6, b7, b8, b9 = b:GetComponents()
	local d = 0
	for _, pair in { { ax, bx }, { ay, by }, { az, bz }, { a1, b1 }, { a5, b5 }, { a9, b9 }, { a2, b2 }, { a4, b4 } } do
		d = math.max(d, math.abs(pair[1] - pair[2]))
	end
	return d < 1e-4
end
local function upgraded(model, withAttachments)
	for _, d in model:GetDescendants() do
		if d.ClassName == "Motor6D" then
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Name, a1.Name = d.Name .. (if withAttachments then "RigAttachment" else "Point"), d.Name .. (if withAttachments then "RigAttachment" else "Point")
			a0.CFrame, a1.CFrame = d.C0, d.C1
			a0.Parent, a1.Parent = d.Part0, d.Part1
			local c = Instance.new("AnimationConstraint")
			c.Name, c.Attachment0, c.Attachment1 = d.Name, a0, a1
			c.Parent = d.Part1
			d:Destroy()
		end
	end
	return model
end
local function jointsCheck(label, model, expected)
	local before = {}
	for _, p in Mock.parts(model) do before[p] = p.CFrame end
	local rebuilt = RigReader.ensureJoints(model)
	if rebuilt ~= expected then fail(string.format("%s: %d joints rebuilt instead of %d", label, rebuilt, expected)) end
	local skeleton = RigReader.skeleton(model)
	if not skeleton then fail(label .. ": the skeleton still cannot be read") end
	for _, d in model:GetDescendants() do
		if d.ClassName == "AnimationConstraint" then fail(label .. ": constraint " .. d.Name .. " left") end
		if d.ClassName == "Motor6D" and not near(d.Part0.CFrame * d.C0 * d.C1:Inverse(), d.Part1.CFrame) then
			fail(label .. ": joint " .. d.Name .. " would move " .. d.Part1.Name)
		end
	end
	if RigReader.ensureJoints(model) ~= 0 then fail(label .. ": joints rebuilt twice") end
	if mode == "check" then print("ok   " .. label) end
end
CharacterData[1] = CharacterData.Skins.CLASSIQUE
jointsCheck("R15 with AnimationConstraints + rig attachments", upgraded(RigBuilder.build(1, nil), true), 15)
jointsCheck("R15 with AnimationConstraints, no rig attachment", upgraded(RigBuilder.build(1, nil), false), 15)
jointsCheck("R15 already in Motor6D", RigBuilder.build(1, nil), 0)
jointsCheck("R6 without joints", r6Body(), 6)

if mode == "check" then
	print(if failures == 0 then "all bodies built" else failures .. " failure(s)")
end
'''

def combined():
    mock = 'local Mock = require("./RobloxMock")\n' \
        'local game, workspace, Instance, Vector3, CFrame, Color3, Enum, UDim2, Vector2 = ' \
        'Mock.game, Mock.workspace, Mock.Instance, Mock.Vector3, Mock.CFrame, Mock.Color3, Mock.Enum, Mock.UDim2, Mock.Vector2\n' \
        'local typeof = Mock.typeof\n' \
        'local task = { spawn = function(f, ...) return f(...) end, defer = function() end, wait = function() end }\n'
    reader = open(os.path.join(ROOT, 'src/shared/RigReader.luau'), encoding='utf-8').read()
    reader = reader.replace('local Shared = script.Parent', '')
    reader = re.sub(r'require\(Shared\.(\w+)\)', r'require("../src/shared/\1")', reader)
    src = open(os.path.join(ROOT, 'src/server/RigBuilder.luau'), encoding='utf-8').read()
    src = src.replace('require(Shared.RigReader)', 'RigReader')
    src = re.sub(r'require\(Shared\.(\w+)\)', r'require("../src/shared/\1")', src)
    return (mock + 'local RigReader = (function()\n' + reader + '\nend)()\n'
            + 'local RigBuilder = (function()\n' + src + '\nend)()\n' + DRIVER)

def run(mode):
    path = os.path.join(ROOT, 'tools', '.rigcheck.luau')
    with open(path, 'w', encoding='utf-8') as f:
        f.write(combined())
    try:
        out = subprocess.run([LUAU, path, '-a', mode], capture_output=True, text=True, cwd=ROOT)
    finally:
        os.remove(path)
    if out.returncode != 0:
        sys.stderr.write(out.stdout + out.stderr)
        sys.exit(1)
    return out.stdout

if __name__ == '__main__':
    mode = sys.argv[1] if len(sys.argv) > 1 else 'check'
    if mode == 'check':
        text = run('check')
        print(text, end='')
        sys.exit(1 if 'FAIL' in text else 0)
    text = run('render')
    target = sys.argv[2] if len(sys.argv) > 2 else 'rigs.png'
    story = target + '.txt'
    with open(story, 'w') as f:
        f.write(text)
    os.environ.setdefault('STORY_W', '720')
    os.environ.setdefault('STORY_COLS', '2')
    subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'storyboard.py'), story, target], check=True,
                   env=dict(os.environ))
    os.remove(story)
    print(target)
