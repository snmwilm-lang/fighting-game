--[[
	The asset IDs of Wilhem's VFX pack (pure: no Roblox API, no require).

	The files live in assets/vfx: textures/VFX_<KEY>.png (VFX_COMMON_<KEY>.png for the shared
	ones) and meshes/VFX_COMMON_<KEY>.fbx. Wilhem uploads them to Roblox (Asset Manager, Bulk
	Import) and gives their IDs; `python3 tools/vfxids.py his_list.txt` writes them here.
	0 = not uploaded yet: never an invented ID (CLAUDE.md).

	The client draws a family of effects with the pack only once every asset it needs is
	uploaded (`ready`), otherwise the game's own procedural effects stay: the shared combat
	effects (COMMON), each fighter's (KITS: trail, impact, dash, aura, skill, passive), KAI's
	wave (KAME: the textures of the Red Kamehameha, on his KAIENHA).
]]
local VfxConfig = {}

VfxConfig.TEXTURES = {
	AKEMI_KUNAI = 0,
	AKEMI_X_SLASH_4x4 = 0,
	ASTER_ACCRETION = 0,
	ASURA_FIST_PRINT = 0,
	AURA_FLAME_8x8 = 0,
	BUBBLE = 0,
	CHAIN = 0,
	CLAW_2x2 = 0,
	CLOUD_2x2 = 0,
	CRACK_2x2 = 0,
	DAICHA_BLACK_HOLE_4x4 = 0,
	DAICHA_HOLE_SWIRL_4x4 = 0,
	DEBRIS_2x2 = 0,
	DISTORT_RING = 0,
	DROPLET = 0,
	DUST_GROUND_4x4 = 0,
	ELIAN_PALM = 0,
	ELIAN_RAY_ORB = 0,
	EMBER = 0,
	ENERGY_FLOW = 0,
	FEATHER_2x2 = 0,
	FLAME_8x8 = 0,
	FLARE_ANAMORPHIC = 0,
	GLINT = 0,
	GLOW_CORE = 0,
	GLOW_SOFT = 0,
	GODRAY = 0,
	GORAN_ANCHOR = 0,
	HEX_GRID = 0,
	HIBIKI_SOUND_ARC = 0,
	HITSPARK_HEAVY_4x4 = 0,
	HITSPARK_LIGHT_4x4 = 0,
	IMPACT_BURST_2x2 = 0,
	INK_4x4 = 0,
	KAI_KAME_BEAM_BODY = 0,
	KAI_KAME_BEAM_CORE = 0,
	KAI_KAME_BEAM_SPIRAL = 0,
	KAI_KAME_BURST = 0,
	KAI_KAME_FLARE = 0,
	KAI_KAME_GLOW = 0,
	KAI_KAME_LIGHTNING = 0,
	KAI_KAME_LIGHTNING_B = 0,
	KAI_KAME_RING = 0,
	KAI_KAME_SHOCKWAVE = 0,
	KAI_KAME_SPARK = 0,
	KAI_KAME_WISP = 0,
	KAI_KI_POP_4x4 = 0,
	KAZAN_HOOK = 0,
	KO_BRUSH_A = 0,
	KO_BRUSH_B = 0,
	KUREN_BAT_2x2 = 0,
	KUREN_BLOOM_4x4 = 0,
	KUREN_CRYSTAL_LANCE = 0,
	KUREN_VEINS = 0,
	KUROEN_BLACK_FLAME_8x8 = 0,
	KUROEN_CORONA = 0,
	KUROEN_MARK = 0,
	LEAF_2x2 = 0,
	LIGHTNING_A = 0,
	LIGHTNING_B = 0,
	LIGHTNING_C = 0,
	LIGHTNING_D = 0,
	MOON = 0,
	MOTE = 0,
	NOTE_2x2 = 0,
	NOVA_DRONE = 0,
	NOVA_HOLO_LINES = 0,
	PETAL_2x2 = 0,
	PIXEL_2x2 = 0,
	PUFF_2x2 = 0,
	RAIJIN_SPEAR = 0,
	RING_DASHED = 0,
	RING_SOFT = 0,
	RING_THIN = 0,
	RYUKEN_STAR_CRACK_4x4 = 0,
	SCORCH = 0,
	SCREEN_CRACK = 0,
	SEAL_CIRCLE = 0,
	SHARD = 0,
	SHIN_RIPPLE_4x4 = 0,
	SHIN_WATER_RIBBON = 0,
	SLASH_ARC = 0,
	SMOKE_CEL_8x8 = 0,
	SNOWFLAKE_2x2 = 0,
	SPEEDLINES_LINEAR_4x4 = 0,
	SPEEDLINES_RADIAL_4x4 = 0,
	SPLASH_4x4 = 0,
	STAR4 = 0,
	STREAK = 0,
	STREAK_V = 0,
	SYLVA_GRASS_RING = 0,
	SYLVA_VINE = 0,
	TARO_FIRE_RING_4x4 = 0,
	TRAIL_CORE = 0,
	TRAIL_GRADIENT = 0,
	TRAIL_RIM = 0,
	TRAIL_WISPY = 0,
	VENOM_PUDDLE = 0,
	VIGNETTE = 0,
	WISP_4x4 = 0,
	YUKINA_FROST_PLATE = 0,
	YUKINA_FROST_TRAIL = 0,
	ZEPHYR_AIR_CRESCENT = 0,
	ZEPHYR_SPIRAL_PUFF_4x4 = 0,
	ZEPHYR_WIND_LINE = 0,
}

-- (the server turns each one into a MeshPart in ReplicatedStorage.VFX_Meshes: a script cannot
-- set a MeshId)
VfxConfig.MESHES = {
	CLAW3 = 0,
	CONE_FLARE = 0,
	CRESCENT_BLADE = 0,
	DOME = 0,
	FIST_GIANT = 0,
	FLOOR_DISC = 0,
	HELIX = 0,
	ICE_SHARD_A = 0,
	ICE_SHARD_B = 0,
	ICE_SHARD_C = 0,
	PILLAR = 0,
	ROCK_A = 0,
	ROCK_B = 0,
	ROCK_C = 0,
	ROOT = 0,
	SHIELD_HEX = 0,
	SHOCK_CYLINDER = 0,
	SHOCK_RING = 0,
	SLASH_180 = 0,
	SLASH_360 = 0,
	SLASH_90 = 0,
	SPHERE = 0,
	SPIKE = 0,
	TWISTER = 0,
	WING = 0,
}

-- What each family needs (generated from the pack's code: every asset its effects name).
VfxConfig.COMMON = {
	textures = {
		"AURA_FLAME_8x8", "CRACK_2x2", "DEBRIS_2x2", "DISTORT_RING", "DUST_GROUND_4x4", "ENERGY_FLOW",
		"FLARE_ANAMORPHIC", "GLINT", "GLOW_CORE", "GODRAY", "HEX_GRID", "HITSPARK_HEAVY_4x4",
		"HITSPARK_LIGHT_4x4", "IMPACT_BURST_2x2", "KO_BRUSH_A", "KO_BRUSH_B", "MOTE", "PETAL_2x2",
		"PUFF_2x2", "RING_DASHED", "RING_SOFT", "RING_THIN", "SHARD", "SLASH_ARC", "SMOKE_CEL_8x8",
		"SPEEDLINES_LINEAR_4x4", "SPEEDLINES_RADIAL_4x4", "STAR4", "STREAK_V", "TRAIL_GRADIENT",
		"VIGNETTE", "WISP_4x4",
	},
	meshes = {
		"SHIELD_HEX", "SHOCK_CYLINDER", "SHOCK_RING", "SLASH_180", "SPHERE",
	},
}
VfxConfig.KITS = {
	AKEMI = { textures = { "AKEMI_KUNAI", "AKEMI_X_SLASH_4x4", "INK_4x4", "TRAIL_CORE", "TRAIL_RIM" }, meshes = {  } },
	ASTER = { textures = { "ASTER_ACCRETION", "TRAIL_CORE", "TRAIL_RIM" }, meshes = {  } },
	ASURA = { textures = { "ASURA_FIST_PRINT", "FLAME_8x8", "TRAIL_CORE", "TRAIL_RIM" }, meshes = {  } },
	DAICHA = { textures = { "DAICHA_BLACK_HOLE_4x4", "DAICHA_HOLE_SWIRL_4x4", "INK_4x4", "TRAIL_CORE", "TRAIL_RIM" }, meshes = {  } },
	ELIAN = { textures = { "ELIAN_PALM", "ELIAN_RAY_ORB", "FEATHER_2x2", "STREAK", "TRAIL_CORE", "TRAIL_RIM" }, meshes = {  } },
	GORAN = { textures = { "GORAN_ANCHOR" }, meshes = {  } },
	HIBECARES = { textures = { "EMBER" }, meshes = { "ROCK_A", "ROCK_B", "ROCK_C" } },
	HIBIKI = { textures = { "HIBIKI_SOUND_ARC", "NOTE_2x2", "TRAIL_WISPY" }, meshes = {  } },
	KAI = { textures = { "KAI_KI_POP_4x4", "TRAIL_CORE", "TRAIL_RIM", "TRAIL_WISPY" }, meshes = {  } },
	KAZAN = { textures = { "CHAIN", "CLAW_2x2", "KAZAN_HOOK", "TRAIL_CORE", "TRAIL_RIM" }, meshes = {  } },
	KUREN = { textures = { "DROPLET", "KUREN_BAT_2x2", "KUREN_BLOOM_4x4", "KUREN_CRYSTAL_LANCE", "KUREN_VEINS", "TRAIL_CORE", "TRAIL_RIM" }, meshes = {  } },
	KUROEN = { textures = { "KUROEN_BLACK_FLAME_8x8", "KUROEN_CORONA", "KUROEN_MARK", "TRAIL_CORE", "TRAIL_RIM" }, meshes = {  } },
	["KUROEN SHIN"] = { textures = { "FEATHER_2x2", "FLAME_8x8", "TRAIL_CORE", "TRAIL_RIM" }, meshes = {  } },
	NOVA = { textures = { "EMBER", "FLAME_8x8", "NOVA_DRONE", "NOVA_HOLO_LINES", "PIXEL_2x2" }, meshes = {  } },
	RAIJIN = { textures = { "LIGHTNING_B", "RAIJIN_SPEAR", "TRAIL_RIM" }, meshes = {  } },
	RYUKEN = { textures = { "RYUKEN_STAR_CRACK_4x4", "SCORCH", "TRAIL_WISPY" }, meshes = { "SPIKE" } },
	SHIN = { textures = { "DROPLET", "SHIN_RIPPLE_4x4", "SHIN_WATER_RIBBON", "SPLASH_4x4", "STREAK" }, meshes = { "CRESCENT_BLADE" } },
	SYLVA = { textures = { "LEAF_2x2", "SYLVA_GRASS_RING", "SYLVA_VINE" }, meshes = { "ROOT" } },
	TARO = { textures = { "EMBER", "FLAME_8x8", "TARO_FIRE_RING_4x4", "TRAIL_CORE", "TRAIL_RIM" }, meshes = {  } },
	VENOM = { textures = { "BUBBLE", "CLAW_2x2", "DROPLET", "SPLASH_4x4", "TRAIL_CORE", "TRAIL_RIM", "VENOM_PUDDLE" }, meshes = {  } },
	YUKINA = { textures = { "SNOWFLAKE_2x2", "YUKINA_FROST_PLATE", "YUKINA_FROST_TRAIL" }, meshes = { "ICE_SHARD_A", "ICE_SHARD_B", "ICE_SHARD_C" } },
	ZEPHYR = { textures = { "TRAIL_WISPY", "ZEPHYR_AIR_CRESCENT", "ZEPHYR_SPIRAL_PUFF_4x4", "ZEPHYR_WIND_LINE" }, meshes = { "CRESCENT_BLADE" } },
}
VfxConfig.KAME = { textures = { "KAI_KAME_BEAM_BODY", "KAI_KAME_BEAM_CORE", "KAI_KAME_BEAM_SPIRAL", "KAI_KAME_BURST", "KAI_KAME_FLARE", "KAI_KAME_GLOW", "KAI_KAME_LIGHTNING", "KAI_KAME_LIGHTNING_B", "KAI_KAME_RING", "KAI_KAME_SHOCKWAVE", "KAI_KAME_SPARK", "KAI_KAME_WISP" }, meshes = {} }

-- The content ID of a texture / a mesh, or nil while it is not uploaded.
local function content(list, key)
	local id = list[key]
	if type(id) ~= "number" or id <= 0 then return nil end
	return "rbxassetid://" .. string.format("%d", id)
end
function VfxConfig.texture(key) return content(VfxConfig.TEXTURES, key) end
function VfxConfig.mesh(key) return content(VfxConfig.MESHES, key) end

-- The assets of `need` ({ textures, meshes }) still missing, in order.
function VfxConfig.missing(need)
	local out = {}
	for _, key in need.textures or {} do
		if not VfxConfig.texture(key) then table.insert(out, key) end
	end
	for _, key in need.meshes or {} do
		if not VfxConfig.mesh(key) then table.insert(out, key) end
	end
	return out
end
function VfxConfig.ready(need) return need ~= nil and #VfxConfig.missing(need) == 0 end

-- Everything a fighter's effects need: the shared ones, and its own (nil: a kit the pack does
-- not cover).
function VfxConfig.kitNeed(kit)
	local own = VfxConfig.KITS[kit]
	if not own then return nil end
	local need = { textures = table.clone(VfxConfig.COMMON.textures), meshes = table.clone(VfxConfig.COMMON.meshes) }
	for _, key in own.textures do table.insert(need.textures, key) end
	for _, key in own.meshes do table.insert(need.meshes, key) end
	return need
end
function VfxConfig.kitReady(kit) return VfxConfig.ready(VfxConfig.kitNeed(kit)) end

-- The file of an asset in assets/vfx (what Wilhem uploads), from its key.
local KIT_PREFIXES = { "KAI_", "TARO_", "ZEPHYR_", "AKEMI_", "RYUKEN_", "SHIN_", "DAICHA_", "RAIJIN_", "YUKINA_",
	"VENOM_", "GORAN_", "ASTER_", "HIBIKI_", "KAZAN_", "KUREN_", "SYLVA_", "ELIAN_", "NOVA_", "KUROEN_", "ASURA_" }
function VfxConfig.file(key)
	if VfxConfig.MESHES[key] ~= nil then return "meshes/VFX_COMMON_" .. key .. ".fbx" end
	for _, prefix in KIT_PREFIXES do
		if string.sub(key, 1, #prefix) == prefix then return "textures/VFX_" .. key .. ".png" end
	end
	return "textures/VFX_COMMON_" .. key .. ".png"
end

return VfxConfig
