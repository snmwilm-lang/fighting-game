--[[
	The hub screen: the players on this server, DÉFIER (challenge one to a 1v1), ACCEPTER /
	REFUSER a challenge, QUITTER LE COMBAT, JOUER (when nobody fights) and INVITER UN AMI
	(Roblox's invite prompt, to bring a friend into this server). The server decides
	everything (src/server/Lobby.luau); this only shows its status and sends requests.
]]
local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")
local UserInputService = game:GetService("UserInputService")
local Theme = require(script.Parent.MenuTheme)

local WHITE = Theme.WHITE
local INK = Color3.fromHex("0B0B0E")
local RED = Theme.RED
local GOLD = Theme.GOLD
local VIP_GOLD = Color3.fromHex("FFD23F") -- (the VIP pass's name colour: StoreConfig VIP.nameColor)
local GREY = Theme.MUTED
local DISPLAY = Enum.Font.Bangers
local UI_FONT = Enum.Font.GothamBlack

local HubController = {}
HubController.__index = HubController

local function new(className, props, parent)
	local i = Instance.new(className)
	for k, v in props do i[k] = v end
	i.Parent = parent
	return i
end

local function stroke(gui, thickness, color)
	local s = new("UIStroke", { Thickness = thickness, Color = color or INK }, gui)
	if gui:IsA("GuiButton") or gui:IsA("Frame") then s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border end
	return s
end

local function button(parent, text, color, props)
	local b = new("TextButton", {
		Text = text, Font = UI_FONT, TextSize = 12, TextColor3 = WHITE, BackgroundColor3 = INK, AutoButtonColor = true,
		Size = UDim2.fromOffset(120, 28),
	}, parent)
	for k, v in props or {} do b[k] = v end
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	Theme.edge(b, color or RED)
	Theme.feedback(b)
	return b
end

function HubController.new(remote)
	local self = setmetatable({ remote = remote, status = {}, seconds = 30, shownChallenge = nil }, HubController)
	local player = Players.LocalPlayer
	-- Above the main menu (DisplayOrder 20) and the mobile controls (10): this window opens
	-- from the menu (PLAYERS, CHALLENGE A FRIEND) and must be drawn and clicked on top of it.
	-- (It was at 8: hidden under the full-screen menu, which also took its clicks.)
	-- (inside the safe area: never under Roblox's top bar or a phone's notch)
	local gui = new("ScreenGui", { Name = "Hub", ResetOnSpawn = false, DisplayOrder = 30, IgnoreGuiInset = false,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
	self.gui = gui
	-- HUB MULTI button, top right, big and gold, during a match (the menu has its own PLAYERS
	-- button); the H key opens / closes the hub too.
	self.toggle = button(gui, "PLAYERS ON THE SERVER (H)", GOLD, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, 164), Size = UDim2.fromOffset(300, 36), TextSize = 15,
		TextColor3 = GOLD, ZIndex = 5, Visible = false,
	})
	-- A dim backdrop under the window: it keeps the clicks off the menu behind, and a click on
	-- it closes the window.
	self.backdrop = new("TextButton", { Name = "Backdrop", Visible = false, Text = "", AutoButtonColor = false, BackgroundColor3 = INK,
		BackgroundTransparency = 0.45, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 1 }, gui)
	self.backdrop.Activated:Connect(function() self:setVisible(false) end)
	-- The window: centred, sized on the screen (phone to PC) within bounds, never taller than
	-- the screen: a fixed header, the players' list (it scrolls) and a fixed footer with the
	-- INVITE button, always on screen.
	local panel = new("Frame", {
		Name = "Players", Visible = false, BackgroundColor3 = Color3.fromHex("15151B"), BackgroundTransparency = 0, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.92, 0.84), ZIndex = 2,
	}, gui)
	new("UISizeConstraint", { MaxSize = Vector2.new(560, 640), MinSize = Vector2.new(280, 260) }, panel)
	Theme.surface(panel, RED)
	new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 10) }, panel)
	self.panel = panel
	local title = new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, -56, 0, 44), Font = DISPLAY, TextScaled = true,
		TextColor3 = WHITE, Text = "PLAYERS ON THE SERVER · CHALLENGES", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 }, panel)
	new("UITextSizeConstraint", { MaxTextSize = 34 }, title)
	-- A big red close button, easy to see and to hit.
	local close = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = RED, Font = UI_FONT, TextSize = 26, Text = "✕", TextColor3 = WHITE, AutoButtonColor = true, ZIndex = 3 }, panel)
	close.BorderSizePixel = 0
	Theme.edge(close, RED)
	Theme.feedback(close)
	close.Activated:Connect(function() self:setVisible(false) end)
	self.stateLabel = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 0, 34),
		Font = UI_FONT, TextSize = 13, TextColor3 = WHITE, TextWrapped = true, Text = "", TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 3 }, panel)
	self.list = new("ScrollingFrame", { Name = "List", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 86),
		Size = UDim2.new(1, 0, 1, -86 - 96), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6,
		ScrollBarImageColor3 = GOLD, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 3 }, panel)
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, self.list)
	local footer = new("Frame", { Name = "Footer", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 90), ZIndex = 3 }, panel)
	local invite = button(footer, "INVITE A FRIEND", GOLD, { Size = UDim2.new(1, 0, 0, 48), TextSize = 20, TextColor3 = GOLD, ZIndex = 4 })
	invite.BackgroundColor3 = RED
	invite.TextColor3 = WHITE
	invite.Activated:Connect(function()
		if not self:invite() then
			invite.Text = "NOT AVAILABLE HERE"
			task.delay(3, function() invite.Text = "INVITE A FRIEND" end)
		end
	end)
	self.inviteButton = invite
	new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 32), Font = UI_FONT,
		TextSize = 11, TextColor3 = GREY, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
		Text = "Your friend joins this server (or from your Roblox profile, \"Join\"), shows up in the list: CHALLENGE, they ACCEPT. H: open / close." },
		footer)
	self.toggle.Activated:Connect(function() self:setVisible(not panel.Visible) end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.H then self:setVisible(not panel.Visible) end
	end)
	-- Incoming challenge banner.
	local banner = new("Frame", {
		Name = "Challenge", Visible = false, BackgroundColor3 = INK, BackgroundTransparency = 0.05, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 150), Size = UDim2.new(0.92, 0, 0, 132), ZIndex = 6,
	}, gui)
	new("UISizeConstraint", { MaxSize = Vector2.new(420, 132) }, banner)
	Theme.surface(banner, GOLD)
	self.bannerText = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, -16, 0, 40), Position = UDim2.fromOffset(8, 6),
		Font = DISPLAY, TextSize = 30, TextColor3 = GOLD, TextScaled = true, Text = "",
	}, banner)
	self.bannerTimer = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, -16, 0, 14), Position = UDim2.fromOffset(8, 44),
		Font = UI_FONT, TextSize = 11, TextColor3 = GREY, Text = "",
	}, banner)
	self.acceptButton = button(banner, "ACCEPT", GOLD, { Position = UDim2.new(0, 12, 0, 76), Size = UDim2.new(0.5, -18, 0, 44) })
	self.declineButton = button(banner, "DECLINE", RED, { Position = UDim2.new(0.5, 6, 0, 76), Size = UDim2.new(0.5, -18, 0, 44) })
	self.acceptButton.Activated:Connect(function()
		if self.shownChallenge then self.remote:FireServer("accept", self.shownChallenge) end
	end)
	self.declineButton.Activated:Connect(function()
		if self.shownChallenge then self.remote:FireServer("decline", self.shownChallenge) end
		banner.Visible = false
	end)
	self.banner = banner
	-- Short notices (a player arrives or leaves), under the HUB button.
	self.notice = new("TextLabel", {
		Name = "Notice", Visible = false, BackgroundColor3 = INK, BackgroundTransparency = 0.1, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -128, 0, 112), Size = UDim2.fromOffset(300, 30),
		Font = UI_FONT, TextSize = 12, TextColor3 = GOLD, TextWrapped = true, Text = "",
	}, gui)
	stroke(self.notice, 1.5, GOLD)
	remote.OnClientEvent:Connect(function(packet)
		if typeof(packet) ~= "table" then return end
		local before = {}
		for _, p in self.status do before[p.id] = p.name end
		local first = not self.received
		self.received = true
		self.status, self.seconds = packet.players or {}, packet.seconds or 30
		-- (a big server sends a short view: arrivals and departures are only announced while
		-- everyone fits in it)
		self.total = packet.total or #self.status
		if self.total > #self.status then first = true end
		local me, arrived = Players.LocalPlayer.UserId, nil
		for _, p in self.status do
			if p.id ~= me and before[p.id] == nil then arrived = p end
			before[p.id] = nil
		end
		local left = next(before) and before[next(before)]
		if arrived and not first then
			self:say(arrived.name .. " joined the server · H to challenge them")
		elseif left and not first then
			self:say(left .. " left the server")
		end
		-- Someone to fight and nobody to fight yet: open the list.
		self:render()
	end)
	remote:FireServer("hello") -- the hub status, now
	task.spawn(function()
		while gui.Parent do
			task.wait(0.25)
			self:tick()
		end
	end)
	return self
end

function HubController:say(text)
	self.notice.Text, self.notice.Visible = text, true
	self.noticeUntil = os.clock() + 5
end

-- Is the local player fighting another player (not the CPU)?
function HubController:fightingHuman()
	local me, mine, others = Players.LocalPlayer.UserId, nil, 0
	for _, p in self.status do
		if p.id == me then mine = p elseif p.slot > 0 then others += 1 end
	end
	return mine ~= nil and mine.slot > 0 and others > 0
end

-- Invite prompt of Roblox (a friend joins this server). Pcall: not available in Studio tests.
function HubController:invite()
	local player = Players.LocalPlayer
	local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
	if ok and can then
		pcall(SocialService.PromptGameInvite, SocialService, player)
		return true
	end
	return false
end

-- Opens / closes the window (built at once, before the server's next status arrives).
function HubController:setVisible(visible)
	Theme.reset(self.panel)
	self.panel.Visible, self.backdrop.Visible = visible, visible
	if visible then self:render() end
end

-- The menu shows its own PLAYERS button: the gold one is only for matches.
function HubController:setInMatch(inMatch)
	self.toggle.Visible = inMatch
	if inMatch then self:setVisible(false) end
end

function HubController:render()
	local me = Players.LocalPlayer.UserId
	local mine = nil
	for _, p in self.status do
		if p.id == me then mine = p end
	end
	self.toggle.Text = "PLAYERS ON THE SERVER (H) · " .. (self.total or #self.status)
	for _, child in self.list:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	local order = 0
	local function line(props)
		order += 1
		props.LayoutOrder = order
		props.BackgroundTransparency = 1
		props.ZIndex = 3
		return new("Frame", props, self.list)
	end
	-- Where the local player is right now.
	local opponent
	for _, p in self.status do
		if p.id ~= me and p.slot > 0 then opponent = p.name end
	end
	self.stateLabel.Text = if mine and mine.slot > 0 then (if opponent then "YOU ARE FIGHTING " .. opponent else "YOU ARE IN A FIGHT")
		else "CHALLENGE a player: they ACCEPT, the 1 vs 1 starts (with the team picked in the menu)"
	for _, p in self.status do
		local row = line({ Size = UDim2.new(1, -8, 0, 52) })
		row.BackgroundTransparency = 0
		row.BackgroundColor3 = Theme.PANEL
		Theme.rule(row, UDim2.new(0, 0, 1, -1), UDim2.new(1, 0, 0, 1), Theme.LINE, 0.4)
		local state = p.where or (if p.slot > 0 then "IN A FIGHT" else "IN THE MENU")
		-- (Game Passes: the VIP / SUPPORTER badges, the VIP's gold name; cosmetic only)
		local badges = if type(p.badges) == "string" and p.badges ~= "" then string.split(p.badges, ",") else {}
		local vip = table.find(badges, "VIP") ~= nil
		local tags = ""
		for _, badge in badges do tags ..= "[" .. badge .. "] " end
		new("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -142, 1, 0), Font = UI_FONT, TextSize = 13, ZIndex = 4,
			TextColor3 = if vip then VIP_GOLD elseif p.id == me then GOLD else WHITE, TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = tags .. (if p.id == me then "YOU · " else "") .. p.name .. "  ·  " .. state,
		}, row)
		-- (the title the player shows: WEEKLY CHAMPION, a challenge title...)
		if p.title and p.title ~= "" then
			row.Size = UDim2.new(1, -8, 0, 62)
			new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 8, 1, -20), Size = UDim2.new(1, -142, 0, 16), Font = UI_FONT,
				TextSize = 11, ZIndex = 4, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
				Text = "👑 " .. p.title }, row)
		end
		if p.id ~= me then
			local challengedMe = p.sent == me
			local sent = mine and mine.sent == p.id
			local label = if challengedMe then "ACCEPT" elseif sent then "CHALLENGE SENT" else "CHALLENGE"
			local b = button(row, label, if challengedMe then GOLD else RED, {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(120, 36), ZIndex = 4,
				AutoButtonColor = not sent, TextColor3 = if sent then GREY else WHITE,
			})
			b.Activated:Connect(function()
				if challengedMe then
					self.remote:FireServer("accept", p.id)
				elseif not sent then
					self.remote:FireServer("challenge", p.id)
				end
			end)
		end
	end
	if #self.status <= 1 then
		local hint = line({ Size = UDim2.new(1, -8, 0, 96) })
		new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = UI_FONT, TextSize = 12, ZIndex = 4,
			TextColor3 = GREY, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
			Text = "You are alone on this server. To play with a friend, they must be on the SAME server: "
				.. "INVITE A FRIEND (they arrive here), or your friend joins you from your Roblox profile (\"Join\"). "
				.. "They then show up in this list: CHALLENGE, they ACCEPT, the 1 vs 1 starts. "
				.. "In Roblox Studio: Test tab › Clients and Servers, 2 players." }, hint)
	end
	-- Incoming challenge: the most recent one is shown in the banner.
	local from = mine and mine.from and mine.from[#mine.from]
	if from ~= self.shownChallenge then
		self.shownChallenge = from
		self.challengeAt = os.clock()
	end
	if from then
		local name = "?"
		for _, p in self.status do
			if p.id == from then name = p.name end
		end
		self.bannerText.Text = name .. " CHALLENGES YOU TO A 1 VS 1!"
		self.banner.Visible = true
	else
		self.banner.Visible = false
	end
end

function HubController:tick()
	if self.notice.Visible and os.clock() > (self.noticeUntil or 0) then self.notice.Visible = false end
	if self.banner.Visible and self.challengeAt then
		local left = math.max(0, math.ceil(self.seconds - (os.clock() - self.challengeAt)))
		self.bannerTimer.Text = "The challenge expires in " .. left .. " s · the fight starts as soon as you accept"
	end
end

return HubController
