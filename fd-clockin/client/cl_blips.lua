local UnitsRadar = {
    blips = {},
    distant = {},
}

lib.callback.register("police:checkClocked", function()
    return checkClocked()
end)

local function updateBlips(blipData)
    for serverID, data in pairs(blipData) do
        local playerPed = GetPlayerPed(GetPlayerFromServerId(serverID))
        local isDistant = not DoesEntityExist(playerPed)

        if not UnitsRadar.blips[serverID] then
            local blip = isDistant and AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z) or AddBlipForEntity(playerPed)
            SetBlipSprite(blip, data.type)
            SetBlipColour(blip, data.color)
            SetBlipCategory(blip, 7)
            SetBlipAsShortRange(blip, true)

            if not isDistant and data.heading then
                ShowHeadingIndicatorOnBlip(blip, true)
                SetBlipRotation(blip, data.heading)
            end

            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(data.name)
            EndTextCommandSetBlipName(blip)

            UnitsRadar.blips[serverID] = blip
            UnitsRadar.distant[serverID] = isDistant
        else
            if isDistant then
                SetBlipCoords(UnitsRadar.blips[serverID], data.coords.x, data.coords.y, data.coords.z)
            elseif data.heading then
                SetBlipRotation(UnitsRadar.blips[serverID], data.heading)
            end
        end
    end

    for serverID, blip in pairs(UnitsRadar.blips) do
        if not blipData[serverID] then
            RemoveBlip(blip)
            UnitsRadar.blips[serverID] = nil
            UnitsRadar.distant[serverID] = nil
        end
    end
end

RegisterNetEvent("police:updateBlips")
AddEventHandler("police:updateBlips", function(blipData)
    updateBlips(blipData)
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        local role = checkClocked()
        if role then
            local blipData = lib.callback.await("police:getBlipData", false)
            updateBlips(blipData)
        end
    end
end)