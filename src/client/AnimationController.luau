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

local function lerpPose(a, b, t)
	local out = {}
	for name, va in a do
		local vb = b[name] or va
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
function AnimationController:update(view, time, poseRate)
	local state = view.state
	local stepped = math.floor(time * poseRate) / poseRate
	local pose, key
	if state == "Attack" and Poses[view.move] then
		local phase = MoveData.phase(MoveData.Moves[view.move], view.moveFrame)
		pose, key = Poses[view.move][phase], view.move .. phase
	elseif view.victory then
		pose, key = Poses.Victory, "Victory"
	elseif state == "Walking" then
		pose, key = cycle(Poses.Walk, stepped, 1.6), "Walk" .. stepped
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
		pose, key = Poses.Hitstun, state
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
	local shaking = view.hitstop > 0 and (state == "Hitstun" or state == "Launched" or state == "Blockstun" or state == "KO")
	local jitter = if shaking then (math.floor(time * 60) % 2 * 2 - 1) * 0.12 else 0
	if key == self.lastKey and jitter == self.shake then return end
	self.lastKey, self.shake = key, jitter
	for name, info in self.joints do
		local v = pose[name]
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
