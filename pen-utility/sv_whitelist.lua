RegisterNetEvent("pen-util:server:checkVehiclePermission", function(netId, spawnName)
    local src = source
    local vehicle = NetworkGetEntityFromNetworkId(netId)

    local allowedRoles = vehicles[spawnName]

    if not allowedRoles then
        return
    end

    local allowed = false
    for _, role in ipairs(allowedRoles) do
        if hasRole(src, role) then
            allowed = true
            break
        end
    end

    if not allowed and DoesEntityExist(vehicle) then
        DeleteEntity(vehicle)
    end
end)
