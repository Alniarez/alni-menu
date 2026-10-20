-- AlniMenu/Core.lua
-- Saved settings, and Esc opening AlniMenu instead of the Game Menu.
--
-- Not RegisterGameMenuEscHandler: adding to it from addon code taints Blizzard's own Esc handlers.
--
-- The Game Menu still opens:
--   in combat       AlniMenu's secure buttons can't be shown then
--   with Shift+Esc  always
--   once allowed    from AlniMenu's Blizzard Menu button

local ADDON_NAME, ns = ...

local Lib = {}
for k, v in pairs(AlnUI) do
    Lib[k] = v
end
ns.Lib = Lib

--------------------------------------------------
-- Configuration
--------------------------------------------------

local DEBUG = AlniDev and AlniDev.debug[ADDON_NAME] or false   -- also shows the debug view's bug icon on the menu

local function DebugPrint(...)
    if DEBUG then
        print("|cff33ff99" .. ADDON_NAME .. ":|r", ...)
    end
end
ns.DebugPrint = DebugPrint
ns.DEBUG = DEBUG

local DEFAULTS = {
    theme = "modern",   -- the Game Menu's own border
}

--------------------------------------------------
-- Saved settings
--------------------------------------------------

local function InitDB()
    AlniMenuDB = AlniMenuDB or {}
    for key, value in pairs(DEFAULTS) do
        if AlniMenuDB[key] == nil then
            AlniMenuDB[key] = value
        end
    end
    -- the player's own names for the built-in buttons, by key
    AlniMenuDB.labels = AlniMenuDB.labels or {}
    -- the player's own macro buttons (Custom.lua)
    AlniMenuDB.custom = AlniMenuDB.custom or {}
    AlniMenuDB.nextCustom = AlniMenuDB.nextCustom or 1
    ns.LoadCustomEntries()
    -- widgets added more than once, like separators
    AlniMenuDB.instances = AlniMenuDB.instances or {}
    AlniMenuDB.nextInstance = AlniMenuDB.nextInstance or 1
    if AlniMenuDB.separators then
        for id in pairs(AlniMenuDB.separators) do
            AlniMenuDB.instances["separator" .. id] = "separator"
        end
        AlniMenuDB.nextInstance = math.max(AlniMenuDB.nextInstance, AlniMenuDB.nextSeparator or 1)
        AlniMenuDB.separators, AlniMenuDB.nextSeparator = nil, nil
    end
    -- layouts saved from edit mode
    AlniMenuDB.layouts = AlniMenuDB.layouts or {}
    -- what widgets save for themselves (row.settings)
    AlniMenuDB.widgetSettings = AlniMenuDB.widgetSettings or {}
    AlniMenuDB.buttons = AlniMenuDB.buttons or {}
end

--- The layout, at PLAYER_LOGIN when every addon has registered its widgets
local function InitLayout()
    ns.LoadInstances()
    -- which buttons are on, missing ones use their default
    for key, entry in pairs(ns.ENTRIES) do
        if not entry.always and AlniMenuDB.buttons[key] == nil then
            AlniMenuDB.buttons[key] = entry.default and true or false
        end
    end
    -- which button goes in which category
    ns.CheckLayout()
    ns.FixSavedLayouts()
    ns.ready = true
end

--------------------------------------------------
-- Esc
--------------------------------------------------

local function HookEscape()
    -- a post-hook: Blizzard's code opening the menu stays untainted
    GameMenuFrame:HookScript("OnShow", function()
        if ns.allowBlizzardMenu then
            ns.allowBlizzardMenu = false
            DebugPrint("Game Menu allowed once")
            return
        end
        if InCombatLockdown() or IsShiftKeyDown() then
            return
        end
        HideUIPanel(GameMenuFrame)
        ns.ShowMenu()
    end)
end

--------------------------------------------------
-- Events
--------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
-- say what Blizzard blocked, so it can move to a secure button
events:RegisterEvent("ADDON_ACTION_FORBIDDEN")
events:RegisterEvent("ADDON_ACTION_BLOCKED")
events:SetScript("OnEvent", function(self, event, name, func)
    if (event == "ADDON_ACTION_FORBIDDEN" or event == "ADDON_ACTION_BLOCKED") then
        if name == ADDON_NAME then
            print("|cff33ff99" .. ADDON_NAME .. ":|r " .. event .. ": " .. tostring(func))
        end
        return
    end
    if event == "ADDON_LOADED" and name == ADDON_NAME then
        self:UnregisterEvent("ADDON_LOADED")
        InitDB()
        HookEscape()
    elseif event == "PLAYER_LOGIN" then
        InitLayout()
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- last moment its secure buttons can still be hidden
        ns.HideMenu()
    end
end)

--------------------------------------------------
-- Slash command
--------------------------------------------------

SLASH_ALNIMENU1 = "/alnimenu"
SlashCmdList.ALNIMENU = function(msg)
    if InCombatLockdown() then
        print("|cff33ff99" .. ADDON_NAME .. ":|r not in combat.")
    elseif strtrim(msg or ""):lower() == "edit" then
        ns.SetEditing(true)
    elseif not ns.HideMenu() then
        ns.ShowMenu()
    end
end
