local clockedIn = {}

lib.callback.register('fd-clockin:server:setClockInState', function(player, type, status)
    local checkRole = false
    local currentTime = os.time()

    if type == 'fire' then
        checkRole = isFire(player)
    elseif type == 'police' then
        checkRole = isPolice(player)
    end

    if not checkRole then
        return { success = false, message = 'You do not have the required role.' }
    end

    if not Player(player).state.clockedIn then
        Player(player).state:set('clockedIn', {}, true)
    end

    local playerState = Player(player).state.clockedIn
    if status then
        if playerState.fire and playerState.fire.status and type == 'police' or
           playerState.police and playerState.police.status and type == 'fire' then
            return { success = false, message = 'You cannot be clocked into both Fire and Police.' }
        end

        if playerState[type] and playerState[type].status then
            return { success = false, message = 'Already Clocked-In' }
        end

        clockedIn[player] = clockedIn[player] or {}
        clockedIn[player][type] = { status = true, time = currentTime }
        playerState[type] = { status = true, time = currentTime }

        Player(player).state:set('clockedIn', playerState, true)
        return { success = true, message = 'Clocked-In' }
    else
        addToDatabase(player, type)
        return { success = true, message = 'Clocked-Out' }
    end
end)

function addToDatabase(player, type)
    if not clockedIn[player] or not clockedIn[player][type] then return end
    local currentTime = os.time()
    local duration = currentTime - clockedIn[player][type].time
    local discordId = getPlayerDiscordId(player)
    MySQL.insert('INSERT INTO clockInTime (discordId, time, type, duration) VALUES (?, ?, ?, ?)', {discordId, currentTime, type, duration})
    clockPlayerOut(player, type)
end

function clockPlayerOut(player, type)
    local playerState = Player(player).state.clockedIn or {}
    playerState[type] = nil
    Player(player).state:set('clockedIn', playerState, true)

    if clockedIn[player] then
        clockedIn[player][type] = nil
        if next(clockedIn[player]) == nil then
            clockedIn[player] = nil
        end
    end
end

AddEventHandler('playerDropped', function()
    local player = source

    if Player(player).state.clockedIn then
        local playerState = Player(player).state.clockedIn
        if playerState.fire and playerState.fire.status then
            addToDatabase(player, 'fire')
        end
        if playerState.police and playerState.police.status then
            addToDatabase(player, 'police')
        end
    end
end)
