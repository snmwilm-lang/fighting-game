local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.CombatConfig)
local MoveData = require(Shared.MoveData)
local CharacterData = require(Shared.CharacterData)
local Sim = require(Shared.CombatSimulation)
local FighterAI = require(Shared.FighterAI)
local ArenaBuilder = require(script.ArenaBuilder)
local RigBuilder = require(script.RigBuilder)

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
	slots[i] = { model = RigBuilder.build(i, fightersFolder), owner = nil, input = Sim.neutralInput(), lastInput = 0 }
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
	slot.model = model
	if owner then owner.Character = model end
	watchRig(i)
	place(slot, world.fighters[i])
end

-- Rebuilds a slot's rig: the owner's Roblox avatar (R15) when they chose it, KAI otherwise.
-- An empty slot (CPU / dummy) becomes a shadow clone of the other player's avatar.
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
				local model = RigBuilder.buildShadow(i, other) -- yields while loading
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
			-- Own avatar + kit; a default R15 body + kit if the avatar cannot load (see RigBuilder).
			local model, status = RigBuilder.buildAvatar(i, owner) -- yields while loading
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

local function assign(player)
	for i, slot in slots do
		if not slot.owner then
			slot.owner = player
			clients[player].slot = i
			player:SetAttribute("FighterSlot", i)
			local previousCharacter = player.Character
			if previousCharacter and previousCharacter ~= slot.model then previousCharacter:Destroy() end
			player.Character = slot.model
			resetAll()
			-- Roblox avatars by default: the player's own R15, the empty slot its shadow.
			if clients[player].avatar then
				rebuildSlot(i)
				if not slots[3 - i].owner then rebuildSlot(3 - i) end
			end
			return
		end
	end
	if player.Character then player.Character:Destroy(); player.Character = nil end
	player:SetAttribute("FighterSlot", 0)
end

local function joined(player)
	if clients[player] then return end
	clients[player] = {
		tokens = 60, lastPacket = os.clock(), lastReset = -math.huge, lastDummy = -math.huge,
		lastAvatar = -math.huge, lastSeq = 0, avatar = true,
	}
	player:SetAttribute("Avatar", true)
	assign(player)
end
Players.PlayerAdded:Connect(joined)
Players.PlayerRemoving:Connect(function(player)
	local client = clients[player]
	if client and client.slot then
		local slot = slots[client.slot]
		player.Character = nil
		slot.owner = nil
		clients[player] = nil
		rebuildSlot(client.slot) -- the freed slot becomes the CPU / dummy again
		resetAll()
	end
	clients[player] = nil
	for _, spectator in Players:GetPlayers() do
		if spectator ~= player and clients[spectator] and not clients[spectator].slot then assign(spectator) end
	end
end)
for _, player in Players:GetPlayers() do joined(player) end
resetAll()

local function finite(n)
	return typeof(n) == "number" and n == n and math.abs(n) < math.huge
end
local BOOLEAN_FIELDS = {
	"crouch", "block", "jump", "dash", "light", "heavy", "special", "ultimate", "reset", "dummy", "avatar", "skin",
}
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
		client.lastAvatar = now
		client.avatar = not client.avatar
		player:SetAttribute("Avatar", client.avatar)
		rebuildSlot(client.slot)
		if not slots[3 - client.slot].owner then rebuildSlot(3 - client.slot) end
	end
	local input = slot.input
	input.axis, input.crouch, input.block = packet.axis, packet.crouch, packet.block
	-- Pulses stay set until the next simulation tick consumes them.
	input.jump = input.jump or packet.jump
	input.dash = input.dash or packet.dash
	input.light = input.light or packet.light
	input.heavy = input.heavy or packet.heavy
	input.special = input.special or packet.special
	input.ultimate = input.ultimate or packet.ultimate
	slot.lastInput = now
end)

local function snapshot()
	local list = {}
	for i, slot in slots do
		local f = world.fighters[i]
		local character = CharacterData[i]
		list[i] = {
			x = f.x, y = f.y, vx = f.vx + f.pushVx, vy = f.vy, facing = f.facing, state = f.state,
			move = f.move or "", moveFrame = f.moveFrame, hitstop = f.hitstop,
			hp = f.hp, guard = f.guard, meter = f.meter, combo = f.comboHits, comboDamage = f.comboDamage, wins = f.wins,
			crouching = f.crouching,
			chainKeys = f.chainKeys, chainClean = f.chainClean, cancelReady = Sim.cancelReady(world, f),
			owner = if slot.owner then slot.owner.UserId else 0,
			player = if slot.owner then slot.owner.DisplayName else "MANNEQUIN · " .. DUMMY_MODES[dummyMode].name,
			character = character.Name, skin = character.Skin, kit = character.Kit,
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
			prompts = world.cinematic.prompts,
		},
		winner = world.winner or -1, matchWinner = world.matchWinner or -1,
		fighters = list,
	})
end

-- Training lab (solo only): play a cinematic directly to check its staging.
local DEBUG_MOVES = { KaienRush = true, Awakening = true, Kaiten = true }
local DEBUG_STYLES = {}
for _, route in MoveData.FullRoutes do DEBUG_STYLES[route.name] = true end
local pendingDebugEvents = {}
debugRemote.OnServerEvent:Connect(function(player, moveId, style, finish)
	local client = clients[player]
	if not client or not client.slot or not isSolo() then return end
	if typeof(moveId) ~= "string" or not DEBUG_MOVES[moveId] then return end
	if style ~= nil and (typeof(style) ~= "string" or not DEBUG_STYLES[style]) then return end
	if typeof(finish) ~= "boolean" then return end
	local now = os.clock()
	if now - (client.lastDebug or -math.huge) < 1 or world.cinematic then return end
	client.lastDebug = now
	if moveId == "Awakening" then style = style or "TORNADE" else style = nil end
	local events = Sim.debugCinematic(world, client.slot, moveId, style, if finish then 300 else nil)
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
				if os.clock() - slot.lastInput > Config.InputTimeout then slot.input = Sim.neutralInput() end
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
