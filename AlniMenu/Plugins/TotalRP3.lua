-- AlniMenu/Plugins/TotalRP3.lua
-- Total RP 3's toolbar as an AlniMenu widget.

if not (AlniMenu and AlniMenu.RegisterWidget) then
    return
end

local TRP3_ADDON = "totalRP3"
local LDB   -- LibDataBroker, from Total RP 3

-- TRP3 names its objects "TRP3", a dash, then the button
local PREFIX = "TRP3 "
local MAX_SIZE, GAP = 26, 4

--- TRP3's toolbar buttons on LibDataBroker. In the toolbar's order, with only the buttons it shows, when it has built
--- its list. Else all of them, by name.
---@return table
local function Objects()
    local list = {}
    for name, object in LDB:DataObjectIterator() do
        if name:sub(1, #PREFIX) == PREFIX then
            table.insert(list, { name = name, object = object })
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)

    local provider = TRP3_ToolbarFrame and TRP3_ToolbarFrame.GetDataProvider and TRP3_ToolbarFrame:GetDataProvider()
    if not provider then
        return list
    end
    -- each toolbar button's object is named after its configText
    local ordered = {}
    for _, button in provider:Enumerate() do
        local text = button.configText
        for _, item in ipairs(list) do
            if text and item.name:sub(-#text) == text then
                table.insert(ordered, item)
                break
            end
        end
    end
    return ordered
end

-- TRP3's windows. A click that opens one closes AlniMenu
local WINDOWS = { "TRP3_MainFrame", "TRP3_CurrentlyFrame", "TRP3_NPCTalkFrame" }

--- Which of TRP3's windows are shown
---@return table
local function ShownWindows()
    local shown = {}
    for _, name in ipairs(WINDOWS) do
        shown[name] = _G[name] and _G[name]:IsShown()
    end
    return shown
end

--- A toolbar button for the row
---@param row Frame
---@return Button
local function CreateIcon(row)
    local icon = CreateFrame("Button", nil, row)
    icon:RegisterForClicks("AnyUp")
    icon:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    icon:SetScript("OnClick", function(self, mouseButton)
        if not self.object.OnClick then
            return
        end
        local before = ShownWindows()
        self.object.OnClick(self, mouseButton)
        C_Timer.After(0, function()
            for name, shown in pairs(ShownWindows()) do
                if shown and not before[name] then
                    AlniMenu.HideMenu()
                    return
                end
            end
        end)
    end)
    icon:SetScript("OnEnter", function(self)
        if self.object.OnTooltipShow then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            self.object.OnTooltipShow(GameTooltip)
            GameTooltip:Show()
        end
    end)
    icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return icon
end

--- Shows TRP3's buttons in `row`, centered, as big as fits
---@param row Frame
local function Refresh(row)
    local list = Objects()
    local size = math.min(MAX_SIZE, (row:GetWidth() - 8 - (#list - 1) * GAP) / math.max(#list, 1))
    local width = #list * size + (#list - 1) * GAP
    for i, item in ipairs(list) do
        local icon = row.icons[i]
        if not icon then
            icon = CreateIcon(row)
            row.icons[i] = icon
        end
        icon.object = item.object
        icon:SetNormalTexture(item.object.icon)
        icon:SetSize(size, size)
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", row, "CENTER", -width / 2 + (i - 1) * (size + GAP), 0)
        icon:Show()
    end
    for i = #list + 1, #row.icons do
        row.icons[i]:Hide()
    end
end

--- Adds the widget, once Total RP 3 has loaded. Not a dependency: without it, nothing happens.
local function Register()
    LDB = LibStub and LibStub("LibDataBroker-1.1", true)
    if not LDB then
        return
    end
    AlniMenu.RegisterWidget("TotalRP3_Toolbar", {
        text = "Total RP 3",
        create = function(row)
            row.icons = {}
            -- TRP3 updates its icons every half second if TRP3 changes in a way this doesn't expect, stop after one
            -- error instead of one every half second
            local function SafeRefresh()
                local ok, err = pcall(Refresh, row)
                if not ok and row.ticker then
                    row.ticker:Cancel()
                    row.ticker = nil
                    print("|cff33ff99AlniMenu:|r Total RP 3 widget: " .. tostring(err))
                end
            end
            row:SetScript("OnShow", function()
                row.ticker = C_Timer.NewTicker(0.5, SafeRefresh)
                SafeRefresh()
            end)
            row:SetScript("OnHide", function()
                if row.ticker then
                    row.ticker:Cancel()
                end
            end)
        end,
        -- the icons are the row, no label
        update = function() end,
    })
end

local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
if isLoaded(TRP3_ADDON) then
    Register()
else
    -- before PLAYER_LOGIN, when AlniMenu checks the layout
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("ADDON_LOADED")
    watcher:SetScript("OnEvent", function(self, _, name)
        if name == TRP3_ADDON then
            self:UnregisterAllEvents()
            Register()
        end
    end)
end

