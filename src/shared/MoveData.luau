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
	  slip        { from, to } frames during which attacks that are not low whiff over the
	              user (boxer's ducking head; projectiles and ultimates still hit)
	  dempsey / finisher   a DEMPSEY ROLL hook (counted against kit.Weave.MaxHooks) / its last
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
	-- (an override can take a field away from the role it derives from: `false` means none)
	if data.invuln == false then data.invuln = nil end
	if data.projectile == false then data.projectile = nil end
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

-- KAI 開's moves. They are also the role templates of every other kit (see derive below).
local KAI = {
	-- Left-click chain: JAB > CROSS > COUDE > KICK
	Jab = {
		id = "Jab", name = "JAB", startup = 5, active = 3, recovery = 9,
		damage = 45, guardDamage = 6, hitstun = 17, blockstun = 11, hitstop = 6,
		push = 10, blockPush = 12, lunge = 4,
		hitbox = { near = 0.4, far = 3.6, low = 2.6, high = 4.6 },
		cancels = { Light = "Cross", Heavy = "BodyBlow" },
	},
	Cross = {
		id = "Cross", name = "CROSS", startup = 6, active = 3, recovery = 11,
		damage = 55, guardDamage = 8, hitstun = 19, blockstun = 12, hitstop = 7,
		push = 11, blockPush = 13, lunge = 7,
		hitbox = { near = 0.4, far = 3.9, low = 2.6, high = 4.6 },
		cancels = { Light = "Elbow", Heavy = "Uppercut" },
	},
	Elbow = {
		id = "Elbow", name = "ELBOW", startup = 6, active = 3, recovery = 13,
		damage = 60, guardDamage = 9, hitstun = 21, blockstun = 13, hitstop = 8,
		push = 9, blockPush = 12, lunge = 10,
		hitbox = { near = 0.3, far = 3.3, low = 2.8, high = 5.0 },
		cancels = { Light = "Kick", Heavy = "SpinKick" },
	},
	Kick = {
		id = "Kick", name = "KICK", startup = 8, active = 4, recovery = 18,
		damage = 80, guardDamage = 12, hitstun = 24, blockstun = 14, hitstop = 10,
		push = 24, blockPush = 18, lunge = 8, launch = 16, knockdown = true,
		hitbox = { near = 0.4, far = 4.4, low = 1.8, high = 4.4 },
		heavy = true,
		cancels = { Heavy = "CrescentMoon" },
	},
	-- Right-click branches of the left-click chain
	BodyBlow = { -- L > R : crumple, then restart a combo
		id = "BodyBlow", name = "LIVER SHOT", startup = 9, active = 3, recovery = 16,
		damage = 70, guardDamage = 14, hitstun = 22, blockstun = 14, hitstop = 10,
		push = 4, blockPush = 14, lunge = 10, crumple = true,
		hitbox = { near = 0.3, far = 3.4, low = 1.8, high = 3.8 },
		heavy = true,
		cancels = { Light = "PalmStrike" },
	},
	Uppercut = { -- L > L > R or crouch + R : launcher, jump to follow
		id = "Uppercut", name = "LAUNCHER", startup = 8, active = 4, recovery = 22,
		damage = 70, guardDamage = 12, hitstun = 26, blockstun = 14, hitstop = 9,
		push = 3, blockPush = 14, lunge = 6, launch = 46, jumpCancel = true,
		hitbox = { near = 0.2, far = 3.4, low = 1.6, high = 6.6 },
		heavy = true,
		cancels = { Heavy = "DragonFist" },
	},
	-- Alternating routes: L > R > L > R and friends unlock special skills.
	PalmStrike = { -- L > R > L : ki palm on the crumpling target
		id = "PalmStrike", name = "KI PALM", startup = 8, active = 4, recovery = 18,
		damage = 75, guardDamage = 14, hitstun = 26, blockstun = 14, hitstop = 10,
		push = 10, blockPush = 16, lunge = 8,
		hitbox = { near = 0.3, far = 3.8, low = 1.8, high = 4.8 },
		heavy = true,
		cancels = { Heavy = "DragonTornado" },
	},
	DragonTornado = { -- L > R > L > R : skill, spinning multi-hit launcher
		id = "DragonTornado", name = "DRAGON TORNADO", kind = "Skill", skill = true,
		startup = 9, active = 16, recovery = 24, hits = 4, hitInterval = 4,
		damage = 30, guardDamage = 10, hitstun = 30, blockstun = 12, hitstop = 12,
		multiHitstop = 3, holdVy = 14, multiPush = 1,
		push = 6, blockPush = 18, lunge = 12, launch = 46, jumpCancel = true, track = true,
		hitbox = { near = 0, far = 3.6, low = 0, high = 7.4 },
		heavy = true,
		cancels = { Light = "KiChase" },
	},
	DragonFist = { -- L > L > R > R or R > R > L > R : skill, rising triple uppercut
		id = "DragonFist", name = "DRAGON FIST", kind = "Skill", skill = true,
		startup = 7, active = 12, recovery = 28, hits = 3, hitInterval = 4,
		damage = 40, guardDamage = 12, hitstun = 30, blockstun = 14, hitstop = 14,
		multiHitstop = 4, holdVy = 6, multiPush = 1,
		-- Rises with the launched target, then the last blow spikes it into the floor: it
		-- bounces back up (once per combo) for the chase and the finisher.
		push = 4, blockPush = 18, lunge = 14, launch = -55, track = true, rise = true, groundBounce = true,
		hitbox = { near = 0, far = 3.6, low = -1, high = 7 },
		heavy = true,
		cancels = { Light = "KiChase" },
	},
	CrescentMoon = { -- L L L L > R : skill, flipping kicks that spike the target down
		id = "CrescentMoon", name = "CRESCENT MOON", kind = "Skill", skill = true,
		startup = 7, active = 13, recovery = 24, hits = 3, hitInterval = 5,
		damage = 35, guardDamage = 12, hitstun = 28, blockstun = 14, hitstop = 13,
		multiHitstop = 4, holdVy = 12, multiPush = 2,
		push = 8, blockPush = 18, lunge = 14, launch = -30, groundBounce = true,
		hitbox = { near = 0, far = 4.2, low = 0, high = 7.5 },
		heavy = true,
		cancels = { Heavy = "Finale" },
	},
	RisingWind = { -- R > L > R : double kick that lifts the swept target
		id = "RisingWind", name = "RISING WIND", startup = 6, active = 8, recovery = 20,
		hits = 2, hitInterval = 4, damage = 40, guardDamage = 10, hitstun = 26, blockstun = 13, hitstop = 9,
		multiHitstop = 3, holdVy = 12, multiPush = 1,
		push = 6, blockPush = 14, lunge = 10, launch = 30, track = true,
		hitbox = { near = 0.2, far = 4.2, low = -1.5, high = 6 },
		heavy = true,
		cancels = { Light = "KiFlurry" },
	},
	KiFlurry = { -- R > L > R > L : skill, rush of ki punches ending in a wall bounce
		id = "KiFlurry", name = "KI FLURRY", kind = "Skill", skill = true,
		startup = 6, active = 24, recovery = 22, hits = 7, hitInterval = 3,
		damage = 18, guardDamage = 6, hitstun = 28, blockstun = 12, hitstop = 14,
		multiHitstop = 2, holdVy = 7, multiPush = 1,
		push = 44, blockPush = 20, lunge = 6, launch = 18, wallBounce = true,
		hitbox = { near = 0.3, far = 4.2, low = 0, high = 7.5 },
		heavy = true,
		cancels = { Light = "KiChase" },
	},
	ThunderHeel = { -- R > R > L : catches the bounce, launches
		id = "ThunderHeel", name = "THUNDER HEEL", startup = 7, active = 4, recovery = 20,
		damage = 70, guardDamage = 12, hitstun = 26, blockstun = 14, hitstop = 10,
		push = 3, blockPush = 14, lunge = 8, launch = 34, jumpCancel = true,
		hitbox = { near = 0.2, far = 3.8, low = 0, high = 7 },
		heavy = true,
		cancels = { Heavy = "DragonFist" },
	},
	SpinKick = { -- L > L > L > R : wall bounce
		id = "SpinKick", name = "SPINNING HEEL", startup = 10, active = 3, recovery = 22,
		damage = 95, guardDamage = 18, hitstun = 26, blockstun = 16, hitstop = 12,
		push = 46, blockPush = 22, lunge = 6, launch = 14, wallBounce = true,
		hitbox = { near = 0.4, far = 4.6, low = 2.2, high = 4.8 },
		heavy = true,
		cancels = { Light = "KiChase" },
	},
	-- Right-click chain
	Smash = {
		id = "Smash", name = "HEAVY STRIKE", startup = 13, active = 4, recovery = 22,
		damage = 110, guardDamage = 40, hitstun = 26, blockstun = 16, hitstop = 11,
		push = 30, blockPush = 22, lunge = 12,
		hitbox = { near = 0.4, far = 4.2, low = 2.4, high = 4.8 },
		heavy = true,
		cancels = { Heavy = "Hammer", Light = "Sweep" },
	},
	Hammer = { -- R > R : overhead axe kick, ground bounce
		id = "Hammer", name = "HEAVEN'S AXE", startup = 12, active = 4, recovery = 20,
		damage = 90, guardDamage = 22, hitstun = 28, blockstun = 15, hitstop = 12,
		push = 4, blockPush = 16, lunge = 10, launch = 26, groundBounce = true, guard = "High",
		hitbox = { near = 0.3, far = 3.8, low = 1.0, high = 6.4 },
		heavy = true,
		cancels = { Light = "ThunderHeel" },
	},
	Sweep = { -- R > L : low sweep, knockdown
		id = "Sweep", name = "SWEEP", startup = 9, active = 4, recovery = 20,
		damage = 60, guardDamage = 12, hitstun = 22, blockstun = 13, hitstop = 9,
		push = 8, blockPush = 14, lunge = 12, launch = 20, knockdown = true, guard = "Low",
		hitbox = { near = 0.3, far = 4.6, low = -0.2, high = 1.4 },
		cancels = { Heavy = "RisingWind" },
	},
	-- Crouching
	LowKick = {
		id = "LowKick", name = "LOW KICK", startup = 5, active = 3, recovery = 10,
		damage = 35, guardDamage = 6, hitstun = 16, blockstun = 11, hitstop = 6,
		push = 9, blockPush = 11, lunge = 3, guard = "Low",
		hitbox = { near = 0.3, far = 4.0, low = -0.2, high = 1.4 },
		cancels = { Light = "Cross", Heavy = "Uppercut" },
	},
	-- Air chain: J.L > J.L > J.R
	AirKick = {
		id = "AirKick", name = "AIR KICK", startup = 6, active = 6, recovery = 10, air = true,
		damage = 55, guardDamage = 10, hitstun = 20, blockstun = 12, hitstop = 8,
		push = 6, blockPush = 12, guard = "High",
		hitbox = { near = 0.3, far = 3.4, low = -0.6, high = 3.2 },
		cancels = { Light = "AirKick2", Heavy = "AirSmash" },
	},
	AirKick2 = {
		id = "AirKick2", name = "DOUBLE KICK", startup = 6, active = 4, recovery = 12, air = true,
		damage = 55, guardDamage = 10, hitstun = 20, blockstun = 12, hitstop = 8,
		push = 6, blockPush = 12, guard = "High",
		hitbox = { near = 0.3, far = 3.6, low = -0.2, high = 3.4 },
		cancels = { Heavy = "AirSmash" },
	},
	AirSmash = {
		id = "AirSmash", name = "METEOR", startup = 9, active = 5, recovery = 14, air = true,
		damage = 80, guardDamage = 16, hitstun = 24, blockstun = 14, hitstop = 11,
		push = 10, blockPush = 14, launch = -30, groundBounce = true, guard = "High",
		hitbox = { near = 0.2, far = 3.6, low = -1.2, high = 3.0 },
		heavy = true,
	},
	-- Special (E): invincible rising launcher, also the anti-air reversal
	Rising = {
		id = "Rising", name = "RISING STRIKE", kind = "Special", startup = 9, active = 5, recovery = 26,
		damage = 100, guardDamage = 25, hitstun = 30, blockstun = 15, hitstop = 12,
		push = 6, blockPush = 18, lunge = 22, launch = 40, jumpCancel = true,
		invuln = { from = 1, to = 10 },
		hitbox = { near = 0.2, far = 3.6, low = 1.0, high = 7.0 },
		heavy = true,
	},
	-- The two last links of every 6-press route: L (chase) then R (finisher).
	KiChase = { -- 5th press: dash through the air to catch any launched / bouncing target
		id = "KiChase", name = "SCARLET CHASE", startup = 6, active = 8, recovery = 22,
		damage = 50, guardDamage = 10, hitstun = 30, blockstun = 14, hitstop = 9,
		push = 4, blockPush = 14, lunge = 34, launch = 26, homing = true, -- ki-charged leap at the target
		hitbox = { near = 0, far = 4.6, low = -1, high = 9 },
		heavy = true,
		cancels = { Heavy = "Finale" },
	},
	Finale = { -- 6th press: finisher. Clean route + 3 bars: ÉVEIL ÉCARLATE (right click) or PORTE DES CIEUX (R key)
		id = "Finale", name = "COUP DE GRACE", kind = "Skill", skill = true,
		startup = 8, active = 4, recovery = 30,
		damage = 110, guardDamage = 30, hitstun = 34, blockstun = 18, hitstop = 16,
		push = 40, blockPush = 22, lunge = 14, launch = 30, knockdown = true, rise = true,
		hitbox = { near = 0, far = 4.6, low = -1, high = 9 },
		heavy = true,
	},
	Kaiten = { -- third ultimate: clean full route ending on the R key, 3 bars
		id = "Kaiten", name = "開天 · GATE OF HEAVEN", kind = "Ultimate", startup = 8, active = 6, recovery = 44,
		damage = 20, guardDamage = 40, hitstun = 40, blockstun = 22, hitstop = 4,
		push = 2, blockPush = 24, lunge = 18, meterCost = 300, track = true,
		invuln = { from = 1, to = 14 },
		hitbox = { near = 0, far = 4.6, low = -1, high = 11 },
		heavy = true,
	},
	Awakening = { -- unique attack: 3 bars, cinematic, up to 35 % of the maximum health (rhythm prompts)
		id = "Awakening", name = "SCARLET AWAKENING", kind = "Ultimate", startup = 8, active = 6, recovery = 40,
		damage = 20, guardDamage = 40, hitstun = 40, blockstun = 22, hitstop = 4,
		push = 2, blockPush = 24, lunge = 20, meterCost = 300, track = true,
		invuln = { from = 1, to = 14 },
		hitbox = { near = 0, far = 4.6, low = -1, high = 11 },
		heavy = true,
	},
	-- COUP FATAL (C): the last-breath move. 3 bars, the user under Config.FatalHealth of its
	-- health, once per match. Cancelled from a hit of a combo it takes the cinematic's
	-- ComboShare of the target's maximum health, thrown raw only RawShare; slow to come out,
	-- blocked or dodged it is simply lost (the whole ki gauge with it). Its cinematic is the
	-- K.O. screen when it kills.
	Fatal = {
		id = "Fatal", name = "滅 · DEAD SKY", kind = "Ultimate", fatal = true, startup = 14, active = 6, recovery = 52,
		damage = 20, guardDamage = 60, hitstun = 40, blockstun = 30, hitstop = 4,
		push = 2, blockPush = 30, lunge = 24, meterCost = 300, track = true,
		invuln = { from = 1, to = 8 },
		hitbox = { near = 0, far = 4.8, low = -1, high = 11 },
		heavy = true,
	},
	-- Crouch + E: ki blast projectile
	KiBlast = {
		id = "KiBlast", name = "KIKOHO", kind = "Special", startup = 12, active = 2, recovery = 26,
		damage = 0, guardDamage = 0, hitstun = 0, blockstun = 0, hitstop = 0, push = 0, blockPush = 0,
		projectile = {
			speed = 30, life = 90, spawnX = 1.8, height = 3.6, halfWidth = 0.9, halfHeight = 0.9,
			damage = 70, guardDamage = 14, hitstun = 22, blockstun = 15, hitstop = 9,
			push = 14, blockPush = 16, heavy = false,
		},
	},
	-- Ultimate (R): costs ki, starts a cinematic when it connects
	KaienRush = {
		id = "KaienRush", name = "KAIEN RUSH", kind = "Ultimate", startup = 8, active = 10, recovery = 36,
		damage = 30, guardDamage = 30, hitstun = 40, blockstun = 20, hitstop = 4,
		push = 2, blockPush = 20, lunge = 34, meterCost = 200, track = true, -- (aims at a jumper, never runs under it)
		invuln = { from = 1, to = 12 },
		hitbox = { near = 0.2, far = 3.8, low = 0.8, high = 11 },
		heavy = true,
	},
}

local function deepCopy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in value do out[k] = deepCopy(v) end
	return out
end

local Moves = {}
local KAI_ROLES = {}
for id, raw in KAI do
	Moves[id] = move(deepCopy(raw))
	KAI_ROLES[id] = id
end

--[[
	Other kits are built on KAI's combo grammar: every KAI move is a role (Jab = first left
	click, BodyBlow = left then right, DragonTornado = skill L R L R...). A kit maps each role
	to its own move and changes what matters: names, damage, speed, reach, properties. So the
	same routes (L R L R...) work for everyone and are learned once, while each kit hits, moves
	and feels differently (punches only, kicks only, shadow strikes).
	tuning: kit-wide { damage = scale, startup = delta for ground normals, reach = scale, recovery = delta
	(the kit's rhythm) };
	overrides[id]: fields replaced on that move (tables are merged).
]]
local function derive(roles, names, tuning, overrides)
	for role, id in roles do
		local raw = KAI[role]
		if raw then
			local data = deepCopy(raw)
			data.id, data.name = id, names[id] or data.name
			if data.cancels then
				local cancels = {}
				for button, target in data.cancels do cancels[button] = roles[target] end
				data.cancels = cancels
			end
			if data.kind ~= "Ultimate" then
				data.damage = math.floor(data.damage * (tuning.damage or 1) + 0.5)
				if data.projectile then
					data.projectile.damage = math.floor(data.projectile.damage * (tuning.damage or 1) + 0.5)
				end
				if (data.kind or "Normal") == "Normal" and not data.air then
					data.startup = math.max(3, data.startup + (tuning.startup or 0))
				end
				-- the kit's rhythm: quick to recover (pressure) or slow (its whiffs get punished)
				if tuning.recovery and data.recovery then data.recovery = math.max(6, data.recovery + tuning.recovery) end
			end
			if data.hitbox then data.hitbox.far = math.floor(data.hitbox.far * (tuning.reach or 1) * 100 + 0.5) / 100 end
			for k, v in overrides[id] or {} do
				if type(v) == "table" and type(data[k]) == "table" then
					for kk, vv in v do data[k][kk] = vv end
				else
					data[k] = v
				end
			end
			Moves[id] = move(data)
		end
	end
end

-- RESOLVE (KAI, kit.Resolve): he took the blow, braces (no invincibility) and answers with a
-- palm that sends the attacker away; both free again about together: back to neutral.
Moves.KaiResolve = move({
	id = "KaiResolve", name = "RESOLVE", kind = "Special", startup = 8, active = 3, recovery = 22,
	damage = 30, guardDamage = 8, hitstun = 14, blockstun = 12, hitstop = 9,
	push = 40, blockPush = 34, lunge = 6, noCancel = true,
	hitbox = { near = 0.2, far = 4.0, low = 1.8, high = 5.0 },
	heavy = true,
})

-- ===================================================================== TARO 火 · boxer
-- Punches only. Fast jabs, heavy hooks, short reach, the toughest body and an iron guard;
-- crouch + E is a PARRY (counter punch) instead of a projectile.
local TARO = {
	Jab = "TaroJab", Cross = "TaroStraight", Elbow = "TaroHook", Kick = "TaroBolo",
	BodyBlow = "TaroLiver", Uppercut = "TaroUppercut", PalmStrike = "TaroRam",
	DragonTornado = "TaroGatling", DragonFist = "TaroVolcano", CrescentMoon = "TaroMeteor",
	RisingWind = "TaroTwinUpper", KiFlurry = "TaroDempsey", ThunderHeel = "TaroRisingHook",
	SpinKick = "TaroCorkscrew", Smash = "TaroHeavy", Hammer = "TaroOverhand", Sweep = "TaroDive",
	LowKick = "TaroLowJab", AirKick = "TaroAirJab", AirKick2 = "TaroAirHook", AirSmash = "TaroAirHammer",
	Rising = "TaroRisingFist", KiChase = "TaroChase", Finale = "TaroFinale",
	KaienRush = "TaroRush", Awakening = "TaroAwakening", Kaiten = "TaroGate", Fatal = "TaroFatal",
}
derive(TARO, {
	TaroJab = "JAB", TaroStraight = "STRAIGHT", TaroHook = "HOOK", TaroBolo = "BOLO PUNCH",
	TaroLiver = "LIVER HOOK", TaroUppercut = "UPPERCUT", TaroRam = "BATTERING RAM",
	TaroGatling = "FIRE GATLING", TaroVolcano = "VOLCANO UPPERCUT", TaroMeteor = "METEOR HAMMER",
	TaroTwinUpper = "DOUBLE RISER", TaroDempsey = "FIGURE-EIGHT FLURRY", TaroRisingHook = "RISING HOOK",
	TaroCorkscrew = "CORKSCREW", TaroHeavy = "HEAVY RIGHT", TaroOverhand = "OVERHAND", TaroDive = "DIVE",
	TaroLowJab = "LOW JAB", TaroAirJab = "AIR STRAIGHT", TaroAirHook = "AIR HOOK", TaroAirHammer = "METEOR FIST",
	TaroRisingFist = "RISING FIST", TaroChase = "BLAZING CHASE", TaroFinale = "FIRE K.O.",
	TaroRush = "DEVASTATING RUSH", TaroAwakening = "HEAVENLY UPPERCUT", TaroGate = "火嵐 · HOOK STORM", TaroFatal = "終 · FINAL BELL",
}, { damage = 0.94, reach = 0.94 }, {
	TaroJab = { startup = 4, recovery = 8 },
	TaroStraight = { startup = 5 },
	TaroHeavy = { guardDamage = 46 },
	TaroOverhand = { guardDamage = 26 },
})
Moves.TaroParry = move({ -- crouch + E: guard-cancelling parry, counters any standing attack
	id = "TaroParry", name = "PARRY", kind = "Special", startup = 2, active = 14, recovery = 22,
	damage = 0, guardDamage = 0, hitstun = 0, blockstun = 0, hitstop = 0, push = 0, blockPush = 0,
	parry = { from = 3, to = 12, counter = "TaroCounter" },
})
Moves.TaroCounter = move({ -- the counter punch of a successful parry
	id = "TaroCounter", name = "COUNTER", kind = "Special", startup = 3, active = 4, recovery = 20,
	damage = 80, guardDamage = 20, hitstun = 30, blockstun = 16, hitstop = 14,
	push = 26, blockPush = 18, lunge = 8, launch = 24, knockdown = true,
	hitbox = { near = 0, far = 3.9, low = 1, high = 6.2 },
	heavy = true,
})

-- DROITE DU CHAMPION (crouch + E in the CLASSIQUE stance): a slow, wound-up straight that
-- crushes the guard and knocks down.
Moves.TaroChampion = move({
	id = "TaroChampion", name = "CHAMPION'S RIGHT", kind = "Special", startup = 14, active = 4, recovery = 22,
	damage = 95, guardDamage = 60, hitstun = 28, blockstun = 20, hitstop = 14,
	push = 30, blockPush = 24, lunge = 14, launch = 20, knockdown = true,
	hitbox = { near = 0.2, far = 4.0, low = 2.2, high = 5.0 },
	heavy = true,
})

-- DEMPSEY ROLL (out of TARO's weave): figure-eight hooks, left and right, each one ducking
-- under high attacks (slip) and stepping in; L continues, R ends on the finishing hook.
local function dempseyHook(id, other)
	return move({
		id = id, name = "DEMPSEY ROLL", startup = 6, active = 3, recovery = 13,
		damage = 40, guardDamage = 10, hitstun = 22, blockstun = 12, hitstop = 7,
		push = 5, blockPush = 11, lunge = 12,
		hitbox = { near = 0.2, far = 3.5, low = 2.4, high = 4.9 },
		slip = { from = 1, to = 5 }, dempsey = true,
		cancels = { Light = other, Heavy = "TaroDempseyFinish" },
	})
end
Moves.TaroDempseyL = dempseyHook("TaroDempseyL", "TaroDempseyR")
Moves.TaroDempseyR = dempseyHook("TaroDempseyR", "TaroDempseyL")
Moves.TaroDempseyFinish = move({
	id = "TaroDempseyFinish", name = "DEMPSEY · FINAL HOOK", startup = 9, active = 4, recovery = 24,
	damage = 105, guardDamage = 26, hitstun = 30, blockstun = 16, hitstop = 14,
	push = 44, blockPush = 20, lunge = 10, launch = 18, wallBounce = true,
	hitbox = { near = 0.2, far = 3.8, low = 2.0, high = 5.2 },
	slip = { from = 1, to = 4 }, dempsey = true, finisher = true, heavy = true,
})

-- ===================================================================== ZEPHYR 風 · kicks
-- Feet only. The longest reach, the highest jump and the fastest walk; kicks wind up a frame
-- longer. Crouch + E throws a blade of wind from a kick.
local ZEPHYR = {
	Jab = "ZephyrFront", Cross = "ZephyrSide", Elbow = "ZephyrRound", Kick = "ZephyrHigh",
	BodyBlow = "ZephyrPlexus", Uppercut = "ZephyrRiser", PalmStrike = "ZephyrHeel",
	DragonTornado = "ZephyrCyclone", DragonFist = "ZephyrSkyward", CrescentMoon = "ZephyrCrescent",
	RisingWind = "ZephyrGust", KiFlurry = "ZephyrHundred", ThunderHeel = "ZephyrSkyHeel",
	SpinKick = "ZephyrBackSpin", Smash = "ZephyrPush", Hammer = "ZephyrAxe", Sweep = "ZephyrSweep",
	LowKick = "ZephyrLow", AirKick = "ZephyrAirKick", AirKick2 = "ZephyrAirKick2", AirSmash = "ZephyrDiveKick",
	Rising = "ZephyrEnvol", KiChase = "ZephyrChase", Finale = "ZephyrFinale", KiBlast = "ZephyrBlade",
	KaienRush = "ZephyrRush", Awakening = "ZephyrAwakening", Kaiten = "ZephyrGate", Fatal = "ZephyrFatal",
}
derive(ZEPHYR, {
	ZephyrFront = "FRONT KICK", ZephyrSide = "SIDE KICK", ZephyrRound = "ROUNDHOUSE", ZephyrHigh = "HIGH KICK",
	ZephyrPlexus = "PLEXUS KICK", ZephyrRiser = "RISING KICK", ZephyrHeel = "PIERCING HEEL",
	ZephyrCyclone = "CYCLONE", ZephyrSkyward = "TRIPLE FLIGHT", ZephyrCrescent = "AZURE CRESCENT",
	ZephyrGust = "SQUALL", ZephyrHundred = "HUNDRED KICKS", ZephyrSkyHeel = "HEAVEN HEEL",
	ZephyrBackSpin = "SPINNING BACK KICK", ZephyrPush = "PUSH KICK", ZephyrAxe = "AXE KICK", ZephyrSweep = "REAP",
	ZephyrLow = "LOW FOOT", ZephyrAirKick = "AIR FOOT", ZephyrAirKick2 = "DOUBLE AIR", ZephyrDiveKick = "FALCON DIVE",
	ZephyrEnvol = "TAKEOFF", ZephyrChase = "WIND DIVE", ZephyrFinale = "FINAL BLADE", ZephyrBlade = "WIND BLADE",
	ZephyrRush = "CUTTING WIND", ZephyrAwakening = "RISING DRAGON", ZephyrGate = "旋風 · RAGING CYCLONE", ZephyrFatal = "嵐 · MOONFALL",
}, { damage = 1.08, startup = 0, reach = 1.12, recovery = 2 }, {
	ZephyrBlade = { startup = 11, projectile = { speed = 36, life = 75, damage = 58, halfHeight = 0.7 } },
	ZephyrPush = { push = 36 },
})

-- CLASH STEP (ZEPHYR, kit.ClashStep): his body leaves the line of the blow (untouchable while
-- it passes), then a reflex kick that sends the opponent away. Built so that both are free
-- again at about the same time, far apart: back to neutral, never a combo (noCancel).
Moves.ZephyrClashStep = move({
	id = "ZephyrClashStep", name = "CLASH STEP", kind = "Special", startup = 7, active = 3, recovery = 22,
	damage = 40, guardDamage = 8, hitstun = 14, blockstun = 12, hitstop = 8,
	push = 40, blockPush = 34, lunge = 4, noCancel = true,
	invuln = { from = 1, to = 7 },
	hitbox = { near = 0.3, far = 4.6, low = 1.6, high = 5.0 },
	heavy = true,
})

-- ===================================================================== AKEMI 影 · shadow
-- Fast and evasive but fragile: the lowest health, quicker wind-ups, a dash that slips
-- through attacks and the passive VOILE D'OMBRE (like Ultra Instinct: 2 evades in stock, each
-- back in 18 s, sooner when she lands hits, then a counter from behind; see
-- Kits.AKEMI.Passive). Crouch + E throws kunai.
local AKEMI = {
	Jab = "AkemiEdge", Cross = "AkemiPalm", Elbow = "AkemiKnee", Kick = "AkemiFlip",
	BodyBlow = "AkemiPierce", Uppercut = "AkemiRise", PalmStrike = "AkemiMark",
	DragonTornado = "AkemiWhirl", DragonFist = "AkemiFangs", CrescentMoon = "AkemiMoonfall",
	RisingWind = "AkemiTwin", KiFlurry = "AkemiThousand", ThunderHeel = "AkemiStealth",
	SpinKick = "AkemiSpin", Smash = "AkemiThrust", Hammer = "AkemiDrop", Sweep = "AkemiReap",
	LowKick = "AkemiLow", AirKick = "AkemiAirEdge", AirKick2 = "AkemiAirEdge2", AirSmash = "AkemiStoop",
	Rising = "AkemiStep", KiChase = "AkemiChase", Finale = "AkemiFinale", KiBlast = "AkemiKunai",
	KaienRush = "AkemiRush", Awakening = "AkemiAwakening", Kaiten = "AkemiGate", Fatal = "AkemiFatal",
}
derive(AKEMI, {
	AkemiEdge = "KNIFE HAND", AkemiPalm = "PALM", AkemiKnee = "KNEE", AkemiFlip = "SOMERSAULT",
	AkemiPierce = "BREAKTHROUGH", AkemiRise = "SHADOW FLIGHT", AkemiMark = "MARK",
	AkemiWhirl = "SHADOW WHIRL", AkemiFangs = "TRIPLE FANG", AkemiMoonfall = "LUNAR FALL",
	AkemiTwin = "TWIN BLADES", AkemiThousand = "THOUSAND CUTS", AkemiStealth = "STEALTH HEEL",
	AkemiSpin = "SPIN DRILL", AkemiThrust = "THRUST", AkemiDrop = "FALL", AkemiReap = "REAPER",
	AkemiLow = "LOW BLOW", AkemiAirEdge = "AIR BLADE", AkemiAirEdge2 = "DOUBLE BLADE", AkemiStoop = "NOSEDIVE",
	AkemiStep = "SHADOW STEP", AkemiChase = "HUNT", AkemiFinale = "EXECUTION", AkemiKunai = "KUNAI",
	AkemiRush = "MANY SHADOWS", AkemiAwakening = "TIME STOP", AkemiGate = "幻舞 · PHANTOM DANCE", AkemiFatal = "刻 · STOLEN INSTANT",
}, { damage = 0.94, startup = 0, reach = 1 }, {
	AkemiStep = { lunge = 26, invuln = { from = 1, to = 11 }, damage = 80 },
	AkemiKunai = { startup = 11, projectile = { speed = 40, life = 55, damage = 40, halfHeight = 0.6, halfWidth = 0.7 } },
})

-- ===================================================================== RYUKEN 拳 · le poing brisé
-- Brute force and pressure: heavier fists, a frontal charge that crosses the screen, a
-- seismic strike along the floor (crouch + E, low) and the passive RAGE (every hit landed
-- adds a stack of damage, lost when he is hit). From Wilhem's character sheet.
local RYUKEN = {
	Jab = "RyukenJab", Cross = "RyukenHook", Elbow = "RyukenBreaker", Kick = "RyukenChain",
	BodyBlow = "RyukenGut", Uppercut = "RyukenUppercut", PalmStrike = "RyukenPound",
	DragonTornado = "RyukenRage", DragonFist = "RyukenRising", CrescentMoon = "RyukenSlam",
	RisingWind = "RyukenStorm", KiFlurry = "RyukenBarrage", ThunderHeel = "RyukenCrash",
	SpinKick = "RyukenSpin", Smash = "RyukenHeavy", Hammer = "RyukenHammer", Sweep = "RyukenSweep",
	LowKick = "RyukenLow", AirKick = "RyukenAirPunch", AirKick2 = "RyukenAirHook", AirSmash = "RyukenAirSlam",
	Rising = "RyukenCharge", KiChase = "RyukenChase", Finale = "RyukenFinale", KiBlast = "RyukenQuake",
	KaienRush = "RyukenRush", Awakening = "RyukenAwakening", Kaiten = "RyukenGate", Fatal = "RyukenFatal",
}
derive(RYUKEN, {
	RyukenJab = "JAB", RyukenHook = "HOOK", RyukenBreaker = "BROKEN ELBOW", RyukenChain = "ONE-TWO",
	RyukenGut = "LIVER FIST", RyukenUppercut = "UPPERCUT", RyukenPound = "POUNDING",
	RyukenRage = "FIST RAGE", RyukenRising = "RISING FIST", RyukenSlam = "SLAM",
	RyukenStorm = "FIST STORM", RyukenBarrage = "SHATTERED FLURRY", RyukenCrash = "FIST DROP",
	RyukenSpin = "SPINNING BACKFIST", RyukenHeavy = "HEAVY FIST", RyukenHammer = "SLEDGE", RyukenSweep = "REAP",
	RyukenLow = "LOW BLOW", RyukenAirPunch = "AIR FIST", RyukenAirHook = "AIR HOOK", RyukenAirSlam = "AIR SLAM",
	RyukenCharge = "HEAD-ON CHARGE", RyukenChase = "PURSUIT", RyukenFinale = "COUP DE GRACE", RyukenQuake = "SEISMIC STRIKE",
	RyukenRush = "FIST FURY", RyukenAwakening = "COLLAPSE", RyukenGate = "拳 · LAST ROUND", RyukenFatal = "砕 · WORLD FIST",
}, { damage = 1.12, startup = 0, reach = 0.95, recovery = -1 }, {
	RyukenCharge = { lunge = 30, invuln = { from = 1, to = 8 }, damage = 96, launch = 20, wallBounce = true },
	RyukenQuake = { startup = 12, projectile = { speed = 34, life = 26, damage = 60, height = 0.6, halfHeight = 0.6,
		halfWidth = 1.1, guard = "Low", guardDamage = 16 } },
})

-- ===================================================================== SHIN 流 · la lame des courants
-- A swordsman: the longest reach of all, quick cuts, PAS DU VENT (a dashing cut that slips
-- through), a current of blade thrown at range (crouch + E) and the passive PRÉCISION (a
-- hit with the tip of the blade, at the end of its reach, deals more).
local SHIN = {
	Jab = "ShinCut1", Cross = "ShinCut2", Elbow = "ShinThrust", Kick = "ShinCombo",
	BodyBlow = "ShinPierce", Uppercut = "ShinRising", PalmStrike = "ShinFlow",
	DragonTornado = "ShinCircle", DragonFist = "ShinSkyCut", CrescentMoon = "ShinCrescent",
	RisingWind = "ShinGale", KiFlurry = "ShinTempest", ThunderHeel = "ShinFalling",
	SpinKick = "ShinSpin", Smash = "ShinBreaker", Hammer = "ShinCleave", Sweep = "ShinReap",
	LowKick = "ShinLow", AirKick = "ShinAirCut", AirKick2 = "ShinAirCut2", AirSmash = "ShinDive",
	Rising = "ShinStep", KiChase = "ShinChase", Finale = "ShinFinale", KiBlast = "ShinCurrent",
	KaienRush = "ShinRush", Awakening = "ShinAwakening", Kaiten = "ShinGate", Fatal = "ShinFatal",
}
derive(SHIN, {
	ShinCut1 = "SLASH 1", ShinCut2 = "SLASH 2", ShinThrust = "THRUST", ShinCombo = "BLADE COMBO",
	ShinPierce = "BREAKTHROUGH", ShinRising = "RISING SLASH", ShinFlow = "CURRENT'S EDGE",
	ShinCircle = "CIRCLE BLADE", ShinSkyCut = "HEAVEN SLASH", ShinCrescent = "STEEL CRESCENT",
	ShinGale = "CUTTING BREATH", ShinTempest = "BLADE STORM", ShinFalling = "BLADE DROP",
	ShinSpin = "WHIRLWIND", ShinBreaker = "GUARD BREAKER", ShinCleave = "CLEAVER", ShinReap = "REAPER",
	ShinLow = "LOW SLASH", ShinAirCut = "AIR SLASH", ShinAirCut2 = "DOUBLE SLASH", ShinDive = "BLADE DIVE",
	ShinStep = "WIND STEP", ShinChase = "PURSUIT", ShinFinale = "FINAL CUT", ShinCurrent = "CUTTING CURRENT",
	ShinRush = "DANCE OF CURRENTS", ShinAwakening = "ENDLESS STORM", ShinGate = "零 · ZERO HORIZON", ShinFatal = "一閃 · ISSEN",
}, { damage = 1.1, startup = 0, reach = 1.17, recovery = 3 }, { -- (nerfed: damage 1.18, reach 1.22, recovery +2 before)
	ShinStep = { lunge = 34, invuln = { from = 1, to = 9 }, damage = 82, launch = 30 },
	ShinBreaker = { guardDamage = 46 },
	ShinCurrent = { startup = 10, projectile = { speed = 48, life = 40, damage = 50, halfHeight = 0.5, halfWidth = 1.4 } },
})

-- ===================================================================== DAICHA 闇 · l'ombre inversée
-- A zoner who bends space: a slow, wide sphere of shadow (crouch + E), TÉLÉPORTATION (the
-- reversal: he reappears behind the opponent) and the passive OMBRE INVERSÉE (a forward
-- dash close to the opponent blinks through to the other side).
local DAICHA = {
	Jab = "DaichaClaw", Cross = "DaichaStep", Elbow = "DaichaThrow", Kick = "DaichaCombo",
	BodyBlow = "DaichaGrip", Uppercut = "DaichaRise", PalmStrike = "DaichaMark",
	DragonTornado = "DaichaDistortion", DragonFist = "DaichaSpire", CrescentMoon = "DaichaEclipse",
	RisingWind = "DaichaVeil", KiFlurry = "DaichaRiver", ThunderHeel = "DaichaFall",
	SpinKick = "DaichaSpin", Smash = "DaichaPush", Hammer = "DaichaDrop", Sweep = "DaichaReap",
	LowKick = "DaichaLow", AirKick = "DaichaAirClaw", AirKick2 = "DaichaAirClaw2", AirSmash = "DaichaDive",
	Rising = "DaichaTeleport", KiChase = "DaichaChase", Finale = "DaichaFinale", KiBlast = "DaichaSphere",
	KaienRush = "DaichaRush", Awakening = "DaichaAwakening", Kaiten = "DaichaGate", Fatal = "DaichaFatal",
}
derive(DAICHA, {
	DaichaClaw = "SHADOW SCRATCH", DaichaStep = "SLANT STEP", DaichaThrow = "THROW", DaichaCombo = "SHADOW COMBO",
	DaichaGrip = "EMBRACE", DaichaRise = "RISING SHADOW", DaichaMark = "DARK MARK",
	DaichaDistortion = "DISTORTION", DaichaSpire = "SHADOW ARROW", DaichaEclipse = "HALF ECLIPSE",
	DaichaVeil = "INVERTED VEIL", DaichaRiver = "SHADOW CURRENT", DaichaFall = "INVERTED FALL",
	DaichaSpin = "SPIN DRILL", DaichaPush = "SHOVE", DaichaDrop = "FALL", DaichaReap = "REAPER",
	DaichaLow = "LOW CLAW", DaichaAirClaw = "AIR CLAW", DaichaAirClaw2 = "DOUBLE CLAW", DaichaDive = "SHADOW DIVE",
	DaichaTeleport = "TELEPORT", DaichaChase = "PURSUIT", DaichaFinale = "BACK TO THE VOID", DaichaSphere = "INVERTED SPHERE",
	DaichaRush = "DARK DOMAIN", DaichaAwakening = "RIVER OF SHADOWS", DaichaGate = "蝕 · TOTAL ECLIPSE", DaichaFatal = "虚 · THE VOID",
}, { damage = 1.25, startup = 0, reach = 1.05 }, {
	-- (limited range, 2 s before the next one, shorter invulnerability: no more teleport on every click)
	DaichaTeleport = { lunge = 0, invuln = { from = 1, to = 8 }, teleport = 1.7, teleportRange = 9, teleportCooldown = 120,
		damage = 70, launch = 26, recovery = 32 },
	DaichaSphere = { startup = 14, projectile = { speed = 16, life = 140, damage = 72, height = 3.4, halfHeight = 1.3, halfWidth = 1.3 } },
})

-- ===================================================================== HIBECARES 崩 · le roi des ruines
-- The tank: the most health, slow and heavy blows, MUR DE PIERRE (crouch + E: a wall of
-- stone that takes the blow, half the damage, low attacks too, then hits back) and the
-- passive ROI DES RUINES (the lower his health, the harder he hits).
local HIBECARES = {
	Jab = "HibecaresStrike", Cross = "HibecaresBash", Elbow = "HibecaresElbow", Kick = "HibecaresChain",
	BodyBlow = "HibecaresGrab", Uppercut = "HibecaresUpper", PalmStrike = "HibecaresPress",
	DragonTornado = "HibecaresRupture", DragonFist = "HibecaresPillar", CrescentMoon = "HibecaresQuake",
	RisingWind = "HibecaresAvalanche", KiFlurry = "HibecaresRubble", ThunderHeel = "HibecaresStomp",
	SpinKick = "HibecaresSwing", Smash = "HibecaresHeavy", Hammer = "HibecaresBreaker", Sweep = "HibecaresSweep",
	LowKick = "HibecaresLow", AirKick = "HibecaresAirFist", AirKick2 = "HibecaresAirSwing", AirSmash = "HibecaresMeteor",
	Rising = "HibecaresShock", KiChase = "HibecaresChase", Finale = "HibecaresFinale",
	KaienRush = "HibecaresRush", Awakening = "HibecaresAwakening", Kaiten = "HibecaresGate", Fatal = "HibecaresFatal",
}
derive(HIBECARES, {
	HibecaresStrike = "STRIKE", HibecaresBash = "SLEDGEHAMMER", HibecaresElbow = "STONE ELBOW", HibecaresChain = "ONE-TWO",
	HibecaresGrab = "WRECKING GRAB", HibecaresUpper = "UPHEAVAL", HibecaresPress = "CRUSH",
	HibecaresRupture = "RUPTURE", HibecaresPillar = "STONE PILLAR", HibecaresQuake = "EARTHQUAKE",
	HibecaresAvalanche = "AVALANCHE", HibecaresRubble = "RUBBLE RAIN", HibecaresStomp = "STOMP",
	HibecaresSwing = "CHAIN BACKHAND", HibecaresHeavy = "HEAVY BLOW", HibecaresBreaker = "GUARD BREAKER", HibecaresSweep = "SWEEP",
	HibecaresLow = "LOW BLOW", HibecaresAirFist = "AIR FIST", HibecaresAirSwing = "AIR CHAIN", HibecaresMeteor = "ROCKFALL",
	HibecaresShock = "SHOCKWAVE", HibecaresChase = "PURSUIT", HibecaresFinale = "KING'S COLLAPSE",
	HibecaresRush = "AWAKENED COLOSSUS", HibecaresAwakening = "PUNISHMENT", HibecaresGate = "崩 · RUIN OF THE WORLD", HibecaresFatal = "墓 · TOMB OF KINGS",
}, { damage = 0.9, startup = 1, reach = 1, recovery = 2 }, {
	HibecaresBreaker = { guardDamage = 40 },
	HibecaresGrab = { guardDamage = 30 },
	HibecaresShock = { lunge = 4, invuln = { from = 1, to = 10 }, launch = 30, hitbox = { near = 0, far = 4.6, low = 0, high = 6.5 } },
})
Moves.HibecaresWall = move({ -- crouch + E: a wall of stone; takes the blow (half damage) and hits back
	id = "HibecaresWall", name = "STONE WALL", kind = "Special", startup = 3, active = 16, recovery = 26,
	damage = 0, guardDamage = 0, hitstun = 0, blockstun = 0, hitstop = 0, push = 0, blockPush = 0,
	parry = { from = 3, to = 16, counter = "HibecaresCounter", absorb = 0.5, lows = true },
})
Moves.HibecaresCounter = move({ -- the wall bursts toward the attacker
	id = "HibecaresCounter", name = "RUINS' RIPOSTE", kind = "Special", startup = 4, active = 5, recovery = 22,
	damage = 90, guardDamage = 26, hitstun = 30, blockstun = 16, hitstop = 14,
	push = 30, blockPush = 20, lunge = 6, launch = 26, knockdown = true,
	hitbox = { near = 0, far = 4.2, low = 0, high = 6 },
	heavy = true,
})

-- ASURA's ground special (E): GATLING DES QUATRE BRAS, a storm of straights from four arms
-- that pins the target in place and ends by knocking it down.
Moves.AsuraGatling = move({
	id = "AsuraGatling", name = "FOUR-ARMED GATLING", kind = "Special", startup = 10, active = 26, recovery = 24,
	hits = 12, hitInterval = 2, damage = 9, guardDamage = 4, hitstun = 26, blockstun = 10, hitstop = 10,
	multiHitstop = 1, holdVy = 0, multiPush = 0.5,
	push = 34, blockPush = 18, lunge = 8, knockdown = true,
	hitbox = { near = 0.2, far = 4.2, low = 0.6, high = 7 },
	heavy = true,
})

-- ===================================================================== WILHEM'S THIRD SHEET
--[[
	Twelve kits on the same combo grammar, written compactly: `newKit(prefix, names, tuning,
	overrides)` names every role `<Prefix><Role>` (RaijinJab, YukinaKaienRush...) from a list
	of 29 names in ROLE_ORDER. Each kit changes what makes it itself: its crouch special (the
	S + E of the sheet), reach, speed, damage, and its passive (CombatSimulation PASSIVE).
]]
local ROLE_ORDER = {
	"Jab", "Cross", "Elbow", "Kick", "BodyBlow", "Uppercut", "PalmStrike", "DragonTornado", "DragonFist", "CrescentMoon",
	"RisingWind", "KiFlurry", "ThunderHeel", "SpinKick", "Smash", "Hammer", "Sweep", "LowKick", "AirKick", "AirKick2",
	"AirSmash", "Rising", "KiChase", "Finale", "KiBlast", "KaienRush", "Awakening", "Kaiten", "Fatal",
}
local THIRD = {} -- name -> { roles, names } (used by the kit() calls below)
local function newKit(name, prefix, list, tuning, overrides)
	assert(#list == #ROLE_ORDER, name .. ": " .. #list .. " names")
	local roles, names, byRole = {}, {}, {}
	for i, role in ROLE_ORDER do
		local id = prefix .. role
		roles[role], names[id], byRole[role] = id, list[i], list[i]
	end
	local own = {}
	for role, fields in overrides do own[prefix .. role] = fields end
	derive(roles, names, tuning, own)
	THIRD[name] = { roles = roles, names = byRole }
	return roles
end

-- RAIJIN 雷: a lightning spear. Long thrusts; LANCE FOUDROYANTE (S + E) pierces across the screen.
newKit("RAIJIN", "Raijin", {
	"THRUST", "SHAFT BACKHAND", "LOW STRIKE", "FINAL THRUST", "GUT PIERCE", "SPEAR LIFT", "DISCHARGE",
	"THUNDER DRAGON", "THUNDER FANG", "ELECTRIC ARC", "STORM WIND", "THOUSAND THRUSTS", "LIGHTNING FALL",
	"SHAFT SWEEP", "HEAVY THRUST", "DOWNWARD STRIKE", "LOW REAP", "LOW PIKE", "AIR THRUST", "AIR BACKHAND",
	"THUNDER DIVE", "RISING BOLT", "ELECTRIC CHASE", "THUNDERCLAP", "LIGHTNING SPEAR",
	"THOUSAND BOLTS", "THUNDER JUDGMENT", "雷神 · DIVINE WRATH", "天罰 · HEAVENLY SENTENCE",
}, { damage = 1.06, startup = 0, reach = 1.15, recovery = 2 }, {
	KiBlast = { startup = 14, projectile = { speed = 50, life = 46, damage = 62, halfWidth = 1.3, guardDamage = 16 } },
})
-- YUKINA 雪: two fans of ice. Dances round the target; MIROIR DE GLACE (S + E) sends projectiles back.
newKit("YUKINA", "Yukina", {
	"FAN", "FAN BACKHAND", "FROST BLADE", "ICE DANCE", "HEART SHARD", "SNOW LIFT", "FROZEN BREATH",
	"SNOW WHIRL", "STALAGMITE", "ICE CRESCENT", "BLIZZARD", "NEEDLE RAIN", "FROST STEP",
	"SPINNING FAN", "ICY CUT", "HAILFALL", "SKATE", "FROZEN LOW BLOW", "AIR FAN", "DOUBLE FAN",
	"AVALANCHE", "ICE SPIKE", "WHITE CHASE", "CRYSTALLIZE", "ICE SHARDS",
	"ICE GARDEN", "WINTER WALTZ", "氷獄 · ETERNAL PRISON", "絶対零度 · ABSOLUTE ZERO",
}, { damage = 1.05, startup = 0, reach = 1.05, recovery = -2 }, {
	KiBlast = { projectile = { speed = 24, life = 80, damage = 52 } },
})
Moves.YukinaMirror = move({ -- crouch + E: a mirror of ice that sends projectiles back to their thrower
	id = "YukinaMirror", name = "ICE MIRROR", kind = "Special", startup = 3, active = 18, recovery = 20,
	damage = 0, guardDamage = 0, hitstun = 0, blockstun = 0, hitstop = 0, push = 0, blockPush = 0,
	reflect = { from = 3, to = 21 },
})
-- VENOM 毒: green claws and poison. Fast, wears the target down; BRUME TOXIQUE (S + E) is a slow cloud.
newKit("VENOM", "Venom", {
	"CLAW", "CLAWED BACKHAND", "LACERATE", "PREDATOR RUSH", "GUT FANG", "RIP", "INJECTION", "FRENZY",
	"RISING BITE", "VENOM CRESCENT", "TOXIC SPIRAL", "THOUSAND CLAWS", "SNAKE TRAP", "CLAW WHIP",
	"HEAVY CLAW", "CRUSH", "CREEPING REAP", "LOW CLAW", "AIR CLAW", "DOUBLE CLAW",
	"PREDATOR DIVE", "VENOM LEAP", "HUNT", "LAST BITE", "TOXIC MIST",
	"FATAL BITE", "EPIDEMIC", "毒王 · VENOM KING", "蝕 · TOTAL CORROSION",
}, { damage = 0.9, startup = -1, reach = 0.95, recovery = -1 }, {
	KiBlast = { startup = 10, projectile = { speed = 10, life = 130, damage = 36, halfWidth = 1.8, halfHeight = 1.8, hitstun = 18,
		push = 4, guardDamage = 8 } },
})
-- GORAN 剛: the wrestler. Slow and huge; grabs that go through guards, ÉTREINTE DU TITAN (S + E).
newKit("GORAN", "Goran", {
	"FOREARM SMASH", "FOREARM", "ELBOW STRIKE", "CLOTHESLINE", "CHOKEHOLD", "TITAN LIFT", "HEADBUTT", "SUPLEX",
	"TITAN UPPERCUT", "BACK SUPLEX", "SPINNING THROW", "POUNDING", "KNEE DROP", "LARIAT",
	"COLOSSUS STRIKE", "HAMMER", "TITAN SWEEP", "SHIN KICK", "AIR GRAPPLE", "AIR ELBOW",
	"COLOSSUS DROP", "TITAN CHARGE", "AIR GRAB", "POWERBOMB", "TITAN'S HUG",
	"APOCALYPSE SUPLEX", "SPINE BREAKER", "巨神 · FALL OF THE TITAN", "終幕 · FINAL THROW",
}, { damage = 0.86, startup = 1, reach = 0.95, recovery = 3 }, {
	BodyBlow = { grab = true, damage = 70, knockdown = true, hitbox = { near = 0, far = 2.6, low = 0.5, high = 5.5 } },
})
Moves.GoranGrab = move({ -- crouch + E: ÉTREINTE DU TITAN, seized and thrown over his shoulder (not blockable)
	id = "GoranGrab", name = "TITAN'S HUG", kind = "Special", startup = 5, active = 3, recovery = 32,
	damage = 130, guardDamage = 0, hitstun = 30, blockstun = 0, hitstop = 14, push = 30, blockPush = 0,
	launch = 24, knockdown = true, grab = true,
	hitbox = { near = 0, far = 2.7, low = 0.5, high = 5.5 },
	heavy = true,
})
-- ASTER 星: gravity. ATTRACTION (S + E) pulls the target in; gravity hits charge his air attacks.
newKit("ASTER", "Aster", {
	"IMPULSE", "RING", "PRESSURE", "SHORT ORBIT", "HEART MASS", "WEIGHTLESS", "STELLAR PUSH",
	"GALACTIC SPIRAL", "RISING COMET", "LUNAR CRESCENT", "SOLAR WIND", "STAR RAIN", "MASS DROP",
	"SPINNING RING", "GRAVE STRIKE", "CRUSH", "GLIDE", "LOW PRESSURE", "AIR IMPULSE", "AIR RING",
	"STARFALL", "ELEVATION", "ORBIT", "SUPERNOVA", "PULL",
	"DEADLY ORBIT", "STELLAR COLLAPSE", "重力 · EVENT HORIZON", "星葬 · COSMIC FUNERAL",
}, { damage = 1.08, startup = 0, reach = 1.05 }, {
	KiBlast = { projectile = { speed = 26, life = 70, damage = 44, pull = 30, push = 0, hitstun = 26 } },
})
-- HIBIKI 響: sound and rhythm. Quick, and quicker still in TEMPO; ONDE SONIQUE (S + E) blows the target away.
newKit("HIBIKI", "Hibiki", {
	"BEAT", "OFFBEAT", "SNARE", "BREAKDANCE", "BODY BASS", "DROP", "SOUND PULSE", "REMIX", "CRESCENDO",
	"SCRATCH", "FEEDBACK", "NOTE FLURRY", "KICK DRUM", "PIROUETTE", "FORTISSIMO", "BASS DROP", "GLISSANDO", "LOW BLOW",
	"AIR NOTE", "SIXTEENTH NOTE", "TEMPO DROP", "AMP", "ECHO", "MAJOR FINALE", "SONIC WAVE",
	"BRUTAL SYMPHONY", "FORBIDDEN FREQUENCY", "絶響 · LAST RESONANCE", "無音 · ABSOLUTE SILENCE",
}, { damage = 0.94, startup = -1, reach = 1, recovery = -3 }, {
	KiBlast = { startup = 9, projectile = { speed = 38, life = 36, damage = 48, halfHeight = 1.8, push = 42, blockPush = 30 } },
})
-- KUROEN 蝕: the emperor of the eclipse. Fists, elbows, knees, short bursts of red and black ki.
-- A technical rushdown: CRIMSON STEP (E) closes in (never invincible), ECLIPSE BREAKER (S + E) a
-- charged blow, TYRANT'S FIST (skill) only goes on if its first blow lands. DOMINATION (see
-- the kit below and CombatSimulation) changes what his combos can do, not how hard he hits.
newKit("KUROEN", "Kuroen", {
	"JAB", "STRAIGHT", "ELBOW CRUSH", "KNEE STRIKE", "LIVER SHOT", "RISING UPPER", "UMBRA PALM",
	"CRIMSON SPIRAL", "SOVEREIGN UPPER", "BLACK CRESCENT", "ECLIPSE KICK", "TYRANT'S FIST", "FALLING EMPEROR",
	"SPINNING HEEL", "CROWN BREAKER", "AXE OF NIGHT", "LOW SWEEP", "SHIN KICK", "AIR KNEE", "AIR HEEL",
	"METEOR ELBOW", "CRIMSON STEP", "DARK PURSUIT", "EMPEROR'S DECREE", "ECLIPSE BREAKER",
	"EMPEROR RUSH", "零 · ZERO ABSOLU: ECLIPSE", "皇 · EMPEROR'S GATE", "蝕 · TOTAL ECLIPSE",
}, { damage = 0.94, startup = -1, reach = 1.0, recovery = 1 }, {
	-- CRIMSON STEP (E): a fast step in and a blow. Not invincible (no free reversal), long recovery:
	-- thrown carelessly it is punished.
	Rising = { invuln = false, startup = 10, lunge = 30, recovery = 32, damage = 72, launch = 26, jumpCancel = false },
	-- TYRANT'S FIST: the flurry only goes on if its first blow lands (CombatSimulation: confirm).
	KiFlurry = { confirm = true, startup = 8 },
	-- ECLIPSE BREAKER (S + E): a blow charged in the arm (a visible wind-up), a finisher or a punish.
	KiBlast = { projectile = false, startup = 20, active = 4, recovery = 34, damage = 128, guardDamage = 34,
		hitstun = 30, blockstun = 16, hitstop = 14, push = 34, blockPush = 22, lunge = 10, launch = 22, wallBounce = true,
		heavy = true, charge = true, hitbox = { near = 0.3, far = 4.0, low = 1.6, high = 5.6 } },
})
-- DOMINATION I (ÉVEIL): CRIMSON STEP becomes EMPEROR STEP: two blows, a quicker recovery. Costs a level.
Moves.KuroenEmperorStep = move({
	id = "KuroenEmperorStep", name = "EMPEROR STEP", kind = "Special", startup = 8, active = 8, recovery = 20,
	hits = 2, hitInterval = 5, damage = 44, guardDamage = 12, hitstun = 26, blockstun = 14, hitstop = 10, multiHitstop = 4,
	push = 10, blockPush = 16, lunge = 34, launch = 30,
	hitbox = { near = 0.2, far = 3.8, low = 1.0, high = 6.0 }, heavy = true,
})
-- KAZAN 鎖: the jailer turned predator. Two steel claws, three long blades on each hand: rakes,
-- crossed rends, rising talons, heavy maulings, both hands in turn. Pressure at short and middle
-- range. SHACKLE HOOK (S + E): the claws catch the opponent and hold it a moment (the shackle).
newKit("KAZAN", "Kazan", {
	"RAKE", "BACKHAND RAKE", "CLAW JAB", "CROSS REND", "GUT CLAW", "RISING TALON", "TWIN GOUGE",
	"CLAW CYCLONE", "SKY TALON", "CRESCENT REND", "PREDATOR RUSH", "THOUSAND CUTS", "FALLING TALON",
	"SPINNING REND", "MAULER", "SKULL SPLITTER", "LOW REND", "ANKLE CLAW", "AIR RAKE", "AIR CROSS",
	"TALON DIVE", "RISING CLAWS", "HUNTER'S CHASE", "EXECUTION", "SHACKLE HOOK",
	"PREDATOR'S FEAST", "IRON FANGS", "鎖獄 · CLAW PRISON", "断罪 · FINAL VERDICT",
}, { damage = 0.97, startup = -1, reach = 1.05, recovery = 0 }, {
	-- SHACKLE HOOK: a lunge, the claws hook the body and hold it (bind) for a follow-up.
	KiBlast = { projectile = false, startup = 13, active = 4, recovery = 28, damage = 46, guardDamage = 10,
		hitstun = 20, blockstun = 14, hitstop = 10, push = 2, blockPush = 18, lunge = 18, bind = 34,
		hitbox = { near = 0.2, far = 3.6, low = 1.2, high = 5.4 } },
})
-- KUREN 血: blood. Every special costs blood and hits harder; LANCE SANGUINE (S + E) is the fastest throw.
newKit("KUREN", "Kuren", {
	"GASH", "SCARLET BACKHAND", "BLEED", "CRIMSON DANCE", "PERFORATE", "GEYSER", "BLOOD PALM", "SCARLET VORTEX",
	"BLOOD PIKE", "RED CRESCENT", "HEMORRHAGE", "THORN SHOWER", "CLOT", "BLOOD WHIP", "PACT STRIKE",
	"CRUOR HAMMER", "RED REAP", "LOW GASH", "AIR TALON", "DOUBLE GASH", "SCARLET FALL",
	"BLOOD ASCENT", "RED HUNT", "OFFERING", "BLOOD LANCE",
	"SCARLET RAIN", "FORBIDDEN PACT", "血王 · BLOOD THRONE", "血月 · BLOOD MOON",
}, { damage = 1.24, startup = 0, reach = 1.05, recovery = -1 }, {
	KiBlast = { startup = 11, projectile = { speed = 54, life = 42, damage = 70, halfWidth = 1.1 } },
})
-- SYLVA 森: the huntress. Traps on the floor; RACINES VORACES (S + E) slow and hurt who steps on them.
newKit("SYLVA", "Sylva", {
	"BRAMBLE", "LEAFY BACKHAND", "THORN", "VINE LASH", "BARK", "SPROUT", "SAP", "LEAF WHIRL",
	"RISING ROOT", "VINE CRESCENT", "FOREST WIND", "THORN RAIN", "STUMP", "VINE WHIP", "TRUNK SLAM",
	"BRANCH FALL", "CREEPING ROOT", "LOW THORN", "LYNX POUNCE", "DOUBLE TALON", "FALCON DROP",
	"GERMINATION", "THE HUNT", "BLOSSOM", "HUNGRY ROOTS",
	"HOSTILE FOREST", "WILD GRASP", "森王 · BRAMBLE DOMAIN", "世界樹 · THE LAST TREE",
}, { damage = 0.98, startup = 0, reach = 1.1 }, {
	KiBlast = { startup = 10, recovery = 20, projectile = { speed = 0, life = 420, spawnX = 3.6, height = 0.4, halfWidth = 1.3,
		halfHeight = 0.6, damage = 50, hitstun = 22, bind = 24, push = 0, trap = true, slow = { ticks = 120, amount = 0.35 },
		guard = "Low" } },
})
-- ELIAN 癒: the healer. Light and care; IMPULSION VITALE (S + E) pushes away and heals him a little.
newKit("ELIAN", "Elian", {
	"PALM", "SHINING BACKHAND", "BLESSING", "GRACE STEP", "LAYING OF HANDS", "ELEVATION", "HOLY PALM",
	"LIGHT SPIRAL", "RISING RAY", "HALO", "DIVINE BREATH", "PRAYER FLURRY", "ANGEL FALL",
	"HOLY SPIN", "HOLY STRIKE", "JUDGMENT", "LIGHT REAP", "LOW BLOW", "FEATHER", "DOUBLE FEATHER",
	"HEAVENFALL", "ASCENSION", "SEEKING LIGHT", "ABSOLUTION", "RAY",
	"REBIRTH", "PURIFICATION", "神癒 · DIVINE MIRACLE", "天光 · LAST LIGHT",
}, { damage = 1.02, startup = 0, reach = 1, recovery = -1 }, {})
Moves.ElianPulse = move({ -- crouch + E: IMPULSION VITALE, a close wave that pushes away and heals him
	id = "ElianPulse", name = "VITAL PULSE", kind = "Special", startup = 8, active = 4, recovery = 24,
	damage = 50, guardDamage = 10, hitstun = 20, blockstun = 14, hitstop = 8, push = 36, blockPush = 32,
	heal = 0.04,
	hitbox = { near = 0, far = 3.4, low = 0, high = 6 },
})
-- NOVA 機: the engineer. Mechanical gauntlets and two drones; SENTINELLE (S + E) fires on its own.
newKit("NOVA", "Nova", {
	"GAUNTLET", "MECH BACKHAND", "PISTON", "SERVO COMBO", "DRILL", "THRUSTER", "DISCHARGE", "TURBINE",
	"RISING CANNON", "PLASMA ARC", "DRONE BARRAGE", "GRAPESHOT", "HYDRAULIC HAMMER", "ROTOR", "IMPACT", "PRESS",
	"SLIDE", "LOW BLOW", "AIR BOOST", "DOUBLE PISTON", "BOMB", "LIFTOFF", "LOCK-ON", "OVERHEAT",
	"DRONE SHOT", "SATURATION", "OMEGA PROTOCOL", "機神 · MECHANICAL ARMY", "終焉 · PROGRAMMED EXTINCTION",
}, { damage = 1.05, startup = 0, reach = 1, recovery = -1 }, {})
local droneShot = {
	id = "NovaDroneShot", name = "SENTRY SHOT", kind = "Special", guard = "Mid", launch = 0,
	speed = 40, life = 50, spawnX = 0, height = 3.4, halfWidth = 0.6, halfHeight = 0.6,
	damage = 30, guardDamage = 6, hitstun = 16, blockstun = 10, hitstop = 6, push = 6, blockPush = 8,
}
Moves.NovaSentinel = move({ -- crouch + E: SENTINELLE, a drone that fires `shots` times on its own (INGÉNIERIE)
	id = "NovaSentinel", name = "SENTRY", kind = "Special", startup = 10, active = 2, recovery = 20,
	damage = 0, guardDamage = 0, hitstun = 0, blockstun = 0, hitstop = 0, push = 0, blockPush = 0,
	drone = table.freeze({ shots = 3, delay = 24, every = 36, projectile = table.freeze(droneShot) }),
})

MoveData.Moves = table.freeze(Moves)

-- ===================================================================== kits

local KAI_STARTERS = {
	Ground = { Light = "Jab", Heavy = "Smash", Special = "Rising", Ultimate = "KaienRush" },
	Crouch = { Light = "LowKick", Heavy = "Uppercut", Special = "KiBlast", Ultimate = "KaienRush" },
	Air = { Light = "AirKick", Heavy = "AirSmash" },
}
-- Combo routes (L = clic gauche, R = clic droit): the grammar shared by every kit.
local ROUTES = {
	{ keys = "L L L L", moves = { "Jab", "Cross", "Elbow", "Kick" } },
	{ keys = "L L R ↑", moves = { "Jab", "Cross", "Uppercut" } },
	{ keys = "L R", moves = { "Jab", "BodyBlow" } },
	{ keys = "L L L R", moves = { "Jab", "Cross", "Elbow", "SpinKick" } },
	{ keys = "R R", moves = { "Smash", "Hammer" } },
	{ keys = "R L", moves = { "Smash", "Sweep" } },
	{ keys = "L R L R", moves = { "Jab", "BodyBlow", "PalmStrike", "DragonTornado" }, skill = true },
	{ keys = "R L R L", moves = { "Smash", "Sweep", "RisingWind", "KiFlurry" }, skill = true },
	{ keys = "L L R R", moves = { "Jab", "Cross", "Uppercut", "DragonFist" }, skill = true },
	{ keys = "R R L R", moves = { "Smash", "Hammer", "ThunderHeel", "DragonFist" }, skill = true },
	{ keys = "L L L L R", moves = { "Jab", "Cross", "Elbow", "Kick", "CrescentMoon" }, skill = true },
}
-- The six 6-press routes; `finale` is the ending staged by the ÉVEIL cinematic.
local FULL_ROUTES = {
	{ keys = "L R L R L R", finale = "TORNADO", moves = { "Jab", "BodyBlow", "PalmStrike", "DragonTornado", "KiChase", "Finale" } },
	{ keys = "R L R L L R", finale = "GUST", moves = { "Smash", "Sweep", "RisingWind", "KiFlurry", "KiChase", "Finale" } },
	{ keys = "L L R R L R", finale = "DRAGON", moves = { "Jab", "Cross", "Uppercut", "DragonFist", "KiChase", "Finale" } },
	{ keys = "R R L R L R", finale = "THUNDER", moves = { "Smash", "Hammer", "ThunderHeel", "DragonFist", "KiChase", "Finale" } },
	{ keys = "L L L R L R", finale = "WALL", moves = { "Jab", "Cross", "Elbow", "SpinKick", "KiChase", "Finale" } },
	{ keys = "L L L L R R", finale = "MOON", moves = { "Jab", "Cross", "Elbow", "Kick", "CrescentMoon", "Finale" } },
}

-- Scripted cinematics of KAI (the other kits reuse the timing, see below).
local CINEMATICS = {
	KaienRush = {
		Type = "Rush",
		Length = 150,
		FinalTick = 118,
		Hits = { 22, 30, 37, 44, 51, 58, 65, 72, 80, 88, 96 },
		HitDamage = 16,
		FinalDamage = 130,
		MinScaling = 0.5,
	},
	-- 開天 · PORTE DES CIEUX: a gate drags the target into a crimson world for one blow.
	-- Removes MaxHealthShare of the target's MAXIMUM health (KO possible, then the K.O. scene).
	-- One prompt: the R key right on the climax opens the gate fully (+PerfectBonus); missed,
	-- the gate only half opens (-MissShare).
	Kaiten = {
		Type = "Gate",
		Length = 210,
		FinalTick = 150,
		Hits = { 118, 126 },
		HitShare = 0.05,
		MaxHealthShare = 0.3,
		FinishExtra = 200,
		PromptTicks = { 140 },
		PromptWindow = 4,
		PerfectBonus = 0.1,
		MissShare = 0.15,
	},
	-- COUP FATAL: one decisive blow at FinalTick, ComboShare (cancelled from a combo) or
	-- RawShare of the target's MAXIMUM health; one tight prompt (the C key) on the climax,
	-- missed: MissRatio of it is lost. Each kit stages its own scene, which is also its K.O.
	-- screen when the blow kills (no K.O. scene after it: FinishExtra 0).
	Fatal = {
		Type = "Fatal",
		Length = 240,
		FinalTick = 150,
		Hits = {},
		ComboShare = 0.5,
		RawShare = 0.3,
		FinishThreshold = 0.5, -- it only kills a target already under half of its health
		MissRatio = 0.4,
		FinishExtra = 0,
		PromptTicks = { 138 },
		PromptWindow = 9, -- (±0.15 s: ±4 was too tight, ISSEN's black-and-white cut especially)
		PromptButton = "Fatal",
	},
	-- ÉVEIL ÉCARLATE: MaxHealthShare of the target's MAXIMUM health when every rhythm prompt is
	-- hit; each missed prompt takes MissShare of it off the final blow (all missed: 12 %). It
	-- only KOs when the blows left can take the health that is left (FINAL FINISH, then the
	-- FinishExtra ticks of the K.O. scene).
	Awakening = {
		Type = "Awaken",
		Length = 220,
		FinalTick = 160,
		Hits = { 70, 78, 86, 94, 102, 110, 118 },
		HitShare = 0.03,
		MaxHealthShare = 0.3,
		MissShare = 0.045,
		FinishExtra = 200, -- the K.O. scene of a FINAL FINISH
		-- Rhythm prompts during the rush: the four first keys of the route that was played.
		PromptTicks = { 66, 82, 98, 114 },
		PromptWindow = 7,
		PerfectRefund = 100,
	},
}

local Kits = {}
local function kit(name, data)
	local roles = data.Roles
	local function remap(list)
		local out = {}
		for i, id in list do out[i] = roles[id] or id end
		return table.freeze(out)
	end
	local starters = {}
	for stance, buttons in KAI_STARTERS do
		local mapped = {}
		for button, id in buttons do mapped[button] = roles[id] end
		for button, id in (data.Starters or {})[stance] or {} do mapped[button] = id end
		starters[stance] = table.freeze(mapped)
	end
	data.Starters = table.freeze(starters)
	local routes = {}
	for i, route in ROUTES do
		routes[i] = table.freeze({
			name = (if route.skill then "★ " else "") .. data.RouteNames[i], keys = route.keys, moves = remap(route.moves),
		})
	end
	data.Routes = table.freeze(routes)
	local full = {}
	for i, route in FULL_ROUTES do
		full[i] = table.freeze({ name = data.FullRouteNames[i], keys = route.keys, finale = route.finale, moves = remap(route.moves) })
	end
	data.FullRoutes = table.freeze(full)
	data.Ultimates = table.freeze({
		Rush = roles.KaienRush, Awaken = roles.Awakening, Gate = roles.Kaiten, Chase = roles.KiChase, Finale = roles.Finale,
		Fatal = roles.Fatal,
	})
	if data.Stances then
		-- Each stance: the kit's stats with its own on top, the starters with its crouch special.
		for _, key in data.Stances.Order do
			local stance = data.Stances[key]
			local stats = table.clone(data.Stats)
			for k, v in stance.Stats or {} do stats[k] = v end
			stance.Stats = table.freeze(stats)
			local own = {}
			for kind, buttons in data.Starters do own[kind] = buttons end
			local crouch = table.clone(data.Starters.Crouch)
			crouch.Special = stance.CrouchSpecial or crouch.Special
			own.Crouch = table.freeze(crouch)
			stance.Starters = table.freeze(own)
			if stance.Weave then stance.Weave = table.freeze(stance.Weave) end
			stance.Id = key
			data.Stances[key] = table.freeze(stance)
		end
		data.Stances.Order = table.freeze(data.Stances.Order)
		data.Stances = table.freeze(data.Stances)
	end
	data.Stats = table.freeze(data.Stats)
	if data.Passive then data.Passive = table.freeze(data.Passive) end
	data.Colors = table.freeze(data.Colors)
	data.Roles = table.freeze(roles)
	data.Name = name
	Kits[name] = table.freeze(data)
	-- The ultimates' cinematics: KAI's timing with this kit's damage.
	for role, cin in CINEMATICS do
		local copy = deepCopy(cin)
		for k, v in (data.CinematicTuning or {})[cin.Type] or {} do copy[k] = v end
		for k, v in copy do
			if type(v) == "table" then copy[k] = table.freeze(v) end
		end
		MoveData.Cinematics[roles[role]] = table.freeze(copy)
	end
end
MoveData.Cinematics = {}

kit("KAI", {
	Kanji = "開", Role = "ALL-ROUNDER",
	Difficulty = 1, -- 1 = simple to pick up, 3 = technical (shown as stars)
	Description = "All-rounder: fists, feet and a ki blast. RESOLVE: press the blow's button (L or R) as it lands, take it and push back. FEINT: guard to stop some strings.",
	Roles = KAI_ROLES,
	Stats = { MaxHealth = 1550, WalkSpeed = 17, AirSpeed = 14, JumpVelocity = 43, DashSpeed = 38 },
	-- RESOLVE: the blow's button (L for a light, R for a heavy) pressed within Window ticks
	-- before its impact (latency forgiven, see Sim.timingSlack), the only attack press of the
	-- last Calm ticks. He takes all the damage, not the stagger, slides Slide back, answers
	-- with KaiResolve; the attacker's string is broken. Normal blows and route techniques only.
	Resolve = { Window = 4, Calm = 20, Slide = 14, Move = "KaiResolve" },
	-- FEINT: after these links made contact, a fresh guard press stops the string: Ticks of
	-- recovery at least (and never free before the opponent), no invincibility, then Cooldown.
	Feint = { Moves = { Cross = true, BodyBlow = true, Elbow = true, Smash = true, Sweep = true }, Ticks = 10, Cooldown = 60 },
	RouteNames = { "CHAIN", "LAUNCHER", "LIVER", "WALL", "AXE KICK", "SWEEP", "TORNADO", "GUST", "DRAGON", "THUNDER", "MOON" },
	FullRouteNames = { "TORNADO", "GUST", "DRAGON", "THUNDER", "WALL", "MOON" },
	GateTitle = { text = "開天", sub = "GATE OF HEAVEN" },
	Colors = { TORNADO = "FF2A3D", GUST = "FF7A2A", DRAGON = "FF2A3D", THUNDER = "8FD8FF", WALL = "FF2A3D", MOON = "FFE9B0" },
})
kit("TARO", {
	Kanji = "火", Role = "BOXER",
	Difficulty = 2,
	Description = "Fists only, two styles: CLASSIC (key & / 1: iron guard, heavy hits, CHAMPION'S RIGHT) "
		.. "or PEEKABOO (key é / 2: body sway, DEMPSEY ROLL, PARRY that counters).",
	Roles = TARO,
	-- Two boxing styles, switched in neutral with keys 1 / & (CLASSIQUE) and 2 / é (ESQUIVE).
	-- Each one overrides the kit's stats and its crouch special. ESQUIVE has the weave: the
	-- forward dash ducks under high attacks; during it or Window ticks after, L starts the
	-- DEMPSEY ROLL (alternating hooks, MaxHooks at most) and R its finishing hook.
	Stances = {
		Order = { "CLASSIC", "PEEKABOO" },
		CLASSIC = {
			Name = "CLASSIC BOXER", Key = "&",
			Stats = { WalkSpeed = 15, DashSpeed = 34, GuardDamageTaken = 0.6, DamageDealt = 1.08 },
			CrouchSpecial = "TaroChampion",
		},
		PEEKABOO = {
			Name = "PEEKABOO BOXER", Key = "é",
			Stats = { WalkSpeed = 17, DashSpeed = 40, GuardDamageTaken = 1, DamageDealt = 0.95 },
			CrouchSpecial = "TaroParry",
			-- Slips: up to Charges ready, each back in Cooldown ticks (one after the other).
			Weave = { Window = 10, Hook = "TaroDempseyL", Finish = "TaroDempseyFinish", MaxHooks = 6, Charges = 3, Cooldown = 420, Duck = 8 },
		},
	},
	Starters = { Crouch = { Special = "TaroParry" } },
	Stats = { MaxHealth = 1560, WalkSpeed = 15.5, AirSpeed = 13, JumpVelocity = 41, DashSpeed = 36, GuardDamageTaken = 0.8 },
	RouteNames = { "CHAIN", "LAUNCHER", "LIVER", "WALL", "OVERHAND", "DIVE", "GATLING", "EIGHT", "VOLCANO", "ERUPTION", "METEOR" },
	FullRouteNames = { "GATLING", "EIGHT", "VOLCANO", "ERUPTION", "WALL", "METEOR" },
	GateTitle = { text = "火嵐", sub = "HOOK STORM" },
	Colors = { TORNADO = "FF6A1A", GUST = "FF3B1A", DRAGON = "FFB21A", THUNDER = "FFD45A", WALL = "FF6A1A", MOON = "FF8C3A" },
})
kit("ZEPHYR", {
	Kanji = "風", Role = "KICKS",
	Difficulty = 2,
	Description = "Kicks only. PERFECT RHYTHM: links on the beat give Sparks (smoother strings). CLASH STEP: attack right as a blow lands to slip it and kick back.",
	Roles = ZEPHYR,
	Stats = { MaxHealth = 1350, WalkSpeed = 18.5, AirSpeed = 15.5, JumpVelocity = 48, DashSpeed = 41 },
	-- PERFECT RHYTHM: a link pressed From..To ticks after the end of the hitstop of the impact
	-- it follows (latency forgiven) is PERFECT; consecutive perfects are Sparks (Max 3): 1 =
	-- RecoveryCut less recovery on the new move, 2 = also Momentum more carry, 3 = also Hitstun
	-- more hitstun on its next impact. A miss only resets the Sparks. PERFECT FINISHER (the
	-- route's last link on the beat): knockdown +FinisherKnockdown ticks, knockback
	-- ×FinisherPush, or +FinisherStun ticks of advantage, by what the ending does. No damage.
	Rhythm = { From = -1, To = 6, Max = 3, RecoveryCut = 0.08, Momentum = 1.1, Hitstun = 1.1,
		FinisherKnockdown = 12, FinisherPush = 1.2, FinisherStun = 4 },
	-- CLASH STEP: an L or R from neutral, at most Window ticks into its wind-up (latency
	-- forgiven) when a blow lands; the attack before it at least Calm ticks older.
	ClashStep = { Window = 3, Calm = 24, Move = "ZephyrClashStep" },
	RouteNames = { "CHAIN", "LAUNCHER", "PLEXUS", "WALL", "AXE KICK", "REAP", "CYCLONE", "HUNDRED KICKS", "TAKEOFF", "SKY", "AZURE" },
	FullRouteNames = { "CYCLONE", "HUNDRED KICKS", "TAKEOFF", "SKY", "WALL", "AZURE" },
	GateTitle = { text = "旋風", sub = "RAGING CYCLONE" },
	Colors = { TORNADO = "5FE0D0", GUST = "9FF0FF", DRAGON = "5FE0D0", THUNDER = "C8F4FF", WALL = "5FE0D0", MOON = "E8FFFF" },
})
kit("AKEMI", {
	Kanji = "影", Role = "EVASION",
	Difficulty = 3,
	Description = "Very fragile. INSTINCT: 3 charges, each dodges a blow for sure (20 s each). Right after: L or R = she strikes from behind (blockable), or move TOWARD the threat: the next blow is dodged free (FLOW DODGE).",
	Roles = AKEMI,
	Stats = { MaxHealth = 1050, WalkSpeed = 19, AirSpeed = 15, JumpVelocity = 45, DashSpeed = 44, DashInvuln = 5 },
	-- VOILE D'OMBRE: from neutral (not attacking, not already hit, not guarding) the next
	-- hit is evaded: AKEMI slides back (Slide = push speed, about 2.4 studs), untouchable
	-- for Invuln ticks, unable to act for Recovery ticks (except for the counter below).
	-- Ultimates cannot be evaded.
	-- Like Ultra Instinct Goku (DBFZ): up to Charges evades ready, each recharging in Cooldown
	-- ticks (one after the other); each hit she lands takes HitRefund ticks off. Right after an
	-- evade, L or R within CounterWindow ticks: she reappears behind the attacker and strikes
	-- (free again: Wilhem, « remets-moi l'esquive où AKEMI passe dans le dos »). The attacker
	-- can read it: a fresh press of the guard from ReadEarly ticks before she reappears to
	-- ReadWindow ticks after turns him to her, guarding (a tight timing: about 0.15 s).
	-- INSTINCT (Wilhem's sheet): while she has a charge, a blow that would really hit her is
	-- dodged (100 %), one charge spent; each spent charge comes back after its own Cooldown
	-- (20 s), all of them in parallel. Styles: which dodge is played (Weight %), how far it
	-- slides (Slide) or goes around the attacker (Around), how long untouchable (Invuln) and
	-- busy (Recovery, never less than the attacker's whiffed attack: no free punish).
	-- INSTINCT FLOW: within FlowWindow ticks after an auto-dodge, moving TOWARD the threat arms
	-- one FLOW DODGE (no charge) for the next blow (armed FlowHold ticks at most); attacking,
	-- guarding, backing away or jumping gives it up. Ultimates and grabs are never dodged.
	-- The counter from behind (kept, Wilhem): L or R within CounterWindow ticks after a dodge,
	-- she reappears CounterGap behind the attacker; Blockable: her blow waits until he is free
	-- again, plus CounterReact ticks, and holding the guard (or away from her) blocks it; a
	-- fresh guard press up to ReadEarly ticks before she reappears reads it at once.
	Passive = { Type = "Evade", Name = "INSTINCT", Independent = true, Charges = 3, Cooldown = 1200,
		FlowWindow = 21, FlowHold = 60,
		CounterWindow = 14, CounterGap = 2.6, CounterCost = 0, Blockable = true, CounterReact = 10, ReadEarly = 3,
		Styles = {
			{ Name = "SLIP", Weight = 45, Slide = 8, Invuln = 12, Recovery = 14 },
			{ Name = "BACK", Weight = 30, Slide = 30, Invuln = 14, Recovery = 18 },
			{ Name = "SIDE", Weight = 20, Around = 2.2, Invuln = 14, Recovery = 18 },
			{ Name = "INSTINCT", Weight = 5, Slide = 3, Invuln = 14, Recovery = 16 },
		},
		Flow = { Name = "FLOW", Slide = -6, Invuln = 12, Recovery = 12 } },
	RouteNames = { "CHAIN", "TAKEOFF", "BREAKTHROUGH", "WALL", "FALL", "REAPER", "WHIRLWIND", "CUTS", "FANG", "ECLIPSE", "CRESCENT" },
	FullRouteNames = { "WHIRLWIND", "CUTS", "FANG", "ECLIPSE", "WALL", "CRESCENT" },
	GateTitle = { text = "幻舞", sub = "PHANTOM DANCE" },
	Colors = { TORNADO = "B060FF", GUST = "8A3CFF", DRAGON = "D08CFF", THUNDER = "6E7BFF", WALL = "B060FF", MOON = "E0C8FF" },
})
-- The four fighters of Wilhem's second sheet.
kit("RYUKEN", {
	Kanji = "拳", Role = "POWER",
	Difficulty = 1,
	Description = "Brutal: power and pressure. RAGE: every hit he lands hits harder, lost when he gets hit.",
	Roles = RYUKEN,
	Stats = { MaxHealth = 1500, WalkSpeed = 17.5, AirSpeed = 14, JumpVelocity = 43, DashSpeed = 40 },
	-- RAGE: each hit landed (not blocked) adds a stack, PerStack more damage each, Max stacks;
	-- all lost when RYUKEN is hit.
	Passive = { Type = "Rage", Name = "RAGE", PerStack = 0.025, Max = 10 },
	RouteNames = { "CHAIN", "LAUNCHER", "LIVER", "WALL", "SLEDGE", "REAP", "RAGE", "GUST", "ASCENSION", "FALL", "SLAM" },
	FullRouteNames = { "RAGE", "GUST", "ASCENSION", "FALL", "WALL", "SLAM" },
	GateTitle = { text = "拳", sub = "LAST ROUND" },
	Colors = { TORNADO = "FF2A2A", GUST = "FF5A1A", DRAGON = "FF2A2A", THUNDER = "FFD0C0", WALL = "FF2A2A", MOON = "FF8A6A" },
})
kit("SHIN", {
	Kanji = "流", Role = "SPEED",
	Difficulty = 2,
	Description = "Swordsman: great reach, quick cuts. PRECISION: a hit with the tip of the blade hurts more.",
	Roles = SHIN,
	Stats = { MaxHealth = 1450, WalkSpeed = 18.5, AirSpeed = 15, JumpVelocity = 45, DashSpeed = 44 },
	-- PRÉCISION: a hit whose target stands in the outer part of the blade's reach (beyond From
	-- of it) deals Bonus more.
	Passive = { Type = "Tip", Name = "PRECISION", From = 0.68, Bonus = 0.12 }, -- (nerfed: from 0.62, +20 %)
	RouteNames = { "CHAIN", "LAUNCHER", "BREAKTHROUGH", "WALL", "CLEAVER", "REAPER", "CIRCLE", "STORM", "SKY", "FALL", "CRESCENT" },
	FullRouteNames = { "CIRCLE", "STORM", "SKY", "FALL", "WALL", "CRESCENT" },
	GateTitle = { text = "零", sub = "ZERO HORIZON" },
	Colors = { TORNADO = "3D9BFF", GUST = "6FD8FF", DRAGON = "3D9BFF", THUNDER = "C8F0FF", WALL = "3D9BFF", MOON = "A8E4FF" },
})
kit("DAICHA", {
	Kanji = "闇", Role = "ZONING",
	Difficulty = 3,
	Description = "Mysterious: controls space. INVERTED SPHERE (S + E), TELEPORT, and INVERTED SHADOW: her dash goes through the opponent.",
	Roles = DAICHA,
	Stats = { MaxHealth = 1500, WalkSpeed = 16, AirSpeed = 14, JumpVelocity = 44, DashSpeed = 38 },
	-- OMBRE INVERSÉE: a forward dash within Range studs of the opponent blinks through to
	-- Gap studs behind them, untouchable for Invuln ticks; Cooldown before the next dash.
	Passive = { Type = "Blink", Name = "INVERTED SHADOW", Range = 5, Gap = 1.8, Invuln = 10, Cooldown = 54 },
	-- Her four ultimates' own timing (Wilhem: ~3, ~5, ~7 and ~10 s at the cinematic's slow
	-- motion); the same blows and damage as everyone's, spread over her scenes.
	CinematicTuning = {
		Rush = { Length = 140, FinalTick = 104, Hits = { 26, 29, 32, 35, 38, 50, 56, 62, 84, 88, 92 } },
		Awaken = { Length = 200, FinalTick = 166, Hits = { 78, 88, 98, 108, 118, 128, 138 }, PromptTicks = { 74, 94, 114, 134 } },
		Gate = { Length = 290, FinalTick = 236, Hits = { 186, 206 }, PromptTicks = { 156 } },
		Fatal = { Length = 350, FinalTick = 266, PromptTicks = { 244 } },
	},
	RouteNames = { "CHAIN", "LAUNCHER", "MARK", "WALL", "FALL", "REAPER", "DISTORTION", "RIVER", "ARROW", "INVERSION", "ECLIPSE" },
	FullRouteNames = { "DISTORTION", "RIVER", "ARROW", "INVERSION", "WALL", "ECLIPSE" },
	GateTitle = { text = "蝕", sub = "TOTAL ECLIPSE" },
	Colors = { TORNADO = "A040FF", GUST = "7A2CFF", DRAGON = "C080FF", THUNDER = "6E7BFF", WALL = "A040FF", MOON = "E0C8FF" },
})
kit("HIBECARES", {
	Kanji = "崩", Role = "ENDURANCE",
	Difficulty = 1,
	Description = "The king of ruins: the most health, heavy blows. STONE WALL (S + E) takes a hit and strikes back; KING OF RUINS: the more he is hurt, the harder he hits.",
	Roles = HIBECARES,
	Starters = { Crouch = { Special = "HibecaresWall" } },
	Stats = { MaxHealth = 1580, WalkSpeed = 13.5, AirSpeed = 12, JumpVelocity = 39, DashSpeed = 30, GuardDamageTaken = 0.85 },
	-- ROI DES RUINES: up to MaxBonus more damage, growing as his health falls from From to To
	-- (shares of his maximum health).
	Passive = { Type = "Ruins", Name = "KING OF RUINS", MaxBonus = 0.3, From = 1, To = 0.3 },
	RouteNames = { "CHAIN", "LAUNCHER", "GRAB", "WALL", "GUARD BREAKER", "SWEEP", "RUPTURE", "RUBBLE", "PILLAR", "STOMP", "EARTHQUAKE" },
	FullRouteNames = { "RUPTURE", "RUBBLE", "PILLAR", "STOMP", "WALL", "EARTHQUAKE" },
	GateTitle = { text = "崩", sub = "RUIN OF THE WORLD" },
	Colors = { TORNADO = "FF8A1A", GUST = "FFB21A", DRAGON = "FF6A1A", THUNDER = "FFD45A", WALL = "FF8A1A", MOON = "C8A070" },
})
-- ===================================================================== WILHEM'S THIRD SHEET: the kits
-- Their route names come from their own moves (THIRD[name].names, by role); the ÉVEIL finales
-- are the six full routes'.
local function third(name, data)
	local n = THIRD[name].names
	data.Roles = THIRD[name].roles
	data.RouteNames = { "CHAIN", "LAUNCHER", "BREAKTHROUGH", "WALL", "HAMMER", "REAPER", n.DragonTornado, n.KiFlurry, n.DragonFist,
		n.ThunderHeel, n.CrescentMoon }
	data.FullRouteNames = { n.DragonTornado, n.KiFlurry, n.DragonFist, n.ThunderHeel, "WALL", n.CrescentMoon }
	local e = data.Energy
	data.Colors = { TORNADO = e, GUST = e, DRAGON = e, THUNDER = data.Light or e, WALL = e, MOON = data.Light or e }
	data.Energy, data.Light = nil, nil
	kit(name, data)
end
third("RAIJIN", {
	Kanji = "雷", Role = "REACH", Difficulty = 2, Energy = "FFE85A", Light = "FFFFFF",
	Description = "The thunder dragon: a lightning-charged spear, the longest reach. OVERCHARGE: 3 hits in a row charge the next technique (more reach, more damage).",
	Stats = { MaxHealth = 1400, WalkSpeed = 17.5, AirSpeed = 14.5, JumpVelocity = 44, DashSpeed = 42 },
	Passive = { Type = "Overcharge", Name = "OVERCHARGE", Every = 3, Reach = 1.35, Bonus = 0.15 },
	GateTitle = { text = "雷神", sub = "DIVINE WRATH" },
})
third("YUKINA", {
	Kanji = "雪", Role = "CONTROL", Difficulty = 3, Energy = "9FE6FF", Light = "FFFFFF",
	Description = "The frost empress: two ice fans. DEEP FREEZE: 3 hits freeze the opponent (20 % slower). ICE MIRROR (S + E) sends projectiles back.",
	Starters = { Crouch = { Special = "YukinaMirror" } },
	Stats = { MaxHealth = 1250, WalkSpeed = 17.5, AirSpeed = 15, JumpVelocity = 45, DashSpeed = 42 },
	Passive = { Type = "Frost", Name = "DEEP FREEZE", Stacks = 3, Slow = 0.2, SlowTicks = 180 },
	GateTitle = { text = "氷獄", sub = "ETERNAL PRISON" },
})
third("VENOM", {
	Kanji = "毒", Role = "ATTRITION", Difficulty = 2, Energy = "7CFF4A", Light = "C8FF9A",
	Description = "The predator: claws and poison, fast. CONTAMINATION: his techniques poison (up to 3 charges, damage over time that never kills). TOXIC MIST (S + E).",
	Stats = { MaxHealth = 1350, WalkSpeed = 18, AirSpeed = 15, JumpVelocity = 45, DashSpeed = 44 },
	Passive = { Type = "Poison", Name = "CONTAMINATION", Max = 3, PerCharge = 6, Interval = 30, Duration = 180 },
	GateTitle = { text = "毒王", sub = "VENOM KING" },
})
third("GORAN", {
	Kanji = "剛", Role = "GRAPPLER", Difficulty = 2, Energy = "FF4A3A", Light = "FFB0A0",
	Description = "The titan: slow and huge, grabs that go through the guard. ANCHOR: his heavy ground blows shrug off a hit. TITAN'S HUG (S + E).",
	Starters = { Crouch = { Special = "GoranGrab" } },
	Stats = { MaxHealth = 1700, WalkSpeed = 13.5, AirSpeed = 12, JumpVelocity = 39, DashSpeed = 30, GuardDamageTaken = 0.85 },
	Passive = { Type = "Anchor", Name = "ANCHOR", Heavy = 60, Absorb = 1 },
	GateTitle = { text = "巨神", sub = "FALL OF THE TITAN" },
})
third("ASTER", {
	Kanji = "星", Role = "GRAVITY", Difficulty = 3, Energy = "B49CFF", Light = "E8E0FF",
	Description = "The master of gravity: floating rings. SHIFTING MASS: after a technique lands, his next air attack hits 30 % harder. PULL (S + E) drags the opponent in.",
	Stats = { MaxHealth = 1300, WalkSpeed = 16.5, AirSpeed = 15.5, JumpVelocity = 47, DashSpeed = 40 },
	Passive = { Type = "Mass", Name = "SHIFTING MASS", Bonus = 0.3 },
	GateTitle = { text = "重力", sub = "EVENT HORIZON" },
})
third("HIBIKI", {
	Kanji = "響", Role = "RHYTHM", Difficulty = 3, Energy = "FF6FC8", Light = "FFD0EE",
	Description = "The resonance: sound and rhythm, very fast. TEMPO: 3 hits on the beat and her recoveries go twice as fast for 4 s. SONIC WAVE (S + E) pushes away.",
	Stats = { MaxHealth = 1250, WalkSpeed = 18.5, AirSpeed = 15, JumpVelocity = 45, DashSpeed = 44 },
	Passive = { Type = "Tempo", Name = "TEMPO", Chain = 3, Window = 50, Duration = 240, Cooldown = 300 },
	GateTitle = { text = "絶響", sub = "LAST RESONANCE" },
})
third("KAZAN", {
	Kanji = "鎖", Role = "PRESSURE", Difficulty = 2, Energy = "FFB04A", Light = "E0E0E8",
	Description = "The predator: two steel claws, three blades on each hand, relentless at short and middle range. SHACKLED: 2 techniques landed and the opponent's next dash is cut in half. SHACKLE HOOK (S + E) catches and holds.",
	Stats = { MaxHealth = 1400, WalkSpeed = 17, AirSpeed = 14, JumpVelocity = 43, DashSpeed = 42 },
	Passive = { Type = "Shackle", Name = "SHACKLED", Hits = 2 },
	GateTitle = { text = "鎖獄", sub = "JUDGMENT OF CHAINS" },
})
-- KUROEN 蝕 · THE EMPEROR OF THE ECLIPSE. Rushdown: superb pressure and mobility, classic
-- defence, no invincible reversal (CRIMSON STEP is not one), ECLIPSE BREAKER punishable, and
-- everything rests on DOMINATION (3 levels, earned by clean combos, lost when hit or idle):
--   I   ÉVEIL      CRIMSON STEP becomes EMPEROR STEP (costs the level)
--   II  SUPRÉMATIE a technique that hits can be cancelled into another (costs a level)
--   III ÉCLIPSE    R on a blow that hits: ZERO ABSOLU: ECLIPSE (costs everything + 3 bars)
-- No damage bonus at any level.
third("KUROEN", {
	Kanji = "蝕", Role = "RUSHDOWN", Difficulty = 3, Energy = "E0102E", Light = "FF6A7A",
	Description = "The emperor of the eclipse: fists, elbows, knees and bursts of red and black ki. DOMINATION: clean combos raise it (3 levels), being hit or idle lowers it. I: EMPEROR STEP. II: techniques cancel into each other. III: R on a hit unleashes ZERO ABSOLU: ECLIPSE.",
	Stats = { MaxHealth = 1350, WalkSpeed = 18, AirSpeed = 15, JumpVelocity = 45, DashSpeed = 46 },
	Passive = { Type = "Domination", Name = "DOMINATION", Max = 3, ComboHits = 4, Idle = 360, Step = "KuroenEmperorStep" },
	GateTitle = { text = "皇", sub = "EMPEROR'S GATE" },
})
third("KUREN", {
	Kanji = "血", Role = "SACRIFICE", Difficulty = 3, Energy = "D0102E", Light = "FF8090",
	Description = "The blood alchemist. SCARLET PACT: each technique costs him 3 % of his health (never fatal) and hits 30 % harder. BLOOD LANCE (S + E) crosses the screen.",
	Stats = { MaxHealth = 1350, WalkSpeed = 16, AirSpeed = 14, JumpVelocity = 44, DashSpeed = 38 },
	Passive = { Type = "Pact", Name = "SCARLET PACT", Cost = 0.03, Bonus = 0.3 },
	GateTitle = { text = "血王", sub = "BLOOD THRONE" },
})
third("SYLVA", {
	Kanji = "森", Role = "TRAPS", Difficulty = 3, Energy = "4AD86A", Light = "C8F0A0",
	Description = "The huntress: traps and vines. HUNGRY ROOTS (S + E) sets a trap that slows and hurts. TERRITORY: with a trap near her, her blows reach further.",
	Stats = { MaxHealth = 1250, WalkSpeed = 17.5, AirSpeed = 15, JumpVelocity = 46, DashSpeed = 42 },
	Passive = { Type = "Territory", Name = "TERRITORY", Range = 12, Reach = 1.2 },
	GateTitle = { text = "森王", sub = "BRAMBLE DOMAIN" },
})
third("ELIAN", {
	Kanji = "癒", Role = "SUPPORT", Difficulty = 2, Energy = "FFE9A0", Light = "FFFFFF",
	Description = "The healer. VITAL PULSE (S + E) pushes away and heals him a little. SECOND WIND: under 30 % health, his next heal is three times stronger (once per round).",
	Starters = { Crouch = { Special = "ElianPulse" } },
	Stats = { MaxHealth = 1350, WalkSpeed = 17, AirSpeed = 14.5, JumpVelocity = 44, DashSpeed = 40 },
	Passive = { Type = "SecondWind", Name = "SECOND WIND", Threshold = 0.3, Boost = 3 },
	GateTitle = { text = "神癒", sub = "DIVINE MIRACLE" },
})
third("NOVA", {
	Kanji = "機", Role = "DRONES", Difficulty = 3, Energy = "FF8A2A", Light = "FFD0A0",
	Description = "The war engineer: mechanical gauntlets and drones. SENTRY (S + E): a drone fires three times on its own. ENGINEERING: 2 drones, which come back over time.",
	Starters = { Crouch = { Special = "NovaSentinel" } },
	Stats = { MaxHealth = 1300, WalkSpeed = 17, AirSpeed = 14.5, JumpVelocity = 44, DashSpeed = 40 },
	Passive = { Type = "Engineering", Name = "ENGINEERING", Charges = 2, Cooldown = 540 },
	GateTitle = { text = "機神", sub = "MECHANICAL ARMY" },
})

-- ===================================================================== ASURA 阿 · boss
-- The CHALLENGE boss: KAI's moves with four arms (the extra pair is cosmetic, see RigBuilder),
-- a lot more health, harder hits and a sturdier guard. Not selectable (not in KitOrder).
kit("ASURA", {
	Kanji = "阿", Role = "BOSS", Boss = true,
	Difficulty = 3,
	Description = "A four-armed KAI, out of the Gate of Heaven. Massive: he hits far harder, his heavy blows go through yours and he never lets go. Felled once, he rises again in a black aura, stronger still. E: FOUR-ARMED GATLING.",
	Roles = table.clone(KAI_ROLES),
	Starters = { Ground = { Special = "AsuraGatling" } },
	-- (Bulk: as tall as the others but massive: wider to hit)
	-- Reach: his four arms strike farther (a spear does not keep him out). SecondLife: the first
	-- time he falls he rises again in a black aura (once per match), harder and faster.
	-- ExtraArms: every grounded blow of his that lands is followed by the second pair of arms
	-- (that share again as damage, a longer stun); blocked, it crushes the guard harder.
	-- NoCounter: never caught by a COUNTER HIT (a boss reads you, you do not read him).
	-- Burst: at the 5th blow of a combo on him, a chance to break it (35 %; 100 % in his
	-- SECOND LIFE): he flares free, the attacker is thrown back, stunned.
	-- DamageTaken: his hide takes 10 % less from every blow. (The BURST comes back every
	-- 10 s and shows on his gauge: a player who reads it beats him with short punishes.)
	Stats = { MaxHealth = 3200, WalkSpeed = 18, AirSpeed = 14, JumpVelocity = 43, DashSpeed = 44, DamageDealt = 1.4,
		GuardDamageTaken = 0.5, Bulk = 1.2, Reach = 1.25, ExtraArms = 0.35, NoCounter = true, DamageTaken = 0.9,
		-- (Wilhem: the BURST is never sure in his first life, 35 % at the 5th blow of a combo;
		-- risen in his SECOND LIFE, every time)
		Burst = { Hits = 5, Cooldown = 600, Invuln = 16, Stun = 16, Push = 40, Chance = 0.35, SecondLifeChance = 1 },
		-- (the second life brings him back under half health, but there he is a monster: every
		-- grounded blow armored, harder hits, faster; eased so he stays beatable, KUROEN SHIN above him)
		SecondLife = { Health = 0.45, DamageDealt = 1.3, Speed = 1.15, RiseTicks = 50, Armor = true } },
	-- ASURA'S WRATH: his heavy grounded normals (Kick, Spin Kick, Hammer, Smash) take one hit
	-- without flinching (GORAN's armor rule), and so does his forward dash: he charges through
	-- a poke or a spear.
	-- (Wilhem: « ils doivent pas être impossibles, juste très compliqués »: in his first life only
	-- the heavies are armored; risen, every grounded blow)
	Passive = { Type = "Anchor", Name = "ASURA'S WRATH", Heavy = 60, Absorb = 1, DashArmor = true },
	RouteNames = { "CHAIN", "LAUNCHER", "LIVER", "WALL", "AXE KICK", "SWEEP", "TORNADO", "GUST", "DRAGON", "THUNDER", "MOON" },
	FullRouteNames = { "TORNADO", "GUST", "DRAGON", "THUNDER", "WALL", "MOON" },
	GateTitle = { text = "阿修羅", sub = "WRATH OF THE FOUR ARMS" },
	Colors = { TORNADO = "FFD23F", GUST = "FF7A2A", DRAGON = "FFD23F", THUNDER = "FFE9B0", WALL = "FFD23F", MOON = "FFE9B0" },
})

-- ===================================================================== KUROEN SHIN 真 · boss
-- The second CHALLENGE boss: KUROEN past his limits (Wilhem: "broken, like Gogeta in
-- FighterZ"). KUROEN's moves (they stay KUROEN's), but DOMINATION is born at ÉCLIPSE and comes
-- back by itself (a level every 4 s), never lost; far more health, harder hits, a dash that
-- passes through blows (instant transmission), never caught by a COUNTER HIT. Not
-- selectable. Beaten, he gives KUROEN's DIVINE ECLIPSE style.
do
	local base = Kits.KUROEN
	kit("KUROEN SHIN", {
		Kanji = "真", Role = "BOSS", Boss = true, Difficulty = 3,
		Description = "KUROEN past every limit: DOMINATION born at ECLIPSE and never lost, DIVINE INSTINCT evades your blows and strikes back, a dash that passes through blows, divine strength. Beat him to earn KUROEN's DIVINE ECLIPSE style.",
		Roles = table.clone(base.Roles),
		-- AutoEvade (DIVINE INSTINCT, his own way of being broken): a blow that reaches him in
		-- neutral is evaded (1 charge, back every 8 s: bait it, then strike) and he reappears behind the attacker.
		Stats = { MaxHealth = 3000, WalkSpeed = 20, AirSpeed = 16, JumpVelocity = 47, DashSpeed = 54, DashInvuln = 8,
			DamageDealt = 1.45, GuardDamageTaken = 0.5, Reach = 1.1, NoCounter = true, DamageTaken = 0.9,
			AutoEvade = { Charges = 1, Cooldown = 480, Invuln = 14, Recovery = 16, Slide = 24, CounterWindow = 16,
				CounterGap = 2.4, CounterCost = 0 } },
		Passive = { Type = "Domination", Name = "TRUE DOMINATION", Max = 3, ComboHits = 3, Idle = 99999, Step = "KuroenEmperorStep",
			Start = 3, Regen = 240, NoLoss = true },
		RouteNames = table.clone(THIRD.KUROEN.names and { "CHAIN", "LAUNCHER", "BREAKTHROUGH", "WALL", "HAMMER", "REAPER",
			THIRD.KUROEN.names.DragonTornado, THIRD.KUROEN.names.KiFlurry, THIRD.KUROEN.names.DragonFist,
			THIRD.KUROEN.names.ThunderHeel, THIRD.KUROEN.names.CrescentMoon }),
		FullRouteNames = { THIRD.KUROEN.names.DragonTornado, THIRD.KUROEN.names.KiFlurry, THIRD.KUROEN.names.DragonFist,
			THIRD.KUROEN.names.ThunderHeel, "WALL", THIRD.KUROEN.names.CrescentMoon },
		GateTitle = { text = "真", sub = "TRUE EMPEROR" },
		Colors = { TORNADO = "FFD23F", GUST = "FFFFFF", DRAGON = "FFD23F", THUNDER = "FFFFFF", WALL = "FFD23F", MOON = "FFFFFF" },
	})
end

MoveData.Cinematics = table.freeze(MoveData.Cinematics)
MoveData.Kits = table.freeze(Kits)
MoveData.KitOrder = table.freeze({ "KAI", "TARO", "ZEPHYR", "AKEMI", "RYUKEN", "SHIN", "DAICHA", "HIBECARES",
	"RAIJIN", "YUKINA", "VENOM", "GORAN", "ASTER", "HIBIKI", "KAZAN", "KUREN", "SYLVA", "ELIAN", "NOVA", "KUROEN" })

-- KAI's tables, kept for code written before the kits.
MoveData.Starters = Kits.KAI.Starters
MoveData.Routes = Kits.KAI.Routes
MoveData.FullRoutes = Kits.KAI.FullRoutes
MoveData.Cinematic = MoveData.Cinematics.KaienRush

-- Kit of a move id (nil for unknown ids).
local moveKit = {}
for name, data in Kits do
	if not data.Boss then -- (ASURA borrows KAI's moves: they stay KAI's)
		for _, id in data.Roles do moveKit[id] = name end
	end
end
moveKit.TaroParry, moveKit.TaroCounter = "TARO", "TARO"
moveKit.TaroDempseyL, moveKit.TaroDempseyR, moveKit.TaroDempseyFinish = "TARO", "TARO", "TARO"
moveKit.TaroChampion = "TARO"
moveKit.ZephyrClashStep, moveKit.KaiResolve = "ZEPHYR", "KAI"
moveKit.HibecaresWall, moveKit.HibecaresCounter = "HIBECARES", "HIBECARES"
moveKit.YukinaMirror, moveKit.GoranGrab, moveKit.KuroenEmperorStep = "YUKINA", "GORAN", "KUROEN"
moveKit.ElianPulse, moveKit.NovaSentinel = "ELIAN", "NOVA"
MoveData.MoveKit = table.freeze(moveKit)

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
