--[[
	BREAKFRAMEZ — VFX_Chars (ModuleScript, côté CLIENT) — étape 2
	════════════════════════════════════════════════════════════
	In the game: Wilhem's VFX pack (stages 1 to 3), adapted for Rojo: the IDs come from
	Shared.VfxConfig (EffectsController uses the pack only once they are uploaded), the meshes
	from ReplicatedStorage.VFX_Meshes (built by the server), the shake goes through the game's
	camera (V.ShakeHook).
	Traînée de coup, impact, dash (et arc de coup quand le perso en a un) des 22 combattants :
	KAI, TARO, ZEPHYR, AKEMI, RYUKEN, SHIN, DAICHA, HIBECARES (étape 2),
	RAIJIN, YUKINA, VENOM, GORAN, ASTER, HIBIKI, KAZAN, KUREN, SYLVA, ELIAN, NOVA, KUROEN, ASURA, KUROEN_SHIN (étape 3).

	Placement : ReplicatedStorage > VFX_Chars, à côté de VFX_Common (qu'il utilise).
	Colle les ID des PNG VFX_<PERSO>_* dans C.Tex ci-dessous.

	API (color facultatif : par défaut l'Énergie du perso ; passer la couleur du skin sinon)
	  local C = require(ReplicatedStorage.VFX_Chars)
	  local trail = C.Trail("KAI", baseAttachment, tipAttachment)   -- trail:On() pendant les images actives, trail:Off() après
	  C.Impact("KAI", "heavy", hitCFrame, nil, { hitstop = 8 })      -- "light" | "medium" | "heavy" | "finisher"
	  C.Dash("KAI", character, direction)
	  C.Swing("ZEPHYR", V.ArcCFrame(epaule, 60))                       -- arc visible du coup, face caméra (60° = coup montant)

	BUDGETS GARANTIS : chaque impact garde la structure imposée par niveau
	  léger 6–10 particules · moyen 12–16 + petit anneau · lourd 20–28 + onde + poussière · fin de combo 30–40 + débris
	La signature du perso passe d'abord ; des étincelles complètent jusqu'à la cible (8 / 14 / 24 / 36).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local V = require(script.Parent.VFX_Common)
local K = V.Kit
local NS = V.NS
local FR = 1 / 60
local WHITE = V.WHITE
local BLACK = Color3.new(0, 0, 0)

local C = {}

C.Tex = V.Tex -- (the IDs: Shared.VfxConfig)

---------------------------------------------------------------------------- outils
local LV = { light = 1, medium = 2, heavy = 3, finisher = 4 }
local TARGET = { light = 8, medium = 14, heavy = 24, finisher = 36 }
local RANGE = { light = { 6, 10 }, medium = { 12, 16 }, heavy = { 20, 28 }, finisher = { 30, 40 } }
local SCALE = { 0.8, 1, 1.25, 1.5 }

local function seq(...): ColorSequence
	local a = { ... }
	local k = {}
	for i = 1, #a, 2 do
		table.insert(k, ColorSequenceKeypoint.new(a[i], a[i + 1]))
	end
	return ColorSequence.new(k)
end

local function hot(color: Color3): ColorSequence -- cœur blanc puis couleur
	return seq(0, WHITE, 0.25, color, 1, color)
end

--- compose un impact : signature du perso + structure imposée par niveau + complément d'étincelles
-- signature(a, p, lv, S, color) -> nombre de particules émises PLUS TARD (différées), ou 0
local function compose(level: string, cf: CFrame, color: Color3, opts: { [string]: any }?, signature)
	local o = opts or {}
	local lv = assert(LV[level], "niveau inconnu : " .. tostring(level))
	local S = (o.scale or 1) * SCALE[lv]
	local p, a = V.Host(cf, 2.5)
	if o.hitstop then
		V.Hitstop(o.hitstop)
	end
	local before = V.Stats.particles
	-- (in the game: Wilhem's impact sheets, HITSPARK and IMPACT_BURST, at the heart of every
	-- blow, under the fighter's own signature; a signature that draws one already keeps its own)
	local sheets, flip = {}, K.flipFx
	K.flipFx = function(att, tex, ...)
		sheets[tex] = true
		return flip(att, tex, ...)
	end
	local ok, pending = pcall(signature, a, p, lv, S, color)
	K.flipFx = flip
	if not ok then
		error(pending, 0)
	end
	pending = pending or 0
	if not (sheets.HITSPARK_LIGHT_4x4 or sheets.HITSPARK_HEAVY_4x4) then
		local size = ({ 6, 7, 8, 8.7 })[lv] * S -- (the sizes of V.Impact)
		if lv <= 2 then
			flip(a, "HITSPARK_LIGHT_4x4", 4, hot(color), size, 14 + lv)
		else
			flip(a, "HITSPARK_HEAVY_4x4", 4, hot(color), size, 15 + lv)
			flip(a, "IMPACT_BURST_2x2", 2, color, NS(0, size * 0.7, 0.15, size * 0.85, 1, size * 0.6), 5 + lv,
				{ mode = "Random", tr = NS(0, 0, 0.6, 0, 1, 1) })
		end
	end
	if lv == 2 then
		K.ring(a, "RING_THIN", color, 1.2 * S, 5 * S, 12)
	elseif lv >= 3 then
		K.ring(a, "RING_SOFT", color, 3 * S, (11 + 2 * lv) * S, 16)
		if lv == 4 then
			K.debris(a, 6, 40 * S, 1.1 * S)
		end
		local gp = V.GroundBelow(cf.Position, o.ignore)
		if gp then
			K.dustAt(CFrame.new(gp), 2, 6 * S)
		else
			K.smoke(a, nil, 2, 4 * S)
		end
	end
	local used = V.Stats.particles - before + pending
	local fill = TARGET[level] - used
	if fill > 0 then
		K.sparks(a, color, fill, (35 + 12 * lv) * S, (0.9 + 0.3 * lv) * S)
	end
	if lv >= 2 then
		V.Light(p, color, (8 + 5 * lv) * S, 2 + lv, 4 + 3 * lv)
	end
	local total = V.Stats.particles - before + pending
	local r = RANGE[level]
	if total < r[1] or total > r[2] then
		warn(("[VFX_Chars] budget %s hors limites : %d"):format(level, total))
	end
	return total
end

--- traînée en 2 couches (cœur + bords) sur les mêmes Attachments ; extras : émetteur à la pointe
local function trailObj(base: Attachment, tip: Attachment, layers: { { [string]: any } }, tipEmitter: { [string]: any }?)
	local trails = {}
	for _, L in layers do
		local t = Instance.new("Trail")
		t.Attachment0 = base
		t.Attachment1 = tip
		t.Texture = V.Tex[L.tex]
		t.TextureMode = Enum.TextureMode.Stretch
		t.Color = if typeof(L.color) == "ColorSequence" then L.color else ColorSequence.new(L.color)
		t.LightEmission = L.le or 1
		t.LightInfluence = 0
		t.Brightness = L.br or 3
		t.Lifetime = math.clamp(L.life or 0.12, 0.08, 0.2)
		t.FaceCamera = false
		t.MinLength = 0.05
		t.Transparency = L.tr or NS(0, 0, 1, 1)
		t.Enabled = false
		t.Parent = base.Parent
		table.insert(trails, t)
	end
	local em: ParticleEmitter? = nil
	if tipEmitter then
		em = V.Emitter(tip, tipEmitter)
		em.Enabled = false
	end
	local api = {}
	function api.On()
		for _, t in trails do
			t.Enabled = true
		end
		if em then
			em.Enabled = true
		end
	end
	function api.Off()
		for _, t in trails do
			t.Enabled = false
		end
		if em then
			em.Enabled = false
		end
	end
	function api.Destroy()
		for _, t in trails do
			t:Destroy()
		end
		if em then
			em:Destroy()
		end
	end
	return api
end

local function hrpOf(char: Model): BasePart
	return assert(char:FindFirstChild("HumanoidRootPart"), "HumanoidRootPart manquant") :: BasePart
end

--- émetteur attaché au perso pendant dur secondes (laisse une traînée de particules derrière lui)
local function bodyEmitter(char: Model, p: { [string]: any }, dur: number)
	local hrp = hrpOf(char)
	local at = Instance.new("Attachment")
	at.Parent = hrp
	local e = V.Emitter(at, p)
	e.Enabled = true
	V.After(dur, function()
		e.Enabled = false
	end)
	V.After(dur + 1.5, function()
		at:Destroy()
	end)
	return e
end

local function camRightSign(dir: Vector3): number
	local cam = workspace.CurrentCamera
	return if cam.CFrame.RightVector:Dot(dir) >= 0 then 1 else -1
end

local function rockMesh(name: string, cf: CFrame, vel: Vector3, size: number, life: number, color: Color3)
	local m = K.meshTemplate(name):Clone()
	m.Anchored = true
	m.CanCollide = false
	m.CanQuery = false
	m.CanTouch = false
	m.CastShadow = false
	m.Material = Enum.Material.Slate
	m.Color = color
	m.Size = Vector3.one * size
	m.CFrame = cf
	m.Parent = K.folder()
	local spin = Vector3.new(math.random() * 20 - 10, math.random() * 20 - 10, math.random() * 20 - 10)
	V.Animate(life, function(k, t)
		local pos = cf.Position + vel * t + Vector3.new(0, -60 * t * t / 2, 0)
		m.CFrame = CFrame.new(pos) * CFrame.Angles(spin.X * t, spin.Y * t, spin.Z * t)
		m.Size = Vector3.one * size * (1 - math.max(0, (k - 0.7) / 0.3))
	end, function()
		m:Destroy()
	end)
end

---------------------------------------------------------------------------- PERSOS
local CH = {}

-- KAI 開 — ki, rouge, cœur blanc ------------------------------------------------
CH.KAI = {
	color = V.Energy.KAI,
	Trail = function(base, tip, color)
		return trailObj(base, tip, {
			{ tex = "TRAIL_RIM", color = color },
			{ tex = "TRAIL_CORE", color = WHITE, br = 4 },
		})
	end,
	Impact = function(a, p, lv, S, color)
		K.flipFx(a, "KAI_KI_POP_4x4", 4, hot(color), (3.2 + 0.6 * lv) * S, 15)
		K.coreFlash(a, 2 * S, 4)
		K.flipFx(a, "MOTE", nil :: any, hot(color), 0.5 * S, 18, { n = 1 + lv, speed = { 10, 20 }, spread = 180, drag = 8 })
		return 0
	end,
	Dash = function(char, dir, color)
		V.DashGround(char, color, dir)
		local _, a = V.Host(hrpOf(char).CFrame, 1)
		K.flipFx(a, "MOTE", nil :: any, color, 0.4, 20, { n = 4, speed = { 4, 8 }, spread = 180, drag = 6 })
	end,
}

-- TARO 火 — feu, boxeur ------------------------------------------------------------
local TARO_YELLOW = Color3.fromHex("FFE14A")
CH.TARO = {
	color = V.Energy.TARO,
	Trail = function(base, tip, color)
		return trailObj(base, tip, {
			{ tex = "TRAIL_RIM", color = color },
			{ tex = "TRAIL_CORE", color = TARO_YELLOW, br = 4 },
		}, {
			tex = "EMBER", color = seq(0, TARO_YELLOW, 1, color), size = NS(0, 0.35, 1, 0), life = { 15, 25 },
			speed = { 2, 5 }, spread = 180, accel = Vector3.new(0, 8, 0), rate = 40, orient = "VelocityParallel",
		})
	end,
	Impact = function(a, p, lv, S, color)
		K.flipFx(a, "TARO_FIRE_RING_4x4", 4, seq(0, TARO_YELLOW, 0.3, color, 1, color), (4.5 + 0.5 * lv) * S, 18)
		K.flipFx(a, "FLAME_8x8", 8, seq(0, TARO_YELLOW, 0.4, color, 1, color), NS(0, 2.2 * S, 1, 3 * S), 22,
			{ n = lv, speed = { 12 * S, 22 * S }, spread = 35, drag = 6, rot = { -15, 15 } })
		local e = V.Emitter(a, {
			tex = "EMBER", color = seq(0, TARO_YELLOW, 1, color), size = NS(0, 0.5 * S, 1, 0), life = { 18, 30 },
			speed = { 35 * S, 60 * S }, spread = 30, drag = 4, accel = Vector3.new(0, -35, 0), orient = "VelocityParallel", br = 3,
		})
		V.Emit(e, 2 + lv)
		return 0
	end,
	Dash = function(char, dir, color, o)
		bodyEmitter(char, {
			tex = "EMBER", color = seq(0, TARO_YELLOW, 1, color), size = NS(0, 0.45, 1, 0), life = { 18, 30 },
			speed = { 1, 3 }, spread = 180, accel = Vector3.new(0, 6, 0), rate = 70, orient = "VelocityParallel",
			shape = Enum.ParticleEmitterShape.Box,
		}, o.duration or 0.25)
		local _, a = V.Host(V.FeetCF(char), 1)
		K.flipFx(a, "FLAME_8x8", 8, seq(0, TARO_YELLOW, 1, color), 2, 18, { n = 2, speed = { 3, 6 }, spread = 40, dir = Enum.NormalId.Top })
	end,
}

-- ZEPHYR 風 — vent, jambes, très transparent ---------------------------------------
local AIR_TR = 0.35
CH.ZEPHYR = {
	color = V.Energy.ZEPHYR,
	Trail = function(base, tip, color)
		return trailObj(base, tip, {
			{ tex = "TRAIL_WISPY", color = seq(0, WHITE, 0.3, color, 1, color), tr = NS(0, AIR_TR, 1, 1), life = 0.14 },
		})
	end,
	Swing = function(cf, color, o)
		V.Slash(cf, color, { mesh = o.mesh or "SLASH_180", tex = "ZEPHYR_AIR_CRESCENT", scale = o.scale or 1.1, fadeFrames = 12 })
		V.Slash(cf * CFrame.new(0, 0.15, 0), WHITE, { mesh = o.mesh or "SLASH_180", tex = "ZEPHYR_AIR_CRESCENT", scale = (o.scale or 1.1) * 0.85, fadeFrames = 8 })
	end,
	Impact = function(a, p, lv, S, color)
		K.flipFx(a, "RING_DASHED", nil :: any, color, NS(0, 2 * S, 1, (5 + lv) * S), 14, { tr = NS(0, AIR_TR, 1, 1), rot = { 0, 360 } })
		local sp = V.Emitter(a, { tex = "ZEPHYR_SPIRAL_PUFF_4x4", grid = 4, color = hot(color), size = (4 + 0.6 * lv) * S, life = 18, rot = { 0, 360 }, rotSpeed = { 200, 300 }, tr = NS(AIR_TR) })
		V.Emit(sp, 1)
		local wl = V.Emitter(a, { tex = "ZEPHYR_WIND_LINE", color = color, size = NS(0, 2.5 * S, 1, 3.5 * S), life = { 14, 20 }, speed = { 12, 22 }, spread = 180, drag = 6, rot = { 0, 360 }, tr = NS(0, AIR_TR, 1, 1) })
		V.Emit(wl, 1 + lv)
		return 0
	end,
	Dash = function(char, dir, color)
		local hrp = hrpOf(char)
		local back = CFrame.lookAt(hrp.Position, hrp.Position - dir)
		local _, a = V.Host(back, 1)
		local flip = if camRightSign(dir) > 0 then 180 else 0 -- la tête de la ligne suit le dash
		local wl = V.Emitter(a, { tex = "ZEPHYR_WIND_LINE", color = color, size = NS(0, 2.5, 1, 4), life = { 12, 18 }, speed = { 20, 30 }, spread = 25, drag = 3, rot = { flip, flip }, tr = NS(0, AIR_TR, 1, 1), shape = nil })
		for i = 0, 2 do
			V.After(i * 2 * FR, function()
				a.Position = Vector3.new(0, (i - 1) * 1.4, 0)
				V.Emit(wl, 2)
			end)
		end
		local _, a2 = V.Host(CFrame.lookAt(hrp.Position, hrp.Position + dir), 1)
		K.ring(a2, "RING_DASHED", color, 3, 6, 12, { orient = "VelocityPerpendicular", speed = { 0.01 } })
	end,
}

-- AKEMI 影 — ombre, violet + encre noire ----------------------------------------
CH.AKEMI = {
	color = V.Energy.AKEMI,
	Trail = function(base, tip, color)
		return trailObj(base, tip, {
			{ tex = "TRAIL_RIM", color = color, br = 3.5 },
			{ tex = "TRAIL_CORE", color = BLACK, le = 0, br = 1 },
		})
	end,
	Swing = function(cf, color, o) -- slash noir à bord violet, 2 couches
		local mesh = o.mesh or "SLASH_180"
		V.Slash(cf, color, { mesh = mesh, scale = (o.scale or 1) * 1.08, fadeFrames = 10 })
		V.Slash(cf * CFrame.new(0, 0.05, 0), BLACK, { mesh = mesh, scale = o.scale or 1, material = Enum.Material.SmoothPlastic, fadeFrames = 12 })
	end,
	Impact = function(a, p, lv, S, color)
		K.flipFx(a, "AKEMI_X_SLASH_4x4", 4, color, (5.5 + 0.5 * lv) * S, 18, { rot = { -15, 15 }, br = 3.5 })
		K.flipFx(a, "AKEMI_X_SLASH_4x4", 4, BLACK, (4.7 + 0.42 * lv) * S, 18, { rot = { -15, 15 }, le = 0, br = 1, z = 2 })
		K.flipFx(a, "INK_4x4", 4, color, (3.5 + 0.4 * lv) * S, 22, { le = 0, br = 1, n = if lv >= 3 then 2 else 1, z = 1 })
		return 0
	end,
	Dash = function(char, dir, color)
		for i = 0, 2 do
			V.After(i * 2 * FR, function()
				V.Ghost(char, BLACK, 10, color)
			end)
		end
		local _, a = V.Host(V.FeetCF(char) * CFrame.new(0, 1, 0), 1.5)
		K.flipFx(a, "INK_4x4", 4, color, 3.5, 24, { le = 0, br = 1 })
	end,
}

-- RYUKEN 拳 — rage, rouge + vapeur grise -----------------------------------------
local STEAM = Color3.fromHex("B8B4B0")
CH.RYUKEN = {
	color = V.Energy.RYUKEN,
	Trail = function(base, tip, color)
		return trailObj(base, tip, {
			{ tex = "TRAIL_WISPY", color = seq(0, Color3.fromHex("FFE0C0"), 0.25, color, 1, Color3.fromHex("8B1A00")), life = 0.16 },
		}, {
			tex = "WISP_4x4", grid = 4, color = STEAM, le = 0, br = 1, size = NS(0, 0.8, 1, 1.8), life = { 20, 30 },
			speed = { 1, 3 }, spread = 60, accel = Vector3.new(0, 5, 0), rate = 25, tr = NS(0, 0.3, 1, 0.8),
		})
	end,
	Impact = function(a, p, lv, S, color)
		K.flipFx(a, "RYUKEN_STAR_CRACK_4x4", 4, hot(color), (5 + 0.6 * lv) * S, 22, { br = 3 })
		K.flipFx(a, "HITSPARK_LIGHT_4x4", 4, seq(0, WHITE, 1, Color3.fromHex("FF8A3A")), (3.5 + 0.5 * lv) * S, 14, { z = 2 })
		local st = V.Emitter(a, { tex = "WISP_4x4", grid = 4, color = STEAM, le = 0, br = 1, size = NS(0, 1.5 * S, 1, 3 * S), life = { 26, 36 }, speed = { 3, 6 }, spread = 70, dir = Enum.NormalId.Top, accel = Vector3.new(0, 6, 0), tr = NS(0, 0.25, 1, 0.8) })
		V.Emit(st, lv)
		return 0
	end,
	Dash = function(char, dir, color)
		local feet = V.FeetCF(char)
		for i = 0, 2 do
			V.After(i * 3 * FR, function()
				local pos = feet.Position - dir.Unit * (i * 2.5)
				V.Mark(CFrame.new(pos), 4, "SCORCH", Color3.fromHex("1A0A06"), nil, 0.8, 1.2)
				V.Mark(CFrame.new(pos + Vector3.new(0, 0.02, 0)), 2.6, "SCORCH", color, nil, 0.15, 0.5, true)
			end)
		end
		local _, a = V.Host(feet, 2)
		local st = V.Emitter(a, { tex = "WISP_4x4", grid = 4, color = STEAM, le = 0, br = 1, size = NS(0, 1.2, 1, 2.5), life = { 26, 36 }, speed = { 2, 4 }, spread = 40, dir = Enum.NormalId.Top, tr = NS(0, 0.3, 1, 0.8) })
		V.Emit(st, 3)
	end,
}

-- SHIN 流 — eau, katana --------------------------------------------------------------
CH.SHIN = {
	color = V.Energy.SHIN,
	Trail = function(base, tip, color)
		return trailObj(base, tip, {
			{ tex = "SHIN_WATER_RIBBON", color = seq(0, WHITE, 0.2, color, 1, color), life = 0.16 },
		}, {
			tex = "DROPLET", color = hot(color), size = NS(0, 0.35, 1, 0.15), life = { 16, 26 },
			speed = { 3, 8 }, spread = 70, accel = Vector3.new(0, -45, 0), rate = 35, orient = "VelocityParallel",
		})
	end,
	Swing = function(cf, color, o)
		V.Slash(cf, color, { mesh = o.mesh or "SLASH_180", scale = o.scale or 1 })
		local _, a = V.Host(cf, 1.5)
		K.flipFx(a, "SPLASH_4x4", 4, hot(color), 3, 22)
	end,
	Impact = function(a, p, lv, S, color)
		-- ligne vive : coupe nette qui traverse le point d'impact
		local cf = (a.Parent :: BasePart).CFrame
		local right = cf.RightVector
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Parent, a1.Parent = p, p
		local L = (4 + 1.5 * lv) * S
		a0.WorldPosition = cf.Position - right * L + cf.UpVector * 0.6 * S
		a1.WorldPosition = cf.Position + right * L - cf.UpVector * 0.6 * S
		local outer = V.Beam(p, a0, a1, { tex = "STREAK", color = color, w = 0.9 * S, br = 3 })
		local core = V.Beam(p, a0, a1, { tex = "STREAK", color = WHITE, w = 0.35 * S, br = 5, z = 1 })
		V.Animate(12 * FR, function(k)
			local w = (1 - k) ^ 2
			outer.Width0, outer.Width1 = 0.9 * S * w, 0.9 * S * w
			core.Width0, core.Width1 = 0.35 * S * w, 0.35 * S * w
		end)
		local d = V.Emitter(a, { tex = "DROPLET", color = hot(color), size = NS(0, 0.5 * S, 1, 0.2 * S), life = { 20, 32 }, speed = { 20 * S, 38 * S }, spread = 60, drag = 2, accel = Vector3.new(0, -50, 0), orient = "VelocityParallel", br = 3 })
		V.Emit(d, 2 + 2 * lv)
		if lv >= 2 then
			K.flipFx(a, "SPLASH_4x4", 4, hot(color), (3 + 0.6 * lv) * S, 22)
		end
		return 0
	end,
	Dash = function(char, dir, color)
		local feet = V.FeetCF(char)
		local _, a = V.Host(feet * CFrame.Angles(math.rad(90), 0, 0), 2)
		local rp = V.Emitter(a, { tex = "SHIN_RIPPLE_4x4", grid = 4, color = color, size = NS(0, 2, 1, 6), life = 30, speed = { 0.01 }, orient = "VelocityPerpendicular", br = 2 })
		V.Emit(rp, 1)
		V.After(4 * FR, function()
			a.WorldPosition = feet.Position + dir.Unit * 2.5
			V.Emit(rp, 1)
		end)
		local d = V.Emitter(a, { tex = "DROPLET", color = hot(color), size = NS(0, 0.35, 1, 0.15), life = { 16, 24 }, speed = { 6, 12 }, spread = 40, accel = Vector3.new(0, -45, 0), orient = "VelocityParallel" })
		V.Emit(d, 4)
	end,
}

-- DAICHA 闇 — vide, violet + matière noire, orbe -----------------------------------
local function portal(pos: Vector3, color: Color3)
	local _, a = V.Host(CFrame.new(pos), 1.5)
	K.flipFx(a, "DAICHA_HOLE_SWIRL_4x4", 4, color, 6.5, 30, { rot = { 0, 360 }, z = -1, br = 3 })
	K.flipFx(a, "DAICHA_BLACK_HOLE_4x4", 4, color, 5, 30, { le = 0, br = 1, rot = { 0, 360 }, z = 1 })
	K.flipFx(a, "DISTORT_RING", nil :: any, WHITE, NS(0, 8, 1, 2), 20, { le = 0, tr = NS(0, 0.6, 1, 1) })
end

CH.DAICHA = {
	color = V.Energy.DAICHA,
	-- traînée derrière l'orbe : base/tip = deux Attachments de part et d'autre de l'orbe
	Trail = function(base, tip, color)
		return trailObj(base, tip, {
			{ tex = "TRAIL_RIM", color = color, life = 0.2 },
			{ tex = "TRAIL_CORE", color = BLACK, le = 0, br = 1, life = 0.2 },
		})
	end,
	Impact = function(a, p, lv, S, color)
		-- 1) aspiration (3 images) : l'énergie est aspirée vers le point d'impact
		p.Size = Vector3.one * (5 + lv) * S
		p.Shape = Enum.PartType.Ball
		local inward = V.Emitter(p, {
			tex = "MOTE", color = color, size = NS(0, 0.5 * S, 1, 0.1), life = 6, speed = { 25 * S },
			shape = Enum.ParticleEmitterShape.Sphere, shapeStyle = Enum.ParticleEmitterShapeStyle.Surface, inward = true,
		})
		V.Emit(inward, 2 + lv)
		K.flipFx(a, "DISTORT_RING", nil :: any, WHITE, NS(0, 6 * S, 1, 0.5), 4, { le = 0, tr = NS(0.5) })
		-- 2) éclat d'encre après 3 images
		V.After(3 * FR, function()
			K.flipFx(a, "INK_4x4", 4, color, (3.8 + 0.5 * lv) * S, 24, { le = 0, br = 1, z = 1 })
			K.ring(a, "RING_THIN", color, 1, (5 + lv) * S, 12)
		end)
		return 2
	end,
	-- opts : from, to (Vector3), delay (images, défaut 8), hide (cache le perso côté client pendant le trajet)
	Dash = function(char, dir, color, o)
		local hrp = hrpOf(char)
		local from = o.from or hrp.Position
		local to = o.to or (from + dir.Unit * 12)
		local delay = (o.delay or 8) * FR
		portal(from, color)
		if o.hide ~= false then
			local parts = {}
			for _, d in char:GetDescendants() do
				if d:IsA("BasePart") or d:IsA("Decal") then
					table.insert(parts, d)
					d.LocalTransparencyModifier = 1
				end
			end
			V.After(delay, function()
				for _, d in parts do
					d.LocalTransparencyModifier = 0
				end
			end)
		end
		V.After(delay * 0.5, function()
			portal(to, color)
		end)
	end,
}

-- HIBECARES 崩 — pierre, poussière + braises orange ---------------------------------
local ROCK = Color3.fromHex("6E625A")
CH.HIBECARES = {
	color = V.Energy.HIBECARES,
	Trail = function(base, tip, color)
		return trailObj(base, tip, {
			{ tex = "TRAIL_GRADIENT", color = seq(0, color, 0.4, Color3.fromHex("C9A27A"), 1, V.DUST), le = 0.35, br = 1.5, life = 0.16 },
		}, {
			tex = "PUFF_2x2", grid = 2, color = V.DUST, le = 0, br = 1, size = NS(0, 0.8, 1, 1.6), life = { 14, 20 },
			speed = { 1, 3 }, spread = 90, rate = 20, rot = { 0, 360 },
		})
	end,
	Swing = function(cf, color, o) -- arc lourd + poussière
		V.Slash(cf, Color3.fromHex("C98A50"), { mesh = o.mesh or "SLASH_180", scale = (o.scale or 1) * 1.3, fadeFrames = 14 })
		V.Slash(cf * CFrame.new(0, 0.1, 0), color, { mesh = o.mesh or "SLASH_180", scale = (o.scale or 1) * 1.15, fadeFrames = 9 })
		local _, a = V.Host(cf, 1.5)
		K.flipFx(a, "PUFF_2x2", 2, V.DUST, NS(0, 2, 1, 4), 18, { le = 0, br = 1, n = 3, speed = { 4, 9 }, spread = 90 })
	end,
	Impact = function(a, p, lv, S, color)
		local cf = (a.Parent :: BasePart).CFrame
		local names = { "ROCK_A", "ROCK_B", "ROCK_C" }
		for i = 1, math.min(lv, 3) do -- rochers en mesh (pas des particules)
			local v = (cf.LookVector * 0.6 + Vector3.new(math.random() - 0.5, 0.8 + math.random() * 0.5, math.random() - 0.5)).Unit * (18 + 8 * math.random()) * S
			rockMesh(names[i], cf, v, (0.7 + 0.3 * math.random()) * S, 0.9, ROCK)
		end
		K.debris(a, 1 + lv, 32 * S, 0.9 * S, ROCK)
		local e = V.Emitter(a, { tex = "EMBER", color = seq(0, Color3.fromHex("FFE0A0"), 1, color), size = NS(0, 0.4 * S, 1, 0), life = { 18, 30 }, speed = { 18 * S, 35 * S }, spread = 70, drag = 3, accel = Vector3.new(0, -20, 0), orient = "VelocityParallel", br = 3 })
		V.Emit(e, lv)
		K.flipFx(a, "PUFF_2x2", 2, V.DUST, NS(0, 2.5 * S, 1, 4.5 * S), 20, { le = 0, br = 1, speed = { 3, 6 }, spread = 60 })
		V.Shake(0.15 * lv, 6 + 2 * lv)
		return 0
	end,
	Dash = function(char, dir, color) -- le sol tremble
		local feet = V.FeetCF(char)
		V.Shake(0.35, 12)
		K.dustAt(feet, 2, 6)
		local _, a = V.Host(feet * CFrame.Angles(math.rad(90), 0, 0), 2)
		K.debris(a, 4, 18, 0.6)
		V.Mark(feet, 6, "CRACK_2x2", Color3.new(0.12, 0.1, 0.1), math.random(0, 2), 0.6, 1.0)
	end,
}

-- RAIJIN 雷 — foudre, jaune, lance ----------------------------------------------------
CH.RAIJIN = {
	color = V.Energy.RAIJIN,
	Trail = function(base, tip, color) -- ruban électrique sur la lance
		return trailObj(base, tip, {
			{ tex = "TRAIL_RIM", color = color },
			{ tex = "LIGHTNING_B", color = WHITE, br = 4, life = 0.1 },
		}, {
			tex = "STREAK_V", color = hot(color), size = NS(0, 0.5, 1, 0), life = { 6, 12 }, speed = { 8, 18 }, spread = 180,
			drag = 8, rate = 30, orient = "VelocityParallel",
		})
	end,
	Impact = function(a, p, lv, S, color) -- petit éclair + lumière qui clignote
		local pos = (a.Parent :: BasePart).Position
		V.Lightning(pos + Vector3.new(-1.5, 2.5, 0) * S, pos + Vector3.new(1.2, -1.8, 0) * S, color, { segs = 5, dur = (6 + 2 * lv) * FR, jitter = 0.7 * S, width = 0.35 * S })
		K.flipFx(a, "HITSPARK_LIGHT_4x4", 4, hot(color), (4 + 0.6 * lv) * S, 14)
		K.coreFlash(a, 2.2 * S, 4)
		local l = Instance.new("PointLight")
		l.Color, l.Range, l.Shadows = color, (10 + 3 * lv) * S, false
		l.Parent = p
		V.Animate((6 + 2 * lv) * FR, function(k, t)
			l.Brightness = if math.floor(t * 30) % 2 == 0 then 5 * (1 - k) else 0.5
		end, function()
			l:Destroy()
		end)
		return 0
	end,
	Dash = function(char, dir, color, o) -- étincelles
		bodyEmitter(char, { tex = "STREAK_V", color = hot(color), size = NS(0, 0.6, 1, 0), life = { 8, 14 }, speed = { 6, 14 }, spread = 180, drag = 6, rate = 80, orient = "VelocityParallel" }, o.duration or 0.25)
		local hrp = hrpOf(char)
		V.Lightning(hrp.Position, hrp.Position + dir.Unit * 8, color, { segs = 6, dur = 8 * FR, jitter = 0.8, width = 0.3 })
	end,
}

-- YUKINA 雪 — glace, éventails ------------------------------------------------------------
CH.YUKINA = {
	color = V.Energy.YUKINA,
	Trail = function(base, tip, color) -- arc de givre bordé de cristaux
		return trailObj(base, tip, {
			{ tex = "YUKINA_FROST_TRAIL", color = seq(0, WHITE, 0.3, color, 1, color), life = 0.16 },
		}, {
			tex = "SNOWFLAKE_2x2", grid = 2, mode = "Random", color = WHITE, size = NS(0, 0.5, 1, 0), life = { 20, 30 },
			speed = { 1, 3 }, spread = 180, rate = 20, rot = { 0, 360 }, rotSpeed = { -90, 90 }, accel = Vector3.new(0, -3, 0),
		})
	end,
	Impact = function(a, p, lv, S, color) -- éclats de glace + bouffée de neige
		local e = V.Emitter(a, { tex = "SHARD", color = seq(0, WHITE, 0.5, color, 1, color), size = NS(0, 0.9 * S, 1, 0.2), life = { 14, 22 }, speed = { 25 * S, 45 * S }, spread = 70, drag = 5, rot = { 0, 360 }, rotSpeed = { -300, 300 }, br = 3 })
		V.Emit(e, 2 + lv)
		K.flipFx(a, "PUFF_2x2", 2, WHITE, NS(0, 2.5 * S, 1, 4.5 * S), 20, { le = 0, br = 1, speed = { 2, 5 }, spread = 60 })
		K.flipFx(a, "SNOWFLAKE_2x2", 2, WHITE, NS(0, 0.6 * S, 1, 0), 30, { mode = "Random", n = lv, speed = { 6, 12 }, spread = 180, drag = 4 })
		return 0
	end,
	Swing = function(cf, color, o)
		V.Slash(cf, color, { mesh = o.mesh or "SLASH_180", scale = o.scale or 1, fadeFrames = 12 })
		local _, a = V.Host(cf, 1.5)
		K.flipFx(a, "SNOWFLAKE_2x2", 2, WHITE, NS(0, 0.5, 1, 0), 30, { mode = "Random", n = 6, speed = { 4, 10 }, spread = 180, drag = 3 })
	end,
	Dash = function(char, dir, color) -- plaque de givre au sol
		local feet = V.FeetCF(char)
		V.Mark(feet, 7, "YUKINA_FROST_PLATE", color, nil, 1.0, 1.0, true)
		local _, a = V.Host(feet * CFrame.new(0, 1, 0), 1.5)
		K.flipFx(a, "SNOWFLAKE_2x2", 2, WHITE, NS(0, 0.5, 1, 0), 30, { mode = "Random", n = 5, speed = { 3, 7 }, spread = 180, dir = Enum.NormalId.Top })
	end,
}

-- VENOM 毒 — poison, vert acide ------------------------------------------------------------
local VENOM_DARK = Color3.fromHex("1E4A12")
CH.VENOM = {
	color = V.Energy.VENOM,
	Trail = function(base, tip, color) -- griffures vertes qui gouttent
		return trailObj(base, tip, {
			{ tex = "TRAIL_RIM", color = color },
			{ tex = "TRAIL_CORE", color = VENOM_DARK, le = 0, br = 1 },
		}, {
			tex = "DROPLET", color = hot(color), size = NS(0, 0.4, 1, 0.15), life = { 16, 26 }, speed = { 1, 3 }, spread = 40,
			dir = Enum.NormalId.Bottom, accel = Vector3.new(0, -40, 0), rate = 30, orient = "VelocityParallel",
		})
	end,
	Swing = function(cf, color, o)
		local _, a = V.Host(cf, 1.5)
		K.flipFx(a, "CLAW_2x2", 2, hot(color), 5 * (o.scale or 1), 14, { mode = "Random", rot = { -10, 10 }, br = 3 })
		local d = V.Emitter(a, { tex = "DROPLET", color = hot(color), size = NS(0, 0.4, 1, 0.15), life = { 16, 26 }, speed = { 1, 4 }, spread = 60, accel = Vector3.new(0, -40, 0), orient = "VelocityParallel" })
		V.Emit(d, 5)
	end,
	Impact = function(a, p, lv, S, color) -- éclaboussure verte
		K.flipFx(a, "SPLASH_4x4", 4, hot(color), (3.5 + 0.6 * lv) * S, 22, { rot = { -20, 20 } })
		local d = V.Emitter(a, { tex = "DROPLET", color = hot(color), size = NS(0, 0.45 * S, 1, 0.15), life = { 18, 28 }, speed = { 18 * S, 32 * S }, spread = 70, drag = 2, accel = Vector3.new(0, -45, 0), orient = "VelocityParallel" })
		V.Emit(d, 2 + lv)
		K.flipFx(a, "BUBBLE", nil :: any, color, NS(0, 0.5 * S, 1, 0.9 * S), 30, { n = lv, speed = { 3, 8 }, spread = 180, drag = 4, rot = { 0, 0 } })
		return 0
	end,
	Dash = function(char, dir, color) -- flaque toxique
		local feet = V.FeetCF(char)
		V.Mark(feet, 6, "VENOM_PUDDLE", color, nil, 1.2, 1.0, false)
		local _, a = V.Host(feet * CFrame.new(0, 0.3, 0), 2)
		K.flipFx(a, "BUBBLE", nil :: any, color, NS(0, 0.4, 1, 0.8), 40, { n = 3, speed = { 1, 3 }, spread = 30, dir = Enum.NormalId.Top, rot = { 0, 0 } })
	end,
}

-- GORAN 剛 — titan, lutteur --------------------------------------------------------------
CH.GORAN = {
	color = V.Energy.GORAN,
	Trail = function(base, tip, color)
		return trailObj(base, tip, {
			{ tex = "TRAIL_GRADIENT", color = seq(0, color, 1, V.DUST), le = 0.5, br = 2, life = 0.14 },
		})
	end,
	Swing = function(cf, color, o) -- onde au sol
		local gp = V.GroundBelow(cf.Position) or cf.Position
		local _, a = V.Host(CFrame.new(gp) * CFrame.Angles(math.rad(90), 0, 0), 2)
		K.ring(a, "RING_SOFT", color, 2, 12 * (o.scale or 1), 16, { orient = "VelocityPerpendicular" })
		K.dustAt(CFrame.new(gp), 2, 6)
	end,
	Impact = function(a, p, lv, S, color) -- fissure + débris
		K.flipFx(a, "CRACK_2x2", 2, hot(color), (4.5 + 0.6 * lv) * S, 20, { mode = "Random", br = 3 })
		K.debris(a, 1 + lv, 35 * S, 1 * S)
		K.flipFx(a, "PUFF_2x2", 2, V.DUST, NS(0, 2.5 * S, 1, 4.5 * S), 20, { le = 0, br = 1, speed = { 3, 6 }, spread = 60 })
		V.Shake(0.1 * lv, 6)
		return 0
	end,
	Dash = function(char, dir, color) -- poussière à chaque pas
		for i = 0, 2 do
			V.After(i * 5 * FR, function()
				K.dustAt(V.FeetCF(char), 1, 5)
				V.Shake(0.12, 5)
			end)
		end
	end,
}

-- ASTER 星 — gravité, violet + noir -------------------------------------------------------
CH.ASTER = {
	color = V.Energy.ASTER,
	Trail = function(base, tip, color) -- anneaux qui se resserrent
		return trailObj(base, tip, {
			{ tex = "TRAIL_RIM", color = color },
			{ tex = "TRAIL_CORE", color = BLACK, le = 0, br = 1 },
		}, {
			tex = "RING_THIN", color = color, size = NS(0, 2, 1, 0.2), life = { 10, 14 }, speed = { 0.1 }, rate = 18, br = 3,
		})
	end,
	Impact = function(a, p, lv, S, color) -- aspiration puis éclat
		p.Size = Vector3.one * (5 + lv) * S
		p.Shape = Enum.PartType.Ball
		local inward = V.Emitter(p, {
			tex = "STAR4", color = color, size = NS(0, 0.6 * S, 1, 0.1), life = 6, speed = { 25 * S },
			shape = Enum.ParticleEmitterShape.Sphere, shapeStyle = Enum.ParticleEmitterShapeStyle.Surface, inward = true,
		})
		V.Emit(inward, 2 + lv)
		V.After(3 * FR, function()
			K.coreFlash(a, (2.5 + 0.4 * lv) * S, 5)
			K.flipFx(a, "STAR4", nil :: any, hot(color), NS(0, 0.8 * S, 1, 0), 18, { n = lv, speed = { 15, 30 }, spread = 180, drag = 6 })
		end)
		return 1 + lv
	end,
	Dash = function(char, dir, color, o) -- poussière d'étoiles
		bodyEmitter(char, { tex = "STAR4", color = hot(color), size = NS(0, 0.5, 1, 0), life = { 16, 26 }, speed = { 0.5, 2 }, spread = 180, rate = 60, rot = { 0, 90 } }, o.duration or 0.25)
	end,
}

-- HIBIKI 響 — son, rose -------------------------------------------------------------------
CH.HIBIKI = {
	color = V.Energy.HIBIKI,
	Trail = function(base, tip, color) -- ondulations
		return trailObj(base, tip, {
			{ tex = "TRAIL_WISPY", color = seq(0, WHITE, 0.3, color, 1, color), life = 0.14 },
		}, {
			tex = "RING_THIN", color = color, size = NS(0, 0.4, 1, 2), tr = NS(0, 0, 1, 1), life = { 10, 14 }, speed = { 0.1 }, rate = 15,
		})
	end,
	Impact = function(a, p, lv, S, color) -- rafale d'anneaux
		local n = 1 + lv
		for i = 0, n - 1 do
			V.After(i * 2 * FR, function()
				K.ring(a, "RING_THIN", if i % 2 == 0 then color else WHITE, 1 * S, (5 + i) * S, 12)
			end)
		end
		K.flipFx(a, "NOTE_2x2", 2, hot(color), NS(0, 1.2 * S, 1, 0.8 * S), 26, { mode = "Random", n = 1, speed = { 6, 10 }, spread = 60, dir = Enum.NormalId.Top, rot = { -20, 20 } })
		return n
	end,
	Dash = function(char, dir, color) -- un anneau à chaque pas
		for i = 0, 2 do
			V.After(i * 4 * FR, function()
				local _, a = V.Host(V.FeetCF(char) * CFrame.Angles(math.rad(90), 0, 0), 1)
				K.ring(a, "RING_THIN", color, 1, 4, 14, { orient = "VelocityPerpendicular" })
			end)
		end
	end,
}

-- KAZAN 鎖 — acier, griffes et chaînes ---------------------------------------------------
local STEEL = Color3.fromHex("C8C8D0")
CH.KAZAN = {
	color = V.Energy.KAZAN,
	Trail = function(base, tip, color)
		return trailObj(base, tip, {
			{ tex = "TRAIL_RIM", color = color },
			{ tex = "TRAIL_CORE", color = STEEL, br = 3 },
		}, {
			tex = "STREAK_V", color = hot(color), size = NS(0, 0.4, 1, 0), life = { 6, 10 }, speed = { 10, 20 }, spread = 90,
			accel = Vector3.new(0, -40, 0), rate = 25, orient = "VelocityParallel",
		})
	end,
	Swing = function(cf, color, o) -- 3 griffures parallèles
		local _, a = V.Host(cf, 1)
		K.flipFx(a, "CLAW_2x2", 2, hot(color), 5.5 * (o.scale or 1), 14, { mode = "Random", rot = { -10, 10 }, br = 3.5 })
	end,
	Impact = function(a, p, lv, S, color) -- griffures + étincelles
		K.flipFx(a, "CLAW_2x2", 2, hot(color), (4.5 + 0.5 * lv) * S, 16, { mode = "Random", rot = { -15, 15 }, br = 3.5 })
		K.flipFx(a, "HITSPARK_LIGHT_4x4", 4, seq(0, WHITE, 1, color), (3 + 0.4 * lv) * S, 12, { z = 2 })
		return 0
	end,
	Dash = function(char, dir, color, o) -- une chaîne qui traîne
		local hrp = hrpOf(char)
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, -0.5, 0.6)
		a0.Parent = hrp
		local p, a1 = V.Host(V.FeetCF(char), 1.2)
		local b = V.Beam(p, a0, a1, { tex = "CHAIN", color = STEEL, w = 0.7, mode = Enum.TextureMode.Wrap, tlen = 1.6, br = 1.5, le = 0.3 })
		b.CurveSize0 = -2
		local dur = o.duration or 0.3
		V.Animate(dur + 0.3, function(k, t)
			local behind = hrp.Position - dir.Unit * 5
			local gp = V.GroundBelow(behind, { char }) or (behind - Vector3.new(0, 2.8, 0))
			a1.WorldPosition = gp + Vector3.new(0, 0.2, 0)
			b.Transparency = NS(math.max(0, (t - dur) / 0.3))
		end, function()
			a0:Destroy()
		end)
		K.sparks(a1, color, 6, 18, 0.6, 60)
	end,
}

-- KUREN 血 — sang stylisé, cramoisi, vampire ----------------------------------------------
local KUREN_DARK = Color3.fromHex("2A0006")
CH.KUREN = {
	color = V.Energy.KUREN,
	Trail = function(base, tip, color) -- croissant sombre à bord rouge
		return trailObj(base, tip, {
			{ tex = "TRAIL_RIM", color = color, br = 3.5 },
			{ tex = "TRAIL_CORE", color = KUREN_DARK, le = 0, br = 1 },
		})
	end,
	Swing = function(cf, color, o)
		local mesh = o.mesh or "SLASH_180"
		V.Slash(cf, color, { mesh = mesh, scale = (o.scale or 1) * 1.08, fadeFrames = 10 })
		V.Slash(cf * CFrame.new(0, 0.05, 0), KUREN_DARK, { mesh = mesh, scale = o.scale or 1, material = Enum.Material.SmoothPlastic, fadeFrames = 12 })
	end,
	Impact = function(a, p, lv, S, color) -- fleur cramoisie qui éclot
		K.flipFx(a, "KUREN_BLOOM_4x4", 4, hot(color), (4 + 0.6 * lv) * S, 22, { rot = { 0, 360 } })
		K.flipFx(a, "PETAL_2x2", 2, color, NS(0, 0.7 * S, 1, 0.3), 30, { mode = "Random", n = lv, speed = { 10, 20 }, spread = 180, drag = 4, rotSpeed = { -200, 200 } })
		local d = V.Emitter(a, { tex = "DROPLET", color = hot(color), size = NS(0, 0.4 * S, 1, 0.15), life = { 16, 26 }, speed = { 15 * S, 28 * S }, spread = 70, drag = 2, accel = Vector3.new(0, -40, 0), orient = "VelocityParallel" })
		V.Emit(d, lv)
		return 0
	end,
	Dash = function(char, dir, color) -- brume + chauves-souris
		local hrp = hrpOf(char)
		local _, a = V.Host(CFrame.lookAt(hrp.Position, hrp.Position - dir), 1.5)
		K.smoke(a, Color3.fromHex("5A0A16"), 2, 4)
		local bats = V.Emitter(a, { tex = "KUREN_BAT_2x2", grid = 2, mode = "Random", color = KUREN_DARK, le = 0, br = 1, size = NS(0, 1, 1, 0.6), life = { 24, 36 }, speed = { 15, 25 }, spread = 50, accel = Vector3.new(0, 8, 0) })
		V.Emit(bats, 4)
	end,
}

-- SYLVA 森 — nature, vert (rose en BLOSSOM) ------------------------------------------------
CH.SYLVA = {
	color = V.Energy.SYLVA,
	Trail = function(base, tip, color) -- liane + feuilles
		return trailObj(base, tip, {
			{ tex = "SYLVA_VINE", color = color, life = 0.16, le = 0.6, br = 2 },
		}, {
			tex = "LEAF_2x2", grid = 2, mode = "Random", color = color, le = 0.5, size = NS(0, 0.6, 1, 0.3), life = { 25, 40 },
			speed = { 1, 4 }, spread = 180, rate = 15, rot = { 0, 360 }, rotSpeed = { -120, 120 }, accel = Vector3.new(0, -4, 0),
		})
	end,
	Impact = function(a, p, lv, S, color) -- gerbe de feuilles
		local e = V.Emitter(a, { tex = "LEAF_2x2", grid = 2, mode = "Random", color = color, le = 0.5, size = NS(0, 0.8 * S, 1, 0.4), life = { 24, 36 }, speed = { 20 * S, 36 * S }, spread = 55, drag = 5, rot = { 0, 360 }, rotSpeed = { -300, 300 }, accel = Vector3.new(0, -6, 0) })
		V.Emit(e, 2 + lv)
		K.flipFx(a, "HITSPARK_LIGHT_4x4", 4, hot(color), (3.5 + 0.5 * lv) * S, 14)
		return 0
	end,
	Dash = function(char, dir, color, o) -- pétales
		local petal = if o.blossom then Color3.fromHex("FF9AC8") else color
		bodyEmitter(char, { tex = "PETAL_2x2", grid = 2, mode = "Random", color = petal, size = NS(0, 0.6, 1, 0.3), life = { 30, 45 }, speed = { 1, 3 }, spread = 180, rate = 40, rot = { 0, 360 }, rotSpeed = { -150, 150 }, accel = Vector3.new(0, -3, 0) }, o.duration or 0.25)
	end,
}

-- ELIAN 癒 — lumière, or pâle ---------------------------------------------------------------
CH.ELIAN = {
	color = V.Energy.ELIAN,
	Trail = function(base, tip, color)
		return trailObj(base, tip, {
			{ tex = "TRAIL_RIM", color = color },
			{ tex = "TRAIL_CORE", color = WHITE, br = 4 },
		})
	end,
	Swing = function(cf, color, o) -- empreinte de paume lumineuse
		local _, a = V.Host(cf, 1)
		K.flipFx(a, "ELIAN_PALM", nil :: any, hot(color), NS(0, 3.2 * (o.scale or 1), 1, 3.8 * (o.scale or 1)), 14, { tr = NS(0, 0, 0.5, 0.2, 1, 1), rot = { 0, 0 }, br = 3.5 })
	end,
	Impact = function(a, p, lv, S, color) -- halo + plumes
		K.flipFx(a, "ELIAN_PALM", nil :: any, hot(color), NS(0, (2.6 + 0.4 * lv) * S, 1, (3.2 + 0.4 * lv) * S), 14, { tr = NS(0, 0, 0.5, 0.2, 1, 1), rot = { 0, 0 }, br = 3.5 })
		K.flipFx(a, "RING_THIN", nil :: any, color, NS(0, 1 * S, 1, (4 + lv) * S), 14, { rot = { 0, 0 } })
		K.flipFx(a, "FEATHER_2x2", 2, seq(0, WHITE, 1, color), NS(0, 0.9 * S, 1, 0.6 * S), 40, { mode = "Random", n = lv, speed = { 6, 14 }, spread = 180, drag = 5, accel = Vector3.new(0, -3, 0), rotSpeed = { -90, 90 } })
		return 0
	end,
	Dash = function(char, dir, color, o) -- traînée de lumière
		local hrp = hrpOf(char)
		local p, a0 = V.Host(CFrame.new(hrp.Position), 1)
		local a1 = Instance.new("Attachment")
		a1.Parent = p
		local b = V.Beam(p, a0, a1, { tex = "STREAK", color = color, w = 2.2, br = 3 })
		local dur = o.duration or 0.25
		V.Animate(dur + 0.25, function(k, t)
			a1.WorldPosition = hrp.Position + Vector3.new(0, 0.5, 0)
			b.Transparency = NS(math.max(0, (t - dur) / 0.25))
		end)
		K.flipFx(a0, "MOTE", nil :: any, color, 0.4, 30, { n = 6, speed = { 2, 5 }, spread = 180, rot = { 0, 0 } })
	end,
}

-- NOVA 機 — tech, orange / cyan ------------------------------------------------------------
local NOVA_CYAN = Color3.fromHex("6FE0FF")
CH.NOVA = {
	color = V.Energy.NOVA,
	Trail = function(base, tip, color) -- vapeur du piston
		return trailObj(base, tip, {
			{ tex = "TRAIL_GRADIENT", color = seq(0, WHITE, 0.3, color, 1, color), life = 0.12 },
		}, {
			tex = "WISP_4x4", grid = 4, color = Color3.fromHex("D8DCE0"), le = 0, br = 1, size = NS(0, 0.8, 1, 2), life = { 18, 26 },
			speed = { 2, 5 }, spread = 40, rate = 25, tr = NS(0, 0.2, 1, 0.8),
		})
	end,
	Impact = function(a, p, lv, S, color) -- carrés de glitch
		K.flipFx(a, "PIXEL_2x2", 2, NOVA_CYAN, NS(0, (2.5 + 0.5 * lv) * S, 1, (3 + 0.5 * lv) * S), 10, { mode = "Random", n = lv, rot = { 0, 0 }, speed = { 4, 10 }, spread = 180 })
		K.flipFx(a, "HITSPARK_LIGHT_4x4", 4, hot(color), (3.5 + 0.5 * lv) * S, 14)
		return 0
	end,
	Dash = function(char, dir, color, o) -- jets de propulseurs
		local hrp = hrpOf(char)
		local _, a = V.Host(CFrame.lookAt(hrp.Position - dir.Unit, hrp.Position - dir.Unit * 3), 1.5)
		K.flipFx(a, "FLAME_8x8", 8, seq(0, WHITE, 0.3, NOVA_CYAN, 1, color), NS(0, 1.6, 1, 2.6), 16, { n = 4, speed = { 18, 28 }, spread = 12, rot = { 80, 100 } })
		bodyEmitter(char, { tex = "EMBER", color = seq(0, WHITE, 1, NOVA_CYAN), size = NS(0, 0.35, 1, 0), life = { 10, 16 }, speed = { 6, 12 }, spread = 25, rate = 50, orient = "VelocityParallel" }, o.duration or 0.25)
	end,
}

-- KUROEN 蝕 — éclipse, rouge + noir -------------------------------------------------------
CH.KUROEN = {
	color = V.Energy.KUROEN,
	Trail = function(base, tip, color)
		return trailObj(base, tip, {
			{ tex = "TRAIL_RIM", color = color, br = 3.5 },
			{ tex = "TRAIL_CORE", color = BLACK, le = 0, br = 1 },
		})
	end,
	Impact = function(a, p, lv, S, color) -- sphère noire + couronne rouge
		K.flipFx(a, "KUROEN_CORONA", nil :: any, hot(color), NS(0, (3 + 0.5 * lv) * S, 1, (4.5 + 0.6 * lv) * S), 18, { tr = NS(0, 0, 0.6, 0.1, 1, 1), rotSpeed = { -60, 60 }, br = 3.5 })
		K.flipFx(a, "GLOW_CORE", nil :: any, BLACK, NS(0, (1.9 + 0.3 * lv) * S, 1, (2.6 + 0.4 * lv) * S), 18, { le = 0, br = 1, tr = NS(0, 0, 0.7, 0.1, 1, 1), z = 2 })
		return 0
	end,
	Dash = function(char, dir, color) -- image fantôme rouge et noire
		for i = 0, 2 do
			V.After(i * 2 * FR, function()
				if i % 2 == 0 then
					V.Ghost(char, BLACK, 10, color)
				else
					V.Ghost(char, color, 8)
				end
			end)
		end
	end,
}

-- ASURA (boss) — or, quatre bras -------------------------------------------------------------
CH.ASURA = {
	color = V.Energy.ASURA,
	Trail = function(base, tip, color) -- une des 4 traînées dorées (appeler une fois par bras)
		return trailObj(base, tip, {
			{ tex = "TRAIL_RIM", color = color },
			{ tex = "TRAIL_CORE", color = WHITE, br = 4 },
		})
	end,
	Impact = function(a, p, lv, S, color) -- empreinte de poing dorée
		K.flipFx(a, "ASURA_FIST_PRINT", nil :: any, hot(color), NS(0, (3 + 0.5 * lv) * S, 1, (3.8 + 0.5 * lv) * S), 16, { tr = NS(0, 0, 0.5, 0.2, 1, 1), rot = { -10, 10 }, br = 3.5 })
		K.flipFx(a, "FLAME_8x8", 8, seq(0, WHITE, 0.3, color, 1, color), NS(0, 2 * S, 1, 3 * S), 20, { n = lv, speed = { 8, 16 }, spread = 60, rot = { -20, 20 } })
		return 0
	end,
	Dash = function(char, dir, color) -- image fantôme dorée + armure
		V.Ghost(char, color, 10)
		V.SuperArmor(char)
	end,
}

-- KUROEN SHIN (boss) — blanc et or ---------------------------------------------------------
CH.KUROEN_SHIN = {
	color = V.Energy.KUROEN_SHIN,
	Trail = function(base, tip, color)
		return trailObj(base, tip, {
			{ tex = "TRAIL_RIM", color = V.GOLD },
			{ tex = "TRAIL_CORE", color = WHITE, br = 4 },
		})
	end,
	Impact = function(a, p, lv, S, color) -- éclat blanc + plumes de lumière
		K.flipFx(a, "HITSPARK_HEAVY_4x4", 4, seq(0, WHITE, 1, color), (4.5 + 0.7 * lv) * S, 16)
		K.flipFx(a, "FEATHER_2x2", 2, seq(0, WHITE, 1, V.GOLD), NS(0, 0.9 * S, 1, 0.6 * S), 40, { mode = "Random", n = 1 + lv, speed = { 8, 16 }, spread = 180, drag = 5, accel = Vector3.new(0, -3, 0), rotSpeed = { -90, 90 } })
		return 0
	end,
	-- téléportation : opts.from / opts.to (Vector3) ; 3 images fantômes sur le trajet
	Dash = function(char, dir, color, o)
		local hrp = hrpOf(char)
		local from = o.from or hrp.Position
		local to = o.to or (from + dir.Unit * 12)
		for i = 0, 2 do
			V.After(i * 2 * FR, function()
				local g = V.Ghost(char, WHITE, 12, V.GOLD)
				local off = (to - from) * (i / 3) - (hrp.Position - from)
				for _, part in g:GetChildren() do
					if part:IsA("BasePart") then
						part.CFrame = part.CFrame + off
					end
				end
			end)
		end
		local _, a = V.Host(CFrame.new(to), 1)
		V.After(6 * FR, function()
			K.coreFlash(a, 4, 6)
			K.ring(a, "RING_THIN", V.GOLD, 1, 7, 12)
		end)
	end,
}

---------------------------------------------------------------------------- API
C.Chars = CH
C.Names = {
	"KAI", "TARO", "ZEPHYR", "AKEMI", "RYUKEN", "SHIN", "DAICHA", "HIBECARES",
	"RAIJIN", "YUKINA", "VENOM", "GORAN", "ASTER", "HIBIKI", "KAZAN", "KUREN", "SYLVA", "ELIAN", "NOVA", "KUROEN",
	"ASURA", "KUROEN_SHIN",
}

local function get(name: string)
	return assert(CH[name], "perso inconnu : " .. tostring(name))
end

function C.Trail(name: string, base: Attachment, tip: Attachment, color: Color3?)
	local c = get(name)
	return c.Trail(base, tip, color or c.color)
end

function C.Impact(name: string, level: string, cf: CFrame, color: Color3?, opts: { [string]: any }?)
	local c = get(name)
	return compose(level, cf, color or c.color, opts, c.Impact)
end

function C.Dash(name: string, char: Model, dir: Vector3, color: Color3?, opts: { [string]: any }?)
	local c = get(name)
	return c.Dash(char, dir, color or c.color, opts or {})
end

--- arc visible d'un coup (persos qui en ont un) ; sinon slash commun à la couleur du perso
function C.Swing(name: string, cf: CFrame, color: Color3?, opts: { [string]: any }?)
	local c = get(name)
	local col = color or c.color
	if c.Swing then
		return c.Swing(cf, col, opts or {})
	end
	return V.Slash(cf, col, opts)
end

return C
