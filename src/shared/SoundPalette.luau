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
	crunch = { DistortionSoundEffect = { Level = 0.12 } }, -- RYUKEN's fists, guard breaks (barely: it grates)
	echo = { EchoSoundEffect = { Delay = 0.11, Feedback = 0.25, WetLevel = -8 } }, -- DAICHA's shadow
	hall = { ReverbSoundEffect = { DecayTime = 1.4, WetLevel = -6 } }, -- ultimates, K.O.
	thin = { EqualizerSoundEffect = { LowGain = -24, MidGain = -6, HighGain = 4 } }, -- blades cutting the air
}

-- A sound: { file, volume, speed, length (seconds, then a short fade; nil = whole), bus }.
-- Each kit's material: the whoosh of its swings and the sound of its hits.
local MATERIALS = {
	KAI = { -- fists of ki
		swing = { { "wind", 0.3, 1.7, 0.16 } },
		heavySwing = { { "wind", 0.42, 1.1, 0.3 } },
		hit = { { "thud", 0.5, 0.82, 0.16 }, { "thud", 0.22, 1.56, 0.05 } },
		heavyHit = { { "thud", 0.75, 0.51, 0.24 }, { "thud", 0.3, 1.39, 0.06 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
		projectile = { { "wind", 0.47, 0.9, 0.35 }, { "boom", 0.17, 2, 0.25 } }, -- ki blast
	},
	TARO = { -- leather gloves: a slap, the body shot
		swing = { { "wind", 0.26, 2, 0.12 } },
		heavySwing = { { "wind", 0.38, 1.4, 0.22 } },
		hit = { { "thud", 0.5, 0.86, 0.16 }, { "thud", 0.22, 1.63, 0.05 } },
		heavyHit = { { "thud", 0.75, 0.53, 0.24 }, { "thud", 0.3, 1.46, 0.06 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
	},
	ZEPHYR = { -- kicks that cut the wind
		swing = { { "wind", 0.38, 1.4, 0.24, "thin" } },
		heavySwing = { { "wind", 0.51, 1, 0.4, "thin" } },
		hit = { { "thud", 0.5, 0.9, 0.16 }, { "thud", 0.22, 1.71, 0.05 }, { "wind", 0.2, 1.8, 0.12 } },
		heavyHit = { { "thud", 0.75, 0.56, 0.24 }, { "thud", 0.3, 1.53, 0.06 }, { "boom", 0.16, 1.7, 0.18, "hall" }, { "wind", 0.22, 1.2, 0.3 } },
		projectile = { { "wind", 0.51, 1.3, 0.4, "thin" } }, -- blade of wind
	},
	AKEMI = { -- the shadow's knife hand: thin, fast, dry
		swing = { { "wind", 0.3, 2.2, 0.1, "thin" } },
		heavySwing = { { "wind", 0.42, 1.6, 0.18, "thin" } },
		hit = { { "thud", 0.5, 0.94, 0.16 }, { "thud", 0.22, 1.79, 0.05 } },
		heavyHit = { { "thud", 0.75, 0.58, 0.24 }, { "thud", 0.3, 1.6, 0.06 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
		projectile = { { "wind", 0.38, 2.3, 0.12, "thin" } }, -- kunai
	},
	RYUKEN = { -- crushing fists: heavier, distorted
		swing = { { "wind", 0.34, 1.3, 0.18 } },
		heavySwing = { { "wind", 0.51, 0.85, 0.32 } },
		hit = { { "thud", 0.5, 0.98, 0.16 }, { "thud", 0.22, 1.86, 0.05 } },
		heavyHit = { { "thud", 0.75, 0.61, 0.24 }, { "thud", 0.3, 1.67, 0.06 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
		projectile = { { "boom", 0.42, 1.2, 0.5, "crunch" }, { "thud", 0.51, 0.6 } }, -- seismic strike
	},
	SHIN = { -- the water blade: a clean cut, the splash of the current
		swing = { { "wind", 0.38, 2, 0.14, "thin" } },
		heavySwing = { { "wind", 0.51, 1.5, 0.24, "thin" } },
		hit = { { "thud", 0.5, 1.02, 0.16 }, { "thud", 0.22, 1.94, 0.05 }, { "splash", 0.2, 1.7, 0.3 } },
		heavyHit = { { "thud", 0.75, 0.63, 0.24 }, { "thud", 0.3, 1.73, 0.06 }, { "boom", 0.16, 1.7, 0.18, "hall" }, { "splash", 0.22, 1.2, 0.5 } },
		projectile = { { "splash", 0.51, 1, 0.6 } }, -- current
	},
	DAICHA = { -- the inverted shadow: low, hollow, echoing
		swing = { { "wind", 0.38, 0.75, 0.24, "echo" } },
		heavySwing = { { "wind", 0.51, 0.55, 0.4, "echo" } },
		hit = { { "thud", 0.5, 1.06, 0.16, "echo" }, { "thud", 0.22, 2.01, 0.05 } },
		heavyHit = { { "thud", 0.75, 0.66, 0.24 }, { "thud", 0.3, 1.8, 0.06 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
		projectile = { { "wind", 0.51, 0.45, 0.6, "echo" } }, -- sphere
	},
	HIBECARES = { -- stone: slow, enormous
		swing = { { "wind", 0.42, 0.6, 0.3 } },
		heavySwing = { { "wind", 0.59, 0.45, 0.5 } },
		hit = { { "thud", 0.5, 1.1, 0.16 }, { "thud", 0.22, 2.09, 0.05 }, { "boom", 0.2, 1.4, 0.3 } },
		heavyHit = { { "thud", 0.75, 0.68, 0.24 }, { "thud", 0.3, 1.87, 0.06 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
		steps = 0.95, -- heavy feet
	},
	-- ASURA and Wilhem's third sheet.
	ASURA = { -- four fists of gold: KAI's blows, deeper, in the hall
		swing = { { "wind", 0.38, 1.2, 0.2 } },
		heavySwing = { { "wind", 0.55, 0.8, 0.36 } },
		hit = { { "thud", 0.5, 1.14, 0.16, "hall" }, { "thud", 0.22, 2.17, 0.05 } },
		heavyHit = { { "thud", 0.75, 0.71, 0.24 }, { "thud", 0.3, 1.94, 0.06 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
		projectile = { { "boom", 0.34, 1.4, 0.4, "hall" } },
	},
	RAIJIN = { -- the spear and its lightning: a crackle
		swing = { { "wind", 0.38, 1.8, 0.16, "thin" } },
		heavySwing = { { "wind", 0.51, 1.3, 0.28, "thin" } },
		hit = { { "thud", 0.5, 1.18, 0.16 }, { "thud", 0.22, 2.24, 0.05 } },
		heavyHit = { { "thud", 0.75, 0.73, 0.24 }, { "thud", 0.3, 2.01, 0.06 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
		projectile = { { "boom", 0.38, 2.4, 0.3, "crunch" }, { "wind", 0.34, 2, 0.2, "thin" } },
	},
	YUKINA = { -- fans of ice: a crystal tinkle
		swing = { { "wind", 0.34, 1.9, 0.18, "thin" } },
		heavySwing = { { "wind", 0.47, 1.5, 0.3, "thin" } },
		hit = { { "thud", 0.5, 1.22, 0.16 }, { "thud", 0.22, 2.32, 0.05 } },
		heavyHit = { { "thud", 0.75, 0.76, 0.24 }, { "thud", 0.3, 2.07, 0.06 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
		projectile = { { "wind", 0.42, 2.6, 0.3, "thin" } },
	},
	VENOM = { -- claws: a dry scrape
		swing = { { "wind", 0.34, 2.1, 0.12, "thin" } },
		heavySwing = { { "wind", 0.47, 1.6, 0.22, "thin" } },
		hit = { { "thud", 0.5, 1.26, 0.16 }, { "thud", 0.22, 2.39, 0.05 } },
		heavyHit = { { "thud", 0.75, 0.78, 0.24 }, { "thud", 0.3, 2.14, 0.06 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
		projectile = { { "wind", 0.47, 0.4, 0.7, "echo" } }, -- the toxic cloud
	},
	GORAN = { -- slams on the mat
		swing = { { "wind", 0.42, 0.7, 0.3 } },
		heavySwing = { { "wind", 0.59, 0.5, 0.45 } },
		hit = { { "thud", 0.5, 1.3, 0.16 }, { "thud", 0.22, 2.47, 0.05 } },
		heavyHit = { { "thud", 0.75, 0.81, 0.24 }, { "thud", 0.3, 2.21, 0.06 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
		projectile = { { "boom", 0.42, 0.55, 0.55, "crunch" }, { "wind", 0.38, 0.5, 0.4 } }, -- the shockwave rolling on the mat
		steps = 0.9,
	},
	ASTER = { -- gravity: a hollow boom
		swing = { { "wind", 0.38, 0.65, 0.3, "echo" } },
		heavySwing = { { "wind", 0.51, 0.5, 0.45, "echo" } },
		hit = { { "thud", 0.5, 1.34, 0.16 }, { "thud", 0.22, 2.55, 0.05 }, { "boom", 0.2, 2.4, 0.25, "echo" } },
		heavyHit = { { "thud", 0.75, 0.83, 0.24 }, { "thud", 0.3, 2.28, 0.06 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
		projectile = { { "wind", 0.51, 0.35, 0.6, "hall" } },
	},
	HIBIKI = { -- beats: clicks in the hall
		swing = { { "wind", 0.3, 2.2, 0.1 } },
		heavySwing = { { "wind", 0.42, 1.7, 0.18 } },
		hit = { { "thud", 0.5, 1.38, 0.16 }, { "thud", 0.22, 2.62, 0.05 } },
		heavyHit = { { "thud", 0.75, 0.86, 0.24 }, { "thud", 0.3, 2.35, 0.06 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
		projectile = { { "boom", 0.38, 2.6, 0.25, "hall" } },
	},
	KUROEN = { -- the eclipse: gauntlets on bone, a dark boom in the hall under the big ones
		swing = { { "wind", 0.34, 1.55, 0.14 } },
		heavySwing = { { "wind", 0.51, 0.95, 0.28, "echo" } },
		hit = { { "thud", 0.5, 1.42, 0.16, "hall" }, { "thud", 0.22, 2.7, 0.05 } },
		heavyHit = { { "thud", 0.75, 0.88, 0.24 }, { "thud", 0.3, 2.41, 0.06 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
	},
	KAZAN = { -- steel claws: a thin slicing whoosh, blades through the body
		swing = { { "wind", 0.38, 2.1, 0.12, "thin" } },
		heavySwing = { { "wind", 0.51, 1.4, 0.24, "thin" } },
		hit = { { "thud", 0.5, 1.46, 0.16 }, { "thud", 0.22, 2.77, 0.05 } },
		heavyHit = { { "thud", 0.75, 0.91, 0.24 }, { "thud", 0.3, 2.48, 0.06 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
	},
	KUREN = { -- blood: a wet, hollow hit
		swing = { { "wind", 0.34, 1.6, 0.18 } },
		heavySwing = { { "wind", 0.47, 1.2, 0.3 } },
		hit = { { "thud", 0.5, 1.5, 0.16 }, { "thud", 0.22, 2.85, 0.05 }, { "splash", 0.2, 0.6, 0.3, "echo" } },
		heavyHit = { { "thud", 0.75, 0.93, 0.24 }, { "thud", 0.3, 2.55, 0.06 }, { "boom", 0.16, 1.7, 0.18, "hall" }, { "splash", 0.22, 0.5, 0.5, "echo" } },
		projectile = { { "splash", 0.51, 0.5, 0.4, "thin" } },
	},
	SYLVA = { -- wood and leaves
		swing = { { "wind", 0.34, 1.5, 0.2, "thin" } },
		heavySwing = { { "wind", 0.47, 1.1, 0.32, "thin" } },
		hit = { { "thud", 0.5, 1.54, 0.16, "thin" }, { "thud", 0.22, 2.93, 0.05 } },
		heavyHit = { { "thud", 0.75, 0.95, 0.24 }, { "thud", 0.3, 2.62, 0.06 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
		projectile = { { "thud", 0.42, 0.9, nil, "echo" } }, -- the roots
	},
	ELIAN = { -- light: a bright chime in the hall
		swing = { { "wind", 0.3, 1.6, 0.2 } },
		heavySwing = { { "wind", 0.42, 1.2, 0.32 } },
		hit = { { "thud", 0.5, 1.58, 0.16 }, { "thud", 0.22, 2.7, 0.05 } },
		heavyHit = { { "thud", 0.75, 0.98, 0.24 }, { "thud", 0.3, 2.69, 0.06 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
		projectile = { { "wind", 0.42, 1.8, 0.3, "hall" } },
	},
	NOVA = { -- metal gauntlets, the drones' shots
		swing = { { "wind", 0.34, 1.9, 0.14 } },
		heavySwing = { { "wind", 0.47, 1.4, 0.24 } },
		hit = { { "thud", 0.5, 1.62, 0.16 }, { "thud", 0.22, 2.8, 0.05 } },
		heavyHit = { { "thud", 0.75, 1.0, 0.24 }, { "thud", 0.3, 2.75, 0.06 }, { "boom", 0.16, 1.7, 0.18, "hall" } },
		projectile = { { "wind", 0.26, 2.4, 0.12 } },
	},
}

-- One sound per action, the same for every fighter.
local ACTIONS = {
	Block = { { "thud", 0.34, 2.1 } }, -- a dry guard
	GuardBreak = { { "boom", 0.51, 1.5, 0.4, "crunch" }, { "thud", 0.59, 0.6 } },
	Clash = { { "boom", 0.3, 1.8, 0.3 } },
	Parry = { { "thud", 0.42, 1.4 } }, -- TARO's glove knocks it aside
	Wall = { { "boom", 0.51, 0.85, 0.5 }, { "thud", 0.59, 0.6 } }, -- HIBECARES's MUR DE PIERRE
	Evade = { { "wind", 0.42, 1.5, 0.2, "echo" } }, -- AKEMI's VOILE D'OMBRE
	Slip = { { "wind", 0.38, 2.1, 0.12 } }, -- TARO's weave
	Blink = { { "wind", 0.51, 0.6, 0.3, "echo" } }, -- DAICHA through the opponent
	Stance = { { "thud", 0.42, 1.6 }, { "thud", 0.34, 1.7 } }, -- gloves knocked together
	SuperFlash = { { "boom", 0.59, 0.7, 1.2, "hall" }, { "wind", 0.42, 0.5, 0.6 } },
	Skill = { { "wind", 0.38, 1, 0.3 } },
	Prompt = { { "tick", 0.59, 1 } },
	Perfect = { { "tick", 0.68, 1.6 }, { "tick", 0.42, 2 } },
	Graded = { { "tick", 0.59, 1.25 } },
	SuperJump = { { "jump", 0.51, 0.85 }, { "wind", 0.34, 0.8, 0.4 } },
	Bounce = { { "thud", 0.64, 0.75 } },
	KO = { { "boom", 0.77, 0.8, 1.5, "hall" }, { "thud", 0.85, 0.5 } },
	Cinematic = { { "boom", 0.26, 1.1, 0.6, "hall" } }, -- under every blow of an ultimate
	Tip = { { "thud", 0.35, 2.3 } }, -- SHIN's PRÉCISION: a bright knock on top of the hit
	Knockdown = { { "thud", 0.77, 0.55 } },
	GetUp = { { "getUp", 0.42, 1.1 } },
	Jump = { { "jump", 0.38, 1.05 } },
	Land = { { "thud", 0.34, 1.2 } },
	Dash = { { "wind", 0.34, 1.2, 0.2 } },
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
