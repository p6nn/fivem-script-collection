local roleList = {}
local discordRoles = {}

Citizen.CreateThread(function()
    TriggerServerEvent("pen-util:PlayerReady")
end)

RegisterNetEvent("pen-util:clientSyncRoles", function(roleListData, userRolesData)
    roleList = roleListData
    discordRoles = userRolesData
end)

function hasRole(role)
    if not discordRoles or not roleList then
        print("^1[Error]^7 discordRoles or roleList is nil, returning false")
        return false
    end

    local roleId = roleList[role]
    if not roleId then
        print("^1[Error]^7 Role '" .. tostring(role) .. "' not found in roleList")
        return false
    end

    for _, id in ipairs(discordRoles) do
        if id == roleId then
            return true
        end
    end

    return false
end
exports('hasRole', hasRole)

function isStaff()
    return lib.callback.await('pen-util:cb:isStaff', false)
end
exports('isStaff', isStaff)

RegisterCommand('hasroletest', function(source, args)
    if not args[1] then
        return
    end
    local role = table.concat(args, " ")

    if hasRole(role) then
        print("^2[Success]^7 You have the role: " .. role)
    else
        print("^1[Denied]^7 You do NOT have the role: " .. role)
    end
end)
