--[[
    Main Dialog System V2
    
    Core functionality for the new Advance Dialog V2 system.
    Manages dialog state, animations, NUI communication, and integrates
    with the dialog registry and task API.
    
    Features:
    - Dialog state management (open/close)
    - NUI callbacks for user interaction
    - Integration with registerDialog/openDialog V2
    - TaskAPI execution with protection
    - Clean error handling
]]

-- ============================================
-- CACHE FREQUENTLY USED NATIVES
-- ============================================

local GetCurrentResourceNameCached = GetCurrentResourceName
local PlayerPedIdCached = PlayerPedId
local DoesEntityExistCached = DoesEntityExist
local GetEntityCoordsCached = GetEntityCoords
local SendNUIMessageCached = SendNUIMessage
local SetNuiFocusCached = SetNuiFocus
local TriggerEventCached = TriggerEvent
local RegisterNetEventCached = RegisterNetEvent
local AddEventHandlerCached = AddEventHandler

-- ============================================
-- STATE
-- ============================================

---@class DialogState
---@field isOpen boolean
---@field dialog? table
---@field ped? number

local activeDialog = nil
local activePed = nil
local isDialogOpen = false

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

---@param playerPed number
---@param ctx table
---@return table
function buildContext(dialog, playerPed)
    local ctx = {
        dialog = dialog,
        dialogId = dialog.id,
        ped = activePed,
        playerPed = playerPed,
        metadata = dialog.metadata or {}
    }
    return ctx
end

-- ============================================
-- DIALOG MANAGEMENT
-- ============================================

--[[
    Show dialog in NUI
    
    @param dialogData: table - Dialog configuration
    @param ped: number - Target ped entity
]]
function showDialog(dialogData, ped, isTransition)
    if not dialogData then
        print(string.format('[%s] Error: No dialog data provided', GetCurrentResourceNameCached()))
        return
    end
    
    activeDialog = dialogData
    activePed = ped
    isDialogOpen = true
    
    -- Build options for NUI
    local options = {}
    for _, option in ipairs(dialogData.options or {}) do
        local enabled = true
        if option.canInteract then
            local success, result = pcall(option.canInteract, PlayerPedIdCached(), buildContext(dialogData, PlayerPedIdCached()))
            if success then
                enabled = result == true
            else
                enabled = false
            end
        end
        
        table.insert(options, {
            label = option.label or '',
            description = option.description or '',
            icon = option.icon or '',
            disabled = not enabled
        })
    end
    
    -- Send to NUI
    SendNUIMessageCached({
        action = 'showDialog',
        data = {
            id = dialogData.id or '',
            speaker = dialogData.speaker or '',
            text = dialogData.text or '',
            options = options
        }
    })
    
    SetNuiFocusCached(true, true)
    TriggerEventCached('advance-dialog:open', buildContext(dialogData, PlayerPedIdCached()))
    
    if Config.enableDebug then
        print(string.format('[%s] Dialog shown: %s', GetCurrentResourceNameCached(), dialogData.id or 'unknown'))
    end
end

function closeDialog()
    if not isDialogOpen then
        return
    end
    
    isDialogOpen = false
    local ctx = buildContext(activeDialog, PlayerPedIdCached())
    
    -- Stop animations
    if activePed and DoesEntityExistCached(activePed) then
        ClearPedTasks(activePed)
    end
    
    -- Hide NUI
    SendNUIMessageCached({ action = 'closeDialog' })
    SetNuiFocusCached(false, false)
    
    -- Trigger event
    TriggerEventCached('advance-dialog:close', ctx)
    
    activeDialog = nil
    activePed = nil
    
    if Config.enableDebug then
        print(string.format('[%s] Dialog closed', GetCurrentResourceNameCached()))
    end
end

function getDialogState()
    return isDialogOpen
end

-- ============================================
-- PED MANAGEMENT
-- ============================================

function setActivePed(ped)
    activePed = ped
end

function getActivePed()
    return activePed
end

function createPedAndOpen(dialogId, pedConfig)
    local model = pedConfig.model or GetHashKey('s_m_y_shop_assistant')
    
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end
    
    local ped = CreatePed(4, model, 
        pedConfig.coords.x, 
        pedConfig.coords.y, 
        pedConfig.coords.z, 
        pedConfig.heading or 0.0, 
        pedConfig.freeze ~= false, 
        true
    )
    
    SetModelAsNoLongerNeeded(model)
    
    if pedConfig.freeze then
        FreezeEntityPosition(ped, true)
    end
    
    if pedConfig.invincible then
        SetEntityInvincible(ped, true)
    end
    
    -- Look at player
    TaskTurnPedToFaceEntity(ped, PlayerPedIdCached(), -1)
    
    -- Setup interaction with ox_target if available
    if exports.ox_target then
        exports.ox_target:addLocalEntity(ped, {
            {
                label = pedConfig.targetLabel or 'Talk',
                icon = pedConfig.targetIcon or 'fa-solid fa-comments',
                onSelect = function()
                    -- Open the registered dialog
                    exports[GetCurrentResourceNameCached()]:openDialog(ped, dialogId)
                end
            }
        })
    end
    
    return ped
end

-- ============================================
-- ANIMATION MANAGEMENT
-- ============================================

function stopCurrentAnimations()
    if activePed and DoesEntityExistCached(activePed) then
        ClearPedTasks(activePed)
    end
end

-- ============================================
-- NUI CALLBACKS
-- ============================================

RegisterNUICallback('selectOption', function(data, cb)
    if not activeDialog or not activeDialog.options then
        cb('ok')
        return
    end
    
    local selectedIndex = tonumber(data.index) or data.index
    
    -- Handle special actions from NUI
    if data.action then
        if data.action == "back" then
            exports[GetCurrentResourceNameCached()]:goBack()
            cb('ok')
            return
        elseif data.action == "close" or selectedIndex == -1 then
            closeDialog()
            cb('cleanup')
            return
        end
    end
    
    if selectedIndex == -1 then
        closeDialog()
        cb('ok')
        return
    end
    
    local selectedOption = activeDialog.options[selectedIndex]
    if not selectedOption then
        cb('ok')
        return
    end
    
    -- Handle special actions
    if selectedOption.action == "back" then
        exports[GetCurrentResourceNameCached()]:goBack()
        cb('ok')
        return
    elseif selectedOption.action == "close" then
        closeDialog()
        cb('ok')
        return
    end
    
    if Config.enableDebug then
        print(string.format('[%s] Option selected: %d, %s', 
            GetCurrentResourceNameCached(), selectedIndex, selectedOption.label or 'Close'))
    end
    
    local ctx = buildContext(activeDialog, PlayerPedIdCached())
    
    -- Check if option is selectable
    if selectedOption.canInteract then
        local success, allowed = pcall(selectedOption.canInteract, PlayerPedIdCached(), ctx)
        if not success or not allowed then
            TriggerEventCached('advance-dialog:denied', ctx)
            cb('ok')
            return
        end
    end
    
    -- Execute callback if present
    if selectedOption.callback then
        local success, err = pcall(selectedOption.callback, ctx)
        if not success then
            print(string.format('[%s] Error in callback: %s', GetCurrentResourceNameCached(), tostring(err)))
        end
    end
    
    -- NEW SYSTEM V2: onSelect with TaskAPI
    if selectedOption.onSelect then
        -- Get error handler from dialog config
        local dialogConfig = getRegisteredDialog(activeDialog.id)
        local onError = nil
        if dialogConfig and dialogConfig.onError then
            onError = dialogConfig.onError
        end
        
        -- Execute safely with protection
        exports[GetCurrentResourceNameCached()]:ExecuteOnSelectSafely(selectedOption.onSelect, ctx, onError)
        
        cb('ok')
        return
    end
    
    -- Handle next dialog
    if selectedOption.next then
        exports[GetCurrentResourceNameCached()]:showDialog(selectedOption.next)
    elseif selectedOption.close then
        closeDialog()
    end
    
    TriggerEventCached('advance-dialog:optionSelected', ctx)
    cb('ok')
end)

RegisterNUICallback('closeDialog', function(data, cb)
    closeDialog()
    cb('ok')
end)

-- ============================================
-- KEYBOARD HANDLERS
-- ============================================

AddEventHandler('onKeyDown', function(key)
    if key == Config.closeKey and isDialogOpen then
        closeDialog()
    end
end)

-- ============================================
-- RESOURCE STOP CLEANUP
-- ============================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceNameCached() then
        return
    end
    
    closeDialog()
    
    if Config.enableDebug then
        print(string.format('[%s] Cleanup completed on resource stop', GetCurrentResourceNameCached()))
    end
end)

-- ============================================
-- EXPORTS
-- ============================================

exports('showDialog', showDialog)
exports('closeDialog', closeDialog)
exports('getDialogState', getDialogState)
exports('isDialogOpen', getDialogState)
exports('stopAnimations', stopCurrentAnimations)
exports('setActivePed', setActivePed)
exports('getActivePed', getActivePed)
exports('createPedAndOpen', createPedAndOpen)
