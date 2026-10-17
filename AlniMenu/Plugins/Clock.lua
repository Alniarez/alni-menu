-- AlniMenu/Plugins/Clock.lua
-- The clock widget.

if not (AlniMenu and AlniMenu.RegisterWidget) then
    return
end

--- Today's date, in the game's own words ("Friday, October 17, 2026")
---@return string
local function Today()
    local t = date("*t")
    if FULLDATE and CALENDAR_WEEKDAY_NAMES and CALENDAR_FULLDATE_MONTH_NAMES then
        return FULLDATE:format(CALENDAR_WEEKDAY_NAMES[t.wday], CALENDAR_FULLDATE_MONTH_NAMES[t.month], t.day, t.year)
    end
    return date("%A, %d %B %Y")
end

AlniMenu.RegisterWidget("clock", {
    text = "Clock",
    create = function(row)
        -- update every second while the menu is open
        row:SetScript("OnShow", function()
            row:SetText(row.name)
            row.ticker = C_Timer.NewTicker(1, function() row:SetText(row.name) end)
        end)
        row:SetScript("OnHide", function()
            if row.ticker then
                row.ticker:Cancel()
            end
        end)
        -- a click opens the game's clock window
        row:EnableMouse(true)
        row:SetScript("OnMouseUp", function(_, button)
            if button == "LeftButton" and ToggleTimeManager then
                AlniMenu.HideMenu()
                ToggleTimeManager()
            end
        end)
        row.lib:AddTooltip(row, function()
            local hour, minute = GetGameTime()
            local text = Today() .. "\n" .. ("Realm time: %02d:%02d"):format(hour, minute)
            if ToggleTimeManager then
                text = text .. "\n\n|cff00ff00Click to open the clock|r"
            end
            return row.name, text
        end)
    end,
    update = function(row)
        row.label:SetText(row.name .. " " .. date("%H:%M:%S"))
    end,
})
