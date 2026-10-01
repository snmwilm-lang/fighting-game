--[[
	Presentation of the ultimate (KAIEN RUSH). The simulation decides everything (hits, damage,
	duration); this module only stages it: cut-in on the super flash, letterbox, scripted camera
	shots, teleporting rush poses and the final impact.

	The camera returns to the fight camera as soon as the snapshot no longer carries a
	cinematic, or if snapshots stop arriving (disconnect), so it can never stay stuck.
]]
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local MoveData = require(Shared.MoveData)
local CharacterData = require(Shared.CharacterData)

local CinematicController = {}

local WHITE = Color3.fromHex("F5F5F7")
local INK = Color3.fromHex("0B0B0E")
local CIN = MoveData.Cinematic
-- Rush poses cycle through the active frames of the normals while KAI blinks around the target.
local RUSH = { "Jab", "Cross", "Kick", "Elbow", "AirKick", "SpinKick", "BodyBlow", "Uppercut", "AirKick2" }

local function tween(instance, duration, goal, style, direction)
	local t = TweenService:Create(instance, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

local function new(className, props, parent)
	local i = Instance.new(className)
	for k, v in props do i[k] = v end
	i.Parent = parent
	return i
end

function CinematicController.new(config, hud, effects)
	local self = setmetatable({ config = config, hud = hud, effects = effects, active = false, shake = 0, shot = nil },
		{ __index = CinematicController })
	local gui = new("ScreenGui", { Name = "Cinematic", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20 },
		Players.LocalPlayer:WaitForChild("PlayerGui"))
	self.gui = gui
	self.top = new("Frame", { BackgroundColor3 = INK, BorderSizePixel = 0, Size = UDim2.fromScale(1, 0) }, gui)
	self.bottom = new("Frame", { BackgroundColor3 = INK, BorderSizePixel = 0, Size = UDim2.fromScale(1, 0),
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1) }, gui)
	self.flashFrame = new("Frame", { BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui)

	-- Cut-in banner: tilted ink band, giant kanji, character and move names.
	local banner = new("Frame", {
		Name = "CutIn", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(1.4, 0, 0.3, 0),
		Position = UDim2.fromScale(-1, 0.5), Rotation = -6, BackgroundColor3 = INK, BorderSizePixel = 0, Visible = false,
	}, gui)
	new("UIGradient", { Rotation = 0, Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.2, 0), NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 0.6),
	}) }, banner)
	self.bannerStripe = new("Frame", { BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 8), Position = UDim2.new(0, 0, 1, -8) }, banner)
	self.bannerStripeTop = new("Frame", { BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 8) }, banner)
	self.kanji = new("TextLabel", {
		BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, Text = "",
		Size = UDim2.fromScale(0.22, 1.25), Position = UDim2.fromScale(0.2, -0.12), TextTransparency = 0.05,
	}, banner)
	self.charName = new("TextLabel", {
		BackgroundTransparency = 1, Font = Enum.Font.Bangers, TextScaled = true, TextColor3 = WHITE,
		Size = UDim2.fromScale(0.3, 0.34), Position = UDim2.fromScale(0.43, 0.08), TextXAlignment = Enum.TextXAlignment.Left,
	}, banner)
	self.moveName = new("TextLabel", {
		BackgroundTransparency = 1, Font = Enum.Font.Bangers, TextScaled = true,
		Size = UDim2.fromScale(0.42, 0.46), Position = UDim2.fromScale(0.43, 0.44), TextXAlignment = Enum.TextXAlignment.Left,
	}, banner)
	new("UIStroke", { Thickness = 3, Color = WHITE }, self.moveName)
	self.banner = banner

	self.stamp = new("TextLabel", {
		BackgroundTransparency = 1, Font = Enum.Font.Bangers, TextSize = 96, TextColor3 = WHITE, Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.78), Size = UDim2.new(1, 0, 0, 100), Rotation = -4,
	}, gui)
	new("UIStroke", { Thickness = 6, Color = INK }, self.stamp)
	self.stampScale = new("UIScale", {}, self.stamp)

	self.darken = new("ColorCorrectionEffect", { Name = "SuperFlash", Enabled = false, Brightness = -0.22, Saturation = -0.55, Contrast = 0.2 }, Lighting)
	return self
end

-- Super flash: dim the world and slide the cut-in across the screen.
function CinematicController:superFlash(slot)
	local data = CharacterData[slot]
	local energy = Color3.fromHex(data.Energy)
	self.kanji.Text, self.kanji.TextColor3 = data.Kanji, energy
	self.charName.Text = data.Name .. " · " .. data.Skin
	self.moveName.Text, self.moveName.TextColor3 = MoveData.Moves.KaienRush.name, energy
	self.bannerStripe.BackgroundColor3, self.bannerStripeTop.BackgroundColor3 = energy, energy
	self.banner.Visible, self.banner.Position = true, UDim2.fromScale(-0.8, 0.5)
	self.darken.Enabled = not self.effects.reduced
	tween(self.banner, 0.14, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Quart)
	local id = (self.flashId or 0) + 1
	self.flashId = id
	task.delay(0.52, function()
		if self.flashId ~= id then return end
		tween(self.banner, 0.12, { Position = UDim2.fromScale(1.8, 0.5) }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
		self.darken.Enabled = false
	end)
end

function CinematicController:begin()
	self.active = true
	self.hud.gui.Enabled = false
	tween(self.top, 0.18, { Size = UDim2.fromScale(1, 0.12) })
	tween(self.bottom, 0.18, { Size = UDim2.fromScale(1, 0.12) })
end

function CinematicController:finish()
	self.active, self.shot = false, nil
	self.hud.gui.Enabled = true
	self.darken.Enabled = false
	self.stamp.Visible = false
	tween(self.top, 0.25, { Size = UDim2.fromScale(1, 0) })
	tween(self.bottom, 0.25, { Size = UDim2.fromScale(1, 0) })
end

function CinematicController:onHit(event)
	local reduced = self.effects.reduced
	self.shake = math.max(self.shake, (if event.heavy then 1.4 else 0.35) * (if reduced then 0.4 else 1))
	if event.heavy then
		if not reduced then
			self.flashFrame.BackgroundTransparency = 0
			tween(self.flashFrame, 0.35, { BackgroundTransparency = 1 })
		end
		self.stamp.Text = MoveData.Moves.KaienRush.name .. " !!"
		self.stamp.TextColor3 = Color3.fromHex(CharacterData[event.attacker].Energy)
		self.stamp.Visible = true
		self.stampScale.Scale = 2.2
		tween(self.stampScale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	end
end

local function hitsBefore(tick)
	local n = 0
	for _, t in CIN.Hits do
		if t <= tick then n += 1 end
	end
	return n
end

-- Overrides the displayed views (positions and poses) for the cinematic. Cosmetic only.
function CinematicController:stage(cin, views, tick)
	local a, d = views[cin.attacker], views[cin.defender]
	if not a or not d then return end
	self.dir = self.dir or a.facing
	local dir = self.dir
	local k = hitsBefore(tick)
	if tick < CIN.FinalTick - 16 then
		if k == 0 then
			a.x, a.state, a.move = d.x - dir * 2.8, "Attack", "KaienRush"
			a.moveFrame = MoveData.Moves.KaienRush.startup + 1
		else
			local behind = k % 2 == 0
			a.x = d.x + (if behind then dir else -dir) * 2.6
			a.y = if k % 3 == 0 then 1.6 else 0
			a.facing = if behind then -dir else dir
			a.state, a.move = "Attack", RUSH[(k - 1) % #RUSH + 1]
			a.moveFrame = MoveData.Moves[a.move].startup + 1
		end
		d.state = "Hitstun"
		local lastHit = CIN.Hits[math.max(k, 1)]
		d.hitstop = if k > 0 and tick - lastHit < 6 then 1 else 0
	elseif tick < CIN.FinalTick then
		a.x, a.y, a.facing = d.x - dir * 2.8, 0, dir
		a.state, a.move, a.moveFrame = "Attack", "Smash", 1
		d.state, d.hitstop = "Hitstun", 0
	else
		a.x, a.y, a.facing = d.x - dir * 2.8, 0, dir
		a.state, a.move = "Attack", "Smash"
		a.moveFrame = MoveData.Moves.Smash.startup + 1
	end
	a.victory = false
	a.ghost = true -- afterimage each time KAI blinks to a new spot
end

-- Returns true while the cinematic owns the camera.
function CinematicController:update(world, views, dt, stale)
	local cin = world.cinematic
	if not cin or stale then
		if self.active then self:finish() end
		self.dir = nil
		return false
	end
	if not self.active then self:begin() end
	local tick = math.min(cin.tick + math.floor((os.clock() - (self.snapshotAt or os.clock())) * self.config.TickRate), cin.length)
	self:stage(cin, views, tick)
	local a, d = views[cin.attacker], views[cin.defender]
	if not a or not d then return true end
	local dir = self.dir or 1
	local pa = Vector3.new(a.x, a.y + 4, 0)
	local pd = Vector3.new(d.x, d.y + 3.6, 0)
	local shot, position, target, fov
	if tick < CIN.Hits[1] then
		shot, fov = "closeup", 30
		position, target = pa + Vector3.new(dir * 4.2, -0.6, 6.5), pa + Vector3.new(0, 0.4, 0)
	elseif tick < CIN.FinalTick - 16 then
		local progress = (tick - CIN.Hits[1]) / (CIN.FinalTick - 16 - CIN.Hits[1])
		local angle = -1.15 + 2.3 * progress
		shot, fov = "orbit", 46
		position = pd + Vector3.new(math.sin(angle) * 12, 2.5 + math.sin(angle * 2) * 1.5, math.cos(angle) * 12)
		target = pd
	elseif tick < CIN.FinalTick then
		local progress = (tick - (CIN.FinalTick - 16)) / 16
		shot, fov = "windup", 38 - 10 * progress
		position, target = pa + Vector3.new(-dir * 5.5, -1.6, 5.5), pd + Vector3.new(0, 0.6, 0)
	elseif tick < CIN.FinalTick + 10 then
		shot, fov = "impact", 52
		position, target = pd + Vector3.new(-dir * 1.5, 0.4, 7), pd
	else
		shot, fov = "wide", 42
		local mid = (pa + pd) / 2
		position, target = mid + Vector3.new(0, 5, 30), mid + Vector3.new(0, 1, 0)
	end
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local goal = CFrame.lookAt(position, target)
	if shot ~= self.shot then
		-- Anime-style hard cut between shots.
		self.shot, self.cameraCFrame = shot, goal
	else
		self.cameraCFrame = self.cameraCFrame:Lerp(goal, 1 - math.exp(-14 * dt))
	end
	local shake = Vector3.zero
	if self.shake > 0.01 then
		shake = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * self.shake
		self.shake *= math.exp(-9 * dt)
	end
	camera.FieldOfView = fov
	camera.CFrame = self.cameraCFrame + self.cameraCFrame:VectorToWorldSpace(shake)
	return true
end

function CinematicController:snapshot()
	self.snapshotAt = os.clock()
end

return CinematicController
