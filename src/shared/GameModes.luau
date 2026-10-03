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
	{ id = "VERSUS_CPU", name = "1 CONTRE 1 · IA", kanji = "戦",
		description = "Toi contre le CPU. Choisis 1, 2 ou 3 persos (relais) et le niveau.", team = true, level = true },
	{ id = "VERSUS", name = "1 CONTRE 1 · JOUEUR", kanji = "対",
		description = "Contre un vrai joueur : NORMAL ou CLASSÉ (points), ou défie un ami du serveur.", team = true, queue = true },
	{ id = "SURVIVAL", name = "SURVIE", kanji = "生",
		description = "Un seul perso, des adversaires à la chaîne, de plus en plus forts. Ta vie ne revient qu'un peu.", team = false },
	{ id = "TRAINING", name = "ENTRAÎNEMENT", kanji = "練",
		description = "Mannequin, CPU, entraîneur de combos, conditions des ultimes.", team = false },
	{ id = "CHALLENGE", name = "CHALLENGE", kanji = "阿",
		description = "ASURA, un KAI à quatre bras. Bientôt.", locked = true },
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
function GameModes.validate(request, kitOrder)
	if type(request) ~= "table" then return nil, "requête invalide" end
	local mode = type(request.mode) == "string" and find(request.mode)
	if not mode then return nil, "mode inconnu" end
	if mode.locked then return nil, "mode verrouillé" end
	local known = {}
	for _, kit in kitOrder do known[kit] = true end
	local team = {}
	if type(request.team) == "table" then
		for i = 1, GameModes.MAX_TEAM do
			local kit = request.team[i]
			if kit == nil then break end
			if type(kit) ~= "string" or not known[kit] then return nil, "perso inconnu" end
			table.insert(team, kit)
		end
	end
	if #team == 0 then return nil, "aucun perso choisi" end
	if not mode.team and #team > 1 then team = { team[1] } end
	local out = { mode = mode.id, team = team }
	if mode.level then
		local level = request.level
		if type(level) ~= "number" or level % 1 ~= 0 or level < 1 or level > 4 then return nil, "niveau invalide" end
		out.level = level
	end
	if mode.queue then
		if type(request.queue) ~= "string" or not GameModes.QUEUES[request.queue] then return nil, "file invalide" end
		out.queue = request.queue
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

return GameModes
