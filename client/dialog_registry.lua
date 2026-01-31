--[[
    Dialog Registry System V2
    
    New simplified dialog system with:
    - registerDialog(): Register dialog configuration once
    - openDialog(): Open dialog on specific entity with optional dynamic metadata
    - Navigation history with "back" action
    - Protected onSelect execution with error handling
]]

---@class DialogOption
---@field label string
---@field description? string
---@field icon? string
---@field canInteract? fun(ctx: DialogContext): boolean
---@field onSelect? fun(ctx: DialogContext, task: TaskAPI)
---@field action? "back" | "close"
---@field next? string
---@field close? boolean
---@field _original? DialogOption
---@field disabled? boolean

---@class DialogMetadata
---@field [string] any

---@class DialogContext
---@field dialog DialogConfig
---@field dialogId string
---@field ped number
---@field playerPed number
---@field metadata table
---@field targetEntity number
---@field option? DialogOption
---@field optionMetadata? table
---@field mergedMetadata? table
---@field reason? string

---@class DialogConfig
---@field id string
---@field speaker? string
---@field text string
---@field metadata? table
---@field canInteract? fun(ctx: DialogContext, targetEntity: number): boolean
---@field onDenied? fun(ctx: DialogContext)
---@field onError? fun(ctx: DialogContext, error: string)
---@field options? DialogOption[]

---@class CoordsTable
---@field x number
---@field y number
---@field z number
---@field radius? number

-- Cache frequently used natives
local GetCurrentResourceNameCached = GetCurrentResourceName
local PlayerPedIdCached = PlayerPedId
local DoesEntityExistCached = DoesEntityExist
local GetEntityCoordsCached = GetEntityCoords
local SendNUIMessageCached = SendNUIMessage
local SetNuiFocusCached = SetNuiFocus
local TriggerEventCached = TriggerEvent
local NetToPedCached = NetToPed
local NetToVehCached = NetToVeh

local RegisteredDialogs = {}
local DialogHistory = {}
local ActiveEntity = nil
local ActiveDialogId = nil

-- ============================================
-- METADATA RESOLUTION
-- ============================================

---@param metadata table
---@return table
local function resolveMetadata(metadata)
    if type(metadata) ~= "table" then
        return {}
    end
    
    local resolved = {}
    for key, value in pairs(metadata) do
        if type(value) == "function" then
            local success, result = pcall(value)
            if success then
                resolved[key] = result
            else
                resolved[key] = nil
            end
        else
            resolved[key] = value
        end
    end
    
    return resolved
end

---@param staticMetadata table
---@param dynamicMetadata? table
---@return table
local function mergeMetadata(staticMetadata, dynamicMetadata)
    local merged = {}
    
    -- Resolve static metadata (functions become values)
    local resolvedStatic = resolveMetadata(staticMetadata)
    for k, v in pairs(resolvedStatic) do
        merged[k] = v
    end
    
    -- Override with dynamic metadata
    if type(dynamicMetadata) == "table" then
        for k, v in pairs(dynamicMetadata) do
            merged[k] = v
        end
    end
    
    return merged
end

-- ============================================
-- DIALOG REGISTRATION
-- ============================================

---@param dialogConfig DialogConfig
---@return boolean
function registerDialog(dialogConfig)
    if not dialogConfig or type(dialogConfig) ~= "table" then
        print(string.format('[%s] Error: Invalid dialog config', GetCurrentResourceNameCached()))
        return false
    end
    
    if not dialogConfig.id or type(dialogConfig.id) ~= "string" then
        print(string.format('[%s] Error: Dialog must have an id', GetCurrentResourceNameCached()))
        return false
    end
    
    RegisteredDialogs[dialogConfig.id] = dialogConfig
    
    if Config.enableDebug then
        print(string.format('[%s] Registered dialog: %s', GetCurrentResourceNameCached(), dialogConfig.id))
    end
    
    return true
end

-- ============================================
-- DIALOG OPENING
-- ============================================

---@param entity number | CoordsTable
---@param dialogId string
---@param dynamicMetadata? table
---@return boolean
function openDialog(entity, dialogId, dynamicMetadata)
    if not entity then
        print(string.format('[%s] Error: No entity provided', GetCurrentResourceNameCached()))
        return false
    end
    
    if not dialogId or type(dialogId) ~= "string" then
        print(string.format('[%s] Error: Invalid dialog id', GetCurrentResourceNameCached()))
        return false
    end
    
    local dialog = RegisteredDialogs[dialogId]
    if not dialog then
        print(string.format('[%s] Error: Dialog "%s" not found', GetCurrentResourceNameCached(), dialogId))
        return false
    end
    
    -- Resolve entity
    local targetEntity = entity
    if type(entity) == "table" and entity.x then
        -- Coords table - find closest ped/entity
        targetEntity = getClosestEntityToCoords(entity)
    elseif type(entity) == "number" and entity > 0 and not DoesEntityExistCached(entity) then
        -- Assume it's a netId
        targetEntity = NetToPedCached(entity) or NetToVehCached(entity)
    end
    
    if not targetEntity or not DoesEntityExistCached(targetEntity) then
        print(string.format('[%s] Error: Target entity does not exist', GetCurrentResourceNameCached()))
        return false
    end
    
    -- Build context
    local staticMetadata = dialog.metadata or {}
    local mergedMetadata = mergeMetadata(staticMetadata, dynamicMetadata)
    
    local playerPed = PlayerPedIdCached()
    ---@type DialogContext
    local ctx = {
        dialog = dialog,
        dialogId = dialogId,
        ped = targetEntity,
        playerPed = playerPed,
        metadata = mergedMetadata,
        targetEntity = targetEntity
    }
    
    -- Check global canInteract
    if dialog.canInteract then
        local success, allowed = pcall(dialog.canInteract, ctx, targetEntity)
        if not success then
            print(string.format('[%s] Error in canInteract: %s', GetCurrentResourceNameCached(), tostring(allowed)))
            return false
        end
        if not allowed then
            if dialog.onDenied then
                pcall(dialog.onDenied, ctx)
            end
            return false
        end
    end
    
    -- Initialize history for this entity if needed
    if not DialogHistory[targetEntity] then
        DialogHistory[targetEntity] = {}
    end
    
    -- Push to history
    table.insert(DialogHistory[targetEntity], dialogId)
    
    -- Set active
    ActiveEntity = targetEntity
    ActiveDialogId = dialogId
    
    -- Build options with canInteract check
    local options = {}
    for _, option in ipairs(dialog.options or {}) do
        local enabled = true
        if option.canInteract then
            local success, result = pcall(option.canInteract, ctx)
            if success then
                enabled = result == true
            else
                enabled = false
            end
        end
        
        table.insert(options, {
            label = option.label,
            description = option.description,
            icon = option.icon,
            disabled = not enabled,
            _original = option -- Store reference
        })
    end
    
    -- Show in NUI
    SendNUIMessageCached({
        action = 'showDialog',
        data = {
            id = dialogId,
            speaker = dialog.speaker or '',
            text = dialog.text or '',
            options = options,
            showBack = #DialogHistory[targetEntity] > 1
        }
    })
    
    SetNuiFocusCached(true, true)
    
    -- Trigger event
    TriggerEventCached('advance-dialog:open', ctx)
    
    if Config.enableDebug then
        print(string.format('[%s] Opened dialog "%s" on entity %s', 
            GetCurrentResourceNameCached(), dialogId, tostring(targetEntity)))
    end
    
    return true
end

-- ============================================
-- NAVIGATION
-- ============================================

---@param entity? number
---@return boolean
function goBack(entity)
    local targetEntity = entity or ActiveEntity
    if not targetEntity or not DialogHistory[targetEntity] then
        return false
    end
    
    local history = DialogHistory[targetEntity]
    if #history < 2 then
        return false
    end
    
    -- Remove current
    table.remove(history)
    
    -- Get previous
    local previousId = history[#history]
    table.remove(history) -- Will be re-added by openDialog
    
    -- Open previous
    return openDialog(targetEntity, previousId)
end

---@param entity? number
function clearHistory(entity)
    local targetEntity = entity or ActiveEntity
    if targetEntity and DialogHistory[targetEntity] then
        DialogHistory[targetEntity] = {}
    end
end

---@param entity? number
---@return table
function getHistory(entity)
    local targetEntity = entity or ActiveEntity
    return DialogHistory[targetEntity] or {}
end

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

---@param coords CoordsTable
---@return number | nil
function getClosestEntityToCoords(coords)
    local playerPed = PlayerPedIdCached()
    local playerCoords = GetEntityCoordsCached(playerPed)
    local targetCoords = vector3(coords.x, coords.y, coords.z)
    
    -- Check if player is within radius
    local dist = #(playerCoords - targetCoords)
    if dist <= (coords.radius or 3.0) then
        -- Return player ped as default, or find closest ped
        return playerPed
    end
    
    return nil
end

---@return number | nil
function getActiveEntity()
    return ActiveEntity
end

---@return string | nil
function getActiveDialogId()
    return ActiveDialogId
end

---@param id string
---@return DialogConfig | nil
function getRegisteredDialog(id)
    return RegisteredDialogs[id]
end

-- ============================================
-- EXPORTS
-- ============================================

exports('registerDialog', registerDialog)
exports('openDialog', openDialog)
exports('goBack', goBack)
exports('clearHistory', clearHistory)
exports('getHistory', getHistory)
exports('getActiveEntity', getActiveEntity)
exports('getActiveDialogId', getActiveDialogId)
exports('getRegisteredDialog', getRegisteredDialog)
