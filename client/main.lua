local activeDialog = nil
local activePed = nil
local currentAnimation = nil
local currentFacialAnim = nil
local isDialogOpen = false
local registeredDialogs = {}
local pendingRequestContext = nil
local taskActions = {}
local activeTaskCamera = nil
local handleDenied = nil

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end

    if value > maxValue then
        return maxValue
    end

    return value
end

local function resolvePed(ped)
    if ped and DoesEntityExist(ped) then
        return ped
    end

    if activePed and DoesEntityExist(activePed) then
        return activePed
    end

    local playerPed = PlayerPedId()
    if playerPed and DoesEntityExist(playerPed) then
        return playerPed
    end

    return ped
end

local function pointCameraAtEntity(entity)
    if not entity or not DoesEntityExist(entity) then
        return
    end

    local playerPed = PlayerPedId()
    if not playerPed or not DoesEntityExist(playerPed) then
        return
    end

    if entity == playerPed then
        return
    end

    local camCoords = GetGameplayCamCoord()
    local targetCoords = GetEntityCoords(entity)

    local dx = targetCoords.x - camCoords.x
    local dy = targetCoords.y - camCoords.y
    local dz = targetCoords.z - camCoords.z

    local targetHeading = GetHeadingFromVector_2d(dx, dy)
    local playerHeading = GetEntityHeading(playerPed)
    local relativeHeading = targetHeading - playerHeading

    if relativeHeading > 180.0 then
        relativeHeading = relativeHeading - 360.0
    elseif relativeHeading < -180.0 then
        relativeHeading = relativeHeading + 360.0
    end

    SetGameplayCamRelativeHeading(relativeHeading)

    local distance = math.sqrt(dx * dx + dy * dy)
    if distance > 0.001 then
        local pitch = -math.deg(math.atan(dz, distance))
        pitch = clamp(pitch, -89.0, 89.0)
        SetGameplayCamRelativePitch(pitch, 1.0)
    end
end

local function mergeTables(baseTable, overrideTable)
    local merged = {}

    if type(baseTable) == "table" then
        for key, value in pairs(baseTable) do
            merged[key] = value
        end
    end

    if type(overrideTable) == "table" then
        for key, value in pairs(overrideTable) do
            merged[key] = value
        end
    end

    return merged
end

local function buildContext(dialogData, option, ped)
    local dialogMetadata = (dialogData and dialogData.metadata) or {}
    local optionMetadata = (option and option.metadata) or {}

    return {
        dialog = dialogData,
        dialogId = dialogData and dialogData.id or nil,
        option = option,
        ped = ped,
        playerPed = PlayerPedId(),
        metadata = dialogMetadata,
        optionMetadata = optionMetadata,
        mergedMetadata = mergeTables(dialogMetadata, optionMetadata)
    }
end

local function loadAnimDict(dict)
    if not dict then
        return false
    end

    RequestAnimDict(dict)

    local timeout = 0
    while not HasAnimDictLoaded(dict) and timeout < 100 do
        Citizen.Wait(50)
        timeout = timeout + 1
    end

    return HasAnimDictLoaded(dict)
end

local function resolveTaskTarget(target, ctx)
    if not target then
        return nil
    end

    if target == "player" then
        return ctx.playerPed or PlayerPedId()
    end

    if type(target) == "number" then
        return target
    end

    return nil
end

local function getVehicleFromContext(ctx, action)
    local netId = nil
    if action and action.vehicleNetId then
        netId = action.vehicleNetId
    end

    if not netId and ctx and ctx.mergedMetadata then
        netId = ctx.mergedMetadata.vehicleNetId
    end

    if not netId and ctx and ctx.metadata then
        netId = ctx.metadata.vehicleNetId
    end

    if not netId then
        return nil
    end

    local vehicle = NetToVeh(netId)
    if vehicle and DoesEntityExist(vehicle) then
        return vehicle
    end

    return nil
end

local function getCoordsFromOffset(entity, offset)
    if not entity or not DoesEntityExist(entity) then
        return nil
    end

    local off = offset or {}
    local coords = GetOffsetFromEntityInWorldCoords(entity, off.x or 0.0, off.y or 0.0, off.z or 0.0)
    return { x = coords.x, y = coords.y, z = coords.z }
end

local function getEngineCoords(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then
        return nil
    end

    local boneIndex = GetEntityBoneIndexByName(vehicle, "engine")
    if boneIndex == -1 then
        boneIndex = GetEntityBoneIndexByName(vehicle, "bonnet")
    end

    if boneIndex ~= -1 then
        local coords = GetWorldPositionOfEntityBone(vehicle, boneIndex)
        return { x = coords.x, y = coords.y, z = coords.z }
    end

    local coords = GetEntityCoords(vehicle)
    return { x = coords.x, y = coords.y, z = coords.z }
end

local function isResourceStarted(resourceName)
    return GetResourceState(resourceName) == "started"
end

local function startProgressBar(action)
    local duration = action.duration or 0
    local label = action.label or "Working..."

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
                name = action.name or "advance-dialog",
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
                name = action.name or "advance-dialog",
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

local function destroyTaskCamera()
    if activeTaskCamera then
        RenderScriptCams(false, true, 250, true, true)
        DestroyCam(activeTaskCamera, false)
        activeTaskCamera = nil
    end
end

local function createTaskCamera(action, ctx)
    destroyTaskCamera()

    activeTaskCamera = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)

    local coords = action.coords
    if not coords then
        local targetEntity = nil
        if action.target == "ped" then
            targetEntity = ctx.ped
        elseif action.target == "player" then
            targetEntity = ctx.playerPed
        elseif action.target == "vehicle" or action.target == "engine" then
            targetEntity = getVehicleFromContext(ctx, action)
        end

        if targetEntity and DoesEntityExist(targetEntity) then
            coords = getCoordsFromOffset(targetEntity, action.offset)
        end
    end

    if coords then
        SetCamCoord(activeTaskCamera, coords.x, coords.y, coords.z)
    end

    SetCamFov(activeTaskCamera, action.fov or 45.0)
    RenderScriptCams(true, true, action.fadeTime or 250, true, true)
end

local function lookAtTaskCamera(action, ctx)
    if not activeTaskCamera then
        return
    end

    local coords = action.coords
    if not coords and action.target then
        if action.target == "ped" then
            local ped = ctx.ped
            if ped and DoesEntityExist(ped) then
                local pedCoords = GetEntityCoords(ped)
                coords = { x = pedCoords.x, y = pedCoords.y, z = pedCoords.z }
            end
        elseif action.target == "player" then
            local playerPed = ctx.playerPed
            if playerPed and DoesEntityExist(playerPed) then
                local playerCoords = GetEntityCoords(playerPed)
                coords = { x = playerCoords.x, y = playerCoords.y, z = playerCoords.z }
            end
        elseif action.target == "vehicle" or action.target == "engine" then
            local vehicle = getVehicleFromContext(ctx, action)
            if vehicle and DoesEntityExist(vehicle) then
                if action.target == "engine" then
                    coords = getEngineCoords(vehicle)
                else
                    local vehicleCoords = GetEntityCoords(vehicle)
                    coords = { x = vehicleCoords.x, y = vehicleCoords.y, z = vehicleCoords.z }
                end
            end
        end
    end

    if coords then
        PointCamAtCoord(activeTaskCamera, coords.x, coords.y, coords.z)
    end
end

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

local function executeTaskAction(action, ped, ctx)
    if not action or not action.type or not ped or not DoesEntityExist(ped) then
        return true
    end

    local customHandler = taskActions[action.type]
    if customHandler then
        local success, err = pcall(customHandler, ctx, action, ped)
        if not success then
            print('[AdvanceDialog] Error in task action:', err)
        end
        return success
    end

    if action.type == "dialogClose" then
        exports['advance-dialog']:closeDialog()
        return true
    end

    if action.type == "wait" then
        if action.duration and action.duration > 0 then
            Citizen.Wait(action.duration)
        end
        return true
    end

    if action.type == "progress" then
        local handled, duration = startProgressBar(action)
        if duration and duration > 0 then
            Citizen.Wait(duration)
        end
        stopProgressBar(handled)
        return true
    end

    if action.type == "camera" then
        if action.action == "destroy" then
            destroyTaskCamera()
            return true
        end

        if action.action == "create" then
            if (action.target == "vehicle" or action.target == "engine") and not getVehicleFromContext(ctx, action) then
                handleDenied(ctx.dialog, ped, "missing_vehicle")
                return false
            end

            createTaskCamera(action, ctx)

            if action.lookAt then
                if type(action.lookAt) == "table" then
                    lookAtTaskCamera({ coords = action.lookAt }, ctx)
                elseif type(action.lookAt) == "string" then
                    lookAtTaskCamera({ target = action.lookAt }, ctx)
                end
            end

            return true
        end

        if action.action == "lookAt" then
            if (action.target == "vehicle" or action.target == "engine") and not getVehicleFromContext(ctx, action) then
                handleDenied(ctx.dialog, ped, "missing_vehicle")
                return false
            end

            lookAtTaskCamera(action, ctx)
            return true
        end

        return true
    end

    if action.type == "goTo" then
        local coords = action.coords

        if action.target == "vehicle" then
            local vehicle = getVehicleFromContext(ctx, action)
            if not vehicle then
                handleDenied(ctx.dialog, ped, "missing_vehicle")
                return false
            end
            coords = getCoordsFromOffset(vehicle, action.offset)
        end

        if coords and coords.x and coords.y and coords.z then
            TaskGoToCoordAnyMeans(
                ped,
                coords.x,
                coords.y,
                coords.z,
                action.speed or 1.0,
                action.p4 or 0,
                action.p5 or false,
                action.p6 or 786603,
                action.p7 or 0.0
            )

            if action.waitForArrival or action.arriveDistance then
                waitForArrival(ped, coords, action.arriveDistance or 1.5, action.timeout or 10000)
            end
        end

        return true
    end

    if action.type == "playAnim" then
        if action.dict and action.anim and loadAnimDict(action.dict) then
            TaskPlayAnim(
                ped,
                action.dict,
                action.anim,
                action.blendIn or 8.0,
                action.blendOut or -8.0,
                action.duration or -1,
                action.flag or DialogEnums.AnimationFlag.UPPER_BODY,
                0.0,
                false,
                false,
                false
            )

            if action.blocking and action.duration and action.duration > 0 then
                Citizen.Wait(action.duration)
            end
        end

        return true
    end

    if action.type == "playFacial" then
        local animDict = action.dict or "facials@gen_male@variations@"
        local animName = action.facial or action.anim or action.name

        if animName and loadAnimDict(animDict) then
            PlayFacialAnim(ped, animName, animDict)

            if action.blocking and action.duration and action.duration > 0 then
                Citizen.Wait(action.duration)
                ClearFacialIdleAnim(ped)
            elseif action.duration and action.duration > 0 then
                SetTimeout(action.duration, function()
                    ClearFacialIdleAnim(ped)
                end)
            end
        end

        return true
    end

    if action.type == "attack" then
        local targetPed = resolveTaskTarget(action.target, ctx)
        if action.targetNetId then
            targetPed = NetToPed(action.targetNetId)
        end

        if targetPed and DoesEntityExist(targetPed) then
            TaskCombatPed(ped, targetPed, 0, 16)
        end

        return true
    end

    if action.type == "follow" then
        local targetPed = resolveTaskTarget(action.target, ctx)
        if action.targetNetId then
            targetPed = NetToPed(action.targetNetId)
        end

        if targetPed and DoesEntityExist(targetPed) then
            TaskFollowToOffsetOfEntity(
                ped,
                targetPed,
                action.offsetX or 0.0,
                action.offsetY or 0.0,
                action.offsetZ or 0.0,
                action.speed or 1.0,
                action.timeout or -1,
                action.stoppingRange or 1.0,
                action.persist ~= false
            )
        end

        return true
    end

    if action.type == "wander" then
        TaskWanderStandard(ped, action.wanderRadius or 10.0, action.wanderDuration or 10.0)
        return true
    end

    if action.type == "scenario" then
        if action.name then
            TaskStartScenarioInPlace(
                ped,
                action.name,
                action.scenarioFlags or 0,
                action.playEnterAnim ~= false
            )
        end
        return true
    end

    return true
end

local function runTaskSequence(sequence, ped, ctx)
    if type(sequence) ~= "table" or not ped or not DoesEntityExist(ped) then
        return
    end

    Citizen.CreateThread(function()
        for _, action in ipairs(sequence) do
            if not ped or not DoesEntityExist(ped) then
                break
            end

            local ok = executeTaskAction(action, ped, ctx)
            if ok == false then
                break
            end

            if action.wait and action.wait > 0 then
                Citizen.Wait(action.wait)
            end
        end
    end)
end

local function runTask(taskFn, ctx)
    if type(taskFn) ~= "function" then
        return nil
    end

    local success, result = pcall(taskFn, ctx)
    if not success then
        print('[AdvanceDialog] Error in task:', result)
        return nil
    end

    if result == nil then
        return nil
    end

    local ped = ctx.ped
    local sequence = nil
    local keepDialog = false

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
    elseif type(result) == "number" then
        ped = result
    end

    if not keepDialog and isDialogOpen then
        exports['advance-dialog']:closeDialog()
    end

    if sequence then
        runTaskSequence(sequence, ped, ctx)
    end

    return {
        ped = ped,
        sequence = sequence,
        keepDialog = keepDialog
    }
end

handleDenied = function(dialogData, ped, reason)
    local ctx = buildContext(dialogData, nil, ped)
    ctx.reason = reason or "canInteract"

    TriggerEvent(DialogEnums.EventType.DIALOG_DENIED, ctx)

    if dialogData and dialogData.onDenied then
        if type(dialogData.onDenied) == "function" then
            local success, err = pcall(dialogData.onDenied, ctx)
            if not success then
                print('[AdvanceDialog] Error in onDenied callback:', err)
            end
        elseif type(dialogData.onDenied) == "table" then
            if type(dialogData.onDenied.callback) == "function" then
                local success, err = pcall(dialogData.onDenied.callback, ctx)
                if not success then
                    print('[AdvanceDialog] Error in onDenied callback:', err)
                end
            end

            if dialogData.onDenied.task then
                runTask(dialogData.onDenied.task, ctx)
            end
        end
    end
end

local function isOptionSelectable(option, dialogData, ped)
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
            print('[AdvanceDialog] Error in option.canInteract:', allowed)
            return false
        end

        return allowed == true
    end

    return true
end

local function buildNuiOptions(dialogData, ped)
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

local function canOpenDialog(dialogData, ped)
    if not dialogData then
        return true
    end

    if type(dialogData.canInteract) ~= "function" then
        return true
    end

    local ctx = buildContext(dialogData, nil, ped)
    local success, allowed = pcall(dialogData.canInteract, ctx.playerPed, ctx)

    if not success then
        print('[AdvanceDialog] Error in canInteract:', allowed)
        handleDenied(dialogData, ped, "canInteract")
        return false
    end

    if allowed then
        return true
    end

    handleDenied(dialogData, ped, "canInteract")
    return false
end

RegisterNetEvent('advance-dialog:client:receiveDialog')
AddEventHandler('advance-dialog:client:receiveDialog', function(payload)
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
        exports['advance-dialog']:showDialog(dialog, ped, true)
    else
        print('[AdvanceDialog] Error: Could not fetch dialog from server')
    end

    pendingRequestContext = nil
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        if isDialogOpen then
            DisableControlAction(0, Config.closeKey, true)
            
            if IsDisabledControlJustPressed(0, Config.closeKey) then
                exports['advance-dialog']:closeDialog()
            end
        end
    end
end)

RegisterNUICallback('selectOption', function(data, cb)
    if not activeDialog or not activeDialog.options then
        cb('ok')
        return
    end
    
    local selectedIndex = tonumber(data.index) or data.index
    if selectedIndex == -1 then
        exports['advance-dialog']:closeDialog()
        cb('ok')
        return
    end

    local selectedOption = activeDialog.options[selectedIndex]
    
    if not selectedOption then
        cb('ok')
        return
    end
    
    if Config.enableDebug then
        print('[AdvanceDialog] Option selected:', selectedIndex, selectedOption.label or 'Close')
    end

    local ped = resolvePed(activePed)
    local ctx = buildContext(activeDialog, selectedOption, ped)

    if not isOptionSelectable(selectedOption, activeDialog, ped) then
        ctx.reason = "option_canInteract"
        TriggerEvent(DialogEnums.EventType.DIALOG_DENIED, ctx)
        cb('ok')
        return
    end
    
    if selectedOption.callback then
        local success, err = pcall(selectedOption.callback, ctx)

        if not success then
            print('[AdvanceDialog] Error in callback:', err)
        end
    end

    local taskResult = nil
    if selectedOption.task then
        taskResult = runTask(selectedOption.task, ctx)
        if taskResult and taskResult.ped then
            ctx.ped = taskResult.ped
        end
    end

    local skipNext = taskResult and taskResult.sequence and not taskResult.keepDialog

    if selectedOption.next and not skipNext then
        local nextDialogId = selectedOption.next
        local nextDialog = registeredDialogs[nextDialogId]

        if nextDialog then
            if canOpenDialog(nextDialog, ctx.ped) then
                exports['advance-dialog']:showDialog(nextDialog, ctx.ped, true)
            end
        else
            pendingRequestContext = {
                ped = ctx.ped,
                dialogId = nextDialogId
            }
            TriggerServerEvent('advance-dialog:server:getDialog', nextDialogId)
        end
    elseif selectedOption.close then
        exports['advance-dialog']:closeDialog()
    end
    
    TriggerEvent(DialogEnums.EventType.OPTION_SELECTED, ctx)
    
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

function showDialog(dialogData, ped, isTransition)
    if isDialogOpen and not isTransition then
        return false, "Dialog already open"
    end

    if not dialogData then
        return false, "No dialog data provided"
    end

    if dialogData.id == nil then
        print('[AdvanceDialog] Error: Missing dialog id')
        return false, "Missing dialog id"
    end

    if type(dialogData.id) == "string" and dialogData.id == "" then
        print('[AdvanceDialog] Error: Invalid dialog id')
        return false, "Invalid dialog id"
    end

    if type(dialogData.id) ~= "string" and type(dialogData.id) ~= "number" then
        print('[AdvanceDialog] Error: Invalid dialog id type')
        return false, "Invalid dialog id"
    end

    local resolvedPed = resolvePed(ped)
    if resolvedPed and DoesEntityExist(resolvedPed) then
        activePed = resolvedPed
    end
    if not canOpenDialog(dialogData, resolvedPed) then
        return false, "Dialog canInteract failed"
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
        print('[AdvanceDialog] Dialog opened:', dialogData.id or 'unknown')
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
        print('[AdvanceDialog] Dialog closed')
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
            local idType = type(id)
            local validKey = (idType == "string" and id ~= "") or idType == "number"

            if not validKey then
                print('[AdvanceDialog] Warning: Skipping dialog with invalid id key')
            else
                if dialog.id ~= nil then
                    local dialogIdType = type(dialog.id)
                    local validDialogId = (dialogIdType == "string" and dialog.id ~= "") or dialogIdType == "number"

                    if not validDialogId then
                        print('[AdvanceDialog] Warning: Dialog id invalid, using key:', tostring(id))
                    elseif dialog.id ~= id then
                        print('[AdvanceDialog] Warning: Dialog id mismatch, using key:', tostring(id))
                    end
                end

                dialog.id = id
                registeredDialogs[id] = dialog
            end
        end
    end

    if Config.enableDebug then
        print('[AdvanceDialog] Registered dialogs:', table.count(registeredDialogs))
    end

    return true
end

function setActivePed(ped)
    if ped and DoesEntityExist(ped) then
        activePed = ped
        return true
    end

    activePed = nil
    return false, "Invalid ped"
end

function getActivePed()
    return activePed
end

function registerTaskAction(name, handler)
    if type(name) ~= "string" or name == "" then
        return false, "Invalid action name"
    end

    if type(handler) ~= "function" then
        return false, "Invalid action handler"
    end

    taskActions[name] = handler
    return true
end

local function applyPedComponents(ped, components)
    if type(components) ~= "table" then
        return
    end

    for _, component in ipairs(components) do
        local componentId = component.componentId or component.component
        if componentId ~= nil then
            SetPedComponentVariation(
                ped,
                componentId,
                component.drawableId or component.drawable or 0,
                component.textureId or component.texture or 0,
                component.paletteId or component.palette or 0
            )
        end
    end
end

local function applyPedProps(ped, props)
    if type(props) ~= "table" then
        return
    end

    for _, prop in ipairs(props) do
        local propId = prop.propId or prop.id
        if propId ~= nil then
            local drawable = prop.drawableId or prop.drawable
            if drawable and drawable >= 0 then
                SetPedPropIndex(
                    ped,
                    propId,
                    drawable,
                    prop.textureId or prop.texture or 0,
                    prop.attach ~= false
                )
            else
                ClearPedProp(ped, propId)
            end
        end
    end
end

local function applyPedFaceFeatures(ped, features)
    if type(features) ~= "table" then
        return
    end

    for _, feature in ipairs(features) do
        if feature.index ~= nil and feature.scale ~= nil then
            SetPedFaceFeature(ped, feature.index, feature.scale)
        end
    end
end

local function applyPedAppearance(ped, appearance)
    if type(appearance) ~= "table" then
        return
    end

    applyPedComponents(ped, appearance.components)
    applyPedProps(ped, appearance.props)
    applyPedFaceFeatures(ped, appearance.faceFeatures)
end

local function loadModel(model)
    local modelHash = model
    if type(model) == "string" then
        modelHash = GetHashKey(model)
    end

    if not modelHash or not IsModelInCdimage(modelHash) then
        return nil, "Invalid model"
    end

    RequestModel(modelHash)

    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 100 do
        Citizen.Wait(50)
        timeout = timeout + 1
    end

    if not HasModelLoaded(modelHash) then
        return nil, "Failed to load model"
    end

    return modelHash
end

local function createPed(pedConfig)
    local config = pedConfig or {}
    if not config.model then
        return nil, "Missing model"
    end

    local modelHash, err = loadModel(config.model)
    if not modelHash then
        return nil, err
    end

    local coords = config.coords
    if not coords then
        local playerCoords = GetEntityCoords(PlayerPedId())
        coords = { x = playerCoords.x, y = playerCoords.y, z = playerCoords.z }
    end

    local heading = config.heading or 0.0
    local networked = config.networked == true

    local ped = CreatePed(4, modelHash, coords.x, coords.y, coords.z, heading, networked, false)
    SetModelAsNoLongerNeeded(modelHash)

    if not ped or not DoesEntityExist(ped) then
        return nil, "Failed to create ped"
    end

    SetEntityAsMissionEntity(ped, true, true)

    if config.freeze then
        FreezeEntityPosition(ped, true)
    end

    if config.invincible then
        SetEntityInvincible(ped, true)
    end

    if config.armor then
        SetPedArmour(ped, config.armor)
    end

    if config.relationship then
        local groupHash = config.relationship.hash
        if config.relationship.group then
            AddRelationshipGroup(config.relationship.group)
            groupHash = GetHashKey(config.relationship.group)
        end

        if groupHash then
            SetPedRelationshipGroupHash(ped, groupHash)
        end
    end

    if config.appearance then
        applyPedAppearance(ped, config.appearance)
    end

    if config.props then
        applyPedProps(ped, config.props)
    end

    if config.weapon and config.weapon.name then
        local weaponHash = GetHashKey(config.weapon.name)
        GiveWeaponToPed(ped, weaponHash, config.weapon.ammo or 0, false, true)
    end

    if config.scenario then
        TaskStartScenarioInPlace(ped, config.scenario, config.scenarioFlags or 0, true)
    end

    if config.anim and config.anim.dict and config.anim.name then
        if loadAnimDict(config.anim.dict) then
            TaskPlayAnim(
                ped,
                config.anim.dict,
                config.anim.name,
                config.anim.blendIn or 8.0,
                config.anim.blendOut or -8.0,
                config.anim.duration or -1,
                config.anim.flag or DialogEnums.AnimationFlag.UPPER_BODY,
                0.0,
                false,
                false,
                false
            )
        end
    end

    local netId = nil
    if networked then
        netId = NetworkGetNetworkIdFromEntity(ped)
    end

    return ped, netId
end

function openDialogById(dialogId, ped)
    if not dialogId then
        return false, "Missing dialog id"
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
    TriggerServerEvent('advance-dialog:server:getDialog', dialogId)
    return true
end

function createPedAndOpen(dialogId, pedConfig)
    local ped, netId = createPed(pedConfig)
    if ped then
        activePed = ped
        openDialogById(dialogId, ped)
    end
    return ped, netId
end

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
