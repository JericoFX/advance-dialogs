--[[
    Example: New OnSelect System V2

    This demonstrates the new simplified dialog system with:
    - registerDialog: Configure once
    - onSelect: Clean execution with TaskAPI
    - Automatic navigation with "back" action
    - Protected execution with error handling
]]

---@class ExampleVehicle
---@field engineHealth number
---@field bodyHealth number

-- ============================================
-- 1. REGISTER DIALOGS (at resource start)
-- ============================================

CreateThread(function()
    -- Wait for the dialog system to be ready
    while GetResourceState('advance-dialog') ~= 'started' do
        Wait(100)
    end

    -- Register main mechanic menu
    exports['advance-dialog']:registerDialog({
        id = "mechanic_menu",
        speaker = "Mechanic John",
        text = "Welcome to the shop. What do you need?",

        -- Static metadata (base configuration)
        metadata = {
            shopName = "Los Angeles Garage",
            basePrice = 500,
            maxDistance = 5.0
        },

        -- GLOBAL canInteract: evaluated when opening
        canInteract = function(ctx, targetPed)
            local playerPed = PlayerPedId()
            local dist = #(GetEntityCoords(playerPed) - GetEntityCoords(targetPed))
            return dist <= ctx.metadata.maxDistance
        end,

        -- Global error handler
        onError = function(ctx, error)
            print("Dialog error:", error)
            TriggerEvent('chat:addMessage', {
                args = { "[ERROR]", "Something went wrong, please try again." }
            })
        end,

        options = {
            {
                label = "Repair Engine",
                icon = "🔧",

                -- PER-OPTION canInteract
                canInteract = function(ctx)
                    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
                    return veh ~= 0 and GetVehicleEngineHealth(veh) < 1000
                end,

                -- NEW: onSelect - clean and direct
                onSelect = function(ctx, task)
                    -- Get vehicle dynamically
                    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
                    local price = ctx.metadata.basePrice

                    -- Close dialog
                    task.closeDialog()

                    -- Go to vehicle (with timeout and automatic slide)
                    local arrived = task.goTo(ctx.ped, veh, { x = 0, y = 2.5, z = 0 }, {
                        timeout = 10000, -- 10 seconds max
                        slide = true     -- Teleport if doesn't arrive
                    })

                    if not arrived then
                        print("Mechanic didn't arrive, using slide")
                    end

                    -- Open hood
                    SetVehicleDoorOpen(veh, 4, false, false)
                    task.wait(500)

                    -- Animation with EXACT duration
                    local animDict = "mini@repair"
                    local animName = "fixing_a_player"
                    local duration = task.getAnimDuration(animDict, animName) * 1000

                    task.playAnim(animDict, animName, duration)
                    task.progress("Repairing engine...", duration)

                    -- Repair
                    SetVehicleFixed(veh)
                    SetVehicleEngineHealth(veh, 1000.0)

                    -- Close hood
                    SetVehicleDoorShut(veh, 4, false)

                    -- Return to menu
                    task.showDialog("mechanic_menu")
                end
            },

            {
                label = "Full Service",
                icon = "🚗",

                canInteract = function(ctx)
                    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
                    return veh ~= 0
                end,

                onSelect = function(ctx, task)
                    local veh = GetVehiclePedIsIn(PlayerPedId(), false)

                    task.closeDialog()

                    -- Movement to vehicle
                    task.goTo(ctx.ped, veh, { x = 0, y = 3, z = 0 }, {
                        timeout = 10000,
                        slide = true
                    })

                    -- Open hood
                    SetVehicleDoorOpen(veh, 4, false, false)
                    task.wait(500)

                    -- Animation with progress
                    local dur = task.getAnimDuration("mini@repair", "fixing_a_player") * 1000
                    task.playAnim("mini@repair", "fixing_a_player", dur)
                    task.progress("Full service...", dur)

                    -- Repair everything
                    SetVehicleFixed(veh)
                    SetVehicleEngineHealth(veh, 1000.0)
                    SetVehicleBodyHealth(veh, 1000.0)
                    SetVehiclePetrolTankHealth(veh, 1000.0)

                    SetVehicleDoorShut(veh, 4, false)

                    -- Return
                    task.showDialog("mechanic_menu")
                end
            },

            {
                label = "View Services",
                next = "mechanic_services" -- Navigation to another menu
            },

            {
                label = "Exit",
                action = "close" -- Special action
            }
        }
    })

    -- Register sub-menu for services
    exports['advance-dialog']:registerDialog({
        id = "mechanic_services",
        speaker = "Mechanic John",
        text = "These are our services:",
        metadata = {
            maxDistance = 5.0
        },
        canInteract = function(ctx, targetPed)
            local playerPed = PlayerPedId()
            local dist = #(GetEntityCoords(playerPed) - GetEntityCoords(targetPed))
            return dist <= ctx.metadata.maxDistance
        end,

        options = {
            {
                label = "Oil Change - $200",
                onSelect = function(ctx, task)
                    -- Simple logic without going to vehicle
                    task.closeDialog()
                    task.progress("Changing oil...", 3000)
                    TriggerEvent('chat:addMessage', { args = { "Oil changed!" } })
                    task.showDialog("mechanic_services")
                end
            },
            {
                label = "General Inspection - $100",
                onSelect = function(ctx, task)
                    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
                    task.closeDialog()

                    task.goTo(ctx.ped, veh, { x = 0, y = 2, z = 0 }, { timeout = 8000, slide = true })
                    task.progress("Inspecting vehicle...", 4000)

                    local engineHealth = GetVehicleEngineHealth(veh)
                    local bodyHealth = GetVehicleBodyHealth(veh)

                    TriggerEvent('chat:addMessage', {
                        args = { "Vehicle Status:",
                            string.format("Engine: %.0f%% | Body: %.0f%%",
                                engineHealth / 10, bodyHealth / 10) }
                    })

                    task.showDialog("mechanic_services")
                end
            },
            {
                label = "← Back",
                action = "back" -- Automatically returns to previous menu
            }
        }
    })

    print("[Example] Dialogs registered successfully")
end)

-- ============================================
-- 2. CREATE PED AND SETUP INTERACTION
-- ============================================

CreateThread(function()
    Wait(2000) -- Wait for dialogs to register

    -- Create mechanic ped
    local mechanic = CreatePed(4,
        GetHashKey("s_m_y_xmech_02"),
        815.0, -944.0, 25.0,
        90.0,
        false, true
    )

    FreezeEntityPosition(mechanic, true)
    SetEntityInvincible(mechanic, true)

    -- Setup interaction using ox_target (or your preferred interaction system)
    if exports.ox_target then
        exports.ox_target:addLocalEntity(mechanic, {
            {
                label = "Talk to mechanic",
                icon = "fa-solid fa-wrench",
                onSelect = function()
                    -- OPEN DIALOG: Just specify entity + dialog ID
                    exports['advance-dialog']:openDialog(
                        mechanic,       -- The entity
                        "mechanic_menu" -- The dialog to open
                    )
                end
            }
        })
    end

    print("[Example] Mechanic created at (815, -944, 25)")
end)

-- ============================================
-- 3. COMPARISON: Old System vs New
-- ============================================

--[[
OLD SYSTEM (verbose):

exports['advance-dialog']:registerDialogs({
    mechanic = {
        speaker = "Mechanic",
        text = "What do you need?",
        options = {
            {
                label = "Repair",
                task = function(ctx)
                    return {
                        sequence = {
                            {type = "dialogClose"},
                            {type = "goTo", target = "vehicle", offset = {x=0, y=2, z=0}},
                            {type = "playAnim", dict = "mini@repair", anim = "fixing_a_player", duration = 5000},
                            {type = "progress", label = "Repairing...", duration = 5000}
                        }
                    }
                end
            }
        }
    }
})

NEW SYSTEM (clean):

exports['advance-dialog']:registerDialog({
    id = "mechanic_menu",
    speaker = "Mechanic",
    text = "What do you need?",
    options = {
        {
            label = "Repair",
            onSelect = function(ctx, task)
                task.closeDialog()
                task.goTo(ctx.ped, vehicle, {x=0, y=2, z=0}, {timeout=10000, slide=true})
                task.playAnim("mini@repair", "fixing_a_player", 5000)
                task.progress("Repairing...", 5000)
                SetVehicleFixed(vehicle)
                task.showDialog("mechanic_menu")
            end
        }
    }
})

KEY DIFFERENCES:
- No more complicated nested tables
- No more registerTaskAction for each action
- Linear and readable code
- TaskAPI with automatic protection
- Simple navigation with action = "back"
- Dynamic metadata at runtime
]]

-- ============================================
-- 4. USING NEW UTILITY HELPERS
-- ============================================

exports['advance-dialog']:registerDialog({
    id = "advanced_mechanic",
    speaker = "Mechanic",
    text = "Advanced repair options:",
    metadata = {
        maxDistance = 10.0
    },
    options = {
        {
            label = "Open Hood and Inspect",
            onSelect = function(ctx, task)
                -- Use helpers to find closest vehicle
                local veh = task.vehicle.getClosest(10.0)
                if not veh then
                    TriggerEvent('chat:addMessage', {args = {"No vehicle nearby!"}})
                    task.showDialog("advanced_mechanic")
                    return
                end
                
                task.closeDialog()
                
                -- Go to hood (bonnet) bone with offset
                task.goToVehicle(ctx.ped, veh, "bonnet", {x=0, y=1.5, z=0}, {
                    timeout = 8000,
                    slide = true
                })
                
                -- Open hood
                SetVehicleDoorOpen(veh, 4, false, false)
                
                -- Facial expression while working
                task.playFacial("concentrated", 3000)
                
                -- Progress while inspecting
                task.progress("Inspecting engine...", 3000)
                
                -- Get damage info
                local engineHealth = GetVehicleEngineHealth(veh)
                
                TriggerEvent('chat:addMessage', {
                    args = {"Inspection result:", string.format("Engine health: %.0f%%", engineHealth/10)}
                })
                
                task.showDialog("advanced_mechanic")
            end
        },
        {
            label = "Find Specific Vehicle",
            onSelect = function(ctx, task)
                -- Search for specific model
                local vehicles = task.search.vehiclesByModel("adder", 100.0)
                
                if #vehicles > 0 then
                    TriggerEvent('chat:addMessage', {
                        args = {"Found", tostring(#vehicles) .. " Adder(s) nearby"}
                    })
                    
                    -- Go to first one
                    task.closeDialog()
                    task.goToVehicle(ctx.ped, vehicles[1], nil, {x=0, y=2, z=0}, {
                        timeout = 10000,
                        slide = true
                    })
                    task.camera.lookAtVehicle(vehicles[1])
                else
                    TriggerEvent('chat:addMessage', {args = {"No Adder found nearby"}})
                end
                
                task.showDialog("advanced_mechanic")
            end
        },
        {
            label = "Find Vehicle by Plate",
            onSelect = function(ctx, task)
                -- Find vehicle by license plate
                local veh = task.vehicle.getByPlate("ABC 123")
                
                if veh then
                    TriggerEvent('chat:addMessage', {args = {"Found vehicle with plate ABC 123"}})
                    
                    task.closeDialog()
                    task.goToVehicle(ctx.ped, veh, "boot", {x=0, y=1.5, z=0})
                else
                    TriggerEvent('chat:addMessage', {args = {"Vehicle not found"}})
                end
                
                task.showDialog("advanced_mechanic")
            end
        },
        {
            label = "Check Player Status",
            onSelect = function(ctx, task)
                -- Use player helpers
                local inVehicle = task.player.isInVehicle()
                local onFoot = task.player.isOnFoot()
                local playerVeh = task.player.getVehicle()
                
                if playerVeh then
                    local dist = task.player.getDistanceTo(playerVeh)
                    TriggerEvent('chat:addMessage', {
                        args = {"Player status:", string.format("In vehicle: %s | Distance to own vehicle: %.1fm", 
                            tostring(inVehicle), dist)}
                    })
                else
                    TriggerEvent('chat:addMessage', {
                        args = {"Player status:", string.format("In vehicle: %s | On foot: %s", 
                            tostring(inVehicle), tostring(onFoot))}
                    })
                end
                
                task.showDialog("advanced_mechanic")
            end
        },
        {
            label = "← Back",
            action = "back"
        }
    }
})

-- ============================================
-- 5. DATA PERSISTENCE EXAMPLES
-- ============================================

-- Example: Quest System with Progress Saving
exports['advance-dialog']:registerDialog({
    id = "quest_giver",
    speaker = "Quest Giver",
    text = "I have a task for you.",
    options = {
        {
            label = "Check Quest Status",
            onSelect = function(ctx, task)
                -- Check if player has already started/completed this quest
                task.data.isCompleted("main_quest_1", function(completed)
                    if completed then
                        TriggerEvent('chat:addMessage', {
                            args = {"Quest:", "You have already completed this quest!"}
                        })
                    else
                        -- Get current progress
                        local progress = task.data.getSync("quest_1_progress", 0)
                        TriggerEvent('chat:addMessage', {
                            args = {"Quest:", string.format("Current progress: %d/5", progress)}
                        })
                    end
                    
                    task.showDialog("quest_giver")
                end)
            end
        },
        {
            label = "Advance Quest",
            onSelect = function(ctx, task)
                -- Get current progress
                local progress = task.data.getSync("quest_1_progress", 0)
                
                if progress >= 5 then
                    -- Quest complete!
                    task.data.markCompleted("main_quest_1")
                    TriggerEvent('chat:addMessage', {
                        args = {"Quest:", "Quest completed! Reward granted."}
                    })
                else
                    -- Advance progress
                    progress = progress + 1
                    task.data.set("quest_1_progress", progress, function(success)
                        if success then
                            TriggerEvent('chat:addMessage', {
                                args = {"Quest:", string.format("Progress updated: %d/5", progress)}
                            })
                        end
                    end)
                end
                
                task.showDialog("quest_giver")
            end
        },
        {
            label = "Reset Quest (Debug)",
            onSelect = function(ctx, task)
                -- Clear specific quest data
                task.data.remove("quest_1_progress")
                task.data.remove("dialog_completed_main_quest_1")
                
                TriggerEvent('chat:addMessage', {
                    args = {"Quest:", "Quest progress reset!"}
                })
                
                task.showDialog("quest_giver")
            end
        },
        {
            label = "Exit",
            action = "close"
        }
    }
})

-- Example: NPC Reputation System
exports['advance-dialog']:registerDialog({
    id = "npc_reputation",
    speaker = "Shop Owner",
    text = "Welcome back!",
    canInteract = function(ctx)
        -- Check reputation to show different dialog
        return true
    end,
    onSelect = function(ctx, task)
        -- Get reputation (0-100)
        local rep = task.data.getSync("rep_shop_owner", 50)
        
        if rep >= 80 then
            ctx.dialog.text = "Welcome back, my friend! You get VIP discount today!"
        elseif rep >= 50 then
            ctx.dialog.text = "Welcome! Good to see you again."
        else
            ctx.dialog.text = "...What do you want?"
        end
        
        task.showDialog("npc_reputation")
    end,
    options = {
        {
            label = "Gain Reputation",
            onSelect = function(ctx, task)
                local rep = task.data.getSync("rep_shop_owner", 50)
                rep = math.min(100, rep + 10)
                
                task.data.set("rep_shop_owner", rep)
                TriggerEvent('chat:addMessage', {
                    args = {"Reputation:", string.format("Shop owner reputation: %d/100", rep)}
                })
                
                task.showDialog("npc_reputation")
            end
        },
        {
            label = "Lose Reputation",
            onSelect = function(ctx, task)
                local rep = task.data.getSync("rep_shop_owner", 50)
                rep = math.max(0, rep - 10)
                
                task.data.set("rep_shop_owner", rep)
                TriggerEvent('chat:addMessage', {
                    args = {"Reputation:", string.format("Shop owner reputation: %d/100", rep)}
                })
                
                task.showDialog("npc_reputation")
            end
        },
        {
            label = "Exit",
            action = "close"
        }
    }
})