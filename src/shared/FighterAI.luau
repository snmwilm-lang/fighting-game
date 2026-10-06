--[[
	CPU opponent for the training dummy. Pure Luau (no Roblox API, no require): it reads the
	simulation world and returns the same input table a player would send, so it obeys every
	combat rule and cannot cheat.

	The CPU perceives its opponent with a reaction delay (in ticks) and makes decisions with a
	seeded random generator, so a given seed always plays the same way (useful for tests).
	Higher levels react faster, guard more often and in the right height, punish whiffs,
	reverse pressure with the invincible special, anti-air jump-ins, zone with ki blasts and use
	longer combo routes (alternating skills included), specials and the ultimate. Every level
	fights back: guarding never locks the CPU into a passive loop.

	DIFFICILE and LÉGENDE also read the opponent's habits (`read`): pressure up close (mashing),
	which guard height its attacks need, zoning and jump-ins. Against pressure they guard,
	answer with the invincible reversal or the fastest jab; against zoning they jump over the
	projectiles; their guard leans to the height the opponent uses most.
]]
-- Without an invincible reversal (KUROEN), getting up means guarding first: the better the
-- guard of the level, the rarer the poke back ((1 - block)^1.1: HARD 34 %, LEGEND 10 %).
local function counterNoReversal(level) return (1 - level.block) ^ 1.1 end

local FighterAI = {}

-- L = light, R = heavy, E = special, U = ultimate, J = jump cancel. `crouch` starts crouching.
local ROUTES = {
	easy = { { "L" }, { "L", "L" }, { "R" }, { "L", "L", "L" } },
	normal = {
		{ "L", "L", "L", "L" }, { "L", "L", "E" }, { "R", "R" }, { "L", "R" }, { "R", "L" },
		{ "L", "R", "L" }, { "L", "L", "R" },
	},
	hard = {
		{ "L", "L", "L", "R" }, { "L", "L", "L", "E" }, { "L", "L", "R", "J", "L", "L", "R" },
		{ "R", "R" }, { "R", "L" }, { crouch = true, "L", "L", "E" },
		{ "L", "R", "L", "R" }, { "R", "L", "R", "L" }, { "L", "L", "R", "R" }, { "R", "R", "L", "R" },
		{ "L", "L", "L", "L", "R" },
	},
	ultimate = { { "L", "L", "L", "E", "U" }, { "L", "L", "U" }, { "R", "U" } },
}

FighterAI.Levels = table.freeze({
	{ name = "EASY", reaction = 22, block = 0.15, lowBlock = 0.2, combo = 0.45, aggression = 0.5,
		antiAir = 0.05, punish = 0.25, reversal = 0.05, counter = 0.4, zoning = 0, promptSpread = 12, decision = 16, ultimate = 0,
		routes = { "easy" } },
	{ name = "NORMAL", reaction = 15, block = 0.4, lowBlock = 0.5, combo = 0.72, aggression = 0.62,
		antiAir = 0.3, punish = 0.5, reversal = 0.15, counter = 0.5, zoning = 0.2, promptSpread = 9, decision = 12, ultimate = 0.25,
		read = 0.35, routes = { "easy", "normal" } },
	{ name = "HARD", reaction = 10, block = 0.62, lowBlock = 0.75, combo = 0.88, aggression = 0.72,
		antiAir = 0.6, punish = 0.75, reversal = 0.3, counter = 0.55, zoning = 0.35, full = 0.25, promptSpread = 6, decision = 8, ultimate = 0.6,
		read = 0.8, routes = { "normal", "hard" } },
	{ name = "LEGEND", reaction = 6, block = 0.88, lowBlock = 0.95, combo = 1, aggression = 0.8,
		antiAir = 0.95, punish = 1, reversal = 0.5, counter = 0.75, zoning = 0.5, full = 0.75, promptSpread = 2, decision = 5, ultimate = 1,
		read = 1, routes = { "hard" } },
})

local function neutral()
	return {
		axis = 0, crouch = false, jump = false, dash = false, block = false,
		light = false, heavy = false, special = false, ultimate = false, fatal = false, stance = 0,
	}
end

-- The CHALLENGE bosses' brains. KUROEN SHIN, the last boss: very hard (Wilhem first: « il doit
-- être vraiment sans limite presque », then: « SHIN il est vraiment trop fort, même les coups
-- aériens il bloque »): reacts in 2 frames, reads 3 jumps in 4 (a jump-in can land), never drops a combo, always
-- ends on his ultimates, reverses pressure, and charges in (an armored dash) instead of
-- walking into a spear. His guard is rolled once per blow (`guardOnce`): 3 blows in 4 high,
-- 2 in 3 low; a mix-up gets through (Wilhem: « comment SHIN bloque tout, tout le temps ? »;
-- rolled every tick, his 95 % was a guard on every blow). ASURA, the first boss, below him (Wilhem: « ils doivent pas être
-- impossibles, juste très compliqués », and KUROEN SHIN the stronger): a slower eye, a guard
-- that a mix-up opens, reads that a feint fools. Not among the menu's levels.
FighterAI.Bosses = table.freeze({
	ASURA = table.freeze({ name = "ASURA", reaction = 4, block = 0.88, lowBlock = 0.95, combo = 1,
		aggression = 0.9, antiAir = 0.9, punish = 0.9, reversal = 0.45, counter = 0.75, zoning = 0.5, full = 1, promptSpread = 0,
		decision = 4, ultimate = 1, read = 0.7, charge = true, varied = true, routes = { "hard" } }),
	["KUROEN SHIN"] = table.freeze({ name = "KUROEN SHIN", reaction = 2, block = 0.75, lowBlock = 0.65, guardOnce = true, combo = 1, aggression = 0.93,
		antiAir = 0.7, punish = 1, reversal = 0.6, counter = 0.85, zoning = 0.5, full = 1, promptSpread = 0, decision = 3,
		ultimate = 1, read = 0.75, charge = true, varied = true, routes = { "hard" },
		-- (0.25.0, Wilhem: « nerfer sa perfection, pas ses stats »: contextual mistakes, see
		-- FighterAI:strainRead; the numbers are tuned with tests/BossReport.luau)
		mistakes = table.freeze({
			-- what he reads as being worked (added to his STRAIN, 0..1, that fades by `calm` a tick)
			calm = 0.985, dash = 0.12, height = 0.03, sway = 0.03, cross = 0.35, whiffBait = 0.14, feint = 0.3,
			rhythm = 0.12, pressure = 0.01,
			-- what the strain does
			decision = 1, -- a real decision time on top of his eye (ticks), even calm
			slow = 6, -- + up to this much under full strain (x strain squared)
			guardDrop = 0.35, -- share of his guard lost under full strain
			lowDrop = 0.35, -- of his low guard
			wrongHeight = 0.25, -- chance to guard the wrong height
			guardTiming = 12, -- ticks his guard may be let go early or held too long
			turtle = 0.25, -- more guarding when worked (the GRAB's answer)
			optimal = 0.9, -- the optimal route (ultimate ending) when his read is clean
			safe = 0.4, -- a short safe string instead, under strain
			extendFail = 0.3, -- an extension he fumbles (the wrong button mid-route)
			confirm = 0.35, -- a missed hit-confirm (stops on hit, goes on on block)
			whiff = 0.25, -- swings from too far
			punishMiss = 0.4, -- a punish missed, or tried too late
			bite = 0.3, -- bites on a feint (a slow blow into it)
			chase = 0.4, -- chases a waking opponent when he should guard
			reads = 0.3, -- his reads (anti-air, counter hit, reversal) blunted under full strain
		}) }),
})
FighterAI.Boss = FighterAI.Bosses.ASURA

-- Does the opponent outreach this fighter (a spear, a sword, long legs)? Its longest neutral
-- button against ours (the boss charges in only then: walking in, it eats the pokes).
function FighterAI:outranged(world, slot)
	local cache = self.reachCache
	local foe = world.fighters[3 - slot]
	if cache and cache.kit == foe.kit then return cache.value end
	local function reach(f)
		local best = 0
		local kit = world.moveData.Kits[f.kit]
		for _, button in { "Light", "Heavy" } do
			local m = kit and world.moves[kit.Starters.Ground[button]]
			if m and m.hitbox then best = math.max(best, m.hitbox.far) end
		end
		return best
	end
	local value = reach(foe) >= 4.6
	self.reachCache = { kit = foe.kit, value = value }
	return value
end

-- levelIndex: 1 (FACILE) to 4 (LÉGENDE), or a boss's name ("ASURA", "KUROEN SHIN").
function FighterAI.new(levelIndex, seed)
	return setmetatable({
		level = FighterAI.Bosses[levelIndex] or FighterAI.Levels[levelIndex],
		seed = (seed or 1) % 2147483647,
		history = {},
		plan = nil, step = 1, pressedMove = nil,
		blockTicks = 0, blockLow = false,
		intent = "wait", intentTicks = 0,
	}, { __index = FighterAI })
end

function FighterAI:random()
	self.seed = (self.seed * 16807) % 2147483647
	return self.seed / 2147483647
end

function FighterAI:chance(p)
	return self:random() < p
end

-- Does it guard this blow, and low? Rolled again each tick it sees the blow coming (a high
-- chance soon becomes a sure guard), or, for a brain with `guardOnce`, once per blow: its
-- `block` is then the real share of blows it guards (Wilhem: « comment SHIN bloque tout, tout
-- le temps ? »).
function FighterAI:guardRoll(seen)
	if not self.level.guardOnce then
		if not self:chance(self.level.block) then return false, false end
		return true, seen.guard == "Low" and self:chance(self.level.lowBlock)
	end
	local key = tostring(seen.move) .. "#" .. tostring(seen.serial)
	if self.guardKey ~= key then
		self.guardKey = key
		local M, strain = self.level.mistakes, self.strain or 0
		local block = if M then self.level.block * (1 - strain * M.guardDrop) else self.level.block
		local low = if M then self.level.lowBlock * (1 - strain * M.lowDrop) else self.level.lowBlock
		self.guardYes, self.guardLowYes = self:chance(block), self:chance(low)
		-- (worked, he may guard the wrong height: a high read as low, a low as high)
		self.guardWrong = M ~= nil and self:chance(strain * M.wrongHeight)
	end
	return self.guardYes, self.guardLowYes, self.guardWrong
end

--[[
	KUROEN SHIN's mistakes (Wilhem, 0.25.0: « il doit rester un boss, mais un excellent joueur
	doit pouvoir le provoquer, créer une erreur et la punir »). Not a flat chance of doing
	something stupid: a STRAIN (0..1) rises with what a good player does to him, as he sees it
	(with his reaction delay), and fades when he is left alone:
	  changes of rhythm between attacks, dashes and air dashes, jumps and crouches (height),
	  walking in and out (distance), cross-ups (ambiguity), whiffs close to him (bait), feints;
	  plain pressure (mashing at one rhythm) barely counts.
	The strain then slows his decisions, opens his guard (late, wrong height, let go early or
	held too long, more turtling: the grab's answer), shortens or fumbles his combos, misses his
	confirms and punishes, makes him swing from too far, bite on feints and chase a waking
	opponent. Calm (a beginner who mashes), he stays the boss.
]]
function FighterAI:strainRead(seen, prev, me, world)
	local M = self.level.mistakes
	if not M then return 0 end
	local s = (self.strain or 0) * M.calm
	local dist = math.abs(seen.x - me.x)
	local log = self.strainLog -- (tests and reports: what worked him, by kind)
	local function add(kind, amount)
		s += amount
		if log then log[kind] = (log[kind] or 0) + amount end
	end
	if prev then
		if seen.dashing and not prev.dashing then add("dash", M.dash) end
		if seen.airborne ~= prev.airborne then add("height", M.height) end
		if seen.crouching ~= prev.crouching and not seen.airborne then add("height", M.height * 0.6) end
		-- (walking in and out, not the lunge of an attack)
		if not seen.move and not prev.move and (seen.vx or 0) * (prev.vx or 0) < 0 and math.abs(seen.vx or 0) > 1 then add("distance", M.sway) end
		-- (hit in between: the next attack's rhythm is not a choice)
		if seen.vulnerable or seen.down then self.lastGap, self.lastAttackTick = nil, nil end
		if (seen.x - me.x) * (prev.x - me.x) < 0 and dist < 6 then add("cross", M.cross) end
		-- (a blow thrown just short of him on purpose: a whiff at the edge of its reach, not a
		-- masher's jab that missed)
		local whiffed = prev.move and not seen.move and not prev.contact and world.moves[prev.move]
		-- (and it worked: he answered it, a guard or a blow of his own)
		if whiffed and whiffed.hitbox and dist > whiffed.hitbox.far + 0.6 and dist < whiffed.hitbox.far + 3
			and (me.move or me.blocking) then
			add("bait", M.whiffBait)
		end
		if seen.feint and not prev.feint then add("feint", M.feint) end
	end
	if seen.move and seen.serial ~= self.strainSerial then
		-- (a new attack: its rhythm against the last one)
		self.strainSerial = seen.serial
		local now = world.tick or 0
		local gap = if self.lastAttackTick then now - self.lastAttackTick else nil
		self.lastAttackTick = now
		if gap and self.lastGap and gap < 180 then
			local change = math.abs(gap - self.lastGap) / math.max(8, gap, self.lastGap)
			add("rhythm", M.rhythm * math.min(1, change * 1.5))
		end
		self.lastGap = gap
		if dist < 5 then add("pressure", M.pressure) end
	end
	self.strain = math.clamp(s, 0, 1)
	return self.strain
end

-- His eye: the level's reaction, plus (with mistakes) a real decision time that grows with
-- the strain (squared: a little strain barely slows him, a player who really works him does).
function FighterAI:reactionTicks()
	local M = self.level.mistakes
	if not M then return self.level.reaction end
	return self.level.reaction + M.decision + math.floor((self.strain or 0) ^ 2 * M.slow + 0.5)
end

-- A mistake whose chance grows with the strain (`base` + `perStrain` x strain).
function FighterAI:slip(perStrain, base)
	if not self.level.mistakes then return false end
	return self:chance((base or 0) + (self.strain or 0) * perStrain)
end

-- A feint seen (once per feint): does he bite? (more often the more he is worked)
function FighterAI:bitesFeint(seen)
	local M = self.level.mistakes
	if not M or not seen.feint or self.bitKey == seen.serial then return false end
	self.bitKey = seen.serial
	return self:slip(M.bite, M.bite * 0.5)
end

-- A read (anti-air, counter hit, reversal) blunted by the strain.
function FighterAI:sharp(value)
	local M = self.level.mistakes
	if not M then return value end
	return value * (1 - (self.strain or 0) * M.reads)
end

-- What the CPU "sees" of a fighter: a light copy pushed into a delayed history.
local function observe(f, moves)
	local m = f.move and moves[f.move]
	local phase
	if m then
		phase = if f.moveFrame <= m.startup then "Startup"
			elseif f.moveFrame <= m.startup + m.active then "Active" else "Recovery"
	end
	return {
		x = f.x, y = f.y, vx = f.vx, vy = f.vy, move = f.move, serial = f.moveSerial, phase = phase, guard = m and m.guard,
		moveFrame = f.moveFrame, crouching = f.crouching,
		contact = f.moveContact, airborne = f.y > 0.5, vulnerable = f.stun > 0 or f.launched, down = f.knockdown > 0 or f.getUp > 0,
		dashing = f.state == "Dashing" or f.state == "AirDash", feint = f.state == "Feint",
	}
end

function FighterAI:pickPlan(meter, cost, fullRoutes, bait, opening)
	self.fumbleAt, self.confirmSlip, self.swingFar = nil, nil, nil
	-- The boss opens from neutral with a mix-up, never twice the same, never a slow blow
	-- (a slow opener from neutral is a free counter hit: Wilhem cornered him and saw him
	-- throw the same SMASH again and again).
	if opening and self.level.varied then
		for attempt = 1, 4 do
			local roll = self:random()
			local plan
			if roll < 0.22 then
				plan = { "R", "L", overhead = true } -- overhead (forward + R): beats the low guard
			elseif roll < 0.42 then
				plan = { crouch = true, "L", "L", "E" } -- low: beats the standing guard
			else
				self:pickPlan(meter, cost, fullRoutes, bait, false)
				plan = self.plan
				if plan[1] ~= "L" and not plan.weave then
					plan = table.clone(plan)
					plan[1] = "L" -- (a fast first button: the jab, then the route)
				end
			end
			local key = (if plan.overhead then "O" elseif plan.crouch then "C" else "") .. table.concat(plan, "")
			if key ~= self.lastOpening or attempt == 4 then
				self.lastOpening = key
				local length = 1
				while length < #plan and self:chance(self.level.combo) do length += 1 end
				self.plan, self.step, self.planLength, self.pressedMove = plan, 1, length, nil
				return
			end
		end
	end
	-- Against a ready evade passive (AKEMI's INSTINCT), a lone jab spends it first.
	if bait and self:chance(self.level.punish * 0.5) then
		self.plan, self.step, self.planLength, self.pressedMove = { "L" }, 1, 1, nil
		return
	end
	-- A boxer (kit.Weave) often weaves in and rolls: dash, then L... and R (DEMPSEY ROLL).
	if self.canWeave and self:chance(0.3) then
		local keys = { "L", "L", "L", "L", "L", "L", "R", weave = true }
		local length = 1
		while length < 6 and self:chance(self.level.combo) do length += 1 end
		if self:chance(self.level.combo) then keys[length + 1], length = "R", length + 1 end
		self.plan, self.step, self.planLength, self.pressedMove = keys, 1, length, nil
		return
	end
	-- With mistakes (KUROEN SHIN), the route follows his read: the optimal one when it is clean,
	-- a short safe string when worked, a standard one most of the time; an extension may be
	-- fumbled (the wrong button mid-route) and a confirm missed (decided here, once per combo).
	local M = self.level.mistakes
	if M then
		local strain = self.strain or 0
		local clean = 1 - strain
		if fullRoutes and self:chance(M.optimal * clean * clean) then
			local route = fullRoutes[math.floor(self:random() * #fullRoutes) + 1]
			local keys = {}
			for key in route.keys:gmatch("%S") do table.insert(keys, key) end
			if meter >= 300 then keys[6] = "U" end
			self.plan, self.step, self.planLength, self.pressedMove = keys, 1, #keys, nil
		else
			local pool = {}
			for _, key in self.level.routes do
				for _, route in ROUTES[key] do table.insert(pool, route) end
			end
			if meter >= cost and self:chance(0.8) then
				for _, route in ROUTES.ultimate do table.insert(pool, route) end
			end
			local route = pool[math.floor(self:random() * #pool) + 1]
			local length = #route
			if self:chance(M.safe * strain) then length = math.min(length, 2) end
			self.plan, self.step, self.planLength, self.pressedMove = route, 1, length, nil
		end
		if self.planLength >= 3 and self:chance(M.extendFail * (0.25 + strain)) then
			self.fumbleAt = 2 + math.floor(self:random() * (self.planLength - 1))
		end
		if self:chance(M.confirm * strain) then self.confirmSlip = true end
		return
	end
	-- The 6-press routes (ending in COUP DE GRÂCE, or ÉVEIL ÉCARLATE with 3 bars).
	if fullRoutes and self.level.full and self:chance(self.level.full) then
		local route = fullRoutes[math.floor(self:random() * #fullRoutes) + 1]
		local keys = {}
		for key in route.keys:gmatch("%S") do table.insert(keys, key) end
		-- Earned ultimates: with 3 bars, end on the right click (ÉVEIL) or the R key (PORTE).
		if meter >= 300 and self:chance(0.5) then keys[6] = "U" end
		local length = 1
		while length < #keys and self:chance(self.level.combo) do length += 1 end
		self.plan, self.step, self.planLength, self.pressedMove = keys, 1, length, nil
		return
	end
	local pool = {}
	for _, key in self.level.routes do
		for _, route in ROUTES[key] do table.insert(pool, route) end
	end
	if meter >= cost and self:chance(self.level.ultimate) then
		for _, route in ROUTES.ultimate do table.insert(pool, route) end
		if self.level.ultimate >= 1 then pool = ROUTES.ultimate end
	end
	local route = pool[math.floor(self:random() * #pool) + 1]
	-- Decide now how far the CPU will get before dropping the combo.
	local length = 1
	while length < #route and self:chance(self.level.combo) do length += 1 end
	self.plan, self.step, self.planLength, self.pressedMove = route, 1, length, nil
end

-- One key per attack seen (its id and start tick), to roll a decision once per attack.
local function opportunityKey(seen, world)
	return seen.move .. ":" .. (world.tick - seen.moveFrame)
end

local BUTTON_FIELD = { L = "light", R = "heavy", E = "special", U = "ultimate" }

function FighterAI:press(input, button)
	if button == "J" then
		input.jump = true
	else
		input[BUTTON_FIELD[button]] = true
	end
	self.step += 1
end

function FighterAI:think(world, slot)
	local input = neutral()
	local me, foe = world.fighters[slot], world.fighters[3 - slot]
	local moves = world.moves
	table.insert(self.history, observe(foe, moves))
	if #self.history > 40 then table.remove(self.history, 1) end
	local cinematic = world.cinematic
	if cinematic and cinematic.attacker == slot and cinematic.prompts then
		-- Rhythm prompts of ÉVEIL ÉCARLATE: accuracy depends on the level.
		local prompt = cinematic.prompts[cinematic.nextPrompt]
		if prompt then
			self.promptOffset = self.promptOffset or {}
			local offset = self.promptOffset[cinematic.nextPrompt]
			if not offset then
				local spread = self.level.promptSpread
				offset = math.floor((self:random() * 2 - 1) * spread + 0.5)
				self.promptOffset[cinematic.nextPrompt] = offset
			end
			if cinematic.tick + 1 == prompt.tick + offset then
				if prompt.button == "Light" then input.light = true
				elseif prompt.button == "Heavy" then input.heavy = true
				elseif prompt.button == "Fatal" then input.fatal = true else input.ultimate = true end
			end
		end
		return input
	end
	self.promptOffset = nil
	if world.phase ~= "Fight" or world.cinematic or me.state == "KO" then
		self.plan, self.blockTicks = nil, 0
		return input
	end
	local reactionIndex = math.max(1, #self.history - self:reactionTicks())
	local seen = self.history[reactionIndex]
	self:strainRead(seen, self.history[reactionIndex - 1], me, world)
	local reaction = self:reactionTicks()
	local strain = self.strain or 0
	local read = self.level.read or 0
	local reads = self.reads
	if read > 0 then
		-- The opponent's habits, as seen (with the reaction delay), fading over ~3 s.
		if not reads then
			reads = { pressure = 0, lows = 0, highs = 0, zoning = 0, jumps = 0, reversals = 0 }
			self.reads = reads
		end
		for key, value in reads do reads[key] = value * 0.996 end
		local started = seen.move and seen.moveFrame <= 1
		if started then
			local m = moves[seen.move]
			if m and m.invuln and math.abs(seen.x - me.x) < 5 then reads.reversals += 1 end
			if m and m.projectile then reads.zoning += 1
			elseif math.abs(seen.x - me.x) < 5 and not seen.airborne then reads.pressure += 1 end
			if m and m.guard == "Low" then reads.lows += 1 elseif m and m.guard == "High" then reads.highs += 1 end
		end
		if seen.airborne and not self.seenAirborne then
			reads.jumps += 1
			self.jumpCount = (self.jumpCount or 0) + 1
		end
		self.seenAirborne = seen.airborne
	end
	-- How hard the opponent is pressing up close (0 = not at all, 1 = mashing).
	local pressing = if reads then math.min(1, reads.pressure / 4) * read else 0
	local dx = seen.x - me.x
	local dist, toward = math.abs(dx), if dx >= 0 then 1 else -1
	local grounded = me.y <= 0 and me.vy <= 0
	-- Every kit shares the combo grammar; its own moves, ultimates and specials differ.
	local kit = world.moveData.Kits[me.kit or "KAI"]
	local ultimateCost = moves[kit.Ultimates.Rush].meterCost
	local fullRoutes = kit.FullRoutes
	-- Kits with stances (TARO: CLASSIQUE / ESQUIVE): the current one's special and weave.
	local stance = kit.Stances and kit.Stances[me.stance]
	local starters = if stance then stance.Starters else kit.Starters
	self.canWeave = (if stance then stance.Weave else kit.Weave) ~= nil
	local crouchSpecial = moves[starters.Crouch.Special]
	local canParry = crouchSpecial ~= nil and crouchSpecial.parry ~= nil
	local parriesLows = canParry and crouchSpecial.parry.lows == true -- HIBECARES's MUR DE PIERRE
	local canZone = crouchSpecial ~= nil and crouchSpecial.projectile ~= nil
	-- The ground special works as an anti-air unless it charges forward (RYUKEN's CHARGE).
	local groundSpecial = moves[starters.Ground.Special]
	local canAntiAir = groundSpecial ~= nil and (groundSpecial.lunge or 0) < 12
	local blink = kit.Passive and kit.Passive.Type == "Blink" and kit.Passive -- DAICHA's OMBRE INVERSÉE
	local foePassive = world.moveData.Kits[foe.kit or "KAI"].Passive
	-- An evade: the boss's only triggers from neutral (a punish never needs the bait); AKEMI's
	-- INSTINCT dodges whenever she is not already hit (her charges must be spent first).
	local instinct = foePassive ~= nil and foePassive.Independent
	local baitEvade = foePassive ~= nil and foePassive.Type == "Evade" and (foe.evadeCharges or 0) > 0
		and (instinct or not foe.move) and foe.stun == 0 and not foe.launched

	-- 1. Continue the current combo plan, one press per move once it made contact.
	local plan = self.plan
	if plan then
		local nextButton = plan[self.step]
		local moveKey = me.move and (me.move .. tostring(me.moveContact ~= nil))
		if self.step > self.planLength or not nextButton then
			if not me.move then self.plan = nil end
		elseif me.move and me.moveContact then
			local m = moves[me.move]
			-- One clean press per link: wait until every hit of the current move is out.
			if moveKey ~= self.pressedMove and me.moveHits >= (m.hits or 1) then
				-- COUP FATAL (last breath): cancelled from a hit that landed, at full power.
				local fatal = kit.Ultimates.Fatal and moves[kit.Ultimates.Fatal]
				local fatalReady = fatal ~= nil and not me.fatalUsed and me.meter >= fatal.meterCost
					and me.hp <= me.maxHp * (world.config.FatalHealth or 0.3) and m.kind ~= "Ultimate" and not m.air
				if me.moveContact == "Hit" and fatalReady and self:chance(self.level.ultimate) then
					input.fatal = true
					self.plan, self.pressedMove = nil, moveKey
					return input
				end
				local blocked = me.moveContact == "Block"
				if self.confirmSlip and self.step == 2 then
					-- (a missed confirm: he reads the first blow wrong; stops a combo that hit,
					-- or goes on with a string that was blocked)
					blocked = not blocked
					self.confirmSlip = nil
				end
				if blocked and self.step > 2 then
					self.plan = nil -- stay safe on block
				elseif self.fumbleAt == self.step and nextButton ~= "J" and nextButton ~= "U" then
					-- (the extension fumbled: the other button, the route breaks there)
					self:press(input, if nextButton == "L" then "R" else "L")
					self.pressedMove, self.fumbleAt, self.planLength = moveKey, nil, self.step - 1
				elseif nextButton == "J" then
					if m.jumpCancel and me.moveFrame > m.startup + m.active then
						self:press(input, "J")
						self.pressedMove = moveKey
					end
				else
					self:press(input, nextButton)
					self.pressedMove = moveKey
				end
			end
			return input
		elseif not me.move and not grounded then
			-- Air follow-up after a jump cancel: strike once the target is close.
			if math.abs(foe.x - me.x) < 4 and math.abs(foe.y - me.y) < 4 and foe.launched then
				self:press(input, nextButton)
				self.pressedMove = nil
			end
			input.axis = if foe.x > me.x then 1 else -1
			return input
		elseif not me.move and self.step > 1 then
			self.plan = nil -- combo dropped or finished
		end
	end
	-- Our attack was just evaded: her counter comes from behind, guard as soon as we can.
	if foe.stunKind == "Evade" and (foe.evadeCounter or 0) > 0 and not me.move and me.stun == 0 then
		self.plan, self.blockTicks, self.blockLow = nil, 16, false
	end
	-- AKEMI's counter in our back: read it as often as we would counter (a fresh press of the
	-- guard in her tight window: let go of it this tick if held, press it the next).
	if (me.blinkRead or 0) > 0 then
		if self.readTry == nil then self.readTry = self:chance(self.level.counter) end
		if self.readTry then
			input.block = not me.blockHeld
			return input
		end
	else
		self.readTry = nil
	end
	-- AKEMI right after an evade: the counter behind the attacker (as often as it counters).
	if (me.evadeCounter or 0) > 0 and me.stunKind == "Evade" and me.meter >= (kit.Passive.CounterCost or 0)
		and self:chance(self.level.counter) then
		input.light = true
		return input
	end
	if me.knockdown > 0 or me.getUp > 0 then self.wasDown = true end
	if me.stun > 0 then self.wasStunned = true end
	if me.move or (me.stun > 0 and me.stunKind ~= "Block") or me.launched or me.knockdown > 0 or me.getUp > 0 then
		return input
	end

	-- 2. Leaving stun or getting up next to the opponent: reversal, counter or keep guarding.
	local recovered = (self.wasStunned or self.wasDown) and me.stun == 0
	self.wasStunned, self.wasDown = me.stun > 0, false
	-- Reads: the opponent gets up next to us and likes its invincible reversal:
	-- guard a moment instead of pressing, then punish the whiffed reversal (see below).
	local foeHeld = seen.down
	local foeRecovered = self.seenHeld and not foeHeld
	self.seenHeld = foeHeld
	if foeRecovered and reads and reads.reversals >= 1.5 and dist < 5 and grounded and not self.plan
		and self:chance(read * 0.85) then
		if self:slip(self.level.mistakes and self.level.mistakes.chase or 0) then
			-- (worked, he chases the waking opponent instead of guarding its reversal)
			self:pickPlan(me.meter, ultimateCost, fullRoutes, baitEvade)
		else
			self.blockTicks, self.blockLow = 14, false
		end
	end
	if recovered and dist < 5 and grounded then
		-- (only through an invincible special: KUROEN's CRIMSON STEP is not one, he must guard)
		if groundSpecial and groundSpecial.invuln and self:chance(self:sharp(self.level.reversal + (1 - self.level.reversal) * pressing * 0.7)) then
			input.special = true -- invincible RISING STRIKE through the pressure
			return input
		elseif self:chance(self.level.counter * (if groundSpecial and not groundSpecial.invuln and not self.level.varied then counterNoReversal(self.level) else 1)) then
			self.blockTicks = 0
			self:pickPlan(me.meter, ultimateCost, fullRoutes, baitEvade) -- poke back right away (fast jab first)
			self.plan = { self.plan[1] == "R" and "L" or self.plan[1], table.unpack(self.plan, 2) }
			self.planLength = math.min(self.planLength, #self.plan)
		elseif self:chance(self.level.block * (if groundSpecial and not groundSpecial.invuln then 1 else 0.6)) then
			self.blockTicks = 10
			self.blockLow = seen.guard == "Low"
		end
	end
	-- 3. Punish: the opponent's move is recovering (whiffed or blocked). One roll per move.
	local opportunity = seen.move and seen.phase == "Recovery" and dist < 4.8
		and (seen.move .. ":" .. (world.tick - seen.moveFrame)) -- start tick identifies the move
	if opportunity and opportunity ~= self.lastOpportunity then
		self.lastOpportunity = opportunity
		local m = moves[seen.move]
		local left = m and (m.startup + m.active + m.recovery - seen.moveFrame - reaction) or 99
		local fastest = moves[starters.Ground.Light].startup
		if read > 0 and reads.reversals >= 1.5 and m and m.cancels and m.cancels.Special then
			-- Reads: this string can still be cancelled into the opponent's invincible reversal.
			self.blockTicks, self.blockLow = 14, false
		elseif read > 0 and left <= fastest and not self:slip(self.level.mistakes and self.level.mistakes.punishMiss * 0.6 or 0) then
			-- Reads: too late to punish (it recovers first); stay safe.
			self.blockTicks, self.blockLow = left + 2, false
		elseif read > 0 and left <= fastest then
			-- (worked: he tries the punish anyway, too late, it fails)
			self.blockTicks = 0
			self:pickPlan(me.meter, ultimateCost, fullRoutes, baitEvade)
		elseif self:chance(self.level.punish * (1 - strain * (if self.level.mistakes then self.level.mistakes.punishMiss else 0))) then
			self.blockTicks = 0
			self:pickPlan(me.meter, ultimateCost, fullRoutes, baitEvade)
		end
	end
	-- A feint (KAI's string stopped, a blow thrown short of him): worked, he bites, a slow
	-- blow into it, guard let go (the feinter's counter hit).
	local M = self.level.mistakes
	if grounded and not self.plan and dist < 5 and self:bitesFeint(seen) then
		self.blockTicks = 0
		input.heavy = true
		return input
	end
	-- Incoming projectile (seen with the reaction delay): guard it once per projectile.
	for _, p in world.projectiles do
		local coming = p.owner ~= slot and math.sign(p.vx) == math.sign(me.x - p.x)
		local eta = math.abs(me.x - p.x) / math.max(1, math.abs(p.vx)) * 60
		if coming and eta < 18 and eta > reaction * 0.5 and p.id ~= self.lastProjectile and grounded
			and not self.plan then
			self.lastProjectile = p.id
			local zoned = if reads then math.min(1, reads.zoning / 3) * read else 0
			if eta > 7 and math.abs(me.x - p.x) > 3 and self:chance(zoned * 0.8) then
				input.jump, input.axis = true, toward -- over the projectile, closing in
				return input
			elseif self:chance(self.level.block) then
				self.blockTicks, self.blockLow = math.ceil(eta) + 4, false
			end
		end
	end
	if self.blockTicks > 0 and not self.plan then
		self.blockTicks -= 1
		-- Reads: while guarding, the guard height follows each new attack seen (once per move).
		if read > 0 and seen.move and seen.phase == "Startup" and seen.guard and self.heightRead ~= opportunityKey(seen, world) then
			self.heightRead = opportunityKey(seen, world)
			if seen.guard == "High" then
				self.blockLow = false
			elseif seen.guard == "Low" and self:chance(self.level.lowBlock) then
				self.blockLow = true
			end
		end
		input.block, input.crouch = true, self.blockLow
		if me.stunKind == "Block" or self.blockTicks > 0 then return input end
	end
	-- Timed anti-air (reads): the jump's arc is predicted from what was seen, so the invincible
	-- rising strike comes out right as the jumper falls into it (once per jump).
	if read > 0 and seen.airborne and grounded and not self.plan and self.aaJump ~= self.jumpCount then
		local y, vy, ticks = seen.y, seen.vy, 0
		local g = world.config.Gravity / 60
		while y > 2.5 and ticks < 90 do
			vy -= g
			y += vy / 60
			ticks += 1
		end
		local lead = ticks - reaction
		local landX = seen.x + (seen.vx or 0) * ticks / 60
		if lead >= 6 and lead <= 10 and math.abs(landX - me.x) < 3.4 then
			self.aaJump = self.jumpCount
			if self:chance(self:sharp(self.level.antiAir * read)) then
				if canAntiAir then
					input.special = true
				else
					self.blockTicks, self.blockLow = lead + 14, false -- guard it standing, punish the landing
					input.block = true
				end
				return input
			end
		end
	end
	if seen.move and (seen.phase == "Startup" or seen.phase == "Active") and dist < 6.5 then
		-- COUNTER HIT (reads): a slow blow started in jab range still has frames left: the jab
		-- gets in first and lands as a counter hit (more damage, more stun) instead of guarding.
		local theirs = world.moves[seen.move]
		local jab = world.moves[kit.Roles and kit.Roles.Jab or "Jab"]
		if read > 0 and theirs and jab and seen.phase == "Startup" and grounded and not seen.airborne and not me.move and dist < 3.4
			and theirs.kind ~= "Ultimate" and not theirs.invuln
			and theirs.startup - (seen.moveFrame + reaction) > jab.startup + 1 and self:chance(self:sharp(self.level.counter * read)) then
			input.light = true
			return input
		end
		if seen.airborne and seen.vy < 0 and grounded and canAntiAir and self:chance(self:sharp(self.level.antiAir)) then
			input.special = true
			return input
		end
		-- A boxer reads the attack and parries it (lows beat the parry, not the stone wall).
		if canParry and seen.phase == "Startup" and (seen.guard ~= "Low" or parriesLows) and not seen.airborne and dist < 4.6
			and self:chance(self.level.block * 0.3) then
			input.crouch, input.special = true, true
			return input
		end
		local guards, low, wrong = self:guardRoll(seen)
		if guards then
			self.blockTicks = 16
			if M then
				-- (worked, his guard is let go too early or held too long: the grab's opening)
				self.blockTicks = math.max(3, 16 + math.floor((self:random() * 2 - 1) * strain * M.guardTiming + 0.5))
			end
			self.blockLow = seen.guard == "Low" and low
			if seen.guard == "High" then self.blockLow = false end
			if seen.guard ~= "Low" and seen.guard ~= "High" and reads then
				self.blockLow = reads.lows > reads.highs -- a mid: lean to the opponent's habit
			end
			if wrong and (seen.guard == "Low" or seen.guard == "High") then self.blockLow = not self.blockLow end
			input.block, input.crouch = true, self.blockLow
			return input
		end
	end
	if not grounded then
		-- Jump-in: kick on the way down.
		if me.vy < 0 and dist < 4 and not me.airAttackUsed then input.light = true end
		input.axis = toward
		return input
	end

	-- Hit a crumpling or launched opponent that is close.
	if not self.plan and foe.stunKind == "Crumple" and dist < 4.2 then
		self:pickPlan(me.meter, ultimateCost, fullRoutes, baitEvade)
	end

	-- 4. Neutral game: walk, dash, jump in, poke, start combos.
	if not self.plan and kit.Stances and grounded and not me.move then
		-- A boxer changes style now and then (seeded, so a seed replays the same fight).
		self.stanceTicks = (self.stanceTicks or math.floor(self:random() * 300)) - 1
		if self.stanceTicks <= 0 then
			self.stanceTicks = 420 + math.floor(self:random() * 480)
			input.stance = if self:chance(0.5) then 1 else 2
		end
	end
	if not self.plan then
		self.intentTicks -= 1
		if self.intentTicks <= 0 then
			self.intentTicks = self.level.decision + math.floor(self:random() * self.level.decision)
			local roll = self:random()
			self.guardLow = self.level.lowBlock > 0.5 and (if reads then reads.lows > reads.highs else self:chance(0.5))
			if dist > 8 and canZone and self:chance(self.level.zoning) then
				self.intent = "blast"
			elseif self.canWeave and dist > 2.8 and dist < 8.5 and self:chance(self.level.aggression * 0.3) then
				self.intent = "dempsey" -- the boxer weaves in and rolls
			elseif blink and dist > 2 and dist <= blink.Range and me.dashCooldown == 0 and self:chance(self.level.aggression * 0.3) then
				self.intent = "blink" -- through the opponent, then strike from behind
			elseif dist > 6 then
				self.intent = if roll < self.level.aggression * 0.6 then "approach"
					elseif roll < self.level.aggression * 0.8 then "dash"
					elseif roll < self.level.aggression then "jumpin" else "wait"
			elseif parriesLows and seen.crouching and self:chance(self.level.block * 0.4) then
				-- The stone wall (HIBECARES) reads a crouching opponent: a low is coming, too
				-- fast to parry on reaction alone.
				self.intent = "wall"
			else
				-- Close range: anticipate (fast pokes cannot be blocked on reaction alone).
				local guard = self.level.block * 0.55 + pressing * 0.3 + (if M then strain * M.turtle else 0)
				self.intent = if roll < guard then "guard"
					elseif roll < guard + self.level.aggression * (1 - guard) then "attack"
					elseif roll < guard + self.level.aggression * (1 - guard) + 0.1 then "retreat" else "wait"
			end
		end
		local intent = self.intent
		if intent == "approach" then
			input.axis = toward
		elseif intent == "dash" then
			input.axis, input.dash = toward, true
			self.intent = "approach"
		elseif intent == "jumpin" then
			input.axis, input.jump = toward, true
			self.intent = "wait"
		elseif intent == "dempsey" then
			-- Weave in (forward dash), then the DEMPSEY ROLL (see pickPlan).
			self.canWeave = true
			repeat self:pickPlan(0, math.huge, nil, false) until self.plan.weave
			self.intent = "wait"
		elseif intent == "wall" then
			input.crouch, input.special = true, true
			self.intent = "wait"
		elseif intent == "blink" then
			input.axis, input.dash = toward, true
			self.intent = "attack"
		elseif intent == "blast" then
			input.crouch, input.special = true, true
			self.intent = "wait"
		elseif intent == "retreat" then
			input.axis = -toward
		elseif intent == "guard" then
			input.block, input.crouch = true, self.guardLow
		elseif intent == "attack" then
			local reach = 4.2
			if M and dist < 6.5 and self:slip(M.whiff) then reach = 6.5 end -- (worked: he swings from too far)
			if dist > reach then
				input.axis = toward
				if self.level.charge and self:outranged(world, slot) and grounded and me.dashTicks == 0 and me.dashCooldown == 0 and dist < 14 then
					input.dash = true
				end
			else
				self:pickPlan(me.meter, ultimateCost, fullRoutes, baitEvade, true)
				if dist > 4.4 then self.swingFar = self.plan end
				if pressing > 0.5 and self.plan[1] ~= "L" and not self.plan.weave then
					-- Against mashing, open with the fastest button (the jab) or lose the trade.
					self.plan = { "L", table.unpack(self.plan, 2) }
					self.planLength = math.min(self.planLength, #self.plan)
				end
				self.intent = "wait"
			end
		end
	end
	-- Reads: an opponent coming down from a jump close by is not the time to start a combo on
	-- the ground (the jump-in hits first): guard standing instead.
	if read > 0 and seen.airborne and dist < 5 and grounded and self.plan and self.step == 1 and self:chance(read) then
		self.plan = nil
		input.block, input.crouch = true, false
		return input
	end
	if self.plan and self.step == 1 then
		if self.plan.weave and grounded and me.dashTicks == 0 and me.dashCooldown == 0 and dist > 2.2 then
			-- The weave first (forward dash): the roll starts on the way in.
			input.axis, input.dash = toward, true
			self.plan.weave = false
		elseif dist > 4.4 and not (M and self.swingFar == self.plan) then
			input.axis = toward
			if self.level.charge and self:outranged(world, slot) and grounded and me.dashTicks == 0 and me.dashCooldown == 0 and dist < 14 then
				input.dash = true -- (the boss charges in: his dash takes a blow)
			end
		else
			if read > 0 and seen.crouching and not self.plan.crouch and not self.plan.overhead and self:chance(read) then
				-- A low guard read: open it with the overhead (forward + R), then its follow-up.
				self.plan = { "R", "L", overhead = true }
				self.planLength = 2
			end
			input.crouch = self.plan.crouch == true
			if self.plan.overhead then input.axis = toward end
			self:press(input, self.plan[1])
		end
	end
	return input
end

return FighterAI
