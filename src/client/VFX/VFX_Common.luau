--[[
	BREAKFRAMEZ — VFX_Common (ModuleScript, côté CLIENT)
	════════════════════════════════════════════════════
	In the game: Wilhem's VFX pack (stages 1 to 3), adapted for Rojo: the IDs come from
	Shared.VfxConfig (EffectsController uses the pack only once they are uploaded), the meshes
	from ReplicatedStorage.VFX_Meshes (built by the server), the shake goes through the game's
	camera (V.ShakeHook).
	Tous les VFX communs du combat : impacts (4 niveaux), garde, garde brisée, parade, chocs,
	renvoi, super armure, burst, mouvements, saisies, super flash, aura de jauge, FATAL prêt,
	soin, retour à la vie, PERFECT, étourdissement, K.O. — plus les outils réutilisés par
	les persos : gel d'impact, ralenti, éclairs, traînées, slashes, images fantômes,
	image d'impact, flash blanc, marques au sol, grades de couleur.

	INSTALLATION
	  1. ReplicatedStorage > VFX_Common (ce ModuleScript).
	  2. Importe les PNG (Asset Manager) et colle leurs ID dans V.Tex ci-dessous.
	  3. Importe les FBX en MeshParts et range-les dans ReplicatedStorage > VFX_Meshes,
	     chaque MeshPart nommé comme sa clé (SLASH_180, SPHERE, SHIELD_HEX…).
	     (Roblox n'autorise pas un script à changer le MeshId : on clone ces modèles.)
	  4. Appelle depuis un LocalScript, ex. quand le serveur signale un coup :
	       local V = require(ReplicatedStorage.VFX_Common)
	       V.Impact("heavy", hitCFrame, attackerColor, { hitstop = 8 })
	     hitCFrame : position du point d'impact, LookVector = direction du coup.

	RYTHME (60 i/s) : anticipation 1–3 images → explosion 1–2 images (très grande)
	→ dissipation 10–30 images. Les Lifetime sont exprimés en images (/60).

	BUDGET : un coup ≤ 40 particules (compté dans chaque fonction), ultime ≤ 600,
	≤ 24 Beams, ≤ 4 lumières. Les compteurs V.Stats permettent de vérifier en jeu.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local V = {}
V.Stats = { particles = 0, beams = 0, lights = 0 }

local FR = 1 / 60 -- une image

---------------------------------------------------------------------------- ASSETS
-- (every texture of the pack, by key: its content ID, "" while it is not uploaded)
local VfxConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("VfxConfig"))
V.Tex = {}
for key in VfxConfig.TEXTURES do
	V.Tex[key] = VfxConfig.texture(key) or ""
end
-- (in the game: a texture that did not load on this client, VfxPack.preload: the particles
-- that use it are left out, the rest of each effect plays)
V.Missing = {}
function V.Blank(key: string)
	V.Missing[key] = true
	V.Tex[key] = ""
end
-- taille des planches (pour ImageRectOffset / SurfaceGui)
V.TexSize = { CRACK_2x2 = 512, SPEEDLINES_RADIAL_4x4 = 1024, SPEEDLINES_LINEAR_4x4 = 1024 }

local meshFolder: Folder? = nil
local function meshTemplate(name: string): MeshPart
	if not meshFolder then
		meshFolder = ReplicatedStorage:FindFirstChild("VFX_Meshes") :: Folder? -- (never yields: built by the server)
	end
	local m = meshFolder and meshFolder:FindFirstChild(name)
	if not (m and m:IsA("MeshPart")) then
		-- (in the game: a mesh not uploaded or not loaded yet gives an empty MeshPart, which
		-- draws nothing: the rest of the effect still plays; the effects that are mostly a
		-- mesh keep the game's own until it is there, VfxPack.MESH_OF)
		if not V.EmptyMesh then
			V.EmptyMesh = Instance.new("MeshPart")
			V.EmptyMesh.Transparency = 1
		end
		return V.EmptyMesh :: MeshPart
	end
	return m :: MeshPart
end

---------------------------------------------------------------------------- PALETTE
V.WHITE = Color3.new(1, 1, 1)
V.GOLD = Color3.fromHex("FFD23F")
V.FATAL_RED = Color3.fromHex("FF1A2A")
V.ARMOR = Color3.fromHex("FF5A28")
V.DUST = Color3.fromHex("BFB2A6")
V.Energy = { -- Énergies des persos (skins : passer une autre Color3)
	KAI = Color3.fromHex("FF2A3D"), TARO = Color3.fromHex("FF6A1A"), ZEPHYR = Color3.fromHex("5FE0D0"),
	AKEMI = Color3.fromHex("B060FF"), RYUKEN = Color3.fromHex("FF2A2A"), SHIN = Color3.fromHex("4DA8FF"),
	DAICHA = Color3.fromHex("B060FF"), HIBECARES = Color3.fromHex("FF8A1A"), RAIJIN = Color3.fromHex("FFE85A"),
	YUKINA = Color3.fromHex("9FE6FF"), VENOM = Color3.fromHex("7CFF4A"), GORAN = Color3.fromHex("FF4A3A"),
	ASTER = Color3.fromHex("B49CFF"), HIBIKI = Color3.fromHex("FF6FC8"), KAZAN = Color3.fromHex("FFB04A"),
	KUREN = Color3.fromHex("D0102E"), SYLVA = Color3.fromHex("4AD86A"), ELIAN = Color3.fromHex("FFE9A0"),
	NOVA = Color3.fromHex("FF8A2A"), KUROEN = Color3.fromHex("E0102E"), ASURA = Color3.fromHex("FFD23F"),
	KUROEN_SHIN = Color3.fromHex("FFF4D6"),
}

-- grades ColorCorrection par perso (V.Grade(nom, durée))
V.Grades = {
	crimson = { tint = Color3.fromHex("FFD0D4"), br = -0.05, ct = 0.15, sat = 0.1 },
	void = { tint = Color3.fromHex("C9B8FF"), br = -0.15, ct = 0.25, sat = -0.3 },
	mono = { tint = Color3.new(1, 1, 1), br = 0, ct = 0.35, sat = -1 },
	fire = { tint = Color3.fromHex("FFD9B8"), br = 0.02, ct = 0.15, sat = 0.15 },
	sky = { tint = Color3.fromHex("D2FFF8"), br = 0.05, ct = 0.05, sat = 0 },
	shadow = { tint = Color3.fromHex("D9C4FF"), br = -0.2, ct = 0.3, sat = -0.4 },
	rage = { tint = Color3.fromHex("FFC2BC"), br = -0.05, ct = 0.3, sat = 0.2 },
	current = { tint = Color3.fromHex("CFE6FF"), br = 0, ct = 0.1, sat = 0 },
	inverse = { tint = Color3.new(1, 1, 1), br = 0, ct = -1.8, sat = -1 },
	ruin = { tint = Color3.fromHex("FFE0C2"), br = -0.05, ct = 0.2, sat = -0.35 },
	storm = { tint = Color3.fromHex("FFF6C9"), br = -0.12, ct = 0.3, sat = -0.2 },
	frost = { tint = Color3.fromHex("DDF6FF"), br = 0.05, ct = 0.1, sat = -0.3 },
	toxic = { tint = Color3.fromHex("DCFFC9"), br = -0.05, ct = 0.15, sat = 0.1 },
	titan = { tint = Color3.fromHex("FFD6C9"), br = -0.05, ct = 0.25, sat = -0.1 },
	cosmos = { tint = Color3.fromHex("D8CCFF"), br = -0.15, ct = 0.2, sat = -0.1 },
	sonic = { tint = Color3.fromHex("FFD6F0"), br = 0.02, ct = 0.1, sat = 0.1 },
	iron = { tint = Color3.fromHex("FFE6C4"), br = -0.05, ct = 0.25, sat = -0.5 },
	blood = { tint = Color3.fromHex("FFB8C0"), br = -0.12, ct = 0.3, sat = -0.1 },
	wild = { tint = Color3.fromHex("D6FFD9"), br = 0, ct = 0.1, sat = 0.1 },
	holy = { tint = Color3.fromHex("FFF6D6"), br = 0.12, ct = 0.05, sat = -0.1 },
}

---------------------------------------------------------------------------- HORLOGE : gel d'impact + ralenti
-- Toutes les animations des VFX passent par V.Animate pour pouvoir se figer (gel) ou ralentir.
local anims = {}
local emitters = setmetatable({}, { __mode = "k" })
local blank = setmetatable({}, { __mode = "k" }) -- (in the game: emitters whose texture did not load)
local timeScale = 1
local frozenUntil = 0
local currentTS = 1

local function effectiveScale(): number
	if os.clock() < frozenUntil then
		return 0
	end
	return timeScale
end

local function applyTS()
	local s = effectiveScale()
	if s == currentTS then
		return
	end
	currentTS = s
	for e in emitters do
		if e.Parent then
			e.TimeScale = s
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	applyTS()
	local step = dt * currentTS
	for i = #anims, 1, -1 do
		local a = anims[i]
		a.t += step
		local k = if a.dur > 0 then math.min(a.t / a.dur, 1) else 1
		local ok, err = pcall(a.fn, k, a.t)
		if not ok then
			warn("[VFX] ", err)
		end
		if k >= 1 or not ok then
			table.remove(anims, i)
			if a.done then
				task.spawn(a.done)
			end
		end
	end
end)

--- anime fn(k ∈ 0..1, t) pendant dur secondes de « temps VFX » (respecte gel et ralenti)
function V.Animate(dur: number, fn: (number, number) -> (), done: (() -> ())?)
	table.insert(anims, { t = 0, dur = dur, fn = fn, done = done })
end

--- appelle fn après sec secondes de temps VFX
function V.After(sec: number, fn: () -> ())
	V.Animate(sec, function() end, fn)
end

--- gel d'impact : fige particules et animations VFX pendant n images (le jeu fige les persos de son côté)
function V.Hitstop(frames: number)
	frozenUntil = math.max(frozenUntil, os.clock() + frames * FR)
	applyTS()
end

--- ralenti global des VFX (0..1) ; 1 = normal
function V.SetTimeScale(s: number)
	timeScale = math.clamp(s, 0, 1)
	applyTS()
end

--- animation en temps RÉEL (effets d'écran : ne se figent pas pendant le gel)
function V.RealAnimate(dur: number, fn: (number, number) -> (), done: (() -> ())?)
	local t0 = os.clock()
	local c
	c = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local k = if dur > 0 then math.min(t / dur, 1) else 1
		local ok, err = pcall(fn, k, t)
		if not ok then
			warn("[VFX] ", err)
		end
		if k >= 1 or not ok then
			c:Disconnect()
			if done then
				done()
			end
		end
	end)
end

---------------------------------------------------------------------------- OUTILS
local function NS(...): NumberSequence
	local a = { ... }
	if #a == 1 then
		return NumberSequence.new(a[1])
	end
	local k = {}
	for i = 1, #a, 2 do
		table.insert(k, NumberSequenceKeypoint.new(a[i], a[i + 1]))
	end
	return NumberSequence.new(k)
end
V.NS = NS

local function CS(c: any): ColorSequence
	if typeof(c) == "ColorSequence" then
		return c
	end
	return ColorSequence.new(c)
end

local function lerpColor(a: Color3, b: Color3, k: number): Color3
	return a:Lerp(b, k)
end

local fxFolder: Folder
local function folder(): Folder
	if not fxFolder or not fxFolder.Parent then
		fxFolder = Instance.new("Folder")
		fxFolder.Name = "BFZ_VFX"
		fxFolder.Parent = workspace
	end
	return fxFolder
end

local function cleanup(inst: Instance, sec: number)
	V.After(sec, function()
		if inst then
			inst:Destroy()
		end
	end)
	task.delay(sec * 6 + 3, function() -- filet de sécurité (ralenti / gel prolongés)
		if inst and inst.Parent then
			inst:Destroy()
		end
	end)
end

--- Part invisible ancrée + Attachment orienté (LookVector = cf.LookVector)
local function host(cf: CFrame, life: number?, size: Vector3?): (Part, Attachment)
	local p = Instance.new("Part")
	p.Name = "fx"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size or Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = cf
	p.Parent = folder()
	local a = Instance.new("Attachment")
	a.Parent = p
	if life then
		cleanup(p, life)
	end
	return p, a
end
V.Host = host

local LAYOUT = { [2] = Enum.ParticleFlipbookLayout.Grid2x2, [4] = Enum.ParticleFlipbookLayout.Grid4x4, [8] = Enum.ParticleFlipbookLayout.Grid8x8 }

--[[ émetteur à rafale (Rate 0, puis :Emit). p = {
	tex, grid (2/4/8), mode ("OneShot"/"Random"/"Loop"), color, le (LightEmission), br,
	size (nombre ou NumberSequence), tr (transparence), life (images, nombre ou {min,max}),
	speed ({min,max}), spread (degrés), drag, accel (Vector3), rot ({min,max}), rotSpeed,
	orient ("FacingCamera"/"VelocityParallel"/"VelocityPerpendicular"/"FacingCameraWorldUp"),
	squash, dir (NormalId), locked, z, shape, inward, rate }]]
local function emitter(parent: Instance, p: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Enabled = (p.rate or 0) > 0
	e.Rate = p.rate or 0
	e.Texture = V.Tex[p.tex] or p.tex
	e.Color = CS(p.color or V.WHITE)
	e.LightEmission = p.le or 1
	e.LightInfluence = 0
	e.Brightness = p.br or 2.5
	local s = p.size or 1
	e.Size = if typeof(s) == "number" then NS(s) else s
	local tr = p.tr or 0
	e.Transparency = if typeof(tr) == "number" then NS(tr) else tr
	local life = p.life or 15
	e.Lifetime = if typeof(life) == "table" then NumberRange.new(life[1] * FR, life[2] * FR) else NumberRange.new(life * FR)
	local sp = p.speed or { 0, 0 }
	e.Speed = NumberRange.new(sp[1], sp[2] or sp[1])
	e.SpreadAngle = Vector2.new(p.spread or 0, p.spread or 0)
	e.Drag = p.drag or 0
	e.Acceleration = p.accel or Vector3.zero
	local rot = p.rot or { 0, 0 }
	e.Rotation = NumberRange.new(rot[1], rot[2] or rot[1])
	local rs = p.rotSpeed or { 0, 0 }
	e.RotSpeed = NumberRange.new(rs[1], rs[2] or rs[1])
	e.Orientation = Enum.ParticleOrientation[p.orient or "FacingCamera"]
	if p.squash then
		e.Squash = if typeof(p.squash) == "number" then NS(p.squash) else p.squash
	end
	e.EmissionDirection = p.dir or Enum.NormalId.Front
	e.LockedToPart = p.locked or false
	e.ZOffset = p.z or 0
	if p.shape then
		e.Shape = p.shape
		e.ShapeStyle = p.shapeStyle or Enum.ParticleEmitterShapeStyle.Volume
		if p.inward then
			e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
		end
	end
	if p.grid then
		e.FlipbookLayout = LAYOUT[p.grid]
		e.FlipbookMode = Enum.ParticleFlipbookMode[p.mode or "OneShot"]
		if p.fps then
			e.FlipbookFramerate = NumberRange.new(p.fps)
		end
		e.FlipbookStartRandom = (p.mode == "Random")
	end
	e.TimeScale = currentTS
	e.Parent = parent
	emitters[e] = true
	if V.Missing[p.tex] then
		blank[e] = true
		e.Transparency = NS(1) -- (and the ones a Rate would let out stay unseen)
	end
	return e
end
V.Emitter = emitter

--- (in the game: the share of the particles drawn, 0.5 in the reduced mode for phones; set by VfxPack)
V.Quality = 1
local function emit(e: ParticleEmitter, n: number)
	if blank[e] then -- (its texture did not load: left out)
		return
	end
	n = math.max(1, math.floor(n * V.Quality + 0.5))
	V.Stats.particles += n
	e:Emit(n)
end
V.Emit = emit

local function light(parent: Instance, color: Color3, range: number, bright: number, frames: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = bright
	l.Shadows = false
	l.Parent = parent
	V.Stats.lights += 1
	V.Animate(frames * FR, function(k)
		l.Brightness = bright * (1 - k) ^ 2
	end, function()
		V.Stats.lights -= 1
		l:Destroy()
	end)
	return l
end
V.Light = light

local function beam(parent: Instance, a0: Attachment, a1: Attachment, p: { [string]: any }): Beam
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.FaceCamera = p.faceCamera ~= false
	b.LightEmission = p.le or 1
	b.LightInfluence = 0
	b.Brightness = p.br or 3
	b.Color = CS(p.color or V.WHITE)
	b.Transparency = if typeof(p.tr) == "NumberSequence" then p.tr else NS(p.tr or 0)
	b.Width0 = p.w0 or p.w or 1
	b.Width1 = p.w1 or p.w or 1
	b.Segments = p.segs or 1
	b.ZOffset = p.z or 0
	if p.tex then
		b.Texture = V.Tex[p.tex] or p.tex
		b.TextureMode = p.mode or Enum.TextureMode.Stretch
		b.TextureLength = p.tlen or 1
		b.TextureSpeed = p.tspeed or 0
	end
	b.Parent = parent
	V.Stats.beams += 1
	b.Destroying:Connect(function()
		V.Stats.beams -= 1
	end)
	return b
end
V.Beam = beam

local function charParts(char: Model)
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local head = char:FindFirstChild("Head") :: BasePart?
	return hrp, head
end

local function feetCF(char: Model): CFrame
	local hrp = charParts(char)
	assert(hrp, "HumanoidRootPart manquant")
	local hum = char:FindFirstChildOfClass("Humanoid")
	-- (in the game: the body's own root height, set by the server on the rig, the block body
	-- has no Humanoid hip height)
	local root = char:GetAttribute("RootHeight")
	local h = if type(root) == "number" then root elseif hum then hum.HipHeight + hrp.Size.Y / 2 else 3
	return hrp.CFrame * CFrame.new(0, -h + 0.1, 0)
end
V.FeetCF = feetCF

local function camera(): Camera
	return workspace.CurrentCamera
end

local screenGui: ScreenGui
local function screen(): ScreenGui
	if not screenGui or not screenGui.Parent then
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = "BFZ_Screen"
		screenGui.IgnoreGuiInset = true
		screenGui.ResetOnSpawn = false
		screenGui.DisplayOrder = 50
		screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end
	return screenGui
end
V.Screen = screen

local function fullImage(tex: string, color: Color3?, z: number?): ImageLabel
	local im = Instance.new("ImageLabel")
	im.BackgroundTransparency = 1
	im.Size = UDim2.fromScale(1, 1)
	im.Image = V.Tex[tex] or tex
	im.ImageColor3 = color or V.WHITE
	im.ScaleType = Enum.ScaleType.Stretch
	im.ZIndex = z or 1
	im.Parent = screen()
	return im
end

--- flipbook UI (ImageLabel) : avance ImageRectOffset à fps, boucle tant que dur
local function uiFlipbook(im: ImageLabel, sheet: number, grid: number, fps: number, dur: number, loop: boolean?)
	local cell = sheet / grid
	local frames = grid * grid - 1 -- dernière image vide
	im.ImageRectSize = Vector2.new(cell, cell)
	V.RealAnimate(dur, function(_, t)
		local i = math.floor(t * fps)
		if loop then
			i %= frames
		else
			i = math.min(i, frames)
		end
		im.ImageRectOffset = Vector2.new((i % grid) * cell, math.floor(i / grid) * cell)
	end)
end
V.UIFlipbook = uiFlipbook

---------------------------------------------------------------------------- EFFETS D'ÉCRAN
local flashTimes = {}
--- flash blanc plein écran : ≤ 3 images, jamais plus de 3 par seconde (sinon ignoré)
function V.WhiteFlash(frames: number?, color: Color3?)
	local n = math.clamp(frames or 2, 1, 3)
	local now = os.clock()
	for i = #flashTimes, 1, -1 do
		if now - flashTimes[i] > 1 then
			table.remove(flashTimes, i)
		end
	end
	if #flashTimes >= 3 then
		return
	end
	table.insert(flashTimes, now)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color or V.WHITE
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = 100
	f.Parent = screen()
	task.delay(n * FR, function()
		f:Destroy()
	end)
end

--- image d'impact : écran noir (ou blanc si inverse) + silhouettes AlwaysOnTop pendant 2–3 images
function V.ImpactFrame(chars: { Model }, frames: number?, inverse: boolean?)
	local n = math.clamp(frames or 3, 1, 3)
	local cam = camera()
	local plane = Instance.new("Part")
	plane.Anchored = true
	plane.CanCollide = false
	plane.CanQuery = false
	plane.CanTouch = false
	plane.CastShadow = false
	plane.Material = Enum.Material.Neon
	plane.Color = if inverse then V.WHITE else Color3.new(0, 0, 0)
	plane.Size = Vector3.new(60, 60, 0.05)
	plane.Parent = folder()
	local hls = {}
	for _, c in chars do
		local h = Instance.new("Highlight")
		h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		h.FillColor = if inverse then Color3.new(0, 0, 0) else V.WHITE
		h.FillTransparency = 0
		h.OutlineTransparency = 1
		h.Adornee = c
		h.Parent = plane
		table.insert(hls, h)
	end
	local conn = RunService.RenderStepped:Connect(function()
		plane.CFrame = cam.CFrame * CFrame.new(0, 0, -1.5)
	end)
	plane.CFrame = cam.CFrame * CFrame.new(0, 0, -1.5)
	task.delay(n * FR, function()
		conn:Disconnect()
		plane:Destroy()
	end)
end

local cc: ColorCorrectionEffect
--- grade ColorCorrection (nom de V.Grades ou table) pendant dur secondes (fondu 6 images)
function V.Grade(name: any, dur: number)
	local g = if typeof(name) == "string" then V.Grades[name] else name
	if not g then
		return
	end
	if not cc or not cc.Parent then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "BFZ_Grade"
		cc.Parent = Lighting
	end
	local fade = 6 * FR
	V.Animate(fade, function(k)
		cc.TintColor = lerpColor(V.WHITE, g.tint, k)
		cc.Brightness = g.br * k
		cc.Contrast = g.ct * k
		cc.Saturation = g.sat * k
	end)
	V.After(dur, function()
		V.Animate(fade * 2, function(k)
			cc.TintColor = lerpColor(g.tint, V.WHITE, k)
			cc.Brightness = g.br * (1 - k)
			cc.Contrast = g.ct * (1 - k)
			cc.Saturation = g.sat * (1 - k)
		end)
	end)
end

--- lignes de vitesse plein écran ("RADIAL" ou "LINEAR")
function V.SpeedLines(kind: string?, dur: number, color: Color3?, transparency: number?)
	local key = "SPEEDLINES_" .. (kind or "RADIAL") .. "_4x4"
	local im = fullImage(key, color, 20)
	im.ImageTransparency = transparency or 0.15
	uiFlipbook(im, 1024, 4, 30, dur, true)
	task.delay(dur, function()
		im:Destroy()
	end)
	return im
end

function V.Vignette(dur: number, color: Color3?, strength: number?)
	local im = fullImage("VIGNETTE", color or Color3.new(0, 0, 0), 10)
	local s = strength or 0.15
	V.RealAnimate(dur, function(k)
		local fadeIn = math.min(k / 0.15, 1)
		local fadeOut = math.min((1 - k) / 0.3, 1)
		im.ImageTransparency = 1 - (1 - s) * math.min(fadeIn, fadeOut)
	end, function()
		im:Destroy()
	end)
	return im
end

---------------------------------------------------------------------------- OUTILS DE PERSO
--- éclair : chaîne de Beams dont les points sautent au hasard toutes les 2–3 images
function V.Lightning(p0: any, p1: any, color: Color3, opts: { [string]: any }?)
	local o = opts or {}
	local segs = o.segs or 6
	local dur = o.dur or 12 * FR
	local jit = o.jitter or 1.2
	local w = o.width or 0.5
	local hp = host(CFrame.new(), dur + FR)
	local function pos(x: any): Vector3
		return if typeof(x) == "Instance" then (x :: Attachment).WorldPosition else x
	end
	local atts = {}
	for i = 0, segs do
		local a = Instance.new("Attachment")
		a.Parent = hp
		atts[i] = a
	end
	for i = 0, segs - 1 do
		beam(hp, atts[i], atts[i + 1], { color = color, w = w, br = 4 })
		if o.core ~= false then
			beam(hp, atts[i], atts[i + 1], { color = V.WHITE, w = w * 0.35, br = 5, z = 1 })
		end
	end
	local frame, every = 0, o.every or 2
	local function jitter()
		local a, b = pos(p0), pos(p1)
		local d = b - a
		local side = d:Cross(Vector3.yAxis)
		if side.Magnitude < 1e-3 then
			side = d:Cross(Vector3.xAxis)
		end
		side = side.Unit
		local up = side:Cross(d.Unit)
		for i = 0, segs do
			local k = i / segs
			local off = Vector3.zero
			if i > 0 and i < segs then
				local amp = jit * math.sin(k * math.pi)
				off = side * (math.random() * 2 - 1) * amp + up * (math.random() * 2 - 1) * amp
			end
			atts[i].WorldPosition = a + d * k + off
		end
	end
	jitter()
	V.Animate(dur, function()
		frame += 1
		if frame % every == 0 then
			jitter()
			every = math.random(2, 3)
		end
	end)
	return hp
end

--- traînée de coup entre deux Attachments (base, pointe) ; :On() pendant les images actives, :Off() ensuite
function V.SwingTrail(base: Attachment, tip: Attachment, color: Color3, opts: { [string]: any }?)
	local o = opts or {}
	local t = Instance.new("Trail")
	t.Attachment0 = base
	t.Attachment1 = tip
	t.Texture = V.Tex[o.tex or "TRAIL_GRADIENT"]
	t.TextureMode = Enum.TextureMode.Stretch
	t.Color = CS(o.color or ColorSequence.new({ ColorSequenceKeypoint.new(0, V.WHITE), ColorSequenceKeypoint.new(0.25, color), ColorSequenceKeypoint.new(1, color) }))
	t.LightEmission = 1
	t.LightInfluence = 0
	t.Brightness = o.br or 3
	t.Lifetime = math.clamp(o.life or 0.12, 0.08, 0.2)
	t.FaceCamera = false
	t.MinLength = 0.05
	t.Transparency = NS(0, 0, 1, 1)
	t.Enabled = false
	t.Parent = base.Parent
	return {
		Trail = t,
		On = function()
			t.Enabled = true
		end,
		Off = function()
			t.Enabled = false
		end,
		Destroy = function()
			t:Destroy()
		end,
	}
end

--- slash en MeshPart : échelle 0,6→1,1 en 4 images, transparence 0→1 en 10 images
function V.Slash(cf: CFrame, color: Color3, opts: { [string]: any }?)
	local o = opts or {}
	local m = meshTemplate(o.mesh or "SLASH_180"):Clone()
	local base = m.Size * (o.scale or 1)
	m.Anchored = true
	m.CanCollide = false
	m.CanQuery = false
	m.CanTouch = false
	m.CastShadow = false
	m.Material = o.material or Enum.Material.ForceField
	m.TextureID = V.Tex[o.tex or "SLASH_ARC"]
	m.Color = color
	m.CFrame = cf
	m.Size = base * 0.6
	m.Parent = folder()
	local scaleF, fadeF = (o.scaleFrames or 4) * FR, (o.fadeFrames or 10) * FR
	local spin = o.spin or 0
	V.Animate(math.max(scaleF, fadeF), function(_, t)
		local ks = math.min(t / scaleF, 1)
		m.Size = base * (0.6 + 0.5 * (1 - (1 - ks) ^ 3))
		m.Transparency = math.min(t / fadeF, 1)
		if spin ~= 0 then
			m.CFrame = cf * CFrame.Angles(0, 0, spin * t)
		end
	end, function()
		m:Destroy()
	end)
	return m
end

--- CFrame pour poser un mesh SLASH_* / CRESCENT face à la caméra (jeu vu de côté)
-- roll : rotation de l'arc dans le plan de l'écran (degrés) ; ex. 0 = arc horizontal, 60 = coup montant
function V.ArcCFrame(center: Vector3, roll: number?): CFrame
	local toCam = (camera().CFrame.Position - center).Unit
	local base = CFrame.lookAt(center, center + toCam) * CFrame.Angles(math.rad(-90), 0, 0)
	return base * CFrame.Angles(0, math.rad(roll or 0), 0)
end

--- image fantôme : clone des parties visibles + Highlight couleur, s'efface en n images
-- outline : couleur du contour (par défaut = color) ; ex. silhouette d'encre : color noir, outline violet
function V.Ghost(char: Model, color: Color3, frames: number?, outline: Color3?)
	local n = frames or 8
	local model = Instance.new("Model")
	model.Name = "ghost"
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Transparency < 1 then
			local ok, c = pcall(function()
				local arch = d.Archivable
				d.Archivable = true
				local cl = d:Clone()
				d.Archivable = arch
				return cl
			end)
			if ok and c then
				for _, ch in c:GetChildren() do
					if not (ch:IsA("SpecialMesh") or ch:IsA("DataModelMesh")) then
						ch:Destroy()
					end
				end
				c.Anchored = true
				c.CanCollide = false
				c.CanQuery = false
				c.CanTouch = false
				c.CastShadow = false
				c.Parent = model
			end
		end
	end
	local h = Instance.new("Highlight")
	h.FillColor = color
	h.OutlineColor = outline or color
	h.FillTransparency = 0.15
	h.OutlineTransparency = if outline then 0 else 0.4
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = model
	model.Parent = folder()
	V.Animate(n * FR, function(k)
		h.FillTransparency = 0.15 + 0.85 * k
		h.OutlineTransparency = (if outline then 0 else 0.4) + (if outline then 1 else 0.6) * k
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") then
				p.LocalTransparencyModifier = k
			end
		end
	end, function()
		model:Destroy()
	end)
	return model
end

--- marque au sol / au mur (Part fine + SurfaceGui) : fissure, brûlure, flaque ; s'efface en 1–2 s
-- cf : position, UpVector = normale de la surface. cell : case de la planche 2×2 (0..3) ou nil
function V.Mark(cf: CFrame, size: number, tex: string, color: Color3?, cell: number?, hold: number?, fade: number?, glow: boolean?)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(size, 0.05, size)
	p.CFrame = cf * CFrame.Angles(0, math.random() * math.pi * 2, 0)
	p.Parent = folder()
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Top
	sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	sg.CanvasSize = Vector2.new(256, 256)
	sg.LightInfluence = if glow then 0 else 1
	sg.Parent = p
	local im = Instance.new("ImageLabel")
	im.BackgroundTransparency = 1
	im.Size = UDim2.fromScale(1, 1)
	im.Image = V.Tex[tex] or tex
	im.ImageColor3 = color or Color3.new(0.1, 0.1, 0.1)
	if cell then
		local sheet = V.TexSize[tex] or 512
		local c = sheet / 2
		im.ImageRectSize = Vector2.new(c, c)
		im.ImageRectOffset = Vector2.new((cell % 2) * c, math.floor(cell / 2) * c)
	end
	im.Parent = sg
	local h, f = hold or 0.6, fade or 1.0
	V.Animate(h + f, function(_, t)
		im.ImageTransparency = math.clamp((t - h) / f, 0, 1)
	end, function()
		p:Destroy()
	end)
	return p
end

local function groundBelow(pos: Vector3, ignore: { Instance }?): (Vector3?, Vector3?)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local list = { folder() }
	for _, i in ignore or {} do
		table.insert(list, i)
	end
	rp.FilterDescendantsInstances = list
	local r = workspace:Raycast(pos + Vector3.new(0, 1, 0), Vector3.new(0, -12, 0), rp)
	if r then
		return r.Position, r.Normal
	end
	return nil, nil
end
V.GroundBelow = groundBelow

---------------------------------------------------------------------------- BRIQUES D'IMPACT
local function sparks(att: Attachment, color: Color3, n: number, spd: number, size: number, spread: number?)
	local e = emitter(att, {
		tex = "STREAK_V", color = ColorSequence.new({ ColorSequenceKeypoint.new(0, V.WHITE), ColorSequenceKeypoint.new(0.3, color), ColorSequenceKeypoint.new(1, color) }),
		size = NS(0, size, 0.6, size * 0.6, 1, 0), life = { 8, 16 }, speed = { spd * 0.6, spd },
		spread = spread or 55, drag = 10, orient = "VelocityParallel", squash = NS(0, -0.6, 1, 0.4), br = 3, z = 2,
	})
	emit(e, n)
end

local function flipFx(att: Attachment, tex: string, grid: number, color: any, size: any, lifeFrames: number, opts: { [string]: any }?)
	local o = opts or {}
	local e = emitter(att, {
		tex = tex, grid = grid, mode = o.mode, color = color, size = size, life = lifeFrames,
		rot = o.rot or { 0, 360 }, le = o.le, br = o.br or 2.5, z = o.z or 1, tr = o.tr,
		speed = o.speed, spread = o.spread, drag = o.drag, accel = o.accel, orient = o.orient, dir = o.dir,
	})
	emit(e, o.n or 1)
	return e
end

local function coreFlash(att: Attachment, size: number, frames: number?)
	local e = emitter(att, { tex = "GLOW_CORE", color = V.WHITE, size = NS(0, size, 1, size * 1.4), tr = NS(0, 0, 1, 1), life = frames or 5, br = 4, z = 3 })
	emit(e, 1)
end

local function ring(att: Attachment, tex: string, color: any, r0: number, r1: number, frames: number, opts: { [string]: any }?)
	local o = opts or {}
	local e = emitter(att, {
		tex = tex, color = color, size = NS(0, r0, 0.35, r0 + (r1 - r0) * 0.8, 1, r1), tr = NS(0, 0, 0.6, 0.2, 1, 1), life = frames,
		orient = o.orient, speed = o.speed or { 0.01 }, dir = o.dir, br = o.br or 2.5, z = o.z or 0,
	})
	emit(e, o.n or 1)
end

local function smoke(att: Attachment, color: Color3?, n: number, size: number, spd: number?)
	local e = emitter(att, {
		tex = "SMOKE_CEL_8x8", grid = 8, color = color or V.DUST, le = 0, br = 1, size = NS(0, size * 0.6, 1, size * 1.2),
		life = { 30, 45 }, speed = { (spd or 6) * 0.5, spd or 6 }, spread = 70, drag = 6, rot = { 0, 360 }, rotSpeed = { -20, 20 },
		dir = Enum.NormalId.Top, accel = Vector3.new(0, 2, 0),
	})
	emit(e, n)
end

local function dustAt(cf: CFrame, n: number, size: number, color: Color3?)
	local _, a = host(cf, 1.5)
	local e = emitter(a, {
		tex = "DUST_GROUND_4x4", grid = 4, color = color or V.DUST, le = 0, br = 1, size = size, life = { 26, 34 },
		speed = { 0.5, 1.5 }, spread = 15, dir = Enum.NormalId.Top, orient = "FacingCameraWorldUp",
	})
	emit(e, n)
	return a
end

local function debris(att: Attachment, n: number, spd: number, size: number, color: Color3?)
	local e = emitter(att, {
		tex = "DEBRIS_2x2", grid = 2, mode = "Random", color = color or Color3.fromHex("8C7F74"), le = 0, br = 1,
		size = NS(0, size, 0.8, size, 1, 0), life = { 30, 50 }, speed = { spd * 0.5, spd }, spread = 60, drag = 1.5,
		accel = Vector3.new(0, -80, 0), rot = { 0, 360 }, rotSpeed = { -400, 400 }, dir = Enum.NormalId.Top,
	})
	emit(e, n)
end

--- secousse caméra (amplitude en studs, durée en images) ; la plus forte en cours l'emporte
--- (set by the game: its own camera shake, amplitude in studs and duration in seconds)
V.ShakeHook = nil :: ((number, number) -> ())?
local shakeAmp, shakeEnd, shakeDur, shakeBound = 0, 0, 1, false
function V.Shake(intensity: number, frames: number?)
	if V.ShakeHook then -- (the game's camera shakes: one shake, not two)
		V.ShakeHook(intensity, (frames or 12) * FR)
		return
	end
	local now = os.clock()
	local d = (frames or 12) * FR
	local current = shakeAmp * math.max(0, (shakeEnd - now) / shakeDur)
	if intensity >= current then
		shakeAmp, shakeEnd, shakeDur = intensity, now + d, d
	end
	if not shakeBound then
		shakeBound = true
		RunService:BindToRenderStep("BFZ_Shake", Enum.RenderPriority.Camera.Value + 1, function()
			local left = shakeEnd - os.clock()
			if left <= 0 then
				return
			end
			local k = left / shakeDur
			local amp = shakeAmp * k * k
			local t = os.clock() * 40
			local cam = camera()
			cam.CFrame = cam.CFrame * CFrame.new(math.noise(t, 0.3) * amp, math.noise(0.7, t) * amp, 0)
		end)
	end
end

-- briques réutilisées par les modules de persos
V.Kit = {
	sparks = sparks, flipFx = flipFx, coreFlash = coreFlash, ring = ring, smoke = smoke,
	dustAt = dustAt, debris = debris, meshTemplate = meshTemplate, charParts = charParts, folder = folder,
}

---------------------------------------------------------------------------- 1. IMPACTS
--[[ niveau : "light" (6–10 particules), "medium" (12–16 + petit anneau), "heavy" (20–28 + onde + poussière),
	"finisher" (30–40 + débris). cf : point d'impact, LookVector = direction du coup.
	opts : hitstop (images), scale, ignore (instances ignorées pour trouver le sol) ]]
function V.Impact(level: string, cf: CFrame, color: Color3, opts: { [string]: any }?)
	local o = opts or {}
	local S = o.scale or 1
	local p, a = host(cf, 2)
	local before = V.Stats.particles
	if o.hitstop then
		V.Hitstop(o.hitstop)
	end
	if level == "light" then -- 8
		flipFx(a, "HITSPARK_LIGHT_4x4", 4, color, 5 * S, 15)
		coreFlash(a, 2.5 * S, 4)
		sparks(a, color, 6, 40 * S, 1.2 * S)
	elseif level == "medium" then -- 15
		flipFx(a, "HITSPARK_LIGHT_4x4", 4, color, 7 * S, 16)
		coreFlash(a, 3.5 * S, 5)
		sparks(a, color, 10, 50 * S, 1.5 * S)
		ring(a, "RING_THIN", color, 1.5 * S, 7 * S, 12)
		flipFx(a, "MOTE", nil :: any, color, 0.6 * S, 20, { n = 2, speed = { 6, 12 }, spread = 90, drag = 6 })
		light(p, color, 10 * S, 3, 6)
	elseif level == "heavy" then -- 24
		flipFx(a, "HITSPARK_HEAVY_4x4", 4, color, 10 * S, 18)
		coreFlash(a, 5 * S, 6)
		flipFx(a, "IMPACT_BURST_2x2", 2, color, NS(0, 7 * S, 0.15, 8.5 * S, 1, 6 * S), 8, { mode = "Random", tr = NS(0, 0, 0.6, 0, 1, 1) })
		sparks(a, color, 14, 65 * S, 1.8 * S, 65)
		ring(a, "RING_SOFT", color, 3 * S, 16 * S, 16)
		local gp = groundBelow(cf.Position, o.ignore)
		if gp then
			dustAt(CFrame.new(gp), 2, 7 * S)
			smoke(a, nil, 2, 4 * S)
		else
			smoke(a, nil, 4, 4 * S)
		end
		light(p, color, 16 * S, 5, 10)
	elseif level == "finisher" then -- 36
		flipFx(a, "HITSPARK_HEAVY_4x4", 4, color, 13 * S, 20)
		coreFlash(a, 6.5 * S, 7)
		flipFx(a, "IMPACT_BURST_2x2", 2, color, NS(0, 9 * S, 0.15, 11 * S, 1, 7 * S), 9, { mode = "Random", n = 2, tr = NS(0, 0, 0.6, 0, 1, 1) })
		sparks(a, color, 16, 80 * S, 2.2 * S, 70)
		ring(a, "RING_SOFT", color, 3 * S, 20 * S, 16)
		V.After(4 * FR, function()
			ring(a, "RING_THIN", V.WHITE, 2 * S, 14 * S, 14)
		end)
		debris(a, 8, 45 * S, 1.2 * S)
		smoke(a, nil, 3, 5 * S)
		local gp = groundBelow(cf.Position, o.ignore)
		if gp then
			dustAt(CFrame.new(gp), 2, 9 * S)
		end
		light(p, color, 22 * S, 6, 14)
	end
	return V.Stats.particles - before
end

---------------------------------------------------------------------------- 2. DÉFENSE
--- garde : disque hexagonal ForceField qui flashe du côté du coup
function V.Guard(defender: Model, hitPos: Vector3, color: Color3)
	local hrp = charParts(defender)
	if not hrp then
		return
	end
	local dir = (hitPos - hrp.Position) * Vector3.new(1, 0, 1)
	dir = if dir.Magnitude > 0.01 then dir.Unit else hrp.CFrame.LookVector
	-- caméra de côté : la plaque se tourne surtout vers la caméra (sinon on la verrait par la tranche)
	local toCam = (camera().CFrame.Position - hrp.Position) * Vector3.new(1, 0, 1)
	toCam = if toCam.Magnitude > 0.01 then toCam.Unit else dir
	local face = (toCam * 0.8 + dir * 0.6).Unit
	local m = meshTemplate("SHIELD_HEX"):Clone()
	local base = Vector3.new(5, 6, 0.8)
	m.Anchored = true
	m.CanCollide = false
	m.CanQuery = false
	m.CanTouch = false
	m.CastShadow = false
	m.Material = Enum.Material.ForceField
	m.TextureID = V.Tex.HEX_GRID
	m.Color = color
	local center = hrp.Position + dir * 1.8
	m.CFrame = CFrame.lookAt(center, center + face)
	m.Parent = folder()
	V.Animate(12 * FR, function(k)
		m.Size = base * (0.9 + 0.15 * math.sin(math.min(k * 3, 1) * math.pi * 0.5))
		m.Transparency = k ^ 1.5
	end, function()
		m:Destroy()
	end)
	local _, a = host(CFrame.lookAt(hitPos, hitPos - dir), 1)
	flipFx(a, "STAR4", nil :: any, V.WHITE, NS(0, 4, 1, 1), 8, { rot = { 0, 90 } })
	ring(a, "RING_THIN", color, 1, 5, 10)
	sparks(a, color, 4, 30, 1)
end

--- garde brisée : le bouclier éclate en éclats + étoiles d'étourdissement
function V.GuardBreak(defender: Model, color: Color3, stunTime: number?)
	local hrp = charParts(defender)
	if not hrp then
		return
	end
	local p, a = host(hrp.CFrame, 2)
	V.Hitstop(8)
	coreFlash(a, 6, 6)
	local e = emitter(a, {
		tex = "SHARD", color = ColorSequence.new({ ColorSequenceKeypoint.new(0, V.WHITE), ColorSequenceKeypoint.new(0.4, color), ColorSequenceKeypoint.new(1, color) }),
		size = NS(0, 1.4, 0.8, 1.2, 1, 0), life = { 20, 34 }, speed = { 25, 45 }, spread = 180, drag = 3,
		accel = Vector3.new(0, -40, 0), rot = { 0, 360 }, rotSpeed = { -500, 500 }, br = 3,
	})
	emit(e, 22)
	ring(a, "RING_SOFT", color, 3, 14, 14)
	flipFx(a, "HITSPARK_HEAVY_4x4", 4, V.WHITE, 9, 16)
	light(p, color, 14, 5, 12)
	return V.Stun(defender, stunTime or 1.2)
end

--- parade : reflet net + anneau blanc
function V.Parry(cf: CFrame, color: Color3?)
	local p, a = host(cf, 1)
	V.Hitstop(6)
	flipFx(a, "GLINT", nil :: any, V.WHITE, NS(0, 7, 0.4, 6, 1, 0), 14, { rot = { 0, 0 }, br = 4 })
	flipFx(a, "STAR4", nil :: any, color or V.WHITE, NS(0, 3, 1, 0), 10, { rot = { 45, 45 } })
	ring(a, "RING_THIN", V.WHITE, 1, 9, 10, { br = 4 })
	coreFlash(a, 3, 4)
	light(p, V.WHITE, 12, 4, 8)
end

--- choc de coups : deux étincelles dos à dos + éclair entre les deux
function V.Clash(cf: CFrame, colorA: Color3, colorB: Color3)
	local pa, aa = host(cf * CFrame.new(-1.3, 0, 0), 1.5)
	local _, ab = host(cf * CFrame.new(1.3, 0, 0), 1.5)
	V.Hitstop(8)
	flipFx(aa, "HITSPARK_HEAVY_4x4", 4, colorA, 9, 18)
	flipFx(ab, "HITSPARK_HEAVY_4x4", 4, colorB, 9, 18)
	sparks(aa, colorA, 8, 50, 1.4, 70)
	sparks(ab, colorB, 8, 50, 1.4, 70)
	V.Lightning(aa, ab, V.WHITE, { segs = 5, dur = 16 * FR, jitter = 1, width = 0.4, core = false })
	local fl0, fl1 = Instance.new("Attachment"), Instance.new("Attachment")
	fl0.Parent, fl1.Parent = pa, pa
	fl0.Position, fl1.Position = Vector3.new(-6, 0, 0), Vector3.new(8.6, 0, 0)
	local b = beam(pa, fl0, fl1, { tex = "FLARE_ANAMORPHIC", w = 3, br = 4 })
	V.Animate(10 * FR, function(k)
		b.Transparency = NS(k)
	end)
	light(pa, V.WHITE, 16, 5, 10)
end

--- choc de projectiles : les deux couleurs explosent ensemble
function V.ProjectileClash(cf: CFrame, colorA: Color3, colorB: Color3)
	local p, a = host(cf, 2)
	V.Hitstop(6)
	flipFx(a, "IMPACT_BURST_2x2", 2, colorA, NS(0, 8, 1, 6), 10, { mode = "Random", tr = NS(0, 0, 0.6, 0, 1, 1) })
	flipFx(a, "IMPACT_BURST_2x2", 2, colorB, NS(0, 6, 1, 4.5), 10, { mode = "Random", tr = NS(0, 0, 0.6, 0, 1, 1), z = 2 })
	coreFlash(a, 5, 6)
	ring(a, "RING_SOFT", ColorSequence.new(colorA, colorB), 3, 15, 16)
	sparks(a, colorA, 8, 55, 1.6, 180)
	sparks(a, colorB, 8, 55, 1.6, 180)
	smoke(a, nil, 3, 4)
	light(p, colorA:Lerp(colorB, 0.5), 16, 5, 10)
end

--- renvoi : un miroir + reflet ; cf : LookVector = direction où regarde le miroir
-- (jeu vu de côté : tourne-le surtout vers la caméra, ex. CFrame.lookAt(pos, pos + versCamera*0.8 + versProjectile*0.6))
function V.Reflect(cf: CFrame, color: Color3)
	local m = meshTemplate("SHIELD_HEX"):Clone()
	local base = Vector3.new(4, 4.6, 0.5)
	m.Anchored = true
	m.CanCollide = false
	m.CanQuery = false
	m.CanTouch = false
	m.CastShadow = false
	m.Material = Enum.Material.Glass
	m.Reflectance = 0.6
	m.Color = V.WHITE:Lerp(color, 0.25)
	m.CFrame = cf
	m.Parent = folder()
	V.Animate(16 * FR, function(k)
		m.Size = base * (0.7 + 0.3 * math.min(k * 4, 1))
		m.Transparency = 0.25 + 0.75 * math.max(0, (k - 0.5) / 0.5)
	end, function()
		m:Destroy()
	end)
	local p, a = host(cf * CFrame.new(-1.2, 1.2, -0.3), 1)
	local e = emitter(a, { tex = "GLINT", color = V.WHITE, size = NS(0, 5, 1, 2), life = 10, speed = { 18 }, dir = Enum.NormalId.Right, br = 4, z = 2 })
	emit(e, 1)
	flipFx(a, "STAR4", nil :: any, color, NS(0, 3, 1, 0), 10)
	light(p, V.WHITE, 10, 3, 8)
end

--- super armure : flash rouge-orange sur le corps
function V.SuperArmor(char: Model)
	local h = Instance.new("Highlight")
	h.FillColor = V.ARMOR
	h.OutlineColor = Color3.fromHex("FFD0A0")
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = char
	h.Parent = folder()
	V.Animate(8 * FR, function(k)
		h.FillTransparency = 0.15 + 0.85 * k
		h.OutlineTransparency = k
	end, function()
		h:Destroy()
	end)
	local hrp = charParts(char)
	if hrp then
		local _, a = host(hrp.CFrame, 1)
		sparks(a, V.ARMOR, 6, 30, 1, 180)
	end
end

--- burst : sphère d'énergie qui repousse tout
function V.Burst(char: Model, color: Color3)
	local hrp = charParts(char)
	if not hrp then
		return
	end
	local m = meshTemplate("SPHERE"):Clone()
	m.Anchored = true
	m.CanCollide = false
	m.CanQuery = false
	m.CanTouch = false
	m.CastShadow = false
	m.Material = Enum.Material.ForceField
	m.TextureID = V.Tex.HEX_GRID
	m.Color = color
	m.CFrame = hrp.CFrame
	m.Size = Vector3.one * 2
	m.Parent = folder()
	V.Animate(20 * FR, function(k)
		local s = 2 + 18 * (1 - (1 - math.min(k / 0.5, 1)) ^ 3)
		m.Size = Vector3.one * s
		m.Transparency = math.max(0, (k - 0.3) / 0.7)
	end, function()
		m:Destroy()
	end)
	local p, a = host(hrp.CFrame, 2)
	V.Hitstop(4)
	coreFlash(a, 8, 6)
	ring(a, "RING_SOFT", color, 4, 24, 18)
	ring(a, "RING_THIN", V.WHITE, 3, 20, 14)
	sparks(a, color, 20, 70, 2, 180)
	light(p, color, 26, 6, 18)
end

---------------------------------------------------------------------------- 3. MOUVEMENT
function V.DashGround(char: Model, color: Color3, dir: Vector3)
	local cf = feetCF(char)
	local a = dustAt(cf, 2, 5)
	local e = emitter(a, { tex = "PUFF_2x2", grid = 2, color = V.DUST, le = 0, br = 1, size = NS(0, 2, 1, 3.5), life = { 14, 20 }, speed = { 6, 10 }, spread = 20, rot = { 0, 360 } })
	a.WorldCFrame = CFrame.lookAt(cf.Position, cf.Position - dir)
	emit(e, 2)
	V.Ghost(char, color, 8)
end

function V.DashAir(char: Model, color: Color3, dir: Vector3)
	local hrp = charParts(char)
	if not hrp then
		return
	end
	local _, a = host(CFrame.lookAt(hrp.Position, hrp.Position + dir), 1)
	ring(a, "RING_DASHED", color, 3, 7, 12, { orient = "VelocityPerpendicular", speed = { 0.01 } })
	ring(a, "RING_THIN", V.WHITE, 2, 5, 8, { orient = "VelocityPerpendicular", speed = { 0.01 } })
	local e = emitter(a, { tex = "STREAK_V", color = color, size = NS(0, 1.2, 1, 0), life = { 8, 12 }, speed = { 40, 60 }, spread = 12, dir = Enum.NormalId.Back, orient = "VelocityParallel", squash = NS(-1.5), drag = 4 })
	emit(e, 6)
	V.Ghost(char, color, 8)
end

function V.SuperJump(char: Model, color: Color3?)
	local cf = feetCF(char)
	local c = color or Color3.fromHex("DFF6FF")
	local m = meshTemplate("SHOCK_CYLINDER"):Clone()
	m.Anchored = true
	m.CanCollide = false
	m.CanQuery = false
	m.CanTouch = false
	m.CastShadow = false
	m.Material = Enum.Material.ForceField
	m.TextureID = V.Tex.ENERGY_FLOW
	m.Color = c
	m.Parent = folder()
	V.Animate(14 * FR, function(k)
		local h = 2 + 16 * (1 - (1 - math.min(k / 0.4, 1)) ^ 2)
		local r = 3.2 - 1.2 * k
		m.Size = Vector3.new(r, h, r)
		m.CFrame = cf * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, k * 3, 0)
		m.Transparency = 0.1 + 0.9 * k
	end, function()
		m:Destroy()
	end)
	local _, a = host(cf * CFrame.Angles(math.rad(90), 0, 0), 1.5)
	ring(a, "RING_SOFT", c, 2, 10, 12, { orient = "VelocityPerpendicular" })
	dustAt(cf, 2, 5)
end

function V.Land(char: Model)
	local cf = feetCF(char)
	local _, a = host(cf, 1)
	local e = emitter(a, { tex = "PUFF_2x2", grid = 2, color = V.DUST, le = 0, br = 1, size = NS(0, 1.6, 1, 2.8), life = { 12, 18 }, speed = { 5, 9 }, spread = 10, rot = { 0, 360 } })
	a.WorldCFrame = cf * CFrame.Angles(0, math.rad(90), 0)
	emit(e, 1)
	a.WorldCFrame = cf * CFrame.Angles(0, math.rad(-90), 0)
	emit(e, 1)
end

--- chute rapide : onde + fissure
function V.FastFall(char: Model, color: Color3)
	local cf = feetCF(char)
	local m = meshTemplate("SHOCK_RING"):Clone()
	m.Anchored = true
	m.CanCollide = false
	m.CanQuery = false
	m.CanTouch = false
	m.CastShadow = false
	m.Material = Enum.Material.Neon
	m.Color = color
	m.Parent = folder()
	V.Animate(14 * FR, function(k)
		local s = 2 + 12 * (1 - (1 - k) ^ 3)
		m.Size = Vector3.new(s, 0.3 * (1 - k) + 0.05, s)
		m.CFrame = cf
		m.Transparency = k
	end, function()
		m:Destroy()
	end)
	V.Mark(cf, 7, "CRACK_2x2", Color3.new(0.12, 0.1, 0.1), math.random(0, 2), 0.8, 1.0)
	dustAt(cf, 2, 6)
end

--- rebond au mur : fissure verticale ; cf : point de contact, LookVector = normale du mur
function V.WallBounce(cf: CFrame, color: Color3?)
	local wallCF = CFrame.lookAt(cf.Position, cf.Position + cf.LookVector) * CFrame.Angles(math.rad(-90), 0, 0)
	V.Mark(wallCF + cf.LookVector * 0.05, 7, "CRACK_2x2", Color3.new(0.12, 0.1, 0.1), 3, 0.8, 1.0)
	local _, a = host(cf, 2)
	debris(a, 6, 30, 1)
	flipFx(a, "PUFF_2x2", 2, V.DUST, NS(0, 2, 1, 4), 16, { le = 0, br = 1, n = 2, speed = { 4, 8 }, spread = 50 })
	if color then
		flipFx(a, "HITSPARK_LIGHT_4x4", 4, color, 6, 14)
	end
end

--- rebond au sol : cratère + débris
function V.GroundBounce(pos: Vector3, color: Color3?)
	local cf = CFrame.new(pos)
	V.Mark(cf, 10, "CRACK_2x2", Color3.new(0.12, 0.1, 0.1), 2, 1.0, 1.0)
	local _, a = host(cf * CFrame.Angles(math.rad(90), 0, 0), 2)
	debris(a, 10, 40, 1.2)
	ring(a, "RING_SOFT", color or V.DUST, 3, 12, 14, { orient = "VelocityPerpendicular" })
	dustAt(cf, 3, 7)
end

--- chute au sol : poussière
function V.Knockdown(pos: Vector3)
	dustAt(CFrame.new(pos), 3, 6)
end

---------------------------------------------------------------------------- 4. SAISIES
function V.GrabGlint(hand: Instance, color: Color3)
	local cf = if hand:IsA("Attachment") then hand.WorldCFrame else (hand :: BasePart).CFrame
	local _, a = host(cf, 1)
	flipFx(a, "GLINT", nil :: any, V.WHITE, NS(0, 3.5, 1, 0), 10, { rot = { 0, 0 }, br = 4 })
	flipFx(a, "STAR4", nil :: any, color, NS(0, 2, 1, 0), 8, { rot = { 0, 90 } })
end

function V.GrabFinish(cf: CFrame, color: Color3, opts: { [string]: any }?)
	return V.Impact("heavy", cf, color, opts or { hitstop = 8 })
end

--- évasion de saisie : éclair horizontal
function V.GrabEscape(cf: CFrame, color: Color3)
	local p, a = host(cf, 1)
	local l, r = Instance.new("Attachment"), Instance.new("Attachment")
	l.Parent, r.Parent = p, p
	l.Position, r.Position = Vector3.new(-4.5, 0, 0), Vector3.new(4.5, 0, 0)
	V.Lightning(l, r, color, { segs = 7, dur = 12 * FR, jitter = 0.9, width = 0.6 })
	ring(a, "RING_THIN", V.WHITE, 1, 8, 10)
	coreFlash(a, 3, 4)
end

---------------------------------------------------------------------------- 5. SUPER FLASH (lancement d'ultime)
--- écran assombri + reflet horizontal + lignes de vitesse + gel de 10 images
function V.SuperFlash(char: Model, color: Color3, opts: { [string]: any }?)
	local o = opts or {}
	local hrp = charParts(char)
	if not hrp then
		return
	end
	local freeze = o.freeze or 10
	V.Hitstop(freeze)
	if o.onFreeze then
		task.spawn(o.onFreeze, freeze * FR)
	end
	local dark = Instance.new("ColorCorrectionEffect")
	dark.Brightness = -0.35
	dark.Contrast = 0.25
	dark.Saturation = -0.4
	dark.Parent = Lighting
	task.delay(freeze * FR, function() -- en temps réel : l'écran se rallume à la fin du gel
		local t0 = os.clock()
		local c
		c = RunService.RenderStepped:Connect(function()
			local k = math.min((os.clock() - t0) / (8 * FR), 1)
			dark.Brightness = -0.35 * (1 - k)
			dark.Contrast = 0.25 * (1 - k)
			dark.Saturation = -0.4 * (1 - k)
			if k >= 1 then
				c:Disconnect()
				dark:Destroy()
			end
		end)
	end)
	-- reflet horizontal (Beam pour garder le ratio 4:1)
	local p = host(hrp.CFrame * CFrame.new(0, 1, 0), 1.2)
	local cam = camera()
	local right = cam.CFrame.RightVector
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent, a1.Parent = p, p
	a0.WorldPosition = p.Position - right * 9
	a1.WorldPosition = p.Position + right * 9
	local fl = beam(p, a0, a1, { tex = "FLARE_ANAMORPHIC", w = 4.5, br = 5, color = V.WHITE:Lerp(color, 0.25), z = 3 })
	-- étoile + cœur
	local _, a = host(hrp.CFrame * CFrame.new(0, 1, 0), 1.2)
	coreFlash(a, 6, 10)
	flipFx(a, "STAR4", nil :: any, V.WHITE, NS(0, 9, 1, 0), 14, { rot = { 0, 0 } })
	V.SpeedLines("RADIAL", (freeze + 6) * FR, V.WHITE, 0.1)
	-- le reflet suit le temps réel (il doit bouger pendant le gel)
	local t0 = os.clock()
	local c
	c = RunService.RenderStepped:Connect(function()
		local k = (os.clock() - t0) / ((freeze + 6) * FR)
		if k >= 1 or not fl.Parent then
			c:Disconnect()
			if fl.Parent then
				fl:Destroy()
			end
			return
		end
		fl.Width0 = 4.5 * (1 - k)
		fl.Width1 = 4.5 * (1 - k)
	end)
	light(p, color, 18, 6, freeze + 6)
end

---------------------------------------------------------------------------- 6. JAUGE, FATAL
local function auraVolume(char: Model, size: Vector3): Part?
	local hrp = charParts(char)
	if not hrp then
		return nil
	end
	local v = Instance.new("Part")
	v.Name = "BFZ_AuraVolume"
	v.Size = size
	v.Transparency = 1
	v.CanCollide = false
	v.CanQuery = false
	v.CanTouch = false
	v.Massless = true
	v.CastShadow = false
	v.CFrame = hrp.CFrame
	local w = Instance.new("WeldConstraint")
	w.Part0 = v
	w.Part1 = hrp
	w.Parent = v
	v.Parent = char
	return v
end

--- aura de jauge : renvoie un objet avec :SetLevel(0..3) et :Destroy()
function V.GaugeAura(char: Model, color: Color3)
	local vol = auraVolume(char, Vector3.new(3, 5, 2))
	assert(vol, "HumanoidRootPart manquant")
	local motes = emitter(vol, { tex = "MOTE", color = color, size = NS(0, 0.35, 1, 0), life = { 30, 50 }, speed = { 3, 6 }, dir = Enum.NormalId.Top, spread = 10, accel = Vector3.new(0, 2, 0), br = 3 })
	local wisps = emitter(vol, { tex = "WISP_4x4", grid = 4, color = color, size = NS(0, 1.5, 1, 2.5), life = { 24, 32 }, speed = { 2, 4 }, dir = Enum.NormalId.Top, spread = 15, rot = { -20, 20 }, tr = NS(0, 0.2, 1, 0.5) })
	local flames = emitter(vol, {
		tex = "AURA_FLAME_8x8", grid = 8, color = ColorSequence.new({ ColorSequenceKeypoint.new(0, V.WHITE), ColorSequenceKeypoint.new(0.2, color), ColorSequenceKeypoint.new(1, color) }),
		size = NS(0, 2.6, 1, 3.6), life = { 22, 30 }, speed = { 3, 6 }, dir = Enum.NormalId.Top, spread = 8, locked = true, br = 2.5, tr = NS(0, 0.1, 1, 0.3), z = -1,
	})
	for _, e in { motes, wisps, flames } do
		e.Rate = 0
		e.Enabled = true
	end
	local api = {}
	function api:SetLevel(n: number)
		motes.Rate = if n >= 1 then 6 + 4 * n else 0
		wisps.Rate = if n >= 2 then 5 else 0
		flames.Rate = if n >= 3 then 16 else 0
	end
	function api:Destroy()
		for _, e in { motes, wisps, flames } do
			e.Enabled = false
		end
		task.delay(1, function()
			vol:Destroy()
		end)
	end
	return api
end

--- aura de FATAL disponible : rouge électrique qui crépite et pulse ; renvoie {Destroy}
function V.FatalReady(char: Model)
	local vol = auraVolume(char, Vector3.new(3.2, 5.5, 2.2))
	assert(vol, "HumanoidRootPart manquant")
	local flames = emitter(vol, {
		tex = "AURA_FLAME_8x8", grid = 8, color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHex("FFD0D0")), ColorSequenceKeypoint.new(0.25, V.FATAL_RED), ColorSequenceKeypoint.new(1, Color3.fromHex("8B0000")) }),
		size = NS(0, 2.4, 1, 3.4), life = { 20, 28 }, speed = { 3, 5 }, dir = Enum.NormalId.Top, spread = 8, locked = true, rate = 10, tr = NS(0, 0.2, 1, 0.4), z = -1,
	})
	local hl = Instance.new("Highlight")
	hl.FillColor = V.FATAL_RED
	hl.OutlineColor = V.FATAL_RED
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Adornee = char
	hl.Parent = vol
	local alive = true
	local hrp = charParts(char) :: BasePart
	task.spawn(function()
		while alive and vol.Parent do
			-- arcs qui sautent sur le corps (2 éclairs à la fois)
			for _ = 1, 2 do
				local p0 = hrp.Position + Vector3.new(math.random() * 3 - 1.5, math.random() * 5 - 2.5, math.random() * 2 - 1)
				local p1 = p0 + Vector3.new(math.random() * 3 - 1.5, math.random() * 2 - 1, math.random() * 2 - 1)
				V.Lightning(p0, p1, V.FATAL_RED, { segs = 4, dur = 6 * FR, jitter = 0.5, width = 0.18, core = false })
			end
			task.wait(0.12 + math.random() * 0.15)
		end
	end)
	local t0 = os.clock()
	local conn = RunService.Heartbeat:Connect(function()
		local s = 0.5 + 0.5 * math.sin((os.clock() - t0) * 7)
		hl.FillTransparency = 0.9 - 0.3 * s
		hl.OutlineTransparency = 0.6 - 0.4 * s
	end)
	return {
		Destroy = function()
			alive = false
			conn:Disconnect()
			flames.Enabled = false
			hl:Destroy()
			task.delay(1, function()
				vol:Destroy()
			end)
		end,
	}
end

---------------------------------------------------------------------------- 7. ÉTATS
--- soin : anneaux dorés qui montent
function V.Heal(char: Model, color: Color3?)
	local c = color or V.GOLD
	local cf = feetCF(char)
	local _, a = host(cf * CFrame.Angles(math.rad(90), 0, 0), 2)
	local e = emitter(a, { tex = "RING_THIN", color = c, size = NS(0, 3.2, 1, 2.2), tr = NS(0, 0, 0.7, 0.2, 1, 1), life = 40, speed = { 7 }, orient = "VelocityPerpendicular", br = 3 })
	for i = 0, 3 do
		V.After(i * 6 * FR, function()
			emit(e, 1)
		end)
	end
	local _, a2 = host(cf, 2)
	local m = emitter(a2, { tex = "MOTE", color = c, size = NS(0, 0.4, 1, 0), life = { 30, 45 }, speed = { 4, 8 }, dir = Enum.NormalId.Top, spread = 25, br = 3 })
	emit(m, 8)
end

--- retour à la vie : pilier de lumière
function V.Revive(char: Model, color: Color3?)
	local c = color or Color3.fromHex("FFF4C8")
	local cf = feetCF(char)
	local p = host(cf, 2.2)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent, a1.Parent = p, p
	a1.Position = Vector3.new(0, 40, 0)
	local b = beam(p, a1, a0, { tex = "GODRAY", w = 7, br = 4, color = c, faceCamera = true })
	V.Animate(2 * 0.95, function(k)
		local w = 7 * math.sin(math.min(k / 0.15, 1) * math.pi / 2) * (1 - math.max(0, (k - 0.6) / 0.4))
		b.Width0, b.Width1 = w, w
	end)
	local _, a = host(cf * CFrame.Angles(math.rad(90), 0, 0), 2)
	ring(a, "RING_SOFT", c, 2, 12, 20, { orient = "VelocityPerpendicular" })
	local m = emitter(a, { tex = "MOTE", color = c, size = NS(0, 0.5, 1, 0), life = { 40, 60 }, speed = { 8, 14 }, spread = 15, br = 3 })
	emit(m, 16)
	light(p, c, 20, 5, 60)
end

--- PERFECT : anneau doré
function V.Perfect(char: Model)
	local hrp = charParts(char)
	if not hrp then
		return
	end
	local p, a = host(hrp.CFrame, 2)
	ring(a, "RING_SOFT", V.GOLD, 3, 18, 24, { br = 3 })
	ring(a, "RING_THIN", V.WHITE, 2, 14, 18, { br = 4 })
	flipFx(a, "STAR4", nil :: any, V.GOLD, NS(0, 6, 1, 0), 18, { rot = { 0, 0 } })
	local e = emitter(a, { tex = "PETAL_2x2", grid = 2, mode = "Random", color = V.GOLD, size = NS(0, 0.8, 1, 0.4), life = { 40, 60 }, speed = { 10, 18 }, spread = 180, drag = 3, accel = Vector3.new(0, -4, 0), rot = { 0, 360 }, rotSpeed = { -120, 120 } })
	emit(e, 12)
	light(p, V.GOLD, 16, 4, 30)
end

--- étourdissement : 3 étoiles qui tournent au-dessus de la tête ; renvoie {Destroy}
function V.Stun(char: Model, duration: number?)
	local _, head = charParts(char)
	if not head then
		return nil
	end
	local guis = {}
	for i = 1, 3 do
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromScale(1.1, 1.1)
		bb.AlwaysOnTop = false
		bb.LightInfluence = 0
		bb.Adornee = head
		local im = Instance.new("ImageLabel")
		im.BackgroundTransparency = 1
		im.Size = UDim2.fromScale(1, 1)
		im.Image = V.Tex.STAR4
		im.ImageColor3 = V.GOLD
		im.Parent = bb
		bb.Parent = head
		guis[i] = bb
	end
	local alive = true
	local t = 0
	local conn = RunService.Heartbeat:Connect(function(dt)
		t += dt * currentTS
		for i, bb in guis do
			local ang = t * 5 + (i - 1) * math.pi * 2 / 3
			bb.StudsOffsetWorldSpace = Vector3.new(math.cos(ang) * 1.3, 1.6 + 0.15 * math.sin(t * 8 + i), math.sin(ang) * 1.3)
		end
	end)
	local api = {
		Destroy = function()
			if not alive then
				return
			end
			alive = false
			conn:Disconnect()
			for _, bb in guis do
				bb:Destroy()
			end
		end,
	}
	if duration then
		V.After(duration, api.Destroy)
	end
	return api
end

---------------------------------------------------------------------------- 8. K.O.
--- ralenti + image d'impact + flash blanc + carte K.O. (sans lettres)
-- opts : onSlowmo(actif:boolean) pour ralentir le gameplay, slow (0.25), slowTime (1.2 s réelles)
function V.KO(victim: Model, attacker: Model?, color: Color3, opts: { [string]: any }?)
	local o = opts or {}
	local hrp = charParts(victim)
	if not hrp then
		return
	end
	local chars = { victim }
	if attacker then
		table.insert(chars, attacker)
	end
	V.ImpactFrame(chars, 3)
	task.delay(3 * FR, function()
		V.WhiteFlash(2)
		V.Impact("finisher", hrp.CFrame, color, { scale = 1.3 })
		V.SetTimeScale(o.slow or 0.25)
		if o.onSlowmo then
			task.spawn(o.onSlowmo, true)
		end
		V.Vignette(o.slowTime or 1.2, Color3.fromHex("1A0003"), 0.1)
		V.Grade("blood", (o.slowTime or 1.2) * (o.slow or 0.25))
		task.delay(o.slowTime or 1.2, function()
			V.SetTimeScale(1)
			if o.onSlowmo then
				task.spawn(o.onSlowmo, false)
			end
		end)
		V.KOCard(o.cardTime or 1.6)
	end)
end

--- carte K.O. : deux coups de pinceau (rouge puis noir) qui entrent en diagonale, sans lettres
function V.KOCard(hold: number?)
	local h = hold or 1.6
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(0.9, 0.45)
	holder.Rotation = -8
	holder.ZIndex = 60
	holder.Parent = screen()
	local function brush(tex: string, col: Color3, z: number): ImageLabel
		local im = Instance.new("ImageLabel")
		im.BackgroundTransparency = 1
		im.AnchorPoint = Vector2.new(0.5, 0.5)
		im.Size = UDim2.fromScale(1, 1)
		im.Image = V.Tex[tex]
		im.ImageColor3 = col
		im.ZIndex = z
		im.Parent = holder
		return im
	end
	local red = brush("KO_BRUSH_A", Color3.fromHex("E0102E"), 61)
	local black = brush("KO_BRUSH_B", Color3.fromHex("0A0506"), 62)
	-- entrée sur 6 images en temps réel (la carte ne doit pas ralentir avec le K.O.)
	local t0 = os.clock()
	local c
	c = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local kin = math.min(t / (6 * FR), 1)
		local e = 1 - (1 - kin) ^ 3
		red.Position = UDim2.fromScale(0.5 - 0.8 * (1 - e), 0.5 + 0.1 * (1 - e))
		local kb = math.clamp((t - 3 * FR) / (6 * FR), 0, 1)
		local eb = 1 - (1 - kb) ^ 3
		black.Position = UDim2.fromScale(0.5 + 0.8 * (1 - eb), 0.62 - 0.1 * (1 - eb))
		local kout = math.clamp((t - h) / 0.25, 0, 1)
		red.ImageTransparency = kout
		black.ImageTransparency = kout
		if kout >= 1 then
			c:Disconnect()
			holder:Destroy()
		end
	end)
	return holder
end

return V
