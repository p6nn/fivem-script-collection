local active = {}
local inside = {}
local shownBox = nil

local function applyBlackout()
    local blackout = false
    for areaId, isInside in pairs(inside) do
        if isInside and active[areaId] then
            blackout = true
            break
        end
    end

    SetArtificialLightsState(blackout)

    if Config.Blackout and Config.Blackout.KeepVehicleLights then
        SetArtificialLightsStateAffectsVehicles(false)
    else
        SetArtificialLightsStateAffectsVehicles(true)
    end
end

local function showBox(key, label)
    if shownBox == key then return end
    shownBox = key
    lib.showTextUI(('[E] Fix power (%s)'):format(label), { position = 'left-center' })
end

local function hideBox(key)
    if shownBox ~= key then return end
    shownBox = nil
    lib.hideTextUI()
end

local function setupAreas()
    for i = 1, #Config.Areas do
        local a = Config.Areas[i]
        local point = lib.points.new({
            coords = a.center,
            distance = a.radius,
            areaId = a.id
        })

        function point:onEnter()
            inside[self.areaId] = true
            applyBlackout()
        end

        function point:onExit()
            inside[self.areaId] = false
            applyBlackout()
        end
    end
end

local function setupBoxes()
    for i = 1, #Config.Areas do
        local a = Config.Areas[i]
        for j = 1, #a.boxes do
            local b = a.boxes[j]
            local key = a.id .. ':' .. b.id

            local point = lib.points.new({
                coords = b.coords,
                distance = 2.2,
                areaId = a.id,
                boxId = b.id,
                key = key,
                label = a.label
            })

            function point:onEnter()
                if active[self.areaId] then
                    showBox(self.key, self.label)
                end
            end

            function point:onExit()
                hideBox(self.key)
            end

            function point:nearby()
                if not active[self.areaId] then return end
                if not inside[self.areaId] then return end

                if shownBox ~= self.key then
                    showBox(self.key, self.label)
                end

                if IsControlJustReleased(0, 38) then
                    local p = PlayerPedId()
                    if IsPedInAnyVehicle(p, false) then
                        lib.notify({ type = 'error', description = 'Exit your vehicle first.' })
                        return
                    end

                    local ok = lib.progressCircle({
                        duration = Config.Repair.DurationMs or 12000,
                        position = 'bottom',
                        useWhileDead = false,
                        canCancel = true,
                        disable = { move = true, car = true, combat = true },
                    })

                    if not ok then return end

                    local res = lib.callback.await('pen-outages:server:repairBox', false, self.areaId, self.boxId)
                    if type(res) ~= 'table' then
                        lib.notify({ type = 'error', description = 'No response from server.' })
                        return
                    end

                    lib.notify({
                        type = res.ok and 'success' or 'error',
                        description = res.message or (res.ok and 'Power restored.' or 'Repair failed.')
                    })
                end
            end
        end
    end
end

RegisterNetEvent('pen-outages:client:setOutage', function(areaId, isActive)
    if type(areaId) ~= 'string' then return end
    active[areaId] = isActive and true or false
    applyBlackout()
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    setupAreas()
    setupBoxes()

    local state = lib.callback.await('pen-outages:server:getState', false)
    if type(state) == 'table' then
        for areaId, isActive in pairs(state) do
            if type(areaId) == 'string' then
                active[areaId] = isActive and true or false
            end
        end
    end

    applyBlackout()
end)