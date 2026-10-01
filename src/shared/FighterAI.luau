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
		routes = { "easy", "normal" } },
	{ name = "DIFFICILE", reaction = 10, block = 0.62, lowBlock = 0.75, combo = 0.88, aggression = 0.72,
		antiAir = 0.6, punish = 0.75, reversal = 0.3, counter = 0.55, zoning = 0.35, full = 0.25, promptSpread = 6, decision = 8, ultimate = 0.6,
		routes = { "normal", "hard" } },
	{ name = "LÉGENDE", reaction = 6, block = 0.8, lowBlock = 0.92, combo = 0.97, aggression = 0.8,
		antiAir = 0.85, punish = 0.95, reversal = 0.45, counter = 0.6, zoning = 0.5, full = 0.5, promptSpread = 2, decision = 6, ultimate = 1,
		routes = { "hard" } },
})

local function neutral()
	return {
		axis = 0, crouch = false, jump = false, dash = false, block = false,
		light = false, heavy = false, special = false, ultimate = false, stance = 0,
	}
end

function FighterAI.new(levelIndex, seed)
	return setmetatable({
		level = FighterAI.Levels[levelIndex],
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
		x = f.x, y = f.y, vy = f.vy, move = f.move, phase = phase, guard = m and m.guard,
		moveFrame = f.moveFrame,
		contact = f.moveContact, airborne = f.y > 0.5, vulnerable = f.stun > 0 or f.launched,
	}
end

function FighterAI:pickPlan(meter, cost, fullRoutes, bait)
	-- Against a ready evade passive (VOILE D'OMBRE), a lone jab spends it first.
	if bait and self:chance(self.level.punish) then
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
				elseif prompt.button == "Heavy" then input.heavy = true else input.ultimate = true end
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
	local canZone = crouchSpecial ~= nil and crouchSpecial.projectile ~= nil
	local foePassive = world.moveData.Kits[foe.kit or "KAI"].Passive
	local baitEvade = foePassive ~= nil and foePassive.Type == "Evade" and foe.evadeCharge == 0

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
	if me.knockdown > 0 or me.getUp > 0 then self.wasDown = true end
	if me.stun > 0 then self.wasStunned = true end
	if me.move or (me.stun > 0 and me.stunKind ~= "Block") or me.launched or me.knockdown > 0 or me.getUp > 0 then
		return input
	end

	-- 2. Leaving stun or getting up next to the opponent: reversal, counter or keep guarding.
	local recovered = (self.wasStunned or self.wasDown) and me.stun == 0
	self.wasStunned, self.wasDown = me.stun > 0, false
	if recovered and dist < 5 and grounded then
		if self:chance(self.level.reversal) then
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
		if self:chance(self.level.punish) then
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
			if self:chance(self.level.block) then
				self.blockTicks, self.blockLow = math.ceil(eta) + 4, false
			end
		end
	end
	if self.blockTicks > 0 and not self.plan then
		self.blockTicks -= 1
		input.block, input.crouch = true, self.blockLow
		if me.stunKind == "Block" or self.blockTicks > 0 then return input end
	end
	if seen.move and (seen.phase == "Startup" or seen.phase == "Active") and dist < 6.5 then
		if seen.airborne and seen.vy < 0 and grounded and self:chance(self.level.antiAir) then
			input.special = true
			return input
		end
		-- A boxer reads the attack and parries it (lows beat the parry).
		if canParry and seen.phase == "Startup" and seen.guard ~= "Low" and not seen.airborne and dist < 4.6
			and self:chance(self.level.block * 0.3) then
			input.crouch, input.special = true, true
			return input
		end
		if self:chance(self.level.block) then
			self.blockTicks = 16
			self.blockLow = seen.guard == "Low" and self:chance(self.level.lowBlock)
			if seen.guard == "High" then self.blockLow = false end
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
			self.guardLow = self.level.lowBlock > 0.5 and self:chance(0.5)
			if dist > 8 and canZone and self:chance(self.level.zoning) then
				self.intent = "blast"
			elseif self.canWeave and dist > 2.8 and dist < 8.5 and self:chance(self.level.aggression * 0.3) then
				self.intent = "dempsey" -- the boxer weaves in and rolls
			elseif dist > 6 then
				self.intent = if roll < self.level.aggression * 0.6 then "approach"
					elseif roll < self.level.aggression * 0.8 then "dash"
					elseif roll < self.level.aggression then "jumpin" else "wait"
			else
				-- Close range: anticipate (fast pokes cannot be blocked on reaction alone).
				local guard = self.level.block * 0.55
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
				self.intent = "wait"
			end
		end
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
