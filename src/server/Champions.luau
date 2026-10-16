--[[
	TWO RANKINGS (Wilhem): ALL TIME (the rating, JeuxCombat_Classement_v1, never reset) and
	WEEKLY (the points of the week, a new ordered store each week: JeuxCombat_Semaine_<week>,
	so it starts again from zero every Monday 00:00 UTC). Weekly points come from the online
	matches the anti-farm counts: a win WEEK_POINTS.win, a draw .draw, a loss .loss (scaled by
	the anti-farm share). The champion of the week is the first of the WEEKLY ranking of the
	week that ended.

	The CHAMPION OF THE WEEK (pure Luau: no Roblox API, no require; the time, the history and the
	profile are passed in): when a new week starts, the first server to notice writes the player
	first on the WEEKLY ranking of the week that ended as its champion, in a shared history (one
	DataStore key, UpdateAsync with `record`: a week is written once, whatever the number of
	servers). The champion gets the title TITLE, once per week won, the next time their profile
	is loaded or at once if they are online. The title
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

Champions.WEEK_POINTS = { win = 3, draw = 1, loss = 0 }

-- Adds a match's weekly points (`result`: "win", "draw", "loss"; `share`: the anti-farm share
-- 0..1) to the profile, starting again from zero on a new week. Returns the points of the week.
function Champions.addPoints(profile, week, result, share)
	if profile.weekId ~= week then profile.weekId, profile.weekPoints = week, 0 end
	local gain = math.floor((Champions.WEEK_POINTS[result] or 0) * (share or 1) + 0.5)
	profile.weekPoints = (tonumber(profile.weekPoints) or 0) + gain
	return profile.weekPoints
end

-- The points of the week shown for a profile (0 when they are from an older week).
function Champions.pointsOf(profile, week)
	if type(profile) ~= "table" or profile.weekId ~= week then return 0 end
	return tonumber(profile.weekPoints) or 0
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
