--[[
	The weapons the kits hold (pure data, no Roblox API, no require): SHIN's katana and
	DAICHA's shadow orb. Each sits in a hand, at a grip given in the hand's own space (the
	hand's -Z is the front of the open hand, +Y points to the elbow; `y` is a share of the
	hand's height, `tilt` degrees around the hand's X axis). Its pieces are placed along the
	grip's -Z axis. Built by the server (RigBuilder), drawn by the pose sheets and
	storyboards, and measured by the animation tests (a cut must really sweep the blade).
	`r6Grip` replaces `grip` on an R6 body, whose hand is the end of a rigid arm.
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
	grip = { y = -0.2, z = -0.95, tilt = 0 },
	r6Grip = { y = -0.9, z = -0.35, tilt = 0 }, -- (R6) just past the end of the arm
	pieces = {
		{ name = "ShadowOrb", size = { 0.9, 0.9, 0.9 }, color = "140A20", shape = "Ball" },
		{ name = "OrbCore", size = { 0.42, 0.42, 0.42 }, color = "energy", material = "Neon", shape = "Ball" },
	},
	base = 0, tip = 0, -- the orb is a point: its centre
}

return WeaponSpec
