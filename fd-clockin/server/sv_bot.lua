function getHours(discordId, filter, specificDate)
    local query = 'SELECT * FROM `clockInTime`'
    local params = {}

    if discordId then
        query = query .. ' WHERE discordId = ?'
        params = {discordId}
    end

    local result = MySQL.prepare.await(query, params)
    print(query)

    if not result or #result == 0 then
        print("No data found")
        return json.encode({})
    end

    for _, record in ipairs(result) do
        if record.discordId then
            record.discordName = getPlayerDiscordName(record.discordId) or "Unknown"
        end
    end

    if discordId then
        return getDurationByFilter(result, filter, discordId, specificDate)
    else
        return getDurationByFilter(result, filter, specificDate)
    end
end

function getDurationByFilter(data, filterType, discordId, specificDate)
    local policeResults = {}
    local fireResults = {}
    local currentTime = os.time()
    local currentDate = os.date("*t", currentTime)

    for _, entry in ipairs(data) do
        local entryTime = tonumber(entry.time)
        local entryDuration = tonumber(entry.duration)
        if not entryTime or not entryDuration then
            goto continue
        end
        local entryDate = os.date("*t", entryTime)

        if discordId and entry.discordId ~= discordId then
            goto continue
        end

        local isValid = false

        if filterType == "daily" then
            if entryDate.year == currentDate.year and entryDate.month == currentDate.month and entryDate.day == currentDate.day then
                isValid = true
            end
        elseif filterType == "weekly" then
            local function getISOWeek(t)
                local yday = t.yday
                local wday = (t.wday - 1) % 7
                local dayOfYearWithWeekStart = yday - wday
                return math.floor(dayOfYearWithWeekStart / 7) + 1
            end

            if entryDate.year == currentDate.year and getISOWeek(entryDate) == getISOWeek(currentDate) then
                isValid = true
            end
        elseif filterType == "monthly" then
            if entryDate.year == currentDate.year and entryDate.month == currentDate.month then
                isValid = true
            end
        elseif filterType == "lifetime" then
            isValid = true
        elseif filterType == "specific" and specificDate then
            local specificYear, specificMonth, specificDay = specificDate:match("(%d+)-(%d+)-(%d+)")
            specificYear, specificMonth, specificDay = tonumber(specificYear), tonumber(specificMonth), tonumber(specificDay)
            if entryDate.year == specificYear and entryDate.month == specificMonth and entryDate.day == specificDay then
                isValid = true
            end
        end

        if isValid then
            local discordId = entry.discordId
            local targetResults = (entry.type == "police") and policeResults or fireResults

            if not targetResults[discordId] then
                targetResults[discordId] = {name = entry.discordName or "Unknown", totalDuration = 0}
            end
            targetResults[discordId].totalDuration = targetResults[discordId].totalDuration + entryDuration
        end

        ::continue::
    end

    local function sortAndFormatResults(results, header, includeRank)
        local sortedResults = {}
        for discordId, entry in pairs(results) do
            table.insert(sortedResults, {name = entry.name, totalDuration = entry.totalDuration, discordId = discordId})
        end
        table.sort(sortedResults, function(a, b)
            return a.totalDuration > b.totalDuration
        end)

        local discordOutput = {header}
        for i = 1, math.min(10, #sortedResults) do
            local entry = sortedResults[i]
            local hours = math.floor(entry.totalDuration / 3600)
            local minutes = math.floor((entry.totalDuration % 3600) / 60)
            local seconds = entry.totalDuration % 60

            if includeRank then
                table.insert(discordOutput, string.format("%d. %s - %02d hours, %02d minutes, %02d seconds", i, entry.name, hours, minutes, seconds))
            else
                table.insert(discordOutput, string.format("%02d hours, %02d minutes, %02d seconds", hours, minutes, seconds))
            end
        end

        return table.concat(discordOutput, "\n")
    end

    local policeHeader = discordId and "**Police**" or "**Police Leaderboard**"
    local fireHeader = discordId and "**Fire**" or "**Fire Leaderboard**"
    local includeRank = not discordId

    local policeLeaderboard = sortAndFormatResults(policeResults, policeHeader, includeRank)
    local fireLeaderboard = sortAndFormatResults(fireResults, fireHeader, includeRank)

    local combinedOutput = policeLeaderboard .. "\n\n" .. fireLeaderboard

    return combinedOutput
end

function getConfig()
    return Config
end

exports('getHours', getHours)
exports('getConfig', getConfig)
