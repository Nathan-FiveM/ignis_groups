QBCore = nil
function FRAMEWORK()
    if Config.Framework == "qbcore" then
        QBCore = exports['qb-core']:GetCoreObject()
    elseif Config.Framework == "qbox" then
        -- QBCore = exports['qb-core']:GetCoreObject() -- Not needed unused unless using QBCore Notify
    end
end

function NOTIFY(title, description, type, timeout)
    if Config.Notify == "qbcore" then
        QBCore.Functions.Notify(description, type)
    elseif Config.Notify == "ox" then
        lib.notify({
            title = title,
            description = description,
            type = type
        })
    end
end