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

-- Wilhem: « affiche tous les titres obtenables et comment en petit en dessous, un design
-- différent pour chaque titre ».
test("titles: every title the game gives is listed with how to get it (in French too) and its own look", function()
	local Locale = require("../src/shared/Locale")
	local StoreConfig = require("../src/shared/StoreConfig")
	local catalog = GameModes.titleCatalog(StoreConfig.ITEMS)
	local byName, looks = {}, {}
	for _, t in catalog do
		expect(not byName[t.name], t.name .. " listed twice")
		byName[t.name] = t
		expect(type(t.how) == "string" and #t.how > 10, t.name .. " does not say how to get it")
		expect(Locale.translate(t.how, "FR") ~= t.how, t.name .. ": how to get it has no French")
		expect(GameModes.TITLE_LOOKS[t.name] ~= nil, t.name .. " has no look of its own")
		local key = t.look.kanji .. t.look.colors[1] .. t.look.colors[2]
		expect(not looks[key], t.name .. " looks like " .. tostring(looks[key]))
		looks[key] = t.name
	end
	local granted = { "WEEKLY CHAMPION" }
	for _, n in GameModes.CHALLENGE_TITLES do table.insert(granted, n) end
	for _, n in GameModes.SHIN_TITLES do table.insert(granted, n) end
	for _, item in StoreConfig.ITEMS do if item.kind == "TITLE" then table.insert(granted, item.name) end end
	for _, n in granted do expect(byName[n] ~= nil, n .. " can be earned but is not in the TITLES window") end
end)

-- Wilhem: « certains titres shop devraient être obtenables avec des conditions cohérentes à leur nom ».
test("shop titles are also earned by a feat that matches their name; the shop still sells them", function()
	local StoreConfig = require("../src/shared/StoreConfig")
	local Moves = MoveData.Moves
	local fatalId = MoveData.Kits.KAI.Ultimates.Fatal
	for _, item in StoreConfig.ITEMS do
		if item.kind == "TITLE" and not item.pass then
			expect(GameModes.TITLE_FEATS[item.name] ~= nil, item.name .. " can only be bought")
			expect(item.coins and item.coins > 0, item.name .. " is not sold any more")
		end
	end
	local p = { titles = {} }
	-- seen from slot 1: the opponent's feats never count for us
	GameModes.featEvent(p, { kind = "Hit", attacker = 2, combo = 30 }, 1, Moves)
	GameModes.featEvent(p, { kind = "GuardBreak", attacker = 2 }, 1, Moves)
	expect(#GameModes.grantFeatTitles(p) == 0, "the opponent's combo or guard break gave us a title")
	-- COMBO ARTIST: a 20-hit combo
	GameModes.featEvent(p, { kind = "Hit", attacker = 1, combo = 19 }, 1, Moves)
	expect(#GameModes.grantFeatTitles(p) == 0, "COMBO ARTIST before 20 hits")
	GameModes.featEvent(p, { kind = "Hit", attacker = 1, combo = 20 }, 1, Moves)
	local got = GameModes.grantFeatTitles(p)
	expect(#got == 1 and got[1] == "COMBO ARTIST", "COMBO ARTIST not earned by a 20-hit combo")
	expect(#GameModes.grantFeatTitles(p) == 0, "a title given twice")
	-- BREAKER: 25 guard breaks; NO MERCY: 5 FATAL BLOW finishes; UNTOUCHABLE: 3 PERFECT rounds
	for _ = 1, 25 do GameModes.featEvent(p, { kind = "GuardBreak", attacker = 1 }, 1, Moves) end
	for _ = 1, 5 do GameModes.featEvent(p, { kind = "Hit", attacker = 1, combo = 1, ko = true, move = fatalId }, 1, Moves) end
	GameModes.featEvent(p, { kind = "Hit", attacker = 1, combo = 1, ko = true, move = "Jab" }, 1, Moves) -- (a jab K.O. is no FATAL)
	for _ = 1, 3 do GameModes.featEvent(p, { kind = "RoundEnd", winner = 1, perfect = true }, 1, Moves) end
	for _ = 1, 10 do GameModes.featEvent(p, { kind = "PromptGrade", attacker = 1, grade = "PERFECT" }, 1, Moves) end
	got = GameModes.grantFeatTitles(p)
	expect(table.concat(got, ",") == "BREAKER,FRAME PERFECT,NO MERCY,UNTOUCHABLE", "feats gave: " .. table.concat(got, ","))
	expect(p.feats.fatalKO == 5, "a jab K.O. counted as a FATAL BLOW finish")
	-- FINAL BOSS: both bosses beaten
	p.asuraGrade = 1
	GameModes.featBosses(p)
	expect(#GameModes.grantFeatTitles(p) == 0, "FINAL BOSS with one boss beaten")
	p.shinGrade = 2
	GameModes.featBosses(p)
	got = GameModes.grantFeatTitles(p)
	expect(#got == 1 and got[1] == "FINAL BOSS", "FINAL BOSS not earned by beating both bosses")
	expect(GameModes.featProgress({}, "COMBO ARTIST") == 0 and GameModes.featProgress({}, "WEEKLY CHAMPION") == nil, "feat progress")
	-- bought, then earned: the feat upgrades it (its star); bought only: no star
	local buyer = { titles = { "BREAKER" } }
	expect(GameModes.titleDisplay(buyer, "BREAKER") == "BREAKER", "a bought title shows a star")
	expect(GameModes.titleDisplay(p, "BREAKER") == "BREAKER ★", "an earned title has no star")
	for _ = 1, 25 do GameModes.featEvent(buyer, { kind = "GuardBreak", attacker = 1 }, 1, Moves) end
	got = GameModes.grantFeatTitles(buyer)
	expect(#got == 1 and #buyer.titles == 1 and GameModes.titleDisplay(buyer, "BREAKER") == "BREAKER ★",
		"earning a bought title did not give it its star (or listed it twice)")
	expect(GameModes.titleDisplay(p, "WEEKLY CHAMPION") == "WEEKLY CHAMPION" and GameModes.titleDisplay(p, "") == "",
		"a title without feat gets a star")
end)

-- Wilhem: « plusieurs catégories de classement, 1v1 mais aussi 2v2, 3v3 ».
test("RANKED in three categories: 1v1, 2v2 and 3v3 each have their own rating and board", function()
	local profile = { rating = 1234 }
	expect(#Matchmaker.CATEGORIES == 3 and #Matchmaker.BOARDS == 3, "three categories, three boards")
	expect(Matchmaker.BOARDS[1] == "JeuxCombat_Classement_v1", "the 1v1 board changed name (its ranking would be lost)")
	expect(Matchmaker.ratingOf(profile, 1) == 1234, "1v1 must stay the profile's rating")
	expect(Matchmaker.ratingOf(profile, 2) == Matchmaker.START_RATING and not Matchmaker.played(profile, 2),
		"a 2v2 never played starts at the starting rating, off the board")
	-- a 2v2 match moves only the 2v2 rating
	local a, b = { rating = 1000 }, { rating = 1000 }
	local newA, newB = Matchmaker.elo(Matchmaker.ratingOf(a, 2), Matchmaker.ratingOf(b, 2), 1)
	Matchmaker.setRating(a, 2, newA)
	Matchmaker.setRating(b, 2, newB)
	expect(Matchmaker.ratingOf(a, 2) > 1000 and Matchmaker.ratingOf(b, 2) < 1000, "the 2v2 ratings did not move")
	expect(a.rating == 1000 and b.rating == 1000, "a 2v2 match moved the 1v1 rating")
	expect(Matchmaker.ratingOf(a, 3) == Matchmaker.START_RATING, "a 2v2 match moved the 3v3 rating")
	expect(Matchmaker.played(a, 2) and type(a.ratings["2"]) == "number", "the 2v2 rating is not saved under a string key")
	-- sizes out of range fall in a category, a broken saved value falls back
	expect(Matchmaker.category(0) == 1 and Matchmaker.category(7) == 3, "the category of a team size")
	expect(Matchmaker.ratingOf({ rating = 900, ratings = { ["3"] = "x" } }, 3) == Matchmaker.START_RATING, "a broken 3v3 rating")
	-- only teams of the same size meet
	local mm = Matchmaker.new()
	Matchmaker.enqueue(mm, 1, "RANKED", 1000, 0, 2)
	Matchmaker.enqueue(mm, 2, "RANKED", 1000, 0, 3)
	expect(#Matchmaker.pair(mm, 30) == 0, "a 2v2 team met a 3v3 team")
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
		if kit.Finisher then need(kit.Finisher.Name) end
		for _, r in kit.FullRoutes do need(r.name) end
	end
	for _, mode in GameModes.List or {} do need(mode.description) end
	-- (B-028: an update stops a 1v1 between players, init.client.luau)
	for _, line in { "NO CONTEST", "NO CONTEST · Moving you to the new version…", "NO CONTEST · UPDATE: moving you to the new version…" } do
		need(line)
	end
	expect(Locale.translate("NO CONTEST · UPDATE: moving you to the new version…", "FR")
		== "MATCH ANNULÉ · MISE À JOUR : on te déplace vers la nouvelle version…", "the no contest line")
	-- (B-035: the menu while the saved profile loads, the refusals of a challenge or of the
	-- reserved server's RANKED match, the owner's !give after a failed load; init.server.luau,
	-- MenuController.luau)
	for _, line in { "LOADING YOUR SAVE…", "YOUR SAVE IS NOT LOADED YET", "YOUR OPPONENT'S SAVE IS NOT LOADED YET",
		"NOT GIVEN · SAVES UNAVAILABLE:", "NOBODY READY (profile loading)" } do
		need(line)
	end
	expect(Locale.translate("LOADING YOUR SAVE…", "FR") == "CHARGEMENT DE TA SAUVEGARDE…", "the loading banner")
	expect(Locale.translate("NOT POSSIBLE: YOUR OPPONENT'S SAVE IS NOT LOADED YET", "FR")
		== "IMPOSSIBLE : LA SAUVEGARDE DE TON ADVERSAIRE N'EST PAS ENCORE CHARGÉE", "the opponent's save, as the menu shows it")
	expect(Locale.translate("GIVEN TO Ann · NOT GIVEN · SAVES UNAVAILABLE: Bob", "FR")
		== "DONNÉ À Ann · PAS DONNÉ · SAUVEGARDES INDISPONIBLES : Bob", "the owner's reply")
	-- (B-039, B-042: the refusals of a menu request, what the reserved server says when its RANKED
	-- match does not start, and its search page while the opponent comes; read from the modules)
	local GlobalQueue = require("../src/server/GlobalQueue")
	for _, line in GameModes.REFUSALS do need(line) end
	for _, line in GlobalQueue.NOTICES do need(line) end
	need("OPPONENT FOUND · CONNECTING…")
	need(string.format("RANKED · %d:%02d\nYour opponent is coming from another server: the match starts as soon as you are both here.", 0, 7))
	-- (whole lines: a line translated piece by piece, "ADVERSAIRE FOUND · CONNECTING…", is no translation)
	for _, line in { "OPPONENT FOUND · CONNECTING…", GameModes.REFUSALS.crossWaiting, GameModes.REFUSALS.rankedUnsaved, GlobalQueue.NOTICES.gone,
		GlobalQueue.NOTICES.theirsFailed } do
		expect(Locale.FR[line] ~= nil, "no whole French line: " .. line)
	end
	expect(Locale.translate(string.format("RANKED · %d:%02d\nYour opponent is coming from another server: the match starts as soon as you are both here.", 1, 5), "FR")
		== "CLASSÉ · 1:05\nTon adversaire arrive d'un autre serveur : la partie commence dès que vous êtes là tous les deux.", "the search page while the opponent comes")
	expect(Locale.translate("NOT POSSIBLE: YOUR OPPONENT LEFT: search again", "FR") == "IMPOSSIBLE : TON ADVERSAIRE EST PARTI : relance la recherche",
		"the opponent left, as the menu shows it")
	expect(Locale.translate("NOT POSSIBLE: " .. GameModes.REFUSALS.rankedUnsaved, "FR")
		== "IMPOSSIBLE : LE CLASSÉ DEMANDE TA SAUVEGARDE : SAUVEGARDES INDISPONIBLES", "RANKED after a failed load")
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
		-- (Wilhem: « la luminosité de certaines maps, c'est abusé »: never dazzling again)
		expect(l.brightness <= 2 and l.bloom <= 0.7 and (l.exposure or 0) <= 0, map.id .. ": too bright (brightness, bloom or exposure)")
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
		expect(style.SkinTone ~= nil, name .. " has no skin tone")
	end
	expect(count == 2 * 20, "expected 2 shop styles for each of the 20 fighters, got " .. count)
	local profile = { coins = 1000, ownedSkins = {} }
	expect(not CharacterData.canWear("KAI GOLD", profile), "a shop style is worn without being bought")
	expect(CharacterData.canWear("CLASSIC", profile) and not CharacterData.canWear("AWAKENED", profile), "free / earned styles are wrong")
	local price = 1500
	local ok, why = CharacterData.buy(profile, "KAI GOLD", price)
	expect(not ok and why == "coins" and profile.coins == 1000, "bought without enough coins")
	profile.coins = price + 5
	expect(CharacterData.buy(profile, "KAI GOLD", price) and profile.coins == 5 and CharacterData.canWear("KAI GOLD", profile), "a purchase failed")
	ok, why = CharacterData.buy(profile, "KAI GOLD", price)
	expect(not ok and why == "owned" and profile.coins == 5, "a style was paid twice")
	expect(not CharacterData.buy(profile, "CLASSIC", price) and not CharacterData.buy(profile, "NOPE", price), "a free or unknown style was sold")
	expect(not CharacterData.buy({ coins = -1 }, "KAI GOLD", price), "a debt bought a style")
	expect(not CharacterData.buy({ coins = 99999 }, "TARO GOLD", nil) and not CharacterData.buy({ coins = 99999 }, "TARO GOLD", 0),
		"a style was sold without a price")
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

-- The profile writes of a server "A" against the DataStore, second by second, as
-- init.server.luau runs them (B-025, B-032). Each visit of a player is a session (the
-- server's client table). writeProfile: only the session that loaded the profile
-- (SaveQueue.isLoaded), SaveQueue.writing, GlobalQueue.write in the UpdateAsync transform,
-- then SaveQueue.written / failed / lost. The flush every FLUSH_PERIOD s (SaveQueue.flush),
-- for the player's current visit. The last write of a visit that leaves (SaveQueue.leaving,
-- retried by SaveQueue.finalRetry, then forget). loadProfile: wait while an older visit
-- holds the id (SaveQueue.held), then the tries of the load. A write lands `latency` s after
-- it starts; `down(id, t)` makes the DataStore fail a request made at t. Another server is
-- played by the test itself, on `w.store`.
local function saveWorld(SaveQueue, G, opts)
	opts = opts or {}
	local w = {
		q = SaveQueue.new(), store = {}, current = {}, flights = {}, timers = {}, loading = {}, writes = {},
		latency = opts.latency or 0.4, phase = opts.phase or 7, closing = false, down = opts.down,
	}
	local function session(id, profile)
		local s = { id = id, profile = profile, present = true, profileLoaded = false, writes = 0 }
		w.current[id] = s
		return s
	end
	-- writeProfile, up to the UpdateAsync call (the rest when it lands)
	function w.write(s, now, release, attempt)
		if not SaveQueue.isLoaded(w.q, s.id, s) then return "unloaded" end
		if SaveQueue.isLost(w.q, s.id, s) then return "lost" end
		SaveQueue.writing(w.q, s.id, now, s)
		w.writes[s.id] = (w.writes[s.id] or 0) + 1
		s.writes += 1
		table.insert(w.flights, { at = now + w.latency, started = now, s = s, release = release, attempt = attempt,
			profile = table.clone(s.profile) })
		return nil
	end
	-- a visit that loads at once (loadProfile, nothing in the way)
	function w.join(id, now, version)
		local s = session(id, { v = version or 1 })
		w.store[id] = G.stamp(s.profile, "A", now, false)
		SaveQueue.loaded(w.q, id, now, s)
		s.profileLoaded = true
		return s
	end
	-- a visit that loads as loadProfile does, from the default profile (v = 0)
	function w.arrive(id, now)
		local s = session(id, { v = 0 })
		w.loading[s] = { next = now, phase = "held", held = 0, attempt = 0, waited = 0 }
		return s
	end
	-- a change (saveProfile), in the player's current visit
	function w.change(id, now, version, urgent)
		local s = w.current[id]
		s.profile.v = version
		SaveQueue.mark(w.q, id, now, s)
		if urgent and SaveQueue.isLoaded(w.q, id, s) then w.write(s, now, false) end
	end
	-- a Developer Product bought (ProcessReceipt): granted only on a loaded profile, once written
	function w.receipt(s, now)
		if not s.profileLoaded or not SaveQueue.isLoaded(w.q, s.id, s) then return "NotProcessedYet" end
		s.profile.v += 1000
		if w.write(s, now, false) then return "NotProcessedYet" end
		return "written"
	end
	-- the visit leaves (PlayerRemoving): its last write, retried, then forget this visit
	function w.leave(id, now, s)
		s = s or w.current[id]
		s.present = false
		if w.current[id] == s then w.current[id] = nil end
		if SaveQueue.isLoaded(w.q, id, s) then
			SaveQueue.leaving(w.q, id, s)
			if w.write(s, now, true, 1) then SaveQueue.forget(w.q, id, s) end
		else
			SaveQueue.forget(w.q, id, s)
		end
	end
	local function land(f)
		local s, why = f.s, nil
		if w.down and w.down(s.id, f.started) then
			why = "error"
		else
			local data
			data, why = G.write(w.store[s.id], f.profile, "A", f.at, f.release, s.present)
			if data then w.store[s.id] = data end
		end
		if why == "error" then
			SaveQueue.failed(w.q, s.id, f.at, s)
		elseif why == "lost" then
			SaveQueue.lost(w.q, s.id, s)
		elseif why == nil and not f.release then
			SaveQueue.written(w.q, s.id, f.started, s)
		end
		if f.attempt then -- (the leaving thread: finalWrite, then forget)
			local delay = if why then SaveQueue.finalRetry(why, f.attempt) else nil
			if delay then
				table.insert(w.timers, { at = f.at + delay, s = s, attempt = f.attempt + 1 })
			else
				SaveQueue.forget(w.q, s.id, s)
			end
		end
	end
	-- one step of loadProfile
	local function load(s, L, t)
		if not s.present then w.loading[s] = nil return end -- (clients[player] ~= client)
		if L.phase == "held" then
			if SaveQueue.held(w.q, s.id, s) and L.held < G.LOCK_TTL + 5 then
				L.held += 1
				L.next = t + 1
				return
			end
			L.phase = "load"
		end
		if L.phase == "unavailable" then -- (SAVES UNAVAILABLE: never loaded)
			s.profileLoaded = true
			w.loading[s] = nil
			return
		end
		local ok = not (w.down and w.down(s.id, t))
		local locked = ok and not G.canLock(w.store[s.id], "A", t)
		if ok and locked and L.waited < G.LOCK_TTL + 5 then
			L.waited += G.LOCK_RETRY
			L.next = t + G.LOCK_RETRY
			return
		end
		if ok and not locked then
			local saved = w.store[s.id]
			s.profile = { v = if saved then saved.v else 0 } -- (Profile.merge)
			w.store[s.id] = G.stamp(saved or {}, "A", t, false)
			SaveQueue.loaded(w.q, s.id, t, s)
			s.profileLoaded = true
			w.loading[s] = nil
			return
		end
		L.attempt += 1
		L.next = t + SaveQueue.retryDelay(L.attempt)
		if L.attempt >= SaveQueue.LOAD_TRIES then L.phase = "unavailable" end
	end
	-- the server's time goes on, one second at a time; `each(t)` at the end of each second
	function w.run(from, to, each)
		for t = from, to do
			table.sort(w.flights, function(a, b) return a.at < b.at end)
			while w.flights[1] and w.flights[1].at <= t do land(table.remove(w.flights, 1)) end
			for i = #w.timers, 1, -1 do
				local r = w.timers[i]
				if r.at <= t then
					table.remove(w.timers, i)
					if w.write(r.s, t, true, r.attempt) then SaveQueue.forget(w.q, r.s.id, r.s) end
				end
			end
			for s, L in w.loading do
				if L.next <= t then load(s, L, t) end
			end
			if t >= w.phase and (t - w.phase) % SaveQueue.FLUSH_PERIOD == 0 then
				for _, id in SaveQueue.flush(w.q, t, w.closing) do
					local s = w.current[id] -- (the flush: GetPlayerByUserId, then its client)
					if s then w.write(s, t, false) end
				end
			end
			if each then each(t) end
		end
	end
	return w
end

test("session lock (B-025): a player who stays keeps a fresh lock, idle for 10 minutes or through a 3-minute RANKED match", function()
	local SaveQueue = require("../src/server/SaveQueue")
	local G = require("../src/server/GlobalQueue")
	expect(SaveQueue.RENEW > SaveQueue.MIN_GAP and SaveQueue.RENEW + 2 * SaveQueue.FLUSH_PERIOD < G.LOCK_TTL,
		"one failed renewal lets the lock expire (RENEW + 2 flushes must stay under LOCK_TTL)")
	-- idle: nothing changes for 10 minutes (the hub, the queue), whatever the flush's phase
	for phase = 0, SaveQueue.FLUSH_PERIOD - 1 do
		local w = saveWorld(SaveQueue, G, { phase = phase })
		w.join(1, 0)
		local stale, oldest = nil, 0
		w.run(0, 600, function(t)
			if G.canLock(w.store[1], "B", t) then stale = stale or t end
			oldest = math.max(oldest, t - w.store[1]._session.t)
		end)
		expect(stale == nil, string.format("idle (flush phase %d): another server can take the profile from t = %s", phase, tostring(stale)))
		expect(oldest < SaveQueue.RENEW + SaveQueue.FLUSH_PERIOD + 1, string.format("idle (phase %d): a lock %.1f s old", phase, oldest))
		expect(w.writes[1] <= 21, string.format("idle (phase %d): %d writes in 10 minutes (2 a minute expected)", phase, w.writes[1]))
	end
	-- a 3-minute RANKED match: a change in the menu, nothing at all during the match, its
	-- result at the end; the player leaves 5 s later. Another server tries 2 s before the
	-- leave (another device, a quick rejoin), then every LOCK_RETRY s (loadProfile)
	local w = saveWorld(SaveQueue, G)
	w.join(1, 0)
	local stale
	w.run(0, 214, function(t)
		if t == 5 then w.change(1, t, 2) end -- (a style worn in the menu)
		if t == 210 then w.change(1, t, 3) end -- (MatchEnd: rating, coins, history)
		if G.canLock(w.store[1], "B", t) then stale = stale or t end
	end)
	expect(stale == nil, "a 3-minute match (from t = 30 to 210): another server can take the profile from t = " .. tostring(stale))
	w.leave(1, 215)
	local loadedAt, version
	w.run(215, 300, function(t)
		if not loadedAt and (t - 213) % G.LOCK_RETRY == 0 and G.canLock(w.store[1], "B", t) then
			loadedAt, version = t, w.store[1].v
		end
	end)
	expect(version == 3 and loadedAt and loadedAt - 213 <= 2 * G.LOCK_RETRY,
		"the other server loads " .. tostring(version) .. " at t = " .. tostring(loadedAt) .. " (the match result, 3, just after the leave)")
end)

test("session lock (B-025): 100 players on one server all keep a fresh lock, idle or busy, within the DataStore budget", function()
	local SaveQueue = require("../src/server/SaveQueue")
	local G = require("../src/server/GlobalQueue")
	local N = 100
	for _, busy in { false, true } do
		local w = saveWorld(SaveQueue, G)
		local staleSeconds, oldest = 0, 0
		w.run(0, 615, function(t)
			for id = 1, N do
				if t < SaveQueue.FLUSH_PERIOD and id % SaveQueue.FLUSH_PERIOD == t then w.join(id, t) end -- (they join over 15 s)
				if busy and w.current[id] then w.change(id, t, t) end -- (a change every second)
				if t >= SaveQueue.FLUSH_PERIOD then
					if G.canLock(w.store[id], "B", t) then staleSeconds += 1 end
					oldest = math.max(oldest, t - w.store[id]._session.t)
				end
			end
		end)
		local total = 0
		for id = 1, N do total += w.writes[id] or 0 end
		local perPlayerMinute = total / N / (616 / 60)
		local kind = if busy then "busy" else "idle"
		expect(staleSeconds == 0, string.format("%d %s players: %d player-seconds where another server could take a profile", N, kind, staleSeconds))
		expect(oldest < SaveQueue.RENEW + SaveQueue.FLUSH_PERIOD + 1, string.format("%d %s players: a lock %.1f s old", N, kind, oldest))
		-- the budget: one write per player and flush at most (4 a minute), under Roblox's
		-- 60 + 10 per player and per minute; an idle player 2 a minute
		expect(perPlayerMinute <= 60 / SaveQueue.FLUSH_PERIOD and perPlayerMinute * N <= 60 + 10 * N,
			string.format("%d %s players: %.2f writes per player and minute", N, kind, perPlayerMinute))
		expect(busy or perPlayerMinute <= 2.1, string.format("%d idle players: %.2f writes per player and minute", N, perPlayerMinute))
	end
	-- one failed renewal, with 30 busy players filling every BATCH: caught up at the next flush
	local failedOnce = false
	local w = saveWorld(SaveQueue, G, { down = function(id)
		if id == 1 and not failedOnce then failedOnce = true return true end
		return false
	end })
	w.join(1, 0)
	local stale, oldest = nil, 0
	w.run(0, 300, function(t)
		for id = 2, 31 do
			if t == 0 then w.join(id, 0) end
			w.change(id, t, t)
		end
		if G.canLock(w.store[1], "B", t) then stale = stale or t end
		oldest = math.max(oldest, t - w.store[1]._session.t)
	end)
	expect(failedOnce and stale == nil, "after one failed renewal, another server can take the profile from t = " .. tostring(stale))
	expect(oldest < SaveQueue.RENEW + 2 * SaveQueue.FLUSH_PERIOD + 1, string.format("after one failed renewal: a lock %.1f s old", oldest))
end)

test("session lock (B-025): a player who left is never renewed, a late write never takes the lock back, never over another server's profile", function()
	local SaveQueue = require("../src/server/SaveQueue")
	local G = require("../src/server/GlobalQueue")
	-- the rules: nothing before RENEW s after the load; a leaving player (its last write still
	-- retried) is neither flushed nor renewed; a closing server renews nothing
	local q = SaveQueue.new()
	SaveQueue.loaded(q, 1, 100)
	expect(#SaveQueue.flush(q, 100 + SaveQueue.RENEW - 1, false) == 0, "a lock renewed right after the load")
	expect(SaveQueue.flush(q, 100 + SaveQueue.RENEW, false)[1] == 1, "a lock RENEW s old is not renewed")
	expect(#SaveQueue.flush(q, 1000, true) == 0, "a closing server takes back the locks its last writes released")
	SaveQueue.mark(q, 1, 101)
	SaveQueue.leaving(q, 1)
	expect(#SaveQueue.flush(q, 1000, false) == 0 and #SaveQueue.renewals(q, 1000) == 0, "a player who left is still written by the flush")
	SaveQueue.forget(q, 1)
	expect(not SaveQueue.isLoaded(q, 1) and #SaveQueue.flush(q, 2000, false) == 0, "a player forgotten is renewed")
	-- a player leaves: the last write releases the lock, then nothing from A any more
	local w = saveWorld(SaveQueue, G)
	local s = w.join(1, 0)
	w.run(0, 49)
	local before = w.writes[1] or 0
	w.leave(1, 50)
	w.run(50, 600)
	expect(w.writes[1] - before == 1 and w.store[1]._session == nil and not SaveQueue.isLoaded(w.q, 1, s),
		string.format("after the leave: %d writes, lock %s", w.writes[1] - before, if w.store[1]._session then "still held" else "released"))
	-- a flush or renewal stuck in the DataStore's queue lands after the last write: it writes
	-- nothing (the player is gone), the lock stays released
	local w2 = saveWorld(SaveQueue, G, { latency = 0.3 })
	w2.join(1, 0)
	w2.run(0, 30)
	w2.latency = 5
	w2.write(w2.current[1], 31, false) -- (lands at t = 36)
	w2.latency = 0.3
	w2.leave(1, 32) -- (lands at t = 32.3)
	local retaken
	w2.run(32, 120, function(t)
		if t >= 33 and not G.canLock(w2.store[1], "B", t) then retaken = retaken or t end
	end)
	expect(retaken == nil, "a write sent before the leave took the lock back at t = " .. tostring(retaken) .. ": the next server waits a minute")
	-- another server took the profile (A's DataStore failed from t = 10 to 100, its lock
	-- expired; A still believes the player is here). While that lock is fresh, every write of
	-- A is refused (GlobalQueue.write); then A never writes the profile again, even after the
	-- other server released it: its copy there is newer
	local w3 = saveWorld(SaveQueue, G, { down = function(_, t) return t >= 10 and t < 100 end })
	local s3 = w3.join(1, 0)
	local bHolds, overwritten, aWhileB = false, nil, nil
	w3.run(0, 400, function(t)
		if t == 70 then
			expect(G.canLock(w3.store[1], "B", t), "the scene: A's lock should have expired after 60 s of failed writes")
			w3.store[1] = G.stamp({ v = 2 }, "B", t, false) -- (the player is on B now)
			bHolds = true
		end
		if bHolds and t % 20 == 10 then w3.store[1] = G.stamp({ v = w3.store[1].v + 1 }, "B", t, false) end -- (B's writes)
		if t == 200 then
			w3.store[1] = G.stamp({ v = 10 }, "B", t, true) -- (the player leaves B: released)
			bHolds = false
		end
		if t == 80 or t == 250 then w3.change(1, t, 99) end -- (a change on A, for a player who is not there)
		if t == 300 then w3.leave(1, t) end -- (A finally sees the player go)
		if bHolds and w3.store[1]._session.job ~= "B" then aWhileB = aWhileB or t end
		if t > 70 and w3.store[1].v == 99 then overwritten = overwritten or t end
	end)
	expect(aWhileB == nil, "A wrote while another server held a fresh lock, at t = " .. tostring(aWhileB))
	expect(overwritten == nil and w3.store[1].v == 10 and w3.store[1]._session == nil,
		"A wrote over the profile of another server at t = " .. tostring(overwritten) .. " (version " .. tostring(w3.store[1].v) .. ")")
	expect(not SaveQueue.isLoaded(w3.q, 1, s3), "a lost profile is still in the queue after the leave")
	-- the transform itself: a write never stamps over another server's fresh lock
	local held = G.stamp({ v = 5 }, "B", 1000, false)
	local data, why = G.write(held, { v = 1 }, "A", 1010, false, true)
	expect(data == nil and why == "lost", "a write over another server's fresh lock")
	data, why = G.write(held, { v = 1 }, "A", 1010, true, false)
	expect(data == nil and why == "lost", "a last write over another server's fresh lock")
	data, why = G.write(nil, { v = 1 }, "A", 1010, false, false)
	expect(data == nil and why == "gone", "a renewal for a player who left")
	data, why = G.write({ v = 0, _session = { job = "A", t = 990 } }, { v = 1 }, "A", 1010, false, true)
	expect(why == nil and data.v == 1 and data._session.job == "A" and data._session.t == 1010, "a renewal of its own lock")
end)

test("last write (B-032): retried after 1, 2 and 4 s on a DataStore error, never on a lock held by another server", function()
	local SaveQueue = require("../src/server/SaveQueue")
	local G = require("../src/server/GlobalQueue")
	-- the rule
	expect(SaveQueue.finalRetry("error", 1) == 1 and SaveQueue.finalRetry("error", 2) == 2 and SaveQueue.finalRetry("error", 3) == 4,
		"a failed last write is not retried after 1, 2 and 4 s")
	expect(SaveQueue.finalRetry("error", SaveQueue.FINAL_TRIES) == nil, "the last write is retried forever")
	expect(SaveQueue.finalRetry("lost", 1) == nil and SaveQueue.finalRetry("gone", 1) == nil and SaveQueue.finalRetry(nil, 1) == nil,
		"a last write refused by another server's lock is retried")
	local waits = 0
	for attempt = 1, SaveQueue.FINAL_TRIES - 1 do waits += SaveQueue.finalRetry("error", attempt) end
	expect(waits == 7, "the retries wait " .. waits .. " s (7 expected, inside the 25 s of BindToClose)")
	-- a RANKED match ends at t = 120 (its result in the profile), the player leaves at t = 125,
	-- before the next flush (t = 127), and the DataStore fails that write once
	local w = saveWorld(SaveQueue, G, { down = function(_, t) return t == 125 end })
	local s = w.join(1, 0)
	w.run(0, 119)
	w.change(1, 120, 2)
	w.run(120, 124)
	local before = w.writes[1] or 0
	w.leave(1, 125)
	local loaded
	w.run(125, 200, function(t)
		if t == 130 and G.canLock(w.store[1], "B", t) then loaded = w.store[1].v end -- (the player joins B at t = 130)
	end)
	expect(w.store[1].v == 2 and w.store[1]._session == nil,
		string.format("after one DataStore error, the save holds version %s, lock %s (the match result, released, expected)",
			tostring(w.store[1].v), if w.store[1]._session then "still held" else "released"))
	expect(w.writes[1] - before == 2 and not SaveQueue.isLoaded(w.q, 1, s), "one error: " .. (w.writes[1] - before) .. " tries")
	expect(loaded == 2, "the next server loads " .. tostring(loaded) .. " at t = 130 (the match result, 2, expected)")
	-- an error that lasts: FINAL_TRIES tries, then the queue forgets the player
	local wd = saveWorld(SaveQueue, G, { down = function(_, t) return t >= 125 end })
	local sd = wd.join(1, 0)
	wd.run(0, 124)
	before = wd.writes[1] or 0
	wd.leave(1, 125)
	wd.run(125, 200)
	expect(wd.writes[1] - before == SaveQueue.FINAL_TRIES and not SaveQueue.isLoaded(wd.q, 1, sd),
		"a lasting error: " .. (wd.writes[1] - before) .. " tries (" .. SaveQueue.FINAL_TRIES .. " expected)")
	-- another server holds the lock: one try, refused, never retried
	local wl = saveWorld(SaveQueue, G)
	local sl = wl.join(1, 0)
	wl.run(0, 120)
	wl.store[1] = G.stamp({ v = 7 }, "B", 121, false)
	before = wl.writes[1] or 0
	wl.leave(1, 125)
	wl.run(125, 200)
	expect(wl.writes[1] - before == 1 and wl.store[1].v == 7 and wl.store[1]._session.job == "B" and not SaveQueue.isLoaded(wl.q, 1, sl),
		"a last write refused by another server's lock: " .. (wl.writes[1] - before) .. " tries, version " .. tostring(wl.store[1].v))
end)

test("back on the same server while the last write is retried: the new visit never writes a profile it did not load, and loads the last one", function()
	local SaveQueue = require("../src/server/SaveQueue")
	local G = require("../src/server/GlobalQueue")
	-- the first visit: its real save is 25000; a RANKED result (26000) is not written yet when
	-- it leaves. Two orders: the old visit removed before the new one is added ("removed
	-- first"), or the new one added first (Roblox's order is not known)
	local function scene(down, removedFirst, latency)
		local w = saveWorld(SaveQueue, G, { down = down })
		local s1 = w.join(1, 0, 25000)
		w.run(0, 98)
		w.change(1, 99, 26000)
		w.run(99, 99)
		local s2
		if latency then w.latency = latency end
		if removedFirst then
			w.leave(1, 100, s1)
			w.latency = 0.4
			w.run(100, 100)
			s2 = w.arrive(1, 101)
			w.run(101, 101)
		else
			s2 = w.arrive(1, 100)
			w.run(100, 100)
			w.leave(1, 101, s1)
			w.latency = 0.4
			w.run(101, 101)
		end
		return w, s1, s2
	end
	for _, removedFirst in { true, false } do
		local order = if removedFirst then "removed first" else "added first"
		-- the load fails (the DataStore is down from t = 100 to 124): SAVES UNAVAILABLE. Nothing
		-- of the new visit is ever written: not its purchase, not its changes
		local w, _, s2 = scene(function(_, t) return t >= 100 and t < 125 end, removedFirst)
		local loadedEver, receipt = false, nil
		w.run(102, 400, function(t)
			if SaveQueue.isLoaded(w.q, 1, s2) then loadedEver = true end
			if t == 130 then receipt = w.receipt(s2, t) end -- (a Developer Product bought)
			if t == 131 then w.change(1, t, 5, true) end -- (a style bought with coins: an urgent save)
		end)
		expect(s2.profileLoaded and not loadedEver, order .. ": a visit whose load failed counts as loaded")
		expect(receipt == "NotProcessedYet", order .. ": a purchase on a profile that never loaded is " .. tostring(receipt))
		expect(s2.writes == 0 and w.store[1].v == 25000,
			string.format("%s: the new visit wrote %d times, the save holds %s (25000, the real save, expected)", order, s2.writes, tostring(w.store[1].v)))
		-- the load works: the new visit waits for the old one's last write (one error, then
		-- written; or a slow write, 5 s in the DataStore's queue), loads it, and from then on
		-- keeps its own lock: flushed, renewed, never released by the old visit's last write
		for _, case in { { "one error", function(_, t) return t == 100 or t == 101 end }, { "a slow last write", nil, 5 } } do
			local wl, _, n2 = scene(case[2], removedFirst, case[3])
			local loadedAt, version, unlocked, stale
			wl.run(102, 400, function(t)
				if not loadedAt and SaveQueue.isLoaded(wl.q, 1, n2) then loadedAt, version = t, n2.profile.v end
				if loadedAt then
					if wl.store[1]._session == nil then unlocked = unlocked or t end
					if G.canLock(wl.store[1], "B", t) then stale = stale or t end
				end
			end)
			local what = order .. ", " .. case[1]
			expect(loadedAt and version == 26000,
				string.format("%s: the new visit loads %s at t = %s (26000, the old visit's last write, expected)", what, tostring(version), tostring(loadedAt)))
			expect(unlocked == nil, what .. ": the old visit's last write released the new visit's lock at t = " .. tostring(unlocked))
			expect(stale == nil, what .. ": the new visit's lock expired at t = " .. tostring(stale))
			expect(n2.writes >= 8 and wl.store[1].v == 26000, string.format("%s: the new visit wrote %d times, the save holds %s", what, n2.writes, tostring(wl.store[1].v)))
		end
	end
	-- the rules themselves: a visit is never "loaded" because an older one of the same player
	-- was; it never marks, leaves nor forgets the older one; it waits while that one holds the id
	local q = SaveQueue.new()
	local old, new = {}, {}
	SaveQueue.loaded(q, 1, 0, old)
	expect(not SaveQueue.isLoaded(q, 1, new) and SaveQueue.held(q, 1, new) and not SaveQueue.held(q, 1, old), "a new visit reads an old one as its own")
	SaveQueue.leaving(q, 1, new)
	SaveQueue.mark(q, 1, 5, new)
	expect(SaveQueue.flush(q, 100, false)[1] == 1 and not SaveQueue.isDirty(q, 1, old), "a new visit marked or let go the old one's entry")
	expect(not SaveQueue.forget(q, 1, new) and SaveQueue.isLoaded(q, 1, old), "a new visit forgot the old one")
	SaveQueue.leaving(q, 1, old)
	expect(SaveQueue.held(q, 1, new) and #SaveQueue.flush(q, 200, false) == 0, "the old visit's last write is not waited for, or it is renewed")
	expect(SaveQueue.forget(q, 1, old) and not SaveQueue.held(q, 1, new), "the old visit is never forgotten")
	SaveQueue.loaded(q, 1, 210, new)
	expect(SaveQueue.isLoaded(q, 1, new) and not SaveQueue.forget(q, 1, old) and SaveQueue.isLoaded(q, 1, new), "the old visit forgot the new one")
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

-- A 1v1 between players as the server counts it (B-023, B-028). The decisions are the real
-- ones (AntiCheat.departure, noContest, share, versusShares, scaleRating; Matchmaker.elo); the
-- few lines that apply them copy endVersus (wins / losses, rating), unseat and BindToClose of
-- src/server/init.server.luau, which the tests do not load.
local function versusBench(queue, ratings, size, owners)
	local AC = require("../src/server/AntiCheat")
	size = size or 1
	owners = owners or { "A", "B" }
	local w = { closing = false, seconds = 60, actions = { 80, 80 }, settled = 0, now = 1000000 }
	w.match = { mode = "VERSUS", queue = queue, slots = { { owner = owners[1] }, { owner = owners[2] } } }
	w.profiles = { { wins = 0, losses = 0 }, { wins = 0, losses = 0 } }
	for s = 1, 2 do
		Matchmaker.setRating(w.profiles[s], size, ratings[s])
		GameModes.achievementSeason(w.profiles[s]) -- (the achievement counters, at 0)
	end
	-- endVersus(match, winnerSlot, leftSlot)
	function w.finish(winner, left)
		local m = w.match
		if m.finished then return end
		m.finished = true
		w.settled += 1
		local p = w.profiles
		local shareA = AC.share(p[1], "B", w.seconds, w.now, w.actions[1], w.actions[2])
		local shareB = AC.share(p[2], "A", w.seconds, w.now, w.actions[2], w.actions[1])
		local shares = AC.versusShares(shareA.rating, shareB.rating, left, m.queue)
		if winner == 1 or winner == 2 then
			if shares[winner] > 0 then p[winner].wins += 1 end
			if shares[3 - winner] > 0 then p[3 - winner].losses += 1 end
		end
		local before = { Matchmaker.ratingOf(p[1], size), Matchmaker.ratingOf(p[2], size) }
		if m.queue == "RANKED" and (shares[1] > 0 or shares[2] > 0) then
			local new = { Matchmaker.elo(before[1], before[2], if winner == 1 then 1 elseif winner == 2 then 0 else 0.5) }
			for s = 1, 2 do
				if shares[s] > 0 then Matchmaker.setRating(p[s], size, AC.scaleRating(before[s], new[s], shares[s])) end
			end
			-- (RISING STAR / LEGEND: only a place whose rating counts)
			for s = 1, 2 do
				if size == 1 and shares[s] > 0 then GameModes.achievementProgress(p[s], { rating = p[s].rating }) end
			end
		end
	end
	-- unseat: a leave (QUIT, another mode, a challenge, or the server's PlayerRemoving)
	function w.leave(slot)
		local how = AC.departure(w.match, slot, w.closing)
		if how == "abandon" then w.finish(3 - slot, slot) elseif how == "void" then AC.noContest(w.match) end
		w.match.slots[slot].owner = nil
		return how
	end
	-- BindToClose: `closing` first, then every 1v1 still being played ends with no result
	function w.close()
		w.closing = true
		return AC.noContest(w.match)
	end
	-- the fight's own end (MatchEnd)
	function w.ko(winner) w.finish(winner) end
	function w.rating(s) return Matchmaker.ratingOf(w.profiles[s], size) end
	function w.unchanged(ratings)
		local p = w.profiles
		return w.rating(1) == ratings[1] and w.rating(2) == ratings[2] and p[1].wins + p[1].losses + p[2].wins + p[2].losses == 0
	end
	return w
end

test("RANKED (B-023): leaving costs the points in full at any time (0, 10, 24, 26, 60 s, 3 actions too); the one who stays gains only a match that counts", function()
	-- (1500 leaves against 1200: Elo gives -27 / +27)
	for _, case in {
		{ t = 0, acts = { 0, 0 }, counted = false }, -- (during the intro)
		{ t = 10, acts = { 4, 6 }, counted = false },
		{ t = 24, acts = { 30, 40 }, counted = false }, -- (MIN_MATCH is 25 s)
		{ t = 26, acts = { 30, 40 }, counted = true },
		{ t = 60, acts = { 12, 80 }, counted = false }, -- (fewer than MIN_ACTIONS: an idle match)
		{ t = 60, acts = { 80, 80 }, counted = true },
		{ t = 120, acts = { 19, 300 }, counted = false },
	} do
		local w = versusBench("RANKED", { 1500, 1200 })
		w.seconds, w.actions = case.t, case.acts
		local what = string.format("leaving at %d s (%d / %d actions)", case.t, case.acts[1], case.acts[2])
		expect(w.leave(1) == "abandon", what .. ": not settled as an abandon")
		expect(w.rating(1) == 1473, what .. ": the one who left keeps " .. w.rating(1) .. " (1473 expected: the full loss)")
		expect(w.profiles[1].losses == 1, what .. ": the defeat of the one who left is not counted")
		expect(w.rating(2) == (if case.counted then 1227 else 1200), what .. ": the one who stays has " .. w.rating(2))
		expect(w.profiles[2].wins == (if case.counted then 1 else 0), what .. ": the win of the one who stays")
		expect(w.profiles[2].achRating == (if case.counted then 1227 else 0) and w.profiles[1].achRating == 1473,
			what .. ": the RISING STAR / LEGEND counter of the one who stays moved on a match that does not count ("
			.. w.profiles[2].achRating .. ")")
		-- (the one who stays goes back to the menu: nothing more is settled)
		expect(w.leave(2) == nil and w.settled == 1 and w.rating(1) == 1473, what .. ": the second leave settled the match again")
	end
	-- the same in 2v2 and 3v3 (their own rating), and the same pair for the 8th time today
	for size = 2, 3 do
		local w = versusBench("RANKED", { 1500, 1200 }, size)
		w.seconds = 10
		w.leave(1)
		expect(w.rating(1) == 1473 and w.rating(2) == 1200 and w.profiles[1].rating == nil,
			size .. "v" .. size .. ": leaving after 10 s gives " .. w.rating(1) .. " / " .. w.rating(2))
	end
	local AC = require("../src/server/AntiCheat")
	local w = versusBench("RANKED", { 1500, 1200 })
	for _ = 1, AC.REPEAT_HARD do AC.record(w.profiles[1], "B", w.now); AC.record(w.profiles[2], "A", w.now) end
	w.leave(1)
	expect(w.rating(1) == 1473 and w.rating(2) == 1200, "the same pair for the 8th time: leaving gives " .. w.rating(1) .. " / " .. w.rating(2))
	-- the one who stays leaves too (a quit in the menu): the leaver is the first one, the other gets nothing more
	w = versusBench("RANKED", { 1300, 1300 })
	w.seconds = 5
	w.leave(2)
	w.leave(1)
	expect(w.rating(2) == 1284 and w.rating(1) == 1300 and w.profiles[2].losses == 1 and w.profiles[1].wins == 0,
		"both leave: " .. w.rating(1) .. " / " .. w.rating(2))
	-- outside RANKED, leaving stays what it was: a loss only when the match counts, no rating
	w = versusBench("NORMAL", { 1500, 1200 })
	w.seconds = 10
	w.leave(1)
	expect(w.unchanged({ 1500, 1200 }), "NORMAL: leaving after 10 s now counts")
	w = versusBench("FRIEND", { 1500, 1200 })
	w.leave(1)
	expect(w.rating(1) == 1500 and w.profiles[1].losses == 1 and w.profiles[2].wins == 1, "FRIEND: leaving after 60 s")
end)

test("RANKED (B-023): played to the end, nothing changes: the smaller share for both, the rating stays a zero-sum", function()
	local AC = require("../src/server/AntiCheat")
	local shares = AC.versusShares(1, 0.25, nil, "RANKED")
	expect(shares[1] == 0.25 and shares[2] == 0.25, "no leave: the smaller share for both")
	shares = AC.versusShares(0, 0, 2, "RANKED")
	expect(shares[1] == 0 and shares[2] == 1, "RANKED, place 2 left: " .. shares[1] .. " / " .. shares[2])
	shares = AC.versusShares(0, 1, 1, "NORMAL")
	expect(shares[1] == 0 and shares[2] == 0, "NORMAL: the one who left gets a share")
	-- a K.O. after 60 s: the usual Elo, zero-sum
	local w = versusBench("RANKED", { 1500, 1200 })
	w.ko(1)
	expect(w.rating(1) == 1505 and w.rating(2) == 1195 and w.profiles[1].wins == 1 and w.profiles[2].losses == 1,
		"a K.O. after 60 s: " .. w.rating(1) .. " / " .. w.rating(2))
	-- a K.O. after 10 s, or an idle one: nothing for anyone (the anti-farm, as before)
	w = versusBench("RANKED", { 1500, 1200 })
	w.seconds = 10
	w.ko(2)
	expect(w.unchanged({ 1500, 1200 }), "a K.O. after 10 s moved something")
	w = versusBench("RANKED", { 1500, 1200 })
	w.actions = { 80, 5 }
	w.ko(1)
	expect(w.unchanged({ 1500, 1200 }), "an idle match moved something")
	-- the same pair for the 4th time today: a quarter for both, still a zero-sum; a draw
	w = versusBench("RANKED", { 1000, 1000 })
	for _ = 1, AC.REPEAT_SOFT do AC.record(w.profiles[1], "B", w.now); AC.record(w.profiles[2], "A", w.now) end
	w.ko(2)
	expect(w.rating(1) == 996 and w.rating(2) == 1004, "the 4th match of the day: " .. w.rating(1) .. " / " .. w.rating(2))
	w = versusBench("RANKED", { 1200, 1200 })
	w.ko(0)
	expect(w.unchanged({ 1200, 1200 }), "a draw between equals moved something")
	-- many matches: without a leave, the points of the two always add up to the same
	local seed = 7
	for _ = 1, 200 do
		seed = (seed * 1103515245 + 12345) % 2147483648
		local ra, rb = 800 + seed % 1200, 800 + (seed // 1200) % 1200
		local w2 = versusBench("RANKED", { ra, rb })
		w2.seconds, w2.actions = 10 + seed % 200, { seed % 60, (seed // 60) % 60 }
		w2.ko(seed % 3)
		expect(w2.rating(1) + w2.rating(2) == ra + rb, string.format("not a zero-sum: %d + %d became %d + %d", ra, rb, w2.rating(1), w2.rating(2)))
	end
end)

test("the server closing (B-028): an update before the leaves makes it a no contest; a leave before it is an abandon (the known limit)", function()
	local AC = require("../src/server/AntiCheat")
	-- BindToClose, then both players are removed (an update, "Migrate to Latest Update")
	for _, t in { 0, 10, 24, 26, 60 } do
		local w = versusBench("RANKED", { 1500, 1200 })
		w.seconds = t
		expect(w.close() and w.match.void, "the closing at " .. t .. " s did not stop the match")
		w.leave(1)
		w.leave(2)
		expect(w.settled == 0 and w.unchanged({ 1500, 1200 }), "BindToClose at " .. t .. " s, then the leaves: "
			.. w.rating(1) .. " / " .. w.rating(2))
	end
	-- the other way round for the second removed, and a K.O. landing during the closing
	local w = versusBench("RANKED", { 1500, 1200 })
	w.close()
	w.leave(2)
	w.ko(1)
	w.leave(1)
	expect(w.settled == 0 and w.unchanged({ 1500, 1200 }), "a K.O. during the closing counted")
	expect(not w.close(), "a match stopped twice")
	-- a match that started after BindToClose (a search answered during the closing): a leave settles nothing
	w = versusBench("RANKED", { 1500, 1200 })
	w.closing = true
	expect(w.leave(1) == "void" and w.match.void and w.unchanged({ 1500, 1200 }), "a leave during the closing counted")
	w.ko(2)
	expect(w.settled == 0, "the K.O. after it counted")
	-- a leave BEFORE BindToClose is an abandon: a real leave just before an update counts, and
	-- an update that removes the players before calling BindToClose still costs the first one
	-- removed (the limit of this fix, B-028; the console lines of PlayerRemoving and
	-- BindToClose will tell whether Roblox does that)
	w = versusBench("RANKED", { 1500, 1200 })
	w.seconds = 10
	w.leave(1)
	w.seconds = 12
	w.leave(2)
	expect(not w.close() and w.rating(1) == 1473 and w.rating(2) == 1200, "a leave before the closing: " .. w.rating(1) .. " / " .. w.rating(2))
	-- only the 1v1 between players: the solo modes are never stopped
	for _, mode in { "VERSUS_CPU", "SURVIVAL", "TRAINING", "CHALLENGE" } do
		local m = { mode = mode, slots = { { owner = "A" }, { owner = nil } } }
		expect(not AC.noContest(m) and not m.finished and AC.departure(m, 1, true) == nil, mode .. " stopped by the closing")
	end
	local alone = { mode = "VERSUS", slots = { { owner = "A" }, { owner = nil } } }
	expect(AC.departure(alone, 1, false) == nil, "a leave with no opponent left settles the match")
end)

test("a challenge accepted during a RANKED match (B-023): never the challenger's match, only the accepter's own", function()
	local AC = require("../src/server/AntiCheat")
	local A, B, C, D = 101, 202, 303, 404
	-- the hub handler of src/server/init.server.luau: `busy` is inVersus (AntiCheat.departure);
	-- an accepted challenge takes the accepter, then the challenger, out of their matches
	-- (unseat); seat drops the challenges of a player sitting in a 1v1 between players
	local function hub()
		local h = { l = Lobby.new(), benches = {}, started = nil }
		for _, id in { A, B, C, D } do Lobby.join(h.l, id, tostring(id)) end
		h.l.slots = {}
		local function find(id)
			for _, w in h.benches do
				for s, slot in w.match.slots do
					if slot.owner == id then return w, s end
				end
			end
			return nil, nil
		end
		function h.busy(id)
			local w, s = find(id)
			return w ~= nil and AC.departure(w.match, s, w.closing) ~= nil
		end
		function h.challenge(from, to, now) return Lobby.challenge(h.l, from, to, now, h.busy(from)) end
		function h.accept(to, from, now)
			local ok, why = Lobby.accept(h.l, to, from, now, h.busy(from))
			if ok then
				for _, id in { to, from } do
					local w, s = find(id)
					if w then w.leave(s) end
				end
				h.started = { from, to }
			end
			return ok, why
		end
		-- a match starts (startVersus: seat each player; `drop` false: the challenges kept, to
		-- check the accept on its own)
		function h.start(w, drop)
			table.insert(h.benches, w)
			if drop ~= false and w.match.mode == "VERSUS" then
				for _, slot in w.match.slots do
					if slot.owner then Lobby.drop(h.l, slot.owner) end
				end
			end
			return w
		end
		return h
	end
	-- 1. A challenged C, then played a RANKED match against B (a REMATCH, a search answered in
	-- a second); C accepts 5 or 24 s later: A's match goes on, untouched, and ends as usual
	for _, t in { 5, 24 } do
		local h = hub()
		expect(h.challenge(A, C, 100), "the challenge was not sent")
		local w = h.start(versusBench("RANKED", { 1500, 1200 }, 1, { A, B }), false)
		w.seconds = t
		local ok, why = h.accept(C, A, 100 + t)
		expect(not ok and why == "busy" and h.started == nil, "C's accept took A out of his RANKED match after " .. t .. " s")
		expect(w.rating(1) == 1500 and w.profiles[1].losses == 0 and not w.match.finished,
			"C's accept settled A's match after " .. t .. " s: A at " .. w.rating(1))
		expect(h.l.challenges[A] == nil and not Lobby.accept(h.l, C, A, 101 + t), "the withdrawn challenge can still be accepted")
		w.seconds = 90
		w.ko(1)
		expect(w.rating(1) == 1505 and w.rating(2) == 1195 and w.settled == 1, "A's match, played on: " .. w.rating(1) .. " / " .. w.rating(2))
	end
	-- 2. the same, as the server does it: sitting in the match drops the challenge, the hub no
	-- longer shows it, and an accept finds nothing
	local h = hub()
	h.challenge(A, C, 100)
	h.challenge(D, A, 100)
	local w = h.start(versusBench("RANKED", { 1500, 1200 }, 1, { A, B }))
	local status = Lobby.status(h.l)
	for _, e in status do
		expect(not (e.id == C and #e.from > 0) and not (e.id == A and (e.sent or #e.from > 0)), "the hub still shows A's challenges")
	end
	expect(not h.accept(C, A, 105) and not h.accept(A, D, 105) and w.rating(1) == 1500 and not w.match.finished, "a dropped challenge was accepted")
	-- 3. a player in a 1v1 between players sends no challenge (its acceptance would take it out)
	expect(not h.challenge(A, C, 106) and h.l.challenges[A] == nil, "A sent a challenge from his RANKED match")
	-- 4. the challenger and the accepter in the same RANKED match (paired after the challenge)
	h = hub()
	h.challenge(A, C, 100)
	w = h.start(versusBench("RANKED", { 1500, 1200 }, 1, { A, C }), false)
	w.seconds = 10
	expect(not h.accept(C, A, 105) and w.unchanged({ 1500, 1200 }) and not w.match.finished, "an accept inside their own match settled it")
	-- 5. the accepter is in a RANKED match: accepting is its own leave, an abandon of its own
	-- match; its opponent's result is the usual one; the challenger, in the hub, is not touched
	for _, case in { { t = 10, stays = 1200, win = 0 }, { t = 60, stays = 1227, win = 1 } } do
		h = hub()
		w = h.start(versusBench("RANKED", { 1500, 1200 }, 1, { C, B }))
		expect(h.challenge(D, C, 100), "D could not challenge a player in a match")
		w.seconds = case.t
		expect(h.accept(C, D, 105) and h.started[1] == D and h.started[2] == C, "C could not accept D's challenge")
		expect(w.rating(1) == 1473 and w.profiles[1].losses == 1 and w.rating(2) == case.stays and w.profiles[2].wins == case.win,
			string.format("C accepts after %d s: C %d, B %d (W%d)", case.t, w.rating(1), w.rating(2), w.profiles[2].wins))
	end
	-- 6. the challenger in a solo match (the CPU, training): accepted, as before (nothing to settle)
	h = hub()
	h.challenge(A, C, 100)
	w = versusBench("RANKED", { 1500, 1200 }, 1, { A, nil })
	w.match.mode = "VERSUS_CPU"
	h.start(w)
	expect(h.accept(C, A, 105) and h.started[1] == A and w.settled == 0, "a challenger playing the CPU cannot be accepted")
end)

test("saves loading (B-035): only TRAINING before the saved profile is in; a challenge waits for both saves; the cross-server RANKED never starts on the defaults", function()
	local G = require("../src/server/GlobalQueue")
	local Profile = require("../src/server/Profile")
	local Taunts = require("../src/shared/Taunts")
	-- every mode of the menu writes in the profile (rating, coins, history, quests, an abandon),
	-- but TRAINING; a mode the list does not know waits too
	for _, mode in GameModes.List do
		expect(GameModes.needsSave(mode.id) == (mode.id ~= "TRAINING"), mode.id .. ": needsSave " .. tostring(GameModes.needsSave(mode.id)))
	end
	expect(GameModes.needsSave(nil) and GameModes.needsSave("NEW MODE"), "an unknown mode waits for the save")
	-- the states of a session, as the server sees them (init.server.luau: `store ~= nil`,
	-- `client.profileLoaded`, true once the load has ended, loaded or failed)
	local STATES = {
		{ name = "loaded", saves = true, loaded = true, loading = false },
		{ name = "waiting (nothing yet)", saves = true, loaded = nil, loading = true },
		{ name = "waiting (false)", saves = true, loaded = false, loading = true },
		{ name = "failed, SAVES UNAVAILABLE (plays unsaved, warned; never TRAINING only)", saves = true, loaded = true, loading = false },
		{ name = "no saves (Studio)", saves = false, loaded = nil, loading = false },
	}
	for _, st in STATES do
		expect(GameModes.saveLoading(st.saves, st.loaded) == st.loading, st.name .. ": saveLoading")
		for _, mode in GameModes.List do
			local waits = GameModes.waitsForSave(mode.id, st.saves, st.loaded)
			expect(waits == (st.loading and mode.id ~= "TRAINING"), st.name .. " · " .. mode.id .. ": waits " .. tostring(waits))
		end
	end
	-- the requests the server checks (`start`): valid in themselves, refused while loading, before
	-- the fighters (a fighter bought is not in the defaults: it would say FIGHTER LOCKED first)
	local function request(r) return (GameModes.validate(r, MoveData.KitOrder)) end
	for _, r in { { mode = "VERSUS", team = { "KAI" }, queue = "RANKED" }, { mode = "VERSUS", team = { "KAI" }, queue = "NORMAL" },
		{ mode = "VERSUS_CPU", team = { "KAI" }, level = 4 }, { mode = "SURVIVAL", team = { "KAI" } },
		{ mode = "CHALLENGE", team = { "KAI" } }, { mode = "CHALLENGE_SHIN", team = { "KAI" } } } do
		local valid = request(r)
		expect(valid and GameModes.waitsForSave(valid.mode, true, nil), r.mode .. " " .. tostring(r.queue) .. " starts on the defaults")
		expect(valid and not GameModes.waitsForSave(valid.mode, true, true), r.mode .. " refused once loaded (or failed)")
	end
	local training = request({ mode = "TRAINING", team = { "AKEMI" } })
	expect(training and not GameModes.waitsForSave(training.mode, true, nil), "TRAINING refused while loading")
	-- what is at stake: the defaults are not the save (the hunt's table: 1600 shown as 1000)
	local deps = { startRating = Matchmaker.START_RATING, taunts = Taunts.DEFAULT, achievementSeason = GameModes.ACHIEVEMENT_SEASON }
	local defaults = Profile.default(deps)
	expect(Matchmaker.ratingOf(defaults, 1) == 1000 and (defaults.coins or 0) == 0, "the defaults: 1000 points, 0 coins")

	-- an accepted challenge (the hub handler): either save loading, nothing starts, the
	-- challenges stay (also the ones the accepter received from others), nobody seated
	local A, B, C = 11, 22, 33
	local l = Lobby.new()
	for _, id in { A, B, C } do Lobby.join(l, id, tostring(id)) end
	l.slots = {}
	expect(Lobby.challenge(l, A, B, 0) and Lobby.challenge(l, C, B, 0), "two challenges to B")
	local ok, why = Lobby.accept(l, B, A, 5, false, true)
	expect(not ok and why == "loading", "accepted while a save loads: " .. tostring(ok) .. ", " .. tostring(why))
	expect(l.challenges[A] and l.challenges[A].to == B and l.challenges[C] and l.challenges[C].to == B, "the challenges stay")
	expect(l.slots[1] == nil and l.slots[2] == nil, "nobody seated while a save loads")
	ok, why = Lobby.accept(l, B, A, 10, false, false)
	expect(ok and why == nil and l.slots[1] == A and l.slots[2] == B, "accepted again once both saves are in")
	expect(l.challenges[A] == nil and l.challenges[C] == nil, "then the challenges go, as before")
	-- an expired challenge stays a plain no, a busy challenger (B-023) is still withdrawn first
	l = Lobby.new()
	for _, id in { A, B } do Lobby.join(l, id, tostring(id)) end
	l.slots = {}
	Lobby.challenge(l, A, B, 0)
	ok, why = Lobby.accept(l, B, A, Lobby.CHALLENGE_SECONDS + 1, false, true)
	expect(not ok and why == nil, "an expired challenge: " .. tostring(why))
	Lobby.challenge(l, A, B, 100)
	ok, why = Lobby.accept(l, B, A, 101, true, true)
	expect(not ok and why == "busy" and l.challenges[A] == nil, "a busy challenger: withdrawn (B-023), " .. tostring(why))

	-- the reserved server of a cross-server RANKED match: both saved profiles, or no match (B-035;
	-- the three states and the whole load cycle: the B-039 test below)
	expect(G.crossStart("loaded", "loaded", 0) == "start", "both in: at once")
	for _, t in { 0, 20, 21, 40, 65, G.PROFILE_CAP - 0.5 } do
		for _, pair in { { "loading", "loaded" }, { "loaded", "loading" }, { "loading", "loading" } } do
			local v = G.crossStart(pair[1], pair[2], t)
			expect(v == "wait", string.format("still loading (%s, %s) at %.1f s: %s (it started at 20 s before B-035)", pair[1], pair[2], t, v))
		end
	end
	for _, pair in { { "loading", "loaded" }, { "loaded", "loading" }, { "loading", "loading" } } do
		expect(G.crossStart(pair[1], pair[2], G.PROFILE_CAP) == "cancel", "still loading at PROFILE_CAP: no match, never on the defaults")
	end
	expect(G.crossStart("loaded", "loaded", G.PROFILE_CAP + 30) == "start", "in at the last check: it starts")
	-- (B-042: a failed load is no save: SAVES UNAVAILABLE plays unsaved, but never RANKED)
	expect(G.crossStart("loaded", "failed", 3) == "cancel" and G.crossStart("failed", "loaded", 3) == "cancel", "a failed load: no match")
	expect(G.crossStart(GameModes.saveState(true, true, true), GameModes.saveState(true, nil, false), 3) == "wait", "one still loading")
end)

test("cross-server RANKED (B-039, B-042): the reserved server starts on both saves or not at all, whatever the wait; meanwhile the player waits for nothing else", function()
	local G = require("../src/server/GlobalQueue")
	local SaveQueue = require("../src/server/SaveQueue")
	-- the saved profile of a session in one word (init.server.luau: `store ~= nil`,
	-- client.profileLoaded, SaveQueue.isLoaded), the same "loading" as B-035's saveLoading
	local S = GameModes.saveState
	expect(S(true, nil, false) == "loading" and S(true, false, false) == "loading", "still on its way")
	expect(S(true, true, true) == "loaded", "loaded by this session")
	expect(S(true, true, false) == "failed" and S(true, true, nil) == "failed", "ended without the save: SAVES UNAVAILABLE")
	expect(S(false, nil, nil) == "loaded" and S(nil, true, false) == "loaded", "no saves (Studio): nothing to wait for")
	for _, hasSaves in { true, false } do
		for _, ended in { true, false, nil } do
			for _, loaded in { true, false } do
				expect((S(hasSaves, ended, loaded) == "loading") == GameModes.saveLoading(hasSaves, ended),
					string.format("saveState and saveLoading disagree (%s, %s, %s)", tostring(hasSaves), tostring(ended), tostring(loaded)))
			end
		end
	end

	-- what the server refuses in the menu (`start`): every mode and queue, every state, waiting or not
	local R = GameModes.REFUSALS
	expect(R.crossWaiting == "YOUR RANKED MATCH IS ABOUT TO START" and R.loading == "YOUR SAVE IS NOT LOADED YET"
		and R.rankedUnsaved == "RANKED NEEDS YOUR SAVE: SAVES UNAVAILABLE", "the texts")
	local requests = {}
	for _, mode in GameModes.List do
		for _, queue in (if mode.queue then { "NORMAL", "RANKED" } else { false }) do
			local r = GameModes.validate({ mode = mode.id, team = { "KAI" }, level = 2, queue = queue or nil }, MoveData.KitOrder)
			expect(r ~= nil, mode.id .. ": not a valid request")
			table.insert(requests, r)
		end
	end
	for _, r in requests do
		local name = r.mode .. (if r.queue then " " .. r.queue else "")
		local ranked = r.mode == "VERSUS" and r.queue == "RANKED"
		-- (B-039: waiting for the cross-server match: nothing at all, TRAINING included)
		for _, state in { "loaded", "loading", "failed" } do
			expect(GameModes.startRefusal(r, state, true) == R.crossWaiting, name .. " started while a cross-server RANKED match is about to start (" .. state .. ")")
		end
		expect(GameModes.startRefusal(r, "loaded", false) == nil, name .. " refused on a loaded save")
		-- (B-035: only TRAINING while loading; a state the rule does not know counts as loading)
		for _, state in { "loading", nil, "?" } do
			local got = GameModes.startRefusal(r, state, false)
			expect(got == (if r.mode == "TRAINING" then nil else R.loading), name .. " while loading (" .. tostring(state) .. "): " .. tostring(got))
		end
		-- (B-042: after a failed load everything is played unsaved but RANKED)
		local got = GameModes.startRefusal(r, "failed", false)
		expect(got == (if ranked then R.rankedUnsaved else nil), name .. " after a failed load: " .. tostring(got))
	end

	-- the reserved server's verdict, each player loaded, loading, failed or gone (left)
	local STATES = { "loaded", "loading", "failed", "gone" }
	for _, a in STATES do
		for _, b in STATES do
			for _, t in { 0, 3, 15, 20, 64, 65, 73, 74, 81, 82, 90, 107, G.PROFILE_CAP - 0.5, G.PROFILE_CAP, G.PROFILE_CAP + 30 } do
				local v = G.crossStart(a, b, t)
				local want
				if a == "gone" or b == "gone" then
					want = "cancel" -- (W3: the one who stays is told, never left waiting)
				elseif a == "failed" or b == "failed" then
					want = "cancel" -- (B-042: never on the default 1000 points; it started before)
				elseif a == "loaded" and b == "loaded" then
					want = "start"
				else
					want = if t < G.PROFILE_CAP then "wait" else "cancel" -- (a load still on its way: no fixed wait)
				end
				expect(v == want, string.format("crossStart(%s, %s, %s s) = %s, not %s", a, b, tostring(t), tostring(v), want))
			end
		end
	end
	-- what each player still there reads when the match does not start
	local N = G.NOTICES
	expect(N.failed == R.rankedUnsaved, "the reserved server and the menu say the same after a failed load")
	local notices = {
		{ "loaded", "gone", N.gone }, { "loading", "gone", N.gone }, { "failed", "gone", N.gone },
		{ "failed", "loaded", N.failed }, { "failed", "loading", N.failed }, { "failed", "failed", N.failed },
		{ "loaded", "failed", N.theirsFailed }, { "loading", "failed", N.theirsFailed },
		{ "loading", "loaded", N.loading }, { "loading", "loading", N.loading }, { "loaded", "loading", N.theirsLoading },
	}
	for _, row in notices do
		expect(G.crossNotice(row[1], row[2]) == row[3], string.format("crossNotice(%s, %s) = %s", row[1], row[2], tostring(G.crossNotice(row[1], row[2]))))
	end
	expect(N.gone == "YOUR OPPONENT LEFT: search again" and N.theirsFailed == "YOUR OPPONENT'S SAVE COULD NOT BE LOADED: search again", "the texts")

	-- waiting on the reserved server, from the arrival until the match starts or is called off
	expect(not G.waiting(nil), "a player of no cross-server match waits")
	local pending = { expect = { 1, 2 }, created = 0 }
	expect(G.waiting(pending), "arrived: not waiting")
	pending.settled = true
	expect(not G.waiting(pending), "started or called off: still waiting")
	-- the search across servers publishes (and teleports) only a player still searching from here
	local now = 5000
	expect(G.publishable("RANKED", now - G.PUBLISH_AFTER, false, false, now), "a RANKED search of PUBLISH_AFTER s is not published")
	expect(not G.publishable("RANKED", now - G.PUBLISH_AFTER + 1, false, false, now), "published too early")
	expect(not G.publishable("NORMAL", now - 100, false, false, now) and not G.publishable(nil, now - 100, false, false, now), "not RANKED, published")
	expect(not G.publishable("RANKED", nil, false, false, now), "published without a search time")
	expect(not G.publishable("RANKED", now - 100, true, false, now), "published while in a match (W2: during its RANKED match, then teleported out of it)")
	expect(not G.publishable("RANKED", now - 100, false, true, now), "published while waiting on the reserved server (W2: before its RANKED match)")

	-- THE WHOLE LOAD CYCLE (the mirror of loadProfile, saveWorld): G arrives on the reserved
	-- server; its profile is still locked by server B (G just left it) until B lets it go
	-- `release` s later (math.huge: never), or the DataStore fails (`failing`). F is loaded. Every
	-- second the reserved server decides on G's state (crossStart). The decision must follow the
	-- load's own end: started when G's save is in, called off when the load failed, never a
	-- fixed wait (65 s cancelled loads that ended from 66 to 73 s; 82 s or more started on 1000).
	local function reserved(release, failing)
		local loading, calls = true, 0
		local w = saveWorld(SaveQueue, G, { down = function()
			if loading then calls += 1 end -- (one UpdateAsync of the load)
			return failing == true
		end })
		w.store[7] = G.stamp({ v = 5 }, "B", 0, release <= 0) -- (G's save, locked by server B)
		local g = w.arrive(7, 0)
		local r = { calls = 0 }
		w.run(0, 250, function(t) -- (long enough for any load and any PROFILE_CAP worth keeping)
			if loading and g.profileLoaded then
				loading, r.ended, r.loaded = false, t, SaveQueue.isLoaded(w.q, 7, g)
			end
			if loading then -- (B renews its lock until it lets it go: its last write releases it)
				w.store[7]._session = if t + 1 < release then { job = "B", t = t + 1 } else nil
			end
			if not r.verdict then
				local v = G.crossStart("loaded", GameModes.saveState(true, g.profileLoaded, SaveQueue.isLoaded(w.q, 7, g)), t)
				if v ~= "wait" then r.verdict, r.at = v, t end
			end
		end)
		r.calls = calls
		return r
	end
	-- a lock never let go: the longest load, read from the modules (they may change)
	local tries = math.ceil((G.LOCK_TTL + 5) / G.LOCK_RETRY) -- (loadProfile: a try every LOCK_RETRY s while waited < LOCK_TTL + 5)
	local tail = 0
	for k = 1, SaveQueue.LOAD_TRIES do tail += SaveQueue.retryDelay(k) end
	local longest = reserved(math.huge)
	expect(longest.ended == tries * G.LOCK_RETRY + tail and longest.calls == tries + SaveQueue.LOAD_TRIES,
		string.format("the mirror's longest load: %s s, %d calls (expected %d s, %d calls)", tostring(longest.ended), longest.calls,
			tries * G.LOCK_RETRY + tail, tries + SaveQueue.LOAD_TRIES))
	expect(not longest.loaded and longest.verdict == "cancel" and longest.at == longest.ended,
		string.format("a lock never let go: SAVES UNAVAILABLE at %s s, then %s at %s s (never a RANKED match on 1000 points)",
			tostring(longest.ended), tostring(longest.verdict), tostring(longest.at)))
	-- (today 81 s and 26 DataStore calls; PROFILE_CAP is only a net above it, with 1 s per call)
	expect(G.PROFILE_CAP > (longest.ended or math.huge) + longest.calls * 1, string.format("PROFILE_CAP %s s is not above the longest load: %s s + %d calls of 1 s",
		tostring(G.PROFILE_CAP), tostring(longest.ended), longest.calls))
	-- every release from 0 to 140 s (the hunt's table: 55 to 130 s): the verdict comes when the load ends
	local lastLoaded = nil
	for release = 0, 140 do
		local r = reserved(release)
		expect(r.ended ~= nil and r.at == r.ended, string.format("lock let go at %d s: load ended at %s s, verdict at %s s", release, tostring(r.ended), tostring(r.at)))
		if r.loaded then
			lastLoaded = release
			expect(r.verdict == "start", string.format("lock let go at %d s: G's save loaded at %s s, but the match is %s at %s s (cancelled for nothing)",
				release, tostring(r.ended), tostring(r.verdict), tostring(r.at)))
		else
			expect(r.verdict == "cancel", string.format("lock let go at %d s: SAVES UNAVAILABLE at %s s, but the match is %s at %s s on 1000 points",
				release, tostring(r.ended), tostring(r.verdict), tostring(r.at)))
		end
		expect((r.at or math.huge) < G.PROFILE_CAP, string.format("lock let go at %d s: decided by PROFILE_CAP (%s s), not by the load", release, tostring(r.at)))
	end
	expect(lastLoaded == tries * G.LOCK_RETRY + tail - SaveQueue.retryDelay(SaveQueue.LOAD_TRIES),
		"the last lock that still loads: " .. tostring(lastLoaded) .. " s (73 s: the last try of loadProfile)")
	-- the DataStore down (Z2): SAVES UNAVAILABLE after the tries, the match called off then (it started on 1000 before)
	local down = reserved(0, true)
	expect(not down.loaded and down.ended == tail and down.verdict == "cancel" and down.at == tail,
		string.format("DataStore down: load ended at %s s, %s at %s s", tostring(down.ended), tostring(down.verdict), tostring(down.at)))
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
		"⚙ TOOLS +", "⚙ TOOLS −", "FIGHTER", "TRAINING", "DISPLAY",
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

test("economy: PvP 150 / 50, 8 free fighters, priced by tier, kept forever, TRAINING tries them all", function()
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
	local akemi = Economy.fighterPrice("AKEMI")
	local buyer = { coins = akemi - 1 }
	local ok, why = Economy.buyFighter(buyer, "AKEMI", MoveData.KitOrder)
	expect(not ok and why == "coins" and buyer.coins == akemi - 1, "bought without the coins")
	buyer.coins = akemi + 100
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

test("tiers: every fighter has one, the free ones are STANDARD, striking ones cost more, styles follow their fighter", function()
	local Economy = require("../src/shared/Economy")
	local CharacterData = require("../src/shared/CharacterData")
	local order = { STANDARD = 1, RARE = 2, EPIC = 3, LEGENDARY = 4 }
	for _, kit in MoveData.KitOrder do
		local tier = Economy.TIER_OF[kit]
		expect(tier and Economy.TIERS[tier], kit .. " has no tier")
		expect((tier == "STANDARD") == Economy.isFree(kit), kit .. ": free and STANDARD disagree")
	end
	for a, ta in Economy.TIERS do
		for b, tb in Economy.TIERS do
			if order[a] < order[b] then
				expect(ta.fighter < tb.fighter and ta.skin < tb.skin, a .. " is not cheaper than " .. b)
			end
		end
	end
	expect(Economy.fighterPrice("KAI") == 0 and Economy.fighterPrice("KUROEN") > Economy.fighterPrice("HIBIKI"), "fighter prices")
	expect(Economy.skinPrice("KUROEN") > Economy.skinPrice("KAI"), "a legendary fighter's style is not dearer")
	for name, item in CharacterData.SHOP do
		expect(Economy.skinPrice(item.kit) == Economy.tierOf(item.kit).skin, name .. " is not priced by its fighter's tier")
	end
	local p = { coins = 3500 }
	expect(CharacterData.buy(p, "KUROEN GOLD", Economy.skinPrice("KUROEN")) or CharacterData.SHOP["KUROEN GOLD"] == nil, "a legendary style")
end)

test("styles: quest styles not sold, equipped style kept only while it is yours", function()
	local CharacterData = require("../src/shared/CharacterData")
	local Quests = require("../src/shared/Quests")
	for name, item in CharacterData.SHOP do
		expect(item.quest == (Quests.BY_REWARD[name] ~= nil), name .. ": quest mark and quest list disagree")
	end
	for _, q in Quests.LIST do
		expect(CharacterData.SHOP[q.reward] ~= nil and CharacterData.QUEST[q.reward], q.id .. "'s reward " .. q.reward .. " is not a quest style")
	end
	local p = { coins = 99999 }
	local ok, why = CharacterData.buy(p, "KAI INFERNO", 1500)
	expect(not ok and why == "quest" and p.coins == 99999, "a quest style was sold")
	-- equip: worn only if it is the fighter's and still yours
	p.equipped = { KAI = "KAI GOLD" }
	expect(CharacterData.styleFor("KAI", p, nil, false) == "CLASSIC", "an unbought style is worn")
	CharacterData.buy(p, "KAI GOLD", 1500)
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

test("tutorial and tiers: every line reads in French", function()
	local Locale = require("../src/shared/Locale")
	local Tutorial = require("../src/shared/Tutorial")
	local Economy = require("../src/shared/Economy")
	local lines = { "WELCOME TO BREAKFRAMEZ", "▶ START THE TUTORIAL", "SKIP", "SKIP ✕", "CLOSE ✕", "TUTORIAL", "TUTORIAL · 3 / 10",
		"TUTORIAL COMPLETE", "YOU'RE READY! ✓", "TUTORIAL: SETTINGS › TUTORIAL, whenever you want",
		"New here? A short TUTORIAL shows the controls and how a fight works: move, attack, combos, guard, specials and ultimates.",
		"About 2 minutes, in TRAINING with KAI. You can skip it at any time, and replay it from SETTINGS.",
		"Keep training here as long as you like, or ◀ MENU to fight the CPU or other players online.",
		"🔒 LEGENDARY · 6000 COINS · YOU HAVE 120", "🔒 2500 COINS · EPIC" }
	for _, step in Tutorial.STEPS do
		table.insert(lines, step.title)
		table.insert(lines, step.text)
		for _, k in step.keys do table.insert(lines, k) end
	end
	for _, tier in Economy.TIERS do table.insert(lines, tier.name) end
	for _, line in lines do
		local fr = Locale.translate(line, "FR")
		expect(fr ~= line or Locale.SAME[line], "no French for: " .. line)
	end
end)

test("HUD textures: every id is a whole number (0 = not uploaded yet, the drawn look stays), each names its PNG", function()
	local UIArt = require("../src/shared/UIArt")
	local count = 0
	for name, image in UIArt.Images do
		count += 1
		expect(type(image.id) == "number" and image.id >= 0 and image.id == math.floor(image.id), name .. ": bad id")
		expect(type(image.file) == "string" and image.file:sub(-4) == ".png", name .. ": no PNG")
		expect(UIArt.asset(name) == (if image.id == 0 then nil else "rbxassetid://" .. image.id), name .. ": asset string")
		if image.slice then
			local l, t, r, b = table.unpack(image.slice)
			expect(l > 0 and t > 0 and r < image.size[1] and b < image.size[2] and l < r and t < b, name .. ": slice outside the PNG")
		end
	end
	expect(count == 7, "seven textures")
	expect(UIArt.asset("Nothing") == nil, "an unknown texture has no asset")
end)

test("VFX pack: every id a whole number (0 = not uploaded), every need a known asset, every fighter covered", function()
	local VfxConfig = require("../src/shared/VfxConfig")
	local textures, meshes = 0, 0
	for key, id in VfxConfig.TEXTURES do
		textures += 1
		expect(type(id) == "number" and id >= 0 and id == math.floor(id), key .. ": bad id")
		expect(VfxConfig.texture(key) == (if id == 0 then nil else "rbxassetid://" .. id), key .. ": content id")
		expect(VfxConfig.MESHES[key] == nil, key .. ": both a texture and a mesh")
		expect(string.sub(VfxConfig.file(key), -4) == ".png", key .. ": its file is not a PNG")
	end
	for key, id in VfxConfig.MESHES do
		meshes += 1
		expect(type(id) == "number" and id >= 0 and id == math.floor(id), key .. ": bad id")
		expect(VfxConfig.file(key) == "meshes/VFX_COMMON_" .. key .. ".fbx", key .. ": its file")
	end
	expect(textures == 105 and meshes == 25, ("the pack: %d textures, %d meshes"):format(textures, meshes))
	local function known(need, what)
		for _, key in need.textures do expect(VfxConfig.TEXTURES[key] ~= nil, what .. " needs an unknown texture " .. key) end
		for _, key in need.meshes do expect(VfxConfig.MESHES[key] ~= nil, what .. " needs an unknown mesh " .. key) end
	end
	known(VfxConfig.COMMON, "COMMON")
	known(VfxConfig.KAME, "KAME")
	for kit, need in VfxConfig.KITS do
		known(need, kit)
		expect(MoveData.Kits[kit] ~= nil, kit .. " is not a fighter of the game")
	end
	for kit in MoveData.Kits do
		expect(VfxConfig.KITS[kit] ~= nil, kit .. " has no effects in the pack")
		local need = VfxConfig.kitNeed(kit)
		expect(#need.textures == #VfxConfig.COMMON.textures + #VfxConfig.KITS[kit].textures, kit .. ": the shared assets are not in its need")
	end
	expect(VfxConfig.kitNeed("NOBODY") == nil and not VfxConfig.kitReady("NOBODY"), "an unknown fighter is ready")
	expect(VfxConfig.file("GLOW_CORE") == "textures/VFX_COMMON_GLOW_CORE.png" and VfxConfig.file("KAI_KI_POP_4x4") == "textures/VFX_KAI_KI_POP_4x4.png",
		"file names")
	-- ready once every asset of the need is uploaded, and only then
	local saved = table.clone(VfxConfig.TEXTURES)
	local savedMeshes = table.clone(VfxConfig.MESHES)
	for key in VfxConfig.TEXTURES do VfxConfig.TEXTURES[key] = 0 end
	for key in VfxConfig.MESHES do VfxConfig.MESHES[key] = 0 end
	expect(not VfxConfig.kitReady("KAI") and #VfxConfig.missing(VfxConfig.kitNeed("KAI")) > 0, "KAI ready with nothing uploaded")
	for i, key in VfxConfig.kitNeed("KAI").textures do VfxConfig.TEXTURES[key] = 1000 + i end
	expect(not VfxConfig.kitReady("KAI"), "KAI ready without its meshes")
	for i, key in VfxConfig.kitNeed("KAI").meshes do VfxConfig.MESHES[key] = 2000 + i end
	expect(VfxConfig.kitReady("KAI") and VfxConfig.ready(VfxConfig.COMMON), "KAI not ready with all its assets")
	expect(not VfxConfig.kitReady("YUKINA"), "YUKINA ready without her own assets")
	VfxConfig.TEXTURES[VfxConfig.KITS.KAI.textures[1]] = 0
	expect(not VfxConfig.kitReady("KAI") and VfxConfig.missing(VfxConfig.kitNeed("KAI"))[1] == VfxConfig.KITS.KAI.textures[1],
		"one missing texture does not stop KAI")
	for key, id in saved do VfxConfig.TEXTURES[key] = id end
	for key, id in savedMeshes do VfxConfig.MESHES[key] = id end
end)

test("the fight snapshot on the wire: short names, everything comes back as it was, unknown fields pass through", function()
	local Wire = require("../src/shared/Wire")
	expect(Wire.check(), "Wire: a name twice or more names than codes")
	local fighter = { roster = nil, skin = "KAI_BASE", custom = { 1, 2 } }
	for i, name in Wire.FIGHTER do fighter[name] = if i % 3 == 0 then "s" .. i elseif i % 3 == 1 then i * 1.5 else i % 2 == 0 end
	local packet = { fighters = { fighter, table.clone(fighter) }, roster = { { name = "A" } }, extra = 7 }
	for i, name in Wire.PACKET do
		if name ~= "fighters" and name ~= "roster" then packet[name] = i end
	end
	local wire = Wire.encode(packet)
	for k in wire do
		expect(packet[k] == nil or #k == 1 or k == "extra", "a long name left on the wire: " .. k)
	end
	local back = Wire.decode(wire)
	for k, v in packet do
		if k ~= "fighters" then expect(back[k] == v, "packet field lost: " .. k) end
	end
	for slot = 1, 2 do
		for k, v in fighter do expect(back.fighters[slot][k] == v, "fighter field lost: " .. k) end
	end
	-- (one-letter names would be read as codes: every field of the snapshot is longer, or listed)
	for _, name in Wire.FIGHTER do expect(#name >= 1, "empty name") end
end)

test("owner commands: only the owner, !give coins / fighter / style / title / item, players by name, never a pass item", function()
	local Admin = require("../src/server/Admin")
	local DevAccess = require("../src/server/DevAccess")
	local StoreConfig = require("../src/shared/StoreConfig")
	local Store = require("../src/shared/Store")
	local idx = Store.index(StoreConfig)
	-- who: the owner only (his ids, or the user who owns the game), never a Studio test player
	expect(DevAccess.isOwner(DevAccess.IDS[1], 0, false), "Wilhem is not the owner")
	expect(DevAccess.isOwner(42, 42, true) and not DevAccess.isOwner(42, 42, false), "the user-owned game's owner")
	expect(not DevAccess.isOwner(7, 42, true) and not DevAccess.isOwner(-1, -1, true), "someone else is the owner")
	-- reading the line
	expect(Admin.parse("hello") == nil and Admin.parse("!dance") == nil, "a chat line read as a command")
	local c = Admin.parse("!give Bob coins 1000")
	expect(c and c.target == "Bob" and c.kind == "coins" and c.amount == 1000, "!give coins not read")
	local _, why = Admin.parse("!give Bob coins -5")
	expect(why ~= nil and select(1, Admin.parse("!give Bob coins 99999999")) == nil, "bad amounts accepted")
	expect(Admin.parse("!help").verb == "help", "!help")
	-- giving
	local catalogs = { kits = MoveData.KitOrder, styles = { KAI_NEON = true }, items = idx.item, titles = { "ASURA SLAYER" } }
	local profile = { coins = 10 }
	expect(Admin.apply(profile, c, catalogs) and profile.coins == 1010, "coins not given")
	expect(Admin.apply(profile, Admin.parse("!give me fighter zephyr"), catalogs) and profile.ownedKits.ZEPHYR, "fighter not given")
	expect(Admin.apply(profile, Admin.parse("!give me fighter all"), catalogs) and profile.ownedKits.KAZAN ~= nil or profile.ownedKits[MoveData.KitOrder[#MoveData.KitOrder]], "every fighter")
	expect(Admin.apply(profile, Admin.parse("!give me style kai neon"), catalogs) and profile.ownedSkins.KAI_NEON, "style not given")
	expect(Admin.apply(profile, Admin.parse("!give me title asura slayer"), catalogs) and table.find(profile.titles, "ASURA SLAYER"), "title not given")
	local shopTitle, passTitle
	for id, item in idx.item do
		if item.kind == "TITLE" and not item.pass and not shopTitle then shopTitle = item end
		if item.pass and not passTitle then passTitle = item end
	end
	expect(Admin.apply(profile, Admin.parse("!give me title " .. shopTitle.name), catalogs) and profile.ownedItems[shopTitle.id], "shop title")
	if passTitle then
		expect(not Admin.apply(profile, Admin.parse("!give me item " .. passTitle.id), catalogs), "a Game Pass item was given")
	end
	expect(not Admin.apply(profile, Admin.parse("!give me fighter NOBODY"), catalogs), "an unknown fighter was given")
	-- players by name
	local players = { { id = 1, name = "Laveine972", display = "Wilhem" }, { id = 2, name = "BobTheBuilder", display = "Bob" },
		{ id = 3, name = "Bobby", display = "Bobby" } }
	expect(#Admin.targets("me", players, 1) == 1 and Admin.targets("me", players, 1)[1].id == 1, "me")
	expect(#Admin.targets("all", players, 1) == 3, "all")
	expect(#Admin.targets("bob", players, 1) == 1 and Admin.targets("bob", players, 1)[1].id == 2, "an exact name first")
	expect(#Admin.targets("bobt", players, 1) == 1, "the start of a name")
	expect(#Admin.targets("zz", players, 1) == 0, "nobody")
end)

-- B-021: the join keeps only the fields of Profile.default (of the same type). The 2v2 / 3v3
-- ratings, the titles' feats and their stars were not there: lost at each join, then erased
-- from the save by the first write of the session.
test("saved profile: everything the modules write comes back at the next join (2v2 / 3v3 ratings, feats, earned titles)", function()
	local Profile = require("../src/server/Profile")
	local Taunts = require("../src/shared/Taunts")
	local Economy = require("../src/shared/Economy")
	local Quests = require("../src/shared/Quests")
	local Store = require("../src/shared/Store")
	local StoreConfig = require("../src/shared/StoreConfig")
	local CharacterData = require("../src/shared/CharacterData")
	local Champions = require("../src/server/Champions")
	local AC = require("../src/server/AntiCheat")
	local Admin = require("../src/server/Admin")
	local G = require("../src/server/GlobalQueue")
	local deps = { startRating = Matchmaker.START_RATING, taunts = Taunts.DEFAULT, achievementSeason = GameModes.ACHIEVEMENT_SEASON }
	local defaults = Profile.default(deps)
	for _, k in { "ratings", "feats", "earnedTitles" } do
		expect(type(defaults[k]) == "table", "no " .. k .. " table in Profile.default: it is lost at each join")
	end
	-- (the DataStore keeps plain values: a save is a deep copy)
	local function copy(v)
		if type(v) ~= "table" then return v end
		local out = {}
		for k, x in v do out[k] = copy(x) end
		return out
	end
	local function same(a, b, path)
		if type(a) ~= "table" or type(b) ~= "table" then
			return a == b, path .. ": " .. tostring(a) .. " then " .. tostring(b)
		end
		for k, v in a do
			local ok, why = same(v, b[k], path .. "." .. tostring(k))
			if not ok then return false, why end
		end
		for k, v in b do
			if a[k] == nil then return false, path .. "." .. tostring(k) .. ": nil then " .. tostring(v) end
		end
		return true, ""
	end

	-- A whole session through every module that writes in the profile, and the server's own
	-- writes (init.server.luau). A field missing from the defaults is caught as it is written.
	-- A NEW WRITER of the profile goes in this list.
	local added = {}
	local p = setmetatable(Profile.default(deps), { __newindex = function(t, k, v)
		added[tostring(k)] = true
		rawset(t, k, v)
	end })
	local now = 1760000000
	local idx = Store.index(StoreConfig)
	-- RANKED (Matchmaker): 1v1, 2v2, 3v3
	Matchmaker.setRating(p, 1, 1180)
	Matchmaker.setRating(p, 2, 1240)
	Matchmaker.setRating(p, 3, 1310)
	-- TITLES (GameModes): 5 K.O. by a FATAL BLOW (NO MERCY earned), 24 guard breaks (BREAKER: 24 / 25)
	local fatal
	for name, m in MoveData.Moves do
		if m.fatal then fatal = name break end
	end
	for _ = 1, 5 do GameModes.featEvent(p, { kind = "Hit", attacker = 1, combo = 12, move = fatal, ko = true }, 1, MoveData.Moves) end
	for _ = 1, 24 do GameModes.featEvent(p, { kind = "GuardBreak", attacker = 1 }, 1, MoveData.Moves) end
	GameModes.featEvent(p, { kind = "RoundEnd", winner = 1, perfect = true }, 1, MoveData.Moves)
	GameModes.featEvent(p, { kind = "PromptGrade", attacker = 1, grade = "PERFECT" }, 1, MoveData.Moves)
	p.asuraGrade, p.asuraDamage, p.shinGrade = 2, 87, 1 -- (the server: CHALLENGE · ASURA, KUROEN SHIN)
	GameModes.featBosses(p)
	local earned = GameModes.grantFeatTitles(p)
	expect(#earned == 2 and table.find(earned, "NO MERCY") and table.find(earned, "FINAL BOSS"), "the session's titles: " .. table.concat(earned, ", "))
	-- ACHIEVEMENTS, coins, MATCH HISTORY (GameModes)
	GameModes.achievementSeason(p)
	GameModes.achievementProgress(p, { won = true })
	GameModes.achievementProgress(p, { rating = 1180, survival = 4, asuraDamage = 87, asuraGrade = 2, shinGrade = 1 })
	GameModes.addCoins(p, "win")
	GameModes.addHistory(p, { t = now, mode = "VERSUS", queue = "RANKED", opp = "BOB", oppKit = "TARO", kit = "KAI", r = "W", coins = 150, delta = 18 })
	-- the owner's commands (Admin)
	local catalogs = { kits = MoveData.KitOrder, styles = CharacterData.Skins, items = idx.item, titles = GameModes.CHALLENGE_TITLES }
	for _, line in { "!give me coins 60000", "!give me fighter zephyr", "!give me style raijin gold", "!give me title asura slayer",
		"!give me item EMOTE_CALCULATED" } do
		expect(Admin.apply(p, Admin.parse(line), catalogs), "the owner's " .. line)
	end
	-- FIGHTERS, DAILY REWARD, WIN STREAK (Economy); a shop style (CharacterData)
	expect(Economy.buyFighter(p, "AKEMI", MoveData.KitOrder), "a fighter bought")
	p.freePicks = 1 -- (an old tester's pick)
	expect(Economy.claimFighter(p, "SHIN", MoveData.KitOrder), "a free pick")
	expect(Economy.claimDaily(p, Economy.dayOf(now)) ~= nil, "the daily reward")
	Economy.streak(p, "win", true)
	local style
	for name, item in CharacterData.SHOP do
		if not item.quest and not p.ownedSkins[name] then style = name break end
	end
	expect(CharacterData.buy(p, style, Economy.skinPrice(CharacterData.SHOP[style].kit)), "a shop style bought")
	-- the SHOP (Store): a title and an aura bought, the aura worn, a pass, two Robux receipts
	expect(Store.buyItem(idx, p, "TITLE_BREAKER"), "a shop title")
	expect(Store.buyItem(idx, p, "VFX_EMBER") and Store.equip(idx, p, "VFX", "VFX_EMBER"), "an aura worn")
	expect(Store.setPass(p, "VIP", true), "a pass")
	expect(Store.grantReceipt(p, "receipt-1", idx.product.COINS_1000, now) == "granted", "coins for Robux")
	expect(Store.grantReceipt(p, "receipt-2", idx.product.SKIN_KAI_GOLD, now) == "granted", "a style for Robux")
	-- QUESTS
	for _ = 1, 30 do Quests.record(p, { won = true, pvp = true, kits = { "KAI" } }) end
	Quests.grant(p)
	-- WEEKLY ranking and CHAMPION OF THE WEEK (Champions)
	local week = Champions.week(now)
	Champions.addPoints(p, week, "win", 1)
	expect(Champions.grant(p, 42, { { week = week - 1, id = 42, name = "WILHEM", rating = 1500 } }) == 1, "the champion's title")
	-- ANTI-CHEAT: today's opponents, the coins of the day
	AC.record(p, 7, now)
	p.coins += AC.capCoins(p, 150, now)
	-- the server: a match, the menu, SETTINGS, the taunts' wheel, a title worn, a style worn
	p.wins += 1
	p.losses += 1
	p.survivalBest, p.hero, p.language, p.howToPlay, p.devOff = 4, "AKEMI", "FR", 3, true
	p.optReduced, p.optSound, p.optMusic, p.optTaunts, p.tauntKey = true, false, false, false, "T"
	p.taunts = Taunts.sanitize({ "calculated", "ez" }, p)
	p.title = "NO MERCY"
	p.equipped.RAIJIN = "RAIJIN GOLD"
	setmetatable(p, nil)
	local unknown = {}
	for k in added do table.insert(unknown, k) end
	table.sort(unknown)
	expect(#unknown == 0, "written in the profile but not in Profile.default (lost at the next join): " .. table.concat(unknown, ", "))
	for k, v in p do
		expect(type(defaults[k]) == type(v), "the profile's " .. tostring(k) .. " is a " .. type(v) .. ", its default a "
			.. type(defaults[k]) .. ": dropped at the next join")
	end

	-- The save (writeProfile: the profile with the session lock, GlobalQueue.stamp), the next
	-- join (Profile.merge, as loadProfile), that session's first write, and the join after it.
	local loaded = Profile.merge(Profile.default(deps), copy(G.stamp(p, "server-A", now, false)), deps)
	local ok, why = same(p, loaded, "profile")
	expect(ok, "changed by a save and the next join: " .. why)
	expect(loaded._session == nil, "the session lock came into the profile")
	local again = Profile.merge(Profile.default(deps), copy(G.stamp(loaded, "server-B", now + 60, false)), deps)
	ok, why = same(p, again, "profile")
	expect(ok, "lost after the first write of the next session: " .. why)
	-- what the player sees after the join
	expect(Matchmaker.ratingOf(again, 1) == 1180 and Matchmaker.ratingOf(again, 2) == 1240 and Matchmaker.ratingOf(again, 3) == 1310
		and Matchmaker.played(again, 2) and Matchmaker.played(again, 3), "the RANKED ratings after a join")
	expect(GameModes.featProgress(again, "BREAKER") == 24 and GameModes.featProgress(again, "NO MERCY") == 5, "the titles' feats after a join")
	expect(GameModes.titleDisplay(again, "NO MERCY") == "NO MERCY ★" and GameModes.titleDisplay(again, "BREAKER") == "BREAKER",
		"the star of a title earned by playing (and none for a bought one) after a join")
	expect(#GameModes.grantFeatTitles(again) == 0, "a title earned a second time after a join")

	-- The merge: a saved value of another type keeps the default (never a broken value in the
	-- game), the others are taken; nothing saved: a new player, on no 2v2 / 3v3 board.
	local broken = Profile.merge(Profile.default(deps), { ratings = 1240, feats = "x", earnedTitles = true, coins = "999", wins = 3 }, deps)
	expect(next(broken.ratings) == nil and next(broken.feats) == nil and next(broken.earnedTitles) == nil and broken.coins == 0
		and broken.wins == 3, "a saved value of another type")
	local fresh = Profile.merge(Profile.default(deps), nil, deps)
	expect((same(fresh, defaults, "new")) and not Matchmaker.played(fresh, 2) and not Matchmaker.played(fresh, 3)
		and Matchmaker.ratingOf(fresh, 3) == Matchmaker.START_RATING, "a new player's profile")
	-- two profiles never share a table (nor the taunts' list of Taunts)
	local other = Profile.default(deps)
	for k, v in defaults do
		expect(type(v) ~= "table" or v ~= other[k], "two new profiles share their " .. k)
	end
	expect(defaults.taunts ~= Taunts.DEFAULT, "a profile shares Taunts.DEFAULT")
end)

T.finish()
