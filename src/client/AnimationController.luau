--[[
	Presentation only: the single writer of the rig's Motor6D.C0. Poses never change simulation
	timing; attacks pick their key pose from the authoritative move frame.

	Pose format: joint -> { rotX, rotY, rotZ } in degrees, applied on top of the bind pose.
	Root also takes { rotX, rotY, rotZ, offsetY, offsetZ } (offset -Z is forward).
	Rig facing is -Z: +rotX on a shoulder/hip swings the limb forward, -rotX on a knee bends it,
	+rotY on the waist brings the right shoulder forward, -rotX on the waist leans forward.

	Looping poses are sampled at `poseRate` changes per second (anime "on twos/threes" look);
	attack, hit and guard poses switch the moment the simulation state changes.
]]
local MoveData = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").MoveData)

local function merge(base, changes)
	local out = table.clone(base)
	for k, v in changes do out[k] = v end
	return out
end

-- Ankles keep the feet flat: ankle = -(hip + knee).
local function legs(lh, lk, rh, rk, lz, rz)
	return {
		LeftHip = { lh, 0, lz or -5 }, LeftKnee = { lk, 0, 0 }, LeftAnkle = { -(lh + lk), 0, 0 },
		RightHip = { rh, 0, rz or 5 }, RightKnee = { rk, 0, 0 }, RightAnkle = { -(rh + rk), 0, 0 },
	}
end

local STANCE = merge(legs(22, -32, -12, -22), {
	Root = { 0, 0, 0, -0.25, 0 },
	Waist = { -8, 12, 0 },
	Neck = { 6, -10, 0 },
	LeftShoulder = { 72, 0, -12 }, LeftElbow = { 85, 0, 0 },
	RightShoulder = { 52, 0, 16 }, RightElbow = { 105, 0, 0 },
})
local GUARD_ARMS = {
	Waist = { -14, 0, 0 }, Neck = { 16, 0, 0 },
	LeftShoulder = { 84, 0, 26 }, LeftElbow = { 125, 0, 0 },
	RightShoulder = { 80, 0, -26 }, RightElbow = { 128, 0, 0 },
}
local CROUCH_LEGS = merge(legs(70, -110, 62, -105), { Root = { 0, 0, 0, -1.0, 0 } })

local Poses = {
	Idle = {
		merge(STANCE, {}),
		merge(STANCE, { Root = { 0, 0, 0, -0.33, 0 }, LeftShoulder = { 76, 0, -12 }, RightShoulder = { 56, 0, 16 } }),
	},
	Walk = {
		merge(STANCE, legs(38, -22, -24, -30)),
		merge(STANCE, legs(10, -14, 18, -70)),
		merge(STANCE, legs(-20, -28, 36, -24)),
		merge(STANCE, legs(18, -70, 8, -14)),
	},
	WalkBack = {
		merge(STANCE, merge(legs(10, -30, -30, -20), { Waist = { 0, 12, 0 }, LeftShoulder = { 80, 0, 0 } })),
		merge(STANCE, merge(legs(-8, -20, 14, -60), { Waist = { 2, 12, 0 }, LeftShoulder = { 82, 0, 0 } })),
		merge(STANCE, merge(legs(-28, -22, 10, -30), { Waist = { 0, 12, 0 }, LeftShoulder = { 80, 0, 0 } })),
		merge(STANCE, merge(legs(14, -60, -8, -20), { Waist = { 2, 12, 0 }, LeftShoulder = { 82, 0, 0 } })),
	},
	Crouch = merge(merge(STANCE, CROUCH_LEGS), { Waist = { -22, 12, 0 }, Neck = { 18, -10, 0 } }),
	Jump = merge(STANCE, merge(legs(70, -95, 30, -60), {
		LeftShoulder = { 110, 0, -30 }, RightShoulder = { 40, 0, 35 }, Waist = { -12, 0, 0 },
	})),
	Fall = merge(STANCE, merge(legs(25, -40, -10, -25), {
		LeftShoulder = { 60, 0, -45 }, RightShoulder = { 50, 0, 45 }, LeftElbow = { 40, 0, 0 }, RightElbow = { 40, 0, 0 },
	})),
	Dash = merge(legs(55, -45, -40, -35), {
		Root = { 0, 0, 0, -0.45, -0.2 }, Waist = { -32, 0, 0 }, Neck = { 25, 0, 0 },
		LeftShoulder = { -45, 0, -20 }, LeftElbow = { 10, 0, 0 },
		RightShoulder = { -50, 0, 20 }, RightElbow = { 10, 0, 0 },
	}),
	Block = merge(merge(STANCE, legs(26, -38, -16, -22)), GUARD_ARMS),
	CrouchBlock = merge(merge(STANCE, CROUCH_LEGS), GUARD_ARMS),
	Blockstun = merge(merge(STANCE, legs(18, -30, -22, -14)), merge(GUARD_ARMS, {
		Root = { 0, 0, 0, -0.3, 0.25 }, Waist = { 4, 0, 0 }, Neck = { 22, 0, 0 },
	})),
	Hitstun = merge(legs(-8, -22, 12, -30), {
		Root = { 0, 0, 0, -0.2, 0.35 }, Waist = { 22, -18, 0 }, Neck = { -28, 10, 0 },
		LeftShoulder = { 25, 0, -40 }, LeftElbow = { 35, 0, 0 },
		RightShoulder = { 12, 0, 50 }, RightElbow = { 25, 0, 0 },
	}),
	HitstunB = merge(legs(15, -40, -15, -20), {
		Root = { 0, 0, 0, -0.45, 0.3 }, Waist = { -30, 25, 10 }, Neck = { 30, -20, 0 },
		LeftShoulder = { 60, 0, -20 }, LeftElbow = { 90, 0, 0 },
		RightShoulder = { -10, 0, 30 }, RightElbow = { 20, 0, 0 },
	}),
	GuardBroken = merge(legs(-5, -30, 15, -40), {
		Root = { 0, 0, 0, -0.35, 0.3 }, Waist = { 28, 0, 0 }, Neck = { -30, 0, 0 },
		LeftShoulder = { 150, 0, -45 }, LeftElbow = { 20, 0, 0 },
		RightShoulder = { 150, 0, 45 }, RightElbow = { 20, 0, 0 },
	}),
	Launched = merge(legs(-20, -50, 10, -30), {
		Root = { 40, 0, 0, 0, 0 }, Waist = { 25, 0, 0 }, Neck = { -35, 0, 0 },
		LeftShoulder = { 140, 0, -50 }, LeftElbow = { 20, 0, 0 },
		RightShoulder = { 120, 0, 60 }, RightElbow = { 30, 0, 0 },
	}),
	Down = merge(legs(15, -20, 35, -50), {
		Root = { 84, 0, 0, -2.45, 0 }, Waist = { 6, 0, 0 }, Neck = { -10, 25, 0 },
		LeftShoulder = { 160, 0, -30 }, LeftElbow = { 20, 0, 0 },
		RightShoulder = { 20, 0, 70 }, RightElbow = { 30, 0, 0 },
	}),
	GetUp = merge(merge(STANCE, legs(80, -120, -30, -60)), {
		Root = { 0, 0, 0, -1.1, 0 }, Waist = { -30, 0, 0 },
		RightShoulder = { 30, 0, 30 }, RightElbow = { 30, 0, 0 },
	}),
	Victory = merge(legs(12, -10, -8, -6), {
		Root = { 0, 0, 0, -0.05, 0 }, Waist = { 10, -15, 0 }, Neck = { -14, 20, 0 },
		RightShoulder = { 172, 0, 8 }, RightElbow = { 15, 0, 0 },
		LeftShoulder = { 10, 0, -15 }, LeftElbow = { 70, 0, 0 },
	}),
	Crumple = merge(legs(75, -125, 40, -100, -12, 12), {
		Root = { 0, 0, 0, -1.25, 0.1 }, Waist = { -48, 0, 8 }, Neck = { 35, 0, 0 },
		LeftShoulder = { -8, 0, -12 }, LeftElbow = { 15, 0, 0 },
		RightShoulder = { 25, 0, 15 }, RightElbow = { 60, 0, 0 },
	}),
	-- Super flash: kiai, fists at the hips, chest out.
	-- FINAL FINISH: face down on the floor.
	DownFace = merge(legs(-5, -10, 10, -25), {
		Root = { -86, 0, 0, -2.55, 0 }, Waist = { -4, 0, 0 }, Neck = { 25, 20, 0 },
		LeftShoulder = { 150, 0, -35 }, LeftElbow = { 25, 0, 0 },
		RightShoulder = { 30, 0, 60 }, RightElbow = { 40, 0, 0 },
	}),
	-- Standing tall over the fallen opponent, fists loose, chin up.
	StandTall = merge(legs(6, -4, -6, -4, -12, 12), {
		Root = { 0, 0, 0, 0, 0 }, Waist = { 4, 8, 0 }, Neck = { -12, -15, 0 },
		LeftShoulder = { 8, 0, -16 }, LeftElbow = { 25, 0, 0 },
		RightShoulder = { 12, 0, 18 }, RightElbow = { 35, 0, 0 },
	}),
	-- Back turned on the fallen opponent, arms crossed.
	ArmsCrossed = merge(legs(8, -6, -8, -6, -10, 10), {
		Root = { 0, 0, 0, 0, 0 }, Waist = { 6, 0, 0 }, Neck = { -8, -25, 0 },
		LeftShoulder = { 62, 0, 38 }, LeftElbow = { 118, 0, 0 },
		RightShoulder = { 58, 0, -38 }, RightElbow = { 122, 0, 0 },
	}),
	Kiai = merge(legs(28, -40, -28, -40, -20, 20), {
		Root = { 0, 0, 0, -0.55, 0 }, Waist = { 14, 0, 0 }, Neck = { -18, 0, 0 },
		LeftShoulder = { 18, 0, -42 }, LeftElbow = { 105, 0, 0 },
		RightShoulder = { 18, 0, 42 }, RightElbow = { 105, 0, 0 },
	}),
	-- Attacks: Startup (anticipation), Active (contact pose), Recovery.
	Jab = {
		Startup = merge(STANCE, { Waist = { -8, 22, 0 }, LeftShoulder = { 70, 0, -6 }, LeftElbow = { 120, 0, 0 } }),
		Active = merge(STANCE, {
			Root = { 0, 0, 0, -0.3, -0.3 }, Waist = { -12, -24, 0 },
			LeftShoulder = { 90, 0, 10 }, LeftElbow = { 0, 0, 0 },
		}),
		Recovery = merge(STANCE, { Waist = { -10, -8, 0 }, LeftShoulder = { 80, 0, 0 }, LeftElbow = { 50, 0, 0 } }),
	},
	Cross = {
		Startup = merge(STANCE, { Waist = { -6, -16, 0 }, RightShoulder = { 45, 0, 25 }, RightElbow = { 130, 0, 0 } }),
		Active = merge(merge(STANCE, legs(38, -42, -28, -6)), {
			Root = { 0, 0, 0, -0.35, -0.55 }, Waist = { -14, 34, 0 },
			RightShoulder = { 90, 0, -8 }, RightElbow = { 0, 0, 0 },
			LeftShoulder = { 55, 0, -20 }, LeftElbow = { 115, 0, 0 },
		}),
		Recovery = merge(STANCE, { Waist = { -10, 20, 0 }, RightShoulder = { 70, 0, 5 }, RightElbow = { 60, 0, 0 } }),
	},
	Elbow = {
		Startup = merge(STANCE, { Waist = { -6, -24, 0 }, RightShoulder = { 30, 0, 45 }, RightElbow = { 140, 0, 0 } }),
		Active = merge(merge(STANCE, legs(42, -50, -26, -10)), {
			Root = { 0, 0, 0, -0.45, -0.5 }, Waist = { -16, 46, 0 }, Neck = { 8, -25, 0 },
			RightShoulder = { 84, 0, -28 }, RightElbow = { 148, 0, 0 },
			LeftShoulder = { 40, 0, -25 }, LeftElbow = { 110, 0, 0 },
		}),
		Recovery = merge(STANCE, { Waist = { -10, 22, 0 }, RightShoulder = { 65, 0, 0 }, RightElbow = { 110, 0, 0 } }),
	},
	BodyBlow = {
		Startup = merge(STANCE, {
			Root = { 0, 0, 0, -0.5, 0.2 }, Waist = { -10, -35, 0 },
			RightShoulder = { -20, 0, 30 }, RightElbow = { 100, 0, 0 },
		}),
		Active = merge(legs(55, -75, -35, -15), {
			Root = { 0, 0, 0, -0.75, -0.6 }, Waist = { -28, 42, 0 }, Neck = { 15, -20, 0 },
			RightShoulder = { 55, 0, -22 }, RightElbow = { 75, 0, 0 },
			LeftShoulder = { 70, 0, -10 }, LeftElbow = { 110, 0, 0 },
		}),
		Recovery = merge(STANCE, { Waist = { -16, 20, 0 }, RightShoulder = { 45, 0, 0 }, RightElbow = { 80, 0, 0 } }),
	},
	Uppercut = {
		Startup = merge(merge(STANCE, CROUCH_LEGS), {
			Waist = { -25, -25, 0 }, RightShoulder = { 10, 0, 25 }, RightElbow = { 120, 0, 0 },
		}),
		Active = merge(legs(30, -25, -20, -30), {
			Root = { 0, 0, 0, 0, -0.2 }, Waist = { 10, 30, 0 }, Neck = { -22, 0, 0 },
			RightShoulder = { 168, 0, -8 }, RightElbow = { 22, 0, 0 },
			LeftShoulder = { 45, 0, -30 }, LeftElbow = { 95, 0, 0 },
		}),
		Recovery = merge(STANCE, legs(25, -30, -10, -25)),
	},
	SpinKick = {
		Startup = merge(STANCE, { Root = { 0, 90, 0, -0.3, 0 }, Waist = { 5, -40, 0 }, Neck = { 0, 70, 0 } }),
		Active = merge(legs(18, -20, -95, -4), {
			Root = { 0, 175, 0, -0.15, 0 }, Waist = { 22, 0, 0 }, Neck = { -10, 150, 0 },
			RightAnkle = { 60, 0, 0 },
			LeftShoulder = { 30, 0, -50 }, RightShoulder = { 20, 0, 55 },
		}),
		Recovery = merge(STANCE, { Root = { 0, 30, 0, -0.25, 0 } }),
	},
	Hammer = {
		Startup = merge(STANCE, merge(legs(-6, -12, 155, -10), {
			Root = { 0, 0, 0, 0.1, 0.2 }, Waist = { 18, 0, 0 },
			LeftShoulder = { 40, 0, -60 }, RightShoulder = { 40, 0, 60 },
		})),
		Active = merge(legs(-4, -10, 62, 0), {
			Root = { 0, 0, 0, -0.2, -0.4 }, Waist = { -28, 0, 0 }, Neck = { 20, 0, 0 },
			LeftShoulder = { -20, 0, -55 }, RightShoulder = { -20, 0, 55 },
			LeftElbow = { 20, 0, 0 }, RightElbow = { 20, 0, 0 },
		}),
		Recovery = merge(STANCE, legs(20, -30, 30, -50)),
	},
	Sweep = {
		Startup = merge(merge(STANCE, CROUCH_LEGS), { Root = { 0, 0, 0, -1.3, 0 }, Waist = { -30, -30, 0 } }),
		Active = merge(legs(105, -145, 84, 0), {
			Root = { 0, 0, 0, -1.65, 0.3 }, Waist = { -18, 40, 0 }, Neck = { 25, -30, 0 },
			LeftShoulder = { 45, 0, -50 }, LeftElbow = { 20, 0, 0 },
			RightShoulder = { 40, 0, 40 }, RightElbow = { 20, 0, 0 },
		}),
		Recovery = merge(STANCE, CROUCH_LEGS),
	},
	LowKick = {
		Startup = merge(merge(STANCE, CROUCH_LEGS), { RightHip = { 50, 0, 5 }, RightKnee = { -90, 0, 0 } }),
		Active = merge(merge(STANCE, CROUCH_LEGS), {
			Waist = { -10, -20, 0 }, RightHip = { 82, 0, 5 }, RightKnee = { -4, 0, 0 }, RightAnkle = { -30, 0, 0 },
		}),
		Recovery = merge(STANCE, CROUCH_LEGS),
	},
	AirKick2 = {
		Startup = merge(STANCE, legs(80, -115, 95, -125)),
		Active = merge(legs(58, -2, 85, -125), {
			Root = { -28, 0, 0, 0, 0 }, Waist = { -10, 15, 0 }, Neck = { 30, 0, 0 },
			LeftShoulder = { -30, 0, -35 }, RightShoulder = { -40, 0, 35 },
		}),
		Recovery = merge(STANCE, legs(50, -80, 30, -60)),
	},
	AirSmash = {
		Startup = merge(STANCE, merge(legs(70, -110, 60, -100), {
			Waist = { 15, 0, 0 }, LeftShoulder = { 175, 0, 15 }, RightShoulder = { 175, 0, -15 },
			LeftElbow = { 40, 0, 0 }, RightElbow = { 40, 0, 0 },
		})),
		Active = merge(legs(40, -60, 20, -40), {
			Root = { -40, 0, 0, 0, 0 }, Waist = { -25, 0, 0 }, Neck = { 30, 0, 0 },
			LeftShoulder = { 70, 0, 12 }, RightShoulder = { 70, 0, -12 },
			LeftElbow = { 0, 0, 0 }, RightElbow = { 0, 0, 0 },
		}),
		Recovery = merge(STANCE, legs(50, -80, 30, -60)),
	},
	PalmStrike = {
		Startup = merge(STANCE, {
			Waist = { -5, -35, 0 }, RightShoulder = { 10, 0, 30 }, RightElbow = { 110, 0, 0 },
			LeftShoulder = { 20, 0, -20 }, LeftElbow = { 100, 0, 0 },
		}),
		Active = merge(legs(55, -65, -35, -10), {
			Root = { 0, 0, 0, -0.45, -0.6 }, Waist = { -15, 30, 0 }, Neck = { 10, -20, 0 },
			RightShoulder = { 88, 0, -10 }, RightElbow = { 5, 0, 0 }, RightWrist = { -60, 0, 0 },
			LeftShoulder = { 86, 0, 12 }, LeftElbow = { 10, 0, 0 }, LeftWrist = { -60, 0, 0 },
		}),
		Recovery = merge(STANCE, { Waist = { -12, 18, 0 } }),
	},
	DragonTornado = {
		Startup = merge(merge(STANCE, CROUCH_LEGS), { Root = { 0, -60, 0, -1, 0 }, Waist = { -20, -30, 0 } }),
		Active = merge(legs(-10, -60, 100, -10, -5, 30), {
			Root = { 0, 0, 0, 0.6, 0 }, Waist = { 5, 0, 0 }, Neck = { -10, 0, 0 },
			LeftShoulder = { 80, 0, -70 }, RightShoulder = { 80, 0, 70 }, LeftElbow = { 10, 0, 0 }, RightElbow = { 10, 0, 0 },
		}),
		Active2 = merge(legs(100, -10, -10, -60, -30, 5), {
			Root = { 0, 180, 0, 0.9, 0 }, Waist = { 5, 0, 0 }, Neck = { -10, 0, 0 },
			LeftShoulder = { 80, 0, -70 }, RightShoulder = { 80, 0, 70 }, LeftElbow = { 10, 0, 0 }, RightElbow = { 10, 0, 0 },
		}),
		Recovery = merge(STANCE, legs(40, -70, 20, -50)),
	},
	DragonFist = {
		Startup = merge(merge(STANCE, CROUCH_LEGS), { Waist = { -28, -25, 0 }, RightShoulder = { 10, 0, 25 }, RightElbow = { 125, 0, 0 } }),
		Active = merge(legs(25, -20, -25, -40), {
			Root = { 0, 0, 0, 0.6, -0.2 }, Waist = { 14, 30, 0 }, Neck = { -28, 0, 0 },
			RightShoulder = { 175, 0, -6 }, RightElbow = { 10, 0, 0 },
			LeftShoulder = { 40, 0, -32 }, LeftElbow = { 100, 0, 0 },
		}),
		Active2 = merge(legs(-25, -40, 25, -20), {
			Root = { 0, 0, 0, 0.9, -0.2 }, Waist = { 14, -30, 0 }, Neck = { -28, 0, 0 },
			LeftShoulder = { 175, 0, 6 }, LeftElbow = { 10, 0, 0 },
			RightShoulder = { 40, 0, 32 }, RightElbow = { 100, 0, 0 },
		}),
		Recovery = merge(STANCE, legs(30, -40, -10, -30)),
	},
	CrescentMoon = {
		Startup = merge(STANCE, legs(80, -110, 70, -100)),
		Active = merge(legs(30, -60, 120, -2), {
			Root = { -60, 0, 0, 0.5, 0 }, Waist = { -10, 0, 0 },
			LeftShoulder = { -30, 0, -50 }, RightShoulder = { -30, 0, 50 },
		}),
		Active2 = merge(legs(120, -2, 30, -60), {
			Root = { -200, 0, 0, 0.7, 0 }, Waist = { -10, 0, 0 },
			LeftShoulder = { -30, 0, -50 }, RightShoulder = { -30, 0, 50 },
		}),
		Recovery = merge(STANCE, legs(50, -80, 30, -60)),
	},
	RisingWind = {
		Startup = merge(merge(STANCE, CROUCH_LEGS), { Waist = { -20, -20, 0 } }),
		Active = merge(legs(-6, -10, 110, -2, -5, 20), {
			Root = { 0, 0, 0, 0.4, 0.1 }, Waist = { 14, -25, 0 },
			LeftShoulder = { 40, 0, -50 }, RightShoulder = { 30, 0, 50 },
		}),
		Active2 = merge(legs(110, -2, -6, -10, -20, 5), {
			Root = { 0, 0, 0, 0.7, 0.1 }, Waist = { 14, 25, 0 },
			LeftShoulder = { 30, 0, -50 }, RightShoulder = { 40, 0, 50 },
		}),
		Recovery = merge(STANCE, legs(30, -50, 30, -50)),
	},
	KiFlurry = {
		Startup = merge(STANCE, { Waist = { -10, -20, 0 }, RightShoulder = { 40, 0, 25 }, RightElbow = { 130, 0, 0 } }),
		Active = merge(merge(STANCE, legs(40, -48, -26, -10)), {
			Root = { 0, 0, 0, -0.4, -0.4 }, Waist = { -14, 32, 0 },
			RightShoulder = { 90, 0, -10 }, RightElbow = { 0, 0, 0 },
			LeftShoulder = { 60, 0, -20 }, LeftElbow = { 115, 0, 0 },
		}),
		Active2 = merge(merge(STANCE, legs(40, -48, -26, -10)), {
			Root = { 0, 0, 0, -0.4, -0.45 }, Waist = { -14, -28, 0 },
			LeftShoulder = { 90, 0, 10 }, LeftElbow = { 0, 0, 0 },
			RightShoulder = { 60, 0, 20 }, RightElbow = { 115, 0, 0 },
		}),
		Recovery = merge(STANCE, { Waist = { -10, 15, 0 } }),
	},
	ThunderHeel = {
		Startup = merge(merge(STANCE, CROUCH_LEGS), { Waist = { -25, 0, 0 } }),
		Active = merge(legs(-20, -40, 130, 0), {
			Root = { -30, 0, 0, 0.3, 0 }, Waist = { 10, 0, 0 }, Neck = { -20, 0, 0 },
			LeftShoulder = { -40, 0, -60 }, RightShoulder = { -40, 0, 60 },
		}),
		Recovery = merge(STANCE, legs(30, -50, 20, -40)),
	},
	KiBlast = {
		Startup = merge(STANCE, merge(legs(35, -50, -25, -25, -15, 15), {
			Root = { 0, 0, 0, -0.5, 0.2 }, Waist = { -5, -40, 0 },
			LeftShoulder = { 30, 0, 30 }, LeftElbow = { 110, 0, 0 },
			RightShoulder = { 30, 0, -10 }, RightElbow = { 110, 0, 0 },
		})),
		Active = merge(legs(45, -55, -30, -10, -15, 15), {
			Root = { 0, 0, 0, -0.5, -0.4 }, Waist = { -12, 10, 0 }, Neck = { 6, -10, 0 },
			LeftShoulder = { 90, 0, 12 }, LeftElbow = { 0, 0, 0 }, LeftWrist = { -70, 0, 0 },
			RightShoulder = { 90, 0, -12 }, RightElbow = { 0, 0, 0 }, RightWrist = { -70, 0, 0 },
		}),
		Recovery = merge(STANCE, { Waist = { -10, 0, 0 } }),
	},
	KiChase = { -- leaping flying knee wrapped in ki
		Startup = merge(merge(STANCE, CROUCH_LEGS), { Waist = { -30, 0, 0 }, LeftShoulder = { -40, 0, -30 }, RightShoulder = { -40, 0, 30 } }),
		Active = merge(legs(110, -140, -20, -30), {
			Root = { -25, 0, 0, 0.3, 0 }, Waist = { -15, 10, 0 }, Neck = { 20, 0, 0 },
			LeftShoulder = { -50, 0, -40 }, LeftElbow = { 20, 0, 0 },
			RightShoulder = { 100, 0, -10 }, RightElbow = { 40, 0, 0 },
		}),
		Recovery = merge(STANCE, legs(50, -80, 30, -60)),
	},
	Finale = { -- double ki fist driven through the target
		Startup = merge(STANCE, merge(legs(40, -60, -30, -30, -15, 15), {
			Root = { 0, 0, 0, -0.6, 0.5 }, Waist = { 0, -50, 0 }, Neck = { 10, 40, 0 },
			LeftShoulder = { 20, 0, 40 }, LeftElbow = { 120, 0, 0 },
			RightShoulder = { -40, 0, 30 }, RightElbow = { 110, 0, 0 },
		})),
		Active = merge(legs(70, -80, -50, -6, -15, 10), {
			Root = { 0, 0, 0, -0.7, -1.0 }, Waist = { -30, 30, 0 }, Neck = { 15, -25, 0 },
			LeftShoulder = { 92, 0, 18 }, LeftElbow = { 5, 0, 0 },
			RightShoulder = { 92, 0, -10 }, RightElbow = { 0, 0, 0 },
		}),
		Recovery = merge(STANCE, { Root = { 0, 0, 0, -0.5, -0.4 }, Waist = { -20, 20, 0 } }),
	},
	Kick = {
		Startup = merge(STANCE, merge(legs(-8, -12, 85, -115), { Waist = { 0, -22, 0 } })),
		Active = merge(STANCE, {
			Root = { 0, 0, 0, -0.05, 0.1 }, Waist = { 12, -38, -14 }, Neck = { -6, 25, 0 },
			LeftHip = { -6, 0, -5 }, LeftKnee = { -10, 0, 0 }, LeftAnkle = { 16, 0, 0 },
			RightHip = { 96, 0, 24 }, RightKnee = { -4, 0, 0 }, RightAnkle = { -35, 0, 0 },
			LeftShoulder = { 40, 0, -45 }, RightShoulder = { 30, 0, 50 },
		}),
		Recovery = merge(STANCE, legs(10, -20, 50, -90)),
	},
	Smash = {
		Startup = merge(STANCE, {
			Root = { 0, 0, 0, -0.4, 0.45 }, Waist = { -4, -42, 0 }, Neck = { 10, 30, 0 },
			RightShoulder = { -35, 0, 35 }, RightElbow = { 95, 0, 0 },
			LeftShoulder = { 92, 0, 0 }, LeftElbow = { 15, 0, 0 },
		}),
		Active = merge(legs(62, -72, -42, -8), {
			Root = { 0, 0, 0, -0.55, -0.85 }, Waist = { -26, 46, 0 }, Neck = { 10, -30, 0 },
			RightShoulder = { 94, 0, -6 }, RightElbow = { 0, 0, 0 },
			LeftShoulder = { -30, 0, -30 }, LeftElbow = { 60, 0, 0 },
		}),
		Recovery = merge(STANCE, { Root = { 0, 0, 0, -0.4, -0.3 }, Waist = { -18, 25, 0 }, RightShoulder = { 70, 0, 0 }, RightElbow = { 40, 0, 0 } }),
	},
	Rising = {
		Startup = merge(merge(STANCE, CROUCH_LEGS), {
			Waist = { -28, -22, 0 }, RightShoulder = { 15, 0, 25 }, RightElbow = { 125, 0, 0 },
		}),
		Active = merge(legs(32, -12, -30, -40), {
			Root = { 0, 0, 0, 0.35, -0.2 }, Waist = { 14, 28, 0 }, Neck = { -25, 0, 0 },
			RightShoulder = { 176, 0, -6 }, RightElbow = { 8, 0, 0 },
			LeftShoulder = { 40, 0, -32 }, LeftElbow = { 90, 0, 0 },
		}),
		Recovery = merge(STANCE, legs(30, -30, -10, -30)),
	},
	AirKick = {
		Startup = merge(STANCE, legs(95, -125, 80, -115)),
		Active = merge(legs(80, -125, 58, -2), {
			Root = { -32, 0, 0, 0, 0 }, Waist = { -10, -15, 0 }, Neck = { 30, 0, 0 },
			LeftShoulder = { -40, 0, -35 }, RightShoulder = { -30, 0, 35 },
			LeftElbow = { 30, 0, 0 }, RightElbow = { 30, 0, 0 },
		}),
		Recovery = merge(STANCE, legs(50, -80, 30, -60)),
	},
}

Poses.KaienRush = { Startup = Poses.Kiai, Active = Poses.Smash.Active, Recovery = Poses.Smash.Recovery }
Poses.Awakening = { Startup = Poses.Kiai, Active = Poses.Finale.Active, Recovery = Poses.Finale.Recovery }

local IDENTITY = { 0, 0, 0, 0, 0 }

local function lerpPose(a, b, t)
	local out = {}
	for name, vb in b do
		if not a[name] then
			local v = {}
			for i = 1, 5 do v[i] = (vb[i] or 0) * t end
			out[name] = v
		end
	end
	for name, va in a do
		local vb = b[name] or IDENTITY
		local v = {}
		for i = 1, 5 do
			local x, y = va[i] or 0, vb[i] or 0
			v[i] = x + (y - x) * t
		end
		out[name] = v
	end
	return out
end

local function cycle(keys, time, cyclesPerSecond)
	local p = (time * cyclesPerSecond) % 1 * #keys
	local i = math.floor(p)
	return lerpPose(keys[i + 1], keys[(i + 1) % #keys + 1], p - i)
end

local AnimationController = {}

function AnimationController.new(model)
	local self = { joints = {}, model = model, lastKey = nil, shake = 0 }
	for _, joint in model:GetDescendants() do
		if joint:IsA("Motor6D") then self.joints[joint.Name] = { joint = joint, base = joint.C0 } end
	end
	return setmetatable(self, { __index = AnimationController })
end

-- view: { state, move, moveFrame, hitstop, victory } from the interpolated snapshot.
-- Attack pose for a given authoritative frame. Startup eases from the stance into the
-- anticipation, the contact pose snaps in on the first active frame (anime impact), and the
-- recovery settles back to the guard. Progress is quantized to poseRate (held poses), and
-- multi-hit moves alternate two contact poses, one per hit.
local function attackPose(id, frame, poseRate)
	local m, set = MoveData.Moves[id], Poses[id]
	local function quantize(progress, length)
		local steps = math.max(1, math.floor(length * poseRate / 60 + 0.5))
		return math.clamp(math.floor(progress * steps + 0.5) / steps, 0, 1)
	end
	if frame <= m.startup then
		if m.meterCost then return set.Startup, id .. "S" end -- held kiai during the super flash
		local t = quantize(frame / m.startup, m.startup)
		return lerpPose(STANCE, set.Startup, math.min(1, t * 1.5)), id .. "S" .. t
	elseif frame <= m.startup + m.active then
		if set.Active2 and m.hits and m.hits > 1 then
			local beat = math.floor((frame - m.startup - 1) / m.hitInterval) % 2
			return if beat == 0 then set.Active else set.Active2, id .. "A" .. beat
		end
		return set.Active, id .. "A"
	end
	local r = (frame - m.startup - m.active) / m.recovery
	if r < 0.45 then
		local t = quantize(r / 0.45, m.recovery * 0.45)
		return lerpPose(set.Active, set.Recovery, t), id .. "R" .. t
	end
	local t = quantize((r - 0.45) / 0.55, m.recovery * 0.55)
	return lerpPose(set.Recovery, STANCE, t), id .. "E" .. t
end

-- view: { state, move, moveFrame, hitstop, victory, intro, vx, facing, combo } from the
-- interpolated snapshot.
function AnimationController:update(view, time, poseRate)
	local state = view.state
	local stepped = math.floor(time * poseRate) / poseRate
	local pose, key
	if view.pose and Poses[view.pose] and Poses[view.pose].Root then
		pose, key = Poses[view.pose], "Pose" .. view.pose -- staged by a cinematic
	elseif state == "Attack" and Poses[view.move] then
		pose, key = attackPose(view.move, view.moveFrame, poseRate)
	elseif view.victory then
		pose, key = Poses.Victory, "Victory"
	elseif view.intro then
		pose, key = Poses.Kiai, "Intro"
	elseif state == "Walking" then
		local backward = (view.vx or 0) * (view.facing or 1) < 0
		if backward then
			pose, key = cycle(Poses.WalkBack, stepped, 1.2), "WalkBack" .. stepped
		else
			pose, key = cycle(Poses.Walk, stepped, 1.6), "Walk" .. stepped
		end
	elseif state == "Crouching" then
		pose, key = Poses.Crouch, state
	elseif state == "Jumping" then
		pose, key = Poses.Jump, state
	elseif state == "Falling" then
		pose, key = Poses.Fall, state
	elseif state == "Dashing" then
		pose, key = Poses.Dash, state
	elseif state == "Blocking" then
		pose, key = Poses.Block, state
	elseif state == "CrouchBlocking" or state == "CrouchBlockstun" then
		pose, key = Poses.CrouchBlock, state
	elseif state == "Blockstun" then
		pose, key = Poses.Blockstun, state
	elseif state == "Hitstun" then
		-- Alternate two reactions so consecutive hits read as separate impacts.
		local variant = if (view.combo or 0) % 2 == 0 then "HitstunB" else "Hitstun"
		pose, key = Poses[variant], variant
	elseif state == "Crumple" then
		pose, key = Poses.Crumple, state
	elseif state == "GuardBroken" then
		pose, key = Poses.GuardBroken, state
	elseif state == "Launched" then
		pose, key = Poses.Launched, state
	elseif state == "Knockdown" or state == "KO" then
		pose, key = Poses.Down, "Down"
	elseif state == "GetUp" then
		pose, key = Poses.GetUp, state
	else
		pose, key = cycle(Poses.Idle, stepped, 0.9), "Idle" .. stepped
	end
	-- Impact shake on the defender while hitstop holds the contact pose.
	local shaking = view.hitstop > 0 and (state == "Hitstun" or state == "Launched" or state == "Blockstun"
		or state == "KO" or state == "Crumple")
	local jitter = if shaking then (math.floor(time * 60) % 2 * 2 - 1) * 0.12 else 0
	if key ~= self.lastKey then
		-- Impacts and hit reactions snap (anime punch); every other change eases in over a
		-- few frames so stance, walk, crouch and guard flow into each other.
		local family = key:match("^%a+") or key
		local snap = key:find("A%d?$") ~= nil or state == "Hitstun" or state == "Launched" or state == "Crumple"
			or state == "GuardBroken" or family == (self.lastKey or ""):match("^%a+")
		self.from = self.current
		self.target = pose
		self.blendStart = time
		self.blendTime = if snap or not self.from then 0 else 0.07
		self.lastKey = key
	elseif jitter == self.shake and not self.blending then
		return
	end
	self.shake = jitter
	local t = if self.blendTime > 0 then math.clamp((time - self.blendStart) / self.blendTime, 0, 1) else 1
	t = 1 - (1 - t) * (1 - t) -- ease out
	self.blending = t < 1
	local applied = if t < 1 then lerpPose(self.from, self.target, t) else self.target
	self.current = applied
	for name, info in self.joints do
		local v = applied[name]
		local offset = CFrame.identity
		if v then
			offset = CFrame.Angles(math.rad(v[1]), math.rad(v[2]), math.rad(v[3]))
			if name == "Root" then
				offset = CFrame.new(jitter, v[4] or 0, v[5] or 0) * offset
			end
		end
		info.joint.C0 = info.base * offset
	end
end

return AnimationController
