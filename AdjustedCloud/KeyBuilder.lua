local KeyBuilder = {}

local playerPrefix = "plr_"
local globalPrefix = "global_"

function KeyBuilder.setPlayerPrefix(prefix)
	playerPrefix = prefix or "plr_"
end

function KeyBuilder.getPlayerPrefix()
	return playerPrefix
end

function KeyBuilder.getPlayerKey(userId)
	return playerPrefix .. tostring(userId)
end

function KeyBuilder.getGlobalKey(globalKey)
	return globalPrefix .. globalKey
end

return KeyBuilder