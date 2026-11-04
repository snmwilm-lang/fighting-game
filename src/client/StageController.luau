--[[
	Living stage, local and cosmetic: lantern flicker, banners swaying in the wind, a contact
	shadow under each fighter and a soft background depth of field during play (the cinematic
	controller owns its own depth of field while it plays).
]]
local Lighting = game:GetService("Lighting")

local StageController = {}
StageController.__index = StageController

function StageController.new(config)
	local self = setmetatable({ config = config, lights = {}, cloths = {}, shadows = {} }, StageController)
	self:setArena(workspace:FindFirstChild("Arena"))
	self.focus = Instance.new("DepthOfFieldEffect")
	self.focus.Name = "StageFocus"
	self.focus.FarIntensity, self.focus.NearIntensity, self.focus.InFocusRadius = 0.18, 0, 22
	self.focus.Parent = Lighting
	self.folder = Instance.new("Folder")
	self.folder.Name = "StageEffects"
	self.folder.Parent = workspace
	return self
end

-- The stage to bring to life (a new one is built for every match's stage: ArenaBuilder).
function StageController:setArena(arena)
	self.lights, self.cloths = {}, {}
	if not arena then return end
	for i, p in arena:GetChildren() do
		if p:IsA("BasePart") then
			local light = p:FindFirstChildOfClass("PointLight")
			if p.Name == "Lantern" and light then
				table.insert(self.lights, { light = light, base = light.Brightness, seed = i * 1.37 })
			elseif p.Name == "Banner" or p.Name == "BannerTail" then
				-- Swing around the top edge of the cloth.
				table.insert(self.cloths, { part = p, base = p.CFrame, half = p.Size.Y / 2, seed = i * 0.71 })
			end
		end
	end
end

-- Three stacked translucent discs fake a soft-edged blob shadow (no texture needed).
local RINGS = { { scale = 1, alpha = 0.82 }, { scale = 0.72, alpha = 0.72 }, { scale = 0.45, alpha = 0.62 } }

local function contactShadow(parent)
	local discs = {}
	for i in RINGS do
		local disc = Instance.new("Part")
		disc.Name = "ContactShadow"
		disc.Shape = Enum.PartType.Cylinder
		disc.Anchored, disc.CanCollide, disc.CanTouch, disc.CanQuery, disc.CastShadow = true, false, false, false, false
		disc.Material, disc.Color = Enum.Material.SmoothPlastic, Color3.fromHex("0B0507")
		disc.Size = Vector3.new(0.02, 3, 3)
		disc.Parent = parent
		discs[i] = disc
	end
	return discs
end

function StageController:update(now, displayed, cinematicActive)
	for _, l in self.lights do
		local flicker = math.sin(now * 13 + l.seed) * 0.08 + math.sin(now * 23.7 + l.seed * 2) * 0.05
			+ math.sin(now * 3.1 + l.seed) * 0.06
		l.light.Brightness = l.base * (1 + flicker)
	end
	for _, c in self.cloths do
		local sway = math.sin(now * 0.9 + c.seed) * 0.035 + math.sin(now * 2.3 + c.seed * 3) * 0.012
		local pivot = c.base * CFrame.new(0, c.half, 0)
		c.part.CFrame = pivot * CFrame.Angles(sway * 0.6, 0, sway) * CFrame.new(0, -c.half, 0)
	end
	-- Contact shadows: darker and tighter on the floor, fading as the fighter rises.
	for i, view in displayed do
		local discs = self.shadows[i]
		if not discs then
			discs = contactShadow(self.folder)
			self.shadows[i] = discs
		end
		local height = math.max(0, view.y or 0)
		local fade = math.clamp(height / 14, 0, 1)
		local lying = view.state == "Knockdown" or view.state == "KO" or view.pose == "DownFace"
		local size = (if lying then 5 else 3.6) * (1 - fade * 0.55)
		for r, ring in RINGS do
			local disc = discs[r]
			local d = size * ring.scale
			disc.Size = Vector3.new(0.02, d, d)
			disc.CFrame = CFrame.new(view.x, 0.03 + r * 0.004, view.z or 0) * CFrame.Angles(0, 0, math.pi / 2)
			disc.Transparency = ring.alpha + (1 - ring.alpha) * fade
		end
	end
	self.focus.Enabled = not cinematicActive
	local camera = workspace.CurrentCamera
	if camera then
		-- Keep the fighting plane sharp, soften the painted background.
		self.focus.FocusDistance = math.abs(camera.CFrame.Position.Z)
	end
end

return StageController
