-- Manga-style combat HUD in the black / white / red palette of the KAI art direction sheet.
-- The local fighter's kit (MoveData.Kits) drives the combo list, the trainer and the lab.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterData = require(Shared.CharacterData)
local MoveData = require(Shared.MoveData)
local Locale = require(Shared.Locale)
local UIArt = require(Shared.UIArt)
local Theme = require(script.Parent.MenuTheme) -- (the fight's buttons wear the menu's design)

local HUD = {}

local WHITE = Color3.fromHex("F5F5F7")
local INK = Color3.fromHex("0B0B0E")
local RED = Color3.fromHex("E0102B")
local FATAL, FATAL_DARK, FATAL_HOT = Color3.fromHex("FF1E3C"), Color3.fromHex("2A0006"), Color3.fromHex("FFC2A8")
local DISPLAY = Enum.Font.Bangers
local UI_FONT = Enum.Font.GothamBlack

local function new(className, props, parent)
	local i = Instance.new(className)
	for k, v in props do i[k] = v end
	i.Parent = parent
	return i
end

local function corner(gui, radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, gui)
end

local function stroke(parent, thickness, color)
	return new("UIStroke", { Thickness = thickness, Color = color or INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, parent)
end

local function text(parent, props)
	local l = new("TextLabel", {
		BackgroundTransparency = 1, Font = DISPLAY, TextColor3 = WHITE, TextScaled = false,
		TextSize = 20, Text = "",
	}, parent)
	for k, v in props do l[k] = v end
	return l
end

-- Marks an instance coloured by the slot's style ("Energy" or "Shield"), see HUD:applyLook.
local function tint(instance, kind)
	instance:SetAttribute("Tint", kind)
	return instance
end

-- A texture of the HUD (UIArt), or nil while Wilhem has not uploaded it yet (the drawn look stays).
local function art(name, parent, props)
	local asset = UIArt.asset(name)
	if asset == nil then return nil end
	local image = UIArt.Images[name]
	local label = Instance.new("ImageLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Image = asset
	if image.slice then
		local l, t, r, b = table.unpack(image.slice)
		label.ScaleType = Enum.ScaleType.Slice
		label.SliceCenter = Rect.new(l, t, r, b)
		label.SliceScale = 0.5 -- (drawn at 2x)
	end
	for key, value in props do label[key] = value end
	label.Parent = parent
	return label
end

-- The health's colours while above half: the fighter's own colour, lit at the timer's end and
-- deeper at the portrait's, so each bar reads as that fighter's.
local function healthColors(energy)
	return ColorSequence.new({ ColorSequenceKeypoint.new(0, energy), ColorSequenceKeypoint.new(0.45, energy:Lerp(Color3.new(1, 1, 1), 0.35)),
		ColorSequenceKeypoint.new(1, energy:Lerp(Color3.new(1, 1, 1), 0.7)) })
end

local function tween(instance, duration, goal, style, direction)
	local t = TweenService:Create(instance, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

function HUD.new(config)
	local self = setmetatable({ config = config, poseRate = config.PoseRate, bars = {}, trail = { 1, 1 }, combo = {} }, { __index = HUD })
	local screen = new("ScreenGui", { Name = "CombatHUD", ResetOnSpawn = false, DisplayOrder = 5, IgnoreGuiInset = false },
		Players.LocalPlayer:WaitForChild("PlayerGui"))
	self.gui = screen
	-- Everything is drawn on a canvas scaled to the screen: on a phone the whole HUD shrinks
	-- together (it filled the screen), keeping its layout; on a PC it stays at full size.
	local gui = new("Frame", { Name = "Canvas", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, screen)
	local canvasScale = new("UIScale", { Scale = 1 }, gui)
	local function fitCanvas()
		local size = screen.AbsoluteSize
		if size.Y <= 0 then return end
		-- (full size from 720 px high; a phone in landscape, ~360-430 px: about 0.55)
		local s = math.clamp(size.Y / 720, 0.5, 1)
		canvasScale.Scale = s
		gui.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	fitCanvas()
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitCanvas)
	self.canvas = gui

	-- VISUAL PASS: a dark vignette at the screen's edges (the fighters stand out in the middle)
	-- and a dark band behind the header (the bars read on every stage, the bright ones too).
	-- (on their own full-screen layer: inside the HUD's safe area they stopped short of a phone's
	-- edges and drew hard black bands, Wilhem's capture)
	local shade = new("ScreenGui", { Name = "CombatShade", ResetOnSpawn = false, DisplayOrder = 4, IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None }, Players.LocalPlayer:WaitForChild("PlayerGui"))
	shade.Enabled = screen.Enabled
	screen:GetPropertyChangedSignal("Enabled"):Connect(function() shade.Enabled = screen.Enabled end)
	for _, side in { { 0, 0 }, { 1, 180 } } do
		local edge = new("Frame", { Name = "Vignette", AnchorPoint = Vector2.new(side[1], 0), Position = UDim2.fromScale(side[1], 0),
			Size = UDim2.fromScale(0.22, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 0 }, shade)
		new("UIGradient", { Rotation = side[2], Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45),
			NumberSequenceKeypoint.new(1, 1) }) }, edge)
	end
	local band = new("Frame", { Name = "HeaderBand", Size = UDim2.new(1, 0, 0.2, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0,
		ZIndex = 0 }, shade)
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1) }) }, band)
	-- Top header (Wilhem: « inspire-toi des jeux de combat connus »: Street Fighter 6, Guilty Gear
	-- Strive, Tekken 8, FighterZ): long health bars from the portrait to the timer, the fighter's
	-- name over them, the guard in chips under them (like the DRIVE gauge), the rounds won next to
	-- the timer; the KI gauge in the bottom corners (on a phone: under the bars, the thumbs are
	-- there).
	local touchLayout = UIS.TouchEnabled and not UIS.KeyboardEnabled
	local EDGE = Color3.fromRGB(200, 200, 212)
	local header = new("Frame", { Name = "Header", BackgroundTransparency = 1, Size = UDim2.new(1, -24, 0, 110), Position = UDim2.fromOffset(12, 6) }, gui)
	for slot = 1, 2 do
		local data = CharacterData[slot]
		local energy = Color3.fromHex(data.Energy)
		local left = slot == 1
		local outer = if left then 0 else 1 -- (the side's outer end: the portrait's)
		local side = new("Frame", {
			Name = "Player" .. slot, BackgroundTransparency = 1,
			Size = UDim2.new(0.5, -50, 1, 0), Position = if left then UDim2.new() else UDim2.new(0.5, 50, 0, 0),
		}, header)
		local function at(x, y) -- (x from the outer end, mirrored for the right side)
			return if left then UDim2.fromOffset(x, y) else UDim2.new(1, -x, 0, y)
		end
		-- the portrait (SF6, Strive: the fighter's face): a square emblem, the fighter's head in 3D
		-- (HUD:setPortrait), a ring of the fighter's colour, a thin inner ring; the kanji in a small
		-- diamond on its lower corner
		local portrait = new("Frame", {
			Name = "Portrait", Size = UDim2.fromOffset(66, 66), AnchorPoint = Vector2.new(0.5, 0.5),
			Position = at(42, 46), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 4, ClipsDescendants = true,
		}, side)
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(energy:Lerp(INK, 0.55), INK) }, portrait)
		local portraitStroke = tint(stroke(portrait, 1.5, energy), "Energy")
		portraitStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		local face = new("ViewportFrame", { Name = "Face", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 4,
			Ambient = Color3.fromHex("9A8F9E"), LightColor = Color3.fromHex("FFF1E0"), LightDirection = Vector3.new(-0.3, -0.6, -1) }, portrait)
		new("Frame", { Name = "Shadow", AnchorPoint = Vector2.new(0.5, 0.5), Position = at(45, 50), Size = UDim2.fromOffset(66, 66),
			BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, BorderSizePixel = 0, ZIndex = 3 }, side)
		local badge = new("Frame", { Name = "KanjiBadge", AnchorPoint = Vector2.new(0.5, 0.5), Position = at(if left then 72 else 72, 76),
			Size = UDim2.fromOffset(26, 26), Rotation = 45, BackgroundColor3 = INK, BorderSizePixel = 0, ZIndex = 6, Visible = false }, side)
		tint(stroke(badge, 2, energy), "Energy")
		local kanji = tint(text(badge, { Text = data.Kanji, Rotation = -45, Size = UDim2.fromScale(1, 1), TextSize = 16, TextColor3 = energy,
			Font = UI_FONT, ZIndex = 7 }), "Energy")
		-- the health bar: a light rim, a dark track, the red trail, the health left (it drains toward
		-- the timer, as in every fighting game)
		local barX = 84
		local rim = new("Frame", { Name = "Rim", BackgroundColor3 = Color3.fromRGB(28, 28, 36), BorderSizePixel = 0,
			Size = UDim2.new(1, -barX + 2, 0, 28), AnchorPoint = Vector2.new(outer, 0), Position = at(barX - 4, 31) }, side)
		stroke(rim, 1, EDGE).Transparency = 0.3
		local bar = new("Frame", {
			Name = "Health", BackgroundColor3 = Color3.fromRGB(14, 14, 20), BorderSizePixel = 0,
			Size = UDim2.new(1, -barX - 2, 0, 22), AnchorPoint = Vector2.new(outer, 0), Position = at(barX - 1, 34),
		}, side)
		local barStroke = stroke(bar, 1, EDGE)
		barStroke.Transparency = 0.6
		-- (the textured frame, once uploaded: slanted ends masked in ink, a light rim)
		local barFrame = art(if left then "BarFrameLeft" else "BarFrameRight", side, { AnchorPoint = Vector2.new(outer, 0),
			Size = UDim2.new(1, -barX + 14, 0, 36), Position = at(barX - 10, 27), ZIndex = 3, SliceScale = 36 / 96 })
		if barFrame then
			rim.BackgroundTransparency = 1
			for _, item in rim:GetChildren() do if item:IsA("UIStroke") then item.Enabled = false end end
		end
		local trail = new("Frame", { Name = "Trail", BackgroundColor3 = RED, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
			AnchorPoint = Vector2.new(outer, 0), Position = UDim2.fromScale(outer, 0) }, bar)
		local fill = new("Frame", { Name = "Fill", BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
			AnchorPoint = Vector2.new(outer, 0), Position = UDim2.fromScale(outer, 0), ClipsDescendants = true }, bar)
		local gradient = new("UIGradient", { Color = healthColors(energy), Rotation = if left then 0 else 180 }, fill)
		-- (alive, Wilhem: « la barre de vie n'est pas assez vivante »; FighterZ, SF6): energy flowing
		-- slowly along it, a glint sweeping it every few seconds, a glowing tip where the health ends
		local flow = new("Frame", { Name = "Flow", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0,
			BorderSizePixel = 0, ZIndex = 1 }, fill)
		local flowKeys = {}
		for k = 0, 8 do
			table.insert(flowKeys, NumberSequenceKeypoint.new(k / 8, if k % 2 == 0 then 1 else 0.82))
		end
		local flowGradient = new("UIGradient", { Transparency = NumberSequence.new(flowKeys), Rotation = if left then 0 else 180 }, flow)
		local glint = new("Frame", { Name = "Glint", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 2 }, fill)
		local glintGradient = new("UIGradient", { Rotation = if left then 20 else 160, Offset = Vector2.new(-1, 0),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.44, 1),
				NumberSequenceKeypoint.new(0.5, 0.25), NumberSequenceKeypoint.new(0.56, 1), NumberSequenceKeypoint.new(1, 1) }) }, glint)
		local tip = new("Frame", { Name = "Tip", Size = UDim2.new(0, 16, 1, 0), AnchorPoint = Vector2.new(1 - outer, 0),
			Position = UDim2.fromScale(1 - outer, 0), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 2 }, fill)
		local tipGradient = new("UIGradient", { Rotation = if left then 0 else 180,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.8, 0.35), NumberSequenceKeypoint.new(1, 0) }) }, tip)
		-- (its volume: a bright top edge, a darker foot)
		new("Frame", { Name = "Shine", Size = UDim2.new(1, 0, 0.28, 0), BackgroundColor3 = WHITE, BackgroundTransparency = 0.45,
			BorderSizePixel = 0, ZIndex = 2 }, bar)
		new("Frame", { Name = "Foot", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0.25, 0),
			BackgroundColor3 = INK, BackgroundTransparency = 0.7, BorderSizePixel = 0, ZIndex = 2 }, bar)
		-- (no marks across it: at 30 % the bar catches fire for the FATAL BLOW, that says enough;
		-- Wilhem: « le séparage par section, c'est pas forcé »; a white flash at every blow)
		local hitFlash = new("Frame", { Name = "HitFlash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1,
			BorderSizePixel = 0, ZIndex = 2 }, fill)
		-- COUP FATAL ready: the bar burns (Wilhem: « un effet sur notre barre de vie comme dans
		-- Taken »): a crimson aura pulsing around it, a flame running along the health left, the
		-- bar and the portrait outlined in crimson. Cosmetic: the server says when it is ready.
		local aura = new("Frame", { Name = "FatalAura", BackgroundTransparency = 1, Size = UDim2.new(1, 10, 1, 10),
			Position = UDim2.fromOffset(-5, -5), Visible = false }, bar)
		local auraStroke = new("UIStroke", { Thickness = 4, Color = FATAL, Transparency = 0.3 }, aura)
		local flame = new("Frame", { Name = "FatalFlame", BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
			Visible = false }, fill)
		local flameGradient = new("UIGradient", {
			Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, FATAL_DARK), ColorSequenceKeypoint.new(0.3, FATAL),
				ColorSequenceKeypoint.new(0.5, FATAL_HOT), ColorSequenceKeypoint.new(0.7, FATAL), ColorSequenceKeypoint.new(1, FATAL_DARK) }),
			Transparency = NumberSequence.new(0.1),
		}, flame)
		-- the guard, in six chips under the bar from its inner end (the DRIVE gauge's place): the dark
		-- chips behind, the lit ones in a container that shrinks toward the timer
		local CHIP, GAP, CHIPS = 34, 4, 6
		local guard = new("Frame", {
			Name = "Guard", BackgroundTransparency = 1, Size = UDim2.fromOffset(CHIPS * (CHIP + GAP) - GAP, 8),
			AnchorPoint = Vector2.new(1 - outer, 0), Position = if left then UDim2.new(1, -1, 0, 64) else UDim2.fromOffset(1, 64),
		}, side)
		for i = 1, CHIPS do
			local off = (i - 1) * (CHIP + GAP)
			new("Frame", { Size = UDim2.fromOffset(CHIP, 8), AnchorPoint = Vector2.new(1 - outer, 0),
				Position = if left then UDim2.new(1, -off, 0, 0) else UDim2.fromOffset(off, 0), BackgroundColor3 = Color3.fromRGB(26, 28, 36),
				BorderSizePixel = 0 }, guard)
		end
		local guardFill = new("Frame", { Name = "Lit", BackgroundTransparency = 1, ClipsDescendants = true, Size = UDim2.fromScale(1, 1),
			AnchorPoint = Vector2.new(1 - outer, 0), Position = UDim2.fromScale(1 - outer, 0) }, guard)
		for i = 1, CHIPS do
			local off = (i - 1) * (CHIP + GAP)
			tint(new("Frame", { Size = UDim2.fromOffset(CHIP, 8), AnchorPoint = Vector2.new(1 - outer, 0),
				Position = if left then UDim2.new(1, -off, 0, 0) else UDim2.fromOffset(off, 0), BackgroundColor3 = Color3.fromHex(data.Shield),
				BorderSizePixel = 0 }, guardFill), "Shield")
		end
		-- the passive's line, under the bar on the outer side
		local passive = tint(text(side, {
			Name = "Passive", TextSize = 12, Font = UI_FONT, TextColor3 = energy, Visible = false,
			Size = UDim2.new(1, -barX - CHIPS * (CHIP + GAP) - 12, 0, 14), AnchorPoint = Vector2.new(outer, 0), Position = at(barX, 62),
			TextXAlignment = if left then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd,
		}), "Energy")
		stroke(passive, 2)
		-- the fighter's name over the bar, big and slanted in spirit; the player's name beside it
		local nameRow = new("Frame", { Name = "NameRow", BackgroundTransparency = 1, Size = UDim2.new(1, -barX - 4, 0, 30),
			AnchorPoint = Vector2.new(outer, 0), Position = at(barX, 0) }, side)
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = if left then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder }, nameRow)
		local name = text(nameRow, {
			Name = "Name", Text = data.Name, TextSize = 24, Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = if left then 1 else 2,
		})
		stroke(name, 1.5)
		local player = tint(text(nameRow, {
			Name = "PlayerName", TextSize = 13, Font = UI_FONT, TextColor3 = energy, Size = UDim2.fromOffset(0, 22),
			AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = if left then 2 else 1,
		}), "Energy")
		stroke(player, 1)
		-- the rounds won: slanted chips under the guard, by the timer
		local pips = {}
		for i = 1, math.max(config.RoundsToWin, 3) do -- (3 for a 3v3 relay: a pip per fighter knocked out)
			local pip = new("Frame", {
				Size = UDim2.fromOffset(18, 9), Rotation = if left then -14 else 14, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = INK,
				BorderSizePixel = 0, Position = if left then UDim2.new(1, -12 - (i - 1) * 24, 0, 86) else UDim2.new(0, 12 + (i - 1) * 24, 0, 86),
			}, side)
			stroke(pip, 1.5, EDGE)
			pips[i] = pip
		end
		-- the KI gauge: a plate with the bars' count in big, three long cells, the ultimate's line
		local panel = new("Frame", { Name = "KiPanel" .. slot, BackgroundTransparency = 1, Size = UDim2.fromOffset(470, 70),
			AnchorPoint = Vector2.new(outer, if touchLayout then 0 else 1),
			Position = if touchLayout then (if left then UDim2.new(0, 96, 0, 96) else UDim2.new(1, -96, 0, 96))
				else (if left then UDim2.new(0, 26, 1, -18) else UDim2.new(1, -26, 1, -18)),
		}, gui)
		if touchLayout then new("UIScale", { Scale = 0.7 }, panel) end
		local function px(x, y) return if left then UDim2.fromOffset(x, y) else UDim2.new(1, -x, 0, y) end
		local plate = new("Frame", { Name = "Plate", AnchorPoint = Vector2.new(outer, 0), Position = px(0, 18), Size = UDim2.fromOffset(78, 50),
			BackgroundColor3 = INK, BackgroundTransparency = 0.05, BorderSizePixel = 0 }, panel)
		tint(stroke(plate, 3, energy), "Energy")
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(40, 40, 52), Color3.new(1, 1, 1)) }, plate)
		plate.BackgroundTransparency = 1
		for _, item in plate:GetChildren() do if item:IsA("UIStroke") then item.Enabled = false end end
		local count = tint(text(plate, { Name = "KiCount", Text = "0", TextSize = 54, TextColor3 = energy, Size = UDim2.fromScale(1, 1),
			Rotation = if left then -6 else 6 }), "Energy")
		stroke(count, 2)
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, Color3.fromRGB(150, 150, 160)) }, count)
		local kiLabel = tint(text(panel, { Text = "KI", TextSize = 12, Font = UI_FONT, TextColor3 = energy, Size = UDim2.fromOffset(78, 14),
			AnchorPoint = Vector2.new(outer, 0), Position = px(0, 2) }), "Energy")
		stroke(kiLabel, 2)
		local segments, segmentEdges = {}, {}
		local CELL = 118
		for i = 1, config.MaxMeter / config.MeterBar do
			local segment = new("Frame", {
				BackgroundColor3 = Color3.fromRGB(20, 22, 30), BorderSizePixel = 0, Size = UDim2.fromOffset(CELL, 10),
				AnchorPoint = Vector2.new(outer, 0), Position = px(90 + (i - 1) * (CELL + 8), 36),
			}, panel)
			local segmentEdge = tint(stroke(segment, 1, energy), "Energy")
			segmentEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			segmentEdges[i] = segmentEdge
			local segmentFill = tint(new("Frame", { BackgroundColor3 = energy, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1),
				AnchorPoint = Vector2.new(outer, 0), Position = UDim2.fromScale(outer, 0) }, segment), "Energy")
			new("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, Color3.fromRGB(170, 170, 180)) }, segmentFill)
			segments[i] = segmentFill
		end
		local ready = text(panel, {
			Name = "UltimateReady", Text = "ULTIMATE READY · R", TextSize = 14, Font = UI_FONT, TextColor3 = WHITE, Visible = false,
			Size = UDim2.fromOffset(370, 16), AnchorPoint = Vector2.new(outer, 0), Position = px(90, 14),
			TextXAlignment = if left then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right, TextScaled = true,
		})
		new("UITextSizeConstraint", { MaxTextSize = 14, MinTextSize = 8 }, ready)
		tint(stroke(ready, 2, energy), "Energy")
		-- VIP (Game Pass): a rainbow running round the portrait and through the player's name, and
		-- a VIP tag (Wilhem: « le rainbow autour de notre icône ou pseudo pour comprendre qu'on est
		-- VIP »). Cosmetic: the server's badges.
		local nameRainbow = new("UIGradient", { Enabled = false, Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0.75, 1)), ColorSequenceKeypoint.new(0.2, Color3.fromHSV(0.15, 0.75, 1)),
			ColorSequenceKeypoint.new(0.4, Color3.fromHSV(0.33, 0.75, 1)), ColorSequenceKeypoint.new(0.6, Color3.fromHSV(0.55, 0.75, 1)),
			ColorSequenceKeypoint.new(0.8, Color3.fromHSV(0.78, 0.75, 1)), ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 0.75, 1)) }) }, player)
		local vipTag = text(side, { Name = "VipTag", Visible = false, Text = "VIP", Font = UI_FONT, TextSize = 10, TextColor3 = INK,
			BackgroundTransparency = 0, BackgroundColor3 = Color3.fromHex("FFD23F"), Size = UDim2.fromOffset(30, 14),
			AnchorPoint = Vector2.new(0.5, 0), Position = at(34, 84), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6 })
		new("UICorner", { CornerRadius = UDim.new(0, 4) }, vipTag)
		local vipGlow = new("UIStroke", { Thickness = 3, Color = Color3.new(1, 1, 1), Enabled = false,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, vipTag)
		self.bars[slot] = { nameRainbow = nameRainbow, rainbowColors = nameRainbow.Color, vipTag = vipTag, vipGlow = vipGlow, hitFlash = hitFlash, segmentEdges = segmentEdges,
			sideBase = side.Position, lastRatio = 1, edgeColor = EDGE, kiPanel = panel, face = face, left = left,
			fill = fill, trail = trail, guard = guardFill, player = player, pips = pips, energy = energy,
			segments = segments, kiCount = count, ready = ready, side = side, gradient = gradient, skin = data.Skin,
			kanji = kanji, name = name, passive = passive, aura = aura, auraStroke = auraStroke, flame = flame,
			flameGradient = flameGradient, barStroke = barStroke, portraitStroke = portraitStroke,
			flow = flow, flowGradient = flowGradient, glint = glint, glintGradient = glintGradient, tip = tip, tipGradient = tipGradient }
	end
	-- the timer: only its number, big and clean (FighterZ, KOF, SF6), the round under it (Wilhem:
	-- « c'est très beau, mais c'est trop dessiné »: no plate, no thick rims)
	local timer = new("Frame", {
		Name = "Timer", Size = UDim2.fromOffset(110, 66), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8),
		BackgroundColor3 = INK, BorderSizePixel = 0, Rotation = 45,
	}, header)
	timer.BackgroundTransparency, timer.Rotation = 1, 0
	self.timer = text(timer, { Size = UDim2.fromScale(1, 1), TextSize = 56, Text = "99" })
	stroke(self.timer, 2)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, Color3.fromRGB(190, 190, 200)) }, self.timer)
	self.timerScale = new("UIScale", { Scale = 1 }, timer) -- (the last 10 s beat: red, a bump each second)
	self.round = text(header, { Size = UDim2.fromOffset(92, 18), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 86),
		TextSize = 12, Font = UI_FONT, Text = "ROUND 1", TextColor3 = Color3.fromHex("FFD23F") })
	stroke(self.round, 1)

	-- Combo counters, one per side (shown on the attacker's side).
	for slot = 1, 2 do
		local left = slot == 1
		local frame = new("Frame", {
			Name = "Combo" .. slot, BackgroundTransparency = 1, Size = UDim2.fromOffset(220, 130), Visible = false,
			AnchorPoint = Vector2.new(if left then 0 else 1, 0.5), Position = if left then UDim2.new(0, 18, 0.4, 0) else UDim2.new(1, -18, 0.4, 0),
		}, gui)
		local scale = new("UIScale", { Scale = 1 }, frame)
		local align = if left then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right
		-- (the big number and HITS side by side, a line of the fighter's colour, the blow and the damage)
		local row = new("Frame", { Name = "Row", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 80) }, frame)
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = if left then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder }, row)
		local count = text(row, { Size = UDim2.fromOffset(0, 80), AutomaticSize = Enum.AutomaticSize.X, TextSize = 86, TextXAlignment = align,
			TextColor3 = self.bars[slot].energy, Rotation = if left then -4 else 4, LayoutOrder = if left then 1 else 2 })
		stroke(count, 5)
		-- (a light top, a darker foot: the number has volume)
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, Color3.fromRGB(175, 175, 185)) }, count)
		local hits = text(row, { Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, TextSize = 36, Text = "HITS",
			LayoutOrder = if left then 2 else 1 })
		stroke(hits, 4)
		local underline = new("Frame", { Name = "Underline", AnchorPoint = Vector2.new(if left then 0 else 1, 0),
			Position = if left then UDim2.fromOffset(0, 84) else UDim2.new(1, 0, 0, 84), Size = UDim2.fromOffset(220, 3),
			BackgroundColor3 = self.bars[slot].energy, BorderSizePixel = 0 }, frame)
		tint(underline, "Energy")
		new("UIGradient", { Rotation = if left then 0 else 180, Transparency = NumberSequence.new(0, 1) }, underline)
		local detail = text(frame, { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 92), TextSize = 15, Font = UI_FONT,
			TextXAlignment = align, TextColor3 = Color3.fromHex("FFD23F") })
		stroke(detail, 2)
		self.combo[slot] = { frame = frame, scale = scale, count = count, detail = detail, expires = 0 }
	end

	-- Announcer.
	local announce = text(gui, {
		Name = "Announcer", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(1, 0, 0, 120), TextSize = 110, Visible = false,
	})
	stroke(announce, 6)
	-- (a dark band unrolls behind the call: ROUND, FIGHT, K.O.; it reads on any stage)
	local announceBand = new("Frame", { Name = "AnnouncerBand", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.new(0, 0, 0, 170), BackgroundColor3 = INK, BackgroundTransparency = 0.45, BorderSizePixel = 0, Visible = false, ZIndex = 0 }, gui)
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.2),
		NumberSequenceKeypoint.new(0.8, 0.2), NumberSequenceKeypoint.new(1, 1) }) }, announceBand)
	for _, y in { 0, 1 } do
		new("Frame", { AnchorPoint = Vector2.new(0.5, y), Position = UDim2.fromScale(0.5, y), Size = UDim2.new(0.7, 0, 0, 2),
			BackgroundColor3 = WHITE, BackgroundTransparency = 0.4, BorderSizePixel = 0 }, announceBand)
	end
	-- (speed lines streaking across the band as a call lands)
	self.announceStreaks = {}
	for i = 1, 7 do
		local streak = new("Frame", { Name = "Streak", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(-0.2, 0.15 + i * 0.1),
			Size = UDim2.new(0.25, 0, 0, if i % 3 == 0 then 3 else 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0.5, BorderSizePixel = 0,
			Visible = false }, announceBand)
		new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.7, 0.2),
			NumberSequenceKeypoint.new(1, 1) }) }, streak)
		self.announceStreaks[i] = streak
	end
	-- (a short calls' letters slam in one after the other: ROUND, FIGHT!, K.O., PERFECT)
	local letters = new("Frame", { Name = "AnnouncerLetters", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(0, 130), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Visible = false }, gui)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, letters)
	self.announceLetters = letters
	-- (the whole screen flashes on FIGHT! and K.O.)
	self.screenFlash = new("Frame", { Name = "ScreenFlash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1,
		BorderSizePixel = 0, ZIndex = 20 }, gui)
	self.announceBand = announceBand
	self.announceScale = new("UIScale", { Scale = 1 }, announce)
	self.announce = announce
	self.announceSub = text(gui, {
		Name = "AnnouncerSub", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.new(1, 0, 0, 34), TextSize = 30, Visible = false, TextColor3 = RED,
	})
	stroke(self.announceSub, 3)

	-- Skill callouts, one per side, slanted like an anime technique name.
	self.callouts = {}
	for slot = 1, 2 do
		local left = slot == 1
		local callout = text(gui, {
			Name = "Skill" .. slot, Visible = false, TextSize = 52, Rotation = if left then -5 else 5,
			Size = UDim2.new(0.5, 0, 0, 60), AnchorPoint = Vector2.new(if left then 0 else 1, 0.5),
			Position = if left then UDim2.new(0, 16, 0.24, 0) else UDim2.new(1, -16, 0.24, 0),
			TextXAlignment = if left then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
			TextColor3 = self.bars[slot].energy,
		})
		stroke(callout, 4, INK)
		self.callouts[slot] = { label = callout, scale = new("UIScale", {}, callout) }
	end

	-- Status and buttons below the header.
	self.status = text(gui, { Name = "Status", Size = UDim2.new(1, -24, 0, 18), Position = UDim2.fromOffset(12, 112), TextSize = 12,
		Font = UI_FONT, TextColor3 = Color3.fromHex("B9B9C2") })
	--[[
		The buttons, tidied (Wilhem: "simplify these UIs"): along the top only ◀ MENU, COMBOS and
		⚙ TOOLS; TOOLS opens one column, in sections (FIGHTER, TRAINING, DISPLAY), where a hidden
		button leaves no hole (a list, not fixed places). Closed by default.
	]]
	local topRow = new("Frame", { Name = "TopButtons", BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 134),
		Size = UDim2.fromOffset(600, 30) }, gui)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, topRow)
	local tools = new("Frame", { Name = "Tools", Visible = false, BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 170), Size = UDim2.fromOffset(230, 0), AutomaticSize = Enum.AutomaticSize.Y }, gui)
	Theme.surface(tools, Theme.RED) -- (the menu's panels: gradient, fine edge, red rule on top)
	new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, tools)
	new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8) }, tools)
	self.tools = tools
	local order = 0
	local function heading(label)
		order += 1
		local h = text(tools, { Name = "Heading", LayoutOrder = order, Text = label, Size = UDim2.new(1, 0, 0, 16), TextSize = 11,
			Font = UI_FONT, TextColor3 = Color3.fromHex("FFD23F"), TextXAlignment = Enum.TextXAlignment.Left })
		return h
	end
	-- (Wilhem: « les boutons en combat ont encore l'ancien design, pas celui du menu »: the
	-- menu's buttons, MenuTheme.button: dark panel, fine edge lit red on hover, press feedback)
	local function button(name, label, width, callback, parent)
		order += 1
		local inRow = parent == topRow
		local b = Theme.button(parent or tools, {
			Name = name, Text = label, LayoutOrder = order, Size = if inRow then UDim2.fromOffset(width, 30) else UDim2.new(1, 0, 0, 30),
			Font = Theme.UI, TextSize = 12, TextColor3 = Theme.WHITE,
		}, Theme.RED)
		new("UICorner", { CornerRadius = UDim.new(0, 2) }, b)
		b.Activated:Connect(callback)
		return b
	end
	self.menuButton = button("Menu", "◀ MENU", 84, function()
		if self.onMenu then self.onMenu() end
	end, topRow)
	self.menuButton.TextColor3 = Theme.GOLD
	self.toolsButton = button("ToolsToggle", "⚙ TOOLS +", 110, function()
		tools.Visible = not tools.Visible
		self.toolsButton.Text = if tools.Visible then "⚙ TOOLS −" else "⚙ TOOLS +"
	end, topRow)
	self.combosButton = button("Combos", "COMBOS", 84, function()
		self.combosPanel.Visible = not self.combosPanel.Visible
	end, topRow)
	-- TARO only: his two boxing styles (keys 1 / & and 2 / é), always at hand.
	self.stanceButtons = {
		button("Stance1", "1 · CLASSIC (&)", 136, function()
			if self.onStance then self.onStance(1) end
		end, topRow),
		button("Stance2", "2 · PEEKABOO (é)", 136, function()
			if self.onStance then self.onStance(2) end
		end, topRow),
	}
	-- FIGHTER: who fights (T / G in training), the look, the style.
	self.fighterHeading = heading("FIGHTER")
	self.kitButton = button("Kit", "FIGHTER: KAI (T)", 0, function()
		if self.onKit then self.onKit() end
	end)
	self.foeKitButton = button("FoeKit", "OPPONENT: KAI (G)", 0, function()
		if self.onFoeKit then self.onFoeKit() end
	end)
	self.skinButton = button("Skin", "STYLE: CLASSIC", 0, function()
		if self.onSkin then self.onSkin() end
	end)
	self.avatarButton = button("Avatar", "LOOK: AVATAR", 0, function()
		if self.onAvatar then self.onAvatar() end
	end)
	-- TRAINING: the dummy, reset, the ultimates' conditions, the combo trainer, the cinematic lab.
	self.trainingHeading = heading("TRAINING")
	self.dummyButton = button("Dummy", "DUMMY (M)", 0, function()
		if self.onDummy then self.onDummy() end
	end)
	self.resetButton = button("Reset", "RESET", 0, function()
		if self.onReset then self.onReset() end
	end)
	self.ultiButton = button("UltiConditions", "ULTIMATES: OFF", 0, function()
		if self.onUltiConditions then self.onUltiConditions() end
	end)
	-- Combo trainer: pick a combo in its panel (two categories), the bar at the bottom shows
	-- what to press and when.
	self.trainerRoute = 0
	self.routeButton = button("Route", "TRAINER +", 0, function()
		self.trainerPanel.Visible = not self.trainerPanel.Visible
	end)
	self.labButton = button("Lab", "CINE LAB", 0, function()
		self.labPanel.Visible = not self.labPanel.Visible
	end)
	self.debugButton = button("Hitboxes", "HITBOX: OFF", 0, function()
		if self.onDebug then self.debugButton.Text = if self.onDebug() then "HITBOX: ON" else "HITBOX: OFF" end
	end)
	-- DISPLAY: the mouse, the poses' rate, the effects, the sound.
	heading("DISPLAY")
	self.mouseButton = button("MouseLock", "MOUSE: FREE (CTRL)", 0, function()
		if self.onMouseLock then self.onMouseLock() end
	end)
	local poseButton
	local function poseLabel(rate)
		return if rate >= 60 then "POSES: SMOOTH" else "POSES: " .. rate .. "/s"
	end
	poseButton = button("PoseRate", poseLabel(self.poseRate), 0, function()
		local rates = { 12, 15, 24, 60 }
		local current = table.find(rates, self.poseRate) or 1
		self.poseRate = rates[current % #rates + 1]
		poseButton.Text = poseLabel(self.poseRate)
	end)
	self.effectsButton = button("Effects", "EFFECTS: FULL", 0, function()
		if self.onEffects then self.effectsButton.Text = if self.onEffects() then "EFFECTS: REDUCED" else "EFFECTS: FULL" end
	end)
	self.soundButton = button("Sound", "SOUND: ON", 0, function()
		if self.onSound then self.soundButton.Text = if self.onSound() then "SOUND: ON" else "SOUND: OFF" end
	end)
	local panelY = 170 -- (panels open under the top buttons, beside the TOOLS column)
	local trainer = new("Frame", {
		Name = "ComboTrainer", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -124), -- (above the KI gauges)
		Size = UDim2.fromOffset(6 * 92, 140), BackgroundTransparency = 1, Visible = false,
	}, gui)
	self.trainer = trainer
	self.trainerNow = text(trainer, { Text = "NOW!", TextSize = 40, TextColor3 = Color3.fromHex("FFD23F"),
		Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 0), Visible = false })
	stroke(self.trainerNow, 3)
	self.trainerStatus = text(trainer, { TextSize = 15, Font = UI_FONT, Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 120) })
	-- The combo being trained, above its boxes.
	self.trainerTitle = text(trainer, { TextSize = 16, Font = UI_FONT, Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, -22), TextColor3 = Color3.fromHex("FFD23F") })
	stroke(self.trainerTitle, 2)
	stroke(self.trainerStatus, 2)
	self.trainerBoxes = {}

	-- Combo routes panel and training lab, filled for the local kit (see HUD:setKit).
	-- (they scroll: a long list never runs off the bottom of the screen and hides its last lines)
	local function panel(name, width, position)
		local frame = new("ScrollingFrame", {
			Name = name, Visible = false, BackgroundColor3 = INK, BackgroundTransparency = 0.1, BorderSizePixel = 0,
			Size = UDim2.new(0, width, 1, -panelY - 48), Position = position, CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarImageColor3 = RED,
		}, gui)
		stroke(frame, 2, RED).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, frame)
		new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, frame)
		return frame
	end
	self.combosPanel = panel("CombosPanel", 380, UDim2.fromOffset(252, panelY))
	self.labPanel = panel("LabPanel", 300, UDim2.new(1, -312, 0, panelY))
	-- The trainer's picker: two scrolling columns (one per category), never taller than the screen.
	self.trainerPanel = new("Frame", {
		Name = "TrainerPanel", Visible = false, BackgroundColor3 = INK, BackgroundTransparency = 0.08, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, panelY), Size = UDim2.new(0, 760, 1, -panelY - 170),
	}, gui)
	stroke(self.trainerPanel, 2, RED).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	new("UISizeConstraint", { MaxSize = Vector2.new(math.huge, 560) }, self.trainerPanel)
	self:setKit("KAI")

	self.help = text(gui, { Name = "Help", Size = UDim2.new(1, -24, 0, 22), Position = UDim2.new(0, 12, 1, -100), TextSize = 12,
		Font = UI_FONT, TextColor3 = Color3.fromHex("D6D6DC") })
	stroke(self.help, 1.5)
	local function updateHelp()
		local gamepad = UIS.PreferredInput == Enum.PreferredInput.Gamepad
		self.help.Visible = not UIS.TouchEnabled
		self.help.Text = if gamepad
			then "STICK: move · A: jump · X: attack · B: heavy · Y: special · LT: ultimate · LB: fatal blow · BACK or RB: guard · RT: dash · R3: taunts · SELECT: reset · HOLD L3: menu"
			else "A/Q · D: move · SPACE: jump · S: down · LEFT CLICK: attack · RIGHT CLICK: heavy · E: special · R: ultimate · C: fatal blow · BACK or F: guard · SHIFT: dash · T: fighter · G: CPU fighter · CTRL: lock mouse · P: menu"
	end
	UIS:GetPropertyChangedSignal("PreferredInput"):Connect(updateHelp)
	updateHelp()
	return self
end

local KEY_LABEL = { L = "L-CLICK", R = "R-CLICK", U = "R KEY", E = "E KEY", C = "C KEY" }
-- A route's keys, compact: mouse buttons as L / R, keyboard keys in brackets ("L L [R]").
local SHORT_KEY = { L = "L", R = "R", U = "[R]", E = "[E]", C = "[C]" }
local function keysShort(keys)
	local out = {}
	for k in keys:gmatch("%S") do table.insert(out, SHORT_KEY[k] or k) end
	return table.concat(out, " ")
end
-- A route's keys in words: "CLIC G, CLIC G, puis TOUCHE R".
local function keysInWords(keys)
	local words = {}
	for k in keys:gmatch("%S") do table.insert(words, KEY_LABEL[k] or k) end
	if #words < 2 then return words[1] or "" end
	return table.concat(words, ", ", 1, #words - 1) .. ", then " .. words[#words]
end
local GREY = Color3.fromHex("B9B9C2")
local GOLD = Color3.fromHex("FFD23F")
local ORANGE = Color3.fromHex("FFB938")
local ULTIMATE = Color3.fromHex("FF2A3D")

-- Why a route stopped being clean (CombatSimulation sets dirtyReason).
local DIRTY = {
	["TOO EARLY"] = "TOO EARLY: press when the previous blow comes out or lands, not before",
	SPAM = "SPAM: several buttons at once or too many presses ahead",
	["WRONG BUTTON"] = "WRONG BUTTON: that is not the next step of the route",
	["PRESS LOST"] = "PRESS LOST: pressed too early, the press expired",
}

function HUD:kitData()
	return MoveData.Kits[self.kit] or MoveData.Kits.KAI
end

local function moveName(kit, role)
	local m = MoveData.Moves[kit.Roles[role] or role]
	return if m then m.name else role
end

-- The local fighter's kit changed: combo list, trainer and lab follow it.
function HUD:setKit(kitName)
	if not kitName or not MoveData.Kits[kitName] or kitName == self.kit then return end
	local first = self.kit == nil
	self.kit = kitName
	self.trainerRoute = math.min(self.trainerRoute, #self:trainerRoutes())
	self:refreshRouteButton()
	self:buildTrainer()
	self:fillTrainer()
	self:fillCombos()
	self:fillLab()
	if not first then
		local kit = self:kitData()
		self:announceText(kit.Name .. " " .. kit.Kanji, kit.Role .. " · " .. HUD.difficultyText(kit) .. " · " .. kit.Description, GOLD)
	end
end

local function clearContent(panel)
	for _, child in panel:GetChildren() do
		if child:IsA("TextLabel") or child:IsA("TextButton") then child:Destroy() end
	end
end

-- Every combo the trainer can follow: the skill routes (★), the full routes, the short
-- routes, then the special, the ultimate and the COUP FATAL cancelled from two hits. Routes
-- with a jump (↑) are left out: the trainer follows presses, not jumps.
function HUD:trainerRoutes()
	local kit = self:kitData()
	if self.trainerCache and self.trainerCache.kit == kit then return self.trainerCache.list end
	local list = {}
	local function add(route, category, full)
		table.insert(list, { name = route.name, keys = route.keys, moves = route.moves, category = category, full = full })
	end
	-- 1. COMBOS: the skill routes (★), the short routes and the special after two hits.
	for _, route in kit.Routes do
		if route.name:find("★") and not route.keys:find("↑") then add(route, 1) end
	end
	for _, route in kit.Routes do
		if not route.name:find("★") and not route.keys:find("↑") then add(route, 1) end
	end
	local starters = kit.Starters.Ground
	local jab = kit.Roles.Jab or "Jab"
	local cross = MoveData.Moves[jab].cancels and MoveData.Moves[jab].cancels.Light or kit.Roles.Cross
	add({ name = "SPECIAL", keys = "L L E", moves = { jab, cross, kit.Roles.Rising or starters.Special } }, 1)
	-- 2. ULTIMES: the full routes (ÉVEIL / PORTE), the ultimate and the COUP FATAL.
	for _, route in kit.FullRoutes do add(route, 2, true) end
	add({ name = "ULTIMATE", keys = "L L U", moves = { jab, cross, kit.Ultimates.Rush } }, 2)
	add({ name = "FATAL BLOW", keys = "L L C", moves = { jab, cross, kit.Ultimates.Fatal } }, 2)
	list[#list - 1].cost = MoveData.Moves[kit.Ultimates.Rush].meterCost
	list[#list].cost = MoveData.Moves[kit.Ultimates.Fatal].meterCost
	list[#list].fatal = true
	self.trainerCache = { kit = kit, list = list }
	return list
end

function HUD:refreshRouteButton()
	local route = self:trainerRoutes()[self.trainerRoute]
	self.routeButton.Text = if route then "TRAINER ✓" else "TRAINER +"
	if self.trainerTitle then
		self.trainerTitle.Text = if route then route.name .. "  ·  " .. keysShort(route.keys) else ""
	end
end

-- The trainer's panel: the combos in two categories, one button each, and OFF.
function HUD:fillTrainer()
	local panel = self.trainerPanel
	if not panel then return end
	for _, child in panel:GetChildren() do
		if not child:IsA("UIStroke") and not child:IsA("UISizeConstraint") then child:Destroy() end
	end
	local function choose(index)
		self.trainerRoute = index
		self:refreshRouteButton()
		self:buildTrainer()
		self:fillTrainer()
		self.trainerPanel.Visible = false
	end
	text(panel, { Text = "TRAINER · " .. self:kitData().Name .. "  (pick a combo)", TextSize = 18, Font = UI_FONT,
		Size = UDim2.new(1, -150, 0, 26), Position = UDim2.fromOffset(10, 6), TextColor3 = RED,
		TextXAlignment = Enum.TextXAlignment.Left })
	local off = Theme.button(panel, {
		Text = "STOP", Size = UDim2.fromOffset(130, 28), Position = UDim2.new(1, -140, 0, 5), Font = Theme.UI, TextSize = 13,
		TextColor3 = Theme.MUTED,
	}, Theme.RED)
	off.Activated:Connect(function() choose(0) end)
	local routes = self:trainerRoutes()
	local titles = { "COMBOS ★ AND MOVES  ·  L = left click, R = right click, [E] = E key",
		"FULL ROUTES AND ULTIMATES  ·  [R] = R key, [C] = C key (ULTIMATES: ON button = full ki)" }
	for category, title in titles do
		local x = if category == 1 then 0 else 0.5
		text(panel, { Text = title, TextSize = 12, Font = UI_FONT, TextColor3 = GOLD, TextWrapped = true,
			Size = UDim2.new(0.5, -16, 0, 30), Position = UDim2.new(x, 10, 0, 36), TextXAlignment = Enum.TextXAlignment.Left })
		local column = new("ScrollingFrame", {
			BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(0.5, -16, 1, -76), Position = UDim2.new(x, 8, 0, 70),
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6,
			ScrollingDirection = Enum.ScrollingDirection.Y,
		}, panel)
		new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, column)
		for index, route in routes do
			if route.category == category then
				local selected = index == self.trainerRoute
				local names = {}
				for _, id in route.moves do
					local m = MoveData.Moves[id]
					table.insert(names, if m then m.name else tostring(id))
				end
				local b = Theme.button(column, {
					Text = "", Size = UDim2.new(1, -8, 0, 44), BackgroundColor3 = if selected then Theme.RAISED else Theme.PANEL,
					LayoutOrder = index,
				}, Theme.GOLD)
				if selected then Theme.rule(b, UDim2.fromOffset(0, 0), UDim2.new(0, 3, 1, 0), Theme.GOLD) end
				text(b, { Text = (if selected then "▶ " else "") .. route.name .. "   " .. keysShort(route.keys), TextSize = 13,
					Font = UI_FONT, Size = UDim2.new(1, -10, 0, 18), Position = UDim2.fromOffset(6, 3),
					TextColor3 = if selected then GOLD else WHITE, TextXAlignment = Enum.TextXAlignment.Left })
				text(b, { Text = table.concat(names, " > "), TextSize = 10, Font = UI_FONT, TextWrapped = true,
					Size = UDim2.new(1, -10, 0, 20), Position = UDim2.fromOffset(6, 22), TextColor3 = GREY,
					TextXAlignment = Enum.TextXAlignment.Left })
				b.Activated:Connect(function() choose(index) end)
			end
		end
	end
end


-- In a match: the fight HUD; in the main menu, nothing of it (the menu takes the screen).
-- The gamepad's "hold L3 to leave" bar (0: hidden).
function HUD:setLeaveProgress(progress)
	if not self.leaveBar then
		local frame = new("Frame", { Name = "LeaveHold", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 190),
			Size = UDim2.fromOffset(260, 34), BackgroundColor3 = INK, BackgroundTransparency = 0.15, Visible = false }, self.canvas)
		corner(frame, 6)
		stroke(frame, 1.5, RED).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = RED, BorderSizePixel = 0 }, frame)
		corner(fill, 6)
		text(frame, { Size = UDim2.fromScale(1, 1), Text = "HOLD L3 TO LEAVE", TextSize = 14, Font = UI_FONT, ZIndex = 2 })
		self.leaveBar = { frame = frame, fill = fill }
	end
	self.leaveBar.frame.Visible = progress > 0
	self.leaveBar.fill.Size = UDim2.fromScale(progress, 1)
end

function HUD:setInMatch(inMatch)
	self.inMatch = inMatch
	self.gui.Enabled = inMatch
end

-- A brief black-and-white flash (TARO's slip: the world slows down around the dodge).
function HUD:slowMotion(seconds)
	local Lighting = game:GetService("Lighting")
	local grade = Lighting:FindFirstChild("SlipGrade")
	if not grade then
		grade = Instance.new("ColorCorrectionEffect")
		grade.Name, grade.Parent = "SlipGrade", Lighting
	end
	self.slowSerial = (self.slowSerial or 0) + 1
	local serial = self.slowSerial
	grade.Enabled, grade.Saturation, grade.Contrast = true, -1, 0.15
	task.delay(seconds, function()
		if self.slowSerial ~= serial then return end
		game:GetService("TweenService"):Create(grade, TweenInfo.new(0.2), { Saturation = 0, Contrast = 0 }):Play()
	end)
end

-- Mouse lock state shown on its button (Ctrl toggles it; locked, the cursor is hidden).
function HUD:setMouseLock(on)
	self.mouseButton.Text = if on then "MOUSE: LOCKED (CTRL)" else "MOUSE: FREE (CTRL)"
end

-- How hard the kit is to pick up: ★ SIMPLE, ★★ MOYEN, ★★★ TECHNIQUE.
HUD.DIFFICULTY = { "SIMPLE", "MEDIUM", "TECHNICAL" }
function HUD.difficultyText(kit)
	local level = kit.Difficulty or 2
	return string.rep("★", level) .. string.rep("☆", 3 - level) .. " " .. HUD.DIFFICULTY[level]
end

-- Combo routes of the kit, its ultimates, specials and passive.
function HUD:fillCombos()
	local panel = self.combosPanel
	clearContent(panel)
	local kit = self:kitData()
	local u = kit.Ultimates
	local lines = {
		{ kit.Name .. " " .. kit.Kanji .. " · " .. kit.Role .. " · " .. HUD.difficultyText(kit), RED },
		{ kit.Description, GREY },
		{ "COMBOS  ·  L = left click, R = right click", RED },
	}
	-- The full routes first (the 6-press combos that open the ultimates), then the short ones.
	table.insert(lines, { "FULL ROUTES (6 presses, ending: " .. moveName(kit, "KiChase") .. " > " .. moveName(kit, "Finale") .. ")", RED })
	for _, route in kit.FullRoutes do
		local names = {}
		for i = 1, math.min(4, #route.moves) do table.insert(names, MoveData.Moves[route.moves[i]].name) end
		table.insert(lines, { route.keys .. "  →  " .. route.name .. "  (" .. table.concat(names, " > ") .. "…)", WHITE })
	end
	table.insert(lines, { "SHORT COMBOS", RED })
	for _, route in kit.Routes do
		local names = {}
		for _, id in route.moves do table.insert(names, MoveData.Moves[id].name) end
		table.insert(lines, { route.keys .. "  →  " .. table.concat(names, " > "), WHITE })
	end
	table.insert(lines, { "RHYTHM: each press AFTER the previous blow comes out. Pressed too early, the combo goes on but is no longer CLEAN (no ultimate). Guard, jump or dash cancel the queued blows.", GOLD })
	table.insert(lines, { "3 ULTIMATES (CLEAN route only)", GOLD })
	table.insert(lines, { "1. R KEY on the keyboard (2 bars), alone or after a blow that lands (e.g. L-CLICK, L-CLICK, then R KEY): " .. moveName(kit, u.Rush), ULTIMATE })
	table.insert(lines, { "2. Full route, 6th = R-CLICK (3 bars): " .. moveName(kit, u.Awaken) .. ", finale depends on the route", ULTIMATE })
	table.insert(lines, { "   up to −30 % of max health: each QTE missed during the flurry takes some off; FINAL FINISH if it finishes", ULTIMATE })
	table.insert(lines, { "3. Full route, 6th = R key (3 bars): " .. kit.GateTitle.text .. " " .. kit.GateTitle.sub .. " (R at the peak: +10 %; missed: −15 %)", ULTIMATE })
	table.insert(lines, { "FATAL BLOW · C key (gamepad L1): " .. moveName(kit, "Fatal") .. " — 3 bars, your health under 30 %, once per match", ULTIMATE })
	table.insert(lines, { "   in a combo: −50 % of max health; raw: −30 %; only kills under half health; missed QTE: −40 % of the blow; parried or dodged: lost", ULTIMATE })
	table.insert(lines, { "↓ + L: " .. moveName(kit, "LowKick") .. " (low guard)  ·  ↓ + R: " .. moveName(kit, "Uppercut") .. " (launcher)", WHITE })
	table.insert(lines, { "After the launcher: SPACE then L L R in the air", WHITE })
	table.insert(lines, { "E after a blow: " .. moveName(kit, "Rising") .. " (invincible at startup)", ORANGE })
	if kit.Stances then
		-- TARO: two styles, switched in neutral (keys 1 / & and 2 / é, or the HUD buttons).
		for rank, id in kit.Stances.Order do
			local stance = kit.Stances[id]
			local special = MoveData.Moves[stance.CrouchSpecial]
			local guard = math.floor((1 - (stance.Stats.GuardDamageTaken or 1)) * 100 + 0.5)
			local power = math.floor(((stance.Stats.DamageDealt or 1) - 1) * 100 + 0.5)
			table.insert(lines, { string.format("%d / %s: %s · damage %+d %% · guard %s%s · ↓ + E: %s", rank, stance.Key, stance.Name,
				power, if guard > 0 then "-" .. guard .. " % chip" else "normal", "", special and special.name or "?"), ORANGE })
			if stance.Weave then
				table.insert(lines, { "   DASH TOWARD THE OPPONENT = BODY SWAY (high blows dodged, + ki) · during / right after: L = DEMPSEY ROLL (L again up to "
					.. stance.Weave.MaxHooks .. ") · R = FINAL HOOK · ↓ + E = PARRY that counters", ORANGE })
			else
				table.insert(lines, { "   iron guard, heavier hits · ↓ + E = CHAMPION'S RIGHT (slow, crushes the guard, knocks down)", ORANGE })
			end
		end
	else
		local crouchSpecial = kit.Starters.Crouch.Special
		local special = MoveData.Moves[crouchSpecial]
		if special and special.parry and special.parry.lows then
			table.insert(lines, { "↓ + E: " .. special.name .. " (takes any blow, even low, taking only "
				.. math.floor((special.parry.absorb or 0) * 100 + 0.5) .. " % of the damage, then strikes back; loses to ultimates)", ORANGE })
		elseif special and special.parry then
			table.insert(lines, { "↓ + E: " .. special.name .. " (counters standing blows and projectiles; loses to low blows and ultimates)", ORANGE })
		elseif special and special.projectile and special.projectile.guard == "Low" then
			table.insert(lines, { "↓ + E: " .. moveName(kit, crouchSpecial) .. " (wave along the floor: block it crouching, 1 at a time)", ORANGE })
		else
			table.insert(lines, { "↓ + E: " .. moveName(kit, crouchSpecial) .. " (projectile, 1 at a time)", ORANGE })
		end
	end
	local passive = kit.Passive
	if passive and passive.Type == "Evade" then
		table.insert(lines, { "PASSIVE " .. passive.Name .. " (like Ultra Instinct): in neutral, an incoming blow is dodged on its own; "
			.. (passive.Charges or 1) .. " dodges in reserve, each comes back in " .. math.floor(passive.Cooldown / 60)
			.. " s (faster when she lands hits). Right after the dodge, L-CLICK or R-CLICK: she reappears behind and strikes (a guard pressed just in time reads it). Never against ultimates.", ORANGE })
	elseif passive and passive.Type == "Rage" then
		table.insert(lines, { "PASSIVE " .. passive.Name .. ": each blow that lands (not blocked) adds +" .. passive.PerStack * 100 .. " % damage (up to "
			.. passive.Max .. "), all lost as soon as he is hit.", ORANGE })
	elseif passive and passive.Type == "Tip" then
		table.insert(lines, { "PASSIVE " .. passive.Name .. ": a hit with the tip of the blade (opponent at the end of the reach) does +"
			.. math.floor(passive.Bonus * 100 + 0.5) .. " % damage.", ORANGE })
	elseif passive and passive.Type == "Blink" then
		table.insert(lines, { "PASSIVE " .. passive.Name .. ": SHIFT toward the opponent (within " .. passive.Range
			.. " m) goes through and reappears behind, untouchable for a moment; cooldown " .. string.format("%.1f", passive.Cooldown / 60) .. " s.", ORANGE })
	elseif passive and passive.Type == "Ruins" then
		table.insert(lines, { "PASSIVE " .. passive.Name .. ": the more he is hurt, the harder he hits (up to +"
			.. math.floor(passive.MaxBonus * 100 + 0.5) .. " % at " .. math.floor(passive.To * 100 + 0.5) .. " % health).", ORANGE })
	end
	if kit.Stats.DashInvuln then
		table.insert(lines, { "DASH: untouchable for " .. kit.Stats.DashInvuln .. " frames at the start", ORANGE })
	end
	table.insert(lines, { "HEALTH " .. kit.Stats.MaxHealth .. " · ★ = skill: alternate left click / right click", GREY })
	table.insert(lines, { "only 1 crumple, ground bounce and wall bounce per combo", GREY })
	table.insert(lines, { "T: change fighter · G: CPU fighter (solo)", GREY })
	for i, line in lines do
		local l = text(panel, { Text = line[1], TextColor3 = line[2], Font = if i == 1 then DISPLAY else UI_FONT,
			TextSize = if i == 1 then 22 else 12, Size = UDim2.new(1, -10, 0, if i == 1 then 24 else 18),
			TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = i, TextWrapped = true })
		l.AutomaticSize = Enum.AutomaticSize.Y
	end
end

-- Rebuilds the six boxes of the combo trainer for the selected route.
function HUD:buildTrainer()
	for _, box in self.trainerBoxes do box.frame:Destroy() end
	self.trainerBoxes = {}
	local route = self:trainerRoutes()[self.trainerRoute]
	self.trainer.Visible = route ~= nil
	if not route then return end
	local keys = {}
	for k in route.keys:gmatch("%S") do table.insert(keys, k) end
	for i, key in keys do
		local frame = new("Frame", {
			Size = UDim2.fromOffset(84, 70), Position = UDim2.fromOffset((i - 1) * 92, 44),
			BackgroundColor3 = INK, BackgroundTransparency = 0.1, BorderSizePixel = 0,
		}, self.trainer)
		local outline = stroke(frame, 3, Color3.fromHex("55555F"))
		outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		local keyLabel = text(frame, { Text = KEY_LABEL[key] or key, TextSize = 24, Size = UDim2.new(1, -6, 0, 36),
			Position = UDim2.fromOffset(3, 0), TextScaled = true })
		new("UITextSizeConstraint", { MaxTextSize = 24, MinTextSize = 10 }, keyLabel)
		local m = MoveData.Moves[route.moves[i]]
		local moveLabel = text(frame, { Text = if m then m.name else route.moves[i], TextSize = 10, Font = UI_FONT,
			Size = UDim2.new(1, -4, 0, 30), Position = UDim2.fromOffset(2, 36), TextWrapped = true, TextScaled = true,
			TextColor3 = GREY })
		new("UITextSizeConstraint", { MaxTextSize = 12, MinTextSize = 6 }, moveLabel)
		self.trainerBoxes[i] = { frame = frame, outline = outline, key = key, keyLabel = keyLabel, moveLabel = moveLabel }
	end
end

-- Training lab: buttons that play each cinematic of the kit directly (solo only).
function HUD:fillLab()
	local panel = self.labPanel
	clearContent(panel)
	local kit = self:kitData()
	text(panel, { Text = "CINE LAB · " .. kit.Name, TextSize = 22, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 0,
		TextXAlignment = Enum.TextXAlignment.Left })
	text(panel, { Text = "Plays a cinematic without doing the combo (solo). Turn HITBOX on to see the shot names.",
		TextSize = 11, Font = UI_FONT, Size = UDim2.new(1, 0, 0, 30), TextWrapped = true, LayoutOrder = 1,
		TextColor3 = GREY, TextXAlignment = Enum.TextXAlignment.Left })
	local order = 2
	local function add(label, callback)
		local b = Theme.button(panel, {
			Text = label, Size = UDim2.new(1, 0, 0, 28), Font = Theme.UI, TextSize = 12, TextColor3 = Theme.WHITE,
			LayoutOrder = order,
		}, Theme.RED)
		order += 1
		b.Activated:Connect(callback)
		return b
	end
	local function play(kind, style, finish)
		return function()
			if self.onDebugCinematic then self.onDebugCinematic(kind, style, finish) end
		end
	end
	local u = kit.Ultimates
	add("1 · " .. moveName(kit, u.Rush), play("Rush", nil, false))
	for _, route in kit.FullRoutes do
		add("2 · " .. moveName(kit, u.Awaken) .. " · " .. route.name, play("Awaken", route.name, false))
	end
	add("2 · AWAKENING · FINAL FINISH (target < 50 %)", play("Awaken", kit.FullRoutes[1].name, true))
	add("3 · " .. kit.GateTitle.sub, play("Gate", nil, false))
	add("3 · " .. kit.GateTitle.sub .. " · K.O. (weak target)", play("Gate", nil, true))
	add("4 · FATAL BLOW · " .. moveName(kit, "Fatal") .. " (in a combo)", play("Fatal", nil, false))
	add("4 · FATAL BLOW · K.O. (its K.O. screen)", play("Fatal", nil, true))
	add("4 · FATAL BLOW · raw", play("Fatal", "raw", false))
	add("K.O. SCENE (preview only)", function()
		if self.onPreviewKO then self.onPreviewKO() end
	end)
end

-- Combo trainer: compares the route typed so far (chainKeys from the server) with the
-- selected route, lights the next box and says why a combo broke.
function HUD:updateTrainer(view, meterFull)
	local kit = self:kitData()
	local route = self:trainerRoutes()[self.trainerRoute]
	if not route or not view then
		self.trainer.Visible = false
		return
	end
	self.trainer.Visible = true
	local keys = route.keys:gsub("%s", "")
	local n = #keys
	local typed = view.chainKeys or ""
	local progress, failed = 0, false
	if typed ~= "" then
		if typed:sub(1, n) == keys then
			progress = n -- done (going on afterwards does not undo it)
		elseif keys:sub(1, #typed) == typed then
			progress = #typed
		elseif route.full and #typed == 6 and keys:sub(1, 5) == typed:sub(1, 5) and typed:sub(6, 6) == "U" then
			progress = 6 -- ended on the R key: the gate ultimate
		else
			failed = true
			for i = 1, #typed do
				if keys:sub(i, i) == typed:sub(i, i) then progress = i else break end
			end
		end
	end
	local attacking = view.state == "Attack" or view.cancelReady
	for i, box in self.trainerBoxes do
		local color = Color3.fromHex("55555F")
		if i <= progress then
			color = Color3.fromHex("3DDC84")
		elseif failed and i == progress + 1 then
			color = RED
		elseif i == progress + 1 and attacking then
			color = if view.cancelReady then GOLD else WHITE
		end
		box.outline.Color = color
		if route.full and i == 6 then
			box.keyLabel.Text = if meterFull then "R-CLICK or R" else "R-CLICK"
			box.moveLabel.Text = if meterFull then "R-CLICK = AWAKENING · R KEY = " .. kit.GateTitle.text else moveName(kit, "Finale")
		end
	end
	self.trainerNow.Visible = view.cancelReady == true and progress >= 1 and progress < n and not failed
	local reason = DIRTY[view.dirtyReason or ""] or "not CLEAN: wrong button, press too early or one too many"
	if failed then
		self.trainerStatus.Text = "MISSED: it needed " .. (KEY_LABEL[keys:sub(progress + 1, progress + 1)] or "?")
			.. " — start again from the 1st blow"
		self.trainerStatus.TextColor3 = RED
	elseif progress >= n then
		self.trainerStatus.Text = if not route.full then "COMBO CLEARED ✓"
			elseif view.chainClean then "ROUTE CLEARED · CLEAN ✓" else "ROUTE CLEARED · " .. reason .. ": no ultimate"
		self.trainerStatus.TextColor3 = Color3.fromHex("3DDC84")
	elseif route.cost and (view.meter or 0) < route.cost then
		-- An ultimate needs its ki first: say it plainly (in training the gauge refills when calm).
		self.trainerStatus.Text = string.format("You need %d ki bars (you have %d): turn ULTIMATES: ON at the top",
			route.cost // 100, (view.meter or 0) // 100)
		self.trainerStatus.TextColor3 = ORANGE
	elseif progress >= 1 then
		local nextKey = KEY_LABEL[keys:sub(progress + 1, progress + 1)] or "?"
		self.trainerStatus.Text = (if view.chainClean then "CLEAN ✓ · now " .. nextKey .. " when the blow lands (yellow box)" else reason)
			.. (if route.full then "  ·  ki " .. (if meterFull then "3 bars ✓" else "< 3 bars") else "")
		self.trainerStatus.TextColor3 = if view.chainClean then WHITE else ORANGE
	else
		self.trainerStatus.Text = "Stand next to the dummy (STILL mode) and do: " .. keysInWords(route.keys)
			.. (if route.fatal then " (in training, low health is not needed)" else "")
			.. "  ·  combo: " .. keysShort(route.keys)
		self.trainerStatus.TextColor3 = GREY
	end
end

-- Recolours a side of the HUD after its fighter changed kit or style (CLASSIQUE, NUIT...).
-- The fighter's face in the portrait (SF6 / Strive): the 3D body of its style (or of its kit,
-- while the style's is not built), a camera on its head, turned three quarters toward the
-- middle of the screen. Cosmetic; tried again until the body is there.
function HUD:setPortrait(slot, kit)
	local bar = self.bars[slot]
	if not bar then return end
	local skin = CharacterData[slot] and CharacterData[slot].Skin or ""
	local key = tostring(kit) .. "/" .. tostring(skin)
	if bar.portraitKey == key then return end
	local styles = ReplicatedStorage:FindFirstChild("StylePreviews")
	local kits = ReplicatedStorage:FindFirstChild("KitPreviews")
	local source = (styles and styles:FindFirstChild(skin)) or (kits and kit and kits:FindFirstChild(kit))
	if not source then return end -- (not built yet: tried again next frame)
	local head0 = source:FindFirstChild("Head")
	if not head0 then return end
	bar.portraitKey = key
	for _, child in bar.face:GetChildren() do
		if child:IsA("Model") or child:IsA("Camera") then child:Destroy() end
	end
	local model = source:Clone()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then d.Anchored = true end
	end
	model.Parent = bar.face
	local head = model:FindFirstChild("Head")
	local camera = new("Camera", { FieldOfView = 30 }, bar.face)
	bar.face.CurrentCamera = camera
	local look = head.CFrame.LookVector
	local turn = math.rad(if bar.left then 28 else -28)
	local dir = CFrame.fromAxisAngle(Vector3.yAxis, turn):VectorToWorldSpace(look)
	local target = head.Position + Vector3.new(0, -0.25, 0)
	camera.CFrame = CFrame.lookAt(target + dir * 4.6 + Vector3.new(0, 0.35, 0), target)
end

function HUD:applyLook(slot)
	local bar = self.bars[slot]
	local data = CharacterData[slot]
	if not bar or bar.skin == data.Skin then return end
	bar.skin = data.Skin
	bar.kanji.Text, bar.name.Text = data.Kanji, data.Name
	local energy, shield = Color3.fromHex(data.Energy), Color3.fromHex(data.Shield)
	bar.energy = energy
	local items = bar.side:GetDescendants()
	for _, item in bar.kiPanel:GetDescendants() do table.insert(items, item) end -- (the KI gauge, in its corner)
	for _, item in items do
		local kind = item:GetAttribute("Tint")
		local color = if kind == "Energy" then energy elseif kind == "Shield" then shield else nil
		if color then
			if item:IsA("UIStroke") then item.Color = color
			elseif item:IsA("TextLabel") then item.TextColor3 = color
			elseif item:IsA("ImageLabel") then item.ImageColor3 = color
			elseif item:IsA("GuiObject") then item.BackgroundColor3 = color end
		end
	end
	bar.gradient.Color = healthColors(energy)
	bar.healthBucket = nil -- (the health colour is drawn again with the new look)
	bar.portraitKey = nil -- (the face too)
	self.callouts[slot].label.TextColor3 = energy
	self.combo[slot].count.TextColor3 = energy
end

function HUD:setEffectsReduced(reduced)
	self.reduced = reduced -- (no shaking header)
	self.effectsButton.Text = if reduced then "EFFECTS: REDUCED" else "EFFECTS: FULL"
end

-- What the loser of a PERFECT round reads.
-- Taunts for the loser of a PERFECT: famous lines of games and players found on the web
-- (sources in docs/JOURNAL.md, v0.13.5), then a few of our own.
HUD.LOSER_LINES = {
	"GIT GUD.", -- Dark Souls / internet slang
	"FLAWLESS VICTORY.", -- Mortal Kombat
	"You must defeat Sheng Long to stand a chance.", -- Ryu, Street Fighter II
	"Handsome fighters never lose battles.", -- Vega, Street Fighter II
	"I will meditate and then destroy you!", -- Dhalsim, Street Fighter II
	"Like taking candy from a baby… except the baby would have put up a better fight.", -- Walshy, Halo
	"You can't beat me.", -- LowTierGod
	"GET OVER HERE… and learn to play.", -- Scorpion, Mortal Kombat
	"TOASTY!", -- Mortal Kombat
	"LOSER… not a single hit landed.",
	"Zero damage. ZERO.",
	"You hit the wind. Well done.",
	"Even the training dummy did better.",
	"GG… well, mostly G for them.",
}

function HUD:announceText(main, sub, color, size, hold)
	local a = self.announce
	local band = self.announceBand
	band.Visible = true
	band.Size = UDim2.new(0, 0, 0, 170)
	tween(band, 0.28, { Size = UDim2.new(1, 0, 0, 170) }, Enum.EasingStyle.Quint)
	-- (speed lines across the band)
	if not self.reduced then
		for i, streak in self.announceStreaks do
			streak.Visible = true
			streak.Position = UDim2.fromScale(-0.2 - (i % 3) * 0.1, 0.15 + i * 0.1)
			tween(streak, 0.45 + (i % 4) * 0.07, { Position = UDim2.fromScale(1.25, 0.15 + i * 0.1) }, Enum.EasingStyle.Quart)
		end
	end
	-- FIGHT! and K.O.: the screen flashes (white, red)
	if (main == "FIGHT!" or main == "K.O.") and not self.reduced then
		self.screenFlash.BackgroundColor3 = if main == "K.O." then Color3.fromHex("FF2A3D") else WHITE
		self.screenFlash.BackgroundTransparency = if main == "K.O." then 0.45 else 0.6
		tween(self.screenFlash, 0.35, { BackgroundTransparency = 1 })
	end
	-- (size: a bigger title, PERFECT; hold: seconds on screen)
	local box = self.announceLetters
	for _, child in box:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	local lang = Players.LocalPlayer:GetAttribute("UILanguage")
	local shown = if lang == "FR" then Locale.translate(main, "FR") else main
	local short = utf8.len(shown) ~= nil and utf8.len(shown) <= 12
	if short then
		-- the letters slam in one after the other, each from big, its top lit
		a.Visible = false
		box.Visible = true
		local s = size or 1
		local n = 0
		for _, code in utf8.codes(shown) do
			n += 1
			local ch = utf8.char(code)
			if ch == " " then
				new("Frame", { Size = UDim2.fromOffset(math.floor(34 * s), 10), BackgroundTransparency = 1, LayoutOrder = n }, box)
			else
				local l = text(box, { Name = "Letter", Text = ch, TextSize = math.floor(110 * s), Size = UDim2.fromOffset(0, math.floor(130 * s)),
					AutomaticSize = Enum.AutomaticSize.X, TextColor3 = color or WHITE, TextTransparency = 1, LayoutOrder = n })
				l:SetAttribute("Untranslated", true)
				stroke(l, 6)
				new("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, Color3.fromRGB(165, 165, 175)) }, l)
				local scale = new("UIScale", { Scale = 2.6 }, l)
				local delay = if self.reduced then 0 else (n - 1) * 0.045
				task.delay(delay, function()
					l.TextTransparency = 0
					tween(scale, 0.24, { Scale = 1 }, Enum.EasingStyle.Back)
				end)
			end
		end
	else
		box.Visible = false
		a.Text, a.TextColor3, a.Visible, a.TextTransparency = main, color or WHITE, true, 0
		self.announceScale.Scale = 2.4 * (size or 1)
		tween(self.announceScale, 0.22, { Scale = size or 1 }, Enum.EasingStyle.Back)
	end
	self.announceSub.Text, self.announceSub.Visible = sub or "", sub ~= nil
	self.announceId = (self.announceId or 0) + 1
	local id = self.announceId
	task.delay(hold or 1.3, function()
		if self.announceId ~= id then return end
		tween(a, 0.25, { TextTransparency = 1 })
		for _, l in box:GetChildren() do
			if l:IsA("TextLabel") then tween(l, 0.2, { TextTransparency = 1 }) end
		end
		tween(band, 0.25, { Size = UDim2.new(0, 0, 0, 170) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		self.announceSub.Visible = false
		-- Hidden once faded: the text's UIStroke outline does not fade with it.
		task.delay(0.26, function()
			if self.announceId == id then
				a.Visible, band.Visible, box.Visible = false, false, false
				for _, streak in self.announceStreaks do streak.Visible = false end
			end
		end)
	end)
end

-- Rounds are announced from the snapshot phase so a client joining mid-intro still sees it.
function HUD:announceRound(round)
	self:announceText("ROUND " .. round, CharacterData[1].Name .. " " .. (CharacterData[1].Title or CharacterData[1].Skin) .. "  VS  "
		.. CharacterData[2].Name .. " " .. (CharacterData[2].Title or CharacterData[2].Skin))
end

-- Slanted technique name on a fighter's side.
function HUD:callout(slot, label)
	local callout = self.callouts[slot]
	if not callout then return end
	callout.label.Text = label
	callout.label.Visible, callout.label.TextTransparency = true, 0
	callout.scale.Scale = 1.8
	tween(callout.scale, 0.16, { Scale = 1 }, Enum.EasingStyle.Back)
	local id = (callout.id or 0) + 1
	callout.id = id
	task.delay(1.1, function()
		if callout.id ~= id then return end
		tween(callout.label, 0.25, { TextTransparency = 1 })
		task.delay(0.26, function()
			if callout.id == id then callout.label.Visible = false end
		end)
	end)
end

function HUD:onEvent(event, world)
	-- SHIN's PRÉCISION: a hit with the tip of the blade.
	if event.kind == "Hit" and event.tip then self:callout(event.attacker, "BLADE TIP!") end
	if event.kind == "Hit" and event.counter then self:callout(event.attacker, "COUNTER!") end
	-- TRAINING: the frame advantage of the exchange (+: the attacker's turn, -: punishable)
	if event.kind == "FrameAdvantage" and world and world.training then
		self:callout(event.attacker, string.format("%+d ON %s", event.frames, if event.blocked then "BLOCK" else "HIT"))
	end
	if event.kind == "Hit" and event.combo and event.combo >= 2 then
		local c = self.combo[event.attacker]
		c.frame.Visible = true
		c.count.Text = tostring(event.combo)
		local m = MoveData.Moves[event.move]
		c.detail.Text = (if m and m.heavy then m.name .. " · " else "") .. event.comboDamage .. " DAMAGE"
		c.scale.Scale = 1.5
		tween(c.scale, 0.15, { Scale = 1 }, Enum.EasingStyle.Back)
		c.expires = os.clock() + 1.4
	elseif event.kind == "Skill" then
		local m = MoveData.Moves[event.move]
		self:callout(event.attacker, (if m then m.name else event.move) .. "!")
	elseif event.kind == "Parry" then
		-- TARO's PARADE, HIBECARES's MUR DE PIERRE (the share of the blow it took).
		local label = if event.name then event.name .. "!" else "PARRY!"
		if event.absorbed then label ..= " −" .. event.absorbed end
		self:callout(event.defender, label)
	elseif event.kind == "Blink" and event.counter then
		self:callout(event.slot, "COUNTER-INSTINCT!")
	elseif event.kind == "Read" then
		self:callout(event.slot, "READ!") -- (AKEMI's counter read: guarded in time)
	elseif event.kind == "Blink" and not event.move then
		local kit = MoveData.Kits[CharacterData[event.slot].Kit]
		self:callout(event.slot, (if kit and kit.Passive then kit.Passive.Name else "TELEPORT") .. "!")
	elseif event.kind == "Evade" then
		local kit = MoveData.Kits[CharacterData[event.defender].Kit]
		local name = if kit and kit.Stats and kit.Stats.AutoEvade then "DIVINE INSTINCT"
			elseif kit and kit.Passive then kit.Passive.Name else "DODGE"
		self:callout(event.defender, name .. "!")
	elseif event.kind == "Burst" then
		self:callout(event.slot, "BURST!")
	elseif event.kind == "Slip" then
		self:callout(event.defender, "DODGE!")
		self:slowMotion(0.45) -- black and white for the slow-down
	elseif event.kind == "Stance" then
		self:callout(event.slot, (event.name or event.stance) .. "!")
		-- The local player: how the new style plays, in one line.
		if event.slot == (Players.LocalPlayer:GetAttribute("FighterSlot") or 0) then
			local hint = if event.stance == "PEEKABOO"
				then "SHIFT toward the opponent = DODGE · then left click = DEMPSEY ROLL · S + E = PARRY"
				else "Iron guard, heavier hits · S + E = CHAMPION'S RIGHT"
			self:announceText(event.name or event.stance, hint, Color3.fromHex("FFB21A"))
		end
	elseif event.kind == "PassiveReady" then
		self:callout(event.slot, event.name .. "!")
	elseif event.kind == "Chilled" then
		self:callout(event.slot, "FROZEN! −20 % SPEED")
	elseif event.kind == "Armor" then
		local kit = MoveData.Kits[CharacterData[event.defender].Kit]
		self:callout(event.defender, (if kit and kit.Passive then kit.Passive.Name else "ANCHOR") .. "! −" .. event.damage)
	elseif event.kind == "Revive" then
		self:callout(event.slot, "SECOND LIFE!")
		self:announceText("ASURA RISES AGAIN", "SECOND LIFE · BLACK AURA", Color3.fromHex("B0102A"), 1.2, 1.6)
	elseif event.kind == "Heal" then
		self:callout(event.slot, "+" .. event.amount .. " HP")
	elseif event.kind == "Reflect" then
		self:callout(event.slot, "ICE MIRROR!")
	elseif event.kind == "Shackled" then
		self:callout(event.slot, "SHACKLED! DASH CUT")
	elseif event.kind == "Domination" then
		-- KUROEN: the level reached, spent or lost, so both players can read the danger.
		local titles = { "DOMINATION I · AWAKENING", "DOMINATION II · SUPREMACY", "DOMINATION III · ECLIPSE" }
		if event.lost then
			self:callout(event.slot, "DOMINATION LOST")
		elseif event.spent then
			local m = MoveData.Moves[event.spent]
			self:callout(event.slot, (if m then m.name else "DOMINATION") .. "!")
		elseif titles[event.level] then
			self:callout(event.slot, titles[event.level] .. "!")
		end
	elseif event.kind == "Drone" then
		self:callout(event.slot, "SENTRY!")
	elseif event.kind == "PassiveEmpty" then
		self:callout(event.slot, "NO DRONE LEFT")
	elseif event.kind == "PassiveUsed" and event.cost then
		self:callout(event.slot, "PACT −" .. event.cost .. " HP")
	elseif event.kind == "ClashStep" then
		self:callout(event.slot, "CLASH STEP!")
	elseif event.kind == "Resolve" then
		self:callout(event.slot, "RESOLVE!")
	elseif event.kind == "Feint" then
		self:callout(event.slot, "FEINT")
	elseif event.kind == "Perfect" and event.finisher then
		self:callout(event.slot, "PERFECT FINISHER ✦")
	elseif event.kind == "Evade" and (event.flow or event.style == "INSTINCT") then
		self:callout(event.defender, if event.flow then "FLOW DODGE!" else "INSTINCT!")
	elseif event.kind == "GuardBreak" then
		-- (a callout on the breaker's side, not the whole screen: Wilhem « le guard break qui prend
		-- tout l'écran, enlève-moi ça »)
		if event.attacker then self:callout(event.attacker, "GUARD BREAK!") end
	elseif event.kind == "Fight" then
		self:announceText("FIGHT!", nil, RED)
	elseif event.kind == "RoundEnd" then
		local main = if event.reason == "Timeout" then "TIME OVER" elseif event.winner == 0 then "DOUBLE K.O." else "K.O."
		local sub
		if not world.training then
			sub = if event.winner == 0 then "DRAW" else CharacterData[event.winner].Name .. " " .. (CharacterData[event.winner].Title or CharacterData[event.winner].Skin) .. " WINS THE ROUND"
		end
		if event.perfect and not world.training and event.winner ~= 0 then
			-- PERFECT: the round won without losing any health. Big and gold for the winner (and
			-- whoever watches); the loser gets a line to remember it by.
			local localSlot = Players.LocalPlayer:GetAttribute("FighterSlot") or 0
			if localSlot == 3 - event.winner then
				local lines = HUD.LOSER_LINES
				self:announceText("PERFECT", lines[(event.tick or 0) % #lines + 1], RED, 1.6, 2.6)
			else
				self:announceText("PERFECT", sub, Color3.fromHex("FFD23F"), 1.6, 2.6)
			end
			return
		end
		-- (one K.O. on screen: a finishing cinematic or the match's K.O. scene shows its own)
		-- (decided by the server: the snapshot here may still hold the score before this K.O.)
		if main == "K.O." and (event.matchOver or event.inCinematic or world.cinematic) then return end
		self:announceText(main, sub, if main == "K.O." then RED else WHITE)
	elseif event.kind == "MatchEnd" then
		-- (a won match: its K.O. scene already says K.O. · VICTORY; only a draw is announced here)
		if event.winner == 0 or world.training then
			self:announceText(if event.winner == 0 then "DRAW GAME" else CharacterData[event.winner].Name .. " WINS!", "VICTORY", RED)
		end
	end
end

-- Called every rendered frame with the latest authoritative snapshot.
function HUD:update(world, views, fps, dt)
	if not views[1] or not views[2] then return end
	local localSlot = Players.LocalPlayer:GetAttribute("FighterSlot") or 0
	for slot, view in views do
		local bar = self.bars[slot]
		local kit = MoveData.Kits[view.kit] or MoveData.Kits.KAI
		self:setPortrait(slot, view.kit) -- (its face; a relay's next fighter changes it)
		local ratio = math.clamp(view.hp / (view.maxHp or kit.Stats.MaxHealth), 0, 1)
		bar.fill.Size = UDim2.fromScale(ratio, 1)
		-- (UI pass) a blow taken: the health left flashes white; a big one shakes the side
		if ratio < bar.lastRatio - 0.001 then
			bar.hitFlash.BackgroundTransparency = 0.1
			tween(bar.hitFlash, 0.22, { BackgroundTransparency = 1 })
			-- (the chunk just lost burns white, then cools to the red trail; the tip flares)
			bar.trail.BackgroundColor3 = WHITE
			tween(bar.trail, 0.35, { BackgroundColor3 = RED })
			bar.tip.Size = UDim2.new(0, 34, 1, 0)
			tween(bar.tip, 0.3, { Size = UDim2.new(0, 16, 1, 0) })
			if bar.lastRatio - ratio > 0.07 and not self.reduced then
				local dir = if slot == 1 then -1 else 1
				bar.side.Position = bar.sideBase + UDim2.fromOffset(dir * 7, 3)
				tween(bar.side, 0.3, { Position = bar.sideBase }, Enum.EasingStyle.Elastic)
			end
		end
		bar.lastRatio = ratio
		-- its colour follows the health left: white, amber under half, a red that beats under a quarter
		local bucket = if ratio > 0.5 then "high" elseif ratio > 0.25 then "mid" else "low"
		if bucket ~= bar.healthBucket or bucket == "low" then
			bar.healthBucket = bucket
			if bucket == "high" then
				bar.gradient.Color = healthColors(bar.energy)
			elseif bucket == "mid" then
				bar.gradient.Color = ColorSequence.new(Color3.fromHex("FFE9A8"), Color3.fromHex("FFC24A"))
			else
				local beat = 0.5 + 0.5 * math.sin(os.clock() * 7)
				local red = Color3.fromHex("FF2A3D"):Lerp(Color3.fromHex("FF9AA4"), beat * 0.6)
				bar.gradient.Color = ColorSequence.new(red, Color3.fromHex("C0101F"))
			end
		end
		-- (alive: the flow drifts toward the timer, a glint every 3.5 s, the tip breathes)
		local live = not self.reduced and ratio > 0
		bar.flow.Visible, bar.glint.Visible, bar.tip.Visible = live, live, ratio > 0
		if live then
			local t = os.clock()
			bar.flowGradient.Offset = Vector2.new((t * 0.12) % 0.25, 0)
			local cycle = (t + slot * 0.9) % 3.5
			bar.glintGradient.Offset = Vector2.new(if cycle < 0.7 then -1 + cycle / 0.7 * 2 else -1, 0)
			bar.tip.BackgroundTransparency = 0.15 + 0.25 * (0.5 + 0.5 * math.sin(t * 5 + slot))
		end
		-- The red trail waits while the combo continues, then catches up.
		if view.combo == 0 or self.trail[slot] < ratio then
			self.trail[slot] = math.max(ratio, self.trail[slot] - dt * 0.6)
		end
		bar.trail.Size = UDim2.fromScale(self.trail[slot], 1)
		-- COUP FATAL ready: the bar burns (aura, flame, crimson outline)
		local fatal = view.fatal == "ready"
		bar.aura.Visible, bar.flame.Visible = fatal, fatal
		if fatal then
			local t = os.clock()
			local pulse = 0.5 + 0.5 * math.sin(t * 7)
			bar.auraStroke.Transparency = 0.1 + 0.5 * pulse
			bar.auraStroke.Thickness = 3 + 4 * (1 - pulse)
			bar.flameGradient.Offset = Vector2.new((t * 0.9) % 2 - 1, 0)
			bar.flameGradient.Rotation = if slot == 1 then 0 else 180
			bar.barStroke.Color = FATAL
			bar.portraitStroke.Color = FATAL
		else
			bar.barStroke.Color = bar.edgeColor
			bar.portraitStroke.Color = bar.energy
		end
		-- CREATOR (the game's owner): a gold tag, the portrait's edge and the name in a moving
		-- gold and white sheen. VIP: the rainbow (the edge cycles through the hues, the name striped).
		local creator = string.find(view.badges or "", "CREATOR", 1, true) ~= nil
		local vip = not creator and string.find(view.badges or "", "VIP", 1, true) ~= nil
		bar.nameRainbow.Enabled, bar.vipTag.Visible = vip or creator, vip or creator
		if creator ~= bar.creatorLook then
			bar.creatorLook = creator
			bar.vipTag.Text = if creator then "★ CREATOR" else "VIP"
			bar.vipTag.Size = UDim2.fromOffset(if creator then 74 else 30, 14)
			bar.nameRainbow.Color = if creator then ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHex("FFB21A")), ColorSequenceKeypoint.new(0.45, Color3.fromHex("FFE9A8")),
				ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.55, Color3.fromHex("FFE9A8")),
				ColorSequenceKeypoint.new(1, Color3.fromHex("FFB21A")) }) else bar.rainbowColors
		end
		if creator then
			local t = os.clock()
			bar.nameRainbow.Offset = Vector2.new((t * 0.6) % 2 - 1, 0)
			bar.player.TextColor3 = WHITE
			local gold = Color3.fromHex("FFD23F"):Lerp(Color3.new(1, 1, 1), 0.5 + 0.5 * math.sin(t * 3))
			if not fatal then bar.portraitStroke.Color = gold end
			bar.vipGlow.Enabled, bar.vipGlow.Color = true, gold
		elseif vip then
			local t = os.clock()
			bar.nameRainbow.Offset = Vector2.new((t * 0.5) % 2 - 1, 0)
			bar.player.TextColor3 = WHITE
			local hue = Color3.fromHSV((t * 0.25) % 1, 0.8, 1)
			if not fatal then bar.portraitStroke.Color = hue end
			bar.vipGlow.Enabled, bar.vipGlow.Color = true, hue
		else
			bar.player.TextColor3 = bar.energy
		end
		bar.guard.Size = UDim2.fromScale(math.clamp(view.guard / self.config.MaxGuard, 0, 1), 1)
		bar.player.Text = (if localSlot == slot then "YOU · " else "") .. view.player .. " · " .. kit.Role
		if view.team and #view.team > 1 then
			-- Relay team: who is out (X), who fights (●), who waits (○).
			local marks = {}
			for i in view.team do
				marks[i] = if i < (view.teamIndex or 1) then "X" elseif i == view.teamIndex then "●" else "○"
			end
			bar.player.Text ..= "  ·  TEAM " .. table.concat(marks, "")
		end
		-- Passive gauge: ready or the seconds left (VOILE D'OMBRE, OMBRE INVERSÉE), the RAGE
		-- stacks, the ROI DES RUINES bonus (from health), PRÉCISION's rule.
		local passive = kit.Passive
		-- TARO in ESQUIVE: his slips (●●●) take the passive's place.
		local stance = kit.Stances and view.stance and kit.Stances[view.stance]
		local weave = stance and stance.Weave
		if weave and weave.Charges then
			passive = { Type = "Evade", Name = "DODGES", Charges = weave.Charges }
		end
		-- ZEPHYR's Sparks (✦) and KAI's RESOLVE take the passive's place.
		if not passive and kit.Rhythm then passive = { Type = "Rhythm", Name = "RHYTHM", Max = kit.Rhythm.Max } end
		if not passive and kit.Resolve then passive = { Type = "Resolve", Name = "RESOLVE" } end
		bar.passive.Visible = passive ~= nil
		if passive and view.passiveLabel then
			-- The third sheet's passives: the simulation writes their line (Sim.passiveLabel).
			bar.passive.Text = view.passiveLabel
			bar.passive.TextTransparency = if view.passiveOn then 0 else 0.45
		elseif passive then
			local gauge = view.passive or 0
			local label, ready
			if passive.Type == "Rage" then
				label, ready = passive.Name .. " ×" .. gauge, gauge > 0
				if gauge > 0 then label ..= " (+" .. math.floor(gauge * passive.PerStack * 100 + 0.5) .. " %)" end
			elseif passive.Type == "Ruins" then
				local bonus = math.floor(passive.MaxBonus * math.clamp((passive.From - ratio) / (passive.From - passive.To), 0, 1) * 100 + 0.5)
				label, ready = passive.Name .. " +" .. bonus .. " %", bonus > 0
			elseif passive.Type == "Tip" then
				label, ready = passive.Name .. ": BLADE TIP +" .. math.floor(passive.Bonus * 100 + 0.5) .. " %", true
			elseif passive.Type == "Evade" then
				-- The evades ready (●) and the seconds before the next one; AKEMI's FLOW armed.
				local charges, most = view.passiveCharges or 0, passive.Charges or 1
				label = passive.Name .. " " .. string.rep("●", charges) .. string.rep("○", most - charges)
					.. (if charges < most then " " .. math.ceil(gauge / 60) .. " s" else "")
					.. (if view.flow == "armed" then " · FLOW" else "")
				ready = charges > 0 or view.flow == "armed"
			elseif passive.Type == "Rhythm" then
				local sparks = view.sparks or 0
				label, ready = passive.Name .. " " .. string.rep("✦", sparks) .. string.rep("·", passive.Max - sparks), sparks > 0
			elseif passive.Type == "Resolve" then
				label, ready = passive.Name .. " · FEINT", true
			else
				label = if gauge <= 0 then passive.Name .. " ✓" else passive.Name .. " " .. math.ceil(gauge / 60) .. " s"
				ready = gauge <= 0
			end
			bar.passive.Text = label
			bar.passive.TextTransparency = if ready then 0 else 0.45
		end
		-- One pip per round to win (best of 3), or per opposing fighter in a relay team (3v3:
		-- three, the match can go to five rounds).
		local other = views[3 - slot]
		local need = if other.team then #other.team else self.config.RoundsToWin
		for i, pip in bar.pips do
			pip.Visible = i <= need
			pip.BackgroundColor3 = if view.wins >= i then bar.energy else INK
		end
		local bars = self.config.MeterBar
		for i, segment in bar.segments do
			segment.Size = UDim2.fromScale(math.clamp((view.meter - (i - 1) * bars) / bars, 0, 1), 1)
		end
		bar.kiCount.Text = tostring(math.floor(view.meter / bars))
		-- (a full ki bar glows, softly beating)
		for i, edge in bar.segmentEdges do
			local full = view.meter >= i * bars
			edge.Thickness = if full then 1.5 else 1
			edge.Transparency = if full then 0.2 + 0.3 * (0.5 + 0.5 * math.sin(os.clock() * 4 + i)) else 0.5
		end
		local u = kit.Ultimates
		local ready = view.meter >= MoveData.Moves[u.Rush].meterCost
		bar.ready.Visible = ready
		bar.ready.Text = if view.meter >= MoveData.Moves[u.Awaken].meterCost then "3 BARS · AWAKENING / " .. kit.GateTitle.text
			else "ULTIMATE READY · R"
		-- COUP FATAL (last breath, once per match): announced above everything else.
		if view.fatal == "ready" then
			bar.ready.Visible = true
			bar.ready.Text = "FATAL BLOW READY · C — " .. moveName(kit, "Fatal")
			bar.ready.TextTransparency = 0.1 * (1 + math.sin(os.clock() * 12))
		elseif ready then bar.ready.TextTransparency = 0.25 + 0.25 * math.sin(os.clock() * 8) end
	end
	for _, c in self.combo do
		if c.frame.Visible and os.clock() > c.expires then c.frame.Visible = false end
	end
	local timerText = if world.timer < 0 then "∞" else tostring(world.timer)
	if timerText ~= self.timer.Text and world.timer >= 0 and world.timer <= 10 and world.phase == "Fight" then
		self.timerScale.Scale = 1.25
		tween(self.timerScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	self.timer.Text = timerText
	self.timer.TextColor3 = if world.timer >= 0 and world.timer <= 10 then Color3.fromHex("FF4A5A") else WHITE
	self.round.Text = if world.training then "TRAINING"
		elseif world.mode == "SURVIVAL" then "SURVIVAL · WAVE " .. (world.wave or 1)
		else "ROUND " .. world.round
	-- Training tools only in ENTRAÎNEMENT (the server ignores them elsewhere anyway).
	local solo = world.solo and (world.mode == nil or world.mode == "TRAINING")
	self.labButton.Visible = solo and localSlot > 0
	self.ultiButton.Visible = solo and localSlot > 0
	self.ultiButton.Text = if world.ultimateConditions then "ULTIMATES: ON (full ki, 25 % health)" else "ULTIMATES: OFF"
	self.ultiButton.TextColor3 = if world.ultimateConditions then Color3.fromHex("FFD23F") else WHITE
	if not self.labButton.Visible then self.labPanel.Visible = false end
	local mine = views[localSlot]
	local myKit = self:kitData()
	-- (the combo trainer: solo only, the server sends its fields only there)
	self.routeButton.Visible = world.solo == true and localSlot > 0
	if not world.solo then self.trainerPanel.Visible = false end
	self:updateTrainer(if world.solo then mine else nil, mine ~= nil and mine.meter >= MoveData.Moves[myKit.Ultimates.Awaken].meterCost)
	self.resetButton.Visible = solo and localSlot > 0
	self.dummyButton.Visible = solo and localSlot > 0
	self.dummyButton.Text = "DUMMY: " .. world.dummyMode .. " (M)"
	self.avatarButton.Visible = localSlot > 0
	self.skinButton.Visible = localSlot > 0
	self.kitButton.Visible = solo and localSlot > 0
	self.foeKitButton.Visible = solo and localSlot > 0
	self.trainingHeading.Visible = solo and localSlot > 0
	self.fighterHeading.Visible = localSlot > 0
	local stances = mine and MoveData.Kits[mine.kit] and MoveData.Kits[mine.kit].Stances
	for rank, b in self.stanceButtons do
		b.Visible = stances ~= nil and localSlot > 0
		local active = stances and mine.stance == stances.Order[rank]
		b.BackgroundColor3 = if active then Color3.fromHex("5A1A10") else INK
		b.TextColor3 = if active then Color3.fromHex("FFD23F") else WHITE
	end
	if localSlot > 0 then
		self.skinButton.Text = "STYLE: " .. (CharacterData[localSlot].Title or CharacterData[localSlot].Skin)
		self.kitButton.Text = "FIGHTER: " .. CharacterData[localSlot].Kit .. " (T)"
		self.foeKitButton.Text = "OPPONENT: " .. CharacterData[3 - localSlot].Kit .. " (G)"
	end
	local player = Players.LocalPlayer
	self.avatarButton.Text = if player:GetAttribute("Avatar") then "LOOK: AVATAR" else "LOOK: MODEL"
	-- Avatar loading feedback: the reason is shown when the avatar could not be used.
	local avatarStatus = player:GetAttribute("AvatarStatus")
	local kind, reason = string.match(tostring(avatarStatus or ""), "^([^|]*)|?(.*)$")
	local note = ""
	if kind == "MODEL" then
		note = " · avatar failed, block model (" .. reason .. ")"
	elseif player:GetAttribute("Avatar") and kind and kind ~= "" then
		note = if kind == "LOADING" then " · AVATAR: loading…"
			elseif kind == "OK" then " · AVATAR " .. rig .. " + KIT " .. CharacterData[math.max(localSlot, 1)].Kit
			elseif kind == "NO ACCESSORIES" then " · AVATAR without accessories (" .. reason .. ")"
			else " · avatar unavailable, default body (" .. reason .. ")"
	end
	if avatarStatus ~= self.lastAvatarStatus then
		self.lastAvatarStatus = avatarStatus
		if kind == "DEFAULT" or kind == "MODEL" then
			self:announceText("AVATAR UNAVAILABLE", "Body " .. rig .. " by default with the kit · " .. reason, GOLD)
		end
	end
	-- Ping of each player in the fight (round trip measured by the server).
	local pings = {}
	for slot = 1, 2 do
		local v = views[slot]
		if v and v.ping then table.insert(pings, (if slot == localSlot then "YOU " else "OPP. ") .. v.ping .. " ms") end
	end
	-- (the technical line: in training, or with TOOLS open; out of the way in a real fight)
	self.status.Visible = world.training == true or (self.tools ~= nil and self.tools.Visible)
	self.status.Text = string.format("v%s · %s · %d FPS%s%s", self.config.Version,
		if localSlot == 0 then "SPECTATOR" elseif world.training then "TRAINING"
			elseif solo then "VS " .. world.dummyMode else "VERSUS", math.floor(fps + 0.5),
		if #pings > 0 then " · PING " .. table.concat(pings, " / ") else "", note)
end

return HUD
