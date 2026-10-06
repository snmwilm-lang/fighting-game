--[[
	QUESTS: simple challenges that give EXISTING styles (pure Luau: no Roblox API, no require).
	The server counts (`record`) and grants (`grant`) on the saved profile; the menu shows the
	progress (`list`). A reward is a shop style of CharacterData marked as a quest style there
	(CharacterData.QUEST, kept equal to these rewards by a test): it is not sold for coins.

	Counted at the end of a real match (not TRAINING; online: only the matches the anti-farm
	counts): `plays` every match played, `pvpWins` online wins, `kitWins[kit]` wins (any mode
	but training) with this fighter in the team.
	The list below is a PROPOSAL (to validate by Wilhem): one line per quest.
	Tests: tests/Lobby.test.luau ("quests").
]]
local Quests = {}

Quests.LIST = {
	{ id = "PLAY10", name = "WARM-UP", how = "Play 10 matches", stat = "plays", goal = 10, reward = "KAI INFERNO" },
	{ id = "PLAY40", name = "REGULAR", how = "Play 40 matches", stat = "plays", goal = 40, reward = "HIBECARES ABYSS" },
	{ id = "WIN5", name = "FIRST BLOOD", how = "Win 5 online matches", stat = "pvpWins", goal = 5, reward = "TARO SAKURA" },
	{ id = "WIN25", name = "CONTENDER", how = "Win 25 online matches", stat = "pvpWins", goal = 25, reward = "ZEPHYR ABYSS" },
	{ id = "RYUKEN5", name = "RAGE UNLEASHED", how = "Win 5 matches with RYUKEN", stat = "kitWins", kit = "RYUKEN", goal = 5, reward = "RYUKEN PHANTOM" },
	{ id = "GORAN5", name = "TITAN'S GRIP", how = "Win 5 matches with GORAN", stat = "kitWins", kit = "GORAN", goal = 5, reward = "GORAN SAKURA" },
	{ id = "ELIAN5", name = "LIGHT BEARER", how = "Win 5 matches with ELIAN", stat = "kitWins", kit = "ELIAN", goal = 5, reward = "ELIAN ABYSS" },
	{ id = "VENOM5", name = "LETHAL DOSE", how = "Win 5 matches with VENOM", stat = "kitWins", kit = "VENOM", goal = 5, reward = "VENOM INFERNO" },
}
Quests.BY_ID = {}
Quests.BY_REWARD = {}
for _, q in Quests.LIST do
	Quests.BY_ID[q.id] = q
	Quests.BY_REWARD[q.reward] = q
end

local function counters(profile)
	if type(profile.quests) ~= "table" then profile.quests = {} end
	local c = profile.quests
	c.plays = tonumber(c.plays) or 0
	c.pvpWins = tonumber(c.pvpWins) or 0
	if type(c.kitWins) ~= "table" then c.kitWins = {} end
	if type(c.done) ~= "table" then c.done = {} end
	return c
end

-- One finished match: { won = bool, pvp = bool, kits = { "KAI", ... } }.
function Quests.record(profile, match)
	local c = counters(profile)
	c.plays += 1
	if match.won then
		if match.pvp then c.pvpWins += 1 end
		local seen = {}
		for _, kit in match.kits or {} do
			if type(kit) == "string" and not seen[kit] then
				seen[kit] = true
				c.kitWins[kit] = (tonumber(c.kitWins[kit]) or 0) + 1
			end
		end
	end
end

function Quests.value(profile, quest)
	local c = type(profile) == "table" and type(profile.quests) == "table" and profile.quests or {}
	if quest.stat == "kitWins" then
		return tonumber(type(c.kitWins) == "table" and c.kitWins[quest.kit]) or 0
	end
	return tonumber(c[quest.stat]) or 0
end

-- Gives the reward of every quest completed and not yet rewarded (once: `done[id]`).
-- Returns the styles newly given.
function Quests.grant(profile)
	local c = counters(profile)
	local given = {}
	for _, q in Quests.LIST do
		if not c.done[q.id] and Quests.value(profile, q) >= q.goal then
			c.done[q.id] = true
			if type(profile.ownedSkins) ~= "table" then profile.ownedSkins = {} end
			if not profile.ownedSkins[q.reward] then
				profile.ownedSkins[q.reward] = true
				table.insert(given, q.reward)
			end
		end
	end
	return given
end

-- What the menu shows: { id, name, how, value, goal, reward, done }.
function Quests.list(status)
	local out = {}
	for _, q in Quests.LIST do
		local value = Quests.value(status or {}, q)
		local done = type(status) == "table" and type(status.quests) == "table" and type(status.quests.done) == "table"
			and status.quests.done[q.id] == true
		table.insert(out, { id = q.id, name = q.name, how = q.how, value = math.min(value, q.goal), goal = q.goal, reward = q.reward,
			done = done or value >= q.goal })
	end
	return out
end

return Quests
