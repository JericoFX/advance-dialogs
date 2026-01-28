-- Advance Dialog usage examples

-- 1) Basic dialog
local basicDialog = {
    id = "welcome_dialog",
    speaker = "NPC",
    text = "Welcome! How can I help you?",
    options = {
        {
            label = "Show rules",
            icon = "!",
            metadata = { action = "rules" },
            callback = function(ctx)
                if ctx.optionMetadata and ctx.optionMetadata.action then
                    print("Option metadata:", ctx.optionMetadata.action)
                end
                TriggerEvent('chat:addMessage', { args = { "Rules go here..." } })
            end,
            close = true
        },
        {
            label = "Close",
            close = true,
            canInteract = function(playerPed, ctx)
                return GetEntityHealth(playerPed) > 0
            end
        }
    }
}

-- 2) Dialog chain (register + open by id)
local dialogChain = {
    start = {
        speaker = "Guide",
        text = "Ready for an adventure?",
        options = {
            { label = "Yes", next = "quest_start" },
            { label = "No", close = true }
        }
    },
    quest_start = {
        speaker = "Guide",
        text = "Meet me by the docks.",
        options = {
            { label = "Got it", close = true }
        }
    }
}

-- 3) Conditional dialog with denied task
local conditionalDialog = {
    id = "vip_shop",
    speaker = "Vendor",
    text = "VIP items only.",
    canInteract = function(playerPed, ctx)
        return GetResourceKvpInt("player_vip") == 1
    end,
    onDenied = {
        callback = function(ctx)
            TriggerEvent('chat:addMessage', { args = { "You are not VIP." } })
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
    },
    options = {
        { label = "Close", close = true }
    }
}

-- 4) Custom task action (vehicle fix)
exports['advance-dialog']:registerTaskAction('vehicleFix', function(ctx, action, ped)
    local vehicle = NetToVeh(ctx.metadata.vehicleNetId)
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

-- 5) Dialog with task sequence (engine check)
local function openEngineCheckDialog(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then
        return
    end

    local dialog = {
        id = "engine_check",
        speaker = "Mechanic",
        text = "Want me to check the engine?",
        metadata = {
            vehicleNetId = VehToNet(vehicle)
        },
        options = {
            {
                label = "Check engine",
                icon = "wrench",
                task = function(ctx)
                    return {
                        ped = ctx.ped,
                        sequence = {
                            { type = "dialogClose" },
                            { type = "goTo", target = "vehicle", offset = { x = 0.0, y = 2.0, z = 0.0 }, speed = 1.0, arriveDistance = 1.5 },
                            { type = "openHood" },
                            { type = "playFacial", facial = "mood_happy", dict = "facials@gen_male@variations@happy", duration = 1500 },
                            { type = "playAnim", dict = "mini@repair", anim = "fixing_a_player", duration = 5000, blocking = false },
                            { type = "progress", label = "Checking engine...", duration = 5000 },
                            { type = "vehicleFix" },
                            { type = "closeHood" }
                        }
                    }
                end
            },
            { label = "No thanks", close = true }
        }
    }

    exports['advance-dialog']:showDialog(dialog, PlayerPedId())
end

-- 6) Create a ped and open dialog by id
local mechanicPedConfig = {
    model = "s_m_y_xmech_02",
    coords = { x = 815.0, y = -944.0, z = 25.0 },
    heading = 90.0,
    networked = true,
    freeze = true,
    invincible = true,
    scenario = "WORLD_HUMAN_CLIPBOARD"
}

-- 7) Police interaction dialog
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

-- 8) Full mechanic flow (camera + progress)
local function openFullMechanicDialog(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then
        return
    end

    local dialog = {
        id = "mechanic_full",
        speaker = "Mechanic",
        text = "Full diagnostic?",
        metadata = {
            vehicleNetId = VehToNet(vehicle)
        },
        options = {
            {
                label = "Start",
                icon = "wrench",
                canInteract = function(playerPed)
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

    exports['advance-dialog']:showDialog(dialog, PlayerPedId())
end

-- Register dialogs on spawn
AddEventHandler('playerSpawned', function()
    exports['advance-dialog']:registerDialogs(dialogChain)
    exports['advance-dialog']:registerDialogs({
        welcome_dialog = basicDialog,
        vip_shop = conditionalDialog
    })
end)

-- Example commands
RegisterCommand('testdialog', function()
    exports['advance-dialog']:showDialog(basicDialog, PlayerPedId())
end)

RegisterCommand('testchain', function()
    exports['advance-dialog']:openDialogById("start")
end)

RegisterCommand('testcreateped', function()
    exports['advance-dialog']:createPedAndOpen("welcome_dialog", mechanicPedConfig)
end)

RegisterCommand('testmechanic', function()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if vehicle and DoesEntityExist(vehicle) then
        openEngineCheckDialog(vehicle)
    else
        TriggerEvent('chat:addMessage', { args = { "Get in a vehicle first." } })
    end
end)

RegisterCommand('testpolice', function()
    exports['advance-dialog']:showDialog(policeDialog, PlayerPedId())
end)

RegisterCommand('testmechanicfull', function()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if vehicle and DoesEntityExist(vehicle) then
        openFullMechanicDialog(vehicle)
    else
        TriggerEvent('chat:addMessage', { args = { "Get in a vehicle first." } })
    end
end)
