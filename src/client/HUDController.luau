-- Manga-style combat HUD in the black / white / red palette of the KAI art direction sheet.
-- The local fighter's kit (MoveData.Kits) drives the combo list, the trainer and the lab.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterData = require(Shared.CharacterData)
local MoveData = require(Shared.MoveData)

local HUD = {}

local WHITE = Color3.fromHex("F5F5F7")
local INK = Color3.fromHex("0B0B0E")
local RED = Color3.fromHex("E0102B")
local DISPLAY = Enum.Font.Bangers
local UI_FONT = Enum.Font.GothamBlack

local function new(className, props, parent)
	local i = Instance.new(className)
	for k, v in props do i[k] = v end
	i.Parent = parent
	return i
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

local function tween(instance, duration, goal, style, direction)
	local t = TweenService:Create(instance, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

function HUD.new(config)
	local self = setmetatable({ config = config, poseRate = config.PoseRate, bars = {}, trail = { 1, 1 }, combo = {} }, { __index = HUD })
	local gui = new("ScreenGui", { Name = "CombatHUD", ResetOnSpawn = false, DisplayOrder = 5, IgnoreGuiInset = false },
		Players.LocalPlayer:WaitForChild("PlayerGui"))
	self.gui = gui

	-- Top header: portraits, health, guard, round pips and timer.
	local header = new("Frame", { Name = "Header", BackgroundTransparency = 1, Size = UDim2.new(1, -24, 0, 104), Position = UDim2.fromOffset(12, 6) }, gui)
	for slot = 1, 2 do
		local data = CharacterData[slot]
		local energy = Color3.fromHex(data.Energy)
		local left = slot == 1
		local side = new("Frame", {
			Name = "Player" .. slot, BackgroundTransparency = 1,
			Size = UDim2.new(0.5, -52, 1, 0), Position = if left then UDim2.new() else UDim2.new(0.5, 52, 0, 0),
		}, header)
		-- Diamond portrait with the character's kanji.
		local portrait = new("Frame", {
			Name = "Portrait", Size = UDim2.fromOffset(54, 54), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45,
			Position = if left then UDim2.fromOffset(36, 40) else UDim2.new(1, -36, 0, 40),
			BackgroundColor3 = INK, BorderSizePixel = 0,
		}, side)
		tint(stroke(portrait, 3, energy), "Energy")
		local kanji = tint(text(portrait, { Text = data.Kanji, Rotation = -45, Size = UDim2.fromScale(1, 1), TextSize = 34, TextColor3 = energy, Font = UI_FONT }), "Energy")
		local barX = 76
		local bar = new("Frame", {
			Name = "Health", BackgroundColor3 = INK, BorderSizePixel = 0,
			Size = UDim2.new(1, -barX - 4, 0, 24), AnchorPoint = Vector2.new(if left then 0 else 1, 0),
			Position = if left then UDim2.fromOffset(barX, 30) else UDim2.new(1, -barX, 0, 30),
		}, side)
		stroke(bar, 2, WHITE)
		local trail = new("Frame", { Name = "Trail", BackgroundColor3 = RED, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
			AnchorPoint = Vector2.new(if left then 0 else 1, 0), Position = if left then UDim2.new() else UDim2.fromScale(1, 0) }, bar)
		local fill = new("Frame", { Name = "Fill", BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
			AnchorPoint = Vector2.new(if left then 0 else 1, 0), Position = if left then UDim2.new() else UDim2.fromScale(1, 0) }, bar)
		local gradient = new("UIGradient", {
			Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, WHITE), ColorSequenceKeypoint.new(0.75, WHITE), ColorSequenceKeypoint.new(1, energy) }),
			Rotation = if left then 0 else 180,
		}, fill)
		local guard = new("Frame", {
			Name = "Guard", BackgroundColor3 = INK, BorderSizePixel = 0,
			Size = UDim2.new(0.6, 0, 0, 6), AnchorPoint = Vector2.new(if left then 0 else 1, 0),
			Position = if left then UDim2.fromOffset(barX, 58) else UDim2.new(1, -barX, 0, 58),
		}, side)
		local guardFill = tint(new("Frame", { BackgroundColor3 = Color3.fromHex(data.Shield), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
			AnchorPoint = Vector2.new(if left then 0 else 1, 0), Position = if left then UDim2.new() else UDim2.fromScale(1, 0) }, guard), "Shield")
		-- Passive gauge (AKEMI's VOILE D'OMBRE), next to the guard bar.
		local passive = tint(text(side, {
			Name = "Passive", TextSize = 11, Font = UI_FONT, TextColor3 = energy, Visible = false,
			Size = UDim2.new(0.4, -barX - 12, 0, 12), AnchorPoint = Vector2.new(if left then 0 else 1, 0),
			Position = if left then UDim2.new(0.6, barX + 8, 0, 55) else UDim2.new(0.4, -barX - 8, 0, 55),
			TextXAlignment = if left then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
		}), "Energy")
		stroke(passive, 1.5)
		local name = text(side, {
			Name = "Name", Text = data.Name, TextSize = 26, Size = UDim2.new(0, 120, 0, 26),
			Position = if left then UDim2.fromOffset(barX, 2) else UDim2.new(1, -barX - 120, 0, 2),
			TextXAlignment = if left then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
		})
		stroke(name, 2)
		local player = tint(text(side, {
			Name = "PlayerName", TextSize = 12, Font = UI_FONT, TextColor3 = energy,
			Size = UDim2.new(1, -barX - 130, 0, 20), Position = if left then UDim2.fromOffset(barX + 64, 7) else UDim2.new(0, 0, 0, 7),
			TextXAlignment = if left then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}), "Energy")
		local pips = {}
		for i = 1, config.RoundsToWin do
			local pip = new("Frame", {
				Size = UDim2.fromOffset(12, 12), Rotation = 45, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = INK, BorderSizePixel = 0,
				Position = if left then UDim2.new(1, -12 - (i - 1) * 20, 0, 92) else UDim2.new(0, 12 + (i - 1) * 20, 0, 92),
			}, side)
			stroke(pip, 2, WHITE)
			pips[i] = pip
		end
		-- Ki meter: three bars, the count in big type, and a glow when the ultimate is ready.
		local meter = new("Frame", {
			Name = "Ki", BackgroundTransparency = 1, Size = UDim2.new(0.6, 0, 0, 12), AnchorPoint = Vector2.new(if left then 0 else 1, 0),
			Position = if left then UDim2.fromOffset(barX + 30, 70) else UDim2.new(1, -barX - 30, 0, 70),
		}, side)
		local segments = {}
		for i = 1, config.MaxMeter / config.MeterBar do
			local segment = new("Frame", {
				BackgroundColor3 = INK, BorderSizePixel = 0, Size = UDim2.new(1 / 3, -4, 1, 0),
				Position = if left then UDim2.new((i - 1) / 3, 0, 0, 0) else UDim2.new(1 - i / 3, 4, 0, 0),
			}, meter)
			tint(stroke(segment, 1.5, energy), "Energy").ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			local segmentFill = tint(new("Frame", { BackgroundColor3 = energy, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1),
				AnchorPoint = Vector2.new(if left then 0 else 1, 0), Position = if left then UDim2.new() else UDim2.fromScale(1, 0) }, segment), "Energy")
			segments[i] = segmentFill
		end
		local count = tint(text(side, {
			Name = "KiCount", Text = "0", TextSize = 30, TextColor3 = energy, Size = UDim2.fromOffset(26, 30),
			Position = if left then UDim2.fromOffset(barX, 62) else UDim2.new(1, -barX - 26, 0, 62),
		}), "Energy")
		stroke(count, 2.5)
		local ready = text(side, {
			Name = "UltimateReady", Text = "ULTIME PRÊT · R", TextSize = 14, Font = UI_FONT, TextColor3 = WHITE, Visible = false,
			Size = UDim2.fromOffset(150, 14), Position = if left then UDim2.fromOffset(barX + 30, 84) else UDim2.new(1, -barX - 180, 0, 84),
			TextXAlignment = if left then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
		})
		tint(stroke(ready, 2, energy), "Energy")
		self.bars[slot] = { fill = fill, trail = trail, guard = guardFill, player = player, pips = pips, energy = energy,
			segments = segments, kiCount = count, ready = ready, side = side, gradient = gradient, skin = data.Skin,
			kanji = kanji, name = name, passive = passive }
	end
	local timer = new("Frame", {
		Name = "Timer", Size = UDim2.fromOffset(62, 62), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10),
		BackgroundColor3 = INK, BorderSizePixel = 0, Rotation = 45,
	}, header)
	stroke(timer, 3, WHITE)
	self.timer = text(timer, { Rotation = -45, Size = UDim2.fromScale(1, 1), TextSize = 36, Text = "99" })
	self.round = text(header, { Size = UDim2.fromOffset(120, 18), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 84),
		TextSize = 14, Font = UI_FONT, Text = "ROUND 1" })
	stroke(self.round, 1.5)

	-- Combo counters, one per side (shown on the attacker's side).
	for slot = 1, 2 do
		local left = slot == 1
		local frame = new("Frame", {
			Name = "Combo" .. slot, BackgroundTransparency = 1, Size = UDim2.fromOffset(220, 130), Visible = false,
			AnchorPoint = Vector2.new(if left then 0 else 1, 0.5), Position = if left then UDim2.new(0, 18, 0.4, 0) else UDim2.new(1, -18, 0.4, 0),
		}, gui)
		local scale = new("UIScale", { Scale = 1 }, frame)
		local align = if left then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right
		local count = text(frame, { Size = UDim2.new(1, 0, 0, 74), TextSize = 78, TextXAlignment = align, TextColor3 = self.bars[slot].energy })
		stroke(count, 4)
		local hits = text(frame, { Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 68), TextSize = 30, Text = "HITS !", TextXAlignment = align })
		stroke(hits, 3)
		local detail = text(frame, { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 98), TextSize = 16, Font = UI_FONT, TextXAlignment = align })
		stroke(detail, 2)
		self.combo[slot] = { frame = frame, scale = scale, count = count, detail = detail, expires = 0 }
	end

	-- Announcer.
	local announce = text(gui, {
		Name = "Announcer", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(1, 0, 0, 120), TextSize = 110, Visible = false,
	})
	stroke(announce, 6)
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
	local x, y = 12, 134
	local function button(name, label, width, callback)
		if x + width > 660 then x, y = 12, y + 34 end -- wrap to a second row
		local b = new("TextButton", {
			Name = name, Text = label, Size = UDim2.fromOffset(width, 28), Position = UDim2.fromOffset(x, y),
			Font = UI_FONT, TextSize = 11, TextColor3 = WHITE, BackgroundColor3 = INK, AutoButtonColor = true,
		}, gui)
		stroke(b, 1.5, RED).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		b.Activated:Connect(callback)
		x += width + 8
		return b
	end
	-- Fighter pick first: the own kit (T) and, in solo, the CPU's (G).
	self.kitButton = button("Kit", "PERSO : KAI (T)", 156, function()
		if self.onKit then self.onKit() end
	end)
	self.foeKitButton = button("FoeKit", "ADVERSAIRE : KAI (G)", 176, function()
		if self.onFoeKit then self.onFoeKit() end
	end)
	self.avatarButton = button("Avatar", "APPARENCE : AVATAR", 176, function()
		if self.onAvatar then self.onAvatar() end
	end)
	self.skinButton = button("Skin", "STYLE : CLASSIQUE", 140, function()
		if self.onSkin then self.onSkin() end
	end)
	self.dummyButton = button("Dummy", "MANNEQUIN (M)", 170, function()
		if self.onDummy then self.onDummy() end
	end)
	self.resetButton = button("Reset", "REPLACER", 84, function()
		if self.onReset then self.onReset() end
	end)
	-- TARO only: his two boxing styles (keys 1 / & and 2 / é).
	self.stanceButtons = {
		button("Stance1", "1 · CLASSIQUE (&)", 136, function()
			if self.onStance then self.onStance(1) end
		end),
		button("Stance2", "2 · ESQUIVE (é)", 124, function()
			if self.onStance then self.onStance(2) end
		end),
	}
	self.combosButton = button("Combos", "COMBOS", 76, function()
		self.combosPanel.Visible = not self.combosPanel.Visible
	end)
	-- Combo trainer: pick a full route, the bar at the bottom shows what to press and when.
	self.trainerRoute = 0
	self.routeButton = button("Route", "ENTRAÎNEUR : OFF", 196, function()
		self.trainerRoute = (self.trainerRoute + 1) % (#self:trainerRoutes() + 1)
		self:refreshRouteButton()
		self:buildTrainer()
	end)
	self.labButton = button("Lab", "LABO CINÉ", 86, function()
		self.labPanel.Visible = not self.labPanel.Visible
	end)
	local poseButton
	local function poseLabel(rate)
		return if rate >= 60 then "POSES : FLUIDE" else "POSES : " .. rate .. "/s"
	end
	poseButton = button("PoseRate", poseLabel(self.poseRate), 108, function()
		local rates = { 12, 15, 24, 60 }
		local current = table.find(rates, self.poseRate) or 1
		self.poseRate = rates[current % #rates + 1]
		poseButton.Text = poseLabel(self.poseRate)
	end)
	self.effectsButton = button("Effects", "EFFETS : FORTS", 118, function()
		if self.onEffects then self.effectsButton.Text = if self.onEffects() then "EFFETS : RÉDUITS" else "EFFETS : FORTS" end
	end)
	self.soundButton = button("Sound", "SON : OUI", 84, function()
		if self.onSound then self.soundButton.Text = if self.onSound() then "SON : OUI" else "SON : NON" end
	end)
	self.debugButton = button("Hitboxes", "HITBOX : NON", 104, function()
		if self.onDebug then self.debugButton.Text = if self.onDebug() then "HITBOX : OUI" else "HITBOX : NON" end
	end)
	local panelY = y + 40 -- panels open below the last row of buttons
	local trainer = new("Frame", {
		Name = "ComboTrainer", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40),
		Size = UDim2.fromOffset(6 * 92, 140), BackgroundTransparency = 1, Visible = false,
	}, gui)
	self.trainer = trainer
	self.trainerNow = text(trainer, { Text = "MAINTENANT !", TextSize = 40, TextColor3 = Color3.fromHex("FFD23F"),
		Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 0), Visible = false })
	stroke(self.trainerNow, 3)
	self.trainerStatus = text(trainer, { TextSize = 15, Font = UI_FONT, Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 120) })
	stroke(self.trainerStatus, 2)
	self.trainerBoxes = {}

	-- Combo routes panel and training lab, filled for the local kit (see HUD:setKit).
	local function panel(name, width, position)
		local frame = new("Frame", {
			Name = name, Visible = false, BackgroundColor3 = INK, BackgroundTransparency = 0.1, BorderSizePixel = 0,
			Size = UDim2.fromOffset(width, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = position,
		}, gui)
		stroke(frame, 2, RED).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, frame)
		new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, frame)
		return frame
	end
	self.combosPanel = panel("CombosPanel", 380, UDim2.fromOffset(12, panelY))
	self.labPanel = panel("LabPanel", 300, UDim2.new(1, -312, 0, panelY))
	self:setKit("KAI")

	self.help = text(gui, { Name = "Help", Size = UDim2.new(1, -24, 0, 22), Position = UDim2.new(0, 12, 1, -30), TextSize = 13,
		Font = UI_FONT, TextColor3 = Color3.fromHex("D6D6DC") })
	stroke(self.help, 1.5)
	local function updateHelp()
		local gamepad = UIS.PreferredInput == Enum.PreferredInput.Gamepad
		self.help.Visible = not UIS.TouchEnabled
		self.help.Text = if gamepad
			then "STICK : bouger · A : saut · X : coup · B : lourd · Y : spéciale · LT : ultime · RB : garde · RT : dash · SELECT : replacer"
			else "Q/A · D : bouger · ESPACE : saut · S : bas · CLIC G : coup · CLIC D : lourd · E : spéciale · R : ultime · F : garde · SHIFT : dash · T : perso · G : perso CPU"
	end
	UIS:GetPropertyChangedSignal("PreferredInput"):Connect(updateHelp)
	updateHelp()
	return self
end

local KEY_LABEL = { L = "CLIC G", R = "CLIC D", U = "R", E = "E", C = "C" }
local GREY = Color3.fromHex("B9B9C2")
local GOLD = Color3.fromHex("FFD23F")
local ORANGE = Color3.fromHex("FFB938")
local ULTIMATE = Color3.fromHex("FF2A3D")

-- Why a route stopped being clean (CombatSimulation sets dirtyReason).
local DIRTY = {
	["TROP TÔT"] = "TROP TÔT : appuie quand le coup d'avant sort ou touche, pas avant",
	SPAM = "SPAM : plusieurs boutons à la fois ou trop d'appuis d'avance",
	["MAUVAIS BOUTON"] = "MAUVAIS BOUTON : ce n'est pas la suite de la route",
	["APPUI PERDU"] = "APPUI PERDU : tapé trop tôt, l'appui a expiré",
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
	self:fillCombos()
	self:fillLab()
	if not first then
		local kit = self:kitData()
		self:announceText(kit.Name .. " " .. kit.Kanji, kit.Role .. " · " .. kit.Description, GOLD)
	end
end

-- Every combo the trainer can follow: the skill routes (★), the full routes, the short
-- routes, then the special, the ultimate and the COUP FATAL cancelled from two hits. Routes
-- with a jump (↑) are left out: the trainer follows presses, not jumps.
function HUD:trainerRoutes()
	local kit = self:kitData()
	if self.trainerCache and self.trainerCache.kit == kit then return self.trainerCache.list end
	local list = {}
	for _, route in kit.Routes do
		if route.name:find("★") and not route.keys:find("↑") then table.insert(list, route) end
	end
	for _, route in kit.FullRoutes do
		table.insert(list, { name = route.name, keys = route.keys, moves = route.moves, full = true })
	end
	for _, route in kit.Routes do
		if not route.name:find("★") and not route.keys:find("↑") then table.insert(list, route) end
	end
	local starters = kit.Starters.Ground
	local jab = kit.Roles.Jab or "Jab"
	local cross = MoveData.Moves[jab].cancels and MoveData.Moves[jab].cancels.Light or kit.Roles.Cross
	table.insert(list, { name = "SPÉCIALE", keys = "L L E", moves = { jab, cross, kit.Roles.Rising or starters.Special } })
	table.insert(list, { name = "ULTIME", keys = "L L U", moves = { jab, cross, kit.Ultimates.Rush } })
	table.insert(list, { name = "COUP FATAL (vie < 30 %, 3 barres)", keys = "L L C", moves = { jab, cross, kit.Ultimates.Fatal } })
	self.trainerCache = { kit = kit, list = list }
	return list
end

function HUD:refreshRouteButton()
	local route = self:trainerRoutes()[self.trainerRoute]
	self.routeButton.Text = if route then "ENTRAÎNEUR : " .. route.name .. " (" .. route.keys .. ")" else "ENTRAÎNEUR : OFF"
end

local function clearContent(panel)
	for _, child in panel:GetChildren() do
		if child:IsA("TextLabel") or child:IsA("TextButton") then child:Destroy() end
	end
end

-- Combo routes of the kit, its ultimates, specials and passive.
function HUD:fillCombos()
	local panel = self.combosPanel
	clearContent(panel)
	local kit = self:kitData()
	local u = kit.Ultimates
	local lines = {
		{ kit.Name .. " " .. kit.Kanji .. " · " .. kit.Role, RED },
		{ kit.Description, GREY },
		{ "COMBOS  ·  L = clic gauche, R = clic droit", RED },
	}
	for _, route in kit.Routes do
		local names = {}
		for _, id in route.moves do table.insert(names, MoveData.Moves[id].name) end
		table.insert(lines, { route.keys .. "  →  " .. table.concat(names, " > "), WHITE })
	end
	table.insert(lines, { "ROUTES COMPLÈTES (6 appuis, fin : " .. moveName(kit, "KiChase") .. " > " .. moveName(kit, "Finale") .. ")", RED })
	for _, route in kit.FullRoutes do
		table.insert(lines, { route.keys .. "  →  " .. route.name, WHITE })
	end
	table.insert(lines, { "RYTHME : chaque appui APRÈS la sortie du coup d'avant. Tapé trop tôt, le combo continue mais n'est plus PROPRE (pas d'ultime). Garde, saut ou dash annulent les coups en attente.", GOLD })
	table.insert(lines, { "3 ULTIMES (route PROPRE seulement)", GOLD })
	table.insert(lines, { "1. R seul (2 barres) : " .. moveName(kit, u.Rush), ULTIMATE })
	table.insert(lines, { "2. Route complète, 6e = CLIC D (3 barres) : " .. moveName(kit, u.Awaken) .. ", finale selon la route", ULTIMATE })
	table.insert(lines, { "   jusqu'à −35 % de la vie max : chaque QTE raté pendant la rafale en retire ; FINAL FINISH s'il achève", ULTIMATE })
	table.insert(lines, { "3. Route complète, 6e = touche R (3 barres) : " .. kit.GateTitle.text .. " " .. kit.GateTitle.sub .. " (R au sommet : +10 % ; raté : −15 %)", ULTIMATE })
	table.insert(lines, { "COUP FATAL · touche C (manette L1) : " .. moveName(kit, "Fatal") .. " — 3 barres, ta vie sous 30 %, une fois par match", ULTIMATE })
	table.insert(lines, { "   en plein combo : −95 % de la vie max ; à froid : −60 % ; QTE raté : −40 % du coup ; paré ou esquivé : perdu", ULTIMATE })
	table.insert(lines, { "↓ + L : " .. moveName(kit, "LowKick") .. " (garde basse)  ·  ↓ + R : " .. moveName(kit, "Uppercut") .. " (lanceur)", WHITE })
	table.insert(lines, { "Après le lanceur : ESPACE puis L L R en l'air", WHITE })
	table.insert(lines, { "E après un coup : " .. moveName(kit, "Rising") .. " (invincible au départ)", ORANGE })
	if kit.Stances then
		-- TARO: two styles, switched in neutral (keys 1 / & and 2 / é, or the HUD buttons).
		for rank, id in kit.Stances.Order do
			local stance = kit.Stances[id]
			local special = MoveData.Moves[stance.CrouchSpecial]
			local guard = math.floor((1 - (stance.Stats.GuardDamageTaken or 1)) * 100 + 0.5)
			local power = math.floor(((stance.Stats.DamageDealt or 1) - 1) * 100 + 0.5)
			table.insert(lines, { string.format("%d / %s : %s · dégâts %+d %% · garde %s%s · ↓ + E : %s", rank, stance.Key, stance.Name,
				power, if guard > 0 then "-" .. guard .. " % d'usure" else "normale", "", special and special.name or "?"), ORANGE })
			if stance.Weave then
				table.insert(lines, { "   DASH VERS L'ADVERSAIRE = ESQUIVE DE BUSTE (coups hauts esquivés, + ki) · pendant / juste après : L = DEMPSEY ROLL (L encore jusqu'à "
					.. stance.Weave.MaxHooks .. ") · R = CROCHET FINAL · ↓ + E = PARADE qui contre", ORANGE })
			else
				table.insert(lines, { "   garde de fer, frappe plus lourde · ↓ + E = DROITE DU CHAMPION (lente, écrase la garde, met au sol)", ORANGE })
			end
		end
	else
		local crouchSpecial = kit.Starters.Crouch.Special
		local special = MoveData.Moves[crouchSpecial]
		if special and special.parry and special.parry.lows then
			table.insert(lines, { "↓ + E : " .. special.name .. " (encaisse n'importe quel coup, même bas, en ne prenant que "
				.. math.floor((special.parry.absorb or 0) * 100 + 0.5) .. " % des dégâts, puis riposte ; perd contre les ultimes)", ORANGE })
		elseif special and special.parry then
			table.insert(lines, { "↓ + E : " .. special.name .. " (contre les coups debout et les projectiles ; perd contre les coups bas et les ultimes)", ORANGE })
		elseif special and special.projectile and special.projectile.guard == "Low" then
			table.insert(lines, { "↓ + E : " .. moveName(kit, crouchSpecial) .. " (onde au ras du sol : à garder accroupi, 1 à la fois)", ORANGE })
		else
			table.insert(lines, { "↓ + E : " .. moveName(kit, crouchSpecial) .. " (projectile, 1 à la fois)", ORANGE })
		end
	end
	local passive = kit.Passive
	if passive and passive.Type == "Evade" then
		table.insert(lines, { "PASSIF " .. passive.Name .. " : au neutre (sans attaquer, sans être touché, sans garder), le 1er coup reçu est esquivé (recul), recharge "
			.. math.floor(passive.Cooldown / 60) .. " s. Jamais contre les ultimes.", ORANGE })
	elseif passive and passive.Type == "Rage" then
		table.insert(lines, { "PASSIF " .. passive.Name .. " : chaque coup porté (pas en garde) ajoute +" .. passive.PerStack * 100 .. " % de dégâts (jusqu'à "
			.. passive.Max .. "), tout est perdu dès qu'il est touché.", ORANGE })
	elseif passive and passive.Type == "Tip" then
		table.insert(lines, { "PASSIF " .. passive.Name .. " : un coup du bout de la lame (adversaire au bout de l'allonge) fait +"
			.. math.floor(passive.Bonus * 100 + 0.5) .. " % de dégâts.", ORANGE })
	elseif passive and passive.Type == "Blink" then
		table.insert(lines, { "PASSIF " .. passive.Name .. " : SHIFT vers l'adversaire (à moins de " .. passive.Range
			.. " m) le traverse et réapparaît derrière lui, intouchable un instant ; recharge " .. string.format("%.1f", passive.Cooldown / 60) .. " s.", ORANGE })
	elseif passive and passive.Type == "Ruins" then
		table.insert(lines, { "PASSIF " .. passive.Name .. " : plus il est blessé, plus il frappe fort (jusqu'à +"
			.. math.floor(passive.MaxBonus * 100 + 0.5) .. " % à " .. math.floor(passive.To * 100 + 0.5) .. " % de vie).", ORANGE })
	end
	if kit.Stats.DashInvuln then
		table.insert(lines, { "DASH : intouchable pendant " .. kit.Stats.DashInvuln .. " images au départ", ORANGE })
	end
	table.insert(lines, { "VIE " .. kit.Stats.MaxHealth .. " · ★ = skill : alterne clic gauche / clic droit", GREY })
	table.insert(lines, { "1 seul effondrement, rebond sol et rebond mur par combo", GREY })
	table.insert(lines, { "T : changer de perso · G : perso du CPU (solo)", GREY })
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
		local keyLabel = text(frame, { Text = KEY_LABEL[key] or key, TextSize = 24, Size = UDim2.new(1, 0, 0, 36) })
		local m = MoveData.Moves[route.moves[i]]
		local moveLabel = text(frame, { Text = if m then m.name else route.moves[i], TextSize = 10, Font = UI_FONT,
			Size = UDim2.new(1, -4, 0, 30), Position = UDim2.fromOffset(2, 36), TextWrapped = true,
			TextColor3 = GREY })
		self.trainerBoxes[i] = { frame = frame, outline = outline, key = key, keyLabel = keyLabel, moveLabel = moveLabel }
	end
end

-- Training lab: buttons that play each cinematic of the kit directly (solo only).
function HUD:fillLab()
	local panel = self.labPanel
	clearContent(panel)
	local kit = self:kitData()
	text(panel, { Text = "LABO CINÉ · " .. kit.Name, TextSize = 22, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 0,
		TextXAlignment = Enum.TextXAlignment.Left })
	text(panel, { Text = "Lance une cinématique sans faire le combo (solo). Active HITBOX pour voir le nom du plan.",
		TextSize = 11, Font = UI_FONT, Size = UDim2.new(1, 0, 0, 30), TextWrapped = true, LayoutOrder = 1,
		TextColor3 = GREY, TextXAlignment = Enum.TextXAlignment.Left })
	local order = 2
	local function add(label, callback)
		local b = new("TextButton", {
			Text = label, Size = UDim2.new(1, 0, 0, 26), Font = UI_FONT, TextSize = 12, TextColor3 = WHITE,
			BackgroundColor3 = Color3.fromHex("1C1C24"), AutoButtonColor = true, LayoutOrder = order,
		}, panel)
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
	add("2 · ÉVEIL · FINAL FINISH (cible < 50 %)", play("Awaken", kit.FullRoutes[1].name, true))
	add("3 · " .. kit.GateTitle.sub, play("Gate", nil, false))
	add("3 · " .. kit.GateTitle.sub .. " · K.O. (cible faible)", play("Gate", nil, true))
	add("4 · COUP FATAL · " .. moveName(kit, "Fatal") .. " (en combo)", play("Fatal", nil, false))
	add("4 · COUP FATAL · K.O. (son écran de K.O.)", play("Fatal", nil, true))
	add("4 · COUP FATAL · à froid", play("Fatal", "raw", false))
	add("SCÈNE DE K.O. (aperçu seul)", function()
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
		if keys:sub(1, #typed) == typed then
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
			box.keyLabel.Text = if meterFull then "CLIC D / R" else "CLIC D"
			box.moveLabel.Text = if meterFull then "ÉVEIL (clic D) · " .. kit.GateTitle.text .. " (R)" else moveName(kit, "Finale")
		end
	end
	self.trainerNow.Visible = view.cancelReady == true and progress >= 1 and progress < n and not failed
	local reason = DIRTY[view.dirtyReason or ""] or "pas PROPRE : mauvais bouton, appui trop tôt ou en trop"
	if failed then
		self.trainerStatus.Text = "RATÉ : il fallait " .. (KEY_LABEL[keys:sub(progress + 1, progress + 1)] or "?")
			.. " — recommence au 1er coup"
		self.trainerStatus.TextColor3 = RED
	elseif progress >= n then
		self.trainerStatus.Text = if not route.full then "COMBO RÉUSSI ✓"
			elseif view.chainClean then "ROUTE RÉUSSIE · PROPRE ✓" else "ROUTE RÉUSSIE · " .. reason .. " : pas d'ultime"
		self.trainerStatus.TextColor3 = Color3.fromHex("3DDC84")
	elseif progress >= 1 then
		self.trainerStatus.Text = (if view.chainClean then "PROPRE ✓ · appuie quand le coup sort (case jaune)" else reason)
			.. "  ·  ki " .. (if meterFull then "3 barres ✓" else "< 3 barres")
		self.trainerStatus.TextColor3 = if view.chainClean then WHITE else ORANGE
	else
		self.trainerStatus.Text = "Colle-toi au mannequin (mode IMMOBILE) et appuie sur " .. KEY_LABEL[keys:sub(1, 1)]
		self.trainerStatus.TextColor3 = GREY
	end
end

-- Recolours a side of the HUD after its fighter changed kit or style (CLASSIQUE, NUIT...).
function HUD:applyLook(slot)
	local bar = self.bars[slot]
	local data = CharacterData[slot]
	if not bar or bar.skin == data.Skin then return end
	bar.skin = data.Skin
	bar.kanji.Text, bar.name.Text = data.Kanji, data.Name
	local energy, shield = Color3.fromHex(data.Energy), Color3.fromHex(data.Shield)
	bar.energy = energy
	for _, item in bar.side:GetDescendants() do
		local kind = item:GetAttribute("Tint")
		local color = if kind == "Energy" then energy elseif kind == "Shield" then shield else nil
		if color then
			if item:IsA("UIStroke") then item.Color = color
			elseif item:IsA("TextLabel") then item.TextColor3 = color
			elseif item:IsA("GuiObject") then item.BackgroundColor3 = color end
		end
	end
	bar.gradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, WHITE), ColorSequenceKeypoint.new(0.75, WHITE), ColorSequenceKeypoint.new(1, energy) })
	self.callouts[slot].label.TextColor3 = energy
	self.combo[slot].count.TextColor3 = energy
end

function HUD:setEffectsReduced(reduced)
	self.effectsButton.Text = if reduced then "EFFETS : RÉDUITS" else "EFFETS : FORTS"
end

function HUD:announceText(main, sub, color)
	local a = self.announce
	a.Text, a.TextColor3, a.Visible, a.TextTransparency = main, color or WHITE, true, 0
	self.announceScale.Scale = 2.4
	tween(self.announceScale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	self.announceSub.Text, self.announceSub.Visible = sub or "", sub ~= nil
	self.announceId = (self.announceId or 0) + 1
	local id = self.announceId
	task.delay(1.3, function()
		if self.announceId ~= id then return end
		tween(a, 0.25, { TextTransparency = 1 })
		self.announceSub.Visible = false
		-- Hidden once faded: the text's UIStroke outline does not fade with it.
		task.delay(0.26, function()
			if self.announceId == id then a.Visible = false end
		end)
	end)
end

-- Rounds are announced from the snapshot phase so a client joining mid-intro still sees it.
function HUD:announceRound(round)
	self:announceText("ROUND " .. round, CharacterData[1].Name .. " " .. CharacterData[1].Skin .. "  VS  "
		.. CharacterData[2].Name .. " " .. CharacterData[2].Skin)
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
	if event.kind == "Hit" and event.tip then self:callout(event.attacker, "BOUT DE LAME !") end
	if event.kind == "Hit" and event.combo and event.combo >= 2 then
		local c = self.combo[event.attacker]
		c.frame.Visible = true
		c.count.Text = tostring(event.combo)
		local m = MoveData.Moves[event.move]
		c.detail.Text = (if m and m.heavy then m.name .. " · " else "") .. event.comboDamage .. " DÉGÂTS"
		c.scale.Scale = 1.5
		tween(c.scale, 0.15, { Scale = 1 }, Enum.EasingStyle.Back)
		c.expires = os.clock() + 1.4
	elseif event.kind == "Skill" then
		local m = MoveData.Moves[event.move]
		self:callout(event.attacker, (if m then m.name else event.move) .. " !")
	elseif event.kind == "Parry" then
		-- TARO's PARADE, HIBECARES's MUR DE PIERRE (the share of the blow it took).
		local label = if event.name then event.name .. " !" else "PARADE !"
		if event.absorbed then label ..= " −" .. event.absorbed end
		self:callout(event.defender, label)
	elseif event.kind == "Blink" and not event.move then
		local kit = MoveData.Kits[CharacterData[event.slot].Kit]
		self:callout(event.slot, (if kit and kit.Passive then kit.Passive.Name else "TÉLÉPORTATION") .. " !")
	elseif event.kind == "Evade" then
		local kit = MoveData.Kits[CharacterData[event.defender].Kit]
		self:callout(event.defender, (if kit and kit.Passive then kit.Passive.Name else "ESQUIVE") .. " !")
	elseif event.kind == "Slip" then
		self:callout(event.defender, "ESQUIVE !")
	elseif event.kind == "Stance" then
		self:callout(event.slot, (event.name or event.stance) .. " !")
		-- The local player: how the new style plays, in one line.
		if event.slot == (Players.LocalPlayer:GetAttribute("FighterSlot") or 0) then
			local hint = if event.stance == "ESQUIVE"
				then "SHIFT vers l'adversaire = ESQUIVE · puis clic gauche = DEMPSEY ROLL · S + E = PARADE"
				else "Garde de fer, coups plus lourds · S + E = DROITE DU CHAMPION"
			self:announceText(event.name or event.stance, hint, Color3.fromHex("FFB21A"))
		end
	elseif event.kind == "GuardBreak" then
		self:announceText("GUARD BREAK", nil, Color3.fromHex("FFD23F"))
	elseif event.kind == "Fight" then
		self:announceText("FIGHT !", nil, RED)
	elseif event.kind == "RoundEnd" then
		local main = if event.reason == "Timeout" then "TIME OVER" elseif event.winner == 0 then "DOUBLE K.O." else "K.O."
		local sub
		if not world.training then
			sub = if event.winner == 0 then "ÉGALITÉ" else CharacterData[event.winner].Name .. " " .. CharacterData[event.winner].Skin .. " GAGNE LE ROUND"
			if event.perfect then sub = "PERFECT ! " .. sub end
		end
		self:announceText(main, sub, if main == "K.O." then RED else WHITE)
	elseif event.kind == "MatchEnd" then
		local main = if event.winner == 0 then "MATCH NUL" else CharacterData[event.winner].Name .. " GAGNE !"
		self:announceText(main, "VICTOIRE", RED)
	end
end

-- Called every rendered frame with the latest authoritative snapshot.
function HUD:update(world, views, fps, dt)
	if not views[1] or not views[2] then return end
	local localSlot = Players.LocalPlayer:GetAttribute("FighterSlot") or 0
	for slot, view in views do
		local bar = self.bars[slot]
		local kit = MoveData.Kits[view.kit] or MoveData.Kits.KAI
		local ratio = math.clamp(view.hp / (view.maxHp or kit.Stats.MaxHealth), 0, 1)
		bar.fill.Size = UDim2.fromScale(ratio, 1)
		-- The red trail waits while the combo continues, then catches up.
		if view.combo == 0 or self.trail[slot] < ratio then
			self.trail[slot] = math.max(ratio, self.trail[slot] - dt * 0.6)
		end
		bar.trail.Size = UDim2.fromScale(self.trail[slot], 1)
		bar.guard.Size = UDim2.fromScale(math.clamp(view.guard / self.config.MaxGuard, 0, 1), 1)
		bar.player.Text = (if localSlot == slot then "VOUS · " else "") .. view.player .. " · " .. kit.Role
		-- Passive gauge: ready or the seconds left (VOILE D'OMBRE, OMBRE INVERSÉE), the RAGE
		-- stacks, the ROI DES RUINES bonus (from health), PRÉCISION's rule.
		local passive = kit.Passive
		bar.passive.Visible = passive ~= nil
		if passive then
			local gauge = view.passive or 0
			local label, ready
			if passive.Type == "Rage" then
				label, ready = passive.Name .. " ×" .. gauge, gauge > 0
				if gauge > 0 then label ..= " (+" .. math.floor(gauge * passive.PerStack * 100 + 0.5) .. " %)" end
			elseif passive.Type == "Ruins" then
				local bonus = math.floor(passive.MaxBonus * math.clamp((passive.From - ratio) / (passive.From - passive.To), 0, 1) * 100 + 0.5)
				label, ready = passive.Name .. " +" .. bonus .. " %", bonus > 0
			elseif passive.Type == "Tip" then
				label, ready = passive.Name .. " : BOUT DE LAME +" .. math.floor(passive.Bonus * 100 + 0.5) .. " %", true
			else
				label = if gauge <= 0 then passive.Name .. " ✓" else passive.Name .. " " .. math.ceil(gauge / 60) .. " s"
				ready = gauge <= 0
			end
			bar.passive.Text = label
			bar.passive.TextTransparency = if ready then 0 else 0.45
		end
		for i, pip in bar.pips do
			pip.BackgroundColor3 = if view.wins >= i then bar.energy else INK
		end
		local bars = self.config.MeterBar
		for i, segment in bar.segments do
			segment.Size = UDim2.fromScale(math.clamp((view.meter - (i - 1) * bars) / bars, 0, 1), 1)
		end
		bar.kiCount.Text = tostring(math.floor(view.meter / bars))
		local u = kit.Ultimates
		local ready = view.meter >= MoveData.Moves[u.Rush].meterCost
		bar.ready.Visible = ready
		bar.ready.Text = if view.meter >= MoveData.Moves[u.Awaken].meterCost then "3 BARRES · ÉVEIL / " .. kit.GateTitle.text
			else "ULTIME PRÊT · R"
		-- COUP FATAL (last breath, once per match): announced above everything else.
		if view.fatal == "ready" then
			bar.ready.Visible = true
			bar.ready.Text = "COUP FATAL PRÊT · C — " .. moveName(kit, "Fatal")
			bar.ready.TextTransparency = 0.1 * (1 + math.sin(os.clock() * 12))
		elseif ready then bar.ready.TextTransparency = 0.25 + 0.25 * math.sin(os.clock() * 8) end
	end
	for _, c in self.combo do
		if c.frame.Visible and os.clock() > c.expires then c.frame.Visible = false end
	end
	self.timer.Text = if world.timer < 0 then "∞" else tostring(world.timer)
	self.round.Text = if world.training then "ENTRAÎNEMENT" else "ROUND " .. world.round
	local solo = world.solo
	self.labButton.Visible = solo and localSlot > 0
	if not self.labButton.Visible then self.labPanel.Visible = false end
	local mine = views[localSlot]
	local myKit = self:kitData()
	self:updateTrainer(mine, mine ~= nil and mine.meter >= MoveData.Moves[myKit.Ultimates.Awaken].meterCost)
	self.resetButton.Visible = solo and localSlot > 0
	self.dummyButton.Visible = solo and localSlot > 0
	self.dummyButton.Text = "MANNEQUIN : " .. world.dummyMode .. " (M)"
	self.avatarButton.Visible = localSlot > 0
	self.skinButton.Visible = localSlot > 0
	self.kitButton.Visible = localSlot > 0
	self.foeKitButton.Visible = solo and localSlot > 0
	local stances = mine and MoveData.Kits[mine.kit] and MoveData.Kits[mine.kit].Stances
	for rank, b in self.stanceButtons do
		b.Visible = stances ~= nil and localSlot > 0
		local active = stances and mine.stance == stances.Order[rank]
		b.BackgroundColor3 = if active then Color3.fromHex("5A1A10") else INK
		b.TextColor3 = if active then Color3.fromHex("FFD23F") else WHITE
	end
	if localSlot > 0 then
		self.skinButton.Text = "STYLE : " .. CharacterData[localSlot].Skin
		self.kitButton.Text = "PERSO : " .. CharacterData[localSlot].Kit .. " (T)"
		self.foeKitButton.Text = "ADVERSAIRE : " .. CharacterData[3 - localSlot].Kit .. " (G)"
	end
	local player = Players.LocalPlayer
	local rig = player:GetAttribute("AvatarRig") or "R15"
	self.avatarButton.Text = if player:GetAttribute("Avatar") then "APPARENCE : AVATAR " .. rig else "APPARENCE : MODÈLE"
	-- Avatar loading feedback: the reason is shown when the avatar could not be used.
	local avatarStatus = player:GetAttribute("AvatarStatus")
	local kind, reason = string.match(tostring(avatarStatus or ""), "^([^|]*)|?(.*)$")
	local note = ""
	if kind == "MODÈLE" then
		note = " · avatar impossible, modèle en blocs (" .. reason .. ")"
	elseif player:GetAttribute("Avatar") and kind and kind ~= "" then
		note = if kind == "CHARGEMENT" then " · AVATAR : chargement…"
			elseif kind == "OK" then " · AVATAR " .. rig .. " + KIT " .. CharacterData[math.max(localSlot, 1)].Kit
			elseif kind == "SANS ACCESSOIRES" then " · AVATAR sans accessoires (" .. reason .. ")"
			else " · avatar indisponible, corps par défaut (" .. reason .. ")"
	end
	if avatarStatus ~= self.lastAvatarStatus then
		self.lastAvatarStatus = avatarStatus
		if kind == "DÉFAUT" or kind == "MODÈLE" then
			self:announceText("AVATAR INDISPONIBLE", "Corps " .. rig .. " par défaut avec le kit · " .. reason, GOLD)
		end
	end
	-- Ping of each player in the fight (round trip measured by the server).
	local pings = {}
	for slot = 1, 2 do
		local v = views[slot]
		if v and v.ping then table.insert(pings, (if slot == localSlot then "VOUS " else "ADV. ") .. v.ping .. " ms") end
	end
	self.status.Text = string.format("v%s · %s · %d FPS%s%s", self.config.Version,
		if localSlot == 0 then "SPECTATEUR" elseif world.training then "ENTRAÎNEMENT"
			elseif solo then "VS " .. world.dummyMode else "VERSUS", math.floor(fps + 0.5),
		if #pings > 0 then " · PING " .. table.concat(pings, " / ") else "", note)
end

return HUD
