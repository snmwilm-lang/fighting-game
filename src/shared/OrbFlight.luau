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
-- (0.23.5, Wilhem: « évite quand ça rentre dans ses bras, quand elle est trop collée au perso »:
-- it floats a little above and ahead of her hands, never on them, as the camera sees her;
-- OrbFlight.avoid then keeps it off her posed body, frame by frame)
OrbFlight.ORBIT = { fwd = 1.75, height = 4.35, side = 0.9, radius = 0.1, period = 2.6, bob = 0.12 }
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
OrbFlight.HAND = { fwd = 1.45, side = 1.35 } -- (just ahead of her fist, never in it)

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
OrbFlight.AHEAD = 0.4
function OrbFlight.strike(move, role)
	local box = move and move.hitbox
	if not box then return { fwd = 1.8, up = 3.4, side = 0.3 } end
	local path = OrbFlight.path(role)
	local up = if path == "low" or path == "reap" then 0.8
		elseif FLOOR[path] then math.clamp(box.low + 0.8, 0.8, 1.6)
		else math.clamp((box.low + box.high) / 2, 0.8, 5.5)
	-- (0.23.5: a little past the end of the reach, so the swelling sphere bursts on the
	-- opponent, ahead of her fist, not round it)
	return { fwd = math.max(1.4, box.far + OrbFlight.AHEAD), up = up, side = 0.3 }
end

-- Where the matter waits, gathered, at the end of the wind-up (just before the blow).
local function windUp(path, hit, hand)
	if path == "low" then return { fwd = 1.35, up = 1.1, side = 1.3 } -- (down before her shin)
	elseif path == "reap" then return { fwd = -1.1, up = 1.1, side = 0.9 } -- (low, behind her)
	elseif path == "rise" then return { fwd = 1.5, up = 0.8, side = 1.2 } -- (at the floor before her)
	elseif path == "slam" then return { fwd = 0.7, up = 6.6, side = 0.6 } -- (raised over her head)
	elseif path == "dive" then return { fwd = 0.2, up = 5.2, side = 0.9 } -- (above her)
	elseif path == "mark" or path == "spear" then return { fwd = 1.5, up = hand.up, side = 1.2 }
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
		-- (swung over her shoulder and clear behind her: never through her, nor over her on screen)
		add(math.max(1, gathered * 0.25), { fwd = 0.6, up = 5.6, side = 1.6 }) -- (over her shoulder)
		add(math.max(2, math.floor(gathered * 0.55)), { fwd = -1.7, up = 4.9, side = 1.2 }, { stop = true }) -- (clear behind her)
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
	-- back to her hand, then to its orbit: first swinging out toward the camera, round her
	-- arm as she pulls it back (straight back, it came home through her fist)
	local back = keys[#keys].t
	local last = keys[#keys].p
	add(back + (total - back) * 0.22, { fwd = math.max(hand.fwd + 0.4, last.fwd - 0.5), up = math.max(last.up, 1.2) + 0.35,
		side = math.max(hand.side, last.side) + 0.45 })
	add(back + (total - back) * 0.55, hand)
	add(total, orbit, { stop = true })
	return keys
end

-- `from`: where the matter was when this move began (OrbFlight.clock keeps it), if known.
function OrbFlight.offset(view, move, role, time, from)
	local state = view.state
	local crouching = state == "Crouching" or state == "CrouchBlocking" or state == "CrouchBlockstun"
	local orbit = OrbFlight.orbit(time, crouching)
	if GUARD[state] then
		-- (the disc, before her, clear of her raised arms; Wilhem: « la garde est trop haute,
		-- descends-la un peu »: centred on her chest, not her face; then, with an in-game capture:
		-- « descends le bouclier »: lower still, its top under her chin, its centre at her belt)
		return { fwd = 2.1, up = if crouching then 1.45 else 2.2, side = 0.4 }
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

-- HOW IT LOOKS (the client draws it; pure so it is tested). A black sphere with a corona of
-- her ki colour round it (an eclipse, in small), a glint of light, three motes of ki circling
-- it, a light, wisps of shadow drifting off it. Returns, for her view at `time` (`form` from
-- OrbFlight.form):
--   halo   the corona's size (x the sphere's radius; 0 = none), haloT its transparency;
--   light  the light's brightness;  sats  the motes' orbit (x radius; 0 = none), spin (rad/s);
--   wisps  the shadow drifting off it (0..1).
-- At rest it breathes, calm; gathered for a blow it burns brighter, the motes drawn in and
-- spinning fast; on the impact the corona flares and the motes are flung out; guarding, the
-- disc has its own rim; hurt, it gutters; at the K.O., shadow rises off the puddle.
OrbFlight.LOOK = {
	rest = { halo = 1.24, haloT = 0.8, light = 0.7, sats = 2.1, spin = 1.6, wisps = 0.45 },
	gather = { halo = 1.13, haloT = 0.6, light = 1.6, sats = 1.25, spin = 8, wisps = 1 },
	impact = { halo = 1.45, haloT = 0.5, light = 4.5, sats = 2.8, spin = 4, wisps = 1 },
	guard = { halo = 0, haloT = 1, light = 1.2, sats = 0, spin = 0, wisps = 0.3 },
	hurt = { halo = 1.2, haloT = 0.9, light = 0.3, sats = 2.5, spin = 12, wisps = 0.2 },
	puddle = { halo = 0, haloT = 1, light = 0.35, sats = 0, spin = 0, wisps = 1 },
	gone = { halo = 0, haloT = 1, light = 0, sats = 0, spin = 0, wisps = 0 },
}
local function blend(a, b, t)
	local out = {}
	for k, v in a do out[k] = v + (b[k] - v) * t end
	return out
end
function OrbFlight.look(view, move, role, time, form)
	local L = OrbFlight.LOOK
	local state = view.state
	time = time or 0
	if form and form.radius < 0.05 then return blend(L.gone, L.gone, 0) end
	if GUARD[state] then return blend(L.guard, L.guard, 0) end
	if state == "KO" then return blend(L.puddle, L.puddle, 0) end
	if HURT[state] then
		local out = blend(L.hurt, L.hurt, 0)
		out.light *= 0.6 + 0.4 * math.abs(math.sin(time * 23)) -- (it gutters)
		return out
	end
	local breath = math.sin(time * 2.4)
	local rest = blend(L.rest, L.rest, 0)
	rest.halo += breath * 0.06
	rest.haloT -= breath * 0.04
	if state ~= "Attack" or not move then return rest end
	local frame, startup, active, recovery = view.moveFrame or 0, move.startup, move.active, move.recovery
	if frame <= startup then
		return blend(rest, L.gather, smooth(frame / math.max(1, startup) * 1.5))
	elseif frame <= startup + active then
		-- (the flare, at its brightest on the contact, then dying down)
		local since = frame - startup
		return blend(L.impact, L.gather, smooth((since - 1) / math.max(2, active + 2)))
	end
	return blend(L.gather, rest, smooth((frame - startup - active) / math.max(1, recovery * 0.7)))
end

-- KEEP OFF HER BODY. `center` = {x, y, z} (world), the sphere's `radius`, her body's parts as
-- boxes { cx, cy, cz, Xx, Xy, Xz, Yx, Yy, Yz, Zx, Zy, Zz, hx, hy, hz } (centre, unit axes, half
-- sizes: the client reads them off her rig every frame, the tests off the posed skeleton).
-- Pushes the centre out of every box, `margin` studs clear of its surface (along the shortest
-- way out), a few passes so that pushing it off one part does not leave it in another.
-- Returns the new centre, and how far it was pushed.
OrbFlight.CLEARANCE = 0.3
OrbFlight.SCREEN_CLEARANCE = 0.15 -- (on screen: a gap between the sphere and her silhouette)
-- How clear a point is of every box (the smallest distance to their surfaces, minus `need`).
local function clearance(x, y, z, boxes, need)
	local worst = math.huge
	for _, b in boxes do
		local dx, dy, dz = x - b[1], y - b[2], z - b[3]
		local lx = math.abs(dx * b[4] + dy * b[5] + dz * b[6]) - b[13]
		local ly = math.abs(dx * b[7] + dy * b[8] + dz * b[9]) - b[14]
		local lz = math.abs(dx * b[10] + dy * b[11] + dz * b[12]) - b[15]
		local d = math.sqrt(math.max(lx, 0) ^ 2 + math.max(ly, 0) ^ 2 + math.max(lz, 0) ^ 2) + math.min(math.max(lx, ly, lz), 0)
		worst = math.min(worst, d - need)
	end
	return worst
end
OrbFlight.clearance = clearance

-- The same, AS SEEN BY THE CAMERA (it looks straight along -Z: the screen is the X-Y plane).
-- In front of her arm, toward the camera, the sphere is clear of it in space but looks stuck
-- in it on screen: what Wilhem sees. Each part is taken as a capsule (its long axis, as wide
-- as its thickest side), drawn flat on the screen.
local function screenClearance(x, y, boxes, need)
	local worst = math.huge
	for _, b in boxes do
		local hx, hy, hz = b[13], b[14], b[15]
		local ax, ay, h, r
		-- (the capsule round the box: its section's corners inside it)
		if hx >= hy and hx >= hz then
			ax, ay, h, r = b[4], b[5], hx, math.sqrt(hy * hy + hz * hz)
		elseif hy >= hz then
			ax, ay, h, r = b[7], b[8], hy, math.sqrt(hx * hx + hz * hz)
		else
			ax, ay, h, r = b[10], b[11], hz, math.sqrt(hx * hx + hy * hy)
		end
		local half = math.max(0, h - r)
		local x0, y0 = b[1] - ax * half, b[2] - ay * half
		local sx, sy = ax * half * 2, ay * half * 2
		local l2 = sx * sx + sy * sy
		local u = if l2 > 1e-8 then math.clamp(((x - x0) * sx + (y - y0) * sy) / l2, 0, 1) else 0
		local dx, dy = x - (x0 + sx * u), y - (y0 + sy * u)
		worst = math.min(worst, math.sqrt(dx * dx + dy * dy) - r - need)
	end
	return worst
end
OrbFlight.screenClearance = screenClearance

-- `dir` (a unit vector, optional): pushed out along it only, as little as needed. A push that
-- always goes the same way slides smoothly as her limbs move (the shortest way out may flip
-- from one side of an arm to the other between two frames: a jolt). In a strike: forward, so
-- the sphere rides ahead of her fist; else toward the camera.
-- `screen`: clear of her as the camera sees her (`screenClearance`), pushed in the screen's
-- plane (along `dir`'s X and Y).
function OrbFlight.avoid(center, radius, boxes, margin, dir, screen)
	local x, y, z = center[1], center[2], center[3]
	local need = radius + (margin or OrbFlight.CLEARANCE)
	if screen then
		local d = dir or { 0, 1, 0 }
		local dx, dy = d[1], d[2]
		local l = math.sqrt(dx * dx + dy * dy)
		if l < 1e-3 then dx, dy, l = 0, 1, 1 end
		dx, dy = dx / l, dy / l
		if screenClearance(x, y, boxes, need) >= 0 then return { x, y, z }, 0 end
		local low, high, t = 0, nil, 0
		while t < 5 do
			t += 0.1
			if screenClearance(x + dx * t, y + dy * t, boxes, need) >= 0 then
				low, high = t - 0.1, t
				break
			end
		end
		if not high then return { x + dx * 5, y + dy * 5, z }, 5 end
		for _ = 1, 7 do
			local mid = (low + high) / 2
			if screenClearance(x + dx * mid, y + dy * mid, boxes, need) >= 0 then high = mid else low = mid end
		end
		return { x + dx * high, y + dy * high, z }, high
	end
	if dir then
		if clearance(x, y, z, boxes, need) >= 0 then return { x, y, z }, 0 end
		local low, high = 0, nil
		local t = 0
		while t < 4 do
			t += 0.1
			if clearance(x + dir[1] * t, y + dir[2] * t, z + dir[3] * t, boxes, need) >= 0 then
				low, high = t - 0.1, t
				break
			end
		end
		if high then
			for _ = 1, 7 do
				local mid = (low + high) / 2
				if clearance(x + dir[1] * mid, y + dir[2] * mid, z + dir[3] * mid, boxes, need) >= 0 then high = mid else low = mid end
			end
			return { x + dir[1] * high, y + dir[2] * high, z + dir[3] * high }, high
		end
		-- (no way out along it: the shortest way, below)
	end
	local moved = 0
	for _ = 1, 3 do
		local pushed = false
		for _, b in boxes do
			local dx, dy, dz = x - b[1], y - b[2], z - b[3]
			-- (in the box's own axes)
			local lx = dx * b[4] + dy * b[5] + dz * b[6]
			local ly = dx * b[7] + dy * b[8] + dz * b[9]
			local lz = dx * b[10] + dy * b[11] + dz * b[12]
			local hx, hy, hz = b[13], b[14], b[15]
			-- quick out: too far from this box to touch it
			if math.abs(lx) < hx + need and math.abs(ly) < hy + need and math.abs(lz) < hz + need then
				local qx, qy, qz = math.clamp(lx, -hx, hx), math.clamp(ly, -hy, hy), math.clamp(lz, -hz, hz)
				local ox, oy, oz = lx - qx, ly - qy, lz - qz
				local d = math.sqrt(ox * ox + oy * oy + oz * oz)
				local nx, ny, nz
				if d > 1e-4 then
					if d < need then
						local k = need / d
						nx, ny, nz = qx + ox * k, qy + oy * k, qz + oz * k
					end
				else
					-- (its centre inside the part: out through the nearest face)
					local px, py, pz = hx - math.abs(lx), hy - math.abs(ly), hz - math.abs(lz)
					nx, ny, nz = lx, ly, lz
					if px <= py and px <= pz then
						nx = (if lx >= 0 then 1 else -1) * (hx + need)
					elseif py <= pz then
						ny = (if ly >= 0 then 1 else -1) * (hy + need)
					else
						nz = (if lz >= 0 then 1 else -1) * (hz + need)
					end
				end
				if nx then
					local wx = b[1] + nx * b[4] + ny * b[7] + nz * b[10]
					local wy = b[2] + nx * b[5] + ny * b[8] + nz * b[11]
					local wz = b[3] + nx * b[6] + ny * b[9] + nz * b[12]
					moved += math.sqrt((wx - x) ^ 2 + (wy - y) ^ 2 + (wz - z) ^ 2)
					x, y, z = wx, wy, wz
					pushed = true
				end
			end
		end
		if not pushed then break end
	end
	return { x, y, z }, moved
end

-- The way the matter is pushed off her body, on the screen: forward in a strike when it is
-- ahead of her (it rides ahead of her fist), else up and forward (it floats over her hands).
function OrbFlight.avoidDirection(state, facing, o)
	local strike = state == "Attack" and (o == nil or o.fwd >= 1.2) -- (ahead of her: it rides ahead of the fist)
	local x, y = if strike then facing * 0.95 else facing * 0.45, if strike then 0.3 else 0.9
	local l = math.sqrt(x * x + y * y)
	return { x / l, y / l, 0 }
end

-- The spring trails its target by about 2ζ/ω (a tight one: 2 ticks). In a strike its target is
-- therefore taken that far AHEAD on the path: followed, the matter is on time (in step with
-- her fist, not 2 studs behind it, in it), and still smoothed. Not past the move's end; in a
-- hit-stop the clock waits, and the target with it, still ahead.
OrbFlight.LEAD = 3
function OrbFlight.leadFrame(view, move)
	local frame = view.moveFrame or 0
	if view.state ~= "Attack" or not move then return frame end
	return math.min(frame + OrbFlight.LEAD, move.startup + move.active + move.recovery)
end

-- How exactly a strike's frame is drawn on its path (0 = by the spring, 1 = on the path):
-- only for the blow itself, from the end of the wind-up to the end of the contact (there a
-- spring trails 2 studs behind, into her fist), coming in and going out smoothly; the
-- wind-up and the return stay with the spring, which smooths a chained blow and her limbs.
function OrbFlight.exactness(view, move)
	if view.state ~= "Attack" or not move then return 0 end
	local frame = view.moveFrame or 0
	local open = move.startup - 3
	local close = move.startup + move.active + math.max(2, move.recovery * 0.25)
	return smooth((frame - open) / 2) * (1 - smooth((frame - close) / 3))
end

-- WHERE IT IS DRAWN, the whole client pipeline (pure: the client and the tests run the same):
-- `target` = {x, y, z}, where `offset` puts it (world); `body` = {x, y}, her feet as drawn;
-- `boxes`: her posed parts (see `avoid`); `radius`: the sphere's.
--  1. the target is kept off her body as the camera sees it (`avoid`, `screen`);
--  2. the spring (`follow`) runs RELATIVE TO HER BODY: it carries the matter along with her
--     steps, dashes and jumps (in world space it trailed 1.6 studs behind a walk, into her
--     back and arms), and only smooths its own motion round her; in a strike it is drawn on
--     the path itself (`tight` = 1);
--  3. what is drawn is kept off her body too, closer, along `dir`;
-- `s` = {} kept per fighter. Returns the place {x, y, z}; `s.speed` its speed (studs/s) and
-- `s.velocity`, `s.snapped` (a teleport: the client re-forms it).
-- `dir`: the way it is pushed off her body (`avoidDirection`).
OrbFlight.PUSH_IN, OrbFlight.PUSH_OUT = 40, 6
-- `exact` (0..1): how much it is drawn on the path itself rather than by the spring (in a
-- strike, once its first frames have passed: `exactness`).
function OrbFlight.place(s, target, dt, tight, body, boxes, radius, dir, exact)
	local want = target
	if boxes then want = OrbFlight.avoid(target, radius, boxes, OrbFlight.SCREEN_CLEARANCE, dir, true) end
	local rel = { want[1] - body[1], want[2] - body[2], want[3] }
	if not s.p then s.p, s.v = { rel[1], rel[2], rel[3] }, { 0, 0, 0 } end
	OrbFlight.follow(s, rel, dt, tight, body)
	-- In a strike the path is already one smooth curve: drawn exactly on it (a spring, even a
	-- tight one, trailed 2 studs behind a blow: into her own fist). `tight` blends from the
	-- spring to the exact path, and the spring is kept in step so that leaving the strike is
	-- smooth too.
	exact = math.clamp(exact or 0, 0, 1)
	local shown = s.p
	if exact > 0 then
		shown = { s.p[1] + (rel[1] - s.p[1]) * exact, s.p[2] + (rel[2] - s.p[2]) * exact, s.p[3] + (rel[3] - s.p[3]) * exact }
		if exact > 0.97 and s.rel and dt > 0 and not s.snapped then
			s.p = { rel[1], rel[2], rel[3] }
			s.v = { (rel[1] - s.rel[1]) / dt, (rel[2] - s.rel[2]) / dt, (rel[3] - s.rel[3]) / dt }
		end
	end
	s.rel = rel
	local at = { body[1] + shown[1], body[2] + shown[2], shown[3] }
	-- 3. what is drawn is kept off her body too (closer: the spring may lag, never into her),
	-- pushed the same fixed way; the push comes in fast and leaves slowly, so it slides off her
	-- limbs (posed 60 times a second) without a jolt
	if boxes and dir then
		local _, need = OrbFlight.avoid(at, radius, boxes, OrbFlight.SCREEN_CLEARANCE * 0.4, dir, true)
		local push = s.push or 0
		local rate = if need > push then OrbFlight.PUSH_IN else OrbFlight.PUSH_OUT
		push += (need - push) * (1 - math.exp(-dt * rate))
		s.push = push
		at = { at[1] + dir[1] * push, at[2] + dir[2] * push, at[3] + dir[3] * push }
	end
	if s.drawn and dt > 0 then
		local v = { (at[1] - s.drawn[1]) / dt, (at[2] - s.drawn[2]) / dt, (at[3] - s.drawn[3]) / dt }
		-- (a teleport carries it at once: not a speed)
		if s.snapped then v = { 0, 0, 0 } end
		s.velocity, s.speed = v, math.sqrt(v[1] ^ 2 + v[2] ^ 2 + v[3] ^ 2)
	else
		s.velocity, s.speed = { 0, 0, 0 }, 0
	end
	s.drawn = at
	return at
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
