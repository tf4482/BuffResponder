-- Mocked-WoW test harness for BuffResponder; run with: lua qa/run.lua
local failures = 0
local tests = 0

-- Record and print one test result
local function Check(name, condition)
    tests = tests + 1
    if condition then
        io.write("\27[32m✅ " .. name .. "\27[0m\n")
        return
    end
    failures = failures + 1
    io.write("\27[31m❌ " .. name .. "\27[0m\n")
end

local frames = {}
local timers = {}
local sentMessages = {}
local output = {}
local now = 100
local playerGUID = "Player-1-00000001"
local groupUnits = {}
local inGroup = false
local guildRoster = {}
local interfaceVersion = 11509
local auraSecret = false
local openedChat
local linkCallback

-- WoW API mocks
function GetBuildInfo()
    return "test", "0", "", interfaceVersion
end

function UnitIsPlayer(unit)
    return groupUnits[unit] ~= nil
end

function UnitIsUnit(unit, other)
    return unit == other
end

C_Secrets = {
    ShouldAurasBeSecret = function()
        return auraSecret
    end,
}

C_UnitAuras = {
    GetAuraDataByAuraInstanceID = function()
    end,
}

EventRegistry = {
    RegisterCallback = function(_, _, callback, owner)
        linkCallback = function(link)
            callback(owner, link)
        end
    end,
}

ChatFrameUtil = {
    OpenChat = function(text)
        openedChat = text
    end,
}

function print(message)
    output[#output + 1] = tostring(message)
end

function CreateFrame()
    local frame = { events = {} }
    function frame:RegisterEvent(event)
        self.events[event] = true
    end
    function frame:RegisterUnitEvent(event)
        self.events[event] = true
    end
    function frame:UnregisterEvent(event)
        self.events[event] = nil
    end
    function frame:SetScript(_, callback)
        self.callback = callback
    end
    frames[#frames + 1] = frame
    return frame
end

C_Timer = {}
function C_Timer.NewTimer(delay, callback)
    local timer = { delay = delay, callback = callback, cancelled = false }
    function timer:Cancel()
        self.cancelled = true
    end
    timers[#timers + 1] = timer
    return timer
end

function GetAddOnMetadata(_, field)
    return field == "Version" and "test" or nil
end

function UnitFullName(unit)
    if unit == "player" then
        return "Tester", "ClassicRealm"
    end
    local member = groupUnits[unit]
    if member then
        return member[1], member[2]
    end
end

function UnitName(unit)
    local name = UnitFullName(unit)
    return name
end

function UnitExists(unit)
    return unit == "player" or groupUnits[unit] ~= nil
end

function UnitGUID(unit)
    return unit == "player" and playerGUID or nil
end

function GetNormalizedRealmName()
    return "ClassicRealm"
end

function GetRealmName()
    return "Classic Realm"
end

function IsInGroup()
    return inGroup
end

function IsInRaid()
    return false
end

function GetNumGroupMembers()
    return inGroup and 2 or 0
end

function GetNumSubgroupMembers()
    return inGroup and 1 or 0
end

function IsInGuild()
    return #guildRoster > 0
end

function GetNumGuildMembers()
    return #guildRoster
end

function GetGuildRosterInfo(index)
    return guildRoster[index]
end

function GuildRoster()
end

function GetTime()
    return now
end

function SendChatMessage(message, channel, _, target)
    sentMessages[#sentMessages + 1] = { message = message, channel = channel, target = target }
end

function CombatLogGetCurrentEventInfo()
end

bit = {
    band = function(value, mask)
        return value == mask and mask or 0
    end,
}

COMBATLOG_OBJECT_TYPE_PLAYER = 1024
SlashCmdList = {}
DB_BuffResponder = {
    enabled = false,
    message = " legacy ",
    replyDelay = "bad",
    obsolete = true,
}

-- Load all addon files in TOC order into a fresh private table and log in
local function LoadAddon()
    local addon = {}
    for _, path in ipairs({ "Static.lua", "Core.lua", "Control.lua", "View.lua" }) do
        assert(loadfile(path))("BuffResponder", addon)
    end
    local eventFrame = frames[#frames]
    eventFrame.callback(eventFrame, "ADDON_LOADED", "BuffResponder")
    eventFrame.callback(eventFrame, "PLAYER_LOGIN")
    return addon, eventFrame
end

local Addon, eventFrame = LoadAddon()
Check("classic client uses the combat log", eventFrame.events.COMBAT_LOG_EVENT_UNFILTERED and not eventFrame.events.UNIT_AURA)

Check("false setting survives migration", Addon.Core.GetSetting("enabled") == false)
Check("legacy message migrates and trims", Addon.Core.GetSetting("message1") == "legacy")
Check("invalid delay uses default", Addon.Core.GetSetting("replyDelay") == 4)
Check("obsolete setting is removed", DB_BuffResponder.obsolete == nil)
Check("schema version is current", DB_BuffResponder.schemaVersion == Addon.Static.SchemaVersion)

local ok = Addon.Core.SetSetting("replyDelay", 31)
Check("delay maximum is enforced", ok == false)
ok = Addon.Core.SetSetting("enabled", "off")
Check("boolean type is enforced", ok == false)
ok = Addon.Core.SetSetting("message2", string.rep("x", 256))
Check("message length is enforced", ok == false)

local fullName, key, shortName = Addon.Control._Test.NormalizePlayerName("Other-Connected Realm", "ClassicRealm")
Check("realm names normalize", fullName == "Other-ConnectedRealm")
Check("identity key is case-insensitive", key == "other-connectedrealm")
Check("short display name is preserved", shortName == "Other")

SlashCmdList.BUFFR("on")
SlashCmdList.BUFFR("delay 2")
SlashCmdList.BUFFR("cooldown 10")
SlashCmdList.BUFFR("mode 1")
SlashCmdList.BUFFR("message1 cheers")
Check("commands update validated settings", Addon.Core.GetSetting("enabled") and Addon.Core.GetSetting("replyDelay") == 2)
Check("message command updates text", Addon.Core.GetSetting("message1") == "cheers")

-- Simulate a combat log aura event on the player
local function FireBuff(spellId, sourceName)
    Addon.Control.HandleCombatLog(
        now,
        "SPELL_AURA_APPLIED",
        false,
        "Player-1-00000002",
        sourceName,
        COMBATLOG_OBJECT_TYPE_PLAYER,
        0,
        playerGUID,
        "Tester-ClassicRealm",
        0,
        0,
        spellId,
        "Power Word: Fortitude"
    )
end

local timerCount = #timers
FireBuff(999999, "Other-ClassicRealm")
Check("unsupported buff is ignored", #timers == timerCount)

FireBuff(1243, "Other-ClassicRealm")
local replyTimer = timers[#timers]
Check("supported buff schedules reply", replyTimer.delay == 2 and not replyTimer.cancelled)

SlashCmdList.BUFFR("off")
Check("disabling cancels pending reply", replyTimer.cancelled)
Check("disabling clears pending state", next(Addon.Control._Test.GetScheduledWhispers()) == nil)
replyTimer.callback()
Check("cancelled reply sends nothing", #sentMessages == 0)

SlashCmdList.BUFFR("on")
FireBuff(1243, "Other-ClassicRealm")
replyTimer = timers[#timers]
replyTimer.callback()
Check("timer sends configured whisper", #sentMessages == 1 and sentMessages[1].message == "cheers")
Check("full identity is whisper target", sentMessages[1].target == "Other-ClassicRealm")

timerCount = #timers
FireBuff(1243, "Other-ClassicRealm")
Check("cooldown prevents another timer", #timers == timerCount)

now = now + 11
FireBuff(1243, "Other-ClassicRealm")
Check("expired cooldown permits another timer", #timers == timerCount + 1)

local sentCount = #sentMessages
FireBuff(1243, "LateJoiner-ClassicRealm")
replyTimer = timers[#timers]
inGroup = true
groupUnits.party1 = { "LateJoiner", "ClassicRealm" }
replyTimer.callback()
Check("send-time group revalidation cancels reply", #sentMessages == sentCount)
inGroup = false
groupUnits.party1 = nil

guildRoster = { "Guildie-ClassicRealm" }
Addon.Control.RefreshGuildRoster()
timerCount = #timers
FireBuff(1243, "Guildie-ClassicRealm")
Check("guild member is excluded", #timers == timerCount)

local passed, total = Addon.Control.RunSelfTest()
Check("local self-test passes", passed == total)

-- WoW Forever: aura detection and a manual thank-you prompt instead of whispers
interfaceVersion = 16001
Addon, eventFrame = LoadAddon()
Check("forever client uses UNIT_AURA", eventFrame.events.UNIT_AURA and not eventFrame.events.COMBAT_LOG_EVENT_UNFILTERED)

groupUnits.nameplate1 = { "Helper", "ClassicRealm" }
-- Simulate a buff added to the player on WoW Forever
local function FireAura(spellId, sourceUnit)
    Addon.Control.HandleAuraUpdate({ addedAuras = { { spellId = spellId, name = "Power Word: Fortitude", sourceUnit = sourceUnit } } })
end

timerCount = #timers
FireAura(1243, nil)
Check("aura with unknown caster is ignored", #timers == timerCount)

auraSecret = true
FireAura(1243, "nameplate1")
Check("secret aura data is skipped", #timers == timerCount)
auraSecret = false

sentCount = #sentMessages
FireAura(1243, "nameplate1")
timers[#timers].callback()
Check("forever never whispers automatically", #sentMessages == sentCount)
Check("forever queues a thank-you", Addon.Control.GetPendingThankCount() == 1)
Check("chat line carries a thank link", output[#output]:find("|Haddon:BuffResponder:thank:helper-classicrealm|h", 1, true) ~= nil)

linkCallback("addon:BuffResponder:thank:helper-classicrealm")
Check("thank link opens a prefilled whisper", openedChat == "/w Helper-ClassicRealm cheers")
Check("thanked player leaves the queue", Addon.Control.GetPendingThankCount() == 0)

openedChat = nil
SlashCmdList.BUFFR("thank")
Check("empty queue opens nothing", openedChat == nil)

passed, total = Addon.Control.RunSelfTest()
Check("forever self-test passes", passed == total)

io.write("\n")
if failures == 0 then
    io.write("\27[32m🟢 " .. tests .. "/" .. tests .. " tests passed\27[0m\n")
else
    io.write("\27[31m🔴 " .. failures .. "/" .. tests .. " tests failed\27[0m\n")
end

os.exit(failures == 0 and 0 or 1)
