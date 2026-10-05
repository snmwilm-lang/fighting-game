--[[
	The TUTORIAL on screen (cosmetic, local): offered at the first launch, started from the
	welcome window or SETTINGS › TUTORIAL. It opens a TRAINING match with KAI and shows one
	step at a time at the top of the screen: what to do, the keys of the device in hand
	(keyboard, gamepad or touch), the progress, and SKIP. A step moves on by itself once the
	player really did it (shared/Tutorial.observe, on the fighter and the match's events); the
	server makes the dummy attack for the guard steps (input.setTutor). The fight itself is the
	normal simulation: nothing here decides a hit.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tutorial = require(Shared.Tutorial)
local MoveData = require(Shared.MoveData)
local Maps = require(Shared.Maps)
local Theme = require(script.Parent.MenuTheme)

local new, text = Theme.new, Theme.text
local GOLD, WHITE, MUTED, RED, INK = Theme.GOLD, Theme.WHITE, Theme.MUTED, Theme.RED, Theme.INK
local GREEN = Color3.fromHex("5BE38A")

local TutorialController = {}
TutorialController.__index = TutorialController

function TutorialController.new(input)
	local self = setmetatable({ input = input, active = false, state = nil }, TutorialController)
	local gui = new("ScreenGui", { Name = "Tutorial", ResetOnSpawn = false, DisplayOrder = 26, IgnoreGuiInset = false, Enabled = false,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets }, Players.LocalPlayer:WaitForChild("PlayerGui"))
	self.gui = gui
	-- (under the timer; scaled down on a phone like the fight HUD)
	local panel = new("Frame", { Name = "Step", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 118),
		Size = UDim2.fromOffset(560, 132), BackgroundColor3 = Theme.PANEL, BackgroundTransparency = 0.08, BorderSizePixel = 0 }, gui)
	Theme.surface(panel, GOLD)
	local scale = new("UIScale", { Scale = 1 }, panel)
	local function fit()
		local y = gui.AbsoluteSize.Y
		if y > 0 then scale.Scale = math.clamp(y / 720, 0.55, 1) end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	self.panel, self.scale = panel, scale
	self.counter = text(panel, { Position = UDim2.fromOffset(16, 8), Size = UDim2.fromOffset(300, 16), Font = Theme.UI, TextSize = 12,
		Text = "", TextColor3 = GOLD })
	self.title = text(panel, { Position = UDim2.fromOffset(16, 24), Size = UDim2.new(1, -150, 0, 40), Font = Theme.DISPLAY, TextSize = 36,
		Text = "", TextColor3 = WHITE })
	self.body = text(panel, { Position = UDim2.fromOffset(16, 64), Size = UDim2.new(1, -32, 0, 34), Font = Theme.BODY, TextSize = 14,
		Text = "", TextColor3 = WHITE, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
	self.keys = text(panel, { Position = UDim2.fromOffset(16, 100), Size = UDim2.new(1, -150, 0, 24), Font = Theme.UI, TextSize = 15,
		Text = "", TextColor3 = GOLD, BackgroundTransparency = 1 })
	self.skip = Theme.button(panel, { Name = "Skip", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(120, 34), Font = Theme.UI, TextSize = 13, Text = "SKIP ✕" }, RED)
	self.skip.Activated:Connect(function()
		if self.active then
			self:stop(false)
		else -- (the last screen's CLOSE)
			self.ended = false
			self.gui.Enabled = false
		end
	end)
	-- progress: one dash per step
	self.dots = {}
	local row = new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -10), Size = UDim2.fromOffset(120, 6),
		BackgroundTransparency = 1 }, panel)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 2) }, row)
	for i = 1, #Tutorial.STEPS do
		self.dots[i] = new("Frame", { Size = UDim2.new(1 / #Tutorial.STEPS, -2, 1, 0), BackgroundColor3 = Theme.LINE, BorderSizePixel = 0 }, row)
	end
	return self
end

-- The device in hand: its keys are the ones shown.
local function device()
	local last = UserInputService:GetLastInputType()
	if string.find(last.Name, "Gamepad") then return "pad" end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then return "touch" end
	return "pc"
end

-- Starts the tutorial: a TRAINING match with KAI (free), then the steps.
function TutorialController:start(menuRemote)
	self.active, self.state, self.ended, self.wasInMatch = true, Tutorial.new(), false, false
	self.skip.Text = "SKIP ✕"
	self.menuRemote = menuRemote
	menuRemote:FireServer({ action = "start", request = { mode = "TRAINING", team = { "KAI" }, map = Maps.DEFAULT } })
	-- (offered once: started counts; a moment later, the server takes one menu request at a time)
	task.delay(0.6, function() menuRemote:FireServer({ action = "howToPlay", version = Tutorial.VERSION }) end)
	self:show()
end

function TutorialController:show()
	local step = self.state and Tutorial.current(self.state)
	if not step then return end
	self.counter.Text = string.format("TUTORIAL · %d / %d", self.state.step, #Tutorial.STEPS)
	self.title.Text = step.title
	self.body.Text = step.text
	self.keys.Text = "▶ " .. (step.keys[device()] or step.keys.pc)
	for i, dot in self.dots do
		dot.BackgroundColor3 = if i < self.state.step then GREEN elseif i == self.state.step then GOLD else Theme.LINE
	end
	self.input.setTutor(step.dummy)
	self.scale.Scale *= 0.94
	local target = math.clamp(self.gui.AbsoluteSize.Y / 720, 0.55, 1)
	TweenService:Create(self.scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = target }):Play()
end

-- The end: done (a last screen), or skipped / left (nothing more).
function TutorialController:stop(completed)
	if not self.active then return end
	self.active = false
	self.input.setTutor(nil)
	if not completed then
		self.gui.Enabled = false
		return
	end
	self.counter.Text = "TUTORIAL COMPLETE"
	self.title.Text = "YOU'RE READY! ✓"
	self.body.Text = "Keep training here as long as you like, or ◀ MENU to fight the CPU or other players online."
	self.keys.Text = ""
	for _, dot in self.dots do dot.BackgroundColor3 = GREEN end
	self.skip.Text = "CLOSE ✕"
	self.ended = true
	task.delay(8, function()
		if self.ended and not self.active then self.gui.Enabled = false end
	end)
end

function TutorialController:advance()
	if self.state.done then
		self:stop(true)
	else
		-- (a short green flash, then the next step)
		self.title.Text, self.title.TextColor3 = "✓ " .. self.title.Text, GREEN
		task.delay(0.6, function()
			if self.active then
				self.title.TextColor3 = WHITE
				self:show()
			end
		end)
	end
end

-- Every frame: the panel only in the tutorial's match; the step watches the fighter.
function TutorialController:update(inMatch, me, slot)
	if not self.active and not self.ended then return end
	self.gui.Enabled = inMatch and (self.active or self.ended)
	if self.active and not inMatch and self.wasInMatch then
		self:stop(false) -- (left the match: the tutorial ends)
	end
	self.wasInMatch = inMatch
	if not self.active or not inMatch or not me or slot == 0 then return end
	self.slot = slot
	if Tutorial.observe(self.state, slot, { kind = "frame", me = me }, MoveData.Moves) then self:advance() end
end

function TutorialController:onEvent(event)
	if not self.active or not self.slot then return end
	if Tutorial.observe(self.state, self.slot, event, MoveData.Moves) then self:advance() end
end

return TutorialController
