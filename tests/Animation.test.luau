-- Offline checks of the animation: every pose and timeline is rebuilt with forward
-- kinematics on the real KAI rig geometry (RigSpec) and on a smaller avatar-like body.
-- Run from the repository root:
--   luau tests/Animation.test.luau
local Config = require("../src/shared/CombatConfig")
local MoveData = require("../src/shared/MoveData")
local Sim = require("../src/shared/CombatSimulation")
local FighterAI = require("../src/shared/FighterAI")
local RigSpec = require("../src/shared/RigSpec")
local K = require("../src/shared/Kinematics")
local Poses = require("../src/shared/PoseLibrary")
local Animator = require("../src/shared/Animator")
local Retarget = require("../src/shared/Retarget")
local T = require("./TestKit")
local test, expect = T.test, T.expect

local KAI = K.fromSpec(RigSpec.KAI)

-- A different body: shorter legs, longer arms, bigger head (like many Roblox avatars).
local function avatarSpec()
	local parts, joints = {}, {}
	local legScale, armScale = 0.82, 1.1
	for name, p in RigSpec.KAI.parts do
		local pos, size = { p.pos[1], p.pos[2], p.pos[3] }, { p.size[1], p.size[2], p.size[3] }
		if name:find("Leg") or name:find("Foot") then
			pos[2] = -0.3 + (pos[2] + 0.3) * legScale
			size[2] *= legScale
		elseif name:find("Arm") or name:find("Hand") then
			pos[2] = 1.5 + (pos[2] - 1.5) * armScale
		elseif name == "Head" then
			size = { 1.4, 1.3, 1.3 }
		end
		parts[name] = { pos = pos, size = size }
	end
	for _, j in RigSpec.KAI.joints do
		local pivot = { j.pivot[1], j.pivot[2], j.pivot[3] }
		if j.name:find("Hip") or j.name:find("Knee") or j.name:find("Ankle") then
			pivot[2] = -0.3 + (pivot[2] + 0.3) * legScale
		elseif j.name:find("Elbow") or j.name:find("Wrist") then
			pivot[2] = 1.5 + (pivot[2] - 1.5) * armScale
		end
		table.insert(joints, { name = j.name, part0 = j.part0, part1 = j.part1, pivot = pivot })
	end
	return { parts = parts, joints = joints }
end
local AVATAR = K.fromSpec(avatarSpec())

local function newAnimator(skel)
	return Animator.new({ poses = Poses, moves = MoveData.Moves, kin = K, config = Config, skeleton = skel or KAI,
		kits = MoveData.Kits, moveKit = MoveData.MoveKit })
end

local function finite(n)
	return type(n) == "number" and n == n and math.abs(n) < 1e5
end

local function checkPose(pose, label, slack)
	slack = slack or 1
	for name, v in pose do
		for i, x in v do
			expect(finite(x), label .. ": " .. name .. "[" .. i .. "] is not finite")
		end
		local range = Poses.LIMITS[name]
		if range then
			expect(v[1] >= range[1] - slack and v[1] <= range[2] + slack,
				string.format("%s: %s rx %.1f outside [%d, %d]", label, name, v[1], range[1], range[2]))
		end
	end
end

-- Foot heights above the floor once the pose is grounded (KAI or another skeleton).
local function feetAboveFloor(anim, pose, altitude)
	local lift = anim:groundLift(pose, altitude or 0)
	local solved = K.solve(anim.skel, pose, lift)
	local floor = anim.skel.floor - (altitude or 0)
	return (K.footBottom(anim.skel, solved, "Left") or 0) - floor, (K.footBottom(anim.skel, solved, "Right") or 0) - floor,
		K.lowest(anim.skel, solved) - floor, solved
end

local CHANNELS = { Ground = true, Look = true, Plant = true, Stance = true }

-- Library poses: name -> raw pose (nested sets flattened to "Jab.Active", "Kits.TARO.STANCE").
local function libraryPoses()
	local list = {}
	local function walk(prefix, entry)
		if type(entry) ~= "table" then return end
		if entry.Root then
			list[prefix] = entry
		else
			for key, child in entry do walk(prefix .. "." .. tostring(key), child) end
		end
	end
	for name, entry in Poses do
		if name ~= "LIMITS" and name ~= "STRIKE" then walk(name, entry) end
	end
	return list
end

print("Animation")

test("every move of MoveData has its key poses (its own or its role's)", function()
	local anim = newAnimator()
	for id, m in MoveData.Moves do
		local set = anim:moveSet(id)
		expect(set and set.Startup and set.Active and set.Recovery, id .. " has no Startup/Active/Recovery poses")
		if m.hits and m.hits > 1 and set.Active2 then
			expect(m.hitInterval, id .. " alternates two contact poses but has no hitInterval")
		end
	end
end)

test("every simulation state has its own animation", function()
	local anim = newAnimator()
	local states = { "Idle", "Walking", "Crouching", "Jumping", "Falling", "Dashing", "Blocking", "CrouchBlocking",
		"Blockstun", "CrouchBlockstun", "Hitstun", "Crumple", "GuardBroken", "Launched", "Knockdown", "GetUp", "KO" }
	local seen = {}
	for _, state in states do
		anim.track.stateAge = 0.5
		local _, key = anim:evaluate({ state = state, x = 0, y = 0, vx = 0, vy = 0, facing = 1, hitstop = 0, combo = 1 }, 1, 15)
		local family = key:match("^[^:]+")
		expect(state == "Idle" or family ~= "Idle", state .. " falls back to the idle animation")
		seen[family] = true
	end
	local count = 0
	for _ in seen do count += 1 end
	expect(count >= 14, "too few distinct animations: " .. count)
end)

test("library poses are finite and inside the joint ranges (KAI and avatar)", function()
	for _, skel in { KAI, AVATAR } do
		local anim = newAnimator(skel)
		for name, pose in libraryPoses() do
			checkPose(anim:resolve(pose), name)
		end
	end
end)

test("planted poses keep both feet on the floor, flat or as pitched (KAI and avatar)", function()
	for label, skel in { KAI = KAI, AVATAR = AVATAR } do
		local anim = newAnimator(skel)
		local checked = 0
		for name, pose in libraryPoses() do
			local stance = pose.Stance
			if stance and (pose.Ground and pose.Ground[1] or 1) == 1 then
				local resolved = anim:resolve(pose)
				local left, right = feetAboveFloor(anim, resolved)
				local solved = K.solve(skel, resolved, 0)
				for i, side in { "Left", "Right" } do
					if not pose[side .. "Hip"] then
						local height: number = if side == "Left" then left else right
						expect(height < 0.06, string.format("%s %s: %s foot floats %.2f above the floor", label, name, side, height))
						local pitch = math.deg(K.pitch(solved[side .. "Foot"]))
						expect(math.abs(pitch - stance[2 + i]) < 2.5,
							string.format("%s %s: %s foot pitch %.1f instead of %.1f", label, name, side, pitch, stance[2 + i]))
						checked += 1
					end
				end
			end
		end
		expect(checked > 60, "too few planted feet checked: " .. checked)
	end
end)

-- Height of what carries the body (the planted feet, else the lowest point) after grounding.
local function support(anim, pose, altitude)
	local left, right, body = feetAboveFloor(anim, pose, altitude)
	local feet = math.min(left, right)
	local planted = pose.Plant or {}
	local pl, pr = math.clamp(planted[1] or 0, 0, 1), math.clamp(planted[2] or 0, 0, 1)
	local foot = if math.abs(pl - pr) < 0.01 then feet elseif pl > pr then left else right
	return body + (foot - body) * math.max(pl, pr), feet, body
end

test("grounded poses rest on the floor and never sink (KAI and avatar)", function()
	for label, skel in { KAI = KAI, AVATAR = AVATAR } do
		local anim = newAnimator(skel)
		for name, pose in libraryPoses() do
			local resolved = anim:resolve(pose)
			local reference, feet, body = support(anim, resolved)
			expect(feet > -0.01, string.format("%s %s: a foot sinks %.2f into the floor", label, name, -feet))
			expect(body > -Animator.CORNER_TOLERANCE - 0.01, string.format("%s %s sinks %.2f into the floor", label, name, -body))
			if (resolved.Ground and resolved.Ground[1] or 1) == 1 then
				expect(math.abs(reference) < 0.01, string.format("%s %s floats %.2f above the floor", label, name, reference))
			end
		end
	end
end)

test("lying poses lie on the floor for any body size", function()
	-- The test avatar has an oversized head: lying on its back, the head lifts the shoulders.
	for skel, propped in { [KAI] = 0.3, [AVATAR] = 0.45 } do
		local anim = newAnimator(skel)
		for _, name in { "Down", "DownFace", "DownImpact", "Crumple", "Kneel" } do
			local resolved = anim:resolve(Poses[name])
			local _, _, lowest, solved = feetAboveFloor(anim, resolved)
			expect(math.abs(lowest) < 0.01, name .. " does not touch the floor")
			if name:find("Down") then
				for _, part in { "UpperTorso", "LowerTorso" } do
					local size = skel.sizes[part]
					local bottom = K.boxBottom(solved[part], size[1] / 2, size[2] / 2, size[3] / 2) - skel.floor
					expect(bottom < propped, string.format("%s: %s floats %.2f above the floor (propped up)", name, part, bottom))
				end
			end
		end
	end
end)

-- World position of a root-space point for a rig placed like the client does.
local function world(x, facing, local3)
	local yaw = math.rad(Config.ModelYaw)
	local rot = K.mul({ 0, 0, 0, 0, 0, -facing, 0, 1, 0, facing, 0, 0 }, K.angles(0, -facing * yaw, 0))
	local wx, wy, wz = K.vector(rot, local3[1], local3[2], local3[3])
	return x + wx, wy, wz
end

local function walk(skel, direction, facing)
	local anim = newAnimator(skel)
	local view = { state = "Idle", x = 0, y = 0, vx = 0, vy = 0, facing = facing, hitstop = 0, combo = 0 }
	local dt, x = 1 / 60, 0
	local slips, frames, airborne, maxLift = 0, 0, 0, 0
	local previous = {}
	for frame = 1, 150 do
		local moving = frame > 10
		view.state = if moving then "Walking" else "Idle"
		view.vx = if moving then direction * facing * Config.WalkSpeed else 0
		if moving then x += view.vx * dt end
		view.x = x
		local pose, lift = anim:step(view, nil, dt, frame * dt, 15, false)
		checkPose(pose, "walk frame " .. frame)
		local solved = K.solve(skel, pose, lift)
		local floor = skel.floor
		local onFloor = 0
		for _, side in { "Left", "Right" } do
			local foot = solved[side .. "Foot"]
			local height = K.footBottom(skel, solved, side) - floor
			expect(height > -0.02, "a foot goes through the floor while walking")
			-- The toe and the heel of the sole: a rolling foot keeps one of them still.
			local h = skel.legs[side].footHalf
			local tx, ty, tz = K.point(foot, 0, -h[2], -h[3])
			local hx, hy, hz = K.point(foot, 0, -h[2], h[3])
			local toeX = world(x, facing, { tx, ty, tz })
			local heelX = world(x, facing, { hx, hy, hz })
			if moving and frame > 20 then
				maxLift = math.max(maxLift, height)
				if height < 0.01 then
					onFloor += 1
					local p = previous[side]
					if p and p.planted then
						frames += 1
						if math.min(math.abs(toeX - p.toe), math.abs(heelX - p.heel)) > 0.03 then slips += 1 end
					end
				end
			end
			previous[side] = { toe = toeX, heel = heelX, planted = height < 0.01 }
		end
		if moving and frame > 20 and onFloor == 0 then airborne += 1 end
	end
	return slips, frames, airborne, maxLift
end

test("walking forward and backward keeps the planted foot still (no foot skating)", function()
	for label, skel in { KAI = KAI, AVATAR = AVATAR } do
		for _, direction in { 1, -1 } do
			for _, facing in { 1, -1 } do
				local slips, frames, _, maxLift = walk(skel, direction, facing)
				expect(frames > 40, label .. ": too few planted frames " .. frames)
				expect(slips == 0, string.format("%s dir %d facing %d: the planted foot slid on %d/%d frames",
					label, direction, facing, slips, frames))
				expect(maxLift > 0.25, label .. ": the swing foot barely lifts")
			end
		end
	end
end)

test("the forward run has a flight phase, the back walk barely leaves the floor", function()
	local _, _, flight = walk(KAI, 1, 1)
	expect(flight > 10, "no flight phase in the forward run: " .. flight)
	local _, _, backFlight = walk(KAI, -1, 1)
	expect(backFlight < flight, "the back walk floats more than the run")
end)

test("attack timelines: anticipation, contact snap, settle back to the stance", function()
	for id, m in MoveData.Moves do
		local anim = newAnimator()
		local total = MoveData.total(m)
		local previous, previousKey
		local stance = anim:resolve(anim:base("STANCE", anim.moveKit[id]))
		for frame = 1, total do
			local pose, key, snap = anim:attack(id, frame, 60)
			checkPose(pose, id .. " frame " .. frame, 3)
			if frame == m.startup + 1 then
				expect(snap and key:find(":I"), id .. ": the first active frame is not a snapped impact")
			end
			if previous and not snap and not m.meterCost then
				for name, v in pose do
					local p = previous[name]
					if p and not CHANNELS[name] then
						for i = 1, 3 do
							local delta = math.abs(v[i] - p[i])
							expect(delta < 75, string.format("%s frame %d (%s): %s[%d] jumps %.0f°", id, frame, key, name, i, delta))
						end
					end
				end
			end
			previous, previousKey = pose, key
		end
		local final = anim:attack(id, total, 60)
		for name, v in stance do
			local f = final[name]
			for i = 1, #v do
				expect(math.abs(f[i] - v[i]) < 1e-6, id .. ": the recovery does not end on the stance (" .. name .. ")")
			end
		end
		local _ = previousKey
	end
end)

test("anticipation pushes past the startup key, impacts overshoot the contact key", function()
	local anim = newAnimator()
	local m = MoveData.Moves.Cross
	local coil = anim:attack("Cross", m.startup, 60)
	local startup = anim:resolve(Poses.Cross.Startup)
	local stance = anim:resolve(Poses.STANCE)
	-- Waist twist winds further back than the startup key.
	expect(math.abs(coil.Waist[2] - stance.Waist[2]) > math.abs(startup.Waist[2] - stance.Waist[2]), "no coil")
	local impact = anim:attack("Cross", m.startup + 1, 60)
	local active = anim:resolve(Poses.Cross.Active)
	expect(impact.Waist[2] > active.Waist[2], "the impact frame does not overshoot the contact pose")
	local held = anim:attack("Cross", m.startup + 3, 60)
	expect(held.Waist[2] == active.Waist[2], "the contact pose is not reached after the smear frames")
end)

test("the wind-up tightens until the release: the held coil keeps moving away from the strike", function()
	local anim = newAnimator()
	for _, id in { "Cross", "Smash", "Kick", "ShinBreaker", "RyukenHeavy" } do
		local m = MoveData.Moves[id]
		local early = anim:attack(id, math.ceil(m.startup * 0.5), 60)
		local late = anim:attack(id, m.startup, 60)
		local active = anim:resolve((Poses[id] or Poses[anim.roleOf[id]]).Active)
		local function distance(pose)
			local sum = 0
			for _, name in { "Waist", "LeftShoulder", "RightShoulder", "LeftElbow", "RightElbow" } do
				for i = 1, 3 do sum += math.abs((pose[name][i] or 0) - (active[name][i] or 0)) end
			end
			return sum
		end
		expect(distance(late) > distance(early) + 3, id .. ": the hold of the wind-up is a frozen pose")
		checkPose(late, id .. " (wind-up)", 1)
	end
end)

test("overlap: the arms drag behind a change of pose and overshoot it a little; an impact lands at once and whips past", function()
	local anim = newAnimator()
	local view = { state = "Idle", x = 0, y = 0, vx = 0, vy = 0, facing = 1, hitstop = 0, combo = 0, kit = "KAI" }
	local other = { state = "Idle", x = 3.5, y = 0, facing = -1 }
	local t = 0
	for _ = 1, 30 do t += 1 / 60; anim:step(view, other, 1 / 60, t, 60, false) end
	-- A key change (stance to a punch's contact): the elbow follows behind its target, then
	-- passes it a little and settles.
	local from, to = anim:resolve(Poses.STANCE), anim:resolve(Poses.Jab.Active)
	anim:overlap(from, 1 / 60, false, true)
	local before, target = from.LeftElbow[1], to.LeftElbow[1]
	local values = {}
	for i = 1, 40 do values[i] = anim:overlap(to, 1 / 60, false, false).LeftElbow[1] end
	local sign = if target > before then 1 else -1
	expect((values[1] - before) * sign < (target - before) * sign * 0.8, "the elbow does not drag behind")
	local peak = -math.huge
	for _, x in values do peak = math.max(peak, (x - target) * sign) end
	expect(peak > 0.3 and peak < math.abs(target - before) * 0.35 + 1, string.format("the overshoot is %.1f°", peak))
	expect(math.abs(values[40] - target) < 1.5, "the elbow does not settle on its target")
	-- An impact frame: exactly on its key at once.
	local m = MoveData.Moves.Jab
	view.state, view.move = "Attack", "Jab"
	for f = 1, m.startup + 1 do
		view.moveFrame = f
		t += 1 / 60
		local pose = anim:step(view, other, 1 / 60, t, 60, false)
		if f == m.startup + 1 then
			local key = anim:attack("Jab", f, 60)
			expect(math.abs(pose.LeftElbow[1] - key.LeftElbow[1]) < 0.01, "the impact frame lags behind its key")
		end
	end
	-- Feet planted by IK never drag.
	view.state, view.move = "Idle", nil
	for _ = 1, 10 do t += 1 / 60; anim:step(view, other, 1 / 60, t, 60, false) end
	local idle = anim:evaluate(view, t + 1 / 60, 60)
	local pose = anim:step(view, other, 1 / 60, t + 1 / 60, 60, false)
	expect(math.abs(pose.LeftKnee[1] - idle.LeftKnee[1]) < 1e-6, "a planted leg is dragged by the springs")
end)

test("presentation spacing: bodies drawn apart at point-blank range, never a jump, nothing at a distance or a crossing", function()
	local previous = nil
	for i = 0, 600 do
		local d = i / 100
		local push = Animator.spacing(0, 0, d, 0)
		local shown = d + 2 * push
		if previous then expect(shown >= previous - 1e-9, string.format("the drawn separation shrinks at %.2f", d)) end
		previous = shown
		if d >= 4.4 or d <= 0.6 then expect(push == 0, string.format("bodies pushed apart at %.2f", d)) end
	end
	expect(Animator.spacing(0, 0, 3, 0) > 0.3, "no spacing at point-blank range")
	expect(Animator.spacing(0, 0, 3, 5) == 0, "a body high above is pushed")
end)

test("each kit's guard has its own rhythm: the boxer bounces, the swordsman barely breathes", function()
	local function bounce(kit)
		local anim = newAnimator()
		local view = { state = "Idle", x = 0, y = 0, vx = 0, vy = 0, facing = 1, hitstop = 0, combo = 0, kit = kit }
		local lo, hi, changes, last = math.huge, -math.huge, 0, nil
		for i = 1, 120 do
			local pose = anim:evaluate(view, i / 60, 60)
			local y = pose.Root[4]
			lo, hi = math.min(lo, y), math.max(hi, y)
			if last and math.sign(y - last) ~= 0 then changes += 1 end
			last = y
		end
		return Animator.IDLE_RHYTHM[kit].rate, hi - lo
	end
	local taro, shin = bounce("TARO"), bounce("SHIN")
	expect(taro > shin * 2, "the boxer's guard is not livelier than the swordsman's")
	for _, kit in MoveData.KitOrder do
		expect(Animator.IDLE_RHYTHM[kit], kit .. " has no guard rhythm")
		local _, range = bounce(kit)
		expect(range > 0.01, kit .. "'s guard never moves")
	end
end)

test("stepped timing: fewer distinct keys at 12 poses/s than at 60", function()
	local function keys(rate)
		local anim, seen, n = newAnimator(), {}, 0
		for frame = 1, MoveData.total(MoveData.Moves.Smash) do
			local _, key = anim:attack("Smash", frame, rate)
			if not seen[key] then seen[key], n = true, n + 1 end
		end
		return n
	end
	expect(keys(12) < keys(60) / 2, "pose rate does not hold steps")
end)

-- Strike limbs of a move: its own entry in Poses.STRIKE, else its role's.
local function strikeOf(anim, id)
	return Poses.STRIKE[id] or Poses.STRIKE[anim.roleOf[id] or ""]
end

test("each kit fights in its style: TARO only punches, ZEPHYR only kicks", function()
	local anim = newAnimator()
	for _, name in { "TARO", "ZEPHYR" } do
		local kit = MoveData.Kits[name]
		local ids = {}
		for _, id in kit.Roles do table.insert(ids, id) end
		if name == "TARO" then table.insert(ids, "TaroCounter") end
		for _, id in ids do
			local limbs = strikeOf(anim, id)
			expect(limbs ~= nil, id .. " has no strike limbs")
			for _, limb in limbs do
				local isHand = limb:find("Hand") ~= nil
				expect(if name == "TARO" then isHand else not isHand, string.format("%s strikes with %s", id, limb))
			end
			-- The contact pose agrees: a punch keeps both feet low, a kick raises or extends a foot.
			local m = MoveData.Moves[id]
			local pose = anim:attack(id, m.startup + 3, 60)
			if m.hitbox and not m.air and m.kind ~= "Ultimate" and (pose.Ground and pose.Ground[1] or 1) > 0.5 then
				local solved = K.solve(KAI, pose, 0)
				local function footUp(side)
					local foot = solved[side .. "Foot"]
					local other = solved[(if side == "Left" then "Right" else "Left") .. "Foot"]
					return foot[2] - other[2] > 0.9 or -foot[3] > 1.9
				end
				local kicking = footUp("Left") or footUp("Right")
				if name == "TARO" then
					expect(not kicking, id .. ": a foot is raised like a kick")
				else
					expect(kicking, id .. ": no foot is raised or extended")
				end
			end
		end
	end
end)

test("every move of every kit has its own animation: nothing borrowed, no key pose shared (Wilhem: obligatoirement différente)", function()
	local seen = {}
	for _, kit in MoveData.KitOrder do
		for role, id in MoveData.Kits[kit].Roles do
			local set = Poses[id]
			expect(set ~= nil, kit .. " " .. id .. " (" .. role .. ") borrows its role's poses")
			expect(Poses.STRIKE[id] ~= nil, kit .. " " .. id .. " has no strike limbs")
			for _, phase in { "Startup", "Active", "Active2", "Recovery" } do
				local pose = set and set[phase]
				if pose then
					local key = Poses.signature(pose)
					local who = kit .. " " .. id .. "." .. phase
					expect(seen[key] == nil or seen[key] == who, who .. " is the same pose as " .. tostring(seen[key]))
					seen[key] = seen[key] or who
				end
			end
		end
	end
	-- (ASURA's gatling too: the boss does not wear TARO's)
	expect(Poses.AsuraGatling ~= Poses.TaroGatling and Poses.AsuraGatling.Active ~= Poses.TaroGatling.Active, "ASURA wears TARO's gatling")
end)

test("no animation shared: jumps, dashes, hits, falls and the cinematics' poses are each kit's own, ASURA's blows too (Wilhem)", function()
	local kits = table.clone(MoveData.KitOrder)
	table.insert(kits, "ASURA")
	local UPPER = { "Waist", "Neck", "LeftShoulder", "LeftElbow", "RightShoulder", "RightElbow" }
	local function apart(p, q)
		local most = 0
		for _, joint in UPPER do
			local a, b = p[joint] or { 0, 0, 0 }, q[joint] or { 0, 0, 0 }
			for i = 1, 3 do most = math.max(most, math.abs((a[i] or 0) - (b[i] or 0))) end
		end
		return most
	end
	local anim = newAnimator()
	local STANDING = { StandTall = true, Roar = true, Kiai = true, Victory = true, Block = true, Kneel = true, Land = true,
		WindGather = true, ArmsCrossed = true, Colossus = true }
	for _, name in Poses.PERSONAL do
		local seen = {}
		for _, kit in kits do
			local pose = anim:base(name, kit)
			expect(pose ~= nil, kit .. " has no " .. name)
			if type(pose[1]) == "table" and not pose.Root then pose = pose[1] end
			for other, theirs in seen do
				expect(apart(pose, theirs) >= 5, string.format("%s's %s is %s's", kit, name, other))
			end
			seen[kit] = pose
			if STANDING[name] then
				anim.kit = kit
				local left, right = feetAboveFloor(anim, anim:resolve(pose))
				-- (one foot on the floor at least: ZEPHYR's victory raises a leg high on purpose)
				expect(math.min(left, right) < 0.08, string.format("%s's %s floats (%.2f, %.2f)", kit, name, left, right))
			end
		end
	end
	anim.kit = nil
	local count = 0
	for id, set in Poses.Kits.ASURA.Moves do
		count += 1
		expect(apart(set.Active, Poses[id].Active) >= 5, "ASURA's " .. id .. " is KAI's")
	end
	expect(count >= 20, "ASURA has only " .. count .. " moves of his own")
end)

test("each kit has its own stance, guard and run", function()
	local anim = newAnimator()
	local base = anim:resolve(Poses.STANCE)
	for _, name in MoveData.KitOrder do
		if name == "KAI" then continue end
		anim.kit = name
		local stance = anim:resolve(anim:base("STANCE"))
		expect(stance ~= base and stance.Root[4] ~= base.Root[4], name .. " uses KAI's stance")
		local left, right = feetAboveFloor(anim, stance)
		expect(left < 0.06 and right < 0.06, name .. "'s stance floats")
		expect(anim:base("RunUpper") ~= Poses.RunUpper and anim:base("Block") ~= Poses.Block, name .. " has no own run / guard")
	end
end)

test("hit reactions follow the move that hit", function()
	local anim = newAnimator()
	local view = { state = "Hitstun", x = 0, y = 0, vx = 0, vy = 0, facing = 1, hitstop = 0, combo = 1 }
	local function reaction(move, combo)
		anim.track.hitBy, anim.track.hitAge = move, 0.2
		view.combo = combo
		local _, key = anim:evaluate(view, 1, 15)
		return key:match("^[^:]+")
	end
	expect(reaction("Sweep", 1) == "HitLow", "a sweep does not hit low")
	expect(reaction("LowKick", 2) == "HitLow", "a low kick does not hit low")
	expect(reaction("BodyBlow", 1) == "HitBody", "a body blow does not double over")
	local a, b = reaction("Jab", 1), reaction("Cross", 2)
	expect(a ~= b and a:find("HitHigh") and b:find("HitHigh"), "consecutive face hits do not alternate")
end)

test("landing squashes the knees, then recovers", function()
	local anim = newAnimator()
	local dt = 1 / 60
	local view = { state = "Falling", x = 0, y = 2, vx = 0, vy = -40, facing = 1, hitstop = 0, combo = 0 }
	anim:step(view, nil, dt, 0, 60, false)
	view.state, view.y, view.vy = "Idle", 0, 0
	-- (the squash comes in over a couple of frames: an instant one popped the knees)
	local pose = anim:step(view, nil, dt, dt, 60, false)
	local first, squash = pose.Root[4], pose.Root[4]
	for i = 2, 6 do
		pose = anim:step(view, nil, dt, i * dt, 60, false)
		squash = math.min(squash, pose.Root[4])
	end
	for i = 7, 30 do pose = anim:step(view, nil, dt, i * dt, 60, false) end
	expect(squash < pose.Root[4] - 0.2, string.format("no landing squash (%.2f then %.2f)", squash, pose.Root[4]))
	expect(first > squash + 0.05, "the landing squash is not eased in (all on the first frame)")
	local left, right = feetAboveFloor(anim, pose)
	expect(left < 0.06 and right < 0.06, "the feet leave the floor after landing")
end)

test("the head looks at the opponent: up at a juggled target, down at a fallen one", function()
	local function neckAfter(other)
		local anim = newAnimator()
		local view = { state = "Idle", x = 0, y = 0, vx = 0, vy = 0, facing = 1, hitstop = 0, combo = 0 }
		local base = anim:resolve(Poses.Idle[1]).Neck[1]
		local pose
		for i = 1, 90 do pose = anim:step(view, other, 1 / 60, i / 60, 60, false) end
		return pose.Neck[1] - base
	end
	local up = neckAfter({ state = "Launched", x = 4, y = 7 })
	local level = neckAfter({ state = "Idle", x = 6, y = 0 })
	local down = neckAfter({ state = "Knockdown", x = 4, y = 0 })
	expect(up > level + 15, string.format("does not look up (%.1f vs %.1f)", up, level))
	expect(down < level - 10, string.format("does not look down (%.1f vs %.1f)", down, level))
	expect(math.abs(up) <= 40 and math.abs(down) <= 40, "the neck turns too far")
end)

test("springs stay stable at low frame rates and settle on their target", function()
	local s = { x = 0, v = 0 }
	for _ = 1, 40 do K.spring(s, 10, 0.1, 6, 0.3) end
	expect(math.abs(s.x - 10) < 0.05, "the spring does not settle: " .. s.x)
	local wobble = { x = 0, v = 300 }
	local peak = 0
	for _ = 1, 120 do peak = math.max(peak, math.abs(K.spring(wobble, 0, 1 / 60, 3.2, 0.32))) end
	expect(peak > 5 and peak < 40, "hit recoil wobble out of range: " .. peak)
end)

test("a full CPU fight animates without NaN, floor clipping or floating", function()
	local world = Sim.newWorld(Config, MoveData, false)
	Sim.resetMatch(world, false)
	local brains = { FighterAI.new(4, 11), FighterAI.new(3, 12) }
	local anims = { newAnimator(KAI), newAnimator(AVATAR) }
	local dt = 1 / 60
	local states = {}
	for tick = 1, 60 * 45 do
		local inputs = { brains[1]:think(world, 1), brains[2]:think(world, 2) }
		Sim.step(world, inputs)
		for i, f in world.fighters do
			local view = {
				x = f.x, y = f.y, vx = f.vx + f.pushVx, vy = f.vy, facing = f.facing, state = f.state,
				move = f.move, moveFrame = f.moveFrame, hitstop = f.hitstop, combo = f.comboHits,
			}
			local o = world.fighters[3 - i]
			local other = { x = o.x, y = o.y, state = o.state, move = o.move }
			local anim = anims[i]
			local pose, lift = anim:step(view, other, dt, tick * dt, 15, false)
			checkPose(pose, f.state .. " tick " .. tick, 3)
			expect(finite(lift), "lift is not finite")
			local solved = K.solve(anim.skel, pose, lift)
			local body = K.lowest(anim.skel, solved) - anim.skel.floor + f.y
			local feet = math.min(K.footBottom(anim.skel, solved, "Left") or 0, K.footBottom(anim.skel, solved, "Right") or 0)
				- anim.skel.floor + f.y
			expect(feet > -0.03, string.format("%s (%s): a foot clips %.2f through the floor at tick %d", f.state, tostring(f.move), -feet, tick))
			expect(body > -Animator.CORNER_TOLERANCE - 0.03,
				string.format("%s (%s) clips %.2f through the floor at tick %d", f.state, tostring(f.move), -body, tick))
			local ground = pose.Ground and pose.Ground[1] or 1
			if f.y <= 0 and ground >= 0.999 and anim.blendTime == 0 then
				local reference = support(anim, pose, 0)
				expect(reference < 0.03, string.format("%s (%s) floats %.2f at tick %d", f.state, tostring(f.move), reference, tick))
			end
			states[f.state] = true
		end
		if world.phase == "MatchEnd" then break end
	end
	for _, needed in { "Walking", "Attack", "Hitstun", "Blocking" } do
		expect(states[needed], "the fight never showed " .. needed)
	end
end)

-- ===================================================================== R6

local function r6Skeleton(scale)
	scale = scale or 1
	local sizes, joints = {}, {}
	for name, p in RigSpec.R6.parts do sizes[name] = { p.size[1] * scale, p.size[2] * scale, p.size[3] * scale } end
	for _, j in RigSpec.R6.joints do
		local c0, c1 = table.clone(j.c0), table.clone(j.c1)
		for i = 1, 3 do c0[i] *= scale; c1[i] *= scale end
		table.insert(joints, { name = j.name, part0 = j.part0, part1 = j.part1, c0 = c0, c1 = c1 })
	end
	return K.skeleton(joints, sizes)
end

local function r6Animator(rt)
	return Animator.new({ poses = Poses, moves = MoveData.Moves, kin = K, config = Config, skeleton = rt.virtual,
		kits = MoveData.Kits, moveKit = MoveData.MoveKit })
end

test("R6: the standard R6 rig stands in its bind pose, feet on the floor", function()
	local r6 = r6Skeleton()
	expect(math.abs(r6.floor + 3) < 1e-6, "R6 floor " .. r6.floor)
	local rt = Retarget.new(K, r6)
	expect(math.abs(rt.virtual.floor - r6.floor) < 0.02, "the virtual R15 is not as tall as the R6 body")
	local c0, lift = Retarget.solve(rt, {}, 0)
	expect(math.abs(lift) < 0.02, "bind pose lifted " .. lift)
	for _, j in RigSpec.R6.joints do
		local got = c0[j.name]
		expect(got, "no C0 for " .. j.name)
		for i = 1, 12 do
			expect(math.abs(got[i] - j.c0[i]) < 0.02, string.format("%s C0[%d] %.3f instead of %.3f", j.name, i, got[i], j.c0[i]))
		end
	end
end)

test("R6: limbs follow the virtual limbs (punch forward, kick up)", function()
	local rt = Retarget.new(K, r6Skeleton())
	local anim = r6Animator(rt)
	local function tip(pose, part)
		local _, _, parts = Retarget.solve(rt, pose, 0)
		local x, y, z = K.point(parts[part], 0, -1, 0)
		return x, y, z
	end
	local cross = anim:attack("Cross", MoveData.Moves.Cross.startup + 3, 60)
	local _, hy, hz = tip(cross, "Right Arm")
	expect(hz < -1.2 and hy > -0.2, string.format("the R6 fist is not forward (y %.2f, z %.2f)", hy, hz))
	local kick = anim:attack("ZephyrHigh", MoveData.Moves.ZephyrHigh.startup + 3, 60)
	local _, fy = tip(kick, "Right Leg")
	expect(fy > 0, string.format("the R6 kick does not rise (foot y %.2f)", fy))
end)

test("R6: a crouch lowers the body, a guard keeps the fists out of the head", function()
	local rt = Retarget.new(K, r6Skeleton())
	local function settled(view)
		local anim = r6Animator(rt)
		view.x, view.y, view.vx, view.vy, view.facing, view.hitstop, view.combo, view.kit, view.moveFrame =
			0, 0, 0, 0, 1, 0, 0, view.kit or "KAI", 0
		local pose
		for i = 1, 40 do
			pose = anim:step(view, { x = 4, y = 0, state = "Idle" }, 1 / 60, i / 60, 60, false)
		end
		local _, lift, parts = Retarget.solve(rt, pose, 0)
		return parts, lift
	end
	local stand, standLift = settled({ state = "Idle" })
	local crouch, crouchLift = settled({ state = "Crouching", crouching = true })
	local drop = (stand.Torso[2] + standLift) - (crouch.Torso[2] + crouchLift)
	expect(drop > 0.4, string.format("the R6 crouch only lowers the torso by %.2f", drop))
	local cases = { { "Blocking", "KAI" } }
	for _, kit in MoveData.KitOrder do table.insert(cases, { "Idle", kit }) end
	for _, case in cases do
		local parts = settled({ state = case[1], kit = case[2] })
		local head = K.inverse(parts.Head)
		for _, arm in { "Left Arm", "Right Arm" } do
			local x, y, z = K.point(parts[arm], 0, -0.8, 0) -- near the fist
			local hx, hy, hz = K.point(head, x, y, z)
			local inside = math.abs(hx) < 0.62 and math.abs(hy) < 0.62 and math.abs(hz) < 0.62
			expect(not inside, string.format("%s %s: the R6 %s goes through the head", case[2], case[1], arm))
		end
	end
end)

test("R6: guard arms point at the opponent, pitched down; standing legs stay close; low moves stay low", function()
	local rt = Retarget.new(K, r6Skeleton())
	local function settled(view)
		local anim = r6Animator(rt)
		view.x, view.y, view.vx, view.vy, view.facing, view.hitstop, view.combo = 0, 0, 0, 0, 1, 0, 0
		local pose
		for i = 1, 40 do
			pose = anim:step(view, { x = 3, y = 0, state = "Idle" }, 1 / 60, i / 60, 60, false)
		end
		local _, lift, parts = Retarget.solve(rt, pose, 0)
		return parts, lift
	end
	-- Direction of a limb toward its tip (rig space: forward is -Z).
	local function tip(t) return -t[5], -t[8], -t[11] end
	for _, kit in MoveData.KitOrder do
		for _, state in { "Idle", "Blocking" } do -- (runs swing the arms: AKEMI's trail behind)
			local parts = settled({ state = state, kit = kit })
			for _, arm in { "Left Arm", "Right Arm" } do
				-- (RAIJIN at rest: the spear on his right shoulder, the left arm hanging, Wilhem's sheet)
				if kit == "RAIJIN" and state == "Idle" then continue end
				-- (SHIN's guard: the katana raised over his head in both hands, Wilhem's sheet)
				if kit == "SHIN" and state == "Blocking" then continue end
				local _, y, z = tip(parts[arm])
				expect(y < -0.1 and y > -0.9, string.format("%s %s: R6 %s pitched %.2f (want down, not hanging)", kit, state, arm, y))
				expect(-z > 0.25, string.format("%s %s: R6 %s does not point forward (%.2f)", kit, state, arm, -z))
			end
			for _, leg in { "Left Leg", "Right Leg" } do
				local _, y = tip(parts[leg])
				expect(y < -0.8, string.format("%s %s: R6 %s splayed (%.2f from vertical)", kit, state, leg, y))
			end
		end
	end
	-- A low kick keeps the body as low as the R15 one would (no straightening).
	local stand, standLift = settled({ state = "Idle", kit = "KAI" })
	local low, lowLift = settled({ state = "Attack", move = "LowKick", moveFrame = MoveData.Moves.LowKick.startup + 1, kit = "KAI" })
	expect((stand.Torso[2] + standLift) - (low.Torso[2] + lowLift) > 0.25, "the R6 low kick stands as tall as the guard")
end)

test("TARO's weave and DEMPSEY ROLL animate on R15 and R6: grounded, fists reaching forward", function()
	local function playRoll(onFrame)
		local world = Sim.newWorld(Config, MoveData, true)
		Sim.setKits(world, "TARO", "KAI")
		world.phase = "Fight"
		world.fighters[1].x, world.fighters[2].x = -3, 3
		local esquive = MoveData.Kits.TARO.Stances.PEEKABOO -- the weave and the roll belong to it
		world.fighters[1].stance, world.fighters[1].stats = esquive.Id, esquive.Stats
		for tick = 1, 110 do
			local i = Sim.neutralInput()
			i.dash, i.axis = tick == 1, if tick <= 3 then 1 else 0
			i.light = tick >= 4 and tick <= 54 and (tick - 4) % 10 == 0
			i.heavy = tick == 70
			Sim.step(world, { i, Sim.neutralInput() })
			local f, o = world.fighters[1], world.fighters[2]
			onFrame(tick, f, { x = f.x, y = f.y, vx = f.vx, vy = f.vy, facing = f.facing, state = f.state, move = f.move,
				moveFrame = f.moveFrame, hitstop = f.hitstop, combo = f.comboHits, kit = f.kit, weave = f.weaveTicks > 0,
				stance = f.stance },
				{ x = o.x, y = o.y, state = o.state, move = o.move })
		end
	end
	-- R6: never sinks or floats; each hook's fist goes out in front.
	local rt = Retarget.new(K, r6Skeleton())
	local anim = r6Animator(rt)
	local reached, seen = {}, {}
	playRoll(function(tick, f, view, other)
		local pose = anim:step(view, other, 1 / 60, tick / 60, 60, false)
		local _, lift, parts = Retarget.solve(rt, pose, f.y)
		local lowest = math.huge
		for name, t in parts do
			local size = rt.r6.sizes[name]
			lowest = math.min(lowest, K.boxBottom(t, size[1] / 2, size[2] / 2, size[3] / 2))
		end
		local height = lowest + lift - rt.r6.floor + f.y
		expect(height > -0.03 and height < 0.06, string.format("R6 %s (%s) at %.2f from the floor, tick %d", f.state, tostring(f.move), height, tick))
		local m = f.move and MoveData.Moves[f.move]
		if m and m.dempsey then
			seen[f.move] = true
			if f.moveFrame > m.startup and f.moveFrame <= m.startup + m.active then
				local arm = if f.move == "TaroDempseyL" then "Left Arm" else "Right Arm"
				local x, y, z = K.point(parts[arm], 0, -0.9, 0)
				if z < -1.0 then reached[f.move] = true end
			end
		end
	end)
	for _, id in { "TaroDempseyL", "TaroDempseyR", "TaroDempseyFinish" } do
		expect(seen[id], "the roll never played " .. id)
		expect(reached[id], "R6: the fist of " .. id .. " never goes out in front")
	end
	-- R15 (KAI rig): the hooking fist goes out in front, the weave rolls the waist.
	local r15 = newAnimator(KAI)
	local reach15, rolls = {}, {}
	playRoll(function(tick, f, view, other)
		local pose, lift = r15:step(view, other, 1 / 60, tick / 60, 60, false)
		if f.state == "Dashing" and view.weave then rolls[math.floor(pose.Waist[3] / 5)] = true end
		local m = f.move and MoveData.Moves[f.move]
		if m and m.dempsey and f.moveFrame > m.startup and f.moveFrame <= m.startup + m.active then
			local solved = K.solve(KAI, pose, lift)
			local hand = solved[if f.move == "TaroDempseyL" then "LeftHand" else "RightHand"]
			if hand[3] < -1.2 then reach15[f.move] = true end
		end
	end)
	for _, id in { "TaroDempseyL", "TaroDempseyR", "TaroDempseyFinish" } do
		expect(reach15[id], "R15: the fist of " .. id .. " never goes out in front")
	end
	local distinct = 0
	for _ in rolls do distinct += 1 end
	expect(distinct >= 3, "the weave does not roll the waist")
end)

test("TARO's two stances look different and stay grounded (R15 and R6)", function()
	local function settled(animator, stance, state)
		local view = { x = 0, y = 0, vx = 0, vy = 0, facing = 1, state = state or "Idle", hitstop = 0, combo = 0, kit = "TARO",
			stance = stance, moveFrame = 0 }
		local pose, lift
		for i = 1, 40 do pose, lift = animator:step(view, { x = 3, y = 0, state = "Idle" }, 1 / 60, i / 60, 60, false) end
		return pose, lift
	end
	local r15 = newAnimator(KAI)
	local classic = settled(r15, "CLASSIC")
	local esquive = settled(r15, "PEEKABOO")
	expect(classic.Root[4] > esquive.Root[4] + 0.1, "the classic guard is not more upright than the peek-a-boo")
	expect(classic.LeftElbow[1] < esquive.LeftElbow[1] - 30, "the classic lead arm is not out")
	for _, stance in { "CLASSIC", "PEEKABOO" } do
		for _, state in { "Idle", "Blocking", "Walking" } do
			-- R6: on the floor, never sinking.
			local rt = Retarget.new(K, r6Skeleton())
			local pose = settled(r6Animator(rt), stance, state)
			local _, lift, parts = Retarget.solve(rt, pose, 0)
			local lowest = math.huge
			for name, t in parts do
				local size = rt.r6.sizes[name]
				lowest = math.min(lowest, K.boxBottom(t, size[1] / 2, size[2] / 2, size[3] / 2))
			end
			local height = lowest + lift - rt.r6.floor
			expect(math.abs(height) < 0.06, string.format("R6 %s %s at %.2f from the floor", stance, state, height))
		end
	end
end)

test("R6: a full CPU fight never sinks, floats or breaks (standard and scaled body)", function()
	for _, scale in { 1, 1.15 } do
		local world = Sim.newWorld(Config, MoveData, false)
		Sim.setKits(world, "ZEPHYR", "TARO")
		local brains = { FighterAI.new(4, 5), FighterAI.new(3, 6) }
		local rts = { Retarget.new(K, r6Skeleton(scale)), Retarget.new(K, r6Skeleton(scale)) }
		local anims = { r6Animator(rts[1]), r6Animator(rts[2]) }
		for tick = 1, 60 * 30 do
			Sim.step(world, { brains[1]:think(world, 1), brains[2]:think(world, 2) })
			for i, f in world.fighters do
				local view = { x = f.x, y = f.y, vx = f.vx, vy = f.vy, facing = f.facing, state = f.state, move = f.move,
					moveFrame = f.moveFrame, hitstop = f.hitstop, combo = f.comboHits, kit = f.kit }
				local o = world.fighters[3 - i]
				local pose = anims[i]:step(view, { x = o.x, y = o.y, state = o.state, move = o.move }, 1 / 60, tick / 60, 15, false)
				local c0, lift, parts = Retarget.solve(rts[i], pose, f.y)
				expect(finite(lift), "R6 lift is not finite")
				for name, value in c0 do
					for _, x in value do expect(finite(x), "R6 " .. name .. " C0 is not finite") end
				end
				local lowest = math.huge
				for name, t in parts do
					local size = rts[i].r6.sizes[name]
					lowest = math.min(lowest, K.boxBottom(t, size[1] / 2, size[2] / 2, size[3] / 2))
				end
				local height = lowest + lift - rts[i].r6.floor + f.y
				expect(height > -0.03, string.format("R6 %s (%s) sinks %.2f at tick %d", f.state, tostring(f.move), -height, tick))
				local ground = pose.Ground and pose.Ground[1] or 1
				if f.y <= 0 and ground >= 0.999 then
					expect(height < 0.03, string.format("R6 %s (%s) floats %.2f at tick %d", f.state, tostring(f.move), height, tick))
				end
			end
		end
	end
end)

-- ===================================================================== weapons
local WeaponKit = require("./WeaponKit")

-- Base and tip of a kit's weapon (the orb: its centre twice) in a key pose, and the chest
-- frame: on an R15 skeleton, or on an R6 body through the retarget.
local function weaponLine(kit, pose, skel, r6)
	local parts = {}
	if r6 then
		local rt = Retarget.new(K, r6)
		local _, _, solved, virtual = Retarget.solve(rt, r6Animator(rt):resolve(pose), 0)
		for name, f in solved do
			if r6.sizes[name] then parts[name] = { cframe = f, size = r6.sizes[name] } end
		end
		for _, side in { "LeftHand", "RightHand" } do
			parts["@" .. side] = { cframe = virtual[side], size = rt.virtual.sizes[side] }
		end
	else
		for name, f in K.solve(skel, newAnimator(skel):resolve(pose), 0) do
			if skel.sizes[name] then parts[name] = { cframe = f, size = skel.sizes[name] } end
		end
	end
	local base, tip = WeaponKit.line(kit, parts)
	return base, tip, (parts.UpperTorso or parts.Torso).cframe
end
local BODIES = { KAI = { KAI }, AVATAR = { AVATAR }, R6 = { nil, r6Skeleton() } }

test("KAZAN's claws: two hands, three long blades each; every rake really sweeps the blades (not a whip, not a punch)", function()
	local WeaponSpec = require("../src/shared/WeaponSpec")
	local spec = WeaponSpec.KAZAN
	expect(spec and spec.pair and spec.hand ~= spec.pair.hand, "KAZAN has not two claws")
	for _, claw in { spec, spec.pair } do
		local blades = 0
		for _, piece in claw.pieces do
			if string.find(piece.name, "ClawBlade") then
				blades += 1
				expect(piece.size[3] >= 1.1, "a claw blade too short to read: " .. piece.size[3])
			end
		end
		expect(blades == 3, "a claw has " .. blades .. " blades")
	end
	local anim = newAnimator(KAI)
	anim.kit = "KAZAN"
	local function tip(pose, spec2)
		local r = anim:resolve(pose)
		local parts = {}
		for name, f in K.solve(KAI, r, anim:groundLift(r, 0)) do
			if KAI.sizes[name] then parts[name] = { cframe = f, size = KAI.sizes[name] } end
		end
		local grip = WeaponKit.grip("KAZAN", parts, spec2)
		local x, y, z = K.point(grip, 0, 0, spec2.tip)
		return { x, y, z }
	end
	-- the rakes and the heavy blows: the leading claw's tip travels from the wind-up to the contact
	for _, role in { "Jab", "Cross", "Kick", "Uppercut", "Smash", "Hammer", "KiFlurry" } do
		local set = Poses[MoveData.Kits.KAZAN.Roles[role]]
		local moved = 0
		for _, spec2 in { spec, spec.pair } do
			local a, b = tip(set.Startup, spec2), tip(set.Active, spec2)
			moved = math.max(moved, math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2))
		end
		expect(moved > 1.2, string.format("KAZAN %s: the claws barely move (%.2f): no rake", role, moved))
	end
end)

test("the weapons in hand (SHIN's katana, RAIJIN's spear, YUKINA's fans, KAZAN's claws) never go through the floor on the ground (R15)", function()
	local WeaponSpec = require("../src/shared/WeaponSpec")
	local anim = newAnimator(KAI)
	for _, kit in { "SHIN", "RAIJIN", "YUKINA", "KAZAN" } do
		anim.kit = kit
		for _, id in MoveData.Kits[kit].Roles do
			for _, phase in { "Startup", "Active", "Active2", "Recovery" } do
				local pose = Poses[id][phase]
				if pose and not MoveData.Moves[id].air and ((pose.Ground and pose.Ground[1]) or 1) > 0.5 then
					local r = anim:resolve(pose)
					local parts = {}
					for name, f in K.solve(KAI, r, anim:groundLift(r, 0)) do
						if KAI.sizes[name] then parts[name] = { cframe = f, size = KAI.sizes[name] } end
					end
					for _, spec in { WeaponSpec[kit], WeaponSpec[kit].pair } do
						local grip = WeaponKit.grip(kit, parts, spec)
						for _, z in { spec.base, spec.tip } do
							local _, y = K.point(grip, 0, 0, z)
							expect(y - KAI.floor > -0.05, string.format("%s %s.%s: the weapon is %.2f under the floor", kit, id, phase, KAI.floor - y))
						end
					end
				end
			end
		end
	end
end)

test("RAIJIN fights with a spear: both hands on the shaft, thrusts driven straight and far (R15)", function()
	local WeaponSpec = require("../src/shared/WeaponSpec")
	local spec = WeaponSpec.RAIJIN
	local anim = newAnimator(KAI)
	anim.kit = "RAIJIN"
	local function hold(pose)
		local r = anim:resolve(pose)
		local parts = {}
		for name, f in K.solve(KAI, r, anim:groundLift(r, 0)) do
			if KAI.sizes[name] then parts[name] = { cframe = f, size = KAI.sizes[name] } end
		end
		local grip = WeaponKit.grip("RAIJIN", parts, spec)
		local gx, gy, gz = K.point(grip, 0, 0, 0)
		local tx, ty, tz = K.point(grip, 0, 0, spec.tip)
		local dx, dy, dz = tx - gx, ty - gy, tz - gz
		local len = math.sqrt(dx * dx + dy * dy + dz * dz)
		dx, dy, dz = dx / len, dy / len, dz / len
		local h = parts.LeftHand.cframe
		local u = math.clamp((h[1] - gx) * dx + (h[2] - gy) * dy + (h[3] - gz) * dz, 0.4, 2.8)
		local off = math.sqrt((gx + dx * u - h[1]) ^ 2 + (gy + dy * u - h[2]) ^ 2 + (gz + dz * u - h[3]) ^ 2)
		return { tip = { tx, ty, tz }, yaw = math.deg(math.atan2(dx, -dz)), left = off }
	end
	-- The thrusts: the tip goes far ahead, straight at the target, from a drawn-back spear.
	for _, role in { "Jab", "BodyBlow", "Smash", "PalmStrike", "KiFlurry", "LowKick" } do
		local id = MoveData.Kits.RAIJIN.Roles[role]
		local s, a = hold(Poses[id].Startup), hold(Poses[id].Active)
		expect(-a.tip[3] > 5.8, string.format("%s: the thrust only reaches %.1f studs", id, -a.tip[3]))
		expect(math.abs(a.yaw) < 18, string.format("%s: the thrust goes off to the side (%.0f°)", id, a.yaw))
		expect(s.tip[3] - a.tip[3] > 2.2, string.format("%s: the tip only travels %.1f studs forward", id, s.tip[3] - a.tip[3]))
	end
	-- Both hands on the shaft (the throws and the raised spear of the ultimates aside).
	local ONE = { Finale = { Active = true, Recovery = true }, KiBlast = true, Fatal = true,
		KaienRush = { Startup = true }, Awakening = { Startup = true }, Kaiten = { Startup = true } }
	for role, id in MoveData.Kits.RAIJIN.Roles do
		for _, key in { "Startup", "Active", "Active2" } do
			local pose = Poses[id][key]
			local one = ONE[role] == true or (type(ONE[role]) == "table" and ONE[role][key])
			if pose and not one then
				local h = hold(pose)
				expect(h.left < 0.45, string.format("%s.%s: the left hand is %.2f off the shaft", id, key, h.left))
			end
		end
	end
end)

test("SHIN's sword strokes sweep the blade, never a fist holding a stick up (R15, avatar, R6)", function()
	local RISING = { ShinRising = true, ShinSkyCut = true } -- rising cuts end with the blade high
	for label, body in BODIES do
		for _, id in MoveData.Kits.SHIN.Roles do
			local set = Poses[id]
			if set and set.Active and set.Startup then
				local _, t0 = weaponLine("SHIN", set.Startup, body[1], body[2])
				local b, t = weaponLine("SHIN", set.Active, body[1], body[2])
				local dx, dy, dz = t[1] - b[1], t[2] - b[2], t[3] - b[3]
				local up = dy / math.sqrt(dx * dx + dy * dy + dz * dz)
				local travel = math.sqrt((t[1] - t0[1]) ^ 2 + (t[2] - t0[2]) ^ 2 + (t[3] - t0[3]) ^ 2)
				expect(travel > 1.5, string.format("%s %s: the blade's tip only travels %.1f studs from wind-up to contact", label, id, travel))
				expect(RISING[id] or up < 0.8, string.format("%s %s: the blade stands up (%.2f) at contact", label, id, up))
			end
		end
	end
end)

test("SHIN's guard: the katana raised over his head in both hands, the blade rising forward above him (R15, avatar, R6)", function()
	for label, body in BODIES do
		for _, key in { "Block", "CrouchBlock" } do
			local b, t, torso = weaponLine("SHIN", Poses.Kits.SHIN[key], body[1], body[2])
			local dx, dy, dz = t[1] - b[1], t[2] - b[2], t[3] - b[3]
			local length = math.sqrt(dx * dx + dy * dy + dz * dz)
			local above = b[2] - torso[2]
			-- (the hilt over his head: well above his chest; the blade climbing, toward the opponent)
			expect(above > 1.8, string.format("%s %s: the hilt is only %.2f above his chest (not over his head)", label, key, above))
			expect(dy / length > 0.2 and dy / length < 0.85, string.format("%s %s: the blade is not on a rising diagonal (%.2f)", label, key, dy / length))
			expect(-dz / length > 0.3, string.format("%s %s: the blade does not point toward the opponent (%.2f)", label, key, -dz / length))
		end
	end
end)

test("KAI's ki beam from the sky: bent over, both arms driven down at the target, palms joined (R15, avatar)", function()
	for label, skel in { R15 = KAI, avatar = AVATAR } do
		local anim = newAnimator(skel)
		local view = { x = 0, y = 10, vx = 0, vy = 0, facing = 1, state = "Attack", move = "KiBlast", moveFrame = 12,
			hitstop = 0, combo = 0, kit = "KAI", pose = "KiBeamDown" }
		local pose, lift
		for t = 0, 30 do pose, lift = anim:step(view, nil, 1 / 60, t / 60, 60, true) end
		local solved = K.solve(skel, pose, lift)
		local hand, arm, other = solved.RightHand, solved.RightUpperArm, solved.LeftHand
		-- (the rig faces -Z: forward is -z)
		local down, forward = arm[2] - hand[2], arm[3] - hand[3]
		local angle = math.deg(math.atan2(forward, down))
		expect(down > 0.8 and angle > -8 and angle < 25,
			string.format("%s: the arms point %.0f degrees off straight down (%.1f down)", label, angle, down))
		local apart = math.sqrt((hand[1] - other[1]) ^ 2 + (hand[2] - other[2]) ^ 2 + (hand[3] - other[3]) ^ 2)
		expect(apart < 1.3, string.format("%s: the palms are %.2f studs apart", label, apart))
		expect(solved.Head[3] < solved.LowerTorso[3] - 0.5, label .. ": he does not lean over the target")
	end
end)

test("finishers and ultimates strike with one fist, the other pulled back: never two fists glued together (R15, avatar)", function()
	local ids = { "Finale", "Awakening", "Fatal", "TaroAwakening", "TaroFinale", "TaroFatal", "RyukenAwakening", "RyukenFatal",
		"RyukenRush", "DaichaRush", "DaichaAwakening", "DaichaGate", "DaichaPush", "DaichaThrow", "DaichaFinale", "DaichaFatal",
		"AkemiFatal", "AkemiAwakening", "ShinRush", "HibecaresFatal", "HibecaresGate" }
	for label, skel in { R15 = KAI, avatar = AVATAR } do
		for _, id in ids do
			local m = MoveData.Moves[id]
			if m then
				local anim = newAnimator(skel)
				local kit = MoveData.MoveKit and MoveData.MoveKit[id] or "KAI"
				local closest = math.huge
				for f = 0, m.startup + m.active do
					local view = { x = 0, y = 0, vx = 0, vy = 0, facing = 1, state = "Attack", move = id, moveFrame = f,
						hitstop = 0, combo = 0, kit = kit }
					local pose, lift = anim:step(view, nil, 1 / 60, f / 60, 60, false)
					if f > m.startup then
						local s = K.solve(skel, pose, lift)
						local l, r = s.LeftHand, s.RightHand
						closest = math.min(closest, math.sqrt((l[1] - r[1]) ^ 2 + (l[2] - r[2]) ^ 2 + (l[3] - r[3]) ^ 2))
					end
				end
				expect(closest > 1.5, string.format("%s %s: both fists %.2f studs apart on the blow", label, id, closest))
			end
		end
	end
end)

test("SHIN's katana never stands up out of the floor when he is down or getting up (R15, avatar, R6)", function()
	local kit = Poses.Kits.SHIN
	for label, body in BODIES do
		for _, name in { "DownImpact", "Down", "DownFace", "Kneel" } do
			local b, t = weaponLine("SHIN", kit[name], body[1], body[2])
			local dx, dy, dz = t[1] - b[1], t[2] - b[2], t[3] - b[3]
			local up = dy / math.sqrt(dx * dx + dy * dy + dz * dz)
			local limit = if name == "Kneel" then 0.3 else 0.45
			expect(up < limit, string.format("%s %s: the blade points to the sky (%.2f)", label, name, up))
		end
	end
end)

test("DAICHA's matter: circles when idle, gathers in her hand and strikes as a sphere, a disc in guard, comes back", function()
	local OrbFlight = require("../src/shared/OrbFlight")
	-- Idle (Wilhem's sheet): small, floating just before her hand, never in her body.
	for i = 0, 40 do
		local o = OrbFlight.offset({ state = "Idle" }, nil, nil, i / 40 * OrbFlight.ORBIT.period)
		-- (0.23.5: near her hand, but floating ahead of it, never on it)
		expect(o.fwd > 1.3 and o.fwd < 2.1 and o.up > 3.8 and o.up < 4.7, "the idle orb is not near her hand")
		expect(math.sqrt(o.fwd ^ 2 + o.side ^ 2) > 0.9, "the idle orb goes through her body")
	end
	expect(OrbFlight.form({ state = "Idle" }, nil).radius < 0.4, "the orb is not small at rest")
	-- Her normals (Wilhem's sheet): the 3rd light blow scrapes the floor, the 2nd follows an
	-- arc, the heavy one is drawn back first, grows a little, and hits harder.
	local roles = MoveData.Kits.DAICHA.Roles
	local function fly(role, frame)
		local m = MoveData.Moves[roles[role]]
		return OrbFlight.offset({ state = "Attack", move = roles[role], moveFrame = frame }, m, role, 1), m
	end
	local low, lm = fly("Elbow", MoveData.Moves[roles.Elbow].startup + 1)
	expect(low.up <= 0.9, string.format("the low blow does not scrape the floor (%.2f)", low.up))
	local _, cm = fly("Cross", 0)
	local mid = fly("Cross", cm.startup - 2)
	local hand = OrbFlight.hand(OrbFlight.strike(cm, "Cross"))
	local hit = OrbFlight.strike(cm, "Cross")
	expect(mid.up > (hand.up + hit.up) / 2 + 0.5, "the second blow does not arc")
	local _, sm = fly("Smash", 0)
	local drawn = fly("Smash", math.floor((sm.startup - 2) * 0.5))
	expect(drawn.fwd < 0, "the heavy blow does not draw the orb back")
	local function r(role, m, frame)
		return OrbFlight.form({ state = "Attack", move = roles[role], moveFrame = frame }, m, role).radius
	end
	expect(r("Smash", sm, sm.startup) > r("Smash", sm, 0), "the orb does not grow for the heavy blow")
	expect(r("Smash", sm, sm.startup + 1) > r("Jab", MoveData.Moves[roles.Jab], MoveData.Moves[roles.Jab].startup + 1),
		"the heavy impact is not bigger than a light one")
	local _ = lm
	-- Every strike: close during the wind-up, at the end of the reach on contact, back on the orbit after.
	for role, id in MoveData.Kits.DAICHA.Roles do
		local m = MoveData.Moves[id]
		if m.hitbox and role ~= "DragonTornado" and role ~= "RisingWind" then
			local function at(frame)
				return OrbFlight.offset({ state = "Attack", move = id, moveFrame = frame }, m, role, 1)
			end
			local hit = at(m.startup + 1)
			expect(math.abs(hit.fwd - math.max(1.4, m.hitbox.far + OrbFlight.AHEAD)) < 0.01 and hit.up >= 0.8,
				string.format("%s: the orb is not at the point of impact on contact (%.2f)", id, hit.fwd))
			local back = at(m.startup + m.active + m.recovery)
			local orbit = OrbFlight.orbit(1, false)
			expect(math.abs(back.fwd - orbit.fwd) + math.abs(back.side - orbit.side) < 0.01, id .. ": the orb never returns to its orbit")
		end
	end
	-- (Wilhem) its FORM: during a strike it never goes through her nor under the deck; it
	-- gathers at her hand during the wind-up, compacting (a smaller ball), and swells on contact.
	local gathered = 0
	for role, id in MoveData.Kits.DAICHA.Roles do
		local m = MoveData.Moves[id]
		if m.hitbox and role ~= "DragonTornado" and role ~= "RisingWind" then
			for frame = 0, m.startup + m.active + m.recovery do
				local o = OrbFlight.offset({ state = "Attack", move = id, moveFrame = frame }, m, role, 1)
				expect(o.up >= 0.6, string.format("%s frame %d: the orb is under the deck", id, frame))
				expect(math.sqrt(o.fwd ^ 2 + o.side ^ 2) >= 0.9 or o.up > 6.2,
					string.format("%s frame %d: the orb goes through her body", id, frame))
			end
			local wind = OrbFlight.offset({ state = "Attack", move = id, moveFrame = m.startup - 2 }, m, role, 1)
			local hand = OrbFlight.hand(OrbFlight.strike(m))
			if m.startup >= 5 and math.abs(wind.fwd - hand.fwd) + math.abs(wind.up - hand.up) < 0.6 then gathered += 1 end
			local function radius(frame)
				local f = OrbFlight.form({ state = "Attack", move = id, moveFrame = frame }, m)
				expect(f.shape == "ball", id .. ": a strike that is not a sphere")
				return f.radius
			end
			expect(radius(m.startup) < radius(0), id .. ": the matter does not compact during the wind-up")
			expect(radius(m.startup + 1) > radius(0) * 1.5, id .. ": the sphere does not swell on contact")
		end
	end
	expect(gathered >= 6, string.format("the matter only gathers in her hand on %d strikes", gathered))
	-- Guard: the same matter flattened into a wide disc before her; idle: a sphere again.
	local disc = OrbFlight.form({ state = "Blocking" }, nil)
	expect(disc.shape == "disc" and disc.radius > 1.4 and disc.thickness < 0.3, "the guard is not a flat disc")
	expect(OrbFlight.form({ state = "CrouchBlockstun" }, nil).shape == "disc", "the low guard is not a disc")
	expect(OrbFlight.form({ state = "Idle" }, nil).shape == "ball", "the idle matter is not a sphere")
	-- Guard: a shield before him.
	local guard = OrbFlight.offset({ state = "Blocking" }, nil, nil, 0)
	expect(guard.fwd > 1, "the orb does not shield him")
	-- (Wilhem: « descends le bouclier »: the disc's top stays under her head, standing and low)
	expect(guard.up + disc.radius < 4.2, string.format("the shield rises to her face (top at %.1f)", guard.up + disc.radius))
	local low = OrbFlight.offset({ state = "CrouchBlocking" }, nil, nil, 0)
	expect(low.up < guard.up - 0.5, "the low guard is not lower than the standing one")
end)

T.test("DAICHA's matter: every blow its own path (rise, slam, dive, spin, throw, blink, mark, wrap, river, spear), a spring follow", function()
	local OrbFlight = require("../src/shared/OrbFlight")
	local roles = MoveData.Kits.DAICHA.Roles
	local function get(role) return MoveData.Moves[roles[role]] end
	local function at(role, frame)
		return OrbFlight.offset({ state = "Attack", move = roles[role], moveFrame = frame }, get(role), role, 1)
	end
	local function form(role, frame)
		return OrbFlight.form({ state = "Attack", move = roles[role], moveFrame = frame }, get(role), role, 1)
	end
	-- every DAICHA role has a named path, and they are not all the same
	local kinds = {}
	for role in roles do
		if OrbFlight.PATH[role] then kinds[OrbFlight.PATH[role]] = true end
	end
	local n = 0
	for _ in kinds do n += 1 end
	expect(n >= 14, "too few distinct orb paths: " .. n)
	-- RISING SHADOW: from the floor, on up through the target
	local up = get("Uppercut")
	expect(at("Uppercut", up.startup - 1).up < 1.5, "the rising shadow does not start at the floor")
	expect(at("Uppercut", up.startup + up.active).up > at("Uppercut", up.startup + 1).up + 1.5, "the rising shadow does not rise")
	-- FALL: raised high over her head, crushed down to the floor
	local hm = get("Hammer")
	expect(at("Hammer", hm.startup - 4).up > 6, "the fall is not raised over her head")
	expect(at("Hammer", hm.startup + 1).up < 2, "the fall is not crushed down")
	expect(form("Hammer", hm.startup + 1).radius > form("Jab", get("Jab").startup + 1).radius, "the fall's impact is not bigger")
	-- SHADOW DIVE: from above, down before her
	local dv = get("AirSmash")
	expect(at("AirSmash", dv.startup - 3).up > 4.5 and at("AirSmash", dv.startup + 1).up < 2, "the dive does not come down")
	-- SPIN DRILL: one turn round her (behind her back)
	local sp, behind = get("SpinKick"), false
	for frame = 0, sp.startup do
		if at("SpinKick", frame).fwd < -0.8 then behind = true end
	end
	expect(behind, "the spin drill does not turn round her")
	-- REAPER: from behind her, low
	local rp = get("Sweep")
	local w = at("Sweep", rp.startup - 4)
	expect(w.fwd < 0 and w.up < 1.5, "the reaper does not start low behind her")
	-- INVERTED SPHERE: the orb IS the thrown sphere, a new one forms in her hand
	local kb = get("KiBlast")
	expect(form("KiBlast", kb.startup - 1).radius > OrbFlight.SIZE.rest, "the sphere does not swell before the throw")
	expect(form("KiBlast", kb.startup + 1).radius < 0.05, "the orb is still there once thrown")
	expect(math.abs(form("KiBlast", kb.startup + kb.active + kb.recovery).radius - OrbFlight.SIZE.rest) < 0.01, "no new orb forms")
	-- TELEPORT: squeezed to a point as she vanishes, bursting where she strikes
	local tp = get("Rising")
	expect(form("Rising", tp.startup).radius < 0.1, "the orb is not squeezed as she vanishes")
	expect(form("Rising", tp.startup + 1).radius > 0.8, "the orb does not burst out where she strikes")
	-- DARK MARK: it clings to the target a moment
	local mk = get("PalmStrike")
	local hit = at("PalmStrike", mk.startup + 1)
	local cling = at("PalmStrike", mk.startup + mk.active + math.floor(mk.recovery * 0.3))
	expect(math.abs(cling.fwd - hit.fwd) + math.abs(cling.up - hit.up) < 0.01, "the dark mark does not cling")
	-- EMBRACE: it coils round the target
	local bb, far = get("BodyBlow"), 0
	local bh = at("BodyBlow", bb.startup + 1)
	for frame = bb.startup + 1, bb.startup + bb.active do
		local o = at("BodyBlow", frame)
		far = math.max(far, math.abs(o.side - bh.side) + math.abs(o.up - bh.up))
		expect(math.abs(o.fwd - bh.fwd) < 1.2, "the embrace leaves the target")
	end
	expect(far > 0.3, "the embrace does not coil")
	-- SHADOW CURRENT: from beat to beat, up and down
	local rv, lo, hi = get("KiFlurry"), math.huge, -math.huge
	for frame = rv.startup + 1, rv.startup + rv.active do
		local y = at("KiFlurry", frame).up
		lo, hi = math.min(lo, y), math.max(hi, y)
	end
	expect(hi - lo > 1, "the shadow current does not flow up and down")
	-- SHADOW ARROW: stretched into an arrow
	expect(form("DragonFist", get("DragonFist").startup + 2).stretch > 2, "the shadow arrow is not stretched")
	-- no blow teleports the orb (the client spring smooths the rest)
	for role, id in roles do
		local m = MoveData.Moves[id]
		if m.hitbox and OrbFlight.path(role) ~= "vortex" then
			local last = at(role, 0)
			for frame = 1, m.startup + m.active + m.recovery do
				local o = at(role, frame)
				local d = math.sqrt((o.fwd - last.fwd) ^ 2 + (o.up - last.up) ^ 2 + (o.side - last.side) ^ 2)
				expect(d < 3.2, string.format("%s frame %d: the orb jumps %.2f", id, frame, d))
				last = o
			end
		end
	end
	-- K.O.: spread on the floor, a puddle; a blow on the guard pushes the disc wider
	local ko = OrbFlight.offset({ state = "KO" }, nil, nil, 0)
	expect(ko.up < 0.2 and OrbFlight.form({ state = "KO" }, nil).shape == "puddle", "no puddle at the K.O.")
	expect(OrbFlight.form({ state = "Blockstun" }, nil).radius > OrbFlight.form({ state = "Blocking" }, nil).radius, "the disc does not give under a blow")
	-- at rest it breathes, a little
	local r1, r2 = OrbFlight.form({ state = "Idle" }, nil, nil, 0.6).radius, OrbFlight.form({ state = "Idle" }, nil, nil, 1.9).radius
	expect(math.abs(r1 - r2) > 0.005 and math.abs(r1 - r2) < 0.06, "the orb does not breathe at rest")
	-- the spring: lags behind a step, overshoots a little, settles; tight in a strike; snaps on a teleport
	local s = { p = { 0, 0, 0 }, v = { 0, 0, 0 } }
	OrbFlight.follow(s, { 1, 0, 0 }, 1 / 60, false)
	expect(s.p[1] > 0 and s.p[1] < 0.3, "the loose orb does not lag behind")
	local peak = 0
	for _ = 1, 120 do
		OrbFlight.follow(s, { 1, 0, 0 }, 1 / 60, false)
		peak = math.max(peak, s.p[1])
	end
	expect(peak > 1.02 and peak < 1.3, string.format("the loose orb overshoot is off (%.2f)", peak))
	expect(math.abs(s.p[1] - 1) < 0.01, "the loose orb never settles")
	local t = { p = { 0, 0, 0 }, v = { 0, 0, 0 } }
	for _ = 1, 4 do OrbFlight.follow(t, { 2, 0, 0 }, 1 / 60, true) end
	expect(t.p[1] > 1.6, "the orb lags too far behind a strike")
	OrbFlight.follow(t, { 30, 0, 0 }, 1 / 60, true)
	expect(t.p[1] == 30, "the orb does not snap after a teleport")
end)

T.test("DAICHA's matter looks alive: a corona, motes and a light that breathe at rest, burn when gathered, flare on the impact", function()
	local OrbFlight = require("../src/shared/OrbFlight")
	local roles = MoveData.Kits.DAICHA.Roles
	local function look(view, move, role, time)
		local m = move and MoveData.Moves[move]
		return OrbFlight.look(view, m, role, time or 1, OrbFlight.form(view, m, role, time or 1))
	end
	local rest = look({ state = "Idle" }, nil, nil, 1)
	expect(rest.halo > 1.1 and rest.haloT > 0.6 and rest.sats > 1.5 and rest.light < 1, "the orb is not calm at rest")
	local a, b = look({ state = "Idle" }, nil, nil, 0.65), look({ state = "Idle" }, nil, nil, 1.95)
	expect(math.abs(a.halo - b.halo) > 0.02, "its corona does not breathe at rest")
	for role, id in roles do
		local m = MoveData.Moves[id]
		if m.hitbox and OrbFlight.path(role) ~= "vortex" then
			local gathered = look({ state = "Attack", moveFrame = m.startup }, id, role)
			local contact = look({ state = "Attack", moveFrame = m.startup + 1 }, id, role)
			local after = look({ state = "Attack", moveFrame = m.startup + m.active + m.recovery }, id, role)
			expect(gathered.light > rest.light and gathered.haloT < rest.haloT and gathered.sats < rest.sats,
				id .. ": it does not burn brighter, its motes drawn in, when gathered")
			expect(contact.halo > gathered.halo and contact.light > gathered.light and contact.sats > gathered.sats,
				id .. ": no flare on the impact")
			expect(math.abs(after.light - rest.light) < 0.3 and math.abs(after.halo - rest.halo) < 0.15, id .. ": it does not calm down after")
			for frame = 0, m.startup + m.active + m.recovery do
				local l = look({ state = "Attack", moveFrame = frame }, id, role)
				expect(l.haloT >= 0 and l.haloT <= 1 and l.light >= 0 and l.halo >= 0, id .. ": a look out of range")
			end
		end
	end
	local guard = look({ state = "Blocking" }, nil, nil)
	expect(guard.halo == 0 and guard.sats == 0 and guard.light > 0, "the disc keeps the sphere's corona or motes")
	expect(look({ state = "KO" }, nil, nil).wisps > 0.5, "no shadow rises off the puddle")
	local kb = MoveData.Moves[roles.KiBlast]
	local thrown = look({ state = "Attack", moveFrame = kb.startup + 1 }, roles.KiBlast, "KiBlast")
	expect(thrown.light == 0 and thrown.halo == 0 and thrown.sats == 0, "the thrown orb still shines in her hand")
end)

T.test("SHIN's katana is a real katana: guard, collar, wrapped hilt, a blade that curves back to an angled point", function()
	local WeaponSpec = require("../src/shared/WeaponSpec")
	local spec, by = WeaponSpec.SHIN, {}
	for _, p in spec.pieces do by[p.name] = p end
	for _, name in { "Pommel", "Handle", "Guard", "GuardRim", "Habaki", "Blade", "Ridge", "Edge", "BladeTip", "Kissaki" } do
		expect(by[name] ~= nil, "SHIN's katana has no " .. name)
	end
	local wraps = 0
	for name in by do if name:sub(1, 5) == "WrapX" then wraps += 1 end end
	expect(wraps >= 4, "the hilt is not wrapped in crossed cord")
	-- the guard sits between the hilt and the blade; the point ends where the blade ends
	expect(by.Handle.z > by.Guard.z and by.Guard.z > by.Blade.z, "the guard is not between the hilt and the blade")
	expect(math.abs(by.Kissaki.z - by.Kissaki.size[3] / 2 - spec.tip) < 0.15, "the point does not end at the tip")
	-- the curve (sori): toward the point the blade rises to its back (+Y), more and more
	expect((by.BladeTip.rot[1] or 0) > 0 and by.Kissaki.rot[1] > by.BladeTip.rot[1], "the blade does not curve back to its point")
	-- the temper line glows along the cutting edge (-Y), the ridge sits above it
	expect(by.Edge.y < 0 and by.Ridge.y > 0 and by.Edge.color == "energy", "the edge / ridge are not where a katana has them")
end)

T.test("YUKINA's fans are real folding fans: sticks fanning out from a rivet, a leaf of panels between them, a rim of frost", function()
	local WeaponSpec = require("../src/shared/WeaponSpec")
	for _, spec in { WeaponSpec.YUKINA, WeaponSpec.YUKINA.pair } do
		local sticks, panels, rims, angles = 0, 0, 0, {}
		local rivet
		for _, p in spec.pieces do
			local n = p.name
			if n == "FanSpine" or n == "FanGuard" or n:sub(1, 6) == "FanRib" then
				sticks += 1
				table.insert(angles, p.rot and p.rot[1] or 0)
			elseif n:sub(1, 7) == "FanLeaf" then
				panels += 1
			elseif n:sub(1, 7) == "FanEdge" then
				rims += 1
			elseif n == "FanRivet" then
				rivet = p
			end
		end
		expect(sticks >= 5 and panels == sticks - 1 and rims == panels, "a fan is not sticks with a leaf and a rim between them")
		table.sort(angles)
		expect(angles[#angles] - angles[1] > 45, "the fan is not opened")
		expect(rivet ~= nil and rivet.shape == "Cylinder", "the sticks have no rivet")
	end
end)

T.test("held weapons are alive like DAICHA's orb: they breathe at rest, burn when gathered, flare on the impact, glint", function()
	local WeaponFX = require("../src/shared/WeaponFX")
	local WeaponSpec = require("../src/shared/WeaponSpec")
	for kit, cfg in WeaponFX.KITS do
		-- (the parts it lights are the weapon's own pieces)
		local spec, names = WeaponSpec[kit], {}
		for _, p in spec.pieces do names[p.name] = true end
		expect(names[cfg.blade] and names[cfg.edge] and (not cfg.shaft or names[cfg.shaft]), kit .. ": WeaponFX names a piece its weapon has not")
		expect(WeaponFX.ELEMENTS[cfg.element] ~= nil, kit .. ": no element")
		local roles = MoveData.Kits[kit].Roles
		local rest = WeaponFX.look({ state = "Idle" }, nil, 1)
		local a, b = WeaponFX.look({ state = "Idle" }, nil, 0.7), WeaponFX.look({ state = "Idle" }, nil, 2.1)
		expect(math.abs(a.light - b.light) > 0.05, kit .. ": its weapon does not breathe at rest")
		local m = MoveData.Moves[roles.Smash]
		local gathered = WeaponFX.look({ state = "Attack", moveFrame = m.startup }, m, 1)
		local contact = WeaponFX.look({ state = "Attack", moveFrame = m.startup + 1 }, m, 1)
		local after = WeaponFX.look({ state = "Attack", moveFrame = m.startup + m.active + m.recovery }, m, 1)
		expect(gathered.glow > rest.glow and gathered.light > rest.light, kit .. ": no burn when the blow gathers")
		expect(contact.flare > 0.9 and contact.light > gathered.light, kit .. ": no flare on the impact")
		expect(math.abs(after.light - rest.light) < 0.3, kit .. ": it does not calm down after")
	end
	expect(WeaponFX.look({ state = "Blocking" }, nil, 1).glow > WeaponFX.look({ state = "Idle" }, nil, 0).glow - 0.2, "the guard dims the weapon")
	expect(WeaponFX.look({ state = "KO" }, nil, 1).light < 0.2, "a fallen fighter's weapon still burns")
	-- the glint runs once down the blade, then rests
	local seen, idle = 0, 0
	for i = 0, 319 do
		local u = WeaponFX.glint(i / 100)
		if u then seen += 1 else idle += 1 end
	end
	expect(seen > 10 and idle > seen * 4, "the glint is never there, or always")
end)

T.test("DAICHA's matter flows: one smooth curve per path, a clock that never goes back, chained from where it was, measured fluid", function()
	local OrbFlight = require("../src/shared/OrbFlight")
	local roles = MoveData.Kits.DAICHA.Roles
	-- every path is one curve whose speed never jumps (at its keys too), at any fractional frame
	for role, id in roles do
		local m = MoveData.Moves[id]
		local path = OrbFlight.path(role)
		if path ~= "vortex" then
			local keys = OrbFlight.keys(path, m, OrbFlight.orbit(1, false), role)
			for i = 2, #keys - 1 do
				local t, e = keys[i].t, 1e-3
				local a, b, c = OrbFlight.curve(keys, t - e), OrbFlight.curve(keys, t), OrbFlight.curve(keys, t + e)
				local jump = math.abs((c.fwd - b.fwd) - (b.fwd - a.fwd)) + math.abs((c.up - b.up) - (b.up - a.up))
					+ math.abs((c.side - b.side) - (b.side - a.side))
				expect(jump / e < 0.05, string.format("%s: its speed jumps at key %d (frame %.2f)", id, i, t))
			end
			-- (and between two frames, at half-frames, it is in between: drawn smoothly at 120 fps)
			local mid = OrbFlight.offset({ state = "Attack", moveFrame = 1.5 }, m, role, 1)
			expect(mid.fwd == mid.fwd and mid.up >= 0.6, id .. ": no place at a half frame")
		end
	end
	-- the move's clock never goes back (a hit-stop the client had not foreseen), a new move starts it again
	local c = {}
	expect(OrbFlight.clock(c, "DaichaClaw", 3.4) == 3.4, "the clock does not start")
	expect(OrbFlight.clock(c, "DaichaClaw", 2.6) == 3.4, "the clock goes back")
	expect(OrbFlight.clock(c, "DaichaClaw", 4.1) == 4.1, "the clock does not go on")
	local last = { fwd = 3.1, up = 2.2, side = 0.4 }
	expect(OrbFlight.clock(c, "DaichaStep", 0.5, last) == 0.5 and c.from.fwd == 3.1, "a new move does not restart the clock")
	-- a blow chained from another starts from where the matter was, not from its rest point
	local step = MoveData.Moves[roles.Cross]
	local o = OrbFlight.offset({ state = "Attack", moveFrame = 0 }, step, "Cross", 1, last)
	expect(math.abs(o.fwd - 3.1) + math.abs(o.up - 2.2) < 0.01, "a chained blow jumps back to the rest point")
	-- the spring: a teleport of her body re-forms the matter there; its stiffness blends between loose and tight
	local s = { p = { 0, 3, 0 }, v = { 0, 0, 0 } }
	OrbFlight.follow(s, { 1, 3, 0 }, 1 / 60, 0, { 0, 0 })
	OrbFlight.follow(s, { 1.1, 3, 0 }, 1 / 60, 0, { 0.25, 0 }) -- (walking, dashing: followed)
	expect(not s.snapped, "a dash re-forms the orb")
	OrbFlight.follow(s, { 5, 3, 0 }, 1 / 60, 0, { 4.25, 0 }) -- (a teleport)
	expect(s.snapped and s.p[1] == 5, "a teleport does not re-form the orb where she is")
	local function moved(tight)
		local q = { p = { 0, 0, 0 }, v = { 0, 0, 0 } }
		OrbFlight.follow(q, { 1, 0, 0 }, 1 / 60, tight)
		return q.p[1]
	end
	expect(moved(0) < moved(0.5) and moved(0.5) < moved(1), "the spring does not blend from loose to tight")
	-- measured like in game (snapshots at 30 a second, drawn at 120): fluid round her, and
	-- (0.23.5) almost never in her body
	local OrbQuality = require("./OrbQuality")
	for _, name in { "routes", "combo", "heavy", "walk" } do
		local q = OrbQuality.measure(name, 120, false)
		expect(q.relZigzag <= 6, string.format("the orb stutters round her in %s (%d)", name, q.relZigzag))
		expect(q.inside <= q.frames * 0.03, string.format("the orb is in her body in %s (%d frames of %d)", name, q.inside, q.frames))
		expect(q.onScreen <= q.frames * 0.05, string.format("the orb is over her on screen in %s (%d frames of %d)", name, q.onScreen, q.frames))
	end
	expect(OrbQuality.measure("walk", 120, false).inside == 0, "the orb is in her body while she walks")
end)

T.test("held weapons keep out of their own fighter's body; a leg settles onto the floor without a jump", function()
	-- (tests/WeaponClearance.luau: real fights, real poses, the weapon placed like the RigBuilder)
	local WeaponClearance = require("./WeaponClearance")
	expect(WeaponClearance.measure("SHIN", "walk").through == 0, "SHIN's blade cuts through his leg as he walks")
	expect(WeaponClearance.measure("YUKINA", "showcase").through == 0, "YUKINA's fans go through her body")
	local raijin = WeaponClearance.measure("RAIJIN", "walk")
	expect(raijin.through <= raijin.frames * 0.3, string.format("RAIJIN's spear is in his body (%d of %d frames)", raijin.through, raijin.frames))
	expect(WeaponClearance.measure("KAZAN", "moves").through <= 2, "KAZAN's claws go through his body")
	-- the big jumps of a joint in one tick (over 50 degrees, not an impact's cut), every kit
	local ClipKit = require("./ClipKit")
	local JOINTS = { "LeftHip", "RightHip", "LeftKnee", "RightKnee" }
	for _, kit in { "KAI", "RAIJIN", "AKEMI" } do
		local last, worst, at = nil, 0, ""
		ClipKit.play(kit, "routes", 60, function(info)
			local pose = info.poses[1]
			if last and not info.snaps[1] then
				for _, j in JOINTS do
					local d = math.abs((pose[j] and pose[j][1] or 0) - (last[j] or 0))
					if d > worst then worst, at = d, string.format("t%d %s %s", info.tick, j, tostring(info.keys[1])) end
				end
			end
			last = {}
			for _, j in JOINTS do last[j] = pose[j] and pose[j][1] or 0 end
		end)
		expect(worst < 50, string.format("%s: a leg jumps %.0f degrees in one tick (%s)", kit, worst, at))
	end
end)

T.test("DAICHA's matter keeps off her body: never in her arms, never stuck to her (Wilhem)", function()
	local OrbFlight = require("../src/shared/OrbFlight")
	-- a box 1 x 2 x 1 at the origin: a point inside is pushed out, `margin` clear of it
	local box = { 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0.5, 1, 0.5 }
	local out = OrbFlight.avoid({ 0.2, 0, 0 }, 0.3, { box }, 0.2)
	expect(OrbFlight.clearance(out[1], out[2], out[3], { box }, 0.5) >= -1e-3, "a point inside her is not pushed out")
	local free = OrbFlight.avoid({ 3, 0, 0 }, 0.3, { box }, 0.2)
	expect(free[1] == 3 and free[2] == 0, "a point clear of her is moved")
	-- pushed along a fixed way only: it slides, it never flips side
	local along = OrbFlight.avoid({ 0.2, 0.3, 0.1 }, 0.3, { box }, 0.2, { 0, 0, 1 })
	expect(along[1] == 0.2 and along[2] == 0.3 and along[3] > 0.95, "the push does not keep to its way")
	local d = OrbFlight.avoidDirection("Attack", 1, { fwd = 3, up = 3, side = 0.3 })
	expect(d[1] > 0.8, "in a strike it is not pushed ahead of her fist")
	local e = OrbFlight.avoidDirection("Idle", -1, nil)
	expect(e[2] > 0.8 and e[1] < 0, "at rest it is not pushed up over her hands")
	-- the target a little ahead on the path, never past the move's end
	local m = MoveData.Moves[MoveData.Kits.DAICHA.Roles.Jab]
	expect(OrbFlight.leadFrame({ state = "Attack", moveFrame = 2 }, m) == 2 + OrbFlight.LEAD, "no lead in a strike")
	expect(OrbFlight.leadFrame({ state = "Attack", moveFrame = 99 }, m) == m.startup + m.active + m.recovery, "a lead past the move's end")
	-- her real poses, in a real fight: the place it aims at is never over her as the camera sees
	-- her (and so never in her)
	local OrbClearance = require("./OrbClearance")
	for _, name in { "showcase", "moves", "combo", "heavy", "routes", "walk" } do
		local q = OrbClearance.measure(name)
		local inside = 0
		for _, n in q.inside do inside += n end
		expect(q.onScreen == 0 and inside <= 1, string.format("%s: the orb aims over her on screen (%d frames) or into her (%d)", name, q.onScreen, inside))
	end
	-- on screen, a body part and a point right on it: pushed off it, up and forward at rest
	local arm = { 0, 3, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0.2, 0.6, 0.2 }
	local off = OrbFlight.avoid({ 0.1, 3.2, 1.5 }, 0.3, { arm }, 0.15, OrbFlight.avoidDirection("Idle", 1), true)
	expect(OrbFlight.screenClearance(off[1], off[2], { arm }, 0.3) >= -1e-3 and off[3] == 1.5, "not pushed off her arm on screen")
end)

-- ===================================================================== ASURA's four arms
local FourArms = require("../src/shared/FourArms")

-- Every point of ASURA's extra arms (torso space) for a view at time `now`.
local function asuraArms(view, now)
	local half = RigSpec.KAI.parts.UpperTorso.size[1] / 2
	local solved = FourArms.solve(FourArms.SPEC, FourArms.pose(view, now, MoveData.Moves), half)
	return solved
end

-- The bodies the extra arms must stay out of, in UpperTorso space: { centre, half size }.
local function asuraBodies()
	local parts = RigSpec.KAI.parts
	local ut = parts.UpperTorso
	local out = {}
	for _, name in { "UpperTorso", "LowerTorso", "Head" } do
		local p = parts[name]
		out[name] = { p.pos[1] - ut.pos[1], p.pos[2] - ut.pos[2], p.pos[3] - ut.pos[3], p.size[1] / 2, p.size[2] / 2, p.size[3] / 2 }
	end
	return out
end

test("ASURA's second pair of arms: raised guard, strikes, gatling pistons, never through his body", function()
	local bodies = asuraBodies()
	local margin = 0.22 -- (the arms' own thickness)
	local function inside(point)
		for name, b in bodies do
			if math.abs(point[1] - b[1]) < b[4] + margin and math.abs(point[2] - b[2]) < b[5] + margin
				and math.abs(point[3] - b[3]) < b[6] + margin then
				return name
			end
		end
		return nil
	end
	-- every state and every move ASURA can play (Wilhem: « vérifie les anim de ses bras »)
	local views = {}
	for _, state in { "Idle", "Walking", "Jumping", "Falling", "Blocking", "CrouchBlocking", "Crouching", "Hitstun", "Blockstun",
		"Launched", "Knockdown", "GetUp", "Dashing", "Cinematic", "KO" } do
		table.insert(views, { state = state })
	end
	-- the scenes of his ultimates (staged poses) and a staged blow without frame data
	for pose in FourArms.SCENE do table.insert(views, { state = "Idle", pose = pose }) end
	for _, pose in { "Roar", "Victory", "DownFace" } do table.insert(views, { state = "Idle", pose = pose }) end
	table.insert(views, { state = "Attack", move = "StagedBlow" })
	local ids = { "AsuraGatling" }
	for _, id in MoveData.Kits.ASURA.Roles do table.insert(ids, id) end
	for _, id in ids do
		local m = MoveData.Moves[id]
		for frame = 1, MoveData.total(m) do table.insert(views, { state = "Attack", move = id, moveFrame = frame }) end
	end
	for _, view in views do
		for now = 0, 1.2, 0.1 do
			for side, arm in asuraArms(view, now) do
				for k = 0, 10 do
					local t = k / 10
					local a, b = if t <= 0.5 then arm.shoulder else arm.elbow, if t <= 0.5 then arm.elbow else arm.fist
					local u = if t <= 0.5 then t * 2 else t * 2 - 1
					if k > 1 then -- (the shoulder itself sits against the flank)
						local point = { a[1] + (b[1] - a[1]) * u, a[2] + (b[2] - a[2]) * u, a[3] + (b[3] - a[3]) * u }
						local hit = inside(point)
						expect(not hit, string.format("%s %s %s frame %s: the %s arm goes through the %s", view.state, tostring(view.pose), tostring(view.move),
							tostring(view.moveFrame), side, tostring(hit)))
					end
				end
			end
		end
	end
	-- The extra shoulders come out of the flanks, under the real ones (not out of the back).
	local spec, half = FourArms.SPEC.shoulder, RigSpec.KAI.parts.UpperTorso.size[1] / 2
	expect(spec.x * half > half and math.abs(spec.z) < 0.25 and spec.y < 0, "the extra arms do not come out of the flanks")
	-- Guard: both fists up, out at the sides, above their elbows.
	local guard = asuraArms({ state = "Idle" }, 0)
	for side, arm in guard do
		expect(arm.fist[2] > arm.elbow[2] + 0.4 and math.abs(arm.fist[1]) > 2, side .. ": the guard is not raised out to the side")
	end
	-- In his ultimates the extra arms play the scene, never a frozen guard: standing tall they
	-- hang low, the power gathering spreads them wide, arms crossed they cross in front.
	local tall, flare, crossed = asuraArms({ state = "Idle", pose = "StandTall" }, 0), asuraArms({ state = "Idle", pose = "Kiai" }, 0),
		asuraArms({ state = "Idle", pose = "ArmsCrossed" }, 0)
	for side, arm in tall do
		expect(arm.fist[2] < guard[side].fist[2] - 1.5, side .. ": standing tall, the extra arm keeps its fighting guard")
		expect(math.abs(flare[side].fist[1]) > math.abs(guard[side].fist[1]) + 0.3, side .. ": the kiai does not spread the extra arms")
		expect(math.abs(crossed[side].fist[1]) < 1.2 and crossed[side].fist[3] < -0.8, side .. ": arms crossed, the extra pair does not cross in front")
	end
	local f1, f2 = asuraArms({ state = "Attack", move = "StagedBlow" }, 0), asuraArms({ state = "Attack", move = "StagedBlow" }, 0.1)
	expect(math.abs(f1.Left.fist[3] - f2.Left.fist[3]) > 0.2, "a staged blow leaves the extra arms still")
	-- An attack: the lead extra fist ends far in front (-Z) at the end of the active frames.
	local smash = MoveData.Moves.Smash
	local hit = asuraArms({ state = "Attack", move = "Smash", moveFrame = smash.startup + smash.active + 2 }, 0)
	expect(math.min(hit.Left.fist[3], hit.Right.fist[3]) < -0.9, "no extra fist thrown at the target")
	-- The gatling: the two fists out of phase, each going back and forth.
	local g = MoveData.Moves.AsuraGatling
	local apart, swings = 0, { Left = {}, Right = {} }
	for now = 0, 0.5, 0.02 do
		local arms = asuraArms({ state = "Attack", move = "AsuraGatling", moveFrame = g.startup + 5 }, now)
		apart = math.max(apart, math.abs(arms.Left.fist[3] - arms.Right.fist[3]))
		for side, arm in arms do table.insert(swings[side], arm.fist[3]) end
	end
	expect(apart > 0.6, "the gatling's fists move together")
	for side, list in swings do
		local lo, hi = math.min(table.unpack(list)), math.max(table.unpack(list))
		expect(hi - lo > 0.8, side .. " fist does not piston in the gatling")
	end
end)

T.finish()
