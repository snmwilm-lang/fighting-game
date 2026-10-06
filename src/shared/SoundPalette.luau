--[[
	The sound palette (pure data, no Roblox API, no require): which built-in client sound,
	how loud, how fast, how long and through which bus, for every action and every kit's
	material. Played by src/client/SoundController.luau; checked by tests/Kits.test.luau.

	CLIENT_SOUNDS is the full list of the sounds shipped in the Roblox client's content folder
	(rbxasset://sounds/..., from the client manifest): nothing else may be used, and no asset
	id is ever invented.
]]
local Palette = {}

Palette.CLIENT_SOUNDS = table.freeze({
	"action_falling.ogg", "action_footsteps_plastic.mp3", "action_get_up.mp3", "action_jump.mp3",
	"action_jump_land.mp3", "action_swim.mp3", "impact_explosion_03.mp3", "impact_water.mp3",
	"oof.ogg", "ouch.ogg", "volume_slider.ogg",
})

-- WILHEM'S UPLOADS (Creator Hub, validated on 6 October 2026): his own royalty-free sounds,
-- by what they are for. A FILES entry may name one of these groups: every play picks one of
-- its takes at random (the same blow never sounds twice the same). Ids given by Wilhem only.
Palette.UPLOADS = table.freeze({
	punch = { "rbxassetid://129256026624539", "rbxassetid://111865355769098", "rbxassetid://139409887608714",
		"rbxassetid://73380268944822" }, -- a fist landing
	whoosh = { "rbxassetid://76049977681468", "rbxassetid://109621774819971" }, -- a blow cutting the air (a miss)
	ko = { "rbxassetid://72478322633124", "rbxassetid://74488688244165", "rbxassetid://122227946848688" },
	guard = { "rbxassetid://79524546381696", "rbxassetid://119049351358648", "rbxassetid://105289989027230" },
	dodge = { "rbxassetid://86507046672081", "rbxassetid://134668366374910" }, -- dash, evade
	barrage = { "rbxassetid://117966984445030" }, -- a rush of blows
	ult = { "rbxassetid://98053537019677", "rbxassetid://126278834963397", "rbxassetid://118955257919955",
		"rbxassetid://73573430517284" },
	slash = { "rbxassetid://76694449914502", "rbxassetid://89042507065653", "rbxassetid://134739371295430" }, -- steel through a body
	clash = { "rbxassetid://88832606101415" }, -- steel on steel
})

local FILES = {
	thud = "rbxasset://sounds/action_jump_land.mp3", -- a blow on a body, a landing
	jump = "rbxasset://sounds/action_jump.mp3",
	getUp = "rbxasset://sounds/action_get_up.mp3",
	steps = "rbxasset://sounds/action_footsteps_plastic.mp3",
	wind = "rbxasset://sounds/action_falling.ogg", -- cut short: every whoosh
	boom = "rbxasset://sounds/impact_explosion_03.mp3", -- big impacts, stone, ultimates
	splash = "rbxasset://sounds/impact_water.mp3", -- SHIN's water blade
	tick = "rbxasset://sounds/volume_slider.ogg", -- dry clicks: guard, prompts, blade tip
}
for group, takes in Palette.UPLOADS do FILES[group] = takes end

-- Coloured buses (child sound groups with engine effects); a sound without a bus is dry.
local BUSES = {
	crunch = { DistortionSoundEffect = { Level = 0.12 } }, -- RYUKEN's fists, guard breaks (barely: it grates)
	echo = { EchoSoundEffect = { Delay = 0.11, Feedback = 0.25, WetLevel = -8 } }, -- DAICHA's shadow
	hall = { ReverbSoundEffect = { DecayTime = 1.4, WetLevel = -6 } }, -- ultimates, K.O.
	thin = { EqualizerSoundEffect = { LowGain = -24, MidGain = -6, HighGain = 4 } }, -- blades cutting the air
}

-- A sound: { file, volume, speed, length (seconds, then a short fade; nil = whole), bus }.
-- Each kit's material: the whoosh of its swings and the sound of its hits.
local MATERIALS = {
	KAI = { -- fists of ki
		swing = { { "whoosh", 0.35, 1.12 } },
		heavySwing = { { "whoosh", 0.47, 0.97 } },
		hit = { { "punch", 0.62, 0.82 } },
		heavyHit = { { "punch", 0.82, 0.72 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
		projectile = { { "wind", 0.47, 0.9, 0.35 }, { "boom", 0.17, 2, 0.25 } }, -- ki blast
	},
	TARO = { -- leather gloves: a slap, the body shot
		swing = { { "whoosh", 0.31, 1.20 } },
		heavySwing = { { "whoosh", 0.43, 1.05 } },
		hit = { { "punch", 0.62, 0.84 } },
		heavyHit = { { "punch", 0.82, 0.74 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
	},
	ZEPHYR = { -- kicks that cut the wind
		swing = { { "whoosh", 0.43, 1.05, nil, "thin" } },
		heavySwing = { { "whoosh", 0.56, 0.95, nil, "thin" } },
		hit = { { "punch", 0.62, 0.86 }, { "wind", 0.2, 1.8, 0.12 } },
		heavyHit = { { "punch", 0.82, 0.76 }, { "boom", 0.16, 1.7, 0.18, "hall" }, { "wind", 0.22, 1.2, 0.3 } },
		projectile = { { "wind", 0.51, 1.3, 0.4, "thin" } }, -- blade of wind
	},
	AKEMI = { -- the shadow's knife hand: thin, fast, dry
		swing = { { "whoosh", 0.35, 1.25, nil, "thin" } },
		heavySwing = { { "whoosh", 0.47, 1.10, nil, "thin" } },
		hit = { { "punch", 0.62, 0.88 } },
		heavyHit = { { "punch", 0.82, 0.77 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
		projectile = { { "wind", 0.38, 2.3, 0.12, "thin" } }, -- kunai
	},
	RYUKEN = { -- crushing fists: heavier, distorted
		swing = { { "whoosh", 0.39, 1.02 } },
		heavySwing = { { "whoosh", 0.56, 0.91 } },
		hit = { { "punch", 0.62, 0.90 } },
		heavyHit = { { "punch", 0.82, 0.79 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
		projectile = { { "boom", 0.42, 1.2, 0.5, "crunch" }, { "thud", 0.51, 0.6 } }, -- seismic strike
	},
	SHIN = { -- the water blade: a clean cut, the splash of the current
		swing = { { "whoosh", 0.43, 1.20, nil, "thin" } },
		heavySwing = { { "whoosh", 0.56, 1.07, nil, "thin" } },
		hit = { { "slash", 0.62, 0.92 }, { "splash", 0.2, 1.7, 0.3 } },
		heavyHit = { { "slash", 0.8, 0.81 }, { "punch", 0.35, 0.64, 0.2 }, { "boom", 0.16, 1.7, 0.18, "hall" }, { "splash", 0.22, 1.2, 0.5 } },
		projectile = { { "splash", 0.51, 1, 0.6 } }, -- current
	},
	DAICHA = { -- the inverted shadow: low, hollow, echoing
		swing = { { "whoosh", 0.43, 0.89, nil, "echo" } },
		heavySwing = { { "whoosh", 0.56, 0.84, nil, "echo" } },
		hit = { { "punch", 0.62, 0.94, nil, "echo" } },
		heavyHit = { { "punch", 0.82, 0.83 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
		projectile = { { "wind", 0.51, 0.45, 0.6, "echo" } }, -- sphere
	},
	HIBECARES = { -- stone: slow, enormous
		swing = { { "whoosh", 0.47, 0.85 } },
		heavySwing = { { "whoosh", 0.60, 0.81 } },
		hit = { { "punch", 0.62, 0.96 }, { "boom", 0.2, 1.4, 0.3 } },
		heavyHit = { { "punch", 0.82, 0.84 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
		steps = 0.95, -- heavy feet
	},
	-- ASURA and Wilhem's third sheet.
	ASURA = { -- four fists of gold: KAI's blows, deeper, in the hall
		swing = { { "whoosh", 0.43, 1.00 } },
		heavySwing = { { "whoosh", 0.60, 0.90 } },
		hit = { { "punch", 0.62, 0.98, nil, "hall" } },
		heavyHit = { { "punch", 0.82, 0.86 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
		projectile = { { "boom", 0.34, 1.4, 0.4, "hall" } },
	},
	RAIJIN = { -- the spear and its lightning: a crackle
		swing = { { "whoosh", 0.43, 1.15, nil, "thin" } },
		heavySwing = { { "whoosh", 0.56, 1.02, nil, "thin" } },
		hit = { { "slash", 0.62, 1.00 } },
		heavyHit = { { "slash", 0.8, 0.88 }, { "punch", 0.35, 0.70, 0.2 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
		projectile = { { "boom", 0.38, 2.4, 0.3, "crunch" }, { "wind", 0.34, 2, 0.2, "thin" } },
	},
	YUKINA = { -- fans of ice: a crystal tinkle
		swing = { { "whoosh", 0.39, 1.17, nil, "thin" } },
		heavySwing = { { "whoosh", 0.52, 1.07, nil, "thin" } },
		hit = { { "slash", 0.62, 1.02 } },
		heavyHit = { { "slash", 0.8, 0.90 }, { "punch", 0.35, 0.71, 0.2 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
		projectile = { { "wind", 0.42, 2.6, 0.3, "thin" } },
	},
	VENOM = { -- claws: a dry scrape
		swing = { { "whoosh", 0.39, 1.23, nil, "thin" } },
		heavySwing = { { "whoosh", 0.52, 1.10, nil, "thin" } },
		hit = { { "slash", 0.62, 1.04 } },
		heavyHit = { { "slash", 0.8, 0.92 }, { "punch", 0.35, 0.73, 0.2 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
		projectile = { { "wind", 0.47, 0.4, 0.7, "echo" } }, -- the toxic cloud
	},
	GORAN = { -- slams on the mat
		swing = { { "whoosh", 0.47, 0.88 } },
		heavySwing = { { "whoosh", 0.60, 0.82 } },
		hit = { { "punch", 0.62, 1.06 } },
		heavyHit = { { "punch", 0.82, 0.93 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
		projectile = { { "boom", 0.42, 0.55, 0.55, "crunch" }, { "wind", 0.38, 0.5, 0.4 } }, -- the shockwave rolling on the mat
		steps = 0.9,
	},
	ASTER = { -- gravity: a hollow boom
		swing = { { "whoosh", 0.43, 0.86, nil, "echo" } },
		heavySwing = { { "whoosh", 0.56, 0.82, nil, "echo" } },
		hit = { { "punch", 0.62, 1.08 }, { "boom", 0.2, 2.4, 0.25, "echo" } },
		heavyHit = { { "punch", 0.82, 0.95 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
		projectile = { { "wind", 0.51, 0.35, 0.6, "hall" } },
	},
	HIBIKI = { -- beats: clicks in the hall
		swing = { { "whoosh", 0.35, 1.25 } },
		heavySwing = { { "whoosh", 0.47, 1.12 } },
		hit = { { "punch", 0.62, 1.10 } },
		heavyHit = { { "punch", 0.82, 0.97 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
		projectile = { { "boom", 0.38, 2.6, 0.25, "hall" } },
	},
	KUROEN = { -- the eclipse: gauntlets on bone, a dark boom in the hall under the big ones
		swing = { { "whoosh", 0.39, 1.09 } },
		heavySwing = { { "whoosh", 0.56, 0.94, nil, "echo" } },
		hit = { { "punch", 0.62, 1.12, nil, "hall" } },
		heavyHit = { { "punch", 0.82, 0.99 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
	},
	KAZAN = { -- steel claws: a thin slicing whoosh, blades through the body
		swing = { { "whoosh", 0.43, 1.23, nil, "thin" } },
		heavySwing = { { "whoosh", 0.56, 1.05, nil, "thin" } },
		hit = { { "slash", 0.62, 1.14 } },
		heavyHit = { { "slash", 0.8, 1.00 }, { "punch", 0.35, 0.80, 0.2 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
	},
	KUREN = { -- blood: a wet, hollow hit
		swing = { { "whoosh", 0.39, 1.10 } },
		heavySwing = { { "whoosh", 0.52, 1.00 } },
		hit = { { "punch", 0.62, 1.16 }, { "splash", 0.2, 0.6, 0.3, "echo" } },
		heavyHit = { { "punch", 0.82, 1.02 }, { "boom", 0.16, 1.7, 0.18, "hall" }, { "splash", 0.22, 0.5, 0.5, "echo" } },
		projectile = { { "splash", 0.51, 0.5, 0.4, "thin" } },
	},
	SYLVA = { -- wood and leaves
		swing = { { "whoosh", 0.39, 1.07, nil, "thin" } },
		heavySwing = { { "whoosh", 0.52, 0.97, nil, "thin" } },
		hit = { { "punch", 0.62, 1.18, nil, "thin" } },
		heavyHit = { { "punch", 0.82, 1.04 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
		projectile = { { "thud", 0.42, 0.9, nil, "echo" } }, -- the roots
	},
	ELIAN = { -- light: a bright chime in the hall
		swing = { { "whoosh", 0.35, 1.10 } },
		heavySwing = { { "whoosh", 0.47, 1.00 } },
		hit = { { "punch", 0.62, 1.20 } },
		heavyHit = { { "punch", 0.82, 1.06 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
		projectile = { { "wind", 0.42, 1.8, 0.3, "hall" } },
	},
	NOVA = { -- metal gauntlets, the drones' shots
		swing = { { "whoosh", 0.39, 1.17 } },
		heavySwing = { { "whoosh", 0.52, 1.05 } },
		hit = { { "punch", 0.62, 1.22 } },
		heavyHit = { { "punch", 0.82, 1.07 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
		projectile = { { "wind", 0.26, 2.4, 0.12 } },
	},
}

-- One sound per action, the same for every fighter.
local ACTIONS = {
	Block = { { "guard", 0.55, 1 } }, -- a blow taken on the guard
	BlockSteel = { { "clash", 0.6, 1.05 } }, -- on a blade's guard: steel on steel (SHIN, RAIJIN, KAZAN, YUKINA)
	GuardBreak = { { "boom", 0.51, 1.5, 0.4, "crunch" }, { "thud", 0.59, 0.6 } },
	Clash = { { "clash", 0.7, 1 }, { "boom", 0.2, 1.8, 0.3 } },
	Parry = { { "thud", 0.42, 1.4 } }, -- TARO's glove knocks it aside
	Wall = { { "boom", 0.51, 0.85, 0.5 }, { "thud", 0.59, 0.6 } }, -- HIBECARES's MUR DE PIERRE
	Evade = { { "dodge", 0.5, 1, nil, "echo" } }, -- AKEMI's VOILE D'OMBRE
	Slip = { { "dodge", 0.42, 1.2, 0.3 } }, -- TARO's weave
	Blink = { { "dodge", 0.5, 0.8, nil, "echo" } }, -- DAICHA through the opponent
	Stance = { { "thud", 0.42, 1.6 }, { "thud", 0.34, 1.7 } }, -- gloves knocked together
	SuperFlash = { { "ult", 0.8, 1, nil, "hall" } },
	Skill = { { "wind", 0.38, 1, 0.3 } },
	Prompt = { { "tick", 0.59, 1 } },
	Perfect = { { "tick", 0.68, 1.6 }, { "tick", 0.42, 2 } },
	Graded = { { "tick", 0.59, 1.25 } },
	SuperJump = { { "jump", 0.51, 0.85 }, { "wind", 0.34, 0.8, 0.4 } },
	Bounce = { { "thud", 0.64, 0.75 } },
	KO = { { "ko", 0.9, 1 }, { "ult", 0.4, 0.85, nil, "hall" } },
	Cinematic = { { "ult", 0.3, 1.1, 0.8, "hall" } }, -- under every blow of an ultimate
	Tip = { { "thud", 0.35, 2.3 } }, -- SHIN's PRÉCISION: a bright knock on top of the hit
	Knockdown = { { "thud", 0.77, 0.55 } },
	GetUp = { { "getUp", 0.42, 1.1 } },
	Jump = { { "jump", 0.38, 1.05 } },
	Land = { { "thud", 0.34, 1.2 } },
	Dash = { { "dodge", 0.45, 1.05 } },
	Barrage = { { "barrage", 0.7, 1 } }, -- a rush of blows (each kit's KiFlurry) as it starts
	-- The third sheet's passives.
	PassiveReady = { { "boom", 0.2, 1.8, 0.25, "hall" } }, -- SURCHARGE, TEMPO ready
	Chilled = { { "thud", 0.34, 2.47, nil, "echo" } }, -- YUKINA's frost takes
	Poison = { { "wind", 0.17, 0.5, 0.2, "echo" } }, -- a tick of poison
	Armor = { { "thud", 0.68, 0.5 } }, -- GORAN shrugs a blow off
	Heal = { { "thud", 0.34, 2.29, nil, "hall" } }, -- ELIAN's care
	Reflect = { { "boom", 0.21, 2.4, 0.2 } }, -- MIROIR DE GLACE
	Drone = { { "wind", 0.26, 2.2, 0.15 } }, -- NOVA's sentinel takes off
	Shackled = { { "thud", 0.41, 1.46, nil, "crunch" } }, -- KAZAN's chains bite
	Domination = { { "boom", 0.38, 1.5, 0.35, "hall" } }, -- KUROEN's DOMINATION rises or is spent
	-- ZEPHYR, KAI, AKEMI: their own mechanics (small, never over the blows).
	Rhythm = { { "clash", 0.28, 2.2 } }, -- PERFECT RHYTHM: a bright ring on top of the kick
	RhythmFinisher = { { "clash", 0.42, 1.7 }, { "boom", 0.18, 2.1, 0.2 } }, -- PERFECT FINISHER
	ClashStep = { { "dodge", 0.55, 1.3, nil, "echo" } }, -- the blow whistles past ZEPHYR
	Resolve = { { "guard", 0.6, 0.75 }, { "thud", 0.5, 0.6 } }, -- KAI braces under the blow
	Feint = { { "dodge", 0.3, 1.5 } }, -- KAI stops his string
	Flow = { { "wind", 0.25, 1.6, 0.2, "echo" } }, -- AKEMI's INSTINCT FLOW armed
	-- The fight's big moments.
	Counter = { { "boom", 0.3, 2.2, 0.2 } }, -- COUNTER HIT: a sharp crack on top
	Revive = { { "boom", 0.85, 0.45, 1.6, "hall" }, { "thud", 0.85, 0.35 }, { "wind", 0.51, 0.4, 1.2, "echo" } }, -- ASURA rises
	RoundStart = { { "thud", 0.59, 0.6, nil, "hall" } }, -- FIGHT!
	-- The menus (buttons).
	UiHover = { { "tick", 0.1, 2.4, 0.04 } },
	UiClick = { { "tick", 0.26, 1.6, 0.06 }, { "thud", 0.15, 2.4 } },
}

-- Wilhem's own sounds, when he has some: an uploaded audio ("rbxassetid://...") per action
-- (ACTIONS key) or per kit material ("KAI.hit", "KAZAN.heavySwing"...). A key given here
-- replaces the built-in sound. Empty: no asset id is ever invented.
Palette.CUSTOM = {}

Palette.FILES, Palette.BUSES, Palette.MATERIALS, Palette.ACTIONS = FILES, BUSES, MATERIALS, ACTIONS
return Palette
