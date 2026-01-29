--[[
    Server Exports and Validation System
    
    Provides server-side dialog management with:
    - Dialog registration and storage
    - Data validation
    - Rate limiting for dialog requests
    - Server-to-client dialog delivery
    
    Security Features:
    - Request rate limiting per player
    - Dialog structure validation
    - Detailed error logging
]]

local registeredDialogs = {}
local lastRequest = {}
local enableDebug = false
local requestCooldown = 1000 -- 1 second between requests

-- ============================================
-- VALIDATION SYSTEM
-- ============================================

--[[
    Validate dialog structure
    
    Checks that dialog data meets minimum requirements and has valid types.
    
    @param dialog: Dialog configuration table
    @param id: Dialog ID (for error messages)
    @return: isValid (boolean), errors (table or nil)
]]
local function validateDialogStructure(dialog, id)
    local errors = {}
    
    if not dialog then
        return false, {"Dialog data is nil"}
    end
    
    if type(dialog) ~= "table" then
        return false, {"Dialog must be a table"}
    end
    
    -- Check required fields
    if not dialog.text then
        table.insert(errors, "Missing required field: text")
    elseif type(dialog.text) ~= "string" then
        table.insert(errors, "Field 'text' must be a string")
    end
    
    -- Check optional fields types
    if dialog.speaker ~= nil and type(dialog.speaker) ~= "string" then
        table.insert(errors, "Field 'speaker' must be a string")
    end
    
    if dialog.metadata ~= nil and type(dialog.metadata) ~= "table" then
        table.insert(errors, "Field 'metadata' must be a table")
    end
    
    -- Validate options if present
    if dialog.options ~= nil then
        if type(dialog.options) ~= "table" then
            table.insert(errors, "Field 'options' must be a table (array)")
        else
            for i, option in ipairs(dialog.options) do
                if type(option) ~= "table" then
                    table.insert(errors, string.format("Option %d must be a table", i))
                else
                    -- Check required option fields
                    if not option.label then
                        table.insert(errors, string.format("Option %d missing required field: label", i))
                    elseif type(option.label) ~= "string" then
                        table.insert(errors, string.format("Option %d field 'label' must be a string", i))
                    end
                    
                    -- Check optional option fields types
                    if option.description ~= nil and type(option.description) ~= "string" then
                        table.insert(errors, string.format("Option %d field 'description' must be a string", i))
                    end
                    
                    if option.next ~= nil and type(option.next) ~= "string" and type(option.next) ~= "number" then
                        table.insert(errors, string.format("Option %d field 'next' must be a string or number", i))
                    end
                    
                    if option.close ~= nil and type(option.close) ~= "boolean" then
                        table.insert(errors, string.format("Option %d field 'close' must be a boolean", i))
                    end
                    
                    if option.metadata ~= nil and type(option.metadata) ~= "table" then
                        table.insert(errors, string.format("Option %d field 'metadata' must be a table", i))
                    end
                    
                    -- Note: callback and task are functions, validated at runtime
                end
            end
        end
    end
    
    if #errors > 0 then
        return false, errors
    end
    
    return true, nil
end

-- ============================================
-- DIALOG REGISTRATION
-- ============================================

--[[
    Register dialogs on server
    
    Validates and stores dialogs for server-to-client delivery.
    Invalid dialogs are logged but not stored.
    
    @param dialogTable: Table with dialogId as keys, dialog config as values
    @return: success (boolean), errorMessage (string or nil)
]]
function registerDialogs(dialogTable)
    if type(dialogTable) ~= "table" then
        return false, "Invalid dialog table"
    end
    
    for id, dialog in pairs(dialogTable) do
        if type(dialog) == "table" then
            local idType = type(id)
            local validKey = (idType == "string" and id ~= "") or idType == "number"
            
            if not validKey then
                print(string.format('[%s] Warning: Skipping dialog with invalid id key', GetCurrentResourceName()))
            else
                -- Validate dialog structure
                local valid, errors = validateDialogStructure(dialog, id)
                
                if not valid then
                    print(string.format('[%s] Validation failed for dialog "%s":', GetCurrentResourceName(), tostring(id)))
                    for _, err in ipairs(errors) do
                        print(string.format('  - %s', err))
                    end
                else
                    -- Handle id mismatch warnings
                    if dialog.id ~= nil then
                        local dialogIdType = type(dialog.id)
                        local validDialogId = (dialogIdType == "string" and dialog.id ~= "") or dialogIdType == "number"
                        
                        if not validDialogId then
                            print(string.format('[%s] Warning: Dialog id invalid, using key: %s', GetCurrentResourceName(), tostring(id)))
                        elseif dialog.id ~= id then
                            print(string.format('[%s] Warning: Dialog id mismatch, using key: %s', GetCurrentResourceName(), tostring(id)))
                        end
                    end
                    
                    dialog.id = id
                    registeredDialogs[id] = dialog
                end
            end
        end
    end
    
    if enableDebug then
        local count = 0
        for _ in pairs(registeredDialogs) do count = count + 1 end
        print(string.format('[%s] Server registered dialogs: %d', GetCurrentResourceName(), count))
    end
    
    return true
end

--[[
    Get a registered dialog
    @param id: Dialog ID
    @return: Dialog config or nil
]]
function getDialog(id)
    return registeredDialogs[id]
end

--[[
    Get all registered dialogs
    @return: Table of all dialogs
]]
function getAllDialogs()
    return registeredDialogs
end

--[[
    Clear all registered dialogs
    @return: success (boolean)
]]
function clearDialogs()
    registeredDialogs = {}
    return true
end

-- ============================================
-- RATE LIMITING
-- ============================================

--[[
    Check if player has exceeded request rate limit
    
    @param source: Player server ID
    @return: allowed (boolean)
]]
local function checkRateLimit(source)
    local currentTime = GetGameTimer()
    local lastTime = lastRequest[source]
    
    if lastTime and (currentTime - lastTime) < requestCooldown then
        return false
    end
    
    lastRequest[source] = currentTime
    return true
end

-- ============================================
-- EVENT HANDLERS
-- ============================================

--[[
    Handle dialog request from client
    
    Rate-limited event to prevent spam.
    Sends dialog data to requesting client.
]]
RegisterNetEvent(string.format('%s:server:getDialog', GetCurrentResourceName()))
AddEventHandler(string.format('%s:server:getDialog', GetCurrentResourceName()), function(dialogId, callbackOrPedNetId)
    local source = source
    
    -- Check rate limit
    if not checkRateLimit(source) then
        if enableDebug then
            print(string.format('[%s] Rate limit hit for source %s', GetCurrentResourceName(), tostring(source)))
        end
        return
    end
    
    local dialog = registeredDialogs[dialogId]
    
    -- Handle callback pattern (if provided)
    if type(callbackOrPedNetId) == "function" then
        callbackOrPedNetId(dialog)
        return
    end
    
    -- Extract ped net ID if provided
    local pedNetId = nil
    if type(callbackOrPedNetId) == "number" then
        pedNetId = callbackOrPedNetId
    end
    
    -- Send dialog to client
    TriggerClientEvent(string.format('%s:client:receiveDialog', GetCurrentResourceName()), source, {
        dialog = dialog,
        dialogId = dialogId,
        pedNetId = pedNetId
    })
end)

-- ============================================
-- SERVER EXPORTS
-- ============================================

--[[
    Open dialog by ID on specific player
    
    @param targetSource: Player server ID
    @param dialogId: Dialog ID to open
    @param pedNetId: Optional ped network ID
    @return: success (boolean), errorMessage (string or nil)
]]
function openDialogById(targetSource, dialogId, pedNetId)
    if not targetSource or not dialogId then
        return false, "Missing target or dialog id"
    end
    
    local dialog = registeredDialogs[dialogId]
    
    TriggerClientEvent(string.format('%s:client:receiveDialog', GetCurrentResourceName()), targetSource, {
        dialog = dialog,
        dialogId = dialogId,
        pedNetId = pedNetId
    })
    
    return dialog ~= nil
end

-- Register exports
exports('registerDialogs', registerDialogs)
exports('getDialog', getDialog)
exports('getAllDialogs', getAllDialogs)
exports('clearDialogs', clearDialogs)
exports('openDialogById', openDialogById)
