-- AlniMenu/Plugins/Experience.lua
-- The experience widget.

if not (AlniMenu and AlniMenu.RegisterWidget) then
    return
end

--- Whether the player still gains experience
---@return boolean
local function Leveling()
    if IsXPUserDisabled and IsXPUserDisabled() then
        return false
    end
    return not GetMaxLevelForPlayerExpansion or UnitLevel("player") < GetMaxLevelForPlayerExpansion()
end

--- Experience as numbers: xp, max, rested (0 when none), percent and rested percent
---@return integer, integer, integer, integer, integer
local function Experience()
    local xp, max, rested = UnitXP("player"), UnitXPMax("player"), GetXPExhaustion() or 0
    if max <= 0 then
        return xp, max, rested, 0, 0
    end
    return xp, max, rested, math.floor(xp / max * 100), math.floor(rested / max * 100)
end

AlniMenu.RegisterWidget("experience", {
    text = "Level",
    shown = Leveling,
    create = function(row)
        -- the bar: XP in purple over rested XP in blue, like the game's own
        local width = row:GetWidth() - 24
        row.rested = row.lib:CreateProgressBar(row, { width = width, height = 16, color = { 0.25, 0.5, 1, 0.6 } })
        row.rested:SetPoint("CENTER")
        row.bar = row.lib:CreateProgressBar(row, { width = width, height = 16, color = { 0.58, 0, 0.55 } })
        row.bar:SetPoint("CENTER")
        row.bar:SetFrameLevel(row.rested:GetFrameLevel() + 1)
        row.bar.bg:Hide()

        -- a click switches between text and bar
        row:EnableMouse(true)
        row:SetScript("OnMouseUp", function(_, button)
            if button == "LeftButton" then
                row.settings.bar = not row.settings.bar
                row:SetText(row.name)
            end
        end)
        row:SetScript("OnShow", function()
            row:SetText(row.name)
            row:RegisterEvent("PLAYER_XP_UPDATE")
            row:RegisterEvent("UPDATE_EXHAUSTION")
        end)
        row:SetScript("OnHide", function() row:UnregisterAllEvents() end)
        row:SetScript("OnEvent", function() row:SetText(row.name) end)
        row.lib:AddTooltip(row, function()
            local xp, max, rested = Experience()
            local text = BreakUpLargeNumbers(xp) .. " / " .. BreakUpLargeNumbers(max) .. " XP"
            if rested > 0 then
                text = text .. "\n" .. BreakUpLargeNumbers(rested) .. " rested"
            end
            text = text .. "\n\n|cff00ff00Click to switch between text and bar|r"
            return row.name .. " " .. UnitLevel("player"), text
        end)
    end,
    update = function(row)
        local xp, max, rested, percent, restedPercent = Experience()
        local showBar = row.settings.bar
        row.label:SetShown(not showBar)
        row.bar:SetShown(showBar)
        row.rested:SetShown(showBar)
        if showBar then
            row.rested:SetMinMaxValues(0, math.max(max, 1))
            row.rested:SetValue(math.min(xp + rested, max))
            row.bar:SetMinMaxValues(0, math.max(max, 1))
            row.bar:SetValue(xp)
            local text = UnitLevel("player") .. " - " .. percent .. "%"
            if rested > 0 then
                text = text .. " (+" .. restedPercent .. "%)"
            end
            row.bar.label:SetText(text)
            return
        end
        local text = row.name .. " " .. UnitLevel("player") .. " - " .. percent .. "%"
        if rested > 0 then
            text = text .. " |cff4d85e6(+" .. restedPercent .. "% rested)|r"
        end
        row.label:SetText(text)
    end,
})
