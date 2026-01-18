local broken = {}
local robbed = {}

local function pickLoot()
  local total = 0
  for i = 1, #Config.LootPool do
    total = total + Config.LootPool[i].chance
  end

  local roll = math.random(1, total)
  local acc = 0

  for i = 1, #Config.LootPool do
    acc = acc + Config.LootPool[i].chance
    if roll <= acc then
      local e = Config.LootPool[i]
      return e.item, math.random(e.min, e.max)
    end
  end
end

lib.callback.register('pen-carparts:server:isHoodBroken', function(_, plate)
  return broken[plate] == true
end)

lib.callback.register('pen-carparts:server:isVehicleRobbed', function(_, plate)
  return robbed[plate] == true
end)

lib.callback.register('pen-carparts:server:breakHood', function(src, netId, plate, coords)
  local player = exports.qbx_core:GetPlayer(src)
  if not player then return false end

  if type(plate) ~= 'string' or plate == '' then return false end
  if exports.ox_inventory:Search(src, 'count', Config.Items.lockpick) < 1 then return false end
  if broken[plate] == true or robbed[plate] == true then return false end

  broken[plate] = true

  if Config.PoliceAlert.enabled then
    Config.PoliceAlert.dispatch({
      codeName = 'VEH_THEFT',
      code = '10-31',
      message = 'Vehicle alarm triggered',
      coords = coords,
      priority = 1
    })
  end

  return true
end)


lib.callback.register('pen-carparts:server:stripVehicle', function(src, netId, plate, coords)
  local player = exports.qbx_core:GetPlayer(src)
  if not player then return { ok = false, msg = 'No player.' } end

  if type(plate) ~= 'string' or plate == '' then
    return { ok = false, msg = 'Invalid plate.' }
  end

  if broken[plate] ~= true then
    return { ok = false, msg = 'Hood is not forced open.' }
  end

  if robbed[plate] == true then
    return { ok = false, msg = 'This vehicle was already stripped.' }
  end

  if GetResourceState('ox_inventory') ~= 'started' then
    return { ok = false, msg = 'ox_inventory not running.' }
  end

  local count = exports.ox_inventory:Search(src, 'count', Config.Items.toolbox) or 0
  if count < 1 then
    return { ok = false, msg = 'Toolbox required.' }
  end

  local item, amount = pickLoot()
  if not item or not amount then
    return { ok = false, msg = 'Loot pool not configured.' }
  end

  local ok = Config.GiveReward(src, item, amount)
  if not ok then
    return { ok = false, msg = 'Reward failed (inventory full / item invalid).' }
  end

  robbed[plate] = true

  if Config.PoliceAlert.enabled and math.random() < Config.PoliceAlert.stripChance then
    Config.PoliceAlert.dispatch({
      codeName = 'VEH_STRIP',
      code = '10-31',
      message = 'Suspicious activity at parked vehicle',
      coords = coords,
      priority = 2
    })
  end

  return { ok = true, item = item, count = amount }
end)