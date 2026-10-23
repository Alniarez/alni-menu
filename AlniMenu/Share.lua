-- AlniMenu/Share.lua
-- Exporting a layout as text, and importing one. Imported custom buttons run macros: each is shown, and only the ticked
-- ones are added.

local ADDON_NAME, ns = ...

local E = C_EncodingUtil
local PREFIX = "AlniMenu1:"   -- format version 1
local MAX_TEXT = 20000
local MAX_CATEGORIES, MAX_ITEMS = 20, 100
-- macro commands that run code, change settings or press other buttons, with every name the game has for them
-- (translated ones too), added by Risky
local RISKY = { "/run", "/script", "/console", "/click", "/dump", "/tinspect" }
local RISKY_SLASH = { "SCRIPT", "CONSOLE", "CLICK", "DUMP", "TABLEINSPECT" }

--- Whether this client can export and import layouts
---@return boolean
function ns.CanShareLayouts()
    return E and E.SerializeCBOR and E.DeserializeCBOR and E.CompressString and E.EncodeBase64 and true or false
end

--- The current layout as text, called `name`
---@param name string?
---@return string
local function Export(name)
    local data = { name = name ~= "" and name or nil, layout = {}, buttons = {}, custom = {} }
    for _, category in ipairs(AlniMenuDB.layout) do
        local copy = { name = category.name, fixed = category.fixed, hidden = category.hidden, items = {}, gaps = {} }
        for _, key in ipairs(category.items) do
            table.insert(copy.items, key)
            copy.gaps[key] = category.gaps[key]
            data.buttons[key] = ns.IsEnabled(key)
            local entry = ns.ENTRIES[key]
            if entry and entry.custom then
                local custom = AlniMenuDB.custom[entry.custom]
                data.custom[key] = { text = custom.text, macro = custom.macro }
            end
        end
        table.insert(data.layout, copy)
    end
    return PREFIX .. E.EncodeBase64(E.CompressString(E.SerializeCBOR(data)))
end

--- `value` if it is a string, cut to `max`
---@param value any
---@param max integer
---@param allowEmpty boolean? an empty string is kept (else nil)
---@return string?
local function Text(value, max, allowEmpty)
    if type(value) ~= "string" then
        return nil
    end
    -- whole characters only, never half of a UTF-8 one
    local out, count = {}, 0
    for char in value:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        count = count + 1
        if count > max then
            break
        end
        out[count] = char
    end
    local text = table.concat(out)
    if strtrim(text) == "" and not allowEmpty then
        return nil
    end
    return text
end

--- A layout from imported data, with only known fields of the right types, or nil
---@param data any
---@return table?
local function Clean(data)
    if type(data) ~= "table" or type(data.layout) ~= "table" then
        return nil
    end
    local out = { name = Text(data.name, 32), layout = {}, buttons = {}, custom = {} }
    for i, category in ipairs(data.layout) do
        if i > MAX_CATEGORIES then
            break
        end
        if type(category) == "table" and type(category.items) == "table" then
            local gaps = type(category.gaps) == "table" and category.gaps or {}
            local copy = {
                name = Text(category.name, 32) or "Category", items = {}, gaps = {},
                fixed = category.fixed == true or nil, hidden = category.hidden == true or nil,
            }
            for j, key in ipairs(category.items) do
                if j > MAX_ITEMS then
                    break
                end
                if type(key) == "string" and #key <= 64 then
                    table.insert(copy.items, key)
                    copy.gaps[key] = gaps[key] == true or nil
                end
            end
            table.insert(out.layout, copy)
        end
    end
    if type(data.buttons) == "table" then
        for key, on in pairs(data.buttons) do
            if type(key) == "string" and type(on) == "boolean" then
                out.buttons[key] = on
            end
        end
    end
    -- only custom buttons the layout uses
    if type(data.custom) == "table" then
        for _, category in ipairs(out.layout) do
            for _, key in ipairs(category.items) do
                local custom = key:match("^custom%d+$") and data.custom[key]
                if type(custom) == "table" and not out.custom[key] then
                    local text, macro = Text(custom.text, 40), Text(custom.macro, 255, true)
                    if text and macro then
                        out.custom[key] = { text = text, macro = macro }
                    end
                end
            end
        end
    end
    if #out.layout == 0 then
        return nil
    end
    return out
end

--- The layout in an exported text, or nil if it isn't one
---@param text string
---@return table?
local function Decode(text)
    text = strtrim(text or "")
    if #text > MAX_TEXT or text:sub(1, #PREFIX) ~= PREFIX then
        return nil
    end
    local ok, data = pcall(function()
        return E.DeserializeCBOR(E.DecompressString(E.DecodeBase64(text:sub(#PREFIX + 1))))
    end)
    if ok then
        return Clean(data)
    end
end

--- Whether `macro` runs code, changes settings or presses other buttons
---@param macro string
---@return boolean
local function Risky(macro)
    local risky = {}
    for _, command in ipairs(RISKY) do
        risky[command] = true
    end
    for _, name in ipairs(RISKY_SLASH) do
        for i = 1, 20 do
            local command = _G["SLASH_" .. name .. i]
            if type(command) == "string" then
                risky[command:lower()] = true
            end
        end
    end
    for line in macro:lower():gmatch("[^\r\n]+") do
        local command = strtrim(line):match("^(/%S+)")
        if command and risky[command] then
            return true
        end
    end
    return false
end

--- A new custom button, not in the menu yet
---@param text string
---@param macro string
---@return string
local function NewCustom(text, macro)
    local id = AlniMenuDB.nextCustom
    AlniMenuDB.nextCustom = id + 1
    AlniMenuDB.custom[id] = { text = text, macro = macro }
    local key = ns.AddCustomEntry(id)
    AlniMenuDB.known[key] = true
    AlniMenuDB.buttons[key] = false
    ns.RefreshEntryButton(key)
    return key
end

--- Adds an imported layout to the saved layouts. Custom buttons in `keep` become new custom buttons; the others, and
--- any custom button the text doesn't include, are left out.
---@param layout table
---@param keep table
local function Apply(layout, keep)
    if InCombatLockdown() then
        print("|cff33ff99" .. ADDON_NAME .. ":|r not in combat.")
        return
    end
    local new = {}
    for key, custom in pairs(layout.custom) do
        if keep[key] then
            new[key] = NewCustom(custom.text, custom.macro)
        end
    end
    local buttons = {}
    for _, category in ipairs(layout.layout) do
        local items, gaps = {}, {}
        for _, key in ipairs(category.items) do
            -- never one of the player's own custom buttons that happens to have the same key
            local isCustom = key:match("^custom%d+$")
            local final = isCustom and new[key] or (not isCustom and key)
            if final then
                table.insert(items, final)
                gaps[final] = category.gaps[key]
                buttons[final] = layout.buttons[key]
            end
        end
        category.items, category.gaps = items, gaps
    end

    local name = layout.name or "Imported"
    local saved = { name = name, layout = layout.layout, buttons = buttons }
    local n = 1
    while ns.HasSavedLayout(saved.name) do
        n = n + 1
        saved.name = name .. " " .. n
    end
    ns.StoreLayout(saved)
    print("|cff33ff99" .. ADDON_NAME .. ":|r saved as \"" .. saved.name .. "\".")
end

-- Preview ------------------------------

local preview

--- The window that shows an imported layout before it is used
---@return Frame
local function Preview()
    if preview then
        return preview
    end
    local Lib = ns.Lib
    preview = Lib:CreateDialog({
        name   = "AlniMenuImportFrame",
        title  = "Import Layout",
        width  = 460,
        height = 400,
        theme  = AlniMenuDB.theme,
        strata = "FULLSCREEN_DIALOG",
    })
    preview.summary = Lib:CreateLabel(preview, { width = 412 })
    preview.summary:SetPoint("TOPLEFT", 24, -54)
    preview.warning = Lib:CreateLabel(preview, {
        width = 412,
        color = { 1, 0.5, 0.25 },
        text  = "This layout has custom buttons. They run macros: read each one, and tick only the ones you want.",
    })
    preview.warning:SetPoint("TOPLEFT", preview.summary, "BOTTOMLEFT", 0, -8)

    local _, list = Lib:CreateScrollFrame(preview, { x1 = 24, y1 = -112, x2 = -44, y2 = 56, contentWidth = 390 })
    preview.list = list
    preview.rows = {}

    preview.cancel = Lib:CreateButton(preview, {
        text = CANCEL or "Cancel", width = 100, onClick = function() preview:Hide() end,
    })
    preview.cancel:SetPoint("BOTTOMRIGHT", -24, 22)
    preview.add = Lib:CreateButton(preview, {
        text        = "Add Layout",
        width       = 100,
        tooltip     = "Add Layout",
        tooltipText = "Adds it to your saved layouts, to load from Layouts. Your menu stays as it is.",
        onClick     = function()
            preview:Hide()
            Apply(preview.layout, preview:Kept())
        end,
    })
    preview.add:SetPoint("RIGHT", preview.cancel, "LEFT", -8, 0)

    function preview:Kept()
        local keep = {}
        for _, row in ipairs(self.rows) do
            if row:IsShown() and row.check:GetChecked() then
                keep[row.key] = true
            end
        end
        return keep
    end

    table.insert(UISpecialFrames, "AlniMenuImportFrame")
    return preview
end

--- One custom button in the preview list: a checkbox with its label, a red tag if it is risky, and its macro
---@param i integer
---@return Frame
local function PreviewRow(i)
    local row = preview.rows[i]
    if row then
        return row
    end
    row = CreateFrame("Frame", nil, preview.list)
    row:SetWidth(390)
    row.check = ns.Lib:CreateCheckbox(row, {})
    row.check:SetPoint("TOPLEFT")
    row.risky = ns.Lib:CreateLabel(row, { text = "Runs code", color = { 1, 0.2, 0.2 }, font = "GameFontNormalSmall" })
    row.risky:SetPoint("LEFT", row.check.label, "RIGHT", 8, 0)
    row.macro = ns.Lib:CreateLabel(row, { width = 360, font = "GameFontHighlightSmall" })
    row.macro:SetPoint("TOPLEFT", row.check, "BOTTOMLEFT", 26, -2)
    preview.rows[i] = row
    return row
end

--- Shows imported `layout`, with its custom buttons to pick from
---@param layout table
local function ShowPreview(layout)
    local window = Preview()
    window.layout = layout
    window:SetTheme(AlniMenuDB.theme)

    local buttons = 0
    for _, category in ipairs(layout.layout) do
        buttons = buttons + #category.items
    end
    local what = layout.name and ('"' .. layout.name .. '"') or "This layout"
    window.summary:SetText(("%s has %d categories and %d buttons."):format(what, #layout.layout, buttons))

    local keys = {}
    for key in pairs(layout.custom) do
        table.insert(keys, key)
    end
    table.sort(keys)
    window.warning:SetShown(#keys > 0)

    local y = 0
    for i, key in ipairs(keys) do
        local custom = layout.custom[key]
        local row = PreviewRow(i)
        row.key = key
        row.check:SetChecked(false)
        -- shown as typed: no colours or icons from |c, |T...
        row.check.label:SetText((custom.text:gsub("|", "||")))
        row.risky:SetShown(Risky(custom.macro))
        row.macro:SetText((custom.macro:gsub("|", "||")))
        local height = 24 + row.macro:GetStringHeight() + 10
        row:SetHeight(height)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:Show()
        y = y + height
    end
    for i = #keys + 1, #window.rows do
        window.rows[i]:Hide()
    end
    window.list:SetHeight(math.max(y, 1))
    window:Show()
end

-- Text window ------------------------------

local textWindow

--- The window with the layout text: to copy for an export, to paste into for an import
---@return Frame
local function TextWindow()
    if textWindow then
        return textWindow
    end
    local Lib = ns.Lib
    textWindow = Lib:CreateDialog({
        name   = "AlniMenuShareFrame",
        title  = "Export Layout",
        width  = 460,
        height = 340,
        theme  = AlniMenuDB.theme,
        strata = "FULLSCREEN_DIALOG",
    })
    textWindow.hint = Lib:CreateLabel(textWindow, { width = 412 })
    textWindow.hint:SetPoint("TOPLEFT", 24, -54)
    -- export only: the text follows the name as it is typed
    textWindow.name = Lib:CreateEditBox(textWindow, {
        label         = "Name",
        width         = 220,
        maxLetters    = 32,
        onTextChanged = function(name)
            textWindow.edit:SetText(Export(strtrim(name)))
            textWindow.edit:HighlightText()
        end,
    })
    textWindow.name:SetPoint("TOPLEFT", 30, -92)

    -- a dark box behind the text, as in the custom button window
    local box = CreateFrame("Frame", nil, textWindow, "BackdropTemplate")
    box:SetPoint("BOTTOMRIGHT", -24, 58)
    textWindow.box = box
    box:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    box:SetBackdropColor(0, 0, 0, 0.6)
    box:SetBackdropBorderColor(0.5, 0.5, 0.5)
    local _, edit = Lib:CreateScrollFrame(box, {
        x1 = 8, y1 = -6, x2 = -26, y2 = 6, childType = "EditBox", contentWidth = 370, contentHeight = 1,
    })
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(370)
    edit:SetScript("OnEscapePressed", edit.ClearFocus)
    box:SetScript("OnMouseDown", function() edit:SetFocus() end)
    textWindow.edit = edit

    textWindow.close = Lib:CreateButton(textWindow, {
        text = CLOSE or "Close", width = 100, onClick = function() textWindow:Hide() end,
    })
    textWindow.close:SetPoint("BOTTOMRIGHT", -24, 22)
    textWindow.next = Lib:CreateButton(textWindow, {
        text    = "Next",
        width   = 100,
        onClick = function()
            local layout = Decode(edit:GetText())
            if not layout then
                textWindow.hint:SetText("|cffff3333That isn't an AlniMenu layout.|r Paste the whole text, then Next.")
                return
            end
            textWindow:Hide()
            ShowPreview(layout)
        end,
    })
    textWindow.next:SetPoint("RIGHT", textWindow.close, "LEFT", -8, 0)

    table.insert(UISpecialFrames, "AlniMenuShareFrame")
    return textWindow
end

--- Opens the text window with `title` and `hint`
---@param title string
---@param hint string
---@param text string
---@param import boolean
local function OpenText(title, hint, text, import)
    local window = TextWindow()
    window.titleText:SetText(title)
    window:SetTheme(AlniMenuDB.theme)
    window.hint:SetText(hint)
    window.edit:SetText(text)
    window.next:SetShown(import)
    window.name:SetShown(not import)
    window.name:SetText("")
    -- the text box goes up where there is no name box
    window.box:ClearAllPoints()
    window.box:SetPoint("TOPLEFT", 24, import and -80 or -122)
    window.box:SetPoint("BOTTOMRIGHT", -24, 58)
    window:Show()
    window.edit:SetFocus()
    window.edit:HighlightText()
end

--- Shows the current layout as text, ready to copy
function ns.ExportLayout()
    OpenText("Export Layout", "Name it if you like, then copy the text (Ctrl+C) and share it.", Export(), false)
end

--- Asks for a layout text to import
function ns.ImportLayout()
    OpenText("Import Layout", "Paste a layout here (Ctrl+V), then Next.", "", true)
end
