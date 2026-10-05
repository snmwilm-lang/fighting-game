--[[
	The developer access (pure Luau: no Roblox API, no require; the ids are passed in). Lives
	on the server only (ServerScriptService: never sent to a client), and only the server asks
	it.

	Who: the Roblox UserIds in IDS, the owner of the game when it belongs to a user (the
	place's CreatorId, read by the server: in a game owned by Wilhem's account, Wilhem), and in
	Roblox Studio the account playing ALONE (Play: the one editing the place; an unpublished
	place has no owner yet, CreatorId 0). Never "everyone in Studio": a Studio test player has a
	negative UserId (-1, -2...) and is refused, and a test with several players gets nothing.
	The server writes in the Output who has it and why not (to find the UserId to put in IDS).

	What: every fighter in every mode and every style, without buying (Economy.canPlay,
	CharacterData.canWear get `dev`); nothing is written as bought in the profile, so switching
	it off (profile.devOff, from SETTINGS) gives the real experience of a new player.
	Tests: tests/Lobby.test.luau ("developer access").
]]
local DevAccess = {}

-- Wilhem's Roblox UserIds (numbers). Add an id here to give a second account the access.
DevAccess.IDS = { 3288842358 } -- (Wilhem: Laveine972)

-- Is this user a developer? `creatorId` / `creatorIsUser`: game.CreatorId and whether
-- game.CreatorType is a user (a group-owned game only trusts IDS). `studioSolo`: the server
-- runs in Roblox Studio with this one player alone in it (Play / Play Here: the account that
-- edits the place, which only someone with edit access to the place can open). In a published
-- game it is always false; in a Studio test with several players (Team Test, Clients and
-- Servers) too: they never get it that way.
function DevAccess.isDev(userId, creatorId, creatorIsUser, studioSolo)
	if type(userId) ~= "number" or userId <= 0 then return false end
	if table.find(DevAccess.IDS, userId) then return true end
	if studioSolo == true then return true end
	return creatorIsUser == true and type(creatorId) == "number" and creatorId > 0 and userId == creatorId
end

-- TESTERS: Roblox UserIds (numbers) that get every fighter (Economy.makeTester; not the
-- developer access: the shop, styles and passes stay as for any player). Old profiles saved
-- before the fighters were sold are testers too, without being listed here.
DevAccess.TESTER_IDS = {}
function DevAccess.isTester(userId)
	return type(userId) == "number" and userId > 0 and table.find(DevAccess.TESTER_IDS, userId) ~= nil
end

-- Is the access on right now (a developer who did not switch it off)?
function DevAccess.active(isDev, profile)
	return isDev == true and not (type(profile) == "table" and profile.devOff == true)
end

return DevAccess
