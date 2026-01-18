local busy = false
local hoodBroken = {}
local vehicleRobbed = {}

local function parked(v)
  if not v or v == 0 or not DoesEntityExist(v) then return false end
  if GetEntitySpeed(v) > Config.MinParkedSpeed then return false end
  if GetPedInVehicleSeat(v, -1) ~= 0 then return false end
  return true
end

local function plateKey(v)
  local plate = qbx.getVehiclePlate(v)
  if not plate or plate == '' then return nil end
  return plate
end

exports.ox_target:addGlobalVehicle({
  {
    name = 'pen-carparts:client:breakHood',
    label = Config.BreakHood.label,
    icon = Config.BreakHood.icon,
    bones = Config.Target.bones,
    distance = Config.Target.distance,
    items = { [Config.Items.lockpick] = 1 },

    canInteract = function(v)
      if busy then return false end
      if not parked(v) then return false end
      local plate = plateKey(v)
      if not plate then return false end
      if vehicleRobbed[plate] then return false end
      return hoodBroken[plate] ~= true
    end,

    onSelect = function(data)
      if busy then return end

      local p = PlayerPedId()
      local v = data.entity
      if not parked(v) then return end

      local plate = plateKey(v)
      if not plate then return end

      if vehicleRobbed[plate] then return end
      if hoodBroken[plate] then return end

      busy = true

      local ok = lib.skillCheck(Config.BreakHood.skill.difficulty, Config.BreakHood.skill.inputs)
      if not ok then
        busy = false
        return lib.notify({ type = 'error', description = 'You failed to force the hood.' })
      end

      local done = lib.progressBar({
        duration = math.random(Config.BreakHood.progress.duration.min, Config.BreakHood.progress.duration.max),
        label = Config.BreakHood.progress.label,
        canCancel = true,
        disable = { move = true, combat = true, car = true },
        anim = Config.BreakHood.progress.anim
      })

      if not done then
        busy = false
        return
      end

      local c = GetEntityCoords(p)
      SetVehicleAlarm(v, true)
      StartVehicleAlarm(v)
      SetVehicleDoorOpen(v, 4, false, false)

      local res = lib.callback.await('pen-carparts:server:breakHood', false, NetworkGetNetworkIdFromEntity(v), plate, { x = c.x, y = c.y, z = c.z })

      if res then
        hoodBroken[plate] = true
      end

      busy = false
    end
  },

  {
    name = 'pen-carparts:client:stripParts',
    label = Config.StripParts.label,
    icon = Config.StripParts.icon,
    bones = Config.Target.bones,
    distance = Config.Target.distance,
    items = { [Config.Items.toolbox] = 1 },

    canInteract = function(v)
      if busy then return false end
      if not parked(v) then return false end
      local plate = plateKey(v)
      if not plate then return false end
      if vehicleRobbed[plate] then return false end
      return hoodBroken[plate] == true
    end,

    onSelect = function(data)
      if busy then return end

      local p = PlayerPedId()
      local v = data.entity
      if not parked(v) then return end

      local plate = plateKey(v)
      if not plate then return end

      if not hoodBroken[plate] then return end
      if vehicleRobbed[plate] then return end

      busy = true

      local ok = lib.skillCheck(Config.StripParts.skill.difficulty, Config.StripParts.skill.inputs)
      if not ok then
        busy = false
        return lib.notify({ type = 'error', description = 'You slipped and failed.' })
      end

      local done = lib.progressBar({
        duration = math.random(Config.StripParts.progress.duration.min, Config.StripParts.progress.duration.max),
        label = Config.StripParts.progress.label,
        canCancel = true,
        disable = { move = true, combat = true, car = true },
        anim = Config.StripParts.progress.anim
      })

      if not done then
        busy = false
        return
      end

      local c = GetEntityCoords(p)

      local res = lib.callback.await('pen-carparts:server:stripVehicle', false, NetworkGetNetworkIdFromEntity(v), plate, { x = c.x, y = c.y, z = c.z })

      busy = false

      if not res or not res.ok then
        busy = false
        return lib.notify({ type = 'error', description = (res and res.msg) or 'Server returned no response.' })
      end

      vehicleRobbed[plate] = true

      lib.notify({
        type = 'success',
        description = ('You stole x%d %s'):format(res.count, res.item)
      })
    end
  }
})