local addonName, Addon = ...
Addon.View = Addon.View or {}

local function ShowHelp()
    print("|cFF00FF00Thanker Commands:|r")
    print("----------------------------------------------------")
    print("Thanker - Automatically thanks for a buff")
    print("----------------------------------------------------")
    print("  /thanker - Show this help")
    print("  /thanker status - Show current configuration")
    print("  /thanker on/off - Enable/Disable the addon")
    print("  /thanker message <text> - Set the whisper message")
    print("  /thanker delay <seconds> - Set reply delay (default: 4)")
    print("  /thanker cooldown <seconds> - Set per-player cooldown (default: 60)")
    print("  /thanker excludegroup on/off - Exclude group members from whispers")
    print("  /thanker excludeguild on/off - Exclude guild members from whispers")
    print("  /thanker debug on/off - Enable/Disable debug mode (allows self-buff testing)")
    print("----------------------------------------------------")
end

function Addon.View.ShowStatus()
    print("|cFF00FF00Thanker Status:|r")
    print("  Enabled: " .. (DB_Thanker.enabled and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
    print("  Message: " .. DB_Thanker.message)
    print("  Reply Delay: " .. DB_Thanker.replyDelay .. " seconds")
    print("  Cooldown: " .. DB_Thanker.cooldownDelay .. " seconds")
    print("  Exclude Group: " .. (DB_Thanker.excludeGroup and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
    print("  Exclude Guild: " .. (DB_Thanker.excludeGuild and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
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
    elseif command == "excludegroup" then
        local toggleCmd = args:lower():trim()
        if toggleCmd == "on" then
            DB_Thanker.excludeGroup = true
            print("|cFF00FF00Thanker:|r Group members will be excluded from whispers.")
        elseif toggleCmd == "off" then
            DB_Thanker.excludeGroup = false
            print("|cFF00FF00Thanker:|r Group members will receive whispers.")
        else
            print("|cFFFF0000Thanker:|r Usage: /thanker excludegroup on|off")
        end
    elseif command == "excludeguild" then
        local toggleCmd = args:lower():trim()
        if toggleCmd == "on" then
            DB_Thanker.excludeGuild = true
            print("|cFF00FF00Thanker:|r Guild members will be excluded from whispers.")
        elseif toggleCmd == "off" then
            DB_Thanker.excludeGuild = false
            print("|cFF00FF00Thanker:|r Guild members will receive whispers.")
        else
            print("|cFFFF0000Thanker:|r Usage: /thanker excludeguild on|off")
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
    else
        print("|cFFFF0000Thanker:|r Unknown command. Type /thanker for help.")
    end
end

function Addon.View.Initialize()
    SLASH_THANKER1 = "/thanker"
    SlashCmdList["THANKER"] = SlashCommandHandler
end
