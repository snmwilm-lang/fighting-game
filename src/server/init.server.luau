local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.CombatConfig)
local MoveData = require(Shared.MoveData)
local CharacterData = require(Shared.CharacterData)
local Sim = require(Shared.CombatSimulation)
local FighterAI = require(Shared.FighterAI)
local PressQueue = require(Shared.PressQueue)
local RigReader = require(Shared.RigReader)
local ArenaBuilder = require(script.ArenaBuilder)
local RigBuilder = require(script.RigBuilder)
local Lobby = require(script.Lobby)

Players.CharacterAutoLoads = false
ArenaBuilder.build()
local fightersFolder = Instance.new("Folder")
fightersFolder.Name, fightersFolder.Parent = "Fighters", workspace
local remotes = Instance.new("Folder")
remotes.Name = "FightingRemotes"
local inputRemote = Instance.new("RemoteEvent")
inputRemote.Name, inputRemote.Parent = "Input", remotes
local snapshotRemote = Instance.new("RemoteEvent")
snapshotRemote.Name, snapshotRemote.Parent = "Snapshot", remotes
local eventsRemote = Instance.new("RemoteEvent")
eventsRemote.Name, eventsRemote.Parent = "Events", remotes
local debugRemote = Instance.new("RemoteEvent")
debugRemote.Name, debugRemote.Parent = "Debug", remotes
-- Hub (lobby): client -> server (action, target user id), server -> clients (hub status).
local hubRemote = Instance.new("RemoteEvent")
hubRemote.Name, hubRemote.Parent = "Hub", remotes
-- Parent last so clients see the folder with every remote already inside.
remotes.Parent = ReplicatedStorage

local slots, clients = {}, {}
local generation = 0
-- Training dummy modes, cycled from the HUD (MANNEQUIN) or the M key.
local DUMMY_MODES = { { name = "IMMOBILE" }, { name = "GARDE", block = true } }
for level, data in FighterAI.Levels do
	table.insert(DUMMY_MODES, { name = "CPU " .. data.name, level = level })
end
local dummyMode = 1
local brain = nil
for i = 1, 2 do
	slots[i] = {
		model = RigBuilder.build(i, fightersFolder), owner = nil, input = Sim.neutralInput(), lastInput = 0,
		presses = PressQueue.new(), -- attack presses in their order, one per simulation tick
	}
end
local world = Sim.newWorld(Config, MoveData, true)

local function isSolo()
	return not (slots[1].owner and slots[2].owner)
end

-- Versus rules (rounds, timer) between two players or against the CPU; training otherwise.
local function isTraining()
	return isSolo() and not DUMMY_MODES[dummyMode].level
end

local function place(slot, fighter)
	local pos = Vector3.new(fighter.x, fighter.y + Config.RootHeight, Config.PlaneZ)
	slot.model.HumanoidRootPart.CFrame = CFrame.lookAt(pos, pos + Vector3.new(fighter.facing, 0, 0))
end

-- New match: health, guard, states, buffers, wins and inputs are all cleared.
local function resetAll()
	generation += 1
	Sim.resetMatch(world, isTraining())
	local level = DUMMY_MODES[dummyMode].level
	brain = if level and isSolo() then FighterAI.new(level, math.floor(os.clock() * 1000) + generation) else nil
	for i, slot in slots do
		slot.input = Sim.neutralInput()
		PressQueue.clear(slot.presses)
		place(slot, world.fighters[i])
	end
end

local function watchRig(i)
	local slot = slots[i]
	local model = slot.model
	model.Humanoid.Died:Connect(function()
		-- Health is owned by the simulation; a Humanoid death only happens if something
		-- external kills the rig, so rebuild it rather than leave a broken character.
		task.defer(function()
			if slot.model ~= model then return end
			if slot.owner then slot.owner.Character = nil end
			model:Destroy()
			slot.model = RigBuilder.build(i, fightersFolder)
			if slot.owner then slot.owner.Character = slot.model end
			watchRig(i)
			resetAll()
		end)
	end)
end
for i = 1, 2 do watchRig(i) end

local function swapModel(i, model)
	local slot = slots[i]
	local owner = slot.owner
	if owner then owner.Character = nil end
	slot.model:Destroy()
	model.Parent = fightersFolder
	-- Once in the world, check the joints again (a Humanoid may rebuild its own).
	local rebuilt = RigReader.ensureJoints(model)
	if rebuilt > 0 then print("[FightingGame] " .. model.Name .. " : " .. rebuilt .. " articulations reconstruites après placement") end
	slot.model = model
	if owner then owner.Character = model end
	watchRig(i)
	place(slot, world.fighters[i])
end

-- The avatar body type of a player: the one they picked in APPARENCE, else the one of their
-- Roblox account (read once, may yield).
local function rigOf(player, client)
	if not client.rig then
		client.rig = RigBuilder.preferredRig(player)
		player:SetAttribute("AvatarRig", client.rig)
	end
	return client.rig
end

-- Rebuilds a slot's rig: the owner's Roblox avatar (R15 or R6) wearing the kit when they
-- chose it, the block model otherwise. An empty slot (CPU / dummy) becomes a shadow clone of
-- the other player's avatar, with the same body type.
local function rebuildSlot(i)
	local slot = slots[i]
	local owner = slot.owner
	local client = owner and clients[owner]
	if not owner then
		local other = slots[3 - i].owner
		local otherClient = other and clients[other]
		if otherClient and otherClient.avatar then
			slot.building = (slot.building or 0) + 1
			local ticket = slot.building
			task.spawn(function()
				local ok, model = pcall(RigBuilder.buildShadow, i, other, rigOf(other, otherClient)) -- yields while loading
				if not ok then
					warn("[FightingGame] Clone d'ombre impossible : " .. tostring(model))
					model = nil
				end
				if slot.owner or slot.building ~= ticket then
					if model then model:Destroy() end
					return
				end
				swapModel(i, model or RigBuilder.build(i, nil))
			end)
		else
			swapModel(i, RigBuilder.build(i, nil))
		end
		return
	end
	if client and client.avatar then
		slot.building = (slot.building or 0) + 1
		local ticket = slot.building
		owner:SetAttribute("AvatarStatus", "CHARGEMENT")
		task.spawn(function()
			-- Own avatar + kit; a default body + kit if the avatar cannot load (see RigBuilder).
			local ok, model, status = pcall(RigBuilder.buildAvatar, i, owner, rigOf(owner, client)) -- yields while loading
			if not ok then
				-- A Roblox error while building: say it on screen instead of loading forever.
				warn("[FightingGame] Avatar impossible : " .. tostring(model))
				model, status = nil, "MODÈLE|" .. tostring(model):sub(1, 90)
			end
			if slot.owner ~= owner or not client.avatar or slot.building ~= ticket then
				if model then model:Destroy() end
				return
			end
			if not model then
				client.avatar = false
				owner:SetAttribute("Avatar", false)
				model = RigBuilder.build(i, nil)
			end
			owner:SetAttribute("AvatarStatus", status)
			swapModel(i, model)
		end)
	else
		slot.building = (slot.building or 0) + 1
		swapModel(i, RigBuilder.build(i, nil))
	end
end

-- Hub (see Lobby): who fights in slots 1 and 2 is the lobby's decision; this applies it to
-- the slots and rigs, then tells every client.
local lobby = Lobby.new()

local function broadcastHub()
	hubRemote:FireAllClients({ players = Lobby.status(lobby), seconds = Lobby.CHALLENGE_SECONDS })
end

local function sync()
	local changed = false
	-- Leave the slots first (a player may move from one slot to the other).
	for i, slot in slots do
		local want = lobby.slots[i] and Players:GetPlayerByUserId(lobby.slots[i])
		local owner = slot.owner
		if owner and owner ~= want then
			slot.owner = nil
			if clients[owner] then clients[owner].slot = nil end
			owner:SetAttribute("FighterSlot", 0)
			if owner.Character == slot.model then owner.Character = nil end
			changed = true
		end
	end
	for i, slot in slots do
		local want = lobby.slots[i] and Players:GetPlayerByUserId(lobby.slots[i])
		if want and clients[want] and slot.owner ~= want then
			slot.owner = want
			clients[want].slot = i
			want:SetAttribute("FighterSlot", i)
			local previous = want.Character
			if previous and previous ~= slots[1].model and previous ~= slots[2].model then previous:Destroy() end
			want.Character = slot.model
			changed = true
		end
	end
	for _, player in Players:GetPlayers() do
		local client = clients[player]
		if client and not client.slot then
			if player:GetAttribute("FighterSlot") ~= 0 then player:SetAttribute("FighterSlot", 0) end
			if player.Character and player.Character ~= slots[1].model and player.Character ~= slots[2].model then
				player.Character:Destroy()
				player.Character = nil
			end
		end
	end
	if changed then
		-- Own avatars on the players' slots, the CPU's shadow clone / block on an empty one.
		for i = 1, 2 do rebuildSlot(i) end
		resetAll()
	end
	broadcastHub()
end

local function joined(player)
	if clients[player] then return end
	clients[player] = {
		tokens = 60, lastPacket = os.clock(), lastReset = -math.huge, lastDummy = -math.huge,
		lastAvatar = -math.huge, lastSeq = 0, avatar = true, rig = nil, lastHub = -math.huge,
	}
	player:SetAttribute("Avatar", true)
	player:SetAttribute("FighterSlot", 0)
	Lobby.join(lobby, player.UserId, player.DisplayName)
	sync()
end
Players.PlayerAdded:Connect(joined)
Players.PlayerRemoving:Connect(function(player)
	-- The lobby frees the slot (the CPU / dummy takes it, or a player waiting in the hub).
	Lobby.leave(lobby, player.UserId)
	sync()
	clients[player] = nil
end)

-- DÉFIER, ACCEPTER, REFUSER, QUITTER LE COMBAT, JOUER (see Lobby for the rules).
local HUB_ACTIONS = { challenge = true, accept = true, decline = true, quit = true, play = true, hello = true }
hubRemote.OnServerEvent:Connect(function(player, action, target)
	local client = clients[player]
	if not client or typeof(action) ~= "string" or not HUB_ACTIONS[action] then return end
	if target ~= nil and (typeof(target) ~= "number" or target % 1 ~= 0) then return end
	local now = os.clock()
	if now - client.lastHub < 0.4 then return end
	client.lastHub = now
	local id = player.UserId
	if action == "hello" then
		-- A client that just started asks for the hub status.
		hubRemote:FireClient(player, { players = Lobby.status(lobby), seconds = Lobby.CHALLENGE_SECONDS })
		return
	end
	local ok
	if action == "challenge" then ok = target ~= nil and Lobby.challenge(lobby, id, target, now)
	elseif action == "accept" then ok = target ~= nil and Lobby.accept(lobby, id, target, now)
	elseif action == "decline" then ok = target ~= nil and Lobby.decline(lobby, id, target)
	elseif action == "quit" then ok = Lobby.quit(lobby, id)
	else ok = Lobby.play(lobby, id) end
	if ok then sync() end
end)
-- Network latency of each fighting player, once a second: the simulation compensates far
-- players a little (late links, QTE), within CombatConfig.MaxLatencyTicks.
task.spawn(function()
	while true do
		task.wait(1)
		for i, slot in slots do
			local owner, ping = slot.owner, nil
			if owner then
				local ok, value = pcall(owner.GetNetworkPing, owner) -- round trip, in seconds
				if ok and typeof(value) == "number" and value == value then ping = math.clamp(value, 0, 2) end
			end
			slot.ping = ping
			local f = world.fighters[i]
			if f then
				f.latencyTicks = if ping then math.clamp(math.floor(ping / 2 * Config.TickRate + 0.5), 0, Config.MaxLatencyTicks) else 0
			end
		end
	end
end)
-- Challenges time out (CHALLENGE_SECONDS).
task.spawn(function()
	while true do
		task.wait(1)
		local before = next(lobby.challenges) ~= nil
		Lobby.expire(lobby, os.clock())
		if before and next(lobby.challenges) == nil then broadcastHub() end
	end
end)
for _, player in Players:GetPlayers() do joined(player) end
resetAll()

local function finite(n)
	return typeof(n) == "number" and n == n and math.abs(n) < math.huge
end
local BOOLEAN_FIELDS = {
	"crouch", "block", "jump", "dash", "reset", "dummy", "avatar", "skin", "kit", "foeKit",
}

-- Kits (MoveData.Kits): a pick gives the slot the kit's first style that differs from the
-- other slot's, then starts a fresh match with the kits' stats.
local function nextKit(kit)
	local order = MoveData.KitOrder
	return order[(table.find(order, kit) or 0) % #order + 1]
end
local function pickKit(i, kit)
	CharacterData[i] = CharacterData.Skins[CharacterData.defaultStyle(kit, CharacterData[3 - i].Skin)]
	Sim.setKits(world, CharacterData[1].Kit, CharacterData[2].Kit)
	rebuildSlot(i)
end
-- Solo: any time. Versus: only before the first hit of the match or once it is over, so a
-- pick never wipes a fight in progress.
local function canPickKit()
	if isSolo() or world.phase == "MatchEnd" then return true end
	if world.round ~= 1 then return false end
	for _, f in world.fighters do
		if f.hp < f.maxHp or f.wins > 0 then return false end
	end
	return true
end
inputRemote.OnServerEvent:Connect(function(player, packet)
	local client = clients[player]
	if not client then return end
	local now = os.clock()
	client.tokens = math.min(60, client.tokens + (now - client.lastPacket) * 60)
	client.lastPacket = now
	if client.tokens < 1 then return end
	client.tokens -= 1
	if typeof(packet) ~= "table" or not client.slot then return end
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
	local slot = slots[client.slot]
	if slot.owner ~= player then return end
	local solo = not slots[3 - client.slot].owner
	if packet.reset and solo and now - client.lastReset > 1 then
		client.lastReset = now
		resetAll()
	end
	if packet.dummy and solo and now - client.lastDummy > 0.3 then
		client.lastDummy = now
		dummyMode = dummyMode % #DUMMY_MODES + 1
		resetAll()
	end
	if packet.kit and now - (client.lastKit or -math.huge) > 0.5 and canPickKit() then
		client.lastKit = now
		pickKit(client.slot, nextKit(CharacterData[client.slot].Kit))
		resetAll()
	end
	if packet.foeKit and solo and now - (client.lastKit or -math.huge) > 0.5 then
		-- The CPU / dummy's kit (solo only).
		client.lastKit = now
		local other = 3 - client.slot
		pickKit(other, nextKit(CharacterData[other].Kit))
		resetAll()
	end
	if packet.skin and now - (client.lastSkin or -math.huge) > 1 then
		-- Next colour style of the kit; the CPU slot takes another one.
		client.lastSkin = now
		local mine, other = client.slot, 3 - client.slot
		CharacterData[mine] = CharacterData.Skins[CharacterData.nextSkin(CharacterData[mine].Skin, CharacterData[other].Skin)]
		rebuildSlot(mine)
		if not slots[other].owner then
			CharacterData[other] = CharacterData.Skins[CharacterData.nextSkin(CharacterData[other].Skin, CharacterData[mine].Skin)]
			rebuildSlot(other)
		end
	end
	if packet.avatar and now - client.lastAvatar > 2 then
		-- APPARENCE: avatar R15 -> avatar R6 -> block model -> avatar R15...
		client.lastAvatar = now
		if not client.avatar then
			client.avatar, client.rig = true, "R15"
		elseif client.rig ~= "R6" then
			client.rig = "R6"
		else
			client.avatar = false
		end
		player:SetAttribute("Avatar", client.avatar)
		player:SetAttribute("AvatarRig", client.rig)
		rebuildSlot(client.slot)
		if not slots[3 - client.slot].owner then rebuildSlot(3 - client.slot) end
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

-- Fields that rarely change (names, looks, kit) go out only when they change, or every two
-- seconds for a client that just arrived: snapshots stay small for far players.
local lastRoster, lastRosterAt = nil, -math.huge
local function roster()
	local list = {}
	for i, slot in slots do
		local character = CharacterData[i]
		list[i] = {
			owner = if slot.owner then slot.owner.UserId else 0,
			player = if slot.owner then slot.owner.DisplayName else "MANNEQUIN · " .. DUMMY_MODES[dummyMode].name,
			character = character.Name, skin = character.Skin, kit = world.fighters[i].kit, maxHp = world.fighters[i].maxHp,
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

local function snapshot()
	local list = {}
	local names = roster()
	local key = rosterKey(names)
	local now = os.clock()
	local sendRoster = key ~= lastRoster or now - lastRosterAt > 2
	if sendRoster then lastRoster, lastRosterAt = key, now end
	for i, slot in slots do
		local f = world.fighters[i]
		list[i] = {
			x = f.x, y = f.y, vx = f.vx + f.pushVx, vy = f.vy, facing = f.facing, state = f.state,
			move = f.move or "", moveFrame = f.moveFrame, hitstop = f.hitstop,
			hp = f.hp, guard = f.guard, meter = f.meter, combo = f.comboHits, comboDamage = f.comboDamage, wins = f.wins,
			crouching = f.crouching, maxHp = f.maxHp, passive = Sim.passiveGauge(world, f), weave = f.weaveTicks > 0,
			stance = f.stance, -- TARO: "CLASSIQUE" / "ESQUIVE"
			chainKeys = f.chainKeys, chainClean = f.chainClean, cancelReady = Sim.cancelReady(world, f),
			dirtyReason = f.dirtyReason or "",
			kit = f.kit, ping = slot.ping and math.floor(slot.ping * 1000 + 0.5) or nil,
		}
	end
	local projectiles = {}
	for _, p in world.projectiles do
		table.insert(projectiles, { id = p.id, x = p.x, y = p.y, vx = p.vx, owner = p.owner })
	end
	snapshotRemote:FireAllClients({
		projectiles = projectiles,
		tick = world.tick, generation = generation, epoch = world.epoch,
		phase = world.phase, phaseTicks = world.phaseTicks, round = world.round,
		timer = Sim.timerSeconds(world), training = world.training, solo = isSolo(),
		dummyMode = DUMMY_MODES[dummyMode].name,
		cinematic = world.cinematic and {
			attacker = world.cinematic.attacker, defender = world.cinematic.defender,
			tick = world.cinematic.tick, length = world.cinematic.length,
			move = world.cinematic.move, finish = world.cinematic.finish, style = world.cinematic.style,
			nextPrompt = world.cinematic.nextPrompt, grade = world.cinematic.grade,
			prompts = world.cinematic.prompts, scale = Sim.cinematicScale(world),
		},
		winner = world.winner or -1, matchWinner = world.matchWinner or -1,
		fighters = list, roster = if sendRoster then names else nil,
	})
end

-- Training lab (solo only): play one of the player's kit's cinematics directly to check its
-- staging. `kind` is the cinematic type, `style` (ÉVEIL only) a full route of the kit.
local DEBUG_TYPES = { Rush = true, Awaken = true, Gate = true }
local pendingDebugEvents = {}
debugRemote.OnServerEvent:Connect(function(player, kind, style, finish)
	local client = clients[player]
	if not client or not client.slot or not isSolo() then return end
	if typeof(kind) ~= "string" or not DEBUG_TYPES[kind] then return end
	if typeof(finish) ~= "boolean" then return end
	local kit = Sim.kitOf(world, world.fighters[client.slot])
	local known = false
	for _, route in kit.FullRoutes do known = known or route.name == style end
	if style ~= nil and (typeof(style) ~= "string" or not known) then return end
	local now = os.clock()
	if now - (client.lastDebug or -math.huge) < 1 or world.cinematic then return end
	client.lastDebug = now
	if kind == "Awaken" then style = style or kit.FullRoutes[1].name else style = nil end
	local events = Sim.debugCinematic(world, client.slot, kind, style, if finish then 300 else nil)
	for _, event in events do table.insert(pendingDebugEvents, event) end
end)

local accumulator, lastSnapshot = 0, 0
RunService.Heartbeat:Connect(function(dt)
	accumulator = math.min(accumulator + dt, Config.MaxCatchUpSteps / Config.TickRate)
	local batch = pendingDebugEvents
	pendingDebugEvents = {}
	while accumulator >= 1 / Config.TickRate do
		accumulator -= 1 / Config.TickRate
		local inputs = {}
		for i, slot in slots do
			if slot.owner then
				if os.clock() - slot.lastInput > Config.InputTimeout then
					slot.input = Sim.neutralInput()
					PressQueue.clear(slot.presses)
				end
				PressQueue.pop(slot.presses, slot.input)
				inputs[i] = slot.input
			elseif brain then
				inputs[i] = brain:think(world, i)
			else
				inputs[i] = Sim.neutralInput()
				inputs[i].block = DUMMY_MODES[dummyMode].block == true
			end
		end
		for _, event in Sim.step(world, inputs) do
			event.tick = world.tick
			table.insert(batch, event)
		end
		for _, slot in slots do
			local input = slot.input
			input.jump, input.dash, input.light, input.heavy, input.special, input.ultimate = false, false, false, false, false, false
			input.stance = 0
		end
	end
	-- Rigs are drawn by each client from snapshots; the server only keeps them near the action.
	if #batch > 0 then
		eventsRemote:FireAllClients(batch)
	end
	if #batch > 0 or world.tick - lastSnapshot >= Config.TickRate / Config.SnapshotRate then
		lastSnapshot = world.tick
		for i, slot in slots do place(slot, world.fighters[i]) end
		snapshot()
	end
end)
print("[FightingGame] " .. Config.Version .. " ready — server-authoritative combat, ki meter, ultimate, CPU (classic remotes, no prediction)")
