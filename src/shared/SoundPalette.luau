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
}

Palette.FILES, Palette.BUSES, Palette.MATERIALS, Palette.ACTIONS = FILES, BUSES, MATERIALS, ACTIONS
return Palette
