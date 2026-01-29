function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

function resolvePed(ped)
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

function mergeTables(baseTable, overrideTable)
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

function buildContext(dialogData, option, ped)
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

function loadAnimDict(dict)
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

function isResourceStarted(resourceName)
    return GetResourceState(resourceName) == "started"
end

function loadModel(model)
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

function resolveTaskTarget(target, ctx)
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

function getVehicleFromContext(ctx, action)
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

function getCoordsFromOffset(entity, offset)
    if not entity or not DoesEntityExist(entity) then
        return nil
    end
    local off = offset or {}
    local coords = GetOffsetFromEntityInWorldCoords(entity, off.x or 0.0, off.y or 0.0, off.z or 0.0)
    return { x = coords.x, y = coords.y, z = coords.z }
end

function getEngineCoords(vehicle)
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
