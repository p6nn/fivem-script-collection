CreateThread(function()
    if not LocalPlayer.state.clockedIn then
        LocalPlayer.state:set('clockedIn', {}, true)
    end
    LocalPlayer.state.clockedIn['fire'] = { status = false, time = 0 }
    LocalPlayer.state.clockedIn['police'] = { status = false, time = 0 }
    LocalPlayer.state:set('clockedIn', LocalPlayer.state.clockedIn, true)
end)

function toggleClockIn(type)
    if not LocalPlayer.state.clockedIn then
        LocalPlayer.state:set('clockedIn', {}, true)
    end

    local isClockedIn = LocalPlayer.state.clockedIn[type] and LocalPlayer.state.clockedIn[type].status or false
    local newStatus = not isClockedIn
    local currentTime = os.time()

    lib.callback('fd-clockin:server:setClockInState', false, function(result)
        if result.success then
            LocalPlayer.state.clockedIn[type] = { status = newStatus, time = currentTime }
            LocalPlayer.state:set('clockedIn', LocalPlayer.state.clockedIn, true)

            local statusType = newStatus and 'success' or 'error'
            lib.notify({ title = result.message, type = statusType })
        else
            lib.notify({ title = result.message, type = 'error' })
        end
    end, type, newStatus)
end

function checkClockedIn(type)
    if not LocalPlayer.state.clockedIn or not LocalPlayer.state.clockedIn[type] then return false end
    return LocalPlayer.state.clockedIn[type].status
end
exports('checkClockedIn', checkClockedIn)
