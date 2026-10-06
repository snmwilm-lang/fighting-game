--[[
	THE STORE'S RULES (pure Luau: no Roblox API, no require; the configuration
	(StoreConfig), the profile, the passes and the time are passed in). The server applies them
	and is the only one to grant anything; the menu reads them to draw prices and statuses.

	  • Receipts (Developer Products): every PurchaseId granted is written in the profile
	    (profile.receipts) in the SAME save as what it gives. A receipt seen again (Roblox
	    retries until the server answers PurchaseGranted, a second server, a reconnection) is
	    never granted twice. The server answers PurchaseGranted only once that save succeeded.
	  • Game Passes: profile.passes keeps the last ownership the server confirmed (so an
	    unreachable Roblox service does not remove a perk); it is checked again at every join.
	  • Coin bonuses: fight coins only, added up, capped (StoreConfig.MAX_COIN_MULTIPLIER).
	  • Cosmetics: bought with coins (profile.ownedItems) or given by a pass; only an owned one
	    can be equipped (profile.cosmetics).
	Tests: tests/Lobby.test.luau ("store").
]]
local Store = {}

Store.KEEP_RECEIPTS = 200 -- receipts kept per profile (the oldest go first)

-- Lookup tables of a configuration (built once): passes, products by key and by id, items.
function Store.index(config)
	local idx = { pass = {}, passById = {}, product = {}, productById = {}, item = {}, styleProduct = {} }
	for _, p in config.PASSES do
		idx.pass[p.key] = p
		if p.id > 0 then idx.passById[p.id] = p end
	end
	for _, p in config.PRODUCTS do
		idx.product[p.key] = p
		if p.id > 0 then idx.productById[p.id] = p end
		if p.style then idx.styleProduct[p.style] = p end
	end
	for _, item in config.ITEMS do idx.item[item.id] = item end
	return idx
end

-- Is a Robux purchase of this pass / product possible: a real id, and the player's policy
-- allows it (`policy`: nil while unknown = no; `randomRestricted` blocks paid random items).
function Store.canPrompt(entry, policy)
	if type(entry) ~= "table" or type(entry.id) ~= "number" or entry.id <= 0 then return false end
	if type(policy) ~= "table" then return false end
	if entry.random and policy.randomRestricted ~= false then return false end
	return true
end

-- ===================================================================== passes
function Store.hasPass(profile, key)
	return type(profile) == "table" and type(profile.passes) == "table" and profile.passes[key] == true
end

-- Writes a pass ownership the server confirmed. Returns true when it changed.
function Store.setPass(profile, key, owned)
	if type(profile.passes) ~= "table" then profile.passes = {} end
	local now = owned == true
	if (profile.passes[key] == true) == now then return false end
	profile.passes[key] = if now then true else nil
	return true
end

-- The multiplier of the fight coins: 1 + the owned passes' bonuses, at most the cap.
function Store.coinMultiplier(config, profile)
	local m = 1
	for _, p in config.PASSES do
		if p.coinBonus and Store.hasPass(profile, p.key) then m += p.coinBonus end
	end
	return math.min(m, config.MAX_COIN_MULTIPLIER)
end

-- The coins of a fight (`base`: after the anti-farm share) with the passes' bonus.
function Store.fightCoins(config, base, profile)
	base = tonumber(base) or 0
	if base <= 0 then return 0 end
	return math.floor(base * Store.coinMultiplier(config, profile) + 0.5)
end

-- The badges shown next to the player's name (hub, player card): "VIP", "SUPPORTER".
function Store.badges(config, profile)
	local out = {}
	for _, p in config.PASSES do
		if p.badge and Store.hasPass(profile, p.key) then table.insert(out, p.badge) end
	end
	return out
end

-- ===================================================================== receipts
-- Grants a Developer Product's receipt to the profile. Returns "granted" (given now: save it),
-- "duplicate" (already given: nothing added) or "unknown" (not a product of the config).
-- (A style bought twice still records the receipt: nothing lost, nothing given twice.)
function Store.grantReceipt(profile, purchaseId, product, now)
	if type(profile) ~= "table" or type(purchaseId) ~= "string" or purchaseId == "" or type(product) ~= "table" then
		return "unknown"
	end
	if type(profile.receipts) ~= "table" then profile.receipts = {} end
	if profile.receipts[purchaseId] then return "duplicate" end
	if product.coins then
		profile.coins = (tonumber(profile.coins) or 0) + product.coins -- (never a pass bonus)
	elseif product.style then
		if type(profile.ownedSkins) ~= "table" then profile.ownedSkins = {} end
		profile.ownedSkins[product.style] = true
	else
		return "unknown"
	end
	profile.receipts[purchaseId] = now
	-- (the oldest receipts go past KEEP_RECEIPTS: Roblox stops retrying a granted one)
	local count, oldest, oldestTime = 0, nil, math.huge
	for id, t in profile.receipts do
		count += 1
		if type(t) ~= "number" or t < oldestTime then oldest, oldestTime = id, if type(t) == "number" then t else -math.huge end
	end
	if count > Store.KEEP_RECEIPTS and oldest ~= purchaseId then profile.receipts[oldest] = nil end
	return "granted"
end

-- ===================================================================== cosmetics
-- Does the profile own this cosmetic item (bought, or given by an owned pass)?
function Store.ownsItem(idx, profile, id)
	local item = idx.item[id]
	if not item or item.soon then return false end
	if item.pass then return Store.hasPass(profile, item.pass) end
	return type(profile) == "table" and type(profile.ownedItems) == "table" and profile.ownedItems[id] == true
end

-- Buys a cosmetic item with coins. Returns true, or false and why: "unknown", "soon" (not
-- made yet), "pass" (only with a Game Pass), "owned", "coins".
function Store.buyItem(idx, profile, id)
	local item = idx.item[id]
	if type(profile) ~= "table" or not item then return false, "unknown" end
	if item.soon then return false, "soon" end
	if item.pass or not item.coins then return false, "pass" end
	if Store.ownsItem(idx, profile, id) then return false, "owned" end
	local coins = tonumber(profile.coins) or 0
	if coins < item.coins then return false, "coins" end
	if type(profile.ownedItems) ~= "table" then profile.ownedItems = {} end
	profile.coins = coins - item.coins
	profile.ownedItems[id] = true
	if item.kind == "TITLE" then
		if type(profile.titles) ~= "table" then profile.titles = {} end
		if not table.find(profile.titles, item.name) then table.insert(profile.titles, item.name) end
	end
	return true
end

-- The titles a pass gives (shown while the pass is owned).
function Store.passTitle(idx, profile, title)
	for _, item in idx.item do
		if item.kind == "TITLE" and item.pass and item.name == title and Store.hasPass(profile, item.pass) then return true end
	end
	return false
end

-- Equips (`id`) or unequips (`id` = "") a cosmetic of a kind that is worn (VFX, VICTORY).
-- Returns true, or false and why: "kind", "unknown", "locked".
function Store.equip(idx, profile, kind, id)
	if kind ~= "VFX" and kind ~= "VICTORY" then return false, "kind" end
	if type(profile.cosmetics) ~= "table" then profile.cosmetics = {} end
	if id == "" then
		profile.cosmetics[kind] = nil
		return true
	end
	local item = idx.item[id]
	if not item or item.kind ~= kind then return false, "unknown" end
	if not Store.ownsItem(idx, profile, id) then return false, "locked" end
	profile.cosmetics[kind] = id
	return true
end

-- The cosmetic worn for a kind, or nil (one no longer owned, a lost pass: none).
function Store.equipped(idx, profile, kind)
	local id = type(profile) == "table" and type(profile.cosmetics) == "table" and profile.cosmetics[kind]
	if type(id) == "string" and Store.ownsItem(idx, profile, id) and idx.item[id].kind == kind then return id end
	return nil
end

-- The two colours of the aura worn ("RRGGBB,RRGGBB"), or "" (the kit's own).
function Store.auraColors(idx, profile)
	local id = Store.equipped(idx, profile, "VFX")
	if not id then return "" end
	local c = idx.item[id].colors
	return c[1] .. "," .. c[2]
end

return Store
