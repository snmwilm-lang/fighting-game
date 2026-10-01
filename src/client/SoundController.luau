--[[
	Sound effects from the sounds shipped with every Roblox client (rbxasset://sounds/...,
	the engine's own content folder): no asset id is used or invented. They are placeholders
	with character, pitched and layered per action, until Wilhem supplies the game's own SFX.
	Purely cosmetic and local; the HUD button SON mutes them.
]]
local SoundService = game:GetService("SoundService")

local SoundController = {}
SoundController.__index = SoundController

local FILES = {
	thud = "rbxasset://sounds/action_jump_land.mp3",
	jump = "rbxasset://sounds/action_jump.mp3",
	getUp = "rbxasset://sounds/action_get_up.mp3",
	steps = "rbxasset://sounds/action_footsteps_plastic.mp3",
	slash = "rbxasset://sounds/swordslash.wav",
	lunge = "rbxasset://sounds/swordlunge.wav",
	ring = "rbxasset://sounds/unsheath.wav",
	ping = "rbxasset://sounds/electronicpingshort.wav",
}

function SoundController.new()
	local self = setmetatable({ enabled = true, templates = {}, last = {}, steps = {} }, SoundController)
	local group = Instance.new("SoundGroup")
	group.Name, group.Volume = "FightSFX", 0.8
	group.Parent = SoundService
	self.group = group
	for name, file in FILES do
		local sound = Instance.new("Sound")
		sound.Name, sound.SoundId, sound.SoundGroup = name, file, group
		sound.Parent = group
		self.templates[name] = sound
	end
	return self
end

-- One-shot copy so overlapping hits do not cut each other.
function SoundController:play(name, volume, speed)
	if not self.enabled then return end
	local template = self.templates[name]
	if not template then return end
	local sound = template:Clone()
	sound.Volume, sound.PlaybackSpeed = volume or 0.6, speed or 1
	sound.Parent = self.group
	sound:Play()
	sound.Ended:Once(function() sound:Destroy() end)
	task.delay(4, function() if sound.Parent then sound:Destroy() end end)
end

function SoundController:setEnabled(enabled)
	self.enabled = enabled
	if not enabled then
		for _, loop in self.steps do loop:Stop() end
	end
end

function SoundController:onEvent(event)
	if event.kind == "Hit" then
		local heavy = event.heavy or event.ko
		self:play("thud", if heavy then 0.95 else 0.55, if heavy then 0.75 else 1.5 + math.random() * 0.2)
		if heavy then self:play("slash", 0.5, 0.7) end
		if event.ko then self:play("thud", 1, 0.5) end
	elseif event.kind == "Block" then
		self:play("ring", 0.35, 1.6 + math.random() * 0.15)
	elseif event.kind == "GuardBreak" then
		self:play("ring", 0.7, 0.8)
		self:play("thud", 0.7, 0.6)
	elseif event.kind == "Clash" then
		self:play("ring", 0.6, 1.1)
	elseif event.kind == "SuperFlash" then
		self:play("ring", 0.8, 0.65)
		self:play("lunge", 0.6, 0.6)
	elseif event.kind == "Skill" then
		self:play("ring", 0.45, 1.25)
	elseif event.kind == "Projectile" then
		self:play("lunge", 0.6, 0.8)
	elseif event.kind == "Prompt" then
		self:play("ping", 0.6, 1)
	elseif event.kind == "PromptGrade" then
		self:play("ping", 0.7, if event.grade == "PARFAIT" then 1.5 else 1.2)
	elseif event.kind == "SuperJump" then
		self:play("jump", 0.6, 0.85)
	end
end

-- State changes of a fighter view: swings, jumps, landings, falls, footsteps.
function SoundController:update(slot, view, moves)
	local last = self.last[slot]
	local m = view.state == "Attack" and moves[view.move]
	local phase = if m then (if view.moveFrame <= m.startup then "S" elseif view.moveFrame <= m.startup + m.active then "A" else "R") else ""
	local key = view.state .. ":" .. tostring(view.move) .. phase
	if last and last.key ~= key and self.enabled then
		if phase == "A" and last.phase ~= "A" then
			-- Whoosh of the swing: sharper for light moves, heavier for big ones.
			if m.heavy or m.meterCost then
				self:play("slash", 0.55, 0.85 + math.random() * 0.1)
			else
				self:play("lunge", 0.4, 1.35 + math.random() * 0.2)
			end
		elseif view.state == "Jumping" and last.state ~= "Jumping" then
			self:play("jump", 0.45, 1.05)
		elseif view.state == "Dashing" and last.state ~= "Dashing" then
			self:play("lunge", 0.35, 0.75)
		elseif view.state == "Knockdown" and last.state ~= "Knockdown" then
			self:play("thud", 0.9, 0.55)
		elseif view.state == "GetUp" and last.state ~= "GetUp" then
			self:play("getUp", 0.5, 1.1)
		end
		if (last.y or 0) > 0.3 and (view.y or 0) <= 0.01 and view.state ~= "Knockdown" then
			self:play("thud", 0.4, 1.2)
		end
	end
	-- Footsteps loop while walking, its rate following the run.
	local loop = self.steps[slot]
	if not loop then
		loop = self.templates.steps:Clone()
		loop.Looped, loop.Volume = true, 0.35
		loop.Parent = self.group
		self.steps[slot] = loop
	end
	local walking = self.enabled and view.state == "Walking"
	if walking and not loop.IsPlaying then loop:Play() elseif not walking and loop.IsPlaying then loop:Stop() end
	if walking then loop.PlaybackSpeed = 1.35 end
	self.last[slot] = { key = key, state = view.state, phase = phase, y = view.y }
end

return SoundController
