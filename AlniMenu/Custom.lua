-- AlniMenu/Custom.lua
-- The window for the player's own buttons (label, macro, category), and for renaming built-in ones.

local ADDON_NAME, ns = ...

local MAX_MACRO = 255   -- as long as a macro may be

-- premade buttons for the Template dropdown
local TEMPLATES = {
    { text = "Dismount",              macro = "/dismount" },
    { text = "Favorite Mount",        macro = "/run C_MountJournal.SummonByID(0)" },
    { text = "Ready Check",           macro = "/readycheck" },
    { text = "Roll",                  macro = "/roll" },
    { text = "Leave Group",           macro = "/run C_PartyInfo.LeaveParty()" },
    { text = "Toggle Sound",          macro = '/run SetCVar("Sound_EnableAllSound", GetCVar("Sound_EnableAllSound") == "1" and "0" or "1")' },
    { text = "Stopwatch",             macro = "/stopwatch" },
}

local window
local editingKey   -- the button being changed; nil for a new custom one
local renaming     -- true: renaming a built-in button
local newCategory  -- the category a new custom button goes in

local function Say(text)
    print("|cff33ff99" .. ADDON_NAME .. ":|r " .. text)
end

--- The categories as dropdown options, by index
---@return table
local function CategoryOptions()
    local options = {}
    for i, category in ipairs(AlniMenuDB.layout) do
        options[i] = { value = i, label = category.name }
    end
    return options
end

--- The index of the category holding `key`, or 0 when unused
---@param key string
---@return integer
local function CategoryOf(key)
    for i, category in ipairs(AlniMenuDB.layout) do
        for _, k in ipairs(category.items) do
            if k == key then
                return i
            end
        end
    end
    return 0
end

--- Moves `key` to the end of category `index` (0: unused)
---@param key string
---@param index integer
local function PutIn(key, index)
    if CategoryOf(key) == index then
        return
    end
    for _, category in ipairs(AlniMenuDB.layout) do
        for j = #category.items, 1, -1 do
            if category.items[j] == key then
                table.remove(category.items, j)
            end
        end
        category.gaps[key] = nil
    end
    local category = AlniMenuDB.layout[index]
    if category then
        table.insert(category.items, key)
    end
end

--- Renaming a built-in button. Its own label, or an empty box, undoes it.
local function SaveRename()
    local key = editingKey
    local text = strtrim(window.label:GetText())
    if text == "" or text == ns.ENTRIES[key].text then
        AlniMenuDB.labels[key] = nil
    else
        AlniMenuDB.labels[key] = text
    end
    ns.RefreshEntryButton(key)
    window:Hide()
    ns.ApplyLayout()
end

local function Save()
    if renaming then
        return SaveRename()
    end
    if InCombatLockdown() then
        Say("custom buttons can only be saved out of combat.")
        return
    end
    local text  = strtrim(window.label:GetText())
    local macro = window.macro:GetText()
    if text == "" then
        Say("give the button a label.")
        return
    end

    local key = editingKey
    if key then
        local id = ns.ENTRIES[key].custom
        AlniMenuDB.custom[id] = { text = text, macro = macro }
        ns.AddCustomEntry(id)
    else
        local id = AlniMenuDB.nextCustom
        AlniMenuDB.nextCustom = id + 1
        AlniMenuDB.custom[id] = { text = text, macro = macro }
        key = ns.AddCustomEntry(id)
        AlniMenuDB.buttons[key] = true
        AlniMenuDB.known[key] = true
    end
    -- without a category picker, new buttons go in the first category
    local index = window.category and window.category:GetValue()
    if index == nil then
        index = editingKey and CategoryOf(key) or newCategory or 1
    end
    -- unused buttons are off; out of Unused (or new), on
    local from = editingKey and CategoryOf(key) or 0
    PutIn(key, index)
    if index == 0 then
        AlniMenuDB.buttons[key] = false
    elseif from == 0 then
        AlniMenuDB.buttons[key] = true
    end

    ns.RefreshEntryButton(key)
    window:Hide()
    ns.ApplyLayout()
    ns.RefreshCustomList()
end

--- Deletes custom button `key`
---@param key string
function ns.DeleteCustomButton(key)
    local entry = ns.ENTRIES[key]
    if InCombatLockdown() or not (entry and entry.custom) then
        return
    end
    ns.RemoveEntry(key)
    AlniMenuDB.custom[entry.custom] = nil
    AlniMenuDB.buttons[key] = nil
    if window and editingKey == key then
        window:Hide()
    end
    ns.ApplyLayout()
    ns.RefreshCustomList()
end

local function Delete()
    if editingKey then
        ns.DeleteCustomButton(editingKey)
    end
end

local function BuildWindow()
    local Lib = ns.Lib
    window = Lib:CreateDialog({
        name   = "AlniMenuCustomFrame",
        title  = "Custom Button",
        width  = 400,
        height = 330,
        theme  = AlniMenuDB.theme,
        strata = "FULLSCREEN_DIALOG",   -- over the menu
    })

    window.label = Lib:CreateEditBox(window, { label = "Label", width = 220, maxLetters = 40 })
    window.label:SetPoint("TOPLEFT", 30, -58)

    if Lib:HasDropdown() then
        window.category = Lib:CreateDropdown(window, { label = "Category", width = 120 })
        window.category:SetPoint("TOPLEFT", 266, -54)
    end

    local macroLabel = window:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    macroLabel:SetPoint("TOPLEFT", 26, -92)
    macroLabel:SetText("Macro (up to " .. MAX_MACRO .. " characters)")

    -- a dark box behind the macro text
    local box = CreateFrame("Frame", nil, window, "BackdropTemplate")
    box:SetPoint("TOPLEFT", 24, -108)
    box:SetPoint("BOTTOMRIGHT", -24, 58)
    box:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    box:SetBackdropColor(0, 0, 0, 0.6)
    box:SetBackdropBorderColor(0.5, 0.5, 0.5)

    local _, macro = Lib:CreateScrollFrame(box, {
        x1 = 8, y1 = -6, x2 = -26, y2 = 6,
        childType     = "EditBox",
        contentWidth  = 310,
        contentHeight = 1,
    })
    macro:SetMultiLine(true)
    macro:SetAutoFocus(false)
    macro:SetFontObject(ChatFontNormal)
    macro:SetMaxLetters(MAX_MACRO)
    macro:SetWidth(310)
    macro:SetScript("OnEscapePressed", macro.ClearFocus)
    window.macro = macro
    -- a click anywhere in the box starts typing
    box:SetScript("OnMouseDown", function() macro:SetFocus() end)

    window.save = Lib:CreateButton(window, { text = SAVE or "Save", width = 100, onClick = Save })
    window.save:SetPoint("BOTTOMRIGHT", -24, 22)
    window.cancel = Lib:CreateButton(window, {
        text = CANCEL or "Cancel", width = 100, onClick = function() window:Hide() end,
    })
    window.cancel:SetPoint("RIGHT", window.save, "LEFT", -8, 0)
    window.delete = Lib:CreateButton(window, { text = DELETE or "Delete", width = 100, onClick = Delete })
    window.delete:SetPoint("BOTTOMLEFT", 24, 22)
    window.reset = Lib:CreateButton(window, {
        text        = RESET or "Reset",
        width       = 100,
        onClick     = function() window.label:SetText(ns.ENTRIES[editingKey].text) end,
        tooltip     = "Reset",
        tooltipText = "Back to the button's own label. Save to keep it.",
    })
    window.reset:SetPoint("BOTTOMLEFT", 24, 22)

    -- new buttons only, where Delete goes for existing ones
    if Lib:HasDropdown() then
        local options = {}
        for i, t in ipairs(TEMPLATES) do
            options[i] = { value = i, label = t.text }
        end
        window.template = Lib:CreateDropdown(window, {
            width       = 136,   -- 8 short of Cancel, like Cancel and Save
            options     = options,
            placeholder = "Template...",
            onChange    = function(i)
                window.label:SetText(TEMPLATES[i].text)
                window.macro:SetText(TEMPLATES[i].macro)
            end,
        })
        window.template:SetPoint("BOTTOMLEFT", 24, 24)
    end

    -- everything only a custom button has, hidden while renaming
    window.customOnly = { macroLabel, box, window.category }

    table.insert(UISpecialFrames, "AlniMenuCustomFrame")
end

--- Lays the window out for a custom button, or smaller for a rename
---@param rename boolean
local function SetMode(rename)
    renaming = rename
    for _, region in pairs(window.customOnly) do
        region:SetShown(not rename)
    end
    window.reset:SetShown(rename)
    window:SetHeight(rename and 160 or 330)
    -- the title refits when the theme is applied
    window.titleText:SetText(rename and "Rename Button" or "Custom Button")
    window:SetTheme(AlniMenuDB.theme)
end

function ns.HideCustomWindow()
    if window then
        window:Hide()
    end
end

--- Opens the window to rename built-in button `key`
---@param key string
function ns.RenameButton(key)
    if InCombatLockdown() then
        return
    end
    if not window then
        BuildWindow()
    end
    editingKey = key
    SetMode(true)
    window.label:SetText(ns.Label(key))
    window.delete:Hide()
    if window.template then
        window.template:Hide()
    end
    window:Show()
    window.label:SetFocus()
    window.label:HighlightText()
end

--- Opens the window for custom button `key`, or for a new one (nil)
---@param key string?
---@param category integer? where a new one goes (default: the first category)
function ns.EditCustomButton(key, category)
    if InCombatLockdown() then
        return
    end
    if not window then
        BuildWindow()
    end
    editingKey = key
    newCategory = category
    SetMode(false)

    local data = key and AlniMenuDB.custom[ns.ENTRIES[key].custom]
    window.label:SetText(data and data.text or "")
    window.macro:SetText(data and data.macro or "")
    if window.category then
        window.category:SetOptions(CategoryOptions())
        -- empty for a button not in the menu: saving keeps it out unless a category is picked
        local current = key and CategoryOf(key)
        window.category:SetValue(current ~= 0 and current or (not key and (category or 1)) or nil)
    end
    window.delete:SetShown(key ~= nil)
    if window.template then
        window.template:SetValue(nil)
        window.template:SetShown(key == nil)
    end

    window:Show()
    window.label:SetFocus()
end

-- The list of custom buttons ------------------------------

local list

StaticPopupDialogs.ALNIMENU_DELETE_CUSTOM = {
    text         = "Delete the custom button %s?",
    button1      = DELETE or "Delete",
    button2      = CANCEL or "Cancel",
    OnAccept     = function(_, key) ns.DeleteCustomButton(key) end,
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
}

--- One row of the list: label, where it is, its macro, and Edit and Delete
---@param i integer
---@return Frame
local function ListRow(i)
    local row = list.rows[i]
    if row then
        return row
    end
    local Lib = ns.Lib
    row = CreateFrame("Frame", nil, list.content)
    row:SetWidth(390)
    row.label = Lib:CreateLabel(row, { font = "GameFontNormal", width = 250, wordWrap = false })
    row.label:SetPoint("TOPLEFT")
    row.where = Lib:CreateLabel(row, { font = "GameFontDisableSmall", width = 250, wordWrap = false })
    row.where:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -2)
    row.macro = Lib:CreateLabel(row, { font = "GameFontHighlightSmall", width = 380 })
    row.macro:SetPoint("TOPLEFT", row.where, "BOTTOMLEFT", 0, -4)
    row.delete = Lib:CreateButton(row, {
        text = DELETE or "Delete", width = 64, height = 20,
        onClick = function() StaticPopup_Show("ALNIMENU_DELETE_CUSTOM", ns.Label(row.key), nil, row.key) end,
    })
    row.delete:SetPoint("TOPRIGHT")
    row.edit = Lib:CreateButton(row, {
        text = EDIT or "Edit", width = 64, height = 20,
        onClick = function() ns.EditCustomButton(row.key) end,
    })
    row.edit:SetPoint("RIGHT", row.delete, "LEFT", -4, 0)
    list.rows[i] = row
    return row
end

--- Fills the list with every custom button, if it is open
function ns.RefreshCustomList()
    if not (list and list:IsShown()) then
        return
    end
    local keys = {}
    for key, entry in pairs(ns.ENTRIES) do
        if entry.custom then
            table.insert(keys, key)
        end
    end
    table.sort(keys, function(a, b) return ns.Label(a) < ns.Label(b) end)
    list.empty:SetShown(#keys == 0)

    local y = 0
    for i, key in ipairs(keys) do
        local row = ListRow(i)
        local index = CategoryOf(key)
        row.key = key
        row.label:SetText(ns.Label(key))
        row.where:SetText(index > 0 and AlniMenuDB.layout[index].name or "Not in the menu")
        row.macro:SetText(AlniMenuDB.custom[ns.ENTRIES[key].custom].macro)
        local height = row.label:GetStringHeight() + row.where:GetStringHeight() + row.macro:GetStringHeight() + 18
        row:SetHeight(height)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:Show()
        y = y + height
    end
    for i = #keys + 1, #list.rows do
        list.rows[i]:Hide()
    end
    list.content:SetHeight(math.max(y, 1))
end

--- Opens the list of custom buttons (from the settings page)
function ns.ShowCustomList()
    if not list then
        local Lib = ns.Lib
        list = Lib:CreateDialog({
            name   = "AlniMenuCustomListFrame",
            title  = "Custom Buttons",
            width  = 460,
            height = 400,
            theme  = AlniMenuDB.theme,
            strata = "FULLSCREEN_DIALOG",
        })
        local _, content = Lib:CreateScrollFrame(list, { x1 = 24, y1 = -54, x2 = -44, y2 = 56, contentWidth = 390 })
        list.content = content
        list.rows = {}
        list.empty = Lib:CreateLabel(list, {
            text = "No custom buttons yet.", width = 412, justify = "CENTER",
        })
        list.empty:SetPoint("TOP", 0, -80)
        list.new = Lib:CreateButton(list, {
            text = "New Button", width = 120, onClick = function() ns.EditCustomButton(nil) end,
        })
        list.new:SetPoint("BOTTOMLEFT", 24, 22)
        table.insert(UISpecialFrames, "AlniMenuCustomListFrame")
    end
    list:SetTheme(AlniMenuDB.theme)
    list:Show()
    ns.RefreshCustomList()
end
