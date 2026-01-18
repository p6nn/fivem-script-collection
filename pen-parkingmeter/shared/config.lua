Config = {}

Config.TargetDistance = 2.0
Config.ServerDistanceCheck = 4.0

Config.MeterModels = {
    `prop_parknmeter_01`,
    `prop_parknmeter_02`,
}

Config.Pricing = {
    { minutes = 5,  price = 25 },
    { minutes = 10, price = 40 },
    { minutes = 15, price = 55 },
    { minutes = 30, price = 90 },
    { minutes = 60, price = 150 },
}

Config.Notify = function(src, message, nType)
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Parking Meter',
        description = message,
        type = nType or 'inform',
    })
end

Config.PayMoney = function(player, amount)
    if not player then return false end
    if amount <= 0 then return false end

    if player.Functions and player.Functions.RemoveMoney then
        return player.Functions.RemoveMoney('cash', amount, 'parking-meter') == true
    end

    return false
end