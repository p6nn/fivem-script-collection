local currentVehicle = 0
local currentSeat = -1
LocalPlayer.state.inVehicle = false

CreateThread(function()
    while true do
        Wait(500) -- Check every 500ms (can be adjusted for performance)
        
        local playerPed = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        local seat = -1

        if vehicle ~= 0 then
            seat = GetPedInVehicleSeat(vehicle, -1) == playerPed and 0 or -1
            for i = 0, GetVehicleModelNumberOfSeats(GetEntityModel(vehicle)) - 2 do
                if GetPedInVehicleSeat(vehicle, i) == playerPed then
                    seat = i
                end
            end
        end

        -- Player just entered a vehicle
        if vehicle ~= 0 and vehicle ~= currentVehicle then
            currentVehicle = vehicle
            currentSeat = seat

            TriggerEvent('pen-util:client:enteredVehicle', vehicle, seat)
        end

        -- Player just exited a vehicle
        if vehicle == 0 and currentVehicle ~= 0 then
            TriggerEvent('pen-util:client:exitedVehicle', currentVehicle)
            currentVehicle = 0
            currentSeat = -1
        end
    end
end)

RegisterNetEvent('pen-util:client:enteredVehicle', function(vehicle, seat)
    LocalPlayer.state.inVehicle = true
end)
RegisterNetEvent('pen-util:client:exitedVehicle', function(vehicle) 
    LocalPlayer.state.inVehicle = false
end)