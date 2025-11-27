CreateThread(function()
    FW = ServerOnLoad()
end)

-- Global groups table comes from shared.lua, but ensure it exists
Groups    = Groups or {}
ActiveVPN = ActiveVPN or {}

local function FormatGroup(gid, g)
    if not g then return {} end

    g.members = g.members or {}

    local members = {}
    local leaderName = g.jobType or ("Group " .. gid)

    for _, m in ipairs(g.members) do
        local isLeader = (m.player == g.leader)

        if isLeader and m.name then
            leaderName = m.name
        end

        members[#members + 1] = {
            cid      = m.cid,
            name     = m.name,
            vpn      = m.vpn or false,
            player   = m.player or 0,
            isLeader = isLeader
        }
    end

    return {
        id      = gid,
        name    = leaderName or ("Group " .. gid), -- 🟢 leader’s name
        jobType = g.jobType or "generic",
        status  = g.status or "idle",
        leader  = g.leader,
        members = members,
        stages  = g.stages or {}
    }
end


local function BuildGroupsArray()
    local groupsArray = {}
    for gid, g in pairs(Groups) do
        groupsArray[#groupsArray + 1] = FormatGroup(gid, g)
    end
    return groupsArray
end

local function SanitizeGroup(g)
    -- convert legacy boolean status into proper string
    if g.status == true then
        g.status = "active"
    elseif g.status == false then
        g.status = "idle"
    end

    -- always ensure members is a table
    g.members = g.members or {}

    return g
end


--- Send phone notification (fallback to QBCore:Notify)
local function SendPhoneNotification(src, title, msg, app, timeout)
    if not src then return end
    local jsonData = json.encode({
        id = ('group_%s'):format(math.random(1000, 9999)),
        title = title or 'Group System',
        description = msg or 'No message provided',
        app = app or 'groups',
        timeout = timeout or 5000,
    })
    TriggerClientEvent('phone:addnotiFication', src, jsonData)
end

-- Simple debug helper (respects sv_debug convar)
local function DebugPrint(msg)
    --if GetConvarInt('sv_debug', 0) == 1 then
        print(('[IGNIS_GROUPS] %s'):format(msg))
    --end
end

-- Get "Firstname Lastname" for a player
local function GetPlayerCharName(src)
    local Player = ServerGetPlayer(src)
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
            local Player = ServerGetPlayerByCitizenId(m.cid)
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
        
        group = SanitizeGroup(group)
        local formattedGroup = FormatGroup(groupId, group)
        formattedGroup.members = groupMembers  -- keep detailed member entries

        for _, m in ipairs(group.members or {}) do
            local Player = ServerGetPlayerByCitizenId(m.cid)
            if Player then
                local src = Player.PlayerData.source
                TriggerClientEvent('summit_phone:client:updateGroupsApp', src, "setInGroup", true)
                TriggerClientEvent('summit_phone:client:updateGroupsApp', src, 'setCurrentGroup', formattedGroup)
            end
        end
        TriggerClientEvent('summit_phone:client:updateGroupsApp', -1, "setGroups", BuildGroupsArray())
    end)
end

-- ####################################################################
-- # CORE GROUP EVENTS
-- ####################################################################

-- Create new group (with optional password & jobType)
RegisterNetEvent('ignis_groups:server:createGroup', function(jobType, pass)
    local src    = source
    local Player = ServerGetPlayer(src)
    if not Player then return end

    local cid     = Player.PlayerData.citizenid
    local hasVpn  = HasVPN(Player)
    local id      = ('%s_%d'):format(cid, math.random(1000, 9999))
    local name    = hasVpn and GenerateAlias(cid) or GetPlayerCharName(src)

    print('Hit the server state and should set nghe in phone to: ', jobType)

    -- === GROUP SIZE LIMIT CHECK ===
    local maxGroupSize = Config.GroupPlayerLimits[jobType] or Config.DefaultGroupLimit
    if maxGroupSize < 1 then maxGroupSize = Config.DefaultGroupLimit end

    -- forward to NUI
    TriggerClientEvent('summit_phone:client:updateGroupsApp', src, "setPlayerJobState", jobType)

    -- group starts with 1 member (the creator) ALWAYS allowed

    Groups[id] = SanitizeGroup({
        id       = id,
        leader   = src,
        jobType  = jobType or 'Generic',
        members  = {
            { cid = cid, name = name, player = src, vpn = hasVpn }
        },
        password = pass or nil,
        ready    = false,
        stages   = {},
        status   = "idle",    -- ✔ good default
    })


    DebugPrint(('Group %s created by src=%s (cid=%s, job=%s)'):format(id, src, cid, jobType or 'Generic'))

    TriggerClientEvent("summit_phone:client:updateGroupsApp", src, "setInGroup", true)

    TriggerClientEvent("summit_phone:client:updateGroupsApp", src, "setCurrentGroup", {
        jobType = jobType,
        members = Groups[id].members,
        leader  = src,
        id      = id,
    })

    TriggerClientEvent('ignis_groups:client:updateGroups', -1, BuildGroupsArray())

    TriggerClientEvent("ignis_groups:client:syncClientData", src, {
        groupID = id,
        leader  = src
    })
    RefreshGroupUI(id)
end)

-- Leave current group
RegisterNetEvent('ignis_groups:server:leaveGroup', function()
    local src    = source
    local Player = ServerGetPlayer(src)
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
                        end
                    end

                    TriggerClientEvent('ignis_groups:client:updateGroups', -1, BuildGroupsArray())

                    if Groups[id] then
                        RefreshGroupUI(id)
                    end

                    TriggerClientEvent('summit_phone:client:updateGroupsApp', src, "setCurrentGroup", { jobType = g.jobType, members = {}, id = nil })
                    
                    TriggerClientEvent('summit_phone:client:updateGroupsApp', src, "setInGroup", false)

                    TriggerClientEvent('summit_phone:client:updateGroupsApp', src, "setGroups", BuildGroupsArray())

                    TriggerClientEvent("ignis_groups:client:syncClientData", src, {
                        groupID = id,
                        leader  = g.leader
                    })
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
        local ply = ServerGetPlayerByCitizenId(m.cid)
        if ply then
            local s = ply.PlayerData.source
            TriggerClientEvent('summit_phone:client:updateGroupsApp', s, "setInGroup", false)
            TriggerClientEvent('summit_phone:client:updateGroupsApp', s, 'setCurrentGroup', {})
            TriggerClientEvent('summit_phone:client:updateGroupsApp', s, "setGroups", BuildGroupsArray())
        end
    end

    Groups[id] = nil
    DebugPrint(('Group %s deleted by %s'):format(id, src))

    TriggerClientEvent("ignis_groups:client:syncClientData", src, {
        groupID = id,
        leader  = group.leader
    })
    TriggerClientEvent('ignis_groups:client:updateGroups', -1, BuildGroupsArray())
end)

-- Cleanup on disconnect
AddEventHandler('playerDropped', function()
    local src    = source
    local Player = ServerGetPlayer(src)
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

function CountPlayersInJob(jobType)
    local count = 0
    for _, group in pairs(Groups) do
        if group.jobType == jobType and group.status == "queued" then
            count += (#group.members or 0)
        end
    end
    return count
end

RegisterNetEvent('ignis_groups:server:readyForJob', function()
    local src = source
    local group, id = GetGroupByMembers(src)
    if not group or not id then
        print(('[IGNIS_GROUPS] ReadyForJob called but no valid group found for src=%s'):format(src))
        return
    end

    _G.JobQueues = _G.JobQueues or {}
    local jobType = group.jobType or 'generic'
    _G.JobQueues[jobType] = _G.JobQueues[jobType] or {}

    for _, gid in ipairs(_G.JobQueues[jobType]) do
        if gid == id then
            print(('[IGNIS_GROUPS] Group %s already queued for %s'):format(id, jobType))
            return
        end
    end

    -- Queue Check
    local maxPlayers = Config.JobPlayerLimits[jobType] or 0
    local activePlayers = CountPlayersInJob(jobType)
    local newTotal = activePlayers + #group.members

    if newTotal > maxPlayers then
        ServerNotify(src, "This job’s queue is full!", "error")
        return
    end
    -- Cooldown Check
    for _, member in ipairs(group.members) do
        local cid = member.cid
        local cd = PlayerJobCooldowns[cid]

        if cd and cd.jobType == jobType and cd.expires > os.time() then
            local remaining = cd.expires - os.time()
            ServerNotify(src, ("Cooldown: %ds remaining"):format(remaining), "error")
            return
        end
    end


    group.status = "queued"
    Groups[id].status = "queued"
    table.insert(_G.JobQueues[jobType], id)
    print(('[IGNIS_GROUPS] Queued group %s for %s'):format(id, jobType))

    -- ✅ Send properly formatted data to phones
    local formatted = FormatGroup(id, group)

    for _, member in ipairs(group.members or {}) do
        local ply = ServerGetPlayerByCitizenId(member.cid)
        if ply then
            local s = ply.PlayerData.source

            TriggerClientEvent('summit_phone:client:updateGroupsApp', s, 'setCurrentGroup', formatted)

            local groupsArray = {}
            for gid, g in pairs(Groups) do
                groupsArray[#groupsArray + 1] = FormatGroup(gid, g)
            end
            TriggerClientEvent('summit_phone:client:updateGroupsApp', s, "setGroups", groupsArray)

            SendPhoneNotification(
                s,
                '📋 Group Update',
                ('Your group has joined the %s queue!'):format(jobType),
                'groups',
                6000
            )
        end
    end
end)

RegisterNetEvent('ignis_groups:server:leaveQueue', function()
    local src = source
    local group, id = GetGroupByMembers(src)
    if not group or not id then return end

    local jobType = group.jobType or "generic"
    _G.JobQueues[jobType] = _G.JobQueues[jobType] or {}

    -- Remove from queue
    for index, gid in ipairs(_G.JobQueues[jobType]) do
        if gid == id then
            table.remove(_G.JobQueues[jobType], index)
            break
        end
    end

    -- Update internal state
    group.status = "idle"
    Groups[id].status = "idle"

    print(("[IGNIS_GROUPS] Group %s left queue for %s"):format(id, jobType))

    -- Build formatted object
    local formatted = FormatGroup(id, group)

    -- Update ALL group members' phones
    for _, member in ipairs(group.members or {}) do
        local ply = ServerGetPlayerByCitizenId(member.cid)
        if ply then
            local s = ply.PlayerData.source

            TriggerClientEvent('summit_phone:client:updateGroupsApp', s, 'setCurrentGroup', formatted)

            -- Rebuild entire groups list
            local groupsArray = {}
            for gid, g in pairs(Groups) do
                groupsArray[#groupsArray + 1] = FormatGroup(gid, g)
            end
            TriggerClientEvent('summit_phone:client:updateGroupsApp', s, "setGroups", groupsArray)

            SendPhoneNotification(
                s,
                '📋 Group Update',
                'Your group has left the job queue.',
                'groups',
                6000
            )
        end
    end
end)

-- Returns (groupTable, groupId)
function GetGroupByMembers(src)
    local Player = ServerGetPlayer(src)
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
    local group = Groups[id]
    if not group or not group.members then return nil end

    local list = {}
    for _, m in ipairs(group.members) do
        list[#list + 1] = m.player
    end
    return list
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

    for _, member in ipairs(g.members) do
        local cid = member.cid
        PlayerJobCooldowns[cid] = {
            jobType = g.jobType,
            expires = os.time() + (Config.JobCooldowns[g.jobType] or 0)
        }
    end

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
        local ply = ServerGetPlayerByCitizenId(m.cid)
        if ply then
            local src = ply.PlayerData.source
            SendPhoneNotification(src, title, msg, 'groups', time or 5000)
        end
    end
end
exports('pNotifyGroup', pNotifyGroup)
exports('NotifyGroup', pNotifyGroup)

RegisterNetEvent('ignis_groups:server:groupNotify', function(id, title, msg)
    pNotifyGroup(id, title, msg)
end)

local function GroupEvent(id, event, args)
    if not id or not event then return end
    local members = getGroupMembers(id)
    if not members then return end

    for _, src in ipairs(members) do
        if type(args) == 'table' then
            TriggerClientEvent(event, src, args)
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
        TriggerClientEvent('summit_phone:client:updateGroupsApp', src, "setInGroup", false)
        TriggerClientEvent('summit_phone:client:updateGroupsApp', src, 'setCurrentGroup', {})
        TriggerClientEvent('summit_phone:client:updateGroupsApp', src,  "setGroups", BuildGroupsArray())
        TriggerClientEvent('ignis_groups:client:setGroupJobSteps', src, {})
        SendPhoneNotification(src, 'Group Disbanded', 'Your group has been disbanded.', 'groups', 5000)
    end

    Groups[id] = nil
    print(('[IGNIS_GROUPS] DestroyGroup: %s removed'):format(id))
    TriggerClientEvent("ignis_groups:client:syncClientData", src, {
        groupID = id,
        leader  = group.leader
    })
    TriggerClientEvent('ignis_groups:client:updateGroups', -1, BuildGroupsArray())
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
        local formatted = FormatGroup(gid, g)
        formatted.memberCount = #(g.members or {})
        groupsArray[#groupsArray + 1] = formatted
    end


    local groupMembers = {}
    local stages       = {}

    if group then
        for _, m in ipairs(group.members or {}) do
            local ply = ServerGetPlayerByCitizenId(m.cid)
            local playerId = m.player
            local name = m.name
            if ply and not m.vpn then
                local info = ply.PlayerData.charinfo or {}
                name = ("%s %s"):format(info.firstname or "John", info.lastname or "Doe")
            end
            playerId  = ply.PlayerData.source
            groupMembers[#groupMembers + 1] = {
                name     = name,
                playerId = playerId,
                isLeader = (playerId == group.leader),
            }
        end

        stages = group.stages or {}
    end

    -- 🟢 AUTO-SYNC QUEUED / ACTIVE GROUPS TO PHONES
    if group and (group.status == "queued" or group.status == "active") then
        DebugPrint(('[IGNIS_GROUPS] Auto-syncing group %s (%s) to members'):format(id, group.status))
        for _, member in ipairs(group.members or {}) do
            local ply = ServerGetPlayerByCitizenId(member.cid)
            if ply then
                local s = ply.PlayerData.source
                TriggerClientEvent('summit_phone:client:updateGroupsApp', s, 'setCurrentGroup', FormatGroup(id, group))
                TriggerClientEvent('summit_phone:client:updateGroupsApp', s, "setGroups", BuildGroupsArray())
            end
        end
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

    if not group then
        -- ❌ Not in a group, fallback to job center
        TriggerClientEvent('summit_phone:client:updateGroupsApp', src, "setInGroup", false)
        return
    end

    -- 🟢 If queued or active, push full sync + notification
    if group.status == "queued" or group.status == "active" then
        print(('[IGNIS_GROUPS] Auto-syncing queued/active group %s (%s) to src=%s'):format(id, group.status, src))

        SendPhoneNotification(src, '📋 Group Update', ('Your group is currently %s for a job.'):format(group.status), 'groups', 4000)

        -- ✅ Push sync for all members
        for _, member in ipairs(group.members or {}) do
            local ply = ServerGetPlayerByCitizenId(member.cid)
            if ply then
                local s = ply.PlayerData.source
                TriggerClientEvent('summit_phone:client:updateGroupsApp', s, 'setCurrentGroup', FormatGroup(id, group))
                TriggerClientEvent('summit_phone:client:updateGroupsApp', s, "setGroups", BuildGroupsArray())
            end
        end
    end

    -- ✅ Player is in a group
    RefreshGroupUI(id)
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

-- === CREATE GROUP BLIP ===
exports('CreateBlipForGroup', function(group, name, data)
    if not group or not data then return end
    for _, member in ipairs(Groups[group].members or {}) do
        local Player = ServerGetPlayerByCitizenId(member.cid)
        if Player then
            if member.cid == Player.PlayerData.citizenid then
                TriggerClientEvent('ignis_groups:client:createBlip', Player.PlayerData.source, group, name, data)
            end
        end
    end
end)

-- === REMOVE GROUP BLIP ===
exports('RemoveBlipForGroup', function(group, name)
    if not group then return end
    for _, member in ipairs(Groups[group].members or {}) do
        local Player = ServerGetPlayerByCitizenId(member.cid)
        if Player then
            TriggerClientEvent('ignis_groups:client:removeBlip', Player.PlayerData.source, group, name)
        end
    end
end)

RegisterNetEvent('ignis_groups:server:updateVPN', function(hasVpn)
    local src = source
    local Player = ServerGetPlayer(src)
    if not Player then return end
    local cid = Player.PlayerData.citizenid

    if hasVpn then
        ActiveVPN[cid] = GenerateAlias(cid)
    else
        ActiveVPN[cid] = nil
    end
end)

local JobCenter = {
    -- Non-VPN Jobs
    ['towing'] = {
        vpn = false,
        label = "Towing",
        description = "Help tow broken down vehicles for the city.",
        coords = vector3(-238.94, -1183.74, 0.0),
        JobInformation = [[
            Talk to the Tow Supervisor and sign in to the towing queue through the phone.
            When your group gets a job, the leader pays the refundable bail if configured.
            Pick up the assigned flatbed at the depot and take the keys.
            Follow the GPS to the target vehicle and load it onto your flatbed (tow interaction).
            Return to the depot drop zone, unload the vehicle, and park the truck.
            Collect your paycheck from the supervisor to finish and get your bail back.
        ]],
    },
    ['taxi'] = {
        vpn = false,
        label = "Taxi",
        description = "Drive passengers to their destinations.",
        coords = vector3(909.51, -177.36, 0.0),
        JobInformation = [[
            Clock in through the taxi queue (Groups app) and grab a taxi from the depot.
            Accept a ride offer when it pops; a blip will mark your passenger.
            Drive to the pickup, start your meter, and collect the passenger.
            Follow the GPS to the drop-off and drive safely to the destination.
            End the ride, charge the fare (invoice prompt), and get paid.
            Stay in queue to receive the next fare or clock out when finished.
        ]],
    },
    ['storedelivery'] = {
        vpn = false,
        label = "Store Deliveries",
        description = "Deliver goods to local stores.",
        coords = vector3(153.2579, -3210.59, 0.0),
        JobInformation = [[
            Sign in with the trucking foreman and queue through the Groups app.
            When queued, grab a box truck at the depot; pay the deposit if required.
            Follow the GPS to each marked store drop-off and unload boxes.
            Complete all required drops for the run (progress shows in the phone).
            Return the truck to the depot and park it.
            Collect your paycheck to finish and get your deposit back.
        ]],
    },
    ['sani'] = {
        vpn = false,
        label = "Sanitation Worker",
        description = "Clean up the city as part of the Sanitation Department.",
        coords = vector3(-351.44, -1566.37, 24.23),
        JobInformation = [[
            Sign in with the sanitation foreman and queue through the Groups app.
            When your group is ready, the leader spawns the Trashmaster and shares keys.
            Drive to Zone 1 and collect trash bags from marked bins/dumpsters; toss them into the truck.
            After Zone 1 is complete, drive to Zone 2 and repeat the bag collection and loading.
            Return the Trashmaster to the depot when both zones are done.
            Have the leader collect the paycheck to finish the run.
        ]],
    },
    ['mining'] = {
        vpn = false,
        label = "Mining Crew",
        description = "Mine valuable ores deep in the quarry.",
        coords = vector3(-598.545, 2096.533, 0.0),
        JobInformation = [[
            Sign in with the mine foreman and queue via the Groups app.
            When your group is ready, head to the quarry and start mining stone.
            Wash the mined stone at the wash station to clean your materials.
            Sell the washed stone/materials to finish the run.
            Stages update in the phone as you mine, wash, and sell.
        ]],
    },
    ['chickens'] = {
        vpn = false,
        label = "Chicken Farmer",
        description = "Process chickens and collect meat for local restaurants.",
        coords = vector3(-138.396, -248.935, 43.0),
        JobInformation = [[
            Talk to the farmer NPC and start the chicken job in the phone queue.
            Accept the job offer in the Groups app when your turn comes up.
            Follow the farm blip and catch live chickens (E when prompted).
            Portion the meat at cut tables, then pack at packing tables.
            Sell the packaged chickens at the marked sell spot to finish and get paid.
        ]],
    },
    ['fishing'] = {
        vpn = false,
        label = "Fishing",
        description = "Catch fish to sell at the docks or markets.",
        coords = vector3(-335.15, 6105.79, 0.0),
        JobInformation = [[
            Sign in with the fishing boss and queue through the Groups app.
            When your group is ready, follow the GPS to the marked fishing spot.
            Fish at the spot to build up your catch totals.
            Return to the boss and collect your paycheck for the haul.
            Sell extra fish at the pier for additional profit.
        ]],
    },
    ['hunting'] = {
        vpn = false,
        label = "Hunting",
        description = "Hunt animals in the wilderness and sell pelts for cash.",
        coords = vector3(-679.34, 5800.97, 17.33),
        JobInformation = [[
            Sign in with the hunting guide and queue through the Groups app.
            Buy bait/knife from the hunting shop, then head to the marked hunting grounds.
            Place bait, wait for animals, and take them down safely.
            Skin the animals for pelts and meat.
            Sell pelts/meat at the hunting buyer to cash out.
        ]],
    },
    ['lumber'] = {
        vpn = false,
        label = "Lumberjack",
        description = "Chop down trees and sell lumber.",
        coords = vector3(1167.73, -1347.27, 33.92),
        JobInformation = [[
            Sign in with the lumber foreman and queue through the Groups app.
            Grab your axe and chop the marked trees to hit the required log count.
            Process the chopped logs at the lumber processing station.
            Sell the processed lumber to the buyer for payout.
            Sign out/collect any bonus once chop and process goals are met.
        ]],
    },
    ['panning'] = {
        vpn = false,
        label = "Gold Panning",
        description = "Pan for gold in rivers and streams.",
        coords = vector3(-1931.76, 1345.193, 214.41),
        JobInformation = [[
            Sign in with the gold panning boss and queue through the Groups app.
            Grab your pan and head to the marked river spot when the job is ready.
            Pan the water to collect paydirt and small nuggets.
            Wash/refine your paydirt to separate the gold.
            Sell the refined gold to the buyer for your payout.
        ]],
    },
    ['postop'] = {
        vpn = false,
        label = "PostOp Worker",
        description = "Deliver mail and packages across the city.",
        coords = vector3(-432.51, -2787.98, 0.0),
        JobInformation = "Pick up packages from the PostOp depot. Follow GPS markers to each delivery address, drop the items, and return to the depot to get paid.",
    },

    -- VPN-Required Jobs
    ['diving'] = {
        vpn = true,
        label = "Diving",
        description = "Recover crates and materials from underwater wrecks.",
        coords = vector3(-1706.41, -1035.66, 13.02), -- example waypoint: diving shop/boat pickup
        JobInformation = [[
            Sign in at the diving spot and queue through the Groups app.
            Grab your gear/boat and head to the marked dive location.
            Dive down and collect the crates/loot from the wreck or seabed.
            Bring the loot back to the surface/boat and return to shore.
            Sell or hand in the recovered materials to get paid.
        ]],
    },
    ['theftcar'] = {
        vpn = true,
        label = "Chop Shop",
        description = "Steal cars and strip them for valuable parts.",
        coords = 'ignis_chopshop:client:setWaypoint',
        JobInformation = [[
            Use a VPN and queue through the Groups app for a chop job.
            Get the target vehicle location and steal it quietly.
            Deliver the vehicle to the chop shop waypoint without attracting police.
            Strip/dismantle the vehicle at the chop shop as instructed.
            Get paid for the parts once the chop is complete.
        ]],
    },
    ['oxyrun'] = {
        vpn = true,
        label = "Oxy Run",
        description = "Deliver 'packages' around the city for extra cash.",
        coords = 'ignis_oxyrun:client:setDealerWaypoint', -- first dealer spawn as waypoint
        JobInformation = [[
            Use a VPN and queue through the Groups app for an oxy run.
            Steal a car to use for deliveries (keep it low-key).
            Meet the supplier in Sandy to pick up your oxy packages.
            Deliver the required packages to city buyers, then finish the remaining drops in Paleto.
            Keep heat low; complete all drops to secure full payout.
        ]],
    },
    ['taco'] = {
        vpn = true,
        label = "Taco Shop",
        description = "Run an underground taco stand.",
        coords = 'rep-weed:client:chiduong',
        JobInformation = [[
            Use a VPN and queue through the Groups app for the taco delivery gig.
            Head to the taco shop to sign in and package the weed tacos.
            Steal or grab the marked delivery vehicle for your run.
            Deliver all taco packages to the marked customers around the city.
            Return to the shop after deliveries to finish and get paid.
        ]],
    },
    ['houserobbery'] = {
        vpn = true,
        label = "House Robbery",
        description = "Break into homes and grab valuables.",
        coords = vector3(706.8385, -965.994, 0.0),
        JobInformation = [[
            Use a VPN and queue through the Groups app for a house job.
            Get the target house location and bring lockpicks/tools.
            Break in quietly, search rooms for valuables, and avoid alarms/residents.
            Grab loot quickly and leave the area before police respond.
            Fence the stolen goods to get paid and clear your bag.
        ]],
    },
}

local function PlayerHasVPN(Player)
    local items = Player.Functions.GetItemsByName('vpn')
    return items and #items > 0
end

-- Return job list to phone
lib.callback.register('ignis_groups:server:getAvailableJobs', function(source)
    local available = {}
    local Player = ServerGetPlayer(source)
    if not Player then return {} end
    local hasVPN = PlayerHasVPN(Player)
    for id, data in pairs(JobCenter) do
        if not data.vpn or (data.vpn and hasVPN) then

            local maxPlayers = Config.JobPlayerLimits[id] or 6
            local activePlayers = CountPlayersInJob(id) or 0

            table.insert(available, {
                id = id,
                label = data.label,
                description = data.description,
                coords = {
                    x = data.coords.x,
                    y = data.coords.y,
                    z = data.coords.z
                },
                vpn = data.vpn or false,
                -- 🔥 NEW: required by phone UI
                capacity = activePlayers,
                maxCapacity = maxPlayers,
            })
        end
    end
    return available
end)

-- Return job info payload for the phone UI
lib.callback.register('ignis_groups:server:getJobInfo', function(source, data)
    local jobId = type(data) == "table" and data.jobId or data
    if not jobId then return nil end

    local jobData = JobCenter[jobId]
    if not jobData then return nil end

    local info = jobData.JobInformation or jobData.description or "No information available."

    return {
        id = jobId,
        label = jobData.label,
        description = jobData.description,
        vpn = jobData.vpn or false,
        information = info,
    }
end)

-- Handle GPS button
RegisterNetEvent('ignis_groups:server:setJobWaypoint', function(data)
    local src = source
    local jobId = data and data.jobId or data
    local jobData = JobCenter[jobId]

    if jobData then
        local c = jobData.coords
        if jobId == 'oxyrun' or jobId == 'taco' or jobId == 'theftcar' then
            TriggerClientEvent(c, src)
        end
        TriggerClientEvent('ignis_groups:client:setWaypoint', src, { x = c.x, y = c.y, z = c.z }, jobData.label)
    else
        print(('[SUMMIT_PHONE] Unknown jobId %s'):format(jobId))
    end
end)

-- Send Job Info Email to Player
RegisterNetEvent('ignis_groups:server:sendJobInfoEmail', function(jobId)
    local src = source
    local Player = ServerGetPlayer(src)
    if not Player then return end

    local jobData = JobCenter[jobId]
    if not jobData then
        print(('[SUMMIT_PHONE] Unknown jobId for email: %s'):format(jobId))
        return
    end

    -- Use JobInformation if available, otherwise fallback to description
    local jobInfo = jobData.JobInformation or jobData.description or "No information available."

    local emailSubject = ('Job Info - %s'):format(jobData.label)
    local emailMessage = string.format([[
        Hello %s,

        ──────────────────────────────

        Here’s your job breakdown for %s

        ──────────────────────────────

        📋 Summary:
        %s

        ──────────────────────────────

        Remember to complete your duties carefully and return to base for payment.

        City Job Center
    ]],
        Player.PlayerData.charinfo.firstname,
        jobData.label,
        jobInfo
    )
    local citizenId = Player.PlayerData.citizenid
    local emailAddress = exports['summit_phone']:GetEmailIdByCitizenId(citizenId)

    if emailAddress then
        emailData = {
            email = emailAddress,
            subject = emailSubject,
            message = emailMessage,
        }
        TriggerEvent('ignis_phone:sendNewMail', src, emailData)
    end
end)

lib.callback.register('ignis_groups:getGroupsForJob', function(source, data)
    print('ignis_groups hit the callback getGroupsForJob')
    local jobType = data.jobType or data  -- support both forms
    print(("ignis_groups getGroupsForJob src=%s jobType=%s"):format(source, tostring(jobType)))
    if not jobType then return {} end

    DebugPrint("ignis_groups getGroupsForJob", source, jobType)

    local results = {}

    for id, group in pairs(Groups) do

        -- fix old broken group data
        group = SanitizeGroup(group)

        if group.jobType == jobType then
            table.insert(results, {
                id = id,
                jobType = group.jobType,
                leader = group.leader,
                memberCount = #(group.members or {}),
                status = group.status,
                members = group.members,
            })
        end
    end

    return results
end)

RegisterNetEvent('ignis_groups:server:joinGroup', function(data)
    local src  = source
    local gid  = data.groupId or data.id
    local pass = data.pass or ""

    DebugPrint("JoinGroup REQUEST: incoming gid =", gid)

    if not gid or not Groups[gid] then
        ServerNotify(src, 'Group not found', 'error')
        return
    end

    local group   = Groups[gid]
    local Player  = ServerGetPlayer(src)
    if not Player then return end

    local cid     = Player.PlayerData.citizenid

    -- password check
    if group.password and group.password ~= pass then
        ServerNotify(src, 'Incorrect password', 'error')
        return
    end

    -- already in ANY group
    for _, g in pairs(Groups) do
        for _, m in ipairs(g.members or {}) do
            if m.cid == cid then
                ServerNotify(src, 'You are already in a group', 'error')
                return
            end
        end
    end

    -- send join request to leader instead of auto-joining
    local leaderSrc = group.leader
    if not leaderSrc then
        ServerNotify(src, 'Group leader unavailable', 'error')
        return
    end

    local requesterName = GetPlayerCharName(src)

    local joinRequest = {
        id = 'joinRequest_' .. gid .. "_" .. cid .. "_" .. math.random(1000,9999),
        title = "Group Join Request",
        description = requesterName .. " wants to join your group",
        app = "groups",
        icons = {
            ['0'] = {
                icon = "https://ignis-rp.com/uploads/server/phone/cross-circle.svg",
                isServer = true,
                event = 'ignis_groups:server:denyJoin',
                args = { requester = src, groupId = gid }
            },
            ['1'] = {
                icon = "https://ignis-rp.com/uploads/server/phone/accept.svg",
                isServer = true,
                event = 'ignis_groups:server:acceptJoin',
                args = { requester = src, groupId = gid }
            }
        }
    }

    TriggerClientEvent('phone:addActionNotification', leaderSrc, json.encode(joinRequest))
    ServerNotify(src, 'Join request sent to group leader', 'primary')
end)
-- ============================================================
-- The LEADER accepts the join request
-- ============================================================
RegisterNetEvent('ignis_groups:server:acceptJoin', function(notificationId, data)
    local leaderSrc = source
    local requester = data.requester
    local gid       = data.groupId

    TriggerClientEvent('phone:client:removeActionNotification', leaderSrc, notificationId)

    local group = Groups[gid]
    if not group then return end

    local Player = ServerGetPlayer(requester)
    if not Player then return end

    local cid     = Player.PlayerData.citizenid
    local hasVpn  = HasVPN(Player)
    local name    = hasVpn and GenerateAlias(cid) or GetPlayerCharName(requester)

    group.members[#group.members + 1] = {
        cid    = cid,
        name   = name,
        player = requester,
        vpn    = hasVpn
    }

    DebugPrint(("[IGNIS_GROUPS] Leader %s accepted %s → group %s"):format(leaderSrc, requester, gid))

    ServerNotify(requester, 'You joined the group!', 'success')
    ServerNotify(leaderSrc, 'Player added to group', 'success')

    RefreshGroupUI(gid)
end)
-- ============================================================
-- The LEADER denies the join request
-- ============================================================
RegisterNetEvent('ignis_groups:server:denyJoin', function(notificationId, data)
    local leaderSrc = source
    local requester = data.requester

    TriggerClientEvent('phone:client:removeActionNotification', leaderSrc, notificationId)

    DebugPrint(("[IGNIS_GROUPS] Leader %s denied join request for %s"):format(leaderSrc, requester))

    ServerNotify(requester, 'Your request was denied', 'error')
end)

RegisterNetEvent('ignis_groups:server:signOutJob', function()
    local src = source
    local group, id = GetGroupByMembers(src)
    if not group or not id then return end

    group.status = "idle"
    print(("[IGNIS_GROUPS] Player %s signed out of job; group %s reset to idle"):format(src, id))

    RefreshGroupUI(id)
end)

RegisterCommand('dummygroupsani', function(source)
    local id = "dummy_" .. math.random(1000, 9999)

    Groups[id] = {
        id       = id,
        leader   = 0,           -- not tied to any player
        jobType  = "sani",
        status   = "idle",
        password = false,
        stages   = {},
        members  = {
            {
                cid    = "npc_sani",
                name   = "AI Worker",
                player = 0,      -- IMPORTANT → not a real session
                vpn    = false,
            }
        }
    }


    DebugPrint(("Dummy group %s created for job 'sani'"):format(id))
    TriggerClientEvent('ignis_groups:client:updateGroups', -1, Groups)
    RefreshGroupUI(id)
end)
