local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared").CombatConfig)
local InputController = require(script.InputController)
local CameraController = require(script.CameraController)
local AnimationController = require(script.AnimationController)
local HUDController = require(script.HUDController)
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("FightingRemotes")
local folder = workspace:WaitForChild("Fighters")
local hud = HUDController.new(Config)
local input = InputController.start(remotes:WaitForChild("Input"))
local cameraController = CameraController.new(Config)
hud.onReset = input.reset

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

local latest, displayed, rigs = nil, {}, {}
local generation, receivedAt, latestTick = -1, 0, -1
remotes.Snapshot.OnClientEvent:Connect(function(packet)
	if packet.tick < latestTick then return end
	latestTick = packet.tick
	latest, receivedAt = packet.fighters, os.clock()
	if generation ~= packet.generation then
		generation = packet.generation
		displayed = {}
		cameraController.center = nil
		input.clear()
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
		cached = { model = model, root = root, animation = AnimationController.new(model) }
		rigs[slot] = cached
	end
	return cached
end

local fps, hudTime = 60, 0
RunService:BindToRenderStep("FightingPresentation", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if not latest then return end
	local alpha = 1 - math.exp(-35 * math.min(dt, 0.1))
	local sinceSnapshot = math.min(os.clock() - receivedAt, 1 / Config.SnapshotRate)
	for i, state in latest do
		local current = displayed[i]
		-- Bounded visual extrapolation; server state remains the source of truth.
		local targetX = math.clamp(state.x + state.vx * sinceSnapshot, Config.ArenaMinX, Config.ArenaMaxX)
		local targetY = math.max(0, state.y + state.vy * sinceSnapshot)
		if not current then current = { x = state.x, y = state.y }; displayed[i] = current end
		current.x += (targetX - current.x) * alpha
		current.y += (targetY - current.y) * alpha
		current.facing, current.state, current.owner, current.name = state.facing, state.state, state.owner, state.name
		local rig = findRig(i)
		if rig then
			local pos = Vector3.new(current.x, current.y + Config.RootHeight, Config.PlaneZ)
			rig.root.CFrame = CFrame.lookAt(pos, pos + Vector3.new(current.facing, 0, 0))
			rig.animation:update(current.state, os.clock(), hud.poseRate)
		end
	end
	cameraController:update(displayed, dt)
	fps += ((1 / math.max(dt, 0.001)) - fps) * math.min(1, dt * 3)
	hudTime += dt
	if hudTime > 0.1 then hudTime = 0; hud:update(displayed, fps) end
end)
print("[FightingGame] Client ready — movement, camera, touch/gamepad and stepped poses")
