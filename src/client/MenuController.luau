--[[
	Main menu (lobby), in the style of Wilhem's mock-up: top bar (logo, tabs, profile), big
	slanted buttons on the left, the favourite fighter in 3D in the middle (drawn by the
	client script: workspace.Fighters.Lobby_<id>), the mode cards on the right, NOUVEAUTÉS and
	MES PERSONNAGES at the bottom. No image asset: shapes, gradients, kanji and the 3D stage.

	Pages: ACCUEIL (cards), MODE SOLO and MODE EN LIGNE (sub-cards), the fighter select
	(1 to 3 fighters, CPU level, NORMAL / CLASSÉ / AMI), the opponent search, PERSONNAGES
	(gallery, favourite), CLASSEMENT (top 10 + own rank), PARAMÈTRES. The server checks and runs
	everything (see the server script); this only draws and sends requests.

	Keyboard: ÉCHAP-free on purpose (Roblox menu): RETOUR ARRIÈRE goes back; in the select,
	arrows choose, ENTRÉE takes a fighter, ESPACE starts. Mouse, touch and gamepad work too.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local MoveData = require(Shared.MoveData)
local CharacterData = require(Shared.CharacterData)
local GameModes = require(Shared.GameModes)
local Maps = require(Shared.Maps)
local FighterAI = require(Shared.FighterAI)
local AnimationController = require(script.Parent.AnimationController)
local CurrencyIcons = require(script.Parent.CurrencyIcons)
local Taunts = require(Shared.Taunts)
local Economy = require(Shared.Economy)
local Quests = require(Shared.Quests)
local Theme = require(script.Parent.MenuTheme)

local WHITE = Color3.fromHex("F5F5F7")
local INK = Color3.fromHex("08080B")
local PANEL = Color3.fromHex("121218")
local PANEL2 = Color3.fromHex("1B1B23")
local RED = Color3.fromHex("E0102B")
local DARKRED = Color3.fromHex("5A0712")
local GOLD = Color3.fromHex("FFD23F")
local GREY = Color3.fromHex("9A9AA6")
local BLUE = Color3.fromHex("2F6BFF")
local VIOLET = Color3.fromHex("8B3DFF")
local DISPLAY = Enum.Font.Bangers
local UI_FONT = Enum.Font.GothamBlack
local BODY_FONT = Enum.Font.GothamBold

local MenuController = {}
MenuController.__index = MenuController

-- Shared, restrained hover / press / gamepad feedback.
local juice = Theme.feedback
local function new(className, props, parent)
	local i = Instance.new(className)
	for k, v in props do i[k] = v end
	i.Parent = parent
	if className == "TextButton" then juice(i) end
	return i
end
local function stroke(gui, thickness, color, transparency)
	local s = new("UIStroke", { Thickness = thickness, Color = color or INK, Transparency = transparency or 0 }, gui)
	s.ApplyStrokeMode = if gui:IsA("TextLabel") then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border
	return s
end
local function corner(gui, radius)
	new("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, gui)
end
local function gradient(gui, from, to, rotation)
	return new("UIGradient", { Rotation = rotation or 0, Color = ColorSequence.new(from, to) }, gui)
end
local function label(parent, props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.BorderSizePixel = 0
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return new("TextLabel", props, parent)
end
local function kitColor(kit)
	local style = CharacterData.Skins[CharacterData.defaultStyle(kit, nil)]
	return Color3.fromHex(style and style.Energy or "E0102B")
end

local LEVEL_NAMES = {}
for i, level in FighterAI.Levels do LEVEL_NAMES[i] = level.name end
local QUEUES = { NORMAL = "NORMAL · no points", RANKED = "RANKED · points and rank", FRIEND = "FRIEND · challenge a player on the server" }
local NEWS = {
	{ tag = "NEW", title = "KUROEN · KAZAN'S CLAWS", color = RED, kanji = "蝕" },
	{ tag = "TEAMS", title = "1, 2 OR 3 FIGHTERS", color = VIOLET, kanji = "隊" },
	{ tag = "ONLINE", title = "RANKED MATCHES", color = GOLD, kanji = "位" },
	{ tag = "BOSS", title = "KUROEN SHIN", color = GOLD, kanji = "真" },
}

function MenuController.new(remote, hub, settings)
	local self = setmetatable({
		remote = remote, hub = hub, settings = settings or {}, status = {}, page = "home", kitIndex = 1,
		team = {}, teamSize = 1, level = 3, queue = "NORMAL", inMatch = false, searchStart = 0, ranking = nil,
	}, MenuController)
	local gui = new("ScreenGui", { Name = "MainMenu", ResetOnSpawn = false, DisplayOrder = 20, IgnoreGuiInset = false, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, Players.LocalPlayer:WaitForChild("PlayerGui"))
	self.gui = gui
	-- The backdrop under the menu covers the WHOLE screen, the band under Roblox's own buttons
	-- included (the menu itself stays out of it: its safe area): the top bar's black reaches the
	-- top edge instead of leaving a strip of the 3D stage above it.
	local backdrop = new("ScreenGui", { Name = "MainMenuBackdrop", ResetOnSpawn = false, DisplayOrder = 19, IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None }, Players.LocalPlayer:WaitForChild("PlayerGui"))
	self.backdrop = backdrop
	-- Vignette over the 3D stage: dark edges, red haze, the hero stays bright in the middle.
	local vignette = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = INK, BorderSizePixel = 0 }, backdrop)
	new("UIGradient", { Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.3, 0.55), NumberSequenceKeypoint.new(0.5, 0.92),
		NumberSequenceKeypoint.new(0.68, 0.55), NumberSequenceKeypoint.new(1, 0.05) }) }, vignette)
	local haze = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = DARKRED, BorderSizePixel = 0 }, backdrop)
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.6, 0.85), NumberSequenceKeypoint.new(1, 0.55) }) }, haze)
	-- Measure the usable GUI area, including Roblox and device insets.
	local safeCanvas = new("Frame", { Name = "SafeCanvas", Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3 }, gui)
	-- The design canvas scales to fit this safe area, including on camera replacement.
	-- (The top bar's black strip spans the whole width, even on wide screens.)
	local strip = new("Frame", { Size = UDim2.new(1, 0, 0, 78), BackgroundColor3 = INK, BackgroundTransparency = 0.15, BorderSizePixel = 0,
		ZIndex = 3 }, backdrop)
	local root = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1600, 900),
		BackgroundTransparency = 1, ZIndex = 3 }, safeCanvas)
	local scale = new("UIScale", {}, root)
	local function fit()
		local size = safeCanvas.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then return end
		scale.Scale = math.min(size.X / 1600, size.Y / 900)
		-- The canvas fills the whole screen (it was a centred 1600 x 900 box, leaving empty
		-- bands on any other shape of screen): at least 1600 x 900 design units, stretched to
		-- the screen's proportions. Everything is anchored to its edge (navigation on the left,
		-- pages and fighters on the right, panels at the bottom), so it spreads with it.
		root.Size = UDim2.fromOffset(math.max(1600, size.X / scale.Scale), math.max(900, size.Y / scale.Scale))
		-- (from the very top of the screen down to the bar's bottom edge: the safe area starts
		-- below Roblox's buttons, safeCanvas.AbsolutePosition + the top inset)
		local top = GuiService:GetGuiInset().Y + safeCanvas.AbsolutePosition.Y
		strip.Position = UDim2.fromOffset(0, 0)
		strip.Size = UDim2.new(1, 0, 0, top + 78 * scale.Scale)
	end
	fit()
	safeCanvas:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	safeCanvas:GetPropertyChangedSignal("AbsolutePosition"):Connect(fit)
	self.root = root
	self.bigKanji = label(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(0.3, 0.55),
		Font = Enum.Font.GothamBlack, TextScaled = true, Text = "開", TextColor3 = RED, TextTransparency = 0.88,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 2 })
	self:buildTopBar()
	self:buildNav()
	-- Pages (right / middle area).
	self.pages = {}
	self.pages.home = self:buildHome()
	self.pages.solo = self:buildSubCards("SOLO MODE", {
		{ id = "VERSUS_CPU", title = "1 VS 1 · CPU", lines = { "You against the CPU", "1, 2 or 3 fighters (tag)", "EASY → LEGEND" }, color = RED, kanji = "戦" },
		{ id = "SURVIVAL", title = "SURVIVAL", lines = { "Opponents one after another", "Stronger and stronger", "Beat your record" }, color = DARKRED, kanji = "生" },
		{ id = "CHALLENGE", title = "CHALLENGE · ASURA", lines = { "The four-armed KAI", "1 to 3 fighters against him", "Your victory decides your reward" }, color = GOLD, kanji = "阿" },
		{ id = "CHALLENGE_SHIN", title = "CHALLENGE · KUROEN SHIN", lines = { "KUROEN past every limit", "Reward: KUROEN's DIVINE ECLIPSE style" }, color = WHITE, kanji = "真" },
	})
	self.pages.online = self:buildSubCards("ONLINE MODE", {
		{ id = "VERSUS", queue = "RANKED", title = "RANKED FIGHT", lines = { "Elo points and rank", "An opponent at your level" }, color = GOLD, kanji = "位" },
		{ id = "VERSUS", queue = "NORMAL", title = "NORMAL FIGHT", lines = { "No points", "The first free player" }, color = RED, kanji = "対" },
		{ id = "VERSUS", queue = "FRIEND", title = "CHALLENGE A FRIEND", lines = { "The players on the server", "CHALLENGE · ACCEPT · INVITE" }, color = VIOLET, kanji = "友" },
	})
	self.pages.select = self:buildSelect()
	self.pages.search = self:buildSearch()
	self.pages.characters = self:buildCharacters()
	self.pages.ranking = self:buildRanking()
	self.pages.settings = self:buildSettings()
	self.pages.achievements = self:buildAchievements()
	self.pages.taunts = self:buildTaunts()
	self:buildBottom()
	-- Toast (errors, results).
	self.toast = label(root, { Visible = false, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 88),
		Size = UDim2.fromOffset(760, 64), BackgroundTransparency = 0, BackgroundColor3 = PANEL, Font = DISPLAY,
		TextSize = 26, TextScaled = true, TextWrapped = true,
		TextColor3 = GOLD, Text = "", TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 30 })
	new("UITextSizeConstraint", { MinTextSize = 16, MaxTextSize = 26 }, self.toast)
	new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16),
		PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, self.toast)
	Theme.surface(self.toast, Theme.GOLD)
	self.toast.BackgroundTransparency = 0.02
	-- PLAY AGAIN (after a solo match): the same request again, one click (or ENTER).
	self.again = Theme.button(root, { Visible = false, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 160),
		Size = UDim2.fromOffset(280, 56), BackgroundColor3 = Theme.RED, Font = DISPLAY, TextSize = 32, Text = "▶ PLAY AGAIN",
		ZIndex = 30 }, Theme.GOLD)
	self.again.Activated:Connect(function() self:playAgain() end)
	self.lastTeams = {} -- mode id -> the last team picked for it (the select remembers it)
	self:open("home")

	remote.OnClientEvent:Connect(function(packet)
		if typeof(packet) ~= "table" then return end
		if packet.error then
			self:flash("NOT POSSIBLE: " .. tostring(packet.error), RED)
		elseif packet.result then
			self:showResult(packet)
		elseif packet.ranking then
			self.ranking = packet.ranking
			self:refreshRanking()
		elseif packet.questGifts then
			self:questFlash(packet.questGifts)
		elseif packet.champion then
			self:flash("👑 CHAMPION OF THE WEEK · TITLE WEEKLY CHAMPION (SETTINGS › TITLE)", GOLD)
			self.toastUntil = os.clock() + 8
		else
			self.status = packet
			if packet.language and self.settings.onLanguage then self.settings.onLanguage(packet.language) end
			if packet.options and self.settings.onOptions then self.settings.onOptions(packet.options) end
			if packet.taunts then
				self.tauntWheel = packet.taunts
				if self.settings.onTaunts then self.settings.onTaunts(packet.taunts) end
				if self.page == "taunts" then self:refreshTaunts() end
			end
			self:refreshProfile()
			if self.page == "characters" and self.galleryKit then self:showKitInfo(self.galleryKit) end
			if self.page == "select" then self:refreshSelect() end
			self:refreshLocks()
			if self.page == "settings" then
				for _, refresh in self.settingRefresh or {} do refresh() end
			end
			if packet.bought then self:flash("STYLE BOUGHT · " .. packet.bought, GOLD) end
			if packet.unlocked then self:flash(packet.unlocked .. " UNLOCKED · YOURS FOREVER", GOLD) end
			if packet.state == "queue" then
				if self.page ~= "search" then self.searchStart = os.clock() end
				self:open("search")
			elseif packet.state == "menu" and self.page == "search" then
				self:open("home")
			end
		end
	end)
	-- (The fight controls sink most keys through ContextActionService: `processed` is true
	-- for them, so only a focused text box is skipped.)
	UserInputService.InputBegan:Connect(function(input)
		if not self.gui.Enabled or UserInputService:GetFocusedTextBox() then return end
		self:onKey(input.KeyCode)
	end)
	RunService.RenderStepped:Connect(function(dt) self:frame(dt) end)
	remote:FireServer({ action = "hello" })
	return self
end

-- ===================================================================== top bar and nav
function MenuController:buildTopBar()
	local bar = new("Frame", { Name = "TopBar", Size = UDim2.new(1, 0, 0, 78), BackgroundColor3 = Theme.INK,
		BackgroundTransparency = 0.06, BorderSizePixel = 0 }, self.root)
	Theme.rule(bar, UDim2.new(0, 28, 1, -1), UDim2.new(1, -56, 0, 1), Theme.LINE, 0.4)
	local logo = new("Frame", { Position = UDim2.fromOffset(30, 8), Size = UDim2.fromOffset(166, 64), BackgroundTransparency = 1 }, bar)
	local brush = Theme.rule(logo, UDim2.fromOffset(4, 15), UDim2.fromOffset(113, 34), Theme.RED)
	brush.Rotation = -9
	Theme.ink(logo, Theme.INK, 0.1)
	local title = label(logo, { Position = UDim2.fromOffset(6, -6), Size = UDim2.fromOffset(148, 62), Font = DISPLAY,
		TextSize = 62, Text = "K.O.", TextColor3 = Theme.WHITE, Rotation = -8 })
	stroke(title, 2, INK)
	label(logo, { Position = UDim2.fromOffset(40, 47), Size = UDim2.fromOffset(138, 14), Font = UI_FONT, TextSize = 10,
		Text = "FIGHTING GAME", TextColor3 = Theme.WHITE, Rotation = -8 })
	self.tabs = {}
	local tabs = { { "PLAY", "home" }, { "FIGHTERS", "characters" }, { "RANKING", "ranking" },
		{ "ACHIEVEMENTS", "achievements" }, { "SETTINGS", "settings" } }
	for i, tab in tabs do
		local b = new("TextButton", { Name = "Tab_" .. tab[2], Position = UDim2.fromOffset(218 + (i - 1) * 167, 0),
			Size = UDim2.fromOffset(159, 78), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1,
			Font = UI_FONT, TextSize = 14, Text = tab[1], TextColor3 = Theme.MUTED, AutoButtonColor = false, BorderSizePixel = 0 }, bar)
		-- (a plain colour: a UIGradient on a text button tints its text too, the tabs' names
		-- came out black on black, the active one invisible)
		b.BackgroundColor3 = RED:Lerp(INK, 0.6)
		local underline = Theme.rule(b, UDim2.new(0, 12, 1, -3), UDim2.new(1, -24, 0, 3), Theme.RED)
		underline.Visible = false
		b.Activated:Connect(function() self:open(tab[2]) end)
		self.tabs[tab[2]] = { button = b, underline = underline }
	end
	local profile = new("Frame", { Name = "Profile", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -28, 0, 12),
		Size = UDim2.fromOffset(468, 54), BackgroundColor3 = Theme.INK, BorderSizePixel = 0 }, bar)
	Theme.edge(profile)
	local face = new("ImageLabel", { Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(46, 46), BackgroundColor3 = DARKRED,
		BorderSizePixel = 0 }, profile)
	Theme.edge(face, Theme.RED)
	task.spawn(function()
		local player = Players.LocalPlayer
		local ok, image = pcall(Players.GetUserThumbnailAsync, Players, player.UserId,
			Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		if ok then face.Image = image end
	end)
	label(profile, { Position = UDim2.fromOffset(62, 5), Size = UDim2.fromOffset(196, 20), Font = UI_FONT, TextSize = 15,
		Text = Players.LocalPlayer.DisplayName, TextColor3 = Theme.WHITE, TextTruncate = Enum.TextTruncate.AtEnd })
	self.profileRank = label(profile, { Position = UDim2.fromOffset(62, 26), Size = UDim2.fromOffset(196, 14), Font = BODY_FONT, TextSize = 10,
		Text = "", TextColor3 = Theme.MUTED, TextTruncate = Enum.TextTruncate.AtEnd })
	local track = Theme.rule(profile, UDim2.fromOffset(62, 45), UDim2.fromOffset(194, 3), Theme.LINE)
	self.profileBar = Theme.rule(track, UDim2.fromOffset(0, 0), UDim2.fromScale(0, 1), Theme.GOLD)
	-- The currencies (GameModes.wallet): COINS, CRYSTALS (achievements), RANK points, each with
	-- its sprite (CurrencyIcons).
	self.wallet, self.walletChips, self.walletShown = {}, {}, {}
	for i, kind in { "coins", "crystals", "rank" } do
		local chip = new("Frame", { Name = "Wallet_" .. kind, Position = UDim2.fromOffset(266 + (i - 1) * 67, 0), Size = UDim2.fromOffset(65, 54),
			BackgroundColor3 = Theme.RAISED, BackgroundTransparency = 0.45, BorderSizePixel = 0 }, profile)
		Theme.rule(chip, UDim2.new(0, 0, 1, -2), UDim2.new(1, 0, 0, 2), CurrencyIcons.COLORS[kind], 0.2)
		CurrencyIcons.make(kind, chip, 24, UDim2.fromOffset(4, 15))
		self.wallet[kind] = label(chip, { Position = UDim2.fromOffset(30, 0), Size = UDim2.fromOffset(34, 54), Font = UI_FONT,
			TextSize = 13, Text = "0", TextColor3 = Theme.WHITE })
		self.walletChips[kind] = chip
	end
end

-- A selected destination carries the red brush accent, in both navigation bars.
function MenuController:buildNav()
	local nav = new("Frame", { Name = "Navigation", Position = UDim2.fromOffset(36, 122),
		Size = UDim2.fromOffset(360, 548), BackgroundTransparency = 1 }, self.root)
	self.nav, self.navItems = nav, {}
	local entries = {
		{ "home", "PLAY", "FIGHT ONLINE OR AGAINST THE CPU", "戦" },
		{ "characters", "FIGHTERS", "THE " .. #MoveData.KitOrder .. " FIGHTERS · YOUR FAVORITE", "人" },
		{ "ranking", "RANKING", "CLIMB THE RANKS", "位" },
		{ "players", "PLAYERS", "CHALLENGE · INVITE A FRIEND (H)", "友" },
		{ "achievements", "ACHIEVEMENTS", "ACHIEVEMENTS · QUESTS · YOUR PROGRESS", "誉" },
		{ "taunts", "TAUNTS", "YOUR 6 TRASH TALKS · EZ, BOZO…", "煽" },
		{ "settings", "SETTINGS", "EFFECTS · SOUND · MUSIC · LANGUAGE", "設" },
	}
	local step = if #entries > 6 then 78 else 88 -- (seven entries: a little tighter, same height)
	for i, entry in entries do
		local b = new("TextButton", { Name = "Nav_" .. entry[1], Position = UDim2.fromOffset(0, (i - 1) * step),
			Size = UDim2.fromOffset(360, step - 10), Rotation = -1.4, BackgroundColor3 = Color3.new(1, 1, 1),
			AutoButtonColor = false, Text = "", BorderSizePixel = 0 }, nav)
		local wash = gradient(b, Theme.RAISED, Theme.INK, 0)
		local edge = Theme.edge(b)
		Theme.ink(b, Theme.WHITE, 0.96)
		local rail = Theme.rule(b, UDim2.fromOffset(0, 0), UDim2.new(0, 4, 1, 0), Theme.RED)
		local glyph = label(b, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -32, 0.5, 0), Size = UDim2.fromOffset(88, 78),
			Font = UI_FONT, TextSize = 72, Text = entry[4], TextColor3 = Theme.MUTED, TextTransparency = 0.87,
			TextXAlignment = Enum.TextXAlignment.Center })
		label(b, { Position = UDim2.fromOffset(22, 7), Size = UDim2.fromOffset(292, 40), Font = DISPLAY, TextSize = 32,
			Text = entry[2], TextColor3 = Theme.WHITE })
		local subtitle = label(b, { Position = UDim2.fromOffset(22, 49), Size = UDim2.fromOffset(298, 19), Font = BODY_FONT,
			TextSize = 10, Text = entry[3], TextColor3 = Theme.MUTED, TextTruncate = Enum.TextTruncate.AtEnd })
		label(b, { Position = UDim2.new(1, -30, 0, 18), Size = UDim2.fromOffset(20, 38), Font = BODY_FONT,
			TextSize = 30, Text = "›", TextColor3 = Theme.WHITE })
		local item = { button = b, wash = wash, edge = edge, rail = rail, glyph = glyph, subtitle = subtitle, active = false }
		self.navItems[entry[1]] = item
		local function hover(on)
			edge.Color = if item.active or on then Theme.RED else Theme.LINE
		end
		b.MouseEnter:Connect(function() hover(true) end)
		b.MouseLeave:Connect(function() hover(false) end)
		b.SelectionGained:Connect(function() hover(true) end)
		b.SelectionLost:Connect(function() hover(false) end)
		b.Activated:Connect(function()
			if entry[1] == "players" then
				if self.hub then self.hub:setVisible(not self.hub.panel.Visible) end
			else self:open(entry[1]) end
		end)
	end
end

-- ===================================================================== home: mode cards
-- A mode card (right column): title, lines, a kanji in the corner, an arrow.
local function card(parent, props)
	local b = new("TextButton", { Name = "ModeCard", Position = props.position, Size = props.size,
		BackgroundColor3 = Color3.new(1, 1, 1), AutoButtonColor = false, Text = "", BorderSizePixel = 0, ClipsDescendants = true }, parent)
	gradient(b, Theme.INK, props.color:Lerp(Theme.INK, 0.82), 0)
	local edge = Theme.edge(b, props.color:Lerp(Theme.LINE, 0.65))
	Theme.ink(b, props.color, 0.81)
	Theme.rule(b, UDim2.fromOffset(0, 0), UDim2.new(0, 3, 1, 0), props.color)
	local glyphSize = math.min(props.size.Y.Offset - 24, 148)
	label(b, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 4), Size = UDim2.fromOffset(glyphSize, glyphSize),
		Font = UI_FONT, TextSize = math.floor(glyphSize * 0.85), Text = props.kanji, TextColor3 = props.color, TextTransparency = 0.85,
		TextXAlignment = Enum.TextXAlignment.Center, Rotation = -8 })
	local compact = props.size.X.Offset < 300
	local tight = props.size.Y.Offset <= 140
	local title = label(b, { Name = "CardTitle", Position = UDim2.fromOffset(22, 14), Size = UDim2.new(1, -44, 0, if tight then 34 elseif compact then 40 else 46),
		Font = DISPLAY, TextSize = if compact then 30 elseif tight then 32 else 40, Text = props.title, TextColor3 = Theme.WHITE,
		TextScaled = true })
	new("UITextSizeConstraint", { MaxTextSize = if compact then 30 elseif tight then 32 else 40, MinTextSize = 18 }, title)
	local lines = props.lines or {}
	local lineHeight = if tight then 18 else 21
	local linesHeight = #lines * lineHeight
	for i, line in lines do
		label(b, { Position = UDim2.new(0, 22, 1, -18 - linesHeight + (i - 1) * lineHeight), Size = UDim2.new(1, -84, 0, lineHeight),
			Font = BODY_FONT, TextSize = if compact then 11 else 12, Text = line, TextColor3 = Theme.MUTED,
			TextTruncate = Enum.TextTruncate.AtEnd })
	end
	local arrow = new("TextLabel", { Name = "Arrow", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.fromOffset(36, 36), BackgroundColor3 = props.color, Font = UI_FONT, TextSize = 28, Text = "›",
		TextColor3 = Theme.WHITE, BorderSizePixel = 0 }, b)
	gradient(arrow, Color3.new(1, 1, 1), Color3.fromHex("8D8D9B"), 90)
	local function focus(on)
		edge.Color = if on then props.color else props.color:Lerp(Theme.LINE, 0.65)
		edge.Thickness = if on then 2 else 1
	end
	b.MouseEnter:Connect(function() focus(true) end)
	b.MouseLeave:Connect(function() focus(false) end)
	b.SelectionGained:Connect(function() focus(true) end)
	b.SelectionLost:Connect(function() focus(false) end)
	return b
end

local function rightPage(self, name, accent)
	local page = new("Frame", { Name = name, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -28, 0, 122),
		Size = UDim2.fromOffset(560, 548), BackgroundTransparency = 0.04, BorderSizePixel = 0 }, self.root)
	Theme.surface(page, accent)
	return page
end

function MenuController:buildHome()
	local page = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -28, 0, 122), Size = UDim2.fromOffset(560, 548),
		BackgroundTransparency = 1 }, self.root)
	card(page, { position = UDim2.fromOffset(0, 0), size = UDim2.fromOffset(560, 178), color = Theme.RED, kanji = "対", title = "ONLINE MODE",
		titleSize = 52, lines = { "RANKED FIGHTS", "NORMAL FIGHTS", "CHALLENGE A FRIEND ON THE SERVER" } }).Activated:Connect(function()
		self:open("online")
	end)
	card(page, { position = UDim2.fromOffset(0, 190), size = UDim2.fromOffset(560, 178), color = Color3.fromHex("C8C8D0"), kanji = "戦",
		title = "SOLO MODE", titleSize = 52, lines = { "1 VS 1 · CPU", "SURVIVAL", "CHALLENGE · ASURA" } }).Activated:Connect(function()
		self:open("solo")
	end)
	card(page, { position = UDim2.fromOffset(0, 380), size = UDim2.fromOffset(274, 168), color = Theme.BLUE, kanji = "隊", title = "TEAMS",
		titleSize = 40, kanjiSize = 120, lines = { "1V1 · 2V2 · 3V3", "against the CPU" } }).Activated:Connect(function()
		self:choose({ id = "VERSUS_CPU" }, 3)
	end)
	card(page, { position = UDim2.fromOffset(286, 380), size = UDim2.fromOffset(274, 168), color = Theme.VIOLET, kanji = "練", title = "TRAINING",
		titleSize = 40, kanjiSize = 120, lines = { "LEARN · TEST", "COMBOS" } }).Activated:Connect(function()
		self:choose({ id = "TRAINING" })
	end)
	return page
end

-- MODE SOLO / MODE EN LIGNE: a title and a column of cards.
function MenuController:buildSubCards(title, entries)
	local page = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -28, 0, 122), Size = UDim2.fromOffset(560, 548),
		BackgroundTransparency = 1 }, self.root)
	local t = label(page, { Size = UDim2.new(1, 0, 0, 50), Font = DISPLAY, TextSize = 40, Text = title, TextColor3 = WHITE })
	Theme.rule(page, UDim2.fromOffset(0, 53), UDim2.fromOffset(46, 3), Theme.RED)
	local step = if #entries > 3 then 112 else 140 -- (four modes: tighter cards)
	for i, entry in entries do
		local locked = false
		local b = card(page, { position = UDim2.fromOffset(0, 72 + (i - 1) * step), size = UDim2.fromOffset(560, step - 12),
			color = if locked then GREY else entry.color, kanji = entry.kanji, title = entry.title, titleSize = 42, kanjiSize = 120,
			lines = entry.lines })
		b.Activated:Connect(function()
			if locked then
				self:flash("CHALLENGE · SOON", GREY)
			elseif entry.queue == "FRIEND" then
				self.queue = "FRIEND"
				self:choose({ id = "VERSUS" })
			else
				if entry.queue then self.queue = entry.queue end
				self:choose({ id = entry.id })
			end
		end)
	end
	local back = new("TextButton", { Position = UDim2.fromOffset(0, 72 + #entries * step), Size = UDim2.fromOffset(150, 40),
		BackgroundColor3 = PANEL, Font = UI_FONT, TextSize = 15, Text = "◀ BACK", TextColor3 = WHITE }, page)
	back.BorderSizePixel = 0
	Theme.edge(back)
	back.Activated:Connect(function() self:open("home") end)
	return page
end

-- ===================================================================== select
--[[
	Fighter select in the Street Fighter IV way (Wilhem's reference): the player's fighter large
	on the left (its kanji as the portrait, its name in big brush letters, its badge), the
	opponent on the right, and the column of portraits in the middle (4 wide), the VS emblem
	above it; the options (team, level or queue) and COMBAT ! along the bottom.
]]
local SELECT_COLUMNS = 4

-- One side of the screen: a huge ghost kanji (the "portrait"), the name, a badge and a line.
function MenuController:selectSide(page, left)
	local side = new("Frame", { Position = if left then UDim2.fromOffset(0, 0) else UDim2.new(0.66, 0, 0, 0),
		Size = UDim2.new(0.34, 0, 1, -150), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 6 }, page)
	local portrait = label(side, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(if left then 0.42 else 0.58, 0.42),
		Size = UDim2.fromScale(1.1, 0.95), Font = UI_FONT, TextScaled = true, Text = "", TextColor3 = WHITE,
		TextTransparency = 0.15, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6 })
	stroke(portrait, 6, INK)
	-- The fighter's own 3D model in its own guard, in front of its ghost kanji (see
	-- MenuController:showPreview; the models are built by the server, KitPreviews).
	local view = new("ViewportFrame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(if left then 0.46 else 0.54, 0.31),
		Size = UDim2.fromScale(1, 0.6), BackgroundTransparency = 1, Ambient = Color3.fromHex("8A8090"), -- (above the name, which hid its legs)
		LightColor = Color3.fromHex("FFF1E0"), LightDirection = Vector3.new(-0.4, -1, 0.6), ZIndex = 7 }, side)
	local world = new("WorldModel", {}, view)
	local camera = new("Camera", { FieldOfView = 26 }, view)
	view.CurrentCamera = camera
	local name = label(side, { AnchorPoint = Vector2.new(if left then 0 else 1, 0), Position = UDim2.new(if left then 0 else 1, if left then 28 else -28, 0.6, 0),
		Size = UDim2.new(0.9, 0, 0, 110), Font = DISPLAY, TextScaled = true, Text = "", TextColor3 = WHITE, Rotation = if left then -6 else 6,
		TextXAlignment = if left then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right, ZIndex = 8 })
	stroke(name, 4, RED)
	local badge = new("Frame", { AnchorPoint = Vector2.new(if left then 0 else 1, 0), Position = UDim2.new(if left then 0 else 1, if left then 40 else -40, 0.6, 118),
		Size = UDim2.fromOffset(96, 64), BackgroundColor3 = RED, BorderSizePixel = 0, ZIndex = 8 }, side)
	stroke(badge, 3, WHITE)
	local badgeKanji = label(badge, { Size = UDim2.fromScale(1, 1), Font = UI_FONT, TextScaled = true, Text = "", TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 9 })
	local role = label(side, { AnchorPoint = Vector2.new(if left then 0 else 1, 0), Position = UDim2.new(if left then 0 else 1, if left then 150 else -150, 0.6, 118),
		Size = UDim2.new(0.62, 0, 0, 64), Font = UI_FONT, TextSize = 16, TextWrapped = true, Text = "", TextColor3 = GOLD,
		TextXAlignment = if left then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right, ZIndex = 8 })
	return { portrait = portrait, name = name, badge = badge, badgeKanji = badgeKanji, role = role, view = view, world = world,
		camera = camera, left = left }
end

function MenuController:buildSelect()
	local page = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 78), Size = UDim2.new(1, 0, 1, -78),
		BackgroundColor3 = DARKRED, BorderSizePixel = 0, ZIndex = 5 }, self.root)
	gradient(page, Color3.fromHex("6A0A16"), INK, 0)
	Theme.ink(page, Theme.RED, 0.93) -- (the same speed lines as the menu's cards)
	self.selectTitle = label(page, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(560, 40),
		Font = DISPLAY, TextScaled = true, Text = "", TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 7 })
	stroke(self.selectTitle, 2, INK)
	self.p1 = self:selectSide(page, true)
	self.p2 = self:selectSide(page, false)
	-- The column of portraits, the VS emblem above it.
	-- (it ends above the options panel: at 630 high its last row of fighters slid under it)
	local column = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52), Size = UDim2.fromOffset(440, 582),
		BackgroundColor3 = Theme.INK, BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 6 }, page)
	Theme.rule(column, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 3), Theme.RED)
	local vs = label(column, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(160, 64), Font = DISPLAY,
		TextScaled = true, Text = "VS", TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 8 })
	stroke(vs, 3, RED)
	local grid = new("Frame", { Position = UDim2.fromOffset(10, 74), Size = UDim2.new(1, -20, 1, -84), BackgroundTransparency = 1, ZIndex = 6 }, column)
	local rows = math.ceil(#MoveData.KitOrder / SELECT_COLUMNS)
	new("UIGridLayout", { CellSize = UDim2.new(1 / SELECT_COLUMNS, -6, 1 / rows, -6), CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	self.kitCells = {}
	for i, name in MoveData.KitOrder do
		local kit = MoveData.Kits[name]
		local color = kitColor(name)
		local cell = new("TextButton", { LayoutOrder = i, BackgroundColor3 = PANEL, AutoButtonColor = false, Text = "", BorderSizePixel = 0, ZIndex = 7 }, grid)
		local edge = stroke(cell, 2, Color3.fromHex("5A3A20"))
		gradient(cell, color:Lerp(INK, 0.35), INK, 90)
		label(cell, { Position = UDim2.fromScale(0, 0.02), Size = UDim2.fromScale(1, 0.7), Font = UI_FONT, TextScaled = true,
			Text = kit.Kanji, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 8 })
		label(cell, { Position = UDim2.fromScale(0.04, 0.72), Size = UDim2.fromScale(0.92, 0.24), Font = DISPLAY, TextScaled = true, Text = name,
			TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 8 })
		local pick = new("TextLabel", { BackgroundColor3 = RED, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -2, 0, 2),
			Size = UDim2.fromOffset(22, 22), Font = DISPLAY, TextSize = 18, Text = "", TextColor3 = WHITE, Visible = false, ZIndex = 9 }, cell)
		corner(pick, 11)
		-- (locked: a dark veil, the lock and the price; in TRAINING: FREE TRIAL)
		local lock = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = INK, BackgroundTransparency = 0.35, BorderSizePixel = 0,
			Font = UI_FONT, TextScaled = true, Text = "🔒\n" .. Economy.FIGHTER_PRICE, TextColor3 = GOLD, Visible = false, ZIndex = 9 }, cell)
		new("UIPadding", { PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.3, 0), PaddingLeft = UDim.new(0.12, 0),
			PaddingRight = UDim.new(0.12, 0) }, lock)
		local trial = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.new(1, -4, 0, 14),
			BackgroundColor3 = Theme.VIOLET, BorderSizePixel = 0, Font = UI_FONT, TextSize = 9, Text = "FREE TRIAL", TextColor3 = WHITE,
			Visible = false, ZIndex = 9 }, cell)
		cell.MouseEnter:Connect(function() self.kitIndex = i; self:refreshSelect() end)
		cell.Activated:Connect(function()
			self.kitIndex = i
			self:pickKit()
		end)
		self.kitCells[i] = { cell = cell, edge = edge, pick = pick, color = color, lock = lock, trial = trial }
	end
	-- (the details of the fighter under the cursor, on its side)
	self.kitName, self.kitRole = self.p1.name, self.p1.role
	self.kitText = label(page, { Position = UDim2.fromOffset(28, 52), Size = UDim2.new(0.3, -28, 0, 150), Font = BODY_FONT, TextSize = 14,
		TextWrapped = true, Text = "", TextColor3 = WHITE, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 8 })
	stroke(self.kitText, 1.5, INK)
	-- What it is good and bad at (GameModes.ratings, from the real data).
	self.kitStats = label(page, { Position = UDim2.fromOffset(28, 206), Size = UDim2.new(0.3, -28, 0, 132), Font = BODY_FONT, TextSize = 15,
		TextWrapped = true, RichText = true, Text = "", TextColor3 = WHITE, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 8 })
	stroke(self.kitStats, 1.5, INK)
	self.ratings = GameModes.ratings(MoveData, MoveData.KitOrder)
	self.kitInfoStroke = stroke(column, 3, RED)
	-- Options and buttons along the bottom.
	local options = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -56, 0, 172),
		BackgroundColor3 = Theme.INK, BackgroundTransparency = 0.12, BorderSizePixel = 0, ZIndex = 6 }, page)
	Theme.edge(options)
	Theme.rule(options, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 2), Theme.RED)
	self.teamLine = self:optionLine(options, 6, "TEAM", function(step)
		if not self.mode.team then return end
		self.teamSize = math.clamp(self.teamSize + step, 1, GameModes.MAX_TEAM)
		while #self.team > self.teamSize do table.remove(self.team) end
	end)
	self.secondLine = self:optionLine(options, 48, "LEVEL", function(step)
		if self.mode.level then
			self.level = math.clamp(self.level + step, 1, #LEVEL_NAMES)
		elseif self.mode.queue then
			local order = { "NORMAL", "RANKED", "FRIEND" }
			local index = table.find(order, self.queue) or 1
			self.queue = order[(index - 1 + step) % #order + 1]
		end
	end)
	-- The stage (Maps): RANDOM or one of them; online matches always draw theirs.
	self.stageLine = self:optionLine(options, 90, "STAGE", function(step)
		local order = { "RANDOM" }
		for _, map in Maps.LIST do table.insert(order, map.id) end
		local index = table.find(order, self.stage) or 1
		self.stage = order[(index - 1 + step) % #order + 1]
	end)
	self.teamSlots = label(options, { Position = UDim2.fromOffset(10, 134), Size = UDim2.new(0.6, 0, 0, 30), Font = DISPLAY, TextSize = 26,
		Text = "", TextColor3 = WHITE, ZIndex = 7 })
	self.goButton = Theme.button(options, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(250, 64),
		BackgroundColor3 = Theme.RED, Font = DISPLAY, TextSize = 40, Text = "FIGHT!", ZIndex = 7 }, Theme.GOLD)
	Theme.ink(self.goButton, Theme.WHITE, 0.85)
	self.goButton.Activated:Connect(function() self:start() end)
	local back = Theme.button(options, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -280, 0.5, 0), Size = UDim2.fromOffset(130, 44),
		Font = UI_FONT, TextSize = 16, Text = "◀ BACK", ZIndex = 7 })
	back.Activated:Connect(function() self:back() end)
	return page
end

function MenuController:optionLine(parent, y, name, change)
	local line = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y), Size = UDim2.new(0.6, 0, 0, 38), ZIndex = 6 }, parent)
	local caption = label(line, { Position = UDim2.fromOffset(16, 0), Size = UDim2.fromOffset(114, 38), Font = UI_FONT, TextSize = 14, Text = name,
		TextColor3 = Theme.MUTED, ZIndex = 7 })
	local function arrow(text, x, step)
		local b = Theme.button(line, { Position = UDim2.fromOffset(x, 3), Size = UDim2.fromOffset(32, 32),
			Font = UI_FONT, TextSize = 18, Text = text, TextColor3 = Theme.GOLD, ZIndex = 7 }, Theme.GOLD)
		b.Activated:Connect(function()
			change(step)
			self:refreshSelect()
		end)
	end
	arrow("◀", 130, -1)
	local value = label(line, { Position = UDim2.fromOffset(168, 0), Size = UDim2.fromOffset(330, 38), Font = DISPLAY, TextSize = 26, Text = "",
		TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 7 })
	arrow("▶", 504, 1)
	return { frame = line, value = value, label = caption, change = change }
end

-- The 3D model of `kit` on one side of the select screen (nil: none), posed every frame by
-- the real Animator in its own guard (the kit's stance). Cosmetic only.
function MenuController:showPreview(side, kit)
	if side.kit == kit and (side.model or not kit) then return end
	if side.model then side.model:Destroy() end
	side.model, side.animation, side.kit = nil, nil, kit
	side.portrait.TextTransparency = if kit then 0.7 else 0.15
	local folder = ReplicatedStorage:FindFirstChild("KitPreviews")
	local source = kit and folder and folder:FindFirstChild(kit)
	if not source then return end
	local model = source:Clone()
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then
		model:Destroy()
		return
	end
	-- Turned three quarters toward the screen's middle (the rig faces -Z), its feet on the
	-- floor: the root at the height measured on this body (GORAN and ASURA are taller than
	-- KAI, a fixed height sank them into the floor and floated the small ones).
	root.Anchored = true
	model.Parent = side.world
	local ok, animation = pcall(AnimationController.new, model)
	side.model, side.animation = model, if ok then animation else nil
	local height = if ok and animation.rootHeight then animation.rootHeight else 3
	local turn = CFrame.Angles(0, math.rad(if side.left then 25 else -25), 0)
	root.CFrame = CFrame.new(0, height, 0) * turn
	if ok then pcall(animation.update, animation, { state = "Idle", x = 0, y = 0, vx = 0, vy = 0, facing = 1, hitstop = 0, combo = 0,
		kit = kit }, nil, 1 / 60, os.clock(), 60, false) end
	side.born = os.clock()
	-- The camera fits the whole body (weapon and extra arms included), whatever its size.
	local _, size = model:GetBoundingBox()
	local top = math.max(size.Y, 5.5)
	local middle = Vector3.new(0, top / 2, 0)
	local distance = (top / 2) / math.tan(math.rad(side.camera.FieldOfView / 2)) / 0.82 + size.Z / 2
	side.camera.CFrame = CFrame.lookAt(middle + Vector3.new(0, 0.3, -distance), middle)
end

function MenuController:animatePreviews(dt)
	for _, side in { self.p1, self.p2 } do
		if side and side.animation then
			-- (its own guard, the kit's stance: every fighter stands its own way, never the shared
			-- arms-up victory pose)
			local view = { state = "Idle", x = 0, y = 0, vx = 0, vy = 0, facing = 1, hitstop = 0, combo = 0, kit = side.kit }
			pcall(side.animation.update, side.animation, view, nil, dt, os.clock(), 60, false)
		end
	end
end

function MenuController:refreshSelect()
	local mode = self.mode
	if not mode then return end
	local name = MoveData.KitOrder[self.kitIndex]
	local kit = MoveData.Kits[name]
	for i, entry in self.kitCells do
		local selected = i == self.kitIndex
		entry.edge.Thickness = if selected then 4 else 2
		entry.edge.Color = if selected then GOLD else entry.color
		local order = table.find(self.team, MoveData.KitOrder[i])
		entry.pick.Visible = order ~= nil
		entry.pick.Text = if order then tostring(order) else ""
		local kitName = MoveData.KitOrder[i]
		entry.lock.Visible = not self:canPlay(kitName, mode.id)
		entry.trial.Visible = mode.id == "TRAINING" and not self:owns(kitName)
	end
	local color = kitColor(name)
	self.kitName.Text = name
	self.p1.portrait.Text, self.p1.portrait.TextColor3 = kit.Kanji, color
	self.p1.badge.BackgroundColor3, self.p1.badgeKanji.Text = color:Lerp(RED, 0.4), kit.Kanji
	local level = kit.Difficulty or 2
	self.kitRole.Text = kit.Role .. "  ·  " .. string.rep("★", level) .. string.rep("☆", 3 - level) .. " " .. ({ "SIMPLE", "MEDIUM", "TECHNICAL" })[level]
	-- The other side: the opponent (unknown until the match: the CPU draws its team, the
	-- search finds a player).
	local bossKit = mode.boss and MoveData.Kits[mode.boss]
	local foe = if bossKit then mode.boss elseif mode.queue then "OPPONENT" else "CPU"
	self.p2.name.Text = foe
	self:showPreview(self.p1, name)
	self:showPreview(self.p2, if bossKit then mode.boss else nil)
	self.p2.portrait.Text = if bossKit then bossKit.Kanji else "？"
	self.p2.portrait.TextColor3 = if bossKit then GOLD else GREY
	self.p2.badgeKanji.Text = if bossKit then bossKit.Kanji elseif mode.queue then "対" else "戦"
	self.p2.badge.BackgroundColor3 = if bossKit then Color3.fromHex("8A6A10") else Color3.fromHex("3A3A44")
	self.p2.role.Text = if mode.level then "LEVEL " .. LEVEL_NAMES[self.level] elseif mode.queue then QUEUES[self.queue] else ""
	-- (the S + E of the sheet and the ultimates, so a new fighter can be read before it is picked)
	local crouch = kit.Starters.Crouch.Special and MoveData.Moves[kit.Starters.Crouch.Special]
	local u = kit.Ultimates
	self.kitText.Text = kit.Description .. "\n\nHealth " .. kit.Stats.MaxHealth .. (if kit.Passive then " · passive " .. kit.Passive.Name else "")
		.. (if crouch then "\nS + E: " .. crouch.name else "")
		.. "\nFORWARD + R: OVERHEAD (blocked standing only)"
		.. "\nR: " .. MoveData.Moves[u.Rush].name .. " · AWAKENING: " .. MoveData.Moves[u.Awaken].name
		.. "\nGATE: " .. MoveData.Moves[u.Gate].name .. (if u.Fatal then " · FATAL: " .. MoveData.Moves[u.Fatal].name else "")
	local rating = self.ratings[name]
	if rating then
		local plus, minus = GameModes.traits(rating)
		local lines = { string.format('<font color="#6CFF8A">+ %s</font>   <font color="#FF6A6A">− %s</font>',
			if #plus > 0 then table.concat(plus, " · ") else "—", if #minus > 0 then table.concat(minus, " · ") else "—") }
		for _, stat in GameModes.STATS do
			local value = rating[stat]
			local hue = if value >= 4 then "#6CFF8A" elseif value <= 2 then "#FF6A6A" else "#FFD23F"
			table.insert(lines, string.format('%s  <font color="%s">%s</font><font color="#55555F">%s</font>', stat, hue,
				string.rep("■", value), string.rep("■", 5 - value)))
		end
		self.kitStats.Text = table.concat(lines, "\n")
	end
	self.kitInfoStroke.Color = color
	self.bigKanji.Text = kit.Kanji
	self.teamLine.frame.Visible = mode.team == true
	self.teamLine.value.Text = self.teamSize .. (if self.teamSize > 1 then " FIGHTERS (TAG)" else " FIGHTER")
	if mode.level then
		self.secondLine.frame.Visible = true
		self.secondLine.label.Text = "CPU LEVEL"
		self.secondLine.value.Text = LEVEL_NAMES[self.level]
	elseif mode.queue then
		self.secondLine.frame.Visible = true
		self.secondLine.label.Text = "MATCH"
		self.secondLine.value.Text = QUEUES[self.queue]
	else
		self.secondLine.frame.Visible = false
	end
	self.stageLine.frame.Visible = not mode.queue
	local stage = Maps.BY_ID[self.stage or ""]
	self.stageLine.value.Text = if stage then stage.kanji .. " " .. stage.name else "RANDOM"
	local slots = {}
	for i = 1, self.teamSize do slots[i] = self.team[i] or "—" end
	self.teamSlots.Text = "YOUR TEAM: " .. table.concat(slots, "  ·  ")
	local ready = #self.team >= self.teamSize
	self.goButton.Text = if mode.queue and self.queue == "FRIEND" then "SEE THE PLAYERS" elseif mode.queue then "SEARCH!" else "FIGHT!"
	self.goButton.BackgroundColor3 = if ready then RED else Color3.fromHex("3A3A44")
end

function MenuController:pickKit()
	local name = MoveData.KitOrder[self.kitIndex]
	if self.mode and not self:canPlay(name, self.mode.id) then
		-- (locked out of TRAINING: offer to unlock it, or to try it for free)
		self:askUnlock(name)
		return
	end
	local found = table.find(self.team, name)
	if found then
		table.remove(self.team, found)
	elseif #self.team < self.teamSize then
		table.insert(self.team, name)
	else
		self.team[#self.team] = name
	end
	self:refreshSelect()
end

-- Opens the fighter select for a mode (`teamSize`: preset team size, ÉQUIPES card).
function MenuController:choose(entry, teamSize)
	local mode = GameModes.find(entry.id)
	if not mode or mode.locked then return end
	self.mode = mode
	self.teamSize = if mode.team then math.clamp(teamSize or self.teamSize, 1, GameModes.MAX_TEAM) else 1
	-- The last team picked for this mode, else the favourite fighter, is preselected.
	local favourite = self.status.hero or "KAI"
	local last = self.lastTeams[mode.id]
	if last and mode.team and not teamSize then self.teamSize = math.clamp(#last, 1, GameModes.MAX_TEAM) end
	if last and #last <= self.teamSize then
		self.team = table.clone(last)
	else
		self.team = { favourite }
	end
	-- (a fighter no longer playable in this mode is not preselected: KAI, free, instead)
	for i = #self.team, 1, -1 do
		if not self:canPlay(self.team[i], mode.id) then table.remove(self.team, i) end
	end
	if #self.team == 0 then self.team = { "KAI" } end
	self.kitIndex = table.find(MoveData.KitOrder, self.team[1]) or table.find(MoveData.KitOrder, favourite) or 1
	if not mode.queue then self.queue = "NORMAL" end
	self:open("select")
end

function MenuController:start()
	local mode = self.mode
	if #self.team < self.teamSize then
		self:flash("PICK " .. (self.teamSize - #self.team) .. " MORE FIGHTER(S)", RED)
		return
	end
	local team = table.clone(self.team)
	for _, kit in team do
		if not self:canPlay(kit, mode.id) then
			self:askUnlock(kit)
			return
		end
	end
	if mode.queue and self.queue == "FRIEND" then
		-- A friend's 1v1: remember the team on the server, then the players' list (DÉFIER).
		self.remote:FireServer({ action = "team", team = team })
		if self.hub then self.hub:setVisible(true) end
		return
	end
	local request = {
		mode = mode.id, team = team, level = if mode.level then self.level else nil, queue = if mode.queue then self.queue else nil,
		map = if mode.queue then nil else (self.stage or "RANDOM"),
	}
	self.lastTeams[mode.id] = table.clone(team)
	self.lastRequest = if mode.queue then nil else request -- (online: a new search, not a replay)
	self.remote:FireServer({ action = "start", request = request })
end

function MenuController:playAgain()
	self.again.Visible = false
	if not self.lastRequest or self.inMatch then return end
	self.remote:FireServer({ action = "start", request = table.clone(self.lastRequest) })
end

-- ===================================================================== search
function MenuController:buildSearch()
	local page = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 270), Size = UDim2.fromOffset(660, 282),
		BackgroundColor3 = PANEL, BorderSizePixel = 0, ZIndex = 5 }, self.root)
	Theme.surface(page, Theme.RED)
	self.searchPulse = Theme.rule(page, UDim2.fromOffset(24, 88), UDim2.new(1, -48, 0, 2), Theme.RED)
	self.searchTitle = label(page, { Position = UDim2.fromOffset(20, 16), Size = UDim2.new(1, -40, 0, 56), Font = DISPLAY, TextScaled = true,
		Text = "SEARCHING FOR AN OPPONENT…", TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6 })
	self.searchText = label(page, { Position = UDim2.fromOffset(20, 104), Size = UDim2.new(1, -40, 0, 80), Font = BODY_FONT, TextSize = 16,
		TextWrapped = true, Text = "", TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6 })
	local cancel = new("TextButton", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(200, 46),
		BackgroundColor3 = RED, Font = DISPLAY, TextSize = 30, Text = "CANCEL", TextColor3 = WHITE, ZIndex = 6 }, page)
	cancel.BorderSizePixel = 0
	Theme.edge(cancel, Theme.RED)
	cancel.Activated:Connect(function() self.remote:FireServer({ action = "cancel" }) end)
	return page
end

-- ===================================================================== characters, ranking, settings
--[[
	FIGHTERS: the fighter (name, role, difficulty), its 3D body in the style chosen (drag to
	turn it), OWNED / FREE / the price to unlock it with the player's balance, TRY IN TRAINING
	(any fighter, free), FAVORITE, then every style of the fighter: free, to earn (challenge,
	quest), owned, or for sale (2500 coins, a confirmation first). A click on a style previews it
	on the body; EQUIP wears it in fights. The server checks every purchase and every style.
]]
function MenuController:buildCharacters()
	local page = rightPage(self, "FIGHTERS", Theme.RED)
	Theme.heading(page, "FIGHTERS", Theme.RED)
	self.galleryName = label(page, { Position = UDim2.fromOffset(22, 74), Size = UDim2.new(1, -44, 0, 26), Font = UI_FONT, TextSize = 16,
		TextTruncate = Enum.TextTruncate.AtEnd, Text = "", TextColor3 = Theme.GOLD })
	-- the 3D preview (drag to turn), its frame
	local holder = new("Frame", { Position = UDim2.fromOffset(22, 104), Size = UDim2.fromOffset(196, 232), BackgroundColor3 = INK,
		BackgroundTransparency = 0.2, BorderSizePixel = 0 }, page)
	Theme.edge(holder)
	gradient(holder, Color3.fromHex("2A0A12"), INK, 90)
	local view = new("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = Color3.fromHex("8A8090"),
		LightColor = Color3.fromHex("FFF1E0"), LightDirection = Vector3.new(-0.4, -1, 0.6), Active = true }, holder)
	local world = new("WorldModel", {}, view)
	local camera = new("Camera", { FieldOfView = 26 }, view)
	view.CurrentCamera = camera
	self.gallery = { view = view, world = world, camera = camera, yaw = math.rad(-20), left = true }
	self.galleryHint = label(holder, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, -8, 0, 14),
		Font = BODY_FONT, TextSize = 10, Text = "◀ DRAG TO TURN ▶", TextColor3 = Theme.MUTED, TextXAlignment = Enum.TextXAlignment.Center })
	self.galleryStyle = label(holder, { Position = UDim2.fromOffset(6, 4), Size = UDim2.new(1, -12, 0, 16), Font = UI_FONT, TextSize = 11,
		Text = "", TextColor3 = WHITE, TextTruncate = Enum.TextTruncate.AtEnd })
	-- (turning: mouse or finger, on the preview only)
	local dragging, lastX = nil, 0
	view.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, lastX = input, input.Position.X
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input == dragging then
			self.gallery.yaw += (input.Position.X - lastX) * 0.012
			lastX = input.Position.X
			self.gallery.turned = os.clock()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input == dragging or input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = nil end
	end)
	-- the fighter's description
	self.galleryText = label(page, { Position = UDim2.fromOffset(232, 104), Size = UDim2.new(1, -254, 0, 150), Font = BODY_FONT, TextSize = 12,
		TextWrapped = true, Text = "", TextColor3 = WHITE, TextYAlignment = Enum.TextYAlignment.Top })
	-- owned / locked, the price, the balance; UNLOCK, TRY IN TRAINING, FAVORITE
	self.galleryState = label(page, { Position = UDim2.fromOffset(232, 256), Size = UDim2.new(1, -254, 0, 18), Font = UI_FONT, TextSize = 12,
		Text = "", TextColor3 = GOLD, TextTruncate = Enum.TextTruncate.AtEnd })
	self.galleryUnlock = Theme.button(page, { Position = UDim2.fromOffset(232, 278), Size = UDim2.fromOffset(150, 26), Font = UI_FONT, TextSize = 12,
		Text = "", BackgroundColor3 = Theme.RED }, GOLD)
	self.galleryUnlock.Activated:Connect(function() self:askUnlock(self.galleryKit) end)
	self.galleryFavorite = Theme.button(page, { Position = UDim2.fromOffset(390, 278), Size = UDim2.fromOffset(148, 26), Font = UI_FONT, TextSize = 12,
		Text = "★ FAVORITE" }, GOLD)
	self.galleryFavorite.Activated:Connect(function() self:makeFavorite(self.galleryKit) end)
	local try = Theme.button(page, { Position = UDim2.fromOffset(232, 310), Size = UDim2.new(1, -254, 0, 26), Font = UI_FONT, TextSize = 12,
		Text = "▶ TRY IN TRAINING (FREE)" }, GOLD)
	try.Activated:Connect(function()
		local kit = self.galleryKit or "KAI"
		self.remote:FireServer({ action = "start", request = { mode = "TRAINING", team = { kit }, map = self.stage or "RANDOM" } })
	end)
	-- every style of the fighter
	Theme.rule(page, UDim2.fromOffset(22, 344), UDim2.new(1, -44, 0, 1), Theme.LINE)
	label(page, { Position = UDim2.fromOffset(22, 348), Size = UDim2.new(1, -44, 0, 20), Font = UI_FONT, TextSize = 13,
		Text = "STYLES · SHOP", TextColor3 = GOLD })
	self.styleList = new("ScrollingFrame", { Position = UDim2.fromOffset(22, 370), Size = UDim2.new(1, -44, 1, -380), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 5, ScrollBarImageColor3 = GOLD, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y }, page)
	new("UIGridLayout", { CellSize = UDim2.new(0.5, -5, 0, 56), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }, self.styleList)
	return page
end

-- Does the player own this fighter (free, bought, or the developer access)?
function MenuController:owns(kit)
	local s = self.status or {}
	return s.dev == true or Economy.owns(s, kit)
end

-- May this fighter be fielded in the mode picked (TRAINING: all of them)?
function MenuController:canPlay(kit, modeId)
	local s = self.status or {}
	return Economy.canPlay(s, kit, modeId, s.dev == true)
end

-- A yes / no question over the whole menu (every purchase asks first).
function MenuController:confirm(text, yesText, onYes)
	if self.dialog then self.dialog:Destroy() end
	local shade = new("TextButton", { Name = "Confirm", Size = UDim2.fromScale(1, 1), BackgroundColor3 = INK, BackgroundTransparency = 0.35,
		AutoButtonColor = false, Text = "", BorderSizePixel = 0, ZIndex = 60 }, self.root)
	self.dialog = shade
	local box = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(460, 210),
		BackgroundColor3 = PANEL, BorderSizePixel = 0, ZIndex = 61 }, shade)
	Theme.surface(box, Theme.GOLD)
	label(box, { Position = UDim2.fromOffset(20, 18), Size = UDim2.new(1, -40, 0, 100), Font = UI_FONT, TextSize = 17, TextWrapped = true,
		Text = text, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 62 })
	local function close()
		if self.dialog == shade then self.dialog = nil end
		shade:Destroy()
	end
	local yes = Theme.button(box, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, -18), Size = UDim2.new(0.5, -26, 0, 48),
		BackgroundColor3 = Theme.RED, Font = DISPLAY, TextSize = 26, Text = yesText, ZIndex = 62 }, GOLD)
	local no = Theme.button(box, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -18), Size = UDim2.new(0.5, -26, 0, 48),
		Font = DISPLAY, TextSize = 26, Text = "CANCEL", ZIndex = 62 })
	yes.Activated:Connect(function() close(); onYes() end)
	no.Activated:Connect(close)
	shade.Activated:Connect(close)
end

-- UNLOCK a fighter (4000 coins): the balance is checked first, then a confirmation.
function MenuController:askUnlock(kit)
	if not kit or self:owns(kit) then return end
	local coins = tonumber(self.status.coins) or 0
	if coins < Economy.FIGHTER_PRICE then
		self:flash(string.format("NOT ENOUGH COINS · %s COSTS %d (YOU HAVE %d) · TRY IT IN TRAINING", kit, Economy.FIGHTER_PRICE, coins), RED)
		return
	end
	self:confirm(string.format("UNLOCK %s FOR %d COINS?\nYou have %d coins. It stays yours forever.", kit, Economy.FIGHTER_PRICE, coins),
		"UNLOCK", function() self.remote:FireServer({ action = "buyFighter", kit = kit }) end)
end

-- BUY a style (2500 coins), after a confirmation.
function MenuController:askStyle(name)
	local item = CharacterData.SHOP[name]
	if not item then return end
	local coins = tonumber(self.status.coins) or 0
	if coins < item.coins then
		self:flash(string.format("NOT ENOUGH COINS · THIS STYLE COSTS %d (YOU HAVE %d)", item.coins, coins), RED)
		return
	end
	self:confirm(string.format("BUY THE STYLE %s FOR %d COINS?\nYou have %d coins.", name, item.coins, coins),
		"BUY", function() self.remote:FireServer({ action = "buySkin", skin = name }) end)
end

function MenuController:makeFavorite(kit)
	if not kit then return end
	if not self:owns(kit) then
		self:flash(kit .. " IS LOCKED · UNLOCK IT FIRST", RED)
		return
	end
	self.remote:FireServer({ action = "hero", kit = kit })
	self:flash(kit .. " · YOUR FAVORITE", kitColor(kit))
end

-- The style shown on the body of the FIGHTERS page (the server builds its body once).
function MenuController:showStyle(name)
	local style = CharacterData.Skins[name]
	if not style then return end
	local g = self.gallery
	self.galleryStyleName = name
	self.galleryStyle.Text = name
	local folder = ReplicatedStorage:FindFirstChild("StylePreviews")
	local source = folder and folder:FindFirstChild(name)
	if not source then
		-- (not built yet: ask for it, show the fighter's first style meanwhile)
		self.remote:FireServer({ action = "preview", skin = name })
		self.galleryWaiting = name
		local kits = ReplicatedStorage:FindFirstChild("KitPreviews")
		source = kits and kits:FindFirstChild(style.Kit)
	else
		self.galleryWaiting = nil
	end
	if g.source == source then return end
	if g.model then g.model:Destroy() end
	g.model, g.animation, g.source, g.kit = nil, nil, source, style.Kit
	if not source then return end
	local model = source:Clone()
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then
		model:Destroy()
		return
	end
	root.Anchored = true
	model.Parent = g.world
	local ok, animation = pcall(AnimationController.new, model)
	g.model, g.animation, g.root = model, if ok then animation else nil, root
	g.height = if ok and animation.rootHeight then animation.rootHeight else 3
	root.CFrame = CFrame.new(0, g.height, 0) * CFrame.Angles(0, g.yaw, 0)
	local _, size = model:GetBoundingBox()
	local top = math.max(size.Y, 5.5)
	local middle = Vector3.new(0, top / 2, 0)
	local distance = (top / 2) / math.tan(math.rad(g.camera.FieldOfView / 2)) / 0.86 + math.max(size.X, size.Z) / 2
	g.camera.CFrame = CFrame.lookAt(middle + Vector3.new(0, 0.3, -distance), middle)
end

function MenuController:animateGallery(dt)
	local g = self.gallery
	if not g then return end
	if self.galleryWaiting then
		local folder = ReplicatedStorage:FindFirstChild("StylePreviews")
		if folder and folder:FindFirstChild(self.galleryWaiting) then self:showStyle(self.galleryWaiting) end
	end
	if not g.model then return end
	-- (it turns slowly by itself until the player turns it)
	if os.clock() - (g.turned or 0) > 4 then g.yaw += dt * 0.35 end
	if g.root then g.root.CFrame = CFrame.new(0, g.height, 0) * CFrame.Angles(0, g.yaw, 0) end
	if g.animation then
		pcall(g.animation.update, g.animation, { state = "Idle", x = 0, y = 0, vx = 0, vy = 0, facing = 1, hitstop = 0, combo = 0, kit = g.kit },
			nil, dt, os.clock(), 60, false)
		if g.root then g.root.CFrame = CFrame.new(0, g.height, 0) * CFrame.Angles(0, g.yaw, 0) end
	end
end

-- The styles of `name` in the FIGHTERS page: free, to earn, owned or for sale.
function MenuController:refreshStyles(name)
	local list = self.styleList
	if not list then return end
	self.stylesKit = name
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	local s = self.status or {}
	local owned = s.ownedSkins or {}
	local equipped = (s.equipped or {})[name]
	local wearing = nil
	for i, styleName in CharacterData.StyleOrder[name] or {} do
		local style = CharacterData.Skins[styleName]
		local item = CharacterData.SHOP[styleName]
		local lock = CharacterData.LOCKED[styleName]
		local quest = Quests.BY_REWARD[styleName]
		local mine = s.dev == true or (if lock then (tonumber(s[lock]) or 0) >= 1 elseif item then owned[styleName] == true else true)
		if mine and (equipped == styleName or (not equipped and i == 1)) then wearing = styleName end
		local row = new("TextButton", { LayoutOrder = i, BackgroundColor3 = Theme.PANEL, AutoButtonColor = false, Text = "", BorderSizePixel = 0 }, list)
		local selected = self.galleryStyleName == styleName
		Theme.edge(row, if selected then GOLD elseif item then Color3.fromHex(style.Energy) else Theme.LINE)
		row.Activated:Connect(function()
			self:showStyle(styleName)
			self:refreshStyles(name)
		end)
		for k, key in { "Vest", "VestTrim", "Energy" } do
			new("Frame", { Position = UDim2.fromOffset(6 + (k - 1) * 10, 8), Size = UDim2.fromOffset(8, 40),
				BackgroundColor3 = Color3.fromHex(style[key]), BorderSizePixel = 0 }, row)
		end
		label(row, { Position = UDim2.fromOffset(40, 4), Size = UDim2.new(1, -128, 0, 22), Font = UI_FONT, TextSize = 13,
			Text = if item then item.theme else styleName, TextColor3 = WHITE, TextTruncate = Enum.TextTruncate.AtEnd })
		-- what it is: free, owned, the challenge or quest that gives it, its price
		local state, color = "FREE", GREY
		if lock then
			state, color = if mine then "EARNED" else (if lock == "shinGrade" then "BEAT KUROEN SHIN" else "BEAT ASURA"), if mine then GOLD else GREY
		elseif quest then
			state, color = if owned[styleName] then "QUEST · OWNED" else "QUEST · " .. quest.how, if owned[styleName] then GOLD else Theme.VIOLET
		elseif item then
			state, color = if owned[styleName] then "OWNED" else "SHOP", if owned[styleName] then GOLD else Color3.fromHex(style.Energy)
		end
		if s.dev and (lock or item) and not (if lock then (tonumber(s[lock]) or 0) >= 1 else owned[styleName]) then
			state ..= " · DEV ACCESS"
		end
		label(row, { Position = UDim2.fromOffset(40, 28), Size = UDim2.new(1, -128, 0, 22), Font = BODY_FONT, TextSize = 10, Text = state,
			TextColor3 = color, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
		-- the action: BUY (price), EQUIP, or EQUIPPED
		local action = Theme.button(row, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -5, 0.5, 0), Size = UDim2.fromOffset(80, 40),
			Font = UI_FONT, TextSize = 12, Text = "" }, GOLD)
		-- ROBUX (prepared): a style with a developer product (CharacterData.SHOP_PRODUCTS, set by
		-- Wilhem) gets a Robux button; Roblox shows the price and the server grants it.
		local product = CharacterData.SHOP_PRODUCTS[styleName]
		if product and not mine then
			local robux = Theme.button(row, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -90, 0.5, 0), Size = UDim2.fromOffset(40, 40),
				Font = UI_FONT, TextSize = 12, Text = "R$" }, GOLD)
			robux.Activated:Connect(function()
				pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, Players.LocalPlayer, product)
			end)
		end
		if wearing == styleName then
			action.Text, action.TextColor3 = "✓ WORN", GOLD
		elseif mine then
			action.Text = "EQUIP"
			action.Activated:Connect(function() self.remote:FireServer({ action = "equip", skin = styleName }) end)
		elseif item and not quest then
			action.Text = "      " .. item.coins
			CurrencyIcons.make("coins", action, 18, UDim2.fromOffset(5, 11))
			action.Activated:Connect(function() self:askStyle(styleName) end)
		else
			action.Text, action.TextColor3 = "🔒", GREY
			action.Activated:Connect(function() self:flash(state, color) end)
		end
	end
end

function MenuController:showKitInfo(name)
	local kit = MoveData.Kits[name]
	if not kit then return end
	self.galleryKit = name
	local level = kit.Difficulty or 2
	self.galleryName.Text = name .. " " .. kit.Kanji .. " · " .. kit.Role .. " · " .. string.rep("★", level) .. string.rep("☆", 3 - level)
	local lines = { kit.Description, "", "Health " .. kit.Stats.MaxHealth .. " · speed " .. kit.Stats.WalkSpeed }
	if kit.Passive then table.insert(lines, "Passive: " .. kit.Passive.Name) end
	table.insert(lines, "Ultimates: " .. MoveData.Moves[kit.Ultimates.Rush].name .. " · " .. MoveData.Moves[kit.Ultimates.Awaken].name
		.. " · " .. MoveData.Moves[kit.Ultimates.Gate].name .. (if kit.Ultimates.Fatal then " · " .. MoveData.Moves[kit.Ultimates.Fatal].name else ""))
	self.galleryText.Text = table.concat(lines, "\n")
	local s = self.status or {}
	local coins = tonumber(s.coins) or 0
	local free, owned = Economy.isFree(name), Economy.owns(s, name)
	if owned then
		self.galleryState.Text, self.galleryState.TextColor3 = if free then "✓ FREE FIGHTER" else "✓ UNLOCKED · YOURS FOREVER", GOLD
	elseif s.dev then
		self.galleryState.Text, self.galleryState.TextColor3 = "DEVELOPER ACCESS · NOT BOUGHT", Theme.VIOLET
	else
		self.galleryState.Text, self.galleryState.TextColor3 = string.format("🔒 LOCKED · %d COINS · YOU HAVE %d", Economy.FIGHTER_PRICE, coins), RED
	end
	self.galleryUnlock.Visible = not owned
	self.galleryUnlock.Text = "UNLOCK · " .. Economy.FIGHTER_PRICE
	self.galleryFavorite.Text = if s.hero == name then "★ YOUR FAVORITE" else "★ FAVORITE"
	-- the style shown: the one equipped (or the first), unless the player picked another one of this fighter
	local current = self.galleryStyleName
	if not current or not CharacterData.Skins[current] or CharacterData.Skins[current].Kit ~= name then
		current = (s.equipped or {})[name] or CharacterData.defaultStyle(name, nil)
	end
	self:showStyle(current)
	self:refreshStyles(name)
end

function MenuController:buildRanking()
	local page = rightPage(self, "RANKING", Theme.GOLD)
	Theme.heading(page, "RANKING", Theme.GOLD)
	self.rankingMine = label(page, { Position = UDim2.fromOffset(22, 80), Size = UDim2.new(1, -32, 0, 24), Font = UI_FONT, TextSize = 15,
		Text = "", TextColor3 = WHITE })
	self.rankingList = new("Frame", { Position = UDim2.fromOffset(22, 122), Size = UDim2.new(1, -44, 1, -140), BackgroundTransparency = 1 }, page)
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, self.rankingList)
	return page
end

function MenuController:refreshRanking()
	local list = self.rankingList
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	local s = self.status
	self.rankingMine.Text = "YOU: " .. (s.rank or "BRONZE") .. " · " .. (s.rating or 1000) .. " pts · " .. (s.wins or 0) .. " W / " .. (s.losses or 0) .. " L"
	local entries = self.ranking
	if not entries then
		label(list, { Size = UDim2.new(1, 0, 0, 30), Font = BODY_FONT, TextSize = 14, Text = "Loading…", TextColor3 = GREY })
		return
	end
	if #entries == 0 then
		label(list, { Size = UDim2.new(1, 0, 0, 60), Font = BODY_FONT, TextSize = 14, TextWrapped = true, TextColor3 = GREY,
			Text = "No ranking yet: play a RANKED match (the ranking is kept in the published game)." })
		return
	end
	for i, e in entries do
		local row = new("Frame", { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = if i <= 3 then Theme.GOLD:Lerp(Theme.INK, 0.91) else Theme.PANEL,
			BorderSizePixel = 0 }, list)
		Theme.rule(row, UDim2.fromOffset(0, 0), UDim2.new(0, 2, 1, 0), if i <= 3 then Theme.GOLD else Theme.LINE)
		label(row, { Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(40, 34), Font = DISPLAY, TextSize = 24, Text = "#" .. e.rank,
			TextColor3 = if i == 1 then GOLD else WHITE })
		label(row, { Position = UDim2.fromOffset(60, 0), Size = UDim2.new(1, -230, 1, 0), Font = UI_FONT, TextSize = 15, Text = e.name,
			TextColor3 = WHITE, TextTruncate = Enum.TextTruncate.AtEnd })
		label(row, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 0), Size = UDim2.fromOffset(170, 34), Font = UI_FONT,
			TextSize = 14, Text = e.title .. " · " .. e.rating, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Right })
	end
end

-- ACHIEVEMENTS: every achievement, where it is earned and the progress (GameModes.achievements,
-- from the saved profile the server sends with the menu status).
function MenuController:buildAchievements()
	local page = rightPage(self, "ACHIEVEMENTS", Theme.GOLD)
	Theme.heading(page, "ACHIEVEMENTS", Theme.GOLD)
	-- two lists: ACHIEVEMENTS (crystals) and QUESTS (styles)
	self.achTab = "achievements"
	self.achTabs = {}
	for i, tab in { { "achievements", "ACHIEVEMENTS" }, { "quests", "QUESTS" } } do
		local b = Theme.button(page, { Position = UDim2.fromOffset(22 + (i - 1) * 156, 76), Size = UDim2.fromOffset(148, 30), Font = UI_FONT,
			TextSize = 13, Text = tab[2] }, GOLD)
		b.Activated:Connect(function()
			self.achTab = tab[1]
			self:refreshAchievements()
		end)
		self.achTabs[tab[1]] = b
	end
	self.achievementsCount = label(page, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -22, 0, 80), Size = UDim2.fromOffset(200, 22),
		Font = UI_FONT, TextSize = 13, Text = "", TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Right })
	local list = new("ScrollingFrame", { Position = UDim2.fromOffset(22, 116), Size = UDim2.new(1, -44, 1, -136), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 6, ScrollBarImageColor3 = GOLD, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y }, page)
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	self.achievementsList = list
	return page
end

function MenuController:refreshAchievements()
	local list = self.achievementsList
	if not list then return end
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	for name, b in self.achTabs do
		b.BackgroundColor3 = if name == self.achTab then Theme.RED else Theme.PANEL
	end
	if self.achTab == "quests" then
		self:refreshQuests(list)
		return
	end
	local entries, done = GameModes.achievements(self.status or {})
	self.achievementsCount.Text = done .. " / " .. #entries .. " UNLOCKED"
	for i, a in entries do
		local row = new("Frame", { LayoutOrder = i, Size = UDim2.new(1, -10, 0, 104),
			BackgroundColor3 = if a.done then Theme.GOLD:Lerp(Theme.INK, 0.94) else Theme.PANEL, BorderSizePixel = 0 }, list)
		Theme.edge(row, if a.done then Theme.GOLD:Lerp(Theme.LINE, 0.4) else Theme.LINE)
		label(row, { Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(32, 32), Font = DISPLAY, TextSize = 25,
			Text = if a.done then "✓" else string.format("%02d", i), TextColor3 = if a.done then Theme.GOLD else Theme.MUTED,
			TextXAlignment = Enum.TextXAlignment.Center })
		label(row, { Position = UDim2.fromOffset(54, 10), Size = UDim2.new(1, -140, 0, 22), Font = UI_FONT, TextSize = 15,
			Text = a.name, TextColor3 = if a.done then Theme.GOLD else Theme.WHITE, TextTruncate = Enum.TextTruncate.AtEnd })
		label(row, { Position = UDim2.fromOffset(54, 36), Size = UDim2.new(1, -70, 0, 32), Font = BODY_FONT, TextSize = 12,
			Text = a.how, TextColor3 = Theme.MUTED, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
		label(row, { Position = UDim2.fromOffset(54, 72), Size = UDim2.new(1, -194, 0, 18), Font = UI_FONT, TextSize = 10,
			Text = a.where, TextColor3 = Theme.VIOLET, TextTruncate = Enum.TextTruncate.AtEnd })
		label(row, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 72), Size = UDim2.fromOffset(120, 18),
			Font = UI_FONT, TextSize = 11, Text = if a.done then "UNLOCKED" else a.value .. " / " .. a.goal,
			TextColor3 = if a.done then Theme.GOLD else Theme.WHITE, TextXAlignment = Enum.TextXAlignment.Right })
		local track = Theme.rule(row, UDim2.fromOffset(54, 96), UDim2.new(1, -68, 0, 2), Theme.LINE)
		Theme.rule(track, UDim2.fromOffset(0, 0), UDim2.fromScale(math.clamp(a.value / math.max(a.goal, 1), 0, 1), 1),
			if a.done then Theme.GOLD else Theme.VIOLET)
		-- (what it pays: crystals, faded until it is unlocked)
		local gem = CurrencyIcons.make("crystals", row, 24, UDim2.new(1, -38, 0, 8))
		label(row, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -44, 0, 10), Size = UDim2.fromOffset(44, 22), Font = UI_FONT,
			TextSize = 13, Text = "+" .. GameModes.CRYSTALS_PER_ACHIEVEMENT, TextColor3 = CurrencyIcons.COLORS.crystals,
			TextXAlignment = Enum.TextXAlignment.Right })
		if not a.done then
			for _, d in gem:GetDescendants() do
				if d:IsA("GuiObject") then d.BackgroundTransparency = math.max(d.BackgroundTransparency, 0.55) end
			end
		end
	end
end

-- QUESTS (Quests): simple challenges, their progress (saved by the server) and the style
-- each one gives (an existing style, shown in its colours).
function MenuController:refreshQuests(list)
	local entries = Quests.list(self.status or {})
	local done = 0
	for _, q in entries do if q.done then done += 1 end end
	self.achievementsCount.Text = done .. " / " .. #entries .. " DONE"
	for i, q in entries do
		local style = CharacterData.Skins[q.reward]
		local row = new("Frame", { LayoutOrder = i, Size = UDim2.new(1, -10, 0, 84),
			BackgroundColor3 = if q.done then Theme.VIOLET:Lerp(Theme.INK, 0.9) else Theme.PANEL, BorderSizePixel = 0 }, list)
		Theme.edge(row, if q.done then Theme.VIOLET else Theme.LINE)
		label(row, { Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(32, 32), Font = DISPLAY, TextSize = 25,
			Text = if q.done then "✓" else string.format("%02d", i), TextColor3 = if q.done then Theme.VIOLET else Theme.MUTED,
			TextXAlignment = Enum.TextXAlignment.Center })
		label(row, { Position = UDim2.fromOffset(54, 8), Size = UDim2.new(1, -200, 0, 22), Font = UI_FONT, TextSize = 15,
			Text = q.name, TextColor3 = WHITE, TextTruncate = Enum.TextTruncate.AtEnd })
		label(row, { Position = UDim2.fromOffset(54, 32), Size = UDim2.new(1, -200, 0, 18), Font = BODY_FONT, TextSize = 12,
			Text = q.how, TextColor3 = Theme.MUTED, TextTruncate = Enum.TextTruncate.AtEnd })
		label(row, { Position = UDim2.fromOffset(54, 54), Size = UDim2.fromOffset(120, 16), Font = UI_FONT, TextSize = 11,
			Text = if q.done then "DONE" else q.value .. " / " .. q.goal, TextColor3 = if q.done then Theme.VIOLET else WHITE })
		local track = Theme.rule(row, UDim2.fromOffset(54, 74), UDim2.new(1, -210, 0, 3), Theme.LINE)
		Theme.rule(track, UDim2.fromOffset(0, 0), UDim2.fromScale(math.clamp(q.value / math.max(q.goal, 1), 0, 1), 1), Theme.VIOLET)
		-- the reward: the style, its colours and its name
		local reward = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(138, 64),
			BackgroundColor3 = Theme.INK, BorderSizePixel = 0 }, row)
		Theme.edge(reward, if style then Color3.fromHex(style.Energy) else Theme.LINE)
		if style then
			for k, key in { "Vest", "VestTrim", "Energy" } do
				new("Frame", { Position = UDim2.fromOffset(6 + (k - 1) * 9, 8), Size = UDim2.fromOffset(7, 48),
					BackgroundColor3 = Color3.fromHex(style[key]), BorderSizePixel = 0 }, reward)
			end
		end
		label(reward, { Position = UDim2.fromOffset(38, 6), Size = UDim2.new(1, -42, 0, 14), Font = BODY_FONT, TextSize = 10,
			Text = "STYLE", TextColor3 = Theme.MUTED })
		label(reward, { Position = UDim2.fromOffset(38, 20), Size = UDim2.new(1, -42, 0, 38), Font = UI_FONT, TextSize = 12, TextWrapped = true,
			Text = q.reward, TextColor3 = if q.done then GOLD else WHITE, TextYAlignment = Enum.TextYAlignment.Top })
	end
end

-- TAUNTS: the six taunts of the fight's wheel. Pick a slot, then a taunt (a taunt already
-- on the wheel swaps places). Locked ones say how to earn them. Saved with the profile.
function MenuController:buildTaunts()
	local page = rightPage(self, "TAUNTS", Theme.RED)
	Theme.heading(page, "TAUNTS", Theme.RED, "Pick a slot, then a taunt. In a fight: the wheel opens with its key (SETTINGS, V by default) or the 💬 button on mobile.")
	self.tauntSlot = 1
	self.tauntSlotButtons = {}
	for i = 1, Taunts.SLOTS do
		local column, row = (i - 1) % 3, (i - 1) // 3
		local b = Theme.button(page, { Name = "TauntSlot" .. i, Position = UDim2.fromOffset(22 + column * 174, 120 + row * 48),
			Size = UDim2.fromOffset(166, 40), Text = "", Font = DISPLAY, TextSize = 18 }, Theme.GOLD)
		b.Activated:Connect(function()
			self.tauntSlot = i
			self:refreshTaunts()
		end)
		self.tauntSlotButtons[i] = b
	end
	Theme.rule(page, UDim2.fromOffset(22, 222), UDim2.new(1, -44, 0, 1), Theme.LINE, 0.3)
	local list = new("ScrollingFrame", { Position = UDim2.fromOffset(22, 232), Size = UDim2.new(1, -44, 1, -246), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 5, ScrollBarImageColor3 = Theme.RED, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y }, page)
	new("UIGridLayout", { CellSize = UDim2.fromOffset(166, 52), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	self.tauntCells = {}
	for _, taunt in Taunts.LIST do
		local cell = Theme.button(list, { Name = "Taunt_" .. taunt.id, LayoutOrder = taunt.order, Text = "" }, Theme.RED)
		local text = label(cell, { Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -36, 0, 26), Font = DISPLAY, TextSize = 20,
			Text = taunt.text, TextColor3 = Theme.WHITE, TextTruncate = Enum.TextTruncate.AtEnd })
		local note = label(cell, { Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -16, 0, 16), Font = BODY_FONT, TextSize = 9,
			Text = "", TextColor3 = Theme.MUTED, TextTruncate = Enum.TextTruncate.AtEnd })
		local badge = label(cell, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(20, 20),
			BackgroundTransparency = 0, BackgroundColor3 = Theme.RED, Font = UI_FONT, TextSize = 11, Text = "",
			TextColor3 = Theme.WHITE, TextXAlignment = Enum.TextXAlignment.Center })
		cell.Activated:Connect(function() self:equipTaunt(taunt.id) end)
		self.tauntCells[taunt.id] = { cell = cell, text = text, note = note, badge = badge }
	end
	return page
end

function MenuController:currentTaunts()
	local wheel = {}
	for i, id in self.tauntWheel or Taunts.DEFAULT do wheel[i] = id end
	return wheel
end

function MenuController:equipTaunt(id)
	if not Taunts.unlocked(id, self.status) then
		local taunt = Taunts.BY_ID[id]
		self:flash("LOCKED · " .. (taunt and taunt.unlock and taunt.unlock.how or ""), Theme.MUTED)
		return
	end
	local wheel = self:currentTaunts()
	local slot = self.tauntSlot or 1
	local already = table.find(wheel, id)
	if already then wheel[already] = wheel[slot] end -- (already on the wheel: the two swap)
	wheel[slot] = id
	self.tauntWheel = wheel
	self.tauntSlot = slot % Taunts.SLOTS + 1
	self:refreshTaunts()
	-- (one save once the clicks stop: the server takes a menu request every 0.5 s at most)
	self.tauntSerial = (self.tauntSerial or 0) + 1
	local serial = self.tauntSerial
	task.delay(0.8, function()
		if self.tauntSerial == serial then self.remote:FireServer({ action = "taunts", taunts = self.tauntWheel }) end
	end)
end

function MenuController:refreshTaunts()
	if not self.tauntCells then return end
	local wheel = self:currentTaunts()
	for i, b in self.tauntSlotButtons do
		local taunt = Taunts.BY_ID[wheel[i] or ""]
		b.Text = i .. "  " .. (if taunt then taunt.text else "—")
		b.TextColor3 = if i == self.tauntSlot then Theme.GOLD else Theme.WHITE
		local edge = b:FindFirstChildOfClass("UIStroke")
		if edge then edge.Color, edge.Thickness = if i == self.tauntSlot then Theme.GOLD else Theme.LINE, if i == self.tauntSlot then 2 else 1 end
	end
	for id, c in self.tauntCells do
		local taunt = Taunts.BY_ID[id]
		local open = Taunts.unlocked(id, self.status)
		local slot = table.find(wheel, id)
		c.badge.Visible = slot ~= nil
		c.badge.Text = if slot then tostring(slot) else ""
		c.text.TextColor3 = if open then Theme.WHITE else Theme.MUTED
		c.note.Text = if not open then "🔒 " .. taunt.unlock.how elseif slot then "ON THE WHEEL" else ""
	end
end

function MenuController:buildSettings()
	local page = rightPage(self, "SETTINGS", Theme.RED)
	Theme.heading(page, "SETTINGS", Theme.RED)
	self.settingRefresh = {}
	-- (a list that scrolls: on a small screen, or with the developer's line, nothing goes off the page)
	local rows = new("ScrollingFrame", { Position = UDim2.fromOffset(22, 86), Size = UDim2.new(1, -36, 1, -96), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 5, ScrollBarImageColor3 = Theme.RED, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y }, page)
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, rows)
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingRight = UDim.new(0, 8) }, rows)
	-- TITLE: the titles the player has (challenges, WEEKLY CHAMPION), or none; the server checks.
	self.settings.title = function()
		local owned = { "" }
		for _, t in self.status.titles or {} do table.insert(owned, t) end
		local index = table.find(owned, self.status.title or "") or 1
		self.remote:FireServer({ action = "title", title = owned[index % #owned + 1] })
	end
	self.settings.titleState = function()
		local t = self.status.title or ""
		return if t == "" then (if #(self.status.titles or {}) == 0 then "NONE YET" else "HIDDEN") else t
	end
	-- DEVELOPER ACCESS (only shown to a developer: DevAccess on the server)
	self.settings.dev = function()
		self.remote:FireServer({ action = "devMode", on = not self.status.dev })
	end
	self.settings.devState = function()
		return if self.status.dev then "ON · ALL FIGHTERS" else "OFF · NEW PLAYER"
	end
	for order, entry in { { "effects", "EFFECTS" }, { "sound", "SOUND" }, { "music", "MUSIC" }, { "mouse", "MOUSE LOCKED (CTRL)" },
		{ "language", "LANGUAGE" }, { "taunts", "OPPONENT TAUNTS" }, { "tauntKey", "TAUNT WHEEL KEY (PC)" }, { "title", "TITLE SHOWN" },
		{ "dev", "DEVELOPER ACCESS" } } do
		local key, name = entry[1], entry[2]
		local b = Theme.button(rows, { Name = "Setting_" .. key, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 52), Text = "" }, Theme.RED)
		label(b, { Position = UDim2.fromOffset(16, 0), Size = UDim2.new(0.5, -16, 1, 0), Font = UI_FONT,
			TextSize = 13, Text = name, TextColor3 = Theme.WHITE, TextWrapped = true })
		local value = label(b, { Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, -42, 1, 0), Font = UI_FONT,
			TextSize = 13, Text = "", TextColor3 = Theme.GOLD, TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = true })
		label(b, { Position = UDim2.new(1, -29, 0, 0), Size = UDim2.fromOffset(24, 52), Font = BODY_FONT,
			TextSize = 24, Text = "›", TextColor3 = Theme.MUTED })
		local function refresh()
			local get = self.settings[key .. "State"]
			value.Text = if get then get() else "—"
			if key == "dev" then b.Visible = self.status.isDev == true end
		end
		table.insert(self.settingRefresh, refresh)
		b.Activated:Connect(function()
			local toggle = self.settings[key]
			if toggle then toggle() end
			refresh()
		end)
		task.defer(refresh)
	end
	label(rows, { LayoutOrder = 100, Size = UDim2.new(1, 0, 0, 30), Font = BODY_FONT, TextSize = 11,
		TextWrapped = true, TextColor3 = Theme.MUTED, TextYAlignment = Enum.TextYAlignment.Top,
		Text = "In a fight: P or ◀ MENU to come back here. Full controls: COMBOS button in a fight, or the README." })
	return page
end

-- ===================================================================== bottom: news and fighters
function MenuController:buildBottom()
	local news = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 28, 1, -28), Size = UDim2.fromOffset(640, 176),
		BackgroundColor3 = INK, BackgroundTransparency = 0.25, BorderSizePixel = 0 }, self.root)
	Theme.surface(news, Theme.RED)
	label(news, { Position = UDim2.fromOffset(16, 9), Size = UDim2.fromOffset(300, 26), Font = DISPLAY, TextSize = 24, Text = "WHAT'S NEW", TextColor3 = WHITE })
	self.bottomNews = news
	for i, item in NEWS do
		local x = 14 + (i - 1) * 154
		local tile = new("Frame", { Position = UDim2.fromOffset(x, 46), Size = UDim2.fromOffset(146, 118), BackgroundColor3 = PANEL,
			BorderSizePixel = 0, ClipsDescendants = true }, news)
		tile.BackgroundColor3 = Color3.new(1, 1, 1)
		Theme.edge(tile, item.color:Lerp(Theme.LINE, 0.6))
		Theme.ink(tile, item.color, 0.87)
		gradient(tile, item.color:Lerp(INK, 0.35), INK, 90)
		label(tile, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.fromOffset(80, 66), Font = Enum.Font.GothamBlack,
			TextScaled = true, Text = item.kanji, TextColor3 = WHITE, TextTransparency = 0.25, TextXAlignment = Enum.TextXAlignment.Center })
		label(tile, { Position = UDim2.fromOffset(8, 70), Size = UDim2.fromOffset(130, 14), Font = UI_FONT, TextSize = 10, Text = item.tag, TextColor3 = GREY })
		label(tile, { Position = UDim2.fromOffset(8, 86), Size = UDim2.fromOffset(130, 26), Font = DISPLAY, TextScaled = true, Text = item.title, TextColor3 = WHITE })
	end
	-- MES PERSONNAGES: every fighter (a strip that scrolls); a click makes one the favourite (the lobby hero).
	local roster = new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -28, 1, -28), Size = UDim2.fromOffset(730, 176),
		BackgroundColor3 = INK, BackgroundTransparency = 0.25, BorderSizePixel = 0 }, self.root)
	Theme.surface(roster, Theme.RED)
	label(roster, { Position = UDim2.fromOffset(16, 9), Size = UDim2.fromOffset(300, 26), Font = DISPLAY, TextSize = 24, Text = "MY FIGHTERS", TextColor3 = WHITE })
	self.bottomRoster = roster
	self.rosterTiles = {}
	self.favoriteMarks = {}
	local strip = new("ScrollingFrame", { Position = UDim2.fromOffset(10, 42), Size = UDim2.new(1, -20, 0, 128), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollingDirection = Enum.ScrollingDirection.X, ScrollBarThickness = 4, ScrollBarImageColor3 = RED,
		CanvasSize = UDim2.fromOffset(4 + #MoveData.KitOrder * 84, 0), ElasticBehavior = Enum.ElasticBehavior.Never }, roster)
	for i, name in MoveData.KitOrder do
		local kit = MoveData.Kits[name]
		local color = kitColor(name)
		local tile = new("TextButton", { Position = UDim2.fromOffset(4 + (i - 1) * 84, 2), Size = UDim2.fromOffset(78, 118), BackgroundColor3 = PANEL,
			AutoButtonColor = false, Text = "", BorderSizePixel = 0 }, strip)
		tile.BackgroundColor3 = Color3.new(1, 1, 1)
		gradient(tile, color:Lerp(INK, 0.65), INK, 90)
		local edge = Theme.edge(tile)
		label(tile, { Position = UDim2.fromOffset(0, 4), Size = UDim2.fromOffset(78, 62), Font = Enum.Font.GothamBlack, TextScaled = true,
			Text = kit.Kanji, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center })
		label(tile, { Position = UDim2.fromOffset(0, 70), Size = UDim2.fromOffset(78, 22), Font = DISPLAY, TextScaled = true, Text = name,
			TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center })
		label(tile, { Position = UDim2.fromOffset(0, 94), Size = UDim2.fromOffset(78, 16), Font = UI_FONT, TextSize = 11,
			Text = string.rep("★", kit.Difficulty or 2) .. string.rep("☆", 3 - (kit.Difficulty or 2)), TextColor3 = GOLD,
			TextXAlignment = Enum.TextXAlignment.Center })
		local lock = label(tile, { Position = UDim2.fromOffset(0, 94), Size = UDim2.fromOffset(78, 16), Font = UI_FONT, TextSize = 11,
			Text = "🔒 " .. Economy.FIGHTER_PRICE, TextColor3 = GOLD, BackgroundTransparency = 0, BackgroundColor3 = INK,
			TextXAlignment = Enum.TextXAlignment.Center, Visible = false, ZIndex = 3 })
		self.rosterLocks = self.rosterLocks or {}
		self.rosterLocks[name] = lock
		tile.MouseEnter:Connect(function() if self.page == "characters" then self:showKitInfo(name) end end)
		tile.Activated:Connect(function()
			-- (owned: the favourite; locked: its page, to see it, try it or unlock it)
			if self:owns(name) then
				self:makeFavorite(name)
				if self.page == "characters" then self:showKitInfo(name) end
			else
				self.galleryKit = name
				if self.page ~= "characters" then self:open("characters") else self:showKitInfo(name) end
			end
		end)
		self.favoriteMarks[name] = label(tile, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 2),
			Size = UDim2.fromOffset(18, 20), Font = UI_FONT, TextSize = 15, Text = "★", TextColor3 = Theme.GOLD, Visible = false })
		self.rosterTiles[name] = edge
	end
end

-- The locks of the fighters' strip (owned or not, the developer access).
function MenuController:refreshLocks()
	for name, lock in self.rosterLocks or {} do lock.Visible = not self:owns(name) end
end

-- ===================================================================== navigation
function MenuController:open(page)
	Theme.reset(self.root)
	if page ~= "search" and self.page == "search" and self.status.state == "queue" then
		self.remote:FireServer({ action = "cancel" })
	end
	self.page = page
	for name, frame in self.pages do frame.Visible = name == page end
	-- (the big ghost kanji only behind the fighter select: in the lobby it sat on the hero)
	self.bigKanji.Visible = page == "select"
	-- (the page settles in: a short zoom from slightly smaller)
	local shown = self.pages[page]
	if shown then
		local scale = shown:FindFirstChild("PageScale") or new("UIScale", { Name = "PageScale" }, shown)
		scale.Scale = 0.985
		TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	local overlay = page == "select" or page == "search"
	self.nav.Visible = not overlay
	self.bottomNews.Visible = not overlay
	self.bottomRoster.Visible = not overlay
	local tab = if page == "solo" or page == "online" or overlay then "home" else page
	for name, entry in self.tabs do
		local active = name == tab
		entry.underline.Visible = active
		entry.button.TextColor3 = if active then WHITE else Theme.MUTED
		entry.button.BackgroundTransparency = if active then 0.05 else 1
	end
	for name, entry in self.navItems do
		local active = name == tab
		entry.active = active
		entry.wash.Color = if active then ColorSequence.new(Theme.RED, Color3.fromHex("930F2C"))
			else ColorSequence.new(Theme.RAISED, Theme.INK)
		entry.edge.Color = if active then Theme.RED else Theme.LINE
		entry.rail.BackgroundColor3 = if active then Theme.WHITE else Theme.RED
		entry.rail.Visible = active
		entry.glyph.TextColor3 = if active then Theme.INK else Theme.MUTED
		entry.glyph.TextTransparency = if active then 0.68 else 0.87
		entry.subtitle.TextColor3 = if active then Theme.WHITE else Theme.MUTED
	end
	if page == "select" then
		self.selectTitle.Text = self.mode.name .. " · PICK " .. (if self.mode.team then "YOUR TEAM" else "YOUR FIGHTER")
		self:refreshSelect()
	elseif page == "ranking" then
		self.remote:FireServer({ action = "ranking" })
		self:refreshRanking()
	elseif page == "characters" then
		self:showKitInfo(self.galleryKit or self.status.hero or "KAI")
	elseif page == "achievements" then
		self:refreshAchievements()
	elseif page == "taunts" then
		self:refreshTaunts()
	elseif page == "settings" then
		for _, refresh in self.settingRefresh or {} do refresh() end
	else
		self.bigKanji.Text = "開"
	end
end

function MenuController:back()
	if self.page == "select" then
		self:open(if self.mode.id == "VERSUS" then "online" elseif self.mode.id == "TRAINING" then "home" else "solo")
	elseif self.page == "search" then
		self.remote:FireServer({ action = "cancel" })
	elseif self.page ~= "home" then
		self:open("home")
	end
end

function MenuController:onKey(key)
	local K = Enum.KeyCode
	if key == K.Backspace or key == K.ButtonB then
		self:back()
		return
	end
	if self.again.Visible and (key == K.Return or key == K.ButtonA) then
		self:playAgain()
		return
	end
	if self.page ~= "select" then return end
	local n = #MoveData.KitOrder
	if key == K.Left or key == K.Q or key == K.A or key == K.DPadLeft then
		self.kitIndex = (self.kitIndex - 2) % n + 1
	elseif key == K.Right or key == K.D or key == K.DPadRight then
		self.kitIndex = self.kitIndex % n + 1
	elseif key == K.Up or key == K.Z or key == K.W or key == K.DPadUp then
		self.secondLine.change(1)
	elseif key == K.Down or key == K.S or key == K.DPadDown then
		self.teamLine.change(if self.teamSize >= GameModes.MAX_TEAM then -(GameModes.MAX_TEAM - 1) else 1)
	elseif key == K.Return or key == K.ButtonA then
		self:pickKit()
		return
	elseif key == K.Space or key == K.ButtonStart then
		self:start()
		return
	end
	self:refreshSelect()
end

function MenuController:refreshProfile()
	local s = self.status
	if not s.rating then return end
	self.profileRank.Text = (s.rank or "BRONZE") .. (if s.nextRank then " · next rank at " .. s.nextRank else " · top rank")
	local floor = 0
	for _, min in { 0, 900, 1100, 1300, 1500, 1700 } do
		if s.rating >= min then floor = min end
	end
	self.profileBar.Size = UDim2.fromScale(if s.nextRank then math.clamp((s.rating - floor) / (s.nextRank - floor), 0, 1) else 1, 1)
	-- The wallet rolls up to its new values (a coin gain counts up, the chip pulses).
	local wallet = GameModes.wallet(s)
	for _, kind in { "coins", "crystals", "rank" } do self:rollWallet(kind, wallet[kind]) end
	self.profileRank.Text ..= " · " .. (s.wins or 0) .. " W"
	if s.title and s.title ~= "" then
		self.profileRank.Text = "« " .. s.title .. " » · " .. self.profileRank.Text
		self.profileRank.TextColor3 = GOLD
	end
	for name, edge in self.rosterTiles do
		edge.Color = if name == s.hero then GOLD else Color3.fromHex("33333D")
		edge.Thickness = if name == s.hero then 2 else 1
		self.favoriteMarks[name].Visible = name == s.hero
	end
	if self.page == "ranking" then self:refreshRanking() end
	if self.page == "achievements" then self:refreshAchievements() end
end

local function short(n) return if n >= 10000 then string.format("%.1fk", n / 1000) else tostring(math.floor(n + 0.5)) end

function MenuController:rollWallet(kind, value)
	local from = self.walletShown[kind]
	self.walletShown[kind] = value
	local text = self.wallet[kind]
	if from == nil or from == value then
		text.Text = short(value)
		return
	end
	local counter = Instance.new("NumberValue")
	counter.Value = from
	counter.Changed:Connect(function(v) text.Text = short(v) end)
	local tween = TweenService:Create(counter, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = value })
	tween.Completed:Once(function() text.Text = short(value); counter:Destroy() end)
	tween:Play()
	local chip = self.walletChips[kind]
	local pulse = chip:FindFirstChild("Pulse") or new("UIScale", { Name = "Pulse" }, chip)
	pulse.Scale = 1.18
	TweenService:Create(pulse, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- A reward pops out of the wallet: the currency's sprite and "+N", rising and fading.
function MenuController:reward(kind, amount)
	if not amount or amount <= 0 then return end
	local chip = self.walletChips[kind]
	if not chip then return end
	local pop = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 6), Size = UDim2.fromOffset(110, 40),
		BackgroundColor3 = INK, BackgroundTransparency = 0.1, BorderSizePixel = 0, ZIndex = 40 }, chip)
	corner(pop, 20)
	stroke(pop, 2, CurrencyIcons.COLORS[kind])
	local icon = CurrencyIcons.make(kind, pop, 30, UDim2.fromOffset(6, 5))
	icon.ZIndex = 41
	local text = label(pop, { Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -44, 1, 0), Font = DISPLAY, TextSize = 28,
		Text = "+" .. amount, TextColor3 = CurrencyIcons.COLORS[kind], ZIndex = 41 })
	stroke(text, 1.5, INK)
	local scale = new("UIScale", { Scale = 0.4 }, pop)
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(1.6, function()
		TweenService:Create(pop, TweenInfo.new(0.6), { Position = UDim2.new(0.5, 0, 1, 40), BackgroundTransparency = 1 }):Play()
		TweenService:Create(text, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		task.delay(0.65, function() pop:Destroy() end)
	end)
end

-- A quest done: its style is given (a toast after the result).
function MenuController:questFlash(gifts)
	if type(gifts) ~= "table" or #gifts == 0 then return end
	task.delay(2.6, function()
		self:flash("QUEST COMPLETE · NEW STYLE: " .. table.concat(gifts, ", "), Theme.VIOLET)
		self.toastUntil = os.clock() + 6
	end)
end

function MenuController:flash(text, color)
	self.toast.Text, self.toast.TextColor3, self.toast.Visible = text, color or GOLD, true
	self.toastUntil = os.clock() + 2.5
end

local GRADE_NAMES = { "C", "B", "A", "S" }
function MenuController:showResult(packet)
	self:questFlash(packet.questGifts)
	if self.lastRequest and not packet.queue then
		self.again.Visible = true
		self.againUntil = os.clock() + 20
	end
	if packet.coins and packet.coins > 0 then
		task.delay(0.4, function() self:reward("coins", packet.coins) end)
	end
	if packet.challenge then
		if packet.boss == "KUROEN SHIN" then
			if packet.won then
				self:flash("KUROEN SHIN DEFEATED · RANK " .. GRADE_NAMES[packet.grade] .. " · KUROEN'S DIVINE ECLIPSE STYLE UNLOCKED", GOLD)
			else
				self:flash("KUROEN SHIN WAS BEYOND YOU · TRY AGAIN", RED)
			end
		elseif packet.won then
			self:flash("ASURA DEFEATED · RANK " .. GRADE_NAMES[packet.grade] .. " · TITLE « " .. (packet.title or "") .. " »"
				.. (if packet.unlock then " · AWAKENED KAI STYLE" else ""), GOLD)
		else
			self:flash("ASURA CRUSHED YOU · " .. (packet.damage or 0) .. " % OF HIS HEALTH TAKEN", RED)
		end
		self.toastUntil = os.clock() + 6
		return
	end
	if packet.survival then
		self:flash("SURVIVAL: " .. packet.survival .. " OPPONENT(S) BEATEN · RECORD " .. (packet.best or 0), GOLD)
	elseif packet.queue == "RANKED" then
		local sign = if (packet.delta or 0) >= 0 then "+" else ""
		self:flash((if packet.won then "VICTORY" elseif packet.draw then "DRAW" else "DEFEAT") .. " · " .. sign .. (packet.delta or 0)
			.. " PTS · " .. (packet.rank or "") .. " " .. (packet.rating or ""), if packet.won then GOLD else RED)
	else
		self:flash(if packet.won then "VICTORY!" elseif packet.draw then "DRAW" else "DEFEAT", if packet.won then GOLD else RED)
	end
	self.toastUntil = os.clock() + 5
end

-- In a match the menu hides; back in the menu it shows again.
function MenuController:setInMatch(inMatch)
	Theme.reset(self.root)
	self.inMatch = inMatch
	self.gui.Enabled = not inMatch
	self.backdrop.Enabled = not inMatch
	if not inMatch and self.page == "search" and self.status.state ~= "queue" then self:open("home") end
	if self.hub then self.hub:setInMatch(inMatch) end
end

function MenuController:leave()
	self.remote:FireServer({ action = "leave" })
end

-- (bound as a plain function for the HUD button)
function MenuController:bindLeave()
	return function() self:leave() end
end

function MenuController:frame(dt)
	if self.toast.Visible and os.clock() > (self.toastUntil or 0) then self.toast.Visible = false end
	if self.again.Visible and (os.clock() > (self.againUntil or 0) or self.page ~= "home") then self.again.Visible = false end
	if self.inMatch then return end
	if self.page == "select" then self:animatePreviews(dt or 1 / 60) end
	if self.page == "characters" then self:animateGallery(dt or 1 / 60) end
	if self.page == "search" then
		local s = self.status
		local waited = math.floor(os.clock() - self.searchStart)
		local queue = if s.queue == "RANKED" then "RANKED" else "NORMAL"
		local count = (s.waiting or {})[s.queue or "NORMAL"] or 0
		self.searchText.Text = string.format("Match %s · %d:%02d\n%d player(s) searching on this server · your rank: %s (%d pts)",
			queue, waited // 60, waited % 60, count, s.rank or "BRONZE", s.rating or 1000)
		self.searchPulse.BackgroundTransparency = 0.3 + 0.3 * math.sin(os.clock() * 4)
	end
	-- Camera on the lobby hero: low angle, slightly to the side, like the cover art.
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 40
		local sway = math.sin(os.clock() * 0.25) * 0.6
		camera.CFrame = CFrame.lookAt(Vector3.new(1.6 + sway, 2.6, 13.5), Vector3.new(0, 3.4, 0))
	end
end

return MenuController
