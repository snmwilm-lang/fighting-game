--[[
	The held weapons, alive (pure Luau: no Roblox API, no require). Wilhem: « tous les persos
	avec des armes : le minimum de détails qu'il y a sur l'orbe de DAICHA doit être le minimum ».
	DAICHA's orb has a corona, a glint, motes, a light, wisps, ghosts, a ribbon, and it breathes
	at rest, burns when gathered, flares on the impact. Every held weapon now gets the same
	(EffectsController:weaponDressing draws it), each in its own element:
	  SHIN    the katana: a current of water, droplets off the blade, a glint running down it;
	  RAIJIN  the spear: lightning, sparks off the head, arcs crawling along the shaft;
	  YUKINA  the two fans: frost, snow motes drifting from the leaves;
	  KAZAN   the two claws: embers rising off the blades.
	`look` is the same breath for all: { glow 0..1 (the edge's light), light (a PointLight's
	brightness), sparks 0..1 (its particles), flare 0..1 (the impact) }.
]]
local WeaponFX = {}

-- Per kit: its parts (RigBuilder names them "Kit" .. name), its element, its colours.
WeaponFX.KITS = {
	SHIN = { blade = "Blade", edge = "Edge", element = "water", accent = "BFE8FF" },
	RAIJIN = { blade = "SpearHead", edge = "Edge", shaft = "Shaft", element = "lightning", accent = "FFF6B0" },
	YUKINA = { blade = "FanLeaf", edge = "FanEdge", element = "frost", accent = "E8FBFF" },
	KAZAN = { blade = "ClawBlade2", edge = "ClawEdge2", element = "ember", accent = "FFB060" },
}

-- What each element emits (particles off the blade): rate per second at sparks = 1, life,
-- speed, drift (studs/s², y), size (start, end), light emission.
WeaponFX.ELEMENTS = {
	water = { rate = 10, life = { 0.35, 0.6 }, speed = { 0.4, 1.2 }, drift = -5, size = { 0.12, 0.02 }, emission = 0.6 },
	lightning = { rate = 16, life = { 0.08, 0.18 }, speed = { 3, 7 }, drift = 0, size = { 0.16, 0 }, emission = 1 },
	frost = { rate = 8, life = { 0.8, 1.4 }, speed = { 0.2, 0.6 }, drift = -0.6, size = { 0.14, 0.04 }, emission = 0.7 },
	ember = { rate = 10, life = { 0.5, 0.9 }, speed = { 0.6, 1.6 }, drift = 3, size = { 0.12, 0 }, emission = 1 },
}

local function smooth(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function blend(a, b, t)
	local out = {}
	for k, v in a do out[k] = v + (b[k] - v) * t end
	return out
end

WeaponFX.LOOK = {
	rest = { glow = 0.35, light = 0.5, sparks = 0.3, flare = 0 },
	gather = { glow = 0.75, light = 1.4, sparks = 0.9, flare = 0 },
	impact = { glow = 1, light = 3.5, sparks = 1, flare = 1 },
	guard = { glow = 0.6, light = 1, sparks = 0.5, flare = 0 },
	hurt = { glow = 0.15, light = 0.25, sparks = 0.1, flare = 0 },
	down = { glow = 0.05, light = 0.1, sparks = 0, flare = 0 },
}
local GUARD = { Blocking = true, CrouchBlocking = true, Blockstun = true, CrouchBlockstun = true }
local HURT = { Hitstun = true, Launched = true, Crumple = true, GuardBroken = true }
local DOWN = { Knockdown = true, KO = true, GetUp = true }

-- The weapon's breath for a fighter's view at `time` (`move`: the move's data when attacking).
function WeaponFX.look(view, move, time)
	local L = WeaponFX.LOOK
	local state = view.state
	time = time or 0
	if DOWN[state] then return blend(L.down, L.down, 0) end
	if GUARD[state] then
		local g = blend(L.guard, L.guard, 0)
		if state == "Blockstun" or state == "CrouchBlockstun" then g.flare, g.glow = 0.6, 1 end -- (a blow on it)
		return g
	end
	if HURT[state] then
		local h = blend(L.hurt, L.hurt, 0)
		h.light *= 0.5 + 0.5 * math.abs(math.sin(time * 21)) -- (it gutters)
		return h
	end
	local breath = math.sin(time * 2.2)
	local rest = blend(L.rest, L.rest, 0)
	rest.glow += breath * 0.08
	rest.light += breath * 0.12
	if state ~= "Attack" or not move then return rest end
	local frame, startup, active, recovery = view.moveFrame or 0, move.startup, move.active, move.recovery
	if frame <= startup then
		return blend(rest, L.gather, smooth(frame / math.max(1, startup) * 1.4))
	elseif frame <= startup + active then
		return blend(L.impact, L.gather, smooth((frame - startup - 1) / math.max(2, active + 2)))
	end
	return blend(L.gather, rest, smooth((frame - startup - active) / math.max(1, recovery * 0.7)))
end

-- The glint: a bright streak running down the blade from its base to its tip, every `period`
-- seconds, for `length` of them. Returns where it is along the blade (0..1), or nil.
WeaponFX.GLINT = { period = 3.2, length = 0.35 }
function WeaponFX.glint(time, offset)
	local g = WeaponFX.GLINT
	local t = (time + (offset or 0)) % g.period
	if t > g.length then return nil end
	return smooth(t / g.length)
end

-- YUKINA's ICE MIRROR (S + E: MoveData YukinaMirror, `reflect` = the frames it sends shots
-- back): a hexagon of ice before her. It grows out of nothing up to the first reflecting
-- frame, holds (shimmering) while it reflects, then shatters. Returns nil when there is no
-- mirror, else { grow 0..1 (its size), shown 0..1 (its opacity), shimmer -1..1, shatter
-- (true on the first frame after the window: the burst of shards) }.
WeaponFX.MIRROR = { shatter = 6 }
function WeaponFX.mirror(move, frame, time)
	local window = move and move.reflect
	if not window or not frame then return nil end
	local from, to = window.from, window.to
	if frame < 0 or frame > to + WeaponFX.MIRROR.shatter then return nil end
	local shimmer = math.sin((time or 0) * 9)
	if frame < from then
		local g = smooth((frame + 1) / math.max(1, from))
		return { grow = g, shown = g, shimmer = shimmer, shatter = false }
	elseif frame <= to then
		return { grow = 1, shown = 1, shimmer = shimmer, shatter = false }
	end
	local k = (frame - to) / WeaponFX.MIRROR.shatter
	return { grow = 1 + 0.15 * k, shown = 1 - smooth(k), shimmer = shimmer, shatter = frame == to + 1 }
end

return WeaponFX
