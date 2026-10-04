--[[
	The game's language on this screen (SETTINGS › LANGUAGE, kept with the profile):
	  AUTO  the game's English, translated by Roblox into the player's own language when the
	        experience has automatic translation on (Creator Dashboard › Localization, source
	        language English);
	  EN    English, never translated;
	  FR    the game's own French (shared/Locale), never re-translated by Roblox.
	Every text of the screens (and of the billboards in the world) is watched: when the game
	writes an English text, the French one replaces it at once. Cosmetic only.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Locale = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Locale"))

local LanguageController = {}
LanguageController.__index = LanguageController

local TEXT = { TextLabel = true, TextButton = true }

function LanguageController.new()
	local self = setmetatable({
		lang = "AUTO",
		original = setmetatable({}, { __mode = "k" }), -- object -> the game's own (English) text
		shown = setmetatable({}, { __mode = "k" }), -- object -> the text this controller wrote
		watched = setmetatable({}, { __mode = "k" }),
	}, LanguageController)
	local gui = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, d in gui:GetDescendants() do self:watch(d) end
	gui.DescendantAdded:Connect(function(d) self:watch(d) end)
	-- (names and titles hung in the world)
	workspace.DescendantAdded:Connect(function(d)
		if TEXT[d.ClassName] and d:FindFirstAncestorWhichIsA("LayerCollector") then self:watch(d) end
	end)
	return self
end

function LanguageController:watch(object)
	if not TEXT[object.ClassName] or self.watched[object] then return end
	self.watched[object] = true
	object:GetPropertyChangedSignal("Text"):Connect(function() self:apply(object) end)
	self:apply(object)
end

function LanguageController:apply(object)
	local text = object.Text
	if text == self.shown[object] then return end -- (our own write)
	self.original[object] = text
	local out = if self.lang == "FR" then Locale.translate(text, "FR") else text
	self.shown[object] = out
	object.AutoLocalize = self.lang == "AUTO"
	if out ~= text then object.Text = out end
end

function LanguageController:set(lang)
	if lang ~= "AUTO" and lang ~= "EN" and lang ~= "FR" then return end
	if lang == self.lang then return end
	self.lang = lang
	for object in self.watched do
		if object.Parent then
			self.shown[object] = nil
			local original = self.original[object]
			if original and object.Text ~= original then
				object.Text = original -- (re-applied by the change signal)
			else
				self:apply(object)
			end
		end
	end
end

-- The next language of the SETTINGS button.
function LanguageController:nextLanguage()
	local list = Locale.LANGUAGES
	return list[(table.find(list, self.lang) or 1) % #list + 1]
end

function LanguageController:name()
	return Locale.NAMES[self.lang] or self.lang
end

return LanguageController
