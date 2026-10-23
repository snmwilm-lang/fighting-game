--[[
	FATAL FINISHERS (Wilhem, 0.27.0: « une animation comme les Legendary Finish de DBL quand
	le fatal tue, une anime spéciale plus longue »). When the COUP FATAL kills (the simulation
	knows it from the start: CombatSimulation startCinematic), the kit's finisher replaces its
	short fatal scene: 7 to 12 seconds directed like an anime sequence, which is the K.O.
	itself. Pure (no Roblox API, no require): CinematicDirector hands its tools over
	(Director.useFinishers), the scenes only stage views, shots and requests:

	  frame.shapes   3D light drawn every frame by the client (CinematicController:drawShapes),
	                 points may be rig parts (resolved after the rigs are placed):
	                   { kind = "sphere", pos, radius, color, core }    a ball of energy
	                   { kind = "beam", from, to, radius, color, rings } a ray, rings travelling
	                   { kind = "ring", pos, normal, radius, width, color, alpha }
	                   { kind = "motes", pos, radius, count, color, phase, out } sucked in / blown out
	                   { kind = "slash", from, to, width, color, alpha } a streak of a blade
	                   { kind = "dome", pos, radius, color, alpha }     an explosion's shell
	                 (a shape may carry `mark`, a handle the tests follow it by; the client ignores it)
	  frame.overlay  full-screen direction:
	                   desat 0..1 (the colour drains), blur 0..1 (a directional blur pulse),
	                   firstPerson = slot (that fighter's head and arms are hidden: the camera is its eyes),
	                   split = { angle, line 0..1, open 0..1, join 0..1, color, letters, letterAt,
	                   letterSize, views, only } (SHIN: the screen cut in two halves along a line
	                   turned `angle` degrees clockwise, the first half on its left-hand side;
	                   K in one, O in the other, each half its own shot of its own fighter), ko = { text, sub, color, at } (the K.O. written into the scene),
	                   caption = { text, color, stroke, age, fade } (a count slammed in at the side:
                   RYUKEN's ten fists of rage)
	  view.hidden    the fighter is not drawn (SHIN between his cuts)
	  fx "sfx"       { sound = "whoosh" | "slash" | "heavy" | "boom" | "charge" | "beam" }

	Timing (ticks at 60 per second; a finisher runs at full speed, its slow motion is staged):
	MoveData's kits carry Finisher = { Length, FinalTick, Name } (FinalTick: the blow that kills).
]]
local Finishers = {}

-- A staged x kept inside the arena (the scenes stand far apart).
local function inside(ctx, x)
	return math.clamp(x, ctx.config.ArenaMinX + 1, ctx.config.ArenaMaxX - 1)
end

-- The centre of a scene (the target's x) that needs `back` studs of deck on the attacker's
-- side of it and `ahead` studs beyond it: near a wall the whole scene stands back from it, as
-- it plays in the middle of the arena (a fighter pinned by `inside` alone ends up too close to
-- the other, and a close-up hung on him in the other's body: B-011).
local function room(ctx, cx, dir, back, ahead)
	local lo, hi = ctx.config.ArenaMinX + 1, ctx.config.ArenaMaxX - 1
	if dir > 0 then return math.clamp(cx, lo + back, hi - ahead) end
	return math.clamp(cx, lo + ahead, hi - back)
end

function Finishers.build(T)
	local v, P, At, shot, frameOn = T.v, T.P, T.At, T.shot, T.frameOn
	local lerp, progress, smooth, attack = T.lerp, T.progress, T.smooth, T.attack
	local S = {}

	local function sfx(frame, key, sound)
		table.insert(frame.fx, { key = key, kind = "sfx", sound = sound })
	end
	local function shape(frame, s)
		frame.shapes = frame.shapes or {}
		table.insert(frame.shapes, s)
	end
	-- DAICHA's matter (CinematicController:drawMatter): a ball, a disc, a pool, a wave
	local function matter(frame, kind, pos, r, color, normal, h)
		frame.matter = frame.matter or {}
		table.insert(frame.matter, { shape = kind, pos = pos, radius = math.max(0.02, r), color = color, normal = normal, height = h })
	end
	local function overlay(frame)
		frame.overlay = frame.overlay or {}
		return frame.overlay
	end
	-- the K.O. written into the scene (no plain HUD title): big, slammed in, the finisher's name under it
	-- (card: { bg, splash } the whole screen one colour behind the letters, Wilhem's storyboards)
	local function ko(ctx, frame, tick, at, color, card)
		if tick < at then return end
		local kit = ctx.moveData.Kits[ctx.cin.kit or ""]
		local name = kit and kit.Finisher and kit.Finisher.Name or "FATAL FINISH"
		overlay(frame).ko = { text = "K.O.", sub = name, color = color, at = at, age = tick - at, card = card }
	end

	-- Places a view on a circle round (cx, 0), on both sides of the line, facing the centre.
	local function circle(view, cx, dir, angle, radius, y)
		view.x = cx - dir * math.cos(angle) * radius
		view.z = -math.sin(angle) * radius
		view.y = y or 0
		local lx, lz = cx - view.x, -view.z
		local l = math.max(1e-3, math.sqrt(lx * lx + lz * lz))
		view.lookDir, view.facing = v(lx / l, 0, lz / l), if lx >= 0 then 1 else -1
	end

	-- The target's own move for a role (its kit's), for the scenes where it strikes back.
	local function theirMove(ctx, d, r)
		local moves = ctx.moveData.Moves
		local own = ctx.moveData.Kits[d.kit or "KAI"] or ctx.moveData.Kits.KAI
		local id = own and own.Roles and own.Roles[r] or r
		return if moves[id] then id else r
	end

	-- ================================================================ SHIN · FINAL DIVISION
	-- Wilhem's storyboard: twelve shots of a second, at night.
	-- 0:00 he fixes his target, the camera closes in slowly · 0:01 his eye; a short silence ·
	-- 0:02 he is gone: one trail of speed · 0:03 a few simple, fast cuts round the target ·
	-- 0:04 he is back, behind it: a clean shot · 0:05 the last cut, the camera follows the blade
	-- · 0:06 the screen splits: K on the left, him · 0:07 O on the right, the target · 0:08 both
	-- halves take the blow, the line along the cut · 0:09 the halves join: K.O. · 0:10 it
	-- falls, he stands · 0:11 the last look at him; back to the game.
	local SHIN_NIGHT = "2B3F8F"
	local SHIN_BLUE = "8FD0FF"
	function S.SHIN(ctx, frame, a, d, tick, dir)
		local A, D = ctx.cin.attacker, ctx.cin.defender
		local moves = ctx.moveData.Moves
		-- (his iai stands 5.8 in front of the target, he comes back 3.6 behind it: near a wall the
		-- whole scene stands back from it, never him alone)
		local cx = room(ctx, T.center(ctx, d), dir, 5.8, 3.6)
		local F = 330
		-- (the cut on the screen follows the blade: down from the high side; K's half on the left)
		local ANGLE = if dir > 0 then 62 else 118
		local low = if dir > 0 then 1 else -1 -- (K low on the left when the cut runs down to the right)
		local o = overlay(frame)
		o.tint = { color = SHIN_NIGHT, amount = smooth(progress(tick, 0, 40)) * (1 - smooth(progress(tick, 690, 720))) }
		local front = inside(ctx, cx - dir * 5.8) -- (where he stands first: his iai leans in a long way)
		local behind = inside(ctx, cx + dir * 3.6) -- (where he comes back)
		-- (a shot for one half of the split screen)
		local function half(s_)
			return { from = s_.from, to = s_.to, fov = s_.fov, roll = s_.roll }
		end
		-- his eye, lit
		local function eye(size)
			shape(frame, { kind = "sphere", pos = P(A, "Head", v(a.facing * 0.5, 0.12, 0.24)), radius = size, color = SHIN_BLUE, core = 1 })
		end
		d.x = cx
		if tick < 60 then
			-- he fixes his target; the camera closes in slowly
			a.x, a.facing, a.pose = front, dir, "Iai"
			d.facing, d.state = -dir, "Idle"
			local q = smooth(progress(tick, 0, 60))
			-- (from his front, the target out of the frame behind the camera's shoulder)
			frame.shot = shot("shin-fd-face", P(A, "Head", v(dir * lerp(3.2, 2.2, q), lerp(0.2, 0.1, q), lerp(6.4, 4.4, q))), P(A, "Head", v(dir * 0.3, -0.6, 0)),
				26, 0, P(A, "Head"))
			frame.shot.close = true
			if tick >= 30 then eye(0.05) end
		elseif tick < 120 then
			-- his eye; a short silence
			a.x, a.facing, a.pose = front, dir, "Iai"
			d.facing, d.state = -dir, "Idle"
			local q = smooth(progress(tick, 60, 120))
			eye(lerp(0.06, 0.09, q))
			frame.shot = shot("shin-fd-eye", P(A, "Head", v(dir * lerp(2.4, 1.85, q), 0.12, lerp(2.4, 1.85, q))), P(A, "Head", v(dir * 0.3, 0.1, 0.1)),
				lerp(30, 28, q), 0, P(A, "Head"))
			frame.shot.close = true
			if tick == 112 then sfx(frame, "fd-ready", "slash") end
			-- (the glint: a thin line of light across the eye, the instant before he goes)
			local glint = progress(tick, 100, 108) * (1 - progress(tick, 110, 119))
			if glint > 0 then
				shape(frame, { kind = "slash", from = P(A, "Head", v(a.facing * 0.5 - 0.9 * glint, 0.12, 0.26)), to = P(A, "Head", v(a.facing * 0.5 + 0.9 * glint, 0.12, 0.26)),
					width = 0.035, color = "FFFFFF", alpha = 0.1 })
			end
		elseif tick < 180 then
			-- he is gone: one trail of speed past the target (seen from behind it)
			a.x, a.facing, a.pose = front, dir, "Iai"
			a.hidden = tick >= 132
			d.facing, d.state = -dir, "Idle"
			if tick == 132 then
				sfx(frame, "fd-vanish", "whoosh")
				table.insert(frame.fx, { key = "fd-ghost", kind = "afterimage", slot = A, color = SHIN_BLUE, life = 0.3 })
			end
			local q = progress(tick, 132, 150)
			local fade = progress(tick, 150, 176)
			if q > 0 and fade < 1 then
				shape(frame, { kind = "slash", from = At(v(front, 3.1, 0.6)), to = At(v(lerp(front, behind + dir * 3, q), 3.4, lerp(0.6, -1.4, q))),
					width = 0.5 * (1 - fade), color = SHIN_BLUE, alpha = fade })
			end
			frame.shot = frameOn("shin-fd-gone", dir, { d, { point = true, x = front, y = 3, z = 0 } }, { yaw = 118, pitch = 2, fill = 0.62, fov = 40,
				focus = P(D, "UpperTorso") })
		elseif tick < 240 then
			-- a few simple, fast cuts round the target: arcs of the blade
			a.hidden = true
			d.facing, d.state = -dir, "Hitstun"
			for i, t in { 184, 198, 212, 226 } do
				local age = tick - t
				if age >= 0 and age < 20 then
					local sweep = smooth(math.min(1, age / 6))
					local fade = progress(tick, t + 6, t + 20)
					local tilt = (i - 2.5) * 0.45
					local s0 = i * 1.9
					local function onArc(u)
						local ang = s0 + u * 3.6 * sweep
						return At(v(cx + math.cos(ang) * 2.7, 3.3 + math.sin(ang) * 2.7 * tilt, math.sin(ang) * 2))
					end
					for k = 0, 9 do
						shape(frame, { kind = "slash", from = onArc(k / 10), to = onArc((k + 1) / 10), width = 0.24, color = if i % 2 == 0 then "FFFFFF" else SHIN_BLUE,
							alpha = fade })
					end
					if age == 0 then sfx(frame, "fd-arc" .. i, "slash") end
					if age < 4 then
						-- (he shows for a blink, mid-cut)
						a.hidden = false
						circle(a, cx, dir, s0 + math.pi, 2.6, 0)
						attack(a, moves, T.role(ctx, if i % 2 == 0 then "Cross" else "Jab"), true)
					end
					if age >= 2 and age < 10 then d.pose = if i % 2 == 0 then "HitBody" else "HitHigh" end
				end
			end
			frame.shot = frameOn("shin-fd-arcs", dir, { d }, { yaw = 118, pitch = 8, fill = 0.5, fov = 40, focus = P(D, "UpperTorso") })
		elseif tick < 300 then
			-- he is back, behind it; it turns round to him: a clean shot over its shoulder
			a.hidden = false
			a.x, a.z, a.lookDir, a.facing, a.pose = behind, nil, nil, -dir, "Iai"
			d.facing, d.state = dir, "Idle"
			if tick == 240 then sfx(frame, "fd-back", "whoosh") end
			frame.shot = frameOn("shin-fd-back", dir, { a, d }, { yaw = -66, pitch = 4, fill = 0.78, fov = 36, focus = P(A, "Head") })
		elseif tick < 360 then
			-- the last cut; the camera follows the blade
			a.x, a.z, a.facing = behind, nil, -dir
			d.facing = dir
			attack(a, moves, T.role(ctx, "Finale"), tick >= F - 4)
			d.state, d.pose = "Hitstun", if tick >= F then "HitHigh" else nil
			d.hitstop = if tick >= F then 1 else 0
			if tick == F then
				sfx(frame, "fd-cut", "slash")
				frame.impact = { key = "fd-cut", color = "FFFFFF" }
			end
			if tick >= F then
				local k = progress(tick, F, F + 6)
				local fade = progress(tick, F + 10, 360)
				shape(frame, { kind = "slash", from = At(v(cx - dir * 2.6, 5.4, 0.8)), to = At(v(cx + dir * lerp(-2.6, 2.6, k), lerp(5.4, 1.2, k), 0.8)),
					width = 0.3, color = "FFFFFF", alpha = fade })
				o.split = { angle = ANGLE, line = smooth(progress(tick, F + 2, F + 16)), open = 0, join = 0, color = SHIN_BLUE }
			end
			-- (the camera swings round with the blade)
			local swing = smooth(progress(tick, F - 10, F + 8))
			frame.shot = frameOn("shin-fd-blade", dir, { a, d }, { yaw = lerp(-20, 40, swing), pitch = -8, fill = 0.74, fov = 38, roll = lerp(-4, 8, swing),
				focus = P(A, "UpperTorso") })
		elseif tick < 556 then
			-- the screen splits: K and him on the left, O and the target on the right; he sheathes,
			-- the click: both halves take the blow; then the halves join
			a.x, a.z, a.facing = behind, nil, -dir
			a.pose = if tick < 466 then "ShinDivision" else "Sheathe"
			d.facing, d.state = dir, "Hitstun"
			d.pose = if tick < 480 then "HitHigh" else "HitBody"
			d.hitstop = if tick < 480 then 1 else 0
			if tick == 480 then
				sfx(frame, "fd-blow", "heavy")
				T.spark(frame, "fd-blow", v(cx, 3.6, 0.6), SHIN_BLUE, 1.4)
				table.insert(frame.fx, { key = "fd-shards", kind = "debris", pos = v(cx, 3, 0.4), color = SHIN_BLUE, scale = 1 })
			end
			if tick >= 540 then
				T.FATAL.fall(ctx.cin, d, tick, 540, 0)
				if d.pose == "Kneel" then d.pose = "DownFace" end
			end
			local open = smooth(progress(tick, 360, 384)) * (1 - smooth(progress(tick, 540, 552)))
			-- (each half its own shot: him in the left one, the target in the right one, each face
			-- clear of its letter)
			o.split = { angle = ANGLE, line = 1, open = open, join = smooth(progress(tick, 540, 552)), color = SHIN_BLUE,
				letters = { "K", if tick >= 420 then "O" else "" }, only = { A, D },
				letterAt = { { 0.12, 0.5 + 0.2 * low }, { 0.88, 0.5 - 0.2 * low } }, letterSize = 0.3,
				views = { half(frameOn("shin-fd-k", dir, { a }, { yaw = -34, pitch = -4, band = "bust", fill = 0.55, fov = 34,
						screen = { -0.44, 0.06 * low }, focus = P(A, "Head") })),
					half(frameOn("shin-fd-o", dir, { d }, { yaw = 34, pitch = 2, band = "bust", fill = 0.55, fov = 34,
						screen = { 0.44, -0.06 * low }, focus = P(D, "Head") })) } }
			frame.shot = frameOn("shin-fd-split", dir, { a, d }, { yaw = 30, pitch = 3, fill = 0.7, fov = 34, focus = P(D, "UpperTorso") })
		elseif tick < 600 then
			-- K.O.: the card, black, a red splash
			a.x, a.z, a.facing, a.pose = behind, nil, -dir, "ShinDivision"
			T.FATAL.fall(ctx.cin, d, tick, 540, 0)
			if d.pose == "Kneel" then d.pose = "DownFace" end
			if tick == 556 then sfx(frame, "fd-ko", "boom") end
			ko(ctx, frame, tick, 556, SHIN_BLUE, { bg = "07080C", splash = "C8102E" })
			frame.shot = frameOn("shin-fd-ko", dir, { a, d }, { yaw = 30, pitch = 3, fill = 0.7, fov = 34, focus = P(D, "UpperTorso") })
		elseif tick < 660 then
			-- it lies there; he stands, the blade low, at night
			T.FATAL.fall(ctx.cin, d, tick, 540, 0)
			if d.pose == "Kneel" then d.pose = "DownFace" end
			a.x, a.z, a.facing = behind, nil, dir
			a.pose = if tick < 640 then "ShinDivision" else "Sheathe"
			frame.shot = frameOn("shin-fd-stand", dir, { a, d }, { yaw = 40, pitch = 6, fill = 0.72, fov = 36, focus = P(A, "UpperTorso") })
		else
			-- the last look at him, over his shoulder; back to the game
			T.FATAL.fall(ctx.cin, d, tick, 540, 0)
			if d.pose == "Kneel" then d.pose = "DownFace" end
			a.x, a.z, a.facing, a.pose = behind, nil, dir, "Sheathe"
			a.lookDir = v(dir, 0, 0.35)
			eye(0.07)
			local q = smooth(progress(tick, 660, 720))
			frame.shot = frameOn("shin-fd-last", dir, { a }, { yaw = lerp(46, 34, q), pitch = -6, band = "bust", fill = lerp(0.62, 0.74, q), fov = 30,
				focus = P(A, "Head") })
		end
	end

	-- ================================================================ TARO · DEMPSEY ROLL: FINAL ROUND
	-- Wilhem's storyboard: twelve shots of a second.
	-- 0:00 he drops his guard, the Dempsey Roll starts · 0:01 the body swings left, right,
	-- faster · 0:02 first person (the target's eyes): the first hook · 0:03 the hooks chain, the
	-- camera jolts with each · 0:04 the rhythm rises, left, right · 0:05 faster: the sight blurs ·
	-- 0:06 the last hooks, it is overwhelmed · 0:07 the last move: the uppercut · 0:08 it flies,
	-- the camera follows it up from behind him, low · 0:09 it crashes on the deck: debris, dust ·
	-- 0:10 K.O. (black, a red splash) · 0:11 his guard comes back up; back to the game.
	function S.TARO(ctx, frame, a, d, tick, dir)
		local A, D = ctx.cin.attacker, ctx.cin.defender
		local moves = ctx.moveData.Moves
		local color = ctx.characters[A].Energy
		local cx = T.center(ctx, d)
		local F = 446
		local o = overlay(frame)
		frame.grade.fire = true
		d.facing = -dir
		-- the hooks: one, then a chain faster and faster
		local hooks = { 150 }
		local h = 180
		while h < 416 do
			table.insert(hooks, h)
			h += if h < 240 then 16 elseif h < 300 then 11 elseif h < 360 then 8 else 6
		end
		local last, index = nil, 0
		for i, t in hooks do
			if t <= tick then last, index = t, i end
		end
		local start = inside(ctx, cx - dir * 5.2) -- (where he stands first: the roll carries him in)
		local close_ = cx - dir * 3.4
		local hit = inside(ctx, cx + dir * 2.2) -- (where the hooks have driven it)
		local land = inside(ctx, hit + dir * 3.4) -- (where it comes down)
		-- its height in the air: up, a beat at the top, down hard
		local function air(t)
			if t < 458 then return 0 end
			if t < 520 then return 8.5 * math.sin(progress(t, 458, 520) * math.pi / 2) end
			if t < 538 then return 8.5 end
			if t < 552 then
				local q = progress(t, 538, 552)
				return 8.5 * (1 - q * q)
			end
			return if t < 566 then 0.8 * math.sin(progress(t, 552, 566) * math.pi) else 0 -- (one bounce)
		end
		if tick < 120 then
			-- he drops his guard; the figure eight starts, faster and faster
			local p = progress(tick, 0, 120)
			d.x, d.state = cx, "Idle"
			if tick < 36 then
				a.x, a.facing, a.state, a.pose = start, dir, "Idle", "GloveTap"
			else
				local phase = ((tick - 36) / 60) * lerp(2.5, 7, progress(tick, 36, 120)) * math.pi
				a.x, a.facing = lerp(start, close_, smooth(progress(tick, 36, 116))) - dir * 0.15 * math.sin(phase), dir
				a.state, a.move, a.weave, a.vx = "Dashing", nil, true, dir * 2 * math.sin(phase)
			end
			if tick > 70 and tick % 12 == 0 then
				table.insert(frame.fx, { key = "dr-ghost" .. tick, kind = "afterimage", slot = A, color = color, life = 0.3 })
			end
			if tick > 84 then frame.speedLines = color end
			if tick < 60 then
				-- (close on him, the target out of the frame on the camera's side)
				local q = smooth(progress(tick, 0, 60))
				frame.shot = shot("taro-dr-guard", At(v(start + dir * lerp(3.0, 2.6, q), 4.6, lerp(6.4, 5.2, q))), At(v(start + dir * 0.4, 3.9, 0)),
					lerp(34, 32, q), 0, P(A, "Head"))
			else
				frame.shot = frameOn("taro-dr-weave", dir, { a, d }, { yaw = lerp(6, 14, p), pitch = -16, fill = lerp(0.8, 0.92, p), fov = lerp(38, 32, p),
					focus = P(A, "UpperTorso") })
			end
		elseif tick < 420 then
			-- through the target's eyes: the first hook, then the chain; it gives ground
			local back = smooth(progress(tick, 180, 420)) * 2.2
			d.x, d.state = inside(ctx, cx + dir * back), "Hitstun"
			-- (the glove stops short of the eyes; 3.5: from the right his hooking arm passes the
			-- lens on its other side, 3.4 put it within 0.25 of it: B-010)
			a.x, a.facing = d.x - dir * 3.5, dir
			local side = if index % 2 == 1 then 1 else -1
			local age = if last then tick - last else 99
			if last and age < 7 then
				attack(a, moves, if side > 0 then "TaroDempseyL" else "TaroDempseyR", true)
			else
				a.state, a.move, a.weave, a.vx = "Dashing", nil, true, dir * side * 2
			end
			if last and age == 0 then
				sfx(frame, "dr-hook" .. index, "heavy")
				T.spark(frame, "dr-spark" .. index, v(d.x - dir * 0.6, 4.4, 0), if index % 3 == 0 then "FFFFFF" else color, 0.9)
			end
			d.pose = if age < 6 then (if side > 0 then "HitHigh" else "HitBody") else nil
			-- (each blow jolts the camera; as they pile up the sight blurs, drains, reddens, sways)
			local jolt = if age < 12 then math.exp(-age / 4) else 0
			local daze = progress(tick, 300, 420)
			o.firstPerson = D
			o.blur = math.max(jolt * 0.9, daze * 0.55)
			o.desat = 0.5 * progress(tick, 360, 420)
			o.tint = { color = "8A1010", amount = 0.4 * daze }
			local sway = side * 0.3 * jolt + 0.1 * daze * math.sin(tick / 9)
			local from = P(D, "Head", v(-dir * (0.55 - 0.3 * jolt), 0.15 + 0.1 * jolt + 0.2 * daze, sway))
			frame.shot = shot("taro-dr-eyes", from, P(A, "UpperTorso", v(0, 0.5, 0)), lerp(72, 84, smooth(progress(tick, 180, 420))),
				math.rad(-side * 14 * jolt + 6 * daze * math.sin(tick / 13)), P(A, "Head"))
		elseif tick < 540 then
			-- the last move: he sinks, the uppercut; a white blow, the frame holds a beat, the body
			-- leaves the deck; then from behind him, low, the camera follows it up
			a.x, a.facing = hit - dir * 2.9, dir
			attack(a, moves, T.role(ctx, "Uppercut"), tick >= F - 3)
			d.x = lerp(hit, land, smooth(progress(tick, 458, 552)))
			d.y = air(tick)
			if tick < F then
				d.state, d.pose = "Hitstun", "HitBody" -- (overwhelmed, it sags)
				o.desat = 0.25
				if tick == 420 then sfx(frame, "dr-cock", "charge") end
				frame.shot = frameOn("taro-dr-coil", dir, { a, d }, { yaw = -30, pitch = -18, fill = 0.82, fov = 34, focus = P(A, "UpperTorso") })
			else
				if tick == F then
					sfx(frame, "dr-upper", "boom")
					T.impact(frame, "dr-upper", v(hit - dir * 0.4, 4.4, 0.6), color, 3)
				end
				o.white = 0.85 * (1 - progress(tick, F, F + 10))
				if tick < 458 then
					d.state, d.pose, d.hitstop = "Hitstun", "HitHigh", 1
				else
					d.state, d.pose, d.hitstop = "Launched", "Launched", 0
				end
				if tick < 480 then
					frame.shot = frameOn("taro-dr-upper", dir, { a, d }, { yaw = 22, pitch = -22, fill = 0.62, fov = 40,
						roll = lerp(0, -6, progress(tick, F, 480)), focus = P(D, "UpperTorso") })
				else
					frame.shot = shot("taro-dr-follow", At(v(a.x - dir * 6.5, 0.9, 5)), P(D, "UpperTorso"), 36, math.rad(dir * 6), P(D, "UpperTorso"))
				end
			end
		elseif tick < 600 then
			-- it comes down hard: the camera closes on the place it lands; debris, dust
			a.x, a.facing = hit - dir * 2.9, dir
			a.state, a.move = "Idle", nil
			d.x, d.y = land, air(tick)
			if tick < 552 then
				d.state, d.pose = "Launched", "Launched"
			else
				d.state, d.pose = "Knockdown", "DownFace"
			end
			if tick == 552 then
				sfx(frame, "dr-crash", "boom")
				T.impact(frame, "dr-crash", v(land, 0.4, 0.4), color, 2.2)
				table.insert(frame.fx, { key = "dr-debris", kind = "debris", pos = v(land, 0.4, 0.4), color = "8A7A66", scale = 1.6 })
				table.insert(frame.fx, { key = "dr-dust", kind = "dust", pos = v(land, 0, 0), direction = dir })
				table.insert(frame.fx, { key = "dr-rocks", kind = "rocks", pos = v(land, 0, 0.4), radius = 2.2, count = 8, color = "6A5E50" })
			end
			if tick >= 552 and tick < 566 then frame.quake = 0.6 * (1 - progress(tick, 552, 566)) end
			frame.shot = frameOn("taro-dr-crash", dir, { d, { point = true, x = land, y = 0.3, z = 0 } }, { yaw = 18, pitch = 6, fill = 0.6, fov = 40,
				focus = P(D, "UpperTorso") })
		elseif tick < 660 then
			-- K.O.: the card, black, a red splash
			a.x, a.facing, a.state = hit - dir * 2.9, dir, "Idle"
			d.x, d.y, d.state, d.pose = land, 0, "Knockdown", "DownFace"
			if tick == 600 then sfx(frame, "dr-ko", "boom") end
			ko(ctx, frame, tick, 600, color, { bg = "0B0B0E", splash = "C8102E" })
			frame.shot = frameOn("taro-dr-ko", dir, { a, d }, { yaw = 18, pitch = 6, fill = 0.7, fov = 40, focus = P(D, "UpperTorso") })
		else
			-- his guard comes back up; back to the game
			local q = smooth(progress(tick, 660, 720))
			a.x, a.facing, a.state = hit - dir * 2.9, dir, "Idle"
			a.pose = if tick < 690 then "GloveTap" else nil
			d.x, d.y, d.state, d.pose = land, 0, "Knockdown", "DownFace"
			frame.shot = frameOn("taro-dr-guardup", dir, { a }, { yaw = lerp(40, 30, q), pitch = -6, band = "bust", fill = 0.72, fov = 30,
				focus = P(A, "Head") })
		end
	end

	-- ================================================================ KAI · MAXIMUM KAIENHA
	-- Wilhem's storyboard: twelve shots of a second.
	-- 0:00 his stance: the energy gathers between his hands · 0:01 it thickens, the camera turns
	-- round him · 0:02 the aura bursts out, the deck cracks · 0:03 his face: the last focus ·
	-- 0:04 the push: the wave bursts out · 0:05 the camera runs along the wave across the arena ·
	-- 0:06 from the side: the target swallowed · 0:07 close on it: the energy wraps it · 0:08 the
	-- explosion, the screen fills with light · 0:09 the light thins out, the shock ring runs on ·
	-- 0:10 K.O. on a card of blue light · 0:11 he stands, seen from behind, the smoke ahead.
	function S.KAI(ctx, frame, a, d, tick, dir)
		local A, D = ctx.cin.attacker, ctx.cin.defender
		local color = ctx.characters[A].Energy
		local cx = T.center(ctx, d)
		local F = 485
		local o = overlay(frame)
		-- (the wave needs room: near a wall the whole scene stands back from it)
		local cfg = ctx.config
		local ax = if dir > 0 then math.min(cx - 3.2, cfg.ArenaMaxX - 1 - 18) else math.max(cx + 3.2, cfg.ArenaMinX + 1 + 18)
		ax = inside(ctx, ax)
		local base = inside(ctx, ax + dir * 7)
		local far = inside(ctx, ax + dir * 16)
		local hands = P(A, "RightHand", v(0, 0, 0))
		hands.mid = "LeftHand"
		a.x, a.facing = ax, dir
		d.facing = -dir
		-- the ball of ki in his cupped palms (KiBall's look): a real, steady growth from a spark to
		-- a sun through the whole charge; it stays in his palms, feeding the wave, while he fires
		local orb = 0
		if tick < 248 then
			orb = (0.06 + 1.16 * progress(tick, 0, 246) ^ 1.35) * (1 + 0.05 * math.sin(tick * 0.9))
		elseif tick < 540 then
			orb = 0.85 * (1 + 0.06 * math.sin(tick * 1.3))
		end
		-- (a point by the ball: its centre between his hands, moved by `dx, dy, dz`)
		local function nearHands(dx, dy, dz)
			local p_ = P(A, "RightHand", v(dx, dy, dz))
			p_.mid = "LeftHand"
			return p_
		end
		-- the charge crackles (Wilhem's reference): streaks of light out of the ball, turning and
		-- flickering, and small arcs onto it
		if tick >= 20 and tick < 248 then
			local streaks = if tick < 120 then 4 else 7
			for k = 1, streaks do
				local an = k / streaks * math.pi * 2 + tick * 0.12
				local flick = 0.5 + 0.5 * math.sin(tick * 1.9 + k * 2.3)
				local from, length = orb * 1.15, (0.5 + 1.8 * orb) * (0.4 + 0.6 * flick)
				shape(frame, { kind = "slash", from = nearHands(math.cos(an) * from, math.sin(an) * from, 0.2),
					to = nearHands(math.cos(an) * (from + length), math.sin(an) * (from + length), 0.2), width = 0.05 + 0.04 * orb,
					color = if k % 2 == 0 then "FFFFFF" else color, alpha = 0.55 - 0.4 * flick })
			end
			if tick % 7 == 0 then
				local bx = ax - dir * 0.6
				table.insert(frame.fx, { key = "kx-crackle" .. tick, kind = "lightning",
					from = v(bx + math.cos(tick * 2.3) * (1 + orb * 1.4), 2.6 + math.sin(tick * 1.7) * (0.8 + orb), 0.4 + math.sin(tick) * 0.8),
					to = v(bx, 2.6, 0.4), color = if tick % 14 == 0 then "FFFFFF" else color })
			end
		end
		-- the wave's head: out of his hands at 248, it meets the target at 262 and carries it across
		local function head(t)
			if t < 262 then return lerp(ax + dir, base, progress(t, 248, 262)) end
			return lerp(base, far, smooth(progress(t, 262, 350)))
		end
		local function beam(tip, radius, tone)
			shape(frame, { kind = "beam", from = hands, to = At(v(tip, 3.1, 0)), radius = radius, color = tone or color, rings = tick / 30 })
		end
		if tick < 60 then
			-- his stance: the energy gathers between his hands
			local p = progress(tick, 0, 60)
			a.pose = "KaiCharge"
			d.x, d.state = base, "Idle"
			shape(frame, { kind = "motes", pos = hands, radius = 4, count = 22, color = color, phase = tick / 60 })
			if tick == 0 then sfx(frame, "kx-charge", "charge") end
			if tick < 40 then
				-- (close on his cupped palms: the spark of ki is born between them)
				local q = smooth(progress(tick, 0, 40))
				frame.shot = shot("kai-mx-palms", nearHands(dir * lerp(1.9, 2.3, q), lerp(0.7, 0.9, q), lerp(2.6, 3.2, q)), nearHands(0, 0.2, 0), 34,
					math.rad(-dir * 6), hands)
				frame.shot.close = true
			else
				frame.shot = frameOn("kai-mx-stance", dir, { a }, { yaw = 20, pitch = -10, fill = lerp(0.55, 0.68, p), fov = 36, focus = P(A, "UpperTorso") })
			end
		elseif tick < 120 then
			-- it thickens; the camera turns round him, to his back
			local p = progress(tick, 60, 120)
			a.pose = "KaiCharge"
			d.x, d.state, d.pose = base, "Blockstun", "VicBrace" -- (it braces against the pressure)
			shape(frame, { kind = "motes", pos = hands, radius = 6, count = 30, color = color, phase = tick / 45 })
			if tick % 20 == 0 then
				table.insert(frame.fx, { key = "kx-arc" .. tick, kind = "lightning", from = v(ax + math.cos(tick * 1.7) * 4, 1 + (tick % 3), math.sin(tick * 1.7) * 3),
					to = v(ax, 2.6, 0), color = color })
			end
			frame.shot = frameOn("kai-mx-orbit", dir, { a }, { yaw = lerp(20, -120, smooth(p)), pitch = -8, fill = 0.66, fov = 40, focus = P(A, "UpperTorso") })
		elseif tick < 180 then
			-- the aura bursts out: rings run on the deck, it cracks, stones rise
			local p = progress(tick, 120, 180)
			a.pose = "KaiChargeStrain"
			d.x, d.state, d.pose = base, "Blockstun", "VicBrace"
			frame.grade.void = true
			if tick == 120 then
				sfx(frame, "kx-aura", "boom")
				frame.impact = { key = "kx-aura", color = color }
				table.insert(frame.fx, { key = "kx-rocks", kind = "rocks", pos = v(ax, 0, 0), radius = 3.2, count = 10, color = "5A5F70" })
				table.insert(frame.fx, { key = "kx-debris", kind = "debris", pos = v(ax, 0.3, 0), color = color, scale = 1.4 })
			end
			if tick % 10 == 0 then
				table.insert(frame.fx, { key = "kx-crack" .. tick, kind = "crack", from = v(ax, 0.05, 0),
					to = v(ax + math.cos(tick) * 5, 0.05, math.sin(tick) * 3), color = color })
			end
			for i, at in { 120, 136, 152, 168 } do
				local q = progress(tick, at, at + 40)
				if q > 0 and q < 1 then
					shape(frame, { kind = "ring", pos = At(v(ax, 0.1, 0)), normal = v(0, 1, 0), radius = lerp(1.2, 7, smooth(q)), width = 0.35,
						color = if i % 2 == 0 then "FFFFFF" else color, alpha = q })
				end
			end
			shape(frame, { kind = "dome", pos = At(v(ax, 0, 0)), radius = lerp(1.5, 3.2, smooth(progress(tick, 120, 140))), color = color, alpha = 0.55 })
			shape(frame, { kind = "motes", pos = At(v(ax, 2.5, 0)), radius = 5, count = 30, color = color, phase = tick / 40, out = true })
			frame.quake = 0.25 * (1 - p)
			frame.shot = frameOn("kai-mx-aura", dir, { a }, { yaw = 22, pitch = -14, fill = 0.45, fov = 44, focus = P(A, "UpperTorso") })
		elseif tick < 240 then
			-- his face: the last focus
			a.pose = "KaiChargeStrain"
			d.x, d.state, d.pose = base, "Blockstun", "VicBrace"
			frame.grade.void = true
			shape(frame, { kind = "motes", pos = hands, radius = 5, count = 26, color = color, phase = tick / 30 })
			local q = smooth(progress(tick, 180, 240))
			frame.shot = shot("kai-mx-face", P(A, "Head", v(dir * lerp(3.4, 2.6, q), lerp(0.3, 0.2, q), lerp(4.2, 3.3, q))), P(A, "Head", v(0, -0.3, 0)),
				lerp(34, 30, q), math.rad(dir * 4), P(A, "Head"))
			frame.shot.close = true
		elseif tick < 300 then
			-- the push: the wave bursts out of his hands and takes the target
			local tip = head(tick)
			a.pose = if tick < 248 then "KaiChargeStrain" else "KaiFire"
			if tick < 262 then
				d.x, d.state, d.pose = base, "Blockstun", "VicBrace"
			else
				d.x, d.y, d.state, d.pose = tip, 1.2 * smooth(progress(tick, 262, 280)), "Launched", "Launched"
			end
			if tick >= 248 then
				beam(tip + dir * 0.5, lerp(0.6, 2.4, smooth(progress(tick, 248, 262))))
				for i = 0, 2 do
					local age = (tick - 248 - i * 8) / 30
					if age >= 0 and age < 1 then
						shape(frame, { kind = "ring", pos = At(v(ax + dir * (1.4 + age * 2), 3.1, 0)), normal = v(dir, 0, 0), radius = 2 + age * 6,
							width = 0.3, color = "FFFFFF", alpha = age })
					end
				end
			end
			if tick == 248 then
				sfx(frame, "kx-fire", "beam")
				frame.impact = { key = "kx-fire", color = "FFFFFF" }
			end
			if tick == 262 then
				sfx(frame, "kx-take", "heavy")
				T.spark(frame, "kx-take", v(base, 3.4, 0.4), "FFFFFF", 1.6)
			end
			frame.shot = frameOn("kai-mx-fire", dir, { a }, { yaw = 48, pitch = -10, fill = 0.6, fov = 44, focus = P(A, "UpperTorso") })
		elseif tick < 360 then
			-- the camera runs along the wave, the target on its head, across the arena
			local tip = head(tick)
			a.pose = "KaiFire"
			d.x, d.y, d.state, d.pose = tip, 1.2 + 0.3 * math.sin(tick / 5), "Launched", "Launched"
			beam(tip + dir * 0.5, 2.4 + 0.25 * math.sin(tick / 3))
			-- (a little ahead of it, looking back down the wave that drives it)
			frame.shot = frameOn("kai-mx-track", dir, { d }, { yaw = 50, pitch = 6, fill = 0.36, fov = 44, roll = -3, lift = 1.8, focus = P(D, "UpperTorso") })
		elseif tick < 420 then
			-- from the side: the whole wave, the target swallowed at its end
			a.pose = "KaiFire"
			d.x, d.y, d.state, d.pose = far, 1.2 + 0.3 * math.sin(tick / 5), "Launched", "Launched"
			beam(far + dir * 5, 2.4 + 0.25 * math.sin(tick / 3))
			frame.shot = frameOn("kai-mx-side", dir, { { point = true, x = ax, y = 3.1, z = 0 }, { point = true, x = far, y = 3.1, z = 0 } },
				{ yaw = 4, pitch = 4, fill = 0.55, fov = 46, focus = P(D, "UpperTorso") })
		elseif tick < F then
			-- close on it: the wave swallows it whole, swelling and whitening (a ray to the end,
			-- Wilhem: « pas une boule, un rayon »)
			a.pose = "KaiFireStrain"
			d.x, d.y, d.state, d.pose = far, 1.2 + 0.2 * math.sin(tick / 4), "Launched", "Launched"
			local q = progress(tick, 440, F)
			beam(far + dir * 5, lerp(2.4, 3.1, q) * (1 + 0.05 * math.sin(tick * 1.1)), if q > 0.5 then "FFFFFF" else color)
			shape(frame, { kind = "motes", pos = At(v(far, 3, 0)), radius = 4, count = 24, color = "FFFFFF", phase = tick / 30 })
			frame.shot = frameOn("kai-mx-wrap", dir, { d }, { yaw = -34, pitch = -6, fill = 0.62, fov = 40, clear = 4.5, focus = P(D, "Head") })
		else
			-- the explosion: the screen fills with light; it thins out, the shock ring runs on;
			-- K.O. on blue light; he stands, seen from behind, the smoke ahead
			local age = tick - F
			local blast = v(far, 3, 0)
			d.x = far
			a.pose = if age < 60 then "KaiFire" else "StandTall"
			T.FATAL.fall(ctx.cin, d, tick, F + 20, 3)
			if d.pose == "Kneel" then d.pose = "DownFace" end
			if age == 0 then
				sfx(frame, "kx-boom", "boom")
				T.impact(frame, "kx-boom", blast, "FFFFFF", 4)
				table.insert(frame.fx, { key = "kx-debris2", kind = "debris", pos = v(far, 0.5, 0), color = color, scale = 2.4 })
				table.insert(frame.fx, { key = "kx-smoke", kind = "smoke", pos = v(far, 1, 0) })
			end
			o.white = smooth(1 - progress(tick, F + 8, F + 45))
			if age < 80 then
				local q = progress(tick, F, F + 80)
				shape(frame, { kind = "dome", pos = At(v(far, 0, 0)), radius = lerp(3, 16, smooth(q)), color = color, alpha = q })
				shape(frame, { kind = "sphere", pos = At(blast), radius = lerp(3.2, 7, q), color = "FFFFFF", core = 1 - q })
			end
			for i = 0, 1 do
				local q = progress(tick, F + 20 + i * 14, F + 110 + i * 14)
				if q > 0 and q < 1 then
					shape(frame, { kind = "ring", pos = At(v(far, 0.15, 0)), normal = v(0, 1, 0), radius = lerp(2, 24, smooth(q)), width = 0.5,
						color = if i == 0 then "FFFFFF" else color, alpha = q })
				end
			end
			if tick < 540 then
				frame.shot = frameOn("kai-mx-blast", dir, { d }, { yaw = 30, pitch = 8, fill = 0.3, fov = 46, focus = P(D, "UpperTorso") })
			elseif tick < 600 then
				frame.shot = frameOn("kai-mx-far", dir, { a, d }, { yaw = -16, pitch = 18, fill = 0.32, fov = 50, focus = P(D, "UpperTorso") })
			elseif tick < 660 then
				if tick == 600 then sfx(frame, "kx-ko", "boom") end
				ko(ctx, frame, tick, 600, "0B1E4A", { bg = "4AA3FF", splash = "0B3A8A" })
				frame.shot = frameOn("kai-mx-ko", dir, { a, d }, { yaw = -16, pitch = 18, fill = 0.32, fov = 50, focus = P(D, "UpperTorso") })
			else
				if tick == 660 then table.insert(frame.fx, { key = "kx-smoke2", kind = "smoke", pos = v(far, 0.6, 0) }) end
				shape(frame, { kind = "motes", pos = At(v(ax, 2.5, 0)), radius = 5, count = 18, color = color, phase = tick / 70, out = true })
				-- (over his back, toward the smoke where it lies)
				frame.shot = frameOn("kai-mx-behind", dir, { a }, { yaw = -104, pitch = 6, fill = 0.55, fov = 40, focus = P(A, "UpperTorso") })
			end
		end
		if orb > 0 then
			shape(frame, { kind = "kiball", pos = hands, radius = orb, color = color })
		end
	end


	-- ================================================================ ZEPHYR · GALE EXCALIBUR
	-- Wilhem: « Zéphyr tu peux t'inspirer de Végéto ». Cocky, arms crossed, untouchable; then
	-- everywhere at once; a sword of wind out of his own foot.
	-- 0:00 arms crossed, he waits · 0:01 it strikes with all it has: he sways out of every blow
	-- without uncrossing his arms, an afterimage where he stood · 0:03 gone; it looks for him ·
	-- 0:04 six kicks out of six flashes, all round it · 0:06 above it: a sword of wind grows out
	-- of his raised foot · 0:07 the axe kick: the sword cleaves it into the deck, a crescent of
	-- wind across the sky · 0:08 he lands behind it, arms crossed again · 0:09 K.O. · 0:10 his
	-- look, unimpressed; back to the game.
	local ZEPHYR_THEIRS = { -- { tick, its blow, his sway: 1 / -1 aside, 0 back }
		{ 66, "Jab", 1 }, { 88, "Cross", -1 }, { 110, "Kick", 0 }, { 134, "Elbow", 1 }, { 156, "Uppercut", -1 }, { 180, "Smash", 0 } }
	local ZEPHYR_FLASHES = { -- { tick, angle round the target, height, his kick }
		{ 232, 0.4, 0, "Kick" }, { 250, 2.6, 1.6, "SpinKick" }, { 268, 4.4, 0, "Cross" },
		{ 286, 1.4, 2.2, "AirKick" }, { 304, 3.6, 0.6, "Elbow" }, { 322, 5.4, 1.8, "AirKick2" } }
	function S.ZEPHYR(ctx, frame, a, d, tick, dir)
		local A, D = ctx.cin.attacker, ctx.cin.defender
		local moves = ctx.moveData.Moves
		local color = ctx.characters[A].Energy
		local cx = T.center(ctx, d)
		local F = 440
		local o = overlay(frame)
		local ax = inside(ctx, cx - dir * 3.5)
		local behind = inside(ctx, cx + dir * 3.2)
		local hover = 6.8 -- (his height above it before the kick)
		d.x = cx
		-- the sword of wind out of his foot: up while the leg is raised, then down with the kick
		local function sword(length, turn)
			local function tip(l) return P(A, "RightFoot", v(dir * math.sin(turn) * l, math.cos(turn) * l, 0)) end
			shape(frame, { kind = "slash", from = P(A, "RightFoot"), to = tip(length), width = 1.1, color = color, alpha = 0.45 })
			shape(frame, { kind = "slash", from = P(A, "RightFoot"), to = tip(length * 0.96), width = 0.42, color = "FFFFFF", alpha = 0 })
		end
		if tick < 60 then
			-- arms crossed, he waits
			a.x, a.facing, a.pose = ax, dir, "ArmsCrossed"
			d.facing, d.state = -dir, "Idle"
			frame.shot = frameOn("zephyr-ge-wait", dir, { a, d }, { yaw = lerp(20, 28, progress(tick, 0, 60)), pitch = -12, fill = 0.8, fov = 36,
				focus = P(A, "Head") })
		elseif tick < 200 then
			-- it strikes with all it has; he sways out of every blow, arms still crossed
			a.x, a.z, a.facing, a.pose = ax, 0, dir, "ArmsCrossed"
			d.facing = -dir
			local k, age = 1, -99
			for i, b in ZEPHYR_THEIRS do
				if tick >= b[1] - 12 then k, age = i, tick - b[1] end
			end
			if age < 12 then
				attack(d, moves, theirMove(ctx, d, ZEPHYR_THEIRS[k][2]), age >= 0)
			else
				d.state, d.move = "Idle", nil
			end
			-- (out of the way just as it lands, and back again)
			local side = ZEPHYR_THEIRS[k][3]
			local sway = math.sin(math.pi * math.clamp((age + 4) / 18, 0, 1))
			if side ~= 0 then a.z = side * 1.1 * sway else a.x = ax - dir * 1 * sway end
			if age == -4 then
				sfx(frame, "ge-sway" .. k, "whoosh")
				table.insert(frame.fx, { key = "ge-ghost" .. k, kind = "afterimage", slot = A, color = color, life = 0.25 })
			end
			-- (from above the line: a sway aside reads on the screen)
			local yaws = { 14, 20, 18, 26, 12, 22 }
			frame.shot = frameOn("zephyr-ge-sway", dir, { a, d }, { yaw = yaws[k], pitch = 12, fill = 0.82, fov = 36, focus = P(A, "Head") })
		elseif tick < 230 then
			-- gone; it looks for him, one way, the other
			a.x, a.z, a.facing, a.pose = ax, 0, dir, "ArmsCrossed"
			a.hidden = tick >= 204
			if tick == 204 then
				sfx(frame, "ge-gone", "whoosh")
				table.insert(frame.fx, { key = "ge-gone", kind = "afterimage", slot = A, color = color, life = 0.4 })
			end
			d.state, d.move = "Idle", nil
			d.facing = if tick < 216 then -dir else dir
			frame.shot = frameOn("zephyr-ge-gone", dir, { d }, { yaw = 60, pitch = 4, fill = 0.6, fov = 40, focus = P(D, "Head") })
		elseif tick < 340 then
			-- six kicks out of six flashes, all round it
			a.hidden = true
			d.state, d.move = "Hitstun", nil
			for i, f in ZEPHYR_FLASHES do
				local age = tick - f[1]
				local at = v(cx - dir * math.cos(f[2]) * 2.5, f[3] + 3, -math.sin(f[2]) * 2.5)
				if age >= -3 and age < 8 then
					a.hidden, a.untucked = false, true -- (kicks out of nowhere, in the air too)
					circle(a, cx, dir, f[2], 2.5, f[3])
					attack(a, moves, T.role(ctx, f[4]), age >= 0)
				end
				if age == -3 then
					sfx(frame, "ge-flash" .. i, "whoosh")
					T.spark(frame, "ge-flash" .. i, at, "FFFFFF", 0.7)
				end
				if age == 0 then
					sfx(frame, "ge-kick" .. i, "heavy")
					T.spark(frame, "ge-kick" .. i, v(cx, 3.4 + f[3] * 0.4, 0), color, 1.1)
				end
				if age >= 0 and age < 18 then
					local q = progress(age, 0, 18)
					shape(frame, { kind = "ring", pos = At(v(cx, 3.4 + f[3] * 0.4, 0)), normal = v(math.cos(f[2]), 0.3, math.sin(f[2])),
						radius = lerp(0.6, 2.8, q), width = 0.18, color = color, alpha = q })
				end
				if age >= 0 and age < 8 then d.pose = if i % 2 == 0 then "HitBody" else "HitHigh" end
			end
			frame.shot = frameOn("zephyr-ge-flash", dir, { d }, { yaw = lerp(50, 100, progress(tick, 230, 340)), pitch = 10, fill = 0.48, fov = 42,
				focus = P(D, "UpperTorso") })
		elseif tick < 480 then
			-- above it: a sword of wind grows out of his raised foot; the axe kick cleaves it into the deck
			frame.grade.sky = true
			a.hidden, a.untucked = false, true -- (the leg stays up over the deck)
			a.x, a.z, a.lookDir, a.facing = cx - dir * 0.9, 0, nil, dir
			local swing = progress(tick, 424, F)
			a.y = if tick < F then lerp(hover, 4.4, swing * swing) else lerp(4.4, 3.6, progress(tick, F, 470))
			attack(a, moves, T.role(ctx, "Hammer"), tick >= 424)
			d.facing = -dir
			if tick < F then
				d.state, d.pose = "Hitstun", "HitHigh"
			else
				d.state, d.pose, d.hitstop = "Knockdown", "DownFace", if tick < F + 6 then 1 else 0
			end
			if tick == 340 then
				sfx(frame, "ge-above", "whoosh")
				T.spark(frame, "ge-above", v(cx - dir * 0.9, hover + 3, 0), "FFFFFF", 0.9)
			end
			if tick == 360 then sfx(frame, "ge-sword", "charge") end
			local grow = smooth(progress(tick, 360, 400))
			if grow > 0 and tick < F + 20 then
				sword(lerp(0.4, 5.5, grow) * (1 - progress(tick, F + 6, F + 20)), lerp(0, 2.6, smooth(swing)))
			end
			if tick == F then
				sfx(frame, "ge-cleave", "boom")
				T.impact(frame, "ge-cleave", v(cx, 1.2, 0.4), color, 3)
				table.insert(frame.fx, { key = "ge-crack", kind = "crack", from = v(cx - dir * 3, 0.05, 0), to = v(cx + dir * 4, 0.05, 0.4), color = color })
				table.insert(frame.fx, { key = "ge-rocks", kind = "rocks", pos = v(cx, 0, 0.3), radius = 2.6, count = 9, color = "6A6E78" })
				table.insert(frame.fx, { key = "ge-debris", kind = "debris", pos = v(cx, 0.4, 0.3), color = color, scale = 1.8 })
				table.insert(frame.fx, { key = "ge-dust", kind = "dust", pos = v(cx, 0, 0), direction = dir })
			end
			if tick >= F then
				o.white = 0.7 * (1 - progress(tick, F, F + 10))
				frame.quake = 0.5 * (1 - progress(tick, F, F + 18))
				-- the crescent of wind flies off across the sky
				local q = progress(tick, F, F + 40)
				if q < 1 then
					local r = lerp(5, 16, smooth(q))
					local function onArc(u)
						local ang = math.rad(lerp(30, 150, u))
						return At(v(cx + math.cos(ang) * r, 2 + math.sin(ang) * r, -4))
					end
					for k = 0, 11 do
						shape(frame, { kind = "slash", from = onArc(k / 12), to = onArc((k + 1) / 12), width = lerp(1.2, 0.3, q), color = if k % 3 == 0 then "FFFFFF" else color,
							alpha = q })
					end
				end
			end
			local blade = { point = true, x = cx - dir * 0.9, y = hover + 10.5, z = 0 }
			if tick < 372 then
				-- (from the deck, looking up at him)
				frame.shot = frameOn("zephyr-ge-above", dir, { a }, { yaw = 24, pitch = -32, fill = 0.55, fov = 42, focus = P(A, "Head") })
			elseif tick < 424 then
				-- (him and the sword of wind out of his foot)
				frame.shot = frameOn("zephyr-ge-sword", dir, { a, blade }, { yaw = 20, pitch = -16, fill = 0.75, fov = 44, focus = P(A, "Head") })
			elseif tick < F then
				frame.shot = frameOn("zephyr-ge-cleave", dir, { a, d }, { yaw = 16, pitch = -6, fill = 0.72, fov = 46, focus = P(A, "Head") })
			else
				frame.shot = frameOn("zephyr-ge-crescent", dir, { a, d, { point = true, x = cx, y = 12, z = -4 } }, { yaw = 10, pitch = -6, fill = 0.62, fov = 50,
					focus = P(D, "UpperTorso") })
			end
		elseif tick < 540 then
			-- he lands behind it, arms crossed again; his back to it
			local q = progress(tick, 480, 498)
			a.untucked = nil
			a.x, a.z, a.lookDir, a.facing = lerp(cx - dir * 0.9, behind, smooth(q)), 0, nil, dir
			a.y = 3.6 * (1 - q) + 1.4 * math.sin(math.pi * q)
			a.move = nil
			if q < 1 then
				a.state, a.pose = "Falling", "JumpApex"
			else
				a.state, a.pose = "Idle", "ArmsCrossed"
			end
			d.state, d.pose = "Knockdown", "DownFace"
			if tick == 498 then sfx(frame, "ge-land", "whoosh") end
			frame.shot = frameOn("zephyr-ge-land", dir, { a, d }, { yaw = 24, pitch = -4, fill = 0.75, fov = 38, focus = P(A, "Head") })
		elseif tick < 600 then
			-- K.O.
			a.x, a.facing, a.pose = behind, dir, "ArmsCrossed"
			d.state, d.pose = "Knockdown", "DownFace"
			if tick == 540 then sfx(frame, "ge-ko", "boom") end
			ko(ctx, frame, tick, 540, color, { bg = "0A1418", splash = color })
			frame.shot = frameOn("zephyr-ge-ko", dir, { a, d }, { yaw = 24, pitch = -4, fill = 0.75, fov = 38, focus = P(A, "Head") })
		else
			-- his look, unimpressed; back to the game
			local q = smooth(progress(tick, 600, 720))
			a.x, a.facing, a.pose = behind, dir, "ArmsCrossed"
			d.state, d.pose = "Knockdown", "DownFace"
			frame.shot = frameOn("zephyr-ge-look", dir, { a }, { yaw = lerp(46, 32, q), pitch = -8, band = "bust", fill = lerp(0.62, 0.76, q), fov = 30,
				focus = P(A, "Head") })
		end
	end

	-- ================================================================ AKEMI · THOUSAND SHADOWS
	-- Her INSTINCT turned into an execution. 0:00 she waits, eyes closed, the world dims · 0:01
	-- the target throws everything it has (its own blows); each one goes through a shadow of
	-- her: she is already elsewhere · 0:03 she is gone; the target alone in a ring of her
	-- shadows; one by one they come alive and cut · 0:05 a thousand cuts at once · 0:06
	-- silence, the target looks for her... she falls from above onto its neck · 0:08 she walks
	-- away.
	-- (her places round the target, x along the fight, z away from the camera: the shadows
	-- stand on the far half, the camera on the near one sees them all)
	local AKEMI_SPOTS = { [0] = { -2.6, 0 }, { 2.7, -0.4 }, { -1.5, -2.7 }, { 1.7, -2.7 }, { -0.2, -3.6 } }
	local AKEMI_STYLES = { "SIDE", "INSTINCT", "SLIP", "BACK" }
	local AKEMI_BLOWS = { 56, 96, 132, 166 }
	local AKEMI_THEIRS = { "Jab", "Elbow", "Uppercut", "SpinKick" }
	local AKEMI_STRIKES = { { 236, "Jab" }, { 258, "BodyBlow" }, { 278, "Smash" }, { 296, "Elbow" } }
	function S.AKEMI(ctx, frame, a, d, tick, dir)
		local A, D = ctx.cin.attacker, ctx.cin.defender
		local moves = ctx.moveData.Moves
		local color = ctx.characters[A].Energy
		local cx = T.center(ctx, d)
		local F = 470
		local BURST = 318
		-- the target's own blows (its kit's move for each role)
		local theirKit = ctx.moveData.Kits[d.kit or "KAI"] or ctx.moveData.Kits.KAI
		local function theirs(r)
			local id = theirKit and theirKit.Roles and theirKit.Roles[r] or r
			return if moves[id] then id else r
		end
		local function spot(i)
			local s_ = AKEMI_SPOTS[i]
			return inside(ctx, cx + dir * s_[1]), s_[2]
		end
		local function faceToward(x, z)
			local lx, lz = x - d.x, (z or 0) - (d.z or 0)
			local l = math.max(1e-3, math.sqrt(lx * lx + lz * lz))
			d.lookDir, d.facing = v(lx / l, 0, lz / l), if lx >= 0 then 1 else -1
		end
		local function faceTarget()
			local lx, lz = d.x - a.x, -(a.z or 0)
			local l = math.max(1e-3, math.sqrt(lx * lx + lz * lz))
			a.lookDir, a.facing = v(lx / l, 0, lz / l), if lx >= 0 then 1 else -1
		end
		local ring = { d }
		for i = 0, 3 do
			local x, z = spot(i)
			table.insert(ring, { point = true, x = x, y = 2.5, z = z })
		end
		d.x, d.state = cx, "Hitstun"
		if tick < F then overlay(frame).desat = if tick < BURST then 0.5 * smooth(progress(tick, 0, 50)) else 0.5 * smooth(progress(tick, 330, 400)) end
		if tick < 50 then
			-- she waits, eyes closed; the target gathers itself
			a.x, a.z, a.facing, a.pose = cx - dir * 2.6, nil, dir, "Sheathe"
			d.state, d.facing = "Idle", -dir
			if tick < 26 then
				frame.shot = frameOn("akemi-ts-wait", dir, { a, d }, { yaw = -60, pitch = 2, fill = 0.7, fov = 34, focus = P(A, "Head") })
			else
				local q = smooth(progress(tick, 26, 50))
				frame.shot = shot("akemi-ts-face", P(A, "Head", v(dir * lerp(2.3, 1.9, q), 0.2, lerp(3.4, 3.0, q))), P(A, "Head", v(0, 0.05, 0)),
					lerp(36, 30, q), 0, P(A, "Head"))
				frame.shot.close = true
			end
		elseif tick < 204 then
			-- it throws everything at her; each blow goes through a shadow, she is already elsewhere
			local k = 1
			for i, t in AKEMI_BLOWS do
				if tick >= t - 12 then k = i end
			end
			local age = tick - AKEMI_BLOWS[k]
			local fromX, fromZ = spot(k - 1)
			local toX, toZ = spot(k)
			if age < 0 then faceToward(fromX, fromZ) end
			if age < 10 then
				attack(d, moves, theirs(AKEMI_THEIRS[k]), age >= 0)
			else
				-- (it goes after her, between two blows)
				d.state, d.move, d.vx = "Walking", nil, (d.facing or -dir) * 2
			end
			if age >= 0 and age < 14 then
				local m = smooth(math.min(1, age / 6))
				a.x, a.z = lerp(fromX, toX, m), lerp(fromZ, toZ, m)
				a.state, a.move, a.evadeStyle = "Evading", nil, AKEMI_STYLES[k]
				if age == 0 then
					-- (the shadow stays where the blow lands; it lives until it strikes)
					sfx(frame, "ts-dodge" .. k, "whoosh")
					table.insert(frame.fx, { key = "ts-shadow" .. k, kind = "afterimage", slot = A, color = color,
						life = (AKEMI_STRIKES[k][1] - tick) / 60 })
				end
			else
				local x, z = if age < 0 then fromX else toX, if age < 0 then fromZ else toZ
				a.x, a.z, a.state, a.move = x, z, "Idle", nil
			end
			faceTarget()
			frame.shot = frameOn("akemi-ts-dance", dir, { a, d }, { yaw = lerp(-10, 40, progress(tick, 50, 204)), pitch = 10, fill = 0.7, fov = 40,
				focus = P(A, "UpperTorso") })
		elseif tick < BURST then
			-- she is gone: the target alone in a ring of her shadows; they come alive, one by one
			a.hidden = true
			local x4, z4 = spot(4)
			a.x, a.z, a.state, a.move = x4, z4, "Idle", nil
			if tick == 204 then sfx(frame, "ts-vanish", "whoosh") end
			local striking = nil
			for i, s_ in AKEMI_STRIKES do
				if tick >= s_[1] and tick < s_[1] + 12 then striking = i end
			end
			if striking then
				local s_ = AKEMI_STRIKES[striking]
				local age = tick - s_[1]
				a.hidden = false
				a.x, a.z = spot(striking - 1)
				faceTarget()
				attack(a, moves, T.role(ctx, s_[2]), age >= 2)
				if age >= 2 then
					d.pose = if striking % 2 == 0 then "HitHigh" else "HitBody"
					local ux, uz = d.x - a.x, -(a.z or 0)
					local l = math.max(1e-3, math.sqrt(ux * ux + uz * uz))
					ux, uz = ux / l, uz / l
					shape(frame, { kind = "slash", from = At(v(d.x - ux * 2.4 - uz * 0.6, 4.2, -uz * 2.4 + ux * 0.6)),
						to = At(v(d.x + ux * 2.4 + uz * 0.6, 2.6, uz * 2.4 - ux * 0.6)), width = 0.2, color = if striking % 2 == 0 then "FFFFFF" else color,
						alpha = (age - 2) / 10 })
				end
				if age == 2 then sfx(frame, "ts-cut" .. striking, "slash") end
				local yaws = { 20, -25, -35, 45 }
				frame.shot = frameOn("akemi-ts-strike" .. striking, dir, { a, d }, { yaw = yaws[striking], pitch = 12, fill = 0.75, fov = 40,
					focus = P(D, "UpperTorso") })
			else
				-- (it turns round and round, looking for her)
				local turn = (tick - 204) * 0.05
				faceToward(d.x + math.cos(turn) * dir, math.sin(turn))
				frame.shot = frameOn("akemi-ts-ring", dir, ring, { yaw = 0, pitch = 30, fill = 0.75, fov = 44, focus = P(D, "UpperTorso") })
			end
		elseif tick < 330 then
			-- all of them at once: a thousand cuts
			a.hidden = true
			d.pose = if (tick // 3) % 2 == 0 then "HitHigh" else "HitBody"
			if tick == BURST then
				sfx(frame, "ts-burst", "boom")
				frame.impact = { key = "ts-burst", color = "FFFFFF" }
			end
			for i = 0, 7 do
				local angle = i * math.pi / 8 + 0.2
				local c, s2 = math.cos(angle), math.sin(angle)
				shape(frame, { kind = "slash", from = At(v(cx - c * 3.4, 3.3 - s2 * 2.2, -s2 * 2)), to = At(v(cx + c * 3.4, 3.3 + s2 * 2.2, s2 * 2)),
					width = 0.24, color = if i % 2 == 0 then "FFFFFF" else color, alpha = progress(tick, BURST, 330) })
			end
			for i = 0, 3 do
				local x, z = spot(i)
				shape(frame, { kind = "motes", pos = At(v(x, 2.5, z)), radius = 2.5, count = 10, color = color, phase = (tick - BURST) / 12, out = true })
			end
			frame.shot = frameOn("akemi-ts-burst", dir, { d }, { yaw = 10, pitch = 66, fill = 0.5, fov = 44, focus = P(D, "UpperTorso") })
		elseif tick < F then
			-- silence; the target looks for her... she falls from above onto its neck
			d.pose = nil
			if tick < 444 then
				a.hidden = true
				local turn = (tick - 330) * 0.03
				faceToward(d.x - math.cos(turn) * dir, -math.sin(turn) * 0.6)
				frame.shot = frameOn("akemi-ts-alone", dir, { d }, { yaw = lerp(-40, 20, progress(tick, 330, 444)), pitch = 6, fill = 0.7, fov = 36,
					focus = P(D, "Head") })
			else
				d.facing, d.lookDir = -dir, nil
				local q = progress(tick, 444, F)
				a.hidden = false
				a.x, a.z, a.facing = cx + dir * 0.9, nil, -dir
				a.y = lerp(10, 3.2, q * q)
				attack(a, moves, T.role(ctx, "Hammer"), q > 0.8)
				if tick == 444 then sfx(frame, "ts-fall", "whoosh") end
				frame.shot = frameOn("akemi-ts-fall", dir, { a }, { yaw = 25, pitch = -40, fill = 0.6, fov = 42, focus = P(A, "UpperTorso") })
			end
		else
			-- on its neck; it drops; she walks away
			local age = tick - F
			d.facing, d.lookDir = -dir, nil
			T.FATAL.fall(ctx.cin, d, tick, F + 2, 0)
			if d.pose == "Kneel" then d.pose = "DownFace" end
			if tick == F then
				sfx(frame, "ts-neck", "heavy")
				T.impact(frame, "ts-neck", v(cx, 4.4, 0.6), color, 2.2)
			end
			if age < 40 then
				a.x, a.facing, a.y = cx + dir * 0.9, -dir, lerp(3.2, 0, smooth(math.min(1, age / 14)))
				if age < 14 then attack(a, moves, T.role(ctx, "Hammer"), true) else a.state, a.move, a.pose = "Idle", nil, "Sheathe" end
				frame.shot = frameOn("akemi-ts-neck", dir, { a, d }, { yaw = 25, pitch = -10, fill = 0.7, fov = 40, focus = P(D, "UpperTorso") })
			else
				local p = progress(tick, F + 40, 640)
				a.y, a.facing = 0, dir
				a.x, a.state, a.move, a.vx = cx + dir * lerp(0.9, 4.5, p), "Walking", nil, dir * 2
				shape(frame, { kind = "motes", pos = P(A, "UpperTorso"), radius = 3, count = 12, color = color, phase = tick / 80, out = true })
				frame.shot = frameOn("akemi-ts-after", dir, { a, d }, { yaw = 30, pitch = 2, fill = 0.55, fov = 34, focus = P(A, "UpperTorso") })
			end
			ko(ctx, frame, tick, F + 40, color)
		end
	end

	-- ================================================================ RYUKEN · TEN FISTS OF RAGE
	-- His RAGE counted out loud: ten blows, each one heavier than the last (the count slams in
	-- at the side of the screen). 0:00 from the deck: he rises, the floor cracks, the roar ·
	-- 0:01 one to five, quick, the target driven back · 0:03 six to nine, slower and heavier,
	-- each one a frozen impact; nine smashes it into the deck · 0:07 it bounces up in slow
	-- motion; his fist, his eyes · 0:08 ten: the sonic boom; the camera whips after the body
	-- to the wall · 0:09 the steam off his fist.
	local RYUKEN_BLOWS = {
		{ 96, "Jab", 8, 0.3 }, { 116, "Cross", 8, 0.6 }, { 134, "Jab", 8, 0.9 }, { 152, "Cross", 8, 1.2 }, { 170, "BodyBlow", 10, 1.7 },
		{ 206, "Elbow", 14, 2.4 }, { 246, "Smash", 16, 3.2 }, { 290, "Uppercut", 16, 3.8 }, { 340, "Hammer", 18, 4.4 },
	}
	local RYUKEN_CUTS = { [6] = { 55, -16 }, [7] = { -60, 4 }, [8] = { 20, -30 }, [9] = { 10, 64 } }
	function S.RYUKEN(ctx, frame, a, d, tick, dir)
		local A, D = ctx.cin.attacker, ctx.cin.defender
		local moves = ctx.moveData.Moves
		local color = ctx.characters[A].Energy
		local cx = T.center(ctx, d)
		local cfg = ctx.config
		local F = 480
		-- (he drives it back, then sends it across the arena: the scene stands back from the wall)
		local room = 26
		local ax0 = if dir > 0 then math.min(cx - 2.9, cfg.ArenaMaxX - 1 - room) else math.max(cx + 2.9, cfg.ArenaMinX + 1 + room)
		ax0 = inside(ctx, ax0)
		local dx0 = ax0 + dir * 2.9
		frame.grade.rage = tick >= 40 and tick < F + 120
		-- where the count stands: the last blow landed and its age
		local n, age = 0, 99
		for i, b in RYUKEN_BLOWS do
			if tick >= b[1] then n, age = i, tick - b[1] end
		end
		if tick >= F then n, age = 10, tick - F end
		local function push(i)
			if i < 1 then return 0 end
			local prev = if i > 1 then RYUKEN_BLOWS[i - 1][4] else 0
			local b = RYUKEN_BLOWS[i]
			return lerp(prev, b[4], smooth(math.min(1, (tick - b[1]) / 8)))
		end
		if n >= 1 then
			local o = overlay(frame)
			o.caption = { text = tostring(n), color = if n >= 10 then "FFFFFF" else color, stroke = if n >= 10 then color else nil, age = age,
				fade = progress(tick, F + 50, F + 70) }
		end
		if tick < 90 then
			-- from the deck: he rises; the floor cracks; the roar
			a.x, a.facing = ax0, dir
			d.x, d.facing, d.state = dx0, -dir, "Hitstun"
			a.pose = if tick >= 40 then "Roar" else nil
			if tick >= 40 then frame.aura = A end
			if tick == 40 then
				sfx(frame, "tf-roar", "charge")
				for i = 0, 4 do
					local angle = i * 1.25 + 0.3
					table.insert(frame.fx, { key = "tf-crack" .. i, kind = "crack", from = v(ax0, 0.05, 0),
						to = v(ax0 + math.cos(angle) * 4, 0.05, math.sin(angle) * 2.5), color = color })
				end
			end
			frame.quake = if tick >= 40 and tick < 48 then 0.5 else nil
			if tick % 10 == 0 then table.insert(frame.fx, { key = "tf-steam" .. tick, kind = "smoke", pos = v(ax0, 2.6, 0.4) }) end
			if tick < 40 then
				-- (from the deck, looking up at him)
				frame.shot = frameOn("ryuken-tf-floor", dir, { a }, { yaw = lerp(-40, -30, progress(tick, 0, 40)), pitch = -32, fill = 0.8, fov = 40,
					focus = P(A, "Head") })
			else
				frame.shot = frameOn("ryuken-tf-roar", dir, { a }, { yaw = 24, pitch = -18, fill = 0.85, fov = 34, focus = P(A, "Head") })
			end
		elseif tick < 356 then
			-- one to nine
			local next = nil
			for i, b in RYUKEN_BLOWS do
				if tick < b[1] then
					next = i
					break
				end
			end
			local back = push(n)
			d.x, d.facing, d.state = dx0 + dir * back, -dir, "Hitstun"
			a.x, a.facing = d.x - dir * 2.9, dir
			frame.aura = A
			local b = RYUKEN_BLOWS[n]
			local id = b and T.role(ctx, b[2])
			if b and age < 10 and moves[id] then
				attack(a, moves, id, true)
			elseif next and tick >= RYUKEN_BLOWS[next][1] - RYUKEN_BLOWS[next][3] then
				attack(a, moves, T.role(ctx, RYUKEN_BLOWS[next][2]), false)
			else
				a.state, a.move = "Idle", nil
			end
			-- its reaction; eight lifts it, nine smashes it into the deck
			if n == 8 then
				d.y, d.pose = 2.4 * math.sin(math.min(1, age / 40) * math.pi), "Launched"
			elseif n == 9 then
				d.y, d.pose = 0, "DownImpact"
			else
				d.pose = if age < 8 then (if n % 2 == 0 then "HitHigh" else "HitBody") else nil
			end
			if b and age == 0 then
				sfx(frame, "tf-blow" .. n, if n >= 7 then "boom" else "heavy")
				T.impact(frame, "tf-blow" .. n, v(d.x - dir * 0.4, if n == 9 then 1.2 else 3.6, 0.6), if n % 3 == 0 then "FFFFFF" else color, 1 + n * 0.22)
				if n == 9 then
					for i = 0, 5 do
						local angle = i * 1.05 + 0.2
						table.insert(frame.fx, { key = "tf-web" .. i, kind = "crack", from = v(d.x, 0.05, 0),
							to = v(d.x + math.cos(angle) * 5, 0.05, math.sin(angle) * 3), color = color })
					end
					table.insert(frame.fx, { key = "tf-dust9", kind = "dust", pos = v(d.x, 0, 0), direction = dir })
					table.insert(frame.fx, { key = "tf-debris9", kind = "debris", pos = v(d.x, 0.4, 0), color = color, scale = 1.4 })
				end
			end
			-- six to nine: the impact holds a beat (frozen, the colour drained)
			if n >= 6 and age < 10 then
				a.hitstop, d.hitstop = 1, 1
				overlay(frame).desat = 0.7 * (1 - age / 10)
			else
				a.hitstop, d.hitstop = 0, 0
			end
			frame.quake = if b and age < 6 then 0.08 * n else nil
			if n >= 6 and RYUKEN_CUTS[n] and (age < 30 or not next) then
				local c = RYUKEN_CUTS[n]
				frame.shot = frameOn("ryuken-tf-cut" .. n, dir, { a, d }, { yaw = c[1], pitch = c[2], fill = 0.8, fov = 40, focus = P(D, "UpperTorso") })
			else
				local p = progress(tick, 90, 356)
				frame.shot = frameOn("ryuken-tf-blows", dir, { a, d }, { yaw = lerp(-10, 26, p), pitch = -6, fill = 0.78, fov = 38, roll = 3 * math.sin(tick / 9),
					focus = P(D, "UpperTorso") })
			end
		elseif tick < F then
			-- it bounces up in slow motion; his fist; his eyes
			local nine = RYUKEN_BLOWS[9][4]
			d.x, d.facing, d.state = dx0 + dir * nine, -dir, "Hitstun"
			d.y, d.pose = 1.5 * smooth(progress(tick, 356, 440)), "Launched"
			a.x, a.facing = d.x - dir * 2.9, dir
			attack(a, moves, T.role(ctx, "Finale"), false)
			frame.aura = A
			shape(frame, { kind = "motes", pos = P(A, "RightHand"), radius = 3, count = 18, color = color, phase = tick / 40 })
			if tick % 10 == 0 then
				table.insert(frame.fx, { key = "tf-arc" .. tick, kind = "lightning", from = v(a.x + math.cos(tick) * 2, 3 + math.sin(tick * 1.3), 0.6),
					to = v(a.x - dir * 0.4, 3.4, 0.4), color = color })
			end
			if tick == 420 then sfx(frame, "tf-charge", "charge") end
			if tick < 420 then
				frame.shot = frameOn("ryuken-tf-bounce", dir, { a, d }, { yaw = 34, pitch = -4, fill = 0.75, fov = 36, focus = P(D, "UpperTorso") })
			elseif tick < 450 then
				frame.shot = frameOn("ryuken-tf-fist", dir, { a }, { yaw = -50, pitch = -8, band = "bust", fill = 0.85, fov = 30, focus = P(A, "RightHand") })
			else
				local q = smooth(progress(tick, 450, F))
				frame.shot = frameOn("ryuken-tf-eyes", dir, { a }, { yaw = 40, pitch = -6, band = "bust", fill = lerp(0.8, 0.95, q), fov = lerp(30, 24, q),
					focus = P(A, "Head") })
			end
		else
			-- ten: the sonic boom; the body crosses the arena into the wall
			local nine = RYUKEN_BLOWS[9][4]
			local from = dx0 + dir * nine
			a.x, a.facing = from - dir * 2.9, dir
			local far = inside(ctx, from + dir * 16)
			local q = smooth(math.min(1, progress(tick, F, F + 20)))
			if tick < F + 20 then
				d.x, d.y, d.pose, d.state = lerp(from, far, q), lerp(1.5, 2.2, q), "Launched", "Hitstun"
			else
				d.x = far
				T.FATAL.fall(ctx.cin, d, tick, F + 20, 2.2)
				if d.pose == "Kneel" then d.pose = "DownFace" end
			end
			if tick < F + 110 then
				attack(a, moves, T.role(ctx, "Finale"), true)
			else
				a.state, a.move, a.pose = "Idle", nil, "StandTall"
			end
			if tick == F then
				sfx(frame, "tf-ten", "boom")
				frame.impact = { key = "tf-ten", color = "FFFFFF" }
				T.spark(frame, "tf-ten", v(from, 3.6, 0.6), "FFFFFF", 3)
				table.insert(frame.fx, { key = "tf-line", kind = "crack", from = v(a.x + dir, 0.05, 0), to = v(far, 0.05, 0), color = color })
			end
			if tick == F + 20 then
				sfx(frame, "tf-wall", "heavy")
				T.impact(frame, "tf-wall", v(far, 2.4, 0.6), color, 3)
				table.insert(frame.fx, { key = "tf-wall-debris", kind = "debris", pos = v(far, 1, 0), color = color, scale = 1.6 })
			end
			-- the sonic boom: rings along the punch
			for i = 0, 2 do
				local r = progress(tick, F + i * 3, F + 26 + i * 3)
				if r > 0 and r < 1 then
					shape(frame, { kind = "ring", pos = At(v(a.x + dir * (2.2 + i * 2.8), 3.4, 0)), normal = v(dir, 0, 0), radius = 0.8 + 4.5 * smooth(r),
						width = 0.3, color = if i == 1 then color else "FFFFFF", alpha = r })
				end
			end
			if tick > F + 30 and tick % 8 == 0 then
				table.insert(frame.fx, { key = "tf-fsteam" .. tick, kind = "smoke", pos = v(a.x + dir * 1.2, 3.4, 0.4) })
			end
			frame.quake = if tick < F + 10 then 1 else nil
			frame.aura = if tick < F + 60 then A else nil
			if tick < F + 24 then
				-- the whip: the camera beside the path turns after the body
				frame.shot = shot("ryuken-tf-whip", At(v(lerp(from, far, 0.45), 3.2, 8)), P(D, "UpperTorso"), 46, 0, P(D, "UpperTorso"))
			elseif tick < F + 70 then
				frame.shot = frameOn("ryuken-tf-wall", dir, { d }, { yaw = -20, pitch = 4, fill = 0.45, fov = 40, focus = P(D, "UpperTorso") })
			else
				-- (over his shoulder: the fist steaming in front, the body slumped at the wall far behind)
				frame.shot = shot("ryuken-tf-after", At(v(a.x - dir * 5, 4.4, 7)), At(v(lerp(a.x, far, 0.35), 2.6, 0)), 40, 0, P(A, "UpperTorso"))
			end
			ko(ctx, frame, tick, F + 70, color)
		end
	end


	-- ================================================================ DAICHA · INVERTED WORLD
	-- Her INVERTED SHADOW made a world. 0:00 her matter spreads under the target, a black pool ·
	-- 0:02 she turns the world over: the image rolls upside down, the colours invert, the target
	-- falls into the sky · 0:04 up there, under a black sun, she blinks to it and her matter
	-- strikes three times · 0:06 the world rights itself: it falls back, all the way down, into
	-- the pool, which closes over it and spits it out · 0:09 the pool dries up, her matter back
	-- in her hand.
	function S.DAICHA(ctx, frame, a, d, tick, dir)
		local A, D = ctx.cin.attacker, ctx.cin.defender
		local moves = ctx.moveData.Moves
		local color = ctx.characters[A].Energy
		local cx = T.center(ctx, d)
		local F = 470
		local home = inside(ctx, cx - dir * 5)
		local TOP = 22
		d.x, d.facing = cx, -dir
		local pool = 3.2 * smooth(progress(tick, 20, 110)) * (1 - smooth(progress(tick, F + 60, F + 140)))
		if pool > 0.05 then matter(frame, "puddle", v(cx, 0.05, 0), pool, color) end
		-- (the roll of the world: over at 100-170, back at 330-350)
		local over = smooth(progress(tick, 100, 170)) * (1 - smooth(progress(tick, 330, 350)))
		local roll = 180 * over
		frame.grade.inverse = over > 0.5
		if tick < 100 then
			-- her matter spreads under the target; it is held there
			a.x, a.facing, a.pose = home, dir, "Levitate"
			d.state, d.pose = "Hitstun", "VicBrace"
			matter(frame, "ball", v(home + dir * 0.9, 3.4 + 0.2 * math.sin(tick / 9), 0.6), 0.45, color)
			if tick == 20 then sfx(frame, "iw-pool", "charge") end
			if tick < 52 then
				frame.shot = frameOn("daicha-iw-pool", dir, { d, { point = true, x = cx, y = 0, z = 1.6 } }, { yaw = 34, pitch = 10, fill = 0.6, fov = 40,
					focus = P(D, "UpperTorso") })
			else
				frame.shot = frameOn("daicha-iw-hand", dir, { a }, { yaw = 32, pitch = -4, band = "bust", fill = 0.85, fov = 32, focus = P(A, "Head") })
			end
		elseif tick < 210 then
			-- the world turns over; the target falls into the sky
			local q = progress(tick, 130, 210)
			a.x, a.facing, a.pose = home, dir, "Levitate"
			d.y, d.state, d.pose = TOP * 0.45 * q * q, "Hitstun", if q > 0 then "Launched" else "VicBrace"
			for i = 0, 5 do
				-- (drops of her matter rain upward out of the pool)
				local t = ((tick - 100) / 70 + i / 6) % 1
				matter(frame, "ball", v(cx + math.cos(i * 2.1) * 1.8, 0.2 + t * 12, math.sin(i * 2.1) * 1.4), 0.12 + 0.06 * (i % 2), color)
			end
			if tick == 100 then sfx(frame, "iw-turn", "whoosh") end
			frame.shot = frameOn("daicha-iw-turn", dir, { a, d }, { yaw = 20, pitch = 6, fill = 0.6, fov = 44, roll = roll, focus = P(D, "UpperTorso") })
		elseif tick < 330 then
			-- under a black sun: she blinks to it; her matter strikes three times
			d.y, d.state = lerp(TOP * 0.45, TOP, smooth(progress(tick, 210, 330))), "Hitstun"
			if tick == 210 then
				table.insert(frame.fx, { key = "iw-sun", kind = "eclipse", pos = v(cx, TOP + 12, -14), color = color, scale = 1.6, life = 2.4 })
				table.insert(frame.fx, { key = "iw-blink", kind = "afterimage", slot = A, color = color, life = 0.6 })
				sfx(frame, "iw-blink", "whoosh")
			end
			a.x, a.y, a.facing = cx - dir * 4, d.y - 0.4, dir
			local strikes = { 236, 266, 296 }
			local k, age = 0, 99
			for i, t in strikes do
				if tick >= t then k, age = i, tick - t end
			end
			local roles = { "Cross", "Smash", "Finale" }
			if k > 0 and age < 14 then
				attack(a, moves, T.role(ctx, roles[k]), age >= 2)
				d.pose = if k % 2 == 0 then "HitBody" else "HitHigh"
			else
				a.state, a.move, a.pose = "Jumping", nil, "Levitate"
				d.pose = "Launched"
			end
			if k > 0 and age == 2 then
				table.insert(frame.fx, { key = "iw-dart" .. k, kind = "orbDart", from = v(a.x + dir * 1.2, a.y + 3.4, 0.4), to = v(cx, d.y + 3.2, 0.4), color = color })
				table.insert(frame.fx, { key = "iw-burst" .. k, kind = "matterBurst", pos = v(cx, d.y + 3.2, 0.4), color = color, scale = 0.8 + 0.3 * k })
				sfx(frame, "iw-hit" .. k, "heavy")
			end
			local yaws = { 8, -16, 24 }
			frame.shot = frameOn("daicha-iw-sky" .. math.max(1, k), dir, { a, d }, { yaw = yaws[math.max(1, k)], pitch = -8, fill = 0.7, fov = 40, roll = 180,
				focus = P(D, "UpperTorso") })
		elseif tick < F then
			-- the world rights itself: it falls all the way back, into the pool
			local q = progress(tick, 350, F)
			d.y = if tick < 350 then TOP else TOP * (1 - q * q)
			d.state, d.pose = "Hitstun", "Launched"
			a.x, a.facing = cx - dir * 4, dir
			a.y = lerp(TOP - 0.4, 7, smooth(progress(tick, 330, F)))
			a.state, a.move, a.pose = "Jumping", nil, "Levitate"
			-- (the pool rises to meet it, a mouth of matter)
			local rise = smooth(progress(tick, F - 40, F))
			if rise > 0 then matter(frame, "wave", v(cx, 0, 0), 3.4, color, nil, 0.2 + 5 * rise) end
			if tick == 330 then sfx(frame, "iw-back", "whoosh") end
			if tick < 350 then
				frame.shot = frameOn("daicha-iw-right", dir, { a, d }, { yaw = 20, pitch = -8, fill = 0.7, fov = 40, roll = roll, focus = P(D, "UpperTorso") })
			elseif tick < 420 then
				-- (from above it: the body falls away toward the pool)
				frame.shot = shot("daicha-iw-fall", At(v(cx + dir * 3, d.y + 10, 5)), P(D, "UpperTorso"), 50, 0, P(D, "UpperTorso"))
			else
				frame.shot = frameOn("daicha-iw-mouth", dir, { d, { point = true, x = cx, y = 0, z = 0 } }, { yaw = 26, pitch = 8, fill = 0.7, fov = 44,
					focus = P(D, "UpperTorso") })
			end
		else
			-- the pool closes over it and spits it out; it dries up; her matter back in her hand
			local age = tick - F
			local close = 1 - smooth(progress(tick, F, F + 40))
			if close > 0 then matter(frame, "wave", v(cx, 0, 0), 3.4 + 0.6 * (1 - close), color, nil, 0.2 + 5.2 * close) end
			d.y = 0
			T.FATAL.fall(ctx.cin, d, tick, F + 30, 0)
			if d.pose == "Kneel" then d.pose = "DownFace" end
			if age == 0 then
				sfx(frame, "iw-crash", "boom")
				T.impact(frame, "iw-crash", v(cx, 1.4, 0.6), color, 3)
				table.insert(frame.fx, { key = "iw-drops", kind = "matterBurst", pos = v(cx, 1, 0.4), color = color, scale = 2.2 })
			end
			for i = 0, 1 do
				local r = progress(tick, F + i * 10, F + 60 + i * 10)
				if r > 0 and r < 1 then
					shape(frame, { kind = "ring", pos = At(v(cx, 0.15, 0)), normal = v(0, 1, 0), radius = lerp(3, 14, smooth(r)), width = 0.35,
						color = if i == 0 then "FFFFFF" else color, alpha = r })
				end
			end
			a.facing = dir
			a.x = cx - dir * lerp(4, 4.8, smooth(progress(tick, F, F + 60)))
			a.y = lerp(7, 0, smooth(progress(tick, F, F + 70)))
			a.state, a.move, a.pose = if a.y > 0.2 then "Jumping" else "Idle", nil, if tick > F + 90 then "StandTall" else "Levitate"
			local back = smooth(progress(tick, F + 90, F + 130))
			matter(frame, "ball", v(lerp(cx, a.x + dir * 0.9, back), lerp(1.2, 3.4, back) + math.sin(back * math.pi), lerp(0, 0.6, back)), 0.45, color)
			if age < 40 then
				frame.shot = frameOn("daicha-iw-crash", dir, { d, { point = true, x = cx, y = 4, z = 0 } }, { yaw = 26, pitch = 18, fill = 0.55, fov = 44,
					focus = P(D, "UpperTorso") })
			else
				frame.shot = frameOn("daicha-iw-after", dir, { a, d }, { yaw = -34, pitch = 4, fill = 0.6, fov = 38, focus = P(A, "UpperTorso") })
			end
			ko(ctx, frame, tick, F + 40, color)
		end
	end

	-- ================================================================ HIBECARES · THRONE OF RUINS
	-- The king of ruins does not move. 0:00 the target strikes him with everything it has (its
	-- own blows): stone flies off him, he does not flinch · 0:03 he looks down at it; it backs
	-- away · 0:04 his stomp: a pillar of ruins rises under it and lifts it to his face · 0:06 he
	-- raises both fists, the stones of the arena rise round them · 0:08 both fists: the pillar
	-- shatters, the target is driven into the deck; a crown of ruins round the crater · 0:09
	-- he stands among them.
	local HIBECARES_THEIRS = { { 30, "Jab" }, { 66, "Cross" }, { 100, "Kick" }, { 132, "Uppercut" }, { 168, "Smash" } }
	function S.HIBECARES(ctx, frame, a, d, tick, dir)
		local A, D = ctx.cin.attacker, ctx.cin.defender
		local moves = ctx.moveData.Moves
		local color = ctx.characters[A].Energy
		local cx = T.center(ctx, d)
		local F = 470
		local ax = inside(ctx, cx - dir * 2.9)
		frame.grade.ruin = tick >= 190
		a.x, a.facing = ax, dir
		if tick < 200 then
			-- it strikes him with everything; he does not flinch
			a.pose = "Colossus"
			d.x, d.facing = cx, -dir
			local k, age = 1, -99
			for i, b in HIBECARES_THEIRS do
				if tick >= b[1] - 12 then k, age = i, tick - b[1] end
			end
			if age < 12 then
				attack(d, moves, theirMove(ctx, d, HIBECARES_THEIRS[k][2]), age >= 0)
			else
				d.state, d.move = "Idle", nil
			end
			if age == 0 then
				sfx(frame, "tr-hit" .. k, if k == 5 then "heavy" else "slash")
				T.spark(frame, "tr-spark" .. k, v(ax + dir * 0.6, 3.6 + (k % 3) * 0.4, 0.6), if k == 5 then "FFFFFF" else color, 0.5 + 0.12 * k)
				table.insert(frame.fx, { key = "tr-chips" .. k, kind = "debris", pos = v(ax + dir * 0.5, 3.4, 0.4), color = color, scale = 0.4 + 0.08 * k })
			end
			frame.quake = if age >= 0 and age < 4 then 0.1 * k else nil
			if k < 5 or age < 0 then
				frame.shot = frameOn("hibecares-tr-take", dir, { a, d }, { yaw = lerp(-26, -6, progress(tick, 0, 168)), pitch = -14, fill = 0.75, fov = 38,
					focus = P(A, "UpperTorso") })
			else
				-- (the strongest blow, on his chest: nothing)
				-- (over his shoulder: its face as its best blow does nothing)
				frame.shot = frameOn("hibecares-tr-chest", dir, { a, d }, { yaw = -50, pitch = -4, band = "bust", fill = 0.8, fov = 32, focus = P(D, "Head") })
			end
		elseif tick < 270 then
			-- he looks down at it; it backs away
			a.pose = "Colossus"
			local p = progress(tick, 200, 270)
			d.x, d.facing, d.state, d.move = cx + dir * 1.2 * smooth(p), -dir, "Walking", nil
			d.vx = dir * 1.5
			-- (from behind the target, his whole height over it)
			frame.shot = frameOn("hibecares-tr-tower", dir, { a, d }, { yaw = 128, pitch = -18, fill = 0.8, fov = 40, focus = P(A, "Head") })
		elseif tick < 340 then
			-- his stomp: a pillar of ruins rises under it, up to his face
			local dx = cx + dir * 1.2
			d.x, d.facing, d.state = dx, -dir, "Hitstun"
			local up = smooth(progress(tick, 284, 320))
			d.y, d.pose = 5 * up, if up > 0 then "HitBody" else nil
			attack(a, moves, T.role(ctx, "ThunderHeel"), tick >= 280)
			if tick == 282 then
				sfx(frame, "tr-stomp", "boom")
				table.insert(frame.fx, { key = "tr-pillar", kind = "rockLine", from = v(dx, 0, 0), to = v(dx, 5, 0), count = 9, color = color, life = 3.3 })
				table.insert(frame.fx, { key = "tr-stomp-crack", kind = "crack", from = v(ax, 0.05, 0), to = v(dx, 0.05, 0), color = color })
				T.impact(frame, "tr-stomp", v(ax + dir * 0.6, 0.4, 0.6), color, 1.6)
			end
			frame.quake = if tick >= 282 and tick < 292 then 0.5 else nil
			frame.shot = frameOn("hibecares-tr-pillar", dir, { a, d }, { yaw = 10, pitch = -10, fill = 0.7, fov = 42, focus = P(D, "UpperTorso") })
		elseif tick < F then
			-- both fists raised; the stones of the arena rise round them
			local dx = cx + dir * 1.2
			d.x, d.facing, d.y, d.state, d.pose = dx, -dir, 5, "Hitstun", "HitHigh"
			attack(a, moves, T.role(ctx, "Hammer"), false)
			if tick == 352 then
				sfx(frame, "tr-rise", "charge")
				for i = 0, 5 do
					local angle = i * math.pi / 3 + 0.4
					table.insert(frame.fx, { key = "tr-stones" .. i, kind = "rocks", pos = v(dx + math.cos(angle) * 9, 0, math.sin(angle) * 6 - 2),
						radius = 1.6, count = 4, color = color, life = 5 })
				end
			end
			frame.quake = 0.12
			if tick < 420 then
				frame.shot = frameOn("hibecares-tr-ruins", dir, { a, d }, { yaw = -30, pitch = -8, fill = 0.5, fov = 46, focus = P(A, "UpperTorso") })
			else
				frame.shot = frameOn("hibecares-tr-fists", dir, { a, d }, { yaw = 20, pitch = -30, fill = 0.75, fov = 38, focus = P(A, "Head") })
			end
		else
			-- both fists: the pillar shatters, the target driven into the deck; a crown of ruins
			local age = tick - F
			local dx = cx + dir * 1.2
			d.x, d.facing = dx, -dir
			local fall = math.min(1, age / 8)
			if age < 30 then
				d.y, d.state, d.pose = 5 * (1 - fall * fall), "Hitstun", if fall < 1 then "HitHigh" else "DownImpact"
			else
				d.y = 0
				T.FATAL.fall(ctx.cin, d, tick, F + 30, 0)
				if d.pose == "Kneel" then d.pose = "DownFace" end
			end
			if age < 60 then attack(a, moves, T.role(ctx, "Hammer"), true) else a.state, a.move, a.pose = "Idle", nil, "Colossus" end
			if age == 0 then
				sfx(frame, "tr-fists", "heavy")
				frame.impact = { key = "tr-fists", color = "FFFFFF" }
				table.insert(frame.fx, { key = "tr-shatter", kind = "debris", pos = v(dx, 3, 0), color = color, scale = 2 })
			end
			if age == 8 then
				sfx(frame, "tr-crater", "boom")
				T.impact(frame, "tr-crater", v(dx, 0.6, 0.6), color, 3.4)
				for i = 0, 7 do
					local angle = i * math.pi / 4 + 0.2
					table.insert(frame.fx, { key = "tr-web" .. i, kind = "crack", from = v(dx, 0.05, 0),
						to = v(dx + math.cos(angle) * 6, 0.05, math.sin(angle) * 4), color = color })
				end
				table.insert(frame.fx, { key = "tr-crown", kind = "rocks", pos = v(dx, 0, 0), radius = 5, count = 12, color = color, life = 4 })
				table.insert(frame.fx, { key = "tr-dust", kind = "dust", pos = v(dx, 0, 0), direction = dir })
			end
			for i = 0, 1 do
				local r = progress(tick, F + 8 + i * 10, F + 70 + i * 10)
				if r > 0 and r < 1 then
					shape(frame, { kind = "ring", pos = At(v(dx, 0.15, 0)), normal = v(0, 1, 0), radius = lerp(2, 16, smooth(r)), width = 0.45,
						color = if i == 0 then "FFFFFF" else color, alpha = r })
				end
			end
			frame.quake = if age >= 8 and age < 20 then 0.9 else nil
			if age < 50 then
				frame.shot = frameOn("hibecares-tr-crater", dir, { a, d }, { yaw = 10, pitch = lerp(40, 70, smooth(progress(tick, F, F + 50))), fill = 0.5, fov = 44,
					focus = P(D, "UpperTorso") })
			else
				frame.shot = frameOn("hibecares-tr-after", dir, { a, d }, { yaw = -40, pitch = -12, fill = 0.6, fov = 40, focus = P(A, "UpperTorso") })
			end
			ko(ctx, frame, tick, F + 50, color)
		end
	end

	-- ================================================================ RAIJIN · SPEAR OF THE THUNDER GOD
	-- The longest reach and the storm. 0:00 the sky darkens, bolts strike round him, he spins
	-- the spear · 0:01 a thousand thrusts; every third one charges it (his OVERCHARGE: three
	-- rings light round him) · 0:05 the spear lifts the target over his head · 0:06 he raises
	-- it to the sky: the lightning comes down on the spear, through the target · 0:08 the last
	-- thrust: the bolt carries it across the arena into the wall · 0:09 the storm clears.
	local RAIJIN_THRUSTS = { "Jab", "Cross", "Jab", "Kick", "Jab", "Elbow", "Jab", "Cross", "Kick" }
	function S.RAIJIN(ctx, frame, a, d, tick, dir)
		local A, D = ctx.cin.attacker, ctx.cin.defender
		local moves = ctx.moveData.Moves
		local color = ctx.characters[A].Energy
		local cx = T.center(ctx, d)
		local cfg = ctx.config
		local F = 450
		-- (the bolt carries it far: the scene stands back from the wall)
		local room = 22
		local ax = if dir > 0 then math.min(cx - 4.4, cfg.ArenaMaxX - 1 - room) else math.max(cx + 4.4, cfg.ArenaMinX + 1 + room)
		ax = inside(ctx, ax)
		local dx0 = ax + dir * 4.4 -- (at the end of the spear, never inside it)
		local far = inside(ctx, dx0 + dir * 17)
		frame.grade.storm = tick < F + 120
		a.x, a.facing = ax, dir
		d.facing = -dir
		local function bolt(key, x, z)
			table.insert(frame.fx, { key = key, kind = "lightning", from = v(x, 34, z), to = v(x, 0, z), color = color })
		end
		if tick < 80 then
			-- the storm gathers; he spins the spear
			d.x, d.state = dx0, "Hitstun"
			if tick % 12 == 0 then
				bolt("st-bolt" .. tick, ax + math.cos(tick * 1.7) * 9, -4 - math.abs(math.sin(tick)) * 6)
				sfx(frame, "st-thunder" .. tick, "boom")
			end
			if (tick // 16) % 2 == 0 then attack(a, moves, T.role(ctx, "SpinKick"), true) else a.state, a.move, a.pose = "Idle", nil, "StandTall" end
			frame.shot = frameOn("raijin-st-storm", dir, { a }, { yaw = -24, pitch = -20, fill = 0.6, fov = 44, focus = P(A, "UpperTorso") })
		elseif tick < 300 then
			-- a thousand thrusts; every third one charges the spear
			d.x, d.state = dx0, "Hitstun"
			local t = tick - 84
			local k = t // 8 + 1
			local age = t % 8
			local charge = math.min(3, math.max(0, (k - 1) // 9))
			if tick < 84 then
				attack(a, moves, T.role(ctx, "Jab"), false)
			else
				attack(a, moves, T.role(ctx, RAIJIN_THRUSTS[(k - 1) % #RAIJIN_THRUSTS + 1]), age < 5)
				d.pose = if age < 4 then (if k % 2 == 0 then "HitHigh" else "HitBody") else nil
				if age == 1 then
					-- the spear's afterimage: a streak of light through the target
					local y = 3.2 + ((k * 7) % 5 - 2) * 0.25
					table.insert(frame.fx, { key = "st-thrust" .. k, kind = "cut", from = v(ax + dir * 2.2, y, 0.5), to = v(dx0 + dir * 1.8, y + ((k % 3) - 1) * 0.3, 0.5),
						color = if k % 3 == 0 then "FFFFFF" else color })
					if k % 4 == 0 then sfx(frame, "st-stab" .. k, "slash") end
				end
				if age == 1 and k % 9 == 0 then
					sfx(frame, "st-charge" .. k, "charge")
					T.spark(frame, "st-charge" .. k, v(ax, 3.4, 0.6), "FFFFFF", 1.2)
				end
			end
			for i = 1, charge do
				shape(frame, { kind = "ring", pos = At(v(ax, 1.2 + i * 0.9, 0)), normal = v(0, 1, 0), radius = 1.6 + 0.3 * i, width = 0.12, color = color,
					alpha = 0.2 })
			end
			if tick > 160 then frame.speedLines = color end
			local cut = math.min(3, (tick - 80) // 74 + 1)
			local yaws = { 18, -34, 58 }
			frame.shot = frameOn("raijin-st-thrusts" .. cut, dir, { a, d }, { yaw = yaws[cut], pitch = if cut == 2 then 6 else -8, fill = 0.74, fov = 40,
				focus = P(D, "UpperTorso") })
		elseif tick < F then
			-- the spear lifts it over his head; the lightning comes down on it
			local up = smooth(progress(tick, 300, 340))
			d.x, d.state = lerp(dx0, ax + dir * 2.4, up), "Hitstun"
			d.y, d.pose = 4.6 * up, "Launched"
			attack(a, moves, T.role(ctx, "Uppercut"), true)
			for i = 1, 3 do
				shape(frame, { kind = "ring", pos = At(v(ax, 1.2 + i * 0.9, 0)), normal = v(0, 1, 0), radius = 1.6 + 0.3 * i, width = 0.12, color = color,
					alpha = 0.1 })
			end
			local strike = smooth(progress(tick, F - 36, F - 6))
			if strike > 0 then
				shape(frame, { kind = "beam", from = At(v(d.x, 40, 0)), to = At(v(d.x, lerp(40, d.y + 3, strike), 0)), radius = 0.5 + 0.4 * strike,
					color = color, rings = tick / 12 })
				overlay(frame).desat = 0.5 * strike
			end
			if tick == F - 36 then sfx(frame, "st-sky", "beam") end
			if tick < 380 then
				frame.shot = frameOn("raijin-st-lift", dir, { a, d }, { yaw = 40, pitch = -22, fill = 0.7, fov = 40, focus = P(D, "UpperTorso") })
			else
				frame.shot = frameOn("raijin-st-rod", dir, { a, d, { point = true, x = d.x, y = 14, z = 0 } }, { yaw = 24, pitch = -16, fill = 0.7, fov = 46,
					focus = P(D, "UpperTorso") })
			end
		else
			-- the lightning through it; the last thrust: the bolt carries it into the wall
			local age = tick - F
			local from = ax + dir * 2.4
			if age < 24 then
				-- (the bolt holds it up there, lit)
				d.x, d.y, d.state, d.pose = from, 4.6, "Hitstun", if (age // 3) % 2 == 0 then "HitHigh" else "Launched"
				attack(a, moves, T.role(ctx, "Uppercut"), true)
				shape(frame, { kind = "beam", from = At(v(d.x, 40, 0)), to = At(v(d.x, 4.6, 0)), radius = 1.1, color = "FFFFFF", rings = tick / 8 })
				overlay(frame).desat = 0.7
			else
				local q = smooth(math.min(1, progress(tick, F + 24, F + 44)))
				if tick < F + 44 then
					d.x, d.y, d.state, d.pose = lerp(from, far, q), lerp(4.6, 2.6, q), "Hitstun", "Launched"
				else
					d.x = far
					T.FATAL.fall(ctx.cin, d, tick, F + 44, 2.6)
					if d.pose == "Kneel" then d.pose = "DownFace" end
				end
				if tick < F + 100 then attack(a, moves, T.role(ctx, "Finale"), true) else a.state, a.move, a.pose = "Idle", nil, "StandTall" end
				if tick < F + 50 and tick % 2 == 0 then
					-- the thrust becomes a bolt across the arena
					table.insert(frame.fx, { key = "st-arc" .. tick, kind = "lightning", from = v(ax + dir * 1.4, 3.4, 0.4), to = v(d.x, d.y + 3, 0.4), color = color })
				end
				if tick == F + 44 then
					sfx(frame, "st-wall", "heavy")
					T.impact(frame, "st-wall", v(far, 2.6, 0.6), color, 2.6)
				end
			end
			if age == 0 then
				sfx(frame, "st-strike", "boom")
				frame.impact = { key = "st-strike", color = "FFFFFF" }
				bolt("st-down", from, 0.4)
			end
			if age == 24 then sfx(frame, "st-thrust", "beam") end
			frame.quake = if age < 8 or (age >= 24 and age < 34) then 0.6 else nil
			if age < 24 then
				frame.shot = frameOn("raijin-st-lit", dir, { a, d }, { yaw = 20, pitch = -10, fill = 0.7, fov = 44, focus = P(D, "UpperTorso") })
			elseif age < 70 then
				frame.shot = frameOn("raijin-st-bolt", dir, { a, d }, { yaw = 6, pitch = 4, fill = 0.7, fov = 46, focus = P(D, "UpperTorso") })
			else
				frame.shot = frameOn("raijin-st-after", dir, { a }, { yaw = 36, pitch = -6, fill = 0.7, fov = 36, focus = P(A, "UpperTorso") })
			end
			ko(ctx, frame, tick, F + 70, color)
		end
	end



	-- ================================================================ YUKINA · FROZEN REQUIEM
	-- The last waltz of the frost empress. 0:00 the snow falls, her fans open · 0:01 the waltz:
	-- round the target in threes, one-two-three, every third cut a DEEP FREEZE: the ice climbs
	-- it, feet, waist, chest · 0:05 the statue: frozen whole, silence, its face behind the ice ·
	-- 0:06 she turns her back and walks away · 0:07 the fan snaps shut: behind her, the statue
	-- shatters · 0:09 the snow, her bow.
	local YUKINA_CUTS = { "Jab", "Cross", "SpinKick", "Elbow", "Cross", "Kick", "Jab", "SpinKick", "Kick" }
	function S.YUKINA(ctx, frame, a, d, tick, dir)
		local A, D = ctx.cin.attacker, ctx.cin.defender
		local moves = ctx.moveData.Moves
		local color = ctx.characters[A].Energy
		local cx = T.center(ctx, d)
		local F = 460
		local ICE = "BFEFFF"
		frame.grade.frost = true
		d.x, d.facing = cx, -dir
		-- the snow, all along
		if tick < F + 160 then
			shape(frame, { kind = "motes", pos = At(v(cx, 7, 0)), radius = 11, count = 30, color = "FFFFFF", phase = tick / 200 })
		end
		-- the ice that has climbed it so far (DEEP FREEZE: three stacks)
		local stacks = 0
		for i, t in { 150, 210, 270 } do
			if tick >= t then stacks = i end
		end
		if tick < 90 then
			-- the snow falls; her fans open
			a.x, a.z, a.facing, a.pose = cx - dir * 3.4, nil, dir, if tick < 40 then "Sheathe" else "WindGather"
			d.state = "Hitstun"
			if tick == 40 then sfx(frame, "fr-open", "whoosh") end
			frame.shot = frameOn("yukina-fr-snow", dir, { a }, { yaw = lerp(-40, -16, progress(tick, 0, 90)), pitch = 4, fill = 0.75, fov = 36,
				focus = P(A, "Head") })
		elseif tick < 300 then
			-- the waltz: round the target in threes; every third cut, the ice climbs it
			local t = tick - 90
			local beat = t // 20 -- (one, two, three...)
			local age = t % 20
			local angle = (t / 210) * math.pi * 1.6 + 0.2
			circle(a, cx, dir, angle, 3.1, 0)
			local third = beat % 3 == 2
			if age < 8 then
				attack(a, moves, T.role(ctx, YUKINA_CUTS[beat % #YUKINA_CUTS + 1]), age >= 2)
			else
				a.state, a.move, a.vx = "Walking", nil, 1.5
			end
			if age == 3 then
				sfx(frame, "fr-cut" .. beat, if third then "slash" else "whoosh")
				local ux, uz = cx - a.x, -(a.z or 0)
				table.insert(frame.fx, { key = "fr-shard" .. beat, kind = "iceShard", from = v(a.x, 3.6, a.z or 0), to = v(cx + ux * 0.4, 3.2, uz * 0.4),
					color = ICE })
				if third then
					table.insert(frame.fx, { key = "fr-bloom" .. beat, kind = "frostBloom", pos = v(cx, 3.2, 0.6), color = ICE })
				end
			end
			d.pose = if stacks >= 3 then "HitHigh" elseif age < 6 then (if beat % 2 == 0 then "HitBody" else "HitHigh") else nil
			d.hitstop = if stacks >= 3 then 1 else 0
			if t > 0 and tick % 60 == 30 then table.insert(frame.fx, { key = "fr-ice" .. tick, kind = "iceGarden", pos = v(cx, 0, 0), radius = 1.2,
				count = 2 + stacks * 2, color = ICE, life = 6 }) end
			for i = 1, stacks do
				shape(frame, { kind = "ring", pos = At(v(cx, 0.4 + (i - 1) * 1.6, 0)), normal = v(0, 1, 0), radius = 1.3, width = 0.18, color = ICE, alpha = 0.3 })
			end
			-- (the camera waltzes with her: it turns as she turns, always three quarters on the pair)
			frame.shot = frameOn("yukina-fr-waltz", dir, { a, d }, { yaw = 30 - math.deg(angle), pitch = 20, fill = 0.7, fov = 40,
				roll = 4 * math.sin(tick / 40), focus = P(D, "UpperTorso") })
		elseif tick < 380 then
			-- the statue: frozen whole; silence; its face behind the ice
			a.x, a.z, a.facing, a.state, a.move, a.pose = cx - dir * 2.6, -1.6, dir, "Idle", nil, "WindGather"
			d.state, d.pose, d.hitstop = "Hitstun", "HitHigh", 1
			overlay(frame).desat = 0.3
			shape(frame, { kind = "dome", pos = At(v(cx, 2.4, 0)), radius = 2.6, color = ICE, alpha = 0.45 })
			if tick == 300 then sfx(frame, "fr-freeze", "charge") end
			if tick < 340 then
				local q = smooth(progress(tick, 300, 340))
				frame.shot = shot("yukina-fr-face", P(D, "Head", v(-dir * lerp(3.4, 2.8, q), 0.3, lerp(4.4, 3.8, q))), P(D, "Head"), 34, 0, P(D, "Head"))
				frame.shot.close = true
			else
				frame.shot = frameOn("yukina-fr-statue", dir, { a, d }, { yaw = 40, pitch = 8, fill = 0.65, fov = 38, focus = P(D, "UpperTorso") })
			end
		elseif tick < F then
			-- she turns her back and walks away; the fan snaps shut
			local p = progress(tick, 380, 440)
			d.state, d.pose, d.hitstop = "Hitstun", "HitHigh", 1
			overlay(frame).desat = 0.3
			shape(frame, { kind = "dome", pos = At(v(cx, 2.4, 0)), radius = 2.6, color = ICE, alpha = 0.45 })
			a.z, a.facing, a.lookDir = -1.6 * (1 - p), -dir, nil
			if tick < 440 then
				a.x, a.state, a.move, a.vx = cx - dir * lerp(2.6, 6.2, p), "Walking", nil, -dir * 2
			else
				a.x, a.state, a.move, a.pose = cx - dir * 6.2, "Idle", nil, "Sheathe"
			end
			-- (her back in front, the statue behind her)
			frame.shot = frameOn("yukina-fr-away", dir, { a, d }, { yaw = -24, pitch = 4, fill = 0.7, fov = 36, focus = P(A, "Head") })
		else
			-- behind her, the statue shatters; the snow; her bow
			local age = tick - F
			a.x, a.z, a.facing, a.lookDir = cx - dir * 6.2, nil, -dir, nil
			a.state, a.move, a.pose = "Idle", nil, if age < 90 then "Sheathe" else "WindGather"
			d.hitstop = 0
			T.FATAL.fall(ctx.cin, d, tick, F + 8, 0)
			if d.pose == "Kneel" then d.pose = "DownFace" end
			if age == 0 then
				sfx(frame, "fr-snap", "slash")
				sfx(frame, "fr-shatter", "boom")
				frame.impact = { key = "fr-shatter", color = "FFFFFF" }
				table.insert(frame.fx, { key = "fr-shards", kind = "debris", pos = v(cx, 2.6, 0), color = ICE, scale = 2 })
				for i = 0, 5 do
					local angle = i * math.pi / 3 + 0.3
					table.insert(frame.fx, { key = "fr-fly" .. i, kind = "iceShard", from = v(cx, 2.6, 0),
						to = v(cx + math.cos(angle) * 6, 2.6 + math.sin(angle) * 3, math.sin(angle * 2) * 3), color = ICE })
				end
			end
			if age < 30 then
				local q = age / 30
				shape(frame, { kind = "sphere", pos = At(v(cx, 2.6, 0)), radius = lerp(2.6, 4.4, q), color = ICE, core = 1 - q })
				shape(frame, { kind = "ring", pos = At(v(cx, 0.2, 0)), normal = v(0, 1, 0), radius = lerp(2, 12, smooth(q)), width = 0.3, color = ICE, alpha = q })
			end
			if age < 50 then
				frame.shot = frameOn("yukina-fr-shatter", dir, { a, d }, { yaw = -24, pitch = 4, fill = 0.7, fov = 36, focus = P(A, "Head") })
			else
				frame.shot = frameOn("yukina-fr-after", dir, { a, d }, { yaw = 30, pitch = 6, fill = 0.55, fov = 38, focus = P(A, "UpperTorso") })
			end
			ko(ctx, frame, tick, F + 40, color)
		end
	end

	-- ================================================================ VENOM · TOXIC FEAST
	-- The predator and its prey. 0:00 the mist rises, he sinks into it · 0:01 low over his
	-- shoulder: he prowls behind the prey in the mist · 0:02 three strikes out of the mist, each one a dose
	-- of poison (CONTAMINATION), the prey's sight swims · 0:05 the poison takes it: it falls to
	-- one knee; he circles closer · 0:07 the pounce from above · 0:08 the green burst blows the
	-- mist away: he crouches over it.
	local VENOM_STRIKES = { { 150, "Elbow", 1.2 }, { 200, "SpinKick", 3.1 }, { 250, "Uppercut", 5.0 } }
	function S.VENOM(ctx, frame, a, d, tick, dir)
		local A, D = ctx.cin.attacker, ctx.cin.defender
		local moves = ctx.moveData.Moves
		local color = ctx.characters[A].Energy
		local cx = T.center(ctx, d)
		local F = 450
		frame.grade.toxic = true
		d.x = cx
		local doses = 0
		for i, s_ in VENOM_STRIKES do
			if tick >= s_[1] + 2 then doses = i end
		end
		-- the mist
		if tick < F and tick % 18 == 0 then
			table.insert(frame.fx, { key = "tf-mist" .. tick, kind = "smoke", pos = v(cx + math.cos(tick) * 4, 0.8, math.sin(tick * 0.7) * 3) })
		end
		-- the poison in the prey: its green motes, more with every dose
		if doses > 0 and tick < F + 20 then
			shape(frame, { kind = "motes", pos = P(D, "UpperTorso"), radius = 1.2 + 0.3 * doses, count = 6 * doses, color = color, phase = tick / 30 })
		end
		if tick < 60 then
			-- the mist rises; he sinks into it
			a.x, a.z, a.facing = cx - dir * 4, nil, dir
			a.pose = "Roar"
			d.state, d.facing = "Idle", -dir
			frame.shot = frameOn("venom-tf-mist", dir, { a }, { yaw = -40, pitch = -6, band = "bust", fill = 0.85, fov = 32, focus = P(A, "Head") })
		elseif tick < 300 then
			-- through his eyes he circles it; three strikes out of the mist
			local striking, after = nil, nil
			for i, s_ in VENOM_STRIKES do
				if tick >= s_[1] - 6 and tick < s_[1] + 14 then striking = i end
				if tick >= s_[1] + 14 and tick < s_[1] + 26 then after = i end
			end
			d.state = "Hitstun"
			d.facing = -dir
			if striking then
				local s_ = VENOM_STRIKES[striking]
				local age = tick - s_[1]
				circle(a, cx, dir, s_[3], 2.8, 0)
				attack(a, moves, T.role(ctx, s_[2]), age >= 0)
				if age == 0 then
					sfx(frame, "tf-claw" .. striking, "slash")
					local ux, uz = cx - a.x, -(a.z or 0)
					local l = math.max(1e-3, math.sqrt(ux * ux + uz * uz))
					ux, uz = ux / l, uz / l
					table.insert(frame.fx, { key = "tf-rend" .. striking, kind = "venomClaw", from = v(cx - ux * 1.4 - uz, 4.4, -uz * 1.4 + ux),
						to = v(cx + ux * 1.4 + uz, 2.4, uz * 1.4 - ux), color = color })
					T.spark(frame, "tf-dose" .. striking, v(cx, 3.4, 0.4), color, 1)
				end
				d.pose = if age >= 0 and age < 10 then (if striking % 2 == 0 then "HitBody" else "HitHigh") else nil
				if age >= 0 then overlay(frame).blur = 0.3 * math.exp(-age / 6) end
				local yaws = { 34, -40, 60 }
				frame.shot = frameOn("venom-tf-strike" .. striking, dir, { a, d }, { yaw = yaws[striking], pitch = 6, fill = 0.75, fov = 40,
					focus = P(D, "UpperTorso") })
			else
				-- (between strikes he is only eyes in the mist, circling low)
				-- (he prowls back and forth behind it, on a half ellipse that the walls never squeeze
				-- onto the prey)
				local cfg = ctx.config
				local rx = math.clamp(math.min(cfg.ArenaMaxX - 1 - cx, cx - cfg.ArenaMinX - 1), 0, 7)
				local sweep = 0.5 - 0.5 * math.cos((tick - 60) / 120 * math.pi)
				local angle = math.pi * (0.15 + 0.7 * sweep)
				a.x, a.z = cx - dir * math.cos(angle) * rx, -math.sin(angle) * 7.5
				local lx, lz = cx - a.x, -a.z
				local l = math.max(1e-3, math.sqrt(lx * lx + lz * lz))
				a.lookDir, a.facing = v(lx / l, 0, lz / l), if lx >= 0 then 1 else -1
				a.state, a.move, a.vx = "Walking", nil, 2
				local sway = math.sin(tick / 7) * 0.12
				local look = a.lookDir
				-- (over his shoulder: his silhouette at the edge of the mist, the prey in the middle)
				-- (hung on his body as drawn, which catches up when he slips back into the mist)
				frame.shot = shot("venom-tf-prowl", P(A, "UpperTorso", v(-look.x * 3.6 - look.z * 2.6, 0.6 + sway, -look.z * 3.6 + look.x * 2.6)),
					P(D, "UpperTorso", v(0, -0.4, 0)), 50, math.rad(4 * math.sin(tick / 11)), P(D, "UpperTorso"))
				if doses > 0 then overlay(frame).blur = 0.15 * doses * (0.5 + 0.5 * math.sin(tick / 9)) end
				if after then
					-- (he slips back into the mist: the strike's shot holds while he goes)
					local yaws = { 34, -40, 60 }
					frame.shot = frameOn("venom-tf-strike" .. after, dir, { a, d }, { yaw = yaws[after], pitch = 6, fill = 0.75, fov = 40,
						focus = P(D, "UpperTorso") })
				end
			end
		elseif tick < 400 then
			-- the poison takes it: one knee down; he circles closer, in the open
			d.state, d.pose, d.facing = "Hitstun", "Kneel", -dir
			local angle = (tick - 300) / 100 * math.pi * 0.9 + 0.5
			circle(a, cx, dir, angle, lerp(4.6, 3.4, progress(tick, 300, 400)), 0)
			a.state, a.move, a.vx = "Walking", nil, 1.2
			overlay(frame).blur = 0.25 * (0.5 + 0.5 * math.sin(tick / 9))
			frame.shot = frameOn("venom-tf-kneel", dir, { a, d }, { yaw = lerp(-20, 20, progress(tick, 300, 400)), pitch = 18, fill = 0.7, fov = 40,
				focus = P(D, "Head") })
		elseif tick < F then
			-- the pounce from above
			local q = progress(tick, 400, F)
			d.state, d.pose, d.facing = "Hitstun", "Kneel", -dir
			a.z, a.lookDir, a.facing = nil, nil, dir
			a.x = lerp(cx - dir * 4.2, cx - dir * 1.2, q)
			a.y = 7 * math.sin(q * math.pi * 0.85)
			attack(a, moves, T.role(ctx, "AirSmash"), q > 0.7)
			if tick == 400 then sfx(frame, "tf-leap", "whoosh") end
			frame.shot = frameOn("venom-tf-pounce", dir, { a, d }, { yaw = 40, pitch = -24, fill = 0.75, fov = 42, focus = P(A, "UpperTorso") })
		else
			-- the green burst blows the mist away; he crouches over it
			local age = tick - F
			a.x, a.y, a.z, a.facing = cx - dir * 1.2, 0, nil, dir
			if age < 30 then attack(a, moves, T.role(ctx, "AirSmash"), true) else a.state, a.move, a.pose = "Idle", nil, if age < 110 then "Roar" else nil end
			d.y = 0
			T.FATAL.fall(ctx.cin, d, tick, F + 4, 0)
			if d.pose == "Kneel" then d.pose = "DownFace" end
			if age == 0 then
				sfx(frame, "tf-feast", "boom")
				T.impact(frame, "tf-feast", v(cx, 1.4, 0.6), color, 3)
				table.insert(frame.fx, { key = "tf-cloud", kind = "venomCloud", pos = v(cx, 1, 0), color = color })
			end
			for i = 0, 1 do
				local r = progress(tick, F + i * 8, F + 60 + i * 8)
				if r > 0 and r < 1 then
					shape(frame, { kind = "ring", pos = At(v(cx, 0.4 + i * 1.2, 0)), normal = v(0, 1, 0), radius = lerp(2, 15, smooth(r)), width = 0.35,
						color = color, alpha = r })
				end
			end
			if age < 60 then
				shape(frame, { kind = "motes", pos = At(v(cx, 1.5, 0)), radius = 7, count = 24, color = color, phase = age / 40, out = true })
			end
			if age < 50 then
				frame.shot = frameOn("venom-tf-burst", dir, { a, d }, { yaw = 26, pitch = 12, fill = 0.6, fov = 42, focus = P(D, "UpperTorso") })
			else
				frame.shot = frameOn("venom-tf-after", dir, { a, d }, { yaw = -30, pitch = -6, fill = 0.65, fov = 38, focus = P(A, "Head") })
			end
			ko(ctx, frame, tick, F + 40, color)
		end
	end

	-- ================================================================ GORAN · TITAN QUAKE
	-- The titan's weight. 0:00 three hammer blows on the deck: the whole ring jumps, the target
	-- bounces higher each time · 0:03 he catches it over his head · 0:04 the airplane spin,
	-- faster and faster, the dust whirling round his feet · 0:06 he leaps · 0:07 he brings it
	-- down into the deck: the ring jumps one last time · 0:09 he stands in the dust.
	function S.GORAN(ctx, frame, a, d, tick, dir)
		local A, D = ctx.cin.attacker, ctx.cin.defender
		local moves = ctx.moveData.Moves
		local color = ctx.characters[A].Energy
		local cx = T.center(ctx, d)
		local cfg = ctx.config
		local F = 470
		-- (the leap needs room: the scene starts back from the wall)
		local room = 8
		local ax0 = if dir > 0 then math.min(cx - 2.6, cfg.ArenaMaxX - 1 - room) else math.max(cx + 2.6, cfg.ArenaMinX + 1 + room)
		ax0 = inside(ctx, ax0)
		local dx0 = ax0 + dir * 2.6
		local runTo = inside(ctx, ax0 + dir * 3)
		frame.grade.titan = true
		local stomps = { 30, 70, 110 }
		if tick < 140 then
			-- three hammer blows on the deck: the ring jumps; the target bounces higher each time
			a.x, a.facing = ax0, dir
			d.x, d.facing, d.state = dx0, -dir, "Hitstun"
			local k, age = 0, 99
			for i, t in stomps do
				if tick >= t - 10 then k, age = i, tick - t end
			end
			if k > 0 and age < 12 then
				attack(a, moves, T.role(ctx, "Hammer"), age >= 0)
			else
				a.state, a.move, a.pose = "Idle", nil, "Colossus"
			end
			if k > 0 and age >= 0 then
				local h = ({ 0.8, 1.6, 3.2 })[k]
				local up = math.max(0, math.sin(math.min(1, age / 30) * math.pi))
				d.y, d.pose = h * up, if up > 0.05 then "Launched" else nil
				if k == 3 and age >= 15 then d.y = h end
			end
			if k > 0 and age == 0 then
				sfx(frame, "tq-stomp" .. k, "boom")
				table.insert(frame.fx, { key = "tq-quake" .. k, kind = "slamQuake", pos = v(ax0, 0, 0), color = color, scale = 0.6 + 0.3 * k })
				table.insert(frame.fx, { key = "tq-ring" .. k, kind = "titanRing", pos = v(ax0, 0, 0), color = color })
			end
			frame.quake = if k > 0 and age >= 0 and age < 8 then 0.3 * k else nil
			-- (very low, at his feet)
			frame.shot = frameOn("goran-tq-pound", dir, { a, d }, { yaw = -10, pitch = -20, fill = 0.75, fov = 40, focus = P(A, "UpperTorso") })
		elseif tick < 240 then
			-- he catches it over his head
			local q = smooth(progress(tick, 140, 170))
			a.x, a.facing = ax0, dir
			d.x, d.facing, d.state, d.pose = lerp(dx0, ax0 + dir * 0.3, q), -dir, "Hitstun", "Launched"
			d.y = lerp(3.2, 5.6, q)
			attack(a, moves, T.role(ctx, "Hammer"), false)
			if tick == 170 then sfx(frame, "tq-catch", "heavy") end
			frame.shot = frameOn("goran-tq-catch", dir, { a, d }, { yaw = 30, pitch = -20, fill = 0.62, fov = 40, focus = P(A, "Head") })
		elseif tick < 380 then
			-- the airplane spin, faster and faster; the dust whirls round his feet
			local q = progress(tick, 240, 380)
			local turn = math.pi * 2 * 2.5 * q * q
			local fx, fz = math.cos(turn) * dir, math.sin(turn)
			a.x, a.lookDir, a.facing = ax0, v(fx, 0, fz), if fx >= 0 then 1 else -1
			attack(a, moves, T.role(ctx, "Hammer"), false)
			d.x, d.z, d.y = ax0 + fx * 0.3, fz * 0.3, 5.6
			d.lookDir, d.facing, d.state, d.pose = v(-fz, 0, fx), if -fz >= 0 then 1 else -1, "Hitstun", "Launched"
			shape(frame, { kind = "motes", pos = At(v(ax0, 0.6, 0)), radius = 3.2, count = 22, color = color, phase = tick / 12, out = true })
			if tick % 20 == 0 then sfx(frame, "tq-spin" .. tick, "whoosh") end
			if q > 0.4 then frame.speedLines = color end
			frame.shot = frameOn("goran-tq-spin", dir, { a, d }, { yaw = 16, pitch = -12, fill = 0.62, fov = 42, focus = P(A, "Head") })
		elseif tick < F then
			-- he leaps; he brings it down
			local q = progress(tick, 380, F)
			local arc = math.sin(q * math.pi)
			a.x, a.facing = lerp(ax0, runTo, q), dir
			a.y = 6 * arc
			d.z, d.lookDir = nil, nil
			d.x, d.facing, d.state, d.pose = a.x + dir * lerp(0.3, 1.8, q), -dir, "Hitstun", "Launched"
			d.y = a.y + lerp(5.6, 2, q * q)
			attack(a, moves, T.role(ctx, "Hammer"), q > 0.6)
			if tick == 380 then sfx(frame, "tq-leap", "whoosh") end
			frame.shot = frameOn("goran-tq-leap", dir, { a, d }, { yaw = 20, pitch = -34, fill = 0.6, fov = 44, focus = P(A, "Head") })
		else
			-- the ring jumps one last time; he stands in the dust
			local age = tick - F
			a.x, a.y, a.facing = runTo, 0, dir
			if age < 50 then attack(a, moves, T.role(ctx, "Hammer"), true) else a.state, a.move, a.pose = "Idle", nil, "Colossus" end
			d.x, d.facing = runTo + dir * 1.8, -dir
			d.y = 0
			if age < 26 then d.state, d.pose = "Hitstun", "DownImpact" else
				T.FATAL.fall(ctx.cin, d, tick, F + 26, 0)
				if d.pose == "Kneel" then d.pose = "DownFace" end
			end
			if age == 0 then
				sfx(frame, "tq-slam", "boom")
				frame.impact = { key = "tq-slam", color = "FFFFFF" }
				T.impact(frame, "tq-slam", v(d.x, 0.8, 0.6), color, 3.4)
				table.insert(frame.fx, { key = "tq-quakeF", kind = "slamQuake", pos = v(d.x, 0, 0), color = color, scale = 2 })
				table.insert(frame.fx, { key = "tq-ringF", kind = "titanRing", pos = v(d.x, 0, 0), color = color })
				for i = 0, 7 do
					local angle = i * math.pi / 4 + 0.3
					table.insert(frame.fx, { key = "tq-web" .. i, kind = "crack", from = v(d.x, 0.05, 0),
						to = v(d.x + math.cos(angle) * 7, 0.05, math.sin(angle) * 4), color = color })
				end
				table.insert(frame.fx, { key = "tq-dust", kind = "dust", pos = v(d.x, 0, 0), direction = dir })
			end
			for i = 0, 2 do
				local r = progress(tick, F + i * 6, F + 60 + i * 6)
				if r > 0 and r < 1 then
					shape(frame, { kind = "ring", pos = At(v(d.x, 0.15, 0)), normal = v(0, 1, 0), radius = lerp(2, 20, smooth(r)), width = 0.45,
						color = if i == 1 then "FFFFFF" else color, alpha = r })
				end
			end
			frame.quake = if age < 14 then 1 else nil
			if age < 46 then
				frame.shot = frameOn("goran-tq-slam", dir, { a, d }, { yaw = 30, pitch = 22, fill = 0.55, fov = 44, focus = P(D, "UpperTorso") })
			else
				frame.shot = frameOn("goran-tq-after", dir, { a, d }, { yaw = -34, pitch = -14, fill = 0.65, fov = 38, focus = P(A, "Head") })
			end
			ko(ctx, frame, tick, F + 46, color)
		end
	end


	-- ================================================================ ASTER · STELLAR COLLAPSE
	-- The master of gravity lets go of it. 0:00 he lifts a hand: gravity is gone, the target, the
	-- dust and the camera float · 0:02 he floats up to it and strikes it in the air, every blow
	-- heavier (SHIFTING MASS) · 0:05 he makes a star; the target falls into its orbit · 0:06 he
	-- closes his hand: the star collapses, the orbit with it · 0:07 the star bursts; gravity
	-- comes back all at once: the target falls into the deck · 0:09 he floats down.
	local ASTER_BLOWS = { { 140, "AirKick" }, { 172, "AirKick2" }, { 204, "AirKick" }, { 236, "AirSmash" }, { 268, "AirKick2" } }
	function S.ASTER(ctx, frame, a, d, tick, dir)
		local A, D = ctx.cin.attacker, ctx.cin.defender
		local moves = ctx.moveData.Moves
		local color = ctx.characters[A].Energy
		local cx = T.center(ctx, d)
		local F = 450
		local star = v(cx, 13, -2)
		frame.grade.cosmos = true
		d.facing = -dir
		-- (the floating dust while gravity is gone)
		if tick < F then
			shape(frame, { kind = "motes", pos = At(v(cx, 3 + tick / 60, 0)), radius = 8, count = 24, color = "FFFFFF", phase = tick / 300 })
		end
		if tick < 120 then
			-- gravity is gone: the target floats, turning slowly
			local p = progress(tick, 20, 120)
			a.x, a.facing, a.pose = cx - dir * 3.4, dir, if tick < 20 then nil else "Levitate"
			d.x, d.y, d.state, d.pose = cx, 3 * smooth(p), "Hitstun", if p > 0 then "Launched" else nil
			local turn = p * 1.4
			d.lookDir = v(-dir * math.cos(turn), 0, math.sin(turn))
			if tick == 20 then
				sfx(frame, "sc-zero", "charge")
				table.insert(frame.fx, { key = "sc-well", kind = "gravityWell", pos = v(a.x, 2.5, 0), radius = 2, count = 5, color = color, life = 2.5 })
			end
			-- (the weightless camera drifts and rolls)
			frame.shot = frameOn("aster-sc-zero", dir, { a, d }, { yaw = lerp(-50, -20, p), pitch = -6, fill = 0.68, fov = 40, roll = 8 * math.sin(tick / 40),
				focus = P(D, "UpperTorso") })
		elseif tick < 300 then
			-- he floats up to it and strikes it, every blow heavier
			local lift = 3 + 4 * smooth(progress(tick, 120, 300))
			local k, age = 0, 99
			for i, b in ASTER_BLOWS do
				if tick >= b[1] - 8 then k, age = i, tick - b[1] end
			end
			local drift = 0.25 * math.max(0, k - 1) + (if k > 0 and age >= 0 then 0.25 * smooth(math.min(1, age / 14)) else 0)
			d.x, d.y, d.state = cx + dir * drift, lift, "Hitstun"
			d.pose = if k > 0 and age >= 0 and age < 10 then (if k % 2 == 0 then "HitBody" else "HitHigh") else "Launched"
			local turn = 1.4 + (tick - 120) / 60
			d.lookDir = v(-dir * math.cos(turn), 0, math.sin(turn))
			a.x, a.y, a.facing = d.x - dir * 2.8, lift - 0.4, dir
			if k > 0 and age < 12 then
				attack(a, moves, T.role(ctx, ASTER_BLOWS[k][2]), age >= 0)
			else
				a.state, a.move, a.pose = "Jumping", nil, "Levitate"
			end
			if k > 0 and age == 0 then
				sfx(frame, "sc-blow" .. k, "heavy")
				T.spark(frame, "sc-spark" .. k, v(d.x - dir * 0.4, d.y + 3.4, 0.4), if k == 5 then "FFFFFF" else color, 0.6 + 0.15 * k)
			end
			-- (SHIFTING MASS: a ring round his fist grows with every blow landed)
			if k > 0 then
				shape(frame, { kind = "ring", pos = P(A, "RightHand"), normal = v(dir, 0, 0), radius = 0.3 + 0.12 * k, width = 0.08, color = color, alpha = 0.3 })
			end
			local yaws = { 30, -50, 50, -40, 40 }
			frame.shot = frameOn("aster-sc-air" .. math.max(1, k), dir, { a, d }, { yaw = yaws[math.max(1, k)], pitch = -10, fill = 0.72, fov = 40,
				roll = 6 * math.sin(tick / 30), focus = P(D, "UpperTorso") })
		elseif tick < F then
			-- the star; the target falls into its orbit; it collapses
			local born = smooth(progress(tick, 300, 330))
			local collapse = smooth(progress(tick, 390, F))
			local radius = 0.4 + 2.6 * born - 2.7 * collapse
			shape(frame, { kind = "sphere", pos = At(star), radius = math.max(0.25, radius), color = if collapse > 0.5 then "2A1838" else color,
				core = 1 - collapse })
			local orbit = 5 * (1 - collapse) + 0.8
			local angle = (tick - 300) / 22
			d.x, d.y, d.z = star.x + math.cos(angle) * orbit, star.y + math.sin(angle) * orbit * 0.4 - 2, star.z + math.sin(angle) * orbit
			d.state, d.pose = "Hitstun", "Launched"
			d.lookDir = v(-math.sin(angle), 0, math.cos(angle))
			a.x, a.y, a.facing, a.state, a.move, a.pose = cx - dir * 4, 6, dir, "Jumping", nil, "Levitate"
			for i = 0, 2 do
				local r = (((tick - 300) / 40 + i / 3) % 1)
				shape(frame, { kind = "ring", pos = At(star), normal = v(0.2, 1, 0.3), radius = if collapse > 0 then lerp(7, 0.5, r) else lerp(0.5, 7, r),
					width = 0.12, color = color, alpha = r })
			end
			if tick == 300 then sfx(frame, "sc-star", "charge") end
			if tick == 390 then sfx(frame, "sc-close", "whoosh") end
			if tick < 390 then
				frame.shot = frameOn("aster-sc-orbit", dir, { a, d, { point = true, x = star.x, y = star.y, z = star.z } }, { yaw = 24, pitch = -14, fill = 0.6,
					fov = 46, focus = P(D, "UpperTorso") })
			else
				frame.shot = frameOn("aster-sc-collapse", dir, { a, d, { point = true, x = star.x, y = star.y, z = star.z } }, { yaw = -20, pitch = -20, fill = 0.7,
					fov = 44, focus = P(D, "UpperTorso") })
			end
		else
			-- the star bursts; gravity comes back: the target falls into the deck; he floats down
			local age = tick - F
			local fall = math.min(1, age / 30)
			if age < 30 then
				d.x, d.y, d.z = lerp(star.x, cx, fall), lerp(star.y - 1, 0, fall * fall), lerp(star.z, 0, fall)
				d.state, d.pose, d.lookDir = "Hitstun", "Launched", nil
			else
				d.x, d.y, d.z, d.lookDir = cx, 0, nil, nil
				T.FATAL.fall(ctx.cin, d, tick, F + 30, 0)
				if d.pose == "Kneel" then d.pose = "DownFace" end
			end
			a.x, a.facing = cx - dir * 4, dir
			a.y = lerp(6, 0, smooth(progress(tick, F + 20, F + 90)))
			a.state, a.move, a.pose = if a.y > 0.2 then "Jumping" else "Idle", nil, if a.y > 0.2 then "Levitate" else "StandTall"
			if age < 40 then
				local q = age / 40
				shape(frame, { kind = "sphere", pos = At(star), radius = lerp(0.5, 7, smooth(q)), color = "FFFFFF", core = 1 - q })
				shape(frame, { kind = "ring", pos = At(star), normal = v(0, 1, 0), radius = lerp(1, 18, smooth(q)), width = 0.4, color = color, alpha = q })
			end
			if age == 0 then
				sfx(frame, "sc-nova", "boom")
				frame.impact = { key = "sc-nova", color = "FFFFFF" }
			end
			if age == 30 then
				sfx(frame, "sc-crash", "heavy")
				T.impact(frame, "sc-crash", v(cx, 1, 0.6), color, 3)
				table.insert(frame.fx, { key = "sc-debris", kind = "debris", pos = v(cx, 0.5, 0), color = color, scale = 1.6 })
				table.insert(frame.fx, { key = "sc-dust", kind = "dust", pos = v(cx, 0, 0), direction = dir })
			end
			frame.quake = if age >= 30 and age < 40 then 0.8 else nil
			if age < 30 then
				frame.shot = frameOn("aster-sc-nova", dir, { d, { point = true, x = cx, y = 0, z = 0 } }, { yaw = 20, pitch = -6, fill = 0.6, fov = 48,
					focus = P(D, "UpperTorso") })
			elseif age < 70 then
				frame.shot = frameOn("aster-sc-crash", dir, { d }, { yaw = 28, pitch = 20, fill = 0.5, fov = 42, focus = P(D, "UpperTorso") })
			else
				frame.shot = frameOn("aster-sc-after", dir, { a, d }, { yaw = 20, pitch = -4, fill = 0.6, fov = 38, focus = P(A, "UpperTorso") })
			end
			ko(ctx, frame, tick, F + 50, color)
		end
	end

	-- ================================================================ HIBIKI · RESONANCE
	-- She finds the target's own note. 0:00 one clap, the target goes still, humming · 0:01 her
	-- palms on a four-beat bar: every beat a ring of sound travels into it, it shakes harder ·
	-- 0:05 it resonates: the rings stand round it, the world warps (the lens and the distance
	-- trade places) · 0:07 she raises both palms: one beat of silence · 0:07 the last clap: it is
	-- blown across the ring · 0:09 the echo dies.
	local HIBIKI_BEATS = { "Jab", "Cross", "PalmStrike", "Jab", "Cross", "PalmStrike", "Elbow", "PalmStrike" }
	function S.HIBIKI(ctx, frame, a, d, tick, dir)
		local A, D = ctx.cin.attacker, ctx.cin.defender
		local moves = ctx.moveData.Moves
		local color = ctx.characters[A].Energy
		local cx = T.center(ctx, d)
		local cfg = ctx.config
		local F = 440
		local room = 16
		local ax = if dir > 0 then math.min(cx - 3.2, cfg.ArenaMaxX - 1 - room) else math.max(cx + 3.2, cfg.ArenaMinX + 1 + room)
		ax = inside(ctx, ax)
		local dx0 = ax + dir * 3.2
		local far = inside(ctx, dx0 + dir * 14)
		frame.grade.sonic = true
		a.x, a.facing = ax, dir
		d.facing = -dir
		-- the beats: one bar of four, then faster
		local beats = {}
		local b = 70
		while b < 300 do
			table.insert(beats, b)
			b += if b < 190 then 30 else 20
		end
		local index, age = 0, 99
		for i, t in beats do
			if tick >= t then index, age = i, tick - t end
		end
		-- the hum: it shakes harder with every beat
		local amp = math.min(0.3, 0.035 * index) * (if tick < F then 1 else 0)
		local function hum()
			d.x = dx0 + amp * math.sin(tick * 2.3)
			d.z = amp * math.cos(tick * 3.1)
		end
		local function ring(i, t0)
			-- a ring of sound travelling from her palms into the target
			local q = (tick - t0) / 12
			if q >= 0 and q < 1 then
				shape(frame, { kind = "ring", pos = At(v(lerp(ax + dir * 1.2, dx0, q), 3.4, 0)), normal = v(dir, 0, 0), radius = lerp(0.6, 1.8, q),
					width = 0.14, color = if i % 4 == 0 then "FFFFFF" else color, alpha = q })
			end
		end
		if tick < 70 then
			-- one clap; the target goes still
			a.pose = if tick < 30 then nil else "GloveTap"
			d.x, d.state = dx0, "Hitstun"
			if tick == 30 then
				sfx(frame, "rs-clap", "heavy")
				table.insert(frame.fx, { key = "rs-clap", kind = "beatRing", pos = v(ax, 0, 0), color = color })
			end
			frame.shot = frameOn("hibiki-rs-clap", dir, { a, d }, { yaw = 24, pitch = -4, band = "bust", fill = 0.8, fov = 32, focus = P(A, "Head") })
		elseif tick < 300 then
			-- her palms on the beat; every beat a ring of sound into it
			d.state = "Hitstun"
			hum()
			d.pose = if age < 5 then (if index % 2 == 0 then "HitBody" else "HitHigh") else nil
			if age < 8 then
				attack(a, moves, T.role(ctx, HIBIKI_BEATS[(index - 1) % #HIBIKI_BEATS + 1]), age >= 0)
			else
				attack(a, moves, T.role(ctx, HIBIKI_BEATS[index % #HIBIKI_BEATS + 1]), false)
			end
			for i, t in beats do ring(i, t) end
			if age == 0 then sfx(frame, "rs-beat" .. index, if index % 4 == 0 then "heavy" else "whoosh") end
			frame.quake = if age < 3 then 0.08 + 0.02 * index else nil
			local cut = math.min(3, index // 4 + 1)
			local yaws = { 60, -15, 10 }
			frame.shot = frameOn("hibiki-rs-bar" .. cut, dir, { a, d }, { yaw = yaws[cut], pitch = -16, fill = 0.72, fov = 40, focus = P(D, "UpperTorso") })
		elseif tick < F then
			-- it resonates; the world warps; then one beat of silence
			d.state, d.pose = "Hitstun", "HitHigh"
			if tick < 410 then hum() else d.x, d.z = dx0, nil end
			attack(a, moves, T.role(ctx, "Finale"), false)
			for i = 0, 2 do
				local r = (((tick - 300) / 30 + i / 3) % 1)
				shape(frame, { kind = "ring", pos = At(v(dx0, 3.2, 0)), normal = v(0, 1, 0), radius = 0.8 + 1.6 * r, width = 0.12, color = color, alpha = r })
			end
			if tick < 380 then
				-- (the dolly zoom: the lens widens while the camera closes in, the subject the same size)
				local q = smooth(progress(tick, 300, 380))
				frame.shot = frameOn("hibiki-rs-warp", dir, { d }, { yaw = 30, pitch = -2, fill = 0.55, fov = lerp(22, 74, q), focus = P(D, "UpperTorso") })
			else
				overlay(frame).desat = smooth(progress(tick, 410, 420)) * 0.8
				frame.shot = frameOn("hibiki-rs-palms", dir, { a, d }, { yaw = -6, pitch = -6, band = "bust", fill = 0.82, fov = 30, focus = P(A, "Head") })
			end
			if tick == 300 then sfx(frame, "rs-hum", "charge") end
		else
			-- the last clap: it is blown across the ring; the echo
			local age2 = tick - F
			local q = smooth(math.min(1, age2 / 22))
			if age2 < 22 then
				d.x, d.y, d.z, d.state, d.pose = lerp(dx0, far, q), 2 * math.sin(q * math.pi), nil, "Hitstun", "Launched"
			else
				d.x, d.z = far, nil
				T.FATAL.fall(ctx.cin, d, tick, F + 22, 0.5)
				if d.pose == "Kneel" then d.pose = "DownFace" end
			end
			if age2 < 60 then attack(a, moves, T.role(ctx, "Finale"), true) else a.state, a.move, a.pose = "Idle", nil, "GloveTap" end
			if age2 == 0 then
				sfx(frame, "rs-final", "boom")
				frame.impact = { key = "rs-final", color = "FFFFFF" }
				table.insert(frame.fx, { key = "rs-wave", kind = "soundWave", pos = v(dx0, 3, 0), from = v(ax, 3.2, 0), to = v(far, 3.2, 0), color = color })
			end
			if age2 == 22 then
				sfx(frame, "rs-land", "heavy")
				T.impact(frame, "rs-land", v(far, 1.6, 0.6), color, 2.4)
			end
			for i = 0, 3 do
				local r = progress(tick, F + i * 6, F + 50 + i * 6)
				if r > 0 and r < 1 then
					shape(frame, { kind = "ring", pos = At(v(ax + dir * (1.4 + i * 2.6), 3.3, 0)), normal = v(dir, 0, 0), radius = lerp(1, 6, smooth(r)),
						width = 0.22, color = if i % 2 == 0 then "FFFFFF" else color, alpha = r })
				end
			end
			if age2 < 26 then
				frame.shot = frameOn("hibiki-rs-blast", dir, { a, d }, { yaw = 10, pitch = 2, fill = 0.6, fov = 46, focus = P(D, "UpperTorso") })
			else
				frame.shot = frameOn("hibiki-rs-after", dir, { a }, { yaw = 20, pitch = -6, fill = 0.7, fov = 36, focus = P(A, "UpperTorso") })
			end
			ko(ctx, frame, tick, F + 40, color)
		end
	end

	-- ================================================================ KAZAN · CAGE OF CLAWS
	-- The predator's claws, three blades on each hand. 0:00 the blades scrape together, sparks ·
	-- 0:01 he rakes the target from every side; every pass leaves three lines of light hanging in
	-- the air · 0:05 a cage of claw marks round it; he stands before it · 0:06 he crosses his
	-- claws and pulls: the cage closes · 0:07 the last cut, six blades in an X; the cage shatters
	-- · 0:09 he shakes his claws clean.
	function S.KAZAN(ctx, frame, a, d, tick, dir)
		local A, D = ctx.cin.attacker, ctx.cin.defender
		local moves = ctx.moveData.Moves
		local color = ctx.characters[A].Energy
		local cx = T.center(ctx, d)
		local F = 440
		local PASSES = 8
		frame.grade.iron = true
		d.x, d.facing = cx, -dir
		-- the marks: pass p leaves three parallel lines round the target
		local close = smooth(progress(tick, 360, F - 6))
		local function marks(upTo, fade)
			for p_ = 1, upTo do
				local angle = p_ * 0.78 + 0.3
				local y = 2.2 + (p_ % 3) * 0.9
				local tilt = if p_ % 2 == 0 then 0.6 else -0.6
				local r = 1.6 * (1 - 0.65 * close)
				local c = v(cx + math.cos(angle) * r, y, math.sin(angle) * r)
				local tx, ty, tz = -math.sin(angle), tilt, math.cos(angle)
				local half = 1.8 * (1 - 0.4 * close)
				for k = -1, 1 do
					local o = k * 0.28
					shape(frame, { kind = "slash", from = At(v(c.x - tx * half, c.y - ty * half + o, c.z - tz * half)),
						to = At(v(c.x + tx * half, c.y + ty * half + o, c.z + tz * half)), width = 0.12,
						color = if k == 0 then "FFFFFF" else color, alpha = fade })
				end
			end
		end
		if tick < 60 then
			-- the blades scrape together, sparks
			a.x, a.z, a.facing = cx - dir * 3.4, nil, dir
			a.pose = if tick < 24 then nil else "Roar"
			d.state = "Hitstun"
			if tick % 10 == 4 then
				T.spark(frame, "cc-scrape" .. tick, v(a.x + dir * 0.6, 3.6, 0.6), if tick % 20 == 4 then "FFFFFF" else color, 0.6)
				sfx(frame, "cc-scrape" .. tick, "slash")
			end
			frame.shot = frameOn("kazan-cc-claws", dir, { a, d }, { yaw = 36, pitch = -8, band = "bust", fill = 0.8, fov = 32, focus = P(A, "Head") })
		elseif tick < 300 then
			-- the passes: from every side, every one leaves its marks
			local t = tick - 70
			local p_ = math.clamp(t // 28 + 1, 1, PASSES)
			local age = t - (p_ - 1) * 28
			local angle = p_ * 0.78 + 0.3 + math.pi
			local ox = if age < 10 then lerp(4.2, 2.2, age / 10) else lerp(2.2, 4.2, math.min(1, (age - 10) / 12))
			circle(a, cx, dir, angle, ox, 0)
			if t < 0 then
				circle(a, cx, dir, 0, 3.4, 0)
				a.state, a.move = "Idle", nil
			elseif age < 12 then
				attack(a, moves, T.role(ctx, if p_ % 2 == 0 then "Cross" else "Jab"), age >= 3)
			else
				a.state, a.move, a.vx = "Dashing", nil, 3
			end
			if t >= 0 and age == 3 then
				sfx(frame, "cc-rake" .. p_, "slash")
				table.insert(frame.fx, { key = "cc-ghost" .. p_, kind = "afterimage", slot = A, color = color, life = 0.35 })
			end
			d.state, d.pose = "Hitstun", if t >= 0 and age >= 3 and age < 10 then (if p_ % 2 == 0 then "HitHigh" else "HitBody") else nil
			marks(if t >= 0 and age >= 3 then p_ else p_ - 1, 0.25)
			if tick > 160 then frame.speedLines = color end
			frame.shot = frameOn("kazan-cc-rake", dir, { d }, { yaw = -20, pitch = 14, fill = 0.55, fov = 42,
				focus = P(D, "UpperTorso") })
		elseif tick < F then
			-- before the cage; he crosses his claws and pulls: it closes
			a.x, a.z, a.lookDir, a.facing = cx - dir * 3.6, nil, nil, dir
			attack(a, moves, T.role(ctx, "Finale"), false)
			d.state, d.pose = "Hitstun", "HitHigh"
			marks(PASSES, lerp(0.25, 0.05, close))
			if tick == 360 then sfx(frame, "cc-pull", "charge") end
			frame.quake = if close > 0 then 0.1 * close else nil
			if tick < 360 then
				frame.shot = frameOn("kazan-cc-cage", dir, { a, d }, { yaw = 20, pitch = 4, fill = 0.68, fov = 38, focus = P(D, "UpperTorso") })
			else
				frame.shot = frameOn("kazan-cc-close", dir, { d }, { yaw = -24, pitch = 6, fill = lerp(0.6, 0.8, close), fov = 34, focus = P(D, "UpperTorso") })
			end
		else
			-- six blades in an X; the cage shatters; he shakes his claws clean
			local age = tick - F
			a.x, a.z, a.lookDir, a.facing = cx + dir * 2.6, nil, nil, dir
			if age < 40 then attack(a, moves, T.role(ctx, "Finale"), true) elseif age < 80 then attack(a, moves, T.role(ctx, "SpinKick"), true)
			else a.state, a.move, a.pose = "Idle", nil, "Roar" end
			T.FATAL.fall(ctx.cin, d, tick, F + 10, 0)
			if d.pose == "Kneel" then d.pose = "DownFace" end
			if age < 24 then
				for side = -1, 1, 2 do
					for k = -1, 1 do
						local o = k * 0.35
						shape(frame, { kind = "slash", from = At(v(cx - side * 2.6, 5.4 + o, 0.5)), to = At(v(cx + side * 2.6, 1.4 + o, 0.5)), width = 0.26,
							color = if k == 0 then "FFFFFF" else color, alpha = age / 24 })
					end
				end
			end
			if age == 0 then
				sfx(frame, "cc-x", "boom")
				frame.impact = { key = "cc-x", color = "FFFFFF" }
				table.insert(frame.fx, { key = "cc-shatter", kind = "clawBurst", pos = v(cx, 3.3, 0.6), color = color })
				table.insert(frame.fx, { key = "cc-sparks", kind = "debris", pos = v(cx, 3, 0), color = color, scale = 1.4 })
			end
			if age < 40 then
				frame.shot = frameOn("kazan-cc-x", dir, { a, d }, { yaw = 16, pitch = 2, fill = 0.68, fov = 40, focus = P(D, "UpperTorso") })
			else
				frame.shot = frameOn("kazan-cc-after", dir, { a, d }, { yaw = -30, pitch = -6, fill = 0.62, fov = 38, focus = P(A, "Head") })
			end
			ko(ctx, frame, tick, F + 40, color)
		end
	end


	-- ================================================================ KUREN · CRIMSON COVENANT
	-- The blood alchemist pays in his own blood (his SCARLET PACT). 0:00 he opens his palm, his
	-- blood drips · 0:01 it runs along the deck to the target and pools under it · 0:03 lances of
	-- blood rise out of the pool round it, one by one · 0:05 he closes his hand slowly; the lances
	-- tremble · 0:07 they plunge in · 0:08 the blood comes back to him; it falls.
	function S.KUREN(ctx, frame, a, d, tick, dir)
		local A, D = ctx.cin.attacker, ctx.cin.defender
		local moves = ctx.moveData.Moves
		local color = ctx.characters[A].Energy
		local cx = T.center(ctx, d)
		local F = 450
		local LANCES = 12
		local ax = inside(ctx, cx - dir * 4.6)
		frame.grade.blood = tick >= 60
		a.x, a.facing = ax, dir
		d.x, d.facing = cx, -dir
		local pool = smooth(progress(tick, 90, 170)) * (1 - smooth(progress(tick, F + 40, F + 120)))
		if pool > 0.02 then
			for i = 0, 2 do
				shape(frame, { kind = "ring", pos = At(v(cx, 0.06 + i * 0.02, 0)), normal = v(0, 1, 0), radius = (1 + i) * 1.2 * pool, width = 0.35, color = color,
					alpha = 0.2 + 0.2 * i })
			end
		end
		-- the lances: lance k is born at 170 + 12k, rising out of the pool
		local plunge = smooth(progress(tick, F - 14, F))
		local gone = progress(tick, F + 30, F + 80)
		local function lances()
			for k = 0, LANCES - 1 do
				local born = 170 + k * 12
				local grow = smooth(progress(tick, born, born + 10))
				if grow > 0 and gone < 1 then
					local angle = k * 2.4 + 0.3
					local base = v(cx + math.cos(angle) * 3.6, 0.1, math.sin(angle) * 3)
					local tipR = lerp(1.5, 0.15, plunge)
					local shake = if tick > 330 and tick < F then 0.08 * math.sin(tick * 3 + k) else 0
					local tip = v(cx + math.cos(angle) * tipR + shake, lerp(0.1, 2.6 + (k % 3) * 0.7, grow), math.sin(angle) * tipR * 0.8)
					shape(frame, { kind = "slash", from = At(base), to = At(v(lerp(base.x, tip.x, grow), tip.y, lerp(base.z, tip.z, grow))), width = 0.22,
						color = if k % 4 == 0 then "FFFFFF" else color, alpha = gone })
				end
			end
		end
		if tick < 90 then
			-- he opens his palm; his blood drips
			attack(a, moves, T.role(ctx, "PalmStrike"), false)
			d.state = "Hitstun"
			if tick == 30 then
				sfx(frame, "cv-cut", "slash")
				T.spark(frame, "cv-cut", v(ax + dir * 0.7, 3.4, 0.6), color, 0.6)
			end
			if tick > 30 then shape(frame, { kind = "motes", pos = P(A, "RightHand"), radius = 1.2, count = 10, color = color, phase = tick / 30, out = true }) end
			frame.shot = frameOn("kuren-cv-palm", dir, { a, d }, { yaw = 26, pitch = -6, band = "bust", fill = 0.8, fov = 32, focus = P(A, "Head") })
		elseif tick < 170 then
			-- the blood runs along the deck to the target and pools under it
			a.state, a.move, a.pose = "Idle", nil, "ArmsCrossed"
			d.state, d.pose = "Hitstun", "VicBrace"
			local q = progress(tick, 90, 140)
			if q < 1 then
				shape(frame, { kind = "slash", from = At(v(ax + dir * 0.6, 0.08, 0)), to = At(v(lerp(ax + dir * 0.6, cx, q), 0.08, 0)), width = 0.3, color = color, alpha = 0.2 })
			end
			if tick == 150 then
				table.insert(frame.fx, { key = "cv-pool", kind = "bloodPool", pos = v(cx, 0, 0), radius = 1.6, scale = 0.4, color = color, life = 1.5 })
				sfx(frame, "cv-pool", "charge")
			end
			frame.shot = frameOn("kuren-cv-flow", dir, { a, d }, { yaw = -24, pitch = -14, fill = 0.7, fov = 40, focus = P(D, "UpperTorso") })
		elseif tick < F then
			-- the lances rise one by one; he closes his hand slowly; they plunge
			a.state, a.move = "Idle", nil
			if tick < 330 then a.pose = "ArmsCrossed" else attack(a, moves, T.role(ctx, "Finale"), false) end
			d.state, d.pose = "Hitstun", if tick < 330 then "VicBrace" else "HitHigh"
			lances()
			if tick >= 170 and (tick - 170) % 12 == 0 and tick < 170 + LANCES * 12 then sfx(frame, "cv-lance" .. tick, "slash") end
			if tick == 330 then sfx(frame, "cv-close", "charge") end
			if tick < 330 then
				frame.shot = frameOn("kuren-cv-lances", dir, { d }, { yaw = lerp(60, 0, progress(tick, 170, 330)), pitch = 18, fill = 0.5, fov = 42,
					focus = P(D, "UpperTorso") })
			else
				frame.shot = frameOn("kuren-cv-hand", dir, { a, d }, { yaw = 30, pitch = -10, fill = 0.72, fov = 38, focus = P(A, "Head") })
			end
		else
			-- they plunge in; the blood comes back to him; it falls
			local age = tick - F
			lances()
			if age < 60 then attack(a, moves, T.role(ctx, "Finale"), true) else a.state, a.move, a.pose = "Idle", nil, "StandTall" end
			if age < 30 then
				d.state, d.pose, d.hitstop = "Hitstun", "HitHigh", if age < 16 then 1 else 0
			else
				d.hitstop = 0
				T.FATAL.fall(ctx.cin, d, tick, F + 30, 0)
				if d.pose == "Kneel" then d.pose = "DownFace" end
			end
			if age == 0 then
				sfx(frame, "cv-pierce", "boom")
				frame.impact = { key = "cv-pierce", color = color }
				table.insert(frame.fx, { key = "cv-bloom", kind = "bloodBloom", pos = v(cx, 3, 0.6), color = color, scale = 1.6 })
			end
			if age >= 30 and age < 90 then
				-- (the blood flows back into his hand: the pact repaid)
				local q = (age - 30) / 60
				shape(frame, { kind = "motes", pos = At(v(lerp(cx, ax + dir * 0.7, q), lerp(2.6, 3.4, q), 0)), radius = 1.4, count = 16, color = color,
					phase = age / 20 })
				frame.aura = A
			end
			if age < 40 then
				frame.shot = frameOn("kuren-cv-pierce", dir, { d }, { yaw = 40, pitch = 24, fill = 0.55, fov = 40, focus = P(D, "UpperTorso") })
			else
				frame.shot = frameOn("kuren-cv-after", dir, { a, d }, { yaw = -30, pitch = -6, fill = 0.62, fov = 38, focus = P(A, "Head") })
			end
			ko(ctx, frame, tick, F + 40, color)
		end
	end

	-- ================================================================ SYLVA · THE GREAT HUNT
	-- The huntress turns the ring into her forest. 0:00 she touches the deck: roots burst out all
	-- round · 0:01 vines bind the target, wrists and ankles, and lift it · 0:03 she circles it at a
	-- distance, low, as a hunter; three traps snap shut on it · 0:05 she stops, aims · 0:07 the
	-- hunt: she goes through it · 0:08 the vines let go; the leaves fall.
	function S.SYLVA(ctx, frame, a, d, tick, dir)
		local A, D = ctx.cin.attacker, ctx.cin.defender
		local moves = ctx.moveData.Moves
		local color = ctx.characters[A].Energy
		local cx = T.center(ctx, d)
		local F = 450
		local LEAF = "6FD36A"
		frame.grade.wild = true
		d.x, d.facing = cx, -dir
		local anchors = { { -2.2, 1.6, "LeftHand" }, { 2.2, 1.6, "RightHand" }, { -1.6, -1.8, "LeftFoot" }, { 1.6, -1.8, "RightFoot" } }
		local lift = smooth(progress(tick, 120, 200)) * (1 - smooth(progress(tick, F, F + 16)))
		local function vines(snap)
			for i, an in anchors do
				local born = 80 + (i - 1) * 20
				local grow = smooth(progress(tick, born, born + 14))
				if grow > 0 and snap < 1 then
					local base = v(cx + an[1], 0.1, an[2])
					shape(frame, { kind = "slash", from = At(base), to = P(D, an[3]), width = 0.16, color = if i % 2 == 0 then LEAF else color,
						alpha = math.max(1 - grow, snap) })
					if tick == born then sfx(frame, "gh-vine" .. i, "whoosh") end
				end
			end
		end
		if tick < 80 then
			-- she touches the deck: roots burst out all round
			a.x, a.z, a.facing = cx - dir * 4.4, nil, dir
			attack(a, moves, T.role(ctx, "KiBlast"), tick >= 30)
			d.state = "Hitstun"
			if tick == 30 then
				sfx(frame, "gh-roots", "boom")
				for i = 0, 5 do
					local angle = i * math.pi / 3 + 0.5
					table.insert(frame.fx, { key = "gh-root" .. i, kind = "roots", pos = v(cx + math.cos(angle) * 6, 0, math.sin(angle) * 4 - 1.5), radius = 1.4,
						count = 4, color = LEAF, life = 7 })
				end
			end
			frame.quake = if tick >= 30 and tick < 40 then 0.4 else nil
			frame.shot = frameOn("sylva-gh-roots", dir, { a, d }, { yaw = -28, pitch = -12, fill = 0.62, fov = 42, focus = P(A, "UpperTorso") })
		elseif tick < 200 then
			-- vines bind the target and lift it
			a.x, a.z, a.facing, a.state, a.move, a.pose = cx - dir * 4.4, nil, dir, "Idle", nil, "WindGather"
			d.y, d.state, d.pose = 1.4 * lift, "Hitstun", "Launched"
			vines(0)
			frame.shot = frameOn("sylva-gh-bind", dir, { a, d }, { yaw = 30, pitch = -6, fill = 0.62, fov = 40, focus = P(D, "UpperTorso") })
		elseif tick < 330 then
			-- she circles it at a distance, low, as a hunter; three traps snap
			d.y, d.state = 1.4, "Hitstun"
			local snapAge = 99
			for i, t in { 230, 270, 310 } do
				if tick >= t then snapAge = tick - t end
				if tick == t then
					sfx(frame, "gh-trap" .. i, "slash")
					table.insert(frame.fx, { key = "gh-thorns" .. i, kind = "thornBurst", pos = v(cx, 2.6, 0.4), color = color, scale = 0.8 + 0.2 * i })
				end
			end
			d.pose = if snapAge < 8 then "HitBody" else "Launched"
			vines(0)
			local angle = (tick - 200) / 130 * math.pi * 1.3 + 0.2
			circle(a, cx, dir, angle, 6, 0)
			a.state, a.move, a.vx = "Walking", nil, 1.4
			frame.shot = frameOn("sylva-gh-stalk", dir, { a, d }, { yaw = 40 - math.deg(angle), pitch = 18, fill = 0.6, fov = 40, focus = P(A, "Head") })
		elseif tick < F then
			-- she stops and aims; then the hunt: through it
			d.y, d.state, d.pose = 1.4, "Hitstun", "Launched"
			vines(0)
			if tick < F - 18 then
				a.x, a.z, a.lookDir, a.facing = cx - dir * 6.5, nil, nil, dir
				attack(a, moves, T.role(ctx, "KiChase"), false)
				-- (behind her, low: the hunter's aim)
				frame.shot = shot("sylva-gh-aim", At(v(cx - dir * 12.5, 3.2, 3.8)), P(D, "UpperTorso"), 30, 0, P(D, "UpperTorso"))
			else
				local q = progress(tick, F - 18, F)
				a.x, a.z, a.lookDir, a.facing = lerp(cx - dir * 6.5, cx - dir * 0.6, q * q), nil, nil, dir
				a.y = 1.2 * math.sin(q * math.pi * 0.5)
				attack(a, moves, T.role(ctx, "KiChase"), true)
				if tick % 4 == 0 then table.insert(frame.fx, { key = "gh-trail" .. tick, kind = "afterimage", slot = A, color = color, life = 0.4 }) end
				if tick == F - 18 then sfx(frame, "gh-run", "whoosh") end
				frame.speedLines = color
				frame.shot = frameOn("sylva-gh-hunt", dir, { a, d }, { yaw = 30, pitch = -4, fill = 0.7, fov = 44, focus = P(D, "UpperTorso") })
			end
		else
			-- the vines let go; the leaves fall
			local age = tick - F
			local q = smooth(math.min(1, age / 16))
			a.x, a.z, a.facing = lerp(cx - dir * 0.6, cx + dir * 4.2, q), nil, dir
			a.y = 1.2 * (1 - q)
			if age < 30 then attack(a, moves, T.role(ctx, "KiChase"), true) else a.state, a.move, a.pose = "Idle", nil, if age < 80 then "WindGather" else nil end
			vines(smooth(math.min(1, age / 10)))
			if age < 16 then
				d.y, d.state, d.pose = 1.4 * (1 - q), "Hitstun", "HitBody"
			else
				d.y = 0
				T.FATAL.fall(ctx.cin, d, tick, F + 16, 0)
				if d.pose == "Kneel" then d.pose = "DownFace" end
			end
			if age == 0 then
				sfx(frame, "gh-kill", "heavy")
				T.impact(frame, "gh-kill", v(cx, 3, 0.6), color, 2.6)
				table.insert(frame.fx, { key = "gh-burst", kind = "thornBurst", pos = v(cx, 3, 0.4), color = color, scale = 1.8 })
			end
			shape(frame, { kind = "motes", pos = At(v(cx, 5, 0)), radius = 7, count = 20, color = LEAF, phase = age / 90 })
			if age < 40 then
				frame.shot = frameOn("sylva-gh-through", dir, { a, d }, { yaw = -20, pitch = 4, fill = 0.62, fov = 42, focus = P(D, "UpperTorso") })
			else
				frame.shot = frameOn("sylva-gh-after", dir, { a, d }, { yaw = -20, pitch = -6, fill = 0.58, fov = 38, focus = P(A, "Head") })
			end
			ko(ctx, frame, tick, F + 40, color)
		end
	end

	-- ================================================================ NOVA · FATAL ERROR
	-- The war engineer runs her last program: her drones, a rail, the target's crash.
	-- 0:00 her visor lights, a scan runs down her body, a hand raised (SENTRY): two drones lift
	-- off · 0:01 two become eight (ENGINEERING) and ring the target · 0:02.7 they scan it, then
	-- lock on: the reticle closes, it raises its guard · 0:04 they fly back and dock in front of
	-- the gauntlet she holds out as a cannon (DRONE SHOT): eight rings, a rail · 0:05.5 the count,
	-- 3, 2, 1, the rings light one by one · 0:07 0: silence, her visor · 0:07.5 the shot, one
	-- white line through the target to the wall · 0:08 time stops round it, then it glitches (her
	-- two colours, its pixels blown out) · 0:09 it crashes · 0:09.7 K.O. on the screen of a
	-- crashed system · 0:10.3 her gauntlet vents its heat.
	local NOVA_DRONES = 8
	local NOVA_GAP, NOVA_ROOM = 10.5, 7 -- (her rail fills the gap; the shot needs room behind the target)
	local NOVA_COUNT = { { 330, "3" }, { 360, "2" }, { 390, "1" }, { 420, "0" } }
	function S.NOVA(ctx, frame, a, d, tick, dir)
		local A, D = ctx.cin.attacker, ctx.cin.defender
		local moves = ctx.moveData.Moves
		local cfg = ctx.config
		local look = ctx.characters[A]
		local color, holo = look.Energy, look.Shield or "6FE0FF" -- (her ki and her hologram: orange and cyan, or the other way round)
		local cx = T.center(ctx, d)
		local F = 450
		local o = overlay(frame)
		frame.grade.tech = true
		local tx = if dir > 0 then math.min(cx, cfg.ArenaMaxX - NOVA_ROOM) else math.max(cx, cfg.ArenaMinX + NOVA_ROOM)
		local ax = inside(ctx, tx - dir * NOVA_GAP)
		tx = ax + dir * NOVA_GAP
		local up = v(0, 1, 0)
		local function add(p, q, k)
			k = k or 1
			return v(p.x + q.x * k, p.y + q.y * k, p.z + q.z * k)
		end
		local function mix(p, q, k)
			return v(lerp(p.x, q.x, k), lerp(p.y, q.y, k), lerp(p.z, q.z, k))
		end
		local function unit(p)
			local l = math.max(1e-6, math.sqrt(p.x * p.x + p.y * p.y + p.z * p.z))
			return v(p.x / l, p.y / l, p.z / l)
		end
		-- her body's axes as the client turns it (3/4 toward the camera, Config.ModelYaw)
		local fwd, side = v(dir * 0.93, 0, 0.37), v(-0.37, 0, dir * 0.93)
		-- the gauntlet held out as a cannon (her DRONE SHOT, measured on the rig), the rail from it
		-- to the target's chest, the line of the shot on to the wall
		local recoil = 0.6 * smooth(progress(tick, F, F + 10))
		local hand = v(ax - dir * recoil + (if dir > 0 then 2.13 else -2.44), 4.5, if dir > 0 then 1.31 else 0.54)
		local axis = unit(v(tx - hand.x, 4 - hand.y, -hand.z))
		local function slot(i)
			return add(hand, axis, 0.9 + 0.66 * (i - 1))
		end
		local muzzle = add(hand, axis, 0.9 + 0.66 * (NOVA_DRONES - 1) + 0.5)
		local wall = if dir > 0 then cfg.ArenaMaxX - 0.5 else cfg.ArenaMinX + 0.5
		local far = add(hand, axis, (wall - hand.x) / axis.x)
		local length = math.sqrt((far.x - muzzle.x) ^ 2 + (far.y - muzzle.y) ^ 2 + (far.z - muzzle.z) ^ 2)
		-- (the drones: born in pairs over her shoulders, each one copying itself; on a ring round
		-- the target, turning slowly; then docked one after the other in the rail)
		local function station(i, t)
			local angle = (i - 1) / NOVA_DRONES * math.pi * 2 + 0.35 + math.max(0, t - 150) / 95
			return v(tx + math.cos(angle) * 4.6, 4.6 + math.sin(i * 2.3) + 0.12 * math.sin(t / 8 + i), math.sin(angle) * 4.6)
		end
		local function born(i)
			return if i <= 2 then 44 elseif i <= 4 then 78 else 92
		end
		local function drone(i, t)
			local s = if i % 2 == 1 then 1 else -1
			local shoulder = v(ax + side.x * s * 1.3 - fwd.x * 0.3, 5.5, side.z * s * 1.3 - fwd.z * 0.3)
			local top = add(shoulder, up, 1.8)
			local b = born(i)
			if t < b then return nil, 0 end
			if i <= 2 and t < 70 then return mix(shoulder, top, smooth(progress(t, b, 70))), 0 end
			if t < 150 then
				local q = smooth(progress(t, math.max(70, b + 6), 150))
				local start = if i <= 2 then top else add(top, side, s * 0.6 * progress(t, b, b + 6))
				return add(mix(start, station(i, 150), q), up, 2.2 * math.sin(math.pi * q)), 0
			end
			local leave = 250 + (i - 1) * 4
			if t < leave then return station(i, t), 0 end
			local q = smooth(progress(t, leave, leave + 34))
			return add(mix(station(i, leave), slot(i), q), up, 1.2 * math.sin(math.pi * q)), q
		end
		-- her visor: a line of light across the eyes
		local function visor(width, alpha, c)
			local front = v(fwd.x * 0.5, 0.12, fwd.z * 0.5)
			shape(frame, { kind = "slash", from = P(A, "Head", add(front, side, -0.26)), to = P(A, "Head", add(front, side, 0.26)),
				width = width, color = c, alpha = alpha })
		end

		-- the fighters
		a.x, a.facing = ax - dir * recoil, dir
		if tick < 24 or (tick >= 100 and tick < 250) or (tick >= F + 44 and tick < 620) then
			a.state, a.move, a.pose = "Idle", nil, nil
		elseif tick < 100 then
			attack(a, moves, "NovaSentinel", true) -- (a hand raised to launch the drones, the other at the visor)
		elseif tick < F + 44 then
			attack(a, moves, T.role(ctx, "KiBlast"), true) -- (the gauntlet held out as a cannon, the other hand bracing it)
		else
			a.state, a.move, a.pose = "Idle", nil, "StandTall"
		end
		d.x, d.z, d.facing, d.hitstop = tx, nil, -dir, 0
		if tick < 160 then
			d.state = "Idle"
		elseif tick < 226 then
			-- it looks for the drones round it, then they lock on
			d.state = "Idle"
			d.lookDir = if tick < 220 then (function()
				local w = 0.9 * math.sin((tick - 160) / 18)
				return v(-dir * math.cos(w), 0, math.sin(w))
			end)() else nil
		elseif tick < F then
			d.state, d.pose = "Idle", "Block" -- (its guard up, for nothing)
		elseif tick < F + 96 then
			-- the shot: time stops round it; then it glitches
			d.state, d.pose, d.hitstop = "Hitstun", "HitBody", 1
			if tick >= F + 40 then
				local g = (tick - F) // 4
				d.x, d.z = tx + 0.16 * ((g * 7) % 3 - 1), 0.12 * ((g * 5) % 3 - 1)
				d.hidden = tick == F + 52 or tick == F + 53 or tick == F + 71 or tick == F + 84 -- (frames dropped)
				if (tick - F - 40) % 6 == 0 then
					table.insert(frame.fx, { key = "fe-glitch" .. tick, kind = "afterimage", slot = D, color = if (tick // 6) % 2 == 0 then color else holo,
						life = 0.3 })
				end
			end
		else
			-- it crashes: it folds, then falls on its face
			d.state = "Hitstun"
			d.pose = if tick < F + 106 then "CrumpleStart" elseif tick < F + 120 then "Crumple" else "DownFace"
		end

		-- the drones (each a body and its rotor; docked, the rotor is a ring of the rail, lit one
		-- by one during the count, white at 0; the shot blows them apart). First in the list: the
		-- client's pool of parts stays the same from one phase to the next.
		if tick < F + 24 then
			local blow = progress(tick, F, F + 20)
			for i = 1, NOVA_DRONES do
				local pos, dock = drone(i, math.min(tick, F))
				if pos then
					local r = lerp(0.42, 0.82, dock) + 0.9 * blow
					local lit = progress(tick, 330 + (i - 1) * 11, 338 + (i - 1) * 11)
					if tick < F then
						shape(frame, { kind = "sphere", pos = At(add(pos, up, r * dock)), radius = lerp(0.17, 0.09, dock), color = color, core = 0.4 })
					end
					shape(frame, { kind = "ring", pos = At(pos), normal = unit(mix(up, axis, dock)), radius = r, width = lerp(0.06, 0.1, dock),
						color = if tick >= 420 then "FFFFFF" elseif lit > 0 then color else holo,
						alpha = math.max(lerp(0.3, 0.45, dock) * (1 - lit), blow) })
				end
			end
			for i = 3, NOVA_DRONES do
				local b = born(i)
				if tick >= b and tick < b + 10 then
					-- (a copy pops out of its drone)
					shape(frame, { kind = "ring", pos = At((drone(i, tick))), normal = up, radius = lerp(0.2, 1, progress(tick, b, b + 10)), width = 0.05,
						color = holo, alpha = progress(tick, b, b + 10) })
				end
			end
		end
		-- BOOT: the visor, the scan down her body
		if tick >= 6 and tick < 70 then visor(0.05, lerp(1, 0.15, progress(tick, 6, 16)), holo) end
		if tick >= 8 and tick < 50 then
			shape(frame, { kind = "ring", pos = At(v(a.x, lerp(6, 0.2, progress(tick, 8, 50)), 0)), normal = up, radius = 1.3, width = 0.06, color = holo,
				alpha = 0.3 })
		end
		-- LOCK-ON: the reticle closes on the floor round it, four marks turning with it; the scan
		-- lines sweep its body, then all hold its chest
		if tick >= 160 and tick < 262 then
			local locked = tick >= 220
			local c = if locked then color else holo
			local fade = progress(tick, 250, 262)
			local r = lerp(3.6, 1.4, smooth(progress(tick, 160, 216)))
			local spin = (math.min(tick, 220) - 160) / 40
			shape(frame, { kind = "ring", pos = At(v(tx, 0.06, 0)), normal = up, radius = r, width = 0.08, color = c, alpha = math.max(0.25, fade) })
			for k = 0, 3 do
				local angle = spin + k * math.pi / 2
				shape(frame, { kind = "slash", from = At(v(tx + math.cos(angle) * r, 0.06, math.sin(angle) * r)),
					to = At(v(tx + math.cos(angle) * (r - 0.7), 0.06, math.sin(angle) * (r - 0.7))), width = 0.07, color = c, alpha = math.max(0.2, fade) })
			end
			if tick < 250 then
				for i = 1, NOVA_DRONES do
					local aim = if locked then P(D, "UpperTorso") else P(D, "UpperTorso", v(0, 1.4 * math.sin((tick - 160) / 11 + i * 0.8), 0))
					shape(frame, { kind = "slash", from = At((drone(i, tick))), to = aim, width = if locked then 0.05 else 0.035, color = c,
						alpha = if locked then 0.15 else 0.45 })
				end
			end
		end
		if tick >= 200 and tick < F then
			-- (the lock on its chest, until the shot)
			shape(frame, { kind = "ring", pos = P(D, "UpperTorso"), normal = v(dir, 0, 0), radius = lerp(1.8, 0.75, smooth(progress(tick, 200, 220))),
				width = 0.06, color = if tick >= 220 then color else holo, alpha = 0.3 })
		end
		-- THE COUNT: the rail charges, sparks run from ring to ring, the air is drawn into it
		if tick >= 330 and tick < F then
			local e1 = unit(add(up, axis, -axis.y))
			local e2 = unit(v(axis.y * e1.z - axis.z * e1.y, axis.z * e1.x - axis.x * e1.z, axis.x * e1.y - axis.y * e1.x))
			for i = 1, NOVA_DRONES - 1 do
				local angle = (tick // 3) * 1.7 + i * 2.3
				local function rim(k, w)
					return add(add(slot(k), e1, math.cos(w) * 0.82), e2, math.sin(w) * 0.82)
				end
				shape(frame, { kind = "slash", from = At(rim(i, angle)), to = At(rim(i + 1, angle + 0.7)), width = 0.035, color = "FFFFFF", alpha = 0.25 })
			end
			shape(frame, { kind = "motes", pos = At(add(hand, axis, 0.4)), radius = 2.4, count = 26, color = color, phase = tick / 45 })
			if tick >= 420 then
				shape(frame, { kind = "sphere", pos = At(muzzle), radius = lerp(0.15, 0.55, progress(tick, 420, F)), color = holo, core = 1 })
			end
			local current
			for _, c in NOVA_COUNT do
				if tick >= c[1] then current = c end
			end
			o.caption = { text = current[2], color = if current[2] == "0" then "FFFFFF" else color, age = tick - current[1], fade = 0 }
			o.desat = if tick < 420 then 0.45 * progress(tick, 330, 420) else 0.85
			if tick >= 420 then visor(0.08, 0.05, "FFFFFF") end
		end
		-- THE SHOT: one line through the target to the wall; the shock rings stand still while time
		-- does, then go on; the far end bursts
		if tick >= F then
			local age = tick - F
			if age < 94 then
				shape(frame, { kind = "slash", from = At(muzzle), to = At(far), width = lerp(1, 0.16, progress(age, 0, 12)), color = holo,
					alpha = progress(age, 64, 94) })
				for j = 1, 4 do
					local grow = smooth(progress(age, j, j + 10)) * (1 + 0.25 * j) + 2.2 * smooth(progress(age, 50, 80))
					shape(frame, { kind = "ring", pos = At(add(muzzle, axis, (j - 0.5) / 4 * length)), normal = axis, radius = 0.3 + grow, width = 0.12,
						color = if j % 2 == 0 then "FFFFFF" else holo, alpha = math.max(0.15, progress(age, 50, 80)) })
				end
			end
			if age < 40 then
				local q = smooth(progress(age, 0, 26))
				shape(frame, { kind = "sphere", pos = At(far), radius = lerp(0.4, 3.2, q), color = holo, core = 1 - q })
			end
			if age >= 40 and age < 96 then
				-- (its pixels blown out)
				shape(frame, { kind = "motes", pos = P(D, "UpperTorso"), radius = 3, count = 28, color = holo, phase = (age - 40) / 36, out = true })
			end
			if age >= 96 and age < 126 then
				shape(frame, { kind = "motes", pos = P(D, "UpperTorso"), radius = 5, count = 36, color = color, phase = (age - 96) / 30, out = true })
				shape(frame, { kind = "ring", pos = At(v(tx, 0.06, 0)), normal = up, radius = lerp(0.6, 4.6, smooth(progress(age, 96, 120))), width = 0.1,
					color = holo, alpha = progress(age, 96, 126) })
			end
			if age == 0 then
				sfx(frame, "fe-shot", "beam")
				sfx(frame, "fe-blast", "boom")
				frame.impact = { key = "fe-shot", color = "FFFFFF" }
				table.insert(frame.fx, { key = "fe-wall", kind = "debris", pos = far, color = holo, scale = 1.2 })
			end
			if age == 40 then sfx(frame, "fe-glitch", "charge") end
			if age == 96 then
				sfx(frame, "fe-crash", "heavy")
				T.spark(frame, "fe-crash", v(tx, 1, 0.6), holo, 1.6)
				table.insert(frame.fx, { key = "fe-crash-debris", kind = "debris", pos = v(tx, 0.5, 0), color = color, scale = 1 })
			end
			o.white = if age < 12 then 0.9 * (1 - progress(age, 0, 12)) else nil
			frame.speedLines = if age < 12 then holo else nil
			frame.quake = if age < 10 then 0.9 elseif age >= 96 and age < 104 then 0.5 else nil
			local glitch = progress(age, 40, 56) * (1 - progress(age, 90, 100))
			o.desat = if age < 40 then 0.6 elseif age < 96 then 0.3 else nil
			if glitch > 0 then o.tint = { color = holo, amount = 0.35 * glitch } end
			if tick >= 620 then
				-- (her gauntlet vents its heat; the visor dims)
				shape(frame, { kind = "motes", pos = P(A, "LeftHand"), radius = 1.5, count = 14, color = "D8D8E0", phase = tick / 50, out = true })
				visor(0.04, 0.5, holo)
			end
			if tick == F + 130 then sfx(frame, "fe-ko", "boom") end
			ko(ctx, frame, tick, F + 130, color, if tick < 620 then { bg = "05070C", splash = holo } else nil)
		end
		-- sounds of the build-up
		if tick == 8 then sfx(frame, "fe-boot", "charge") end
		if tick == 44 or tick == 78 or tick == 92 or tick == 250 then sfx(frame, "fe-drones" .. tick, "whoosh") end
		if tick == 220 or tick == 330 then sfx(frame, "fe-lock" .. tick, "charge") end
		if tick == 284 or tick == 296 or tick == 312 or tick == 360 or tick == 390 then sfx(frame, "fe-clamp" .. tick, "slash") end

		-- the shots
		if tick < 70 then
			frame.shot = frameOn("nova-fe-boot", dir, { a, { point = true, x = ax, y = 7.4, z = 0 } }, { yaw = 34, pitch = -6, band = "bust",
				fill = lerp(0.7, 0.8, smooth(progress(tick, 0, 70))), fov = 32, focus = P(A, "Head") })
		elseif tick < 118 then
			frame.shot = frameOn("nova-fe-launch", dir, { a, d, { point = true, x = ax, y = 8, z = 0 } }, { yaw = -36, pitch = -16, fill = 0.74, fov = 46,
				focus = P(A, "UpperTorso") })
		elseif tick < 160 then
			frame.shot = frameOn("nova-fe-swarm", dir, { d, { point = true, x = tx - 4.6, y = 5, z = 0 }, { point = true, x = tx + 4.6, y = 5, z = 0 } },
				{ yaw = 16, pitch = 32, fill = 0.62, fov = 44, focus = P(D, "UpperTorso") })
		elseif tick < 220 then
			frame.shot = frameOn("nova-fe-scan", dir, { d }, { yaw = lerp(-50, -20, smooth(progress(tick, 160, 220))), pitch = 22, fill = 0.5, fov = 42,
				focus = P(D, "Head") })
		elseif tick < 250 then
			frame.shot = frameOn("nova-fe-lock", dir, { d }, { yaw = -30, pitch = 2, band = "bust", fill = 0.66, fov = 34, focus = P(D, "Head") })
		elseif tick < 330 then
			frame.shot = frameOn("nova-fe-dock", dir, { a, d }, { yaw = 8, pitch = -6, fill = 0.88, fov = 40, focus = P(A, "UpperTorso") })
		elseif tick < 360 then
			frame.shot = frameOn("nova-fe-three", dir, { a }, { yaw = 56, pitch = -8, band = "bust", fill = 0.62, fov = 36, focus = P(A, "Head") })
		elseif tick < 390 then
			frame.shot = frameOn("nova-fe-two", dir, { a, d }, { yaw = 62, pitch = 4, fill = 0.8, fov = 36, focus = P(A, "Head") })
		elseif tick < 420 then
			frame.shot = frameOn("nova-fe-one", dir, { a, d }, { yaw = -56, pitch = 10, fill = 0.8, fov = 34, focus = P(D, "Head") })
		elseif tick < F then
			frame.shot = frameOn("nova-fe-zero", dir, { a }, { yaw = 12, pitch = -2, band = "face", fill = 0.72, fov = 28, focus = P(A, "Head") })
			frame.shot.close = true
		elseif tick < F + 14 then
			frame.shot = frameOn("nova-fe-fire", dir, { a, d, { point = true, x = far.x, y = far.y, z = far.z } }, { yaw = 4, pitch = -4, fill = 0.9, fov = 46,
				focus = P(D, "UpperTorso") })
		elseif tick < F + 96 then
			frame.shot = frameOn("nova-fe-freeze", dir, { d }, { yaw = lerp(-75, 5, smooth(progress(tick, F + 14, F + 96))), pitch = 6, fill = 0.55, fov = 40,
				focus = P(D, "UpperTorso") })
		elseif tick < F + 130 then
			frame.shot = frameOn("nova-fe-crash", dir, { d, { point = true, x = tx, y = 5.6, z = 0 } }, { yaw = 24, pitch = 20, fill = 0.6, fov = 40,
				focus = P(D, "UpperTorso") })
		elseif tick < 620 then
			frame.shot = frameOn("nova-fe-ko", dir, { a, d }, { yaw = 18, pitch = 8, fill = 0.66, fov = 40, focus = P(D, "UpperTorso") })
		else
			-- (low in the frame: the K.O. reads over her)
			frame.shot = frameOn("nova-fe-last", dir, { a }, { yaw = 40, pitch = -8, fill = lerp(0.62, 0.7, smooth(progress(tick, 620, 660))), fov = 34,
				screen = { 0.2, -0.22 }, focus = P(A, "Head") })
		end
	end

	-- ================================================================ KUROEN · BLACK SUN
	-- The emperor of the eclipse spends his DOMINATION, short and brutal: fists, elbows, knees.
	-- 0:00 his back: the three red marks of DOMINATION light one by one, I, II, III; the light
	-- falls (his grade) · 0:01.4 his eyes; it raises its guard · 0:01.8 CRIMSON STEP: he is on
	-- it, the knee; a small black sun stays on its belly · 0:02.6 the elbow down: it drops to its
	-- knees, a second sun on its shoulder · 0:03.5 the palm into its chest: the third · 0:04.9
	-- the emperor over it, his fist raised: the three suns leave its body and gather in his fist,
	-- one black sun with a red corona · 0:06.2 silence, the sun over his fist · 0:07.1 AXE OF
	-- NIGHT: both fists bring the sun down on it; it is driven face down into the deck, the corona
	-- runs along the floor, his seal under it · 0:08.3 K.O. · 0:09.8 his back, the marks gone
	-- dark. No eclipse in the sky (his ÉVEIL and DAICHA's PORTE have it), no juggle (his FATAL),
	-- no storm of fists (his PORTE): the sun is born on the deck, out of his blows.
	local KUROEN_GAP, KUROEN_FAR = 2.9, 6 -- (where he strikes from; where he stands first)
	local KUROEN_SUN = "07040C" -- (the black of his small black sun, KitFX)
	-- (each blow: its tick, his role, where its sun stays on the target, offset in the target's
	-- own axes: forward (toward him), up, toward the camera side; the impact for the burst)
	local KUROEN_BLOWS = {
		{ tick = 132, role = "Kick", part = "UpperTorso", off = { 0.7, -0.45, 0.25 }, burst = 2.3, sound = "heavy" },
		{ tick = 180, role = "Elbow", part = "UpperTorso", off = { 0.3, 1.02, 0.85 }, burst = 3.7, sound = "heavy" },
		{ tick = 252, role = "PalmStrike", part = "UpperTorso", off = { 0.76, 0.1, 0.2 }, burst = 3, sound = "heavy" },
	}
	local KUROEN_LIFT = { 304, 320, 336 } -- (when each sun leaves the target for his fist)
	local KUROEN_FLIGHT = 28
	-- The shots, in order (to: the tick it ends; subjects: "a", "d" or "ad", and sky: a point over him
	-- at that height, his raised fist; focus: slot and part)
	local KUROEN_SHOTS = {
		{ to = 84, name = "kuroen-bs-back", subjects = "a", yaw = -128, pitch = 4, band = "bust", fill = 0.7, fov = 34, focus = { "A", "UpperTorso" } },
		{ to = 110, name = "kuroen-bs-eyes", subjects = "a", yaw = 14, pitch = -6, band = "bust", fill = 0.75, fov = 30, focus = { "A", "Head" } },
		{ to = 124, name = "kuroen-bs-step", subjects = "ad", yaw = -10, pitch = 8, fill = 0.62, fov = 42, focus = { "A", "UpperTorso" } },
		{ to = 156, name = "kuroen-bs-knee", subjects = "ad", yaw = 24, pitch = -14, fill = 0.86, fov = 38, focus = { "D", "UpperTorso" } },
		{ to = 188, name = "kuroen-bs-elbow", subjects = "ad", yaw = -16, pitch = 44, fill = 0.82, fov = 38, focus = { "A", "UpperTorso" } },
		{ to = 212, name = "kuroen-bs-knees", subjects = "ad", yaw = 96, pitch = 28, fill = 0.82, fov = 38, focus = { "D", "UpperTorso" } },
		{ to = 296, name = "kuroen-bs-palm", subjects = "ad", yaw = 30, pitch = 4, fill = 0.85, fov = 36, focus = { "D", "UpperTorso" } },
		{ to = 372, name = "kuroen-bs-throne", subjects = "ad", sky = 8.2, yaw = 44, pitch = -16, fill = 0.92, fov = 38, focus = { "A", "Head" } },
		{ to = 436, name = "kuroen-bs-sun", subjects = "a", sky = 8.4, yaw = 24, pitch = -24, fill = 0.8, fov = 34, focus = { "A", "RightHand" } },
		{ to = 470, name = "kuroen-bs-blow", subjects = "ad", yaw = 16, pitch = 6, fill = 0.84, fov = 40, focus = { "D", "UpperTorso" } },
		{ to = 510, name = "kuroen-bs-crater", subjects = "ad", yaw = 10, pitch = 56, fill = 0.62, fov = 42, focus = { "D", "UpperTorso" } },
		{ to = 590, name = "kuroen-bs-ko", subjects = "ad", yaw = 26, pitch = 10, fill = 0.6, fov = 40, focus = { "D", "UpperTorso" } },
		{ to = math.huge, name = "kuroen-bs-last", subjects = "a", yaw = -112, pitch = 2, fill = 0.6, fov = 36, screen = { 0.2, -0.22 },
			focus = { "A", "UpperTorso" } },
	}
	function S.KUROEN(ctx, frame, a, d, tick, dir)
		local A, D = ctx.cin.attacker, ctx.cin.defender
		local moves = ctx.moveData.Moves
		local color = ctx.characters[A].Energy -- (his ki: red, or his style's)
		local F = 440
		local o = overlay(frame)
		-- (he stands KUROEN_FAR from it first, it is driven back 1 stud and lies beyond: near a
		-- wall the whole scene stands back from it, never him alone)
		local tx = room(ctx, T.center(ctx, d), dir, KUROEN_FAR + 1.2, 3.6)
		local ax = tx - dir * KUROEN_GAP
		local up = v(0, 1, 0)
		local function add(p, q, k)
			k = k or 1
			return v(p.x + q.x * k, p.y + q.y * k, p.z + q.z * k)
		end
		-- a body's axes as the client turns it (3/4 toward the camera, Config.ModelYaw): forward,
		-- and the side toward the camera
		local turn = math.rad(ctx.config.ModelYaw or 22)
		local function axes(facing)
			return v(facing * math.cos(turn), 0, math.sin(turn)), v(-facing * math.sin(turn), 0, math.cos(turn))
		end
		local hisFwd = axes(dir)
		local itsFwd, itsSide = axes(-dir)
		-- (the lab rig's raised fist (his RISING UPPER) and kneeling chest, in each body's own axes:
		-- right, forward; only where the suns leave from is staged with them)
		local function rightOf(f) return v(-f.z, 0, f.x) end
		local hisFist = add(v(rightOf(hisFwd).x * 0.48, 0, rightOf(hisFwd).z * 0.48), hisFwd, 0.08)
		local itsChest = add(v(rightOf(itsFwd).x * 0.06, 0, rightOf(itsFwd).z * 0.06), itsFwd, 0.31)
		-- the shot of this tick (its angle also turns the rings toward the camera)
		local current
		for _, s_ in KUROEN_SHOTS do
			if tick < s_.to then
				current = s_
				break
			end
		end
		local yaw, pitch = math.rad(current.yaw * dir), math.rad(current.pitch)
		local toCamera = v(math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch))

		-- the fighters
		d.x, d.z, d.facing, d.hitstop = tx, nil, -dir, 0
		a.facing, a.z = dir, nil
		if tick < 110 then
			a.x, a.state, a.move, a.pose = tx - dir * KUROEN_FAR, "Idle", nil, "StandTall"
		elseif tick < 118 then
			-- CRIMSON STEP: on it in a blink
			a.x = lerp(tx - dir * KUROEN_FAR, ax, smooth(progress(tick, 110, 118)))
			attack(a, moves, T.role(ctx, "Rising"), true)
		else
			a.x = ax
		end
		local blow = nil
		for i, b in KUROEN_BLOWS do
			if tick >= b.tick - 14 and tick < b.tick + 20 then blow = i end
		end
		if tick >= 118 and tick < 296 then
			if blow then
				attack(a, moves, T.role(ctx, KUROEN_BLOWS[blow].role), tick >= KUROEN_BLOWS[blow].tick - 4)
			else
				a.state, a.move, a.pose = "Idle", nil, nil
			end
		elseif tick >= 296 and tick < F - 16 then
			attack(a, moves, T.role(ctx, "Uppercut"), true) -- (his fist raised: the suns come to it)
		elseif tick >= F - 16 and tick < F + 40 then
			attack(a, moves, T.role(ctx, "Hammer"), tick >= F - 4) -- (AXE OF NIGHT: both fists up, then down)
		elseif tick >= F + 40 then
			a.state, a.move, a.pose = "Idle", nil, "StandTall"
			a.x = lerp(ax, tx - dir * 3.6, smooth(progress(tick, F + 40, F + 80))) -- (half a step back from it)
			if tick < F + 80 then a.state, a.pose, a.vx = "Walking", nil, -dir * 1.2 end
		end
		if tick < 84 then
			d.state, d.pose = "Idle", nil
		elseif tick < 132 then
			d.state, d.pose = "Idle", "Block" -- (its guard up, for nothing)
		elseif tick < 180 then
			d.state, d.pose = "Hitstun", "HitBody"
		elseif tick < 186 then
			d.state, d.pose = "Hitstun", "CrumpleStart"
		elseif tick < F then
			d.state, d.pose = "Hitstun", "Kneel"
			if tick >= 252 and tick < 262 then d.x = tx + dir * 0.15 * math.sin(progress(tick, 252, 262) * math.pi) end
		else
			-- driven face down into the deck, a stud back
			d.state = "Hitstun"
			d.x = tx + dir * smooth(progress(tick, F, F + 10))
			d.pose = if tick < F + 6 then "Crumple" else "DownFace"
		end

		-- DOMINATION: the three red marks on his back, along his spine, lit one by one; they flare
		-- and are spent when he moves (their order: I high, III low)
		if tick >= 16 and tick < 110 then
			local back = v(-hisFwd.x, 0, -hisFwd.z)
			for k = 1, 3 do
				local lit = 16 + (k - 1) * 24
				if tick >= lit then
					local flare = 1 - progress(tick, lit, lit + 8) + progress(tick, 100, 110)
					local pos = P(A, "UpperTorso", v(back.x * 0.7, 0.42 - (k - 1) * 0.42, back.z * 0.7))
					shape(frame, { kind = "ring", pos = pos, normal = back, radius = 0.16 + 0.12 * flare, width = 0.07, color = color,
						alpha = math.clamp(0.15 + 0.5 * flare, 0, 0.95) })
				end
			end
		end
		-- the suns left on the target by his blows (its corona turned to the camera), then their
		-- flight to his raised fist
		local fist = P(A, "RightHand", v(0, 0.9, 0))
		local arrived = 0
		for i, b in KUROEN_BLOWS do
			local lift = KUROEN_LIFT[i]
			if tick >= b.tick and tick < lift + KUROEN_FLIGHT then
				local off = add(v(itsFwd.x * b.off[1], b.off[2], itsFwd.z * b.off[1]), itsSide, b.off[3])
				local q = smooth(progress(tick, lift, lift + KUROEN_FLIGHT))
				local pos = P(D, b.part, off)
				if q > 0 then
					-- (from the body to his fist, hung on his real fist all the way: it lands in it on
					-- every avatar; only where it leaves from is staged, the gap between its chest and
					-- his raised fist as the lab's rig has them, B-013)
					local gap = add(add(add(v(tx - ax, 2.91 - 6.27 - 0.9, 0), off), itsChest), hisFist, -1)
					pos = P(A, "RightHand", v(gap.x * (1 - q), 0.9 + gap.y * (1 - q) + 1.4 * math.sin(math.pi * q), gap.z * (1 - q)))
				end
				shape(frame, { kind = "ring", pos = pos, normal = toCamera, radius = lerp(0.3, 0.2, q), width = 0.08, color = color,
					alpha = 0.2 + 0.3 * q, mark = i })
			elseif tick >= lift + KUROEN_FLIGHT then
				arrived += 1
			end
		end
		-- THE BLACK SUN: in his raised fist, growing with each sun it takes; brought down with both
		-- fists; driven into the deck under the target
		if arrived > 0 and tick < F + 18 then
			local r = 0.26 + 0.18 * (arrived - 1) + 0.04 * math.sin(tick / 5)
			local pos = fist
			if tick >= F - 16 and tick < F then
				pos = P(A, "RightHand", v(0, 0.6, 0))
			elseif tick >= F then
				local q = progress(tick, F, F + 18)
				pos = At(v(tx + dir * 0.3, lerp(1.6, -0.4, q), 0.3))
				r *= 1 - 0.6 * q
			end
			shape(frame, { kind = "sphere", pos = pos, radius = r, color = KUROEN_SUN, core = 0 })
			shape(frame, { kind = "ring", pos = pos, normal = toCamera, radius = r * 1.45, width = 0.1, color = color, alpha = 0.1 })
		end
		if tick >= 300 and tick < F then
			shape(frame, { kind = "motes", pos = fist, radius = 2.2, count = 18, color = color, phase = tick / 40 })
			o.tint = { color = "40101A", amount = 0.3 * smooth(progress(tick, 300, 340)) }
		end
		-- the blow: the corona runs along the floor, the deck breaks under it, his seal
		if tick >= F and tick < F + 80 then
			local age = tick - F
			for j = 0, 1 do
				local q = smooth(progress(age, j * 8, 44 + j * 8))
				if q > 0 then
					shape(frame, { kind = "ring", pos = At(v(tx + dir, 0.08, 0)), normal = up, radius = lerp(0.8, 6.5 - j * 2, q), width = 0.22,
						color = if j == 0 then color else "FFFFFF", alpha = progress(age, 24 + j * 8, 70) })
				end
			end
			if age < 40 then
				shape(frame, { kind = "motes", pos = At(v(tx + dir, 1, 0.4)), radius = 4, count = 26, color = color, phase = age / 40, out = true })
			end
			if age == 0 then
				T.impact(frame, "bs-blow", v(tx + dir * 0.4, 1.4, 0.4), color, 2.6)
				table.insert(frame.fx, { key = "bs-seal", kind = "eclipseSeal", pos = v(tx + dir, 0, 0), color = color, radius = 3.4 })
				table.insert(frame.fx, { key = "bs-debris", kind = "debris", pos = v(tx + dir, 0.4, 0), color = color, scale = 1.2 })
				sfx(frame, "bs-blow", "heavy")
				sfx(frame, "bs-boom", "boom")
			end
			frame.quake = if age < 10 then 0.9 else nil
			frame.speedLines = if age < 12 then color else nil
		end

		-- the blows: a small black sun at each impact (KitFX: his own), a spark, the gauntlet on bone
		for i, b in KUROEN_BLOWS do
			if tick == b.tick then
				local p = v(tx - dir * 0.5, b.burst, 0.5)
				table.insert(frame.fx, { key = "bs-sun" .. i, kind = "eclipse", pos = p, color = color, scale = 0.12, life = 0.75 }) -- (gone before the next: one light)
				T.spark(frame, "bs-hit" .. i, p, color, 1.2)
				frame.impact = { key = "bs-hit" .. i, color = color }
				sfx(frame, "bs-hit" .. i, b.sound)
				if i == 3 then sfx(frame, "bs-hit-boom", "boom") end
			end
			if tick >= b.tick and tick < b.tick + 6 then frame.quake = 0.4 end
		end
		if tick == 110 then
			table.insert(frame.fx, { key = "bs-step", kind = "afterimage", slot = A, color = color, life = 0.35 })
			sfx(frame, "bs-step", "whoosh")
		end
		if tick == 16 or tick == 40 then sfx(frame, "bs-mark" .. tick, "charge") end
		if tick == 64 then sfx(frame, "bs-mark-iii", "boom") end
		if tick == 300 then sfx(frame, "bs-lift", "charge") end
		if tick == F - 16 then sfx(frame, "bs-raise", "whoosh") end
		if tick == F + 60 then sfx(frame, "bs-ko", "boom") end
		-- his grade (the light falls) from DOMINATION III; his aura while it lasts
		frame.grade.eclipse = tick >= 64
		if tick >= 64 and tick < 118 then frame.aura = A end
		ko(ctx, frame, tick, F + 60, color, if tick < F + 140 then { bg = KUROEN_SUN, splash = color } else nil)

		-- the shot
		local subjects = if current.subjects == "a" then { a } elseif current.subjects == "d" then { d } else { a, d }
		if current.sky then table.insert(subjects, { point = true, x = a.x, y = current.sky, z = 0 }) end
		frame.shot = frameOn(current.name, dir, subjects, { yaw = current.yaw, pitch = current.pitch, band = current.band, fill = current.fill,
			fov = current.fov, screen = current.screen, focus = P(if current.focus[1] == "A" then A else D, current.focus[2]) })
	end

	-- ================================================================ ELIAN · FINAL MERCY
	-- The healer gives too much light. 0:00 he walks to the target, calm, a halo over his head ·
	-- 0:01 his palm on its chest: the light pours in, it glows · 0:03 the light lifts it in a
	-- pillar; seven halos come down round it · 0:05 the light grows until the world goes white;
	-- silence · 0:07 it gathers to a point and bursts in a cross · 0:08 it comes down slowly out of
	-- the light, asleep.
	function S.ELIAN(ctx, frame, a, d, tick, dir)
		local A, D = ctx.cin.attacker, ctx.cin.defender
		local moves = ctx.moveData.Moves
		local color = ctx.characters[A].Energy
		local cx = T.center(ctx, d)
		local F = 450
		local GOLD = "FFF2B0"
		frame.grade.holy = true
		d.x, d.facing = cx, -dir
		local up = smooth(progress(tick, 210, 290))
		if tick < F + 10 then
			shape(frame, { kind = "ring", pos = P(A, "Head", v(0, 1.1, 0)), normal = v(0, 1, 0), radius = 0.7, width = 0.1, color = GOLD, alpha = 0.2 })
		end
		if tick < 90 then
			-- he walks to it, calm
			local q = smooth(progress(tick, 0, 70))
			a.x, a.facing = cx - dir * lerp(5.5, 2.4, q), dir
			if q < 1 then a.state, a.move, a.vx = "Walking", nil, dir * 2 else attack(a, moves, T.role(ctx, "PalmStrike"), false) end
			d.state = "Hitstun"
			frame.shot = frameOn("elian-fm-walk", dir, { a, d }, { yaw = lerp(10, 30, q), pitch = -6, fill = 0.66, fov = 38, focus = P(A, "Head") })
		elseif tick < 210 then
			-- his palm on its chest: the light pours in
			a.x, a.facing = cx - dir * 2.4, dir
			attack(a, moves, T.role(ctx, "BodyBlow"), true)
			d.state, d.pose = "Hitstun", "HitBody"
			local glow = progress(tick, 90, 210)
			shape(frame, { kind = "motes", pos = P(D, "UpperTorso"), radius = 1.6, count = math.floor(6 + 18 * glow), color = GOLD, phase = tick / 40 })
			shape(frame, { kind = "ring", pos = At(v(cx - dir * 1.2, 0.08, 0)), normal = v(0, 1, 0), radius = 3.2, width = 0.16, color = GOLD, alpha = 0.4 })
			if tick == 90 then sfx(frame, "fm-touch", "charge") end
			frame.shot = frameOn("elian-fm-touch", dir, { a, d }, { yaw = 8, pitch = -4, band = "bust", fill = 0.8, fov = 32, focus = P(D, "Head") })
		elseif tick < F then
			-- the pillar lifts it; seven halos come down; the world goes white
			a.x, a.facing = cx - dir * 3.4, dir
			attack(a, moves, T.role(ctx, "Finale"), false)
			d.y, d.state, d.pose = 4 * up, "Hitstun", "Launched"
			if tick == 210 then
				table.insert(frame.fx, { key = "fm-pillar", kind = "lightPillar", pos = v(cx, 0, 0), radius = 1.8, scale = 1.6, color = GOLD, life = 4 })
				sfx(frame, "fm-pillar", "beam")
			end
			shape(frame, { kind = "beam", from = At(v(cx, 0, 0)), to = At(v(cx, 30, 0)), radius = 0.6 + 1.2 * up, color = GOLD, rings = tick / 30 })
			for i = 0, 6 do
				local born = 240 + i * 18
				local q = progress(tick, born, born + 40)
				if q > 0 then
					shape(frame, { kind = "ring", pos = At(v(cx, lerp(14, 2 + i * 0.6, smooth(q)), 0)), normal = v(0, 1, 0), radius = 1.6 + 0.15 * i, width = 0.14,
						color = GOLD, alpha = 0.15 })
				end
			end
			local white = smooth(progress(tick, 360, F - 20))
			overlay(frame).desat = 0.85 * white
			if tick < 360 then
				frame.shot = frameOn("elian-fm-pillar", dir, { a, d, { point = true, x = cx, y = 10, z = 0 } }, { yaw = 20, pitch = -22, fill = 0.7, fov = 44,
					focus = P(D, "UpperTorso") })
			else
				frame.shot = frameOn("elian-fm-white", dir, { a }, { yaw = 30, pitch = -6, band = "bust", fill = 0.85, fov = 30, focus = P(A, "Head") })
			end
		else
			-- the light gathers to a point and bursts in a cross; it comes down, asleep
			local age = tick - F
			a.x, a.facing = cx - dir * 3.4, dir
			if age < 50 then attack(a, moves, T.role(ctx, "Finale"), true) else a.state, a.move, a.pose = "Idle", nil, "StandTall" end
			local q = smooth(progress(tick, F + 20, F + 90))
			if q < 1 then
				d.y, d.state, d.pose = 4 * (1 - q), "Hitstun", "Launched"
			else
				d.y = 0
				T.FATAL.fall(ctx.cin, d, tick, F + 90, 0)
				if d.pose == "Kneel" then d.pose = "DownFace" end
			end
			if age == 0 then
				sfx(frame, "fm-cross", "boom")
				frame.impact = { key = "fm-cross", color = "FFFFFF" }
			end
			if age < 40 then
				local k = age / 40
				local c = v(cx, 4 + 3.2, 0)
				shape(frame, { kind = "beam", from = At(v(c.x, c.y - 8 * (1 - k * 0.5), 0)), to = At(v(c.x, c.y + 8 * (1 - k * 0.5), 0)), radius = 0.6 * (1 - k), color = "FFFFFF",
					rings = age / 10 })
				shape(frame, { kind = "beam", from = At(v(c.x - 6 * (1 - k * 0.5), c.y + 1.4, 0)), to = At(v(c.x + 6 * (1 - k * 0.5), c.y + 1.4, 0)),
					radius = 0.5 * (1 - k), color = GOLD, rings = age / 10 })
				shape(frame, { kind = "sphere", pos = At(c), radius = lerp(0.3, 3, k), color = GOLD, core = 1 - k })
			end
			overlay(frame).desat = 0.85 * (1 - smooth(progress(tick, F, F + 30)))
			if age < 50 then
				frame.shot = frameOn("elian-fm-cross", dir, { d }, { yaw = 16, pitch = -10, fill = 0.5, fov = 44, focus = P(D, "UpperTorso") })
			else
				frame.shot = frameOn("elian-fm-after", dir, { a, d }, { yaw = -30, pitch = -2, fill = 0.6, fov = 38, focus = P(A, "Head") })
			end
			ko(ctx, frame, tick, F + 50, color)
		end
	end

	return S
end

return Finishers
