# AdjustedCloud

**Professional data management framework for Roblox.**  
No magic auto-save. Just caching, dirty flags, atomic operations, and full control.

[![Roblox](https://img.shields.io/badge/Roblox-Studio-blue)](https://www.roblox.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub Stars](https://img.shields.io/github/stars/AdjustedTechnologies/Adjusted-Cloud?style=social)](https://github.com/AdjustedTechnologies/Adjusted-Cloud)

---

## 📖 Table of Contents

- [Philosophy](#philosophy)
- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [API Reference](#api-reference)
  - [Player Methods](#player-specific-methods)
  - [Global Data Methods](#global-data-methods)
  - [Environment & Utilities](#environment--utilities)
- [Advanced Examples](#advanced-examples)
- [Testing](#testing)
- [Contributing](#contributing)
- [License](#license)

---

## Philosophy

AdjustedCloud is built for developers who **want to understand and control every aspect** of their game's data.  
Unlike other frameworks that hide complexity behind auto‑save and profiles, AdjustedCloud gives you:

- A **transparent in‑memory cache** – you always know what data is where.
- **Dirty flags** – track exactly what has changed and needs saving.
- **Atomic updates** – safe concurrent access without data loss.
- **Full responsibility** – you decide when and how data is saved.

> You are in charge. The framework only provides the tools.

---

## Features

- **Player & Global data** – separate caches and dirty flags for both.
- **Atomic operations** – `UpdateField` / `UpdateGlobal` using `UpdateAsync`.
- **Batch updates** – `SetBatch` / `SetBatchGlobal` updates multiple fields, marks dirty only on change.
- **Dirty flag management** – check, discard, save selectively.
- **Configurable key prefix** – default `"plr_"`, change it to anything.
- **Retry logic** – automatic retries with exponential backoff for DataStore operations.
- **Studio mode** – use a mock DataStore in Studio (no risk to real data).
- **Auto‑shutdown save** – optionally save all dirty data when the server closes.
- **Data deletion** – remove fields or entire datasets (soft or hard).
- **Cache inspection & reset** – powerful testing utilities included.
- **Modular architecture** – easy to extend and maintain.

---

## Installation

1. Copy the `AdjustedCloud` folder into `ReplicatedStorage`.
2. Enable API services:  
   `File → Experience Settings → Security → Enable Studio Access to API Services`.
3. (Optional) Configure your own `DataStoreAccess` module if needed.

---

## Quick Start

```lua
local AdjustedCloud = require(game.ReplicatedStorage.AdjustedCloud)
local Players = game:GetService("Players")

-- (Optional) Force production mode – use real DataStore even in Studio
AdjustedCloud.SetStudioMode(false)

Players.PlayerAdded:Connect(function(player)
    local data = AdjustedCloud.InitPlayer(player, "PlayerData", { Coins = 0, Level = 1 })
    print(player.Name, "has", data.Coins, "coins and level", data.Level)
end)

Players.PlayerRemoving:Connect(function(player)
    local success, err = AdjustedCloud.SaveData(player, "PlayerData", true)
    if success then
        print("Data saved for", player.Name)
    else
        warn("Save failed:", err)
    end
end)
```

---

## API Reference

### Player‑specific methods

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `InitPlayer` | `(player: Player, dataName: string, template?: table, options?: table)` | `table` | Loads player data from DataStore (or creates from template). Returns the data table. |
| `GetData` | `(player: Player, dataName: string)` | `table` | Returns the cached data table (or empty table if not loaded). |
| `SetData` | `(player: Player, dataName: string, key: string, value: any)` | `nil` | Sets a field, marks dirty if changed. |
| `SetBatch` | `(player: Player, dataName: string, updates: table, force?: boolean)` | `boolean` | Updates multiple fields. Returns `true` if any field changed. |
| `MergeData` | `(player: Player, dataName: string, updates: table, force?: boolean)` | `boolean` | ⚠️ Deprecated – use `SetBatch` instead. |
| `UpdateField` | `(player: Player, dataName: string, key: string, updater: function(old: any) -> any)` | `(boolean, any)` | Atomic field update. Returns `(success, newValue)` or `(false, error)`. |
| `SaveData` | `(player: Player, dataName: string, force?: boolean)` | `(boolean, string?)` | Saves if dirty or forced. Returns `(success, error?)`. |
| `SaveAllDirty` | `(player: Player)` | `(boolean, table?)` | Saves all dirty dataNames for the player. Returns `(success, errors?)`. |
| `IsDirty` | `(player: Player, dataName: string)` | `boolean` | Checks if the data is dirty. |
| `DiscardDirty` | `(player: Player, dataName: string)` | `nil` | Clears dirty flag without saving. |
| `GetCache` | `(player: Player)` | `table?` | Returns the entire cache table for the player (all dataNames). |
| `RemoveField` | `(player: Player, dataName: string, key: string)` | `boolean` | Deletes a field, marks dirty. Returns `true` if field existed. |
| `RemoveData` | `(player: Player, dataName: string, permanent?: boolean)` | `boolean` | Soft (clear cache) or hard (`RemoveAsync`) delete. Returns `true` on success. |
| `ClearCache` | `(player: Player, dataName?: string)` | `nil` | Removes player data from cache. If `dataName` given, only that dataName. |
| `WatchField` | `(player: Player, dataName: string, key: string, callback: function(new, old))` | `function` | Subscribes to field changes. Returns an unsubscribe function. |
| `WatchData` | `(player: Player, dataName: string, callback: function(changes: table))` | `function` | Subscribes to any changes in the dataName. Returns an unsubscribe function. |

### Global data methods

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `InitGlobal` | `(globalKey: string, dataName: string, template?: table, options?: table)` | `table` | Loads (or creates) global data. |
| `GetGlobal` | `(globalKey: string, dataName: string)` | `table` | Returns the global data table. |
| `SetGlobal` | `(globalKey: string, dataName: string, key: string, value: any)` | `nil` | Sets a global field, marks dirty. |
| `SetBatchGlobal` | `(globalKey: string, dataName: string, updates: table, force?: boolean)` | `boolean` | Batch updates global data. Returns `true` if any field changed. |
| `MergeGlobal` | `(globalKey: string, dataName: string, updates: table, force?: boolean)` | `boolean` | ⚠️ Deprecated – use `SetBatchGlobal` instead. |
| `UpdateGlobal` | `(globalKey: string, dataName: string, key: string, updater: function(old: any) -> any)` | `(boolean, any)` | Atomic global field update. |
| `SaveGlobal` | `(globalKey: string, dataName: string, force?: boolean)` | `(boolean, string?)` | Saves global data if dirty or forced. |
| `SaveAllDirtyGlobal` | `()` | `(boolean, table?)` | Saves all dirty global data. |
| `IsGlobalDirty` | `(globalKey: string, dataName: string)` | `boolean` | Checks dirty status. |
| `DiscardGlobalDirty` | `(globalKey: string, dataName: string)` | `nil` | Clears dirty flag without saving. |
| `GetGlobalCache` | `()` | `table` | Returns the entire global cache. |
| `GetGlobalDirtyMap` | `()` | `table` | Returns the global dirty map. |

### Environment & utilities

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `SetKeyPrefix` | `(prefix: string)` | `nil` | Changes the key prefix for player data (default `"plr_"`). |
| `SetStudioMode` | `(enabled: boolean)` | `nil` | `true` = mock DataStore, `false` = real DataStore. |
| `EnableAutoShutdownSave` | `(enabled: boolean)` | `nil` | If `true`, saves all dirty data when server closes. |
| `PurgeAll` | `(permanent?: boolean)` | `(boolean, table?)` | ⚠️ Destructive – clears all player caches. If `permanent`, overwrites DataStore with empty tables. |
| `testing` | | `table` | Test helpers: `_Reset()`, `_ResetGlobals()`, `_GetCache()`, `_GetGlobalCache()`, `_GetDirty()`, `_GetGlobalDirty()`, `_InspectPlayerCache(player)`, `_InspectGlobalCache(globalKey)`, `_InspectPlayerDirty(player)`, `ResetMock()`. |

---

## Advanced Examples

### Atomic currency update
```lua
local ok, newBalance = AdjustedCloud.UpdateField(player, "PlayerData", "Coins", function(old)
    return (old or 0) + 50
end)
```

### Batch update on exit
```lua
Players.PlayerRemoving:Connect(function(player)
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        AdjustedCloud.SetBatch(player, "PlayerData", {
            Coins = leaderstats.Coins.Value,
            Level = leaderstats.Level.Value
        })
    end
    AdjustedCloud.SaveAllDirty(player)
end)
```

### Global data with atomic counter
```lua
local stats = AdjustedCloud.InitGlobal("ServerStats", "GlobalData", { TotalPlayers = 0 })
AdjustedCloud.UpdateGlobal("ServerStats", "GlobalData", "TotalPlayers", function(old)
    return old + 1
end)
```

### Watching for changes
```lua
local unwatch = AdjustedCloud.WatchField(player, "PlayerData", "Coins", function(new, old)
    print(`Coins changed: {old} -> {new}`)
    -- Update UI, trigger achievements, etc.
end)

-- Later, when you no longer need it:
unwatch()
```

### Permanent player wipe
```lua
AdjustedCloud.RemoveData(player, "PlayerData", true)  -- hard delete
```

---

## Testing

AdjustedCloud includes a full test suite with a mock DataStore.  
Run `TestRunner.lua` in Studio to verify everything works.  
Use the `testing` utilities to inspect internal state during development.

```lua
-- Example test usage
local cache = AdjustedCloud.testing._GetCache()
local dirty = AdjustedCloud.testing._GetDirty()
AdjustedCloud.testing._Reset()  -- clear all player caches
```

---

## Contributing

Issues and pull requests are welcome! Please follow the existing code style and add tests for new features.

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Open a pull request

---

## License

MIT © AdjustedTechnologies

---

## Links

- [GitHub Repository](https://github.com/AdjustedTechnologies/Adjusted-Cloud)
- [Roblox Developer Forum Thread](#) (coming soon)
- [Report a Bug](https://github.com/AdjustedTechnologies/Adjusted-Cloud/issues)
