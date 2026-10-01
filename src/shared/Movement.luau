-- Pure authoritative movement; no Roblox physics, rendering, remotes or assets.
local Movement = {}

function Movement.new(x, facing)
	return { x = x, y = 0, vy = 0, vx = 0, facing = facing,
		state = "Idle", dashTicks = 0, dashCooldown = 0, dashDirection = facing }
end

function Movement.step(s, input, c)
	local dt = 1 / c.TickRate
	s.dashCooldown = math.max(0, s.dashCooldown - 1)
	local grounded = s.y <= 0 and s.vy <= 0
	local crouched = grounded and input.crouch and s.dashTicks == 0
	if input.jump and grounded and not crouched and s.dashTicks == 0 then
		s.vy = c.JumpVelocity
		grounded = false
	end
	if input.dash and grounded and not crouched and s.dashTicks == 0 and s.dashCooldown == 0 then
		s.dashDirection = if math.abs(input.axis) > 0.1 then math.sign(input.axis) else s.facing
		s.dashTicks = c.DashTicks
		s.dashCooldown = c.DashCooldownTicks
	end
	if s.dashTicks > 0 then
		s.vx = s.dashDirection * c.DashSpeed
		s.dashTicks -= 1
		s.state = "Dashing"
	elseif crouched then
		s.vx = 0
		s.state = "Crouching"
	else
		s.vx = input.axis * (if grounded then c.WalkSpeed else c.AirSpeed)
		s.state = if math.abs(s.vx) > 0.05 then "Walking" else "Idle"
	end
	s.x = math.clamp(s.x + s.vx * dt, c.ArenaMinX, c.ArenaMaxX)
	if not grounded then
		s.vy -= c.Gravity * dt
		s.y += s.vy * dt
		if s.y <= 0 then
			s.y = 0
			s.vy = 0
		else
			s.state = if s.vy > 0 then "Jumping" else "Falling"
		end
	end
end

function Movement.resolvePair(a, b, c, previousDelta)
	local delta = b.x - a.x
	-- Preserve ordering during grounded crossing attempts, including a fast dash.
	if math.abs(a.y - b.y) < c.PushHeight then
		local order = if previousDelta >= 0 then 1 else -1
		if delta * order < c.PushWidth then
			local center = math.clamp((a.x + b.x) / 2,
				c.ArenaMinX + c.PushWidth / 2, c.ArenaMaxX - c.PushWidth / 2)
			a.x = center - order * c.PushWidth / 2
			b.x = center + order * c.PushWidth / 2
		end
	end
	if math.abs(b.x - a.x) > 0.05 then
		if a.dashTicks == 0 then a.facing = math.sign(b.x - a.x) end
		if b.dashTicks == 0 then b.facing = math.sign(a.x - b.x) end
	end
end

return Movement
