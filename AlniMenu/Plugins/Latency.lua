-- AlniMenu/Plugins/Latency.lua
-- The latency widget.

if not (AlniMenu and AlniMenu.RegisterWidget) then
    return
end

--- `ms` in green, yellow or red, as the micro menu colors latency
---@param ms number
---@return string
local function Colored(ms)
    local color = "|cffff0000"
    if ms < (PERFORMANCEBAR_LOW_LATENCY or 300) then
        color = "|cff00ff00"
    elseif ms < (PERFORMANCEBAR_MEDIUM_LATENCY or 600) then
        color = "|cffffff00"
    end
    return color .. ms .. "|r"
end

AlniMenu.RegisterWidget("latency", {
    text = "Latency",
    create = function(row)
        -- every second while the menu is open
        row:SetScript("OnShow", function()
            row:SetText(row.name)
            row.ticker = C_Timer.NewTicker(1, function() row:SetText(row.name) end)
        end)
        row:SetScript("OnHide", function()
            if row.ticker then
                row.ticker:Cancel()
            end
            row.ticker = nil
        end)
        row.lib:AddTooltip(row, function()
            return row.name, "Home: chat, friends and addons.\nWorld: combat and everything around you."
        end)
    end,
    update = function(row)
        local _, _, home, world = GetNetStats()
        row.label:SetText(row.name .. " " .. Colored(home) .. " / " .. Colored(world) .. " ms")
    end,
})
