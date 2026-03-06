-- AdjustedCloud, Created by AdjustedTechnologies on 7 March, 2026
-- Latest version you can find on github: https://github.com/AdjustedTechnologies/Adjusted-Cloud
-- This module is licensed under MIT, you can find the full license in the GitHub repository.
-- Global Data Store (W.I.P) does not yet have watchers.

-- Version 1.1 unstable

local AdjustedCloud = {}

local DataStore = require(script.DataStoreAccess).ReturnService()
local Players = game:GetService("Players")

-- Internal helper modules
local StudioMode = require(script.StudioMode)
local WatcherManager = require(script.WatcherManager)
local KeyBuilder = require(script.KeyBuilder)
local DataStoreHelper = require(script.DataStoreHelper)
local CacheManager = require(script.CacheManager)
local ErrorHandler = require(script.ErrorHandler)
local Utils = require(script.Utils)

-- Create cache managers for player and global data
local playerCache = {}
local playerDirty = {}
local PlayerManager = CacheManager.new(playerCache, playerDirty)

local globalCache = {}
local globalDirty = {}
local GlobalManager = CacheManager.new(globalCache, globalDirty)

local autoShutdownEnabled = false
local shutdownBound = false

				---- Public API ----

-- Set the environment mode (true = Studio, false = Production)
function AdjustedCloud.SetStudioMode(enabled)
	StudioMode.SetStudioMode(enabled)
	ErrorHandler.debug("Studio mode set to", enabled)
end

-- Changes the key prefix used for player data (default "plr_").
-- @param prefix string
function AdjustedCloud.SetKeyPrefix(prefix)
	KeyBuilder.setPlayerPrefix(prefix)
	ErrorHandler.debug("KeyPrefix set to", prefix)
end

-- Enables or disables automatic saving of all dirty data when the server shuts down.
-- In Studio mode, this has no effect (to avoid accidental saves).
-- @param enabled boolean
function AdjustedCloud.EnableAutoShutdownSave(enabled)
	if enabled == autoShutdownEnabled then return end
	autoShutdownEnabled = enabled

	if enabled and not shutdownBound and not StudioMode.IsStudioMode() then
		game:BindToClose(function()
			ErrorHandler.info("Server shutting down, saving all dirty data...")

			local globalSuccess, globalErrors = AdjustedCloud.SaveAllDirtyGlobal()
			if not globalSuccess then
				ErrorHandler.warn("Errors while saving global data on shutdown:", globalErrors)
			end
			
			local allSuccess = true
			local playerErrors = {}
			for _, player in ipairs(Players:GetPlayers()) do
				local success, err = AdjustedCloud.SaveAllDirty(player)
				if not success then
					allSuccess = false
					playerErrors[player.UserId] = err
				end
			end
			if not allSuccess then
				ErrorHandler.warn("Errors while saving player data on shutdown:", playerErrors)
			end

			ErrorHandler.info("Shutdown save completed.")
		end)
		shutdownBound = true
		ErrorHandler.debug("Auto-shutdown save enabled")
	elseif not enabled and shutdownBound then
		ErrorHandler.warn("Auto-shutdown save cannot be disabled after binding (restart required)")
	end
end

-- Initializes player data for the specified DataStore.
-- Loads from the store or creates an empty table.
-- @param player Player
-- @param dataName string
-- @param opt table? not used for now
-- @return table
function AdjustedCloud.InitPlayer(player, dataName, template, options)
	local playerKey = KeyBuilder.getPlayerKey(player.UserId)

	local cached = PlayerManager:get(playerKey, dataName)
	if cached then
		return cached
	end

	local store = DataStore:GetDataStore(dataName)
	local key = playerKey
	local success, loaded = DataStoreHelper.getAsync(store, key)

	if not success or not loaded then
		ErrorHandler.warn("Failed to load data for:", player.UserId, loaded)
		loaded = {}
	end

	if template and type(template) == "table" then
		local changed = false
		for key, defaultValue in pairs(template) do
			if loaded[key] == nil then
				loaded[key] = defaultValue
				changed = true
			end
		end
		if changed then
			PlayerManager:markDirty(playerKey, dataName)
		end
	end

	PlayerManager:set(playerKey, dataName, loaded)

	return loaded
end

-- Initializes global data for the specified globalKey and dataName.
-- Loads from the store or creates an empty table.
-- @param globalKey string
-- @param dataName string
-- @param template table
-- @param options table?
-- @return table 
function AdjustedCloud.InitGlobal(globalKey, dataName, template, options)
	local cached = GlobalManager:get(globalKey, dataName)
	if cached then
		return cached
	end

	local store = DataStore:GetDataStore(dataName)
	local key = KeyBuilder.getGlobalKey(globalKey)
	local success, loaded = DataStoreHelper.getAsync(store, key)

	if not success or not loaded then
		ErrorHandler.warn("Failed to load global data for", globalKey, loaded)
		loaded = {}
	end

	if template and type(template) == "table" then
		local changed = false
		for key, defaultValue in pairs(template) do
			if loaded[key] == nil then
				loaded[key] = defaultValue
				changed = true
			end
		end
		if changed then
			GlobalManager:markDirty(globalKey, dataName)
		end
	end

	GlobalManager:set(globalKey, dataName, loaded)
	return loaded
end

-- Returns the data table of the player for the specified DataStore.
-- If data is not initialized, returns an empty table (better to call InitPlayer first).
-- @param player Player
-- @param dataName string
-- @return table
function AdjustedCloud.GetData(player, dataName)
	local playerKey = KeyBuilder.getPlayerKey(player.UserId)
	local data = PlayerManager:get(playerKey, dataName)
	return data or {}
end

-- Returns the data table for the specified global dataset.
-- If data is not initialized, returns an empty table (better to call InitGlobal first).
-- @param globalKey string
-- @param dataName string
-- @return table
function AdjustedCloud.GetGlobal(globalKey, dataName)
	local data = GlobalManager:get(globalKey, dataName)
	return data or {}
end

-- Sets a field in the player's data for the specified DataStore.
-- Automatically marks the data as dirty if the value changes.
-- @param player Player
-- @param dataName string
-- @param key string
-- @param value any
function AdjustedCloud.SetData(player, dataName, key, value)
	local playerKey = KeyBuilder.getPlayerKey(player.UserId)
	local data = PlayerManager:get(playerKey, dataName)
	local oldValue = data[key]
	local changed = PlayerManager:updateField(playerKey, dataName, key, value)
	if changed then
		WatcherManager.notifyField(playerKey, dataName, key, value, oldValue)
	end
end

-- Sets a field in the global data for the specified dataset.
-- Automatically marks the data as dirty if the value changes.
-- @param globalKey string
-- @param dataName string
-- @param key string
-- @param value any
function AdjustedCloud.SetGlobal(globalKey, dataName, key, value)
	GlobalManager:updateField(globalKey, dataName, key, value)
end

-- ⚠ Deprecated. Use SetBatch instead.
function AdjustedCloud.MergeData(p, data, changes, forced)
	AdjustedCloud.SetBatch(p, data, changes, forced)
end

-- Set multiple fields into the player's data.
-- Only marks dirty if any field actually changed.
-- @param player Player
-- @param dataName string
-- @param updates table: { [key] = value, ... }
-- @param force boolean?   If true, forces dirty even if values are the same.
-- @return boolean changed  True if at least one field was updated.
function AdjustedCloud.SetBatch(player, dataName, updates, force)
	local playerKey = KeyBuilder.getPlayerKey(player.UserId)

	if not PlayerManager:get(playerKey, dataName) then
		PlayerManager:set(playerKey, dataName, {})
	end

	local data = PlayerManager:get(playerKey, dataName)
	local oldValues = {}
	for key, _ in pairs(updates) do
		oldValues[key] = data[key]
	end

	local changed = PlayerManager:merge(playerKey, dataName, updates, force)

	if changed then
		for key, _ in pairs(updates) do
			local oldValue = oldValues[key]
			local newValue = data[key]
			if force or oldValue ~= newValue then
				WatcherManager.notifyField(playerKey, dataName, key, newValue, oldValue)
			end
		end
	end
	return changed
end

-- ⚠ Deprecated. Use SetBatchGlobal instead.
function AdjustedCloud.MergeGlobal(gkey, data, changes, forced)
	AdjustedCloud.SetBatchGlobal(gkey, data, changes, forced)
end

-- Set multiple fields into the global data.
-- Only marks dirty if any field actually changed.
-- @param globalKey string
-- @param dataName string
-- @param updates table: { [key] = value, ... }
-- @param force boolean? If true, forces dirty even if values are the same.
-- @return boolean changed True if at least one field was updated.
function AdjustedCloud.SetBatchGlobal(globalKey, dataName, updates, force)
	return GlobalManager:merge(globalKey, dataName, updates, force)
end

-- Atomically updates a field using DataStore's UpdateAsync.
-- The updater function receives the old value and returns the new value.
-- The cache is updated with the full table returned by UpdateAsync.
-- @param player Player
-- @param dataName string
-- @param key string
-- @param updater function(oldValue: any) -> newValue: any
-- @return boolean success, any newValueOrError
function AdjustedCloud.UpdateField(player, dataName, key, updater)
	local userId = player.UserId
	local playerKey = KeyBuilder.getPlayerKey(userId)
	local store = DataStore:GetDataStore(dataName)
	local storeKey = playerKey

	local currentData = PlayerManager:get(playerKey, dataName) or {}
	local oldValue = currentData[key]

	local success, result = DataStoreHelper.updateAsync(store, storeKey, function(oldData)
		oldData = oldData or {}
		local oldVal = oldData[key]
		local newVal = updater(oldVal)
		oldData[key] = newVal
		return oldData
	end)

	if not success then
		return false, "UpdateAsync failed: " .. tostring(result)
	end

	PlayerManager:set(playerKey, dataName, result)
	PlayerManager:markDirty(playerKey, dataName)

	local newValue = result[key]
	if oldValue ~= newValue then
		WatcherManager.notifyField(playerKey, dataName, key, newValue, oldValue)
	end

	return true, newValue
end

-- Atomically updates a multiple fields using DataStore's UpdateAsync.
-- After a successful update, the cache is synchronized and the data is marked as dirty.
-- @param player Player
-- @param dataName string
-- @param updates table: { [key] = newValue, ... }
-- @return boolean success, table? newData (or error)
function AdjustedCloud.UpdateData(player, dataName, updates)
	local userId = player.UserId
	local playerKey = KeyBuilder.getPlayerKey(userId)
	local store = DataStore:GetDataStore(dataName)
	local storeKey = playerKey

	local currentData = PlayerManager:get(playerKey, dataName) or {}
	local oldValues = {}
	for key, _ in pairs(updates) do
		oldValues[key] = currentData[key]
	end

	local success, result = DataStoreHelper.updateAsync(store, storeKey, function(oldData)
		oldData = oldData or {}
		for key, newValue in pairs(updates) do
			if newValue == nil then
				oldData[key] = nil
			else
				oldData[key] = newValue
			end
		end
		return oldData
	end)

	if not success then
		return false, "UpdateAsync failed: " .. tostring(result)
	end

	PlayerManager:set(playerKey, dataName, result)
	PlayerManager:markDirty(playerKey, dataName)

	for key, newValue in pairs(updates) do
		local oldValue = oldValues[key]
		local actualNew = result[key]
		if oldValue ~= actualNew then
			WatcherManager.notifyField(playerKey, dataName, key, actualNew, oldValue)
		end
	end

	return true, result
end

-- Atomically updates a global field using DataStore's UpdateAsync.
-- The updater function receives the old value and returns the new value.
-- The cache is updated with the full table returned by UpdateAsync.
-- @param globalKey string
-- @param dataName string
-- @param key string
-- @param updater function(oldValue: any) -> newValue: any
-- @return boolean success, any newValueOrError
function AdjustedCloud.UpdateGlobal(globalKey, dataName, key, updater)
	local store = DataStore:GetDataStore(dataName)
	local storeKey = KeyBuilder.getGlobalKey(globalKey)

	local success, result = DataStoreHelper.updateAsync(store, storeKey, function(oldData)
		oldData = oldData or {}
		local oldValue = oldData[key]
		local newValue = updater(oldValue)
		oldData[key] = newValue
		return oldData
	end)

	if not success then
		return false, "UpdateAsync failed: " .. tostring(result)
	end

	GlobalManager:set(globalKey, dataName, result)
	GlobalManager:markDirty(globalKey, dataName)
	return true, result[key]
end

-- Atomically updates a multiple fields using Global DataStore's UpdateAsync.
-- After a successful update, the cache is synchronized and the data is marked as dirty.
-- @param globalKey string
-- @param dataName string
-- @param updates table: { [key] = newValue, ... }
-- @return boolean success, table? newData (or error)
function AdjustedCloud.UpdateGlobalData(globalKey, dataName, updates)
	local store = DataStore:GetDataStore(dataName)
	local storeKey = KeyBuilder.getGlobalKey(globalKey)

	local currentData = GlobalManager:get(globalKey, dataName) or {}
	local oldValues = {}
	for key, _ in pairs(updates) do
		oldValues[key] = currentData[key]
	end

	local success, result = DataStoreHelper.updateAsync(store, storeKey, function(oldData)
		oldData = oldData or {}
		for key, newValue in pairs(updates) do
			if newValue == nil then
				oldData[key] = nil
			else
				oldData[key] = newValue
			end
		end
		return oldData
	end)

	if not success then
		return false, "UpdateAsync failed: " .. tostring(result)
	end

	GlobalManager:set(globalKey, dataName, result)
	GlobalManager:markDirty(globalKey, dataName)

	for key, newValue in pairs(updates) do
		local oldValue = oldValues[key]
		local actualNew = result[key]
		if oldValue ~= actualNew then
			-- pass
		end
	end

	return true, result
end

-- Saves player data for the specified DataStore.
-- If data is dirty, it will be saved; otherwise nothing happens (unless forced).
-- @param player Player
-- @param dataName string
-- @param force boolean?   If true, saves even if not dirty.
-- @return boolean success, string? error
function AdjustedCloud.SaveData(player, dataName, force)
	local playerKey = KeyBuilder.getPlayerKey(player.UserId)
	local data = PlayerManager:get(playerKey, dataName)
	if not data then
		return false, "No data to save"
	end

	if not force and not PlayerManager:isDirty(playerKey, dataName) then
		return true
	end

	local store = DataStore:GetDataStore(dataName)
	local storeKey = playerKey
	local success, err = DataStoreHelper.setAsync(store, storeKey, data)
	if success then
		PlayerManager:cleanDirty(playerKey, dataName)
		ErrorHandler.debug("Saved player data:", player.UserId, dataName)
		return true
	else
		ErrorHandler.warn("Failed to save player data:", player.UserId, dataName, err)
		return false, err
	end
end

-- Saves global data for the specified dataset.
-- If data is dirty, it will be saved; otherwise nothing happens (unless forced).
-- @param globalKey string
-- @param dataName string
-- @param force boolean? If true, saves even if not dirty.
-- @return boolean success, string? error
function AdjustedCloud.SaveGlobal(globalKey, dataName, force)
	local data = GlobalManager:get(globalKey, dataName)
	if not data then
		return false, "No global data to save"
	end

	if not force and not GlobalManager:isDirty(globalKey, dataName) then
		return true
	end

	local store = DataStore:GetDataStore(dataName)
	local storeKey = KeyBuilder.getGlobalKey(globalKey)
	local success, err = DataStoreHelper.setAsync(store, storeKey, data)
	if success then
		GlobalManager:cleanDirty(globalKey, dataName)
		ErrorHandler.debug("Saved global data:", globalKey, dataName)
		return true
	else
		ErrorHandler.warn("Failed to save global data:", globalKey, dataName, err)
		return false, err
	end
end

-- Subscribes to changes of a specific field in the player's data.
-- @param player Player
-- @param dataName string
-- @param key string
-- @param callback function(newValue: any, oldValue: any)
-- @return function()
function AdjustedCloud.WatchField(player, dataName, key, callback)
	local playerKey = KeyBuilder.getPlayerKey(player.UserId)
	return WatcherManager.subscribe(playerKey, dataName, key, callback)
end

-- Subscribes to any changes in the player's data for the specified dataName.
-- @param player Player
-- @param dataName string
-- @param callback function(changes: { [string]: any })
-- @return function()
function AdjustedCloud.WatchData(player, dataName, callback)
	local playerKey = KeyBuilder.getPlayerKey(player.UserId)
	return WatcherManager.subscribe(playerKey, dataName, nil, callback)  -- nil = __ALL__
end

-- Saves all dirty data for a specific player (all dataNames).
-- @param player Player
-- @return boolean success (overall), table errors (optional)
function AdjustedCloud.SaveAllDirty(player)
	local playerKey = KeyBuilder.getPlayerKey(player.UserId)
	local dirtyData = PlayerManager:getDirtyEntries(playerKey)
	if not dirtyData then
		return true
	end

	local allSuccess = true
	local errors = {}
	for dataName, _ in pairs(dirtyData) do
		local success, err = AdjustedCloud.SaveData(player, dataName, true)
		if not success then
			allSuccess = false
			errors[dataName] = err
		end
	end
	return allSuccess, errors
end

-- Saves all dirty global data (all keys and dataNames).
-- @return boolean success (overall), table errors (optional)
function AdjustedCloud.SaveAllDirtyGlobal()
	local allSuccess = true
	local errors = {}
	local allDirty = GlobalManager:getAllDirty()
	for globalKey, dataNames in pairs(allDirty) do
		for dataName, _ in pairs(dataNames) do
			local success, err = AdjustedCloud.SaveGlobal(globalKey, dataName, true)
			if not success then
				allSuccess = false
				if not errors[globalKey] then errors[globalKey] = {} end
				errors[globalKey][dataName] = err
			end
		end
	end
	return allSuccess, errors
end

-- Removes a specific field from player data.
-- @param player Player
-- @param dataName string
-- @param key string
-- @return boolean
function AdjustedCloud.RemoveField(player, dataName, key)
	local playerKey = KeyBuilder.getPlayerKey(player)
	if not playerCache[playerKey] or not playerCache[playerKey][dataName] then
		return false
	end
	local data = playerCache[playerKey][dataName]
	if data[key] ~= nil then
		data[key] = nil
		PlayerManager:markDirty(playerKey, dataName)
		return true
	end
	return false
end

-- Removes all data for a player.
-- @param player Player
-- @param dataName string
-- @param permanent boolean - If true, removes data from DataStore permanently.
function AdjustedCloud.RemoveData(player, dataName, permanent)
	local playerKey = KeyBuilder.getPlayerKey(player)
	if not playerCache[playerKey] then return false end

	if permanent then
		local store = DataStore:GetDataStore(dataName)
		local key = playerKey
		local success = pcall(function()
			store:RemoveAsync(key)
		end)
		if success then
			playerCache[playerKey][dataName] = nil
			PlayerManager:cleanDirty(playerKey, dataName)
			return true
		else
			return false
		end
	else
		playerCache[playerKey][dataName] = {}
		PlayerManager:markDirty(playerKey, dataName)
		return true
	end
end

-- Clear all cache for a player.
-- @param player Player
-- @param dataName string?
function AdjustedCloud.ClearCache(player, dataName)
	local playerKey = KeyBuilder.getPlayerKey(player)
	if dataName then
		if playerCache[playerKey] then
			playerCache[playerKey][dataName] = nil
		end
	else
		playerCache[playerKey] = nil
		playerDirty[playerKey] = nil
	end
end

-- Purges all player data from cache and optionally from DataStore.
-- WARNING: This is a destructive operation. Use with extreme caution.
-- @param permanent boolean?  If true, also removes data from DataStore (sets empty tables).
-- @return boolean success, table? errors
function AdjustedCloud.PurgeAll(permanent)
	ErrorHandler.warn("PurgeAll called! This will erase ALL player data. permanent=", tostring(permanent))
	local allSuccess = true
	local errors = {}

	if permanent then
		for playerKey, dataMap in pairs(playerCache) do
			local userId = playerKey:match(KeyBuilder.getPlayerPrefix() .. "(.*)")
			if userId then
				for dataName, _ in pairs(dataMap) do
					local store = DataStore:GetDataStore(dataName)
					local key = KeyBuilder.getPlayerKey(userId)
					local success, err = DataStoreHelper.setAsync(store, key, {})
					if not success then
						allSuccess = false
						if not errors[playerKey] then errors[playerKey] = {} end
						errors[playerKey][dataName] = err
					end
				end
			end
		end
	end

	PlayerManager:reset()
	ErrorHandler.info("Player cache cleared by PurgeAll")

	return allSuccess, errors
end

-- Returns whether the player's data for a specific dataName is dirty.
-- @param player Player
-- @param dataName string
-- @return boolean
function AdjustedCloud.IsDirty(player, dataName)
	local playerKey = KeyBuilder.getPlayerKey(player.UserId)
	return PlayerManager:isDirty(playerKey, dataName)
end

-- Returns whether the global data for a specific key/dataName is dirty.
-- @param globalKey string
-- @param dataName string
-- @return boolean
function AdjustedCloud.IsGlobalDirty(globalKey, dataName)
	return GlobalManager:isDirty(globalKey, dataName)
end

-- Discards the dirty flag for player data without saving.
-- @param player Player
-- @param dataName string
function AdjustedCloud.DiscardDirty(player, dataName)
	local playerKey = KeyBuilder.getPlayerKey(player.UserId)
	PlayerManager:cleanDirty(playerKey, dataName)
end

-- Discards the dirty flag for global data without saving.
-- @param globalKey string
-- @param dataName string
function AdjustedCloud.DiscardGlobalDirty(globalKey, dataName)
	GlobalManager:cleanDirty(globalKey, dataName)
end

-- Returns the entire cache for a player (all dataNames).
-- @param player Player
-- @return table?
function AdjustedCloud.GetCache(player)
	if not player then
		ErrorHandler.error("Expected a player, got nil")
	end
	local playerKey = KeyBuilder.getPlayerKey(player.UserId)
	return PlayerManager:getCache(playerKey)
end

-- Returns the entire global cache (all keys).
-- @return table
function AdjustedCloud.GetGlobalCache()
	return globalCache
end

-- Returns the global dirty map.
-- @return table
function AdjustedCloud.GetGlobalDirtyMap()
	return globalDirty
end

-- ================= TESTING UTILITIES =================
-- These functions are intended for development and testing only.
-- They provide debug output and direct access to internal state.
-- Do not rely on them in production code.
AdjustedCloud.testing = {
	-- Print a debug message (for internal use)
	_Debug = ErrorHandler.debug,

	-- Reset all player caches and dirty flags.
	_Reset = function()
		PlayerManager:reset()
		ErrorHandler.debug("Player cache reset")
	end,

	-- Reset all global caches and dirty flags.
	_ResetGlobals = function()
		GlobalManager:reset()
		ErrorHandler.debug("Global cache reset")
	end,

	-- Return a shallow copy of the player cache (for inspection).
	_GetCache = function() return Utils.shallowCopy(playerCache) end,

	-- Return a shallow copy of the global cache.
	_GetGlobalCache = function() return Utils.shallowCopy(globalCache) end,

	-- Return a shallow copy of the player dirty map.
	_GetDirty = function() return Utils.shallowCopy(playerDirty) end,

	-- Return a shallow copy of the global dirty map.
	_GetGlobalDirty = function() return Utils.shallowCopy(globalDirty) end,

	-- Inspect the cache for a specific player.
	_InspectPlayerCache = function(player)
		local playerKey = KeyBuilder.getPlayerKey(player.UserId)
		return playerCache[playerKey]
	end,

	-- Inspect the global cache for a specific key.
	_InspectGlobalCache = function(globalKey)
		return globalCache[globalKey]
	end,

	-- Inspect the dirty flags for a specific player.
	_InspectPlayerDirty = function(player)
		local playerKey = KeyBuilder.getPlayerKey(player.UserId)
		return playerDirty[playerKey]
	end,
	
	-- Reset mock storage (useful for tests)
	ResetMock = function()
		StudioMode.ResetMock()
		ErrorHandler.debug("Mock DataStore reset")
	end,
}

return AdjustedCloud
