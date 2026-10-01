-- KAI 開 — original character from Wilhem's art direction sheet: black, white and red,
-- open sleeveless vest over a white tank top, red sash, hand wraps, baggy pants, sneakers.
-- Slot 2 uses a skin of the same character until a second fighter exists.
-- Colors are hex strings so the data stays engine-independent.
local function skin(name, colors)
	colors.Name = "KAI"
	colors.Kanji = "開"
	colors.Skin = name
	return table.freeze(colors)
end

return table.freeze({
	skin("CLASSIQUE", {
		Hair = "121216", HairTip = "C8102E",
		SkinTone = "E3A98A", Eyes = "8E1020",
		Vest = "16161B", VestTrim = "C8102E", Shirt = "E9E9EE",
		Sash = "C8102E", Wraps = "F2F2F5",
		Pants = "1B1B21", PantsShade = "111115",
		Shoes = "F2F2F5", ShoeAccent = "C8102E", Sole = "16161B",
		Energy = "FF2A3D", -- ki color for sparks, aura and slashes
		Shield = "6E7BFF", -- guard effect
	}),
	skin("NUIT", {
		Hair = "0E1222", HairTip = "3D7BFF",
		SkinTone = "D9A07F", Eyes = "2A5BD7",
		Vest = "141B33", VestTrim = "3D7BFF", Shirt = "DCE3F2",
		Sash = "2F5FE0", Wraps = "E4EAF7",
		Pants = "151C30", PantsShade = "0D1222",
		Shoes = "E4EAF7", ShoeAccent = "3D7BFF", Sole = "141B33",
		Energy = "4D8DFF",
		Shield = "B07BFF",
	}),
})
