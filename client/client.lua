CreateThread(function()
    ClientOnLoad()
end)
local ActiveBlips = {}

-- === PHONE SYNC EVENTS ===
-- === ALWAYS NORMALIZE GROUP DATA BEFORE SENDING TO PHONE ===

local function NormalizeGroups(groups)
    -- If it's already an array, return it untouched
    if type(groups) == "table" and groups[1] ~= nil then
        return groups
    end

    -- Otherwise convert dictionary → array
    local arr = {}
    for gid, g in pairs(groups or {}) do
        arr[#arr + 1] = g
    end
    return arr
end
RegisterNetEvent("ignis_groups:client:updateGroups", function(groups)
    TriggerEvent('summit_phone:client:updateGroupsApp', "setGroups", groups)
end)

RegisterNetEvent('ignis_groups:client:syncGroups', function(groups)
    TriggerEvent('summit_phone:client:updateGroupsApp', "setGroups", groups)
end)

RegisterNetEvent('ignis_groups:client:updateStatus', function(group, name, stages)
    TriggerEvent('summit_phone:client:updateGroupsApp', "updateStatus", { group = group, name = name, stages = stages })
end)

RegisterNetEvent('ignis_groups:client:setGroupJobSteps', function(stages)
    inJob = true
    TriggerEvent('summit_phone:client:updateGroupsApp', "setGroupJobSteps", stages)
end)

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

RegisterNetEvent('ignis_groups:client:signIn', function(job)
    local jobType = job or 'generic'
    print(('[ignis_groups] Signed in for job: %s'):format(jobType))
    LocalPlayer.state:set('nghe', jobType, false)
    exports['summit_phone']:SendCustomAppMessage('sendPhoneNotification', {
        app = 'groups',
        title = '📋 Group System',
        description = ('Signed in for %s'):format(jobType),
        timeout = 3500
    })
    TriggerServerEvent('ignis_groups:server:createGroup', jobType)
end)

RegisterNetEvent('ignis_groups:client:signOff', function()
    print('[ignis_groups] Signed off from job')
    exports['summit_phone']:SendCustomAppMessage('sendPhoneNotification', {
        app = 'groups',
        title = '📋 Group System',
        description = 'You have signed off from your group job.',
        timeout = 3000
    })
    LocalPlayer.state:set('nghe', nil, true)
end)

RegisterCommand('mygroup', function()
    TriggerServerEvent('ignis_groups:server:printMyGroup')
end)