
local QBX = exports.qbx_core
local inventory = exports.ox_inventory

local pickaxeDurability = {}

local function notify(src, msg, type_, dur)
    TriggerClientEvent('ox_lib:notify', src, { description = msg, type = type_ or 'inform', duration = dur or 5000 })
end

RegisterNetEvent('pen-miningjob:server:mineRock', function()
    local src = source
    local player = QBX:GetPlayer(src)
    if not player then return end
    if not player.PlayerData.job or player.PlayerData.job.name ~= Config.RequiredJob then
        notify(src, 'You are not authorized to mine', 'error')
        return
    end
    local count = inventory:Search(src, 'count', Config.RequiredItem)
    if not count or count < 1 then
        notify(src, 'You need a pickaxe to mine', 'error')
        return
    end
    if not pickaxeDurability[src] then pickaxeDurability[src] = Config.PickaxeDurability end
    local breakTool = false
    if math.random() <= (Config.PickaxeBreakChance or 0) then
        breakTool = true
    else
        pickaxeDurability[src] = pickaxeDurability[src] - 1
        if pickaxeDurability[src] <= 0 then breakTool = true end
    end
    if breakTool then
        inventory:RemoveItem(src, Config.RequiredItem, 1)
        pickaxeDurability[src] = nil
        notify(src, 'Your pickaxe broke!', 'error')
    end
    local rewards = {}
    for _, r in ipairs(Config.MiningRewards or {}) do
        if math.random(100) <= r.chance then
            local amt = math.random(r.min, r.max)
            rewards[#rewards+1] = { item = r.item, amount = amt }
        end
    end
    local given = {}
    for i = 1, #rewards do
        local ok = inventory:AddItem(src, rewards[i].item, rewards[i].amount)
        if ok then given[#given+1] = (rewards[i].amount .. 'x ' .. rewards[i].item) end
    end
    if #given > 0 then
        notify(src, 'Found: ' .. table.concat(given, ', '), 'success')
    else
        notify(src, 'Mining yielded nothing useful', 'inform')
    end
end)

lib.callback.register('pen-miningjob:server:getSellableItems', function(source)
    local src = source
    local player = QBX:GetPlayer(src)
    if not player then return {} end
    if not player.PlayerData.job or player.PlayerData.job.name ~= Config.RequiredJob then return {} end
    local sellable = {}
    for name, _ in pairs(Config.SellPrices or {}) do
        local cnt = inventory:Search(src, 'count', name)
        if cnt and cnt > 0 then
            local item = inventory:Items(name)
            sellable[#sellable+1] = { name = name, label = (item and item.label) or name, count = cnt }
        end
    end
    return sellable
end)

lib.callback.register('pen-miningjob:server:sellItem', function(source, itemName, amount)
    local src = source
    local player = QBX:GetPlayer(src)
    if not player then return { ok = false, msg = 'Player not found' } end
    if not player.PlayerData.job or player.PlayerData.job.name ~= Config.RequiredJob then return { ok = false, msg = 'Not authorized' } end
    if not itemName or not amount or amount < 1 then return { ok = false, msg = 'Invalid request' } end
    local price = Config.SellPrices[itemName]
    if not price then return { ok = false, msg = 'Cannot sell this item here' } end
    local have = inventory:Search(src, 'count', itemName)
    if not have or have < amount then return { ok = false, msg = 'Not enough items' } end
    local removed = inventory:RemoveItem(src, itemName, amount)
    if not removed then return { ok = false, msg = 'Failed to remove items' } end
    local per = math.random(price.min, price.max)
    local total = per * amount
    player.Functions.AddMoney('cash', total)
    return { ok = true, total = total }
end)

AddEventHandler('playerDropped', function()
    local src = source
    pickaxeDurability[src] = nil
end)

AddEventHandler('ox_inventory:usedItem', function(source, name)
    if name == Config.RequiredItem then
        pickaxeDurability[source] = Config.PickaxeDurability
    end
end)
