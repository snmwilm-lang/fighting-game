local CameraController = {}
function CameraController.new(config)
	return setmetatable({ config = config, center = nil, distance = nil }, { __index = CameraController })
end
function CameraController:update(fighters, dt)
	local camera = workspace.CurrentCamera
	if not camera or not fighters[1] or not fighters[2] then return end
	local c, a, b = self.config, fighters[1], fighters[2]
	camera.CameraType, camera.FieldOfView = Enum.CameraType.Scriptable, c.CameraFOV
	local ratio = math.max(0.3, camera.ViewportSize.X / math.max(1, camera.ViewportSize.Y))
	local top = math.max(a.y, b.y) + 7
	local center = Vector3.new((a.x + b.x) / 2, top / 2 + 0.5, 0)
	local halfWidth = math.abs(a.x - b.x) / 2 + c.CameraMargin
	local distanceX = halfWidth / (math.tan(math.rad(c.CameraFOV / 2)) * ratio)
	-- Extra vertical space leaves room for HUD/touch controls.
	local distanceY = (top / 2 + 4) / math.tan(math.rad(c.CameraFOV / 2))
	local required = math.max(c.CameraMinDistance, distanceX, distanceY)
	local alpha = 1 - math.exp(-10 * dt)
	self.center = if self.center then self.center:Lerp(center, alpha) else center
	-- Pull out immediately to avoid cropping fast jumps; ease back in.
	self.distance = if not self.distance or required > self.distance then required else self.distance + (required - self.distance) * alpha
	camera.CFrame = CFrame.lookAt(self.center + Vector3.new(0, 0, self.distance), self.center)
	camera.Focus = CFrame.new(self.center)
end
return CameraController
