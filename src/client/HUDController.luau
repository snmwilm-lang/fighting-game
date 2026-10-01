-- Manga-style combat HUD in the black / white / red palette of the KAI art direction sheet.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterData = require(Shared.CharacterData)
local MoveData = require(Shared.MoveData)

local HUD = {}

local WHITE = Color3.fromHex("F5F5F7")
local INK = Color3.fromHex("0B0B0E")
local RED = Color3.fromHex("E0102B")
local DISPLAY = Enum.Font.Bangers
local UI_FONT = Enum.Font.GothamBlack

local function new(className, props, parent)
	local i = Instance.new(className)
	for k, v in props do i[k] = v end
	i.Parent = parent
	return i
end

local function stroke(parent, thickness, color)
	return new("UIStroke", { Thickness = thickness, Color = color or INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, parent)
end

local function text(parent, props)
	local l = new("TextLabel", {
		BackgroundTransparency = 1, Font = DISPLAY, TextColor3 = WHITE, TextScaled = false,
		TextSize = 20, Text = "",
	}, parent)
	for k, v in props do l[k] = v end
	return l
end

local function tween(instance, duration, goal, style, direction)
	local t = TweenService:Create(instance, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

function HUD.new(config)
	local self = setmetatable({ config = config, poseRate = config.PoseRate, bars = {}, trail = { 1, 1 }, combo = {} }, { __index = HUD })
	local gui = new("ScreenGui", { Name = "CombatHUD", ResetOnSpawn = false, DisplayOrder = 5, IgnoreGuiInset = false },
		Players.LocalPlayer:WaitForChild("PlayerGui"))
	self.gui = gui

	-- Top header: portraits, health, guard, round pips and timer.
	local header = new("Frame", { Name = "Header", BackgroundTransparency = 1, Size = UDim2.new(1, -24, 0, 104), Position = UDim2.fromOffset(12, 6) }, gui)
	for slot = 1, 2 do
		local data = CharacterData[slot]
		local energy = Color3.fromHex(data.Energy)
		local left = slot == 1
		local side = new("Frame", {
			Name = "Player" .. slot, BackgroundTransparency = 1,
			Size = UDim2.new(0.5, -52, 1, 0), Position = if left then UDim2.new() else UDim2.new(0.5, 52, 0, 0),
		}, header)
		-- Diamond portrait with the character's kanji.
		local portrait = new("Frame", {
			Name = "Portrait", Size = UDim2.fromOffset(54, 54), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45,
			Position = if left then UDim2.fromOffset(36, 40) else UDim2.new(1, -36, 0, 40),
			BackgroundColor3 = INK, BorderSizePixel = 0,
		}, side)
		stroke(portrait, 3, energy)
		text(portrait, { Text = data.Kanji, Rotation = -45, Size = UDim2.fromScale(1, 1), TextSize = 34, TextColor3 = energy, Font = UI_FONT })
		local barX = 76
		local bar = new("Frame", {
			Name = "Health", BackgroundColor3 = INK, BorderSizePixel = 0,
			Size = UDim2.new(1, -barX - 4, 0, 24), AnchorPoint = Vector2.new(if left then 0 else 1, 0),
			Position = if left then UDim2.fromOffset(barX, 30) else UDim2.new(1, -barX, 0, 30),
		}, side)
		stroke(bar, 2, WHITE)
		local trail = new("Frame", { Name = "Trail", BackgroundColor3 = RED, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
			AnchorPoint = Vector2.new(if left then 0 else 1, 0), Position = if left then UDim2.new() else UDim2.fromScale(1, 0) }, bar)
		local fill = new("Frame", { Name = "Fill", BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
			AnchorPoint = Vector2.new(if left then 0 else 1, 0), Position = if left then UDim2.new() else UDim2.fromScale(1, 0) }, bar)
		new("UIGradient", {
			Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, WHITE), ColorSequenceKeypoint.new(0.75, WHITE), ColorSequenceKeypoint.new(1, energy) }),
			Rotation = if left then 0 else 180,
		}, fill)
		local guard = new("Frame", {
			Name = "Guard", BackgroundColor3 = INK, BorderSizePixel = 0,
			Size = UDim2.new(0.6, 0, 0, 6), AnchorPoint = Vector2.new(if left then 0 else 1, 0),
			Position = if left then UDim2.fromOffset(barX, 58) else UDim2.new(1, -barX, 0, 58),
		}, side)
		local guardFill = new("Frame", { BackgroundColor3 = Color3.fromHex(data.Shield), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
			AnchorPoint = Vector2.new(if left then 0 else 1, 0), Position = if left then UDim2.new() else UDim2.fromScale(1, 0) }, guard)
		local name = text(side, {
			Name = "Name", Text = data.Name, TextSize = 26, Size = UDim2.new(0, 120, 0, 26),
			Position = if left then UDim2.fromOffset(barX, 2) else UDim2.new(1, -barX - 120, 0, 2),
			TextXAlignment = if left then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
		})
		stroke(name, 2)
		local player = text(side, {
			Name = "PlayerName", TextSize = 12, Font = UI_FONT, TextColor3 = energy,
			Size = UDim2.new(1, -barX - 130, 0, 20), Position = if left then UDim2.fromOffset(barX + 64, 7) else UDim2.new(0, 0, 0, 7),
			TextXAlignment = if left then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local pips = {}
		for i = 1, config.RoundsToWin do
			local pip = new("Frame", {
				Size = UDim2.fromOffset(12, 12), Rotation = 45, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = INK, BorderSizePixel = 0,
				Position = if left then UDim2.new(1, -12 - (i - 1) * 20, 0, 92) else UDim2.new(0, 12 + (i - 1) * 20, 0, 92),
			}, side)
			stroke(pip, 2, WHITE)
			pips[i] = pip
		end
		-- Ki meter: three bars, the count in big type, and a glow when the ultimate is ready.
		local meter = new("Frame", {
			Name = "Ki", BackgroundTransparency = 1, Size = UDim2.new(0.6, 0, 0, 12), AnchorPoint = Vector2.new(if left then 0 else 1, 0),
			Position = if left then UDim2.fromOffset(barX + 30, 70) else UDim2.new(1, -barX - 30, 0, 70),
		}, side)
		local segments = {}
		for i = 1, config.MaxMeter / config.MeterBar do
			local segment = new("Frame", {
				BackgroundColor3 = INK, BorderSizePixel = 0, Size = UDim2.new(1 / 3, -4, 1, 0),
				Position = if left then UDim2.new((i - 1) / 3, 0, 0, 0) else UDim2.new(1 - i / 3, 4, 0, 0),
			}, meter)
			stroke(segment, 1.5, energy).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			local segmentFill = new("Frame", { BackgroundColor3 = energy, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1),
				AnchorPoint = Vector2.new(if left then 0 else 1, 0), Position = if left then UDim2.new() else UDim2.fromScale(1, 0) }, segment)
			segments[i] = segmentFill
		end
		local count = text(side, {
			Name = "KiCount", Text = "0", TextSize = 30, TextColor3 = energy, Size = UDim2.fromOffset(26, 30),
			Position = if left then UDim2.fromOffset(barX, 62) else UDim2.new(1, -barX - 26, 0, 62),
		})
		stroke(count, 2.5)
		local ready = text(side, {
			Name = "UltimateReady", Text = "ULTIME PRÊT · R", TextSize = 14, Font = UI_FONT, TextColor3 = WHITE, Visible = false,
			Size = UDim2.fromOffset(150, 14), Position = if left then UDim2.fromOffset(barX + 30, 84) else UDim2.new(1, -barX - 180, 0, 84),
			TextXAlignment = if left then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
		})
		stroke(ready, 2, energy)
		self.bars[slot] = { fill = fill, trail = trail, guard = guardFill, player = player, pips = pips, energy = energy,
			segments = segments, kiCount = count, ready = ready }
	end
	local timer = new("Frame", {
		Name = "Timer", Size = UDim2.fromOffset(62, 62), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10),
		BackgroundColor3 = INK, BorderSizePixel = 0, Rotation = 45,
	}, header)
	stroke(timer, 3, WHITE)
	self.timer = text(timer, { Rotation = -45, Size = UDim2.fromScale(1, 1), TextSize = 36, Text = "99" })
	self.round = text(header, { Size = UDim2.fromOffset(120, 18), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 84),
		TextSize = 14, Font = UI_FONT, Text = "ROUND 1" })
	stroke(self.round, 1.5)

	-- Combo counters, one per side (shown on the attacker's side).
	for slot = 1, 2 do
		local left = slot == 1
		local frame = new("Frame", {
			Name = "Combo" .. slot, BackgroundTransparency = 1, Size = UDim2.fromOffset(220, 130), Visible = false,
			AnchorPoint = Vector2.new(if left then 0 else 1, 0.5), Position = if left then UDim2.new(0, 18, 0.4, 0) else UDim2.new(1, -18, 0.4, 0),
		}, gui)
		local scale = new("UIScale", { Scale = 1 }, frame)
		local align = if left then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right
		local count = text(frame, { Size = UDim2.new(1, 0, 0, 74), TextSize = 78, TextXAlignment = align, TextColor3 = self.bars[slot].energy })
		stroke(count, 4)
		local hits = text(frame, { Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 68), TextSize = 30, Text = "HITS !", TextXAlignment = align })
		stroke(hits, 3)
		local detail = text(frame, { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 98), TextSize = 16, Font = UI_FONT, TextXAlignment = align })
		stroke(detail, 2)
		self.combo[slot] = { frame = frame, scale = scale, count = count, detail = detail, expires = 0 }
	end

	-- Announcer.
	local announce = text(gui, {
		Name = "Announcer", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(1, 0, 0, 120), TextSize = 110, Visible = false,
	})
	stroke(announce, 6)
	self.announceScale = new("UIScale", { Scale = 1 }, announce)
	self.announce = announce
	self.announceSub = text(gui, {
		Name = "AnnouncerSub", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.new(1, 0, 0, 34), TextSize = 30, Visible = false, TextColor3 = RED,
	})
	stroke(self.announceSub, 3)

	-- Skill callouts, one per side, slanted like an anime technique name.
	self.callouts = {}
	for slot = 1, 2 do
		local left = slot == 1
		local callout = text(gui, {
			Name = "Skill" .. slot, Visible = false, TextSize = 52, Rotation = if left then -5 else 5,
			Size = UDim2.new(0.5, 0, 0, 60), AnchorPoint = Vector2.new(if left then 0 else 1, 0.5),
			Position = if left then UDim2.new(0, 16, 0.24, 0) else UDim2.new(1, -16, 0.24, 0),
			TextXAlignment = if left then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
			TextColor3 = self.bars[slot].energy,
		})
		stroke(callout, 4, INK)
		self.callouts[slot] = { label = callout, scale = new("UIScale", {}, callout) }
	end

	-- Status and buttons below the header.
	self.status = text(gui, { Name = "Status", Size = UDim2.new(1, -24, 0, 18), Position = UDim2.fromOffset(12, 112), TextSize = 12,
		Font = UI_FONT, TextColor3 = Color3.fromHex("B9B9C2") })
	local x = 12
	local function button(name, label, width, callback)
		local b = new("TextButton", {
			Name = name, Text = label, Size = UDim2.fromOffset(width, 28), Position = UDim2.fromOffset(x, 134),
			Font = UI_FONT, TextSize = 11, TextColor3 = WHITE, BackgroundColor3 = INK, AutoButtonColor = true,
		}, gui)
		stroke(b, 1.5, RED).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		b.Activated:Connect(callback)
		x += width + 8
		return b
	end
	local poseButton
	poseButton = button("PoseRate", "POSES : 15/s", 108, function()
		local rates = { 12, 15, 24, 60 }
		local current = table.find(rates, self.poseRate) or 1
		self.poseRate = rates[current % #rates + 1]
		poseButton.Text = if self.poseRate >= 60 then "POSES : FLUIDE" else "POSES : " .. self.poseRate .. "/s"
	end)
	self.effectsButton = button("Effects", "EFFETS : FORTS", 118, function()
		if self.onEffects then self.effectsButton.Text = if self.onEffects() then "EFFETS : RÉDUITS" else "EFFETS : FORTS" end
	end)
	self.debugButton = button("Hitboxes", "HITBOX : NON", 104, function()
		if self.onDebug then self.debugButton.Text = if self.onDebug() then "HITBOX : OUI" else "HITBOX : NON" end
	end)
	self.dummyButton = button("Dummy", "MANNEQUIN (M)", 170, function()
		if self.onDummy then self.onDummy() end
	end)
	self.resetButton = button("Reset", "REPLACER", 84, function()
		if self.onReset then self.onReset() end
	end)
	self.avatarButton = button("Avatar", "APPARENCE : KAI", 140, function()
		if self.onAvatar then self.onAvatar() end
	end)
	self.combosButton = button("Combos", "COMBOS", 76, function()
		self.combosPanel.Visible = not self.combosPanel.Visible
	end)

	-- Combo routes panel (from MoveData.Routes) plus special, ultimate and air follow-ups.
	local panel = new("Frame", {
		Name = "CombosPanel", Visible = false, BackgroundColor3 = INK, BackgroundTransparency = 0.1, BorderSizePixel = 0,
		Size = UDim2.fromOffset(360, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.fromOffset(12, 170),
	}, gui)
	stroke(panel, 2, RED).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingTop = UDim.new(0, 8) }, panel)
	new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, panel)
	local lines = { { "COMBOS  ·  L = clic gauche, R = clic droit", RED } }
	for _, route in MoveData.Routes do
		local names = {}
		for _, id in route.moves do table.insert(names, MoveData.Moves[id].name) end
		table.insert(lines, { route.keys .. "  →  " .. table.concat(names, " > "), WHITE })
	end
	table.insert(lines, { "ROUTES COMPLÈTES (6 appuis, fin : POURSUITE > GRÂCE)", RED })
	for _, route in MoveData.FullRoutes do
		table.insert(lines, { route.keys .. "  →  " .. route.name, WHITE })
	end
	table.insert(lines, { "3 barres + 6e coup : ÉVEIL ÉCARLATE (−95 % de la vie ; < 50 % : FINAL FINISH)", Color3.fromHex("FF2A3D") })
	table.insert(lines, { "↓ + L : KICK BAS (garde basse)  ·  ↓ + R : LANCEUR", WHITE })
	table.insert(lines, { "Après LANCEUR : ESPACE puis L L R en l'air", WHITE })
	table.insert(lines, { "E après un coup : RISING STRIKE (invincible)", Color3.fromHex("FFB938") })
	table.insert(lines, { "↓ + E : KIKOHO (boule de ki, 1 à la fois)", Color3.fromHex("FFB938") })
	table.insert(lines, { "★ = skill : alterne clic gauche / clic droit", Color3.fromHex("FFD23F") })
	table.insert(lines, { "R (2 barres de ki) : KAIEN RUSH → cinématique", Color3.fromHex("FF2A3D") })
	table.insert(lines, { "1 seul effondrement, rebond sol et rebond mur par combo", Color3.fromHex("B9B9C2") })
	for i, line in lines do
		local l = text(panel, { Text = line[1], TextColor3 = line[2], Font = if i == 1 then DISPLAY else UI_FONT,
			TextSize = if i == 1 then 20 else 12, Size = UDim2.new(1, -10, 0, if i == 1 then 24 else 20),
			TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = i, TextWrapped = true })
		l.AutomaticSize = Enum.AutomaticSize.Y
	end
	self.combosPanel = panel

	self.help = text(gui, { Name = "Help", Size = UDim2.new(1, -24, 0, 22), Position = UDim2.new(0, 12, 1, -30), TextSize = 13,
		Font = UI_FONT, TextColor3 = Color3.fromHex("D6D6DC") })
	stroke(self.help, 1.5)
	local function updateHelp()
		local gamepad = UIS.PreferredInput == Enum.PreferredInput.Gamepad
		self.help.Visible = not UIS.TouchEnabled
		self.help.Text = if gamepad
			then "STICK : bouger · A : saut · X : coup · B : lourd · Y : spéciale · LT : ultime · RB : garde · RT : dash · SELECT : replacer"
			else "Q/A · D : bouger · ESPACE : saut · S : bas · CLIC G : coup · CLIC D : lourd · E : spéciale · R : ultime · F : garde · SHIFT : dash"
	end
	UIS:GetPropertyChangedSignal("PreferredInput"):Connect(updateHelp)
	updateHelp()
	return self
end

function HUD:setEffectsReduced(reduced)
	self.effectsButton.Text = if reduced then "EFFETS : RÉDUITS" else "EFFETS : FORTS"
end

function HUD:announceText(main, sub, color)
	local a = self.announce
	a.Text, a.TextColor3, a.Visible, a.TextTransparency = main, color or WHITE, true, 0
	self.announceScale.Scale = 2.4
	tween(self.announceScale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	self.announceSub.Text, self.announceSub.Visible = sub or "", sub ~= nil
	self.announceId = (self.announceId or 0) + 1
	local id = self.announceId
	task.delay(1.3, function()
		if self.announceId ~= id then return end
		tween(a, 0.25, { TextTransparency = 1 })
		self.announceSub.Visible = false
	end)
end

-- Rounds are announced from the snapshot phase so a client joining mid-intro still sees it.
function HUD:announceRound(round)
	self:announceText("ROUND " .. round, CharacterData[1].Name .. " " .. CharacterData[1].Skin .. "  VS  "
		.. CharacterData[2].Name .. " " .. CharacterData[2].Skin)
end

function HUD:onEvent(event, world)
	if event.kind == "Hit" and event.combo and event.combo >= 2 then
		local c = self.combo[event.attacker]
		c.frame.Visible = true
		c.count.Text = tostring(event.combo)
		local m = MoveData.Moves[event.move]
		c.detail.Text = (if m and m.heavy then m.name .. " · " else "") .. event.comboDamage .. " DÉGÂTS"
		c.scale.Scale = 1.5
		tween(c.scale, 0.15, { Scale = 1 }, Enum.EasingStyle.Back)
		c.expires = os.clock() + 1.4
	elseif event.kind == "Skill" then
		local callout = self.callouts[event.attacker]
		local m = MoveData.Moves[event.move]
		callout.label.Text = (if m then m.name else event.move) .. " !"
		callout.label.Visible, callout.label.TextTransparency = true, 0
		callout.scale.Scale = 1.8
		tween(callout.scale, 0.16, { Scale = 1 }, Enum.EasingStyle.Back)
		local id = (callout.id or 0) + 1
		callout.id = id
		task.delay(1.1, function()
			if callout.id ~= id then return end
			tween(callout.label, 0.25, { TextTransparency = 1 })
		end)
	elseif event.kind == "GuardBreak" then
		self:announceText("GUARD BREAK", nil, Color3.fromHex("FFD23F"))
	elseif event.kind == "Fight" then
		self:announceText("FIGHT !", nil, RED)
	elseif event.kind == "RoundEnd" then
		local main = if event.reason == "Timeout" then "TIME OVER" elseif event.winner == 0 then "DOUBLE K.O." else "K.O."
		local sub
		if not world.training then
			sub = if event.winner == 0 then "ÉGALITÉ" else CharacterData[event.winner].Name .. " " .. CharacterData[event.winner].Skin .. " GAGNE LE ROUND"
			if event.perfect then sub = "PERFECT ! " .. sub end
		end
		self:announceText(main, sub, if main == "K.O." then RED else WHITE)
	elseif event.kind == "MatchEnd" then
		local main = if event.winner == 0 then "MATCH NUL" else CharacterData[event.winner].Name .. " GAGNE !"
		self:announceText(main, "VICTOIRE", RED)
	end
end

-- Called every rendered frame with the latest authoritative snapshot.
function HUD:update(world, views, fps, dt)
	if not views[1] or not views[2] then return end
	local localSlot = Players.LocalPlayer:GetAttribute("FighterSlot") or 0
	local maxHealth = self.config.MaxHealth
	for slot, view in views do
		local bar = self.bars[slot]
		local ratio = math.clamp(view.hp / maxHealth, 0, 1)
		bar.fill.Size = UDim2.fromScale(ratio, 1)
		-- The red trail waits while the combo continues, then catches up.
		if view.combo == 0 or self.trail[slot] < ratio then
			self.trail[slot] = math.max(ratio, self.trail[slot] - dt * 0.6)
		end
		bar.trail.Size = UDim2.fromScale(self.trail[slot], 1)
		bar.guard.Size = UDim2.fromScale(math.clamp(view.guard / self.config.MaxGuard, 0, 1), 1)
		bar.player.Text = (if localSlot == slot then "VOUS · " else "") .. view.player
		for i, pip in bar.pips do
			pip.BackgroundColor3 = if view.wins >= i then bar.energy else INK
		end
		local bars = self.config.MeterBar
		for i, segment in bar.segments do
			segment.Size = UDim2.fromScale(math.clamp((view.meter - (i - 1) * bars) / bars, 0, 1), 1)
		end
		bar.kiCount.Text = tostring(math.floor(view.meter / bars))
		local ready = view.meter >= MoveData.Moves.KaienRush.meterCost
		bar.ready.Visible = ready
		bar.ready.Text = if view.meter >= MoveData.Moves.Awakening.meterCost then "ÉVEIL PRÊT · 6e COUP" else "ULTIME PRÊT · R"
		if ready then bar.ready.TextTransparency = 0.25 + 0.25 * math.sin(os.clock() * 8) end
	end
	for _, c in self.combo do
		if c.frame.Visible and os.clock() > c.expires then c.frame.Visible = false end
	end
	self.timer.Text = if world.timer < 0 then "∞" else tostring(world.timer)
	self.round.Text = if world.training then "ENTRAÎNEMENT" else "ROUND " .. world.round
	local solo = world.solo
	self.resetButton.Visible = solo and localSlot > 0
	self.dummyButton.Visible = solo and localSlot > 0
	self.dummyButton.Text = "MANNEQUIN : " .. world.dummyMode .. " (M)"
	self.avatarButton.Visible = localSlot > 0
	self.avatarButton.Text = if Players.LocalPlayer:GetAttribute("Avatar") then "APPARENCE : MON AVATAR" else "APPARENCE : KAI"
	self.status.Text = string.format("v%s · %s · %d FPS", self.config.Version,
		if localSlot == 0 then "SPECTATEUR" elseif world.training then "ENTRAÎNEMENT"
			elseif solo then "VS " .. world.dummyMode else "VERSUS", math.floor(fps + 0.5))
end

return HUD
