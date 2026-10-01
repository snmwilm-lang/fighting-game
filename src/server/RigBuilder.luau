-- KAI as a block R15 rig built from plain parts (no external catalog or animation assets).
-- The 15 Motor6D joints are the contract with the client AnimationController.
-- Hair, face, vest, sash and wraps are cosmetic parts welded on top of the skeleton.
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
	local hair, hairTip = color("Hair"), color("HairTip")
	-- Face (front of the rig is -Z): sharp determined eyes and angled brows.
	for _, sign in { -1, 1 } do
		ornament("Head", "EyeWhite", Vector3.new(0.3, 0.15, 0.04), CFrame.new(sign * 0.23, 0.03, -0.51), Color3.fromHex("F7F7FA"))
		ornament("Head", "Iris", Vector3.new(0.13, 0.15, 0.04), CFrame.new(sign * 0.2, 0.03, -0.53), color("Eyes"))
		ornament("Head", "Brow", Vector3.new(0.36, 0.08, 0.04),
			CFrame.new(sign * 0.23, 0.19, -0.52) * CFrame.Angles(0, 0, sign * 0.32), ink)
		ornament("Head", "SideLock", Vector3.new(0.16, 0.75, 0.55), CFrame.new(sign * 0.6, 0.02, -0.12), hair)
	end
	ornament("Head", "Mouth", Vector3.new(0.24, 0.04, 0.04), CFrame.new(0, -0.27, -0.51), ink)
	-- Messy spiky black hair with red highlights.
	ornament("Head", "HairCap", Vector3.new(1.24, 0.42, 1.14), CFrame.new(0, 0.48, 0.04), hair)
	for i, x in { -0.4, -0.13, 0.13, 0.4 } do
		ornament("Head", "Bang", Vector3.new(0.3, 0.5, 0.12),
			CFrame.new(x, 0.3, -0.55) * CFrame.Angles(math.rad(180), 0, (i - 2.5) * 0.25), hair, "WedgePart")
	end
	local spikes = {
		{ x = -0.45, h = 0.85, tilt = -0.45, tip = false },
		{ x = -0.24, h = 1.2, tilt = -0.2, tip = true },
		{ x = 0, h = 1.45, tilt = 0.02, tip = false },
		{ x = 0.24, h = 1.15, tilt = 0.22, tip = true },
		{ x = 0.45, h = 0.8, tilt = 0.45, tip = false },
	}
	for _, s in spikes do
		ornament("Head", "HairSpike", Vector3.new(0.3, s.h, 1.2),
			CFrame.new(s.x, 0.62 + s.h / 2, 0.15) * CFrame.Angles(0, 0, s.tilt), if s.tip then hairTip else hair, "WedgePart")
	end
	for _, sign in { -1, 1 } do
		ornament("Head", "BackSpike", Vector3.new(0.32, 0.95, 0.85),
			CFrame.new(sign * 0.3, 0.1, 0.75) * CFrame.Angles(math.rad(-120), 0, sign * 0.3), hair, "WedgePart")
	end
	-- Open sleeveless vest over the white tank top, with a raised collar.
	local vest, trim = color("Vest"), color("VestTrim")
	for _, sign in { -1, 1 } do
		ornament("UpperTorso", "VestFront", Vector3.new(0.62, 1.42, 0.08), CFrame.new(sign * 0.66, 0, -0.52), vest)
		ornament("UpperTorso", "VestSide", Vector3.new(0.08, 1.42, 1.04), CFrame.new(sign * 0.97, 0, 0), vest)
		ornament("UpperTorso", "VestTrim", Vector3.new(0.06, 1.42, 0.1), CFrame.new(sign * 0.33, 0, -0.55), trim)
		ornament("UpperTorso", "Shoulder", Vector3.new(0.5, 0.18, 1.06), CFrame.new(sign * 0.72, 0.68, 0), vest)
		ornament(if sign < 0 then "LeftUpperArm" else "RightUpperArm", "Muscle", Vector3.new(0.74, 0.4, 0.8),
			CFrame.new(0, 0.1, -0.02), color("SkinTone"))
		ornament(if sign < 0 then "LeftLowerArm" else "RightLowerArm", "WrapBand", Vector3.new(0.66, 0.08, 0.7),
			CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, 0.15), Color3.fromHex("C9C9D1"))
		ornament(if sign < 0 then "LeftFoot" else "RightFoot", "ShoeStripe", Vector3.new(0.82, 0.14, 0.7),
			CFrame.new(0, 0.02, 0.1), color("ShoeAccent"))
		ornament(if sign < 0 then "LeftFoot" else "RightFoot", "Sole", Vector3.new(0.84, 0.12, 1.24),
			CFrame.new(0, -0.18, 0), color("Sole"))
		ornament(if sign < 0 then "LeftLowerLeg" else "RightLowerLeg", "PantsCuff", Vector3.new(0.86, 0.22, 0.92),
			CFrame.new(0, -0.38, 0), color("PantsShade"))
	end
	ornament("UpperTorso", "VestBack", Vector3.new(1.94, 1.42, 0.08), CFrame.new(0, 0, 0.52), vest)
	ornament("UpperTorso", "Collar", Vector3.new(1.3, 0.42, 0.5), CFrame.new(0, 0.82, 0.3) * CFrame.Angles(math.rad(-15), 0, 0), vest)
	-- Red sash with a knot and two long tails.
	local sash = color("Sash")
	ornament("LowerTorso", "Sash", Vector3.new(1.78, 0.34, 1.02), CFrame.new(0, 0.18, 0), sash)
	ornament("LowerTorso", "SashKnot", Vector3.new(0.4, 0.34, 0.14), CFrame.new(-0.35, 0.18, -0.54), sash)
	ornament("LowerTorso", "SashTail", Vector3.new(0.24, 1.5, 0.06), CFrame.new(-0.45, -0.6, -0.56) * CFrame.Angles(0, 0, -0.12), sash)
	ornament("LowerTorso", "SashTail", Vector3.new(0.2, 1.25, 0.06), CFrame.new(-0.22, -0.5, -0.57) * CFrame.Angles(0, 0, 0.1), sash)
	ornament("LowerTorso", "SashTailBack", Vector3.new(0.26, 1.6, 0.06), CFrame.new(0.4, -0.6, 0.54) * CFrame.Angles(math.rad(12), 0, 0.1), sash)

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
	return model
end
return RigBuilder
