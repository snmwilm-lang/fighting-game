local CAS = game:GetService("ContextActionService")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Bindings = require(game:GetService("ReplicatedStorage").Shared.InputConfig)
local InputController = {}

function InputController.start(remote)
	local keys, pulses = {}, { jump = false, dash = false, reset = false }
	local stick, touchStick = Vector2.zero, Vector2.zero
	local blocked, sequence, elapsed, keepalive = false, 0, 0, 0
	local function has(action)
		for _, held in keys do if held == action then return true end end
		return false
	end
	local function set(action, key, down)
		if down and not blocked and not UIS:GetFocusedTextBox() then
			keys[key] = action
			local pulse = ({ Jump = "jump", Dash = "dash", Reset = "reset" })[action]
			if pulse then pulses[pulse] = true end
		else keys[key] = nil end
	end
	local function clear()
		table.clear(keys)
		stick, touchStick = Vector2.zero, Vector2.zero
		pulses.jump, pulses.dash, pulses.reset = false, false, false
	end
	for action, codes in Bindings do
		if type(codes) == "table" then
			CAS:BindActionAtPriority("Fight_" .. action, function(_, state, input)
				if UIS:GetFocusedTextBox() then
					set(action, input.KeyCode, false)
					return Enum.ContextActionResult.Pass
				end
				set(action, input.KeyCode, state == Enum.UserInputState.Begin)
				return Enum.ContextActionResult.Sink
			end, false, 3000, table.unpack(codes))
		end
	end
	CAS:BindActionAtPriority("Fight_Stick", function(_, state, input)
		stick = if state == Enum.UserInputState.Cancel or state == Enum.UserInputState.End
			then Vector2.zero else Vector2.new(input.Position.X, input.Position.Y)
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.Thumbstick1)
	UIS.TextBoxFocused:Connect(clear)
	UIS.WindowFocusReleased:Connect(function() blocked = true; clear() end)
	UIS.WindowFocused:Connect(function() blocked = false end)
	GuiService.MenuOpened:Connect(function() blocked = true; clear() end)
	GuiService.MenuClosed:Connect(function() blocked = false end)
	UIS.GamepadDisconnected:Connect(clear)

	-- Custom touch controls: each finger is tracked until release outside the button.
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "MobileControls", false, 10
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui.Enabled = UIS.TouchEnabled
	local controls = Instance.new("Frame")
	controls.Name, controls.Size, controls.BackgroundTransparency = "Controls", UDim2.fromScale(1, 1), 1
	controls.Parent = gui
	local function circle(name, size, position, text)
		local b = Instance.new("TextButton")
		b.Name, b.Size, b.Position = name, UDim2.fromOffset(size, size), position
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.BackgroundColor3, b.BackgroundTransparency = Color3.fromHex("1B2941"), 0.15
		b.Text, b.TextColor3, b.TextSize, b.Font = text, Color3.fromHex("F0F8FF"), 15, Enum.Font.GothamBold
		b.AutoButtonColor, b.Parent = false, controls
		local corner = Instance.new("UICorner")
		corner.CornerRadius, corner.Parent = UDim.new(1, 0), b
		local stroke = Instance.new("UIStroke")
		stroke.Color, stroke.Transparency, stroke.Thickness, stroke.Parent = Color3.fromHex("52F2D6"), 0.3, 2, b
		return b
	end
	local pad = circle("Stick", 130, UDim2.new(0, 95, 1, -95), "")
	local knob = circle("Knob", 50, pad.Position, "↔")
	knob.Active, knob.Interactable = false, false
	local activeTouch = nil
	local touchButtons = {}
	local function moveTouch(position)
		local center = pad.AbsolutePosition + pad.AbsoluteSize / 2
		local v = (Vector2.new(position.X, position.Y) - center) / (pad.AbsoluteSize.X / 2)
		if v.Magnitude > 1 then v = v.Unit end
		touchStick = Vector2.new(v.X, -v.Y)
		knob.Position = pad.Position + UDim2.fromOffset(v.X * 34, v.Y * 34)
	end
	pad.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch and not activeTouch then
			activeTouch = input
			moveTouch(input.Position)
		end
	end)
	for action, info in { Jump = { -75, -142, "SAUT" }, Dash = { -150, -82, "DASH" }, Crouch = { -62, -55, "BAS" } } do
		local button = circle(action, 66, UDim2.new(1, info[1], 1, info[2]), info[3])
		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				touchButtons[input] = button
				button.BackgroundColor3 = Color3.fromHex("38766F")
				set(action, input, true)
			end
		end)
	end
	UIS.InputChanged:Connect(function(input)
		if input == activeTouch then moveTouch(input.Position) end
	end)
	UIS.InputEnded:Connect(function(input)
		keys[input] = nil
		if touchButtons[input] then
			touchButtons[input].BackgroundColor3 = Color3.fromHex("1B2941")
			touchButtons[input] = nil
		end
		if input == activeTouch then
			activeTouch, touchStick, knob.Position = nil, Vector2.zero, pad.Position
		end
	end)
	local function read()
		if blocked or UIS:GetFocusedTextBox() then return 0, false end
		local axis = (if has("Right") then 1 else 0) - (if has("Left") then 1 else 0)
		if not has("Right") and not has("Left") then
			local v = if activeTouch then touchStick.X else stick.X
			axis = if math.abs(v) > Bindings.Deadzone then math.sign(v) * (math.abs(v) - Bindings.Deadzone) / (1 - Bindings.Deadzone) else 0
		end
		return math.clamp(axis, -1, 1), has("Crouch") or stick.Y < -0.55 or touchStick.Y < -0.55
	end
	local previousAxis, previousCrouch = 0, false
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		keepalive += dt
		if elapsed < 1 / 30 then return end
		elapsed = 0
		local axis, crouch = read()
		if keepalive >= 0.1 or math.abs(axis - previousAxis) > 0.02 or crouch ~= previousCrouch
			or pulses.jump or pulses.dash or pulses.reset then
			sequence += 1
			remote:FireServer({ seq = sequence, axis = axis, crouch = crouch,
				jump = pulses.jump, dash = pulses.dash, reset = pulses.reset })
			previousAxis, previousCrouch, keepalive = axis, crouch, 0
			pulses.jump, pulses.dash, pulses.reset = false, false, false
		end
	end)
	return { reset = function() pulses.reset = true end, clear = clear }
end
return InputController
