--!strict
--[[
	The local fighter's drawing ahead of the server (Wilhem, 0.25.1: « quand t'appuies vite sur
	Q ou D, le perso recule, se retourne et revient à sa place »). Pure: no Roblox API, no
	require.

	The snapshot shows where the server had the fighter; the inputs sent since (one round trip
	plus the time since that snapshot) are not in it yet. The drawing adds what those inputs
	will do: the speed asked for, frame by frame, summed over that window. A change of
	direction then bends the path smoothly (the old speed leaves the window as the new one
	enters it), where the old drawing (held speed x lead) jumped from one side to the other.
	A dash pressed is predicted the same way (its speed for its length).
]]
local Prediction = {}

local KEEP = 0.6 -- seconds of history kept (more than any window)

export type History = { samples: { { t: number, dt: number, vx: number } } }

function Prediction.new(): History
	return { samples = {} }
end

-- The speed the inputs ask for this frame (studs/s): the dash's for its length after a press,
-- else the walk (none while crouching or guarding, or when the fighter cannot move freely).
function Prediction.velocity(free: boolean, axis: number, crouch: boolean, block: boolean, walkSpeed: number,
	sinceDash: number, dashSeconds: number, dashSpeed: number, facing: number): number
	if not free then return 0 end
	if sinceDash >= 0 and sinceDash < dashSeconds and not crouch and not block then
		local dir = if math.abs(axis) > 0.1 then (if axis > 0 then 1 else -1) else facing
		return dir * dashSpeed
	end
	if crouch or block then return 0 end
	return axis * walkSpeed
end

function Prediction.record(h: History, now: number, dt: number, vx: number)
	table.insert(h.samples, { t = now, dt = dt, vx = vx })
	while #h.samples > 0 and h.samples[1].t < now - KEEP do
		table.remove(h.samples, 1)
	end
end

-- How far the inputs of the last `window` seconds carry the fighter (studs): each frame's
-- speed times its share of the window (the oldest frame counted only for its part inside).
function Prediction.offset(h: History, now: number, window: number): number
	local from = now - window
	local sum = 0
	for _, s in h.samples do
		local start = s.t - s.dt
		if s.t > from then
			local inside = s.t - math.max(start, from)
			sum += s.vx * math.max(0, inside)
		end
	end
	return sum
end

-- The window not yet in the snapshot: the round trip plus the time since it arrived, capped.
function Prediction.window(rttSeconds: number, sinceSnapshot: number): number
	return math.clamp(rttSeconds + sinceSnapshot, 0, 0.3)
end

return Prediction
