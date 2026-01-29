--[[
    Camera System Module
    
    Provides dynamic camera functionality with three modes:
    - static: Camera is placed at fixed position (original behavior)
    - follow: Camera moves with target, maintaining relative offset
    - track: Camera stays at fixed position but points at moving target
    - orbit: Camera rotates around target in a circle
    
    Features:
    - Smooth movement with configurable lerp factor
    - Support for specific bone targeting (e.g., "wheel_lf", "engine")
    - Auto-destroy on sequence completion
    - Configurable via Config table
]]

local activeTaskCamera = nil
local activeCameraThread = nil
local cameraConfig = nil
local cameraTargetEntity = nil
local cameraOrbitAngle = 0
local lastCameraPosition = nil

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

--[[
    Linear interpolation between two values
    @param current: Current value
    @param target: Target value
    @param factor: Interpolation factor (0.0-1.0)
    @return: Interpolated value
]]
local function lerp(current, target, factor)
    return current + (target - current) * factor
end

--[[
    Linear interpolation for 3D coordinates
    @param from: {x, y, z} current position
    @param to: {x, y, z} target position
    @param factor: Interpolation factor
    @return: {x, y, z} interpolated position
]]
local function lerpCoords(from, to, factor)
    return {
        x = lerp(from.x, to.x, factor),
        y = lerp(from.y, to.y, factor),
        z = lerp(from.z, to.z, factor)
    }
end

--[[
    Resolve value - if it's a function, call it with ctx, otherwise return value
    @param value: Value or function(ctx)
    @param ctx: Context object
    @return: Resolved value
]]
local function resolveValue(value, ctx)
    if type(value) == "function" then
        return value(ctx)
    end
    return value
end

--[[
    Resolve camera target entity and optionally specific bone
    @param target: Target type string ("ped", "player", "vehicle", "engine")
    @param bone: Optional bone name string
    @param ctx: Context object
    @return: Entity handle, or nil if not found
]]
local function resolveCameraTarget(target, bone, ctx)
    local targetEntity = nil
    
    -- Resolve base entity
    if target == "ped" then
        targetEntity = ctx.ped
    elseif target == "player" then
        targetEntity = ctx.playerPed
    elseif target == "vehicle" or target == "engine" then
        targetEntity = getVehicleFromContext(ctx, {target = target})
    end
    
    return targetEntity
end

--[[
    Get world coordinates of a specific bone on an entity
    @param entity: Entity handle
    @param boneName: Name of the bone
    @return: {x, y, z} world coordinates, or nil if bone not found
]]
local function getBoneWorldCoords(entity, boneName)
    if not entity or not DoesEntityExist(entity) or not boneName then
        return nil
    end
    
    local boneIndex = GetEntityBoneIndexByName(entity, boneName)
    if boneIndex == -1 then
        return nil
    end
    
    local coords = GetWorldPositionOfEntityBone(entity, boneIndex)
    return {x = coords.x, y = coords.y, z = coords.z}
end

-- ============================================
-- CAMERA TRACKING SYSTEM
-- ============================================

--[[
    Start camera tracking thread based on mode
    @param config: Camera configuration table
    @param ctx: Context object
]]
local function startCameraTracking(config, ctx)
    -- Stop any existing tracking
    stopCameraTracking()
    
    -- Initialize tracking variables
    cameraConfig = config
    cameraTargetEntity = resolveCameraTarget(config.target, config.bone, ctx)
    cameraOrbitAngle = 0
    lastCameraPosition = nil
    
    if not cameraTargetEntity or not DoesEntityExist(cameraTargetEntity) then
        print(string.format('[%s] Camera target not found: %s', GetCurrentResourceName(), tostring(config.target)))
        return
    end
    
    -- Get initial position for lerp
    local initialCoords = GetEntityCoords(cameraTargetEntity)
    if config.bone then
        local boneCoords = getBoneWorldCoords(cameraTargetEntity, config.bone)
        if boneCoords then
            initialCoords = boneCoords
        end
    end
    
    -- Calculate initial camera position based on mode
    if config.mode == "follow" then
        -- For follow mode, start at offset position
        local offset = resolveValue(config.offset, ctx) or {x = 0, y = 0, z = 0}
        lastCameraPosition = {
            x = initialCoords.x + offset.x,
            y = initialCoords.y + offset.y,
            z = initialCoords.z + offset.z
        }
    elseif config.mode == "track" then
        -- For track mode, use fixed coords
        lastCameraPosition = resolveValue(config.coords, ctx) or initialCoords
    elseif config.mode == "orbit" then
        -- For orbit mode, calculate initial position on circle
        local radius = resolveValue(config.radius, ctx) or 3.0
        local height = resolveValue(config.height, ctx) or 1.5
        lastCameraPosition = {
            x = initialCoords.x + radius,
            y = initialCoords.y,
            z = initialCoords.z + height
        }
    end
    
    -- Start tracking thread
    activeCameraThread = true
    
    Citizen.CreateThread(function()
        while activeCameraThread do
            if not cameraTargetEntity or not DoesEntityExist(cameraTargetEntity) then
                if Config.enableDebug then
                    print(string.format('[%s] Camera target no longer exists, stopping tracking', GetCurrentResourceName()))
                end
                break
            end
            
            -- Get target position
            local targetCoords = GetEntityCoords(cameraTargetEntity)
            
            -- If bone specified, use bone position
            if cameraConfig.bone then
                local boneCoords = getBoneWorldCoords(cameraTargetEntity, cameraConfig.bone)
                if boneCoords then
                    targetCoords = boneCoords
                end
            end
            
            -- Calculate new camera position based on mode
            local newCamPos = nil
            
            if cameraConfig.mode == "follow" then
                -- FOLLOW MODE: Maintain offset from target
                local offset = resolveValue(cameraConfig.offset, ctx) or {x = 0, y = 0, z = 0}
                newCamPos = {
                    x = targetCoords.x + offset.x,
                    y = targetCoords.y + offset.y,
                    z = targetCoords.z + offset.z
                }
                
            elseif cameraConfig.mode == "track" then
                -- TRACK MODE: Camera stays at fixed position, looks at target
                newCamPos = resolveValue(cameraConfig.coords, ctx)
                if not newCamPos then
                    -- Fallback to current position if coords not set
                    newCamPos = lastCameraPosition
                end
                
            elseif cameraConfig.mode == "orbit" then
                -- ORBIT MODE: Rotate around target in circle
                local radius = resolveValue(cameraConfig.radius, ctx) or 3.0
                local height = resolveValue(cameraConfig.height, ctx) or 1.5
                local speed = resolveValue(cameraConfig.speed, ctx) or 1.0
                
                -- Apply direction multiplier
                if Config.cameraOrbitDirection == "counter" then
                    speed = -speed
                end
                
                -- Update orbit angle
                cameraOrbitAngle = cameraOrbitAngle + (speed * 0.016) -- Approx 60fps
                
                -- Calculate position on circle
                newCamPos = {
                    x = targetCoords.x + (math.cos(cameraOrbitAngle) * radius),
                    y = targetCoords.y + (math.sin(cameraOrbitAngle) * radius),
                    z = targetCoords.z + height
                }
            end
            
            -- Apply lerp smoothing if enabled
            if cameraConfig.lerp ~= false and lastCameraPosition and cameraConfig.mode ~= "orbit" then
                local lerpFactor = Config.cameraLerpFactor or 0.3
                newCamPos = lerpCoords(lastCameraPosition, newCamPos, lerpFactor)
            end
            
            -- Update camera position
            if newCamPos and activeTaskCamera then
                SetCamCoord(activeTaskCamera, newCamPos.x, newCamPos.y, newCamPos.z)
                lastCameraPosition = newCamPos
                
                -- For track and orbit modes, point camera at target
                if cameraConfig.mode == "track" or cameraConfig.mode == "orbit" then
                    PointCamAtCoord(activeTaskCamera, targetCoords.x, targetCoords.y, targetCoords.z)
                end
            end
            
            Citizen.Wait(0) -- Run every frame for smooth movement
        end
        
        activeCameraThread = nil
    end)
    
    if Config.enableDebug then
        print(string.format('[%s] Camera tracking started: mode=%s, target=%s, bone=%s', 
            GetCurrentResourceName(), 
            cameraConfig.mode, 
            tostring(cameraConfig.target),
            tostring(cameraConfig.bone)))
    end
end

--[[
    Stop camera tracking thread
]]
function stopCameraTracking()
    if activeCameraThread then
        activeCameraThread = false
        -- Wait a frame to ensure thread stops
        Citizen.Wait(0)
    end
    
    cameraConfig = nil
    cameraTargetEntity = nil
    lastCameraPosition = nil
    
    if Config.enableDebug then
        print(string.format('[%s] Camera tracking stopped', GetCurrentResourceName()))
    end
end

-- ============================================
-- PUBLIC FUNCTIONS
-- ============================================

--[[
    Point gameplay camera at entity (for dialog opening)
    @param entity: Entity to point camera at
]]
function pointCameraAtEntity(entity)
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

--[[
    Destroy active task camera and stop tracking
]]
function destroyTaskCamera()
    -- Stop tracking first
    stopCameraTracking()
    
    -- Destroy camera
    if activeTaskCamera then
        RenderScriptCams(false, true, 250, true, true)
        DestroyCam(activeTaskCamera, false)
        activeTaskCamera = nil
        
        if Config.enableDebug then
            print(string.format('[%s] Task camera destroyed', GetCurrentResourceName()))
        end
    end
end

--[[
    Create task camera with support for dynamic modes
    @param action: Camera action configuration
    @param ctx: Context object containing ped, playerPed, etc.
]]
function createTaskCamera(action, ctx)
    -- Destroy any existing camera
    destroyTaskCamera()
    
    -- Create new camera
    activeTaskCamera = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    
    -- Resolve configuration with support for function values
    local config = {
        mode = resolveValue(action.mode, ctx) or "static",
        target = resolveValue(action.target, ctx),
        bone = resolveValue(action.bone, ctx),
        offset = resolveValue(action.offset, ctx),
        coords = resolveValue(action.coords, ctx),
        radius = resolveValue(action.radius, ctx) or 3.0,
        height = resolveValue(action.height, ctx) or 1.5,
        speed = resolveValue(action.speed, ctx) or 1.0,
        fov = resolveValue(action.fov, ctx) or 45.0,
        lerp = resolveValue(action.lerp, ctx),
        autoDestroy = resolveValue(action.autoDestroy, ctx),
        fadeTime = resolveValue(action.fadeTime, ctx) or 250
    }
    
    -- Resolve target entity
    local targetEntity = resolveCameraTarget(config.target, config.bone, ctx)
    
    -- Set initial camera position based on mode
    if config.mode == "static" then
        -- STATIC MODE: Original behavior
        local coords = config.coords
        if not coords and targetEntity and DoesEntityExist(targetEntity) then
            coords = getCoordsFromOffset(targetEntity, config.offset)
        end
        
        if coords then
            SetCamCoord(activeTaskCamera, coords.x, coords.y, coords.z)
        end
        
    elseif config.mode == "follow" or config.mode == "track" or config.mode == "orbit" then
        -- DYNAMIC MODES: Start tracking
        if targetEntity and DoesEntityExist(targetEntity) then
            -- Set initial position
            if config.mode == "follow" then
                local targetCoords = GetEntityCoords(targetEntity)
                if config.bone then
                    local boneCoords = getBoneWorldCoords(targetEntity, config.bone)
                    if boneCoords then targetCoords = boneCoords end
                end
                
                local offset = config.offset or {x = 0, y = 0, z = 0}
                SetCamCoord(activeTaskCamera, 
                    targetCoords.x + offset.x,
                    targetCoords.y + offset.y,
                    targetCoords.z + offset.z
                )
                
            elseif config.mode == "track" then
                -- Use provided coords or fallback to offset from target
                local coords = config.coords
                if not coords and targetEntity then
                    coords = getCoordsFromOffset(targetEntity, {x = -2.0, y = -2.0, z = 1.5})
                end
                if coords then
                    SetCamCoord(activeTaskCamera, coords.x, coords.y, coords.z)
                end
                
            elseif config.mode == "orbit" then
                -- Start at initial orbit position
                local targetCoords = GetEntityCoords(targetEntity)
                local radius = config.radius or 3.0
                local height = config.height or 1.5
                SetCamCoord(activeTaskCamera,
                    targetCoords.x + radius,
                    targetCoords.y,
                    targetCoords.z + height
                )
            end
            
            -- Start the tracking thread
            startCameraTracking(config, ctx)
        else
            print(string.format('[%s] Cannot start camera tracking: target not found', GetCurrentResourceName()))
        end
    end
    
    -- Set FOV and render
    SetCamFov(activeTaskCamera, config.fov)
    RenderScriptCams(true, true, config.fadeTime, true, true)
    
    -- Handle lookAt for static mode
    if config.mode == "static" and action.lookAt then
        if type(action.lookAt) == "table" then
            lookAtTaskCamera({coords = action.lookAt}, ctx)
        elseif type(action.lookAt) == "string" then
            lookAtTaskCamera({target = action.lookAt}, ctx)
        end
    end
    
    if Config.enableDebug then
        print(string.format('[%s] Task camera created: mode=%s, fov=%.1f', 
            GetCurrentResourceName(), config.mode, config.fov))
    end
end

--[[
    Point task camera at coordinates or target
    @param action: LookAt action configuration
    @param ctx: Context object
]]
function lookAtTaskCamera(action, ctx)
    if not activeTaskCamera then
        return
    end
    
    local coords = action.coords
    
    -- Resolve coordinates from target if specified
    if not coords and action.target then
        local targetEntity = resolveCameraTarget(action.target, action.bone, ctx)
        
        if targetEntity and DoesEntityExist(targetEntity) then
            if action.target == "engine" then
                coords = getEngineCoords(targetEntity)
            else
                -- Get entity position or bone position
                coords = GetEntityCoords(targetEntity)
                if action.bone then
                    local boneCoords = getBoneWorldCoords(targetEntity, action.bone)
                    if boneCoords then coords = boneCoords end
                end
            end
        end
    end
    
    if coords then
        PointCamAtCoord(activeTaskCamera, coords.x, coords.y, coords.z)
    end
end

--[[
    Get active task camera handle
    @return: Camera handle or nil
]]
function getActiveTaskCamera()
    return activeTaskCamera
end

--[[
    Check if camera is currently tracking
    @return: Boolean
]]
function isCameraTracking()
    return activeCameraThread ~= nil
end
