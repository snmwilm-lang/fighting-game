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
