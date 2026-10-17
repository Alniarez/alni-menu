-- AlniMenu/Plugins/Bags.lua
-- The bag space widget.

if not (AlniMenu and AlniMenu.RegisterWidget) then
    return
end

local GetFree = C_Container and C_Container.GetContainerNumFreeSlots or GetContainerNumFreeSlots
local GetSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
local REAGENT_BAG = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag

--- Free and total slots in `first` to `last` of the player's bags
---@param first integer
---@param last integer
---@return integer
---@return integer
local function BagSpace(first, last)
    local free, total = 0, 0
    for bag = first, last do
        free = free + (GetFree(bag) or 0)
        total = total + (GetSlots(bag) or 0)
    end
    return free, total
end

--- `free` in red when 0, yellow when 5 or fewer
---@param free integer
---@return string
local function FreeColor(free)
    if free == 0 then
        return "|cffff0000" .. free .. "|r"
    elseif free <= 5 then
        return "|cffffff00" .. free .. "|r"
    end
    return tostring(free)
end

AlniMenu.RegisterWidget("bagspace", {
    text = "Bags",
    create = function(row)
        row:SetScript("OnShow", function()
            row:SetText(row.name)
            row:RegisterEvent("BAG_UPDATE_DELAYED")
        end)
        row:SetScript("OnHide", function() row:UnregisterAllEvents() end)
        row:SetScript("OnEvent", function() row:SetText(row.name) end)
        row.lib:AddTooltip(row, function()
            local free, total = BagSpace(0, NUM_BAG_SLOTS or 4)
            local text = free .. " of " .. total .. " free"
            if REAGENT_BAG and (GetSlots(REAGENT_BAG) or 0) > 0 then
                local reagentFree, reagentTotal = BagSpace(REAGENT_BAG, REAGENT_BAG)
                text = text .. "\nReagent bag: " .. reagentFree .. " of " .. reagentTotal .. " free"
            end
            return row.name, text
        end)
    end,
    update = function(row)
        local free, total = BagSpace(0, NUM_BAG_SLOTS or 4)
        row.label:SetText(row.name .. " " .. FreeColor(free) .. " / " .. total .. " free")
    end,
})
