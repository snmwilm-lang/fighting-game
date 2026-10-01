--[[
	Presentation of the cinematic attacks: KAIEN RUSH (ultimate, R) and ÉVEIL ÉCARLATE (unique
	attack: 6th press of a full route with 3 ki bars), including the FINAL FINISH sequence when
	the target was under half health.

	The simulation decides everything (hits, damage, KO, duration); this module only stages it:
	cut-in on the super flash, letterbox, scripted camera shots with hard anime cuts, poses and
	positions of both fighters, colour grading and stamps.

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
local RED = Color3.fromHex("E0102B")
-- Rush poses cycle through the active frames of the normals while KAI blinks around the target.
local RUSH = { "Jab", "Cross", "Kick", "Elbow", "AirKick", "SpinKick", "BodyBlow", "Uppercut", "AirKick2", "KiFlurry" }

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

local function hitsBefore(hits, tick)
	local n = 0
	for _, t in hits do
		if t <= tick then n += 1 end
	end
	return n
end

local function lerp(a, b, t)
	return a + (b - a) * math.clamp(t, 0, 1)
end

function CinematicController.new(config, hud, effects)
	local self = setmetatable({ config = config, hud = hud, effects = effects, active = false, shake = 0, shot = nil },
		{ __index = CinematicController })
	local gui = new("ScreenGui", { Name = "Cinematic", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20 },
		Players.LocalPlayer:WaitForChild("PlayerGui"))
	self.gui = gui
	-- Giant kanji painted over the eyes close-up.
	self.kanjiBack = new("TextLabel", {
		BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, Text = "", Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.72, 0.5), Size = UDim2.fromScale(0.5, 0.9),
		TextColor3 = RED, TextTransparency = 0.35,
	}, gui)
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
	-- Big centre title for FINAL FINISH / K.O.
	self.title = new("TextLabel", {
		BackgroundTransparency = 1, Font = Enum.Font.Bangers, TextSize = 150, TextColor3 = RED, Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.new(1, 0, 0, 160), Rotation = -3,
	}, gui)
	new("UIStroke", { Thickness = 8, Color = WHITE }, self.title)
	self.titleScale = new("UIScale", {}, self.title)

	self.darken = new("ColorCorrectionEffect", { Name = "SuperFlash", Enabled = false, Brightness = -0.22, Saturation = -0.55, Contrast = 0.2 }, Lighting)
	-- Crimson sky of ÉVEIL ÉCARLATE, and the inverted manga look of its impact.
	self.crimson = new("ColorCorrectionEffect", { Name = "Crimson", Enabled = false, TintColor = Color3.fromRGB(255, 120, 125), Contrast = 0.3, Saturation = 0.15, Brightness = -0.05 }, Lighting)
	self.mono = new("ColorCorrectionEffect", { Name = "FinishMono", Enabled = false, Saturation = -1, Contrast = 0.6, Brightness = 0.02 }, Lighting)
	return self
end

-- Super flash: dim the world and slide the cut-in across the screen.
function CinematicController:superFlash(slot, moveId)
	local data = CharacterData[slot]
	local energy = Color3.fromHex(data.Energy)
	local m = MoveData.Moves[moveId or "KaienRush"]
	self.kanji.Text, self.kanji.TextColor3 = data.Kanji, energy
	self.charName.Text = data.Name .. " · " .. data.Skin
	self.moveName.Text, self.moveName.TextColor3 = m.name, energy
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
	self.titleShown = nil
	tween(self.top, 0.18, { Size = UDim2.fromScale(1, 0.12) })
	tween(self.bottom, 0.18, { Size = UDim2.fromScale(1, 0.12) })
end

function CinematicController:finish()
	self.active, self.shot = false, nil
	self.hud.gui.Enabled = true
	self.darken.Enabled, self.crimson.Enabled, self.mono.Enabled = false, false, false
	self.stamp.Visible, self.title.Visible, self.kanjiBack.Visible = false, false, false
	tween(self.top, 0.25, { Size = UDim2.fromScale(1, 0) })
	tween(self.bottom, 0.25, { Size = UDim2.fromScale(1, 0) })
end

function CinematicController:flash(duration)
	if self.effects.reduced then return end
	self.flashFrame.BackgroundTransparency = 0
	tween(self.flashFrame, duration or 0.35, { BackgroundTransparency = 1 })
end

function CinematicController:showStamp(text, color)
	self.stamp.Text, self.stamp.TextColor3 = text, color
	self.stamp.Visible = true
	self.stampScale.Scale = 2.2
	tween(self.stampScale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
end

function CinematicController:showTitle(text, color)
	if self.titleShown == text then return end
	self.titleShown = text
	self.title.Text, self.title.TextColor3, self.title.Visible = text, color, true
	self.titleScale.Scale = 3
	tween(self.titleScale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
end

function CinematicController:onHit(event)
	local reduced = self.effects.reduced
	self.shake = math.max(self.shake, (if event.heavy then 1.6 else 0.4) * (if reduced then 0.4 else 1))
	if event.heavy then
		self:flash()
		local m = MoveData.Moves[event.move]
		self:showStamp((if m then m.name else event.move) .. " !!", Color3.fromHex(CharacterData[event.attacker].Energy))
		if event.move == "Awakening" and not reduced then
			-- Manga impact: one inverted black-and-white beat.
			self.mono.Enabled = true
			task.delay(0.12, function() self.mono.Enabled = false end)
		end
	end
end

-- KAIEN RUSH: rush of blinks around the target, wind-up, final blow.
function CinematicController:directRush(cin, a, d, tick, dir)
	local data = MoveData.Cinematics.KaienRush
	local k = hitsBefore(data.Hits, tick)
	if tick < data.FinalTick - 16 then
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
		local lastHit = data.Hits[math.max(k, 1)]
		d.hitstop = if k > 0 and tick - lastHit < 6 then 1 else 0
	elseif tick < data.FinalTick then
		a.x, a.y, a.facing = d.x - dir * 2.8, 0, dir
		a.state, a.move, a.moveFrame = "Attack", "Smash", MoveData.Moves.Smash.startup
		d.state, d.hitstop = "Hitstun", 0
	else
		a.x, a.y, a.facing = d.x - dir * 2.8, 0, dir
		a.state, a.move = "Attack", "Smash"
		a.moveFrame = MoveData.Moves.Smash.startup + 1
	end
	a.ghost = true

	local pa = Vector3.new(a.x, a.y + 4, 0)
	local pd = Vector3.new(d.x, d.y + 3.6, 0)
	if tick < data.Hits[1] then
		return "closeup", pa + Vector3.new(dir * 4.2, -0.6, 6.5), pa + Vector3.new(0, 0.4, 0), 30, 0
	elseif tick < data.FinalTick - 16 then
		local progress = (tick - data.Hits[1]) / (data.FinalTick - 16 - data.Hits[1])
		local angle = -1.15 + 2.3 * progress
		return "orbit", pd + Vector3.new(math.sin(angle) * 12, 2.5 + math.sin(angle * 2) * 1.5, math.cos(angle) * 12), pd, 46, 0
	elseif tick < data.FinalTick then
		local progress = (tick - (data.FinalTick - 16)) / 16
		return "windup", pa + Vector3.new(-dir * 5.5, -1.6, 5.5), pd + Vector3.new(0, 0.6, 0), 38 - 10 * progress, 0
	elseif tick < data.FinalTick + 10 then
		return "impact", pd + Vector3.new(-dir * 1.5, 0.4, 7), pd, 52, 0
	end
	local mid = (pa + pd) / 2
	return "wide", mid + Vector3.new(0, 5, 30), mid + Vector3.new(0, 1, 0), 42, 0
end

-- ÉVEIL ÉCARLATE: eyes, crimson aura, dash, strikes from many angles, sky leap, dive, impact,
-- then (FINAL FINISH only) the slow fall, the K.O. and KAI turning his back.
function CinematicController:directAwakening(cin, a, d, tick, dir, now)
	local data = MoveData.Cinematics.Awakening
	local energy = Color3.fromHex(CharacterData[cin.attacker].Energy)
	local reduced = self.effects.reduced
	local headA = Vector3.new(a.x, a.y + 5.3, 0)
	local pd = Vector3.new(d.x, d.y + 3.6, 0)
	self.crimson.Enabled = not reduced and tick >= 24 and tick < data.FinalTick + 40
	self.kanjiBack.Visible = tick < 24
	if tick < 24 then
		-- 1. Extreme close-up on the eyes, a giant kanji painted over the frame.
		self.kanjiBack.Text = CharacterData[cin.attacker].Kanji
		a.x, a.y, a.facing, a.pose = d.x - dir * 9, 0, dir, "Kiai"
		d.state = "Hitstun"
		local eyes = Vector3.new(a.x, a.y + 5.4, 0)
		return "eyes", eyes + Vector3.new(dir * 1.6, 0.05, 1.2), eyes, 16, 0
	elseif tick < 50 then
		-- 2. Low-angle hero shot while the crimson aura erupts.
		a.x, a.y, a.facing, a.pose = d.x - dir * 9, 0, dir, "Kiai"
		d.state = "Hitstun"
		if self.effects.rigs and self.effects.rigs[cin.attacker] and self.effects.rigs[cin.attacker].aura then
			self.effects.rigs[cin.attacker].aura:Emit(if reduced then 1 else 3)
		end
		local feet = Vector3.new(a.x, a.y, 0)
		return "hero", feet + Vector3.new(dir * 4, 0.6, 5), headA + Vector3.new(0, 1.5, 0), 48, math.rad(-8 * dir)
	elseif tick < data.Hits[1] then
		-- 3. Tracking shot of the dash.
		local progress = (tick - 50) / (data.Hits[1] - 50)
		a.x, a.y, a.facing, a.pose = lerp(d.x - dir * 9, d.x - dir * 2.4, progress), 0, dir, "Dash"
		a.ghost = true
		d.state = "Hitstun"
		local mid = Vector3.new((a.x + d.x) / 2, 3.5, 0)
		return "dash", mid + Vector3.new(0, 1, 14), mid, 40, 0
	elseif tick < data.Hits[#data.Hits] + 4 then
		-- 4. Strikes: a hard cut to a new camera angle on every hit.
		local k = math.max(1, hitsBefore(data.Hits, tick))
		local behind = k % 2 == 0
		a.x = d.x + (if behind then dir else -dir) * 2.5
		a.y = if k % 3 == 0 then 2 else 0
		a.facing = if behind then -dir else dir
		a.state, a.move = "Attack", RUSH[(k * 3) % #RUSH + 1]
		a.moveFrame = MoveData.Moves[a.move].startup + 1
		a.ghost = true
		d.state = "Hitstun"
		d.hitstop = if tick - data.Hits[k] < 6 then 1 else 0
		local angles = {
			{ Vector3.new(-dir * 4, 2.5, 5), 40, math.rad(6) },   -- over the attacker's shoulder
			{ Vector3.new(dir * 3.5, 0.5, 4.5), 34, 0 },         -- in the target's face
			{ Vector3.new(0.3, 13, 1.5), 55, 0 },                -- top-down
			{ Vector3.new(-dir * 2, -3, 7), 50, math.rad(-14) }, -- dutch angle from the floor
			{ Vector3.new(dir * 9, 3, 9), 38, 0 },               -- wide three-quarter
		}
		local view = angles[(k - 1) % #angles + 1]
		return "strike" .. k, pd + view[1], pd, view[2], view[3]
	elseif tick < data.FinalTick - 12 then
		-- 5. Sky leap: KAI rises above the target, seen from the ground.
		local progress = (tick - (data.Hits[#data.Hits] + 4)) / (data.FinalTick - 12 - data.Hits[#data.Hits] - 4)
		a.x, a.y, a.facing = d.x - dir * 1.5, lerp(1, 11, progress), dir
		a.state, a.move, a.moveFrame = "Attack", "AirSmash", 1
		d.state = "Hitstun"
		return "sky", pd + Vector3.new(-dir * 3, -3.4, 6), Vector3.new(a.x, a.y + 3, 0), 60, math.rad(10 * dir)
	elseif tick < data.FinalTick then
		-- 6. The dive.
		local progress = (tick - (data.FinalTick - 12)) / 12
		a.x, a.y, a.facing = d.x - dir * 1.8, lerp(11, d.y + 1, progress), dir
		a.state, a.move = "Attack", "AirSmash"
		a.moveFrame = MoveData.Moves.AirSmash.startup + 1
		a.ghost = true
		d.state = "Hitstun"
		return "dive", pd + Vector3.new(dir * 6, 4, 7), pd + Vector3.new(0, 2, 0), 44, 0
	elseif tick < data.FinalTick + 14 then
		-- 7. Impact: wide frame, shockwave.
		a.x, a.y, a.facing = d.x - dir * 1.8, 0, dir
		a.state, a.move = "Attack", "AirSmash"
		a.moveFrame = MoveData.Moves.AirSmash.startup + 1
		if not self.shockwaveDone then
			self.shockwaveDone = true
			self.effects:shockwave(Vector3.new(d.x, 0, 0), energy)
		end
		local mid = Vector3.new(d.x, 3, 0)
		return "impact", mid + Vector3.new(0, 6, 34), mid, 46, 0
	elseif not cin.finish or tick < data.Length then
		-- 8. Aftermath: KAI lands in a kiai, the target flies (or falls).
		a.x, a.y, a.facing, a.pose = a.x, 0, dir, "Kiai"
		local mid = Vector3.new((a.x + d.x) / 2, 3, 0)
		return "aftermath", mid + Vector3.new(-dir * 4, 3, 26), mid, 42, 0
	end
	-- FINAL FINISH: several points of view on the fall and the K.O.
	local t = tick - data.Length
	self.mono.Enabled = not reduced and t < 30
	if t < 30 then
		-- a. Slow-motion close-up: the target falls, frozen in black and white.
		local progress = t / 30
		d.y, d.pose = lerp(4, 1.2, progress), "Launched"
		d.state = "KO"
		local head = Vector3.new(d.x, d.y + 4, 0)
		self:showTitle("FINAL FINISH", RED)
		return "finish-fall", head + Vector3.new(dir * 2.5, 0.6, 3.5), head, 30, math.rad(-12)
	elseif t < 58 then
		-- b. Ground-level profile as the body hits the floor.
		d.y, d.pose, d.state = 0, "DownFace", "KO"
		if not self.dustDone then
			self.dustDone = true
			self.effects:dust(d.x, 0, -dir)
			self.effects:dust(d.x + dir, 0, dir)
			self.shake = math.max(self.shake, if reduced then 0.3 else 0.8)
		end
		self:showTitle("K.O.", RED)
		local floor = Vector3.new(d.x, 0.6, 0)
		return "finish-floor", floor + Vector3.new(-dir * 7, 0.2, 4), floor, 44, 0
	elseif t < 84 then
		-- c. Top-down on the fallen fighter.
		d.y, d.pose, d.state = 0, "DownFace", "KO"
		local floor = Vector3.new(d.x, 0, 0)
		return "finish-top", floor + Vector3.new(0.2, 15, 2.5), floor, 40, math.rad(90)
	end
	-- d. KAI turns his back, the fallen opponent behind him: the classic last frame.
	d.y, d.pose, d.state = 0, "DownFace", "KO"
	a.x, a.y, a.pose = d.x - dir * 4, 0, "ArmsCrossed"
	a.facing = -dir
	self:showTitle("FINAL FINISH", WHITE)
	local back = Vector3.new(a.x, 4.6, 0)
	return "finish-back", back + Vector3.new(-dir * 3.2, 0.6, -0.5) + Vector3.new(0, 0, 4.5),
		Vector3.new(d.x, 1.5, 0), 34, 0
end

-- Returns true while the cinematic owns the camera.
function CinematicController:update(world, views, dt, stale)
	local cin = world.cinematic
	if not cin or stale then
		if self.active then self:finish() end
		self.dir, self.shockwaveDone, self.dustDone = nil, nil, nil
		return false
	end
	if not self.active then self:begin() end
	local tick = math.min(cin.tick + math.floor((os.clock() - (self.snapshotAt or os.clock())) * self.config.TickRate), cin.length)
	local a, d = views[cin.attacker], views[cin.defender]
	if not a or not d then return true end
	self.dir = self.dir or a.facing
	a.victory, a.pose, d.pose = false, nil, nil
	local shot, position, target, fov, roll
	if cin.move == "Awakening" then
		shot, position, target, fov, roll = self:directAwakening(cin, a, d, tick, self.dir, os.clock())
	else
		shot, position, target, fov, roll = self:directRush(cin, a, d, tick, self.dir)
	end
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local goal = CFrame.lookAt(position, target) * CFrame.Angles(0, 0, roll or 0)
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
