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
local Animator = require("../src/shared/Animator")

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
	local views, bodies = {}, {}
	local OrbClearance = require("./OrbClearance")
	ClipKit.play("DAICHA", script, 60, function(info)
		views[info.tick] = info.views[1]
		local v, w = info.views[1], info.views[2]
		local push = Animator.spacing(v.x, v.y, w.x, w.y)
		local side = if w.x >= v.x then 1 else -1
		bodies[info.tick] = { boxes = OrbClearance.boxes(info.parts[1]), x = v.x - side * push, y = v.y }
	end)
	local tickRate, snapEvery = Config.TickRate, 2
	local spring, tight, last, lastV = nil, 0, nil, nil
	local clock, snaps, skip = {}, 0, false
	local shownX, shownY, lastOffset
	local inside, touching, onScreen = 0, 0, 0
	local relSpeeds, lastRel = {}, nil
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
			local o
			if int or not OrbFlight.LEAD then
				o = OrbFlight.offset(shown, id and MoveData.Moves[id], id and ROLE_OF[id], t, if int then nil else clock.from)
			else
				-- (the spring's target a little ahead on the path: on time once followed)
				local ahead = { state = shown.state, move = shown.move, moveFrame = OrbFlight.leadFrame(shown, id and MoveData.Moves[id]) }
				o = OrbFlight.offset(ahead, id and MoveData.Moves[id], id and ROLE_OF[id], t, clock.from)
			end
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
			-- (kept off her body, posed as drawn this frame: like the client, before the spring)
			-- (her pose of that tick, carried to where the client draws her body now)
			local posed = bodies[math.max(1, math.floor(t * tickRate))]
			local body = nil
			if posed then
				body = {}
				local bx, by = x - posed.x, shownY - posed.y
				for i, b in posed.boxes do
					local c = table.clone(b)
					c[1] += bx
					c[2] += by
					body[i] = c
				end
			end
			local form = OrbFlight.form(shown, id and MoveData.Moves[id], id and ROLE_OF[id], t)
			local want = if view.state == "Attack" then 1 else 0
			local p
			if int or not OrbFlight.place then
				if not spring then spring = { p = { target[1], target[2], target[3] }, v = { 0, 0, 0 } } end
				OrbFlight.follow(spring, target, dt, view.state == "Attack")
				p = { spring.p[1], spring.p[2], spring.p[3] }
			else
				spring = spring or {}
				tight += (want - tight) * (1 - math.exp(-dt * 14))
				p = OrbFlight.place(spring, target, dt, tight, { x, shownY }, body, math.max(form.radius, 0.05),
					OrbFlight.avoidDirection(view.state, view.facing, o), 0)
			end
			if spring.snapped or (last and math.abs(p[1] - last[1]) > 5) then snaps += 1; skip = true end
			-- (unseen: thrown away, squeezed to a point as she vanishes, a disc: not measured)
			if form.shape ~= "ball" or form.radius < 0.12 then skip = true end
			-- (the orb as drawn, against her body as drawn: inside her, or stuck to her)
			if body and form.shape == "ball" and form.radius > 0.05 then
				local closest, part = math.huge, nil
				for _, b in body do
					local dx, dy, dz = p[1] - b[1], p[2] - b[2], p[3] - b[3]
					local lx = math.abs(dx * b[4] + dy * b[5] + dz * b[6]) - b[13]
					local ly = math.abs(dx * b[7] + dy * b[8] + dz * b[9]) - b[14]
					local lz = math.abs(dx * b[10] + dy * b[11] + dz * b[12]) - b[15]
					local d = math.sqrt(math.max(lx, 0) ^ 2 + math.max(ly, 0) ^ 2 + math.max(lz, 0) ^ 2) + math.min(math.max(lx, ly, lz), 0)
					if d - form.radius < closest then closest, part = d - form.radius, b.name end
				end
				if closest < 0 then
					inside += 1
					if OrbQuality.why then
						print(string.format("  in-body t%.3f %s %s f%.2f  %.2f %s  orb(%.2f,%.2f,%.2f) target(%.2f,%.2f,%.2f)", t, view.state, tostring(view.move),
							frame or -1, closest, tostring(part), (p[1] - x) * view.facing, p[2] - shownY, p[3], (target[1] - x) * view.facing, target[2] - shownY, target[3]))
					end
				end
				if closest < 0.15 then touching += 1 end
				if OrbFlight.screenClearance and OrbFlight.screenClearance(p[1], p[2], body, form.radius) < 0 then onScreen += 1 end
			end
			table.insert(positions, p)
			-- (and round her: what the eye sees following her)
			local rp = { p[1] - x, p[2] - shownY, p[3] }
			if lastRel and not skip then
				local rv = { (rp[1] - lastRel[1]) / dt, (rp[2] - lastRel[2]) / dt, (rp[3] - lastRel[3]) / dt }
				table.insert(relSpeeds, math.sqrt(rv[1] ^ 2 + rv[2] ^ 2 + rv[3] ^ 2))
			elseif skip then
				table.insert(relSpeeds, false)
			end
			lastRel = rp
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
	-- zigzag: its speed going up, down, up again from one frame to the next (a stutter the eye
	-- sees), by more than 3 studs/s each time
	local zigzag = 0
	for i = 2, #speeds - 2 do
		local a, b, c = speeds[i] - speeds[i - 1], speeds[i + 1] - speeds[i], speeds[i + 2] - speeds[i + 1]
		if a * b < 0 and b * c < 0 and math.abs(a) > 3 and math.abs(b) > 3 and math.abs(c) > 3 then zigzag += 1 end
	end
	local relZigzag = 0
	for i = 2, #relSpeeds - 2 do
		local s0, s1, s2, s3 = relSpeeds[i - 1], relSpeeds[i], relSpeeds[i + 1], relSpeeds[i + 2]
		if s0 and s1 and s2 and s3 then
			local a, b, c = s1 - s0, s2 - s1, s3 - s2
			if a * b < 0 and b * c < 0 and math.abs(a) > 3 and math.abs(b) > 3 and math.abs(c) > 3 then relZigzag += 1 end
		end
	end
	table.sort(accels)
	return {
		relZigzag = relZigzag,
		zigzag = zigzag,
		jitter = jitter / math.max(1, n),
		stalls = stalls,
		jump = jump,
		accel = accels[math.max(1, math.floor(#accels * 0.99))] or 0,
		frames = #positions,
		snaps = snaps,
		inside = inside,
		onScreen = onScreen,
		touching = touching,
	}
end

if args[1] then -- (run with -a; required by a test: the module only)
	local scripts = if scriptName == "all" then { "showcase", "moves", "combo", "heavy", "routes", "walk" } else { scriptName }
	for _, s in scripts do
		local q = OrbQuality.measure(s, rate, intFrames)
		print(string.format("%-9s zigzag %3d  jitter %6.2f  stalls %3d  jump %5.2f  accel %8.0f  re-formed %d  in-body %d touching %d on-screen %d  (%d frames at %d fps)",
			s, q.zigzag, q.jitter, q.stalls, q.jump, q.accel, q.snaps, q.inside, q.touching, q.onScreen, q.frames, rate))
	end
end

return OrbQuality
