--[[
	THE TUTORIAL (pure Luau: no Roblox API, no require; the moves table is passed in). Played
	once at the first launch (and again from SETTINGS), in a TRAINING match with KAI against
	the dummy, SKIP at any time. Each step says what to do (keyboard, gamepad and touch) and
	moves on by itself once the player really did it: the client watches its own fighter and
	the match's events (Tutorial.observe); the server makes the dummy attack for the guard
	steps (Tutorial.dummyInput, asked by the client with the step's `dummy`).
	The fight is never touched: the dummy only sends inputs, like a CPU; the simulation decides.
	Tests: tests/CombatSimulation.test.luau ("tutorial").
]]
local Tutorial = {}

Tutorial.VERSION = 2 -- (2: the tutorial replaced the v0.21 guide; raise it to show a new tutorial to everyone again)
Tutorial.DUMMIES = { STILL = true, JAB = true, LOW = true }

-- The steps, in order. `keys`: what to press on a PC, a gamepad, a touch screen.
Tutorial.STEPS = {
	{ id = "move", title = "MOVE", text = "Walk forward, then back.",
		keys = { pc = "A/Q · D", pad = "LEFT STICK", touch = "JOYSTICK" }, dummy = "STILL" },
	{ id = "jump", title = "JUMP", text = "Jump.", keys = { pc = "SPACE", pad = "A", touch = "JUMP" }, dummy = "STILL" },
	{ id = "dash", title = "DASH", text = "Dash: a quick step, forward or back.", keys = { pc = "SHIFT", pad = "RT", touch = "DASH" },
		dummy = "STILL" },
	{ id = "light", title = "ATTACK", text = "Hit the dummy 3 times with light attacks.",
		keys = { pc = "LEFT CLICK", pad = "X", touch = "ATTACK" }, dummy = "STILL", count = 3 },
	{ id = "heavy", title = "HEAVY", text = "Land a heavy attack: slower, it hurts more.",
		keys = { pc = "RIGHT CLICK", pad = "B", touch = "HEAVY" }, dummy = "STILL" },
	{ id = "combo", title = "COMBO", text = "Chain 4 hits in a row: press again as each blow comes out.",
		keys = { pc = "CLICKS", pad = "X / B", touch = "ATTACK / HEAVY" }, dummy = "STILL", count = 4 },
	{ id = "guard", title = "GUARD", text = "The dummy attacks: hold BACK (away from it) to guard 2 blows.",
		keys = { pc = "HOLD BACK (or F)", pad = "STICK BACK (or RB)", touch = "JOYSTICK BACK (or GUARD)" }, dummy = "JAB", count = 2 },
	{ id = "low", title = "LOW GUARD", text = "It kicks low now: hold DOWN-BACK to guard the sweep.",
		keys = { pc = "S + BACK", pad = "STICK DOWN-BACK", touch = "JOYSTICK DOWN-BACK" }, dummy = "LOW" },
	{ id = "special", title = "SPECIAL", text = "Use your special move.", keys = { pc = "E", pad = "Y", touch = "SPEC" }, dummy = "STILL" },
	{ id = "ultimate", title = "ULTIMATE", text = "Your ki bars are full: unleash your ultimate.",
		keys = { pc = "R", pad = "LT", touch = "ULTI" }, dummy = "STILL" },
}

-- A new run of the tutorial.
function Tutorial.new()
	return { step = 1, count = 0, left = 0, right = 0, lastX = nil, done = false }
end

function Tutorial.current(state)
	return Tutorial.STEPS[state.step]
end

local function advance(state)
	state.step += 1
	state.count, state.left, state.right, state.lastX = 0, 0, 0, nil
	if state.step > #Tutorial.STEPS then state.done = true end
	return true
end

-- Watches one thing that happened: { kind = "frame", me = fighter view } every frame, or a
-- match event (Hit, Block, Projectile...). `slot`: the player's slot; `moves`: MoveData.Moves.
-- Returns true when the step was just completed (the state moved to the next one).
function Tutorial.observe(state, slot, thing, moves)
	if state.done or type(thing) ~= "table" then return false end
	local step = Tutorial.STEPS[state.step]
	local id = step.id
	if thing.kind == "frame" then
		local me = thing.me
		if type(me) ~= "table" then return false end
		if id == "move" and type(me.x) == "number" then
			if state.lastX then
				local dx = me.x - state.lastX
				if dx > 0 then state.right += dx else state.left -= dx end
			end
			state.lastX = me.x
			if state.left >= 2 and state.right >= 2 then return advance(state) end
		elseif id == "jump" and (me.y or 0) > 1.5 then
			return advance(state)
		elseif id == "dash" and me.state == "Dashing" then
			return advance(state)
		elseif (id == "special" or id == "ultimate") and me.move and moves[me.move] then
			local kind = moves[me.move].kind
			if (id == "special" and kind == "Special") or (id == "ultimate" and kind == "Ultimate") then return advance(state) end
		end
		return false
	end
	local m = thing.move and moves[thing.move]
	if thing.kind == "Hit" and thing.attacker == slot then
		if id == "light" and not thing.heavy then
			state.count += 1
		elseif id == "heavy" and thing.heavy then
			return advance(state)
		elseif id == "combo" and (thing.combo or 0) >= (step.count or 4) then
			return advance(state)
		end
	elseif thing.kind == "Block" and thing.defender == slot then
		if id == "guard" then
			state.count += 1
		elseif id == "low" and m and m.guard == "Low" then
			return advance(state)
		end
	elseif thing.kind == "SuperFlash" and thing.attacker == slot and id == "ultimate" then
		return advance(state)
	end
	if step.count and state.count >= step.count and (id == "light" or id == "guard") then return advance(state) end
	return false
end

-- What the dummy does on a step (the server, in a TRAINING match with the tutorial on):
-- STILL stands; JAB walks up and jabs about once a second; LOW walks up and sweeps (crouching
-- light). `input`: a neutral input to fill; `me`, `foe`: the dummy's and the player's fighters.
function Tutorial.dummyInput(mode, me, foe, tick, input)
	if mode ~= "JAB" and mode ~= "LOW" then return input end
	if type(me) ~= "table" or type(foe) ~= "table" then return input end
	local dx = foe.x - me.x
	if math.abs(dx) > 3 then
		input.axis = if dx > 0 then 1 else -1
		return input
	end
	if mode == "LOW" then input.crouch = true end
	input.light = tick % 70 == 0
	return input
end

return Tutorial
