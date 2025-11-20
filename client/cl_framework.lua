function ClientOnLoad()
    if Config.Framework == "qbcore" then
        QBCore = exports['qb-core']:GetCoreObject()
    elseif Config.Framework == "qbox" then
        -- QBCore = exports['qb-core']:GetCoreObject() -- Not needed unused unless using QBCore Notify
    end
end

function ClientNotify(title, description, type, timeout)
    if Config.Notify == "qbcore" then
        return QBCore.Functions.Notify(description, type)
    elseif Config.Notify == "ox" then
        return lib.notify({
            title = title,
            description = description,
            type = type
        })
    end
end