local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.CombatConfig)
local MoveData = require(Shared.MoveData)
local CharacterData = require(Shared.CharacterData)
local RigReader = require(Shared.RigReader)
local Animator = require(Shared.Animator)
local InputController = require(script.InputController)
local CameraController = require(script.CameraController)
local AnimationController = require(script.AnimationController)
local HUDController = require(script.HUDController)
local EffectsController = require(script.EffectsController)
local CinematicController = require(script.CinematicController)
local StageController = require(script.StageController)
local SoundController = require(script.SoundController)
local HubController = require(script.HubController)
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("FightingRemotes")
local folder = workspace:WaitForChild("Fighters")
local hud = HUDController.new(Config)
local input = InputController.start(remotes:WaitForChild("Input"))
local cameraController = CameraController.new(Config)
local effects = EffectsController.new(Config, cameraController)
local cinematic = CinematicController.new(Config, hud, effects)
local stage = StageController.new(Config)
local sounds = SoundController.new()
HubController.new(remotes:WaitForChild("Hub")) -- DÉFIER / ACCEPTER / INVITER UN AMI (1 contre 1)
hud.onReset = input.reset
hud.onDummy = input.toggleDummy
hud.onAvatar = input.toggleAvatar
hud.onSkin = input.nextSkin
hud.onKit = input.nextKit
hud.onFoeKit = input.nextFoeKit
hud.onStance = input.setStance
input.setCinematicTick(function() return cinematic.displayTick end)
local debugRemote = remotes:WaitForChild("Debug")
-- kind: the cinematic type ("Rush", "Awaken", "Gate") of the local fighter's kit.
hud.onDebugCinematic = function(kind, style, finish)
	cinematic.labRequested = true
	debugRemote:FireServer(kind, style, finish == true)
end
hud.onPreviewKO = function()
	cinematic:previewKO(player:GetAttribute("FighterSlot") or 0)
end
hud.onEffects = function()
	effects.reduced = not effects.reduced
	return effects.reduced
end
hud.onSound = function()
	sounds:setEnabled(not sounds.enabled)
	return sounds.enabled
end
hud.onDebug = function()
	effects:setDebug(not effects.debug)
	return effects.debug
end
hud:setEffectsReduced(effects.reduced)

-- Disable Roblox's walking/jumping controls; our abstract input adapter owns them.
task.spawn(function()
	local module = player.PlayerScripts:WaitForChild("PlayerModule", 10)
	if module then require(module):GetControls():Disable() end
end)
-- Default Reset would kill the custom rig. The HUD offers a solo-only replacement.
task.spawn(function()
	for _ = 1, 20 do
		local ok = pcall(function() StarterGui:SetCore("ResetButtonCallback", false) end)
		if ok then return end
		task.wait(0.25)
	end
	warn("[FightingGame] Default Reset could not be disabled; use the training Reset button.")
end)

local world, displayed, rigs, previous = nil, {}, {}, {}
effects.rigs = rigs
local generation, epoch, receivedAt, latestTick, lastPhase = -1, -1, 0, -1, nil
local lastCinematic = nil
local roster = nil -- last names / looks / kits sent by the server
remotes:WaitForChild("Snapshot").OnClientEvent:Connect(function(packet)
	if packet.tick < latestTick and packet.generation == generation then return end
	latestTick = packet.tick
	-- Names, looks and kits come only when they change (see the server's roster): merged
	-- into every snapshot so the rest of the client reads them as before.
	if packet.roster then roster = packet.roster end
	for slot, fighter in packet.fighters do
		local r = roster and roster[slot]
		if r then
			for k, v in r do
				if fighter[k] == nil then fighter[k] = v end
			end
		end
	end
	world, receivedAt = packet, os.clock()
	-- Kit styles chosen on the server: every module reads CharacterData[slot].
	for slot, fighter in packet.fighters do
		if fighter.skin and CharacterData.Skins[fighter.skin] and CharacterData[slot].Skin ~= fighter.skin then
			CharacterData[slot] = CharacterData.Skins[fighter.skin]
			hud:applyLook(slot)
		end
	end
	-- The local fighter's kit drives the combo list, the trainer and the lab.
	local mine = packet.fighters[player:GetAttribute("FighterSlot") or 0]
	hud:setKit(if mine then mine.kit else nil)
	cinematic:snapshot()
	if generation ~= packet.generation or epoch ~= packet.epoch then
		-- New match or new round: snap instead of sliding fighters back to their spawns.
		if generation ~= packet.generation then input.clear() end
		generation, epoch = packet.generation, packet.epoch
		displayed = {}
		cameraController.center = nil
	end
	-- An ultimate re-aligns both fighters on the ground: snap rather than slide into place.
	local cinKey = if packet.cinematic then packet.cinematic.move .. "/" .. packet.cinematic.attacker else nil
	if cinKey and cinKey ~= lastCinematic then displayed = {} end
	lastCinematic = cinKey
	if packet.phase == "Intro" and lastPhase ~= "Intro" then
		hud:announceRound(packet.round)
	end
	lastPhase = packet.phase
end)
remotes:WaitForChild("Events").OnClientEvent:Connect(function(batch)
	if type(batch) ~= "table" then return end
	for _, event in batch do
		effects:onEvent(event, displayed, rigs)
		sounds:onEvent(event)
		if event.kind == "SuperFlash" then
			cinematic:superFlash(event.attacker, event.move)
		elseif event.kind == "Hit" and event.cinematic then
			cinematic:onHit(event)
		elseif event.kind == "Prompt" then
			cinematic:onPrompt(event)
		elseif event.kind == "PromptGrade" then
			cinematic:onGrade(event)
		end
		if world then hud:onEvent(event, world) end
	end
end)

local firstSeen = setmetatable({}, { __mode = "k" }) -- model -> first time seen incomplete
local function findRig(slot)
	local model = folder:FindFirstChild("Fighter" .. slot)
	if not model then return nil end
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not model:FindFirstChild("Head") then return nil end
	local cached = rigs[slot]
	if not cached or cached.model ~= model then
		local motorCount = 0
		for _, child in model:GetDescendants() do
			if child:IsA("Motor6D") then motorCount += 1 end
		end
		-- Wait for complete rig replication (15 joints on R15 and KAI, 6 on R6).
		local needed = if RigReader.rigType(model) == "R6" then 6 else 15
		if motorCount < needed then
			-- Joints that never arrive as Motor6D (Roblox's avatar joint upgrade turns them into
			-- constraints): after a moment, rebuild them here so the body can be animated.
			firstSeen[model] = firstSeen[model] or os.clock()
			if os.clock() - firstSeen[model] < 2 or RigReader.ensureJoints(model) == 0 then return nil end
			warn("[FightingGame] Articulations de " .. model.Name .. " reconstruites côté client")
		end
		local animation = AnimationController.new(model)
		cached = {
			model = model, root = root, animation = animation, readAt = os.clock(),
			rootHeight = animation.rootHeight, -- measured on this body: its feet rest on the floor
		}
		rigs[slot] = cached
		effects:attachRig(slot, cached)
	elseif not cached.animation.complete and os.clock() - cached.readAt > 0.25 then
		-- Its skeleton was not fully there yet (joints or parts still replicating): read again,
		-- otherwise the body would stay frozen in its bind pose.
		cached.readAt = os.clock()
		local animation = AnimationController.new(model)
		if animation.complete then
			cached.animation, cached.rootHeight = animation, animation.rootHeight
		end
	end
	return cached
end

local fps = 60
RunService:BindToRenderStep("FightingPresentation", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if not world then return end
	local now = os.clock()
	local alpha = 1 - math.exp(-35 * math.min(dt, 0.1))
	local sinceSnapshot = math.min(now - receivedAt, 2 / Config.SnapshotRate)
	local mySlot = player:GetAttribute("FighterSlot") or 0
	for i, state in world.fighters do
		local current = displayed[i]
		-- Bounded visual extrapolation, paused during hitstop; server state stays the truth.
		local ahead = if state.hitstop > 0 then 0 else sinceSnapshot
		local vx, predicted = state.vx, nil
		-- Visual prediction of the local fighter (a far player): walking follows the held
		-- direction at once and is drawn ahead by the one-way latency. Only the drawing: the
		-- server decides, and the smoothing pulls the body back if it disagrees.
		if i == mySlot and not world.cinematic and state.hitstop == 0 and state.y <= 0
			and (state.state == "Idle" or state.state == "Walking") then
			local kit = MoveData.Kits[state.kit]
			local stance = kit and kit.Stances and state.stance and kit.Stances[state.stance]
			local stats = if stance then stance.Stats elseif kit then kit.Stats else nil
			local axis, crouch, block = input.held()
			if stats then
				vx = if crouch or block then 0 else axis * stats.WalkSpeed
				ahead += math.min((state.ping or 0) / 2000, 0.12)
				predicted = if math.abs(vx) > 0.05 then "Walking" else "Idle"
			end
		end
		local targetX = math.clamp(state.x + vx * ahead, Config.ArenaMinX, Config.ArenaMaxX)
		local targetY = math.max(0, state.y + state.vy * ahead)
		if not current then current = { x = state.x, y = state.y }; displayed[i] = current end
		current.x += (targetX - current.x) * alpha
		current.y += (targetY - current.y) * alpha
		for k, v in state do
			if k ~= "x" and k ~= "y" then current[k] = v end
		end
		if predicted then current.state, current.vx = predicted, vx end
		-- Staging fields are rebuilt every frame by the cinematic director.
		current.ghost, current.pose, current.z, current.lookDir = nil, nil, nil, nil
		local m = MoveData.Moves[state.move]
		if m then
			current.moveFrame = math.min(state.moveFrame + math.floor(ahead * Config.TickRate), MoveData.total(m))
		end
		current.intro = world.phase == "Intro" and world.phaseTicks > 50
		current.victory = (world.phase == "KO" or world.phase == "MatchEnd") and (world.winner == i or world.matchWinner == i)
			and world.phaseTicks < Config.KOTicks - 60 and state.state ~= "KO" and state.y <= 0
	end
	-- The ultimate cinematic stages poses/positions and owns the camera while it plays.
	local cinematicActive = cinematic:update(world, displayed, dt, now - receivedAt > 1)
	-- Presentation spacing (Animator.spacing): at point-blank range the two bodies are drawn a
	-- little apart so they never sink into each other. Drawing only, never in cinematics.
	local spread = { 0, 0 }
	local one, two = displayed[1], displayed[2]
	if one and two and not cinematicActive then
		local push = Animator.spacing(one.x, one.y, two.x, two.y)
		local side = if two.x >= one.x then 1 else -1
		spread = { -side * push, side * push }
	end
	for i in world.fighters do
		local current = displayed[i]
		local rig = findRig(i)
		if rig then
			local pos = Vector3.new(current.x + (spread[i] or 0), current.y + rig.rootHeight, current.z or Config.PlaneZ)
			if current.lookDir then
				local look = current.lookDir
				rig.root.CFrame = CFrame.lookAt(pos, pos + Vector3.new(look.x, look.y, look.z)) -- free orientation (K.O. scene)
			else
				-- Heading in the floor plane: 0 = facing +X, pi = facing -X. A side switch turns
				-- the body through the camera side in a few frames instead of popping.
				local target = if current.facing > 0 then 0 else math.pi
				rig.heading = if rig.heading then rig.heading + (target - rig.heading) * math.min(1, dt * 25) else target
				-- Turned slightly toward the camera, like sprites drawn in 3/4 view.
				local heading = rig.heading + math.rad(Config.ModelYaw) * math.cos(rig.heading)
				rig.root.CFrame = CFrame.lookAt(pos, pos + Vector3.new(math.cos(heading), 0, math.sin(heading)))
			end
			rig.animation:update(current, displayed[3 - i], dt, now, hud.poseRate, cinematicActive)
			previous[i] = { key = effects:update(i, current, rig, previous[i], now) }
			sounds:update(i, current, MoveData.Moves)
		end
	end
	effects:updateProjectiles(world.projectiles, sinceSnapshot, now)
	stage:update(now, displayed, cinematicActive)
	if cinematicActive then
		cinematic:camera(dt, rigs, displayed)
	else
		cameraController:update(displayed, dt)
	end
	local localSlot = player:GetAttribute("FighterSlot") or 0
	local mine = displayed[localSlot]
	local kit = mine and MoveData.Kits[mine.kit]
	input.setUltimateReady(kit ~= nil and mine.meter >= MoveData.Moves[kit.Ultimates.Rush].meterCost)
	input.setFatalReady(mine ~= nil and mine.fatal == "ready")
	fps += ((1 / math.max(dt, 0.001)) - fps) * math.min(1, dt * 3)
	hud:update(world, displayed, fps, dt)
end)
print("[FightingGame] Client ready — 4 kits (T / G), combos (clics), garde F, spéciale E, ultime R, R15 / R6")
