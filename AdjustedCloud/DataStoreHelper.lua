local DataStoreHelper = {}
local ErrorHandler = require(script.Parent.ErrorHandler)

local DEFAULT_RETRIES = 3
local DEFAULT_DELAY = 1

local config = {
	retryCount = DEFAULT_RETRIES,
	retryDelay = DEFAULT_DELAY,
}

function DataStoreHelper.setConfig(newConfig)
	config.retryCount = newConfig.retryCount or config.retryCount
	config.retryDelay = newConfig.retryDelay or config.retryDelay
end

local function withRetries(func, ...)
	local lastError
	for attempt = 1, config.retryCount do
		local success, result = pcall(func, ...)
		if success then
			return true, result
		else
			lastError = result
			ErrorHandler.warn("DataStore attempt", attempt, "failed:", result)
			if attempt < config.retryCount then
				task.wait(config.retryDelay * (attempt - 1))
			end
		end
	end
	return false, lastError
end

function DataStoreHelper.getAsync(store, key)
	return withRetries(function()
		return store:GetAsync(key)
	end)
end

function DataStoreHelper.setAsync(store, key, value)
	return withRetries(function()
		return store:SetAsync(key, value)
	end)
end

function DataStoreHelper.updateAsync(store, key, transformer)
	return withRetries(function()
		return store:UpdateAsync(key, transformer)
	end)
end

return DataStoreHelper