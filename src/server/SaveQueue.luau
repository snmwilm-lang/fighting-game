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
	  • a failed write stays dirty and is retried at the next flush.
	The leaderboard is written only when the rating changed since its last write.
	Used by src/server/init.server.luau; tests: tests/Lobby.test.luau.
]]
local SaveQueue = {}

SaveQueue.MIN_GAP = 7
SaveQueue.FLUSH_PERIOD = 15
SaveQueue.BATCH = 8
SaveQueue.LOAD_TRIES = 4

function SaveQueue.new()
	return { entries = {} }
end

local function entry(q, id)
	local e = q.entries[id]
	if not e then
		e = { loaded = false, dirty = false, since = 0, lastWrite = -math.huge, boardRating = nil }
		q.entries[id] = e
	end
	return e
end

-- The profile of `id` loaded from the store (or is new): it may be written from now on.
function SaveQueue.loaded(q, id)
	entry(q, id).loaded = true
end

function SaveQueue.isLoaded(q, id)
	local e = q.entries[id]
	return e ~= nil and e.loaded
end

function SaveQueue.isDirty(q, id)
	local e = q.entries[id]
	return e ~= nil and e.dirty
end

-- Something changed in the profile of `id`.
function SaveQueue.mark(q, id, now)
	local e = entry(q, id)
	if not e.dirty then e.dirty, e.since = true, now end
end

-- The ids to write now: urgent ones (leaving, closing) first whatever the gap, then the
-- dirty ones whose gap is over, oldest first, at most BATCH. Never one not loaded.
function SaveQueue.due(q, now, urgent)
	local list = {}
	for id, e in q.entries do
		if e.loaded and e.dirty and (urgent or now - e.lastWrite >= SaveQueue.MIN_GAP) then
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

-- A write of `id` is starting: it is clean until the next change (a failed write calls
-- `failed`, which puts it back).
function SaveQueue.writing(q, id, now)
	local e = entry(q, id)
	e.dirty, e.lastWrite = false, now
end

function SaveQueue.failed(q, id, now)
	SaveQueue.mark(q, id, now)
end

-- Should the leaderboard get this rating? (only when it changed)
function SaveQueue.boardChanged(q, id, rating)
	local e = entry(q, id)
	if e.boardRating == rating then return false end
	e.boardRating = rating
	return true
end

-- The player left: forget it (after its last write).
function SaveQueue.forget(q, id)
	q.entries[id] = nil
end

-- Seconds to wait before the n-th retry of a failed load (1, 2, 4, 8...).
function SaveQueue.retryDelay(attempt)
	return 2 ^ (attempt - 1)
end

return SaveQueue
