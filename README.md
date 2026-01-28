# Advance Dialog - FiveM Dialog System

Minimal and flexible dialog system for FiveM with animations, access rules, metadata, and a task sequence system.

## Features

- Minimal NUI dialog UI
- Body and facial animations
- Dialog chains with branching
- Per-option callbacks
- Dialog and option metadata
- `canInteract` + denied hooks
- Task sequences with custom actions
- Progress providers (ox_lib, qb-progressbar, mythic, or NUI fallback)
- Ped creation helpers
- Client and server exports

## Install

1. Drop the folder into `resources/`
2. Add `ensure advance-dialog` to `server.cfg`
3. Restart the server

## Quick Start

### Register and open by id (client)

```lua
exports['advance-dialog']:registerDialogs({
    start = {
        speaker = "NPC",
        text = "Hello!",
        options = {
            { label = "Continue", next = "end" }
        }
    },
    end = {
        speaker = "NPC",
        text = "See you!",
        options = { { label = "Close", close = true } }
    }
})

exports['advance-dialog']:openDialogById("start")
```

### Register on server, open by id (server)

```lua
exports['advance-dialog']:registerDialogs({
    welcome = {
        speaker = "NPC",
        text = "Welcome!",
        options = { { label = "Close", close = true } }
    }
})

-- later
exports['advance-dialog']:openDialogById(source, "welcome", pedNetId)
```

### Direct open without registering

```lua
exports['advance-dialog']:showDialog({
    id = "hello_direct",
    speaker = "NPC",
    text = "Hello there!",
    options = { { label = "Close", close = true } }
}, PlayerPedId())
```

`showDialog` requires an `id` when opening dialogs directly.

## Dialog chaining (concatenate menus)

Use `options[].next` with `registerDialogs` and `openDialogById`.

```lua
local chain = {
    start = {
        speaker = "Guide",
        text = "Ready?",
        options = {
            { label = "Yes", next = "mid" },
            { label = "No", close = true }
        }
    },
    mid = {
        speaker = "Guide",
        text = "Almost there.",
        options = { { label = "Continue", next = "end" } }
    },
    end = {
        speaker = "Guide",
        text = "Done.",
        options = { { label = "Close", close = true } }
    }
}

exports['advance-dialog']:registerDialogs(chain)
exports['advance-dialog']:openDialogById("start")
```

If the next dialog is not in the client registry, the client requests it from the server automatically.

## Callbacks, tasks, metadata

### Callbacks

```lua
options = {
    {
        label = "Accept",
        callback = function(ctx)
            print("Option:", ctx.option.label)
            print("Dialog metadata:", ctx.metadata.someKey)
            print("Option metadata:", ctx.optionMetadata.someKey)
        end,
        close = true
    }
}
```

Metadata access:

- `ctx.metadata` = dialog metadata
- `ctx.optionMetadata` = option metadata
- `ctx.mergedMetadata` = merged (option overrides dialog)

### Tasks (sequence)

```lua
options = {
    {
        label = "Check engine",
        task = function(ctx)
            return {
                ped = ctx.ped,
                sequence = {
                    { type = "dialogClose" },
                    { type = "goTo", target = "vehicle", offset = { x = 0.0, y = 2.0, z = 0.0 }, arriveDistance = 1.5 },
                    { type = "playAnim", dict = "mini@repair", anim = "fixing_a_player", duration = 5000, blocking = false },
                    { type = "progress", label = "Checking engine...", duration = 5000 }
                }
            }
        end
    }
}
```

If a task returns a sequence, the dialog closes by default unless `keepDialog = true`.

## canInteract

Use `canInteract` to control if a dialog can open. It receives `(playerPed, ctx)` and must return boolean.

```lua
canInteract = function(playerPed, ctx)
    return IsPedOnFoot(playerPed)
end
```

When denied, `onDenied.callback` runs and `onDenied.task` can run a sequence.

```lua
onDenied = {
    callback = function(ctx)
        print("Denied:", ctx.reason)
    end,
    task = function(ctx)
        return {
            ped = ctx.ped,
            sequence = {
                { type = "dialogClose" },
                { type = "wander" }
            }
        }
    end
}
```

## Option fields

Each option supports:

- `label` (string)
- `description` (string)
- `icon` (string) - rendered as plain text (emoji or short text)
- `next` (dialog id)
- `close` (boolean)
- `callback(ctx)` (function)
- `task(ctx)` (function)
- `canInteract` (boolean or function)
- `metadata` (table)

If `canInteract` returns false, the option is disabled and will not trigger callbacks.
`canInteract` is evaluated when the dialog is shown and again on click.
All option functions run on the client.

## Play facial animations in options

Use the task sequence action `playFacial`:

```lua
task = function(ctx)
    return {
        ped = ctx.ped,
        sequence = {
            { type = "playFacial", facial = "mood_happy", dict = "facials@gen_male@variations@happy", duration = 2000 }
        }
    }
end
```

## Task system

### Built-in sequence actions

- `goTo` (coords or target = "vehicle")
- `playAnim`
- `playFacial`
- `wait`
- `progress`
- `dialogClose`
- `camera` (create / lookAt / destroy)
- `attack`, `follow`, `wander`, `scenario`

### Custom task actions

Register your own action once and reuse it in sequences:

```lua
exports['advance-dialog']:registerTaskAction('vehicleFix', function(ctx, action, ped)
    local vehicle = NetToVeh(ctx.metadata.vehicleNetId)
    if vehicle and DoesEntityExist(vehicle) then
        SetVehicleFixed(vehicle)
    end
end)
```

Then use it in a sequence:

```lua
sequence = {
    { type = "progress", label = "Fixing...", duration = 3000 },
    { type = "vehicleFix" }
}
```

Custom actions can be any `type` you register with `registerTaskAction`.

### Vehicle metadata

Actions that use `target = "vehicle"` or `target = "engine"` require `metadata.vehicleNetId`.
If it is missing, the dialog is denied with `reason = "missing_vehicle"`.

## Progress providers

Set in `config.lua`:

```lua
Config.progressProvider = "ox_lib"
```

Supported providers:

- `ox_lib`
- `qb-progressbar`
- `mythic`
- `none` (NUI fallback)

## Client exports

```lua
exports['advance-dialog']:showDialog(dialogData, ped)
exports['advance-dialog']:openDialogById(dialogId, ped)
exports['advance-dialog']:closeDialog()
exports['advance-dialog']:getDialogState()
exports['advance-dialog']:setActivePed(ped)
exports['advance-dialog']:getActivePed()
exports['advance-dialog']:createPedAndOpen(dialogId, pedConfig)
exports['advance-dialog']:registerTaskAction(name, handler)

exports['advance-dialog']:playAnimation(ped, 'WAVE')
exports['advance-dialog']:playFacialAnimation(ped, 'HAPPY')
exports['advance-dialog']:getPresetAnimations()
exports['advance-dialog']:getPresetFacials()
```

## Server exports

```lua
exports['advance-dialog']:registerDialogs(dialogTable)
exports['advance-dialog']:getDialog(dialogId)
exports['advance-dialog']:getAllDialogs()
exports['advance-dialog']:clearDialogs()
exports['advance-dialog']:openDialogById(source, dialogId, pedNetId)
```

## Events

```lua
AddEventHandler('advance-dialog:open', function(ctx) end)
AddEventHandler('advance-dialog:close', function(ctx) end)
AddEventHandler('advance-dialog:optionSelected', function(ctx) end)
AddEventHandler('advance-dialog:requested', function(ctx) end)
AddEventHandler('advance-dialog:denied', function(ctx) end)
AddEventHandler('advance-dialog:animationStart', function(ctx) end)
AddEventHandler('advance-dialog:animationEnd', function(ctx) end)
```

Event payload (`ctx`) includes:

```lua
{
    dialog = dialogData,
    dialogId = dialogData.id,
    option = optionData,
    ped = ped,
    playerPed = PlayerPedId(),
    metadata = dialogData.metadata or {},
    optionMetadata = optionData.metadata or {},
    mergedMetadata = { ... },
    reason = "canInteract" -- only for denied
}

Possible denied reasons:

- `canInteract` (dialog blocked)
- `option_canInteract` (option blocked)
- `missing_vehicle` (vehicleNetId missing)

Reason map:

- `canInteract`: dialog-level access failed
- `option_canInteract`: option-level access failed
- `missing_vehicle`: task action required `metadata.vehicleNetId`
```

## Types

```lua
Dialog = {
    id = string,
    speaker = string,
    text = string,
    animation = table,
    metadata = table,
    canInteract = function(playerPed, ctx) return boolean end,
    onDenied = {
        callback = function(ctx) end,
        task = function(ctx) return TaskResult end
    },
    options = { DialogOption }
}

DialogOption = {
    label = string,
    description = string,
    icon = string,
    next = string,
    close = boolean,
    callback = function(ctx) end,
    task = function(ctx) return TaskResult end,
    canInteract = boolean or function(playerPed, ctx) return boolean end,
    metadata = table
}

TaskResult = number or {
    ped = number,
    sequence = { TaskAction },
    keepDialog = boolean
}

TaskAction = {
    type = "goTo" | "playAnim" | "playFacial" | "wait" | "progress" | "dialogClose" | "camera" | "attack" | "follow" | "wander" | "scenario" | "<custom>",
    -- fields depend on type
}

EventPayload = {
    dialog = Dialog,
    dialogId = string,
    option = DialogOption,
    ped = number,
    playerPed = number,
    metadata = table,
    optionMetadata = table,
    mergedMetadata = table,
    reason = string
}
```

## Ped creation

```lua
local pedConfig = {
    model = "s_m_y_xmech_02",
    coords = { x = 123.0, y = 456.0, z = 78.0 },
    heading = 90.0,
    networked = true,
    freeze = true,
    invincible = true,
    armor = 100,
    relationship = { group = "MECHANIC" },
    scenario = "WORLD_HUMAN_CLIPBOARD",
    scenarioFlags = 0,
    anim = { dict = "mini@repair", name = "fixing_a_player" },
    appearance = {
        components = { { componentId = 3, drawableId = 1, textureId = 0, paletteId = 0 } },
        props = { { propId = 0, drawableId = 2, textureId = 0 } },
        faceFeatures = { { index = 0, scale = 0.2 } }
    },
    props = { { propId = 1, drawableId = -1 } },
    weapon = { name = "WEAPON_PISTOL", ammo = 60 }
}

exports['advance-dialog']:createPedAndOpen("dialog_id", pedConfig)
```

## Examples

Check `examples.lua` for more usage patterns.

### Example: Mechanic flow

```lua
exports['advance-dialog']:registerTaskAction('openHood', function(ctx)
    local vehicle = NetToVeh(ctx.mergedMetadata.vehicleNetId)
    if vehicle and DoesEntityExist(vehicle) then
        SetVehicleDoorOpen(vehicle, 4, false, false)
    end
end)

exports['advance-dialog']:registerTaskAction('closeHood', function(ctx)
    local vehicle = NetToVeh(ctx.mergedMetadata.vehicleNetId)
    if vehicle and DoesEntityExist(vehicle) then
        SetVehicleDoorShut(vehicle, 4, false)
    end
end)

local mechanicDialog = {
    id = "mechanic_intro",
    speaker = "Mechanic",
    text = "Need a quick check?",
    metadata = { vehicleNetId = VehToNet(GetVehiclePedIsIn(PlayerPedId(), false)) },
    options = {
        {
            label = "Check engine",
            icon = "wrench",
            task = function(ctx)
                return {
                    ped = ctx.ped,
                    sequence = {
                        { type = "dialogClose" },
                        { type = "openHood" },
                        { type = "playAnim", dict = "mini@repair", anim = "fixing_a_player", duration = 5000, blocking = false },
                        { type = "progress", label = "Checking engine...", duration = 5000 },
                        { type = "closeHood" }
                    }
                }
            end
        }
    }
}

exports['advance-dialog']:showDialog(mechanicDialog, PlayerPedId())
```

### Example: Full mechanic flow (camera + progress + custom actions)

```lua
exports['advance-dialog']:registerTaskAction('vehicleFix', function(ctx)
    local vehicle = NetToVeh(ctx.mergedMetadata.vehicleNetId)
    if vehicle and DoesEntityExist(vehicle) then
        SetVehicleFixed(vehicle)
        SetVehicleDeformationFixed(vehicle)
    end
end)

exports['advance-dialog']:registerTaskAction('openHood', function(ctx)
    local vehicle = NetToVeh(ctx.mergedMetadata.vehicleNetId)
    if vehicle and DoesEntityExist(vehicle) then
        SetVehicleDoorOpen(vehicle, 4, false, false)
    end
end)

exports['advance-dialog']:registerTaskAction('closeHood', function(ctx)
    local vehicle = NetToVeh(ctx.mergedMetadata.vehicleNetId)
    if vehicle and DoesEntityExist(vehicle) then
        SetVehicleDoorShut(vehicle, 4, false)
    end
end)

local fullMechanicDialog = {
    id = "mechanic_full",
    speaker = "Mechanic",
    text = "Full diagnostic?",
    metadata = { vehicleNetId = VehToNet(GetVehiclePedIsIn(PlayerPedId(), false)) },
    options = {
        {
            label = "Start",
            icon = "wrench",
            canInteract = function(playerPed, ctx)
                return IsPedInAnyVehicle(playerPed, false)
            end,
            task = function(ctx)
                return {
                    ped = ctx.ped,
                    sequence = {
                        { type = "dialogClose" },
                        { type = "goTo", target = "vehicle", offset = { x = 0.0, y = 2.0, z = 0.0 }, arriveDistance = 1.2 },
                        { type = "openHood" },
                        { type = "camera", action = "create", target = "engine", offset = { x = 0.0, y = 1.2, z = 0.6 }, fov = 45.0 },
                        { type = "camera", action = "lookAt", target = "engine" },
                        { type = "playAnim", dict = "mini@repair", anim = "fixing_a_player", duration = 6000, blocking = false },
                        { type = "progress", label = "Running diagnostics...", duration = 6000 },
                        { type = "vehicleFix" },
                        { type = "camera", action = "destroy" },
                        { type = "closeHood" }
                    }
                }
            end
        }
    }
}

exports['advance-dialog']:showDialog(fullMechanicDialog, PlayerPedId())
```

### Example: Police interaction

```lua
local policeDialog = {
    id = "police_intro",
    speaker = "Officer",
    text = "Do you have ID?",
    options = {
        {
            label = "Show ID",
            callback = function(ctx)
                TriggerEvent('chat:addMessage', { args = { "ID shown." } })
            end,
            close = true
        },
        {
            label = "Search vehicle",
            canInteract = function(playerPed)
                return IsPedInAnyVehicle(playerPed, false)
            end,
            callback = function(ctx)
                TriggerEvent('chat:addMessage', { args = { "Vehicle search started." } })
            end,
            close = true
        }
    }
}

exports['advance-dialog']:showDialog(policeDialog, PlayerPedId())
```
