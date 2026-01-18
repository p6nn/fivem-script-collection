AddEventHandler('pen-util:client:enteredVehicle', function(vehicle, seat)
    if vehicle ~= 0 and (seat == -1 or seat == 0) then
        print("[Whitelist] checking vehicle")
        local model = GetEntityModel(vehicle)
        local spawnName = GetDisplayNameFromVehicleModel(model):lower()
        TriggerServerEvent("pen-util:server:checkVehiclePermission", VehToNet(vehicle), spawnName)
    end
end)
