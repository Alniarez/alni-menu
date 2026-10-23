-- AlniMenu/Plugins/Durability.lua
-- The durability widget.

if not (AlniMenu and AlniMenu.RegisterWidget) then
    return
end

local EQUIPPED_SLOTS = 19

--- `percent` in green, yellow or red
---@param percent integer
---@return string
local function DurabilityColor(percent)
    if percent >= 50 then
        return "|cff00ff00"
    elseif percent >= 25 then
        return "|cffffff00"
    end
    return "|cffff0000"
end

--- Lowest durability of the equipped items in percent (nil if none), and the damaged ones
---@return integer?
---@return table
local function Durability()
    local lowest
    local damaged = {}
    for slot = 1, EQUIPPED_SLOTS do
        local current, maximum = GetInventoryItemDurability(slot)
        if current and maximum and maximum > 0 then
            local percent = math.floor(current / maximum * 100)
            lowest = math.min(lowest or 100, percent)
            if percent < 100 then
                table.insert(damaged, { link = GetInventoryItemLink("player", slot), percent = percent })
            end
        end
    end
    table.sort(damaged, function(a, b) return a.percent < b.percent end)
    return lowest, damaged
end

AlniMenu.RegisterWidget("durability", {
    text = "Durability",
    create = function(row)
        row:SetScript("OnShow", function()
            row:SetText(row.name)
            row:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
        end)
        row:SetScript("OnHide", function() row:UnregisterAllEvents() end)
        row:SetScript("OnEvent", function()
            row:SetText(row.name)
            -- and the tooltip, if it is showing
            if GameTooltip:IsOwned(row) then
                row:GetScript("OnEnter")(row)
            end
        end)
        row.lib:AddTooltip(row, function()
            local _, damaged = Durability()
            if #damaged == 0 then
                return row.name, "Nothing is damaged."
            end
            local lines = {}
            for _, item in ipairs(damaged) do
                table.insert(lines, DurabilityColor(item.percent) .. item.percent .. "%|r  " .. (item.link or "?"))
            end
            return row.name, table.concat(lines, "\n")
        end)
    end,
    update = function(row)
        local lowest = Durability()
        if lowest then
            row.label:SetText(row.name .. " " .. DurabilityColor(lowest) .. lowest .. "%|r")
        else
            row.label:SetText(row.name)
        end
    end,
})
