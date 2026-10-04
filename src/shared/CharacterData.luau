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
local KANJI = { KAI = "開", TARO = "火", ZEPHYR = "風", AKEMI = "影", RYUKEN = "拳", SHIN = "流", DAICHA = "闇", HIBECARES = "崩",
	ASURA = "阿", RAIJIN = "雷", YUKINA = "雪", VENOM = "毒", GORAN = "剛", ASTER = "星", HIBIKI = "響",
	KAZAN = "鎖", KUREN = "血", SYLVA = "森", ELIAN = "癒", NOVA = "機", KUROEN = "蝕", ["KUROEN SHIN"] = "真" }

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
	CLASSIC = skin("CLASSIC", {
		Hair = "121216", HairTip = "C8102E",
		SkinTone = "E3A98A", Eyes = "8E1020",
		Vest = "16161B", VestTrim = "C8102E", Shirt = "E9E9EE",
		Sash = "C8102E", Wraps = "F2F2F5",
		Pants = "1B1B21", PantsShade = "111115",
		Shoes = "F2F2F5", ShoeAccent = "C8102E", Sole = "16161B",
		Energy = "FF2A3D", -- ki color for sparks, aura and slashes
		Shield = "6E7BFF", -- guard effect
	}),
	NIGHT = skin("NIGHT", {
		Hair = "0E1222", HairTip = "3D7BFF",
		SkinTone = "D9A07F", Eyes = "2A5BD7",
		Vest = "141B33", VestTrim = "3D7BFF", Shirt = "DCE3F2",
		Sash = "2F5FE0", Wraps = "E4EAF7",
		Pants = "151C30", PantsShade = "0D1222",
		Shoes = "E4EAF7", ShoeAccent = "3D7BFF", Sole = "141B33",
		Energy = "4D8DFF",
		Shield = "B07BFF",
	}),
	["SACRED"] = skin("SACRED", {
		Hair = "F2EEE8", HairTip = "FFD23F",
		SkinTone = "E8B48F", Eyes = "C99A1E",
		Vest = "F4F1EA", VestTrim = "FFD23F", Shirt = "FFFFFF",
		Sash = "E8B21C", Wraps = "FFFFFF",
		Pants = "EDE7DA", PantsShade = "D6CDBA",
		Shoes = "FFFFFF", ShoeAccent = "E8B21C", Sole = "C9B98F",
		Energy = "FFD23F",
		Shield = "FFFFFF",
	}),
	CURSED = skin("CURSED", {
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
	BLAZE = style("TARO", "BLAZE", {
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
	AZURE = style("ZEPHYR", "AZURE", {
		Hair = "E8F4F2", HairTip = "5FE0D0", SkinTone = "E3B08F", Eyes = "1E9A8E",
		Vest = "1E5E66", VestTrim = "5FE0D0", Shirt = "E8F4F2",
		Sash = "2BB8A8", Wraps = "E8F4F2",
		Pants = "1A3C44", PantsShade = "12282E",
		Shoes = "E8F4F2", ShoeAccent = "5FE0D0", Sole = "1A3C44",
		Energy = "5FE0D0", Shield = "C8F4FF",
	}),
	["STORM"] = style("ZEPHYR", "STORM", {
		Hair = "2A2E38", HairTip = "C8F4FF", SkinTone = "D9A07F", Eyes = "6E7BFF",
		Vest = "3A3F4C", VestTrim = "C8F4FF", Shirt = "D6DCE8",
		Sash = "D6DCE8", Wraps = "6E7BFF",
		Pants = "2A2E38", PantsShade = "1C1F27",
		Shoes = "D6DCE8", ShoeAccent = "6E7BFF", Sole = "1C1F27",
		Energy = "9FD8FF", Shield = "6E7BFF",
	}),
	-- AKEMI 影: black and violet (OMBRE), black and crimson (LUNE ROUGE).
	SHADOW = style("AKEMI", "SHADOW", {
		Hair = "0E0A14", HairTip = "8A3CFF", SkinTone = "D8B09A", Eyes = "8A3CFF",
		Vest = "14101C", VestTrim = "8A3CFF", Shirt = "1E1828",
		Sash = "1E1828", Wraps = "8A3CFF",
		Pants = "14101C", PantsShade = "0C0812",
		Shoes = "14101C", ShoeAccent = "8A3CFF", Sole = "0C0812",
		Energy = "B060FF", Shield = "6E7BFF",
	}),
	["RED MOON"] = style("AKEMI", "RED MOON", {
		Hair = "0E0A0C", HairTip = "E0102B", SkinTone = "E3B8A0", Eyes = "C8102E",
		Vest = "120A0C", VestTrim = "E0102B", Shirt = "1E1214",
		Sash = "1E1214", Wraps = "E0102B",
		Pants = "120A0C", PantsShade = "0A0607",
		Shoes = "120A0C", ShoeAccent = "E0102B", Sole = "0A0607",
		Energy = "FF2A3D", Shield = "FF9F40",
	}),
	-- RYUKEN 拳 (Wilhem's second sheet): white hair, red fists, black (BRISÉ); crimson and
	-- black (SANG NOIR).
	["SHATTERED"] = style("RYUKEN", "SHATTERED", {
		Hair = "F2ECE8", HairTip = "FF3B3B", SkinTone = "D9A07F", Eyes = "D01818",
		Vest = "1A1416", VestTrim = "E0102B", Shirt = "1A1416",
		Sash = "C8102E", Wraps = "E0102B",
		Pants = "26262C", PantsShade = "18181C",
		Shoes = "1A1416", ShoeAccent = "E0102B", Sole = "F2ECE8",
		Energy = "FF2A2A", Shield = "FFB0A0",
	}),
	["BLACK BLOOD"] = style("RYUKEN", "BLACK BLOOD", {
		Hair = "1A1214", HairTip = "FF2A2A", SkinTone = "C98F6E", Eyes = "FF2A2A",
		Vest = "5A0A12", VestTrim = "FF2A2A", Shirt = "5A0A12",
		Sash = "1A1214", Wraps = "1A1214",
		Pants = "120E10", PantsShade = "0A0809",
		Shoes = "120E10", ShoeAccent = "FF2A2A", Sole = "5A0A12",
		Energy = "FF4A2A", Shield = "FFD0A0",
	}),
	-- SHIN 流: navy coat, blue edge, silver blade (COURANT); black and steel (ACIER).
	CURRENT = style("SHIN", "CURRENT", {
		Hair = "141A2E", HairTip = "3D9BFF", SkinTone = "E3B08F", Eyes = "2E8BFF",
		Vest = "18223F", VestTrim = "3D9BFF", Shirt = "E4ECF7",
		Sash = "3D9BFF", Wraps = "C8D4E8",
		Pants = "141A2E", PantsShade = "0C1020",
		Shoes = "1B2238", ShoeAccent = "3D9BFF", Sole = "0C1020",
		Energy = "4DA8FF", Shield = "C8F0FF",
	}),
	STEEL = style("SHIN", "STEEL", {
		Hair = "D6DCE8", HairTip = "6FD8FF", SkinTone = "D9A07F", Eyes = "6FD8FF",
		Vest = "1C1C22", VestTrim = "B8C4D8", Shirt = "2A2A32",
		Sash = "B8C4D8", Wraps = "1C1C22",
		Pants = "1C1C22", PantsShade = "101014",
		Shoes = "1C1C22", ShoeAccent = "B8C4D8", Sole = "101014",
		Energy = "8FE0FF", Shield = "3D9BFF",
	}),
	-- DAICHA 闇: white robe, violet sash and shadows (INVERSÉ); black robe, gold eyes (ÉCLIPSE).
	["INVERTED"] = style("DAICHA", "INVERTED", {
		Hair = "120A1C", HairTip = "A040FF", SkinTone = "E8C0A8", Eyes = "B060FF",
		Vest = "F0EEF4", VestTrim = "A040FF", Shirt = "F0EEF4",
		Sash = "7A2CC8", Wraps = "2A1A3A",
		Pants = "1E1428", PantsShade = "120C18",
		Shoes = "1E1428", ShoeAccent = "A040FF", Sole = "120C18",
		Energy = "B060FF", Shield = "6E7BFF",
	}),
	["ECLIPSE"] = style("DAICHA", "ECLIPSE", {
		Hair = "0A0A0E", HairTip = "FFD45A", SkinTone = "D8B09A", Eyes = "FFD45A",
		Vest = "16121E", VestTrim = "FFD45A", Shirt = "16121E",
		Sash = "FFD45A", Wraps = "16121E",
		Pants = "0E0A14", PantsShade = "08060C",
		Shoes = "0E0A14", ShoeAccent = "FFD45A", Sole = "08060C",
		Energy = "C080FF", Shield = "FFD45A",
	}),
	-- HIBECARES 崩: stone, rust and embers (RUINES); molten rock (MAGMA).
	ASURA = style("ASURA", "ASURA", {
		Hair = "0A0A0E", HairTip = "FFD23F",
		SkinTone = "8A5A44", Eyes = "FFD23F",
		Vest = "0E0E12", VestTrim = "FFD23F", Shirt = "2A0A0E",
		Sash = "FFD23F", Wraps = "C8A040",
		Pants = "16090B", PantsShade = "0B0507",
		Shoes = "C8A040", ShoeAccent = "FF2A3D", Sole = "0E0E12",
		Energy = "FFD23F", Shield = "FF2A3D",
	}),
	["AWAKENED"] = skin("AWAKENED", { -- KAI's style won by beating ASURA (CHALLENGE)
		Hair = "F5F0E0", HairTip = "FFD23F",
		SkinTone = "E3A98A", Eyes = "FFD23F",
		Vest = "F2F2F5", VestTrim = "FFD23F", Shirt = "16161B",
		Sash = "FFD23F", Wraps = "FFE9B0",
		Pants = "F2F2F5", PantsShade = "C8C8D0",
		Shoes = "16161B", ShoeAccent = "FFD23F", Sole = "F2F2F5",
		Energy = "FFD23F", Shield = "FFE9B0",
	}),
	-- Wilhem's third sheet: two styles each.
	THUNDERSTORM = style("RAIJIN", "THUNDERSTORM", { Hair = "F2F2F5", HairTip = "FFE85A", SkinTone = "E0A884", Eyes = "FFE85A", Vest = "141418", VestTrim = "FFE85A", Shirt = "141418", Sash = "FFE85A", Wraps = "2A2A33", Pants = "1C1C22", PantsShade = "101014", Shoes = "1C1C22", ShoeAccent = "FFE85A", Sole = "101014", Energy = "FFE85A", Shield = "8FD8FF" }),
	DIVINE = style("RAIJIN", "DIVINE", { Hair = "FFFFFF", HairTip = "8FD8FF", SkinTone = "E8B898", Eyes = "8FD8FF", Vest = "F2F0EA", VestTrim = "FFD23F", Shirt = "F2F0EA", Sash = "FFD23F", Wraps = "FFFFFF", Pants = "E6E0D4", PantsShade = "C8C0B0", Shoes = "F2F0EA", ShoeAccent = "8FD8FF", Sole = "C8C0B0", Energy = "8FD8FF", Shield = "FFE85A" }),
	WINTER = style("YUKINA", "WINTER", { Hair = "D8E2EE", HairTip = "9FE6FF", SkinTone = "F2D2C2", Eyes = "3D9BFF", Vest = "F4F8FC", VestTrim = "9FE6FF", Shirt = "F4F8FC", Sash = "6FC8F0", Wraps = "DCEFFA", Pants = "E8F2FA", PantsShade = "BCD8EA", Shoes = "F4F8FC", ShoeAccent = "9FE6FF", Sole = "BCD8EA", Energy = "9FE6FF", Shield = "FFFFFF" }),
	["EMPRESS"] = style("YUKINA", "EMPRESS", { Hair = "C8CCD8", HairTip = "FFFFFF", SkinTone = "F0D0C0", Eyes = "6FC8F0", Vest = "1E2A4A", VestTrim = "C8E8FF", Shirt = "1E2A4A", Sash = "C8E8FF", Wraps = "3A4A70", Pants = "1A2440", PantsShade = "10182A", Shoes = "1E2A4A", ShoeAccent = "C8E8FF", Sole = "10182A", Energy = "C8F0FF", Shield = "6FC8F0" }),
	TOXIC = style("VENOM", "TOXIC", { Hair = "5A2A8A", HairTip = "7CFF4A", SkinTone = "C8A890", Eyes = "7CFF4A", Vest = "141216", VestTrim = "7CFF4A", Shirt = "2A2430", Sash = "7CFF4A", Wraps = "3A3440", Pants = "16141A", PantsShade = "0E0C10", Shoes = "16141A", ShoeAccent = "7CFF4A", Sole = "0E0C10", Energy = "7CFF4A", Shield = "B060FF" }),
	MUTATION = style("VENOM", "MUTATION", { Hair = "2A3A1A", HairTip = "C8FF4A", SkinTone = "9AB08A", Eyes = "FFE85A", Vest = "2A3A20", VestTrim = "B060FF", Shirt = "1A2414", Sash = "B060FF", Wraps = "3A4A30", Pants = "1A2414", PantsShade = "10180C", Shoes = "1A2414", ShoeAccent = "B060FF", Sole = "10180C", Energy = "B8FF5A", Shield = "B060FF" }),
	TITAN = style("GORAN", "TITAN", { Hair = "141210", HairTip = "2A2420", SkinTone = "B98060", Eyes = "5A3A2A", Vest = "C8102E", VestTrim = "141418", Shirt = "B98060", Sash = "141418", Wraps = "E8E0D4", Pants = "141418", PantsShade = "0C0C10", Shoes = "C8102E", ShoeAccent = "141418", Sole = "0C0C10", Energy = "FF4A3A", Shield = "FFB0A0" }),
	GLADIATOR = style("GORAN", "GLADIATOR", { Hair = "2A1A10", HairTip = "5A3A20", SkinTone = "A87050", Eyes = "3A2A1A", Vest = "8A6A3A", VestTrim = "FFD23F", Shirt = "A87050", Sash = "FFD23F", Wraps = "8A6A3A", Pants = "5A4028", PantsShade = "3A2818", Shoes = "5A4028", ShoeAccent = "FFD23F", Sole = "2A1C10", Energy = "FFB03A", Shield = "FFD23F" }),
	COSMOS = style("ASTER", "COSMOS", { Hair = "D8D8E4", HairTip = "B49CFF", SkinTone = "E0B494", Eyes = "B49CFF", Vest = "10101C", VestTrim = "B49CFF", Shirt = "1A1A2A", Sash = "6A5ACF", Wraps = "2A2A40", Pants = "10101C", PantsShade = "08080E", Shoes = "10101C", ShoeAccent = "B49CFF", Sole = "08080E", Energy = "B49CFF", Shield = "E8E0FF" }),
	["SINGULARITY"] = style("ASTER", "SINGULARITY", { Hair = "0A0A10", HairTip = "FF6A2A", SkinTone = "D0A080", Eyes = "FF6A2A", Vest = "0A0A10", VestTrim = "FF6A2A", Shirt = "14141C", Sash = "FF6A2A", Wraps = "1A1A24", Pants = "0A0A10", PantsShade = "050508", Shoes = "0A0A10", ShoeAccent = "FF6A2A", Sole = "050508", Energy = "FF7A3A", Shield = "B49CFF" }),
	TECHNO = style("HIBIKI", "TECHNO", { Hair = "FF8AD0", HairTip = "FFFFFF", SkinTone = "F0C8B0", Eyes = "FF6FC8", Vest = "F4F4F8", VestTrim = "141418", Shirt = "141418", Sash = "FF6FC8", Wraps = "141418", Pants = "141418", PantsShade = "0C0C10", Shoes = "F4F4F8", ShoeAccent = "FF6FC8", Sole = "141418", Energy = "FF6FC8", Shield = "6FE0FF" }),
	HARMONY = style("HIBIKI", "HARMONY", { Hair = "FFB0E0", HairTip = "FFE85A", SkinTone = "F0C8B0", Eyes = "6FE0FF", Vest = "2A1A3A", VestTrim = "6FE0FF", Shirt = "F4F4F8", Sash = "6FE0FF", Wraps = "F4F4F8", Pants = "2A1A3A", PantsShade = "1A1024", Shoes = "2A1A3A", ShoeAccent = "6FE0FF", Sole = "1A1024", Energy = "6FE0FF", Shield = "FF6FC8" }),
	-- KUROEN: dark skin, a big white mane with red streaks swept back, a torn sleeveless black
	-- jacket, wide white trousers, black and red gauntlets, an aura of red and black.
	["EMPEROR"] = style("KUROEN", "EMPEROR", { Hair = "F4F2EE", HairTip = "E0102E", SkinTone = "5C3826", Eyes = "FF2A3D", Vest = "0C0C0E", VestTrim = "E0102E", Shirt = "0C0C0E", Sash = "E0102E", Wraps = "141016", Pants = "EEEAE2", PantsShade = "BEB8AE", Shoes = "0C0C0E", ShoeAccent = "E0102E", Sole = "050506", Energy = "E0102E", Shield = "FF6A7A" }),
	-- KUROEN SHIN (boss): his hair gone white-gold, a white and gold aura, the eclipse turned to
	-- light. DIVINE ECLIPSE: the same look for KUROEN himself, won by beating him (CHALLENGE · KUROEN SHIN).
	["TRUE EMPEROR"] = style("KUROEN SHIN", "TRUE EMPEROR", { Hair = "FFFFFF", HairTip = "FFD23F", SkinTone = "5C3826", Eyes = "FFD23F", Vest = "F4F0E6", VestTrim = "FFD23F", Shirt = "F4F0E6", Sash = "FFD23F", Wraps = "F4F0E6", Pants = "141418", PantsShade = "0C0C10", Shoes = "F4F0E6", ShoeAccent = "FFD23F", Sole = "0C0C10", Energy = "FFE9A0", Shield = "FFFFFF" }),
	["DIVINE ECLIPSE"] = style("KUROEN", "DIVINE ECLIPSE", { Hair = "FFFFFF", HairTip = "FFD23F", SkinTone = "5C3826", Eyes = "FFD23F", Vest = "F4F0E6", VestTrim = "FFD23F", Shirt = "F4F0E6", Sash = "FFD23F", Wraps = "F4F0E6", Pants = "141418", PantsShade = "0C0C10", Shoes = "F4F0E6", ShoeAccent = "FFD23F", Sole = "0C0C10", Energy = "FFE9A0", Shield = "FFFFFF" }),
	["BLOOD MOON"] = style("KUROEN", "BLOOD MOON", { Hair = "D8D0D0", HairTip = "8A0A1A", SkinTone = "4E2E20", Eyes = "FFB03A", Vest = "2A060E", VestTrim = "FFB03A", Shirt = "2A060E", Sash = "8A0A1A", Wraps = "2A060E", Pants = "1C1C20", PantsShade = "101014", Shoes = "2A060E", ShoeAccent = "FFB03A", Sole = "08080A", Energy = "FF4A2A", Shield = "FFB03A" }),
	PRISONER = style("KAZAN", "PRISONER", { Hair = "8A8A90", HairTip = "5A5A60", SkinTone = "D8A888", Eyes = "FFB04A", Vest = "141418", VestTrim = "8A8A94", Shirt = "1C1C22", Sash = "8A8A94", Wraps = "5A5A64", Pants = "141418", PantsShade = "0C0C10", Shoes = "141418", ShoeAccent = "FFB04A", Sole = "0C0C10", Energy = "FFB04A", Shield = "E0E0E8" }),
	["EXECUTIONER"] = style("KAZAN", "EXECUTIONER", { Hair = "1A1A1E", HairTip = "C8102E", SkinTone = "C8987A", Eyes = "FF4A3A", Vest = "2A0A10", VestTrim = "C8102E", Shirt = "141418", Sash = "C8102E", Wraps = "3A3A40", Pants = "1A1A1E", PantsShade = "0E0E12", Shoes = "1A1A1E", ShoeAccent = "C8102E", Sole = "0E0E12", Energy = "FF5A3A", Shield = "FFB04A" }),
	["ROYAL BLOOD"] = style("KUREN", "ROYAL BLOOD", { Hair = "6A0A18", HairTip = "D0102E", SkinTone = "F2DCD4", Eyes = "D0102E", Vest = "4A0A18", VestTrim = "FFD23F", Shirt = "1A0A0E", Sash = "D0102E", Wraps = "2A0A10", Pants = "1A0A0E", PantsShade = "0E0508", Shoes = "1A0A0E", ShoeAccent = "FFD23F", Sole = "0E0508", Energy = "D0102E", Shield = "FFD23F" }),
	FORBIDDEN = style("KUREN", "FORBIDDEN", { Hair = "1A0A0E", HairTip = "FF2A3D", SkinTone = "E8D4D0", Eyes = "FF2A3D", Vest = "0E0A0C", VestTrim = "FF2A3D", Shirt = "2A0A10", Sash = "FF2A3D", Wraps = "0E0A0C", Pants = "0E0A0C", PantsShade = "060406", Shoes = "0E0A0C", ShoeAccent = "FF2A3D", Sole = "060406", Energy = "FF2A4A", Shield = "8A0A1A" }),
	WILD = style("SYLVA", "WILD", { Hair = "3A8A3A", HairTip = "8AD84A", SkinTone = "D8A884", Eyes = "4AD86A", Vest = "5A3A20", VestTrim = "1E8A4A", Shirt = "2A5A2A", Sash = "1E8A4A", Wraps = "6A4A28", Pants = "4A3018", PantsShade = "2E1E10", Shoes = "3A2814", ShoeAccent = "4AD86A", Sole = "2E1E10", Energy = "4AD86A", Shield = "C8F0A0" }),
	BLOSSOM = style("SYLVA", "BLOSSOM", { Hair = "5AB85A", HairTip = "FF8AC8", SkinTone = "E0B494", Eyes = "FF8AC8", Vest = "EAF4E0", VestTrim = "FF8AC8", Shirt = "5AB85A", Sash = "FF8AC8", Wraps = "EAF4E0", Pants = "3A7A3A", PantsShade = "2A5A2A", Shoes = "EAF4E0", ShoeAccent = "FF8AC8", Sole = "2A5A2A", Energy = "8AF08A", Shield = "FF8AC8" }),
	["CELESTIAL"] = style("ELIAN", "CELESTIAL", { Hair = "F0D888", HairTip = "FFFFFF", SkinTone = "EEC4A4", Eyes = "3AD8C8", Vest = "F6F4EE", VestTrim = "FFD23F", Shirt = "FFFFFF", Sash = "FFD23F", Wraps = "F6F4EE", Pants = "EAE4D8", PantsShade = "CCC4B4", Shoes = "F6F4EE", ShoeAccent = "3AD8C8", Sole = "CCC4B4", Energy = "FFE9A0", Shield = "3AD8C8" }),
	CORRUPTED = style("ELIAN", "CORRUPTED", { Hair = "3A3428", HairTip = "B060FF", SkinTone = "D0B8A8", Eyes = "B060FF", Vest = "1A1620", VestTrim = "B060FF", Shirt = "2A2430", Sash = "B060FF", Wraps = "1A1620", Pants = "1A1620", PantsShade = "0E0C12", Shoes = "1A1620", ShoeAccent = "B060FF", Sole = "0E0C12", Energy = "C080FF", Shield = "3AD8C8" }),
	PROTOTYPE = style("NOVA", "PROTOTYPE", { Hair = "D0D4DC", HairTip = "FF8A2A", SkinTone = "E8BC9C", Eyes = "FF8A2A", Vest = "16161C", VestTrim = "FF8A2A", Shirt = "2A2A33", Sash = "FF8A2A", Wraps = "5A5A66", Pants = "1C1C22", PantsShade = "101014", Shoes = "1C1C22", ShoeAccent = "FF8A2A", Sole = "101014", Energy = "FF8A2A", Shield = "6FE0FF" }),
	OMEGA = style("NOVA", "OMEGA", { Hair = "F4F4F8", HairTip = "6FE0FF", SkinTone = "E8BC9C", Eyes = "6FE0FF", Vest = "E8ECF2", VestTrim = "6FE0FF", Shirt = "1C1C22", Sash = "6FE0FF", Wraps = "8A8A96", Pants = "E8ECF2", PantsShade = "B8BCC4", Shoes = "1C1C22", ShoeAccent = "6FE0FF", Sole = "E8ECF2", Energy = "6FE0FF", Shield = "FF8A2A" }),
	RUINS = style("HIBECARES", "RUINS", {
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
	KAI = table.freeze({ "CLASSIC", "NIGHT", "SACRED", "CURSED", "AWAKENED" }), -- (ÉVEILLÉ: won against ASURA)
	ASURA = table.freeze({ "ASURA" }),
	TARO = table.freeze({ "BLAZE", "CHAMPION" }),
	ZEPHYR = table.freeze({ "AZURE", "STORM" }),
	AKEMI = table.freeze({ "SHADOW", "RED MOON" }),
	RYUKEN = table.freeze({ "SHATTERED", "BLACK BLOOD" }),
	SHIN = table.freeze({ "CURRENT", "STEEL" }),
	DAICHA = table.freeze({ "INVERTED", "ECLIPSE" }),
	HIBECARES = table.freeze({ "RUINS", "MAGMA" }),
	RAIJIN = table.freeze({ "THUNDERSTORM", "DIVINE" }),
	YUKINA = table.freeze({ "WINTER", "EMPRESS" }),
	VENOM = table.freeze({ "TOXIC", "MUTATION" }),
	GORAN = table.freeze({ "TITAN", "GLADIATOR" }),
	ASTER = table.freeze({ "COSMOS", "SINGULARITY" }),
	HIBIKI = table.freeze({ "TECHNO", "HARMONY" }),
	KAZAN = table.freeze({ "PRISONER", "EXECUTIONER" }),
	KUREN = table.freeze({ "ROYAL BLOOD", "FORBIDDEN" }),
	SYLVA = table.freeze({ "WILD", "BLOSSOM" }),
	ELIAN = table.freeze({ "CELESTIAL", "CORRUPTED" }),
	NOVA = table.freeze({ "PROTOTYPE", "OMEGA" }),
	KUROEN = table.freeze({ "EMPEROR", "BLOOD MOON", "DIVINE ECLIPSE" }), -- (DIVINE ECLIPSE: won against KUROEN SHIN)
	["KUROEN SHIN"] = table.freeze({ "TRUE EMPEROR" }),
})

local CharacterData = {
	Skins = Skins,
	StyleOrder = STYLE_ORDER,
	SkinOrder = STYLE_ORDER.KAI, -- KAI's styles (older name)
	Skins.CLASSIC, -- slot 1
	Skins.NIGHT, -- slot 2
}

-- Styles to earn (the server checks): the profile field that must be at least 1.
CharacterData.LOCKED = table.freeze({ ["AWAKENED"] = "asuraGrade", ["DIVINE ECLIPSE"] = "shinGrade" })

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
