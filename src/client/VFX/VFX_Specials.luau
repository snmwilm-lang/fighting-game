--[[
	BREAKFRAMEZ — VFX_Specials (ModuleScript, côté CLIENT) — étape 3
	════════════════════════════════════════════════════════════════
	In the game: Wilhem's VFX pack (stages 1 to 3), adapted for Rojo: the IDs come from
	Shared.VfxConfig (EffectsController uses the pack only once they are uploaded), the meshes
	from ReplicatedStorage.VFX_Meshes (built by the server), the shake goes through the game's
	camera (V.ShakeHook).
	Auras (22 combattants), projectiles / compétences et passifs (20 persos jouables).
	Utilise VFX_Common et VFX_Chars (placer les trois dans ReplicatedStorage).

	AURA — S.Aura(nom, character, couleur?) -> { SetLevel(0..3), Destroy() }
	   0 = au repos, 1–3 = jauge. KAI passe aux flammes DBZ à 3 (« jauge pleine »).

	COMPÉTENCE (colonne « projectile ») — S.Skill(nom, args) -> { Hit(cf?), Destroy() }
	   args.part   : la Part du projectile créée par le jeu (son LookVector = sens du tir). Les VFX s'y accrochent.
	   args.char   : le lanceur ; args.target : la cible (Model) ; args.cf : point d'effet ; args.color : skin
	   Hit(cf) joue l'impact du perso (niveau args.level, « heavy » par défaut) puis nettoie.
	   Persos sans projectile qui vole : RYUKEN (ligne de roche le long du sol), GORAN (onde de l'étreinte),
	   SYLVA (piège de racines), HIBIKI (arcs en série), NOVA (drones qui tirent) — voir chaque entrée.

	PASSIF — S.Passive(nom, args) -> { Set(valeur), Trigger(...), Destroy() }
	   Set : état continu (charges, niveau de rage, vie…) ; Trigger : événement ponctuel (parade, pulsation…).

	Budgets : chaque aura reste sous ~40 particules vivantes au niveau 3 ; projectiles ≤ 40 par seconde.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local V = require(script.Parent.VFX_Common)
local C = require(script.Parent.VFX_Chars)
local K = V.Kit
local NS = V.NS
local FR = 1 / 60
local WHITE, BLACK = V.WHITE, Color3.new(0, 0, 0)

local S = {}

S.Tex = V.Tex -- (the IDs: Shared.VfxConfig)

---------------------------------------------------------------------------- outils
local function seq(...): ColorSequence
	local a = { ... }
	local k = {}
	for i = 1, #a, 2 do
		table.insert(k, ColorSequenceKeypoint.new(a[i], a[i + 1]))
	end
	return ColorSequence.new(k)
end
local function hot(c: Color3): ColorSequence
	return seq(0, WHITE, 0.25, c, 1, c)
end

local function hrpOf(char: Model): BasePart
	return assert(char:FindFirstChild("HumanoidRootPart"), "HumanoidRootPart manquant") :: BasePart
end

local function colorOf(name: string, c: Color3?): Color3
	return c or (C.Chars[name] and C.Chars[name].color) or V.Energy[name] or WHITE
end

--- Part invisible soudée au personnage (volume d'émission)
local function volume(char: Model, size: Vector3, offset: Vector3?): Part
	local hrp = hrpOf(char)
	local v = Instance.new("Part")
	v.Name = "BFZ_FxVolume"
	v.Size = size
	v.Transparency = 1
	v.CanCollide = false
	v.CanQuery = false
	v.CanTouch = false
	v.Massless = true
	v.CastShadow = false
	v.CFrame = hrp.CFrame * CFrame.new(offset or Vector3.zero)
	local w = Instance.new("WeldConstraint")
	w.Part0 = v
	w.Part1 = hrp
	w.Parent = v
	v.Parent = char
	return v
end

--- sprite plat toujours face caméra (BillboardGui) ; renvoie gui, image
local function sprite(adornee: Instance, tex: string, studs: number, color: Color3, offset: Vector3?): (BillboardGui, ImageLabel)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(studs, studs)
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false
	bb.Adornee = adornee
	bb.StudsOffsetWorldSpace = offset or Vector3.zero
	local im = Instance.new("ImageLabel")
	im.BackgroundTransparency = 1
	im.Size = UDim2.fromScale(1, 1)
	im.AnchorPoint = Vector2.new(0.5, 0.5)
	im.Position = UDim2.fromScale(0.5, 0.5)
	im.Image = V.Tex[tex] or tex
	im.ImageColor3 = color
	im.Parent = bb
	bb.Parent = adornee
	return bb, im
end

--- couche supplémentaire dans un BillboardGui existant
local function layer(bb: BillboardGui, tex: string, color: Color3, scale: number?, z: number?): ImageLabel
	local im = Instance.new("ImageLabel")
	im.BackgroundTransparency = 1
	im.AnchorPoint = Vector2.new(0.5, 0.5)
	im.Position = UDim2.fromScale(0.5, 0.5)
	im.Size = UDim2.fromScale(scale or 1, scale or 1)
	im.Image = V.Tex[tex] or tex
	im.ImageColor3 = color
	im.ZIndex = z or 1
	im.Parent = bb
	return im
end

--- sprites en orbite autour d'un point (BillboardGui) ; :SetCount(n) ; :Destroy()
local function orbit(adornee: BasePart, tex: string, color: Color3, maxN: number, radius: number, speed: number, studs: number, yAmp: number?, cell: { number }?)
	local guis = {}
	for i = 1, maxN do
		local bb, im = sprite(adornee, tex, studs, color)
		if cell then -- case d'une planche 2x2 (ex. DEBRIS_2x2)
			im.ImageRectSize = Vector2.new(cell[1], cell[1])
			im.ImageRectOffset = Vector2.new(((i - 1) % 2) * cell[1], (math.floor((i - 1) / 2) % 2) * cell[1])
		end
		bb.Enabled = false
		guis[i] = { bb = bb, im = im }
	end
	local count, t, alive = 0, 0, true
	local conn = RunService.Heartbeat:Connect(function(dt)
		t += dt
		for i, g in guis do
			if i <= count then
				local a = t * speed + (i - 1) * math.pi * 2 / math.max(count, 1)
				g.bb.StudsOffsetWorldSpace = Vector3.new(math.cos(a) * radius, (yAmp or 0.4) * math.sin(a * 1.7 + i), math.sin(a) * radius)
				g.im.Rotation = (t * 90 + i * 40) % 360
			end
		end
	end)
	local api = {}
	function api.SetCount(n: number)
		count = math.clamp(n, 0, maxN)
		for i, g in guis do
			g.bb.Enabled = i <= count
		end
	end
	function api.Destroy()
		if not alive then
			return
		end
		alive = false
		conn:Disconnect()
		for _, g in guis do
			g.bb:Destroy()
		end
	end
	return api
end

--- Highlight qui pulse (intensité 0..1 réglable)
local function pulseHL(adornee: Instance, color: Color3, freq: number, outline: Color3?)
	local h = Instance.new("Highlight")
	h.FillColor = color
	h.OutlineColor = outline or color
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = adornee
	h.FillTransparency = 1
	h.OutlineTransparency = 1
	h.Parent = adornee
	local amount, t = 0, 0
	local conn = RunService.Heartbeat:Connect(function(dt)
		t += dt
		local s = 0.5 + 0.5 * math.sin(t * freq * math.pi * 2)
		h.FillTransparency = 1 - amount * (0.15 + 0.35 * s)
		h.OutlineTransparency = 1 - amount * (0.4 + 0.6 * s)
	end)
	return {
		Set = function(a: number)
			amount = math.clamp(a, 0, 1)
		end,
		Destroy = function()
			conn:Disconnect()
			h:Destroy()
		end,
	}
end

--- éclairs qui sautent autour d'un volume ; :SetPeriod(sec ou nil = arrêt)
local function crackle(getCenter: () -> Vector3, size: Vector3, color: Color3, width: number)
	local period: number? = nil
	local alive = true
	task.spawn(function()
		while alive do
			if period then
				local c = getCenter()
				local p0 = c + Vector3.new((math.random() - 0.5) * size.X, (math.random() - 0.5) * size.Y, (math.random() - 0.5) * size.Z)
				local p1 = p0 + Vector3.new((math.random() - 0.5) * 3, (math.random() - 0.5) * 2, (math.random() - 0.5) * 2)
				V.Lightning(p0, p1, color, { segs = 4, dur = 6 * FR, jitter = 0.5, width = width, core = false })
				task.wait(period * (0.6 + math.random() * 0.8))
			else
				task.wait(0.1)
			end
		end
	end)
	return {
		SetPeriod = function(p: number?)
			period = p
		end,
		Destroy = function()
			alive = false
		end,
	}
end

--- attaches avant/arrière d'une Part de projectile (LookVector = sens du tir)
local function ends(part: BasePart, len: number?): (Attachment, Attachment, Attachment)
	local L = len or math.max(part.Size.Z, 2)
	local back, front, mid = Instance.new("Attachment"), Instance.new("Attachment"), Instance.new("Attachment")
	back.Position = Vector3.new(0, 0, L / 2)
	front.Position = Vector3.new(0, 0, -L / 2)
	back.Parent, front.Parent, mid.Parent = part, part, part
	return back, front, mid
end

local function weldMesh(part: BasePart, name: string, size: Vector3, setup: (MeshPart) -> (), offset: CFrame?): MeshPart
	local m = K.meshTemplate(name):Clone()
	m.Anchored = false
	m.CanCollide = false
	m.CanQuery = false
	m.CanTouch = false
	m.Massless = true
	m.CastShadow = false
	m.Size = size
	m.CFrame = part.CFrame * (offset or CFrame.new())
	setup(m)
	local w = Instance.new("WeldConstraint")
	w.Part0 = m
	w.Part1 = part
	w.Parent = m
	m.Parent = part
	return m
end

local function emitterOn(parent: Instance, p: { [string]: any }): ParticleEmitter
	local e = V.Emitter(parent, p)
	e.Enabled = (p.rate or 0) > 0
	return e
end

--- objet « compétence » générique : liste d'instances à nettoyer + impact
local function skillHandle(name: string, args: { [string]: any }, owned: { Instance }, extra: (() -> ())?)
	local api = {}
	local done = false
	function api.Destroy()
		if done then
			return
		end
		done = true
		if extra then
			extra()
		end
		for _, i in owned do
			if i:IsA("ParticleEmitter") or i:IsA("Trail") or i:IsA("Beam") then
				(i :: any).Enabled = false
				task.delay(1.2, function()
					i:Destroy()
				end)
			else
				i:Destroy()
			end
		end
	end
	function api.Hit(cf: CFrame?)
		local at = cf or (if args.part then (args.part :: BasePart).CFrame else nil)
		if at then
			C.Impact(name, args.level or "heavy", at, args.color, { hitstop = args.hitstop })
		end
		api.Destroy()
	end
	return api
end

---------------------------------------------------------------------------- AURAS
--[[ recette : liste de couches { p = paramètres d'émetteur, rates = {niveau0, 1, 2, 3}, vol = "body"|"feet"|"head" }
	extra(char, color, vol) -> { SetLevel(n), Destroy() } pour ce qui n'est pas une particule (orbites, éclairs, halo…) ]]
local function auraFrom(char: Model, layers, extra)
	local vols = {
		body = volume(char, Vector3.new(3, 5, 2)),
		feet = volume(char, Vector3.new(3, 0.4, 2), Vector3.new(0, -2.8, 0)),
		head = volume(char, Vector3.new(1, 0.2, 1), Vector3.new(0, 3.4, 0)),
	}
	local ems = {}
	for _, L in layers do
		local e = V.Emitter(vols[L.vol or "body"], L.p)
		e.Rate = 0
		e.Enabled = true
		table.insert(ems, { e = e, rates = L.rates })
	end
	local ex = extra and extra(vols) or nil
	local api = {}
	function api.SetLevel(n: number)
		local lv = math.clamp(math.floor(n), 0, 3)
		for _, x in ems do
			x.e.Rate = x.rates[lv + 1]
		end
		if ex then
			ex.SetLevel(lv)
		end
	end
	function api.Destroy()
		for _, x in ems do
			x.e.Enabled = false
		end
		if ex then
			ex.Destroy()
		end
		task.delay(1.5, function()
			for _, v in vols do
				v:Destroy()
			end
		end)
	end
	api.SetLevel(0)
	return api
end

local UP = Enum.NormalId.Top
local function rising(tex: string, color: any, size: number, extra: { [string]: any }?)
	local p = { tex = tex, color = color, size = NS(0, size, 1, 0), life = { 30, 50 }, speed = { 2, 5 }, dir = UP, spread = 15, accel = Vector3.new(0, 2, 0), br = 2.5, shape = Enum.ParticleEmitterShape.Box }
	for k, v in extra or {} do
		p[k] = v
	end
	return p
end
local function flames(tex: string, color: any, size: number, extra: { [string]: any }?)
	local p = { tex = tex, grid = 8, color = color, size = NS(0, size, 1, size * 1.35), life = { 22, 30 }, speed = { 3, 6 }, dir = UP, spread = 8, locked = true, tr = NS(0, 0.1, 1, 0.35), z = -1, shape = Enum.ParticleEmitterShape.Box }
	for k, v in extra or {} do
		p[k] = v
	end
	return p
end

local AURA = {}
AURA.KAI = function(char, c)
	return auraFrom(char, {
		{ p = rising("MOTE", hot(c), 0.35), rates = { 3, 6, 10, 14 } },
		{ p = flames("AURA_FLAME_8x8", seq(0, WHITE, 0.2, c, 1, c), 2.6), rates = { 0, 0, 0, 16 } },
	})
end
AURA.TARO = function(char, c)
	return auraFrom(char, {
		{ p = rising("EMBER", seq(0, Color3.fromHex("FFE14A"), 1, c), 0.35, { orient = "VelocityParallel" }), rates = { 3, 6, 10, 14 } },
		{ p = flames("FLAME_8x8", seq(0, Color3.fromHex("FFE14A"), 0.4, c, 1, c), 1.2, { locked = true }), rates = { 0, 3, 6, 9 }, vol = "head" },
	})
end
AURA.ZEPHYR = function(char, c)
	return auraFrom(char, {
		{ p = rising("MOTE", c, 0.25, { tr = NS(0, 0.4, 1, 1) }), rates = { 1, 2, 4, 6 } },
	}, function(v)
		local o = orbit(v.body, "ZEPHYR_WIND_LINE", c, 4, 2.2, 3, 3)
		return { SetLevel = function(l) o.SetCount(l + 1) end, Destroy = o.Destroy }
	end)
end
AURA.AKEMI = function(char, c)
	return auraFrom(char, {
		{ p = rising("WISP_4x4", BLACK, 1.6, { grid = 4, le = 0, br = 1, size = NS(0, 1.2, 1, 2), tr = NS(0, 0.2, 1, 0.7) }), rates = { 2, 4, 6, 9 } },
		{ p = rising("MOTE", c, 0.25), rates = { 1, 2, 3, 5 } },
	})
end
AURA.RYUKEN = function(char, c)
	return auraFrom(char, {
		{ p = rising("WISP_4x4", Color3.fromHex("B8B4B0"), 1.6, { grid = 4, le = 0, br = 1, size = NS(0, 1.2, 1, 2.4), tr = NS(0, 0.3, 1, 0.8) }), rates = { 2, 4, 7, 10 } },
	})
end
AURA.SHIN = function(char, c)
	return auraFrom(char, {
		{ p = { tex = "DROPLET", color = hot(c), size = NS(0, 0.3, 1, 0.15), life = { 20, 30 }, speed = { 0, 1 }, accel = Vector3.new(0, -30, 0), orient = "VelocityParallel", shape = Enum.ParticleEmitterShape.Box }, rates = { 1, 2, 3, 5 } },
		{ p = { tex = "SHIN_RIPPLE_4x4", grid = 4, color = c, size = NS(0, 1.5, 1, 4), life = 30, speed = { 0.01 }, dir = UP, orient = "VelocityPerpendicular", shape = Enum.ParticleEmitterShape.Box }, rates = { 0.5, 1, 1.5, 2.5 }, vol = "feet" },
	})
end
AURA.DAICHA = function(char, c)
	return auraFrom(char, {
		{ p = rising("MOTE", c, 0.3), rates = { 1, 2, 3, 4 } },
	}, function(v)
		local o = orbit(v.body, "GLOW_CORE", Color3.fromHex("2A1040"), 6, 2, 2.2, 0.8, 1.2)
		return { SetLevel = function(l) o.SetCount(3 + l) end, Destroy = o.Destroy }
	end)
end
AURA.HIBECARES = function(char, c)
	return auraFrom(char, {
		{ p = rising("EMBER", seq(0, Color3.fromHex("FFE0A0"), 1, c), 0.3, { orient = "VelocityParallel" }), rates = { 0, 2, 4, 7 } },
	}, function(v)
		local o = orbit(v.body, "DEBRIS_2x2", Color3.fromHex("8C7F74"), 6, 2.4, 0.8, 0.9, 1.5, { 256 })
		return { SetLevel = function(l) o.SetCount(2 + l) end, Destroy = o.Destroy }
	end)
end
AURA.RAIJIN = function(char, c)
	return auraFrom(char, {
		{ p = rising("STREAK_V", hot(c), 0.4, { orient = "VelocityParallel", life = { 6, 12 } }), rates = { 1, 3, 6, 10 } },
	}, function(v)
		local cr = crackle(function() return v.body.Position end, Vector3.new(3, 5, 2), c, 0.15)
		local periods = { 0.7, 0.4, 0.25, 0.12 }
		return { SetLevel = function(l) cr.SetPeriod(periods[l + 1]) end, Destroy = cr.Destroy }
	end)
end
AURA.YUKINA = function(char, c)
	return auraFrom(char, {
		{ p = { tex = "SNOWFLAKE_2x2", grid = 2, mode = "Random", color = WHITE, size = NS(0, 0.5, 1, 0), life = { 40, 60 }, speed = { 0.5, 1.5 }, spread = 180, accel = Vector3.new(0, -1.5, 0), rot = { 0, 360 }, rotSpeed = { -60, 60 }, shape = Enum.ParticleEmitterShape.Box }, rates = { 2, 4, 6, 9 } },
		{ p = rising("MOTE", c, 0.25), rates = { 0, 2, 3, 5 } },
	})
end
AURA.VENOM = function(char, c)
	return auraFrom(char, {
		{ p = rising("BUBBLE", c, 0.6, { size = NS(0, 0.3, 0.8, 0.6, 1, 0.8), tr = NS(0, 0, 0.9, 0, 1, 1) }), rates = { 2, 4, 6, 8 } },
		{ p = rising("WISP_4x4", c, 1.4, { grid = 4, le = 0, br = 1, size = NS(0, 1, 1, 2), tr = NS(0, 0.4, 1, 0.85) }), rates = { 1, 2, 3, 5 } },
	})
end
AURA.GORAN = function(char, c)
	return auraFrom(char, {
		{ p = { tex = "PUFF_2x2", grid = 2, color = V.DUST, le = 0, br = 1, size = NS(0, 1.2, 1, 2.4), life = { 20, 30 }, speed = { 1, 3 }, spread = 70, dir = UP, rot = { 0, 360 }, shape = Enum.ParticleEmitterShape.Box }, rates = { 1, 2, 3, 5 }, vol = "feet" },
		{ p = rising("MOTE", c, 0.25), rates = { 0, 1, 2, 4 } },
	})
end
AURA.ASTER = function(char, c)
	return auraFrom(char, {
		{ p = rising("MOTE", c, 0.2), rates = { 1, 2, 3, 4 } },
	}, function(v)
		local o = orbit(v.body, "STAR4", c, 6, 2.2, 1.6, 0.9, 1.4)
		local counts = { 2, 3, 4, 6 }
		return { SetLevel = function(l) o.SetCount(counts[l + 1]) end, Destroy = o.Destroy }
	end)
end
AURA.HIBIKI = function(char, c)
	return auraFrom(char, {
		{ p = rising("NOTE_2x2", hot(c), 0.9, { grid = 2, mode = "Random", size = NS(0, 0.9, 1, 0.5), rot = { -20, 20 } }), rates = { 1, 2, 3, 4 } },
	}, function(v)
		local level, alive = 0, true
		task.spawn(function() -- anneau sur chaque temps (120 bpm)
			while alive do
				task.wait(0.5)
				if alive and level > 0 then
					local _, a = V.Host(v.feet.CFrame * CFrame.Angles(math.rad(90), 0, 0), 1)
					K.ring(a, "RING_THIN", c, 1.5, 4 + level, 14, { orient = "VelocityPerpendicular" })
				end
			end
		end)
		return { SetLevel = function(l) level = l end, Destroy = function() alive = false end }
	end)
end
AURA.KAZAN = function(char, c)
	return auraFrom(char, {
		{ p = { tex = "STREAK_V", color = hot(c), size = NS(0, 0.35, 1, 0), life = { 6, 12 }, speed = { 6, 14 }, spread = 70, dir = UP, accel = Vector3.new(0, -40, 0), orient = "VelocityParallel", shape = Enum.ParticleEmitterShape.Box }, rates = { 2, 5, 8, 12 } },
	})
end
AURA.KUREN = function(char, c)
	return auraFrom(char, {
		{ p = { tex = "DROPLET", color = hot(c), size = NS(0, 0.3, 1, 0.15), life = { 20, 30 }, speed = { 0, 1 }, accel = Vector3.new(0, -25, 0), orient = "VelocityParallel", shape = Enum.ParticleEmitterShape.Box }, rates = { 1, 2, 3, 5 } },
		{ p = rising("PETAL_2x2", c, 0.6, { grid = 2, mode = "Random", rot = { 0, 360 }, rotSpeed = { -120, 120 }, accel = Vector3.new(0, 0.5, 0) }), rates = { 1, 2, 4, 6 } },
	})
end
AURA.SYLVA = function(char, c)
	return auraFrom(char, {
		{ p = { tex = "LEAF_2x2", grid = 2, mode = "Random", color = c, le = 0.5, size = NS(0, 0.6, 1, 0.3), life = { 40, 60 }, speed = { 0.5, 2 }, spread = 180, accel = Vector3.new(0, -1, 0), rot = { 0, 360 }, rotSpeed = { -90, 90 }, shape = Enum.ParticleEmitterShape.Box }, rates = { 1, 2, 4, 6 } },
	})
end
AURA.ELIAN = function(char, c)
	return auraFrom(char, {
		{ p = rising("MOTE", hot(c), 0.3), rates = { 2, 5, 8, 12 } },
	}, function(v)
		local bb, im = sprite(v.head, "RING_THIN", 1.6, c, Vector3.new(0, 0.6, 0))
		bb.Size = UDim2.fromScale(1.8, 0.6) -- halo vu légèrement de côté
		return { SetLevel = function(l) im.ImageTransparency = 0.3 - 0.1 * l end, Destroy = function() bb:Destroy() end }
	end)
end
AURA.NOVA = function(char, c)
	return auraFrom(char, {
		{ p = { tex = "NOVA_HOLO_LINES", color = Color3.fromHex("6FE0FF"), size = NS(0, 2.5, 1, 2.5), life = { 10, 16 }, tr = NS(0, 0.5, 0.5, 0.3, 1, 1), locked = true, shape = Enum.ParticleEmitterShape.Box }, rates = { 1, 2, 3, 5 } },
		{ p = rising("PIXEL_2x2", Color3.fromHex("6FE0FF"), 0.4, { grid = 2, mode = "Random", life = { 10, 18 } }), rates = { 0, 1, 2, 4 } },
	})
end
AURA.KUROEN = function(char, c)
	return auraFrom(char, {
		{ p = flames("KUROEN_BLACK_FLAME_8x8", c, 2.2, { le = 0, br = 1 }), rates = { 2, 5, 9, 14 } },
	})
end
AURA.ASURA = function(char, c)
	return auraFrom(char, {
		{ p = flames("FLAME_8x8", seq(0, WHITE, 0.3, c, 1, c), 2.4), rates = { 3, 6, 10, 14 } },
	})
end
AURA.KUROEN_SHIN = function(char, c)
	return auraFrom(char, {
		{ p = flames("FLAME_8x8", seq(0, WHITE, 0.6, Color3.fromHex("FFF4D6"), 1, V.GOLD), 2.4), rates = { 3, 6, 10, 14 } },
		{ p = rising("MOTE", V.GOLD, 0.3), rates = { 2, 4, 6, 8 } },
	})
end

---------------------------------------------------------------------------- COMPÉTENCES
local SKILL = {}

-- KAI — KIKOHO : boule 3D (cœur blanc, coque, 3 boucles de ki qui tournent, étincelles, queue de comète à 2 brins)
-- args.part ; args.charge (s, défaut 0.3) : la boule naît entre les paumes et grossit
SKILL.KAI = function(a, c)
	local part = a.part :: BasePart
	local size = a.size or 3
	local bb, shell = sprite(part, "GLOW_CORE", size, c)
	local core = layer(bb, "GLOW_CORE", WHITE, 0.55, 3)
	local loops = {}
	for i = 1, 3 do
		loops[i] = layer(bb, "RING_THIN", c, 1.25, 2)
	end
	local _, _, mid = ends(part)
	local sp = emitterOn(mid, { tex = "STREAK_V", color = hot(c), size = NS(0, 0.5, 1, 0), life = { 6, 12 }, speed = { 8, 16 }, spread = 180, drag = 6, rate = 30, orient = "VelocityParallel" })
	local t1, t2 = Instance.new("Attachment"), Instance.new("Attachment")
	local t3, t4 = Instance.new("Attachment"), Instance.new("Attachment")
	t1.Position, t2.Position = Vector3.new(0, 0.5, 0), Vector3.new(0, 0.1, 0)
	t3.Position, t4.Position = Vector3.new(0, -0.1, 0), Vector3.new(0, -0.5, 0)
	for _, x in { t1, t2, t3, t4 } do
		x.Parent = part
	end
	local tails = {}
	for _, pair in { { t1, t2 }, { t3, t4 } } do
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1 = pair[1], pair[2]
		tr.Texture = V.Tex.TRAIL_WISPY
		tr.Color = hot(c)
		tr.LightEmission, tr.LightInfluence, tr.Lifetime = 1, 0, 0.3
		tr.Transparency = NS(0, 0, 1, 1)
		tr.FaceCamera = true
		tr.Parent = part
		table.insert(tails, tr)
	end
	local charge = a.charge or 0.3
	local alive = true
	local t = 0
	local conn = RunService.Heartbeat:Connect(function(dt)
		t += dt
		local g = math.min(t / charge, 1)
		local s = size * (0.15 + 0.85 * (1 - (1 - g) ^ 2)) * (1 + 0.05 * math.sin(t * 30))
		bb.Size = UDim2.fromScale(s, s)
		for i, l in loops do
			l.Rotation = t * 300 + i * 60
			l.Size = UDim2.fromScale(1.25, 0.35 + 0.1 * math.sin(t * 9 + i))
		end
		core.Size = UDim2.fromScale(0.55 + 0.05 * math.sin(t * 40), 0.55 + 0.05 * math.sin(t * 40))
	end)
	return skillHandle("KAI", a, { bb, sp, tails[1], tails[2], t1, t2, t3, t4 }, function()
		alive = false
		conn:Disconnect()
	end)
end

-- TARO — boule de feu à fumée sombre
SKILL.TARO = function(a, c)
	local part = a.part :: BasePart
	local bb = sprite(part, "GLOW_CORE", 2.6, c)
	layer(bb, "GLOW_CORE", Color3.fromHex("FFE14A"), 0.55, 2)
	local _, _, mid = ends(part)
	local fl = emitterOn(mid, { tex = "FLAME_8x8", grid = 8, color = seq(0, Color3.fromHex("FFE14A"), 0.4, c, 1, c), size = NS(0, 2.2, 1, 1.2), life = { 10, 16 }, speed = { 1, 3 }, spread = 180, rate = 22, locked = true, rot = { 0, 360 } })
	local sm = emitterOn(mid, { tex = "SMOKE_CEL_8x8", grid = 8, color = Color3.fromHex("2A1A14"), le = 0, br = 1, size = NS(0, 1.2, 1, 2.6), life = { 20, 30 }, speed = { 0.5, 1.5 }, spread = 180, rate = 14, rot = { 0, 360 }, z = -1 })
	return skillHandle("TARO", a, { bb, fl, sm })
end

-- ZEPHYR — WIND BLADE : lame en croissant
SKILL.ZEPHYR = function(a, c)
	local part = a.part :: BasePart
	local blade = weldMesh(part, "CRESCENT_BLADE", Vector3.new(4, 0.3, 1.8) * (a.scale or 1), function(m)
		m.Material = Enum.Material.ForceField
		m.TextureID = V.Tex.ZEPHYR_AIR_CRESCENT
		m.Color = c
	end, CFrame.Angles(0, 0, math.rad(90))) -- lame dressée face à la caméra (jeu vu de côté)
	local back, front = ends(part)
	local wl = emitterOn(back, { tex = "ZEPHYR_WIND_LINE", color = c, size = NS(0, 2, 1, 3), life = { 10, 16 }, speed = { 1, 3 }, spread = 30, rate = 12, tr = NS(0, 0.35, 1, 1) })
	return skillHandle("ZEPHYR", a, { blade, wl })
end

-- AKEMI — KUNAI : kunai avec reflet
SKILL.AKEMI = function(a, c)
	local part = a.part :: BasePart
	local back, front = ends(part, 2.4)
	local b = V.Beam(part, back, front, { tex = "AKEMI_KUNAI", color = Color3.fromHex("D8D8E8"), w = 0.7, le = 0.2, br = 1.5 })
	local gl = emitterOn(front, { tex = "GLINT", color = WHITE, size = NS(0, 1.4, 1, 0), life = 8, rate = 5, br = 4 })
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = back, front
	tr.Texture = V.Tex.TRAIL_RIM
	tr.Color = ColorSequence.new(c)
	tr.Lifetime, tr.LightEmission, tr.LightInfluence = 0.1, 1, 0
	tr.FaceCamera = true
	tr.Parent = part
	return skillHandle("AKEMI", a, { b, gl, tr })
end

-- RYUKEN — SEISMIC STRIKE : ligne de roche qui jaillit le long du sol (args.cf = départ, LookVector = direction ; args.length, args.speed)
SKILL.RYUKEN = function(a, c)
	local cf = a.cf :: CFrame
	local len, speed = a.length or 28, a.speed or 70
	local n = math.floor(len / 2.2)
	local alive = true
	local owned = {}
	for i = 1, n do
		V.After(i * 2.2 / speed, function()
			if not alive then
				return
			end
			local pos = cf.Position + cf.LookVector * (i * 2.2)
			local gp = V.GroundBelow(pos) or pos
			local m = K.meshTemplate("SPIKE"):Clone()
			m.Anchored, m.CanCollide, m.CanQuery, m.CanTouch, m.CastShadow = true, false, false, false, false
			m.Material = Enum.Material.Slate
			m.Color = Color3.fromHex("5A4A44")
			local h = 2.5 + math.random() * 1.8 + i * 0.05
			local tilt = CFrame.Angles(math.rad(math.random(-15, 15)), 0, math.rad(math.random(-15, 15)))
			m.Parent = K.folder()
			V.Animate(0.7, function(k)
				local up = if k < 0.15 then k / 0.15 else (if k > 0.7 then 1 - (k - 0.7) / 0.3 else 1)
				m.Size = Vector3.new(1.4, h * up + 0.05, 1.4)
				m.CFrame = CFrame.new(gp + Vector3.new(0, (h * up) / 2 - 0.3, 0)) * tilt
			end, function()
				m:Destroy()
			end)
			V.Mark(CFrame.new(gp), 3.5, "CRACK_2x2", c, math.random(0, 2), 0.3, 0.8, true)
			K.dustAt(CFrame.new(gp), 1, 4)
		end)
	end
	return skillHandle("RYUKEN", a, owned, function()
		alive = false
	end)
end

-- SHIN — CUTTING CURRENT : croissant d'eau
SKILL.SHIN = function(a, c)
	local part = a.part :: BasePart
	local blade = weldMesh(part, "CRESCENT_BLADE", Vector3.new(4.4, 0.3, 2) * (a.scale or 1), function(m)
		m.Material = Enum.Material.ForceField
		m.TextureID = V.Tex.SHIN_WATER_RIBBON
		m.Color = c
	end, CFrame.Angles(0, 0, math.rad(90)))
	local back = ends(part)
	local d = emitterOn(back, { tex = "DROPLET", color = hot(c), size = NS(0, 0.35, 1, 0.15), life = { 14, 22 }, speed = { 2, 6 }, spread = 60, accel = Vector3.new(0, -40, 0), rate = 30, orient = "VelocityParallel" })
	return skillHandle("SHIN", a, { blade, d })
end

-- DAICHA — INVERTED SPHERE : sphère noire, anneau de distorsion
SKILL.DAICHA = function(a, c)
	local part = a.part :: BasePart
	local sz = a.size or 3
	local sph = weldMesh(part, "SPHERE", Vector3.one * sz, function(m)
		m.Material = Enum.Material.SmoothPlastic
		m.Color = BLACK
	end)
	local hl = Instance.new("Highlight")
	hl.FillTransparency, hl.OutlineColor, hl.OutlineTransparency = 1, c, 0
	hl.Adornee = sph
	hl.Parent = sph
	local bb, ring = sprite(part, "DISTORT_RING", sz * 1.9, WHITE)
	ring.ImageTransparency = 0.5
	local fx = weldMesh(part, "SPHERE", Vector3.one * sz * 2.4, function(m)
		m.Transparency = 1
	end)
	local inward = emitterOn(fx, { tex = "MOTE", color = c, size = NS(0, 0.4, 1, 0.1), life = 10, speed = { 10 }, rate = 25, shape = Enum.ParticleEmitterShape.Sphere, shapeStyle = Enum.ParticleEmitterShapeStyle.Surface, inward = true })
	local t, conn = 0, nil
	conn = RunService.Heartbeat:Connect(function(dt)
		t += dt
		ring.Rotation = t * 120
		local s = 1 + 0.08 * math.sin(t * 12)
		ring.Size = UDim2.fromScale(s, s)
	end)
	return skillHandle("DAICHA", a, { sph, bb, fx, inward }, function()
		conn:Disconnect()
	end)
end

-- HIBECARES — rocher lancé
SKILL.HIBECARES = function(a, c)
	local part = a.part :: BasePart
	local sz = a.size or 2.6
	local rock = weldMesh(part, "ROCK_A", Vector3.one * sz, function(m)
		m.Material = Enum.Material.Slate
		m.Color = Color3.fromHex("6E625A")
	end)
	local back, _, mid = ends(part)
	local dust = emitterOn(back, { tex = "PUFF_2x2", grid = 2, color = V.DUST, le = 0, br = 1, size = NS(0, 1, 1, 2), life = { 14, 20 }, speed = { 0.5, 2 }, spread = 60, rate = 20, rot = { 0, 360 } })
	local emb = emitterOn(mid, { tex = "EMBER", color = seq(0, Color3.fromHex("FFE0A0"), 1, c), size = NS(0, 0.35, 1, 0), life = { 10, 18 }, speed = { 2, 6 }, spread = 180, rate = 15, orient = "VelocityParallel" })
	return skillHandle("HIBECARES", a, { rock, dust, emb })
end

-- RAIJIN — LIGHTNING SPEAR : lance de lumière entourée d'éclairs
SKILL.RAIJIN = function(a, c)
	local part = a.part :: BasePart
	local back, front, mid = ends(part, a.length or 6)
	local glow = V.Beam(part, back, front, { tex = "RAIJIN_SPEAR", color = c, w = 2.2, br = 3 })
	local core = V.Beam(part, back, front, { tex = "RAIJIN_SPEAR", color = WHITE, w = 1.2, br = 4, z = 1 })
	local alive = true
	task.spawn(function()
		while alive do
			V.Lightning(back, front, c, { segs = 6, dur = 6 * FR, jitter = 0.9, width = 0.22, core = false })
			task.wait(0.08)
		end
	end)
	local sp = emitterOn(mid, { tex = "STREAK_V", color = hot(c), size = NS(0, 0.4, 1, 0), life = { 6, 10 }, speed = { 6, 14 }, spread = 180, rate = 25, orient = "VelocityParallel" })
	return skillHandle("RAIJIN", a, { glow, core, sp, back, front, mid }, function()
		alive = false
	end)
end

-- YUKINA — ICE SHARDS : 3 éclats
SKILL.YUKINA = function(a, c)
	local part = a.part :: BasePart
	local owned = {}
	for i, off in { CFrame.new(0, 0.9, 0.6), CFrame.new(0, 0, -0.4), CFrame.new(0, -0.9, 0.6) } do
		local m = weldMesh(part, ({ "ICE_SHARD_A", "ICE_SHARD_B", "ICE_SHARD_C" })[i], Vector3.new(0.55, 2.2, 0.55), function(mm)
			mm.Material = Enum.Material.Glass
			mm.Transparency = 0.15
			mm.Color = c
		end, off * CFrame.Angles(math.rad(-90), 0, 0))
		table.insert(owned, m)
	end
	local back = ends(part)
	table.insert(owned, emitterOn(back, { tex = "SNOWFLAKE_2x2", grid = 2, mode = "Random", color = WHITE, size = NS(0, 0.5, 1, 0), life = { 16, 26 }, speed = { 0.5, 2 }, spread = 180, rate = 25, rot = { 0, 360 } }))
	return skillHandle("YUKINA", a, owned)
end

-- VENOM — TOXIC MIST : nuage lent
SKILL.VENOM = function(a, c)
	local part = a.part :: BasePart
	local _, _, mid = ends(part)
	local cloud = emitterOn(mid, { tex = "SMOKE_CEL_8x8", grid = 8, color = Color3.fromHex("4FA02A"), le = 0, br = 1, size = NS(0, 4, 1, 7), life = { 50, 70 }, speed = { 0.5, 1.5 }, spread = 180, rate = 12, rot = { 0, 360 }, rotSpeed = { -15, 15 }, tr = NS(0, 0.3, 1, 1) })
	local bub = emitterOn(mid, { tex = "BUBBLE", color = c, size = NS(0, 0.4, 0.8, 0.8, 1, 1), tr = NS(0, 0, 0.9, 0, 1, 1), life = { 30, 50 }, speed = { 1, 3 }, spread = 180, rate = 6 })
	return skillHandle("VENOM", a, { cloud, bub })
end

-- GORAN — TITAN'S HUG : onde de l'étreinte (args.target)
SKILL.GORAN = function(a, c)
	local hrp = hrpOf(a.target)
	local _, at = V.Host(hrp.CFrame, 2)
	K.ring(at, "RING_SOFT", c, 14, 3, 14)
	V.After(14 * FR, function()
		V.Hitstop(8)
		K.ring(at, "RING_SOFT", c, 3, 18, 18)
		K.ring(at, "RING_THIN", WHITE, 2, 14, 14)
		K.coreFlash(at, 5, 6)
		K.sparks(at, c, 16, 60, 1.8, 180)
		K.dustAt(V.FeetCF(a.target), 2, 7)
		V.Shake(0.5, 12)
	end)
	return skillHandle("GORAN", a, {})
end

-- ASTER — PULL : sphère noire + disque d'accrétion (args.part ou args.cf)
SKILL.ASTER = function(a, c)
	local part = a.part or (V.Host(a.cf, a.duration or 2))
	local sz = a.size or 2.4
	local bb, disk = sprite(part, "ASTER_ACCRETION", sz * 3, c)
	local hole = layer(bb, "GLOW_CORE", BLACK, 0.32, 2)
	local fx = weldMesh(part, "SPHERE", Vector3.one * sz * 4, function(m)
		m.Transparency = 1
	end)
	local stars = emitterOn(fx, { tex = "STAR4", color = hot(c), size = NS(0, 0.5, 1, 0.1), life = 14, speed = { 12 }, rate = 20, shape = Enum.ParticleEmitterShape.Sphere, shapeStyle = Enum.ParticleEmitterShapeStyle.Surface, inward = true })
	local t, conn = 0, nil
	conn = RunService.Heartbeat:Connect(function(dt)
		t += dt
		disk.Rotation = -t * 160
		disk.Size = UDim2.fromScale(1, 0.55)
	end)
	return skillHandle("ASTER", a, { bb, fx, stars }, function()
		conn:Disconnect()
	end)
end

-- HIBIKI — SONIC WAVE : arcs en série (args.cf = départ, LookVector = direction ; args.count, args.range)
SKILL.HIBIKI = function(a, c)
	local cf = a.cf :: CFrame
	local _, at = V.Host(cf, 2)
	local e = V.Emitter(at, { tex = "HIBIKI_SOUND_ARC", color = hot(c), size = NS(0, 2.5, 1, 5), life = { 24, 24 }, speed = { (a.range or 30) / 0.4 }, tr = NS(0, 0, 0.7, 0.2, 1, 1), br = 3, rot = { 0, 0 } })
	for i = 0, (a.count or 5) - 1 do
		V.After(i * 4 * FR, function()
			V.Emit(e, 1)
		end)
	end
	return skillHandle("HIBIKI", a, {})
end

-- KAZAN — SHACKLE HOOK : crochet + chaîne (args.part, args.from = Attachment de la main)
SKILL.KAZAN = function(a, c)
	local part = a.part :: BasePart
	local back, front = ends(part, 2)
	local hook = V.Beam(part, back, front, { tex = "KAZAN_HOOK", color = Color3.fromHex("D0D0D8"), w = 1.6, le = 0.3, br = 1.5 })
	local chain = if a.from then V.Beam(part, a.from, back, { tex = "CHAIN", color = Color3.fromHex("C8C8D0"), w = 0.7, mode = Enum.TextureMode.Wrap, tlen = 1.6, le = 0.3, br = 1.5 }) else nil
	local sp = emitterOn(front, { tex = "STREAK_V", color = hot(c), size = NS(0, 0.35, 1, 0), life = { 6, 10 }, speed = { 6, 12 }, spread = 90, rate = 15, orient = "VelocityParallel" })
	local owned: { Instance } = { hook, sp, back, front }
	if chain then
		table.insert(owned, chain)
	end
	return skillHandle("KAZAN", a, owned)
end

-- KUREN — BLOOD LANCE : lance de cristal
SKILL.KUREN = function(a, c)
	local part = a.part :: BasePart
	local back, front, mid = ends(part, a.length or 5)
	local lance = V.Beam(part, back, front, { tex = "KUREN_CRYSTAL_LANCE", color = c, w = 1.6, br = 3 })
	local petals = emitterOn(back, { tex = "PETAL_2x2", grid = 2, mode = "Random", color = c, size = NS(0, 0.5, 1, 0.2), life = { 20, 30 }, speed = { 1, 3 }, spread = 90, rate = 18, rot = { 0, 360 }, rotSpeed = { -200, 200 } })
	local drops = emitterOn(mid, { tex = "DROPLET", color = hot(c), size = NS(0, 0.3, 1, 0.1), life = { 14, 20 }, speed = { 1, 4 }, spread = 120, accel = Vector3.new(0, -30, 0), rate = 15, orient = "VelocityParallel" })
	return skillHandle("KUREN", a, { lance, petals, drops, back, front, mid })
end

-- SYLVA — HUNGRY ROOTS : piège de racines (args.cf = centre du piège)
SKILL.SYLVA = function(a, c)
	local center = (a.cf :: CFrame).Position
	local gp = V.GroundBelow(center) or center
	local owned = {}
	for i = 1, 6 do
		local ang = i * math.pi * 2 / 6
		local base = gp + Vector3.new(math.cos(ang), 0, math.sin(ang)) * 2.6
		local m = K.meshTemplate("ROOT"):Clone()
		m.Anchored, m.CanCollide, m.CanQuery, m.CanTouch, m.CastShadow = true, false, false, false, false
		m.Material = Enum.Material.Wood
		m.Color = Color3.fromHex("4A3A24")
		m.Parent = K.folder()
		table.insert(owned, m)
		V.Animate(a.duration or 1.6, function(k)
			local grow = math.min(k / 0.2, 1)
			local lean = math.min(math.max((k - 0.2) / 0.2, 0), 1)
			local h = 4.5 * grow
			m.Size = Vector3.new(1, h + 0.05, 1)
			-- la racine pousse puis se penche vers le centre du piège
			m.CFrame = CFrame.lookAt(base, Vector3.new(gp.X, base.Y, gp.Z)) * CFrame.Angles(math.rad(-35 * lean), 0, 0) * CFrame.new(0, h / 2, 0)
		end)
	end
	V.Mark(CFrame.new(gp), 8, "SYLVA_GRASS_RING", c, nil, (a.duration or 1.6) - 0.5, 0.5, false)
	local _, at = V.Host(CFrame.new(gp + Vector3.new(0, 1, 0)), 2)
	K.flipFx(at, "LEAF_2x2", 2, c, NS(0, 0.7, 1, 0.3), 40, { mode = "Random", n = 10, speed = { 8, 16 }, spread = 70, dir = Enum.NormalId.Top, le = 0.5, accel = Vector3.new(0, -8, 0), rotSpeed = { -200, 200 } })
	return skillHandle("SYLVA", a, owned)
end

-- ELIAN — RAY : orbe de lumière à rayons
SKILL.ELIAN = function(a, c)
	local part = a.part :: BasePart
	local bb, rays = sprite(part, "ELIAN_RAY_ORB", a.size or 4, c)
	layer(bb, "GLOW_CORE", WHITE, 0.4, 2)
	local back = ends(part)
	local m = emitterOn(back, { tex = "MOTE", color = hot(c), size = NS(0, 0.4, 1, 0), life = { 16, 26 }, speed = { 0.5, 2 }, spread = 180, rate = 25 })
	local t, conn = 0, nil
	conn = RunService.Heartbeat:Connect(function(dt)
		t += dt
		rays.Rotation = t * 45
	end)
	return skillHandle("ELIAN", a, { bb, m }, function()
		conn:Disconnect()
	end)
end

-- NOVA — DRONE SHOT : drones qui tirent des lasers (args.char, args.target ou args.cf ; args.count = 2)
SKILL.NOVA = function(a, c)
	local hrp = hrpOf(a.char)
	local cyan = Color3.fromHex("6FE0FF")
	local owned = {}
	local n = a.count or 2
	for i = 1, n do
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Transparency = true, false, false, false, 1
		p.Size = Vector3.one * 0.2
		p.Parent = K.folder()
		table.insert(owned, p)
		local bb = sprite(p, "NOVA_DRONE", 2.2, WHITE)
		local off = Vector3.new(-1.5 + 3 * (i - 1) / math.max(n - 1, 1), 4.5 + (i % 2) * 0.6, 0)
		local fire = 0.25 + (i - 1) * 0.12
		local fired = false
		V.Animate(a.duration or 1.2, function(k, t)
			p.CFrame = CFrame.new(hrp.Position + off + Vector3.new(0, 0.2 * math.sin(t * 10 + i), 0))
			if not fired and t >= fire then
				fired = true
				local tgt = if a.target then hrpOf(a.target).Position else (a.cf :: CFrame).Position
				local _, a0 = V.Host(p.CFrame, 0.3)
				local _, a1 = V.Host(CFrame.new(tgt), 0.3)
				local beam = V.Beam(a0.Parent :: Instance, a0, a1, { color = cyan, w = 0.35, br = 5 })
				local core = V.Beam(a0.Parent :: Instance, a0, a1, { color = WHITE, w = 0.12, br = 5, z = 1 })
				V.Animate(8 * FR, function(kk)
					beam.Width0, beam.Width1 = 0.35 * (1 - kk), 0.35 * (1 - kk)
					core.Width0, core.Width1 = 0.12 * (1 - kk), 0.12 * (1 - kk)
				end)
				K.flipFx(a1, "PIXEL_2x2", 2, cyan, 1.6, 8, { mode = "Random" })
				K.coreFlash(a1, 1.4, 4)
			end
			bb.Enabled = k < 0.9
		end, function()
			p:Destroy()
		end)
	end
	return skillHandle("NOVA", a, {})
end

-- KUROEN — ECLIPSE BREAKER : disque d'éclipse
SKILL.KUROEN = function(a, c)
	local part = a.part :: BasePart
	local sz = a.size or 4
	local bb, corona = sprite(part, "KUROEN_CORONA", sz * 1.6, c)
	local disk = layer(bb, "GLOW_CORE", BLACK, 0.62, 2)
	local back = ends(part)
	local fl = emitterOn(back, { tex = "KUROEN_BLACK_FLAME_8x8", grid = 8, color = c, le = 0, br = 1, size = NS(0, 1.6, 1, 0.8), life = { 12, 18 }, speed = { 1, 3 }, spread = 90, rate = 20, rot = { -90, -90 } })
	local t, conn = 0, nil
	conn = RunService.Heartbeat:Connect(function(dt)
		t += dt
		corona.Rotation = t * 70
	end)
	local _ = disk
	return skillHandle("KUROEN", a, { bb, fl }, function()
		conn:Disconnect()
	end)
end

---------------------------------------------------------------------------- PASSIFS
local PASSIVE = {}

local function handle(set, trigger, destroy)
	return { Set = set or function() end, Trigger = trigger or function() end, Destroy = destroy or function() end }
end

-- KAI — RESOLVE : parade rouge et blanc ; Trigger(cf)
PASSIVE.KAI = function(a, c)
	return handle(nil, function(cf: CFrame)
		local _, at = V.Host(cf, 1)
		V.Hitstop(6)
		K.flipFx(at, "GLINT", nil :: any, WHITE, NS(0, 7, 0.4, 6, 1, 0), 14, { rot = { 0, 0 }, br = 4 })
		K.ring(at, "RING_THIN", c, 1, 9, 12, { br = 4 })
		K.ring(at, "RING_THIN", WHITE, 1, 6, 10, { br = 4 })
		K.flipFx(at, "STAR4", nil :: any, c, NS(0, 3, 1, 0), 10, { rot = { 45, 45 } })
		K.coreFlash(at, 3, 4)
	end)
end

-- TARO — Dempsey Roll : images fantômes et arcs en ∞ ; Trigger(durée)
PASSIVE.TARO = function(a, c)
	local char = a.char
	return handle(nil, function(dur: number?)
		local d = dur or 0.8
		local hrp = hrpOf(char)
		local p0, p1 = Instance.new("Attachment"), Instance.new("Attachment")
		p0.Parent, p1.Parent = hrp, hrp
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1 = p0, p1
		tr.Texture = V.Tex.TRAIL_RIM
		tr.Color = seq(0, Color3.fromHex("FFE14A"), 1, c)
		tr.LightEmission, tr.LightInfluence, tr.Lifetime = 1, 0, 0.18
		tr.Transparency = NS(0, 0, 1, 1)
		tr.Parent = hrp
		local frame = 0
		V.Animate(d, function(k, t)
			local s = t * 9 -- lemniscate (∞) devant le buste
			local x, y = 1.6 * math.cos(s) / (1 + math.sin(s) ^ 2), 1.6 * math.sin(s) * math.cos(s) / (1 + math.sin(s) ^ 2)
			p0.Position = Vector3.new(x, 1 + y, -1.4)
			p1.Position = Vector3.new(x * 1.15, 1 + y * 1.15 + 0.35, -1.6)
			frame += 1
			if frame % 6 == 0 then
				V.Ghost(char, c, 8)
			end
		end, function()
			tr.Enabled = false
			task.delay(0.3, function()
				tr:Destroy(); p0:Destroy(); p1:Destroy()
			end)
		end)
	end)
end

-- ZEPHYR — Perfect Rhythm : pulsation dorée (Trigger) ; étincelles en orbite (Set(0..3))
PASSIVE.ZEPHYR = function(a, c)
	local hrp = hrpOf(a.char)
	local o = orbit(hrp, "STAR4", V.GOLD, 3, 1.8, 4, 0.7, 0.5)
	return handle(function(n) o.SetCount(n) end, function()
		local h = Instance.new("Highlight")
		h.FillColor, h.OutlineColor, h.Adornee = V.GOLD, V.GOLD, a.char
		h.Parent = hrp
		V.Animate(10 * FR, function(k)
			h.FillTransparency, h.OutlineTransparency = 0.4 + 0.6 * k, k
		end, function()
			h:Destroy()
		end)
		local _, at = V.Host(hrp.CFrame, 1)
		K.ring(at, "RING_THIN", V.GOLD, 2, 8, 14)
	end, o.Destroy)
end

-- AKEMI — INSTINCT : image fantôme argentée (Trigger) ; 3 orbes de charge qui tournent (Set(0..3))
PASSIVE.AKEMI = function(a, c)
	local hrp = hrpOf(a.char)
	local o = orbit(hrp, "GLOW_CORE", c, 3, 1.6, 3, 0.7, 0.3)
	return handle(function(n) o.SetCount(n) end, function()
		V.Ghost(a.char, Color3.fromHex("D8DCE8"), 14, WHITE)
	end, o.Destroy)
end

-- RYUKEN — RAGE : vapeur et rouge qui montent sur 10 niveaux, flammes à 10 ; Set(0..10)
PASSIVE.RYUKEN = function(a, c)
	local vol = volume(a.char, Vector3.new(3, 5, 2))
	local steam = V.Emitter(vol, { tex = "WISP_4x4", grid = 4, color = Color3.fromHex("B8B4B0"), le = 0, br = 1, size = NS(0, 1.2, 1, 2.4), life = { 26, 36 }, speed = { 2, 5 }, dir = UP, spread = 15, tr = NS(0, 0.3, 1, 0.8), shape = Enum.ParticleEmitterShape.Box })
	local fl = V.Emitter(vol, { tex = "AURA_FLAME_8x8", grid = 8, color = seq(0, Color3.fromHex("FFD0C0"), 0.25, c, 1, Color3.fromHex("8B0000")), size = NS(0, 2.6, 1, 3.6), life = { 22, 30 }, speed = { 3, 6 }, dir = UP, spread = 8, locked = true, tr = NS(0, 0.1, 1, 0.35), z = -1, shape = Enum.ParticleEmitterShape.Box })
	steam.Enabled, fl.Enabled = true, true
	steam.Rate, fl.Rate = 0, 0
	local hl = pulseHL(a.char, c, 1.5)
	return handle(function(n: number)
		local k = math.clamp(n, 0, 10) / 10
		steam.Rate = 12 * k
		hl.Set(k * 0.8)
		fl.Rate = if n >= 10 then 16 else 0
	end, nil, function()
		steam.Enabled, fl.Enabled = false, false
		hl.Destroy()
		task.delay(1.5, function()
			vol:Destroy()
		end)
	end)
end

-- SHIN — PRECISION : reflet à la pointe ; Trigger(attachment de la pointe)
PASSIVE.SHIN = function(a, c)
	return handle(nil, function(tip: Attachment)
		local _, at = V.Host(tip.WorldCFrame, 1)
		K.flipFx(at, "GLINT", nil :: any, WHITE, NS(0, 3, 0.4, 2.5, 1, 0), 12, { rot = { 0, 0 }, br = 4 })
		K.flipFx(at, "STAR4", nil :: any, c, NS(0, 1.6, 1, 0), 10, { rot = { 0, 0 } })
	end)
end

-- DAICHA — L'orbe : cœur noir + coque ForceField violette (args.part = la Part de l'orbe)
PASSIVE.DAICHA = function(a, c)
	local part = a.part :: BasePart
	local sz = a.size or 1.8
	local core = weldMesh(part, "SPHERE", Vector3.one * sz * 0.6, function(m)
		m.Material = Enum.Material.SmoothPlastic
		m.Color = BLACK
	end)
	local shell = weldMesh(part, "SPHERE", Vector3.one * sz, function(m)
		m.Material = Enum.Material.ForceField
		m.TextureID = V.Tex.HEX_GRID
		m.Color = c
	end)
	return handle(function(intensity: number)
		shell.Transparency = 1 - math.clamp(intensity, 0, 1)
	end, nil, function()
		core:Destroy(); shell:Destroy()
	end)
end

-- HIBECARES — KING OF RUINS : fissures sous lui qui grandissent quand sa vie baisse, braises ; Set(vie 0..1)
PASSIVE.HIBECARES = function(a, c)
	local char = a.char
	local vol = volume(char, Vector3.new(3, 0.4, 2), Vector3.new(0, -2.8, 0))
	local emb = V.Emitter(vol, { tex = "EMBER", color = seq(0, Color3.fromHex("FFE0A0"), 1, c), size = NS(0, 0.35, 1, 0), life = { 30, 45 }, speed = { 2, 5 }, dir = UP, spread = 20, accel = Vector3.new(0, 3, 0), orient = "VelocityParallel", shape = Enum.ParticleEmitterShape.Box })
	emb.Enabled, emb.Rate = true, 0
	local mark: Part? = nil
	local lastStep = -1
	return handle(function(hp: number)
		local loss = 1 - math.clamp(hp, 0, 1)
		emb.Rate = 18 * loss
		local step = math.floor(loss * 4) -- 4 paliers de fissures
		if step ~= lastStep then
			lastStep = step
			if mark then
				mark:Destroy()
				mark = nil
			end
			if step > 0 then
				mark = V.Mark(V.FeetCF(char), 3 + 3 * step, "CRACK_2x2", c, 0, 9e9, 1, true)
			end
		end
		if mark then
			local feet = V.FeetCF(char).Position
			mark.CFrame = CFrame.new(feet) * (mark.CFrame - mark.CFrame.Position)
		end
	end, nil, function()
		emb.Enabled = false
		if mark then
			mark:Destroy()
		end
		task.delay(1.5, function()
			vol:Destroy()
		end)
	end)
end

-- RAIJIN — OVERCHARGE : la lance crépite, 3 pastilles ; Set(0..3) ; args.weaponBase/weaponTip (Attachments)
PASSIVE.RAIJIN = function(a, c)
	local head = a.char:FindFirstChild("Head") :: BasePart
	local pips = {}
	for i = 1, 3 do
		local bb = sprite(head, "GLOW_CORE", 0.7, c, Vector3.new(-0.8 + (i - 1) * 0.8, 2.2, 0))
		bb.Enabled = false
		pips[i] = bb
	end
	local level, alive = 0, true
	task.spawn(function()
		while alive do
			if level > 0 and a.weaponBase and a.weaponTip then
				V.Lightning(a.weaponBase, a.weaponTip, c, { segs = 5, dur = 6 * FR, jitter = 0.4 + 0.15 * level, width = 0.15, core = false })
			end
			task.wait(0.35 / math.max(level, 1))
		end
	end)
	return handle(function(n)
		level = math.clamp(n, 0, 3)
		for i, bb in pips do
			bb.Enabled = i <= level
		end
	end, nil, function()
		alive = false
		for _, bb in pips do
			bb:Destroy()
		end
	end)
end

-- YUKINA — DEEP FREEZE : givre sur la cible, gangue de glace aux pieds à 3 charges ; Set(charges 0..3) ; args.target
PASSIVE.YUKINA = function(a, c)
	local tgt = a.target
	local hl = pulseHL(tgt, c, 0.8, WHITE)
	local shards = {}
	local vol = volume(tgt, Vector3.new(3, 5, 2))
	local frost = V.Emitter(vol, { tex = "SNOWFLAKE_2x2", grid = 2, mode = "Random", color = WHITE, size = NS(0, 0.4, 1, 0), life = { 30, 45 }, speed = { 0.2, 1 }, spread = 180, rot = { 0, 360 }, shape = Enum.ParticleEmitterShape.Box })
	frost.Enabled, frost.Rate = true, 0
	local function clear()
		for _, m in shards do
			m:Destroy()
		end
		shards = {}
	end
	return handle(function(n)
		n = math.clamp(n, 0, 3)
		hl.Set(n / 3 * 0.8)
		frost.Rate = 3 * n
		clear()
		local feet = V.FeetCF(tgt)
		for i = 1, n * 2 do
			local ang = i * math.pi * 2 / (n * 2)
			local m = K.meshTemplate(({ "ICE_SHARD_A", "ICE_SHARD_B", "ICE_SHARD_C" })[(i % 3) + 1]):Clone()
			m.Anchored, m.CanCollide, m.CanQuery, m.CanTouch, m.CastShadow = true, false, false, false, false
			m.Material = Enum.Material.Glass
			m.Transparency = 0.2
			m.Color = c
			local h = 0.6 + 0.4 * n
			m.Size = Vector3.new(0.5, h, 0.5)
			m.CFrame = feet * CFrame.Angles(0, ang, 0) * CFrame.new(0, 0, -1.1) * CFrame.Angles(math.rad(-20), 0, 0) * CFrame.new(0, h / 2, 0)
			m.Parent = K.folder()
			table.insert(shards, m)
		end
	end, nil, function()
		hl.Destroy()
		clear()
		frost.Enabled = false
		task.delay(1.5, function()
			vol:Destroy()
		end)
	end)
end

-- VENOM — CONTAMINATION : teinte verte qui pulse, bulles, gouttes ; Set(0..1) ; args.target
PASSIVE.VENOM = function(a, c)
	local tgt = a.target
	local hl = pulseHL(tgt, c, 1.2)
	local vol = volume(tgt, Vector3.new(3, 5, 2))
	local bub = V.Emitter(vol, { tex = "BUBBLE", color = c, size = NS(0, 0.3, 0.8, 0.6, 1, 0.8), tr = NS(0, 0, 0.9, 0, 1, 1), life = { 30, 45 }, speed = { 1, 3 }, dir = UP, spread = 20, shape = Enum.ParticleEmitterShape.Box })
	local drip = V.Emitter(vol, { tex = "DROPLET", color = hot(c), size = NS(0, 0.3, 1, 0.1), life = { 16, 24 }, speed = { 0, 1 }, accel = Vector3.new(0, -35, 0), orient = "VelocityParallel", shape = Enum.ParticleEmitterShape.Box })
	bub.Enabled, drip.Enabled = true, true
	bub.Rate, drip.Rate = 0, 0
	return handle(function(k)
		k = math.clamp(k, 0, 1)
		hl.Set(k * 0.7)
		bub.Rate, drip.Rate = 6 * k, 5 * k
	end, nil, function()
		hl.Destroy()
		bub.Enabled, drip.Enabled = false, false
		task.delay(1.5, function()
			vol:Destroy()
		end)
	end)
end

-- GORAN — ANCHOR : flash d'armure + ancre lumineuse au sol ; Trigger(durée)
PASSIVE.GORAN = function(a, c)
	return handle(nil, function(dur: number?)
		V.SuperArmor(a.char)
		V.Mark(V.FeetCF(a.char), 6, "GORAN_ANCHOR", c, nil, (dur or 1.5), 0.4, true)
		local _, at = V.Host(V.FeetCF(a.char) * CFrame.Angles(math.rad(90), 0, 0), 1)
		K.ring(at, "RING_SOFT", c, 2, 9, 14, { orient = "VelocityPerpendicular" })
	end)
end

-- ASTER — SHIFTING MASS : anneaux au-dessus (dir = 1) ou en dessous (dir = -1) de la cible ; Trigger(target, dir)
PASSIVE.ASTER = function(a, c)
	return handle(nil, function(tgt: Model, dir: number?)
		local d = dir or 1
		local hrp = hrpOf(tgt)
		local start = hrp.CFrame * CFrame.new(0, 6 * d, 0)
		local _, at = V.Host(CFrame.new(start.Position) * CFrame.Angles(math.rad(if d > 0 then -90 else 90), 0, 0), 2)
		local e = V.Emitter(at, { tex = "RING_THIN", color = c, size = NS(0, 5, 1, 2), tr = NS(0, 0, 0.8, 0.2, 1, 1), life = 24, speed = { 10 }, orient = "VelocityPerpendicular", br = 3 })
		for i = 0, 3 do
			V.After(i * 4 * FR, function()
				V.Emit(e, 1)
			end)
		end
	end)
end

-- HIBIKI — TEMPO : tout pulse en rythme ; Set(bpm, 0 = arrêt)
PASSIVE.HIBIKI = function(a, c)
	local bpm, alive = 0, true
	local hl = pulseHL(a.char, c, 2)
	task.spawn(function()
		while alive do
			if bpm > 0 then
				hl.Set(0.6)
				local _, at = V.Host(V.FeetCF(a.char) * CFrame.Angles(math.rad(90), 0, 0), 1)
				K.ring(at, "RING_THIN", c, 1.5, 6, 12, { orient = "VelocityPerpendicular" })
				task.wait(0.08)
				hl.Set(0)
				task.wait(60 / bpm - 0.08)
			else
				task.wait(0.1)
			end
		end
	end)
	return handle(function(n) bpm = math.max(0, n) end, nil, function()
		alive = false
		hl.Destroy()
	end)
end

-- KAZAN — SHACKLED : chaîne entre lui et la cible ; Set(target ou nil)
PASSIVE.KAZAN = function(a, c)
	local hrp = hrpOf(a.char)
	local a0 = Instance.new("Attachment")
	a0.Parent = hrp
	local b: Beam? = nil
	local a1: Attachment? = nil
	local function clear()
		if b then b:Destroy() end
		if a1 then a1:Destroy() end
		b, a1 = nil, nil
	end
	return handle(function(tgt: Model?)
		clear()
		if tgt then
			a1 = Instance.new("Attachment")
			a1.Parent = hrpOf(tgt)
			b = V.Beam(hrp, a0, a1, { tex = "CHAIN", color = Color3.fromHex("C8C8D0"), w = 0.7, mode = Enum.TextureMode.Wrap, tlen = 1.6, le = 0.3, br = 1.5 })
			b.CurveSize0, b.CurveSize1 = -2, 2
			local _, at = V.Host((a1 :: Attachment).WorldCFrame, 1)
			K.sparks(at, c, 8, 25, 0.8, 180)
		end
	end, nil, function()
		clear()
		a0:Destroy()
	end)
end

-- KUREN — SCARLET PACT : veines cramoisies, aura qui aspire ; Set(0..1)
PASSIVE.KUREN = function(a, c)
	local vol = volume(a.char, Vector3.new(2.6, 4.5, 1.6))
	local veins = V.Emitter(vol, { tex = "KUREN_VEINS", color = hot(c), size = NS(0, 2.2, 1, 2.6), life = { 18, 26 }, tr = NS(0, 1, 0.3, 0.2, 1, 1), locked = true, shape = Enum.ParticleEmitterShape.Box })
	local big = volume(a.char, Vector3.new(9, 9, 9))
	big.Shape = Enum.PartType.Ball
	local suck = V.Emitter(big, { tex = "MOTE", color = c, size = NS(0, 0.35, 1, 0.1), life = 18, speed = { 12 }, shape = Enum.ParticleEmitterShape.Sphere, shapeStyle = Enum.ParticleEmitterShapeStyle.Surface, inward = true })
	veins.Enabled, suck.Enabled = true, true
	veins.Rate, suck.Rate = 0, 0
	return handle(function(k)
		k = math.clamp(k, 0, 1)
		veins.Rate, suck.Rate = 4 * k, 20 * k
	end, nil, function()
		veins.Enabled, suck.Enabled = false, false
		task.delay(1.5, function()
			vol:Destroy(); big:Destroy()
		end)
	end)
end

-- SYLVA — TERRITORY : anneau d'herbe et de fleurs au sol (12 studs) ; Set(position Vector3 ou nil) ; args.blossom
PASSIVE.SYLVA = function(a, c)
	local mark: Part? = nil
	local petals: ParticleEmitter? = nil
	local col = if a.blossom then Color3.fromHex("FF9AC8") else c
	local function clear()
		if mark then mark:Destroy() end
		mark = nil
		if petals then
			petals.Enabled = false
		end
	end
	return handle(function(pos: Vector3?)
		clear()
		if pos then
			local gp = V.GroundBelow(pos) or pos
			mark = V.Mark(CFrame.new(gp), 24, "SYLVA_GRASS_RING", col, nil, 9e9, 0.5, false)
			local _, at = V.Host(CFrame.new(gp + Vector3.new(0, 0.5, 0)), 9e9)
			petals = V.Emitter(at.Parent :: Instance, { tex = "PETAL_2x2", grid = 2, mode = "Random", color = col, size = NS(0, 0.5, 1, 0.2), life = { 40, 60 }, speed = { 0.5, 2 }, spread = 60, dir = UP, rate = 6, rot = { 0, 360 }, rotSpeed = { -90, 90 }, shape = Enum.ParticleEmitterShape.Disc, accel = Vector3.new(0, -0.5, 0) })
			local hostPart = at.Parent :: BasePart
			hostPart.Size = Vector3.new(24, 0.2, 24)
			petals.Enabled = true
		end
	end, nil, clear)
end

-- ELIAN — SECOND WIND : pilier de lumière + anneaux ; Trigger()
PASSIVE.ELIAN = function(a, c)
	return handle(nil, function()
		V.Revive(a.char, c)
		V.Heal(a.char, c)
	end)
end

-- NOVA — ENGINEERING : drone en hologramme ; Set(true/false)
PASSIVE.NOVA = function(a, c)
	local hrp = hrpOf(a.char)
	local cyan = Color3.fromHex("6FE0FF")
	local bb, im = sprite(hrp, "NOVA_DRONE", 2, cyan, Vector3.new(1.8, 3.2, 0))
	local scan = layer(bb, "NOVA_HOLO_LINES", cyan, 1, 2)
	im.ImageTransparency, scan.ImageTransparency = 0.4, 0.6
	bb.Enabled = false
	local t, conn = 0, nil
	conn = RunService.Heartbeat:Connect(function(dt)
		t += dt
		bb.StudsOffsetWorldSpace = Vector3.new(1.8, 3.2 + 0.2 * math.sin(t * 3), 0)
		im.ImageTransparency = 0.35 + 0.15 * math.sin(t * 25) ^ 2
	end)
	return handle(function(on) bb.Enabled = on and true or false end, nil, function()
		conn:Disconnect()
		bb:Destroy()
	end)
end

-- KUROEN — DOMINATION : 3 marques rouges dans le dos ; Set(0..3)
PASSIVE.KUROEN = function(a, c)
	local hrp = hrpOf(a.char)
	local marks = {}
	for i = 1, 3 do
		local att = Instance.new("Attachment")
		att.Position = Vector3.new(-0.6 + (i - 1) * 0.6, 0.6 + (i == 2 and 0.4 or 0), 0.65)
		att.Parent = hrp
		local bb = sprite(hrp, "KUROEN_MARK", 0.9, c)
		bb.Adornee = att :: any
		bb.Enabled = false
		marks[i] = { bb = bb, att = att }
	end
	return handle(function(n)
		for i, m in marks do
			m.bb.Enabled = i <= n
		end
	end, nil, function()
		for _, m in marks do
			m.bb:Destroy(); m.att:Destroy()
		end
	end)
end

---------------------------------------------------------------------------- API
S.Auras, S.Skills, S.Passives = AURA, SKILL, PASSIVE

function S.Aura(name: string, char: Model, color: Color3?)
	local f = assert(AURA[name], "aura inconnue : " .. tostring(name))
	return f(char, colorOf(name, color))
end

function S.Skill(name: string, args: { [string]: any })
	local f = assert(SKILL[name], "compétence inconnue : " .. tostring(name))
	return f(args, colorOf(name, args.color))
end

function S.Passive(name: string, args: { [string]: any })
	local f = assert(PASSIVE[name], "passif inconnu : " .. tostring(name))
	return f(args, colorOf(name, args.color))
end

return S
