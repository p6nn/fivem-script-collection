Config = {
    guildId = "",
    discordToken = ""
}

getPlayerDiscordId = function(player)
    return exports["fd-discord-util"]:GetPlayerDiscordId(player)
end

getPlayerDiscordName = function(player)
    return exports["fd-discord-util"]:GetPlayerDiscordName(player)
end

isFire = function(player)
    return true
end

isPolice = function(player)
    return true
end