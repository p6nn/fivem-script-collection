Config = {}

Config.Items = {
  lockpick = 'lockpick',
  toolbox = 'repairkit'
}

Config.MinParkedSpeed = 0.25

Config.Target = {
  bones = { 'bonnet' },
  distance = 1.6
}

Config.BreakHood = {
  label = 'Break open hood',
  icon = 'fa-solid fa-lock-open',
  skill = {
    difficulty = { 'medium' },
    inputs = { 'w', 'a', 's', 'd' }
  },
  progress = {
    duration = { min = 2500, max = 4500 },
    label = 'Forcing the hood...',
    anim = { dict = 'veh@break_in@0h@p_m_one@', clip = 'low_force_entry_ds' }
  }
}

Config.StripParts = {
  label = 'Strip vehicle parts',
  icon = 'fa-solid fa-screwdriver-wrench',
  skill = {
    difficulty = { 'easy', 'medium' },
    inputs = { 'w', 'a', 's', 'd' }
  },
  progress = {
    duration = { min = 4500, max = 8500 },
    label = 'Stripping parts...',
    anim = { dict = 'mini@repair', clip = 'fixing_a_player' }
  }
}

Config.LootPool = {
  { item = 'scrapmetal', min = 2, max = 6, chance = 30 },
  { item = 'electronics', min = 1, max = 3, chance = 20 },
  { item = 'carbattery', min = 1, max = 1, chance = 15 },
  { item = 'rubber', min = 2, max = 5, chance = 20 },
  { item = 'radiator', min = 1, max = 1, chance = 15 }
}

Config.GiveReward = function(src, item, count)
  if type(src) ~= 'number' or src < 1 then return false end
  if type(item) ~= 'string' or item == '' then return false end
  if type(count) ~= 'number' or count < 1 then return false end

  if GetResourceState('ox_inventory') ~= 'started' then
    return false
  end

  return exports.ox_inventory:AddItem(src, item, count) == true
end



Config.PoliceAlert = {
  enabled = true,
  stripChance = 0.35,

  dispatch = function(data)
    if GetResourceState('ps-dispatch') == 'started' then
      TriggerEvent('ps-dispatch:server:notify', {
        message = data.message,
        codeName = data.codeName,
        code = data.code,
        coords = data.coords,
        priority = data.priority
      })
    end
  end
}