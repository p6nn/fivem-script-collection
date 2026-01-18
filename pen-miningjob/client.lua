
local QBX = exports.qbx_core
local target = exports.ox_target
local inventory = exports.ox_inventory

local isOnCooldown = false
local rocks = {}
local sellerPed = nil

CreateThread(function()
    for _, zone in pairs(Config.MiningZones or {}) do
        if zone.blip then
            local blip = AddBlipForCoord(zone.coords.x, zone.coords.y, zone.coords.z)
            SetBlipSprite(blip, zone.blip.sprite)
            SetBlipColour(blip, zone.blip.color)
            SetBlipScale(blip, zone.blip.scale)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(zone.blip.label)
            EndTextCommandSetBlipName(blip)
        end
        lib.zones.sphere({
            coords = zone.coords,
            radius = zone.radius,
            onEnter = function() lib.notify({ description = 'You are in a mining area', type = 'inform', duration = 2500 }) end
        })
    end
    if Config.SellLocation and Config.SellLocation.blip then
        local b = AddBlipForCoord(Config.SellLocation.coords.x, Config.SellLocation.coords.y, Config.SellLocation.coords.z)
        SetBlipSprite(b, Config.SellLocation.blip.sprite)
        SetBlipColour(b, Config.SellLocation.blip.color)
        SetBlipScale(b, Config.SellLocation.blip.scale)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(Config.SellLocation.blip.label)
        EndTextCommandSetBlipName(b)
    end
    SpawnRocks()
    SpawnSellerPed()
end)

function SpawnRocks()
    for i, rockData in pairs(Config.RockLocations or {}) do
        RequestModel(rockData.model)
        while not HasModelLoaded(rockData.model) do Wait(10) end
        local rock = CreateObject(GetHashKey(rockData.model), rockData.coords.x, rockData.coords.y, rockData.coords.z, false, false, false)
        SetEntityHeading(rock, rockData.heading or 0.0)
        FreezeEntityPosition(rock, true)
        SetEntityAsMissionEntity(rock, true, true)
        rocks[#rocks+1] = rock
        target:addLocalEntity(rock, {
            {
                name = 'mine_rock_'..i,
                icon = 'fas fa-pickaxe',
                label = 'Mine Rock',
                onSelect = function() MineRock(rockData.coords) end,
                canInteract = function() return CanMine() end
            }
        })
        lib.points.new({
            coords = rockData.coords,
            distance = 25.0,
            onEnter = function() lib.notify({ description = 'Press target on rock to mine', type = 'inform', duration = 2000 }) end
        })
    end
end

function SpawnSellerPed()
    RequestModel(Config.SellLocation.ped.model)
    while not HasModelLoaded(Config.SellLocation.ped.model) do Wait(10) end
    sellerPed = CreatePed(4, GetHashKey(Config.SellLocation.ped.model), Config.SellLocation.coords.x, Config.SellLocation.coords.y, Config.SellLocation.coords.z - 1.0, Config.SellLocation.heading, false, true)
    FreezeEntityPosition(sellerPed, true)
    SetEntityInvincible(sellerPed, true)
    SetBlockingOfNonTemporaryEvents(sellerPed, true)
    TaskStartScenarioInPlace(sellerPed, Config.SellLocation.ped.scenario, 0, true)
    target:addLocalEntity(sellerPed, {
        {
            name = 'mining_seller',
            icon = 'fas fa-coins',
            label = 'Sell Mining Materials',
            onSelect = function() OpenSellMenu() end,
            canInteract = function() return HasMinerJob() end
        }
    })
end

function CanMine()
    if isOnCooldown then
        lib.notify({ description = 'You need to rest before mining again', type = 'error' })
        return false
    end
    if not HasMinerJob() then
        lib.notify({ description = 'You need to be a miner to do this', type = 'error' })
        return false
    end
    if not HasPickaxe() then
        lib.notify({ description = 'You need a pickaxe to mine', type = 'error' })
        return false
    end
    local p = PlayerPedId()
    local c = GetEntityCoords(p)
    if not IsInMiningZone(c) then
        lib.notify({ description = 'You can only mine in designated areas', type = 'error' })
        return false
    end
    return true
end

function HasMinerJob()
    local player = QBX:GetPlayerData()
    return player.job and player.job.name == Config.RequiredJob
end

function HasPickaxe()
    local cnt = inventory:Search('count', Config.RequiredItem)
    return cnt and cnt > 0
end

function IsInMiningZone(coords)
    for _, zone in pairs(Config.MiningZones or {}) do
        if #(coords - zone.coords) <= zone.radius then return true end
    end
    return false
end

function MineRock(rockCoords)
    local p = PlayerPedId()
    local c = GetEntityCoords(p)
    local heading = GetHeadingFromVector_2d(rockCoords.x - c.x, rockCoords.y - c.y)
    SetEntityHeading(p, heading)
    RequestAnimDict('melee@large_wpn@streamed_core')
    while not HasAnimDictLoaded('melee@large_wpn@streamed_core') do Wait(10) end
    TaskPlayAnim(p, 'melee@large_wpn@streamed_core', 'ground_attack_on_spot', 8.0, -8.0, -1, 1, 0, false, false, false)
    local time = math.random(Config.MiningTime.min, Config.MiningTime.max)
    local ok = lib.progressBar({ duration = time, label = 'Mining...', useWhileDead = false, canCancel = true, disable = { car = true, move = true, combat = true } })
    ClearPedTasks(p)
    if ok then
        TriggerServerEvent('pen-miningjob:server:mineRock')
        SetMiningCooldown()
    else
        lib.notify({ description = 'Mining cancelled', type = 'error' })
    end
end

function SetMiningCooldown()
    isOnCooldown = true
    SetTimeout(Config.MiningCooldown, function() isOnCooldown = false end)
end

function OpenSellMenu()
    local items = lib.callback.await('pen-miningjob:server:getSellableItems')
    if not items or #items == 0 then
        lib.notify({ description = 'You have no materials to sell', type = 'error' })
        return
    end
    local opts = {}
    for _, it in ipairs(items) do
        local pr = Config.SellPrices[it.name]
        if pr then
            local minP = pr.min * it.count
            local maxP = pr.max * it.count
            opts[#opts+1] = {
                title = it.label..' x'..it.count,
                description = 'Sell for $'..minP..' - $'..maxP,
                icon = 'fas fa-coins',
                onSelect = function()
                    local res = lib.callback.await('pen-miningjob:server:sellItem', it.name, it.count)
                    if res and res.ok then
                        lib.notify({ description = 'Sold for $'..res.total, type = 'success' })
                    else
                        lib.notify({ description = (res and res.msg) or 'Sale failed', type = 'error' })
                    end
                end
            }
        end
    end
    lib.registerContext({ id = 'mining_sell_menu', title = 'Mining Materials Buyer', options = opts })
    lib.showContext('mining_sell_menu')
end

RegisterNetEvent('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for _, r in pairs(rocks) do
        target:removeLocalEntity(r)
        DeleteObject(r)
    end
    if sellerPed then
        target:removeLocalEntity(sellerPed)
        DeletePed(sellerPed)
    end
end)
