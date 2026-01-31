--[[
    Ped Management System
    
    Handles creation, customization, and cleanup of peds.
]]

---@class PedComponent
---@field componentId? number
---@field component? number
---@field drawableId? number
---@field drawable? number
---@field textureId? number
---@field texture? number
---@field paletteId? number
---@field palette? number

---@class PedProp
---@field propId? number
---@field id? number
---@field drawableId? number
---@field drawable? number
---@field textureId? number
---@field texture? number
---@field attach? boolean

---@class PedFaceFeature
---@field index number
---@field scale number

---@class PedWeapon
---@field name string
---@field ammo? number

---@class PedAnim
---@field dict string
---@field name string
---@field blendIn? number
---@field blendOut? number
---@field duration? number
---@field flag? number

---@class PedRelationship
---@field hash? number
---@field group? string

---@class PedAppearance
---@field components? PedComponent[]
---@field props? PedProp[]
---@field faceFeatures? PedFaceFeature[]

---@class PedConfig
---@field model string | number
---@field coords? {x: number, y: number, z: number}
---@field heading? number
---@field networked? boolean
---@field freeze? boolean
---@field invincible? boolean
---@field armor? number
---@field relationship? PedRelationship
---@field appearance? PedAppearance
---@field props? PedProp[]
---@field weapon? PedWeapon
---@field scenario? string
---@field scenarioFlags? number
---@field anim? PedAnim

-- Cache frequently used natives
local PlayerPedIdCached = PlayerPedId
local DoesEntityExistCached = DoesEntityExist
local GetEntityCoordsCached = GetEntityCoords
local GetHashKeyCached = GetHashKey
local CreatePedCached = CreatePed
local SetModelAsNoLongerNeededCached = SetModelAsNoLongerNeeded
local SetEntityAsMissionEntityCached = SetEntityAsMissionEntity
local FreezeEntityPositionCached = FreezeEntityPosition
local SetEntityInvincibleCached = SetEntityInvincible
local SetPedArmourCached = SetPedArmour
local AddRelationshipGroupCached = AddRelationshipGroup
local SetPedRelationshipGroupHashCached = SetPedRelationshipGroupHash
local SetPedComponentVariationCached = SetPedComponentVariation
local SetPedPropIndexCached = SetPedPropIndex
local ClearPedPropCached = ClearPedProp
local SetPedFaceFeatureCached = SetPedFaceFeature
local GiveWeaponToPedCached = GiveWeaponToPed
local TaskStartScenarioInPlaceCached = TaskStartScenarioInPlace
local TaskPlayAnimCached = TaskPlayAnim
local NetworkGetNetworkIdFromEntityCached = NetworkGetNetworkIdFromEntity
local DeleteEntityCached = DeleteEntity

local createdPeds = {}

---@param ped number
---@param components? PedComponent[]
function applyPedComponents(ped, components)
    if type(components) ~= "table" then
        return
    end
    for _, component in ipairs(components) do
        local componentId = component.componentId or component.component
        if componentId ~= nil then
            SetPedComponentVariationCached(
                ped,
                componentId,
                component.drawableId or component.drawable or 0,
                component.textureId or component.texture or 0,
                component.paletteId or component.palette or 0
            )
        end
    end
end

---@param ped number
---@param props? PedProp[]
function applyPedProps(ped, props)
    if type(props) ~= "table" then
        return
    end
    for _, prop in ipairs(props) do
        local propId = prop.propId or prop.id
        if propId ~= nil then
            local drawable = prop.drawableId or prop.drawable
            if drawable and drawable >= 0 then
                SetPedPropIndexCached(
                    ped,
                    propId,
                    drawable,
                    prop.textureId or prop.texture or 0,
                    prop.attach ~= false
                )
            else
                ClearPedPropCached(ped, propId)
            end
        end
    end
end

---@param ped number
---@param features? PedFaceFeature[]
function applyPedFaceFeatures(ped, features)
    if type(features) ~= "table" then
        return
    end
    for _, feature in ipairs(features) do
        if feature.index ~= nil and feature.scale ~= nil then
            SetPedFaceFeatureCached(ped, feature.index, feature.scale)
        end
    end
end

---@param ped number
---@param appearance? PedAppearance
function applyPedAppearance(ped, appearance)
    if type(appearance) ~= "table" then
        return
    end
    applyPedComponents(ped, appearance.components)
    applyPedProps(ped, appearance.props)
    applyPedFaceFeatures(ped, appearance.faceFeatures)
end

---@param pedConfig PedConfig
---@return number | nil, number | nil, string?
function createPed(pedConfig)
    local config = pedConfig or {}
    if not config.model then
        return nil, nil, "Missing model"
    end
    local modelHash, err = loadModel(config.model)
    if not modelHash then
        return nil, nil, err
    end
    local coords = config.coords
    if not coords then
        local playerCoords = GetEntityCoordsCached(PlayerPedIdCached())
        coords = { x = playerCoords.x, y = playerCoords.y, z = playerCoords.z }
    end
    local heading = config.heading or 0.0
    local networked = config.networked == true
    local ped = CreatePedCached(4, modelHash, coords.x, coords.y, coords.z, heading, networked, false)
    SetModelAsNoLongerNeededCached(modelHash)
    if not ped or not DoesEntityExistCached(ped) then
        return nil, nil, "Failed to create ped"
    end
    SetEntityAsMissionEntityCached(ped, true, true)
    if config.freeze then
        FreezeEntityPositionCached(ped, true)
    end
    if config.invincible then
        SetEntityInvincibleCached(ped, true)
    end
    if config.armor then
        SetPedArmourCached(ped, config.armor)
    end
    if config.relationship then
        local groupHash = config.relationship.hash
        if config.relationship.group then
            AddRelationshipGroupCached(config.relationship.group)
            groupHash = GetHashKeyCached(config.relationship.group)
        end
        if groupHash then
            SetPedRelationshipGroupHashCached(ped, groupHash)
        end
    end
    if config.appearance then
        applyPedAppearance(ped, config.appearance)
    end
    if config.props then
        applyPedProps(ped, config.props)
    end
    if config.weapon and config.weapon.name then
        local weaponHash = GetHashKeyCached(config.weapon.name)
        GiveWeaponToPedCached(ped, weaponHash, config.weapon.ammo or 0, false, true)
    end
    if config.scenario then
        TaskStartScenarioInPlaceCached(ped, config.scenario, config.scenarioFlags or 0, true)
    end
    if config.anim and config.anim.dict and config.anim.name then
        if loadAnimDict(config.anim.dict) then
            TaskPlayAnimCached(
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
        netId = NetworkGetNetworkIdFromEntityCached(ped)
    end
    table.insert(createdPeds, ped)
    return ped, netId
end

---@return number[]
function getCreatedPeds()
    return createdPeds
end

function clearCreatedPeds()
    for _, ped in ipairs(createdPeds) do
        if ped and DoesEntityExistCached(ped) then
            DeleteEntityCached(ped)
        end
    end
    createdPeds = {}
end
