local _, Addon = ...
Addon.Control = Addon.Control or {}

local Control = Addon.Control
local Core = Addon.Core
local Static = Addon.Static
local playerName
local playerRealm
local playerFullName
local playerFullKey
local guildMembers = {}
local playerCooldowns = {}
local scheduledWhispers = {}

local function NormalizeRealm(realm)
    if type(realm) ~= "string" then
        return ""
    end
    return realm:gsub("[%s%-]", "")
end

local function NormalizePlayerName(name, fallbackRealm)
    if type(name) ~= "string" or name == "" then
        return nil
    end

    local shortName, realm = name:match("^([^-]+)%-(.+)$")
    shortName = shortName or name
    realm = NormalizeRealm(realm or fallbackRealm)
    if realm == "" then
        return shortName, shortName:lower(), shortName
    end

    local fullName = shortName .. "-" .. realm
    return fullName, fullName:lower(), shortName
end

local function GetUnitIdentity(unit)
    if not UnitExists(unit) then
        return nil
    end

    local name, realm
    if UnitFullName then
        name, realm = UnitFullName(unit)
    else
        name, realm = UnitName(unit)
    end
    if not name then
        return nil
    end
    return NormalizePlayerName(realm and realm ~= "" and (name .. "-" .. realm) or name, playerRealm)
end

local function BuildGroupMembers()
    local members = {}

    local _, ownKey = GetUnitIdentity("player")
    if ownKey then
        members[ownKey] = true
    end

    if IsInRaid() then
        for index = 1, GetNumGroupMembers() do
            local _, key = GetUnitIdentity("raid" .. index)
            if key then
                members[key] = true
            end
        end
    elseif IsInGroup() then
        local memberCount = GetNumSubgroupMembers and GetNumSubgroupMembers() or math.max(0, GetNumGroupMembers() - 1)
        for index = 1, memberCount do
            local _, key = GetUnitIdentity("party" .. index)
            if key then
                members[key] = true
            end
        end
    end

    return members
end

local function IsPlayerExcluded(targetKey)
    if Core.GetSetting("excludeGroup") and BuildGroupMembers()[targetKey] then
        return true, "group member"
    end
    if Core.GetSetting("excludeGuild") and guildMembers[targetKey] then
        return true, "guild member"
    end
    return false
end

local function GetResponseMessage()
    local messages = {}
    for index = 1, 5 do
        local message = Core.GetSetting("message" .. index)
        if message and message ~= "" then
            messages[#messages + 1] = message
        end
    end

    if #messages == 0 then
        return nil
    end

    local mode = Core.GetSetting("responseMode")
    if mode ~= "random" then
        local selected = Core.GetSetting("message" .. mode)
        return selected ~= "" and selected or messages[1]
    end

    return messages[math.random(#messages)]
end

local function PruneCooldowns(now)
    for key, expiresAt in pairs(playerCooldowns) do
        if expiresAt <= now then
            playerCooldowns[key] = nil
        end
    end
end

local function IsOnCooldown(targetKey, now)
    local expiresAt = playerCooldowns[targetKey]
    return expiresAt and expiresAt > now
end

local function CanWhisper(targetKey)
    if not Core.GetSetting("enabled") then
        return false, "addon disabled"
    end

    if not targetKey or targetKey == playerFullKey then
        return false, "invalid target"
    end

    local excluded, reason = IsPlayerExcluded(targetKey)
    if excluded then
        return false, reason
    end

    if IsOnCooldown(targetKey, GetTime()) then
        return false, "cooldown active"
    end

    return true
end

local function ScheduleWhisper(targetName, targetKey, delay)
    local now = GetTime()
    PruneCooldowns(now)

    local allowed, reason = CanWhisper(targetKey)
    if not allowed then
        Core.Debug("Skipped " .. targetName .. ": " .. reason .. ".")
        return false
    end

    if scheduledWhispers[targetKey] then
        Core.Debug("A reply to " .. targetName .. " is already pending.")
        return false
    end

    local timer
    timer = C_Timer.NewTimer(delay, function()
        local pending = scheduledWhispers[targetKey]
        if not pending or pending.timer ~= timer then
            return
        end

        scheduledWhispers[targetKey] = nil
        local canSend, skipReason = CanWhisper(targetKey)
        if not canSend then
            Core.Debug("Cancelled reply to " .. targetName .. ": " .. skipReason .. ".")
            return
        end

        local message = GetResponseMessage()
        if not message then
            Core.Debug("Cancelled reply to " .. targetName .. ": no message is configured.")
            return
        end

        SendChatMessage(message, "WHISPER", nil, targetName)
        playerCooldowns[targetKey] = GetTime() + Core.GetSetting("cooldownDelay")
        Core.Debug("Whispered " .. targetName .. ": " .. message)
    end)

    scheduledWhispers[targetKey] = {
        timer = timer,
        targetName = targetName,
    }
    Core.Debug("Reply to " .. targetName .. " scheduled in " .. delay .. " seconds.")
    return true
end

function Control.HandleCombatLog(_, subevent, _, sourceGUID, sourceName, sourceFlags, _, destGUID, _, _, _, spellId, spellName)
    if not Core.GetSetting("enabled") then
        return
    end

    if not Static.AuraEvents[subevent] then
        return
    end

    local currentPlayerGUID = UnitGUID("player")
    if not currentPlayerGUID or destGUID ~= currentPlayerGUID then
        return
    end

    if type(spellId) ~= "number" or not Static.BuffSpellIds[spellId] then
        Core.Debug("Ignored unsupported buff " .. tostring(spellName or spellId or "unknown") .. ".")
        return
    end

    if type(sourceGUID) ~= "string" or sourceGUID == currentPlayerGUID then
        Core.Debug("Ignored a self-applied buff.")
        return
    end

    if type(sourceFlags) ~= "number" or bit.band(sourceFlags, COMBATLOG_OBJECT_TYPE_PLAYER) == 0 then
        Core.Debug("Ignored a buff from a non-player source.")
        return
    end

    local targetName, targetKey, displayName = NormalizePlayerName(sourceName, playerRealm)
    if not targetName or not targetKey then
        Core.Debug("Ignored a buff with no valid source name.")
        return
    end

    Core.Debug("Received " .. tostring(spellName or ("spell " .. spellId)) .. " from " .. displayName .. ".")
    ScheduleWhisper(targetName, targetKey, Core.GetSetting("replyDelay"))
end

function Control.Initialize(name, realm, fullName)
    playerName = name
    playerRealm = NormalizeRealm(realm)
    playerFullName, playerFullKey = NormalizePlayerName(fullName or name, playerRealm)
end

function Control.RefreshGuildRoster()
    guildMembers = {}
    if not IsInGuild() then
        return
    end

    for index = 1, GetNumGuildMembers() do
        local memberName = GetGuildRosterInfo(index)
        local _, key = NormalizePlayerName(memberName, playerRealm)
        if key then
            guildMembers[key] = true
        end
    end
end

function Control.CancelAllScheduled(reason)
    for key, pending in pairs(scheduledWhispers) do
        pending.timer:Cancel()
        scheduledWhispers[key] = nil
    end
    Core.Debug("Cancelled pending replies: " .. tostring(reason or "requested") .. ".")
end

function Control.RunSelfTest()
    local settings = Core.GetSettings()
    local checks = {
        { "player identity", playerName and playerFullName and playerFullKey },
        { "settings schema", settings.schemaVersion == Static.SchemaVersion },
        { "message available", GetResponseMessage() ~= nil },
        { "spell whitelist", Static.BuffSpellIds[1243] and Static.BuffSpellIds[21562] },
        { "timer API", C_Timer and C_Timer.NewTimer },
    }

    local passed = 0
    for _, check in ipairs(checks) do
        local ok = not not check[2]
        passed = passed + (ok and 1 or 0)
        Core.Print((ok and "✅ " or "❌ ") .. check[1], ok and "FF80FF80" or "FFFF8080")
    end
    return passed, #checks
end

Control._Test = {
    NormalizePlayerName = NormalizePlayerName,
    GetResponseMessage = GetResponseMessage,
    PruneCooldowns = PruneCooldowns,
    GetScheduledWhispers = function()
        return scheduledWhispers
    end,
}
