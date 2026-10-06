-- Lobby surfaces only. No assets, fighter data, camera or gameplay dependencies.
local TweenService = game:GetService("TweenService")
local Theme = {}
local resetFeedback = setmetatable({}, { __mode = "k" })

Theme.WHITE = Color3.fromHex("F5F2EB")
Theme.INK = Color3.fromHex("090A0E")
Theme.PANEL = Color3.fromHex("13151D")
Theme.RAISED = Color3.fromHex("20232E")
Theme.LINE = Color3.fromHex("41434E")
Theme.MUTED = Color3.fromHex("B1B2BE")
Theme.RED = Color3.fromHex("F32643")
Theme.GOLD = Color3.fromHex("EABD67")
Theme.BLUE = Color3.fromHex("4C8EFF")
Theme.VIOLET = Color3.fromHex("AB73FF")
Theme.DISPLAY = Enum.Font.Bangers
Theme.BODY = Enum.Font.GothamBold
Theme.UI = Enum.Font.GothamBlack

function Theme.new(className, props, parent)
	local object = Instance.new(className)
	for key, value in props do object[key] = value end
	object.Parent = parent
	return object
end
local new = Theme.new

function Theme.text(parent, props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.BorderSizePixel = 0
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.TextColor3 = props.TextColor3 or Theme.WHITE
	props.Font = props.Font or Theme.BODY
	props.ZIndex = props.ZIndex or parent.ZIndex
	return new("TextLabel", props, parent)
end

function Theme.edge(parent, color, thickness, transparency)
	return new("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color or Theme.LINE, Thickness = thickness or 1, Transparency = transparency or 0 }, parent)
end

function Theme.gradient(parent, first, last, rotation)
	return new("UIGradient", { Color = ColorSequence.new(first, last), Rotation = rotation or 0 }, parent)
end

function Theme.rule(parent, position, size, color, transparency)
	return new("Frame", { Name = "Rule", Position = position, Size = size, BorderSizePixel = 0,
		BackgroundColor3 = color or Theme.LINE, BackgroundTransparency = transparency or 0, ZIndex = parent.ZIndex }, parent)
end

-- Graphic speed lines are UI shapes: they remain crisp at every canvas scale.
function Theme.ink(parent, accent, strength)
	local art = new("Frame", { Name = "Ink", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		ClipsDescendants = true, ZIndex = parent.ZIndex }, parent)
	-- Keep the rotated strokes inside the card; this also works in places where
	-- clipping rotated descendants is disabled (and under the tilted nav buttons).
	for i = 1, 7 do
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.42 + i * 0.055, 0.5),
			Size = UDim2.new(0, if i % 3 == 0 then 12 else 2, 0.7, 0), Rotation = 28,
			BackgroundColor3 = accent, BackgroundTransparency = strength or 0.88,
			BorderSizePixel = 0, ZIndex = parent.ZIndex }, art)
	end
	return art
end

function Theme.surface(parent, accent)
	parent.BackgroundColor3 = Color3.new(1, 1, 1)
	parent.BorderSizePixel = 0
	new("UICorner", { CornerRadius = UDim.new(0, 2) }, parent)
	if parent:IsA("TextLabel") then
		parent.BackgroundColor3 = Theme.PANEL
	else
		Theme.gradient(parent, Theme.RAISED, Theme.INK, 28)
	end
	local edge = Theme.edge(parent)
	Theme.rule(parent, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 2), accent or Theme.RED)
	return edge
end

function Theme.heading(parent, title, accent, subtitle)
	Theme.text(parent, { Name = "Heading", Position = UDim2.fromOffset(22, 18), Size = UDim2.new(1, -44, 0, 44),
		Text = title, Font = Theme.DISPLAY, TextSize = 38 })
	Theme.rule(parent, UDim2.fromOffset(22, 68), UDim2.fromOffset(38, 3), accent or Theme.RED)
	Theme.rule(parent, UDim2.fromOffset(68, 69), UDim2.new(1, -90, 0, 1), Theme.LINE, 0.3)
	if subtitle then
		return Theme.text(parent, { Position = UDim2.fromOffset(22, 80), Size = UDim2.new(1, -44, 0, 28),
			Text = subtitle, TextSize = 13, TextColor3 = Theme.MUTED, TextWrapped = true })
	end
	return nil
end

-- Focus also answers the controller. Cancel the previous tween before each new one;
-- leaving a button while pressed never leaves it oversized or visually stuck down.
function Theme.feedback(button)
	local scale = new("UIScale", { Name = "ButtonScale", Scale = 1 }, button)
	local hovered, focused, pressed = false, false, false
	local tween
	local function refresh()
		if tween then tween:Cancel() end
		tween = TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = if pressed then 0.985 elseif hovered or focused then 1.012 else 1,
		})
		tween:Play()
	end
	resetFeedback[button] = function() hovered = false; focused = false; pressed = false; refresh() end
	button.MouseEnter:Connect(function() hovered = true; refresh() end)
	button.MouseLeave:Connect(function() hovered = false; pressed = false; refresh() end)
	button.SelectionGained:Connect(function() focused = true; refresh() end)
	button.SelectionLost:Connect(function() focused = false; pressed = false; refresh() end)
	button.MouseButton1Down:Connect(function() pressed = true; refresh() end)
	button.MouseButton1Up:Connect(function() pressed = false; refresh() end)
	button:GetPropertyChangedSignal("Visible"):Connect(function()
		if not button.Visible then hovered = false; focused = false; pressed = false; refresh() end
	end)
end

function Theme.reset(parent)
	for _, child in parent:GetDescendants() do
		local reset = resetFeedback[child]
		if reset then reset() end
	end
end

function Theme.button(parent, props, accent)
	props.AutoButtonColor = false
	props.BorderSizePixel = 0
	props.BackgroundColor3 = props.BackgroundColor3 or Theme.PANEL
	props.TextColor3 = props.TextColor3 or Theme.WHITE
	props.Font = props.Font or Theme.UI
	props.ZIndex = props.ZIndex or parent.ZIndex
	local button = new("TextButton", props, parent)
	Theme.feedback(button)
	local edge = Theme.edge(button)
	local hovered, focused = false, false
	local function paint()
		local on = hovered or focused
		edge.Color = if on then (accent or Theme.RED) else Theme.LINE
		button.BackgroundColor3 = if on then Theme.RAISED else props.BackgroundColor3
	end
	button.MouseEnter:Connect(function() hovered = true; paint() end)
	button.MouseLeave:Connect(function() hovered = false; paint() end)
	button.SelectionGained:Connect(function() focused = true; paint() end)
	button.SelectionLost:Connect(function() focused = false; paint() end)
	return button
end

-- A real cross (Wilhem: « mets une vraie croix »: the ✕ character is missing from the game's
-- fonts and showed as an empty box): two white bars crossed at 45°, drawn inside `parent`.
-- `size` in pixels (the bars' length), `position` / `anchor` of the cross in its parent
-- (default: centred).
function Theme.cross(parent, size, position, anchor, color)
	size = size or 18
	local box = Theme.new("Frame", { Name = "Cross", BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size),
		AnchorPoint = anchor or Vector2.new(0.5, 0.5), Position = position or UDim2.fromScale(0.5, 0.5),
		ZIndex = (parent.ZIndex or 1) + 1 }, parent)
	for _, angle in { 45, -45 } do
		Theme.new("Frame", { BorderSizePixel = 0, BackgroundColor3 = color or Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1.25, 0, 0, math.max(2, math.floor(size / 6))), Rotation = angle,
			ZIndex = box.ZIndex }, box)
	end
	return box
end

return Theme
