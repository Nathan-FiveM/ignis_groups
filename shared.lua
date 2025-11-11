-- Shared globals for ignis_groups
Groups = {}
GroupConfigs = {}

function DebugPrint(msg)
    if GetConvarInt('sv_debug', 0) == 1 then
        print(('[IGNIS_GROUPS] %s'):format(msg))
    end
end