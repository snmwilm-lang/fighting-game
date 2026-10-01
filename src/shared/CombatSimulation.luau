--[[
	Authoritative fighting simulation: movement, attacks, guard, combos, ki meter, ultimate
	cinematic and rounds. Pure Luau with no Roblox API and no require, so the same file runs
	on the server and in offline tests. The server passes CombatConfig and MoveData to newWorld.

	One call to step() advances exactly one 60 Hz tick and returns presentation events
	(hits, blocks, KO, announcements). Events never feed back into the simulation.
]]

local CombatSimulation = {}

local BUTTONS = { light = "Light", heavy = "Heavy", special = "Special", ultimate = "Ultimate" }
local BUTTON_ORDER = { "light", "heavy", "special", "ultimate" }
local KEY_LETTER = { Light = "L", Heavy = "R", Special = "E", Ultimate = "U" }

local function newFighter(slot, c)
	local facing = if slot == 1 then 1 else -1
	return {
		slot = slot,
		x = if slot == 1 then -c.SpawnX else c.SpawnX,
		y = 0, vx = 0, vy = 0, pushVx = 0,
		facing = facing,
		state = "Idle",
		dashTicks = 0, dashCooldown = 0, dashDirection = facing,
		hp = c.MaxHealth, guard = c.MaxGuard, guardRegenDelay = 0, meter = 0,
		move = nil, moveFrame = 0, moveContact = nil, airAttackUsed = false,
		moveHits = 0, lastHitFrame = 0, projectileSpawned = false,
		chainKeys = "", chainClean = false, awakenStyle = nil,
		grace = nil, -- { move, ticks }: late presses still link after the move ended
		stun = 0, stunKind = nil, launched = false, juggle = 0,
		pendingBounce = false, bounced = false, wallBounce = false, wallBounced = false, crumpled = false,
		knockdown = 0, getUp = 0,
		hitstop = 0, frozen = false,
		comboHits = 0, comboDamage = 0, calmTicks = 0,
		buffer = {}, -- queued presses { button, ticks }, oldest first
		blocking = false, crouching = false, holdBlock = false, holdCrouch = false,
		wins = 0,
	}
end

local function resetFighters(world)
	for slot = 1, 2 do
		local old = world.fighters[slot]
		world.fighters[slot] = newFighter(slot, world.config)
		if old then
			world.fighters[slot].wins = old.wins
			world.fighters[slot].meter = old.meter -- ki carries over between rounds
		end
	end
	world.epoch += 1
	world.timerTicks = world.config.RoundSeconds * world.config.TickRate
	world.winner = nil
	world.reason = nil
	world.cinematic = nil
	world.projectiles = {}
end

function CombatSimulation.newWorld(config, moveData, training)
	local world = {
		config = config,
		moveData = moveData,
		moves = moveData.Moves,
		fighters = {},
		epoch = 0,
		tick = 0,
		projectiles = {},
		nextProjectileId = 0,
	}
	CombatSimulation.resetMatch(world, training)
	return world
end

-- Full reset: health, guard, meter, states, buffers, wins and round counter.
function CombatSimulation.resetMatch(world, training)
	world.training = training
	world.fighters = {}
	resetFighters(world)
	world.round = 1
	world.matchWinner = nil
	if training then
		world.phase, world.phaseTicks = "Fight", 0
	else
		world.phase, world.phaseTicks = "Intro", world.config.IntroTicks
	end
end

function CombatSimulation.neutralInput()
	return {
		axis = 0, crouch = false, jump = false, dash = false, block = false,
		light = false, heavy = false, special = false, ultimate = false,
	}
end

local function isGrounded(f)
	return f.y <= 0 and f.vy <= 0
end

local function isInvulnerable(f, c, moves)
	if f.state == "KO" or f.knockdown > 0 or f.getUp > 0 or (f.launched and f.juggle >= c.MaxJuggleHits) then
		return true
	end
	local m = f.move and moves[f.move]
	return m ~= nil and m.invuln ~= nil and f.moveFrame >= m.invuln.from and f.moveFrame <= m.invuln.to
end

local function canTurn(f)
	return f.state ~= "KO" and not f.move and f.stun == 0 and not f.launched
		and f.knockdown == 0 and f.dashTicks == 0 and isGrounded(f)
end

local function gainMeter(f, amount, c)
	f.meter = math.clamp(f.meter + amount, 0, c.MaxMeter)
end

-- Integrates position. Returns true on the tick the fighter lands.
local function physics(f, c)
	local dt = 1 / c.TickRate
	f.x = math.clamp(f.x + (f.vx + f.pushVx) * dt, c.ArenaMinX, c.ArenaMaxX)
	if f.wallBounce and ((f.x >= c.ArenaMaxX and f.pushVx > 0) or (f.x <= c.ArenaMinX and f.pushVx < 0)) then
		f.pushVx = -f.pushVx * 0.3
		f.vy = c.WallBounceVelocity
		f.wallBounce, f.wallBounced, f.justWallBounced = false, true, true
	end
	f.pushVx *= if f.launched then c.AirPushDecay else c.PushbackDecay
	if math.abs(f.pushVx) < 0.2 then f.pushVx = 0 end
	if f.y > 0 or f.vy > 0 then
		f.vy -= c.Gravity * dt
		f.y += f.vy * dt
		if f.y <= 0 then
			f.y, f.vy = 0, 0
			return true
		end
	end
	return false
end

local function startMove(world, f, id, events, isLink)
	local m = world.moves[id]
	local entry = table.remove(f.buffer, 1)
	local letter = if entry then KEY_LETTER[entry.button] else "?"
	if isLink then
		-- A link of the current combo: remember the typed route and whether it stayed clean.
		f.chainKeys ..= letter
		-- (a link keeps the combo clean; spam is detected when it happens)
	else
		f.chainKeys, f.chainClean = letter, not f.dirtyStart
		f.dirtyStart = false
	end
	f.move, f.moveFrame, f.moveContact = id, 1, nil
	f.moveHits, f.lastHitFrame, f.projectileSpawned = 0, 0, false
	if m.air then f.airAttackUsed = true end
	if m.homing then
		local target = world.fighters[3 - f.slot]
		local c = world.config
		-- Leap high enough to meet the target (vertical speed decided once, at the start).
		local height = math.max(0, target.y + 1.5 - f.y)
		f.vy = math.clamp(math.sqrt(2 * c.Gravity * height), 0, 48)
	end
	if m.skill then
		table.insert(events, { kind = "Skill", attacker = f.slot, move = id })
	end
	if m.meterCost then
		f.meter -= m.meterCost
		-- Super flash: everyone freezes while the ultimate is announced.
		local flash = world.config.SuperFlashTicks
		for _, other in world.fighters do
			other.hitstop = math.max(other.hitstop, flash)
		end
		f.hitstop = flash
		table.insert(events, { kind = "SuperFlash", attacker = f.slot, move = id })
	end
end

-- Name of the full route whose first five links this combo matches, if it was played cleanly.
function CombatSimulation.awakeningStyle(world, f, currentId)
	if not f.chainClean or #f.chainKeys ~= 5 then return nil end
	for _, route in world.moveData.FullRoutes do
		local keys = route.keys:gsub("%s", "")
		if keys:sub(1, 5) == f.chainKeys and route.moves[5] == (currentId or f.move) then
			return route.name
		end
	end
	return nil
end

local function chooseMove(world, f, grounded, crouching)
	local head = f.buffer[1]
	if not head then return nil end
	local moves, starters, button = world.moves, world.moveData.Starters, head.button
	local nextId
	local currentId = f.move or (f.grace and f.grace.move)
	if currentId then
		local current = moves[currentId]
		if f.move then
			if not f.moveContact or f.moveFrame <= current.startup then return nil end
			-- A multi-hit move can only be cancelled once all its hits are out.
			if f.moveHits < (current.hits or 1) and f.moveFrame <= current.startup + current.active then return nil end
		end
		if button == "Special" and current.kind == "Normal" and not current.air then
			nextId = (if crouching then starters.Crouch else starters.Ground).Special
		elseif button == "Ultimate" and current.kind ~= "Ultimate" and not current.air then
			nextId = starters.Ground.Ultimate
			-- Third ultimate, PORTE DES CIEUX: the five first links of a full route played
			-- cleanly (one press per link, after each hit), then the R key with 3 bars.
			local style = CombatSimulation.awakeningStyle(world, f, currentId)
			if style and f.meter >= moves.Kaiten.meterCost then
				nextId = "Kaiten"
				f.awakenStyle = style
			end
		elseif current.cancels then
			nextId = current.cancels[button]
			-- Second ultimate, ÉVEIL ÉCARLATE: the same clean route ending on the right click.
			if nextId == "Finale" then
				local style = CombatSimulation.awakeningStyle(world, f, currentId)
				if style and f.meter >= moves.Awakening.meterCost then
					nextId = "Awakening"
					f.awakenStyle = style
				end
			end
		end
	end
	if not nextId and f.move and f.moveContact and not head.judged then
		-- The cancel window is open and this button continues nothing: wrong button.
		head.judged = true
		f.chainClean = false
	end
	local isLink = nextId ~= nil and currentId ~= nil
	if not nextId and not f.move and f.dashTicks == 0 then
		-- Neutral start (also when a late press is not a valid cancel of the finished move).
		if grounded then
			nextId = (if crouching then starters.Crouch else starters.Ground)[button]
		elseif not f.airAttackUsed then
			nextId = starters.Air[button]
		end
	end
	local m = nextId and moves[nextId]
	if m and m.meterCost and f.meter < m.meterCost then return nil end
	if m and m.projectile then
		for _, p in world.projectiles do
			if p.owner == f.slot then return nil end -- one ki blast on screen at a time
		end
	end
	return nextId, isLink
end

local function stepFighter(world, f, input, events)
	local c, moves = world.config, world.moves
	-- Presses queue in the order typed, so mashing L L L R gives exactly that route.
	-- While being hit, knocked down, getting up or guarding, presses are ignored except in
	-- the last few ticks (a deliberate reversal): mashing under pressure never fires on its own.
	local locked = f.state == "KO" or f.launched or f.knockdown > 0 or f.getUp > 0 or f.stun > 0
	local remaining = if f.state == "KO" or f.launched or f.knockdown > 0 then math.huge
		elseif f.getUp > 0 then f.getUp else f.stun
	local recovered = f.wasLocked and not locked
	f.wasLocked = locked
	if recovered and input.block then
		table.clear(f.buffer) -- holding guard while recovering: guard wins
	end
	-- Spam = hitting every button: several buttons on the same tick, a press that overflows
	-- the queue, a wrong button or a press that is never used. Typing the right route fast
	-- (even entirely ahead of time) stays clean.
	local pressed = 0
	for _, field in BUTTON_ORDER do
		if input[field] and (not locked or remaining <= c.ReversalBufferTicks) then
			pressed += 1
			if #f.buffer >= c.BufferSize then
				table.remove(f.buffer, 1)
				f.chainClean = false
			end
			table.insert(f.buffer, { button = BUTTONS[field], ticks = c.BufferTicks })
		end
	end
	if pressed > 1 then
		f.chainClean = false
		f.dirtyStart = true -- also spoils a combo that these presses would start
	end
	if f.hitstop > 0 then
		-- Hitstop suspends everything, including move frames and stun counters.
		f.hitstop -= 1
		f.frozen = true
		return
	end
	f.frozen = false
	f.holdBlock, f.holdCrouch = input.block, input.crouch
	f.dashCooldown = math.max(0, f.dashCooldown - 1)
	if f.guardRegenDelay > 0 then
		f.guardRegenDelay -= 1
	elseif f.stunKind ~= "GuardBreak" then
		f.guard = math.min(c.MaxGuard, f.guard + c.GuardRegenPerTick)
	end

	local grounded = isGrounded(f)

	if f.state == "KO" then
		f.vx = 0
		physics(f, c)
		return
	end
	if f.knockdown > 0 then
		f.knockdown -= 1
		f.vx, f.state = 0, "Knockdown"
		if f.knockdown == 0 then f.getUp = c.GetUpTicks end
		physics(f, c)
		return
	end
	if f.getUp > 0 then
		f.getUp -= 1
		f.vx, f.state = 0, "GetUp"
		physics(f, c)
		return
	end
	if f.launched then
		f.vx, f.state = 0, "Launched"
		if physics(f, c) then
			if f.pendingBounce then
				f.pendingBounce, f.bounced = false, true
				f.vy = c.GroundBounceVelocity
				f.justBounced = true
			else
				f.launched, f.juggle = false, 0
				f.stun, f.stunKind = 0, nil
				f.knockdown, f.state = c.KnockdownTicks, "Knockdown"
			end
		end
		return
	end
	if f.stun > 0 then
		f.stun -= 1
		f.vx = 0
		f.crouching = f.stunKind == "Block" and f.holdCrouch
		f.state = if f.stunKind == "Block" then (if f.crouching then "CrouchBlockstun" else "Blockstun")
			elseif f.stunKind == "GuardBreak" then "GuardBroken"
			elseif f.stunKind == "Crumple" then "Crumple"
			else "Hitstun"
		if f.stun == 0 then
			if f.stunKind == "GuardBreak" then f.guard = c.MaxGuard end
			f.stunKind = nil
		end
		physics(f, c)
		return
	end

	-- Actionable from here: the defender has truly recovered, so any combo on it is over.
	f.comboHits, f.comboDamage = 0, 0
	f.bounced, f.wallBounced, f.crumpled = false, false, false

	if f.move then
		local m = moves[f.move]
		f.moveFrame += 1
		if m.jumpCancel and f.moveContact == "Hit" and input.jump and grounded
			and f.moveFrame > m.startup + m.active then
			-- Super jump after a launcher to follow the target.
			f.move, f.moveContact = nil, nil
			f.vy = c.SuperJumpVelocity
			f.vx = input.axis * c.AirSpeed
			f.airAttackUsed = false
			grounded = false
			table.insert(events, { kind = "SuperJump", attacker = f.slot })
		elseif f.moveFrame > world.moveData.total(m) then
			-- A move that connected keeps its cancels for a few more ticks (network latency).
			if f.moveContact and f.moveHits >= (m.hits or 1) then
				f.grace = { move = f.move, ticks = c.LateCancelTicks }
			end
			f.move, f.moveContact = nil, nil
		end
	end
	if f.grace and not f.move then
		f.grace.ticks -= 1
		if f.grace.ticks < 0 then f.grace = nil end
	end
	local nextId, isLink = chooseMove(world, f, grounded, input.crouch)
	if nextId then
		f.grace = nil
		startMove(world, f, nextId, events, isLink)
	end
	-- Only the press waiting its turn ages, and only once the current move is recovering:
	-- presses typed during startup/active wait for the contact that allows the cancel.
	local head = f.buffer[1]
	local current = f.move and moves[f.move]
	local waiting = current and f.moveFrame <= current.startup + current.active
	if head and not waiting then
		head.ticks -= 1
		if head.ticks <= 0 then
			table.remove(f.buffer, 1)
			if f.move or f.grace then f.chainClean = false end -- a press that was never used
		end
	end

	if f.move then
		local m = moves[f.move]
		f.blocking, f.crouching = false, f.move == "LowKick"
		if m.homing or m.track then
			-- Steer toward a spot just in front of the target every tick until the hits are out.
			local target = world.fighters[3 - f.slot]
			local steering = f.moveFrame <= m.startup + m.active and f.moveHits < (m.hits or 1)
			local gap = target.x - f.facing * 1.4 - f.x
			f.vx = if steering then math.clamp(gap * 10, -m.lunge, m.lunge) elseif grounded then 0 else f.vx * 0.9
		elseif grounded and not m.air then
			f.vx = if f.moveFrame <= m.startup + m.active then f.facing * m.lunge else 0
		end
		f.state = "Attack"
		if m.projectile and not f.projectileSpawned and f.moveFrame == m.startup + 1 then
			f.projectileSpawned = true
			local data = m.projectile
			world.nextProjectileId += 1
			table.insert(world.projectiles, {
				id = world.nextProjectileId, owner = f.slot, data = data,
				x = f.x + f.facing * data.spawnX, y = f.y + data.height, oldX = f.x,
				vx = f.facing * data.speed, life = data.life,
			})
			table.insert(events, { kind = "Projectile", attacker = f.slot })
		end
		if physics(f, c) and m.air then
			f.move, f.moveContact, f.state = nil, nil, "Idle"
		end
		if isGrounded(f) then f.airAttackUsed = false end
		return
	end

	local crouched = grounded and input.crouch and f.dashTicks == 0
	local blocking = grounded and input.block and f.dashTicks == 0
	if input.jump and grounded and not crouched and not blocking and f.dashTicks == 0 then
		f.vy = c.JumpVelocity
		grounded = false
		f.airAttackUsed = false
	end
	if input.dash and grounded and not crouched and not blocking and f.dashTicks == 0 and f.dashCooldown == 0 then
		f.dashDirection = if math.abs(input.axis) > 0.1 then math.sign(input.axis) else f.facing
		f.dashTicks = c.DashTicks
		f.dashCooldown = c.DashCooldownTicks
	end
	f.crouching, f.blocking = crouched, blocking
	if f.dashTicks > 0 then
		f.vx = f.dashDirection * c.DashSpeed
		f.dashTicks -= 1
		f.state = "Dashing"
	elseif blocking then
		f.vx = 0
		f.state = if crouched then "CrouchBlocking" else "Blocking"
	elseif crouched then
		f.vx = 0
		f.state = "Crouching"
	else
		f.vx = input.axis * (if grounded then c.WalkSpeed else c.AirSpeed)
		f.state = if math.abs(f.vx) > 0.05 then "Walking" else "Idle"
	end
	physics(f, c)
	if isGrounded(f) then
		f.airAttackUsed = false
	else
		f.state = if f.vy > 0 then "Jumping" else "Falling"
	end
end

-- Pushboxes: fighters never cross while vertically overlapping. Facing follows the opponent
-- only when a fighter is free to turn (never mid-attack, mid-stun, mid-dash or airborne).
local function resolvePair(a, b, c, previousDelta)
	local delta = b.x - a.x
	if math.abs(a.y - b.y) < c.PushHeight then
		local order = if previousDelta >= 0 then 1 else -1
		if delta * order < c.PushWidth then
			local center = math.clamp((a.x + b.x) / 2,
				c.ArenaMinX + c.PushWidth / 2, c.ArenaMaxX - c.PushWidth / 2)
			a.x = center - order * c.PushWidth / 2
			b.x = center + order * c.PushWidth / 2
		end
	end
	if math.abs(b.x - a.x) > 0.05 then
		if canTurn(a) then a.facing = math.sign(b.x - a.x) end
		if canTurn(b) then b.facing = math.sign(a.x - b.x) end
	end
end

function CombatSimulation.hitbox(f, m)
	local hb = m.hitbox
	local x1, x2 = f.x + f.facing * hb.near, f.x + f.facing * hb.far
	return math.min(x1, x2), math.max(x1, x2), f.y + hb.low, f.y + hb.high
end

function CombatSimulation.hurtbox(f, c)
	local height = if f.crouching then c.CrouchHurtHeight else c.HurtHeight
	return f.x - c.HurtHalfWidth, f.x + c.HurtHalfWidth, f.y, f.y + height
end

local function hitboxActive(f, moves)
	if not f.move or f.frozen then return nil end
	local m = moves[f.move]
	if not m.hitbox or f.moveHits >= (m.hits or 1) then return nil end
	if f.moveHits > 0 and f.moveFrame - f.lastHitFrame < m.hitInterval then return nil end
	if f.moveFrame > m.startup and f.moveFrame <= m.startup + m.active then return m end
	return nil
end

local function canBlock(d, sourceX, m)
	if not isGrounded(d) or d.move then return false end
	local guarding = d.blocking or (d.stunKind == "Block" and d.holdBlock)
	if not guarding then return false end
	local side = math.sign(sourceX - d.x)
	if side ~= 0 and side ~= d.facing then return false end -- attacked from behind
	local crouching = d.holdCrouch
	if m.guard == "High" and crouching then return false end
	if m.guard == "Low" and not crouching then return false end
	return true
end

local function applyPush(a, d, speed, c, source)
	local fromX = if source then source.x else a.x
	local dir = if d.x > fromX then 1 elseif d.x < fromX then -1 else (if source then source.dir else a.facing)
	local cornered = (dir > 0 and d.x >= c.ArenaMaxX - c.CornerMargin)
		or (dir < 0 and d.x <= c.ArenaMinX + c.CornerMargin)
	if cornered and not d.wallBounce and not source then
		a.pushVx = -dir * speed * c.CornerPushRatio
	else
		d.pushVx = dir * speed
	end
end

local function comboScale(d, c, minimum)
	return math.max(minimum or c.MinComboScaling, c.ComboScaling ^ d.comboHits)
end

-- Builds the authoritative script of a cinematic: which tick deals how much damage.
local function startCinematic(world, a, d, events, moveId)
	local c = world.config
	local cin = world.moveData.Cinematics[moveId]
	local plan, finish = {}, false
	if moveId == "Kaiten" then
		-- A fixed share of the MAXIMUM health, ignoring combo scaling; it can KO.
		local total = math.floor(c.MaxHealth * cin.MaxHealthShare)
		finish = total >= d.hp
		local share = math.floor(total * cin.HitShare)
		for _, t in cin.Hits do table.insert(plan, { tick = t, damage = share }) end
		table.insert(plan, { tick = cin.FinalTick, damage = total - share * #cin.Hits, final = true })
	elseif moveId == "Awakening" then
		-- 95 % of the current health whatever it is; below half the maximum: FINAL FINISH.
		finish = d.hp < c.MaxHealth * cin.FinishThreshold
		local total = if finish then d.hp else math.floor(d.hp * cin.HealthRatio)
		local share = math.floor(total * cin.HitShare)
		for _, t in cin.Hits do table.insert(plan, { tick = t, damage = share }) end
		table.insert(plan, { tick = cin.FinalTick, damage = total - share * #cin.Hits, final = true })
	else
		local scale = comboScale(d, c, cin.MinScaling)
		for _, t in cin.Hits do
			table.insert(plan, { tick = t, damage = math.max(1, math.floor(cin.HitDamage * scale + 0.5)) })
		end
		table.insert(plan, { tick = cin.FinalTick, damage = math.max(1, math.floor(cin.FinalDamage * scale + 0.5)), final = true })
	end
	-- ÉVEIL ÉCARLATE: rhythm prompts during the rush, taken from the route that was played.
	local prompts = {}
	local style = a.awakenStyle
	if moveId == "Kaiten" then
		for _, t in cin.PromptTicks do
			table.insert(prompts, { tick = t, button = "Ultimate", result = nil })
		end
	elseif moveId == "Awakening" then
		local keys = "LRLR"
		for _, route in world.moveData.FullRoutes do
			if route.name == style then keys = route.keys:gsub("%s", "") end
		end
		for i, t in cin.PromptTicks do
			local letter = keys:sub(i, i)
			table.insert(prompts, { tick = t, button = if letter == "R" then "Heavy" else "Light", result = nil })
		end
	end
	world.cinematic = {
		attacker = a.slot, defender = d.slot, move = moveId, tick = 0, finish = finish, style = style,
		length = cin.Length + (if finish then cin.FinishExtra else 0), finalTick = cin.FinalTick, plan = plan,
		prompts = prompts, nextPrompt = 1, perfect = 0,
	}
	a.move, a.moveContact, a.state = moveId, "Hit", "Cinematic"
	a.pushVx, d.pushVx, a.vx = 0, 0, 0
	d.stun, d.stunKind, d.state = 999, "Hit", "Hitstun"
	table.insert(events, { kind = "CinematicStart", attacker = a.slot, defender = d.slot, move = moveId,
		finish = finish, style = style })
end

-- Applies one hit (or blocked hit) of move m from attacker a on defender d. `source` is set
-- for projectiles: { x, y, dir }; the attacker is then not frozen and not pushed.
local function applyHit(world, a, d, m, events, source)
	local c = world.config
	local event = { attacker = a.slot, defender = d.slot, move = m.id, heavy = m.heavy == true }
	if source then
		event.x, event.y, event.projectile = source.x, source.y, true
	else
		local hx1, hx2, hy1, hy2 = CombatSimulation.hitbox(a, m)
		local dx1, dx2, dy1, dy2 = CombatSimulation.hurtbox(d, c)
		event.x = (math.max(hx1, dx1) + math.min(hx2, dx2)) / 2
		event.y = (math.max(hy1, dy1) + math.min(hy2, dy2)) / 2
		a.moveHits += 1
		a.lastHitFrame = a.moveFrame
	end
	local hits = m.hits or 1
	local final = source ~= nil or a.moveHits >= hits
	local firstHit = source ~= nil or a.moveHits == 1
	local stop = if final then m.hitstop else (m.multiHitstop or 3)
	if canBlock(d, if source then source.x else a.x, m) then
		if not source then a.moveContact = "Block" end
		local chip = math.floor(m.damage * c.BlockDamageRatio + 0.5)
		d.hp = math.max(math.min(d.hp, 1), d.hp - chip)
		event.damage = chip
		d.guard -= m.guardDamage
		d.guardRegenDelay = c.GuardRegenDelayTicks
		d.blocking = true
		if m.kind ~= "Ultimate" then gainMeter(a, m.damage * c.MeterOnBlock, c) end
		gainMeter(d, m.damage * c.MeterWhenBlocking, c)
		if d.guard <= 0 then
			d.guard = 0
			d.stun, d.stunKind = c.GuardBreakTicks, "GuardBreak"
			d.blocking = false
			event.kind = "GuardBreak"
		else
			d.stun, d.stunKind = m.blockstun, "Block"
			event.kind = "Block"
		end
		applyPush(a, d, if final then m.blockPush else 2, c, source)
		stop = math.max(3, stop - 2)
		if not source then a.hitstop = stop end
		d.hitstop = stop
		table.insert(events, event)
		return
	end

	if not source then a.moveContact = "Hit" end
	local damage = math.max(1, math.floor(m.damage * comboScale(d, c) + 0.5))
	d.hp = math.max(0, d.hp - damage)
	d.comboHits += 1
	d.comboDamage += damage
	if m.kind ~= "Ultimate" then gainMeter(a, damage * c.MeterOnHit, c) end
	gainMeter(d, damage * c.MeterWhenHit, c)
	d.move, d.moveContact, d.dashTicks, d.grace = nil, nil, 0, nil
	d.blocking, d.crouching = false, false
	d.stun, d.stunKind = m.hitstun, "Hit"
	d.calmTicks = 0
	local airborne = not isGrounded(d) or d.launched
	if firstHit and (airborne or (final and (m.launch ~= 0 or m.groundBounce))) then
		d.juggle += 1 -- juggle points count moves, not the individual hits of a multi-hit
	end
	if not final then
		-- Intermediate hit of a multi-hit move: hold the target in place.
		if airborne then
			d.vy = math.max(d.vy, m.holdVy or 8)
			d.launched = true
		end
	elseif m.groundBounce and not d.bounced then
		if airborne then
			-- Spiked toward the floor, bounces back up on landing.
			d.vy = math.min(m.launch, -c.SpikeVelocity)
			d.pendingBounce = true
		else
			d.vy, d.bounced = c.GroundBounceVelocity, true
			event.bounce = true
		end
		d.launched = true
	elseif m.launch > 0 then
		d.vy = m.launch
		d.launched = true
	elseif m.launch < 0 then
		if airborne then
			d.vy = m.launch
			d.launched = true
		end
	elseif airborne then
		d.vy = math.max(d.vy, c.JugglePop)
		d.launched = true
	elseif m.crumple and not d.crumpled then
		d.stun, d.stunKind, d.crumpled = c.CrumpleTicks, "Crumple", true
		event.crumple = true
	end
	if final and m.wallBounce and not d.wallBounced and d.launched then
		d.wallBounce = true
	end
	applyPush(a, d, if final then m.push else (m.multiPush or 1), c, source)
	if not source then a.hitstop = stop end
	d.hitstop = stop
	event.kind, event.damage, event.combo, event.comboDamage = "Hit", damage, d.comboHits, d.comboDamage
	event.final = final
	if d.hp <= 0 then
		d.state = "KO"
		d.stun, d.stunKind, d.launched, d.pendingBounce, d.wallBounce = 0, nil, false, false, false
		d.vy = math.max(d.vy, c.KOPop)
		d.pushVx *= 1.6
		if not source then a.hitstop = c.KOHitstop end
		d.hitstop = c.KOHitstop
		event.ko = true
	elseif m.kind == "Ultimate" and not source then
		a.hitstop, d.hitstop = 0, 0
		startCinematic(world, a, d, events, m.id)
	end
	table.insert(events, event)
end

-- Ki blasts: swept against the opponent's hurtbox each tick, clash with enemy blasts.
local function stepProjectiles(world, events)
	local c = world.config
	local dt = 1 / c.TickRate
	local list = world.projectiles
	for _, p in list do
		p.oldX = p.x
		p.x += p.vx * dt
		p.life -= 1
	end
	local function span(p)
		return math.min(p.oldX, p.x) - p.data.halfWidth, math.max(p.oldX, p.x) + p.data.halfWidth
	end
	for i = 1, #list do
		for j = i + 1, #list do
			local a, b = list[i], list[j]
			if a.owner ~= b.owner and not a.dead and not b.dead then
				local a1, a2 = span(a)
				local b1, b2 = span(b)
				if a1 <= b2 and b1 <= a2 and math.abs(a.y - b.y) < a.data.halfHeight + b.data.halfHeight then
					a.dead, b.dead = true, true
					table.insert(events, { kind = "Clash", x = (a.x + b.x) / 2, y = a.y })
				end
			end
		end
	end
	for _, p in list do
		local d = world.fighters[3 - p.owner]
		if not p.dead and not isInvulnerable(d, c, world.moves) then
			local x1, x2 = span(p)
			local dx1, dx2, dy1, dy2 = CombatSimulation.hurtbox(d, c)
			local h = p.data.halfHeight
			if x1 <= dx2 and dx1 <= x2 and p.y - h <= dy2 and dy1 <= p.y + h then
				p.dead = true
				applyHit(world, world.fighters[p.owner], d, p.data, events,
					{ x = p.x, y = p.y, dir = math.sign(p.vx) })
			end
		end
	end
	for i = #list, 1, -1 do
		local p = list[i]
		if p.dead or p.life <= 0 or p.x < c.ArenaMinX - 4 or p.x > c.ArenaMaxX + 4 then
			table.remove(list, i)
		end
	end
end

local function detectHits(world, events)
	local a, b = world.fighters[1], world.fighters[2]
	local c, moves = world.config, world.moves
	local pending = {}
	for _, pair in { { a, b }, { b, a } } do
		local attacker, defender = pair[1], pair[2]
		local m = hitboxActive(attacker, moves)
		if m and not isInvulnerable(defender, c, moves) then
			local hx1, hx2, hy1, hy2 = CombatSimulation.hitbox(attacker, m)
			local dx1, dx2, dy1, dy2 = CombatSimulation.hurtbox(defender, c)
			if hx1 <= dx2 and dx1 <= hx2 and hy1 <= dy2 and dy1 <= hy2 then
				table.insert(pending, { attacker, defender, m })
			end
		end
	end
	-- Both hits are decided before either applies, so simultaneous attacks trade.
	for _, hit in pending do
		if not world.cinematic then applyHit(world, hit[1], hit[2], hit[3], events) end
	end
end

-- The ultimate plays as a scripted, authoritative sequence: fixed hits, then a final blow.
-- Cinematics play as scripted, authoritative sequences: fixed hits, then a final blow.
-- Rhythm prompts: each one is judged once. Pressing early (spam) or the wrong button fails
-- it; missing the window fails it too. All succeeded: PARFAIT, one ki bar back.
local function judgePrompts(world, state, input, events)
	local cin = world.moveData.Cinematics[state.move]
	local prompt = state.prompts[state.nextPrompt]
	if not prompt then return end
	local pressed = if input.light then "Light" elseif input.heavy then "Heavy"
		elseif input.ultimate then "Ultimate" else nil
	local delta = state.tick - prompt.tick
	local result
	if pressed and delta >= -cin.PromptWindow then
		result = pressed == prompt.button and delta <= cin.PromptWindow
	elseif pressed then
		result = false -- far too early: mashing
	elseif delta > cin.PromptWindow then
		result = false -- missed
	end
	if result == nil then return end
	prompt.result = result
	if result then state.perfect += 1 end
	table.insert(events, { kind = "Prompt", attacker = state.attacker, index = state.nextPrompt, success = result })
	state.nextPrompt += 1
	if state.nextPrompt > #state.prompts then
		local all = state.perfect == #state.prompts
		state.grade = if all then "PARFAIT" elseif state.perfect >= #state.prompts - 1 then "GRAND" else "BON"
		if all and cin.PerfectRefund then gainMeter(world.fighters[state.attacker], cin.PerfectRefund, world.config) end
		if all and cin.PerfectBonus then
			-- Gate fully opened: the final blow hits harder.
			for _, step in state.plan do
				if step.final then step.damage += math.floor(world.config.MaxHealth * cin.PerfectBonus) end
			end
			local d = world.fighters[state.defender]
			local total = 0
			for _, step in state.plan do total += step.damage end
			if total >= d.hp then state.finish, state.length = true, cin.Length + cin.FinishExtra end
		end
		table.insert(events, { kind = "PromptGrade", attacker = state.attacker, grade = state.grade })
	end
end

local function stepCinematic(world, events, inputs)
	local c = world.config
	local state = world.cinematic
	state.tick += 1
	local a, d = world.fighters[state.attacker], world.fighters[state.defender]
	if #state.prompts > 0 then
		judgePrompts(world, state, inputs[state.attacker] or CombatSimulation.neutralInput(), events)
	end
	local dir = if d.x >= a.x then 1 else -1
	for _, step in state.plan do
		if step.tick == state.tick then
			local finishing = step.final and state.finish
			-- Only KAIEN RUSH's last blow or a FINAL FINISH can KO; ÉVEIL ÉCARLATE otherwise
			-- always leaves the target standing on its last 5 %.
			local canKO = step.final and state.move == "KaienRush"
			d.hp = if finishing then 0 else math.max(if canKO then 0 else 1, d.hp - step.damage)
			d.comboHits += 1
			d.comboDamage += step.damage
			if state.move == "KaienRush" then gainMeter(d, step.damage * c.MeterWhenHit, c) end
			table.insert(events, {
				kind = "Hit", attacker = a.slot, defender = d.slot, move = state.move, cinematic = true,
				heavy = step.final == true, ko = d.hp <= 0, damage = step.damage, combo = d.comboHits,
				comboDamage = d.comboDamage, x = d.x - dir * 0.6, y = d.y + 3.4, finish = finishing,
			})
			if step.final then
				d.stun, d.stunKind = 0, nil
				if d.hp <= 0 then
					-- FINAL FINISH: the target is thrown down and stays on the floor.
					d.state, d.launched = "KO", false
					d.vy, d.pushVx = c.KOPop * 0.6, dir * 14
				else
					d.launched, d.juggle = true, c.MaxJuggleHits -- untouchable until it lands
					d.vy, d.pushVx = c.UltimateLaunch, dir * c.UltimatePush
				end
			end
		end
	end
	if state.tick > state.finalTick then
		stepFighter(world, d, CombatSimulation.neutralInput(), events)
	end
	if state.tick >= state.length then
		world.cinematic = nil
		a.move, a.moveContact, a.state = nil, nil, "Idle"
		a.awakenStyle = nil
		table.insert(events, { kind = "CinematicEnd", attacker = a.slot, defender = d.slot, finish = state.finish })
	end
end

local function endRound(world, events, reason)
	local c = world.config
	local a, b = world.fighters[1], world.fighters[2]
	local winner
	if reason == "KO" then
		winner = if a.hp <= 0 and b.hp <= 0 then 0 elseif a.hp <= 0 then 2 else 1
	else
		winner = if a.hp > b.hp then 1 elseif b.hp > a.hp then 2 else 0
	end
	world.winner, world.reason = winner, reason
	if not world.training then
		-- A draw (double KO or equal health at timeout) gives both fighters the round.
		if winner == 0 or winner == 1 then a.wins += 1 end
		if winner == 0 or winner == 2 then b.wins += 1 end
	end
	world.phase, world.phaseTicks = "KO", c.KOTicks
	table.insert(events, { kind = "RoundEnd", winner = winner, reason = reason,
		perfect = winner ~= 0 and world.fighters[winner].hp == c.MaxHealth })
end

local function advancePhase(world, events)
	local c = world.config
	if world.phase == "Intro" then
		world.phaseTicks -= 1
		if world.phaseTicks <= 0 then
			world.phase = "Fight"
			table.insert(events, { kind = "Fight" })
		end
	elseif world.phase == "Fight" then
		if world.cinematic then return end -- the round ends only once the cinematic is over
		local a, b = world.fighters[1], world.fighters[2]
		if a.hp <= 0 or b.hp <= 0 then
			endRound(world, events, "KO")
		elseif not world.training then
			world.timerTicks = math.max(0, world.timerTicks - 1)
			if world.timerTicks == 0 then endRound(world, events, "Timeout") end
		end
	elseif world.phase == "KO" then
		world.phaseTicks -= 1
		if world.phaseTicks > 0 then return end
		local a, b = world.fighters[1], world.fighters[2]
		if world.training then
			resetFighters(world)
			world.phase = "Fight"
			table.insert(events, { kind = "Reset" })
		elseif a.wins >= c.RoundsToWin or b.wins >= c.RoundsToWin then
			world.matchWinner = if a.wins >= c.RoundsToWin and b.wins >= c.RoundsToWin then 0
				elseif a.wins >= c.RoundsToWin then 1 else 2
			world.phase, world.phaseTicks = "MatchEnd", c.MatchEndTicks
			table.insert(events, { kind = "MatchEnd", winner = world.matchWinner })
		else
			world.round += 1
			resetFighters(world)
			world.phase, world.phaseTicks = "Intro", c.IntroTicks
			table.insert(events, { kind = "Round", round = world.round })
		end
	elseif world.phase == "MatchEnd" then
		world.phaseTicks -= 1
		if world.phaseTicks <= 0 then
			CombatSimulation.resetMatch(world, world.training)
			table.insert(events, { kind = "Round", round = 1 })
		end
	end
end

local function trainingRefill(world)
	local c = world.config
	for _, f in world.fighters do
		local calm = f.comboHits == 0 and f.stun == 0 and not f.launched and f.knockdown == 0
			and f.state ~= "KO" and not f.move
		f.calmTicks = if calm then f.calmTicks + 1 else 0
		if f.calmTicks >= c.TrainingRefillTicks then
			f.hp = c.MaxHealth
			f.meter = c.MaxMeter
		end
	end
end

local function collectBounceEvents(world, events)
	for _, f in world.fighters do
		if f.justBounced or f.justWallBounced then
			table.insert(events, { kind = if f.justWallBounced then "WallBounce" else "GroundBounce",
				defender = f.slot, x = f.x, y = f.y })
			f.justBounced, f.justWallBounced = false, false
		end
	end
end

-- inputs[slot] = { axis, crouch, jump, dash, block, light, heavy, special, ultimate }.
-- Returns a list of events.
function CombatSimulation.step(world, inputs)
	local events = {}
	world.tick += 1
	if world.cinematic then
		stepCinematic(world, events, inputs)
		collectBounceEvents(world, events)
		advancePhase(world, events)
		return events
	end
	local fighting = world.phase == "Fight"
	local neutral = CombatSimulation.neutralInput()
	local a, b = world.fighters[1], world.fighters[2]
	local previousDelta = b.x - a.x
	for slot, f in world.fighters do
		stepFighter(world, f, if fighting then inputs[slot] or neutral else neutral, events)
	end
	resolvePair(a, b, world.config, previousDelta)
	if fighting then
		detectHits(world, events)
		stepProjectiles(world, events)
		if world.training then trainingRefill(world) end
	end
	collectBounceEvents(world, events)
	advancePhase(world, events)
	return events
end

-- True when the fighter's next press would be a clean combo link right now
-- (shown by the combo trainer as "MAINTENANT !").
function CombatSimulation.cancelReady(world, f)
	if #f.buffer > 0 then return false end
	if f.grace then return true end
	local m = f.move and world.moves[f.move]
	return m ~= nil and f.moveContact ~= nil and f.moveHits >= (m.hits or 1)
end

-- Training lab: plays a cinematic directly, without performing its combo. The two fighters
-- are placed face to face; `hp` sets the target's health (low health = FINAL FINISH).
function CombatSimulation.debugCinematic(world, slot, moveId, style, hp)
	local events = {}
	if not world.moveData.Cinematics[moveId] then return events end
	local a, d = world.fighters[slot], world.fighters[3 - slot]
	world.cinematic, world.phase, world.projectiles = nil, "Fight", {}
	for _, f in { a, d } do
		f.y, f.vy, f.vx, f.pushVx = 0, 0, 0, 0
		f.move, f.moveContact, f.stun, f.stunKind, f.launched = nil, nil, 0, nil, false
		f.knockdown, f.getUp, f.hitstop, f.buffer, f.grace = 0, 0, 0, {}, nil
		if f.state == "KO" then f.state = "Idle" end
	end
	local center = math.clamp((a.x + d.x) / 2, world.config.ArenaMinX + 4, world.config.ArenaMaxX - 4)
	a.x, d.x, a.facing, d.facing = center - 1.3, center + 1.3, 1, -1
	d.hp = math.clamp(hp or world.config.MaxHealth, 1, world.config.MaxHealth)
	a.awakenStyle = style
	table.insert(events, { kind = "SuperFlash", attacker = slot, move = moveId })
	startCinematic(world, a, d, events, moveId)
	return events
end

function CombatSimulation.timerSeconds(world)
	if world.training then return -1 end
	return math.ceil(world.timerTicks / world.config.TickRate)
end

return CombatSimulation
