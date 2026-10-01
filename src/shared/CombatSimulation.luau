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
end

function CombatSimulation.newWorld(config, moveData, training)
	local world = {
		config = config,
		moveData = moveData,
		moves = moveData.Moves,
		fighters = {},
		epoch = 0,
		tick = 0,
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

local function startMove(world, f, id, events)
	local m = world.moves[id]
	f.move, f.moveFrame, f.moveContact = id, 1, nil
	table.remove(f.buffer, 1)
	if m.air then f.airAttackUsed = true end
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

local function chooseMove(world, f, grounded, crouching)
	local head = f.buffer[1]
	if not head then return nil end
	local moves, starters, button = world.moves, world.moveData.Starters, head.button
	local nextId
	if f.move then
		local current = moves[f.move]
		if not f.moveContact or f.moveFrame <= current.startup then return nil end
		if button == "Special" and current.kind == "Normal" and not current.air then
			nextId = starters.Ground.Special
		elseif button == "Ultimate" and current.kind ~= "Ultimate" and not current.air then
			nextId = starters.Ground.Ultimate
		elseif current.cancels then
			nextId = current.cancels[button]
		end
	elseif f.dashTicks == 0 then
		if grounded then
			nextId = (if crouching then starters.Crouch else starters.Ground)[button]
		elseif not f.airAttackUsed then
			nextId = starters.Air[button]
		end
	end
	local m = nextId and moves[nextId]
	if m and m.meterCost and f.meter < m.meterCost then return nil end
	return nextId
end

local function stepFighter(world, f, input, events)
	local c, moves = world.config, world.moves
	-- Presses queue in the order typed, so mashing L L L R gives exactly that route.
	for _, field in BUTTON_ORDER do
		if input[field] then
			if #f.buffer >= c.BufferSize then table.remove(f.buffer, 1) end
			table.insert(f.buffer, { button = BUTTONS[field], ticks = c.BufferTicks })
		end
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
			f.move, f.moveContact = nil, nil
		end
	end
	local nextId = chooseMove(world, f, grounded, input.crouch)
	if nextId then startMove(world, f, nextId, events) end
	for i = #f.buffer, 1, -1 do
		local entry = f.buffer[i]
		entry.ticks -= 1
		if entry.ticks <= 0 then table.remove(f.buffer, i) end
	end

	if f.move then
		local m = moves[f.move]
		f.blocking, f.crouching = false, f.move == "LowKick"
		if grounded and not m.air then
			f.vx = if f.moveFrame <= m.startup + m.active then f.facing * m.lunge else 0
		end
		f.state = "Attack"
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
	if not f.move or f.frozen or f.moveContact then return nil end
	local m = moves[f.move]
	if f.moveFrame > m.startup and f.moveFrame <= m.startup + m.active then return m end
	return nil
end

local function canBlock(d, a, m)
	if not isGrounded(d) or d.move then return false end
	local guarding = d.blocking or (d.stunKind == "Block" and d.holdBlock)
	if not guarding then return false end
	local side = math.sign(a.x - d.x)
	if side ~= 0 and side ~= d.facing then return false end -- attacked from behind
	local crouching = d.holdCrouch
	if m.guard == "High" and crouching then return false end
	if m.guard == "Low" and not crouching then return false end
	return true
end

local function applyPush(a, d, speed, c)
	local dir = if d.x > a.x then 1 elseif d.x < a.x then -1 else a.facing
	local cornered = (dir > 0 and d.x >= c.ArenaMaxX - c.CornerMargin)
		or (dir < 0 and d.x <= c.ArenaMinX + c.CornerMargin)
	if cornered and not d.wallBounce then
		a.pushVx = -dir * speed * c.CornerPushRatio
	else
		d.pushVx = dir * speed
	end
end

local function comboScale(d, c, minimum)
	return math.max(minimum or c.MinComboScaling, c.ComboScaling ^ d.comboHits)
end

local function startCinematic(world, a, d, events)
	local cin = world.moveData.Cinematic
	world.cinematic = {
		attacker = a.slot, defender = d.slot, tick = 0, length = cin.Length,
		scale = comboScale(d, world.config, cin.MinScaling),
	}
	a.move, a.moveContact, a.state = "KaienRush", "Hit", "Cinematic"
	a.pushVx, d.pushVx, a.vx = 0, 0, 0
	d.stun, d.stunKind, d.state = 999, "Hit", "Hitstun"
	table.insert(events, { kind = "CinematicStart", attacker = a.slot, defender = d.slot, move = "KaienRush" })
end

local function applyHit(world, a, d, m, events)
	local c = world.config
	local hx1, hx2, hy1, hy2 = CombatSimulation.hitbox(a, m)
	local dx1, dx2, dy1, dy2 = CombatSimulation.hurtbox(d, c)
	local event = {
		attacker = a.slot, defender = d.slot, move = m.id, heavy = m.heavy == true,
		x = (math.max(hx1, dx1) + math.min(hx2, dx2)) / 2,
		y = (math.max(hy1, dy1) + math.min(hy2, dy2)) / 2,
	}
	if canBlock(d, a, m) then
		a.moveContact = "Block"
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
		applyPush(a, d, m.blockPush, c)
		local stop = math.max(3, m.hitstop - 2)
		a.hitstop, d.hitstop = stop, stop
		table.insert(events, event)
		return
	end

	a.moveContact = "Hit"
	local damage = math.max(1, math.floor(m.damage * comboScale(d, c) + 0.5))
	d.hp = math.max(0, d.hp - damage)
	d.comboHits += 1
	d.comboDamage += damage
	if m.kind ~= "Ultimate" then gainMeter(a, damage * c.MeterOnHit, c) end
	gainMeter(d, damage * c.MeterWhenHit, c)
	d.move, d.moveContact, d.dashTicks = nil, nil, 0
	d.blocking, d.crouching = false, false
	d.stun, d.stunKind = m.hitstun, "Hit"
	d.calmTicks = 0
	local airborne = not isGrounded(d) or d.launched
	if m.groundBounce and not d.bounced then
		if airborne then
			-- Spiked toward the floor, bounces back up on landing.
			d.vy = math.min(m.launch, -c.SpikeVelocity)
			d.pendingBounce = true
		else
			d.vy, d.bounced = c.GroundBounceVelocity, true
			event.bounce = true
		end
		d.launched = true
		d.juggle += 1
	elseif m.launch > 0 then
		d.vy = m.launch
		d.launched = true
		d.juggle += 1
	elseif m.launch < 0 then
		if airborne then
			d.vy = m.launch
			d.launched = true
			d.juggle += 1
		end
	elseif airborne then
		d.vy = math.max(d.vy, c.JugglePop)
		d.launched = true
		d.juggle += 1
	elseif m.crumple and not d.crumpled then
		d.stun, d.stunKind, d.crumpled = c.CrumpleTicks, "Crumple", true
		event.crumple = true
	end
	if m.wallBounce and not d.wallBounced and d.launched then
		d.wallBounce = true
	end
	applyPush(a, d, m.push, c)
	a.hitstop, d.hitstop = m.hitstop, m.hitstop
	event.kind, event.damage, event.combo, event.comboDamage = "Hit", damage, d.comboHits, d.comboDamage
	if d.hp <= 0 then
		d.state = "KO"
		d.stun, d.stunKind, d.launched, d.pendingBounce, d.wallBounce = 0, nil, false, false, false
		d.vy = math.max(d.vy, c.KOPop)
		d.pushVx *= 1.6
		a.hitstop, d.hitstop = c.KOHitstop, c.KOHitstop
		event.ko = true
	elseif m.kind == "Ultimate" then
		a.hitstop, d.hitstop = 0, 0
		startCinematic(world, a, d, events)
	end
	table.insert(events, event)
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
local function stepCinematic(world, events)
	local c, cin = world.config, world.moveData.Cinematic
	local state = world.cinematic
	state.tick += 1
	local a, d = world.fighters[state.attacker], world.fighters[state.defender]
	local dir = if d.x >= a.x then 1 else -1
	local function hit(amount, final)
		local damage = math.max(1, math.floor(amount * state.scale + 0.5))
		d.hp = if final then math.max(0, d.hp - damage) else math.max(1, d.hp - damage)
		d.comboHits += 1
		d.comboDamage += damage
		gainMeter(d, damage * c.MeterWhenHit, c)
		table.insert(events, {
			kind = "Hit", attacker = a.slot, defender = d.slot, move = "KaienRush", cinematic = true,
			heavy = final, ko = final and d.hp <= 0, damage = damage, combo = d.comboHits, comboDamage = d.comboDamage,
			x = d.x - dir * 0.6, y = d.y + 3.4,
		})
	end
	if table.find(cin.Hits, state.tick) then hit(cin.HitDamage, false) end
	if state.tick == cin.FinalTick then
		hit(cin.FinalDamage, true)
		d.stun, d.stunKind = 0, nil
		d.launched, d.juggle = true, c.MaxJuggleHits -- untouchable until it lands
		d.vy, d.pushVx = c.UltimateLaunch, dir * c.UltimatePush
		if d.hp <= 0 then
			d.state, d.launched = "KO", false
		end
	end
	if state.tick > cin.FinalTick then
		stepFighter(world, d, CombatSimulation.neutralInput(), events)
	end
	if state.tick >= state.length then
		world.cinematic = nil
		a.move, a.moveContact, a.state = nil, nil, "Idle"
		table.insert(events, { kind = "CinematicEnd", attacker = a.slot, defender = d.slot })
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
		stepCinematic(world, events)
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
		if world.training then trainingRefill(world) end
	end
	collectBounceEvents(world, events)
	advancePhase(world, events)
	return events
end

function CombatSimulation.timerSeconds(world)
	if world.training then return -1 end
	return math.ceil(world.timerTicks / world.config.TickRate)
end

return CombatSimulation
