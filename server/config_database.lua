--[[
    Database Configuration
    
    Server-side only configuration for SQL persistence.
    This file is never exposed to the client.
    
    Recommended: MariaDB for automatic triggers and events.
]]

---@class DatabaseConfig
---@field provider "oxmysql" Only oxmysql is supported
---@field table DatabaseTableConfig
---@field identifier DatabaseIdentifierConfig
---@field queries DatabaseQueriesConfig
---@field limits DatabaseLimitsConfig

---@class DatabaseTableConfig
---@field name string Table name (default: "advance_dialog_data")
---@field autoCreate boolean Auto-create table on startup

---@class DatabaseIdentifierConfig
---@field type "license" | "steam" | "discord" | "citizenid" | "identifier" | "custom"
---@field customFunction? fun(source: number): string Custom identifier function

---@class DatabaseQueriesConfig
---@field insert? string Custom INSERT query (nil = use standard with triggers)
---@field select? string Custom SELECT query (nil = use standard)
---@field update? string Custom UPDATE query (nil = use standard)
---@field delete? string Custom DELETE query (nil = use standard)

---@class DatabaseLimitsConfig
---@field maxEntriesPerPlayer number Maximum entries per player (default: 100)
---@field autoDeleteOldest boolean Auto-delete oldest when limit reached (default: true)
---@field expirationDays number Days before auto-cleanup (default: 30)

ConfigDatabase = {
    -- Only oxmysql is supported
    provider = "oxmysql",
    
    -- Table configuration
    table = {
        name = "advance_dialog_data",
        autoCreate = true,
    },
    
    -- Player identifier configuration
    -- The developer chooses based on their framework:
    -- "license" = FiveM license (default, framework-agnostic)
    -- "citizenid" = QBCore
    -- "identifier" = ESX  
    -- "steam" = Steam ID
    -- "discord" = Discord ID
    -- "custom" = Use customFunction
    identifier = {
        type = "license",
        -- Example for custom:
        -- customFunction = function(source)
        --     return exports['my-framework']:getPlayerId(source)
        -- end
    },
    
    -- Custom SQL queries (optional)
    -- Set to nil to use automatic standard queries with triggers
    -- Only modify if you need custom table structure
    queries = {
        insert = nil,
        select = nil,
        update = nil,
        delete = nil,
    },
    
    -- Limits and cleanup (enforced via MariaDB triggers/events)
    limits = {
        maxEntriesPerPlayer = 100,      -- Auto-deletes oldest via trigger
        autoDeleteOldest = true,         -- Managed by database trigger
        expirationDays = 30,             -- Auto-cleanup via scheduled event
    }
}
