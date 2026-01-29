# Advance Dialog System

A flexible and powerful dialog system for FiveM with dynamic camera tracking, task sequences, and dual action registration.

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Dynamic Camera System](#dynamic-camera-system)
- [Task System](#task-system)
- [Mutable Context](#mutable-context)
- [Action Registration](#action-registration)
- [Examples](#examples)
- [API Reference](#api-reference)
- [Configuration](#configuration)

## Features

- **Dynamic Camera System**: Four camera modes (static, follow, track, orbit) with smooth movement
- **Task Sequences**: Chain multiple actions together with flow control
- **Dual Action Registration**: Global actions (all dialogs) and dialog-specific actions
- **Mutable Context**: Share data between actions in a sequence
- **Bone Support**: Target specific bones (wheel_lf, engine, head, etc.)
- **Validation**: Server-side dialog validation and rate limiting
- **Progress Bars**: Support for ox_lib, qb-progressbar, mythic, or NUI fallback
- **Animations**: Body and facial animation support with presets
- **Ped Creation**: Helper functions for creating and configuring peds

## Installation

1. Drop the `advance-dialog` folder into your `resources/` directory
2. Add `ensure advance-dialog` to your `server.cfg`
3. Configure `config.lua` to your preferences
4. Restart your server

## Quick Start

### Basic Dialog

```lua
exports['advance-dialog']:registerDialogs({
    welcome = {
        speaker = "NPC",
        text = "Welcome to the server!",
        options = {
            { label = "Thanks!", close = true }
        }
    }
})

-- Open the dialog
exports['advance-dialog']:openDialogById("welcome")
```

### Dialog with Task Sequence

```lua
exports['advance-dialog']:registerDialogs({
    quest_giver = {
        speaker = "Quest Giver",
        text = "I need you to do something for me.",
        options = {
            {
                label = "Accept Quest",
                task = function(ctx)
                    return {
                        sequence = {
                            { type = "dialogClose" },
                            { type = "playAnim", dict = "gestures", anim = "thumbs_up", duration = 2000 },
                            { type = "wait", duration = 1000 },
                            { type = "goTo", target = "player", offset = {x=0, y=1.5, z=0} }
                        }
                    }
                end
            },
            { label = "Decline", close = true }
        }
    }
})
```

## Dynamic Camera System

The Advance Dialog system includes a powerful camera system with four modes. Cameras can follow peds, track moving targets, or orbit around entities.

### Camera Modes

#### 1. Static Mode (Default)
Camera is placed at a fixed position and doesn't move.

```lua
{ 
    type = "camera", 
    action = "create", 
    mode = "static",
    coords = {x=100, y=200, z=30},
    fov = 45
}
```

**Parameters:**
- `coords` (table): Fixed camera position {x, y, z}
- `fov` (number): Field of view (default: 45)
- `fadeTime` (number): Transition time in ms (default: 250)

#### 2. Follow Mode
Camera moves with the target, maintaining relative offset. Perfect for following an NPC as they walk.

```lua
{
    type = "camera",
    action = "create",
    mode = "follow",
    target = "ped",              -- "ped", "player", "vehicle"
    offset = {x=2, y=0, z=1.5},  -- Relative offset from target
    bone = "head",               -- Optional: follow specific bone
    fov = 50,
    lerp = true                  -- Smooth movement (default: true)
}
```

**How it works:**
- Camera continuously updates position to maintain offset from target
- If target moves, camera follows smoothly
- Configurable via `Config.cameraLerpFactor` (0.0-1.0)

**Parameters:**
- `target` (string): "ped", "player", "vehicle", "engine"
- `offset` (table): {x, y, z} relative to target
- `bone` (string): Optional bone name (e.g., "head", "wheel_lf")
- `lerp` (boolean): Enable smooth interpolation (default: true)

#### 3. Track Mode
Camera stays at a fixed position but continuously points at a moving target.

```lua
{
    type = "camera",
    action = "create",
    mode = "track",
    coords = {x=100, y=200, z=30},  -- Fixed camera position
    target = "player",               -- What to track
    bone = "head",                   -- Optional: track specific bone
    fov = 45
}
```

**Use Cases:**
- Security camera watching a player
- Fixed camera angle that follows action
- Dramatic reveals

**Parameters:**
- `coords` (table): Fixed camera position {x, y, z}
- `target` (string): Entity to track
- `bone` (string): Optional bone to track

#### 4. Orbit Mode
Camera rotates around the target in a circle.

```lua
{
    type = "camera",
    action = "create",
    mode = "orbit",
    target = "vehicle",
    radius = 3.5,       -- Distance from target
    height = 0.8,       -- Height offset from target
    speed = 1.0,        -- Rotation speed (degrees/frame)
    fov = 60
}
```

**How it works:**
- Camera moves in a circular path around target
- Continuously points at target center
- Speed and direction configurable

**Parameters:**
- `radius` (number): Circle radius (default: 3.0)
- `height` (number): Height above target (default: 1.5)
- `speed` (number): Rotation speed in degrees/frame (default: 1.0)
  - Positive = clockwise
  - Negative = counter-clockwise

### Camera Actions

#### Create Camera
```lua
{ type = "camera", action = "create", mode = "follow", target = "ped", ... }
```

#### Look At (for static mode)
```lua
{ type = "camera", action = "lookAt", target = "player" }
```

#### Destroy Camera
```lua
{ type = "camera", action = "destroy" }
```

**Auto-Destruction:**
Cameras are automatically destroyed at the end of task sequences (configurable via `Config.cameraAutoDestroy`).

### Bone Targeting

Cameras can target specific bones on entities:

```lua
-- Target vehicle's engine
{ type = "camera", action = "create", target = "engine", mode = "follow", offset = {x=0, y=1.5, z=0.5} }

-- Target ped's head
{ type = "camera", action = "create", target = "ped", bone = "head", mode = "follow", offset = {x=1, y=0, z=0} }

-- Target specific wheel
{ type = "camera", action = "create", target = "vehicle", bone = "wheel_lf", mode = "orbit", radius = 2.0 }
```

**Common Bones:**
- Vehicle: "engine", "bonnet", "wheel_lf", "wheel_rf", "wheel_lr", "wheel_rr"
- Ped: "head", "neck", "spine", "hand_l", "hand_r"

### Camera Configuration

```lua
Config = {
    -- ... other configs ...
    
    -- Camera movement smoothing (0.0 = instant, 1.0 = very smooth)
    cameraLerpFactor = 0.3,
    
    -- Orbit rotation direction
    cameraOrbitDirection = "clockwise",  -- "clockwise" or "counter"
    
    -- Auto destroy camera when task sequence ends
    cameraAutoDestroy = true
}
```

## Task System

The task system allows you to create sequences of actions that execute in order. Actions can be built-in or custom-registered.

### Built-in Actions

#### dialogClose
Closes the current dialog.
```lua
{ type = "dialogClose" }
```

#### wait
Pauses execution for specified duration.
```lua
{ type = "wait", duration = 3000 }
```

#### progress
Shows a progress bar.
```lua
{ 
    type = "progress", 
    label = "Working...", 
    duration = 5000 
}
```

#### camera
Manages camera (see Camera System section).
```lua
{ type = "camera", action = "create", mode = "follow", target = "ped" }
```

#### goTo
Moves ped to coordinates or entity.
```lua
-- Go to specific coordinates
{ type = "goTo", coords = {x=100, y=200, z=30} }

-- Go to entity with offset
{ type = "goTo", target = "vehicle", offset = {x=0, y=2, z=0} }

-- Go to specific bone
{ type = "goTo", target = "vehicle", bone = "engine", offset = {x=0, y=1.5, z=0} }
```

**Parameters:**
- `target`: "ped", "player", "vehicle"
- `coords`: Direct coordinates {x, y, z}
- `offset`: Relative offset from target
- `bone`: Optional bone name
- `speed`: Movement speed (default: 1.0)
- `arriveDistance`: Distance to consider "arrived" (default: 1.5)
- `waitForArrival`: Wait until ped arrives (boolean)
- `timeout`: Maximum wait time in ms (default: 10000)

#### playAnim
Plays an animation.
```lua
{
    type = "playAnim",
    dict = "mini@repair",
    anim = "fixing_a_player",
    duration = 5000,
    blocking = false,  -- Wait for animation to finish
    flag = DialogEnums.AnimationFlag.UPPER_BODY
}
```

#### playFacial
Plays a facial animation.
```lua
{
    type = "playFacial",
    facial = "mood_happy",
    dict = "facials@gen_male@variations@happy",
    duration = 2000,
    blocking = false
}
```

#### attack
Makes ped attack target.
```lua
{ type = "attack", target = "player" }
-- or with net ID:
{ type = "attack", targetNetId = 12345 }
```

#### follow
Makes ped follow target.
```lua
{
    type = "follow",
    target = "player",
    offsetX = 1.0,
    offsetY = 0,
    offsetZ = 0,
    speed = 1.0,
    stoppingRange = 1.0
}
```

#### wander
Makes ped wander randomly.
```lua
{ type = "wander", wanderRadius = 10.0, wanderDuration = 10.0 }
```

#### scenario
Makes ped play a scenario.
```lua
{ type = "scenario", name = "WORLD_HUMAN_CLIPBOARD" }
```

#### run
Executes custom Lua function (see Mutable Context section).
```lua
{ type = "run", fn = function(ctx) ... end }
```

## Mutable Context

The context (`ctx`) is shared across all actions in a sequence. You can store data in one action and access it in subsequent actions.

### Basic Usage

```lua
task = function(ctx)
    return {
        sequence = {
            -- Store data in ctx
            { type = "run", fn = function(ctx)
                ctx.myData = "Hello from first action!"
                ctx.playerName = GetPlayerName(PlayerId())
            end},
            
            -- Access stored data
            { type = "run", fn = function(ctx)
                print(ctx.myData)  -- "Hello from first action!"
                print(ctx.playerName)
            end}
        }
    }
end
```

### Dynamic Properties with resolveValue

Any property in an action can be either a static value or a function that receives `ctx`:

```lua
task = function(ctx)
    return {
        sequence = {
            -- Store wheel information
            { type = "run", fn = function(ctx)
                ctx.targetWheel = "wheel_lf"
                ctx.repairTime = 5000
            end},
            
            -- Use function to get dynamic value
            { 
                type = "goTo", 
                target = "vehicle",
                bone = function(ctx) return ctx.targetWheel end,  -- Dynamic!
                offset = {x=0.5, y=0, z=0}
            },
            
            -- Dynamic duration
            { 
                type = "progress", 
                label = "Repairing...",
                duration = function(ctx) return ctx.repairTime end  -- Dynamic!
            }
        }
    }
end
```

### Practical Example: Dynamic Wheel Repair

```lua
exports['advance-dialog']:registerDialogs({
    mechanic = {
        speaker = "Mechanic",
        text = "Which wheel needs repair?",
        metadata = {vehicleNetId = VehToNet(cache.veh)}, -- Set when opening dialog
        options = {
            {
                label = "Auto-detect",
                task = function(ctx)
                    return {
                        sequence = {
                            -- Detect burst wheel
                            { type = "run", fn = function(ctx)
                                local vehicle = NetToVeh(ctx.mergedMetadata.vehicleNetId)
                                
                                for i = 0, 5 do
                                    if IsVehicleTyreBurst(vehicle, i, false) then
                                        ctx.wheelIndex = i
                                        ctx.wheelBone = (i == 0 and "wheel_lf") or
                                                       (i == 1 and "wheel_rf") or
                                                       (i == 4 and "wheel_lr") or
                                                       (i == 5 and "wheel_rr") or "wheel_lm"
                                        ctx.hasBurstWheel = true
                                        break
                                    end
                                end
                                
                                ctx.hasBurstWheel = ctx.hasBurstWheel or false
                            end},
                            
                            -- Go to detected wheel (or engine if none)
                            { 
                                type = "goTo", 
                                target = "vehicle",
                                bone = function(ctx) 
                                    return ctx.hasBurstWheel and ctx.wheelBone or "engine"
                                end,
                                offset = {x=0.5, y=0, z=0}
                            },
                            
                            -- Repair time based on condition
                            { 
                                type = "progress", 
                                label = function(ctx)
                                    return ctx.hasBurstWheel and "Changing wheel..." or "Inspecting..."
                                end,
                                duration = function(ctx)
                                    return ctx.hasBurstWheel and 4000 or 2000
                                end
                            }
                        }
                    }
                end
            }
        }
    }
})
```

## Action Registration

Register custom actions to reuse logic across dialogs. Actions can be **global** (available everywhere) or **dialog-specific**.

### Global Actions

Available in all dialogs:

```lua
-- Register global action
exports['advance-dialog']:registerTaskAction(nil, 'repairVehicle', function(ctx, action, ped)
    local vehicle = NetToVeh(ctx.mergedMetadata.vehicleNetId)
    if vehicle and DoesEntityExist(vehicle) then
        SetVehicleFixed(vehicle)
        SetVehicleEngineHealth(vehicle, 1000.0)
    end
end)

-- Use in any dialog
{ type = "repairVehicle" }
```

### Dialog-Specific Actions

Only available in specific dialogs:

```lua
-- Register for mechanic dialog only
exports['advance-dialog']:registerTaskAction('mechanic', 'advancedDiagnostic', function(ctx, action, ped)
    -- Special diagnostic logic only for mechanic
    local vehicle = NetToVeh(ctx.mergedMetadata.vehicleNetId)
    -- ... complex diagnostic code ...
end)

-- This will ERROR in other dialogs!
-- Only works in dialog with id "mechanic"
{ type = "advancedDiagnostic" }
```

### Resolution Order

When executing a custom action:
1. Look for dialog-specific action first
2. If not found, look for global action
3. If not found, error

This allows overriding global actions per dialog:

```lua
-- Global: Simple open hood
exports['advance-dialog']:registerTaskAction(nil, 'openHood', function(ctx, action, ped)
    local vehicle = NetToVeh(ctx.mergedMetadata.vehicleNetId)
    SetVehicleDoorOpen(vehicle, 4, false, false)
end)

-- Override for premium mechanic: Also checks fluids
exports['advance-dialog']:registerTaskAction('premium_mechanic', 'openHood', function(ctx, action, ped)
    local vehicle = NetToVeh(ctx.mergedMetadata.vehicleNetId)
    SetVehicleDoorOpen(vehicle, 4, false, false)
    -- Additional premium checks...
    ctx.fluidLevel = GetVehicleOilLevel(vehicle)
end)
```

### Action Parameters

Custom actions receive three parameters:

```lua
exports['advance-dialog']:registerTaskAction(nil, 'myAction', function(ctx, action, ped)
    -- ctx: Context object with dialog data, metadata, player info
    -- action: The action configuration table (with resolved values)
    -- ped: The ped entity handle
    
    -- Access action parameters
    local customParam = action.myParameter
    local speed = action.speed
    
    -- Modify context for subsequent actions
    ctx.result = "Action completed!"
end)

-- Usage with parameters:
{ type = "myAction", myParameter = "value", speed = 2.0 }
```

## Examples

### Example 1: Complete Mechanic Flow

```lua
-- Register custom actions
exports['advance-dialog']:registerTaskAction(nil, 'openHood', function(ctx, action, ped)
    local vehicle = NetToVeh(ctx.mergedMetadata.vehicleNetId)
    if vehicle then SetVehicleDoorOpen(vehicle, 4, false, false) end
end)

exports['advance-dialog']:registerTaskAction(nil, 'closeHood', function(ctx, action, ped)
    local vehicle = NetToVeh(ctx.mergedMetadata.vehicleNetId)
    if vehicle then SetVehicleDoorShut(vehicle, 4, false) end
end)

exports['advance-dialog']:registerTaskAction(nil, 'fixEngine', function(ctx, action, ped)
    local vehicle = NetToVeh(ctx.mergedMetadata.vehicleNetId)
    if vehicle then
        SetVehicleFixed(vehicle)
        SetVehicleEngineHealth(vehicle, 1000.0)
    end
end)

-- Create dialog
exports['advance-dialog']:registerDialogs({
    mechanic_full_service = {
        id = "mechanic_full_service",
        speaker = "Mechanic",
        text = "I'll perform a full diagnostic on your vehicle. This will take a few minutes.",
        metadata = { vehicleNetId = nil }, -- Set when opening dialog
        options = {
            {
                label = "Start Service ($500)",
                task = function(ctx)
                    return {
                        sequence = {
                            -- Close dialog and begin
                            { type = "dialogClose" },
                            
                            -- Walk to vehicle
                            { 
                                type = "goTo", 
                                target = "vehicle", 
                                offset = {x=0, y=2.5, z=0},
                                arriveDistance = 1.5
                            },
                            
                            -- Camera follows mechanic
                            { 
                                type = "camera", 
                                action = "create", 
                                mode = "follow",
                                target = "ped",
                                offset = {x=2.0, y=-1.5, z=1.2},
                                fov = 45
                            },
                            
                            -- Open hood
                            { type = "openHood" },
                            
                            -- Inspect animation
                            { 
                                type = "playAnim", 
                                dict = "mini@repair", 
                                anim = "fixing_a_player",
                                duration = 3000,
                                blocking = false
                            },
                            
                            -- Diagnostic progress
                            { 
                                type = "progress", 
                                label = "Running diagnostics...",
                                duration = 3000
                            },
                            
                            -- Check what needs repair (context)
                            { type = "run", fn = function(ctx)
                                local vehicle = NetToVeh(ctx.mergedMetadata.vehicleNetId)
                                ctx.engineHealth = GetVehicleEngineHealth(vehicle)
                                ctx.bodyHealth = GetVehicleBodyHealth(vehicle)
                                ctx.needsRepair = ctx.engineHealth < 1000 or ctx.bodyHealth < 1000
                            end},
                            
                            -- Perform repair
                            { type = "playAnim", dict = "mini@repair", anim = "fixing_a_player", duration = 5000, blocking = false },
                            { type = "progress", label = "Repairing engine...", duration = 5000 },
                            { type = "fixEngine" },
                            
                            -- Close hood
                            { type = "closeHood" },
                            
                            -- Camera to orbit mode to show off vehicle
                            { 
                                type = "camera", 
                                action = "create", 
                                mode = "orbit",
                                target = "vehicle",
                                radius = 4.0,
                                height = 1.0,
                                speed = 1.5,
                                fov = 55
                            },
                            
                            -- Wait while camera shows vehicle
                            { type = "wait", duration = 4000 },
                            
                            -- Destroy camera
                            { type = "camera", action = "destroy" },
                            
                            -- Return to player
                            { 
                                type = "goTo", 
                                target = "player", 
                                offset = {x=0, y=1.5, z=0},
                                arriveDistance = 1.5
                            },
                            
                            -- Done animation
                            { type = "playAnim", dict = "gestures", anim = "thumbs_up", duration = 2000 },
                            
                            -- Open completion dialog after delay
                            { type = "run", fn = function(ctx)
                                local message = ctx.needsRepair and 
                                    "All done! Your vehicle is fully repaired." or
                                    "Good news! Your vehicle was already in perfect condition."
                                
                                -- You could pass this to next dialog via metadata if needed
                                TriggerServerEvent('mechanic:chargePlayer', 500)
                                
                                -- Open completion dialog
                                exports['advance-dialog']:openDialogById("mechanic_complete", ctx.ped)
                            end}
                        },
                        keepDialog = false
                    }
                end
            },
            { label = "Not now", close = true }
        }
    },
    
    mechanic_complete = {
        id = "mechanic_complete",
        speaker = "Mechanic",
        text = "Service complete! Is there anything else you need?",
        options = {
            { label = "That's all, thanks!", close = true }
        }
    }
})

-- Usage:
-- local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
-- local netId = VehToNet(vehicle)
-- exports['advance-dialog']:showDialog({
--     id = "mechanic_full_service",
--     metadata = { vehicleNetId = netId }
-- }, mechanicPed)
```

### Example 2: Police Interaction with Camera

```lua
exports['advance-dialog']:registerDialogs({
    police_checkpoint = {
        speaker = "Officer",
        text = "License and registration, please.",
        options = {
            {
                label = "Show Documents",
                task = function(ctx)
                    return {
                        sequence = {
                            -- Camera tracks player from officer's position
                            { 
                                type = "camera", 
                                action = "create", 
                                mode = "track",
                                target = "player",
                                coords = function(ctx)
                                    -- Position camera at officer's shoulder
                                    local officerPos = GetEntityCoords(ctx.ped)
                                    return {x=officerPos.x, y=officerPos.y, z=officerPos.z + 0.5}
                                end,
                                fov = 40
                            },
                            
                            -- Player reaches for documents
                            { type = "playAnim", dict = "mp_common", anim = "givetake1_a", duration = 2000, blocking = false },
                            { type = "wait", duration = 2000 },
                            
                            -- Officer inspects
                            { type = "playAnim", dict = "amb@world_human_clipboard@male@base", anim = "base", duration = 3000, blocking = false },
                            { type = "wait", duration = 3000 },
                            
                            -- Camera destroy
                            { type = "camera", action = "destroy" }
                        }
                    }
                end
            }
        }
    }
})
```

### Example 3: Quest System with Dynamic Branching

```lua
exports['advance-dialog']:registerDialogs({
    quest_giver = {
        speaker = "Quest Master",
        text = "What would you like to do?",
        options = {
            {
                label = "Check Active Quests",
                task = function(ctx)
                    return {
                        sequence = {
                            { type = "run", fn = function(ctx)
                                -- Query quest status
                                ctx.hasQuest = exports['my-quest-system']:HasActiveQuest(PlayerId())
                                ctx.questStatus = exports['my-quest-system']:GetQuestProgress(PlayerId())
                            end},
                            
                            -- Branch based on quest status
                            { type = "run", fn = function(ctx)
                                if ctx.hasQuest then
                                    -- Show quest progress dialog
                                    local progress = math.floor((ctx.questStatus.current / ctx.questStatus.total) * 100)
                                    exports['advance-dialog']:showDialog({
                                        id = "quest_progress",
                                        text = string.format("Quest Progress: %d%%", progress),
                                        options = {{label = "Continue", close = true}}
                                    }, ctx.ped)
                                else
                                    -- Show available quests
                                    exports['advance-dialog']:showDialog({
                                        id = "quest_available",
                                        text = "You have no active quests. Take one?",
                                        options = {
                                            {label = "Yes", next = "quest_select"},
                                            {label = "No", close = true}
                                        }
                                    }, ctx.ped)
                                end
                            end}
                        }
                    }
                end
            }
        }
    }
})
```

## API Reference

### Client Exports

#### Dialog Management
```lua
exports['advance-dialog']:showDialog(dialogData, ped, isTransition)
exports['advance-dialog']:closeDialog()
exports['advance-dialog']:getDialogState()
exports['advance-dialog']:openDialogById(dialogId, ped)
exports['advance-dialog']:registerDialogs(dialogTable)
```

#### Ped Management
```lua
exports['advance-dialog']:setActivePed(ped)
exports['advance-dialog']:getActivePed()
exports['advance-dialog']:createPedAndOpen(dialogId, pedConfig)
exports['advance-dialog']:stopAnimations()
```

#### Task Actions
```lua
-- Register global action
exports['advance-dialog']:registerTaskAction(nil, name, handler)

-- Register dialog-specific action
exports['advance-dialog']:registerTaskAction(dialogId, name, handler)

-- Helper to open dialog after sequence
exports['advance-dialog']:openDialogAfterSequence(dialogId, ped, delay)
```

#### Animations
```lua
exports['advance-dialog']:playAnimation(ped, presetName, customDuration)
exports['advance-dialog']:playFacialAnimation(ped, presetName, customDuration)
exports['advance-dialog']:getPresetAnimations()
exports['advance-dialog']:getPresetFacials()
```

### Server Exports

```lua
exports['advance-dialog']:registerDialogs(dialogTable)
exports['advance-dialog']:getDialog(dialogId)
exports['advance-dialog']:getAllDialogs()
exports['advance-dialog']:clearDialogs()
exports['advance-dialog']:openDialogById(targetSource, dialogId, pedNetId)
```

### Events

```lua
-- Client Events
AddEventHandler('advance-dialog:open', function(ctx) end)
AddEventHandler('advance-dialog:close', function(ctx) end)
AddEventHandler('advance-dialog:optionSelected', function(ctx) end)
AddEventHandler('advance-dialog:requested', function(ctx) end)
AddEventHandler('advance-dialog:denied', function(ctx) end)
AddEventHandler('advance-dialog:animationStart', function(ctx) end)
AddEventHandler('advance-dialog:animationEnd', function(ctx) end)
```

## Configuration

```lua
Config = {
    -- UI Settings
    uiPage = 'nui/index.html',
    closeKey = 27,  -- Escape key
    
    -- Animation Settings
    defaultAnimDuration = 3000,
    enableDebug = false,
    
    -- Progress Provider
    -- Options: "ox_lib", "qb-progressbar", "mythic", "none"
    progressProvider = "none",
    
    -- Camera Settings
    cameraLerpFactor = 0.3,           -- 0.0-1.0 (smoothness)
    cameraOrbitDirection = "clockwise", -- "clockwise" or "counter"
    cameraAutoDestroy = true,         -- Auto destroy at sequence end
    
    -- Task Sequence Settings
    taskSequenceTimeout = 30000,      -- Max sequence duration (ms)
    
    -- Localization
    Locale = 'en',
    
    -- Animation Libraries to Preload
    animationLibrary = {
        "anim@amb@clubhouse@",
        "anim@mp_facial_tourist",
        "missmic2_credits_04",
        "anim@heists@heist_corona@single_team",
        "anim@scripted@payphone_hits@male@"
    }
}
```

---

**Version:** 1.1.0  
**Author:** JericoFX  
**License:** MIT
