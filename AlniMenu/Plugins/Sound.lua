-- AlniMenu/Plugins/Sound.lua
-- The sound widget.

if not (AlniMenu and AlniMenu.RegisterWidget) then
    return
end

local SOUNDS = {
    { text = "Music", cvar = "Sound_EnableMusic" },
    { text = "Ambience", cvar = "Sound_EnableAmbience" },
    { text = "Effects", cvar = "Sound_EnableSFX" },
}

--- Shows whether `toggle`'s sound is on: white when on, grey when off
---@param toggle Button
local function ShowSound(toggle)
    local on = GetCVar(toggle.sound.cvar) == "1"
    toggle:GetFontString():SetTextColor(on and 1 or 0.5, on and 1 or 0.5, on and 1 or 0.5)
end

AlniMenu.RegisterWidget("sound", {
    text = "Sound",
    create = function(row)
        local width = (row:GetWidth() - 16) / #SOUNDS
        row.toggles = {}
        for i, sound in ipairs(SOUNDS) do
            local toggle = CreateFrame("Button", nil, row)
            toggle:SetSize(width, row:GetHeight())
            toggle:SetPoint("LEFT", 8 + (i - 1) * width, 0)
            toggle:SetNormalFontObject("GameFontNormal")
            toggle:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
            toggle:SetText(sound.text)
            toggle.sound = sound
            toggle:SetScript("OnClick", function(self)
                SetCVar(sound.cvar, GetCVar(sound.cvar) == "1" and "0" or "1")
                ShowSound(self)
                -- the tooltip says on or off, so show it again
                if GameTooltip:IsOwned(self) then
                    self:GetScript("OnEnter")(self)
                end
            end)
            row.lib:AddTooltip(toggle, function()
                return sound.text, GetCVar(sound.cvar) == "1" and "On. Click to turn it off." or "Off. Click to turn it on."
            end)
            row.toggles[i] = toggle
        end
        -- they may have changed in the game's settings
        row:SetScript("OnShow", function()
            for _, toggle in ipairs(row.toggles) do
                ShowSound(toggle)
            end
        end)
    end,
    -- the toggles are the row, no label
    update = function() end,
})
