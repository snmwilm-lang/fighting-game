--[[
	KAI's KIKOHO, his ball of ki (pure: no Roblox API, no require), done the way DAICHA's sphere
	is (OrbFlight; Wilhem: « utilise la même technique qu'avec la boule de DAICHA »): one ball,
	never a new one.
	  wind-up:  it forms between his palms, cupped at his rear hip, and grows to the release
	            (`charge`: its white core and its shell of ki, both easing in);
	  release:  the palms push forward and the SAME ball leaves them: the client draws the
	            projectile from where the ball was and eases it onto the real shot (`launch`),
	            so it flies out of his hands instead of appearing ahead of them;
	  flight:   the shot itself (the simulation's projectile), drawn by the client.
	The client hangs the ball between his two hands every frame (the posed rig); the tests do
	the same with the Animator (Animation: KIKOHO).
]]
local KiBall = {}

-- KAI's moves that form the ball (ASURA fights with KAI's moves: his too).
KiBall.MOVES = { KiBlast = true }

-- Sizes (studs): the white core and the shell of ki round it, at the start and at the release.
KiBall.CORE = { 0.2, 0.62 }
KiBall.SHELL = { 0.45, 1.35 }

-- Seconds the drawn shot takes to join the real one after the release.
KiBall.LAUNCH = 0.14

local function smooth(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- The ball while he winds up: nil outside the wind-up of a ki ball move. `move` is the move's
-- data (startup). t: 0 at the first frame, 1 at the release.
function KiBall.charge(view, move)
	if view.state ~= "Attack" or not KiBall.MOVES[view.move] or not move then return nil end
	local frame = view.moveFrame or 0
	-- (up to the release frame itself: the shot appears the frame after, from right there)
	if frame > move.startup then return nil end
	local t = math.clamp(frame / math.max(1, move.startup), 0, 1)
	local k = smooth(t)
	return {
		t = t,
		core = KiBall.CORE[1] + (KiBall.CORE[2] - KiBall.CORE[1]) * k,
		shell = KiBall.SHELL[1] + (KiBall.SHELL[2] - KiBall.SHELL[1]) * k,
	}
end

-- Where the drawn shot is `age` seconds after the release: from the ball's last place between
-- his palms (`from`) onto the real shot (`to`, where the simulation has it now), easing out
-- (fast off the palms, settling on the shot). Points are { x, y, z }.
function KiBall.launch(from, to, age)
	local k = math.clamp(age / KiBall.LAUNCH, 0, 1)
	k = 1 - (1 - k) ^ 3
	return { from[1] + (to[1] - from[1]) * k, from[2] + (to[2] - from[2]) * k, from[3] + (to[3] - from[3]) * k }
end

-- The ball's look (Wilhem's drawing): a white-hot core; loops of ki wound round it, each in its
-- own plane, never quite round, turning fast (one inside the other, the outer ones wider);
-- sparks flickering round the core, short dashes; a haze round it all. Every size is a share
-- of the ball's radius. The client draws it (EffectsController:kiBallDraw: the ball between his
-- palms, the shot, the cinematics' "kiball"), the storyboards too.
KiBall.LOOPS = {
	{ size = 0.62, tilt = 0.35, turn = 0.9, spin = 7.5, wobble = 0.12 },
	{ size = 0.86, tilt = 1.25, turn = -0.6, spin = -9, wobble = 0.1 },
	{ size = 1.08, tilt = 2.1, turn = 0.3, spin = 11, wobble = 0.14 },
}
KiBall.SPARKS = 9

-- Loop `i`'s plane at `time`: its two tilts (radians round X and Y) and its turn round its own
-- axis (radians).
function KiBall.loopPlane(i, time)
	local l = KiBall.LOOPS[i]
	return l.tilt + 0.35 * math.sin(time * 1.3 + i * 2.1), l.turn + time * 0.8 * (if i % 2 == 0 then -1 else 1), time * l.spin
end

-- The normal of loop `i`'s plane at `time` (its circle lies in local X-Z, tilted round X, then
-- turned round Y).
function KiBall.loopNormal(i, time)
	local rx, ry = KiBall.loopPlane(i, time)
	return math.sin(rx) * math.sin(ry), math.cos(rx), math.sin(rx) * math.cos(ry)
end

-- Loop `i`'s radius (share of the ball's) at the angle `a` round it, at `time`: never round.
function KiBall.loopRadius(i, a, time)
	local l = KiBall.LOOPS[i]
	return l.size * (1 + l.wobble * math.sin(3 * a + time * 5 + i * 1.7) + 0.5 * l.wobble * math.sin(5 * a - time * 7 + i))
end

-- A spark's place (x, y, z: shares of the radius, round the centre) and its length, `k` of
-- KiBall.SPARKS, at `time`: each lives 1/12 s, then flickers elsewhere.
local function hash(n)
	local x = math.sin(n * 127.1 + 311.7) * 43758.5453
	return x - math.floor(x)
end
function KiBall.spark(k, time)
	local life = math.floor(time * 12 + k * 0.37)
	local seed = k * 13.7 + life * 7.3
	local theta = hash(seed) * math.pi * 2
	local z = hash(seed + 1.1) * 2 - 1
	local r = 0.38 + 0.7 * hash(seed + 2.3)
	local ring = math.sqrt(math.max(0, 1 - z * z))
	return math.cos(theta) * ring * r, z * r, math.sin(theta) * ring * r, 0.12 + 0.2 * hash(seed + 3.9)
end

-- The KIKOHO in flight, in 3D (Wilhem: « une belle boule 3D », fluid like the wave): behind the
-- ball a comet's tail of ki, as wide as the ball where it leaves it and thinning to nothing,
-- rippling, the ripples flowing back from the ball; two strands of light wound round the tail
-- in helices, closing on the ball. At `u` (0 at the ball, 1 at the tail's end) and `time`: the
-- tail's radius (a share of the ball's) and the sway of its axis (a share of the ball's radius).
KiBall.TAIL = { length = 4.2, strands = 2 } -- (its length: in the ball's radii)
function KiBall.tail(u, time)
	local tau = math.pi * 2
	local taper = (1 - math.clamp(u, 0, 1)) ^ 0.8
	local ripple = 1 + 0.12 * math.sin(tau * (u * 3 - time * 2.2)) + 0.06 * math.sin(tau * (u * 7 - time * 3.1) + 1.1)
	local sway = 0.18 * u * math.sin(tau * (u * 1.6 - time * 1.8) + 0.4)
	return 0.92 * taper * ripple, sway
end
-- Strand `i` of the tail at `u`: its angle round the tail's axis (radians) and its distance from
-- it (a share of the ball's radius): just outside the tail, closing on it toward its end.
function KiBall.tailStrand(i, u, time)
	local tau = math.pi * 2
	local angle = (i - 1) / KiBall.TAIL.strands * tau + (u * 1.5 - time * 2.5) * tau
	local radius = KiBall.tail(u, time)
	return angle, radius * 1.12 + 0.04
end

-- His wave (KAIEN RUSH's KAIENHA, the MAXIMUM KAIENHA; Wilhem's drawing): thin out of his
-- palms, it swells within its first tenth and widens a little to its end; its edges ripple,
-- the bumps flowing away from him, never the same above and below (it meanders a little round
-- its axis). At `u` (0 at his palms, 1 at its end) and `time` (seconds): the radius as a share
-- of the wave's own, and the sway of its axis (a share of the radius, across it).
KiBall.BEAM = { start = 0.45, swell = 0.12, widen = 0.18 }
function KiBall.beam(u, time)
	local b = KiBall.BEAM
	local tau = math.pi * 2
	local inn = smooth(u / b.swell)
	local taper = b.start + (1 - b.start) * inn
	local ripple = 1 + 0.13 * math.sin(tau * (u * 5 - time * 1.6)) + 0.07 * math.sin(tau * (u * 11 - time * 2.4) + 1.3)
		+ 0.04 * math.sin(tau * (u * 19 - time * 3.3) + 2.1)
	local sway = 0.08 * math.sin(tau * (u * 3.5 - time * 1.2) + 0.7) + 0.04 * math.sin(tau * (u * 8 - time * 2) + 2.4)
	return taper * (1 + b.widen * u) * ripple, sway * inn
end

-- The wave in 3D (Wilhem: « un beau modèle 3D du rayon, fluide »): round its rippling body,
-- three strands of light wound in helices, twisting along it and flowing away from his palms,
-- just outside the body (a ray to its end, no ball: Wilhem); at his palms a mouth, a flare.
-- `strand` gives strand `i` at `u` and `time`: its angle round the axis
-- (radians) and its distance from it (a share of the wave's radius).
KiBall.STRANDS = 3
KiBall.TURNS = 2.2 -- (turns of a strand along the whole wave)
KiBall.MOUTH = 1.6 -- (the flare at his palms)
function KiBall.strand(i, u, time)
	local tau = math.pi * 2
	local angle = (i - 1) / KiBall.STRANDS * tau + (u * KiBall.TURNS - time * 1.4) * tau
	local scale = KiBall.beam(u, time)
	return angle, scale * (1.08 + 0.12 * math.sin(tau * (u * 4 - time * 2) + i))
end

return KiBall
