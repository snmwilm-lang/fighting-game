--[[
	When to write the profiles (pure Luau: no Roblox API, no require; the time is passed in).
	Built for tens of thousands of players spread over many servers:
	  • a change marks the profile dirty; it is written at the next flush, never more than
	    once every MIN_GAP seconds per player (Roblox: one write per key every 6 s);
	  • a regular flush (FLUSH_PERIOD) writes the dirty ones, at most BATCH per flush, the
	    oldest first (a full server never bursts past the DataStore budget);
	  • leaving or the server closing writes right away (urgent), whatever the gap;
	  • a profile that never loaded (DataStore down) is NEVER written: that would erase the
	    real save with an empty one;
	  • a failed write stays dirty and is retried at the next flush;
	  • the session lock (GlobalQueue.canLock) stays fresh while the player is here: every flush
	    also rewrites, as it is, each loaded profile whose lock is RENEW seconds old, changed or
	    not, with no BATCH limit (B-025). Never while it leaves, never after another server
	    took it (`lost`: its copy there is newer), never once the server closes;
	  • the last write (leaving, closing) is retried on a DataStore error, never on a lock
	    held by another server (`finalRetry`, B-032).
	SESSIONS: a player may come back to the same server while the last write of their previous
	visit is still being retried (or Roblox may add the new visit before removing the old
	one). Each visit is a session (any value: the server passes its client table), and the
	entry of an id belongs to ONE session: the one that loaded it. Every call names its
	session; a call from another session never reads it as loaded, never marks, leaves nor
	forgets it. `held` tells the new session to wait for the old one (its last write) before
	loading. A session left out (nil) is a session of its own: the tests' single visits.
	The leaderboard is written only when the rating changed since its last write.
	Used by src/server/init.server.luau; tests: tests/Lobby.test.luau.
]]
local SaveQueue = {}

SaveQueue.MIN_GAP = 7
SaveQueue.FLUSH_PERIOD = 15
SaveQueue.BATCH = 8
SaveQueue.LOAD_TRIES = 4
-- (seconds: a loaded profile is rewritten when its lock is this old. One renewal may fail:
-- RENEW + 2 * FLUSH_PERIOD = 50 s stays under GlobalQueue.LOCK_TTL = 60 s)
SaveQueue.RENEW = 20
SaveQueue.FINAL_TRIES = 4 -- (the last write: 1 try and 3 retries, after 1, 2 and 4 s)

function SaveQueue.new()
	return { entries = {}, boards = {} }
end

local function fresh(session)
	return {
		session = session, -- (the visit this entry belongs to)
		loaded = false, dirty = false, since = 0, lastWrite = -math.huge,
		lockAt = -math.huge, -- (the start of the last load or write that stamped the lock)
		leaving = false, -- (the player left: only the last write, by the leaving thread)
		lost = false, -- (another server holds the profile: never written from here again)
	}
end

-- The entry of `id` for `session`, or nil when it belongs to another session that loaded
-- it (that one is never touched from here). `create`: make it when there is none (a
-- leftover of another session that never loaded is replaced).
local function own(q, id, session, create)
	local e = q.entries[id]
	if e and e.session ~= session then
		if e.loaded then return nil end
		e = nil
	end
	if not e and create then
		e = fresh(session)
		q.entries[id] = e
	end
	return e
end

-- The profile of `id` loaded from the store (or is new) by `session`: it may be written from
-- now on. `now`: when that load started (it stamped the session lock). The id is this
-- session's from now on, even over an older session's entry.
function SaveQueue.loaded(q, id, now, session)
	local e = q.entries[id]
	if not e or e.session ~= session then
		e = fresh(session)
		q.entries[id] = e
	end
	e.loaded, e.leaving, e.lost = true, false, false
	if now then e.lockAt = math.max(e.lockAt, now) end
end

-- Did THIS session load the profile of `id`? (never true for a visit still loading, even
-- while an older visit of the same player is still in the queue)
function SaveQueue.isLoaded(q, id, session)
	local e = q.entries[id]
	return e ~= nil and e.loaded and e.session == session
end

-- Another session of this player holds the id (still here, or its last write still being
-- retried): a new session waits for it before loading.
function SaveQueue.held(q, id, session)
	local e = q.entries[id]
	return e ~= nil and e.loaded and e.session ~= session
end

function SaveQueue.isDirty(q, id, session)
	local e = q.entries[id]
	return e ~= nil and e.dirty and e.session == session
end

-- Something changed in the profile of `id` (in `session`).
function SaveQueue.mark(q, id, now, session)
	local e = own(q, id, session, true)
	if e and not e.dirty then e.dirty, e.since = true, now end
end

local function writable(e)
	return e.loaded and not e.leaving and not e.lost
end

-- The ids to write now: urgent ones (leaving, closing) first whatever the gap, then the
-- dirty ones whose gap is over, oldest first, at most BATCH. Never one not loaded (nor one
-- leaving, nor one another server took).
function SaveQueue.due(q, now, urgent)
	local list = {}
	for id, e in q.entries do
		if writable(e) and e.dirty and (urgent or now - e.lastWrite >= SaveQueue.MIN_GAP) then
			table.insert(list, { id = id, since = e.since })
		end
	end
	table.sort(list, function(a, b)
		if a.since ~= b.since then return a.since < b.since end
		return a.id < b.id
	end)
	local out = {}
	for i, item in list do
		if not urgent and i > SaveQueue.BATCH then break end
		table.insert(out, item.id)
	end
	return out
end

-- The loaded profiles whose session lock is RENEW seconds old (and last written MIN_GAP
-- ago), changed or not, the oldest lock first. No BATCH limit: every present player keeps
-- a fresh lock, however many they are (at most one write per player and flush).
function SaveQueue.renewals(q, now)
	local list = {}
	for id, e in q.entries do
		if writable(e) and now - e.lockAt >= SaveQueue.RENEW and now - e.lastWrite >= SaveQueue.MIN_GAP then
			table.insert(list, { id = id, at = e.lockAt })
		end
	end
	table.sort(list, function(a, b)
		if a.at ~= b.at then return a.at < b.at end
		return a.id < b.id
	end)
	local out = {}
	for _, item in list do table.insert(out, item.id) end
	return out
end

-- One flush: the dirty ones (`due`), then the renewals not already in it. `closing`: the
-- server closes, its last writes released the locks: no renewal takes one back. (The
-- server writes an id only for the session that loaded it: `isLoaded`.)
function SaveQueue.flush(q, now, closing)
	local out = SaveQueue.due(q, now, false)
	if closing then return out end
	local taken = {}
	for _, id in out do taken[id] = true end
	for _, id in SaveQueue.renewals(q, now) do
		if not taken[id] then table.insert(out, id) end
	end
	return out
end

-- A write of `id` by `session` is starting: it is clean until the next change (a failed
-- write calls `failed`, which puts it back).
function SaveQueue.writing(q, id, now, session)
	local e = own(q, id, session, false)
	if e then e.dirty, e.lastWrite = false, now end
end

-- The write that started at `started` is in the store: the lock is that fresh.
function SaveQueue.written(q, id, started, session)
	local e = own(q, id, session, false)
	if e then e.lockAt = math.max(e.lockAt, started) end
end

function SaveQueue.failed(q, id, now, session)
	local e = own(q, id, session, false) -- (never brings back a player forgotten)
	if e and not e.dirty then e.dirty, e.since = true, now end
end

-- A write was refused: another server holds a fresh lock on the profile (the player is
-- there now). Its copy is newer: this server never writes it again, even once that lock
-- is released.
function SaveQueue.lost(q, id, session)
	local e = own(q, id, session, false)
	if e then e.lost = true end
end

function SaveQueue.isLost(q, id, session)
	local e = own(q, id, session, false)
	return e ~= nil and e.lost
end

-- The player left: from now on only the last write (and its retries) touches the profile,
-- then `forget`.
function SaveQueue.leaving(q, id, session)
	local e = own(q, id, session, false)
	if e then e.leaving = true end
end

-- Should the leaderboard get this rating? (only when it changed; one per player, whatever
-- the session)
function SaveQueue.boardChanged(q, id, rating)
	if q.boards[id] == rating then return false end
	q.boards[id] = rating
	return true
end

-- The session left: forget it (after its last write). Never the entry of a newer session.
-- True when forgotten.
function SaveQueue.forget(q, id, session)
	local e = q.entries[id]
	if e and e.session ~= session then return false end
	q.entries[id] = nil
	q.boards[id] = nil
	return true
end

-- Seconds to wait before the n-th retry of a failed load (1, 2, 4, 8...).
function SaveQueue.retryDelay(attempt)
	return 2 ^ (attempt - 1)
end

-- The last write (leaving, closing) failed at try `attempt`, for `why`: the seconds to wait
-- before trying again, or nil to give up. Only a DataStore error ("error") is retried, up to
-- FINAL_TRIES tries (1 + 2 + 4 = 7 s of waits, inside the 25 s of BindToClose); never a
-- lock held by another server ("lost"), nor a write that had nothing to do.
function SaveQueue.finalRetry(why, attempt)
	if why ~= "error" or attempt >= SaveQueue.FINAL_TRIES then return nil end
	return SaveQueue.retryDelay(attempt)
end

return SaveQueue
