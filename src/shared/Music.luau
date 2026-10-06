--[[
	The in-game music (pure Luau: no Roblox API, no require). Real tracks only: the game ships
	no music asset and no asset id is ever invented, so the tracks are the royalty-free audio
	Wilhem picks (Roblox Creator Store audio licensed for experiences, or his own uploads):
	  • a Sound dropped in Studio into ReplicatedStorage › Audio › Music, named after its slot
	    (MENU, BATTLE, TEMPLE, ..., ASURA, WRATH, VICTORY, DEFEAT); see docs/AUDIO.md;
	  • or an id in Music.CUSTOM below ("rbxassetid://...").
	A slot without a track falls back on a more general one (a stage on BATTLE, the SECOND LIFE
	on ASURA, ASURA on BATTLE); nothing at all: silence (never the old generated music).
	Played by src/client/MusicController.luau; checked by tests/Kits.test.luau.
]]
local Music = {}

-- Slot -> "rbxassetid://..." (optional; the Audio › Music folder works too). Never invented.
Music.CUSTOM = {}

-- WILHEM'S TRACKS (assets/music, given by Wilhem on 5 October 2026, loudness evened to -14
-- LUFS). Several tracks on one slot make a playlist: one plays to its end, then another (never
-- the same twice in a row). `id`: the "rbxassetid://..." Roblox gives once Wilhem uploads the
-- file (Studio › Asset Manager › Import, or create.roblox.com › Audio); "" until then (no id
-- invented): a Sound in Audio › Music named after the slot still works too. The four ids
-- below are Wilhem's uploads (Creator Hub, validated on 6 October 2026).
Music.TRACKS = {
	{ slot = "MENU", file = "assets/music/menu_1_be_and_obey.mp3", title = "Be And Obey", id = "rbxassetid://108751565199726" },
	{ slot = "MENU", file = "assets/music/menu_2_funk_break_beat.mp3", title = "Funk Break Beat", id = "rbxassetid://102119957612262" },
	{ slot = "BATTLE", file = "assets/music/battle_1_fast_amen_break.mp3", title = "Fast Amen Break", id = "rbxassetid://70875466407021" },
	{ slot = "BATTLE", file = "assets/music/battle_2_risky_step.mp3", title = "Risky Step", id = "rbxassetid://86152672257538" },
}

-- (Wilhem: « tourne partout, par extraits de 30/40 secondes »: the menu and the fights share
-- one playlist of all his tracks, played in turn, an excerpt of each.)
Music.SHARED = { MENU = true, BATTLE = true }
Music.EXCERPT = { min = 30, max = 40, edge = 4 }

-- The ids of a slot's tracks: Music.TRACKS (uploaded; every one of them on a SHARED slot)
-- then Music.CUSTOM.
function Music.idsFor(slotId)
	local out = {}
	for _, t in Music.TRACKS do
		if (t.slot == slotId or Music.SHARED[slotId]) and type(t.id) == "string" and string.match(t.id, "^rbxassetid://%d+$") then
			table.insert(out, t.id)
		end
	end
	local custom = Music.CUSTOM[slotId]
	if type(custom) == "string" then table.insert(out, custom) end
	return out
end

-- The next track of a slot's rotation (Wilhem: « les musiques, alterne-les, c'est en boucle
-- les mêmes, fais-les tourner »): after `last`, always the one after it, round the list; the
-- first time (`last` nil), a random start (`roll(n)` -> 1..n). Kept per slot across the menus
-- and the matches, so every track comes round in turn.
function Music.rotate(count, last, roll)
	if count <= 0 then return nil end
	if not last then return roll(count) end
	return (last % count) + 1
end

-- The rotation a slot follows: the SHARED slots one and the same (the menu and the fights carry
-- on the same turn), every other slot its own.
function Music.rotationKey(slotId)
	return if Music.SHARED[slotId] then "SHARED" else slotId
end

-- Which part of a track of `length` seconds to play: { start, duration }, an excerpt of 30 to
-- 40 s away from the very start and end (`roll()` -> 0..1). A track too short (or a length
-- not known yet: 0) plays from its start.
function Music.excerpt(length, roll)
	local E = Music.EXCERPT
	local duration = E.min + (E.max - E.min) * roll()
	if not length or length <= 0 then return { start = 0, duration = duration } end
	if length < duration + 2 * E.edge then return { start = 0, duration = math.min(duration, length) } end
	return { start = E.edge + (length - duration - 2 * E.edge) * roll(), duration = duration }
end

-- The next track of a playlist of `count`: never `last` again when there is another one.
-- `roll(n)` -> an integer 1..n (math.random in the game, fixed in the tests).
function Music.nextTrack(count, last, roll)
	if count <= 0 then return nil end
	if count == 1 then return 1 end
	local pick = roll(count - 1)
	if last and pick >= last then pick += 1 end
	return pick
end

-- Every slot, in the order docs/AUDIO.md lists them, with what it is for and the fallback.
Music.SLOTS = {
	{ id = "MENU", use = "menus, hub, character select" },
	{ id = "BATTLE", use = "any fight (the stages without a track of their own)" },
	{ id = "TEMPLE", use = "SCARLET TEMPLE", fallback = "BATTLE" },
	{ id = "FROZEN", use = "FROZEN LAKE", fallback = "BATTLE" },
	{ id = "NEON", use = "NEON ROOFTOP", fallback = "BATTLE" },
	{ id = "VOLCANO", use = "VOLCANO FORGE", fallback = "BATTLE" },
	{ id = "BAMBOO", use = "BAMBOO DOJO", fallback = "BATTLE" },
	{ id = "SKY", use = "CLOUD PALACE", fallback = "BATTLE" },
	{ id = "ASURA", use = "boss fights (ASURA, KUROEN SHIN)", fallback = "BATTLE" },
	{ id = "WRATH", use = "ASURA's SECOND LIFE", fallback = "ASURA" },
	{ id = "VICTORY", use = "short jingle: you win the match", stinger = true },
	{ id = "DEFEAT", use = "short jingle: you lose the match", stinger = true },
}
local BY_ID = {}
for _, slot in Music.SLOTS do BY_ID[slot.id] = slot end
Music.BY_ID = BY_ID

-- The slot the game wants now. state = { inMatch, map, boss, wrath }
function Music.themeFor(state)
	if not state.inMatch then return "MENU" end
	if state.wrath then return "WRATH" end
	if state.boss then return "ASURA" end
	return if BY_ID[state.map or ""] then state.map else "BATTLE"
end

-- The slot actually played: the wanted one or its first fallback that has a track.
-- has(slotId) -> true when a track exists for it. nil: no track at all (silence).
function Music.resolve(slotId, has)
	local seen = 0
	local id = slotId
	while id and seen < 8 do
		if has(id) then return id end
		id = BY_ID[id] and BY_ID[id].fallback
		seen += 1
	end
	return nil
end

-- How loud the music sits: under the cinematics it steps back, and a clutch moment (a fighter
-- under 30 %, the deciding round) brings it up a little. fight = { phase, hp, deciding, cinematic }
function Music.volume(fight)
	if fight.cinematic then return 0.45 end
	if fight.phase == "Fight" then
		if fight.deciding then return 1 end
		for _, share in fight.hp or {} do
			if share > 0 and share < 0.3 then return 1 end
		end
	end
	return 0.85
end

return Music
