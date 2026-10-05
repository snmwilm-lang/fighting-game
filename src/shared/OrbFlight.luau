--[[
	DAICHA's shadow matter (pure: no Roblox API, no require). Wilhem: « elle ne change pas de
	pouvoir selon l'action ; elle change la FORME de son pouvoir »: ATTACK = a round, dense
	sphere; DEFENCE = the same matter spread flat into a black disc before her.
	From her view (state, move and frame), the move's data, its role and the time, `offset`
	gives where the matter is, relative to her feet (`fwd` toward the side she faces, `up`,
	`side` toward the camera), and `form` its shape (a ball of `radius`, or a disc of `radius`
	and `thickness` facing the opponent). The client draws it there every frame; the pose
	sheets and storyboards draw it there; the tests check it.
	  idle, walking, jumping: a small sphere floating just before her hand, bobbing;
	  attacking: it leaves its orbit and gathers at her striking hand, compacting (smaller,
	             denser) during the wind-up; it drives out with the blow to the point of impact,
	             swelling on contact (the sphere IS the impact); then back to the hand, then
	             to its orbit;
	  guarding:  it flattens into a wide black disc, a shield before her (wider, rippling,
	             when a blow lands on it);
	  hit:       knocked back behind her, small, shaking; knocked down: dropped on the floor;
	             K.O.: spread on the floor, a puddle;
	  each blow: its own path (OrbFlight.PATH: straight, arc, low, heavy, rise, slam, dive,
	             spin, throw, blink, mark, wrap, river, spear, crescent, vortex).
	The client follows `offset` with a spring (`follow`): it lags behind her steps, overshoots
	a little and settles; and it draws the sphere longer along its flight when it goes fast.
]]
local OrbFlight = {}

-- (Wilhem's sheet: « l'orbe reste petite, proche de sa main ») at rest it floats just before
-- her hand, bobbing, a small circle.
OrbFlight.ORBIT = { fwd = 0.95, height = 3.4, side = 0.7, radius = 0.1, period = 2.6, bob = 0.12 }
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

-- Its place at rest at `time`, before her hand (lower when she crouches).
function OrbFlight.orbit(time, crouching)
	local o = OrbFlight.ORBIT
	local angle = time / o.period * math.pi * 2
	return {
		fwd = o.fwd + math.cos(angle) * o.radius,
		up = (if crouching then o.height - 1.2 else o.height) + math.sin(time * 3.1) * o.bob,
		side = o.side + math.sin(angle) * o.radius,
	}
end

-- Wilhem's sheet, her normals: M1 1 straight from the right hand, 2 a short arc, 3 low, the
-- orb scraping the floor, 4 close and pushing; M2 (Smash) drawn back first, then driven in.
-- Every other blow has its own path too (« le système de boules »: the same sphere, moved
-- by her, never a new one), named by role:
--   straight  out with the fist (and the default);   arc     over the top, then down on it;
--   low       scraping the floor;                     heavy   drawn back behind her, then in;
--   reap      from behind her, low, round to the front (the reaper's swing);
--   rise      from the floor up through the target;  slam    raised high, then crushed down;
--   dive      in the air: from above, down before her;
--   spin      one turn round her body, then out;     throw   it IS the sphere she throws
--             (INVERTED SPHERE): gone when thrown, a new one forms in her hand;
--   blink     squeezed to a point as she vanishes, bursting out where she strikes;
--   mark      pressed on the target, it clings a moment, shrinking, before coming back;
--   wrap      it coils round the target (EMBRACE);   river   from beat to beat, up and down;
--   spear     stretched into an arrow;              crescent a wide half-circle (HALF ECLIPSE);
--   vortex    it whirls round her, fast and wide.
OrbFlight.PATH = {
	Jab = "straight", Kick = "straight", AirKick2 = "straight", KiChase = "straight", Finale = "straight",
	Cross = "arc", Elbow = "low", LowKick = "low", Sweep = "reap", Smash = "heavy",
	Uppercut = "rise", Hammer = "slam", ThunderHeel = "slam", AirKick = "dive", AirSmash = "dive",
	SpinKick = "spin", KiBlast = "throw", Rising = "blink", PalmStrike = "mark", BodyBlow = "wrap",
	KiFlurry = "river", DragonFist = "spear", CrescentMoon = "crescent",
	DragonTornado = "vortex", RisingWind = "vortex",
}
local FLOOR = { low = true, reap = true, slam = true, dive = true } -- (they strike along the floor)

function OrbFlight.path(role)
	return role and OrbFlight.PATH[role] or "straight"
end

-- The point a move strikes: the end of its reach, at the middle of its hitbox's height (the
-- blows along the floor: just over it).
function OrbFlight.strike(move, role)
	local box = move and move.hitbox
	if not box then return { fwd = 1.8, up = 3.4, side = 0.3 } end
	local path = OrbFlight.path(role)
	local up = if path == "low" or path == "reap" then 0.8
		elseif FLOOR[path] then math.clamp(box.low + 0.8, 0.8, 1.6)
		else math.clamp((box.low + box.high) / 2, 0.8, 5.5)
	return { fwd = math.max(1.4, box.far - 0.2), up = up, side = 0.3 }
end

-- Where the matter waits, gathered, at the end of the wind-up (just before the blow).
local function windUp(path, hit, hand)
	if path == "low" then return { fwd = 0.9, up = 1.2, side = 0.9 } -- (down by her shin)
	elseif path == "reap" then return { fwd = -1.1, up = 1.1, side = 0.9 } -- (low, behind her)
	elseif path == "rise" then return { fwd = 1.2, up = 0.8, side = 0.9 } -- (at the floor before her)
	elseif path == "slam" then return { fwd = 0.7, up = 6.6, side = 0.6 } -- (raised over her head)
	elseif path == "dive" then return { fwd = 0.2, up = 5.2, side = 0.9 } -- (above her)
	elseif path == "mark" or path == "spear" then return { fwd = 1.0, up = hand.up, side = 0.8 }
	end
	return hand
end

-- Its place while a strike `frame` of `move` runs (startup, active, recovery).
local function strikeAt(path, frame, move, orbit, time, role)
	local startup, active, recovery = move.startup, move.active, move.recovery
	local hit = OrbFlight.strike(move, role)
	local hand = OrbFlight.hand(hit)
	local ready = windUp(path, hit, hand)
	local lead = if path == "arc" or path == "slam" or path == "dive" or path == "spin" or path == "reap" then 4 else 2
	lead = math.min(lead, math.max(1, startup - 1))
	if frame <= startup - lead then
		local u = math.max(frame, 0) / math.max(1, startup - lead)
		if path == "heavy" then
			-- M2: drawn back behind her (a short charge), then brought to her hand as she steps in.
			local back = { fwd = -0.9, up = 4.2, side = 1.0 }
			if u <= 0.55 then return mix(orbit, back, smooth(u / 0.55 * 1.4)) end
			return mix(back, ready, smooth((u - 0.55) / 0.45))
		elseif path == "spin" then
			-- One turn round her (behind her back, away from the camera), ending at her hand.
			local a = smooth(u) * math.pi * 2
			local r = 1.45
			local o = { fwd = math.cos(a) * r, up = 3.4 + math.sin(a * 0.5) * 0.4, side = math.sin(a) * r }
			return mix(o, ready, smooth((u - 0.8) / 0.2))
		elseif path == "blink" then
			return mix(orbit, ready, smooth(u * 1.6)) -- (in her hand, squeezed: `form`)
		end
		return mix(orbit, ready, smooth(u * 1.6))
	elseif frame <= startup then
		-- The blow, from where it waited to the point of impact.
		local u = (frame - (startup - lead)) / lead
		local o = mix(ready, hit, if path == "slam" or path == "dive" then u * u else u) -- (crushing down: faster and faster)
		if path == "arc" then o.up += math.sin(u * math.pi) * 1.1
		elseif path == "reap" then o.side += math.sin(u * math.pi) * 0.5; o.up -= math.sin(u * math.pi) * 0.3
		elseif path == "spin" then o.side += math.sin(u * math.pi) * 0.6
		end
		return o
	elseif frame <= startup + active then
		local since = frame - startup - 1
		local u = since / math.max(1, active - 1)
		if path == "rise" then
			return { fwd = hit.fwd, up = hit.up + smooth(u) * 2.4, side = hit.side } -- (on up through it)
		elseif path == "wrap" then
			local a = since * 1.9
			return { fwd = hit.fwd + math.cos(a) * 0.55 - 0.55, up = hit.up + math.sin(a) * 0.35, side = hit.side + math.sin(a) * 0.55 }
		elseif path == "river" and move.hitInterval then
			-- From beat to beat: high, low, high... flowing over the target.
			local beat = math.floor(since / move.hitInterval)
			local w = (since % move.hitInterval) / move.hitInterval
			local function at(b) return { fwd = hit.fwd - (b % 3) * 0.3, up = hit.up + (if b % 2 == 0 then 0 else 1.6), side = hit.side + (b % 2) * 0.3 } end
			return mix(at(beat), at(beat + 1), smooth(w))
		elseif path == "crescent" then
			-- A wide half-circle over the target and back toward her (the eclipse's edge).
			local a = smooth(u) * math.pi
			return { fwd = hit.fwd - 1.3 + math.cos(a) * 1.3, up = hit.up + math.sin(a) * 1.6, side = hit.side }
		end
		-- (multi-hit moves: a little jolt on every beat)
		local beat = if move.hitInterval then math.floor(since / move.hitInterval) % 2 else 0
		return { fwd = hit.fwd - beat * 0.4, up = hit.up + beat * 0.3, side = hit.side }
	end
	-- Back to her hand, then to its orbit (the mark clings to the target a moment first).
	local u = (frame - startup - active) / math.max(1, recovery)
	local from = hit
	if path == "rise" then from = { fwd = hit.fwd, up = hit.up + 2.4, side = hit.side }
	elseif path == "crescent" then from = { fwd = hit.fwd - 2.6, up = hit.up, side = hit.side }
	elseif path == "mark" then
		if u < 0.4 then return hit end
		u = (u - 0.4) / 0.6
	end
	return mix(mix(from, hand, smooth(u * 2)), orbit, smooth((u - 0.5) / 0.5))
end

function OrbFlight.offset(view, move, role, time)
	local state = view.state
	local crouching = state == "Crouching" or state == "CrouchBlocking" or state == "CrouchBlockstun"
	local orbit = OrbFlight.orbit(time, crouching)
	if GUARD[state] then
		return { fwd = 1.5, up = if crouching then 2.3 else 3.5, side = 0.2 } -- (the disc, before her)
	elseif state == "KO" then
		return { fwd = 1.4, up = 0.06, side = 0.6 } -- (fallen, spread on the floor: a puddle)
	elseif state == "Knockdown" then
		return { fwd = 1.3, up = 0.6, side = 0.9 } -- (dropped by her, rolling on the floor)
	elseif HURT[state] then
		-- Knocked away from her by the blow, shaking.
		return { fwd = -1.6 + math.sin(time * 37) * 0.12, up = 3.6 + math.sin(time * 29) * 0.12, side = 0.8 }
	elseif state == "Dashing" then
		return { fwd = -1.3, up = 4, side = 0.5 }
	elseif state ~= "Attack" or not move then
		return orbit
	end
	local frame = view.moveFrame or 0
	local path = OrbFlight.path(role)
	if path == "vortex" then
		-- The vortex: the orb whirls round her, fast and wide.
		local angle = time * 12
		local r = 2.7
		return { fwd = math.cos(angle) * r, up = 3.2 + math.sin(time * 9) * 0.8, side = math.sin(angle) * r }
	end
	return OrbFlight.clear(strikeAt(path, frame, move, orbit, time, role))
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
-- Guard: a flat disc facing the opponent (pushed wider when a blow lands on it). K.O.: a
-- puddle on the floor. Returns { shape = "ball", radius, stretch } (`stretch`: drawn longer
-- along its flight, 1 = round), { shape = "disc", radius, thickness } or { shape = "puddle",
-- radius, thickness }. A radius of 0: no matter there (thrown away). `time`: the breath at rest.
OrbFlight.SIZE = { rest = 0.35, dense = 0.26, heavy = 0.55, impact = 0.7, disc = 1.8, thickness = 0.16, hurt = 0.3,
	puddle = 1.3, breath = 0.05 }
local STUN = { Blockstun = true, CrouchBlockstun = true }
function OrbFlight.form(view, move, role, time)
	local S = OrbFlight.SIZE
	local state = view.state
	if GUARD[state] then
		return { shape = "disc", radius = if STUN[state] then S.disc * 1.12 else S.disc, thickness = S.thickness }
	end
	if state == "KO" then return { shape = "puddle", radius = S.puddle, thickness = 0.08 } end
	if HURT[state] then return { shape = "ball", radius = S.hurt, stretch = 1 } end
	if state ~= "Attack" or not move then
		return { shape = "ball", radius = S.rest * (1 + S.breath * math.sin((time or 0) * 2.4)), stretch = 1 }
	end
	local frame, startup, active, recovery = view.moveFrame or 0, move.startup, move.active, move.recovery
	local path = OrbFlight.path(role)
	if path == "throw" then
		-- INVERTED SPHERE: it swells in her hand, leaves as the projectile, a new one forms.
		if frame < startup then return { shape = "ball", radius = S.rest + (S.heavy - S.rest) * smooth(frame / startup), stretch = 1 } end
		local u = (frame - startup - active) / math.max(1, recovery)
		return { shape = "ball", radius = S.rest * smooth(u), stretch = 1 }
	end
	if frame <= startup then
		local u = smooth(frame / math.max(1, startup))
		if path == "heavy" then -- (M2: it grows a little as she steps in)
			return { shape = "ball", radius = S.rest + (S.heavy - S.rest) * u, stretch = 1 }
		elseif path == "blink" then -- (squeezed to a point as she vanishes)
			return { shape = "ball", radius = S.rest + (0.06 - S.rest) * u, stretch = 1 }
		end
		return { shape = "ball", radius = S.rest + (S.dense - S.rest) * u, stretch = 1 }
	elseif frame <= startup + active then
		local since = frame - startup
		local peak = if path == "heavy" or path == "blink" or path == "slam" then S.impact * 1.3 else S.impact
		local stretch = if path == "spear" then 2.6 else 1
		if path == "spear" or path == "river" then peak = S.impact * 0.8 end -- (an arrow, a current: thinner, longer)
		return { shape = "ball", radius = peak - (peak - S.rest * 1.2) * smooth((since - 2) / math.max(1, active)), stretch = stretch }
	end
	local u = (frame - startup - active) / math.max(1, recovery)
	if path == "mark" and u < 0.4 then -- (the mark on the target, shrinking)
		return { shape = "ball", radius = S.rest * 1.2 * (1 - u), stretch = 1 }
	end
	return { shape = "ball", radius = S.rest * 1.2 + (S.rest - S.rest * 1.2) * smooth(u), stretch = 1 }
end

-- The client's follow of the matter: a spring toward where `offset` puts it, so it lags a
-- little behind her steps and jumps, overshoots and settles (stiff and tight in a strike, so
-- it still lands on the impact). `s` = { p = {x, y, z}, v = {x, y, z} } is updated in place;
-- `target` = {x, y, z}. Too far (a teleport, a blink): it is there at once.
OrbFlight.SPRING = { loose = 13, looseDamping = 0.55, tight = 60, tightDamping = 0.9, snap = 7 }
function OrbFlight.follow(s, target, dt, tight)
	local k = OrbFlight.SPRING
	local w, z = if tight then k.tight else k.loose, if tight then k.tightDamping else k.looseDamping
	local p, v = s.p, s.v
	local dx, dy, dz = target[1] - p[1], target[2] - p[2], target[3] - p[3]
	if dx * dx + dy * dy + dz * dz > k.snap * k.snap then
		s.p, s.v = { target[1], target[2], target[3] }, { 0, 0, 0 }
		return s
	end
	local steps = math.max(1, math.ceil(dt / (1 / 240)))
	local h = dt / steps
	for _ = 1, steps do
		for i = 1, 3 do
			v[i] += (w * w * (target[i] - p[i]) - 2 * z * w * v[i]) * h
			p[i] += v[i] * h
		end
	end
	return s
end

return OrbFlight
