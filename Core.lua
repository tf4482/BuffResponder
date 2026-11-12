-- Settings, player identity, world-entry grace period, and event dispatch
local addonName, Addon = ...
Addon.Core = Addon.Core or {}
Addon.Name = addonName

local Core = Addon.Core
local Static = Addon.Static
local settings
local playerName
local playerRealm
local playerFullName
local graceTimer
local isInGracePeriod = true
local isInitialized = false

-- Shallow table copy
local function CopyTable(source)
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = value
    end
    return copy
end

-- Trim surrounding whitespace; non-strings become empty
local function Trim(value)
    if type(value) ~= "string" then
        return ""
    end
    return value:match("^%s*(.-)%s*$")
end

-- TOC metadata on old and new clients
local function GetMetadata(field)
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(addonName, field)
    end
    if GetAddOnMetadata then
        return GetAddOnMetadata(addonName, field)
    end
end

-- Strip spaces and dashes from a realm name
local function NormalizeRealm(realm)
    if type(realm) ~= "string" then
        return ""
    end
    return realm:gsub("[%s%-]", "")
end

-- Validate and normalize one setting value
local function NormalizeSetting(key, value)
    if Static.BooleanSettings[key] then
        if type(value) == "boolean" then
            return value
        end
        return nil, "must be on or off"
    end

    if key:match("^message[1-5]$") then
        if type(value) ~= "string" then
            return nil, "must be text"
        end
        local message = Trim(value)
        if #message > Static.Limits.messageLength then
            return nil, "must be " .. Static.Limits.messageLength .. " bytes or fewer"
        end
        return message
    end

    if key == "responseMode" then
        if type(value) ~= "string" then
            return nil, "must be random or 1-5"
        end
        local mode = Trim(value):lower()
        if mode == "random" or mode:match("^[1-5]$") then
            return mode
        end
        return nil, "must be random or 1-5"
    end

    local minimum
    local maximum
    if key == "replyDelay" then
        minimum = Static.Limits.replyDelayMin
        maximum = Static.Limits.replyDelayMax
    elseif key == "cooldownDelay" then
        minimum = Static.Limits.cooldownDelayMin
        maximum = Static.Limits.cooldownDelayMax
    end

    if minimum then
        local number = tonumber(value)
        if not number or number ~= number or number < minimum or number > maximum then
            return nil, "must be between " .. minimum .. " and " .. maximum
        end
        return number
    end

    return nil, "is not a configurable setting"
end

-- Complete, valid settings table from saved data
local function BuildSettings(source)
    source = type(source) == "table" and source or {}

    -- Migrate the original single-message setting
    if source.message1 == nil and type(source.message) == "string" then
        source.message1 = source.message
    end

    local normalized = {}
    for key, defaultValue in pairs(Static.Defaults) do
        if key ~= "schemaVersion" then
            local value = NormalizeSetting(key, source[key])
            if value == nil then
                value = defaultValue
            end
            normalized[key] = value
        end
    end
    normalized.schemaVersion = Static.SchemaVersion
    return normalized
end

-- Load and repair the saved settings
local function InitializeSettings()
    settings = BuildSettings(DB_BuffResponder)
    DB_BuffResponder = settings
end

-- Read the player's name and realm
local function RefreshPlayerInfo()
    local name, realm
    if UnitFullName then
        name, realm = UnitFullName("player")
    end
    playerName = name or UnitName("player")
    playerRealm = NormalizeRealm(realm)

    if playerRealm == "" then
        local currentRealm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName()
        playerRealm = NormalizeRealm(currentRealm)
    end

    if playerName and playerRealm ~= "" then
        playerFullName = playerName .. "-" .. playerRealm
    else
        playerFullName = playerName
    end
end

-- Stop a running grace period timer
local function CancelGracePeriod()
    if graceTimer then
        graceTimer:Cancel()
        graceTimer = nil
    end
end

-- Ignore aura noise for a few seconds after login or zoning
local function StartGracePeriod()
    CancelGracePeriod()
    isInGracePeriod = true

    if Addon.Control and Addon.Control.CancelAllScheduled then
        Addon.Control.CancelAllScheduled("world transition")
    end

    Core.Debug("Entered the world; buff tracking starts in " .. Static.Limits.gracePeriod .. " seconds.")

    local timer
    timer = C_Timer.NewTimer(Static.Limits.gracePeriod, function()
        if graceTimer ~= timer then
            return
        end
        graceTimer = nil
        isInGracePeriod = false
        Core.Debug("Grace period ended; buff tracking is active.")
    end)
    graceTimer = timer
end

-- Ask the server for a fresh guild roster (C_GuildInfo on WoW Forever)
local function RequestGuildRoster()
    local request = C_GuildInfo and C_GuildInfo.GuildRoster or GuildRoster
    if IsInGuild() and request then
        request()
    end
end

local frame = CreateFrame("Frame")

-- Central event handler
local function OnEvent(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon ~= addonName then
            return
        end

        InitializeSettings()
        Addon.View.Initialize()
        Addon.Control.RegisterThankLinks()
        isInitialized = true
        frame:UnregisterEvent("ADDON_LOADED")
        return
    end

    if not isInitialized then
        return
    end

    if event == "PLAYER_LOGIN" then
        RefreshPlayerInfo()
        Addon.Control.Initialize(playerName, playerRealm, playerFullName)
        RequestGuildRoster()
        Addon.Control.RefreshGuildRoster()
        Core.Print("Loaded v" .. Core.GetVersion() .. ". Type |cFFFFFF00/buffr|r for options.")
    elseif event == "PLAYER_ENTERING_WORLD" then
        RefreshPlayerInfo()
        Addon.Control.Initialize(playerName, playerRealm, playerFullName)
        StartGracePeriod()
    elseif event == "PLAYER_GUILD_UPDATE" then
        RequestGuildRoster()
        Addon.Control.RefreshGuildRoster()
    elseif event == "GUILD_ROSTER_UPDATE" then
        Addon.Control.RefreshGuildRoster()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" and not isInGracePeriod then
        Addon.Control.HandleCombatLog(CombatLogGetCurrentEventInfo())
    elseif event == "UNIT_AURA" and not isInGracePeriod then
        local _, updateInfo = ...
        Addon.Control.HandleAuraUpdate(updateInfo)
    end
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("GUILD_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_GUILD_UPDATE")
-- WoW Forever has no combat log for addons; it watches the player's auras instead
if Static.IsForever then
    frame:RegisterUnitEvent("UNIT_AURA", "player")
else
    frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end
frame:SetScript("OnEvent", OnEvent)

-- Public trim helper
function Core.Trim(value)
    return Trim(value)
end

-- Colored chat line with the addon prefix
function Core.Print(message, color)
    local messageColor = color or "FFFFFFFF"
    print("|cFF00FF00BuffResponder:|r |c" .. messageColor .. tostring(message) .. "|r")
end

-- Diagnostic line, only in debug mode
function Core.Debug(message)
    if settings and settings.debugMode then
        Core.Print("🔍 " .. tostring(message), "FF80D8FF")
    end
end

-- Addon version from the TOC
function Core.GetVersion()
    return GetMetadata("Version") or "dev"
end

-- One setting value
function Core.GetSetting(key)
    return settings and settings[key]
end

-- Copy of all settings
function Core.GetSettings()
    return settings and CopyTable(settings) or {}
end

-- Validate and store one setting
function Core.SetSetting(key, value)
    if not settings or Static.Defaults[key] == nil or key == "schemaVersion" then
        return false, "unknown setting"
    end

    local normalized, err = NormalizeSetting(key, value)
    if normalized == nil then
        return false, err
    end

    settings[key] = normalized
    return true, normalized
end

-- Player name, realm, and full name
function Core.GetPlayerInfo()
    return playerName, playerRealm, playerFullName
end

-- Restore all defaults
function Core.ResetSettings()
    settings = BuildSettings({})
    DB_BuffResponder = settings
    return Core.GetSettings()
end

-- Internals exposed to qa/run.lua
Core._Test = {
    BuildSettings = BuildSettings,
    NormalizeSetting = NormalizeSetting,
}
