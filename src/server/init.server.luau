--[[
	Server: menus, matches and opponent search.

	A server hosts many matches at once (MATCHES): each has its own simulation world, its two
	slots (a player, the CPU or the training dummy) and its rigs in workspace.Fighters.Match<id>.
	Every match uses the same stage; each client draws only the two fighters of its own match
	(the others are hidden on that client), so dozens of 1v1 run side by side on one server and
	Roblox spreads the players over as many servers as needed.

	A player arrives in the main menu (GameModes): ENTRAÎNEMENT, 1 CONTRE 1 · IA, SURVIE,
	1 CONTRE 1 · JOUEUR (NORMAL, CLASSÉ or a friend's challenge from the hub). The server checks
	every request, runs the match and sends the player back to the menu at the end. Ratings
	(CLASSÉ) and the best SURVIE are saved with DataStoreService (only in a published game).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local TeleportService = game:GetService("TeleportService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.CombatConfig)
local MoveData = require(Shared.MoveData)
local CharacterData = require(Shared.CharacterData)
local Sim = require(Shared.CombatSimulation)
local FighterAI = require(Shared.FighterAI)
local PressQueue = require(Shared.PressQueue)
local RigReader = require(Shared.RigReader)
local GameModes = require(Shared.GameModes)
local Maps = require(Shared.Maps)
local RigBuilder = require(script.RigBuilder)
local Lobby = require(script.Lobby)
local Matchmaker = require(script.Matchmaker)
local SaveQueue = require(script.SaveQueue)
local GlobalQueue = require(script.GlobalQueue)
local AntiCheat = require(script.AntiCheat)
local Taunts = require(Shared.Taunts)
local Economy = require(Shared.Economy)
local Quests = require(Shared.Quests)
local DevAccess = require(script.DevAccess)
local Champions = require(script.Champions)
local JOB = game.JobId -- (this server: the session lock and the cross-server queue)
local arrivedForCrossMatch -- (defined with the cross-server search)

Players.CharacterAutoLoads = false
-- (the stages are built by each client: Maps, client/ArenaBuilder)
local fightersFolder = Instance.new("Folder")
fightersFolder.Name, fightersFolder.Parent = "Fighters", workspace
local remotes = Instance.new("Folder")
remotes.Name = "FightingRemotes"
local function remote(name)
	local r = Instance.new("RemoteEvent")
	r.Name, r.Parent = name, remotes
	return r
end
local inputRemote = remote("Input")
local snapshotRemote = remote("Snapshot")
local eventsRemote = remote("Events")
local debugRemote = remote("Debug")
local hubRemote = remote("Hub") -- friends' challenges: client -> server (action, target user id)
local menuRemote = remote("Menu") -- main menu: requests in, the player's menu status out
-- Parent last so clients see the folder with every remote already inside.
remotes.Parent = ReplicatedStorage

-- Training dummy modes, cycled from the HUD (MANNEQUIN) or the M key.
local DUMMY_MODES = { { name = "STILL" }, { name = "GUARD", block = true } }
for level, data in FighterAI.Levels do
	table.insert(DUMMY_MODES, { name = "CPU " .. data.name, level = level })
end

local clients = {} -- player -> { slot, match, team, queue, rating, ... }
local matches = {} -- id -> match
local nextMatchId = 0
local lobby = Lobby.new() -- the players of the server and their challenges (hub)
local matchmaker = Matchmaker.new()

-- ===================================================================== saved data
-- Rating (CLASSÉ), wins / losses, best SURVIE. Published game only: in Studio without API
-- access the calls fail (pcall) and the player simply starts from the defaults.
local store = nil
do
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, "JeuxCombat_Joueurs_v1")
	if ok then store = result end
end
local function defaultProfile()
	return { rating = Matchmaker.START_RATING, wins = 0, losses = 0, survivalBest = 0, hero = "KAI", coins = 0,
		recentOpp = {}, coinDay = 0, coinToday = 0, -- (anti-cheat: today's opponents, the daily coin cap)
		asuraGrade = 0, asuraDamage = 0, title = "", -- CHALLENGE: best grade, best damage share, title
		shinGrade = 0, -- CHALLENGE · KUROEN SHIN: best grade (1+ unlocks KUROEN's DIVINE style)
		ownedSkins = {}, -- SHOP: the shop and quest styles owned (name -> true, CharacterData.SHOP)
		ownedKits = {}, -- the fighters unlocked with coins (name -> true; the free ones: Economy.FREE)
		equipped = {}, -- the style worn with each fighter (kit -> style name)
		quests = {}, -- QUESTS: the counters and the quests rewarded (Quests)
		titles = {}, championWeeks = {}, -- the titles owned (challenges, champion of the week)
		devOff = false, -- (developer access only: switched off to play as a new player)
		language = "AUTO", -- SETTINGS › LANGUAGE: AUTO (Roblox's translation), EN or FR
		optReduced = false, optSound = true, optMusic = true, -- SETTINGS: effects reduced, sound, music (kept)
		optTaunts = true, tauntKey = "V", -- SETTINGS: the opponents' taunts shown, the key of the taunt wheel
		taunts = table.clone(Taunts.DEFAULT), -- TAUNTS: the 6 on the wheel (ids, Taunts.LIST)
		-- ACHIEVEMENTS: their own counters, reset by a new season (GameModes.achievementSeason)
		achSeason = GameModes.ACHIEVEMENT_SEASON, achWins = 0, achRating = 0, achSurvival = 0, achAsuraDamage = 0, achAsuraGrade = 0, achShinGrade = 0 }
end
-- ANTI-CHEAT: packets the real client never sends add suspicion; past AntiCheat.KICK the
-- player is kicked (a server log line says why).
local ac = AntiCheat.new()
local function suspect(player, reason)
	if AntiCheat.flag(ac, player.UserId, reason, os.clock()) then
		local entry = ac.log[#ac.log]
		local why = {}
		for r, n in entry.reasons do table.insert(why, r .. " x" .. n) end
		warn("[FightingGame] anti-cheat: kicked " .. player.Name .. " (" .. player.UserId .. "): " .. table.concat(why, ", "))
		player:Kick("BREAKFRAMEZ: invalid data received from your game. / Données invalides reçues de ton jeu.")
	end
end
-- The developer access (DevAccess: the listed UserIds and the game's owner; never everyone in
-- Studio), on unless the developer switched it off in SETTINGS.
local CREATOR_IS_USER = game.CreatorType == Enum.CreatorType.User
local function devOn(player, client)
	return DevAccess.active(DevAccess.isDev(player.UserId, game.CreatorId, CREATOR_IS_USER), client and client.profile)
end
local saves = SaveQueue.new() -- when to write (SaveQueue: spacing, batches, never an unloaded profile)
local function loadProfile(player, client)
	client.profile = defaultProfile()
	if not store then return end
	task.spawn(function()
		-- (a DataStore hiccup is retried; a profile that never loads is never written over; a
		-- profile another server still holds (the player just came from it) is waited for:
		-- the session lock, GlobalQueue.canLock)
		local attempt, waited = 0, 0
		while attempt < SaveQueue.LOAD_TRIES do
			local data, locked = nil, false
			local ok = pcall(store.UpdateAsync, store, "joueur_" .. player.UserId, function(old)
				if not GlobalQueue.canLock(old, JOB, os.time()) then
					locked = true
					return nil -- (nothing written: still the other server's)
				end
				locked, data = false, old
				return GlobalQueue.stamp(if type(old) == "table" then old else {}, JOB, os.time(), false)
			end)
			if clients[player] ~= client then return end
			if ok and locked and waited < GlobalQueue.LOCK_TTL + 5 then
				waited += GlobalQueue.LOCK_RETRY
				task.wait(GlobalQueue.LOCK_RETRY)
				continue
			end
			if ok and not locked then
				if type(data) == "table" then
					for k, v in defaultProfile() do
						if type(data[k]) == type(v) then client.profile[k] = data[k] end
					end
					if not MoveData.Kits[client.profile.hero] then client.profile.hero = "KAI" end
					if type(data.achSeason) ~= "number" then client.profile.achSeason = 0 end -- (saved before the seasons)
					GameModes.achievementSeason(client.profile)
				end
				client.profile.taunts = Taunts.sanitize(client.profile.taunts, client.profile)
				-- (a challenge title won before the titles list: kept in it)
				local p = client.profile
				if p.title ~= "" and not table.find(p.titles, p.title) then table.insert(p.titles, p.title) end
				-- (a favourite that is not playable any more, a locked fighter: KAI, free, instead)
				if not Economy.canPlay(p, p.hero, "VERSUS", devOn(player, client)) then p.hero = "KAI" end
				SaveQueue.loaded(saves, player.UserId)
				SaveQueue.boardChanged(saves, player.UserId, math.floor(client.profile.rating)) -- (already on the board)
				client.profileLoaded = true
				if type(data) == "table" then client.onProfileLoaded() end
				return
			end
			attempt += 1
			task.wait(SaveQueue.retryDelay(attempt))
		end
		client.profileLoaded = true
		if clients[player] == client then
			menuRemote:FireClient(player, { error = "SAVES UNAVAILABLE: this session will not be kept" })
		end
	end)
end
-- The ranking (CLASSEMENT): an ordered store of the ratings, read 10 at a time.
local board = nil
local championHistory = {} -- (the champions of the week, read from the shared history: Champions)
do
	local ok, result = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, "JeuxCombat_Classement_v1")
	if ok then board = result end
end
-- One write of a profile (UpdateAsync, safe if another server touched it), then the board
-- only when the rating changed. Yields: called in its own thread.
local function writeProfile(player, client, release)
	local id = player.UserId
	local profile = table.clone(client.profile)
	SaveQueue.writing(saves, id, os.clock())
	local lost = false
	local ok = pcall(store.UpdateAsync, store, "joueur_" .. id, function(old)
		-- (only while this server holds the session lock; `release` lets it go: leaving)
		if not GlobalQueue.canLock(old, JOB, os.time()) then
			lost = true
			return nil
		end
		return GlobalQueue.stamp(profile, JOB, os.time(), release)
	end)
	if not ok then
		SaveQueue.failed(saves, id, os.clock())
		return false
	end
	if lost then
		warn("[FightingGame] profile " .. id .. " is held by another server: not written")
		return false
	end
	local data = profile
	local rating = math.floor(data.rating)
	if board and SaveQueue.boardChanged(saves, id, rating) then pcall(board.SetAsync, board, tostring(id), rating) end
	return true
end
-- A change to keep: written by the next flush (urgent: now, when leaving or closing).
local function saveProfile(player, client, urgent)
	if not store or not client.profile then return end
	SaveQueue.mark(saves, player.UserId, os.clock())
	if urgent and SaveQueue.isLoaded(saves, player.UserId) then
		task.spawn(writeProfile, player, client)
	end
end
task.spawn(function()
	while true do
		task.wait(SaveQueue.FLUSH_PERIOD)
		for _, id in SaveQueue.due(saves, os.clock(), false) do
			local player = Players:GetPlayerByUserId(id)
			local client = player and clients[player]
			if client then task.spawn(writeProfile, player, client) end
		end
	end
end)
local boardCache, boardAt, nameCache = nil, -math.huge, {}
local function topRatings()
	if boardCache and os.clock() - boardAt < 60 then return boardCache end
	local list = {}
	if board then
		local ok, pages = pcall(board.GetSortedAsync, board, false, 10)
		if ok and pages then
			for rank, entry in pages:GetCurrentPage() do
				local id = tonumber(entry.key)
				local name = id and nameCache[id]
				if id and not name then
					local okName, value = pcall(Players.GetNameFromUserIdAsync, Players, id)
					name = if okName then value else "#" .. entry.key
					nameCache[id] = name
				end
				table.insert(list, { rank = rank, name = name or "?", rating = entry.value, title = Matchmaker.rankName(entry.value) })
			end
		end
	end
	boardCache, boardAt = list, os.clock()
	return list
end

-- ===================================================================== matches
local function isSolo(match)
	return not (match.slots[1].owner and match.slots[2].owner)
end
local function isTraining(match)
	return match.mode == "TRAINING" and isSolo(match) and not DUMMY_MODES[match.dummyMode].level
end

local function place(slot, fighter)
	if not slot.model or not slot.model:FindFirstChild("HumanoidRootPart") then return end
	local pos = Vector3.new(fighter.x, fighter.y + Config.RootHeight, Config.PlaneZ)
	slot.model.HumanoidRootPart.CFrame = CFrame.lookAt(pos, pos + Vector3.new(fighter.facing, 0, 0))
end

-- The CPU of a match: the training dummy's level, the chosen level, or the SURVIE wave's.
local function newBrain(match)
	if not isSolo(match) then return nil end
	local level = if match.mode == "TRAINING" then DUMMY_MODES[match.dummyMode].level else match.level
	return level and FighterAI.new(level, math.floor(os.clock() * 1000) + match.generation) or nil
end

-- New match: health, guard, states, buffers, wins and inputs are all cleared.
local function resetAll(match)
	match.generation += 1
	if match.mode == "TRAINING" then
		Sim.resetMatch(match.world, isTraining(match))
	else
		Sim.resetMatch(match.world, false)
	end
	match.brain = newBrain(match)
	for i, slot in match.slots do
		slot.input = Sim.neutralInput()
		PressQueue.clear(slot.presses)
		place(slot, match.world.fighters[i])
	end
end

local rebuildSlot
local function watchRig(match, i)
	local slot = match.slots[i]
	local model = slot.model
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	humanoid.Died:Connect(function()
		-- Health is owned by the simulation; a Humanoid death only happens if something
		-- external kills the rig, so rebuild it rather than leave a broken character.
		task.defer(function()
			if slot.model ~= model or match.closed then return end
			if slot.owner then slot.owner.Character = nil end
			model:Destroy()
			slot.model = RigBuilder.build(i, match.folder, match.characters[i])
			if slot.owner then slot.owner.Character = slot.model end
			watchRig(match, i)
			resetAll(match)
		end)
	end)
end

local function swapModel(match, i, model)
	local slot = match.slots[i]
	if match.closed then
		model:Destroy()
		return
	end
	local owner = slot.owner
	if owner and owner.Character == slot.model then owner.Character = nil end
	if slot.model then slot.model:Destroy() end
	model.Name = "Fighter" .. i
	model.Parent = match.folder
	-- Once in the world, check the joints again (a Humanoid may rebuild its own).
	local rebuilt = RigReader.ensureJoints(model)
	if rebuilt > 0 then print("[FightingGame] " .. model.Name .. ": " .. rebuilt .. " joints rebuilt after placement") end
	slot.model = model
	if owner then owner.Character = model end
	watchRig(match, i)
	place(slot, match.world.fighters[i])
end

-- The avatar body type of a player: always R15 (Wilhem: « on jouera sans [le R6] »). The R6
-- path of the RigBuilder stays for tools and tests, but the menu no longer offers it.
local function rigOf(player, client)
	if client.rig ~= "R15" then
		client.rig = "R15"
		player:SetAttribute("AvatarRig", client.rig)
	end
	return client.rig
end

-- Rebuilds a slot's rig: the owner's Roblox avatar (R15 or R6) wearing the kit when they
-- chose it, the block model otherwise. A CPU / dummy slot becomes a shadow clone of the other
-- player's avatar, with the same body type.
function rebuildSlot(match, i)
	local slot = match.slots[i]
	local owner = slot.owner
	local client = owner and clients[owner]
	local data = match.characters[i]
	slot.building = (slot.building or 0) + 1
	local ticket = slot.building
	if not owner then
		local other = match.slots[3 - i].owner
		local otherClient = other and clients[other]
		if otherClient and otherClient.avatar then
			task.spawn(function()
				local ok, model = pcall(RigBuilder.buildShadow, i, other, rigOf(other, otherClient), data) -- yields
				if not ok then
					warn("[FightingGame] Shadow clone failed: " .. tostring(model))
					model = nil
				end
				if slot.owner or slot.building ~= ticket or match.closed then
					if model then model:Destroy() end
					return
				end
				swapModel(match, i, model or RigBuilder.build(i, nil, data))
			end)
		else
			swapModel(match, i, RigBuilder.build(i, nil, data))
		end
		return
	end
	if client and client.avatar then
		owner:SetAttribute("AvatarStatus", "LOADING")
		task.spawn(function()
			-- Own avatar + kit; a default body + kit if the avatar cannot load (see RigBuilder).
			local ok, model, status = pcall(RigBuilder.buildAvatar, i, owner, rigOf(owner, client), data) -- yields
			if not ok then
				warn("[FightingGame] Avatar failed: " .. tostring(model))
				model, status = nil, "MODEL|" .. tostring(model):sub(1, 90)
			end
			if slot.owner ~= owner or not client.avatar or slot.building ~= ticket or match.closed then
				if model then model:Destroy() end
				return
			end
			if not model then
				client.avatar = false
				owner:SetAttribute("Avatar", false)
				model = RigBuilder.build(i, nil, data)
			end
			owner:SetAttribute("AvatarStatus", status)
			swapModel(match, i, model)
		end)
	else
		swapModel(match, i, RigBuilder.build(i, nil, data))
	end
end

-- The look of each slot follows its current kit (a style different from the other slot's).
local function refreshLooks(match)
	for i = 1, 2 do
		local kit = match.world.kits[i]
		if not match.characters[i] or match.characters[i].Kit ~= kit then
			local other = match.characters[3 - i]
			-- (the style the player equipped for this fighter, if it is theirs; the CPU: the first)
			local owner = match.slots[i].owner
			local client = owner and clients[owner]
			match.characters[i] = CharacterData.Skins[CharacterData.styleFor(kit, client and client.profile, other and other.Skin,
				client ~= nil and devOn(owner, client))]
			if match.slots[i].model then rebuildSlot(match, i) end
		end
	end
end

local menuStatus -- (defined below)
local previewStyle -- (defined below)

local function newMatch(mode, options)
	nextMatchId += 1
	local folder = Instance.new("Folder")
	folder.Name = "Match" .. nextMatchId
	folder.Parent = fightersFolder
	local match = {
		id = nextMatchId, folder = folder, mode = mode, queue = options.queue, level = options.level,
		world = Sim.newWorld(Config, MoveData, mode == "TRAINING"), slots = {}, characters = {},
		dummyMode = 1, generation = 0, accumulator = 0, lastSnapshot = 0, pendingDebug = {},
		wave = 0, lastRoster = nil, lastRosterAt = -math.huge,
		map = Maps.pick(options.map, math.random(1, 1000)), -- its stage (asked in the menu, else drawn)
	}
	for i = 1, 2 do
		match.slots[i] = { model = nil, owner = nil, input = Sim.neutralInput(), lastInput = 0, presses = PressQueue.new() }
	end
	matches[match.id] = match
	return match
end

local function seat(match, i, player)
	local client = clients[player]
	local slot = match.slots[i]
	slot.owner = player
	client.match, client.slot = match, i
	player:SetAttribute("MatchId", match.id)
	player:SetAttribute("FighterSlot", i)
	player:SetAttribute("Mode", match.mode)
	player:SetAttribute("Map", match.map) -- (the client builds this stage)
end

-- Builds the rigs and starts a match whose slots and teams are set.
local function launch(match)
	refreshLooks(match)
	for i = 1, 2 do rebuildSlot(match, i) end
	resetAll(match)
	for i = 1, 2 do
		local owner = match.slots[i].owner
		if owner and clients[owner] then menuStatus(owner) end
	end
end

-- A player leaves their match (back to the menu). The match closes once no player is left;
-- a 1v1 between players ends: the one who stays wins (CLASSÉ: the one who left loses points).
local endVersus
local function unseat(player)
	local client = clients[player]
	local match = client and client.match
	if not match then return end
	local i = client.slot
	if match.mode == "VERSUS" and not match.finished and match.slots[3 - i].owner then
		endVersus(match, 3 - i, i) -- (the one who leaves gets nothing)
	end
	match.slots[i].owner = nil
	client.match, client.slot = nil, nil
	player:SetAttribute("MatchId", 0)
	player:SetAttribute("FighterSlot", 0)
	player:SetAttribute("Mode", "")
	player:SetAttribute("Map", "")
	if player.Character == match.slots[i].model then player.Character = nil end
	local anyone = false
	for _, slot in match.slots do
		if slot.owner then anyone = true end
	end
	if not anyone then
		match.closed = true
		matches[match.id] = nil
		match.folder:Destroy()
	elseif match.mode == "VERSUS" then
		-- The other player goes back to the menu too.
		local other = match.slots[3 - i].owner
		task.delay(3, function()
			if other and clients[other] and clients[other].match == match then
				unseat(other)
				menuStatus(other)
			end
		end)
	end
end

-- ===================================================================== modes
local function randomStart()
	return math.random(0, #MoveData.KitOrder - 1)
end

local function startSolo(player, request)
	local client = clients[player]
	local mode = request.mode
	local match = newMatch(mode, { level = request.level, map = request.map })
	seat(match, 1, player)
	local world = match.world
	if mode == "TRAINING" then
		Sim.setKits(world, request.team[1], request.team[1])
		match.dummyMode = 1
	elseif mode == "VERSUS_CPU" then
		Sim.setLineup(world, request.team, GameModes.cpuTeam(#request.team, MoveData.KitOrder, randomStart()))
	elseif GameModes.find(mode).boss then
		-- A boss (ASURA, KUROEN SHIN) against a team of 1 to 3, with the boss's brain.
		match.level = "ASURA"
		Sim.setTeams(world, request.team, { GameModes.find(mode).boss })
	elseif mode == "SURVIVAL" then
		match.wave, match.seed = 1, randomStart()
		local kit, level = GameModes.survivalOpponent(1, MoveData.KitOrder, match.seed)
		match.level = level
		Sim.setTeams(world, { request.team[1] }, { kit })
	end
	client.team = request.team
	launch(match)
end

local function startVersus(playerA, playerB, queue)
	local match = newMatch("VERSUS", { queue = queue })
	seat(match, 1, playerA)
	seat(match, 2, playerB)
	-- (a fighter the player does not own is never fielded: checked when the team was chosen,
	-- checked again here)
	local function fielded(player)
		local client = clients[player]
		local team = client.team or { "KAI" }
		if not Economy.teamAllowed(client.profile, team, "VERSUS", devOn(player, client)) then return { "KAI" } end
		return team
	end
	local teamA, teamB = fielded(playerA), fielded(playerB)
	-- Same team size on both sides (the smaller one).
	local size = math.min(#teamA, #teamB)
	Sim.setLineup(match.world, table.move(teamA, 1, size, 1, {}), table.move(teamB, 1, size, 1, {}))
	launch(match)
end

-- End of a 1v1 between players: ratings (CLASSÉ), wins / losses, result to both.
function endVersus(match, winnerSlot, leftSlot)
	if match.finished then return end
	match.finished = true
	local a, b = match.slots[1].owner, match.slots[2].owner
	local ca, cb = a and clients[a], b and clients[b]
	if not (ca and cb) then return end
	local scoreA = if winnerSlot == 1 then 1 elseif winnerSlot == 2 then 0 else 0.5
	-- ANTI-CHEAT (farming): a match too short, or the same two players again and again,
	-- pays less or nothing; the coins have a daily cap (AntiCheat).
	local seconds, now = match.world.tick / Config.TickRate, os.time()
	local shareA = AntiCheat.share(ca.profile, b.UserId, seconds, now)
	local shareB = AntiCheat.share(cb.profile, a.UserId, seconds, now)
	local share = math.min(shareA.rating, shareB.rating) -- (the rating stays a zero-sum)
	AntiCheat.record(ca.profile, b.UserId, now)
	AntiCheat.record(cb.profile, a.UserId, now)
	if share > 0 then
		if winnerSlot == 1 then ca.profile.wins += 1; cb.profile.losses += 1
		elseif winnerSlot == 2 then cb.profile.wins += 1; ca.profile.losses += 1 end
		if winnerSlot == 1 or winnerSlot == 2 then
			GameModes.achievementProgress((if winnerSlot == 1 then ca else cb).profile, { won = true })
		end
	end
	-- COINS (Economy): a win WIN, a loss LOSS, nothing for the one who left; the anti-farm
	-- share and the daily cap apply.
	local function pay(profile, slot, part)
		local result = if slot == leftSlot then "left" elseif winnerSlot == slot then "win" elseif winnerSlot == 0 then "draw" else "loss"
		local gain = AntiCheat.capCoins(profile, math.floor(Economy.pvpCoins(result) * part + 0.5), now)
		profile.coins = (tonumber(profile.coins) or 0) + gain
		return gain
	end
	local gains = { pay(ca.profile, 1, shareA.coins), pay(cb.profile, 2, shareB.coins) }
	-- QUESTS: a real match (counted by the anti-farm) moves them; never the one who left.
	if share > 0 then
		for slot, client in { ca, cb } do
			if slot ~= leftSlot then
				local team = match.world.teams and match.world.teams[slot]
				Quests.record(client.profile, { won = winnerSlot == slot, pvp = true,
					kits = if team then team.kits else { match.world.kits[slot] } })
				client.questGifts = Quests.grant(client.profile)
			end
		end
	end
	local before = { ca.profile.rating, cb.profile.rating }
	if match.queue == "RANKED" and share > 0 then
		local newA, newB = Matchmaker.elo(ca.profile.rating, cb.profile.rating, scoreA)
		ca.profile.rating = AntiCheat.scaleRating(before[1], newA, share)
		cb.profile.rating = AntiCheat.scaleRating(before[2], newB, share)
		GameModes.achievementProgress(ca.profile, { rating = ca.profile.rating })
		GameModes.achievementProgress(cb.profile, { rating = cb.profile.rating })
	end
	for i, player in { a, b } do
		local client = clients[player]
		saveProfile(player, client, client.questGifts and #client.questGifts > 0)
		menuRemote:FireClient(player, {
			questGifts = client.questGifts,
			result = true, queue = match.queue, won = winnerSlot == i, draw = winnerSlot == 0,
			rating = client.profile.rating, delta = client.profile.rating - before[i],
			rank = Matchmaker.rankName(client.profile.rating), coins = gains[i],
		})
		client.questGifts = nil
	end
end

-- What the menu of a player shows: where they are, their rank, the queues.
function menuStatus(player, bought, unlocked)
	local client = clients[player]
	if not client then return end
	local profile = client.profile or defaultProfile()
	menuRemote:FireClient(player, {
		state = if client.match then "match" elseif client.queue then "queue" else "menu",
		mode = client.match and client.match.mode or nil, queue = client.queue,
		rating = profile.rating, rank = Matchmaker.rankName(profile.rating), hero = profile.hero, language = profile.language,
		nextRank = (function()
			for _, r in Matchmaker.RANKS do
				if r.min > profile.rating then return r.min end
			end
			return nil
		end)(),
		wins = profile.wins, losses = profile.losses, survivalBest = profile.survivalBest, coins = profile.coins or 0,
		-- (only once the saved profile is in: the defaults must not be applied in its place)
		options = if not store or SaveQueue.isLoaded(saves, player.UserId)
			then { optReduced = profile.optReduced, optSound = profile.optSound, optMusic = profile.optMusic,
				optTaunts = profile.optTaunts, tauntKey = profile.tauntKey } else nil,
		taunts = Taunts.sanitize(profile.taunts, profile), -- (the wheel, and the menu's TAUNTS page)
		ownedSkins = profile.ownedSkins or {}, bought = bought, -- (SHOP: the styles bought)
		ownedKits = profile.ownedKits or {}, unlocked = unlocked, equipped = profile.equipped or {},
		quests = profile.quests or {}, titles = profile.titles or {}, champions = championHistory,
		isDev = DevAccess.isDev(player.UserId, game.CreatorId, CREATOR_IS_USER), dev = devOn(player, client),
		asuraGrade = profile.asuraGrade, asuraDamage = profile.asuraDamage, title = profile.title,
		achWins = profile.achWins, achRating = profile.achRating, achSurvival = profile.achSurvival,
		achAsuraDamage = profile.achAsuraDamage, achAsuraGrade = profile.achAsuraGrade, achShinGrade = profile.achShinGrade,
		shinGrade = profile.shinGrade,
		waiting = { NORMAL = Matchmaker.waitingIn(matchmaker, "NORMAL"), RANKED = Matchmaker.waitingIn(matchmaker, "RANKED") },
		online = #Players:GetPlayers(), matches = (function()
			local n = 0
			for _ in matches do n += 1 end
			return n
		end)(),
	})
end

-- CHAMPION OF THE WEEK (Champions): the existing ranking is untouched; at each new week
-- (Monday 00:00 UTC) the player first on it becomes the champion of the week that ended,
-- written once in a shared history (UpdateAsync: one write per week whatever the servers).
-- The champion gets the title WEEKLY CHAMPION (not for sale), here or when they next join.
local championStore = nil
if store then
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, "JeuxCombat_Champions_v1")
	if ok then championStore = result end
end
local function grantChampion(player, client)
	if not (client and client.profile and (not store or SaveQueue.isLoaded(saves, player.UserId))) then return end
	if Champions.grant(client.profile, player.UserId, championHistory) > 0 then
		saveProfile(player, client, true)
		menuRemote:FireClient(player, { champion = true })
		menuStatus(player)
	end
end
task.spawn(function()
	while championStore do
		local okRead, history = pcall(championStore.GetAsync, championStore, "history")
		if okRead and type(history) == "table" then championHistory = history end
		local week = Champions.week(os.time())
		local last = championHistory[#championHistory]
		if board and (not last or last.week < week - 1) then
			local okTop, pages = pcall(board.GetSortedAsync, board, false, 1)
			local top = okTop and pages and pages:GetCurrentPage()[1]
			local id = top and tonumber(top.key)
			if id then
				local okName, name = pcall(Players.GetNameFromUserIdAsync, Players, id)
				local champion = { id = id, name = if okName then name else "#" .. id, rating = top.value }
				local okWrite, written = pcall(championStore.UpdateAsync, championStore, "history", function(old)
					return Champions.record(old, week - 1, champion) -- (nil: already written by a server)
				end)
				if okWrite and type(written) == "table" then championHistory = written end
			end
		end
		for player, client in clients do grantChampion(player, client) end
		task.wait(300)
	end
end)

-- ===================================================================== hub (friends)
local function hubStatus()
	local list = Lobby.status(lobby)
	for _, entry in list do
		local player = Players:GetPlayerByUserId(entry.id)
		local client = player and clients[player]
		entry.slot = if client and client.match then client.slot else 0
		entry.title = if player then player:GetAttribute("Title") or "" else "" -- (a challenge title, WEEKLY CHAMPION...)
		entry.where = if not client then "?"
			elseif client.match then (if client.match.mode == "VERSUS" then "IN A FIGHT" elseif client.match.mode == "TRAINING" then "TRAINING"
				elseif GameModes.find(client.match.mode) and GameModes.find(client.match.mode).boss then "VS " .. GameModes.find(client.match.mode).boss
				else "VS THE CPU")
			elseif client.queue then "SEARCHING" else "IN THE MENU"
	end
	return list
end
-- The hub screens: each player gets its own short view (Lobby.view: itself, its challenges,
-- then the others, at most Lobby.VIEW_LIMIT names) instead of every name on the server, and
-- the updates are gathered: at most one send every HUB_PERIOD seconds however many players
-- act at once (a full server stays linear, not players x players).
local HUB_PERIOD = 0.5
local lastHubKey, hubDirty, lastHubSend = nil, false, -math.huge
local function flushHub(force)
	hubDirty = false
	lastHubSend = os.clock()
	local list = hubStatus()
	local parts = {}
	for _, e in list do
		table.insert(parts, table.concat({ e.id, e.where, tostring(e.sent), table.concat(e.from, ","), e.title or "" }, ":"))
	end
	local key = table.concat(parts, "|")
	if key == lastHubKey and not force then return end -- (nothing changed: no redraw on every client)
	lastHubKey = key
	local byId = Lobby.index(list)
	for player in clients do
		local view, total = Lobby.view(list, player.UserId, nil, byId)
		hubRemote:FireClient(player, { players = view, total = total, seconds = Lobby.CHALLENGE_SECONDS })
	end
end
local function broadcastHub(force)
	hubDirty = true
	if force or os.clock() - lastHubSend >= HUB_PERIOD then flushHub(force) end
end
task.spawn(function()
	while true do
		task.wait(HUB_PERIOD)
		if hubDirty then flushHub(false) end
	end
end)

-- ===================================================================== lobby hero
-- The player's favourite fighter stands in the middle of the stage behind the main menu
-- (workspace.Fighters.Lobby_<user id>); only that player draws it (like the matches).
local function buildHero(player)
	local client = clients[player]
	if not client then return end
	client.heroTicket = (client.heroTicket or 0) + 1
	local ticket = client.heroTicket
	local kit = client.profile and client.profile.hero or "KAI"
	local look = CharacterData.Skins[CharacterData.styleFor(kit, client.profile, nil, devOn(player, client))]
	player:SetAttribute("Title", client.profile and client.profile.title or "") -- (shown over the hero and in the hub)
	task.spawn(function()
		local model
		if client.avatar then
			local ok, built = pcall(RigBuilder.buildAvatar, 1, player, rigOf(player, client), look) -- yields
			model = if ok then built else nil
		end
		model = model or RigBuilder.build(1, nil, look)
		if clients[player] ~= client or client.heroTicket ~= ticket then
			model:Destroy()
			return
		end
		local folderName = "Lobby_" .. player.UserId
		local holder = fightersFolder:FindFirstChild(folderName)
		if holder then holder:ClearAllChildren() else
			holder = Instance.new("Folder")
			holder.Name, holder.Parent = folderName, fightersFolder
		end
		model.Name = "Hero"
		model.Parent = holder
		RigReader.ensureJoints(model)
		local root = model:FindFirstChild("HumanoidRootPart")
		if root then
			local pos = Vector3.new(0, Config.RootHeight, Config.PlaneZ)
			root.CFrame = CFrame.lookAt(pos, pos + Vector3.new(1, 0, 0))
		end
		player:SetAttribute("HeroKit", kit)
	end)
end

-- The fighter select shows each fighter's own 3D model, posed by the client (MenuController):
-- one body per kit in its first style (and ASURA's), built once at start in
-- ReplicatedStorage.KitPreviews. Cosmetic only.
task.spawn(function()
	local folder = Instance.new("Folder")
	folder.Name = "KitPreviews"
	local names = table.clone(MoveData.KitOrder)
	table.insert(names, "ASURA")
	table.insert(names, "KUROEN SHIN")
	for _, name in names do
		local ok, model = pcall(RigBuilder.build, 1, nil, CharacterData.Skins[CharacterData.defaultStyle(name, nil)])
		if ok and model then
			model.Name = name
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then d.CastShadow = false end
			end
			model.Parent = folder
		else
			warn("[FightingGame] Preview of " .. name .. " failed: " .. tostring(model))
		end
		task.wait()
	end
	folder.Parent = ReplicatedStorage
end)

-- The FIGHTERS page previews every style of a fighter on its body: one model per style, built
-- the first time a player looks at it, then shared by everyone (ReplicatedStorage.StylePreviews).
local styleFolder = Instance.new("Folder")
styleFolder.Name = "StylePreviews"
styleFolder.Parent = ReplicatedStorage
local styleBuilding = {}
previewStyle = function(name)
	local style = CharacterData.Skins[name]
	if not style or styleBuilding[name] or styleFolder:FindFirstChild(name) then return end
	styleBuilding[name] = true
	task.spawn(function()
		local ok, model = pcall(RigBuilder.build, 1, nil, style)
		if ok and model then
			model.Name = name
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then d.CastShadow = false end
			end
			model.Parent = styleFolder
		else
			warn("[FightingGame] Preview of the style " .. name .. " failed: " .. tostring(model))
		end
		styleBuilding[name] = nil
	end)
end

-- ===================================================================== cross-server RANKED
--[[
	RANKED across every server (GlobalQueue decides, tests: Lobby): a RANKED player who found
	nobody here for GlobalQueue.PUBLISH_AFTER s is published in a MemoryStore sorted map
	(sorted by rating). Every 2 s this server looks for an opponent for its published
	players (as the pair's initiator only), claims it atomically, reserves a server and
	teleports its player there; the opponent's server sees the claim and sends its own. The
	reserved server starts the RANKED match when both arrived. Published game only: in Studio
	the calls fail (pcall) and the search stays on this server.
]]
local rankedMap = nil
do
	local ok, result = pcall(MemoryStoreService.GetSortedMap, MemoryStoreService, "RankedQueue_v1")
	if ok then rankedMap = result end
end
local published = {} -- user id -> { entry, refreshed }
local crossPending = {} -- reserved server: code -> { expect, created, started }

local function unpublish(id)
	if published[id] and rankedMap then
		task.spawn(function() pcall(rankedMap.RemoveAsync, rankedMap, tostring(id)) end)
	end
	published[id] = nil
end

local function teleportToMatch(player, code, partner)
	local client = clients[player]
	if not client then return end
	Matchmaker.leave(matchmaker, player.UserId)
	client.queue = nil
	unpublish(player.UserId)
	local data = { cross = { code = code, expect = { player.UserId, partner }, team = client.team } }
	local ok = pcall(TeleportService.TeleportToPrivateServer, TeleportService, game.PlaceId, code, { player }, nil, data)
	if not ok then
		menuRemote:FireClient(player, { error = "THE OPPONENT'S SERVER COULD NOT BE REACHED" })
		menuStatus(player)
	end
end

local function crossStep()
	if not rankedMap then return end
	local now = os.time()
	-- publish / refresh this server's RANKED players who waited long enough
	for player, client in clients do
		local id = player.UserId
		if client.queue == "RANKED" and client.queueSince and now - client.queueSince >= GlobalQueue.PUBLISH_AFTER then
			local p = published[id]
			if not p or now - p.refreshed >= GlobalQueue.REFRESH then
				local entry = GlobalQueue.entry(id, client.profile.rating, #client.team, JOB, client.queueSince, client.team, now)
				local ok = pcall(rankedMap.SetAsync, rankedMap, tostring(id), entry, GlobalQueue.STALE + 10, math.floor(entry.rating))
				if ok then published[id] = { entry = entry, refreshed = now } end
			end
		elseif published[id] then
			unpublish(id) -- (found a local opponent, cancelled, left the menu)
		end
	end
	for id, p in published do
		local player = Players:GetPlayerByUserId(id)
		if not player or not clients[player] or clients[player].queue ~= "RANKED" then
			unpublish(id) -- (left, cancelled, or already paired on this server)
			continue
		end
		-- 1. did another server claim us? then go to its reserved server
		local okMine, mine = pcall(rankedMap.GetAsync, rankedMap, tostring(id))
		if okMine and type(mine) == "table" and mine.claim and mine.claim.by ~= JOB then
			teleportToMatch(player, mine.claim.code, mine.claim.partner)
			continue
		end
		-- 2. else, as the initiator, look for an opponent near our rating
		local me = p.entry
		local reach = GlobalQueue.window(now - me.since)
		local okRange, items = pcall(rankedMap.GetRangeAsync, rankedMap, Enum.SortDirection.Ascending, 100,
			{ sortKey = math.floor(me.rating - reach - 1) }, { sortKey = math.floor(me.rating + reach + 1) })
		if not okRange then continue end
		local entries = {}
		for _, item in items do
			if type(item.value) == "table" and item.value.job ~= JOB then table.insert(entries, item.value) end
		end
		local other = GlobalQueue.pick(me, entries, now)
		if other then
			local okCode, code = pcall(TeleportService.ReserveServer, TeleportService, game.PlaceId)
			if okCode and code then
				local claimed = nil
				pcall(rankedMap.UpdateAsync, rankedMap, tostring(other.id), function(current)
					claimed = GlobalQueue.claim(current, code, JOB, os.time(), id)
					return claimed
				end, GlobalQueue.STALE + 10)
				if claimed then
					teleportToMatch(player, code, other.id)
				end
			end
		end
	end
end
task.spawn(function()
	while true do
		task.wait(2)
		local ok, err = pcall(crossStep)
		if not ok then warn("[FightingGame] cross-server search: " .. tostring(err)) end
	end
end)

-- The reserved server: a player arriving for a cross-server match waits for the other one.
arrivedForCrossMatch = function(player, client)
	local okJoin, join = pcall(player.GetJoinData, player)
	local data = okJoin and type(join) == "table" and type(join.TeleportData) == "table" and join.TeleportData.cross
	if type(data) ~= "table" or game.PrivateServerId == "" or type(data.code) ~= "string" or type(data.expect) ~= "table" then return end
	local request = GameModes.validate({ mode = "VERSUS_CPU", team = data.team, level = 1 }, MoveData.KitOrder)
	if request then client.team = request.team end
	local pending = crossPending[data.code]
	if not pending then
		local expect = {}
		for _, id in data.expect do
			if typeof(id) == "number" then table.insert(expect, id) end
		end
		pending = { expect = expect, created = os.clock() }
		crossPending[data.code] = pending
	end
	if GlobalQueue.arrival(pending, player.UserId, os.clock()) and not pending.started then
		pending.started = true
		task.spawn(function()
			-- (both profiles in first: the rating at stake must be the saved one)
			local a, b = Players:GetPlayerByUserId(pending.expect[1]), Players:GetPlayerByUserId(pending.expect[2])
			local started = os.clock()
			while a and b and clients[a] and clients[b] and not (clients[a].profileLoaded and clients[b].profileLoaded)
				and os.clock() - started < 20 do
				task.wait(0.5)
			end
			if a and b and clients[a] and clients[b] then startVersus(a, b, "RANKED") end
		end)
	end
end
task.spawn(function()
	while true do
		task.wait(5)
		for code, pending in crossPending do
			if not pending.started and GlobalQueue.expired(pending, os.clock()) then
				crossPending[code] = nil
				for id in pending.arrived or {} do
					local p = Players:GetPlayerByUserId(id)
					if p and clients[p] then
						menuRemote:FireClient(p, { error = "YOUR OPPONENT DID NOT ARRIVE: search again" })
						menuStatus(p)
					end
				end
			end
		end
	end
end)

local function joined(player)
	if clients[player] then return end
	local client = {
		tokens = 60, lastPacket = os.clock(), lastReset = -math.huge, lastDummy = -math.huge,
		lastAvatar = -math.huge, lastSeq = 0, avatar = false, rig = nil, lastHub = -math.huge, lastMenu = -math.huge,
		team = { "KAI" },
	}
	clients[player] = client
	client.onProfileLoaded = function()
		grantChampion(player, client)
		buildHero(player)
		menuStatus(player)
	end
	arrivedForCrossMatch(player, client)
	loadProfile(player, client)
	buildHero(player)
	player:SetAttribute("Avatar", false) -- the block model of the kit; APPARENCE: avatar R15
	player:SetAttribute("FighterSlot", 0)
	player:SetAttribute("MatchId", 0)
	Lobby.join(lobby, player.UserId, player.DisplayName)
	lobby.slots = {} -- (the lobby only keeps the challenges; matches seat the players)
	menuStatus(player)
	broadcastHub()
end
Players.PlayerAdded:Connect(joined)
Players.PlayerRemoving:Connect(function(player)
	AntiCheat.forget(ac, player.UserId)
	local client = clients[player]
	if client then
		Matchmaker.leave(matchmaker, player.UserId)
		unseat(player)
		-- (the last write, right away; then the queue forgets the player)
		if store and client.profile and SaveQueue.isLoaded(saves, player.UserId) then
			task.spawn(function()
				writeProfile(player, client, true) -- (the last write releases the session lock)
				SaveQueue.forget(saves, player.UserId)
			end)
		else
			SaveQueue.forget(saves, player.UserId)
		end
		local holder = fightersFolder:FindFirstChild("Lobby_" .. player.UserId)
		if holder then holder:Destroy() end
	end
	Lobby.leave(lobby, player.UserId)
	lobby.slots = {}
	clients[player] = nil
	broadcastHub()
end)

-- DÉFIER, ACCEPTER, REFUSER (see Lobby). An accepted challenge starts a 1v1 (no points).
local HUB_ACTIONS = { challenge = true, accept = true, decline = true, hello = true }
hubRemote.OnServerEvent:Connect(function(player, action, target)
	local client = clients[player]
	if not client then return end
	if typeof(action) ~= "string" or not HUB_ACTIONS[action] then return suspect(player, "malformed") end
	if target ~= nil and (typeof(target) ~= "number" or target % 1 ~= 0) then return suspect(player, "malformed") end
	local now = os.clock()
	if now - client.lastHub < 0.4 then return end
	client.lastHub = now
	local id = player.UserId
	if action == "hello" then
		local view, total = Lobby.view(hubStatus(), player.UserId)
		hubRemote:FireClient(player, { players = view, total = total, seconds = Lobby.CHALLENGE_SECONDS })
		return
	end
	local ok
	if action == "challenge" then ok = target ~= nil and Lobby.challenge(lobby, id, target, now)
	elseif action == "accept" then
		ok = target ~= nil and Lobby.accept(lobby, id, target, now)
		lobby.slots = {}
		local challenger = ok and Players:GetPlayerByUserId(target)
		if challenger and clients[challenger] then
			for _, p in { player, challenger } do
				Matchmaker.leave(matchmaker, p.UserId)
				clients[p].queue = nil
				unseat(p)
			end
			startVersus(challenger, player, "FRIEND")
		end
	else ok = target ~= nil and Lobby.decline(lobby, id, target) end
	if ok then broadcastHub() end
end)

-- ===================================================================== menu requests
-- { action = "start", request = { mode, team, level, queue } } · { action = "cancel" } (leave
-- the queue) · { action = "leave" } (back to the menu) · { action = "hello" }.
local MENU_ACTIONS = { hello = true, hero = true, language = true, options = true, team = true, ranking = true,
	start = true, cancel = true, leave = true, taunts = true, buySkin = true, buyFighter = true, equip = true, title = true,
	devMode = true, preview = true }
menuRemote.OnServerEvent:Connect(function(player, packet)
	local client = clients[player]
	if not client then return end
	if typeof(packet) ~= "table" or typeof(packet.action) ~= "string" or not MENU_ACTIONS[packet.action] then
		return suspect(player, "malformed")
	end
	local now = os.clock()
	if now - client.lastMenu < 0.5 then return end
	client.lastMenu = now
	local action = packet.action
	if action == "hello" then
		menuStatus(player)
	elseif action == "hero" then
		-- PERSONNAGES / MES PERSONNAGES: the favourite fighter (also the lobby's hero).
		if typeof(packet.kit) == "string" and table.find(MoveData.KitOrder, packet.kit) and client.profile
			and Economy.canPlay(client.profile, packet.kit, "VERSUS", devOn(player, client)) then
			client.profile.hero = packet.kit
			saveProfile(player, client)
			buildHero(player)
			menuStatus(player)
		end
	elseif action == "language" then
		-- SETTINGS › LANGUAGE, kept with the profile.
		if (packet.language == "AUTO" or packet.language == "EN" or packet.language == "FR") and client.profile then
			client.profile.language = packet.language
			saveProfile(player, client)
			menuStatus(player)
		end
	elseif action == "options" then
		-- SETTINGS › EFFECTS / SOUND / MUSIC, kept with the profile (booleans only).
		local o = packet.options
		if typeof(o) == "table" and client.profile then
			for _, key in { "optReduced", "optSound", "optMusic", "optTaunts" } do
				if typeof(o[key]) == "boolean" then client.profile[key] = o[key] end
			end
			if typeof(o.tauntKey) == "string" and table.find(Taunts.KEYS, o.tauntKey) then client.profile.tauntKey = o.tauntKey end
			saveProfile(player, client)
		end
	elseif action == "taunts" then
		-- TAUNTS: the 6 taunts of the wheel (only known, unlocked ones are kept: Taunts.sanitize).
		if client.profile then
			client.profile.taunts = Taunts.sanitize(packet.taunts, client.profile)
			saveProfile(player, client)
			menuStatus(player)
		end
	elseif action == "buySkin" then
		-- SHOP: a style bought with coins (price and ownership checked here, never by the client).
		if typeof(packet.skin) ~= "string" then return suspect(player, "malformed") end
		if client.profile and (not store or SaveQueue.isLoaded(saves, player.UserId)) then
			local ok, why = CharacterData.buy(client.profile, packet.skin)
			if ok then
				saveProfile(player, client, true)
				menuStatus(player, packet.skin)
			else
				menuRemote:FireClient(player, { error = if why == "coins" then "NOT ENOUGH COINS"
					elseif why == "quest" then "THIS STYLE IS A QUEST REWARD" elseif why == "owned" then "ALREADY OWNED" else "STYLE NOT FOR SALE" })
			end
		end
	elseif action == "buyFighter" then
		-- A fighter unlocked for coins (Economy: price, ownership; kept forever). Only once the
		-- saved profile is in (never bought on a default profile that would be lost).
		if typeof(packet.kit) ~= "string" then return suspect(player, "malformed") end
		if client.profile and (not store or SaveQueue.isLoaded(saves, player.UserId)) then
			local ok, why = Economy.buyFighter(client.profile, packet.kit, MoveData.KitOrder)
			if ok then
				saveProfile(player, client, true)
				menuStatus(player, nil, packet.kit)
			else
				menuRemote:FireClient(player, { error = if why == "coins" then "NOT ENOUGH COINS"
					elseif why == "owned" then "ALREADY OWNED" else "FIGHTER NOT FOR SALE" })
			end
		end
	elseif action == "equip" then
		-- The style worn with a fighter (only one the player may wear; cosmetic only).
		local style = typeof(packet.skin) == "string" and CharacterData.Skins[packet.skin]
		if not style then return suspect(player, "malformed") end
		if client.profile and CharacterData.canWear(packet.skin, client.profile, devOn(player, client)) then
			client.profile.equipped[style.Kit] = packet.skin
			saveProfile(player, client)
			if client.profile.hero == style.Kit then buildHero(player) end
			menuStatus(player)
		end
	elseif action == "title" then
		-- The title shown on the profile and in the lobby: one the player has, or none.
		if typeof(packet.title) ~= "string" then return suspect(player, "malformed") end
		if client.profile and Champions.canShow(client.profile, packet.title) then
			client.profile.title = packet.title
			player:SetAttribute("Title", packet.title)
			saveProfile(player, client)
			menuStatus(player)
			broadcastHub(true)
		end
	elseif action == "devMode" then
		-- The developer access switched off / on (only for a developer: DevAccess).
		if typeof(packet.on) ~= "boolean" then return suspect(player, "malformed") end
		if client.profile and DevAccess.isDev(player.UserId, game.CreatorId, CREATOR_IS_USER) then
			client.profile.devOff = not packet.on
			saveProfile(player, client)
			buildHero(player)
			menuStatus(player)
		end
	elseif action == "preview" then
		-- The 3D preview of a style in the FIGHTERS page (built once per style, shared).
		if typeof(packet.skin) ~= "string" then return suspect(player, "malformed") end
		previewStyle(packet.skin)
	elseif action == "team" then
		-- The team chosen for a friend's challenge (DÉFIER AMI), without joining a queue.
		local request = GameModes.validate({ mode = "VERSUS_CPU", team = packet.team, level = 1 }, MoveData.KitOrder)
		if request and Economy.teamAllowed(client.profile, request.team, "VERSUS", devOn(player, client)) then client.team = request.team end
	elseif action == "ranking" then
		task.spawn(function()
			local list = topRatings()
			if clients[player] then menuRemote:FireClient(player, { ranking = list }) end
		end)
	elseif action == "start" then
		local request, reason = GameModes.validate(packet.request, MoveData.KitOrder, Maps.BY_ID)
		if not request then
			menuRemote:FireClient(player, { error = reason })
			return
		end
		-- (a locked fighter: TRAINING only, to try it; the developer access plays them all)
		local allowed, locked = Economy.teamAllowed(client.profile, request.team, request.mode, devOn(player, client))
		if not allowed then
			menuRemote:FireClient(player, { error = "FIGHTER LOCKED: " .. tostring(locked) .. " (TRAINING ONLY)" })
			return
		end
		Matchmaker.leave(matchmaker, player.UserId)
		client.queue = nil
		unseat(player)
		client.team = request.team
		if request.mode == "VERSUS" then
			client.queue = request.queue
			client.queueSince = os.time() -- (the cross-server search publishes after a while)
			local rating = client.profile and client.profile.rating or Matchmaker.START_RATING
			Matchmaker.enqueue(matchmaker, player.UserId, request.queue, rating, now, #request.team)
			menuStatus(player)
		else
			startSolo(player, request)
		end
	elseif action == "cancel" then
		Matchmaker.leave(matchmaker, player.UserId)
		client.queue = nil
		menuStatus(player)
	elseif action == "leave" then
		Matchmaker.leave(matchmaker, player.UserId)
		client.queue = nil
		unseat(player)
		menuStatus(player)
	end
	broadcastHub()
end)

-- Opponent search: every second, pair the waiting players (see Matchmaker).
task.spawn(function()
	while true do
		task.wait(1)
		for _, pair in Matchmaker.pair(matchmaker, os.clock()) do
			local a, b = Players:GetPlayerByUserId(pair.a), Players:GetPlayerByUserId(pair.b)
			if a and b and clients[a] and clients[b] then
				clients[a].queue, clients[b].queue = nil, nil
				startVersus(a, b, pair.queue)
			else
				-- One of them left in the meantime: the other one waits again.
				for _, p in { a, b } do
					if p and clients[p] and clients[p].queue then
						Matchmaker.enqueue(matchmaker, p.UserId, clients[p].queue, clients[p].profile.rating, os.clock(), #clients[p].team)
					end
				end
			end
		end
		for player, client in clients do
			if client.queue then menuStatus(player) end -- (waiting counts)
		end
		broadcastHub()
		Lobby.expire(lobby, os.clock())
	end
end)

-- Network latency of each fighting player, once a second: the simulation compensates far
-- players a little (late links, QTE), within CombatConfig.MaxLatencyTicks.
task.spawn(function()
	while true do
		task.wait(1)
		for _, match in matches do
			for i, slot in match.slots do
				local owner, ping = slot.owner, nil
				if owner then
					local ok, value = pcall(owner.GetNetworkPing, owner) -- round trip, in seconds
					if ok and typeof(value) == "number" and value == value then ping = math.clamp(value, 0, 2) end
				end
				slot.ping = ping
				local f = match.world.fighters[i]
				if f then
					f.latencyTicks = if ping then math.clamp(math.floor(ping / 2 * Config.TickRate + 0.5), 0, Config.MaxLatencyTicks) else 0
				end
			end
		end
	end
end)
for _, player in Players:GetPlayers() do joined(player) end

-- ===================================================================== input
local function finite(n)
	return typeof(n) == "number" and n == n and math.abs(n) < math.huge
end
local BOOLEAN_FIELDS = {
	"crouch", "block", "jump", "dash", "reset", "dummy", "avatar", "skin", "kit", "foeKit", "ultiConditions",
}

local function nextKit(kit)
	local order = MoveData.KitOrder
	return order[(table.find(order, kit) or 0) % #order + 1]
end
-- Training only: the player's kit (T) and the dummy / CPU's (G).
local function pickKit(match, i, kit)
	local kits = { match.world.kits[1], match.world.kits[2] }
	kits[i] = kit
	Sim.setKits(match.world, kits[1], kits[2])
	refreshLooks(match)
end

inputRemote.OnServerEvent:Connect(function(player, packet)
	local client = clients[player]
	if not client then return end
	local now = os.clock()
	client.tokens = math.min(60, client.tokens + (now - client.lastPacket) * 60)
	client.lastPacket = now
	if client.tokens < 1 then
		client.drops = client.drops or {}
		if AntiCheat.dropped(client.drops, now) then suspect(player, "flood") end
		return
	end
	client.tokens -= 1
	local match = client.match
	-- (every check below fails only for a forged packet: the game's own client never sends it)
	if typeof(packet) ~= "table" then return suspect(player, "malformed") end
	if not match then return end
	if not finite(packet.seq) or packet.seq % 1 ~= 0 or packet.seq > 1e9 then return suspect(player, "malformed") end
	if packet.seq <= client.lastSeq then return suspect(player, "replay") end
	if not finite(packet.axis) or math.abs(packet.axis) > 1 then return suspect(player, "malformed") end
	for _, field in BOOLEAN_FIELDS do
		if typeof(packet[field]) ~= "boolean" then return suspect(player, "malformed") end
	end
	if not PressQueue.valid(packet.presses) then return suspect(player, "malformed") end
	local stance = packet.stance
	if stance ~= nil and (not finite(stance) or stance % 1 ~= 0 or stance < 0 or stance > 2) then return suspect(player, "malformed") end
	-- The cinematic tick the player saw (QTE lag compensation, bounded by the simulation).
	local cinTick = packet.cinTick
	if cinTick ~= nil and (not finite(cinTick) or cinTick < 0 or cinTick > 10000) then return suspect(player, "malformed") end
	-- QUICK TRASH TALK: only a slot number of the player's saved wheel (never a text).
	local taunt = packet.taunt
	if taunt ~= nil and (not finite(taunt) or taunt % 1 ~= 0 or taunt < 0 or taunt > Taunts.SLOTS) then return suspect(player, "malformed") end
	client.lastSeq = packet.seq
	local slot = match.slots[client.slot]
	if slot.owner ~= player then return end
	local world = match.world
	local training = match.mode == "TRAINING"
	if packet.reset and training and now - client.lastReset > 1 then
		client.lastReset = now
		resetAll(match)
	end
	-- Training: the ultimates' conditions switched on (ki always full, COUP FATAL ready).
	if packet.ultiConditions and training and now - (client.lastUlti or -math.huge) > 0.3 then
		client.lastUlti = now
		world.ultimateConditions = if world.ultimateConditions then nil else client.slot
	end
	if packet.dummy and training and now - client.lastDummy > 0.3 then
		client.lastDummy = now
		match.dummyMode = match.dummyMode % #DUMMY_MODES + 1
		resetAll(match)
	end
	if packet.kit and training and now - (client.lastKit or -math.huge) > 0.5 then
		client.lastKit = now
		pickKit(match, client.slot, nextKit(world.kits[client.slot]))
		resetAll(match)
	end
	if packet.foeKit and training and now - (client.lastKit or -math.huge) > 0.5 then
		client.lastKit = now
		local other = 3 - client.slot
		pickKit(match, other, nextKit(world.kits[other]))
		resetAll(match)
	end
	if packet.skin and now - (client.lastSkin or -math.huge) > 1 then
		-- Next colour style of the kit; the other slot keeps a different one.
		client.lastSkin = now
		local mine, other = client.slot, 3 - client.slot
		-- (Styles to earn, KAI's ÉVEILLÉ and KUROEN's DIVINE, are skipped until won: the CHALLENGES.)
		local name = match.characters[mine].Skin
		-- (and the shop styles until bought: CharacterData.canWear)
		for _ = 1, 16 do
			name = CharacterData.nextSkin(name, match.characters[other].Skin)
			if CharacterData.canWear(name, client.profile, devOn(player, client)) then break end
		end
		if not CharacterData.canWear(name, client.profile, devOn(player, client)) then name = match.characters[mine].Skin end
		match.characters[mine] = CharacterData.Skins[name]
		rebuildSlot(match, mine)
	end
	if packet.avatar and now - client.lastAvatar > 2 then
		-- APPARENCE: block model (the default) <-> avatar R15 (no more R6).
		client.lastAvatar = now
		client.avatar, client.rig = not client.avatar, "R15"
		player:SetAttribute("Avatar", client.avatar)
		player:SetAttribute("AvatarRig", client.rig)
		rebuildSlot(match, client.slot)
		if not match.slots[3 - client.slot].owner then rebuildSlot(match, 3 - client.slot) end
	end
	local input = slot.input
	input.axis, input.crouch, input.block = packet.axis, packet.crouch, packet.block
	-- Pulses stay set until the next simulation tick consumes them.
	input.jump = input.jump or packet.jump
	input.dash = input.dash or packet.dash
	if stance and stance > 0 then input.stance = stance end -- TARO's style keys (1 / 2)
	input.cinTick = if cinTick then math.floor(cinTick) else nil
	-- A taunt: the slot's taunt of the saved wheel, once every Taunts.COOLDOWN s (server
	-- clock), shown to everyone in the match as a bubble (an event out of the simulation:
	-- it never touches the fight).
	if taunt and taunt > 0 and client.profile then
		client.tauntState = client.tauntState or {}
		local id = Taunts.request(client.tauntState, client.profile.taunts, taunt, now)
		if id then table.insert(match.pendingDebug, { kind = "Taunt", slot = client.slot, id = id, tick = world.tick }) end
	end
	-- Attack presses keep their count and order (see PressQueue): one per tick.
	PressQueue.push(slot.presses, packet.presses)
	slot.lastInput = now
end)

-- ===================================================================== snapshots
-- Fields that rarely change (names, looks, kit) go out only when they change, or every two
-- seconds for a client that just arrived: snapshots stay small for far players.
local function roster(match)
	local list = {}
	for i, slot in match.slots do
		local character = match.characters[i]
		local name = if slot.owner then slot.owner.DisplayName
			elseif match.mode == "TRAINING" then "DUMMY · " .. DUMMY_MODES[match.dummyMode].name
			elseif match.mode == "SURVIVAL" then "CPU · WAVE " .. match.wave
			elseif GameModes.find(match.mode) and GameModes.find(match.mode).boss then GameModes.find(match.mode).boss .. " · BOSS"
			else "CPU · " .. (FighterAI.Levels[match.level or 1] or FighterAI.Levels[1]).name
		list[i] = {
			owner = if slot.owner then slot.owner.UserId else 0, player = name,
			character = character and character.Name or "?", skin = character and character.Skin or "",
			kit = match.world.fighters[i].kit, maxHp = match.world.fighters[i].maxHp,
		}
	end
	return list
end
local function rosterKey(list)
	local parts = {}
	for i, r in list do
		parts[i] = table.concat({ r.owner, r.player, r.character, r.skin, r.kit, r.maxHp }, "|")
	end
	return table.concat(parts, "#")
end

local function recipients(match)
	local list = {}
	for _, slot in match.slots do
		if slot.owner then table.insert(list, slot.owner) end
	end
	return list
end

local function snapshot(match)
	local world = match.world
	local names = roster(match)
	local key = rosterKey(names)
	local now = os.clock()
	local sendRoster = key ~= match.lastRoster or now - match.lastRosterAt > 2
	if sendRoster then match.lastRoster, match.lastRosterAt = key, now end
	local list = {}
	for i, slot in match.slots do
		local f = world.fighters[i]
		local team = world.teams and world.teams[i]
		list[i] = {
			x = f.x, y = f.y, vx = f.vx + f.pushVx, vy = f.vy, facing = f.facing, state = f.state,
			move = f.move or "", moveFrame = f.moveFrame, hitstop = f.hitstop,
			hp = f.hp, guard = f.guard, meter = f.meter, combo = f.comboHits, comboDamage = f.comboDamage, wins = f.wins,
			crouching = f.crouching, maxHp = f.maxHp, passive = Sim.passiveGauge(world, f), weave = f.weaveTicks > 0,
			passiveCharges = Sim.passiveCharges(world, f) or 0,
			passiveLabel = Sim.passiveLabel(world, f), passiveOn = select(2, Sim.passiveLabel(world, f)), -- (third sheet)
			chilled = f.chilled > 0 or nil, poisoned = f.poisonTicks > 0 or nil, tempo = f.tempo > 0 or nil,
			wakeInvuln = f.wakeInvuln, -- (the body blinks while untouchable after getting up)
			revived = f.revived or nil, -- ASURA's SECOND LIFE (black aura)
			domination = if f.domination > 0 then f.domination else nil, -- KUROEN's DOMINATION (his aura)
			stance = f.stance, -- TARO: "CLASSIC" / "PEEKABOO"
			fatal = if f.fatalUsed then "used" elseif Sim.fatalReady(world, f) then "ready" else "none", -- COUP FATAL
			chainKeys = f.chainKeys, chainClean = f.chainClean, cancelReady = Sim.cancelReady(world, f),
			dirtyReason = f.dirtyReason or "",
			kit = f.kit, ping = slot.ping and math.floor(slot.ping * 1000 + 0.5) or nil,
			team = team and team.kits or nil, teamIndex = team and team.index or nil, -- relay teams
		}
	end
	local projectiles = {}
	for _, p in world.projectiles do
		table.insert(projectiles, { id = p.id, x = p.x, y = p.y, vx = p.vx, owner = p.owner, trap = p.data.trap or nil,
			move = p.data.id })
	end
	for i, drone in world.drones or {} do -- NOVA's sentinels, drawn as small drones
		table.insert(projectiles, { id = "drone" .. drone.owner .. "-" .. i, x = drone.x, y = drone.y, vx = 0, owner = drone.owner, drone = true })
	end
	local packet = {
		projectiles = projectiles,
		tick = world.tick, generation = match.generation, epoch = world.epoch,
		phase = world.phase, phaseTicks = world.phaseTicks, round = world.round,
		timer = Sim.timerSeconds(world), training = world.training, solo = isSolo(match),
		mode = match.mode, matchId = match.id, wave = match.wave, queue = match.queue,
		dummyMode = DUMMY_MODES[match.dummyMode].name,
		ultimateConditions = world.ultimateConditions ~= nil,
		cinematic = world.cinematic and {
			attacker = world.cinematic.attacker, defender = world.cinematic.defender,
			tick = world.cinematic.tick, length = world.cinematic.length,
			move = world.cinematic.move, finish = world.cinematic.finish, style = world.cinematic.style, kit = world.cinematic.kit,
			nextPrompt = world.cinematic.nextPrompt, grade = world.cinematic.grade,
			prompts = world.cinematic.prompts, scale = Sim.cinematicScale(world),
		},
		winner = world.winner or -1, matchWinner = world.matchWinner or -1,
		fighters = list, roster = if sendRoster then names else nil,
	}
	for _, player in recipients(match) do
		snapshotRemote:FireClient(player, packet)
	end
end

-- Training lab (training only): play one of the player's kit's cinematics directly to check
-- its staging. `kind` is the cinematic type, `style` (ÉVEIL only) a full route of the kit.
local DEBUG_TYPES = { Rush = true, Awaken = true, Gate = true, Fatal = true }
debugRemote.OnServerEvent:Connect(function(player, kind, style, finish)
	local client = clients[player]
	if not client then return end
	if typeof(kind) ~= "string" or not DEBUG_TYPES[kind] or typeof(finish) ~= "boolean" then return suspect(player, "malformed") end
	local match = client.match
	-- (the CINE LAB button shows in every solo match: outside training the request is simply
	-- refused, never held against the player)
	if not match or match.mode ~= "TRAINING" or not isSolo(match) then return end
	local world = match.world
	local kit = Sim.kitOf(world, world.fighters[client.slot])
	local known = false
	for _, route in kit.FullRoutes do known = known or route.name == style end
	if kind == "Fatal" and style == "raw" then known = true end -- (the COUP FATAL thrown raw)
	if style ~= nil and (typeof(style) ~= "string" or not known) then return end
	local now = os.clock()
	if now - (client.lastDebug or -math.huge) < 1 or world.cinematic then return end
	client.lastDebug = now
	if kind == "Awaken" then style = style or kit.FullRoutes[1].name elseif kind ~= "Fatal" then style = nil end
	local events = Sim.debugCinematic(world, client.slot, kind, style, if finish then 300 else nil)
	for _, event in events do table.insert(match.pendingDebug, event) end
end)

-- ===================================================================== simulation
-- Mode rules that follow the simulation's events (SURVIE waves, relay rigs, end of match).
local function followEvents(match, events)
	local world = match.world
	for _, event in events do
		if event.kind == "RoundEnd" and match.mode == "SURVIVAL" and world.teams then
			local cpu = world.teams[2]
			if cpu.index > #cpu.kits then
				-- The opponent is down: the next one joins the queue of the CPU team.
				match.wave += 1
				local kit, level = GameModes.survivalOpponent(match.wave, MoveData.KitOrder, match.seed)
				table.insert(cpu.kits, kit)
				match.level = level
			end
		elseif event.kind == "TeamSwap" then
			refreshLooks(match) -- the next fighter of the team comes in (new rig)
			if event.slot == 2 and match.mode == "SURVIVAL" then match.brain = newBrain(match) end
		elseif event.kind == "MatchEnd" then
			local owner = match.slots[1].owner
			-- QUESTS: a solo match played to its end (CPU, survival, challenges; never TRAINING)
			if match.mode ~= "VERSUS" and match.mode ~= "TRAINING" and owner and clients[owner] then
				local client = clients[owner]
				local team = world.teams and world.teams[1]
				Quests.record(client.profile, { won = event.winner == 1, pvp = false, kits = if team then team.kits else { world.kits[1] } })
				local gifts = Quests.grant(client.profile)
				saveProfile(owner, client, #gifts > 0)
				if #gifts > 0 then menuRemote:FireClient(owner, { questGifts = gifts }) end
			end
			if match.mode == "SURVIVAL" and owner and clients[owner] then
				local client = clients[owner]
				local beaten = match.wave - 1
				GameModes.achievementProgress(client.profile, { survival = beaten })
				local gain = AntiCheat.capCoins(client.profile, GameModes.COINS.survivalWin * beaten, os.time())
				client.profile.coins = (client.profile.coins or 0) + gain
				client.profile.survivalBest = math.max(client.profile.survivalBest, beaten)
				saveProfile(owner, client) -- (the record and the achievements' counter)
				menuRemote:FireClient(owner, { result = true, survival = beaten, best = client.profile.survivalBest, coins = gain })
			elseif match.mode == "VERSUS" then
				endVersus(match, event.winner)
			elseif match.mode == "CHALLENGE_SHIN" and owner and clients[owner] then
				-- KUROEN SHIN: the grade (team size, health left), KUROEN's DIVINE style once beaten.
				local client = clients[owner]
				local team = world.teams and world.teams[1]
				local mine = world.fighters[1]
				local won = event.winner == 1
				local grade, _, unlock = GameModes.challengeGrade(won, team and #team.kits or 1, math.max(0, mine.hp) / mine.maxHp)
				local title = if grade > 0 then GameModes.SHIN_TITLES[grade] else nil
				local profile = client.profile
				local newBest = grade > (profile.shinGrade or 0)
				GameModes.achievementProgress(profile, { shinGrade = grade })
				local gain = if grade >= 1 then AntiCheat.capCoins(profile, GameModes.COINS.boss, os.time()) else 0
				profile.coins = (profile.coins or 0) + gain
				if newBest then
					profile.shinGrade = grade
					profile.title = title or profile.title
					if title and not table.find(profile.titles, title) then table.insert(profile.titles, title) end
					owner:SetAttribute("Title", profile.title)
				end
				saveProfile(owner, client)
				menuRemote:FireClient(owner, { result = true, challenge = true, boss = "KUROEN SHIN", coins = gain, won = won, grade = grade, title = title,
					newBest = newBest, unlock = unlock })
			elseif match.mode == "CHALLENGE" and owner and clients[owner] then
				-- The reward depends on how ASURA was beaten (GameModes.challengeGrade).
				local client = clients[owner]
				local team = world.teams and world.teams[1]
				local boss = world.fighters[2]
				local mine = world.fighters[1]
				local won = event.winner == 1
				local damage = if boss.kit == "ASURA" then 1 - math.max(0, boss.hp) / boss.maxHp else 1
				local grade, title, unlock = GameModes.challengeGrade(won, team and #team.kits or 1, math.max(0, mine.hp) / mine.maxHp)
				local profile = client.profile
				local newBest = grade > profile.asuraGrade
				profile.asuraDamage = math.max(profile.asuraDamage, math.floor(damage * 100 + 0.5))
				GameModes.achievementProgress(profile, { asuraDamage = math.floor(damage * 100 + 0.5), asuraGrade = grade })
				local gain = if grade >= 1 then AntiCheat.capCoins(profile, GameModes.COINS.boss, os.time()) else 0
				profile.coins = (profile.coins or 0) + gain
				if newBest then
					profile.asuraGrade = grade
					profile.title = title or profile.title
					if title and not table.find(profile.titles, title) then table.insert(profile.titles, title) end
					owner:SetAttribute("Title", profile.title)
				end
				saveProfile(owner, client)
				menuRemote:FireClient(owner, { result = true, challenge = true, coins = gain, won = won, grade = grade, title = title,
					newBest = newBest, unlock = unlock, damage = math.floor(damage * 100 + 0.5) })
			end
			if match.mode ~= "TRAINING" then
				-- Back to the menu once the end screen has been seen.
				task.delay(Config.MatchEndTicks / Config.TickRate - 0.5, function()
					for _, slot in match.slots do
						local player = slot.owner
						if player and clients[player] and clients[player].match == match then
							unseat(player)
							menuStatus(player)
						end
					end
					broadcastHub()
				end)
			end
		end
	end
end

local function stepMatch(match, dt)
	local world = match.world
	match.accumulator = math.min(match.accumulator + dt, Config.MaxCatchUpSteps / Config.TickRate)
	local batch = match.pendingDebug
	match.pendingDebug = {}
	while match.accumulator >= 1 / Config.TickRate do
		match.accumulator -= 1 / Config.TickRate
		local inputs = {}
		for i, slot in match.slots do
			if slot.owner then
				if os.clock() - slot.lastInput > Config.InputTimeout then
					slot.input = Sim.neutralInput()
					PressQueue.clear(slot.presses)
				end
				PressQueue.pop(slot.presses, slot.input)
				inputs[i] = slot.input
			elseif match.brain then
				inputs[i] = match.brain:think(world, i)
			else
				inputs[i] = Sim.neutralInput()
				inputs[i].block = match.mode == "TRAINING" and DUMMY_MODES[match.dummyMode].block == true
			end
		end
		if world.ultimateConditions and not isSolo(match) then world.ultimateConditions = nil end -- (solo only)
		local events = Sim.step(world, inputs)
		for _, event in events do
			event.tick = world.tick
			table.insert(batch, event)
		end
		followEvents(match, events)
		if match.closed then return end
		for _, slot in match.slots do
			local input = slot.input
			input.jump, input.dash, input.light, input.heavy, input.special, input.ultimate = false, false, false, false, false, false
			input.fatal = false
			input.stance = 0
		end
	end
	-- Rigs are drawn by each client from snapshots; the server only keeps them near the action.
	if #batch > 0 then
		for _, player in recipients(match) do
			eventsRemote:FireClient(player, batch)
		end
	end
	-- (a snapshot with the events, but never more than one every 2 ticks: 30 / s at most per
	-- player, the events themselves leave right away above; a full server stays light)
	local since = world.tick - match.lastSnapshot
	if since < 0 then since = math.huge end -- (a new world restarts its ticks)
	if (#batch > 0 and since >= 2) or since >= Config.TickRate / Config.SnapshotRate then
		match.lastSnapshot = world.tick
		for i, slot in match.slots do place(slot, world.fighters[i]) end
		snapshot(match)
	end
end

RunService.Heartbeat:Connect(function(dt)
	for _, match in matches do
		if not match.closed then stepMatch(match, dt) end
	end
end)
print("[FightingGame] " .. Config.Version .. " ready — menus, many matches per server, opponent search, server-authoritative combat")

-- SHOP · ROBUX (prepared, off): a shop style sold for Robux needs a developer product created by
-- Wilhem on Roblox, its id in CharacterData.SHOP_PRODUCTS[name]. While that table is empty
-- (now: no id is ever invented) nothing is connected and the shop sells for coins only.
if next(CharacterData.SHOP_PRODUCTS) then
	local MarketplaceService = game:GetService("MarketplaceService")
	local byProduct = {}
	for name, product in CharacterData.SHOP_PRODUCTS do byProduct[product] = name end
	MarketplaceService.ProcessReceipt = function(receipt)
		local name = byProduct[receipt.ProductId]
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		local client = player and clients[player]
		-- (granted only once the purchase is really written in the saved profile; else Roblox
		-- calls again later)
		if not name or not client or not client.profile or (store and not SaveQueue.isLoaded(saves, player.UserId)) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if type(client.profile.ownedSkins) ~= "table" then client.profile.ownedSkins = {} end
		client.profile.ownedSkins[name] = true
		if store and not writeProfile(player, client) then return Enum.ProductPurchaseDecision.NotProcessedYet end
		menuStatus(player, name)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

-- The server closing (update, shutdown): every loaded profile is written before it goes
-- (Roblox waits up to 30 s for this).
game:BindToClose(function()
	if not store then return end
	local pending = 0
	for player, client in clients do
		if client.profile and SaveQueue.isLoaded(saves, player.UserId) then
			pending += 1
			task.spawn(function()
				writeProfile(player, client, true)
				pending -= 1
			end)
		end
	end
	local started = os.clock()
	while pending > 0 and os.clock() - started < 25 do task.wait(0.2) end
end)
