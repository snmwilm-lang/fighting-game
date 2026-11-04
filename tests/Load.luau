-- Load test of the server's logic with thousands of players, offline (not Roblox: a Roblox
-- server holds a few hundred players at most, so 1000 to 10000 players are spread over many
-- servers; this measures what ONE server's code costs as the count grows, and the share of
-- a 60 Hz frame the fights take).
--   luau tests/Load.luau -a [players...]        (default: 1000 5000 10000)
local Config = require("../src/shared/CombatConfig")
local MoveData = require("../src/shared/MoveData")
local Sim = require("../src/shared/CombatSimulation")
local FighterAI = require("../src/shared/FighterAI")
local Lobby = require("../src/server/Lobby")
local Matchmaker = require("../src/server/Matchmaker")

local counts = {}
for _, a in { ... } do table.insert(counts, tonumber(a)) end
if #counts == 0 then counts = { 1000, 5000, 10000 } end

local seed = 12345
local function rand()
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end

local function ms(t) return string.format("%.2f ms", t * 1000) end

-- Hub and search: every simulated second players join, leave, challenge, queue; then the
-- server pairs the queues and builds every player's hub view (what flushHub sends).
local function hub(n)
	local lobby, mm = Lobby.new(), Matchmaker.new()
	local t0 = os.clock()
	for id = 1, n do Lobby.join(lobby, id, "P" .. id) end
	local joinTime = os.clock() - t0
	local worstPair, worstViews, pairs, sent, maxView = 0, 0, 0, 0, 0
	local nextId = n + 1
	local queued = {}
	for second = 1, 60 do
		-- 2 % of the players act: queue, challenge, leave and are replaced.
		for _ = 1, math.max(1, n // 50) do
			local id = 1 + math.floor(rand() * (nextId - 1))
			local r = rand()
			if lobby.players[id] then
				if r < 0.4 and not queued[id] then
					Matchmaker.enqueue(mm, id, if r < 0.2 then "RANKED" else "NORMAL", 600 + math.floor(rand() * 1400), second,
						1 + math.floor(rand() * 3))
					queued[id] = true
				elseif r < 0.7 then
					Lobby.challenge(lobby, id, 1 + math.floor(rand() * (nextId - 1)), second)
				elseif r < 0.85 then
					Lobby.leave(lobby, id)
					Matchmaker.leave(mm, id)
					queued[id] = nil
					Lobby.join(lobby, nextId, "P" .. nextId)
					nextId += 1
				end
			end
		end
		local t = os.clock()
		local found = Matchmaker.pair(mm, second)
		worstPair = math.max(worstPair, os.clock() - t)
		for _, p in found do queued[p.a], queued[p.b] = nil, nil end
		pairs += #found
		Lobby.expire(lobby, second)
		t = os.clock()
		local list = Lobby.status(lobby)
		local byId = Lobby.index(list)
		for _, id in lobby.order do
			local view = Lobby.view(list, id, nil, byId)
			sent += #view
			maxView = math.max(maxView, #view)
		end
		worstViews = math.max(worstViews, os.clock() - t)
	end
	return {
		join = joinTime, pair = worstPair, views = worstViews, pairs = pairs, perSecond = sent / 60, maxView = maxView,
		waiting = Matchmaker.waitingIn(mm, "RANKED") + Matchmaker.waitingIn(mm, "NORMAL"),
	}
end

-- The fights: the cost of one match tick (CPU against CPU, the heaviest: the AI thinks too).
local function fights()
	local worlds, brains = {}, {}
	for i = 1, 20 do
		local world = Sim.newWorld(Config, MoveData, false)
		Sim.setKits(world, MoveData.KitOrder[(i - 1) % #MoveData.KitOrder + 1], MoveData.KitOrder[(i * 7) % #MoveData.KitOrder + 1])
		worlds[i], brains[i] = world, { FighterAI.new(3, i), FighterAI.new(3, i + 100) }
	end
	local ticks = 600
	local t = os.clock()
	for _ = 1, ticks do
		for i, world in worlds do
			Sim.step(world, { brains[i][1]:think(world, 1), brains[i][2]:think(world, 2) })
		end
	end
	return (os.clock() - t) / (ticks * #worlds)
end

print("Charge du serveur (logique pure, hors Roblox)")
local perMatch = fights()
print(string.format("  un combat (2 CPU, IA comprise) : %s par tick ; à 60 Hz un serveur tient ~%d combats dans 50 %% d'une frame",
	ms(perMatch), math.floor(0.5 / 60 / perMatch)))
for _, n in counts do
	local r = hub(n)
	print(string.format("  %6d joueurs : arrivée %s · appariement (pire seconde) %s · vues du hub %s · %d paires en 60 s · %d en attente",
		n, ms(r.join), ms(r.pair), ms(r.views), r.pairs, r.waiting))
	print(string.format("                 hub : au plus %d noms par joueur, %.0f noms envoyés par seconde au total", r.maxView, r.perSecond))
	local matches = math.ceil(n / 2)
	print(string.format("                 %d combats en même temps : %s par tick pour la simulation (%d serveurs de 100 joueurs)", matches,
		ms(matches * perMatch), math.ceil(n / 100)))
end
