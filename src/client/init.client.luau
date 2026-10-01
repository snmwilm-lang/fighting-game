local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.CombatConfig)
local MoveData = require(Shared.MoveData)
local CharacterData = require(Shared.CharacterData)
local InputController = require(script.InputController)
local CameraController = require(script.CameraController)
local AnimationController = require(script.AnimationController)
local HUDController = require(script.HUDController)
local EffectsController = require(script.EffectsController)
local CinematicController = require(script.CinematicController)
local StageController = require(script.StageController)
local SoundController = require(script.SoundController)
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
hud.onReset = input.reset
hud.onDummy = input.toggleDummy
hud.onAvatar = input.toggleAvatar
hud.onSkin = input.nextSkin
local debugRemote = remotes:WaitForChild("Debug")
hud.onDebugCinematic = function(moveId, style, finish)
	cinematic.labRequested = true
	debugRemote:FireServer(moveId, style, finish == true)
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
remotes:WaitForChild("Snapshot").OnClientEvent:Connect(function(packet)
	if packet.tick < latestTick and packet.generation == generation then return end
	latestTick = packet.tick
	world, receivedAt = packet, os.clock()
	-- Kit styles chosen on the server: every module reads CharacterData[slot].
	for slot, fighter in packet.fighters do
		if fighter.skin and CharacterData.Skins[fighter.skin] and CharacterData[slot].Skin ~= fighter.skin then
			CharacterData[slot] = CharacterData.Skins[fighter.skin]
			hud:applyLook(slot)
		end
	end
	cinematic:snapshot()
	if generation ~= packet.generation or epoch ~= packet.epoch then
		-- New match or new round: snap instead of sliding fighters back to their spawns.
		if generation ~= packet.generation then input.clear() end
		generation, epoch = packet.generation, packet.epoch
		displayed = {}
		cameraController.center = nil
	end
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
		if motorCount < 15 then return nil end -- Wait for complete rig replication.
		local animation = AnimationController.new(model)
		cached = {
			model = model, root = root, animation = animation,
			rootHeight = animation.rootHeight, -- measured on this body: its feet rest on the floor
		}
		rigs[slot] = cached
		effects:attachRig(slot, cached)
	end
	return cached
end

local fps = 60
RunService:BindToRenderStep("FightingPresentation", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if not world then return end
	local now = os.clock()
	local alpha = 1 - math.exp(-35 * math.min(dt, 0.1))
	local sinceSnapshot = math.min(now - receivedAt, 2 / Config.SnapshotRate)
	for i, state in world.fighters do
		local current = displayed[i]
		-- Bounded visual extrapolation, paused during hitstop; server state stays the truth.
		local ahead = if state.hitstop > 0 then 0 else sinceSnapshot
		local targetX = math.clamp(state.x + state.vx * ahead, Config.ArenaMinX, Config.ArenaMaxX)
		local targetY = math.max(0, state.y + state.vy * ahead)
		if not current then current = { x = state.x, y = state.y }; displayed[i] = current end
		current.x += (targetX - current.x) * alpha
		current.y += (targetY - current.y) * alpha
		for k, v in state do
			if k ~= "x" and k ~= "y" then current[k] = v end
		end
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
	for i in world.fighters do
		local current = displayed[i]
		local rig = findRig(i)
		if rig then
			local pos = Vector3.new(current.x, current.y + rig.rootHeight, current.z or Config.PlaneZ)
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
	input.setUltimateReady(mine ~= nil and mine.meter >= MoveData.Moves.KaienRush.meterCost)
	fps += ((1 / math.max(dt, 0.001)) - fps) * math.min(1, dt * 3)
	hud:update(world, displayed, fps, dt)
end)
print("[FightingGame] Client ready — combos (clics), garde F, spéciale E, ultime R + cinématique, CPU")
