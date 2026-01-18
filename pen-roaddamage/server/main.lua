local Config = require 'shared.config'

local roadState = {}
local dirty = {}

local function clamp(n, min, max)
    if n < min then return min end
    if n > max then return max end
    return n
end

local function ensureRoad(street)
    local s = roadState[street]
    if s then return s end

    s = {
        damage = 0.0,
        lastDecayAt = GetGameTimer(),
    }

    roadState[street] = s
    return s
end

local function loadAllRoadDamage()
    local rows = MySQL.query.await('SELECT street, damage FROM road_damage', {})
    if not rows then return end

    for i = 1, #rows do
        local row = rows[i]
        local street = tonumber(row and row.street)
        local dmg = tonumber(row and row.damage)

        if street and dmg then
            local s = ensureRoad(street)
            s.damage = clamp(dmg, 0.0, 100.0)
            s.lastDecayAt = GetGameTimer()
        end
    end
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    loadAllRoadDamage()
end)

lib.callback.register('pen-roaddamage:server:reportUsage', function(source, payload)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false end

    if type(payload) ~= 'table' then return false end

    local street = tonumber(payload.street)
    local meters = tonumber(payload.meters)

    if not street or not meters then return false end
    if street < 0 or street > Config.limits.maxStreetKey then return false end
    if meters <= 0.0 or meters > Config.limits.maxMetersPerReport then return false end

    local s = ensureRoad(street)

    local added = meters * Config.damagePerMeter * 100.0
    if added <= 0.0 then return true end

    s.damage = clamp(s.damage + added, 0.0, 100.0)
    dirty[street] = true

    return true
end)

lib.callback.register('pen-roaddamage:server:getDamage', function(source, street)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return nil end

    local k = tonumber(street)
    if not k then return nil end

    local s = ensureRoad(k)
    return s.damage
end)

SetInterval(function()
    local perMinute = tonumber(Config.damageDecayPerMinute) or 0.0
    if perMinute <= 0.0 then return end

    local t = GetGameTimer()

    for street, s in pairs(roadState) do
        local last = tonumber(s.lastDecayAt) or t
        local elapsedMs = t - last

        if elapsedMs > 0 then
            local minutes = elapsedMs / 60000.0
            local dec = perMinute * minutes

            if dec > 0.0 then
                local before = s.damage
                s.damage = clamp(before - dec, 0.0, 100.0)
                s.lastDecayAt = t

                if s.damage ~= before then
                    dirty[street] = true
                end
            end
        end
    end
end, 30000)

SetInterval(function()
    for street in pairs(dirty) do
        local s = roadState[street]
        if s then
            MySQL.update.await([[
                INSERT INTO road_damage (street, damage, updated_at)
                VALUES (?, ?, NOW())
                ON DUPLICATE KEY UPDATE
                    damage = VALUES(damage),
                    updated_at = VALUES(updated_at)
            ]], { street, s.damage })
        end

        dirty[street] = nil
    end
end, Config.saveIntervalMs)