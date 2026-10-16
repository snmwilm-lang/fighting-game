--[[
	Wilhem's VFX pack in the fight (client, cosmetic only: never a hit, a health or a K.O.).

	The pack's three modules (VFX/: VFX_Common, VFX_Chars, VFX_Specials) draw the shared combat
	effects and every fighter's own. This bridge calls them from the game's events and views,
	and only for a family whose every asset is uploaded (Shared.VfxConfig: "COMMON", or a kit,
	which needs the shared assets too). EffectsController asks first: a call returns true when
	the pack drew the effect, false when the game's own procedural effect must stay (assets not
	uploaded yet, meshes not loaded yet, or a pack effect that failed once: that family then
	goes back to the game's effects for the session, with one warning). A texture that does not
	load on the client is named in the output and left out of the pack's effects (preload).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local VfxConfig = require(Shared.VfxConfig)
local CombatConfig = require(Shared.CombatConfig)

local VfxPack = {}
VfxPack.__index = VfxPack

-- (the pack's names of the fighters)
local NAME = { ["KUROEN SHIN"] = "KUROEN_SHIN" }
local function packName(kit)
	return NAME[kit] or kit
end
VfxPack.packName = packName

-- The game's impact tiers (KitFX.impactTier) on the pack's four levels: a jab stays light, a
-- strong blow is the pack's medium, the end of a string its heavy, an ultimate's or the K.O.'s
-- last blow its finisher.
VfxPack.LEVEL = { light = "light", heavy = "medium", finisher = "heavy", ko = "finisher" }

-- Kits whose shot keeps the game's own drawing: KAI's KIKOHO (Wilhem's own ball, his
-- drawings), and the shots the pack does not hang on a flying part (NOVA's drones, SYLVA's
-- trap, RYUKEN's quake along the floor, HIBIKI's pulses, GORAN's hug); the bosses have none.
local OWN_SHOT = { KAI = true, ASURA = true, ["KUROEN SHIN"] = true, NOVA = true, SYLVA = true, RYUKEN = true,
	HIBIKI = true, GORAN = true }

-- The passives the bridge keeps alive on the body (Set each frame from the view; the others
-- are events: Trigger). Each gives the pack's arguments.
local PASSIVE_ARGS = {
	KAI = true, ZEPHYR = true, AKEMI = true, RYUKEN = true, SHIN = true, HIBECARES = true, GORAN = true,
	HIBIKI = true, KUREN = true, NOVA = true, KUROEN = true, ELIAN = true, KAZAN = true,
	RAIJIN = function(rig)
		-- (the spear crackles between its two ends: the weapon's trail attachments)
		local weapon = rig.trails and rig.trails.Weapon
		return { weaponBase = weapon and weapon.Attachment0, weaponTip = weapon and weapon.Attachment1 }
	end,
}
-- What each continuous passive shows, read from the fighter's view (`m`: its move's data).
local PASSIVE_VALUE = {
	RYUKEN = function(view) return view.passive or 0 end, -- RAGE stacks (0..10)
	KUROEN = function(view) return view.domination or 0 end, -- DOMINATION (0..3)
	AKEMI = function(view) return view.passiveCharges or 0 end, -- INSTINCT's evades ready
	ZEPHYR = function(view) return view.sparks or 0 end, -- PERFECT RHYTHM's sparks
	HIBECARES = function(view) -- KING OF RUINS: the health left (in steps: Set redraws the cracks)
		return math.floor((view.hp or 0) / math.max(1, view.maxHp or 1) * 20 + 0.5) / 20
	end,
	RAIJIN = function(view) return if view.passiveOn then 3 else 0 end, -- OVERCHARGE ready
	HIBIKI = function(view) return if (view.tempo or 0) > 0 then 120 else 0 end, -- TEMPO's beat
	KUREN = function(_, m) return if m and (m.skill or m.meterCost) then 1 else 0 end, -- the PACT paid
	NOVA = function(view) return view.passiveOn == true end, -- a drone ready
}
-- (set every frame, not only on a change: its cracks follow his feet)
local EVERY_FRAME = { HIBECARES = true }

function VfxPack.new(effects)
	return setmetatable({ effects = effects, loaded = nil, broken = {}, readiness = {}, checked = {}, failed = {} }, VfxPack)
end

-- The shared effects that are mostly a mesh: the game's own stays until it is loaded.
VfxPack.MESH_OF = { Guard = "SHIELD_HEX", Reflect = "SHIELD_HEX", Burst = "SPHERE", SuperJump = "SHOCK_CYLINDER",
	FastFall = "SHOCK_RING" }

-- The pack's modules, required once and only when a family is ready (nothing of the pack runs
-- before its assets are there).
function VfxPack:load()
	if self.loaded ~= nil then return self.loaded end
	local ok, err = pcall(function()
		local folder = script.Parent:WaitForChild("VFX", 5)
		self.V = require(folder:WaitForChild("VFX_Common", 5))
		self.C = require(folder:WaitForChild("VFX_Chars", 5))
		self.S = require(folder:WaitForChild("VFX_Specials", 5))
	end)
	self.loaded = ok
	if ok then
		local effects = self.effects
		-- (one camera, one shake: the pack's shakes go through the game's)
		self.V.ShakeHook = function(amplitude, seconds)
			effects.camera:shake(amplitude * (if effects.reduced then 0.4 else 1), seconds)
		end
		self:preload()
	else
		warn("[VFX] the pack did not load: " .. tostring(err))
	end
	return ok
end

-- Every uploaded texture loaded once on this client. One that does not load (a wrong ID, an
-- image refused) is named in the output and left out of the effects (its particles are not
-- drawn, the rest of each effect plays); a family that loses many goes back to the game's
-- effects (`ready`). A texture still loading (a slow connection, a time-out) is not a failure.
function VfxPack:preload()
	task.spawn(function()
		local list, keyOf, bad = {}, {}, {}
		for key in VfxConfig.TEXTURES do
			local id = VfxConfig.texture(key)
			if id then
				table.insert(list, id)
				keyOf[id] = key
			end
		end
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(list, function(id, status)
				if status == Enum.AssetFetchStatus.Failure and keyOf[id] then
					self.failed[keyOf[id]] = true
					table.insert(bad, keyOf[id] .. " " .. id)
				end
			end)
		end)
		if #bad > 0 then
			table.sort(bad)
			warn("[VFX] these textures did not load, left out of the effects (check their IDs in VfxConfig): "
				.. table.concat(bad, ", "))
			if self.V and self.V.Blank then
				for key in self.failed do self.V.Blank(key) end
			end
			self.readiness = {} -- (each family checked again)
		end
	end)
end

-- How many of a family's textures may fail before it goes back to the game's effects: a few
-- left out still leave the pack's look (a misread ID), not most of it.
function VfxPack.tolerated(count)
	return math.max(2, math.floor(count * 0.2))
end

local function meshesThere(list)
	local folder = ReplicatedStorage:FindFirstChild("VFX_Meshes")
	for _, key in list do
		if not (folder and folder:FindFirstChild(key)) then return false end
	end
	return true
end

-- Does the pack draw this family: "COMMON" (the shared effects) or a kit (its own and the
-- shared ones)? Checked again every 2 s while not (the server loads the meshes after the start).
function VfxPack:ready(family)
	if not family or self.broken[family] then return false end
	if self.readiness[family] then return true end
	local now = os.clock()
	if self.readiness[family] == false and now - (self.checked[family] or 0) < 2 then return false end
	self.checked[family] = now
	local need = if family == "COMMON" then VfxConfig.COMMON else VfxConfig.kitNeed(family) -- (the game's names)
	-- (the textures decide: a mesh still missing only leaves its piece out, MESH_OF; textures
	-- that failed to load, `failed`, are left out, and too many keep the family on the game's)
	local ok = need ~= nil and VfxConfig.ready({ textures = need.textures, meshes = {} }) and self:load()
	if ok then
		local lost = 0
		for _, key in need.textures do
			if self.failed[key] then lost += 1 end
		end
		ok = lost <= VfxPack.tolerated(#need.textures)
	end
	self.readiness[family] = ok and true or false
	return self.readiness[family]
end

-- Runs a pack effect; if it fails, its family goes back to the game's own effects.
function VfxPack:try(family, fn, ...)
	if self.V then self.V.Quality = if self.effects.reduced then 0.5 else 1 end
	local ok, err = pcall(fn, ...)
	if not ok then
		self.broken[family] = true
		warn(("[VFX] %s: back to the game's own effects (%s)"):format(tostring(family), tostring(err)))
	end
	return ok
end

-- A shared effect (VFX_Common): `name` is the pack's function (Parry, Clash, Guard...). Its
-- first argument missing (a body not there yet): the game draws it, the pack stays on.
function VfxPack:common(name, ...)
	if (...) == nil or not self:ready("COMMON") then return false end
	if self.MESH_OF[name] and not meshesThere({ self.MESH_OF[name] }) then return false end
	return self:try("COMMON", self.V[name], ...)
end

-- A blow lands: the attacker's own impact, at the game's tier, frozen with the fighters
-- during the hitstop (frames). `ignore`: the bodies (not the floor under the blow).
function VfxPack:hit(kit, tier, position, facing, color, hitstop, ignore)
	if not self:ready(kit) then return false end
	local front = position + Vector3.new(0, 0, 0.8)
	local cf = CFrame.lookAt(front, front + Vector3.new(if facing < 0 then -1 else 1, 0, 0))
	local scale = (if tier == "light" then 0.75 else 1) * (if self.effects.reduced then 0.85 else 1)
	return self:try(kit, self.C.Impact, packName(kit), self.LEVEL[tier] or "medium", cf, color,
		{ hitstop = hitstop, ignore = ignore, scale = scale })
end

-- A strong blow goes out: the kit's arc (or the shared slash), facing the camera. roll: the
-- arc's tilt on screen (degrees: 0 flat, 60 rising, -60 falling).
function VfxPack:swing(kit, center, roll, color)
	-- (an arc is a mesh: the shared slash, or the kit's own)
	local own = VfxConfig.KITS[kit]
	if not (self:ready(kit) and meshesThere({ "SLASH_180" }) and meshesThere(own and own.meshes or {})) then return false end
	return self:try(kit, function()
		self.C.Swing(packName(kit), self.V.ArcCFrame(center, roll), color, {})
	end)
end

-- The dash starts: the kit's own (dust, ghost, embers, the warp...).
function VfxPack:dash(kit, model, dir, color)
	if not (model and self:ready(kit)) then return false end
	return self:try(kit, self.C.Dash, packName(kit), model, dir, color)
end

-- ============================================================== on the body

local function undress(rig)
	local state = rig.pack
	if not state then return end
	for _, trail in state.trails or {} do pcall(trail.Destroy) end
	if state.aura then pcall(state.aura.Destroy) end
	if state.passive then pcall(state.passive.Destroy) end
	rig.pack = nil
end
VfxPack.undress = function(_, rig) undress(rig) end

-- The fighter's effects that live on its body: strike trails on the game's trail attachments,
-- the aura (its level: the meter), the passive. Built once per body, kit and colour; nil while
-- the pack does not draw this kit.
function VfxPack:dress(rig, kit, color, now)
	local key = tostring(kit) .. "|" .. color:ToHex() .. "|" .. tostring(rig.model)
	local state = rig.pack
	if state and state.key == key and (state.on or now - state.at < 2) then
		return if state.on then state else nil
	end
	undress(rig)
	state = { key = key, at = now, on = false, trails = {} }
	rig.pack = state
	if not (rig.model and rig.model.Parent and self:ready(kit)) then return nil end
	local name = packName(kit)
	local ok = self:try(kit, function()
		for limb, trail in rig.trails or {} do
			if trail.Attachment0 and trail.Attachment1 then
				state.trails[limb] = self.C.Trail(name, trail.Attachment0, trail.Attachment1, color)
			end
		end
		if self.S.Auras[name] then state.aura = self.S.Aura(name, rig.model, color) end
		local args = PASSIVE_ARGS[name]
		if args and self.S.Passives[name] then
			local a = if type(args) == "function" then args(rig) else {}
			a.char = rig.model
			a.color = color
			state.passive = self.S.Passive(name, a)
		end
	end)
	if not ok then
		undress(rig)
		return nil
	end
	state.on, state.name = true, name
	return state
end

-- Every frame: the aura's level (the meter: one level a third of the gauge) and the passive's
-- state. False when the pack does not dress this body.
function VfxPack:update(rig, view, m, now, color)
	if rig.pack and rig.pack.on and not self:ready(view.kit) then undress(rig) end -- (a texture failed meanwhile)
	local state = self:dress(rig, view.kit, color, now)
	if not state then return false end
	return self:try(view.kit, function()
		local level = math.clamp(math.floor((view.meter or 0) / (CombatConfig.MaxMeter / 3)), 0, 3)
		if state.aura and state.level ~= level then
			state.level = level
			state.aura.SetLevel(level)
		end
		local value = PASSIVE_VALUE[state.name]
		if state.passive and value then
			local v = value(view, m)
			if v ~= state.value or EVERY_FRAME[state.name] then
				state.value = v
				state.passive.Set(v)
			end
		end
	end)
end

-- A strike trail on or off (true: the pack's trail took it, the game's stays off).
function VfxPack:trail(rig, limb, on)
	local state = rig.pack
	local trail = state and state.on and state.trails[limb]
	if not trail then return false end
	if state.lit == nil then state.lit = {} end
	if state.lit[limb] ~= on then
		state.lit[limb] = on
		if on then trail.On() else trail.Off() end
	end
	return true
end

-- A passive's moment (KAI's RESOLVE, AKEMI's evade, GORAN's anchor, ELIAN's SECOND WIND):
-- only on that fighter (`kit`: the game's name), whose passive draws it.
function VfxPack:trigger(rig, kit, ...)
	local state = rig and rig.pack
	if not (state and state.on and state.passive and state.name == packName(kit)) then return false end
	return self:try(state.name, state.passive.Trigger, ...)
end
-- The passive's state set from an event (KAZAN's chain to the shackled foe, nil: let go).
function VfxPack:set(rig, kit, value)
	local state = rig and rig.pack
	if not (state and state.on and state.passive and state.name == packName(kit)) then return false end
	return self:try(state.name, state.passive.Set, value)
end

-- ============================================================== shots

-- A new shot: the kit's own skill hung on an invisible part the game moves (its LookVector:
-- where it flies). nil: the game draws it.
function VfxPack:shot(kit, color, anchor)
	if not kit or OWN_SHOT[kit] or not self:ready(kit) then return nil end
	local name = packName(kit)
	if not self.S.Skills[name] then return nil end
	local handle
	local ok = self:try(kit, function()
		handle = self.S.Skill(name, { part = anchor, color = color })
	end)
	return if ok then handle else nil
end

return VfxPack
