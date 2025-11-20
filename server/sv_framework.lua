function ServerOnLoad()
    if Config.Framework == "qbcore" then
        return exports['qb-core']:GetCoreObject()
    elseif Config.Framework == "qbox" then
        -- QBCore = exports['qb-core']:GetCoreObject() -- Not required for QBox
    end
end

function ServerNotify(src, title, description, notifyType, timeout)
    if Config.Notify == "qbcore" then
        return TriggerClientEvent('QBCore:Notify', src, description, type)
    elseif Config.Notify == "ox" then
        return TriggerClientEvent('ox_lib:notify', src, {
            id = title,
            title = title,
            description = description,
            type = notifyType,
        })
    end
end

function ServerCallback()
    if Config.Framework == "qbcore" then
        return
    elseif Config.Framework == "qbox" then
        return
    end
end

function ServerGetPlayer(src)
    if Config.Framework == "qbcore" then
        return FW.Functions.GetPlayer(src)
    elseif Config.Framework == "qbox" then
        return exports.qbx_core:GetPlayer(src)
    end
end

function ServerGetPlayerByCitizenId(cid)
    if Config.Framework == "qbcore" then
        return FW.Functions.GetPlayerByCitizenId(cid)
    elseif Config.Framework == "qbox" then
        return exports.qbx_core:GetPlayerByCitizenId(cid)
    end
end