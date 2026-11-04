--[[
	QUICK TRASH TALK, the client side (cosmetic): the taunt wheel and the bubbles.

	  • The wheel: the 6 equipped taunts (shared/Taunts, the saved wheel the menu status
	    carries) around a centre that shows the cooldown. PC: a key (SETTINGS › TAUNT KEY,
	    V by default) opens it, a click picks; mobile: the small 💬 button. It closes at once
	    after a pick, on the key again, on Escape or after 4 s (a click outside stays an attack). It never sinks a key: moving,
	    guarding and attacking go on while it is open (only the cursor is freed a moment
	    when the mouse is locked).
	  • A pick only sends the SLOT NUMBER (input.taunt): the server decides, checks the 5 s
	    cooldown and sends a "Taunt" event to the whole match.
	  • The bubble: a BillboardGui on the fighter's head (it follows every move and pose),
	    small, black / red / white, pops in, stays Taunts.DURATION s, fades out. One bubble
	    per fighter (a new one replaces the old). Hidden during the cinematics. SETTINGS ›
	    OPPONENT TAUNTS: OFF hides the others' bubbles (your own still shows).
]]
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Taunts = require(Shared:WaitForChild("Taunts"))

local TauntController = {}
TauntController.__index = TauntController

local INK = Color3.fromHex("090A0E")
local RED = Color3.fromHex("F32643")
local WHITE = Color3.fromHex("F5F2EB")
local MUTED = Color3.fromHex("8A8B96")
local AUTO_CLOSE = 4

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end

local function inMatch()
	return (Players.LocalPlayer:GetAttribute("MatchId") or 0) ~= 0
end

function TauntController.new(input)
	local self = setmetatable({ input = input, wheel = table.clone(Taunts.DEFAULT), key = "V", showOthers = true,
		open = false, last = -math.huge, bubbles = {}, hiddenByCinematic = false }, TauntController)
	local gui = new("ScreenGui", { Name = "Taunts", ResetOnSpawn = false, DisplayOrder = 15, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, Players.LocalPlayer:WaitForChild("PlayerGui"))
	self.gui = gui
	self.bubbleFolder = new("Folder", { Name = "TauntBubbles" }, gui)
	-- The wheel (hidden until opened): six slanted plates around a round centre.
	local wheel = new("Frame", { Name = "Wheel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(420, 300), BackgroundTransparency = 1, Visible = false }, gui)
	self.wheelFrame = wheel
	new("UIScale", { Name = "Pop" }, wheel)
	local centre = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(92, 92),
		BackgroundColor3 = INK, BackgroundTransparency = 0.1, BorderSizePixel = 0 }, wheel)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, centre)
	new("UIStroke", { Color = RED, Thickness = 2 }, centre)
	self.centreText = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.Bangers, TextSize = 22,
		Text = "TAUNT", TextColor3 = WHITE }, centre)
	self.plates = {}
	for i = 1, Taunts.SLOTS do
		local angle = math.rad(-90 + (i - 1) * 60)
		local plate = new("TextButton", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(150, 40),
			Position = UDim2.new(0.5, math.cos(angle) * 150, 0.5, math.sin(angle) * 105), BackgroundColor3 = INK,
			BackgroundTransparency = 0.08, AutoButtonColor = false, BorderSizePixel = 0, Font = Enum.Font.Bangers, TextSize = 20,
			Text = "", TextColor3 = WHITE, TextScaled = false, Rotation = -3 }, wheel)
		new("UIStroke", { Color = Color3.fromHex("41434E"), Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, plate)
		new("Frame", { Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = RED, BorderSizePixel = 0 }, plate)
		new("TextLabel", { Position = UDim2.fromOffset(-6, -8), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = RED, BorderSizePixel = 0,
			Font = Enum.Font.GothamBlack, TextSize = 11, Text = tostring(i), TextColor3 = WHITE }, plate)
		plate.MouseEnter:Connect(function() plate.BackgroundColor3 = Color3.fromHex("5A0A16") end)
		plate.MouseLeave:Connect(function() plate.BackgroundColor3 = INK end)
		plate.Activated:Connect(function() self:pick(i) end)
		self.plates[i] = plate
	end
	-- (no full-screen backdrop: a click outside the plates stays an attack; the wheel closes
	-- on a pick, on its key again, on Escape, or by itself after AUTO_CLOSE s)
	-- Mobile: a small round 💬 button (only in a match, only on touch screens).
	local touch = new("TextButton", { Name = "TauntButton", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.42, 0),
		Size = UDim2.fromOffset(46, 46), BackgroundColor3 = INK, BackgroundTransparency = 0.15, AutoButtonColor = false,
		Font = Enum.Font.GothamBlack, TextSize = 22, Text = "💬", TextColor3 = WHITE, Visible = false }, gui)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, touch)
	new("UIStroke", { Color = RED, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, touch)
	touch.Activated:Connect(function() if self.open then self:close() else self:openWheel() end end)
	self.touchButton = touch
	-- PC: the key (never sunk: the fight's own bindings still get it if they use it).
	UserInputService.InputBegan:Connect(function(io, processed)
		if processed or UserInputService:GetFocusedTextBox() then return end
		local ok, code = pcall(function() return Enum.KeyCode[self.key] end)
		if ok and io.KeyCode == code then
			if self.open then self:close() else self:openWheel() end
		elseif io.KeyCode == Enum.KeyCode.Escape and self.open then
			self:close()
		end
	end)
	-- Gamepad: R3 (right stick pressed) opens the wheel, the right stick points at a plate,
	-- letting it go sends that taunt; R3 again closes.
	local aimed = nil
	UserInputService.InputBegan:Connect(function(io)
		if io.KeyCode == Enum.KeyCode.ButtonR3 then
			if self.open then self:close() else self:openWheel() end
			aimed = nil
		end
	end)
	UserInputService.InputChanged:Connect(function(io)
		if io.KeyCode ~= Enum.KeyCode.Thumbstick2 or not self.open then return end
		local v = Vector2.new(io.Position.X, -io.Position.Y) -- (screen: y down)
		if v.Magnitude > 0.7 then
			-- the plate whose direction is the closest (plate i at -90 + (i - 1) * 60 degrees)
			local angle = math.deg(math.atan2(v.Y, v.X))
			local slot = math.floor(((angle + 90) % 360 + 30) / 60) % Taunts.SLOTS + 1
			if slot ~= aimed then
				aimed = slot
				for i, plate in self.plates do plate.BackgroundColor3 = if i == slot then Color3.fromHex("5A0A16") else INK end
			end
		elseif v.Magnitude < 0.3 and aimed then
			local slot = aimed
			aimed = nil
			for _, plate in self.plates do plate.BackgroundColor3 = INK end
			if self.plates[slot].Visible then self:pick(slot) end
		end
	end)
	RunService.RenderStepped:Connect(function() self:frame() end)
	return self
end

-- The saved wheel and options from the menu status.
function TauntController:setWheel(list)
	-- (the server already cleaned it against the saved profile: unlocked ones included)
	if type(list) == "table" then
		local kept = {}
		for _, id in list do
			if Taunts.BY_ID[id] and #kept < Taunts.SLOTS then table.insert(kept, id) end
		end
		if #kept > 0 then self.wheel = kept end
	end
end
function TauntController:setKey(key)
	if table.find(Taunts.KEYS, key) then self.key = key end
end
function TauntController:setShowOthers(on)
	self.showOthers = on
	if not on then
		local mine = Players.LocalPlayer:GetAttribute("FighterSlot") or 0
		for slot, bubble in self.bubbles do
			if slot ~= mine then bubble:Destroy(); self.bubbles[slot] = nil end
		end
	end
end

function TauntController:openWheel()
	if not inMatch() then return end
	for i, plate in self.plates do
		local taunt = Taunts.BY_ID[self.wheel[i] or ""]
		plate.Text = if taunt then taunt.text else "—"
		plate.Visible = taunt ~= nil
	end
	self.open = true
	self.wheelFrame.Visible = true
	self.openedAt = os.clock()
	self.input.suspendMouseLock(true)
	local pop = self.wheelFrame.Pop
	pop.Scale = 0.7
	TweenService:Create(pop, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

function TauntController:close()
	self.open = false
	self.wheelFrame.Visible = false
	self.input.suspendMouseLock(false)
end

function TauntController:pick(slot)
	self:close()
	-- (the server checks the cooldown too: this only spares a refused packet)
	if Taunts.cooldownLeft(self.last, os.clock()) > 0 then return end
	self.last = os.clock()
	self.input.taunt(slot)
end

function TauntController:frame()
	local match = inMatch()
	self.touchButton.Visible = match and UserInputService.TouchEnabled
	if self.open and (not match or os.clock() - (self.openedAt or 0) > AUTO_CLOSE) then self:close() end
	if self.open then
		local left = Taunts.cooldownLeft(self.last, os.clock())
		self.centreText.Text = if left > 0 then string.format("%.1f", left) else "TAUNT"
		self.centreText.TextColor3 = if left > 0 then MUTED else WHITE
	end
	if not match then
		for slot, bubble in self.bubbles do bubble:Destroy(); self.bubbles[slot] = nil end
	end
end

-- The cinematics hide the bubbles (they would sit in the middle of the staged shots).
function TauntController:setCinematic(active)
	self.bubbleFolder.Parent = if active then nil else self.gui
end

-- A "Taunt" event of the match: the bubble over that fighter's head.
function TauntController:onEvent(event, rigs)
	if event.kind ~= "Taunt" then return end
	local taunt = Taunts.BY_ID[event.id or ""]
	if not taunt then return end
	local mine = Players.LocalPlayer:GetAttribute("FighterSlot") or 0
	if event.slot ~= mine and not self.showOthers then return end
	local rig = rigs and rigs[event.slot]
	local head = rig and rig.model and rig.model:FindFirstChild("Head")
	if not head then return end
	if self.bubbles[event.slot] then self.bubbles[event.slot]:Destroy() end
	-- Small and readable at any distance (pixel size), over the head, never in front of the
	-- other fighter's body (it sits above the heads), always drawn on top.
	local width = math.clamp(#taunt.text * 11 + 34, 90, 240)
	local board = new("BillboardGui", { Name = "Taunt" .. event.slot, Adornee = head, AlwaysOnTop = true, LightInfluence = 0,
		Size = UDim2.fromOffset(width, 44), StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0), ResetOnSpawn = false,
		MaxDistance = 400 }, self.bubbleFolder)
	local holder = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, board)
	local scale = new("UIScale", { Scale = 0.2 }, holder)
	local plate = new("Frame", { Size = UDim2.new(1, 0, 1, -8), BackgroundColor3 = INK, BackgroundTransparency = 0.05,
		BorderSizePixel = 0 }, holder)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, plate)
	local edge = new("UIStroke", { Color = if event.slot == mine then RED else WHITE, Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, plate)
	new("Frame", { Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = RED, BorderSizePixel = 0 }, plate)
	-- (the tail pointing at the head)
	local tail = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.fromOffset(12, 12),
		Rotation = 45, BackgroundColor3 = INK, BorderSizePixel = 0, ZIndex = 0 }, holder)
	local text = new("TextLabel", { Size = UDim2.new(1, -12, 1, 0), Position = UDim2.fromOffset(8, 0), BackgroundTransparency = 1,
		Font = Enum.Font.Bangers, TextScaled = true, Text = taunt.text, TextColor3 = WHITE }, plate)
	new("UITextSizeConstraint", { MaxTextSize = 24, MinTextSize = 12 }, text)
	new("UIStroke", { Color = INK, Thickness = 1.5 }, text)
	self.bubbles[event.slot] = board
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(Taunts.DURATION, function()
		if self.bubbles[event.slot] ~= board then return end
		local out = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(scale, out, { Scale = 0.6 }):Play()
		TweenService:Create(plate, out, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(tail, out, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(text, out, { TextTransparency = 1 }):Play()
		TweenService:Create(edge, out, { Transparency = 1 }):Play()
		task.delay(0.25, function()
			if self.bubbles[event.slot] == board then self.bubbles[event.slot] = nil end
			board:Destroy()
		end)
	end)
end

return TauntController
