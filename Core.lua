local addonName, Addon = ...
Addon.Core = Addon.Core or {}

local DEFAULTS = {
    enabled = true,
    message = "ty <3",
    message1 = "ty <3",
    message2 = "thx :)",
    message3 = "tyvm <3",
    message4 = "ty :)",
    message5 = "thx :D",
    responseMode = "random",
    replyDelay = 4,
    cooldownDelay = 60,
    debugMode = false,
    excludeGroup = true,
    excludeGuild = true,
}

DB_BuffResponder = DB_BuffResponder or {}

local function InitializeSettings()
    for key, value in pairs(DEFAULTS) do
        if DB_BuffResponder[key] == nil then
            DB_BuffResponder[key] = value
        end
    end
end

function string:trim()
    return self:match("^%s*(.-)%s*$")
end

local frame = CreateFrame("FRAME")

local playerName = UnitName("player")
local playerRealm = GetRealmName()
local playerFullName = playerName .. "-" .. playerRealm

local isInGracePeriod = true

local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "BuffResponder" then
            InitializeSettings()

            Addon.Control.Initialize(playerName, playerFullName)
            Addon.View.Initialize()

            print("|cFF00FF00BuffResponder|r loaded. Type /buffr for options.")
            frame:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        isInGracePeriod = true

        if DB_BuffResponder.debugMode then
            print("|cFF00FF00BuffResponder:|r Entered world, starting grace period.")
        end

        C_Timer.After(8, function()
            isInGracePeriod = false
            if DB_BuffResponder.debugMode then
                print("|cFF00FF00BuffResponder:|r Grace period ended, now tracking buffs.")
            end
        end)
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if not isInGracePeriod then
            Addon.Control.HandleCombatLog(CombatLogGetCurrentEventInfo())
        end
    end
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:SetScript("OnEvent", OnEvent)

function Addon.Core.GetSettings()
    return DB_BuffResponder
end

function Addon.Core.GetPlayerInfo()
    return playerName, playerRealm, playerFullName
end

function Addon.Core.ResetSettings()
    for key, value in pairs(DEFAULTS) do
        DB_BuffResponder[key] = value
    end
end
