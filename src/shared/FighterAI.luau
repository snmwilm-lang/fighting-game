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
	{ name = "FACILE", reaction = 22, block = 0.15, lowBlock = 0.2, combo = 0.45, aggression = 0.5,
		antiAir = 0.05, punish = 0.25, reversal = 0.05, counter = 0.4, zoning = 0, promptSpread = 12, decision = 16, ultimate = 0,
		routes = { "easy" } },
	{ name = "NORMAL", reaction = 15, block = 0.4, lowBlock = 0.5, combo = 0.72, aggression = 0.62,
		antiAir = 0.3, punish = 0.5, reversal = 0.15, counter = 0.5, zoning = 0.2, promptSpread = 9, decision = 12, ultimate = 0.25,
		read = 0.35, routes = { "easy", "normal" } },
	{ name = "DIFFICILE", reaction = 10, block = 0.62, lowBlock = 0.75, combo = 0.88, aggression = 0.72,
		antiAir = 0.6, punish = 0.75, reversal = 0.3, counter = 0.55, zoning = 0.35, full = 0.25, promptSpread = 6, decision = 8, ultimate = 0.6,
		read = 0.8, routes = { "normal", "hard" } },
	{ name = "LÉGENDE", reaction = 6, block = 0.88, lowBlock = 0.95, combo = 1, aggression = 0.8,
		antiAir = 0.95, punish = 1, reversal = 0.5, counter = 0.75, zoning = 0.5, full = 0.75, promptSpread = 2, decision = 5, ultimate = 1,
		read = 1, routes = { "hard" } },
})

local function neutral()
	return {
		axis = 0, crouch = false, jump = false, dash = false, block = false,
		light = false, heavy = false, special = false, ultimate = false, fatal = false, stance = 0,
	}
end

-- The CHALLENGE boss (ASURA): LÉGENDE's reads, faster still, never drops a combo, always
-- ends on its ultimates and reverses pressure more often. Not one of the menu's levels.
FighterAI.Boss = table.freeze({ name = "ASURA", reaction = 4, block = 0.93, lowBlock = 0.97, combo = 1, aggression = 0.88,
	antiAir = 0.97, punish = 1, reversal = 0.6, counter = 0.85, zoning = 0.5, full = 0.85, promptSpread = 1, decision = 4,
	ultimate = 1, read = 1, routes = { "hard" } })

-- levelIndex: 1 (FACILE) to 4 (LÉGENDE), or "ASURA" (the boss).
function FighterAI.new(levelIndex, seed)
	return setmetatable({
		level = if levelIndex == "ASURA" then FighterAI.Boss else FighterAI.Levels[levelIndex],
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

-- What the CPU "sees" of a fighter: a light copy pushed into a delayed history.
local function observe(f, moves)
	local m = f.move and moves[f.move]
	local phase
	if m then
		phase = if f.moveFrame <= m.startup then "Startup"
			elseif f.moveFrame <= m.startup + m.active then "Active" else "Recovery"
	end
	return {
		x = f.x, y = f.y, vx = f.vx, vy = f.vy, move = f.move, phase = phase, guard = m and m.guard,
		moveFrame = f.moveFrame, crouching = f.crouching,
		contact = f.moveContact, airborne = f.y > 0.5, vulnerable = f.stun > 0 or f.launched, down = f.knockdown > 0 or f.getUp > 0,
	}
end

function FighterAI:pickPlan(meter, cost, fullRoutes, bait)
	-- Against a ready evade passive (VOILE D'OMBRE), a lone jab spends it first.
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
	local seen = self.history[math.max(1, #self.history - self.level.reaction)]
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
	-- An evade (VOILE D'OMBRE) only triggers from neutral: a punish never needs the bait.
	local baitEvade = foePassive ~= nil and foePassive.Type == "Evade" and (foe.evadeCharges or 0) > 0
		and not foe.move and foe.stun == 0 and not foe.launched

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
				if me.moveContact == "Block" and self.step > 2 then
					self.plan = nil -- stay safe on block
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
		self.blockTicks, self.blockLow = 14, false
	end
	if recovered and dist < 5 and grounded then
		if self:chance(self.level.reversal + (1 - self.level.reversal) * pressing * 0.7) then
			input.special = true -- invincible RISING STRIKE through the pressure
			return input
		elseif self:chance(self.level.counter) then
			self.blockTicks = 0
			self:pickPlan(me.meter, ultimateCost, fullRoutes, baitEvade) -- poke back right away (fast jab first)
			self.plan = { self.plan[1] == "R" and "L" or self.plan[1], table.unpack(self.plan, 2) }
			self.planLength = math.min(self.planLength, #self.plan)
		elseif self:chance(self.level.block * 0.6) then
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
		local left = m and (m.startup + m.active + m.recovery - seen.moveFrame - self.level.reaction) or 99
		local fastest = moves[starters.Ground.Light].startup
		if read > 0 and reads.reversals >= 1.5 and m and m.cancels and m.cancels.Special then
			-- Reads: this string can still be cancelled into the opponent's invincible reversal.
			self.blockTicks, self.blockLow = 14, false
		elseif read > 0 and left <= fastest then
			-- Reads: too late to punish (it recovers first); stay safe.
			self.blockTicks, self.blockLow = left + 2, false
		elseif self:chance(self.level.punish) then
			self.blockTicks = 0
			self:pickPlan(me.meter, ultimateCost, fullRoutes, baitEvade)
		end
	end
	-- Incoming projectile (seen with the reaction delay): guard it once per projectile.
	for _, p in world.projectiles do
		local coming = p.owner ~= slot and math.sign(p.vx) == math.sign(me.x - p.x)
		local eta = math.abs(me.x - p.x) / math.max(1, math.abs(p.vx)) * 60
		if coming and eta < 18 and eta > self.level.reaction * 0.5 and p.id ~= self.lastProjectile and grounded
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
		local lead = ticks - self.level.reaction
		local landX = seen.x + (seen.vx or 0) * ticks / 60
		if lead >= 6 and lead <= 10 and math.abs(landX - me.x) < 3.4 then
			self.aaJump = self.jumpCount
			if self:chance(self.level.antiAir * read) then
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
		if seen.airborne and seen.vy < 0 and grounded and canAntiAir and self:chance(self.level.antiAir) then
			input.special = true
			return input
		end
		-- A boxer reads the attack and parries it (lows beat the parry, not the stone wall).
		if canParry and seen.phase == "Startup" and (seen.guard ~= "Low" or parriesLows) and not seen.airborne and dist < 4.6
			and self:chance(self.level.block * 0.3) then
			input.crouch, input.special = true, true
			return input
		end
		if self:chance(self.level.block) then
			self.blockTicks = 16
			self.blockLow = seen.guard == "Low" and self:chance(self.level.lowBlock)
			if seen.guard == "High" then self.blockLow = false end
			if seen.guard ~= "Low" and seen.guard ~= "High" and reads then
				self.blockLow = reads.lows > reads.highs -- a mid: lean to the opponent's habit
			end
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
				local guard = self.level.block * 0.55 + pressing * 0.3
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
			if dist > 4.2 then
				input.axis = toward
			else
				self:pickPlan(me.meter, ultimateCost, fullRoutes, baitEvade)
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
		elseif dist > 4.4 then
			input.axis = toward
		else
			input.crouch = self.plan.crouch == true
			self:press(input, self.plan[1])
		end
	end
	return input
end

return FighterAI
