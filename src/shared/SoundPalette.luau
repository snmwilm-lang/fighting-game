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

-- Coloured buses (child sound groups with engine effects); a sound without a bus is dry.
local BUSES = {
	crunch = { DistortionSoundEffect = { Level = 0.5 } }, -- RYUKEN's fists, guard breaks
	echo = { EchoSoundEffect = { Delay = 0.11, Feedback = 0.35, WetLevel = -4 } }, -- DAICHA's shadow
	hall = { ReverbSoundEffect = { DecayTime = 1.6, WetLevel = -2 } }, -- ultimates, K.O.
	thin = { EqualizerSoundEffect = { LowGain = -24, MidGain = -6, HighGain = 4 } }, -- blades cutting the air
}

-- A sound: { file, volume, speed, length (seconds, then a short fade; nil = whole), bus }.
-- Each kit's material: the whoosh of its swings and the sound of its hits.
local MATERIALS = {
	KAI = { -- fists of ki
		swing = { { "wind", 0.35, 1.7, 0.16 } },
		heavySwing = { { "wind", 0.5, 1.1, 0.3 } },
		hit = { { "thud", 0.55, 1.5 } },
		heavyHit = { { "thud", 0.9, 0.8 }, { "boom", 0.25, 1.6, 0.35 } },
		projectile = { { "wind", 0.55, 0.9, 0.35 }, { "boom", 0.2, 2, 0.25 } }, -- ki blast
	},
	TARO = { -- leather gloves: a slap, the body shot
		swing = { { "wind", 0.3, 2, 0.12 } },
		heavySwing = { { "wind", 0.45, 1.4, 0.22 } },
		hit = { { "thud", 0.6, 1.9 }, { "thud", 0.3, 1.2 } },
		heavyHit = { { "thud", 0.95, 1 }, { "thud", 0.5, 0.7 } },
	},
	ZEPHYR = { -- kicks that cut the wind
		swing = { { "wind", 0.45, 1.4, 0.24, "thin" } },
		heavySwing = { { "wind", 0.6, 1, 0.4, "thin" } },
		hit = { { "thud", 0.5, 1.6 }, { "wind", 0.25, 1.8, 0.12 } },
		heavyHit = { { "thud", 0.85, 0.95 }, { "wind", 0.4, 1.2, 0.3 } },
		projectile = { { "wind", 0.6, 1.3, 0.4, "thin" } }, -- blade of wind
	},
	AKEMI = { -- the shadow's knife hand: thin, fast, dry
		swing = { { "wind", 0.35, 2.2, 0.1, "thin" } },
		heavySwing = { { "wind", 0.5, 1.6, 0.18, "thin" } },
		hit = { { "tick", 0.5, 0.7 }, { "thud", 0.35, 2 } },
		heavyHit = { { "tick", 0.7, 0.5 }, { "thud", 0.6, 1.3 } },
		projectile = { { "wind", 0.45, 2.3, 0.12, "thin" } }, -- kunai
	},
	RYUKEN = { -- crushing fists: heavier, distorted
		swing = { { "wind", 0.4, 1.3, 0.18 } },
		heavySwing = { { "wind", 0.6, 0.85, 0.32 } },
		hit = { { "thud", 0.75, 1.15, nil, "crunch" } },
		heavyHit = { { "thud", 1, 0.7, nil, "crunch" }, { "boom", 0.4, 1.3, 0.5 } },
		projectile = { { "boom", 0.5, 1.2, 0.5, "crunch" }, { "thud", 0.6, 0.6 } }, -- seismic strike
	},
	SHIN = { -- the water blade: a clean cut, the splash of the current
		swing = { { "wind", 0.45, 2, 0.14, "thin" } },
		heavySwing = { { "wind", 0.6, 1.5, 0.24, "thin" } },
		hit = { { "splash", 0.45, 1.7, 0.3 }, { "tick", 0.35, 1.2 } },
		heavyHit = { { "splash", 0.75, 1.2, 0.5 }, { "thud", 0.4, 1.4 } },
		projectile = { { "splash", 0.6, 1, 0.6 } }, -- current
	},
	DAICHA = { -- the inverted shadow: low, hollow, echoing
		swing = { { "wind", 0.45, 0.75, 0.24, "echo" } },
		heavySwing = { { "wind", 0.6, 0.55, 0.4, "echo" } },
		hit = { { "thud", 0.55, 1, nil, "echo" } },
		heavyHit = { { "thud", 0.85, 0.65, nil, "echo" }, { "boom", 0.3, 0.8, 0.4, "echo" } },
		projectile = { { "wind", 0.6, 0.45, 0.6, "echo" } }, -- sphere
	},
	HIBECARES = { -- stone: slow, enormous
		swing = { { "wind", 0.5, 0.6, 0.3 } },
		heavySwing = { { "wind", 0.7, 0.45, 0.5 } },
		hit = { { "thud", 0.85, 0.7 }, { "boom", 0.25, 1.4, 0.3 } },
		heavyHit = { { "boom", 0.7, 0.75, 0.8 }, { "thud", 1, 0.5 } },
		steps = 0.95, -- heavy feet
	},
	-- ASURA and Wilhem's third sheet.
	ASURA = { -- four fists of gold: KAI's blows, deeper, in the hall
		swing = { { "wind", 0.45, 1.2, 0.2 } },
		heavySwing = { { "wind", 0.65, 0.8, 0.36 } },
		hit = { { "thud", 0.8, 1.05, nil, "hall" } },
		heavyHit = { { "thud", 1, 0.65, nil, "hall" }, { "boom", 0.4, 1.1, 0.5, "hall" } },
		projectile = { { "boom", 0.4, 1.4, 0.4, "hall" } },
	},
	RAIJIN = { -- the spear and its lightning: a crackle
		swing = { { "wind", 0.45, 1.8, 0.16, "thin" } },
		heavySwing = { { "wind", 0.6, 1.3, 0.28, "thin" } },
		hit = { { "tick", 0.6, 2.4, nil, "crunch" }, { "thud", 0.4, 1.6 } },
		heavyHit = { { "boom", 0.45, 2.2, 0.3, "crunch" }, { "thud", 0.7, 1 } },
		projectile = { { "boom", 0.45, 2.4, 0.3, "crunch" }, { "wind", 0.4, 2, 0.2, "thin" } },
	},
	YUKINA = { -- fans of ice: a crystal tinkle
		swing = { { "wind", 0.4, 1.9, 0.18, "thin" } },
		heavySwing = { { "wind", 0.55, 1.5, 0.3, "thin" } },
		hit = { { "tick", 0.55, 2.8, nil, "echo" }, { "thud", 0.3, 1.8 } },
		heavyHit = { { "tick", 0.7, 2.2, nil, "echo" }, { "thud", 0.6, 1.2 } },
		projectile = { { "wind", 0.5, 2.6, 0.3, "thin" }, { "tick", 0.4, 2.6 } },
	},
	VENOM = { -- claws: a dry scrape
		swing = { { "wind", 0.4, 2.1, 0.12, "thin" } },
		heavySwing = { { "wind", 0.55, 1.6, 0.22, "thin" } },
		hit = { { "tick", 0.5, 1.3, nil, "thin" }, { "thud", 0.35, 1.7 } },
		heavyHit = { { "tick", 0.7, 1, nil, "thin" }, { "thud", 0.65, 1.1 } },
		projectile = { { "wind", 0.55, 0.4, 0.7, "echo" } }, -- the toxic cloud
	},
	GORAN = { -- slams on the mat
		swing = { { "wind", 0.5, 0.7, 0.3 } },
		heavySwing = { { "wind", 0.7, 0.5, 0.45 } },
		hit = { { "thud", 0.95, 0.6, nil, "crunch" } },
		heavyHit = { { "boom", 0.6, 0.9, 0.6, "crunch" }, { "thud", 1, 0.45 } },
		projectile = { { "boom", 0.5, 0.55, 0.55, "crunch" }, { "wind", 0.45, 0.5, 0.4 } }, -- the shockwave rolling on the mat
		steps = 0.9,
	},
	ASTER = { -- gravity: a hollow boom
		swing = { { "wind", 0.45, 0.65, 0.3, "echo" } },
		heavySwing = { { "wind", 0.6, 0.5, 0.45, "echo" } },
		hit = { { "boom", 0.35, 2.4, 0.25, "echo" }, { "thud", 0.4, 1.3 } },
		heavyHit = { { "boom", 0.6, 1.6, 0.5, "echo" }, { "thud", 0.7, 0.8 } },
		projectile = { { "wind", 0.6, 0.35, 0.6, "hall" } },
	},
	HIBIKI = { -- beats: clicks in the hall
		swing = { { "wind", 0.35, 2.2, 0.1 } },
		heavySwing = { { "wind", 0.5, 1.7, 0.18 } },
		hit = { { "tick", 0.65, 1, nil, "hall" }, { "thud", 0.4, 2 } },
		heavyHit = { { "boom", 0.4, 2.6, 0.25, "hall" }, { "tick", 0.6, 0.8 } },
		projectile = { { "boom", 0.45, 2.6, 0.25, "hall" }, { "tick", 0.5, 1.2 } },
	},
	KUROEN = { -- the eclipse: gauntlets on bone, a dark boom in the hall under the big ones
		swing = { { "wind", 0.4, 1.55, 0.14 } },
		heavySwing = { { "wind", 0.6, 0.95, 0.28, "echo" } },
		hit = { { "thud", 0.7, 1.35, nil, "hall" }, { "tick", 0.25, 0.9 } },
		heavyHit = { { "thud", 1, 0.75, nil, "hall" }, { "boom", 0.35, 1.25, 0.4, "echo" } },
	},
	KAZAN = { -- steel claws: a thin slicing whoosh, blades through the body
		swing = { { "wind", 0.45, 2.1, 0.12, "thin" } },
		heavySwing = { { "wind", 0.6, 1.4, 0.24, "thin" } },
		hit = { { "tick", 0.55, 0.85, nil, "thin" }, { "thud", 0.5, 1.7 } },
		heavyHit = { { "tick", 0.8, 0.6, nil, "crunch" }, { "thud", 0.85, 0.9 } },
	},
	KUREN = { -- blood: a wet, hollow hit
		swing = { { "wind", 0.4, 1.6, 0.18 } },
		heavySwing = { { "wind", 0.55, 1.2, 0.3 } },
		hit = { { "splash", 0.5, 0.6, 0.3, "echo" }, { "thud", 0.4, 1.5 } },
		heavyHit = { { "splash", 0.75, 0.5, 0.5, "echo" }, { "thud", 0.7, 1 } },
		projectile = { { "splash", 0.6, 0.5, 0.4, "thin" } },
	},
	SYLVA = { -- wood and leaves
		swing = { { "wind", 0.4, 1.5, 0.2, "thin" } },
		heavySwing = { { "wind", 0.55, 1.1, 0.32, "thin" } },
		hit = { { "thud", 0.5, 1.8, nil, "thin" }, { "tick", 0.3, 1.4 } },
		heavyHit = { { "thud", 0.8, 1.2, nil, "thin" }, { "thud", 0.5, 0.8 } },
		projectile = { { "thud", 0.5, 0.9, nil, "echo" } }, -- the roots
	},
	ELIAN = { -- light: a bright chime in the hall
		swing = { { "wind", 0.35, 1.6, 0.2 } },
		heavySwing = { { "wind", 0.5, 1.2, 0.32 } },
		hit = { { "tick", 0.5, 2, nil, "hall" }, { "thud", 0.35, 1.6 } },
		heavyHit = { { "tick", 0.7, 1.6, nil, "hall" }, { "thud", 0.6, 1.1 } },
		projectile = { { "wind", 0.5, 1.8, 0.3, "hall" } },
	},
	NOVA = { -- metal gauntlets, the drones' shots
		swing = { { "wind", 0.4, 1.9, 0.14 } },
		heavySwing = { { "wind", 0.55, 1.4, 0.24 } },
		hit = { { "thud", 0.55, 2.3, nil, "crunch" }, { "tick", 0.35, 1.6 } },
		heavyHit = { { "thud", 0.85, 1.4, nil, "crunch" }, { "boom", 0.3, 2, 0.25 } },
		projectile = { { "tick", 0.6, 2.6, nil, "crunch" }, { "wind", 0.3, 2.4, 0.12 } },
	},
}

-- One sound per action, the same for every fighter.
local ACTIONS = {
	Block = { { "thud", 0.4, 2.1 }, { "tick", 0.3, 0.6 } }, -- a dry guard
	GuardBreak = { { "boom", 0.6, 1.5, 0.4, "crunch" }, { "thud", 0.7, 0.6 } },
	Clash = { { "tick", 0.6, 0.45 }, { "boom", 0.35, 1.8, 0.3 } },
	Parry = { { "tick", 0.7, 1.5 }, { "thud", 0.5, 1.4 } }, -- TARO's glove knocks it aside
	Wall = { { "boom", 0.6, 0.85, 0.5 }, { "thud", 0.7, 0.6 } }, -- HIBECARES's MUR DE PIERRE
	Evade = { { "wind", 0.5, 1.5, 0.2, "echo" } }, -- AKEMI's VOILE D'OMBRE
	Slip = { { "wind", 0.45, 2.1, 0.12 } }, -- TARO's weave
	Blink = { { "wind", 0.6, 0.6, 0.3, "echo" }, { "tick", 0.3, 0.4 } }, -- DAICHA through the opponent
	Stance = { { "thud", 0.5, 1.6 }, { "thud", 0.4, 1.7 } }, -- gloves knocked together
	SuperFlash = { { "boom", 0.7, 0.7, 1.2, "hall" }, { "wind", 0.5, 0.5, 0.6 } },
	Skill = { { "wind", 0.45, 1, 0.3 }, { "tick", 0.3, 0.9 } },
	Prompt = { { "tick", 0.7, 1 } },
	Perfect = { { "tick", 0.8, 1.6 }, { "tick", 0.5, 2 } },
	Graded = { { "tick", 0.7, 1.25 } },
	SuperJump = { { "jump", 0.6, 0.85 }, { "wind", 0.4, 0.8, 0.4 } },
	Bounce = { { "thud", 0.75, 0.75 } },
	KO = { { "boom", 0.9, 0.8, 1.5, "hall" }, { "thud", 1, 0.5 } },
	Cinematic = { { "boom", 0.3, 1.1, 0.6, "hall" } }, -- under every blow of an ultimate
	Tip = { { "tick", 0.5, 1.8 } }, -- SHIN's PRÉCISION: a bright click on top of the hit
	Knockdown = { { "thud", 0.9, 0.55 } },
	GetUp = { { "getUp", 0.5, 1.1 } },
	Jump = { { "jump", 0.45, 1.05 } },
	Land = { { "thud", 0.4, 1.2 } },
	Dash = { { "wind", 0.4, 1.2, 0.2 } },
	-- The third sheet's passives.
	PassiveReady = { { "tick", 0.6, 1.4 }, { "tick", 0.4, 1.9 } }, -- SURCHARGE, TEMPO ready
	Chilled = { { "tick", 0.5, 2.6, nil, "echo" } }, -- YUKINA's frost takes
	Poison = { { "wind", 0.2, 0.5, 0.2, "echo" } }, -- a tick of poison
	Armor = { { "thud", 0.8, 0.5 }, { "tick", 0.4, 0.6 } }, -- GORAN shrugs a blow off
	Heal = { { "tick", 0.5, 2.2, nil, "hall" } }, -- ELIAN's care
	Reflect = { { "tick", 0.7, 2.4 }, { "boom", 0.25, 2.4, 0.2 } }, -- MIROIR DE GLACE
	Drone = { { "tick", 0.5, 2.2 }, { "wind", 0.3, 2.2, 0.15 } }, -- NOVA's sentinel takes off
	Shackled = { { "tick", 0.6, 0.35, nil, "crunch" } }, -- KAZAN's chains bite
	Domination = { { "boom", 0.45, 1.5, 0.35, "hall" }, { "tick", 0.5, 0.7 } }, -- KUROEN's DOMINATION rises or is spent
	-- The fight's big moments.
	Counter = { { "tick", 0.7, 0.8 }, { "boom", 0.35, 2.2, 0.2 } }, -- COUNTER HIT: a sharp crack on top
	Revive = { { "boom", 1, 0.45, 1.6, "hall" }, { "thud", 1, 0.35 }, { "wind", 0.6, 0.4, 1.2, "echo" } }, -- ASURA rises
	RoundStart = { { "thud", 0.7, 0.6, nil, "hall" }, { "tick", 0.4, 1.4 } }, -- FIGHT!
	-- The menus (buttons).
	UiHover = { { "tick", 0.12, 2.4, 0.04 } },
	UiClick = { { "tick", 0.3, 1.6, 0.06 }, { "thud", 0.18, 2.4 } },
}

Palette.FILES, Palette.BUSES, Palette.MATERIALS, Palette.ACTIONS = FILES, BUSES, MATERIALS, ACTIONS
return Palette
