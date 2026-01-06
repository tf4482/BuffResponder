local addonName, Addon = ...
Addon.View = Addon.View or {}

local function ShowHelp()
    print("|cFF00FF00BuffResponder Commands:|r")
    print("----------------------------------------------------")
    print("BuffResponder - Automatically responds when getting buffed")
    print("----------------------------------------------------")
    print("  /buffr - Show this help")
    print("  /buffr status - Show current configuration")
    print("  /buffr on/off - Enable/Disable the addon")
    print("  /buffr message <text> - Set the whisper message")
    print("  /buffr delay <seconds> - Set reply delay (default: 4)")
    print("  /buffr cooldown <seconds> - Set per-player cooldown (default: 60)")
    print("  /buffr excludegroup on/off - Exclude group members from whispers")
    print("  /buffr excludeguild on/off - Exclude guild members from whispers")
    print("  /buffr debug on/off - Enable/Disable debug mode (allows self-buff testing)")
    print("----------------------------------------------------")
end

function Addon.View.ShowStatus()
    print("|cFF00FF00BuffResponder Status:|r")
    print("  Enabled: " .. (DB_BuffResponder.enabled and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
    print("  Message: " .. DB_BuffResponder.message)
    print("  Reply Delay: " .. DB_BuffResponder.replyDelay .. " seconds")
    print("  Cooldown: " .. DB_BuffResponder.cooldownDelay .. " seconds")
    print("  Exclude Group: " .. (DB_BuffResponder.excludeGroup and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
    print("  Exclude Guild: " .. (DB_BuffResponder.excludeGuild and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
    print("  Debug Mode: " .. (DB_BuffResponder.debugMode and "|cFF00FF00On|r" or "|cFFFF0000Off|r"))
end

local function SlashCommandHandler(msg)
    local command, args = msg:match("^(%S*)%s*(.-)$")
    command = command:lower()

    if command == "" or command == "help" then
        ShowHelp()
    elseif command == "status" then
        Addon.View.ShowStatus()
    elseif command == "on" then
        DB_BuffResponder.enabled = true
        print("|cFF00FF00BuffResponder:|r Enabled")
    elseif command == "off" then
        DB_BuffResponder.enabled = false
        print("|cFF00FF00BuffResponder:|r Disabled")
    elseif command == "message" then
        if args and args:trim() ~= "" then
            DB_BuffResponder.message = args:trim()
            print("|cFF00FF00BuffResponder:|r Message set to: " .. DB_BuffResponder.message)
        else
            print("|cFFFF0000BuffResponder:|r Please provide a message.")
        end
    elseif command == "delay" then
        local delay = tonumber(args)
        if delay and delay >= 0 then
            DB_BuffResponder.replyDelay = delay
            print("|cFF00FF00BuffResponder:|r Reply delay set to " .. delay .. " seconds")
        else
            print("|cFFFF0000BuffResponder:|r Please provide a valid number (>= 0)")
        end
    elseif command == "cooldown" then
        local cooldown = tonumber(args)
        if cooldown and cooldown >= 0 then
            DB_BuffResponder.cooldownDelay = cooldown
            print("|cFF00FF00BuffResponder:|r Cooldown set to " .. cooldown .. " seconds")
        else
            print("|cFFFF0000BuffResponder:|r Please provide a valid number (>= 0)")
        end
    elseif command == "excludegroup" then
        local toggleCmd = args:lower():trim()
        if toggleCmd == "on" then
            DB_BuffResponder.excludeGroup = true
            print("|cFF00FF00BuffResponder:|r Group members will be excluded from whispers.")
        elseif toggleCmd == "off" then
            DB_BuffResponder.excludeGroup = false
            print("|cFF00FF00BuffResponder:|r Group members will receive whispers.")
        else
            print("|cFFFF0000BuffResponder:|r Usage: /buffr excludegroup on|off")
        end
    elseif command == "excludeguild" then
        local toggleCmd = args:lower():trim()
        if toggleCmd == "on" then
            DB_BuffResponder.excludeGuild = true
            print("|cFF00FF00BuffResponder:|r Guild members will be excluded from whispers.")
        elseif toggleCmd == "off" then
            DB_BuffResponder.excludeGuild = false
            print("|cFF00FF00BuffResponder:|r Guild members will receive whispers.")
        else
            print("|cFFFF0000BuffResponder:|r Usage: /buffr excludeguild on|off")
        end
    elseif command == "debug" then
        local debugCmd = args:lower():trim()
        if debugCmd == "on" then
            DB_BuffResponder.debugMode = true
            print("|cFF00FF00BuffResponder:|r Debug mode enabled. You can now buff yourself to test whispers.")
        elseif debugCmd == "off" then
            DB_BuffResponder.debugMode = false
            print("|cFF00FF00BuffResponder:|r Debug mode disabled.")
        else
            print("|cFFFF0000BuffResponder:|r Usage: /buffr debug on|off")
        end
    else
        print("|cFFFF0000BuffResponder:|r Unknown command. Type /buffr for help.")
    end
end

function Addon.View.Initialize()
    SLASH_BUFFR1 = "/buffr"
    SlashCmdList["BUFFR"] = SlashCommandHandler
end
