local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.CombatConfig)
local Movement = require(Shared.Movement)
local ArenaBuilder = require(script.ArenaBuilder)
local RigBuilder = require(script.RigBuilder)

Players.CharacterAutoLoads = false
ArenaBuilder.build()
local fightersFolder = Instance.new("Folder")
fightersFolder.Name, fightersFolder.Parent = "Fighters", workspace
local remotes = Instance.new("Folder")
remotes.Name, remotes.Parent = "FightingRemotes", ReplicatedStorage
local inputRemote = Instance.new("RemoteEvent")
inputRemote.Name, inputRemote.Parent = "Input", remotes
local snapshotRemote = Instance.new("RemoteEvent")
snapshotRemote.Name, snapshotRemote.Parent = "Snapshot", remotes

local function neutral() return { axis = 0, crouch = false, jump = false, dash = false } end
local slots, clients = {}, {}
local tickNumber, generation = 0, 0
for i = 1, 2 do
	slots[i] = { model = RigBuilder.build(i, fightersFolder), owner = nil,
		state = Movement.new(if i == 1 then -Config.SpawnX else Config.SpawnX, if i == 1 then 1 else -1),
		input = neutral(), lastInput = 0 }
end
local function place(slot)
	local s = slot.state
	local pos = Vector3.new(s.x, s.y + Config.RootHeight, Config.PlaneZ)
	slot.model.HumanoidRootPart.CFrame = CFrame.lookAt(pos, pos + Vector3.new(s.facing, 0, 0))
end
local function resetAll()
	generation += 1
	for i, slot in slots do
		slot.state = Movement.new(if i == 1 then -Config.SpawnX else Config.SpawnX, if i == 1 then 1 else -1)
		slot.input = neutral()
		slot.model.Humanoid.Health = slot.model.Humanoid.MaxHealth
		place(slot)
	end
end
local function watchRig(i)
	local slot = slots[i]
	local model = slot.model
	model.Humanoid.Died:Connect(function()
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
			return
		end
	end
	if player.Character then player.Character:Destroy(); player.Character = nil end
	player:SetAttribute("FighterSlot", 0)
end
local function joined(player)
	if clients[player] then return end
	clients[player] = { tokens = 45, lastPacket = os.clock(), lastReset = -math.huge, lastSeq = 0 }
	assign(player)
end
Players.PlayerAdded:Connect(joined)
Players.PlayerRemoving:Connect(function(player)
	local client = clients[player]
	if client and client.slot then
		local slot = slots[client.slot]
		player.Character = nil
		slot.owner = nil
		slot.model:Destroy()
		slot.model = RigBuilder.build(client.slot, fightersFolder)
		watchRig(client.slot)
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
inputRemote.OnServerEvent:Connect(function(player, packet)
	local client = clients[player]
	if not client then return end
	local now = os.clock()
	client.tokens = math.min(45, client.tokens + (now - client.lastPacket) * 35)
	client.lastPacket = now
	if client.tokens < 1 then return end
	client.tokens -= 1
	if typeof(packet) ~= "table" or not client.slot then return end
	if not finite(packet.seq) or packet.seq % 1 ~= 0 or packet.seq <= client.lastSeq or packet.seq > 1e9 then return end
	if not finite(packet.axis) or math.abs(packet.axis) > 1 then return end
	if typeof(packet.crouch) ~= "boolean" or typeof(packet.jump) ~= "boolean"
		or typeof(packet.dash) ~= "boolean" or typeof(packet.reset) ~= "boolean" then return end
	client.lastSeq = packet.seq
	local slot = slots[client.slot]
	if slot.owner ~= player or slot.model.Humanoid.Health <= 0 then return end
	if packet.reset and now - client.lastReset > 1 then
		if not slots[3 - client.slot].owner then resetAll() end
		client.lastReset = now
	end
	slot.input.axis, slot.input.crouch = packet.axis, packet.crouch
	slot.input.jump = slot.input.jump or packet.jump
	slot.input.dash = slot.input.dash or packet.dash
	slot.lastInput = now
end)
local function snapshot()
	local list = {}
	for i, slot in slots do
		list[i] = { x = slot.state.x, y = slot.state.y, vx = slot.state.vx, vy = slot.state.vy,
			facing = slot.state.facing, state = slot.state.state,
			owner = if slot.owner then slot.owner.UserId else 0,
			name = if slot.owner then slot.owner.DisplayName else "TRAINING DUMMY" }
	end
	snapshotRemote:FireAllClients({ tick = tickNumber, generation = generation, fighters = list })
end
local accumulator, lastSnapshot = 0, 0
RunService.Heartbeat:Connect(function(dt)
	accumulator = math.min(accumulator + dt, Config.MaxCatchUpSteps / Config.TickRate)
	while accumulator >= 1 / Config.TickRate do
		accumulator -= 1 / Config.TickRate
		tickNumber += 1
		local previousDelta = slots[2].state.x - slots[1].state.x
		for _, slot in slots do
			if os.clock() - slot.lastInput > Config.InputTimeout then slot.input = neutral() end
			Movement.step(slot.state, slot.input, Config)
			slot.input.jump, slot.input.dash = false, false
		end
		Movement.resolvePair(slots[1].state, slots[2].state, Config, previousDelta)
	end
	for _, slot in slots do place(slot) end
	if tickNumber - lastSnapshot >= Config.TickRate / Config.SnapshotRate then
		lastSnapshot = tickNumber
		snapshot()
	end
end)
print("[FightingGame] Phase 1 ready — " .. Config.Version .. " — classic authoritative prototype")
