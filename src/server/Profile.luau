--[[
	The saved profile of a player: a new player's values, and the merge of a save at the join.
	Pure (no Roblox API, no require: the server passes its dependencies) so it can be tested
	offline (tests/Lobby.test.luau).

	deps = { startRating = Matchmaker.START_RATING, taunts = Taunts.DEFAULT,
		achievementSeason = GameModes.ACHIEVEMENT_SEASON }

	THE RULE: the load keeps only the fields listed in Profile.default, with the type they have
	there. So EVERY field a module writes in the profile (Matchmaker, GameModes, Economy, Quests,
	Champions, Store, AntiCheat, Admin, CharacterData, the server) must be listed below, with the
	type it is saved with; a field missing here is dropped at the next join, and the first write
	of that session erases it from the save too (B-021: the 2v2 / 3v3 ratings, the titles' feats
	and their stars). The test "saved profile" of Lobby.test checks it.
]]
local Profile = {}

function Profile.default(deps)
	return { rating = deps.startRating, wins = 0, losses = 0, survivalBest = 0, hero = "KAI", coins = 0,
		-- RANKED 2v2 / 3v3 (Matchmaker.setRating): category -> rating, under a string key ("2", "3").
		-- Empty for a new player: a category without a rating has never been played and stays off
		-- its board (Matchmaker.played); Matchmaker.ratingOf gives it the starting rating.
		ratings = {},
		recentOpp = {}, coinDay = 0, coinToday = 0, -- (anti-cheat: today's opponents, the daily coin cap)
		asuraGrade = 0, asuraDamage = 0, title = "", -- CHALLENGE: best grade, best damage share, title
		shinGrade = 0, -- CHALLENGE · KUROEN SHIN: best grade (1+ unlocks KUROEN's DIVINE style)
		ownedSkins = {}, -- SHOP: the shop and quest styles owned (name -> true, CharacterData.SHOP)
		ownedKits = {}, -- the fighters unlocked with coins (name -> true; the free ones: Economy.FREE)
		equipped = {}, -- the style worn with each fighter (kit -> style name)
		quests = {}, -- QUESTS: the counters and the quests rewarded (Quests)
		titles = {}, championWeeks = {}, -- the titles owned (challenges, champion of the week)
		-- TITLES won by a feat (GameModes.TITLE_FEATS): the counters of the feats (stat -> count:
		-- guardBreaks, perfect, fatalKO...) and the titles earned by playing (name -> true: the star)
		feats = {}, earnedTitles = {},
		weekId = 0, weekPoints = 0, -- WEEKLY ranking: the points of the week (Champions)
		freePicks = 0, picksGiven = false, -- the old testers' free picks (Economy.claimFighter)
		tester = false, -- TESTERS: every fighter (Economy.makeTester)
		winStreak = 0, bestStreak = 0, -- WIN STREAK: online wins in a row (a real match), the best
		howToPlay = 0, -- HOW TO PLAY: the version of the guide already shown (once per player)
		dailyDay = 0, dailyStreak = 0, -- DAILY REWARD: the last day claimed, the series (Economy.claimDaily)
		history = {}, -- MATCH HISTORY: the last 10 matches (GameModes.addHistory)
		-- SHOP (Store, StoreConfig): the Game Passes last confirmed, the cosmetics bought with
		-- coins, the ones worn, and the Robux receipts already granted (never twice)
		passes = {}, ownedItems = {}, cosmetics = {}, receipts = {},
		devOff = false, -- (developer access only: switched off to play as a new player)
		language = "AUTO", -- SETTINGS › LANGUAGE: AUTO (Roblox's translation), EN or FR
		optReduced = false, optSound = true, optMusic = true, -- SETTINGS: effects reduced, sound, music (kept)
		optTaunts = true, tauntKey = "V", -- SETTINGS: the opponents' taunts shown, the key of the taunt wheel
		taunts = table.clone(deps.taunts), -- TAUNTS: the 6 on the wheel (ids, Taunts.LIST)
		-- ACHIEVEMENTS: their own counters, reset by a new season (GameModes.achievementSeason)
		achSeason = deps.achievementSeason, achWins = 0, achRating = 0, achSurvival = 0, achAsuraDamage = 0, achAsuraGrade = 0, achShinGrade = 0 }
end

-- The join: every field of the defaults whose saved value has the same type is taken from the
-- save (`saved`: what the DataStore holds); any other keeps the profile's value (a broken or
-- foreign value never reaches the game). Nothing else of the save comes in (the session lock
-- `_session` stays in the store: GlobalQueue). Returns the profile.
function Profile.merge(profile, saved, deps)
	if type(saved) ~= "table" then return profile end
	for k, v in Profile.default(deps) do
		if type(saved[k]) == type(v) then profile[k] = saved[k] end
	end
	return profile
end

return Profile
