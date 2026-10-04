--[[
	The hub screen: the players on this server, DÉFIER (challenge one to a 1v1), ACCEPTER /
	REFUSER a challenge, QUITTER LE COMBAT, JOUER (when nobody fights) and INVITER UN AMI
	(Roblox's invite prompt, to bring a friend into this server). The server decides
	everything (src/server/Lobby.luau); this only shows its status and sends requests.
]]
local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")
local UserInputService = game:GetService("UserInputService")

local WHITE = Color3.fromHex("F5F5F7")
local INK = Color3.fromHex("0B0B0E")
local RED = Color3.fromHex("E0102B")
local GOLD = Color3.fromHex("FFD23F")
local GREY = Color3.fromHex("8A8A94")
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
	stroke(b, 1.5, color or RED)
	return b
end

function HubController.new(remote)
	local self = setmetatable({ remote = remote, status = {}, seconds = 30, shownChallenge = nil }, HubController)
	local player = Players.LocalPlayer
	local gui = new("ScreenGui", { Name = "Hub", ResetOnSpawn = false, DisplayOrder = 8 }, player:WaitForChild("PlayerGui"))
	-- HUB MULTI button, top right, big and gold; the H key opens / closes the hub too.
	self.toggle = button(gui, "JOUEURS DU SERVEUR (H)", GOLD, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, 128), Size = UDim2.fromOffset(300, 36), TextSize = 15,
		TextColor3 = GOLD, ZIndex = 5,
	})
	-- The hub itself: a lobby panel in the middle of the screen. It opens on arrival.
	local panel = new("Frame", {
		Name = "Players", Visible = false, BackgroundColor3 = Color3.fromHex("15151B"), BackgroundTransparency = 0, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(520, 0),
		AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 10,
	}, gui)
	new("UICorner", { CornerRadius = UDim.new(0, 10) }, panel)
	stroke(panel, 3, GOLD)
	new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 10) }, panel)
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, panel)
	self.panel = panel
	self.toggle.Activated:Connect(function() panel.Visible = not panel.Visible end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.H then panel.Visible = not panel.Visible end
	end)
	-- Incoming challenge banner.
	local banner = new("Frame", {
		Name = "Challenge", Visible = false, BackgroundColor3 = INK, BackgroundTransparency = 0.05, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 150), Size = UDim2.fromOffset(420, 96),
	}, gui)
	stroke(banner, 3, GOLD)
	self.bannerText = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, -16, 0, 40), Position = UDim2.fromOffset(8, 6),
		Font = DISPLAY, TextSize = 30, TextColor3 = GOLD, TextScaled = true, Text = "",
	}, banner)
	self.bannerTimer = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, -16, 0, 14), Position = UDim2.fromOffset(8, 44),
		Font = UI_FONT, TextSize = 11, TextColor3 = GREY, Text = "",
	}, banner)
	self.acceptButton = button(banner, "ACCEPTER", GOLD, { Position = UDim2.new(0.5, -128, 0, 60), Size = UDim2.fromOffset(120, 28) })
	self.declineButton = button(banner, "REFUSER", RED, { Position = UDim2.new(0.5, 8, 0, 60), Size = UDim2.fromOffset(120, 28) })
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
			self:say(arrived.name .. " a rejoint le serveur · H pour le défier")
		elseif left and not first then
			self:say(left .. " a quitté le serveur")
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

function HubController:render()
	local me = Players.LocalPlayer.UserId
	local mine, fighting = nil, 0
	for _, p in self.status do
		if p.id == me then mine = p end
		if p.slot > 0 then fighting += 1 end
	end
	self.toggle.Text = "JOUEURS DU SERVEUR (H) · " .. (self.total or #self.status)
	for _, child in self.panel:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	local order = 0
	local function line(props)
		order += 1
		props.LayoutOrder = order
		props.BackgroundTransparency = 1
		return new("Frame", props, self.panel)
	end
	local title = line({ Size = UDim2.new(1, 0, 0, 44) })
	new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, -56, 1, 0), Font = DISPLAY, TextSize = 36,
		TextColor3 = GOLD, Text = "JOUEURS DU SERVEUR · DÉFIS", TextXAlignment = Enum.TextXAlignment.Left }, title)
	-- A big red close button, easy to see and to hit.
	local close = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = RED, Font = UI_FONT, TextSize = 26, Text = "✕", TextColor3 = WHITE, AutoButtonColor = true }, title)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, close)
	stroke(close, 2, WHITE)
	close.Activated:Connect(function() self.panel.Visible = false end)
	-- Where the local player is right now.
	local opponent
	for _, p in self.status do
		if p.id ~= me and p.slot > 0 then opponent = p.name end
	end
	local where = if mine and mine.slot > 0 then (if opponent then "TU COMBATS " .. opponent else "TU ES EN COMBAT")
		else "DÉFIE un joueur : il ACCEPTE, le 1 contre 1 commence (avec l'équipe choisie au menu)"
	local stateLine = line({ Size = UDim2.new(1, 0, 0, 20) })
	new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = UI_FONT, TextSize = 13,
		TextColor3 = WHITE, Text = where, TextXAlignment = Enum.TextXAlignment.Left }, stateLine)
	for _, p in self.status do
		local row = line({ Size = UDim2.new(1, 0, 0, 30) })
		local state = p.where or (if p.slot > 0 then "EN COMBAT" else "AU MENU")
		new("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.new(1, -130, 1, 0), Font = UI_FONT, TextSize = 13,
			TextColor3 = if p.id == me then GOLD else WHITE, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
			Text = (if p.id == me then "VOUS · " else "") .. p.name .. "  ·  " .. state,
		}, row)
		if p.id ~= me then
			local challengedMe = p.sent == me
			local sent = mine and mine.sent == p.id
			local label = if challengedMe then "ACCEPTER" elseif sent then "DÉFI ENVOYÉ" else "DÉFIER"
			local b = button(row, label, if challengedMe then GOLD else RED, {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(120, 26),
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
		local hint = line({ Size = UDim2.new(1, 0, 0, 78) })
		new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = UI_FONT, TextSize = 12,
			TextColor3 = GREY, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
			Text = "Tu es seul sur ce serveur. Pour jouer avec un ami, il doit être sur le MÊME serveur : "
				.. "INVITER UN AMI (il arrive ici), ou ton ami te rejoint depuis ton profil Roblox (« Rejoindre »). "
				.. "Il apparaît alors dans cette liste : DÉFIER, il ACCEPTE, le 1 contre 1 commence. "
				.. "Dans Roblox Studio : onglet Test › Clients et serveurs, 2 joueurs." }, hint)
	end
	local actions = line({ Size = UDim2.new(1, 0, 0, 28) })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }, actions)
	local invite = button(actions, "INVITER UN AMI", GOLD, { Size = UDim2.fromOffset(140, 28) })
	invite.Activated:Connect(function()
		if not self:invite() then invite.Text = "INDISPONIBLE ICI" end
	end)
	local keys = line({ Size = UDim2.new(1, 0, 0, 16) })
	new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = UI_FONT, TextSize = 10, TextColor3 = GREY,
		Text = "H : ouvrir / fermer cette fenêtre", TextXAlignment = Enum.TextXAlignment.Left }, keys)
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
		self.bannerText.Text = name .. " TE DÉFIE EN 1 CONTRE 1 !"
		self.banner.Visible = true
	else
		self.banner.Visible = false
	end
end

function HubController:tick()
	if self.notice.Visible and os.clock() > (self.noticeUntil or 0) then self.notice.Visible = false end
	if self.banner.Visible and self.challengeAt then
		local left = math.max(0, math.ceil(self.seconds - (os.clock() - self.challengeAt)))
		self.bannerTimer.Text = "Le défi expire dans " .. left .. " s · le combat commence dès que tu acceptes"
	end
end

return HubController
