Citizen.CreateThread(function()
    print('[Clock-In] Created Zones')

	for _, data in pairs(Config.Locations) do
		for _, zone in ipairs(data.zones) do
			local newZone = BoxZone:Create(zone.coords, 1.0, 1.0, {
				name = 'Clock-In',
				debugPoly = zone.debug,
				heading = zone.heading,
				minZ = zone.minZ,
				maxZ = zone.maxZ,
			})

            newZone:onPlayerInOut(function(isPointInside, _)
                if isPointInside then
                    isInClockInZone = true
                    currentDepartment = zone.department
                else
                    isInClockInZone = false
                    currentDepartment = nil
                    lib.hideTextUI()
                end
            end)
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        if isInClockInZone and currentDepartment then

            lib.hideTextUI()
            if checkClockedin(currentDepartment) then
                lib.showTextUI('[E] - Clock-Out')
            else
                lib.showTextUI('[E] - Clock-In')
            end

            if IsControlJustPressed(1, 51) then
                toggleClockIn(currentDepartment)
            end
            Citizen.Wait(0)
        else
            Citizen.Wait(500)
        end
    end
end)
