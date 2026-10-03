--[[
	Opponent search for 1 CONTRE 1 · JOUEUR. Pure Luau (no Roblox API, no require): the server
	script asks it who to pair and applies the result; tests/Lobby.test.luau checks the rules.

	Rules
	- NORMAL: the two players who waited the longest play each other.
	- CLASSÉ (RANKED): two players are paired when their ratings are close enough. The gap
	  allowed starts at BASE_WINDOW points and widens by WIDEN_PER_SECOND each second of
	  waiting (up to MAX_WINDOW): nobody waits forever.
	- A player is in one queue at a time; leaving the server or the menu removes them.
	- Ratings: Elo, K = K_FACTOR, starting at START_RATING; a rank name per band.

	  local mm = Matchmaker.new()
	  Matchmaker.enqueue(mm, id, "RANKED", rating, now)
	  for _, pair in Matchmaker.pair(mm, now) do ... pair.a, pair.b, pair.queue ... end
	  local newA, newB = Matchmaker.elo(ratingA, ratingB, scoreA)  -- scoreA: 1, 0.5 or 0
]]
local Matchmaker = {}

Matchmaker.START_RATING = 1000
Matchmaker.K_FACTOR = 32
Matchmaker.BASE_WINDOW = 100
Matchmaker.WIDEN_PER_SECOND = 25
Matchmaker.MAX_WINDOW = 800

Matchmaker.RANKS = {
	{ min = 0, name = "BRONZE" },
	{ min = 900, name = "ARGENT" },
	{ min = 1100, name = "OR" },
	{ min = 1300, name = "PLATINE" },
	{ min = 1500, name = "DIAMANT" },
	{ min = 1700, name = "LÉGENDE" },
}

function Matchmaker.new()
	return { waiting = {}, serial = 0 } -- waiting: id -> { queue, rating, since, order }
end

function Matchmaker.enqueue(mm, id, queue, rating, now)
	mm.serial += 1
	mm.waiting[id] = { queue = queue, rating = rating or Matchmaker.START_RATING, since = now, order = mm.serial }
end

function Matchmaker.leave(mm, id)
	mm.waiting[id] = nil
end

function Matchmaker.waitingIn(mm, queue)
	local n = 0
	for _, entry in mm.waiting do
		if entry.queue == queue then n += 1 end
	end
	return n
end

local function window(entry, now)
	return math.min(Matchmaker.MAX_WINDOW, Matchmaker.BASE_WINDOW + Matchmaker.WIDEN_PER_SECOND * (now - entry.since))
end

-- Pairs as many players as the rules allow; the paired players leave the queue.
function Matchmaker.pair(mm, now)
	local pairs = {}
	for _, queue in { "NORMAL", "RANKED" } do
		local list = {}
		for id, entry in mm.waiting do
			if entry.queue == queue then table.insert(list, { id = id, entry = entry }) end
		end
		table.sort(list, function(x, y) return x.entry.order < y.entry.order end) -- longest wait first
		local taken = {}
		for i, x in list do
			if not taken[x.id] then
				local best, bestGap = nil, math.huge
				for j = i + 1, #list do
					local y = list[j]
					if not taken[y.id] then
						local gap = math.abs(x.entry.rating - y.entry.rating)
						if queue == "NORMAL" then
							best, bestGap = y, 0
							break
						end
						if gap <= math.min(window(x.entry, now), window(y.entry, now)) and gap < bestGap then
							best, bestGap = y, gap
						end
					end
				end
				if best then
					taken[x.id], taken[best.id] = true, true
					mm.waiting[x.id], mm.waiting[best.id] = nil, nil
					table.insert(pairs, { a = x.id, b = best.id, queue = queue })
				end
			end
		end
	end
	return pairs
end

-- Elo update. scoreA = 1 (A won), 0.5 (draw) or 0 (B won). Ratings never go below 0.
function Matchmaker.elo(ratingA, ratingB, scoreA)
	local expectedA = 1 / (1 + 10 ^ ((ratingB - ratingA) / 400))
	local delta = Matchmaker.K_FACTOR * (scoreA - expectedA)
	return math.max(0, math.floor(ratingA + delta + 0.5)), math.max(0, math.floor(ratingB - delta + 0.5))
end

function Matchmaker.rankName(rating)
	local name = Matchmaker.RANKS[1].name
	for _, rank in Matchmaker.RANKS do
		if rating >= rank.min then name = rank.name end
	end
	return name
end

return Matchmaker
