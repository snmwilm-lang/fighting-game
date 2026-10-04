-- Offline tests of the hub (src/server/Lobby.luau). Run from the repository root:
--   luau tests/Lobby.test.luau
local Lobby = require("../src/server/Lobby")
local Matchmaker = require("../src/server/Matchmaker")
local GameModes = require("../src/shared/GameModes")
local MoveData = require("../src/shared/MoveData")
local T = require("./TestKit")
local test, expect = T.test, T.expect

print("Lobby")

test("the first player fights the CPU, the next ones wait in the hub", function()
	local l = Lobby.new()
	expect(Lobby.join(l, 1, "WILHEM") == 1, "the first player has no slot")
	expect(Lobby.join(l, 2, "POTE") == 0, "the second player took a slot without a challenge")
	expect(l.slots[1] == 1 and l.slots[2] == nil, "slots " .. tostring(l.slots[1]) .. " " .. tostring(l.slots[2]))
	expect(Lobby.join(l, 2, "POTE") == 0 and #l.order == 2, "joining twice adds the player twice")
end)

test("a challenge accepted in time starts the 1v1 (challenger in slot 1)", function()
	local l = Lobby.new()
	Lobby.join(l, 1, "WILHEM")
	Lobby.join(l, 2, "POTE")
	expect(Lobby.challenge(l, 2, 1, 0), "the challenge was not sent")
	local status = Lobby.status(l)
	expect(status[1].from[1] == 2 and status[2].sent == 1, "the hub does not show the challenge")
	expect(not Lobby.accept(l, 2, 1, 1), "the challenger accepted its own challenge")
	expect(Lobby.accept(l, 1, 2, 5), "the challenge was not accepted")
	expect(l.slots[1] == 2 and l.slots[2] == 1, "slots after the accept")
	expect(next(l.challenges) == nil, "challenges left after the accept")
	expect(not Lobby.challenge(l, 1, 2, 6), "a challenge between two fighters already facing each other")
end)

test("a refused or expired challenge changes nothing", function()
	local l = Lobby.new()
	Lobby.join(l, 1, "A")
	Lobby.join(l, 2, "B")
	Lobby.challenge(l, 2, 1, 0)
	expect(Lobby.decline(l, 1, 2) and not Lobby.accept(l, 1, 2, 1), "accepted after a refusal")
	Lobby.challenge(l, 2, 1, 10)
	expect(not Lobby.accept(l, 1, 2, 10 + Lobby.CHALLENGE_SECONDS + 1), "accepted after the timeout")
	Lobby.expire(l, 10 + Lobby.CHALLENGE_SECONDS + 1)
	expect(next(l.challenges) == nil, "the expired challenge is still listed")
	expect(l.slots[1] == 1 and l.slots[2] == nil, "slots changed")
	expect(not Lobby.challenge(l, 1, 1, 0) and not Lobby.challenge(l, 1, 99, 0), "invalid challenges accepted")
end)

test("a third player can challenge a fighter: the other fighter goes back to the hub", function()
	local l = Lobby.new()
	Lobby.join(l, 1, "A")
	Lobby.join(l, 2, "B")
	Lobby.challenge(l, 2, 1, 0)
	Lobby.accept(l, 1, 2, 0)
	Lobby.join(l, 3, "C")
	expect(Lobby.challenge(l, 3, 1, 1) and Lobby.accept(l, 1, 3, 2), "the new 1v1 did not start")
	expect(l.slots[1] == 3 and l.slots[2] == 1 and Lobby.slotOf(l, 2) == 0, "B is still fighting")
end)

test("quit, play and leaving keep someone fighting when possible", function()
	local l = Lobby.new()
	Lobby.join(l, 1, "A")
	Lobby.join(l, 2, "B")
	expect(not Lobby.play(l, 2), "B took a slot while A plays")
	expect(Lobby.quit(l, 1) and l.slots[1] == nil, "A did not leave the fight")
	expect(Lobby.play(l, 2) and l.slots[1] == 2, "B could not play once nobody fights")
	Lobby.leave(l, 2)
	expect(l.slots[1] == 1, "A (waiting in the hub) did not take the free place")
	Lobby.challenge(l, 1, 3, 0) -- unknown player
	Lobby.join(l, 3, "C")
	Lobby.challenge(l, 3, 1, 0)
	Lobby.leave(l, 3)
	expect(next(l.challenges) == nil, "a challenge of a player who left is still pending")
end)

test("menu: requests are checked (mode, kits, team size, level, queue)", function()
	local kits = MoveData.KitOrder
	local ok = GameModes.validate({ mode = "VERSUS_CPU", team = { "KAI", "SHIN", "TARO" }, level = 4 }, kits)
	expect(ok and #ok.team == 3 and ok.level == 4, "a valid 3-fighter request was refused")
	expect(GameModes.validate({ mode = "VERSUS_CPU", team = { "KAI" }, level = 9 }, kits) == nil, "level 9 accepted")
	expect(GameModes.validate({ mode = "VERSUS_CPU", team = { "GOKU" }, level = 2 }, kits) == nil, "unknown kit accepted")
	local challenge = GameModes.validate({ mode = "CHALLENGE", team = { "KAI", "SHIN" } }, kits)
	expect(challenge and #challenge.team == 2, "CHALLENGE takes a team of 1 to 3")
	expect(GameModes.validate({ mode = "CHALLENGE", team = { "ASURA" } }, kits) == nil, "the boss can be picked")
	expect(GameModes.validate({ mode = "VERSUS", team = { "KAI" }, queue = "WHATEVER" }, kits) == nil, "unknown queue accepted")
	local four = GameModes.validate({ mode = "VERSUS", team = { "KAI", "SHIN", "TARO", "AKEMI" }, queue = "RANKED" }, kits)
	expect(four and #four.team == 3, "a team was not capped at 3")
	local survival = GameModes.validate({ mode = "SURVIVAL", team = { "KAI", "SHIN" } }, kits)
	expect(survival and #survival.team == 1, "SURVIE takes a single fighter")
	expect(GameModes.validate("hack", kits) == nil and GameModes.validate({ mode = "TRAINING" }, kits) == nil,
		"a request without a fighter was accepted")
end)

test("menu: SURVIE waves get harder, the CPU teams have different fighters", function()
	local kits = MoveData.KitOrder
	local _, first = GameModes.survivalOpponent(1, kits, 0)
	local _, later = GameModes.survivalOpponent(10, kits, 0)
	expect(first == 1 and later == 4, "levels " .. first .. " / " .. later)
	local team = GameModes.cpuTeam(3, kits, 5)
	expect(#team == 3 and team[1] ~= team[2] and team[2] ~= team[3] and team[1] ~= team[3], "CPU team with doubles")
end)

test("matchmaking: NORMAL pairs by waiting order, CLASSÉ by close ratings, widening with time", function()
	local mm = Matchmaker.new()
	Matchmaker.enqueue(mm, 1, "NORMAL", 1000, 0)
	Matchmaker.enqueue(mm, 2, "RANKED", 1000, 0)
	Matchmaker.enqueue(mm, 3, "NORMAL", 1600, 1)
	Matchmaker.enqueue(mm, 4, "RANKED", 1500, 1)
	local pairs = Matchmaker.pair(mm, 1)
	expect(#pairs == 1 and pairs[1].queue == "NORMAL" and pairs[1].a == 1 and pairs[1].b == 3, "NORMAL pairing")
	expect(Matchmaker.waitingIn(mm, "RANKED") == 2, "far ratings were paired at once")
	-- 500 points apart: paired once both waited long enough ((500 - 100) / 25 = 16 s).
	expect(#Matchmaker.pair(mm, 10) == 0, "paired too early")
	local late = Matchmaker.pair(mm, 18)
	expect(#late == 1 and late[1].queue == "RANKED", "never paired after waiting")
	-- The closest rating wins.
	Matchmaker.enqueue(mm, 5, "RANKED", 1000, 20)
	Matchmaker.enqueue(mm, 6, "RANKED", 1090, 20)
	Matchmaker.enqueue(mm, 7, "RANKED", 1010, 20)
	local close = Matchmaker.pair(mm, 20)
	expect(#close == 1 and close[1].a == 5 and close[1].b == 7, "the closest opponent was not chosen")
	Matchmaker.leave(mm, 6)
	expect(Matchmaker.waitingIn(mm, "RANKED") == 0, "leaving did not remove the player")
end)

test("ranking: Elo moves points from the loser to the winner, more for an upset", function()
	local a, b = Matchmaker.elo(1000, 1000, 1)
	expect(a == 1016 and b == 984, "even match: " .. a .. " / " .. b)
	local upset = Matchmaker.elo(1000, 1400, 1)
	local expected = Matchmaker.elo(1400, 1000, 1)
	expect(upset - 1000 > expected - 1400, "an upset should win more points")
	local d1, d2 = Matchmaker.elo(1200, 1200, 0.5)
	expect(d1 == 1200 and d2 == 1200, "a draw between equals changed the ratings")
	expect(Matchmaker.rankName(950) == "SILVER" and Matchmaker.rankName(1750) == "LEGEND", "rank names")
end)

test("matchmaking: only teams of the same size meet (1v1, 2v2, 3v3)", function()
	local mm = Matchmaker.new()
	Matchmaker.enqueue(mm, 1, "NORMAL", 1000, 0, 3)
	Matchmaker.enqueue(mm, 2, "NORMAL", 1000, 0, 1)
	expect(#Matchmaker.pair(mm, 1) == 0, "a team of 3 met a team of 1")
	Matchmaker.enqueue(mm, 3, "NORMAL", 1000, 2, 3)
	local pairs = Matchmaker.pair(mm, 3)
	expect(#pairs == 1 and pairs[1].a == 1 and pairs[1].b == 3, "the two teams of 3 were not paired")
	expect(Matchmaker.waitingIn(mm, "NORMAL") == 1, "the solo player left the queue")
end)

test("CHALLENGE: the reward follows how ASURA was beaten", function()
	expect(GameModes.challengeGrade(false, 1, 1) == 0, "a defeat gave a grade")
	local c, titleC, unlock = GameModes.challengeGrade(true, 3, 0.1)
	expect(c == 1 and titleC ~= nil and unlock, "a win with 3 fighters: grade C, a title, the style")
	expect(GameModes.challengeGrade(true, 2, 0.1) == 2, "a win with 2 fighters: grade B")
	expect(GameModes.challengeGrade(true, 1, 0.2) == 3, "a win alone: grade A")
	local s, titleS = GameModes.challengeGrade(true, 1, 0.6)
	expect(s == 4 and titleS == "ASURA", "alone with half the health left: grade S and the ASURA title")
end)

test("10000 players: the search pairs them fast and right, each hub view stays short and shows its challenges", function()
	local mm = Matchmaker.new()
	local seed = 7
	local function rand()
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	local info = {}
	for id = 1, 10000 do
		local queue = if id % 2 == 0 then "RANKED" else "NORMAL"
		local rating, size = 500 + math.floor(rand() * 1500), 1 + id % 3
		info[id] = { queue = queue, rating = rating, size = size }
		Matchmaker.enqueue(mm, id, queue, rating, 0, size)
	end
	local t = os.clock()
	local pairs = Matchmaker.pair(mm, 0)
	expect(os.clock() - t < 1, string.format("pairing 10000 players took %.2f s", os.clock() - t))
	local seen = {}
	for _, p in pairs do
		local a, b = info[p.a], info[p.b]
		expect(not seen[p.a] and not seen[p.b], "a player paired twice")
		seen[p.a], seen[p.b] = true, true
		expect(a.queue == b.queue and a.size == b.size and a.queue == p.queue, "mixed queues or team sizes")
		if p.queue == "RANKED" then
			expect(math.abs(a.rating - b.rating) <= Matchmaker.BASE_WINDOW, "ranked gap over the window")
		end
	end
	expect(#pairs > 4500, "only " .. #pairs .. " pairs")
	-- hub views
	local lobby = Lobby.new()
	for id = 1, 10000 do Lobby.join(lobby, id, "P" .. id) end
	Lobby.challenge(lobby, 9000, 9999, 0)
	Lobby.challenge(lobby, 5, 9999, 0)
	local list = Lobby.status(lobby)
	local byId = Lobby.index(list)
	local view, total = Lobby.view(list, 9999, nil, byId)
	expect(total == 10000 and #view == Lobby.VIEW_LIMIT, "view of " .. #view .. " of " .. total)
	local ids = {}
	for _, e in view do ids[e.id] = true end
	expect(ids[9999] and ids[9000] and ids[5], "the player or its challengers are missing from its view")
	t = os.clock()
	for id = 1, 10000 do Lobby.view(list, id, nil, byId) end
	expect(os.clock() - t < 1, string.format("10000 views took %.2f s", os.clock() - t))
end)

test("languages: the game is in English, every move, fighter text and menu line has its French (Locale)", function()
	local Locale = require("../src/shared/Locale")
	local CharacterData = require("../src/shared/CharacterData")
	local missing = {}
	local function need(text)
		if type(text) == "string" and string.find(text, "%a") and not Locale.SAME[text] and Locale.translate(text, "FR") == text then
			table.insert(missing, text)
		end
	end
	for _, m in MoveData.Moves do
		need(m.name)
	end
	for _, kit in MoveData.Kits do
		need(kit.Description)
		need(kit.Role)
		if kit.Passive then need(kit.Passive.Name) end
		for _, r in kit.FullRoutes do need(r.name) end
	end
	for _, mode in GameModes.List or {} do need(mode.description) end
	-- whole lines, format lines and lines built from pieces
	expect(Locale.translate("ROUTE CLEARED · CLEAN ✓", "FR") == "ROUTE RÉUSSIE · PROPRE ✓", "a whole line")
	expect(Locale.translate("You need 3 ki bars (you have 1): turn ULTIMATES: ON at the top", "FR")
		== "Il faut 3 barres de ki (tu en as 1) : active ULTIMES : ON en haut", "a format line")
	expect(Locale.translate("FIGHTER: KAI (T)", "FR") == "PERSO : KAI (T)", "a line built from pieces")
	expect(Locale.translate("DRAGON FIST", "EN") == "DRAGON FIST" and Locale.translate("DRAGON FIST", "AUTO") == "DRAGON FIST",
		"English or Roblox's translation change nothing")
	-- the source is English: no French left in the moves' names
	for id, m in MoveData.Moves do
		expect(not string.find(m.name or "", "[\195\197]"), id .. " is still French: " .. tostring(m.name))
	end
	local list = {}
	for i = 1, math.min(#missing, 8) do list[i] = missing[i] end
	expect(#missing == 0, #missing .. " texts without French: " .. table.concat(list, " | "))
	local _ = CharacterData
end)

test("every fighter is good at something and pays for it, and no two play alike (POWER, SPEED, RANGE, DEFENSE, MOBILITY)", function()
	local ratings = GameModes.ratings(MoveData, MoveData.KitOrder)
	local seen = {}
	for _, name in MoveData.KitOrder do
		local r = ratings[name]
		local plus, minus = GameModes.traits(r)
		expect(#plus >= 1, name .. " is the best at nothing")
		expect(#minus >= 1, name .. " has no weakness")
		local key = table.concat({ r.POWER, r.SPEED, r.RANGE, r.DEFENSE, r.MOBILITY }, "")
		expect(not seen[key], name .. " plays like " .. tostring(seen[key]))
		seen[key] = name
	end
	-- the roles read in the numbers: GORAN tanks, VENOM is fast, RAIJIN reaches far, AKEMI moves; KAZAN's claws
	-- press (fast, middle range: never a whip's reach); KUROEN rushes in (mobility) with a classic defence
	expect(ratings.GORAN.DEFENSE == 5 and ratings.VENOM.SPEED == 5 and ratings.RAIJIN.RANGE == 5 and ratings.AKEMI.MOBILITY == 5,
		"a fighter does not read like its role")
	expect(ratings.KAZAN.SPEED >= 4 and ratings.KAZAN.RANGE <= 3, "KAZAN's claws do not read as pressure")
	expect(ratings.KUROEN.MOBILITY >= 4 and ratings.KUROEN.DEFENSE <= 3 and ratings.KUROEN.SPEED >= 3, "KUROEN does not read as a rushdown")
end)

test("stages: six complete stages on the same ground, chosen in the menu or drawn, checked by the server", function()
	local Maps = require("../src/shared/Maps")
	local ids, names = {}, {}
	local function hexColor(c) return type(c) == "string" and string.match(c, "^%x%x%x%x%x%x$") ~= nil end
	for _, map in Maps.LIST do
		expect(not ids[map.id] and not names[map.name], map.id .. " is twice")
		ids[map.id], names[map.name] = true, true
		expect(#map.sky >= 4 and #map.hills == 3, map.id .. ": sky or hills missing")
		for _, band in map.sky do expect(hexColor(band[2]), map.id .. ": bad sky colour") end
		for _, key in { "color", "worn", "trim", "line" } do expect(hexColor(map.floor[key]), map.id .. ": bad floor " .. key) end
		expect(type(map.floor.material) == "string" and hexColor(map.light) and hexColor(map.mist), map.id .. ": floor, light or mist")
		expect(map.air and #map.air.colors == 2 and map.air.rate > 0, map.id .. ": no particles")
		local l = map.lighting
		expect(l.clock >= 0 and l.clock < 24 and l.brightness > 0 and l.density >= 0 and l.density <= 1, map.id .. ": lighting")
		expect(map.kanji and map.props, map.id .. ": no kanji or set dressing")
	end
	expect(#Maps.LIST >= 6, "only " .. #Maps.LIST .. " stages")
	expect(Maps.pick("FROZEN", 3) == "FROZEN" and ids[Maps.pick(nil, 7)] and ids[Maps.pick("NOWHERE", 2)], "picking a stage")
	local drawn = {}
	for seed = 1, 60 do drawn[Maps.pick(nil, seed)] = true end
	local n = 0
	for _ in drawn do n += 1 end
	expect(n == #Maps.LIST, "RANDOM never draws some stages")
	local kits = MoveData.KitOrder
	local ok = GameModes.validate({ mode = "VERSUS_CPU", team = { "KAI" }, level = 2, map = "NEON" }, kits, Maps.BY_ID)
	expect(ok and ok.map == "NEON", "a stage asked in the menu is dropped")
	local random = GameModes.validate({ mode = "VERSUS_CPU", team = { "KAI" }, level = 2, map = "RANDOM" }, kits, Maps.BY_ID)
	expect(random and random.map == nil, "RANDOM is not drawn by the server")
	expect(GameModes.validate({ mode = "VERSUS_CPU", team = { "KAI" }, level = 2, map = "MOON BASE" }, kits, Maps.BY_ID) == nil,
		"an unknown stage is accepted")
end)

test("every fighter wears its own styles: each style of its list exists and is its own (never KAI's by mistake)", function()
	local CharacterData = require("../src/shared/CharacterData")
	local kits = table.clone(MoveData.KitOrder)
	table.insert(kits, "ASURA")
	for _, kit in kits do
		local order = CharacterData.StyleOrder[kit]
		expect(order ~= nil and #order >= 1, kit .. " has no styles")
		for _, name in order or {} do
			local style = CharacterData.Skins[name]
			expect(style ~= nil, kit .. "'s style " .. name .. " does not exist")
			expect(style == nil or style.Kit == kit, kit .. "'s style " .. name .. " is " .. tostring(style and style.Kit) .. "'s")
		end
		local first = CharacterData.Skins[CharacterData.defaultStyle(kit, nil)]
		expect(first and first.Kit == kit, kit .. " starts in someone else's look")
	end
	for name, style in CharacterData.Skins do
		expect(style.Skin == name, "the style " .. name .. " is filed under another name (" .. tostring(style.Skin) .. ")")
	end
end)

test("achievements: each says where it is earned, reads the saved profile, and is in French", function()
	local Locale = require("../src/shared/Locale")
	local ids, modes = {}, {}
	for _, mode in GameModes.List do modes[mode.name] = true end
	for _, a in GameModes.ACHIEVEMENTS do
		expect(not ids[a.id], "two achievements " .. a.id)
		ids[a.id] = true
		local mode = string.match(a.where, "^(.-) · RANKED$") or a.where
		expect(modes[mode], a.name .. ": earned in an unknown mode " .. a.where)
		expect(a.goal > 0 and type(a.stat) == "string", a.name .. ": no goal")
		for _, text in { a.name, a.where, a.how } do
			expect(Locale.translate(text, "FR") ~= text or Locale.SAME[text], a.name .. ": no French for " .. text)
		end
	end
	local none, zero = GameModes.achievements({})
	expect(zero == 0 and #none == #GameModes.ACHIEVEMENTS, "a new player has achievements")
	local list, done = GameModes.achievements({ achWins = 12, achSurvival = 5, achAsuraGrade = 2, achAsuraDamage = 80, achRating = 1000 })
	expect(done == 6, "wins 12, survival 5, ASURA beaten with 2: 6 achievements, got " .. done)
	for _, a in list do
		if a.id == "VETERAN" then expect(not a.done and a.value == 12 and a.goal == 50, "the progress is not shown") end
	end
	-- A new season resets every player's achievements, never their points, wins or rewards.
	local old = { rating = 1800, wins = 70, asuraGrade = 4, title = "ASURA", achSeason = GameModes.ACHIEVEMENT_SEASON - 1,
		achWins = 70, achRating = 1800, achSurvival = 20, achAsuraDamage = 100, achAsuraGrade = 4 }
	expect(GameModes.achievementSeason(old), "an old season's profile was not reset")
	local _, after = GameModes.achievements(old)
	expect(after == 0, "achievements kept after the reset: " .. after)
	expect(old.rating == 1800 and old.wins == 70 and old.asuraGrade == 4 and old.title == "ASURA", "the reset touched the points or rewards")
	expect(not GameModes.achievementSeason(old), "reset twice in the same season")
	GameModes.achievementProgress(old, { won = true })
	GameModes.achievementProgress(old, { rating = 1310 })
	local again
	_, again = GameModes.achievements(old)
	expect(again == 2, "after the reset, a win and 1310 points give FIRST WIN and RISING STAR, got " .. again)
	local legacy = { wins = 5 } -- (saved before the seasons: no achSeason)
	GameModes.achievementSeason(legacy)
	expect(legacy.achWins == 0 and legacy.achSeason == GameModes.ACHIEVEMENT_SEASON, "an old save is not reset")
end)

T.finish()
