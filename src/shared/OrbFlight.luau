--[[
	DAICHA's shadow matter (pure: no Roblox API, no require). Wilhem: « elle ne change pas de
	pouvoir selon l'action ; elle change la FORME de son pouvoir »: ATTACK = a round, dense
	sphere; DEFENCE = the same matter spread flat into a black disc before her.
	From her view (state, move and frame), the move's data, its role and the time, `offset`
	gives where the matter is, relative to her feet (`fwd` toward the side she faces, `up`,
	`side` toward the camera), and `form` its shape (a ball of `radius`, or a disc of `radius`
	and `thickness` facing the opponent). The client draws it there every frame; the pose
	sheets and storyboards draw it there; the tests check it.
	  idle, walking, jumping: a sphere circling her at chest height, bobbing;
	  attacking: it leaves its orbit and gathers at her striking hand, compacting (smaller,
	             denser) during the wind-up; it drives out with the blow to the point of impact,
	             swelling on contact (the sphere IS the impact); then back to the hand, then
	             to its orbit;
	  guarding:  it flattens into a wide black disc, a shield before her;
	  hit:       it drifts back behind her, small.
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

-- Her striking hand, where the matter gathers before a blow (toward the camera: never in her body).
OrbFlight.HAND = { fwd = 0.75, side = 1.05 }

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
		return { fwd = 1.5, up = if crouching then 2.3 else 3.5, side = 0.2 } -- (the disc, before her)
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
	local hit = OrbFlight.strike(move)
	local hand = OrbFlight.hand(hit)
	local out
	if frame <= startup - 2 then
		-- The wind-up: out of its orbit into her hand.
		out = mix(orbit, hand, smooth(math.max(frame, 0) / math.max(1, startup - 2) * 1.6))
	elseif frame <= startup then
		-- The blow: the sphere drives out with the fist.
		out = mix(hand, hit, (frame - (startup - 2)) / 2)
	elseif frame <= startup + active then
		-- (multi-hit moves: a little jolt on every beat)
		local beat = if move.hitInterval then math.floor((frame - startup - 1) / move.hitInterval) % 2 else 0
		out = { fwd = hit.fwd - beat * 0.4, up = hit.up + beat * 0.3, side = hit.side }
	else
		-- Back to her hand, then to its orbit.
		local u = (frame - startup - active) / math.max(1, recovery)
		out = mix(mix(hit, hand, smooth(u * 2)), orbit, smooth((u - 0.5) / 0.5))
	end
	return OrbFlight.clear(out)
end

-- Never through her body (the matter passes round her side), never under the deck.
function OrbFlight.clear(o)
	o.up = math.max(0.6, o.up)
	if o.up < 6.2 and o.fwd * o.fwd + o.side * o.side < 1 then
		o.side = math.sqrt(1 - math.min(1, o.fwd * o.fwd))
	end
	return o
end

-- Where her striking hand holds the matter before the blow (at the height of the impact).
function OrbFlight.hand(hit)
	local h = OrbFlight.HAND
	return { fwd = h.fwd, up = math.clamp(hit.up, 2.4, 4.6), side = h.side }
end

-- The SHAPE of the matter. Attack: a ball compacting during the wind-up, swelling on contact.
-- Guard: a flat disc facing the opponent. Returns { shape = "ball", radius } or
-- { shape = "disc", radius, thickness }.
OrbFlight.SIZE = { rest = 0.45, dense = 0.3, impact = 0.85, disc = 1.8, thickness = 0.16, hurt = 0.35 }
function OrbFlight.form(view, move)
	local S = OrbFlight.SIZE
	local state = view.state
	if GUARD[state] then return { shape = "disc", radius = S.disc, thickness = S.thickness } end
	if HURT[state] then return { shape = "ball", radius = S.hurt } end
	if state ~= "Attack" or not move then return { shape = "ball", radius = S.rest } end
	local frame, startup, active, recovery = view.moveFrame or 0, move.startup, move.active, move.recovery
	if frame <= startup then
		return { shape = "ball", radius = S.rest + (S.dense - S.rest) * smooth(frame / math.max(1, startup)) }
	elseif frame <= startup + active then
		local since = frame - startup
		return { shape = "ball", radius = S.impact - (S.impact - S.rest * 1.2) * smooth((since - 2) / math.max(1, active)) }
	end
	local u = (frame - startup - active) / math.max(1, recovery)
	return { shape = "ball", radius = S.rest * 1.2 + (S.rest - S.rest * 1.2) * smooth(u) }
end

return OrbFlight
