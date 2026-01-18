local registeredDialogs = {}
local enableDebug = false

function registerDialogs(dialogTable)
    if type(dialogTable) ~= "table" then
        return false, "Invalid dialog table"
    end

    for id, dialog in pairs(dialogTable) do
        if type(dialog) == "table" then
            dialog.id = dialog.id or id
            registeredDialogs[id] = dialog
        end
    end

    if enableDebug then
        local count = 0
        for _ in pairs(registeredDialogs) do count = count + 1 end
        print('[SimpleDialogs] Registered dialogs:', count)
    end

    return true
end

function getDialog(id)
    return registeredDialogs[id]
end

function getAllDialogs()
    return registeredDialogs
end

function clearDialogs()
    registeredDialogs = {}
    return true
end

RegisterNetEvent('simple-dialogs:server:getDialog', function(dialogId, callback)
    local source = source
    local dialog = registeredDialogs[dialogId]

    if callback then
        callback(dialog)
    else
        TriggerClientEvent('simple-dialogs:client:receiveDialog', source, dialog)
    end
end)

exports('registerDialogs', registerDialogs)
exports('getDialog', getDialog)
exports('getAllDialogs', getAllDialogs)
exports('clearDialogs', clearDialogs)
