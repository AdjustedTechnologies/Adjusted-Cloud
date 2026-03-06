local WatcherManager = {}

local listeners = {}

function WatcherManager.subscribe(playerKey, dataName, key, callback)
	if not listeners[playerKey] then
		listeners[playerKey] = {}
	end
	if not listeners[playerKey][dataName] then
		listeners[playerKey][dataName] = {}
	end
	local target = key or "__ALL__"
	if not listeners[playerKey][dataName][target] then
		listeners[playerKey][dataName][target] = {}
	end
	table.insert(listeners[playerKey][dataName][target], callback)

	return function()
		WatcherManager.unsubscribe(playerKey, dataName, key, callback)
	end
end

function WatcherManager.unsubscribe(playerKey, dataName, key, callback)
	local target = key or "__ALL__"
	if listeners[playerKey] and listeners[playerKey][dataName] and listeners[playerKey][dataName][target] then
		local list = listeners[playerKey][dataName][target]
		for i, cb in ipairs(list) do
			if cb == callback then
				table.remove(list, i)
				break
			end
		end
		
		if #list == 0 then
			listeners[playerKey][dataName][target] = nil
		end
	end
end

function WatcherManager.notifyField(playerKey, dataName, key, newValue, oldValue)
	if not listeners[playerKey] then return end
	local dataListeners = listeners[playerKey][dataName]
	if not dataListeners then return end

	if dataListeners[key] then
		for _, cb in ipairs(dataListeners[key]) do
			task.spawn(cb, newValue, oldValue)
		end
	end

	if dataListeners.__ALL__ then
		local changes = { [key] = newValue }
		for _, cb in ipairs(dataListeners.__ALL__) do
			task.spawn(cb, changes)
		end
	end
end

function WatcherManager.notifyBatch(playerKey, dataName, changes)
	if not listeners[playerKey] then return end
	local dataListeners = listeners[playerKey][dataName]
	if not dataListeners then return end

	for key, newValue in pairs(changes) do
		if dataListeners[key] then
			local oldValue = nil
			for _, cb in ipairs(dataListeners[key]) do
				task.spawn(cb, newValue, oldValue)
			end
		end
	end

	if dataListeners.__ALL__ then
		for _, cb in ipairs(dataListeners.__ALL__) do
			task.spawn(cb, changes)
		end
	end
end

function WatcherManager.clearPlayer(playerKey)
	listeners[playerKey] = nil
end

return WatcherManager
