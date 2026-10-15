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
	AKEMI_KUNAI = 95280256018725,
	AKEMI_X_SLASH_4x4 = 80350275092776,
	ASTER_ACCRETION = 93701412134586,
	ASURA_FIST_PRINT = 86344622044786,
	AURA_FLAME_8x8 = 76674667602910,
	BUBBLE = 119908280286090,
	CHAIN = 122397734804482,
	CLAW_2x2 = 124149758005404,
	CLOUD_2x2 = 0,
	CRACK_2x2 = 131532983279170,
	DAICHA_BLACK_HOLE_4x4 = 132247628747340,
	DAICHA_HOLE_SWIRL_4x4 = 96624792473549,
	DEBRIS_2x2 = 119518461000753,
	DISTORT_RING = 105297954989496,
	DROPLET = 107928975191417,
	DUST_GROUND_4x4 = 124749445884248,
	ELIAN_PALM = 113037440638130,
	ELIAN_RAY_ORB = 100526016485785,
	EMBER = 138824428381782,
	ENERGY_FLOW = 92477491586539,
	FEATHER_2x2 = 96643332969413,
	FLAME_8x8 = 134272922854864,
	FLARE_ANAMORPHIC = 127942310962349,
	GLINT = 71838431066278,
	GLOW_CORE = 79961727900875,
	GLOW_SOFT = 0,
	GODRAY = 74867653412308,
	GORAN_ANCHOR = 84432119019180,
	HEX_GRID = 100945487053832,
	HIBIKI_SOUND_ARC = 112045948370823,
	HITSPARK_HEAVY_4x4 = 82610829362765,
	HITSPARK_LIGHT_4x4 = 105360452325770,
	IMPACT_BURST_2x2 = 87592434141268,
	INK_4x4 = 116755174902827,
	KAI_KAME_BEAM_BODY = 116606402570628,
	KAI_KAME_BEAM_CORE = 125717489869006,
	KAI_KAME_BEAM_SPIRAL = 123173652646865,
	KAI_KAME_BURST = 81728354160392,
	KAI_KAME_FLARE = 135750298331349,
	KAI_KAME_GLOW = 125397937908043,
	KAI_KAME_LIGHTNING = 112897579070515,
	KAI_KAME_LIGHTNING_B = 140664334759062,
	KAI_KAME_RING = 79818135927725,
	KAI_KAME_SHOCKWAVE = 130915695956295,
	KAI_KAME_SPARK = 85921755244217,
	KAI_KAME_WISP = 98421806414049,
	KAI_KI_POP_4x4 = 140072630443668,
	KAZAN_HOOK = 88434409917310,
	KO_BRUSH_A = 84463749649351,
	KO_BRUSH_B = 135292890813993,
	KUREN_BAT_2x2 = 99430689939713,
	KUREN_BLOOM_4x4 = 85649157526636,
	KUREN_CRYSTAL_LANCE = 90407945082125,
	KUREN_VEINS = 76325948252933,
	KUROEN_BLACK_FLAME_8x8 = 138704745721269,
	KUROEN_CORONA = 85673913682982,
	KUROEN_MARK = 125172311459320,
	LEAF_2x2 = 121691312069788,
	LIGHTNING_A = 0,
	LIGHTNING_B = 119788487794702,
	LIGHTNING_C = 0,
	LIGHTNING_D = 0,
	MOON = 0,
	MOTE = 88069804150348,
	NOTE_2x2 = 101399425391714,
	NOVA_DRONE = 87557678069395,
	NOVA_HOLO_LINES = 92396296251480,
	PETAL_2x2 = 138312182076607,
	PIXEL_2x2 = 76093508887765,
	PUFF_2x2 = 88489781075602,
	RAIJIN_SPEAR = 83176546770615,
	RING_DASHED = 88460202745815,
	RING_SOFT = 73346109162402,
	RING_THIN = 138989809489773,
	RYUKEN_STAR_CRACK_4x4 = 101287857141872,
	SCORCH = 103708884224582,
	SCREEN_CRACK = 0,
	SEAL_CIRCLE = 0,
	SHARD = 136592694621528,
	SHIN_RIPPLE_4x4 = 98511362239144,
	SHIN_WATER_RIBBON = 135810012202821,
	SLASH_ARC = 86267136066812,
	SMOKE_CEL_8x8 = 107275933469412,
	SNOWFLAKE_2x2 = 93332849660878,
	SPEEDLINES_LINEAR_4x4 = 108538541586321,
	SPEEDLINES_RADIAL_4x4 = 94886256262593,
	SPLASH_4x4 = 106532420058283,
	STAR4 = 105965822566876,
	STREAK = 131235104854356,
	STREAK_V = 92964447571627,
	SYLVA_GRASS_RING = 140272106184135,
	SYLVA_VINE = 115387718212361,
	TARO_FIRE_RING_4x4 = 117903813899443,
	TRAIL_CORE = 76783761900785,
	TRAIL_GRADIENT = 86921442957900,
	TRAIL_RIM = 89342529833038,
	TRAIL_WISPY = 102118287764041,
	VENOM_PUDDLE = 130293878205784,
	VIGNETTE = 115641742126501,
	WISP_4x4 = 79172398844712,
	YUKINA_FROST_PLATE = 86922521419467,
	YUKINA_FROST_TRAIL = 139012676940669,
	ZEPHYR_AIR_CRESCENT = 117599885895241,
	ZEPHYR_SPIRAL_PUFF_4x4 = 123822722292251,
	ZEPHYR_WIND_LINE = 139025991717366,
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
