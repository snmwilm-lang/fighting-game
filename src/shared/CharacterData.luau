-- Kits. A kit is a fighting style worn by the player's own Roblox avatar: its moveset and
-- ultimates (MoveData.Kits), its ki colour, and an outfit overlay sized on the avatar's real
-- parts. Each kit has colour styles: KAI 開 (CLASSIQUE, NUIT, SACRÉ, MAUDIT, from Wilhem's
-- art direction sheet), TARO 火 the boxer, ZEPHYR 風 the kicker, AKEMI 影 the shadow.
--
-- CharacterData[slot] is the look currently used by a slot. It is the only mutable part of
-- this module: the server changes it when a player picks another kit or style and sends the
-- style name in the snapshot; clients apply it the same way, so every module sees the same
-- look. Colours are hex strings so the data stays engine-independent.
-- Every style carries the fields of the KAI block model (Hair, Vest...) and the outfit
-- colours: Sash = main outfit colour (KAI sash, TARO gloves, ZEPHYR scarf, AKEMI mask),
-- Wraps = second colour (bands, guards).
local KANJI = { KAI = "開", TARO = "火", ZEPHYR = "風", AKEMI = "影", RYUKEN = "拳", SHIN = "流", DAICHA = "闇", HIBECARES = "崩" }

local function style(kit, name, colors)
	colors.Name = kit
	colors.Kanji = KANJI[kit]
	colors.Kit = kit
	colors.Skin = name
	return table.freeze(colors)
end

local function skin(name, colors)
	return style("KAI", name, colors)
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
	-- TARO 火: orange gloves, gold trunks and black boots (BRASIER), white and gold champion
	-- (CHAMPION). Shirt = his towel. Never KAI's black / red / white.
	BRASIER = style("TARO", "BRASIER", {
		Hair = "2B1A12", HairTip = "FF7A1A", SkinTone = "C98A62", Eyes = "B8420E",
		Vest = "2B1A12", VestTrim = "FFC22E", Shirt = "F2EEE6",
		Sash = "F0601A", Wraps = "FFC22E",
		Pants = "F2A91A", PantsShade = "B8780E",
		Shoes = "1E1A18", ShoeAccent = "FFC22E", Sole = "1E1A18",
		Energy = "FF6A1A", Shield = "FFD45A",
	}),
	CHAMPION = style("TARO", "CHAMPION", {
		Hair = "3A2418", HairTip = "FFD45A", SkinTone = "B97A55", Eyes = "8E5A10",
		Vest = "F2F2F5", VestTrim = "FFD45A", Shirt = "FFD45A",
		Sash = "F2F2F5", Wraps = "FFD45A",
		Pants = "F2F2F5", PantsShade = "D6CDBA",
		Shoes = "F2F2F5", ShoeAccent = "FFD45A", Sole = "C9A040",
		Energy = "FFB21A", Shield = "FF6A1A",
	}),
	-- ZEPHYR 風: teal scarf (AZUR), storm grey and white (TEMPÊTE).
	AZUR = style("ZEPHYR", "AZUR", {
		Hair = "E8F4F2", HairTip = "5FE0D0", SkinTone = "E3B08F", Eyes = "1E9A8E",
		Vest = "1E5E66", VestTrim = "5FE0D0", Shirt = "E8F4F2",
		Sash = "2BB8A8", Wraps = "E8F4F2",
		Pants = "1A3C44", PantsShade = "12282E",
		Shoes = "E8F4F2", ShoeAccent = "5FE0D0", Sole = "1A3C44",
		Energy = "5FE0D0", Shield = "C8F4FF",
	}),
	["TEMPÊTE"] = style("ZEPHYR", "TEMPÊTE", {
		Hair = "2A2E38", HairTip = "C8F4FF", SkinTone = "D9A07F", Eyes = "6E7BFF",
		Vest = "3A3F4C", VestTrim = "C8F4FF", Shirt = "D6DCE8",
		Sash = "D6DCE8", Wraps = "6E7BFF",
		Pants = "2A2E38", PantsShade = "1C1F27",
		Shoes = "D6DCE8", ShoeAccent = "6E7BFF", Sole = "1C1F27",
		Energy = "9FD8FF", Shield = "6E7BFF",
	}),
	-- AKEMI 影: black and violet (OMBRE), black and crimson (LUNE ROUGE).
	OMBRE = style("AKEMI", "OMBRE", {
		Hair = "0E0A14", HairTip = "8A3CFF", SkinTone = "D8B09A", Eyes = "8A3CFF",
		Vest = "14101C", VestTrim = "8A3CFF", Shirt = "1E1828",
		Sash = "1E1828", Wraps = "8A3CFF",
		Pants = "14101C", PantsShade = "0C0812",
		Shoes = "14101C", ShoeAccent = "8A3CFF", Sole = "0C0812",
		Energy = "B060FF", Shield = "6E7BFF",
	}),
	["LUNE ROUGE"] = style("AKEMI", "LUNE ROUGE", {
		Hair = "0E0A0C", HairTip = "E0102B", SkinTone = "E3B8A0", Eyes = "C8102E",
		Vest = "120A0C", VestTrim = "E0102B", Shirt = "1E1214",
		Sash = "1E1214", Wraps = "E0102B",
		Pants = "120A0C", PantsShade = "0A0607",
		Shoes = "120A0C", ShoeAccent = "E0102B", Sole = "0A0607",
		Energy = "FF2A3D", Shield = "FF9F40",
	}),
	-- RYUKEN 拳 (Wilhem's second sheet): white hair, red fists, black (BRISÉ); crimson and
	-- black (SANG NOIR).
	["BRISÉ"] = style("RYUKEN", "BRISÉ", {
		Hair = "F2ECE8", HairTip = "FF3B3B", SkinTone = "D9A07F", Eyes = "D01818",
		Vest = "1A1416", VestTrim = "E0102B", Shirt = "1A1416",
		Sash = "C8102E", Wraps = "E0102B",
		Pants = "26262C", PantsShade = "18181C",
		Shoes = "1A1416", ShoeAccent = "E0102B", Sole = "F2ECE8",
		Energy = "FF2A2A", Shield = "FFB0A0",
	}),
	["SANG NOIR"] = style("RYUKEN", "SANG NOIR", {
		Hair = "1A1214", HairTip = "FF2A2A", SkinTone = "C98F6E", Eyes = "FF2A2A",
		Vest = "5A0A12", VestTrim = "FF2A2A", Shirt = "5A0A12",
		Sash = "1A1214", Wraps = "1A1214",
		Pants = "120E10", PantsShade = "0A0809",
		Shoes = "120E10", ShoeAccent = "FF2A2A", Sole = "5A0A12",
		Energy = "FF4A2A", Shield = "FFD0A0",
	}),
	-- SHIN 流: navy coat, blue edge, silver blade (COURANT); black and steel (ACIER).
	COURANT = style("SHIN", "COURANT", {
		Hair = "141A2E", HairTip = "3D9BFF", SkinTone = "E3B08F", Eyes = "2E8BFF",
		Vest = "18223F", VestTrim = "3D9BFF", Shirt = "E4ECF7",
		Sash = "3D9BFF", Wraps = "C8D4E8",
		Pants = "141A2E", PantsShade = "0C1020",
		Shoes = "1B2238", ShoeAccent = "3D9BFF", Sole = "0C1020",
		Energy = "4DA8FF", Shield = "C8F0FF",
	}),
	ACIER = style("SHIN", "ACIER", {
		Hair = "D6DCE8", HairTip = "6FD8FF", SkinTone = "D9A07F", Eyes = "6FD8FF",
		Vest = "1C1C22", VestTrim = "B8C4D8", Shirt = "2A2A32",
		Sash = "B8C4D8", Wraps = "1C1C22",
		Pants = "1C1C22", PantsShade = "101014",
		Shoes = "1C1C22", ShoeAccent = "B8C4D8", Sole = "101014",
		Energy = "8FE0FF", Shield = "3D9BFF",
	}),
	-- DAICHA 闇: white robe, violet sash and shadows (INVERSÉ); black robe, gold eyes (ÉCLIPSE).
	["INVERSÉ"] = style("DAICHA", "INVERSÉ", {
		Hair = "120A1C", HairTip = "A040FF", SkinTone = "E8C0A8", Eyes = "B060FF",
		Vest = "F0EEF4", VestTrim = "A040FF", Shirt = "F0EEF4",
		Sash = "7A2CC8", Wraps = "2A1A3A",
		Pants = "1E1428", PantsShade = "120C18",
		Shoes = "1E1428", ShoeAccent = "A040FF", Sole = "120C18",
		Energy = "B060FF", Shield = "6E7BFF",
	}),
	["ÉCLIPSE"] = style("DAICHA", "ÉCLIPSE", {
		Hair = "0A0A0E", HairTip = "FFD45A", SkinTone = "D8B09A", Eyes = "FFD45A",
		Vest = "16121E", VestTrim = "FFD45A", Shirt = "16121E",
		Sash = "FFD45A", Wraps = "16121E",
		Pants = "0E0A14", PantsShade = "08060C",
		Shoes = "0E0A14", ShoeAccent = "FFD45A", Sole = "08060C",
		Energy = "C080FF", Shield = "FFD45A",
	}),
	-- HIBECARES 崩: stone, rust and embers (RUINES); molten rock (MAGMA).
	RUINES = style("HIBECARES", "RUINES", {
		Hair = "2A1E16", HairTip = "FF8A1A", SkinTone = "C98F6E", Eyes = "FF6A1A",
		Vest = "6A5A4A", VestTrim = "C8102E", Shirt = "6A5A4A",
		Sash = "C8102E", Wraps = "8A8070",
		Pants = "4A3E34", PantsShade = "32281F",
		Shoes = "2A2420", ShoeAccent = "8A8070", Sole = "1A1612",
		Energy = "FF8A1A", Shield = "FFD45A",
	}),
	MAGMA = style("HIBECARES", "MAGMA", {
		Hair = "120C0A", HairTip = "FF4A1A", SkinTone = "B97A55", Eyes = "FFB21A",
		Vest = "2A2420", VestTrim = "FF4A1A", Shirt = "2A2420",
		Sash = "FF4A1A", Wraps = "3A3430",
		Pants = "1E1A16", PantsShade = "120E0C",
		Shoes = "1E1A16", ShoeAccent = "FF4A1A", Sole = "120E0C",
		Energy = "FF5A1A", Shield = "FFB21A",
	}),
})

local STYLE_ORDER = table.freeze({
	KAI = table.freeze({ "CLASSIQUE", "NUIT", "SACRÉ", "MAUDIT" }),
	TARO = table.freeze({ "BRASIER", "CHAMPION" }),
	ZEPHYR = table.freeze({ "AZUR", "TEMPÊTE" }),
	AKEMI = table.freeze({ "OMBRE", "LUNE ROUGE" }),
	RYUKEN = table.freeze({ "BRISÉ", "SANG NOIR" }),
	SHIN = table.freeze({ "COURANT", "ACIER" }),
	DAICHA = table.freeze({ "INVERSÉ", "ÉCLIPSE" }),
	HIBECARES = table.freeze({ "RUINES", "MAGMA" }),
})

local CharacterData = {
	Skins = Skins,
	StyleOrder = STYLE_ORDER,
	SkinOrder = STYLE_ORDER.KAI, -- KAI's styles (older name)
	Skins.CLASSIQUE, -- slot 1
	Skins.NUIT, -- slot 2
}

-- Next style of the same kit, skipping `avoid` (the opponent's style).
function CharacterData.nextSkin(current, avoid)
	local kit = Skins[current] and Skins[current].Kit or "KAI"
	local order = STYLE_ORDER[kit]
	local index = table.find(order, current) or 0
	for step = 1, #order do
		local name = order[(index + step - 1) % #order + 1]
		if name ~= avoid then return name end
	end
	return current
end

-- First style of a kit that differs from `avoid`.
function CharacterData.defaultStyle(kit, avoid)
	local order = STYLE_ORDER[kit] or STYLE_ORDER.KAI
	for _, name in order do
		if name ~= avoid then return name end
	end
	return order[1]
end

return CharacterData
