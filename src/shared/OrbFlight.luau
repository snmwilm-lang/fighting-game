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

--[[
	FLUIDITY. A strike's path is a list of keys { t = frame, p = place } joined by one smooth
	curve (cubic Hermite, Catmull-Rom tangents: the speed never jumps from one key to the
	next), evaluated at any fractional frame (the client extrapolates the frame between two
	snapshots). A key may set its tangent: `stop` (the matter pauses there: the gathered
	wind-up, the end), or `drive` (it arrives at full speed: the impact, followed through a
	little past the target and back, at most `follow` studs).
]]
OrbFlight.FOLLOW_THROUGH = 0.35

local function sub(a, b) return { fwd = a.fwd - b.fwd, up = a.up - b.up, side = a.side - b.side } end
local function scale(a, k) return { fwd = a.fwd * k, up = a.up * k, side = a.side * k } end
local function length(a) return math.sqrt(a.fwd * a.fwd + a.up * a.up + a.side * a.side) end
local ZERO = { fwd = 0, up = 0, side = 0 }

-- The tangents (studs per frame) of every key, then the place at frame `t`.
function OrbFlight.curve(keys, t)
	local n = #keys
	if t <= keys[1].t then return keys[1].p end
	if t >= keys[n].t then return keys[n].p end
	local i = 1
	while keys[i + 1].t < t do i += 1 end
	local function tangent(k)
		local key = keys[k]
		if key.m then return key.m end
		if key.stop or k == 1 or k == n then return ZERO end
		local m = scale(sub(keys[k + 1].p, keys[k - 1].p), 1 / math.max(1e-3, keys[k + 1].t - keys[k - 1].t))
		if key.drive then
			-- (into the target at the speed it came, but never more than `follow` past it)
			local before = scale(sub(key.p, keys[k - 1].p), 1 / math.max(1e-3, key.t - keys[k - 1].t))
			local after = keys[k + 1].t - key.t
			local speed = length(before)
			local most = (key.follow or OrbFlight.FOLLOW_THROUGH) / (0.148 * math.max(1, after))
			m = scale(before, if speed > most then most / speed else 1)
		end
		return m
	end
	local k0, k1 = keys[i], keys[i + 1]
	local h = k1.t - k0.t
	local u = (t - k0.t) / h
	local m0, m1 = scale(tangent(i), h), scale(tangent(i + 1), h)
	local u2, u3 = u * u, u * u * u
	local h00, h10, h01, h11 = 2 * u3 - 3 * u2 + 1, u3 - 2 * u2 + u, -2 * u3 + 3 * u2, u3 - u2
	local p0, p1 = k0.p, k1.p
	return {
		fwd = h00 * p0.fwd + h10 * m0.fwd + h01 * p1.fwd + h11 * m1.fwd,
		up = h00 * p0.up + h10 * m0.up + h01 * p1.up + h11 * m1.up,
		side = h00 * p0.side + h10 * m0.side + h01 * p1.side + h11 * m1.side,
	}
end

-- The keys of a strike's path (frames: 0 = start, contact = startup + 1, total = the end).
function OrbFlight.keys(path, move, orbit, role, from)
	local startup, active, recovery = move.startup, move.active, move.recovery
	local hit = OrbFlight.strike(move, role)
	local hand = OrbFlight.hand(hit)
	local ready = windUp(path, hit, hand)
	local contact = startup + 1
	local lead = if path == "arc" or path == "slam" or path == "dive" or path == "spin" or path == "reap" then 4 else 2
	lead = math.min(lead, math.max(1, startup - 1))
	local gathered = contact - lead -- (the wind-up ends: gathered, a breath before the blow)
	local finish, total = startup + active, startup + active + recovery
	-- (from where the matter was when the move began: chained from another blow, it does not
	-- jump back to its rest point first)
	local keys = { { t = 0, p = from or orbit, stop = true } }
	local function add(t, p, extra)
		local key = { t = t, p = p }
		for k, v in extra or {} do key[k] = v end
		if t > keys[#keys].t + 1e-3 then table.insert(keys, key) end
	end
	-- the wind-up
	if path == "heavy" then
		-- M2: drawn back behind her (a short charge), then brought to her hand as she steps in.
		add(math.max(1, math.floor(gathered * 0.55)), { fwd = -0.9, up = 4.2, side = 1.0 }, { stop = true })
	elseif path == "spin" then
		-- One turn round her (toward the camera, behind her back, away), ending at her hand.
		local r = 1.5
		for k = 1, 5 do
			local a = k / 6 * math.pi * 2
			add(gathered * (0.15 + 0.75 * k / 6), { fwd = math.cos(a) * r, up = 3.4 + math.sin(a * 0.5) * 0.4, side = math.sin(a) * r })
		end
	end
	add(gathered, ready, { stop = path ~= "spin" })
	-- the blow
	if path == "arc" then
		add(contact - lead / 2, { fwd = (ready.fwd + hit.fwd) / 2, up = (ready.up + hit.up) / 2 + 1.3, side = (ready.side + hit.side) / 2 })
	elseif path == "reap" then
		add(contact - lead / 2, { fwd = (ready.fwd + hit.fwd) / 2, up = 0.7, side = (ready.side + hit.side) / 2 + 0.5 })
	elseif path == "spin" then
		add(contact - lead / 2, { fwd = (ready.fwd + hit.fwd) / 2, up = (ready.up + hit.up) / 2, side = (ready.side + hit.side) / 2 + 0.6 })
	elseif path == "slam" or path == "dive" then
		-- (slowly at first, then crushed down faster and faster)
		add(contact - lead / 2, { fwd = ready.fwd + (hit.fwd - ready.fwd) * 0.25, up = ready.up + (hit.up - ready.up) * 0.25,
			side = ready.side + (hit.side - ready.side) * 0.25 })
	end
	-- the contact and what it does while the blow is active
	if path == "rise" then
		add(contact, hit, { drive = true, follow = 0 })
		add(finish, { fwd = hit.fwd, up = hit.up + 2.4, side = hit.side }, { stop = true }) -- (on up through it)
	elseif path == "wrap" then
		add(contact, hit, { drive = true, follow = 0.1 })
		for frame = contact + 1, finish do
			local a = (frame - contact) * 1.9
			add(frame, { fwd = hit.fwd + math.cos(a) * 0.55 - 0.55, up = hit.up + math.sin(a) * 0.35, side = hit.side + math.sin(a) * 0.55 })
		end
	elseif path == "river" and move.hitInterval then
		-- From beat to beat: high, low, high... flowing over the target.
		add(contact, hit, { drive = true, follow = 0.2 })
		local b = 1
		while contact + b * move.hitInterval <= finish do
			add(contact + b * move.hitInterval, { fwd = hit.fwd - (b % 3) * 0.3, up = hit.up + (if b % 2 == 0 then 0 else 1.6),
				side = hit.side + (b % 2) * 0.3 })
			b += 1
		end
	elseif path == "crescent" then
		-- A wide half-circle over the target and back toward her (the eclipse's edge).
		add(contact, hit, { drive = true, follow = 0.1 })
		for k = 1, 4 do
			local a = k / 4 * math.pi
			add(contact + (finish - contact) * k / 4, { fwd = hit.fwd - 1.3 + math.cos(a) * 1.3, up = hit.up + math.sin(a) * 1.6, side = hit.side })
		end
	elseif path == "mark" then
		add(contact, hit, { stop = true })
		add(finish + recovery * 0.4, hit, { stop = true }) -- (it clings to the target a moment)
	elseif move.hitInterval then
		-- (multi-hit moves: it pulses into the target on every beat)
		add(contact, hit, { drive = true, follow = 0.15 })
		local b = 1
		while contact + b * move.hitInterval <= finish do
			local out = b % 2 == 1
			add(contact + b * move.hitInterval, if out then { fwd = hit.fwd - 0.4, up = hit.up + 0.3, side = hit.side } else hit)
			b += 1
		end
	else
		add(contact, hit, { drive = true })
		if finish > contact then add(finish, hit) end
	end
	-- back to her hand, then to its orbit
	local back = keys[#keys].t
	add(back + (total - back) * 0.45, hand)
	add(total, orbit, { stop = true })
	return keys
end

-- `from`: where the matter was when this move began (OrbFlight.clock keeps it), if known.
function OrbFlight.offset(view, move, role, time, from)
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
		return { fwd = -1.6 + math.sin(time * 17) * 0.15, up = 3.6 + math.sin(time * 13) * 0.15, side = 0.8 }
	elseif state == "Dashing" then
		return { fwd = -1.3, up = 4, side = 0.5 }
	elseif state ~= "Attack" or not move then
		return orbit
	end
	local frame = math.max(0, view.moveFrame or 0)
	local path = OrbFlight.path(role)
	if path == "vortex" then
		-- The vortex: the orb whirls round her, fast and wide (eased in from her hand and back).
		local angle = time * 12
		local r = 2.7
		local whirl = { fwd = math.cos(angle) * r, up = 3.2 + math.sin(time * 9) * 0.8, side = math.sin(angle) * r }
		local w = smooth(frame / 5) * (1 - smooth((frame - move.startup - move.active) / math.max(1, move.recovery * 0.7)))
		return OrbFlight.clear(mix(if from and frame < 5 then mix(from, orbit, smooth(frame / 5)) else orbit, whirl, w))
	end
	return OrbFlight.clear(OrbFlight.curve(OrbFlight.keys(path, move, orbit, role, from), frame))
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

-- The move's clock as the client draws it: the frame extrapolated between two snapshots, but
-- never back (a snapshot that brings a hit-stop the client had not foreseen would pull the
-- matter back a step: it waits there instead until the move catches up). A new move, or the
-- same one started again (its frame far back), starts the clock again, and keeps in `c.from`
-- where the matter was then (`last`: the offset drawn the frame before), so the new path
-- starts from there. `c` = {} kept per fighter.
function OrbFlight.clock(c, move, frame, last)
	if c.frame == nil or move ~= c.move or frame < c.frame - 3 then
		c.move, c.frame = move, frame
		c.from = if move and last then { fwd = last.fwd, up = last.up, side = last.side } else nil
	else
		c.frame = math.max(c.frame, frame)
	end
	return c.frame
end

-- The client's follow of the matter: a spring toward where `offset` puts it, so it lags a
-- little behind her steps and jumps, overshoots a touch and settles; tight in a strike, so it
-- still lands on the impact. `tight`: 0 (at rest) .. 1 (striking), eased by the client from one
-- to the other so the spring never changes all at once (true / false: 1 / 0).
-- `s` = { p = {x, y, z}, v = {x, y, z} } is updated in place; `target` = {x, y, z}.
-- `body` = {x, y}, her feet as drawn: when they move faster than anything but a teleport (the
-- blink through the opponent, TELEPORT: `teleport` studs/s), or the matter is too far, it is
-- there at once and `s.snapped` says so (the client re-forms it there, from nothing).
-- (Carrying it along with her own motion was tried: it trembles while she walks.)
OrbFlight.SPRING = { loose = 14, looseDamping = 0.72, tight = 55, tightDamping = 0.88, snap = 7, teleport = 90 }
function OrbFlight.follow(s, target, dt, tight, body)
	local k = OrbFlight.SPRING
	local a = if tight == true then 1 elseif type(tight) == "number" then math.clamp(tight, 0, 1) else 0
	-- (the stiffness blends on a log scale: halfway is a middling spring, not almost the tight one)
	local w = k.loose * (k.tight / k.loose) ^ a
	local z = k.looseDamping + (k.tightDamping - k.looseDamping) * a
	local p, v = s.p, s.v
	s.snapped = false
	local moved = false
	if body and s.body and dt > 0 then
		local bx, by = body[1] - s.body[1], body[2] - s.body[2]
		moved = math.sqrt(bx * bx + by * by) / dt > k.teleport
	end
	if body then s.body = { body[1], body[2] } end
	local dx, dy, dz = target[1] - p[1], target[2] - p[2], target[3] - p[3]
	if moved or dx * dx + dy * dy + dz * dz > k.snap * k.snap then
		s.p, s.v, s.snapped = { target[1], target[2], target[3] }, { 0, 0, 0 }, true
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
