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
	pieces = {
		{ name = "Handle", size = { 0.18, 0.18, 0.9 }, z = 0.05, color = "0B0B0E" },
		{ name = "Guard", size = { 0.5, 0.5, 0.08 }, z = -0.42, color = "trim", shape = "Cylinder" },
		{ name = "Blade", size = { 0.08, 0.22, 3.4 }, z = -2.16, color = "D6DCE8", material = "Metal" },
		{ name = "Edge", size = { 0.09, 0.05, 3.3 }, y = -0.12, z = -2.12, color = "energy", material = "Neon" },
	},
	-- Along the grip's -Z: where the blade starts and ends (trails, tests).
	base = -0.46, tip = -3.86,
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

-- YUKINA's fans of ice, one in each hand, opened on the line of the hand.
local function fan(hand)
	return {
		hand = hand,
		grip = { y = -0.15, z = -0.1, tilt = -20 },
		r6Grip = { y = -0.35, z = -0.15, tilt = -78 },
		pieces = {
			{ name = "FanSpine", size = { 0.08, 0.08, 1.15 }, z = -0.55, color = "E8F2FA", material = "Metal" },
			{ name = "FanLeaf", size = { 0.05, 1.1, 1.0 }, y = 0.3, z = -0.65, color = "energy", material = "Glass" },
			{ name = "FanEdge", size = { 0.06, 0.06, 1.0 }, y = 0.85, z = -0.65, color = "FFFFFF", material = "Neon" },
		},
		base = -0.15, tip = -1.15,
	}
end
WeaponSpec.YUKINA = fan("RightHand")
WeaponSpec.YUKINA.pair = fan("LeftHand")

-- KAZAN's claws: a steel gauntlet on each hand, three long blades out of the knuckles, on the
-- line of the forearm (tilt -90: the grip's -Z is the hand's -Y, past the fist), side by side
-- across the knuckles (x). Long enough to read at a glance, short enough to stay a fist's
-- weapon (the reach of his moves is in MoveData: middle range, never a whip's).
local function claw(hand)
	local pieces = {
		{ name = "ClawPlate", size = { 0.74, 0.16, 0.26 }, z = 0.02, color = "trim", material = "Metal" },
	}
	for i, x in { -0.24, 0, 0.24 } do
		table.insert(pieces, { name = "ClawBlade" .. i, size = { 0.07, 0.16, 1.35 }, x = x, z = -0.68, color = "C8CCD6", material = "Metal" })
		table.insert(pieces, { name = "ClawEdge" .. i, size = { 0.08, 0.04, 1.2 }, x = x, y = 0.09, z = -0.7, color = "energy", material = "Neon" })
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
