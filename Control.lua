local addonName, Addon = ...
Addon.Control = Addon.Control or {}

local function Set(list)
    local set = {}
    for _, value in ipairs(list) do
        set[value] = true
    end
    return set
end

local BuffList = Set({
    (GetSpellInfo(Addon.Static.BuffSpells.MARK)),
    (GetSpellInfo(Addon.Static.BuffSpells.THORNS)),
    (GetSpellInfo(Addon.Static.BuffSpells.AI)),
    (GetSpellInfo(Addon.Static.BuffSpells.MIGHT)),
    (GetSpellInfo(Addon.Static.BuffSpells.KINGS)),
    (GetSpellInfo(Addon.Static.BuffSpells.WIS)),
    (GetSpellInfo(Addon.Static.BuffSpells.FORT)),
    (GetSpellInfo(Addon.Static.BuffSpells.BREATH)),
})

local playerCooldowns = {}
local scheduledWhispers = {}

local playerName, playerFullName

local function IsPlayerInGroup(name)
    if not IsInGroup() then
        return false
    end

    local numGroupMembers = GetNumGroupMembers()
    for i = 1, numGroupMembers do
        local unit = (IsInRaid() and "raid" or "party") .. i
        if UnitName(unit) == name then
            return true
        end
    end

    return false
end

local function IsPlayerInGuild(name)
    if not IsInGuild() then
        return false
    end

    local numGuildMembers = GetNumGuildMembers()
    for i = 1, numGuildMembers do
        local guildMemberName = GetGuildRosterInfo(i)
        if guildMemberName and guildMemberName:match("([^-]+)") == name then
            return true
        end
    end

    return false
end

local function GetResponseMessage()

    local messages = {}
    for i = 1, 5 do
        local msg = DB_BuffResponder["message" .. i]
        if msg and msg:trim() ~= "" then
            table.insert(messages, msg)
        end
    end

    if #messages == 0 then
        return "Ty <3"
    end

    local mode = DB_BuffResponder.responseMode
    if mode == "1" or mode == "2" or mode == "3" or mode == "4" or mode == "5" then
        local msgIndex = tonumber(mode)
        local msg = DB_BuffResponder["message" .. msgIndex]
        if msg and msg:trim() ~= "" then
            return msg
        else
            return messages[1]
        end
    end

    local randomIndex = math.random(1, #messages)
    return messages[randomIndex]
end

local function ScheduleWhisper(targetName, delay)
    local currentTime = GetTime()
    if not DB_BuffResponder.debugMode and playerCooldowns[targetName] and currentTime < playerCooldowns[targetName] then
        print("|cFF00FF00BuffResponder:|r " .. targetName .. " is on cooldown. Whisper skipped.")
        return
    end

    if scheduledWhispers[targetName] then
        if DB_BuffResponder.debugMode then
            print("|cFF00FF00BuffResponder:|r Whisper to " .. targetName .. " already scheduled.")
        end
        return
    end

    scheduledWhispers[targetName] = true

    C_Timer.After(delay, function()
        local message = GetResponseMessage()
        SendChatMessage(message, "WHISPER", nil, targetName)

        local whisperTime = GetTime()
        playerCooldowns[targetName] = whisperTime + DB_BuffResponder.cooldownDelay

        scheduledWhispers[targetName] = nil

        if DB_BuffResponder.debugMode then
            print("|cFF00FF00BuffResponder:|r Whispered " .. targetName .. ": " .. message)
        end
    end)

    if DB_BuffResponder.debugMode then
        print("|cFF00FF00BuffResponder:|r Scheduled whisper to " .. targetName .. " in " .. delay .. " seconds.")
    end
end

function Addon.Control.HandleCombatLog(timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName)
    if not DB_BuffResponder.enabled then
        return
    end

    if subevent ~= "SPELL_AURA_APPLIED" then
        return
    end

    local playerGUID = UnitGUID("player")
    if destGUID ~= playerGUID then
        return
    end

    if not sourceName or sourceName == "" then
        return
    end

    if not BuffList[spellName] then
        if not DB_BuffResponder.debugMode then
            return
        end
        print("|cFF00FF00BuffResponder:|r Debug mode: Buff '" .. (spellName or "unknown") .. "' is not in the whitelist but processing anyway.")
    end

    local sourceIsPlayer = (sourceGUID == playerGUID)

    if sourceIsPlayer and not DB_BuffResponder.debugMode then
        return
    end

    local isPlayer = bit.band(sourceFlags, COMBATLOG_OBJECT_TYPE_PLAYER) == COMBATLOG_OBJECT_TYPE_PLAYER

    if not isPlayer and not DB_BuffResponder.debugMode then
        return
    end

    local cleanName = sourceName:match("([^-]+)") or sourceName

    if DB_BuffResponder.debugMode then
        print("|cFF00FF00BuffResponder:|r Received whitelisted buff '" .. spellName .. "' from " .. cleanName)
    end

    if sourceIsPlayer and DB_BuffResponder.debugMode then
        if DB_BuffResponder.debugMode then
            print("|cFF00FF00BuffResponder:|r Debug mode: You buffed yourself. Scheduling test whisper.")
        end
        ScheduleWhisper(playerName, DB_BuffResponder.replyDelay)
        return
    end

    if DB_BuffResponder.excludeGroup and IsPlayerInGroup(cleanName) then
        if DB_BuffResponder.debugMode then
            print("|cFF00FF00BuffResponder:|r " .. cleanName .. " is in your group. Whisper skipped.")
        end
        return
    end

    if DB_BuffResponder.excludeGuild and IsPlayerInGuild(cleanName) then
        if DB_BuffResponder.debugMode then
            print("|cFF00FF00BuffResponder:|r " .. cleanName .. " is in your guild. Whisper skipped.")
        end
        return
    end

    ScheduleWhisper(cleanName, DB_BuffResponder.replyDelay)
end

function Addon.Control.Initialize(pName, pFullName)
    playerName = pName
    playerFullName = pFullName
end
