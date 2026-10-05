--[[
	The CHAMPION OF THE WEEK on the existing ranking (pure Luau: no Roblox API, no require; the
	time, the history and the profile are passed in). The ranking itself is unchanged (the
	rating board, JeuxCombat_Classement_v1): when a new week starts (Monday 00:00 UTC), the
	first server to notice writes the player first on the board as the champion of the week
	that ended, in a shared history (one DataStore key, UpdateAsync with `record`: a week is
	written once, whatever the number of servers). The champion gets the title TITLE, once per
	week won, the next time their profile is loaded or at once if they are online. The title
	cannot be bought: only `grant` adds it.
	Tests: tests/Lobby.test.luau ("weekly champion").
]]
local Champions = {}

Champions.TITLE = "WEEKLY CHAMPION"
Champions.KEEP = 104 -- weeks kept in the history (two years)
local MONDAY = 4 * 86400 -- (1 January 1970 was a Thursday: the first Monday 00:00 UTC)
local WEEK = 7 * 86400

function Champions.week(time)
	return math.floor((time - MONDAY) / WEEK)
end

-- The history transform: the history with `week`'s champion added, or nil when that week is
-- already written (nothing to write) or there is no champion.
function Champions.record(history, week, champion)
	if type(champion) ~= "table" or type(champion.id) ~= "number" then return nil end
	local list = if type(history) == "table" then table.clone(history) else {}
	for _, e in list do
		if type(e) == "table" and e.week == week then return nil end
	end
	table.insert(list, { week = week, id = champion.id, name = tostring(champion.name or "?"), rating = tonumber(champion.rating) or 0 })
	table.sort(list, function(a, b) return a.week < b.week end)
	while #list > Champions.KEEP do table.remove(list, 1) end
	return list
end

-- Gives the title to `userId`'s profile for every week of the history they won and that it
-- did not get yet. Returns the number of weeks newly given.
function Champions.grant(profile, userId, history)
	if type(profile) ~= "table" or type(history) ~= "table" then return 0 end
	if type(profile.championWeeks) ~= "table" then profile.championWeeks = {} end
	if type(profile.titles) ~= "table" then profile.titles = {} end
	local given = 0
	for _, e in history do
		if type(e) == "table" and e.id == userId and not profile.championWeeks[tostring(e.week)] then
			profile.championWeeks[tostring(e.week)] = true
			given += 1
		end
	end
	if given > 0 and not table.find(profile.titles, Champions.TITLE) then
		table.insert(profile.titles, Champions.TITLE)
	end
	return given
end

-- May this profile show `title`? Only one it has (a challenge title, the champion's...), or none.
function Champions.canShow(profile, title)
	if title == "" then return true end
	return type(profile) == "table" and type(profile.titles) == "table" and table.find(profile.titles, title) ~= nil
end

return Champions
