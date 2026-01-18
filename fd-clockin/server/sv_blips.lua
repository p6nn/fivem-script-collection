local UnitsRadar = {
    active = {},
}

local function updateUnitBlip(serverID)
    local isPolice = Player(serverID).state.clockedIn and Player(serverID).state.clockedIn.police
    local isFire = Player(serverID).state.clockedIn and Player(serverID).state.clockedIn.fire

    if isPolice or isFire then
        local role = isPolice and "police" or "fire"
        local playerPed = GetPlayerPed(serverID)
        local coords = GetEntityCoords(playerPed)
        local heading = math.ceil(GetEntityHeading(playerPed))

        local blipColor = role == "police" and 3 or 1
        local blipType = role == "police" and 1 or 2

        UnitsRadar.active[serverID] = {
            name = (role == "police" and "Officer" or "Firefighter") .. " | " .. GetPlayerName(serverID),
            color = blipColor,
            type = blipType,
            coords = coords,
            heading = heading
        }
    else
        UnitsRadar.active[serverID] = nil
    end

    TriggerClientEvent("police:updateBlips", -1, UnitsRadar.active)
end

AddEventHandler("playerDropped", function()
    local serverID = source
    UnitsRadar.active[serverID] = nil
    TriggerClientEvent("police:updateBlips", -1, UnitsRadar.active)
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        for _, playerID in pairs(GetPlayers()) do
            updateUnitBlip(playerID)
        end
    end
end)

lib.callback.register("police:getBlipData", function(source)
    return UnitsRadar.active
end)
