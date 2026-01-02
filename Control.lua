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
    (GetSpellInfo(Addon.Static.BuffSpells.WW)),
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

local function ScheduleWhisper(targetName, delay)
    local currentTime = GetTime()
    if playerCooldowns[targetName] and currentTime < playerCooldowns[targetName] then
        if DB_Thanker.debugMode then
            print("|cFF00FF00Thanker:|r " .. targetName .. " is on cooldown. Whisper skipped.")
        end
        return
    end

    if scheduledWhispers[targetName] then
        if DB_Thanker.debugMode then
            print("|cFF00FF00Thanker:|r Whisper to " .. targetName .. " already scheduled.")
        end
        return
    end

    scheduledWhispers[targetName] = true

    C_Timer.After(delay, function()
        SendChatMessage(DB_Thanker.message, "WHISPER", nil, targetName)

        local whisperTime = GetTime()
        playerCooldowns[targetName] = whisperTime + DB_Thanker.cooldownDelay

        scheduledWhispers[targetName] = nil

        if DB_Thanker.debugMode then
            print("|cFF00FF00Thanker:|r Whispered " .. targetName .. ": " .. DB_Thanker.message)
        end
    end)

    if DB_Thanker.debugMode then
        print("|cFF00FF00Thanker:|r Scheduled whisper to " .. targetName .. " in " .. delay .. " seconds.")
    end
end

function Addon.Control.HandleCombatLog(timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName)
    if not DB_Thanker.enabled then
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
        if not DB_Thanker.debugMode then
            return
        end
        print("|cFF00FF00Thanker:|r Debug mode: Buff '" .. (spellName or "unknown") .. "' is not in the whitelist but processing anyway.")
    end

    local sourceIsPlayer = (sourceGUID == playerGUID)

    if sourceIsPlayer and not DB_Thanker.debugMode then
        return
    end

    local isPlayer = bit.band(sourceFlags, COMBATLOG_OBJECT_TYPE_PLAYER) == COMBATLOG_OBJECT_TYPE_PLAYER

    if not isPlayer and not DB_Thanker.debugMode then
        return
    end

    local cleanName = sourceName:match("([^-]+)") or sourceName

    if DB_Thanker.debugMode then
        print("|cFF00FF00Thanker:|r Received whitelisted buff '" .. spellName .. "' from " .. cleanName)
    end

    if sourceIsPlayer and DB_Thanker.debugMode then
        if DB_Thanker.debugMode then
            print("|cFF00FF00Thanker:|r Debug mode: You buffed yourself. Scheduling test whisper.")
        end
        ScheduleWhisper(playerName, DB_Thanker.replyDelay)
    else
        ScheduleWhisper(cleanName, DB_Thanker.replyDelay)
    end
end

function Addon.Control.Initialize(pName, pFullName)
    playerName = pName
    playerFullName = pFullName
end

function Addon.Control.TestWhisper()
    if DB_Thanker.debugMode then
        print("|cFF00FF00Thanker:|r Test mode: Buff yourself to trigger a whisper.")
        print("|cFF00FF00Thanker:|r The whisper will be sent to yourself after " .. DB_Thanker.replyDelay .. " seconds.")
    else
        print("|cFFFF0000Thanker:|r Debug mode must be enabled to test. Use /thanker debug on")
    end
end
