-- KAI as a block R15 rig built from plain parts (no external catalog or animation assets).
-- The 15 Motor6D joints are the contract with the client AnimationController.
-- Hair, face, vest, sash, wraps and sneakers are cosmetic parts welded on top of the skeleton:
-- they follow the joints but never change hitboxes (those come from the simulation).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterData = require(Shared.CharacterData)
local RigSpec = require(Shared.RigSpec)
local RigReader = require(Shared.RigReader)
local RigBuilder = {}

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
	local PART_COLORS = {
		HumanoidRootPart = ink, LowerTorso = color("Pants"), UpperTorso = color("Shirt"), Head = color("SkinTone"),
		UpperArm = color("SkinTone"), LowerArm = color("Wraps"), Hand = color("Wraps"),
		UpperLeg = color("Pants"), LowerLeg = color("PantsShade"), Foot = color("Shoes"),
	}
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
		ornament("Head", "SideLock", Vector3.new(0.16, 0.8, 0.55), CFrame.new(sign * 0.6, 0.02, -0.12), hair)
		ornament("Head", "SideSpike", Vector3.new(0.18, 0.55, 0.5),
			CFrame.new(sign * 0.62, -0.42, -0.1) * CFrame.Angles(math.rad(180), 0, sign * 0.25), hair, "WedgePart")
	end
	ornament("Head", "Nose", Vector3.new(0.12, 0.14, 0.12), CFrame.new(0, -0.1, -0.54) * CFrame.Angles(math.rad(180), 0, 0), skin, "WedgePart")
	ornament("Head", "Mouth", Vector3.new(0.26, 0.04, 0.04), CFrame.new(0.02, -0.3, -0.51) * CFrame.Angles(0, 0, 0.08), ink)
	ornament("Head", "Jaw", Vector3.new(0.9, 0.12, 0.8), CFrame.new(0, -0.53, -0.04), skin)

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
	model.PrimaryPart, model.Parent = root, parent
	model:SetAttribute("RootHeight", 3)
	return model
end

-- Kit outfit worn over a Roblox avatar: headband, sash with tails, hand wraps and the kanji
-- on the back. Every piece is sized from the avatar's own parts, so it fits any body.
function RigBuilder.applyKit(model, slot)
	local data = CharacterData[slot]
	local sash, wraps, energy = Color3.fromHex(data.Sash), Color3.fromHex(data.Wraps), Color3.fromHex(data.Energy)
	local ink = Color3.fromHex("0B0B0E")
	local function piece(parentName, name, size, offset, color, shape)
		local base = model:FindFirstChild(parentName)
		if not base or not base:IsA("BasePart") then return nil end
		local p = Instance.new("Part")
		p.Name, p.Size, p.Color = "Kit" .. name, size, color
		p.Material = Enum.Material.SmoothPlastic
		p.CanCollide, p.CanTouch, p.CanQuery, p.Massless, p.CastShadow = false, false, false, true, true
		if shape then p.Shape = shape end
		p.CFrame = base.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = base, p, p
		p.Parent = model
		return p
	end
	local function size(name)
		local part = model:FindFirstChild(name)
		return if part and part:IsA("BasePart") then part.Size else Vector3.one
	end
	-- Swaying cloth strip hanging from `pivot` on a body part.
	local function tailPiece(parentName, name, stripSize, pivot)
		local base = model:FindFirstChild(parentName)
		local p = piece(parentName, name, stripSize, CFrame.identity, sash)
		if not p or not base then return end
		p:FindFirstChildOfClass("WeldConstraint"):Destroy()
		hangTail(base, p, pivot)
	end
	-- Hachimaki: a band around the forehead, knotted at the back with two tails in the wind.
	local head = size("Head")
	piece("Head", "Headband", Vector3.new(head.X * 1.04, head.Y * 0.16, head.Z * 1.04), CFrame.new(0, head.Y * 0.18, 0), sash)
	piece("Head", "HeadbandKnot", Vector3.new(0.3, 0.22, 0.16), CFrame.new(0, head.Y * 0.16, head.Z * 0.53), sash)
	for i, sign in { -1, 1 } do
		tailPiece("Head", "HeadbandTail", Vector3.new(0.18, 0.95 + i * 0.25, 0.06),
			CFrame.new(sign * 0.1, head.Y * 0.14, head.Z * 0.56) * CFrame.Angles(math.rad(-58 - i * 8), 0, sign * 0.25))
	end
	-- Sash around the waist, a big knot in front and long tails.
	local waist = size("LowerTorso")
	piece("LowerTorso", "Sash", Vector3.new(waist.X * 1.08, math.max(0.3, waist.Y * 0.38), waist.Z * 1.12), CFrame.new(0, waist.Y * 0.15, 0), sash)
	piece("LowerTorso", "SashKnot", Vector3.new(0.42, 0.36, 0.16), CFrame.new(-waist.X * 0.22, waist.Y * 0.15, -waist.Z * 0.58) * CFrame.Angles(0, 0, 0.3), sash)
	tailPiece("LowerTorso", "SashTail", Vector3.new(0.26, 1.5, 0.06), CFrame.new(-waist.X * 0.3, waist.Y * 0.12, -waist.Z * 0.6) * CFrame.Angles(0, 0, -0.14))
	tailPiece("LowerTorso", "SashTail2", Vector3.new(0.22, 1.2, 0.06), CFrame.new(-waist.X * 0.14, waist.Y * 0.1, -waist.Z * 0.61) * CFrame.Angles(0, 0, 0.12))
	tailPiece("LowerTorso", "SashTailBack", Vector3.new(0.28, 1.6, 0.06), CFrame.new(waist.X * 0.25, waist.Y * 0.15, waist.Z * 0.6) * CFrame.Angles(math.rad(14), 0, 0.12))
	-- Hand wraps: bands on both forearms and around the knuckles.
	for _, side in { "Left", "Right" } do
		local arm = size(side .. "LowerArm")
		for i, y in { 0.28, 0.02, -0.24 } do
			piece(side .. "LowerArm", "Wrap" .. i, Vector3.new(arm.X * 1.1, 0.1, arm.Z * 1.1),
				CFrame.new(0, y * arm.Y, 0) * CFrame.Angles(0, 0, (if i % 2 == 0 then 1 else -1) * 0.16), wraps)
		end
		local hand = size(side .. "Hand")
		piece(side .. "Hand", "Knuckles", Vector3.new(hand.X * 1.1, hand.Y * 0.4, hand.Z * 1.1), CFrame.new(0, -hand.Y * 0.1, 0), wraps)
	end
	-- Kanji on the back: an invisible plate carrying the emblem.
	local torso = size("UpperTorso")
	local plate = piece("UpperTorso", "Emblem", Vector3.new(torso.X * 0.7, torso.Y * 0.7, 0.05), CFrame.new(0, 0.05, torso.Z / 2 + 0.04), ink)
	if plate then
		plate.Transparency = 1
		local gui = Instance.new("SurfaceGui")
		gui.Face, gui.LightInfluence, gui.CanvasSize = Enum.NormalId.Back, 0, Vector2.new(200, 200)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency, label.Size, label.Text = 1, UDim2.fromScale(1, 1), data.Kanji
		label.TextScaled, label.Font, label.TextColor3 = true, Enum.Font.GothamBlack, energy
		local outline = Instance.new("UIStroke")
		outline.Color, outline.Thickness, outline.Parent = ink, 3, label
		label.Parent = gui
		gui.Parent = plate
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

local function hasJoints(model)
	for _, name in RigSpec.JOINTS do
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

-- Builds a fighter from a HumanoidDescription (see buildAvatar / buildShadow).
-- Returns the model, or nil and the reason.
local function fromDescription(slot, description, label)
	local built, model = pcall(Players.CreateHumanoidModelFromDescription, Players, description, Enum.HumanoidRigType.R15)
	if not built or not model then
		return nil, "création du corps R15 impossible : " .. tostring(model)
	end
	model.Name = "Fighter" .. slot
	model:SetAttribute("Slot", slot)
	model:SetAttribute("Character", label)
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
	local complete, missing = hasJoints(model)
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
	outline.OutlineColor, outline.OutlineTransparency = Color3.fromHex("0B0B0E"), 0
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = model
	model.PrimaryPart = root
	RigBuilder.applyKit(model, slot)
	return model, nil
end

-- A plain R15 body in the kit's colours (no asset id): used when the avatar cannot load.
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
	The player's own Roblox avatar wearing the kit. Never gives up silently:
	  avatar loaded                -> model, "OK"
	  avatar unavailable           -> default R15 body + kit, "DÉFAUT|<reason>"
	  avatar body cannot be built  -> retried without its accessories, then the default body
	Returns nil only if even the default R15 body fails (the server then uses KAI).
]]
function RigBuilder.buildAvatar(slot, player)
	local description, reason = describe(player)
	if description then
		local model, problem = fromDescription(slot, description, "AVATAR")
		if model then return model, "OK" end
		reason = problem
		-- Some accessories / layered clothing can fail to build: keep the body and colours.
		local plain = defaultDescription(slot)
		for _, field in { "HeadColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor", "TorsoColor",
			"Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg", "Face",
			"HeightScale", "WidthScale", "DepthScale", "HeadScale", "BodyTypeScale", "ProportionScale" } do
			pcall(function() plain[field] = description[field] end)
		end
		model = fromDescription(slot, plain, "AVATAR")
		if model then return model, "SANS ACCESSOIRES|" .. tostring(reason) end
	end
	warn("[FightingGame] Avatar indisponible pour " .. player.Name .. " : " .. tostring(reason))
	local model, problem = fromDescription(slot, defaultDescription(slot), "R15")
	if model then return model, "DÉFAUT|" .. tostring(reason) end
	return nil, "KAI|" .. tostring(problem)
end

-- The CPU / training dummy: a shadow clone of the opponent's avatar (dark body, glowing
-- outline). Without a loadable avatar (Studio test players), a default Roblox R15 body in the
-- NUIT colours. No asset id is involved: only body colours change.
function RigBuilder.buildShadow(slot, player)
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
	local model = fromDescription(slot, description, if shadow then "OMBRE" else "R15")
	if not model and shadow then model = fromDescription(slot, defaultDescription(slot), "R15") end
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
