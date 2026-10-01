--[[
	Frame data for every attack. Pure data, read by the authoritative simulation and by the
	client for presentation only.

	Timeline of a move lasting startup + active + recovery ticks, frame counted from 1:
	  1 .. startup                        startup  (no hitbox)
	  startup + 1 .. startup + active     active   (hitbox live, hits at most once)
	  startup + active + 1 .. total       recovery
	The move ends after its last recovery tick. Hitstop suspends the frame counter.

	hitbox: offsets from the attacker, along its facing (near/far) and above its feet (low/high).
	guard: "Mid" is blocked standing or crouching, "High" only standing, "Low" only crouching.
	cancels: button -> move id, allowed once the move made contact (hit or block).
	Blocked hits deal damage * CombatConfig.BlockDamageRatio and can never KO.
	launch: vertical velocity given to the target; launched targets fall into a knockdown.
	heavy: presentation hint for bigger effects.
]]

local MoveData = {}

MoveData.Moves = table.freeze({
	Jab = table.freeze({
		id = "Jab", name = "JAB", startup = 5, active = 3, recovery = 9,
		damage = 45, guardDamage = 6,
		hitstun = 17, blockstun = 11, hitstop = 6,
		push = 10, blockPush = 12, lunge = 4, launch = 0,
		hitbox = table.freeze({ near = 0.4, far = 3.6, low = 2.6, high = 4.6 }),
		guard = "Mid",
		cancels = table.freeze({ Light = "Cross", Heavy = "Rising" }),
	}),
	Cross = table.freeze({
		id = "Cross", name = "CROSS", startup = 6, active = 3, recovery = 11,
		damage = 55, guardDamage = 8,
		hitstun = 19, blockstun = 12, hitstop = 7,
		push = 11, blockPush = 13, lunge = 7, launch = 0,
		hitbox = table.freeze({ near = 0.4, far = 3.9, low = 2.6, high = 4.6 }),
		guard = "Mid",
		cancels = table.freeze({ Light = "Elbow", Heavy = "Rising" }),
	}),
	Elbow = table.freeze({
		id = "Elbow", name = "COUDE", startup = 6, active = 3, recovery = 13,
		damage = 60, guardDamage = 9,
		hitstun = 21, blockstun = 13, hitstop = 8,
		push = 9, blockPush = 12, lunge = 10, launch = 0,
		hitbox = table.freeze({ near = 0.3, far = 3.3, low = 2.8, high = 5.0 }),
		guard = "Mid",
		cancels = table.freeze({ Light = "Kick", Heavy = "Rising" }),
	}),
	Kick = table.freeze({
		id = "Kick", name = "KICK", startup = 8, active = 4, recovery = 17,
		damage = 75, guardDamage = 12,
		hitstun = 24, blockstun = 14, hitstop = 9,
		push = 14, blockPush = 18, lunge = 8, launch = 0,
		hitbox = table.freeze({ near = 0.4, far = 4.4, low = 1.8, high = 4.4 }),
		guard = "Mid", heavy = true,
		cancels = table.freeze({ Heavy = "Rising" }),
	}),
	Smash = table.freeze({
		id = "Smash", name = "FRAPPE LOURDE", startup = 13, active = 4, recovery = 22,
		damage = 120, guardDamage = 40,
		hitstun = 26, blockstun = 16, hitstop = 11,
		push = 34, blockPush = 22, lunge = 12, launch = 0,
		hitbox = table.freeze({ near = 0.4, far = 4.2, low = 2.4, high = 4.8 }),
		guard = "Mid", heavy = true,
	}),
	Rising = table.freeze({
		id = "Rising", name = "RISING STRIKE", startup = 9, active = 5, recovery = 24,
		damage = 100, guardDamage = 25,
		hitstun = 30, blockstun = 15, hitstop = 12,
		push = 6, blockPush = 18, lunge = 22, launch = 40,
		hitbox = table.freeze({ near = 0.2, far = 3.6, low = 1.5, high = 6.8 }),
		guard = "Mid", heavy = true,
	}),
	AirKick = table.freeze({
		id = "AirKick", name = "KICK AÉRIEN", startup = 6, active = 8, recovery = 10, air = true,
		damage = 65, guardDamage = 10,
		hitstun = 20, blockstun = 12, hitstop = 8,
		push = 9, blockPush = 12, lunge = 0, launch = 0,
		hitbox = table.freeze({ near = 0.3, far = 3.4, low = -0.6, high = 2.6 }),
		guard = "High",
	}),
})

-- Which move a button starts from neutral.
MoveData.Starters = table.freeze({
	Ground = table.freeze({ Light = "Jab", Heavy = "Smash" }),
	Air = table.freeze({ Light = "AirKick", Heavy = "AirKick" }),
})

function MoveData.total(move)
	return move.startup + move.active + move.recovery
end

function MoveData.phase(move, frame)
	if frame <= move.startup then
		return "Startup"
	elseif frame <= move.startup + move.active then
		return "Active"
	end
	return "Recovery"
end

return table.freeze(MoveData)
