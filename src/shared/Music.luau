--[[
	The in-game music (pure Luau: no Roblox API, no require). The game ships no music asset
	and no asset id is ever invented, so the music is played by a sequencer from the sounds of
	the Roblox client itself (SoundPalette.FILES): taiko drums, kicks and snares from the body
	thud, hi-hats and koto-like plucks from the dry click pitched to a scale, whooshes from the
	wind, accents from the explosion, through the engine's reverb and echo. Each stage has its
	own theme (tempo, scale, groove, melody), the menu its calm one, ASURA his own, and his
	SECOND LIFE a faster, darker one. The fight raises the music by layers:
	  1 CALM    the menu, the round intro: drums and the melody, softly
	  2 FIGHT   the full groove
	  3 CLUTCH  a fighter under 30 % or the deciding round: double-time hats, taiko rolls
	Played by src/client/MusicController.luau; checked by tests/Kits.test.luau.

	Wilhem can give the game its own music later (uploaded audio of his): Music.CUSTOM maps a
	theme to an asset id; a theme with one plays it in a loop instead of the sequencer.

	Pattern strings have one character per sixteenth note: "x" a hit, "X" an accent, "." a
	rest. A melody string gives scale degrees: "1"-"9" (1 = the root, the scale repeats an
	octave up past its length), "." a rest, "-" the note held (nothing new is played).
]]
local Music = {}

-- Theme -> "rbxassetid://..." of an uploaded audio (none: the sequencer plays).
Music.CUSTOM = {}

-- The instruments: a client sound (SoundPalette.FILES key), its volume, its speed (pitch),
-- a length (seconds, nil = the whole sound) and a bus (SoundPalette.BUSES, nil = dry).
Music.VOICES = {
	taiko = { "thud", 0.75, 0.5, nil, "hall" },
	kick = { "thud", 0.6, 0.78 },
	snare = { "thud", 0.42, 2.05 },
	clap = { "tick", 0.32, 0.62, nil, "hall" },
	hat = { "tick", 0.16, 2.9, 0.05 },
	rim = { "tick", 0.28, 1.35, 0.08 },
	shaker = { "wind", 0.12, 3, 0.05, "thin" },
	swell = { "wind", 0.28, 0.55, 1.1 },
	boom = { "boom", 0.3, 0.62, 0.9, "hall" },
	chain = { "tick", 0.3, 0.42, 0.1, "crunch" },
	drip = { "splash", 0.22, 1.6, 0.25, "echo" },
	pluck = { "tick", 0.36, 1, 0.22, "hall" }, -- the melody (pitched to the scale)
	bass = { "thud", 0.5, 0.5, 0.35 }, -- the bass line (pitched to the scale)
}

-- One octave of each scale, in semitones from the root.
local SCALES = {
	miyako = { 0, 1, 5, 7, 8 }, -- the Japanese "in" scale
	hirajoshi = { 0, 2, 3, 7, 8 },
	minorPenta = { 0, 3, 5, 7, 10 },
	phrygianDom = { 0, 1, 4, 5, 7, 8, 10 },
	majorPenta = { 0, 2, 4, 7, 9 },
	lydian = { 0, 2, 4, 6, 7, 9, 11 },
	demon = { 0, 1, 3, 6, 7 },
}
Music.SCALES = SCALES

--[[
	A theme: tempo (beats per minute, four sixteenths a beat), its scale, the pitch of its root
	(speed of the pluck and of the bass), and its layers. Each layer: voice -> one bar pattern
	(16) or several bars (a list, played in turn). melody / bass: one string per bar, in turn.
]]
Music.THEMES = {
	MENU = { tempo = 92, scale = "minorPenta", root = 0.9, bassRoot = 0.5,
		calm = { taiko = "x.......x.....x.", hat = "..x...x...x...x.", swell = "x..............." },
		fight = {}, clutch = {},
		melody = { "1...3...5-..4...", "3...2...1-......", "5...4...3...5...", "6-..5...3-..2..." },
		bass = { "1.......1.......", "1.......5.......", "4.......4.......", "5.......1......." } },
	TEMPLE = { tempo = 124, scale = "miyako", root = 1, bassRoot = 0.5,
		calm = { taiko = "x.......x.......", rim = "....x.......x..." },
		fight = { taiko = "x..x....x.x.....", kick = "x.......x.......", snare = "....X.......X...", hat = "x.x.x.x.x.x.x.x.",
			clap = "............x..." },
		clutch = { taiko = { "x..x..x.x.x.xxxx", "x..x..x.x..xx.x." }, hat = "xxxxxxxxxxxxxxxx", boom = "x..............." },
		melody = { "1..2..4-5.....4.", "5..4..2-1.......", "4..5..7-8..7..5.", "4.2.1...2-......" },
		bass = { "1.....1...1.....", "1.....5...5.....", "4.....4...4.....", "2.....2...5....." } },
	FROZEN = { tempo = 104, scale = "hirajoshi", root = 1.2, bassRoot = 0.6,
		calm = { taiko = "x...............", hat = "....x.......x..." },
		fight = { kick = "x.....x...x.....", rim = "....x.......x.x.", hat = "x...x...x...x...", drip = "..........x....." },
		clutch = { kick = "x.x...x.x.x...x.", hat = "x.xxx.xxx.xxx.xx", taiko = "x.......x...x.x." },
		melody = { "5-..4...3...1...", "2-..3...5-......", "8-..7...5...4...", "3...2...1-......" },
		bass = { "1...............", "1.......4.......", "3...............", "4.......5......." } },
	NEON = { tempo = 150, scale = "minorPenta", root = 1.15, bassRoot = 0.55,
		calm = { kick = "x...x...x...x...", hat = "..x...x...x...x." },
		fight = { kick = "x...x...x...x...", snare = "....X.......X...", hat = "xxxxxxxxxxxxxxxx", clap = "....x.......x..x",
			shaker = "..x...x...x...x." },
		clutch = { kick = "x.x.x.x.x.x.x.x.", snare = { "....X.......X.XX", "....X..X....XXXX" }, boom = "x..............." },
		melody = { "1.1.3.1.5.4.3...", "1.1.3.1.6.5.4...", "8.7.5.4.3.4.5...", "3.4.3.1.2.1-...." },
		bass = { "1.1.1.1.1.1.1.1.", "4.4.4.4.4.4.4.4.", "6.6.6.6.5.5.5.5.", "1.1.1.1.5.5.5.5." } },
	VOLCANO = { tempo = 118, scale = "phrygianDom", root = 0.85, bassRoot = 0.45,
		calm = { taiko = "x.......x.......", boom = "x..............." },
		fight = { taiko = "X..x..x.X..x....", kick = "x..x..x.x..x....", snare = "....X.......X...", chain = "......x.......x." },
		clutch = { taiko = { "X.xX.xX.X.xX.xxx", "X.xX.xX.XxXxXxXx" }, boom = "x.......x.......", hat = "x.x.x.x.x.x.x.x." },
		melody = { "1.2.3-..2.1.....", "1.2.3.5.6-..5...", "8.7.6.5.3-..2...", "1.2.1-..7.1-...." },
		bass = { "1..1..1.1..1....", "1..1..1.2..2....", "6..6..6.5..5....", "1..1..2.1......." } },
	BAMBOO = { tempo = 112, scale = "majorPenta", root = 1.1, bassRoot = 0.55,
		calm = { rim = "x...x...x...x...", shaker = "..x...x...x...x." },
		fight = { kick = "x.....x.x.......", rim = "..x...x...x.x.x.", shaker = "x.x.x.x.x.x.x.x.", snare = "....x.......x..." },
		clutch = { kick = "x...x.x.x...x.x.", rim = "xxx.xxx.xxx.xxx.", taiko = "x.......x.x....." },
		melody = { "1.2.3.5.6.5.3...", "2.3.5.3.2.1.....", "5.6.8.6.5.3.2...", "3.2.1.2.1-......" },
		bass = { "1.......5.......", "2.......5.......", "4.......1.......", "5.......1......." } },
	SKY = { tempo = 100, scale = "lydian", root = 1.25, bassRoot = 0.62,
		calm = { swell = "x.......x.......", rim = "....x.......x..." },
		fight = { kick = "x.......x..x....", clap = "....x.......x...", hat = "..x...x...x...x.", swell = "x..............." },
		clutch = { kick = "x...x...x..xx...", hat = "x.xxx.xxx.xxx.xx", boom = "x..............." },
		melody = { "1-..3-..5-..7-..", "8-..7...6...5...", "4-..6-..8-..7...", "5...4...3-......" },
		bass = { "1...............", "6...............", "4...............", "5...............", } },
	ASURA = { tempo = 132, scale = "demon", root = 0.8, bassRoot = 0.42,
		calm = { taiko = "X.......X.......", boom = "x..............." },
		fight = { taiko = "X..x.xX..x..X.x.", kick = "x..x..x.x..x..x.", chain = "....x.......x...", snare = "....X.......X..." },
		clutch = { taiko = { "X.xX.xX.X.xX.xxx", "XxXxX.xX.xXxXxXx" }, boom = "x.......x.......", hat = "xxxxxxxxxxxxxxxx" },
		melody = { "1...2...1...4-..", "5...4...2...1...", "1.2.1.4.5-..4...", "2...1...7-..1..." },
		bass = { "1..1..1.1..1..1.", "2..2..2.2..2..2.", "4..4..4.4..4..4.", "2..2..1.1..1...." } },
	-- ASURA's SECOND LIFE: faster, lower, every layer at once.
	WRATH = { tempo = 164, scale = "demon", root = 0.7, bassRoot = 0.36,
		calm = { taiko = "XxX.XxX.XxX.XxXx" },
		fight = { kick = "x.x.x.x.x.x.x.x.", boom = "x.......x.......", chain = "..x...x...x...x.", snare = "....X.......X..X" },
		clutch = { hat = "xxxxxxxxxxxxxxxx", taiko = "XxXxXxXxXxXxXxXx" },
		melody = { "1.1.2.1.4.4.5.4.", "1.1.2.1.7.7.1...", "5.4.2.1.2.4.5...", "4.2.1.7.1-......" },
		bass = { "1.1.1.1.1.1.1.1.", "1.1.1.1.2.2.2.2.", "4.4.4.4.4.4.4.4.", "2.2.2.2.1.1.1.1." } },
}

-- Short stingers (one bar, played once): the round's FIGHT!, the K.O., the winner, the loser.
Music.STINGERS = {
	FIGHT = { taiko = "X...X...X.X.X...", boom = "x..............." },
	KO = { boom = "X...............", taiko = "x.x.x..........." },
	VICTORY = { taiko = "X.X.X...X.......", melody = "1.3.5.8-........" },
	DEFEAT = { taiko = "x.......x.......", melody = "5...4...2...1---" },
}

-- Pitch of a scale degree (1 = the root; past the scale's length, an octave up).
function Music.pitch(scaleName, degree, root)
	local scale = SCALES[scaleName] or SCALES.minorPenta
	local index = degree - 1
	local octave = math.floor(index / #scale)
	local semitone = scale[index % #scale + 1] + 12 * octave
	return (root or 1) * 2 ^ (semitone / 12)
end

local function pick(pattern, bar)
	if type(pattern) == "table" then return pattern[(bar - 1) % #pattern + 1] end
	return pattern
end

local function note(voice, accent, speed)
	local v = Music.VOICES[voice]
	return { voice = voice, file = v[1], volume = v[2] * (if accent then 1.3 else 1), speed = speed or v[3], length = v[4], bus = v[5] }
end

local function hits(out, layer, bar, i)
	for voice, pattern in layer do
		local p = pick(pattern, bar)
		local c = string.sub(p, i, i)
		if c == "x" or c == "X" then table.insert(out, note(voice, c == "X")) end
	end
end

local function line(out, theme, strings, bar, i, voice, root)
	if not strings then return end
	local p = pick(strings, bar)
	local degree = tonumber(string.sub(p, i, i))
	if degree and degree > 0 then table.insert(out, note(voice, false, Music.pitch(theme.scale, degree, root))) end
end

-- The notes of one sixteenth: theme id, intensity (1 calm, 2 fight, 3 clutch), the step
-- counted from the theme's start (1, 2, 3...). Returns a list of { voice, file, volume,
-- speed, length, bus }.
function Music.step(themeId, intensity, step)
	local theme = Music.THEMES[themeId] or Music.THEMES.MENU
	local bar, i = math.floor((step - 1) / 16) + 1, (step - 1) % 16 + 1
	local out = {}
	hits(out, theme.calm, bar, i)
	if intensity >= 2 then hits(out, theme.fight, bar, i) end
	if intensity >= 3 then hits(out, theme.clutch, bar, i) end
	line(out, theme, theme.melody, bar, i, "pluck", theme.root)
	if intensity >= 2 or themeId == "MENU" then line(out, theme, theme.bass, bar, i, "bass", theme.bassRoot) end
	return out
end

-- The notes of a stinger's sixteenth (i from 1 to 16), in a theme's scale.
function Music.stinger(name, themeId, i)
	local s = Music.STINGERS[name]
	local theme = Music.THEMES[themeId] or Music.THEMES.MENU
	local out = {}
	if not s then return out end
	for voice, pattern in s do
		if voice == "melody" then
			line(out, theme, pattern, 1, i, "pluck", theme.root)
		else
			local c = string.sub(pattern, i, i)
			if c == "x" or c == "X" then table.insert(out, note(voice, c == "X")) end
		end
	end
	return out
end

-- Seconds per sixteenth of a theme.
function Music.stepSeconds(themeId)
	local theme = Music.THEMES[themeId] or Music.THEMES.MENU
	return 60 / theme.tempo / 4
end

-- Which theme plays: the menu's, the stage's, ASURA's (his SECOND LIFE: WRATH).
-- state = { inMatch, map, boss (ASURA in the match), wrath (he rose again) }
function Music.themeFor(state)
	if not state.inMatch then return "MENU" end
	if state.wrath then return "WRATH" end
	if state.boss then return "ASURA" end
	return if Music.THEMES[state.map or ""] then state.map else "TEMPLE"
end

-- How hard the music plays. fight = { phase, hp = { share1, share2 }, deciding (the round
-- that can end the match) }.
function Music.intensity(fight)
	if not fight or fight.phase ~= "Fight" then return 1 end
	for _, share in fight.hp or {} do
		if share > 0 and share < 0.3 then return 3 end
	end
	if fight.deciding then return 3 end
	return 2
end

return Music
