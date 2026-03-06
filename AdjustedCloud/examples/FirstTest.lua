-- Get AdjustedCloud and Players Service
local AdjustedCloud = require(game.ReplicatedStorage.AdjustedCloud)
local Players = game:GetService("Players")

-- Set DataStore name
local DATA_NAME = "PlayerData"

-- Default data template (if player has no data)
local Template = {
	Coins = 0,
	Level = 1
}

-- (Optional) change the key prefix – default is "plr_"
AdjustedCloud.SetKeyPrefix("plr_")

-- (Optional) enable saving all dirty data when the server shuts down
AdjustedCloud.EnableAutoShutdownSave(true)

-- Uncomment the line below to use a mock DataStore in Studio (safe for testing, no real data is saved)
-- AdjustedCloud.SetStudioMode(true)

-- When a player joins the game
Players.PlayerAdded:Connect(function(p)
	-- Load data (or create new data using the template)
	local data = AdjustedCloud.InitPlayer(p, DATA_NAME, Template)
	--                 1st arg: player, 2nd: DataStore name, 3rd: template

	-- Print current data
	print(p.Name .. " joined: Coins=" .. data.Coins .. ", Level=" .. data.Level)

	-- Example: give the player 50 extra coins
	AdjustedCloud.SetData(p, DATA_NAME, "Coins", data.Coins + 50)
	-- 1st arg: player, 2nd: DataStore name, 3rd: field name, 4th: new value

	-- Print updated value
	print(p.Name .. " now has: Coins=" .. data.Coins)
end)

-- When a player leaves
Players.PlayerRemoving:Connect(function(p)
	-- Save the player's data (force = true means save even if nothing changed)
	print("PlayerLeaving")
	local success, err = AdjustedCloud.SaveData(p, DATA_NAME, true)
	print(success, err)
	-- 1st arg: player, 2nd: DataStore name, 3rd: force save

	if success then
		print("Data for " .. p.Name .. " saved!")
	else
		warn("Data for " .. p.Name .. " NOT saved, error:", err)
	end

end)
