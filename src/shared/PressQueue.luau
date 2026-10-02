--[[
	Attack presses in the order they were made, from the client to the simulation. Pure (no
	Roblox API, no require).

	The client sends every attack press of a packet as an ordered list ("light", "heavy",
	"special", "ultimate", "fatal"); the server appends it to the slot's queue and hands the
	simulation ONE press per tick. Two presses between two ticks used to merge into one
	(booleans), and a heavy then a light came out light first (fixed button order): count
	and order are now kept.
]]
local PressQueue = {}

PressQueue.BUTTONS = table.freeze({ light = true, heavy = true, special = true, ultimate = true, fatal = true })
PressQueue.MAX_PACKET = 8 -- presses accepted in one packet
PressQueue.CAPACITY = 6 -- presses waiting on the server (the oldest goes on overflow)

function PressQueue.new()
	return { items = {} }
end

-- A packet's list: an array of at most MAX_PACKET known button names, nothing else.
function PressQueue.valid(list)
	if type(list) ~= "table" then return false end
	local count = 0
	for key, value in list do
		count += 1
		if type(key) ~= "number" or key ~= math.floor(key) or key < 1 then return false end
		if type(value) ~= "string" or not PressQueue.BUTTONS[value] then return false end
	end
	return count == #list and count <= PressQueue.MAX_PACKET
end

function PressQueue.push(queue, list)
	for _, button in list do
		if #queue.items >= PressQueue.CAPACITY then table.remove(queue.items, 1) end
		table.insert(queue.items, button)
	end
end

-- Sets the next press (if any) on the simulation input of this tick.
function PressQueue.pop(queue, input)
	local button = table.remove(queue.items, 1)
	if button then input[button] = true end
	return button
end

function PressQueue.clear(queue)
	table.clear(queue.items)
end

return PressQueue
