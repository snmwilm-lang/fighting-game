--[[
	QUICK TRASH TALK (pure Luau: no Roblox API, no require). Predefined taunts only: a player
	never types a word. The client only ever sends a SLOT NUMBER (1 to 6) of its equipped
	wheel; the server reads which taunt that slot holds in the SAVED profile, checks the
	cooldown and broadcasts it to the match. A forged text, an unknown taunt or a locked one
	can therefore never reach another player.

	To add a taunt: one line in LIST (a stable id, the text, optionally `unlock` = a check on
	the saved profile: an achievement `stat`, a SHOP item bought with coins `item`
	(profile.ownedItems, StoreConfig.ITEMS), or a Game Pass `pass` (profile.passes)). Its id must
	never change (the profiles keep ids).
	Used by: server (init.server.luau), client (TauntController, MenuController). Tests: Lobby.
]]
local Taunts = {}

Taunts.COOLDOWN = 5 -- seconds between two taunts of the same player (checked by the server)
Taunts.DURATION = 2 -- seconds a bubble stays up
Taunts.SLOTS = 6 -- taunts on the wheel
Taunts.KEYS = { "V", "B", "N", "Y", "X" } -- keyboard keys the wheel can be opened with (SETTINGS)

Taunts.LIST = {
	{ id = "ez", text = "EZ 😂" },
	{ id = "bozo", text = "BOZO 🤡" },
	{ id = "slow", text = "TOO SLOW 💀" },
	{ id = "cry", text = "CRY ABOUT IT 😭" },
	{ id = "skill", text = "SKILL ISSUE" },
	{ id = "bro", text = "BRO???" },
	{ id = "good", text = "YOU GOOD? 💀" },
	{ id = "runback", text = "RUN IT BACK" },
	{ id = "nicetry", text = "NICE TRY" },
	{ id = "lol", text = "LOL" },
	{ id = "sitdown", text = "SIT DOWN" },
	{ id = "what", text = "WHAT WAS THAT?!" },
	-- Earned (achievements, challenges): shown locked until then.
	{ id = "godslayer", text = "GOD SLAIN 👑", unlock = { stat = "asuraGrade", min = 1, how = "Beat ASURA (CHALLENGE)" } },
	{ id = "eclipse", text = "ECLIPSED 🌑", unlock = { stat = "shinGrade", min = 1, how = "Beat KUROEN SHIN (CHALLENGE)" } },
	{ id = "veteran", text = "GG, GO NEXT", unlock = { stat = "wins", min = 25, how = "Win 25 versus matches" } },
	-- SHOP (StoreConfig.ITEMS, EMOTE): bought with coins, or the SUPPORTER pass's own.
	{ id = "calculated", text = "CALCULATED 🧠", unlock = { item = "EMOTE_CALCULATED", how = "SHOP" } },
	{ id = "framedata", text = "FRAME DATA 📊", unlock = { item = "EMOTE_FRAMEDATA", how = "SHOP" } },
	{ id = "whosnext", text = "WHO'S NEXT?", unlock = { item = "EMOTE_WHOSNEXT", how = "SHOP" } },
	{ id = "breakframed", text = "BREAKFRAMED 💥", unlock = { item = "EMOTE_BREAKFRAMED", how = "SHOP" } },
	{ id = "respect", text = "RESPECT 🤝", unlock = { pass = "SUPPORTER", how = "SUPPORTER pass" } },
}

Taunts.BY_ID = {}
for i, taunt in Taunts.LIST do
	taunt.order = i
	Taunts.BY_ID[taunt.id] = taunt
end

Taunts.DEFAULT = { "ez", "bozo", "slow", "skill", "runback", "nicetry" }

-- Is `id` a taunt this profile (or menu status) may use?
function Taunts.unlocked(id, profile)
	local taunt = Taunts.BY_ID[id]
	if not taunt then return false end
	if not taunt.unlock then return true end
	local u = taunt.unlock
	if u.item then
		return type(profile) == "table" and type(profile.ownedItems) == "table" and profile.ownedItems[u.item] == true
	end
	if u.pass then
		return type(profile) == "table" and type(profile.passes) == "table" and profile.passes[u.pass] == true
	end
	local value = type(profile) == "table" and tonumber(profile[taunt.unlock.stat]) or 0
	return value >= taunt.unlock.min
end

-- A clean wheel from anything (a saved list, a client request): known, unlocked, no
-- duplicates, at most SLOTS; the defaults fill what is missing.
function Taunts.sanitize(list, profile)
	local out, seen = {}, {}
	if type(list) == "table" then
		for _, id in list do
			if #out >= Taunts.SLOTS then break end
			if type(id) == "string" and not seen[id] and Taunts.unlocked(id, profile) then
				seen[id] = true
				table.insert(out, id)
			end
		end
	end
	for _, id in Taunts.DEFAULT do
		if #out >= Taunts.SLOTS then break end
		if not seen[id] then
			seen[id] = true
			table.insert(out, id)
		end
	end
	return out
end

-- The server's check for a taunt request: `slot` must be an integer 1..SLOTS of the wheel,
-- the cooldown over. Returns the taunt id or nil and why.
function Taunts.request(state, wheel, slot, now)
	if type(slot) ~= "number" or slot ~= slot or slot % 1 ~= 0 or slot < 1 or slot > Taunts.SLOTS then
		return nil, "malformed"
	end
	local id = wheel and wheel[slot]
	if not id or not Taunts.BY_ID[id] then return nil, "empty" end
	if now - (state.last or -math.huge) < Taunts.COOLDOWN then return nil, "cooldown" end
	state.last = now
	return id, nil
end

-- Seconds left before the next taunt (the wheel greys out meanwhile).
function Taunts.cooldownLeft(last, now)
	return math.max(0, Taunts.COOLDOWN - (now - (last or -math.huge)))
end

return Taunts
