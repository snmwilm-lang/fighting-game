--[[
	The economy of the fighters (pure Luau: no Roblox API, no require; the profile, the roster
	and whether the player has the developer access are passed in). The server applies it
	(init.server.luau) and is the only one to change coins or ownership; the menu only reads
	it to draw the locks and the prices.

	  • PvP rewards: a win WIN coins, a loss LOSS (a draw DRAW). The anti-farm rules
	    (AntiCheat: short matches, the same pair again and again, the daily cap) still apply;
	    a player who leaves a running match gets nothing.
	  • Fighters: FREE ones from the start, the others unlocked for FIGHTER_PRICE coins, kept
	    forever (profile.ownedKits[kit] = true).
	  • TRAINING: every fighter, owned or not (to try before buying); it never unlocks one.
	  • The developer access (src/server/DevAccess.luau, checked by the server): every fighter
	    in every mode and every style, WITHOUT writing them as bought; it can be switched off
	    (profile.devOff) to play as a new player.
	Tests: tests/Lobby.test.luau ("economy").
]]
local Economy = {}

Economy.WIN = 150
Economy.LOSS = 50
Economy.DRAW = 100 -- (not set by Wilhem: between the two)
Economy.FIGHTER_PRICE = 4000
Economy.SKIN_PRICE = 2500

-- The 8 free fighters (40 % of 20): simple to pick up and every family of play once (all-
-- rounder, boxer, kicks, power, endurance, grappler, support, attrition); the most striking
-- ones stay to unlock. (A proposal chosen by Claude on Wilhem's go-ahead: change the list here.)
Economy.FREE = table.freeze({ "KAI", "TARO", "ZEPHYR", "RYUKEN", "HIBECARES", "GORAN", "ELIAN", "VENOM" })

function Economy.isFree(kit)
	return table.find(Economy.FREE, kit) ~= nil
end

-- Does the profile own this fighter (free or bought)?
function Economy.owns(profile, kit)
	if Economy.isFree(kit) then return true end
	if type(profile) == "table" and profile.tester == true then return true end -- (the testers: every fighter)
	local owned = type(profile) == "table" and profile.ownedKits
	return type(owned) == "table" and owned[kit] == true
end

-- May this fighter be played in this mode? TRAINING: all of them; the developer: all of them.
function Economy.canPlay(profile, kit, mode, dev)
	if dev or mode == "TRAINING" then return true end
	return Economy.owns(profile, kit)
end

-- A whole team: true, or false and the first fighter that is locked.
function Economy.teamAllowed(profile, team, mode, dev)
	for _, kit in team or {} do
		if not Economy.canPlay(profile, kit, mode, dev) then return false, kit end
	end
	return true
end

-- Unlocks a fighter for coins (the server calls it on the saved profile). `roster`: the list
-- of the playable fighters (MoveData.KitOrder): a boss or an unknown name is never sold.
-- Returns true, or false and why: "unknown", "owned", "coins".
function Economy.buyFighter(profile, kit, roster)
	if type(profile) ~= "table" or type(kit) ~= "string" or not table.find(roster, kit) then return false, "unknown" end
	if Economy.owns(profile, kit) then return false, "owned" end
	local coins = tonumber(profile.coins) or 0
	if coins < Economy.FIGHTER_PRICE then return false, "coins" end
	if type(profile.ownedKits) ~= "table" then profile.ownedKits = {} end
	profile.coins = coins - Economy.FIGHTER_PRICE
	profile.ownedKits[kit] = true
	return true
end

-- THE TESTERS (Wilhem: « faut qu'ils aient accès à tous les persos »): a profile saved before
-- the fighters were sold (no ownedKits), or one that already got the old 3 free picks
-- (picksGiven), becomes a TESTER: every fighter, now and the ones added later (Economy.owns),
-- without writing them as bought. The server also makes testers of the UserIds it lists
-- (DevAccess.TESTER_IDS). Returns true when the profile just became a tester.
function Economy.makeTester(profile, saved)
	if type(profile) ~= "table" or profile.tester == true then return false end
	if type(saved) ~= "table" or (type(saved.ownedKits) == "table" and not saved.picksGiven) then return false end
	profile.tester = true
	return true
end

-- (the old free picks: kept for a profile that still has some, see claimFighter)
Economy.TESTER_PICKS = 3
function Economy.claimFighter(profile, kit, roster)
	if type(profile) ~= "table" or type(kit) ~= "string" or not table.find(roster, kit) then return false, "unknown" end
	if Economy.owns(profile, kit) then return false, "owned" end
	local picks = tonumber(profile.freePicks) or 0
	if picks < 1 then return false, "picks" end
	if type(profile.ownedKits) ~= "table" then profile.ownedKits = {} end
	profile.freePicks = picks - 1
	profile.ownedKits[kit] = true
	return true
end

-- The coins of a PvP result before the anti-farm share and the daily cap: "win", "loss",
-- "draw"; a player who left the match ("left") gets nothing.
function Economy.pvpCoins(result)
	if result == "win" then return Economy.WIN end
	if result == "loss" then return Economy.LOSS end
	if result == "draw" then return Economy.DRAW end
	return 0
end

return Economy
