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
	return { rating = Matchmaker.START_RATING, wins = 0, losses = 0, survivalBest = 0, hero = "KAI",
		asuraGrade = 0, asuraDamage = 0, title = "", -- CHALLENGE: best grade, best damage share, title
		language = "AUTO" } -- SETTINGS › LANGUAGE: AUTO (Roblox's translation), EN or FR
end
local function loadProfile(player, client)
	client.profile = defaultProfile()
	if not store then return end
	task.spawn(function()
		local ok, data = pcall(store.GetAsync, store, "joueur_" .. player.UserId)
		if ok and type(data) == "table" and clients[player] == client then
			for k, v in defaultProfile() do
				if type(data[k]) == type(v) then client.profile[k] = data[k] end
			end
			if not MoveData.Kits[client.profile.hero] then client.profile.hero = "KAI" end
			client.onProfileLoaded()
		end
		client.profileLoaded = true
	end)
end
-- The ranking (CLASSEMENT): an ordered store of the ratings, read 10 at a time.
local board = nil
do
	local ok, result = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, "JeuxCombat_Classement_v1")
	if ok then board = result end
end
local function saveProfile(player, client)
	if not store or not client.profile then return end
	local data = table.clone(client.profile)
	task.spawn(function()
		pcall(store.SetAsync, store, "joueur_" .. player.UserId, data)
		if board then pcall(board.SetAsync, board, tostring(player.UserId), math.floor(data.rating)) end
	end)
end
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
			match.characters[i] = CharacterData.Skins[CharacterData.defaultStyle(kit, other and other.Skin)]
			if match.slots[i].model then rebuildSlot(match, i) end
		end
	end
end

local menuStatus -- (defined below)

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
		endVersus(match, 3 - i)
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
	elseif mode == "CHALLENGE" then
		-- ASURA, the four-armed boss, against a team of 1 to 3.
		match.level = "ASURA"
		Sim.setTeams(world, request.team, { "ASURA" })
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
	local teamA = clients[playerA].team or { "KAI" }
	local teamB = clients[playerB].team or { "KAI" }
	-- Same team size on both sides (the smaller one).
	local size = math.min(#teamA, #teamB)
	Sim.setLineup(match.world, table.move(teamA, 1, size, 1, {}), table.move(teamB, 1, size, 1, {}))
	launch(match)
end

-- End of a 1v1 between players: ratings (CLASSÉ), wins / losses, result to both.
function endVersus(match, winnerSlot)
	if match.finished then return end
	match.finished = true
	local a, b = match.slots[1].owner, match.slots[2].owner
	local ca, cb = a and clients[a], b and clients[b]
	if not (ca and cb) then return end
	local scoreA = if winnerSlot == 1 then 1 elseif winnerSlot == 2 then 0 else 0.5
	if winnerSlot == 1 then ca.profile.wins += 1; cb.profile.losses += 1
	elseif winnerSlot == 2 then cb.profile.wins += 1; ca.profile.losses += 1 end
	local before = { ca.profile.rating, cb.profile.rating }
	if match.queue == "RANKED" then
		ca.profile.rating, cb.profile.rating = Matchmaker.elo(ca.profile.rating, cb.profile.rating, scoreA)
	end
	for i, player in { a, b } do
		local client = clients[player]
		saveProfile(player, client)
		menuRemote:FireClient(player, {
			result = true, queue = match.queue, won = winnerSlot == i, draw = winnerSlot == 0,
			rating = client.profile.rating, delta = client.profile.rating - before[i],
			rank = Matchmaker.rankName(client.profile.rating),
		})
	end
end

-- What the menu of a player shows: where they are, their rank, the queues.
function menuStatus(player)
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
		wins = profile.wins, losses = profile.losses, survivalBest = profile.survivalBest,
		asuraGrade = profile.asuraGrade, asuraDamage = profile.asuraDamage, title = profile.title,
		waiting = { NORMAL = Matchmaker.waitingIn(matchmaker, "NORMAL"), RANKED = Matchmaker.waitingIn(matchmaker, "RANKED") },
		online = #Players:GetPlayers(), matches = (function()
			local n = 0
			for _ in matches do n += 1 end
			return n
		end)(),
	})
end

-- ===================================================================== hub (friends)
local function hubStatus()
	local list = Lobby.status(lobby)
	for _, entry in list do
		local player = Players:GetPlayerByUserId(entry.id)
		local client = player and clients[player]
		entry.slot = if client and client.match then client.slot else 0
		entry.where = if not client then "?"
			elseif client.match then (if client.match.mode == "VERSUS" then "IN A FIGHT" elseif client.match.mode == "TRAINING" then "TRAINING"
				elseif client.match.mode == "CHALLENGE" then "VS ASURA" else "VS THE CPU")
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
		table.insert(parts, table.concat({ e.id, e.where, tostring(e.sent), table.concat(e.from, ",") }, ":"))
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
	local look = CharacterData.Skins[CharacterData.defaultStyle(kit, nil)]
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

local function joined(player)
	if clients[player] then return end
	local client = {
		tokens = 60, lastPacket = os.clock(), lastReset = -math.huge, lastDummy = -math.huge,
		lastAvatar = -math.huge, lastSeq = 0, avatar = false, rig = nil, lastHub = -math.huge, lastMenu = -math.huge,
		team = { "KAI" },
	}
	clients[player] = client
	client.onProfileLoaded = function()
		buildHero(player)
		menuStatus(player)
	end
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
	local client = clients[player]
	if client then
		Matchmaker.leave(matchmaker, player.UserId)
		unseat(player)
		saveProfile(player, client)
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
	if not client or typeof(action) ~= "string" or not HUB_ACTIONS[action] then return end
	if target ~= nil and (typeof(target) ~= "number" or target % 1 ~= 0) then return end
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
menuRemote.OnServerEvent:Connect(function(player, packet)
	local client = clients[player]
	if not client or typeof(packet) ~= "table" or typeof(packet.action) ~= "string" then return end
	local now = os.clock()
	if now - client.lastMenu < 0.5 then return end
	client.lastMenu = now
	local action = packet.action
	if action == "hello" then
		menuStatus(player)
	elseif action == "hero" then
		-- PERSONNAGES / MES PERSONNAGES: the favourite fighter (also the lobby's hero).
		if typeof(packet.kit) == "string" and MoveData.Kits[packet.kit] and client.profile then
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
	elseif action == "team" then
		-- The team chosen for a friend's challenge (DÉFIER AMI), without joining a queue.
		local request = GameModes.validate({ mode = "VERSUS_CPU", team = packet.team, level = 1 }, MoveData.KitOrder)
		if request then client.team = request.team end
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
		Matchmaker.leave(matchmaker, player.UserId)
		client.queue = nil
		unseat(player)
		client.team = request.team
		if request.mode == "VERSUS" then
			client.queue = request.queue
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
	if client.tokens < 1 then return end
	client.tokens -= 1
	local match = client.match
	if typeof(packet) ~= "table" or not match then return end
	if not finite(packet.seq) or packet.seq % 1 ~= 0 or packet.seq <= client.lastSeq or packet.seq > 1e9 then return end
	if not finite(packet.axis) or math.abs(packet.axis) > 1 then return end
	for _, field in BOOLEAN_FIELDS do
		if typeof(packet[field]) ~= "boolean" then return end
	end
	if not PressQueue.valid(packet.presses) then return end
	local stance = packet.stance
	if stance ~= nil and (not finite(stance) or stance % 1 ~= 0 or stance < 0 or stance > 2) then return end
	-- The cinematic tick the player saw (QTE lag compensation, bounded by the simulation).
	local cinTick = packet.cinTick
	if cinTick ~= nil and (not finite(cinTick) or cinTick < 0 or cinTick > 10000) then return end
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
		-- (Styles to earn, like KAI's ÉVEILLÉ, are skipped until won: CHALLENGE ASURA.)
		local name = match.characters[mine].Skin
		for _ = 1, 8 do
			name = CharacterData.nextSkin(name, match.characters[other].Skin)
			if not CharacterData.LOCKED[name] or (client.profile and client.profile.asuraGrade >= 1) then break end
		end
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
			elseif match.mode == "CHALLENGE" then "ASURA · BOSS"
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
	local match = client and client.match
	if not match or match.mode ~= "TRAINING" or not isSolo(match) then return end
	if typeof(kind) ~= "string" or not DEBUG_TYPES[kind] then return end
	if typeof(finish) ~= "boolean" then return end
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
			if match.mode == "SURVIVAL" and owner and clients[owner] then
				local client = clients[owner]
				local beaten = match.wave - 1
				if beaten > client.profile.survivalBest then
					client.profile.survivalBest = beaten
					saveProfile(owner, client)
				end
				menuRemote:FireClient(owner, { result = true, survival = beaten, best = client.profile.survivalBest })
			elseif match.mode == "VERSUS" then
				endVersus(match, event.winner)
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
				if newBest then
					profile.asuraGrade = grade
					profile.title = title or profile.title
				end
				saveProfile(owner, client)
				menuRemote:FireClient(owner, { result = true, challenge = true, won = won, grade = grade, title = title,
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
	if #batch > 0 or world.tick - match.lastSnapshot >= Config.TickRate / Config.SnapshotRate then
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
