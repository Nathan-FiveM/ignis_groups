FRAMEWORK()
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
            -- Send job offer ONLY to the leader
            local leaderSrc = group.leader
            local leaderPly = GETPLAYER(leaderSrc)

            if leaderPly then
                print(('[IGNIS_GROUPS] Sending job offer ONLY to leader %s for group %s'):format(leaderSrc, nextGroupId))
                TriggerClientEvent('phone:addActionNotification', leaderSrc, json.encode(actionData))
            else
                print(('[IGNIS_GROUPS] Leader %s not found when offering job %s'):format(leaderSrc, jobType))
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

    print(('[IGNIS_GROUPS] Group %s accepted %s job - triggering event'):format(gid, jobType))

    for _, member in ipairs(group.members or {}) do
        local ply = GETPLAYERBYCID(member.cid)
        if ply then
            local playerId = member.player or member.playerId or 0
            print(('[IGNIS_GROUPS] Triggering readyforjob for %s (%s)'):format(playerId, member.cid))
            -- TriggerClientEvent('rep-tablet:client:readyforjob', playerId)
            TriggerClientEvent('ignis_groups:client:readyforjob', playerId)
        else
            print(('[IGNIS_GROUPS] Could not find player with CID %s (may be offline)'):format(tostring(member.cid)))
        end
    end
end)

RegisterNetEvent('ignis_groups:denyJob', function(notificationId, data)
    TriggerClientEvent('phone:client:removeActionNotification', source, notificationId)
    local gid = data.groupId
    local jobType = data.jobType
    if not gid or not jobType then return end

    -- ensure JobQueues exists for this job type
    _G.JobQueues[jobType] = _G.JobQueues[jobType] or {}

    -- ✅ Re-insert the group at the end of the queue
    table.insert(_G.JobQueues[jobType], gid)
    print(('[IGNIS_GROUPS] Group %s declined %s — moved to back of queue'):format(gid, jobType))
end)