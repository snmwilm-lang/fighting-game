--[[
	The weapons the kits hold (pure data, no Roblox API, no require): SHIN's katana and
	DAICHA's shadow orb. Each sits in a hand, at a grip given in the hand's own space (the
	hand's -Z is the front of the open hand, +Y points to the elbow; `y` is a share of the
	hand's height, `tilt` degrees around the hand's X axis). Its pieces are placed along the
	grip's -Z axis. Built by the server (RigBuilder), drawn by the pose sheets and
	storyboards, and measured by the animation tests (a cut must really sweep the blade).
	`r6Grip` replaces `grip` on an R6 body, whose hand is the end of a rigid arm.
	`pair`: a second weapon in the other hand (YUKINA's two fans, KAZAN's two claws).
	A piece may be offset sideways (`x`, the grip's X: KAZAN's three blades side by side).
]]
local WeaponSpec = {}

WeaponSpec.SHIN = {
	hand = "RightHand",
	grip = { y = -0.1, z = -0.1, tilt = -20 },
	-- An R6 arm has no wrist: there the blade carries on the line of the arm, so the arm's
	-- swing is still the blade's arc.
	r6Grip = { y = -0.3, z = -0.15, tilt = -78 },
	-- (Wilhem: « augmente la qualité de cette lame »: a real katana, piece by piece. The grip's
	-- -Z runs up the blade, its -Y is the cutting edge, +Y the back. `rot`: degrees around the
	-- grip's X, Y, Z, after the offset.)
	pieces = {
		-- the hilt: the pommel cap (kashira), the handle (tsuka) wrapped in crossed cord (ito)
		-- over white ray skin (same), two ornaments (menuki) under the wrap
		{ name = "Pommel", size = { 0.17, 0.21, 0.07 }, z = 0.36, color = "trim", material = "Metal" },
		{ name = "Handle", size = { 0.16, 0.2, 0.7 }, z = -0.03, color = "E9E4D6" },
		{ name = "Wrap2", size = { 0.17, 0.21, 0.08 }, z = 0.15, color = "141621" },
		{ name = "Wrap3", size = { 0.17, 0.21, 0.08 }, z = 0.0, color = "141621" },
		{ name = "Wrap4", size = { 0.17, 0.21, 0.08 }, z = -0.15, color = "141621" },
		{ name = "WrapX1a", size = { 0.175, 0.03, 0.2 }, z = 0.21, rot = { 42, 0, 0 }, color = "141621" },
		{ name = "WrapX1b", size = { 0.175, 0.03, 0.2 }, z = 0.21, rot = { -42, 0, 0 }, color = "141621" },
		{ name = "WrapX2a", size = { 0.175, 0.03, 0.2 }, z = 0.075, rot = { 42, 0, 0 }, color = "141621" },
		{ name = "WrapX2b", size = { 0.175, 0.03, 0.2 }, z = 0.075, rot = { -42, 0, 0 }, color = "141621" },
		{ name = "WrapX3a", size = { 0.175, 0.03, 0.2 }, z = -0.075, rot = { 42, 0, 0 }, color = "141621" },
		{ name = "WrapX3b", size = { 0.175, 0.03, 0.2 }, z = -0.075, rot = { -42, 0, 0 }, color = "141621" },
		{ name = "Menuki", size = { 0.165, 0.05, 0.12 }, y = 0.1, z = 0.075, color = "trim", material = "Metal" },
		{ name = "Fuchi", size = { 0.19, 0.23, 0.07 }, z = -0.31, color = "trim", material = "Metal" },
		-- the guard (tsuba): a dark iron disc in a gold rim, its washers (seppa) either side
		{ name = "GuardRim", size = { 0.05, 0.54, 0.54 }, z = -0.4, rot = { 0, 90, 0 }, color = "trim", shape = "Cylinder", material = "Metal" },
		{ name = "Guard", size = { 0.08, 0.46, 0.46 }, z = -0.4, rot = { 0, 90, 0 }, color = "1C1C24", shape = "Cylinder", material = "Metal" },
		{ name = "Seppa", size = { 0.04, 0.3, 0.3 }, z = -0.46, rot = { 0, 90, 0 }, color = "trim", shape = "Cylinder", material = "Metal" },
		-- the blade collar (habaki), gold
		{ name = "Habaki", size = { 0.12, 0.27, 0.18 }, y = -0.01, z = -0.56, color = "trim", material = "Metal" },
		-- the blade: polished steel, its ridge line (shinogi) darker, its glowing temper line
		-- (hamon, `Edge`) along the cutting edge; it curves back toward the tip (sori) and ends
		-- in an angled point (kissaki)
		{ name = "Blade", size = { 0.07, 0.24, 2.7 }, z = -1.97, color = "D6DCE8", material = "Metal" },
		{ name = "Ridge", size = { 0.075, 0.035, 2.6 }, y = 0.055, z = -1.97, color = "8E97A8", material = "Metal" },
		{ name = "BladeBack", size = { 0.078, 0.03, 2.7 }, y = 0.115, z = -1.97, color = "A9B1C0", material = "Metal" },
		{ name = "Edge", size = { 0.08, 0.05, 2.65 }, y = -0.1, z = -1.97, color = "energy", material = "Neon" },
		{ name = "BladeTip", size = { 0.07, 0.22, 0.42 }, y = 0.02, z = -3.51, rot = { 7, 0, 0 }, color = "D6DCE8", material = "Metal" },
		{ name = "EdgeTip", size = { 0.08, 0.05, 0.4 }, y = -0.075, z = -3.5, rot = { 7, 0, 0 }, color = "energy", material = "Neon" },
		{ name = "Kissaki", size = { 0.066, 0.16, 0.2 }, y = 0.06, z = -3.76, rot = { 32, 0, 0 }, color = "EEF2F8", material = "Metal" },
	},
	-- Along the grip's -Z: where the blade starts and ends (trails, tests).
	base = -0.62, tip = -3.86,
}

WeaponSpec.DAICHA = {
	hand = "LeftHand",
	-- The orb is built in the hand, but it flies on its own (src/shared/OrbFlight.luau): the
	-- client sets it free and moves it every frame.
	flies = true,
	grip = { y = -0.2, z = -0.95, tilt = 0 },
	r6Grip = { y = -0.9, z = -0.35, tilt = 0 }, -- (R6) just past the end of the arm
	pieces = {
		{ name = "ShadowOrb", size = { 0.9, 0.9, 0.9 }, color = "140A20", shape = "Ball" },
		{ name = "OrbCore", size = { 0.42, 0.42, 0.42 }, color = "energy", material = "Neon", shape = "Ball" },
	},
	base = 0, tip = 0, -- the orb is a point: its centre
}

-- RAIJIN's spear, held a third of the way down the shaft in the right hand: the butt behind
-- the fist, the steel head far ahead, its edge glowing with lightning.
WeaponSpec.RAIJIN = {
	hand = "RightHand",
	grip = { y = -0.1, z = -0.1, tilt = -20 },
	r6Grip = { y = -0.3, z = -0.15, tilt = -78 },
	pieces = {
		-- (the butt only 0.7 past the fist: both hands hold the shaft ahead of it, and a longer
		-- end went through his chest in his guard and his walk)
		{ name = "Shaft", size = { 0.16, 0.16, 4.4 }, z = -1.5, color = "2A2A33", material = "Metal" },
		{ name = "Butt", size = { 0.24, 0.24, 0.26 }, z = 0.8, color = "trim", material = "Metal" },
		{ name = "Collar", size = { 0.26, 0.26, 0.16 }, z = -3.62, color = "trim", material = "Metal" },
		{ name = "SpearHead", size = { 0.1, 0.38, 0.95 }, z = -4.15, color = "D6DCE8", material = "Metal" },
		{ name = "Edge", size = { 0.11, 0.06, 0.85 }, y = 0.2, z = -4.1, color = "energy", material = "Neon" },
		-- (Wilhem's sheet: a red tassel tied under the head)
		{ name = "Tassel", size = { 0.05, 0.75, 0.1 }, y = -0.42, z = -3.5, color = "B3121E" },
		{ name = "Tassel2", size = { 0.05, 0.58, 0.09 }, x = 0.07, y = -0.34, z = -3.44, color = "8E0E18" },
	},
	base = -3.6, tip = -4.6,
}

-- YUKINA's fans of ice, one in each hand, opened on the line of the hand. (Wilhem: « les
-- éventails » detailed like SHIN's katana.) A real folding fan: seven sticks radiating from a
-- rivet in her fist, the outer two heavier (the guards), the leaf stretched between them in
-- six panels of ice-blue glass, a rim of frost along its edge, an icicle at the end of every
-- stick, a snowflake painted on it, and a jewel on the rivet. It opens from the
-- line of the hand (-Z) toward +Y, over FAN_OPEN degrees.
local FAN_OPEN, FAN_STICKS, FAN_R, FAN_LEAF = 62, 7, 1.2, 0.3
local FAN_PIVOT = { 0, -0.1, 0 }
local LETTERS = { "A", "B", "C", "D", "E", "F", "G" }
local function fanPiece(name, size, angle, r, color, material, shape, x)
	local a = math.rad(angle)
	return { name = name, size = size, x = x or 0, y = FAN_PIVOT[2] + math.sin(a) * r, z = FAN_PIVOT[3] - math.cos(a) * r,
		rot = { angle, 0, 0 }, color = color, material = material, shape = shape }
end
local function fan(hand)
	local pieces = {}
	local step = FAN_OPEN / (FAN_STICKS - 1)
	for i = 0, FAN_STICKS - 1 do
		local angle = i * step
		local guard = i == 0 or i == FAN_STICKS - 1
		-- (the first guard keeps its old name: the spine on the line of the hand)
		local name = if i == 0 then "FanSpine" elseif guard then "FanGuard" else "FanRib" .. LETTERS[i]
		table.insert(pieces, fanPiece(name, if guard then { 0.06, 0.07, FAN_R + 0.05 } else { 0.035, 0.035, FAN_R },
			angle, (FAN_R + (if guard then 0.05 else 0)) / 2, if guard then "B9C6D3" else "E8F2FA", "Metal"))
		table.insert(pieces, fanPiece("FanIce" .. LETTERS[i + 1], { 0.04, 0.05, 0.2 }, angle, FAN_R + 0.12, "DDF6FF", "Ice"))
	end
	local chord = 2 * FAN_R * math.sin(math.rad(step / 2)) * 1.05
	for i = 0, FAN_STICKS - 2 do
		local angle = (i + 0.5) * step
		-- (the middle panel and its rim keep the names WeaponFX lights: FanLeaf, FanEdge)
		local middle = i == math.floor((FAN_STICKS - 1) / 2)
		table.insert(pieces, fanPiece(if middle then "FanLeaf" else "FanLeaf" .. LETTERS[i + 1], { 0.03, chord, FAN_R - FAN_LEAF },
			angle, (FAN_R + FAN_LEAF) / 2, "energy", "Glass"))
		table.insert(pieces, fanPiece(if middle then "FanEdge" else "FanEdge" .. LETTERS[i + 1], { 0.045, chord, 0.05 },
			angle, FAN_R - 0.02, "FFFFFF", "Neon"))
	end
	-- a snowflake painted on the leaf (three crossed strokes on its outer face)
	for k = 0, 2 do
		local flake = fanPiece("FanFlake" .. LETTERS[k + 1], { 0.035, 0.03, 0.24 }, FAN_OPEN / 2, 0.86, "FFFFFF", nil, nil, 0.025)
		flake.rot = { FAN_OPEN / 2 + k * 60, 0, 0 }
		table.insert(pieces, flake)
	end
	-- the rivet through the sticks (a cylinder lies along X: through the fan), its jewel
	-- (no tassel: it caught between her fists when she crosses them)
	table.insert(pieces, { name = "FanRivet", size = { 0.12, 0.13, 0.13 }, y = FAN_PIVOT[2], z = FAN_PIVOT[3], color = "trim",
		shape = "Cylinder", material = "Metal" })
	table.insert(pieces, { name = "FanJewel", size = { 0.14, 0.07, 0.07 }, y = FAN_PIVOT[2], z = FAN_PIVOT[3], color = "energy",
		shape = "Cylinder", material = "Neon" })
	return {
		hand = hand,
		grip = { y = -0.15, z = -0.1, tilt = -20 },
		r6Grip = { y = -0.35, z = -0.15, tilt = -78 },
		pieces = pieces,
		base = -0.15, tip = -1.2,
	}
end
WeaponSpec.YUKINA = fan("RightHand")
WeaponSpec.YUKINA.pair = fan("LeftHand")

-- KAZAN's claws: a steel gauntlet on each hand, three long blades out of the knuckles, on the
-- line of the forearm (tilt -90: the grip's -Z is the hand's -Y, past the fist), side by side
-- across the knuckles (x). Long enough to read at a glance, short enough to stay a fist's
-- weapon (the reach of his moves is in MoveData: middle range, never a whip's).
-- (Wilhem: « les griffes de KAZAN », detailed like SHIN's katana: the gauntlet's plate and its
-- knuckle guard, and each blade a thick root out of the knuckles, a long blade with its
-- glowing edge, curving down at the end into a hooked point.)
local function claw(hand)
	local pieces = {
		{ name = "ClawPlate", size = { 0.74, 0.16, 0.26 }, z = 0.02, color = "trim", material = "Metal" },
		{ name = "ClawKnuckle", size = { 0.78, 0.1, 0.12 }, y = 0.1, z = -0.1, color = "3A3D46", material = "Metal" },
	}
	for i, x in { -0.24, 0, 0.24 } do
		local L = ({ "A", "B", "C" })[i]
		table.insert(pieces, { name = "ClawRoot" .. L, size = { 0.1, 0.2, 0.22 }, x = x, z = -0.16, color = "3A3D46", material = "Metal" })
		table.insert(pieces, { name = "ClawBlade" .. i, size = { 0.07, 0.16, 1.12 }, x = x, z = -0.6, color = "C8CCD6", material = "Metal" })
		table.insert(pieces, { name = "ClawEdge" .. i, size = { 0.08, 0.04, 1.05 }, x = x, y = 0.09, z = -0.62, color = "energy", material = "Neon" })
		table.insert(pieces, { name = "ClawTip" .. L, size = { 0.065, 0.13, 0.26 }, x = x, y = -0.02, z = -1.27, rot = { -14, 0, 0 },
			color = "C8CCD6", material = "Metal" })
		table.insert(pieces, { name = "ClawHook" .. L, size = { 0.06, 0.08, 0.13 }, x = x, y = -0.07, z = -1.41, rot = { -34, 0, 0 },
			color = "E6E9F0", material = "Metal" })
	end
	return {
		hand = hand,
		grip = { y = -0.38, z = -0.08, tilt = -90 },
		r6Grip = { y = -0.46, z = -0.08, tilt = -90 },
		pieces = pieces,
		base = -0.05, tip = -1.35,
	}
end
WeaponSpec.KAZAN = claw("RightHand")
WeaponSpec.KAZAN.pair = claw("LeftHand")

return WeaponSpec
