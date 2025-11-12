local QBCore = exports['qb-core']:GetCoreObject()
_G.JobQueues = _G.JobQueues or {}

local INTERVAL = 30000  -- 30s

CreateThread(function()
    print('[IGNIS_GROUPS] Queue Thread Started')
    while true do
        Wait(INTERVAL)

        for jobType, queue in pairs(_G.JobQueues) do
            if #queue == 0 then
                print('[IGNIS_GROUPS] No queue')
                goto continue
            end

            local nextGroupId = table.remove(queue, 1)
            local group = Groups[nextGroupId]
            if not group then
                print('[IGNIS_GROUPS] Skipping', nextGroupId, '(group not found in Groups table)')
                goto continue
            end

            print(('[IGNIS_GROUPS] Offering %s to group %s'):format(jobType, nextGroupId))

            local actionData = {
                id = 'Server_Queue'..tostring(math.random(1, 100000)),
                title = 'Job Offer',
                description = ('Start %s mission?'):format(jobType),
                app = 'groups',
                icons = {
                    ['0'] = {
                        icon = "https://ignis-rp.com/uploads/server/phone/cross-circle.svg",
                        isServer = true,
                        event = 'ignis_groups:denyJob',
                        args = { groupId = nextGroupId, jobType = jobType }
                    },
                    ['1'] = {
                        icon = "https://ignis-rp.com/uploads/server/phone/accept.svg",
                        isServer = true,
                        event = 'ignis_groups:acceptJob',
                        args = { groupId = nextGroupId, jobType = jobType }
                    }
                }
            }

            for _, member in ipairs(group.members or {}) do
                local cid = member.cid or member
                local ply = QBCore.Functions.GetPlayerByCitizenId(cid)
                if ply then
                    local src = ply.PlayerData.source
                    print(('[IGNIS_GROUPS] Sending notification to %s (%s)'):format(src, cid))
                    TriggerClientEvent('phone:addActionNotification', src, json.encode(actionData))
                else
                    print(('[IGNIS_GROUPS] Skipping %s — player not found'):format(cid))
                end
            end

            ::continue::
        end
    end
end)

RegisterNetEvent('ignis_groups:acceptJob', function(notificationId, data)
    TriggerClientEvent('phone:client:removeActionNotification', source, notificationId)
    local gid = data.groupId
    local jobType = data.jobType
    local group = Groups[gid]
    if not group then return end

    print(('[IGNIS_GROUPS] Group %s accepted %s job - triggering Rep-Tablet event'):format(gid, jobType))

    -- Fire the legacy tablet client event so escrowed job scripts react normally
    for _, member in ipairs(group.members or {}) do
        local ply = QBCore.Functions.GetPlayerByCitizenId(member.cid)
        if ply then
            print(('[IGNIS_GROUPS] Triggering Rep-Tablet readyforjob for %s (%s)'):format(ply.PlayerData.source, member.cid))
            TriggerClientEvent('rep-tablet:client:readyforjob', ply.PlayerData.source)
        else
            print(('[IGNIS_GROUPS] Could not find player with CID %s (may be offline)'):format(tostring(member.cid)))
        end
    end
end)

RegisterNetEvent('ignis_groups:denyJob', function(notificationId, data)
	TriggerClientEvent('phone:client:removeActionNotification', source, notificationId)
    TriggerClientEvent('ignis_groups:server:readyForJob', data.jobType)
    print(('[IGNIS_GROUPS] Group %s denied %s job'):format(data.groupId, 'houserobbery'))
end)
