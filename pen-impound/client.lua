local currentZone, isUIOpen, radialItemAdded = nil, false, false

local function notify(msg, type_, dur)
    lib.notify({ description = msg, type = type_ or 'inform', duration = dur or 5000 })
end

local function isAuthorizedJob()
    local player = exports.qbx_core:GetPlayerData()
    if not player or not player.job then return false end
    return Config.AuthorizedJobs[player.job.name] == true
end

local function getVehicleNearby()
    local p = PlayerPedId()
    local c = GetEntityCoords(p)
    local v, dist = lib.getClosestVehicle(c, 3.0, true)
    if v and DoesEntityExist(v) and IsEntityAVehicle(v) and dist and dist <= 3.0 then
        return v
    end
end

local function setFocus(open)
    isUIOpen = open
    SetNuiFocus(open, open)
end

local function setupBlips()
    for _, zone in pairs(Config.ImpoundZones or {}) do
        local blipCfg = zone.blip
        if blipCfg and blipCfg.enabled then
            local blip = AddBlipForCoord(zone.coords.x, zone.coords.y, zone.coords.z)
            SetBlipSprite(blip, blipCfg.sprite)
            SetBlipColour(blip, blipCfg.color)
            SetBlipScale(blip, blipCfg.scale)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(blipCfg.label or 'Impound')
            EndTextCommandSetBlipName(blip)
        end
    end
end

local function registerRetrieveZones()
    for _, z in pairs(Config.ImpoundZones or {}) do
        lib.zones.sphere({
            coords = z.coords,
            radius = 3.0,
            inside = function()
                if IsControlJustReleased(0, 38) then
                    currentZone = z.name
                    OpenRetrieveUI()
                end
            end,
            onEnter = function()
                if not isUIOpen then
                    notify('Press [E] to open Impound', 'inform', 3000)
                end
            end
        })
    end
end

local function addRadial()
    if radialItemAdded then return end
    lib.addRadialItem({
        id = 'impound_vehicle',
        label = 'Impound Vehicle',
        icon = 'truck-loading',
        onSelect = function()
            if not isAuthorizedJob() then
                notify(Config.Locale and Config.Locale.noPermission or 'Not allowed', 'error')
                return
            end
            local v = getVehicleNearby()
            if v then
                OpenImpoundUI(v)
            else
                notify('No vehicle found', 'error')
            end
        end
    })
    radialItemAdded = true
end

local function setupCommandMapping()
    RegisterCommand('impoundvehicle', function()
        if not isAuthorizedJob() then
            notify(Config.Locale and Config.Locale.noPermission or 'Not allowed', 'error')
            return
        end
        local v = getVehicleNearby()
        if v then
            OpenImpoundUI(v)
        else
            notify('No vehicle found', 'error')
        end
    end, false)
    RegisterKeyMapping('impoundvehicle', 'Impound Vehicle', 'keyboard', Config.ImpoundKeybind or 'F6')
end

function OpenImpoundUI(vehicle)
    if isUIOpen or not vehicle or not DoesEntityExist(vehicle) then return end
    local plate = GetVehicleNumberPlateText(vehicle)
    local model = GetEntityModel(vehicle)
    local displayName = GetDisplayNameFromVehicleModel(model)
    local fuel = (Entity(vehicle).state and Entity(vehicle).state.fuel) or 0
    local props = lib.getVehicleProperties(vehicle)
    local ownerData = lib.callback.await('pen-impound:server:getVehicleOwner', plate)
    setFocus(true)
    SendNUIMessage({
        action = 'openImpound',
        data = {
            plate = plate,
            model = displayName,
            fuel = math.floor(fuel),
            ownerName = ownerData and ownerData.name or 'Unknown',
            ownerId = ownerData and ownerData.citizenid or nil,
            vehicleProps = props,
            vehicle = VehToNet(vehicle)
        }
    })
end

function OpenRetrieveUI()
    if isUIOpen then return end
    local vehicles = lib.callback.await('pen-impound:server:getImpoundedVehicles')
    local authorizedJob = isAuthorizedJob()
    if not authorizedJob and (not vehicles or #vehicles == 0) then
        notify('You have no impounded vehicles', 'info')
        return
    end
    setFocus(true)
    SendNUIMessage({
        action = 'openRetrieve',
        data = {
            vehicles = vehicles,
            zone = currentZone,
            isAuthorized = authorizedJob
        }
    })
end

RegisterNUICallback('close', function(_, cb)
    setFocus(false)
    cb('ok')
end)

RegisterNUICallback('impoundVehicle', function(data, cb)
    local success = lib.callback.await('pen-impound:server:impoundVehicle', data)
    if success then
        local v = NetToVeh(data.vehicle)
        if v and DoesEntityExist(v) then DeleteEntity(v) end
        notify((Config.Locale and Config.Locale.impoundSuccess) or 'Vehicle impounded', 'success')
    else
        notify((Config.Locale and Config.Locale.impoundError) or 'Failed to impound', 'error')
    end
    setFocus(false)
    cb('ok')
end)

RegisterNUICallback('retrieveVehicle', function(data, cb)
    local result = lib.callback.await('pen-impound:server:retrieveVehicle', data.id, currentZone)
    if result and result.success then
        notify((Config.Locale and Config.Locale.retrieveSuccess) or 'Vehicle retrieved', 'success')
    else
        notify((result and result.message) or (Config.Locale and Config.Locale.retrieveError) or 'Failed to retrieve', 'error')
    end
    setFocus(false)
    cb('ok')
end)

RegisterNUICallback('releaseVehicle', function(data, cb)
    local result = lib.callback.await('pen-impound:server:releaseVehicle', data.id, currentZone)
    if result and result.success then
        notify('Vehicle released successfully', 'success')
    else
        notify((result and result.message) or 'Failed to release vehicle', 'error')
    end
    setFocus(false)
    cb('ok')
end)

RegisterNUICallback('getAllImpounded', function(_, cb)
    local vehicles = lib.callback.await('pen-impound:server:getAllImpoundedVehicles')
    cb(vehicles or {})
end)

RegisterNUICallback('getImpoundLogs', function(_, cb)
    local logs = lib.callback.await('pen-impound:server:getImpoundLogs')
    cb(logs or {})
end)

RegisterNUICallback('calculateFee', function(data, cb)
    local fee = lib.callback.await('pen-impound:server:calculateFee', data.timestamp)
    cb(fee or 0)
end)

RegisterNetEvent('pen-impound:client:checkVehicle', function()
    if not isAuthorizedJob() then
        notify((Config.Locale and Config.Locale.noPermission) or 'Not allowed', 'error')
        return
    end
    local v = getVehicleNearby()
    if v then
        OpenImpoundUI(v)
    else
        notify('No vehicle found', 'error')
    end
end)

function OpenImpoundMenu()
    if not isAuthorizedJob() then
        notify((Config.Locale and Config.Locale.noPermission) or 'Not allowed', 'error')
        return
    end
    local v = getVehicleNearby()
    if not v then
        notify('No vehicle found', 'error')
        return
    end
    lib.registerContext({
        id = 'impound_menu',
        title = 'Vehicle Impound',
        options = {
            { title = 'Impound This Vehicle', description = 'Open impound form', icon = 'truck-loading', onSelect = function() OpenImpoundUI(v) end },
            { title = 'Cancel', icon = 'xmark' }
        }
    })
    lib.showContext('impound_menu')
end

exports('OpenImpoundMenu', OpenImpoundMenu)

CreateThread(function()
    setupBlips()
    registerRetrieveZones()
    addRadial()
    setupCommandMapping()
end)
