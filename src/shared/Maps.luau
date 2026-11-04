--!strict
--[[
	The stages (pure data, no Roblox API: materials and colours are names and hex strings, the
	client's ArenaBuilder builds them). Every stage keeps the same fighting ground: a deck at
	y = 0 from x = -28 to 28 (CombatConfig ArenaMinX / ArenaMaxX), so no stage changes the
	game, only its look. Tests: Lobby (every stage complete, ids unique, chosen by the menu).
	  props      the set dressing built around the deck
	  sky        painted bands, bottom to top { top height, colour }
	  orb        the sun or moon { colour, x, y, size, stripes }
	  hills      three depth layers of silhouettes { colour }
	  floor      { colour, material, worn, trim (neon edge), line (painted planks/tiles) }
	  frame      the structure framing the fight { colour, dark }
	  light      colour of its lamps (lanterns, neon, lava...)
	  air        falling or rising particles { kind, colours, rate }
	  mist       colour of the ground mist
	  lighting   { clock, brightness, ambient, outdoor, tint, contrast, saturation, bloom, exposure (the
	             camera's exposure compensation, ≤ 0: Wilhem, « la luminosité de certaines maps, c'est abusé »),
	             atmosphere, decay, density, haze }
]]
local Maps = {}

Maps.LIST = {
	{
		id = "TEMPLE", name = "SCARLET TEMPLE", kanji = "寺", props = "temple",
		sky = { { 30, "C4182F" }, { 42, "7A0F1F" }, { 54, "420A14" }, { 70, "1F070C" }, { 88, "0C0508" } },
		orb = { color = "F5EDE6", x = -18, y = 22, size = 34, stripes = "C4182F" },
		hills = { "5A0C18", "2E0810", "140508" },
		floor = { color = "4A3230", material = "WoodPlanks", worn = "5C403A", trim = "FF2A3D", line = "1A1214" },
		frame = { color = "C8102E", dark = "0B0B0E" },
		light = "FF5A4E",
		air = { kind = "petals", colors = { "FFE3E7", "FF6B7D" }, rate = 9 },
		mist = "C85060",
		lighting = { clock = 17.4, brightness = 1.9, ambient = "7E6266", outdoor = "987276", tint = "FFF0EE", contrast = 0.18, exposure = -0.15,
			saturation = 0.22, bloom = 0.5, atmosphere = "A8283A", decay = "1F070C", density = 0.32, haze = 1.5 },
	},
	{
		id = "FROZEN", name = "FROZEN LAKE", kanji = "氷", props = "ice",
		sky = { { 26, "1B3A6B" }, { 40, "13284C" }, { 54, "0C1A33" }, { 70, "070F1F" }, { 88, "03070F" } },
		orb = { color = "E8F4FF", x = 20, y = 26, size = 22 },
		hills = { "2A4A72", "1A3150", "0E1C30" },
		floor = { color = "A8D4F0", material = "Ice", worn = "C8E8FF", trim = "6FD8FF", line = "7FB0D0" },
		frame = { color = "DDEEFF", dark = "1A2A40" },
		light = "8FE0FF",
		air = { kind = "snow", colors = { "FFFFFF", "CFEFFF" }, rate = 16 },
		mist = "B8E0FF",
		lighting = { clock = 0.5, brightness = 1.5, ambient = "5A6E90", outdoor = "7A90B8", tint = "E8F4FF", contrast = 0.15, exposure = -0.2,
			saturation = 0.05, bloom = 0.55, atmosphere = "6A8AB8", decay = "0A1424", density = 0.36, haze = 2 },
	},
	{
		id = "NEON", name = "NEON ROOFTOP", kanji = "街", props = "city",
		sky = { { 24, "3A1460" }, { 38, "24104A" }, { 52, "160A33" }, { 70, "0B0620" }, { 88, "05030F" } },
		orb = { color = "FF5AD8", x = -24, y = 30, size = 16 },
		hills = { "2A1A48", "1A1030", "0E0820" },
		floor = { color = "3A3A44", material = "Concrete", worn = "4A4A55", trim = "00E5FF", line = "22222A" },
		frame = { color = "FF2AD4", dark = "101018" },
		light = "00E5FF",
		air = { kind = "rain", colors = { "B8D8FF", "6A8ACC" }, rate = 40 },
		mist = "5A3A8A",
		lighting = { clock = 22, brightness = 1.2, ambient = "4A3A6A", outdoor = "5A4A80", tint = "F0E8FF", contrast = 0.25,
			saturation = 0.35, bloom = 0.7, atmosphere = "3A2060", decay = "0A0518", density = 0.3, haze = 1.2 },
	},
	{
		id = "VOLCANO", name = "VOLCANO FORGE", kanji = "炎", props = "volcano",
		sky = { { 28, "FF5A1A" }, { 40, "B8320E" }, { 54, "5A1408" }, { 70, "240804" }, { 88, "0C0302" } },
		orb = { color = "FFC870", x = 16, y = 18, size = 40 },
		hills = { "4A1A0E", "2A0E08", "140604" },
		floor = { color = "2A2224", material = "Basalt", worn = "3A2E2E", trim = "FF6A1A", line = "FF4A10" },
		frame = { color = "3A2A26", dark = "120A08" },
		light = "FF7A2A",
		air = { kind = "embers", colors = { "FFE0A0", "FF4A10" }, rate = 22 },
		mist = "6A2A1A",
		lighting = { clock = 18.2, brightness = 1.7, ambient = "8A4A3A", outdoor = "A85A40", tint = "FFE8D8", contrast = 0.28, exposure = -0.1,
			saturation = 0.25, bloom = 0.6, atmosphere = "8A2A10", decay = "200804", density = 0.4, haze = 2.2 },
	},
	{
		id = "BAMBOO", name = "BAMBOO DOJO", kanji = "竹", props = "bamboo",
		sky = { { 30, "CFE8A0" }, { 44, "8CC870" }, { 58, "4A8A50" }, { 72, "24502E" }, { 88, "102418" } },
		orb = { color = "FFF6D0", x = -14, y = 30, size = 26 },
		hills = { "3A6A40", "24482A", "122818" },
		floor = { color = "8A6A40", material = "WoodPlanks", worn = "A0804E", trim = "FFD23F", line = "4A3820" },
		frame = { color = "2A4A1E", dark = "14200E" },
		light = "FFE08A",
		air = { kind = "leaves", colors = { "B8E070", "6AA040" }, rate = 7 },
		mist = "A8D8A0",
		lighting = { clock = 9.5, brightness = 2, ambient = "7A8A6A", outdoor = "98A880", tint = "F4FFE8", contrast = 0.14, exposure = -0.2,
			saturation = 0.18, bloom = 0.45, atmosphere = "A8C890", decay = "4A6A40", density = 0.28, haze = 1.4 },
	},
	{
		id = "SKY", name = "CLOUD PALACE", kanji = "天", props = "sky",
		sky = { { 22, "FFE6A8" }, { 36, "FFC07A" }, { 50, "F08A6A" }, { 68, "7A5AA8" }, { 88, "2A2050" } },
		orb = { color = "FFF4C8", x = 0, y = 14, size = 46 },
		hills = { "FFFFFF", "F0E8F8", "D8D0E8" },
		floor = { color = "E8E0D0", material = "Marble", worn = "F4EEE0", trim = "FFD23F", line = "C8BEA8" },
		frame = { color = "FFD23F", dark = "8A6A20" },
		light = "FFE8A0",
		air = { kind = "feathers", colors = { "FFFFFF", "FFE8C0" }, rate = 6 },
		mist = "FFFFFF",
		lighting = { clock = 6.4, brightness = 2, ambient = "9A8CAA", outdoor = "B8A8C4", tint = "FFF6EC", contrast = 0.14, exposure = -0.3,
			saturation = 0.2, bloom = 0.5, atmosphere = "F0C8A8", decay = "6A5A90", density = 0.3, haze = 1.6 },
	},
}

Maps.BY_ID = {}
for i, map in Maps.LIST do
	Maps.BY_ID[map.id] = map
	map.index = i
end
Maps.DEFAULT = "TEMPLE"

-- The stage of a match: the one asked for, else one drawn from `seed` (RANDOM).
function Maps.pick(asked: string?, seed: number): string
	if asked and Maps.BY_ID[asked] then return asked end
	return Maps.LIST[(math.floor(seed) % #Maps.LIST) + 1].id
end

return Maps
