--[[
	Sound effects, built only from the sounds shipped in every Roblox client's content folder
	(rbxasset://sounds/...; the full list is SoundPalette.CLIENT_SOUNDS, from the client
	manifest). No asset id is used or invented. (The old sword sounds, swordslash.wav and the
	like, are no longer in the client: they played nothing.)

	Each file is shaped (pitch, length, the engine's sound effects on a few buses) into one
	coherent palette (src/shared/SoundPalette.luau), until Wilhem supplies the game's own SFX:
	  - every action has one sound, the same for every fighter (guard, guard break, clash,
	    parry, evade, jump, landing, knockdown, super flash, rhythm prompts...);
	  - every kit strikes with its own material: fists of ki (KAI), leather gloves (TARO),
	    kicks of wind (ZEPHYR), the shadow's knife hand (AKEMI), crushing fists (RYUKEN, a
	    distorted bus), the water blade (SHIN), the inverted shadow (DAICHA, an echo bus),
	    stone (HIBECARES);
	  - a heavy blow is the heavy version of the same material, never another material.
	Purely cosmetic and local; the HUD button SON mutes them.
]]
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local MoveData = require(Shared:WaitForChild("MoveData"))
local Palette = require(Shared:WaitForChild("SoundPalette"))
local FILES, BUSES, MATERIALS, ACTIONS = Palette.FILES, Palette.BUSES, Palette.MATERIALS, Palette.ACTIONS

local SoundController = {}
SoundController.__index = SoundController

local function material(kit)
	return MATERIALS[kit or "KAI"] or MATERIALS.KAI
end

function SoundController.new()
	local self = setmetatable({ enabled = true, templates = {}, buses = {}, last = {}, steps = {} }, SoundController)
	-- Wilhem's own royalty-free sounds, found by the list they replace (docs/AUDIO.md): a Sound
	-- in ReplicatedStorage › Audio › SFX named after the action ("Block", "KO"...), the kit's
	-- part ("KAI.hit") or the part for every kit ("hit"), or an id in SoundPalette.CUSTOM.
	self.keys = {}
	for key, list in ACTIONS do
		self.keys[list] = { key }
	end
	for kit, own in MATERIALS do
		for part, list in own do
			if type(list) == "table" then self.keys[list] = { kit .. "." .. part, part } end
		end
	end
	local group = Instance.new("SoundGroup")
	group.Name, group.Volume = "FightSFX", 0.65
	group.Parent = SoundService
	self.group = group
	for name, effects in BUSES do
		local bus = Instance.new("SoundGroup")
		bus.Name, bus.Volume = "SFX_" .. name, 1
		for class, props in effects do
			local effect = Instance.new(class)
			for key, value in props do effect[key] = value end
			effect.Parent = bus
		end
		bus.Parent = group -- nested: its output goes through the main group
		self.buses[name] = bus
	end
	for name, file in FILES do
		local sound = Instance.new("Sound")
		sound.Name, sound.SoundId, sound.SoundGroup = name, file, group
		sound.Parent = group
		self.templates[name] = sound
	end
	return self
end

-- One shot of a sound (a copy, so overlapping hits never cut each other), slightly varied.
function SoundController:play(spec, scale)
	if not self.enabled then return end
	local template = self.templates[spec[1]]
	if not template then return end
	local sound = template:Clone()
	sound.Volume = spec[2] * (scale or 1)
	sound.PlaybackSpeed = spec[3] * (0.96 + math.random() * 0.08)
	sound.SoundGroup = self.buses[spec[5]] or self.group
	sound.Parent = self.group
	sound:Play()
	local length = spec[4]
	if length then
		-- Cut short with a quick fade.
		task.delay(length, function()
			if not sound.Parent then return end
			TweenService:Create(sound, TweenInfo.new(0.06), { Volume = 0 }):Play()
			task.delay(0.07, function() sound:Destroy() end)
		end)
	end
	sound.Ended:Once(function() sound:Destroy() end)
	task.delay(4, function() if sound.Parent then sound:Destroy() end end)
end

-- The menus' buttons: a soft tick on hover, a click on press (every button of a screen gui).
function SoundController:watchButtons(gui)
	local function hook(object)
		if not object:IsA("GuiButton") then return end
		object.MouseEnter:Connect(function() self:playAll(ACTIONS.UiHover) end)
		object.Activated:Connect(function() self:playAll(ACTIONS.UiClick) end)
	end
	for _, d in gui:GetDescendants() do hook(d) end
	gui.DescendantAdded:Connect(hook)
end

-- The replacement of a sound list: a Sound of the Audio › SFX folder, or a CUSTOM id.
function SoundController:custom(list)
	local keys = list and self.keys[list]
	if not keys then return nil end
	local audio = ReplicatedStorage:FindFirstChild("Audio")
	local folder = audio and audio:FindFirstChild("SFX")
	for _, key in keys do
		local sound = folder and folder:FindFirstChild(key)
		if sound and sound:IsA("Sound") and sound.SoundId ~= "" then return sound end
		if Palette.CUSTOM[key] then return Palette.CUSTOM[key] end
	end
	return nil
end

function SoundController:playAll(list, scale)
	local custom = self:custom(list)
	if custom then
		if not self.enabled then return end
		local sound
		if typeof(custom) == "Instance" then
			sound = custom:Clone()
			sound.Volume = (if custom.Volume > 0 then custom.Volume else 0.7) * (scale or 1)
		else
			sound = Instance.new("Sound")
			sound.SoundId, sound.Volume = custom, 0.7 * (scale or 1)
		end
		sound.Looped, sound.SoundGroup = false, self.group
		sound.Parent = self.group
		sound:Play()
		sound.Ended:Once(function() sound:Destroy() end)
		task.delay(6, function() if sound.Parent then sound:Destroy() end end)
		return
	end
	for _, spec in list or {} do self:play(spec, scale) end
end

function SoundController:setEnabled(enabled)
	self.enabled = enabled
	if not enabled then
		for _, loop in self.steps do loop:Stop() end
	end
end

function SoundController:onEvent(event)
	local kind = event.kind
	if kind == "Hit" then
		local own = material(MoveData.MoveKit[event.move])
		local heavy = event.heavy or event.ko or event.cinematic
		self:playAll(if heavy then own.heavyHit else own.hit)
		if event.tip then self:playAll(ACTIONS.Tip) end
		if event.counter then self:playAll(ACTIONS.Counter) end
		if event.cinematic then self:playAll(ACTIONS.Cinematic) end
		if event.ko then self:playAll(ACTIONS.KO) end
	elseif kind == "Parry" then
		self:playAll(if event.absorbed then ACTIONS.Wall else ACTIONS.Parry)
	elseif kind == "Projectile" then
		self:playAll(material(MoveData.MoveKit[event.move]).projectile or MATERIALS.KAI.projectile)
	elseif kind == "PromptGrade" then
		self:playAll(if event.grade == "PERFECT" then ACTIONS.Perfect else ACTIONS.Graded)
	elseif kind == "GroundBounce" or kind == "WallBounce" then
		self:playAll(ACTIONS.Bounce)
	elseif kind == "Blink" or kind == "Block" or kind == "GuardBreak" or kind == "Clash" or kind == "Evade" or kind == "Slip"
		or kind == "Stance" or kind == "SuperFlash" or kind == "Skill" or kind == "Prompt" or kind == "SuperJump"
		or kind == "PassiveReady" or kind == "Chilled" or kind == "Poison" or kind == "Armor" or kind == "Heal"
		or kind == "Reflect" or kind == "Drone" or kind == "Shackled" or kind == "Domination" then
		self:playAll(ACTIONS[kind])
	elseif kind == "Revive" then
		self:playAll(ACTIONS.Revive)
	elseif kind == "Fight" then
		self:playAll(ACTIONS.RoundStart)
	elseif kind == "DroneShot" then
		self:playAll(MATERIALS.NOVA.projectile)
	end
end

-- State changes of a fighter view: swings (in its kit's material), jumps, landings, dashes,
-- falls, getting up, footsteps.
function SoundController:update(slot, view, moves)
	local last = self.last[slot]
	local m = view.state == "Attack" and moves[view.move]
	local phase = if m then (if view.moveFrame <= m.startup then "S" elseif view.moveFrame <= m.startup + m.active then "A" else "R") else ""
	local key = view.state .. ":" .. tostring(view.move) .. phase
	local own = material(view.kit)
	if last and last.key ~= key and self.enabled then
		if phase == "A" and last.phase ~= "A" then
			self:playAll(if m.heavy or m.meterCost or m.kind == "Ultimate" then own.heavySwing else own.swing)
		elseif view.state == "Jumping" and last.state ~= "Jumping" then
			self:playAll(ACTIONS.Jump)
		elseif view.state == "Dashing" and last.state ~= "Dashing" then
			self:playAll(ACTIONS.Dash)
		elseif view.state == "Knockdown" and last.state ~= "Knockdown" then
			self:playAll(ACTIONS.Knockdown)
		elseif view.state == "GetUp" and last.state ~= "GetUp" then
			self:playAll(ACTIONS.GetUp)
		end
		if (last.y or 0) > 0.3 and (view.y or 0) <= 0.01 and view.state ~= "Knockdown" then
			self:playAll(ACTIONS.Land)
		end
	end
	-- Footsteps loop while walking, its rate following the run (slower for the heavy ones).
	local loop = self.steps[slot]
	if not loop then
		loop = self.templates.steps:Clone()
		loop.Looped, loop.Volume = true, 0.35
		loop.Parent = self.group
		self.steps[slot] = loop
	end
	local walking = self.enabled and view.state == "Walking"
	if walking and not loop.IsPlaying then loop:Play() elseif not walking and loop.IsPlaying then loop:Stop() end
	if walking then loop.PlaybackSpeed = own.steps or 1.35 end
	self.last[slot] = { key = key, state = view.state, phase = phase, y = view.y }
end

return SoundController
