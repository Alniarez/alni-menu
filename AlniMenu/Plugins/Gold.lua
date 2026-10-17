-- AlniMenu/Plugins/Gold.lua
-- The gold widget.

if not (AlniMenu and AlniMenu.RegisterWidget) then
    return
end

--- `money` (in copper) as the game shows it, with coin icons
---@param money integer
---@return string
local function MoneyText(money)
    if GetMoneyString then
        return GetMoneyString(money, true)
    end
    return GetCoinTextureString(money)
end

AlniMenu.RegisterWidget("gold", {
    text = "Gold",
    create = function(row)
        row:SetScript("OnShow", function()
            row:SetText(row.name)
            row:RegisterEvent("PLAYER_MONEY")
        end)
        row:SetScript("OnHide", function() row:UnregisterAllEvents() end)
        row:SetScript("OnEvent", function() row:SetText(row.name) end)
    end,
    update = function(row)
        row.label:SetText(row.name .. " " .. MoneyText(GetMoney()))
    end,
})
