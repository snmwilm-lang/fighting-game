--[[
	The stages, built on each client from shared/Maps (several matches share a server, each
	player sees the stage of its own match; the menu shows the default one). Every stage keeps
	the same fighting ground: a deck at y = 0 from x = -28 to 28, painted limits, a neon edge.
	Only plain parts, built-in materials and the engine's own particle textures (no asset id).
	Everything lives in Workspace.Arena (local to this client); its lighting effects are named
	"Arena*" in Lighting. StageController animates the parts named Lantern (flicker) and
	Banner / BannerTail (sway).
]]
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Maps = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Maps"))

local ArenaBuilder = {}

local function hex(color)
	return Color3.fromHex(color)
end

local function material(name)
	local ok, value = pcall(function() return Enum.Material[name] end)
	return if ok and value then value else Enum.Material.SmoothPlastic
end

-- ===================================================================== shared pieces
local function kit(arena)
	local B = {}
	function B.part(name, size, cframe, color, mat, collide)
		local p = Instance.new("Part")
		p.Name, p.Size = name, size
		p.CFrame = if typeof(cframe) == "Vector3" then CFrame.new(cframe) else cframe
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, collide == true, false, false
		p.Material, p.Color = mat or Enum.Material.SmoothPlastic, hex(color)
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.CastShadow = false
		p.Parent = arena
		return p
	end
	function B.wedge(name, size, cframe, color)
		local w = Instance.new("WedgePart")
		w.Name, w.Size, w.CFrame = name, size, cframe
		w.Anchored, w.CanCollide, w.CanTouch, w.CanQuery = true, false, false, false
		w.Material, w.Color, w.CastShadow = Enum.Material.SmoothPlastic, hex(color), false
		w.Parent = arena
		return w
	end
	function B.ball(name, size, position, color, mat)
		local b = B.part(name, Vector3.one * size, position, color, mat)
		b.Shape = Enum.PartType.Ball
		return b
	end
	function B.cylinder(name, length, width, cframe, color, mat)
		local c = B.part(name, Vector3.new(length, width, width), cframe, color, mat)
		c.Shape = Enum.PartType.Cylinder
		return c
	end
	-- A lamp the stage flickers: a glowing part named Lantern with its light.
	function B.lamp(size, position, color, range, shape)
		local l = B.part("Lantern", size, position, color, Enum.Material.Neon)
		if shape then l.Shape = shape end
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness, light.Shadows = hex(color), range or 18, 1.6, true
		light.Parent = l
		return l
	end
	-- A hanging cloth with a kanji (sways: Banner / BannerTail).
	function B.banner(x, z, height, color, ink, kanji, tilt)
		B.part("BannerPole", Vector3.new(0.5, height + 15, 0.5), Vector3.new(x - 2.6, (height + 15) / 2 - 2, z), ink)
		B.part("BannerArm", Vector3.new(6, 0.4, 0.4), Vector3.new(x, height + 12.6, z), ink)
		local cloth = B.part("Banner", Vector3.new(4.6, 15, 0.12), CFrame.new(x, height + 4.5, z) * CFrame.Angles(0, 0, math.rad(tilt or 0)),
			color, Enum.Material.Fabric)
		local gui = Instance.new("SurfaceGui")
		gui.Face, gui.LightInfluence, gui.CanvasSize = Enum.NormalId.Front, 0.4, Vector2.new(200, 650)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency, label.Size, label.Position = 1, UDim2.fromScale(1, 0.5), UDim2.fromScale(0, 0.1)
		label.Text, label.TextScaled, label.Font = kanji, true, Enum.Font.GothamBlack
		label.TextColor3, label.TextTransparency = hex(ink), 0.1
		label.Parent = gui
		gui.Parent = cloth
		B.part("BannerTail", Vector3.new(4.6, 1.2, 0.1), CFrame.new(x + 0.6, height - 3.6, z) * CFrame.Angles(0, 0, -0.25), color, Enum.Material.Fabric)
		return cloth
	end
	function B.sign(text, size, position, color, back)
		local board = B.part("Sign", size, position, back, Enum.Material.SmoothPlastic)
		local gui = Instance.new("SurfaceGui")
		gui.Face, gui.LightInfluence, gui.CanvasSize = Enum.NormalId.Front, 0, Vector2.new(size.X * 50, size.Y * 50)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency, label.Size = 1, UDim2.fromScale(1, 1)
		label.Text, label.TextScaled, label.Font, label.TextColor3 = text, true, Enum.Font.GothamBlack, hex(color)
		label.Parent = gui
		gui.Parent = board
		B.part("SignGlow", Vector3.new(size.X + 0.4, size.Y + 0.4, 0.05), position - Vector3.new(0, 0, 0.12), color, Enum.Material.Neon)
		return board
	end
	return B
end

-- Sky bands, the sun or moon, three layers of hills.
local function backdrop(B, map, hillShape)
	for i, band in map.sky do
		local bottom = if i == 1 then -6 else map.sky[i - 1][1]
		local height = band[1] - bottom
		B.part("SkyBand", Vector3.new(320, height, 1), Vector3.new(0, bottom + height / 2, -90), band[2])
	end
	local orb = map.orb
	local sun = B.cylinder("Sun", 1, orb.size, CFrame.new(orb.x, orb.y, -88) * CFrame.Angles(0, math.pi / 2, 0), orb.color, Enum.Material.Neon)
	sun.Size = Vector3.new(1, orb.size, orb.size)
	if orb.stripes then
		for i = 1, 3 do
			B.part("SunStripe", Vector3.new(orb.size + 2, 0.8 + i * 0.35, 0.5), Vector3.new(orb.x, orb.y - orb.size * 0.3 + i * 3.2, -87.4), orb.stripes)
		end
	end
	local depths = { { -78, 26 }, { -66, 20 }, { -52, 14 } }
	for li, layer in depths do
		local z, height, color = layer[1], layer[2], map.hills[li]
		for i = -6, 6 do
			local h = height * (0.55 + ((i * i * 13 + li * 7) % 10) / 20)
			local w = 18 + (i * 7 + li) % 9
			local x = i * 22 + li * 7
			if hillShape == "blocks" then -- a skyline
				B.part("Building", Vector3.new(w * 0.6, h * 1.6, 6), Vector3.new(x, h * 0.8 - 4, z), color)
			elseif hillShape == "clouds" then
				B.ball("Cloud", w * 0.9, Vector3.new(x, h * 0.25 - 6, z), color)
			else
				B.wedge("Mountain", Vector3.new(2, h, w / 2), CFrame.new(x - w / 4, h / 2 - 4, z) * CFrame.Angles(0, math.pi / 2, 0), color)
				B.wedge("Mountain", Vector3.new(2, h, w / 2), CFrame.new(x + w / 4, h / 2 - 4, z) * CFrame.Angles(0, -math.pi / 2, 0), color)
			end
		end
	end
end

-- The fighting ground: the same on every stage (only its look changes).
local function deck(B, map)
	local f = map.floor
	local mat = material(f.material)
	B.part("Floor", Vector3.new(80, 2, 22), Vector3.new(0, -1, 0), f.color, mat, true)
	B.part("FloorShade", Vector3.new(80, 0.02, 8), Vector3.new(0, 0.01, -7), f.line, mat).Transparency = 0.5
	B.part("FloorWorn", Vector3.new(60, 0.015, 7), Vector3.new(0, 0.008, 0.5), f.worn, mat)
	for z = -9, 9, 3 do
		B.part("Plank", Vector3.new(80, 0.03, 0.08), Vector3.new(0, 0.02, z), f.line)
	end
	B.part("Step", Vector3.new(86, 1.2, 4), Vector3.new(0, -1.6, 12.5), f.line, mat)
	B.part("StepLower", Vector3.new(90, 1.2, 4), Vector3.new(0, -2.8, 15.5), f.line, mat).Transparency = 0.2
	B.part("FrontTrim", Vector3.new(80, 0.18, 0.2), Vector3.new(0, -0.1, 11.05), f.trim, Enum.Material.Neon)
	for _, x in { -28, 28 } do -- the arena limits painted on the deck
		B.part("Boundary", Vector3.new(0.18, 0.04, 20), Vector3.new(x, 0.04, 0), f.trim, Enum.Material.Neon)
	end
end

-- Falling or rising particles (engine textures only) and the ground mist.
local AIR = {
	petals = { size = 0.35, speed = { 1, 3 }, accel = Vector3.new(1.5, -2.2, 0), life = { 9, 13 }, from = 30, down = true },
	leaves = { size = 0.45, speed = { 1, 3 }, accel = Vector3.new(2, -2.6, 0), life = { 8, 12 }, from = 30, down = true },
	snow = { size = 0.22, speed = { 2, 4 }, accel = Vector3.new(0.6, -1.6, 0), life = { 10, 14 }, from = 30, down = true },
	feathers = { size = 0.5, speed = { 0.5, 1.5 }, accel = Vector3.new(0.8, -1, 0), life = { 12, 16 }, from = 30, down = true },
	rain = { size = 0.09, speed = { 55, 70 }, accel = Vector3.new(0, -20, 0), life = { 0.6, 0.9 }, from = 34, down = true, streak = true },
	embers = { size = 0.16, speed = { 2, 5 }, accel = Vector3.new(0.8, 2, 0), life = { 4, 7 }, from = 0.2, down = false, glow = true },
}
local function air(B, map)
	local spec = AIR[map.air.kind] or AIR.petals
	local source = B.part("AirSource", Vector3.new(90, 1, 30), Vector3.new(0, spec.from, -6), "FFFFFF")
	source.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Name = "Air"
	e.Color = ColorSequence.new(hex(map.air.colors[1]), hex(map.air.colors[2]))
	e.Size = if spec.streak then NumberSequence.new(spec.size) else NumberSequence.new(spec.size)
	if spec.streak then
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
		e.Squash = NumberSequence.new(-3)
	end
	e.Rate = map.air.rate
	e.Lifetime = NumberRange.new(spec.life[1], spec.life[2])
	e.Speed = NumberRange.new(spec.speed[1], spec.speed[2])
	e.Acceleration = spec.accel
	e.SpreadAngle = Vector2.new(30, 30)
	e.EmissionDirection = if spec.down then Enum.NormalId.Bottom else Enum.NormalId.Top
	e.Rotation, e.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-90, 90)
	e.LightEmission = if spec.glow then 1 else 0.3
	if spec.glow then
		e.LightInfluence = 0
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0), NumberSequenceKeypoint.new(1, 1) })
	end
	e.Parent = source
	local mistSource = B.part("MistSource", Vector3.new(90, 0.2, 10), Vector3.new(0, 0.3, -8), "FFFFFF")
	mistSource.Transparency = 1
	local mist = Instance.new("ParticleEmitter")
	mist.Name = "FloorMist"
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(hex(map.mist))
	mist.LightInfluence, mist.LightEmission = 0.6, 0.15
	mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 10) })
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.88), NumberSequenceKeypoint.new(1, 1) })
	mist.Rate, mist.Lifetime = 1.6, NumberRange.new(10, 14)
	mist.Speed, mist.SpreadAngle = NumberRange.new(0.3, 0.8), Vector2.new(80, 10)
	mist.Rotation, mist.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-6, 6)
	mist.Acceleration = Vector3.new(0.4, 0, 0)
	mist.Parent = mistSource
end

-- ===================================================================== each stage's dressing
local PROPS = {}

-- SCARLET TEMPLE: pagoda, torii, paper lanterns, war banners, ruins, cherry trees.
function PROPS.temple(B, map)
	local frame, dark = map.frame.color, map.frame.dark
	for level = 0, 3 do
		local width = 16 - level * 3
		local y = 4 + level * 6
		B.part("PagodaWall", Vector3.new(width - 4, 5, 6), Vector3.new(34, y, -46), "120608", Enum.Material.Wood)
		B.part("PagodaRoof", Vector3.new(width + 3, 0.9, 9), Vector3.new(34, y + 2.9, -46), dark)
		B.part("PagodaLight", Vector3.new(width - 5, 1.2, 0.2), Vector3.new(34, y - 0.4, -42.9), "FF3B4E", Enum.Material.Neon)
	end
	for _, x in { -24, 24 } do
		B.part("ToriiPillar", Vector3.new(1.8, 22, 1.8), Vector3.new(x, 10, -14), frame)
		B.part("ToriiBase", Vector3.new(2.6, 1.4, 2.6), Vector3.new(x, 0.2, -14), "1C171B", Enum.Material.Slate)
	end
	B.part("ToriiNuki", Vector3.new(54, 1.4, 1.2), Vector3.new(0, 16, -14), frame)
	B.part("ToriiKasagi", Vector3.new(62, 1.8, 2.4), Vector3.new(0, 20.6, -14), dark)
	B.part("ToriiShimaki", Vector3.new(58, 1.2, 2), Vector3.new(0, 19.3, -14), frame)
	for _, side in { -1, 1 } do
		B.wedge("ToriiTip", Vector3.new(2.4, 1.6, 3), CFrame.new(side * 32.4, 21, -14) * CFrame.Angles(0, side * -math.pi / 2, 0), dark)
	end
	B.part("ToriiPlaque", Vector3.new(4, 3.2, 0.4), Vector3.new(0, 18, -13.3), dark)
	for _, x in { -36, -16, 16, 36 } do
		B.part("LanternPole", Vector3.new(0.4, 7, 0.4), Vector3.new(x, 3.5, -10), dark, Enum.Material.Wood)
		local lantern = B.lamp(Vector3.new(2.2, 1.7, 1.7), CFrame.new(x, 7.6, -10) * CFrame.Angles(0, 0, math.pi / 2), map.light, 18,
			Enum.PartType.Cylinder)
		lantern.Material = Enum.Material.Neon
		B.part("LanternCap", Vector3.new(1.9, 0.3, 1.9), Vector3.new(x, 8.85, -10), dark)
		B.part("LanternFoot", Vector3.new(1.5, 0.25, 1.5), Vector3.new(x, 6.4, -10), dark)
	end
	for i, banner in { { -30, "闘" }, { -12, "魂" }, { 12, "開" }, { 30, "炎" } } do
		B.banner(banner[1], if i % 2 == 0 then -22 else -26, 15, "8E1020", dark, banner[2], if i % 2 == 0 then 2 else -2)
	end
	for i, ruin in { { -44, 12, -18 }, { -38, 7, -30 }, { 40, 9, -20 }, { 46, 14, -32 }, { -20, 5, -34 }, { 24, 6, -36 } } do
		local x, h, z = ruin[1], ruin[2], ruin[3]
		B.part("RuinPillar", Vector3.new(2.6, h, 2.6), CFrame.new(x, h / 2 - 1, z) * CFrame.Angles(0, math.rad(i * 23), math.rad((i % 3 - 1) * 6)), "3A3238", Enum.Material.Slate)
		B.part("RuinCap", Vector3.new(3.2, 0.8, 3.2), CFrame.new(x + (i % 2) * 0.6, h - 0.6, z) * CFrame.Angles(0, math.rad(i * 17), math.rad((i % 2) * 14)), "2A2328", Enum.Material.Slate)
	end
	for i, tree in { { -50, -30, 1.1 }, { -32, -40, 0.9 }, { 52, -28, 1.0 }, { 18, -44, 0.8 }, { -4, -48, 0.75 } } do
		local x, z, k = tree[1], tree[2], tree[3]
		B.part("TreeTrunk", Vector3.new(1.4 * k, 14 * k, 1.4 * k), CFrame.new(x, 7 * k - 1, z) * CFrame.Angles(0, 0, math.rad((i % 3 - 1) * 8)), "1A1013", Enum.Material.Wood)
		for b = 1, 6 do
			local angle = b * 1.05 + i
			B.ball("Blossom", (6 + (b % 3) * 1.6) * k, Vector3.new(x + math.cos(angle) * 4 * k, (13 + (b % 2) * 2.4) * k, z + math.sin(angle) * 2.5 * k),
				if b % 3 == 0 then "F28FA0" elseif b % 3 == 1 then "E86F84" else "FFC2CC")
		end
	end
end

-- FROZEN LAKE: ice crystals framing the fight, snowy pines, blue lamps, an aurora.
function PROPS.ice(B, map)
	for _, side in { -1, 1 } do
		for k = 1, 4 do
			local x = side * (23 + k * 1.6)
			local h = 10 + (k * 7) % 9
			B.part("IceCrystal", Vector3.new(1.6, h, 1.6), CFrame.new(x, h / 2 - 1, -13 - k) * CFrame.Angles(0, k, math.rad(side * (6 + k * 4))),
				"BFE6FF", Enum.Material.Ice).Transparency = 0.15
		end
	end
	for i = -5, 5 do
		local x, z = i * 11 + (i % 2) * 3, -30 - (i * i) % 12
		local h = 10 + (i * 5) % 6
		B.part("PineTrunk", Vector3.new(1, 4, 1), Vector3.new(x, 1, z), "2A1E1A", Enum.Material.Wood)
		for t = 0, 2 do
			local w = 7 - t * 2
			B.wedge("Pine", Vector3.new(2, h / 3, w / 2), CFrame.new(x - w / 4, 3 + t * h / 4 + h / 6, z) * CFrame.Angles(0, math.pi / 2, 0), "1E3A30")
			B.wedge("Pine", Vector3.new(2, h / 3, w / 2), CFrame.new(x + w / 4, 3 + t * h / 4 + h / 6, z) * CFrame.Angles(0, -math.pi / 2, 0), "1E3A30")
			B.part("PineSnow", Vector3.new(w * 0.7, 0.4, 2.2), Vector3.new(x, 3 + t * h / 4 + 0.2, z), "F4FAFF", Enum.Material.Snow)
		end
	end
	for _, x in { -34, -14, 14, 34 } do
		B.part("LampPost", Vector3.new(0.4, 6, 0.4), Vector3.new(x, 3, -10), map.frame.dark, Enum.Material.Metal)
		B.lamp(Vector3.new(1.4, 1.4, 1.4), Vector3.new(x, 6.6, -10), map.light, 16, Enum.PartType.Ball)
	end
	for i, color in { "5AFFB0", "4AD8FF", "8A6AFF" } do -- the aurora
		local band = B.part("Aurora", Vector3.new(200, 3 + i, 0.5), CFrame.new(0, 44 + i * 5, -84) * CFrame.Angles(0, 0, math.rad(4 - i * 3)), color, Enum.Material.Neon)
		band.Transparency = 0.55
	end
	for i, banner in { { -30, "氷" }, { 30, "雪" } } do
		B.banner(banner[1], -24, 14, "1E3A6A", "DDEEFF", banner[2], if i == 1 then -2 else 2)
	end
end

-- NEON ROOFTOP: a city skyline, lit windows, neon signs, rooftop gear, a railing.
function PROPS.city(B, map)
	for i = -7, 7 do
		local x = i * 13
		local h = 18 + (i * i * 7) % 22
		local z = -40 - (i % 3) * 8
		B.part("Tower", Vector3.new(10, h, 8), Vector3.new(x, h / 2 - 2, z), if i % 2 == 0 then "1A1430" else "221A3A", Enum.Material.Concrete)
		for row = 1, math.floor(h / 4) do
			if (row + i) % 3 ~= 0 then
				B.part("Window", Vector3.new(7, 0.6, 0.1), Vector3.new(x, row * 4 - 2, z + 4.05), if (row * i) % 2 == 0 then "FFD87A" else "6AE8FF",
					Enum.Material.Neon).Transparency = 0.35
			end
		end
	end
	B.sign("闘", Vector3.new(6, 8, 0.4), Vector3.new(-30, 14, -18), "FF2AD4", "120A1E")
	B.sign("FIGHT", Vector3.new(14, 4, 0.4), Vector3.new(0, 22, -24), "00E5FF", "120A1E")
	B.sign("夜", Vector3.new(6, 8, 0.4), Vector3.new(30, 14, -18), "FFD23F", "120A1E")
	B.part("Railing", Vector3.new(80, 0.3, 0.3), Vector3.new(0, 3.2, -11), "5A5A66", Enum.Material.Metal)
	for x = -38, 38, 4 do
		B.part("RailPost", Vector3.new(0.2, 3.2, 0.2), Vector3.new(x, 1.6, -11), "5A5A66", Enum.Material.Metal)
	end
	B.part("AirUnit", Vector3.new(5, 3, 4), Vector3.new(-38, 1.5, -6), "6A6A74", Enum.Material.DiamondPlate)
	B.part("WaterTank", Vector3.new(6, 7, 6), Vector3.new(40, 6, -16), "4A3A30", Enum.Material.Wood)
	for _, x in { -20, 20 } do
		B.part("NeonPole", Vector3.new(0.4, 9, 0.4), Vector3.new(x, 4.5, -12), "101018", Enum.Material.Metal)
		B.lamp(Vector3.new(0.6, 3, 0.6), Vector3.new(x, 9, -12), if x < 0 then "FF2AD4" else map.light, 20)
	end
end

-- VOLCANO FORGE: basalt columns, a lava river and falls, cracks of lava in the ground, braziers.
function PROPS.volcano(B, map)
	for _, side in { -1, 1 } do
		for k = 1, 5 do
			local h = 8 + (k * 5) % 10
			B.part("Basalt", Vector3.new(2.2, h, 2.2), Vector3.new(side * (24 + k * 2.2), h / 2 - 1, -12 - (k % 2) * 2), "2A2224", Enum.Material.Basalt)
		end
	end
	B.part("LavaRiver", Vector3.new(160, 0.4, 8), Vector3.new(0, -1.2, -20), "FF5A10", Enum.Material.Neon)
	for _, x in { -40, -8, 26 } do
		B.part("LavaFall", Vector3.new(4, 30, 0.6), Vector3.new(x, 12, -48), "FF7A1A", Enum.Material.Neon).Transparency = 0.1
	end
	for i = 1, 8 do -- glowing cracks behind the fighters (never under their feet)
		local x = -36 + i * 9
		B.part("LavaCrack", Vector3.new(3 + i % 3, 0.05, 0.25), CFrame.new(x, 0.03, -8 - (i % 3)) * CFrame.Angles(0, math.rad(i * 37), 0), "FF4A10", Enum.Material.Neon)
	end
	for _, x in { -34, 34 } do
		B.part("BrazierBowl", Vector3.new(3, 1.2, 3), Vector3.new(x, 4, -10), "3A2A26", Enum.Material.Metal)
		B.part("BrazierLeg", Vector3.new(0.6, 4, 0.6), Vector3.new(x, 1.5, -10), "201814", Enum.Material.Metal)
		B.lamp(Vector3.new(2.2, 1.4, 2.2), Vector3.new(x, 5.1, -10), map.light, 22, Enum.PartType.Ball)
	end
	B.part("Anvil", Vector3.new(4, 2, 2), Vector3.new(-42, 1, -4), "30302F", Enum.Material.Metal)
	for i, banner in { { -26, "炎" }, { 26, "鍛" } } do
		B.banner(banner[1], -24, 15, "5A1408", "FF9A4A", banner[2], if i == 1 then -2 else 2)
	end
end

-- BAMBOO DOJO: bamboo groves, a dark wood frame, paper lanterns, scrolls.
function PROPS.bamboo(B, map)
	for i = 1, 60 do
		local side = if i % 2 == 0 then 1 else -1
		local x = side * (26 + (i * 7) % 26) + (if i % 5 == 0 then -side * 50 else 0)
		local z = -14 - (i * 11) % 30
		local h = 24 + (i * 13) % 14
		local stalk = B.part("Bamboo", Vector3.new(h, 0.7, 0.7), CFrame.new(x, h / 2 - 1, z) * CFrame.Angles(0, 0, math.pi / 2 + math.rad((i % 5) - 2)),
			if i % 3 == 0 then "6A9A3A" else "4E7E2E", Enum.Material.Wood)
		stalk.Shape = Enum.PartType.Cylinder
		for n = 1, 3 do
			B.part("BambooNode", Vector3.new(0.85, 0.2, 0.85), Vector3.new(x, n * h / 4, z), "3A5A20")
		end
	end
	for _, x in { -24, 24 } do
		B.part("DojoPost", Vector3.new(1.6, 20, 1.6), Vector3.new(x, 9, -14), map.frame.dark, Enum.Material.Wood)
	end
	B.part("DojoBeam", Vector3.new(56, 1.6, 1.8), Vector3.new(0, 18.6, -14), map.frame.dark, Enum.Material.Wood)
	B.part("DojoRoof", Vector3.new(60, 1, 3.4), Vector3.new(0, 19.8, -14), map.frame.color, Enum.Material.Wood)
	for _, x in { -18, -6, 6, 18 } do
		B.part("LanternString", Vector3.new(0.1, 2, 0.1), Vector3.new(x, 16.8, -14), "1A1A10")
		B.lamp(Vector3.new(1.6, 2.2, 1.6), Vector3.new(x, 15, -14), map.light, 16, Enum.PartType.Ball)
	end
	for i, banner in { { -12, "竹" }, { 12, "心" } } do
		B.banner(banner[1], -22, 14, "F2E8D0", "1A1A10", banner[2], if i == 1 then -1 else 1)
	end
end

-- CLOUD PALACE: a marble deck above a sea of clouds, golden columns, floating islands.
function PROPS.sky(B, map)
	for i = -8, 8 do
		B.ball("CloudSea", 14 + (i * i) % 6, Vector3.new(i * 11, -9 - (i % 3), 6 - (i * 5) % 14), if i % 2 == 0 then "FFFFFF" else "F4ECF8")
	end
	for _, x in { -26, -22, 22, 26 } do
		B.part("Column", Vector3.new(2, 18, 2), Vector3.new(x, 8, -14), "F4EEE0", Enum.Material.Marble)
		B.part("ColumnCap", Vector3.new(2.8, 0.8, 2.8), Vector3.new(x, 17.4, -14), map.frame.color, Enum.Material.Metal)
		B.part("ColumnBase", Vector3.new(2.8, 0.8, 2.8), Vector3.new(x, -0.6, -14), map.frame.color, Enum.Material.Metal)
	end
	B.part("Architrave", Vector3.new(58, 1.6, 2.4), Vector3.new(0, 18.6, -14), "F4EEE0", Enum.Material.Marble)
	B.part("GoldBand", Vector3.new(58, 0.4, 2.5), Vector3.new(0, 17.9, -14), map.frame.color, Enum.Material.Metal)
	for i, island in { { -46, 14, -40, 8 }, { 40, 20, -46, 10 }, { 6, 30, -60, 6 } } do
		local x, y, z, r = island[1], island[2], island[3], island[4]
		B.ball("IslandRock", r, Vector3.new(x, y - r * 0.3, z), "8A7A6A", Enum.Material.Slate)
		B.part("IslandGrass", Vector3.new(r * 0.9, 0.6, r * 0.9), Vector3.new(x, y + r * 0.15, z), "8AC870", Enum.Material.Grass)
		if i == 2 then B.part("IslandShrine", Vector3.new(2, 3, 2), Vector3.new(x, y + 1.8, z), map.frame.color, Enum.Material.Metal) end
	end
	for _, x in { -34, 34 } do
		B.part("BrazierStand", Vector3.new(0.8, 4, 0.8), Vector3.new(x, 2, -10), map.frame.dark, Enum.Material.Metal)
		B.lamp(Vector3.new(1.6, 1.6, 1.6), Vector3.new(x, 4.6, -10), map.light, 18, Enum.PartType.Ball)
	end
	for i, banner in { { -12, "天" }, { 12, "光" } } do
		B.banner(banner[1], -22, 15, "FFFFFF", "8A6A20", banner[2], if i == 1 then -2 else 2)
	end
end

-- ===================================================================== build
local function lighting(map)
	local l = map.lighting
	Lighting.ClockTime, Lighting.Brightness = l.clock, l.brightness
	Lighting.GeographicLatitude = 25
	Lighting.Ambient, Lighting.OutdoorAmbient = hex(l.ambient), hex(l.outdoor)
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
	effect("ColorCorrectionEffect", "ArenaGrade", { Contrast = l.contrast + 0.04, Saturation = l.saturation, TintColor = hex(l.tint) })
	-- (VISUAL PASS: a touch more contrast; the bloom softer on phones, where it washed the
	-- small screen out)
	local phone = game:GetService("UserInputService").TouchEnabled and not game:GetService("UserInputService").KeyboardEnabled
	effect("BloomEffect", "ArenaBloom", { Intensity = l.bloom * (if phone then 0.6 else 1), Size = 28, Threshold = 1.25 })
	effect("SunRaysEffect", "ArenaSunRays", { Intensity = 0.05, Spread = 0.55 })
	effect("Atmosphere", "ArenaAtmosphere", { Density = l.density, Offset = 0.1, Color = hex(l.atmosphere), Decay = hex(l.decay), Glare = 0.4,
		Haze = l.haze })
end

-- Builds `mapId` (the default stage when unknown) and returns the Arena model.
function ArenaBuilder.build(mapId)
	local map = Maps.BY_ID[mapId or ""] or Maps.BY_ID[Maps.DEFAULT]
	local old = workspace:FindFirstChild("Arena")
	if old then old:Destroy() end
	local arena = Instance.new("Model")
	arena.Name = "Arena"
	arena:SetAttribute("Map", map.id)
	local B = kit(arena)
	backdrop(B, map, if map.props == "city" then "blocks" elseif map.props == "sky" then "clouds" else nil)
	deck(B, map)
	PROPS[map.props](B, map)
	air(B, map)
	-- FILL LIGHT on the fighters (Wilhem's phone capture: on the sunset / lava stages the sun
	-- is behind them and they read as dark silhouettes). A soft spot from the camera's side
	-- lights their front on every stage; no shadows (cheap, one light).
	local fill = Instance.new("Part")
	fill.Name, fill.Anchored, fill.CanCollide, fill.CanQuery, fill.CanTouch = "FighterFill", true, false, false, false
	fill.Transparency, fill.CastShadow, fill.Size = 1, false, Vector3.new(0.2, 0.2, 0.2)
	fill.CFrame = CFrame.lookAt(Vector3.new(0, 9, 18), Vector3.new(0, 3, 0))
	local spot = Instance.new("SpotLight")
	spot.Face, spot.Angle, spot.Range, spot.Shadows = Enum.NormalId.Front, 100, 45, false
	spot.Brightness = map.lighting.fill or 1.4
	spot.Color = Color3.fromHex(map.lighting.tint or "FFFFFF"):Lerp(Color3.new(1, 1, 1), 0.5)
	spot.Parent = fill
	fill.Parent = arena
	arena.Parent = workspace
	lighting(map)
	return arena
end

return ArenaBuilder
