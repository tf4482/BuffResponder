
DB_Thanker = DB_Thanker or {
    ["thanker"] = "/run ShowUIPanel(ThankerFrame)",
}

function string:trim()
    return self:match("^%s*(.-)%s*$")
end

local frame = CreateFrame("FRAME")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", OnAddonLoaded)
