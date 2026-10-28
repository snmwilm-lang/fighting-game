-- Side camera framing both fighters. Shake and punch-in zoom are cosmetic and short.
local CameraController = {}

function CameraController.new(config)
	return setmetatable({
		config = config, center = nil, distance = nil,
		shakeTime = 0, shakeDuration = 0, shakePower = 0,
		zoom = 0, focus = nil,
	}, { __index = CameraController })
end

function CameraController:shake(power, duration)
	if power >= self.shakePower * (self.shakeTime / math.max(self.shakeDuration, 1e-3)) then
		self.shakePower, self.shakeDuration, self.shakeTime = power, duration, duration
	end
end

-- Brief push toward a point (heavy hits, KO). amount is a fraction of the distance.
function CameraController:punch(amount, focus)
	self.zoom = math.max(self.zoom, amount)
	self.focus = focus
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

	local look = self.center
	local distance = self.distance
	if self.zoom > 0.001 then
		if self.focus then look = look:Lerp(self.focus, self.zoom) end
		distance *= 1 - self.zoom * 0.45
		self.zoom *= math.exp(-3.5 * dt)
	else
		self.zoom, self.focus = 0, nil
	end
	local offset = Vector3.zero
	if self.shakeTime > 0 then
		self.shakeTime = math.max(0, self.shakeTime - dt)
		local strength = self.shakePower * self.shakeTime / self.shakeDuration
		offset = Vector3.new((math.random() * 2 - 1) * strength, (math.random() * 2 - 1) * strength, 0)
	end
	camera.CFrame = CFrame.lookAt(look + Vector3.new(0, 0, distance) + offset, look + offset)
	camera.Focus = CFrame.new(look)
end

return CameraController
