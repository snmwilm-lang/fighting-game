-- KAI as a block R15 rig built from plain parts (no external catalog or animation assets).
-- The 15 Motor6D joints are the contract with the client AnimationController.
-- Hair, face, vest, sash, wraps and sneakers are cosmetic parts welded on top of the skeleton:
-- they follow the joints but never change hitboxes (those come from the simulation).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharacterData = require(ReplicatedStorage:WaitForChild("Shared").CharacterData)
local RigBuilder = {}

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
		p.CastShadow = false
		p.Parent = model
		if not parts[name] then parts[name] = p end
		return p
	end
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.zero, ink)
	root.Transparency, root.Anchored = 1, true
	part("LowerTorso", Vector3.new(1.7, 0.65, 0.95), Vector3.zero, color("Pants"))
	part("UpperTorso", Vector3.new(1.9, 1.4, 1), Vector3.new(0, 1, 0), color("Shirt"))
	part("Head", Vector3.new(1.1, 1.1, 1), Vector3.new(0, 2.3, 0), color("SkinTone"))
	local function joint(name, aName, bName, pivot)
		local a, b = parts[aName], parts[bName]
		local j = Instance.new("Motor6D")
		j.Name, j.Part0, j.Part1 = name, a, b
		j.C0 = a.CFrame:ToObjectSpace(CFrame.new(pivot))
		j.C1 = b.CFrame:ToObjectSpace(CFrame.new(pivot))
		j.Parent = b
	end
	joint("Root", "HumanoidRootPart", "LowerTorso", Vector3.zero)
	joint("Waist", "LowerTorso", "UpperTorso", Vector3.new(0, 0.35, 0))
	joint("Neck", "UpperTorso", "Head", Vector3.new(0, 1.72, 0))
	for _, side in { "Left", "Right" } do
		local sign = if side == "Left" then -1 else 1
		-- Sleeveless: bare, muscular arms; wrapped forearms and fists.
		part(side .. "UpperArm", Vector3.new(0.7, 1.1, 0.76), Vector3.new(sign * 1.37, 0.92, 0), color("SkinTone"))
		part(side .. "LowerArm", Vector3.new(0.62, 0.95, 0.66), Vector3.new(sign * 1.37, -0.08, 0), color("Wraps"))
		part(side .. "Hand", Vector3.new(0.74, 0.62, 0.76), Vector3.new(sign * 1.37, -0.8, 0), color("Wraps"))
		joint(side .. "Shoulder", "UpperTorso", side .. "UpperArm", Vector3.new(sign * 1.1, 1.5, 0))
		joint(side .. "Elbow", side .. "UpperArm", side .. "LowerArm", Vector3.new(sign * 1.37, 0.4, 0))
		joint(side .. "Wrist", side .. "LowerArm", side .. "Hand", Vector3.new(sign * 1.37, -0.55, 0))
		-- Baggy martial-arts pants, sneakers.
		part(side .. "UpperLeg", Vector3.new(0.86, 1.25, 0.92), Vector3.new(sign * 0.47, -0.95, 0), color("Pants"))
		part(side .. "LowerLeg", Vector3.new(0.8, 1.05, 0.86), Vector3.new(sign * 0.47, -2.08, 0), color("PantsShade"))
		part(side .. "Foot", Vector3.new(0.8, 0.42, 1.2), Vector3.new(sign * 0.47, -2.8, -0.15), color("Shoes"))
		joint(side .. "Hip", "LowerTorso", side .. "UpperLeg", Vector3.new(sign * 0.47, -0.3, 0))
		joint(side .. "Knee", side .. "UpperLeg", side .. "LowerLeg", Vector3.new(sign * 0.47, -1.57, 0))
		joint(side .. "Ankle", side .. "LowerLeg", side .. "Foot", Vector3.new(sign * 0.47, -2.6, 0))
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
	ornament("LowerTorso", "SashTail", Vector3.new(0.26, 1.7, 0.06), CFrame.new(-0.48, -0.7, -0.56) * CFrame.Angles(0, 0, -0.14), sash)
	ornament("LowerTorso", "SashTail", Vector3.new(0.22, 1.35, 0.06), CFrame.new(-0.24, -0.55, -0.57) * CFrame.Angles(0, 0, 0.12), sash)
	ornament("LowerTorso", "SashTailBack", Vector3.new(0.28, 1.8, 0.06), CFrame.new(0.4, -0.7, 0.54) * CFrame.Angles(math.rad(14), 0, 0.12), sash)

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

local JOINTS = {
	"Root", "Waist", "Neck", "LeftShoulder", "LeftElbow", "LeftWrist", "RightShoulder", "RightElbow",
	"RightWrist", "LeftHip", "LeftKnee", "LeftAnkle", "RightHip", "RightKnee", "RightAnkle",
}

-- The player's own Roblox avatar as a standard R15 rig. Its 15 Motor6D joints have the same
-- names as KAI's, so the same poses drive it. Returns an unparented model, or nil if the
-- avatar cannot be loaded (for example the negative test players of a Studio local server).
function RigBuilder.buildAvatar(slot, userId)
	local ok, description = pcall(Players.GetHumanoidDescriptionFromUserId, Players, userId)
	if not ok or not description then
		warn("[FightingGame] Avatar indisponible pour " .. tostring(userId) .. " : " .. tostring(description))
		return nil
	end
	local built, model = pcall(Players.CreateHumanoidModelFromDescription, Players, description, Enum.HumanoidRigType.R15)
	if not built or not model then
		warn("[FightingGame] Création de l'avatar R15 impossible : " .. tostring(model))
		return nil
	end
	model.Name = "Fighter" .. slot
	model:SetAttribute("Slot", slot)
	model:SetAttribute("Character", "AVATAR")
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
		return nil
	end
	for _, name in JOINTS do
		local found = false
		for _, d in model:GetDescendants() do
			if d:IsA("Motor6D") and d.Name == name then
				found = true
				break
			end
		end
		if not found then
			warn("[FightingGame] Avatar sans articulation " .. name .. ", retour à KAI")
			model:Destroy()
			return nil
		end
	end
	root.Anchored, root.Transparency = true, 1
	humanoid.AutoRotate, humanoid.EvaluateStateMachine = false, false
	humanoid.BreakJointsOnDeath, humanoid.RequiresNeck = false, false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed, humanoid.JumpPower = 0, 0
	-- Feet on the floor: root center sits HipHeight + half the root above the ground.
	model:SetAttribute("RootHeight", humanoid.HipHeight + root.Size.Y / 2)
	local outline = Instance.new("Highlight")
	outline.Name, outline.Adornee = "InkOutline", model
	outline.FillTransparency, outline.FillColor = 1, Color3.new(1, 1, 1)
	outline.OutlineColor, outline.OutlineTransparency = Color3.fromHex("0B0B0E"), 0
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = model
	model.PrimaryPart = root
	return model
end

return RigBuilder
