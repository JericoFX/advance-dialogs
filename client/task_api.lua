--[[
    Task API V2

    Provides task execution methods for onSelect callbacks.
    All methods are protected with pcall and timeout handling.

    Usage in onSelect:
        onSelect = function(ctx, task)
            task.closeDialog()
            task.goTo(ctx.ped, vehicle, {x=0, y=2, z=0}, {timeout=10000, slide=true})
            task.playAnim("mini@repair", "fixing_a_player", 5000)
        end
]]

---@class GoToOptions
---@field timeout? number Max time to wait in ms (default: 30000)
---@field slide? boolean If true, teleport if timeout reached
---@field arriveDistance? number Distance to consider "arrived" (default: 1.5)

---@class AnimOptions
---@field ped? number Target ped (default: PlayerPedId())
---@field blendIn? number Blend in speed (default: 8.0)
---@field blendOut? number Blend out speed (default: -8.0)
---@field flag? number Animation flag (default: 0)
---@field blocking? boolean Wait for completion

---@class ScenarioOptions
---@field ped? number Target ped (default: PlayerPedId())
---@field flags? number Scenario flags (default: 0)
---@field playEnter? boolean Play enter animation (default: true)

---@class ProgressOptions
---@field useWhileDead? boolean
---@field canCancel? boolean
---@field disable? table

---@class CameraConfig
---@field mode? "static" | "follow" | "track" | "orbit"
---@field target? number | "player" | "ped" | "vehicle" | "engine"
---@field coords? {x: number, y: number, z: number}
---@field offset? {x: number, y: number, z: number}
---@field bone? string
---@field fov? number
---@field radius? number
---@field height? number
---@field speed? number
---@field lerp? boolean
---@field autoDestroy? boolean
---@field fadeTime? number
---@field lookAt? table | string

---@class CameraAPI
---@field create fun(config: CameraConfig): boolean
---@field destroy fun()
---@field lookAt fun(target: any, options?: table): boolean
---@field follow fun(target: any, offset?: table, options?: table): boolean
---@field track fun(coords: table, target: any, options?: table): boolean
---@field orbit fun(target: any, radius?: number, height?: number, speed?: number, options?: table): boolean
---@field static fun(coords: table, lookAtTarget?: any, options?: table): boolean

---@class TaskAPI
---@field closeDialog fun()
---@field showDialog fun(dialogId: string): boolean
---@field goBack fun(): boolean
---@field wait fun(ms: number)
---@field goTo fun(ped: number, target: any, offset?: table, options?: GoToOptions): boolean
---@field goToCoords fun(ped: number, x: number, y: number, z: number, options?: GoToOptions): boolean
---@field getAnimDuration fun(dict: string, anim: string): number
---@field playAnim fun(dict: string, anim: string, duration?: number, options?: AnimOptions): boolean
---@field playScenario fun(scenarioName: string, duration?: number, options?: ScenarioOptions): boolean
---@field progress fun(label: string, duration: number, options?: ProgressOptions): boolean
---@field camera CameraAPI
---@field playFacial fun(animName: string, duration?: number, options?: table): boolean
---@field clearFacial fun(ped?: number)

---@type TaskAPI
TaskAPI = {}

-- Cache frequently used natives
local GetCurrentResourceNameCached = GetCurrentResourceName
local PlayerPedIdCached = PlayerPedId
local DoesEntityExistCached = DoesEntityExist
local GetEntityCoordsCached = GetEntityCoords
local GetGameTimerCached = GetGameTimer
local GetVehiclePedIsInCached = GetVehiclePedIsIn
local TaskGoToCoordAnyMeansCached = TaskGoToCoordAnyMeans
local TaskPlayAnimCached = TaskPlayAnim
local TaskStartScenarioInPlaceCached = TaskStartScenarioInPlace
local SendNUIMessageCached = SendNUIMessage
local SetTimeoutCached = SetTimeout
local PlayFacialAnimCached = PlayFacialAnim
local ClearFacialIdleAnimOverrideCached = ClearFacialIdleAnimOverride
local ClearPedTasksCached = ClearPedTasks
local SetEntityCoordsCached = SetEntityCoords
local WaitCached = Wait

-- ============================================
-- DIALOG OPERATIONS
-- ============================================

function TaskAPI.closeDialog()
    exports[GetCurrentResourceNameCached()]:closeDialog()
end

---@param dialogId string
---@return boolean
function TaskAPI.showDialog(dialogId)
    if not dialogId then return false end

    local entity = getActiveEntity()
    if not entity then
        print(string.format('[%s] Error: No active entity to show dialog', GetCurrentResourceNameCached()))
        return false
    end

    return exports[GetCurrentResourceNameCached()]:openDialog(entity, dialogId)
end

---@return boolean
function TaskAPI.goBack()
    return exports[GetCurrentResourceNameCached()]:goBack()
end

-- ============================================
-- WAIT
-- ============================================

---@param ms number
function TaskAPI.wait(ms)
    if type(ms) ~= "number" or ms <= 0 then return end
    WaitCached(ms)
end

-- ============================================
-- MOVEMENT
-- ============================================

---@param ped number
---@param target any
---@param offset? table
---@param options? GoToOptions
---@return boolean
function TaskAPI.goTo(ped, target, offset, options)
    if not ped or not DoesEntityExistCached(ped) then
        print(string.format('[%s] Error: Invalid ped in goTo', GetCurrentResourceNameCached()))
        return false
    end

    options = options or {}
    local timeout = options.timeout or 30000
    local slide = options.slide or false
    local arriveDistance = options.arriveDistance or 1.5

    -- Resolve target to coordinates
    local targetCoords = nil

    if type(target) == "number" and DoesEntityExistCached(target) then
        -- Entity handle
        local baseCoords = GetEntityCoordsCached(target)
        if offset then
            targetCoords = vector3(
                baseCoords.x + (offset.x or 0),
                baseCoords.y + (offset.y or 0),
                baseCoords.z + (offset.z or 0)
            )
        else
            targetCoords = baseCoords
        end
    elseif type(target) == "vector3" then
        targetCoords = target
    elseif type(target) == "table" and target.x then
        targetCoords = vector3(target.x, target.y, target.z)
    elseif target == "player" then
        local playerPed = PlayerPedIdCached()
        local baseCoords = GetEntityCoordsCached(playerPed)
        if offset then
            targetCoords = vector3(
                baseCoords.x + (offset.x or 0),
                baseCoords.y + (offset.y or 0),
                baseCoords.z + (offset.z or 0)
            )
        else
            targetCoords = baseCoords
        end
    elseif target == "vehicle" then
        local vehicle = GetVehiclePedIsInCached(PlayerPedIdCached(), false)
        if vehicle and DoesEntityExistCached(vehicle) then
            local baseCoords = GetEntityCoordsCached(vehicle)
            if offset then
                targetCoords = vector3(
                    baseCoords.x + (offset.x or 0),
                    baseCoords.y + (offset.y or 0),
                    baseCoords.z + (offset.z or 0)
                )
            else
                targetCoords = baseCoords
            end
        end
    end

    if not targetCoords then
        print(string.format('[%s] Error: Could not resolve target coordinates', GetCurrentResourceNameCached()))
        return false
    end

    -- Start movement
    TaskGoToCoordAnyMeansCached(ped, targetCoords.x, targetCoords.y, targetCoords.z, 1.0, 0, false, 786603, 0.0)

    -- Wait for arrival with timeout
    local startTime = GetGameTimerCached()
    while DoesEntityExistCached(ped) do
        local pedCoords = GetEntityCoordsCached(ped)
        local dist = #(pedCoords - targetCoords)

        if dist <= arriveDistance then
            return true
        end

        if (GetGameTimerCached() - startTime) >= timeout then
            if slide then
                -- Teleport to destination
                SetEntityCoordsCached(ped, targetCoords.x, targetCoords.y, targetCoords.z, false, false, false, false)
            end
            return false
        end

        WaitCached(100)
    end

    return false
end

---@param ped number
---@param x number
---@param y number
---@param z number
---@param options? GoToOptions
---@return boolean
function TaskAPI.goToCoords(ped, x, y, z, options)
    return TaskAPI.goTo(ped, vector3(x, y, z), nil, options)
end

-- ============================================
-- ANIMATIONS
-- ============================================

---@param dict string
---@param anim string
---@return number
function TaskAPI.getAnimDuration(dict, anim)
    if not dict or not anim then return 1.0 end

    -- Try to get native duration
    if HasAnimDictLoaded(dict) or loadAnimDict(dict) then
        -- GetAnimDuration returns time in seconds
        local duration = GetAnimDuration(dict, anim)
        if duration and duration > 0 then
            return duration
        end
    end

    -- Default fallback
    return 1.0
end

---@param dict string
---@param anim string
---@param duration? number
---@param options? AnimOptions
---@return boolean
function TaskAPI.playAnim(dict, anim, duration, options)
    if not dict or not anim then return false end
    options = options or {}

    local ped = options.ped or PlayerPedIdCached()
    if not DoesEntityExistCached(ped) then return false end

    if not loadAnimDict(dict) then
        print(string.format('[%s] Error: Could not load anim dict %s', GetCurrentResourceNameCached(), dict))
        return false
    end

    local blendIn = options.blendIn or 8.0
    local blendOut = options.blendOut or -8.0
    local flag = options.flag or 0

    TaskPlayAnimCached(ped, dict, anim, blendIn, blendOut, duration or -1, flag, 0.0, false, false, false)

    -- If blocking, wait for duration
    if options.blocking and duration and duration > 0 then
        WaitCached(duration)
    end

    return true
end

---@param scenarioName string
---@param duration? number
---@param options? ScenarioOptions
---@return boolean
function TaskAPI.playScenario(scenarioName, duration, options)
    if not scenarioName then return false end
    options = options or {}

    local ped = options.ped or PlayerPedIdCached()
    if not DoesEntityExistCached(ped) then return false end

    local flags = options.flags or 0
    local playEnter = options.playEnter ~= false

    TaskStartScenarioInPlaceCached(ped, scenarioName, flags, playEnter)

    if duration and duration > 0 then
        WaitCached(duration)
        ClearPedTasksCached(ped)
    end

    return true
end

-- ============================================
-- PROGRESS BAR
-- ============================================

---@param label string
---@param duration number
---@param options? ProgressOptions
---@return boolean
function TaskAPI.progress(label, duration, options)
    if not duration or duration <= 0 then return false end
    options = options or {}

    local provider = string.lower(Config.progressProvider or "none")
    local handled = false

    if provider == "ox_lib" and isResourceStarted("ox_lib") then
        local ok = pcall(function()
            if exports.ox_lib and exports.ox_lib.progressBar then
                exports.ox_lib:progressBar({
                    duration = duration,
                    label = label or "Working...",
                    useWhileDead = true,
                    canCancel = false,
                    disable = { move = true, car = true, combat = true }
                })
            elseif lib and lib.progressBar then
                lib.progressBar({
                    duration = duration,
                    label = label or "Working...",
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
                name = GetCurrentResourceNameCached(),
                duration = duration,
                label = label or "Working...",
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
                name = GetCurrentResourceNameCached(),
                duration = duration,
                label = label or "Working...",
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
        -- Use native NUI progress
        SendNUIMessageCached({
            action = 'progressStart',
            data = {
                label = label or "Working...",
                duration = duration
            }
        })
        WaitCached(duration)
        SendNUIMessageCached({ action = 'progressEnd' })
    else
        WaitCached(duration)
    end

    return true
end

-- ============================================
-- CAMERA (Enhanced)
-- ============================================

---@type CameraAPI
TaskAPI.camera = {}

---@param config CameraConfig
---@return boolean
function TaskAPI.camera.create(config)
    if not config then return false end
    createTaskCamera(config, {})
    return true
end

function TaskAPI.camera.destroy()
    destroyTaskCamera()
end

---@param target any
---@param options? table
---@return boolean
function TaskAPI.camera.lookAt(target, options)
    options = options or {}

    if type(target) == "table" and target.x then
        -- Coordinates
        lookAtTaskCamera({ coords = target }, {})
    elseif type(target) == "string" then
        -- Named target
        lookAtTaskCamera({ target = target, bone = options.bone }, {})
    elseif type(target) == "number" and DoesEntityExistCached(target) then
        -- Entity handle
        lookAtTaskCamera({ target = "custom", customEntity = target, bone = options.bone }, {})
    end

    return true
end

---@param target any
---@param offset? table
---@param options? table
---@return boolean
function TaskAPI.camera.follow(target, offset, options)
    options = options or {}
    return TaskAPI.camera.create({
        mode = "follow",
        target = target,
        offset = offset or { x = 2.0, y = -1.5, z = 1.5 },
        fov = options.fov or 45,
        bone = options.bone
    })
end

---@param coords table
---@param target any
---@param options? table
---@return boolean
function TaskAPI.camera.track(coords, target, options)
    options = options or {}
    return TaskAPI.camera.create({
        mode = "track",
        coords = coords,
        target = target,
        fov = options.fov or 45,
        bone = options.bone
    })
end

---@param target any
---@param radius? number
---@param height? number
---@param speed? number
---@param options? table
---@return boolean
function TaskAPI.camera.orbit(target, radius, height, speed, options)
    options = options or {}
    return TaskAPI.camera.create({
        mode = "orbit",
        target = target,
        radius = radius or 3.5,
        height = height or 0.8,
        speed = speed or 1.0,
        fov = options.fov or 55
    })
end

---@param coords table
---@param lookAtTarget? any
---@param options? table
---@return boolean
function TaskAPI.camera.static(coords, lookAtTarget, options)
    options = options or {}
    return TaskAPI.camera.create({
        mode = "static",
        coords = coords,
        lookAt = lookAtTarget,
        fov = options.fov or 45
    })
end

-- ============================================
-- FACIAL ANIMATIONS (Enhanced with Presets)
-- ============================================

---@param animName string
---@param duration? number
---@param options? table
---@return boolean
function TaskAPI.playFacial(animName, duration, options)
    if not animName then return false end
    options = options or {}

    local ped = options.ped or PlayerPedIdCached()
    if not DoesEntityExistCached(ped) then return false end

    -- Preset facial animations
    local presets = {
        -- Moods
        ["happy"] = { dict = "facials@gen_male@variations@happy", anim = "mood_happy" },
        ["angry"] = { dict = "facials@gen_male@variations@angry", anim = "mood_angry" },
        ["sad"] = { dict = "facials@gen_male@variations@sad", anim = "mood_sad" },
        ["surprised"] = { dict = "facials@gen_male@variations@surprised", anim = "mood_surprised" },
        ["aiming"] = { dict = "facials@gen_male@variations@aiming", anim = "mood_aiming" },
        ["injured"] = { dict = "facials@gen_male@variations@injured", anim = "mood_injured" },
        ["concentrated"] = { dict = "facials@gen_male@variations@concentrated", anim = "mood_concentrated" },
        ["normal"] = { dict = "facials@gen_male@base", anim = "mood_normal" },

        -- Specific reactions
        ["shocked"] = { dict = "facials@gen_male@variations@shocked", anim = "shocked" },
        ["sleeping"] = { dict = "sleeping@gen_male", anim = "sleeping" },
        ["dead"] = { dict = "facials@gen_male@variations@dead", anim = "dead" },
        ["knockout"] = { dict = "facials@gen_male@variations@knockout", anim = "knockout" },

        -- Pain
        ["pain_1"] = { dict = "facials@gen_male@variations@pain", anim = "pain_1" },
        ["pain_2"] = { dict = "facials@gen_male@variations@pain", anim = "pain_2" },
        ["pain_3"] = { dict = "facials@gen_male@variations@pain", anim = "pain_3" },

        -- Eyes
        ["blink"] = { dict = "facials@gen_male@variations@blink", anim = "blink" },
        ["blink_long"] = { dict = "facials@gen_male@variations@blink", anim = "blink_long" },
        ["wink_left"] = { dict = "facials@gen_male@variations@blink", anim = "wink_left" },
        ["wink_right"] = { dict = "facials@gen_male@variations@blink", anim = "wink_right" },
    }

    -- Use preset or custom
    local preset = presets[animName]
    local dict = options.dict or (preset and preset.dict) or "facials@gen_male@variations@"
    local anim = (preset and preset.anim) or animName

    if not loadAnimDict(dict) then
        print(string.format('[%s] Error: Could not load facial dict %s', GetCurrentResourceNameCached(), dict))
        return false
    end

    PlayFacialAnimCached(ped, anim, dict)

    if duration and duration > 0 then
        if options.blocking then
            WaitCached(duration)
            ClearFacialIdleAnimOverrideCached(ped)
        else
            SetTimeoutCached(duration, function()
                if DoesEntityExistCached(ped) then
                    ClearFacialIdleAnimOverrideCached(ped)
                end
            end)
        end
    end

    return true
end

---@param ped? number
function TaskAPI.clearFacial(ped)
    ped = ped or PlayerPedIdCached()
    if DoesEntityExistCached(ped) then
        ClearFacialIdleAnimOverrideCached(ped)
    end
end

-- ============================================
-- ENHANCED GO TO METHODS (With Bone Support)
-- ============================================

---@param movingPed number
---@param targetVehicle number
---@param bone? string Bone name (e.g., "bonnet", "boot", "door_dside_f")
---@param offset? {x: number, y: number, z: number}
---@param options? GoToOptions
---@return boolean
function TaskAPI.goToVehicle(movingPed, targetVehicle, bone, offset, options)
    if not movingPed or not DoesEntityExistCached(movingPed) then
        print(string.format('[%s] Error: Invalid movingPed in goToVehicle', GetCurrentResourceNameCached()))
        return false
    end
    
    if not targetVehicle or not DoesEntityExistCached(targetVehicle) then
        print(string.format('[%s] Error: Invalid targetVehicle in goToVehicle', GetCurrentResourceNameCached()))
        return false
    end
    
    -- Calculate target coordinates
    local targetCoords = nil
    
    if bone and bone ~= "" then
        local boneIndex = GetEntityBoneIndexByName(targetVehicle, bone)
        if boneIndex ~= -1 then
            targetCoords = GetWorldPositionOfEntityBone(targetVehicle, boneIndex)
        else
            -- Fallback to center
            targetCoords = GetEntityCoordsCached(targetVehicle)
        end
    else
        targetCoords = GetEntityCoordsCached(targetVehicle)
    end
    
    -- Apply offset
    if offset then
        targetCoords = vector3(
            targetCoords.x + (offset.x or 0),
            targetCoords.y + (offset.y or 0),
            targetCoords.z + (offset.z or 0)
        )
    end
    
    -- Move to calculated position
    return TaskAPI.goToCoords(movingPed, targetCoords.x, targetCoords.y, targetCoords.z, options)
end

---@param movingPed number
---@param targetPed number
---@param bone? string Bone name (e.g., "head", "spine3", "hand_r")
---@param offset? {x: number, y: number, z: number}
---@param options? GoToOptions
---@return boolean
function TaskAPI.goToPed(movingPed, targetPed, bone, offset, options)
    if not movingPed or not DoesEntityExistCached(movingPed) then
        print(string.format('[%s] Error: Invalid movingPed in goToPed', GetCurrentResourceNameCached()))
        return false
    end
    
    if not targetPed or not DoesEntityExistCached(targetPed) then
        print(string.format('[%s] Error: Invalid targetPed in goToPed', GetCurrentResourceNameCached()))
        return false
    end
    
    -- Calculate target coordinates
    local targetCoords = nil
    
    if bone and bone ~= "" then
        local boneIndex = GetEntityBoneIndexByName(targetPed, bone)
        if boneIndex ~= -1 then
            targetCoords = GetWorldPositionOfEntityBone(targetPed, boneIndex)
        else
            -- Fallback to center
            targetCoords = GetEntityCoordsCached(targetPed)
        end
    else
        targetCoords = GetEntityCoordsCached(targetPed)
    end
    
    -- Apply offset
    if offset then
        targetCoords = vector3(
            targetCoords.x + (offset.x or 0),
            targetCoords.y + (offset.y or 0),
            targetCoords.z + (offset.z or 0)
        )
    end
    
    -- Move to calculated position
    return TaskAPI.goToCoords(movingPed, targetCoords.x, targetCoords.y, targetCoords.z, options)
end

-- ============================================
-- VEHICLE HELPERS
-- ============================================

TaskAPI.vehicle = {}

---@param radius? number Search radius (default: 50.0)
---@param coords? vector3 | {x: number, y: number, z: number} Search center (default: player position)
---@return number | nil
function TaskAPI.vehicle.getClosest(radius, coords)
    radius = radius or 50.0
    coords = coords or GetEntityCoordsCached(PlayerPedIdCached())
    
    local vehicles = GetGamePool('CVehicle')
    local closest = nil
    local closestDist = radius
    
    for _, veh in ipairs(vehicles) do
        local dist = #(GetEntityCoordsCached(veh) - coords)
        if dist <= closestDist then
            closest = veh
            closestDist = dist
        end
    end
    
    return closest
end

---@param model string | number Model name or hash
---@param radius? number Search radius (default: 50.0)
---@param coords? vector3 | {x: number, y: number, z: number} Search center (default: player position)
---@return number | nil
function TaskAPI.vehicle.getByModel(model, radius, coords)
    radius = radius or 50.0
    coords = coords or GetEntityCoordsCached(PlayerPedIdCached())
    
    local modelHash = type(model) == "string" and GetHashKey(model) or model
    local vehicles = GetGamePool('CVehicle')
    local closest = nil
    local closestDist = radius
    
    for _, veh in ipairs(vehicles) do
        if GetEntityModel(veh) == modelHash then
            local dist = #(GetEntityCoordsCached(veh) - coords)
            if dist <= closestDist then
                closest = veh
                closestDist = dist
            end
        end
    end
    
    return closest
end

---@param plate string License plate
---@return number | nil
function TaskAPI.vehicle.getByPlate(plate)
    local vehicles = GetGamePool('CVehicle')
    
    for _, veh in ipairs(vehicles) do
        local vehPlate = GetVehicleNumberPlateText(veh)
        if vehPlate and string.lower(vehPlate) == string.lower(plate) then
            return veh
        end
    end
    
    return nil
end

---@param ped? number Ped to check from (default: PlayerPedId())
---@param maxDist? number Max distance (default: 5.0)
---@return number | nil
function TaskAPI.vehicle.getInFront(ped, maxDist)
    ped = ped or PlayerPedIdCached()
    maxDist = maxDist or 5.0
    
    local coords = GetEntityCoordsCached(ped)
    local forward = GetEntityForwardVector(ped)
    local targetCoords = coords + forward * maxDist
    
    local vehicles = GetGamePool('CVehicle')
    local closest = nil
    local closestDist = maxDist
    
    for _, veh in ipairs(vehicles) do
        local vehCoords = GetEntityCoordsCached(veh)
        -- Check if vehicle is roughly in front
        local distToLine = #(vehCoords - targetCoords)
        if distToLine <= closestDist then
            -- Check if actually in front (dot product)
            local toVeh = (vehCoords - coords)
            toVeh = toVeh / #(toVeh)
            local dot = forward.x * toVeh.x + forward.y * toVeh.y + forward.z * toVeh.z
            
            if dot > 0.7 then -- Within ~45 degrees
                closest = veh
                closestDist = distToLine
            end
        end
    end
    
    return closest
end

-- ============================================
-- PED HELPERS
-- ============================================

TaskAPI.ped = {}

---@param radius? number Search radius (default: 50.0)
---@param coords? vector3 | {x: number, y: number, z: number} Search center (default: player position)
---@param includePlayer? boolean Include player ped (default: false)
---@return number | nil
function TaskAPI.ped.getClosest(radius, coords, includePlayer)
    radius = radius or 50.0
    coords = coords or GetEntityCoordsCached(PlayerPedIdCached())
    local playerPed = PlayerPedIdCached()
    
    local peds = GetGamePool('CPed')
    local closest = nil
    local closestDist = radius
    
    for _, ped in ipairs(peds) do
        if ped ~= playerPed or includePlayer then
            local dist = #(GetEntityCoordsCached(ped) - coords)
            if dist <= closestDist and not IsPedAPlayer(ped) then
                closest = ped
                closestDist = dist
            end
        end
    end
    
    return closest
end

---@param model string | number Model name or hash
---@param radius? number Search radius (default: 50.0)
---@param coords? vector3 | {x: number, y: number, z: number} Search center (default: player position)
---@return number | nil
function TaskAPI.ped.getByModel(model, radius, coords)
    radius = radius or 50.0
    coords = coords or GetEntityCoordsCached(PlayerPedIdCached())
    
    local modelHash = type(model) == "string" and GetHashKey(model) or model
    local peds = GetGamePool('CPed')
    local closest = nil
    local closestDist = radius
    
    for _, ped in ipairs(peds) do
        if GetEntityModel(ped) == modelHash then
            local dist = #(GetEntityCoordsCached(ped) - coords)
            if dist <= closestDist and not IsPedAPlayer(ped) then
                closest = ped
                closestDist = dist
            end
        end
    end
    
    return closest
end

---@param fromPed? number Ped to check from (default: PlayerPedId())
---@param maxDist? number Max distance (default: 5.0)
---@return number | nil
function TaskAPI.ped.getInFront(fromPed, maxDist)
    fromPed = fromPed or PlayerPedIdCached()
    maxDist = maxDist or 5.0
    
    local coords = GetEntityCoordsCached(fromPed)
    local forward = GetEntityForwardVector(fromPed)
    local targetCoords = coords + forward * maxDist
    
    local peds = GetGamePool('CPed')
    local closest = nil
    local closestDist = maxDist
    
    for _, ped in ipairs(peds) do
        if ped ~= fromPed and not IsPedAPlayer(ped) then
            local pedCoords = GetEntityCoordsCached(ped)
            local distToLine = #(pedCoords - targetCoords)
            
            if distToLine <= closestDist then
                -- Check if actually in front
                local toPed = (pedCoords - coords)
                toPed = toPed / #(toPed)
                local dot = forward.x * toPed.x + forward.y * toPed.y + forward.z * toPed.z
                
                if dot > 0.7 then -- Within ~45 degrees
                    closest = ped
                    closestDist = distToLine
                end
            end
        end
    end
    
    return closest
end

---@param ped number
---@return boolean
function TaskAPI.ped.isDead(ped)
    if not ped or not DoesEntityExistCached(ped) then return false end
    return IsPedDeadOrDying(ped, true)
end

---@param ped number
---@return boolean
function TaskAPI.ped.isInVehicle(ped)
    if not ped or not DoesEntityExistCached(ped) then return false end
    return IsPedInAnyVehicle(ped, false)
end

---@param ped number
---@param target vector3 | {x: number, y: number, z: number} | number Entity handle or coords
---@return number
function TaskAPI.ped.getDistanceTo(ped, target)
    if not ped or not DoesEntityExistCached(ped) then return 999999.0 end
    
    local pedCoords = GetEntityCoordsCached(ped)
    local targetCoords
    
    if type(target) == "number" then
        targetCoords = GetEntityCoordsCached(target)
    elseif type(target) == "table" then
        targetCoords = vector3(target.x, target.y, target.z)
    elseif type(target) == "vector3" then
        targetCoords = target
    else
        return 999999.0
    end
    
    return #(pedCoords - targetCoords)
end

---@param radius? number Search radius (default: 50.0)
---@param coords? vector3 | {x: number, y: number, z: number} Search center (default: player position)
---@param includePlayer? boolean Include player ped (default: false)
---@return number[]
function TaskAPI.ped.getInRange(radius, coords, includePlayer)
    radius = radius or 50.0
    coords = coords or GetEntityCoordsCached(PlayerPedIdCached())
    local playerPed = PlayerPedIdCached()
    
    local peds = GetGamePool('CPed')
    local results = {}
    
    for _, ped in ipairs(peds) do
        if ped ~= playerPed or includePlayer then
            local dist = #(GetEntityCoordsCached(ped) - coords)
            if dist <= radius and not IsPedAPlayer(ped) then
                table.insert(results, ped)
            end
        end
    end
    
    return results
end

-- ============================================
-- PLAYER HELPERS
-- ============================================

TaskAPI.player = {}

---@return number | nil
function TaskAPI.player.getVehicle()
    local veh = GetVehiclePedIsIn(PlayerPedIdCached(), false)
    return veh ~= 0 and veh or nil
end

---@return number
function TaskAPI.player.getPed()
    return PlayerPedIdCached()
end

---@return vector3
function TaskAPI.player.getCoords()
    return GetEntityCoordsCached(PlayerPedIdCached())
end

---@return boolean
function TaskAPI.player.isInVehicle()
    return IsPedInAnyVehicle(PlayerPedIdCached(), false)
end

---@return boolean
function TaskAPI.player.isOnFoot()
    return not IsPedInAnyVehicle(PlayerPedIdCached(), false)
end

---@param target vector3 | {x: number, y: number, z: number} | number Entity handle or coords
---@return number
function TaskAPI.player.getDistanceTo(target)
    return TaskAPI.ped.getDistanceTo(PlayerPedIdCached(), target)
end

-- ============================================
-- ENTITY HELPERS
-- ============================================

TaskAPI.entity = {}

---@param radius? number Search radius (default: 50.0)
---@param coords? vector3 | {x: number, y: number, z: number} Search center (default: player position)
---@param filter? "vehicle" | "ped" | "object" | nil Entity type filter
---@return number | nil
function TaskAPI.entity.getClosest(radius, coords, filter)
    radius = radius or 50.0
    coords = coords or GetEntityCoordsCached(PlayerPedIdCached())
    
    local pool = nil
    if filter == "vehicle" then
        pool = GetGamePool('CVehicle')
    elseif filter == "ped" then
        pool = GetGamePool('CPed')
    elseif filter == "object" then
        pool = GetGamePool('CObject')
    else
        -- Search all types
        local all = {}
        for _, v in ipairs(GetGamePool('CVehicle')) do table.insert(all, v) end
        for _, v in ipairs(GetGamePool('CPed')) do table.insert(all, v) end
        for _, v in ipairs(GetGamePool('CObject')) do table.insert(all, v) end
        pool = all
    end
    
    local closest = nil
    local closestDist = radius
    
    for _, entity in ipairs(pool) do
        if entity ~= PlayerPedIdCached() then
            local dist = #(GetEntityCoordsCached(entity) - coords)
            if dist <= closestDist then
                closest = entity
                closestDist = dist
            end
        end
    end
    
    return closest
end

---@param entity number
---@return boolean
function TaskAPI.entity.isValid(entity)
    return entity and DoesEntityExistCached(entity)
end

---@param entity number
---@param radius number
---@param coords? vector3 | {x: number, y: number, z: number} Check center (default: player position)
---@return boolean
function TaskAPI.entity.isInRange(entity, radius, coords)
    if not TaskAPI.entity.isValid(entity) then return false end
    
    radius = radius or 50.0
    coords = coords or GetEntityCoordsCached(PlayerPedIdCached())
    
    local entityCoords = GetEntityCoordsCached(entity)
    return #(entityCoords - coords) <= radius
end

---@param entity number
---@param target vector3 | {x: number, y: number, z: number} | number Entity handle or coords
---@return number
function TaskAPI.entity.getDistance(entity, target)
    return TaskAPI.ped.getDistanceTo(entity, target)
end

-- ============================================
-- CAMERA HELPERS
-- ============================================

function TaskAPI.camera.lookAtPed(ped)
    if not ped or not DoesEntityExistCached(ped) then return false end
    TaskAPI.camera.lookAt(ped, {bone = "head"})
    return true
end

function TaskAPI.camera.lookAtVehicle(veh)
    if not veh or not DoesEntityExistCached(veh) then return false end
    TaskAPI.camera.lookAt(veh)
    return true
end

function TaskAPI.camera.lookAtPlayer()
    return TaskAPI.camera.lookAtPed(PlayerPedIdCached())
end

-- ============================================
-- SEARCH HELPERS
-- ============================================

TaskAPI.search = {}

---@param model string | number Model name or hash
---@param radius? number Search radius (default: 100.0)
---@param coords? vector3 | {x: number, y: number, z: number} Search center (default: player position)
---@return number[]
function TaskAPI.search.vehiclesByModel(model, radius, coords)
    radius = radius or 100.0
    coords = coords or GetEntityCoordsCached(PlayerPedIdCached())
    
    local modelHash = type(model) == "string" and GetHashKey(model) or model
    local vehicles = GetGamePool('CVehicle')
    local results = {}
    
    for _, veh in ipairs(vehicles) do
        if GetEntityModel(veh) == modelHash then
            local dist = #(GetEntityCoordsCached(veh) - coords)
            if dist <= radius then
                table.insert(results, veh)
            end
        end
    end
    
    return results
end

---@param model string | number Model name or hash
---@param radius? number Search radius (default: 100.0)
---@param coords? vector3 | {x: number, y: number, z: number} Search center (default: player position)
---@return number[]
function TaskAPI.search.pedsByModel(model, radius, coords)
    radius = radius or 100.0
    coords = coords or GetEntityCoordsCached(PlayerPedIdCached())
    
    local modelHash = type(model) == "string" and GetHashKey(model) or model
    local peds = GetGamePool('CPed')
    local results = {}
    
    for _, ped in ipairs(peds) do
        if GetEntityModel(ped) == modelHash and not IsPedAPlayer(ped) then
            local dist = #(GetEntityCoordsCached(ped) - coords)
            if dist <= radius then
                table.insert(results, ped)
            end
        end
    end
    
    return results
end

---@param radius? number Search radius (default: 100.0)
---@param coords? vector3 | {x: number, y: number, z: number} Search center (default: player position)
---@return number[]
function TaskAPI.search.vehiclesInRange(radius, coords)
    radius = radius or 100.0
    coords = coords or GetEntityCoordsCached(PlayerPedIdCached())
    
    local vehicles = GetGamePool('CVehicle')
    local results = {}
    
    for _, veh in ipairs(vehicles) do
        local dist = #(GetEntityCoordsCached(veh) - coords)
        if dist <= radius then
            table.insert(results, veh)
        end
    end
    
    return results
end

---@param radius? number Search radius (default: 100.0)
---@param coords? vector3 | {x: number, y: number, z: number} Search center (default: player position)
---@param includePlayer? boolean Include player ped (default: false)
---@return number[]
function TaskAPI.search.pedsInRange(radius, coords, includePlayer)
    return TaskAPI.ped.getInRange(radius, coords, includePlayer)
end

-- ============================================
-- SAFE EXECUTION WRAPPER
-- ============================================

---@param onSelect fun(ctx: DialogContext, task: TaskAPI)
---@param ctx DialogContext
---@param onError? fun(ctx: DialogContext, error: string)
---@return boolean
function ExecuteOnSelectSafely(onSelect, ctx, onError)
    if type(onSelect) ~= "function" then return false end

    CreateThread(function()
        local startTime = GetGameTimerCached()
        local timeout = Config.taskTimeout or 30000

        local success, err = pcall(function()
            onSelect(ctx, TaskAPI)

            -- Check timeout
            if (GetGameTimerCached() - startTime) >= timeout then
                error("Task execution timeout (>" .. timeout .. "ms)")
            end
        end)

        if not success then
            print(string.format('[%s] onSelect ERROR: %s', GetCurrentResourceNameCached(), tostring(err)))

            -- Call error handler if provided
            if onError and type(onError) == "function" then
                pcall(onError, ctx, err)
            end

            -- Recovery: go back or close
            local history = getHistory()
            if #history > 1 then
                TaskAPI.goBack()
            else
                TaskAPI.closeDialog()
            end
        end
    end)

    return true
end

-- ============================================
-- DATA PERSISTENCE (Client-Server Communication)
-- ============================================

TaskAPI.data = {}

---@param key string
---@param value any
---@param callback? fun(success: boolean)
function TaskAPI.data.set(key, value, callback)
    TriggerServerEvent('advance-dialog:data:set', key, value)
    if callback then
        -- Server responds with success status
        RegisterNetEvent('advance-dialog:data:set:response', function(success)
            callback(success)
        end)
    end
end

---@param key string
---@param defaultValue any
---@param callback fun(value: any)
function TaskAPI.data.get(key, defaultValue, callback)
    TriggerServerEvent('advance-dialog:data:get', key, defaultValue)
    RegisterNetEvent('advance-dialog:data:get:response', function(value)
        callback(value)
    end)
end

---@param key string
---@param defaultValue any
---@return any
function TaskAPI.data.getSync(key, defaultValue)
    local result = nil
    local waiting = true
    
    TaskAPI.data.get(key, defaultValue, function(value)
        result = value
        waiting = false
    end)
    
    while waiting do
        Wait(0)
    end
    
    return result
end

---@param key string
---@param callback? fun(success: boolean)
function TaskAPI.data.remove(key, callback)
    TriggerServerEvent('advance-dialog:data:remove', key)
    if callback then
        RegisterNetEvent('advance-dialog:data:remove:response', function(success)
            callback(success)
        end)
    end
end

---@param callback? fun(success: boolean)
function TaskAPI.data.clear(callback)
    TriggerServerEvent('advance-dialog:data:clear')
    if callback then
        RegisterNetEvent('advance-dialog:data:clear:response', function(success)
            callback(success)
        end)
    end
end

---@param dialogId string
function TaskAPI.data.markCompleted(dialogId)
    TaskAPI.data.set("dialog_completed_" .. dialogId, true)
end

---@param dialogId string
---@param callback fun(completed: boolean)
function TaskAPI.data.isCompleted(dialogId, callback)
    TaskAPI.data.get("dialog_completed_" .. dialogId, false, function(value)
        callback(value == true)
    end)
end

-- ============================================
-- EXPORTS
-- ============================================

exports('TaskAPI', function() return TaskAPI end)
exports('ExecuteOnSelectSafely', ExecuteOnSelectSafely)
