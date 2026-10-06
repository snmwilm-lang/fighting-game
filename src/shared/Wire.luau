--!strict
-- The fight snapshot on the wire (server -> client, 30 times a second per player): every field
-- name is sent with every packet, so the names are shortened to one character here and given
-- back in full on arrival (the rest of the client reads the usual names). A field this list
-- does not know passes through unchanged. Pure: no Roblox API, no require.
local Wire = {}

-- Order matters only for the codes: add new names at the END (the codes of the others stay).
local FIGHTER = {
	"x", "y", "vx", "vy", "facing", "state", "move", "moveFrame", "hitstop", "hp", "guard", "meter", "combo",
	"comboDamage", "wins", "crouching", "maxHp", "passive", "weave", "passiveCharges", "passiveLabel", "passiveOn",
	"chilled", "tempo", "poisoned", "wakeInvuln", "revived", "domination", "stance", "sparks", "evadeStyle", "flow",
	"fatal", "chainKeys", "chainClean", "cancelReady", "dirtyReason", "kit", "ping", "team", "teamIndex",
}
local PACKET = {
	"projectiles", "tick", "generation", "epoch", "phase", "phaseTicks", "round", "timer", "training", "solo", "mode",
	"matchId", "wave", "queue", "dummyMode", "ultimateConditions", "cinematic", "winner", "matchWinner", "fighters", "roster",
}
local CODES = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

local function tables(names: { string }): ({ [string]: string }, { [string]: string })
	local short: { [string]: string }, long: { [string]: string } = {}, {}
	for i, name in names do
		local code = string.sub(CODES, i, i)
		short[name], long[code] = code, name
	end
	return short, long
end
local FIGHTER_SHORT, FIGHTER_LONG = tables(FIGHTER)
local PACKET_SHORT, PACKET_LONG = tables(PACKET)
Wire.FIGHTER, Wire.PACKET = FIGHTER, PACKET

local function rename(t: { [string]: any }, map: { [string]: string }): { [string]: any }
	local out = {}
	for k, v in t do out[map[k] or k] = v end
	return out
end

-- Server side: the packet with short names (its fighters too).
function Wire.encode(packet: { [string]: any }): { [string]: any }
	local out = rename(packet, PACKET_SHORT)
	local fighters = packet.fighters
	if fighters then
		local list = {}
		for i, f in fighters do list[i] = rename(f, FIGHTER_SHORT) end
		out[PACKET_SHORT.fighters] = list
	end
	return out
end

-- Client side: the full names back.
function Wire.decode(packet: { [string]: any }): { [string]: any }
	local out = rename(packet, PACKET_LONG)
	local fighters = out.fighters
	if fighters then
		local list = {}
		for i, f in fighters do list[i] = rename(f, FIGHTER_LONG) end
		out.fighters = list
	end
	return out
end

-- (for the tests) every name once, a code for each. A name the lists do not know passes
-- through: it must not be a single character (it would be read as a code).
function Wire.check(): boolean
	for _, names in { FIGHTER, PACKET } do
		if #names > #CODES then return false end
		local seen = {}
		for _, name in names do
			if seen[name] then return false end
			seen[name] = true
		end
	end
	return true
end

return Wire
