local QBCore = exports['qb-core']:GetCoreObject()

-- Global groups table comes from shared.lua, but ensure it exists
Groups    = Groups or {}
ActiveVPN = ActiveVPN or {}

--- Send phone notification (fallback to QBCore:Notify)
local function SendPhoneNotification(src, title, msg, app, timeout)
    if not src then return end

    if GetResourceState('summit_phone') == 'started' then
        exports['summit_phone']:sendNotification({
            id = ('group_%s'):format(math.random(1000, 9999)),
            title = title or 'Group System',
            description = msg or 'No message provided',
            app = app or 'groups',
            timeout = timeout or 5000,
        })
    else
        TriggerClientEvent('QBCore:Notify', src, msg or 'Notification', 'primary', timeout or 5000)
    end
end

-- Simple debug helper (respects sv_debug convar)
local function DebugPrint(msg)
    if GetConvarInt('sv_debug', 0) == 1 then
        print(('[IGNIS_GROUPS] %s'):format(msg))
    end
end

-- Get "Firstname Lastname" for a player
local function GetPlayerCharName(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return "Unknown" end
    local info = Player.PlayerData.charinfo or {}
    return ("%s %s"):format(info.firstname or "John", info.lastname or "Doe")
end

-- Does this player have a VPN item?
local function HasVPN(Player)
    if not Player or not Player.PlayerData or not Player.PlayerData.items then return false end
    for _, item in pairs(Player.PlayerData.items) do
        if item and item.name == 'vpn' then
            return true
        end
    end
    return false
end

-- Per-session alias for VPN users
local function GenerateAlias(cid)
    if ActiveVPN[cid] then return ActiveVPN[cid] end

    local adjectives = { "Silent", "Crimson", "Shadow", "Ghost", "Neon", "Iron", "Lucky", "Silver", "Hidden", "Frost" }
    local animals    = { "Fox", "Wolf", "Raven", "Panther", "Viper", "Falcon", "Cobra", "Tiger", "Hawk", "Lynx" }

    local alias = ("%s %s"):format(
        adjectives[math.random(#adjectives)],
        animals[math.random(#animals)]
    )

    ActiveVPN[cid] = alias
    return alias
end

-- ####################################################################
-- # PHONE UI BRIDGE
-- ####################################################################

local function RefreshGroupUI(groupId)
    CreateThread(function()
        Wait(200) -- give a tick for data to settle

        local group = Groups[groupId]
        if not group then
            DebugPrint(('RefreshGroupUI aborted, group %s not found'):format(groupId))
            return
        end

        DebugPrint(('RefreshGroupUI %s (%d members)'):format(groupId, #(group.members or {})))

        local groupMembers = {}

        for _, m in ipairs(group.members or {}) do
            local Player = QBCore.Functions.GetPlayerByCitizenId(m.cid)
            local name   = m.name or "Unknown"
            local playerId = m.player or 0

            if Player then
                local info = Player.PlayerData.charinfo or {}
                name      = ("%s %s"):format(info.firstname or "John", info.lastname or "Doe")
                playerId  = Player.PlayerData.source
            end

            groupMembers[#groupMembers + 1] = {
                name     = name,
                playerId = playerId,
                isLeader = (playerId == group.leader),
            }
        end

        local formattedGroup = {
            id      = groupId,
            name    = group.jobType or ('Group ' .. groupId),
            leader  = group.leader,
            members = groupMembers,
            status  = group.status or 'idle',
            stages  = group.stages or {},
            jobType = group.jobType or 'Generic',
        }

        for _, m in ipairs(group.members or {}) do
            local Player = QBCore.Functions.GetPlayerByCitizenId(m.cid)
            if Player then
                local src = Player.PlayerData.source
                TriggerClientEvent('summit_phone:client:updateGroupsApp', src, 'setInGroup', true)
                TriggerClientEvent('summit_phone:client:updateGroupsApp', src, 'setCurrentGroup', formattedGroup)
                TriggerClientEvent('summit_phone:client:updateGroupsApp', src, 'setGroups', Groups)
            end
        end
    end)
end

-- ####################################################################
-- # CORE GROUP EVENTS
-- ####################################################################

-- Create new group (with optional password & jobType)
RegisterNetEvent('ignis_groups:server:createGroup', function(jobType, pass)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local cid     = Player.PlayerData.citizenid
    local hasVpn  = HasVPN(Player)
    local id      = ('%s_%d'):format(cid, math.random(1000, 9999))
    local name    = hasVpn and GenerateAlias(cid) or GetPlayerCharName(src)

    Groups[id] = {
        id       = id,
        leader   = src,                       -- leader = server id (rep-tablet compat)
        jobType  = jobType or 'Generic',
        members  = {
            { cid = cid, name = name, player = src, vpn = hasVpn }
        },
        password = pass or nil,
        ready    = false,
        stages   = {},
        status   = false,
    }

    DebugPrint(('Group %s created by src=%s (cid=%s, job=%s)'):format(id, src, cid, jobType or 'Generic'))

    TriggerClientEvent('ignis_groups:client:updateGroups', -1, Groups)
    TriggerClientEvent('ignis_groups:client:syncGroups',   -1, Groups)

    RefreshGroupUI(id)
end)

-- Join existing group
RegisterNetEvent('ignis_groups:server:joinGroup', function(groupId, pass)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local cid    = Player.PlayerData.citizenid

    local group = Groups[groupId]
    if not group then
        TriggerClientEvent('QBCore:Notify', src, 'Group not found', 'error')
        return
    end

    if group.password and group.password ~= pass then
        TriggerClientEvent('QBCore:Notify', src, 'Incorrect password', 'error')
        return
    end

    -- Already in any group?
    for _, g in pairs(Groups) do
        for _, m in ipairs(g.members or {}) do
            if m.cid == cid then
                TriggerClientEvent('QBCore:Notify', src, 'You are already in a group', 'error')
                return
            end
        end
    end

    -- Already in this group?
    for _, m in ipairs(group.members or {}) do
        if m.cid == cid then
            TriggerClientEvent('QBCore:Notify', src, 'You are already in this group', 'error')
            return
        end
    end

    local hasVpn = HasVPN(Player)
    local name   = hasVpn and GenerateAlias(cid) or GetPlayerCharName(src)

    group.members[#group.members + 1] = {
        cid    = cid,
        name   = name,
        player = src,
        vpn    = hasVpn,
    }

    DebugPrint(('Player %s joined group %s'):format(src, groupId))

    TriggerClientEvent('ignis_groups:client:updateGroups', -1, Groups)
    TriggerClientEvent('ignis_groups:client:syncGroups',   -1, Groups)
    RefreshGroupUI(groupId)
end)

-- Leave current group
RegisterNetEvent('ignis_groups:server:leaveGroup', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local cid    = Player.PlayerData.citizenid

    for id, g in pairs(Groups) do
        if g.members then
            for i, m in ipairs(g.members) do
                if m.cid == cid then
                    table.remove(g.members, i)

                    if #g.members == 0 then
                        Groups[id] = nil
                        DebugPrint(('Group %s disbanded (last member left)'):format(id))
                    else
                        if g.leader == src then
                            local newLeader = g.members[1] and g.members[1].player
                            g.leader = newLeader
                            DebugPrint(('Group %s new leader: %s'):format(id, tostring(newLeader)))
                            RefreshGroupUI(id)
                        end
                    end

                    TriggerClientEvent('ignis_groups:client:updateGroups', -1, Groups)
                    TriggerClientEvent('ignis_groups:client:syncGroups',   -1, Groups)

                    if Groups[id] then
                        RefreshGroupUI(id)
                    end

                    TriggerClientEvent('summit_phone:client:updateGroupsApp', src, 'setInGroup', false)
                    TriggerClientEvent('summit_phone:client:updateGroupsApp', src, 'setCurrentGroup', {})
                    TriggerClientEvent('summit_phone:client:updateGroupsApp', src, 'setGroups', Groups)
                    return
                end
            end
        end
    end
end)

-- Delete group (leader disbands)
RegisterNetEvent('ignis_groups:server:deleteGroup', function()
    local src = source
    local group, id = GetGroupByMembers(src)
    if not group or not id then return end

    local g = Groups[id]
    if not g then return end

    local members = g.members or {}

    for _, m in ipairs(members) do
        local ply = QBCore.Functions.GetPlayerByCitizenId(m.cid)
        if ply then
            local s = ply.PlayerData.source
            TriggerClientEvent('summit_phone:client:updateGroupsApp', s, 'setInGroup', false)
            TriggerClientEvent('summit_phone:client:updateGroupsApp', s, 'setCurrentGroup', {})
            TriggerClientEvent('summit_phone:client:updateGroupsApp', s, 'setGroups', Groups)
        end
    end

    Groups[id] = nil
    DebugPrint(('Group %s deleted by %s'):format(id, src))

    TriggerClientEvent('ignis_groups:client:updateGroups', -1, Groups)
end)

-- Cleanup on disconnect
AddEventHandler('playerDropped', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local cid    = Player.PlayerData.citizenid

    for id, g in pairs(Groups) do
        if g.members then
            for i, m in ipairs(g.members) do
                if m.cid == cid or m.player == src then
                    table.remove(g.members, i)

                    if #g.members == 0 then
                        Groups[id] = nil
                        DebugPrint(('Group %s removed (disconnect, now empty)'):format(id))
                    else
                        if g.leader == src then
                            local newLeader = g.members[1] and g.members[1].player
                            g.leader = newLeader
                            DebugPrint(('Group %s new leader after disconnect: %s'):format(id, tostring(newLeader)))
                        end
                        RefreshGroupUI(id)
                    end

                    ActiveVPN[cid] = nil
                    return
                end
            end
        end
    end

    ActiveVPN[cid] = nil
end)

-- ####################################################################
-- # QUEUE / READY FOR JOB
-- ####################################################################

RegisterNetEvent('ignis_groups:server:readyForJob', function()
    local src = source
    local group, id = GetGroupByMembers(src)
    if not group or not id then return end

    _G.JobQueues = _G.JobQueues or {}

    local jobType = group.jobType or 'generic'
    _G.JobQueues[jobType] = _G.JobQueues[jobType] or {}

    for _, gid in ipairs(_G.JobQueues[jobType]) do
        if gid == id then
            DebugPrint(('Group %s already queued for %s'):format(id, jobType))
            return
        end
    end

    table.insert(_G.JobQueues[jobType], id)
    DebugPrint(('Queued group %s for %s'):format(id, jobType))

    TriggerClientEvent('summit_phone:client:updateGroupsApp', src, 'setGroupJobSteps', {
        { id = 1, name = 'Waiting for job offer...', isDone = false }
    })
end)

-- ####################################################################
-- # EXPORTS (rep-tablet compatibility)
-- ####################################################################

-- Returns (groupTable, groupId)
function GetGroupByMembers(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return nil, nil end

    local cid = Player.PlayerData.citizenid

    for id, group in pairs(Groups) do
        if group.members then
            for _, m in ipairs(group.members) do
                if m.cid == cid then
                    return group, id
                end
            end
        end
    end

    return nil, nil
end
exports('GetGroupByMembers', GetGroupByMembers)

local function GetGroupLeader(groupRef)
    if not groupRef then return nil end

    if type(groupRef) == 'table' then
        return groupRef.leader
    elseif Groups[groupRef] then
        return Groups[groupRef].leader
    end

    return nil
end
exports('GetGroupLeader', GetGroupLeader)

local function getGroupMembers(id)
    if not id then return nil end
    local g = Groups[id]
    if not g or not g.members then return nil end

    local temp = {}
    for _, m in ipairs(g.members) do
        temp[#temp + 1] = m.player -- server IDs
    end
    return temp
end
exports('getGroupMembers', getGroupMembers)

local function getGroupSize(id)
    local g = Groups[id]
    if not g or not g.members then return 0 end
    return #g.members
end
exports('getGroupSize', getGroupSize)

local function setJobStatus(id, stages)
    if not id then return end
    local g = Groups[id]
    if not g then return end

    g.status = true
    g.stages = stages or {}

    local members = getGroupMembers(id)
    if members then
        for _, src in ipairs(members) do
            TriggerClientEvent('ignis_groups:client:setGroupJobSteps', src, g.stages)
            TriggerClientEvent('summit_phone:client:updateGroupsApp', src, 'setGroupJobSteps', g.stages)
            SendPhoneNotification(src, 'Job Started', ('Your group began a %s mission!'):format(g.jobType or 'task'), 'groups', 6000)
        end
    end

    print(('[IGNIS_GROUPS] setJobStatus: %s started (%d stages)'):format(id, #(stages or {})))
end
exports('setJobStatus', setJobStatus)

local function resetJobStatus(id)
    if not id then return end
    local g = Groups[id]
    if not g then return end

    g.status = false
    g.stages = {}

    local members = getGroupMembers(id)
    if members then
        for _, src in ipairs(members) do
            TriggerClientEvent('ignis_groups:client:setGroupJobSteps', src, {})
            TriggerClientEvent('summit_phone:client:updateGroupsApp', src, 'setGroupJobSteps', {})
            SendPhoneNotification(src, 'Job Update', 'Group job has been reset.', 'groups', 5000)
        end
    end
end
exports('resetJobStatus', resetJobStatus)

local function pNotifyGroup(id, title, msg, icon, color, time)
    local g = Groups[id]
    if not g then return end

    for _, m in ipairs(g.members or {}) do
        local ply = QBCore.Functions.GetPlayerByCitizenId(m.cid)
        if ply then
            local src = ply.PlayerData.source
            SendPhoneNotification(src, title, msg, 'groups', time or 5000)
        end
    end
end
exports('pNotifyGroup', pNotifyGroup)
exports('NotifyGroup', pNotifyGroup)


local function GroupEvent(id, event, args)
    if not id or not event then return end
    local members = getGroupMembers(id)
    if not members then return end

    for _, src in ipairs(members) do
        if type(args) == 'table' then
            TriggerClientEvent(event, src, table.unpack(args))
        elseif args ~= nil then
            TriggerClientEvent(event, src, args)
        else
            TriggerClientEvent(event, src)
        end
    end

    -- Optional: auto log when triggered for debugging
    if GetConvarInt('sv_debug', 0) == 1 then
        print(('[IGNIS_GROUPS] GroupEvent "%s" sent to %d members of %s'):format(event, #members, id))
    end
end
exports('GroupEvent', GroupEvent)

local function isGroupLeader(src, id)
    if not id then return false end
    local leader = GetGroupLeader(id)
    return leader == src
end
exports('isGroupLeader', isGroupLeader)

local function DestroyGroup(id)
    if not id then return end
    local g = Groups[id]
    if not g then return end

    local members = getGroupMembers(id) or {}
    for _, src in ipairs(members) do
        TriggerClientEvent('summit_phone:client:updateGroupsApp', src, 'setInGroup', false)
        TriggerClientEvent('summit_phone:client:updateGroupsApp', src, 'setCurrentGroup', {})
        TriggerClientEvent('summit_phone:client:updateGroupsApp', src, 'setGroups', Groups)
        TriggerClientEvent('ignis_groups:client:setGroupJobSteps', src, {})
        SendPhoneNotification(src, 'Group Disbanded', 'Your group has been disbanded.', 'groups', 5000)
    end

    Groups[id] = nil
    print(('[IGNIS_GROUPS] DestroyGroup: %s removed'):format(id))
    TriggerClientEvent('ignis_groups:client:updateGroups', -1, Groups)
end
exports('DestroyGroup', DestroyGroup)

exports('GetAllGroups', function()
    return Groups
end)

-- ####################################################################
-- # OX_LIB CALLBACKS (phone NUI)
-- ####################################################################

lib.callback.register('ignis_groups:getSetupAppData', function(source)
    DebugPrint(('getSetupAppData called by %s'):format(source))

    local src = source
    local group, id = GetGroupByMembers(src)

    local groupsArray = {}

    for gid, g in pairs(Groups) do
        groupsArray[#groupsArray + 1] = {
            id          = gid,
            name        = g.jobType or ('Group ' .. gid),
            memberCount = #(g.members or {}),
            status      = g.status and 'busy' or 'idle',
            leader      = g.leader,
            members     = g.members or {},
            jobType     = g.jobType or 'Generic',
        }
    end

    local groupMembers = {}
    local stages       = {}

    if group then
        for _, m in ipairs(group.members or {}) do
            local ply = QBCore.Functions.GetPlayerByCitizenId(m.cid)
            local name = m.name
            local playerId = m.player

            if ply then
                local info = ply.PlayerData.charinfo or {}
                name      = ("%s %s"):format(info.firstname or "John", info.lastname or "Doe")
                playerId  = ply.PlayerData.source
            end

            groupMembers[#groupMembers + 1] = {
                name     = name,
                playerId = playerId,
                isLeader = (playerId == group.leader),
            }
        end

        stages = group.stages or {}
    end

    return {
        groups      = groupsArray,
        groupData   = groupMembers,
        inGroup     = group ~= nil,
        groupStages = stages,
    }
end)

lib.callback.register('ignis_groups:getGroupData', function(source)
    local group = GetGroupByMembers(source)
    return group or {}
end)

lib.callback.register('ignis_groups:getGroupJobSteps', function(source)
    local group = GetGroupByMembers(source)
    return (group and group.stages) or {}
end)

lib.callback.register('ignis_groups:getMemberList', function(source)
    local group = GetGroupByMembers(source)
    if not group then return {} end
    local out = {}
    for _, m in ipairs(group.members or {}) do
        out[#out + 1] = m
    end
    return out
end)

RegisterNetEvent('ignis_groups:server:getSetupAppData', function()
    local src = source
    local group, id = GetGroupByMembers(src)

    if group then
        -- Send current group info back to phone
        TriggerClientEvent('summit_phone:client:updateGroupsApp', src, 'setInGroup', true)
        TriggerClientEvent('summit_phone:client:updateGroupsApp', src, 'setCurrentGroup', group)
    else
        -- Fallback: job center
        TriggerClientEvent('summit_phone:client:updateGroupsApp', src, 'setInGroup', false)
    end
end)


-- ####################################################################
-- # DEBUG / ADMIN COMMANDS
-- ####################################################################

RegisterCommand('printgroups', function(src)
    DebugPrint('================= CURRENT GROUPS =================')
    if not next(Groups) then
        DebugPrint('No active groups')
        return
    end
    for id, g in pairs(Groups) do
        DebugPrint(('Group %s | job=%s | leader=%s | members=%d | status=%s'):format(
            id,
            g.jobType or 'none',
            tostring(g.leader),
            #(g.members or {}),
            g.status and 'busy' or 'idle'
        ))
    end
    DebugPrint('==================================================')
end, true)

RegisterCommand('printgroup', function(src, args)
    local target = tonumber(args[1])
    if not target then
        DebugPrint('Usage: /printgroup <playerID>')
        return
    end
    local group, id = GetGroupByMembers(target)
    if not group then
        DebugPrint(('Player %s not in any group'):format(target))
        return
    end
    DebugPrint(('--- Group for player %s (id=%s) ---'):format(target, id))
    DebugPrint(json.encode(group, { indent = true }))
end, true)

RegisterNetEvent('ignis_groups:server:printMyGroup', function()
    local src = source
    local group, id = GetGroupByMembers(src)
    if group then
        DebugPrint(('[IGNIS_GROUPS] Player %s is in group %s (%d members)'):format(
            src, id, #(group.members or {})))
    else
        DebugPrint(('[IGNIS_GROUPS] Player %s not in any group'):format(src))
    end
end)