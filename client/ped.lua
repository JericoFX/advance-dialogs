local createdPeds = {}

function applyPedComponents(ped, components)
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

function applyPedProps(ped, props)
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

function applyPedFaceFeatures(ped, features)
    if type(features) ~= "table" then
        return
    end
    for _, feature in ipairs(features) do
        if feature.index ~= nil and feature.scale ~= nil then
            SetPedFaceFeature(ped, feature.index, feature.scale)
        end
    end
end

function applyPedAppearance(ped, appearance)
    if type(appearance) ~= "table" then
        return
    end
    applyPedComponents(ped, appearance.components)
    applyPedProps(ped, appearance.props)
    applyPedFaceFeatures(ped, appearance.faceFeatures)
end

function createPed(pedConfig)
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
    table.insert(createdPeds, ped)
    return ped, netId
end

function getCreatedPeds()
    return createdPeds
end

function clearCreatedPeds()
    for _, ped in ipairs(createdPeds) do
        if ped and DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
    createdPeds = {}
end
