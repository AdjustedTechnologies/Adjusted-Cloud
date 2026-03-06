# AdjustedCloud

**Professional data management framework for Roblox.**  
No magic auto-save. Just caching, dirty flags, atomic operations, and full control.

[![Roblox](https://img.shields.io/badge/Roblox-Studio-blue)](https://www.roblox.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## Philosophy

AdjustedCloud is built for developers who **want to understand and control every aspect** of their game's data.  
Unlike other frameworks that hide complexity behind auto‑save and profiles, AdjustedCloud gives you:

- A **transparent in‑memory cache**.
- **Dirty flags** to track changes.
- **Atomic updates** for safe concurrent access.
- **Full responsibility** for when and how data is saved.

> You are in charge. The framework only provides the tools.

---

## Features

- **Player & Global data**: separate caches and dirty flags.
- **Atomic operations** (`UpdateField` / `UpdateGlobal`) using `UpdateAsync`.
- **Batch updates** (`SetBatch` / `SetBatchGlobal`): update multiple fields, mark dirty only on change.
- **Dirty flag management**: check, discard, save selectively.
- **Configurable key prefix** (default `"plr_"`).
- **Retry logic**: automatic retries with exponential backoff.
- **Studio mode**: use a mock DataStore in Studio (no risk to real data).
- **Auto‑shutdown save** (optional): saves all dirty data when server closes.
- **Data deletion**: remove fields or entire datasets (soft or hard).
- **Cache inspection & reset**: powerful testing utilities.
- **Modular architecture**: easy to extend and maintain.

---

## Installation

1. Copy the `AdjustedCloud` folder into `ReplicatedStorage`.
2. Enable API services: `File → Experience Settings → Security → Enable Studio Access to API Services`.
3. (Optional) Configure your own `DataStoreAccess` module if needed.

---

## Quick Start

```lua
local AdjustedCloud = require(game.ReplicatedStorage.AdjustedCloud)
local Players = game:GetService("Players")

-- (optional) force production mode - use real DataStore even in Studio
AdjustedCloud.SetStudioMode(false)

Players.PlayerAdded:Connect(function(p)
    local data = AdjustedCloud.InitPlayer(p, "MyData")
    if not data.Coins then
        AdjustedCloud.SetData(p, "MyData", "Coins", 100)
    end
    print(p.Name, "has", data.Coins, "coins")
end)

Players.PlayerRemoving:Connect(function(p)
    AdjustedCloud.SaveData(p, "MyData", true) -- force save
end)
```

---

## API Reference

### Player‑specific methods

| Method | Description |
|--------|-------------|
| `InitPlayer(player, dataName, options?)` | Loads (or creates) player data. Returns the data table. |
| `GetData(player, dataName)` | Returns the data table (or empty table if not loaded). |
| `SetData(player, dataName, key, value)` | Sets a field, marks dirty if changed. |
| `SetBatch(player, dataName, updates, force?)` | Batch updates multiple fields. Returns `true` if any change. |
| `MergeData(player, dataName, updates, force?)` | ⚠️ Deprecated alias for `SetBatch`. |
| `UpdateField(player, dataName, key, updater)` | Atomic update using `UpdateAsync`. Returns `success, newValue`. |
| `SaveData(player, dataName, force?)` | Saves if dirty or forced. Returns `success, error`. |
| `SaveAllDirty(player)` | Saves all dirty dataNames for the player. |
| `IsDirty(player, dataName)` | Checks if the data is dirty. |
| `DiscardDirty(player, dataName)` | Clears dirty flag without saving. |
| `GetCache(player)` | Returns the entire cache table for the player (all dataNames). |
| `RemoveField(player, dataName, key)` | Deletes a field (marks dirty). |
| `RemoveData(player, dataName, permanent?)` | Soft (clear cache) or hard (calls `RemoveAsync`) delete. |
| `ClearCache(player, dataName?)` | Removes player data from cache (if `dataName` given, only that dataName). |

### Global data methods

| Method | Description |
|--------|-------------|
| `InitGlobal(globalKey, dataName, options?)` | Loads (or creates) global data. |
| `GetGlobal(globalKey, dataName)` | Returns the global data table. |
| `SetGlobal(globalKey, dataName, key, value)` | Sets a global field, marks dirty. |
| `SetBatchGlobal(globalKey, dataName, updates, force?)` | Batch updates global data. Returns `true` if any change. |
| `MergeGlobal(globalKey, dataName, updates, force?)` | ⚠️ Deprecated alias for `SetBatchGlobal`. |
| `UpdateGlobal(globalKey, dataName, key, updater)` | Atomic update on global field. |
| `SaveGlobal(globalKey, dataName, force?)` | Saves global data if dirty or forced. |
| `SaveAllDirtyGlobal()` | Saves all dirty global data. |
| `IsGlobalDirty(globalKey, dataName)` | Checks dirty status. |
| `DiscardGlobalDirty(globalKey, dataName)` | Clears dirty flag without saving. |
| `GetGlobalCache()` | Returns the entire global cache. |
| `GetGlobalDirtyMap()` | Returns the global dirty map. |

### Environment & utilities

| Method | Description |
|--------|-------------|
| `SetKeyPrefix(prefix)` | Changes the key prefix for player data (default `"plr_"`). |
| `SetStudioMode(enabled)` | `true` = use mock DataStore (Studio), `false` = real DataStore. |
| `EnableAutoShutdownSave(enabled)` | If `true`, saves all dirty data when server closes. |
| `PurgeAll(permanent?)` | ⚠️ Destructive - clears **all** player caches. If `permanent`, also overwrites DataStore with empty tables. |
| `testing` | Table with test helpers: `_Reset()`, `_ResetGlobals()`, `_GetCache()`, `_GetGlobalCache()`, `_GetDirty()`, `_GetGlobalDirty()`, `_InspectPlayerCache(player)`, `_InspectGlobalCache(globalKey)`, `_InspectPlayerDirty(player)`, `ResetMock()`. |

---

## Advanced Examples

### Using atomic updates for currency

```lua
local ok, newBalance = AdjustedCloud.UpdateField(player, "PlayerData", "Coins", function(old)
    return (old or 0) + 50
end)
```

### Batch‑updating leaderstats on exit

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

### Working with global data

```lua
local global = AdjustedCloud.InitGlobal("ServerSettings", "Config")
AdjustedCloud.SetGlobal("ServerSettings", "Config", "EventActive", true)
```

### Deleting a player permanently

```lua
AdjustedCloud.RemoveData(player, "PlayerData", true)  -- hard delete from DataStore
```

### Clearing cache for a specific dataName

```lua
AdjustedCloud.ClearCache(player, "PlayerData")  -- removes from memory only
```

---

## Testing

AdjustedCloud includes a full test suite with a mock DataStore.  
Run `TestRunner.lua` in Studio to verify everything works.  
Use the `testing` utilities to inspect internal state during development.

---

## License

MIT © AdjustedTechnologies

---

## Contributing

Issues and pull requests are welcome! Please follow the existing code style and add tests for new features.

---

## Links

- [GitHub Repository](https://github.com/AdjustedTechnologies/AdjustedCloud)
- [Roblox Developer Forum Thread](#) (coming soon)
- [Documentation Wiki](https://github.com/AdjustedTechnologies/AdjustedCloud/wiki)
```
