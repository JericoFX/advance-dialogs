--[[
    Task System Module
    
    Provides task sequence execution with:
    - Dual action registration system (global and dialog-specific)
    - Dynamic value resolution (functions or static values)
    - Mutable context sharing between actions
    - Support for custom actions via registerTaskAction
    - Built-in actions: dialogClose, wait, progress, camera, goTo, playAnim, etc.
    
    Features:
    - Global actions available in all dialogs
    - Dialog-specific actions override global ones
    - resolveValue() allows dynamic properties based on context
    - "run" action for executing custom logic
    - Camera auto-destruction on sequence completion
    - Comprehensive error handling and logging
]]

-- Task actions registry with dual system:
-- global: available in all dialogs
-- byDialog: specific to certain dialogs (indexed by dialogId)
local taskActions = {
    global = {},
    byDialog = {}
}

-- ============================================
-- REGISTRATION SYSTEM
-- ============================================

--[[
    Register a custom task action
    
    @param dialogId: string|nil - Dialog ID for specific action, or nil for global
    @param name: string - Action type name (used in sequence)
    @param handler: function(ctx, action, ped) - Handler function
    
    Usage:
    -- Global action (available in all dialogs)
    registerTaskAction(nil, 'repairVehicle', function(ctx, action, ped)
        local vehicle = NetToVeh(ctx.mergedMetadata.vehicleNetId)
        SetVehicleFixed(vehicle)
    end)
    
    -- Dialog-specific action (only available in dialog "mechanic")
    registerTaskAction('mechanic', 'specialRepair', function(ctx, action, ped)
        -- Only works in mechanic dialog
    end)
]]
function registerTaskAction(dialogId, name, handler)
    if type(name) ~= "string" or name == "" then
        return false, "Invalid action name"
    end
    
    if type(handler) ~= "function" then
        return false, "Invalid action handler"
    end
    
    if dialogId == nil then
        -- Global action
        taskActions.global[name] = handler
        
        if Config.enableDebug then
            print(string.format('[%s] Registered global task action: %s', GetCurrentResourceName(), name))
        end
    else
        -- Dialog-specific action
        if not taskActions.byDialog[dialogId] then
            taskActions.byDialog[dialogId] = {}
        end
        taskActions.byDialog[dialogId][name] = handler
        
        if Config.enableDebug then
            print(string.format('[%s] Registered task action for dialog "%s": %s', 
                GetCurrentResourceName(), dialogId, name))
        end
    end
    
    return true
end

--[[
    Get task action handler
    
    Resolution order:
    1. Look for dialog-specific action
    2. If not found, look for global action
    3. If not found, return nil
    
    @param actionType: string - Action type name
    @param dialogId: string|nil - Current dialog ID
    @return: Handler function or nil
]]
local function getTaskAction(actionType, dialogId)
    -- First, check for dialog-specific action
    if dialogId and taskActions.byDialog[dialogId] and taskActions.byDialog[dialogId][actionType] then
        return taskActions.byDialog[dialogId][actionType]
    end
    
    -- Then, check for global action
    if taskActions.global[actionType] then
        return taskActions.global[actionType]
    end
    
    -- Not found
    return nil
end

-- ============================================
-- VALUE RESOLUTION SYSTEM
-- ============================================

--[[
    Resolve a value that may be either static or a function
    
    If value is a function, it will be called with ctx and the result returned.
    If value is not a function, it will be returned as-is.
    
    This allows dynamic properties in task actions:
    
    Static value:
    { type = "goTo", target = "vehicle", offset = {x=0, y=2, z=0} }
    
    Dynamic value (function):
    { 
        type = "goTo", 
        target = "vehicle", 
        offset = function(ctx) 
            return ctx.targetOffset or {x=0, y=2, z=0} 
        end 
    }
    
    @param value: any - Value or function(ctx)
    @param ctx: table - Context object
    @return: Resolved value
]]
function resolveValue(value, ctx)
    if type(value) == "function" then
        local success, result = pcall(value, ctx)
        if not success then
            print(string.format('[%s] Error resolving value: %s', GetCurrentResourceName(), tostring(result)))
            return nil
        end
        return result
    end
    return value
end

-- ============================================
-- PROGRESS BAR SYSTEM
-- ============================================

local function startProgressBar(action)
    local duration = resolveValue(action.duration, action.ctx) or 0
    local label = resolveValue(action.label, action.ctx) or "Working..."
    
    if duration <= 0 then
        return false, 0
    end
    
    local provider = string.lower(Config.progressProvider or "none")
    local handled = false
    
    if provider == "ox_lib" and isResourceStarted("ox_lib") then
        local ok = pcall(function()
            if exports.ox_lib and exports.ox_lib.progressBar then
                exports.ox_lib:progressBar({
                    duration = duration,
                    label = label,
                    useWhileDead = true,
                    canCancel = false,
                    disable = { move = true, car = true, combat = true }
                })
            elseif lib and lib.progressBar then
                lib.progressBar({
                    duration = duration,
                    label = label,
                    useWhileDead = true,
                    canCancel = false,
                    disable = { move = true, car = true, combat = true }
                })
            end
        end)
        handled = ok
    elseif provider == "qb-progressbar" and isResourceStarted("qb-progressbar") then
        local ok = pcall(function()
            exports['qb-progressbar']:Progress({
                name = action.name or GetCurrentResourceName(),
                duration = duration,
                label = label,
                useWhileDead = true,
                canCancel = false,
                controlDisables = {
                    disableMovement = true,
                    disableCarMovement = true,
                    disableMouse = false,
                    disableCombat = true
                }
            }, function() end)
        end)
        handled = ok
    elseif provider == "mythic" and isResourceStarted("mythic_progbar") then
        local ok = pcall(function()
            exports['mythic_progbar']:Progress({
                name = action.name or GetCurrentResourceName(),
                duration = duration,
                label = label,
                useWhileDead = true,
                canCancel = false,
                controlDisables = {
                    disableMovement = true,
                    disableCarMovement = true,
                    disableMouse = false,
                    disableCombat = true
                }
            }, function() end)
        end)
        handled = ok
    end
    
    if not handled then
        SendNUIMessage({
            action = 'progressStart',
            data = {
                label = label,
                duration = duration
            }
        })
    end
    
    return handled, duration
end

local function stopProgressBar(handled)
    if not handled then
        SendNUIMessage({ action = 'progressEnd' })
    end
end

-- ============================================
-- MOVEMENT UTILITIES
-- ============================================

local function waitForArrival(ped, coords, arriveDistance, timeout)
    if not coords then
        return false
    end
    
    local startTime = GetGameTimer()
    local targetDistance = arriveDistance or 1.5
    
    while DoesEntityExist(ped) do
        local pedCoords = GetEntityCoords(ped)
        local distance = Vdist(pedCoords.x, pedCoords.y, pedCoords.z, coords.x, coords.y, coords.z)
        
        if distance <= targetDistance then
            return true
        end
        
        if timeout and timeout > 0 and (GetGameTimer() - startTime) >= timeout then
            return false
        end
        
        Citizen.Wait(100)
    end
    
    return false
end

-- ============================================
-- TASK EXECUTION
-- ============================================

--[[
    Execute a single task action
    
    This is the main function that processes each action in a sequence.
    It handles both built-in actions and custom registered actions.
    
    Built-in actions:
    - dialogClose: Closes the dialog
    - wait: Waits for specified duration
    - progress: Shows progress bar
    - camera: Manages camera (create, lookAt, destroy)
    - goTo: Moves ped to coordinates
    - playAnim: Plays animation
    - playFacial: Plays facial animation
    - attack: Makes ped attack target
    - follow: Makes ped follow target
    - wander: Makes ped wander
    - scenario: Makes ped play scenario
    - run: Executes custom function (modifies ctx)
    
    @param action: table - Action configuration
    @param ped: number - Ped entity handle
    @param ctx: table - Context object
    @return: table - {success, error, actionType, [additional data]}
]]
function executeTaskAction(action, ped, ctx)
    if not action or not action.type or not ped or not DoesEntityExist(ped) then
        return { success = true, error = nil }
    end
    
    -- Resolve action type (in case it's a function)
    local actionType = resolveValue(action.type, ctx)
    
    -- Check for custom task action (dialog-specific or global)
    local customHandler = getTaskAction(actionType, ctx.dialogId)
    
    if customHandler then
        local success, result = pcall(customHandler, ctx, action, ped)
        if not success then
            local errorMsg = string.format('[%s] Error in custom task action "%s": %s', 
                GetCurrentResourceName(), actionType, tostring(result))
            print(errorMsg)
            return { success = false, error = errorMsg, actionType = actionType }
        end
        return { success = true, error = nil }
    end
    
    -- Built-in actions
    
    -- CLOSE DIALOG
    if actionType == "dialogClose" then
        exports[GetCurrentResourceName()]:closeDialog()
        return { success = true, error = nil }
    end
    
    -- WAIT
    if actionType == "wait" then
        local duration = resolveValue(action.duration, ctx) or 0
        if duration > 0 then
            Citizen.Wait(duration)
        end
        return { success = true, error = nil }
    end
    
    -- PROGRESS BAR
    if actionType == "progress" then
        local handled, duration = startProgressBar(action)
        if duration and duration > 0 then
            Citizen.Wait(duration)
        end
        stopProgressBar(handled)
        return { success = true, error = nil }
    end
    
    -- RUN CUSTOM FUNCTION (modifies ctx)
    if actionType == "run" then
        if type(action.fn) == "function" then
            local success, err = pcall(action.fn, ctx)
            if not success then
                print(string.format('[%s] Error in run action: %s', GetCurrentResourceName(), tostring(err)))
                return { success = false, error = tostring(err), actionType = actionType }
            end
        end
        return { success = true, error = nil }
    end
    
    -- CAMERA
    if actionType == "camera" then
        local actionCmd = resolveValue(action.action, ctx)
        
        if actionCmd == "destroy" then
            destroyTaskCamera()
            return { success = true, error = nil }
        end
        
        if actionCmd == "create" then
            -- Validate vehicle if needed
            local target = resolveValue(action.target, ctx)
            if (target == "vehicle" or target == "engine") and not getVehicleFromContext(ctx, action) then
                if handleDenied then
                    handleDenied(ctx.dialog, ped, "missing_vehicle")
                end
                return { success = false, error = "Missing vehicle", actionType = actionType }
            end
            
            -- Create camera (handles both static and dynamic modes)
            createTaskCamera(action, ctx)
            return { success = true, error = nil }
        end
        
        if actionCmd == "lookAt" then
            -- Validate vehicle if needed
            local target = resolveValue(action.target, ctx)
            if (target == "vehicle" or target == "engine") and not getVehicleFromContext(ctx, action) then
                if handleDenied then
                    handleDenied(ctx.dialog, ped, "missing_vehicle")
                end
                return { success = false, error = "Missing vehicle", actionType = actionType }
            end
            
            lookAtTaskCamera(action, ctx)
            return { success = true, error = nil }
        end
        
        return { success = true, error = nil }
    end
    
    -- GO TO COORDINATES
    if actionType == "goTo" then
        local coords = resolveValue(action.coords, ctx)
        local target = resolveValue(action.target, ctx)
        
        if target == "vehicle" then
            local vehicle = getVehicleFromContext(ctx, action)
            if not vehicle then
                if handleDenied then
                    handleDenied(ctx.dialog, ped, "missing_vehicle")
                end
                return { success = false, error = "Missing vehicle", actionType = actionType }
            end
            coords = getCoordsFromOffset(vehicle, resolveValue(action.offset, ctx))
        elseif target == "ped" then
            if ctx.ped and DoesEntityExist(ctx.ped) then
                coords = getCoordsFromOffset(ctx.ped, resolveValue(action.offset, ctx))
            end
        elseif target == "player" then
            local playerPed = PlayerPedId()
            if playerPed and DoesEntityExist(playerPed) then
                coords = getCoordsFromOffset(playerPed, resolveValue(action.offset, ctx))
            end
        end
        
        if coords and coords.x and coords.y and coords.z then
            TaskGoToCoordAnyMeans(
                ped,
                coords.x,
                coords.y,
                coords.z,
                resolveValue(action.speed, ctx) or 1.0,
                resolveValue(action.p4, ctx) or 0,
                resolveValue(action.p5, ctx) or false,
                resolveValue(action.p6, ctx) or 786603,
                resolveValue(action.p7, ctx) or 0.0
            )
            
            if action.waitForArrival or action.arriveDistance then
                waitForArrival(ped, coords, resolveValue(action.arriveDistance, ctx) or 1.5, 
                    resolveValue(action.timeout, ctx) or 10000)
            end
        end
        
        return { success = true, error = nil }
    end
    
    -- PLAY ANIMATION
    if actionType == "playAnim" then
        local dict = resolveValue(action.dict, ctx)
        local anim = resolveValue(action.anim, ctx)
        
        if dict and anim and loadAnimDict(dict) then
            TaskPlayAnim(
                ped,
                dict,
                anim,
                resolveValue(action.blendIn, ctx) or 8.0,
                resolveValue(action.blendOut, ctx) or -8.0,
                resolveValue(action.duration, ctx) or -1,
                resolveValue(action.flag, ctx) or DialogEnums.AnimationFlag.UPPER_BODY,
                0.0,
                false,
                false,
                false
            )
            
            if action.blocking then
                local duration = resolveValue(action.duration, ctx) or 0
                if duration and duration > 0 then
                    Citizen.Wait(duration)
                end
            end
        end
        
        return { success = true, error = nil }
    end
    
    -- PLAY FACIAL ANIMATION
    if actionType == "playFacial" then
        local animDict = resolveValue(action.dict, ctx) or "facials@gen_male@variations@"
        local animName = resolveValue(action.facial, ctx) or resolveValue(action.anim, ctx) or resolveValue(action.name, ctx)
        
        if animName and loadAnimDict(animDict) then
            PlayFacialAnim(ped, animName, animDict)
            
            if action.blocking then
                local duration = resolveValue(action.duration, ctx) or 0
                if duration > 0 then
                    Citizen.Wait(duration)
                    ClearFacialIdleAnim(ped)
                end
            elseif resolveValue(action.duration, ctx) and resolveValue(action.duration, ctx) > 0 then
                SetTimeout(resolveValue(action.duration, ctx), function()
                    ClearFacialIdleAnim(ped)
                end)
            end
        end
        
        return { success = true, error = nil }
    end
    
    -- ATTACK TARGET
    if actionType == "attack" then
        local targetPed = resolveTaskTarget(resolveValue(action.target, ctx), ctx)
        
        if action.targetNetId then
            targetPed = NetToPed(action.targetNetId)
        end
        
        if targetPed and DoesEntityExist(targetPed) then
            TaskCombatPed(ped, targetPed, 0, 16)
        end
        
        return { success = true, error = nil }
    end
    
    -- FOLLOW TARGET
    if actionType == "follow" then
        local targetPed = resolveTaskTarget(resolveValue(action.target, ctx), ctx)
        
        if action.targetNetId then
            targetPed = NetToPed(action.targetNetId)
        end
        
        if targetPed and DoesEntityExist(targetPed) then
            TaskFollowToOffsetOfEntity(
                ped,
                targetPed,
                resolveValue(action.offsetX, ctx) or 0.0,
                resolveValue(action.offsetY, ctx) or 0.0,
                resolveValue(action.offsetZ, ctx) or 0.0,
                resolveValue(action.speed, ctx) or 1.0,
                resolveValue(action.timeout, ctx) or -1,
                resolveValue(action.stoppingRange, ctx) or 1.0,
                resolveValue(action.persist, ctx) ~= false
            )
        end
        
        return { success = true, error = nil }
    end
    
    -- WANDER
    if actionType == "wander" then
        TaskWanderStandard(
            ped,
            resolveValue(action.wanderRadius, ctx) or 10.0,
            resolveValue(action.wanderDuration, ctx) or 10.0
        )
        return { success = true, error = nil }
    end
    
    -- SCENARIO
    if actionType == "scenario" then
        local scenarioName = resolveValue(action.name, ctx)
        if scenarioName then
            TaskStartScenarioInPlace(
                ped,
                scenarioName,
                resolveValue(action.scenarioFlags, ctx) or 0,
                resolveValue(action.playEnterAnim, ctx) ~= false
            )
        end
        return { success = true, error = nil }
    end
    
    -- Unknown action type
    if Config.enableDebug then
        print(string.format('[%s] Unknown task action type: %s', GetCurrentResourceName(), tostring(actionType)))
    end
    
    return { success = true, error = nil }
end

-- ============================================
-- SEQUENCE EXECUTION
-- ============================================

--[[
    Run a task sequence
    
    Executes a sequence of actions in order. Each action receives the same
    ctx object which can be modified by "run" actions to share data.
    
    Features:
    - Global timeout protection
    - Error handling with optional stopOnError
    - Camera auto-destruction
    - Mutable context sharing
    
    @param sequence: table - Array of action configurations
    @param ped: number - Ped entity handle
    @param ctx: table - Context object
    @param stopOnError: boolean - Stop sequence on first error
]]
function runTaskSequence(sequence, ped, ctx, stopOnError)
    if type(sequence) ~= "table" or not ped or not DoesEntityExist(ped) then
        return
    end
    
    -- Track if sequence used camera for auto-destruction
    local usedCamera = false
    
    local sequenceTimeout = Config.taskSequenceTimeout or 30000
    local sequenceStartTime = GetGameTimer()
    
    Citizen.CreateThread(function()
        for i, action in ipairs(sequence) do
            -- Check if ped still exists
            if not ped or not DoesEntityExist(ped) then
                print(string.format('[%s] Task sequence aborted: ped no longer exists at action %d', 
                    GetCurrentResourceName(), i))
                break
            end
            
            -- Check global timeout
            if (GetGameTimer() - sequenceStartTime) >= sequenceTimeout then
                print(string.format('[%s] Task sequence timed out after %dms at action %d/%d', 
                    GetCurrentResourceName(), sequenceTimeout, i, #sequence))
                break
            end
            
            -- Track camera usage
            if action.type == "camera" and action.action == "create" then
                usedCamera = true
            end
            
            -- Execute action
            local result = executeTaskAction(action, ped, ctx)
            
            if result.success == false then
                local errorMsg = string.format('[%s] Task action failed at step %d/%d: type=%s, error=%s', 
                    GetCurrentResourceName(), i, #sequence, action.type or 'unknown', result.error or 'unknown')
                print(errorMsg)
                
                if stopOnError then
                    print(string.format('[%s] Stopping task sequence due to error', GetCurrentResourceName()))
                    break
                end
            end
            
            -- Wait between actions if specified
            if action.wait and action.wait > 0 then
                Citizen.Wait(action.wait)
            end
        end
        
        -- Auto-destroy camera if enabled and camera was used
        if Config.cameraAutoDestroy and usedCamera then
            destroyTaskCamera()
        end
        
        if Config.enableDebug then
            print(string.format('[%s] Task sequence completed', GetCurrentResourceName()))
        end
    end)
end

--[[
    Run a task function
    
    Main entry point for executing tasks from dialog options.
    
    @param taskFn: function(ctx) - Task function returning sequence config
    @param ctx: table - Context object
    @return: table - Task result with ped, sequence, keepDialog, stopOnError
]]
function runTask(taskFn, ctx)
    if type(taskFn) ~= "function" then
        return nil
    end
    
    local success, result = pcall(taskFn, ctx)
    if not success then
        print(string.format('[%s] Error in task function: %s', GetCurrentResourceName(), tostring(result)))
        return nil
    end
    
    if result == nil then
        return nil
    end
    
    local ped = ctx.ped
    local sequence = nil
    local keepDialog = false
    local stopOnError = false
    
    if type(result) == "table" then
        if result.ped then
            ped = result.ped
        end
        if result.sequence then
            sequence = result.sequence
        end
        if result.keepDialog ~= nil then
            keepDialog = result.keepDialog
        end
        if result.stopOnError ~= nil then
            stopOnError = result.stopOnError
        end
    elseif type(result) == "number" then
        ped = result
    end
    
    -- Close dialog unless keepDialog is true
    if not keepDialog and isDialogOpen then
        exports[GetCurrentResourceName()]:closeDialog()
    end
    
    -- Run sequence if provided
    if sequence then
        runTaskSequence(sequence, ped, ctx, stopOnError)
    end
    
    return {
        ped = ped,
        sequence = sequence,
        keepDialog = keepDialog,
        stopOnError = stopOnError
    }
end

--[[
    Get all registered task actions
    @return: table - {global = {...}, byDialog = {...}}
]]
function getTaskActions()
    return taskActions
end

--[[
    Get global task actions
    @return: table - Global actions dictionary
]]
function getGlobalTaskActions()
    return taskActions.global
end

--[[
    Get dialog-specific task actions
    @param dialogId: string - Dialog ID
    @return: table - Actions for that dialog or nil
]]
function getDialogTaskActions(dialogId)
    return taskActions.byDialog[dialogId]
end
