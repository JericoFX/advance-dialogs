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
    metadata = {playerId = 12345},
    options = {
        {
            label = "Show ID",
            callback = function(ctx)
                TriggerEvent('chat:addMessage', { args = { "ID shown: " .. ctx.optionMetadata.playerId } })
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

-- ============================================
-- NEW EXAMPLES - Advanced Features
-- ============================================

-- Dynamic Camera System Examples

--[[
    Example: Dynamic Follow Camera
    Camera smoothly follows the ped as they move
]]
RegisterCommand('testcamera_follow', function()
    local dialog = {
        id = "camera_follow_demo",
        speaker = "Camera Operator",
        text = "Let's test the follow camera mode!",
        options = {
            {
                label = "Start Demo",
                task = function(ctx)
                    return {
                        sequence = {
                            -- Close dialog
                            { type = "dialogClose" },
                            
                            -- Create follow camera
                            { 
                                type = "camera", 
                                action = "create", 
                                mode = "follow",
                                target = "ped",
                                offset = {x=2.0, y=-2.0, z=1.5},
                                fov = 45,
                                lerp = true
                            },
                            
                            -- Walk around
                            { type = "goTo", coords = {x=820, y=-940, z=25}, speed = 1.0, waitForArrival = true },
                            { type = "wait", duration = 1000 },
                            { type = "goTo", coords = {x=825, y=-935, z=25}, speed = 1.0, waitForArrival = true },
                            { type = "wait", duration = 1000 },
                            
                            -- Destroy camera
                            { type = "camera", action = "destroy" }
                        }
                    }
                end
            }
        }
    }
    
    exports['advance-dialog']:showDialog(dialog, PlayerPedId())
end)

--[[
    Example: Orbit Camera
    Camera rotates around the player
]]
RegisterCommand('testcamera_orbit', function()
    local dialog = {
        id = "camera_orbit_demo",
        speaker = "Photographer",
        text = "Let me take some shots of you!",
        options = {
            {
                label = "Start Photo Shoot",
                task = function(ctx)
                    return {
                        sequence = {
                            { type = "dialogClose" },
                            
                            -- Create orbit camera
                            { 
                                type = "camera", 
                                action = "create", 
                                mode = "orbit",
                                target = "player",
                                radius = 3.0,
                                height = 0.5,
                                speed = 1.0,
                                fov = 50
                            },
                            
                            -- Pose for camera
                            { type = "playAnim", dict = "mp_player_int_upperpeace_sign", anim = "mp_player_int_peace_sign", duration = 8000 },
                            
                            -- Camera auto-destroys at sequence end
                        }
                    }
                end
            }
        }
    }
    
    exports['advance-dialog']:showDialog(dialog, PlayerPedId())
end)

--[[
    Example: Track Camera
    Camera stays fixed but tracks the player
]]
RegisterCommand('testcamera_track', function()
    local dialog = {
        id = "camera_track_demo",
        speaker = "Security Guard",
        text = "Please step into the inspection area.",
        options = {
            {
                label = "Proceed",
                task = function(ctx)
                    return {
                        sequence = {
                            { type = "dialogClose" },
                            
                            -- Create track camera at guard position
                            { 
                                type = "camera", 
                                action = "create", 
                                mode = "track",
                                coords = {x=815, y=-944, z=26},
                                target = "player",
                                fov = 40
                            },
                            
                            -- Player walks around
                            { type = "wait", duration = 2000 },
                            
                            -- Destroy camera
                            { type = "camera", action = "destroy" }
                        }
                    }
                end
            }
        }
    }
    
    exports['advance-dialog']:showDialog(dialog, PlayerPedId())
end)

--[[
    Example: Context Mutable Data
    Shows how to share data between actions
]]
RegisterCommand('testcontext', function()
    local dialog = {
        id = "context_demo",
        speaker = "Data Scientist",
        text = "Let me demonstrate context sharing!",
        options = {
            {
                label = "Run Demo",
                task = function(ctx)
                    return {
                        sequence = {
                            -- Store data in context
                            { type = "run", fn = function(ctx)
                                ctx.demoData = {
                                    timestamp = GetGameTimer(),
                                    playerName = GetPlayerName(PlayerId()),
                                    randomValue = math.random(1, 100)
                                }
                                print("[Action 1] Stored data in context")
                            end},
                            
                            -- Access stored data
                            { type = "run", fn = function(ctx)
                                print("[Action 2] Retrieved from context:")
                                print("  Player: " .. ctx.demoData.playerName)
                                print("  Random Value: " .. ctx.demoData.randomValue)
                            end},
                            
                            -- Modify data
                            { type = "run", fn = function(ctx)
                                ctx.demoData.modified = true
                                ctx.demoData.randomValue = ctx.demoData.randomValue * 2
                                print("[Action 3] Modified data")
                            end},
                            
                            -- Access modified data
                            { type = "run", fn = function(ctx)
                                print("[Action 4] Final value: " .. ctx.demoData.randomValue)
                                print("[Action 4] Was modified: " .. tostring(ctx.demoData.modified))
                            end}
                        }
                    }
                end
            }
        }
    }
    
    exports['advance-dialog']:showDialog(dialog, PlayerPedId())
end)

--[[
    Example: Dynamic Properties with Functions
    Shows how to use functions for dynamic values
]]
RegisterCommand('testdynamic', function()
    local dialog = {
        id = "dynamic_props_demo",
        speaker = "Dynamic Tester",
        text = "Testing dynamic properties!",
        options = {
            {
                label = "Run Test",
                task = function(ctx)
                    return {
                        sequence = {
                            -- Set initial data
                            { type = "run", fn = function(ctx)
                                ctx.testValues = {
                                    duration = 3000,
                                    label = "Dynamic Progress",
                                    coords = {x=815, y=-944, z=26}
                                }
                            end},
                            
                            -- Use dynamic values
                            { 
                                type = "progress",
                                label = function(ctx) return ctx.testValues.label end,
                                duration = function(ctx) return ctx.testValues.duration end
                            },
                            
                            -- Change values
                            { type = "run", fn = function(ctx)
                                ctx.testValues.duration = 5000
                                ctx.testValues.label = "Updated Progress!"
                            end},
                            
                            -- Use updated values
                            {
                                type = "progress",
                                label = function(ctx) return ctx.testValues.label end,
                                duration = function(ctx) return ctx.testValues.duration end
                            }
                        }
                    }
                end
            }
        }
    }
    
    exports['advance-dialog']:showDialog(dialog, PlayerPedId())
end)

--[[
    Example: Dialog-Specific Actions
    Shows global vs dialog-specific action registration
]]
RegisterCommand('testactions', function()
    -- Register a GLOBAL action (available everywhere)
    exports['advance-dialog']:registerTaskAction(nil, 'globalTest', function(ctx, action, ped)
        print("[GLOBAL ACTION] Executed!")
        TriggerEvent('chat:addMessage', { args = { "Global action executed!" } })
    end)
    
    -- Register a DIALOG-SPECIFIC action
    exports['advance-dialog']:registerTaskAction('action_test_dialog', 'specificTest', function(ctx, action, ped)
        print("[DIALOG-SPECIFIC ACTION] Executed!")
        TriggerEvent('chat:addMessage', { args = { "Dialog-specific action executed!" } })
    end)
    
    local dialog = {
        id = "action_test_dialog",
        speaker = "Action Tester",
        text = "Testing action registration!",
        options = {
            {
                label = "Run Global Action",
                task = function(ctx)
                    return {
                        sequence = {
                            { type = "globalTest" }
                        }
                    }
                end
            },
            {
                label = "Run Specific Action",
                task = function(ctx)
                    return {
                        sequence = {
                            { type = "specificTest" }
                        }
                    }
                end
            }
        }
    }
    
    exports['advance-dialog']:showDialog(dialog, PlayerPedId())
end)

--[[
    Example: Complete Mechanic with Everything
    Shows full integration of all features
]]
RegisterCommand('testfullmechanic', function()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if not vehicle or not DoesEntityExist(vehicle) then
        TriggerEvent('chat:addMessage', { args = { "Get in a vehicle first!" } })
        return
    end
    
    -- Register actions
    exports['advance-dialog']:registerTaskAction(nil, 'advancedRepair', function(ctx, action, ped)
        local vehicle = NetToVeh(ctx.mergedMetadata.vehicleNetId)
        if vehicle then
            SetVehicleFixed(vehicle)
            SetVehicleEngineHealth(vehicle, 1000.0)
            SetVehicleBodyHealth(vehicle, 1000.0)
            SetVehiclePetrolTankHealth(vehicle, 1000.0)
            ctx.repairComplete = true
        end
    end)
    
    local dialog = {
        id = "full_mechanic_demo",
        speaker = "Master Mechanic",
        text = "I'll perform a complete restoration with dynamic camera tracking!",
        metadata = { vehicleNetId = VehToNet(vehicle) },
        options = {
            {
                label = "Full Restoration ($1000)",
                task = function(ctx)
                    return {
                        sequence = {
                            -- 1. Setup
                            { type = "dialogClose" },
                            
                            -- 2. Detect damage
                            { type = "run", fn = function(ctx)
                                local veh = NetToVeh(ctx.mergedMetadata.vehicleNetId)
                                ctx.initialHealth = {
                                    engine = GetVehicleEngineHealth(veh),
                                    body = GetVehicleBodyHealth(veh)
                                }
                                ctx.needsFullRestore = ctx.initialHealth.engine < 1000 or ctx.initialHealth.body < 1000
                            end},
                            
                            -- 3. Follow camera as mechanic approaches
                            { 
                                type = "camera", 
                                action = "create", 
                                mode = "follow",
                                target = "ped",
                                offset = {x=2.5, y=-2.0, z=1.2},
                                fov = 45,
                                lerp = true
                            },
                            
                            -- 4. Approach vehicle
                            { type = "goTo", target = "vehicle", offset = {x=0, y=3, z=0}, arriveDistance = 1.5 },
                            
                            -- 5. Switch to orbit camera for inspection
                            { 
                                type = "camera", 
                                action = "create", 
                                mode = "orbit",
                                target = "vehicle",
                                radius = 4.0,
                                height = 1.0,
                                speed = 1.0,
                                fov = 55
                            },
                            
                            -- 6. Inspect
                            { type = "playAnim", dict = "mini@repair", anim = "fixing_a_player", duration = 5000, blocking = false },
                            { type = "wait", duration = 5000 },
                            
                            -- 7. Open hood and focus camera on engine
                            { type = "run", fn = function(ctx)
                                local veh = NetToVeh(ctx.mergedMetadata.vehicleNetId)
                                SetVehicleDoorOpen(veh, 4, false, false)
                            end},
                            
                            { 
                                type = "camera", 
                                action = "create", 
                                mode = "track",
                                target = "vehicle",
                                bone = "engine",
                                coords = function(ctx)
                                    local veh = NetToVeh(ctx.mergedMetadata.vehicleNetId)
                                    local pos = GetEntityCoords(veh)
                                    return {x=pos.x + 1.5, y=pos.y, z=pos.z + 0.8}
                                end,
                                fov = 40
                            },
                            
                            -- 8. Repair with progress
                            { type = "playAnim", dict = "mini@repair", anim = "fixing_a_player", duration = 8000, blocking = false },
                            { 
                                type = "progress", 
                                label = function(ctx)
                                    return ctx.needsFullRestore and "Full Restoration..." or "Touch-up..."
                                end,
                                duration = function(ctx)
                                    return ctx.needsFullRestore and 8000 or 4000
                                end
                            },
                            
                            -- 9. Execute repair
                            { type = "advancedRepair" },
                            
                            -- 10. Close hood
                            { type = "run", fn = function(ctx)
                                local veh = NetToVeh(ctx.mergedMetadata.vehicleNetId)
                                SetVehicleDoorShut(veh, 4, false)
                            end},
                            
                            -- 11. Final orbit showcase
                            { 
                                type = "camera", 
                                action = "create", 
                                mode = "orbit",
                                target = "vehicle",
                                radius = 3.5,
                                height = 0.8,
                                speed = 1.5,
                                fov = 60
                            },
                            
                            { type = "wait", duration = 4000 },
                            
                            -- 12. Cleanup and return
                            { type = "camera", action = "destroy" },
                            { type = "goTo", target = "player", offset = {x=0, y=1.5, z=0}, arriveDistance = 1.5 },
                            
                            -- 13. Report success
                            { type = "run", fn = function(ctx)
                                if ctx.repairComplete then
                                    TriggerEvent('chat:addMessage', { args = { "Vehicle fully restored!" } })
                                end
                            end}
                        },
                        keepDialog = false
                    }
                end
            }
        }
    }
    
    exports['advance-dialog']:showDialog(dialog, PlayerPedId())
end)

--[[
    Example: Complete Mechanic with Everything
    Shows full integration of all features
]]
RegisterCommand('testfullmechanic', function()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if not vehicle or not DoesEntityExist(vehicle) then
        TriggerEvent('chat:addMessage', { args = { "Get in a vehicle first!" } })
        return
    end
    
    -- Register actions
    exports['advance-dialog']:registerTaskAction(nil, 'advancedRepair', function(ctx, action, ped)
        local vehicle = NetToVeh(ctx.mergedMetadata.vehicleNetId)
        if vehicle then
            SetVehicleFixed(vehicle)
            SetVehicleEngineHealth(vehicle, 1000.0)
            SetVehicleBodyHealth(vehicle, 1000.0)
            SetVehiclePetrolTankHealth(vehicle, 1000.0)
            ctx.repairComplete = true
        end
    end)
    
    local dialog = {
        id = "full_mechanic_demo",
        speaker = "Master Mechanic",
        text = "I'll perform a complete restoration with dynamic camera tracking!",
        metadata = { vehicleNetId = VehToNet(vehicle) },
        options = {
            {
                label = "Full Restoration ($1000)",
                task = function(ctx)
                    return {
                        sequence = {
                            -- 1. Setup
                            { type = "dialogClose" },
                            
                            -- 2. Detect damage
                            { type = "run", fn = function(ctx)
                                local veh = NetToVeh(ctx.mergedMetadata.vehicleNetId)
                                ctx.initialHealth = {
                                    engine = GetVehicleEngineHealth(veh),
                                    body = GetVehicleBodyHealth(veh)
                                }
                                ctx.needsFullRestore = ctx.initialHealth.engine < 1000 or ctx.initialHealth.body < 1000
                            end},
                            
                            -- 3. Follow camera as mechanic approaches
                            { 
                                type = "camera", 
                                action = "create", 
                                mode = "follow",
                                target = "ped",
                                offset = {x=2.5, y=-2.0, z=1.2},
                                fov = 45,
                                lerp = true
                            },
                            
                            -- 4. Approach vehicle
                            { type = "goTo", target = "vehicle", offset = {x=0, y=3, z=0}, arriveDistance = 1.5 },
                            
                            -- 5. Switch to orbit camera for inspection
                            { 
                                type = "camera", 
                                action = "create", 
                                mode = "orbit",
                                target = "vehicle",
                                radius = 4.0,
                                height = 1.0,
                                speed = 1.0,
                                fov = 55
                            },
                            
                            -- 6. Inspect
                            { type = "playAnim", dict = "mini@repair", anim = "fixing_a_player", duration = 5000, blocking = false },
                            { type = "wait", duration = 5000 },
                            
                            -- 7. Open hood and focus camera on engine
                            { type = "run", fn = function(ctx)
                                local veh = NetToVeh(ctx.mergedMetadata.vehicleNetId)
                                SetVehicleDoorOpen(veh, 4, false, false)
                            end},
                            
                            { 
                                type = "camera", 
                                action = "create", 
                                mode = "track",
                                target = "vehicle",
                                bone = "engine",
                                coords = function(ctx)
                                    local veh = NetToVeh(ctx.mergedMetadata.vehicleNetId)
                                    local pos = GetEntityCoords(veh)
                                    return {x=pos.x + 1.5, y=pos.y, z=pos.z + 0.8}
                                end,
                                fov = 40
                            },
                            
                            -- 8. Repair with progress
                            { type = "playAnim", dict = "mini@repair", anim = "fixing_a_player", duration = 8000, blocking = false },
                            { 
                                type = "progress", 
                                label = function(ctx)
                                    return ctx.needsFullRestore and "Full Restoration..." or "Touch-up..."
                                end,
                                duration = function(ctx)
                                    return ctx.needsFullRestore and 8000 or 4000
                                end
                            },
                            
                            -- 9. Execute repair
                            { type = "advancedRepair" },
                            
                            -- 10. Close hood
                            { type = "run", fn = function(ctx)
                                local veh = NetToVeh(ctx.mergedMetadata.vehicleNetId)
                                SetVehicleDoorShut(veh, 4, false)
                            end},
                            
                            -- 11. Final orbit showcase
                            { 
                                type = "camera", 
                                action = "create", 
                                mode = "orbit",
                                target = "vehicle",
                                radius = 3.5,
                                height = 0.8,
                                speed = 1.5,
                                fov = 60
                            },
                            
                            { type = "wait", duration = 4000 },
                            
                            -- 12. Cleanup and return
                            { type = "camera", action = "destroy" },
                            { type = "goTo", target = "player", offset = {x=0, y=1.5, z=0}, arriveDistance = 1.5 },
                            
                            -- 13. Report success
                            { type = "run", fn = function(ctx)
                                if ctx.repairComplete then
                                    TriggerEvent('chat:addMessage', { args = { "Vehicle fully restored!" } })
                                end
                            end}
                        },
                        keepDialog = false
                    }
                end
            }
        }
    }
    
    exports['advance-dialog']:showDialog(dialog, PlayerPedId())
end)

-- ============================================
-- HELP COMMAND
-- ============================================
RegisterCommand('dialoghelp', function()
    local helpText = {
        "=== ADVANCE DIALOG COMMANDS ===",
        "",
        "Basic Commands:",
        "  /testdialog - Basic dialog example",
        "  /testchain - Dialog chaining example", 
        "  /testcreateped - Create ped with dialog",
        "  /testmechanic - Simple mechanic flow",
        "  /testmechanicfull - Full mechanic with camera",
        "",
        "Camera Commands:",
        "  /testcamera_follow - Follow camera mode",
        "  /testcamera_orbit - Orbit camera mode",
        "  /testcamera_track - Track camera mode",
        "",
        "Advanced Commands:",
        "  /testcontext - Context sharing demo",
        "  /testdynamic - Dynamic properties demo",
        "  /testactions - Action registration demo",
        "  /testfullmechanic - Complete integration demo",
        "",
        "Configuration:",
        "  Edit config.lua to customize:",
        "  - Camera lerp factor",
        "  - Orbit direction", 
        "  - Auto-destroy settings",
        "  - Progress bar provider"
    }
    
    for _, line in ipairs(helpText) do
        TriggerEvent('chat:addMessage', { args = { line } })
    end
end)
