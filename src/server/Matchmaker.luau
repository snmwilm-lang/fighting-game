--[[
	Opponent search for 1 CONTRE 1 · JOUEUR. Pure Luau (no Roblox API, no require): the server
	script asks it who to pair and applies the result; tests/Lobby.test.luau checks the rules.

	Rules
	- NORMAL: the two players who waited the longest play each other.
	- CLASSÉ (RANKED): two players are paired when their ratings are close enough. The gap
	  allowed starts at BASE_WINDOW points and widens by WIDEN_PER_SECOND each second of
	  waiting (up to MAX_WINDOW): nobody waits forever.
	- A player is in one queue at a time; leaving the server or the menu removes them.
	- Only teams of the same size meet: 1 against 1, 2 against 2, 3 against 3 (relay).
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
	{ min = 900, name = "SILVER" },
	{ min = 1100, name = "GOLD" },
	{ min = 1300, name = "PLATINUM" },
	{ min = 1500, name = "DIAMOND" },
	{ min = 1700, name = "LEGEND" },
}

function Matchmaker.new()
	return { waiting = {}, serial = 0 } -- waiting: id -> { queue, rating, since, order }
end

-- `size`: the player's team (1 to 3 fighters): only teams of the same size meet (1v1, 2v2, 3v3).
function Matchmaker.enqueue(mm, id, queue, rating, now, size)
	mm.serial += 1
	mm.waiting[id] = { queue = queue, rating = rating or Matchmaker.START_RATING, since = now, order = mm.serial, size = size or 1 }
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

-- Pairs as many players as the rules allow; the paired players leave the queue. The longest
-- wait goes first. NORMAL: with the next player waiting (same team size). CLASSÉ: with the
-- closest rating inside both windows, found by walking out from its place in the list sorted
-- by rating (O(n log n): thousands of players waiting stay cheap).
function Matchmaker.pair(mm, now)
	local pairs = {}
	-- one list per queue and team size
	local groups = {}
	for id, entry in mm.waiting do
		local key = entry.queue .. "/" .. entry.size
		groups[key] = groups[key] or { queue = entry.queue, list = {} }
		table.insert(groups[key].list, { id = id, entry = entry })
	end
	local keys = {}
	for key in groups do table.insert(keys, key) end
	table.sort(keys) -- (a fixed order: the same queue always pairs the same way)
	for _, key in keys do
		local queue, list = groups[key].queue, groups[key].list
		table.sort(list, function(x, y) return x.entry.order < y.entry.order end) -- longest wait first
		local taken = {}
		local function match(x, y)
			taken[x.id], taken[y.id] = true, true
			mm.waiting[x.id], mm.waiting[y.id] = nil, nil
			table.insert(pairs, { a = x.id, b = y.id, queue = queue })
		end
		if queue ~= "RANKED" then
			local first = nil
			for _, x in list do
				if first then
					match(first, x)
					first = nil
				else
					first = x
				end
			end
		else
			local byRating = table.clone(list)
			table.sort(byRating, function(x, y)
				if x.entry.rating ~= y.entry.rating then return x.entry.rating < y.entry.rating end
				return x.entry.order < y.entry.order
			end)
			for i, x in byRating do x.at = i end
			for _, x in list do
				if not taken[x.id] then
					local reach = window(x.entry, now)
					local best, bestGap = nil, math.huge
					for _, step in { -1, 1 } do
						local j = x.at + step
						while byRating[j] do
							local y = byRating[j]
							local gap = math.abs(x.entry.rating - y.entry.rating)
							if gap > reach or gap >= bestGap then break end
							if not taken[y.id] and gap <= window(y.entry, now) then
								best, bestGap = y, gap
								break
							end
							j += step
						end
					end
					if best then match(x, best) end
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

-- RANKED in three categories (Wilhem: « plusieurs catégories de classement, 1v1 mais aussi
-- 2v2, 3v3 »): a team of 1, 2 or 3 fighters only meets the same size, and each size has its
-- own rating and its own board. 1v1 keeps `profile.rating` (the rank, the weekly champion,
-- the achievements read it); 2v2 and 3v3 live in `profile.ratings` ("2", "3": saved keys).
Matchmaker.CATEGORIES = { "1V1", "2V2", "3V3" }
Matchmaker.BOARDS = { "JeuxCombat_Classement_v1", "JeuxCombat_Classement_2v2_v1", "JeuxCombat_Classement_3v3_v1" }

local function category(size)
	return math.clamp(math.floor(tonumber(size) or 1), 1, 3)
end
Matchmaker.category = category

function Matchmaker.ratingOf(profile, size)
	size = category(size)
	if size == 1 then return tonumber(profile.rating) or Matchmaker.START_RATING end
	local ratings = profile.ratings
	local r = type(ratings) == "table" and tonumber(ratings[tostring(size)]) or nil
	return r or Matchmaker.START_RATING
end

-- Has this profile played this category yet (2v2 / 3v3 only reach a board once played)?
function Matchmaker.played(profile, size)
	size = category(size)
	if size == 1 then return true end
	return type(profile.ratings) == "table" and tonumber(profile.ratings[tostring(size)]) ~= nil
end

function Matchmaker.setRating(profile, size, value)
	size = category(size)
	value = math.max(0, math.floor(tonumber(value) or Matchmaker.START_RATING))
	if size == 1 then
		profile.rating = value
	else
		if type(profile.ratings) ~= "table" then profile.ratings = {} end
		profile.ratings[tostring(size)] = value
	end
end

function Matchmaker.rankName(rating)
	local name = Matchmaker.RANKS[1].name
	for _, rank in Matchmaker.RANKS do
		if rating >= rank.min then name = rank.name end
	end
	return name
end

return Matchmaker
