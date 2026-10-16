--[[
	A strict stand-in for the Roblox engine, checked against the real API (tools/RobloxApi.luau,
	written from Roblox's own API dump by tools/vfxrun.py). Made to run the client's effect code
	offline (tools/vfxrun.py runs Wilhem's VFX pack through it) and to fail where Roblox fails:

	- a class that does not exist or cannot be created (Instance.new);
	- a property, method or event that does not exist, a property read only or locked to
	  scripts, a value of the wrong type (Roblox's "Unable to assign property");
	- an Enum or an Enum item that does not exist;
	- a NumberSequence / ColorSequence that does not start at 0 and end at 1, a NumberRange
	  upside down, a bad hex colour;
	- a destroyed instance given a parent again.

	Time is simulated (os.clock, task.wait / delay / spawn, RunService's events, tweens) so the
	effects play out frame by frame. Nothing is drawn: this only proves the code runs.
	Errors (thrown, or raised inside a frame, a signal, a delayed function) and warnings are
	collected in env.errors and env.warns.
]]
return function(API)
	local env = { errors = {}, warns = {}, clock = 0, label = "" }
	local nativeTypeof = typeof
	local kinds = setmetatable({}, { __mode = "k" }) -- (fake datatype value -> its Roblox type)

	local function fail(msg, level)
		error(msg, (level or 1) + 1)
	end
	local function typeOf(v)
		local k = type(v) == "table" and kinds[v]
		if k then return k end
		return nativeTypeof(v)
	end
	env.typeof = typeOf
	local function record(kind, msg)
		table.insert(env.errors, { label = env.label, kind = kind, msg = tostring(msg) })
	end
	env.record = record
	local function num(v, what)
		if v == nil then return 0 end
		if type(v) ~= "number" then fail(("invalid argument (%s): number expected, got %s"):format(what, typeOf(v)), 3) end
		return v
	end

	-- ================================================================= Vector3
	local V3 = {}
	local function vec(x, y, z)
		local v = setmetatable({ X = x, Y = y, Z = z }, V3)
		kinds[v] = "Vector3"
		return v
	end
	local function isV3(v) return kinds[v] == "Vector3" end
	V3.__add = function(a, b)
		if not (isV3(a) and isV3(b)) then fail("attempt to perform arithmetic (add) on Vector3 and " .. typeOf(if isV3(a) then b else a), 2) end
		return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
	end
	V3.__sub = function(a, b)
		if not (isV3(a) and isV3(b)) then fail("attempt to perform arithmetic (sub) on Vector3 and " .. typeOf(if isV3(a) then b else a), 2) end
		return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
	end
	V3.__mul = function(a, b)
		if type(a) == "number" and isV3(b) then return vec(b.X * a, b.Y * a, b.Z * a) end
		if isV3(a) and type(b) == "number" then return vec(a.X * b, a.Y * b, a.Z * b) end
		if isV3(a) and isV3(b) then return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z) end
		fail("attempt to perform arithmetic (mul) on " .. typeOf(a) .. " and " .. typeOf(b), 2)
	end
	V3.__div = function(a, b)
		if isV3(a) and type(b) == "number" then return vec(a.X / b, a.Y / b, a.Z / b) end
		if isV3(a) and isV3(b) then return vec(a.X / b.X, a.Y / b.Y, a.Z / b.Z) end
		fail("attempt to perform arithmetic (div) on " .. typeOf(a) .. " and " .. typeOf(b), 2)
	end
	V3.__unm = function(a) return vec(-a.X, -a.Y, -a.Z) end
	V3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
	V3.__tostring = function(a) return ("%g, %g, %g"):format(a.X, a.Y, a.Z) end
	local V3m = {}
	function V3m.Dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
	function V3m.Cross(a, b) return vec(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
	function V3m.Lerp(a, b, t) return a + (b - a) * num(t, "alpha") end
	function V3m.Abs(a) return vec(math.abs(a.X), math.abs(a.Y), math.abs(a.Z)) end
	function V3m.Min(a, b) return vec(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z)) end
	function V3m.Max(a, b) return vec(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z)) end
	function V3m.Floor(a) return vec(math.floor(a.X), math.floor(a.Y), math.floor(a.Z)) end
	function V3m.Ceil(a) return vec(math.ceil(a.X), math.ceil(a.Y), math.ceil(a.Z)) end
	function V3m.FuzzyEq(a, b, e) return (a - b).Magnitude <= (e or 1e-5) end
	function V3m.Angle(a, b)
		local d = a.Magnitude * b.Magnitude
		return if d == 0 then 0 else math.acos(math.clamp(V3m.Dot(a, b) / d, -1, 1))
	end
	V3.__index = function(t, k)
		if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) end
		if k == "Unit" then
			local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
			return if m == 0 then vec(0 / 0, 0 / 0, 0 / 0) else vec(t.X / m, t.Y / m, t.Z / m)
		end
		local f = V3m[k]
		if f then return f end
		fail(tostring(k) .. " is not a valid member of Vector3", 2)
	end
	V3.__newindex = function(_, k) fail(tostring(k) .. " cannot be assigned to", 2) end
	env.Vector3 = {
		new = function(x, y, z) return vec(num(x, "x"), num(y, "y"), num(z, "z")) end,
		zero = vec(0, 0, 0), one = vec(1, 1, 1), xAxis = vec(1, 0, 0), yAxis = vec(0, 1, 0), zAxis = vec(0, 0, 1),
	}

	-- ================================================================= Vector2
	local V2 = {}
	local function vec2(x, y)
		local v = setmetatable({ X = x, Y = y }, V2)
		kinds[v] = "Vector2"
		return v
	end
	V2.__add = function(a, b) return vec2(a.X + b.X, a.Y + b.Y) end
	V2.__sub = function(a, b) return vec2(a.X - b.X, a.Y - b.Y) end
	V2.__mul = function(a, b)
		if type(a) == "number" then return vec2(b.X * a, b.Y * a) end
		if type(b) == "number" then return vec2(a.X * b, a.Y * b) end
		return vec2(a.X * b.X, a.Y * b.Y)
	end
	V2.__div = function(a, b)
		if type(b) == "number" then return vec2(a.X / b, a.Y / b) end
		return vec2(a.X / b.X, a.Y / b.Y)
	end
	V2.__unm = function(a) return vec2(-a.X, -a.Y) end
	V2.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
	V2.__index = function(t, k)
		if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y) end
		if k == "Unit" then
			local m = math.sqrt(t.X * t.X + t.Y * t.Y)
			return vec2(t.X / m, t.Y / m)
		end
		if k == "Dot" then return function(a, b) return a.X * b.X + a.Y * b.Y end end
		if k == "Lerp" then return function(a, b, s) return a + (b - a) * s end end
		fail(tostring(k) .. " is not a valid member of Vector2", 2)
	end
	env.Vector2 = {
		new = function(x, y) return vec2(num(x, "x"), num(y, "y")) end,
		zero = vec2(0, 0), one = vec2(1, 1), xAxis = vec2(1, 0), yAxis = vec2(0, 1),
	}

	-- ================================================================= CFrame
	-- r: row-major 3x3 rotation { r00, r01, r02, r10, ... }; p: position.
	local CF = {}
	local function cf(p, r)
		local c = setmetatable({ p = p, r = r }, CF)
		kinds[c] = "CFrame"
		return c
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
	local function rx(a) local c, s = math.cos(a), math.sin(a) return { 1, 0, 0, 0, c, -s, 0, s, c } end
	local function ry(a) local c, s = math.cos(a), math.sin(a) return { c, 0, s, 0, 1, 0, -s, 0, c } end
	local function rz(a) local c, s = math.cos(a), math.sin(a) return { c, -s, 0, s, c, 0, 0, 0, 1 } end
	local function lookAt(at, target, up)
		up = up or vec(0, 1, 0)
		local f = target - at
		if f.Magnitude < 1e-9 then return cf(at, IDENT) end
		f = f.Unit
		local right = V3m.Cross(f, up)
		if right.Magnitude < 1e-6 then
			right = V3m.Cross(f, vec(0, 0, if f.Y > 0 then 1 else -1))
		end
		right = right.Unit
		local u = V3m.Cross(right, f).Unit
		local b = -f
		return cf(at, { right.X, u.X, b.X, right.Y, u.Y, b.Y, right.Z, u.Z, b.Z })
	end
	CF.__mul = function(a, b)
		if kinds[a] ~= "CFrame" then fail("attempt to perform arithmetic (mul) on " .. typeOf(a) .. " and CFrame", 2) end
		if kinds[b] == "CFrame" then return cf(a.p + rapply(a.r, b.p), rmul(a.r, b.r)) end
		if kinds[b] == "Vector3" then return a.p + rapply(a.r, b) end
		fail("attempt to perform arithmetic (mul) on CFrame and " .. typeOf(b), 2)
	end
	CF.__add = function(a, b)
		if kinds[b] ~= "Vector3" then fail("attempt to perform arithmetic (add) on CFrame and " .. typeOf(b), 2) end
		return cf(a.p + b, a.r)
	end
	CF.__sub = function(a, b)
		if kinds[b] ~= "Vector3" then fail("attempt to perform arithmetic (sub) on CFrame and " .. typeOf(b), 2) end
		return cf(a.p - b, a.r)
	end
	CF.__eq = function(a, b)
		for i = 1, 9 do if a.r[i] ~= b.r[i] then return false end end
		return a.p == b.p
	end
	local CFm = {}
	function CFm.Inverse(t)
		local rt = rtrans(t.r)
		return cf(-rapply(rt, t.p), rt)
	end
	function CFm.ToObjectSpace(t, o) return CFm.Inverse(t) * o end
	function CFm.ToWorldSpace(t, o) return t * o end
	function CFm.PointToWorldSpace(t, v) return t * v end
	function CFm.PointToObjectSpace(t, v) return CFm.Inverse(t) * v end
	function CFm.VectorToWorldSpace(t, v) return rapply(t.r, v) end
	function CFm.VectorToObjectSpace(t, v) return rapply(rtrans(t.r), v) end
	function CFm.Lerp(a, b, s)
		s = num(s, "alpha")
		local r = {}
		for i = 1, 9 do r[i] = a.r[i] + (b.r[i] - a.r[i]) * s end
		-- (re-orthonormalised: a stand-in for the real slerp)
		local x = vec(r[1], r[4], r[7]).Unit
		local y = vec(r[2], r[5], r[8])
		local z = V3m.Cross(x, y).Unit
		y = V3m.Cross(z, x).Unit
		return cf(a.p:Lerp(b.p, s), { x.X, y.X, z.X, x.Y, y.Y, z.Y, x.Z, y.Z, z.Z })
	end
	function CFm.GetComponents(t)
		local r = t.r
		return t.p.X, t.p.Y, t.p.Z, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9]
	end
	CFm.components = CFm.GetComponents
	function CFm.ToEulerAnglesXYZ(t)
		local r = t.r
		local y = math.asin(math.clamp(r[3], -1, 1))
		return math.atan2(-r[6], r[9]), y, math.atan2(-r[2], r[1])
	end
	function CFm.ToOrientation(t)
		local r = t.r
		local x = math.asin(math.clamp(-r[6], -1, 1))
		return x, math.atan2(r[3], r[9]), math.atan2(r[4], r[5])
	end
	CFm.ToEulerAnglesYXZ = CFm.ToOrientation
	function CFm.ToAxisAngle(t)
		local r = t.r
		local angle = math.acos(math.clamp((r[1] + r[5] + r[9] - 1) / 2, -1, 1))
		local axis = vec(r[8] - r[6], r[3] - r[7], r[4] - r[2])
		return if axis.Magnitude > 1e-9 then axis.Unit else vec(1, 0, 0), angle
	end
	function CFm.Orthonormalize(t) return t end
	function CFm.FuzzyEq(a, b, e) return (a.p - b.p).Magnitude <= (e or 1e-5) end
	CF.__index = function(t, k)
		if k == "Position" or k == "p" then return t.p end
		if k == "X" then return t.p.X elseif k == "Y" then return t.p.Y elseif k == "Z" then return t.p.Z end
		if k == "LookVector" then return vec(-t.r[3], -t.r[6], -t.r[9]) end
		if k == "RightVector" or k == "XVector" then return vec(t.r[1], t.r[4], t.r[7]) end
		if k == "UpVector" or k == "YVector" then return vec(t.r[2], t.r[5], t.r[8]) end
		if k == "ZVector" then return vec(t.r[3], t.r[6], t.r[9]) end
		if k == "Rotation" then return cf(vec(0, 0, 0), t.r) end
		local f = CFm[k]
		if f then return f end
		fail(tostring(k) .. " is not a valid member of CFrame", 2)
	end
	CF.__newindex = function(_, k) fail(tostring(k) .. " cannot be assigned to", 2) end
	CF.__tostring = function(t) return ("%g, %g, %g, ..."):format(t.p.X, t.p.Y, t.p.Z) end
	local function quat(x, y, z, w)
		local n = math.sqrt(x * x + y * y + z * z + w * w)
		x, y, z, w = x / n, y / n, z / n, w / n
		return {
			1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w),
			2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w),
			2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y),
		}
	end
	local function axisAngle(axis, a)
		local u = axis.Unit
		local s = math.sin(a / 2)
		return quat(u.X * s, u.Y * s, u.Z * s, math.cos(a / 2))
	end
	env.CFrame = {
		new = function(...)
			local n = select("#", ...)
			local a, b, c = ...
			if n == 0 then return cf(vec(0, 0, 0), IDENT) end
			if kinds[a] == "Vector3" then
				if n >= 2 and kinds[b] == "Vector3" then return lookAt(a, b) end
				return cf(a, IDENT)
			end
			if n == 3 then return cf(vec(num(a, "x"), num(b, "y"), num(c, "z")), IDENT) end
			local t = { ... }
			for i, v in t do num(v, "component " .. i) end
			if n == 7 then return cf(vec(t[1], t[2], t[3]), quat(t[4], t[5], t[6], t[7])) end
			if n == 12 then return cf(vec(t[1], t[2], t[3]), { t[4], t[5], t[6], t[7], t[8], t[9], t[10], t[11], t[12] }) end
			fail("Invalid number of arguments: " .. n, 2)
		end,
		lookAt = function(at, target, up)
			if kinds[at] ~= "Vector3" or kinds[target] ~= "Vector3" then fail("CFrame.lookAt: Vector3 expected", 2) end
			return lookAt(at, target, up)
		end,
		Angles = function(x, y, z) return cf(vec(0, 0, 0), rmul(rmul(rx(num(x, "x")), ry(num(y, "y"))), rz(num(z, "z")))) end,
		fromEulerAnglesYXZ = function(x, y, z) return cf(vec(0, 0, 0), rmul(rmul(ry(num(y, "y")), rx(num(x, "x"))), rz(num(z, "z")))) end,
		fromAxisAngle = function(axis, a) return cf(vec(0, 0, 0), axisAngle(axis, num(a, "angle"))) end,
		fromMatrix = function(p, x, y, z)
			z = z or V3m.Cross(x, y).Unit
			return cf(p, { x.X, y.X, z.X, x.Y, y.Y, z.Y, x.Z, y.Z, z.Z })
		end,
		identity = cf(vec(0, 0, 0), IDENT),
	}
	env.CFrame.fromEulerAnglesXYZ = env.CFrame.Angles
	env.CFrame.fromOrientation = env.CFrame.fromEulerAnglesYXZ

	-- ================================================================= Color3
	local C3 = {}
	local function col(r, g, b)
		local c = setmetatable({ R = r, G = g, B = b }, C3)
		kinds[c] = "Color3"
		return c
	end
	C3.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end
	C3.__index = function(t, k)
		if k == "Lerp" then return function(a, b, s) return col(a.R + (b.R - a.R) * s, a.G + (b.G - a.G) * s, a.B + (b.B - a.B) * s) end end
		if k == "ToHex" then
			return function(a)
				local f = function(v) return math.clamp(math.floor(v * 255 + 0.5), 0, 255) end
				return ("%02X%02X%02X"):format(f(a.R), f(a.G), f(a.B))
			end
		end
		if k == "ToHSV" then
			return function(a)
				local mx, mn = math.max(a.R, a.G, a.B), math.min(a.R, a.G, a.B)
				local d = mx - mn
				local h = 0
				if d > 0 then
					if mx == a.R then h = ((a.G - a.B) / d) % 6 elseif mx == a.G then h = (a.B - a.R) / d + 2 else h = (a.R - a.G) / d + 4 end
					h /= 6
				end
				return h, if mx == 0 then 0 else d / mx, mx
			end
		end
		fail(tostring(k) .. " is not a valid member of Color3", 2)
	end
	C3.__newindex = function(_, k) fail(tostring(k) .. " cannot be assigned to", 2) end
	env.Color3 = {
		new = function(r, g, b) return col(num(r, "r"), num(g, "g"), num(b, "b")) end,
		fromRGB = function(r, g, b) return col(num(r, "r") / 255, num(g, "g") / 255, num(b, "b") / 255) end,
		fromHex = function(h)
			if type(h) ~= "string" then fail("Color3.fromHex: string expected", 2) end
			local s = h:gsub("^#", "")
			if not (s:match("^%x%x%x%x%x%x$") or s:match("^%x%x%x$")) then fail("Unable to convert characters to hex value", 2) end
			if #s == 3 then s = s:sub(1, 1):rep(2) .. s:sub(2, 2):rep(2) .. s:sub(3, 3):rep(2) end
			return col(tonumber(s:sub(1, 2), 16) / 255, tonumber(s:sub(3, 4), 16) / 255, tonumber(s:sub(5, 6), 16) / 255)
		end,
		fromHSV = function(h, s, v)
			h, s, v = num(h, "h"), num(s, "s"), num(v, "v")
			local i = math.floor(h * 6)
			local f = h * 6 - i
			local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
			i %= 6
			if i == 0 then return col(v, t, p) elseif i == 1 then return col(q, v, p) elseif i == 2 then return col(p, v, t)
			elseif i == 3 then return col(p, q, v) elseif i == 4 then return col(t, p, v) end
			return col(v, p, q)
		end,
	}

	-- ================================================ sequences, ranges, UDim, TweenInfo...
	local function frozen(kind, t)
		kinds[t] = kind
		return setmetatable(t, {
			__index = function(_, k) fail(tostring(k) .. " is not a valid member of " .. kind, 2) end,
			__newindex = function(_, k) fail(tostring(k) .. " cannot be assigned to", 2) end,
		})
	end
	local function checkKeys(kind, list)
		if #list < 2 then fail(kind .. ": requires at least 2 keypoints", 3) end
		if #list > 20 then fail(kind .. ": a maximum of 20 keypoints is allowed", 3) end
		if list[1].Time ~= 0 or list[#list].Time ~= 1 then fail(kind .. " time must start at 0, and end at 1", 3) end
		for i = 2, #list do
			if list[i].Time < list[i - 1].Time then fail(kind .. ": all keypoints must be ordered by time", 3) end
		end
	end
	env.NumberSequenceKeypoint = {
		new = function(t, v, e)
			t, v = num(t, "time"), num(v, "value")
			return frozen("NumberSequenceKeypoint", { Time = t, Value = v, Envelope = num(e, "envelope") })
		end,
	}
	env.NumberSequence = {
		new = function(a, b)
			local list
			if type(a) == "number" then
				local v1 = if b ~= nil then num(b, "value") else a
				list = { env.NumberSequenceKeypoint.new(0, a), env.NumberSequenceKeypoint.new(1, v1) }
			elseif type(a) == "table" and not kinds[a] then
				for _, k in a do
					if kinds[k] ~= "NumberSequenceKeypoint" then fail("NumberSequence.new: NumberSequenceKeypoint expected, got " .. typeOf(k), 2) end
				end
				list = table.clone(a)
				checkKeys("NumberSequence", list)
			else
				fail("NumberSequence.new: invalid argument (" .. typeOf(a) .. ")", 2)
			end
			return frozen("NumberSequence", { Keypoints = list })
		end,
	}
	env.ColorSequenceKeypoint = {
		new = function(t, c)
			if kinds[c] ~= "Color3" then fail("ColorSequenceKeypoint.new: Color3 expected, got " .. typeOf(c), 2) end
			return frozen("ColorSequenceKeypoint", { Time = num(t, "time"), Value = c })
		end,
	}
	env.ColorSequence = {
		new = function(a, b)
			local list
			if kinds[a] == "Color3" then
				if b ~= nil and kinds[b] ~= "Color3" then fail("ColorSequence.new: Color3 expected, got " .. typeOf(b), 2) end
				list = { env.ColorSequenceKeypoint.new(0, a), env.ColorSequenceKeypoint.new(1, b or a) }
			elseif type(a) == "table" and not kinds[a] then
				for _, k in a do
					if kinds[k] ~= "ColorSequenceKeypoint" then fail("ColorSequence.new: ColorSequenceKeypoint expected, got " .. typeOf(k), 2) end
				end
				list = table.clone(a)
				checkKeys("ColorSequence", list)
			else
				fail("ColorSequence.new: invalid argument (" .. typeOf(a) .. ")", 2)
			end
			return frozen("ColorSequence", { Keypoints = list })
		end,
	}
	env.NumberRange = {
		new = function(a, b)
			a = num(a, "min")
			b = if b == nil then a else num(b, "max")
			if b < a then fail("NumberRange: invalid range", 2) end
			return frozen("NumberRange", { Min = a, Max = b })
		end,
	}
	local UD = {}
	local function udim(s, o)
		local u = setmetatable({ Scale = s, Offset = o }, UD)
		kinds[u] = "UDim"
		return u
	end
	UD.__add = function(a, b) return udim(a.Scale + b.Scale, a.Offset + b.Offset) end
	UD.__sub = function(a, b) return udim(a.Scale - b.Scale, a.Offset - b.Offset) end
	UD.__unm = function(a) return udim(-a.Scale, -a.Offset) end
	UD.__eq = function(a, b) return a.Scale == b.Scale and a.Offset == b.Offset end
	UD.__index = function(_, k) fail(tostring(k) .. " is not a valid member of UDim", 2) end
	env.UDim = { new = function(s, o) return udim(num(s, "scale"), num(o, "offset")) end }
	local U2 = {}
	local function udim2(x, y)
		local u = setmetatable({ X = x, Y = y }, U2)
		kinds[u] = "UDim2"
		return u
	end
	U2.__add = function(a, b) return udim2(a.X + b.X, a.Y + b.Y) end
	U2.__sub = function(a, b) return udim2(a.X - b.X, a.Y - b.Y) end
	U2.__unm = function(a) return udim2(-a.X, -a.Y) end
	U2.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
	U2.__index = function(t, k)
		if k == "Width" then return t.X elseif k == "Height" then return t.Y end
		if k == "Lerp" then
			return function(a, b, s)
				return udim2(udim(a.X.Scale + (b.X.Scale - a.X.Scale) * s, a.X.Offset + (b.X.Offset - a.X.Offset) * s),
					udim(a.Y.Scale + (b.Y.Scale - a.Y.Scale) * s, a.Y.Offset + (b.Y.Offset - a.Y.Offset) * s))
			end
		end
		fail(tostring(k) .. " is not a valid member of UDim2", 2)
	end
	env.UDim2 = {
		new = function(a, b, c, d)
			if kinds[a] == "UDim" then return udim2(a, b) end
			return udim2(udim(num(a, "xs"), num(b, "xo")), udim(num(c, "ys"), num(d, "yo")))
		end,
		fromScale = function(x, y) return udim2(udim(num(x, "x"), 0), udim(num(y, "y"), 0)) end,
		fromOffset = function(x, y) return udim2(udim(0, num(x, "x")), udim(0, num(y, "y"))) end,
	}
	env.Rect = {
		new = function(a, b, c, d)
			if kinds[a] == "Vector2" then return frozen("Rect", { Min = a, Max = b }) end
			return frozen("Rect", { Min = vec2(num(a, "x0"), num(b, "y0")), Max = vec2(num(c, "x1"), num(d, "y1")) })
		end,
	}

	-- ================================================================= Enum
	local enumTypes = {}
	local function enumItem(enumName, name, value)
		local item = { Name = name, Value = value }
		kinds[item] = "EnumItem"
		return setmetatable(item, {
			__index = function(_, k)
				if k == "EnumType" then return enumTypes[enumName] end
				fail(tostring(k) .. " is not a valid member of \"Enum." .. enumName .. "." .. name .. "\"", 2)
			end,
			__newindex = function(_, k) fail(tostring(k) .. " cannot be assigned to", 2) end,
			__tostring = function() return "Enum." .. enumName .. "." .. name end,
		})
	end
	for enumName, items in API.enums do
		local list, byName, byValue = {}, {}, {}
		for name, value in items do
			local item = enumItem(enumName, name, value)
			byName[name], byValue[value] = item, byValue[value] or item
			table.insert(list, item)
		end
		table.sort(list, function(a, b) return a.Value < b.Value end)
		local et = {}
		kinds[et] = "Enum"
		enumTypes[enumName] = setmetatable(et, {
			__index = function(_, k)
				if k == "GetEnumItems" then return function() return table.clone(list) end end
				if k == "FromName" then return function(_, n) return byName[n] end end
				if k == "FromValue" then return function(_, v) return byValue[v] end end
				local item = byName[k]
				if item == nil then fail(tostring(k) .. " is not a valid member of \"Enum." .. enumName .. "\"", 2) end
				return item
			end,
			__newindex = function(_, k) fail(tostring(k) .. " cannot be assigned to", 2) end,
			__tostring = function() return enumName end,
			byName = byName, byValue = byValue,
		})
	end
	env.Enum = setmetatable({}, {
		__index = function(_, k)
			local et = enumTypes[k]
			if et == nil then fail(tostring(k) .. " is not a valid member of \"Enums\"", 2) end
			return et
		end,
	})
	local function enumOf(enumName, v)
		local et = enumTypes[enumName]
		if not et then return nil end
		local meta = getmetatable(et)
		if kinds[v] == "EnumItem" then
			return if meta.byName[v.Name] == v then v else nil
		elseif type(v) == "number" then
			return meta.byValue[v]
		elseif type(v) == "string" then
			return meta.byName[v]
		end
		return nil
	end

	-- ================================================================= time and threads
	local queue = {} -- { at, co, args }
	local function resume(co, ...)
		local ok, err = coroutine.resume(co, ...)
		if not ok then record("error", debug.traceback(co, tostring(err))) end
	end
	local function schedule(at, co, ...)
		table.insert(queue, { at = at, co = co, args = table.pack(...) })
	end
	local task = {}
	function task.spawn(f, ...)
		local co = if type(f) == "thread" then f else coroutine.create(f)
		resume(co, ...)
		return co
	end
	function task.defer(f, ...)
		local co = if type(f) == "thread" then f else coroutine.create(f)
		schedule(env.clock, co, ...)
		return co
	end
	function task.delay(t, f, ...)
		local co = if type(f) == "thread" then f else coroutine.create(f)
		schedule(env.clock + math.max(0, num(t, "duration")), co, ...)
		return co
	end
	function task.wait(t)
		if not coroutine.isyieldable() then fail("attempt to yield across metamethod/C-call boundary", 2) end
		local start = env.clock
		schedule(start + math.max(num(t, "duration"), 1 / 60), coroutine.running())
		coroutine.yield()
		return env.clock - start
	end
	function task.cancel(co)
		for i = #queue, 1, -1 do
			if queue[i].co == co then table.remove(queue, i) end
		end
	end
	function task.synchronize() end
	function task.desynchronize() end
	env.task = task
	env.wait = task.wait
	env.delay = task.delay
	env.spawn = task.spawn
	env.os = setmetatable({ clock = function() return env.clock end, time = function() return 1.7e9 + env.clock end },
		{ __index = os })
	env.tick = function() return 1.7e9 + env.clock end
	env.time = function() return env.clock end
	env.warn = function(...)
		local parts = {}
		for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
		table.insert(env.warns, { label = env.label, msg = table.concat(parts, " ") })
	end
	env.print = function() end

	-- ================================================================= signals
	local function signal(name)
		local s = { handlers = {}, name = name }
		local api = {}
		kinds[api] = "RBXScriptSignal"
		local function connect(fn, once)
			if type(fn) ~= "function" then fail("Attempt to connect failed: Passed value is not a function", 3) end
			local conn = { Connected = true }
			kinds[conn] = "RBXScriptConnection"
			local h = { fn = fn, conn = conn, once = once }
			function conn.Disconnect()
				conn.Connected = false
				local i = table.find(s.handlers, h)
				if i then table.remove(s.handlers, i) end
			end
			table.insert(s.handlers, h)
			return conn
		end
		api.Connect = function(_, fn) return connect(fn) end
		api.ConnectParallel = api.Connect
		api.Once = function(_, fn) return connect(fn, true) end
		api.Wait = function()
			local co = coroutine.running()
			connect(function(...) task.spawn(co, ...) end, true)
			return coroutine.yield()
		end
		s.api = api
		function s.fire(...)
			for _, h in table.clone(s.handlers) do
				if h.conn.Connected then
					if h.once then h.conn.Disconnect() end
					task.spawn(h.fn, ...)
				end
			end
		end
		function s.clear()
			for _, h in table.clone(s.handlers) do h.conn.Disconnect() end
		end
		return s
	end

	-- ================================================================= instances
	local classes = API.classes
	local function member(class, key)
		local c = classes[class]
		while c do
			local m = c.members[key]
			if m then return m end
			c = c.super and classes[c.super]
		end
		return nil
	end
	local function isA(class, name)
		local c = class
		while c do
			if c == name then return true end
			c = classes[c] and classes[c].super
		end
		return false
	end
	local ST = setmetatable({}, { __mode = "k" }) -- instance -> state
	local Inst = {}
	local function fullName(st)
		local parts = {}
		while st do
			table.insert(parts, 1, st.name)
			st = st.parent and ST[st.parent]
		end
		return table.concat(parts, ".")
	end
	local function isInstance(v) return type(v) == "table" and ST[v] ~= nil end

	local function parseDefault(m)
		local d, t = m.default, m.t
		if m.cat == "Enum" then
			local et = enumTypes[t]
			if et and d then
				local meta = getmetatable(et)
				return meta.byName[d] or meta.byValue[tonumber(d)] or (et:GetEnumItems())[1]
			end
			return et and (et:GetEnumItems())[1]
		elseif m.cat == "Class" then
			return nil
		elseif t == "bool" then
			return d == "true"
		elseif t == "float" or t == "double" or t == "int" or t == "int64" then
			return tonumber(d) or 0
		elseif t == "string" or t == "Content" or t == "ContentId" then
			return d or ""
		end
		local nums = {}
		for n in (d or ""):gmatch("[-%d%.eE+]+") do table.insert(nums, tonumber(n) or 0) end
		if t == "Vector3" then return vec(nums[1] or 0, nums[2] or 0, nums[3] or 0)
		elseif t == "Vector2" then return vec2(nums[1] or 0, nums[2] or 0)
		elseif t == "CFrame" then return env.CFrame.identity
		elseif t == "Color3" then
			if #nums >= 3 then
				local scale = if nums[1] > 1 or nums[2] > 1 or nums[3] > 1 then 255 else 1
				return col(nums[1] / scale, nums[2] / scale, nums[3] / scale)
			end
			return col(1, 1, 1)
		elseif t == "NumberSequence" then return env.NumberSequence.new(nums[2] or 0)
		elseif t == "ColorSequence" then return env.ColorSequence.new(col(1, 1, 1))
		elseif t == "NumberRange" then return env.NumberRange.new(nums[1] or 0, math.max(nums[1] or 0, nums[2] or nums[1] or 0))
		elseif t == "UDim2" then return udim2(udim(nums[1] or 0, nums[2] or 0), udim(nums[3] or 0, nums[4] or 0))
		elseif t == "UDim" then return udim(nums[1] or 0, nums[2] or 0)
		end
		return nil
	end

	local function checkValue(st, key, m, value)
		local t, cat = m.t, m.cat
		local function wrong()
			fail(("Unable to assign property %s. %s expected, got %s"):format(key, t, typeOf(value)), 4)
		end
		if cat == "Enum" then
			local item = enumOf(t, value)
			if item == nil then
				fail(("Unable to assign property %s. %s expected, got %s"):format(key, "EnumItem of Enum." .. t,
					if kinds[value] == "EnumItem" then tostring(value) else typeOf(value)), 4)
			end
			return item
		elseif cat == "Class" then
			if value == nil then return nil end
			if not isInstance(value) or not isA(ST[value].class, t) then wrong() end
			return value
		elseif t == "bool" then
			if type(value) ~= "boolean" then wrong() end
		elseif t == "float" or t == "double" or t == "int" or t == "int64" then
			if type(value) ~= "number" then wrong() end
			if value ~= value then fail(("Unable to assign property %s: NaN"):format(key), 4) end
			if t == "int" or t == "int64" then value = math.floor(value) end
		elseif t == "string" or t == "Content" or t == "ContentId" then
			if type(value) == "number" then value = tostring(value) end
			if type(value) ~= "string" then wrong() end
		else
			if typeOf(value) ~= t then wrong() end
		end
		return value
	end

	local newInstance
	local special = {} -- methods with a behaviour (the others exist and return nothing)

	local function setParent(obj, st, value)
		if value ~= nil and not isInstance(value) then
			fail("Unable to assign property Parent. Instance expected, got " .. typeOf(value), 3)
		end
		if st.locked then
			fail(("The Parent property of %s is locked, current parent: NULL, new parent %s"):format(st.name,
				if value then ST[value].name else "NULL"), 3)
		end
		local p = value
		while p do
			if p == obj then fail("Attempt to set parent of " .. st.name .. " to " .. ST[value].name .. " would result in circular reference", 3) end
			p = ST[p].parent
		end
		if st.parent == value then return end
		if st.parent then
			local siblings = ST[st.parent].children
			local i = table.find(siblings, obj)
			if i then table.remove(siblings, i) end
		end
		st.parent = value
		if value then table.insert(ST[value].children, obj) end
	end

	local function worldCF(obj)
		local st = ST[obj]
		if isA(st.class, "BasePart") or st.class == "Camera" then
			return st.props.CFrame or env.CFrame.identity
		elseif st.class == "Attachment" then
			local local_ = st.props.CFrame or env.CFrame.identity
			local parent = st.parent
			if parent and (isA(ST[parent].class, "BasePart")) then return worldCF(parent) * local_ end
			return local_
		end
		return env.CFrame.identity
	end

	Inst.__index = function(obj, key)
		local st = ST[obj]
		if key == "Parent" then return st.parent end
		if key == "Name" then return st.name end
		if key == "ClassName" then return st.class end
		local m = member(st.class, key)
		if m then
			if m.kind == "Property" then
				if m.noread then fail(("The current thread cannot read '%s'"):format(key), 2) end
				-- (the few properties computed from others)
				if key == "Position" and (isA(st.class, "BasePart") or st.class == "Attachment") then
					return (st.props.CFrame or env.CFrame.identity).Position
				end
				if st.class == "Attachment" and (key == "WorldPosition" or key == "WorldCFrame") then
					local w = worldCF(obj)
					return if key == "WorldPosition" then w.Position else w
				end
				if key == "AssemblyLinearVelocity" then return st.props[key] or vec(0, 0, 0) end
				local v = st.props[key]
				if v == nil and not st.set[key] then
					v = parseDefault(m)
				end
				return v
			elseif m.kind == "Function" then
				return special[key] or function(self)
					if self ~= obj then fail(("Expected ':' not '.' calling member function %s"):format(key), 2) end
					return nil
				end
			elseif m.kind == "Event" then
				st.signals[key] = st.signals[key] or signal(key)
				return st.signals[key].api
			end
			return nil
		end
		for _, child in st.children do
			if ST[child].name == key then return child end
		end
		fail(("%s is not a valid member of %s \"%s\""):format(tostring(key), st.class, fullName(st)), 2)
	end
	Inst.__newindex = function(obj, key, value)
		local st = ST[obj]
		if key == "Parent" then return setParent(obj, st, value) end
		if key == "Name" then
			if type(value) ~= "string" then fail("Unable to assign property Name. string expected, got " .. typeOf(value), 2) end
			st.name = value
			return
		end
		local m = member(st.class, key)
		if not m or m.kind ~= "Property" then
			fail(("%s is not a valid member of %s \"%s\""):format(tostring(key), st.class, fullName(st)), 2)
		end
		if m.readonly then fail(("Unable to assign property %s. Property is read only"):format(key), 2) end
		if m.nowrite then fail(("The current thread cannot write '%s' (lacking capability)"):format(key), 2) end
		value = checkValue(st, key, m, value)
		if key == "Position" and (isA(st.class, "BasePart") or st.class == "Attachment") then
			local c = st.props.CFrame or env.CFrame.identity
			st.props.CFrame = cf(value, c.r)
		elseif st.class == "Attachment" and (key == "WorldPosition" or key == "WorldCFrame") then
			local parent = st.parent
			local base = if parent and isA(ST[parent].class, "BasePart") then worldCF(parent) else env.CFrame.identity
			local w = if key == "WorldPosition" then cf(value, worldCF(obj).r) else value
			st.props.CFrame = base:Inverse() * w
		else
			st.props[key] = value
			st.set[key] = true
		end
		local sig = st.signals["Changed"]
		if sig then sig.fire(key) end
		local ps = st.propSignals and st.propSignals[key]
		if ps then ps.fire() end
	end
	Inst.__tostring = function(obj) return ST[obj].name end

	function newInstance(class, internal)
		local c = classes[class]
		if not c then fail(('Unable to create an Instance of type "%s"'):format(tostring(class)), 3) end
		if not internal and (c.notCreatable or c.service) then
			fail(('Unable to create an Instance of type "%s"'):format(class), 3)
		end
		local obj = setmetatable({}, Inst)
		kinds[obj] = "Instance"
		ST[obj] = { class = class, name = class, props = {}, set = {}, children = {}, attrs = {}, signals = {} }
		return obj
	end
	env.Instance = {
		new = function(class, parent)
			local obj = newInstance(class)
			if parent ~= nil then obj.Parent = parent end
			return obj
		end,
	}
	env.newInstance = function(class, props, parent)
		local obj = newInstance(class, true)
		for k, v in props or {} do
			local m = member(class, k)
			if k == "Name" then ST[obj].name = v
			elseif m and m.kind == "Property" then ST[obj].props[k] = v ST[obj].set[k] = true
			else ST[obj].props[k] = v end
		end
		if parent then setParent(obj, ST[obj], parent) end
		return obj
	end
	env.state = function(obj) return ST[obj] end
	env.isA = isA

	local function self_(obj, name)
		if not isInstance(obj) then fail(("Expected ':' not '.' calling member function %s"):format(name), 3) end
		return ST[obj]
	end
	local function descendants(obj, out)
		for _, child in ST[obj].children do
			table.insert(out, child)
			descendants(child, out)
		end
		return out
	end
	function special.GetChildren(obj) return table.clone(self_(obj, "GetChildren").children) end
	function special.GetDescendants(obj) self_(obj, "GetDescendants") return descendants(obj, {}) end
	function special.FindFirstChild(obj, name, recursive)
		local st = self_(obj, "FindFirstChild")
		if type(name) ~= "string" then fail("Argument 1 missing or nil", 2) end
		for _, child in (if recursive then descendants(obj, {}) else st.children) do
			if ST[child].name == name then return child end
		end
		return nil
	end
	function special.WaitForChild(obj, name, timeout)
		local found = special.FindFirstChild(obj, name)
		if found then return found end
		if timeout == nil then
			record("error", ("WaitForChild(\"%s\") on %s would wait forever"):format(name, fullName(ST[obj])))
		end
		return nil
	end
	function special.FindFirstChildOfClass(obj, class)
		for _, child in self_(obj, "FindFirstChildOfClass").children do
			if ST[child].class == class then return child end
		end
		return nil
	end
	function special.FindFirstChildWhichIsA(obj, class, recursive)
		for _, child in (if recursive then descendants(obj, {}) else self_(obj, "FindFirstChildWhichIsA").children) do
			if isA(ST[child].class, class) then return child end
		end
		return nil
	end
	function special.FindFirstAncestorOfClass(obj, class)
		local p = self_(obj, "FindFirstAncestorOfClass").parent
		while p do
			if ST[p].class == class then return p end
			p = ST[p].parent
		end
		return nil
	end
	function special.FindFirstAncestorWhichIsA(obj, class)
		local p = self_(obj, "FindFirstAncestorWhichIsA").parent
		while p do
			if isA(ST[p].class, class) then return p end
			p = ST[p].parent
		end
		return nil
	end
	function special.FindFirstAncestor(obj, name)
		local p = self_(obj, "FindFirstAncestor").parent
		while p do
			if ST[p].name == name then return p end
			p = ST[p].parent
		end
		return nil
	end
	function special.IsA(obj, class)
		if type(class) ~= "string" then fail("Argument 1 missing or nil", 2) end
		if not classes[class] then return false end
		return isA(self_(obj, "IsA").class, class)
	end
	function special.IsDescendantOf(obj, other)
		local p = self_(obj, "IsDescendantOf").parent
		while p do
			if p == other then return true end
			p = ST[p].parent
		end
		return false
	end
	function special.IsAncestorOf(obj, other) return special.IsDescendantOf(other, obj) end
	function special.GetFullName(obj) return fullName(self_(obj, "GetFullName")) end
	function special.GetAttribute(obj, name) return self_(obj, "GetAttribute").attrs[name] end
	function special.SetAttribute(obj, name, value) self_(obj, "SetAttribute").attrs[name] = value end
	function special.GetAttributes(obj) return table.clone(self_(obj, "GetAttributes").attrs) end
	function special.AddTag(obj, tag) local st = self_(obj, "AddTag") st.tags = st.tags or {} st.tags[tag] = true end
	function special.HasTag(obj, tag) local st = self_(obj, "HasTag") return st.tags ~= nil and st.tags[tag] == true end
	function special.RemoveTag(obj, tag) local st = self_(obj, "RemoveTag") if st.tags then st.tags[tag] = nil end end
	function special.GetPropertyChangedSignal(obj, prop)
		local st = self_(obj, "GetPropertyChangedSignal")
		local m = member(st.class, prop)
		if not (m and m.kind == "Property") and prop ~= "Parent" and prop ~= "Name" then
			fail(prop .. " is not a valid property name.", 2)
		end
		st.propSignals = st.propSignals or {}
		st.propSignals[prop] = st.propSignals[prop] or signal(prop)
		return st.propSignals[prop].api
	end
	local function destroy(obj)
		local st = ST[obj]
		if st.destroyed then return end
		if st.signals.Destroying then st.signals.Destroying.fire() end
		for _, child in table.clone(st.children) do destroy(child) end
		if st.parent then
			local siblings = ST[st.parent].children
			local i = table.find(siblings, obj)
			if i then table.remove(siblings, i) end
		end
		st.parent, st.destroyed, st.locked = nil, true, true
		for _, s in st.signals do s.clear() end
	end
	function special.Destroy(obj) self_(obj, "Destroy") destroy(obj) end
	function special.ClearAllChildren(obj)
		for _, child in table.clone(self_(obj, "ClearAllChildren").children) do destroy(child) end
	end
	local function clone(obj)
		local st = ST[obj]
		if st.props.Archivable == false then return nil end
		local copy = newInstance(st.class, true)
		local cs = ST[copy]
		cs.name = st.name
		for k, v in st.props do cs.props[k] = v end
		for k, v in st.set do cs.set[k] = v end
		for k, v in st.attrs do cs.attrs[k] = v end
		for _, child in st.children do
			local c = clone(child)
			if c then setParent(c, ST[c], copy) end
		end
		return copy
	end
	function special.Clone(obj) self_(obj, "Clone") return clone(obj) end
	function special.Emit(obj, n)
		local st = self_(obj, "Emit")
		if n ~= nil and type(n) ~= "number" then fail("Unable to cast " .. typeOf(n) .. " to int", 2) end
		st.emitted = (st.emitted or 0) + (n or 16)
		env.emitted = (env.emitted or 0) + (n or 16)
	end
	function special.Clear(obj) self_(obj, "Clear") end
	function special.GetPivot(obj)
		local st = self_(obj, "GetPivot")
		if isA(st.class, "BasePart") then return worldCF(obj) end
		local primary = st.props.PrimaryPart or special.FindFirstChildWhichIsA(obj, "BasePart", true)
		return if primary then worldCF(primary) else env.CFrame.identity
	end
	function special.PivotTo(obj, c)
		local st = self_(obj, "PivotTo")
		if kinds[c] ~= "CFrame" then fail("Unable to cast " .. typeOf(c) .. " to CoordinateFrame", 2) end
		if isA(st.class, "BasePart") then st.props.CFrame = c return end
		local delta = c * special.GetPivot(obj):Inverse()
		for _, d in descendants(obj, {}) do
			if isA(ST[d].class, "BasePart") then ST[d].props.CFrame = delta * worldCF(d) end
		end
	end
	function special.GetBoundingBox(obj) return special.GetPivot(obj), vec(4, 6, 2) end
	function special.GetExtentsSize() return vec(4, 6, 2) end
	function special.GetMass() return 1 end
	function special.GetPlayingAnimationTracks() return {} end
	function special.GetService(obj, name)
		local service = env.services[name]
		if service then return service end
		local c = classes[name]
		if c and c.service then
			service = env.newInstance(name, {}, env.game)
			env.services[name] = service
			return service
		end
		fail(("'%s' is not a valid Service name"):format(tostring(name)), 2)
	end
	special.FindService = special.GetService
	function special.Raycast(_, origin, direction, params)
		if kinds[origin] ~= "Vector3" or kinds[direction] ~= "Vector3" then fail("Raycast: Vector3 expected", 2) end
		if params ~= nil and kinds[params] ~= "RaycastParams" then fail("Unable to cast " .. typeOf(params) .. " to RaycastParams", 2) end
		-- (the arena floor: y = 0)
		if direction.Y < 0 and origin.Y >= 0 and origin.Y + direction.Y <= 0 then
			local t = origin.Y / -direction.Y
			local at = origin + direction * t
			local hit = { Position = at, Normal = vec(0, 1, 0), Instance = env.floor, Distance = (at - origin).Magnitude,
				Material = enumTypes.Material.Plastic }
			kinds[hit] = "RaycastResult"
			return hit
		end
		return nil
	end
	function special.BindToRenderStep(_, name, priority, fn)
		if type(name) ~= "string" or type(priority) ~= "number" or type(fn) ~= "function" then
			fail("BindToRenderStep: bad arguments", 2)
		end
		env.renderSteps[name] = fn
	end
	function special.UnbindFromRenderStep(_, name) env.renderSteps[name] = nil end
	function special.AddItem(_, obj, life)
		if not isInstance(obj) then fail("Unable to cast " .. typeOf(obj) .. " to Instance", 2) end
		task.delay(life or 10, function() destroy(obj) end)
	end
	function special.PreloadAsync(_, list, callback)
		if type(list) ~= "table" then fail("Unable to cast to Array", 2) end
		for _, id in list do
			local status = if env.failAssets and env.failAssets[id] then enumTypes.AssetFetchStatus.Failure
				else enumTypes.AssetFetchStatus.Success
			if callback then callback(id, status) end
		end
	end
	function special.WorldToViewportPoint(cam, p)
		local local_ = worldCF(cam):Inverse() * p
		local depth = -local_.Z
		local f = 360 / math.tan(math.rad(35))
		return vec(640 + local_.X / math.max(depth, 1e-3) * f, 360 - local_.Y / math.max(depth, 1e-3) * f, depth), depth > 0
	end
	special.WorldToScreenPoint = special.WorldToViewportPoint
	function special.ViewportPointToRay(cam)
		local c = worldCF(cam)
		local ray = { Origin = c.Position, Direction = c.LookVector }
		kinds[ray] = "Ray"
		return ray
	end
	special.ScreenPointToRay = special.ViewportPointToRay
	-- TweenService
	function special.Create(_, obj, info, goals)
		if not isInstance(obj) then fail("Unable to cast " .. typeOf(obj) .. " to Instance", 2) end
		if kinds[info] ~= "TweenInfo" then fail("Unable to cast " .. typeOf(info) .. " to TweenInfo", 2) end
		if type(goals) ~= "table" then fail("Unable to cast to Dictionary", 2) end
		local st = ST[obj]
		for k, v in goals do
			local m = member(st.class, k)
			if not (m and m.kind == "Property") then fail(("No property named '%s' for object '%s'"):format(k, st.name), 2) end
			if m.readonly then fail(("TweenService:Create property named '%s' cannot be tweened"):format(k), 2) end
			local t = typeOf(v)
			if not (t == "number" or t == "Vector3" or t == "Vector2" or t == "CFrame" or t == "Color3" or t == "UDim2"
				or t == "UDim" or t == "boolean" or t == "NumberRange" or t == "Rect" or t == "EnumItem") then
				fail(("TweenService:Create property named '%s' cannot be tweened due to type mismatch (property is a '%s', but given type is '%s')"):format(k, m.t, t), 2)
			end
			checkValue(st, k, m, v)
		end
		local tween = env.newInstance("Tween", {})
		local ts = ST[tween]
		ts.play = function()
			task.delay(info.Time + info.DelayTime, function()
				if ST[obj].destroyed then return end
				for k, v in goals do obj[k] = v end
				if ts.signals.Completed then ts.signals.Completed.fire(enumTypes.PlaybackState.Completed) end
			end)
		end
		return tween
	end
	function special.Play(obj)
		local st = self_(obj, "Play")
		if st.play then st.play() end
	end
	env.TweenInfo = {
		new = function(t, style, dir, repeats, reverses, delay)
			if style ~= nil and enumOf("EasingStyle", style) == nil then fail("TweenInfo.new: bad EasingStyle", 2) end
			if dir ~= nil and enumOf("EasingDirection", dir) == nil then fail("TweenInfo.new: bad EasingDirection", 2) end
			return frozen("TweenInfo", { Time = num(t or 1, "time"), EasingStyle = style, EasingDirection = dir,
				RepeatCount = repeats or 0, Reverses = reverses or false, DelayTime = num(delay, "delay") })
		end,
	}
	env.RaycastParams = {
		new = function()
			local p = { FilterDescendantsInstances = {}, IgnoreWater = false, CollisionGroup = "Default", RespectCanCollide = false }
			kinds[p] = "RaycastParams"
			return setmetatable(p, {
				__newindex = function(t, k, v)
					if k == "FilterType" then
						if enumOf("RaycastFilterType", v) == nil then fail("Unable to assign property FilterType", 2) end
						rawset(t, k, v)
						return
					end
					fail(tostring(k) .. " is not a valid member of RaycastParams", 2)
				end,
				__index = function(_, k) if k == "FilterType" then return enumTypes.RaycastFilterType.Exclude end fail(tostring(k) .. " is not a valid member of RaycastParams", 2) end,
			})
		end,
	}
	env.Random = {
		new = function()
			local r = {}
			kinds[r] = "Random"
			function r.NextNumber(_, a, b) a, b = a or 0, b or 1 return a + math.random() * (b - a) end
			function r.NextInteger(_, a, b) return math.random(a, b) end
			function r.NextUnitVector() return vec(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit end
			return r
		end,
	}

	-- ================================================================= the place
	env.services = {}
	local game = env.newInstance("DataModel", { Name = "Game" })
	env.game = game
	local function service(name)
		local s = env.newInstance(name, {}, game)
		env.services[name] = s
		return s
	end
	local workspace = service("Workspace")
	env.workspace = workspace
	local camera = env.newInstance("Camera", { Name = "Camera", FieldOfView = 70, ViewportSize = vec2(1280, 720),
		CFrame = lookAt(vec(0, 5, 32), vec(0, 3, 0)) }, workspace)
	ST[workspace].props.CurrentCamera = camera
	env.floor = env.newInstance("Part", { Name = "Floor", Anchored = true, Size = vec(64, 1, 20), CFrame = cf(vec(0, -0.5, 0), IDENT) }, workspace)
	local players = service("Players")
	local player = env.newInstance("Player", { Name = "Wilhem" }, players)
	ST[players].props.LocalPlayer = player
	env.newInstance("PlayerGui", { Name = "PlayerGui" }, player)
	for _, name in { "Lighting", "ReplicatedStorage", "RunService", "TweenService", "Debris", "ContentProvider",
		"UserInputService", "StarterPlayer", "SoundService" } do
		service(name)
	end
	env.renderSteps = {}

	-- one frame: RunService's events, the bound render steps, the due threads
	function env.step(dt)
		env.clock += dt
		local due = {}
		for i = #queue, 1, -1 do
			if queue[i].at <= env.clock + 1e-9 then
				table.insert(due, 1, table.remove(queue, i))
			end
		end
		table.sort(due, function(a, b) return a.at < b.at end)
		for _, q in due do
			if coroutine.status(q.co) == "suspended" then resume(q.co, table.unpack(q.args, 1, q.args.n)) end
		end
		local rs = ST[env.services.RunService].signals
		if rs.RenderStepped then rs.RenderStepped.fire(dt) end
		for name, fn in env.renderSteps do
			local ok, err = pcall(fn, dt)
			if not ok then record("error", "render step " .. name .. ": " .. tostring(err)) end
		end
		if rs.Stepped then rs.Stepped.fire(env.clock, dt) end
		if rs.Heartbeat then rs.Heartbeat.fire(dt) end
	end
	function env.run(seconds)
		for _ = 1, math.ceil(seconds * 60) do env.step(1 / 60) end
	end
	-- one call of the code under test, in a thread of its own (it may wait); errors recorded
	function env.call(label, fn, ...)
		env.label = label
		local results
		local co = coroutine.create(function(...)
			results = table.pack(xpcall(fn, function(e) return debug.traceback(tostring(e), 2) end, ...))
		end)
		resume(co, ...)
		if results and not results[1] then
			record("error", results[2])
			return nil
		end
		return if results then table.unpack(results, 2, results.n) else nil
	end
	-- a module's source, run as Roblox runs a ModuleScript: its own `script`, the fake engine
	-- as its globals
	local modules = {}
	function env.module(instance, chunk)
		modules[instance] = { chunk = chunk }
	end
	function env.require(x)
		local m = modules[x]
		if not m then fail("Attempted to call require with invalid argument(s).", 2) end
		if not m.loaded then
			m.loaded = true
			m.value = m.chunk()
		end
		return m.value
	end
	function env.globals(script)
		return setmetatable({
			game = game, workspace = workspace, script = script, require = env.require, Instance = env.Instance,
			Enum = env.Enum, Vector3 = env.Vector3, Vector2 = env.Vector2, CFrame = env.CFrame, Color3 = env.Color3,
			ColorSequence = env.ColorSequence, ColorSequenceKeypoint = env.ColorSequenceKeypoint,
			NumberSequence = env.NumberSequence, NumberSequenceKeypoint = env.NumberSequenceKeypoint,
			NumberRange = env.NumberRange, UDim = env.UDim, UDim2 = env.UDim2, Rect = env.Rect, TweenInfo = env.TweenInfo,
			RaycastParams = env.RaycastParams, Random = env.Random, typeof = env.typeof, task = env.task, wait = env.wait,
			delay = env.delay, spawn = env.spawn, os = env.os, tick = env.tick, time = env.time, warn = env.warn,
			print = env.print,
		}, { __index = _G })
	end
	return env
end
