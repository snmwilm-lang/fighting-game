-- DAICHA's orb, how fluid it looks (not a test): a scripted fight played by the real simulation
-- (tests/ClipKit.luau), then the client's drawing of the orb rebuilt like in game: snapshots
-- every 2 ticks (30 a second), the frame drawn at RATE frames a second, the move's frame
-- extrapolated from the last snapshot, OrbFlight.offset as the target, OrbFlight.follow as the
-- spring. Prints how fluid its motion is:
--   luau tests/OrbQuality.luau -a SCRIPT|all [RATE] [int|frac] [why]
-- (`int`: the move's frame rounded down, like before 0.23.3)
--   jitter   the mean shake of its speed from one frame to the next (studs/s): the stutter of
--            a target moving by steps; lower is smoother;
--   stalls   frames where it stops dead in mid-flight then goes on;
--   jump     its biggest move in one frame (studs): a teleport shows here;
--   accel    its 99th-percentile acceleration (studs/s²): the hardest jolts.
local Config = require("../src/shared/CombatConfig")
local MoveData = require("../src/shared/MoveData")
local OrbFlight = require("../src/shared/OrbFlight")
local ClipKit = require("./ClipKit")

local args = { ... }
local scriptName = args[1] or "showcase"
local rate = tonumber(args[2]) or 120
local intFrames = args[3] == "int"

local ROLE_OF = {}
for _, kit in MoveData.Kits do
	if kit.Roles then
		for role, id in kit.Roles do ROLE_OF[id] = role end
	end
end

local OrbQuality = {}
OrbQuality.why = args[4] == "why"
OrbQuality.dump = args[4] == "dump" -- (every drawn frame: S time speed x y, for a chart)

function OrbQuality.measure(script, fps, int)
	local views = {}
	ClipKit.play("DAICHA", script, 60, function(info) views[info.tick] = info.views[1] end)
	local tickRate, snapEvery = Config.TickRate, 2
	local spring, tight, last, lastV = nil, 0, nil, nil
	local clock, snaps, skip = {}, 0, false
	local shownX, shownY, lastOffset
	local speeds, accels, jump, stalls, jitter, n = {}, {}, 0, 0, 0, 0
	local positions, labels = {}, {}
	local dt = 1 / fps
	local duration = #views / tickRate
	local t = 0
	while t < duration do
		local snapTick = math.max(1, math.floor(t * tickRate / snapEvery) * snapEvery)
		local view = views[snapTick]
		if view then
			local ahead = t - snapTick / tickRate
			local m = view.move and MoveData.Moves[view.move]
			local frame = view.moveFrame
			if m then
				local extra = if (view.hitstop or 0) > 0 then 0 else ahead * tickRate
				frame = math.min(if int then view.moveFrame + math.floor(ahead * tickRate) else view.moveFrame + extra, MoveData.total(m))
			end
			if not int then frame = OrbFlight.clock(clock, view.state == "Attack" and view.move or nil, frame or 0, lastOffset) end
			local shown = { state = view.state, move = view.move, moveFrame = frame }
			local id = view.state == "Attack" and view.move or nil
			local o = OrbFlight.offset(shown, id and MoveData.Moves[id], id and ROLE_OF[id], t, if int then nil else clock.from)
			lastOffset = o
			-- (the body as the client draws it: extrapolated, then eased, init.client.luau)
			local still = (view.hitstop or 0) > 0
			local alpha = 1 - math.exp(-35 * dt)
			local tx = view.x + (if still then 0 else (view.vx or 0) * ahead)
			local ty = math.max(0, view.y + (if still then 0 else (view.vy or 0) * ahead))
			shownX = if shownX then shownX + (tx - shownX) * alpha else tx
			shownY = if shownY then shownY + (ty - shownY) * alpha else ty
			local x = shownX
			local target = { x + view.facing * o.fwd, shownY + o.up, o.side }
			if not spring then spring = { p = { target[1], target[2], target[3] }, v = { 0, 0, 0 } } end
			local want = if view.state == "Attack" then 1 else 0
			if int then
				OrbFlight.follow(spring, target, dt, view.state == "Attack")
			else
				tight += (want - tight) * (1 - math.exp(-dt * 14))
				OrbFlight.follow(spring, target, dt, tight, { x, shownY })
			end
			if spring.snapped or (last and math.abs(spring.p[1] - last[1]) > 5) then snaps += 1; skip = true end
			local p = { spring.p[1], spring.p[2], spring.p[3] }
			table.insert(positions, p)
			table.insert(labels, string.format("t%.3f tick%d %s %s f%.2f", t, snapTick, view.state, tostring(view.move), frame or -1))
			if skip then
				skip, last, lastV = false, nil, nil -- (a teleport: the orb re-forms there, not a jolt)
			end
			if last then
				local v = { (p[1] - last[1]) / dt, (p[2] - last[2]) / dt, (p[3] - last[3]) / dt }
				local speed = math.sqrt(v[1] ^ 2 + v[2] ^ 2 + v[3] ^ 2)
				jump = math.max(jump, speed * dt)
				table.insert(speeds, speed)
				if OrbQuality.dump then print(string.format("S %.4f %.3f %.3f %.3f", t, speed, p[1], p[2])) end
				if lastV then
					local a = math.sqrt((v[1] - lastV[1]) ^ 2 + (v[2] - lastV[2]) ^ 2 + (v[3] - lastV[3]) ^ 2) / dt
					table.insert(accels, a)
				end
				lastV = v
			end
			last = p
		end
		t += dt
	end
	for i = 2, #speeds - 1 do
		local around = (speeds[i - 1] + speeds[i + 1]) / 2
		jitter += math.abs(speeds[i] - around)
		n += 1
		if around > 3 and speeds[i] < around * 0.35 then
			stalls += 1
			if OrbQuality.why then print("  stall", labels[i + 1], string.format("%.1f vs %.1f", speeds[i], around)) end
		end
	end
	if OrbQuality.why then
		local worst = {}
		for i = 2, #speeds - 1 do table.insert(worst, { math.abs(speeds[i] - (speeds[i - 1] + speeds[i + 1]) / 2), i }) end
		table.sort(worst, function(a, b) return a[1] > b[1] end)
		for k = 1, math.min(12, #worst) do print("  shake", labels[worst[k][2] + 1], string.format("%.1f", worst[k][1])) end
	end
	table.sort(accels)
	return {
		jitter = jitter / math.max(1, n),
		stalls = stalls,
		jump = jump,
		accel = accels[math.max(1, math.floor(#accels * 0.99))] or 0,
		frames = #positions,
		snaps = snaps,
	}
end

if args[1] then -- (run with -a; required by a test: the module only)
	local scripts = if scriptName == "all" then { "showcase", "moves", "combo", "heavy", "routes", "walk" } else { scriptName }
	for _, s in scripts do
		local q = OrbQuality.measure(s, rate, intFrames)
		print(string.format("%-9s jitter %6.2f  stalls %3d  jump %5.2f  accel %8.0f  re-formed %d  (%d frames at %d fps)",
			s, q.jitter, q.stalls, q.jump, q.accel, q.snaps, q.frames, rate))
	end
end

return OrbQuality
