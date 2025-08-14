-- GLOBALS
local discordRoles = {}
local nameCache = {}
local roleFetchCooldown = {}
local RoleNameToId = {}
local RoleIdToName = {}
GlobalState.HasLoadedPermissions = false

-- DISCORD REQUEST
function Request(method, endpoint, data)
    local HEADERS = { ["Content-Type"] = "application/json", ["Authorization"] = "Bot " .. CONFIG.BotToken }
    local payload = (type(data) == 'table' and #data == 0 or data == nil) and '' or json.encode(data)
    local code, result, _, err = PerformHttpRequestAwait("https://discord.com/api/" .. endpoint, method, payload, HEADERS)
    if code ~= 200 then
        dbg("Request failed: HTTP " .. code .. " | Error: " .. (err or "Unknown error"))
        return nil
    end
    return result and json.decode(result) or nil
end

-- LOAD DISCORD ROLES
function LoadGuildRoles()
    local roles = Request("GET", "guilds/" .. CONFIG.GuildId .. "/roles", {})
    if not roles then
        dbg("^1[Error]^7 Failed to load Discord roles.")
        return
    end
    for _, role in ipairs(roles) do
        RoleNameToId[role.name] = role.id
        RoleIdToName[role.id] = role.name
    end
    dbg("^2[Success]^7 Loaded " .. tostring(#roles) .. " Discord roles.")
end

Citizen.CreateThread(LoadGuildRoles)

-- IDENTIFIERS
function GetPlayerDiscordId(player)
    for _, id in ipairs(GetPlayerIdentifiers(player)) do
        if id:match('discord:') then
            return id:gsub('discord:', '')
        end
    end
    return nil
end
exports('GetPlayerDiscordId', GetPlayerDiscordId)

-- GET ROLES
function GetPlayerDiscordRoles(player)
    local discordId = GetPlayerDiscordId(player)
    if not discordId then return {} end

    if discordRoles[player] then return discordRoles[player] end
    if roleFetchCooldown[player] and os.time() < roleFetchCooldown[player] then return {} end

    local member = Request("GET", "guilds/" .. CONFIG.GuildId .. "/members/" .. discordId, {})
    if not member or not member.roles then
        roleFetchCooldown[player] = os.time() + 120
        discordRoles[player] = {}
        return {}
    end

    discordRoles[player] = member.roles
    return member.roles
end
exports('GetPlayerDiscordRoles', GetPlayerDiscordRoles)

-- ROLE HELPERS
function FindDiscordRoleIdByName(name) return RoleNameToId[name] end
function FindDiscordRoleNameById(id) return RoleIdToName[id] end

function hasRole(player, role)
    local roles = GetPlayerDiscordRoles(player)
    local roleId = FindDiscordRoleIdByName(role)
    if not roleId then return false end
    for _, r in ipairs(roles) do if r == roleId then return true end end
    return false
end
exports('hasRole', hasRole)
exports('DoesPlayerHaveDiscordRole', hasRole)

-- NAME FETCHING
function GetPlayerDiscordName(discordId)
    local member = Request("GET", "guilds/" .. CONFIG.GuildId .. "/members/" .. discordId, {})
    return member and (member.nick or member.user.username) or nil
end
exports('GetPlayerDiscordName', GetPlayerDiscordName)

function GetPlayerDiscordNameFromId(player)
    local discordId = GetPlayerDiscordId(player)
    if nameCache[player] then return nameCache[player] end
    local member = Request("GET", "guilds/" .. CONFIG.GuildId .. "/members/" .. discordId, {})
    if not discordId or not member or not member.user then return GetPlayerName(player) end
    nameCache[player] = member.nick or member.user.username
    return nameCache[player]
end
exports('GetPlayerDiscordNameFromId', GetPlayerDiscordNameFromId)

function ReloadPlayerRoles(player)
    local discordId = GetPlayerDiscordId(player)
    if not discordId then
        dbg("^1[Reload]^7 No Discord ID found for player " .. player)
        return {}
    end

    local member = Request("GET", "guilds/" .. CONFIG.GuildId .. "/members/" .. discordId, {})
    if not member or not member.roles then
        dbg("^1[Reload]^7 Failed to fetch roles for player " .. player)
        discordRoles[player] = {}
        return {}
    end

    -- Update cache and reset cooldown
    discordRoles[player] = member.roles
    roleFetchCooldown[player] = nil

    dbg("^2[Reload]^7 Updated Discord roles for player " .. player)
    return member.roles
end
exports('ReloadPlayerRoles', ReloadPlayerRoles)

-- ASSIGN ACE
function AssignAcePermissions(player)
    local roles = GetPlayerDiscordRoles(player)
    for _, roleId in ipairs(roles) do
        local roleName = RoleIdToName[roleId]
        local ace = CONFIG.RolesToAce[roleName]
        if ace then
            for _, id in ipairs(GetPlayerIdentifiers(player)) do
                ExecuteCommand("add_principal identifier." .. id .. " " .. ace)
            end
        end
    end
end
exports('AssignAcePermissions', AssignAcePermissions)

-- GROUP CHECKS
function IsStaff(p)
    for _, v in ipairs(CONFIG.StaffRoles) do if hasRole(p, v) then return true end end
    return false
end
exports('IsStaff', IsStaff)

function IsCop(p)
    for _, v in ipairs(CONFIG.CopRoles) do if hasRole(p, v) then return true end end
    return false
end
exports('IsCop', IsCop)

function IsFire(p)
    for _, v in ipairs(CONFIG.FireRoles) do if hasRole(p, v) then return true end end
    return false
end
exports('IsFire', IsFire)

-- CALLBACK
lib.callback.register('pen-util:cb:isStaff', function(src)
    return IsStaff(src)
end)

-- REFRESH
RegisterCommand("_refreshpermissions", function(player)
    AssignAcePermissions(player)
end)

-- PLAYER READY
RegisterNetEvent("pen-util:PlayerReady", function()
    local player = source
    AssignAcePermissions(player)
    TriggerClientEvent('pen-util:clientSyncRoles', player, RoleNameToId, discordRoles[player])
end)

-- CLEANUP
AddEventHandler("playerDropped", function()
    local player = source
    discordRoles[player] = nil
    roleFetchCooldown[player] = nil
    nameCache[player] = nil
end)

-- OPTIONAL COMMAND TO RELOAD ROLES
RegisterCommand("_reloadroles", function()
    LoadGuildRoles()
    dbg("^3[Reload]^7 Refreshed Discord roles from API.")
end, true)

-- LOAD INITIAL PERMISSIONS
function LoadAcePerms()
    local after = nil
    local fetched = 0
    local total = 0

    repeat
        local endpoint = "v9/guilds/" .. CONFIG.GuildId .. "/members?limit=1000"
        if after then
            endpoint = endpoint .. "&after=" .. after
        end

        local members = Request("GET", endpoint, {})
        if not members then
            dbg("^1[Error]^7 Failed to fetch Discord members.")
            break
        end

        fetched = #members
        total = total + fetched

        for _, m in ipairs(members) do
            after = m.user.id -- set for next page

            local roles = {}
            for _, r in ipairs(m.roles or {}) do
                local roleName = RoleIdToName[r]
                if roleName and CONFIG.RolesToAce[roleName] then
                    ExecuteCommand("add_principal identifier.discord:" .. m.user.id .. " " .. CONFIG.RolesToAce[roleName])
                    table.insert(roles, roleName)
                end
            end

            if #roles > 0 then
                dbg("^2[Info]^7 " .. m.user.username .. " has roles: " .. table.concat(roles, ", "))
            end
        end

        Citizen.Wait(100) -- Prevent rate limiting
    until fetched < 1000

    dbg("^2[Success]^7 Loaded permissions for " .. total .. " Discord members.")
    GlobalState.HasLoadedPermissions = true
end


Citizen.CreateThread(function()
    if not GlobalState.HasLoadedPermissions then
        LoadAcePerms()
    end
end)

-- debug

function dbg(msg)
    if CONFIG.debugMode then print(msg) end
end