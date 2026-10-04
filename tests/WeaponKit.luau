-- Where the kits' weapons (src/shared/WeaponSpec.luau) are on a posed body, offline: the
-- pieces to draw in the pose sheets and storyboards, and the blade's base and tip for the
-- animation tests. `parts`: part name -> { cframe = 12 numbers, size = { x, y, z } } (R15,
-- or an R6 body whose hand is the end of its arm, as RigBuilder places it).
local K = require("../src/shared/Kinematics")
local WeaponSpec = require("../src/shared/WeaponSpec")
local OrbFlight = require("../src/shared/OrbFlight")
local MoveData = require("../src/shared/MoveData")

local ROLE_OF = {}
for _, kit in MoveData.Kits do
	for role, id in kit.Roles do ROLE_OF[id] = role end
end

local WeaponKit = {}

local R6_HANDS = { RightHand = "Right Arm", LeftHand = "Left Arm" }

local function hand(parts, name)
	local p = parts[name]
	if p then return p.cframe, p.size, false end
	local arm = R6_HANDS[name] and (parts[R6_HANDS[name]] or parts[(R6_HANDS[name]:gsub(" ", "_"))])
	if not arm then return nil, nil end
	return K.mul(arm.cframe, K.translation(0, arm.size[2] * -0.42, 0)), { arm.size[1], arm.size[2] * 0.16, arm.size[3] }, true
end

-- The grip frame of `kit`'s weapon (nil for a kit without one) and its spec (`spec` given:
-- that weapon, e.g. the second of a pair).
function WeaponKit.grip(kit, parts, spec)
	spec = spec or WeaponSpec[kit]
	if not spec then return nil, nil end
	local frame, size, r6 = hand(parts, spec.hand)
	if not frame then return nil, nil end
	local g = if r6 then spec.r6Grip or spec.grip else spec.grip
	return K.mul(K.mul(frame, K.translation(0, size[2] * g.y, g.z)), K.angles(math.rad(g.tilt), 0, 0)), spec
end

-- Where a flying weapon is (DAICHA's orb, OrbFlight) for a fighter's view at `time`: a world
-- position { x, y, z } (the view's x, y are its feet; it faces `facing` along X).
function WeaponKit.flight(view, time)
	local id = view.state == "Attack" and view.move or nil
	local o = OrbFlight.offset(view, id and MoveData.Moves[id], id and ROLE_OF[id], time)
	return { view.x + (view.facing or 1) * o.fwd, view.y + o.up, (view.z or 0) + o.side }, o
end

-- The weapon's pieces: { name, cframe, size, color (hex) }. A flying weapon needs the view
-- and the time (`flight` = { view, time }); without them it is drawn in the hand.
function WeaponKit.pieces(kit, parts, energy, flight, which)
	local grip, spec = WeaponKit.grip(kit, parts, which)
	local out = {}
	if not grip then return out end
	if spec.flies and flight then
		local at = WeaponKit.flight(flight.view, flight.time)
		if flight.view.state == "Attack" then
			-- The chain of shadow from his hand to the orb while he strikes with it.
			local hx, hy, hz = K.point(grip, 0, 0, 0)
			local dx, dy, dz = at[1] - hx, at[2] - hy, at[3] - hz
			local length = math.sqrt(dx * dx + dy * dy + dz * dz)
			if length > 0.05 then
				local zx, zy, zz = -dx / length, -dy / length, -dz / length -- the part's -Z toward the orb
				local ux, uy, uz = 0, 1, 0
				if math.abs(zy) > 0.95 then ux, uy, uz = 1, 0, 0 end
				local xx, xy, xz = uy * zz - uz * zy, uz * zx - ux * zz, ux * zy - uy * zx
				local xl = math.sqrt(xx * xx + xy * xy + xz * xz)
				xx, xy, xz = xx / xl, xy / xl, xz / xl
				local yx, yy, yz = zy * xz - zz * xy, zz * xx - zx * xz, zx * xy - zy * xx
				table.insert(out, { name = "WeaponChain", size = { 0.1, 0.1, length },
					cframe = { (hx + at[1]) / 2, (hy + at[2]) / 2, (hz + at[3]) / 2, xx, yx, zx, xy, yy, zy, xz, yz, zz },
					color = energy or "8FD8FF" })
			end
		end
		grip = K.translation(at[1], at[2], at[3])
	end
	for _, p in spec.pieces do
		table.insert(out, { name = "Weapon" .. p.name, cframe = K.mul(grip, K.translation(0, p.y or 0, p.z or 0)), size = p.size,
			color = if p.color == "energy" then energy or "8FD8FF" elseif p.color == "trim" then "C9A227" else p.color })
	end
	if spec.pair and not which then
		for _, piece in WeaponKit.pieces(kit, parts, energy, flight, spec.pair) do
			piece.name ..= "2"
			table.insert(out, piece)
		end
	end
	return out
end

-- World base and tip of the blade (for the orb: its centre, twice).
function WeaponKit.line(kit, parts)
	local grip, spec = WeaponKit.grip(kit, parts)
	if not grip then return nil, nil end
	local bx, by, bz = K.point(grip, 0, 0, spec.base)
	local tx, ty, tz = K.point(grip, 0, 0, spec.tip)
	return { bx, by, bz }, { tx, ty, tz }
end

return WeaponKit
