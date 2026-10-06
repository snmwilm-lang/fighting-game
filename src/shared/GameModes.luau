--[[
	Game modes of the main menu (Street Fighter style) and their rules. Pure Luau (no Roblox
	API, no require): the server validates a menu request with it and runs the match, the
	client draws the menu from the same list; tests/Lobby.test.luau checks the rules.

	  GameModes.List                       -- menu order: id, name, description, options
	  GameModes.validate(request, kitOrder) -- sanitized request or nil, reason
	  GameModes.survivalOpponent(wave, n)   -- the CPU kit and level of a SURVIE wave
	  GameModes.cpuTeam(size, kitOrder, n)  -- a CPU team of `size` different kits
]]
local GameModes = {}

GameModes.MAX_TEAM = 3

GameModes.List = {
	{ id = "VERSUS_CPU", name = "1 VS 1 · CPU", kanji = "戦",
		description = "You against the CPU. Pick 1, 2 or 3 fighters (tag) and the level.", team = true, level = true },
	{ id = "VERSUS", name = "1 VS 1 · PLAYER", kanji = "対",
		description = "Against a real player: NORMAL or RANKED (points), or challenge a friend on the server.", team = true, queue = true },
	{ id = "SURVIVAL", name = "SURVIVAL", kanji = "生",
		description = "One fighter, opponents one after another, stronger and stronger. Your health only comes back a little.", team = false },
	{ id = "TRAINING", name = "TRAINING", kanji = "練",
		description = "Dummy, CPU, combo trainer, ultimate conditions.", team = false },
	{ id = "CHALLENGE", name = "CHALLENGE · ASURA", kanji = "阿",
		description = "ASURA, a four-armed KAI, out of the Gate of Heaven. Bring 1 to 3 fighters. Your victory decides your reward.",
		team = true, boss = "ASURA", grade = "asuraGrade" },
	{ id = "CHALLENGE_SHIN", name = "CHALLENGE · KUROEN SHIN", kanji = "真",
		description = "KUROEN past every limit, born at ECLIPSE. Bring 1 to 3 fighters. Beat him to earn KUROEN's DIVINE ECLIPSE style.",
		team = true, boss = "KUROEN SHIN", grade = "shinGrade" },
}

GameModes.QUEUES = { NORMAL = true, RANKED = true }

local function find(id)
	for _, mode in GameModes.List do
		if mode.id == id then return mode end
	end
	return nil
end
GameModes.find = find

-- A menu request from a client: { mode, team = { kits }, level, queue }. Everything a
-- client sends is checked: unknown modes and kits, locked modes, team sizes.
function GameModes.validate(request, kitOrder, maps)
	if type(request) ~= "table" then return nil, "invalid request" end
	local mode = type(request.mode) == "string" and find(request.mode)
	if not mode then return nil, "unknown mode" end
	if mode.locked then return nil, "locked mode" end
	local known = {}
	for _, kit in kitOrder do known[kit] = true end
	local team = {}
	if type(request.team) == "table" then
		for i = 1, GameModes.MAX_TEAM do
			local kit = request.team[i]
			if kit == nil then break end
			if type(kit) ~= "string" or not known[kit] then return nil, "unknown fighter" end
			table.insert(team, kit)
		end
	end
	if #team == 0 then return nil, "no fighter picked" end
	if not mode.team and #team > 1 then team = { team[1] } end
	local out = { mode = mode.id, team = team }
	if mode.level then
		local level = request.level
		if type(level) ~= "number" or level % 1 ~= 0 or level < 1 or level > 4 then return nil, "invalid level" end
		out.level = level
	end
	if mode.queue then
		if type(request.queue) ~= "string" or not GameModes.QUEUES[request.queue] then return nil, "invalid queue" end
		out.queue = request.queue
	end
	-- the stage (Maps): nil or "RANDOM" = drawn by the server
	if request.map ~= nil then
		if type(request.map) ~= "string" or (request.map ~= "RANDOM" and not (maps and maps[request.map])) then return nil, "invalid stage" end
		if request.map ~= "RANDOM" then out.map = request.map end
	end
	return out
end

-- SURVIE: wave 1 is easy, the level climbs every few waves, LÉGENDE from wave 8. `n` is a
-- number chosen by the caller (random on the server, fixed in the tests) to pick the kit.
function GameModes.survivalOpponent(wave, kitOrder, n)
	local level = if wave <= 2 then 1 elseif wave <= 4 then 2 elseif wave <= 7 then 3 else 4
	local kit = kitOrder[(n + wave * 3) % #kitOrder + 1]
	return kit, level
end

-- A CPU team of `size` different kits, starting from position `n` of the roster.
function GameModes.cpuTeam(size, kitOrder, n)
	local team = {}
	for i = 1, math.clamp(size, 1, GameModes.MAX_TEAM) do
		team[i] = kitOrder[(n + (i - 1) * 3) % #kitOrder + 1]
	end
	return team
end

-- CHALLENGE: the reward is decided by how the boss was beaten.
--   won: the player's team beat ASURA · fighters: the team's size · hpLeft: health share
--   left on the last fighter · damage: share of ASURA's health taken (also when lost).
-- Returns grade (0 none, 1 C, 2 B, 3 A, 4 S), the title earned, and whether KAI's ÉVEILLÉ
-- style is unlocked (any win).
GameModes.CHALLENGE_TITLES = { "ASURA SLAYER", "ARM BREAKER", "ASURA'S EQUAL", "ASURA" }
GameModes.SHIN_TITLES = { "GOD SLAYER", "ECLIPSE BREAKER", "TRUE EMPEROR'S EQUAL", "TRUE EMPEROR" }
function GameModes.challengeGrade(won, fighters, hpLeft)
	if not won then return 0, nil, false end
	local grade = 1 -- C: beaten with a team of 3
	if fighters <= 2 then grade = 2 end -- B: with 2
	if fighters <= 1 then grade = 3 end -- A: alone
	if fighters <= 1 and hpLeft >= 0.5 then grade = 4 end -- S: alone, with half the health left
	return grade, GameModes.CHALLENGE_TITLES[grade], true
end

-- TITLES (Wilhem: « affiche tous les titres obtenables et comment, en petit en dessous, un design
-- différent pour chaque titre »): every title the game can give, how to get it, and its own
-- look (a kanji, two colours, a font: Enum.Font names). The shop's titles come from
-- StoreConfig.ITEMS (passed in: this module requires nothing).
GameModes.TITLE_LOOKS = {
	["WEEKLY CHAMPION"] = { kanji = "王", colors = { "FFD23F", "FF8A00" }, font = "Bangers" },
	["ASURA SLAYER"] = { kanji = "斬", colors = { "FF5A36", "8A0F14" }, font = "Bangers" },
	["ARM BREAKER"] = { kanji = "砕", colors = { "FF9A3C", "B5361A" }, font = "GothamBlack" },
	["ASURA'S EQUAL"] = { kanji = "対", colors = { "FFD27A", "C8541E" }, font = "Michroma" },
	["ASURA"] = { kanji = "阿", colors = { "FFE9B0", "D4A017" }, font = "Antique" },
	["GOD SLAYER"] = { kanji = "神", colors = { "FFFFFF", "9AB8FF" }, font = "Bangers" },
	["ECLIPSE BREAKER"] = { kanji = "蝕", colors = { "C77DFF", "3A0CA3" }, font = "GothamBlack" },
	["TRUE EMPEROR'S EQUAL"] = { kanji = "皇", colors = { "E0E0FF", "6A4CFF" }, font = "Michroma" },
	["TRUE EMPEROR"] = { kanji = "真", colors = { "FFFFFF", "FFD23F" }, font = "Antique" },
	["UNTOUCHABLE"] = { kanji = "影", colors = { "9AF0FF", "1E6BFF" }, font = "Oswald" },
	["COMBO ARTIST"] = { kanji = "連", colors = { "FF6FD8", "7A2BFF" }, font = "PermanentMarker" },
	["FRAME PERFECT"] = { kanji = "刻", colors = { "7CFFB2", "0FA36B" }, font = "Arcade" },
	["NO MERCY"] = { kanji = "鬼", colors = { "FF3D3D", "3A0000" }, font = "Creepster" },
	["FINAL BOSS"] = { kanji = "魔", colors = { "B06BFF", "FF2A6D" }, font = "Bangers" },
	["BREAKER"] = { kanji = "破", colors = { "FFB347", "FF3D00" }, font = "SpecialElite" },
	["SUPPORTER"] = { kanji = "援", colors = { "FF9AC6", "FF4F9A" }, font = "FredokaOne" },
}
local TITLE_HOW = {
	["WEEKLY CHAMPION"] = "Finish first of the WEEKLY ranking.",
	["ASURA SLAYER"] = "CHALLENGE: beat ASURA (a team of 3 is enough).",
	["ARM BREAKER"] = "CHALLENGE: beat ASURA with 2 fighters or fewer.",
	["ASURA'S EQUAL"] = "CHALLENGE: beat ASURA alone.",
	["ASURA"] = "CHALLENGE: beat ASURA alone with half your health left.",
	["GOD SLAYER"] = "CHALLENGE: beat KUROEN SHIN (a team of 3 is enough).",
	["ECLIPSE BREAKER"] = "CHALLENGE: beat KUROEN SHIN with 2 fighters or fewer.",
	["TRUE EMPEROR'S EQUAL"] = "CHALLENGE: beat KUROEN SHIN alone.",
	["TRUE EMPEROR"] = "CHALLENGE: beat KUROEN SHIN alone with half your health left.",
}
-- The shop's titles can also be EARNED, by a feat that matches their name (Wilhem: « certains
-- titres shop devraient être obtenables avec des conditions cohérentes à leur nom »). Counted
-- only in real fights (the server: online with the anti-farm, or against a LEGEND CPU, a
-- boss, SURVIVAL; never TRAINING). profile.feats keeps the counters.
GameModes.TITLE_FEATS = {
	UNTOUCHABLE = { stat = "perfect", goal = 3, how = "Win 3 rounds PERFECT (without taking a hit) in real fights." },
	["COMBO ARTIST"] = { stat = "bestCombo", goal = 20, how = "Land a combo of 20 hits in a real fight." },
	["FRAME PERFECT"] = { stat = "perfectPrompts", goal = 10, how = "Hit every rhythm prompt of an ultimate PERFECT, 10 times." },
	["NO MERCY"] = { stat = "fatalKO", goal = 5, how = "Finish 5 opponents with a FATAL BLOW." },
	["FINAL BOSS"] = { stat = "bosses", goal = 2, how = "Beat both bosses: ASURA and KUROEN SHIN." },
	BREAKER = { stat = "guardBreaks", goal = 25, how = "Break your opponents' guard 25 times in real fights." },
}

local function feats(profile)
	if type(profile.feats) ~= "table" then profile.feats = {} end
	return profile.feats
end

-- One event of a real fight, seen from `slot` (the player's side): the feats move.
-- moves: MoveData.Moves (a FATAL BLOW is a move with `fatal`).
function GameModes.featEvent(profile, event, slot, moves)
	local f = feats(profile)
	local kind = event.kind
	if kind == "Hit" and event.attacker == slot then
		f.bestCombo = math.max(tonumber(f.bestCombo) or 0, tonumber(event.combo) or 0)
		local m = moves and event.move and moves[event.move]
		if event.ko and m and m.fatal then f.fatalKO = (tonumber(f.fatalKO) or 0) + 1 end
	elseif kind == "GuardBreak" and event.attacker == slot then
		f.guardBreaks = (tonumber(f.guardBreaks) or 0) + 1
	elseif kind == "RoundEnd" and event.winner == slot and event.perfect then
		f.perfect = (tonumber(f.perfect) or 0) + 1
	elseif kind == "PromptGrade" and event.attacker == slot and event.grade == "PERFECT" then
		f.perfectPrompts = (tonumber(f.perfectPrompts) or 0) + 1
	end
end

-- The bosses beaten (FINAL BOSS): from the challenges' best grades.
function GameModes.featBosses(profile)
	local f = feats(profile)
	f.bosses = (if (tonumber(profile.asuraGrade) or 0) > 0 then 1 else 0) + (if (tonumber(profile.shinGrade) or 0) > 0 then 1 else 0)
end

-- The progress of a title's feat (value, goal), or nil (a title without feat).
function GameModes.featProgress(profile, name)
	local feat = GameModes.TITLE_FEATS[name]
	if not feat then return nil end
	local f = type(profile) == "table" and type(profile.feats) == "table" and profile.feats or {}
	return math.min(tonumber(f[feat.stat]) or 0, feat.goal), feat.goal
end

-- Gives every title whose feat is done and not yet owned; returns the new ones.
function GameModes.grantFeatTitles(profile)
	if type(profile.titles) ~= "table" then profile.titles = {} end
	local given = {}
	for name, feat in GameModes.TITLE_FEATS do
		local value = GameModes.featProgress(profile, name)
		if value and value >= feat.goal and not table.find(profile.titles, name) then
			table.insert(profile.titles, name)
			table.insert(given, name)
		end
	end
	table.sort(given)
	return given
end

function GameModes.titleCatalog(storeItems)
	local list = {}
	local function add(name, how, source, alt)
		local look = GameModes.TITLE_LOOKS[name] or { kanji = "称", colors = { "FFFFFF", "B1B2BE" }, font = "GothamBlack" }
		table.insert(list, { name = name, how = how, source = source, look = look, alt = alt })
	end
	add("WEEKLY CHAMPION", TITLE_HOW["WEEKLY CHAMPION"], "weekly")
	for _, name in GameModes.CHALLENGE_TITLES do add(name, TITLE_HOW[name], "challenge") end
	for _, name in GameModes.SHIN_TITLES do add(name, TITLE_HOW[name], "challenge") end
	for _, item in storeItems or {} do
		if item.kind == "TITLE" then
			local feat = GameModes.TITLE_FEATS[item.name]
			local shop = if item.pass then "With the " .. item.pass .. " Game Pass (SHOP › GAME PASSES)."
				else "SHOP › COSMETICS › TITLES: " .. tostring(item.coins) .. " coins."
			-- (a feat earns it; the shop sells it too)
			if feat then
				add(item.name, feat.how, "feat", "Or buy it: " .. tostring(item.coins) .. " coins (SHOP).")
			else
				add(item.name, shop, if item.pass then "pass" else "shop")
			end
		end
	end
	return list
end

-- ACHIEVEMENTS (menu › ACHIEVEMENTS): each one says where it is earned (the mode) and is
-- read from the player's saved profile (the server's menu status): { stat, goal }.
GameModes.ACHIEVEMENTS = {
	{ id = "FIRST_WIN", name = "FIRST WIN", where = "1 VS 1 · PLAYER", how = "Win a match against a player.", stat = "achWins", goal = 1 },
	{ id = "SEASONED", name = "SEASONED", where = "1 VS 1 · PLAYER", how = "Win 10 matches against players.", stat = "achWins", goal = 10 },
	{ id = "VETERAN", name = "VETERAN", where = "1 VS 1 · PLAYER", how = "Win 50 matches against players.", stat = "achWins", goal = 50 },
	{ id = "RISING", name = "RISING STAR", where = "1 VS 1 · PLAYER · RANKED", how = "Reach 1300 points.", stat = "achRating", goal = 1300 },
	{ id = "LEGEND", name = "LEGEND OF THE RING", where = "1 VS 1 · PLAYER · RANKED", how = "Reach 1700 points.", stat = "achRating", goal = 1700 },
	{ id = "SURVIVOR", name = "SURVIVOR", where = "SURVIVAL", how = "Beat 5 opponents in a row.", stat = "achSurvival", goal = 5 },
	{ id = "UNBREAKABLE", name = "UNBREAKABLE", where = "SURVIVAL", how = "Beat 15 opponents in a row.", stat = "achSurvival", goal = 15 },
	{ id = "GATE", name = "FACE THE GATE", where = "CHALLENGE · ASURA", how = "Take half of ASURA's health.", stat = "achAsuraDamage", goal = 50 },
	{ id = "SLAYER", name = "ASURA SLAYER", where = "CHALLENGE · ASURA", how = "Beat ASURA (a team of 3 is enough). Reward: KAI's AWAKENED style.",
		stat = "achAsuraGrade", goal = 1 },
	{ id = "BREAKER", name = "ARM BREAKER", where = "CHALLENGE · ASURA", how = "Beat ASURA with 2 fighters or fewer.", stat = "achAsuraGrade", goal = 2 },
	{ id = "EQUAL", name = "ASURA'S EQUAL", where = "CHALLENGE · ASURA", how = "Beat ASURA alone.", stat = "achAsuraGrade", goal = 3 },
	{ id = "ASURA", name = "ASURA", where = "CHALLENGE · ASURA", how = "Beat ASURA alone with half your health left.", stat = "achAsuraGrade", goal = 4 },
	{ id = "GODSLAYER", name = "GOD SLAYER", where = "CHALLENGE · KUROEN SHIN", how = "Beat KUROEN SHIN. Reward: KUROEN's DIVINE ECLIPSE style.",
		stat = "achShinGrade", goal = 1 },
	{ id = "TRUEEMPEROR", name = "TRUE EMPEROR", where = "CHALLENGE · KUROEN SHIN", how = "Beat KUROEN SHIN alone.", stat = "achShinGrade", goal = 3 },
}

-- The achievements count from their own counters (ach...), not from the ranking or the
-- rewards: a new SEASON resets every player's achievements (Wilhem: "reset les achievements
-- pour tout le monde") without touching their points, wins, titles or unlocked styles.
GameModes.ACHIEVEMENT_SEASON = 2
GameModes.ACHIEVEMENT_COUNTERS = { "achWins", "achRating", "achSurvival", "achAsuraDamage", "achAsuraGrade", "achShinGrade" }

-- A profile from an older season (or none): its achievement counters start again from zero.
-- Returns true if it was reset.
function GameModes.achievementSeason(profile)
	if profile.achSeason == GameModes.ACHIEVEMENT_SEASON then return false end
	for _, key in GameModes.ACHIEVEMENT_COUNTERS do profile[key] = 0 end
	profile.achSeason = GameModes.ACHIEVEMENT_SEASON
	return true
end

-- The counters after something happened: { won = true }, { rating = n }, { survival = n },
-- { asuraDamage = percent }, { asuraGrade = grade }.
function GameModes.achievementProgress(profile, what)
	GameModes.achievementSeason(profile)
	if what.won then profile.achWins += 1 end
	if what.rating then profile.achRating = math.max(profile.achRating, what.rating) end
	if what.survival then profile.achSurvival = math.max(profile.achSurvival, what.survival) end
	if what.asuraDamage then profile.achAsuraDamage = math.max(profile.achAsuraDamage, what.asuraDamage) end
	if what.asuraGrade then profile.achAsuraGrade = math.max(profile.achAsuraGrade, what.asuraGrade) end
	if what.shinGrade then profile.achShinGrade = math.max(profile.achShinGrade or 0, what.shinGrade) end
end

-- The achievements as a player sees them: { name, where, how, done, value, goal }, and the
-- number unlocked. `status`: the menu status (wins, rating, survivalBest, asuraGrade...).
function GameModes.achievements(status)
	local out, done = {}, 0
	for _, a in GameModes.ACHIEVEMENTS do
		local value = tonumber(status and status[a.stat]) or 0
		local ok = value >= a.goal
		if ok then done += 1 end
		table.insert(out, { id = a.id, name = a.name, where = a.where, how = a.how, done = ok, value = math.min(value, a.goal), goal = a.goal })
	end
	return out, done
end

-- Currencies (the bar of the menu, sprites: client/CurrencyIcons). COINS are earned by
-- playing (the server adds them, never the client); CRYSTALS come from the achievements
-- (CRYSTALS_PER_ACHIEVEMENT each one unlocked); RANK is the rating.
GameModes.COINS = { win = 150, loss = 50, draw = 100, survivalWin = 10, boss = 60 } -- (PvP: Economy.WIN / LOSS / DRAW)
GameModes.CRYSTALS_PER_ACHIEVEMENT = 25
function GameModes.addCoins(profile, kind, count)
	local gain = (GameModes.COINS[kind] or 0) * (count or 1)
	profile.coins = math.max(0, (tonumber(profile.coins) or 0) + gain)
	return gain
end
-- MATCH HISTORY: the last HISTORY_SIZE matches of a profile, newest first. `entry`: { t = time,
-- mode, queue, opp (the opponent's name or "CPU"), oppKit, kit, r = "W" / "L" / "D", coins,
-- delta (rating) }. Only plain values (kept by the DataStore).
GameModes.HISTORY_SIZE = 10
function GameModes.addHistory(profile, entry)
	if type(profile.history) ~= "table" then profile.history = {} end
	local clean = {}
	for k, v in entry do
		if type(v) == "string" or type(v) == "number" then clean[k] = if type(v) == "string" then string.sub(v, 1, 40) else v end
	end
	table.insert(profile.history, 1, clean)
	while #profile.history > GameModes.HISTORY_SIZE do table.remove(profile.history) end
	return profile.history
end

function GameModes.wallet(status)
	local _, done = GameModes.achievements(status)
	return { coins = tonumber(status and status.coins) or 0, crystals = done * GameModes.CRYSTALS_PER_ACHIEVEMENT,
		rank = tonumber(status and status.rating) or 0 }
end

--[[
	What a fighter is good and bad at, for the fighter select (from the real data, so it
	never lies): POWER (damage of its blows), SPEED (startup + recovery of its ground blows),
	RANGE (reach), DEFENSE (health and guard), MOBILITY (walk, dash, jump). Each from 1 to 5,
	ranked against the whole roster. Every fighter has something it is the best at and
	something it pays for (tests: Lobby), but the all-rounder.
]]
GameModes.STATS = { "POWER", "SPEED", "RANGE", "DEFENSE", "MOBILITY" }
local GROUND = { "Jab", "Cross", "Elbow", "Kick", "BodyBlow", "Uppercut", "Smash", "Hammer", "Sweep", "LowKick", "SpinKick" }
local function measure(moveData, name)
	local kit = moveData.Kits[name]
	local st = kit.Stats
	local power, reach, n = 0, 0, 0
	for _, id in kit.Roles do
		local m = moveData.Moves[id]
		if m and (m.damage or 0) > 0 and m.kind ~= "Ultimate" then
			power += m.damage * (m.hits or 1)
			reach += m.hitbox and m.hitbox.far or 0
			n += 1
		end
	end
	local frames, k = 0, 0
	for _, role in GROUND do
		local m = moveData.Moves[kit.Roles[role]]
		if m then
			frames += m.startup * 2 + (m.recovery or 0)
			k += 1
		end
	end
	return {
		POWER = power / math.max(n, 1) * (st.DamageDealt or 1),
		SPEED = -frames / math.max(k, 1) + (st.WalkSpeed or 16) * 0.4,
		RANGE = reach / math.max(n, 1),
		DEFENSE = st.MaxHealth / (st.GuardDamageTaken or 1),
		MOBILITY = (st.WalkSpeed or 16) + (st.DashSpeed or 38) * 0.5 + (st.JumpVelocity or 43) * 0.3,
	}
end
function GameModes.ratings(moveData, kitOrder)
	local raw = {}
	for _, name in kitOrder do raw[name] = measure(moveData, name) end
	local out = {}
	for _, name in kitOrder do out[name] = {} end
	for _, stat in GameModes.STATS do
		local sorted = table.clone(kitOrder)
		table.sort(sorted, function(a, b)
			if raw[a][stat] ~= raw[b][stat] then return raw[a][stat] < raw[b][stat] end
			return a < b
		end)
		for i, name in sorted do
			out[name][stat] = 1 + math.floor((i - 1) * 5 / #sorted)
		end
	end
	return out
end
-- Its strengths (4 and 5) and weaknesses (1 and 2), strongest first.
function GameModes.traits(rating)
	local plus, minus = {}, {}
	for _, stat in GameModes.STATS do
		if rating[stat] >= 4 then table.insert(plus, stat) end
		if rating[stat] <= 2 then table.insert(minus, stat) end
	end
	table.sort(plus, function(a, b) return rating[a] > rating[b] end)
	table.sort(minus, function(a, b) return rating[a] < rating[b] end)
	return plus, minus
end

return GameModes
