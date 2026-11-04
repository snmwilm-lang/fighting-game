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
	  • The reserved server waits for both (ARRIVE_TIMEOUT), then for both saved profiles
	    (crossStart: loaded, loading, failed or gone), then starts the RANKED match. From the
	    arrival until then, the player is waiting for it (`waiting`): nothing else starts and
	    nothing publishes it (`publishable`, B-039).
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

-- May a server publish its player in the search across servers (and teleport it to a match
-- found there)? A RANKED search of PUBLISH_AFTER s or more, from a player in no match (B-039:
-- never out of a match it is playing) and not already waiting for a cross-server match on this
-- reserved server (`waiting`). `queue`, `since`: the player's search (client.queue,
-- client.queueSince); `inMatch`: seated in a match.
function GlobalQueue.publishable(queue, since, inMatch, waiting, now)
	return queue == "RANKED" and type(since) == "number" and now - since >= GlobalQueue.PUBLISH_AFTER and not inMatch and not waiting
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

-- Is a player who arrived for `pending` (client.crossPending: nil for any other player) still
-- waiting for its match? From the arrival until the match starts or is called off (the
-- server sets pending.settled: started, cancelled, the other one left or never came).
-- Meanwhile nothing else starts (GameModes.startRefusal), no challenge is accepted, nothing
-- publishes it, and the menu says OPPONENT FOUND · CONNECTING… (B-039).
function GlobalQueue.waiting(pending)
	return type(pending) == "table" and pending.settled ~= true
end

-- Both players arrived on the reserved server: the RANKED match starts only on both saved
-- profiles, never on the defaults (B-035: 1000 points, a result wiped by the merge of the
-- save) nor after a failed load (B-042: the opponent counted against 1000, the other one risks
-- nothing). `stateA`, `stateB`: each player's GameModes.saveState ("loaded", "loading",
-- "failed": SAVES UNAVAILABLE), or "gone" (left the server). `waited`: seconds since both
-- arrived. "start" (both loaded), "cancel" (one left, one load failed), or "wait" (a load still
-- on its way: it always ends, loaded or failed, before PROFILE_CAP; then "cancel"). Never a
-- fixed wait: a load can still succeed after any fixed time, or fail before it (B-039).
function GlobalQueue.crossStart(stateA, stateB, waited)
	if stateA == "gone" or stateB == "gone" then return "cancel" end
	if stateA == "failed" or stateB == "failed" then return "cancel" end
	if stateA == "loaded" and stateB == "loaded" then return "start" end
	if waited < GlobalQueue.PROFILE_CAP then return "wait" end
	return "cancel"
end

-- What a player still on the reserved server reads when its RANKED match does not start
-- (`mine`, `theirs`: the states crossStart decided on), or nil. Then it keeps its menu there.
GlobalQueue.NOTICES = {
	gone = "YOUR OPPONENT LEFT: search again",
	failed = "RANKED NEEDS YOUR SAVE: SAVES UNAVAILABLE", -- (the same as GameModes.startRefusal)
	theirsFailed = "YOUR OPPONENT'S SAVE COULD NOT BE LOADED: search again",
	loading = "YOUR SAVE IS NOT LOADED YET",
	theirsLoading = "YOUR OPPONENT'S SAVE IS NOT LOADED YET",
}
function GlobalQueue.crossNotice(mine, theirs)
	local n = GlobalQueue.NOTICES
	if theirs == "gone" then return n.gone end
	if mine == "failed" then return n.failed end
	if theirs == "failed" then return n.theirsFailed end
	if mine == "loading" then return n.loading end
	if theirs == "loading" then return n.theirsLoading end
	return nil
end

--[[
	The session lock of a saved profile (a field `_session` = { job, t } in the saved data):
	a server may load and write a profile only if no other server holds a fresh lock on it
	(the player left one server for another, e.g. a cross-server match). Each write renews
	the lock, and a present player's profile is rewritten often enough for it to stay fresh
	(SaveQueue.renewals); leaving releases it. A lock older than LOCK_TTL is the trace of a
	crashed server: it is taken over.
]]
GlobalQueue.LOCK_TTL = 60
GlobalQueue.LOCK_RETRY = 3 -- (seconds between two tries while another server holds the lock)
-- (crossStart: only a net for a load thread that never ends. A load always ends, loaded or
-- failed: on a reserved server, at most 81 s after the arrival (22 tries every LOCK_RETRY s while
-- another server holds the lock, then LOAD_TRIES tries: 1, 2, 4, 8 s apart), plus the time of
-- its 26 DataStore calls. 120 s stays above it with 1 s per call; tests: Lobby, B-039)
GlobalQueue.PROFILE_CAP = 120

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

-- One profile write (the DataStore UpdateAsync transform, `saved` = what the store holds):
-- the data to write, or nil and why nothing is written:
--   • "gone": a write that is not the last one (a flush, a lock renewal) for a player who
--     left (`present` false): the last write released the lock, this one must not take it
--     back;
--   • "lost": another server holds a fresh lock: the player is there, its copy is newer.
function GlobalQueue.write(saved, profile, job, now, release, present)
	if not release and not present then return nil, "gone" end
	if not GlobalQueue.canLock(saved, job, now) then return nil, "lost" end
	return GlobalQueue.stamp(profile, job, now, release), nil
end

return GlobalQueue
