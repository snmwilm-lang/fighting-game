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
		id = "Elbow", name = "COUDE", startup = 6, active = 3, recovery = 13,
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
		id = "BodyBlow", name = "COUP AU FOIE", startup = 9, active = 3, recovery = 16,
		damage = 70, guardDamage = 14, hitstun = 22, blockstun = 14, hitstop = 10,
		push = 4, blockPush = 14, lunge = 10, crumple = true,
		hitbox = { near = 0.3, far = 3.4, low = 1.8, high = 3.8 },
		heavy = true,
		cancels = { Light = "PalmStrike" },
	},
	Uppercut = { -- L > L > R or crouch + R : launcher, jump to follow
		id = "Uppercut", name = "LANCEUR", startup = 8, active = 4, recovery = 22,
		damage = 70, guardDamage = 12, hitstun = 26, blockstun = 14, hitstop = 9,
		push = 3, blockPush = 14, lunge = 6, launch = 46, jumpCancel = true,
		hitbox = { near = 0.2, far = 3.4, low = 1.6, high = 6.6 },
		heavy = true,
		cancels = { Heavy = "DragonFist" },
	},
	-- Alternating routes: L > R > L > R and friends unlock special skills.
	PalmStrike = { -- L > R > L : ki palm on the crumpling target
		id = "PalmStrike", name = "PAUME DE KI", startup = 8, active = 4, recovery = 18,
		damage = 75, guardDamage = 14, hitstun = 26, blockstun = 14, hitstop = 10,
		push = 10, blockPush = 16, lunge = 8,
		hitbox = { near = 0.3, far = 3.8, low = 1.8, high = 4.8 },
		heavy = true,
		cancels = { Heavy = "DragonTornado" },
	},
	DragonTornado = { -- L > R > L > R : skill, spinning multi-hit launcher
		id = "DragonTornado", name = "TORNADE DU DRAGON", kind = "Skill", skill = true,
		startup = 9, active = 16, recovery = 24, hits = 4, hitInterval = 4,
		damage = 30, guardDamage = 10, hitstun = 30, blockstun = 12, hitstop = 12,
		multiHitstop = 3, holdVy = 14, multiPush = 1,
		push = 6, blockPush = 18, lunge = 12, launch = 46, jumpCancel = true, track = true,
		hitbox = { near = 0, far = 3.6, low = 0, high = 7.4 },
		heavy = true,
		cancels = { Light = "KiChase" },
	},
	DragonFist = { -- L > L > R > R or R > R > L > R : skill, rising triple uppercut
		id = "DragonFist", name = "POING DU DRAGON", kind = "Skill", skill = true,
		startup = 7, active = 12, recovery = 28, hits = 3, hitInterval = 4,
		damage = 40, guardDamage = 12, hitstun = 30, blockstun = 14, hitstop = 14,
		multiHitstop = 4, holdVy = 6, multiPush = 1,
		push = 4, blockPush = 18, lunge = 14, launch = 40, track = true,
		hitbox = { near = 0, far = 3.6, low = 0.5, high = 11.5 },
		heavy = true,
		cancels = { Light = "KiChase" },
	},
	CrescentMoon = { -- L L L L > R : skill, flipping kicks that spike the target down
		id = "CrescentMoon", name = "CROISSANT DE LUNE", kind = "Skill", skill = true,
		startup = 7, active = 13, recovery = 24, hits = 3, hitInterval = 5,
		damage = 35, guardDamage = 12, hitstun = 28, blockstun = 14, hitstop = 13,
		multiHitstop = 4, holdVy = 12, multiPush = 2,
		push = 8, blockPush = 18, lunge = 14, launch = -30, groundBounce = true,
		hitbox = { near = 0, far = 4.2, low = 0, high = 7.5 },
		heavy = true,
		cancels = { Heavy = "Finale" },
	},
	RisingWind = { -- R > L > R : double kick that lifts the swept target
		id = "RisingWind", name = "VENT ASCENDANT", startup = 6, active = 8, recovery = 20,
		hits = 2, hitInterval = 4, damage = 40, guardDamage = 10, hitstun = 26, blockstun = 13, hitstop = 9,
		multiHitstop = 3, holdVy = 12, multiPush = 1,
		push = 6, blockPush = 14, lunge = 10, launch = 30, track = true,
		hitbox = { near = 0.2, far = 4.2, low = -1.5, high = 6 },
		heavy = true,
		cancels = { Light = "KiFlurry" },
	},
	KiFlurry = { -- R > L > R > L : skill, rush of ki punches ending in a wall bounce
		id = "KiFlurry", name = "RAFALE DE KI", kind = "Skill", skill = true,
		startup = 6, active = 24, recovery = 22, hits = 7, hitInterval = 3,
		damage = 18, guardDamage = 6, hitstun = 28, blockstun = 12, hitstop = 14,
		multiHitstop = 2, holdVy = 7, multiPush = 1,
		push = 44, blockPush = 20, lunge = 6, launch = 18, wallBounce = true,
		hitbox = { near = 0.3, far = 4.2, low = 0, high = 7.5 },
		heavy = true,
		cancels = { Light = "KiChase" },
	},
	ThunderHeel = { -- R > R > L : catches the bounce, launches
		id = "ThunderHeel", name = "TALON FOUDRE", startup = 7, active = 4, recovery = 20,
		damage = 70, guardDamage = 12, hitstun = 26, blockstun = 14, hitstop = 10,
		push = 3, blockPush = 14, lunge = 8, launch = 34, jumpCancel = true,
		hitbox = { near = 0.2, far = 3.8, low = 0, high = 7 },
		heavy = true,
		cancels = { Heavy = "DragonFist" },
	},
	SpinKick = { -- L > L > L > R : wall bounce
		id = "SpinKick", name = "TALON TOURNOYANT", startup = 10, active = 3, recovery = 22,
		damage = 95, guardDamage = 18, hitstun = 26, blockstun = 16, hitstop = 12,
		push = 46, blockPush = 22, lunge = 6, launch = 14, wallBounce = true,
		hitbox = { near = 0.4, far = 4.6, low = 2.2, high = 4.8 },
		heavy = true,
		cancels = { Light = "KiChase" },
	},
	-- Right-click chain
	Smash = {
		id = "Smash", name = "FRAPPE LOURDE", startup = 13, active = 4, recovery = 22,
		damage = 110, guardDamage = 40, hitstun = 26, blockstun = 16, hitstop = 11,
		push = 30, blockPush = 22, lunge = 12,
		hitbox = { near = 0.4, far = 4.2, low = 2.4, high = 4.8 },
		heavy = true,
		cancels = { Heavy = "Hammer", Light = "Sweep" },
	},
	Hammer = { -- R > R : overhead axe kick, ground bounce
		id = "Hammer", name = "HACHE CÉLESTE", startup = 12, active = 4, recovery = 20,
		damage = 90, guardDamage = 22, hitstun = 28, blockstun = 15, hitstop = 12,
		push = 4, blockPush = 16, lunge = 10, launch = 26, groundBounce = true, guard = "High",
		hitbox = { near = 0.3, far = 3.8, low = 1.0, high = 6.4 },
		heavy = true,
		cancels = { Light = "ThunderHeel" },
	},
	Sweep = { -- R > L : low sweep, knockdown
		id = "Sweep", name = "BALAYAGE", startup = 9, active = 4, recovery = 20,
		damage = 60, guardDamage = 12, hitstun = 22, blockstun = 13, hitstop = 9,
		push = 8, blockPush = 14, lunge = 12, launch = 20, knockdown = true, guard = "Low",
		hitbox = { near = 0.3, far = 4.6, low = -0.2, high = 1.4 },
		cancels = { Heavy = "RisingWind" },
	},
	-- Crouching
	LowKick = {
		id = "LowKick", name = "KICK BAS", startup = 5, active = 3, recovery = 10,
		damage = 35, guardDamage = 6, hitstun = 16, blockstun = 11, hitstop = 6,
		push = 9, blockPush = 11, lunge = 3, guard = "Low",
		hitbox = { near = 0.3, far = 4.0, low = -0.2, high = 1.4 },
		cancels = { Light = "Cross", Heavy = "Uppercut" },
	},
	-- Air chain: J.L > J.L > J.R
	AirKick = {
		id = "AirKick", name = "KICK AÉRIEN", startup = 6, active = 6, recovery = 10, air = true,
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
		id = "AirSmash", name = "MÉTÉORE", startup = 9, active = 5, recovery = 14, air = true,
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
		id = "KiChase", name = "POURSUITE ÉCARLATE", startup = 6, active = 8, recovery = 22,
		damage = 50, guardDamage = 10, hitstun = 30, blockstun = 14, hitstop = 9,
		push = 4, blockPush = 14, lunge = 34, launch = 26, homing = true, -- ki-charged leap at the target
		hitbox = { near = 0, far = 4.6, low = -1, high = 9 },
		heavy = true,
		cancels = { Heavy = "Finale" },
	},
	Finale = { -- 6th press: finisher. Clean route + 3 bars: ÉVEIL ÉCARLATE (right click) or PORTE DES CIEUX (R key)
		id = "Finale", name = "COUP DE GRÂCE", kind = "Skill", skill = true,
		startup = 8, active = 4, recovery = 30,
		damage = 110, guardDamage = 30, hitstun = 34, blockstun = 18, hitstop = 16,
		push = 40, blockPush = 22, lunge = 14, launch = 30, knockdown = true,
		hitbox = { near = 0, far = 4.6, low = -1, high = 9 },
		heavy = true,
	},
	Kaiten = { -- third ultimate: clean full route ending on the R key, 3 bars
		id = "Kaiten", name = "開天 · PORTE DES CIEUX", kind = "Ultimate", startup = 8, active = 6, recovery = 44,
		damage = 20, guardDamage = 40, hitstun = 40, blockstun = 22, hitstop = 4,
		push = 2, blockPush = 24, lunge = 18, meterCost = 300,
		invuln = { from = 1, to = 14 },
		hitbox = { near = 0, far = 4.6, low = -1, high = 9 },
		heavy = true,
	},
	Awakening = { -- unique attack: 3 bars, cinematic, up to 35 % of the maximum health (rhythm prompts)
		id = "Awakening", name = "ÉVEIL ÉCARLATE", kind = "Ultimate", startup = 8, active = 6, recovery = 40,
		damage = 20, guardDamage = 40, hitstun = 40, blockstun = 22, hitstop = 4,
		push = 2, blockPush = 24, lunge = 20, meterCost = 300,
		invuln = { from = 1, to = 14 },
		hitbox = { near = 0, far = 4.6, low = -1, high = 9 },
		heavy = true,
	},
	-- COUP FATAL (C): the last-breath move. 3 bars, the user under Config.FatalHealth of its
	-- health, once per match. Cancelled from a hit of a combo it takes the cinematic's
	-- ComboShare of the target's maximum health, thrown raw only RawShare; slow to come out,
	-- blocked or dodged it is simply lost (the whole ki gauge with it). Its cinematic is the
	-- K.O. screen when it kills.
	Fatal = {
		id = "Fatal", name = "滅 · CIEL ÉTEINT", kind = "Ultimate", fatal = true, startup = 14, active = 6, recovery = 52,
		damage = 20, guardDamage = 60, hitstun = 40, blockstun = 30, hitstop = 4,
		push = 2, blockPush = 30, lunge = 24, meterCost = 300,
		invuln = { from = 1, to = 8 },
		hitbox = { near = 0, far = 4.8, low = -1, high = 9 },
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
		push = 2, blockPush = 20, lunge = 34, meterCost = 200,
		invuln = { from = 1, to = 12 },
		hitbox = { near = 0.2, far = 3.8, low = 0.8, high = 8.5 },
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
	tuning: kit-wide { damage = scale, startup = delta for ground normals, reach = scale };
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
	TaroJab = "JAB", TaroStraight = "DIRECT", TaroHook = "CROCHET", TaroBolo = "BOLO PUNCH",
	TaroLiver = "CROCHET AU FOIE", TaroUppercut = "UPPERCUT", TaroRam = "COUP DE BÉLIER",
	TaroGatling = "GATLING DE FEU", TaroVolcano = "UPPERCUT VOLCAN", TaroMeteor = "MARTEAU MÉTÉORE",
	TaroTwinUpper = "DOUBLE ASCENDANT", TaroDempsey = "RAFALE EN HUIT", TaroRisingHook = "CROCHET MONTANT",
	TaroCorkscrew = "TIRE-BOUCHON", TaroHeavy = "DROITE LOURDE", TaroOverhand = "OVERHAND", TaroDive = "PLONGEON",
	TaroLowJab = "JAB BAS", TaroAirJab = "DIRECT AÉRIEN", TaroAirHook = "CROCHET AÉRIEN", TaroAirHammer = "POING MÉTÉORE",
	TaroRisingFist = "POING ASCENDANT", TaroChase = "POURSUITE ARDENTE", TaroFinale = "K.O. DE FEU",
	TaroRush = "RUSH DÉVASTATEUR", TaroAwakening = "UPPERCUT CÉLESTE", TaroGate = "火嵐 · TEMPÊTE DE CROCHETS", TaroFatal = "終 · DERNIÈRE CLOCHE",
}, { damage = 1, reach = 0.94 }, {
	TaroJab = { startup = 4, recovery = 8 },
	TaroStraight = { startup = 5 },
	TaroHeavy = { guardDamage = 46 },
	TaroOverhand = { guardDamage = 26 },
})
Moves.TaroParry = move({ -- crouch + E: guard-cancelling parry, counters any standing attack
	id = "TaroParry", name = "PARADE", kind = "Special", startup = 2, active = 14, recovery = 22,
	damage = 0, guardDamage = 0, hitstun = 0, blockstun = 0, hitstop = 0, push = 0, blockPush = 0,
	parry = { from = 3, to = 12, counter = "TaroCounter" },
})
Moves.TaroCounter = move({ -- the counter punch of a successful parry
	id = "TaroCounter", name = "CONTRE", kind = "Special", startup = 3, active = 4, recovery = 20,
	damage = 80, guardDamage = 20, hitstun = 30, blockstun = 16, hitstop = 14,
	push = 26, blockPush = 18, lunge = 8, launch = 24, knockdown = true,
	hitbox = { near = 0, far = 3.9, low = 1, high = 6.2 },
	heavy = true,
})

-- DROITE DU CHAMPION (crouch + E in the CLASSIQUE stance): a slow, wound-up straight that
-- crushes the guard and knocks down.
Moves.TaroChampion = move({
	id = "TaroChampion", name = "DROITE DU CHAMPION", kind = "Special", startup = 14, active = 4, recovery = 22,
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
	id = "TaroDempseyFinish", name = "DEMPSEY · CROCHET FINAL", startup = 9, active = 4, recovery = 24,
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
	ZephyrFront = "PIED DE FACE", ZephyrSide = "PIED LATÉRAL", ZephyrRound = "CIRCULAIRE", ZephyrHigh = "HIGH KICK",
	ZephyrPlexus = "PIED AU PLEXUS", ZephyrRiser = "PIED MONTANT", ZephyrHeel = "TALON PERÇANT",
	ZephyrCyclone = "CYCLONE", ZephyrSkyward = "TRIPLE ENVOL", ZephyrCrescent = "CROISSANT D'AZUR",
	ZephyrGust = "BOURRASQUE", ZephyrHundred = "CENT PIEDS", ZephyrSkyHeel = "TALON CÉLESTE",
	ZephyrBackSpin = "RETOURNÉ", ZephyrPush = "PIED POUSSÉ", ZephyrAxe = "HACHE", ZephyrSweep = "FAUCHAGE",
	ZephyrLow = "PIED BAS", ZephyrAirKick = "PIED AÉRIEN", ZephyrAirKick2 = "DOUBLE AÉRIEN", ZephyrDiveKick = "PIQUÉ DU FAUCON",
	ZephyrEnvol = "ENVOL", ZephyrChase = "PIQUÉ DU VENT", ZephyrFinale = "LAME FINALE", ZephyrBlade = "LAME DE VENT",
	ZephyrRush = "VENT TRANCHEUR", ZephyrAwakening = "DRAGON ASCENDANT", ZephyrGate = "旋風 · CYCLONE FURIEUX", ZephyrFatal = "嵐 · CHUTE DE LA LUNE",
}, { damage = 1.05, startup = 0, reach = 1.12 }, {
	ZephyrBlade = { startup = 11, projectile = { speed = 36, life = 75, damage = 58, halfHeight = 0.7 } },
	ZephyrPush = { push = 36 },
})

-- ===================================================================== AKEMI 影 · shadow
-- Fast and evasive but fragile: the lowest health, quicker wind-ups, a dash that slips
-- through attacks and the passive VOILE D'OMBRE (the first hit of an attack sequence is
-- evaded every 20 s, see Kits.AKEMI.Passive). Crouch + E throws kunai.
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
	AkemiEdge = "LAME DE MAIN", AkemiPalm = "PAUME", AkemiKnee = "GENOU", AkemiFlip = "SALTO",
	AkemiPierce = "PERCÉE", AkemiRise = "ENVOL D'OMBRE", AkemiMark = "MARQUE",
	AkemiWhirl = "TOURBILLON D'OMBRE", AkemiFangs = "TRIPLE CROC", AkemiMoonfall = "CHUTE LUNAIRE",
	AkemiTwin = "LAMES JUMELLES", AkemiThousand = "MILLE ENTAILLES", AkemiStealth = "TALON FURTIF",
	AkemiSpin = "VRILLE", AkemiThrust = "ESTOC", AkemiDrop = "CHUTE", AkemiReap = "FAUCHE",
	AkemiLow = "COUP BAS", AkemiAirEdge = "LAME AÉRIENNE", AkemiAirEdge2 = "DOUBLE LAME", AkemiStoop = "PIQUÉ",
	AkemiStep = "PAS DE L'OMBRE", AkemiChase = "TRAQUE", AkemiFinale = "EXÉCUTION", AkemiKunai = "KUNAÏ",
	AkemiRush = "OMBRES MULTIPLES", AkemiAwakening = "TEMPS SUSPENDU", AkemiGate = "幻舞 · DANSE FANTÔME", AkemiFatal = "刻 · L'INSTANT VOLÉ",
}, { damage = 0.88, startup = 0, reach = 1 }, {
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
	RyukenJab = "JAB", RyukenHook = "CROCHET", RyukenBreaker = "COUDE BRISÉ", RyukenChain = "ENCHAÎNEMENT",
	RyukenGut = "POING AU FOIE", RyukenUppercut = "UPPERCUT", RyukenPound = "MARTÈLEMENT",
	RyukenRage = "RAGE DU POING", RyukenRising = "POING ASCENDANT", RyukenSlam = "SLAM",
	RyukenStorm = "TEMPÊTE DE POINGS", RyukenBarrage = "RAFALE BRISÉE", RyukenCrash = "CHUTE DU POING",
	RyukenSpin = "REVERS TOURNANT", RyukenHeavy = "POING LOURD", RyukenHammer = "MASSE", RyukenSweep = "FAUCHAGE",
	RyukenLow = "COUP BAS", RyukenAirPunch = "POING AÉRIEN", RyukenAirHook = "CROCHET AÉRIEN", RyukenAirSlam = "SLAM AÉRIEN",
	RyukenCharge = "CHARGE FRONTALE", RyukenChase = "POURSUITE", RyukenFinale = "COUP DE GRÂCE", RyukenQuake = "FRAPPE SISMIQUE",
	RyukenRush = "FUREUR DU POING", RyukenAwakening = "EFFONDREMENT", RyukenGate = "拳 · DERNIER ROUND", RyukenFatal = "砕 · POING DU MONDE",
}, { damage = 1.04, startup = 0, reach = 0.95 }, {
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
	ShinCut1 = "TRANCHE 1", ShinCut2 = "TRANCHE 2", ShinThrust = "ESTOC", ShinCombo = "COMBO LAME",
	ShinPierce = "PERCÉE", ShinRising = "TRANCHE MONTANTE", ShinFlow = "FIL DU COURANT",
	ShinCircle = "LAME CIRCULAIRE", ShinSkyCut = "TRANCHE CÉLESTE", ShinCrescent = "CROISSANT D'ACIER",
	ShinGale = "SOUFFLE TRANCHANT", ShinTempest = "TEMPÊTE TRANCHANTE", ShinFalling = "CHUTE DE LAME",
	ShinSpin = "TOURBILLON", ShinBreaker = "BRISE-GARDE", ShinCleave = "FENDOIR", ShinReap = "FAUCHE",
	ShinLow = "TRANCHE BASSE", ShinAirCut = "TRANCHE AÉRIENNE", ShinAirCut2 = "DOUBLE TRANCHE", ShinDive = "PIQUÉ DE LAME",
	ShinStep = "PAS DU VENT", ShinChase = "POURSUITE", ShinFinale = "COUPE FINALE", ShinCurrent = "COURANT TRANCHANT",
	ShinRush = "DANSE DES COURANTS", ShinAwakening = "TEMPÊTE CONTINUE", ShinGate = "零 · ZÉRO HORIZON", ShinFatal = "一閃 · ISSEN",
}, { damage = 0.98, startup = 0, reach = 1.22 }, {
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
	DaichaClaw = "GRIFFURE D'OMBRE", DaichaStep = "PAS OBLIQUE", DaichaThrow = "PROJECTION", DaichaCombo = "COMBO OMBRE",
	DaichaGrip = "ÉTREINTE", DaichaRise = "OMBRE MONTANTE", DaichaMark = "MARQUE SOMBRE",
	DaichaDistortion = "DISTORSION", DaichaSpire = "FLÈCHE D'OMBRE", DaichaEclipse = "DEMI-ÉCLIPSE",
	DaichaVeil = "VOILE INVERSÉ", DaichaRiver = "COURANT D'OMBRES", DaichaFall = "CHUTE INVERSÉE",
	DaichaSpin = "VRILLE", DaichaPush = "POUSSÉE", DaichaDrop = "CHUTE", DaichaReap = "FAUCHE",
	DaichaLow = "GRIFFE BASSE", DaichaAirClaw = "GRIFFE AÉRIENNE", DaichaAirClaw2 = "DOUBLE GRIFFE", DaichaDive = "PIQUÉ D'OMBRE",
	DaichaTeleport = "TÉLÉPORTATION", DaichaChase = "POURSUITE", DaichaFinale = "RETOUR AU NÉANT", DaichaSphere = "SPHÈRE INVERSÉE",
	DaichaRush = "DOMAINE OBSCUR", DaichaAwakening = "RIVIÈRE D'OMBRES", DaichaGate = "蝕 · ÉCLIPSE TOTALE", DaichaFatal = "虚 · NÉANT",
}, { damage = 1.0, startup = 0, reach = 1.05 }, {
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
	HibecaresStrike = "FRAPPE", HibecaresBash = "COUP DE MASSE", HibecaresElbow = "COUDE DE PIERRE", HibecaresChain = "ENCHAÎNEMENT",
	HibecaresGrab = "SAISIE DESTRUCTRICE", HibecaresUpper = "SOULÈVEMENT", HibecaresPress = "ÉCRASEMENT",
	HibecaresRupture = "RUPTURE", HibecaresPillar = "PILIER DE PIERRE", HibecaresQuake = "SÉISME",
	HibecaresAvalanche = "AVALANCHE", HibecaresRubble = "PLUIE DE GRAVATS", HibecaresStomp = "PIÉTINEMENT",
	HibecaresSwing = "REVERS DE CHAÎNE", HibecaresHeavy = "COUP LOURD", HibecaresBreaker = "BRISE-GARDE", HibecaresSweep = "BALAYAGE",
	HibecaresLow = "COUP BAS", HibecaresAirFist = "POING AÉRIEN", HibecaresAirSwing = "CHAÎNE AÉRIENNE", HibecaresMeteor = "CHUTE DE ROC",
	HibecaresShock = "ONDE DE CHOC", HibecaresChase = "POURSUITE", HibecaresFinale = "EFFONDREMENT DU ROI",
	HibecaresRush = "COLOSSE ÉVEILLÉ", HibecaresAwakening = "CHÂTIMENT", HibecaresGate = "崩 · RUINES DU MONDE", HibecaresFatal = "墓 · TOMBEAU DES ROIS",
}, { damage = 1.05, startup = 1, reach = 1 }, {
	HibecaresBreaker = { guardDamage = 40 },
	HibecaresGrab = { guardDamage = 30 },
	HibecaresShock = { lunge = 4, invuln = { from = 1, to = 10 }, launch = 30, hitbox = { near = 0, far = 4.6, low = 0, high = 6.5 } },
})
Moves.HibecaresWall = move({ -- crouch + E: a wall of stone; takes the blow (half damage) and hits back
	id = "HibecaresWall", name = "MUR DE PIERRE", kind = "Special", startup = 3, active = 16, recovery = 26,
	damage = 0, guardDamage = 0, hitstun = 0, blockstun = 0, hitstop = 0, push = 0, blockPush = 0,
	parry = { from = 3, to = 16, counter = "HibecaresCounter", absorb = 0.5, lows = true },
})
Moves.HibecaresCounter = move({ -- the wall bursts toward the attacker
	id = "HibecaresCounter", name = "RIPOSTE DES RUINES", kind = "Special", startup = 4, active = 5, recovery = 22,
	damage = 90, guardDamage = 26, hitstun = 30, blockstun = 16, hitstop = 14,
	push = 30, blockPush = 20, lunge = 6, launch = 26, knockdown = true,
	hitbox = { near = 0, far = 4.2, low = 0, high = 6 },
	heavy = true,
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
	{ keys = "L R L R L R", finale = "TORNADE", moves = { "Jab", "BodyBlow", "PalmStrike", "DragonTornado", "KiChase", "Finale" } },
	{ keys = "R L R L L R", finale = "RAFALE", moves = { "Smash", "Sweep", "RisingWind", "KiFlurry", "KiChase", "Finale" } },
	{ keys = "L L R R L R", finale = "DRAGON", moves = { "Jab", "Cross", "Uppercut", "DragonFist", "KiChase", "Finale" } },
	{ keys = "R R L R L R", finale = "FOUDRE", moves = { "Smash", "Hammer", "ThunderHeel", "DragonFist", "KiChase", "Finale" } },
	{ keys = "L L L R L R", finale = "MUR", moves = { "Jab", "Cross", "Elbow", "SpinKick", "KiChase", "Finale" } },
	{ keys = "L L L L R R", finale = "LUNE", moves = { "Jab", "Cross", "Elbow", "Kick", "CrescentMoon", "Finale" } },
}

-- Scripted cinematics of KAI (the other kits reuse the timing, see below).
local CINEMATICS = {
	KaienRush = {
		Type = "Rush",
		Length = 150,
		FinalTick = 118,
		Hits = { 22, 30, 37, 44, 51, 58, 65, 72, 80, 88, 96 },
		HitDamage = 22,
		FinalDamage = 170,
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
		MaxHealthShare = 0.4,
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
		ComboShare = 0.95,
		RawShare = 0.6,
		MissRatio = 0.4,
		FinishExtra = 0,
		PromptTicks = { 138 },
		PromptWindow = 4,
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
		MaxHealthShare = 0.35,
		MissShare = 0.0575,
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
	Kanji = "開", Role = "POLYVALENT",
	Description = "Tout-terrain : poings, pieds et boule de ki.",
	Roles = KAI_ROLES,
	Stats = { MaxHealth = 1550, WalkSpeed = 17, AirSpeed = 14, JumpVelocity = 43, DashSpeed = 38 },
	RouteNames = { "CHAÎNE", "LANCEUR", "FOIE", "MUR", "HACHE", "BALAYAGE", "TORNADE", "RAFALE", "DRAGON", "FOUDRE", "LUNE" },
	FullRouteNames = { "TORNADE", "RAFALE", "DRAGON", "FOUDRE", "MUR", "LUNE" },
	GateTitle = { text = "開天", sub = "PORTE DES CIEUX" },
	Colors = { TORNADE = "FF2A3D", RAFALE = "FF7A2A", DRAGON = "FF2A3D", FOUDRE = "8FD8FF", MUR = "FF2A3D", LUNE = "FFE9B0" },
})
kit("TARO", {
	Kanji = "火", Role = "BOXEUR",
	Description = "Que les poings, deux styles : CLASSIQUE (touche & / 1 : garde de fer, frappe lourde, DROITE DU CHAMPION) "
		.. "ou ESQUIVE (touche é / 2 : esquive de buste, DEMPSEY ROLL, PARADE qui contre).",
	Roles = TARO,
	-- Two boxing styles, switched in neutral with keys 1 / & (CLASSIQUE) and 2 / é (ESQUIVE).
	-- Each one overrides the kit's stats and its crouch special. ESQUIVE has the weave: the
	-- forward dash ducks under high attacks; during it or Window ticks after, L starts the
	-- DEMPSEY ROLL (alternating hooks, MaxHooks at most) and R its finishing hook.
	Stances = {
		Order = { "CLASSIQUE", "ESQUIVE" },
		CLASSIQUE = {
			Name = "BOXEUR CLASSIQUE", Key = "&",
			Stats = { WalkSpeed = 15, DashSpeed = 34, GuardDamageTaken = 0.6, DamageDealt = 1.08 },
			CrouchSpecial = "TaroChampion",
		},
		ESQUIVE = {
			Name = "BOXEUR ESQUIVE", Key = "é",
			Stats = { WalkSpeed = 17, DashSpeed = 40, GuardDamageTaken = 1, DamageDealt = 0.95 },
			CrouchSpecial = "TaroParry",
			Weave = { Window = 10, Hook = "TaroDempseyL", Finish = "TaroDempseyFinish", MaxHooks = 6 },
		},
	},
	Starters = { Crouch = { Special = "TaroParry" } },
	Stats = { MaxHealth = 1600, WalkSpeed = 15.5, AirSpeed = 13, JumpVelocity = 41, DashSpeed = 36, GuardDamageTaken = 0.8 },
	RouteNames = { "CHAÎNE", "LANCEUR", "FOIE", "MUR", "OVERHAND", "PLONGEON", "GATLING", "HUIT", "VOLCAN", "ÉRUPTION", "MÉTÉORE" },
	FullRouteNames = { "GATLING", "HUIT", "VOLCAN", "ÉRUPTION", "MUR", "MÉTÉORE" },
	GateTitle = { text = "火嵐", sub = "TEMPÊTE DE CROCHETS" },
	Colors = { TORNADE = "FF6A1A", RAFALE = "FF3B1A", DRAGON = "FFB21A", FOUDRE = "FFD45A", MUR = "FF6A1A", LUNE = "FF8C3A" },
})
kit("ZEPHYR", {
	Kanji = "風", Role = "JAMBES",
	Description = "Que les pieds. Plus grande allonge, saut le plus haut, LAME DE VENT (S + E).",
	Roles = ZEPHYR,
	Stats = { MaxHealth = 1450, WalkSpeed = 18.5, AirSpeed = 15.5, JumpVelocity = 48, DashSpeed = 41 },
	RouteNames = { "CHAÎNE", "LANCEUR", "PLEXUS", "MUR", "HACHE", "FAUCHAGE", "CYCLONE", "CENT PIEDS", "ENVOL", "CIEL", "AZUR" },
	FullRouteNames = { "CYCLONE", "CENT PIEDS", "ENVOL", "CIEL", "MUR", "AZUR" },
	GateTitle = { text = "旋風", sub = "CYCLONE FURIEUX" },
	Colors = { TORNADE = "5FE0D0", RAFALE = "9FF0FF", DRAGON = "5FE0D0", FOUDRE = "C8F4FF", MUR = "5FE0D0", LUNE = "E8FFFF" },
})
kit("AKEMI", {
	Kanji = "影", Role = "ESQUIVE",
	Description = "Rapide et fragile : VOILE D'OMBRE esquive un coup toutes les 20 s, dash intouchable, KUNAÏ (S + E).",
	Roles = AKEMI,
	Stats = { MaxHealth = 1100, WalkSpeed = 19, AirSpeed = 15, JumpVelocity = 45, DashSpeed = 44, DashInvuln = 5 },
	-- VOILE D'OMBRE: from neutral (not attacking, not already hit, not guarding) the next
	-- hit is evaded: AKEMI slides back (Slide = push speed, about 2.4 studs), untouchable
	-- for Invuln ticks, unable to act for Recovery ticks; then it recharges for Cooldown
	-- ticks. Ultimates cannot be evaded.
	Passive = { Type = "Evade", Name = "VOILE D'OMBRE", Cooldown = 1200, Invuln = 14, Recovery = 16, Slide = 26 },
	RouteNames = { "CHAÎNE", "ENVOL", "PERCÉE", "MUR", "CHUTE", "FAUCHE", "TOURBILLON", "ENTAILLES", "CROC", "ÉCLIPSE", "CROISSANT" },
	FullRouteNames = { "TOURBILLON", "ENTAILLES", "CROC", "ÉCLIPSE", "MUR", "CROISSANT" },
	GateTitle = { text = "幻舞", sub = "DANSE FANTÔME" },
	Colors = { TORNADE = "B060FF", RAFALE = "8A3CFF", DRAGON = "D08CFF", FOUDRE = "6E7BFF", MUR = "B060FF", LUNE = "E0C8FF" },
})
-- The four fighters of Wilhem's second sheet.
kit("RYUKEN", {
	Kanji = "拳", Role = "FORCE",
	Description = "Brutal : la puissance et la pression. RAGE : chaque coup porté frappe plus fort, perdue quand il est touché.",
	Roles = RYUKEN,
	Stats = { MaxHealth = 1500, WalkSpeed = 17.5, AirSpeed = 14, JumpVelocity = 43, DashSpeed = 40 },
	-- RAGE: each hit landed (not blocked) adds a stack, PerStack more damage each, Max stacks;
	-- all lost when RYUKEN is hit.
	Passive = { Type = "Rage", Name = "RAGE", PerStack = 0.025, Max = 10 },
	RouteNames = { "CHAÎNE", "LANCEUR", "FOIE", "MUR", "MASSE", "FAUCHAGE", "RAGE", "RAFALE", "ASCENSION", "CHUTE", "SLAM" },
	FullRouteNames = { "RAGE", "RAFALE", "ASCENSION", "CHUTE", "MUR", "SLAM" },
	GateTitle = { text = "拳", sub = "DERNIER ROUND" },
	Colors = { TORNADE = "FF2A2A", RAFALE = "FF5A1A", DRAGON = "FF2A2A", FOUDRE = "FFD0C0", MUR = "FF2A2A", LUNE = "FF8A6A" },
})
kit("SHIN", {
	Kanji = "流", Role = "VITESSE",
	Description = "Bretteur : la plus grande allonge, des coupes rapides. PRÉCISION : un coup du bout de la lame fait plus mal.",
	Roles = SHIN,
	Stats = { MaxHealth = 1400, WalkSpeed = 18.5, AirSpeed = 15, JumpVelocity = 45, DashSpeed = 44 },
	-- PRÉCISION: a hit whose target stands in the outer part of the blade's reach (beyond From
	-- of it) deals Bonus more.
	Passive = { Type = "Tip", Name = "PRÉCISION", From = 0.62, Bonus = 0.2 },
	RouteNames = { "CHAÎNE", "LANCEUR", "PERCÉE", "MUR", "FENDOIR", "FAUCHE", "CERCLE", "TEMPÊTE", "CIEL", "CHUTE", "CROISSANT" },
	FullRouteNames = { "CERCLE", "TEMPÊTE", "CIEL", "CHUTE", "MUR", "CROISSANT" },
	GateTitle = { text = "零", sub = "ZÉRO HORIZON" },
	Colors = { TORNADE = "3D9BFF", RAFALE = "6FD8FF", DRAGON = "3D9BFF", FOUDRE = "C8F0FF", MUR = "3D9BFF", LUNE = "A8E4FF" },
})
kit("DAICHA", {
	Kanji = "闇", Role = "ZONING",
	Description = "Mystérieux : contrôle l'espace. SPHÈRE INVERSÉE (S + E), TÉLÉPORTATION, et OMBRE INVERSÉE : son dash traverse l'adversaire.",
	Roles = DAICHA,
	Stats = { MaxHealth = 1400, WalkSpeed = 16, AirSpeed = 14, JumpVelocity = 44, DashSpeed = 38 },
	-- OMBRE INVERSÉE: a forward dash within Range studs of the opponent blinks through to
	-- Gap studs behind them, untouchable for Invuln ticks; Cooldown before the next dash.
	Passive = { Type = "Blink", Name = "OMBRE INVERSÉE", Range = 5, Gap = 1.8, Invuln = 10, Cooldown = 54 },
	RouteNames = { "CHAÎNE", "LANCEUR", "MARQUE", "MUR", "CHUTE", "FAUCHE", "DISTORSION", "RIVIÈRE", "FLÈCHE", "INVERSION", "ÉCLIPSE" },
	FullRouteNames = { "DISTORSION", "RIVIÈRE", "FLÈCHE", "INVERSION", "MUR", "ÉCLIPSE" },
	GateTitle = { text = "蝕", sub = "ÉCLIPSE TOTALE" },
	Colors = { TORNADE = "A040FF", RAFALE = "7A2CFF", DRAGON = "C080FF", FOUDRE = "6E7BFF", MUR = "A040FF", LUNE = "E0C8FF" },
})
kit("HIBECARES", {
	Kanji = "崩", Role = "ENDURANCE",
	Description = "Le roi des ruines : le plus de vie, des coups lourds. MUR DE PIERRE (S + E) encaisse et riposte ; ROI DES RUINES : plus il est blessé, plus il frappe fort.",
	Roles = HIBECARES,
	Starters = { Crouch = { Special = "HibecaresWall" } },
	Stats = { MaxHealth = 1800, WalkSpeed = 13.5, AirSpeed = 12, JumpVelocity = 39, DashSpeed = 30, GuardDamageTaken = 0.85 },
	-- ROI DES RUINES: up to MaxBonus more damage, growing as his health falls from From to To
	-- (shares of his maximum health).
	Passive = { Type = "Ruins", Name = "ROI DES RUINES", MaxBonus = 0.3, From = 1, To = 0.3 },
	RouteNames = { "CHAÎNE", "LANCEUR", "SAISIE", "MUR", "BRISE-GARDE", "BALAYAGE", "RUPTURE", "GRAVATS", "PILIER", "PIÉTINEMENT", "SÉISME" },
	FullRouteNames = { "RUPTURE", "GRAVATS", "PILIER", "PIÉTINEMENT", "MUR", "SÉISME" },
	GateTitle = { text = "崩", sub = "RUINES DU MONDE" },
	Colors = { TORNADE = "FF8A1A", RAFALE = "FFB21A", DRAGON = "FF6A1A", FOUDRE = "FFD45A", MUR = "FF8A1A", LUNE = "C8A070" },
})
MoveData.Cinematics = table.freeze(MoveData.Cinematics)
MoveData.Kits = table.freeze(Kits)
MoveData.KitOrder = table.freeze({ "KAI", "TARO", "ZEPHYR", "AKEMI", "RYUKEN", "SHIN", "DAICHA", "HIBECARES" })

-- KAI's tables, kept for code written before the kits.
MoveData.Starters = Kits.KAI.Starters
MoveData.Routes = Kits.KAI.Routes
MoveData.FullRoutes = Kits.KAI.FullRoutes
MoveData.Cinematic = MoveData.Cinematics.KaienRush

-- Kit of a move id (nil for unknown ids).
local moveKit = {}
for name, data in Kits do
	for _, id in data.Roles do moveKit[id] = name end
end
moveKit.TaroParry, moveKit.TaroCounter = "TARO", "TARO"
moveKit.TaroDempseyL, moveKit.TaroDempseyR, moveKit.TaroDempseyFinish = "TARO", "TARO", "TARO"
moveKit.TaroChampion = "TARO"
moveKit.HibecaresWall, moveKit.HibecaresCounter = "HIBECARES", "HIBECARES"
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
