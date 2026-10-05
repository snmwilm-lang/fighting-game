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

test("shop styles: two per fighter, locked until bought with coins, the price checked", function()
	local CharacterData = require("../src/shared/CharacterData")
	local count = 0
	for name, item in CharacterData.SHOP do
		count += 1
		local style = CharacterData.Skins[name]
		expect(style and style.Kit == item.kit, name .. " is not its fighter's style")
		expect(table.find(CharacterData.StyleOrder[item.kit], name) ~= nil, name .. " is missing from " .. item.kit .. "'s styles")
		expect(item.coins > 0 and style.SkinTone ~= nil, name .. " has no price or no skin tone")
	end
	expect(count == 2 * 20, "expected 2 shop styles for each of the 20 fighters, got " .. count)
	local profile = { coins = 1000, ownedSkins = {} }
	expect(not CharacterData.canWear("KAI GOLD", profile), "a shop style is worn without being bought")
	expect(CharacterData.canWear("CLASSIC", profile) and not CharacterData.canWear("AWAKENED", profile), "free / earned styles are wrong")
	local price = CharacterData.SHOP["KAI GOLD"].coins
	local ok, why = CharacterData.buy(profile, "KAI GOLD")
	expect(not ok and why == "coins" and profile.coins == 1000, "bought without enough coins")
	profile.coins = price + 5
	expect(CharacterData.buy(profile, "KAI GOLD") and profile.coins == 5 and CharacterData.canWear("KAI GOLD", profile), "a purchase failed")
	ok, why = CharacterData.buy(profile, "KAI GOLD")
	expect(not ok and why == "owned" and profile.coins == 5, "a style was paid twice")
	expect(not CharacterData.buy(profile, "CLASSIC") and not CharacterData.buy(profile, "NOPE"), "a free or unknown style was sold")
	expect(not CharacterData.buy({ coins = -1 }, "KAI GOLD"), "a debt bought a style")
	-- (an old profile without the field)
	expect(not CharacterData.canWear("KAI GOLD", { coins = 0 }), "a profile without ownedSkins wears a shop style")
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

test("currencies: coins earned by playing (the winner more), crystals from achievements, rank from the rating", function()
	local profile = { rating = 1234 }
	GameModes.addCoins(profile, "win")
	GameModes.addCoins(profile, "loss")
	GameModes.addCoins(profile, "survivalWin", 3)
	local c = GameModes.COINS
	expect(profile.coins == c.win + c.loss + c.survivalWin * 3, "coins badly counted: " .. tostring(profile.coins))
	expect(c.win > c.draw and c.draw > c.loss and c.loss > 0, "the winner does not earn more (or a loss earns nothing)")
	local status = { coins = profile.coins, rating = 1234, achWins = 9999 }
	local _, done = GameModes.achievements(status)
	local wallet = GameModes.wallet(status)
	expect(wallet.coins == profile.coins and wallet.rank == 1234, "the wallet does not read the profile")
	expect(done > 0 and wallet.crystals == done * GameModes.CRYSTALS_PER_ACHIEVEMENT, "crystals do not follow the achievements")
	expect(GameModes.wallet(nil).coins == 0, "an empty profile breaks the wallet")
	-- the reward chips (a number inside) read in French too
	local Locale = require("../src/shared/Locale")
	for en, fr in { ["WIN +" .. c.win] = "VICTOIRE +" .. c.win, ["+" .. c.survivalWin .. " / OPPONENT"] = "+" .. c.survivalWin .. " / ADVERSAIRE",
		["ELO POINTS"] = "POINTS ELO" } do
		expect(Locale.translate(en, "FR") == fr, en .. " -> " .. Locale.translate(en, "FR"))
	end
end)

test("saves: never an unloaded profile, one write per player every 7 s at most, batches, urgent on leave, board only on change", function()
	local SaveQueue = require("../src/server/SaveQueue")
	local q = SaveQueue.new()
	-- a profile that never loaded (DataStore down) is never written, even urgently
	SaveQueue.mark(q, 1, 0)
	expect(#SaveQueue.due(q, 100, false) == 0 and #SaveQueue.due(q, 100, true) == 0, "an unloaded profile would be written over")
	SaveQueue.loaded(q, 1)
	expect(SaveQueue.due(q, 100, false)[1] == 1, "a loaded dirty profile is not written")
	SaveQueue.writing(q, 1, 100)
	SaveQueue.mark(q, 1, 101)
	expect(#SaveQueue.due(q, 103, false) == 0, "written twice within the gap (Roblox: 6 s per key)")
	expect(SaveQueue.due(q, 100 + SaveQueue.MIN_GAP, false)[1] == 1, "not written after the gap")
	expect(SaveQueue.due(q, 102, true)[1] == 1, "leaving does not write right away")
	-- a failed write is retried
	SaveQueue.writing(q, 1, 200)
	SaveQueue.failed(q, 1, 200)
	expect(SaveQueue.isDirty(q, 1), "a failed write is forgotten")
	-- a full server: at most BATCH per flush, the oldest first
	local big = SaveQueue.new()
	for id = 1, 50 do
		SaveQueue.loaded(big, id)
		SaveQueue.mark(big, id, 1000 - id)
	end
	local batch = SaveQueue.due(big, 2000, false)
	expect(#batch == SaveQueue.BATCH and batch[1] == 50, "a flush bursts past the budget or not the oldest first")
	expect(#SaveQueue.due(big, 2000, true) == 50, "closing the server does not write everyone")
	-- the leaderboard only when the rating changed
	expect(SaveQueue.boardChanged(q, 1, 1000) and not SaveQueue.boardChanged(q, 1, 1000) and SaveQueue.boardChanged(q, 1, 1016),
		"the leaderboard is written for nothing")
	expect(SaveQueue.retryDelay(1) == 1 and SaveQueue.retryDelay(3) == 4, "load retries do not back off")
	SaveQueue.forget(q, 1)
	expect(not SaveQueue.isLoaded(q, 1), "a player who left is kept")
end)

test("cross-server RANKED: one initiator per pair, same size, close ratings, atomic claim, fresh entries; session lock", function()
	local G = require("../src/server/GlobalQueue")
	local now = 1000
	local a = G.entry(1, 1200, 1, "jobA", now - 20, { "KAI" }, now)
	local b = G.entry(2, 1250, 1, "jobB", now - 10, { "TARO" }, now)
	local far = G.entry(3, 1900, 1, "jobC", now - 10, { "SHIN" }, now)
	local trio = G.entry(4, 1210, 3, "jobD", now - 10, { "KAI", "TARO", "SHIN" }, now)
	local list = { a, b, far, trio }
	expect(G.pick(a, list, now) == b, "the closest opponent of the same size is not picked")
	expect(G.pick(b, list, now) == nil, "both servers would claim the same pair (b waited less: a initiates)")
	expect(G.pick(trio, list, now) == nil, "a team of 3 meets a single fighter")
	-- the claim is atomic: the second one fails
	local claimed = G.claim(b, "code1", "jobA", now)
	expect(claimed and claimed.claim.code == "code1", "the claim did not take")
	expect(G.claim(claimed, "code2", "jobZ", now) == nil, "an entry was claimed twice")
	expect(G.pick(a, { a, claimed }, now) == nil, "a claimed entry is picked again")
	-- a stale entry (its server stopped refreshing it) is ignored
	local stale = G.entry(5, 1201, 1, "jobE", now - 100, { "KAI" }, now - G.STALE - 1)
	expect(G.pick(a, { a, stale }, now) == nil, "a stale entry is picked")
	-- the window widens with the wait: nobody waits forever
	local early = G.entry(6, 1200, 1, "jobF", now - 1, { "KAI" }, now)
	local gapped = G.entry(7, 1600, 1, "jobG", now, { "KAI" }, now)
	expect(G.pick(early, { early, gapped }, now) == nil, "a 400-point gap meets at once")
	early.since, gapped.since = now - 30, now - 29
	expect(G.pick(early, { early, gapped }, now) == gapped, "the window never widens")
	-- the reserved server waits for both, gives up after the timeout
	local pending = { expect = { 1, 2 }, created = now }
	expect(not G.arrival(pending, 1, now) and G.arrival(pending, 2, now + 3), "the match starts before both arrived")
	expect(G.expired({ expect = { 1, 2 }, created = now }, now + G.ARRIVE_TIMEOUT + 1), "a reserved server waits forever")
	-- session lock: another server's fresh lock blocks, a stale one or our own does not
	expect(G.canLock(nil, "jobA", now) and G.canLock({ rating = 1 }, "jobA", now), "a fresh profile cannot be locked")
	expect(not G.canLock({ _session = { job = "jobB", t = now - 5 } }, "jobA", now), "two servers hold the same profile")
	expect(G.canLock({ _session = { job = "jobB", t = now - G.LOCK_TTL - 1 } }, "jobA", now), "a crashed server's lock is never taken over")
	expect(G.canLock({ _session = { job = "jobA", t = now - 5 } }, "jobA", now), "a server is locked out of its own profile")
	local stamped = G.stamp({ rating = 1 }, "jobA", now, false)
	expect(stamped._session.job == "jobA" and G.stamp({ rating = 1 }, "jobA", now, true)._session == nil, "the lock is not written or released")
end)

test("anti-cheat: forged packets kick, a real player never does; no farming (short matches, the same pair, daily cap)", function()
	local AC = require("../src/server/AntiCheat")
	local ac = AC.new()
	-- forged packets: kicked after a few
	local kicked = false
	for i = 1, 5 do kicked = AC.flag(ac, 1, "malformed", i * 0.1) or kicked end
	expect(kicked and #ac.log == 1, "five forged packets in a row do not kick")
	-- a real player: a few dropped packets (a 144 Hz client mashing) never count as a flood
	local drops, flooded = {}, false
	for i = 1, 100 do flooded = AC.dropped(drops, 5 + i / 1000) or flooded end
	expect(not flooded, "a hundred dropped packets in a second count as a flood")
	for i = 1, 200 do flooded = AC.dropped(drops, 6 + i / 1000) or flooded end
	expect(flooded, "a gross flood is not seen")
	-- and a rare oddity now and then never adds up to a kick (the points fade)
	local never = true
	for t = 1, 3600 do
		if t % 60 == 0 and AC.flag(ac, 2, "flood", t) then never = false end
	end
	expect(never and AC.score(ac, 2, 3600) < AC.KICK, "rare oddities over an hour kick a real player")
	-- token bucket
	local b = {}
	local passed = 0
	for i = 1, 100 do if AC.bucket(b, 0, 10, 20) then passed += 1 end end
	expect(passed == 20 and AC.bucket(b, 1, 10, 20), "the bucket lets a burst through or never refills")
	-- farming: a match too short pays nothing
	local profile = {}
	expect(AC.share(profile, 99, AC.MIN_MATCH - 1, 0).coins == 0, "a 10-second match pays")
	-- the same opponent again and again: less, then nothing
	local time = 1000000
	for _ = 1, AC.REPEAT_SOFT do AC.record(profile, 99, time) end
	local soft = AC.share(profile, 99, 60, time)
	expect(soft.coins > 0 and soft.coins < 1 and soft.rating < 1, "the same pair keeps full gains")
	for _ = AC.REPEAT_SOFT + 1, AC.REPEAT_HARD do AC.record(profile, 99, time) end
	expect(AC.share(profile, 99, 60, time).rating == 0, "two alts farm rating forever")
	expect(AC.share(profile, 99, 60, time + 86400).rating == 1, "the count never resets the next day")
	expect(AC.share(profile, 42, 60, time).coins == 1, "another opponent is punished")
	for id = 1, 50 do AC.record(profile, 1000 + id, time + id) end
	local n = 0
	for _ in profile.recentOpp do n += 1 end
	expect(n <= AC.RECENT_LIMIT, "the opponent list grows without end")
	-- no daily cap (Wilhem): every real match pays, the day's total is only counted
	local p2 = {}
	local got = 0
	for _ = 1, 100 do got += AC.capCoins(p2, 150, time) end
	expect(got == 15000 and p2.coinToday == 15000 and AC.capCoins(p2, -5, time) == 0, "coins are capped (or go negative)")
	-- both must really play: an AFK alt (or a still bot) pays nothing, to either side
	expect(AC.share({}, 7, 90, time, 300, 3).coins == 0 and AC.share({}, 7, 90, time, 2, 300).rating == 0, "an idle player's match pays")
	expect(AC.share({}, 7, 90, time, 300, 250).coins == 1, "a real match is punished")
	expect(AC.scaleRating(1000, 1016, 0.25) == 1004 and AC.scaleRating(1000, 984, 0.25) == 996, "the rating share is wrong")
end)

test("taunts: predefined only, a slot number of the saved wheel, 5 s server cooldown, two players at once, six saved, locked ones", function()
	local Taunts = require("../src/shared/Taunts")
	-- the list: the 12 asked, unique ids, nothing free-text
	local seen = {}
	for _, t in Taunts.LIST do
		expect(not seen[t.id], "duplicate taunt id " .. t.id)
		seen[t.id] = true
		expect(type(t.text) == "string" and #t.text > 0 and #t.text <= 24, t.id .. ": text missing or too long for a bubble")
	end
	for _, text in { "EZ 😂", "BOZO 🤡", "TOO SLOW 💀", "CRY ABOUT IT 😭", "SKILL ISSUE", "BRO???", "YOU GOOD? 💀", "RUN IT BACK",
		"NICE TRY", "LOL", "SIT DOWN", "WHAT WAS THAT?!" } do
		local found = false
		for _, t in Taunts.LIST do found = found or t.text == text end
		expect(found, "missing taunt " .. text)
	end
	-- (7) the six equipped are kept as saved (order, no duplicate, unknown / locked dropped, defaults fill)
	local profile = { wins = 0 }
	local wheel = Taunts.sanitize({ "lol", "bozo", "lol", "hacked text", 42, "eclipse", "sitdown", "cry", "what", "ez", "slow" }, profile)
	expect(#wheel == Taunts.SLOTS and wheel[1] == "lol" and wheel[2] == "bozo" and wheel[3] == "sitdown",
		"the saved wheel is not kept as chosen: " .. table.concat(wheel, ","))
	expect(not table.find(wheel, "eclipse"), "a locked taunt went on the wheel")
	expect(#Taunts.sanitize(nil, profile) == Taunts.SLOTS, "an empty profile has no wheel")
	expect(Taunts.unlocked("eclipse", { shinGrade = 1 }) and not Taunts.unlocked("eclipse", {}), "unlocks do not follow the profile")
	-- (4) the cooldown, checked on the server's clock: spam is refused, forged slots too
	local a, b = {}, {}
	local mine = Taunts.sanitize(nil, profile)
	expect(Taunts.request(a, mine, 1, 100) == "ez", "a taunt is refused")
	local sent = 0
	for t = 100.1, 104.9, 0.1 do if Taunts.request(a, mine, 2, t) then sent += 1 end end
	expect(sent == 0, sent .. " taunts got through the 5 s cooldown")
	expect(Taunts.request(a, mine, 2, 105) == "bozo", "the cooldown never ends")
	for _, forged in { 0, 7, 1.5, -1, 0 / 0, math.huge, "1", { 1 } } do
		local id, why = Taunts.request({}, mine, forged, 1000)
		expect(id == nil and why == "malformed", "a forged slot was accepted: " .. tostring(forged))
	end
	-- (1) two players at the same moment: each has their own cooldown, both bubbles go out
	expect(Taunts.request(b, mine, 3, 100) == "slow" and Taunts.request({}, mine, 4, 100) ~= nil, "two players cannot taunt at once")
	expect(Taunts.cooldownLeft(100, 102) == 3 and Taunts.cooldownLeft(nil, 0) == 0, "the wheel's cooldown display is wrong")
end)

test("taunts never touch the fight: a taunt sent while attacking changes nothing in the simulation", function()
	-- (2) the taunt travels in the input packet but never enters the simulation's input
	local Config = require("../src/shared/CombatConfig")
	local MoveData = require("../src/shared/MoveData")
	local Sim = require("../src/shared/CombatSimulation")
	local function play(withTaunt)
		local w = Sim.newWorld(Config, MoveData, false)
		Sim.setKits(w, "KAI", "TARO")
		w.phase = "Fight"
		w.fighters[1].x, w.fighters[2].x = -1.5, 1.5
		for t = 1, 90 do
			local i1 = Sim.neutralInput()
			i1.light = t % 6 == 1
			if withTaunt and t == 3 then i1.taunt = 2 end
			Sim.step(w, { i1, Sim.neutralInput() })
		end
		local f, d = w.fighters[1], w.fighters[2]
		return string.format("%.4f %.4f %d %d %s", f.x, d.x, f.hp, d.hp, tostring(f.move))
	end
	expect(play(false) == play(true), "a taunt changed the fight")
end)

test("economy, styles, quests and titles: every new menu line reads in French", function()
	local Locale = require("../src/shared/Locale")
	local Quests = require("../src/shared/Quests")
	local lines = { "◀ DRAG TO TURN ▶", "★ FAVORITE", "★ YOUR FAVORITE", "▶ TRY IN TRAINING (FREE)", "UNLOCK · 4000", "UNLOCK", "BUY",
		"EQUIP", "✓ WORN", "EARNED", "BEAT KUROEN SHIN", "BEAT ASURA", "QUEST · OWNED", "QUEST · Win 5 matches with RYUKEN",
		"✓ FREE FIGHTER", "✓ UNLOCKED · YOURS FOREVER", "DEVELOPER ACCESS · NOT BOUGHT", "🔒 LOCKED · 4000 COINS · YOU HAVE 120",
		"FREE TRIAL", "NOT ENOUGH COINS · SHIN COSTS 4000 (YOU HAVE 120) · TRY IT IN TRAINING",
		"UNLOCK SHIN FOR 4000 COINS?\nYou have 5000 coins. It stays yours forever.", "NOT ENOUGH COINS · THIS STYLE COSTS 2500 (YOU HAVE 10)",
		"BUY THE STYLE KAI GOLD FOR 2500 COINS?\nYou have 3000 coins.", "SHIN IS LOCKED · UNLOCK IT FIRST", "SHIN UNLOCKED · YOURS FOREVER",
		"QUEST COMPLETE · NEW STYLE: KAI INFERNO", "👑 CHAMPION OF THE WEEK · TITLE WEEKLY CHAMPION (SETTINGS › TITLE)", "QUESTS",
		"3 / 8 DONE", "DONE", "TITLE SHOWN", "DEVELOPER ACCESS", "NONE YET", "HIDDEN", "ON · ALL FIGHTERS", "OFF · NEW PLAYER",
		"ACHIEVEMENTS · QUESTS · YOUR PROGRESS", "NOT POSSIBLE: FIGHTER LOCKED: SHIN (TRAINING ONLY)", "NOT POSSIBLE: THIS STYLE IS A QUEST REWARD",
		"NOT POSSIBLE: ALREADY OWNED", "NOT POSSIBLE: FIGHTER NOT FOR SALE", "WEEKLY CHAMPION", "CANCEL",
		"⚙ TOOLS ▾", "⚙ TOOLS ▴", "FIGHTER", "TRAINING", "DISPLAY",
		"ALL TIME", "WEEKLY", "TAKE FREE (2 LEFT)", "TAKE", "HOLD L3 TO LEAVE",
		"NOTIFICATIONS", "Nothing yet: rewards, quests, unlocks and challenges show up here.", "NO TITLE SHOWN", "RANK GOLD · 1320 PTS",
		"THIS WEEK: 12 PTS", "8 W / 3 L · WIN RATE 73/100", "FAVORITE: KAI", "FIGHTERS: 11 / 20", "ACHIEVEMENTS: 4 · QUESTS: 2 / 8",
		"BEST SURVIVAL: 6", "COINS: 4200", "UPDATE", "SHOP · QUESTS · WEEKLY", "HISTORY", "YOUR LAST 10 MATCHES",
		"⚔ REMATCH (LAST ONLINE OPPONENT)", "No match yet: your fights show up here.", "WIN", "LOSS", "VS CPU",
		"KAI  vs  Bob (TARO)  ·  ONLINE · RANKED", "+150 COINS", "📖 MOVES", "PASSIVE: RAGE", "MOVES", "ULTIMATES", "⚔ REMATCH",
		"NOT POSSIBLE: YOUR OPPONENT IS NOT ON THIS SERVER ANY MORE", "REMATCH SENT TO Bob · THEY ACCEPT IN THEIR BANNER",
		"LIGHT 1  ·  DRAGON FIST  ·  62 dmg  ·  9 f", "Looking on every server…",
		"Match RANKED · 0:12\n2 player(s) searching on this server · your rank: GOLD (1320 pts)\nLooking on every server…\n\nTIP: A win online pays 150 coins, a loss 50.",
		"TAKE SHIN FOR FREE?\nThank you for testing: 3 free fighter(s) left to pick.", "NOT POSSIBLE: NO FREE PICK LEFT", "YOU: 12 PTS THIS WEEK · win 3, draw 1 · from zero every Monday",
		"No points yet this week: win online matches (the ranking is kept in the published game)." }
	for _, q in Quests.LIST do
		table.insert(lines, q.name)
		table.insert(lines, q.how)
	end
	for _, line in lines do
		local fr = Locale.translate(line, "FR")
		expect(fr ~= line or Locale.SAME[line], "no French for: " .. line)
		expect(not string.find(fr, "%%[ds]"), "a format left in: " .. fr)
	end
end)

test("economy: PvP 150 / 50, 8 free fighters, 4000 to unlock, kept forever, TRAINING tries them all", function()
	local Economy = require("../src/shared/Economy")
	local AC = require("../src/server/AntiCheat")
	expect(Economy.pvpCoins("win") == 150 and Economy.pvpCoins("loss") == 50 and Economy.pvpCoins("left") == 0, "the PvP rewards are wrong")
	expect(GameModes.COINS.win == Economy.WIN and GameModes.COINS.loss == Economy.LOSS, "two economies disagree")
	-- a real match pays in full; the anti-farm still applies (short match, the same pair)
	local now = 1e9
	local p = { coins = 0, recentOpp = {} }
	local share = AC.share(p, 42, 90, now)
	local gain = AC.capCoins(p, math.floor(Economy.pvpCoins("win") * share.coins + 0.5), now)
	expect(gain == 150, "a win paid " .. gain)
	expect(AC.share(p, 42, 10, now).coins == 0, "a 10 s match pays")
	expect(AC.share(p, 43, 90, now, 400, 5).coins == 0, "a win against an AFK alt pays")
	-- 8 free of 20, all of them real fighters
	expect(#Economy.FREE == 8, "not 8 free fighters")
	for _, kit in Economy.FREE do expect(table.find(MoveData.KitOrder, kit) ~= nil, kit .. " is not a fighter") end
	local fresh = { coins = 0 }
	local locked = 0
	for _, kit in MoveData.KitOrder do
		if not Economy.owns(fresh, kit) then locked += 1 end
		expect(Economy.canPlay(fresh, kit, "TRAINING", false), kit .. " cannot be tried in TRAINING")
	end
	expect(locked == 12, locked .. " fighters locked instead of 12")
	-- buying: price, no debt, once, a boss or an unknown name never sold
	local buyer = { coins = 3999 }
	local ok, why = Economy.buyFighter(buyer, "AKEMI", MoveData.KitOrder)
	expect(not ok and why == "coins" and buyer.coins == 3999, "bought without the coins")
	buyer.coins = 4100
	expect(Economy.buyFighter(buyer, "AKEMI", MoveData.KitOrder) and buyer.coins == 100, "the purchase of AKEMI failed")
	ok, why = Economy.buyFighter(buyer, "AKEMI", MoveData.KitOrder)
	expect(not ok and why == "owned" and buyer.coins == 100, "AKEMI was paid twice")
	expect(not Economy.buyFighter({ coins = 99999 }, "ASURA", MoveData.KitOrder), "a boss was sold")
	expect(not Economy.buyFighter({ coins = 99999 }, "KAI", MoveData.KitOrder), "a free fighter was sold")
	expect(Economy.canPlay(buyer, "AKEMI", "VERSUS", false), "a bought fighter is not playable")
	-- training never unlocks: still locked in every other mode
	expect(not Economy.canPlay(fresh, "KUROEN", "VERSUS", false) and not Economy.canPlay(fresh, "KUROEN", "VERSUS_CPU", false),
		"a locked fighter is playable out of training")
	local allowed, which = Economy.teamAllowed(fresh, { "KAI", "SHIN" }, "VERSUS", false)
	expect(not allowed and which == "SHIN", "a team with a locked fighter passes")
end)

test("testers: an old profile (or one that had the free picks) gets every fighter, never written as bought; a new one none", function()
	local Economy = require("../src/shared/Economy")
	local old = { coins = 120, wins = 4 } -- (saved before the fighters were sold: no ownedKits)
	local p = { coins = 120, ownedKits = {} }
	expect(Economy.makeTester(p, old) and p.tester == true, "an old profile is not a tester")
	expect(not Economy.makeTester(p, old), "made a tester twice")
	for _, kit in MoveData.KitOrder do
		expect(Economy.canPlay(p, kit, "VERSUS", false) and Economy.canPlay(p, kit, "RANKED", false), kit .. " is locked for a tester")
	end
	expect(next(p.ownedKits) == nil and p.coins == 120, "the tester's fighters were written as bought (or coins taken)")
	expect(not Economy.buyFighter(p, "SHIN", MoveData.KitOrder), "a tester paid for a fighter")
	-- a tester of v0.19 (the 3 picks given, ownedKits saved) gets them all too
	local picked = { ownedKits = { SHIN = true } }
	expect(Economy.makeTester(picked, { ownedKits = { SHIN = true }, picksGiven = true }) and Economy.owns(picked, "NOVA"),
		"a tester who had the picks is still limited")
	expect(not Economy.makeTester({}, { ownedKits = {} }) and not Economy.makeTester({}, nil), "a new player became a tester")
	expect(not Economy.owns({ tester = "yes" }, "NOVA"), "a forged tester field unlocks fighters")
	local fresh = { freePicks = 1, ownedKits = {} }
	expect(Economy.claimFighter(fresh, "NOVA", MoveData.KitOrder) and not Economy.claimFighter({ freePicks = 3 }, "KAI", MoveData.KitOrder),
		"the old picks are broken")
end)

test("developer access: listed ids or the game's owner, never Studio's test players, never written as bought, can be off", function()
	local Economy = require("../src/shared/Economy")
	local CharacterData = require("../src/shared/CharacterData")
	local Dev = require("../src/server/DevAccess")
	expect(Dev.isDev(777, 777, true) and not Dev.isDev(778, 777, true), "the owner of the game is not the only one")
	expect(not Dev.isDev(-1, -1, true) and not Dev.isDev(-2, 777, true), "a Studio test player got the access")
	expect(not Dev.isDev(777, 777, false), "a group game trusts its group id as a player")
	-- Roblox Studio, place not published (owner 0) or a group's: the account playing alone has it
	expect(Dev.isDev(4242, 0, true, true) and Dev.isDev(4242, 99, false, true), "Studio's lone player (the editor) has no access")
	expect(not Dev.isDev(4242, 0, true, false), "a Studio test with several players gave the access")
	expect(not Dev.isDev(-1, 0, true, true), "a Studio test player (negative id) got the access")
	table.insert(Dev.IDS, 555)
	expect(Dev.isDev(555, 777, true), "a listed id has no access")
	table.remove(Dev.IDS)
	local profile = { coins = 0, devOff = false }
	local dev = Dev.active(Dev.isDev(777, 777, true), profile)
	for _, kit in MoveData.KitOrder do expect(Economy.canPlay(profile, kit, "VERSUS", dev), kit .. " locked for the developer") end
	expect(CharacterData.canWear("KUROEN BLOOD MOON", profile, dev) or CharacterData.Skins["KUROEN BLOOD MOON"] == nil, "a style refused")
	expect(CharacterData.canWear("AKEMI GOLD", profile, dev), "a shop style refused to the developer")
	expect(profile.ownedKits == nil and profile.ownedSkins == nil, "the developer access wrote purchases")
	profile.devOff = true
	expect(not Dev.active(true, profile) and not Economy.canPlay(profile, "SHIN", "VERSUS", Dev.active(true, profile)),
		"the access cannot be switched off")
end)

test("styles: 2500 coins, quest styles not sold, equipped style kept only while it is yours", function()
	local CharacterData = require("../src/shared/CharacterData")
	local Quests = require("../src/shared/Quests")
	for name, item in CharacterData.SHOP do
		expect(item.coins == 2500, name .. " costs " .. item.coins)
		expect(item.quest == (Quests.BY_REWARD[name] ~= nil), name .. ": quest mark and quest list disagree")
	end
	for _, q in Quests.LIST do
		expect(CharacterData.SHOP[q.reward] ~= nil and CharacterData.QUEST[q.reward], q.id .. "'s reward " .. q.reward .. " is not a quest style")
	end
	local p = { coins = 99999 }
	local ok, why = CharacterData.buy(p, "KAI INFERNO")
	expect(not ok and why == "quest" and p.coins == 99999, "a quest style was sold")
	-- equip: worn only if it is the fighter's and still yours
	p.equipped = { KAI = "KAI GOLD" }
	expect(CharacterData.styleFor("KAI", p, nil, false) == "CLASSIC", "an unbought style is worn")
	CharacterData.buy(p, "KAI GOLD")
	expect(CharacterData.styleFor("KAI", p, nil, false) == "KAI GOLD", "the equipped style is not worn")
	expect(CharacterData.styleFor("KAI", p, "KAI GOLD", false) ~= "KAI GOLD", "both slots wear the same style")
	p.equipped.TARO = "KAI GOLD"
	expect(CharacterData.Skins[CharacterData.styleFor("TARO", p, nil, false)].Kit == "TARO", "TARO wears KAI's style")
end)

test("quests: counted, saved in the profile, rewarded once with an existing style", function()
	local Quests = require("../src/shared/Quests")
	local CharacterData = require("../src/shared/CharacterData")
	local p = {}
	for _ = 1, 9 do Quests.record(p, { won = false, pvp = true, kits = { "KAI" } }) end
	expect(#Quests.grant(p) == 0, "rewarded before the goal")
	Quests.record(p, { won = true, pvp = true, kits = { "RYUKEN", "RYUKEN" } })
	local given = Quests.grant(p)
	expect(#given == 1 and given[1] == "KAI INFERNO" and p.ownedSkins["KAI INFERNO"], "PLAY10 did not give its style")
	expect(#Quests.grant(p) == 0, "a reward was given twice")
	expect(p.quests.kitWins.RYUKEN == 1 and p.quests.pvpWins == 1, "the counters are wrong (a fighter twice in the team counts once)")
	for _ = 1, 4 do Quests.record(p, { won = true, pvp = false, kits = { "RYUKEN" } }) end
	given = Quests.grant(p)
	expect(table.find(given, "RYUKEN PHANTOM") ~= nil and CharacterData.canWear("RYUKEN PHANTOM", p), "the RYUKEN quest did not unlock its style")
	expect(p.quests.pvpWins == 1, "a CPU win counted as an online win")
	-- saved: the counters live in the profile (a plain table the DataStore keeps)
	local copy = { quests = table.clone(p.quests), ownedSkins = table.clone(p.ownedSkins) }
	expect(Quests.value(copy, Quests.BY_ID.PLAY10) == 14 and #Quests.grant(copy) == 0, "a saved profile loses its progress")
	local shown = Quests.list(p)
	expect(#shown == #Quests.LIST and shown[1].done and shown[1].value == shown[1].goal, "the menu list is wrong")
end)

test("weekly champion: written once per week, title given once, not for sale, history kept", function()
	local C = require("../src/server/Champions")
	local monday = 4 * 86400 + 100 * 7 * 86400
	expect(C.week(monday) == 100 and C.week(monday - 1) == 99 and C.week(monday + 6 * 86400) == 100, "the week turns at the wrong time")
	local history = C.record(nil, 99, { id = 7, name = "ALICE", rating = 2100 })
	expect(history and #history == 1, "the first champion was not written")
	expect(C.record(history, 99, { id = 8, name = "BOB", rating = 2200 }) == nil, "a second server wrote the same week again")
	history = C.record(history, 100, { id = 7, name = "ALICE", rating = 2150 })
	expect(#history == 2, "the history is not kept")
	local p = { title = "", titles = {} }
	expect(not C.canShow(p, C.TITLE), "the title can be shown without winning")
	expect(C.grant(p, 7, history) == 2 and table.find(p.titles, C.TITLE), "the champion did not get the title")
	expect(C.grant(p, 7, history) == 0 and #p.titles == 1, "the title was given twice")
	expect(C.grant({}, 8, history) == 0, "someone else got the title")
	expect(C.canShow(p, C.TITLE) and C.canShow(p, "") and not C.canShow(p, "GOD SLAYER"), "titles not owned can be shown")
	-- WEEKLY ranking: points of the week, from zero on a new week, scaled by the anti-farm share
	local w = {}
	expect(C.addPoints(w, 100, "win", 1) == 3 and C.addPoints(w, 100, "draw", 1) == 4 and C.addPoints(w, 100, "loss", 1) == 4,
		"the weekly points are wrong")
	expect(C.addPoints(w, 100, "win", 0.25) == 5, "the anti-farm share does not scale the points")
	expect(C.pointsOf(w, 100) == 5 and C.pointsOf(w, 101) == 0, "last week's points show this week")
	expect(C.addPoints(w, 101, "win", 1) == 3, "the points do not start again on Monday")
	local long = nil
	for w = 1, C.KEEP + 10 do long = C.record(long, w, { id = w, name = "P", rating = 1 }) end
	expect(#long == C.KEEP and long[1].week == 11, "the history grows without end")
end)

test("store: one config, ids to fill (0 = not sold yet), passes cosmetic, prices and kinds coherent", function()
	local Config = require("../src/shared/StoreConfig")
	local Store = require("../src/shared/Store")
	local CharacterData = require("../src/shared/CharacterData")
	local Taunts = require("../src/shared/Taunts")
	local idx = Store.index(Config)
	local keys, ids = {}, {}
	local function checkId(entry, what)
		expect(type(entry.id) == "number" and entry.id >= 0 and entry.id % 1 == 0, what .. " has no valid id (0 until created)")
		expect(type(entry.robux) == "number" and entry.robux > 0, what .. " has no Robux price shown")
		expect(not keys[entry.key], "two entries share the key " .. entry.key)
		keys[entry.key] = true
		if entry.id > 0 then
			expect(not ids[entry.id], "two entries share the id " .. entry.id)
			ids[entry.id] = true
		end
		expect(not entry.random, what .. " is a paid random item (no loot box)")
	end
	for _, p in Config.PASSES do
		checkId(p, "pass " .. p.key)
		expect(#p.perks > 0, p.key .. " lists no perk")
		-- a pass never touches the fight: only these fields are allowed
		for field in p do
			expect(table.find({ "key", "id", "robux", "name", "color", "perks", "coinBonus", "badge", "nameColor", "title", "taunt" }, field),
				"pass " .. p.key .. " has an unknown perk field: " .. field)
		end
		if p.taunt then expect(Taunts.BY_ID[p.taunt] and Taunts.BY_ID[p.taunt].unlock.pass == p.key, p.key .. "'s emote is not its own") end
	end
	expect(idx.pass.VIP and idx.pass.DOUBLE and idx.pass.SUPPORTER, "VIP, DOUBLE REWARDS and SUPPORTER are missing")
	for _, p in Config.PRODUCTS do
		checkId(p, "product " .. p.key)
		expect((p.coins ~= nil) ~= (p.style ~= nil), p.key .. " must give coins or a style")
		if p.style then
			local item = CharacterData.SHOP[p.style]
			expect(item and not item.quest, p.key .. " sells " .. p.style .. ": not a shop style, or a quest reward")
		end
	end
	local seen = {}
	for _, item in Config.ITEMS do
		expect(not seen[item.id] and table.find(Config.KINDS, item.kind), item.id .. " is twice or of an unknown kind")
		seen[item.id] = true
		expect(item.soon or item.pass or (type(item.coins) == "number" and item.coins > 0), item.id .. " has no price")
		if item.pass then expect(idx.pass[item.pass], item.id .. " needs an unknown pass") end
		if item.kind == "EMOTE" then
			local t = Taunts.BY_ID[item.taunt]
			expect(t and (t.unlock.item == item.id or t.unlock.pass == item.pass), item.id .. " is not its taunt's unlock")
		end
		if item.kind == "VFX" then expect(#item.colors == 2, item.id .. " needs two colours") end
	end
	for _, f in Config.FEATURED do
		local ok = (f.kind == "pass" and idx.pass[f.key]) or (f.kind == "product" and idx.product[f.key]) or (f.kind == "item" and idx.item[f.key])
		expect(ok, "FEATURED shows an unknown " .. f.kind .. " " .. f.key)
	end
	-- a Robux purchase only with a real id and a known policy
	expect(not Store.canPrompt({ id = 0 }, {}) and not Store.canPrompt({ id = 5 }, nil) and Store.canPrompt({ id = 5 }, {}),
		"a purchase can start without an id or a policy")
	expect(not Store.canPrompt({ id = 5, random = true }, { randomRestricted = true }), "a paid random item passes a restricting policy")
end)

test("store: pass bonuses on fight coins only, added up, capped at x2.25; badges and pass items follow the pass", function()
	local Config = require("../src/shared/StoreConfig")
	local Store = require("../src/shared/Store")
	local idx = Store.index(Config)
	local p = { coins = 0 }
	expect(Store.coinMultiplier(Config, p) == 1 and Store.fightCoins(Config, 150, p) == 150, "a bonus without a pass")
	Store.setPass(p, "VIP", true)
	expect(Store.fightCoins(Config, 150, p) == 188, "VIP is not +25 %: " .. Store.fightCoins(Config, 150, p))
	Store.setPass(p, "DOUBLE", true)
	expect(Store.coinMultiplier(Config, p) == 2.25 and Store.fightCoins(Config, 100, p) == 225, "VIP + DOUBLE is not x2.25")
	Store.setPass(p, "VIP", false)
	expect(Store.fightCoins(Config, 50, p) == 100 and Store.fightCoins(Config, 0, p) == 0 and Store.fightCoins(Config, -5, p) == 0,
		"DOUBLE alone is not x2 (or a negative gain)")
	-- the cap holds whatever passes are added later
	local big = table.clone(Config)
	big.PASSES = table.clone(Config.PASSES)
	table.insert(big.PASSES, { key = "MEGA", coinBonus = 5 })
	Store.setPass(p, "VIP", true)
	Store.setPass(p, "MEGA", true)
	expect(Store.coinMultiplier(big, p) == Config.MAX_COIN_MULTIPLIER, "the cap does not hold")
	-- a coin pack never gets the bonus
	expect(Store.grantReceipt(p, "R1", idx.product.COINS_1000, 1) == "granted" and p.coins == 1000, "a coin pack got the pass bonus")
	-- badges and the pass's own items
	local s = { passes = { SUPPORTER = true } }
	expect(table.concat(Store.badges(Config, s), ",") == "SUPPORTER", "the SUPPORTER badge")
	expect(Store.ownsItem(idx, s, "EMOTE_RESPECT") and Store.passTitle(idx, s, "SUPPORTER"), "SUPPORTER's emote / title")
	expect(not Store.ownsItem(idx, {}, "EMOTE_RESPECT") and not Store.passTitle(idx, {}, "SUPPORTER"), "a pass item without the pass")
	expect(not Store.buyItem(idx, { coins = 99999 }, "VFX_VIP_GOLD"), "a VIP item was sold for coins")
	local Taunts = require("../src/shared/Taunts")
	expect(Taunts.unlocked("respect", s) and not Taunts.unlocked("respect", {}), "the SUPPORTER emote is not tied to the pass")
	expect(table.find(Taunts.sanitize({ "respect" }, s), "respect") and not table.find(Taunts.sanitize({ "respect" }, {}), "respect"),
		"the wheel keeps a pass emote without the pass")
	-- setPass reports changes only
	expect(Store.setPass(s, "SUPPORTER", true) == false and Store.setPass(s, "SUPPORTER", false) == true and not Store.hasPass(s, "SUPPORTER"),
		"setPass does not report its changes")
end)

test("store: receipts granted once (retries, a second server, a reconnection), never lost, the ledger bounded", function()
	local Config = require("../src/shared/StoreConfig")
	local Store = require("../src/shared/Store")
	local idx = Store.index(Config)
	local p = { coins = 10, ownedSkins = {} }
	expect(Store.grantReceipt(p, "A", idx.product.COINS_3000, 100) == "granted" and p.coins == 3010, "a pack was not granted")
	for _ = 1, 5 do
		expect(Store.grantReceipt(p, "A", idx.product.COINS_3000, 101) == "duplicate", "a retried receipt was granted again")
	end
	expect(p.coins == 3010, "coins given twice: " .. p.coins)
	-- the ledger travels with the saved profile: a reload (reconnection, another server) still knows it
	local function copy(t)
		local out = {}
		for k, v in t do out[k] = if type(v) == "table" then copy(v) else v end
		return out
	end
	local reloaded = copy(p)
	expect(Store.grantReceipt(reloaded, "A", idx.product.COINS_3000, 500) == "duplicate" and reloaded.coins == 3010,
		"a reloaded profile granted the receipt again")
	-- a save that failed: the server answers NotProcessedYet, the profile that was not written
	-- did not keep it, so Roblox's retry grants it (once) on the profile actually loaded
	local unsaved = copy(reloaded)
	Store.grantReceipt(unsaved, "B", idx.product.COINS_1000, 600)
	expect(Store.grantReceipt(reloaded, "B", idx.product.COINS_1000, 700) == "granted" and reloaded.coins == 4010, "a lost save lost the purchase")
	-- a Robux style
	expect(Store.grantReceipt(p, "C", idx.product.SKIN_KAI_GOLD, 102) == "granted" and p.ownedSkins["KAI GOLD"], "the style was not given")
	expect(Store.grantReceipt(p, "C", idx.product.SKIN_KAI_GOLD, 103) == "duplicate", "the style receipt twice")
	-- bad receipts
	expect(Store.grantReceipt(p, "", idx.product.COINS_1000, 1) == "unknown" and Store.grantReceipt(p, "D", nil, 1) == "unknown"
		and Store.grantReceipt(p, "E", { key = "X" }, 1) == "unknown" and p.coins == 3010, "a bad receipt gave something")
	-- bounded ledger, the newest kept
	local q = { coins = 0 }
	for i = 1, Store.KEEP_RECEIPTS + 30 do Store.grantReceipt(q, "R" .. i, idx.product.COINS_1000, i) end
	local n = 0
	for _ in q.receipts do n += 1 end
	expect(n == Store.KEEP_RECEIPTS and q.receipts["R" .. (Store.KEEP_RECEIPTS + 30)] and not q.receipts.R1, "the ledger is not bounded: " .. n)
end)

test("store: cosmetics bought once with coins, equipped only when owned, unequipped, a lost pass removes its look", function()
	local Config = require("../src/shared/StoreConfig")
	local Store = require("../src/shared/Store")
	local idx = Store.index(Config)
	local p = { coins = 1000, titles = {} }
	local ok, why = Store.buyItem(idx, p, "TITLE_UNTOUCHABLE")
	expect(not ok and why == "coins" and p.coins == 1000, "bought without enough coins")
	p.coins = 5000
	expect(Store.buyItem(idx, p, "TITLE_UNTOUCHABLE") and p.coins == 3500 and table.find(p.titles, "UNTOUCHABLE"), "a title purchase failed")
	ok, why = Store.buyItem(idx, p, "TITLE_UNTOUCHABLE")
	expect(not ok and why == "owned" and p.coins == 3500 and #p.titles == 1, "a title paid twice")
	ok, why = Store.buyItem(idx, p, "VICTORY_THRONE")
	expect(not ok and why == "soon" and p.coins == 3500, "a COMING SOON item was sold")
	expect(not Store.buyItem(idx, p, "NOPE") and not Store.buyItem(idx, nil, "VFX_FROST"), "an unknown item was sold")
	-- equip
	ok, why = Store.equip(idx, p, "VFX", "VFX_FROST")
	expect(not ok and why == "locked" and Store.auraColors(idx, p) == "", "an aura not owned was equipped")
	expect(Store.buyItem(idx, p, "VFX_FROST") and Store.equip(idx, p, "VFX", "VFX_FROST"), "an owned aura cannot be equipped")
	expect(Store.equipped(idx, p, "VFX") == "VFX_FROST" and Store.auraColors(idx, p) == "BFEFFF,4FB8FF", "the aura worn")
	expect(not Store.equip(idx, p, "VFX", "TITLE_UNTOUCHABLE") and not Store.equip(idx, p, "HEALTH", "VFX_FROST"), "a wrong kind equipped")
	expect(Store.equip(idx, p, "VFX", "") and Store.equipped(idx, p, "VFX") == nil, "unequip failed")
	expect(not Store.equip(idx, p, "VICTORY", "VICTORY_THRONE"), "a COMING SOON victory was equipped")
	-- the VIP aura: only with VIP, gone with the pass
	p.passes = { VIP = true }
	expect(Store.equip(idx, p, "VFX", "VFX_VIP_GOLD") and Store.auraColors(idx, p) ~= "", "the VIP aura with VIP")
	Store.setPass(p, "VIP", false)
	expect(Store.equipped(idx, p, "VFX") == nil and Store.auraColors(idx, p) == "", "the VIP aura stays without the pass")
	-- a forged save field never makes an item owned
	expect(not Store.ownsItem(idx, { ownedItems = "all" }, "VFX_FROST") and not Store.ownsItem(idx, { ownedItems = { VICTORY_THRONE = true } }, "VICTORY_THRONE"),
		"a forged profile owns items")
end)

test("store: every SHOP line, item, perk and message reads in French", function()
	local Locale = require("../src/shared/Locale")
	local Config = require("../src/shared/StoreConfig")
	local Taunts = require("../src/shared/Taunts")
	local lines = { "SHOP", "FEATURED", "COSMETICS", "GAME PASSES", "SKINS", "TITLES", "EMOTES", "AURAS", "VICTORY",
		"THE BEST OF THE SHOP · COSMETICS AND COINS ONLY: NO ADVANTAGE IN A FIGHT", "COINS AND STYLES FOR ROBUX · ROBLOX CONFIRMS EVERY PURCHASE",
		"PERMANENT · RESTORED EVERY TIME YOU JOIN · BONUSES ON FIGHT COINS ONLY (AT MOST x2.25)",
		"A title shown over your fighter and in the lobby (SETTINGS › TITLE too).", "A taunt for your wheel (TAUNTS page): EQUIP puts it on the wheel.",
		"Recolours your fighter's aura in fights, seen by everyone. Cosmetic only.", "Victory animations are being made: they come in a later update.",
		"FIGHT COINS x2.25", "SOON", "COMING SOON", "COMING SOON · NOT ON SALE YET", "COMING SOON · IN A LATER UPDATE",
		"PURCHASES NOT AVAILABLE YET · YOUR SAVE IS LOADING", "ROBLOX PURCHASE WINDOW…", "✓ OWNED · ACTIVE", "SOON · R$ 299",
		"+3000 coins at once. Pass bonuses never apply to Robux purchases.", "A style for KAI · GOLD. Cosmetic only. Also in FIGHTERS.",
		"✓ EQUIPPED", "UNEQUIP", "✓ OWNED", "QUEST", "🔒 2500 COINS", "BUY 2500", "WITH THE VIP PASS", "SEE THE PASS",
		"NOT ENOUGH COINS · BREAKER COSTS 4000 (YOU HAVE 10)", "BUY BREAKER FOR 4000 COINS?\nYou have 5000 coins.", "GAME PASS · PERMANENT",
		"+3000 COINS", "ON YOUR TAUNT WHEEL", "PURCHASE COMPLETE · VIP PASS", "GAME PASSES · COSMETICS · COINS",
		"NOT POSSIBLE: ONLY WITH ITS GAME PASS", "NOT POSSIBLE: NOT FOR SALE", "NOT POSSIBLE: YOUR SAVE IS NOT LOADED YET",
		"NOT POSSIBLE: NOT AVAILABLE FOR YOUR ACCOUNT", "NOT POSSIBLE: COMING SOON", "✓ TESTER · EVERY FIGHTER", "Permanent. No advantage in a fight." }
	for _, p in Config.PASSES do
		table.insert(lines, p.name)
		for _, perk in p.perks do table.insert(lines, perk) end
	end
	for _, p in Config.PRODUCTS do
		if p.name then table.insert(lines, p.name) end
		if p.tag then table.insert(lines, p.tag) end
	end
	for _, item in Config.ITEMS do table.insert(lines, item.name) end
	for _, t in Taunts.LIST do
		table.insert(lines, t.text)
		if t.unlock and t.unlock.how then table.insert(lines, t.unlock.how) end
	end
	for _, line in lines do
		local fr = Locale.translate(line, "FR")
		expect(fr ~= line or Locale.SAME[line], "no French for: " .. line)
		expect(not string.find(fr, "%%[ds]"), "a format left in: " .. fr)
	end
end)

test("daily reward: once a day, more each day in a row over 7 days, a missed day starts again, in French", function()
	local Economy = require("../src/shared/Economy")
	local Locale = require("../src/shared/Locale")
	local p = { coins = 0 }
	local day = Economy.dayOf(1700000000)
	expect(Economy.claimDaily(p, day) == Economy.DAILY[1] and p.dailyStreak == 1, "day 1")
	expect(Economy.claimDaily(p, day) == nil and p.coins == Economy.DAILY[1], "claimed twice the same day")
	local total = p.coins
	for d = 2, 7 do
		local coins, streak = Economy.claimDaily(p, day + d - 1)
		expect(coins == Economy.DAILY[d] and streak == d, "day " .. d .. " of the series")
		total += coins
	end
	expect(p.coins == total, "coins of the series")
	local coins, streak = Economy.claimDaily(p, day + 7)
	expect(streak == 1 and coins == Economy.DAILY[1], "the series does not start again after 7 days")
	coins, streak = Economy.claimDaily(p, day + 10)
	expect(streak == 1, "a missed day keeps the series")
	expect(Economy.claimDaily(p, day + 9) == nil, "a clock gone backwards pays again")
	expect(Economy.claimDaily(nil, day) == nil, "no profile")
	for _, line in { "DAILY REWARD", "DAY 3 · +200 COINS", "DAY 3", "DAILY REWARD · DAY 3 · +200 COINS",
		"Come back every day: the reward grows for 7 days in a row. A day missed starts again at day 1.",
		"Hold BACK (away from the opponent) to guard, down-back for lows; F works too. Grabs and overheads (forward + R) go through.",
		"+5 ON HIT", "-10 ON BLOCK", "HOLD BACK TO GUARD",
		"HOW TO PLAY", "DAILY STREAK: 3 / 7", "🔥 4 WINS IN A ROW", "⬆ RANK UP · GOLD", "⬇ RANK DOWN · SILVER", "WIN STREAK: 2 · BEST 7", "MOVE: A/Q · D (stick on gamepad and mobile) · JUMP: SPACE · DASH: SHIFT",
		"GUARD: hold BACK (away from the opponent). DOWN-BACK guards the lows (sweeps). F / RB guard too.",
		"Grabs and overheads (forward + R) go through the guard: mix them in to open a turtle.",
		"ATTACK: LEFT CLICK (light) · RIGHT CLICK (heavy) · E: special. Each press after the previous blow comes out: a CLEAN combo.",
		"ULTIMATES: R once the ki bars are full · C: the FATAL BLOW when the opponent is low.",
		"TRAINING is free with every fighter: the frame advantage (+3 ON HIT, -5 ON BLOCK) tells who has the turn.",
		"Online wins pay coins: unlock fighters and styles (FIGHTERS, SHOP). Come back every day for the DAILY REWARD.",
		"Like every fighting game: hold BACK (away from the opponent) to guard, DOWN-BACK against lows. F / RB still work.",
		"Walking back, the guard comes up by itself when an attack is near.",
		"DAILY REWARD: come back every day, 7 days in a row for more coins. New lobby and fight music.",
		"TRAINING: the frame advantage of each exchange (+3 ON HIT, -5 ON BLOCK...): who has the turn, what can be punished." } do
		expect(Locale.translate(line, "FR") ~= line, "no French for: " .. line)
	end
end)

test("win streak: counted wins in a row, a loss or leaving ends it, a draw or an uncounted match changes nothing", function()
	local Economy = require("../src/shared/Economy")
	local p = {}
	for _ = 1, 3 do Economy.streak(p, "win", true) end
	expect(p.winStreak == 3 and p.bestStreak == 3, "three wins")
	expect(Economy.streak(p, "draw", true) == 3 and Economy.streak(p, "win", false) == 3 and Economy.streak(p, "loss", false) == 3,
		"a draw or an uncounted match moved the streak")
	expect(Economy.streak(p, "loss", true) == 0 and p.bestStreak == 3, "a loss did not end it (or the best was lost)")
	Economy.streak(p, "win", true)
	expect(Economy.streak(p, "left", false) == 0, "leaving did not end it")
end)

T.finish()
