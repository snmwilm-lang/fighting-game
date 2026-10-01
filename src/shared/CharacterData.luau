-- Kits. A kit is a fighting style worn by the player's own Roblox avatar: its moveset and
-- ultimates, its ki colour, and an outfit overlay (headband, sash, hand wraps, back emblem)
-- sized on the avatar's real parts. KAI 開 is the first kit, from Wilhem's art direction
-- sheet; its four colour styles come from the same sheet (CLASSIQUE, NUIT, SACRÉ, MAUDIT).
--
-- CharacterData[slot] is the look currently used by a slot. It is the only mutable part of
-- this module: the server changes it when a player picks another style and sends the style
-- name in the snapshot; clients apply it the same way, so every module sees the same look.
-- Colours are hex strings so the data stays engine-independent.
local function skin(name, colors)
	colors.Name = "KAI"
	colors.Kanji = "開"
	colors.Kit = "KAI"
	colors.Skin = name
	return table.freeze(colors)
end

local Skins = table.freeze({
	CLASSIQUE = skin("CLASSIQUE", {
		Hair = "121216", HairTip = "C8102E",
		SkinTone = "E3A98A", Eyes = "8E1020",
		Vest = "16161B", VestTrim = "C8102E", Shirt = "E9E9EE",
		Sash = "C8102E", Wraps = "F2F2F5",
		Pants = "1B1B21", PantsShade = "111115",
		Shoes = "F2F2F5", ShoeAccent = "C8102E", Sole = "16161B",
		Energy = "FF2A3D", -- ki color for sparks, aura and slashes
		Shield = "6E7BFF", -- guard effect
	}),
	NUIT = skin("NUIT", {
		Hair = "0E1222", HairTip = "3D7BFF",
		SkinTone = "D9A07F", Eyes = "2A5BD7",
		Vest = "141B33", VestTrim = "3D7BFF", Shirt = "DCE3F2",
		Sash = "2F5FE0", Wraps = "E4EAF7",
		Pants = "151C30", PantsShade = "0D1222",
		Shoes = "E4EAF7", ShoeAccent = "3D7BFF", Sole = "141B33",
		Energy = "4D8DFF",
		Shield = "B07BFF",
	}),
	["SACRÉ"] = skin("SACRÉ", {
		Hair = "F2EEE8", HairTip = "FFD23F",
		SkinTone = "E8B48F", Eyes = "C99A1E",
		Vest = "F4F1EA", VestTrim = "FFD23F", Shirt = "FFFFFF",
		Sash = "E8B21C", Wraps = "FFFFFF",
		Pants = "EDE7DA", PantsShade = "D6CDBA",
		Shoes = "FFFFFF", ShoeAccent = "E8B21C", Sole = "C9B98F",
		Energy = "FFD23F",
		Shield = "FFFFFF",
	}),
	MAUDIT = skin("MAUDIT", {
		Hair = "120A1A", HairTip = "A040FF",
		SkinTone = "C9A08C", Eyes = "B060FF",
		Vest = "1A1024", VestTrim = "A040FF", Shirt = "2A1F33",
		Sash = "7A2CC8", Wraps = "D9C8F2",
		Pants = "150E1C", PantsShade = "0C0812",
		Shoes = "2A1F33", ShoeAccent = "A040FF", Sole = "0C0812",
		Energy = "B060FF",
		Shield = "FF4FD8",
	}),
})

local CharacterData = {
	Skins = Skins,
	SkinOrder = table.freeze({ "CLASSIQUE", "NUIT", "SACRÉ", "MAUDIT" }),
	Skins.CLASSIQUE, -- slot 1
	Skins.NUIT, -- slot 2
}

-- Next style in the order, skipping `avoid` (the opponent's style).
function CharacterData.nextSkin(current, avoid)
	local order = CharacterData.SkinOrder
	local index = table.find(order, current) or 0
	for step = 1, #order do
		local name = order[(index + step - 1) % #order + 1]
		if name ~= avoid then return name end
	end
	return current
end

return CharacterData
