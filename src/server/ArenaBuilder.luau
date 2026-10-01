local ArenaBuilder = {}
function ArenaBuilder.build()
	local arena = Instance.new("Model")
	arena.Name, arena.Parent = "Arena", workspace
	local function part(name, size, position, color, material)
		local p = Instance.new("Part")
		p.Name, p.Size, p.Position = name, size, position
		p.Anchored, p.CanCollide, p.CanTouch = true, name == "Floor", false
		p.Material, p.Color = material or Enum.Material.SmoothPlastic, Color3.fromHex(color)
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = arena
		return p
	end
	part("Floor", Vector3.new(74, 2, 20), Vector3.new(0, -1, 0), "151B2D")
	part("Apron", Vector3.new(80, 1, 24), Vector3.new(0, -2.5, 0), "080C17")
	part("FrontEdge", Vector3.new(74, 0.15, 0.16), Vector3.new(0, -0.25, 10.05), "52F2D6", Enum.Material.Neon)
	part("RearEdge", Vector3.new(74, 0.12, 0.16), Vector3.new(0, 0.05, -9), "F77D50", Enum.Material.Neon)
	for x = -28, 28, 4 do
		part("FloorSeam", Vector3.new(0.04, 0.02, 18), Vector3.new(x, 0.015, 0), "2B354D")
	end
	for _, x in { -28, 28 } do
		part("Boundary", Vector3.new(0.1, 0.03, 18), Vector3.new(x, 0.04, 0), "EACA84")
	end
	part("Backdrop", Vector3.new(200, 80, 2), Vector3.new(0, 20, -35), "121728")
	local sun = part("SunDisc", Vector3.new(1, 19, 19), Vector3.new(8, 17, -32), "F77D50", Enum.Material.Neon)
	sun.Shape = Enum.PartType.Cylinder
	sun.CFrame *= CFrame.Angles(0, math.pi / 2, 0)
	for i = -8, 8 do
		local h = 6 + ((i * i * 7) % 15)
		part("Skyline", Vector3.new(5, h, 3), Vector3.new(i * 8, h / 2 - 3, -28), "1F2941")
	end
	for _, x in { -34, 34 } do
		part("GatePillar", Vector3.new(1.5, 15, 2), Vector3.new(x, 6, -8), "29344F")
		part("GateLight", Vector3.new(0.18, 13, 2.05), Vector3.new(x, 6, -8), "52F2D6", Enum.Material.Neon)
	end
	part("GateBeam", Vector3.new(72, 1.4, 2), Vector3.new(0, 13, -8), "29344F")
	local lighting = game:GetService("Lighting")
	lighting.ClockTime, lighting.Brightness = 16.5, 2
	lighting.Ambient = Color3.fromRGB(125, 135, 158)
	lighting.OutdoorAmbient = Color3.fromRGB(105, 117, 145)
	lighting.GlobalShadows = true
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name, grade.Contrast, grade.Saturation = "FightingGameGrade", 0.12, -0.05
	grade.Parent = lighting
	return arena
end
return ArenaBuilder
