local function roundTo(n, decimals)
    local m = 10 ^ (decimals or 2)
    return math.floor(n * m + 0.5) / m
end

local function meterKeyFromCoords(coords)
    return ('%.2f:%.2f:%.2f'):format(roundTo(coords.x, 2), roundTo(coords.y, 2), roundTo(coords.z, 2))
end

local function getPricingOptions()
    local opts = {}
    for i = 1, #Config.Pricing do
    local row = Config.Pricing[i]
    opts[#opts + 1] = {
        value = row.minutes,
        label = ('%d minutes - $%d'):format(row.minutes, row.price),
    }
    end
    return opts
end

local function openPayDialog(entity, hitCoords)
    local c = GetEntityCoords(entity)
    local key = meterKeyFromCoords(c)

    local res = lib.inputDialog('Pay Parking Meter', {
    {
        type = 'select',
        label = 'Select duration',
        options = getPricingOptions(),
        required = true,
    },
    })

    if not res or not res[1] then return end

    local minutes = tonumber(res[1])
    if not minutes or minutes <= 0 then
        lib.notify({ title = 'Parking Meter', description = 'Invalid selection.', type = 'error' })
        return
    end

    lib.callback('pen-parkingmeter:server:payMeter', false, function(ok, msg)
    if ok then
        lib.notify({ title = 'Parking Meter', description = msg or 'Paid.', type = 'success' })
    else
        lib.notify({ title = 'Parking Meter', description = msg or 'Failed.', type = 'error' })
    end
    end, key, c, minutes)
end

local function checkMeter(entity)
    local c = GetEntityCoords(entity)
    local key = meterKeyFromCoords(c)

    lib.callback('pen-parkingmeter:server:checkMeter', false, function(ok, remaining, msg)
    if not ok then
        lib.notify({ title = 'Parking Meter', description = msg or 'Failed.', type = 'error' })
        return
    end

    if not remaining or remaining <= 0 then
        lib.notify({ title = 'Parking Meter', description = 'This meter is expired.', type = 'inform' })
        return
    end

    local mins = math.floor(remaining / 60)
    local secs = remaining - (mins * 60)
    lib.notify({
        title = 'Parking Meter',
        description = ('Time left: %d:%02d'):format(mins, secs),
        type = 'inform',
    })
    end, key, c)
end

CreateThread(function()
  exports.ox_target:addModel(Config.MeterModels, {
    {
        name = 'pen-parkingmeter:client:pay',
        icon = 'fa-solid fa-coins',
        label = 'Pay Meter',
        distance = Config.TargetDistance,
        onSelect = function(data)
            openPayDialog(data.entity, data.coords)
        end,
    },
    {
        name = 'pen-parkingmeter:client:check',
        icon = 'fa-solid fa-clock',
        label = 'Check Meter',
        distance = Config.TargetDistance,
        onSelect = function(data)
            checkMeter(data.entity)
        end,
    }})
end)