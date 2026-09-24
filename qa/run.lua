local failures = 0
local tests = 0

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

function print(message)
    output[#output + 1] = tostring(message)
end

function CreateFrame()
    local frame = { events = {} }
    function frame:RegisterEvent(event)
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

local Addon = {}
local function LoadAddonFile(path)
    local chunk = assert(loadfile(path))
    chunk("BuffResponder", Addon)
end

LoadAddonFile("Static.lua")
LoadAddonFile("Core.lua")
LoadAddonFile("Control.lua")
LoadAddonFile("View.lua")

local eventFrame = frames[1]
eventFrame.callback(eventFrame, "ADDON_LOADED", "BuffResponder")
eventFrame.callback(eventFrame, "PLAYER_LOGIN")

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

io.write("\n")
if failures == 0 then
    io.write("\27[32m🟢 " .. tests .. "/" .. tests .. " tests passed\27[0m\n")
else
    io.write("\27[31m🔴 " .. failures .. "/" .. tests .. " tests failed\27[0m\n")
end

os.exit(failures == 0 and 0 or 1)
