-- "Temple écarlate": an original anime-style stage in the black / white / red palette of
-- the KAI art direction sheet, built from plain parts.
-- Everything lives in Workspace.Arena; lighting effects are named "Arena*" in Lighting.
local Lighting = game:GetService("Lighting")
local ArenaBuilder = {}

local function hex(color)
	return Color3.fromHex(color)
end

function ArenaBuilder.build()
	local arena = Instance.new("Model")
	arena.Name = "Arena"
	local function part(name, size, cframe, color, material, collide)
		local p = Instance.new("Part")
		p.Name, p.Size = name, size
		p.CFrame = if typeof(cframe) == "Vector3" then CFrame.new(cframe) else cframe
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, collide == true, false, false
		p.Material, p.Color = material or Enum.Material.SmoothPlastic, hex(color)
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.CastShadow = false
		p.Parent = arena
		return p
	end
	local function wedge(name, size, cframe, color)
		local w = Instance.new("WedgePart")
		w.Name, w.Size, w.CFrame = name, size, cframe
		w.Anchored, w.CanCollide, w.CanTouch, w.CanQuery = true, false, false, false
		w.Material, w.Color, w.CastShadow = Enum.Material.SmoothPlastic, hex(color), false
		w.Parent = arena
		return w
	end

	-- Sky: flat painted bands, like an anime background plate.
	local bands = { { 30, "C4182F" }, { 42, "7A0F1F" }, { 54, "420A14" }, { 70, "1F070C" }, { 88, "0C0508" } }
	for i, band in bands do
		local bottom = if i == 1 then -6 else bands[i - 1][1]
		local height = band[1] - bottom
		part("SkyBand", Vector3.new(320, height, 1), Vector3.new(0, bottom + height / 2, -90), band[2])
	end
	local sun = part("Sun", Vector3.new(1, 34, 34), CFrame.new(-18, 22, -88) * CFrame.Angles(0, math.pi / 2, 0),
		"F5EDE6", Enum.Material.Neon)
	sun.Shape = Enum.PartType.Cylinder
	for i = 1, 3 do -- stripes cut through the sun, a classic retro anime motif
		part("SunStripe", Vector3.new(36, 0.8 + i * 0.35, 0.5), Vector3.new(-18, 12 + i * 3.2, -87.4), "C4182F")
	end

	-- Mountain silhouettes in three depth layers.
	local layers = { { -78, "5A0C18", 26 }, { -66, "2E0810", 20 }, { -52, "140508", 14 } }
	for li, layer in layers do
		local z, color, height = layer[1], layer[2], layer[3]
		for i = -6, 6 do
			local h = height * (0.55 + ((i * i * 13 + li * 7) % 10) / 20)
			local w = 18 + (i * 7 + li) % 9
			local x = i * 22 + li * 7
			wedge("Mountain", Vector3.new(2, h, w / 2), CFrame.new(x - w / 4, h / 2 - 4, z) * CFrame.Angles(0, math.pi / 2, 0), color)
			wedge("Mountain", Vector3.new(2, h, w / 2), CFrame.new(x + w / 4, h / 2 - 4, z) * CFrame.Angles(0, -math.pi / 2, 0), color)
		end
	end

	-- Pagoda silhouette on the right.
	for level = 0, 3 do
		local width = 16 - level * 3
		local y = 4 + level * 6
		part("PagodaWall", Vector3.new(width - 4, 5, 6), Vector3.new(34, y, -46), "120608")
		part("PagodaRoof", Vector3.new(width + 3, 0.9, 9), Vector3.new(34, y + 2.9, -46), "0B0B0E")
		part("PagodaLight", Vector3.new(width - 5, 1.2, 0.2), Vector3.new(34, y - 0.4, -42.9), "FF3B4E", Enum.Material.Neon)
	end

	-- Floor: wooden temple deck with painted plank lines.
	part("Floor", Vector3.new(80, 2, 22), Vector3.new(0, -1, 0), "3A2A2C", Enum.Material.SmoothPlastic, true)
	part("FloorShade", Vector3.new(80, 0.02, 8), Vector3.new(0, 0.01, -7), "2C1F21")
	for z = -9, 9, 3 do
		part("Plank", Vector3.new(80, 0.03, 0.08), Vector3.new(0, 0.02, z), "1A1214")
	end
	part("Step", Vector3.new(86, 1.2, 4), Vector3.new(0, -1.6, 12.5), "1A1214")
	part("FrontTrim", Vector3.new(80, 0.18, 0.2), Vector3.new(0, -0.1, 11.05), "FF2A3D", Enum.Material.Neon)
	for _, x in { -28, 28 } do -- arena limits painted on the deck
		part("Boundary", Vector3.new(0.18, 0.04, 20), Vector3.new(x, 0.04, 0), "F5EDE6", Enum.Material.Neon)
	end

	-- Torii gate framing the fight.
	local toriiRed = "C8102E"
	for _, x in { -24, 24 } do
		part("ToriiPillar", Vector3.new(1.8, 22, 1.8), Vector3.new(x, 10, -14), toriiRed)
		part("ToriiBase", Vector3.new(2.6, 1.4, 2.6), Vector3.new(x, 0.2, -14), "0B0B0E")
	end
	part("ToriiNuki", Vector3.new(54, 1.4, 1.2), Vector3.new(0, 16, -14), toriiRed)
	part("ToriiKasagi", Vector3.new(62, 1.8, 2.4), Vector3.new(0, 20.6, -14), "0B0B0E")
	part("ToriiShimaki", Vector3.new(58, 1.2, 2), Vector3.new(0, 19.3, -14), toriiRed)
	for _, side in { -1, 1 } do
		wedge("ToriiTip", Vector3.new(2.4, 1.6, 3), CFrame.new(side * 32.4, 21, -14) * CFrame.Angles(0, side * -math.pi / 2, 0), "0B0B0E")
	end
	part("ToriiPlaque", Vector3.new(4, 3.2, 0.4), Vector3.new(0, 18, -13.3), "0B0B0E")

	-- Paper lanterns with warm light.
	for _, x in { -36, -16, 16, 36 } do
		part("LanternPole", Vector3.new(0.4, 7, 0.4), Vector3.new(x, 3.5, -10), "0B0B0E")
		local lantern = part("Lantern", Vector3.new(1.6, 2.2, 1.6), Vector3.new(x, 7.6, -10), "FF5A4E", Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = hex("FF5A4E"), 16, 1.4
		light.Parent = lantern
	end

	-- Drifting embers and petals (built-in sparkle texture tinted, no external asset).
	local emitterPart = part("PetalSource", Vector3.new(90, 1, 30), Vector3.new(0, 30, -6), "FFFFFF")
	emitterPart.Transparency = 1
	local petals = Instance.new("ParticleEmitter")
	petals.Name = "Petals"
	petals.Color = ColorSequence.new(hex("FFE3E7"), hex("FF6B7D"))
	petals.Size = NumberSequence.new(0.35)
	petals.Rate = 9
	petals.Lifetime = NumberRange.new(9, 13)
	petals.Speed = NumberRange.new(1, 3)
	petals.Acceleration = Vector3.new(1.5, -2.2, 0)
	petals.SpreadAngle = Vector2.new(30, 30)
	petals.EmissionDirection = Enum.NormalId.Bottom
	petals.Rotation = NumberRange.new(0, 360)
	petals.RotSpeed = NumberRange.new(-90, 90)
	petals.LightEmission = 0.3
	petals.Parent = emitterPart

	-- Ruined temple dressing (backgrounds of the cinematic wide shots): hanging war banners
	-- painted with kanji, broken stone pillars and rubble.
	local banners = { { -30, "闘" }, { -12, "魂" }, { 12, "開" }, { 30, "炎" } }
	for i, banner in banners do
		local x, kanji = banner[1], banner[2]
		local z = if i % 2 == 0 then -22 else -26
		part("BannerPole", Vector3.new(0.5, 30, 0.5), Vector3.new(x - 2.6, 13, z), "0B0B0E")
		part("BannerArm", Vector3.new(6, 0.4, 0.4), Vector3.new(x, 27.6, z), "0B0B0E")
		local cloth = part("Banner", Vector3.new(4.6, 15, 0.12), CFrame.new(x, 19.5, z) * CFrame.Angles(0, 0, math.rad(if i % 2 == 0 then 2 else -2)), "8E1020")
		local gui = Instance.new("SurfaceGui")
		gui.Face, gui.LightInfluence, gui.CanvasSize = Enum.NormalId.Front, 0.4, Vector2.new(200, 650)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency, label.Size, label.Position = 1, UDim2.fromScale(1, 0.5), UDim2.fromScale(0, 0.1)
		label.Text, label.TextScaled, label.Font = kanji, true, Enum.Font.GothamBlack
		label.TextColor3, label.TextTransparency = Color3.fromHex("0B0B0E"), 0.1
		label.Parent = gui
		gui.Parent = cloth
		part("BannerTail", Vector3.new(4.6, 1.2, 0.1), CFrame.new(x + 0.6, 11.4, z) * CFrame.Angles(0, 0, -0.25), "8E1020")
	end
	local ruins = { { -44, 12, -18 }, { -38, 7, -30 }, { 40, 9, -20 }, { 46, 14, -32 }, { -20, 5, -34 }, { 24, 6, -36 } }
	for i, ruin in ruins do
		local x, h, z = ruin[1], ruin[2], ruin[3]
		part("RuinPillar", Vector3.new(2.6, h, 2.6), CFrame.new(x, h / 2 - 1, z) * CFrame.Angles(0, math.rad(i * 23), math.rad((i % 3 - 1) * 6)), "2A2328")
		part("RuinCap", Vector3.new(3.2, 0.8, 3.2), CFrame.new(x + (i % 2) * 0.6, h - 0.6, z) * CFrame.Angles(0, math.rad(i * 17), math.rad((i % 2) * 14)), "1C171B")
		for r = 1, 3 do
			part("Rubble", Vector3.new(1 + r * 0.4, 0.6 + r * 0.2, 1.2), CFrame.new(x + r * 1.7 - 3, 0, z + r) * CFrame.Angles(0, math.rad(r * 40 + i * 11), math.rad(r * 12)), "241E22")
		end
	end

	arena.Parent = workspace

	-- Flat, warm lighting: low environment shading keeps colors as solid fills (cel look).
	Lighting.ClockTime, Lighting.Brightness = 17.4, 2.2
	Lighting.Ambient = hex("8E7276")
	Lighting.OutdoorAmbient = hex("A88286")
	Lighting.EnvironmentDiffuseScale, Lighting.EnvironmentSpecularScale = 0, 0
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0
	local function effect(className, name, props)
		local old = Lighting:FindFirstChild(name)
		if old then old:Destroy() end
		local e = Instance.new(className)
		e.Name = name
		for k, v in props do e[k] = v end
		e.Parent = Lighting
		return e
	end
	effect("ColorCorrectionEffect", "ArenaGrade", { Contrast = 0.15, Saturation = 0.18, TintColor = hex("FFF0F0") })
	effect("BloomEffect", "ArenaBloom", { Intensity = 0.6, Size = 30, Threshold = 1.4 })
	effect("Atmosphere", "ArenaAtmosphere", { Density = 0.3, Offset = 0.1, Color = hex("A8283A"), Decay = hex("1F070C"), Glare = 0.4, Haze = 1.4 })
	return arena
end

return ArenaBuilder
