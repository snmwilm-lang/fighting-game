--[[
	THE STORE'S CONFIGURATION (pure data: no Roblox API, no require). Every Game Pass,
	Developer Product and cosmetic item of the SHOP lives here, and only here: the server
	(init.server.luau, with Store.luau) and the menu (MenuController) both read it.

	IDS: every `id = 0` is a PLACEHOLDER. No id is invented: Wilhem creates the pass or the
	product on the Creator Dashboard and pastes its real number here (docs/MONETISATION.md says
	how, step by step). While an id is 0, the item shows "SOON" and no Robux purchase can be
	started for it (the server refuses it too).

	PRICES: `robux` is only the price SHOWN in the menu. The real price is the one set on the
	Creator Dashboard: keep both equal. The prices below are proposals (provisional).

	RULES (Wilhem's brief):
	  • A Game Pass never gives a competitive advantage: no damage, health, speed, Elo, weekly
	    points, ranking or combat effect. Only cosmetics and more FIGHT COINS.
	  • Coin bonuses (`coinBonus`) add up on the base reward and are capped at
	    MAX_COIN_MULTIPLIER: VIP (+25 %) + DOUBLE REWARDS (+100 %) = ×2.25. They apply to the
	    coins of fights only (versus, survival, challenges), never to a Robux purchase (coin
	    packs), quests, refunds or anything else.
	  • No paid random item (no loot box). An item marked `random = true` would be refused to
	    players whose policy restricts paid random items (PolicyService): none exists.
	To add a Game Pass: one entry in PASSES (a new stable `key`), its perks handled where the
	key is read (Store.luau, the server). To add a product: one entry in PRODUCTS. A key must
	never change once players own it (the profiles keep keys).
	Tests: tests/Lobby.test.luau ("store").
]]
local StoreConfig = {}

StoreConfig.MAX_COIN_MULTIPLIER = 2.25

-- GAME PASSES: permanent, checked by the server at every join (UserOwnsGamePassAsync) and at
-- once after a purchase in the game.
StoreConfig.PASSES = {
	{
		key = "VIP", id = 0, robux = 299, name = "VIP", color = "FFD23F",
		perks = { "VIP badge in the lobby", "Exclusive gold name", "VIP GOLD aura (cosmetic)", "+25% fight coins" },
		coinBonus = 0.25, badge = "VIP", nameColor = "FFD23F",
	},
	{
		key = "DOUBLE", id = 0, robux = 199, name = "DOUBLE REWARDS", color = "FF2A3D",
		perks = { "x2 coins from fights", "Never on Robux purchases" },
		coinBonus = 1,
	},
	{
		key = "SUPPORTER", id = 0, robux = 99, name = "SUPPORTER", color = "FF6FA8",
		perks = { "SUPPORTER badge", "Exclusive SUPPORTER title", "Exclusive RESPECT emote" },
		badge = "SUPPORTER", title = "SUPPORTER", taunt = "respect",
	},
}

-- DEVELOPER PRODUCTS: bought as often as wanted (coins) or once (a style). Granted by the
-- server's ProcessReceipt only, after the profile is saved.
StoreConfig.PRODUCTS = {
	{ key = "COINS_1000", id = 0, robux = 99, name = "1,000 COINS", coins = 1000 },
	{ key = "COINS_3000", id = 0, robux = 249, name = "3,000 COINS", coins = 3000, tag = "POPULAR" },
	{ key = "COINS_7500", id = 0, robux = 499, name = "7,500 COINS", coins = 7500, tag = "BEST VALUE" },
	-- Shop styles also sold for Robux (the GOLD ones; still sold for coins in FIGHTERS). Price by
	-- the fighter's tier (Economy.TIERS): STANDARD / RARE 99, EPIC 149, LEGENDARY 199.
	{ key = "SKIN_KAI_GOLD", id = 0, robux = 99, style = "KAI GOLD" },
	{ key = "SKIN_AKEMI_GOLD", id = 0, robux = 199, style = "AKEMI GOLD" },
	{ key = "SKIN_SHIN_GOLD", id = 0, robux = 149, style = "SHIN GOLD" },
	{ key = "SKIN_RAIJIN_GOLD", id = 0, robux = 199, style = "RAIJIN GOLD" },
	{ key = "SKIN_VENOM_GOLD", id = 0, robux = 99, style = "VENOM GOLD" },
	{ key = "SKIN_HIBIKI_GOLD", id = 0, robux = 99, style = "HIBIKI GOLD" },
	{ key = "SKIN_KUREN_GOLD", id = 0, robux = 149, style = "KUREN GOLD" },
	{ key = "SKIN_NOVA_GOLD", id = 0, robux = 149, style = "NOVA GOLD" },
}

-- COSMETIC ITEMS, bought with coins (or given by a pass: `pass`). Kinds: TITLE (shown over the
-- hero and in the hub), EMOTE (a taunt of the wheel: Taunts.LIST, `taunt`), VFX (the colours
-- of the fighter's aura particles in a match: `colors`), VICTORY (victory animations: not made
-- yet, `soon = true`: shown as COMING SOON, never sold).
StoreConfig.ITEMS = {
	{ id = "TITLE_UNTOUCHABLE", kind = "TITLE", name = "UNTOUCHABLE", coins = 1500 },
	{ id = "TITLE_COMBO_ARTIST", kind = "TITLE", name = "COMBO ARTIST", coins = 1500 },
	{ id = "TITLE_FRAME_PERFECT", kind = "TITLE", name = "FRAME PERFECT", coins = 2500 },
	{ id = "TITLE_NO_MERCY", kind = "TITLE", name = "NO MERCY", coins = 2500 },
	{ id = "TITLE_FINAL_BOSS", kind = "TITLE", name = "FINAL BOSS", coins = 4000 },
	{ id = "TITLE_BREAKER", kind = "TITLE", name = "BREAKER", coins = 4000 },
	{ id = "TITLE_SUPPORTER", kind = "TITLE", name = "SUPPORTER", pass = "SUPPORTER" },

	{ id = "EMOTE_CALCULATED", kind = "EMOTE", name = "CALCULATED 🧠", taunt = "calculated", coins = 1200 },
	{ id = "EMOTE_FRAMEDATA", kind = "EMOTE", name = "FRAME DATA 📊", taunt = "framedata", coins = 1200 },
	{ id = "EMOTE_WHOSNEXT", kind = "EMOTE", name = "WHO'S NEXT?", taunt = "whosnext", coins = 1500 },
	{ id = "EMOTE_BREAKFRAMED", kind = "EMOTE", name = "BREAKFRAMED 💥", taunt = "breakframed", coins = 2000 },
	{ id = "EMOTE_RESPECT", kind = "EMOTE", name = "RESPECT 🤝", taunt = "respect", pass = "SUPPORTER" },

	{ id = "VFX_FROST", kind = "VFX", name = "FROST AURA", colors = { "BFEFFF", "4FB8FF" }, coins = 3000 },
	{ id = "VFX_EMBER", kind = "VFX", name = "EMBER AURA", colors = { "FFB347", "FF3A12" }, coins = 3000 },
	{ id = "VFX_SHADOW", kind = "VFX", name = "SHADOW AURA", colors = { "B060FF", "2A0A3A" }, coins = 3000 },
	{ id = "VFX_SAKURA", kind = "VFX", name = "SAKURA AURA", colors = { "FFC6DC", "FF6FA8" }, coins = 3000 },
	{ id = "VFX_VOID", kind = "VFX", name = "VOID AURA", colors = { "1AE6D2", "0A2A3A" }, coins = 3000 },
	{ id = "VFX_VIP_GOLD", kind = "VFX", name = "VIP GOLD AURA", colors = { "FFF1B0", "E8B21C" }, pass = "VIP" },

	{ id = "VICTORY_THRONE", kind = "VICTORY", name = "THRONE", soon = true },
	{ id = "VICTORY_SHOWBOAT", kind = "VICTORY", name = "SHOWBOAT", soon = true },
	{ id = "VICTORY_MEDITATION", kind = "VICTORY", name = "MEDITATION", soon = true },
}

-- FEATURED tab: what is shown first (kind: "pass", "product", "item"; key: its key / id).
StoreConfig.FEATURED = {
	{ kind = "pass", key = "VIP" },
	{ kind = "product", key = "COINS_3000" },
	{ kind = "product", key = "SKIN_KAI_GOLD" },
	{ kind = "item", key = "VFX_FROST" },
	{ kind = "pass", key = "SUPPORTER" },
	{ kind = "item", key = "TITLE_BREAKER" },
}

-- The kinds of the COSMETICS tab, in order (SKIN: the shop styles of CharacterData.SHOP).
StoreConfig.KINDS = { "SKIN", "TITLE", "EMOTE", "VFX", "VICTORY" }

return StoreConfig
