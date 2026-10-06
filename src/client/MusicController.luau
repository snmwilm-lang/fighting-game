--[[
	The in-game music (cosmetic, local): real royalty-free tracks only, never generated notes.
	A track is a Sound placed in Studio in ReplicatedStorage › Audio › Music and named after
	its slot (shared/Music.SLOTS: MENU, BATTLE, TEMPLE..., ASURA, WRATH, VICTORY, DEFEAT), or an
	id in Music.CUSTOM. The slot follows the game (menu, stage, boss, SECOND LIFE); a missing
	slot falls back on a more general one, and no track at all means silence. Tracks
	cross-fade; VICTORY / DEFEAT play once over the music. Steps back under the cinematics.
	Several tracks on a slot (Wilhem's tracks, Music.TRACKS, or a Folder named after the slot
	holding several Sounds) make a playlist played in turn (Music.rotate), an excerpt of 30 to
	40 s of each (Music.excerpt), cross-faded. The menu and the fights share all of Wilhem's
	tracks on one rotation (Music.SHARED), which carries on across the menus and the matches.
	SETTINGS › MUSIC turns it off. See docs/AUDIO.md.
]]
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Music = require(Shared:WaitForChild("Music"))

local MusicController = {}
MusicController.__index = MusicController

local FADE = 1.2
local LEVEL = 0.5 -- (the Music group's volume when on)

function MusicController.new()
	local self = setmetatable({ enabled = true, slot = nil, theme = "MENU", current = nil, level = 0.85, lastTrack = {} }, MusicController)
	local group = Instance.new("SoundGroup")
	group.Name, group.Volume = "Music", LEVEL
	group.Parent = SoundService
	self.group = group
	return self
end

-- The Sound templates of a slot: the Audio › Music folder (a Sound, or a Folder of Sounds,
-- named after the slot), then the uploaded ids (Music.TRACKS, Music.CUSTOM).
local made = {}
local function templates(slotId)
	local out = {}
	local audio = ReplicatedStorage:FindFirstChild("Audio")
	local folder = audio and audio:FindFirstChild("Music")
	local entry = folder and folder:FindFirstChild(slotId)
	if entry and entry:IsA("Sound") and entry.SoundId ~= "" then table.insert(out, entry) end
	if entry and entry:IsA("Folder") then
		for _, child in entry:GetChildren() do
			if child:IsA("Sound") and child.SoundId ~= "" then table.insert(out, child) end
		end
	end
	for _, id in Music.idsFor(slotId) do
		if not made[id] then
			local s = Instance.new("Sound")
			s.Name, s.SoundId, s.Volume = slotId, id, 0.6
			made[id] = s
		end
		table.insert(out, made[id])
	end
	return out
end
local function template(slotId)
	return templates(slotId)[1]
end

local function fadeOut(sound)
	local tween = TweenService:Create(sound, TweenInfo.new(FADE), { Volume = 0 })
	tween.Completed:Once(function() sound:Destroy() end)
	tween:Play()
end

function MusicController:play(slotId)
	if self.current then fadeOut(self.current); self.current = nil end
	self.slot = slotId
	if not slotId or not self.enabled then return end
	local list = templates(slotId)
	-- (the tracks in turn, the menu and the fights on one rotation: Music.rotate, rotationKey)
	local key = Music.rotationKey(slotId)
	local index = Music.rotate(#list, self.lastTrack[key], function(n) return math.random(1, n) end)
	if not index then return end
	self.lastTrack[key] = index
	local base = list[index]
	local sound = base:Clone()
	-- (the menu and the fights: excerpts in turn; a boss's theme: played whole, looping)
	local excerpts = Music.SHARED[slotId] == true
	sound.Name, sound.Looped, sound.SoundGroup = "MusicTrack", not excerpts and #list == 1, self.group
	local volume = base.Volume > 0 and base.Volume or 0.6
	sound:SetAttribute("Base", volume)
	sound.Volume = 0
	sound.Parent = self.group
	self.current = sound
	local function nextOne()
		if self.current == sound and self.slot == slotId then self:play(slotId) end
	end
	sound.Ended:Once(nextOne)
	-- An excerpt of 30 to 40 s (Music.excerpt), then the next track: wait for the track to
	-- load (its length), jump to the excerpt, fade it in.
	task.spawn(function()
		local waited = 0
		while not sound.IsLoaded and waited < 6 and sound.Parent do
			waited += task.wait(0.1)
		end
		if self.current ~= sound then return end
		local part = if excerpts then Music.excerpt(sound.TimeLength, math.random) else nil
		sound.TimePosition = if part then part.start else 0
		sound:Play()
		TweenService:Create(sound, TweenInfo.new(FADE), { Volume = volume * self.level }):Play()
		if part then task.delay(part.duration, nextOne) end
	end)
end

-- state = { inMatch, map, boss, wrath, phase, hp = { share1, share2 }, deciding, cinematic }
function MusicController:update(state)
	self.theme = Music.themeFor(state)
	local slot = Music.resolve(self.theme, function(id) return template(id) ~= nil end)
	if slot ~= self.slot then self:play(slot) end
	local level = Music.volume(state)
	if level ~= self.level then
		self.level = level
		if self.current then
			TweenService:Create(self.current, TweenInfo.new(0.5), { Volume = self.current:GetAttribute("Base") * level }):Play()
		end
	end
end

-- A jingle over the music (VICTORY, DEFEAT), when the slot has a track; FIGHT and KO have none.
function MusicController:sting(name)
	if not self.enabled or not (Music.BY_ID[name] and Music.BY_ID[name].stinger) then return end
	local base = template(name)
	if not base then return end
	local sound = base:Clone()
	sound.Looped, sound.SoundGroup = false, self.group
	sound.Parent = self.group
	sound:Play()
	sound.Ended:Once(function() sound:Destroy() end)
end

function MusicController:setEnabled(enabled)
	self.enabled = enabled
	TweenService:Create(self.group, TweenInfo.new(0.4), { Volume = if enabled then LEVEL else 0 }):Play()
	local slot = self.slot
	self.slot = nil
	if enabled then self:play(slot) else self:play(nil) end
	self.slot = slot
end

return MusicController
