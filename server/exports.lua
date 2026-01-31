--[[
    Server Exports
    
    Server-side exports for database operations.
    Used internally by client-server communication.
    
    Note: Database functions are implemented in database.lua
    This file serves as the export interface.
]]

-- Database operations (implemented in database.lua)
exports('DatabaseSet', function(source, key, value, callback)
    -- Implemented in database.lua
end)

exports('DatabaseGet', function(source, key, defaultValue, callback)
    -- Implemented in database.lua
end)

exports('DatabaseRemove', function(source, key, callback)
    -- Implemented in database.lua
end)

exports('DatabaseClear', function(source, callback)
    -- Implemented in database.lua
end)

exports('DatabaseMarkCompleted', function(source, dialogId, callback)
    -- Implemented in database.lua
end)

exports('DatabaseIsCompleted', function(source, dialogId, callback)
    -- Implemented in database.lua
end)
