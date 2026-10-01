--[[
	CPU opponent for the training dummy. Pure Luau (no Roblox API, no require): it reads the
	simulation world and returns the same input table a player would send, so it obeys every
	combat rule and cannot cheat.

	The CPU perceives its opponent with a reaction delay (in ticks) and makes decisions with a
	seeded random generator, so a given seed always plays the same way (useful for tests).
	Higher levels react faster, guard more often and in the right height, punish whiffs,
	anti-air jump-ins and use longer combo routes, specials and the ultimate.
]]
local FighterAI = {}

-- L = light, R = heavy, E = special, U = ultimate, J = jump cancel. `crouch` starts crouching.
local ROUTES = {
	easy = { { "L" }, { "L", "L" }, { "R" } },
	normal = { { "L", "L", "L", "L" }, { "L", "L", "E" }, { "R", "R" }, { "L", "R" }, { "R", "L" } },
	hard = {
		{ "L", "L", "L", "R" }, { "L", "L", "L", "E" }, { "L", "L", "R", "J", "L", "L", "R" },
		{ "R", "R" }, { "R", "L" }, { crouch = true, "L", "L", "E" },
	},
	ultimate = { { "L", "L", "L", "E", "U" }, { "L", "L", "U" }, { "R", "U" } },
}

FighterAI.Levels = table.freeze({
	{ name = "FACILE", reaction = 24, block = 0.15, lowBlock = 0.2, combo = 0.4, aggression = 0.3,
		antiAir = 0.05, punish = 0.1, decision = 20, ultimate = 0, routes = { "easy" } },
	{ name = "NORMAL", reaction = 16, block = 0.45, lowBlock = 0.5, combo = 0.7, aggression = 0.5,
		antiAir = 0.3, punish = 0.35, decision = 14, ultimate = 0.25, routes = { "easy", "normal" } },
	{ name = "DIFFICILE", reaction = 10, block = 0.7, lowBlock = 0.75, combo = 0.88, aggression = 0.65,
		antiAir = 0.6, punish = 0.7, decision = 9, ultimate = 0.6, routes = { "normal", "hard" } },
	{ name = "LÉGENDE", reaction = 6, block = 0.9, lowBlock = 0.92, combo = 0.97, aggression = 0.75,
		antiAir = 0.85, punish = 0.95, decision = 6, ultimate = 1, routes = { "hard" } },
})

local function neutral()
	return {
		axis = 0, crouch = false, jump = false, dash = false, block = false,
		light = false, heavy = false, special = false, ultimate = false,
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
		contact = f.moveContact, airborne = f.y > 0.5, vulnerable = f.stun > 0 or f.launched,
	}
end

function FighterAI:pickPlan(meter, cost)
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
	if world.phase ~= "Fight" or world.cinematic or me.state == "KO" then
		self.plan, self.blockTicks = nil, 0
		return input
	end
	local seen = self.history[math.max(1, #self.history - self.level.reaction)]
	local dx = seen.x - me.x
	local dist, toward = math.abs(dx), if dx >= 0 then 1 else -1
	local grounded = me.y <= 0 and me.vy <= 0
	local ultimateCost = moves.KaienRush.meterCost

	-- 1. Continue the current combo plan, one press per move once it made contact.
	local plan = self.plan
	if plan then
		local nextButton = plan[self.step]
		local moveKey = me.move and (me.move .. tostring(me.moveContact ~= nil))
		if self.step > self.planLength or not nextButton then
			if not me.move then self.plan = nil end
		elseif me.move and me.moveContact then
			local m = moves[me.move]
			if moveKey ~= self.pressedMove then
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
	if me.move or (me.stun > 0 and me.stunKind ~= "Block") or me.launched or me.knockdown > 0 or me.getUp > 0 then
		return input
	end

	-- 2. Defense from what it perceived: guard at the right height or anti-air.
	-- Coming out of hitstun or blockstun under pressure, good players keep guarding.
	if self.wasStunned and me.stun == 0 and dist < 6 and self:chance(self.level.block) then
		self.blockTicks = 14
		self.blockLow = seen.guard == "Low"
	end
	self.wasStunned = me.stun > 0
	if self.blockTicks > 0 then
		self.blockTicks -= 1
		input.block, input.crouch = true, self.blockLow
		if me.stunKind == "Block" or self.blockTicks > 0 then return input end
	end
	if seen.move and (seen.phase == "Startup" or seen.phase == "Active") and dist < 6.5 then
		if seen.airborne and seen.vy < 0 and grounded and self:chance(self.level.antiAir) then
			input.special = true
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

	-- 3. Punish a whiffed or blocked move still recovering.
	if seen.move and seen.phase == "Recovery" and dist < 4.6 and self:chance(self.level.punish) then
		self:pickPlan(me.meter, ultimateCost)
	end
	-- Hit a crumpling or launched opponent that is close.
	if not self.plan and foe.stunKind == "Crumple" and dist < 4.2 then
		self:pickPlan(me.meter, ultimateCost)
	end

	-- 4. Neutral game: walk, dash, jump in, poke, start combos.
	if not self.plan then
		self.intentTicks -= 1
		if self.intentTicks <= 0 then
			self.intentTicks = self.level.decision + math.floor(self:random() * self.level.decision)
			local roll = self:random()
			self.guardLow = self.level.lowBlock > 0.5 and self:chance(0.5)
			if dist > 6 then
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
		elseif intent == "retreat" then
			input.axis = -toward
		elseif intent == "guard" then
			input.block, input.crouch = true, self.guardLow
		elseif intent == "attack" then
			if dist > 4.2 then
				input.axis = toward
			else
				self:pickPlan(me.meter, ultimateCost)
				self.intent = "wait"
			end
		end
	end
	if self.plan and self.step == 1 then
		if dist > 4.4 then
			input.axis = toward
		else
			input.crouch = self.plan.crouch == true
			self:press(input, self.plan[1])
		end
	end
	return input
end

return FighterAI
