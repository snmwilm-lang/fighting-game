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
		part("PagodaWall", Vector3.new(width - 4, 5, 6), Vector3.new(34, y, -46), "120608", Enum.Material.Wood)
		part("PagodaRoof", Vector3.new(width + 3, 0.9, 9), Vector3.new(34, y + 2.9, -46), "0B0B0E")
		part("PagodaLight", Vector3.new(width - 5, 1.2, 0.2), Vector3.new(34, y - 0.4, -42.9), "FF3B4E", Enum.Material.Neon)
	end

	-- Floor: wooden temple deck (built-in WoodPlanks material) with painted plank lines, a worn
	-- lighter fighting area in the middle and stone steps in front.
	part("Floor", Vector3.new(80, 2, 22), Vector3.new(0, -1, 0), "4A3230", Enum.Material.WoodPlanks, true)
	part("FloorShade", Vector3.new(80, 0.02, 8), Vector3.new(0, 0.01, -7), "2C1F21", Enum.Material.WoodPlanks)
	part("FloorWorn", Vector3.new(60, 0.015, 7), Vector3.new(0, 0.008, 0.5), "5C403A", Enum.Material.WoodPlanks)
	for z = -9, 9, 3 do
		part("Plank", Vector3.new(80, 0.03, 0.08), Vector3.new(0, 0.02, z), "1A1214")
	end
	part("Step", Vector3.new(86, 1.2, 4), Vector3.new(0, -1.6, 12.5), "2A2328", Enum.Material.Slate)
	part("StepLower", Vector3.new(90, 1.2, 4), Vector3.new(0, -2.8, 15.5), "211C20", Enum.Material.Slate)
	part("FrontTrim", Vector3.new(80, 0.18, 0.2), Vector3.new(0, -0.1, 11.05), "FF2A3D", Enum.Material.Neon)
	for _, x in { -28, 28 } do -- arena limits painted on the deck
		part("Boundary", Vector3.new(0.18, 0.04, 20), Vector3.new(x, 0.04, 0), "F5EDE6", Enum.Material.Neon)
	end

	-- Torii gate framing the fight.
	local toriiRed = "C8102E"
	for _, x in { -24, 24 } do
		part("ToriiPillar", Vector3.new(1.8, 22, 1.8), Vector3.new(x, 10, -14), toriiRed)
		part("ToriiBase", Vector3.new(2.6, 1.4, 2.6), Vector3.new(x, 0.2, -14), "1C171B", Enum.Material.Slate)
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
		part("LanternPole", Vector3.new(0.4, 7, 0.4), Vector3.new(x, 3.5, -10), "0B0B0E", Enum.Material.Wood)
		local lantern = part("Lantern", Vector3.new(1.6, 2.2, 1.6), Vector3.new(x, 7.6, -10), "FF5A4E", Enum.Material.Neon)
		lantern.Shape = Enum.PartType.Cylinder
		lantern.Size = Vector3.new(2.2, 1.7, 1.7)
		lantern.CFrame = CFrame.new(x, 7.6, -10) * CFrame.Angles(0, 0, math.pi / 2)
		part("LanternCap", Vector3.new(1.9, 0.3, 1.9), Vector3.new(x, 8.85, -10), "0B0B0E")
		part("LanternFoot", Vector3.new(1.5, 0.25, 1.5), Vector3.new(x, 6.4, -10), "0B0B0E")
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness, light.Shadows = hex("FF6A50"), 18, 1.6, true
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
		local cloth = part("Banner", Vector3.new(4.6, 15, 0.12), CFrame.new(x, 19.5, z) * CFrame.Angles(0, 0, math.rad(if i % 2 == 0 then 2 else -2)), "8E1020", Enum.Material.Fabric)
		local gui = Instance.new("SurfaceGui")
		gui.Face, gui.LightInfluence, gui.CanvasSize = Enum.NormalId.Front, 0.4, Vector2.new(200, 650)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency, label.Size, label.Position = 1, UDim2.fromScale(1, 0.5), UDim2.fromScale(0, 0.1)
		label.Text, label.TextScaled, label.Font = kanji, true, Enum.Font.GothamBlack
		label.TextColor3, label.TextTransparency = Color3.fromHex("0B0B0E"), 0.1
		label.Parent = gui
		gui.Parent = cloth
		part("BannerTail", Vector3.new(4.6, 1.2, 0.1), CFrame.new(x + 0.6, 11.4, z) * CFrame.Angles(0, 0, -0.25), "8E1020", Enum.Material.Fabric)
	end
	local ruins = { { -44, 12, -18 }, { -38, 7, -30 }, { 40, 9, -20 }, { 46, 14, -32 }, { -20, 5, -34 }, { 24, 6, -36 } }
	for i, ruin in ruins do
		local x, h, z = ruin[1], ruin[2], ruin[3]
		part("RuinPillar", Vector3.new(2.6, h, 2.6), CFrame.new(x, h / 2 - 1, z) * CFrame.Angles(0, math.rad(i * 23), math.rad((i % 3 - 1) * 6)), "3A3238", Enum.Material.Slate)
		part("RuinCap", Vector3.new(3.2, 0.8, 3.2), CFrame.new(x + (i % 2) * 0.6, h - 0.6, z) * CFrame.Angles(0, math.rad(i * 17), math.rad((i % 2) * 14)), "2A2328", Enum.Material.Slate)
		for r = 1, 3 do
			part("Rubble", Vector3.new(1 + r * 0.4, 0.6 + r * 0.2, 1.2), CFrame.new(x + r * 1.7 - 3, 0, z + r) * CFrame.Angles(0, math.rad(r * 40 + i * 11), math.rad(r * 12)), "2E272C", Enum.Material.Cobblestone)
		end
	end

	-- Cherry trees between the torii and the mountains: a second depth layer of pink canopy.
	local trees = { { -50, -30, 1.1 }, { -32, -40, 0.9 }, { 52, -28, 1.0 }, { 18, -44, 0.8 }, { -4, -48, 0.75 } }
	for i, tree in trees do
		local x, z, k = tree[1], tree[2], tree[3]
		part("TreeTrunk", Vector3.new(1.4 * k, 14 * k, 1.4 * k), CFrame.new(x, 7 * k - 1, z) * CFrame.Angles(0, 0, math.rad((i % 3 - 1) * 8)), "1A1013", Enum.Material.Wood)
		for b = 1, 6 do
			local angle = b * 1.05 + i
			local blossom = part("Blossom", Vector3.one * (6 + (b % 3) * 1.6) * k,
				Vector3.new(x + math.cos(angle) * 4 * k, (13 + (b % 2) * 2.4) * k, z + math.sin(angle) * 2.5 * k),
				if b % 3 == 0 then "F28FA0" elseif b % 3 == 1 then "E86F84" else "FFC2CC", Enum.Material.SmoothPlastic)
			blossom.Shape = Enum.PartType.Ball
		end
	end

	-- Embers rising from the deck and a thin mist on the floor. Engine-provided particle
	-- textures only (rbxasset:// paths shipped with every Roblox client, no asset id).
	local emberSource = part("EmberSource", Vector3.new(80, 0.2, 18), Vector3.new(0, 0.2, -2), "FFFFFF")
	emberSource.Transparency = 1
	local embers = Instance.new("ParticleEmitter")
	embers.Name = "Embers"
	embers.Color = ColorSequence.new(hex("FFD9A0"), hex("FF2A3D"))
	embers.LightEmission, embers.LightInfluence = 1, 0
	embers.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.14), NumberSequenceKeypoint.new(1, 0) })
	embers.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0),
		NumberSequenceKeypoint.new(1, 1) })
	embers.Rate, embers.Lifetime = 7, NumberRange.new(4, 7)
	embers.Speed, embers.SpreadAngle = NumberRange.new(1.5, 4), Vector2.new(25, 25)
	embers.Acceleration, embers.Drag = Vector3.new(0.8, 1.2, 0), 0.4
	embers.EmissionDirection = Enum.NormalId.Top
	embers.Parent = emberSource
	local mistSource = part("MistSource", Vector3.new(90, 0.2, 10), Vector3.new(0, 0.3, -8), "FFFFFF")
	mistSource.Transparency = 1
	local mist = Instance.new("ParticleEmitter")
	mist.Name = "FloorMist"
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(hex("C85060"))
	mist.LightInfluence, mist.LightEmission = 0.6, 0.15
	mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 10) })
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.88),
		NumberSequenceKeypoint.new(1, 1) })
	mist.Rate, mist.Lifetime = 1.6, NumberRange.new(10, 14)
	mist.Speed, mist.SpreadAngle = NumberRange.new(0.3, 0.8), Vector2.new(80, 10)
	mist.Rotation, mist.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-6, 6)
	mist.Acceleration = Vector3.new(0.4, 0, 0)
	mist.Parent = mistSource

	arena.Parent = workspace

	-- Warm sunset lighting: low environment shading keeps colours as solid fills (cel look),
	-- crisp sun shadows ground the fighters on the deck.
	Lighting.ClockTime, Lighting.Brightness = 17.4, 2.4
	Lighting.GeographicLatitude = 25
	Lighting.Ambient = hex("8E7276")
	Lighting.OutdoorAmbient = hex("A88286")
	Lighting.EnvironmentDiffuseScale, Lighting.EnvironmentSpecularScale = 0.15, 0.1
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.12
	local function effect(className, name, props)
		local old = Lighting:FindFirstChild(name)
		if old then old:Destroy() end
		local e = Instance.new(className)
		e.Name = name
		for k, v in props do e[k] = v end
		e.Parent = Lighting
		return e
	end
	effect("ColorCorrectionEffect", "ArenaGrade", { Contrast = 0.18, Saturation = 0.22, TintColor = hex("FFF0EE") })
	effect("BloomEffect", "ArenaBloom", { Intensity = 0.75, Size = 28, Threshold = 1.25 })
	effect("SunRaysEffect", "ArenaSunRays", { Intensity = 0.05, Spread = 0.55 })
	effect("Atmosphere", "ArenaAtmosphere", { Density = 0.32, Offset = 0.1, Color = hex("A8283A"), Decay = hex("1F070C"), Glare = 0.4, Haze = 1.5 })
	return arena
end

return ArenaBuilder
