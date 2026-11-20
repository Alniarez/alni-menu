-- AlniMenu/Settings.lua
-- AlniMenu's page in the game's Settings panel.

local ADDON_NAME, ns = ...

-- every theme
local THEME_DESCRIPTIONS = {
    basic    = "A metal window frame with a title bar.",
    gold     = "A gold dialog border with a title banner.",
    panel    = "The frame of windows like the Character window.",
    modern   = "The Game Menu's border and header.",
    standard = "A grey dialog border with a title banner.",
    tooltip  = "A tooltip's thin border.",
}

local function GetThemeOptions()
    local list = {}
    for _, name in ipairs(ns.Lib:GetThemes()) do
        table.insert(list, { value = name, label = name:sub(1, 1):upper() .. name:sub(2), tooltip = THEME_DESCRIPTIONS[name] })
    end
    return list
end

StaticPopupDialogs.ALNIMENU_ERASE_DATA = {
    text         = "Erase all AlniMenu data (layout, custom buttons, saved layouts, theme) and reload the UI?",
    button1      = ACCEPT or "Accept",
    button2      = CANCEL or "Cancel",
    OnAccept     = function()
        AlniMenuDB = nil
        ReloadUI()
    end,
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
    showAlert    = true,
}

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
    if name ~= ADDON_NAME then
        return
    end
    self:UnregisterAllEvents()

    if AlniMenuDB.theme == nil then
        AlniMenuDB.theme = "modern"
    end

    local page = ns.Lib:CreateSettingsPage({ name = "AlniMenu" })

    page:AddDropdown({
        label   = "Theme",
        tooltip = "The border and title style of the menu.",
        options = GetThemeOptions,
        get     = function() return AlniMenuDB.theme end,
        set     = function(value)
            AlniMenuDB.theme = value
            ns.ApplyTheme()
        end,
    })

    -- buttons and categories are edited on the menu itself
    page:AddButton({
        label   = "Buttons and categories",
        text    = "Edit Layout",
        tooltip = "Opens the menu in edit mode: show or hide buttons, move them between categories, "
            .. "and add, rename or reorder categories. The gear in the menu's corner does the same.",
        onClick = function() ns.SetEditing(true) end,
    })

    page:AddButton({
        label   = "Custom buttons",
        text    = "Manage",
        tooltip = "Every custom button, in the menu or not, to edit or delete.",
        onClick = function() ns.ShowCustomList() end,
    })

    page:AddButton({
        label   = "Erase all data",
        text    = "Erase",
        tooltip = "Back to a new install: the Original layout, no custom buttons or saved layouts. Reloads the UI.",
        onClick = function() StaticPopup_Show("ALNIMENU_ERASE_DATA") end,
    })

    ns.settingsCategory = page:Register()
end)
