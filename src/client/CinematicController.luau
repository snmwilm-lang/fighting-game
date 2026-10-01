--[[
	Staging of every cinematic moment. The simulation decides everything (hits, damage, KO,
	duration, rhythm prompts); this module only directs it:

	  KAIEN RUSH        ultimate 1 (R alone): blinking rush around the target.
	  ÉVEIL ÉCARLATE    ultimate 2 (clean full route ending on the right click): eyes, aura,
	                    strikes from many angles, then one of six finales picked by the route.
	  PORTE DES CIEUX   ultimate 3 (clean full route ending on the R key): a giant torii drags
	                    the target into a crimson world for a single blow.
	  K.O. SCENE        FINAL FINISH and match-winning K.O.: loser on the floor in the
	                    foreground, winner standing (low angle), hand on the floor, feet,
	                    face, arms crossed, back, wide arena shot, fade to black.

	Shots are described with points tied to rig parts (Head, RightHand, LeftFoot...), resolved
	after the rigs are placed, so framing works on KAI and on any Roblox avatar alike.
	The camera returns to the fight camera as soon as nothing is staged, or if snapshots stop
	arriving (disconnect), so it can never stay stuck.
]]
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local MoveData = require(Shared.MoveData)
local CharacterData = require(Shared.CharacterData)
local Director = require(Shared.CinematicDirector)
local RigReader = require(Shared.RigReader)

local CinematicController = {}

local WHITE = Color3.fromHex("F5F5F7")
local INK = Color3.fromHex("0B0B0E")
local RED = Color3.fromHex("E0102B")
local GOLD = Color3.fromHex("FFD23F")
local PROMPT_LABEL = { Light = "CLIC G", Heavy = "CLIC D", Ultimate = "R" }

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
	local self = setmetatable({
		config = config, hud = hud, effects = effects, active = false, shake = 0, shot = nil,
		props = {},
	}, { __index = CinematicController })
	local gui = new("ScreenGui", { Name = "Cinematic", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20 },
		Players.LocalPlayer:WaitForChild("PlayerGui"))
	self.gui = gui
	self.kanjiBack = new("TextLabel", {
		BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, Text = "", Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.72, 0.5), Size = UDim2.fromScale(0.5, 0.9),
		TextColor3 = RED, TextTransparency = 0.35,
	}, gui)
	self.top = new("Frame", { BackgroundColor3 = INK, BorderSizePixel = 0, Size = UDim2.fromScale(1, 0) }, gui)
	self.bottom = new("Frame", { BackgroundColor3 = INK, BorderSizePixel = 0, Size = UDim2.fromScale(1, 0),
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1) }, gui)
	self.flashFrame = new("Frame", { BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui)
	self.fade = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5 }, gui)

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
		BackgroundTransparency = 1, Font = Enum.Font.Bangers, TextSize = 90, TextColor3 = WHITE, Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.8), Size = UDim2.new(1, 0, 0, 100), Rotation = -4,
	}, gui)
	new("UIStroke", { Thickness = 6, Color = INK }, self.stamp)
	self.stampScale = new("UIScale", {}, self.stamp)
	self.title = new("TextLabel", {
		BackgroundTransparency = 1, Font = Enum.Font.Bangers, TextSize = 150, TextColor3 = RED, Visible = false, ZIndex = 6,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.new(1, 0, 0, 160), Rotation = -3,
	}, gui)
	new("UIStroke", { Thickness = 8, Color = WHITE }, self.title)
	self.titleScale = new("UIScale", {}, self.title)
	self.subtitle = new("TextLabel", {
		BackgroundTransparency = 1, Font = Enum.Font.Bangers, TextSize = 46, TextColor3 = WHITE, Visible = false, ZIndex = 6,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.new(1, 0, 0, 50),
	}, gui)
	new("UIStroke", { Thickness = 4, Color = INK }, self.subtitle)

	-- Rhythm prompt: key in a circle, and a ring closing in on the perfect moment.
	local prompt = new("Frame", {
		Name = "Prompt", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.7),
		Size = UDim2.fromOffset(110, 110), BackgroundColor3 = INK, BackgroundTransparency = 0.15, Visible = false, ZIndex = 4,
	}, gui)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, prompt)
	new("UIStroke", { Thickness = 4, Color = WHITE }, prompt)
	self.promptLabel = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Enum.Font.Bangers, TextSize = 34,
		TextColor3 = WHITE, ZIndex = 4,
	}, prompt)
	local ring = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(2, 2),
		BackgroundTransparency = 1, ZIndex = 4,
	}, prompt)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
	self.promptRingStroke = new("UIStroke", { Thickness = 5, Color = RED }, ring)
	self.prompt, self.promptRing = prompt, ring
	self.promptResult = new("TextLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.58),
		Size = UDim2.new(1, 0, 0, 50), Font = Enum.Font.Bangers, TextSize = 44, Visible = false, ZIndex = 4,
	}, gui)
	new("UIStroke", { Thickness = 4, Color = INK }, self.promptResult)

	-- Debug readout (HITBOX on, or a cinematic launched from the lab): shot name and tick, so
	-- a badly framed shot can be reported precisely.
	self.debugLabel = new("TextLabel", {
		BackgroundColor3 = INK, BackgroundTransparency = 0.25, Font = Enum.Font.Code, TextSize = 16,
		TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, Visible = false, ZIndex = 8,
		Position = UDim2.new(0, 12, 0.13, 0), Size = UDim2.fromOffset(460, 24),
	}, gui)

	-- Anime speed lines: thin rays from the edges toward the centre, redrawn every frame.
	local lines = new("Frame", { Name = "SpeedLines", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 2 }, gui)
	self.speedLines, self.speedRays = lines, {}
	for i = 1, 30 do
		self.speedRays[i] = new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5), BorderSizePixel = 0, BackgroundColor3 = WHITE, ZIndex = 2,
			Rotation = i / 30 * 360,
		}, lines)
	end
	self.fovKick = 0

	local function grade(name, props)
		return new("ColorCorrectionEffect", props, Lighting)
	end
	self.darken = grade("SuperFlash", { Name = "SuperFlash", Enabled = false, Brightness = -0.22, Saturation = -0.55, Contrast = 0.2 })
	self.crimson = grade("Crimson", { Name = "Crimson", Enabled = false, TintColor = Color3.fromRGB(255, 120, 125), Contrast = 0.3, Saturation = 0.15, Brightness = -0.05 })
	self.void = grade("Void", { Name = "Void", Enabled = false, TintColor = Color3.fromRGB(255, 70, 80), Contrast = 0.55, Saturation = -0.3, Brightness = -0.28 })
	self.mono = grade("FinishMono", { Name = "FinishMono", Enabled = false, Saturation = -1, Contrast = 0.6, Brightness = 0.02 })
	-- Each kit's own grade: TARO's fire, ZEPHYR's sky, AKEMI's shadow.
	self.fire = grade("Fire", { Name = "KitFire", Enabled = false, TintColor = Color3.fromRGB(255, 180, 120), Contrast = 0.25, Saturation = 0.25, Brightness = 0.02 })
	self.sky = grade("Sky", { Name = "KitSky", Enabled = false, TintColor = Color3.fromRGB(190, 230, 255), Contrast = 0.1, Saturation = -0.15, Brightness = 0.06 })
	self.shadowGrade = grade("Shadow", { Name = "KitShadow", Enabled = false, TintColor = Color3.fromRGB(175, 150, 230), Contrast = 0.45, Saturation = -0.35, Brightness = -0.12 })
	-- RYUKEN's rage (hot red, hard contrast), SHIN's current (cold steel), DAICHA's inverted
	-- shadow (deep violet), HIBECARES' ruin (dusty sepia).
	self.rage = grade("Rage", { Name = "KitRage", Enabled = false, TintColor = Color3.fromRGB(255, 150, 130), Contrast = 0.42, Saturation = 0.3, Brightness = -0.04 })
	self.current = grade("Current", { Name = "KitCurrent", Enabled = false, TintColor = Color3.fromRGB(165, 210, 245), Contrast = 0.32, Saturation = -0.45, Brightness = 0.02 })
	self.inverse = grade("Inverse", { Name = "KitInverse", Enabled = false, TintColor = Color3.fromRGB(215, 135, 255), Contrast = 0.6, Saturation = 0.05, Brightness = -0.2 })
	self.ruin = grade("Ruin", { Name = "KitRuin", Enabled = false, TintColor = Color3.fromRGB(235, 205, 160), Contrast = 0.3, Saturation = -0.45, Brightness = -0.02 })
	self.dof = new("DepthOfFieldEffect", { Name = "CinematicDoF", Enabled = false, FarIntensity = 0.65, NearIntensity = 0.35, InFocusRadius = 4 }, Lighting)
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

function CinematicController:begin(kind)
	self.active, self.kind = true, kind
	self.hud.gui.Enabled = false
	self.titleShown, self.memo, self.anchors, self.gate = nil, {}, {}, nil
	self.cinClock, self.displayTick = nil, nil
	tween(self.top, 0.18, { Size = UDim2.fromScale(1, 0.12) })
	tween(self.bottom, 0.18, { Size = UDim2.fromScale(1, 0.12) })
end

function CinematicController:showDebug(label, tick, length)
	self.debugInfo = { label = label, tick = tick, length = length }
end

function CinematicController:finish()
	self.active, self.shot, self.kind, self.dir = false, nil, nil, nil
	self.displayTick, self.cinClock = nil, nil
	self.debugLabel.Visible, self.labRequested = false, false
	self.hud.gui.Enabled = true
	for _, effect in { self.darken, self.crimson, self.void, self.mono, self.dof, self.fire, self.sky, self.shadowGrade,
		self.rage, self.current, self.inverse, self.ruin } do
		effect.Enabled = false
	end
	self.handheld = 0
	self.stamp.Visible, self.title.Visible, self.subtitle.Visible, self.kanjiBack.Visible = false, false, false, false
	self.prompt.Visible, self.promptResult.Visible = false, false
	self.speedLines.Visible, self.speedColor, self.fovKick = false, nil, 0
	tween(self.fade, 0.4, { BackgroundTransparency = 1 })
	tween(self.top, 0.25, { Size = UDim2.fromScale(1, 0) })
	tween(self.bottom, 0.25, { Size = UDim2.fromScale(1, 0) })
	for _, prop in self.props do
		if typeof(prop) == "Instance" then prop:Destroy() end
	end
	self.props = {}
end

-- Runs `fn` once per staged moment (memo keys are reset at every new cinematic).
function CinematicController:once(key, fn)
	if self.memo[key] then return end
	self.memo[key] = true
	fn()
end

function CinematicController:flash(duration)
	if self.effects.reduced then return end
	self.flashFrame.BackgroundTransparency = 0
	tween(self.flashFrame, duration or 0.35, { BackgroundTransparency = 1 })
end

-- Hit / rhythm stamp. It hides itself: events arrive on their own remote and can come just
-- after the snapshot that ended the cinematic, so finish() alone could leave it on screen.
function CinematicController:showStamp(text, color)
	self.stamp.Text, self.stamp.TextColor3 = text, color
	self.stamp.Visible = true
	self.stampScale.Scale = 2.2
	tween(self.stampScale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	local id = (self.stampId or 0) + 1
	self.stampId = id
	task.delay(1.2, function()
		if self.stampId == id then self.stamp.Visible = false end
	end)
end

function CinematicController:showTitle(text, color, subtitle)
	if self.titleShown == text then return end
	self.titleShown = text
	self.title.Text, self.title.TextColor3, self.title.Visible = text, color, true
	self.titleScale.Scale = 3
	tween(self.titleScale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	self.subtitle.Text, self.subtitle.Visible = subtitle or "", subtitle ~= nil
end

function CinematicController:hideTitle()
	self.title.Visible, self.subtitle.Visible, self.titleShown = false, false, nil
end

function CinematicController:onHit(event)
	local reduced = self.effects.reduced
	self.shake = math.max(self.shake, (if event.heavy then 1.6 else 0.4) * (if reduced then 0.4 else 1))
	if event.heavy then
		self:flash()
		local m = MoveData.Moves[event.move]
		self:showStamp((if m then m.name else event.move) .. " !!", Color3.fromHex(CharacterData[event.attacker].Energy))
		local cin = MoveData.Cinematics[event.move]
		if not (cin and cin.Type == "Rush") and not reduced then
			self.mono.Enabled, self.monoBeat = true, true -- manga impact: one black-and-white beat
			task.delay(0.14, function() self.monoBeat = false end)
		end
	end
end

function CinematicController:onPrompt(event)
	if event.attacker ~= (Players.LocalPlayer:GetAttribute("FighterSlot") or 0) and not self.showAllPrompts then
		-- Prompts of the CPU or the other player are shown smaller, as information.
		self.promptResult.TextSize = 30
	else
		self.promptResult.TextSize = 44
	end
	self.promptResult.Text = if event.success then "PARFAIT !" else "RATÉ"
	self.promptResult.TextColor3 = if event.success then GOLD else Color3.fromHex("8A8A96")
	self.promptResult.Visible = true
	local id = (self.promptId or 0) + 1
	self.promptId = id
	task.delay(0.4, function()
		if self.promptId == id then self.promptResult.Visible = false end
	end)
end

function CinematicController:onGrade(event)
	local color = if event.grade == "PARFAIT" then GOLD elseif event.grade == "GRAND" then WHITE else Color3.fromHex("8A8A96")
	self:showStamp("RYTHME : " .. event.grade, color)
end

-- Ring closing in on the next prompt. Only the attacker's controller decides; this is a hint.
function CinematicController:updatePrompt(cin, tick)
	local prompts = cin.prompts
	local nextPrompt = prompts and prompts[cin.nextPrompt]
	if not nextPrompt or tick < nextPrompt.tick - 30 then
		self.prompt.Visible = false
		return
	end
	local t = (nextPrompt.tick - tick) / 30
	self.prompt.Visible = true
	self.promptLabel.Text = PROMPT_LABEL[nextPrompt.button] or nextPrompt.button
	self.promptRing.Size = UDim2.fromScale(1 + math.max(0, t) * 1.4, 1 + math.max(0, t) * 1.4)
	self.promptRingStroke.Color = if math.abs(tick - nextPrompt.tick) <= 3 then GOLD else RED
end

-- ===================================================================== FRAME

local function vec(t)
	return Vector3.new(t.x, t.y, t.z or 0)
end

-- Plays the effect requests of a director frame (each key once per cinematic).
function CinematicController:applyFx(frame)
	local fx = self.effects
	for _, request in frame.fx do
		if not self.memo[request.key] then
			self.memo[request.key] = true
			local kind, color = request.kind, request.color and Color3.fromHex(request.color)
			local prop
			if kind == "tornadoRing" then fx:tornadoRing(vec(request.pos), color)
			elseif kind == "spark" then fx:spark(vec(request.pos), color, request.scale or 1)
			elseif kind == "dragonHelix" then fx:dragonHelix(vec(request.pos), color)
			elseif kind == "lightning" then fx:lightning(vec(request.from), vec(request.to), color)
			elseif kind == "shockwave" then fx:shockwave(vec(request.pos), color)
			elseif kind == "dust" then fx:dust(request.pos.x, request.pos.y, request.direction or 1)
			elseif kind == "arc" then fx:arc(vec(request.pos), request.radius, request.from, request.to, color, request.tilt, request.dir)
			elseif kind == "crescent" then prop = fx:crescent(vec(request.pos), color)
			elseif kind == "kanjiSeal" then prop = fx:kanjiSeal(vec(request.pos), color, request.text)
			elseif kind == "gate" then
				prop = fx:gate(vec(request.pos), request.dir, color)
				self.gate = prop
			elseif kind == "gateOpen" then fx:gateOpen(self.gate)
			elseif kind == "gateShatter" then fx:gateShatter(self.gate, color)
			elseif kind == "rocks" then prop = fx:rocks(vec(request.pos), request.radius, request.count or 8, color)
			elseif kind == "debris" then fx:debris(vec(request.pos), color, request.scale or 1)
			elseif kind == "crack" then fx:crack(vec(request.from), vec(request.to), color)
			elseif kind == "cut" then fx:cut(vec(request.from), vec(request.to), color)
			elseif kind == "eclipse" then prop = fx:eclipse(vec(request.pos), color, request.scale or 1, request.life)
			elseif kind == "smoke" then fx:smoke(vec(request.pos))
			end
			if prop then table.insert(self.props, prop) end
		end
	end
	if frame.aura then
		local rig = fx.rigs and fx.rigs[frame.aura]
		if rig and rig.aura then rig.aura:Emit(if fx.reduced then 1 else 3) end
	end
end

-- Applies grading, overlays and titles of a director frame.
function CinematicController:applyFrame(frame)
	local reduced = self.effects.reduced
	self.crimson.Enabled = frame.grade.crimson and not reduced
	self.void.Enabled = frame.grade.void and not reduced
	self.fire.Enabled = frame.grade.fire == true and not reduced
	self.sky.Enabled = frame.grade.sky == true and not reduced
	self.shadowGrade.Enabled = frame.grade.shadow == true and not reduced
	self.rage.Enabled = frame.grade.rage == true and not reduced
	self.current.Enabled = frame.grade.current == true and not reduced
	self.inverse.Enabled = frame.grade.inverse == true and not reduced
	self.ruin.Enabled = frame.grade.ruin == true and not reduced
	-- TARO's handheld camera: a slow constant sway (smaller in reduced mode).
	self.handheld = (frame.handheld or 0) * (if reduced then 0.3 else 1)
	-- A jolt of the camera (HIBECARES' blows shaking the deck).
	if frame.quake then self.shake = math.max(self.shake, frame.quake * (if reduced then 0.4 else 1)) end
	if frame.grade.mono then
		self.mono.Enabled = not reduced
	elseif not self.monoBeat then
		self.mono.Enabled = false
	end
	self.kanjiBack.Visible = frame.kanjiBack ~= nil
	if frame.kanjiBack then self.kanjiBack.Text = frame.kanjiBack end
	if frame.title then
		self:showTitle(frame.title.text, Color3.fromHex(frame.title.color), frame.title.sub)
	elseif frame.hideTitle then
		self:hideTitle()
	end
	-- Speed lines while the frame asks for them (off in reduced mode).
	self.speedColor = if frame.speedLines and not reduced then Color3.fromHex(frame.speedLines) else nil
	-- Impact frame and a zoom punch, once per key.
	if frame.impact and not self.memo["impact:" .. frame.impact.key] then
		self.memo["impact:" .. frame.impact.key] = true
		local color = Color3.fromHex(frame.impact.color)
		self.fovKick = if reduced then 3 else 9
		self.shake = math.max(self.shake, if reduced then 0.3 else 0.9)
		self.effects:impactFrame(color, if reduced then 0.6 else 1.4)
	end
	if frame.fade and not self.memo.fade then
		self.memo.fade = true
		tween(self.fade, 0.35, { BackgroundTransparency = 0 })
	end
	self:applyFx(frame)
	self.pending = frame.shot
end

-- Lab: plays the K.O. scene on the current fighters, without any K.O. (client only).
function CinematicController:previewKO(winner)
	if winner < 1 then return end
	self.preview = { start = os.clock(), winner = winner, loser = 3 - winner }
	self.labRequested = true
end

-- Stages poses and positions (before the rigs are placed). Returns true while active.
function CinematicController:update(world, views, dt, stale)
	local cin = world.cinematic
	local ctx = { views = views, moveData = MoveData, config = self.config, characters = CharacterData }
	if self.preview and not cin and not stale then
		local t = math.floor((os.clock() - self.preview.start) * self.config.TickRate)
		if t <= Director.KO_SCENE + 30 then
			if not self.active or self.kind ~= "preview" then
				if self.active then self:finish() end
				self:begin("preview")
			end
			local w, l = views[self.preview.winner], views[self.preview.loser]
			if w and l then
				ctx.anchors = self.anchors
				self:applyFrame(Director.ko(ctx, self.preview.winner, self.preview.loser, w, l, math.min(t, Director.KO_SCENE)))
				self:showDebug("apercu-ko", t, Director.KO_SCENE)
			end
			return true
		end
		self.preview = nil
	end
	local winner, loser, koTick
	if not cin and not stale and world.epoch ~= self.finishEpoch then
		-- (a FINAL FINISH already played its own K.O. scene for this round)
		winner, loser, koTick = Director.victoryScene(world, self.config)
	end
	if stale or (not cin and not winner) then
		if self.active then self:finish() end
		self.pending = nil
		return false
	end
	local kind = if cin then cin.move else "ko"
	if not self.active or self.kind ~= kind then
		if self.active then self:finish() end
		self:begin(kind)
	end
	ctx.anchors = self.anchors
	if cin then
		-- A smooth, monotonic cinematic clock: it runs at the slow-motion speed between
		-- snapshots and eases toward the server's tick, so a late or bunched snapshot (a far
		-- player) never makes the shots jump back; a big gap (new cinematic) snaps.
		local speed = self.config.TickRate * (cin.scale or 1)
		local target = cin.tick + (os.clock() - (self.snapshotAt or os.clock())) * speed
		local clock = self.cinClock
		if not clock or math.abs(target - clock) > 15 then
			clock = target
		else
			clock = math.max(clock, clock + dt * speed + (target - (clock + dt * speed)) * math.min(1, dt * 3))
		end
		self.cinClock = clock
		local tick = math.min(math.floor(clock), cin.length)
		self.displayTick = tick -- sent with QTE presses (lag compensation)
		self:updatePrompt(cin, tick)
		self:showDebug(cin.move .. (if cin.style then "/" .. cin.style else "") .. (if cin.finish then "/FINISH" else ""),
			tick, cin.length)
		if cin.finish then self.finishEpoch = world.epoch end
		ctx.cin, ctx.tick = cin, tick
		local frame = Director.cinematic(ctx)
		if frame then self:applyFrame(frame) end
	else
		local w, l = views[winner], views[loser]
		if not w or not l then return true end
		self.prompt.Visible = false
		self:applyFrame(Director.ko(ctx, winner, loser, w, l, koTick))
		self:showDebug("ko", koTick, Director.KO_SCENE)
	end
	return true
end

local function resolve(point, rigs, views)
	if point.position then return vec(point.position) end
	local offset = vec(point.offset)
	local rig = rigs[point.slot]
	if rig then
		local _, position = RigReader.part(rig.model, point.part)
		if position then return position + offset end
	end
	local v = views[point.slot]
	return Vector3.new(v and v.x or 0, (v and v.y or 0) + 3.5, v and v.z or 0) + offset
end

-- Places the camera on the staged shot (after the rigs are placed, so parts are current).
function CinematicController:camera(dt, rigs, views)
	local s = self.pending
	if not s then return end
	local position, target = resolve(s.from, rigs, views), resolve(s.to, rigs, views)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local goal = CFrame.lookAt(position, target) * CFrame.Angles(0, 0, s.roll)
	if s.name ~= self.shot then
		-- Anime-style hard cut between shots, with a tiny push-in afterwards.
		self.shot, self.cameraCFrame, self.shotTime = s.name, goal, 0
	else
		self.cameraCFrame = self.cameraCFrame:Lerp(goal, 1 - math.exp(-14 * dt))
	end
	self.shotTime = (self.shotTime or 0) + dt
	local push = self.cameraCFrame.LookVector * math.min(self.shotTime, 1.2) * 0.6
	local shake = Vector3.zero
	if (self.handheld or 0) > 0 then
		local t = os.clock()
		shake = Vector3.new(math.sin(t * 2.3) + math.sin(t * 5.1) * 0.4, math.sin(t * 1.7 + 1) + math.sin(t * 4.3) * 0.3, 0) * self.handheld
	end
	if self.shake > 0.01 then
		shake += Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * self.shake
		self.shake *= math.exp(-9 * dt)
	end
	-- Zoom punch: the field of view snaps in on an impact and eases back.
	camera.FieldOfView = s.fov - self.fovKick
	self.fovKick *= math.exp(-10 * dt)
	self:drawSpeedLines()
	local info = self.debugInfo
	self.debugLabel.Visible = (self.effects.debug or self.labRequested) and info ~= nil
	if self.debugLabel.Visible then
		self.debugLabel.Text = string.format(" %s · plan %s · tick %d/%d · FOV %d", info.label, s.name, info.tick, info.length, s.fov)
	end
	camera.CFrame = (self.cameraCFrame + push) + self.cameraCFrame:VectorToWorldSpace(shake)
	-- Depth of field on the subject (off in reduced mode).
	local focus = resolve(s.focus, rigs, views)
	self.dof.Enabled = not self.effects.reduced
	self.dof.FocusDistance = (camera.CFrame.Position - focus).Magnitude
	self.dof.InFocusRadius = math.max(2.5, self.dof.FocusDistance * 0.18)
end

function CinematicController:drawSpeedLines()
	local color = self.speedColor
	self.speedLines.Visible = color ~= nil and self.active
	if not self.speedLines.Visible then return end
	for i, ray in self.speedRays do
		local angle = math.rad(ray.Rotation)
		local start = 0.3 + math.random() * 0.18 -- distance from the centre, share of the screen
		ray.Position = UDim2.fromScale(0.5 + math.cos(angle) * start, 0.5 + math.sin(angle) * start)
		ray.Size = UDim2.new(0.25 + math.random() * 0.3, 0, 0, 1 + math.random(0, 3))
		ray.BackgroundColor3 = if i % 3 == 0 then color else WHITE
		ray.BackgroundTransparency = 0.25 + math.random() * 0.45
	end
end

function CinematicController:snapshot()
	self.snapshotAt = os.clock()
end

return CinematicController
