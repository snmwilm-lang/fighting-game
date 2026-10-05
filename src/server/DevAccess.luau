--[[
	The developer access (pure Luau: no Roblox API, no require; the ids are passed in). Lives
	on the server only (ServerScriptService: never sent to a client), and only the server asks
	it.

	Who: the Roblox UserIds in IDS, and the owner of the game when it belongs to a user (the
	place's CreatorId, read by the server: in a game owned by Wilhem's account, Wilhem). Never
	"everyone in Studio": a Studio test player has a negative UserId (-1, -2...) and is refused;
	a Play Solo session in Studio is the real account, so only the developer gets it.

	What: every fighter in every mode and every style, without buying (Economy.canPlay,
	CharacterData.canWear get `dev`); nothing is written as bought in the profile, so switching
	it off (profile.devOff, from SETTINGS) gives the real experience of a new player.
	Tests: tests/Lobby.test.luau ("developer access").
]]
local DevAccess = {}

-- Wilhem's Roblox UserIds (numbers). Add an id here to give a second account the access.
DevAccess.IDS = {}

-- Is this user a developer? `creatorId` / `creatorIsUser`: game.CreatorId and whether
-- game.CreatorType is a user (a group-owned game only trusts IDS).
function DevAccess.isDev(userId, creatorId, creatorIsUser)
	if type(userId) ~= "number" or userId <= 0 then return false end
	if table.find(DevAccess.IDS, userId) then return true end
	return creatorIsUser == true and type(creatorId) == "number" and creatorId > 0 and userId == creatorId
end

-- Is the access on right now (a developer who did not switch it off)?
function DevAccess.active(isDev, profile)
	return isDev == true and not (type(profile) == "table" and profile.devOff == true)
end

return DevAccess
