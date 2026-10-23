--[[
	RANKED search across every server (pure Luau: no Roblox API, no require; the time and the
	entries are passed in). The server script (init.server.luau) keeps the entries in a
	MemoryStore sorted map and moves the players with TeleportService; this module decides.

	  • A RANKED player who found nobody on their own server for PUBLISH_AFTER seconds is
	    published: { id, rating, size, job (their server), since, team }.
	  • Each server looks for an opponent for ITS published players only, and only as the
	    "initiator": the one of the pair who waited longer (equal: the lower id). So a pair is
	    claimed by exactly one server, never by both at once.
	  • The opponent: same team size, not claimed, still fresh (refreshed every REFRESH s,
	    stale after STALE s), the closest rating inside both windows (the same widening window
	    as the server's own Matchmaker: nobody waits forever).
	  • The claim is atomic (MemoryStore UpdateAsync with `claim`): it fails when someone was
	    faster, and the search goes on.
	  • The reserved server waits for both (ARRIVE_TIMEOUT), then starts the RANKED match.
	Tests: tests/Lobby.test.luau.
]]
local GlobalQueue = {}

GlobalQueue.PUBLISH_AFTER = 6
GlobalQueue.REFRESH = 10
GlobalQueue.STALE = 30
GlobalQueue.ARRIVE_TIMEOUT = 40
GlobalQueue.BASE_WINDOW = 100
GlobalQueue.WIDEN_PER_SECOND = 25
GlobalQueue.MAX_WINDOW = 800

function GlobalQueue.window(waited)
	return math.min(GlobalQueue.MAX_WINDOW, GlobalQueue.BASE_WINDOW + GlobalQueue.WIDEN_PER_SECOND * math.max(0, waited))
end

-- The entry of a waiting player (what goes in the map).
function GlobalQueue.entry(id, rating, size, job, since, team, now)
	return { id = id, rating = rating, size = size, job = job, since = since, team = team, t = now, claim = nil }
end

-- Is `a` the one who claims the pair (a, b)? The longer wait, else the lower id.
function GlobalQueue.initiates(a, b)
	if a.since ~= b.since then return a.since < b.since end
	return a.id < b.id
end

local function usable(e, now)
	return e ~= nil and e.claim == nil and now - (e.t or -math.huge) <= GlobalQueue.STALE
end

-- The best opponent for `me` among `entries` (a list of entries), or nil.
function GlobalQueue.pick(me, entries, now)
	if not usable(me, now) then return nil end
	local reach = GlobalQueue.window(now - me.since)
	local best, bestGap = nil, math.huge
	for _, other in entries do
		if other.id ~= me.id and other.size == me.size and usable(other, now) and GlobalQueue.initiates(me, other) then
			local gap = math.abs(other.rating - me.rating)
			if gap <= reach and gap <= GlobalQueue.window(now - other.since) then
				if gap < bestGap or (gap == bestGap and best and other.since < best.since) then
					best, bestGap = other, gap
				end
			end
		end
	end
	return best
end

-- The atomic claim of an entry (the MemoryStore UpdateAsync transform): the claimed entry,
-- or nil when it is gone, stale or already claimed (then nothing is written).
function GlobalQueue.claim(current, code, by, now, partner)
	if not usable(current, now) then return nil end
	local claimed = table.clone(current)
	claimed.claim = { code = code, by = by, at = now, partner = partner }
	return claimed
end

-- The reserved server: who it waits for and when to give up.
function GlobalQueue.arrival(pending, id, now)
	pending.arrived = pending.arrived or {}
	pending.arrived[id] = true
	local all = true
	for _, expected in pending.expect do
		if not pending.arrived[expected] then all = false end
	end
	return all
end

function GlobalQueue.expired(pending, now)
	return now - pending.created > GlobalQueue.ARRIVE_TIMEOUT
end

--[[
	The session lock of a saved profile (a field `_session` = { job, t } in the saved data):
	a server may load and write a profile only if no other server holds a fresh lock on it
	(the player left one server for another, e.g. a cross-server match). Each write renews
	the lock; leaving releases it. A lock older than LOCK_TTL is the trace of a crashed
	server: it is taken over.
]]
GlobalQueue.LOCK_TTL = 60
GlobalQueue.LOCK_RETRY = 3 -- (seconds between two tries while another server holds the lock)

function GlobalQueue.canLock(saved, job, now)
	local session = type(saved) == "table" and saved._session
	if type(session) ~= "table" then return true end
	if session.job == job then return true end
	return now - (tonumber(session.t) or 0) > GlobalQueue.LOCK_TTL
end

-- The data to write: the profile with this server's lock (or none, when releasing).
function GlobalQueue.stamp(profile, job, now, release)
	local data = table.clone(profile)
	data._session = if release then nil else { job = job, t = now }
	return data
end

return GlobalQueue
