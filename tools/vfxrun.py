#!/usr/bin/env python3
"""Runs Wilhem's VFX pack (src/client/VFX) through the game's bridge (src/client/VfxPack.luau)
on a strict stand-in for the Roblox engine (tools/RobloxStrict.luau), checked against Roblox's
real API: every effect the game calls, for every fighter, frame by frame. It fails where Roblox
would fail (a property that does not exist, a value of the wrong type, an Enum that does not
exist, a sequence that does not start at 0...) and names the effects that would fall back to
the game's own ones. Nothing is drawn: judge the look in Studio.

    python3 tools/vfxrun.py                 (needs `luau` on the PATH)
    python3 tools/vfxrun.py --refresh [Full-API-Dump.json]
        rewrites tools/RobloxApi.luau from Roblox's API dump (downloaded when no file is given)

Two runs: the meshes not uploaded yet (the game today) and every mesh loaded.
"""
import json
import os
import re
import subprocess
import sys
import urllib.request

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
API_PATH = os.path.join(ROOT, "tools", "RobloxApi.luau")
DUMP_URL = "https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/Full-API-Dump.json"
SOURCES = ["src/client/VFX/VFX_Common.luau", "src/client/VFX/VFX_Chars.luau", "src/client/VFX/VFX_Specials.luau",
           "src/client/VfxPack.luau"]
# (the classes the stand-in builds itself, beside those the sources name)
BASE_CLASSES = ["DataModel", "Workspace", "Camera", "Players", "Player", "PlayerGui", "Lighting", "ReplicatedStorage",
                "RunService", "TweenService", "Tween", "Debris", "ContentProvider", "UserInputService", "StarterPlayer",
                "SoundService", "Folder", "ModuleScript", "LocalScript", "Model", "Part", "MeshPart", "Humanoid",
                "Attachment", "Trail", "WeldConstraint", "Motor6D"]


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def refresh(dump_path=None):
    if dump_path:
        dump = json.load(open(dump_path, encoding="utf-8"))
    else:
        with urllib.request.urlopen(DUMP_URL) as r:
            dump = json.load(r)
    by_name = {c["Name"]: c for c in dump["Classes"]}
    text = "".join(open(os.path.join(ROOT, p), encoding="utf-8").read() for p in SOURCES)
    wanted = set(BASE_CLASSES) | {n for n in re.findall(r'"([A-Z][A-Za-z0-9]+)"', text) if n in by_name}
    for name in list(wanted):  # (and every superclass)
        c = by_name.get(name)
        while c and c.get("Superclass") and c["Superclass"] != "<<<ROOT>>>":
            wanted.add(c["Superclass"])
            c = by_name.get(c["Superclass"])
    enums_used = set(re.findall(r"Enum\.([A-Za-z]+)", text))
    out = ["-- Written by tools/vfxrun.py --refresh from Roblox's API dump: the classes the VFX pack",
           "-- touches (and their superclasses), their members, and the Enums. Do not edit by hand.",
           "return {", "\tclasses = {"]
    for name in sorted(wanted):
        c = by_name.get(name)
        if not c:
            continue
        tags = c.get("Tags") or []
        members = []
        for m in c["Members"]:
            mt = m["MemberType"]
            mtags = m.get("Tags") or []
            sec = m.get("Security")
            read_sec = sec if isinstance(sec, str) else (sec or {}).get("Read", "None")
            write_sec = sec if isinstance(sec, str) else (sec or {}).get("Write", "None")
            hidden = "NotScriptable" in mtags
            if mt == "Property":
                vt = m["ValueType"]
                if vt["Category"] == "Enum":
                    enums_used.add(vt["Name"])
                fields = ['kind = "Property"', "t = " + lua_str(vt["Name"]), "cat = " + lua_str(vt["Category"])]
                if m.get("Default") is not None and m.get("Default") != "__api_dump_no_string_value__":
                    fields.append("default = " + lua_str(str(m["Default"])))
                if "ReadOnly" in mtags:
                    fields.append("readonly = true")
                if hidden or read_sec != "None":
                    fields.append("noread = true")
                if hidden or write_sec != "None":
                    fields.append("nowrite = true")
            elif mt == "Function":
                if hidden or read_sec != "None":
                    continue
                fields = ['kind = "Function"']
            elif mt == "Event":
                if hidden or read_sec != "None":
                    continue
                fields = ['kind = "Event"']
            else:
                continue
            members.append("\t\t\t[%s] = { %s }," % (lua_str(m["Name"]), ", ".join(fields)))
        sup = c.get("Superclass")
        out.append("\t\t[%s] = {" % lua_str(name))
        if sup and sup != "<<<ROOT>>>":
            out.append("\t\t\tsuper = %s," % lua_str(sup))
        if "NotCreatable" in tags:
            out.append("\t\t\tnotCreatable = true,")
        if "Service" in tags:
            out.append("\t\t\tservice = true,")
        out.append("\t\t\tmembers = {")
        out.extend("\t" + line for line in members)
        out.append("\t\t\t},")
        out.append("\t\t},")
    out.append("\t},")
    out.append("\tenums = {")
    for e in sorted(dump["Enums"], key=lambda e: e["Name"]):
        if e["Name"] not in enums_used:
            continue
        items = ", ".join("[%s] = %d" % (lua_str(i["Name"]), i["Value"]) for i in e["Items"])
        out.append("\t\t[%s] = { %s }," % (lua_str(e["Name"]), items))
    out.append("\t},")
    out.append("}")
    open(API_PATH, "w", encoding="utf-8").write("\n".join(out) + "\n")
    print("tools/RobloxApi.luau: %d classes, %d enums" % (len(wanted), len(enums_used)))


HARNESS = r'''
local API = require("../tools/RobloxApi")
local makeEnv = require("../tools/RobloxStrict")
local VfxConfig = require("../src/shared/VfxConfig")
local CombatConfig = require("../src/shared/CombatConfig")
local CHUNKS = ...CHUNKS...

-- the stand-in fails where Roblox fails (else this run proves nothing)
do
	local env = makeEnv(API)
	local wrong = 0
	local function refused(what, fn)
		if pcall(fn) then
			print("  FAIL the stand-in let this through: " .. what)
			wrong += 1
		end
	end
	local e = env.Instance.new("ParticleEmitter")
	refused("a property that does not exist", function() e.Sprite = 1 end)
	refused("a value of the wrong type", function() e.Rate = "fast" end)
	refused("an Enum item that does not exist", function() return env.Enum.ParticleFlipbookLayout.Grid3x3 end)
	refused("an Enum value of the wrong Enum", function() e.FlipbookLayout = env.Enum.NormalId.Top end)
	refused("a NumberSequence that does not start at 0", function()
		return env.NumberSequence.new({ env.NumberSequenceKeypoint.new(0.1, 1), env.NumberSequenceKeypoint.new(1, 0) })
	end)
	refused("a NumberRange upside down", function() return env.NumberRange.new(2, 1) end)
	refused("a class that does not exist", function() return env.Instance.new("Sparkle") end)
	refused("a service created by hand", function() return env.Instance.new("Workspace") end)
	refused("a MeshPart's MeshId set by a script", function() env.Instance.new("MeshPart").MeshId = "rbxassetid://1" end)
	refused("a read-only property", function() env.workspace.CurrentCamera.ViewportSize = env.Vector2.new(1, 1) end)
	refused("a bad hex colour", function() return env.Color3.fromHex("GG0000") end)
	refused("a destroyed part given a parent again", function()
		local p = env.Instance.new("Part")
		p:Destroy()
		p.Parent = env.workspace
	end)
	refused("a method that does not exist", function() e:Burst(3) end)
	if wrong > 0 then error("the stand-in is not strict enough") end
	print("the stand-in refuses what Roblox refuses (13 checks)")
end

local function scenario(title, withMeshes, failKeys)
	local env = makeEnv(API)
	env.failAssets = {}
	for _, key in failKeys or {} do env.failAssets[VfxConfig.texture(key)] = true end
	local game, Vector3, CFrame, Color3 = env.game, env.Vector3, env.CFrame, env.Color3
	local RS = env.services.ReplicatedStorage
	local shared = env.newInstance("Folder", { Name = "Shared" }, RS)
	env.module(env.newInstance("ModuleScript", { Name = "VfxConfig" }, shared), function() return VfxConfig end)
	env.module(env.newInstance("ModuleScript", { Name = "CombatConfig" }, shared), function() return CombatConfig end)
	-- (the server's loader: the folder always, a MeshPart per mesh once uploaded)
	local meshes = env.newInstance("Folder", { Name = "VFX_Meshes" }, RS)
	if withMeshes then
		for key in VfxConfig.MESHES do
			env.newInstance("MeshPart", { Name = key, Anchored = true, CanCollide = false, Size = Vector3.new(4, 4, 4) }, meshes)
		end
	end
	local player = env.services.Players.LocalPlayer
	local client = env.newInstance("LocalScript", { Name = "Client" }, env.newInstance("Folder", { Name = "PlayerScripts" }, player))
	local folder = env.newInstance("Folder", { Name = "VFX" }, client)
	local packScript
	for name, chunk in CHUNKS do
		local parent = if name == "VfxPack" then client else folder
		local s = env.newInstance("ModuleScript", { Name = name }, parent)
		if name == "VfxPack" then packScript = s end
		setfenv(chunk, env.globals(s))
		env.module(s, chunk)
	end

	-- a fighter as the game builds it: a block body with a root, limbs, a Humanoid, its kit
	local function fighter(kit, x)
		local model = env.newInstance("Model", { Name = kit }, env.workspace)
		local function part(name, size, at)
			return env.newInstance("Part", { Name = name, Size = size, CFrame = CFrame.new(x + at.X, at.Y, at.Z), Anchored = true }, model)
		end
		local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0))
		part("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 5, 0))
		part("UpperTorso", Vector3.new(2, 1.6, 1), Vector3.new(0, 3.6, 0))
		local hands, trails = {}, {}
		for _, limb in { "RightHand", "LeftHand", "RightFoot", "LeftFoot" } do
			local p = part(limb, Vector3.new(0.6, 0.6, 0.6), Vector3.new(if limb:find("Right") then 1.2 else -1.2, if limb:find("Hand") then 3 else 0.3, 0))
			hands[limb] = p
			local a0 = env.newInstance("Attachment", { Name = "TrailA" }, p)
			local a1 = env.newInstance("Attachment", { Name = "TrailB", Position = Vector3.new(0, 0.4, 0) }, p)
			trails[limb] = env.newInstance("Trail", { Name = limb .. "Trail", Attachment0 = a0, Attachment1 = a1, Enabled = false }, p)
		end
		local weapon = part("KitBlade", Vector3.new(0.2, 0.2, 4), Vector3.new(1.5, 3.5, 0))
		local w0 = env.newInstance("Attachment", { Name = "Base", Position = Vector3.new(0, 0, 2) }, weapon)
		local w1 = env.newInstance("Attachment", { Name = "Tip", Position = Vector3.new(0, 0, -2) }, weapon)
		trails.Weapon = env.newInstance("Trail", { Name = "WeaponTrail", Attachment0 = w0, Attachment1 = w1, Enabled = false }, weapon)
		env.newInstance("Humanoid", { Name = "Humanoid", HipHeight = 2 }, model)
		model.PrimaryPart = root
		model:SetAttribute("Kit", kit)
		model:SetAttribute("RootHeight", 3)
		return { model = model, trails = trails, hand = hands.RightHand }
	end

	local freshBody = #fighter("COUNT", 40).model:GetDescendants()
	-- (with textures that did not load: nothing drawn with them may be in the world, at any frame)
	local unseenFails = {}
	if failKeys and #failKeys > 0 then
		local function textureOf(d)
			local st = env.state(d)
			if d:IsA("Trail") or d:IsA("Beam") then return st.set.Texture and d.Texture end
			if d:IsA("MeshPart") then return st.set.TextureID and d.TextureID end
			return nil
		end
		-- (once the preload is over: a piece with no texture, or with one that failed, even made
		-- before the preload ended, e.g. a body dressed on the first frame)
		local function failed(tex) return tex == "" or (env.preloaded and env.failAssets[tex]) end
		env.onStep = function()
			for _, d in env.workspace:GetDescendants() do
				local tex = textureOf(d)
				if tex and failed(tex) and not unseenFails[env.label] then
					unseenFails[env.label] = d.ClassName .. " " .. d:GetFullName()
				end
				if d:IsA("ParticleEmitter") and not unseenFails[env.label] then
					local st = env.state(d)
					local seen = false
					for _, k in d.Transparency.Keypoints do
						if k.Value < 1 then seen = true end
					end
					if d.Texture == "" and (st.emitted or 0) > 0 then
						unseenFails[env.label] = "ParticleEmitter emitting with no texture"
					elseif env.preloaded and env.failAssets[d.Texture] and seen then
						unseenFails[env.label] = "ParticleEmitter still shown with a texture that failed: " .. d:GetFullName()
					end
				end
			end
		end
	end
	local sheetIds = { [VfxConfig.texture("HITSPARK_LIGHT_4x4")] = true, [VfxConfig.texture("HITSPARK_HEAVY_4x4")] = true }
	local noSheet = {}
	local function emitters()
		local set = {}
		local fx = env.workspace:FindFirstChild("BFZ_VFX")
		for _, d in (if fx then fx:GetDescendants() else {}) do
			if d:IsA("ParticleEmitter") then set[d] = true end
		end
		return set
	end
	local shakes = 0
	local effects = { reduced = false, camera = { shake = function() shakes += 1 end } }
	local VfxPack = env.call("load the bridge", env.require, packScript)
	local pack = VfxPack.new(effects)
	local results = {} -- label -> "pack" / "game" (who draws it)
	local function try(label, fn)
		local before = #env.errors + #env.warns
		local r = env.call(label, fn)
		results[label] = if r then "pack" else "game"
		return r
	end
	local function ready(family)
		local ok = pack:ready(family)
		if not ok then
			local need = if family == "COMMON" then VfxConfig.COMMON else VfxConfig.kitNeed(family)
			local missing = need and VfxConfig.missing({ textures = need.textures, meshes = {} }) or { "(not a family)" }
			table.insert(env.errors, { label = family, kind = "not ready", msg = "missing: " .. table.concat(missing, ", ") })
		end
		return ok
	end

	env.label = "ready"
	ready("COMMON")
	-- a body dressed on the first frame, before the preload is over (the game's order: the first
	-- call is the frame's update)
	local early = fighter("KAI", -8)
	env.label = "KAI dressed before the preload"
	try("KAI dressed before the preload", function()
		return pack:update(early, { kit = "KAI", meter = 300, state = "Attack" }, nil, env.clock, Color3.fromHex("FF2A3D"))
	end)
	pack:trail(early, "RightHand", true)
	local kits = {}
	for kit in VfxConfig.KITS do table.insert(kits, kit) end
	table.sort(kits)
	local white = Color3.new(1, 1, 1)
	local other = fighter("FOE", 4)

	-- the shared effects, as EffectsController calls them
	local a = fighter("KAI", -4)
	local commons = {
		{ "Knockdown", Vector3.new(0, 0, 0) },
		{ "WallBounce", CFrame.lookAt(Vector3.new(-27, 4, 0), Vector3.new(-26, 4, 0)), white },
		{ "GroundBounce", Vector3.new(0, 0.05, 0), nil },
		{ "SuperJump", a.model, Color3.fromHex("FF2A3D") },
		{ "FastFall", a.model, Color3.fromHex("FF2A3D") },
		{ "DashAir", a.model, Color3.fromHex("FF2A3D"), Vector3.new(1, 0, 0) },
		{ "GrabGlint", a.hand, Color3.fromHex("5BE3A1") },
		{ "GrabFinish", CFrame.new(0, 3, 0), Color3.fromHex("FF2A3D"), { hitstop = 6, ignore = { a.model, other.model } } },
		{ "GrabEscape", CFrame.new(0, 3, 0.6), white },
		{ "Parry", CFrame.new(0, 3, 0.8), Color3.fromHex("FFD23F") },
		{ "Clash", CFrame.new(0, 3, 0.8), Color3.fromHex("FF2A3D"), Color3.fromHex("4DA8FF") },
		{ "SuperArmor", a.model },
		{ "Heal", a.model, Color3.fromHex("FFE9A0") },
		{ "Reflect", CFrame.lookAt(Vector3.new(0, 3, 0), Vector3.new(0, 3, 1)), Color3.fromHex("FFE9A0") },
		{ "Burst", a.model, Color3.fromHex("FFD23F") },
		{ "Guard", other.model, Vector3.new(3, 3, 0), Color3.fromHex("4DA8FF") },
		{ "GuardBreak", other.model, Color3.fromHex("4DA8FF"), 1.2 },
	}
	for _, c in commons do
		try("common " .. c[1], function() return pack:common(table.unpack(c)) end)
		env.run(0.4)
	end
	a.model:Destroy()
	env.label = "KAI dressed before the preload"
	pack:update(early, { kit = "KAI", meter = 300, state = "Attack" }, nil, env.clock, Color3.fromHex("FF2A3D"))
	env.run(0.5)
	pack:undress(early)
	early.model:Destroy()

	-- every fighter: its impacts at the four tiers, its arc, its dash, its body (trails, aura,
	-- passive), its passive's moments, its shot
	for _, kit in kits do
		env.label = kit
		local f = fighter(kit, -3)
		local color = Color3.fromHex("FF2A3D")
		if ready(kit) then
			for _, tier in { "light", "heavy", "finisher", "ko" } do
				local old = emitters()
				try(kit .. " hit " .. tier, function()
					return pack:hit(kit, tier, Vector3.new(1, 3.4, 0), 1, color, 8, { f.model, other.model })
				end)
				-- (Wilhem's impact sheets drawn at the heart of the blow)
				local sheets = 0
				for e in emitters() do
					if not old[e] and sheetIds[e.Texture] and (env.state(e).emitted or 0) > 0 then sheets += 1 end
				end
				if sheets == 0 then table.insert(noSheet, kit .. " " .. tier) end
				if sheets > 1 then table.insert(env.errors, { label = kit .. " " .. tier, kind = "two impact sheets", msg = sheets .. " HITSPARK sheets on one blow" }) end
				env.run(0.35)
			end
			try(kit .. " swing", function() return pack:swing(kit, Vector3.new(-1, 3.6, 0.8), 60, color) end)
			env.run(0.3)
			try(kit .. " dash", function() return pack:dash(kit, f.model, Vector3.new(1, 0, 0), color) end)
			env.run(0.5)
			for _, meter in { 0, 120, 220, 300 } do
				try(kit .. " body " .. meter, function()
					return pack:update(f, { kit = kit, meter = meter, passive = 4, domination = 2, passiveCharges = 2, sparks = 3,
						hp = 600, maxHp = 1000, passiveOn = true, tempo = 2, state = "Attack" }, { skill = true }, env.clock, color)
				end)
				env.run(0.4)
			end
			try(kit .. " trail", function()
				local r = pack:trail(f, "RightHand", true)
				env.run(0.2)
				pack:trail(f, "RightHand", false)
				return r
			end)
			local moment = ({ KAI = { CFrame.new(-3, 3, 0.8) }, AKEMI = {}, GORAN = { 1.2 }, ELIAN = {} })[kit]
			if moment then
				try(kit .. " passive moment", function() return pack:trigger(f, kit, table.unpack(moment)) end)
				env.run(0.6)
			end
			if kit == "KAZAN" then
				try("KAZAN chain", function()
					local r = pack:set(f, "KAZAN", other.model)
					env.run(1.4)
					pack:set(f, "KAZAN", nil)
					return r
				end)
			end
			try(kit .. " shot", function()
				local anchor = env.newInstance("Part", { Name = "Anchor", Size = Vector3.one * 0.3, Anchored = true, Transparency = 1,
					CFrame = CFrame.lookAt(Vector3.new(-2, 3.4, 0.4), Vector3.new(0, 3.4, 0.4)) }, env.workspace)
				local skill = pack:shot(kit, color, anchor)
				for i = 1, 40 do
					anchor.CFrame = CFrame.lookAt(Vector3.new(-2 + i * 0.2, 3.4, 0.4), Vector3.new(i * 0.2, 3.4, 0.4))
					env.step(1 / 60)
				end
				if skill then
					if skill.Hit then skill.Hit(CFrame.new(6, 3.4, 0.4)) end
					env.run(0.3)
					skill.Destroy()
				end
				anchor:Destroy()
				return skill ~= nil
			end)
			env.run(0.5)
			pack:undress(f)
		end
		f.model:Destroy()
		env.run(1.5)
	end

	-- after everything: what is still in the world
	env.label = "cleanup"
	env.run(12)
	local left = 0
	local fx = env.workspace:FindFirstChild("BFZ_VFX")
	if fx then left = #fx:GetDescendants() end
	local inOther = #other.model:GetDescendants()

	-- the report
	print(("== %s =="):format(title))
	local drawn, kept = {}, {}
	for label, who in results do table.insert(if who == "pack" then drawn else kept, label) end
	table.sort(drawn)
	table.sort(kept)
	print(("  the pack draws %d effects; the game keeps %d:"):format(#drawn, #kept))
	for _, label in kept do print("    game: " .. label) end
	local errors = 0
	for _, e in env.errors do
		errors += 1
		print(("  FAIL [%s] %s: %s"):format(e.label, e.kind, (e.msg:gsub("\n", "\n         "))))
	end
	local budget = 0
	for _, w in env.warns do
		if w.msg:find("budget", 1, true) then
			budget += 1
		elseif failKeys and w.msg:find("did not load", 1, true) then
			print("  (expected) " .. w.msg)
		else
			errors += 1
			print(("  FAIL [%s] warning: %s"):format(w.label, w.msg))
		end
	end
	if budget > 0 then print(("  (%d particle-budget notes from the pack)"):format(budget)) end
	if #noSheet > 0 then
		print(("  impact sheet not drawn on %d blows: %s"):format(#noSheet, table.concat(noSheet, ", ")))
	else
		print("  Wilhem's impact sheet drawn on every blow of every fighter")
	end
	print(("  particles emitted: %d; camera shakes through the game: %d"):format(env.emitted or 0, shakes))
	print(("  left in BFZ_VFX after 12 s: %d instances; on the foe's body: %d (a fresh body has %d)"):format(left, inOther, freshBody))
	if left > 0 or inOther ~= freshBody then
		errors += 1
		print("  FAIL effects left in the world")
	end
	for label, what in unseenFails do
		errors += 1
		print(("  FAIL [%s] drawn with a texture that did not load: %s"):format(label, what))
	end
	if failKeys and #failKeys > 0 and next(unseenFails) == nil then
		print("  nothing drawn with the textures that did not load, at any frame")
	end
	return errors, #noSheet
end

local failed, noSheet = scenario("meshes not uploaded yet (the game today)", false)
if noSheet > 0 then
	failed += 1
	print("  FAIL some blows have no impact sheet")
end
local _, noSheetAll
_, noSheetAll = scenario("every mesh loaded", true)
failed += _
if noSheetAll > 0 then
	failed += 1
	print("  FAIL some blows have no impact sheet")
end
-- textures that do not load: left out (particles, trails, beams, meshes), every effect still
-- plays (no sheet on a light blow without HITSPARK_LIGHT)
failed += scenario("particles, a trail, a beam and meshes do not load", true,
	{ "HITSPARK_LIGHT_4x4", "TRAIL_CORE", "HEX_GRID", "SLASH_ARC", "ENERGY_FLOW", "AKEMI_KUNAI" })
failed += scenario("the other trails and blades do not load", true,
	{ "TRAIL_RIM", "TRAIL_WISPY", "TRAIL_GRADIENT", "SHIN_WATER_RIBBON", "ZEPHYR_AIR_CRESCENT" })
print(if failed == 0 then "VFX run: all passed" else ("VFX run: %d problems"):format(failed))
if failed > 0 then error("VFX run failed") end
'''


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--refresh":
        refresh(sys.argv[2] if len(sys.argv) > 2 else None)
        if len(sys.argv) > 2:
            return
    if not os.path.exists(API_PATH):
        refresh()
    chunks = []
    for p in SOURCES:
        name = os.path.splitext(os.path.basename(p))[0]
        src = open(os.path.join(ROOT, p), encoding="utf-8").read()
        chunks.append("\t[%s] = function(...)\n%s\nend," % (lua_str(name), src))
    harness = HARNESS.replace("...CHUNKS...", "{\n" + "\n".join(chunks) + "\n}")
    path = os.path.join(ROOT, "tests", "_vfxrun_%d.luau" % os.getpid())  # (one per run; .gitignore)
    with open(path, "w", encoding="utf-8") as f:
        f.write(harness)
    try:
        code = subprocess.call(["luau", path], cwd=ROOT)
    finally:
        os.remove(path)
    sys.exit(code)


if __name__ == "__main__":
    main()
