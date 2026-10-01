--[[
	Staging of every cinematic moment. The simulation decides everything (hits, damage, KO,
	duration, rhythm prompts); this module only directs it:

	  KAIEN RUSH        ultimate 1 (R alone): blinking rush around the target.
	  ÉVEIL ÉCARLATE    ultimate 2 (clean full route ending on the right click): eyes, aura,
	                    strikes from many angles, then one of six finales picked by the route.
	  PORTE DES CIEUX   ultimate 3 (clean full route ending on the R key): a giant torii drags
	                    the target into a crimson world for a single blow.
	  K.O. SCENE        FINAL FINISH and match-winning K.O.: loser on the floor in the
	                    foreground, winner standing (low angle), hand on the floor, feet,
	                    face, arms crossed, back, wide arena shot, fade to black.

	Shots are described with points tied to rig parts (Head, RightHand, LeftFoot...), resolved
	after the rigs are placed, so framing works on KAI and on any Roblox avatar alike.
	The camera returns to the fight camera as soon as nothing is staged, or if snapshots stop
	arriving (disconnect), so it can never stay stuck.
]]
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local MoveData = require(Shared.MoveData)
local CharacterData = require(Shared.CharacterData)

local CinematicController = {}

local WHITE = Color3.fromHex("F5F5F7")
local INK = Color3.fromHex("0B0B0E")
local RED = Color3.fromHex("E0102B")
local GOLD = Color3.fromHex("FFD23F")
-- Rush poses cycle through the active frames of the normals while KAI blinks around the target.
local RUSH = { "Jab", "Cross", "Kick", "Elbow", "AirKick", "SpinKick", "BodyBlow", "Uppercut", "AirKick2", "KiFlurry" }
local STYLE_COLORS = {
	TORNADE = Color3.fromHex("FF2A3D"), RAFALE = Color3.fromHex("FF7A2A"), DRAGON = Color3.fromHex("FF2A3D"),
	FOUDRE = Color3.fromHex("8FD8FF"), MUR = Color3.fromHex("FF2A3D"), LUNE = Color3.fromHex("FFE9B0"),
}
local KO_SCENE = 200 -- ticks, same as the FINAL FINISH extension
local PROMPT_LABEL = { Light = "CLIC G", Heavy = "CLIC D", Ultimate = "R" }

local function tween(instance, duration, goal, style, direction)
	local t = TweenService:Create(instance, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

local function new(className, props, parent)
	local i = Instance.new(className)
	for k, v in props do i[k] = v end
	i.Parent = parent
	return i
end

local function hitsBefore(hits, tick)
	local n = 0
	for _, t in hits do
		if t <= tick then n += 1 end
	end
	return n
end

local function lerp(a, b, t)
	return a + (b - a) * math.clamp(t, 0, 1)
end

local function progress(tick, from, to)
	return math.clamp((tick - from) / math.max(1, to - from), 0, 1)
end

-- A point of a shot: a rig part of a fighter plus a world offset, or a fixed position.
local function P(slot, part, offset)
	return { slot = slot, part = part, offset = offset or Vector3.zero }
end
local function At(position)
	return { position = position }
end

-- shot = { name, from, to, fov, roll, focus }: `from`/`to`/`focus` are points.
local function shot(name, from, to, fov, roll, focus)
	return { name = name, from = from, to = to, fov = fov, roll = roll or 0, focus = focus or to }
end

function CinematicController.new(config, hud, effects)
	local self = setmetatable({
		config = config, hud = hud, effects = effects, active = false, shake = 0, shot = nil,
		props = {},
	}, { __index = CinematicController })
	local gui = new("ScreenGui", { Name = "Cinematic", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20 },
		Players.LocalPlayer:WaitForChild("PlayerGui"))
	self.gui = gui
	self.kanjiBack = new("TextLabel", {
		BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, Text = "", Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.72, 0.5), Size = UDim2.fromScale(0.5, 0.9),
		TextColor3 = RED, TextTransparency = 0.35,
	}, gui)
	self.top = new("Frame", { BackgroundColor3 = INK, BorderSizePixel = 0, Size = UDim2.fromScale(1, 0) }, gui)
	self.bottom = new("Frame", { BackgroundColor3 = INK, BorderSizePixel = 0, Size = UDim2.fromScale(1, 0),
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1) }, gui)
	self.flashFrame = new("Frame", { BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui)
	self.fade = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5 }, gui)

	-- Cut-in banner: tilted ink band, giant kanji, character and move names.
	local banner = new("Frame", {
		Name = "CutIn", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(1.4, 0, 0.3, 0),
		Position = UDim2.fromScale(-1, 0.5), Rotation = -6, BackgroundColor3 = INK, BorderSizePixel = 0, Visible = false,
	}, gui)
	new("UIGradient", { Rotation = 0, Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.2, 0), NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 0.6),
	}) }, banner)
	self.bannerStripe = new("Frame", { BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 8), Position = UDim2.new(0, 0, 1, -8) }, banner)
	self.bannerStripeTop = new("Frame", { BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 8) }, banner)
	self.kanji = new("TextLabel", {
		BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, Text = "",
		Size = UDim2.fromScale(0.22, 1.25), Position = UDim2.fromScale(0.2, -0.12), TextTransparency = 0.05,
	}, banner)
	self.charName = new("TextLabel", {
		BackgroundTransparency = 1, Font = Enum.Font.Bangers, TextScaled = true, TextColor3 = WHITE,
		Size = UDim2.fromScale(0.3, 0.34), Position = UDim2.fromScale(0.43, 0.08), TextXAlignment = Enum.TextXAlignment.Left,
	}, banner)
	self.moveName = new("TextLabel", {
		BackgroundTransparency = 1, Font = Enum.Font.Bangers, TextScaled = true,
		Size = UDim2.fromScale(0.42, 0.46), Position = UDim2.fromScale(0.43, 0.44), TextXAlignment = Enum.TextXAlignment.Left,
	}, banner)
	new("UIStroke", { Thickness = 3, Color = WHITE }, self.moveName)
	self.banner = banner

	self.stamp = new("TextLabel", {
		BackgroundTransparency = 1, Font = Enum.Font.Bangers, TextSize = 90, TextColor3 = WHITE, Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.8), Size = UDim2.new(1, 0, 0, 100), Rotation = -4,
	}, gui)
	new("UIStroke", { Thickness = 6, Color = INK }, self.stamp)
	self.stampScale = new("UIScale", {}, self.stamp)
	self.title = new("TextLabel", {
		BackgroundTransparency = 1, Font = Enum.Font.Bangers, TextSize = 150, TextColor3 = RED, Visible = false, ZIndex = 6,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.new(1, 0, 0, 160), Rotation = -3,
	}, gui)
	new("UIStroke", { Thickness = 8, Color = WHITE }, self.title)
	self.titleScale = new("UIScale", {}, self.title)
	self.subtitle = new("TextLabel", {
		BackgroundTransparency = 1, Font = Enum.Font.Bangers, TextSize = 46, TextColor3 = WHITE, Visible = false, ZIndex = 6,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.new(1, 0, 0, 50),
	}, gui)
	new("UIStroke", { Thickness = 4, Color = INK }, self.subtitle)

	-- Rhythm prompt: key in a circle, and a ring closing in on the perfect moment.
	local prompt = new("Frame", {
		Name = "Prompt", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.7),
		Size = UDim2.fromOffset(110, 110), BackgroundColor3 = INK, BackgroundTransparency = 0.15, Visible = false, ZIndex = 4,
	}, gui)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, prompt)
	new("UIStroke", { Thickness = 4, Color = WHITE }, prompt)
	self.promptLabel = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Enum.Font.Bangers, TextSize = 34,
		TextColor3 = WHITE, ZIndex = 4,
	}, prompt)
	local ring = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(2, 2),
		BackgroundTransparency = 1, ZIndex = 4,
	}, prompt)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
	self.promptRingStroke = new("UIStroke", { Thickness = 5, Color = RED }, ring)
	self.prompt, self.promptRing = prompt, ring
	self.promptResult = new("TextLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.58),
		Size = UDim2.new(1, 0, 0, 50), Font = Enum.Font.Bangers, TextSize = 44, Visible = false, ZIndex = 4,
	}, gui)
	new("UIStroke", { Thickness = 4, Color = INK }, self.promptResult)

	local function grade(name, props)
		return new("ColorCorrectionEffect", props, Lighting)
	end
	self.darken = grade("SuperFlash", { Name = "SuperFlash", Enabled = false, Brightness = -0.22, Saturation = -0.55, Contrast = 0.2 })
	self.crimson = grade("Crimson", { Name = "Crimson", Enabled = false, TintColor = Color3.fromRGB(255, 120, 125), Contrast = 0.3, Saturation = 0.15, Brightness = -0.05 })
	self.void = grade("Void", { Name = "Void", Enabled = false, TintColor = Color3.fromRGB(255, 70, 80), Contrast = 0.55, Saturation = -0.3, Brightness = -0.28 })
	self.mono = grade("FinishMono", { Name = "FinishMono", Enabled = false, Saturation = -1, Contrast = 0.6, Brightness = 0.02 })
	self.dof = new("DepthOfFieldEffect", { Name = "CinematicDoF", Enabled = false, FarIntensity = 0.65, NearIntensity = 0.35, InFocusRadius = 4 }, Lighting)
	return self
end

-- Super flash: dim the world and slide the cut-in across the screen.
function CinematicController:superFlash(slot, moveId)
	local data = CharacterData[slot]
	local energy = Color3.fromHex(data.Energy)
	local m = MoveData.Moves[moveId or "KaienRush"]
	self.kanji.Text, self.kanji.TextColor3 = data.Kanji, energy
	self.charName.Text = data.Name .. " · " .. data.Skin
	self.moveName.Text, self.moveName.TextColor3 = m.name, energy
	self.bannerStripe.BackgroundColor3, self.bannerStripeTop.BackgroundColor3 = energy, energy
	self.banner.Visible, self.banner.Position = true, UDim2.fromScale(-0.8, 0.5)
	self.darken.Enabled = not self.effects.reduced
	tween(self.banner, 0.14, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Quart)
	local id = (self.flashId or 0) + 1
	self.flashId = id
	task.delay(0.52, function()
		if self.flashId ~= id then return end
		tween(self.banner, 0.12, { Position = UDim2.fromScale(1.8, 0.5) }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
		self.darken.Enabled = false
	end)
end

function CinematicController:begin(kind)
	self.active, self.kind = true, kind
	self.hud.gui.Enabled = false
	self.titleShown, self.memo = nil, {}
	self.gateX, self.wallX, self.koSide = nil, nil, nil
	tween(self.top, 0.18, { Size = UDim2.fromScale(1, 0.12) })
	tween(self.bottom, 0.18, { Size = UDim2.fromScale(1, 0.12) })
end

function CinematicController:finish()
	self.active, self.shot, self.kind, self.dir = false, nil, nil, nil
	self.hud.gui.Enabled = true
	for _, effect in { self.darken, self.crimson, self.void, self.mono, self.dof } do effect.Enabled = false end
	self.stamp.Visible, self.title.Visible, self.subtitle.Visible, self.kanjiBack.Visible = false, false, false, false
	self.prompt.Visible, self.promptResult.Visible = false, false
	tween(self.fade, 0.4, { BackgroundTransparency = 1 })
	tween(self.top, 0.25, { Size = UDim2.fromScale(1, 0) })
	tween(self.bottom, 0.25, { Size = UDim2.fromScale(1, 0) })
	for _, prop in self.props do
		if typeof(prop) == "Instance" then prop:Destroy() end
	end
	self.props = {}
end

-- Runs `fn` once per staged moment (memo keys are reset at every new cinematic).
function CinematicController:once(key, fn)
	if self.memo[key] then return end
	self.memo[key] = true
	fn()
end

function CinematicController:flash(duration)
	if self.effects.reduced then return end
	self.flashFrame.BackgroundTransparency = 0
	tween(self.flashFrame, duration or 0.35, { BackgroundTransparency = 1 })
end

function CinematicController:showStamp(text, color)
	self.stamp.Text, self.stamp.TextColor3 = text, color
	self.stamp.Visible = true
	self.stampScale.Scale = 2.2
	tween(self.stampScale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
end

function CinematicController:showTitle(text, color, subtitle)
	if self.titleShown == text then return end
	self.titleShown = text
	self.title.Text, self.title.TextColor3, self.title.Visible = text, color, true
	self.titleScale.Scale = 3
	tween(self.titleScale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	self.subtitle.Text, self.subtitle.Visible = subtitle or "", subtitle ~= nil
end

function CinematicController:hideTitle()
	self.title.Visible, self.subtitle.Visible, self.titleShown = false, false, nil
end

function CinematicController:onHit(event)
	local reduced = self.effects.reduced
	self.shake = math.max(self.shake, (if event.heavy then 1.6 else 0.4) * (if reduced then 0.4 else 1))
	if event.heavy then
		self:flash()
		local m = MoveData.Moves[event.move]
		self:showStamp((if m then m.name else event.move) .. " !!", Color3.fromHex(CharacterData[event.attacker].Energy))
		if event.move ~= "KaienRush" and not reduced then
			self.mono.Enabled = true -- manga impact: one black-and-white beat
			task.delay(0.14, function()
				if self.kind ~= "ko" then self.mono.Enabled = false end
			end)
		end
	end
end

function CinematicController:onPrompt(event)
	if event.attacker ~= (Players.LocalPlayer:GetAttribute("FighterSlot") or 0) and not self.showAllPrompts then
		-- Prompts of the CPU or the other player are shown smaller, as information.
		self.promptResult.TextSize = 30
	else
		self.promptResult.TextSize = 44
	end
	self.promptResult.Text = if event.success then "PARFAIT !" else "RATÉ"
	self.promptResult.TextColor3 = if event.success then GOLD else Color3.fromHex("8A8A96")
	self.promptResult.Visible = true
	local id = (self.promptId or 0) + 1
	self.promptId = id
	task.delay(0.4, function()
		if self.promptId == id then self.promptResult.Visible = false end
	end)
end

function CinematicController:onGrade(event)
	local color = if event.grade == "PARFAIT" then GOLD elseif event.grade == "GRAND" then WHITE else Color3.fromHex("8A8A96")
	self:showStamp("RYTHME : " .. event.grade, color)
end

-- Ring closing in on the next prompt. Only the attacker's controller decides; this is a hint.
function CinematicController:updatePrompt(cin, tick)
	local prompts = cin.prompts
	local nextPrompt = prompts and prompts[cin.nextPrompt]
	if not nextPrompt or tick < nextPrompt.tick - 30 then
		self.prompt.Visible = false
		return
	end
	local t = (nextPrompt.tick - tick) / 30
	self.prompt.Visible = true
	self.promptLabel.Text = PROMPT_LABEL[nextPrompt.button] or nextPrompt.button
	self.promptRing.Size = UDim2.fromScale(1 + math.max(0, t) * 1.4, 1 + math.max(0, t) * 1.4)
	self.promptRingStroke.Color = if math.abs(tick - nextPrompt.tick) <= 3 then GOLD else RED
end

-- ===================================================================== KAIEN RUSH

function CinematicController:directRush(cin, a, d, tick, dir)
	local data = MoveData.Cinematics.KaienRush
	local A, D = cin.attacker, cin.defender
	local k = hitsBefore(data.Hits, tick)
	if tick < data.FinalTick - 16 then
		if k == 0 then
			a.x, a.state, a.move = d.x - dir * 2.8, "Attack", "KaienRush"
			a.moveFrame = MoveData.Moves.KaienRush.startup + 1
		else
			local behind = k % 2 == 0
			a.x = d.x + (if behind then dir else -dir) * 2.6
			a.y = if k % 3 == 0 then 1.6 else 0
			a.facing = if behind then -dir else dir
			a.state, a.move = "Attack", RUSH[(k - 1) % #RUSH + 1]
			a.moveFrame = MoveData.Moves[a.move].startup + 1
		end
		d.state = "Hitstun"
		d.hitstop = if k > 0 and tick - data.Hits[k] < 6 then 1 else 0
		a.ghost = true
	elseif tick < data.FinalTick then
		a.x, a.y, a.facing = d.x - dir * 2.8, 0, dir
		a.state, a.move, a.moveFrame = "Attack", "Smash", MoveData.Moves.Smash.startup
		d.state, d.hitstop = "Hitstun", 0
	else
		a.x, a.y, a.facing = d.x - dir * 2.8, 0, dir
		a.state, a.move = "Attack", "Smash"
		a.moveFrame = MoveData.Moves.Smash.startup + 1
	end
	if tick < data.Hits[1] then
		return shot("closeup", P(A, "Head", Vector3.new(dir * 3.4, -0.6, 5.5)), P(A, "Head"), 30)
	elseif tick < data.FinalTick - 16 then
		local angle = -1.15 + 2.3 * progress(tick, data.Hits[1], data.FinalTick - 16)
		return shot("orbit", P(D, "UpperTorso", Vector3.new(math.sin(angle) * 12, 2.5 + math.sin(angle * 2) * 1.5, math.cos(angle) * 12)),
			P(D, "UpperTorso"), 46)
	elseif tick < data.FinalTick then
		return shot("windup", P(A, "UpperTorso", Vector3.new(-dir * 5.5, -1.8, 5.5)), P(D, "UpperTorso"),
			38 - 10 * progress(tick, data.FinalTick - 16, data.FinalTick))
	elseif tick < data.FinalTick + 10 then
		return shot("impact", P(D, "UpperTorso", Vector3.new(-dir * 1.5, 0.4, 7)), P(D, "UpperTorso"), 52)
	end
	return shot("wide", P(D, "UpperTorso", Vector3.new(-dir * 6, 5, 30)), P(D, "UpperTorso"), 42)
end

-- ===================================================================== ÉVEIL ÉCARLATE

-- Finale of ÉVEIL ÉCARLATE, picked by the route that was played (ticks 122 → 174).
function CinematicController:directStyle(cin, a, d, tick, dir, style)
	local data = MoveData.Cinematics.Awakening
	local A, D = cin.attacker, cin.defender
	local color = STYLE_COLORS[style] or RED
	local start, final = data.Hits[#data.Hits] + 4, data.FinalTick
	local p = progress(tick, start, final)
	d.state = "Hitstun"
	if style == "TORNADE" then
		-- Rising spin: both fighters climb inside a tornado of ki.
		d.y = lerp(0, 9, p)
		a.x, a.y, a.facing = d.x - dir * 1.8, d.y - 0.5, dir
		a.state, a.move = "Attack", "DragonTornado"
		a.moveFrame = MoveData.Moves.DragonTornado.startup + 1 + (math.floor(tick / 4) % 2) * MoveData.Moves.DragonTornado.hitInterval
		if tick % 6 == 0 then self.effects:tornadoRing(Vector3.new(d.x, d.y + 1, 0), color) end
		local angle = tick * 0.12
		return shot("style-tornado", P(D, "UpperTorso", Vector3.new(math.sin(angle) * 11, 1, math.cos(angle) * 11)), P(D, "UpperTorso"), 50)
	elseif style == "RAFALE" then
		-- Barrage: a hundred fists in front of the target.
		a.x, a.y, a.facing = d.x - dir * 2.2, 0, dir
		a.state, a.move = "Attack", "KiFlurry"
		a.moveFrame = MoveData.Moves.KiFlurry.startup + 1 + (math.floor(tick / 2) % 2) * MoveData.Moves.KiFlurry.hitInterval
		if tick % 3 == 0 then
			self.effects:spark(Vector3.new(d.x - dir * 0.6 + (math.random() - 0.5), 3 + math.random() * 1.6, 0.5), color, 0.7)
		end
		if p < 0.5 then
			return shot("style-rafale-front", P(D, "Head", Vector3.new(-dir * 4, 0.2, 2.5)), P(A, "UpperTorso"), 40, math.rad(-6))
		end
		return shot("style-rafale-side", P(A, "UpperTorso", Vector3.new(dir * 1, 0.5, 9)), P(D, "UpperTorso"), 36)
	elseif style == "DRAGON" then
		-- Crouched charge, then the rising dragon fist with a ki dragon spiralling up.
		a.x, a.facing = d.x - dir * 1.6, dir
		if p < 0.7 then
			a.y, a.state, a.move, a.moveFrame = 0, "Attack", "DragonFist", MoveData.Moves.DragonFist.startup
			self:once("dragon-charge", function() self.effects:spark(Vector3.new(a.x, 2, 0), color, 1.6) end)
			return shot("style-dragon-charge", P(A, "Head", Vector3.new(dir * 2.5, -1.6, 4)), P(A, "Head"), 34, math.rad(8 * dir))
		end
		local q = progress(tick, start + (final - start) * 0.7, final)
		a.y, d.y = lerp(0, 6, q), lerp(0, 11, q)
		a.state, a.move = "Attack", "DragonFist"
		a.moveFrame = MoveData.Moves.DragonFist.startup + 1
		self:once("dragon-helix", function() self.effects:dragonHelix(Vector3.new(d.x, 0, 0), color) end)
		return shot("style-dragon-rise", At(Vector3.new(d.x - dir * 3, 0.4, 6)), P(D, "UpperTorso"), 62, math.rad(12 * dir))
	elseif style == "FOUDRE" then
		-- Leap into the storm, dive with lightning.
		if p < 0.65 then
			a.x, a.y, a.facing = d.x - dir * 1.5, lerp(1, 12, p / 0.65), dir
			a.state, a.move, a.moveFrame = "Attack", "AirSmash", 1
			if tick % 5 == 0 then
				self.effects:lightning(Vector3.new(d.x + (math.random() - 0.5) * 8, 30, -4), Vector3.new(a.x, a.y + 3, 0), color)
			end
			return shot("style-foudre-sky", P(D, "UpperTorso", Vector3.new(-dir * 3, -3.4, 6)), P(A, "Head"), 60, math.rad(10 * dir))
		end
		a.x, a.y, a.facing = d.x - dir * 1.8, lerp(12, d.y + 1, (p - 0.65) / 0.35), dir
		a.state, a.move, a.moveFrame = "Attack", "AirSmash", MoveData.Moves.AirSmash.startup + 1
		a.ghost = true
		if tick % 3 == 0 then self.effects:lightning(Vector3.new(a.x, a.y + 12, 0), Vector3.new(d.x, d.y + 3, 0), color) end
		return shot("style-foudre-dive", P(D, "UpperTorso", Vector3.new(dir * 6, 4, 7)), P(D, "UpperTorso"), 44)
	elseif style == "MUR" then
		-- Spinning heel that sends the target across the arena into the wall.
		self.wallX = self.wallX or { from = d.x, to = math.clamp(d.x + dir * 14, self.config.ArenaMinX - 4, self.config.ArenaMaxX + 4) }
		local wallX = self.wallX.to
		if p < 0.55 then
			a.x, a.y, a.facing = d.x - dir * 2.4, 0, dir
			a.state, a.move = "Attack", "SpinKick"
			a.moveFrame = if p < 0.4 then MoveData.Moves.SpinKick.startup else MoveData.Moves.SpinKick.startup + 1
			return shot("style-mur-kick", P(A, "UpperTorso", Vector3.new(-dir * 2, -1, 7)), P(A, "UpperTorso"), 42)
		end
		local q = progress(tick, start + (final - start) * 0.55, final)
		d.x, d.y, d.pose = lerp(self.wallX.from, wallX, q), lerp(3, 4, q), "Launched"
		self:once("mur-wall", function()
			task.delay(0.35, function() self.effects:shockwave(Vector3.new(wallX, 4, 0), color) end)
		end)
		return shot("style-mur-wall", At(Vector3.new(wallX - dir * 2, 3.5, 7)), P(D, "UpperTorso"), 55)
	elseif style == "LUNE" then
		-- A giant crescent rises behind KAI, then the axe kick from the moon.
		a.x, a.y, a.facing = d.x - dir * 1.6, lerp(1, 10, math.min(1, p / 0.7)), dir
		self:once("lune-crescent", function()
			table.insert(self.props, self.effects:crescent(Vector3.new(d.x, 13, -6), color))
		end)
		if p < 0.7 then
			a.state, a.move, a.moveFrame = "Attack", "Hammer", MoveData.Moves.Hammer.startup
			return shot("style-lune-moon", P(D, "UpperTorso", Vector3.new(dir * 4, -2.6, 9)), At(Vector3.new(d.x, 11, -4)), 58)
		end
		a.y = lerp(10, d.y + 1, (p - 0.7) / 0.3)
		a.state, a.move, a.moveFrame = "Attack", "Hammer", MoveData.Moves.Hammer.startup + 1
		a.ghost = true
		return shot("style-lune-dive", P(D, "UpperTorso", Vector3.new(-dir * 5, 3, 6)), P(D, "UpperTorso"), 46)
	end
	-- Unknown style: classic leap and dive.
	a.x, a.y, a.facing = d.x - dir * 1.5, lerp(1, 11, p), dir
	a.state, a.move, a.moveFrame = "Attack", "AirSmash", 1
	return shot("style-default", P(D, "UpperTorso", Vector3.new(-dir * 3, -3.4, 6)), P(A, "Head"), 60)
end

function CinematicController:directAwakening(cin, a, d, tick, dir)
	local data = MoveData.Cinematics.Awakening
	local A, D = cin.attacker, cin.defender
	local style = cin.style or "TORNADE"
	local color = STYLE_COLORS[style] or RED
	local reduced = self.effects.reduced
	self.crimson.Enabled = not reduced and tick >= 24 and tick < data.FinalTick + 40
	self.kanjiBack.Visible = tick < 24
	if tick < 24 then
		-- 1. Extreme close-up on the eyes, a giant kanji painted over the frame.
		self.kanjiBack.Text = CharacterData[A].Kanji
		a.x, a.y, a.facing, a.pose = d.x - dir * 9, 0, dir, "Kiai"
		d.state = "Hitstun"
		return shot("eyes", P(A, "Head", Vector3.new(dir * 1.5, 0.15, 1.3)), P(A, "Head", Vector3.new(0, 0.12, 0)), 16)
	elseif tick < 50 then
		-- 2. Low-angle hero shot while the crimson aura erupts.
		a.x, a.y, a.facing, a.pose = d.x - dir * 9, 0, dir, "Kiai"
		d.state = "Hitstun"
		local rig = self.effects.rigs and self.effects.rigs[A]
		if rig and rig.aura then rig.aura:Emit(if reduced then 1 else 3) end
		return shot("hero", P(A, "LeftFoot", Vector3.new(dir * 4, 0.4, 5)), P(A, "Head", Vector3.new(0, 1.2, 0)), 48, math.rad(-8 * dir))
	elseif tick < data.Hits[1] then
		-- 3. Tracking shot of the dash.
		a.x, a.y, a.facing, a.pose = lerp(d.x - dir * 9, d.x - dir * 2.4, progress(tick, 50, data.Hits[1])), 0, dir, "Dash"
		a.ghost = true
		d.state = "Hitstun"
		return shot("dash", P(A, "UpperTorso", Vector3.new(dir * 2, 1, 13)), P(A, "UpperTorso"), 40)
	elseif tick < data.Hits[#data.Hits] + 4 then
		-- 4. Strikes: a hard cut to a new camera angle on every hit.
		local k = math.max(1, hitsBefore(data.Hits, tick))
		local behind = k % 2 == 0
		a.x = d.x + (if behind then dir else -dir) * 2.5
		a.y = if k % 3 == 0 then 2 else 0
		a.facing = if behind then -dir else dir
		a.state, a.move = "Attack", RUSH[(k * 3) % #RUSH + 1]
		a.moveFrame = MoveData.Moves[a.move].startup + 1
		a.ghost = true
		d.state = "Hitstun"
		d.hitstop = if tick - data.Hits[k] < 6 then 1 else 0
		local angles = {
			{ Vector3.new(-dir * 4, 2.5, 5), 40, math.rad(6) },   -- over the attacker's shoulder
			{ Vector3.new(dir * 3.5, 0.5, 4.5), 34, 0 },         -- in the target's face
			{ Vector3.new(0.3, 13, 1.5), 55, 0 },                -- top-down
			{ Vector3.new(-dir * 2, -3, 7), 50, math.rad(-14) }, -- dutch angle from the floor
			{ Vector3.new(dir * 9, 3, 9), 38, 0 },               -- wide three-quarter
		}
		local view = angles[(k - 1) % #angles + 1]
		return shot("strike" .. k, P(D, "UpperTorso", view[1]), P(D, "UpperTorso"), view[2], view[3])
	elseif tick < data.FinalTick then
		return self:directStyle(cin, a, d, tick, dir, style)
	elseif tick < data.FinalTick + 14 then
		-- 7. Impact: wide frame, shockwave in the colour of the style.
		self:once("awakening-impact", function()
			self.effects:shockwave(Vector3.new(d.x, 0, 0), color)
		end)
		local mid = Vector3.new(d.x, 3, 0)
		return shot("impact", At(mid + Vector3.new(0, 6, 34)), At(mid), 46)
	end
	-- 8. Aftermath: KAI lands in a kiai, the target flies away (or falls for the K.O. scene).
	a.y, a.facing, a.pose = 0, dir, "Kiai"
	self:showTitle(MoveData.Moves.Awakening.name, color, style)
	return shot("aftermath", P(A, "UpperTorso", Vector3.new(-dir * 4, 3, 26)), P(A, "UpperTorso"), 42)
end

-- ===================================================================== PORTE DES CIEUX

function CinematicController:directKaiten(cin, a, d, tick, dir)
	local data = MoveData.Cinematics.Kaiten
	local A, D = cin.attacker, cin.defender
	local energy = Color3.fromHex(CharacterData[A].Energy)
	local reduced = self.effects.reduced
	self.gateX = self.gateX or d.x + dir * 7 -- fixed once: the staged target moves afterwards
	local gateX = self.gateX
	self.void.Enabled = not reduced and tick >= 20 and tick < data.FinalTick + 20
	if tick < 30 then
		-- 1. KAI joins his fists; a seal with his kanji burns on the floor (seen from above).
		a.x, a.facing, a.pose = d.x - dir * 4, dir, "Kiai"
		d.state = "Hitstun"
		self:once("seal", function()
			table.insert(self.props, self.effects:kanjiSeal(Vector3.new((a.x + d.x) / 2, 0.06, 0), energy, CharacterData[A].Kanji))
		end)
		return shot("seal", At(Vector3.new((a.x + d.x) / 2, 22, 2)), At(Vector3.new((a.x + d.x) / 2, 0, 0)), 50, math.rad(90))
	elseif tick < 70 then
		-- 2. A giant torii rises behind the target.
		a.x, a.facing, a.pose = d.x - dir * 4, dir, "Kiai"
		d.state = "Hitstun"
		self:once("gate", function()
			self.gate = self.effects:gate(Vector3.new(gateX, 0, -1), dir, energy)
			table.insert(self.props, self.gate)
		end)
		return shot("gate-rise", At(Vector3.new(d.x - dir * 9, 0.6, 12)), At(Vector3.new(gateX, 7, -1)), 55, math.rad(-5 * dir))
	elseif tick < 110 then
		-- 3. The gate opens; the target is dragged toward the crimson light, KAI walks after it.
		local p = progress(tick, 70, 110)
		self:once("gate-open", function() self.effects:gateOpen(self.gate) end)
		d.x, d.y, d.pose = lerp(gateX - dir * 7, gateX - dir * 1.5, p), lerp(0, 2.5, p), "Launched"
		a.x, a.facing, a.state, a.vx = lerp(gateX - dir * 11, gateX - dir * 6, p), dir, "Walking", dir * 4
		a.pose = nil
		return shot("gate-back", P(A, "UpperTorso", Vector3.new(-dir * 5, 1.2, 3)), At(Vector3.new(gateX, 6, -1)), 48)
	elseif tick < data.Hits[1] then
		-- 4. Inside the crimson world: KAI appears right in front of the target.
		self.crimson.Enabled = not reduced
		d.x, d.y, d.pose = gateX - dir * 1.5, 2.5, "Launched"
		a.x, a.y, a.facing, a.pose = d.x - dir * 2.4, 1.6, dir, "Kiai"
		a.ghost = true
		return shot("crimson", P(A, "Head", Vector3.new(dir * 2.5, 0.2, 3.5)), P(A, "Head"), 30)
	elseif tick < data.PromptTicks[1] - 14 then
		-- 5. Two blows to set it up.
		d.x, d.y = gateX - dir * 1.5, 2.5
		d.state, d.hitstop = "Hitstun", if (tick - data.Hits[1]) % 8 < 5 then 1 else 0
		a.x, a.y, a.facing = d.x - dir * 2.4, 1.6, dir
		local second = tick >= data.Hits[2]
		a.state, a.move = "Attack", if second then "Cross" else "Jab"
		a.moveFrame = MoveData.Moves[a.move].startup + 1
		return shot("setup" .. tostring(second), P(D, "Head", Vector3.new(if second then dir * 3 else -dir * 3, 0.5, 4)), P(D, "Head"), 36)
	elseif tick < data.FinalTick then
		-- 6. Wind-up on the fist, everything stops: press R at the climax.
		d.x, d.y, d.state = gateX - dir * 1.5, 2.5, "Hitstun"
		a.x, a.y, a.facing = d.x - dir * 2.6, 1.6, dir
		a.state, a.move, a.moveFrame = "Attack", "Finale", MoveData.Moves.Finale.startup
		self.mono.Enabled = not reduced and tick >= data.PromptTicks[1] - 4
		return shot("fist", P(A, "RightHand", Vector3.new(dir * 1.2, 0.3, 2.2)), P(A, "RightHand"), 22, math.rad(4))
	elseif tick < data.FinalTick + 22 then
		-- 7. The single blow: the gate shatters behind the target.
		self.mono.Enabled = false
		a.x, a.y, a.facing = a.x, 1.6, dir
		a.state, a.move, a.moveFrame = "Attack", "Finale", MoveData.Moves.Finale.startup + 1
		self:once("shatter", function()
			self.effects:gateShatter(self.gate, energy)
			self.effects:shockwave(Vector3.new(gateX, 3, -1), energy)
		end)
		return shot("shatter", At(Vector3.new(gateX + dir * 4, 5, 18)), At(Vector3.new(gateX - dir * 2, 4, 0)), 60)
	end
	-- 8. The world comes back.
	self.void.Enabled, self.crimson.Enabled = false, false
	a.y, a.facing, a.pose = 0, dir, "Kiai"
	self:showTitle("開天", RED, "PORTE DES CIEUX")
	return shot("gate-after", P(A, "UpperTorso", Vector3.new(-dir * 3, 2.5, 22)), P(A, "UpperTorso"), 42)
end

-- ===================================================================== K.O. SCENE

-- The K.O. scene of Wilhem's storyboard. `t` runs from 0 to KO_SCENE ticks.
function CinematicController:directKO(winner, loser, w, l, t)
	self.koSide = self.koSide or (if w.x >= l.x then 1 else -1)
	local side = self.koSide
	local reduced = self.effects.reduced
	local W, L = winner, loser
	-- Staging: the loser lies face down, head toward the camera; the winner stands behind.
	local floorZ = 0
	l.state, l.lookDir, l.z = "KO", Vector3.new(0, 0, 1), floorZ
	w.victory, w.state, w.vx = false, "Idle", 0
	w.x, w.y, w.z = l.x + side * 2.8, 0, floorZ - 3.4
	w.lookDir = Vector3.new(-side * 0.25, 0, 1)
	self.mono.Enabled = not reduced and t < 30
	if t < 30 then
		-- 0. The last fall, in slow motion and black and white.
		l.y, l.pose = lerp(3.5, 0, t / 26), if t < 24 then "Launched" else "DownFace"
		w.pose = "StandTall"
		self:hideTitle()
		return shot("ko-fall", P(L, "Head", Vector3.new(side * 2.5, 0.8, 3.2)), P(L, "Head"), 30, math.rad(-12))
	end
	l.y, l.pose = 0, "DownFace"
	if t < 50 then
		-- 1. MAIN AU SOL: the loser's hand on the floor.
		w.pose = "StandTall"
		self:once("ko-dust", function()
			self.effects:dust(l.x, 0, -side)
			self.effects:dust(l.x + side, 0, side)
		end)
		return shot("ko-hand", P(L, "RightHand", Vector3.new(-1.3, 0.35, 1.6)), P(L, "RightHand"), 26)
	elseif t < 90 then
		-- 2. SCÈNE 1: loser in the foreground, winner standing, very low angle.
		w.pose = "StandTall"
		return shot("ko-scene1", P(L, "Head", Vector3.new(-side * 1.8, 0.35, 3.2)), P(W, "Head", Vector3.new(0, -0.8, 0)), 58,
			math.rad(-4 * side), P(W, "UpperTorso"))
	elseif t < 108 then
		-- 3. DÉTAIL PIEDS: the winner's sneakers next to the fallen fighter.
		w.pose = "StandTall"
		return shot("ko-feet", P(W, "LeftFoot", Vector3.new(-side * 1.6, 0.25, 2.6)), P(W, "RightFoot"), 32)
	elseif t < 126 then
		-- 4. ZOOM VISAGE: the winner's face.
		w.pose = "ArmsCrossed"
		return shot("ko-face", P(W, "Head", Vector3.new(0.35, 0.05, 1.7)), P(W, "Head", Vector3.new(0, 0.1, 0)), 18)
	elseif t < 160 then
		-- 5. SCÈNE 2: arms crossed, slight low angle, the K.O. still behind / in front.
		w.pose = "ArmsCrossed"
		return shot("ko-scene2", P(W, "UpperTorso", Vector3.new(-side * 1.2, -1.6, 7.5)), P(W, "UpperTorso", Vector3.new(0, 0.3, 0)), 50,
			0, P(W, "UpperTorso"))
	elseif t < 176 then
		-- 6. DOS DU GAGNANT: from behind, toward the torii and the sunset.
		w.pose = "ArmsCrossed"
		return shot("ko-back", P(W, "UpperTorso", Vector3.new(side * 0.8, 0.6, -4.5)), At(Vector3.new(w.x, 8, -60)), 50,
			0, P(W, "UpperTorso"))
	elseif t < 188 then
		-- 7. PLAN LARGE ARÈNE.
		w.pose = "ArmsCrossed"
		return shot("ko-wide", At(Vector3.new(w.x, 10, 46)), At(Vector3.new(w.x, 6, -20)), 38)
	end
	-- 8. FONDU NOIR / K.O.
	w.pose = "ArmsCrossed"
	self:once("ko-fade", function()
		tween(self.fade, 0.35, { BackgroundTransparency = 0 })
		self:showTitle("K.O.", RED, CharacterData[W].Name .. " " .. CharacterData[W].Skin .. " · VICTOIRE")
	end)
	return shot("ko-wide", At(Vector3.new(w.x, 10, 46)), At(Vector3.new(w.x, 6, -20)), 38)
end

-- ===================================================================== FRAME

-- Is a match-winning K.O. being shown? Returns winner, loser and the scene tick.
local function victoryScene(world, config)
	if world.training or world.cinematic then return nil end
	local winner = world.winner
	if not winner or winner <= 0 then return nil end
	local w = world.fighters[winner]
	if not w or w.wins < config.RoundsToWin then return nil end
	local t
	if world.phase == "KO" then
		t = config.KOTicks - world.phaseTicks - 40 -- let the body land first
	elseif world.phase == "MatchEnd" then
		t = config.KOTicks - 40 + (config.MatchEndTicks - world.phaseTicks)
	else
		return nil
	end
	if t < 0 then return nil end
	return winner, 3 - winner, math.min(t, KO_SCENE)
end

-- Stages poses and positions (before the rigs are placed). Returns true while active.
function CinematicController:update(world, views, dt, stale)
	local cin = world.cinematic
	local winner, loser, koTick
	if not cin and not stale and world.epoch ~= self.finishEpoch then
		-- (a FINAL FINISH already played its own K.O. scene for this round)
		winner, loser, koTick = victoryScene(world, self.config)
	end
	if stale or (not cin and not winner) then
		if self.active then self:finish() end
		self.pending = nil
		return false
	end
	local kind = if cin then cin.move else "ko"
	if not self.active or self.kind ~= kind then
		if self.active then self:finish() end
		self:begin(kind)
	end
	if cin then
		local tick = math.min(cin.tick + math.floor((os.clock() - (self.snapshotAt or os.clock())) * self.config.TickRate), cin.length)
		local a, d = views[cin.attacker], views[cin.defender]
		if not a or not d then return true end
		self.dir = self.dir or a.facing
		a.victory, a.pose, d.pose = false, nil, nil
		self:updatePrompt(cin, tick)
		local cinData = MoveData.Cinematics[cin.move]
		if cin.finish then self.finishEpoch = world.epoch end
		if cin.finish and tick >= cinData.Length then
			-- FINAL FINISH: the K.O. scene of the storyboard.
			self.pending = self:directKO(cin.attacker, cin.defender, a, d, tick - cinData.Length)
		elseif cin.move == "Awakening" then
			self.pending = self:directAwakening(cin, a, d, tick, self.dir)
		elseif cin.move == "Kaiten" then
			self.pending = self:directKaiten(cin, a, d, tick, self.dir)
		else
			self.pending = self:directRush(cin, a, d, tick, self.dir)
		end
	else
		local w, l = views[winner], views[loser]
		if not w or not l then return true end
		self.prompt.Visible = false
		self.pending = self:directKO(winner, loser, w, l, koTick)
	end
	return true
end

local function resolve(point, rigs, views)
	if point.position then return point.position end
	local rig = rigs[point.slot]
	local part = rig and rig.model:FindFirstChild(point.part)
	if part then return part.Position + point.offset end
	local v = views[point.slot]
	return Vector3.new(v and v.x or 0, (v and v.y or 0) + 3.5, v and v.z or 0) + point.offset
end

-- Places the camera on the staged shot (after the rigs are placed, so parts are current).
function CinematicController:camera(dt, rigs, views)
	local s = self.pending
	if not s then return end
	local position, target = resolve(s.from, rigs, views), resolve(s.to, rigs, views)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local goal = CFrame.lookAt(position, target) * CFrame.Angles(0, 0, s.roll)
	if s.name ~= self.shot then
		-- Anime-style hard cut between shots, with a tiny push-in afterwards.
		self.shot, self.cameraCFrame, self.shotTime = s.name, goal, 0
	else
		self.cameraCFrame = self.cameraCFrame:Lerp(goal, 1 - math.exp(-14 * dt))
	end
	self.shotTime = (self.shotTime or 0) + dt
	local push = self.cameraCFrame.LookVector * math.min(self.shotTime, 1.2) * 0.6
	local shake = Vector3.zero
	if self.shake > 0.01 then
		shake = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * self.shake
		self.shake *= math.exp(-9 * dt)
	end
	camera.FieldOfView = s.fov
	camera.CFrame = (self.cameraCFrame + push) + self.cameraCFrame:VectorToWorldSpace(shake)
	-- Depth of field on the subject (off in reduced mode).
	local focus = resolve(s.focus, rigs, views)
	self.dof.Enabled = not self.effects.reduced
	self.dof.FocusDistance = (camera.CFrame.Position - focus).Magnitude
	self.dof.InFocusRadius = math.max(2.5, self.dof.FocusDistance * 0.18)
end

function CinematicController:snapshot()
	self.snapshotAt = os.clock()
end

return CinematicController
