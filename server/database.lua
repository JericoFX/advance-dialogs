--[[
    Database Provider
    
    Handles SQL persistence via oxmysql.
    Designed for MariaDB with automatic triggers for limits and cleanup.
    
    Features:
    - Automatic table creation
    - Configurable player identifier (license/citizenid/etc)
    - Custom query support
    - Async operations with callbacks
    - 100% server-side (client never sees SQL config)
]]

---@class DatabaseProvider
---@field ready boolean
---@field tableCreated boolean

local DatabaseProvider = {
    ready = false,
    tableCreated = false,
}

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

---Get player identifier based on configuration
---@param source number Player server ID
---@return string | nil
local function getPlayerIdentifier(source)
    if not source or source <= 0 then return nil end
    
    local idType = ConfigDatabase.identifier.type
    
    if idType == "license" then
        -- FiveM license (framework-agnostic)
        for i = 0, GetNumPlayerIdentifiers(source) - 1 do
            local id = GetPlayerIdentifier(source, i)
            if string.find(id, "license:") then
                return id
            end
        end
        return nil
        
    elseif idType == "steam" then
        for i = 0, GetNumPlayerIdentifiers(source) - 1 do
            local id = GetPlayerIdentifier(source, i)
            if string.find(id, "steam:") then
                return id
            end
        end
        return nil
        
    elseif idType == "discord" then
        for i = 0, GetNumPlayerIdentifiers(source) - 1 do
            local id = GetPlayerIdentifier(source, i)
            if string.find(id, "discord:") then
                return id
            end
        end
        return nil
        
    elseif idType == "citizenid" then
        -- QBCore
        if exports['qb-core'] then
            local Player = exports['qb-core']:GetPlayer(source)
            if Player then
                return Player.PlayerData.citizenid
            end
        end
        return nil
        
    elseif idType == "identifier" then
        -- ESX
        if exports['es_extended'] then
            local xPlayer = exports['es_extended']:getPlayerFromId(source)
            if xPlayer then
                return xPlayer.identifier
            end
        end
        return nil
        
    elseif idType == "custom" then
        if ConfigDatabase.identifier.customFunction then
            return ConfigDatabase.identifier.customFunction(source)
        end
        return nil
    end
    
    return nil
end

-- ============================================
-- TABLE MANAGEMENT
-- ============================================

---Create database table and triggers
---@param callback? fun(success: boolean, error?: string)
function DatabaseProvider.createTable(callback)
    if DatabaseProvider.tableCreated then
        if callback then callback(true) end
        return
    end
    
    local tableName = ConfigDatabase.table.name
    local resourceName = GetCurrentResourceName()
    
    -- Main table
    local createTableQuery = string.format([[
        CREATE TABLE IF NOT EXISTS %s (
            id INT AUTO_INCREMENT PRIMARY KEY,
            identifier VARCHAR(100) NOT NULL,
            resource VARCHAR(100) NOT NULL,
            dialog_id VARCHAR(100),
            data_key VARCHAR(255) NOT NULL,
            data_value TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            
            UNIQUE KEY unique_data (identifier, resource, data_key),
            INDEX idx_identifier (identifier),
            INDEX idx_updated (updated_at)
        ) ENGINE=InnoDB;
    ]], tableName)
    
    -- Trigger: Limit to 100 entries per player (auto-delete oldest)
    local createTriggerQuery = string.format([[
        CREATE TRIGGER IF NOT EXISTS trg_%s_limit_100
        BEFORE INSERT ON %s
        FOR EACH ROW
        BEGIN
            DECLARE count_entries INT;
            
            SELECT COUNT(*) INTO count_entries 
            FROM %s 
            WHERE identifier = NEW.identifier;
            
            IF count_entries >= 100 THEN
                DELETE FROM %s 
                WHERE identifier = NEW.identifier 
                ORDER BY created_at ASC 
                LIMIT 1;
            END IF;
        END;
    ]], tableName, tableName, tableName, tableName)
    
    -- Event: Auto-cleanup entries older than 30 days
    local createEventQuery = string.format([[
        CREATE EVENT IF NOT EXISTS evt_%s_cleanup
        ON SCHEDULE EVERY 24 HOUR
        DO
        BEGIN
            DELETE FROM %s 
            WHERE updated_at < DATE_SUB(NOW(), INTERVAL 30 DAY);
        END;
    ]], tableName, tableName)
    
    -- Execute queries
    exports.oxmysql:execute(createTableQuery, {}, function(result, err)
        if err then
            print(string.format('[%s] Database Error: %s', resourceName, tostring(err)))
            if callback then callback(false, tostring(err)) end
            return
        end
        
        -- Create trigger
        exports.oxmysql:execute(createTriggerQuery, {}, function()
            -- Create event (requires event_scheduler = ON)
            exports.oxmysql:execute(createEventQuery, {}, function()
                DatabaseProvider.tableCreated = true
                print(string.format('[%s] Database table and triggers created successfully', resourceName))
                if callback then callback(true) end
            end)
        end)
    end)
end

-- ============================================
-- DATA OPERATIONS
-- ============================================

---Set data value
---@param source number Player server ID
---@param key string Data key
---@param value any Data value (will be JSON encoded)
---@param callback? fun(success: boolean, error?: string)
function DatabaseProvider.set(source, key, value, callback)
    if not DatabaseProvider.tableCreated then
        if callback then callback(false, "Database not initialized") end
        return
    end
    
    local identifier = getPlayerIdentifier(source)
    if not identifier then
        if callback then callback(false, "Could not get player identifier") end
        return
    end
    
    local resourceName = GetCurrentResourceName()
    local tableName = ConfigDatabase.table.name
    local jsonValue = json.encode({value = value, type = type(value)})
    
    local query = ConfigDatabase.queries.insert or string.format([[
        INSERT INTO %s (identifier, resource, data_key, data_value, created_at)
        VALUES (?, ?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE 
        data_value = VALUES(data_value),
        updated_at = NOW();
    ]], tableName)
    
    exports.oxmysql:execute(query, {
        identifier, 
        resourceName, 
        key, 
        jsonValue
    }, function(result, err)
        if err then
            print(string.format('[%s] Database set error: %s', resourceName, tostring(err)))
            if callback then callback(false, tostring(err)) end
            return
        end
        if callback then callback(true) end
    end)
end

---Get data value
---@param source number Player server ID
---@param key string Data key
---@param defaultValue any Default value if not found
---@param callback fun(value: any, error?: string)
function DatabaseProvider.get(source, key, defaultValue, callback)
    if not DatabaseProvider.tableCreated then
        callback(defaultValue, "Database not initialized")
        return
    end
    
    local identifier = getPlayerIdentifier(source)
    if not identifier then
        callback(defaultValue, "Could not get player identifier")
        return
    end
    
    local resourceName = GetCurrentResourceName()
    local tableName = ConfigDatabase.table.name
    
    local query = ConfigDatabase.queries.select or string.format([[
        SELECT data_value FROM %s 
        WHERE identifier = ? AND resource = ? AND data_key = ?
        LIMIT 1;
    ]], tableName)
    
    exports.oxmysql:execute(query, {
        identifier, 
        resourceName, 
        key
    }, function(result, err)
        if err then
            print(string.format('[%s] Database get error: %s', resourceName, tostring(err)))
            callback(defaultValue, tostring(err))
            return
        end
        
        if result and result[1] and result[1].data_value then
            local decoded = json.decode(result[1].data_value)
            if decoded and decoded.value ~= nil then
                callback(decoded.value)
                return
            end
        end
        
        callback(defaultValue)
    end)
end

---Remove data entry
---@param source number Player server ID
---@param key string Data key
---@param callback? fun(success: boolean, error?: string)
function DatabaseProvider.remove(source, key, callback)
    if not DatabaseProvider.tableCreated then
        if callback then callback(false, "Database not initialized") end
        return
    end
    
    local identifier = getPlayerIdentifier(source)
    if not identifier then
        if callback then callback(false, "Could not get player identifier") end
        return
    end
    
    local resourceName = GetCurrentResourceName()
    local tableName = ConfigDatabase.table.name
    
    local query = ConfigDatabase.queries.delete or string.format([[
        DELETE FROM %s 
        WHERE identifier = ? AND resource = ? AND data_key = ?;
    ]], tableName)
    
    exports.oxmysql:execute(query, {
        identifier, 
        resourceName, 
        key
    }, function(result, err)
        if err then
            print(string.format('[%s] Database remove error: %s', resourceName, tostring(err)))
            if callback then callback(false, tostring(err)) end
            return
        end
        if callback then callback(true) end
    end)
end

---Clear all data for player
---@param source number Player server ID
---@param callback? fun(success: boolean, error?: string)
function DatabaseProvider.clear(source, callback)
    if not DatabaseProvider.tableCreated then
        if callback then callback(false, "Database not initialized") end
        return
    end
    
    local identifier = getPlayerIdentifier(source)
    if not identifier then
        if callback then callback(false, "Could not get player identifier") end
        return
    end
    
    local resourceName = GetCurrentResourceName()
    local tableName = ConfigDatabase.table.name
    
    local query = string.format([[
        DELETE FROM %s 
        WHERE identifier = ? AND resource = ?;
    ]], tableName)
    
    exports.oxmysql:execute(query, {
        identifier, 
        resourceName
    }, function(result, err)
        if err then
            print(string.format('[%s] Database clear error: %s', resourceName, tostring(err)))
            if callback then callback(false, tostring(err)) end
            return
        end
        if callback then callback(true) end
    end)
end

---Mark dialog as completed
---@param source number Player server ID
---@param dialogId string Dialog ID
---@param callback? fun(success: boolean, error?: string)
function DatabaseProvider.markCompleted(source, dialogId, callback)
    DatabaseProvider.set(source, "dialog_completed_" .. dialogId, true, callback)
end

---Check if dialog is completed
---@param source number Player server ID
---@param dialogId string Dialog ID
---@param callback fun(completed: boolean, error?: string)
function DatabaseProvider.isCompleted(source, dialogId, callback)
    DatabaseProvider.get(source, "dialog_completed_" .. dialogId, false, function(value, err)
        callback(value == true, err)
    end)
end

-- ============================================
-- INITIALIZATION
-- ============================================

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    -- Check if oxmysql is available
    if not exports.oxmysql then
        print(string.format('[%s] WARNING: oxmysql not found. SQL features disabled.', resourceName))
        return
    end
    
    if ConfigDatabase.table.autoCreate then
        DatabaseProvider.createTable(function(success)
            if success then
                DatabaseProvider.ready = true
                print(string.format('[%s] Database provider ready', resourceName))
            end
        end)
    end
end)

-- ============================================
-- EXPORTS
-- ============================================

exports('DatabaseSet', DatabaseProvider.set)
exports('DatabaseGet', DatabaseProvider.get)
exports('DatabaseRemove', DatabaseProvider.remove)
exports('DatabaseClear', DatabaseProvider.clear)
exports('DatabaseMarkCompleted', DatabaseProvider.markCompleted)
exports('DatabaseIsCompleted', DatabaseProvider.isCompleted)
