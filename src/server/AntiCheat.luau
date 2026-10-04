--[[
	Anti-cheat rules (pure Luau: no Roblox API, no require; the time and the profiles are
	passed in). The server is already the only judge of every blow, health and K.O., and the
	players have no physical character to move; what is left to cheat is the remotes and the
	rewards. This module decides; src/server/init.server.luau applies.

	1. SUSPICION. A packet the real client never sends (wrong types or values, an unknown action,
	   an input sequence going back, a gross flood) adds suspicion points; they fade by
	   DECAY per second. At KICK points the player is kicked (a log line on the server); a real
	   player never gets near it (malformed packets are impossible from the game's client).
	2. FARMING. Coins and ELO are earned only by real matches:
	   • a match shorter than MIN_MATCH seconds pays nothing and moves no rating (an alt
	     joining and leaving at once);
	   • the same two players again and again: from the REPEAT_SOFT-th match of the day the
	     gains are divided, from REPEAT_HARD on they stop (two alt accounts);
	   • coins per day are capped (DAILY_COINS), kept in the profile (every server sees it).
	Tests: tests/Lobby.test.luau.
]]
local AntiCheat = {}

AntiCheat.KICK = 100
AntiCheat.DECAY = 0.5 -- points forgotten per second
AntiCheat.WEIGHTS = {
	malformed = 25, -- a packet with impossible types or values
	flood = 20, -- a gross flood: more than FLOOD_DROPS packets dropped within one second
	replay = 10, -- an input sequence number going back
}
AntiCheat.FLOOD_DROPS = 120 -- (a 144 Hz client mashing stays far below; a flood tool does not)
AntiCheat.MIN_MATCH = 25
AntiCheat.REPEAT_SOFT = 4
AntiCheat.REPEAT_HARD = 8
AntiCheat.DAILY_COINS = 2000
AntiCheat.RECENT_LIMIT = 30 -- opponents remembered per profile

function AntiCheat.new()
	return { players = {}, log = {} }
end

-- A suspicious act; returns true when the player must be kicked.
function AntiCheat.flag(ac, id, reason, now)
	local p = ac.players[id]
	if not p then
		p = { score = 0, at = now, reasons = {} }
		ac.players[id] = p
	end
	p.score = math.max(0, p.score - (now - p.at) * AntiCheat.DECAY)
	p.at = now
	p.score += AntiCheat.WEIGHTS[reason] or 10
	p.reasons[reason] = (p.reasons[reason] or 0) + 1
	if p.score >= AntiCheat.KICK and not p.kicked then
		p.kicked = true
		table.insert(ac.log, { id = id, at = now, reasons = table.clone(p.reasons) })
		return true
	end
	return false
end

function AntiCheat.score(ac, id, now)
	local p = ac.players[id]
	if not p then return 0 end
	return math.max(0, p.score - (now - p.at) * AntiCheat.DECAY)
end

function AntiCheat.forget(ac, id)
	ac.players[id] = nil
end

-- A token bucket (rate per second, burst): true when the packet may pass.
function AntiCheat.bucket(state, now, rate, burst)
	state.tokens = math.min(burst, (state.tokens or burst) + (now - (state.at or now)) * rate)
	state.at = now
	if state.tokens < 1 then return false end
	state.tokens -= 1
	return true
end

local function day(time)
	return math.floor(time / 86400)
end

-- How much of a match's gains a player keeps: { coins = 0..1, rating = 0..1 }.
-- `profile.recentOpp` keeps today's count against each opponent (saved: every server sees it).
function AntiCheat.share(profile, opponentId, seconds, time)
	if seconds < AntiCheat.MIN_MATCH then return { coins = 0, rating = 0, reason = "short" } end
	if not opponentId then return { coins = 1, rating = 1 } end
	local recent = type(profile.recentOpp) == "table" and profile.recentOpp or {}
	local key = tostring(opponentId)
	local today = day(time)
	local e = recent[key]
	local count = if type(e) == "table" and e.day == today then e.count else 0
	if count >= AntiCheat.REPEAT_HARD then return { coins = 0, rating = 0, reason = "repeat" } end
	if count >= AntiCheat.REPEAT_SOFT then return { coins = 0.25, rating = 0.25, reason = "repeat" } end
	return { coins = 1, rating = 1 }
end

-- Counts a match against `opponentId` today (keeps the RECENT_LIMIT latest opponents).
function AntiCheat.record(profile, opponentId, time)
	if not opponentId then return end
	local recent = type(profile.recentOpp) == "table" and profile.recentOpp or {}
	local key, today = tostring(opponentId), day(time)
	local e = recent[key]
	if type(e) ~= "table" or e.day ~= today then e = { day = today, count = 0 } end
	e.count += 1
	e.at = time
	recent[key] = e
	-- (bounded: the oldest ones go)
	local keys = {}
	for k, v in recent do
		if type(v) == "table" then table.insert(keys, { k = k, at = v.at or 0 }) else recent[k] = nil end
	end
	if #keys > AntiCheat.RECENT_LIMIT then
		table.sort(keys, function(a, b) return a.at < b.at end)
		for i = 1, #keys - AntiCheat.RECENT_LIMIT do recent[keys[i].k] = nil end
	end
	profile.recentOpp = recent
end

-- Counts a dropped packet; true when this second's drops make a gross flood (flag it once).
function AntiCheat.dropped(state, now)
	local second = math.floor(now)
	if state.second ~= second then state.second, state.drops, state.flagged = second, 0, false end
	state.drops += 1
	if state.drops > AntiCheat.FLOOD_DROPS and not state.flagged then
		state.flagged = true
		return true
	end
	return false
end

-- The coins a player may still get today (the cap is in the profile: coinDay, coinToday).
function AntiCheat.capCoins(profile, gain, time)
	local today = day(time)
	if profile.coinDay ~= today then profile.coinDay, profile.coinToday = today, 0 end
	local allowed = math.max(0, math.min(gain, AntiCheat.DAILY_COINS - (profile.coinToday or 0)))
	profile.coinToday = (profile.coinToday or 0) + allowed
	return allowed
end

-- A rating change scaled by the share (the loser loses as much as the winner gains).
function AntiCheat.scaleRating(before, after, share)
	local delta = after - before
	return before + math.sign(delta) * math.floor(math.abs(delta) * share + 0.5)
end

return AntiCheat
