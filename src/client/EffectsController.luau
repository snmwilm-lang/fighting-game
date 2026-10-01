--[[
	Cosmetic effects only: they never change hitboxes or timing. Everything is local to this
	client and short-lived. "Reduced" mode drops screen flashes and lowers shake/particle counts
	(see the project guide: option to reduce flashes and shakes, lighter VFX on mobile).
]]
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local MoveData = require(Shared.MoveData)
local Sim = require(Shared.CombatSimulation)
local CharacterData = require(Shared.CharacterData)

local EffectsController = {}

local WHITE = Color3.fromHex("FFFFFF")
local BODY_PARTS = {
	Head = true, UpperTorso = true, LowerTorso = true,
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
	RightUpperArm = true, RightLowerArm = true, RightHand = true,
	LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true,
	RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
}

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
	local arc = arcs[moveId]
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
	if moveId == "Smash" or moveId == "KaienRush" or moveId == "Finale" or moveId == "Awakening" then -- speed streaks
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

function EffectsController:attachRig(slot, rig)
	local torso = rig.model:FindFirstChild("UpperTorso")
	if not torso then return end
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

-- Per-frame presentation driven by the interpolated fighter views.
function EffectsController:update(slot, view, rig, previous, now)
	local color = self:energy(slot)
	local phase = if view.state == "Attack" and MoveData.Moves[view.move]
		then MoveData.phase(MoveData.Moves[view.move], view.moveFrame) else nil
	local key = if phase then view.move .. phase else view.state
	if previous and previous.key ~= key then
		if phase == "Active" then
			local m = MoveData.Moves[view.move]
			if m.heavy then self:slash(view, view.move, color) end
		elseif view.state == "Dashing" then
			self:dust(view.x, view.y, view.facing)
		elseif view.state == "Knockdown" and previous.key ~= "KO" then
			self:dust(view.x, view.y, view.facing)
			self.camera:shake(if self.reduced then 0.15 else 0.35, 0.2)
		end
	end
	if rig.aura and phase == "Startup" and (view.move == "Smash" or view.move == "Rising" or view.move == "Uppercut"
		or view.move == "Hammer" or view.move == "KaienRush") then
		rig.aura:Emit(if self.reduced then 1 else 3)
	end
	if view.ghost and previous and previous.key ~= key then
		self:afterimage(rig, color)
	end
	if view.state == "Dashing" and now - (self.ghostClock[slot] or 0) > 0.045 then
		self.ghostClock[slot] = now
		self:afterimage(rig, color)
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
	if event.kind == "Clash" then
		self:spark(Vector3.new(event.x, event.y, 0), WHITE, 2)
		self.camera:shake(if self.reduced then 0.15 else 0.35, 0.18)
		return
	elseif event.kind == "Skill" then
		local rig = rigs[event.attacker]
		if rig and rig.aura then rig.aura:Emit(if self.reduced then 8 else 24) end
		local v = views[event.attacker]
		if v then self.camera:punch(0.1, Vector3.new(v.x, v.y + 3.5, 0)) end
		return
	elseif event.kind == "Projectile" then
		local v = views[event.attacker]
		if v then self:spark(Vector3.new(v.x + v.facing * 1.8, v.y + 3.6, 0), self:energy(event.attacker), 0.8) end
		return
	end
	if event.kind == "Hit" or event.kind == "Block" or event.kind == "GuardBreak" then
		local attackerColor = self:energy(event.attacker)
		local position = Vector3.new(event.x, event.y, 0)
		local m = MoveData.Moves[event.move]
		local shakeScale = if self.reduced then 0.4 else 1
		if event.kind == "Hit" then
			local heavy = event.heavy or event.ko
			self:spark(position, attackerColor, if heavy then 1.5 else 1)
			if rigs[event.defender] then self:flash(rigs[event.defender]) end
			self.camera:shake((if heavy then 0.5 else 0.18) * shakeScale, if heavy then 0.25 else 0.12)
			if heavy then
				self:impactFrame(attackerColor, if event.ko or event.cinematic then 2 else 1)
				self.camera:punch(if event.ko then 0.45 else 0.12, position)
			end
		else
			local defender = views[event.defender]
			local shieldColor = Color3.fromHex(CharacterData[event.defender].Shield)
			if defender then self:shield(defender, shieldColor) end
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
			local core = self:part(Vector3.one * 1.1, CFrame.new(p.x, p.y, 0), WHITE, Enum.PartType.Ball)
			local shell = self:part(Vector3.one * 2, CFrame.new(p.x, p.y, 0), color, Enum.PartType.Ball)
			shell.Material, shell.Transparency = Enum.Material.ForceField, 0
			local light = Instance.new("PointLight")
			light.Color, light.Range, light.Brightness = color, 12, 3
			light.Parent = core
			visual = { core = core, shell = shell, color = color, trail = 0 }
			self.projectiles[p.id] = visual
		end
		local position = Vector3.new(p.x + p.vx * ahead, p.y, 0.4)
		local pulse = 1 + 0.12 * math.sin(now * 40)
		visual.core.CFrame = CFrame.new(position)
		visual.shell.CFrame = CFrame.new(position)
		visual.shell.Size = Vector3.one * 2 * pulse
		if now - visual.trail > (if self.reduced then 0.06 else 0.03) then
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
