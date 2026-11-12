-- Buff detection, filtering, and thank-you delivery
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
local thankQueue = {}
local THANK_LINK_PREFIX = "addon:" .. Addon.Name .. ":thank:"

-- Strip spaces and dashes so realm names compare reliably
local function NormalizeRealm(realm)
    if type(realm) ~= "string" then
        return ""
    end
    return realm:gsub("[%s%-]", "")
end

-- Full name, lowercase lookup key, and short display name for a player
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

-- Normalized identity of a unit token
local function GetUnitIdentity(unit)
    if not UnitExists(unit) then
        return nil
    end

    -- WoW Forever: UnitName returns first name and surname; whispers need "First Last"
    if Static.IsForever then
        local firstName, surname = UnitName(unit)
        if not firstName then
            return nil
        end
        local fullName = surname and surname ~= "" and (firstName .. " " .. surname) or firstName
        return fullName, fullName:lower(), fullName
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

-- Lookup set of the player and all current party or raid members
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

-- Group and guild exclusion check
local function IsPlayerExcluded(targetKey)
    if Core.GetSetting("excludeGroup") and BuildGroupMembers()[targetKey] then
        return true, "group member"
    end
    if Core.GetSetting("excludeGuild") and guildMembers[targetKey] then
        return true, "guild member"
    end
    return false
end

-- Configured message by mode, or a random non-empty one
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

-- Drop expired per-player cooldowns
local function PruneCooldowns(now)
    for key, expiresAt in pairs(playerCooldowns) do
        if expiresAt <= now then
            playerCooldowns[key] = nil
        end
    end
end

-- Active cooldown check for one player
local function IsOnCooldown(targetKey, now)
    local expiresAt = playerCooldowns[targetKey]
    return expiresAt and expiresAt > now
end

-- Index of a player's pending thank-you prompt
local function FindThank(targetKey)
    for index, entry in ipairs(thankQueue) do
        if entry.key == targetKey then
            return index
        end
    end
end

-- All conditions for replying to one player
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

    if FindThank(targetKey) then
        return false, "thank-you already pending"
    end

    return true
end

-- WoW Forever blocks addon chat in instances; Classic Era always allows it
local function CanAutoWhisper()
    if not Static.IsForever then
        return true
    end
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
        return false
    end
    return not IsInInstance()
end

-- Whisper directly when allowed; otherwise queue a prompt the player confirms
local function Deliver(targetName, targetKey, displayName, message)
    if CanAutoWhisper() then
        local send = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
        send(message, "WHISPER", nil, targetName)
        Core.Debug("Whispered " .. targetName .. ": " .. message)
        return
    end

    thankQueue[#thankQueue + 1] = { key = targetKey, name = targetName, message = message }
    local link = "|cFF80D8FF|H" .. THANK_LINK_PREFIX .. targetKey .. "|h[Thank]|h|r"
    Core.Print(Static.Icons.star .. displayName .. " buffed you. " .. link .. " or |cFFFFFF00/buffr thank|r")
end

-- Delayed reply with revalidation right before delivery
local function ScheduleWhisper(targetName, targetKey, displayName, delay)
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

        Deliver(targetName, targetKey, displayName, message)
        playerCooldowns[targetKey] = GetTime() + Core.GetSetting("cooldownDelay")
    end)

    scheduledWhispers[targetKey] = {
        timer = timer,
        targetName = targetName,
    }
    Core.Debug("Reply to " .. targetName .. " scheduled in " .. delay .. " seconds.")
    return true
end

-- Whitelist check by spell ID, independent of the game language
local function IsTrackedSpell(spellId, spellName)
    if type(spellId) == "number" and Static.BuffSpellIds[spellId] then
        return true
    end
    Core.Debug("Ignored unsupported buff " .. tostring(spellName or "unknown") .. " (" .. tostring(spellId) .. ").")
    return false
end

-- Secret value test; always false on clients without secret values
local function IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end

-- Classic Era: buff detection from the combat log
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

    if not IsTrackedSpell(spellId, spellName) then
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
    ScheduleWhisper(targetName, targetKey, displayName, Core.GetSetting("replyDelay"))
end

-- WoW Forever: check one aura on the player for a tracked buff from another player
local function HandleAura(aura, isUpdate)
    if not aura or IsSecret(aura.spellId) or IsSecret(aura.sourceUnit) then
        return
    end

    -- Updates of untracked auras (e.g. movement effects) fire constantly; skip them silently
    if isUpdate and not Static.BuffSpellIds[aura.spellId] then
        return
    end

    if not IsTrackedSpell(aura.spellId, aura.name) then
        return
    end

    -- The caster is only known while it has a unit token (group, target, mouseover, nameplate)
    local unit = aura.sourceUnit
    if not unit or not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") then
        Core.Debug("Ignored " .. tostring(aura.name) .. ": caster is unknown, not a player, or yourself.")
        return
    end

    local targetName, targetKey, displayName = GetUnitIdentity(unit)
    if not targetName then
        Core.Debug("Ignored a buff with no valid source name.")
        return
    end

    Core.Debug("Received " .. tostring(aura.name) .. " from " .. displayName .. ".")
    ScheduleWhisper(targetName, targetKey, displayName, Core.GetSetting("replyDelay"))
end

-- WoW Forever: buff detection from UNIT_AURA on the player
function Control.HandleAuraUpdate(updateInfo)
    if not Core.GetSetting("enabled") or not updateInfo or updateInfo.isFullUpdate then
        return
    end

    -- Aura contents are secret in combat; reading them would throw
    if C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() then
        Core.Debug("Skipped an aura update: aura data is secret right now.")
        return
    end

    for _, aura in ipairs(updateInfo.addedAuras or {}) do
        HandleAura(aura)
    end
    for _, auraInstanceID in ipairs(updateInfo.updatedAuraInstanceIDs or {}) do
        HandleAura(C_UnitAuras.GetAuraDataByAuraInstanceID("player", auraInstanceID), true)
    end
end

-- Open the chat box as a whisper to the player with the message filled in
local function OpenWhisper(name, message)
    if not (ChatFrameUtil and ChatFrameUtil.ChooseBoxForSend) then
        ChatFrame_OpenChat("/w " .. name .. " " .. message)
        return
    end
    -- Set the target directly; "/w First Last" would split the surname from the name
    local editBox = ChatFrameUtil.ChooseBoxForSend()
    editBox:SetChatType("WHISPER")
    editBox:SetTellTarget(name)
    ChatFrameUtil.OpenChat(message)
    editBox:UpdateHeader()
end

-- Prepare the next or a given thank-you; the player sends it with Enter
function Control.Thank(targetKey)
    local index = targetKey and FindThank(targetKey) or (thankQueue[1] and 1)
    if not index then
        Core.Print(Static.Icons.off .. "No pending thank-yous.", "FFFFFF80")
        return false
    end

    local entry = table.remove(thankQueue, index)
    -- Next frame: after a slash command Blizzard clears and hides the chat box
    C_Timer.After(0, function()
        OpenWhisper(entry.name, entry.message)
    end)
    Core.Print(Static.Icons.star .. "Whisper to " .. entry.name .. " ready; press Enter to send.")
    return true
end

-- Number of thank-you prompts waiting for the player
function Control.GetPendingThankCount()
    return #thankQueue
end

-- Forget all pending thank-you prompts
function Control.ClearThanks()
    thankQueue = {}
end

-- Route clicks on the [Thank] chat links to Control.Thank
function Control.RegisterThankLinks()
    if not Static.IsForever or not EventRegistry then
        return
    end
    EventRegistry:RegisterCallback("SetItemRef", function(_, link)
        local key = type(link) == "string" and link:sub(1, #THANK_LINK_PREFIX) == THANK_LINK_PREFIX and link:sub(#THANK_LINK_PREFIX + 1)
        if key then
            Control.Thank(key)
        end
    end, Control)
end

-- Store the player's own identity
function Control.Initialize(name, realm, fullName)
    playerName = name
    playerRealm = NormalizeRealm(realm)
    playerFullName, playerFullKey = NormalizePlayerName(fullName or name, playerRealm)
end

-- Rebuild the guild member lookup set
function Control.RefreshGuildRoster()
    guildMembers = {}
    if not IsInGuild() then
        return
    end

    for index = 1, GetNumGuildMembers() do
        local memberName = GetGuildRosterInfo(index)
        local _, key
        if Static.IsForever and type(memberName) == "string" then
            -- WoW Forever: "First Last", without any realm suffix
            key = (memberName:gsub("%-.*$", "")):lower()
        else
            _, key = NormalizePlayerName(memberName, playerRealm)
        end
        if key then
            guildMembers[key] = true
        end
    end
end

-- Cancel all delayed replies
function Control.CancelAllScheduled(reason)
    for key, pending in pairs(scheduledWhispers) do
        pending.timer:Cancel()
        scheduledWhispers[key] = nil
    end
    Core.Debug("Cancelled pending replies: " .. tostring(reason or "requested") .. ".")
end

-- Local checks that never contact another player
function Control.RunSelfTest()
    local settings = Core.GetSettings()
    local checks = {
        { "player identity", playerName and playerFullName and playerFullKey },
        { "settings schema", settings.schemaVersion == Static.SchemaVersion },
        { "message available", GetResponseMessage() ~= nil },
        { "spell whitelist", Static.BuffSpellIds[1243] and Static.BuffSpellIds[21562] },
        { "timer API", C_Timer and C_Timer.NewTimer },
        { "thank prompt API", not Static.IsForever or (EventRegistry and (ChatFrameUtil or ChatFrame_OpenChat)) },
    }

    local passed = 0
    for _, check in ipairs(checks) do
        local ok = not not check[2]
        passed = passed + (ok and 1 or 0)
        Core.Print((ok and Static.Icons.ok or Static.Icons.fail) .. check[1], ok and "FF80FF80" or "FFFF8080")
    end
    return passed, #checks
end

-- Internals exposed to qa/run.lua
Control._Test = {
    NormalizePlayerName = NormalizePlayerName,
    GetResponseMessage = GetResponseMessage,
    PruneCooldowns = PruneCooldowns,
    GetScheduledWhispers = function()
        return scheduledWhispers
    end,
}
