local addonName, Addon = ...
Addon.Core = Addon.Core or {}

local DEFAULTS = {
    enabled = true,
    message = "Thank you!",
    replyDelay = 4,
    cooldownDelay = 60,
    debugMode = false,
    excludeGroup = false,
    excludeGuild = false,
}

DB_Thanker = DB_Thanker or {}

local function InitializeSettings()
    for key, value in pairs(DEFAULTS) do
        if DB_Thanker[key] == nil then
            DB_Thanker[key] = value
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

local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "Thanker" then
            InitializeSettings()

            Addon.Control.Initialize(playerName, playerFullName)
            Addon.View.Initialize()

            print("|cFF00FF00Thanker|r loaded. Type /thanker for options.")
            frame:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        Addon.Control.HandleCombatLog(CombatLogGetCurrentEventInfo())
    end
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:SetScript("OnEvent", OnEvent)

function Addon.Core.GetSettings()
    return DB_Thanker
end

function Addon.Core.GetPlayerInfo()
    return playerName, playerRealm, playerFullName
end
