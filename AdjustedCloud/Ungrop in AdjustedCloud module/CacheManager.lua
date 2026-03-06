local CacheManager = {}
local ErrorHandler = require(script.Parent.ErrorHandler)
local Utils = require(script.Parent.Utils)

function CacheManager.new(cacheTable, dirtyTable)
	local self = setmetatable({}, {__index = CacheManager})
	self.cache = cacheTable or {}
	self.dirty = dirtyTable or {}
	return self
end

function CacheManager:get(mainKey, dataName)
	local entry = self.cache[mainKey]
	if entry and entry[dataName] then
		return entry[dataName]
	end
	return nil
end

function CacheManager:set(mainKey, dataName, dataTable)
	if not self.cache[mainKey] then
		self.cache[mainKey] = {}
	end
	self.cache[mainKey][dataName] = dataTable
end

function CacheManager:updateField(mainKey, dataName, key, value)
	if not self.cache[mainKey] then
		self.cache[mainKey] = {}
	end
	if not self.cache[mainKey][dataName] then
		self.cache[mainKey][dataName] = {}
	end
	local data = self.cache[mainKey][dataName]
	if data[key] ~= value then
		data[key] = value
		self:markDirty(mainKey, dataName)
		return true
	end
	return false
end

function CacheManager:merge(mainKey, dataName, updates, force)
	if not self.cache[mainKey] then
		self.cache[mainKey] = {}
	end
	if not self.cache[mainKey][dataName] then
		self.cache[mainKey][dataName] = {}
	end
	local data = self.cache[mainKey][dataName]
	local anyChanged = false
	for key, value in pairs(updates) do
		if force or data[key] ~= value then
			data[key] = value
			anyChanged = true
		end
	end
	if anyChanged then
		self:markDirty(mainKey, dataName)
	end
	return anyChanged
end

function CacheManager:markDirty(mainKey, dataName)
	if not self.dirty[mainKey] then
		self.dirty[mainKey] = {}
	end
	self.dirty[mainKey][dataName] = true
end

function CacheManager:cleanDirty(mainKey, dataName)
	if self.dirty[mainKey] then
		self.dirty[mainKey][dataName] = nil
		if Utils.isEmpty(self.dirty[mainKey]) then
			self.dirty[mainKey] = nil
		end
	end
end

function CacheManager:isDirty(mainKey, dataName)
	return self.dirty[mainKey] and self.dirty[mainKey][dataName] or false
end

function CacheManager:getDirtyEntries(mainKey)
	return self.dirty[mainKey]
end

function CacheManager:getAllDirty()
	return self.dirty
end

function CacheManager:getCache(mainKey)
	return self.cache[mainKey]
end

function CacheManager:reset()
	self.cache = {}
	self.dirty = {}
end

return CacheManager
