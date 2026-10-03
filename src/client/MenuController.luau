--[[
	Main menu, Street Fighter style: MODE SELECT (GameModes.List), then the fighter select
	(1 to 3 fighters for the relay modes, the CPU level, NORMAL / CLASSÉ / AMI for the 1v1
	between players), then the opponent search. The server checks and runs everything (see
	the server script); this only draws the menu and sends the request.

	Keyboard: Z/S or arrows to move, Q/D or arrows to change, ENTRÉE / ESPACE to confirm,
	RETOUR ARRIÈRE to go back. Mouse, touch and gamepad (D-pad, A, B) work too.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local MoveData = require(Shared.MoveData)
local CharacterData = require(Shared.CharacterData)
local GameModes = require(Shared.GameModes)
local FighterAI = require(Shared.FighterAI)

local WHITE = Color3.fromHex("F5F5F7")
local INK = Color3.fromHex("0B0B0E")
local PANEL = Color3.fromHex("15151B")
local RED = Color3.fromHex("E0102B")
local GOLD = Color3.fromHex("FFD23F")
local GREY = Color3.fromHex("8A8A94")
local DISPLAY = Enum.Font.Bangers
local UI_FONT = Enum.Font.GothamBlack
local BODY_FONT = Enum.Font.GothamBold

local MenuController = {}
MenuController.__index = MenuController

local function new(className, props, parent)
	local i = Instance.new(className)
	for k, v in props do i[k] = v end
	i.Parent = parent
	return i
end

local function stroke(gui, thickness, color)
	local s = new("UIStroke", { Thickness = thickness, Color = color or INK }, gui)
	s.ApplyStrokeMode = if gui:IsA("TextLabel") then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border
	return s
end

local function corner(gui, radius)
	new("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, gui)
end

local function kitColor(kit)
	local style = CharacterData.Skins[CharacterData.defaultStyle(kit, nil)]
	return Color3.fromHex(style and style.Energy or "E0102B")
end

local LEVEL_NAMES = {}
for i, level in FighterAI.Levels do LEVEL_NAMES[i] = level.name end
local QUEUES = { { id = "NORMAL", name = "NORMAL", sub = "sans points" }, { id = "RANKED", name = "CLASSÉ", sub = "points et rang" },
	{ id = "FRIEND", name = "AMI", sub = "défie un joueur du serveur" } }

function MenuController.new(remote, hub)
	local self = setmetatable({
		remote = remote, hub = hub, status = {}, screen = "modes", modeIndex = 1, kitIndex = 1,
		team = {}, teamSize = 1, level = 3, queueIndex = 1, inMatch = false, searchStart = 0,
	}, MenuController)
	local gui = new("ScreenGui", { Name = "MainMenu", ResetOnSpawn = false, DisplayOrder = 20, IgnoreGuiInset = true },
		Players.LocalPlayer:WaitForChild("PlayerGui"))
	self.gui = gui
	-- Background: dark, a red slash, big kanji.
	local back = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = INK, BackgroundTransparency = 0.12, BorderSizePixel = 0 }, gui)
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.45) }) }, back)
	local slash = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.62, 0.5), Size = UDim2.new(0.22, 0, 2, 0),
		Rotation = 18, BackgroundColor3 = RED, BackgroundTransparency = 0.82, BorderSizePixel = 0 }, back)
	self.slash = slash
	self.bigKanji = new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, 20),
		Size = UDim2.fromScale(0.45, 0.75), Font = Enum.Font.GothamBlack, TextScaled = true, Text = "戦", TextColor3 = RED,
		TextTransparency = 0.82 }, back)
	-- Title.
	local title = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 40, 0, 26), Size = UDim2.new(0.6, 0, 0, 70),
		Font = DISPLAY, TextScaled = true, Text = "JEUX COMBAT", TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left }, gui)
	stroke(title, 3, RED)
	self.subtitle = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 44, 0, 94), Size = UDim2.new(0.6, 0, 0, 22),
		Font = UI_FONT, TextSize = 16, Text = "CHOISIS TON MODE", TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left }, gui)
	-- Profile card, top right.
	local card = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, 26), Size = UDim2.fromOffset(300, 92),
		BackgroundColor3 = PANEL, BorderSizePixel = 0 }, gui)
	corner(card, 8)
	stroke(card, 2, GOLD)
	self.profileName = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 24),
		Font = DISPLAY, TextSize = 26, Text = Players.LocalPlayer.DisplayName, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd }, card)
	self.profileRank = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -24, 0, 20),
		Font = UI_FONT, TextSize = 15, Text = "", TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left }, card)
	self.profileStats = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 58), Size = UDim2.new(1, -24, 0, 28),
		Font = BODY_FONT, TextSize = 12, Text = "", TextColor3 = GREY, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true }, card)
	-- The three screens.
	self.modesScreen = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 40, 0, 140), Size = UDim2.new(1, -80, 1, -200) }, gui)
	self.selectScreen = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 40, 0, 140), Size = UDim2.new(1, -80, 1, -200), Visible = false }, gui)
	self.searchScreen = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 40, 0, 140), Size = UDim2.new(1, -80, 1, -200), Visible = false }, gui)
	-- Bottom help line.
	self.help = new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 40, 1, -16),
		Size = UDim2.new(1, -80, 0, 20), Font = BODY_FONT, TextSize = 13, TextColor3 = GREY, TextXAlignment = Enum.TextXAlignment.Left,
		Text = "" }, gui)
	-- Result banner (end of a ranked match, SURVIE record...).
	self.result = new("TextLabel", { Visible = false, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 130),
		Size = UDim2.fromOffset(620, 54), BackgroundColor3 = PANEL, Font = DISPLAY, TextSize = 30, TextColor3 = GOLD, ZIndex = 20,
		Text = "" }, gui)
	corner(self.result, 8)
	stroke(self.result, 3, GOLD)
	self:buildModes()
	self:buildSelect()
	self:buildSearch()
	self:show("modes")

	remote.OnClientEvent:Connect(function(packet)
		if typeof(packet) ~= "table" then return end
		if packet.error then
			self:flash("IMPOSSIBLE : " .. tostring(packet.error), RED)
		elseif packet.result then
			self:showResult(packet)
		else
			self.status = packet
			self:refreshProfile()
			if packet.state == "queue" then
				if self.screen ~= "search" then self.searchStart = os.clock() end
				self:show("search")
			elseif packet.state == "menu" and self.screen == "search" then
				self:show("modes")
			end
		end
	end)
	-- (The fight controls sink most keys through ContextActionService, so `processed` is
	-- true for them: only a focused text box is skipped.)
	UserInputService.InputBegan:Connect(function(input)
		if not self.gui.Enabled or UserInputService:GetFocusedTextBox() then return end
		self:onKey(input.KeyCode)
	end)
	RunService.RenderStepped:Connect(function(dt) self:frame(dt) end)
	remote:FireServer({ action = "hello" })
	return self
end

-- ===================================================================== screen 1: modes
function MenuController:buildModes()
	local list = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.5, 0, 1, 0) }, self.modesScreen)
	new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	self.modeButtons = {}
	for i, mode in GameModes.List do
		local b = new("TextButton", { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = PANEL, AutoButtonColor = false,
			Text = "", BorderSizePixel = 0 }, list)
		corner(b, 6)
		local edge = stroke(b, 2, Color3.fromHex("2A2A33"))
		local kanji = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 4), Size = UDim2.fromOffset(50, 50),
			Font = Enum.Font.GothamBlack, TextScaled = true, Text = mode.kanji, TextColor3 = RED }, b)
		local name = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(70, 6), Size = UDim2.new(1, -80, 0, 46),
			Font = DISPLAY, TextScaled = true, Text = mode.name .. (if mode.locked then "  · BIENTÔT" else ""),
			TextColor3 = if mode.locked then GREY else WHITE, TextXAlignment = Enum.TextXAlignment.Left }, b)
		b.MouseEnter:Connect(function() self.modeIndex = i; self:refreshModes() end)
		b.Activated:Connect(function()
			self.modeIndex = i
			self:chooseMode()
		end)
		self.modeButtons[i] = { button = b, edge = edge, kanji = kanji, name = name }
	end
	local info = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.42, 0, 0, 200),
		BackgroundColor3 = PANEL, BackgroundTransparency = 0.1, BorderSizePixel = 0 }, self.modesScreen)
	corner(info, 8)
	stroke(info, 2, RED)
	self.modeTitle = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -32, 0, 44),
		Font = DISPLAY, TextScaled = true, Text = "", TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left }, info)
	self.modeText = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 60), Size = UDim2.new(1, -32, 1, -70),
		Font = BODY_FONT, TextSize = 16, TextWrapped = true, Text = "", TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top }, info)
	self.onlineText = new("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 212), Size = UDim2.new(0.42, 0, 0, 40),
		BackgroundTransparency = 1, Font = BODY_FONT, TextSize = 13, TextWrapped = true, Text = "", TextColor3 = GREY,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, self.modesScreen)
end

function MenuController:refreshModes()
	for i, entry in self.modeButtons do
		local selected = i == self.modeIndex
		entry.edge.Color = if selected then GOLD else Color3.fromHex("2A2A33")
		entry.edge.Thickness = if selected then 3 else 2
		entry.button.BackgroundColor3 = if selected then Color3.fromHex("3A0A12") else PANEL
		entry.button.Size = UDim2.new(if selected then 1 else 0.94, 0, 0, 58)
	end
	local mode = GameModes.List[self.modeIndex]
	self.modeTitle.Text = mode.name
	self.modeText.Text = mode.description
	self.bigKanji.Text = mode.kanji
	local s = self.status
	local waiting = s.waiting or {}
	self.onlineText.Text = string.format("%d joueur(s) sur ce serveur · %d combat(s) en cours · en recherche : %d normal, %d classé",
		s.online or 1, s.matches or 0, waiting.NORMAL or 0, waiting.RANKED or 0)
end

function MenuController:chooseMode()
	local mode = GameModes.List[self.modeIndex]
	if mode.locked then
		self:flash(mode.name .. " ARRIVE BIENTÔT", GREY)
		return
	end
	self.mode = mode
	self.teamSize = if mode.team then math.clamp(self.teamSize, 1, GameModes.MAX_TEAM) else 1
	self.team = {}
	self:show("select")
end

-- ===================================================================== screen 2: fighters
function MenuController:buildSelect()
	local grid = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.56, 0, 0, 280) }, self.selectScreen)
	new("UIGridLayout", { CellSize = UDim2.new(0.25, -10, 0.5, -10), CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	self.kitCells = {}
	for i, name in MoveData.KitOrder do
		local kit = MoveData.Kits[name]
		local color = kitColor(name)
		local cell = new("TextButton", { LayoutOrder = i, BackgroundColor3 = PANEL, AutoButtonColor = false, Text = "", BorderSizePixel = 0 }, grid)
		corner(cell, 6)
		local edge = stroke(cell, 2, color)
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromHex("1C1C24"), color:Lerp(INK, 0.6)) }, cell)
		new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromScale(0, 0.04), Size = UDim2.fromScale(1, 0.56),
			Font = Enum.Font.GothamBlack, TextScaled = true, Text = kit.Kanji, TextColor3 = color }, cell)
		new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromScale(0, 0.6), Size = UDim2.fromScale(1, 0.22),
			Font = DISPLAY, TextScaled = true, Text = name, TextColor3 = WHITE }, cell)
		new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromScale(0, 0.82), Size = UDim2.fromScale(1, 0.14),
			Font = UI_FONT, TextScaled = true, Text = string.rep("★", kit.Difficulty or 2) .. string.rep("☆", 3 - (kit.Difficulty or 2)),
			TextColor3 = GOLD }, cell)
		local pick = new("TextLabel", { BackgroundColor3 = RED, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(26, 26), Font = DISPLAY, TextSize = 20, Text = "", TextColor3 = WHITE, Visible = false }, cell)
		corner(pick, 13)
		cell.MouseEnter:Connect(function() self.kitIndex = i; self:refreshSelect() end)
		cell.Activated:Connect(function()
			self.kitIndex = i
			self:pickKit()
		end)
		self.kitCells[i] = { cell = cell, edge = edge, pick = pick, color = color }
	end
	-- Fighter details.
	local info = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.4, 0, 0, 280),
		BackgroundColor3 = PANEL, BackgroundTransparency = 0.05, BorderSizePixel = 0 }, self.selectScreen)
	corner(info, 8)
	self.kitInfoStroke = stroke(info, 2, RED)
	self.kitName = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -32, 0, 50),
		Font = DISPLAY, TextScaled = true, Text = "", TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left }, info)
	self.kitRole = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 60), Size = UDim2.new(1, -32, 0, 22),
		Font = UI_FONT, TextSize = 16, Text = "", TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left }, info)
	self.kitText = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 90), Size = UDim2.new(1, -32, 1, -100),
		Font = BODY_FONT, TextSize = 15, TextWrapped = true, Text = "", TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top }, info)
	-- Options row: team size, CPU level / queue.
	local options = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 296), Size = UDim2.new(1, 0, 0, 120) }, self.selectScreen)
	self.teamLine = self:optionLine(options, 0, "ÉQUIPE", function(step)
		if not self.mode.team then return end
		self.teamSize = math.clamp(self.teamSize + step, 1, GameModes.MAX_TEAM)
		while #self.team > self.teamSize do table.remove(self.team) end
	end)
	self.secondLine = self:optionLine(options, 42, "NIVEAU", function(step)
		if self.mode.level then
			self.level = math.clamp(self.level + step, 1, #LEVEL_NAMES)
		elseif self.mode.queue then
			self.queueIndex = (self.queueIndex - 1 + step) % #QUEUES + 1
		end
	end)
	self.teamSlots = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 86), Size = UDim2.new(0.6, 0, 0, 30),
		Font = DISPLAY, TextSize = 26, Text = "", TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left }, options)
	self.goButton = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 70), Size = UDim2.fromOffset(240, 50),
		BackgroundColor3 = RED, Font = DISPLAY, TextSize = 34, Text = "COMBAT !", TextColor3 = WHITE, AutoButtonColor = true }, options)
	corner(self.goButton, 8)
	stroke(self.goButton, 3, GOLD)
	self.goButton.Activated:Connect(function() self:start() end)
	local backButton = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -252, 0, 76), Size = UDim2.fromOffset(120, 40),
		BackgroundColor3 = PANEL, Font = UI_FONT, TextSize = 16, Text = "◀ RETOUR", TextColor3 = WHITE, AutoButtonColor = true }, options)
	corner(backButton, 8)
	stroke(backButton, 2, GREY)
	backButton.Activated:Connect(function() self:back() end)
end

function MenuController:optionLine(parent, y, label, change)
	local line = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y), Size = UDim2.new(0.6, 0, 0, 36) }, parent)
	new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromOffset(110, 36), Font = UI_FONT, TextSize = 16, Text = label,
		TextColor3 = GREY, TextXAlignment = Enum.TextXAlignment.Left, Name = "Label" }, line)
	local function arrow(text, x, step)
		local b = new("TextButton", { Position = UDim2.fromOffset(x, 2), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = PANEL,
			Font = UI_FONT, TextSize = 18, Text = text, TextColor3 = GOLD, AutoButtonColor = true }, line)
		corner(b, 6)
		stroke(b, 2, GOLD)
		b.Activated:Connect(function()
			change(step)
			self:refreshSelect()
		end)
	end
	arrow("◀", 110, -1)
	local value = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(148, 0), Size = UDim2.fromOffset(260, 36),
		Font = DISPLAY, TextSize = 26, Text = "", TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center, Name = "Value" }, line)
	arrow("▶", 414, 1)
	return { frame = line, value = value, label = line.Label, change = change }
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
	end
	self.kitName.Text = name .. " " .. kit.Kanji
	local level = kit.Difficulty or 2
	self.kitRole.Text = kit.Role .. "  ·  " .. string.rep("★", level) .. string.rep("☆", 3 - level) .. " "
		.. ({ "SIMPLE", "MOYEN", "TECHNIQUE" })[level]
	self.kitText.Text = kit.Description .. "\n\nVie " .. kit.Stats.MaxHealth .. (if kit.Passive then " · passif " .. kit.Passive.Name else "")
	self.kitInfoStroke.Color = kitColor(name)
	self.slash.BackgroundColor3 = kitColor(name)
	self.bigKanji.Text = kit.Kanji
	-- Options.
	self.teamLine.frame.Visible = mode.team == true
	self.teamLine.value.Text = self.teamSize .. (if self.teamSize > 1 then " PERSOS (RELAIS)" else " PERSO")
	if mode.level then
		self.secondLine.frame.Visible = true
		self.secondLine.label.Text = "NIVEAU CPU"
		self.secondLine.value.Text = LEVEL_NAMES[self.level]
	elseif mode.queue then
		self.secondLine.frame.Visible = true
		self.secondLine.label.Text = "PARTIE"
		local q = QUEUES[self.queueIndex]
		self.secondLine.value.Text = q.name .. " · " .. q.sub
	else
		self.secondLine.frame.Visible = false
	end
	local slots = {}
	for i = 1, self.teamSize do
		slots[i] = self.team[i] or "—"
	end
	self.teamSlots.Text = "TON ÉQUIPE : " .. table.concat(slots, "  ·  ")
	local ready = #self.team >= self.teamSize
	self.goButton.Text = if mode.queue and QUEUES[self.queueIndex].id == "FRIEND" then "VOIR LES JOUEURS"
		elseif mode.queue then "CHERCHER !" else "COMBAT !"
	self.goButton.BackgroundColor3 = if ready then RED else Color3.fromHex("3A3A44")
end

-- Click / ENTRÉE on a fighter: adds it to the team (again: removes it).
function MenuController:pickKit()
	local name = MoveData.KitOrder[self.kitIndex]
	local found = table.find(self.team, name)
	if found then
		table.remove(self.team, found)
	elseif #self.team < self.teamSize then
		table.insert(self.team, name)
	else
		self.team[#self.team] = name
	end
	self:refreshSelect()
	if #self.team >= self.teamSize and self.teamSize == 1 then self:flash(name .. " CHOISI · ENTRÉE POUR COMBATTRE", GOLD) end
end

function MenuController:start()
	local mode = self.mode
	if #self.team < self.teamSize then
		self:flash("CHOISIS " .. (self.teamSize - #self.team) .. " PERSO(S) DE PLUS", RED)
		return
	end
	local team = table.clone(self.team)
	if mode.queue and QUEUES[self.queueIndex].id == "FRIEND" then
		-- A friend's 1v1: remember the team, then the hub (DÉFIER / ACCEPTER).
		self.remote:FireServer({ action = "start", request = { mode = "VERSUS", team = team, queue = "NORMAL" } })
		self.remote:FireServer({ action = "cancel" })
		if self.hub then self.hub.panel.Visible = true end
		return
	end
	self.remote:FireServer({ action = "start", request = {
		mode = mode.id, team = team, level = if mode.level then self.level else nil,
		queue = if mode.queue then QUEUES[self.queueIndex].id else nil,
	} })
end

-- ===================================================================== screen 3: search
function MenuController:buildSearch()
	local box = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 40), Size = UDim2.fromOffset(560, 240),
		BackgroundColor3 = PANEL, BorderSizePixel = 0 }, self.searchScreen)
	corner(box, 10)
	stroke(box, 3, GOLD)
	self.searchTitle = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 16), Size = UDim2.new(1, -40, 0, 56),
		Font = DISPLAY, TextScaled = true, Text = "RECHERCHE D'ADVERSAIRE…", TextColor3 = GOLD }, box)
	self.searchText = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 82), Size = UDim2.new(1, -40, 0, 80),
		Font = BODY_FONT, TextSize = 16, TextWrapped = true, Text = "", TextColor3 = WHITE }, box)
	local cancel = new("TextButton", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(200, 44),
		BackgroundColor3 = RED, Font = DISPLAY, TextSize = 28, Text = "ANNULER", TextColor3 = WHITE }, box)
	corner(cancel, 8)
	cancel.Activated:Connect(function() self.remote:FireServer({ action = "cancel" }) end)
end

-- ===================================================================== common
function MenuController:show(screen)
	self.screen = screen
	self.modesScreen.Visible = screen == "modes"
	self.selectScreen.Visible = screen == "select"
	self.searchScreen.Visible = screen == "search"
	if screen == "modes" then
		self.subtitle.Text = "CHOISIS TON MODE"
		self.slash.BackgroundColor3 = RED
		self.help.Text = "Z / S ou flèches : choisir · ENTRÉE : valider · souris et manette aussi"
		self:refreshModes()
	elseif screen == "select" then
		self.subtitle.Text = self.mode.name .. " · CHOISIS " .. (if self.mode.team then "TON ÉQUIPE" else "TON PERSO")
		self.help.Text = "Flèches : choisir un perso · ENTRÉE : le prendre (encore : le retirer) · Z / S : options · ESPACE : combat · RETOUR ARRIÈRE : retour"
		self:refreshSelect()
	else
		self.subtitle.Text = "1 CONTRE 1 · JOUEUR"
		self.help.Text = "La partie démarre dès qu'un adversaire est trouvé"
	end
end

function MenuController:back()
	if self.screen == "select" then self:show("modes")
	elseif self.screen == "search" then self.remote:FireServer({ action = "cancel" }) end
end

function MenuController:onKey(key)
	local K = Enum.KeyCode
	if self.screen == "modes" then
		if key == K.Up or key == K.Z or key == K.W or key == K.DPadUp then
			self.modeIndex = (self.modeIndex - 2) % #GameModes.List + 1
			self:refreshModes()
		elseif key == K.Down or key == K.S or key == K.DPadDown then
			self.modeIndex = self.modeIndex % #GameModes.List + 1
			self:refreshModes()
		elseif key == K.Return or key == K.Space or key == K.ButtonA then
			self:chooseMode()
		end
	elseif self.screen == "select" then
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
		elseif key == K.Backspace or key == K.ButtonB then
			self:back()
			return
		end
		self:refreshSelect()
	elseif self.screen == "search" then
		if key == K.Backspace or key == K.ButtonB then self:back() end
	end
end

function MenuController:refreshProfile()
	local s = self.status
	if not s.rating then return end
	self.profileRank.Text = (s.rank or "BRONZE") .. " · " .. s.rating .. " pts"
	self.profileStats.Text = string.format("Victoires %d · Défaites %d · Record SURVIE : %d", s.wins or 0, s.losses or 0, s.survivalBest or 0)
	if self.screen == "modes" then self:refreshModes() end
end

function MenuController:flash(text, color)
	self.result.Text, self.result.TextColor3, self.result.Visible = text, color or GOLD, true
	self.resultUntil = os.clock() + 2.5
end

function MenuController:showResult(packet)
	if packet.survival then
		self:flash("SURVIE : " .. packet.survival .. " ADVERSAIRE(S) BATTU(S) · RECORD " .. (packet.best or 0), GOLD)
	elseif packet.queue == "RANKED" then
		local sign = if (packet.delta or 0) >= 0 then "+" else ""
		self:flash((if packet.won then "VICTOIRE" elseif packet.draw then "ÉGALITÉ" else "DÉFAITE") .. " · " .. sign .. (packet.delta or 0)
			.. " PTS · " .. (packet.rank or "") .. " " .. (packet.rating or ""), if packet.won then GOLD else RED)
	else
		self:flash(if packet.won then "VICTOIRE !" elseif packet.draw then "ÉGALITÉ" else "DÉFAITE", if packet.won then GOLD else RED)
	end
	self.resultUntil = os.clock() + 5
end

-- In a match the menu hides; back in the menu it shows again with a slow camera on the stage.
function MenuController:setInMatch(inMatch)
	self.inMatch = inMatch
	self.gui.Enabled = not inMatch
	if not inMatch and self.screen == "search" and self.status.state ~= "queue" then self:show("modes") end
end

-- HUD ◀ MENU: leave the match (back here).
function MenuController:leave()
	self.remote:FireServer({ action = "leave" })
end

function MenuController:frame(dt)
	if self.result.Visible and os.clock() > (self.resultUntil or 0) then self.result.Visible = false end
	if self.inMatch then return end
	if self.screen == "search" then
		local s = self.status
		local waited = math.floor(os.clock() - self.searchStart)
		local queue = if s.queue == "RANKED" then "CLASSÉ" else "NORMAL"
		local count = (s.waiting or {})[s.queue or "NORMAL"] or 0
		self.searchText.Text = string.format("Partie %s · %d:%02d\n%d joueur(s) en recherche sur ce serveur · ton rang : %s (%d pts)",
			queue, waited // 60, waited % 60, count, s.rank or "BRONZE", s.rating or 1000)
		self.searchTitle.TextTransparency = 0.25 + 0.25 * math.sin(os.clock() * 4)
	end
	-- A slow camera on the empty stage behind the menu.
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Scriptable
		local t = os.clock() * 0.08
		local eye = Vector3.new(math.sin(t) * 18, 9, 34 + math.cos(t) * 6)
		camera.CFrame = CFrame.lookAt(eye, Vector3.new(0, 4, 0))
	end
end

-- (bound as a plain function for the HUD button)
function MenuController:bindLeave()
	return function() self:leave() end
end

return MenuController
