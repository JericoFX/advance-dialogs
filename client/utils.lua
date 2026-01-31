--[[
    Utility Functions
    
    Common utility functions used throughout the Advance Dialog system.
]]

---@class MergedMetadata
---@field [string] any

---@class DialogContextLegacy
---@field dialog? table
---@field dialogId? string | number
---@field option? table
---@field ped? number
---@field playerPed number
---@field metadata table
---@field optionMetadata table
---@field mergedMetadata MergedMetadata

---@class TaskTarget
---@field player? boolean
---@field [number] number

-- Cache frequently used natives
local PlayerPedIdCached = PlayerPedId
local DoesEntityExistCached = DoesEntityExist
local GetEntityCoordsCached = GetEntityCoords
local RequestAnimDictCached = RequestAnimDict
local HasAnimDictLoadedCached = HasAnimDictLoaded
local WaitCached = Wait
local GetResourceStateCached = GetResourceState
local GetHashKeyCached = GetHashKey
local IsModelInCdimageCached = IsModelInCdimage
local RequestModelCached = RequestModel
local HasModelLoadedCached = HasModelLoaded
local NetToVehCached = NetToVeh
local GetOffsetFromEntityInWorldCoordsCached = GetOffsetFromEntityInWorldCoords
local GetEntityBoneIndexByNameCached = GetEntityBoneIndexByName
local GetWorldPositionOfEntityBoneCached = GetWorldPositionOfEntityBone

---@param value number
---@param minValue number
---@param maxValue number
---@return number
function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

---@param ped? number
---@return number | nil
function resolvePed(ped)
    if ped and DoesEntityExistCached(ped) then
        return ped
    end
    if activePed and DoesEntityExistCached(activePed) then
        return activePed
    end
    local playerPed = PlayerPedIdCached()
    if playerPed and DoesEntityExistCached(playerPed) then
        return playerPed
    end
    return ped
end

---@param baseTable? table
---@param overrideTable? table
---@return MergedMetadata
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

---@param dialogData? table
---@param option? table
---@param ped? number
---@return DialogContextLegacy
function buildContext(dialogData, option, ped)
    local dialogMetadata = (dialogData and dialogData.metadata) or {}
    local optionMetadata = (option and option.metadata) or {}
    return {
        dialog = dialogData,
        dialogId = dialogData and dialogData.id or nil,
        option = option,
        ped = ped,
        playerPed = PlayerPedIdCached(),
        metadata = dialogMetadata,
        optionMetadata = optionMetadata,
        mergedMetadata = mergeTables(dialogMetadata, optionMetadata)
    }
end

---@param dict string
---@return boolean
function loadAnimDict(dict)
    if not dict then
        return false
    end
    RequestAnimDictCached(dict)
    local timeout = 0
    while not HasAnimDictLoadedCached(dict) and timeout < 100 do
        WaitCached(50)
        timeout = timeout + 1
    end
    return HasAnimDictLoadedCached(dict)
end

---@param resourceName string
---@return boolean
function isResourceStarted(resourceName)
    return GetResourceStateCached(resourceName) == "started"
end

---@param model string | number
---@return number | nil, string?
function loadModel(model)
    local modelHash = model
    if type(model) == "string" then
        modelHash = GetHashKeyCached(model)
    end
    if not modelHash or not IsModelInCdimageCached(modelHash) then
        return nil, "Invalid model"
    end
    RequestModelCached(modelHash)
    local timeout = 0
    while not HasModelLoadedCached(modelHash) and timeout < 100 do
        WaitCached(50)
        timeout = timeout + 1
    end
    if not HasModelLoadedCached(modelHash) then
        return nil, "Failed to load model"
    end
    return modelHash
end

---@param target? TaskTarget
---@param ctx DialogContextLegacy
---@return number | nil
function resolveTaskTarget(target, ctx)
    if not target then
        return nil
    end
    if target == "player" then
        return ctx.playerPed or PlayerPedIdCached()
    end
    if type(target) == "number" then
        return target
    end
    return nil
end

---@param ctx DialogContextLegacy
---@param action? table
---@return number | nil
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
    local vehicle = NetToVehCached(netId)
    if vehicle and DoesEntityExistCached(vehicle) then
        return vehicle
    end
    return nil
end

---@param entity number
---@param offset? {x?: number, y?: number, z?: number}
---@return {x: number, y: number, z: number} | nil
function getCoordsFromOffset(entity, offset)
    if not entity or not DoesEntityExistCached(entity) then
        return nil
    end
    local off = offset or {}
    local coords = GetOffsetFromEntityInWorldCoordsCached(entity, off.x or 0.0, off.y or 0.0, off.z or 0.0)
    return { x = coords.x, y = coords.y, z = coords.z }
end

---@param vehicle number
---@return {x: number, y: number, z: number} | nil
function getEngineCoords(vehicle)
    if not vehicle or not DoesEntityExistCached(vehicle) then
        return nil
    end
    local boneIndex = GetEntityBoneIndexByNameCached(vehicle, "engine")
    if boneIndex == -1 then
        boneIndex = GetEntityBoneIndexByNameCached(vehicle, "bonnet")
    end
    if boneIndex ~= -1 then
        local coords = GetWorldPositionOfEntityBoneCached(vehicle, boneIndex)
        return { x = coords.x, y = coords.y, z = coords.z }
    end
    local coords = GetEntityCoordsCached(vehicle)
    return { x = coords.x, y = coords.y, z = coords.z }
end
