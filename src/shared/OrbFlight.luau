--[[
	DAICHA's shadow orb flies on its own around him (pure: no Roblox API, no require). From his
	view (state, move and frame), his move's data, the move's role (its combo slot: the vortex
	roles whirl the orb) and the time, `offset` gives where the orb is, relative to his feet:
	`fwd` toward the side he faces, `up`, and `side` toward the camera (+Z). The client moves the
	orb there every frame; the pose sheets and storyboards draw it there; the tests check it.
	  idle, walking, jumping: it circles him at chest height, bobbing;
	  attacking: it comes back close and gathers during the wind-up, flies out to the point of
	             impact (the end of the move's reach) for the contact, then returns to its orbit;
	  guarding:  it holds before him as a shield;
	  hit:       it drifts back behind him.
]]
local OrbFlight = {}

OrbFlight.ORBIT = { radius = 1.9, height = 4.3, period = 2.6, bob = 0.3 }
local VORTEX = { DragonTornado = true, RisingWind = true }
local GUARD = { Blocking = true, CrouchBlocking = true, Blockstun = true, CrouchBlockstun = true }
local HURT = { Hitstun = true, Launched = true, Knockdown = true, KO = true, Crumple = true, GuardBroken = true, GetUp = true }

local function smooth(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function mix(a, b, t)
	return { fwd = a.fwd + (b.fwd - a.fwd) * t, up = a.up + (b.up - a.up) * t, side = a.side + (b.side - a.side) * t }
end

-- Its place on the orbit at `time` (lower when he crouches).
function OrbFlight.orbit(time, crouching)
	local o = OrbFlight.ORBIT
	local angle = time / o.period * math.pi * 2
	return {
		fwd = math.cos(angle) * o.radius,
		up = (if crouching then o.height - 1.3 else o.height) + math.sin(time * 3.1) * o.bob,
		side = math.sin(angle) * o.radius,
	}
end

-- The point a move strikes: the end of its reach, at the middle of its hitbox's height.
function OrbFlight.strike(move)
	local box = move and move.hitbox
	if not box then return { fwd = 1.8, up = 3.4, side = 0.3 } end
	return { fwd = math.max(1.4, box.far - 0.2), up = math.clamp((box.low + box.high) / 2, 0.8, 5.5), side = 0.3 }
end

function OrbFlight.offset(view, move, role, time)
	local state = view.state
	local crouching = state == "Crouching" or state == "CrouchBlocking" or state == "CrouchBlockstun"
	local orbit = OrbFlight.orbit(time, crouching)
	if GUARD[state] then
		return { fwd = 1.6, up = if crouching then 2.4 else 3.6, side = 0.3 }
	elseif HURT[state] then
		return { fwd = -1.6, up = 3.6, side = 0.8 }
	elseif state == "Dashing" then
		return { fwd = -1.3, up = 4, side = 0.5 }
	elseif state ~= "Attack" or not move then
		return orbit
	end
	local frame, startup, active, recovery = view.moveFrame or 0, move.startup, move.active, move.recovery
	if role and VORTEX[role] then
		-- The vortex: the orb whirls round him, fast and wide.
		local angle = time * 12
		local r = 2.7
		return { fwd = math.cos(angle) * r, up = 3.2 + math.sin(time * 9) * 0.8, side = math.sin(angle) * r }
	end
	local gather = { fwd = 0.9, up = 3.6, side = 0.6 }
	local hit = OrbFlight.strike(move)
	if frame <= startup then
		return mix(orbit, gather, smooth(frame / math.max(1, startup)))
	elseif frame <= startup + active then
		-- (multi-hit moves: a little jolt on every beat)
		local beat = if move.hitInterval then math.floor((frame - startup - 1) / move.hitInterval) % 2 else 0
		return { fwd = hit.fwd - beat * 0.4, up = hit.up + beat * 0.3, side = hit.side }
	end
	return mix(hit, orbit, smooth((frame - startup - active) / math.max(1, recovery)))
end

return OrbFlight
