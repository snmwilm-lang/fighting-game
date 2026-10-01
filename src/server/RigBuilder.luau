-- Original block R15 test rig, no external catalog/animation assets.
local RigBuilder = {}
function RigBuilder.build(slot, parent)
	local model = Instance.new("Model")
	model.Name = "Fighter" .. slot
	model:SetAttribute("Slot", slot)
	local accent = Color3.fromHex(if slot == 1 then "52F2D6" else "FF895A")
	local dark = Color3.fromHex("263047")
	local skin = Color3.fromHex(if slot == 1 then "B47B5F" else "C69A75")
	local parts = {}
	local function part(name, size, pos, color)
		local p = Instance.new("Part")
		p.Name, p.Size, p.Position, p.Color = name, size, pos, color
		p.Material = Enum.Material.SmoothPlastic
		p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = false, false, false, true
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent, parts[name] = model, p
		return p
	end
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.zero, dark)
	root.Transparency, root.Anchored = 1, true
	part("LowerTorso", Vector3.new(1.65, 0.65, 0.9), Vector3.zero, dark)
	part("UpperTorso", Vector3.new(1.9, 1.4, 1), Vector3.new(0, 1, 0), accent)
	part("Head", Vector3.new(1.1, 1.1, 1), Vector3.new(0, 2.3, 0), skin)
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
		part(side .. "UpperArm", Vector3.new(0.65, 1.1, 0.72), Vector3.new(sign * 1.35, 0.92, 0), skin)
		part(side .. "LowerArm", Vector3.new(0.6, 0.95, 0.65), Vector3.new(sign * 1.35, -0.08, 0), dark)
		part(side .. "Hand", Vector3.new(0.7, 0.55, 0.72), Vector3.new(sign * 1.35, -0.8, 0), accent)
		joint(side .. "Shoulder", "UpperTorso", side .. "UpperArm", Vector3.new(sign * 1.1, 1.5, 0))
		joint(side .. "Elbow", side .. "UpperArm", side .. "LowerArm", Vector3.new(sign * 1.35, 0.4, 0))
		joint(side .. "Wrist", side .. "LowerArm", side .. "Hand", Vector3.new(sign * 1.35, -0.55, 0))
		part(side .. "UpperLeg", Vector3.new(0.72, 1.25, 0.8), Vector3.new(sign * 0.47, -0.95, 0), dark)
		part(side .. "LowerLeg", Vector3.new(0.66, 1.05, 0.7), Vector3.new(sign * 0.47, -2.08, 0), dark)
		part(side .. "Foot", Vector3.new(0.78, 0.4, 1.15), Vector3.new(sign * 0.47, -2.8, -0.15), accent)
		joint(side .. "Hip", "LowerTorso", side .. "UpperLeg", Vector3.new(sign * 0.47, -0.3, 0))
		joint(side .. "Knee", side .. "UpperLeg", side .. "LowerLeg", Vector3.new(sign * 0.47, -1.57, 0))
		joint(side .. "Ankle", side .. "LowerLeg", side .. "Foot", Vector3.new(sign * 0.47, -2.6, 0))
	end
	local function ornament(name, size, offset, color)
		local p = part(name, size, parts.Head.Position + offset, color)
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = parts.Head, p, p
	end
	ornament("Headband", Vector3.new(1.13, 0.18, 1.03), Vector3.new(0, 0.3, 0), accent)
	ornament("Brow", Vector3.new(0.8, 0.1, 0.05), Vector3.new(0, 0.09, -0.52), dark)
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.AutoRotate, humanoid.EvaluateStateMachine = false, false
	humanoid.AutomaticScalingEnabled = false
	humanoid.BreakJointsOnDeath, humanoid.RequiresNeck = false, false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed, humanoid.JumpPower = 0, 0
	humanoid.Parent = model
	local outline = Instance.new("Highlight")
	outline.Name, outline.Adornee = "InkOutline", model
	outline.FillTransparency = 1
	outline.OutlineColor, outline.OutlineTransparency = Color3.fromHex("070B13"), 0
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = model
	model.PrimaryPart, model.Parent = root, parent
	return model
end
return RigBuilder
