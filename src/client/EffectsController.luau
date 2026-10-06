--[[
	Cosmetic effects only: they never change hitboxes or timing. Everything is local to this
	client and short-lived. "Reduced" mode drops screen flashes and lowers shake/particle counts
	(see the project guide: option to reduce flashes and shakes, lighter VFX on mobile).
]]
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local MoveData = require(Shared.MoveData)
local Sim = require(Shared.CombatSimulation)
local CharacterData = require(Shared.CharacterData)
local RigReader = require(Shared.RigReader)
local PoseLibrary = require(Shared.PoseLibrary)
local OrbFlight = require(Shared.OrbFlight)
local WeaponFX = require(Shared.WeaponFX)
local BLOCK_SPARKS -- (set with the weapons below)
local KitFX = require(Shared.KitFX)

local EffectsController = {}

local WHITE = Color3.fromHex("FFFFFF")
local BODY_PARTS = {
	Head = true, UpperTorso = true, LowerTorso = true,
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
	RightUpperArm = true, RightLowerArm = true, RightHand = true,
	LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true,
	RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
	Torso = true, ["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true, -- R6
}

-- Limbs that strike with each move (PoseLibrary.STRIKE: the move's own entry, else its role's):
-- their motion trails light up during the swing.
local ROLE_OF = {}
for _, kit in MoveData.Kits do
	for role, id in kit.Roles do ROLE_OF[id] = role end
end
local function strikeLimbs(id)
	return PoseLibrary.STRIKE[id] or PoseLibrary.STRIKE[ROLE_OF[id] or ""]
end
local TRAIL_LIMBS = { "LeftHand", "RightHand", "LeftFoot", "RightFoot" }

local function tween(instance, duration, goal, style)
	local t = TweenService:Create(instance, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

function EffectsController.new(config, camera)
	local self = setmetatable({
		config = config, camera = camera,
		reduced = UIS.TouchEnabled and not UIS.KeyboardEnabled,
		debug = false, rigs = {}, ghostClock = {}, debugParts = {},
	}, { __index = EffectsController })
	self.folder = Instance.new("Folder")
	self.folder.Name, self.folder.Parent = "ClientEffects", workspace
	self.grade = Instance.new("ColorCorrectionEffect")
	self.grade.Name, self.grade.Enabled, self.grade.Parent = "ImpactFrame", false, Lighting
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset, gui.DisplayOrder = "ImpactOverlay", false, true, 3
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.overlay = gui
	return self
end

function EffectsController:energy(slot)
	return Color3.fromHex(CharacterData[slot].Energy)
end

function EffectsController:part(size, cframe, color, shape)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Material, p.Color, p.Size, p.CFrame = Enum.Material.Neon, color, size, cframe
	if shape then p.Shape = shape end
	p.Parent = self.folder
	return p
end

-- Manga star burst: alternating white and energy-colored rays plus a bright core.
function EffectsController:spark(position, color, scale)
	local rays = if self.reduced then 6 else 11
	local front = position + Vector3.new(0, 0, 1.4)
	for i = 1, rays do
		local angle = (i / rays) * math.pi * 2 + math.random() * 0.4
		local length = (1.2 + math.random() * 1.6) * scale
		local rot = CFrame.new(front) * CFrame.Angles(0, 0, angle)
		local ray = self:part(Vector3.new(0.16 * scale, length, 0.05), rot * CFrame.new(0, length / 2 + 0.3, 0),
			if i % 2 == 0 then WHITE else color)
		tween(ray, 0.16, { CFrame = rot * CFrame.new(0, length + 0.9 * scale, 0), Size = Vector3.new(0.02, length * 1.5, 0.05), Transparency = 1 })
		Debris:AddItem(ray, 0.2)
	end
	local core = self:part(Vector3.one * 0.8 * scale, CFrame.new(front), WHITE, Enum.PartType.Ball)
	tween(core, 0.12, { Size = Vector3.one * 2.6 * scale, Transparency = 1 })
	Debris:AddItem(core, 0.15)
	local ring = self:part(Vector3.new(0.05, 1, 1) * scale, CFrame.new(front) * CFrame.Angles(0, math.pi / 2, 0), color, Enum.PartType.Cylinder)
	ring.Transparency = 0.2
	tween(ring, 0.2, { Size = Vector3.new(0.05, 4.5, 4.5) * scale, Transparency = 1 })
	Debris:AddItem(ring, 0.25)
end

-- Guard effect in front of the defender (blue/violet star from the art sheet).
function EffectsController:shield(fighter, color)
	local center = Vector3.new(fighter.x + fighter.facing * 1.2, fighter.y + 3.4, 0.6)
	local disc = self:part(Vector3.new(0.1, 3.4, 3.4), CFrame.new(center) * CFrame.Angles(0, math.rad(-fighter.facing * 25), 0), color, Enum.PartType.Cylinder)
	disc.Material, disc.Transparency = Enum.Material.ForceField, 0
	tween(disc, 0.22, { Size = Vector3.new(0.1, 5, 5), Transparency = 1 })
	Debris:AddItem(disc, 0.25)
	self:spark(center, color, 0.7)
end

-- ===================================================================== weapons
-- SHIN's katana and DAICHA's shadow orb (src/shared/WeaponSpec.luau). Every sword stroke
-- draws its own arc (flat, diagonal, vertical, a full ring for the spins; arc = { from, to,
-- radius, height, tilt } in the fighting plane), a straight cut for the thrusts (`line`: its
-- height, -1 = plunged down) and a strike on the floor for the heavy cuts; every orb strike
-- its burst, the heavy a beam, the spins a vortex of orbs. By role (the combo slot).
local SWORD = {
	Jab = { arc = { 100, -40, 3.4, 3.6, 1.25 } }, Cross = { arc = { -70, 60, 3.2, 3.0, 0.5 } }, Elbow = { line = 3.4 },
	Kick = { arc = { 130, -70, 4.0, 3.4, 0.25 } }, KiFlurry = { arc = { 100, -40, 3.4, 3.6, 1.25 } },
	Smash = { arc = { 110, -70, 3.8, 3.2, 0 }, ground = true }, Hammer = { arc = { 130, -50, 3.8, 3.4, 0.45 }, ground = true },
	Uppercut = { arc = { -80, 110, 3.2, 2.8, 0 } }, BodyBlow = { line = 2.4 }, PalmStrike = { line = 3.2 },
	KiBlast = { arc = { 110, -40, 4.2, 3.4, 1.3 } }, Rising = { arc = { 120, -30, 3.8, 2.6, 1.3 }, line = 2.6 },
	DragonTornado = { arc = { 0, 360, 3.6, 3.2, 1.45 } }, SpinKick = { arc = { 200, -40, 3.6, 3.2, 1.3 } },
	LowKick = { arc = { 100, -40, 3.2, 1.0, 1.4 } }, Sweep = { arc = { -60, 120, 3.6, 0.9, 1.4 } },
	AirKick = { arc = { 110, -60, 3.0, 2.6, 0 } }, AirKick2 = { arc = { 100, -40, 3.0, 2.8, 1.25 } },
	AirSmash = { line = -1, ground = true }, CrescentMoon = { arc = { 90, -270, 3.2, 2.6, 0 } },
	DragonFist = { arc = { -80, 110, 3.0, 3.0, 0.2 } }, RisingWind = { arc = { 0, 360, 3.2, 3.0, 1.45 } },
	ThunderHeel = { arc = { 120, -60, 3.4, 3.0, 0 }, ground = true }, KiChase = { line = 3 },
	Finale = { arc = { 120, -40, 4.4, 3.2, 1.3 }, line = 3.4 }, KaienRush = { arc = { 120, -40, 4.4, 3.2, 1.3 } },
	Awakening = { arc = { 120, -40, 4.4, 3.2, 1.3 }, line = 3.4 }, Kaiten = { arc = { 110, -70, 3.8, 3.2, 0 }, ground = true },
}
local ORB = {
	Jab = { burst = 0.8 }, Cross = { burst = 0.8, arc = { 60, -80, 3.0, 3.4, 0.6 } }, Elbow = { burst = 1.1 },
	Kick = { burst = 1.8, ground = true }, Smash = { beam = 9 }, Hammer = { burst = 1.5, ground = true },
	KiBlast = { burst = 0.9 }, PalmStrike = { burst = 1 }, BodyBlow = { burst = 1 },
	Uppercut = { burst = 1, arc = { -80, 100, 2.8, 3, 0 } }, DragonTornado = { vortex = true }, DragonFist = { burst = 1.2 },
	CrescentMoon = { arc = { 90, -270, 3, 2.6, 0 }, burst = 1 }, RisingWind = { vortex = true }, KiFlurry = { burst = 0.7 },
	ThunderHeel = { burst = 1.4, ground = true }, SpinKick = { arc = { 200, -40, 3.4, 3.2, 1.3 }, burst = 0.8 },
	Sweep = { arc = { -60, 120, 3.4, 1, 1.4 }, burst = 0.8 }, LowKick = { burst = 0.8 },
	AirKick = { arc = { 110, -60, 2.8, 2.6, 0.3 }, burst = 0.8 }, AirKick2 = { burst = 0.8 }, AirSmash = { burst = 1.8, ground = true },
	KiChase = { burst = 1 }, Rising = { burst = 1.2 }, Finale = { beam = 10 }, KaienRush = { beam = 9 }, Awakening = { beam = 10 },
	Kaiten = { vortex = true, burst = 2 },
}
local VOID = Color3.fromHex("140A20")

-- The stroke of a weapon kit's move (false for the other kits: they keep `slash`).
function EffectsController:weaponStrike(view, moveId, color, rig)
	local kit = MoveData.MoveKit[moveId]
	local role = ROLE_OF[moveId] or moveId
	local f, z = view.facing, self.config.PlaneZ
	if kit == "SHIN" then
		local s = SWORD[role]
		if not s then return false end
		if s.arc then
			local a = s.arc
			local center = Vector3.new(view.x + f * 0.6, view.y + a[4], z)
			self:arc(center, a[3], a[1], a[2], color, a[5], f)
			self:arc(center, a[3] * 0.86, a[1], a[2], WHITE, a[5], f) -- the edge's gleam
		end
		if s.line and s.line < 0 then
			self:cut(Vector3.new(view.x + f * 1.4, view.y + 4, z), Vector3.new(view.x + f * 1.8, math.max(0, view.y - 1), z), color)
		elseif s.line then
			self:cut(Vector3.new(view.x + f * 0.4, view.y + s.line, z), Vector3.new(view.x + f * 5.6, view.y + s.line, z), color)
		end
		if s.ground then
			local x = view.x + f * 3
			self:crack(Vector3.new(x - f, 0.05, z), Vector3.new(x + f * 2.5, 0.05, z + 0.6), color)
			self:spark(Vector3.new(x, 0.6, z + 0.4), color, 1.6)
			self:dust(x, 0, f)
			self.camera:shake(if self.reduced then 0.15 else 0.35, 0.18)
		end
		return true
	elseif kit == "DAICHA" then
		local s = ORB[role]
		if not s then return false end
		-- Where the flying orb strikes (OrbFlight): the end of the move's reach.
		local hit = OrbFlight.strike(MoveData.Moves[moveId], role)
		local at = Vector3.new(view.x + f * hit.fwd, view.y + hit.up, z + hit.side)
		if s.arc then
			local a = s.arc
			self:arc(Vector3.new(view.x + f * 0.4, view.y + a[4], z), a[3], a[1], a[2], color, a[5], f)
		end
		if s.burst then self:orbBurst(at, color, s.burst) end
		if s.beam then self:orbBeam(at, f, s.beam, color) end
		if s.vortex then self:orbVortex(Vector3.new(view.x, view.y + 3, z), color) end
		if s.ground then
			local x = view.x + f * 2.6
			self:orbBurst(Vector3.new(x, 0.6, z), color, 1.4)
			self:dust(x, 0, f)
			self:dust(x, 0, -f)
			self.camera:shake(if self.reduced then 0.15 else 0.35, 0.18)
		end
		return true
	end
	return false
end

-- A burst of the shadow orb: a dark core swelling in a glow and a ring of its colour.
function EffectsController:orbBurst(position, color, scale)
	local core = self:part(Vector3.one * 0.6 * scale, CFrame.new(position), VOID, Enum.PartType.Ball)
	core.Material = Enum.Material.SmoothPlastic
	tween(core, 0.25, { Size = Vector3.one * 2.2 * scale, Transparency = 1 })
	Debris:AddItem(core, 0.3)
	local glow = self:part(Vector3.one * 0.9 * scale, CFrame.new(position), color, Enum.PartType.Ball)
	glow.Transparency = 0.25
	tween(glow, 0.3, { Size = Vector3.one * 3.2 * scale, Transparency = 1 })
	Debris:AddItem(glow, 0.35)
	local ring = self:part(Vector3.new(0.08, 1, 1) * scale, CFrame.new(position) * CFrame.Angles(0, math.pi / 2, 0), color, Enum.PartType.Cylinder)
	ring.Material = Enum.Material.ForceField
	tween(ring, 0.3, { Size = Vector3.new(0.08, 5, 5) * scale, Transparency = 1 })
	Debris:AddItem(ring, 0.35)
	self:spark(position, color, 0.8 * scale)
end

-- DAICHA's heavy: the orb's shadow fired straight ahead as a beam, bursting at its end.
function EffectsController:orbBeam(from, facing, length, color)
	local to = from + Vector3.new(facing * length, 0, 0)
	local mid = (from + to) / 2
	local beam = self:part(Vector3.new(length, 0.5, 0.5), CFrame.new(mid), color, Enum.PartType.Cylinder)
	beam.Transparency = 0.1
	tween(beam, 0.35, { Size = Vector3.new(length, 1.6, 1.6), Transparency = 1 })
	Debris:AddItem(beam, 0.4)
	local core = self:part(Vector3.new(length, 0.2, 0.2), CFrame.new(mid), WHITE, Enum.PartType.Cylinder)
	tween(core, 0.25, { Transparency = 1 })
	Debris:AddItem(core, 0.3)
	self:orbBurst(to, color, 1.6)
end

-- A vortex: small orbs whirling outward round the body, a ring climbing.
function EffectsController:orbVortex(center, color)
	local balls = {}
	for i = 1, if self.reduced then 3 else 6 do
		balls[i] = self:part(Vector3.one * 0.6, CFrame.new(center), if i % 2 == 0 then VOID else color, Enum.PartType.Ball)
	end
	local start = os.clock()
	task.spawn(function()
		while os.clock() - start < 0.7 do
			local t = os.clock() - start
			for i, ball in balls do
				local angle = t * 14 + i / #balls * math.pi * 2
				local r = 1.6 + t * 2.4
				ball.CFrame = CFrame.new(center + Vector3.new(math.cos(angle) * r, math.sin(t * 6 + i) * 0.6, math.sin(angle) * r))
				ball.Transparency = t / 0.7
			end
			task.wait()
		end
		for _, ball in balls do ball:Destroy() end
	end)
	self:tornadoRing(center, color)
end

-- The held weapons, alive (WeaponFX; Wilhem: « le minimum de détails de l'orbe de DAICHA doit
-- être le minimum »): a light of the player's ki colour that breathes at rest, burns when the
-- blow gathers and flashes on the impact; the edge glowing with it; a glint running down the
-- blade; the element's particles off it (water, sparks, snow, embers); for RAIJIN lightning
-- crawling along the shaft; a ribbon behind it when it swings fast, and fading ghosts of it in
-- a quick blow. A light, an emitter and a glint per blade: cheap. Built once per rig.
local function longAxis(size)
	if size.Z >= size.X and size.Z >= size.Y then return Vector3.zAxis, size.Z end
	if size.Y >= size.X then return Vector3.yAxis, size.Y end
	return Vector3.xAxis, size.X
end
-- YUKINA's ICE MIRROR (S + E): a hexagon of ice standing before her while it reflects
-- (WeaponFX.mirror: it grows, holds and shimmers, then shatters into shards). Three glass
-- slabs make the hexagon, a rim of frost runs round it, a snowflake glows in its heart and
-- a crystal juts from every corner. Cosmetic: the reflection itself is the server's.
function EffectsController:iceMirror(slot, rig, view, now, color)
	self.mirrors = self.mirrors or {}
	local m = view.state == "Attack" and view.move and MoveData.Moves[view.move]
	local look = m and WeaponFX.mirror(m, view.moveFrame, now)
	local mirror = self.mirrors[slot]
	if mirror and (not mirror.model.Parent or mirror.rig ~= rig) then
		mirror.model:Destroy()
		mirror, self.mirrors[slot] = nil, nil
	end
	if not look then
		if mirror then mirror.model:Destroy(); self.mirrors[slot] = nil end
		return
	end
	local R = 1.7
	if not mirror then
		local model = Instance.new("Model")
		model.Name = "IceMirror" .. slot
		local parts = {}
		local function add(p, base, kind)
			p.Parent = model
			table.insert(parts, { part = p, base = base, kind = kind, size = p.Size })
		end
		local ice, frost = Color3.fromHex("DFF6FF"), Color3.fromHex("FFFFFF")
		for i = 0, 2 do
			local slab = self:part(Vector3.new(0.06, R * math.sqrt(3), R), CFrame.Angles(math.rad(60 * i), 0, 0), ice)
			slab.Material, slab.Reflectance = Enum.Material.Glass, 0.3
			add(slab, 0.45, "glass")
		end
		for i = 0, 5 do
			local a0, a1 = math.rad(60 * i), math.rad(60 * (i + 1))
			local v0 = Vector3.new(0, math.sin(a0) * R, math.cos(a0) * R)
			local v1 = Vector3.new(0, math.sin(a1) * R, math.cos(a1) * R)
			local rim = self:part(Vector3.new(0.12, 0.12, R + 0.06), CFrame.lookAt((v0 + v1) / 2, v1), frost)
			rim.Material = Enum.Material.Neon
			add(rim, 0, "rim")
			local spike = self:part(Vector3.new(0.14, 0.14, 0.55), CFrame.lookAt(v0 * 1.12, v0 * 1.4), ice)
			spike.Material = Enum.Material.Ice
			add(spike, 0.1, "spike")
			if i < 3 then
				local ray = self:part(Vector3.new(0.08, 0.06, R * 1.3), CFrame.lookAt(Vector3.zero, v0), color)
				ray.Material = Enum.Material.Neon
				add(ray, 0.2, "flake")
			end
		end
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = Color3.fromHex("BFEFFF"), 10, 1.5
		light.Parent = parts[1].part
		model.WorldPivot = CFrame.identity
		model.Parent = self.folder
		-- (never left standing if the fight stops mid-mirror: the move lasts well under 1 s)
		Debris:AddItem(model, 2)
		mirror = { model = model, parts = parts, scale = 1, rig = rig }
		self.mirrors[slot] = mirror
	end
	-- before her, at her chest, facing the opponent (turned a little toward the camera)
	local f = view.facing or 1
	local at = Vector3.new(view.x + f * 1.5, view.y + 3, self.config.PlaneZ + 0.25)
	local turn = (if f > 0 then 0 else math.pi) - f * math.rad(20)
	mirror.model:PivotTo(CFrame.new(at) * CFrame.Angles(0, turn, 0) * CFrame.Angles(look.shimmer * 0.04, 0, 0))
	if math.abs(look.grow - mirror.scale) > 0.02 then
		mirror.model:ScaleTo(math.max(0.05, look.grow))
		mirror.scale = look.grow
	end
	for _, entry in mirror.parts do
		local flicker = if entry.kind == "rim" then 0.15 * (0.5 + 0.5 * look.shimmer) else 0
		entry.part.Transparency = 1 - (1 - entry.base) * look.shown + flicker * look.shown
	end
	if look.shatter and not mirror.shattered then
		mirror.shattered = true
		self:shards(at, Color3.fromHex("DFF6FF"), if self.reduced then 6 else 14, 0.9, Enum.Material.Ice, 0.45)
		self:spark(at, Color3.fromHex("BFEFFF"), 1)
	end
end

-- The sparks a blow strikes off a held weapon in guard, by its element: { flash, sparks,
-- embers, material of the sparks }.
BLOCK_SPARKS = {
	water = { Color3.fromHex("FFB23F"), Color3.fromHex("FFE08A"), Color3.fromHex("FF5A2A") }, -- SHIN: steel, orange
	ember = { Color3.fromHex("FF8A2A"), Color3.fromHex("FFD27A"), Color3.fromHex("FF3A1A") }, -- KAZAN: steel, red-hot
	lightning = { Color3.fromHex("FFF6B0"), Color3.fromHex("FFFFFF"), Color3.fromHex("8FD8FF") }, -- RAIJIN: crackling
	frost = { Color3.fromHex("E8FBFF"), Color3.fromHex("DFF6FF"), Color3.fromHex("9FE6FF"), Enum.Material.Ice }, -- YUKINA: ice chips
}

-- VENOM's CONTAMINATION on its victim (KitFX.poisonLook): while the body carries poison
-- (view.poisoned: its charges), a green glaze pulses over it, toxic bubbles rise off it and
-- green drops fall from it, more with every charge; each tick of poison flares the glaze.
local POISON_GREEN, POISON_DARK = Color3.fromHex("7CFF4A"), Color3.fromHex("2E7D12")
function EffectsController:poisonAura(slot, rig, view, now)
	self.poisons = self.poisons or {}
	local fx = self.poisons[slot]
	local charges = view.poisoned
	if type(charges) ~= "number" or charges <= 0 or not rig.model or not rig.model.Parent then
		if fx then
			fx.glaze:Destroy()
			fx.bubbles:Destroy()
			self.poisons[slot] = nil
		end
		return
	end
	local torso = rig.model:FindFirstChild("UpperTorso") or rig.model:FindFirstChild("Torso")
	if not torso then return end
	if not fx or fx.rig ~= rig or not fx.glaze.Parent then
		if fx then fx.glaze:Destroy(); fx.bubbles:Destroy() end
		local glaze = Instance.new("Highlight")
		glaze.FillColor, glaze.OutlineColor = POISON_GREEN, POISON_DARK
		glaze.DepthMode = Enum.HighlightDepthMode.Occluded
		glaze.FillTransparency, glaze.OutlineTransparency = 1, 1
		glaze.Adornee, glaze.Parent = rig.model, self.folder
		local bubbles = Instance.new("ParticleEmitter")
		bubbles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		bubbles.Color = ColorSequence.new(POISON_GREEN, POISON_DARK)
		bubbles.LightEmission, bubbles.LightInfluence = 0.6, 0.4
		bubbles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.7, 0.35),
			NumberSequenceKeypoint.new(1, 0) })
		bubbles.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		bubbles.Lifetime, bubbles.Speed = NumberRange.new(0.5, 0.9), NumberRange.new(1, 2.4)
		bubbles.Acceleration, bubbles.SpreadAngle = Vector3.new(0, 2.5, 0), Vector2.new(35, 35)
		bubbles.EmissionDirection = Enum.NormalId.Top
		bubbles.Parent = torso
		fx = { rig = rig, glaze = glaze, bubbles = bubbles, drip = 0 }
		self.poisons[slot] = fx
	end
	local look = KitFX.poisonLook(charges, now, fx.tickAt and now - fx.tickAt)
	fx.glaze.FillTransparency = 1 - look.tint
	fx.glaze.OutlineTransparency = 1 - math.min(1, look.tint * 1.6)
	fx.bubbles.Rate = look.bubbles * (if self.reduced then 0.5 else 1)
	-- green drops falling off the body
	if now - fx.drip > 1 / look.drips then
		fx.drip = now
		self:drops(torso.Position + Vector3.new((math.random() - 0.5) * 1.2, -0.6, 0.3), POISON_GREEN, 1, 0.7, 2)
	end
end

function EffectsController:weaponDressing(rig, view, now, slot)
	local kit = view.kit or rig.model:GetAttribute("Kit")
	local cfg = kit and WeaponFX.KITS[kit]
	if not cfg then return end
	local fx = rig.weaponFx
	if fx and (not fx.blades[1] or not fx.blades[1].part.Parent) then
		for _, b in fx.blades do if b.glint then b.glint:Destroy() end end
		fx = nil
	end
	if not fx then
		local color = self:energy(slot or 1)
		local accent = Color3.fromHex(cfg.accent)
		local element = WeaponFX.ELEMENTS[cfg.element]
		fx = { blades = {}, edges = {}, shafts = {}, kit = kit, clock = 0, ghostClock = 0, arcClock = 0, color = color, accent = accent }
		for _, child in rig.model:GetChildren() do
			if child:IsA("BasePart") then
				if child.Name == "Kit" .. cfg.blade then
					local axis, length = longAxis(child.Size)
					local b = { part = child, axis = axis, length = length }
					-- its light
					b.light = Instance.new("PointLight")
					b.light.Name, b.light.Color, b.light.Shadows, b.light.Range = "WeaponLight", color, false, 7
					b.light.Parent = child
					-- its element, off the blade
					local e = Instance.new("ParticleEmitter")
					e.Name = "WeaponElement"
					e.Color = ColorSequence.new(accent, color)
					e.LightEmission, e.LightInfluence = element.emission, 0
					e.Lifetime = NumberRange.new(element.life[1], element.life[2])
					e.Speed = NumberRange.new(element.speed[1], element.speed[2])
					e.Acceleration = Vector3.new(0, element.drift, 0)
					e.SpreadAngle = Vector2.new(180, 180)
					e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, element.size[1]), NumberSequenceKeypoint.new(1, element.size[2]) })
					e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
					e.Rate = 0
					e.Parent = child
					b.emitter, b.rate = e, element.rate
					-- its glint: a white streak that runs down the blade
					b.glint = self:part(Vector3.new(0.12, 0.12, 0.12), CFrame.identity, WHITE)
					b.glint.Name, b.glint.Transparency, b.glint.Parent = "WeaponGlint", 1, rig.model
					-- its ribbon (SHIN's blade has one already: attachWeapon)
					if kit ~= "SHIN" then
						local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
						a0.Position, a1.Position = axis * (length * 0.45), -axis * (length * 0.5)
						a0.Parent, a1.Parent = child, child
						local trail = Instance.new("Trail")
						trail.Name, trail.Attachment0, trail.Attachment1 = "WeaponRibbon", a0, a1
						trail.Color = ColorSequence.new(WHITE, color)
						trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.6, 0.5),
							NumberSequenceKeypoint.new(1, 1) })
						trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.15) })
						trail.Lifetime, trail.MinLength, trail.LightEmission, trail.Enabled = 0.18, 0.02, 1, false
						trail.Parent = child
						b.trail = trail
					end
					b.last = child.Position
					table.insert(fx.blades, b)
				elseif child.Name == "Kit" .. cfg.edge then
					table.insert(fx.edges, { part = child, color = child.Color, transparency = child.Transparency })
				elseif cfg.shaft and child.Name == "Kit" .. cfg.shaft then
					table.insert(fx.shafts, child)
				end
			end
		end
		if #fx.blades == 0 then return end
		rig.weaponFx = fx
	end
	local dt = math.clamp(now - (fx.clock ~= 0 and fx.clock or now), 0, 0.1)
	fx.clock = now
	local id = view.state == "Attack" and view.move or nil
	local want = WeaponFX.look({ state = view.state, moveFrame = view.moveClock or view.moveFrame }, id and MoveData.Moves[id], now)
	local look = fx.look or want
	for k, v in want do look[k] = look[k] + (v - look[k]) * (1 - math.exp(-dt * (if v > look[k] then 30 else 10))) end
	fx.look = look
	local reduced = self.reduced
	for i, b in fx.blades do
		local part = b.part
		local pos = part.Position
		local speed = if dt > 0 then (pos - b.last).Magnitude / dt else 0
		b.last = pos
		b.light.Brightness, b.light.Range = look.light, 6 + look.light * 1.5
		b.emitter.Rate = look.sparks * b.rate * (if reduced then 0.35 else 1)
		-- the glint (a little offset per blade so a pair does not flash together)
		local u = WeaponFX.glint(now, i * 0.9)
		if u and not reduced then
			local along = b.axis * ((0.5 - u) * b.length * 0.9)
			b.glint.CFrame = part.CFrame * CFrame.new(along)
			b.glint.Size = Vector3.new(0.14, 0.14, 0.14) + b.axis * 0.35
			b.glint.Transparency = 0.1 + 0.6 * math.abs(u - 0.5)
		elseif b.glint.Transparency < 1 then
			b.glint.Transparency = 1
		end
		-- the ribbon when it swings fast
		if b.trail then
			local on = speed > 16
			if b.trail.Enabled ~= on then b.trail.Enabled = on end
		end
		-- ghosts of it in a quick blow
		if id and speed > 28 and not reduced and now - fx.ghostClock > 0.035 then
			fx.ghostClock = now
			local ghost = self:part(part.Size, part.CFrame, fx.color)
			ghost.Transparency = 0.55
			tween(ghost, 0.15, { Transparency = 1 })
			Debris:AddItem(ghost, 0.17)
		end
	end
	-- the edge glows with the breath, white-hot on the impact
	for _, e in fx.edges do
		e.part.Transparency = math.clamp(0.55 - 0.55 * look.glow, 0, 1)
		e.part.Color = e.color:Lerp(WHITE, look.flare * 0.7)
	end
	-- RAIJIN: lightning crawling along the shaft, more as the blow gathers
	if #fx.shafts > 0 and not reduced and now - fx.arcClock > 0.09 and math.random() < look.sparks * 0.55 then
		fx.arcClock = now
		local shaft = fx.shafts[1]
		local axis, length = longAxis(shaft.Size)
		local a = shaft.CFrame * CFrame.new(axis * ((math.random() - 0.5) * length * 0.9))
		local b = shaft.CFrame * CFrame.new(axis * ((math.random() - 0.5) * length * 0.9))
		self:crawl(a.Position, b.Position, fx.color)
	end
end

-- A small arc of lightning between two close points (RAIJIN's shaft): thin, quick.
function EffectsController:crawl(from, to, color)
	local points = { from }
	for i = 1, 3 do
		local jitter = Vector3.new((math.random() - 0.5) * 0.35, (math.random() - 0.5) * 0.35, (math.random() - 0.5) * 0.35)
		table.insert(points, from:Lerp(to, i / 4) + jitter)
	end
	table.insert(points, to)
	for i = 1, #points - 1 do
		local p0, p1 = points[i], points[i + 1]
		local bolt = self:part(Vector3.new(0.06, 0.06, (p1 - p0).Magnitude), CFrame.lookAt((p0 + p1) / 2, p1), if i % 2 == 0 then WHITE else color)
		tween(bolt, 0.1, { Transparency = 1 })
		Debris:AddItem(bolt, 0.12)
	end
end

-- DAICHA's body as boxes for OrbFlight.avoid (centre, unit axes, half sizes), read off her rig
-- as drawn this frame. The tables are kept and refilled: no garbage every frame.
local BODY_PARTS = { "Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm",
	"RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" }
function EffectsController:orbBodyBoxes(rig)
	local parts = rig.orbBody
	if not parts or (parts[1] and not parts[1].Parent) then
		parts = {}
		for _, name in BODY_PARTS do
			local p = rig.model:FindFirstChild(name)
			if p and p:IsA("BasePart") then table.insert(parts, p) end
		end
		rig.orbBody, rig.orbBoxes = parts, {}
	end
	local boxes = rig.orbBoxes
	for i, p in parts do
		local cf, size = p.CFrame, p.Size
		local b = boxes[i] or {}
		local px, py, pz = cf.Position.X, cf.Position.Y, cf.Position.Z
		local rx, uy, lz = cf.XVector, cf.YVector, cf.ZVector
		b[1], b[2], b[3] = px, py, pz
		b[4], b[5], b[6] = rx.X, rx.Y, rx.Z
		b[7], b[8], b[9] = uy.X, uy.Y, uy.Z
		b[10], b[11], b[12] = lz.X, lz.Y, lz.Z
		b[13], b[14], b[15] = size.X / 2, size.Y / 2, size.Z / 2
		boxes[i] = b
	end
	return boxes
end

-- The orb's dressing (flyOrb): the glint, the three motes of ki circling it, its light, the
-- wisps of shadow drifting off it, the ghosts it leaves when it strikes fast, built once and
-- moved every frame. A handful of parts and two emitters: cheap.
local SAT_PLANES = { CFrame.Angles(math.rad(70), 0, 0), CFrame.Angles(math.rad(20), math.rad(60), 0), CFrame.Angles(math.rad(-45), math.rad(-50), 0) }
function EffectsController:orbDressing(rig, look, r, hidden, gone, speed, dt, now, color, view, frameCF)
	local shell = rig.orbParts[1]
	if not shell or not shell.Parent then return end
	local fx = rig.orbFx
	if not fx or not fx.glint.Parent then
		fx = {}
		fx.glint = self:part(Vector3.one * 0.1, CFrame.identity, WHITE, Enum.PartType.Ball)
		fx.glint.Name, fx.glint.Parent = "OrbGlint", rig.model
		fx.sats = {}
		for i = 1, 3 do
			local sat = self:part(Vector3.one * 0.1, CFrame.identity, color, Enum.PartType.Ball)
			sat.Name, sat.Parent = "OrbMote" .. i, rig.model
			fx.sats[i] = sat
		end
		fx.light = Instance.new("PointLight")
		fx.light.Name, fx.light.Shadows, fx.light.Parent = "OrbLight", false, shell
		fx.wisps = Instance.new("ParticleEmitter")
		fx.wisps.Name = "OrbWisps"
		fx.wisps.Texture = "rbxasset://textures/particles/smoke_main.dds"
		fx.wisps.Color = ColorSequence.new(Color3.fromHex("000000"), Color3.fromHex("2A1240"))
		fx.wisps.LightEmission, fx.wisps.LightInfluence = 0, 0
		fx.wisps.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
		fx.wisps.Lifetime, fx.wisps.Speed = NumberRange.new(0.4, 0.8), NumberRange.new(0.4, 1.3)
		fx.wisps.SpreadAngle, fx.wisps.Acceleration = Vector2.new(180, 180), Vector3.new(0, 1.8, 0)
		fx.wisps.RotSpeed, fx.wisps.Rotation = NumberRange.new(-60, 60), NumberRange.new(0, 360)
		fx.wisps.Parent = shell
		fx.phase, fx.ghostClock = 0, 0
		rig.orbFx = fx
	end
	local pos = frameCF.Position
	-- the light, in her ki colour (it flares on the impact)
	fx.light.Color, fx.light.Brightness = color, if gone then 0 else look.light
	fx.light.Range = 5 + look.light * 1.2
	-- the wisps of shadow, drifting off it (fewer with reduced effects)
	local rate = if gone then 0 else look.wisps * (if self.reduced then 5 else 14)
	fx.wisps.Rate = rate
	local puff = math.max(r, rig.orbRadius * 0.6)
	if math.abs(puff - (fx.puff or -1)) > 0.03 then -- (rebuilt only when it changes: no garbage every frame)
		fx.puff = puff
		fx.wisps.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, math.max(0.1, puff * 1.4)), NumberSequenceKeypoint.new(1, math.max(0.2, puff * 2.6)) })
	end
	-- the glint: a small white highlight on the side toward the camera, high
	local camera = workspace.CurrentCamera
	if camera and not hidden and r > 0.08 then
		local toCamera = (camera.CFrame.Position - pos).Unit
		local at = pos + (toCamera * 0.72 + Vector3.yAxis * 0.42 - camera.CFrame.RightVector * 0.3) * r
		fx.glint.CFrame, fx.glint.Size, fx.glint.Transparency = CFrame.new(at), Vector3.one * math.max(0.03, r * 0.32), 0.2
	else
		fx.glint.Transparency = 1
	end
	-- the three motes of ki, each on its own tilted orbit
	fx.phase += look.spin * dt
	local orbit = r * look.sats
	local moteSize = math.clamp(r * 0.28, 0.05, 0.16)
	for i, sat in fx.sats do
		if hidden or look.sats < 0.2 then
			sat.Transparency = 1
		else
			local a = fx.phase + (i - 1) * math.pi * 2 / 3
			local plane = SAT_PLANES[i]
			local offset = (plane.RightVector * math.cos(a) + plane.LookVector * math.sin(a)) * orbit
			sat.CFrame, sat.Size, sat.Color = CFrame.new(pos + offset), Vector3.one * moteSize, color:Lerp(WHITE, 0.45) -- (lighter than the corona: they read against it)
			sat.Transparency = 0.1
		end
	end
	-- ghosts: when it strikes fast, it leaves fading black copies of itself
	if not hidden and not self.reduced and view.state == "Attack" and speed > 22 and now - fx.ghostClock > 0.035 then
		fx.ghostClock = now
		local ghost = self:part(Vector3.one * r * 2, CFrame.new(pos), Color3.fromHex("07040C"), Enum.PartType.Ball)
		ghost.Material, ghost.Transparency = Enum.Material.SmoothPlastic, 0.5
		local rim = self:part(Vector3.one * r * 2.5, CFrame.new(pos), color, Enum.PartType.Ball)
		rim.Transparency = 0.8
		tween(ghost, 0.16, { Transparency = 1, Size = Vector3.one * r * 1.2 })
		tween(rim, 0.16, { Transparency = 1, Size = Vector3.one * r * 1.4 })
		Debris:AddItem(ghost, 0.18)
		Debris:AddItem(rim, 0.18)
	end
end

-- DAICHA's matter, free of her hand: where OrbFlight puts it, followed by a spring (it lags a
-- little behind her steps and jumps, overshoots a touch and settles; tight in a strike; re-formed
-- from nothing after a teleport), in the shape OrbFlight gives (Wilhem: attack = a dense sphere
-- swelling on impact, guard = the same matter spread into a black disc before her, a puddle at
-- the K.O.), morphing smoothly from one to the other, drawn longer along its flight when it
-- goes fast. FLUIDITY: the move's frame is read between two ticks (moveClock, never back), each
-- path is one smooth curve starting from where the matter was, the spring's stiffness, the
-- size, the stretch and its direction are all eased: nothing changes at once
-- (measured: tests/OrbQuality.luau).
function EffectsController:flyOrb(rig, view, now, slot)
	local id = view.state == "Attack" and view.move or nil
	local move = id and MoveData.Moves[id]
	local role = id and ROLE_OF[id]
	rig.orbMoveClock = rig.orbMoveClock or {}
	local frame = OrbFlight.clock(rig.orbMoveClock, id, view.moveClock or view.moveFrame or 0, rig.orbLast)
	local shown = { state = view.state, moveFrame = frame }
	-- (the spring's target a little ahead on the path: followed, the matter is on time, in step
	-- with her fist, not trailing behind it into it)
	local ahead = { state = view.state, moveFrame = OrbFlight.leadFrame(shown, move) }
	local o = OrbFlight.offset(ahead, move, role, now, rig.orbMoveClock.from)
	rig.orbLast = o
	-- (from where the body is drawn: the presentation spacing may set it a little apart)
	local x = if rig.root then rig.root.Position.X else view.x
	local z0 = self.config.PlaneZ
	local target = { x + view.facing * o.fwd, view.y + o.up, z0 + o.side }
	local dt = math.clamp(now - (rig.orbClock or now), 0, 0.1)
	rig.orbClock = now
	local spring = rig.orbSpring
	if not spring then
		spring = {}
		rig.orbSpring = spring
	end
	-- (the spring tightens as a strike starts and loosens after it, never at once)
	rig.orbTight = (rig.orbTight or 0) + ((if id then 1 else 0) - (rig.orbTight or 0)) * (1 - math.exp(-dt * 14))
	-- Kept off her own body (Wilhem: « évite quand ça rentre dans ses bras, quand c'est trop
	-- collé au perso »): her parts as they are drawn this frame (OrbFlight.place, measured by
	-- tests/OrbClearance.luau and tests/OrbQuality.luau).
	local form = OrbFlight.form(shown, move, role, now)
	local boxes = self:orbBodyBoxes(rig)
	local at = OrbFlight.place(spring, target, dt, rig.orbTight, { x, view.y }, boxes, math.max(form.radius, 0.05),
		OrbFlight.avoidDirection(view.state, view.facing, o))
	rig.orbPosition = Vector3.new(at[1], at[2], at[3])
	local vel = spring.velocity or { 0, 0, 0 }
	local velocity = Vector3.new(vel[1], vel[2], vel[3])
	-- the shape: ball <-> disc (morph 0..1); the ball's radius on a soft spring (it pops a
	-- little past its size on an impact, then settles)
	local S = OrbFlight.SIZE
	local disc = form.shape ~= "ball"
	local flat = form.shape == "puddle"
	rig.orbMorph = (rig.orbMorph or 0) + ((if disc then 1 else 0) - (rig.orbMorph or 0)) * (1 - math.exp(-dt * 16))
	local wanted = if disc then S.rest else form.radius
	rig.orbRadius = rig.orbRadius or wanted
	rig.orbGrow = rig.orbGrow or 0
	if spring.snapped or form.radius < 0.05 then
		rig.orbRadius, rig.orbGrow = 0, 0 -- (thrown: it IS the projectile now; teleported: it re-forms)
	else
		local w, z = 30, 0.6
		local steps = math.max(1, math.ceil(dt / (1 / 240)))
		for _ = 1, steps do
			local h = dt / steps
			rig.orbGrow += (w * w * (wanted - rig.orbRadius) - 2 * z * w * rig.orbGrow) * h
			rig.orbRadius = math.max(0, rig.orbRadius + rig.orbGrow * h)
		end
	end
	local m = rig.orbMorph
	local r = rig.orbRadius * (1 - m)
	-- stretched along its flight (and the arrow's own stretch), its volume kept; the stretch
	-- and its direction eased, so it never flickers
	local speed = velocity.Magnitude
	local stretchWanted = math.clamp((form.stretch or 1) * (1 + math.min(speed / 50, 0.9)), 1, 3.2)
	rig.orbStretch = (rig.orbStretch or 1) + (stretchWanted - (rig.orbStretch or 1)) * (1 - math.exp(-dt * 20))
	local stretch = rig.orbStretch
	local along = rig.orbAlong or Vector3.new(view.facing, 0, 0)
	if speed > 1.5 then along = along:Lerp(velocity.Unit, 1 - math.exp(-dt * 25)) end
	if along.Magnitude < 0.05 then along = Vector3.new(view.facing, 0, 0) end
	rig.orbAlong = along.Unit
	local frameCF = CFrame.lookAt(rig.orbPosition, rig.orbPosition + rig.orbAlong)
	local thin = 1 / math.sqrt(stretch)
	-- HOW IT LOOKS (OrbFlight.look, eased): a black sphere with a corona of her ki colour
	-- (KitOrbCore, once hidden inside it), a glint, three motes circling, a light, wisps.
	local hidden = m > 0.97 or self.hideOrb or r < 0.03
	local wantLook = OrbFlight.look(shown, move, role, now, form)
	local look = rig.orbLook or wantLook
	for k, v in wantLook do look[k] = look[k] + (v - look[k]) * (1 - math.exp(-dt * 22)) end
	rig.orbLook = look
	local color = self:energy(slot or 1)
	for _, p in rig.orbParts do
		if p.Parent then
			local mesh = p:FindFirstChild("OrbShape")
			if not mesh then
				mesh = Instance.new("SpecialMesh")
				mesh.Name, mesh.MeshType, mesh.Parent = "OrbShape", Enum.MeshType.Sphere, p
				if p.Name == "KitOrbCore" then
					p.Material, p.CastShadow = Enum.Material.Neon, false
				else
					-- (a glossy black: the light slides over it)
					p.Material, p.Color, p.Reflectance = Enum.Material.SmoothPlastic, Color3.fromHex("07040C"), 0.22
				end
			end
			mesh.Scale = Vector3.new(thin, thin, stretch)
			p.CFrame = frameCF
			if p.Name == "KitOrbCore" then
				p.Size = Vector3.one * math.max(0.03, r * 2 * math.max(look.halo, 0.01))
				p.Transparency = if hidden or look.halo < 0.05 then 1 else math.clamp(look.haloT, 0, 1)
			else
				p.Size = Vector3.one * math.max(0.03, r * 2)
				p.Transparency = if hidden then 1 else 0
			end
		end
	end
	-- (the light and the wisps stay with the disc and the puddle; gone with the thrown orb, or
	-- while an ultimate stages the matter itself)
	local gone = self.hideOrb or (rig.orbRadius < 0.03 and m < 0.5)
	self:orbDressing(rig, look, r, hidden, gone, speed, dt, now, color, view, frameCF)
	-- its ribbon: drawn whenever it flies fast (not only during a blow), as wide as the orb
	local trail = rig.trails and rig.trails.Weapon
	if trail then
		local on = speed > 14 and r > 0.08 and not self.hideOrb and m < 0.5
		if trail.Enabled ~= on then trail.Enabled = on end
		local a0, a1 = trail.Attachment0, trail.Attachment1
		if a0 and a1 then
			local half = math.max(0.05, r * 0.8)
			a0.Position, a1.Position = Vector3.new(0, half, 0), Vector3.new(0, -half, 0)
		end
	end
	if self.hideOrb then m = 0 end -- (an ultimate stages the matter itself)
	if not rig.orbDisc or not rig.orbDisc.Parent then
		local core = self:part(Vector3.new(0.16, 0.1, 0.1), CFrame.identity, VOID, Enum.PartType.Cylinder)
		core.Material, core.Name = Enum.Material.SmoothPlastic, "MatterDisc"
		local rim = self:part(Vector3.new(0.08, 0.1, 0.1), CFrame.identity, self:energy(slot or 1), Enum.PartType.Cylinder)
		rim.Material, rim.Transparency, rim.Name = Enum.Material.Neon, 0.35, "MatterRim"
		core.Parent, rim.Parent = rig.model, rig.model
		rig.orbDisc, rig.orbRim = core, rim
	end
	-- (a shield turned toward the camera: edge-on, from the side view, a disc would be a line;
	-- a puddle lies flat on the floor; the turn between the two eased)
	local f = view.facing
	rig.orbLie = (rig.orbLie or 0) + ((if flat then 1 else 0) - (rig.orbLie or 0)) * (1 - math.exp(-dt * 10))
	local face = CFrame.new(rig.orbPosition) * CFrame.Angles(0, (if f > 0 then 0 else math.pi) - f * math.rad(42) * (1 - rig.orbLie), rig.orbLie * math.pi / 2)
	-- the disc's size eased too (a blow on the shield: it gives, and ripples)
	local size = if disc then form.radius else S.disc
	rig.orbDiscSize = (rig.orbDiscSize or size) + (size - (rig.orbDiscSize or size)) * (1 - math.exp(-dt * 18))
	size = rig.orbDiscSize
	if form.shape == "disc" and form.radius > S.disc then size *= 1 + 0.04 * math.sin(now * 50) end
	local d = size * 2 * m
	local thick = if disc then form.thickness else S.thickness
	local hide = m < 0.03
	rig.orbDisc.Size = Vector3.new(thick, math.max(0.05, d), math.max(0.05, d))
	rig.orbDisc.CFrame, rig.orbDisc.Transparency = face, if hide then 1 else 0.02
	rig.orbRim.Size = Vector3.new(thick * 0.5, math.max(0.05, d * 1.08), math.max(0.05, d * 1.08))
	rig.orbRim.CFrame = face * CFrame.new(-0.05 + 0.03 * rig.orbLie, 0, 0)
	-- (the rim breathes gently)
	rig.orbRim.Transparency = if hide then 1 else 0.3 + 0.25 * rig.orbLie + 0.08 * math.sin(now * 3)
	-- a blow lands on the shield: a ring of her colour spreads off it
	local stunned = view.state == "Blockstun" or view.state == "CrouchBlockstun"
	if stunned and not rig.orbWasStunned and not hide then
		local ring = self:part(Vector3.new(0.05, d * 1.05, d * 1.05), face, self:energy(slot or 1), Enum.PartType.Cylinder)
		ring.Transparency = 0.35
		tween(ring, 0.28, { Transparency = 1, Size = Vector3.new(0.05, d * 1.7, d * 1.7) })
		Debris:AddItem(ring, 0.3)
	end
	rig.orbWasStunned = stunned
end

-- ===================================================================== every kit's own strikes
-- No two fighters' blows look alike: each speaks its own element (src/shared/KitFX.luau),
-- when a blow goes out (`kitSwing`, the first contact frame of the move, hit or not), when it
-- lands (`kitHit`, the Hit event), on the dash (`kitDash`) and in the motes always floating
-- round the body (`ambient`). The shapes and the element's accent tell the fighter; the
-- style's ki colour paints the rest (a shop style recolours its effects).
local FIRE, EMBER = Color3.fromHex("FF7A1A"), Color3.fromHex("FFD45A")
local STONE = Color3.fromHex("7A6D62")
local GOLD = Color3.fromHex("FFD23F")
local FACE = CFrame.Angles(0, math.pi / 2, 0) -- a cylinder facing the camera (a ring seen face on)
local FLAT = CFrame.Angles(0, 0, math.pi / 2) -- a cylinder lying on the floor

-- A ring growing from `from` to `to` studs wide in `life` s (face on, or `flat` on the floor).
function EffectsController:ring(position, color, from, to, life, flat, thickness, material)
	local ring = self:part(Vector3.new(thickness or 0.08, from, from), CFrame.new(position) * (if flat then FLAT else FACE), color,
		Enum.PartType.Cylinder)
	if material then ring.Material = material end
	ring.Transparency = 0.1
	tween(ring, life, { Size = Vector3.new(0.03, to, to), Transparency = 1 })
	Debris:AddItem(ring, life + 0.05)
	return ring
end

-- Small falling pieces (client physics only): drops of poison or blood, embers, leaves.
function EffectsController:drops(position, color, count, scale, spread, long)
	for i = 1, if self.reduced then math.ceil(count / 2) else count do
		local size = (0.12 + math.random() * 0.14) * scale
		local drop = self:part(Vector3.new(size, size * (long or 1), size), CFrame.new(position
			+ Vector3.new((math.random() - 0.5) * 0.6, (math.random() - 0.5) * 0.6, 0.3)), color, if long then nil else Enum.PartType.Ball)
		drop.Anchored = false
		drop.AssemblyLinearVelocity = Vector3.new((math.random() - 0.5) * (spread or 14), 6 + math.random() * 8, (math.random() - 0.5) * 5)
		if long then drop.AssemblyAngularVelocity = Vector3.new(math.random() * 8, math.random() * 8, math.random() * 8) end
		tween(drop, 0.7 + i * 0.03, { Transparency = 1 })
		Debris:AddItem(drop, 0.8 + i * 0.03)
	end
end

-- Thin long pieces thrown out of `position` like a star (ice shards, steel splinters, rays).
function EffectsController:shards(position, color, count, scale, material, life)
	local n = if self.reduced then math.ceil(count / 2) else count
	for i = 1, n do
		local angle = i / n * math.pi * 2 + math.random() * 0.5
		local dir = Vector3.new(math.cos(angle), math.sin(angle), 0)
		local length = (0.9 + math.random() * 0.8) * scale
		local look = CFrame.lookAt(position, position + dir, Vector3.zAxis)
		local shard = self:part(Vector3.new(0.14 * scale, 0.14 * scale, length), look * CFrame.new(0, 0, -length / 2 - 0.2), color)
		if material then
			shard.Material = material
			if material == Enum.Material.Ice then shard.Transparency, shard.Reflectance = 0.1, 0.25 end
		end
		tween(shard, life or 0.3, { CFrame = look * CFrame.new(0, 0, -length / 2 - 1.6 * scale), Size = Vector3.new(0.03, 0.03, length * 0.6),
			Transparency = 1 })
		Debris:AddItem(shard, (life or 0.3) + 0.05)
	end
end

-- Square pixels jumping out (NOVA's machines).
function EffectsController:pixels(position, color, accent, count, scale)
	for i = 1, if self.reduced then math.ceil(count / 2) else count do
		local size = (0.22 + math.random() * 0.2) * scale
		local cube = self:part(Vector3.one * size, CFrame.new(position), if i % 2 == 0 then accent else color)
		local away = Vector3.new((math.random() - 0.5) * 3, (math.random() - 0.5) * 2.4, 0.4) * scale
		-- (they jump in two hard steps, like a screen glitch, then vanish)
		task.delay(0.04, function() if cube.Parent then cube.Position = position + away * 0.5 end end)
		task.delay(0.09, function() if cube.Parent then cube.Position = position + away end end)
		tween(cube, 0.24, { Transparency = 1 }, Enum.EasingStyle.Linear)
		Debris:AddItem(cube, 0.26)
	end
end

-- A ki flash: a white core in a ring of the fighter's colour.
function EffectsController:kiPop(position, color, scale)
	local core = self:part(Vector3.one * 0.5 * scale, CFrame.new(position), WHITE, Enum.PartType.Ball)
	tween(core, 0.14, { Size = Vector3.one * 1.8 * scale, Transparency = 1 })
	Debris:AddItem(core, 0.18)
	self:ring(position, color, 1 * scale, 3.4 * scale, 0.2, false, 0.06 * scale)
end

-- TARO's glove: a ring of fire round the fist and embers thrown off it.
function EffectsController:fireRing(position, scale)
	local ring = self:ring(position, FIRE, 1 * scale, 3.2 * scale, 0.22, false, 0.18 * scale)
	ring.Transparency = 0.05
	local core = self:part(Vector3.one * 0.7 * scale, CFrame.new(position), EMBER, Enum.PartType.Ball)
	tween(core, 0.16, { Size = Vector3.one * 1.6 * scale, Transparency = 1 })
	Debris:AddItem(core, 0.2)
	for i = 1, if self.reduced then 3 else 7 do
		local ember = self:part(Vector3.one * 0.16, CFrame.new(position), if i % 2 == 0 then FIRE else EMBER, Enum.PartType.Ball)
		local away = Vector3.new((math.random() - 0.3) * 2.6, math.random() * 2.2, (math.random() - 0.5) * 1.6) * scale
		tween(ember, 0.35, { Position = position + away, Transparency = 1, Size = Vector3.one * 0.05 })
		Debris:AddItem(ember, 0.4)
	end
end

-- ZEPHYR's wind: a fast ring of air and two thin gusts.
function EffectsController:airBurst(position, facing, scale)
	self:ring(position, WHITE, 1 * scale, 4.2 * scale, 0.18, false, 0.05, Enum.Material.ForceField)
	for i = -1, 1, 2 do
		local start = position + Vector3.new(-facing * 0.6, i * 0.5 * scale, 0.3)
		local gust = self:part(Vector3.new(2.2 * scale, 0.06, 0.06), CFrame.new(start + Vector3.new(facing * 1.1 * scale, 0, 0)), WHITE)
		gust.Transparency = 0.2
		tween(gust, 0.16, { CFrame = gust.CFrame + Vector3.new(facing * 2, 0, 0), Transparency = 1 })
		Debris:AddItem(gust, 0.2)
	end
end

-- RYUKEN's rage: cracks of red light through the air round the blow, and a shock ring.
function EffectsController:rageCrack(position, color, scale)
	for i = 1, if self.reduced then 3 else 5 do
		local angle = i / 5 * math.pi * 2 + math.random() * 0.6
		local reach = (1.2 + math.random() * 1.2) * scale
		self:lightning(position, position + Vector3.new(math.cos(angle) * reach, math.sin(angle) * reach, 0.4), color)
	end
	self:ring(position, color, 1 * scale, 3.8 * scale, 0.18, false, 0.1)
end

-- The flourish of a blow going out, by verb (KitFX.SWINGS). Each gets: the view of the
-- attacker, `at` (where the blow reaches), the ki colour, the element's accent, heavy, the
-- facing, the fighting plane's z and whether it is a kick.
local SWINGS = {}
function SWINGS.kiStreak(self, view, at, color, accent, heavy, f, z)
	self:cut(at - Vector3.new(f * 1.4, 0, 0), at + Vector3.new(f * 0.4, 0, 0), color)
	if heavy then self:kiPop(at, color, 0.8) end
end
function SWINGS.fireStreak(self, view, at, color, accent, heavy, f, z)
	self:cut(at - Vector3.new(f * 1.8, 0, 0), at + Vector3.new(f * 0.6, 0, 0), FIRE)
	if heavy then self:fireRing(at, 1.3) end
end
function SWINGS.windCrescent(self, view, at, color, accent, heavy, f, z, kick)
	self:arc(Vector3.new(view.x + f * 0.6, at.Y, z), if heavy then 3.6 else 3, if kick then -70 else -40, if kick then 80 else 40, WHITE, 0.3, f)
end
function SWINGS.shadowSlash(self, view, at, color, accent, heavy, f, z)
	self:arc(Vector3.new(view.x + f * 0.6, at.Y, z), 2.6, 70, -50, color, 0.5, f)
	if heavy then self:cut(at + Vector3.new(-f, 1, 0), at + Vector3.new(f, -1, 0), color) end
end
function SWINGS.heatStreaks(self, view, at, color, accent, heavy, f, z)
	for i = -1, 1 do
		local y = at.Y + i * 0.35
		self:cut(Vector3.new(at.X - f * 2.4, y, z), Vector3.new(at.X, y, z), color)
	end
	if heavy then
		self:crack(Vector3.new(view.x + f, 0.05, z), Vector3.new(view.x + f * 4.5, 0.05, z + 0.5), color)
		self:smoke(at)
	end
end
function SWINGS.stoneWeight(self, view, at, color, accent, heavy, f, z)
	self:dust(view.x, 0, f)
	if heavy then
		self:crack(Vector3.new(view.x + f, 0.05, z), Vector3.new(view.x + f * 4, 0.05, z - 0.5), color)
		self:debris(Vector3.new(view.x + f * 2.5, 0.3, z), color, 0.8)
		self.camera:shake(if self.reduced then 0.15 else 0.4, 0.2)
	end
end
-- RAIJIN: the spear's thrust is a bolt running down its whole length; heavy, a strike from the sky.
function SWINGS.spearBolt(self, view, at, color, accent, heavy, f, z)
	local from, to = at - Vector3.new(f * 1.2, 0, 0), at + Vector3.new(f * 3.4, 0, 0)
	self:cut(from, to, accent)
	self:lightning(from, to, color)
	if heavy then
		local ground = Vector3.new(to.X, 0.1, z)
		self:lightning(ground + Vector3.new(f * 1.5, 11, 0), ground, accent)
		self:ring(ground, color, 1, 6, 0.3, true, 0.1)
	end
end
-- YUKINA: the two fans, two arcs of frost crossing; heavy, a line of frost along the floor.
function SWINGS.fanArcs(self, view, at, color, accent, heavy, f, z)
	local center = Vector3.new(view.x + f * 0.5, at.Y, z)
	self:arc(center, 2.7, 110, -30, accent, 0.4, f)
	self:arc(center + Vector3.new(0, -0.3, 0), 2.4, -60, 70, color, -0.4, f)
	self:shards(at, accent, 4, 0.5, Enum.Material.Ice, 0.25)
	if heavy then
		self:crack(Vector3.new(view.x + f, 0.05, z), Vector3.new(view.x + f * 5, 0.05, z + 0.3), accent)
		self:debris(Vector3.new(view.x + f * 3, 0.3, z), color, 0.6, "ice")
	end
end
-- VENOM: three thin fang swipes dripping poison; heavy, a spit of venom ahead.
function SWINGS.fangSwipe(self, view, at, color, accent, heavy, f, z)
	for i, r in { 2.3, 2.65, 3.0 } do
		self:arc(Vector3.new(view.x + f * 0.5, at.Y + (i - 2) * 0.2, z), r, 80, -40, if i == 2 then accent else color, 0.3, f)
	end
	self:drops(at, accent, 3, 1, 8)
	if heavy then
		self:orbDart(at, at + Vector3.new(f * 4, -0.6, 0), accent)
		task.delay(0.1, function() self:drops(at + Vector3.new(f * 4, -0.6, 0), accent, 6, 1.2, 14) end)
	end
end
-- GORAN: no light show, weight: the floor rings under every blow; heavy, it quakes.
function SWINGS.titanStomp(self, view, at, color, accent, heavy, f, z)
	self:ring(Vector3.new(view.x + f * 0.8, 0.08, z), accent, 1.5, if heavy then 9 else 5, 0.35, true, 0.12,
		Enum.Material.SmoothPlastic)
	self:dust(view.x + f, 0, f)
	if heavy then
		self:dust(view.x + f, 0, -f)
		self:debris(Vector3.new(view.x + f * 2, 0.3, z), color, 0.7)
		self.camera:shake(if self.reduced then 0.2 else 0.5, 0.22)
	end
end
-- ASTER: rings of gravity close in on the fist; heavy, a small dark mass at its heart.
function SWINGS.gravityRings(self, view, at, color, accent, heavy, f, z)
	for i = 1, if heavy then 3 else 2 do
		task.delay((i - 1) * 0.04, function()
			local ring = self:part(Vector3.new(0.06, 3.2, 3.2), CFrame.new(at) * FACE * CFrame.Angles(i * 0.7, 0, 0), if i % 2 == 0 then accent else color,
				Enum.PartType.Cylinder)
			ring.Material = Enum.Material.ForceField
			tween(ring, 0.2, { Size = Vector3.new(0.06, 0.4, 0.4), Transparency = 1 }, Enum.EasingStyle.Quart)
			Debris:AddItem(ring, 0.25)
		end)
	end
	if heavy then
		local mass = self:part(Vector3.one * 0.3, CFrame.new(at), VOID, Enum.PartType.Ball)
		mass.Material = Enum.Material.SmoothPlastic
		tween(mass, 0.25, { Size = Vector3.one * 1.4, Transparency = 1 })
		Debris:AddItem(mass, 0.3)
	end
end
-- HIBIKI: sound ripples running ahead of the blow, one after another.
function SWINGS.soundRipples(self, view, at, color, accent, heavy, f, z)
	for i = 1, if heavy then 4 else 2 do
		task.delay((i - 1) * 0.045, function()
			self:arc(Vector3.new(at.X - f * 1.2 + f * i * 0.7, at.Y, z), 0.9 + i * 0.35, -55, 55, if i % 2 == 0 then accent else color, 0, f)
		end)
	end
end
-- KAZAN: three claw arcs side by side, steel sparks; heavy, the chain lashes out.
function SWINGS.tripleClaw(self, view, at, color, accent, heavy, f, z)
	for i = -1, 1 do
		self:arc(Vector3.new(view.x + f * 0.5, at.Y + i * 0.38, z), 2.7, 75, -45, if i == 0 then accent else color, 0.25, f)
	end
	self:shards(at, Color3.fromHex("FFB04A"), 3, 0.35)
	if heavy then
		local from, to = Vector3.new(view.x + f * 0.6, at.Y, z), at + Vector3.new(f * 3.5, 0, 0)
		for i = 0, 6 do
			local p = from:Lerp(to, i / 7)
			local link = self:part(Vector3.new(0.12, 0.3, 0.55), CFrame.lookAt(p, to) * CFrame.Angles(0, 0, if i % 2 == 0 then 0 else math.pi / 2), accent)
			link.Material = Enum.Material.Metal
			tween(link, 0.3, { Transparency = 1 })
			Debris:AddItem(link, 0.35)
		end
	end
end
-- KUREN: a thick crimson crescent shedding drops; heavy, the blood lance.
function SWINGS.bloodCrescent(self, view, at, color, accent, heavy, f, z)
	local center = Vector3.new(view.x + f * 0.6, at.Y, z)
	self:arc(center, 3, 100, -60, accent, 0.2, f)
	self:arc(center, 2.6, 100, -60, color, 0.2, f)
	self:drops(at, accent, 3, 0.9, 8)
	if heavy then self:cut(at - Vector3.new(f, 0, 0), at + Vector3.new(f * 5, 0, 0), accent) end
end
-- SYLVA: a vine whips in a wave, leaves flying; heavy, thorns out of the floor.
function SWINGS.vineWhip(self, view, at, color, accent, heavy, f, z)
	local prev = Vector3.new(view.x + f * 0.4, at.Y - 0.4, z)
	for i = 1, 6 do
		local p = Vector3.new(view.x + f * (0.4 + i * 0.6), at.Y + math.sin(i * 1.3) * 0.5, z)
		local seg = self:part(Vector3.new(0.16, 0.16, (p - prev).Magnitude + 0.1), CFrame.lookAt((p + prev) / 2, p), if i % 2 == 0 then accent else color)
		seg.Material = Enum.Material.Neon
		task.delay(i * 0.012, function() if seg.Parent then tween(seg, 0.25, { Transparency = 1, Size = seg.Size * Vector3.new(0.3, 0.3, 1) }) end end)
		Debris:AddItem(seg, 0.35)
		prev = p
	end
	self:drops(at, accent, 3, 1.2, 10, 0.35)
	if heavy then self:debris(Vector3.new(view.x + f * 2.6, 0.3, z), accent, 0.7, "thorn") end
end
-- ELIAN: a warm light from the palm; heavy, a column of light.
function SWINGS.lightPalm(self, view, at, color, accent, heavy, f, z)
	local glow = self:part(Vector3.one * 0.6, CFrame.new(at), accent, Enum.PartType.Ball)
	glow.Transparency = 0.2
	tween(glow, 0.22, { Size = Vector3.one * 2.2, Transparency = 1 })
	Debris:AddItem(glow, 0.25)
	self:ring(at, color, 0.6, 2.6, 0.22, false, 0.05)
	if heavy then
		local column = self:part(Vector3.new(10, 1.2, 1.2), CFrame.new(at.X + f, 5, z) * FLAT, accent, Enum.PartType.Cylinder)
		column.Transparency = 0.3
		tween(column, 0.4, { Size = Vector3.new(14, 0.1, 0.1), Transparency = 1 })
		Debris:AddItem(column, 0.45)
	end
end
-- NOVA: the gauntlet's piston: a hard straight blow and steam out of the elbow.
function SWINGS.pistonPunch(self, view, at, color, accent, heavy, f, z)
	self:cut(at - Vector3.new(f * 1.2, 0, 0), at + Vector3.new(f * 0.8, 0, 0), color)
	for i = 1, if heavy then 4 else 2 do
		local puff = self:part(Vector3.one * 0.3, CFrame.new(at - Vector3.new(f * 2, 0, 0)), WHITE)
		puff.Material, puff.Transparency = Enum.Material.SmoothPlastic, 0.3
		tween(puff, 0.3, { Position = puff.Position + Vector3.new(-f * (1 + i * 0.4), (math.random() - 0.3) * 1, 0), Size = Vector3.one * 0.8, Transparency = 1 })
		Debris:AddItem(puff, 0.35)
	end
	if heavy then
		self:cut(at - Vector3.new(f * 4, 0, 0), at - Vector3.new(f * 2, 0, 0), FIRE) -- (the thruster)
		self:pixels(at, color, accent, 4, 0.8)
	end
end
-- KUROEN: red ki round a black core; heavy, a small black sun on the fist.
function SWINGS.eclipseStreak(self, view, at, color, accent, heavy, f, z)
	self:cut(at - Vector3.new(f * 1.8, 0, 0), at + Vector3.new(f * 0.5, 0, 0), color)
	local core = self:part(Vector3.new(0.18, 0.18, 2), CFrame.lookAt(at - Vector3.new(f * 0.7, 0, 0), at), accent)
	core.Material = Enum.Material.SmoothPlastic
	tween(core, 0.2, { Transparency = 1 })
	Debris:AddItem(core, 0.25)
	if heavy then self:eclipse(at, color, 0.18, 0.3) end
end
-- ASURA: four arms, two blows at once: two golden streaks.
function SWINGS.fourArms(self, view, at, color, accent, heavy, f, z)
	self:cut(at - Vector3.new(f * 1.6, -0.4, 0), at + Vector3.new(f * 0.4, 0.4, 0), accent)
	self:cut(at - Vector3.new(f * 1.6, 0.5, 0), at + Vector3.new(f * 0.4, -0.5, 0), color)
	if heavy then self:kiPop(at, accent, 1.1) end
end
-- KUROEN SHIN: the eclipse turned to light: white and gold.
function SWINGS.divineStreak(self, view, at, color, accent, heavy, f, z)
	self:cut(at - Vector3.new(f * 2, 0, 0), at + Vector3.new(f * 0.6, 0, 0), accent)
	self:cut(at - Vector3.new(f * 1.4, 0.3, 0), at + Vector3.new(f * 0.3, 0.3, 0), GOLD)
	if heavy then self:ring(at, GOLD, 1, 4.2, 0.25, false, 0.08) end
end
SWINGS.weapon = SWINGS.kiStreak -- (SHIN, DAICHA: their weapon draws it, weaponStrike)

-- The mark of a blow that lands, by verb (KitFX.HITS).
local HITS = {}
function HITS.kiPop(self, p, color, accent, s) self:kiPop(p, color, s) end
function HITS.fireRing(self, p, color, accent, s) self:fireRing(p, s) end
function HITS.airBurst(self, p, color, accent, s, facing) self:airBurst(p, facing, s) end
function HITS.shadowCross(self, p, color, accent, s)
	self:cut(p + Vector3.new(-1.1, 0.9, 0.3) * s, p + Vector3.new(1.1, -0.9, 0.3) * s, color)
	self:cut(p + Vector3.new(-1.1, -0.9, 0.3) * s, p + Vector3.new(1.1, 0.9, 0.3) * s, color)
end
function HITS.rageCrack(self, p, color, accent, s) self:rageCrack(p, color, s) end
function HITS.rubble(self, p, color, accent, s, facing)
	self:debris(p, STONE, 0.5 * s)
	self:dust(p.X, 0, facing)
end
function HITS.bladeLine(self, p, color, accent, s, facing)
	self:cut(p + Vector3.new(-facing * 1.3, 0.6, 0.3), p + Vector3.new(facing * 1.3, -0.6, 0.3), color)
end
function HITS.orbBurst(self, p, color, accent, s) self:orbBurst(p, color, 0.7 * s) end
function HITS.thunderStrike(self, p, color, accent, s)
	self:lightning(p + Vector3.new((math.random() - 0.5) * 2, 6 * s, 0), p, accent)
	self:shards(p, accent, 5, 0.6 * s, nil, 0.15)
end
function HITS.iceShards(self, p, color, accent, s)
	self:shards(p, accent, 7, 0.8 * s, Enum.Material.Ice, 0.35)
	self:ring(p, color, 0.8, 3 * s, 0.25, false, 0.06, Enum.Material.ForceField)
end
function HITS.toxicSplash(self, p, color, accent, s)
	self:ring(p, accent, 0.6, 2.8 * s, 0.22, false, 0.12)
	self:drops(p, accent, 6, s, 12)
	local bubble = self:part(Vector3.one * 0.7 * s, CFrame.new(p + Vector3.new(0, 0, 0.4)), color, Enum.PartType.Ball)
	bubble.Material, bubble.Transparency = Enum.Material.Glass, 0.4
	tween(bubble, 0.25, { Size = Vector3.one * 1.8 * s, Transparency = 1 })
	Debris:AddItem(bubble, 0.3)
end
function HITS.quake(self, p, color, accent, s, facing)
	self:ring(Vector3.new(p.X, 0.08, p.Z), accent, 1, 6 * s, 0.4, true, 0.15, Enum.Material.SmoothPlastic)
	self:debris(Vector3.new(p.X, 0.3, p.Z), color, 0.5 * s)
	self:dust(p.X, 0, facing)
	self.camera:shake((if self.reduced then 0.1 else 0.25) * s, 0.15)
end
function HITS.implode(self, p, color, accent, s)
	local ring = self:part(Vector3.new(0.08, 4.5 * s, 4.5 * s), CFrame.new(p) * FACE, accent, Enum.PartType.Cylinder)
	ring.Material = Enum.Material.ForceField
	tween(ring, 0.16, { Size = Vector3.new(0.08, 0.3, 0.3) }, Enum.EasingStyle.Quart)
	Debris:AddItem(ring, 0.17)
	task.delay(0.15, function() self:kiPop(p, color, 0.9 * s) end)
end
function HITS.soundBurst(self, p, color, accent, s)
	for i = 0, 2 do
		task.delay(i * 0.05, function() self:ring(p, if i == 1 then accent else color, 0.8, (2.4 + i * 1.2) * s, 0.22, false, 0.05) end)
	end
end
function HITS.clawMarks(self, p, color, accent, s, facing)
	for i = -1, 1 do
		local o = Vector3.new(0, i * 0.4, 0.3) * s
		self:cut(p + o + Vector3.new(-facing * 1.1, 0.7, 0) * s, p + o + Vector3.new(facing * 1.1, -0.7, 0) * s, if i == 0 then accent else color)
	end
	self:shards(p, Color3.fromHex("FFB04A"), 4, 0.4 * s, nil, 0.18)
end
function HITS.bloodBloom(self, p, color, accent, s)
	local core = self:part(Vector3.one * 0.6 * s, CFrame.new(p), accent, Enum.PartType.Ball)
	core.Material = Enum.Material.SmoothPlastic
	tween(core, 0.2, { Size = Vector3.one * 2 * s, Transparency = 1 })
	Debris:AddItem(core, 0.25)
	self:drops(p, accent, 6, s, 12)
	self:ring(p, color, 0.6, 2.6 * s, 0.2, false, 0.06)
end
function HITS.leafBurst(self, p, color, accent, s)
	self:drops(p, accent, 7, 1.4 * s, 16, 0.3)
	self:ring(p, color, 0.6, 2.8 * s, 0.22, false, 0.05)
end
function HITS.halo(self, p, color, accent, s)
	local halo = self:ring(p + Vector3.new(0, 1.2, 0), accent, 1.6 * s, 2.2 * s, 0.4, true, 0.12)
	tween(halo, 0.4, { Position = halo.Position + Vector3.new(0, 1.2, 0), Transparency = 1 })
	self:kiPop(p, accent, 0.8 * s)
	self:shards(p, WHITE, 4, 0.7 * s, nil, 0.2)
end
function HITS.glitch(self, p, color, accent, s)
	self:pixels(p, color, accent, 6, s)
	local scan = self:part(Vector3.new(0.05, 2.6 * s, 0.05), CFrame.new(p + Vector3.new(-1, 0, 0.4)), accent)
	tween(scan, 0.14, { Position = p + Vector3.new(1, 0, 0.4), Transparency = 1 }, Enum.EasingStyle.Linear)
	Debris:AddItem(scan, 0.16)
end
function HITS.eclipseBurst(self, p, color, accent, s)
	local sun = self:part(Vector3.one * 0.5 * s, CFrame.new(p + Vector3.new(0, 0, 0.3)), Color3.fromHex("07040C"), Enum.PartType.Ball)
	sun.Material = Enum.Material.SmoothPlastic
	tween(sun, 0.18, { Size = Vector3.one * 1.6 * s, Transparency = 1 })
	Debris:AddItem(sun, 0.22)
	self:ring(p, color, 1.2, 3.6 * s, 0.22, false, 0.1)
end
function HITS.goldenFists(self, p, color, accent, s)
	self:kiPop(p + Vector3.new(0, 0.5, 0), accent, s)
	self:kiPop(p - Vector3.new(0, 0.5, 0), color, 0.8 * s)
end
function HITS.divineBurst(self, p, color, accent, s)
	self:kiPop(p, WHITE, 1.2 * s)
	self:ring(p, GOLD, 1, 4 * s, 0.25, false, 0.08)
	self:shards(p, GOLD, 6, 0.8 * s, nil, 0.22)
end

-- The dash, by verb (KitFX.DASHES): what the fighter leaves behind them as they go.
local DASHES = {}
local function feet(view, z) return Vector3.new(view.x, 0.2, z) end
function DASHES.dust(self, view) self:dust(view.x, view.y, view.facing) end
function DASHES.embers(self, view, color, accent, z)
	self:dust(view.x, view.y, view.facing)
	self:drops(feet(view, z) + Vector3.new(0, 0.6, 0), FIRE, 4, 0.8, 6)
end
function DASHES.gust(self, view, color, accent, z)
	for i = -1, 1 do
		local start = Vector3.new(view.x, view.y + 2.5 + i * 0.9, z + 0.4)
		local gust = self:part(Vector3.new(2.4, 0.05, 0.05), CFrame.new(start), WHITE)
		gust.Transparency = 0.3
		tween(gust, 0.2, { Position = start - Vector3.new(view.facing * 2.5, 0, 0), Transparency = 1 })
		Debris:AddItem(gust, 0.22)
	end
end
function DASHES.shade(self, view) end -- (AKEMI: the afterimages are her dash)
function DASHES.scorch(self, view, color, accent, z)
	self:dust(view.x, view.y, view.facing)
	self:smoke(feet(view, z))
end
function DASHES.tremor(self, view, color, accent, z)
	self:dust(view.x, view.y, view.facing)
	self:dust(view.x, view.y, -view.facing)
end
function DASHES.sparks(self, view, color, accent, z)
	self:lightning(feet(view, z) + Vector3.new(-view.facing * 2.5, 0.2, 0), feet(view, z), accent)
end
function DASHES.frost(self, view, color, accent, z)
	self:crack(feet(view, z) - Vector3.new(view.facing * 3, 0.15, 0), feet(view, z) - Vector3.new(0, 0.15, 0), accent)
end
function DASHES.venomTrail(self, view, color, accent, z)
	self:drops(feet(view, z) + Vector3.new(0, 0.8, 0), accent, 3, 0.8, 4)
end
function DASHES.stomp(self, view, color, accent, z)
	self:dust(view.x, view.y, view.facing)
	self:ring(feet(view, z) - Vector3.new(0, 0.1, 0), accent, 1, 4, 0.3, true, 0.1, Enum.Material.SmoothPlastic)
end
function DASHES.float(self, view, color, accent, z)
	self:ring(Vector3.new(view.x, view.y + 0.1, z), accent, 0.8, 3, 0.3, true, 0.05, Enum.Material.ForceField)
end
function DASHES.beat(self, view, color, accent, z)
	self:ring(Vector3.new(view.x, view.y + 0.1, z), color, 0.6, 3.4, 0.2, true, 0.05)
	task.delay(0.1, function() self:ring(Vector3.new(view.x, view.y + 0.1, z), accent, 0.6, 2.6, 0.2, true, 0.05) end)
end
function DASHES.chain(self, view, color, accent, z)
	self:dust(view.x, view.y, view.facing)
	self:shards(feet(view, z) + Vector3.new(0, 0.3, 0), Color3.fromHex("FFB04A"), 3, 0.3, nil, 0.15)
end
function DASHES.mist(self, view, color, accent, z)
	for _ = 1, if self.reduced then 2 else 4 do
		local puff = self:part(Vector3.one * 0.6, CFrame.new(view.x + (math.random() - 0.5), view.y + 1 + math.random() * 2.5, z), accent, Enum.PartType.Ball)
		puff.Material, puff.Transparency = Enum.Material.SmoothPlastic, 0.45
		tween(puff, 0.5, { Size = Vector3.one * 1.6, Transparency = 1 })
		Debris:AddItem(puff, 0.55)
	end
end
function DASHES.petals(self, view, color, accent, z)
	self:drops(Vector3.new(view.x, view.y + 1.5, z), accent, 4, 1.2, 6, 0.3)
end
function DASHES.glow(self, view, color, accent, z)
	self:drops(Vector3.new(view.x, view.y + 2, z), accent, 3, 0.7, 4)
end
function DASHES.thrusters(self, view, color, accent, z)
	for i = -1, 1, 2 do
		local from = Vector3.new(view.x - view.facing * 0.4, view.y + 2.6 + i * 0.3, z - 0.3)
		self:cut(from, from - Vector3.new(view.facing * 2.2, 0.4, 0), FIRE)
	end
end
function DASHES.redShade(self, view, color, accent, z)
	self:dust(view.x, view.y, view.facing)
end
function DASHES.ripple(self, view, color, accent, z)
	self:wake(feet(view, z) - Vector3.new(view.facing * 3, 0.15, 0), feet(view, z) - Vector3.new(0, 0.15, 0), color, 0.6)
end
function DASHES.warp(self, view, color, accent, z)
	self:ring(Vector3.new(view.x, view.y + 0.1, z), color, 2.6, 0.4, 0.2, true, 0.06, Enum.Material.ForceField)
end
function DASHES.goldShade(self, view, color, accent, z)
	self:dust(view.x, view.y, view.facing)
	self:ring(Vector3.new(view.x, view.y + 0.1, z), GOLD, 1, 4, 0.25, true, 0.06)
end

-- Every verb of KitFX has its drawing (a missing one would silently fall back to KAI's).
for name in KitFX.SWINGS do assert(SWINGS[name], "KitFX swing without a drawing: " .. name) end
for name in KitFX.HITS do assert(HITS[name], "KitFX hit without a drawing: " .. name) end
for name in KitFX.DASHES do assert(DASHES[name], "KitFX dash without a drawing: " .. name) end

local function accentOf(fx)
	return Color3.fromHex(fx.accent)
end

-- A blow goes out (first contact frame): the kit's flourish along the strike.
function EffectsController:kitSwing(view, moveId, color, heavy)
	local kit = MoveData.MoveKit[moveId] or view.kit or "KAI"
	local fx = KitFX.of(kit)
	local role = ROLE_OF[moveId] or moveId
	local f, z = view.facing, self.config.PlaneZ
	local limbs = strikeLimbs(moveId)
	local kick = limbs and (table.find(limbs, "RightFoot") or table.find(limbs, "LeftFoot")) ~= nil
	local at = Vector3.new(view.x + f * 2.2, view.y + (if role == "Sweep" or role == "LowKick" then 1 else 3.4), z)
	SWINGS[fx.swing](self, view, at, color, accentOf(fx), heavy, f, z, kick)
end

-- A blow lands: the kit's mark on the target.
function EffectsController:kitHit(moveId, position, color, heavy, facing)
	local fx = KitFX.of(MoveData.MoveKit[moveId] or "KAI")
	HITS[fx.hit](self, position, color, accentOf(fx), if heavy then 1.5 else 1, facing)
end

-- The dash starts: the afterimages, and what the kit leaves on the floor.
function EffectsController:kitDash(view, color)
	local fx = KitFX.of(view.kit)
	DASHES[fx.dash](self, view, color, accentOf(fx), self.config.PlaneZ)
end

-- The motes always floating round the fighter (very light: none in reduced mode), and the
-- strike trails in the element's colours.
local MOTION = {
	rise = { accel = Vector3.new(0, 4, 0), speed = NumberRange.new(0.5, 1.5), life = NumberRange.new(1, 1.6), drag = 0 },
	fall = { accel = Vector3.new(0, -2.5, 0), speed = NumberRange.new(0.6, 1.4), life = NumberRange.new(1.2, 1.8), drag = 1 },
	drift = { accel = Vector3.new(0, 0.6, 0), speed = NumberRange.new(0.6, 1.2), life = NumberRange.new(1.2, 2), drag = 1.5 },
	orbit = { accel = Vector3.zero, speed = NumberRange.new(1.5, 2.5), life = NumberRange.new(0.8, 1.2), drag = 3 },
	flicker = { accel = Vector3.zero, speed = NumberRange.new(3, 6), life = NumberRange.new(0.12, 0.25), drag = 0 },
}
function EffectsController:ambient(rig, kitName, energyHex)
	local torso = RigReader.part(rig.model, "UpperTorso")
	if not torso then return end
	local fx = KitFX.of(kitName)
	local a = fx.ambient
	local motion = MOTION[a.motion] or MOTION.rise
	local motes = rig.motes
	if not motes or not motes.Parent then
		motes = Instance.new("ParticleEmitter")
		motes.Name = "KitMotes"
		motes.LightInfluence, motes.LockedToPart = 0, false
		motes.SpreadAngle = Vector2.new(180, 180)
		motes.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.7, 0.4),
			NumberSequenceKeypoint.new(1, 1) })
		motes.Parent = torso
		rig.motes = motes
	end
	-- (SHOP · VFX: an aura bought by the player recolours these motes, "RRGGBB,RRGGBB" set by
	-- the server on the rig; the kit's shapes and motion stay: cosmetic only)
	local worn = rig.model:GetAttribute("Aura")
	local wornPair = if type(worn) == "string" and string.match(worn, "^%x%x%x%x%x%x,%x%x%x%x%x%x$") then string.split(worn, ",") else nil
	rig.motesAura = worn
	motes.Color = if wornPair then ColorSequence.new(Color3.fromHex(wornPair[1]), Color3.fromHex(wornPair[2]))
		else ColorSequence.new(Color3.fromHex(KitFX.color(a.colors[1], energyHex)), Color3.fromHex(KitFX.color(a.colors[2], energyHex)))
	motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, a.size), NumberSequenceKeypoint.new(1, a.size * 0.3) })
	motes.Acceleration, motes.Speed, motes.Lifetime, motes.Drag = motion.accel, motion.speed, motion.life, motion.drag
	motes.LightEmission = if a.motion == "flicker" then 1 else 0.5
	motes.Rate = KitFX.ambientRate(kitName, self.reduced)
	rig.motesKit, rig.motesReduced = kitName, self.reduced
	-- (strike trails and the ki aura's bursts: the element's two colours)
	local pair = ColorSequence.new(Color3.fromHex(KitFX.color(fx.trail[1], energyHex)), Color3.fromHex(KitFX.color(fx.trail[2], energyHex)))
	for limb, trail in rig.trails or {} do
		if limb ~= "Weapon" then trail.Color = pair end
	end
	if rig.aura then rig.aura.Color = pair end
end

-- Smear arc for strong attacks, drawn in the fighting plane in front of the attacker.
function EffectsController:slash(fighter, moveId, color)
	local arcs = {
		Kick = { from = -70, to = 55, radius = 3.4, height = 3 },
		Smash = { from = -25, to = 25, radius = 3.9, height = 3.8 },
		Rising = { from = -80, to = 105, radius = 2.9, height = 3.2 },
		Uppercut = { from = -80, to = 100, radius = 2.8, height = 3 },
		SpinKick = { from = -35, to = 45, radius = 3.9, height = 3 },
		Hammer = { from = 115, to = -25, radius = 3.4, height = 3.2 },
		Sweep = { from = -75, to = -8, radius = 4, height = 1.1 },
		AirSmash = { from = 70, to = -70, radius = 3, height = 1.6 },
		BodyBlow = { from = -45, to = 5, radius = 3.2, height = 2.6 },
		KaienRush = { from = -25, to = 25, radius = 3.9, height = 3.8 },
		KiChase = { from = -60, to = 60, radius = 3.4, height = 3.4 },
		Finale = { from = -40, to = 40, radius = 4.4, height = 3.6 },
		Awakening = { from = -40, to = 40, radius = 4.4, height = 3.6 },
		DragonFist = { from = -80, to = 100, radius = 2.8, height = 3 },
		KiFlurry = { from = -20, to = 20, radius = 3.6, height = 3.6 },
		CrescentMoon = { from = 120, to = -60, radius = 3.4, height = 3.2 },
		DragonTornado = { from = -10, to = 350, radius = 3, height = 3.4 },
	}
	-- Other kits' moves use the arc of their role (TARO's hook = KAI's elbow slot...).
	local arc = arcs[moveId] or arcs[ROLE_OF[moveId] or ""]
	if not arc then return end
	local segments = if self.reduced then 7 else 13
	local cx, cy = fighter.x + fighter.facing * 0.6, fighter.y + arc.height
	for i = 0, segments - 1 do
		local t0, t1 = i / segments, (i + 1) / segments
		local a0 = math.rad(arc.from + (arc.to - arc.from) * t0)
		local a1 = math.rad(arc.from + (arc.to - arc.from) * t1)
		local p0 = Vector3.new(cx + fighter.facing * math.cos(a0) * arc.radius, cy + math.sin(a0) * arc.radius, 1)
		local p1 = Vector3.new(cx + fighter.facing * math.cos(a1) * arc.radius, cy + math.sin(a1) * arc.radius, 1)
		local width = 0.15 + 0.75 * math.sin(t0 * math.pi)
		local seg = self:part(Vector3.new(width, 0.1, (p1 - p0).Magnitude + 0.1), CFrame.lookAt((p0 + p1) / 2, p1, Vector3.zAxis),
			if i % 3 == 0 then WHITE else color)
		seg.Transparency = 0.15 + 0.5 * (1 - t0)
		tween(seg, 0.22, { Transparency = 1, Size = seg.Size * Vector3.new(0.3, 1, 1.15) })
		Debris:AddItem(seg, 0.25)
	end
	local role = ROLE_OF[moveId] or moveId
	if role == "Smash" or role == "KaienRush" or role == "Finale" or role == "Awakening" then -- speed streaks
		for i = 1, if self.reduced then 3 else 6 do
			local y = cy + (math.random() - 0.5) * 2.2
			local start = Vector3.new(fighter.x + fighter.facing * 1.5, y, 1.2)
			local length = 3 + math.random() * 3
			local streak = self:part(Vector3.new(length, 0.08, 0.08), CFrame.new(start + Vector3.new(fighter.facing * length / 2, 0, 0)),
				if i % 2 == 0 then WHITE else color)
			tween(streak, 0.18, { CFrame = streak.CFrame + Vector3.new(fighter.facing * 3, 0, 0), Transparency = 1 })
			Debris:AddItem(streak, 0.2)
		end
	end
end

-- Free smear arc of a cinematic (wind blades, hooks, cuts): around `center`, from / to in
-- degrees, in the fighting plane tilted by `tilt` radians around the X axis.
function EffectsController:arc(center, radius, from, to, color, tilt, dir)
	local segments = if self.reduced then 7 else 14
	local ct, st = math.cos(tilt or 0), math.sin(tilt or 0)
	local function at(angle)
		local a = math.rad(angle)
		return center + Vector3.new((dir or 1) * math.cos(a) * radius, math.sin(a) * radius * ct, math.sin(a) * radius * st)
	end
	for i = 0, segments - 1 do
		local t0 = i / segments
		local p0, p1 = at(from + (to - from) * t0), at(from + (to - from) * (i + 1) / segments)
		local width = 0.15 + 0.8 * math.sin(t0 * math.pi)
		local seg = self:part(Vector3.new(width, 0.1, (p1 - p0).Magnitude + 0.1), CFrame.lookAt((p0 + p1) / 2, p1, Vector3.zAxis),
			if i % 3 == 0 then WHITE else color)
		seg.Transparency = 0.1 + 0.5 * (1 - t0)
		tween(seg, 0.24, { Transparency = 1, Size = seg.Size * Vector3.new(0.3, 1, 1.15) })
		Debris:AddItem(seg, 0.27)
	end
end

-- Ground shockwave of a cinematic finisher: a flat ring racing outward and a ki pillar.
function EffectsController:shockwave(position, color)
	local ring = self:part(Vector3.new(0.3, 2, 2), CFrame.new(position + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		color, Enum.PartType.Cylinder)
	ring.Transparency = 0.1
	tween(ring, 0.6, { Size = Vector3.new(0.3, 60, 60), Transparency = 1 })
	Debris:AddItem(ring, 0.65)
	local pillar = self:part(Vector3.new(30, 4, 4), CFrame.new(position + Vector3.new(0, 15, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		WHITE, Enum.PartType.Cylinder)
	pillar.Transparency = 0.2
	tween(pillar, 0.5, { Size = Vector3.new(40, 12, 12), Transparency = 1 })
	Debris:AddItem(pillar, 0.55)
	self:spark(position + Vector3.new(0, 3, 0), color, 3)
	self:dust(position.X, 0, 1)
	self:dust(position.X, 0, -1)
end

function EffectsController:dust(x, y, direction)
	for i = 1, if self.reduced then 3 else 6 do
		local puff = self:part(Vector3.one * 0.6, CFrame.new(x + (math.random() - 0.5), y + 0.3, 0.5 + math.random()),
			Color3.fromHex("C9BFC0"), Enum.PartType.Ball)
		puff.Material, puff.Transparency = Enum.Material.SmoothPlastic, 0.3
		local drift = Vector3.new(-direction * (1 + math.random() * 2), 0.5 + math.random(), 0)
		tween(puff, 0.4, { Position = puff.Position + drift, Size = Vector3.one * (1.5 + i * 0.1), Transparency = 1 })
		Debris:AddItem(puff, 0.45)
	end
end

-- Translucent energy copy of the body, used for dash afterimages.
function EffectsController:afterimage(rig, color)
	for _, p in rig.model:GetChildren() do
		if p:IsA("BasePart") and BODY_PARTS[p.Name] then
			local ghost = self:part(p.Size, p.CFrame, color)
			ghost.Transparency = 0.55
			tween(ghost, 0.24, { Transparency = 1 })
			Debris:AddItem(ghost, 0.26)
		end
	end
end

function EffectsController:flash(rig)
	local outline = rig.model:FindFirstChild("InkOutline")
	if not outline then return end
	local base = rig.model:GetAttribute("BaseFill") or 1 -- shadow clones keep their tint
	outline.FillTransparency = 0.15
	task.delay(0.07, function()
		if outline.Parent then outline.FillTransparency = base end
	end)
end

-- Manga impact frame: black/white/red contrast for two short beats and radial speed lines.
function EffectsController:impactFrame(color, strength)
	local lines = if self.reduced then 10 else 26
	for i = 1, lines do
		local angle = (i / lines) * 360 + math.random() * 8
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BorderSizePixel = 0
		line.BackgroundColor3 = if i % 3 == 0 then color else WHITE
		line.BackgroundTransparency = 0.1
		line.Size = UDim2.new(0.55, 0, 0, 2 + math.random(0, 3) * strength)
		local rad = math.rad(angle)
		line.Position = UDim2.fromScale(0.5 + math.cos(rad) * 0.62, 0.5 + math.sin(rad) * 0.62)
		line.Rotation = angle
		line.Parent = self.overlay
		tween(line, 0.24, { BackgroundTransparency = 1, Size = UDim2.new(0.3, 0, 0, 1) })
		Debris:AddItem(line, 0.26)
	end
	if self.reduced then return end
	local grade = self.grade
	grade.Enabled, grade.Saturation, grade.Contrast, grade.Brightness, grade.TintColor = true, -1, 1.2, 0.05, WHITE
	task.delay(0.05, function()
		grade.Saturation, grade.Contrast, grade.TintColor = -0.4, 0.8, Color3.new(1, 0.42, 0.46)
		task.delay(0.05, function() grade.Enabled = false end)
	end)
end

-- The kit's weapon (SHIN's katana, DAICHA's orb, freed from his hand to fly): its parts
-- replicate after the body, so update tries again until they are there. True when done.
function EffectsController:attachWeapon(slot, rig)
	-- The kit's weapon: a ribbon along SHIN's blade (the arc of every cut), a smear behind
	-- DAICHA's orb; lit with the hand that holds it.
	local blade, orb = rig.model:FindFirstChild("KitBlade"), rig.model:FindFirstChild("KitShadowOrb")
	local weapon = blade or orb
	if not (weapon and weapon:IsA("BasePart")) then return false end
	rig.trails = rig.trails or {}
	-- (the orb's two parts both: kit pieces replicate one by one, after the body)
	rig.weaponSince = rig.weaponSince or os.clock()
	if orb and not rig.model:FindFirstChild("KitOrbCore") and os.clock() - rig.weaponSince < 3 then return false end
	do
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Name, a1.Name = "WeaponTrailBase", "WeaponTrailTip"
		if blade then
			a0.Position, a1.Position = Vector3.new(0, 0, blade.Size.Z * 0.45), Vector3.new(0, 0, -blade.Size.Z * 0.5)
		else
			a0.Position, a1.Position = Vector3.new(0, weapon.Size.Y * 0.45, 0), Vector3.new(0, -weapon.Size.Y * 0.45, 0)
		end
		a0.Parent, a1.Parent = weapon, weapon
		local trail = Instance.new("Trail")
		trail.Name = "WeaponTrail"
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Color = ColorSequence.new(WHITE, self:energy(slot))
		trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.6, 0.45),
			NumberSequenceKeypoint.new(1, 1) })
		trail.Lifetime, trail.MinLength, trail.LightEmission, trail.FaceCamera = if blade then 0.2 else 0.16, 0.02, 1, false
		if orb then
			-- (the orb's smear: from her colour to a dark violet, thinning to a point)
			trail.Color = ColorSequence.new(self:energy(slot), Color3.fromHex("2A1240"))
			trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.1) })
			trail.LightEmission, trail.Lifetime = 0.7, 0.2
		end
		trail.Enabled = false
		trail.Parent = weapon
		rig.trails.Weapon = trail
		rig.weaponHand = if blade then "RightHand" else "LeftHand"
		rig.weaponKind = if blade then "Sword" else "Orb"
		if orb then
			-- DAICHA's matter is set free: it flies round her (OrbFlight) and changes shape, moved
			-- every frame (a sphere to strike, a disc to guard).
			rig.orbParts = {}
			local free = {}
			for _, name in { "KitShadowOrb", "KitOrbCore" } do
				local p = rig.model:FindFirstChild(name)
				if p and p:IsA("BasePart") then
					free[p] = true
					table.insert(rig.orbParts, p)
				end
			end
			-- Every joint holding it to the hand goes, wherever it is parented.
			for _, joint in rig.model:GetDescendants() do
				if (joint:IsA("WeldConstraint") or joint:IsA("Weld") or joint:IsA("Motor6D"))
					and (free[joint.Part0] or free[joint.Part1]) then
					joint:Destroy()
				end
			end
			for p in free do p.Anchored, p.Massless = true, true end
			rig.orbPosition = orb.Position
		end
	end
	return true
end

function EffectsController:attachRig(slot, rig)
	local torso = RigReader.part(rig.model, "UpperTorso")
	if not torso then return end
	-- Motion trails on fists and feet (ki colour fading to white), lit only while striking.
	rig.trails = {}
	for _, limb in TRAIL_LIMBS do
		local part = RigReader.part(rig.model, limb)
		if part then
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Name, a1.Name = "TrailTop", "TrailBottom"
			-- On an R6 limb (a whole arm or leg), the trail follows its far end only.
			local top = if part.Name == limb then 0.4 else -0.25
			a0.Position, a1.Position = Vector3.new(0, part.Size.Y * top, 0), Vector3.new(0, -part.Size.Y * 0.45, 0)
			a0.Parent, a1.Parent = part, part
			local trail = Instance.new("Trail")
			trail.Name = "StrikeTrail"
			trail.Attachment0, trail.Attachment1 = a0, a1
			trail.Color = ColorSequence.new(self:energy(slot), WHITE)
			trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
			trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.15) })
			trail.Lifetime, trail.MinLength, trail.LightEmission, trail.FaceCamera = 0.13, 0.05, 1, true
			trail.Enabled = false
			trail.Parent = part
			rig.trails[limb] = trail
		end
	end
	rig.weaponDone = self:attachWeapon(slot, rig)
	-- Ki glow: lights the body in its ki colour when charging, skills and ultimates.
	local glow = Instance.new("PointLight")
	glow.Name = "KiGlow"
	glow.Color, glow.Range, glow.Brightness, glow.Shadows = self:energy(slot), 10, 0, false
	glow.Parent = torso
	rig.glow = glow
	local aura = Instance.new("ParticleEmitter")
	aura.Name = "KiAura"
	aura.Color = ColorSequence.new(self:energy(slot), WHITE)
	aura.LightEmission, aura.Rate, aura.Lifetime = 1, 0, NumberRange.new(0.25, 0.45)
	aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	aura.Speed, aura.SpreadAngle = NumberRange.new(3, 7), Vector2.new(180, 180)
	aura.Acceleration = Vector3.new(0, 8, 0)
	aura.Parent = torso
	rig.aura = aura
end

-- ASURA's SECOND LIFE: risen again, wrapped in a black aura for the rest of the match (black
-- smoke rising off the body, the body darkened, a blood-red outline). Cosmetic only.
function EffectsController:blackAura(rig)
	local torso = rig.model:FindFirstChild("UpperTorso") or rig.model:FindFirstChild("Torso")
	if not torso then return false end
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "BlackAura"
	smoke.Color = ColorSequence.new(Color3.fromHex("000000"), Color3.fromHex("2A0A1E"))
	smoke.LightEmission, smoke.LightInfluence = 0, 0
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 3.2) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(0.7, 1.2)
	smoke.Speed = NumberRange.new(3, 6)
	smoke.SpreadAngle = Vector2.new(25, 25)
	smoke.Acceleration = Vector3.new(0, 6, 0)
	smoke.Rate = if self.reduced then 14 else 40
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.Parent = torso
	local outline = rig.model:FindFirstChild("InkOutline")
	if outline then
		outline.FillColor, outline.OutlineColor = Color3.fromHex("000000"), Color3.fromHex("B0102A")
		outline.FillTransparency = 0.55
		rig.model:SetAttribute("BaseFill", 0.55)
	end
	return true
end

-- KUROEN's DOMINATION, readable by both players: no aura at 0; I a few red embers, II red and
-- black smoke, III (ÉCLIPSE) a black core with red flames and a red ring at his feet. One
-- emitter, its rate and colours set by the level (cheap).
local DOMINATION_LOOK = {
	{ rate = 6, size = 0.6, colors = { "FF4A5A", "E0102E" } },
	{ rate = 16, size = 0.9, colors = { "E0102E", "1A0408" } },
	{ rate = 30, size = 1.3, colors = { "0A0204", "FF1A2E" } },
}
function EffectsController:domination(rig, level, view)
	local torso = rig.model:FindFirstChild("UpperTorso") or rig.model:FindFirstChild("Torso")
	if not torso then return end
	local aura = rig.dominationAura
	if not aura or not aura.Parent then
		aura = Instance.new("ParticleEmitter")
		aura.Name = "DominationAura"
		aura.LightEmission, aura.LightInfluence = 0.3, 0
		aura.Lifetime = NumberRange.new(0.4, 0.8)
		aura.Speed = NumberRange.new(2, 5)
		aura.SpreadAngle = Vector2.new(30, 30)
		aura.Acceleration = Vector3.new(0, 8, 0)
		aura.EmissionDirection = Enum.NormalId.Top
		aura.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		aura.Parent = torso
		rig.dominationAura = aura
	end
	if rig.dominationLevel == level then return end
	rig.dominationLevel = level
	local look = DOMINATION_LOOK[level]
	aura.Enabled = look ~= nil
	if look then
		aura.Rate = if self.reduced then look.rate * 0.4 else look.rate
		aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, look.size), NumberSequenceKeypoint.new(1, look.size * 2) })
		aura.Color = ColorSequence.new(Color3.fromHex(look.colors[1]), Color3.fromHex(look.colors[2]))
		if level == 3 then self:arc(Vector3.new(view.x, 0.08, self.config.PlaneZ), 2.6, 0, 360, Color3.fromHex("E0102E"), math.pi / 2, 1) end
	end
end

-- Per-frame presentation driven by the interpolated fighter views.
function EffectsController:update(slot, view, rig, previous, now)
	if view.revived and not rig.blackAura then rig.blackAura = self:blackAura(rig) end
	if view.kit == "KUROEN" or rig.dominationAura then self:domination(rig, view.domination or 0, view) end
	local color = self:energy(slot)
	local energyHex = CharacterData[slot].Energy
	if rig.motesKit ~= view.kit or rig.motesReduced ~= self.reduced or rig.motesEnergy ~= energyHex
		or (rig.model and rig.motesAura ~= rig.model:GetAttribute("Aura")) then
		rig.motesEnergy = energyHex
		self:ambient(rig, view.kit, energyHex)
	end
	local phase = if view.state == "Attack" and MoveData.Moves[view.move]
		then MoveData.phase(MoveData.Moves[view.move], view.moveFrame) else nil
	local key = if phase then view.move .. phase else view.state
	if previous and previous.key ~= key then
		if phase == "Active" and not view.ghost then -- staged cinematic poses bring their own effects
			local m = MoveData.Moves[view.move]
			-- The weapon kits draw every stroke; the others their own flourish, and a smear on
			-- their strong attacks.
			if not self:weaponStrike(view, view.move, color, rig) then
				self:kitSwing(view, view.move, color, m.heavy)
				if m.heavy then self:slash(view, view.move, color) end
			end
		elseif view.state == "Dashing" then
			self:kitDash(view, color)
		elseif view.state == "Knockdown" and previous.key ~= "KO" then
			self:dust(view.x, view.y, view.facing)
			self.camera:shake(if self.reduced then 0.15 else 0.35, 0.2)
		end
	end
	local role = ROLE_OF[view.move] or view.move
	if rig.aura and phase == "Startup" and (role == "Smash" or role == "Rising" or role == "Uppercut"
		or role == "Hammer" or role == "KaienRush") then
		rig.aura:Emit(if self.reduced then 1 else 3)
	end
	if view.ghost and previous and previous.key ~= key and now - (self.ghostClock[slot] or 0) > 0.06 then
		self.ghostClock[slot] = now
		self:afterimage(rig, color)
	end
	if view.state == "Dashing" and now - (self.ghostClock[slot] or 0) > 0.045 then
		self.ghostClock[slot] = now
		self:afterimage(rig, color)
	end
	-- Strike trails from the end of the wind-up to the start of the recovery.
	if rig.trails then
		local m = view.state == "Attack" and MoveData.Moves[view.move]
		local limbs = m and strikeLimbs(view.move)
		local swinging = m and view.moveFrame >= m.startup * 0.6 and view.moveFrame <= m.startup + m.active + m.recovery * 0.25
		-- (a weapon's ribbon also draws the wind-up and the follow-through)
		local weaponSwinging = m and view.moveFrame >= m.startup * 0.4 and view.moveFrame <= m.startup + m.active + m.recovery * 0.45
		for limb, trail in rig.trails do
			local isWeapon = limb == "Weapon"
			if isWeapon and rig.orbParts then continue end -- (the free orb draws its own: flyOrb)
			local hand = if isWeapon then rig.weaponHand else limb
			local on = limbs ~= nil and (if isWeapon then weaponSwinging else swinging) and table.find(limbs, hand) ~= nil
				and not (self.reduced and not m.heavy and not isWeapon)
			if trail.Enabled ~= on then trail.Enabled = on end
		end
	end
	if not rig.weaponDone and now - (rig.weaponTry or 0) > 0.2 then
		-- (the weapon arrived after the body, or the outfit was rebuilt: attach it now)
		rig.weaponTry = now
		rig.weaponDone = self:attachWeapon(slot, rig)
	end
	if rig.orbParts and rig.orbParts[1] and not rig.orbParts[1].Parent then
		rig.orbParts, rig.weaponDone, rig.weaponKind, rig.weaponSince = nil, false, nil, nil
	end
	if rig.orbParts then self:flyOrb(rig, view, now, slot) end
	self:weaponDressing(rig, view, now, slot)
	self:iceMirror(slot, rig, view, now, color)
	self:poisonAura(slot, rig, view, now)
	-- (no drawn guard any more: SHIN's guard is his katana raised over his head, and the blow
	-- on it strikes sparks off the steel (onEvent: Block); DAICHA's is her matter flattened:
	-- flyOrb. Wilhem: « SHIN a un vieil effet bleu quand il bloque »)
	if rig.glow then
		local m = view.state == "Attack" and MoveData.Moves[view.move]
		local target = 0
		if m and (m.meterCost or m.skill) then
			target = if MoveData.phase(m, view.moveFrame) == "Recovery" then 0.6 else 2.6
		elseif view.meter and view.meter >= MoveData.Moves[(MoveData.Kits[view.kit] or MoveData.Kits.KAI).Ultimates.Rush].meterCost then
			target = 0.5 + 0.35 * math.sin(now * 5)
		end
		-- RYUKEN's RAGE: the body glows hotter with every stack.
		local passive = (MoveData.Kits[view.kit] or MoveData.Kits.KAI).Passive
		if passive and passive.Type == "Rage" and (view.passive or 0) > 0 then
			target = math.max(target, 1.6 * view.passive / passive.Max + 0.25 * math.sin(now * 9))
		end
		rig.glow.Brightness += (target - rig.glow.Brightness) * math.min(1, (if target > rig.glow.Brightness then 18 else 5) / 60)
	end
	if self.debug then self:drawDebug(slot, view) end
	return key
end

function EffectsController:onEvent(event, views, rigs)
	if event.kind == "GroundBounce" or event.kind == "WallBounce" then
		local x = if event.kind == "WallBounce" then math.clamp(event.x, self.config.ArenaMinX, self.config.ArenaMaxX) else event.x
		self:dust(x, if event.kind == "WallBounce" then event.y + 2 else 0, 1)
		self:spark(Vector3.new(x, event.y + 1, 0), WHITE, 1.1)
		self.camera:shake(if self.reduced then 0.2 else 0.45, 0.22)
		return
	elseif event.kind == "SuperJump" then
		local v = views[event.attacker]
		if v then self:dust(v.x, 0, v.facing) end
		return
	elseif event.kind == "SuperFlash" then
		local rig = rigs[event.attacker]
		local v = views[event.attacker]
		if rig and rig.aura then rig.aura:Emit(if self.reduced then 15 else 45) end
		if v then
			self:spark(Vector3.new(v.x, v.y + 3.5, 0), self:energy(event.attacker), 2.2)
			self.camera:punch(0.35, Vector3.new(v.x, v.y + 3.5, 0))
		end
		return
	end
	if event.kind == "Parry" then
		-- TARO's PARADE: a golden flash on the glove and a short stop. HIBECARES's MUR DE
		-- PIERRE: the blow breaks on stone (debris, dust).
		local position = Vector3.new(event.x, event.y, 0)
		if event.absorbed then
			self:debris(position - Vector3.new(0, 1.5, 0), self:energy(event.defender), 0.5)
			self:dust(event.x, 0, 1)
			self:spark(position, Color3.fromHex("B8A890"), 1.4)
		else
			self:spark(position, Color3.fromHex("FFD23F"), 1.6)
		end
		self:spark(position, self:energy(event.defender), 1)
		if rigs[event.defender] then self:flash(rigs[event.defender]) end
		self.camera:punch(if self.reduced then 0.08 else 0.18, position)
		return
	elseif event.kind == "Evade" then
		-- AKEMI's VOILE D'OMBRE: a shadow copy left where the hit was aimed.
		local rig = rigs[event.defender]
		if rig then
			self:afterimage(rig, self:energy(event.defender))
			if not self.reduced then task.delay(0.06, function() self:afterimage(rig, self:energy(event.defender)) end) end
		end
		local v = views[event.defender]
		if v then self:dust(v.x, 0, -v.facing) end
		return
	elseif event.kind == "Blink" then
		-- DAICHA's OMBRE INVERSÉE / TÉLÉPORTATION: a shadow copy where he was, a pool of
		-- shadow where he comes out.
		local color = self:energy(event.slot)
		if rigs[event.slot] then self:afterimage(rigs[event.slot], color) end
		self:arc(Vector3.new(event.x, 0.08, self.config.PlaneZ), 1.4, 0, 360, color, math.pi / 2, 1)
		self:spark(Vector3.new(event.x, 3, self.config.PlaneZ), Color3.fromHex("1A0B2E"), 0.9)
		return
	elseif event.kind == "Slip" then
		-- TARO's weave: the blow whistles over his head (a white arc above the ducking body).
		local v = views[event.defender]
		if v then
			local dir = if event.attacker and views[event.attacker] and views[event.attacker].x > v.x then -1 else 1
			self:arc(Vector3.new(v.x, v.y + 4.4, self.config.PlaneZ), 1.5, -30, 120, Color3.new(1, 1, 1), 0, dir)
		end
		return
	elseif event.kind == "Clash" then
		self:spark(Vector3.new(event.x, event.y, 0), WHITE, 2)
		self.camera:shake(if self.reduced then 0.15 else 0.35, 0.18)
		return
	elseif event.kind == "Skill" then
		local rig = rigs[event.attacker]
		if rig and rig.aura then rig.aura:Emit(if self.reduced then 8 else 24) end
		local v = views[event.attacker]
		if v then self.camera:punch(0.1, Vector3.new(v.x, v.y + 3.5, 0)) end
		return
	elseif event.kind == "Chilled" or event.kind == "Poison" or event.kind == "Heal" or event.kind == "Reflect"
		or event.kind == "Armor" or event.kind == "Shackled" or event.kind == "Domination" or event.kind == "Drone" then
		-- The third sheet's passives: a mark where it happened, in the element of the one who
		-- caused it (frost, poison, light, the mirror, the titan's anchor, the shackle, the
		-- eclipse, the drones).
		local slot = event.slot or event.defender
		local position = Vector3.new(event.x or 0, event.y or 3, 0)
		local colors = { Chilled = "9FE6FF", Poison = "7CFF4A", Heal = "FFE9A0", Reflect = "C8F0FF", Armor = "FF4A3A",
			Shackled = "FFB04A", Domination = "E0102E", Drone = "FF8A2A" }
		local color = Color3.fromHex(colors[event.kind])
		local verb = ({ Chilled = "iceShards", Poison = "toxicSplash", Heal = "halo", Reflect = "iceShards", Armor = "quake",
			Shackled = "clawMarks", Domination = "eclipseBurst", Drone = "glitch" })[event.kind]
		local accent = ({ Chilled = "DFF6FF", Poison = "7CFF4A", Heal = "FFE9A0", Reflect = "FFFFFF", Armor = "C9BFC0",
			Shackled = "E0E0E8", Domination = "0A0204", Drone = "6FE0FF" })[event.kind]
		HITS[verb](self, position, color, Color3.fromHex(accent), if event.kind == "Poison" then 0.6 else 1, 1)
		if event.kind == "Poison" and self.poisons and self.poisons[slot] then self.poisons[slot].tickAt = os.clock() end
		if event.kind == "Heal" or event.kind == "Chilled" then
			self:arc(Vector3.new(event.x or 0, 0.08, self.config.PlaneZ), 1.6, 0, 360, color, math.pi / 2, 1)
		elseif event.kind == "Armor" and rigs[slot] then
			self:flash(rigs[slot])
		end
		return
	elseif event.kind == "Burst" then
		-- BOSS BURST: a golden shockwave throws the attacker off the combo.
		local position = Vector3.new(event.x or 0, event.y or 3, 0)
		self:spark(position, Color3.fromHex("FFD23F"), 2)
		self:arc(Vector3.new(event.x or 0, 0.08, self.config.PlaneZ), 4, 0, 360, Color3.fromHex("FF7A2A"), math.pi / 2, 0.6)
		self.camera:shake(if self.reduced then 0.2 else 0.5, 0.3)
		return
	elseif event.kind == "Revive" then
		-- SECOND LIFE: a black shockwave where he rises.
		local position = Vector3.new(event.x or 0, event.y or 3, 0)
		self:spark(position, Color3.fromHex("B0102A"), 2.4)
		self:arc(Vector3.new(event.x or 0, 0.08, self.config.PlaneZ), 5, 0, 360, Color3.fromHex("1A0010"), math.pi / 2, 1)
		self.camera:shake(if self.reduced then 0.3 else 0.8, 0.5)
		return
	elseif event.kind == "Projectile" then
		local v = views[event.attacker]
		if v then self:spark(Vector3.new(v.x + v.facing * 1.8, v.y + 3.6, 0), self:energy(event.attacker), 0.8) end
		return
	end
	if event.kind == "Hit" or event.kind == "Block" or event.kind == "GuardBreak" then
		local attackerColor = self:energy(event.attacker)
		local position = Vector3.new(event.x, event.y, 0)
		-- ASURA's second pair of arms follows the blow: a second, golden impact just above.
		if event.arms then self:spark(position + Vector3.new(0, 0.7, 0), Color3.fromHex("FFD23F"), 1.3) end
		local m = MoveData.Moves[event.move]
		local shakeScale = if self.reduced then 0.4 else 1
		if event.kind == "Hit" then
			local heavy = event.heavy or event.ko
			self:spark(position, attackerColor, if heavy then 1.5 else 1)
			local attackerView = views[event.attacker]
			self:kitHit(event.move, position, attackerColor, heavy, if attackerView then attackerView.facing else 1)
			if event.tip then
				-- SHIN's PRÉCISION: the tip of the blade, one clean line through the hit.
				self:cut(position - Vector3.new(1.4, 0.5, 0), position + Vector3.new(1.4, 0.5, 0), attackerColor)
			end
			if rigs[event.defender] then self:flash(rigs[event.defender]) end
			self.camera:shake((if heavy then 0.5 else 0.18) * shakeScale, if heavy then 0.25 else 0.12)
			if heavy then
				self:impactFrame(attackerColor, if event.ko or event.cinematic then 2 else 1)
				self.camera:punch(if event.ko then 0.45 else 0.12, position)
			end
		else
			local defender = views[event.defender]
			local shieldColor = Color3.fromHex(CharacterData[event.defender].Shield)
			local model = rigs[event.defender] and rigs[event.defender].model
			local held = model and WeaponFX.KITS[model:GetAttribute("Kit") or ""]
			local steel = held and model:FindFirstChild("Kit" .. held.blade)
			if steel and defender and (defender.state == "Blockstun" or defender.state == "CrouchBlockstun"
				or defender.state == "Blocking" or defender.state == "CrouchBlocking") then
				-- A held weapon takes the blow (SHIN's katana over his head, KAZAN's crossed claws,
				-- RAIJIN's spear, YUKINA's fans): sparks off it where it lands, in its element
				-- (Wilhem's sheets: the blade meets the blow, a burst of sparks)
				local tone = BLOCK_SPARKS[held.element] or BLOCK_SPARKS.water
				local at = steel.Position:Lerp(steel.CFrame * Vector3.new(0, 0, -steel.Size.Z * 0.25), 0.5)
				self:spark(at, tone[1], 1.2)
				self:shards(at, tone[2], if self.reduced then 5 else 10, 0.55, tone[4] or Enum.Material.Neon, 0.22)
				self:shards(at, tone[3], if self.reduced then 3 else 6, 0.4, Enum.Material.Neon, 0.3)
			elseif defender then
				self:shield(defender, shieldColor)
			end
			if event.kind == "GuardBreak" then
				self:spark(position, Color3.fromHex("FFD23F"), 1.8)
				self:impactFrame(shieldColor, 1)
				self.camera:shake(0.5 * shakeScale, 0.3)
			else
				self.camera:shake(0.1 * shakeScale, 0.08)
			end
		end
		if m and m.launch > 0 and event.kind == "Hit" and views[event.defender] then
			self:dust(views[event.defender].x, 0, -views[event.attacker].facing)
		end
	end
end

-- Projectiles, extrapolated between snapshots, each in its thrower's element (KitFX.SHOTS):
-- KAI's ki blast, ZEPHYR's blade of wind, AKEMI's kunai, RYUKEN's quake along the floor,
-- SHIN's current, DAICHA's sphere, RAIJIN's bolt, YUKINA's shard, VENOM's cloud, ASTER's well,
-- HIBIKI's pulse, KUREN's lance, SYLVA's trap, NOVA's drones and shots, KUROEN's black sun.
-- A shot is a few parts placed round its centre (`pieces`: part, offset), turned to face
-- where it goes, maybe spinning, and leaving ghosts behind (`ghost`: none, ball or streak).
local SHOTS = {}
local function piece(self, list, size, offset, color, shape, material, transparency)
	local p = self:part(size, CFrame.identity, color, shape)
	if material then p.Material = material end
	if transparency then p.Transparency = transparency end
	table.insert(list, { part = p, offset = offset })
	return p
end
function SHOTS.ball(self, color, accent, scale)
	local list = {}
	piece(self, list, Vector3.one * 1.1 * scale, CFrame.identity, WHITE, Enum.PartType.Ball)
	piece(self, list, Vector3.one * 2 * scale, CFrame.identity, color, Enum.PartType.Ball, Enum.Material.ForceField, 0)
	return { pieces = list, ghost = "ball", pulse = 2 }
end
function SHOTS.crescent(self, color, accent, scale)
	local list = {}
	for i = -3, 3 do
		local a = i / 3 * 1.1
		piece(self, list, Vector3.new(0.3, 0.9, 0.12), CFrame.new(-math.cos(a) * 0.9 + 0.9, math.sin(a) * 1.6, 0) * CFrame.Angles(0, 0, -a),
			if i == 0 then WHITE else color, nil, nil, 0.15)
	end
	return { pieces = list, ghost = "streak" }
end
function SHOTS.kunai(self, color, accent, scale)
	local list = {}
	piece(self, list, Vector3.new(1.4, 0.12, 0.12), CFrame.identity, Color3.fromHex("1A1A22"), nil, Enum.Material.Metal)
	piece(self, list, Vector3.new(0.4, 0.3, 0.06), CFrame.new(0.8, 0, 0) * CFrame.Angles(0, 0, math.rad(45)), Color3.fromHex("C8C8D0"),
		nil, Enum.Material.Metal)
	piece(self, list, Vector3.new(1.6, 0.4, 0.4), CFrame.identity, color, nil, Enum.Material.ForceField, 0)
	return { pieces = list, ghost = "streak" }
end
function SHOTS.wave(self, color, accent, scale)
	local list = {}
	for i = 0, 2 do
		piece(self, list, Vector3.new(0.6, 0.9 + i * 0.35, 1.2), CFrame.new(-i * 0.5, -0.4 + i * 0.15, 0) * CFrame.Angles(0, 0, math.rad(-20)),
			if i == 0 then color else STONE, nil, if i == 0 then nil else Enum.Material.Slate)
	end
	return { pieces = list, ghost = "crack" }
end
-- SHIN's COURANT TRANCHANT (S + E): a crescent of water cut off his blade, its belly forward,
-- thick in the middle and thinning to two points: a white core, the water around it (glass),
-- his ki around that; it sheds mist, after-images of its water and droplets that fall.
function SHOTS.slash(self, color, accent, scale)
	local list, after = {}, {}
	local R, n = 1.75 * scale, 4
	local function arc(i, width, depth, lengthScale, partColor, material, transparency)
		local a = i / n * 1.05
		local w = width * (1 - math.abs(i) / (n + 1.2))
		local at = CFrame.new(math.cos(a) * R - R + 0.35, math.sin(a) * R, 0) * CFrame.Angles(0, 0, a)
		return piece(self, list, Vector3.new(w, R * 1.05 / n * lengthScale, depth), at, partColor, nil, material, transparency)
	end
	-- (the middle of the core first: it carries the light and the mist)
	local core = arc(0, 0.16, 0.1, 1.15, WHITE, Enum.Material.Neon)
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color, mist.LightEmission = ColorSequence.new(accent, color), 0.5
	mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.2) })
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	mist.Lifetime, mist.Speed, mist.Rate = NumberRange.new(0.25, 0.45), NumberRange.new(0.5, 1.5), if self.reduced then 12 else 30
	mist.SpreadAngle, mist.Parent = Vector2.new(180, 180), core
	for i = -n, n do
		if i ~= 0 then arc(i, 0.16, 0.1, 1.15, WHITE, Enum.Material.Neon) end
	end
	for i = -n, n do
		local water = arc(i, 0.5, 0.3, 1.12, accent, Enum.Material.Glass, 0.3)
		if i % 2 == 0 then table.insert(after, list[#list]) end
		water.Reflectance = 0.2
	end
	if not self.reduced then
		for i = -n + 1, n - 1 do arc(i, 0.85, 0.5, 1.2, color, Enum.Material.ForceField, 0) end
	end
	return { pieces = list, ghost = "current", after = after }
end
function SHOTS.sphere(self, color, accent, scale)
	local list = {}
	piece(self, list, Vector3.one * 1.8 * scale, CFrame.identity, Color3.fromHex("0B0712"), Enum.PartType.Ball, Enum.Material.SmoothPlastic)
	piece(self, list, Vector3.one * 2.6 * scale, CFrame.identity, color, Enum.PartType.Ball, Enum.Material.ForceField, 0)
	piece(self, list, Vector3.new(0.06, 3.4, 3.4) * scale, CFrame.Angles(0, math.pi / 2, 0.4), color, Enum.PartType.Cylinder, nil, 0.3)
	return { pieces = list, ghost = "ball", spin = 3 }
end
function SHOTS.bolt(self, color, accent, scale)
	local list = {}
	piece(self, list, Vector3.new(1.8, 0.25, 0.25), CFrame.identity, WHITE)
	piece(self, list, Vector3.new(2.2, 0.7, 0.7), CFrame.identity, accent, nil, Enum.Material.ForceField, 0)
	return { pieces = list, ghost = "bolt" }
end
function SHOTS.shard(self, color, accent, scale)
	local list = {}
	piece(self, list, Vector3.new(1.6, 0.4, 0.4), CFrame.Angles(math.rad(45), 0, 0), accent, nil, Enum.Material.Ice, 0.1)
	piece(self, list, Vector3.new(0.9, 0.6, 0.6), CFrame.new(-0.3, 0, 0) * CFrame.Angles(math.rad(45), 0, 0), color, nil, Enum.Material.Ice, 0.2)
	return { pieces = list, ghost = "streak", spin = 0, roll = 8 }
end
-- VENOM's BRUME TOXIQUE (S + E): a slow, rolling cloud of poison: a dark core, swollen green
-- lobes round it, a thick green smoke boiling off it and bubbles that rise and pop; drips
-- fall from it as it goes.
function SHOTS.cloud(self, color, accent, scale)
	local list = {}
	local core = piece(self, list, Vector3.one * 1.3 * scale, CFrame.identity, Color3.fromHex("1E4A0E"), Enum.PartType.Ball,
		Enum.Material.SmoothPlastic, 0.2)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		piece(self, list, Vector3.one * (1.1 + (i % 3) * 0.25) * scale, CFrame.new(math.cos(a) * 0.75, math.sin(a) * 0.6, (i % 2) * 0.3 - 0.15),
			if i % 2 == 0 then accent else color, Enum.PartType.Ball, Enum.Material.SmoothPlastic, 0.4)
	end
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromHex("7CFF4A"), Color3.fromHex("2E7D12"))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3.2) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime, smoke.Speed, smoke.Rate = NumberRange.new(0.6, 1.1), NumberRange.new(0.4, 1.2), if self.reduced then 10 else 24
	smoke.RotSpeed, smoke.SpreadAngle = NumberRange.new(-60, 60), Vector2.new(180, 180)
	smoke.Parent = core
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	bubbles.Color, bubbles.LightEmission = ColorSequence.new(Color3.fromHex("B6FF8A")), 0.7
	bubbles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.8, 0.45), NumberSequenceKeypoint.new(1, 0) })
	bubbles.Lifetime, bubbles.Speed, bubbles.Rate = NumberRange.new(0.4, 0.8), NumberRange.new(1.5, 3), if self.reduced then 6 else 14
	bubbles.Acceleration, bubbles.SpreadAngle = Vector3.new(0, 3, 0), Vector2.new(60, 60)
	bubbles.EmissionDirection = Enum.NormalId.Top
	bubbles.Parent = core
	return { pieces = list, ghost = "drip", spin = 1.2 }
end
function SHOTS.well(self, color, accent, scale)
	local list = {}
	piece(self, list, Vector3.one * 0.9 * scale, CFrame.identity, Color3.fromHex("07040C"), Enum.PartType.Ball, Enum.Material.SmoothPlastic)
	piece(self, list, Vector3.new(0.06, 2.6, 2.6) * scale, CFrame.Angles(0, math.pi / 2, 0), accent, Enum.PartType.Cylinder, Enum.Material.ForceField)
	piece(self, list, Vector3.new(0.06, 2, 2) * scale, CFrame.Angles(0.9, math.pi / 2, 0), color, Enum.PartType.Cylinder, Enum.Material.ForceField)
	return { pieces = list, ghost = "none", spin = 5 }
end
function SHOTS.pulse(self, color, accent, scale)
	local list = {}
	for i = 0, 2 do
		local size = 3.2 - i * 0.8
		piece(self, list, Vector3.new(0.08, size, size), CFrame.new(-i * 0.6, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), if i == 1 then accent else color,
			Enum.PartType.Cylinder, nil, 0.2 + i * 0.2)
	end
	return { pieces = list, ghost = "none", pulse = 6 }
end
function SHOTS.lance(self, color, accent, scale)
	local list = {}
	piece(self, list, Vector3.new(3.4, 0.18, 0.18), CFrame.identity, accent, nil, Enum.Material.SmoothPlastic)
	piece(self, list, Vector3.new(3.6, 0.5, 0.5), CFrame.identity, color, nil, nil, 0.35)
	piece(self, list, Vector3.new(0.7, 0.35, 0.35), CFrame.new(1.9, 0, 0) * CFrame.Angles(math.rad(45), 0, 0), WHITE)
	return { pieces = list, ghost = "drip" }
end
function SHOTS.trap(self, color, accent, scale)
	local list = {}
	piece(self, list, Vector3.new(0.2, 2.6, 2.6), CFrame.Angles(0, 0, math.pi / 2), color, Enum.PartType.Cylinder, Enum.Material.ForceField, 0)
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		piece(self, list, Vector3.new(0.18, 0.9, 0.18), CFrame.new(math.cos(a) * 1, 0.3, math.sin(a) * 1) * CFrame.Angles(math.cos(a) * 0.5, 0, -math.sin(a) * 0.5),
			accent, nil, Enum.Material.LeafyGrass)
	end
	return { pieces = list, ghost = "none", still = true, flat = true }
end
function SHOTS.drone(self, color, accent, scale)
	local list = {}
	piece(self, list, Vector3.new(0.9, 0.35, 0.7), CFrame.identity, Color3.fromHex("5A5A66"), nil, Enum.Material.Metal)
	piece(self, list, Vector3.new(1.4, 0.06, 0.25), CFrame.new(0, 0.25, 0), Color3.fromHex("2A2A33"), nil, Enum.Material.Metal)
	piece(self, list, Vector3.one * 0.22, CFrame.new(0.46, 0, 0), color, Enum.PartType.Ball)
	return { pieces = list, ghost = "none", still = true, hover = true }
end
function SHOTS.bullet(self, color, accent, scale)
	local list = {}
	piece(self, list, Vector3.new(0.9, 0.22, 0.22), CFrame.identity, WHITE)
	piece(self, list, Vector3.new(1.3, 0.45, 0.45), CFrame.identity, color, nil, nil, 0.3)
	return { pieces = list, ghost = "streak" }
end
function SHOTS.eclipse(self, color, accent, scale)
	local list = {}
	piece(self, list, Vector3.one * 1.2 * scale, CFrame.new(0, 0, 0.1), Color3.fromHex("07040C"), Enum.PartType.Ball, Enum.Material.SmoothPlastic)
	piece(self, list, Vector3.one * 1.8 * scale, CFrame.identity, color, Enum.PartType.Ball, nil, 0.3)
	return { pieces = list, ghost = "ball", pulse = 3 }
end
for name in KitFX.SHOTS do assert(SHOTS[name], "KitFX shot without a drawing: " .. name) end

function EffectsController:updateProjectiles(list, ahead, now)
	self.projectiles = self.projectiles or {}
	local alive = {}
	for _, p in list or {} do
		alive[p.id] = true
		local visual = self.projectiles[p.id]
		if not visual then
			local color = self:energy(p.owner)
			local fx = KitFX.of(p.move and MoveData.MoveKit[p.move] or CharacterData[p.owner].Kit)
			local kind = if p.drone then "drone" elseif p.trap then "trap" else fx.shot
			visual = SHOTS[kind](self, color, Color3.fromHex(fx.accent), 1)
			visual.color, visual.accent, visual.trail, visual.born = color, Color3.fromHex(fx.accent), 0, now
			local light = Instance.new("PointLight")
			light.Color, light.Range, light.Brightness = color, 12, if p.drone then 1 else 3
			light.Parent = visual.pieces[1].part
			self.projectiles[p.id] = visual
		end
		local dir = if (p.vx or 0) < 0 then -1 else 1
		visual.dir = if p.vx and p.vx ~= 0 then dir else (visual.dir or 1)
		local y = if visual.flat then 0.15 elseif visual.hover then p.y + math.sin(now * 6) * 0.15 else p.y
		local position = Vector3.new(p.x + (p.vx or 0) * ahead, y, if visual.flat then self.config.PlaneZ else 0.4)
		visual.at = position
		local base = CFrame.new(position) * (if visual.dir < 0 then CFrame.Angles(0, math.pi, 0) else CFrame.identity)
		local turn = if visual.roll then CFrame.Angles(visual.roll * now, 0, 0) else CFrame.identity
		local spin = if visual.spin then CFrame.Angles(0, 0, now * visual.spin) else CFrame.identity
		local pulse = if visual.pulse then 1 + 0.06 * visual.pulse * math.sin(now * 40) else 1
		for i, entry in visual.pieces do
			local placed = base * turn * spin * entry.offset
			if pulse ~= 1 and i == #visual.pieces then -- (the outer shell breathes)
				entry.size = entry.size or entry.part.Size
				entry.part.Size = entry.size * pulse
			end
			entry.part.CFrame = placed
		end
		if not visual.still and visual.ghost ~= "none" and now - visual.trail > (if self.reduced then 0.06 else 0.03) then
			visual.trail = now
			if visual.ghost == "ball" then
				local ghost = self:part(Vector3.one * 1.3, CFrame.new(position), visual.color, Enum.PartType.Ball)
				ghost.Transparency = 0.4
				tween(ghost, 0.2, { Transparency = 1, Size = Vector3.one * 0.3 })
				Debris:AddItem(ghost, 0.22)
			elseif visual.ghost == "streak" then
				local ghost = self:part(Vector3.new(1.6, 0.12, 0.12), CFrame.new(position - Vector3.new(visual.dir * 1.2, 0, 0)), visual.color)
				ghost.Transparency = 0.3
				tween(ghost, 0.16, { Transparency = 1, Size = Vector3.new(0.4, 0.04, 0.04) })
				Debris:AddItem(ghost, 0.18)
			elseif visual.ghost == "bolt" then
				if math.random() < 0.5 then
					self:lightning(position, position - Vector3.new(visual.dir * 2.2, (math.random() - 0.5) * 1.2, 0), visual.color)
				end
			elseif visual.ghost == "crack" then
				local floor = Vector3.new(position.X, 0.05, self.config.PlaneZ)
				local seg = self:part(Vector3.new(0.9, 0.05, 0.3), CFrame.new(floor), visual.color)
				tween(seg, 0.8, { Transparency = 1 })
				Debris:AddItem(seg, 0.85)
			elseif visual.ghost == "current" then
				-- (SHIN's crescent: its water left behind a moment, and droplets falling off it)
				for _, entry in visual.after do
					local ghost = self:part(entry.part.Size, entry.part.CFrame, visual.accent)
					ghost.Material, ghost.Transparency = Enum.Material.Glass, 0.55
					tween(ghost, 0.22, { Transparency = 1, Size = entry.part.Size * Vector3.new(0.3, 1, 0.3) })
					Debris:AddItem(ghost, 0.24)
				end
				if math.random() < 0.4 then
					self:drops(position + Vector3.new(-visual.dir * 0.6, (math.random() - 0.5) * 2.4, 0), visual.accent, 1, 0.8, 3)
				end
			elseif visual.ghost == "drip" then
				if math.random() < 0.35 then self:drops(position, visual.accent, 1, 0.8, 2) end
			end
		end
	end
	for id, visual in self.projectiles do
		if not alive[id] then
			-- (SHIN's crescent bursts into spray where it ends)
			if visual.ghost == "current" and visual.at then self:drops(visual.at, visual.accent, 7, 1, 10) end
			for _, entry in visual.pieces do entry.part:Destroy() end
			self.projectiles[id] = nil
		end
	end
end

-- ===================================================================== cinematic props

-- Flat ring of ki climbing around a spinning fighter.
function EffectsController:tornadoRing(position, color)
	local ring = self:part(Vector3.new(0.25, 5, 5), CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2), color, Enum.PartType.Cylinder)
	ring.Material, ring.Transparency = Enum.Material.ForceField, 0
	tween(ring, 0.5, { Size = Vector3.new(0.25, 9, 9), CFrame = ring.CFrame + Vector3.new(0, 3.5, 0), Transparency = 1 })
	Debris:AddItem(ring, 0.55)
end

-- A dragon of ki spiralling up from the floor.
function EffectsController:dragonHelix(position, color)
	local count = if self.reduced then 14 else 30
	for i = 0, count - 1 do
		task.delay(i * 0.018, function()
			local angle = i * 0.55
			local height = i * 0.55
			local size = 1.8 - i / count
			local ball = self:part(Vector3.one * size, CFrame.new(position + Vector3.new(math.cos(angle) * 2.6, height, math.sin(angle) * 2.6)),
				if i % 4 == 0 then WHITE else color, Enum.PartType.Ball)
			ball.Transparency = 0.1
			tween(ball, 0.45, { Transparency = 1, Size = Vector3.one * 0.2 })
			Debris:AddItem(ball, 0.5)
		end)
	end
end

-- Zigzag lightning bolt between two points.
function EffectsController:lightning(from, to, color)
	local points = { from }
	local segments = 7
	for i = 1, segments - 1 do
		local t = i / segments
		local jitter = Vector3.new((math.random() - 0.5) * 2.4, (math.random() - 0.5) * 1.2, (math.random() - 0.5) * 1.2)
		table.insert(points, from:Lerp(to, t) + jitter)
	end
	table.insert(points, to)
	for i = 1, #points - 1 do
		local p0, p1 = points[i], points[i + 1]
		local bolt = self:part(Vector3.new(0.22, 0.22, (p1 - p0).Magnitude), CFrame.lookAt((p0 + p1) / 2, p1), if i % 2 == 0 then WHITE else color)
		tween(bolt, 0.16, { Transparency = 1 })
		Debris:AddItem(bolt, 0.18)
	end
	local flash = self:part(Vector3.one * 0.5, CFrame.new(to), WHITE, Enum.PartType.Ball)
	flash.Transparency = 1
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = color, 30, 6
	light.Parent = flash
	Debris:AddItem(flash, 0.12)
end

-- Giant crescent moon hanging in the sky behind the fighters. Returns it for cleanup.
function EffectsController:crescent(center, color)
	local model = Instance.new("Model")
	model.Name, model.Parent = "Crescent", self.folder
	local segments = 18
	for i = 0, segments - 1 do
		local a0 = math.rad(-120 + 240 * i / segments)
		local a1 = math.rad(-120 + 240 * (i + 1) / segments)
		local thickness = 0.4 + 2.2 * math.sin(math.pi * (i + 0.5) / segments)
		local radius = 9 - thickness / 2
		local p0 = center + Vector3.new(math.cos(a0) * radius, math.sin(a0) * radius, 0)
		local p1 = center + Vector3.new(math.cos(a1) * radius, math.sin(a1) * radius, 0)
		local piece = self:part(Vector3.new(thickness, 0.4, (p1 - p0).Magnitude + 0.2), CFrame.lookAt((p0 + p1) / 2, p1, Vector3.zAxis), color)
		piece.Transparency, piece.Parent = 1, model
		tween(piece, 0.5, { Transparency = 0.05 })
	end
	local glow = Instance.new("PointLight")
	glow.Color, glow.Range, glow.Brightness = color, 40, 2
	glow.Parent = model:FindFirstChildWhichIsA("BasePart")
	return model
end

-- Burning seal on the floor with the character's kanji. Returns it for cleanup.
function EffectsController:kanjiSeal(center, color, kanji)
	local model = Instance.new("Model")
	model.Name, model.Parent = "Seal", self.folder
	local disc = self:part(Vector3.new(0.05, 2, 2), CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2), color, Enum.PartType.Cylinder)
	disc.Transparency, disc.Parent = 0.55, model
	tween(disc, 0.6, { Size = Vector3.new(0.05, 30, 30) }, Enum.EasingStyle.Back)
	local ring = self:part(Vector3.new(0.08, 2, 2), CFrame.new(center + Vector3.new(0, 0.02, 0)) * CFrame.Angles(0, 0, math.pi / 2), WHITE, Enum.PartType.Cylinder)
	ring.Material, ring.Transparency, ring.Parent = Enum.Material.ForceField, 0, model
	tween(ring, 0.6, { Size = Vector3.new(0.08, 31, 31) }, Enum.EasingStyle.Back)
	local plate = self:part(Vector3.new(18, 0.05, 18), CFrame.new(center + Vector3.new(0, 0.04, 0)), color)
	plate.Transparency, plate.Parent = 1, model
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.LightInfluence, gui.CanvasSize = Enum.NormalId.Top, 0, Vector2.new(400, 400)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency, label.Size, label.Text = 1, UDim2.fromScale(1, 1), kanji
	label.TextScaled, label.Font, label.TextColor3, label.TextTransparency = true, Enum.Font.GothamBlack, WHITE, 1
	label.Parent = gui
	gui.Parent = plate
	tween(label, 0.5, { TextTransparency = 0 })
	return model
end

-- Giant torii rising from the floor. Its portal lights up with gateOpen. Returns the model.
function EffectsController:gate(base, dir, color)
	local model = Instance.new("Model")
	model.Name, model.Parent = "HeavenGate", self.folder
	local red, ink = Color3.fromHex("C8102E"), Color3.fromHex("0B0B0E")
	local function piece(size, offset, partColor, material)
		local p = self:part(size, CFrame.new(base + offset - Vector3.new(0, 30, 0)), partColor)
		p.Material = material or Enum.Material.SmoothPlastic
		p.Parent = model
		tween(p, 1.2, { CFrame = CFrame.new(base + offset) }, Enum.EasingStyle.Quart)
		return p
	end
	-- The opening faces the fight axis (X), pillars on each side along Z.
	piece(Vector3.new(2.4, 26, 2.4), Vector3.new(0, 13, -6), red)
	piece(Vector3.new(2.4, 26, 2.4), Vector3.new(0, 13, 6), red)
	piece(Vector3.new(2, 1.6, 18), Vector3.new(0, 19, 0), red)
	piece(Vector3.new(3, 2.2, 22), Vector3.new(0, 25, 0), ink)
	piece(Vector3.new(2.6, 1.4, 20), Vector3.new(0, 23.4, 0), red)
	local portal = piece(Vector3.new(0.3, 18, 10), Vector3.new(dir * 0.4, 9.5, 0), color, Enum.Material.Neon)
	portal.Name, portal.Transparency = "Portal", 1
	return model
end

function EffectsController:gateOpen(gate)
	local portal = gate and gate:FindFirstChild("Portal")
	if not portal then return end
	tween(portal, 0.8, { Transparency = 0.1 })
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = portal.Color, 50, 5
	light.Parent = portal
end

-- The gate bursts apart: every piece flies away (client-side physics only).
function EffectsController:gateShatter(gate, color)
	if not gate then return end
	for _, p in gate:GetChildren() do
		if p:IsA("BasePart") then
			if p.Name == "Portal" then
				tween(p, 0.2, { Transparency = 1, Size = p.Size * 1.6 })
			else
				p.Anchored = false
				p.AssemblyLinearVelocity = Vector3.new((math.random() - 0.5) * 60, 30 + math.random() * 30, (math.random() - 0.5) * 60)
				p.AssemblyAngularVelocity = Vector3.new(math.random() * 6, math.random() * 6, math.random() * 6)
			end
		end
	end
	self:spark(gate:GetPivot().Position + Vector3.new(0, 8, 0), color, 4)
	Debris:AddItem(gate, 3)
end

-- What grows out of the floor: HIBECARES' stone only; the other kits raise their own matter
-- (Wilhem: no stone where the power has nothing to do with it). thin / tall scale the
-- pillars, tilt their lean (iron bars stand straight, roots twist).
local MATTER = {
	stone = { material = Enum.Material.Slate, color = Color3.fromHex("6E6258"), thin = 1, tall = 1, tilt = 1 },
	ice = { material = Enum.Material.Ice, color = Color3.fromHex("BFE6FF"), thin = 0.55, tall = 1.25, tilt = 0.7, clear = 0.15 },
	wood = { material = Enum.Material.Wood, color = Color3.fromHex("5A3B22"), thin = 0.42, tall = 1.1, tilt = 2.4 },
	thorn = { material = Enum.Material.LeafyGrass, color = Color3.fromHex("3F6B2A"), thin = 0.3, tall = 0.9, tilt = 1.8 },
	iron = { material = Enum.Material.Metal, color = Color3.fromHex("5A5F69"), thin = 0.26, tall = 1.4, tilt = 0 },
}
EffectsController.MATTER = MATTER

local function shape(self, part, matter)
	part.Material = matter.material
	if matter.clear then part.Transparency = matter.clear end
	if matter.material == Enum.Material.Ice then part.Reflectance = 0.2 end
end

-- Pillars of `matter` (stone by default: HIBECARES) bursting out of the floor on the far half
-- of a ring around `center` (the near half would hide the fighters). Returns the model.
function EffectsController:rocks(center, radius, count, color, life, matterName)
	local matter = MATTER[matterName or "stone"] or MATTER.stone
	local model = Instance.new("Model")
	model.Name, model.Parent = "Rocks", self.folder
	local stone = matter.color
	count = if self.reduced then math.max(3, count // 2) else count
	for i = 1, count do
		local angle = math.pi * (i - 0.5) / count
		local height = (3 + ((i * 37) % 7) * 0.7) * matter.tall
		local width = (1.2 + ((i * 13) % 5) * 0.25) * matter.thin
		local base = center + Vector3.new(math.cos(angle) * radius, 0, -math.sin(angle) * radius)
		local lean = matter.tilt
		local tilt = CFrame.Angles(math.rad(((i * 17) % 21 - 10) * lean), math.rad(i * 47), math.rad(((i * 29) % 19 - 9) * lean))
		local final = CFrame.new(base + Vector3.new(0, height / 2 - 0.3, 0)) * tilt
		local rock = self:part(Vector3.new(width, height, width * 0.9), final - Vector3.new(0, height, 0), stone)
		shape(self, rock, matter)
		rock.Parent = model
		tween(rock, 0.25, { CFrame = final }, Enum.EasingStyle.Back)
		local glow = self:part(Vector3.new(width * 1.6, 0.08, width * 1.6), CFrame.new(base + Vector3.new(0, 0.06, 0)), color)
		glow.Transparency, glow.Parent = 0.3, model
		tween(glow, 0.8, { Transparency = 1 })
	end
	if matter == MATTER.stone then
		self:dust(center.X, 0, 1)
		self:dust(center.X, 0, -1)
	end
	if life then self:sink(model, life) end
	return model
end

-- Pillars of a model sinking back into the floor after `life` seconds, then gone.
function EffectsController:sink(model, life)
	task.delay(life, function()
		for _, part in model:GetChildren() do
			if part:IsA("BasePart") then
				tween(part, 0.35, { CFrame = part.CFrame - Vector3.new(0, part.Size.Y, 0), Transparency = 1 }, Enum.EasingStyle.Quad)
			end
		end
		Debris:AddItem(model, 0.4)
	end)
end

-- HIBECARES: stone pillars erupting one after the other along a line of the floor (a quake
-- running to the target), sinking back after `life` seconds.
function EffectsController:rockLine(from, to, count, color, life, matterName)
	local matter = MATTER[matterName or "stone"] or MATTER.stone
	local model = Instance.new("Model")
	model.Name, model.Parent = "RockLine", self.folder
	local stone = matter.color
	for i = 1, count do
		task.delay((i - 1) * 0.05, function()
			if not model.Parent then return end
			local base = from:Lerp(to, (i - 0.5) / count)
			local height = (2 + 3.2 * i / count) * matter.tall
			local width = (1.1 + (i % 3) * 0.25) * matter.thin
			local final = CFrame.new(base + Vector3.new(0, height / 2 - 0.3, 0)) * CFrame.Angles(math.rad(((i * 23) % 17 - 8) * matter.tilt),
				math.rad(i * 61), math.rad(((i * 31) % 15 - 7) * matter.tilt))
			local rock = self:part(Vector3.new(width, height, width * 0.9), final - Vector3.new(0, height, 0), stone)
			shape(self, rock, matter)
			rock.Parent = model
			tween(rock, 0.16, { CFrame = final }, Enum.EasingStyle.Back)
			local glow = self:part(Vector3.new(width * 1.6, 0.08, width * 1.6), CFrame.new(base + Vector3.new(0, 0.06, 0)), color)
			glow.Transparency, glow.Parent = 0.3, model
			tween(glow, 0.6, { Transparency = 1 })
		end)
	end
	self:sink(model, (life or 1) + count * 0.05)
	return model
end

-- RYUKEN: a giant fist of ki (forearm, fist, four knuckles) thrown from `from` to `to`, then
-- fading out where it struck.
function EffectsController:rageFist(from, to, color, scale)
	local travel = to - from
	if travel.Magnitude < 1e-3 then return end
	local look = CFrame.lookAt(from, to)
	local pieces = {
		self:part(Vector3.new(1.5, 1.5, 3.4) * scale, look * CFrame.new(0, 0, 2.6 * scale), color), -- forearm
		self:part(Vector3.new(2.2, 2, 1.8) * scale, look, color), -- fist
	}
	for i = 1, 4 do
		table.insert(pieces, self:part(Vector3.new(0.5, 0.42, 0.5) * scale,
			look * CFrame.new((i - 2.5) * 0.52 * scale, 0.55 * scale, -1 * scale), WHITE))
	end
	for _, piece in pieces do
		piece.Transparency = 0.25
		tween(piece, 0.18, { CFrame = piece.CFrame + travel }, Enum.EasingStyle.Quart)
		task.delay(0.22, function()
			if piece.Parent then tween(piece, 0.45, { Transparency = 1, Size = piece.Size * 1.3 }) end
		end)
		Debris:AddItem(piece, 0.75)
	end
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = color, 26, 5
	light.Parent = pieces[2]
end

-- DAICHA: `count` orbs of shadow circling `center` on a ring of `radius` tilted by `tilt`
-- radians, `spin` turns per second from the turn `phase`, for `life` seconds (the director's
-- crownAt gives the same places). Returns them for cleanup.
function EffectsController:orbs(center, radius, count, color, life, spin, phase, tilt)
	local model = Instance.new("Model")
	model.Name, model.Parent = "Orbs", self.folder
	local balls = {}
	for i = 1, count do
		local core = self:part(Vector3.one * 0.9, CFrame.new(center), Color3.fromHex("0B0712"), Enum.PartType.Ball)
		core.Material, core.Parent = Enum.Material.SmoothPlastic, model
		local halo = self:part(Vector3.one * 1.35, CFrame.new(center), color, Enum.PartType.Ball)
		halo.Material, halo.Transparency, halo.Parent = Enum.Material.ForceField, 0, model
		balls[i] = { core, halo }
	end
	local start = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local t = os.clock() - start
		if t > life or not model.Parent then
			connection:Disconnect()
			model:Destroy()
			return
		end
		for i, ball in balls do
			local angle = (phase + spin * t + (i - 1) / count) * math.pi * 2
			local spot = center + Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius * math.sin(tilt),
				math.sin(angle) * radius * math.cos(tilt))
			ball[1].CFrame, ball[2].CFrame = CFrame.new(spot), CFrame.new(spot)
		end
	end)
	return model
end

-- KAI: a beam of ki from `from` down to `to` (a white core in a coloured sheath that swells
-- then thins out).
function EffectsController:kiBeam(from, to, color, scale)
	local length = (to - from).Magnitude
	if length < 1e-3 then return end
	local placed = CFrame.lookAt((from + to) / 2, to)
	local sheath = self:part(Vector3.new(1.6 * scale, 1.6 * scale, length), placed, color)
	sheath.Transparency = 0.2
	local core = self:part(Vector3.new(0.6 * scale, 0.6 * scale, length), placed, WHITE)
	for _, p in { sheath, core } do
		tween(p, 0.12, { Size = Vector3.new(p.Size.X * 1.6, p.Size.Y * 1.6, length) })
		task.delay(0.35, function()
			if p.Parent then tween(p, 0.3, { Size = Vector3.new(0.05, 0.05, length), Transparency = 1 }) end
		end)
		Debris:AddItem(p, 0.7)
	end
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = color, 30, 6
	light.Parent = core
end

-- ZEPHYR: a crescent blade of wind flying from `from` to `to` (tilted by `tilt` radians).
function EffectsController:windBlade(from, to, color, tilt, scale)
	local travel = to - from
	if travel.Magnitude < 1e-3 then return end
	local look = CFrame.lookAt(from, to) * CFrame.Angles(0, 0, tilt)
	local pieces = {}
	for i = -3, 3 do
		local angle = i / 3 * 1.1
		local spot = look * CFrame.new(math.sin(angle) * 1.6 * scale, 0, -math.cos(angle) * 0.9 * scale + 0.9 * scale)
		local piece = self:part(Vector3.new(0.9 * scale, 0.12, 0.3), spot * CFrame.Angles(0, -angle, 0), if i == 0 then WHITE else color)
		piece.Transparency = 0.15
		table.insert(pieces, piece)
	end
	local time = math.clamp(travel.Magnitude / 60, 0.08, 0.25)
	for _, piece in pieces do
		tween(piece, time, { CFrame = piece.CFrame + travel }, Enum.EasingStyle.Linear)
		task.delay(time, function()
			if piece.Parent then tween(piece, 0.2, { Transparency = 1, Size = piece.Size * 1.4 }) end
		end)
		Debris:AddItem(piece, time + 0.25)
	end
end

-- TARO: the ropes of the ring, three lines of fire from `from` to `to` (on the floor), for
-- `life` seconds. Returns them for cleanup.
function EffectsController:ropes(from, to, color, life)
	local model = Instance.new("Model")
	model.Name, model.Parent = "Ropes", self.folder
	local length = (to - from).Magnitude
	if length < 1e-3 then return model end
	for i = 1, 3 do
		local lift = Vector3.new(0, 1.2 + i * 1.1, 0)
		local rope = self:part(Vector3.new(0.18, 0.18, length), CFrame.lookAt((from + to) / 2 + lift, to + lift), color)
		rope.Transparency, rope.Parent = 1, model
		tween(rope, 0.3, { Transparency = 0.1 })
	end
	Debris:AddItem(model, life)
	return model
end

-- AKEMI: her shadow left standing where she struck: a dark copy of the rig of `slot`, kept
-- `life` seconds. Returns it for cleanup.
function EffectsController:shadowCopy(slot, color, life)
	local rig = self.rigs[slot]
	if not rig or not rig.model then return nil end
	local model = Instance.new("Model")
	model.Name, model.Parent = "ShadowCopy", self.folder
	for _, p in rig.model:GetChildren() do
		if p:IsA("BasePart") and BODY_PARTS[p.Name] then
			local ghost = self:part(p.Size, p.CFrame, Color3.fromHex("140A1E"))
			ghost.Material, ghost.Transparency, ghost.Parent = Enum.Material.SmoothPlastic, 0.25, model
		end
	end
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = color, 8, 1.5
	light.Parent = model:FindFirstChildWhichIsA("BasePart")
	task.delay(math.max(0, life - 0.2), function()
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") then tween(p, 0.2, { Transparency = 1 }) end
		end
	end)
	Debris:AddItem(model, life)
	return model
end

-- DAICHA: one orb of shadow darting from `from` into `to`, a violet streak behind it.
function EffectsController:orbDart(from, to, color)
	local length = (to - from).Magnitude
	if length < 1e-3 then return end
	local orb = self:part(Vector3.one, CFrame.new(from), Color3.fromHex("0B0712"), Enum.PartType.Ball)
	orb.Material = Enum.Material.SmoothPlastic
	tween(orb, 0.09, { CFrame = CFrame.new(to) }, Enum.EasingStyle.Linear)
	Debris:AddItem(orb, 0.1)
	local streak = self:part(Vector3.new(0.4, 0.4, length), CFrame.lookAt((from + to) / 2, to), color)
	streak.Transparency = 0.3
	tween(streak, 0.25, { Size = Vector3.new(0.05, 0.05, length), Transparency = 1 })
	Debris:AddItem(streak, 0.3)
	task.delay(0.09, function() self:spark(to, color, 0.6) end)
end

-- SHIN: the water his steps leave on the deck, a smooth glowing stroke fading in `life` s.
function EffectsController:wake(from, to, color, life)
	local length = (to - from).Magnitude
	if length < 1e-3 then return end
	local stroke = self:part(Vector3.new(0.7, 0.06, length + 0.3), CFrame.lookAt((from + to) / 2, to), color)
	stroke.Transparency = 0.25
	tween(stroke, life, { Size = Vector3.new(0.15, 0.06, length + 0.3), Transparency = 1 })
	Debris:AddItem(stroke, life + 0.05)
end

-- SHIN: a column of water rising and spinning from the floor for `life` seconds (a clear core,
-- rings climbing it). Returns it for cleanup.
function EffectsController:waterspout(base, radius, height, color, life)
	local model = Instance.new("Model")
	model.Name, model.Parent = "Waterspout", self.folder
	local upright = CFrame.Angles(0, 0, math.pi / 2)
	local core = self:part(Vector3.new(0.4, radius * 2, radius * 2), CFrame.new(base) * upright, color, Enum.PartType.Cylinder)
	core.Material, core.Transparency, core.Parent = Enum.Material.ForceField, 0, model
	tween(core, 0.4, { Size = Vector3.new(height, radius * 2, radius * 2), CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * upright })
	local waves = math.max(1, math.floor(life / 0.12))
	for w = 0, waves - 1 do
		task.delay(w * 0.12, function()
			if not model.Parent then return end
			local y = (w % 8) / 8 * height
			local ring = self:part(Vector3.new(0.2, radius * 2.2, radius * 2.2), CFrame.new(base + Vector3.new(0, y, 0)) * upright,
				if w % 3 == 0 then WHITE else color, Enum.PartType.Cylinder)
			ring.Material, ring.Transparency, ring.Parent = Enum.Material.ForceField, 0, model
			tween(ring, 0.5, { CFrame = ring.CFrame + Vector3.new(0, height / 4, 0), Size = Vector3.new(0.2, radius * 2.8, radius * 2.8),
				Transparency = 1 })
			Debris:AddItem(ring, 0.55)
		end)
	end
	Debris:AddItem(model, life)
	return model
end

-- Chunks flung out of the floor, a few glowing (client-side physics only): stone by default,
-- else the kit's own matter (shards of ice, thorns, scraps of iron).
function EffectsController:debris(position, color, scale, matterName)
	local matter = MATTER[matterName or "stone"] or MATTER.stone
	local stone = if matter == MATTER.stone then Color3.fromHex("7A6D62") else matter.color
	for i = 1, if self.reduced then 4 else 9 do
		local size = (0.35 + math.random() * 0.6) * scale
		local spot = position + Vector3.new((math.random() - 0.5) * 2, 0.3, (math.random() - 0.5) * 1.2)
		local glowing = i % 4 == 0
		local long = if matter == MATTER.stone then 0.8 else 2.2 -- shards and thorns are long and thin
		local chunk = self:part(Vector3.new(size * matter.thin ^ 0.5, size * long, size * matter.thin ^ 0.5), CFrame.new(spot)
			* CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6), if glowing then color else stone)
		if glowing then chunk.Material = Enum.Material.Neon else shape(self, chunk, matter) end
		chunk.Anchored = false
		chunk.AssemblyLinearVelocity = Vector3.new((math.random() - 0.5) * 30, 18 + math.random() * 22, (math.random() - 0.5) * 12)
			* math.sqrt(scale)
		chunk.AssemblyAngularVelocity = Vector3.new(math.random() * 10, math.random() * 10, math.random() * 10)
		tween(chunk, 1.2, { Transparency = 1 }, Enum.EasingStyle.Quint)
		Debris:AddItem(chunk, 1.3)
	end
end

-- A glowing fissure running along the floor from one point to another.
function EffectsController:crack(from, to, color)
	local side = (to - from):Cross(Vector3.yAxis)
	side = if side.Magnitude > 1e-3 then side.Unit else Vector3.xAxis
	local points, segments = { from }, if self.reduced then 4 else 7
	for i = 1, segments - 1 do
		table.insert(points, from:Lerp(to, i / segments) + side * (math.random() - 0.5) * 0.9)
	end
	table.insert(points, to)
	for i = 1, #points - 1 do
		local p0, p1 = points[i], points[i + 1]
		task.delay((i - 1) * 0.025, function()
			local length = (p1 - p0).Magnitude
			local seg = self:part(Vector3.new(0.28, 0.05, length + 0.1), CFrame.lookAt((p0 + p1) / 2, p1), if i % 3 == 0 then WHITE else color)
			tween(seg, 1.4, { Transparency = 1, Size = Vector3.new(0.05, 0.05, length + 0.1) })
			Debris:AddItem(seg, 1.5)
		end)
	end
end

-- SHIN: a perfectly straight line of light, a white core in a coloured sheath that flashes
-- wide and fades.
function EffectsController:cut(from, to, color)
	local length = (to - from).Magnitude
	if length < 1e-3 then return end
	local up = if math.abs((to - from).Unit.Y) > 0.95 then Vector3.zAxis else Vector3.yAxis
	local placed = CFrame.lookAt((from + to) / 2, to, up)
	local sheath = self:part(Vector3.new(0.5, 0.5, length), placed, color)
	sheath.Transparency = 0.2
	tween(sheath, 0.35, { Size = Vector3.new(0.02, 1.6, length * 1.02), Transparency = 1 })
	Debris:AddItem(sheath, 0.4)
	local core = self:part(Vector3.new(0.12, 0.12, length), placed, WHITE)
	tween(core, 0.25, { Size = Vector3.new(0.01, 0.01, length), Transparency = 1 })
	Debris:AddItem(core, 0.3)
end

-- DAICHA: a black sun with a burning corona. Returns it for cleanup; gone after `life`
-- seconds, or kept until the end of the scene.
function EffectsController:eclipse(center, color, scale, life)
	local model = Instance.new("Model")
	model.Name, model.Parent = "Eclipse", self.folder
	local size = 9 * scale
	local corona = self:part(Vector3.one * size * 1.18, CFrame.new(center), color, Enum.PartType.Ball)
	corona.Transparency, corona.Parent = 1, model
	tween(corona, 0.6, { Transparency = 0.35 })
	local sun = self:part(Vector3.one * 0.5, CFrame.new(center + Vector3.new(0, 0, 0.6 * scale)), Color3.fromHex("07040C"), Enum.PartType.Ball)
	sun.Material, sun.Parent = Enum.Material.SmoothPlastic, model
	tween(sun, 0.8, { Size = Vector3.one * size }, Enum.EasingStyle.Quart)
	local glow = Instance.new("PointLight")
	glow.Color, glow.Range, glow.Brightness = color, 30 * scale + 10, 3
	glow.Parent = corona
	if life then Debris:AddItem(model, life) end
	return model
end

-- DAICHA: black droplets of matter bursting off an impact, rimmed with her ki colour.
function EffectsController:matterBurst(center, color, scale)
	for i = 1, if self.reduced then 5 else 12 do
		local angle = i / 12 * math.pi * 2 + math.random() * 0.4
		local size = (0.25 + math.random() * 0.35) * scale
		local drop = self:part(Vector3.one * size, CFrame.new(center), if i % 4 == 0 then color else VOID, Enum.PartType.Ball)
		drop.Material = if i % 4 == 0 then Enum.Material.Neon else Enum.Material.SmoothPlastic
		local out = Vector3.new(math.cos(angle), math.sin(angle) * 0.8 + 0.3, (math.random() - 0.3) * 0.8) * (2.2 + math.random() * 1.8) * scale
		tween(drop, 0.45, { Position = center + out, Size = Vector3.one * size * 0.3, Transparency = 1 }, Enum.EasingStyle.Quad)
		Debris:AddItem(drop, 0.5)
	end
end

-- A few grey puffs rising (RYUKEN's smoking fists).
function EffectsController:smoke(position)
	for _ = 1, if self.reduced then 2 else 4 do
		local puff = self:part(Vector3.one * 0.4, CFrame.new(position + Vector3.new((math.random() - 0.5) * 0.4, 0, (math.random() - 0.5) * 0.4)),
			Color3.fromHex("8C8A90"), Enum.PartType.Ball)
		puff.Material, puff.Transparency = Enum.Material.SmoothPlastic, 0.35
		tween(puff, 0.9, { Position = puff.Position + Vector3.new((math.random() - 0.5) * 0.6, 1.6 + math.random(), 0),
			Size = Vector3.one * 1.3, Transparency = 1 })
		Debris:AddItem(puff, 1)
	end
end

-- Debug display of hurtboxes (green) and live hitboxes (red), from the shared simulation math.
function EffectsController:drawDebug(slot, view)
	local boxes = self.debugParts[slot]
	if not boxes then
		boxes = {}
		for i, c in { Color3.fromRGB(60, 255, 120), Color3.fromRGB(255, 50, 60) } do
			local p = self:part(Vector3.one, CFrame.identity, c)
			p.Material, p.Transparency = Enum.Material.SmoothPlastic, 0.65
			boxes[i] = p
		end
		self.debugParts[slot] = boxes
	end
	local x1, x2, y1, y2 = Sim.hurtbox(view, self.config)
	boxes[1].Size = Vector3.new(x2 - x1, y2 - y1, 0.2)
	boxes[1].CFrame = CFrame.new((x1 + x2) / 2, (y1 + y2) / 2, 1.6)
	local m = view.state == "Attack" and MoveData.Moves[view.move]
	if m and m.hitbox and MoveData.phase(m, view.moveFrame) == "Active" then
		local hx1, hx2, hy1, hy2 = Sim.hitbox(view, m)
		boxes[2].Transparency = 0.5
		boxes[2].Size = Vector3.new(hx2 - hx1, hy2 - hy1, 0.25)
		boxes[2].CFrame = CFrame.new((hx1 + hx2) / 2, (hy1 + hy2) / 2, 1.7)
	else
		boxes[2].Transparency = 1
	end
end

function EffectsController:setDebug(enabled)
	self.debug = enabled
	if not enabled then
		for _, boxes in self.debugParts do
			for _, p in boxes do p:Destroy() end
		end
		self.debugParts = {}
	end
end

return EffectsController
