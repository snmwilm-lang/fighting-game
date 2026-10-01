local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.CombatConfig)
local MoveData = require(Shared.MoveData)
local InputController = require(script.InputController)
local CameraController = require(script.CameraController)
local AnimationController = require(script.AnimationController)
local HUDController = require(script.HUDController)
local EffectsController = require(script.EffectsController)
local CinematicController = require(script.CinematicController)
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("FightingRemotes")
local folder = workspace:WaitForChild("Fighters")
local hud = HUDController.new(Config)
local input = InputController.start(remotes:WaitForChild("Input"))
local cameraController = CameraController.new(Config)
local effects = EffectsController.new(Config, cameraController)
local cinematic = CinematicController.new(Config, hud, effects)
hud.onReset = input.reset
hud.onDummy = input.toggleDummy
hud.onAvatar = input.toggleAvatar
hud.onEffects = function()
	effects.reduced = not effects.reduced
	return effects.reduced
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
		cached = {
			model = model, root = root, animation = AnimationController.new(model),
			rootHeight = model:GetAttribute("RootHeight") or Config.RootHeight,
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
				rig.root.CFrame = CFrame.lookAt(pos, pos + current.lookDir) -- free orientation (K.O. scene)
			else
				-- Turn the rig slightly toward the camera, like sprites drawn in 3/4 view.
				rig.root.CFrame = CFrame.lookAt(pos, pos + Vector3.new(current.facing, 0, 0))
					* CFrame.Angles(0, -current.facing * math.rad(Config.ModelYaw), 0)
			end
			rig.animation:update(current, now, hud.poseRate)
			previous[i] = { key = effects:update(i, current, rig, previous[i], now) }
		end
	end
	effects:updateProjectiles(world.projectiles, sinceSnapshot, now)
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
