--[[
	Frame data and combo routes. Pure data, read by the authoritative simulation and by the
	client for presentation only.

	Timeline of a move lasting startup + active + recovery ticks, frame counted from 1:
	  1 .. startup                        startup  (no hitbox)
	  startup + 1 .. startup + active     active   (hitbox live, hits at most once)
	  startup + active + 1 .. total       recovery
	The move ends after its last recovery tick. Hitstop suspends the frame counter.

	Fields
	  hitbox      offsets from the attacker along its facing (near/far) and above its feet (low/high)
	  guard       "Mid" blocked standing or crouching, "High" only standing, "Low" only crouching
	  cancels     button -> move id, allowed once the move made contact (hit or block)
	  launch      vertical velocity given to the target; launched targets fall into a knockdown
	  crumple     long collapsing hitstun, once per combo
	  groundBounce / wallBounce   once per combo, the target bounces and stays juggleable
	  knockdown   the target falls even when hit on the ground
	  jumpCancel  on hit, jumping during recovery cancels the move (follow the launched target)
	  invuln      { from, to } frames during which the user cannot be hit
	  meterCost   ki meter spent to start the move
	  hits / hitInterval   multi-hit: up to `hits` hits, at least `hitInterval` frames apart;
	              launch, bounces and crumple only apply on the final hit
	  holdVy / multiPush / multiHitstop   intermediate hits of a multi-hit move
	  projectile  spawns a ki blast on the first active frame (one per fighter on screen)
	  skill       special skill unlocked by alternating clicks: announced on screen
	  homing      the user leaps at the target: horizontal speed up to `lunge`, vertical speed
	              enough to reach the target's height (decided at the start), steering each tick
	  track       horizontal steering toward the target until all hits are out (no leap)
	  heavy       presentation hint for bigger effects
	Blocked hits deal damage * CombatConfig.BlockDamageRatio and can never KO.
	Any grounded normal cancels into the special (E) on contact; any normal or special cancels
	into the ultimate (R) on contact when the meter allows it.
]]

local MoveData = {}

local function move(data)
	if data.hitbox then data.hitbox = table.freeze(data.hitbox) end
	if data.projectile then
		local p = data.projectile
		p.id, p.name, p.kind = data.id, data.name, "Special"
		p.guard, p.launch = p.guard or "Mid", 0
		data.projectile = table.freeze(p)
	end
	if data.cancels then data.cancels = table.freeze(data.cancels) end
	if data.invuln then data.invuln = table.freeze(data.invuln) end
	data.lunge = data.lunge or 0
	data.launch = data.launch or 0
	data.guard = data.guard or "Mid"
	data.kind = data.kind or "Normal"
	return table.freeze(data)
end

MoveData.Moves = table.freeze({
	-- Left-click chain: JAB > CROSS > COUDE > KICK
	Jab = move({
		id = "Jab", name = "JAB", startup = 5, active = 3, recovery = 9,
		damage = 45, guardDamage = 6, hitstun = 17, blockstun = 11, hitstop = 6,
		push = 10, blockPush = 12, lunge = 4,
		hitbox = { near = 0.4, far = 3.6, low = 2.6, high = 4.6 },
		cancels = { Light = "Cross", Heavy = "BodyBlow" },
	}),
	Cross = move({
		id = "Cross", name = "CROSS", startup = 6, active = 3, recovery = 11,
		damage = 55, guardDamage = 8, hitstun = 19, blockstun = 12, hitstop = 7,
		push = 11, blockPush = 13, lunge = 7,
		hitbox = { near = 0.4, far = 3.9, low = 2.6, high = 4.6 },
		cancels = { Light = "Elbow", Heavy = "Uppercut" },
	}),
	Elbow = move({
		id = "Elbow", name = "COUDE", startup = 6, active = 3, recovery = 13,
		damage = 60, guardDamage = 9, hitstun = 21, blockstun = 13, hitstop = 8,
		push = 9, blockPush = 12, lunge = 10,
		hitbox = { near = 0.3, far = 3.3, low = 2.8, high = 5.0 },
		cancels = { Light = "Kick", Heavy = "SpinKick" },
	}),
	Kick = move({
		id = "Kick", name = "KICK", startup = 8, active = 4, recovery = 18,
		damage = 80, guardDamage = 12, hitstun = 24, blockstun = 14, hitstop = 10,
		push = 24, blockPush = 18, lunge = 8, launch = 16, knockdown = true,
		hitbox = { near = 0.4, far = 4.4, low = 1.8, high = 4.4 },
		heavy = true,
		cancels = { Heavy = "CrescentMoon" },
	}),
	-- Right-click branches of the left-click chain
	BodyBlow = move({ -- L > R : crumple, then restart a combo
		id = "BodyBlow", name = "COUP AU FOIE", startup = 9, active = 3, recovery = 16,
		damage = 70, guardDamage = 14, hitstun = 22, blockstun = 14, hitstop = 10,
		push = 4, blockPush = 14, lunge = 10, crumple = true,
		hitbox = { near = 0.3, far = 3.4, low = 1.8, high = 3.8 },
		heavy = true,
		cancels = { Light = "PalmStrike" },
	}),
	Uppercut = move({ -- L > L > R or crouch + R : launcher, jump to follow
		id = "Uppercut", name = "LANCEUR", startup = 8, active = 4, recovery = 22,
		damage = 70, guardDamage = 12, hitstun = 26, blockstun = 14, hitstop = 9,
		push = 3, blockPush = 14, lunge = 6, launch = 46, jumpCancel = true,
		hitbox = { near = 0.2, far = 3.4, low = 1.6, high = 6.6 },
		heavy = true,
		cancels = { Heavy = "DragonFist" },
	}),
	-- Alternating routes: L > R > L > R and friends unlock special skills.
	PalmStrike = move({ -- L > R > L : ki palm on the crumpling target
		id = "PalmStrike", name = "PAUME DE KI", startup = 8, active = 4, recovery = 18,
		damage = 75, guardDamage = 14, hitstun = 26, blockstun = 14, hitstop = 10,
		push = 10, blockPush = 16, lunge = 8,
		hitbox = { near = 0.3, far = 3.8, low = 1.8, high = 4.8 },
		heavy = true,
		cancels = { Heavy = "DragonTornado" },
	}),
	DragonTornado = move({ -- L > R > L > R : skill, spinning multi-hit launcher
		id = "DragonTornado", name = "TORNADE DU DRAGON", kind = "Skill", skill = true,
		startup = 9, active = 16, recovery = 24, hits = 4, hitInterval = 4,
		damage = 30, guardDamage = 10, hitstun = 30, blockstun = 12, hitstop = 12,
		multiHitstop = 3, holdVy = 14, multiPush = 1,
		push = 6, blockPush = 18, lunge = 12, launch = 46, jumpCancel = true, track = true,
		hitbox = { near = 0, far = 3.6, low = 0, high = 7.4 },
		heavy = true,
		cancels = { Light = "KiChase" },
	}),
	DragonFist = move({ -- L > L > R > R or R > R > L > R : skill, rising triple uppercut
		id = "DragonFist", name = "POING DU DRAGON", kind = "Skill", skill = true,
		startup = 7, active = 12, recovery = 28, hits = 3, hitInterval = 4,
		damage = 40, guardDamage = 12, hitstun = 30, blockstun = 14, hitstop = 14,
		multiHitstop = 4, holdVy = 6, multiPush = 1,
		push = 4, blockPush = 18, lunge = 14, launch = 34, track = true,
		hitbox = { near = 0, far = 3.6, low = 0.5, high = 10 },
		heavy = true,
		cancels = { Light = "KiChase" },
	}),
	CrescentMoon = move({ -- L L L L > R : skill, flipping kicks that spike the target down
		id = "CrescentMoon", name = "CROISSANT DE LUNE", kind = "Skill", skill = true,
		startup = 7, active = 13, recovery = 24, hits = 3, hitInterval = 5,
		damage = 35, guardDamage = 12, hitstun = 28, blockstun = 14, hitstop = 13,
		multiHitstop = 4, holdVy = 12, multiPush = 2,
		push = 8, blockPush = 18, lunge = 14, launch = -30, groundBounce = true,
		hitbox = { near = 0, far = 4.2, low = 0, high = 7.5 },
		heavy = true,
		cancels = { Heavy = "Finale" },
	}),
	RisingWind = move({ -- R > L > R : double kick that lifts the swept target
		id = "RisingWind", name = "VENT ASCENDANT", startup = 7, active = 8, recovery = 20,
		hits = 2, hitInterval = 4, damage = 40, guardDamage = 10, hitstun = 26, blockstun = 13, hitstop = 9,
		multiHitstop = 3, holdVy = 12, multiPush = 1,
		push = 6, blockPush = 14, lunge = 10, launch = 30,
		hitbox = { near = 0.2, far = 4.0, low = -0.5, high = 5.5 },
		heavy = true,
		cancels = { Light = "KiFlurry" },
	}),
	KiFlurry = move({ -- R > L > R > L : skill, rush of ki punches ending in a wall bounce
		id = "KiFlurry", name = "RAFALE DE KI", kind = "Skill", skill = true,
		startup = 6, active = 24, recovery = 22, hits = 7, hitInterval = 3,
		damage = 18, guardDamage = 6, hitstun = 28, blockstun = 12, hitstop = 14,
		multiHitstop = 2, holdVy = 7, multiPush = 1,
		push = 44, blockPush = 20, lunge = 6, launch = 18, wallBounce = true,
		hitbox = { near = 0.3, far = 4.2, low = 0, high = 7.5 },
		heavy = true,
		cancels = { Light = "KiChase" },
	}),
	ThunderHeel = move({ -- R > R > L : catches the bounce, launches
		id = "ThunderHeel", name = "TALON FOUDRE", startup = 7, active = 4, recovery = 20,
		damage = 70, guardDamage = 12, hitstun = 26, blockstun = 14, hitstop = 10,
		push = 3, blockPush = 14, lunge = 8, launch = 40, jumpCancel = true,
		hitbox = { near = 0.2, far = 3.8, low = 0, high = 7 },
		heavy = true,
		cancels = { Heavy = "DragonFist" },
	}),
	SpinKick = move({ -- L > L > L > R : wall bounce
		id = "SpinKick", name = "TALON TOURNOYANT", startup = 10, active = 3, recovery = 22,
		damage = 95, guardDamage = 18, hitstun = 26, blockstun = 16, hitstop = 12,
		push = 46, blockPush = 22, lunge = 6, launch = 14, wallBounce = true,
		hitbox = { near = 0.4, far = 4.6, low = 2.2, high = 4.8 },
		heavy = true,
		cancels = { Light = "KiChase" },
	}),
	-- Right-click chain
	Smash = move({
		id = "Smash", name = "FRAPPE LOURDE", startup = 13, active = 4, recovery = 22,
		damage = 110, guardDamage = 40, hitstun = 26, blockstun = 16, hitstop = 11,
		push = 30, blockPush = 22, lunge = 12,
		hitbox = { near = 0.4, far = 4.2, low = 2.4, high = 4.8 },
		heavy = true,
		cancels = { Heavy = "Hammer", Light = "Sweep" },
	}),
	Hammer = move({ -- R > R : overhead axe kick, ground bounce
		id = "Hammer", name = "HACHE CÉLESTE", startup = 12, active = 4, recovery = 20,
		damage = 90, guardDamage = 22, hitstun = 28, blockstun = 15, hitstop = 12,
		push = 4, blockPush = 16, lunge = 10, launch = 26, groundBounce = true, guard = "High",
		hitbox = { near = 0.3, far = 3.8, low = 1.0, high = 6.4 },
		heavy = true,
		cancels = { Light = "ThunderHeel" },
	}),
	Sweep = move({ -- R > L : low sweep, knockdown
		id = "Sweep", name = "BALAYAGE", startup = 9, active = 4, recovery = 20,
		damage = 60, guardDamage = 12, hitstun = 22, blockstun = 13, hitstop = 9,
		push = 8, blockPush = 14, lunge = 12, launch = 10, knockdown = true, guard = "Low",
		hitbox = { near = 0.3, far = 4.6, low = -0.2, high = 1.4 },
		cancels = { Heavy = "RisingWind" },
	}),
	-- Crouching
	LowKick = move({
		id = "LowKick", name = "KICK BAS", startup = 5, active = 3, recovery = 10,
		damage = 35, guardDamage = 6, hitstun = 16, blockstun = 11, hitstop = 6,
		push = 9, blockPush = 11, lunge = 3, guard = "Low",
		hitbox = { near = 0.3, far = 4.0, low = -0.2, high = 1.4 },
		cancels = { Light = "Cross", Heavy = "Uppercut" },
	}),
	-- Air chain: J.L > J.L > J.R
	AirKick = move({
		id = "AirKick", name = "KICK AÉRIEN", startup = 6, active = 6, recovery = 10, air = true,
		damage = 55, guardDamage = 10, hitstun = 20, blockstun = 12, hitstop = 8,
		push = 6, blockPush = 12, guard = "High",
		hitbox = { near = 0.3, far = 3.4, low = -0.6, high = 3.2 },
		cancels = { Light = "AirKick2", Heavy = "AirSmash" },
	}),
	AirKick2 = move({
		id = "AirKick2", name = "DOUBLE KICK", startup = 6, active = 4, recovery = 12, air = true,
		damage = 55, guardDamage = 10, hitstun = 20, blockstun = 12, hitstop = 8,
		push = 6, blockPush = 12, guard = "High",
		hitbox = { near = 0.3, far = 3.6, low = -0.2, high = 3.4 },
		cancels = { Heavy = "AirSmash" },
	}),
	AirSmash = move({
		id = "AirSmash", name = "MÉTÉORE", startup = 9, active = 5, recovery = 14, air = true,
		damage = 80, guardDamage = 16, hitstun = 24, blockstun = 14, hitstop = 11,
		push = 10, blockPush = 14, launch = -30, groundBounce = true, guard = "High",
		hitbox = { near = 0.2, far = 3.6, low = -1.2, high = 3.0 },
		heavy = true,
	}),
	-- Special (E): invincible rising launcher, also the anti-air reversal
	Rising = move({
		id = "Rising", name = "RISING STRIKE", kind = "Special", startup = 9, active = 5, recovery = 26,
		damage = 100, guardDamage = 25, hitstun = 30, blockstun = 15, hitstop = 12,
		push = 6, blockPush = 18, lunge = 22, launch = 40, jumpCancel = true,
		invuln = { from = 1, to = 10 },
		hitbox = { near = 0.2, far = 3.6, low = 1.0, high = 7.0 },
		heavy = true,
	}),
	-- The two last links of every 6-press route: L (chase) then R (finisher).
	KiChase = move({ -- 5th press: dash through the air to catch any launched / bouncing target
		id = "KiChase", name = "POURSUITE ÉCARLATE", startup = 6, active = 8, recovery = 22,
		damage = 50, guardDamage = 10, hitstun = 30, blockstun = 14, hitstop = 9,
		push = 4, blockPush = 14, lunge = 34, launch = 26, homing = true, -- ki-charged leap at the target
		hitbox = { near = 0, far = 4.6, low = -1, high = 9 },
		heavy = true,
		cancels = { Heavy = "Finale" },
	}),
	Finale = move({ -- 6th press: finisher. Clean route + 3 bars: ÉVEIL ÉCARLATE (right click) or PORTE DES CIEUX (R key)
		id = "Finale", name = "COUP DE GRÂCE", kind = "Skill", skill = true,
		startup = 8, active = 4, recovery = 30,
		damage = 110, guardDamage = 30, hitstun = 34, blockstun = 18, hitstop = 16,
		push = 40, blockPush = 22, lunge = 14, launch = 30, knockdown = true,
		hitbox = { near = 0, far = 4.6, low = -1, high = 9 },
		heavy = true,
	}),
	Kaiten = move({ -- third ultimate: clean full route ending on the R key, 3 bars
		id = "Kaiten", name = "開天 · PORTE DES CIEUX", kind = "Ultimate", startup = 8, active = 6, recovery = 44,
		damage = 20, guardDamage = 40, hitstun = 40, blockstun = 22, hitstop = 4,
		push = 2, blockPush = 24, lunge = 18, meterCost = 300,
		invuln = { from = 1, to = 14 },
		hitbox = { near = 0, far = 4.6, low = -1, high = 9 },
		heavy = true,
	}),
	Awakening = move({ -- unique attack: 3 bars, cinematic, 95 % of the current health or FINAL FINISH
		id = "Awakening", name = "ÉVEIL ÉCARLATE", kind = "Ultimate", startup = 8, active = 6, recovery = 40,
		damage = 20, guardDamage = 40, hitstun = 40, blockstun = 22, hitstop = 4,
		push = 2, blockPush = 24, lunge = 20, meterCost = 300,
		invuln = { from = 1, to = 14 },
		hitbox = { near = 0, far = 4.6, low = -1, high = 9 },
		heavy = true,
	}),
	-- Crouch + E: ki blast projectile
	KiBlast = move({
		id = "KiBlast", name = "KIKOHO", kind = "Special", startup = 12, active = 2, recovery = 26,
		damage = 0, guardDamage = 0, hitstun = 0, blockstun = 0, hitstop = 0, push = 0, blockPush = 0,
		projectile = {
			speed = 30, life = 90, spawnX = 1.8, height = 3.6, halfWidth = 0.9, halfHeight = 0.9,
			damage = 70, guardDamage = 14, hitstun = 22, blockstun = 15, hitstop = 9,
			push = 14, blockPush = 16, heavy = false,
		},
	}),
	-- Ultimate (R): costs ki, starts a cinematic when it connects
	KaienRush = move({
		id = "KaienRush", name = "KAIEN RUSH", kind = "Ultimate", startup = 8, active = 10, recovery = 36,
		damage = 30, guardDamage = 30, hitstun = 40, blockstun = 20, hitstop = 4,
		push = 2, blockPush = 20, lunge = 34, meterCost = 200,
		invuln = { from = 1, to = 12 },
		hitbox = { near = 0.2, far = 3.8, low = 0.8, high = 8.5 },
		heavy = true,
	}),
})

-- Which move a button starts from neutral.
MoveData.Starters = table.freeze({
	Ground = table.freeze({ Light = "Jab", Heavy = "Smash", Special = "Rising", Ultimate = "KaienRush" }),
	Crouch = table.freeze({ Light = "LowKick", Heavy = "Uppercut", Special = "KiBlast", Ultimate = "KaienRush" }),
	Air = table.freeze({ Light = "AirKick", Heavy = "AirSmash" }),
})

-- Scripted cinematics: ticks of the hits inside the cinematic and how damage is decided.
MoveData.Cinematics = table.freeze({
	KaienRush = table.freeze({
		Length = 150,
		FinalTick = 118,
		Hits = table.freeze({ 22, 30, 37, 44, 51, 58, 65, 72, 80, 88, 96 }),
		HitDamage = 22,
		FinalDamage = 170,
		MinScaling = 0.5,
	}),
	-- 開天 · PORTE DES CIEUX: a gate drags the target into a crimson world for one blow.
	-- Removes MaxHealthShare of the MAXIMUM health (KO possible, then the K.O. scene).
	-- One prompt: the R key right on the climax opens the gate fully (+PerfectBonus).
	Kaiten = table.freeze({
		Length = 210,
		FinalTick = 150,
		Hits = table.freeze({ 118, 126 }),
		HitShare = 0.05,
		MaxHealthShare = 0.5,
		FinishExtra = 200,
		PromptTicks = table.freeze({ 140 }),
		PromptWindow = 4,
		PerfectBonus = 0.1,
	}),
	-- ÉVEIL ÉCARLATE: removes HealthRatio of the target's current health, whatever it is.
	-- Below FinishThreshold of the maximum health it is a FINAL FINISH (KO) with an extra
	-- FinishExtra ticks of KO sequence.
	Awakening = table.freeze({
		Length = 220,
		FinalTick = 160,
		Hits = table.freeze({ 70, 78, 86, 94, 102, 110, 118 }),
		HitShare = 0.05,
		HealthRatio = 0.95,
		FinishThreshold = 0.5,
		FinishExtra = 200, -- the K.O. scene of a FINAL FINISH
		-- Rhythm prompts during the rush: the four first keys of the route that was played.
		PromptTicks = table.freeze({ 66, 82, 98, 114 }),
		PromptWindow = 7,
		PerfectRefund = 100,
	}),
})
-- Kept for code written against the single-cinematic version.
MoveData.Cinematic = MoveData.Cinematics.KaienRush

-- Combo routes shown in the HUD help and used by the CPU. L = clic gauche, R = clic droit.
MoveData.Routes = table.freeze({
	{ name = "CHAÎNE", keys = "L L L L", moves = { "Jab", "Cross", "Elbow", "Kick" } },
	{ name = "LANCEUR", keys = "L L R ↑", moves = { "Jab", "Cross", "Uppercut" } },
	{ name = "FOIE", keys = "L R", moves = { "Jab", "BodyBlow" } },
	{ name = "MUR", keys = "L L L R", moves = { "Jab", "Cross", "Elbow", "SpinKick" } },
	{ name = "HACHE", keys = "R R", moves = { "Smash", "Hammer" } },
	{ name = "BALAYAGE", keys = "R L", moves = { "Smash", "Sweep" } },
	{ name = "★ TORNADE", keys = "L R L R", moves = { "Jab", "BodyBlow", "PalmStrike", "DragonTornado" } },
	{ name = "★ RAFALE", keys = "R L R L", moves = { "Smash", "Sweep", "RisingWind", "KiFlurry" } },
	{ name = "★ DRAGON", keys = "L L R R", moves = { "Jab", "Cross", "Uppercut", "DragonFist" } },
	{ name = "★ FOUDRE", keys = "R R L R", moves = { "Smash", "Hammer", "ThunderHeel", "DragonFist" } },
	{ name = "★ LUNE", keys = "L L L L R", moves = { "Jab", "Cross", "Elbow", "Kick", "CrescentMoon" } },
})

-- The six full 6-press routes. Their last link is COUP DE GRÂCE, which becomes
-- ÉVEIL ÉCARLATE when the ki meter is full (3 bars).
MoveData.FullRoutes = table.freeze({
	{ name = "TORNADE", keys = "L R L R L R", moves = { "Jab", "BodyBlow", "PalmStrike", "DragonTornado", "KiChase", "Finale" } },
	{ name = "RAFALE", keys = "R L R L L R", moves = { "Smash", "Sweep", "RisingWind", "KiFlurry", "KiChase", "Finale" } },
	{ name = "DRAGON", keys = "L L R R L R", moves = { "Jab", "Cross", "Uppercut", "DragonFist", "KiChase", "Finale" } },
	{ name = "FOUDRE", keys = "R R L R L R", moves = { "Smash", "Hammer", "ThunderHeel", "DragonFist", "KiChase", "Finale" } },
	{ name = "MUR", keys = "L L L R L R", moves = { "Jab", "Cross", "Elbow", "SpinKick", "KiChase", "Finale" } },
	{ name = "LUNE", keys = "L L L L R R", moves = { "Jab", "Cross", "Elbow", "Kick", "CrescentMoon", "Finale" } },
})

function MoveData.total(m)
	return m.startup + m.active + m.recovery
end

function MoveData.phase(m, frame)
	if frame <= m.startup then
		return "Startup"
	elseif frame <= m.startup + m.active then
		return "Active"
	end
	return "Recovery"
end

return table.freeze(MoveData)
