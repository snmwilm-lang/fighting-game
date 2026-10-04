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
		local hit = OrbFlight.strike(MoveData.Moves[moveId])
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

-- DAICHA's orb, free of his hand: where OrbFlight puts it, eased (it never teleports).
function EffectsController:flyOrb(rig, view, now)
	local id = view.state == "Attack" and view.move or nil
	local o = OrbFlight.offset(view, id and MoveData.Moves[id], id and ROLE_OF[id], now)
	-- (from where the body is drawn: the presentation spacing may set it a little apart)
	local x = if rig.root then rig.root.Position.X else view.x
	local target = Vector3.new(x + view.facing * o.fwd, view.y + o.up, self.config.PlaneZ + o.side)
	local dt = math.clamp(now - (rig.orbClock or now), 0, 0.1)
	rig.orbClock = now
	rig.orbPosition = (rig.orbPosition or target):Lerp(target, 1 - math.exp(-dt * 22))
	local spin = CFrame.new(rig.orbPosition) * CFrame.Angles(0, now * 2.2, now * 0.7)
	for _, p in rig.orbParts do
		if p.Parent then p.CFrame = spin end
	end
	if rig.orbChain then rig.orbChain.Enabled = view.state == "Attack" end
end

-- The guard of a weapon kit, shown while guarding (and flashing when it takes a blow): an
-- arc of light raised before SHIN's blade, two rings of shadow round DAICHA's orb.
function EffectsController:weaponGuard(slot, rig, view, guarding, color)
	self.guards = self.guards or {}
	local guard = self.guards[slot]
	if not guard or guard.rig ~= rig then
		if guard then guard.model:Destroy() end
		local model = Instance.new("Model")
		model.Name = "WeaponGuard" .. slot
		local parts = {}
		if rig.weaponKind == "Sword" then
			-- ")" : segments of an arc standing in front of the body.
			local segments, radius = 9, 2.2
			for i = 0, segments - 1 do
				local a0 = math.rad(-75 + 150 * i / segments)
				local a1 = math.rad(-75 + 150 * (i + 1) / segments)
				local p0 = Vector3.new(math.cos(a0) * 0.6, math.sin(a0) * radius, math.cos(a0) * 0.2)
				local p1 = Vector3.new(math.cos(a1) * 0.6, math.sin(a1) * radius, math.cos(a1) * 0.2)
				local width = 0.12 + 0.3 * math.sin(math.pi * (i + 0.5) / segments)
				local seg = self:part(Vector3.new(width, 0.1, (p1 - p0).Magnitude + 0.05), CFrame.lookAt((p0 + p1) / 2, p1), if i % 3 == 1 then WHITE else color)
				seg.Parent = model
				table.insert(parts, seg)
			end
		else
			for i, d in { 3.2, 2.2 } do
				local ring = self:part(Vector3.new(0.06, d, d), CFrame.new(i * 0.15, 0, 0), color, Enum.PartType.Cylinder)
				ring.Material, ring.Parent = Enum.Material.ForceField, model
				table.insert(parts, ring)
			end
			local core = self:part(Vector3.new(0.05, 1.2, 1.2), CFrame.identity, VOID, Enum.PartType.Cylinder)
			core.Parent = model
			table.insert(parts, core)
		end
		model.WorldPivot = CFrame.identity -- built round the origin
		model.Parent = self.folder
		guard = { model = model, parts = parts, rig = rig, shown = 0, flash = 0 }
		self.guards[slot] = guard
	end
	local target = if guarding then 0.55 else 0
	guard.shown += (target - guard.shown) * 0.3
	guard.flash = math.max(0, guard.flash - 0.08)
	local low = view.state == "CrouchBlocking" or view.state == "CrouchBlockstun"
	local f = view.facing
	local at = if rig.orbPosition and rig.weaponKind == "Orb" then rig.orbPosition
		else Vector3.new(view.x + f * 1.3, view.y + (if low then 2.1 else 3.5), self.config.PlaneZ + 0.2)
	-- Turned a little toward the camera so it reads from the side view.
	guard.model:PivotTo(CFrame.new(at) * CFrame.Angles(0, (if f > 0 then 0 else math.pi) - f * math.rad(35), 0))
	local alpha = 1 - math.clamp(guard.shown + guard.flash, 0, 1)
	for _, p in guard.parts do
		if p.Transparency ~= alpha then p.Transparency = alpha end
	end
end

-- ===================================================================== every kit's own strikes
-- The combos of the eight fighters never look alike: each kit has its own flourish when a
-- blow goes out (`kitSwing`, on the first contact frame of the move, hit or not) and when it
-- lands (`kitHit`, on the Hit event): ki for KAI, fire round TARO's gloves, wind for ZEPHYR,
-- shadow cuts for AKEMI, cracks of rage for RYUKEN, the blade for SHIN, the orb for DAICHA,
-- stone for HIBECARES.
local FIRE, EMBER = Color3.fromHex("FF7A1A"), Color3.fromHex("FFD45A")
local STONE = Color3.fromHex("7A6D62")

-- A ki flash: a white core in a ring of the fighter's colour.
function EffectsController:kiPop(position, color, scale)
	local core = self:part(Vector3.one * 0.5 * scale, CFrame.new(position), WHITE, Enum.PartType.Ball)
	tween(core, 0.14, { Size = Vector3.one * 1.8 * scale, Transparency = 1 })
	Debris:AddItem(core, 0.18)
	local ring = self:part(Vector3.new(0.06, 1, 1) * scale, CFrame.new(position) * CFrame.Angles(0, math.pi / 2, 0), color, Enum.PartType.Cylinder)
	tween(ring, 0.2, { Size = Vector3.new(0.06, 3.4, 3.4) * scale, Transparency = 1 })
	Debris:AddItem(ring, 0.24)
end

-- TARO's glove: a ring of fire round the fist and embers thrown off it.
function EffectsController:fireRing(position, scale)
	local ring = self:part(Vector3.new(0.18, 1, 1) * scale, CFrame.new(position) * CFrame.Angles(0, math.pi / 2, 0), FIRE, Enum.PartType.Cylinder)
	ring.Transparency = 0.05
	tween(ring, 0.22, { Size = Vector3.new(0.05, 3.2, 3.2) * scale, Transparency = 1 })
	Debris:AddItem(ring, 0.26)
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
	local ring = self:part(Vector3.new(0.05, 1, 1) * scale, CFrame.new(position) * CFrame.Angles(0, math.pi / 2, 0), WHITE, Enum.PartType.Cylinder)
	ring.Material, ring.Transparency = Enum.Material.ForceField, 0
	tween(ring, 0.18, { Size = Vector3.new(0.05, 4.2, 4.2) * scale, Transparency = 1 })
	Debris:AddItem(ring, 0.22)
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
	local ring = self:part(Vector3.new(0.1, 1, 1) * scale, CFrame.new(position) * CFrame.Angles(0, math.pi / 2, 0), color, Enum.PartType.Cylinder)
	tween(ring, 0.18, { Size = Vector3.new(0.05, 3.8, 3.8) * scale, Transparency = 1 })
	Debris:AddItem(ring, 0.22)
end

-- A blow goes out (first contact frame): the kit's flourish along the strike.
function EffectsController:kitSwing(view, moveId, color, heavy)
	local kit = MoveData.MoveKit[moveId] or "KAI"
	local role = ROLE_OF[moveId] or moveId
	local f, z = view.facing, self.config.PlaneZ
	local limbs = strikeLimbs(moveId)
	local footwork = limbs and (table.find(limbs, "RightFoot") or table.find(limbs, "LeftFoot")) ~= nil
	local at = Vector3.new(view.x + f * 2.2, view.y + (if role == "Sweep" or role == "LowKick" then 1 else 3.4), z)
	if kit == "TARO" then
		-- the punch drags a streak of fire
		self:cut(at - Vector3.new(f * 1.8, 0, 0), at + Vector3.new(f * 0.6, 0, 0), FIRE)
		if heavy then self:fireRing(at, 1.3) end
	elseif kit == "ZEPHYR" then
		-- every kick cuts a crescent of wind
		self:arc(Vector3.new(view.x + f * 0.6, at.Y, z), if heavy then 3.6 else 3, if footwork then -70 else -40,
			if footwork then 80 else 40, WHITE, 0.3, f)
	elseif kit == "AKEMI" then
		-- a thin shadow slash
		self:arc(Vector3.new(view.x + f * 0.6, at.Y, z), 2.6, 70, -50, color, 0.5, f)
		if heavy then self:cut(at + Vector3.new(-f, 1, 0), at + Vector3.new(f, -1, 0), color) end
	elseif kit == "RYUKEN" then
		-- heat streaks behind the fist
		for i = -1, 1 do
			local y = at.Y + i * 0.35
			self:cut(Vector3.new(at.X - f * 2.4, y, z), Vector3.new(at.X, y, z), color)
		end
		if heavy then
			self:crack(Vector3.new(view.x + f, 0.05, z), Vector3.new(view.x + f * 4.5, 0.05, z + 0.5), color)
		end
	elseif kit == "HIBECARES" then
		-- the weight of the blow raises dust at his feet
		self:dust(view.x, 0, f)
		if heavy then
			self:crack(Vector3.new(view.x + f, 0.05, z), Vector3.new(view.x + f * 4, 0.05, z - 0.5), color)
			self:debris(Vector3.new(view.x + f * 2.5, 0.3, z), color, 0.8)
			self.camera:shake(if self.reduced then 0.15 else 0.4, 0.2)
		end
	else
		-- KAI: a short ki streak along the blow
		self:cut(at - Vector3.new(f * 1.4, 0, 0), at + Vector3.new(f * 0.4, 0, 0), color)
	end
end

-- A blow lands: the kit's mark on the target.
function EffectsController:kitHit(moveId, position, color, heavy, facing)
	local kit = MoveData.MoveKit[moveId] or "KAI"
	local s = if heavy then 1.5 else 1
	if kit == "TARO" then
		self:fireRing(position, s)
	elseif kit == "ZEPHYR" then
		self:airBurst(position, facing, s)
	elseif kit == "AKEMI" then
		self:cut(position + Vector3.new(-1.1, 0.9, 0.3) * s, position + Vector3.new(1.1, -0.9, 0.3) * s, color)
		self:cut(position + Vector3.new(-1.1, -0.9, 0.3) * s, position + Vector3.new(1.1, 0.9, 0.3) * s, color)
	elseif kit == "RYUKEN" then
		self:rageCrack(position, color, s)
	elseif kit == "HIBECARES" then
		self:debris(position, STONE, 0.5 * s)
		self:dust(position.X, 0, facing)
	elseif kit == "SHIN" then
		self:cut(position + Vector3.new(-facing * 1.3, 0.6, 0.3), position + Vector3.new(facing * 1.3, -0.6, 0.3), color)
	elseif kit == "DAICHA" then
		self:orbBurst(position, color, 0.7 * s)
	else
		self:kiPop(position, color, s)
	end
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
		trail.Enabled = false
		trail.Parent = weapon
		rig.trails.Weapon = trail
		rig.weaponHand = if blade then "RightHand" else "LeftHand"
		rig.weaponKind = if blade then "Sword" else "Orb"
		if orb then
			-- DAICHA's orb is set free: it flies round him (OrbFlight), moved every frame.
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
			-- The chain of shadow between his hand and the orb, shown while he strikes with it
			-- (the orb swings like a nunchaku, see OrbFlight).
			local holder = rig.model:FindFirstChild("LeftHand") or rig.model:FindFirstChild("Left Arm")
			if holder and holder:IsA("BasePart") then
				local c0, c1 = Instance.new("Attachment"), Instance.new("Attachment")
				c0.Name, c1.Name = "OrbChainHand", "OrbChainOrb"
				c0.Position = Vector3.new(0, -holder.Size.Y * 0.3, 0)
				c0.Parent, c1.Parent = holder, orb
				local chain = Instance.new("Beam")
				chain.Name = "OrbChain"
				chain.Attachment0, chain.Attachment1 = c0, c1
				chain.Width0, chain.Width1 = 0.18, 0.09
				chain.Color = ColorSequence.new(Color3.fromHex("140A20"), self:energy(slot))
				chain.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.35) })
				chain.LightEmission, chain.FaceCamera, chain.Segments = 0.6, true, 1
				chain.Enabled = false
				chain.Parent = holder
				rig.orbChain = chain
			end
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
			self:dust(view.x, view.y, view.facing)
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
	if rig.orbParts then self:flyOrb(rig, view, now) end
	if rig.weaponKind then
		local guarding = view.state == "Blocking" or view.state == "CrouchBlocking" or view.state == "Blockstun"
			or view.state == "CrouchBlockstun"
		self:weaponGuard(slot, rig, view, guarding, color)
	end
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
		-- The third sheet's passives: a mark where it happened, in a colour that tells it.
		local slot = event.slot or event.defender
		local position = Vector3.new(event.x or 0, event.y or 3, 0)
		local colors = { Chilled = "9FE6FF", Poison = "7CFF4A", Heal = "FFE9A0", Reflect = "C8F0FF", Armor = "FF4A3A",
			Shackled = "FFB04A", Domination = "E0102E", Drone = "FF8A2A" }
		local color = Color3.fromHex(colors[event.kind])
		self:spark(position, color, if event.kind == "Poison" then 0.5 else 1.2)
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
			local guard = self.guards and self.guards[event.defender]
			if guard and guard.shown > 0.2 then
				-- SHIN's blade / DAICHA's orb takes the blow: the guard flashes.
				guard.flash = 1
				self:spark(guard.model:GetPivot().Position, self:energy(event.defender), 1.1)
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

-- Ki blasts: a glowing core with a ki shell and a short trail, extrapolated between snapshots.
function EffectsController:updateProjectiles(list, ahead, now)
	self.projectiles = self.projectiles or {}
	local alive = {}
	for _, p in list or {} do
		alive[p.id] = true
		local visual = self.projectiles[p.id]
		local color = self:energy(p.owner)
		if not visual then
			-- (a trap lies flat on the floor; a drone is small and metallic)
			local scale = if p.drone then 0.45 elseif p.trap then 1.3 else 1
			local core = self:part(Vector3.one * 1.1 * scale, CFrame.new(p.x, p.y, 0), if p.drone then Color3.fromHex("5A5A66") else WHITE, Enum.PartType.Ball)
			local shell = self:part(Vector3.one * 2 * scale, CFrame.new(p.x, p.y, 0), color, Enum.PartType.Ball)
			shell.Material, shell.Transparency = Enum.Material.ForceField, 0
			local light = Instance.new("PointLight")
			light.Color, light.Range, light.Brightness = color, 12, 3
			light.Parent = core
			visual = { core = core, shell = shell, color = color, trail = 0, scale = scale, still = p.drone or p.trap }
			self.projectiles[p.id] = visual
		end
		local position = Vector3.new(p.x + p.vx * ahead, p.y, 0.4)
		local pulse = 1 + 0.12 * math.sin(now * 40)
		visual.core.CFrame = CFrame.new(position)
		visual.shell.CFrame = CFrame.new(position)
		visual.shell.Size = if p.trap then Vector3.new(2.6, 0.3, 2.6) * pulse else Vector3.one * 2 * pulse * visual.scale
		if not visual.still and now - visual.trail > (if self.reduced then 0.06 else 0.03) then
			visual.trail = now
			local ghost = self:part(Vector3.one * 1.3, CFrame.new(position), visual.color, Enum.PartType.Ball)
			ghost.Transparency = 0.4
			tween(ghost, 0.2, { Transparency = 1, Size = Vector3.one * 0.3 })
			Debris:AddItem(ghost, 0.22)
		end
	end
	for id, visual in self.projectiles do
		if not alive[id] then
			visual.core:Destroy()
			visual.shell:Destroy()
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
