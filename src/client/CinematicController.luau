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
local KiBall = require(Shared.KiBall)
Director.useFinishers(require(Shared.Finishers)) -- (the FATAL FINISHERS' scenes)

local CinematicController = {}

local WHITE = Color3.fromHex("F5F5F7")
local INK = Color3.fromHex("0B0B0E")
local RED = Color3.fromHex("E0102B")
local GOLD = Color3.fromHex("FFD23F")

local function vec(t)
	return Vector3.new(t.x, t.y, t.z or 0)
end

-- The grade of each themed kit (CinematicDirector THEMES).
local THEME_GRADES = {
	asura = { TintColor = Color3.fromRGB(255, 215, 140), Contrast = 0.55, Saturation = -0.35, Brightness = -0.12 }, -- black and gold
	storm = { TintColor = Color3.fromRGB(225, 225, 255), Contrast = 0.5, Saturation = -0.3, Brightness = -0.06 }, -- RAIJIN
	frost = { TintColor = Color3.fromRGB(200, 235, 255), Contrast = 0.2, Saturation = -0.5, Brightness = 0.08 }, -- YUKINA
	toxic = { TintColor = Color3.fromRGB(190, 255, 170), Contrast = 0.4, Saturation = -0.1, Brightness = -0.12 }, -- VENOM
	titan = { TintColor = Color3.fromRGB(255, 190, 170), Contrast = 0.45, Saturation = -0.2, Brightness = -0.06 }, -- GORAN
	cosmos = { TintColor = Color3.fromRGB(190, 180, 255), Contrast = 0.5, Saturation = 0.1, Brightness = -0.16 }, -- ASTER
	sonic = { TintColor = Color3.fromRGB(255, 190, 235), Contrast = 0.35, Saturation = 0.3, Brightness = 0.02 }, -- HIBIKI
	divine = { TintColor = Color3.fromRGB(255, 245, 210), Contrast = 0.3, Saturation = -0.15, Brightness = 0.14 }, -- KUROEN SHIN (white and gold)
	eclipse = { TintColor = Color3.fromRGB(255, 120, 130), Contrast = 0.65, Saturation = -0.45, Brightness = -0.24 }, -- KUROEN (the light goes out)
	iron = { TintColor = Color3.fromRGB(225, 215, 195), Contrast = 0.45, Saturation = -0.7, Brightness = -0.08 }, -- KAZAN
	blood = { TintColor = Color3.fromRGB(255, 150, 160), Contrast = 0.55, Saturation = -0.2, Brightness = -0.14 }, -- KUREN
	wild = { TintColor = Color3.fromRGB(205, 245, 185), Contrast = 0.25, Saturation = 0.2, Brightness = 0 }, -- SYLVA
	holy = { TintColor = Color3.fromRGB(255, 245, 215), Contrast = 0.15, Saturation = -0.2, Brightness = 0.12 }, -- ELIAN
	tech = { TintColor = Color3.fromRGB(255, 205, 160), Contrast = 0.4, Saturation = -0.25, Brightness = -0.04 }, -- NOVA
}
local PROMPT_LABEL = { Light = "L-CLICK", Heavy = "R-CLICK", Ultimate = "R" }

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
	-- The grades of the themed kits (CinematicDirector THEMES), one per kit.
	self.themeGrades = {}
	for name, props in THEME_GRADES do
		local cc = grade(name, props)
		cc.Name, cc.Enabled = "Kit_" .. name, false
		self.themeGrades[name] = cc
	end
	self.dof = new("DepthOfFieldEffect", { Name = "CinematicDoF", Enabled = false, FarIntensity = 0.65, NearIntensity = 0.35, InFocusRadius = 4 }, Lighting)
	-- FATAL FINISHERS (Finishers.luau): the colour drained, a blur pulse, the K.O. written into
	-- the scene, the 3D light of the shapes (a pool of parts), the screen split in two.
	self.finisherBlur = new("BlurEffect", { Name = "FinisherBlur", Enabled = false, Size = 0 }, Lighting)
	self.finisherDesat = new("ColorCorrectionEffect", { Name = "FinisherDesat", Enabled = false, Saturation = 0 }, Lighting)
	self.koLabel = new("TextLabel", {
		BackgroundTransparency = 1, Font = Enum.Font.Bangers, TextScaled = true, Text = "K.O.", TextColor3 = WHITE, Visible = false, ZIndex = 7,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(0.7, 0.32),
	}, gui)
	self.koStroke = new("UIStroke", { Thickness = 6, Color = RED }, self.koLabel)
	self.koScale = new("UIScale", {}, self.koLabel)
	self.koSub = new("TextLabel", {
		BackgroundTransparency = 1, Font = Enum.Font.Bangers, TextScaled = true, Text = "", TextColor3 = WHITE, Visible = false, ZIndex = 7,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.66), Size = UDim2.fromScale(0.6, 0.07),
	}, gui)
	new("UIStroke", { Thickness = 3, Color = INK }, self.koSub)
	-- a count slammed in at the side of the screen (RYUKEN's ten fists of rage)
	self.captionLabel = new("TextLabel", {
		BackgroundTransparency = 1, Font = Enum.Font.Bangers, TextScaled = true, Text = "", TextColor3 = WHITE, Visible = false, ZIndex = 7,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.85, 0.5), Size = UDim2.fromScale(0.24, 0.3),
	}, gui)
	self.captionStroke = new("UIStroke", { Thickness = 5, Color = INK }, self.captionLabel)
	self.captionScale = new("UIScale", {}, self.captionLabel)
	-- a night (or any) tint over the whole scene (SHIN's FINAL DIVISION)
	self.finisherTint = new("ColorCorrectionEffect", { Name = "FinisherTint", Enabled = false }, Lighting)
	-- the screen filled with light (KAI's explosion)
	self.whiteFrame = new("Frame", { Name = "FinisherWhite", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1,
		BorderSizePixel = 0, Visible = false, ZIndex = 6 }, gui)
	-- the K.O. card: the whole screen one colour, a splash behind the letters
	self.koCard = new("Frame", { Name = "KOCard", Size = UDim2.fromScale(1, 1), BackgroundColor3 = INK, BorderSizePixel = 0, Visible = false,
		ZIndex = 6 }, gui)
	self.koSplash = {}
	for i = 1, 9 do
		local big = i <= 3
		local bar = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, BackgroundColor3 = RED, ZIndex = 6,
			Rotation = if big then -18 + (i - 2) * 9 else (i * 47) % 360,
			Position = if big then UDim2.fromScale(0.5 + (i - 2) * 0.05, 0.45 + (i - 2) * 0.04)
				else UDim2.fromScale(0.5 + math.cos(i * 1.7) * 0.32, 0.45 + math.sin(i * 1.3) * 0.28),
			Size = if big then UDim2.fromScale(0.9 - math.abs(i - 2) * 0.2, 0.05 - math.abs(i - 2) * 0.015)
				else UDim2.fromScale(0.02 + (i % 3) * 0.008, 0.035 + (i % 2) * 0.01) }, self.koCard)
		table.insert(self.koSplash, bar)
	end
	self.shapePool, self.fpHidden = {}, {}
	return self
end

-- The effects of the themed kits (CinematicDirector THEMES): each kind is drawn by one of the
-- engine's props in the kit's colour. A request carries from/to (lines) or pos/radius.
local THEME_FX = {
	asuraFist = "rageFist", asuraHalo = "dragonHelix", asuraSeal = "seal",
	spearBolt = "lightning", thunderBurst = "lightningCrown", stormRing = "ring",
	iceShard = "windBlade", frostBloom = "crescentSmall", iceGarden = "ice",
	venomClaw = "cut", venomCloud = "smoke", toxicPool = "orbs",
	titanGrip = "crack", slamQuake = "quake", titanRing = "quakeRing",
	gravityPull = "kiBeam", starCollapse = "eclipse", gravityWell = "orbs",
	soundWave = "waves", soundRing = "tornadoRing", beatRing = "shockwave",
	crimsonFist = "rageFist", eclipseBurst = "eclipse", eclipseSeal = "seal", -- KUROEN
	divineFist = "rageFist", divineHalo = "dragonHelix", divineSeal = "seal", -- KUROEN SHIN
	clawRend = "cut", clawBurst = "crescentSmall", prisonRing = "cage", -- KAZAN's claws
	bloodSpear = "kiBeam", bloodBloom = "crescentSmall", bloodPool = "waterspout",
	vines = "wake", thornBurst = "thorns", roots = "roots",
	lightRay = "lightning", lightPillar = "waterspout", haloRing = "ring",
	droneShot = "orbDart", dronePulse = "shockwave", droneRing = "orbs",
}

function CinematicController:themed(kind, r, color)
	local fx, renderer = self.effects, THEME_FX[kind]
	if not renderer then return nil end
	local from, to = r.from and vec(r.from), r.to and vec(r.to)
	local pos = r.pos and vec(r.pos) or to
	if renderer == "lightning" then fx:lightning(from or pos + Vector3.new(0, 12, 0), to or pos, color)
	elseif renderer == "lightningCrown" then
		for i = 1, 4 do fx:lightning(pos + Vector3.new(math.cos(i * 1.6) * 3, 12, -math.abs(math.sin(i * 1.6)) * 3), pos, color) end
	elseif renderer == "rageFist" then fx:rageFist(from or pos, to or pos, color, r.scale or 1)
	elseif renderer == "dragonHelix" then fx:dragonHelix(Vector3.new(pos.X, 0, pos.Z), color)
	elseif renderer == "seal" or renderer == "ring" then
		fx:arc(pos + Vector3.new(0, 0.1, 0), r.radius or 2.4, 0, 360, color, math.pi / 2, 1)
		fx:shockwave(Vector3.new(pos.X, 0, pos.Z), color)
	elseif renderer == "windBlade" then fx:windBlade(from or pos, to or pos, color, 0, r.scale or 1)
	elseif renderer == "crescentSmall" then fx:arc(pos, 2.2 * (r.scale or 1), -60, 240, color, 0, 1) fx:spark(pos, color, 1.6)
	elseif renderer == "rocks" then return fx:rocks(Vector3.new(pos.X, 0, pos.Z), r.radius or 2.4, r.count or 6, color, r.life)
	-- Each kit's own matter, never HIBECARES' stone: YUKINA's ice, SYLVA's roots, KAZAN's cage.
	elseif renderer == "ice" then return fx:rocks(Vector3.new(pos.X, 0, pos.Z), r.radius or 2.4, r.count or 6, color, r.life, "ice")
	elseif renderer == "roots" then return fx:rocks(Vector3.new(pos.X, 0, pos.Z), r.radius or 2.4, r.count or 6, color, r.life, "wood")
	elseif renderer == "cage" then
		return fx:rocks(Vector3.new(pos.X, 0, pos.Z), r.radius or 2.4, (r.count or 6) + 4, color, r.life, "iron")
	elseif renderer == "quakeRing" then
		-- GORAN: the ring's deck cracks in a star under his weight (no pillars).
		local base = Vector3.new(pos.X, 0.05, pos.Z)
		for i = 1, 6 do
			local angle = i / 6 * math.pi * 2 + 0.3
			fx:crack(base, base + Vector3.new(math.cos(angle), 0, math.sin(angle) * 0.6) * (r.radius or 2.4) * 1.4, color)
		end
		fx:shockwave(Vector3.new(pos.X, 0, pos.Z), color)
		fx:dust(pos.X, 0, 1)
		fx:dust(pos.X, 0, -1)
	elseif renderer == "thorns" then fx:debris(pos, color, r.scale or 1, "thorn")
	elseif renderer == "scrap" then fx:debris(pos, color, r.scale or 1, "iron")
	elseif renderer == "cut" then fx:cut(from or pos, to or pos, color)
	elseif renderer == "smoke" then fx:smoke(pos) fx:spark(pos, color, 1.4)
	elseif renderer == "orbs" then
		return fx:orbs(pos + Vector3.new(0, 1.5, 0), r.radius or 2.4, r.count or 6, color, r.life or 1.2, 0.6, 0, 0.3)
	elseif renderer == "crack" then fx:crack(from or pos, to or pos, color)
	elseif renderer == "quake" then fx:shockwave(Vector3.new(pos.X, 0, pos.Z), color) fx:debris(pos, color, r.scale or 1)
	elseif renderer == "kiBeam" then fx:kiBeam(from or pos, to or pos, color, r.scale or 1)
	elseif renderer == "eclipse" then return fx:eclipse(pos + Vector3.new(0, 2, -2), color, r.scale or 1, 1.2)
	elseif renderer == "waves" then
		for i = 1, 3 do
			fx:arc((from or pos):Lerp(to or pos, i / 4), 1 + i * 0.5, 0, 360, color, 0, 1)
		end
	elseif renderer == "tornadoRing" then fx:tornadoRing(pos, color)
	elseif renderer == "shockwave" then fx:shockwave(Vector3.new(pos.X, 0, pos.Z), color)
	elseif renderer == "ropes" then return fx:ropes(from or pos, to or pos, color, r.life or 1)
	elseif renderer == "sparkBig" then fx:spark(pos, color, 2.4 * (r.scale or 1))
	elseif renderer == "debris" then fx:debris(pos, color, r.scale or 1)
	elseif renderer == "waterspout" then return fx:waterspout(Vector3.new(pos.X, 0, pos.Z), r.radius or 1.6, 7 * (r.scale or 1), color, r.life or 1.2)
	elseif renderer == "wake" then fx:wake(from or pos, to or pos, color, r.life or 1.2)
	elseif renderer == "orbDart" then fx:orbDart(from or pos, to or pos, color)
	end
	return nil
end

-- Super flash: dim the world and slide the cut-in across the screen.
function CinematicController:superFlash(slot, moveId)
	local data = CharacterData[slot]
	local energy = Color3.fromHex(data.Energy)
	local m = MoveData.Moves[moveId or "KaienRush"]
	self.kanji.Text, self.kanji.TextColor3 = data.Kanji, energy
	self.charName.Text = data.Name .. " · " .. (data.Title or data.Skin)
	-- (a boss borrowing another kit's moves names its ultimates itself: ASURA)
	local theme = Director.THEMES[data.Kit]
	local cin = MoveData.Cinematics[moveId or "KaienRush"]
	local name = theme and theme.names and cin and theme.names[cin.Type] or m.name
	self.moveName.Text, self.moveName.TextColor3 = name, energy
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
	-- (the K.O. scenes played: a kit with two victories shows them in turn, CinematicDirector GEN.winPose)
	if kind == "ko" then self.koCount = (self.koCount or 0) + 1 end
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
	for _, cc in self.themeGrades do cc.Enabled = false end
	self.handheld = 0
	self.blackActive = false
	self.kanjiBack.ZIndex = 1
	self.fade.BackgroundColor3 = Color3.new(0, 0, 0)
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
	self:drawMatter(nil)
	self.usesMatter, self.effects.hideOrb = false, false
	self:clearFinisher()
end

-- DAICHA's black matter, staged every frame by the director (frame.matter): one shape per
-- entry, a ball, a disc facing `normal`, a puddle on the floor or an upright wave; a black
-- core with a thin rim of her ki colour. A pool of parts, reused from frame to frame.
local MATTER_BLACK = Color3.fromHex("0B0712")
function CinematicController:drawMatter(list)
	self.matterPool = self.matterPool or {}
	local pool = self.matterPool
	local n = if list then #list else 0
	for i = 1, math.max(n, #pool) do
		local m = list and list[i]
		local item = pool[i]
		if m and not item then
			local core = Instance.new("Part")
			core.Anchored, core.CanCollide, core.CanQuery, core.CanTouch, core.CastShadow = true, false, false, false, false
			core.Material, core.Color, core.Size, core.Name = Enum.Material.SmoothPlastic, MATTER_BLACK, Vector3.one, "Matter"
			local mesh = Instance.new("SpecialMesh")
			mesh.Parent = core
			local rim = core:Clone()
			rim.Material, rim.Transparency, rim.Name = Enum.Material.Neon, 0.55, "MatterRim"
			core.Parent, rim.Parent = self.effects.folder, self.effects.folder
			item = { core = core, rim = rim, mesh = mesh, rimMesh = rim:FindFirstChildOfClass("SpecialMesh") }
			pool[i] = item
		end
		if item then
			if not m then
				item.core.Transparency, item.rim.Transparency = 1, 1
			else
				local pos = Vector3.new(m.pos.x, m.pos.y, m.pos.z or 0)
				local r = m.radius
				local cf, scale
				if m.shape == "disc" or m.shape == "puddle" then
					-- (a cylinder mesh stands along Y: turned so its axis is the disc's normal)
					local n3 = if m.shape == "puddle" then Vector3.yAxis else Vector3.new(m.normal.x, m.normal.y, m.normal.z or 0).Unit
					local side = if math.abs(n3.Y) > 0.9 then Vector3.xAxis else Vector3.yAxis
					local right = side:Cross(n3).Unit
					cf = CFrame.fromMatrix(pos, right, n3)
					item.mesh.MeshType, item.rimMesh.MeshType = Enum.MeshType.Cylinder, Enum.MeshType.Cylinder
					scale = Vector3.new(r * 2, if m.shape == "puddle" then 0.1 else 0.22, r * 2)
				elseif m.shape == "wave" then
					cf = CFrame.new(pos)
					item.mesh.MeshType, item.rimMesh.MeshType = Enum.MeshType.Sphere, Enum.MeshType.Sphere
					scale = Vector3.new(r * 2, math.max(0.1, m.height or r * 2), r * 2)
				else
					cf = CFrame.new(pos)
					item.mesh.MeshType, item.rimMesh.MeshType = Enum.MeshType.Sphere, Enum.MeshType.Sphere
					scale = Vector3.one * r * 2
				end
				item.core.CFrame, item.mesh.Scale, item.core.Transparency = cf, scale, 0
				item.rim.CFrame, item.rimMesh.Scale = cf, scale * 1.06 + Vector3.new(0, 0.02, 0)
				item.rim.Color = if m.color then Color3.fromHex(m.color) else MATTER_BLACK
				item.rim.Transparency = if m.color == "0B0712" then 1 else 0.6
			end
		end
	end
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
	self.promptResult.Text = if event.success then "PERFECT!" else "MISSED"
	self.promptResult.TextColor3 = if event.success then GOLD else Color3.fromHex("8A8A96")
	self.promptResult.Visible = true
	local id = (self.promptId or 0) + 1
	self.promptId = id
	task.delay(0.4, function()
		if self.promptId == id then self.promptResult.Visible = false end
	end)
end

function CinematicController:onGrade(event)
	local color = if event.grade == "PERFECT" then GOLD elseif event.grade == "GREAT" then WHITE else Color3.fromHex("8A8A96")
	self:showStamp("RHYTHM: " .. event.grade, color)
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
			elseif kind == "rocks" then prop = fx:rocks(vec(request.pos), request.radius, request.count or 8, color, request.life)
			elseif kind == "rockLine" then prop = fx:rockLine(vec(request.from), vec(request.to), request.count or 4, color, request.life)
			elseif kind == "rageFist" then fx:rageFist(vec(request.from), vec(request.to), color, request.scale or 1)
			elseif kind == "orbs" then
				prop = fx:orbs(vec(request.pos), request.radius, request.count, color, request.life, request.spin or 0.5, request.phase or 0,
					request.tilt or 0)
			elseif kind == "kiBeam" then fx:kiBeam(vec(request.from), vec(request.to), color, request.scale or 1)
			elseif kind == "windBlade" then fx:windBlade(vec(request.from), vec(request.to), color, request.tilt or 0, request.scale or 1)
			elseif kind == "ropes" then prop = fx:ropes(vec(request.from), vec(request.to), color, request.life or 2)
			elseif kind == "afterimage" then prop = fx:shadowCopy(request.slot, color, request.life or 1)
			elseif kind == "orbDart" then fx:orbDart(vec(request.from), vec(request.to), color)
			elseif kind == "wake" then fx:wake(vec(request.from), vec(request.to), color, request.life or 1.6)
			elseif kind == "waterspout" then prop = fx:waterspout(vec(request.pos), request.radius, request.scale, color, request.life)
			elseif kind == "debris" then fx:debris(vec(request.pos), color, request.scale or 1)
			elseif kind == "crack" then fx:crack(vec(request.from), vec(request.to), color)
			elseif kind == "cut" then fx:cut(vec(request.from), vec(request.to), color)
			elseif kind == "eclipse" then prop = fx:eclipse(vec(request.pos), color, request.scale or 1, request.life)
			elseif kind == "smoke" then fx:smoke(vec(request.pos))
			elseif kind == "matterBurst" then fx:matterBurst(vec(request.pos), color, request.scale or 1)
			elseif kind == "sfx" then
				if self.playSound then self.playSound(request.sound, self.kitOfAttacker) end
			else prop = self:themed(kind, request, color or Color3.new(1, 1, 1))
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
	for name, cc in self.themeGrades do cc.Enabled = frame.grade[name] == true and not reduced end
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
	-- The screen gone black (KAI's COUP FATAL): only the kanji and the flashes of the blows.
	if frame.black ~= nil then
		self.fade.BackgroundTransparency = 1 - frame.black
		self.kanjiBack.ZIndex = 6
		self.blackActive = true
	elseif self.blackActive then
		self.blackActive = false
		self.kanjiBack.ZIndex = 1
		if not self.memo.fade then self.fade.BackgroundTransparency = 1 end
	end
	if frame.impact and not self.memo["impact:" .. frame.impact.key] then
		self.memo["impact:" .. frame.impact.key] = true
		local color = Color3.fromHex(frame.impact.color)
		if (frame.black or 0) > 0.5 and not reduced then
			-- In the black, a blow is a flash of the whole screen.
			self.fade.BackgroundColor3 = color
			tween(self.fade, 0.14, { BackgroundColor3 = Color3.new(0, 0, 0) })
		end
		self.fovKick = if reduced then 3 else 9
		self.shake = math.max(self.shake, if reduced then 0.3 else 0.9)
		self.effects:impactFrame(color, if reduced then 0.6 else 1.4)
	end
	if frame.fade and not self.memo.fade then
		self.memo.fade = true
		tween(self.fade, 0.35, { BackgroundTransparency = 0 })
	end
	self:applyFx(frame)
	self:drawMatter(frame.matter)
	self.pendingShapes = frame.shapes -- (drawn after the rigs are placed: they hang on their parts)
	self:applyOverlay(frame.overlay)
	-- (DAICHA's scenes stage her matter themselves: her fighting sphere hides meanwhile)
	if frame.matter then self.usesMatter = true end
	self.effects.hideOrb = self.usesMatter == true
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
	-- The match's mini intro (Director.intro): each fighter in turn, his entrance pose.
	local introT = if not cin and not stale then Director.introScene(world, self.config) else nil
	if introT and views[1] and views[2] then
		if not self.active or self.kind ~= "intro" then
			if self.active then self:finish() end
			self:begin("intro")
		end
		ctx.anchors = self.anchors
		self:applyFrame(Director.intro(ctx, views, introT))
		self:showDebug("intro", introT, Director.INTRO_SCENE)
		return true
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
	ctx.anchors, ctx.koCount = self.anchors, self.koCount
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
		-- (a FINAL FINISH is only certain once the blow landed: missed prompts can still undo it)
		if cin.finish and tick >= (cin.finalTick or MoveData.Cinematics[cin.move].FinalTick) then self.finishEpoch = world.epoch end
		self.kitOfAttacker = cin.kit
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
		if position and point.mid then
			-- (between two parts: KAI's sphere between his hands)
			local _, other = RigReader.part(rig.model, point.mid)
			if other then position = (position + other) / 2 end
		end
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
	local goal = CFrame.lookAt(position, target) * CFrame.Angles(0, 0, s.roll * (if self.effects.reduced then 0.3 else 1))
	if s.name ~= self.shot then
		-- Anime-style hard cut between shots, with a tiny push-in afterwards.
		self.shot, self.cameraCFrame, self.shotTime = s.name, goal, 0
	else
		self.cameraCFrame = self.cameraCFrame:Lerp(goal, 1 - math.exp(-14 * dt))
	end
	self.shotTime = (self.shotTime or 0) + dt
	-- (a close-up hangs on a part a stud or two away: no push-in, it would enter the head)
	local push = if s.close then Vector3.zero else self.cameraCFrame.LookVector * math.min(self.shotTime, 1.2) * 0.6
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
		self.debugLabel.Text = string.format(" %s · shot %s · tick %d/%d · FOV %d", info.label, s.name, info.tick, info.length, s.fov)
	end
	camera.CFrame = (self.cameraCFrame + push) + self.cameraCFrame:VectorToWorldSpace(shake)
	-- Depth of field on the subject (off in reduced mode).
	local focus = resolve(s.focus, rigs, views)
	self.dof.Enabled = not self.effects.reduced
	self.dof.FocusDistance = (camera.CFrame.Position - focus).Magnitude
	self.dof.InFocusRadius = math.max(2.5, self.dof.FocusDistance * 0.18)
	self:drawShapes(self.pendingShapes, rigs, views)
	self:updateFirstPerson(rigs)
	self:updateSplit(rigs, camera, views)
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

-- ===================================================================== FATAL FINISHERS
-- (Finishers.luau stages them; here they are drawn. Everything is reset by clearFinisher.)

local function hex(color, fallback)
	return if color then Color3.fromHex(color) else (fallback or WHITE)
end

-- A neon part of the finishers' pool (made once, reused frame after frame).
function CinematicController:shapePart(shape, material)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material, p.Shape, p.Size, p.Name = material or Enum.Material.Neon, shape or Enum.PartType.Block, Vector3.one, "FinisherLight"
	p.Parent = self.effects.folder
	return p
end

-- One entry of the pool per shape of the frame, by its index: { kind, parts = {...}, light }.
-- Parts are hidden (Transparency 1) rather than destroyed when a shape goes away.
local BEAM_SLICES = 16 -- (the wave's slices: KiBall.beam)
local RING_SEGMENTS = 22
function CinematicController:drawShapes(list, rigs, views)
	local pool = self.shapePool
	local reduced = self.effects.reduced
	local n = if list then #list else 0
	for i = 1, math.max(n, #pool) do
		local sh = list and list[i]
		local entry = pool[i]
		if entry and (not sh or entry.kind ~= sh.kind) then
			for _, part in entry.parts do part.Transparency = 1 end
			if entry.light then entry.light.Enabled = false end
		end
		if sh then
			if not entry or entry.kind ~= sh.kind then
				if entry then for _, part in entry.parts do part:Destroy() end end
				entry = { kind = sh.kind, parts = {} }
				pool[i] = entry
			end
			local color = hex(sh.color)
			local parts = entry.parts
			if sh.kind == "sphere" then
				-- a white-hot core in a ball of the ki's colour, a halo around, a light
				if not parts[1] then
					parts[1], parts[2], parts[3] = self:shapePart(Enum.PartType.Ball), self:shapePart(Enum.PartType.Ball), self:shapePart(Enum.PartType.Ball)
					entry.light = Instance.new("PointLight")
					entry.light.Parent = parts[1]
				end
				local pos, r = resolve(sh.pos, rigs, views), math.max(0.05, sh.radius)
				local core = math.clamp(sh.core or 1, 0, 1)
				parts[1].CFrame, parts[1].Size, parts[1].Color, parts[1].Transparency = CFrame.new(pos), Vector3.one * r * 1.1, WHITE, 1 - 0.95 * core
				parts[2].CFrame, parts[2].Size, parts[2].Color, parts[2].Transparency = CFrame.new(pos), Vector3.one * r * 2, color, 0.25
				parts[3].CFrame, parts[3].Size, parts[3].Color, parts[3].Transparency = CFrame.new(pos), Vector3.one * r * 3.2, color, 0.8
				entry.light.Enabled, entry.light.Color, entry.light.Range, entry.light.Brightness = true, color, math.min(60, 6 + r * 9), 2 + 3 * core
			elseif sh.kind == "beam" then
				-- the wave (KiBall.beam, Wilhem's drawing): thin out of the palms, swelling, its
				-- edges rippling and flowing away; built of short overlapping slices, each its own
				-- width and a little off the axis, a white core through them, a glow round them,
				-- and bands travelling along it
				local slices = if reduced then 8 else BEAM_SLICES
				if not parts[1] then
					parts[1] = self:shapePart(Enum.PartType.Cylinder)
					for k = 2, 2 * BEAM_SLICES + 1 do parts[k] = self:shapePart(Enum.PartType.Cylinder) end
					for k = 2 * BEAM_SLICES + 2, 2 * BEAM_SLICES + 6 do parts[k] = self:shapePart(Enum.PartType.Cylinder) end
					entry.light = Instance.new("PointLight")
					entry.light.Parent = parts[1]
				end
				local a, b = resolve(sh.from, rigs, views), resolve(sh.to, rigs, views)
				local axis = b - a
				local length = math.max(0.1, axis.Magnitude)
				local dirU = axis / length
				local r = math.max(0.05, sh.radius)
				-- (a cylinder lies along its X axis)
				local turn = CFrame.lookAt(Vector3.zero, dirU) * CFrame.Angles(0, math.pi / 2, 0)
				-- (the sway goes across the wave as the camera sees it)
				local look = workspace.CurrentCamera and workspace.CurrentCamera.CFrame.LookVector or Vector3.zAxis
				local across = dirU:Cross(look)
				across = if across.Magnitude > 1e-3 then across.Unit else Vector3.yAxis
				local now = os.clock()
				parts[1].CFrame = CFrame.new((a + b) / 2) * turn
				parts[1].Size, parts[1].Color, parts[1].Transparency = Vector3.new(length, r * 0.8, r * 0.8), WHITE, 0
				for k = 1, BEAM_SLICES do
					local sheath, glow = parts[1 + k], parts[1 + BEAM_SLICES + k]
					if k > slices then
						sheath.Transparency, glow.Transparency = 1, 1
					else
						local u = (k - 0.5) / slices
						local scale, sway = KiBall.beam(u, now)
						local at = CFrame.new(a + axis * u + across * (sway * r)) * turn
						local long = length / slices * 1.35
						sheath.CFrame, sheath.Size, sheath.Color, sheath.Transparency = at, Vector3.new(long, r * 2 * scale, r * 2 * scale), color, 0.2
						glow.CFrame, glow.Size, glow.Color, glow.Transparency = at, Vector3.new(long, r * 3.1 * scale, r * 3.1 * scale), color, 0.78
					end
				end
				local bands = if reduced then 2 else 5
				for k = 1, 5 do
					local part = parts[2 * BEAM_SLICES + 1 + k]
					if k > bands then
						part.Transparency = 1
					else
						local t = ((sh.rings or 0) + (k - 1) / bands) % 1
						local scale = KiBall.beam(t, now)
						part.CFrame = CFrame.new(a + axis * t) * turn
						part.Size, part.Color, part.Transparency = Vector3.new(0.18, r * 2.7 * scale, r * 2.7 * scale), WHITE, 0.55
					end
				end
				entry.light.Enabled, entry.light.Color, entry.light.Range, entry.light.Brightness = true, color, 40, 4
			elseif sh.kind == "ring" then
				-- a ring of light: segments round its normal
				local count = if reduced then 12 else RING_SEGMENTS
				for k = 1, RING_SEGMENTS do
					if not parts[k] then parts[k] = self:shapePart() end
				end
				local pos = resolve(sh.pos, rigs, views)
				local normal = vec(sh.normal or { x = 0, y = 1, z = 0 }).Unit
				local side = if math.abs(normal.Y) > 0.9 then Vector3.xAxis else Vector3.yAxis
				local u = side:Cross(normal).Unit
				local w = normal:Cross(u).Unit
				local r = math.max(0.1, sh.radius)
				local width = math.max(0.05, sh.width or 0.2)
				local segment = 2 * math.pi * r / count * 1.08
				for k = 1, RING_SEGMENTS do
					local part = parts[k]
					if k > count then
						part.Transparency = 1
					else
						local angle = (k - 0.5) / count * math.pi * 2
						local at = pos + (u * math.cos(angle) + w * math.sin(angle)) * r
						local tangent = (-u * math.sin(angle) + w * math.cos(angle))
						part.CFrame = CFrame.lookAt(at, at + tangent, normal)
						part.Size, part.Color = Vector3.new(width, width * 0.5, segment), color
						part.Transparency = math.clamp(sh.alpha or 0, 0, 1)
					end
				end
			elseif sh.kind == "motes" then
				-- motes drawn in to the point (or blown out of it), spiralling
				local count = math.min(40, if reduced then math.floor((sh.count or 20) / 3) else sh.count or 20)
				for k = 1, 40 do
					if not parts[k] then parts[k] = self:shapePart(Enum.PartType.Ball) end
				end
				local center = resolve(sh.pos, rigs, views)
				local phase = sh.phase or 0
				for k = 1, 40 do
					local part = parts[k]
					if k > count then
						part.Transparency = 1
					else
						local t = (phase * 0.6 + k / count) % 1
						local r = sh.radius * (if sh.out then t else 1 - t)
						local angle = k * 2.4 + phase * 3
						part.CFrame = CFrame.new(center + Vector3.new(math.cos(angle) * r, math.sin(angle * 1.3) * r * 0.6, math.sin(angle) * r))
						part.Size = Vector3.one * (0.12 + 0.12 * (1 - t))
						part.Color = if k % 4 == 0 then WHITE else color
						part.Transparency = if sh.out then 0.2 + 0.8 * t else 0.15 + 0.6 * (1 - t)
					end
				end
			elseif sh.kind == "slash" then
				-- a blade's streak: a thin white core in a wider band of colour
				if not parts[1] then parts[1], parts[2] = self:shapePart(), self:shapePart() end
				local a, b = resolve(sh.from, rigs, views), resolve(sh.to, rigs, views)
				local frame = CFrame.lookAt((a + b) / 2, b)
				local length = (b - a).Magnitude
				local width = math.max(0.02, sh.width or 0.15)
				local fade = math.clamp(sh.alpha or 0, 0, 1)
				parts[1].CFrame, parts[1].Size, parts[1].Color, parts[1].Transparency = frame, Vector3.new(width * 0.4, width * 0.4, length), WHITE, fade
				parts[2].CFrame, parts[2].Size, parts[2].Color = frame, Vector3.new(width * 1.6, width * 0.25, length * 1.02), color
				parts[2].Transparency = 0.35 + 0.65 * fade
			elseif sh.kind == "dome" then
				-- the blast's shell (the deck hides its lower half)
				if not parts[1] then parts[1] = self:shapePart(Enum.PartType.Ball, if reduced then Enum.Material.Neon else Enum.Material.ForceField) end
				local pos, r = resolve(sh.pos, rigs, views), math.max(0.1, sh.radius)
				parts[1].CFrame, parts[1].Size, parts[1].Color = CFrame.new(pos), Vector3.one * r * 2, color
				parts[1].Transparency = math.clamp(0.3 + 0.7 * (sh.alpha or 0), 0, 1)
			end
		end
	end
end

-- The direction over the whole screen: the colour drained, a blur pulse, the K.O. written into
-- the scene; first person and the split are applied after the camera (updateFirstPerson,
-- updateSplit).
function CinematicController:applyOverlay(o)
	local reduced = self.effects.reduced
	self.overlay = o
	local desat = o and o.desat or 0
	self.finisherDesat.Enabled = desat > 0.01
	self.finisherDesat.Saturation = -desat
	local blur = if o and not reduced then o.blur or 0 else 0
	self.finisherBlur.Enabled = blur > 0.02
	self.finisherBlur.Size = blur * 16
	local tint = o and o.tint
	self.finisherTint.Enabled = tint ~= nil and (tint.amount or 0) > 0.01
	if self.finisherTint.Enabled then
		local amount = math.clamp(tint.amount, 0, 1)
		self.finisherTint.TintColor = WHITE:Lerp(hex(tint.color), amount)
		self.finisherTint.Brightness = -0.12 * amount
		self.finisherTint.Contrast = 0.2 * amount
		self.finisherTint.Saturation = -0.4 * amount
	end
	local white = if o and not reduced then o.white or 0 elseif o then math.min(0.6, o.white or 0) else 0
	self.whiteFrame.Visible = white > 0.01
	self.whiteFrame.BackgroundTransparency = 1 - math.clamp(white, 0, 1)
	local card = o and o.ko and o.ko.card
	self.koCard.Visible = card ~= nil
	if card then
		self.koCard.BackgroundColor3 = hex(card.bg, INK)
		for _, bar in self.koSplash do
			bar.Visible = card.splash ~= nil
			bar.BackgroundColor3 = hex(card.splash, RED)
		end
	end
	local ko = o and o.ko
	if ko then
		-- (after its slam it rises and shrinks so the scene reads; on a card it stays, centred)
		local settle = if card then 0 else math.clamp((ko.age - 40) / 20, 0, 1)
		if not self.koLabel.Visible then
			self.koLabel.Visible, self.koSub.Visible = true, true
			self.koScale.Scale = if reduced then 1 else 2.4
			tween(self.koScale, 0.14, { Scale = 1 }, Enum.EasingStyle.Back)
			self:flash(0.25)
		end
		local color = hex(ko.color, RED)
		self.koStroke.Color = color
		self.koSub.Text, self.koSub.TextColor3 = ko.sub or "", color
		self.koLabel.Position = UDim2.fromScale(0.5, 0.42 - 0.22 * settle)
		self.koLabel.Size = UDim2.fromScale(0.7 - 0.36 * settle, 0.32 - 0.17 * settle)
		self.koSub.Position = UDim2.fromScale(0.5, 0.66 - 0.36 * settle)
	elseif self.koLabel.Visible then
		self.koLabel.Visible, self.koSub.Visible = false, false
	end
	local caption = o and o.caption
	if caption then
		if not self.captionLabel.Visible or self.captionLabel.Text ~= caption.text then
			-- (a new count slams in)
			self.captionLabel.Visible, self.captionLabel.Text = true, caption.text
			self.captionScale.Scale = if reduced then 1.1 else 1.8
			tween(self.captionScale, 0.12, { Scale = 1 }, Enum.EasingStyle.Back)
		end
		self.captionLabel.TextColor3 = hex(caption.color)
		self.captionStroke.Color = hex(caption.stroke, INK)
		self.captionLabel.TextTransparency = math.clamp(caption.fade or 0, 0, 1)
		self.captionStroke.Transparency = math.clamp(caption.fade or 0, 0, 1)
	elseif self.captionLabel.Visible then
		self.captionLabel.Visible = false
	end
end

-- First person: the camera is that fighter's eyes; its head and arms are not drawn for us.
local function headOrArm(part)
	local name = part.Name
	if name == "Head" or string.find(name, "Arm") or string.find(name, "Hand") then return true end
	local accessory = part:FindFirstAncestorOfClass("Accessory")
	return accessory ~= nil
end
function CinematicController:updateFirstPerson(rigs)
	local slot = self.overlay and self.overlay.firstPerson
	if slot == self.fpSlot then return end
	for part in self.fpHidden do part.LocalTransparencyModifier = 0 end
	self.fpHidden, self.fpSlot = {}, slot
	local rig = slot and rigs[slot]
	if not rig then return end
	for _, part in rig.model:GetDescendants() do
		if (part:IsA("BasePart") or part:IsA("Decal")) and headOrArm(if part:IsA("Decal") then part.Parent else part) then
			part.LocalTransparencyModifier = 1
			self.fpHidden[part] = true
		end
	end
end

-- SHIN's FINAL DIVISION: the screen cut along a line into two halves (masked canvases), the
-- scene alive in both (viewports mirroring the two bodies, the camera's own view), slid apart
-- along the cut, K in one, O in the other, then joined into K.O.
-- (each part's path in its model: the copy's parts are found by it, whatever Clone() skipped)
local function pathOf(part, root)
	local names = {}
	local node = part
	while node and node ~= root do
		table.insert(names, 1, node.Name)
		node = node.Parent
	end
	return table.concat(names, "/")
end

function CinematicController:buildSplit(rigs, color, only)
	local gui = self.gui
	local holder = new("Frame", { Name = "FinalDivision", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0, ZIndex = 4 }, gui)
	local split = { holder = holder, halves = {}, pairs = {} }
	-- (each half is a square canvas centred on the screen, so its masking gradient turns by
	-- the very angle of the line; inside it, a screen-sized region holds the view and the letter)
	local opaque = NumberSequenceKeypoint.new
	for side = 1, 2 do
		local group = new("CanvasGroup", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 4 }, holder)
		local mask = new("UIGradient", { Transparency = if side == 1
			then NumberSequence.new({ opaque(0, 0), opaque(0.499, 0), opaque(0.5, 1), opaque(1, 1) })
			else NumberSequence.new({ opaque(0, 1), opaque(0.499, 1), opaque(0.5, 0), opaque(1, 0) }) }, group)
		local inner = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 4 }, group)
		local viewport = new("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = if side == 1 then Color3.fromHex("10131C") else Color3.fromHex("1A0F18"),
			BorderSizePixel = 0, Ambient = Color3.fromRGB(170, 170, 185), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-0.4, -1, -0.6),
			ZIndex = 4 }, inner)
		local cam = Instance.new("Camera")
		cam.Parent = viewport
		viewport.CurrentCamera = cam
		local letter = new("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true,
			Text = if side == 1 then "K" else "O", TextColor3 = WHITE, TextTransparency = 0.05, ZIndex = 5,
			AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(0.42, 0.62) }, inner)
		new("UIStroke", { Thickness = 8, Color = color }, letter)
		split.halves[side] = { group = group, inner = inner, mask = mask, viewport = viewport, cam = cam, letter = letter }
		-- the bodies, copied once (only its own one when the half has its own subject); each frame
		-- their parts follow the real ones
		for slot, rig in rigs do
			if only and only[side] and only[side] ~= slot then continue end
			local copy = rig.model:Clone()
			if not copy then continue end
			local twins = {}
			for _, d in copy:GetDescendants() do
				if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") or d:IsA("ParticleEmitter") or d:IsA("BillboardGui") then
					d:Destroy()
				elseif d:IsA("BasePart") then
					twins[pathOf(d, copy)] = twins[pathOf(d, copy)] or d
					d.Anchored = true
				end
			end
			for _, part in rig.model:GetDescendants() do
				local twin = part:IsA("BasePart") and twins[pathOf(part, rig.model)]
				if twin then table.insert(split.pairs, { part, twin }) end
			end
			copy.Parent = viewport
		end
	end
	-- the cut itself, over both halves
	split.line = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1.6, 0, 0, 4),
		BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 6 }, gui)
	new("UIStroke", { Thickness = 3, Color = color, Transparency = 0.2 }, split.line)
	self.split = split
	return split
end

-- A line drawn across the screen `t` of its way (a hard-edged gradient reveals it from one end).
local function drawnLine(frame, t)
	t = math.clamp(t, 0, 1)
	frame.Visible = t > 0.001
	local key = NumberSequenceKeypoint.new
	local edge = math.clamp(t, 0.002, 0.998)
	frame:FindFirstChildOfClass("UIGradient").Transparency = if t >= 0.999 then NumberSequence.new(0)
		else NumberSequence.new({ key(0, 0), key(edge - 0.001, 0), key(edge, 1), key(1, 1) })
end

function CinematicController:updateSplit(rigs, camera, views)
	local o = self.overlay and self.overlay.split
	if not o then
		if self.split then
			self.split.holder:Destroy()
			self.split.line:Destroy()
			self.split = nil
		end
		if self.lineOnly then self.lineOnly.Visible = false end
		return
	end
	local color = hex(o.color, Color3.fromHex("8FD8FF"))
	local angle = o.angle or 0
	local split = self.split
	local open = math.max(0, o.open or 0)
	if (open > 0 or (o.join or 0) > 0) and not split then split = self:buildSplit(rigs, color, o.only) end
	if not split then
		-- before the cut opens: only the line, drawn across from one side
		if not self.lineOnly then
			self.lineOnly = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1.6, 0, 0, 4),
				BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 6 }, self.gui)
			new("UIStroke", { Thickness = 3, Color = color, Transparency = 0.2 }, self.lineOnly)
			new("UIGradient", {}, self.lineOnly)
		end
		self.lineOnly.Rotation = angle
		drawnLine(self.lineOnly, o.line or 0)
		return
	end
	if self.lineOnly then self.lineOnly.Visible = false end
	-- the halves: masked across the line, slid apart along it
	local screen = camera.ViewportSize
	local side = math.ceil(math.sqrt(screen.X * screen.X + screen.Y * screen.Y))
	-- (one shot slid apart; halves with their own shots stay put, only the gap opens)
	local shift = if o.views then 0 else open * screen.X * 0.07
	local ux, uy = math.cos(math.rad(angle)), math.sin(math.rad(angle))
	local join = math.clamp(o.join or 0, 0, 1)
	for index, half in split.halves do
		local sign = if index == 1 then -1 else 1
		half.group.Size = UDim2.fromOffset(side, side)
		half.group.Position = UDim2.new(0.5, ux * shift * sign, 0.5, uy * shift * sign)
		half.inner.Size = UDim2.fromOffset(screen.X, screen.Y)
		-- (the line travels along its Rotation; the first half lies on its left-hand side)
		half.mask.Rotation = angle - 90
		-- (a half may hold its own shot: SHIN's face behind the K, the target behind the O)
		local own = o.views and o.views[index]
		if own then
			local from, to = resolve(own.from, rigs, views), resolve(own.to, rigs, views)
			half.cam.CFrame = CFrame.lookAt(from, to) * CFrame.Angles(0, 0, own.roll or 0)
			half.cam.FieldOfView = own.fov or camera.FieldOfView
		else
			half.cam.CFrame, half.cam.FieldOfView = camera.CFrame, camera.FieldOfView
		end
		if o.letters then half.letter.Text = o.letters[index] or "" end
		-- each letter in its half, clear of the face (o.letterAt: share of the screen); joined, they
		-- meet in the middle (K.O.)
		local at = o.letterAt and o.letterAt[index] or (if index == 1 then { 0.3, 0.36 } else { 0.7, 0.64 })
		local size = (o.letterSize or 0.4) * (1 - 0.3 * join)
		half.letter.Position = UDim2.fromScale(at[1] + (0.5 + sign * 0.08 - at[1]) * join, at[2] + (0.5 - at[2]) * join)
		half.letter.Size = UDim2.new(0, math.floor(screen.Y * size * 0.8), size, 0)
	end
	for _, pair in split.pairs do
		if pair[1].Parent then pair[2].CFrame = pair[1].CFrame end
	end
	split.line.Rotation = angle
	split.line.Size = UDim2.new(1.6, 0, 0, 4 + math.floor(open * (if o.views then 12 else 6)))
end

function CinematicController:clearFinisher()
	for _, entry in self.shapePool or {} do
		for _, part in entry.parts do part:Destroy() end
	end
	self.shapePool, self.pendingShapes = {}, nil
	for part in self.fpHidden or {} do
		if part.Parent then part.LocalTransparencyModifier = 0 end
	end
	self.fpHidden, self.fpSlot, self.overlay = {}, nil, nil
	if self.split then
		self.split.holder:Destroy()
		self.split.line:Destroy()
		self.split = nil
	end
	if self.lineOnly then self.lineOnly:Destroy() self.lineOnly = nil end
	if self.finisherBlur then self.finisherBlur.Enabled = false end
	if self.finisherDesat then self.finisherDesat.Enabled = false end
	if self.koLabel then self.koLabel.Visible, self.koSub.Visible = false, false end
	if self.captionLabel then self.captionLabel.Visible = false end
	if self.finisherTint then self.finisherTint.Enabled = false end
	if self.whiteFrame then self.whiteFrame.Visible = false end
	if self.koCard then self.koCard.Visible = false end
end

function CinematicController:snapshot()
	self.snapshotAt = os.clock()
end

return CinematicController
