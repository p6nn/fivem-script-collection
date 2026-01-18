local Config = require 'shared.config'

local tracked = {
    street = nil,
    meters = 0.0,
    last = nil,
    lastReportAt = 0,
    lastSyncAt = 0,
    cachedDamage = {},
}

local function v3dist(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function streetAtCoords(c)
    local streetHash = GetStreetNameAtCoord(c.x, c.y, c.z)
    if not streetHash then return nil end
    return tonumber(streetHash)
end

local function getDamage(street)
    local v = tracked.cachedDamage[street]
    if v == nil then return 0.0 end
    return v
end

local function syncDamage(street)
    local dmg = lib.callback.await('pen-roaddamage:server:getDamage', false, street)
    if dmg == nil then return end
    tracked.cachedDamage[street] = tonumber(dmg) or 0.0
end

local function flushUsage()
    if not tracked.street then return end
    if tracked.meters <= 0.0 then return end

    lib.callback.await('pen-roaddamage:server:reportUsage', 1500, {
        street = tracked.street,
        meters = tracked.meters,
    })

    tracked.meters = 0.0
end

local function tyrePopChance(dmg)
    local minD = tonumber(Config.tirePop.minDamage) or 0.0
    local maxD = tonumber(Config.tirePop.maxDamage) or 100.0
    local base = tonumber(Config.tirePop.baseChancePerSampleAtMax) or 0.0

    if dmg < minD then return 0.0 end
    if maxD <= minD then return base end

    local scaled = (dmg - minD) / (maxD - minD)
    if scaled < 0.0 then scaled = 0.0 end
    if scaled > 1.0 then scaled = 1.0 end

    return base * scaled
end

local function tryPopTyre(v, dmg)
    if not Config.tirePop.enabled then return end

    if Config.tirePop.disableIfBulletproof then
        if not GetVehicleTyresCanBurst(v) then return end
    end

    local chance = tyrePopChance(dmg)
    if chance <= 0.0 then return end

    if math.random() > chance then return end

    local wheel = math.random(0, 5)
    if IsVehicleTyreBurst(v, wheel, false) then return end

    SetVehicleTyreBurst(v, wheel, true, Config.tirePop.burstDamage)
end

SetInterval(function()
    local p = PlayerPedId()
    if not p or p == 0 then return end

    if not IsPedInAnyVehicle(p, false) then
        if tracked.street then
            flushUsage()
        end

        tracked.street = nil
        tracked.last = nil
        return
    end

    local v = GetVehiclePedIsIn(p, false)
    if not v or v == 0 then return end

    if Config.tirePop.onlyDriver then
        if GetPedInVehicleSeat(v, -1) ~= p then return end
    end

    if GetEntitySpeed(v) < Config.minSpeedToCount then return end

    local c = GetEntityCoords(p)
    local street = streetAtCoords(c)
    if not street then return end

    if tracked.last then
        local moved = v3dist(c, tracked.last)

        if moved > 0.1 and moved < 120.0 then
            if tracked.street == street then
                tracked.meters = tracked.meters + moved
            else
                flushUsage()
                tracked.street = street
                tracked.meters = moved
            end
        end
    else
        tracked.street = street
        tracked.meters = 0.0
    end

    tracked.last = c

    local t = GetGameTimer()

    if tracked.street and (t - tracked.lastSyncAt) >= Config.syncIntervalMs then
        tracked.lastSyncAt = t
        syncDamage(tracked.street)
    end

    if tracked.street then
        tryPopTyre(v, getDamage(tracked.street))
    end

    if (t - tracked.lastReportAt) >= Config.reportIntervalMs then
        tracked.lastReportAt = t
        flushUsage()
    end
end, Config.sampleIntervalMs)