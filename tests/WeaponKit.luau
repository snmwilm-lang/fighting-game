-- Where the kits' weapons (src/shared/WeaponSpec.luau) are on a posed body, offline: the
-- pieces to draw in the pose sheets and storyboards, and the blade's base and tip for the
-- animation tests. `parts`: part name -> { cframe = 12 numbers, size = { x, y, z } } (R15,
-- or an R6 body whose hand is the end of its arm, as RigBuilder places it).
local K = require("../src/shared/Kinematics")
local WeaponSpec = require("../src/shared/WeaponSpec")

local WeaponKit = {}

local R6_HANDS = { RightHand = "Right Arm", LeftHand = "Left Arm" }

local function hand(parts, name)
	local p = parts[name]
	if p then return p.cframe, p.size, false end
	local arm = R6_HANDS[name] and (parts[R6_HANDS[name]] or parts[(R6_HANDS[name]:gsub(" ", "_"))])
	if not arm then return nil, nil end
	return K.mul(arm.cframe, K.translation(0, arm.size[2] * -0.42, 0)), { arm.size[1], arm.size[2] * 0.16, arm.size[3] }, true
end

-- The grip frame of `kit`'s weapon (nil for a kit without one) and its spec.
function WeaponKit.grip(kit, parts)
	local spec = WeaponSpec[kit]
	if not spec then return nil, nil end
	local frame, size, r6 = hand(parts, spec.hand)
	if not frame then return nil, nil end
	local g = if r6 then spec.r6Grip or spec.grip else spec.grip
	return K.mul(K.mul(frame, K.translation(0, size[2] * g.y, g.z)), K.angles(math.rad(g.tilt), 0, 0)), spec
end

-- The weapon's pieces: { name, cframe, size, color (hex) }.
function WeaponKit.pieces(kit, parts, energy)
	local grip, spec = WeaponKit.grip(kit, parts)
	local out = {}
	if not grip then return out end
	for _, p in spec.pieces do
		table.insert(out, { name = "Weapon" .. p.name, cframe = K.mul(grip, K.translation(0, p.y or 0, p.z or 0)), size = p.size,
			color = if p.color == "energy" then energy or "8FD8FF" elseif p.color == "trim" then "C9A227" else p.color })
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
