-- Input adapter: keyboard, mouse, gamepad and custom touch controls all feed the same logical
-- actions, sent to the server as one validated packet. Attacks and jumps are pulses (sent at
-- once); movement, crouch and guard are held states.
local CAS = game:GetService("ContextActionService")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Bindings = require(Shared.InputConfig)
local PressQueue = require(Shared.PressQueue)
local InputController = {}

local PULSES = {
	Jump = "jump", Dash = "dash", Reset = "reset", Light = "light", Heavy = "heavy",
	Special = "special", Ultimate = "ultimate", Fatal = "fatal", Dummy = "dummy", Kit = "kit", FoeKit = "foeKit",
	Stance1 = "stance1", Stance2 = "stance2",
}

function InputController.start(remote)
	local keys = {}
	local pulses = {
		jump = false, dash = false, reset = false, dummy = false, avatar = false, skin = false, kit = false, foeKit = false,
		ultiConditions = false,
		stance1 = false, stance2 = false,
	}
	local stick, touchStick = Vector2.zero, Vector2.zero
	local blocked, sequence, sinceAxis, keepalive = false, 0, 0, 0
	local cinematicTick = nil -- function: the cinematic tick shown on screen (QTE lag compensation)
	local tutorMode = nil -- TUTORIAL: the dummy's behaviour asked for this step (server-checked)
	local tauntSlot = 0 -- QUICK TRASH TALK: the wheel slot (1..6) to send with the next packet
	local lockSuspended = false -- (the taunt wheel needs the cursor a moment)
	local function has(action)
		for _, held in keys do if held == action then return true end end
		return false
	end
	-- Attack presses in the order they were made: two clicks between two packets stay two
	-- clicks, a heavy then a light stays heavy first (see PressQueue).
	local presses = {}
	local function press(pulse)
		if PressQueue.BUTTONS[pulse] then
			if #presses < PressQueue.MAX_PACKET then table.insert(presses, pulse) end
		else
			pulses[pulse] = true
		end
	end
	local lastDirection = nil -- left + right held together: the last one pressed wins
	-- Mouse lock (Ctrl or the HUD button): the cursor is hidden and held at the centre of the
	-- screen, so clicking to attack never sends the mouse anywhere (like shift lock, no dot).
	local mouseLocked, onMouseLock = false, nil
	local function setMouseLock(on)
		mouseLocked = on
		if not on then
			UIS.MouseBehavior = Enum.MouseBehavior.Default
			UIS.MouseIconEnabled = true
		end
		if onMouseLock then onMouseLock(on) end
	end
	local wasLocked = false
	RunService:BindToRenderStep("FightMouseLock", Enum.RenderPriority.Camera.Value + 2, function()
		-- Only in a match: the menu always needs its cursor.
		local inMatch = (Players.LocalPlayer:GetAttribute("MatchId") or 0) ~= 0
		local lock = mouseLocked and inMatch and not lockSuspended
		if lock then -- (the default camera scripts reset it: enforce every frame)
			UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
			UIS.MouseIconEnabled = false
		elseif wasLocked then
			UIS.MouseBehavior = Enum.MouseBehavior.Default
			UIS.MouseIconEnabled = true
		end
		wasLocked = lock
	end)
	local function set(action, key, down)
		if action == "MouseLock" then
			if down and not blocked and not UIS:GetFocusedTextBox() then setMouseLock(not mouseLocked) end
			return
		end
		if down and not blocked and not UIS:GetFocusedTextBox() then
			keys[key] = action
			if action == "Left" or action == "Right" then lastDirection = action end
			local pulse = PULSES[action]
			if pulse then press(pulse) end
		else keys[key] = nil end
	end
	local function clear()
		table.clear(keys)
		table.clear(presses)
		stick, touchStick = Vector2.zero, Vector2.zero
		for k in pulses do pulses[k] = false end
	end
	-- (out of a match the fight lets every key through: a gamepad's A / B / D-pad then drive
	-- the menu's selection instead of being swallowed by the fight's bindings)
	local function inMatch()
		return (Players.LocalPlayer:GetAttribute("MatchId") or 0) ~= 0
	end
	for action, codes in Bindings do
		if type(codes) == "table" and action ~= "Mouse" then
			CAS:BindActionAtPriority("Fight_" .. action, function(_, state, input)
				if UIS:GetFocusedTextBox() or not inMatch() then
					set(action, input.KeyCode, false)
					return Enum.ContextActionResult.Pass
				end
				set(action, input.KeyCode, state == Enum.UserInputState.Begin)
				return Enum.ContextActionResult.Sink
			end, false, 3000, table.unpack(codes))
		end
	end
	CAS:BindActionAtPriority("Fight_Stick", function(_, state, input)
		if not inMatch() then
			stick = Vector2.zero
			return Enum.ContextActionResult.Pass
		end
		stick = if state == Enum.UserInputState.Cancel or state == Enum.UserInputState.End
			then Vector2.zero else Vector2.new(input.Position.X, input.Position.Y)
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.Thumbstick1)
	-- Mouse attacks: left click = combo, right click = heavy / combo finisher.
	-- gameProcessed skips clicks on HUD buttons.
	UIS.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or blocked then return end
		for action, inputType in Bindings.Mouse do
			if input.UserInputType == inputType then press(PULSES[action]) end
		end
	end)
	UIS.TextBoxFocused:Connect(clear)
	UIS.WindowFocusReleased:Connect(function() blocked = true; clear() end)
	UIS.WindowFocused:Connect(function() blocked = false end)
	GuiService.MenuOpened:Connect(function() blocked = true; clear() end)
	GuiService.MenuClosed:Connect(function() blocked = false end)
	UIS.GamepadDisconnected:Connect(clear)

	-- Custom touch controls: each finger is tracked until release, even outside the button.
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "MobileControls", false, 10
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui.Enabled = UIS.TouchEnabled
	local controls = Instance.new("Frame")
	controls.Name, controls.Size, controls.BackgroundTransparency = "Controls", UDim2.fromScale(1, 1), 1
	controls.Parent = gui
	-- (scaled to the screen: on a phone the pad and the buttons took half of it; still big
	-- enough for a thumb)
	local controlsScale = Instance.new("UIScale")
	controlsScale.Parent = controls
	local function fitControls()
		local height = gui.AbsoluteSize.Y
		if height <= 0 then return end
		local scale = math.clamp(height / 620, 0.62, 1)
		controlsScale.Scale = scale
		controls.Size = UDim2.fromScale(1 / scale, 1 / scale)
	end
	fitControls()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitControls)
	local function circle(name, size, position, text, color)
		local b = Instance.new("TextButton")
		b.Name, b.Size, b.Position = name, UDim2.fromOffset(size, size), position
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.BackgroundColor3, b.BackgroundTransparency = Color3.fromHex("101014"), 0.15
		b.Text, b.TextColor3, b.TextSize, b.Font = text, Color3.fromHex("F5F5F7"), 15, Enum.Font.Bangers
		b.AutoButtonColor, b.Parent = false, controls
		local corner = Instance.new("UICorner")
		corner.CornerRadius, corner.Parent = UDim.new(1, 0), b
		local stroke = Instance.new("UIStroke")
		stroke.Color, stroke.Transparency, stroke.Thickness, stroke.Parent = color or Color3.fromHex("E0102B"), 0.15, 2.5, b
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
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
	local layout = {
		Light = { -82, -92, 84, "ATTACK" },
		Heavy = { -180, -64, 72, "HEAVY" },
		Jump = { -78, -196, 66, "JUMP" },
		Block = { -172, -162, 66, "GUARD", Color3.fromHex("6E7BFF") },
		Dash = { -268, -56, 58, "DASH" },
		Crouch = { -262, -138, 54, "DOWN" },
		Special = { -250, -222, 58, "SPEC", Color3.fromHex("FFB938") },
		Ultimate = { -152, -254, 62, "ULTI", Color3.fromHex("FF2A3D") },
		Fatal = { -60, -282, 54, "FATAL", Color3.fromHex("FFFFFF") },
	}
	local ultimateButton, fatalButton
	for action, info in layout do
		local button = circle(action, info[3], UDim2.new(1, info[1], 1, info[2]), info[4], info[5])
		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				touchButtons[input] = button
				button.BackgroundColor3 = Color3.fromHex("5A0A16")
				set(action, input, true)
			end
		end)
		if action == "Ultimate" then ultimateButton = button end
		if action == "Fatal" then fatalButton, button.Visible = button, false end
	end
	UIS.InputChanged:Connect(function(input)
		if input == activeTouch then moveTouch(input.Position) end
	end)
	UIS.InputEnded:Connect(function(input)
		keys[input] = nil
		if touchButtons[input] then
			touchButtons[input].BackgroundColor3 = Color3.fromHex("101014")
			touchButtons[input] = nil
		end
		if input == activeTouch then
			activeTouch, touchStick, knob.Position = nil, Vector2.zero, pad.Position
		end
	end)

	local function read()
		if blocked or UIS:GetFocusedTextBox() then return 0, false, false end
		local right, left = has("Right"), has("Left")
		local axis = (if right then 1 else 0) - (if left then 1 else 0)
		if right and left then
			-- Switching side before letting go of the other key must not stop the fighter.
			axis = if lastDirection == "Left" then -1 else 1
		end
		if not right and not left then
			local v = if activeTouch then touchStick.X else stick.X
			axis = if math.abs(v) > Bindings.Deadzone then math.sign(v) * (math.abs(v) - Bindings.Deadzone) / (1 - Bindings.Deadzone) else 0
		end
		local crouch = has("Crouch") or stick.Y < -0.55 or touchStick.Y < -0.55
		return math.clamp(axis, -1, 1), crouch, has("Block")
	end
	local previousAxis, previousCrouch, previousBlock = 0, false, false
	RunService.Heartbeat:Connect(function(dt)
		sinceAxis += dt
		keepalive += dt
		local axis, crouch, block = read()
		local pulse = #presses > 0 or tauntSlot > 0
		for _, pressed in pulses do pulse = pulse or pressed end
		-- Pulses and button changes go out immediately; analog drift is capped at 30 Hz.
		local axisChanged = math.abs(axis - previousAxis) > 0.02 and sinceAxis >= 1 / 30
		if pulse or crouch ~= previousCrouch or block ~= previousBlock or axisChanged or keepalive >= 0.1 then
			sequence += 1
			remote:FireServer({ seq = sequence, axis = axis, crouch = crouch, block = block,
				jump = pulses.jump, dash = pulses.dash, presses = table.clone(presses),
				reset = pulses.reset, dummy = pulses.dummy, ultiConditions = pulses.ultiConditions,
				avatar = pulses.avatar, skin = pulses.skin, kit = pulses.kit, foeKit = pulses.foeKit,
				stance = if pulses.stance2 then 2 elseif pulses.stance1 then 1 else 0,
				cinTick = cinematicTick and cinematicTick() or nil, taunt = if tauntSlot > 0 then tauntSlot else nil,
				tutor = tutorMode })
			tauntSlot = 0
			table.clear(presses)
			previousAxis, previousCrouch, previousBlock, keepalive, sinceAxis = axis, crouch, block, 0, 0
			for k in pulses do pulses[k] = false end
		end
	end)
	return {
		reset = function() pulses.reset = true end,
		toggleDummy = function() pulses.dummy = true end,
		toggleMouseLock = function() setMouseLock(not mouseLocked) end,
		isMouseLocked = function() return mouseLocked end,
		onMouseLock = function(callback) onMouseLock = callback end, -- (the HUD shows the state)
		toggleUltiConditions = function() pulses.ultiConditions = true end, -- training: ki always full
		toggleAvatar = function() pulses.avatar = true end,
		nextSkin = function() pulses.skin = true end,
		nextKit = function() pulses.kit = true end,
		nextFoeKit = function() pulses.foeKit = true end,
		setStance = function(rank) pulses["stance" .. rank] = true end, -- TARO: 1 CLASSIQUE, 2 ESQUIVE
		setCinematicTick = function(source) cinematicTick = source end,
		-- TUTORIAL: what the training dummy does on this step (Tutorial.DUMMIES; nil = off)
		setTutor = function(mode) tutorMode = mode end,
		-- QUICK TRASH TALK: send the taunt of wheel slot `slot` (the server picks the text).
		taunt = function(slot) tauntSlot = slot end,
		suspendMouseLock = function(on) lockSuspended = on end,
		-- What is held right now (axis -1..1, crouch, block): the local fighter is drawn ahead
		-- of the server by it (visual prediction, see the client's presentation loop).
		held = function() return read() end, -- axis, crouch, block
		clear = clear,
		-- The touch ULTI button glows when the ki meter can pay for the ultimate.
		setUltimateReady = function(ready)
			if not ultimateButton then return end
			ultimateButton.BackgroundColor3 = if ready then Color3.fromHex("8C0A1C") else Color3.fromHex("101014")
			ultimateButton.TextTransparency = if ready then 0 else 0.5
		end,
		-- The touch FATAL button only shows while the COUP FATAL can be thrown.
		setFatalReady = function(ready)
			if fatalButton then fatalButton.Visible = ready end
		end,
	}
end
return InputController
