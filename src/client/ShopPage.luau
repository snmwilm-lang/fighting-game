--[[
	The SHOP page of the main menu (MenuController builds it, opened from the SHOP entry):
	four tabs, FEATURED, COSMETICS (skins, titles, emotes, auras, victory animations), SHOP
	(coins and styles for Robux) and GAME PASSES. A grid of cards on the right (price and
	status: OWNED, EQUIPPED, locked, SOON), the selected card in big on the left (3D for a
	style, the title's plate, the emote's bubble, the aura's colours, a pass's perks) with its
	buttons: BUY (coins, after a confirmation), R$ (Roblox's own purchase window), EQUIP /
	UNEQUIP.

	Everything here only DRAWS and ASKS: the server checks every price, ownership and id
	(Store.luau), starts the Robux purchases itself and grants them (ProcessReceipt). An id
	still 0 in StoreConfig shows SOON and cannot be bought.
	Mouse, touch (the page follows the screen's width) and gamepad (every card and button is a
	selectable button).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local StoreConfig = require(Shared.StoreConfig)
local Store = require(Shared.Store)
local CharacterData = require(Shared.CharacterData)
local Taunts = require(Shared.Taunts)
local Quests = require(Shared.Quests)
local Economy = require(Shared.Economy)
local MoveData = require(Shared.MoveData)
local Theme = require(script.Parent.MenuTheme)
local CurrencyIcons = require(script.Parent.CurrencyIcons)

local idx = Store.index(StoreConfig)
local new, text = Theme.new, Theme.text
local WHITE, MUTED, GOLD, RED, INK = Theme.WHITE, Theme.MUTED, Theme.GOLD, Theme.RED, Theme.INK
local GREEN = Color3.fromHex("5BE38A")
local DISPLAY, UI_FONT, BODY_FONT = Theme.DISPLAY, Theme.UI, Theme.BODY

local TABS = { { "featured", "FEATURED" }, { "cosmetics", "COSMETICS" }, { "shop", "SHOP" }, { "passes", "GAME PASSES" } }
local KIND_NAMES = { SKIN = "SKINS", TITLE = "TITLES", EMOTE = "EMOTES", VFX = "AURAS", VICTORY = "VICTORY" }
local TAB_NOTES = {
	featured = "THE BEST OF THE SHOP · COSMETICS AND COINS ONLY: NO ADVANTAGE IN A FIGHT",
	shop = "COINS AND STYLES FOR ROBUX · ROBLOX CONFIRMS EVERY PURCHASE",
	passes = "PERMANENT · RESTORED EVERY TIME YOU JOIN · BONUSES ON FIGHT COINS ONLY (AT MOST x2.25)",
}
local KIND_INFO = {
	TITLE = "A title shown over your fighter and in the lobby (SETTINGS › TITLE too).",
	EMOTE = "A taunt for your wheel (TAUNTS page): EQUIP puts it on the wheel.",
	VFX = "Recolours your fighter's aura in fights, seen by everyone. Cosmetic only.",
	VICTORY = "Victory animations are being made: they come in a later update.",
}

local ShopPage = {}
ShopPage.__index = ShopPage

local function hex(c) return Color3.fromHex(c) end

-- ===================================================================== build
function ShopPage.new(menu, root)
	local self = setmetatable({ menu = menu, tab = "featured", kind = "SKIN", selected = nil, motes = {} }, ShopPage)
	-- (as wide as the screen allows right of the navigation: phones get three columns)
	local page = new("Frame", { Name = "SHOP", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -28, 0, 122),
		Size = UDim2.new(1, -424, 0, 548), BackgroundColor3 = Theme.PANEL, BackgroundTransparency = 0.04, BorderSizePixel = 0 }, root)
	Theme.surface(page, RED)
	Theme.heading(page, "SHOP", RED)
	self.page = page
	-- a cross to close the shop (Wilhem: « une croix pour fermer le shop »), back to the menu
	local close = Theme.button(page, { Name = "ShopClose", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 20),
		Size = UDim2.fromOffset(40, 40), BackgroundColor3 = RED, Text = "" }, GOLD)
	Theme.cross(close, 18)
	close.Activated:Connect(function() menu:open("home") end)
	-- the balance (top right, left of the cross)
	local wallet = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -70, 0, 20), Size = UDim2.fromOffset(150, 40),
		BackgroundColor3 = INK, BorderSizePixel = 0 }, page)
	Theme.edge(wallet, GOLD)
	CurrencyIcons.make("coins", wallet, 26, UDim2.fromOffset(8, 7))
	self.balance = text(wallet, { Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -48, 1, 0), Font = UI_FONT, TextSize = 18,
		Text = "0", TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Right })
	self.bonus = text(page, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -230, 0, 30), Size = UDim2.fromOffset(220, 20),
		Font = UI_FONT, TextSize = 12, Text = "", TextColor3 = GREEN, TextXAlignment = Enum.TextXAlignment.Right })
	-- the four tabs
	self.tabButtons = {}
	local tabRow = new("Frame", { Position = UDim2.fromOffset(22, 80), Size = UDim2.new(1, -44, 0, 36), BackgroundTransparency = 1 }, page)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, tabRow)
	for i, tab in TABS do
		local b = Theme.button(tabRow, { Name = "ShopTab_" .. tab[1], LayoutOrder = i, Size = UDim2.new(0.25, -5, 1, 0), Font = DISPLAY,
			TextSize = 22, Text = tab[2] }, RED)
		b.Activated:Connect(function() self:setTab(tab[1]) end)
		self.tabButtons[tab[1]] = b
	end
	-- the kinds (COSMETICS) or the tab's note
	self.kindRow = new("Frame", { Position = UDim2.fromOffset(22, 124), Size = UDim2.new(1, -44, 0, 28), BackgroundTransparency = 1 }, page)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, self.kindRow)
	self.kindButtons = {}
	for i, kind in StoreConfig.KINDS do
		local b = Theme.button(self.kindRow, { Name = "ShopKind_" .. kind, LayoutOrder = i, Size = UDim2.new(0.2, -5, 1, 0), Font = UI_FONT,
			TextSize = 12, Text = KIND_NAMES[kind] }, GOLD)
		b.Activated:Connect(function()
			self.kind = kind
			self.selected = nil
			self:refresh()
		end)
		self.kindButtons[kind] = b
	end
	self.note = text(page, { Position = UDim2.fromOffset(22, 124), Size = UDim2.new(1, -44, 0, 28), Font = BODY_FONT, TextSize = 12,
		Text = "", TextColor3 = MUTED, TextWrapped = true })
	self:buildPanel()
	-- the grid of cards
	self.grid = new("ScrollingFrame", { Name = "ShopGrid", Position = UDim2.fromOffset(318, 160), Size = UDim2.new(1, -340, 1, -174),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5, ScrollBarImageColor3 = RED, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, Selectable = false }, page)
	new("UIGridLayout", { CellSize = UDim2.fromOffset(162, 134), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, self.grid)
	new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2) }, self.grid)
	return self
end

-- The selected item in big (left), its status and its buttons.
function ShopPage:buildPanel()
	local panel = new("Frame", { Name = "ShopPreview", Position = UDim2.fromOffset(22, 160), Size = UDim2.new(0, 282, 1, -174),
		BackgroundColor3 = INK, BackgroundTransparency = 0.1, BorderSizePixel = 0 }, self.page)
	Theme.edge(panel)
	self.panel = panel
	self.panelScale = new("UIScale", { Scale = 1 }, panel)
	local art = new("Frame", { Name = "Art", Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 172), BackgroundColor3 = INK,
		BorderSizePixel = 0, ClipsDescendants = true }, panel)
	self.artWash = new("UIGradient", { Rotation = 90, Color = ColorSequence.new(hex("2A0A12"), INK) }, art)
	self.art = art
	-- (behind the body: the style's kanji in big, a lit floor; a tier badge in the corner)
	self.watermark = text(art, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromScale(1, 1.1),
		Font = UI_FONT, TextScaled = true, Text = "", TextColor3 = WHITE, TextTransparency = 0.88, TextXAlignment = Enum.TextXAlignment.Center })
	self.floor = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.93), Size = UDim2.new(0.8, 0, 0, 26),
		BackgroundColor3 = WHITE, BackgroundTransparency = 0.55, BorderSizePixel = 0 }, art)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, self.floor)
	self.floorGradient = new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.1), NumberSequenceKeypoint.new(1, 1) }) }, self.floor)
	self.tierBadge = text(art, { Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(92, 18), BackgroundTransparency = 0,
		BackgroundColor3 = INK, Font = UI_FONT, TextSize = 10, Text = "", TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 4 })
	self.tierEdge = Theme.edge(self.tierBadge, GOLD)
	-- (a style: its body in 3D, the FIGHTERS page's preview)
	local holder = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, art)
	self.view = self.menu:styleViewport(holder)
	self.viewHolder = holder
	-- (anything else: a big line, a small one)
	self.artBig = text(art, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.new(1, -20, 0, 70),
		Font = DISPLAY, TextScaled = true, Text = "", TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center })
	new("UITextSizeConstraint", { MaxTextSize = 44 }, self.artBig)
	self.artSmall = text(art, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.45, 40), Size = UDim2.new(1, -20, 0, 20),
		Font = UI_FONT, TextSize = 13, Text = "", TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Center })
	self.artIcon = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromOffset(64, 64),
		BackgroundTransparency = 1 }, art)
	CurrencyIcons.make("coins", self.artIcon, 64, UDim2.fromOffset(0, 0))
	-- (an aura: motes rising in its two colours)
	for i = 1, 14 do
		local mote = new("Frame", { Size = UDim2.fromOffset(8, 8), AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, Visible = false }, art)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, mote)
		self.motes[i] = { frame = mote, x = (i * 0.137) % 1, t = (i * 0.29) % 1, speed = 0.25 + (i % 5) * 0.06 }
	end
	self.name = text(panel, { Position = UDim2.fromOffset(12, 186), Size = UDim2.new(1, -24, 0, 30), Font = DISPLAY, TextScaled = true,
		Text = "", TextColor3 = WHITE })
	new("UITextSizeConstraint", { MaxTextSize = 28 }, self.name)
	self.info = text(panel, { Position = UDim2.fromOffset(12, 218), Size = UDim2.new(1, -24, 1, -318), Font = BODY_FONT, TextSize = 12,
		Text = "", TextColor3 = MUTED, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
	self.state = text(panel, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -60), Size = UDim2.new(1, -24, 0, 34),
		Font = UI_FONT, TextSize = 13, Text = "", TextColor3 = GOLD, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Bottom })
	self.primary = Theme.button(panel, { Name = "ShopPrimary", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -10),
		Size = UDim2.new(0.5, -14, 0, 44), BackgroundColor3 = RED, Font = DISPLAY, TextSize = 22, Text = "" }, GOLD)
	self.robux = Theme.button(panel, { Name = "ShopRobux", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -10),
		Size = UDim2.new(0.5, -14, 0, 44), BackgroundColor3 = hex("0E3A22"), Font = DISPLAY, TextSize = 22, Text = "" }, GREEN)
	self.primary.Activated:Connect(function() if self.primaryAction then self.primaryAction() end end)
	self.robux.Activated:Connect(function() if self.robuxAction then self.robuxAction() end end)
end

-- ===================================================================== entries
-- What a tab shows: { type = "pass" | "product" | "skin" | "item", key, data }.
local function skinEntry(name) return { type = "skin", key = name, data = CharacterData.SHOP[name] } end
function ShopPage:entries()
	local out = {}
	if self.tab == "featured" then
		for _, f in StoreConfig.FEATURED do
			if f.kind == "pass" then table.insert(out, { type = "pass", key = f.key, data = idx.pass[f.key] })
			elseif f.kind == "product" then
				local p = idx.product[f.key]
				table.insert(out, if p.style then skinEntry(p.style) else { type = "product", key = f.key, data = p })
			else table.insert(out, { type = "item", key = f.key, data = idx.item[f.key] }) end
		end
	elseif self.tab == "passes" then
		for _, p in StoreConfig.PASSES do table.insert(out, { type = "pass", key = p.key, data = p }) end
	elseif self.tab == "shop" then
		for _, p in StoreConfig.PRODUCTS do
			table.insert(out, if p.style then skinEntry(p.style) else { type = "product", key = p.key, data = p })
		end
	elseif self.kind == "SKIN" then
		-- (every shop style, fighter by fighter, in the roster's order)
		local names, order = {}, {}
		for i, kit in MoveData.KitOrder do order[kit] = i end
		for name in CharacterData.SHOP do table.insert(names, name) end
		table.sort(names, function(a, b)
			local ka, kb = order[CharacterData.SHOP[a].kit] or 99, order[CharacterData.SHOP[b].kit] or 99
			if ka ~= kb then return ka < kb end
			return a < b
		end)
		for _, name in names do table.insert(out, skinEntry(name)) end
	else
		for _, item in StoreConfig.ITEMS do
			if item.kind == self.kind then table.insert(out, { type = "item", key = item.id, data = item }) end
		end
	end
	return out
end

-- The status of an entry: its name, colour, state line, info, the two buttons.
function ShopPage:describe(e)
	local s = self.menu.status or {}
	local d = { name = "", color = RED, state = "", stateColor = MUTED, info = "" }
	local coins = tonumber(s.coins) or 0
	local function robux(kind, entry)
		if entry.id <= 0 then
			d.robux = { text = "SOON", off = true, run = function() self.menu:flash("COMING SOON · NOT ON SALE YET", MUTED) end }
		else
			d.robux = { text = "R$ " .. entry.robux, run = function()
				if not s.paid then
					self.menu:flash("PURCHASES NOT AVAILABLE YET · YOUR SAVE IS LOADING", RED)
					return
				end
				self.menu.remote:FireServer({ action = "robux", kind = kind, key = entry.key })
				self.menu:flash("ROBLOX PURCHASE WINDOW…", GREEN)
			end }
		end
	end
	if e.type == "pass" then
		local p = e.data
		d.name, d.color = p.name, hex(p.color)
		d.info = "• " .. table.concat(p.perks, "\n• ") .. "\nPermanent. No advantage in a fight."
		if Store.hasPass(s, p.key) then
			d.state, d.stateColor = "✓ OWNED · ACTIVE", GREEN
		else
			d.state = if p.id > 0 then "R$ " .. p.robux else "SOON · R$ " .. p.robux
			robux("pass", p)
		end
	elseif e.type == "product" then
		local p = e.data
		d.name, d.color = p.name, GOLD
		d.tag = p.tag
		d.info = "+" .. p.coins .. " coins at once. Pass bonuses never apply to Robux purchases."
		d.state = if p.id > 0 then "R$ " .. p.robux else "SOON · R$ " .. p.robux
		robux("product", p)
	elseif e.type == "skin" then
		local name, item = e.key, e.data
		local style = CharacterData.Skins[name]
		local owned = s.dev == true or ((s.ownedSkins or {})[name] == true)
		local equipped = (s.equipped or {})[item.kit] == name
		d.name, d.color = name, hex(style.Energy)
		d.info = "A style for " .. item.kit .. " · " .. item.theme .. ". Cosmetic only. Also in FIGHTERS."
		local product = idx.styleProduct[name]
		if equipped then
			d.state, d.stateColor = "✓ EQUIPPED", GREEN
			d.primary = { text = "UNEQUIP", run = function()
				self.menu.remote:FireServer({ action = "equip", skin = CharacterData.defaultStyle(item.kit, nil) })
			end }
		elseif owned then
			d.state, d.stateColor = "✓ OWNED", GOLD
			d.primary = { text = "EQUIP", run = function() self.menu.remote:FireServer({ action = "equip", skin = name }) end }
		elseif item.quest then
			local quest = Quests.BY_REWARD[name]
			d.state, d.stateColor = "QUEST · " .. (if quest then quest.how else ""), Theme.VIOLET
			d.primary = { text = "QUEST", off = true, run = function() self.menu:flash(d.state, Theme.VIOLET) end }
		else
			local price = Economy.skinPrice(item.kit)
			d.state = "🔒 " .. price .. " COINS · " .. Economy.tierOf(item.kit).name
			d.primary = { text = "BUY " .. price, coins = true, run = function() self.menu:askStyle(name) end }
			if product then robux("product", product) end
		end
	else
		local item = e.data
		d.name = item.name
		d.color = if item.colors then hex(item.colors[2]) elseif item.pass then hex(idx.pass[item.pass].color) else GOLD
		d.info = KIND_INFO[item.kind] or ""
		local owned = Store.ownsItem(idx, s, item.id)
		local equipped = false
		if item.kind == "TITLE" then equipped = s.title == item.name
		elseif item.kind == "EMOTE" then equipped = table.find(self.menu:currentTaunts(), item.taunt) ~= nil
		elseif item.kind == "VFX" then equipped = (s.cosmetics or {}).VFX == item.id end
		if item.soon then
			d.state, d.stateColor = "COMING SOON", MUTED
			d.primary = { text = "SOON", off = true, run = function() self.menu:flash("COMING SOON · IN A LATER UPDATE", MUTED) end }
		elseif owned and equipped then
			d.state, d.stateColor = "✓ EQUIPPED", GREEN
			d.primary = { text = "UNEQUIP", run = function() self:wear(item, false) end }
		elseif owned then
			d.state, d.stateColor = "✓ OWNED", GOLD
			d.primary = { text = "EQUIP", run = function() self:wear(item, true) end }
		elseif item.pass then
			d.state, d.stateColor = "WITH THE " .. idx.pass[item.pass].name .. " PASS", hex(idx.pass[item.pass].color)
			d.primary = { text = "SEE THE PASS", run = function()
				self.tab, self.selected = "passes", "pass:" .. item.pass
				self:refresh()
			end }
		else
			d.state = "🔒 " .. item.coins .. " COINS"
			d.primary = { text = "BUY " .. item.coins, coins = true, run = function()
				if coins < item.coins then
					self.menu:flash(string.format("NOT ENOUGH COINS · %s COSTS %d (YOU HAVE %d)", item.name, item.coins, coins), RED)
					return
				end
				self.menu:confirm(string.format("BUY %s FOR %d COINS?\nYou have %d coins.", item.name, item.coins, coins), "BUY", function()
					self.menu.remote:FireServer({ action = "buyItem", id = item.id })
				end)
			end }
		end
	end
	return d
end

-- EQUIP / UNEQUIP a cosmetic (the server checks it is owned).
function ShopPage:wear(item, on)
	local remote = self.menu.remote
	if item.kind == "TITLE" then
		remote:FireServer({ action = "title", title = if on then item.name else "" })
	elseif item.kind == "VFX" then
		remote:FireServer({ action = "cosmetic", kind = "VFX", id = if on then item.id else "" })
	elseif item.kind == "EMOTE" then
		local wheel = self.menu:currentTaunts()
		local at = table.find(wheel, item.taunt)
		if on and not at then wheel[Taunts.SLOTS] = item.taunt
		elseif not on and at then table.remove(wheel, at) end
		self.menu.tauntWheel = wheel
		remote:FireServer({ action = "taunts", taunts = wheel })
		self:refresh()
	end
end

-- ===================================================================== drawing
function ShopPage:setTab(tab)
	if self.tab ~= tab then self.selected = nil end
	self.tab = tab
	self:refresh()
end

local function keyOf(e) return e.type .. ":" .. e.key end

-- The small picture of a card (and the colours of its edge).
local function cardArt(card, e, d)
	local art = new("Frame", { Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, 64), BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0, ClipsDescendants = true }, card)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(d.color:Lerp(INK, 0.45), INK) }, art)
	if e.type == "skin" then
		local style = CharacterData.Skins[e.key]
		for k, key in { "Vest", "VestTrim", "Sash", "Energy" } do
			new("Frame", { Position = UDim2.new(0, 10 + (k - 1) * 16, 0, 10), Size = UDim2.fromOffset(12, 44), BackgroundColor3 = hex(style[key]),
				BorderSizePixel = 0 }, art)
		end
		text(art, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(60, 56), Font = UI_FONT,
			TextSize = 40, Text = style.Kanji or "", TextColor3 = hex(style.Energy), TextTransparency = 0.25,
			TextXAlignment = Enum.TextXAlignment.Center })
		-- (whose style it is, in a corner)
		local tag = text(art, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 4, 1, -3), Size = UDim2.fromOffset(74, 14),
			BackgroundTransparency = 0.15, BackgroundColor3 = INK, Font = UI_FONT, TextSize = 9, Text = e.data.kit, TextColor3 = WHITE,
			TextXAlignment = Enum.TextXAlignment.Center })
		new("UICorner", { CornerRadius = UDim.new(0, 3) }, tag)
	elseif e.type == "product" then
		CurrencyIcons.make("coins", art, 40, UDim2.fromOffset(10, 12))
		text(art, { Position = UDim2.fromOffset(56, 0), Size = UDim2.new(1, -60, 1, 0), Font = DISPLAY, TextSize = 28,
			Text = "+" .. e.data.coins, TextColor3 = GOLD })
	elseif e.type == "pass" then
		text(art, { Size = UDim2.fromScale(1, 1), Font = DISPLAY, TextScaled = true, Text = e.data.name, TextColor3 = hex(e.data.color),
			TextXAlignment = Enum.TextXAlignment.Center })
	else
		local item = e.data
		if item.kind == "VFX" then
			for k, c in item.colors do
				local dot = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, (k - 1.5) * 34, 0.5, 0),
					Size = UDim2.fromOffset(36, 36), BackgroundColor3 = hex(c), BorderSizePixel = 0 }, art)
				new("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
			end
		elseif item.kind == "EMOTE" then
			local bubble = text(art, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -16, 0, 34),
				BackgroundTransparency = 0, BackgroundColor3 = WHITE, Font = DISPLAY, TextScaled = true, Text = item.name, TextColor3 = INK,
				TextXAlignment = Enum.TextXAlignment.Center })
			new("UICorner", { CornerRadius = UDim.new(0, 10) }, bubble)
		elseif item.kind == "VICTORY" then
			text(art, { Size = UDim2.fromScale(1, 1), Font = UI_FONT, TextSize = 34, Text = "🏆", TextColor3 = MUTED, TextTransparency = 0.4,
				TextXAlignment = Enum.TextXAlignment.Center })
		else
			text(art, { Size = UDim2.new(1, -8, 1, 0), Position = UDim2.fromOffset(4, 0), Font = DISPLAY, TextScaled = true,
				Text = "« " .. item.name .. " »", TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Center })
		end
	end
end

function ShopPage:refresh()
	if not self.page.Visible and self.drawn then return end
	self.drawn = true
	local s = self.menu.status or {}
	self.balance.Text = tostring(s.coins or 0)
	local m = tonumber(s.coinMultiplier) or 1
	self.bonus.Text = if m > 1 then string.format("FIGHT COINS x%.2f", m) else ""
	for name, b in self.tabButtons do
		local on = name == self.tab
		b.BackgroundColor3 = if on then RED else Theme.PANEL
		b.TextColor3 = if on then WHITE else MUTED
	end
	local cosmetics = self.tab == "cosmetics"
	self.kindRow.Visible = cosmetics
	self.note.Visible = not cosmetics
	self.note.Text = TAB_NOTES[self.tab] or ""
	for kind, b in self.kindButtons do
		b.TextColor3 = if kind == self.kind then GOLD else MUTED
		b.BackgroundColor3 = if kind == self.kind then Theme.RAISED else Theme.PANEL
	end
	local entries = self:entries()
	local chosen = nil
	for _, e in entries do
		if keyOf(e) == self.selected then chosen = e end
	end
	chosen = chosen or entries[1]
	self.selected = chosen and keyOf(chosen)
	-- The grid is rebuilt only when what it lists changed (tab, kind, the status after a
	-- purchase); a click on a card only moves the highlight, and the scroll stays where it was
	-- (it went back to the top on every click).
	local list = self.tab .. "/" .. self.kind .. "/" .. tostring(self.statusSerial or 0)
	if list ~= self.listKey then
		local sameTab = self.listKey and self.listKey:match("^[^/]*/[^/]*") == list:match("^[^/]*/[^/]*")
		local scroll = self.grid.CanvasPosition
		self.listKey = list
		self:buildGrid(entries, not sameTab)
		if sameTab then task.defer(function() self.grid.CanvasPosition = scroll end) else self.grid.CanvasPosition = Vector2.zero end
	end
	self:highlight()
	self:showSelected(chosen)
end

-- Every card of the grid (cards slide in one after the other when a tab opens).
function ShopPage:buildGrid(entries, animate)
	for _, child in self.grid:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	self.cards = {}
	for i, e in entries do
		local d = self:describe(e)
		local card = Theme.button(self.grid, { Name = "ShopCard_" .. e.key, LayoutOrder = i, Text = "", BackgroundColor3 = Theme.PANEL },
			d.color)
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 160)) }, card)
		-- (a bar of the item's colour along the top)
		new("Frame", { Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = d.color, BorderSizePixel = 0, ZIndex = card.ZIndex + 1 }, card)
		cardArt(card, e, d)
		text(card, { Position = UDim2.fromOffset(8, 72), Size = UDim2.new(1, -16, 0, 20), Font = UI_FONT, TextSize = 12, Text = d.name,
			TextColor3 = WHITE, TextTruncate = Enum.TextTruncate.AtEnd })
		text(card, { Position = UDim2.fromOffset(8, 94), Size = UDim2.new(1, -16, 0, 34), Font = UI_FONT, TextSize = 11, Text = d.state,
			TextColor3 = d.stateColor, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
		if d.tag then
			local tag = text(card, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 8), Size = UDim2.fromOffset(84, 18),
				BackgroundTransparency = 0, BackgroundColor3 = RED, Font = UI_FONT, TextSize = 10, Text = d.tag, TextColor3 = WHITE,
				TextXAlignment = Enum.TextXAlignment.Center, ZIndex = card.ZIndex + 2 })
			new("UICorner", { CornerRadius = UDim.new(0, 4) }, tag)
		end
		-- (owned or worn: a check in the corner)
		if d.stateColor == GREEN or d.stateColor == GOLD and d.state:sub(1, 3) == "✓" then
			local check = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 8), Size = UDim2.fromOffset(20, 20),
				BackgroundColor3 = d.stateColor, BorderSizePixel = 0, ZIndex = card.ZIndex + 2 }, card)
			new("UICorner", { CornerRadius = UDim.new(1, 0) }, check)
			text(check, { Size = UDim2.fromScale(1, 1), Font = UI_FONT, TextSize = 13, Text = "✓", TextColor3 = INK,
				TextXAlignment = Enum.TextXAlignment.Center, ZIndex = check.ZIndex + 1 })
		end
		local scale = card:FindFirstChild("ButtonScale")
		if animate and scale and not self.reduced then
			scale.Scale = 0.94
			TweenService:Create(scale, TweenInfo.new(0.16 + math.min(i, 12) * 0.015, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
		local key = keyOf(e)
		card.Activated:Connect(function()
			if self.selected ~= key then
				self.selected = key
				self:refresh()
			end
		end)
		self.cards[key] = { card = card, edge = card:FindFirstChildOfClass("UIStroke"), color = d.color }
	end
end

-- The selected card: a gold edge, a little raised; the others back to normal.
function ShopPage:highlight()
	for key, c in self.cards or {} do
		local on = key == self.selected
		if c.edge then
			c.edge.Color = if on then GOLD else Theme.LINE
			c.edge.Thickness = if on then 2 else 1
		end
		c.card.BackgroundColor3 = if on then Theme.RAISED else Theme.PANEL
	end
end

-- The big preview of the selected entry.
function ShopPage:showSelected(e)
	local panelVisible = e ~= nil
	self.panel.Visible = panelVisible
	if not e then return end
	local d = self:describe(e)
	if self.shown ~= self.selected then
		self.shown = self.selected
		self.panelScale.Scale = 0.96
		TweenService:Create(self.panelScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	self.name.Text = d.name
	self.info.Text = d.info
	self.state.Text, self.state.TextColor3 = d.state, d.stateColor
	self.artWash.Color = ColorSequence.new(d.color:Lerp(INK, 0.55), INK)
	local style = e.type == "skin" and CharacterData.Skins[e.key]
	self.watermark.Text = if style then (style.Kanji or "") else ""
	self.watermark.TextColor3 = d.color
	self.floor.Visible = e.type == "skin"
	self.floor.BackgroundColor3 = d.color
	local tier = if e.type == "skin" then Economy.tierOf(e.data.kit) else nil
	self.tierBadge.Visible = tier ~= nil
	if tier then
		self.tierBadge.Text = e.data.kit .. " · " .. tier.name
		self.tierBadge.TextColor3 = hex(tier.color)
		self.tierEdge.Color = hex(tier.color)
	end
	-- the picture
	local skin = e.type == "skin"
	self.viewHolder.Visible = skin
	self.view.hint.Visible = skin
	if skin then self.menu:viewStyle(self.view, e.key) end
	self.artIcon.Visible = e.type == "product"
	local vfx = e.type == "item" and e.data.kind == "VFX"
	self.moteColors = if vfx then { hex(e.data.colors[1]), hex(e.data.colors[2]) } else nil
	for _, m in self.motes do m.frame.Visible = vfx end
	local big, small, bigColor = "", "", WHITE
	if e.type == "pass" then
		big, small, bigColor = e.data.name, "GAME PASS · PERMANENT", hex(e.data.color)
	elseif e.type == "product" then
		big, small, bigColor = "", "+" .. e.data.coins .. " COINS", GOLD
	elseif e.type == "item" then
		local item = e.data
		if item.kind == "TITLE" then
			big, small, bigColor = "« " .. item.name .. " »", Players.LocalPlayer.DisplayName, GOLD
		elseif item.kind == "EMOTE" then
			big, small = item.name, "ON YOUR TAUNT WHEEL"
		elseif item.kind == "VICTORY" then
			big, small, bigColor = "🏆 " .. item.name, "COMING SOON", MUTED
		elseif item.kind == "VFX" then
			big, small = "", item.name
		end
	end
	self.artBig.Text, self.artBig.TextColor3 = big, bigColor
	self.artBig.Visible = big ~= ""
	self.artSmall.Text = small
	self.artSmall.Visible = small ~= "" and not skin
	-- the buttons
	local function setButton(button, spec)
		button.Visible = spec ~= nil
		if not spec then return end
		button.Text = spec.text
		button.TextColor3 = if spec.off then MUTED else WHITE
	end
	setButton(self.primary, d.primary)
	setButton(self.robux, d.robux)
	if d.primary and not d.robux then self.primary.Size = UDim2.new(1, -20, 0, 44)
	else self.primary.Size = UDim2.new(0.5, -14, 0, 44) end
	if d.robux and not d.primary then
		self.robux.Size = UDim2.new(1, -20, 0, 44)
	else
		self.robux.Size = UDim2.new(0.5, -14, 0, 44)
	end
	self.primaryAction = d.primary and d.primary.run
	self.robuxAction = d.robux and d.robux.run
end

-- Every frame while the page is open: the style turns, the aura's motes rise.
function ShopPage:update(dt)
	if not self.page.Visible then return end
	if self.viewHolder.Visible then self.menu:animateView(self.view, dt) end
	if self.moteColors then
		for i, m in self.motes do
			m.t = (m.t + dt * m.speed) % 1
			local f = m.frame
			f.Position = UDim2.fromScale(0.2 + m.x * 0.6 + math.sin((m.t + i) * 6) * 0.03, 0.95 - m.t * 0.9)
			f.BackgroundColor3 = self.moteColors[(i % 2) + 1]
			f.BackgroundTransparency = m.t * 0.8
			local size = 6 + (1 - m.t) * 8
			f.Size = UDim2.fromOffset(size, size)
		end
	end
end

-- The menu's status changed (coins, ownership, passes): the page follows.
function ShopPage:statusChanged()
	self.statusSerial = (self.statusSerial or 0) + 1
	if self.page.Visible then self:refresh() end
end

-- After a purchase (the server's word): a notification, the page shows it owned.
function ShopPage:purchased(p)
	local name = p.key
	if p.kind == "pass" and idx.pass[p.key] then name = idx.pass[p.key].name .. " PASS"
	elseif p.kind == "product" and idx.product[p.key] then name = idx.product[p.key].name or idx.product[p.key].style
	elseif p.kind == "item" and idx.item[p.key] then name = idx.item[p.key].name end
	self.menu:notify("PURCHASE COMPLETE · " .. tostring(name), GREEN)
end

return ShopPage
