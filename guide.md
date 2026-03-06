# Guide: How to use AdjustedCloud?

### For beginners, this framework (or wrapper) for DataStore may seem complicated, but in reality, everything is simple.

---

## What is AdjustedCloud?

AdjustedCloud is a tool that helps you save and load player data (and server‑wide data) in your Roblox game. It acts like a smart memory box:
- It keeps a copy of the data **in memory (cache)** so you can read it instantly.
- It remembers which values have changed (**dirty flags**) so you can save only what is necessary.
- It gives you **full control** – no hidden auto‑saves, no magic.

---

## Quick Start Example:
``` lua
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

    -- Print updated value (note: `data` still holds the old value, but the cache is updated)
    print(p.Name .. " now has: Coins=" .. data.Coins + 50)
end)

-- When a player leaves
Players.PlayerRemoving:Connect(function(p)
    -- Save the player's data (force = true means save even if nothing changed)
    local success, err = AdjustedCloud.SaveData(p, DATA_NAME, true)
    -- 1st arg: player, 2nd: DataStore name, 3rd: force save

    if success then
        print("Data for " .. p.Name .. " saved!")
    else
        warn("Data for " .. p.Name .. " NOT saved, error:", err)
    end
end)
```

---

## Detailed Explanation of Key Concepts

### 1. **DataStore name (`DATA_NAME`)**
   - Think of it as a folder in the cloud where your game’s data is stored. You can have different folders for different purposes (e.g., "PlayerData", "GameSettings").

### 2. **Template (default data)**
   - When a player joins for the first time, they have no saved data. The **template** provides the starting values. Any fields that are missing in the loaded data will be filled with the template values.

### 3. **Key prefix (`SetKeyPrefix`)**
   - Inside the DataStore, every player’s data is stored under a unique key. By default it is `"plr_"` followed by the player’s user ID (e.g., `plr_12345`). You can change the prefix to anything you like.

### 4. **Cache and dirty flags**
   - After `InitPlayer`, the data is kept in memory (**cache**). When you use `SetData`, the cache is updated immediately, and a **dirty flag** is set to remember that this data has changed.
   - Nothing is written to the actual DataStore until you call `SaveData`. This is why you **must** call `SaveData` when the player leaves, otherwise the changes are lost.

### 5. **Force save**
   - The third argument of `SaveData` (`force`) tells the framework: “Save this data even if it is not marked as dirty.” Using `true` guarantees that the data is written to the DataStore, which is safe to do on player exit.

### 6. **Error handling**
   - Always check the return values of `SaveData`. If it fails, the player might leave without saving – you could retry or log the error.

---

## Common Beginner Mistakes

| Mistake | Why it’s wrong | How to fix |
|--------|----------------|------------|
| Forgetting to call `SaveData` on player exit | Changes are lost forever. | Always add a `PlayerRemoving` handler with `SaveData(..., true)`. |
| Using `SetData` for currency in a multi‑server game | Two servers could overwrite each other, causing lost coins. | Use `UpdateField` for atomic updates (see advanced section). |
| Not using a template | New players start with an empty table – your code might crash because fields like `Coins` don’t exist. | Always provide a template with default values. |
| Calling `SaveData` too often | You may hit DataStore limits or slow down the game. | Save only when necessary (on exit, after important actions). You can also use `SaveAllDirty` periodically. |

---

## More Advanced Features (When You’re Ready)

### **SetBatch – update multiple fields at once**
```lua
AdjustedCloud.SetBatch(player, "PlayerData", {
    Coins = 200,
    Level = 5
})
```
This changes both fields and sets the dirty flag only once. It’s more efficient than two separate `SetData` calls.

### **UpdateField – atomic update (for money, scores, etc.)**
```lua
local ok, newCoins = AdjustedCloud.UpdateField(player, "PlayerData", "Coins", function(old)
    return (old or 0) + 50
end)
```
This uses Roblox’s `UpdateAsync` to ensure that even if two servers try to add coins at the same time, the final value is correct. **Always use this for anything that multiple servers might change concurrently.**

### **WatchField / WatchData – react to changes**
```lua
AdjustedCloud.WatchField(player, "PlayerData", "Coins", function(new, old)
    print("Coins changed from", old, "to", new)
end)
```
Now every time `Coins` is changed (by any method), your callback runs automatically. Great for updating UI.

### **Global data (server‑wide)**
```lua
local global = AdjustedCloud.InitGlobal("ServerStats", "GlobalData", {
    TotalPlayers = 0
})
AdjustedCloud.UpdateGlobal("ServerStats", "GlobalData", "TotalPlayers", function(old)
    return old + 1
end)
```
Use `InitGlobal`, `SetGlobal`, `UpdateGlobal` exactly like player methods, but without a player argument.

---

## Glossary

- **Cache** – a temporary copy of data kept in memory for fast access.
- **Dirty flag** – a marker that indicates the data has been changed and needs to be saved.
- **Template** – a table with default values used when a player has no saved data.
- **Force save** – saving even if the data is not dirty; useful when you want to be absolutely sure.
- **Atomic operation** – an update that is performed as a single, indivisible step, safe from conflicts.
- **Key prefix** – a string added to the beginning of every player’s storage key to avoid mixing with other data.

---

## Where to Go Next

- Read the full [API Reference](https://github.com/AdjustedTechnologies/AdjustedCloud/wiki) on GitHub.
- Look at the **examples** folder in the repository.
- Join the [Discord](https://discord.gg/...) to ask questions and share your projects.

---

Now you are ready to use AdjustedCloud like a pro!