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

return KiBall
