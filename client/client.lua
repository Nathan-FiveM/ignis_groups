local QBCore = exports['qb-core']:GetCoreObject()
local ActiveBlips = {}

-- === BLIPS ===
RegisterNetEvent('ignis_groups:client:createBlip', function(group, name, data)
    if ActiveBlips[name] then RemoveBlip(ActiveBlips[name]) end
    local blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
    SetBlipSprite(blip, data.sprite or 1)
    SetBlipColour(blip, data.color or 0)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(data.label or name)
    EndTextCommandSetBlipName(blip)
    ActiveBlips[name] = blip
end)

RegisterNetEvent('ignis_groups:client:removeBlip', function(group, name)
    if ActiveBlips[name] then
        RemoveBlip(ActiveBlips[name])
        ActiveBlips[name] = nil
    end
end)

------------------------------------------------------------
--  LEGACY EVENT: Job Checkout / SignOut (used by Rep Scripts)
------------------------------------------------------------

-- old tablet used this to mark a player "done"
AddEventHandler('rep-tablet:client:checkout', function()
    print('[REP-TABLET STUB] Checkout triggered (job complete)')
    isSignedIn = false
    LocalPlayer.state:set('nghe', nil, true)
end)

-- === PHONE SYNC EVENTS ===
RegisterNetEvent('ignis_groups:client:syncGroups', function(groups)
    TriggerEvent('summit_phone:client:updateGroupsApp', groups)
end)

RegisterNetEvent('ignis_groups:client:updateStatus', function(group, name, stages)
    TriggerEvent('summit_phone:client:updateGroupsApp', 'updateStatus', { group = group, name = name, stages = stages })
end)

RegisterNetEvent('ignis_groups:client:setGroupJobSteps', function(stages)
    TriggerEvent('summit_phone:client:updateGroupsApp', 'setGroupJobSteps', stages)
end)

-- Legacy closeAllNotification event
RegisterNetEvent('rep-tablet:client:closeAllNotification', function()
    exports['summit_phone']:SendCustomAppMessage('closeNotification', {})
end)

RegisterCommand('mygroup', function()
    TriggerServerEvent('ignis_groups:server:printMyGroup')
end)