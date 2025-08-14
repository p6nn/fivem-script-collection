
function SpawnPersistentTable(row)
    local coords = vector3(row.coords.x, row.coords.y, row.coords.z)
    RequestModel(Config.MethTable.model)
    while not HasModelLoaded(Config.MethTable.model) do Wait(10) end
    local obj = CreateObject(Config.MethTable.model, coords.x, coords.y, coords.z, true, false, false)
    SetEntityHeading(obj, row.heading or 0.0)
    FreezeEntityPosition(obj, true)
    local netId = NetworkGetNetworkIdFromEntity(obj)
    placedTables[row.id] = { id = row.id, object = obj, coords = coords, netId = netId, currentStep = row.current_step or 1, isActive = row.is_active == 1, isWaiting = row.is_waiting == 1 }
    methStatus[row.id] = { currentStep = row.current_step or 1, isActive = row.is_active == 1, isWaiting = row.is_waiting == 1, waitEndTime = row.wait_end or nil, owner = row.citizenid }
    exports.ox_target:addEntity(netId, {
        { name = 'pickup_meth_table_'..row.id, icon = 'fas fa-hand-paper', label = 'Pick up Meth Table', onSelect = function() PickupMethTable(row.id) end },
        { name = 'cook_meth_'..row.id, icon = 'fas fa-fire', label = 'Cook Meth', onSelect = function() OpenCookingMenu(row.id) end }
    })
end

function PlaceMethTable()
    local p = PlayerPedId()
    local c = GetEntityCoords(p)
    local heading = GetEntityHeading(p)
    local fwd = GetEntityForwardVector(p)
    local place = vector3(c.x + fwd.x * 2.0, c.y + fwd.y * 2.0, c.z - 1.0)
    for _, tbl in pairs(placedTables) do
        if #(place - tbl.coords) < 3.0 then lib.notify({ description = 'There is already a meth table nearby', type = 'error' }); return end
    end
    local created = lib.callback.await('pen-meth:server:createTable', place, heading)
    if not created or not created.ok then
        lib.notify({ description = 'Unable to place table', type = 'error' })
        return
    end
    RequestModel(Config.MethTable.model)
    while not HasModelLoaded(Config.MethTable.model) do Wait(10) end
    local obj = CreateObject(Config.MethTable.model, place.x, place.y, place.z, true, false, false)
    SetEntityHeading(obj, heading)
    FreezeEntityPosition(obj, true)
    local netId = NetworkGetNetworkIdFromEntity(obj)
    placedTables[created.id] = { id = created.id, object = obj, coords = place, netId = netId, currentStep = 1, isActive = false }
    methStatus[created.id] = { currentStep = 1, isActive = false, isWaiting = false, waitEndTime = nil, owner = created.owner }
    exports.ox_target:addEntity(netId, {
        { name = 'pickup_meth_table_'..created.id, icon = 'fas fa-hand-paper', label = 'Pick up Meth Table', onSelect = function() PickupMethTable(created.id) end },
        { name = 'cook_meth_'..created.id, icon = 'fas fa-fire', label = 'Cook Meth', onSelect = function() OpenCookingMenu(created.id) end }
    })
    lib.notify({ description = 'Meth table placed', type = 'success' })
    DebugPrint('Placed meth table '..created.id)
end

function PickupMethTable(tableId)
    local t = placedTables[tableId]
    if not t then DebugPrint('Missing table '..tostring(tableId)); return end
    if t.isActive then lib.notify({ description = 'Cannot pick up while cooking is active', type = 'error' }); return end
    local s = methStatus[tableId]
    if s.currentStep > 1 and s.currentStep <= #Config.CookingSteps then
        local alert = lib.alertDialog({ header = 'Warning', content = 'Picking up loses progress. Continue?', centered = true, cancel = true })
        if alert ~= 'confirm' then return end
        if s.isWaiting then s.isWaiting = false s.waitEndTime = nil end
    end
    local res = lib.callback.await('pen-meth:server:pickupTable', tableId, s.currentStep, s.isWaiting)
    if not res or not res.ok then
        lib.notify({ description = 'Unable to pick up table', type = 'error' })
        return
    end
    exports.ox_target:removeEntity(t.netId)
    if DoesEntityExist(t.object) then DeleteEntity(t.object) end
    placedTables[tableId] = nil
    methStatus[tableId] = nil
    lib.notify({ description = 'Meth table picked up', type = 'success' })
    DebugPrint('Picked up meth table '..tableId)
end

AddEventHandler('onResourceStop', function(r)
    if GetCurrentResourceName() ~= r then return end
    for _, t in pairs(placedTables) do
        exports.ox_target:removeEntity(t.netId)
        if DoesEntityExist(t.object) then DeleteEntity(t.object) end
    end
end)
