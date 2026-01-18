Config = {}

Config.Debug = false

Config.Outage = {
    Enabled = true,
    RollIntervalSeconds = 120,
    ChancePercent = 8,
    MaxActive = 2,
    Persist = true,
}

Config.Repair = {
    DurationMs = 12000,
    CooldownSeconds = 8,

    RequiredItems = {
        { name = 'electronics_kit', count = 1 },
        { name = 'wirecutters', count = 1 },
    },

    ConsumeItems = {
        { name = 'electronics_kit', count = 1 },
    },
}

Config.Blackout = {
    KeepVehicleLights = true,
}

Config.Alert = {
    Enabled = true,
    OnStart = true,
    OnRestore = true,

    Handler = function(data)
        local exampleData = {
            resource = 'pen-outages',
            areaId = 'mirrorpark',
            areaLabel = 'Mirror Park',
            state = 'outage',
            startedAt = 1700000000,
            restoredBy = 0,
            coords = { x = 1032.0, y = -740.0, z = 57.5 },
            radius = 420.0,
            firstBox = { x = 1146.2, y = -820.7, z = 57.4 },
        }

        TriggerEvent('pen_phone:server:powerAlert', data, exampleData)
    end
}

Config.Areas = {
    {
        id = 'mirrorpark',
        label = 'Mirror Park',
        center = vec3(1032.0, -740.0, 57.5),
        radius = 420.0,
        boxes = {
            { id = 'mp_01', coords = vec3(1146.2, -820.7, 57.4), heading = 0.0 },
            { id = 'mp_02', coords = vec3(980.6, -672.3, 57.5), heading = 0.0 },
        }
    },
    {
        id = 'delperro',
        label = 'Del Perro',
        center = vec3(-1350.0, -1050.0, 4.0),
        radius = 520.0,
        boxes = {
            { id = 'dp_01', coords = vec3(-1331.2, -1223.4, 4.8), heading = 0.0 },
        }
    },
}
