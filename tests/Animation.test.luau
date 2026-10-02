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

test("weapon kits never borrow KAI's punches or kicks (SHIN's blade, DAICHA's shadow, HIBECARES's stone; AKEMI's hands)", function()
	-- AKEMI keeps KAI's kicks for her kicks (salto, heel, sweep, low kick, flying knee, axe, palms).
	local AKEMI_KICKS = { Kick = true, SpinKick = true, Sweep = true, LowKick = true, ThunderHeel = true, CrescentMoon = true,
		KiChase = true, Hammer = true, PalmStrike = true }
	for _, kit in { "SHIN", "DAICHA", "HIBECARES", "AKEMI" } do
		for role, id in MoveData.Kits[kit].Roles do
			if not (kit == "AKEMI" and AKEMI_KICKS[role]) then
				expect(Poses[id] ~= nil, kit .. " " .. id .. " (" .. role .. ") uses KAI's poses")
				expect(Poses.STRIKE[id] ~= nil, kit .. " " .. id .. " has no strike limbs")
			end
		end
	end
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
	local pose = anim:step(view, nil, dt, dt, 60, false)
	local squash = pose.Root[4]
	for i = 2, 30 do pose = anim:step(view, nil, dt, i * dt, 60, false) end
	expect(squash < pose.Root[4] - 0.2, string.format("no landing squash (%.2f then %.2f)", squash, pose.Root[4]))
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
		local esquive = MoveData.Kits.TARO.Stances.ESQUIVE -- the weave and the roll belong to it
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
	local classic = settled(r15, "CLASSIQUE")
	local esquive = settled(r15, "ESQUIVE")
	expect(classic.Root[4] > esquive.Root[4] + 0.1, "the classic guard is not more upright than the peek-a-boo")
	expect(classic.LeftElbow[1] < esquive.LeftElbow[1] - 30, "the classic lead arm is not out")
	for _, stance in { "CLASSIQUE", "ESQUIVE" } do
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

T.finish()
