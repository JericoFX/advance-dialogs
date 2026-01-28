local registeredDialogs = {}
local enableDebug = false

function registerDialogs(dialogTable)
    if type(dialogTable) ~= "table" then
        return false, "Invalid dialog table"
    end

    for id, dialog in pairs(dialogTable) do
        if type(dialog) == "table" then
            local idType = type(id)
            local validKey = (idType == "string" and id ~= "") or idType == "number"

            if not validKey then
                print('[AdvanceDialog] Warning: Skipping dialog with invalid id key')
            else
                if dialog.id ~= nil then
                    local dialogIdType = type(dialog.id)
                    local validDialogId = (dialogIdType == "string" and dialog.id ~= "") or dialogIdType == "number"

                    if not validDialogId then
                        print('[AdvanceDialog] Warning: Dialog id invalid, using key:', tostring(id))
                    elseif dialog.id ~= id then
                        print('[AdvanceDialog] Warning: Dialog id mismatch, using key:', tostring(id))
                    end
                end

                dialog.id = id
                registeredDialogs[id] = dialog
            end
        end
    end

    if enableDebug then
        local count = 0
        for _ in pairs(registeredDialogs) do count = count + 1 end
        print('[AdvanceDialog] Registered dialogs:', count)
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

RegisterNetEvent('advance-dialog:server:getDialog', function(dialogId, callbackOrPedNetId)
    local source = source
    local dialog = registeredDialogs[dialogId]

    if type(callbackOrPedNetId) == "function" then
        callbackOrPedNetId(dialog)
        return
    end

    local pedNetId = nil
    if type(callbackOrPedNetId) == "number" then
        pedNetId = callbackOrPedNetId
    end

    TriggerClientEvent('advance-dialog:client:receiveDialog', source, {
        dialog = dialog,
        dialogId = dialogId,
        pedNetId = pedNetId
    })
end)

function openDialogById(targetSource, dialogId, pedNetId)
    if not targetSource or not dialogId then
        return false, "Missing target or dialog id"
    end

    local dialog = registeredDialogs[dialogId]

    TriggerClientEvent('advance-dialog:client:receiveDialog', targetSource, {
        dialog = dialog,
        dialogId = dialogId,
        pedNetId = pedNetId
    })

    return dialog ~= nil
end

exports('registerDialogs', registerDialogs)
exports('getDialog', getDialog)
exports('getAllDialogs', getAllDialogs)
exports('clearDialogs', clearDialogs)
exports('openDialogById', openDialogById)
