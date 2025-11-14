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
RegisterNetEvent("ignis_groups:client:updateGroups", function(groups)
    TriggerEvent('summit_phone:client:updateGroupsApp', 'setGroups', groups)
end)

RegisterNetEvent('ignis_groups:client:syncGroups', function(groups)
    TriggerEvent('summit_phone:client:updateGroupsApp', 'setGroups', groups)
end)

RegisterNetEvent('ignis_groups:client:updateStatus', function(group, name, stages)
    TriggerEvent('summit_phone:client:updateGroupsApp', 'updateStatus', { group = group, name = name, stages = stages })
end)

RegisterNetEvent('ignis_groups:client:setGroupJobSteps', function(stages)
    inJob = true
    TriggerEvent('summit_phone:client:updateGroupsApp', 'setGroupJobSteps', stages)
end)

-- Legacy closeAllNotification event
RegisterNetEvent('rep-tablet:client:closeAllNotification', function()
    exports['summit_phone']:SendCustomAppMessage('closeNotification', {})
end)

local ActiveBlips = {}

-- === CREATE BLIP FOR GROUP ===
RegisterNetEvent('ignis_groups:client:createBlip', function(group, name, data)
    if not data or not data.coords then
        print(('[IGNIS_GROUPS] ⚠️ Invalid blip data for %s: %s'):format(group or 'unknown', json.encode(data)))
        return
    end

    -- Remove old blip if one exists with same name
    if ActiveBlips[name] then
        RemoveBlip(ActiveBlips[name])
    end

    local coords = data.coords
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, data.sprite or 1)
    SetBlipColour(blip, data.color or 0)
    SetBlipScale(blip, 0.9)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(data.label or name or 'Job Location')
    EndTextCommandSetBlipName(blip)

    ActiveBlips[name] = blip

    print(('[IGNIS_GROUPS] Created blip "%s" for group %s'):format(name or 'unknown', group or '?'))
end)

-- === REMOVE GROUP BLIP ===
RegisterNetEvent('ignis_groups:client:removeBlip', function(group, name)
    if ActiveBlips[name] then
        RemoveBlip(ActiveBlips[name])
        ActiveBlips[name] = nil
        print(('[IGNIS_GROUPS] Removed blip "%s" for group %s'):format(name or 'unknown', group or '?'))
    end
end)

exports('GetMyGroup', function(cb)
    QBCore.Functions.TriggerCallback('ignis_groups:getMyGroup', function(data)
        cb(data)
    end)
end)

exports('GetMyGroupLeader', function(cb)
    QBCore.Functions.TriggerCallback('ignis_groups:getGroupLeader', function(leader)
        cb(leader)
    end)
end)

RegisterCommand('mygroup', function()
    TriggerServerEvent('ignis_groups:server:printMyGroup')
end)