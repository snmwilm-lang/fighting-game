--[[
	The hub (lobby) of a server: who is here, who holds the two fighter slots, and the
	challenges between players. Pure Luau (no Roblox API, no require): the server script
	applies its slot decisions to the rigs; tests/Lobby.test.luau checks the rules.

	Rules
	- The first player to arrive takes slot 1 and plays against the CPU (training / solo).
	- Anyone arriving while a player is already fighting waits in the hub and watches.
	- A player challenges another one (DÉFIER); the challenge lasts CHALLENGE_SECONDS. When
	  it is accepted, the two take slots 1 (challenger) and 2, and anyone else in a slot goes
	  back to the hub. A refusal, a new challenge, leaving or the timeout cancel it.
	- QUITTER LE COMBAT puts a player back in the hub (the CPU takes the place).
	- JOUER (from the hub) takes a free slot only when no other player is fighting.
	- When a fighter leaves the server and nobody plays any more, the first player waiting
	  in the hub takes slot 1.

	  local lobby = Lobby.new()
	  Lobby.join(lobby, id, name)            -- returns the slot taken (0 = hub)
	  Lobby.challenge(lobby, from, to, now)  -- true when the challenge is sent
	  Lobby.accept(lobby, to, from, now)     -- true when the 1v1 starts
	  lobby.slots[1], lobby.slots[2]         -- player ids (nil = CPU / dummy)
]]
local Lobby = {}

Lobby.CHALLENGE_SECONDS = 30

function Lobby.new()
	return { players = {}, order = {}, slots = {}, challenges = {} }
end

local function slotOf(lobby, id)
	for i = 1, 2 do
		if lobby.slots[i] == id then return i end
	end
	return 0
end
Lobby.slotOf = slotOf

local function humans(lobby)
	local n = 0
	for i = 1, 2 do
		if lobby.slots[i] ~= nil then n += 1 end
	end
	return n
end

-- Removes every challenge sent by or to `id`.
local function dropChallenges(lobby, id)
	for from, c in lobby.challenges do
		if from == id or c.to == id then lobby.challenges[from] = nil end
	end
end

function Lobby.join(lobby, id, name)
	if lobby.players[id] then return slotOf(lobby, id) end
	lobby.players[id] = { name = name or tostring(id) }
	table.insert(lobby.order, id)
	if humans(lobby) == 0 then
		lobby.slots[1] = id
		return 1
	end
	return 0
end

function Lobby.leave(lobby, id)
	if not lobby.players[id] then return end
	lobby.players[id] = nil
	table.remove(lobby.order, table.find(lobby.order, id))
	dropChallenges(lobby, id)
	local slot = slotOf(lobby, id)
	if slot > 0 then lobby.slots[slot] = nil end
	if humans(lobby) == 0 then
		-- Nobody plays any more: the first player waiting in the hub takes slot 1.
		for _, other in lobby.order do
			lobby.slots[1] = other
			break
		end
	end
end

function Lobby.challenge(lobby, from, to, now)
	if from == to or not lobby.players[from] or not lobby.players[to] then return false end
	-- Already fighting each other: nothing to challenge.
	if slotOf(lobby, from) > 0 and slotOf(lobby, to) > 0 then return false end
	lobby.challenges[from] = { to = to, expires = now + Lobby.CHALLENGE_SECONDS }
	return true
end

function Lobby.decline(lobby, to, from)
	local c = lobby.challenges[from]
	if not c or c.to ~= to then return false end
	lobby.challenges[from] = nil
	return true
end

function Lobby.accept(lobby, to, from, now)
	local c = lobby.challenges[from]
	if not c or c.to ~= to or now > c.expires then return false end
	if not lobby.players[from] or not lobby.players[to] then return false end
	dropChallenges(lobby, from)
	dropChallenges(lobby, to)
	-- The challenger takes slot 1, the challenged slot 2; anyone else fighting goes to the hub.
	lobby.slots[1], lobby.slots[2] = from, to
	return true
end

function Lobby.quit(lobby, id)
	local slot = slotOf(lobby, id)
	if slot == 0 then return false end
	lobby.slots[slot] = nil
	return true
end

function Lobby.play(lobby, id)
	if not lobby.players[id] or slotOf(lobby, id) > 0 or humans(lobby) > 0 then return false end
	lobby.slots[1] = id
	return true
end

-- Drops the challenges that timed out.
function Lobby.expire(lobby, now)
	for from, c in lobby.challenges do
		if now > c.expires then lobby.challenges[from] = nil end
	end
end

-- What the hub screens show: every player with their slot and the challenges they sent and
-- received ({ id, name, slot, challenged = { ids it challenged }, from = { ids challenging it } }).
function Lobby.status(lobby)
	local list = {}
	for _, id in lobby.order do
		local entry = { id = id, name = lobby.players[id].name, slot = slotOf(lobby, id), sent = nil, from = {} }
		local c = lobby.challenges[id]
		if c then entry.sent = c.to end
		for from, other in lobby.challenges do
			if other.to == id then table.insert(entry.from, from) end
		end
		table.insert(list, entry)
	end
	return list
end

return Lobby
