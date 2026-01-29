--[[
    Main Dialog System Module
    
    Core functionality for the Advance Dialog system.
    Manages dialog state, animations, NUI communication, and integrates
    with the camera and task systems.
    
    Features:
    - Dialog state management (open/close)
    - Animation system integration
    - NUI callbacks for user interaction
    - Task sequence execution
    - Context building for callbacks
    - Cleanup on resource stop
]]

local activeDialog = nil
local activePed = nil
local currentAnimation = nil
local currentFacialAnim = nil
local isDialogOpen = false
local registeredDialogs = {}
local pendingRequestContext = nil

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

--[[
    Handle denied dialog interaction
    
    Called when canInteract returns false or other validation fails.
    Triggers events and runs onDenied callbacks/tasks if configured.
    
    @param dialogData: Dialog configuration
    @param ped: Ped entity
    @param reason: String reason for denial
]]
function handleDenied(dialogData, ped, reason)
    local ctx = buildContext(dialogData, nil, ped)
    ctx.reason = reason or "canInteract"
    
    TriggerEvent(DialogEnums.EventType.DIALOG_DENIED, ctx)
    
    if dialogData and dialogData.onDenied then
        if type(dialogData.onDenied) == "function" then
            local success, err = pcall(dialogData.onDenied, ctx)
            if not success then
                print(string.format('[%s] Error in onDenied callback: %s', GetCurrentResourceName(), tostring(err)))
            end
        elseif type(dialogData.onDenied) == "table" then
            if type(dialogData.onDenied.callback) == "function" then
                local success, err = pcall(dialogData.onDenied.callback, ctx)
                if not success then
                    print(string.format('[%s] Error in onDenied callback: %s', GetCurrentResourceName(), tostring(err)))
                end
            end
            
            if dialogData.onDenied.task then
                runTask(dialogData.onDenied.task, ctx)
            end
        end
    end
end

-- ============================================
-- ANIMATION SYSTEM
-- ============================================

--[[
    Stop current animations on active ped
]]
function stopCurrentAnimations()
    if activePed and DoesEntityExist(activePed) then
        ClearPedTasks(activePed)
        ClearPedSecondaryTask(activePed)
        
        if currentFacialAnim then
            ClearFacialIdleAnim(activePed)
        end
    end
    
    currentAnimation = nil
    currentFacialAnim = nil
end

--[[
    Apply animation to ped
    
    @param animation: Animation configuration table
    @param ped: Ped entity handle
]]
function applyAnimation(animation, ped)
    if not ped or not DoesEntityExist(ped) then
        return
    end
    
    if not animation or not animation.type then
        return
    end
    
    if animation.type == DialogEnums.AnimationType.COMMON then
        if animation.dict and animation.anim then
            if loadAnimDict(animation.dict) then
                TaskPlayAnim(ped, animation.dict, animation.anim,
                    animation.blendIn or 8.0,
                    animation.blendOut or -8.0,
                    animation.duration or -1,
                    animation.flag or DialogEnums.AnimationFlag.UPPER_BODY,
                    0.0, false, false, false)
                
                currentAnimation = animation
                
                local animCtx = buildContext(activeDialog, nil, ped)
                animCtx.animation = animation
                TriggerEvent(DialogEnums.EventType.ANIMATION_START, animCtx)
                
                if animation.duration and animation.duration > 0 then
                    SetTimeout(animation.duration, function()
                        ClearPedTasks(ped)
                        currentAnimation = nil
                        
                        local animCtx = buildContext(activeDialog, nil, ped)
                        animCtx.animation = animation
                        TriggerEvent(DialogEnums.EventType.ANIMATION_END, animCtx)
                    end)
                end
            end
        end
    elseif animation.type == DialogEnums.AnimationType.FACIAL then
        if animation.facial and animation.dict then
            local animName = animation.facial
            local animDict = animation.dict or "facials@gen_male@variations@"
            
            if loadAnimDict(animDict) then
                PlayFacialAnim(ped, animName, animDict)
                currentFacialAnim = animation
                
                if animation.duration and animation.duration > 0 then
                    SetTimeout(animation.duration, function()
                        ClearFacialIdleAnim(ped)
                        currentFacialAnim = nil
                    end)
                end
            end
        end
    end
end

-- ============================================
-- NUI OPTIONS BUILDING
-- ============================================

--[[
    Build NUI options from dialog data
    
    Evaluates canInteract for each option and builds the options
    array for the NUI interface.
    
    @param dialogData: Dialog configuration
    @param ped: Ped entity
    @return: Array of option tables for NUI
]]
function buildNuiOptions(dialogData, ped)
    local options = {}
    
    if not dialogData or type(dialogData.options) ~= "table" then
        return options
    end
    
    for _, option in ipairs(dialogData.options) do
        local enabled = isOptionSelectable(option, dialogData, ped)
        
        table.insert(options, {
            label = option.label,
            description = option.description,
            icon = option.icon,
            disabled = not enabled
        })
    end
    
    return options
end

--[[
    Check if option is selectable
    
    Evaluates canInteract for an option. Can be boolean or function.
    
    @param option: Option configuration
    @param dialogData: Dialog configuration
    @param ped: Ped entity
    @return: Boolean
]]
function isOptionSelectable(option, dialogData, ped)
    if option == nil then
        return false
    end
    
    if option.canInteract == nil then
        return true
    end
    
    if type(option.canInteract) == "boolean" then
        return option.canInteract
    end
    
    if type(option.canInteract) == "function" then
        local ctx = buildContext(dialogData, option, ped)
        local success, allowed = pcall(option.canInteract, ctx.playerPed, ctx)
        if not success then
            print(string.format('[%s] Error in option.canInteract: %s', GetCurrentResourceName(), tostring(allowed)))
            return false
        end
        
        return allowed == true
    end
    
    return true
end

--[[
    Check if dialog can be opened
    
    Evaluates dialog-level canInteract if present.
    
    @param dialogData: Dialog configuration
    @param ped: Ped entity
    @return: Boolean
]]
function canOpenDialog(dialogData, ped)
    if not dialogData then
        return true
    end
    
    if type(dialogData.canInteract) ~= "function" then
        return true
    end
    
    local ctx = buildContext(dialogData, nil, ped)
    local success, allowed = pcall(dialogData.canInteract, ctx.playerPed, ctx)
    
    if not success then
        print(string.format('[%s] Error in canInteract: %s', GetCurrentResourceName(), tostring(allowed)))
        handleDenied(dialogData, ped, "canInteract")
        return false
    end
    
    if allowed then
        return true
    end
    
    handleDenied(dialogData, ped, "canInteract")
    return false
end

-- ============================================
-- DIALOG MANAGEMENT
-- ============================================

--[[
    Show dialog
    
    Main function to display a dialog. Handles validation, animation,
    camera positioning, and NUI communication.
    
    @param dialogData: Dialog configuration
    @param ped: Target ped (optional, uses activePed or player)
    @param isTransition: Boolean - if true, skips some validations
    @return: success, errorMessage
]]
function showDialog(dialogData, ped, isTransition)
    if isDialogOpen and not isTransition then
        return false, _L('dialog_already_open')
    end
    
    if not dialogData then
        return false, _L('no_dialog_data')
    end
    
    if dialogData.id == nil then
        print(string.format('[%s] Error: Missing dialog id', GetCurrentResourceName()))
        return false, _L('missing_dialog_id')
    end
    
    if type(dialogData.id) == "string" and dialogData.id == "" then
        print(string.format('[%s] Error: Invalid dialog id', GetCurrentResourceName()))
        return false, _L('invalid_dialog_id')
    end
    
    if type(dialogData.id) ~= "string" and type(dialogData.id) ~= "number" then
        print(string.format('[%s] Error: Invalid dialog id type', GetCurrentResourceName()))
        return false, _L('invalid_dialog_id_type')
    end
    
    local resolvedPed = resolvePed(ped)
    if resolvedPed and DoesEntityExist(resolvedPed) then
        activePed = resolvedPed
    end
    
    if not canOpenDialog(dialogData, resolvedPed) then
        return false, _L('can_interact_failed')
    end
    
    if resolvedPed and DoesEntityExist(resolvedPed) and activePed ~= resolvedPed then
        stopCurrentAnimations()
    end
    
    activeDialog = dialogData
    activePed = resolvedPed
    
    if resolvedPed and DoesEntityExist(resolvedPed) then
        pointCameraAtEntity(resolvedPed)
    end
    
    if dialogData.animation and not isTransition then
        applyAnimation(dialogData.animation, activePed)
    end
    
    SendNUIMessage({
        action = 'showDialog',
        data = {
            id = dialogData.id,
            speaker = dialogData.speaker or '',
            text = dialogData.text or '',
            options = buildNuiOptions(dialogData, activePed)
        }
    })
    
    SetNuiFocus(true, true)
    isDialogOpen = true
    
    TriggerEvent(DialogEnums.EventType.DIALOG_OPEN, buildContext(dialogData, nil, activePed))
    
    if Config.enableDebug then
        print(string.format('[%s] Dialog opened: %s', GetCurrentResourceName(), tostring(dialogData.id)))
    end
    
    return true
end

--[[
    Close dialog
    
    Closes the active dialog, stops animations, destroys camera,
    and triggers events.
    
    @return: success, errorMessage
]]
function closeDialog()
    if not isDialogOpen then
        return false, _L('no_dialog_open')
    end
    
    stopCurrentAnimations()
    destroyTaskCamera() -- Also destroys any active task camera
    
    SendNUIMessage({ action = 'closeDialog' })
    SetNuiFocus(false, false)
    isDialogOpen = false
    
    if activeDialog then
        TriggerEvent(DialogEnums.EventType.DIALOG_CLOSE, buildContext(activeDialog, nil, activePed))
    else
        TriggerEvent(DialogEnums.EventType.DIALOG_CLOSE, {
            dialog = nil,
            dialogId = nil,
            option = nil,
            ped = activePed,
            playerPed = PlayerPedId(),
            metadata = {},
            optionMetadata = {},
            mergedMetadata = {}
        })
    end
    
    activeDialog = nil
    activePed = nil
    
    if Config.enableDebug then
        print(string.format('[%s] Dialog closed', GetCurrentResourceName()))
    end
    
    return true
end

--[[
    Get current dialog state
    @return: Table with isOpen, dialog, ped
]]
function getDialogState()
    return {
        isOpen = isDialogOpen,
        dialog = activeDialog,
        ped = activePed
    }
end

--[[
    Register dialogs
    
    Registers one or more dialogs for client-side access.
    
    @param dialogTable: Table with dialogId as keys, dialog config as values
    @return: success, errorMessage
]]
function registerDialogs(dialogTable)
    if type(dialogTable) ~= "table" then
        return false, _L('invalid_dialog_table')
    end
    
    for id, dialog in pairs(dialogTable) do
        if type(dialog) == "table" then
            local idType = type(id)
            local validKey = (idType == "string" and id ~= "") or idType == "number"
            
            if not validKey then
                print(string.format('[%s] Warning: Skipping dialog with invalid id key', GetCurrentResourceName()))
            else
                if dialog.id ~= nil then
                    local dialogIdType = type(dialog.id)
                    local validDialogId = (dialogIdType == "string" and dialog.id ~= "") or dialogIdType == "number"
                    
                    if not validDialogId then
                        print(string.format('[%s] Warning: Dialog id invalid, using key: %s', GetCurrentResourceName(), tostring(id)))
                    elseif dialog.id ~= id then
                        print(string.format('[%s] Warning: Dialog id mismatch, using key: %s', GetCurrentResourceName(), tostring(id)))
                    end
                end
                
                dialog.id = id
                registeredDialogs[id] = dialog
            end
        end
    end
    
    if Config.enableDebug then
        local count = 0
        for _ in pairs(registeredDialogs) do count = count + 1 end
        print(string.format('[%s] Registered dialogs: %d', GetCurrentResourceName(), count))
    end
    
    return true
end

--[[
    Set active ped
    @param ped: Ped entity
    @return: success, errorMessage
]]
function setActivePed(ped)
    if ped and DoesEntityExist(ped) then
        activePed = ped
        return true
    end
    
    activePed = nil
    return false, _L('invalid_ped')
end

--[[
    Get active ped
    @return: Ped entity or nil
]]
function getActivePed()
    return activePed
end

--[[
    Open dialog by ID
    
    Opens a registered dialog by its ID. If not found locally,
    requests it from server.
    
    @param dialogId: Dialog ID string or number
    @param ped: Ped entity (optional)
    @return: success
]]
function openDialogById(dialogId, ped)
    if not dialogId then
        return false, _L('missing_dialog_id')
    end
    
    local resolvedPed = resolvePed(ped)
    local dialog = registeredDialogs[dialogId]
    
    local requestCtx = buildContext(dialog, nil, resolvedPed)
    requestCtx.dialogId = dialogId
    TriggerEvent(DialogEnums.EventType.DIALOG_REQUESTED, requestCtx)
    
    if dialog then
        return showDialog(dialog, resolvedPed, false)
    end
    
    pendingRequestContext = {
        ped = resolvedPed,
        dialogId = dialogId
    }
    TriggerServerEvent(string.format('%s:server:getDialog', GetCurrentResourceName()), dialogId)
    return true
end

--[[
    Create ped and open dialog
    
    Helper function that creates a ped and immediately opens a dialog.
    
    @param dialogId: Dialog ID
    @param pedConfig: Ped configuration table
    @return: ped, netId
]]
function createPedAndOpen(dialogId, pedConfig)
    local ped, netId = createPed(pedConfig)
    if ped then
        activePed = ped
        openDialogById(dialogId, ped)
    end
    return ped, netId
end

--[[
    Open dialog after sequence completion
    
    Helper to open a dialog after a delay. Useful for opening
    completion dialogs after task sequences.
    
    @param dialogId: Dialog ID to open
    @param ped: Ped to associate with dialog (optional, uses activePed)
    @param delay: Delay in milliseconds (optional)
]]
function openDialogAfterSequence(dialogId, ped, delay)
    Citizen.CreateThread(function()
        if delay and delay > 0 then
            Citizen.Wait(delay)
        end
        
        local targetPed = ped or activePed
        openDialogById(dialogId, targetPed)
    end)
end

-- ============================================
-- EVENT HANDLERS
-- ============================================

-- Server response handler
RegisterNetEvent(string.format('%s:client:receiveDialog', GetCurrentResourceName()))
AddEventHandler(string.format('%s:client:receiveDialog', GetCurrentResourceName()), function(payload)
    local dialog = payload
    local ped = activePed
    local dialogId = nil
    
    if type(payload) == "table" and payload.dialog then
        dialog = payload.dialog
        dialogId = payload.dialogId
        
        if payload.pedNetId then
            local pedFromNet = NetToPed(payload.pedNetId)
            if pedFromNet and DoesEntityExist(pedFromNet) then
                ped = pedFromNet
            end
        elseif pendingRequestContext and pendingRequestContext.ped then
            ped = pendingRequestContext.ped
        end
    elseif pendingRequestContext and pendingRequestContext.ped then
        ped = pendingRequestContext.ped
    end
    
    if dialog then
        dialog.id = dialog.id or dialogId
        exports[GetCurrentResourceName()]:showDialog(dialog, ped, true)
    else
        print(string.format('[%s] Error: Could not fetch dialog from server', GetCurrentResourceName()))
    end
    
    pendingRequestContext = nil
end)

-- Close key handler
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        if isDialogOpen then
            DisableControlAction(0, Config.closeKey, true)
            
            if IsDisabledControlJustPressed(0, Config.closeKey) then
                exports[GetCurrentResourceName()]:closeDialog()
            end
        end
    end
end)

-- NUI Callback for option selection
RegisterNUICallback('selectOption', function(data, cb)
    if not activeDialog or not activeDialog.options then
        cb('ok')
        return
    end
    
    local selectedIndex = tonumber(data.index) or data.index
    if selectedIndex == -1 then
        exports[GetCurrentResourceName()]:closeDialog()
        cb('ok')
        return
    end
    
    local selectedOption = activeDialog.options[selectedIndex]
    if not selectedOption then
        cb('ok')
        return
    end
    
    if Config.enableDebug then
        print(string.format('[%s] Option selected: %d, %s', GetCurrentResourceName(), selectedIndex, selectedOption.label or 'Close'))
    end
    
    local ped = resolvePed(activePed)
    local ctx = buildContext(activeDialog, selectedOption, ped)
    
    -- Check if option is selectable
    if not isOptionSelectable(selectedOption, activeDialog, ped) then
        ctx.reason = "option_canInteract"
        TriggerEvent(DialogEnums.EventType.DIALOG_DENIED, ctx)
        cb('ok')
        return
    end
    
    -- Execute callback if present
    if selectedOption.callback then
        local success, err = pcall(selectedOption.callback, ctx)
        if not success then
            print(string.format('[%s] Error in callback: %s', GetCurrentResourceName(), tostring(err)))
        end
    end
    
    -- Execute task if present
    local taskResult = nil
    if selectedOption.task then
        taskResult = runTask(selectedOption.task, ctx)
        if taskResult and taskResult.ped then
            ctx.ped = taskResult.ped
        end
    end
    
    local skipNext = taskResult and taskResult.sequence and not taskResult.keepDialog
    
    -- Handle next dialog or close
    if selectedOption.next and not skipNext then
        local nextDialogId = selectedOption.next
        local nextDialog = registeredDialogs[nextDialogId]
        
        if nextDialog then
            if canOpenDialog(nextDialog, ctx.ped) then
                exports[GetCurrentResourceName()]:showDialog(nextDialog, ctx.ped, true)
            end
        else
            pendingRequestContext = {
                ped = ctx.ped,
                dialogId = nextDialogId
            }
            TriggerServerEvent(string.format('%s:server:getDialog', GetCurrentResourceName()), nextDialogId)
        end
    elseif selectedOption.close then
        exports[GetCurrentResourceName()]:closeDialog()
    end
    
    TriggerEvent(DialogEnums.EventType.OPTION_SELECTED, ctx)
    cb('ok')
end)

-- Resource stop cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    
    -- Close dialog
    if isDialogOpen then
        closeDialog()
    end
    
    -- Destroy camera
    destroyTaskCamera()
    
    -- Stop animations
    stopCurrentAnimations()
    
    -- Clear created peds
    clearCreatedPeds()
    
    if Config.enableDebug then
        print(string.format('[%s] Cleanup completed on resource stop', GetCurrentResourceName()))
    end
end)

-- ============================================
-- EXPORTS
-- ============================================

exports('showDialog', showDialog)
exports('closeDialog', closeDialog)
exports('getDialogState', getDialogState)
exports('stopAnimations', stopCurrentAnimations)
exports('registerDialogs', registerDialogs)
exports('openDialogById', openDialogById)
exports('setActivePed', setActivePed)
exports('getActivePed', getActivePed)
exports('createPedAndOpen', createPedAndOpen)
exports('registerTaskAction', registerTaskAction)
exports('openDialogAfterSequence', openDialogAfterSequence)
