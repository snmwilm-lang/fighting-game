--[[
	The in-game music (cosmetic, local). The pure sequencer (shared/Music) decides the notes
	of each sixteenth; this plays them from the client's own sounds (SoundPalette.FILES),
	on a Music sound group with its own buses (the SFX's reverb, echo...). It follows the
	game: the menu's theme, the stage's theme in a fight, ASURA's (and his SECOND LIFE's),
	louder layers when a fighter is close to the end or the round decides the match, a
	stinger on FIGHT!, K.O., the win and the loss, quieter under the ultimates' cinematics.
	A theme with an uploaded audio of Wilhem's (Music.CUSTOM) plays it in a loop instead.
	SETTINGS › MUSIC turns it off.
]]
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Music = require(Shared:WaitForChild("Music"))
local Palette = require(Shared:WaitForChild("SoundPalette"))

local MusicController = {}
MusicController.__index = MusicController

local POOL = 3 -- (copies per instrument: a note never cuts the one before it)

function MusicController.new()
	local self = setmetatable({ enabled = true, theme = "MENU", intensity = 1, step = 0, clock = 0, voices = {},
		stinger = nil, duck = 1, custom = nil }, MusicController)
	local group = Instance.new("SoundGroup")
	group.Name, group.Volume = "Music", 0.5
	group.Parent = SoundService
	self.group = group
	local buses = {}
	for name, effects in Palette.BUSES do
		local bus = Instance.new("SoundGroup")
		bus.Name = "Music_" .. name
		for class, props in effects do
			local effect = Instance.new(class)
			for key, value in props do effect[key] = value end
			effect.Parent = bus
		end
		bus.Parent = group
		buses[name] = bus
	end
	for name, v in Music.VOICES do
		local pool = { next = 1 }
		for i = 1, POOL do
			local sound = Instance.new("Sound")
			sound.Name = "Music_" .. name .. i
			sound.SoundId = Palette.FILES[v[1]]
			sound.SoundGroup = buses[v[5]] or group
			sound.Parent = group
			pool[i] = sound
		end
		self.voices[name] = pool
	end
	RunService.Heartbeat:Connect(function(dt) self:tick(dt) end)
	return self
end

function MusicController:play(n)
	local pool = self.voices[n.voice]
	if not pool then return end
	local sound = pool[pool.next]
	pool.next = pool.next % POOL + 1
	sound.Volume = n.volume * self.duck
	sound.PlaybackSpeed = n.speed
	sound.TimePosition = 0
	sound:Play()
	if n.length then
		local serial = (sound:GetAttribute("Serial") or 0) + 1
		sound:SetAttribute("Serial", serial)
		task.delay(n.length, function()
			if sound:GetAttribute("Serial") == serial then sound:Stop() end
		end)
	end
end

function MusicController:tick(dt)
	if not self.enabled or self.custom then return end
	self.clock += dt
	local theme = self.stinger and self.stinger.theme or self.theme
	local length = Music.stepSeconds(theme)
	local guard = 0
	while self.clock >= length and guard < 4 do
		self.clock -= length
		guard += 1
		if self.stinger then
			local s = self.stinger
			s.i += 1
			for _, n in Music.stinger(s.name, s.theme, s.i) do self:play(n) end
			if s.i >= 16 then
				self.stinger = nil
				self.step = 0 -- (the theme starts again from its first bar)
			end
		else
			self.step += 1
			for _, n in Music.step(self.theme, self.intensity, self.step) do self:play(n) end
		end
	end
	if self.clock > length * 4 then self.clock = 0 end -- (a long freeze: no burst of notes)
end

-- The custom audio of a theme (Music.CUSTOM), looped.
function MusicController:applyCustom()
	local id = Music.CUSTOM[self.theme]
	if self.custom and self.custom.SoundId == id then return end
	if self.custom then self.custom:Destroy(); self.custom = nil end
	if id and self.enabled then
		local sound = Instance.new("Sound")
		sound.Name, sound.SoundId, sound.Looped, sound.Volume, sound.SoundGroup = "MusicCustom", id, true, 0.6, self.group
		sound.Parent = self.group
		sound:Play()
		self.custom = sound
	end
end

-- state = { inMatch, map, boss, wrath, phase, hp = { share1, share2 }, deciding, cinematic }
function MusicController:update(state)
	local theme = Music.themeFor(state)
	if theme ~= self.theme then
		self.theme, self.step, self.clock = theme, 0, 0
		self:applyCustom()
	end
	self.intensity = Music.intensity(state)
	local duck = if state.cinematic then 0.45 else 1
	if duck ~= self.duck then self.duck = duck end
end

-- A stinger now (FIGHT, KO, VICTORY, DEFEAT), in the current theme's scale.
function MusicController:sting(name)
	if not self.enabled or self.custom then return end
	self.stinger, self.clock = { name = name, theme = self.theme, i = 0 }, 0
end

function MusicController:setEnabled(enabled)
	self.enabled = enabled
	TweenService:Create(self.group, TweenInfo.new(0.4), { Volume = if enabled then 0.5 else 0 }):Play()
	if not enabled then
		for _, pool in self.voices do
			for i = 1, POOL do pool[i]:Stop() end
		end
		if self.custom then self.custom:Destroy(); self.custom = nil end
	else
		self:applyCustom()
	end
end

return MusicController
