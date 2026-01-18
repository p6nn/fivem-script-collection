local meters = {}

local function nowSeconds()
    return os.time()
end

local function clampMinutes(minutes)
    minutes = tonumber(minutes)
    if not minutes then return nil end
    if minutes < 1 then return nil end
    if minutes > 180 then return nil end
    return math.floor(minutes)
end

local function getPriceForMinutes(minutes)
    for i = 1, #Config.Pricing do
        local row = Config.Pricing[i]
        if row.minutes == minutes then
            return row.price
        end
    end
    return nil
end

local function isNearMeter(src, meterCoords)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local c = GetEntityCoords(ped)
    local dx = c.x - meterCoords.x
    local dy = c.y - meterCoords.y
    local dz = c.z - meterCoords.z
    return (dx * dx + dy * dy + dz * dz) <= (Config.ServerDistanceCheck * Config.ServerDistanceCheck)
end

local function remainingSeconds(key)
    local state = meters[key]
    if not state then return 0 end
    local rem = state.expiresAt - nowSeconds()
    if rem <= 0 then
        meters[key] = nil
        return 0
    end
    return rem
end

lib.callback.register('pen-parkingmeter:server:checkMeter', function(src, key, meterCoords)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false, 0, 'Player not found.' end
    if type(key) ~= 'string' or not meterCoords then return false, 0, 'Invalid request.' end
    if not isNearMeter(src, meterCoords) then return false, 0, 'Too far from meter.' end

    return true, remainingSeconds(key)
end)

lib.callback.register('pen-parkingmeter:server:payMeter', function(src, key, meterCoords, minutes)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false, 'Player not found.' end
    if type(key) ~= 'string' or not meterCoords then return false, 'Invalid request.' end
    if not isNearMeter(src, meterCoords) then return false, 'Too far from meter.' end

    minutes = clampMinutes(minutes)
    if not minutes then return false, 'Invalid minutes.' end

    local price = getPriceForMinutes(minutes)
    if not price then return false, 'That duration is not available.' end

    local ok = Config.PayMoney(player, price)
    if not ok then return false, 'Not enough money.' end

    local cur = remainingSeconds(key)
    local added = minutes * 60
    local base = nowSeconds()
    if cur > 0 then
        base = base + cur
    end

    meters[key] = {
        expiresAt = base + added
    }

    local total = remainingSeconds(key)
    local mins = math.floor(total / 60)
    local secs = total - (mins * 60)

    return true, ('Paid. Time left: %d:%02d'):format(mins, secs)
end)