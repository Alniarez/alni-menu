-- AlniMenu/Plugins/Separator.lua
-- The separator widget.

if not (AlniMenu and AlniMenu.RegisterWidget) then
    return
end

AlniMenu.RegisterWidget("separator", {
    text = "Separator",
    height = 12,
    multiple = true,
    create = function(row)
        local line = row.lib:CreateSeparator(row, { color = { 0.8, 0.7, 0.4, 0.6 } })
        line:ClearAllPoints()
        line:SetPoint("LEFT", 12, 0)
        line:SetPoint("RIGHT", -12, 0)
    end,
    -- no label
    update = function() end,
})
