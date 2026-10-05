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
local FourArms = require(Shared.FourArms)
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
--[[
	HAIR. A lock is drawn like an anime lock: `segments` boxes that thin and curl from a root
	on the scalp, then a point made of two wedges back to back (it tapers on both faces, not a
	flat blade). `root` is a CFrame in the head's space whose +Y is the lock's direction.
	opts: segments (2-4), curl (radians per segment around X: + bends toward the back),
	sway (around Z), twist (around Y), tip (colour of the last segment and the point).
]]
local function lock(ctx, name, root, length, width, depth, colour, opts)
	opts = opts or {}
	local o = ctx.ornament
	local n = opts.segments or 3
	local seg = length / (n + 0.9)
	local cf = root
	for i = 1, n do
		local t = (i - 1) / n
		local last = i == n
		o("Head", name, Vector3.new(width * (1 - 0.42 * t), seg * 1.14, depth * (1 - 0.38 * t)),
			cf * CFrame.new(0, seg / 2, 0), if last and opts.tip then opts.tip else colour)
		cf = cf * CFrame.new(0, seg, 0) * CFrame.Angles(opts.curl or 0, opts.twist or 0, opts.sway or 0)
	end
	local tipW, tipD, tipL = width * 0.5, depth * 0.62, seg * 1.6
	for _, side in { 1, -1 } do
		-- (a wedge's slope runs up to its back edge: one faces back, its mirror faces front)
		o("Head", name .. "Point", Vector3.new(tipW, tipL, tipD / 2),
			cf * CFrame.new(0, tipL / 2 - seg * 0.08, -side * tipD / 4) * CFrame.Angles(0, if side == 1 then 0 else math.pi, 0),
			opts.tip or colour, "WedgePart")
	end
end

-- A pointed spike (spiky anime hair), in the game's blocky style: two blocks that narrow
-- on all four sides, then a small double-wedge point. It reads pointed from every angle (two
-- crossed blades would only make a cross).
local function spike(ctx, name, root, length, base, colour, tip)
	local o = ctx.ornament
	local steps = { { 1.0, 0.42 }, { 0.56, 0.36 } } -- (width share, length share: two blocks keep the rig light)
	local y = 0
	for i, st in steps do
		local h = length * st[2]
		o("Head", name, Vector3.new(base * st[1], h * 1.08, base * st[1]), root * CFrame.new(0, y + h / 2, 0),
			if i == #steps and tip then tip else colour)
		y += h
	end
	local point, w = length * 0.3, base * 0.34
	for _, side in { 1, -1 } do
		o("Head", name .. "Point", Vector3.new(w, point, w / 2),
			root * CFrame.new(0, y + point / 2 - 0.02, -side * w / 4) * CFrame.Angles(0, if side == 1 then 0 else math.pi, 0),
			tip or colour, "WedgePart")
	end
end

-- A spike rooted at (x, y, z), `back` degrees tipped toward the back, `out` degrees leaning
-- outward (+ to the right).
local function spikeAt(ctx, name, x, y, z, back, out, length, base, colour, tip)
	spike(ctx, name, CFrame.new(x, y, z) * CFrame.Angles(math.rad(back), 0, math.rad(-out)), length, base, colour, tip)
end

-- A lock rooted at (x, y, z) on the head, pointing with the given angles (degrees): `pitch`
-- tips it back (+) or forward (-), `roll` leans it outward (+ to the right).
local function lockAt(ctx, name, x, y, z, pitch, roll, length, width, depth, colour, opts)
	lock(ctx, name, CFrame.new(x, y, z) * CFrame.Angles(math.rad(pitch), 0, math.rad(-roll)), length, width, depth, colour, opts)
end

-- A fringe: short locks hanging over the brow, from x = -0.4 to 0.4 (`n` of them), each a
-- little longer in the middle; `slant` leans them all to one side (degrees).
local function fringe(ctx, n, length, colour, tip, slant)
	for i = 1, n do
		local t = (i - 1) / math.max(1, n - 1)
		local x = -0.4 + 0.8 * t
		spikeAt(ctx, "Fringe", x, 0.5, -0.5, 180 + 14, (t - 0.5) * 24 + (slant or 0), length * (0.8 + 0.3 * math.sin(t * math.pi)),
			0.28, colour, if tip and i == math.ceil(n / 2) then tip else nil)
	end
end

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
		o("Head", "HairBack", Vector3.new(1.2, 0.62, 0.26), CFrame.new(0, 0.22, 0.46), hair)
		-- Hair standing up like flames: tall points straight up, a little back, red at the tips.
		for i, f in { { -0.42, 0.06, -28, 1.3, 12 }, { -0.22, -0.08, -12, 1.75, 6 }, { 0, 0.06, 0, 2.05, 14 },
			{ 0.22, -0.08, 12, 1.8, 6 }, { 0.42, 0.06, 28, 1.35, 12 }, { -0.18, 0.32, -10, 1.5, 40 }, { 0.18, 0.32, 10, 1.45, 40 },
			{ 0, 0.38, 0, 1.3, 60 } } do
			spikeAt(ctx, "HairFlame", f[1], 0.5, f[2], f[5], f[3], f[4], 0.62, hair, if i % 2 == 1 then tip else nil)
		end
		-- (the base of the flames is one mass: no gaps between the points like fingers)
		o("Head", "HairMass", Vector3.new(1.14, 0.55, 0.96), CFrame.new(0, 0.82, 0.08) * CFrame.Angles(math.rad(10), 0, 0), hair)
		for i, x in { -0.36, -0.12, 0.14, 0.38 } do
			spikeAt(ctx, "Fringe", x, 0.5, -0.5, 180 + 12, (i - 2.5) * 14, 0.55, 0.24, hair)
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
		o("Head", "HairBack", Vector3.new(1.26, 0.8, 0.3), CFrame.new(0, 0.12, 0.48), hair)
		-- Wild hair: thick short points every which way above the headband, a shaggy mane
		-- falling over the nape and the ears.
		for i, w in { { -0.44, 0.0, -58, 0.85, 10 }, { -0.26, -0.1, -30, 1.0, -4 }, { -0.06, 0.08, -8, 1.15, 22 },
			{ 0.16, -0.06, 16, 1.05, 4 }, { 0.36, 0.06, 40, 0.95, 18 }, { 0.48, 0.12, 66, 0.8, 30 }, { -0.2, 0.34, -24, 0.95, 70 },
			{ 0.2, 0.34, 22, 0.95, 74 } } do
			spikeAt(ctx, "WildHair", w[1], 0.48, w[2], w[5], w[3], w[4], 0.56, hair, if i == 4 then tip else nil)
		end
		for _, m in { { -0.5, -30 }, { -0.2, -10 }, { 0.14, 10 }, { 0.46, 30 } } do
			spikeAt(ctx, "Shag", m[1], 0.24, 0.46, 180 - 28, m[2], 0.8, 0.4, hair)
		end
		for _, sign in { -1, 1 } do
			spikeAt(ctx, "Shag", sign * 0.6, 0.2, 0.0, 180, sign * -14, 0.6, 0.3, hair)
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
-- ===================================================================== bodies of ASURA and the third sheet

-- Spiky hair from a list of { x, height, tilt, z, lean }: a cap and wedge spikes, `tipEvery`
-- spikes in the tip colour.
local function spikes(ctx, list, tipEvery)
	local o = ctx.ornament
	o("Head", "HairCap", Vector3.new(1.24, 0.4, 1.14), CFrame.new(0, 0.5, 0.04), ctx.hair)
	o("Head", "HairBack", Vector3.new(1.2, 0.7, 0.3), CFrame.new(0, 0.2, 0.45), ctx.hair)
	for i, f in list do
		-- (each a pointed spike from the scalp, fanned out a little more than the list says and
		-- tipped back by its `lean`)
		local lean = f[5] or -20
		spike(ctx, "HairSpike", CFrame.new(f[1] * 0.92, 0.48, (f[4] or 0.08) * 0.8) * CFrame.Angles(math.rad(-lean), 0, f[3] * 1.25),
			f[2] + 0.2, 0.46, ctx.hair, if tipEvery and i % tipEvery == 0 then ctx.hairTip else nil)
	end
end

-- Glowing lines (tattoos, circuits, marks) on a part.
local function glowLines(ctx, partName, list, partColor)
	for i, l in list do
		local p = ctx.ornament(partName, "Glow" .. i, Vector3.new(l[1], l[2], 0.04), CFrame.new(l[3], l[4], l[5] or -0.52)
			* CFrame.Angles(0, 0, l[6] or 0), partColor)
		p.Material = Enum.Material.Neon
	end
end

-- ASURA 阿: KAI out of the Gate, darker: a wild black mane with gold, a third eye of gold on the
-- brow, a bare chest crossed by gold chains, gold armlets, wide black hakama and bare feet.
-- (The second pair of arms comes from addFourArms.)
BODIES.ASURA = {
	colors = function(pc, color)
		pc.UpperTorso, pc.LowerArm, pc.Hand = color("SkinTone"), color("SkinTone"), color("Wraps")
		pc.LowerLeg, pc.Foot = color("Pants"), color("SkinTone")
	end,
	head = function(ctx)
		local o = ctx.ornament
		spikes(ctx, { { -0.5, 1.2, -0.6 }, { -0.3, 1.6, -0.35 }, { -0.1, 1.9, -0.1 }, { 0.12, 2.0, 0.08 }, { 0.32, 1.6, 0.35 },
			{ 0.5, 1.2, 0.6 }, { 0, 1.5, 0, 0.5, -70 } }, 3)
		for _, sign in { -1, 1 } do
			o("Head", "Mane", Vector3.new(0.24, 1.3, 0.9), CFrame.new(sign * 0.62, -0.3, 0.3) * CFrame.Angles(0, 0, sign * 0.12), ctx.hair, "WedgePart")
		end
		local eye = o("Head", "ThirdEye", Vector3.new(0.12, 0.24, 0.04), CFrame.new(0, 0.32, -0.56), ctx.color("Eyes"))
		eye.Material = Enum.Material.Neon
		o("Head", "Diadem", Vector3.new(1.2, 0.12, 1.12), CFrame.new(0, 0.4, 0), ctx.color("Sash")).Material = Enum.Material.Metal
	end,
	body = function(ctx)
		local o, color, ink = ctx.ornament, ctx.color, ctx.ink
		local gold = color("Sash")
		for _, sign in { -1, 1 } do
			o("UpperTorso", "ChestLine", Vector3.new(0.6, 0.04, 0.04), CFrame.new(sign * 0.33, 0.12, -0.51) * CFrame.Angles(0, 0, sign * -0.18), ink)
			material(o("UpperTorso", "GoldChain", Vector3.new(0.12, 1.8, 0.08), CFrame.new(0, 0, -0.54) * CFrame.Angles(0, 0, sign * 0.6), gold), Enum.Material.Metal)
		end
		material(o("UpperTorso", "ChainMedal", Vector3.new(0.34, 0.34, 0.1), CFrame.new(0, 0.02, -0.58), gold), Enum.Material.Metal)
		-- Massive, not taller: slabs of muscle (pecs, trapezius, lats) and gold pauldrons widen him.
		local skin = color("SkinTone")
		for _, sign in { -1, 1 } do
			o("UpperTorso", "Pec", Vector3.new(0.86, 0.6, 0.16), CFrame.new(sign * 0.44, 0.34, -0.52) * CFrame.Angles(math.rad(-6), 0, sign * -0.06), skin)
			o("UpperTorso", "Trapezius", Vector3.new(0.5, 0.34, 0.8), CFrame.new(sign * 0.5, 0.78, 0.06) * CFrame.Angles(0, 0, sign * -0.42), skin, "WedgePart")
			o("UpperTorso", "Lat", Vector3.new(0.16, 1.0, 0.84), CFrame.new(sign * 0.92, 0.1, 0.04) * CFrame.Angles(0, 0, sign * 0.1), skin)
		end
		bareArms(ctx, nil, nil)
		for _, side in { "Left", "Right" } do
			local sign = if side == "Left" then -1 else 1
			material(o(side .. "UpperArm", "Pauldron", Vector3.new(1.08, 0.22, 1.04), CFrame.new(sign * 0.08, 0.5, 0) * CFrame.Angles(0, 0, sign * -0.25), gold), Enum.Material.Metal)
			o(side .. "UpperArm", "Biceps", Vector3.new(0.9, 0.66, 0.92), CFrame.new(0, -0.06, -0.02), skin)
			material(o(side .. "UpperArm", "Armlet", Vector3.new(0.96, 0.16, 0.98), CFrame.new(0, -0.1, 0), gold), Enum.Material.Metal)
			o(side .. "LowerArm", "Forearm", Vector3.new(0.82, 0.58, 0.86), CFrame.new(0, 0.14, 0), skin)
			material(o(side .. "LowerArm", "Bangle", Vector3.new(0.88, 0.26, 0.9), CFrame.new(0, -0.32, 0), gold), Enum.Material.Metal)
			o(side .. "Hand", "Gauntlet", Vector3.new(0.88, 0.42, 0.9), CFrame.new(0, 0.08, 0), color("Wraps"))
		end
		o("LowerTorso", "Sash", Vector3.new(1.8, 0.4, 1.04), CFrame.new(0, 0.18, 0), color("Shirt"))
		ctx.tail("LowerTorso", "SashTail", Vector3.new(0.3, 1.6, 0.06), CFrame.new(-0.4, 0.14, -0.56) * CFrame.Angles(0, 0, -0.12), color("Shirt"))
		ctx.tail("LowerTorso", "SashTailBack", Vector3.new(0.3, 1.8, 0.06), CFrame.new(0.3, 0.16, 0.56) * CFrame.Angles(math.rad(12), 0, 0.1), gold)
		legs(ctx, { wide = true, feet = "bare" })
	end,
}

-- RAIJIN 雷: white hair in spikes swept back with yellow tips, a black sleeveless jacket with a
-- high collar, glowing lightning tattoos down the arms, the spear strapped across his back.
BODIES.RAIJIN = {
	colors = function(pc, color)
		pc.UpperTorso, pc.LowerArm, pc.Hand = color("Vest"), color("SkinTone"), color("SkinTone")
	end,
	head = function(ctx)
		spikes(ctx, { { -0.45, 1.1, -0.5, 0.2, -50 }, { -0.22, 1.4, -0.25, 0.25, -60 }, { 0, 1.6, 0, 0.3, -66 },
			{ 0.22, 1.4, 0.25, 0.25, -60 }, { 0.45, 1.1, 0.5, 0.2, -50 }, { 0, 1.0, 0, 0.6, -90 } }, 2)
		ctx.ornament("Head", "Fringe", Vector3.new(0.9, 0.26, 0.14), CFrame.new(0, 0.38, -0.55) * CFrame.Angles(math.rad(180), 0, 0.1), ctx.hair, "WedgePart")
	end,
	body = function(ctx)
		local o, color = ctx.ornament, ctx.color
		local energy = color("Energy")
		for _, sign in { -1, 1 } do
			o("UpperTorso", "CollarHigh", Vector3.new(0.16, 0.6, 0.8), CFrame.new(sign * 0.56, 0.86, 0.06), color("Vest"))
			o("UpperTorso", "JacketEdge", Vector3.new(0.06, 1.6, 0.06), CFrame.new(sign * 0.18, -0.1, -0.53), color("VestTrim"))
		end
		o("UpperTorso", "Undershirt", Vector3.new(0.3, 1.5, 0.04), CFrame.new(0, -0.1, -0.505), color("Wraps"))
		bareArms(ctx, nil, nil)
		for _, side in { "Left", "Right" } do
			glowLines(ctx, side .. "UpperArm", { { 0.06, 0.6, 0, 0, -0.44, 0.5 }, { 0.06, 0.4, 0.12, -0.3, -0.44, -0.6 } }, energy)
			glowLines(ctx, side .. "LowerArm", { { 0.06, 0.5, 0, 0.1, -0.36, -0.5 }, { 0.06, 0.4, 0.08, -0.25, -0.36, 0.6 } }, energy)
		end
		-- (the spear is in his hand: WeaponSpec.RAIJIN, OUTFITS.RAIJIN)
		o("LowerTorso", "Belt", Vector3.new(1.76, 0.22, 1.0), CFrame.new(0, 0.2, 0), color("Sash"))
		legs(ctx, { feet = "boots" })
	end,
}

-- YUKINA 雪: long silver hair down her back, a white and ice-blue kimono with long sleeves, a
-- wide obi, two crystal fans folded at her waist, and tabi.
BODIES.YUKINA = {
	colors = function(pc, color)
		pc.UpperTorso, pc.UpperArm, pc.LowerArm = color("Vest"), color("Vest"), color("Vest")
		pc.LowerLeg, pc.Foot = color("Pants"), color("Shoes")
	end,
	head = function(ctx)
		local o, hair = ctx.ornament, ctx.hair
		o("Head", "HairCap", Vector3.new(1.2, 0.36, 1.14), CFrame.new(0, 0.5, 0.06), hair)
		o("Head", "HairBack", Vector3.new(1.16, 0.8, 0.24), CFrame.new(0, 0.14, 0.47), hair)
		fringe(ctx, 5, 0.55, hair)
		for _, sign in { -1, 1 } do
			lockAt(ctx, "SideLock", sign * 0.58, 0.3, -0.18, 180 + 4, sign * -6, 1.5, 0.2, 0.3, hair, { segments = 3, curl = math.rad(-3) })
		end
		ctx.tail("Head", "LongHair", Vector3.new(1.0, 2.4, 0.16), CFrame.new(0, -0.5, 0.6), hair)
		local pin = o("Head", "HairPin", Vector3.new(0.3, 0.3, 0.1), CFrame.new(0.4, 0.5, -0.3) * CFrame.Angles(0, 0, 0.78), ctx.hairTip)
		pin.Material = Enum.Material.Glass
	end,
	body = function(ctx)
		local o, color, ink = ctx.ornament, ctx.color, ctx.ink
		for _, sign in { -1, 1 } do
			o("UpperTorso", "Lapel", Vector3.new(0.16, 1.3, 0.06), CFrame.new(sign * 0.2, 0.1, -0.52) * CFrame.Angles(0, 0, sign * 0.42), color("VestTrim"))
		end
		for _, side in { "Left", "Right" } do
			o(side .. "LowerArm", "Sleeve", Vector3.new(0.9, 1.1, 0.96), CFrame.new(0, -0.1, 0.1), color("Vest"))
			o(side .. "LowerArm", "SleeveEdge", Vector3.new(0.94, 0.08, 1.0), CFrame.new(0, -0.62, 0.1), color("VestTrim"))
		end
		o("LowerTorso", "Obi", Vector3.new(1.84, 0.5, 1.06), CFrame.new(0, 0.12, 0), color("Sash"))
		o("LowerTorso", "ObiCord", Vector3.new(1.86, 0.06, 1.08), CFrame.new(0, 0.12, 0), color("Wraps"))
		o("LowerTorso", "ObiBow", Vector3.new(1.0, 0.5, 0.3), CFrame.new(0, 0.16, 0.66), color("Sash"))
		-- (the fans are in her hands: WeaponSpec.YUKINA, OUTFITS.YUKINA)
		o("UpperTorso", "Hem", Vector3.new(1.96, 0.3, 1.04), CFrame.new(0, -0.66, 0), color("Vest"))
		legs(ctx, { wide = true, feet = "tabi" })
		o("UpperTorso", "Fold", Vector3.new(0.04, 0.5, 0.04), CFrame.new(0.3, -0.3, -0.51), ink)
	end,
}

-- VENOM 毒: messy purple hair, a respirator mask over the mouth glowing green, an asymmetric
-- black coat (one long tail), and green metal claws over the hands.
BODIES.VENOM = {
	colors = function(pc, color)
		pc.UpperTorso, pc.UpperArm, pc.LowerArm = color("Vest"), color("Vest"), color("Shirt")
	end,
	head = function(ctx)
		local o = ctx.ornament
		spikes(ctx, { { -0.5, 0.9, -0.9, 0.1, -10 }, { -0.25, 1.1, -0.5, -0.1, -30 }, { 0.05, 1.2, 0.3, 0.2, -40 },
			{ 0.3, 1.0, 0.8, 0, -20 }, { 0.5, 0.8, 1.1, 0.2, -10 }, { -0.1, 0.9, -0.2, 0.5, -80 } }, 3)
		o("Head", "Mask", Vector3.new(0.9, 0.38, 0.3), CFrame.new(0, -0.3, -0.48), ctx.color("Wraps"))
		-- the respirator: a snout under the nose, vent slats, a glowing seam, straps to the ears
		o("Head", "MaskSnout", Vector3.new(0.5, 0.2, 0.16), CFrame.new(0, -0.48, -0.66) * CFrame.Angles(math.rad(180), 0, 0),
			ctx.color("Wraps"), "WedgePart")
		for i = -1, 1 do
			o("Head", "Vent", Vector3.new(0.32, 0.03, 0.04), CFrame.new(0, -0.26 + i * 0.07, -0.64), ctx.ink)
		end
		o("Head", "MaskSeam", Vector3.new(0.04, 0.3, 0.04), CFrame.new(0, -0.32, -0.645), ctx.color("Energy")).Material = Enum.Material.Neon
		for _, sign in { -1, 1 } do
			local filter = ctx.shaped("Head", "Filter", Vector3.new(0.12, 0.28, 0.28), CFrame.new(sign * 0.36, -0.34, -0.62)
				* CFrame.Angles(0, math.rad(90), 0), ctx.color("Energy"), Enum.PartType.Cylinder)
			filter.Material = Enum.Material.Neon
			-- (a metal rim round each filter)
			material(ctx.shaped("Head", "FilterRim", Vector3.new(0.06, 0.34, 0.34), CFrame.new(sign * 0.36, -0.34, -0.56)
				* CFrame.Angles(0, math.rad(90), 0), ctx.ink, Enum.PartType.Cylinder), Enum.Material.Metal)
			o("Head", "MaskStrap", Vector3.new(0.05, 0.1, 0.5), CFrame.new(sign * 0.52, -0.24, -0.22) * CFrame.Angles(math.rad(-12), 0, 0), ctx.ink)
		end
	end,
	body = function(ctx)
		local o, color, ink = ctx.ornament, ctx.color, ctx.ink
		o("UpperTorso", "CoatFlap", Vector3.new(1.0, 1.6, 0.08), CFrame.new(-0.46, -0.1, -0.52) * CFrame.Angles(0, 0, 0.08), color("Vest"))
		o("UpperTorso", "CoatEdge", Vector3.new(0.06, 1.6, 0.1), CFrame.new(0.04, -0.1, -0.56) * CFrame.Angles(0, 0, 0.08), color("VestTrim"))
		ctx.tail("LowerTorso", "CoatTail", Vector3.new(0.8, 2.0, 0.06), CFrame.new(-0.45, 0.1, 0.54), color("Vest"))
		for _, side in { "Left", "Right" } do
			local claw = o(side .. "Hand", "ClawPlate", Vector3.new(0.8, 0.5, 0.82), CFrame.new(0, 0.1, 0), color("VestTrim"))
			claw.Material = Enum.Material.Metal
			for i = -1, 1 do
				o(side .. "Hand", "Claw", Vector3.new(0.08, 0.7, 0.1), CFrame.new(i * 0.24, -0.5, -0.32) * CFrame.Angles(math.rad(-20), 0, 0),
					color("Energy")).Material = Enum.Material.Neon
			end
		end
		o("LowerTorso", "Belt", Vector3.new(1.76, 0.2, 1.0), CFrame.new(0, 0.2, 0), ink)
		legs(ctx, { feet = "boots" })
	end,
}

-- GORAN 剛: the colossus. Tied black hair, a thick beard, bare scarred shoulders, a red and
-- black wrestler's singlet, wrist tape, knee pads and boots.
BODIES.GORAN = {
	colors = function(pc, color)
		pc.UpperTorso, pc.UpperArm, pc.LowerArm, pc.Hand = color("Vest"), color("SkinTone"), color("SkinTone"), color("Wraps")
	end,
	head = function(ctx)
		local o, hair = ctx.ornament, ctx.hair
		o("Head", "HairCap", Vector3.new(1.22, 0.34, 1.14), CFrame.new(0, 0.52, 0.06), hair)
		o("Head", "TopKnot", Vector3.new(0.4, 0.5, 0.4), CFrame.new(0, 0.86, 0.3), hair)
		o("Head", "KnotTie", Vector3.new(0.44, 0.1, 0.44), CFrame.new(0, 0.7, 0.3), ctx.color("VestTrim"))
		o("Head", "Beard", Vector3.new(1.0, 0.6, 0.5), CFrame.new(0, -0.52, -0.3), hair)
		o("Head", "BeardTip", Vector3.new(0.6, 0.4, 0.3), CFrame.new(0, -0.86, -0.36) * CFrame.Angles(math.rad(180), 0, 0), hair, "WedgePart")
	end,
	body = function(ctx)
		local o, color, ink = ctx.ornament, ctx.color, ctx.ink
		for _, sign in { -1, 1 } do
			o("UpperTorso", "Strap", Vector3.new(0.3, 0.5, 1.04), CFrame.new(sign * 0.45, 0.66, 0), color("Vest"))
			o("UpperTorso", "Trap", Vector3.new(0.5, 0.3, 0.7), CFrame.new(sign * 0.72, 0.78, 0.05) * CFrame.Angles(0, 0, sign * -0.3), ctx.skin)
			o("UpperTorso", "SideStripe", Vector3.new(0.08, 1.6, 1.06), CFrame.new(sign * 0.96, -0.1, 0), color("VestTrim"))
		end
		o("UpperTorso", "Neckline", Vector3.new(0.7, 0.36, 0.04), CFrame.new(0, 0.54, -0.505), ctx.skin)
		bareArms(ctx, color("Wraps"), color("Wraps"))
		for _, side in { "Left", "Right" } do
			o(side .. "UpperArm", "Scar", Vector3.new(0.5, 0.05, 0.04), CFrame.new(0, 0.3, -0.44) * CFrame.Angles(0, 0, 0.5), Color3.fromHex("8A5A44"))
			o(side .. "LowerLeg", "KneePad", Vector3.new(0.96, 0.4, 0.5), CFrame.new(0, 0.34, -0.3), color("VestTrim"))
		end
		o("LowerTorso", "Belt", Vector3.new(1.84, 0.34, 1.06), CFrame.new(0, 0.2, 0), color("VestTrim"))
		material(o("LowerTorso", "BeltPlate", Vector3.new(0.7, 0.5, 0.08), CFrame.new(0, 0.2, -0.56), Color3.fromHex("FFD23F")), Enum.Material.Metal)
		legs(ctx, { feet = "boots" })
	end,
}

-- ASTER 星: silver hair, a long black coat dotted with stars, and three metal rings floating
-- round each forearm.
BODIES.ASTER = {
	colors = function(pc, color)
		pc.UpperTorso, pc.UpperArm, pc.LowerArm = color("Vest"), color("Vest"), color("Vest")
	end,
	head = function(ctx)
		local o, hair = ctx.ornament, ctx.hair
		o("Head", "HairCap", Vector3.new(1.22, 0.4, 1.14), CFrame.new(0, 0.5, 0.06), hair)
		o("Head", "HairBack", Vector3.new(1.16, 0.6, 0.24), CFrame.new(0, 0.22, 0.47), hair)
		-- (untidy hair floating up a little: his gravity plays with it)
		fringe(ctx, 4, 0.65, hair, ctx.hairTip, 6)
		for _, c in { { -0.34, 0.1, -30, 0.85, 30 }, { -0.1, -0.04, -8, 1.0, 20 }, { 0.16, 0.06, 14, 0.95, 32 }, { 0.38, 0.0, 36, 0.8, 24 },
			{ 0.0, 0.3, 0, 0.9, 64 } } do
			spikeAt(ctx, "HairSpike", c[1], 0.5, c[2], c[5], c[3], c[4], 0.46, hair)
		end
		ctx.tail("Head", "BackHair", Vector3.new(0.9, 1.0, 0.14), CFrame.new(0, -0.2, 0.6), hair)
	end,
	body = function(ctx)
		local o, color = ctx.ornament, ctx.color
		local energy = color("Energy")
		o("UpperTorso", "CoatCollar", Vector3.new(1.4, 0.5, 1.1), CFrame.new(0, 0.84, 0.05), color("Vest"))
		o("UpperTorso", "CoatEdge", Vector3.new(0.06, 1.6, 0.06), CFrame.new(0, -0.1, -0.53), color("VestTrim"))
		-- Stars scattered on the coat.
		for i, p in { { -0.5, 0.4 }, { 0.4, 0.1 }, { -0.2, -0.4 }, { 0.6, -0.5 }, { -0.7, -0.2 } } do
			o("UpperTorso", "Star" .. i, Vector3.new(0.1, 0.1, 0.04), CFrame.new(p[1], p[2], -0.52) * CFrame.Angles(0, 0, 0.78), energy).Material = Enum.Material.Neon
		end
		ctx.tail("LowerTorso", "CoatTail", Vector3.new(1.6, 2.0, 0.06), CFrame.new(0, 0.1, 0.54), color("Vest"))
		for _, side in { "Left", "Right" } do
			for i, y in { 0.3, 0, -0.3 } do
				local ring = ctx.shaped(side .. "LowerArm", "Ring" .. i, Vector3.new(0.08, 1.2 - i * 0.1, 1.2 - i * 0.1), CFrame.new(0, y, 0)
					* CFrame.Angles(0, 0, math.pi / 2), color("Wraps"), Enum.PartType.Cylinder)
				ring.Material, ring.Transparency = Enum.Material.Metal, 0.1
			end
		end
		o("LowerTorso", "Belt", Vector3.new(1.76, 0.2, 1.0), CFrame.new(0, 0.2, 0), color("Sash"))
		legs(ctx, { feet = "boots" })
	end,
}

-- HIBIKI 響: short pink hair, big futuristic headphones, a white and black cropped jacket,
-- gloves with sound amplifiers, sneakers.
BODIES.HIBIKI = {
	colors = function(pc, color)
		pc.UpperTorso, pc.UpperArm, pc.LowerArm = color("Vest"), color("Vest"), color("SkinTone")
	end,
	head = function(ctx)
		local o, hair = ctx.ornament, ctx.hair
		o("Head", "HairCap", Vector3.new(1.24, 0.44, 1.16), CFrame.new(0, 0.5, 0.06), hair)
		o("Head", "HairBack", Vector3.new(1.2, 0.72, 0.26), CFrame.new(0, 0.12, 0.48), hair)
		-- A bob: a straight-cut fringe (pink tip), locks falling to the jaw all around.
		fringe(ctx, 5, 0.5, hair, ctx.hairTip, -4)
		for _, l in { { -0.6, -0.1, -4 }, { 0.6, -0.1, 4 }, { -0.36, 0.48, -14 }, { 0, 0.5, 0 }, { 0.36, 0.48, 14 } } do
			lockAt(ctx, "Bob", l[1], 0.36, l[2], 180 - (if l[2] > 0 then 18 else 0), l[3], 0.95, 0.34, 0.34, hair,
				{ segments = 2, curl = math.rad(if l[2] > 0 then 10 else -6), tip = ctx.hairTip })
		end
		for _, sign in { -1, 1 } do
			local cup = ctx.shaped("Head", "EarCup", Vector3.new(0.3, 0.7, 0.7), CFrame.new(sign * 0.68, 0, 0.04) * CFrame.Angles(0, 0, 0),
				ctx.color("Shirt"), Enum.PartType.Cylinder)
			cup.Material = Enum.Material.SmoothPlastic
			o("Head", "CupLight", Vector3.new(0.04, 0.4, 0.4), CFrame.new(sign * 0.84, 0, 0.04), ctx.color("Energy")).Material = Enum.Material.Neon
			-- (a ring round the light, and the arm down to the mic on the right)
			ctx.shaped("Head", "CupRing", Vector3.new(0.05, 0.56, 0.56), CFrame.new(sign * 0.83, 0, 0.04), ctx.ink, Enum.PartType.Cylinder)
			if sign > 0 then
				o("Head", "MicArm", Vector3.new(0.05, 0.05, 0.5), CFrame.new(0.66, -0.3, -0.3) * CFrame.Angles(0, math.rad(-30), 0), ctx.ink)
				ctx.shaped("Head", "Mic", Vector3.one * 0.11, CFrame.new(0.5, -0.32, -0.54), ctx.color("Energy"), Enum.PartType.Ball).Material = Enum.Material.Neon
			end
		end
		o("Head", "HeadbandArc", Vector3.new(1.4, 0.14, 0.24), CFrame.new(0, 0.74, 0.04), ctx.color("Shirt"))
	end,
	body = function(ctx)
		local o, color, ink = ctx.ornament, ctx.color, ctx.ink
		o("UpperTorso", "Crop", Vector3.new(1.98, 0.3, 1.06), CFrame.new(0, -0.6, 0), color("Shirt"))
		o("UpperTorso", "Zip", Vector3.new(0.06, 1.3, 0.06), CFrame.new(0, 0, -0.53), color("Sash"))
		for _, side in { "Left", "Right" } do
			o(side .. "Hand", "Glove", Vector3.new(0.78, 0.66, 0.8), CFrame.new(0, 0, 0), color("Shirt"))
			ctx.shaped(side .. "Hand", "Amplifier", Vector3.new(0.2, 0.5, 0.5), CFrame.new(0, 0.06, 0.2), color("Energy"), Enum.PartType.Cylinder).Material = Enum.Material.Neon
		end
		o("LowerTorso", "Belt", Vector3.new(1.76, 0.2, 1.0), CFrame.new(0, 0.2, 0), color("Sash"))
		legs(ctx, { feet = "sneakers" })
		o("UpperTorso", "Logo", Vector3.new(0.4, 0.3, 0.04), CFrame.new(0.4, 0.3, -0.51), ink)
	end,
}

-- KUROEN 蝕: very muscular, dark skin; a big white mane with red streaks swept back; a torn
-- sleeveless black jacket open on the chest, wide white trousers, black and red gauntlets.
-- A few readable shapes (the mane, the white trousers, the red gauntlets): he stays himself
-- in the middle of the effects. (His red and black aura is the client's, EffectsController.)
BODIES.KUROEN = {
	colors = function(pc, color)
		pc.UpperTorso, pc.UpperArm, pc.LowerArm, pc.Hand = color("SkinTone"), color("SkinTone"), color("Wraps"), color("Wraps")
		pc.UpperLeg, pc.LowerLeg = color("Pants"), color("Pants")
	end,
	head = function(ctx)
		local o, hair, tip = ctx.ornament, ctx.hair, ctx.hairTip
		o("Head", "HairCap", Vector3.new(1.3, 0.46, 1.2), CFrame.new(0, 0.5, 0.1), hair)
		o("Head", "HairBack", Vector3.new(1.26, 0.9, 0.3), CFrame.new(0, 0.1, 0.5), hair)
		-- A wild mane: swept-back points over the crown, heavy points falling down the back
		-- and over the shoulders, one red streak.
		for _, m in { { -0.4, 0.02, -24, 1.15, 52 }, { -0.16, -0.08, -8, 1.4, 44 }, { 0.12, -0.06, 8, 1.4, 46, true },
			{ 0.38, 0.04, 24, 1.15, 54 }, { 0, 0.3, 0, 1.3, 78 } } do
			spikeAt(ctx, "Mane", m[1], 0.5, m[2], m[5], m[3], m[4], 0.56, hair, if m[6] then tip else nil)
		end
		for _, m in { { -0.5, -34, 1.2 }, { -0.2, -12, 1.45 }, { 0.16, 12, 1.4 }, { 0.48, 32, 1.2 } } do
			spikeAt(ctx, "BackMane", m[1], 0.3, 0.46, 180 - 30, m[2], m[3], 0.5, hair)
		end
		for _, sign in { -1, 1 } do
			spikeAt(ctx, "SideMane", sign * 0.62, 0.22, 0.2, 180 - 12, sign * -18, 1.0, 0.36, hair)
		end
		fringe(ctx, 3, 0.5, hair)
	end,
	body = function(ctx)
		local o, color, ink = ctx.ornament, ctx.color, ctx.ink
		local skin, red = color("SkinTone"), color("VestTrim")
		-- muscle: pecs and abs on the bare chest
		for _, sign in { -1, 1 } do
			o("UpperTorso", "Pec", Vector3.new(0.8, 0.5, 0.12), CFrame.new(sign * 0.4, 0.3, -0.52), skin)
			o("UpperTorso", "Trap", Vector3.new(0.46, 0.3, 0.8), CFrame.new(sign * 0.5, 0.78, 0.05) * CFrame.Angles(0, 0, sign * -0.4), skin, "WedgePart")
		end
		for row = 0, 2 do
			o("UpperTorso", "AbLine" .. row, Vector3.new(0.5, 0.04, 0.04), CFrame.new(0, -0.15 - row * 0.2, -0.53), ink)
		end
		-- the torn sleeveless jacket, open on the chest (its two panels and a ragged hem)
		for _, sign in { -1, 1 } do
			o("UpperTorso", "JacketPanel", Vector3.new(0.5, 1.42, 1.06), CFrame.new(sign * 0.72, 0, 0.01), color("Vest"))
			o("UpperTorso", "JacketEdge", Vector3.new(0.05, 1.42, 0.05), CFrame.new(sign * 0.48, 0, -0.53), red)
			o("UpperTorso", "Tear", Vector3.new(0.3, 0.22, 0.06), CFrame.new(sign * 0.7, -0.66, -0.52) * CFrame.Angles(0, 0, sign * 0.5), color("Vest"), "WedgePart")
		end
		o("UpperTorso", "JacketBack", Vector3.new(1.94, 1.42, 0.08), CFrame.new(0, 0, 0.52), color("Vest"))
		ctx.tail("UpperTorso", "Coattail", Vector3.new(1.6, 1.0, 0.06), CFrame.new(0, -1.0, 0.54), color("Vest"))
		bareArms(ctx, nil, nil)
		-- gauntlets: black plates, red knuckles and a red stripe
		for _, side in { "Left", "Right" } do
			material(o(side .. "LowerArm", "Gauntlet", Vector3.new(0.82, 0.8, 0.86), CFrame.new(0, -0.05, 0), color("Wraps")), Enum.Material.Metal)
			o(side .. "LowerArm", "GauntletStripe", Vector3.new(0.86, 0.1, 0.9), CFrame.new(0, 0.2, 0), red).Material = Enum.Material.Neon
			o(side .. "Hand", "Knuckles", Vector3.new(0.82, 0.18, 0.24), CFrame.new(0, -0.1, -0.34), red).Material = Enum.Material.Metal
		end
		o("LowerTorso", "Sash", Vector3.new(1.8, 0.34, 1.02), CFrame.new(0, 0.18, 0), red)
		ctx.tail("LowerTorso", "SashTail", Vector3.new(0.28, 1.3, 0.06), CFrame.new(0.5, 0.1, -0.54) * CFrame.Angles(0, 0, 0.12), red)
		legs(ctx, { wide = true, feet = "bare" })
	end,
}

-- KAZAN 鎖: the predator. Short grey hair, amber eyes, a black combat suit with a high collar,
-- steel shoulder plates, the padlock of the jailer on the chest, and on each hand a steel
-- gauntlet with three long claws (WeaponSpec.KAZAN: built with the weapons, so they follow
-- the hands and are measured by the animation tests).
BODIES.KAZAN = {
	colors = function(pc, color)
		pc.UpperTorso, pc.UpperArm, pc.LowerArm = color("Vest"), color("Vest"), color("Vest")
	end,
	head = function(ctx)
		spikes(ctx, { { -0.4, 0.6, -0.4, 0.1, -30 }, { -0.15, 0.7, -0.15, 0.15, -40 }, { 0.12, 0.7, 0.15, 0.15, -40 },
			{ 0.4, 0.6, 0.4, 0.1, -30 } }, nil)
		ctx.ornament("Head", "Collar", Vector3.new(1.16, 0.4, 1.08), CFrame.new(0, -0.44, 0.02), ctx.color("Vest"))
		-- a predator's look: a steel half-mask over the mouth
		material(ctx.ornament("Head", "JawGuard", Vector3.new(1.04, 0.36, 0.14), CFrame.new(0, -0.26, -0.55), ctx.color("Wraps")), Enum.Material.Metal)
		-- its teeth (dark grooves, the middle ones longer), rivets and the cheek plates
		for i = -2, 2 do
			ctx.ornament("Head", "GuardTooth", Vector3.new(0.04, if math.abs(i) <= 1 then 0.26 else 0.18, 0.03),
				CFrame.new(i * 0.16, -0.3 + (if math.abs(i) <= 1 then 0 else 0.04), -0.625), ctx.ink)
		end
		for _, sign in { -1, 1 } do
			material(ctx.shaped("Head", "Rivet", Vector3.one * 0.09, CFrame.new(sign * 0.44, -0.18, -0.63), ctx.color("Energy"), Enum.PartType.Ball),
				Enum.Material.Metal)
			material(ctx.ornament("Head", "CheekPlate", Vector3.new(0.1, 0.3, 0.42), CFrame.new(sign * 0.55, -0.24, -0.3), ctx.color("Wraps")),
				Enum.Material.Metal)
		end
	end,
	body = function(ctx)
		local o, color, ink = ctx.ornament, ctx.color, ctx.ink
		local metal = color("Wraps")
		for _, sign in { -1, 1 } do
			o("UpperTorso", "Seam", Vector3.new(0.04, 1.4, 0.04), CFrame.new(sign * 0.4, -0.1, -0.51), ink)
			o("UpperTorso", "ShoulderPlate", Vector3.new(0.6, 0.2, 1.1), CFrame.new(sign * 0.74, 0.7, 0), metal).Material = Enum.Material.Metal
		end
		material(o("UpperTorso", "Padlock", Vector3.new(0.34, 0.36, 0.12), CFrame.new(0, 0.1, -0.58), color("Energy")), Enum.Material.Metal)
		for _, side in { "Left", "Right" } do
			-- the claws' gauntlets: steel vambraces and knuckle plates (the blades are the weapon)
			material(o(side .. "LowerArm", "Vambrace", Vector3.new(0.84, 0.86, 0.88), CFrame.new(0, -0.04, 0), metal), Enum.Material.Metal)
			o(side .. "LowerArm", "VambraceRim", Vector3.new(0.88, 0.08, 0.92), CFrame.new(0, 0.38, 0), color("Energy"))
			material(o(side .. "Hand", "KnucklePlate", Vector3.new(0.84, 0.3, 0.3), CFrame.new(0, -0.08, -0.3), metal), Enum.Material.Metal)
		end
		o("LowerTorso", "Belt", Vector3.new(1.76, 0.26, 1.0), CFrame.new(0, 0.2, 0), ink)
		legs(ctx, { feet = "boots" })
	end,
}

-- KUREN 血: dark red hair over one eye, pale skin, a long burgundy coat with gold buttons,
-- scarlet marks glowing on both forearms.
BODIES.KUREN = {
	colors = function(pc, color)
		pc.UpperTorso, pc.UpperArm, pc.LowerArm = color("Vest"), color("Vest"), color("SkinTone")
	end,
	head = function(ctx)
		local o, hair = ctx.ornament, ctx.hair
		o("Head", "HairCap", Vector3.new(1.22, 0.4, 1.14), CFrame.new(0, 0.5, 0.06), hair)
		o("Head", "HairBack", Vector3.new(1.16, 0.7, 0.24), CFrame.new(0, 0.16, 0.47), hair)
		-- A long bang swept over one eye, layered locks behind.
		lockAt(ctx, "SweptBang", -0.1, 0.52, -0.5, 180 + 6, -30, 1.0, 0.42, 0.16, hair, { segments = 3, curl = math.rad(4) })
		lockAt(ctx, "SweptBang", 0.18, 0.52, -0.5, 180 + 8, -22, 0.85, 0.32, 0.14, ctx.hairTip, { segments = 2 })
		for _, l in { { -0.4, -20 }, { 0, 0 }, { 0.4, 20 } } do
			lockAt(ctx, "BackLock", l[1], 0.42, 0.42, 180 - 22, l[2], 1.0, 0.36, 0.28, hair, { segments = 2, curl = math.rad(8) })
		end
		ctx.tail("Head", "BackHair", Vector3.new(0.9, 1.1, 0.14), CFrame.new(0, -0.2, 0.6), ctx.hairTip)
	end,
	body = function(ctx)
		local o, color = ctx.ornament, ctx.color
		local energy = color("Energy")
		o("UpperTorso", "Cravat", Vector3.new(0.4, 0.5, 0.06), CFrame.new(0, 0.4, -0.52), color("Shirt"))
		for i = 0, 3 do
			material(o("UpperTorso", "Button", Vector3.new(0.1, 0.1, 0.05), CFrame.new(0.3, 0.2 - i * 0.3, -0.53), color("VestTrim")), Enum.Material.Metal)
		end
		o("UpperTorso", "CoatCollar", Vector3.new(1.4, 0.5, 1.1), CFrame.new(0, 0.84, 0.05), color("Vest"))
		ctx.tail("LowerTorso", "CoatTail", Vector3.new(1.6, 2.2, 0.06), CFrame.new(0, 0.1, 0.54), color("Vest"))
		for _, sign in { -1, 1 } do
			ctx.tail("LowerTorso", "CoatFront", Vector3.new(0.7, 1.8, 0.06), CFrame.new(sign * 0.5, 0.08, -0.53), color("Vest"))
		end
		for _, side in { "Left", "Right" } do
			glowLines(ctx, side .. "LowerArm", { { 0.06, 0.6, 0, 0, -0.36, 0.3 }, { 0.3, 0.05, 0, 0.2, -0.36, 0 }, { 0.06, 0.4, 0.1, -0.2, -0.36, -0.4 } }, energy)
		end
		legs(ctx, { feet = "boots" })
	end,
}

-- SYLVA 森: braided green hair, a brown and emerald hunter's outfit with a leaf mantle, plant
-- gauntlets of bark and leaves, floral tattoos on the arms.
BODIES.SYLVA = {
	colors = function(pc, color)
		pc.UpperTorso, pc.UpperArm, pc.LowerArm, pc.Hand = color("Vest"), color("SkinTone"), color("Wraps"), color("Wraps")
	end,
	head = function(ctx)
		local o, hair = ctx.ornament, ctx.hair
		o("Head", "HairCap", Vector3.new(1.2, 0.38, 1.14), CFrame.new(0, 0.5, 0.06), hair)
		o("Head", "HairBack", Vector3.new(1.16, 0.7, 0.24), CFrame.new(0, 0.16, 0.47), hair)
		fringe(ctx, 4, 0.5, hair, nil, 8)
		for i = 0, 3 do -- the braid, bead after bead
			ctx.shaped("Head", "Braid", Vector3.new(0.34 - i * 0.04, 0.34 - i * 0.04, 0.34 - i * 0.04), CFrame.new(0.3, -0.3 - i * 0.3, 0.5), hair, Enum.PartType.Ball)
		end
		o("Head", "Leaf", Vector3.new(0.3, 0.06, 0.5), CFrame.new(-0.4, 0.6, -0.1) * CFrame.Angles(0, 0, 0.5), ctx.hairTip)
	end,
	body = function(ctx)
		local o, color = ctx.ornament, ctx.color
		local energy = color("Energy")
		for i = -3, 3 do -- leaf mantle over the shoulders
			o("UpperTorso", "MantleLeaf", Vector3.new(0.3, 0.06, 0.6), CFrame.new(i * 0.28, 0.8, 0.1) * CFrame.Angles(0.3, 0, i * 0.2), color("VestTrim"))
		end
		o("UpperTorso", "Strap", Vector3.new(0.14, 1.7, 0.06), CFrame.new(0, 0, -0.52) * CFrame.Angles(0, 0, 0.62), color("Sash"))
		for _, side in { "Left", "Right" } do
			o(side .. "LowerArm", "Bark", Vector3.new(0.8, 0.9, 0.8), CFrame.new(0, -0.1, 0), color("Wraps")).Material = Enum.Material.Wood
			o(side .. "Hand", "LeafGuard", Vector3.new(0.86, 0.1, 0.6), CFrame.new(0, 0.2, -0.1) * CFrame.Angles(0.3, 0, 0), color("VestTrim"))
			glowLines(ctx, side .. "UpperArm", { { 0.14, 0.14, 0, 0.1, -0.44, 0.78 }, { 0.04, 0.4, 0.05, -0.2, -0.44, 0.2 } }, energy)
		end
		o("LowerTorso", "Belt", Vector3.new(1.76, 0.22, 1.0), CFrame.new(0, 0.2, 0), color("Sash"))
		o("LowerTorso", "Pouch", Vector3.new(0.4, 0.4, 0.3), CFrame.new(0.7, 0, -0.4), color("Vest"))
		legs(ctx, { feet = "boots" })
	end,
}

-- ELIAN 癒: short blond hair, a white and gold coat with a cross of light on the chest,
-- glowing armbands on both arms.
BODIES.ELIAN = {
	colors = function(pc, color)
		pc.UpperTorso, pc.UpperArm, pc.LowerArm = color("Vest"), color("Vest"), color("Vest")
	end,
	head = function(ctx)
		local o, hair = ctx.ornament, ctx.hair
		o("Head", "HairCap", Vector3.new(1.22, 0.42, 1.14), CFrame.new(0, 0.5, 0.06), hair)
		o("Head", "HairBack", Vector3.new(1.16, 0.62, 0.24), CFrame.new(0, 0.2, 0.47), hair)
		-- Neat hair combed back from the brow in soft layered locks, two locks on the forehead.
		for _, l in { { -0.36, -0.36, -14, 0.95 }, { -0.12, -0.4, -4, 1.1 }, { 0.12, -0.4, 4, 1.1 }, { 0.36, -0.36, 14, 0.95 },
			{ -0.22, -0.1, -10, 1.0 }, { 0.22, -0.1, 10, 1.0 } } do
			lockAt(ctx, "SweptLock", l[1], 0.6, l[2], 72, l[3], l[4], 0.32, 0.26, hair, { segments = 3, curl = math.rad(10) })
		end
		lockAt(ctx, "Fringe", 0.18, 0.5, -0.52, 180 + 12, 18, 0.6, 0.18, 0.14, hair, { segments = 2 })
		lockAt(ctx, "Fringe", -0.26, 0.5, -0.52, 180 + 12, -14, 0.5, 0.16, 0.14, hair, { segments = 2 })
	end,
	body = function(ctx)
		local o, color = ctx.ornament, ctx.color
		local gold, energy = color("VestTrim"), color("Energy")
		o("UpperTorso", "CrossV", Vector3.new(0.14, 0.6, 0.04), CFrame.new(0, 0.1, -0.52), energy).Material = Enum.Material.Neon
		o("UpperTorso", "CrossH", Vector3.new(0.5, 0.14, 0.04), CFrame.new(0, 0.18, -0.52), energy).Material = Enum.Material.Neon
		for _, sign in { -1, 1 } do
			o("UpperTorso", "CoatEdge", Vector3.new(0.06, 1.6, 0.06), CFrame.new(sign * 0.5, -0.1, -0.53), gold)
			ctx.tail("LowerTorso", "CoatFront", Vector3.new(0.7, 1.8, 0.06), CFrame.new(sign * 0.5, 0.08, -0.53), color("Vest"))
		end
		ctx.tail("LowerTorso", "CoatTail", Vector3.new(1.6, 2.0, 0.06), CFrame.new(0, 0.1, 0.54), color("Vest"))
		for _, side in { "Left", "Right" } do
			o(side .. "UpperArm", "Armband", Vector3.new(0.9, 0.2, 0.9), CFrame.new(0, -0.2, 0), energy).Material = Enum.Material.Neon
			o(side .. "LowerArm", "Cuff", Vector3.new(0.74, 0.16, 0.74), CFrame.new(0, -0.4, 0), gold)
		end
		o("LowerTorso", "Belt", Vector3.new(1.76, 0.2, 1.0), CFrame.new(0, 0.2, 0), gold)
		legs(ctx, { feet = "boots" })
	end,
}

-- NOVA 機: short silver hair, orange tech goggles, an armoured black jacket, big mechanical
-- gauntlets, and two small drones hovering over her shoulders.
BODIES.NOVA = {
	colors = function(pc, color)
		pc.UpperTorso, pc.UpperArm, pc.LowerArm, pc.Hand = color("Vest"), color("Vest"), color("Wraps"), color("Wraps")
	end,
	head = function(ctx)
		local o, hair = ctx.ornament, ctx.hair
		o("Head", "HairCap", Vector3.new(1.22, 0.4, 1.14), CFrame.new(0, 0.5, 0.06), hair)
		o("Head", "HairBack", Vector3.new(1.16, 0.5, 0.24), CFrame.new(0, 0.26, 0.47), hair)
		-- Short spiky top over the goggles' strap, a side-swept lock.
		for _, c in { { -0.3, 0.06, -26, 0.75, 30 }, { -0.08, -0.06, -8, 0.9, 22 }, { 0.14, 0.04, 12, 0.85, 34 }, { 0.36, 0.1, 30, 0.7, 40 } } do
			spikeAt(ctx, "HairSpike", c[1], 0.52, c[2], c[5], c[3], c[4], 0.42, hair)
		end
		lockAt(ctx, "SideCut", -0.2, 0.52, -0.5, 180 + 8, -34, 0.7, 0.4, 0.14, hair, { segments = 2 })
		local goggles = o("Head", "Goggles", Vector3.new(1.0, 0.24, 0.1), CFrame.new(0, 0.42, -0.55), ctx.color("Energy"))
		goggles.Material, goggles.Transparency = Enum.Material.Glass, 0.1
		-- two round lenses in a metal frame, a bridge between them
		for _, sign in { -1, 1 } do
			material(ctx.shaped("Head", "GoggleRim", Vector3.new(0.06, 0.34, 0.34), CFrame.new(sign * 0.26, 0.42, -0.61)
				* CFrame.Angles(0, math.rad(90), 0), ctx.color("Wraps"), Enum.PartType.Cylinder), Enum.Material.Metal)
			local lens = ctx.shaped("Head", "GoggleLens", Vector3.new(0.04, 0.24, 0.24), CFrame.new(sign * 0.26, 0.42, -0.64)
				* CFrame.Angles(0, math.rad(90), 0), ctx.color("Energy"), Enum.PartType.Cylinder)
			lens.Material = Enum.Material.Neon
		end
		material(o("Head", "GoggleBridge", Vector3.new(0.14, 0.06, 0.06), CFrame.new(0, 0.44, -0.62), ctx.color("Wraps")), Enum.Material.Metal)
		o("Head", "GoggleStrap", Vector3.new(1.18, 0.12, 1.1), CFrame.new(0, 0.42, 0), ctx.ink)
	end,
	body = function(ctx)
		local o, color, ink = ctx.ornament, ctx.color, ctx.ink
		local energy, metal = color("Energy"), color("Wraps")
		for _, sign in { -1, 1 } do
			o("UpperTorso", "ArmorPlate", Vector3.new(0.6, 0.7, 0.08), CFrame.new(sign * 0.45, 0.2, -0.53), metal).Material = Enum.Material.Metal
			-- A drone over each shoulder: body, rotor ring, a glowing eye.
			local drone = o("UpperTorso", "Drone", Vector3.new(0.5, 0.3, 0.5), CFrame.new(sign * 1.4, 1.5, 0.3), metal)
			drone.Material = Enum.Material.Metal
			ctx.shaped("UpperTorso", "DroneRotor", Vector3.new(0.06, 0.9, 0.9), CFrame.new(sign * 1.4, 1.7, 0.3) * CFrame.Angles(0, 0, math.pi / 2), ink, Enum.PartType.Cylinder)
			o("UpperTorso", "DroneEye", Vector3.new(0.14, 0.1, 0.06), CFrame.new(sign * 1.4, 1.5, 0.04), energy).Material = Enum.Material.Neon
		end
		for _, side in { "Left", "Right" } do
			local g = o(side .. "Hand", "Gauntlet", Vector3.new(0.96, 0.84, 0.98), CFrame.new(0, -0.02, 0), metal)
			g.Material = Enum.Material.Metal
			o(side .. "Hand", "Core", Vector3.new(0.4, 0.2, 0.06), CFrame.new(0, 0, -0.52), energy).Material = Enum.Material.Neon
			o(side .. "LowerArm", "Piston", Vector3.new(0.86, 0.8, 0.86), CFrame.new(0, -0.1, 0), metal).Material = Enum.Material.Metal
		end
		o("LowerTorso", "Belt", Vector3.new(1.76, 0.24, 1.0), CFrame.new(0, 0.2, 0), color("Sash"))
		legs(ctx, { feet = "boots" })
	end,
}

RigBuilder.BODIES = BODIES

-- `data` (optional): the look to build (a CharacterData entry); default CharacterData[slot].
function RigBuilder.build(slot, parent, data)
	data = data or CharacterData[slot]
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
			ornament("Head", "SideLock", Vector3.new(0.14, 0.56, 0.52), CFrame.new(sign * 0.6, 0.18, -0.1), hair)
			lockAt({ ornament = ornament }, "SideSpike", sign * 0.6, 0.0, -0.14, 180, sign * -10, 0.62, 0.14, 0.36, hair,
				{ segments = 2, curl = math.rad(6) })
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
	-- Messy spiky black hair with red highlights: a cap that hugs the skull, a fringe of short
	-- locks over the brow, a crown of tall tapered spikes, locks falling at the nape.
	ornament("Head", "HairCap", Vector3.new(1.22, 0.4, 1.14), CFrame.new(0, 0.5, 0.04), hair)
	ornament("Head", "HairBack", Vector3.new(1.18, 0.78, 0.26), CFrame.new(0, 0.18, 0.46), hair)
	for i, x in { -0.4, -0.18, 0.04, 0.26, 0.44 } do
		spikeAt(ctx, "Fringe", x, 0.5, -0.5, 180 + 14, (i - 3) * 12, 0.55 + (i % 2) * 0.18, 0.26, hair, if i == 2 then hairTip else nil)
	end
	-- (x, z, outward lean, length, back tilt, red tip): a fan, the tallest in the middle-back
	local crown = {
		{ -0.44, 0.04, -44, 1.0, 22 }, { -0.28, -0.12, -24, 1.3, 14, true }, { -0.1, 0.06, -8, 1.55, 30 },
		{ 0.12, -0.08, 8, 1.6, 20 }, { 0.3, 0.06, 26, 1.3, 30, true }, { 0.44, 0.0, 44, 1.0, 20 },
		{ 0.0, 0.32, 0, 1.4, 62 }, { -0.3, 0.3, -22, 1.15, 66 }, { 0.3, 0.3, 22, 1.15, 66, true },
	}
	for _, c in crown do
		spikeAt(ctx, "HairSpike", c[1], 0.5, c[2], c[5], c[3], c[4], 0.5, hair, if c[6] then hairTip else nil)
	end
	for _, b in { { -0.34, -26 }, { 0, 0 }, { 0.34, 26 } } do
		spikeAt(ctx, "BackSpike", b[1], 0.3, 0.42, 180 - 40, b[2], 0.95, 0.42, hair)
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
	if data.Kit ~= "KAI" then RigBuilder.applyKit(model, slot, data.Kit == "TARO", true, data) end
	-- DETAILS (every fighter of the block model, after its outfit): fists with knuckles and a
	-- thumb, a toe cap on the shoes, kneecaps; the square silhouette is kept (Wilhem: no
	-- rounded shoulders). Each piece takes the colour the outfit gave its limb, so it reads as
	-- the same glove, trouser or shoe.
	local function tone(name) return parts[name].Color end
	for _, sign in { -1, 1 } do
		local side = if sign < 0 then "Left" else "Right"
		local hand, leg, foot = side .. "Hand", side .. "LowerLeg", side .. "Foot"
		ornament(hand, "Knuckles", Vector3.new(0.78, 0.18, 0.5), CFrame.new(0, -0.24, -0.18), tone(hand))
		ornament(hand, "Thumb", Vector3.new(0.16, 0.34, 0.3), CFrame.new(-sign * 0.38, -0.04, -0.2), tone(hand))
		ornament(foot, "ToeCap", Vector3.new(0.76, 0.3, 0.36), CFrame.new(0, -0.06, -0.72) * CFrame.Angles(0, math.pi, 0), tone(foot), "WedgePart")
		ornament(leg, "Kneecap", Vector3.new(0.5, 0.36, 0.12), CFrame.new(0, 0.42, -0.46), tone(leg))
	end
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
	-- the mask rides up the nose: a ridge in the middle, a fold under the eyes
	o.piece("Head", "MaskRidge", Vector3.new(head.X * 0.12, head.Y * 0.3, 0.06), CFrame.new(0, -head.Y * 0.2, -head.Z * 0.535), o.main)
	o.piece("Head", "MaskFold", Vector3.new(head.X * 1.05, 0.05, 0.05), CFrame.new(0, -head.Y * 0.04, -head.Z * 0.53), o.second)
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

-- ---------------------------------------------------------------- ASURA and the third sheet
-- On a player's own avatar: each kit's signature pieces (its block body, BODIES, draws its own).

-- A band round a part (bracelets, armbands, belts), `h` high at `y` (share of its height).
local function band(o, regionName, name, h, y, partColor, grow)
	local s = o.size(regionName)
	return o.piece(regionName, name, Vector3.new(s.X * (grow or 1.1), h, s.Z * (grow or 1.1)), CFrame.new(0, y * s.Y, 0), partColor)
end

function OUTFITS.ASURA(o)
	if o.block then return end -- (the block body draws all of it)
	local gold = o.main
	for _, side in SIDES do
		band(o, side[1] .. "UpperArm", "Armlet", 0.18, -0.1, gold).Material = Enum.Material.Metal
		band(o, side[1] .. "LowerArm", "Bangle", 0.22, -0.3, gold).Material = Enum.Material.Metal
	end
	local head = o.size("Head")
	o.piece("Head", "Diadem", Vector3.new(head.X * 1.06, head.Y * 0.12, head.Z * 1.06), CFrame.new(0, head.Y * 0.3, 0), gold).Material = Enum.Material.Metal
	o.piece("Head", "ThirdEye", Vector3.new(0.12, 0.24, 0.04), CFrame.new(0, head.Y * 0.2, -head.Z * 0.54), o.energy).Material = Enum.Material.Neon
	if not o.block then
		local waist = o.size("LowerTorso")
		o.piece("LowerTorso", "Sash", Vector3.new(waist.X * 1.08, math.max(0.3, waist.Y * 0.4), waist.Z * 1.12), CFrame.new(0, waist.Y * 0.15, 0), o.color("Shirt"))
	end
end

function OUTFITS.RAIJIN(o)
	o.weapon(WeaponSpec.RAIJIN)
	if o.block then return end -- (the block body draws the rest)
	for _, side in SIDES do
		local arm = o.size(side[1] .. "LowerArm")
		o.piece(side[1] .. "LowerArm", "Bolt", Vector3.new(0.06, arm.Y * 0.7, 0.04), CFrame.new(0, 0, -arm.Z * 0.56) * CFrame.Angles(0, 0, 0.4), o.energy).Material = Enum.Material.Neon
	end
	band(o, "LowerTorso", "Belt", 0.22, 0.2, o.main, 1.08)
end

function OUTFITS.YUKINA(o)
	o.weapon(WeaponSpec.YUKINA)
	if o.block then return end -- (the block body draws the rest)
	local waist = o.size("LowerTorso")
	o.piece("LowerTorso", "Obi", Vector3.new(waist.X * 1.1, math.max(0.4, waist.Y * 0.5), waist.Z * 1.14), CFrame.new(0, waist.Y * 0.1, 0), o.main)
	o.piece("LowerTorso", "ObiBow", Vector3.new(waist.X * 0.6, 0.5, 0.3), CFrame.new(0, waist.Y * 0.14, waist.Z * 0.66), o.main)
end

function OUTFITS.VENOM(o)
	if o.block then return end -- (the block body draws all of it)
	local head = o.size("Head")
	o.piece("Head", "Mask", Vector3.new(head.X * 0.8, head.Y * 0.36, 0.3), CFrame.new(0, -head.Y * 0.26, -head.Z * 0.46), o.second)
	for _, side in SIDES do
		local hand = o.size(side[1] .. "Hand")
		for i = -1, 1 do
			o.piece(side[1] .. "Hand", "Claw" .. i, Vector3.new(0.08, hand.Y * 0.9, 0.1), CFrame.new(i * hand.X * 0.3, -hand.Y * 0.5, -hand.Z * 0.4)
				* CFrame.Angles(math.rad(-20), 0, 0), o.energy).Material = Enum.Material.Neon
		end
	end
end

function OUTFITS.GORAN(o)
	if o.block then return end -- (the block body draws all of it)
	for _, side in SIDES do
		band(o, side[1] .. "LowerArm", "Tape", 0.3, -0.3, o.second)
		local leg = o.size(side[1] .. "LowerLeg")
		o.piece(side[1] .. "LowerLeg", "KneePad", Vector3.new(leg.X * 1.1, leg.Y * 0.3, leg.Z * 0.5), CFrame.new(0, leg.Y * 0.36, -leg.Z * 0.3), o.main)
	end
	local waist = o.size("LowerTorso")
	band(o, "LowerTorso", "Belt", 0.34, 0.2, o.main, 1.1)
	o.piece("LowerTorso", "BeltPlate", Vector3.new(waist.X * 0.4, 0.5, 0.08), CFrame.new(0, waist.Y * 0.2, -waist.Z * 0.6), Color3.fromHex("FFD23F")).Material = Enum.Material.Metal
end

function OUTFITS.ASTER(o)
	if o.block then return end -- (the block body draws all of it)
	for _, side in SIDES do
		for i, y in { 0.3, 0, -0.3 } do
			local arm = o.size(side[1] .. "LowerArm")
			local ring = o.piece(side[1] .. "LowerArm", "Ring" .. i, Vector3.new(0.08, arm.X * 1.8, arm.X * 1.8), CFrame.new(0, y * arm.Y, 0)
				* CFrame.Angles(0, 0, math.pi / 2), o.second, Enum.PartType.Cylinder)
			ring.Material = Enum.Material.Metal
		end
	end
	local chest = o.size("UpperTorso")
	o.piece("UpperTorso", "Star", Vector3.new(0.16, 0.16, 0.04), CFrame.new(-chest.X * 0.25, chest.Y * 0.2, -chest.Z * 0.54) * CFrame.Angles(0, 0, 0.78), o.energy).Material = Enum.Material.Neon
end

function OUTFITS.HIBIKI(o)
	if o.block then return end -- (the block body draws all of it)
	local head = o.size("Head")
	for _, side in SIDES do
		o.piece("Head", "EarCup", Vector3.new(0.3, head.Y * 0.7, head.Y * 0.7), CFrame.new(side[2] * head.X * 0.58, 0, 0), o.color("Shirt"), Enum.PartType.Cylinder)
		o.piece("Head", "CupLight", Vector3.new(0.04, head.Y * 0.4, head.Y * 0.4), CFrame.new(side[2] * (head.X * 0.58 + 0.16), 0, 0), o.energy).Material = Enum.Material.Neon
		local hand = o.size(side[1] .. "Hand")
		o.piece(side[1] .. "Hand", "Amplifier", Vector3.new(0.2, hand.Y * 0.6, hand.Y * 0.6), CFrame.new(0, 0, hand.Z * 0.3), o.energy, Enum.PartType.Cylinder).Material = Enum.Material.Neon
	end
	o.piece("Head", "HeadbandArc", Vector3.new(head.X * 1.2, 0.14, 0.24), CFrame.new(0, head.Y * 0.56, 0), o.color("Shirt"))
end

function OUTFITS.KUROEN(o)
	if o.block then return end -- (the block body draws all of it)
	for _, side in SIDES do
		local arm = o.size(side[1] .. "LowerArm")
		o.piece(side[1] .. "LowerArm", "Gauntlet", Vector3.new(arm.X * 1.12, arm.Y * 0.8, arm.Z * 1.12), CFrame.new(0, -arm.Y * 0.05, 0),
			Color3.fromHex("141016")).Material = Enum.Material.Metal
		o.piece(side[1] .. "LowerArm", "GauntletStripe", Vector3.new(arm.X * 1.16, 0.1, arm.Z * 1.16), CFrame.new(0, arm.Y * 0.2, 0), o.main).Material = Enum.Material.Neon
	end
	local waist = o.size("LowerTorso")
	o.piece("LowerTorso", "Sash", Vector3.new(waist.X * 1.08, math.max(0.3, waist.Y * 0.4), waist.Z * 1.12), CFrame.new(0, waist.Y * 0.15, 0), o.main)
end

-- KUROEN SHIN (boss) is KUROEN's body in his divine colours.
BODIES["KUROEN SHIN"] = BODIES.KUROEN
OUTFITS["KUROEN SHIN"] = OUTFITS.KUROEN

function OUTFITS.KAZAN(o)
	o.weapon(WeaponSpec.KAZAN) -- the two claws (block body and avatars alike)
	if o.block then return end -- (the block body draws the rest)
	local metal = o.second
	for _, side in SIDES do
		local arm = o.size(side[1] .. "LowerArm")
		o.piece(side[1] .. "LowerArm", "Vambrace", Vector3.new(arm.X * 1.14, arm.Y * 0.86, arm.Z * 1.14), CFrame.new(0, -arm.Y * 0.04, 0), metal).Material = Enum.Material.Metal
	end
	local chest = o.size("UpperTorso")
	o.piece("UpperTorso", "Padlock", Vector3.new(0.34, 0.36, 0.12), CFrame.new(0, chest.Y * 0.05, -chest.Z * 0.58), o.energy).Material = Enum.Material.Metal
end

function OUTFITS.KUREN(o)
	if o.block then return end -- (the block body draws all of it)
	for _, side in SIDES do
		local arm = o.size(side[1] .. "LowerArm")
		o.piece(side[1] .. "LowerArm", "Mark", Vector3.new(0.06, arm.Y * 0.6, 0.04), CFrame.new(0, 0, -arm.Z * 0.56) * CFrame.Angles(0, 0, 0.3), o.energy).Material = Enum.Material.Neon
		o.piece(side[1] .. "LowerArm", "MarkBar", Vector3.new(arm.X * 0.5, 0.05, 0.04), CFrame.new(0, arm.Y * 0.2, -arm.Z * 0.56), o.energy).Material = Enum.Material.Neon
	end
	if not o.block then
		local chest = o.size("UpperTorso")
		o.piece("UpperTorso", "Cravat", Vector3.new(0.4, 0.5, 0.06), CFrame.new(0, chest.Y * 0.3, -chest.Z * 0.54), o.color("Shirt"))
		o.tail("UpperTorso", "CoatTail", Vector3.new(chest.X * 0.8, 2.2, 0.06), CFrame.new(0, -chest.Y * 0.4, chest.Z * 0.56), o.color("Vest"))
	end
end

function OUTFITS.SYLVA(o)
	if o.block then return end -- (the block body draws all of it)
	for _, side in SIDES do
		local arm = o.size(side[1] .. "LowerArm")
		o.piece(side[1] .. "LowerArm", "Bark", Vector3.new(arm.X * 1.14, arm.Y * 0.8, arm.Z * 1.14), CFrame.new(0, -arm.Y * 0.05, 0), o.second).Material = Enum.Material.Wood
		local hand = o.size(side[1] .. "Hand")
		o.piece(side[1] .. "Hand", "LeafGuard", Vector3.new(hand.X * 1.1, 0.1, hand.Z * 0.8), CFrame.new(0, hand.Y * 0.3, 0) * CFrame.Angles(0.3, 0, 0), o.color("VestTrim"))
	end
	if not o.block then
		local chest = o.size("UpperTorso")
		for i = -2, 2 do
			o.piece("UpperTorso", "MantleLeaf" .. i, Vector3.new(0.3, 0.06, 0.6), CFrame.new(i * chest.X * 0.16, chest.Y * 0.5, 0) * CFrame.Angles(0.3, 0, i * 0.2), o.color("VestTrim"))
		end
	end
end

function OUTFITS.ELIAN(o)
	if o.block then return end -- (the block body draws all of it)
	for _, side in SIDES do
		band(o, side[1] .. "UpperArm", "Armband", 0.2, -0.2, o.energy).Material = Enum.Material.Neon
		band(o, side[1] .. "LowerArm", "Cuff", 0.16, -0.4, o.color("VestTrim"))
	end
	local chest = o.size("UpperTorso")
	o.piece("UpperTorso", "CrossV", Vector3.new(0.14, 0.6, 0.04), CFrame.new(0, chest.Y * 0.05, -chest.Z * 0.54), o.energy).Material = Enum.Material.Neon
	o.piece("UpperTorso", "CrossH", Vector3.new(0.5, 0.14, 0.04), CFrame.new(0, chest.Y * 0.12, -chest.Z * 0.54), o.energy).Material = Enum.Material.Neon
end

function OUTFITS.NOVA(o)
	if o.block then return end -- (the block body draws all of it)
	local metal = o.second
	for _, side in SIDES do
		local hand = o.size(side[1] .. "Hand")
		local w = math.max(hand.X, hand.Z)
		o.piece(side[1] .. "Hand", "Gauntlet", Vector3.new(w * 1.3, hand.Y * 1.1, w * 1.32), CFrame.new(0, 0, 0), metal).Material = Enum.Material.Metal
		o.piece(side[1] .. "Hand", "Core", Vector3.new(w * 0.5, 0.2, 0.06), CFrame.new(0, 0, -w * 0.68), o.energy).Material = Enum.Material.Neon
	end
	local chest = o.size("UpperTorso")
	for _, side in SIDES do
		local drone = o.piece("UpperTorso", "Drone", Vector3.new(0.5, 0.3, 0.5), CFrame.new(side[2] * (chest.X * 0.5 + 0.9), chest.Y * 0.5 + 0.9, 0.3), metal)
		drone.Material = Enum.Material.Metal
		o.piece("UpperTorso", "DroneEye", Vector3.new(0.14, 0.1, 0.06), CFrame.new(side[2] * (chest.X * 0.5 + 0.9), chest.Y * 0.5 + 0.9, 0.04), o.energy).Material = Enum.Material.Neon
	end
	local head = o.size("Head")
	local goggles = o.piece("Head", "Goggles", Vector3.new(head.X * 0.9, head.Y * 0.22, 0.1), CFrame.new(0, head.Y * 0.3, -head.Z * 0.54), o.energy)
	goggles.Material, goggles.Transparency = Enum.Material.Glass, 0.1
end

--[[
	The kit's outfit worn over a body (a Roblox R15 or R6 avatar, or the block model of a kit
	other than KAI): every piece is sized from the body's own parts so it fits any avatar, and
	the kit's kanji goes on the back unless `noEmblem` (the block model draws its own).
]]
function RigBuilder.applyKit(model, slot, noEmblem, block, data)
	data = data or CharacterData[slot]
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
	-- A held weapon (WeaponSpec): its pieces placed at the grip, in the hand (and its pair in
	-- the other hand).
	function o.weapon(spec)
		if spec.pair then o.weapon(spec.pair) end
		local hand = o.size(spec.hand)
		local g = if model:FindFirstChild(spec.hand) then spec.grip else spec.r6Grip or spec.grip
		local grip = CFrame.new(0, hand.Y * g.y, g.z) * CFrame.Angles(math.rad(g.tilt), 0, 0)
		for _, piece in spec.pieces do
			local partColor = if piece.color == "energy" then o.energy elseif piece.color == "trim" then color("VestTrim")
				else Color3.fromHex(piece.color)
			local p = o.piece(spec.hand, piece.name, Vector3.new(piece.size[1], piece.size[2], piece.size[3]),
				grip * CFrame.new(piece.x or 0, piece.y or 0, piece.z or 0), partColor, piece.shape and Enum.PartType[piece.shape])
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
	if data.Kit == "ASURA" then RigBuilder.addFourArms(model, data) end
end

-- ASURA's second pair of arms, out of his flanks under the first: on each side an upper arm (a
-- gold armlet), a forearm (wraps and a gold bangle) and a wrapped fist, on two joints: the
-- shoulder (Motor6D AsuraLeft / AsuraRight, on the torso) and the elbow (AsuraLeftElbow /
-- AsuraRightElbow). Their geometry comes from FourArms.SPEC, scaled to the torso; the client
-- poses them every frame with FourArms.pose (AnimationController).
function RigBuilder.addFourArms(model, data)
	local torso = model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")
	if not torso or model:FindFirstChild("AsuraArmLeft") then return end
	local spec = FourArms.SPEC
	local skin, wraps = Color3.fromHex(data.SkinTone or "8A5A44"), Color3.fromHex(data.Wraps or "C8A040")
	local gold = Color3.fromHex(data.Sash or "FFD23F")
	local scale = torso.Size.X / 2
	local upperLength, foreLength = spec.upper * scale, spec.fore * scale
	local function piece(name, size, color, material, shape)
		local p = Instance.new("Part")
		p.Name, p.Size, p.Color = name, size, color
		p.Material = material or Enum.Material.SmoothPlastic
		p.CanCollide, p.CanTouch, p.CanQuery, p.Massless, p.CastShadow = false, false, false, true, true
		if shape then p.Shape = shape end
		return p
	end
	local function weld(part0, part1, offset)
		local w = Instance.new("Weld")
		w.Part0, w.Part1, w.C0 = part0, part1, offset
		w.Parent = part1
		part1.CFrame = part0.CFrame * offset
		part1.Parent = model
	end
	-- (built straight into their guard; the client takes over once it runs)
	local guard = FourArms.pose({ state = "Idle" }, 0, nil)
	for _, side in { -1, 1 } do
		local name = if side < 0 then "Left" else "Right"
		local pitch, yaw, roll, bend, twist = FourArms.angles(side, guard[name])
		local w = 0.62 * scale -- (as thick as his first arms: massive)
		local upper = piece("AsuraArm" .. name, Vector3.new(w, upperLength, w), skin)
		local fore = piece("AsuraForearm" .. name, Vector3.new(w * 0.92, foreLength, w * 0.92), skin)
		local shoulder = Instance.new("Motor6D")
		shoulder.Name, shoulder.Part0, shoulder.Part1 = "Asura" .. name, torso, upper
		shoulder.C0 = CFrame.new(side * spec.shoulder.x * scale, spec.shoulder.y * scale, spec.shoulder.z * scale)
			* CFrame.Angles(0, math.rad(yaw), 0) * CFrame.Angles(math.rad(pitch), 0, 0) * CFrame.Angles(0, 0, math.rad(roll))
			* CFrame.Angles(0, math.rad(twist), 0)
		shoulder.C1 = CFrame.new(0, upperLength / 2, 0)
		upper.CFrame = torso.CFrame * shoulder.C0 * shoulder.C1:Inverse()
		shoulder.Parent = torso
		upper.Parent = model
		local elbow = Instance.new("Motor6D")
		elbow.Name, elbow.Part0, elbow.Part1 = "Asura" .. name .. "Elbow", upper, fore
		elbow.C0 = CFrame.new(0, -upperLength / 2, 0) * CFrame.Angles(math.rad(bend), 0, 0)
		elbow.C1 = CFrame.new(0, foreLength / 2, 0)
		fore.CFrame = upper.CFrame * elbow.C0 * elbow.C1:Inverse()
		elbow.Parent = upper
		fore.Parent = model
		-- The joints read as joints: a ball at the shoulder and at the elbow.
		weld(upper, piece("AsuraShoulderBall" .. name, Vector3.one * w * 1.25, skin, nil, Enum.PartType.Ball), CFrame.new(0, upperLength / 2, 0))
		weld(upper, piece("AsuraElbowBall" .. name, Vector3.one * w * 1.05, skin, nil, Enum.PartType.Ball), CFrame.new(0, -upperLength / 2, 0))
		weld(upper, piece("AsuraArmlet" .. name, Vector3.new(w * 1.2, 0.16 * scale, w * 1.2), gold, Enum.Material.Metal), CFrame.new(0, upperLength * 0.12, 0))
		for i, y in { 0.2, 0, -0.2 } do
			weld(fore, piece("AsuraWrap" .. name .. i, Vector3.new(w * 1.02, 0.08 * scale, w * 1.02), wraps, Enum.Material.Fabric),
				CFrame.new(0, y * foreLength, 0) * CFrame.Angles(0, 0, (if i % 2 == 0 then 1 else -1) * 0.18))
		end
		weld(fore, piece("AsuraBangle" .. name, Vector3.new(w * 1.14, 0.18 * scale, w * 1.14), gold, Enum.Material.Metal), CFrame.new(0, -foreLength * 0.36, 0))
		weld(fore, piece("AsuraFist" .. name, Vector3.one * 0.76 * scale, wraps, Enum.Material.Fabric), CFrame.new(0, -foreLength / 2 - 0.3 * scale, 0))
		weld(fore, piece("AsuraKnuckles" .. name, Vector3.new(0.8, 0.18, 0.2) * scale, gold, Enum.Material.Metal), CFrame.new(0, -foreLength / 2 - 0.4 * scale, -0.3 * scale))
	end
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
	if #ids == 0 then return nil, "Studio test player (no Roblox account)" end
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
local function fromDescription(slot, description, label, rigType, data)
	rigType = if rigType == "R6" then "R6" else "R15"
	local built, model = pcall(Players.CreateHumanoidModelFromDescription, Players, description, Enum.HumanoidRigType[rigType])
	if not built or not model then
		return nil, "body creation " .. rigType .. " failed: " .. tostring(model)
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
		return nil, "body without HumanoidRootPart"
	end
	-- Joints the animation can drive (Motor6D), whatever Roblox built (see RigReader).
	local rebuilt = RigReader.ensureJoints(model)
	if rebuilt > 0 then
		model:SetAttribute("JointsRebuilt", rebuilt)
		print(string.format("[FightingGame] Avatar %s: %d joints rebuilt as Motor6D", rigType, rebuilt))
	end
	local complete, missing = hasJoints(model, rigType)
	if not complete then
		model:Destroy()
		return nil, "joint " .. tostring(missing) .. " missing"
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
		if not scaled then warn("[FightingGame] Avatar scaling failed: " .. tostring(problem)) end
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
	RigBuilder.applyKit(model, slot, nil, nil, data)
	return model, nil
end

-- A plain body in the kit's colours (no asset id): used when the avatar cannot load.
local function defaultDescription(slot, data)
	data = data or CharacterData[slot]
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
	  avatar unavailable           -> default body + kit, "DEFAULT|<reason>"
	  avatar body cannot be built  -> retried without its accessories, then the default body
	Returns nil only if even the default body fails (the server then uses the block model).
]]
function RigBuilder.buildAvatar(slot, player, rigType, data)
	local description, reason = describe(player)
	if description then
		local model, problem = fromDescription(slot, description, "AVATAR", rigType, data)
		if model then return model, "OK" end
		reason = problem
		-- Some accessories / layered clothing can fail to build: keep the body and colours.
		local plain = defaultDescription(slot, data)
		for _, field in { "HeadColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor", "TorsoColor",
			"Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg", "Face",
			"HeightScale", "WidthScale", "DepthScale", "HeadScale", "BodyTypeScale", "ProportionScale" } do
			pcall(function() plain[field] = description[field] end)
		end
		model = fromDescription(slot, plain, "AVATAR", rigType, data)
		if model then return model, "NO ACCESSORIES|" .. tostring(reason) end
	end
	warn("[FightingGame] Avatar unavailable for " .. player.Name .. ": " .. tostring(reason))
	local model, problem = fromDescription(slot, defaultDescription(slot, data), "DEFAULT", rigType, data)
	if model then return model, "DEFAULT|" .. tostring(reason) end
	return nil, "MODEL|" .. tostring(problem)
end

-- The CPU / training dummy: a shadow clone of the opponent's avatar (dark body, glowing
-- outline), with the same rig type. Without a loadable avatar (Studio test players), a
-- default Roblox body in the slot's colours. No asset id is involved: only colours change.
function RigBuilder.buildShadow(slot, player, rigType, data)
	local description = if player then describe(player) else nil
	local shadow = description ~= nil
	data = data or CharacterData[slot]
	if shadow then
		local body = Color3.fromHex("1A1424")
		description.HeadColor, description.LeftArmColor, description.RightArmColor = body, body, body
		description.LeftLegColor, description.RightLegColor, description.TorsoColor = body, body, body
	else
		description = defaultDescription(slot, data)
	end
	local model = fromDescription(slot, description, if shadow then "SHADOW" else "DEFAULT", rigType, data)
	if not model and shadow then model = fromDescription(slot, defaultDescription(slot, data), "DEFAULT", rigType, data) end
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
