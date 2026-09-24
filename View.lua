local _, Addon = ...
Addon.View = Addon.View or {}

local View = Addon.View
local Core = Addon.Core
local Static = Addon.Static

local function State(value)
    return value and "|cFF80FF80On|r" or "|cFFFF8080Off|r"
end

local function SetSetting(key, value, label)
    local ok, result = Core.SetSetting(key, value)
    if not ok then
        Core.Print(label .. " " .. result .. ".", "FFFF8080")
        return false
    end
    return true, result
end

local function ShowHelp()
    print("|cFF00FF00BuffResponder v" .. Core.GetVersion() .. "|r |cFFFFFFFF— commands|r")
    print("|cFF80D8FF/buffr status|r — show the current configuration")
    print("|cFF80D8FF/buffr on|off|r — enable or disable automatic replies")
    print("|cFF80D8FF/buffr message [text]|r — set message 1")
    print("|cFF80D8FF/buffr message1-5 [text]|r — set or clear a message")
    print("|cFF80D8FF/buffr mode random|1|2|3|4|5|r — choose message selection")
    print("|cFF80D8FF/buffr delay [0-" .. Static.Limits.replyDelayMax .. "]|r — set reply delay")
    print("|cFF80D8FF/buffr cooldown [0-" .. Static.Limits.cooldownDelayMax .. "]|r — set per-player cooldown")
    print("|cFF80D8FF/buffr excludegroup on|off|r — ignore group members")
    print("|cFF80D8FF/buffr excludeguild on|off|r — ignore guild members")
    print("|cFF80D8FF/buffr debug on|off|r — toggle diagnostic output")
    print("|cFF80D8FF/buffr test|r — run local checks without whispering")
    print("|cFF80D8FF/buffr reset|r — restore all defaults")
end

function View.ShowStatus()
    local settings = Core.GetSettings()
    print("|cFF00FF00BuffResponder v" .. Core.GetVersion() .. "|r |cFFFFFFFF— status|r")
    print("  Enabled: " .. State(settings.enabled))
    print("  |cFFFFFF80Messages|r")
    for index = 1, 5 do
        local message = settings["message" .. index]
        print("    " .. index .. ": " .. (message ~= "" and message or "|cFF808080(not set)|r"))
    end
    print("  Mode: |cFFFFFF80" .. settings.responseMode .. "|r")
    print("  Reply delay: |cFFFFFF80" .. settings.replyDelay .. " seconds|r")
    print("  Cooldown: |cFFFFFF80" .. settings.cooldownDelay .. " seconds|r")
    print("  Exclude group: " .. State(settings.excludeGroup))
    print("  Exclude guild: " .. State(settings.excludeGuild))
    print("  Debug: " .. State(settings.debugMode))
end

local function HandleEnabled(enabled)
    SetSetting("enabled", enabled, "Enabled")
    if not enabled then
        Addon.Control.CancelAllScheduled("addon disabled")
    end
    Core.Print(enabled and "✅ Automatic replies enabled." or "⏸ Automatic replies disabled.")
end

local function HandleMessage(command, args)
    local index = command == "message" and "1" or command:match("^message([1-5])$")
    if not index then
        return false
    end

    local message = Core.Trim(args)
    if command == "message" and message == "" then
        Core.Print("Provide message text.", "FFFF8080")
        return true
    end

    local ok, result = SetSetting("message" .. index, message, "Message " .. index)
    if ok then
        Core.Print(result == "" and ("🧹 Message " .. index .. " cleared.") or ("💬 Message " .. index .. " set to: " .. result))
    end
    return true
end

local function HandleMode(args)
    local ok, mode = SetSetting("responseMode", args, "Response mode")
    if ok then
        Core.Print(mode == "random" and "🎲 Response mode set to random." or ("📌 Always using message " .. mode .. "."))
    end
end

local function HandleNumber(key, label, args)
    local ok, value = SetSetting(key, args, label)
    if ok then
        Core.Print("⏱ " .. label .. " set to " .. value .. " seconds.")
    end
end

local function HandleToggle(key, command, label, args)
    local value = Core.Trim(args):lower()
    if value ~= "on" and value ~= "off" then
        Core.Print("Usage: /buffr " .. command .. " on|off", "FFFF8080")
        return
    end

    local enabled = value == "on"
    if SetSetting(key, enabled, label) then
        Core.Print((enabled and "✅ " or "⛔ ") .. label .. ": " .. (enabled and "on" or "off") .. ".")
    end
end

local commands = {
    help = function()
        ShowHelp()
    end,
    status = function()
        View.ShowStatus()
    end,
    on = function()
        HandleEnabled(true)
    end,
    off = function()
        HandleEnabled(false)
    end,
    mode = function(args)
        HandleMode(args)
    end,
    delay = function(args)
        HandleNumber("replyDelay", "Reply delay", args)
    end,
    cooldown = function(args)
        HandleNumber("cooldownDelay", "Cooldown", args)
    end,
    excludegroup = function(args)
        HandleToggle("excludeGroup", "excludegroup", "Exclude group", args)
    end,
    excludeguild = function(args)
        HandleToggle("excludeGuild", "excludeguild", "Exclude guild", args)
    end,
    debug = function(args)
        HandleToggle("debugMode", "debug", "Debug", args)
    end,
    test = function()
        Core.Print("🧪 Running local checks; no whisper will be sent.")
        local passed, total = Addon.Control.RunSelfTest()
        Core.Print((passed == total and "✅ " or "⚠️ ") .. passed .. "/" .. total .. " checks passed.")
    end,
    reset = function()
        Addon.Control.CancelAllScheduled("settings reset")
        Core.ResetSettings()
        Core.Print("♻️ Settings restored to defaults.")
        View.ShowStatus()
    end,
}

local function SlashCommandHandler(input)
    local command, args = Core.Trim(input):match("^(%S*)%s*(.-)$")
    command = command:lower()

    if command == "" then
        command = "help"
    end

    if HandleMessage(command, args) then
        return
    end

    local handler = commands[command]
    if not handler then
        Core.Print("Unknown command. Type /buffr for help.", "FFFF8080")
        return
    end
    handler(args)
end

function View.Initialize()
    SLASH_BUFFR1 = "/buffr"
    SlashCmdList.BUFFR = SlashCommandHandler
end

View._Test = {
    SlashCommandHandler = SlashCommandHandler,
}
