--[[
	The currency sprites of the menu (cosmetic). Each icon is drawn from UI shapes, so it shows
	without any uploaded image: COINS a gold coin stamped 金, CRYSTALS a violet gem, RANK a red
	chevron badge, TICKETS a torn ticket. The same designs exist as images in
	assets/icons/currency_*.png (tools/currency_icons.py): once Wilhem uploads them, their ids
	go in IMAGES below and the image is shown instead (they are: Wilhem's uploads). No id is ever invented.
]]
local CurrencyIcons = {}

-- kind -> "rbxassetid://..." of the uploaded assets/icons/currency_<kind>.png (missing: drawn).
-- (uploaded by Wilhem to Roblox, his ids)
CurrencyIcons.IMAGES = {
	coins = "rbxassetid://94413834656149",
	crystals = "rbxassetid://117266491886576",
	rank = "rbxassetid://131891284883773",
	tickets = "rbxassetid://128432100049492",
}

CurrencyIcons.COLORS = {
	coins = Color3.fromHex("FFC83D"),
	crystals = Color3.fromHex("A77BFF"),
	rank = Color3.fromHex("FF3B4E"),
	tickets = Color3.fromHex("3FD6FF"),
}

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end

local function gradient(o, top, bottom)
	new("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = 90 }, o)
end

local function round(o, r)
	new("UICorner", { CornerRadius = if r then UDim.new(0, r) else UDim.new(0.5, 0) }, o)
end

local function edge(o, thickness, color)
	new("UIStroke", { Thickness = thickness, Color = color, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end

local DRAW = {}

function DRAW.coins(icon)
	local coin = new("Frame", { Size = UDim2.fromScale(0.9, 0.9), Position = UDim2.fromScale(0.05, 0.05),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, icon)
	round(coin)
	gradient(coin, Color3.fromHex("FFE58A"), Color3.fromHex("D99A12"))
	edge(coin, 1.5, Color3.fromHex("8A5A00"))
	local inner = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.68, 0.68),
		BackgroundTransparency = 1 }, coin)
	round(inner)
	edge(inner, 1, Color3.fromHex("B37A06"))
	new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true,
		Text = "金", TextColor3 = Color3.fromHex("8A5A00") }, inner)
end

function DRAW.crystals(icon)
	local gem = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.62),
		Rotation = 45, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, icon)
	round(gem, 2)
	gradient(gem, Color3.fromHex("E2D2FF"), Color3.fromHex("6A3BD8"))
	edge(gem, 1.5, Color3.fromHex("3A1A8A"))
	local shine = new("Frame", { Position = UDim2.fromScale(0.14, 0.14), Size = UDim2.fromScale(0.3, 0.3),
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.25, BorderSizePixel = 0 }, gem)
	round(shine, 1)
end

function DRAW.rank(icon)
	local badge = new("Frame", { Size = UDim2.fromScale(0.9, 0.9), Position = UDim2.fromScale(0.05, 0.05),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, icon)
	round(badge, 4)
	gradient(badge, Color3.fromHex("FF6A78"), Color3.fromHex("A3081A"))
	edge(badge, 1.5, Color3.fromHex("5A0410"))
	for i, y in { 0.3, 0.55 } do
		for side = -1, 1, 2 do
			new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5 + side * 0.15, y),
				Size = UDim2.fromScale(0.38, 0.12), Rotation = side * -35, BackgroundColor3 = if i == 1 then Color3.fromHex("FFE9B0")
				else Color3.new(1, 1, 1), BorderSizePixel = 0 }, badge)
		end
	end
end

function DRAW.tickets(icon)
	local ticket = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.92, 0.6),
		Rotation = -12, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, icon)
	round(ticket, 3)
	gradient(ticket, Color3.fromHex("9CEBFF"), Color3.fromHex("1C8FB8"))
	edge(ticket, 1.5, Color3.fromHex("0A4A63"))
	for _, x in { 0, 1 } do
		local notch = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.5), Size = UDim2.fromScale(0.2, 0.32),
			BackgroundColor3 = Color3.fromHex("14141A"), BorderSizePixel = 0 }, ticket)
		round(notch)
	end
	new("Frame", { Position = UDim2.fromScale(0.62, 0.15), Size = UDim2.new(0, 1, 0.7, 0), BackgroundColor3 = Color3.fromHex("0A4A63"),
		BorderSizePixel = 0 }, ticket)
end

-- An icon of `size` pixels (square) for a currency kind, in `parent`.
function CurrencyIcons.make(kind, parent, size, position)
	local holder = new("Frame", { Size = UDim2.fromOffset(size, size), Position = position or UDim2.new(), BackgroundTransparency = 1,
		Name = "Currency_" .. kind }, parent)
	-- The drawn icon always, the uploaded image over it: an image still in moderation (or
	-- refused) leaves the drawing visible instead of an empty square.
	local drawn = Instance.new("Frame")
	drawn.Name, drawn.Size, drawn.BackgroundTransparency = "Drawn", UDim2.fromScale(1, 1), 1
	drawn.Parent = holder
	if DRAW[kind] then DRAW[kind](drawn) end
	local image = CurrencyIcons.IMAGES[kind]
	if image then
		local picture = new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = image,
			ScaleType = Enum.ScaleType.Fit, ImageTransparency = 1 }, holder)
		-- (shown, and the drawing hidden, only once the image really loaded)
		local function check()
			if picture.IsLoaded then
				picture.ImageTransparency = 0
				drawn.Visible = false
			end
		end
		picture:GetPropertyChangedSignal("IsLoaded"):Connect(check)
		check()
	end
	return holder
end

return CurrencyIcons
