--[[
	DAICHA's shadow orb flies on its own around him (pure: no Roblox API, no require). From his
	view (state, move and frame), his move's data, the move's role (its combo slot: the vortex
	roles whirl the orb) and the time, `offset` gives where the orb is, relative to his feet:
	`fwd` toward the side he faces, `up`, and `side` toward the camera (+Z). The client moves the
	orb there every frame; the pose sheets and storyboards draw it there; the tests check it.
	  idle, walking, jumping: it circles him at chest height, bobbing;
	  attacking: like a nunchaku on a chain of shadow from his hand: it leaves its orbit and
	             spins round his hand during the wind-up (one full turn, overhead and behind),
	             whips out on an arc to the point of impact (the end of the move's reach) for the
	             contact, carries on round, down and back under, and returns to its orbit;
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

-- The nunchaku: the hand it spins round, the short chain of the wind-up, the share of the
-- startup spent whipping out, how far round it carries on after the contact.
OrbFlight.NUNCHAKU = { pivotFwd = 0.7, chain = 1.3, side = 1.2, whip = 0.4, follow = 1.3 }

-- A point of the circle of radius r round the pivot p, at `angle` (radians: 0 = straight
-- ahead, pi / 2 = straight up), in his fighting plane (never under the deck).
local function round(p, r, angle, side)
	return { fwd = p.fwd + math.cos(angle) * r, up = math.max(0.6, p.up + math.sin(angle) * r), side = side }
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
	local n = OrbFlight.NUNCHAKU
	local hit = OrbFlight.strike(move)
	local pivot = { fwd = n.pivotFwd, up = math.clamp(hit.up + 0.3, 2.6, 4.6) }
	local reach = math.max(n.chain, math.sqrt((hit.fwd - pivot.fwd) ^ 2 + (hit.up - pivot.up) ^ 2))
	local aim = math.atan2(hit.up - pivot.up, hit.fwd - pivot.fwd)
	local cocked = aim + math.pi * 0.6 -- up and behind, where the whip starts
	local whip = math.max(2, math.floor(startup * n.whip + 0.5))
	if frame <= startup - whip then
		-- The wind-up: out of its orbit into a turn round his hand (a full one when there is
		-- time, half of one for a quick move), ending cocked.
		local u = math.max(frame, 0) / math.max(1, startup - whip)
		local turns = math.clamp((startup - whip) / 8, 0.5, 1)
		local spin = round(pivot, n.chain, cocked - (1 - u) * turns * math.pi * 2, n.side)
		return mix(orbit, spin, smooth(u * 3))
	elseif frame <= startup then
		-- The whip: over the top to the point of impact, faster and faster, the chain paying out.
		local u = (frame - (startup - whip)) / whip
		local at = round(pivot, n.chain + (reach - n.chain) * u, cocked + (aim - cocked) * u * u, n.side + (hit.side - n.side) * u)
		return at
	elseif frame <= startup + active then
		-- (multi-hit moves: a little jolt on every beat)
		local beat = if move.hitInterval then math.floor((frame - startup - 1) / move.hitInterval) % 2 else 0
		return { fwd = hit.fwd - beat * 0.4, up = hit.up + beat * 0.3, side = hit.side }
	end
	-- Follow-through: it carries on round, down and back under his hand, then rejoins its orbit.
	local u = (frame - startup - active) / math.max(1, recovery)
	local swing = round(pivot, reach + (n.chain - reach) * smooth(u * 1.5), aim - math.pi * n.follow * smooth(u * 1.5),
		hit.side + (n.side - hit.side) * smooth(u * 3))
	local out = mix(swing, orbit, smooth((u - 0.5) / 0.5))
	-- (passing back by him, the chain swings it round his side, never through his body)
	if out.up < 6.2 and out.fwd * out.fwd + out.side * out.side < 1 then
		out.side = math.sqrt(1 - math.min(1, out.fwd * out.fwd))
	end
	return out
end

return OrbFlight
