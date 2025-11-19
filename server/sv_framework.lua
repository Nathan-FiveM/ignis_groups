QBCore = nil
function FRAMEWORK()
    if Config.Framework == "qbcore" then
        QBCore = exports['qb-core']:GetCoreObject()
    elseif Config.Framework == "qbox" then
        -- QBCore = exports['qb-core']:GetCoreObject() -- Not required for QBox
    end
end

function NOTIFY(src, title, description, notifyType, timeout)
    if Config.Notify == "qbcore" then
        TriggerClientEvent('QBCore:Notify', src, description, type)
    elseif Config.Notify == "ox" then
        TriggerClientEvent('ox_lib:notify', src, {
            id = title,
            title = title,
            description = description,
            type = notifyType,
        })
    end
end

function CALLBACK()
    if Config.Framework == "qbcore" then

    elseif Config.Framework == "qbox" then

    end
end

function GETPLAYER(src)
    if Config.Framework == "qbcore" then
        QBCore.Functions.GetPlayer(src)
    elseif Config.Framework == "qbox" then
        exports.qbx_core:GetPlayer(src)
    end
end

function GETPLAYERBYCID(cid)
    if Config.Framework == "qbcore" then
        QBCore.Functions.GetPlayerByCitizenId(cid)
    elseif Config.Framework == "qbox" then
        exports.qbx_core:GetPlayerByCitizenId(cid)
    end
end