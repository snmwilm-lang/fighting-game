-- Where the kits' weapons (src/shared/WeaponSpec.luau) are on a posed body, offline: the
-- pieces to draw in the pose sheets and storyboards, and the blade's base and tip for the
-- animation tests. `parts`: part name -> { cframe = 12 numbers, size = { x, y, z } } (R15,
-- or an R6 body whose hand is the end of its arm, as RigBuilder places it).
local K = require("../src/shared/Kinematics")
local WeaponSpec = require("../src/shared/WeaponSpec")
local OrbFlight = require("../src/shared/OrbFlight")
local MoveData = require("../src/shared/MoveData")
local FourArms = require("../src/shared/FourArms")

local ROLE_OF = {}
for _, kit in MoveData.Kits do
	for role, id in kit.Roles do ROLE_OF[id] = role end
end

local WeaponKit = {}

local R6_HANDS = { RightHand = "Right Arm", LeftHand = "Left Arm" }

local function hand(parts, name)
	local p = parts[name] or parts["@" .. name] -- (@: the virtual R15 hand of an R6 body, see Retarget)
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

-- A posed body ({ [name] = { cframe, size } }) as OrbFlight.avoid's boxes (centre, unit axes,
-- half sizes), like the client reads them off the rig (EffectsController:orbBodyBoxes).
function WeaponKit.boxes(parts)
	local out = {}
	for name, part in parts do
		if name ~= "HumanoidRootPart" then
			local c, z = part.cframe, part.size
			table.insert(out, { c[1], c[2], c[3], c[4], c[7], c[10], c[5], c[8], c[11], c[6], c[9], c[12], z[1] / 2, z[2] / 2, z[3] / 2, name = name })
		end
	end
	return out
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
-- ASURA's second pair of arms, posed as the client poses them (RigBuilder.addFourArms,
-- AnimationController:swingFourArms, without its easing): { name, cframe, size, color }.
function WeaponKit.fourArms(parts, view, time)
	local torso = parts.UpperTorso or parts.Torso
	if not torso then return {} end
	local spec, out = FourArms.SPEC, {}
	local scale = torso.size[1] / 2
	local upper, fore, w = spec.upper * scale, spec.fore * scale, 0.62 * scale
	local arms = FourArms.pose(view, time, MoveData.Moves)
	for name, a in arms do
		local side = if name == "Left" then -1 else 1
		local pitch, yaw, roll, bend, twist = FourArms.angles(side, a)
		local c0 = K.mul(K.mul(K.mul(K.mul(K.translation(side * spec.shoulder.x * scale, spec.shoulder.y * scale, spec.shoulder.z * scale),
			K.angles(0, math.rad(yaw), 0)), K.angles(math.rad(pitch), 0, 0)), K.angles(0, 0, math.rad(roll))), K.angles(0, math.rad(twist), 0))
		local arm = K.mul(K.mul(torso.cframe, c0), K.translation(0, -upper / 2, 0))
		local forearm = K.mul(K.mul(K.mul(arm, K.translation(0, -upper / 2, 0)), K.angles(math.rad(bend), 0, 0)), K.translation(0, -fore / 2, 0))
		table.insert(out, { name = "AsuraArm" .. name, cframe = arm, size = { w, upper, w }, color = "8A5A44" })
		table.insert(out, { name = "AsuraForearm" .. name, cframe = forearm, size = { w * 0.92, fore, w * 0.92 }, color = "8A5A44" })
		table.insert(out, { name = "AsuraFist" .. name, cframe = K.mul(forearm, K.translation(0, -fore / 2 - 0.3 * scale, 0)),
			size = { 0.76 * scale, 0.76 * scale, 0.76 * scale }, color = "C8A040" })
	end
	return out
end

function WeaponKit.pieces(kit, parts, energy, flight, which)
	if kit == "ASURA" and flight and not which then return WeaponKit.fourArms(parts, flight.view, flight.time) end
	local grip, spec = WeaponKit.grip(kit, parts, which)
	local out = {}
	if not grip then return out end
	local scale = 1
	if spec.flies and flight then
		local at = WeaponKit.flight(flight.view, flight.time)
		-- (no chain any more: the matter flies free; drawn at the size OrbFlight.form gives, a
		-- disc or a puddle drawn as a flat wide orb)
		local view = flight.view
		local id = view.state == "Attack" and view.move or nil
		local form = OrbFlight.form(view, id and MoveData.Moves[id], id and ROLE_OF[id], flight.time)
		scale = math.max(0.01, form.radius * 2 / 0.9)
		-- (kept off her body, like in game: OrbFlight.avoid)
		if form.shape == "ball" and form.radius > 0.05 then
			local o = select(2, WeaponKit.flight(view, flight.time))
			at = OrbFlight.avoid(at, form.radius, WeaponKit.boxes(parts), OrbFlight.SCREEN_CLEARANCE,
				OrbFlight.avoidDirection(view.state, view.facing or 1, o), true)
		end
		grip = K.translation(at[1], at[2], at[3])
	end
	for _, p in spec.pieces do
		table.insert(out, { name = "Weapon" .. p.name, cframe = K.mul(grip, K.translation(p.x or 0, p.y or 0, p.z or 0)),
			size = if scale == 1 then p.size else { p.size[1] * scale, p.size[2] * scale, p.size[3] * scale },
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
