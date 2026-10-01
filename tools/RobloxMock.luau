--[[
	A tiny stand-in for the parts of the Roblox API used by src/server/RigBuilder.luau, so the
	fighter bodies and kit outfits can be built offline (tools/rigcheck.py). Real CFrame maths
	(positions and rotations), plain instances with names, parents and attributes; everything
	else is stored and ignored. Not a Roblox emulator: only what RigBuilder touches.
]]
local Mock = {}

-- ===================================================================== Vector3
local V3 = {}
V3.__index = V3
local function vec(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
end
V3.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__mul = function(a, b)
	if type(a) == "number" then return vec(b.X * a, b.Y * a, b.Z * a) end
	if type(b) == "number" then return vec(a.X * b, a.Y * b, a.Z * b) end
	return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then return vec(a.X / b, a.Y / b, a.Z / b) end
	return vec(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__unm = function(a) return vec(-a.X, -a.Y, -a.Z) end
function V3.__index(t, k)
	if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) end
	return rawget(V3, k)
end
Mock.Vector3 = { new = vec, one = vec(1, 1, 1), zero = vec(0, 0, 0), xAxis = vec(1, 0, 0), yAxis = vec(0, 1, 0), zAxis = vec(0, 0, 1) }

-- ===================================================================== CFrame
-- r = row-major 3x3 rotation { r00, r01, r02, r10, ... }, p = position.
local CF = {}
local function cf(p, r)
	return setmetatable({ p = p, r = r }, CF)
end
local IDENT = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function rmul(a, b)
	local o = {}
	for i = 0, 2 do
		for j = 0, 2 do
			o[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[3 + j + 1] + a[i * 3 + 3] * b[6 + j + 1]
		end
	end
	return o
end
local function rapply(r, v)
	return vec(r[1] * v.X + r[2] * v.Y + r[3] * v.Z, r[4] * v.X + r[5] * v.Y + r[6] * v.Z, r[7] * v.X + r[8] * v.Y + r[9] * v.Z)
end
local function rtrans(r)
	return { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] }
end
CF.__mul = function(a, b)
	if getmetatable(b) == CF then return cf(a.p + rapply(a.r, b.p), rmul(a.r, b.r)) end
	return a.p + rapply(a.r, b)
end
function CF.__index(t, k)
	if k == "Position" then return t.p end
	if k == "X" then return t.p.X elseif k == "Y" then return t.p.Y elseif k == "Z" then return t.p.Z end
	if k == "LookVector" then return vec(-t.r[3], -t.r[6], -t.r[9]) end
	if k == "RightVector" then return vec(t.r[1], t.r[4], t.r[7]) end
	if k == "UpVector" then return vec(t.r[2], t.r[5], t.r[8]) end
	if k == "Rotation" then return cf(vec(), t.r) end
	return rawget(CF, k)
end
function CF.Inverse(t)
	local rt = rtrans(t.r)
	return cf(-rapply(rt, t.p), rt)
end
function CF.ToObjectSpace(t, o)
	return t:Inverse() * o
end
function CF.ToWorldSpace(t, o)
	return t * o
end
function CF.GetComponents(t)
	local r = t.r
	return t.p.X, t.p.Y, t.p.Z, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9]
end
local function angles(rx, ry, rz)
	local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
	local X = { 1, 0, 0, 0, cx, -sx, 0, sx, cx }
	local Y = { cy, 0, sy, 0, 1, 0, -sy, 0, cy }
	local Z = { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }
	return rmul(rmul(X, Y), Z)
end
Mock.CFrame = {
	new = function(x, y, z, ...)
		if type(x) == "table" then
			if y and type(y) == "table" then -- CFrame.new(pos, lookAt)
				local f = y - x
				local l = f.Magnitude
				if l < 1e-9 then return cf(x, IDENT) end
				local bz = -f / l
				local rx = vec(-bz.Z, 0, bz.X) -- up x back
				local rl = rx.Magnitude
				if rl < 1e-9 then rx = vec(1, 0, 0) else rx = rx / rl end
				local uy = vec(bz.Y * rx.Z - bz.Z * rx.Y, bz.Z * rx.X - bz.X * rx.Z, bz.X * rx.Y - bz.Y * rx.X)
				return cf(x, { rx.X, uy.X, bz.X, rx.Y, uy.Y, bz.Y, rx.Z, uy.Z, bz.Z })
			end
			return cf(x, IDENT)
		end
		local extra = { ... }
		if #extra == 9 then return cf(vec(x, y, z), extra) end
		return cf(vec(x, y, z), IDENT)
	end,
	Angles = function(rx, ry, rz) return cf(vec(), angles(rx, ry, rz)) end,
	fromEulerAnglesXYZ = function(rx, ry, rz) return cf(vec(), angles(rx, ry, rz)) end,
	identity = cf(vec(), IDENT),
}
Mock.CFrame.lookAt = function(a, b) return Mock.CFrame.new(a, b) end

-- ===================================================================== Colours, UI values
Mock.Color3 = {
	fromHex = function(h)
		h = h:gsub("#", "")
		return { R = tonumber(h:sub(1, 2), 16) / 255, G = tonumber(h:sub(3, 4), 16) / 255, B = tonumber(h:sub(5, 6), 16) / 255, hex = h:upper() }
	end,
	new = function(r, g, b)
		return { R = r, G = g, B = b, hex = string.format("%02X%02X%02X", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)) }
	end,
}
Mock.Color3.fromRGB = function(r, g, b) return Mock.Color3.new(r / 255, g / 255, b / 255) end
Mock.Vector2 = { new = function(x, y) return { X = x, Y = y } end }
Mock.UDim2 = { new = function(...) return { ... } end, fromScale = function(x, y) return { x, 0, y, 0 } end, fromOffset = function(x, y) return { 0, x, 0, y } end }
-- Enum.Anything.Item -> "Anything.Item" (compared by identity in RigBuilder).
Mock.Enum = setmetatable({}, { __index = function(_, group)
	return setmetatable({}, { __index = function(_, item) return group .. "." .. item end })
end })

-- ===================================================================== Instances
local BASEPARTS = { Part = true, WedgePart = true, MeshPart = true }
local Inst = {}
local instances = {}
local function newInstance(className)
	local self = { ClassName = className, Name = className, _children = {}, _attributes = {}, _parent = nil }
	if BASEPARTS[className] then
		self.Size, self.CFrame, self.Color = vec(1, 1, 1), Mock.CFrame.identity, Mock.Color3.new(0.6, 0.6, 0.6)
		self.Transparency, self.Shape = 0, "PartType.Block"
	end
	table.insert(instances, self)
	return setmetatable(self, Inst)
end
function Inst.__index(t, k)
	if k == "Parent" then return rawget(t, "_parent") end
	local method = rawget(Inst, k)
	if method then return method end
	for _, c in rawget(t, "_children") do
		if c.Name == k then return c end
	end
	return nil
end
function Inst.__newindex(t, k, v)
	if k == "Parent" then
		local old = rawget(t, "_parent")
		if old then
			local list = rawget(old, "_children")
			local i = table.find(list, t)
			if i then table.remove(list, i) end
		end
		rawset(t, "_parent", v)
		if v then table.insert(rawget(v, "_children"), t) end
		return
	end
	rawset(t, k, v)
end
function Inst.IsA(t, class)
	if class == "BasePart" then return BASEPARTS[t.ClassName] == true end
	if class == "Instance" then return true end
	return t.ClassName == class
end
function Inst.FindFirstChild(t, name, recursive)
	for _, c in rawget(t, "_children") do
		if c.Name == name then return c end
	end
	if recursive then
		for _, c in rawget(t, "_children") do
			local f = c:FindFirstChild(name, true)
			if f then return f end
		end
	end
	return nil
end
function Inst.FindFirstChildOfClass(t, class)
	for _, c in rawget(t, "_children") do
		if c.ClassName == class then return c end
	end
	return nil
end
function Inst.FindFirstChildWhichIsA(t, class)
	for _, c in rawget(t, "_children") do
		if c:IsA(class) then return c end
	end
	return nil
end
function Inst.WaitForChild(t, name)
	return t:FindFirstChild(name) or error("WaitForChild: no " .. name)
end
function Inst.GetChildren(t)
	return table.clone(rawget(t, "_children"))
end
function Inst.GetDescendants(t)
	local out = {}
	local function walk(n)
		for _, c in rawget(n, "_children") do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(t)
	return out
end
function Inst.SetAttribute(t, k, v) rawget(t, "_attributes")[k] = v end
function Inst.GetAttribute(t, k) return rawget(t, "_attributes")[k] end
function Inst.Destroy(t) t.Parent = nil; rawset(t, "_destroyed", true) end
function Inst.GetScale() return 1 end
function Inst.ScaleTo() end
function Inst.Clone(t)
	local c = newInstance(t.ClassName)
	for k, v in t do
		if k ~= "_children" and k ~= "_parent" and k ~= "_attributes" then rawset(c, k, v) end
	end
	for _, child in rawget(t, "_children") do child:Clone().Parent = c end
	return c
end
function Inst.GetPivot(t)
	return t.PrimaryPart and t.PrimaryPart.CFrame or Mock.CFrame.identity
end

Mock.Instance = { new = function(className, parent)
	local i = newInstance(className)
	if parent then i.Parent = parent end
	return i
end }

-- game with a few services; ReplicatedStorage.Shared exists (the modules are inlined by
-- tools/rigcheck.py).
local game = newInstance("DataModel")
local replicated = newInstance("ReplicatedStorage")
replicated.Name, replicated.Parent = "ReplicatedStorage", game
local shared = newInstance("Folder")
shared.Name, shared.Parent = "Shared", replicated
local players = newInstance("Players")
players.Name, players.Parent = "Players", game
function game.GetService(_, name)
	return game:FindFirstChild(name) or (function()
		local s = newInstance(name)
		s.Name, s.Parent = name, game
		return s
	end)()
end
Mock.game = game
Mock.workspace = newInstance("Workspace")

-- typeof() of the stand-in values ("CFrame", "Vector3", "Instance", or Luau's own).
function Mock.typeof(x)
	local mt = getmetatable(x)
	if mt == CF then return "CFrame" elseif mt == V3 then return "Vector3" elseif mt == Inst then return "Instance" end
	return typeof(x)
end

-- Every BasePart under `model`, with its world frame.
function Mock.parts(model)
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then table.insert(out, d) end
	end
	return out
end

return Mock
