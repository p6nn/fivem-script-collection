local outages = {}
local lastRepair = {}

local function getArea(areaId)
    for i = 1, #Config.Areas do
        local a = Config.Areas[i]
        if a.id == areaId then
            return a
        end
    end
end

local function persist(areaId, isActive)
    if not Config.Outage.Persist then return end
    pcall(function()
        MySQL.prepare(
            'INSERT INTO pen_outages (area_id, active, started_at) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE active = VALUES(active), started_at = VALUES(started_at)',
            { areaId, isActive and 1 or 0, os.time() }
        )
    end)
end

local function broadcast(areaId, isActive)
    TriggerClientEvent('pen-outages:client:setOutage', -1, areaId, isActive and true or false)
end

local function buildAlertPayload(areaId, state, restoredBy)
    local a = getArea(areaId)
    if not a then return nil end

    local payload = {
        resource = 'pen-outages',
        areaId = areaId,
        areaLabel = a.label,
        state = state,
        restoredBy = restoredBy or 0,
        coords = { x = a.center.x, y = a.center.y, z = a.center.z },
        radius = a.radius,
    }

    if a.boxes and a.boxes[1] and a.boxes[1].coords then
        payload.firstBox = { x = a.boxes[1].coords.x, y = a.boxes[1].coords.y, z = a.boxes[1].coords.z }
    end

    return payload
end

local function runAlert(payload)
    local alert = Config.Alert
    if not alert or not alert.Enabled then return end
    if type(alert.Handler) ~= 'function' then return end
    if type(payload) ~= 'table' then return end
    pcall(function()
        alert.Handler(payload)
    end)
end

local function countActive()
    local n = 0
    for _, s in pairs(outages) do
        if s then n += 1 end
    end
    return n
end

local function setOutage(areaId, isActive, restoredBy)
    if type(areaId) ~= 'string' or areaId == '' then return end
    local a = getArea(areaId)
    if not a then return end

    if isActive then
        if outages[areaId] then return end
        outages[areaId] = true
        persist(areaId, true)
        broadcast(areaId, true)
        if Config.Alert and Config.Alert.OnStart then
            runAlert(buildAlertPayload(areaId, 'outage', 0))
        end
        return
    end

    if not outages[areaId] then return end
    outages[areaId] = nil
    persist(areaId, false)
    broadcast(areaId, false)
    if Config.Alert and Config.Alert.OnRestore then
        runAlert(buildAlertPayload(areaId, 'restored', restoredBy or 0))
    end
end

local function pickArea()
    local candidates = {}
    for i = 1, #Config.Areas do
        local id = Config.Areas[i].id
        if not outages[id] then
            candidates[#candidates + 1] = id
        end
    end
    if #candidates == 0 then return nil end
    return candidates[math.random(1, #candidates)]
end

local function hasItems(src, items)
    if type(items) ~= 'table' or #items == 0 then return true end
    for i = 1, #items do
        local it = items[i]
        local name = it and it.name
        local count = tonumber(it and it.count) or 1
        if type(name) ~= 'string' or name == '' then return false end
        local found = exports.ox_inventory:Search(src, 'count', name)
        if (tonumber(found) or 0) < count then
            return false
        end
    end
    return true
end

local function consumeItems(src, items)
    if type(items) ~= 'table' or #items == 0 then return true end
    for i = 1, #items do
        local it = items[i]
        local name = it and it.name
        local count = tonumber(it and it.count) or 1
        if type(name) ~= 'string' or name == '' then return false end
        if not exports.ox_inventory:RemoveItem(src, name, count) then
            return false
        end
    end
    return true
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    if Config.Outage.Persist then
        pcall(function()
            local rows = MySQL.query.await('SELECT area_id, active FROM pen_outages', {})
            if type(rows) ~= 'table' then return end
            for i = 1, #rows do
                local r = rows[i]
                if r and r.area_id and tonumber(r.active) == 1 then
                    outages[r.area_id] = true
                end
            end
        end)
        for i = 1, #Config.Areas do
            local id = Config.Areas[i].id
            if outages[id] then
                broadcast(id, true)
            end
        end
    end

    CreateThread(function()
        math.randomseed(os.time())
        while true do
            Wait((Config.Outage.RollIntervalSeconds or 120) * 1000)

            if not Config.Outage.Enabled then goto continue end
            if countActive() >= (Config.Outage.MaxActive or 1) then goto continue end

            local chance = tonumber(Config.Outage.ChancePercent) or 5
            chance = math.min(math.max(chance, 0), 100)
            if math.random(1, 100) > chance then goto continue end

            local areaId = pickArea()
            if areaId then
                setOutage(areaId, true, 0)
            end

            ::continue::
        end
    end)
end)

lib.callback.register('pen-outages:server:getState', function(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return nil end

    local state = {}
    for i = 1, #Config.Areas do
        local id = Config.Areas[i].id
        state[id] = outages[id] and true or false
    end
    return state
end)

lib.callback.register('pen-outages:server:repairBox', function(src, areaId, boxId)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return { ok = false, message = 'Player not found.' } end
    if type(areaId) ~= 'string' or type(boxId) ~= 'string' then return { ok = false, message = 'Invalid request.' } end
    if not outages[areaId] then return { ok = false, message = 'Power is already stable here.' } end

    local a = getArea(areaId)
    if not a then return { ok = false, message = 'Invalid area.' } end

    local now = os.time()
    lastRepair[src] = lastRepair[src] or 0
    if (now - lastRepair[src]) < (Config.Repair.CooldownSeconds or 8) then
        return { ok = false, message = 'Slow down.' }
    end
    lastRepair[src] = now

    local valid = false
    for i = 1, #a.boxes do
        if a.boxes[i].id == boxId then
            valid = true
            break
        end
    end
    if not valid then return { ok = false, message = 'Invalid box.' } end

    if not hasItems(src, Config.Repair.RequiredItems) then
        return { ok = false, message = 'You do not have the required items.' }
    end

    if not consumeItems(src, Config.Repair.ConsumeItems) then
        return { ok = false, message = 'Item check failed. Try again.' }
    end

    setOutage(areaId, false, src)
    return { ok = true, message = ('Power restored: %s'):format(a.label) }
end)
