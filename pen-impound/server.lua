local function notify(src, msg, type_, dur)
    TriggerClientEvent('ox_lib:notify', src, {
        description = msg,
        type = type_ or 'inform',
        duration = dur or 5000
    })
end

local function getPlayer(src)
    return exports.qbx_core:GetPlayer(src)
end

local function isAuthorizedJobName(jobName)
    for _, j in ipairs(Config.AuthorizedJobs or {}) do
        if j == jobName then return true end
    end
    return false
end

local function parseTimestamp(ts)
    if type(ts) == 'number' then return ts end
    if type(ts) == 'table' then
        return os.time({ year = ts.year, month = ts.month, day = ts.day, hour = ts.hour, min = ts.min, sec = ts.sec })
    end
    if type(ts) == 'string' then
        local Y,m,d,H,M,S = ts:match('(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)')
        if Y then return os.time({ year = tonumber(Y), month = tonumber(m), day = tonumber(d), hour = tonumber(H), min = tonumber(M), sec = tonumber(S) }) end
    end
    return os.time()
end

function CalculateImpoundFee(timestamp)
    local start = parseTimestamp(timestamp)
    local days = math.max(0, math.floor((os.time() - start) / 86400))
    if days < 1 then return Config.ImpoundFees.earlyReleaseFee end
    return (Config.ImpoundFees.base or 0) + (Config.ImpoundFees.perDay or 0) * math.min(days, Config.ImpoundFees.maxDays or days)
end

local function nearestImpoundName(coords)
    local best, bestDist
    for _, z in ipairs(Config.ImpoundZones or {}) do
        local d = #(coords - z.coords)
        if not bestDist or d < bestDist then
            bestDist = d
            best = z.name
        end
    end
    return best
end

function GetAvailableSpawnPoint(zone)
    local points = Config.VehicleSpawnPoints and Config.VehicleSpawnPoints[zone]
    if not points then return nil end
    for i = 1, #points do
        local p = points[i]
        local occupied
        for _, veh in ipairs(GetAllVehicles()) do
            if #(GetEntityCoords(veh) - vector3(p.x, p.y, p.z)) < 3.0 then
                occupied = true
                break
            end
        end
        if not occupied then return p end
    end
end

function spawnVehicle(src, props, spawnPoint)
    local netId = qbx.spawnVehicle({ model = props.model, spawnSource = spawnPoint, warp = false, props = props })
    if not netId then
        notify(src, 'Failed to spawn vehicle', 'error')
        return
    end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 then
        notify(src, 'Failed to resolve spawned vehicle', 'error')
        return
    end
    SetVehicleNumberPlateText(veh, props.plate)
    Entity(veh).state.fuel = props.fuel
    exports.qbx_vehiclekeys:GiveKeys(src, veh, true)
end

lib.callback.register('pen-impound:server:getVehicleOwner', function(_, plate)
    if not plate or plate == '' then return nil end
    local row = MySQL.single.await('SELECT citizenid FROM player_vehicles WHERE plate = ? LIMIT 1', { plate })
    if not row or not row.citizenid then return nil end

    local p = exports.qbx_core:GetPlayerByCitizenId(row.citizenid)
    if p and p.PlayerData and p.PlayerData.charinfo then
        local c = p.PlayerData.charinfo
        return { citizenid = row.citizenid, name = (c.firstname or 'Unknown') .. ' ' .. (c.lastname or '') }
    end

    local prow = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ? LIMIT 1', { row.citizenid })
    if not prow or not prow.charinfo then return { citizenid = row.citizenid, name = 'Unknown' } end
    local info = json.decode(prow.charinfo) or {}
    return { citizenid = row.citizenid, name = (info.firstname or 'Unknown') .. ' ' .. (info.lastname or '') }
end)

lib.callback.register('pen-impound:server:impoundVehicle', function(source, data)
    local src = source
    local player = getPlayer(src)
    if not player or not player.PlayerData then return false end
    if not isAuthorizedJobName(player.PlayerData.job and player.PlayerData.job.name) then return false end
    if not data or not data.plate or not data.model or not data.vehicleProps then return false end

    local zoneName = nearestImpoundName(GetEntityCoords(GetPlayerPed(src)))
    local id = MySQL.insert.await('INSERT INTO vehicle_impounds (plate, model, citizenid, owner_name, fuel, officer, officer_citizenid, job, reason, report_id, impound_location, vehicle_props) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        data.plate, data.model, data.ownerId, data.ownerName, data.fuel,
        (player.PlayerData.charinfo.firstname or '') .. ' ' .. (player.PlayerData.charinfo.lastname or ''),
        player.PlayerData.citizenid, player.PlayerData.job.name, data.reason or 'Unspecified', data.reportId or nil, zoneName, json.encode(data.vehicleProps)
    })
    if not id then return false end

    MySQL.update.await('UPDATE player_vehicles SET state = 2 WHERE plate = ?', { data.plate })

    if data.ownerId then
        local owner = exports.qbx_core:GetPlayerByCitizenId(data.ownerId)
        if owner and owner.PlayerData and owner.PlayerData.source then
            notify(owner.PlayerData.source, (Config.Locale and Config.Locale.impoundNotification) and string.format(Config.Locale.impoundNotification, data.plate, data.reason or 'Unspecified') or ('Your vehicle '..data.plate..' was impounded'), 'error', (Config.NotifyDuration or 5000))
        end
    end

    return true
end)

lib.callback.register('pen-impound:server:getImpoundedVehicles', function(source)
    local src = source
    local player = getPlayer(src)
    if not player or not player.PlayerData then return {} end
    local rows = MySQL.query.await('SELECT * FROM vehicle_impounds WHERE citizenid = ? AND released = 0 ORDER BY timestamp DESC', { player.PlayerData.citizenid }) or {}
    for i = 1, #rows do rows[i].fee = CalculateImpoundFee(rows[i].timestamp) end
    return rows
end)

lib.callback.register('pen-impound:server:retrieveVehicle', function(source, impoundId, zone)
    local src = source
    local player = getPlayer(src)
    if not player or not player.PlayerData then return { success = false, message = 'Player not found' } end
    if not impoundId then return { success = false, message = 'Invalid request' } end

    local impound = MySQL.single.await('SELECT * FROM vehicle_impounds WHERE id = ? AND released = 0 LIMIT 1', { impoundId })
    if not impound then return { success = false, message = (Config.Locale and Config.Locale.vehicleNotFound) or 'Vehicle not found' } end
    if impound.citizenid ~= player.PlayerData.citizenid then return { success = false, message = (Config.Locale and Config.Locale.noPermission) or 'Not allowed' } end

    local fee = CalculateImpoundFee(impound.timestamp)
    local cash = (player.PlayerData.money and player.PlayerData.money.cash) or 0
    local bank = (player.PlayerData.money and player.PlayerData.money.bank) or 0
    if cash < fee and bank < fee then return { success = false, message = (Config.Locale and Config.Locale.insufficientFunds) or 'Insufficient funds' } end

    local point = GetAvailableSpawnPoint(zone)
    if not point then return { success = false, message = (Config.Locale and Config.Locale.noAvailableSpawn) or 'No available spawn point' } end

    if cash >= fee then exports.qbx_core:RemoveMoney(src, 'cash', fee, 'vehicle-impound-fee') else exports.qbx_core:RemoveMoney(src, 'bank', fee, 'vehicle-impound-fee') end
    MySQL.update.await('UPDATE vehicle_impounds SET released = 1, released_at = NOW() WHERE id = ?', { impoundId })
    MySQL.update.await('UPDATE player_vehicles SET state = 0 WHERE plate = ?', { impound.plate })

    local props = json.decode(impound.vehicle_props)
    if props then
        props.plate = impound.plate
        props.fuel = impound.fuel
        spawnVehicle(src, props, point)
    end

    return { success = true }
end)

lib.callback.register('pen-impound:server:calculateFee', function(_, timestamp)
    return CalculateImpoundFee(timestamp)
end)

lib.callback.register('pen-impound:server:getAllImpoundedVehicles', function(source)
    local src = source
    local player = getPlayer(src)
    if not player or not player.PlayerData or not isAuthorizedJobName(player.PlayerData.job and player.PlayerData.job.name) then return {} end
    local rows = MySQL.query.await('SELECT * FROM vehicle_impounds WHERE released = 0 ORDER BY timestamp DESC') or {}
    for i = 1, #rows do rows[i].fee = CalculateImpoundFee(rows[i].timestamp) end
    return rows
end)

lib.callback.register('pen-impound:server:releaseVehicle', function(source, impoundId, zone)
    local src = source
    local player = getPlayer(src)
    if not player or not player.PlayerData or not isAuthorizedJobName(player.PlayerData.job and player.PlayerData.job.name) then return { success = false, message = (Config.Locale and Config.Locale.noPermission) or 'Not allowed' } end
    if not impoundId then return { success = false, message = 'Invalid request' } end

    local impound = MySQL.single.await('SELECT * FROM vehicle_impounds WHERE id = ? AND released = 0 LIMIT 1', { impoundId })
    if not impound then return { success = false, message = (Config.Locale and Config.Locale.vehicleNotFound) or 'Vehicle not found' } end

    local point = GetAvailableSpawnPoint(zone)
    if not point then return { success = false, message = (Config.Locale and Config.Locale.noAvailableSpawn) or 'No available spawn point' } end

    MySQL.update.await('UPDATE vehicle_impounds SET released = 1, released_at = NOW() WHERE id = ?', { impoundId })
    MySQL.update.await('UPDATE player_vehicles SET state = 0 WHERE plate = ?', { impound.plate })

    local props = json.decode(impound.vehicle_props)
    if props then
        props.plate = impound.plate
        props.fuel = impound.fuel
        spawnVehicle(src, props, point)
    end

    if impound.citizenid then
        local owner = exports.qbx_core:GetPlayerByCitizenId(impound.citizenid)
        if owner and owner.PlayerData and owner.PlayerData.source then
            notify(owner.PlayerData.source, 'Your vehicle '..impound.plate..' has been released from impound by '..((player.PlayerData.job and player.PlayerData.job.label) or 'staff'), 'success', (Config.NotifyDuration or 5000))
        end
    end

    return { success = true }
end)

lib.callback.register('pen-impound:server:getImpoundLogs', function(source)
    local src = source
    local player = getPlayer(src)
    if not player or not player.PlayerData or not isAuthorizedJobName(player.PlayerData.job and player.PlayerData.job.name) then return {} end
    return MySQL.query.await('SELECT id, plate, model, owner_name, officer, job, reason, timestamp, released, released_at, CASE WHEN released = 0 THEN "impounded" ELSE "released" END AS action_type FROM vehicle_impounds WHERE timestamp >= DATE_SUB(NOW(), INTERVAL 48 HOUR) OR released_at >= DATE_SUB(NOW(), INTERVAL 48 HOUR) ORDER BY COALESCE(released_at, timestamp) DESC LIMIT 50') or {}
end)

RegisterCommand('checkimpounds', function(source)
    local src = source
    local player = getPlayer(src)
    if not player or not player.PlayerData then return end
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM vehicle_impounds WHERE citizenid = ? AND released = 0', { player.PlayerData.citizenid }) or 0
    notify(src, ('You have %d impounded vehicles. CitizenID: %s'):format(count, player.PlayerData.citizenid), 'info')
end, false)

RegisterCommand('testimpound', function(source)
    local src = source
    if src > 0 and not IsPlayerAceAllowed(src, 'admin') then
        notify(src, 'You do not have permission to use this command', 'error')
        return
    end
    local player = getPlayer(src)
    if not player or not player.PlayerData then return end

    local id = MySQL.insert.await('INSERT INTO vehicle_impounds (plate, model, citizenid, owner_name, fuel, officer, officer_citizenid, job, reason, impound_location, vehicle_props) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        'TEST' .. math.random(1000, 9999),
        'Sultan',
        player.PlayerData.citizenid,
        (player.PlayerData.charinfo.firstname or '') .. ' ' .. (player.PlayerData.charinfo.lastname or ''),
        75,
        'Test Officer',
        'TEST123',
        'police',
        'Test impound for debugging',
        'police_impound',
        json.encode({ model = 'sultan', plate = 'TEST1234' })
    })

    if id then
        notify(src, 'Test impound added successfully! Try retrieving it at the impound lot.', 'success')
    else
        notify(src, 'Failed to add test impound', 'error')
    end
end, false)

CreateThread(function()
    while true do
        Wait(Config.DatabaseUpdateInterval)
        if (Config.ImpoundFees.maxDays or 0) > 0 then
            MySQL.update.await('UPDATE vehicle_impounds SET released = 2 WHERE released = 0 AND DATEDIFF(NOW(), timestamp) > ?', { Config.ImpoundFees.maxDays })
        end
    end
end)
