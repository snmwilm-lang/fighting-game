--[[
	Authoritative fighting simulation: movement, attacks, guard, combos, ki meter, ultimate
	cinematic and rounds. Pure Luau with no Roblox API and no require, so the same file runs
	on the server and in offline tests. The server passes CombatConfig and MoveData to newWorld.

	One call to step() advances exactly one 60 Hz tick and returns presentation events
	(hits, blocks, KO, announcements). Events never feed back into the simulation.
]]

local CombatSimulation = {}

local BUTTONS = { light = "Light", heavy = "Heavy", special = "Special", ultimate = "Ultimate", fatal = "Fatal" }
local BUTTON_ORDER = { "light", "heavy", "special", "ultimate", "fatal" }
local KEY_LETTER = { Light = "L", Heavy = "R", Special = "E", Ultimate = "U", Fatal = "C" }

local function newFighter(slot, c, kit, stanceId)
	local facing = if slot == 1 then 1 else -1
	-- Kits with stances (TARO: CLASSIQUE / ESQUIVE) take the stance's stats.
	local stance = kit.Stances and (kit.Stances[stanceId] or kit.Stances[kit.Stances.Order[1]])
	local stats = if stance then stance.Stats else kit.Stats
	return {
		slot = slot,
		kit = kit.Name, stats = stats, maxHp = stats.MaxHealth,
		stance = stance and stance.Id, stanceCooldown = 0,
		evadeCharge = 0, evadeInvuln = 0, dashInvuln = 0, -- passive VOILE D'OMBRE, dash that slips through
		evadeCharges = kit.Passive and kit.Passive.Charges or 0, evadeCounter = 0, evadeFrom = nil,
		-- Boxer (kit.Weave, TARO): forward dash = weave under high attacks, then DEMPSEY ROLL.
		weaveTicks = 0, dempseyWindow = 0, dempseyCount = 0, slipSerial = -1, teleportReady = 0,
		slipCharges = 3, slipCharge = 0, -- boxer's slips ready (see Weave.Charges) and the refill timer
		latencyTicks = 0, -- one-way network latency of the player (set by the server), for fairness
		rage = 0, -- RYUKEN's RAGE stacks (passive "Rage")
		x = if slot == 1 then -c.SpawnX else c.SpawnX,
		y = 0, vx = 0, vy = 0, pushVx = 0,
		facing = facing,
		state = "Idle",
		dashTicks = 0, dashCooldown = 0, dashDirection = facing,
		hp = stats.MaxHealth, guard = c.MaxGuard, guardRegenDelay = 0, meter = 0,
		move = nil, moveFrame = 0, moveContact = nil, airAttackUsed = false,
		moveHits = 0, lastHitFrame = 0, projectileSpawned = false,
		chainKeys = "", chainClean = false, awakenStyle = nil, dirtyReason = nil,
		moveSerial = 0, -- counts the moves started, so a press knows which attack it followed
		grace = nil, -- { move, ticks, serial }: late presses still link after the move ended
		stun = 0, stunKind = nil, launched = false, juggle = 0,
		pendingBounce = false, bounced = false, wallBounce = false, wallBounced = false, crumpled = false,
		knockdown = 0, getUp = 0, wakeInvuln = 0, -- wakeInvuln: untouchable just after getting up
		hitstop = 0, frozen = false,
		comboHits = 0, comboDamage = 0, calmTicks = 0,
		buffer = {}, -- queued presses { button, ticks }, oldest first
		blocking = false, crouching = false, holdBlock = false, holdCrouch = false,
		guardWindow = 0, -- ticks left to strike out of the guard (fast light attack)
		wins = 0,
	}
end

local function resetFighters(world)
	for slot = 1, 2 do
		local old = world.fighters[slot]
		-- The chosen stance stays from one round to the next (same kit).
		local stance = old and old.kit == world.kits[slot] and old.stance or nil
		world.fighters[slot] = newFighter(slot, world.config, world.moveData.Kits[world.kits[slot]], stance)
		if old then
			world.fighters[slot].wins = old.wins
			world.fighters[slot].meter = old.meter -- ki carries over between rounds
			world.fighters[slot].latencyTicks = old.latencyTicks
			world.fighters[slot].fatalUsed = old.fatalUsed -- the COUP FATAL is once per match
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
		kits = { "KAI", "KAI" },
	}
	CombatSimulation.resetMatch(world, training)
	return world
end

-- Chooses each slot's kit (MoveData.Kits) and starts a fresh match with their stats.
function CombatSimulation.setKits(world, kit1, kit2)
	local kits = world.moveData.Kits
	world.kits = { if kits[kit1] then kit1 else "KAI", if kits[kit2] then kit2 else "KAI" }
	CombatSimulation.resetMatch(world, world.training)
end

local function kitOf(world, f)
	return world.moveData.Kits[f.kit]
end
CombatSimulation.kitOf = kitOf

-- The fighter's stance (TARO: CLASSIQUE / ESQUIVE), nil for a kit without stances; its
-- starters (crouch special) and its weave (ESQUIVE only).
local function stanceOf(world, f)
	local kit = kitOf(world, f)
	return kit.Stances and kit.Stances[f.stance]
end
CombatSimulation.stanceOf = stanceOf
local function startersOf(world, f)
	local stance = stanceOf(world, f)
	return if stance then stance.Starters else kitOf(world, f).Starters
end
local function weaveOf(world, f)
	local stance = stanceOf(world, f)
	if stance then return stance.Weave end
	return kitOf(world, f).Weave
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
		light = false, heavy = false, special = false, ultimate = false, fatal = false,
		stance = 0, -- 1, 2...: switch to the kit's stance of that rank (TARO only)
	}
end

local function isGrounded(f)
	return f.y <= 0 and f.vy <= 0
end

local function isInvulnerable(f, c, moves)
	if f.state == "KO" or f.knockdown > 0 or f.getUp > 0 or (f.launched and f.juggle >= c.MaxJuggleHits)
		or f.evadeInvuln > 0 or f.dashInvuln > 0 or f.wakeInvuln > 0 then
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
		-- Rhythm: the press must come once the attack it continues is out (active frames,
		-- hit, recovery or the late window). Typed earlier, the combo goes on but is not clean.
		local current = if f.move then f.moveSerial elseif f.grace then f.grace.serial else nil
		if entry and entry.after ~= current then
			f.chainClean, f.dirtyReason = false, "TROP TÔT"
		end
	else
		f.chainKeys, f.chainClean = letter, not f.dirtyStart
		f.dirtyReason = if f.dirtyStart then "SPAM" else nil
		f.dirtyStart = false
	end
	f.moveSerial += 1
	if m.teleport then
		-- DAICHA's TÉLÉPORTATION: reappears `teleport` studs behind the opponent, facing them.
		local foe = world.fighters[3 - f.slot]
		local side = if foe.x >= f.x then 1 else -1
		local c = world.config
		f.x = math.clamp(foe.x + side * m.teleport, c.ArenaMinX + 0.5, c.ArenaMaxX - 0.5)
		if f.x == foe.x then f.x = foe.x - side * m.teleport end
		f.facing = if foe.x >= f.x then 1 else -1
		f.vx, f.dashTicks, f.crossed = 0, 0, true
		f.teleportReady = world.tick + (m.teleportCooldown or 0)
		table.insert(events, { kind = "Blink", slot = f.slot, x = f.x, move = id })
	end
	if m.dempsey then
		-- DEMPSEY ROLL: each hook continues the roll (counted for its limit), from the weave.
		f.dempseyCount = if isLink and f.dempseyCount > 0 then f.dempseyCount + 1 else 1
		f.dashTicks, f.dempseyWindow, f.weaveTicks = 0, 0, 0
	else
		f.dempseyCount = 0
	end
	f.move, f.moveFrame, f.moveContact = id, 1, nil
	f.moveHits, f.lastHitFrame, f.projectileSpawned = 0, 0, false
	f.wakeInvuln = 0 -- (the wake-up invincibility is for getting out, not for attacking)
	local fast = world.config.GuardCancelStartup
	if fast and not isLink and f.guardWindow > 0 and (m.kind or "Normal") == "Normal" and not m.air
		and m == world.moves[startersOf(world, f).Ground.Light] and m.startup > fast then
		-- Out of the guard: the jab skips part of its wind-up.
		f.moveFrame = m.startup - fast + 1
		f.guardWindow = 0
		table.insert(events, { kind = "GuardRelease", slot = f.slot })
	end
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
	if m.fatal then f.fatalUsed = true end -- (spent even if it misses: once per match)
	if m.meterCost then
		f.meter -= m.meterCost
		-- Super flash: everyone freezes while the ultimate is announced.
		local flash = world.config.SuperFlashTicks
		for _, other in world.fighters do
			other.hitstop = math.max(other.hitstop, flash)
		end
		f.hitstop = flash
		-- Cancelled from a combo on a reeling target: the target stays frozen through the
		-- wind-up too, so a launched or pushed-away target cannot fly out of reach and the
		-- ultimate connects (raw, it can still be guarded or avoided).
		local foe = world.fighters[3 - f.slot]
		if isLink and foe and foe.state ~= "KO"
			and ((foe.stun > 0 and (foe.stunKind == "Hit" or foe.stunKind == "Crumple")) or foe.launched) then
			foe.hitstop = math.max(foe.hitstop, flash + m.startup + 1)
		end
		table.insert(events, { kind = "SuperFlash", attacker = f.slot, move = id })
	end
end

-- COUP FATAL: 3 bars (the whole gauge), one's own health under FatalHealth, not used yet this
-- match.
function CombatSimulation.fatalReady(world, f)
	local id = kitOf(world, f).Ultimates.Fatal
	local m = id and world.moves[id]
	if m == nil or f.meter < m.meterCost or f.hp <= 0 then return false end
	-- (in training or with ULTIMES ON it is always there to practise)
	if world.training or world.ultimateConditions == f.slot then return true end
	return not f.fatalUsed and f.hp <= f.maxHp * (world.config.FatalHealth or 0.3)
end

-- Name of the full route whose first five links this combo matches, if it was played cleanly.
function CombatSimulation.awakeningStyle(world, f, currentId)
	if not f.chainClean or #f.chainKeys ~= 5 then return nil end
	for _, route in kitOf(world, f).FullRoutes do
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
	local kit = kitOf(world, f)
	local moves, starters, button, ultimates = world.moves, startersOf(world, f), head.button, kit.Ultimates
	local nextId
	local currentId = f.move or (f.grace and f.grace.move)
	if button == "Fatal" then
		-- COUP FATAL: from a combo (the target reeling from a hit: full power) or raw.
		local id = ultimates.Fatal
		if not CombatSimulation.fatalReady(world, f) or not grounded then return nil end
		local current = f.move and moves[f.move]
		if current then
			if current.kind == "Ultimate" or current.air or not f.moveContact or f.moveFrame <= current.startup then return nil end
		elseif f.dashTicks > 0 then
			return nil
		end
		local foe = world.fighters[3 - f.slot]
		f.fatalCombo = foe ~= nil and ((foe.stun > 0 and (foe.stunKind == "Hit" or foe.stunKind == "Crumple")) or foe.launched)
		return id, current ~= nil
	end
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
			if style and f.meter >= moves[ultimates.Gate].meterCost then
				nextId = ultimates.Gate
				f.awakenStyle = style
			end
		elseif current.cancels then
			nextId = current.cancels[button]
			-- Second ultimate, ÉVEIL ÉCARLATE: the same clean route ending on the right click.
			if nextId == ultimates.Finale then
				local style = CombatSimulation.awakeningStyle(world, f, currentId)
				if style and f.meter >= moves[ultimates.Awaken].meterCost then
					nextId = ultimates.Awaken
					f.awakenStyle = style
				end
			end
		end
	end
	if not nextId and f.move and f.moveContact and not head.judged then
		-- The cancel window is open and this button continues nothing: wrong button.
		head.judged = true
		f.chainClean, f.dirtyReason = false, "MAUVAIS BOUTON"
	end
	local weave = weaveOf(world, f)
	if weave and nextId and moves[nextId].dempsey and not moves[nextId].finisher and f.dempseyCount >= weave.MaxHooks then
		nextId = nil -- the roll has its limit: only the finishing hook is left
	end
	if weave and not nextId and not f.move and f.dempseyWindow > 0 and grounded and not crouching then
		-- Out of the weave (forward dash) or right after it: L starts the DEMPSEY ROLL, R its
		-- finishing hook.
		nextId = if button == "Light" then weave.Hook elseif button == "Heavy" then weave.Finish else nil
		if nextId then currentId = nil end
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
	if m and m.teleportRange then
		-- (DAICHA's TÉLÉPORTATION only reaches an opponent that close)
		local foe = world.fighters[3 - f.slot]
		if foe and math.abs(foe.x - f.x) > m.teleportRange then return nil end
		if world.tick < (f.teleportReady or 0) then return nil end -- still recovering from the last one
	end
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
	-- Changing your mind wins: guard, jump or dash drops the attacks still waiting in the
	-- queue (also when recovering from a hit while holding guard).
	if input.block or input.jump or input.dash then
		table.clear(f.buffer)
	end
	-- VOILE D'OMBRE's counter (AKEMI, like Ultra Instinct): L or R right after an evade, she
	-- reappears behind the attacker (still in its whiffed attack) and strikes.
	if f.evadeCounter > 0 and f.stunKind == "Evade" and f.hitstop == 0 and (input.light or input.heavy) then
		local a = world.fighters[f.evadeFrom or (3 - f.slot)]
		local passive = kitOf(world, f).Passive
		if a and a.state ~= "KO" and passive and f.meter >= (passive.CounterCost or 0) then
			f.meter -= passive.CounterCost or 0 -- like DBFZ's follow-ups, the counter costs ki
			local lo, hi = c.ArenaMinX + 0.5, c.ArenaMaxX - 0.5
			f.x = math.clamp(a.x - a.facing * (passive.CounterGap or 1.7), lo, hi)
			f.y, f.vy, f.vx, f.pushVx = 0, 0, 0, 0
			f.facing = if a.x >= f.x then 1 else -1
			f.stun, f.stunKind, f.state, f.evadeCounter = 0, nil, "Idle", 0
			f.crossed = true -- (she came out on the other side: the pushboxes keep her there)
			table.clear(f.buffer)
			local id = kitOf(world, f).Starters.Ground[if input.heavy then "Heavy" else "Light"]
			startMove(world, f, id, events, false)
			table.insert(events, { kind = "Blink", slot = f.slot, x = f.x, counter = true })
			return
		end
	end
	-- Spam = hitting every button: several buttons on the same tick, a press that overflows
	-- the queue, a wrong button or a press that is never used. A clean route also needs
	-- rhythm: each press once the previous attack is out (see startMove).
	local pressed = 0
	local current = f.move and moves[f.move]
	-- The attack this press may continue: the current move once its hitbox came out, or the
	-- move that just ended (late window). Nil while the current move is still winding up.
	local after = if current and f.moveFrame > current.startup then f.moveSerial
		elseif not f.move and f.grace then f.grace.serial else nil
	for _, field in BUTTON_ORDER do
		if input[field] and (not locked or remaining <= c.ReversalBufferTicks) then
			pressed += 1
			if #f.buffer >= c.BufferSize then
				table.remove(f.buffer, 1)
				f.chainClean, f.dirtyReason = false, "SPAM"
			end
			table.insert(f.buffer, { button = BUTTONS[field], ticks = c.BufferTicks, after = after })
		end
	end
	if pressed > 1 then
		f.chainClean, f.dirtyReason = false, "SPAM"
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
	-- Guard release: a light attack started while guarding or just after a blocked hit comes
	-- out faster (GuardCancelStartup): blocking gives the turn back.
	if f.blocking or (f.stunKind == "Block" and f.stun > 0) then
		f.guardWindow = c.GuardCancelTicks or 0
	else
		f.guardWindow = math.max(0, f.guardWindow - 1)
	end
	-- VOILE D'OMBRE: the charges come back one after the other.
	local evadePassive = kitOf(world, f).Passive
	if evadePassive and evadePassive.Type == "Evade" and f.evadeCharges < (evadePassive.Charges or 1) then
		f.evadeCharge = math.max(0, f.evadeCharge - 1)
		if f.evadeCharge == 0 then
			f.evadeCharges += 1
			if f.evadeCharges < (evadePassive.Charges or 1) then f.evadeCharge = evadePassive.Cooldown end
		end
	end
	-- Boxer's slips (TARO, ESQUIVE): up to Weave.Charges, back one after the other.
	local slipWeave = weaveOf(world, f)
	if slipWeave and slipWeave.Charges then
		f.slipCharges = math.min(f.slipCharges, slipWeave.Charges)
		if f.slipCharges < slipWeave.Charges then
			f.slipCharge = math.max(0, f.slipCharge - 1)
			if f.slipCharge == 0 then
				f.slipCharges += 1
				if f.slipCharges < slipWeave.Charges then f.slipCharge = slipWeave.Cooldown end
			end
		end
	end
	f.evadeCounter = math.max(0, f.evadeCounter - 1)
	f.evadeInvuln = math.max(0, f.evadeInvuln - 1)
	f.dashInvuln = math.max(0, f.dashInvuln - 1)
	if f.getUp == 0 then f.wakeInvuln = math.max(0, f.wakeInvuln - 1) end
	f.weaveTicks = math.max(0, f.weaveTicks - 1)
	f.stanceCooldown = math.max(0, f.stanceCooldown - 1)
	f.dempseyWindow = math.max(0, f.dempseyWindow - 1)
	local stats = f.stats
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
		-- Back on its feet: a moment untouchable, so a waiting attack cannot glue it into a new
		-- combo the very first frame (it may guard, move or jump; attacking ends it).
		if f.getUp == 0 then f.wakeInvuln = c.WakeInvulnTicks or 0 end
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
			elseif f.stunKind == "Evade" then "Evading"
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

	-- Stance switch (TARO: 1 / & = CLASSIQUE, 2 / é = ESQUIVE): in neutral, on the ground,
	-- not during an attack, then a short cooldown.
	local stances = kitOf(world, f).Stances
	local wanted = stances and (input.stance or 0) > 0 and stances.Order[input.stance]
	if wanted and wanted ~= f.stance and not f.move and f.stanceCooldown == 0 and grounded then
		f.stance = wanted
		f.stats = stances[wanted].Stats
		f.stanceCooldown = c.StanceCooldownTicks or 30
		f.dempseyWindow, f.weaveTicks, f.dempseyCount = 0, 0, 0
		stats = f.stats
		table.insert(events, { kind = "Stance", slot = f.slot, stance = wanted, name = stances[wanted].Name })
	end

	if f.move then
		local m = moves[f.move]
		f.moveFrame += 1
		if m.jumpCancel and f.moveContact == "Hit" and input.jump and grounded
			and f.moveFrame > m.startup + m.active then
			-- Super jump after a launcher to follow the target.
			f.move, f.moveContact = nil, nil
			f.vy = c.SuperJumpVelocity
			f.vx = input.axis * stats.AirSpeed
			f.airAttackUsed = false
			grounded = false
			table.insert(events, { kind = "SuperJump", attacker = f.slot })
		elseif f.moveFrame > world.moveData.total(m) then
			-- A move that connected keeps its cancels for a few more ticks (network latency).
			if f.moveContact and f.moveHits >= (m.hits or 1) then
				-- (longer for a far player: their press left before it reached the server)
				f.grace = { move = f.move, ticks = c.LateCancelTicks + math.min(f.latencyTicks or 0, c.MaxLatencyTicks or 12), serial = f.moveSerial }
			else
				-- A whiffed attack: presses made during it are forgotten, except a deliberate
				-- one in its last ticks (no surprise attack after changing your mind).
				for i = #f.buffer, 1, -1 do
					if c.BufferTicks - f.buffer[i].ticks >= c.ReversalBufferTicks then table.remove(f.buffer, i) end
				end
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
	-- Every press ages (BufferTicks), except while a connected attack is still hitting: a
	-- press made once the hit lands waits for the last hit. Typing a route far ahead loses
	-- presses, so combos need rhythm; hitstop freezes the count (see above).
	local ongoing = f.move and moves[f.move]
	local holding = ongoing and f.moveContact and f.moveFrame <= ongoing.startup + ongoing.active
	if not holding then
		for i = #f.buffer, 1, -1 do
			local entry = f.buffer[i]
			entry.ticks -= 1
			if entry.ticks <= 0 then
				table.remove(f.buffer, i)
				if f.move or f.grace then f.chainClean, f.dirtyReason = false, "APPUI PERDU" end
			end
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
			table.insert(events, { kind = "Projectile", attacker = f.slot, move = f.move })
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
		f.vy = stats.JumpVelocity
		grounded = false
		f.airAttackUsed = false
	end
	if input.dash and grounded and not crouched and not blocking and f.dashTicks == 0 and f.dashCooldown == 0 then
		f.dashDirection = if math.abs(input.axis) > 0.1 then math.sign(input.axis) else f.facing
		f.dashTicks = c.DashTicks
		f.dashInvuln = stats.DashInvuln or 0
		f.dashCooldown = c.DashCooldownTicks
		local weave = weaveOf(world, f)
		local foe = world.fighters[3 - f.slot]
		local passive = kitOf(world, f).Passive
		if passive and passive.Type == "Blink" and foe and f.dashDirection == (if foe.x >= f.x then 1 else -1)
			and math.abs(foe.x - f.x) <= passive.Range and foe.state ~= "KO" then
			-- DAICHA's OMBRE INVERSÉE: the dash blinks through to the other side of the opponent.
			local side = f.dashDirection
			local x = math.clamp(foe.x + side * passive.Gap, c.ArenaMinX + 0.5, c.ArenaMaxX - 0.5)
			if math.abs(x - foe.x) >= passive.Gap * 0.5 then
				f.x = x
				f.facing = -side -- facing the opponent; the dash ends a little further on
				f.dashTicks, f.dashInvuln, f.crossed = 2, passive.Invuln, true
				f.dashCooldown = passive.Cooldown
				table.insert(events, { kind = "Blink", slot = f.slot, x = f.x })
			end
		end
		if weave and foe and f.dashDirection == (if foe.x >= f.x then 1 else -1) then
			-- The boxer's forward dash is a weave: the head ducks under high attacks.
			f.weaveTicks = c.DashTicks + (weave.Duck or 0) -- (still ducking a moment after the dash)
			f.dempseyWindow = c.DashTicks + weave.Window
		end
	end
	f.crouching, f.blocking = crouched, blocking
	if f.dashTicks > 0 then
		f.vx = f.dashDirection * stats.DashSpeed
		f.dashTicks -= 1
		f.state = "Dashing"
	elseif blocking then
		f.vx = 0
		f.state = if crouched then "CrouchBlocking" else "Blocking"
	elseif crouched then
		f.vx = 0
		f.state = "Crouching"
	else
		f.vx = input.axis * (if grounded then stats.WalkSpeed else stats.AirSpeed)
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
	if cin.Type == "Fatal" then
		-- COUP FATAL: one blow, a share of the target's MAXIMUM health (much more from a combo).
		local total = math.floor(d.maxHp * (if a.fatalCombo then cin.ComboShare else cin.RawShare))
		finish = total >= d.hp and (not cin.FinishThreshold or d.hp < d.maxHp * cin.FinishThreshold)
		table.insert(plan, { tick = cin.FinalTick, damage = total, final = true })
	elseif cin.MaxHealthShare then
		-- A share of the target's MAXIMUM health, ignoring combo scaling (Gate, Awaken); the
		-- rhythm prompts can still take some off (MissShare), so it only KOs if what is left
		-- of it can take the remaining health (decided again once the prompts are judged).
		local total = math.floor(d.maxHp * cin.MaxHealthShare)
		finish = total >= d.hp
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
	if cin.Type == "Gate" or cin.Type == "Fatal" then
		for _, t in cin.PromptTicks do
			table.insert(prompts, { tick = t, button = cin.PromptButton or "Ultimate", result = nil })
		end
	elseif cin.Type == "Awaken" then
		local keys = "LRLR"
		for _, route in kitOf(world, a).FullRoutes do
			if route.name == style then keys = route.keys:gsub("%s", "") end
		end
		for i, t in cin.PromptTicks do
			local letter = keys:sub(i, i)
			table.insert(prompts, { tick = t, button = if letter == "R" then "Heavy" else "Light", result = nil })
		end
	end
	world.cinematic = {
		attacker = a.slot, defender = d.slot, move = moveId, type = cin.Type, tick = 0, finish = finish, style = style,
		length = cin.Length + (if finish then cin.FinishExtra else 0), finalTick = cin.FinalTick, plan = plan,
		prompts = prompts, nextPrompt = 1, perfect = 0, combo = if cin.Type == "Fatal" then a.fatalCombo == true else nil,
		startHp = d.hp, -- (a finish threshold looks at the health the target had when it began)
	}
	a.move, a.moveContact, a.state = moveId, "Hit", "Cinematic"
	a.pushVx, d.pushVx, a.vx = 0, 0, 0
	d.stun, d.stunKind, d.state = 999, "Hit", "Hitstun"
	-- Same line, on the ground, face to face: a combo often ends with the target in the air
	-- or far away, the ultimate always starts from a clean staging.
	local dir = if d.x > a.x then 1 elseif d.x < a.x then -1 else a.facing
	local gap, lo, hi = c.CinematicGap or 2.6, c.ArenaMinX + 0.5, c.ArenaMaxX - 0.5
	d.x = math.clamp(d.x, lo, hi)
	a.x = d.x - dir * gap
	if a.x < lo or a.x > hi then
		a.x = math.clamp(a.x, lo, hi)
		d.x = a.x + dir * gap
	end
	for _, f in { a, d } do
		f.y, f.vy, f.vx, f.dashTicks, f.weaveTicks, f.dempseyWindow = 0, 0, 0, 0, 0, 0
	end
	d.launched, d.knockdown, d.getUp, d.pendingBounce, d.crumpled = false, 0, 0, false, false
	a.facing, d.facing = dir, -dir
	table.insert(events, { kind = "CinematicStart", attacker = a.slot, defender = d.slot, move = moveId,
		finish = finish, style = style })
end

-- Applies one hit (or blocked hit) of move m from attacker a on defender d. `source` is set
-- for projectiles: { x, y, dir }; the attacker is then not frozen and not pushed.
-- TARO's PARADE: a standing attack (not a low, not an ultimate) that lands during the parry
-- window is cancelled; the counter punch starts at once and the attacker is stuck in the clash.
local function tryParry(world, a, d, m, events, source)
	local pm = d.move and world.moves[d.move]
	local parry = pm and pm.parry
	if not parry or d.moveFrame < parry.from or d.moveFrame > parry.to then return false end
	if (m.guard == "Low" and not parry.lows) or m.kind == "Ultimate" then return false end
	-- A wall (HIBECARES's MUR DE PIERRE) takes part of the blow: never a KO.
	local absorbed = if parry.absorb then math.floor((m.damage or 0) * parry.absorb + 0.5) else 0
	if absorbed > 0 then d.hp = math.max(1, d.hp - absorbed) end
	table.insert(events, { kind = "Parry", attacker = a.slot, defender = d.slot, move = m.id,
		x = d.x + d.facing * 1.1, y = d.y + 3.6, absorbed = if absorbed > 0 then absorbed else nil, name = pm.name })
	d.moveSerial += 1
	d.move, d.moveFrame, d.moveContact, d.moveHits, d.lastHitFrame = parry.counter, 1, nil, 0, 0
	d.hitstop = 6
	if not source then
		a.moveHits = m.hits or 1 -- the parried attack hits no more
		a.hitstop = math.max(a.hitstop, 22)
		a.pushVx = 0
	end
	return true
end

-- Passive VOILE D'OMBRE (AKEMI): from neutral (not attacking, not already hit, not
-- guarding), the next hit is evaded: the fighter slips back, invulnerable for a moment, and
-- the attack whiffs.
local function tryEvade(world, a, d, m, events, source)
	local passive = kitOf(world, d).Passive
	if not passive or passive.Type ~= "Evade" or d.evadeCharges <= 0 or m.kind == "Ultimate" then return false end
	-- Only from neutral: not in the middle of an own attack, not already hit or down.
	if d.move or d.stun > 0 or d.launched or d.knockdown > 0 or d.getUp > 0 or d.state == "KO" then return false end
	local sourceX = if source then source.x else a.x
	if canBlock(d, sourceX, m) then return false end -- a guarded hit stays a guarded hit
	local dir = if sourceX >= d.x then 1 else -1
	-- A slide back out of reach, untouchable, then a short recovery: neutral is reset, the
	-- evade never grants a free punish (and the whiffed attack stays punishable only by
	-- whoever was ready for it).
	d.pushVx = -dir * passive.Slide
	d.evadeCharges -= 1
	if d.evadeCharge <= 0 then d.evadeCharge = passive.Cooldown end
	d.evadeInvuln = passive.Invuln
	d.evadeCounter, d.evadeFrom = passive.CounterWindow or 0, a.slot
	d.stun, d.stunKind, d.vx = passive.Recovery, "Evade", 0
	d.grace, d.dashTicks, d.weaveTicks, d.dempseyWindow = nil, 0, 0, 0
	table.clear(d.buffer)
	if not source then a.moveHits = m.hits or 1 end -- the attack whiffs
	table.insert(events, { kind = "Evade", attacker = a.slot, defender = d.slot, move = m.id, x = d.x, y = d.y + 3 })
	return true
end

-- Damage passives of the attacker: RYUKEN's RAGE stacks, SHIN's PRÉCISION (the tip of the
-- blade), HIBECARES's ROI DES RUINES (the lower his health, the harder he hits). Returns the
-- multiplier and whether it was a tip hit.
local function passiveBonus(world, a, d, m, source)
	local passive = kitOf(world, a).Passive
	if not passive then return 1, false end
	if passive.Type == "Rage" then
		return 1 + a.rage * passive.PerStack, false
	elseif passive.Type == "Tip" and not source and m.hitbox then
		local reach = math.abs(d.x - a.x) - world.config.HurtHalfWidth
		if reach >= m.hitbox.far * passive.From then return 1 + passive.Bonus, true end
	elseif passive.Type == "Ruins" then
		local share = a.hp / a.maxHp
		local t = math.clamp((passive.From - share) / (passive.From - passive.To), 0, 1)
		return 1 + passive.MaxBonus * t, false
	end
	return 1, false
end

local function applyHit(world, a, d, m, events, source)
	local c = world.config
	if tryParry(world, a, d, m, events, source) or tryEvade(world, a, d, m, events, source) then return end
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
		-- Light pokes (jab, cross...) wear the guard less: mashing does not break it.
		local wear = if (m.kind or "Normal") == "Normal" and m.guardDamage <= 12 then c.LightGuardWear or 1 else 1
		d.guard -= m.guardDamage * wear * (d.stats.GuardDamageTaken or 1)
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
	local bonus, tip = passiveBonus(world, a, d, m, source)
	local damage = math.max(1, math.floor(m.damage * comboScale(d, c) * (a.stats.DamageDealt or 1) * bonus + 0.5))
	d.hp = math.max(0, d.hp - damage)
	event.tip = tip or nil
	-- RAGE: a hit landed adds a stack; being hit loses them all.
	local rage = kitOf(world, a).Passive
	if rage and rage.Type == "Rage" then a.rage = math.min(rage.Max, a.rage + 1) end
	-- VOILE D'OMBRE (AKEMI): each hit she lands brings her next evade closer.
	if rage and rage.Type == "Evade" and rage.HitRefund and a.evadeCharges < (rage.Charges or 1) then
		a.evadeCharge = math.max(1, a.evadeCharge - rage.HitRefund)
	end
	d.rage = 0
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
		-- One real launch per combo: a target already in the air is only kept up (a small
		-- pop), never thrown sky-high again.
		d.vy = if airborne and d.juggle > 1 then math.max(d.vy, math.min(m.launch, c.RelaunchVelocity or m.launch)) else m.launch
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
local slips -- (the boxer's slip, defined with detectHits below)
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
			if x1 <= dx2 and dx1 <= x2 and p.y - h <= dy2 and dy1 <= p.y + h
				and not slips(world, world.fighters[p.owner], d, p.data, events, "p" .. p.id) then
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

-- Boxer's slip (TARO): during the weave (forward dash) and the start of each DEMPSEY ROLL
-- hook, attacks that are not low whiff over the ducking head. Lows, projectiles and
-- ultimates still hit. The first slip of each attack gives a little ki.
function slips(world, a, d, m, events, serial)
	serial = serial or a.moveSerial
	if m.kind == "Ultimate" then return false end
	local weave = weaveOf(world, d)
	-- The counted slips (ESQUIVE) dodge everything but the ultimates, lows and projectiles
	-- included; the old uncounted weave only ducks under the high blows.
	if (m.guard == "Low" or serial ~= a.moveSerial) and not (weave and weave.Charges) then return false end
	local dm = d.move and world.moves[d.move]
	local ducking = d.weaveTicks > 0
		or (dm ~= nil and dm.slip ~= nil and d.moveFrame >= dm.slip.from and d.moveFrame <= dm.slip.to)
	if d.slipSerial == serial then return true end -- this attack was already slipped: it whiffs to the end
	if not ducking then return false end
	-- Like VOILE D'OMBRE, the slips are counted (Weave.Charges, refilled over time).
	if weave and weave.Charges then
		if d.slipCharges <= 0 then return false end
		d.slipCharges -= 1
		if d.slipCharge <= 0 then d.slipCharge = weave.Cooldown end
	end
	d.slipSerial = serial
	gainMeter(d, world.config.SlipMeter or 0, world.config)
	-- A short slow-down on both fighters (drawn in black and white by the client); the
	-- attacker, thrown off balance, stays frozen longer: the boxer always takes the lead
	-- (his DEMPSEY ROLL window opens again).
	local freeze = world.config.SlipFreezeTicks or 0
	a.hitstop = math.max(a.hitstop, freeze + (world.config.SlipAdvantageTicks or 0))
	d.hitstop = math.max(d.hitstop, freeze)
	if weave then d.dempseyWindow = math.max(d.dempseyWindow, weave.Window + (world.config.SlipAdvantageTicks or 0)) end
	table.insert(events, { kind = "Slip", attacker = a.slot, defender = d.slot, move = m.id, x = d.x, y = d.y + 3.4 })
	return true
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
			if hx1 <= dx2 and dx1 <= hx2 and hy1 <= dy2 and dy1 <= hy2 and not slips(world, attacker, defender, m, events) then
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
local function judgePrompts(world, state, input, events, force)
	local cin = world.moveData.Cinematics[state.move]
	local prompt = state.prompts[state.nextPrompt]
	if not prompt then return end
	local pressed = if input.light then "Light" elseif input.heavy then "Heavy"
		elseif input.ultimate then "Ultimate" elseif input.fatal then "Fatal" else nil
	-- Lag compensation (a far player): the press is judged at the cinematic tick the player
	-- saw when pressing (input.cinTick), never later than now and never further back than
	-- their round trip allows; a prompt is only "missed" once that much time has passed.
	local f = world.fighters[state.attacker]
	local latency = math.min(f.latencyTicks or 0, world.config.MaxLatencyTicks or 12)
	local reach = if latency > 0 then 2 * latency + 3 else 0
	local tick = state.tick
	local seen = input.cinTick
	if pressed and reach > 0 and type(seen) == "number" and seen <= tick and seen >= tick - reach then
		tick = seen
	end
	local delta = tick - prompt.tick
	local result
	if pressed and delta >= -cin.PromptWindow then
		result = pressed == prompt.button and delta <= cin.PromptWindow
	elseif pressed then
		result = false -- far too early: mashing
	elseif state.tick - prompt.tick > cin.PromptWindow + reach then
		result = false -- missed
	end
	if result == nil and force then result = false end -- (the blow lands now: too late)
	if result == nil then return end
	prompt.result = result
	if result then
		state.perfect += 1
	elseif cin.MissShare or cin.MissRatio then
		-- A missed prompt weakens the final blow (a share of the maximum health, or of the blow).
		local cut = 0
		for _, step in state.plan do
			if step.final then
				cut = if cin.MissShare then math.floor(world.fighters[state.defender].maxHp * cin.MissShare)
					else math.floor(step.damage * cin.MissRatio)
			end
		end
		for _, step in state.plan do
			if step.final then step.damage = math.max(1, step.damage - cut) end
		end
	end
	table.insert(events, { kind = "Prompt", attacker = state.attacker, index = state.nextPrompt, success = result })
	state.nextPrompt += 1
	if state.nextPrompt > #state.prompts then
		local all = state.perfect == #state.prompts
		state.grade = if all then "PARFAIT" elseif state.perfect >= #state.prompts - 1 then "GRAND" else "BON"
		if all and cin.PerfectRefund then gainMeter(world.fighters[state.attacker], cin.PerfectRefund, world.config) end
		if all and cin.PerfectBonus then
			-- Gate fully opened: the final blow hits harder.
			for _, step in state.plan do
				if step.final then step.damage += math.floor(world.fighters[state.defender].maxHp * cin.PerfectBonus) end
			end
		end
		if cin.MaxHealthShare or cin.Type == "Fatal" then
			-- KO only if the blows still to land can take the health that is left (the ones
			-- already dealt are in d.hp, they must not count twice).
			local d = world.fighters[state.defender]
			local remaining = 0
			for _, step in state.plan do
				if not step.done then remaining += step.damage end
			end
			state.finish = remaining >= d.hp
				and (not cin.FinishThreshold or (state.startHp or d.hp) < d.maxHp * cin.FinishThreshold)
			state.length = cin.Length + (if state.finish then cin.FinishExtra else 0)
		end
		table.insert(events, { kind = "PromptGrade", attacker = state.attacker, grade = state.grade })
	end
end

-- Slow motion of a cinematic at its current tick (share of real time).
function CombatSimulation.cinematicScale(world)
	local c, state = world.config, world.cinematic
	if not state then return 1 end
	local around = c.CinematicImpactTicks or { 0, 0 }
	local fromFinal = state.tick - state.finalTick
	if fromFinal >= around[1] and fromFinal <= around[2] then return c.CinematicImpactScale or 1 end
	return c.CinematicTimeScale or 1
end

local function stepCinematic(world, events, inputs)
	local c = world.config
	local state = world.cinematic
	local a, d = world.fighters[state.attacker], world.fighters[state.defender]
	-- Slow motion: the cinematic's own clock advances by a share of a tick; rhythm prompts are
	-- still read on every simulation tick.
	state.clock = (state.clock or 0) + CombatSimulation.cinematicScale(world)
	if state.clock < 1 then
		if #state.prompts > 0 then
			judgePrompts(world, state, inputs[state.attacker] or CombatSimulation.neutralInput(), events)
		end
		return
	end
	state.clock -= 1
	state.tick += 1
	if #state.prompts > 0 then
		judgePrompts(world, state, inputs[state.attacker] or CombatSimulation.neutralInput(), events)
	end
	local dir = if d.x >= a.x then 1 else -1
	for _, step in state.plan do
		if step.tick == state.tick and step.final then
			-- A prompt still waiting (a far player's lag window) is judged missed before the
			-- final blow: what the blow deals and whether it kills are decided now.
			while state.nextPrompt <= #state.prompts do
				judgePrompts(world, state, CombatSimulation.neutralInput(), events, true)
			end
		end
	end
	for _, step in state.plan do
		if step.tick == state.tick then
			step.done = true
			local finishing = step.final and state.finish
			-- Only the rush's last blow or a FINAL FINISH can KO; the awakening otherwise
			-- always leaves the target standing on its last 5 %.
			local canKO = step.final and state.type == "Rush"
			d.hp = if finishing then 0 else math.max(if canKO then 0 else 1, d.hp - step.damage)
			d.comboHits += 1
			d.comboDamage += step.damage
			if state.type == "Rush" then gainMeter(d, step.damage * c.MeterWhenHit, c) end
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
		a.awakenStyle, a.fatalCombo = nil, nil
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
		perfect = winner ~= 0 and world.fighters[winner].hp == world.fighters[winner].maxHp })
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
			f.hp = f.maxHp
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
	-- A blink or a teleport (DAICHA) is the one way to cross the opponent on the ground.
	if a.crossed or b.crossed then
		previousDelta = b.x - a.x
		a.crossed, b.crossed = false, false
	end
	resolvePair(a, b, world.config, previousDelta)
	if fighting then
		detectHits(world, events)
		stepProjectiles(world, events)
		if world.training then trainingRefill(world) end
		-- ULTIMES ON (solo button, `ultimateConditions` = the player's slot): every condition of
		-- the ultimates met for that fighter, ki always full and health held at 25 % (the COUP
		-- FATAL's last breath).
		local f = world.ultimateConditions and world.fighters[world.ultimateConditions]
		if f and f.state ~= "KO" then
			f.meter = world.config.MaxMeter
			f.hp = math.min(f.hp, math.max(1, math.floor(f.maxHp * (world.config.FatalHealth or 0.3)) - math.floor(f.maxHp * 0.05)))
		end
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

-- What the HUD shows of a fighter's passive: the ticks before it is ready again (AKEMI's
-- VOILE D'OMBRE, DAICHA's OMBRE INVERSÉE: the dash) or RYUKEN's RAGE stacks; nil for the
-- passives without a gauge (SHIN's PRÉCISION, HIBECARES's ROI DES RUINES: shown from health).
function CombatSimulation.passiveGauge(world, f)
	local weave = weaveOf(world, f)
	if weave and weave.Charges then return f.slipCharge end -- TARO's slips (ESQUIVE)
	local passive = kitOf(world, f).Passive
	if not passive then return nil end
	if passive.Type == "Evade" then return f.evadeCharge end
	if passive.Type == "Blink" then return f.dashCooldown end
	if passive.Type == "Rage" then return f.rage end
	return nil
end

-- AKEMI's VOILE D'OMBRE: the evades ready (nil for the other passives).
function CombatSimulation.passiveCharges(world, f)
	local passive = kitOf(world, f).Passive
	if passive and passive.Type == "Evade" then return f.evadeCharges end
	local weave = weaveOf(world, f)
	return if weave and weave.Charges then f.slipCharges else nil
end

-- Training lab: plays a cinematic directly, without performing its combo. The two fighters
-- are placed face to face; `hp` sets the target's health (low health = FINAL FINISH).
function CombatSimulation.debugCinematic(world, slot, moveId, style, hp)
	local events = {}
	local a, d = world.fighters[slot], world.fighters[3 - slot]
	-- A cinematic type ("Rush", "Awaken", "Gate") plays the attacker's own kit version.
	moveId = kitOf(world, a).Ultimates[moveId] or moveId
	if not world.moveData.Cinematics[moveId] then return events end
	world.cinematic, world.phase, world.projectiles = nil, "Fight", {}
	for _, f in { a, d } do
		f.y, f.vy, f.vx, f.pushVx = 0, 0, 0, 0
		f.move, f.moveContact, f.stun, f.stunKind, f.launched = nil, nil, 0, nil, false
		f.knockdown, f.getUp, f.wakeInvuln, f.hitstop, f.buffer, f.grace = 0, 0, 0, 0, {}, nil
		if f.state == "KO" then f.state = "Idle" end
	end
	local center = math.clamp((a.x + d.x) / 2, world.config.ArenaMinX + 4, world.config.ArenaMaxX - 4)
	a.x, d.x, a.facing, d.facing = center - 1.3, center + 1.3, 1, -1
	d.hp = math.clamp(hp or d.maxHp, 1, d.maxHp)
	a.awakenStyle = style
	a.fatalCombo = style ~= "raw" -- (the COUP FATAL: from a combo unless asked raw)
	table.insert(events, { kind = "SuperFlash", attacker = slot, move = moveId })
	startCinematic(world, a, d, events, moveId)
	return events
end

function CombatSimulation.timerSeconds(world)
	if world.training then return -1 end
	return math.ceil(world.timerTicks / world.config.TickRate)
end

return CombatSimulation
