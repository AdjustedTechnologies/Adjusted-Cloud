local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")

local StudioMode = {}

local isStudio = RunService:IsStudio()
local useRealDataStore = not isStudio

local mockStorage = {}

local function getMockDataStore(dataName)
	if not mockStorage[dataName] then
		mockStorage[dataName] = {}
	end
	local store = mockStorage[dataName]
	return {
		GetAsync = function(_, key)
			return store[key]
		end,
		SetAsync = function(_, key, value)
			store[key] = value
			print("[StudioMode] Mock Set:", key, value)
		end,
		UpdateAsync = function(_, key, transformer)
			local old = store[key]
			local new = transformer(old)
			store[key] = new
			return new
		end,
		RemoveAsync = function(_, key)
			store[key] = nil
		end,
	}
end

-- Public

function StudioMode.SetStudioMode(enabled)
	useRealDataStore = not enabled
	isStudio = enabled
end

function StudioMode.IsStudioMode()
	return isStudio
end

function StudioMode.GetDataStore(dataName)
	if useRealDataStore then
		return DataStoreService:GetDataStore(dataName)
	else
		return getMockDataStore(dataName)
	end
end

function StudioMode.ResetMock()
	mockStorage = {}
end

return StudioMode
