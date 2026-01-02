local addonName, Addon = ...
Addon.View = Addon.View or {}

local function ShowHelp()
    print("|cFF00FF00Thanker Commands:|r")
    print("  /thanker - Show this help")
    print("  /thanker status - Show current configuration")
    print("  /thanker on - Enable the addon")
    print("  /thanker off - Disable the addon")
    print("  /thanker message <text> - Set the whisper message")
    print("  /thanker delay <seconds> - Set reply delay (default: 2)")
    print("  /thanker cooldown <seconds> - Set per-player cooldown (default: 30)")
    print("  /thanker debug on - Enable debug mode (allows self-buff testing)")
    print("  /thanker debug off - Disable debug mode")
    print("  /thanker test - Test the whisper (in debug mode only)")
end

function Addon.View.ShowStatus()
    print("|cFF00FF00Thanker Status:|r")
    print("  Enabled: " .. (DB_Thanker.enabled and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
    print("  Message: " .. DB_Thanker.message)
    print("  Reply Delay: " .. DB_Thanker.replyDelay .. " seconds")
    print("  Cooldown: " .. DB_Thanker.cooldownDelay .. " seconds")
    print("  Debug Mode: " .. (DB_Thanker.debugMode and "|cFF00FF00On|r" or "|cFFFF0000Off|r"))
end

local function SlashCommandHandler(msg)
    local command, args = msg:match("^(%S*)%s*(.-)$")
    command = command:lower()

    if command == "" or command == "help" then
        ShowHelp()
    elseif command == "status" then
        Addon.View.ShowStatus()
    elseif command == "on" then
        DB_Thanker.enabled = true
        print("|cFF00FF00Thanker:|r Enabled")
    elseif command == "off" then
        DB_Thanker.enabled = false
        print("|cFF00FF00Thanker:|r Disabled")
    elseif command == "message" then
        if args and args:trim() ~= "" then
            DB_Thanker.message = args:trim()
            print("|cFF00FF00Thanker:|r Message set to: " .. DB_Thanker.message)
        else
            print("|cFFFF0000Thanker:|r Please provide a message.")
        end
    elseif command == "delay" then
        local delay = tonumber(args)
        if delay and delay >= 0 then
            DB_Thanker.replyDelay = delay
            print("|cFF00FF00Thanker:|r Reply delay set to " .. delay .. " seconds")
        else
            print("|cFFFF0000Thanker:|r Please provide a valid number (>= 0)")
        end
    elseif command == "cooldown" then
        local cooldown = tonumber(args)
        if cooldown and cooldown >= 0 then
            DB_Thanker.cooldownDelay = cooldown
            print("|cFF00FF00Thanker:|r Cooldown set to " .. cooldown .. " seconds")
        else
            print("|cFFFF0000Thanker:|r Please provide a valid number (>= 0)")
        end
    elseif command == "debug" then
        local debugCmd = args:lower():trim()
        if debugCmd == "on" then
            DB_Thanker.debugMode = true
            print("|cFF00FF00Thanker:|r Debug mode enabled. You can now buff yourself to test whispers.")
        elseif debugCmd == "off" then
            DB_Thanker.debugMode = false
            print("|cFF00FF00Thanker:|r Debug mode disabled.")
        else
            print("|cFFFF0000Thanker:|r Usage: /thanker debug on|off")
        end
    elseif command == "test" then
        Addon.Control.TestWhisper()
    else
        print("|cFFFF0000Thanker:|r Unknown command. Type /thanker for help.")
    end
end

function Addon.View.Initialize()
    SLASH_THANKER1 = "/thanker"
    SlashCmdList["THANKER"] = SlashCommandHandler
end
