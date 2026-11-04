--[[
	The owner's chat commands (Wilhem: « donne-moi la perm de give des trucs in game à des gens
	juste avec une ligne dans le chat »). Pure Luau: no Roblox API, no require (the catalogs are
	passed in). The server only listens to the game's owner (DevAccess.isOwner) and never to
	anyone else; this module reads the line and changes a profile.

	  !give <player|me|all> coins <amount>        coins (1 to 1 000 000 at once)
	  !give <player|me|all> fighter <KIT|ALL>     a fighter (or every fighter), forever
	  !give <player|me|all> style <STYLE>         a shop / quest style
	  !give <player|me|all> title <TITLE>         a title (a challenge or shop one; never a Game Pass one)
	  !give <player|me|all> item <ITEM ID>        a cosmetic of the shop (never a Game Pass one)
	  !help                                       the list, in the owner's chat
	Names are matched without caring about case, spaces or underscores; a player by the start
	of their name or display name. Tests: tests/Lobby.test.luau ("owner commands").
]]
local Admin = {}

Admin.MAX_COINS = 1000000
Admin.HELP = "!give <player|me|all> coins 1000 · fighter KAI|ALL · style <STYLE> · title <TITLE> · item <ID>"

local KINDS = {
	coins = "coins", coin = "coins", pieces = "coins", piece = "coins",
	fighter = "fighter", kit = "fighter", perso = "fighter",
	style = "style", skin = "style",
	title = "title", titre = "title",
	item = "item", cosmetic = "item",
}

local function key(text)
	return (string.gsub(string.upper(text or ""), "[%s_%-]", ""))
end
Admin.key = key

-- The command of a chat line, or nil (not a command) / nil, why.
function Admin.parse(text)
	if type(text) ~= "string" then return nil end
	local line = string.match(text, "^%s*(.-)%s*$")
	if string.sub(line, 1, 1) ~= "!" then return nil end
	local words = {}
	for w in string.gmatch(string.sub(line, 2), "%S+") do table.insert(words, w) end
	local verb = string.lower(words[1] or "")
	if verb == "help" then return { verb = "help" } end
	if verb ~= "give" then return nil end
	local target, kind = words[2], KINDS[string.lower(words[3] or "")]
	if not target or not kind then return nil, Admin.HELP end
	local value = table.concat(words, " ", 4)
	if value == "" then return nil, Admin.HELP end
	if kind == "coins" then
		local n = tonumber(value)
		if not n or n ~= math.floor(n) or n < 1 or n > Admin.MAX_COINS then return nil, "coins: a whole number from 1 to " .. Admin.MAX_COINS end
		return { verb = "give", target = target, kind = kind, amount = n }
	end
	return { verb = "give", target = target, kind = kind, value = value }
end

-- Gives `cmd` to `profile`. catalogs = { kits = { "KAI", ... }, styles = { [name] = true },
-- titles = { name, ... } (challenge titles), items = { [id] = item } (shop items: kind, name,
-- pass). Returns true and what was given, or false and why.
function Admin.apply(profile, cmd, catalogs)
	if type(profile) ~= "table" or type(cmd) ~= "table" then return false, "no profile" end
	local want = key(cmd.value)
	if cmd.kind == "coins" then
		profile.coins = (tonumber(profile.coins) or 0) + cmd.amount
		return true, cmd.amount .. " COINS"
	elseif cmd.kind == "fighter" then
		if type(profile.ownedKits) ~= "table" then profile.ownedKits = {} end
		if want == "ALL" then
			for _, kit in catalogs.kits do profile.ownedKits[kit] = true end
			return true, "EVERY FIGHTER"
		end
		for _, kit in catalogs.kits do
			if key(kit) == want then
				profile.ownedKits[kit] = true
				return true, kit
			end
		end
		return false, "unknown fighter " .. tostring(cmd.value)
	elseif cmd.kind == "style" then
		for name in catalogs.styles do
			if key(name) == want then
				if type(profile.ownedSkins) ~= "table" then profile.ownedSkins = {} end
				profile.ownedSkins[name] = true
				return true, "STYLE " .. name
			end
		end
		return false, "unknown style " .. tostring(cmd.value)
	elseif cmd.kind == "title" then
		for id, item in catalogs.items do
			if item.kind == "TITLE" and key(item.name) == want then
				if item.pass then return false, item.name .. " comes with a Game Pass" end
				if type(profile.ownedItems) ~= "table" then profile.ownedItems = {} end
				profile.ownedItems[id] = true
				return true, "TITLE " .. item.name
			end
		end
		for _, name in catalogs.titles do
			if key(name) == want then
				if type(profile.titles) ~= "table" then profile.titles = {} end
				if not table.find(profile.titles, name) then table.insert(profile.titles, name) end
				return true, "TITLE " .. name
			end
		end
		return false, "unknown title " .. tostring(cmd.value)
	elseif cmd.kind == "item" then
		for id, item in catalogs.items do
			if key(id) == want or key(item.name) == want then
				if item.pass then return false, tostring(item.name) .. " comes with a Game Pass" end
				if type(profile.ownedItems) ~= "table" then profile.ownedItems = {} end
				profile.ownedItems[id] = true
				return true, tostring(item.name or id)
			end
		end
		return false, "unknown item " .. tostring(cmd.value)
	end
	return false, "unknown"
end

-- The players a target names: "me", "all", or the ones whose name or display name starts with
-- it (case ignored). `players` = { { id, name, display } }. Several matches: none (ambiguous).
function Admin.targets(target, players, selfId)
	local t = string.lower(target or "")
	if t == "me" then
		for _, p in players do if p.id == selfId then return { p } end end
		return {}
	end
	if t == "all" then return table.clone(players) end
	local exact, start = {}, {}
	for _, p in players do
		local n, d = string.lower(p.name or ""), string.lower(p.display or "")
		if n == t or d == t then table.insert(exact, p)
		elseif string.sub(n, 1, #t) == t or string.sub(d, 1, #t) == t then table.insert(start, p) end
	end
	if #exact > 0 then return exact end
	return if #start == 1 then start else {}
end

return Admin
