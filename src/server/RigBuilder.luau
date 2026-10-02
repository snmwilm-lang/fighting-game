-- Fighter bodies. The block model (KAI's R15 rig built from plain parts, no external catalog
-- or animation asset), or the player's own Roblox avatar, R15 or R6, wearing the outfit of
-- the chosen kit. The Motor6D joints (15 on R15, 6 on R6) are the contract with the client
-- AnimationController. Hair, face, vest, outfits are cosmetic parts welded on top of the
-- skeleton: they follow the joints but never change hitboxes (those come from the simulation).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterData = require(Shared.CharacterData)
local RigSpec = require(Shared.RigSpec)
local WeaponSpec = require(Shared.WeaponSpec)
local RigReader = require(Shared.RigReader)
local RigBuilder = {}
local INK = Color3.fromHex("0B0B0E")

-- Avatars are scaled to about KAI's height so the fixed hurtboxes (CombatConfig.HurtHeight)
-- match the body on screen; very small or very tall avatars are brought into this range.
local TARGET_HEIGHT, HEIGHT_TOLERANCE = 5.7, 0.08

-- A cloth tail hanging from `pivot` (relative to `base`): its Weld, named TailJoint, is swung
-- by the client AnimationController (springs), so sashes and headband tails sway.
local function hangTail(base, p, pivot)
	local half = p.Size.Y / 2
	p.CFrame = base.CFrame * pivot * CFrame.new(0, -half, 0)
	local weld = Instance.new("Weld")
	weld.Name = "TailJoint"
	weld.Part0, weld.Part1 = base, p
	weld.C0, weld.C1 = pivot, CFrame.new(0, half, 0)
	weld.Parent = p
	return p
end

-- TARO 火's head: short dark hair swept up in a quiff (no spikes), a taped nose, a scar
-- through the brow and a gum shield. The face (eyes, brows, ears) is the shared one.
function RigBuilder.taroHead(ornament, hair, hairTip, skin, ink, white)
	ornament("Head", "HairCap", Vector3.new(1.18, 0.3, 1.1), CFrame.new(0, 0.5, 0.06), hair)
	ornament("Head", "HairBack", Vector3.new(1.14, 0.62, 0.14), CFrame.new(0, 0.26, 0.52), hair)
	for _, sign in { -1, 1 } do
		ornament("Head", "Fade", Vector3.new(0.08, 0.42, 0.8), CFrame.new(sign * 0.56, 0.28, 0.08), hair)
	end
	-- The quiff: a wedge swept up and back from the forehead, its front tipped with colour.
	ornament("Head", "Quiff", Vector3.new(0.98, 0.5, 0.72), CFrame.new(0, 0.78, -0.12) * CFrame.Angles(math.rad(-14), 0, 0), hair, "WedgePart")
	ornament("Head", "QuiffTip", Vector3.new(0.7, 0.18, 0.3), CFrame.new(0.06, 0.86, -0.42) * CFrame.Angles(math.rad(-30), 0, 0.06), hairTip, "WedgePart")
	ornament("Head", "NoseTape", Vector3.new(0.4, 0.09, 0.05), CFrame.new(0, -0.04, -0.56), white)
	ornament("Head", "Scar", Vector3.new(0.05, 0.36, 0.04), CFrame.new(-0.27, 0.18, -0.535) * CFrame.Angles(0, 0, 0.3), Color3.fromHex("A85A4A"))
	ornament("Head", "GumShield", Vector3.new(0.28, 0.07, 0.04), CFrame.new(0.02, -0.3, -0.52), Color3.fromHex("FFB21A"))
	ornament("Head", "Chin", Vector3.new(0.5, 0.12, 0.2), CFrame.new(0, -0.52, -0.42), skin)
end

-- TARO 火's body: bare muscular chest with a towel around the neck and 火 tattooed on the
-- back, taped forearms (the gloves come from his outfit), boxing trunks and high laced
-- boots. Nothing of KAI's vest, sash, baggy pants or sneakers.
function RigBuilder.taroBody(ornament, shaped, parts, color, data, ink)
	local skin, towel, line = color("SkinTone"), color("Shirt"), Color3.fromHex("8A5A40")
	-- Chest: pecs, abs, collarbones (lines in a darker skin tone, ink under the pecs).
	for _, sign in { -1, 1 } do
		ornament("UpperTorso", "Pec", Vector3.new(0.84, 0.52, 0.14), CFrame.new(sign * 0.44, 0.22, -0.5), skin)
		ornament("UpperTorso", "PecLine", Vector3.new(0.78, 0.05, 0.04), CFrame.new(sign * 0.44, -0.05, -0.58) * CFrame.Angles(0, 0, sign * -0.12), ink)
		ornament("UpperTorso", "Collarbone", Vector3.new(0.5, 0.04, 0.04), CFrame.new(sign * 0.36, 0.56, -0.52) * CFrame.Angles(0, 0, sign * 0.15), line)
		ornament("UpperTorso", "Trap", Vector3.new(0.5, 0.26, 0.6), CFrame.new(sign * 0.5, 0.74, 0.05) * CFrame.Angles(0, 0, sign * -0.35), skin)
		for row = 0, 2 do
			ornament("UpperTorso", "Ab", Vector3.new(0.3, 0.04, 0.04), CFrame.new(sign * 0.17, -0.28 - row * 0.15, -0.51), line)
		end
	end
	ornament("UpperTorso", "AbCentre", Vector3.new(0.04, 0.5, 0.04), CFrame.new(0, -0.42, -0.51), line)
	-- Towel around the neck, its two ends hanging on the chest.
	ornament("UpperTorso", "TowelNeck", Vector3.new(1.3, 0.24, 1.06), CFrame.new(0, 0.74, 0.02), towel)
	for _, sign in { -1, 1 } do
		ornament("UpperTorso", "TowelEnd", Vector3.new(0.34, 0.86, 0.1), CFrame.new(sign * 0.36, 0.3, -0.56) * CFrame.Angles(0, 0, sign * 0.06), towel)
		ornament("UpperTorso", "TowelStripe", Vector3.new(0.36, 0.06, 0.11), CFrame.new(sign * 0.36, 0.0, -0.56), color("Wraps"))
	end
	-- 火 tattooed on the back.
	local back = parts.UpperTorso
	local emblem = Instance.new("SurfaceGui")
	emblem.Name, emblem.Face, emblem.LightInfluence = "Emblem", Enum.NormalId.Back, 0
	emblem.CanvasSize = Vector2.new(200, 150)
	local kanji = Instance.new("TextLabel")
	kanji.BackgroundTransparency, kanji.Size = 1, UDim2.fromScale(1, 1)
	kanji.Text, kanji.TextScaled, kanji.Font = data.Kanji, true, Enum.Font.GothamBlack
	kanji.TextColor3 = color("Energy")
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness, stroke.Parent = ink, 3, kanji
	kanji.Parent = emblem
	emblem.Parent = back
	for _, side in { "Left", "Right" } do
		local sign = if side == "Left" then -1 else 1
		-- Boxer's shoulders and arms, tape around the wrists.
		shaped(side .. "UpperArm", "Deltoid", Vector3.new(0.96, 0.92, 0.96), CFrame.new(0, 0.3, 0), skin, Enum.PartType.Ball)
		shaped(side .. "UpperArm", "Bicep", Vector3.new(0.66, 0.66, 0.66), CFrame.new(0, -0.1, -0.14), skin, Enum.PartType.Ball)
		shaped(side .. "LowerArm", "Forearm", Vector3.new(0.7, 0.7, 0.7), CFrame.new(0, 0.22, 0), skin, Enum.PartType.Ball)
		ornament(side .. "LowerArm", "Tape", Vector3.new(0.68, 0.34, 0.72), CFrame.new(0, -0.3, 0), color("Wraps"))
		ornament(side .. "Hand", "Thumb", Vector3.new(0.2, 0.32, 0.26), CFrame.new(-sign * 0.38, 0.02, -0.22), color("Wraps"))
		-- Satin trunks: wide legs with a side stripe.
		ornament(side .. "UpperLeg", "TrunkLeg", Vector3.new(1.0, 0.8, 1.04), CFrame.new(sign * 0.03, 0.26, 0), color("Pants"))
		ornament(side .. "UpperLeg", "TrunkHem", Vector3.new(1.02, 0.1, 1.06), CFrame.new(sign * 0.03, -0.14, 0), color("Wraps"))
		ornament(side .. "UpperLeg", "TrunkStripe", Vector3.new(0.06, 0.8, 0.5), CFrame.new(sign * 0.53, 0.26, 0), color("Wraps"))
		ornament(side .. "UpperLeg", "Thigh", Vector3.new(0.9, 0.5, 0.96), CFrame.new(0, -0.38, 0), skin)
		-- High boxing boots: shaft over the shin, laces, top band, thin flat sole.
		ornament(side .. "LowerLeg", "BootShaft", Vector3.new(0.86, 0.78, 0.92), CFrame.new(0, -0.14, 0), color("Shoes"))
		ornament(side .. "LowerLeg", "BootTop", Vector3.new(0.9, 0.1, 0.96), CFrame.new(0, 0.26, 0), color("ShoeAccent"))
		for i = 0, 3 do
			ornament(side .. "LowerLeg", "Lace", Vector3.new(0.34, 0.04, 0.04), CFrame.new(0, 0.16 - i * 0.16, -0.47), color("ShoeAccent"))
		end
		ornament(side .. "Foot", "Sole", Vector3.new(0.84, 0.08, 1.24), CFrame.new(0, -0.19, 0), color("Sole"))
		ornament(side .. "Foot", "BootToe", Vector3.new(0.82, 0.3, 0.4), CFrame.new(0, -0.04, -0.42), color("Shoes"))
		ornament(side .. "Foot", "BootLogo", Vector3.new(0.86, 0.1, 0.4), CFrame.new(0, 0.05, 0.2), color("ShoeAccent"))
	end
	-- Trunks' waistband (the champion belt comes from his outfit).
	ornament("LowerTorso", "Waistband", Vector3.new(1.76, 0.3, 1.0), CFrame.new(0, 0.12, 0), color("Wraps"))
	ornament("LowerTorso", "Trunks", Vector3.new(1.76, 0.5, 1.0), CFrame.new(0, -0.14, 0), color("Pants"))
end

--[[
	Each fighter's own block body: hair (head) and clothes (body), drawn over the shared
	skeleton (RigSpec.KAI) and face. KAI keeps the base body below; every other kit has its
	own silhouette, so no one looks like KAI wearing another outfit. `ctx` gives:
	ornament(part, name, size, offset, color, class), shaped(part, name, size, offset, color,
	shape), tail(part, name, size, pivot, color) for a swaying strip, color(key), ink, white,
	skin, hair, hairTip. Offsets are relative to the bind pose of the part (front is -Z).
]]
local BODIES = {}

local function material(p, mat)
	p.Material = mat
	return p
end

-- Legs and feet shared by the bodies. opts.wide: wide trousers (hakama, dobok) down to the
-- ankle; opts.feet: "sneakers", "boots", "tabi" or "bare".
local function legs(ctx, opts)
	local o, color, ink = ctx.ornament, ctx.color, ctx.ink
	for _, side in { "Left", "Right" } do
		local sign = if side == "Left" then -1 else 1
		if opts.wide then
			o(side .. "UpperLeg", "WideLeg", Vector3.new(1.06, 1.1, 1.08), CFrame.new(sign * 0.04, 0.04, 0), color("Pants"))
			if not opts.shins then -- (bare shins: ZEPHYR's guards show)
				o(side .. "LowerLeg", "WideFlare", Vector3.new(1.02, 0.9, 1.04), CFrame.new(sign * 0.03, 0.02, 0), color("Pants"))
			end
			o(side .. "UpperLeg", "Pleat", Vector3.new(0.04, 1.0, 0.04), CFrame.new(sign * 0.18, 0, -0.55), ink)
			o(side .. "LowerLeg", "Pleat", Vector3.new(0.04, 0.8, 0.04), CFrame.new(-sign * 0.12, 0.05, -0.53), ink)
		else
			o(side .. "UpperLeg", "Thigh", Vector3.new(0.94, 0.9, 0.98), CFrame.new(0, 0.1, 0), color("Pants"))
			o(side .. "UpperLeg", "Fold", Vector3.new(0.5, 0.04, 0.04), CFrame.new(sign * 0.1, -0.35, -0.5) * CFrame.Angles(0, 0, sign * 0.3), ink)
		end
		local feet = opts.feet or "sneakers"
		if feet == "sneakers" then
			if not opts.wide then o(side .. "LowerLeg", "PantsCuff", Vector3.new(0.9, 0.26, 0.94), CFrame.new(0, -0.38, 0), color("PantsShade")) end
			o(side .. "Foot", "Sole", Vector3.new(0.84, 0.12, 1.26), CFrame.new(0, -0.18, 0), color("Sole"))
			o(side .. "Foot", "ToeCap", Vector3.new(0.82, 0.24, 0.32), CFrame.new(0, -0.07, -0.47), color("Shoes"))
			o(side .. "Foot", "ShoeStripe", Vector3.new(0.86, 0.12, 0.62), CFrame.new(0, 0, 0.12) * CFrame.Angles(0.25, 0, 0), color("ShoeAccent"))
		elseif feet == "boots" then
			o(side .. "LowerLeg", "BootShaft", Vector3.new(0.9, 0.7, 0.94), CFrame.new(0, -0.18, 0), color("Shoes"))
			o(side .. "LowerLeg", "BootCuff", Vector3.new(0.96, 0.14, 1.0), CFrame.new(0, 0.18, 0), color("ShoeAccent"))
			o(side .. "Foot", "Sole", Vector3.new(0.9, 0.16, 1.3), CFrame.new(0, -0.17, -0.02), color("Sole"))
			o(side .. "Foot", "BootToe", Vector3.new(0.86, 0.34, 0.46), CFrame.new(0, -0.02, -0.42), color("Shoes"))
			o(side .. "Foot", "Strap", Vector3.new(0.9, 0.08, 0.5), CFrame.new(0, 0.12, 0.1), color("ShoeAccent"))
		elseif feet == "tabi" then
			for i, y in { 0.3, 0.08, -0.14, -0.36 } do
				o(side .. "LowerLeg", "ShinWrap" .. i, Vector3.new(0.86, 0.06, 0.9), CFrame.new(0, y, 0) * CFrame.Angles(0, 0, (if i % 2 == 0 then 1 else -1) * 0.16), color("Wraps"))
			end
			o(side .. "Foot", "Sole", Vector3.new(0.82, 0.08, 1.22), CFrame.new(0, -0.19, 0), ink)
			o(side .. "Foot", "SplitToe", Vector3.new(0.04, 0.3, 0.34), CFrame.new(sign * 0.12, -0.04, -0.46), ink)
		else -- bare feet with ankle wraps
			o(side .. "Foot", "AnkleWrap", Vector3.new(0.86, 0.14, 0.9), CFrame.new(0, 0.12, 0.08), color("Wraps"))
			o(side .. "Foot", "Toes", Vector3.new(0.7, 0.06, 0.04), CFrame.new(0, -0.08, -0.6), ctx.ink)
		end
	end
end

-- Bare arms: shoulders and biceps, optional forearm bands (bandages) and knuckle wraps.
local function bareArms(ctx, bands, knuckles)
	for _, side in { "Left", "Right" } do
		ctx.shaped(side .. "UpperArm", "Deltoid", Vector3.new(0.84, 0.84, 0.84), CFrame.new(0, 0.3, 0), ctx.skin, Enum.PartType.Ball)
		ctx.shaped(side .. "UpperArm", "Bicep", Vector3.new(0.62, 0.62, 0.62), CFrame.new(0, -0.08, -0.13), ctx.skin, Enum.PartType.Ball)
		if bands then
			for i, y in { 0.3, 0.06, -0.18, -0.38 } do
				ctx.ornament(side .. "LowerArm", "Band" .. i, Vector3.new(0.66, 0.06, 0.7),
					CFrame.new(0, y, 0) * CFrame.Angles(0, 0, (if i % 2 == 0 then 1 else -1) * 0.2), bands)
			end
		end
		if knuckles then
			ctx.ornament(side .. "Hand", "Knuckles", Vector3.new(0.78, 0.16, 0.2), CFrame.new(0, -0.12, -0.32), knuckles)
		end
	end
end

-- ZEPHYR 風: hair swept back by the wind, a crossed taekwondo top tied with a belt, wide
-- trousers, bare feet with ankle wraps (the shin guards come from his outfit).
BODIES.ZEPHYR = {
	colors = function(pc, color)
		pc.UpperTorso, pc.UpperArm, pc.LowerArm, pc.Hand = color("Shirt"), color("Shirt"), color("SkinTone"), color("SkinTone")
		pc.LowerLeg, pc.Foot = color("Pants"), color("SkinTone")
	end,
	head = function(ctx)
		local o, hair, tip = ctx.ornament, ctx.hair, ctx.hairTip
		o("Head", "HairCap", Vector3.new(1.2, 0.36, 1.12), CFrame.new(0, 0.5, 0.06), hair)
		-- Long locks streaming back (to the side of the attack: the wind).
		for i, y in { 0.62, 0.42, 0.22 } do
			o("Head", "WindLock", Vector3.new(0.9 - i * 0.12, 0.2, 1.3 + i * 0.25),
				CFrame.new(0, y, 0.55 + i * 0.12) * CFrame.Angles(math.rad(14 - i * 6), 0, 0), if i == 1 then tip else hair, "WedgePart")
		end
		for _, sign in { -1, 1 } do
			o("Head", "SideSweep", Vector3.new(0.12, 0.45, 0.8), CFrame.new(sign * 0.58, 0.18, 0.15) * CFrame.Angles(0, 0, sign * -0.1), hair)
		end
		o("Head", "Fringe", Vector3.new(0.9, 0.22, 0.14), CFrame.new(0.05, 0.42, -0.54) * CFrame.Angles(0, 0, -0.12), hair)
	end,
	body = function(ctx)
		local o, color, ink = ctx.ornament, ctx.color, ctx.ink
		-- Crossed top: the two lapels overlap in a V, dark trim, a belt with hanging ends.
		for _, sign in { -1, 1 } do
			o("UpperTorso", "Lapel", Vector3.new(0.16, 1.2, 0.06), CFrame.new(sign * 0.2, 0.1, -0.52) * CFrame.Angles(0, 0, sign * 0.42), color("Vest"))
			o(if sign < 0 then "LeftUpperArm" else "RightUpperArm", "Sleeve", Vector3.new(0.8, 0.5, 0.86), CFrame.new(0, 0.3, 0), color("Shirt"))
		end
		o("UpperTorso", "Neckline", Vector3.new(0.34, 0.3, 0.04), CFrame.new(0, 0.54, -0.505), ctx.skin)
		ctx.shaped("LeftLowerArm", "Forearm", Vector3.new(0.64, 0.64, 0.64), CFrame.new(0, 0.2, 0), ctx.skin, Enum.PartType.Ball)
		ctx.shaped("RightLowerArm", "Forearm", Vector3.new(0.64, 0.64, 0.64), CFrame.new(0, 0.2, 0), ctx.skin, Enum.PartType.Ball)
		o("LowerTorso", "Belt", Vector3.new(1.76, 0.26, 1.0), CFrame.new(0, 0.2, 0), color("Vest"))
		o("LowerTorso", "BeltKnot", Vector3.new(0.3, 0.26, 0.14), CFrame.new(0.1, 0.2, -0.55), color("Vest"))
		ctx.tail("LowerTorso", "BeltEnd", Vector3.new(0.14, 0.7, 0.05), CFrame.new(0.02, 0.12, -0.56) * CFrame.Angles(0, 0, 0.12), color("Vest"))
		ctx.tail("LowerTorso", "BeltEnd2", Vector3.new(0.14, 0.6, 0.05), CFrame.new(0.2, 0.12, -0.56) * CFrame.Angles(0, 0, -0.1), color("Vest"))
		o("UpperTorso", "Hem", Vector3.new(1.96, 0.3, 1.04), CFrame.new(0, -0.6, 0), color("Shirt"))
		legs(ctx, { wide = true, feet = "bare", shins = true })
		o("UpperTorso", "ChestLine", Vector3.new(0.04, 0.5, 0.04), CFrame.new(0, -0.1, -0.51), ink)
	end,
}

-- AKEMI 影: short hair under the hood, a close-fitting dark suit with crossed straps and a
-- blade sheath on the back, slim trousers, shin wraps and split-toe boots.
BODIES.AKEMI = {
	colors = function(pc, color)
		pc.UpperTorso, pc.UpperArm, pc.LowerArm, pc.Hand = color("Vest"), color("Vest"), color("Vest"), color("Vest")
		pc.LowerLeg, pc.Foot = color("Pants"), color("Shoes")
	end,
	head = function(ctx)
		local o, hair = ctx.ornament, ctx.hair
		o("Head", "HairCap", Vector3.new(1.18, 0.3, 1.1), CFrame.new(0, 0.5, 0.06), hair)
		o("Head", "Bangs", Vector3.new(1.0, 0.3, 0.14), CFrame.new(0, 0.34, -0.54) * CFrame.Angles(math.rad(180), 0, 0), hair, "WedgePart")
		for _, sign in { -1, 1 } do
			o("Head", "SideBang", Vector3.new(0.14, 0.5, 0.3), CFrame.new(sign * 0.55, 0.12, -0.32), ctx.hairTip)
		end
	end,
	body = function(ctx)
		local o, color, ink = ctx.ornament, ctx.color, ctx.ink
		for _, sign in { -1, 1 } do
			o("UpperTorso", "Strap", Vector3.new(0.14, 1.7, 0.06), CFrame.new(0, 0, -0.52) * CFrame.Angles(0, 0, sign * 0.62), color("Wraps"))
			o("UpperTorso", "Seam", Vector3.new(0.04, 1.2, 0.04), CFrame.new(sign * 0.6, -0.1, -0.51), ink)
		end
		o("UpperTorso", "StrapBuckle", Vector3.new(0.24, 0.24, 0.08), CFrame.new(0, 0.05, -0.56), color("VestTrim"))
		material(o("UpperTorso", "Sheath", Vector3.new(0.2, 1.7, 0.2), CFrame.new(0.1, 0.1, 0.62) * CFrame.Angles(0, 0, 0.55), ink), Enum.Material.SmoothPlastic)
		o("UpperTorso", "SheathTip", Vector3.new(0.22, 0.2, 0.22), CFrame.new(0.55, 0.78, 0.62) * CFrame.Angles(0, 0, 0.55), color("VestTrim"))
		for _, side in { "Left", "Right" } do
			o(side .. "Hand", "Glove", Vector3.new(0.78, 0.66, 0.8), CFrame.new(0, 0, 0), color("Vest"))
		end
		o("LowerTorso", "Belt", Vector3.new(1.74, 0.2, 0.99), CFrame.new(0, 0.2, 0), color("Wraps"))
		legs(ctx, { feet = "tabi" })
	end,
}

-- RYUKEN 拳: tall white hair standing up like flames (red tips), a scar across the nose, a
-- black tank top with a torn hem, red bandages up the forearms and a buckled belt.
BODIES.RYUKEN = {
	colors = function(pc, color)
		pc.UpperTorso, pc.LowerArm, pc.Hand = color("Shirt"), color("Wraps"), color("Wraps")
	end,
	head = function(ctx)
		local o, hair, tip = ctx.ornament, ctx.hair, ctx.hairTip
		o("Head", "HairCap", Vector3.new(1.24, 0.4, 1.14), CFrame.new(0, 0.5, 0.04), hair)
		local flames = {
			{ x = -0.42, h = 1.3, tilt = -0.5, z = 0.1, lean = -20 }, { x = -0.22, h = 1.7, tilt = -0.25, z = 0, lean = -28 },
			{ x = 0, h = 2.0, tilt = 0, z = 0.12, lean = -34 }, { x = 0.22, h = 1.75, tilt = 0.25, z = 0, lean = -28 },
			{ x = 0.42, h = 1.35, tilt = 0.5, z = 0.1, lean = -20 }, { x = 0, h = 1.2, tilt = 0, z = 0.48, lean = -60 },
		}
		for i, f in flames do
			o("Head", "HairFlame", Vector3.new(0.32, f.h, 0.9),
				CFrame.new(f.x, 0.6 + f.h / 2.4, f.z) * CFrame.Angles(math.rad(f.lean), 0, f.tilt), if i % 2 == 0 then tip else hair, "WedgePart")
		end
		for i, x in { -0.36, -0.1, 0.18, 0.4 } do
			o("Head", "Fringe", Vector3.new(0.24, 0.42, 0.12), CFrame.new(x, 0.3, -0.56) * CFrame.Angles(math.rad(180), 0, (i - 2.5) * 0.2), hair, "WedgePart")
		end
		o("Head", "Scar", Vector3.new(0.5, 0.05, 0.04), CFrame.new(0, -0.02, -0.56) * CFrame.Angles(0, 0, 0.35), ctx.color("Wraps"))
	end,
	body = function(ctx)
		local o, color, ink = ctx.ornament, ctx.color, ctx.ink
		o("UpperTorso", "Neckline", Vector3.new(0.62, 0.3, 0.04), CFrame.new(0, 0.56, -0.505), ctx.skin)
		for _, sign in { -1, 1 } do
			o("UpperTorso", "ChestLine", Vector3.new(0.6, 0.04, 0.04), CFrame.new(sign * 0.33, 0.12, -0.51) * CFrame.Angles(0, 0, sign * -0.18), ink)
			o("UpperTorso", "Trap", Vector3.new(0.46, 0.24, 0.6), CFrame.new(sign * 0.52, 0.74, 0.05) * CFrame.Angles(0, 0, sign * -0.3), ctx.skin)
		end
		-- Torn hem: ragged teeth under the tank top.
		for i = -3, 3 do
			o("UpperTorso", "TornHem", Vector3.new(0.26, 0.2 + (i % 2) * 0.1, 0.06), CFrame.new(i * 0.26, -0.72, -0.51) * CFrame.Angles(math.rad(180), 0, 0), color("Shirt"), "WedgePart")
		end
		bareArms(ctx, ink, ink)
		o("LowerTorso", "Belt", Vector3.new(1.76, 0.24, 1.0), CFrame.new(0, 0.2, 0), ink)
		o("LowerTorso", "Buckle", Vector3.new(0.34, 0.28, 0.08), CFrame.new(0, 0.2, -0.53), color("VestTrim"))
		legs(ctx, { feet = "sneakers" })
	end,
}

-- SHIN 流: bangs swept over one eye, a high ponytail, a high collar over the mouth, a long
-- coat with blue edges and tails down to the knees, gloves, wide trousers and boots.
BODIES.SHIN = {
	colors = function(pc, color)
		pc.UpperTorso, pc.UpperArm, pc.LowerArm, pc.Hand = color("Vest"), color("Vest"), color("Vest"), color("Wraps")
		pc.LowerLeg = color("Pants")
	end,
	head = function(ctx)
		local o, hair, tip = ctx.ornament, ctx.hair, ctx.hairTip
		o("Head", "HairCap", Vector3.new(1.2, 0.36, 1.12), CFrame.new(0, 0.5, 0.06), hair)
		o("Head", "SweptBang", Vector3.new(0.7, 0.75, 0.16), CFrame.new(0.2, 0.18, -0.55) * CFrame.Angles(math.rad(180), 0, 0.35), hair, "WedgePart")
		o("Head", "BangTip", Vector3.new(0.3, 0.3, 0.17), CFrame.new(0.32, -0.12, -0.56) * CFrame.Angles(math.rad(180), 0, 0.35), tip, "WedgePart")
		for _, sign in { -1, 1 } do
			o("Head", "SideHair", Vector3.new(0.12, 0.62, 0.7), CFrame.new(sign * 0.58, 0.1, 0.05), hair)
		end
		o("Head", "TieKnot", Vector3.new(0.3, 0.26, 0.24), CFrame.new(0, 0.62, 0.5), ctx.color("Sash"))
		ctx.tail("Head", "Ponytail", Vector3.new(0.32, 1.25, 0.26), CFrame.new(0, 0.6, 0.56) * CFrame.Angles(math.rad(-30), 0, 0), hair)
		-- High collar over the mouth.
		o("Head", "Collar", Vector3.new(1.16, 0.42, 1.08), CFrame.new(0, -0.42, 0.02), ctx.color("Shirt"))
		o("Head", "CollarEdge", Vector3.new(1.18, 0.07, 1.1), CFrame.new(0, -0.2, 0.02), ctx.color("VestTrim"))
	end,
	body = function(ctx)
		local o, color, ink = ctx.ornament, ctx.color, ctx.ink
		local trim = color("VestTrim")
		-- Coat closed across the chest (diagonal edge), blue trims, sleeves with cuffs.
		o("UpperTorso", "CoatEdge", Vector3.new(0.08, 1.5, 0.06), CFrame.new(-0.1, 0, -0.52) * CFrame.Angles(0, 0, 0.32), trim)
		o("UpperTorso", "Shoulders", Vector3.new(2.0, 0.22, 1.08), CFrame.new(0, 0.62, 0), color("Vest"))
		for _, side in { "Left", "Right" } do
			o(side .. "LowerArm", "Cuff", Vector3.new(0.74, 0.2, 0.78), CFrame.new(0, -0.38, 0), trim)
			o(side .. "UpperArm", "Sleeve", Vector3.new(0.8, 0.9, 0.84), CFrame.new(0, 0.04, 0), color("Vest"))
		end
		o("LowerTorso", "Sash", Vector3.new(1.76, 0.24, 1.0), CFrame.new(0, 0.22, 0), color("Sash"))
		-- Coat tails: two in front, one behind, swaying.
		for _, x in { -0.45, 0.45 } do
			ctx.tail("LowerTorso", "CoatTail", Vector3.new(0.72, 1.6, 0.06), CFrame.new(x, 0.08, -0.52), color("Vest"))
		end
		ctx.tail("LowerTorso", "CoatBack", Vector3.new(1.5, 1.8, 0.06), CFrame.new(0, 0.1, 0.52) * CFrame.Angles(math.rad(8), 0, 0), color("Vest"))
		legs(ctx, { wide = true, feet = "boots" })
	end,
}

-- DAICHA 闇: long straight hair down the back, a white robe crossed in violet, wide sleeves,
-- an obi with a knot and tails, dark trousers and soft boots.
BODIES.DAICHA = {
	colors = function(pc, color)
		pc.UpperTorso, pc.UpperArm, pc.LowerArm, pc.Hand = color("Shirt"), color("Shirt"), color("Shirt"), color("SkinTone")
	end,
	head = function(ctx)
		local o, hair, tip = ctx.ornament, ctx.hair, ctx.hairTip
		o("Head", "HairCap", Vector3.new(1.22, 0.36, 1.14), CFrame.new(0, 0.5, 0.05), hair)
		o("Head", "Bangs", Vector3.new(1.06, 0.36, 0.14), CFrame.new(0, 0.32, -0.55) * CFrame.Angles(math.rad(180), 0, 0), hair, "WedgePart")
		for _, sign in { -1, 1 } do
			o("Head", "Curtain", Vector3.new(0.14, 1.3, 0.5), CFrame.new(sign * 0.6, -0.15, -0.1), hair)
			o("Head", "CurtainTip", Vector3.new(0.15, 0.24, 0.5), CFrame.new(sign * 0.6, -0.86, -0.1), tip)
		end
		o("Head", "BackHair", Vector3.new(1.16, 1.1, 0.2), CFrame.new(0, 0, 0.56), hair)
		ctx.tail("Head", "LongHair", Vector3.new(1.0, 1.9, 0.14), CFrame.new(0, -0.5, 0.62), hair)
	end,
	body = function(ctx)
		local o, color, ink = ctx.ornament, ctx.color, ctx.ink
		local trim = color("VestTrim")
		for _, sign in { -1, 1 } do
			o("UpperTorso", "CrossCollar", Vector3.new(0.14, 1.3, 0.06), CFrame.new(sign * 0.18, 0.12, -0.52) * CFrame.Angles(0, 0, sign * 0.5), trim)
		end
		o("UpperTorso", "Neckline", Vector3.new(0.3, 0.3, 0.04), CFrame.new(0, 0.56, -0.505), ctx.skin)
		for _, side in { "Left", "Right" } do
			-- Wide sleeves hanging from the forearm.
			o(side .. "LowerArm", "WideSleeve", Vector3.new(0.86, 0.95, 0.9), CFrame.new(0, -0.1, 0.06), color("Shirt"))
			o(side .. "LowerArm", "SleeveEdge", Vector3.new(0.88, 0.1, 0.92), CFrame.new(0, -0.55, 0.06), trim)
		end
		o("LowerTorso", "Obi", Vector3.new(1.78, 0.44, 1.02), CFrame.new(0, 0.12, 0), color("Sash"))
		o("LowerTorso", "ObiKnot", Vector3.new(0.5, 0.34, 0.2), CFrame.new(0, 0.12, 0.58), color("Sash"))
		ctx.tail("LowerTorso", "ObiTail", Vector3.new(0.2, 1.3, 0.05), CFrame.new(-0.12, 0.06, 0.66) * CFrame.Angles(0, 0, 0.1), color("Sash"))
		ctx.tail("LowerTorso", "ObiTail2", Vector3.new(0.2, 1.1, 0.05), CFrame.new(0.12, 0.06, 0.66) * CFrame.Angles(0, 0, -0.1), color("Sash"))
		o("UpperTorso", "RobeHem", Vector3.new(1.98, 0.5, 1.06), CFrame.new(0, -0.66, 0), color("Shirt"))
		legs(ctx, { wide = true, feet = "tabi" })
		o("UpperTorso", "Fold", Vector3.new(0.04, 0.6, 0.04), CFrame.new(0.45, -0.2, -0.51), ink)
	end,
}

-- HIBECARES 崩: wild hair under a red headband with his mark, a ragged sleeveless tunic, a
-- chain across the chest, a stone pauldron, rope belt, heavy boots (his stone gauntlets and
-- arm chains come from his outfit).
BODIES.HIBECARES = {
	colors = function(pc, color)
		pc.UpperTorso, pc.Hand = color("Vest"), color("Wraps")
		pc.LowerArm = color("SkinTone")
	end,
	head = function(ctx)
		local o, hair, tip = ctx.ornament, ctx.hair, ctx.hairTip
		o("Head", "HairCap", Vector3.new(1.3, 0.44, 1.2), CFrame.new(0, 0.5, 0.06), hair)
		for i = 1, 7 do
			local a = (i - 4) * 0.4
			o("Head", "WildHair", Vector3.new(0.38, 0.8 + (i % 3) * 0.2, 0.7),
				CFrame.new(math.sin(a) * 0.55, 0.62 + math.cos(a) * 0.2, 0.1) * CFrame.Angles(math.rad(-25), 0, a * 1.1), if i == 4 then tip else hair, "WedgePart")
		end
		for _, sign in { -1, 1 } do
			o("Head", "Shag", Vector3.new(0.2, 0.7, 0.8), CFrame.new(sign * 0.62, -0.05, 0.12) * CFrame.Angles(0, 0, sign * 0.15), hair)
		end
		local band = ctx.color("Sash")
		o("Head", "Headband", Vector3.new(1.18, 0.2, 1.1), CFrame.new(0, 0.26, 0), band)
		o("Head", "BandMark", Vector3.new(0.3, 0.16, 0.04), CFrame.new(0, 0.26, -0.57), ctx.white)
		ctx.tail("Head", "BandTail", Vector3.new(0.18, 1.0, 0.05), CFrame.new(0.15, 0.24, 0.56) * CFrame.Angles(math.rad(-50), 0, 0.2), band)
		o("Head", "Stubble", Vector3.new(0.8, 0.14, 0.06), CFrame.new(0, -0.44, -0.5), Color3.fromHex("5A4436"))
	end,
	body = function(ctx)
		local o, color, ink = ctx.ornament, ctx.color, ctx.ink
		local metal = Color3.fromHex("4A4A52")
		-- Ragged hem and torn shoulders of the tunic.
		for i = -3, 3 do
			o("UpperTorso", "Rag", Vector3.new(0.28, 0.26 + (i % 2) * 0.14, 0.06), CFrame.new(i * 0.27, -0.76, -0.51) * CFrame.Angles(math.rad(180), 0, 0), color("Vest"), "WedgePart")
		end
		-- A chain across the chest, link after link.
		for i = 0, 8 do
			local t = i / 8
			material(o("UpperTorso", "ChainLink", Vector3.new(0.16, 0.24, 0.1),
				CFrame.new(-0.8 + t * 1.6, 0.6 - t * 1.2, -0.56) * CFrame.Angles(0, 0, 0.64 + (i % 2) * 1.57), metal), Enum.Material.Metal)
		end
		material(o("LeftUpperArm", "Pauldron", Vector3.new(0.96, 0.5, 0.96), CFrame.new(0, 0.42, 0), color("Wraps")), Enum.Material.Slate)
		material(o("LeftUpperArm", "PauldronRim", Vector3.new(1.0, 0.1, 1.0), CFrame.new(0, 0.18, 0), metal), Enum.Material.Metal)
		bareArms(ctx, nil, nil)
		o("LowerTorso", "Rope", Vector3.new(1.78, 0.18, 1.02), CFrame.new(0, 0.24, 0), color("PantsShade"))
		o("LowerTorso", "RopeKnot", Vector3.new(0.26, 0.24, 0.16), CFrame.new(-0.3, 0.24, -0.56), color("PantsShade"))
		legs(ctx, { feet = "boots" })
	end,
}

-- TARO 火 (see taroHead / taroBody above).
BODIES.TARO = {
	colors = function(pc, color)
		pc.UpperTorso, pc.LowerArm = color("SkinTone"), color("SkinTone")
		pc.LowerLeg = color("SkinTone")
	end,
	head = function(ctx) RigBuilder.taroHead(ctx.ornament, ctx.hair, ctx.hairTip, ctx.skin, ctx.ink, ctx.white) end,
	body = function(ctx) RigBuilder.taroBody(ctx.ornament, ctx.shaped, ctx.parts, ctx.color, ctx.data, ctx.ink) end,
}
RigBuilder.BODIES = BODIES

function RigBuilder.build(slot, parent)
	local data = CharacterData[slot]
	local function color(key)
		return Color3.fromHex(data[key])
	end
	local model = Instance.new("Model")
	model.Name = "Fighter" .. slot
	model:SetAttribute("Slot", slot)
	model:SetAttribute("Character", data.Name)
	local ink = Color3.fromHex("0B0B0E")
	local parts = {}
	local function part(name, size, pos, partColor, className)
		local p = Instance.new(className or "Part")
		p.Name, p.Size, p.Color = name, size, partColor
		p.CFrame = if typeof(pos) == "CFrame" then pos else CFrame.new(pos)
		p.Material = Enum.Material.SmoothPlastic
		p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = false, false, false, true
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.CastShadow = name ~= "HumanoidRootPart" -- the body casts a shadow on the deck
		p.Parent = model
		if not parts[name] then parts[name] = p end
		return p
	end
	-- Body parts and joints from the shared geometry (the offline animation tests use it too).
	local spec = RigSpec.KAI
	local custom = BODIES[data.Kit] -- every kit but KAI has its own hair and clothes (BODIES)
	local PART_COLORS = {
		HumanoidRootPart = ink, LowerTorso = color("Pants"), UpperTorso = color("Shirt"), Head = color("SkinTone"),
		UpperArm = color("SkinTone"), LowerArm = color("Wraps"), Hand = color("Wraps"),
		UpperLeg = color("Pants"), LowerLeg = color("PantsShade"), Foot = color("Shoes"),
	}
	if custom then custom.colors(PART_COLORS, color) end
	local ORDER = { "HumanoidRootPart", "LowerTorso", "UpperTorso", "Head" }
	for _, side in { "Left", "Right" } do
		for _, piece in { "UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot" } do
			table.insert(ORDER, side .. piece)
		end
	end
	for _, name in ORDER do
		local p = spec.parts[name]
		local kind = name:gsub("^Left", ""):gsub("^Right", "")
		part(name, Vector3.new(p.size[1], p.size[2], p.size[3]), Vector3.new(p.pos[1], p.pos[2], p.pos[3]),
			PART_COLORS[kind] or PART_COLORS[name])
	end
	local root = parts.HumanoidRootPart
	root.Transparency, root.Anchored = 1, true
	for _, j in spec.joints do
		local a, b = parts[j.part0], parts[j.part1]
		local pivot = CFrame.new(j.pivot[1], j.pivot[2], j.pivot[3])
		local motor = Instance.new("Motor6D")
		motor.Name, motor.Part0, motor.Part1 = j.name, a, b
		motor.C0 = a.CFrame:ToObjectSpace(pivot)
		motor.C1 = b.CFrame:ToObjectSpace(pivot)
		motor.Parent = b
	end

	-- Cosmetics: offset is relative to the bind pose of the part they are welded to.
	local function ornament(parentName, name, size, offset, partColor, className)
		local base = parts[parentName]
		local p = part(name, size, base.CFrame * offset, partColor, className)
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = base, p, p
		return p
	end
	local function shaped(parentName, name, size, offset, partColor, shape)
		local p = ornament(parentName, name, size, offset, partColor)
		p.Shape = shape
		return p
	end
	local skin, hair, hairTip = color("SkinTone"), color("Hair"), color("HairTip")
	local wrapLine = Color3.fromHex("C3C3CC")
	local white = Color3.fromHex("F7F7FA")

	-- Neck, ears and face (front of the rig is -Z): sharp eyes with ink lids and highlights.
	shaped("UpperTorso", "Neck", Vector3.new(0.55, 0.52, 0.52), CFrame.new(0, 0.82, 0.02) * CFrame.Angles(0, 0, math.pi / 2), skin, Enum.PartType.Cylinder)
	for _, sign in { -1, 1 } do
		ornament("Head", "Ear", Vector3.new(0.1, 0.3, 0.22), CFrame.new(sign * 0.57, -0.02, 0.05), skin)
		ornament("Head", "EyeWhite", Vector3.new(0.32, 0.15, 0.04), CFrame.new(sign * 0.23, 0.03, -0.51), white)
		ornament("Head", "Iris", Vector3.new(0.14, 0.15, 0.04), CFrame.new(sign * 0.19, 0.02, -0.53), color("Eyes"))
		ornament("Head", "Pupil", Vector3.new(0.06, 0.09, 0.04), CFrame.new(sign * 0.19, 0.02, -0.535), ink)
		local glint = ornament("Head", "EyeGlint", Vector3.new(0.04, 0.04, 0.04), CFrame.new(sign * 0.16, 0.06, -0.55), white)
		glint.Material = Enum.Material.Neon
		ornament("Head", "Lid", Vector3.new(0.38, 0.05, 0.05),
			CFrame.new(sign * 0.23, 0.12, -0.525) * CFrame.Angles(0, 0, sign * 0.18), ink)
		ornament("Head", "Brow", Vector3.new(0.38, 0.08, 0.05),
			CFrame.new(sign * 0.24, 0.22, -0.53) * CFrame.Angles(0, 0, sign * 0.34), ink)
		if not custom then -- (KAI's side locks; the other kits have their own hair)
			ornament("Head", "SideLock", Vector3.new(0.16, 0.8, 0.55), CFrame.new(sign * 0.6, 0.02, -0.12), hair)
			ornament("Head", "SideSpike", Vector3.new(0.18, 0.55, 0.5),
				CFrame.new(sign * 0.62, -0.42, -0.1) * CFrame.Angles(math.rad(180), 0, sign * 0.25), hair, "WedgePart")
		end
	end
	ornament("Head", "Nose", Vector3.new(0.12, 0.14, 0.12), CFrame.new(0, -0.1, -0.54) * CFrame.Angles(math.rad(180), 0, 0), skin, "WedgePart")
	ornament("Head", "Mouth", Vector3.new(0.26, 0.04, 0.04), CFrame.new(0.02, -0.3, -0.51) * CFrame.Angles(0, 0, 0.08), ink)
	ornament("Head", "Jaw", Vector3.new(0.9, 0.12, 0.8), CFrame.new(0, -0.53, -0.04), skin)

	-- Shared context of the kits' own bodies (see BODIES).
	local function bodyTail(regionName, name, size, pivot, partColor)
		local base = parts[regionName]
		local p = part(name, size, base.CFrame, partColor)
		return hangTail(base, p, pivot)
	end
	local ctx = { ornament = ornament, shaped = shaped, tail = bodyTail, parts = parts, color = color, data = data,
		ink = ink, white = white, skin = skin, hair = hair, hairTip = hairTip }
	if custom then
		custom.head(ctx)
	else
	-- Messy spiky black hair with red highlights: cap, fringe, crown and back spikes.
	ornament("Head", "HairCap", Vector3.new(1.24, 0.42, 1.14), CFrame.new(0, 0.48, 0.04), hair)
	for i, x in { -0.42, -0.2, 0.02, 0.24, 0.44 } do
		ornament("Head", "Fringe", Vector3.new(0.26, 0.5 + (i % 2) * 0.15, 0.12),
			CFrame.new(x, 0.26 - (i % 2) * 0.06, -0.56) * CFrame.Angles(math.rad(180), 0, (i - 3) * 0.22),
			if i == 2 then hairTip else hair, "WedgePart")
	end
	local crown = {
		{ x = -0.48, h = 0.8, tilt = -0.55, z = 0.1, tip = false },
		{ x = -0.3, h = 1.15, tilt = -0.3, z = 0.0, tip = true },
		{ x = -0.08, h = 1.4, tilt = -0.08, z = 0.18, tip = false },
		{ x = 0.12, h = 1.55, tilt = 0.05, z = -0.05, tip = false },
		{ x = 0.32, h = 1.2, tilt = 0.28, z = 0.1, tip = true },
		{ x = 0.5, h = 0.85, tilt = 0.55, z = 0.05, tip = false },
	}
	for _, sp in crown do
		ornament("Head", "HairSpike", Vector3.new(0.3, sp.h, 1.15),
			CFrame.new(sp.x, 0.62 + sp.h / 2, sp.z + 0.12) * CFrame.Angles(0, 0, sp.tilt), if sp.tip then hairTip else hair, "WedgePart")
	end
	for i, sign in { -1, 0, 1 } do
		ornament("Head", "BackSpike", Vector3.new(0.34, 1 - math.abs(sign) * 0.15, 0.85),
			CFrame.new(sign * 0.32, 0.12 - i * 0.03, 0.72) * CFrame.Angles(math.rad(-118), 0, sign * 0.35), hair, "WedgePart")
	end
	end

	if custom then
		custom.body(ctx)
	else
	-- Tank top: scoop neckline, chest and abs lines drawn in ink.
	ornament("UpperTorso", "Neckline", Vector3.new(0.62, 0.26, 0.04), CFrame.new(0, 0.58, -0.505), skin)
	for _, sign in { -1, 1 } do
		ornament("UpperTorso", "ChestLine", Vector3.new(0.6, 0.04, 0.04), CFrame.new(sign * 0.33, 0.12, -0.51) * CFrame.Angles(0, 0, sign * -0.18), ink)
	end
	ornament("UpperTorso", "AbsLine", Vector3.new(0.04, 0.45, 0.04), CFrame.new(0, -0.35, -0.51), Color3.fromHex("BDBDC6"))

	-- Open sleeveless vest: front panels, raised collar lined in red, flared hem, 開 on the back.
	local vest, trim = color("Vest"), color("VestTrim")
	for _, sign in { -1, 1 } do
		ornament("UpperTorso", "VestFront", Vector3.new(0.6, 1.62, 0.08), CFrame.new(sign * 0.67, -0.1, -0.52), vest)
		ornament("UpperTorso", "VestSide", Vector3.new(0.08, 1.62, 1.04), CFrame.new(sign * 0.98, -0.1, 0), vest)
		ornament("UpperTorso", "VestTrim", Vector3.new(0.06, 1.62, 0.1), CFrame.new(sign * 0.35, -0.1, -0.55), trim)
		ornament("UpperTorso", "Shoulder", Vector3.new(0.52, 0.18, 1.08), CFrame.new(sign * 0.72, 0.68, 0), vest)
		ornament("UpperTorso", "CollarSide", Vector3.new(0.14, 0.55, 0.62),
			CFrame.new(sign * 0.6, 0.86, 0.12) * CFrame.Angles(0, 0, sign * -0.12), vest)
		ornament("UpperTorso", "CollarLining", Vector3.new(0.05, 0.5, 0.58),
			CFrame.new(sign * 0.52, 0.86, 0.12) * CFrame.Angles(0, 0, sign * -0.12), trim)
	end
	ornament("UpperTorso", "VestBack", Vector3.new(1.96, 1.62, 0.08), CFrame.new(0, -0.1, 0.52), vest)
	ornament("UpperTorso", "Collar", Vector3.new(1.3, 0.58, 0.16), CFrame.new(0, 0.9, 0.42) * CFrame.Angles(math.rad(-12), 0, 0), vest)
	ornament("UpperTorso", "CollarLiningBack", Vector3.new(1.2, 0.5, 0.05), CFrame.new(0, 0.9, 0.33) * CFrame.Angles(math.rad(-12), 0, 0), trim)
	local back = parts.VestBack
	if back then
		local emblem = Instance.new("SurfaceGui")
		emblem.Name, emblem.Face, emblem.LightInfluence = "Emblem", Enum.NormalId.Back, 0
		emblem.CanvasSize = Vector2.new(200, 160)
		local kanji = Instance.new("TextLabel")
		kanji.BackgroundTransparency, kanji.Size = 1, UDim2.fromScale(1, 1)
		kanji.Text, kanji.TextScaled, kanji.Font = data.Kanji, true, Enum.Font.GothamBlack
		kanji.TextColor3 = trim
		kanji.Parent = emblem
		emblem.Parent = back
	end

	-- Arms: deltoids and biceps, forearm wraps with bands, knuckle wraps.
	for _, side in { "Left", "Right" } do
		local sign = if side == "Left" then -1 else 1
		shaped(side .. "UpperArm", "Deltoid", Vector3.new(0.82, 0.82, 0.82), CFrame.new(0, 0.32, 0), skin, Enum.PartType.Ball)
		shaped(side .. "UpperArm", "Bicep", Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, -0.08, -0.13), skin, Enum.PartType.Ball)
		for i, y in { 0.3, 0.08, -0.14, -0.36 } do
			ornament(side .. "LowerArm", "WrapBand", Vector3.new(0.66, 0.06, 0.7),
				CFrame.new(0, y, 0) * CFrame.Angles(0, 0, (if i % 2 == 0 then 1 else -1) * 0.18), wrapLine)
		end
		ornament(side .. "Hand", "Knuckles", Vector3.new(0.78, 0.16, 0.2), CFrame.new(0, -0.12, -0.32), wrapLine)
		ornament(side .. "Hand", "Thumb", Vector3.new(0.2, 0.32, 0.26), CFrame.new(-sign * 0.38, 0.02, -0.22), skin)
		-- Baggy pants: wide thighs, folds, gathered cuffs; sneakers with toe cap, stripe and laces.
		ornament(side .. "UpperLeg", "Thigh", Vector3.new(0.94, 0.9, 0.98), CFrame.new(0, 0.1, 0), color("Pants"))
		ornament(side .. "UpperLeg", "Fold", Vector3.new(0.5, 0.04, 0.04),
			CFrame.new(sign * 0.1, -0.35, -0.5) * CFrame.Angles(0, 0, sign * 0.3), ink)
		ornament(side .. "LowerLeg", "Fold", Vector3.new(0.45, 0.04, 0.04),
			CFrame.new(-sign * 0.05, 0.25, -0.44) * CFrame.Angles(0, 0, sign * -0.3), ink)
		ornament(side .. "LowerLeg", "PantsCuff", Vector3.new(0.9, 0.26, 0.94), CFrame.new(0, -0.38, 0), color("PantsShade"))
		ornament(side .. "Foot", "Sole", Vector3.new(0.84, 0.12, 1.26), CFrame.new(0, -0.18, 0), color("Sole"))
		ornament(side .. "Foot", "ToeCap", Vector3.new(0.82, 0.24, 0.32), CFrame.new(0, -0.07, -0.47), color("Shoes"))
		ornament(side .. "Foot", "ShoeStripe", Vector3.new(0.86, 0.12, 0.62), CFrame.new(0, 0.0, 0.12) * CFrame.Angles(0.25, 0, 0), color("ShoeAccent"))
		ornament(side .. "Foot", "HeelTab", Vector3.new(0.3, 0.3, 0.1), CFrame.new(0, 0.12, 0.6), color("ShoeAccent"))
		for i = 0, 2 do
			ornament(side .. "Foot", "Lace", Vector3.new(0.4, 0.04, 0.04), CFrame.new(0, 0.21, -0.32 + i * 0.16), ink)
		end
	end

	-- Red sash: thick wrap, big knot and long tails (front and back).
	local sash = color("Sash")
	ornament("LowerTorso", "Sash", Vector3.new(1.78, 0.38, 1.02), CFrame.new(0, 0.18, 0), sash)
	ornament("LowerTorso", "SashKnot", Vector3.new(0.44, 0.38, 0.16), CFrame.new(-0.36, 0.18, -0.55) * CFrame.Angles(0, 0, 0.3), sash)
	local function tail(name, size, pivot)
		local base = parts.LowerTorso
		local p = part(name, size, base.CFrame, sash)
		return hangTail(base, p, pivot)
	end
	tail("SashTail", Vector3.new(0.26, 1.7, 0.06), CFrame.new(-0.48, 0.15, -0.56) * CFrame.Angles(0, 0, -0.14))
	tail("SashTail", Vector3.new(0.22, 1.35, 0.06), CFrame.new(-0.24, 0.12, -0.57) * CFrame.Angles(0, 0, 0.12))
	tail("SashTailBack", Vector3.new(0.28, 1.8, 0.06), CFrame.new(0.4, 0.18, 0.54) * CFrame.Angles(math.rad(14), 0, 0.12))
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.AutoRotate, humanoid.EvaluateStateMachine = false, false
	humanoid.AutomaticScalingEnabled = false
	humanoid.BreakJointsOnDeath, humanoid.RequiresNeck = false, false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed, humanoid.JumpPower = 0, 0
	humanoid.Parent = model
	-- Ink outline; it does not replace drawn inner lines (see the project guide).
	local outline = Instance.new("Highlight")
	outline.Name, outline.Adornee = "InkOutline", model
	outline.FillTransparency, outline.FillColor = 1, Color3.new(1, 1, 1)
	outline.OutlineColor, outline.OutlineTransparency = ink, 0
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = model
	-- Another kit: its outfit over the block body (gloves, scarf, hood...).
	-- (TARO's body draws its own kanji, a tattoo; the others carry it on the back)
	if data.Kit ~= "KAI" then RigBuilder.applyKit(model, slot, data.Kit == "TARO", true) end
	model:SetAttribute("Kit", data.Kit)
	model:SetAttribute("Skin", data.Skin)
	model.PrimaryPart, model.Parent = root, parent
	model:SetAttribute("RootHeight", 3)
	return model
end

-- Body regions an outfit is attached to, found on any body: an R15 part, or the matching
-- slice of a rigid R6 part (an R6 arm is upper arm, forearm and hand in one block). Each R6
-- entry is { R6 part, centre and height of the slice as fractions of the part's height }.
local R6_REGIONS = {
	UpperTorso = { "Torso", 0.15, 0.7 }, LowerTorso = { "Torso", -0.36, 0.28 },
}
for _, side in { "Left", "Right" } do
	R6_REGIONS[side .. "UpperArm"] = { side .. " Arm", 0.25, 0.45 }
	R6_REGIONS[side .. "LowerArm"] = { side .. " Arm", -0.2, 0.35 }
	R6_REGIONS[side .. "Hand"] = { side .. " Arm", -0.42, 0.16 }
	R6_REGIONS[side .. "UpperLeg"] = { side .. " Leg", 0.25, 0.45 }
	R6_REGIONS[side .. "LowerLeg"] = { side .. " Leg", -0.2, 0.35 }
	R6_REGIONS[side .. "Foot"] = { side .. " Leg", -0.43, 0.14 }
end

-- Visible size of a head: a classic head mesh is drawn smaller than its 2 x 1 x 1 part.
local function headSize(head)
	local s = head.Size
	local mesh = head:FindFirstChildOfClass("SpecialMesh")
	if mesh and mesh.MeshType == Enum.MeshType.Head then
		return Vector3.new(s.Y * mesh.Scale.X, s.Y * mesh.Scale.Y, s.Y * mesh.Scale.Z)
	end
	return Vector3.new(math.min(s.X, s.Y * 1.25), s.Y, math.min(s.Z, s.Y * 1.25))
end

-- The part carrying a region, the region's frame in that part and its size.
local function region(model, name)
	local part = model:FindFirstChild(name)
	if part and part:IsA("BasePart") then
		return part, CFrame.identity, if name == "Head" then headSize(part) else part.Size
	end
	local slice = R6_REGIONS[name]
	part = slice and model:FindFirstChild(slice[1])
	if not part or not part:IsA("BasePart") then return nil, nil, nil end
	local s = part.Size
	return part, CFrame.new(0, s.Y * slice[2], 0), Vector3.new(s.X, s.Y * slice[3], s.Z)
end

local SIDES = { { "Left", -1 }, { "Right", 1 } }

-- Kit outfits. `o` gives: piece(region, name, size, offset, color, shape), tail(region,
-- name, size, pivot, color) for a swaying strip, size(region), color(key) and the style's
-- main (Sash) and second (Wraps) colours. Offsets are relative to the region's centre; the
-- front of every body is -Z.
local OUTFITS = {}

-- KAI 開: hachimaki with two tails, sash with a knot and long tails, hand wraps.
function OUTFITS.KAI(o)
	local head = o.size("Head")
	o.piece("Head", "Headband", Vector3.new(head.X * 1.04, head.Y * 0.16, head.Z * 1.04), CFrame.new(0, head.Y * 0.18, 0), o.main)
	o.piece("Head", "HeadbandKnot", Vector3.new(0.3, 0.22, 0.16), CFrame.new(0, head.Y * 0.16, head.Z * 0.53), o.main)
	for i, sign in { -1, 1 } do
		o.tail("Head", "HeadbandTail", Vector3.new(0.18, 0.95 + i * 0.25, 0.06),
			CFrame.new(sign * 0.1, head.Y * 0.14, head.Z * 0.56) * CFrame.Angles(math.rad(-58 - i * 8), 0, sign * 0.25), o.main)
	end
	local waist = o.size("LowerTorso")
	o.piece("LowerTorso", "Sash", Vector3.new(waist.X * 1.08, math.max(0.3, waist.Y * 0.38), waist.Z * 1.12), CFrame.new(0, waist.Y * 0.15, 0), o.main)
	o.piece("LowerTorso", "SashKnot", Vector3.new(0.42, 0.36, 0.16), CFrame.new(-waist.X * 0.22, waist.Y * 0.15, -waist.Z * 0.58) * CFrame.Angles(0, 0, 0.3), o.main)
	o.tail("LowerTorso", "SashTail", Vector3.new(0.26, 1.5, 0.06), CFrame.new(-waist.X * 0.3, waist.Y * 0.12, -waist.Z * 0.6) * CFrame.Angles(0, 0, -0.14), o.main)
	o.tail("LowerTorso", "SashTail2", Vector3.new(0.22, 1.2, 0.06), CFrame.new(-waist.X * 0.14, waist.Y * 0.1, -waist.Z * 0.61) * CFrame.Angles(0, 0, 0.12), o.main)
	o.tail("LowerTorso", "SashTailBack", Vector3.new(0.28, 1.6, 0.06), CFrame.new(waist.X * 0.25, waist.Y * 0.15, waist.Z * 0.6) * CFrame.Angles(math.rad(14), 0, 0.12), o.main)
	for _, side in SIDES do
		local arm = o.size(side[1] .. "LowerArm")
		for i, y in { 0.28, 0.02, -0.24 } do
			o.piece(side[1] .. "LowerArm", "Wrap" .. i, Vector3.new(arm.X * 1.1, 0.1, arm.Z * 1.1),
				CFrame.new(0, y * arm.Y, 0) * CFrame.Angles(0, 0, (if i % 2 == 0 then 1 else -1) * 0.16), o.second)
		end
		local hand = o.size(side[1] .. "Hand")
		o.piece(side[1] .. "Hand", "Knuckles", Vector3.new(hand.X * 1.1, hand.Y * 0.4, hand.Z * 1.1), CFrame.new(0, -hand.Y * 0.1, 0), o.second)
	end
end

-- TARO 火, the boxer: big gloves with laced cuffs, trunks and a champion belt.
function OUTFITS.TARO(o)
	for _, side in SIDES do
		local name, sign = side[1], side[2]
		local hand = o.size(name .. "Hand")
		local w = math.max(hand.X, hand.Z)
		o.piece(name .. "Hand", "Glove", Vector3.new(w * 1.3, w * 1.2, w * 1.36), CFrame.new(0, -w * 0.04, -w * 0.06), o.main)
		o.piece(name .. "Hand", "GloveKnuckles", Vector3.one * w * 1.3, CFrame.new(0, -w * 0.12, -w * 0.2), o.main, Enum.PartType.Ball)
		o.piece(name .. "Hand", "GloveThumb", Vector3.new(w * 0.36, w * 0.66, w * 0.5), CFrame.new(-sign * w * 0.62, w * 0.04, -w * 0.28), o.main)
		local arm = o.size(name .. "LowerArm")
		o.piece(name .. "LowerArm", "Cuff", Vector3.new(arm.X * 1.28, arm.Y * 0.3, arm.Z * 1.28), CFrame.new(0, -arm.Y * 0.3, 0), o.second)
		o.piece(name .. "LowerArm", "Lace", Vector3.new(arm.X * 0.12, arm.Y * 0.26, 0.06), CFrame.new(0, -arm.Y * 0.3, -arm.Z * 0.66), o.main)
		local thigh = o.size(name .. "UpperLeg")
		if not o.block then
		o.piece(name .. "UpperLeg", "Trunks", Vector3.new(thigh.X * 1.14, thigh.Y * 0.6, thigh.Z * 1.14), CFrame.new(0, thigh.Y * 0.22, 0), o.color("Pants"))
		o.piece(name .. "UpperLeg", "TrunksStripe", Vector3.new(0.08, thigh.Y * 0.6, thigh.Z * 1.16), CFrame.new(sign * thigh.X * 0.57, thigh.Y * 0.22, 0), o.second)
		end
	end
	-- Towel around the neck, ends on the chest (avatars; the block body draws its own).
	if not o.block then
		local chest = o.size("UpperTorso")
		local towel = o.color("Shirt")
		o.piece("UpperTorso", "Towel", Vector3.new(chest.X * 0.7, 0.26, chest.Z * 1.16), CFrame.new(0, chest.Y * 0.5, 0), towel)
		for _, side in SIDES do
			o.piece("UpperTorso", "TowelEnd", Vector3.new(chest.X * 0.17, chest.Y * 0.55, 0.1),
				CFrame.new(side[2] * chest.X * 0.18, chest.Y * 0.2, -chest.Z * 0.58), towel)
		end
	end
	local waist = o.size("LowerTorso")
	local beltY = math.max(0.3, waist.Y * 0.45)
	o.piece("LowerTorso", "Belt", Vector3.new(waist.X * 1.1, beltY, waist.Z * 1.14), CFrame.new(0, waist.Y * 0.2, 0), o.color("Pants"))
	o.piece("LowerTorso", "BeltPlate", Vector3.new(waist.X * 0.42, beltY * 1.5, 0.1), CFrame.new(0, waist.Y * 0.2, -waist.Z * 0.6), o.second)
	o.piece("LowerTorso", "BeltGem", Vector3.new(waist.X * 0.16, beltY * 0.7, 0.06), CFrame.new(0, waist.Y * 0.2, -waist.Z * 0.66), o.energy).Material = Enum.Material.Neon
end

-- ZEPHYR 風, the kicker: a long scarf streaming behind, shin guards and ankle wraps.
function OUTFITS.ZEPHYR(o)
	local chest = o.size("UpperTorso")
	o.piece("UpperTorso", "Scarf", Vector3.new(chest.X * 0.66, 0.34, chest.Z * 1.2), CFrame.new(0, chest.Y * 0.5, 0), o.main)
	o.piece("UpperTorso", "ScarfFold", Vector3.new(chest.X * 0.3, 0.42, 0.14), CFrame.new(-chest.X * 0.14, chest.Y * 0.4, -chest.Z * 0.6) * CFrame.Angles(0, 0, 0.2), o.main)
	o.tail("UpperTorso", "ScarfTail", Vector3.new(0.32, 2.3, 0.07), CFrame.new(-0.14, chest.Y * 0.48, chest.Z * 0.6) * CFrame.Angles(math.rad(-24), 0, -0.12), o.main)
	o.tail("UpperTorso", "ScarfTail2", Vector3.new(0.26, 1.85, 0.07), CFrame.new(0.14, chest.Y * 0.46, chest.Z * 0.6) * CFrame.Angles(math.rad(-14), 0, 0.14), o.main)
	for _, side in SIDES do
		local name = side[1]
		local shin = o.size(name .. "LowerLeg")
		o.piece(name .. "LowerLeg", "ShinGuard", Vector3.new(shin.X * 1.12, shin.Y * 0.72, shin.Z * 0.4), CFrame.new(0, shin.Y * 0.02, -shin.Z * 0.42), o.second)
		for i, y in { 0.28, -0.24 } do
			o.piece(name .. "LowerLeg", "GuardStrap" .. i, Vector3.new(shin.X * 1.16, 0.1, shin.Z * 1.16), CFrame.new(0, y * shin.Y, 0), o.main)
		end
		local foot = o.size(name .. "Foot")
		o.piece(name .. "Foot", "AnkleWrap", Vector3.new(foot.X * 1.1, math.min(0.18, foot.Y * 0.7), foot.Z * 0.9), CFrame.new(0, foot.Y * 0.35, foot.Z * 0.05), o.main)
	end
end

-- AKEMI 影, the shadow: hood, face mask with a trailing knot, bracers and a thin obi.
function OUTFITS.AKEMI(o)
	local head = o.size("Head")
	local hood = o.color("Vest")
	o.piece("Head", "HoodTop", Vector3.new(head.X * 1.14, head.Y * 0.3, head.Z * 1.14), CFrame.new(0, head.Y * 0.42, head.Z * 0.02), hood)
	o.piece("Head", "HoodBack", Vector3.new(head.X * 1.14, head.Y * 0.92, head.Z * 0.16), CFrame.new(0, head.Y * 0.02, head.Z * 0.56), hood)
	for _, side in SIDES do
		o.piece("Head", "HoodSide", Vector3.new(head.X * 0.08, head.Y * 0.74, head.Z * 0.95), CFrame.new(side[2] * head.X * 0.56, head.Y * 0.1, head.Z * 0.06), hood)
	end
	o.piece("Head", "HoodEdge", Vector3.new(head.X * 1.16, 0.08, 0.1), CFrame.new(0, head.Y * 0.28, -head.Z * 0.56), o.second)
	o.piece("Head", "Mask", Vector3.new(head.X * 1.03, head.Y * 0.42, head.Z * 1.03), CFrame.new(0, -head.Y * 0.24, 0), o.main)
	o.tail("Head", "MaskTail", Vector3.new(0.16, 1.2, 0.05), CFrame.new(0, -head.Y * 0.1, head.Z * 0.56) * CFrame.Angles(math.rad(-34), 0, 0.15), o.second)
	for _, side in SIDES do
		local arm = o.size(side[1] .. "LowerArm")
		o.piece(side[1] .. "LowerArm", "Bracer", Vector3.new(arm.X * 1.12, arm.Y * 0.66, arm.Z * 1.12), CFrame.new(0, -arm.Y * 0.04, 0), o.main)
		for i, y in { 0.3, -0.36 } do
			o.piece(side[1] .. "LowerArm", "BracerBand" .. i, Vector3.new(arm.X * 1.16, 0.08, arm.Z * 1.16), CFrame.new(0, y * arm.Y, 0), o.second)
		end
	end
	local waist = o.size("LowerTorso")
	o.piece("LowerTorso", "Obi", Vector3.new(waist.X * 1.08, math.max(0.24, waist.Y * 0.32), waist.Z * 1.12), CFrame.new(0, waist.Y * 0.18, 0), o.second)
	o.tail("LowerTorso", "ObiTail", Vector3.new(0.18, 1.1, 0.05), CFrame.new(waist.X * 0.3, waist.Y * 0.15, waist.Z * 0.6) * CFrame.Angles(math.rad(10), 0, 0.1), o.second)
end

-- RYUKEN 拳: red bandages up both forearms and a cracked black gauntlet on the right fist,
-- its cracks glowing.
function OUTFITS.RYUKEN(o)
	for _, side in SIDES do
		local name = side[1]
		local arm = o.size(name .. "LowerArm")
		for i, y in { 0.32, 0.1, -0.12, -0.34 } do
			o.piece(name .. "LowerArm", "Bandage" .. i, Vector3.new(arm.X * 1.08, 0.1, arm.Z * 1.08),
				CFrame.new(0, y * arm.Y, 0) * CFrame.Angles(0, 0, (if i % 2 == 0 then 1 else -1) * 0.18), o.second)
		end
	end
	local hand = o.size("RightHand")
	local w = math.max(hand.X, hand.Z)
	o.piece("RightHand", "Gauntlet", Vector3.new(w * 1.2, w * 1.0, w * 1.22), CFrame.new(0, -w * 0.05, 0), o.color("Shirt"))
	for i = 1, 3 do
		o.piece("RightHand", "Crack" .. i, Vector3.new(w * 0.06, w * 0.7, 0.04), CFrame.new((i - 2) * w * 0.3, -w * 0.05, -w * 0.62)
			* CFrame.Angles(0, 0, (i - 2) * 0.5), o.energy).Material = Enum.Material.Neon
	end
end

-- SHIN 流: a katana in the right hand (its edge glowing), the sheath at the left hip, and on
-- avatars a high collar.
function OUTFITS.SHIN(o)
	o.weapon(WeaponSpec.SHIN)
	local waist = o.size("LowerTorso")
	o.piece("LowerTorso", "Sheath", Vector3.new(0.2, 0.24, 3.0), CFrame.new(-waist.X * 0.52, 0, waist.Z * 0.2)
		* CFrame.Angles(math.rad(-20), math.rad(10), 0), INK)
	if not o.block then
		local head = o.size("Head")
		o.piece("Head", "Collar", Vector3.new(head.X * 1.06, head.Y * 0.38, head.Z * 1.06), CFrame.new(0, -head.Y * 0.36, 0), o.main)
	end
end

-- DAICHA 闇: a sphere of shadow floating by the left hand (its glowing core), and on avatars
-- the violet obi.
function OUTFITS.DAICHA(o)
	o.weapon(WeaponSpec.DAICHA)
	if not o.block then
		local waist = o.size("LowerTorso")
		o.piece("LowerTorso", "Obi", Vector3.new(waist.X * 1.08, math.max(0.3, waist.Y * 0.4), waist.Z * 1.12), CFrame.new(0, waist.Y * 0.12, 0), o.main)
		o.tail("LowerTorso", "ObiTail", Vector3.new(0.2, 1.2, 0.05), CFrame.new(0, waist.Y * 0.1, waist.Z * 0.6), o.main)
	end
end

-- HIBECARES 崩: stone gauntlets on both fists, chains wound round the forearms, and on avatars
-- the red headband.
function OUTFITS.HIBECARES(o)
	local metal = Color3.fromHex("4A4A52")
	for _, side in SIDES do
		local name = side[1]
		local hand = o.size(name .. "Hand")
		local w = math.max(hand.X, hand.Z)
		o.piece(name .. "Hand", "StoneFist", Vector3.new(w * 1.32, w * 1.12, w * 1.34), CFrame.new(0, -w * 0.06, -w * 0.04), o.second).Material = Enum.Material.Slate
		o.piece(name .. "Hand", "Ember", Vector3.new(w * 0.5, 0.06, 0.04), CFrame.new(0, -w * 0.1, -w * 0.68), o.energy).Material = Enum.Material.Neon
		local arm = o.size(name .. "LowerArm")
		for i, y in { 0.3, 0.05, -0.2 } do
			o.piece(name .. "LowerArm", "Chain" .. i, Vector3.new(arm.X * 1.14, 0.12, arm.Z * 1.14),
				CFrame.new(0, y * arm.Y, 0) * CFrame.Angles(0, 0, (if i % 2 == 0 then 1 else -1) * 0.25), metal).Material = Enum.Material.Metal
		end
	end
	if not o.block then
		local head = o.size("Head")
		o.piece("Head", "Headband", Vector3.new(head.X * 1.05, head.Y * 0.18, head.Z * 1.05), CFrame.new(0, head.Y * 0.2, 0), o.main)
	end
end

--[[
	The kit's outfit worn over a body (a Roblox R15 or R6 avatar, or the block model of a kit
	other than KAI): every piece is sized from the body's own parts so it fits any avatar, and
	the kit's kanji goes on the back unless `noEmblem` (the block model draws its own).
]]
function RigBuilder.applyKit(model, slot, noEmblem, block)
	local data = CharacterData[slot]
	local function color(key)
		return Color3.fromHex(data[key] or "FFFFFF")
	end
	local function newPiece(name, size, partColor, shape)
		local p = Instance.new("Part")
		p.Name, p.Size, p.Color = "Kit" .. name, size, partColor
		p.Material = Enum.Material.SmoothPlastic
		p.CanCollide, p.CanTouch, p.CanQuery, p.Massless, p.CastShadow = false, false, false, true, true
		if shape then p.Shape = shape end
		return p
	end
	-- (block: the kit's own block body, which already draws some pieces, e.g. TARO's towel)
	local o = { main = color("Sash"), second = color("Wraps"), energy = color("Energy"), color = color, block = block == true }
	function o.size(name)
		local _, _, size = region(model, name)
		return size or Vector3.one
	end
	function o.piece(regionName, name, size, offset, partColor, shape)
		local base, frame = region(model, regionName)
		if not base then return newPiece(name, size, partColor, shape) end -- unparented, harmless
		local p = newPiece(name, size, partColor, shape)
		p.CFrame = base.CFrame * frame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = base, p, p
		p.Parent = model
		return p
	end
	-- A held weapon (WeaponSpec): its pieces placed at the grip, in the hand.
	function o.weapon(spec)
		local hand = o.size(spec.hand)
		local g = if model:FindFirstChild(spec.hand) then spec.grip else spec.r6Grip or spec.grip
		local grip = CFrame.new(0, hand.Y * g.y, g.z) * CFrame.Angles(math.rad(g.tilt), 0, 0)
		for _, piece in spec.pieces do
			local partColor = if piece.color == "energy" then o.energy elseif piece.color == "trim" then color("VestTrim")
				else Color3.fromHex(piece.color)
			local p = o.piece(spec.hand, piece.name, Vector3.new(piece.size[1], piece.size[2], piece.size[3]),
				grip * CFrame.new(0, piece.y or 0, piece.z or 0), partColor, piece.shape and Enum.PartType[piece.shape])
			if piece.material then p.Material = Enum.Material[piece.material] end
		end
	end
	function o.tail(regionName, name, size, pivot, partColor)
		local base, frame = region(model, regionName)
		if not base then return end
		local p = newPiece(name, size, partColor)
		hangTail(base, p, frame * pivot)
		p.Parent = model
	end
	local outfit = OUTFITS[data.Kit] or OUTFITS.KAI
	outfit(o)
	-- Kanji on the back: an invisible plate carrying the emblem.
	if not noEmblem then
		local torso = o.size("UpperTorso")
		local plate = o.piece("UpperTorso", "Emblem", Vector3.new(torso.X * 0.7, torso.Y * 0.7, 0.05), CFrame.new(0, 0.05, torso.Z / 2 + 0.04), INK)
		if plate.Parent then
			plate.Transparency = 1
			local gui = Instance.new("SurfaceGui")
			gui.Face, gui.LightInfluence, gui.CanvasSize = Enum.NormalId.Back, 0, Vector2.new(200, 200)
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency, label.Size, label.Text = 1, UDim2.fromScale(1, 1), data.Kanji
			label.TextScaled, label.Font, label.TextColor3 = true, Enum.Font.GothamBlack, o.energy
			local outline = Instance.new("UIStroke")
			outline.Color, outline.Thickness, outline.Parent = INK, 3, label
			label.Parent = gui
			gui.Parent = plate
		end
	end
	model:SetAttribute("Kit", data.Kit)
	model:SetAttribute("Skin", data.Skin)
end

-- Avatar appearances, fetched once per player and cloned for each build (style changes and
-- the CPU's shadow clone rebuild rigs often).
local descriptions = {}

-- The player's HumanoidDescription: from the account (UserId), then from the appearance id
-- (Studio test players have negative UserIds), each tried twice. Returns nil and the reason.
local function describe(player)
	local cached = descriptions[player.UserId]
	if cached and cached.Parent == nil then return cached:Clone(), nil end
	local ids = {}
	if player.UserId > 0 then table.insert(ids, player.UserId) end
	local appearance = player.CharacterAppearanceId
	if appearance and appearance > 0 and appearance ~= player.UserId then table.insert(ids, appearance) end
	if #ids == 0 then return nil, "joueur de test Studio (pas de compte Roblox)" end
	local reason = "inconnue"
	for _, id in ids do
		for attempt = 1, 2 do
			local ok, result = pcall(Players.GetHumanoidDescriptionFromUserId, Players, id)
			if ok and result then
				descriptions[player.UserId] = result
				return result:Clone(), nil
			end
			reason = tostring(result)
			task.wait(attempt * 0.75)
		end
	end
	return nil, reason
end

-- The avatar type the player chose on Roblox ("R15" or "R6"), read once from the account.
-- Studio test players (no account) and failed requests give "R15".
local preferred = {}
function RigBuilder.preferredRig(player)
	local cached = preferred[player.UserId]
	if cached then return cached end
	local rig = "R15"
	if player.UserId > 0 then
		local ok, info = pcall(Players.GetCharacterAppearanceInfoAsync, Players, player.UserId)
		if ok and type(info) == "table" and info.playerAvatarType == "R6" then rig = "R6" end
	end
	preferred[player.UserId] = rig
	return rig
end

local function hasJoints(model, rigType)
	for _, name in if rigType == "R6" then RigSpec.R6_JOINTS else RigSpec.JOINTS do
		local found = false
		for _, d in model:GetDescendants() do
			if d:IsA("Motor6D") and d.Name == name then
				found = true
				break
			end
		end
		if not found then return false, name end
	end
	return true
end

-- Builds a fighter from a HumanoidDescription as an R15 or R6 body (see buildAvatar /
-- buildShadow). Returns the model, or nil and the reason.
local function fromDescription(slot, description, label, rigType)
	rigType = if rigType == "R6" then "R6" else "R15"
	local built, model = pcall(Players.CreateHumanoidModelFromDescription, Players, description, Enum.HumanoidRigType[rigType])
	if not built or not model then
		return nil, "création du corps " .. rigType .. " impossible : " .. tostring(model)
	end
	model.Name = "Fighter" .. slot
	model:SetAttribute("Slot", slot)
	model:SetAttribute("Character", label)
	model:SetAttribute("Rig", rigType)
	for _, d in model:GetDescendants() do
		if d:IsA("BaseScript") then
			d:Destroy() -- no default Animate/Health scripts: the AnimationController owns the joints
		elseif d:IsA("BasePart") then
			d.CanCollide, d.CanTouch, d.CanQuery, d.Massless = false, false, false, true
		end
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		model:Destroy()
		return nil, "corps sans HumanoidRootPart"
	end
	-- Joints the animation can drive (Motor6D), whatever Roblox built (see RigReader).
	local rebuilt = RigReader.ensureJoints(model)
	if rebuilt > 0 then
		model:SetAttribute("JointsRebuilt", rebuilt)
		print(string.format("[FightingGame] Avatar %s : %d articulations reconstruites en Motor6D", rigType, rebuilt))
	end
	local complete, missing = hasJoints(model, rigType)
	if not complete then
		model:Destroy()
		return nil, "articulation " .. tostring(missing) .. " absente"
	end
	root.Anchored, root.Transparency = true, 1
	humanoid.AutoRotate, humanoid.EvaluateStateMachine = false, false
	humanoid.BreakJointsOnDeath, humanoid.RequiresNeck = false, false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed, humanoid.JumpPower = 0, 0
	-- Bring the body to KAI's height (hurtboxes are fixed by the simulation).
	local skeleton = RigReader.skeleton(model)
	local height = skeleton and RigReader.height(skeleton)
	if height and height > 0 and math.abs(TARGET_HEIGHT / height - 1) > HEIGHT_TOLERANCE then
		humanoid.AutomaticScalingEnabled = false
		local factor = math.clamp(TARGET_HEIGHT / height, 0.6, 1.6)
		local scaled, problem = pcall(function() model:ScaleTo(model:GetScale() * factor) end)
		if not scaled then warn("[FightingGame] Mise à l'échelle de l'avatar impossible : " .. tostring(problem)) end
		skeleton = RigReader.skeleton(model)
	end
	model:SetAttribute("RootHeight", if skeleton then -skeleton.floor else humanoid.HipHeight + root.Size.Y / 2)
	local outline = Instance.new("Highlight")
	outline.Name, outline.Adornee = "InkOutline", model
	outline.FillTransparency, outline.FillColor = 1, Color3.new(1, 1, 1)
	outline.OutlineColor, outline.OutlineTransparency = INK, 0
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = model
	model.PrimaryPart = root
	RigBuilder.applyKit(model, slot)
	return model, nil
end

-- A plain body in the kit's colours (no asset id): used when the avatar cannot load.
local function defaultDescription(slot)
	local data = CharacterData[slot]
	local description = Instance.new("HumanoidDescription")
	local skin = Color3.fromHex(data.SkinTone)
	description.HeadColor, description.LeftArmColor, description.RightArmColor = skin, skin, skin
	description.LeftLegColor, description.RightLegColor = Color3.fromHex(data.Pants), Color3.fromHex(data.Pants)
	description.TorsoColor = Color3.fromHex(data.Vest)
	return description
end

--[[
	The player's own Roblox avatar, as an R15 or R6 body (rigType), wearing the kit. Never
	gives up silently:
	  avatar loaded                -> model, "OK"
	  avatar unavailable           -> default body + kit, "DÉFAUT|<reason>"
	  avatar body cannot be built  -> retried without its accessories, then the default body
	Returns nil only if even the default body fails (the server then uses the block model).
]]
function RigBuilder.buildAvatar(slot, player, rigType)
	local description, reason = describe(player)
	if description then
		local model, problem = fromDescription(slot, description, "AVATAR", rigType)
		if model then return model, "OK" end
		reason = problem
		-- Some accessories / layered clothing can fail to build: keep the body and colours.
		local plain = defaultDescription(slot)
		for _, field in { "HeadColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor", "TorsoColor",
			"Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg", "Face",
			"HeightScale", "WidthScale", "DepthScale", "HeadScale", "BodyTypeScale", "ProportionScale" } do
			pcall(function() plain[field] = description[field] end)
		end
		model = fromDescription(slot, plain, "AVATAR", rigType)
		if model then return model, "SANS ACCESSOIRES|" .. tostring(reason) end
	end
	warn("[FightingGame] Avatar indisponible pour " .. player.Name .. " : " .. tostring(reason))
	local model, problem = fromDescription(slot, defaultDescription(slot), "DÉFAUT", rigType)
	if model then return model, "DÉFAUT|" .. tostring(reason) end
	return nil, "MODÈLE|" .. tostring(problem)
end

-- The CPU / training dummy: a shadow clone of the opponent's avatar (dark body, glowing
-- outline), with the same rig type. Without a loadable avatar (Studio test players), a
-- default Roblox body in the slot's colours. No asset id is involved: only colours change.
function RigBuilder.buildShadow(slot, player, rigType)
	local description = if player then describe(player) else nil
	local shadow = description ~= nil
	local data = CharacterData[slot]
	if shadow then
		local body = Color3.fromHex("1A1424")
		description.HeadColor, description.LeftArmColor, description.RightArmColor = body, body, body
		description.LeftLegColor, description.RightLegColor, description.TorsoColor = body, body, body
	else
		description = defaultDescription(slot)
	end
	local model = fromDescription(slot, description, if shadow then "OMBRE" else "DÉFAUT", rigType)
	if not model and shadow then model = fromDescription(slot, defaultDescription(slot), "DÉFAUT", rigType) end
	if model and shadow then
		local outline = model:FindFirstChild("InkOutline")
		if outline then
			outline.FillColor, outline.FillTransparency = Color3.fromHex(data.Energy), 0.72
			outline.OutlineColor = Color3.fromHex(data.Energy)
			model:SetAttribute("BaseFill", 0.72)
		end
	end
	return model
end

return RigBuilder
