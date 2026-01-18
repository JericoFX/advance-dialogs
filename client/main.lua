local activeDialog = nil
local activePed = nil
local currentAnimation = nil
local currentFacialAnim = nil
local isDialogOpen = false
local registeredDialogs = {}

RegisterNetEvent('simple-dialogs:client:receiveDialog')
AddEventHandler('simple-dialogs:client:receiveDialog', function(dialog)
    if dialog then
        exports['simple-dialogs']:showDialog(dialog, activePed, true)
    else
        print('[SimpleDialogs] Error: Could not fetch dialog from server')
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        if isDialogOpen then
            DisableControlAction(0, Config.closeKey, true)
            
            if IsDisabledControlJustPressed(0, Config.closeKey) then
                exports['simple-dialogs']:closeDialog()
            end
        end
    end
end)

RegisterNUICallback('selectOption', function(data, cb)
    if not activeDialog or not activeDialog.options then
        cb('ok')
        return
    end
    
    local selectedIndex = data.index
    local selectedOption = activeDialog.options[selectedIndex]
    
    if not selectedOption then
        cb('ok')
        return
    end
    
    if Config.enableDebug then
        print('[SimpleDialogs] Option selected:', selectedIndex, selectedOption.label or 'Close')
    end
    
    if selectedOption.callback then
        local success, err = pcall(selectedOption.callback, {
            dialog = activeDialog,
            option = selectedOption,
            ped = activePed,
            metadata = activeDialog.metadata or {}
        })

        if not success then
            print('[SimpleDialogs] Error in callback:', err)
        end
    end

    if selectedOption.next then
        local nextDialogId = selectedOption.next
        local nextDialog = registeredDialogs[nextDialogId]

        if nextDialog then
            exports['simple-dialogs']:showDialog(nextDialog, activePed, true)
        else
            TriggerServerEvent('simple-dialogs:server:getDialog', nextDialogId)
        end
    elseif selectedOption.close then
        exports['simple-dialogs']:closeDialog()
    end
    
    TriggerEvent(DialogEnums.EventType.OPTION_SELECTED, {
        option = selectedOption,
        dialog = activeDialog,
        ped = activePed
    })
    
    cb('ok')
end)

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

function applyAnimation(animation, ped)
    if not ped or not DoesEntityExist(ped) then
        return
    end
    
    if not animation or not animation.type then
        return
    end
    
    if animation.type == DialogEnums.AnimationType.COMMON then
        if animation.dict and animation.anim then
            RequestAnimDict(animation.dict)
            
            local timeout = 0
            while not HasAnimDictLoaded(animation.dict) and timeout < 100 do
                Citizen.Wait(50)
                timeout = timeout + 1
            end
            
            if HasAnimDictLoaded(animation.dict) then
                TaskPlayAnim(ped, animation.dict, animation.anim,
                    animation.blendIn or 8.0,
                    animation.blendOut or -8.0,
                    animation.duration or -1,
                    animation.flag or DialogEnums.AnimationFlag.UPPER_BODY,
                    0.0, false, false, false)
                
                currentAnimation = animation
                
                TriggerEvent(DialogEnums.EventType.ANIMATION_START, {
                    ped = ped,
                    animation = animation
                })
                
                if animation.duration and animation.duration > 0 then
                    SetTimeout(animation.duration, function()
                        ClearPedTasks(ped)
                        currentAnimation = nil
                        
                        TriggerEvent(DialogEnums.EventType.ANIMATION_END, {
                            ped = ped,
                            animation = animation
                        })
                    end)
                end
            end
        end
    elseif animation.type == DialogEnums.AnimationType.FACIAL then
        if animation.facial and animation.dict then
            local animName = animation.facial
            local animDict = animation.dict or "facials@gen_male@variations@"
            
            RequestAnimDict(animDict)
            
            local timeout = 0
            while not HasAnimDictLoaded(animDict) and timeout < 100 do
                Citizen.Wait(50)
                timeout = timeout + 1
            end
            
            if HasAnimDictLoaded(animDict) then
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

function showDialog(dialogData, ped, isTransition)
    if isDialogOpen and not isTransition then
        return false, "Dialog already open"
    end

    if not dialogData then
        return false, "No dialog data provided"
    end

    if ped and DoesEntityExist(ped) and activePed ~= ped then
        stopCurrentAnimations()
    end

    activeDialog = dialogData
    activePed = ped or nil

    if dialogData.animation and not isTransition then
        applyAnimation(dialogData.animation, activePed)
    end

    SendNUIMessage({
        action = 'showDialog',
        data = {
            speaker = dialogData.speaker or '',
            text = dialogData.text or '',
            options = dialogData.options or {}
        }
    })

    SetNuiFocus(true, true)
    isDialogOpen = true

    TriggerEvent(DialogEnums.EventType.DIALOG_OPEN, {
        dialog = dialogData,
        ped = activePed
    })

    if Config.enableDebug then
        print('[SimpleDialogs] Dialog opened:', dialogData.id or 'unknown')
    end

    return true
end

function closeDialog()
    if not isDialogOpen then
        return false, "No dialog open"
    end
    
    stopCurrentAnimations()
    
    SendNUIMessage({
        action = 'closeDialog'
    })
    
    SetNuiFocus(false, false)
    isDialogOpen = false
    
    TriggerEvent(DialogEnums.EventType.DIALOG_CLOSE, {
        dialog = activeDialog,
        ped = activePed
    })
    
    activeDialog = nil
    activePed = nil
    
    if Config.enableDebug then
        print('[SimpleDialogs] Dialog closed')
    end
    
    return true
end

function getDialogState()
    return {
        isOpen = isDialogOpen,
        dialog = activeDialog,
        ped = activePed
    }
end

function registerDialogs(dialogTable)
    if type(dialogTable) ~= "table" then
        return false, "Invalid dialog table"
    end

    for id, dialog in pairs(dialogTable) do
        if type(dialog) == "table" then
            dialog.id = dialog.id or id
            registeredDialogs[id] = dialog
        end
    end

    if Config.enableDebug then
        print('[SimpleDialogs] Registered dialogs:', table.count(registeredDialogs))
    end

    return true
end

exports('showDialog', showDialog)
exports('closeDialog', closeDialog)
exports('getDialogState', getDialogState)
exports('stopAnimations', stopCurrentAnimations)
exports('registerDialogs', registerDialogs)
