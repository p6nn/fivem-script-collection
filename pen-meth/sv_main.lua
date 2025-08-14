
local QBX = exports.qbx_core

local function notify(src, msg, type_, dur)
    TriggerClientEvent('ox_lib:notify', src, { description = msg, type = type_ or 'inform', duration = dur or 5000 })
end

local function getPlayer(src)
    return QBX:GetPlayer(src)
end

local function DebugPrint(message)
    if Config.Debug then print('[PEN-METH SERVER] ' .. message) end
end

local function genId(citizenid)
    return ('%s_%d_%d'):format(citizenid or 'unknown', GetGameTimer(), math.random(1000,9999))
end

lib.callback.register('pen-meth:server:createTable', function(source, coords, heading)
    local src = source
    local player = getPlayer(src)
    if not player then return { ok = false, err = 'no_player' } end
    local has = player.Functions.GetItemByName(Config.MethTable.item)
    if not has or has.amount < 1 then return { ok = false, err = 'no_item' } end
    local removed = player.Functions.RemoveItem(Config.MethTable.item, 1)
    if not removed then return { ok = false, err = 'remove_fail' } end
    local id = genId(player.PlayerData.citizenid)
    local inserted = MySQL.insert.await('INSERT INTO pen_meth_tables (id, citizenid, x, y, z, heading, current_step, is_active, is_waiting, wait_end) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        id, player.PlayerData.citizenid, coords.x, coords.y, coords.z, heading, 1, 0, 0, 0
    })
    if not inserted then return { ok = false, err = 'db_insert_fail' } end
    DebugPrint('Created table '..id..' for '..player.PlayerData.citizenid)
    return { ok = true, id = id, owner = player.PlayerData.citizenid }
end)

lib.callback.register('pen-meth:server:getTables', function(source)
    local rows = MySQL.query.await('SELECT id, citizenid, x, y, z, heading, current_step, is_active, is_waiting, wait_end FROM pen_meth_tables', {}) or {}
    for i=1,#rows do
        rows[i].coords = { x = rows[i].x, y = rows[i].y, z = rows[i].z }
        rows[i].x, rows[i].y, rows[i].z = nil, nil, nil
    end
    return rows
end)

lib.callback.register('pen-meth:server:pickupTable', function(source, tableId, currentStep, isWaiting)
    local src = source
    local player = getPlayer(src)
    if not player then return { ok = false, err = 'no_player' } end
    if not tableId or type(tableId) ~= 'string' then return { ok = false, err = 'bad_id' } end
    local row = MySQL.single.await('SELECT citizenid, current_step FROM pen_meth_tables WHERE id = ? LIMIT 1', { tableId })
    if not row then return { ok = false, err = 'not_found' } end
    if row.citizenid ~= player.PlayerData.citizenid then return { ok = false, err = 'not_owner' } end
    if Config.Refund and Config.Refund.enabled and currentStep and currentStep > 1 then
        TriggerEvent('pen-meth:server:refundFromStep', src, currentStep)
    end
    local deleted = MySQL.update.await('DELETE FROM pen_meth_tables WHERE id = ?', { tableId })
    if not deleted or deleted < 1 then return { ok = false, err = 'db_delete_fail' } end
    player.Functions.AddItem(Config.MethTable.item, 1)
    return { ok = true }
end)

RegisterNetEvent('pen-meth:server:statusUpdate', function(tableId, status)
    local src = source
    if not tableId or type(status) ~= 'table' then return end
    MySQL.update.await('UPDATE pen_meth_tables SET current_step = ?, is_active = ?, is_waiting = ?, wait_end = ? WHERE id = ?', {
        status.currentStep or 1,
        status.isActive and 1 or 0,
        status.isWaiting and 1 or 0,
        status.waitEndTime or 0,
        tableId
    })
end)

RegisterNetEvent('pen-meth:server:removeItem', function(item, amount)
    local src = source
    local player = getPlayer(src)
    if not player then return end
    if not item or not amount or amount < 1 then return end
    player.Functions.RemoveItem(item, amount)
end)

RegisterNetEvent('pen-meth:server:giveItem', function(item, amount, quality)
    local src = source
    local player = getPlayer(src)
    if not player then return end
    local success = false
    if quality and Config.MethQuality and Config.MethQuality.enabled then
        if not quality.purity then quality.purity = 75 end
        local finalAmount = math.ceil(amount * (quality.multiplier or 1.0))
        local metadata = { quality = quality.name, purity = (quality.purity or 75)..'%', color = quality.color, description = 'Quality: '..(quality.name or 'Average')..' ('..(quality.purity or 75)..'% purity)' }
        success = player.Functions.AddItem(item, finalAmount, false, metadata)
        if success then notify(src, 'You received '..finalAmount..'x '..(quality.name or 'Average')..' '..item, 'success') end
    else
        success = player.Functions.AddItem(item, amount)
        if success then notify(src, 'You received '..amount..'x '..item, 'success') end
    end
    if not success then DebugPrint('Give item failed for '..src) end
end)

RegisterNetEvent('pen-meth:server:checkAndRemoveItem', function(tableId, item, amount, stepId)
    local src = source
    local player = getPlayer(src)
    if not player then return end
    local has = player.Functions.GetItemByName(item)
    if has and has.amount >= amount then
        local ok = player.Functions.RemoveItem(item, amount)
        TriggerClientEvent('pen-meth:client:itemCheckResponse', src, tableId, stepId, ok and true or false)
    else
        TriggerClientEvent('pen-meth:client:itemCheckResponse', src, tableId, stepId, false)
    end
end)

RegisterNetEvent('pen-meth:server:refundFromStep', function(src, currentStep)
    local player = getPlayer(src)
    if not player then return end
    if not Config.Refund or not Config.Refund.enabled then return end
    local given = false
    for i = 1, (currentStep - 1) do
        local step = Config.CookingSteps[i]
        if step and step.requiredItem then
            local amt = math.ceil(step.requiredAmount * Config.Refund.percentage)
            if amt > 0 then
                player.Functions.AddItem(step.requiredItem, amt)
                given = true
            end
        end
    end
    if given then
        local pct = math.floor((Config.Refund.percentage or 0) * 100)
        notify(src, 'You received '..pct..'% of your ingredients back', 'info')
    end
end)

CreateThread(function()
    while GetResourceState('qbx_core') ~= 'started' do Wait(500) end
    exports.qbx_core:CreateUseableItem(Config.MethTable.item, function(source)
        TriggerClientEvent('pen-meth:client:useMethTable', source)
    end)
end)

AddEventHandler('onResourceStart', function(res)
    if GetCurrentResourceName() ~= res then return end
    print('^2[PEN-METH]^0 started')
end)
