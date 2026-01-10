local addonName, Addon = ...
Addon.View = Addon.View or {}

local function ShowHelp()
    print("|cFF00FF00BuffResponder Commands:|r")
    print("----------------------------------------------------")
    print("BuffResponder 1.2 - Automatically responds when getting buffed")
    print("----------------------------------------------------")
    print("  /buffr - Show this help")
    print("  /buffr status - Show current configuration")
    print("  /buffr on/off - Enable/Disable the addon")
    print("  /buffr message [text] - Set message #1")
    print("  /buffr message1-5 [text] - Set specific message")
    print("  /buffr mode [mode] - Set response mode")
    print("    random = pick randomly from non-empty messages")
    print("    1, 2, 3, 4, or 5 = always use that message")
    print("  /buffr delay [seconds] - Set reply delay (default: 4)")
    print("  /buffr cooldown [seconds] - Per-player cooldown (default: 60)")
    print("  /buffr excludegroup on/off - Exclude group members")
    print("  /buffr excludeguild on/off - Exclude guild members")
    print("  /buffr debug on/off - Enable/Disable debug mode")
    print("  /buffr reset - Reset all settings to default values")
    print("----------------------------------------------------")
end

function Addon.View.ShowStatus()
    print("|cFF00FF00BuffResponder Status:|r")
    print("  Enabled: " .. (DB_BuffResponder.enabled and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
    print("  |cFFFFFF00Messages:|r")
    for i = 1, 5 do
        local msg = DB_BuffResponder["message" .. i]
        if msg and msg:trim() ~= "" then
            print("    Message " .. i .. ": " .. msg)
        else
            print("    Message " .. i .. ": |cFF808080(not set)|r")
        end
    end
    print("  Response Mode: |cFFFFFF00" .. DB_BuffResponder.responseMode .. "|r")
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
            DB_BuffResponder.message1 = args:trim()
            print("|cFF00FF00BuffResponder:|r Message 1 set to: " .. DB_BuffResponder.message1)
        else
            print("|cFFFF0000BuffResponder:|r Please provide a message.")
        end
    elseif command == "message1" or command == "message2" or command == "message3" or command == "message4" or command == "message5" then
        local msgNum = command:sub(-1)
        if args and args:trim() ~= "" then
            DB_BuffResponder["message" .. msgNum] = args:trim()
            print("|cFF00FF00BuffResponder:|r Message " .. msgNum .. " set to: " .. DB_BuffResponder["message" .. msgNum])
        else
            DB_BuffResponder["message" .. msgNum] = ""
            print("|cFF00FF00BuffResponder:|r Message " .. msgNum .. " cleared.")
        end
    elseif command == "mode" then
        local mode = args:lower():trim()
        if mode == "random" or mode == "1" or mode == "2" or mode == "3" or mode == "4" or mode == "5" then
            DB_BuffResponder.responseMode = mode
            if mode == "random" then
                print("|cFF00FF00BuffResponder:|r Response mode set to: Random (picks from all non-empty messages)")
            else
                print("|cFF00FF00BuffResponder:|r Response mode set to: Always use Message " .. mode)
            end
        else
            print("|cFFFF0000BuffResponder:|r Invalid mode. Use: random, 1, 2, 3, 4, or 5")
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
    elseif command == "reset" then
        Addon.Core.ResetSettings()
        print("|cFF00FF00BuffResponder:|r All settings have been reset to default values.")
        Addon.View.ShowStatus()
    else
        print("|cFFFF0000BuffResponder:|r Unknown command. Type /buffr for help.")
    end
end

function Addon.View.Initialize()
    SLASH_BUFFR1 = "/buffr"
    SlashCmdList["BUFFR"] = SlashCommandHandler
end
