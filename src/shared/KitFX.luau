--[[
	The visual identity of every fighter (pure Luau: no Roblox API, no require). Data only:
	src/client/EffectsController.luau draws it. One element per fighter, and everything they do
	speaks it: the flourish of a blow going out (`swing`, bigger on a heavy blow), the
	mark it leaves on the opponent (`hit`), the dash (`dash`), the motes always floating round
	the body (`ambient`, very light), the projectiles (`shot`) and the strike trails of the limbs (`trail`).

	Colours: "energy" = the ki colour of the style worn (a shop or earned style recolours the
	effects with the outfit), any other value is a hex of the element itself (ice stays white
	blue, poison keeps its green drops): the SHAPES and the ACCENT tell the fighter apart, the
	energy follows the style.

	To give a fighter new effects: change their line here; a new verb (a word in SWINGS, HITS,
	DASHES, SHOTS) needs its drawing in EffectsController (it checks every verb at load).
	Tests: tests/Kits.test.luau ("visual identity").
]]
local KitFX = {}

-- The verbs the client knows how to draw.
KitFX.SWINGS = {
	kiStreak = true, fireStreak = true, windCrescent = true, shadowSlash = true, heatStreaks = true, stoneWeight = true,
	spearBolt = true, fanArcs = true, fangSwipe = true, titanStomp = true, gravityRings = true, soundRipples = true,
	tripleClaw = true, bloodCrescent = true, vineWhip = true, lightPalm = true, pistonPunch = true, eclipseStreak = true,
	fourArms = true, divineStreak = true, weapon = true,
}
KitFX.HITS = {
	kiPop = true, fireRing = true, airBurst = true, shadowCross = true, rageCrack = true, rubble = true, bladeLine = true,
	orbBurst = true, thunderStrike = true, iceShards = true, toxicSplash = true, quake = true, implode = true,
	soundBurst = true, clawMarks = true, bloodBloom = true, leafBurst = true, halo = true, glitch = true, eclipseBurst = true,
	goldenFists = true, divineBurst = true,
}
KitFX.DASHES = {
	dust = true, embers = true, gust = true, shade = true, scorch = true, tremor = true, sparks = true, frost = true,
	venomTrail = true, stomp = true, float = true, beat = true, chain = true, mist = true, petals = true, glow = true,
	thrusters = true, redShade = true, ripple = true, warp = true, goldShade = true,
}

-- What their projectiles look like (a ki blast, a blade of wind, a kunai...). NOVA's drones
-- are always drones; a trap always lies on the floor.
KitFX.SHOTS = {
	ball = true, crescent = true, kunai = true, wave = true, slash = true, sphere = true, bolt = true, shard = true,
	cloud = true, well = true, pulse = true, lance = true, trap = true, bullet = true, eclipse = true,
}

-- motion of the ambient motes: rise (fire, steam), fall (snow, petals), drift (dust, sound),
-- orbit (gravity, drones), flicker (sparks: short and fast).
KitFX.MOTIONS = { rise = true, fall = true, drift = true, orbit = true, flicker = true }

local function kit(t)
	return table.freeze(t)
end

KitFX.KITS = {
	-- KAI 開: pure ki, white and the style's colour: clean streaks, round pops.
	KAI = kit({ element = "ki", accent = "FFFFFF", shot = "ball", swing = "kiStreak", hit = "kiPop", dash = "dust",
		ambient = { motion = "rise", colors = { "energy", "FFFFFF" }, rate = 2, size = 0.35 },
		trail = { "energy", "FFFFFF" } }),
	-- TARO 火: the boxer on fire: fire dragged by the glove, rings of fire on the hit, embers.
	TARO = kit({ element = "fire", accent = "FFD45A", shot = "ball", swing = "fireStreak", hit = "fireRing", dash = "embers",
		ambient = { motion = "rise", colors = { "FF7A1A", "FFD45A" }, rate = 4, size = 0.3 },
		trail = { "FF7A1A", "FFD45A" } }),
	-- ZEPHYR 風: wind: white crescents on every kick, gusts, air rings.
	ZEPHYR = kit({ element = "wind", accent = "E8F6FF", shot = "crescent", swing = "windCrescent", hit = "airBurst", dash = "gust",
		ambient = { motion = "drift", colors = { "E8F6FF", "energy" }, rate = 2, size = 0.25 },
		trail = { "FFFFFF", "energy" } }),
	-- AKEMI 影: shadow: thin dark cuts, an X on the hit, a shade left behind.
	AKEMI = kit({ element = "shadow", accent = "140A1E", shot = "kunai", swing = "shadowSlash", hit = "shadowCross", dash = "shade",
		ambient = { motion = "drift", colors = { "140A1E", "energy" }, rate = 2, size = 0.4 },
		trail = { "energy", "140A1E" } }),
	-- RYUKEN 拳: rage: heat streaks, cracks of red light, smoke off the fists.
	RYUKEN = kit({ element = "rage", accent = "FF3A1A", shot = "wave", swing = "heatStreaks", hit = "rageCrack", dash = "scorch",
		ambient = { motion = "rise", colors = { "8C8A90", "energy" }, rate = 2, size = 0.45 },
		trail = { "energy", "FF3A1A" } }),
	-- SHIN 流: the blade and water: arcs of the katana, straight cuts.
	SHIN = kit({ element = "water", accent = "BFF4FF", shot = "slash", swing = "weapon", hit = "bladeLine", dash = "ripple",
		ambient = { motion = "fall", colors = { "BFF4FF", "energy" }, rate = 1.5, size = 0.2 },
		trail = { "FFFFFF", "energy" } }),
	-- DAICHA 闇: the void orb: dark cores, rings, the orb's bursts.
	DAICHA = kit({ element = "void", accent = "0B0712", shot = "sphere", swing = "weapon", hit = "orbBurst", dash = "warp",
		ambient = { motion = "orbit", colors = { "energy", "0B0712" }, rate = 2, size = 0.35 },
		trail = { "energy", "0B0712" } }),
	-- HIBECARES 崩: stone: weight, dust, rubble flung from the floor.
	HIBECARES = kit({ element = "stone", accent = "7A6D62", shot = "ball", swing = "stoneWeight", hit = "rubble", dash = "tremor",
		ambient = { motion = "drift", colors = { "B8A890", "energy" }, rate = 1.5, size = 0.4 },
		trail = { "energy", "B8A890" } }),
	-- RAIJIN 雷: thunder: the spear's thrust is a bolt, the hit a strike from above, sparks.
	RAIJIN = kit({ element = "thunder", accent = "FFF6A0", shot = "bolt", swing = "spearBolt", hit = "thunderStrike", dash = "sparks",
		ambient = { motion = "flicker", colors = { "FFF6A0", "energy" }, rate = 4, size = 0.25 },
		trail = { "FFFFFF", "energy" } }),
	-- YUKINA 雪: frost: the two fans draw twin icy arcs, the hit bursts in shards, snow falls.
	YUKINA = kit({ element = "ice", accent = "DFF6FF", shot = "shard", swing = "fanArcs", hit = "iceShards", dash = "frost",
		ambient = { motion = "fall", colors = { "FFFFFF", "9FE6FF" }, rate = 3, size = 0.25 },
		trail = { "DFF6FF", "energy" } }),
	-- VENOM 毒: poison: fang swipes dripping green, a splash and drops on the hit, bubbles.
	VENOM = kit({ element = "poison", accent = "7CFF4A", shot = "cloud", swing = "fangSwipe", hit = "toxicSplash", dash = "venomTrail",
		ambient = { motion = "rise", colors = { "7CFF4A", "2A5A10" }, rate = 3, size = 0.3 },
		trail = { "7CFF4A", "energy" } }),
	-- GORAN 剛: the titan: no light show, weight: stomps, the ground ringing, dust.
	GORAN = kit({ element = "titan", accent = "C9BFC0", shot = "ball", swing = "titanStomp", hit = "quake", dash = "stomp",
		ambient = { motion = "drift", colors = { "C9BFC0", "energy" }, rate = 1, size = 0.5 },
		trail = { "energy", "C9BFC0" } }),
	-- ASTER 星: gravity: little rings round the fist, the hit pulls inward, stars orbit him.
	ASTER = kit({ element = "gravity", accent = "E8E0FF", shot = "well", swing = "gravityRings", hit = "implode", dash = "float",
		ambient = { motion = "orbit", colors = { "E8E0FF", "energy" }, rate = 2, size = 0.2 },
		trail = { "energy", "E8E0FF" } }),
	-- HIBIKI 響: sound: ripples ahead of each blow, a burst of rings on the hit, the beat.
	HIBIKI = kit({ element = "sound", accent = "6FE0FF", shot = "pulse", swing = "soundRipples", hit = "soundBurst", dash = "beat",
		ambient = { motion = "drift", colors = { "energy", "6FE0FF" }, rate = 2, size = 0.25 },
		trail = { "energy", "6FE0FF" } }),
	-- KAZAN 鎖: steel and chains: three claw arcs, claw marks and steel sparks on the hit.
	KAZAN = kit({ element = "steel", accent = "E0E0E8", shot = "ball", swing = "tripleClaw", hit = "clawMarks", dash = "chain",
		ambient = { motion = "flicker", colors = { "FFB04A", "E0E0E8" }, rate = 1.5, size = 0.2 },
		trail = { "E0E0E8", "energy" } }),
	-- KUREN 血: blood: crimson crescents, a bloom of drops on the hit, a red mist.
	KUREN = kit({ element = "blood", accent = "8A0A1A", shot = "lance", swing = "bloodCrescent", hit = "bloodBloom", dash = "mist",
		ambient = { motion = "fall", colors = { "8A0A1A", "energy" }, rate = 2, size = 0.25 },
		trail = { "energy", "8A0A1A" } }),
	-- SYLVA 森: nature: vine whips, leaves bursting, petals in her wake.
	SYLVA = kit({ element = "nature", accent = "8AD84A", shot = "trap", swing = "vineWhip", hit = "leafBurst", dash = "petals",
		ambient = { motion = "fall", colors = { "8AD84A", "energy" }, rate = 2, size = 0.3 },
		trail = { "8AD84A", "energy" } }),
	-- ELIAN 癒: light: warm palms, a halo on the hit, a soft glow.
	ELIAN = kit({ element = "light", accent = "FFE9A0", shot = "ball", swing = "lightPalm", hit = "halo", dash = "glow",
		ambient = { motion = "rise", colors = { "FFE9A0", "FFFFFF" }, rate = 2, size = 0.25 },
		trail = { "FFE9A0", "energy" } }),
	-- NOVA 機: machines: piston punches, square pixels and a scan on the hit, thrusters.
	NOVA = kit({ element = "tech", accent = "6FE0FF", shot = "bullet", swing = "pistonPunch", hit = "glitch", dash = "thrusters",
		ambient = { motion = "flicker", colors = { "energy", "6FE0FF" }, rate = 2, size = 0.2 },
		trail = { "energy", "6FE0FF" } }),
	-- KUROEN 蝕: the eclipse: red ki with a black core, a small black sun on the hit.
	KUROEN = kit({ element = "eclipse", accent = "0A0204", shot = "eclipse", swing = "eclipseStreak", hit = "eclipseBurst", dash = "redShade",
		ambient = { motion = "rise", colors = { "E0102E", "0A0204" }, rate = 2, size = 0.35 },
		trail = { "energy", "0A0204" } }),
	-- Bosses.
	ASURA = kit({ element = "asura", accent = "FFD23F", shot = "ball", swing = "fourArms", hit = "goldenFists", dash = "goldShade",
		ambient = { motion = "rise", colors = { "FFD23F", "energy" }, rate = 3, size = 0.4 },
		trail = { "FFD23F", "energy" } }),
	["KUROEN SHIN"] = kit({ element = "divine", accent = "FFFFFF", shot = "ball", swing = "divineStreak", hit = "divineBurst", dash = "goldShade",
		ambient = { motion = "rise", colors = { "FFFFFF", "FFD23F" }, rate = 4, size = 0.35 },
		trail = { "FFFFFF", "FFD23F" } }),
}

-- The identity of a kit (KAI's for an unknown one).
function KitFX.of(kitName)
	return KitFX.KITS[kitName] or KitFX.KITS.KAI
end

-- A colour entry: "energy" -> the style's ki colour, else the hex itself.
function KitFX.color(entry, energyHex)
	if entry == "energy" then return energyHex end
	return entry
end

-- How many motes per second (none in reduced mode: the effects option, phones).
function KitFX.ambientRate(kitName, reduced)
	if reduced then return 0 end
	return KitFX.of(kitName).ambient.rate
end

return KitFX
