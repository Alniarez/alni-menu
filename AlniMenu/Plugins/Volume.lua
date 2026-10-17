-- AlniMenu/Plugins/Volume.lua
-- The volume widget.

if not (AlniMenu and AlniMenu.RegisterWidget) then
    return
end

--- The master volume, 0 to 100
---@return integer
local function Volume()
    return math.floor((tonumber(GetCVar("Sound_MasterVolume")) or 0) * 100 + 0.5)
end

AlniMenu.RegisterWidget("volume", {
    text = "Volume",
    create = function(row)
        local slider = row.lib:CreateSlider(row, {
            width = row:GetWidth() - 40,
            value = Volume(),
            onChange = function(value)
                value = math.floor(value + 0.5)
                -- also called on create and show
                if value ~= Volume() then
                    SetCVar("Sound_MasterVolume", value / 100)
                end
                if row.name then
                    row:SetText(row.name)
                end
            end,
        })
        slider:SetPoint("TOP", 0, -2)
        row.label:ClearAllPoints()
        row.label:SetPoint("TOP", slider, "BOTTOM", 0, -4)
        -- it may have changed elsewhere
        row:SetScript("OnShow", function() slider:SetValue(Volume()) end)
    end,
    update = function(row)
        row.label:SetText(row.name .. " " .. Volume() .. "%")
    end,
})
