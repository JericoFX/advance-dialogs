--[[
    Server Events Handler
    
    Handles client requests for data persistence.
    All database operations run server-side for security.
]]

-- Data Set
RegisterNetEvent('advance-dialog:data:set', function(key, value)
    local src = source
    if not src or src <= 0 then return end
    
    exports[GetCurrentResourceName()]:DatabaseSet(src, key, value, function(success)
        TriggerClientEvent('advance-dialog:data:set:response', src, success)
    end)
end)

-- Data Get
RegisterNetEvent('advance-dialog:data:get', function(key, defaultValue)
    local src = source
    if not src or src <= 0 then return end
    
    exports[GetCurrentResourceName()]:DatabaseGet(src, key, defaultValue, function(value)
        TriggerClientEvent('advance-dialog:data:get:response', src, value)
    end)
end)

-- Data Remove
RegisterNetEvent('advance-dialog:data:remove', function(key)
    local src = source
    if not src or src <= 0 then return end
    
    exports[GetCurrentResourceName()]:DatabaseRemove(src, key, function(success)
        TriggerClientEvent('advance-dialog:data:remove:response', src, success)
    end)
end)

-- Data Clear
RegisterNetEvent('advance-dialog:data:clear', function()
    local src = source
    if not src or src <= 0 then return end
    
    exports[GetCurrentResourceName()]:DatabaseClear(src, function(success)
        TriggerClientEvent('advance-dialog:data:clear:response', src, success)
    end)
end)
