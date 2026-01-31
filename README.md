# Advance Dialog System V2

A modern and clean dialog system for FiveM. Register your menus once and use them on any entity with protected execution and automatic navigation.

## Main Features

- ✅ **Clean API**: `registerDialog()` + `openDialog()` - No complications
- ✅ **Direct onSelect**: Linear code without nested tables
- ✅ **TaskAPI**: Simple methods like `task.goTo()`, `task.playAnim()`, `task.progress()`
- ✅ **Automatic Protection**: Errors don't block NUI
- ✅ **Smart Navigation**: Automatic "Back" button with history
- ✅ **Real Duration**: `task.getAnimDuration()` uses native FiveM times
- ✅ **Smart Movement**: `goTo()` with timeout and automatic slide
- ✅ **Full Camera System**: 4 modes (static, follow, track, orbit) with bone support
- ✅ **Facial Animations**: Presets for moods (happy, angry, sad, surprised, etc.)

## Quick Start

```lua
-- 1. Register your menu (once at startup)
exports['advance-dialog']:registerDialog({
    id = "mechanic_menu",
    speaker = "Mechanic",
    text = "What do you need?",
    metadata = {
        shopName = "Central Garage",
        maxDistance = 5.0
    },
    canInteract = function(ctx, targetPed)
        -- Check distance when opening
        local dist = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(targetPed))
        return dist <= ctx.metadata.maxDistance
    end,
    options = {
        {
            label = "Repair Engine",
            icon = "🔧",
            canInteract = function(ctx)
                -- Check if there's a damaged vehicle
                local veh = GetVehiclePedIsIn(PlayerPedId(), false)
                return veh ~= 0 and GetVehicleEngineHealth(veh) < 1000
            end,
            onSelect = function(ctx, task)
                -- Clean linear code
                local veh = GetVehiclePedIsIn(PlayerPedId(), false)
                
                task.closeDialog()
                task.goTo(ctx.ped, veh, {x=0, y=2.5, z=0}, {
                    timeout = 10000,  -- Maximum 10 seconds
                    slide = true      -- Teleport if doesn't arrive
                })
                
                -- Animation with exact duration
                local dur = task.getAnimDuration("mini@repair", "fixing_a_player") * 1000
                task.playAnim("mini@repair", "fixing_a_player", dur)
                task.progress("Repairing...", dur)
                
                SetVehicleFixed(veh)
                
                -- Return to menu
                task.showDialog("mechanic_menu")
            end
        },
        {
            label = "View Services",
            next = "mechanic_services"  -- Go to another menu
        },
        {
            label = "← Back",
            action = "back"  -- Returns automatically
        },
        {
            label = "Exit",
            action = "close"
        }
    }
})

-- 2. Create ped and assign interaction
local mechanic = CreatePed(4, GetHashKey("s_m_y_xmech_02"), 815.0, -944.0, 25.0, 90.0, false, true)
FreezeEntityPosition(mechanic, true)

-- 3. Open dialog on interaction
exports.ox_target:addLocalEntity(mechanic, {
    {
        label = "Talk to mechanic",
        onSelect = function()
            exports['advance-dialog']:openDialog(mechanic, "mechanic_menu")
        end
    }
})
```

## V2 API Reference

### registerDialog(config)

Registers a menu to use multiple times.

```lua
exports['advance-dialog']:registerDialog({
    id = "string",              -- Unique identifier (required)
    speaker = "string",         -- NPC name
    text = "string",            -- Dialog text (required)
    metadata = {},              -- Static data or functions
    canInteract = fn,           -- Global validation function
    onError = fn,               -- Error handler
    options = {}                -- Array of options
})
```

#### Option Structure

```lua
options = {
    {
        label = "string",           -- Visible text (required)
        icon = "string",            -- Emoji or icon
        description = "string",     -- Tooltip
        canInteract = fn,           -- Per-option validation
        
        -- One of these actions:
        onSelect = fn,              -- Execute code
        next = "dialog_id",         -- Go to another menu
        action = "back"            -- "back" or "close"
    }
}
```

### openDialog(entity, dialogId, dynamicMetadata)

Opens a registered menu on an entity.

```lua
exports['advance-dialog']:openDialog(
    entity,                     -- Ped, vehicle, coords, or netId
    "dialog_id",               -- Registered dialog ID
    {                          -- Optional: dynamic metadata
        vehicle = cache.vehicle,
        playerJob = jobName
    }
)
```

### onSelect(ctx, task)

Callback that receives two parameters:

```lua
onSelect = function(ctx, task)
    -- ctx: Complete context
    --   ctx.dialog        -- Dialog config
    --   ctx.dialogId      -- Current ID
    --   ctx.ped          -- Target ped/entity
    --   ctx.playerPed    -- Player ped
    --   ctx.metadata     -- Merged metadata (static + dynamic)
    
    -- task: Object with methods
    --   task.closeDialog()
    --   task.showDialog("id")
    --   task.goBack()
    --   task.wait(ms)
    --   task.goTo(ped, target, offset, options)
    --   task.playAnim(dict, anim, duration)
    --   task.getAnimDuration(dict, anim)
    --   task.playFacial(anim, duration)
    --   task.progress(label, duration)
    --   task.camera.create(config)
end
```

## Complete Task API

### Dialog
- `task.closeDialog()` - Closes current menu
- `task.showDialog(dialogId)` - Opens another registered menu
- `task.goBack()` - Returns to previous menu

### Wait
- `task.wait(ms)` - Waits in milliseconds

### Movement
- `task.goTo(ped, target, offset, options)` - Moves ped to target
  - `target`: entity, vector3, coords table, "player", "vehicle"
  - `options`: `{timeout = ms, slide = bool, arriveDistance = num}`
  - Returns: `true` if arrived, `false` if timeout/slide

### Animations
- `task.playAnim(dict, anim, duration, options)` - Plays animation
- `task.getAnimDuration(dict, anim)` - Gets real duration in seconds
- `task.playFacial(animName, duration, options)` - Facial animation with presets
- `task.playScenario(scenarioName, duration, options)` - Scenario

**Facial Presets:**
- Moods: happy, angry, sad, surprised, aiming, injured, concentrated, normal
- Reactions: shocked, sleeping, dead, knockout
- Pain: pain_1, pain_2, pain_3
- Eyes: blink, blink_long, wink_left, wink_right

### Progress
- `task.progress(label, duration, options)` - Progress bar

### Camera
- `task.camera.create(config)` - Creates camera
- `task.camera.destroy()` - Destroys camera
- `task.camera.lookAt(target)` - Looks at target
- `task.camera.follow(target, offset, options)` - Quick follow preset
- `task.camera.track(coords, target, options)` - Quick track preset
- `task.camera.orbit(target, radius, height, speed, options)` - Quick orbit preset
- `task.camera.static(coords, lookAtTarget, options)` - Quick static preset

**Camera Modes:**
- static: Fixed position
- follow: Moves with target maintaining offset
- track: Fixed position, points at moving target
- orbit: Rotates around target in circle

**Camera Config:**
```lua
{
    mode = "static" | "follow" | "track" | "orbit",
    target = entity | "player" | "ped" | "vehicle" | "engine",
    coords = {x, y, z},
    offset = {x, y, z},
    bone = string,  -- e.g., "head", "wheel_lf"
    fov = number,
    radius = number,  -- For orbit mode
    height = number,   -- For orbit mode
    speed = number,   -- For orbit mode
    lerp = boolean
}
```

### Enhanced Movement (With Bone Support)
- `task.goToVehicle(movingPed, targetVehicle, bone, offset, options)` - Go to vehicle bone
- `task.goToPed(movingPed, targetPed, bone, offset, options)` - Go to ped bone
  - `bone`: Vehicle bones ("bonnet", "boot", "door_dside_f") or Ped bones ("head", "spine3")
  - `offset`: {x, y, z} relative to bone position

### Vehicle Helpers
- `task.vehicle.getClosest(radius, coords)` - Get closest vehicle
- `task.vehicle.getByModel(model, radius, coords)` - Get closest by model hash
- `task.vehicle.getByPlate(plate)` - Find vehicle by license plate
- `task.vehicle.getInFront(ped, maxDist)` - Get vehicle in front of ped

### Ped Helpers
- `task.ped.getClosest(radius, coords, includePlayer)` - Get closest ped
- `task.ped.getByModel(model, radius, coords)` - Get closest by model hash
- `task.ped.getInFront(ped, maxDist)` - Get ped in front
- `task.ped.isDead(ped)` - Check if ped is dead/dying
- `task.ped.isInVehicle(ped)` - Check if ped is in vehicle
- `task.ped.getDistanceTo(ped, target)` - Get distance to entity/coords
- `task.ped.getInRange(radius, coords, includePlayer)` - Get all peds in radius

### Player Helpers
- `task.player.getVehicle()` - Get player's vehicle (or nil)
- `task.player.getPed()` - Get player ped
- `task.player.getCoords()` - Get player coordinates
- `task.player.isInVehicle()` - Check if player is in vehicle
- `task.player.isOnFoot()` - Check if player is on foot
- `task.player.getDistanceTo(target)` - Get distance to target

### Entity Helpers
- `task.entity.getClosest(radius, coords, filter)` - Get closest entity
  - `filter`: "vehicle", "ped", "object", or nil (any)
- `task.entity.isValid(entity)` - Check if entity exists
- `task.entity.isInRange(entity, radius, coords)` - Check range
- `task.entity.getDistance(entity, target)` - Get distance

### Camera Shortcuts
- `task.camera.lookAtPed(ped)` - Look at ped (with head bone)
- `task.camera.lookAtVehicle(veh)` - Look at vehicle
- `task.camera.lookAtPlayer()` - Look at player

### Search Helpers
- `task.search.vehiclesByModel(model, radius, coords)` - Get all vehicles by model
- `task.search.pedsByModel(model, radius, coords)` - Get all peds by model
- `task.search.vehiclesInRange(radius, coords)` - Get all vehicles in range
- `task.search.pedsInRange(radius, coords, includePlayer)` - Get all peds in range

## Menu Navigation

### Automatic History

```lua
-- Main menu
exports['advance-dialog']:registerDialog({
    id = "main_menu",
    options = {
        {label = "Services", next = "services_menu"},
        {label = "Exit", action = "close"}
    }
})

-- Sub-menu with back button
exports['advance-dialog']:registerDialog({
    id = "services_menu",
    options = {
        {label = "Repair", onSelect = ...},
        {label = "Paint", onSelect = ...},
        {label = "← Back", action = "back"}  -- Returns to main_menu
    }
})
```

The "Back" button appears automatically when there's history.

## Error Protection

Every `onSelect` runs in a protected thread:

```lua
onSelect = function(ctx, task)
    -- If this fails...
    error("Something went wrong!")
    
    -- The system automatically:
    -- 1. Catches error (no crash)
    -- 2. Calls onError if defined
    -- 3. Returns to previous menu or closes dialog
    -- 4. NUI never gets blocked
end
```

## Data Persistence (SQL)

Save player progress, quest states, NPC relationships, and any data you need.

### Database Setup (MariaDB Recommended)

We **strongly recommend MariaDB** for automatic data management via triggers.

**Automatic Features (Zero Lua Code Required):**
- ✅ **100 entries limit per player**: Auto-deletes oldest when limit reached
- ✅ **30-day expiration**: Auto-cleans old data every 24 hours
- ✅ **Zero performance impact**: All logic runs in database, not Lua

### Setup Instructions

**1. Enable Event Scheduler** (run once in your database):
```sql
SET GLOBAL event_scheduler = ON;
```

**2. Create Table** (automatic or manual):
```sql
-- The resource auto-creates the table, or run: docs/database_setup.sql
```

### Why MariaDB?

| Feature | MariaDB | MySQL | KVP (Default) |
|---------|---------|-------|---------------|
| Auto-triggers | ✅ Native | ✅ Native | ❌ Manual Lua |
| Auto-cleanup events | ✅ Native | ✅ Native | ❌ Manual |
| Performance | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ |
| Persistence | Server | Server | Local PC |
| Framework needed | oxmysql | oxmysql | None |

### Configuration

```lua
-- server/config_database.lua (server-side only, never exposed to client)
ConfigDatabase = {
    provider = "oxmysql",  -- Only oxmysql supported for SQL
    
    -- Player identifier type:
    identifier = {
        type = "license",        -- FiveM license (default, framework-agnostic)
        -- type = "citizenid",   -- QBCore
        -- type = "identifier",  -- ESX
        -- type = "custom",      -- Your own function
    },
    
    -- Table configuration
    table = {
        name = "advance_dialog_data",
        autoCreate = true,  -- Creates table + triggers automatically
    },
    
    -- Custom queries (optional, nil = use automatic triggers)
    queries = {
        insert = nil,  -- Uses automatic limit trigger
        select = nil,
        update = nil,
        delete = nil,
    },
    
    -- Limits (enforced by MariaDB triggers, not Lua)
    limits = {
        maxEntriesPerPlayer = 100,
        autoDeleteOldest = true,
        expirationDays = 30,
    }
}
```

### API Usage

```lua
-- Save data (async with callback)
task.data.set("quest_progress", 5, function(success)
    if success then
        print("Saved!")
    end
end)

-- Read data (async)
task.data.get("quest_progress", 0, function(value)
    print("Progress: " .. tostring(value))
end)

-- Read data (sync - waits for response)
local progress = task.data.getSync("quest_progress", 0)

-- Mark dialog as completed
task.data.markCompleted("quest_1")

-- Check if completed
task.data.isCompleted("quest_1", function(completed)
    if completed then
        print("Already done this quest")
    end
end)

-- Remove specific data
task.data.remove("temp_value")

-- Clear all data for player
task.data.clear(function(success)
    print("All data cleared")
end)
```

### Example: Quest System with Persistence

```lua
exports['advance-dialog']:registerDialog({
    id = "quest_giver",
    speaker = "Quest Giver",
    text = "I have a task for you.",
    options = {
        {
            label = "Check Status",
            onSelect = function(ctx, task)
                task.data.isCompleted("main_quest", function(done)
                    if done then
                        print("Quest already completed!")
                    else
                        local progress = task.data.getSync("quest_progress", 0)
                        print(string.format("Progress: %d/5", progress))
                    end
                    task.showDialog("quest_giver")
                end)
            end
        },
        {
            label = "Complete Step",
            onSelect = function(ctx, task)
                local progress = task.data.getSync("quest_progress", 0)
                progress = progress + 1
                
                if progress >= 5 then
                    task.data.markCompleted("main_quest")
                    print("Quest completed!")
                else
                    task.data.set("quest_progress", progress)
                    print(string.format("Progress: %d/5", progress))
                end
                
                task.showDialog("quest_giver")
            end
        }
    }
})
```

### Security

- ✅ **Server-side only**: SQL config never exposed to client
- ✅ **Automatic sanitization**: All queries use parameterized statements
- ✅ **Identifier validation**: Player ID verified server-side
- ✅ **No client authority**: Client cannot spoof data or access other players' data

### Custom SQL (Advanced)

If you need custom table structure:

```lua
ConfigDatabase.table.autoCreate = false
ConfigDatabase.queries.insert = "INSERT INTO my_custom_table (...) VALUES (...)"
ConfigDatabase.queries.select = "SELECT value FROM my_custom_table WHERE ..."
```

---

## Complete Examples

### Complete Mechanic

See `examples_v2.lua` for complete example with:
- Dialog registration
- Ped creation
- ox_target interaction
- Vehicle movement
- Animations with real duration
- Menu navigation

## Configuration

```lua
Config = {
    -- UI
    closeKey = 27,              -- Escape
    
    -- Protection
    taskTimeout = 30000,        -- onSelect timeout (ms)
    
    -- Camera
    cameraLerpFactor = 0.3,
    cameraAutoDestroy = true,
    
    -- Progress
    progressProvider = "none",  -- "ox_lib", "qb-progressbar", "mythic", "none"
    
    -- Debug
    enableDebug = false
}
```

## Available Exports

### New V2 System
```lua
exports['advance-dialog']:registerDialog(config)
exports['advance-dialog']:openDialog(entity, dialogId, metadata)
exports['advance-dialog']:goBack()
exports['advance-dialog']:getHistory()
exports['advance-dialog']:clearHistory()
```

---

**Version:** 2.0.0  
**Author:** JericoFX  
**License:** GPL3
