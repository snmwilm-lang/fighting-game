local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local HUD = {}
function HUD.new(config)
	local self = { poseRate = config.PoseRate, labels = {} }
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "CombatHUD", false, 5
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local function label(parent, name, text, size, position, textSize, color)
		local l = Instance.new("TextLabel")
		l.Name, l.Text, l.Size, l.Position = name, text, size, position
		l.BackgroundTransparency = 1
		l.Font, l.TextSize, l.TextColor3 = Enum.Font.GothamBold, textSize, color or Color3.fromHex("EFF6FF")
		l.TextTruncate = Enum.TextTruncate.AtEnd
		l.Parent = parent
		return l
	end
	local top = Instance.new("Frame")
	top.Name, top.Size, top.Position = "Header", UDim2.new(1, -28, 0, 84), UDim2.fromOffset(14, 10)
	top.BackgroundColor3, top.BackgroundTransparency, top.BorderSizePixel = Color3.fromHex("0C1222"), 0.12, 0
	top.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius, corner.Parent = UDim.new(0, 12), top
	label(top, "Title", "RIFT // FIGHT LAB", UDim2.new(1, 0, 0, 24), UDim2.fromOffset(0, 6), 16)
	for i = 1, 2 do
		local color = Color3.fromHex(if i == 1 then "52F2D6" else "FF895A")
		self.labels[i] = label(top, "Player" .. i, "...", UDim2.new(0.44, 0, 0, 24),
			UDim2.fromScale(if i == 1 then 0.02 else 0.54, 0.37), 15, color)
		self.labels[i + 2] = label(top, "State" .. i, "IDLE", UDim2.new(0.44, 0, 0, 20),
			UDim2.fromScale(if i == 1 then 0.02 else 0.54, 0.67), 12)
	end
	label(top, "VS", "VS", UDim2.fromScale(0.08, 0.5), UDim2.fromScale(0.46, 0.4), 14)
	self.status = label(gui, "Status", "Connexion au terrain…", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 99), 12)
	local function button(name, text, x, width, callback)
		local b = Instance.new("TextButton")
		b.Name, b.Text = name, text
		b.Size, b.Position = UDim2.fromOffset(width, 32), UDim2.fromOffset(x, 126)
		b.Font, b.TextSize = Enum.Font.GothamBold, 11
		b.TextColor3, b.BackgroundColor3 = Color3.fromHex("EFF6FF"), Color3.fromHex("26344F")
		b.Parent = gui
		local round = Instance.new("UICorner")
		round.CornerRadius, round.Parent = UDim.new(0, 7), b
		b.Activated:Connect(callback)
		return b
	end
	local poseButton
	poseButton = button("PoseRate", "POSES : 15/s", 16, 126, function()
		local rates = { 12, 15, 24, 60 }
		local current = table.find(rates, self.poseRate) or 1
		self.poseRate = rates[current % #rates + 1]
		poseButton.Text = "POSES : " .. self.poseRate .. "/s"
	end)
	self.resetButton = button("Reset", "REPLACER · SOLO", 152, 150, function()
		if self.onReset then self.onReset() end
	end)
	self.help = label(gui, "Help", "", UDim2.new(1, -24, 0, 28), UDim2.new(0, 12, 1, -34), 12)
	local function updateHelp()
		local gamepad = UIS.PreferredInput == Enum.PreferredInput.Gamepad
		self.help.Visible = not UIS.TouchEnabled
		self.help.Text = if gamepad then "STICK / CROIX : bouger    A / ↑ : saut    ↓ : bas    RT : dash    Y : replacer (solo)"
			else "Q/A · D : bouger    ESPACE : saut    S : bas    SHIFT : dash    R : replacer (solo)"
	end
	UIS:GetPropertyChangedSignal("PreferredInput"):Connect(updateHelp)
	updateHelp()
	return setmetatable(self, { __index = HUD })
end
function HUD:update(fighters, fps)
	if not fighters[1] or not fighters[2] then return end
	local localSlot = Players.LocalPlayer:GetAttribute("FighterSlot") or 0
	for i, f in fighters do
		self.labels[i].Text = (if localSlot == i then "VOUS · " else "") .. f.name
		self.labels[i + 2].Text = string.upper(f.state) .. "  /  X " .. string.format("%.1f", f.x)
	end
	local solo = fighters[1].owner == 0 or fighters[2].owner == 0
	self.resetButton.Visible = solo and localSlot > 0
	self.status.Text = string.format("PHASE 01 · %s · %d FPS · mouvement uniquement",
		if localSlot == 0 then "SPECTATEUR" elseif solo then "ENTRAÎNEMENT" else "2 JOUEURS", math.floor(fps + 0.5))
end
return HUD
