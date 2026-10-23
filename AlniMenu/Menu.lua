-- AlniMenu/Menu.lua
local ADDON_NAME, ns = ...

--------------------------------------------------
-- Layout
--------------------------------------------------

-- the Game Menu's own sizes (MainMenuFrameTemplate)
local BUTTON_W, BUTTON_H = 200, 36
local COLUMN_GAP         = 8    -- between columns
local SECTION_GAP        = 12   -- between sections
local HEADING_H          = 20   -- the category names over the columns
local TOP, BOTTOM        = 40, 26
local RELEASE            = "Beta"   -- shown after the version in the menu's corner; "" for none
local SIDE               = 20
local EDIT_W             = 260  -- columns in edit mode, room for the controls
local MIN_UNUSED_ROWS    = 8    -- Unused wraps into more columns past this or the tallest category

-- Blizzard's big red Game Menu button
local BUTTON_TEMPLATE = "MainMenuFrameButtonTemplate"

--- Blizzard's translated label `key`, or `fallback` where it has none
---@param key string
---@param fallback string
---@return string
local function L(key, fallback)
    local text = _G[key]
    return type(text) == "string" and text or fallback
end

--------------------------------------------------
-- Buttons
--
-- ENTRIES[key]:
--   text     label
--   default  on by default
--   always   can't be switched off
--   action   function returning how it works on this client, or nil:
--              { click = frame }   secure click on a Blizzard button
--              { macro = "/cmd" }  secure slash command
--              { func = fn }       fn() after the menu closes
--   shown    optional: whether it applies right now
--   badge    optional: "new" or "alert" (and why), like the Game Menu's marks
--------------------------------------------------

--- A Blizzard button to click, if this client has it
---@param name string
---@return function
local function Click(name)
    return function()
        local frame = _G[name]
        if frame then
            return { click = frame }
        end
    end
end

--- A function to call, if the global `name` exists (always, with no name)
---@param name string?
---@param fn function
---@return function
local function Func(name, fn)
    return function()
        if name == nil or _G[name] ~= nil then
            return { func = fn }
        end
    end
end

local function Macro(command)
    return function() return { macro = command } end
end

local function OpenSettings()
    SettingsPanel:Open()
end

--- Blizzard's own menu, for anything AlniMenu doesn't offer
local function ShowBlizzardMenu()
    ns.allowBlizzardMenu = true   -- AlniMenu steps aside this once
    if GameMenuFrame_Show then
        GameMenuFrame_Show()
    else
        ShowUIPanel(GameMenuFrame)
    end
end

--- Profession in slot `slot` of GetProfessions() (1, 2: main ones, 5: Cooking): its name and the spell that opens it.
--- Nil when there is none.
---@param slot integer
---@return function
local function Profession(slot)
    return function()
        if not (GetProfessions and C_SpellBook and C_SpellBook.GetSpellBookItemInfo) then
            return nil
        end
        local index = select(slot, GetProfessions())
        if not index then
            return nil
        end
        local name, _, _, _, _, offset = GetProfessionInfo(index)
        local info = C_SpellBook.GetSpellBookItemInfo(offset + 1, Enum.SpellBookSpellBank.Player)
        if not (info and info.spellID) then
            return nil
        end
        return name, info.spellID
    end
end

--------------------------------------------------
-- Alerts: why the micro menu highlights a window, worked out like Blizzard does. Each returns the message or nil. Not
-- read off the micro buttons: those are disabled while the Game Menu is open.
--------------------------------------------------

local Alerts = {}

--- Talents, in the micro menu's order of importance
---@return string?
function Alerts.Talents()
    if IsPlayerInitialSpec and IsPlayerInitialSpec() and (GetNumSpecializations() or 0) > 0 then
        return L("NPEV2_SPEC_TUTORIAL_GOSSIP_CLOSED", "Choose a specialization.")
    end
    local talents = C_ClassTalents
    if talents and (talents.HasUnspentTalentPoints()
        or (talents.HasUnspentHeroTalentPoints and talents.HasUnspentHeroTalentPoints())) then
        return L("TALENT_MICRO_BUTTON_UNSPENT_TALENTS", "You have unspent talent points.")
    end
    -- PvP talents only matter with War Mode on or in a battleground
    local pvp = C_PvP and (C_PvP.IsWarModeDesired() or (PVPUtil and PVPUtil.IsInActiveBattlefield()))
    if pvp and C_SpecializationInfo and C_SpecializationInfo.GetPvpTalentAlertStatus then
        local emptySlot, newTalent = C_SpecializationInfo.GetPvpTalentAlertStatus()
        if emptySlot then
            return L("TALENT_MICRO_BUTTON_UNSPENT_PVP_TALENT_SLOT", "You have an empty PvP talent slot.")
        elseif newTalent then
            return L("TALENT_MICRO_BUTTON_NEW_PVP_TALENT", "You have a new PvP talent.")
        end
    end
end

--- A profession specialization to choose; `name` limits it to one profession
---@param name string?
---@return string?
function Alerts.NewSpecialization(name)
    local profName = C_ProfSpecs and C_ProfSpecs.GetNewSpecReminderProfName and C_ProfSpecs.GetNewSpecReminderProfName()
    if profName and (not name or name == profName) then
        local text = PROFESSIONS_NEW_CHOICE_AVAILABLE_SPECIALIZATION
        return text and text:format(profName) or ("A new " .. profName .. " specialization is available.")
    end
end

function Alerts.Professions()
    local newSpec = Alerts.NewSpecialization()
    if newSpec then
        return newSpec
    end
    if C_ProfSpecs and C_ProfSpecs.ShouldShowPointsReminder and C_ProfSpecs.ShouldShowPointsReminder() then
        return L("PROFESSIONS_UNSPENT_SPEC_POINTS_REMINDER", "You have unspent profession specialization points.")
    end
end

function Alerts.Mounts()
    local journal = C_MountJournal
    local count = journal and journal.GetNumMountsNeedingFanfare and journal.GetNumMountsNeedingFanfare() or 0
    if count > 0 then
        return count > 1 and L("COLLECTION_UNOPENED_PLURAL", "You have new mounts to open.")
            or L("COLLECTION_UNOPENED_SINGULAR", "You have a new mount to open.")
    end
end

--- As the Guild & Communities micro button's dot
---@return string?
function Alerts.Guild()
    if not (C_Club and C_Club.IsEnabled() and C_SocialRestrictions and C_SocialRestrictions.CanReceiveChat()) then
        return nil
    end
    local unseen = false
    for _, invitation in ipairs(C_Club.GetInvitationsForSelf() or {}) do
        if not (DISPLAYED_COMMUNITIES_INVITATIONS and DISPLAYED_COMMUNITIES_INVITATIONS[invitation.club.clubId]) then
            unseen = true
        end
    end
    if unseen then
        return "You have new community invitations."
    end
    if CommunitiesUtil and CommunitiesUtil.DoesAnyCommunityHaveUnreadMessages() then
        return "You have unread community messages."
    end
end

--- As the Adventure Guide micro button's dot: tabs not looked at yet
---@return string?
function Alerts.AdventureGuide()
    local tabsSeen = Enum.FrameTutorialAccount and Enum.FrameTutorialAccount.EnconterJournalTutorialsTabSeen
    local unseen = tabsSeen and not GetCVarBitfield("closedInfoFramesAccountWide", tabsSeen)
    local journeys = LE_FRAME_TUTORIAL_JOURNEYS_TAB and not GetCVarBitfield("closedInfoFrames", LE_FRAME_TUTORIAL_JOURNEYS_TAB)
    if unseen or journeys then
        return "There is something new to see in the Adventure Guide."
    end
end

--- An open support ticket that needs the player, in Blizzard's words
---@return string?
function Alerts.Ticket()
    if TicketStatusFrame and TicketStatusFrame:IsShown() then
        local text = TicketStatusTitleText and TicketStatusTitleText:GetText()
        return (text and text ~= "") and text or "Your support ticket needs your attention."
    end
end

--- As the Shop micro button's dot
---@return string?
function Alerts.Shop()
    if C_CatalogShop and C_CatalogShop.HasNewProducts and C_CatalogShop.HasNewProducts() then
        return "There are new products in the Shop."
    end
end

--- A badge function showing the alert `check` finds
---@param check function
---@param ... any
---@return function
local function AlertBadge(check, ...)
    local args = { ... }
    return function()
        local ok, text = pcall(check, unpack(args))
        if ok and text then
            return "alert", text
        end
    end
end

--- A secure button casting a profession's spell
---@param slot integer
---@param fallback string
---@return table
local function ProfessionEntry(slot, fallback)
    local profession = Profession(slot)
    return {
        text       = fallback,
        profession = profession,
        default    = true,
        action     = function() return { spell = true } end,
        shown      = function() return profession() ~= nil end,
        -- a new specialization to choose in this profession
        badge      = function()
            local name = profession()
            local text = name and Alerts.NewSpecialization(name)
            if text then
                return "alert", text
            end
        end,
    }
end

--- Opens the Adventure Guide on its Traveler's Log tab
local function OpenTravelersLog()
    if not EncounterJournal and EncounterJournal_LoadUI then
        EncounterJournal_LoadUI()
    end
    if not (EncounterJournal and EncounterJournal.MonthlyActivitiesTab) then
        return
    end
    if not EncounterJournal:IsShown() then
        ToggleEncounterJournal()
    end
    EJ_ContentTab_Select(EncounterJournal.MonthlyActivitiesTab:GetID())
end

local function CollectionsTab(index)
    return Func("ToggleCollectionsJournal", function() ToggleCollectionsJournal(index) end)
end

local ENTRIES = {
    -- windows (the micro menu, and the tabs inside it)
    character    = { text = L("CHARACTER_BUTTON", "Character Info"), action = Click("CharacterMicroButton") },
    reputation   = { text = L("REPUTATION", "Reputation"),
                     action = Func("ToggleCharacter", function() ToggleCharacter("ReputationFrame") end) },
    currency     = { text = L("CURRENCY", "Currency"),
                     action = Func("ToggleCharacter", function() ToggleCharacter("TokenFrame") end) },
    professions  = { text = L("PROFESSIONS_BUTTON", "Professions"), action = Click("ProfessionMicroButton"),
                     badge  = AlertBadge(Alerts.Professions) },
    -- each named after the profession learned there, hidden when none
    profession1  = ProfessionEntry(1, "First Profession"),
    profession2  = ProfessionEntry(2, "Second Profession"),
    cooking      = ProfessionEntry(5, "Cooking"),
    -- Forever has a micro button for each, Retail one for both (so Blizzard's function)
    spellbook    = { text = L("SPELLBOOK", "Spellbook"),
                     action = function()
                         return Click("SpellbookMicroButton")()
                             or { func = function() PlayerSpellsUtil.ToggleSpellBookFrame() end }
                     end },
    talents      = { text = L("TALENTS", "Talents"),
                     action = function()
                         return Click("TalentMicroButton")()
                             or { func = function() PlayerSpellsUtil.ToggleClassTalentOrSpecFrame() end }
                     end,
                     badge  = AlertBadge(Alerts.Talents) },
    achievements = { text = L("ACHIEVEMENT_BUTTON", "Achievements"), action = Click("AchievementMicroButton") },
    questlog     = { text = "Quest Log & Map", action = Click("QuestLogMicroButton") },
    calendar     = { text = "Calendar", action = Click("GameTimeFrame") },
    housing      = { text = "Housing Dashboard", action = Click("HousingMicroButton") },
    guild        = { text = L("GUILD_AND_COMMUNITIES", "Guild & Communities"), action = Click("GuildMicroButton"),
                     badge  = AlertBadge(Alerts.Guild) },
    groupfinder  = { text = L("GROUP_FINDER", "Group Finder"), action = Click("LFDMicroButton") },
    pvp          = { text = L("PLAYER_V_PLAYER", "Player vs. Player"),
                     action = Func("TogglePVPUI", function() TogglePVPUI() end) },
    mounts       = { text = L("MOUNTS", "Mounts"), action = CollectionsTab(COLLECTIONS_JOURNAL_TAB_INDEX_MOUNTS or 1),
                     badge  = AlertBadge(Alerts.Mounts) },
    appearances  = { text = "Appearances", action = CollectionsTab(COLLECTIONS_JOURNAL_TAB_INDEX_APPEARANCES or 5) },
    adventure    = { text = L("ADVENTURE_JOURNAL", "Adventure Guide"), action = Click("EJMicroButton"),
                     badge  = AlertBadge(Alerts.AdventureGuide) },
    travelerslog = { text = L("MONTHLY_ACTIVITIES_TAB", "Traveler's Log"),
                     action = Func("ToggleEncounterJournal", OpenTravelersLog),
                     shown  = function()
                         return C_PlayerInfo and C_PlayerInfo.IsTravelersLogAvailable
                             and C_PlayerInfo.IsTravelersLogAvailable()
                     end },

    -- the Game Menu's own
    options  = { text = L("GAMEMENU_OPTIONS", "Options"), default = true, action = Func(nil, OpenSettings),
                 badgeKind = "new",
                 badge  = function()
                     return CurrentVersionHasNewUnseenSettings() and "new"
                 end },
    shop     = { text = L("BLIZZARD_STORE", "Shop"), default = true,
                 action = Func("ToggleStoreUI", function() ToggleStoreUI() end),
                 shown  = function() return C_StorePublic and C_StorePublic.IsEnabled and C_StorePublic.IsEnabled() end,
                 badge  = AlertBadge(Alerts.Shop) },
    addons   = { text = L("ADDONS", "AddOns"), default = true,
                 action = Func("AddonList", function() ShowUIPanel(AddonList) end) },
    editmode = { text = L("HUD_EDIT_MODE_MENU", "Edit Mode"), default = true, action = Macro("/editmode"),
                 shown  = function() return EditModeManagerFrame and EditModeManagerFrame:CanEnterEditMode() end,
                 badge  = function()
                     local tutorial = EditModeManagerFrame and EditModeManagerFrame.Tutorial
                     return tutorial and tutorial:HasHelptipsToShow() and "alert"
                 end },
    support  = { text = L("GAMEMENU_SUPPORT", "Support"), default = true,
                 action = Func("ToggleHelpFrame", function() ToggleHelpFrame() end),
                 badge  = AlertBadge(Alerts.Ticket) },
    macros   = { text = L("MACROS", "Macros"), default = true, action = Macro("/macro") },
    reload   = { text = "Reload UI", default = true, action = Macro("/reload") },
    logout   = { text = L("LOG_OUT", "Log Out"), default = true, action = Macro("/logout") },
    exit     = { text = L("EXIT_GAME", "Exit Game"), default = true, action = Macro("/quit") },
    blizzard = { text = "Blizzard Menu", default = true, action = Func(nil, ShowBlizzardMenu) },
    -- optional: without it the menu shows a close X by the gear
    close    = { text = L("RETURN_TO_GAME", "Return to Game"), default = true, action = Func(nil, function() end) },
}

--------------------------------------------------
-- Widgets
--
-- Rows that aren't buttons, from AlniMenu.RegisterWidget (the Plugins folder or other addons). Never in Unused. A
-- `multiple` widget can be added many times, each one is "<key><id>" in AlniMenuDB.instances.
--------------------------------------------------

---@class AlniMenuWidget
---@field text string label, also in the + lists (default: the key)
---@field create? fun(row: AlniMenuWidgetRow) builds the widget in its row
---@field update? fun(row: AlniMenuWidgetRow) shows `row.name` (renamed or not) in `row.label`; default: the name alone
---@field height? number row height outside edit mode (default: a button's)
---@field multiple? boolean can be added any number of times, like separators
---@field shown? fun(): boolean whether it shows right now, like buttons that only apply sometimes (default: always)

---@class AlniMenuWidgetRow: Frame
---@field label FontString centered in the row
---@field name string the widget's label, as the player named it
---@field lib table AlniMenu's copy of AlnUI, for building the widget
---@field settings table saved for this widget across sessions, for its own options

local WIDGETS = {}       -- registered widget keys, in the order the + lists them
local WIDGET_DEFS = {}   -- key -> AlniMenuWidget

--- The catalog entry for widget `key`, or for its instance `id`
---@param key string
---@param def AlniMenuWidget
---@param id integer?
---@return string
local function WidgetEntry(key, def, id)
    local entryKey = id and (key .. id) or key
    ENTRIES[entryKey] = ENTRIES[entryKey] or {
        key = entryKey, widget = def, instance = id, text = def.text, rowHeight = def.height, shown = def.shown,
        action = function() return { widget = def } end,
    }
    return entryKey
end

--- A new instance of `multiple` widget `key`, saved in AlniMenuDB.instances
---@param key string
---@return string
local function NewInstance(key)
    local id = AlniMenuDB.nextInstance
    AlniMenuDB.nextInstance = id + 1
    AlniMenuDB.instances[key .. id] = key
    return WidgetEntry(key, WIDGET_DEFS[key], id)
end

--- Catalog entries for the saved instances of registered widgets
function ns.LoadInstances()
    for entryKey, key in pairs(AlniMenuDB.instances) do
        local def = WIDGET_DEFS[key]
        local id = def and tonumber(entryKey:sub(#key + 1))
        if id then
            WidgetEntry(key, def, id)
        end
    end
end

--- The `multiple` widget an instance key like "separator3" belongs to, if any
---@param entryKey string
---@return string?
local function InstanceOf(entryKey)
    for _, key in ipairs(WIDGETS) do
        if WIDGET_DEFS[key].multiple and entryKey:match("^" .. key:gsub("%p", "%%%0") .. "%d+$") then
            return key
        end
    end
end

AlniMenu = AlniMenu or {}

--- Closes the menu, for widgets that open another window. False if it was not open, or in combat.
---@return boolean
function AlniMenu.HideMenu()
    return ns.HideMenu()
end

--- Adds a widget to the + lists in edit mode. Call it before PLAYER_LOGIN, with `## Dependencies: AlniMenu` in your TOC
--- (`## OptionalDeps: AlniMenu` if your addon does more than this). Use a key unique to your addon. See the Plugins
--- folder.
---@param key string
---@param def AlniMenuWidget
function AlniMenu.RegisterWidget(key, def)
    assert(type(key) == "string" and type(def) == "table", "usage: AlniMenu.RegisterWidget(key, def)")
    if WIDGET_DEFS[key] then
        return
    end
    def.text = def.text or key
    WIDGET_DEFS[key] = def
    table.insert(WIDGETS, key)
    if not def.multiple then
        WidgetEntry(key, def)
    end
    -- registered late
    if ns.ready then
        ns.LoadInstances()
        for entryKey, entry in pairs(ENTRIES) do
            if entry.widget == def then
                ns.RefreshEntryButton(entryKey)
            end
        end
    end
end

--------------------------------------------------
-- Layout
--
-- AlniMenuDB.layout: categories, left to right, one column each:
--   name   heading
--   items  button keys, top to bottom
--   gaps   { [key] = true } for a gap above that button
-- Buttons in no category are unused.
--------------------------------------------------

local DEFAULT_LAYOUT = {
    { name = "Character",
      items = { "character", "spellbook", "talents",
                "professions", "profession1", "profession2", "achievements" },
      gaps  = { professions = true } },
    { name = "Game Menu", fixed = true,
      items = { "options", "shop", "addons", "editmode", "support", "macros", "reload",
                "logout", "exit", "blizzard", "close" },
      gaps  = { addons = true, logout = true, blizzard = true },
      off   = { shop = true, reload = true, close = true } },
    { name = "Social",    items = { "guild", "groupfinder", "pvp" } },
    { name = "Adventure",
      items = { "questlog", "adventure", "calendar", "housing", "mounts", "appearances" },
      gaps  = { housing = true } },
}

-- The game's own Game Menu. New installs start with it
local ORIGINAL_LAYOUT = {
    { name = "Game Menu", fixed = true,
      items = { "options", "shop", "addons", "editmode", "support", "macros",
                "logout", "exit", "close" },
      gaps  = { addons = true, logout = true, close = true } },
}

-- Game Menu basics, the player's windows, a separator, volume and latency
local COMPACT_LAYOUT = {
    { name = "Game Menu", fixed = true,
      items = { "options", "addons", "editmode", "macros", "logout", "exit" },
      gaps  = { addons = true, logout = true } },
    { name = "Player",
      items = { "character", "travelerslog", "talents", "profession1", "profession2", "separator", "volume", "latency" },
      gaps  = { profession1 = true } },
}

local LAYOUTS = { default = DEFAULT_LAYOUT, original = ORIGINAL_LAYOUT, compact = COMPACT_LAYOUT }

-- the Layouts list shows them in this order
local LAYOUT_ORDER = {
    { name = "default", label = "Default" },
    { name = "original", label = "Original" },
    { name = "compact", label = "Compact" },
}

-- The Game Menu category: always shown, never renamed or deleted
local GAME_MENU_NAME = L("MAINMENU_BUTTON", "Game Menu")

--- A fresh copy of `template` (default: DEFAULT_LAYOUT)
---@param template table?
---@return table
function ns.DefaultLayout(template)
    local layout = {}
    for i, category in ipairs(template or DEFAULT_LAYOUT) do
        local gaps = {}
        for key in pairs(category.gaps or {}) do
            gaps[key] = true
        end
        layout[i] = { name = category.fixed and GAME_MENU_NAME or category.name, fixed = category.fixed,
                      items = { unpack(category.items) }, gaps = gaps }
    end
    return layout
end

--- Switches on the buttons in `template` except its `off` ones, the rest off. Custom buttons keep theirs.
---@param template table
local function SetButtonsFrom(template)
    local on = {}
    for _, category in ipairs(template) do
        for _, key in ipairs(category.items) do
            on[key] = not (category.off and category.off[key])
        end
    end
    for key, entry in pairs(ENTRIES) do
        if not entry.always and not entry.custom then
            AlniMenuDB.buttons[key] = on[key] or false
        end
    end
end

--- The Game Menu category of the saved layout
---@return table
local function GameMenuCategory()
    for _, category in ipairs(AlniMenuDB.layout) do
        if category.fixed then
            return category
        end
    end
    return AlniMenuDB.layout[1]
end

--- Whether `layout` has `key` in any category
---@param layout table
---@param key string
---@return boolean
local function InLayout(layout, key)
    for _, category in ipairs(layout) do
        for _, k in ipairs(category.items) do
            if k == key then
                return true
            end
        end
    end
    return false
end

--- Puts `key`, new to this layout, where DEFAULT_LAYOUT has it: same category, after the same button. Else unused.
---@param layout table
---@param key string
local function PlaceNewButton(layout, key)
    for _, default in ipairs(DEFAULT_LAYOUT) do
        for j, k in ipairs(default.items) do
            if k == key then
                for _, category in ipairs(layout) do
                    if (default.fixed and category.fixed) or category.name == default.name then
                        local at = #category.items + 1
                        local before = default.items[j - 1]
                        for n, existing in ipairs(category.items) do
                            if existing == before then
                                at = n + 1
                            end
                        end
                        table.insert(category.items, at, key)
                        return
                    end
                end
                return
            end
        end
    end
end

--- Repairs AlniMenuDB.layout: makes one if missing, drops unknown and repeated keys, places new buttons
--- (AlniMenuDB.known lists the ones seen) and fixes the Game Menu category.
function ns.CheckLayout()
    local layout = AlniMenuDB.layout
    -- damaged saved data: drop anything that isn't a category
    if type(layout) == "table" then
        for i = #layout, 1, -1 do
            if type(layout[i]) ~= "table" then
                table.remove(layout, i)
            end
        end
    end
    if type(layout) ~= "table" or #layout == 0 then
        AlniMenuDB.layout = ns.DefaultLayout(ORIGINAL_LAYOUT)
        SetButtonsFrom(ORIGINAL_LAYOUT)
        AlniMenuDB.known = {}
        for key in pairs(ENTRIES) do
            AlniMenuDB.known[key] = true
        end
        return
    end

    local placed = {}
    for _, category in ipairs(layout) do
        category.name   = tostring(category.name or "")
        category.gaps   = type(category.gaps) == "table" and category.gaps or {}
        category.hidden = category.hidden == true or nil
        local items = {}
        for _, key in ipairs(type(category.items) == "table" and category.items or {}) do
            if ENTRIES[key] and not placed[key] then
                placed[key] = true
                table.insert(items, key)
            end
        end
        category.items = items
    end

    -- old layouts: everything in them is known
    if type(AlniMenuDB.known) ~= "table" then
        AlniMenuDB.known = {}
        for key in pairs(placed) do
            AlniMenuDB.known[key] = true
        end
    end
    -- DEFAULT_LAYOUT's order, so each new button finds the one before it
    local order, seen = {}, {}
    for _, default in ipairs(DEFAULT_LAYOUT) do
        for _, key in ipairs(default.items) do
            table.insert(order, key)
            seen[key] = true
        end
    end
    for key in pairs(ENTRIES) do
        if not seen[key] then
            table.insert(order, key)
        end
    end
    for _, key in ipairs(order) do
        if ENTRIES[key] and not placed[key] and not AlniMenuDB.known[key] then
            PlaceNewButton(layout, key)
        end
        AlniMenuDB.known[key] = true
    end

    -- exactly one Game Menu category: marked, named so, holding Blizzard Menu, or the first
    local fixed
    for _, category in ipairs(layout) do
        if not fixed and category.fixed then
            fixed = category
        end
    end
    for _, category in ipairs(layout) do
        if not fixed and (category.name == GAME_MENU_NAME or category.name == "Game Menu") then
            fixed = category
        end
    end
    for _, category in ipairs(layout) do
        for _, key in ipairs(category.items) do
            if not fixed and key == "blizzard" then
                fixed = category
            end
        end
    end
    fixed = fixed or layout[1]
    for _, category in ipairs(layout) do
        category.fixed = nil
    end
    fixed.fixed, fixed.name, fixed.hidden = true, GAME_MENU_NAME, nil

    for key, entry in pairs(ENTRIES) do
        if entry.always and not placed[key] and not InLayout(layout, key) then
            table.insert(fixed.items, key)
        end
    end

    -- widget instances only exist in a category
    for key, entry in pairs(ENTRIES) do
        if entry.instance and not InLayout(layout, key) then
            AlniMenuDB.instances[key] = nil
            ns.RemoveEntry(key)
        end
    end

    -- forget keys no longer known, like widgets whose addon is off (saved layouts keep them)
    for _, saved in ipairs({ AlniMenuDB.buttons, AlniMenuDB.labels, AlniMenuDB.known, AlniMenuDB.widgetSettings }) do
        if type(saved) == "table" then
            for key in pairs(saved) do
                if not ENTRIES[key] then
                    saved[key] = nil
                end
            end
        end
    end
    for key in pairs(AlniMenuDB.instances or {}) do
        if not ENTRIES[key] then
            AlniMenuDB.instances[key] = nil
        end
    end

    -- unused buttons are off
    if type(AlniMenuDB.buttons) == "table" then
        for key, entry in pairs(ENTRIES) do
            if not entry.always and not InLayout(layout, key) then
                AlniMenuDB.buttons[key] = false
            end
        end
    end
end

--- The buttons in no category, sorted by label
---@return string[]
function ns.UnusedKeys()
    local placed = {}
    for _, category in ipairs(AlniMenuDB.layout) do
        for _, key in ipairs(category.items) do
            placed[key] = true
        end
    end
    local unused = {}
    for key, entry in pairs(ENTRIES) do
        if not placed[key] and not entry.widget then
            table.insert(unused, key)
        end
    end
    table.sort(unused, function(a, b) return ns.Label(a) < ns.Label(b) end)
    return unused
end

ns.ENTRIES = ENTRIES
for key, entry in pairs(ENTRIES) do
    entry.key = key
end

--- What `key`'s button says: the player's name for it (not for custom buttons), or its own
---@param key string
---@return string
function ns.Label(key)
    local entry = ENTRIES[key]
    if not entry then
        return ""
    end
    local renamed = not entry.custom and AlniMenuDB.labels and AlniMenuDB.labels[key]
    if renamed then
        return renamed
    end
    -- a profession button is named after the profession learned there
    local name = entry.profession and entry.profession()
    return name or entry.text
end

--------------------------------------------------
-- Custom buttons
--
-- AlniMenuDB.custom[id] = { text, macro }, from edit mode (Custom.lua). Each is the entry "custom<id>", a secure button
-- running the macro.
--------------------------------------------------

function ns.CustomKey(id)
    return "custom" .. id
end

--- Adds (or refreshes) custom button `id` in the catalog
---@param id integer
---@return string
---@return table
function ns.AddCustomEntry(id)
    local data = AlniMenuDB.custom[id]
    local key = ns.CustomKey(id)
    local entry = ENTRIES[key] or { custom = id, key = key }
    entry.text = data.text
    entry.action = function() return { macro = AlniMenuDB.custom[id].macro } end
    ENTRIES[key] = entry
    return key, entry
end

--- Entries for every saved custom button, before the layout check
function ns.LoadCustomEntries()
    for id in pairs(AlniMenuDB.custom) do
        ns.AddCustomEntry(id)
    end
end

--- Whether the player has `key` switched on
---@param key string
---@return boolean
function ns.IsEnabled(key)
    local entry = ENTRIES[key]
    if entry.always then
        return true
    end
    local saved = AlniMenuDB.buttons and AlniMenuDB.buttons[key]
    if saved == nil then
        return entry.default and true or false
    end
    return saved
end

--------------------------------------------------
-- Window
--------------------------------------------------

local menu

-- debug view (the bug icon): every button and marker, and what each button does
local debugView = false

--- A widget's row: button sized, with a label, filled in by the widget's `create`. Nil if `create` fails.
---@param entry table
---@param action table
---@return Frame?
local function CreateWidgetRow(entry, action)
    local def = action.widget
    local row = CreateFrame("Frame", nil, menu)
    row:SetSize(BUTTON_W, def.height or BUTTON_H)
    row.action = action
    row.lib = ns.Lib
    -- saved for the widget, per row
    AlniMenuDB.widgetSettings[entry.key] = AlniMenuDB.widgetSettings[entry.key] or {}
    row.settings = AlniMenuDB.widgetSettings[entry.key]
    row.label = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.label:SetPoint("CENTER")

    -- what the layout and edit mode use on buttons
    function row:SetText(text)
        self.name = text
        if def.update then
            def.update(self)
        else
            self.label:SetText(text)
        end
    end
    function row:GetFontString()
        return self.label
    end

    if def.create then
        local ok, err = pcall(def.create, row)
        if not ok then
            print("|cff33ff99" .. ADDON_NAME .. ":|r widget " .. entry.key .. " failed: " .. tostring(err))
            row:Hide()
            return nil
        end
    end
    row:SetText(ns.Label(entry.key))
    return row
end

--- Makes the button for `entry`, the way its action needs; nil when this client cannot do it
---@param entry table
---@return Button?
local function CreateMenuButton(entry)
    local action = entry.action()
    if not action then
        return nil
    end
    if action.widget then
        return CreateWidgetRow(entry, action)
    end
    local b
    if action.click or action.macro or action.spell then
        b = CreateFrame("Button", nil, menu, "SecureActionButtonTemplate, " .. BUTTON_TEMPLATE)
        if action.click then
            b:SetAttribute("type", "click")
            b:SetAttribute("clickbutton", action.click)
        elseif action.spell then
            -- the spell itself is set each time the menu is laid out
            b:SetAttribute("type", "spell")
        else
            b:SetAttribute("type", "macro")
            b:SetAttribute("macrotext", action.macro)
        end
        -- once, on release, on every client
        b:SetAttribute("useOnKeyDown", false)
        b:RegisterForClicks("AnyUp")
        b:HookScript("PostClick", function() ns.HideMenu() end)
    else
        b = CreateFrame("Button", nil, menu, BUTTON_TEMPLATE)
        b:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
            ns.HideMenu()
            action.func()
        end)
    end
    b:SetSize(BUTTON_W, BUTTON_H)
    b:SetText(ns.Label(entry.key))
    b.action = action
    -- the reason for an alert badge, when it has one
    ns.Lib:AddTooltip(b, function()
        if debugView then
            return ns.Label(entry.key), b.debugText
        end
        return b.alertText
    end)
    return b
end

--- Makes `key`'s button if missing, or updates a custom button's label and macro. Out of combat only.
---@param key string
function ns.RefreshEntryButton(key)
    local entry = ENTRIES[key]
    if not menu or not entry then
        return
    end
    if not entry.button then
        entry.button = CreateMenuButton(entry)
    elseif entry.custom then
        entry.button:SetAttribute("macrotext", AlniMenuDB.custom[entry.custom].macro)
        entry.button.action.macro = AlniMenuDB.custom[entry.custom].macro
    end
    if entry.button then
        entry.button:SetText(ns.Label(key))
    end
    if entry.editBar then
        entry.editBar.label:SetText(ns.Label(key))
    end
end

--- Takes a deleted custom button out of the catalog and the menu
---@param key string
function ns.RemoveEntry(key)
    local entry = ENTRIES[key]
    if not entry then
        return
    end
    if entry.button then
        entry.button:Hide()
    end
    if entry.editBar then
        entry.editBar:Hide()
    end
    for _, category in ipairs(AlniMenuDB.layout) do
        for j = #category.items, 1, -1 do
            if category.items[j] == key then
                table.remove(category.items, j)
            end
        end
        category.gaps[key] = nil
    end
    ENTRIES[key] = nil
end

--- Shows or hides the mark entry.badge asks for, made like the Game Menu's
---@param entry table
local function UpdateBadge(entry)
    local b = entry.button
    local badge, reason
    if entry.badge then
        local ok, b1, b2 = pcall(entry.badge)
        if ok then
            badge, reason = b1, b2
        end
    end
    -- or the dot of a micro button it clicks
    local micro = b.action.click
    if not badge and micro and micro.NotificationOverlay and micro.NotificationOverlay:IsShown() then
        badge = "alert"
    end
    b.alertText = badge == "alert" and reason or nil

    if debugView then
        -- what the button is and does
        local action = b.action
        local how = action.click and ("clicks " .. (action.click:GetName() or "a Blizzard button"))
            or action.macro and ("runs " .. action.macro:gsub("\n", " / "))
            or action.spell and ("casts spell " .. tostring(b:GetAttribute("spell")))
            or "calls a Blizzard function"
        local lines = {
            "key: " .. entry.key,
            how,
            "switched on: " .. tostring(ns.IsEnabled(entry.key)),
            "applies now: " .. tostring(not entry.shown or entry.shown() and true or false),
            "marker now: " .. (badge or "none") .. (reason and (" (" .. reason .. ")") or ""),
        }
        b.debugText = table.concat(lines, "\n")
        -- show every marker it can have
        local canMark = entry.badge or (micro and micro.NotificationOverlay)
        if canMark and not badge then
            badge = entry.badgeKind or "alert"
        end
    end

    if badge == "new" and not b.newLabel then
        b.newLabel = CreateFrame("Frame", nil, b, "NewFeatureLabelTemplate")
        b.newLabel:SetScale(0.8)
        b.newLabel:SetPoint("BOTTOMRIGHT", b:GetFontString(), "LEFT", 16, -10)
    elseif badge == "alert" and not b.alert then
        b.alert = CreateFrame("Frame", nil, b)
        b.alert:SetSize(21, 21)
        b.alert:SetPoint("TOPLEFT", b, "TOPLEFT", -5, 5)
        b.alert:SetFrameLevel(b:GetFrameLevel() + 10)
        local icon = b.alert:CreateTexture(nil, "OVERLAY")
        icon:SetAllPoints()
        icon:SetAtlas("UI-HUD-MicroMenu-Communities-Icon-Notification")
    end
    if b.newLabel then
        b.newLabel:SetShown(badge == "new")
    end
    if b.alert then
        b.alert:SetShown(badge == "alert")
    end
end

--- Whether `key`'s button shows now: made, switched on and its `shown` check passing
---@param key string
---@return boolean
local function IsShown(key)
    local entry = ENTRIES[key]
    if not (entry.button and ns.IsEnabled(key)) then
        return false
    end
    if entry.shown then
        local ok, shown = pcall(entry.shown)
        return ok and shown and true or false
    end
    return true
end

--------------------------------------------------
-- Edit mode
--
-- The gear switches the menu to edit mode: every button shows under a bar of controls, headings become name boxes, "+
-- Add" adds buttons and widgets and the footer has the layouts. Changes are kept only with Done.
--------------------------------------------------

local editing = false
local Layout, HasShownIn   -- below; the edit controls lay the menu out again

-- AlniMenuDB as edit mode started, put back unless it ends with Done
local saved
local refreshButtons = false   -- buttons to bring up to date out of combat

local function Copy(t)
    if type(t) ~= "table" then
        return t
    end
    local c = {}
    for k, v in pairs(t) do
        c[k] = Copy(v)
    end
    return c
end

local function Snapshot()
    saved = {
        layout     = Copy(AlniMenuDB.layout),
        buttons    = Copy(AlniMenuDB.buttons),
        labels     = Copy(AlniMenuDB.labels),
        custom     = Copy(AlniMenuDB.custom),
        instances  = Copy(AlniMenuDB.instances),
        known      = Copy(AlniMenuDB.known),
        widgetSettings = Copy(AlniMenuDB.widgetSettings),
    }
end

local function RefreshButtons()
    refreshButtons = false
    for key in pairs(ENTRIES) do
        ns.RefreshEntryButton(key)
    end
end

local function Discard()
    if not saved then
        return
    end
    if ns.HideCustomWindow then
        ns.HideCustomWindow()
    end
    -- custom buttons a saved layout uses stay (an import made while editing), even if made while editing
    for _, layout in ipairs(AlniMenuDB.layouts) do
        for _, category in ipairs(layout.layout or {}) do
            for _, key in ipairs(category.items or {}) do
                local entry = ENTRIES[key]
                if entry and entry.custom and not saved.custom[entry.custom] then
                    saved.custom[entry.custom] = AlniMenuDB.custom[entry.custom]
                end
            end
        end
    end
    -- custom buttons made while editing go, deleted ones come back
    for key, entry in pairs(ENTRIES) do
        if entry.custom and not saved.custom[entry.custom] then
            ns.RemoveEntry(key)
        end
        if entry.instance and not saved.instances[key] then
            ns.RemoveEntry(key)
        end
    end
    AlniMenuDB.layout     = saved.layout
    AlniMenuDB.buttons    = saved.buttons
    AlniMenuDB.labels     = saved.labels
    AlniMenuDB.custom     = saved.custom
    AlniMenuDB.instances  = saved.instances
    AlniMenuDB.known      = saved.known
    AlniMenuDB.widgetSettings = saved.widgetSettings
    -- nextCustom and nextInstance only grow, so an id is never given to two buttons
    saved = nil
    ns.LoadCustomEntries()
    ns.LoadInstances()
    if ns.RefreshCustomList then
        ns.RefreshCustomList()
    end
    -- secure buttons: only out of combat
    if InCombatLockdown() then
        refreshButtons = true
    else
        RefreshButtons()
    end
end
local DoLayout

local ICON = {
    up     = "Interface\\Buttons\\Arrow-Up-Up",
    down   = "Interface\\Buttons\\Arrow-Down-Up",
    left   = "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up",
    right  = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up",
    gap    = "Interface\\Buttons\\UI-PlusButton-Up",
    nogap  = "Interface\\Buttons\\UI-MinusButton-Up",
    delete = "Interface\\Buttons\\UI-StopButton",
    gear   = "Interface\\Buttons\\UI-OptionsButton",
    edit   = "Interface\\Buttons\\UI-GuildButton-PublicNote-Up",
}

--- A tooltip for control `b` that is greyed out while `b` is disabled
---@param b Button
---@param text string
function ns.ControlTooltip(b, text)
    ns.Lib:AddTooltip(b, function()
        if b:IsEnabled() then
            return text
        end
        return "|cff808080" .. text .. "|r"
    end)
end

--- A small icon button with a tooltip
---@param parent Frame
---@param icon string
---@param size number
---@param tooltip string
---@param onClick function
---@return Button
local function IconButton(parent, icon, size, tooltip, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b:SetNormalTexture(icon)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetScript("OnClick", onClick)
    ns.ControlTooltip(b, tooltip)
    return b
end

--- A small text button with a tooltip
---@param parent Frame
---@param text string
---@param tooltip string
---@param onClick function
---@return Button
local function TextButton(parent, text, tooltip, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetNormalFontObject("GameFontNormalSmall")
    b:SetHighlightFontObject("GameFontHighlightSmall")
    b:SetText(text)
    b:SetSize(b:GetFontString():GetStringWidth() + 8, 18)
    b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    b:SetScript("OnClick", onClick)
    ns.ControlTooltip(b, tooltip)
    return b
end

--- Enables `b`, or greys it out
---@param b Button
---@param usable boolean
local function SetUsable(b, usable)
    b:SetEnabled(usable)
    b:SetAlpha(usable and 1 or 0.3)
end

--- Where `key` is: its category's index and its place in it (nil, nil when unused)
---@param key string
---@return integer?
---@return integer?
local function Find(key)
    for i, category in ipairs(AlniMenuDB.layout) do
        for j, k in ipairs(category.items) do
            if k == key then
                return i, j
            end
        end
    end
end

--- Whether Esc closes the menu. Not in edit mode: Esc on one of its windows would close the menu too, and with it the
--- unsaved edits.
---@param on boolean
local function EscCloses(on)
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == "AlniMenuFrame" then
            table.remove(UISpecialFrames, i)
        end
    end
    if on then
        table.insert(UISpecialFrames, "AlniMenuFrame")
    end
end

local function Changed()
    Layout()
    -- the custom button windows show categories and where each button is
    if ns.RefreshCustomWindow then
        ns.RefreshCustomWindow()
    end
    if ns.RefreshCustomList then
        ns.RefreshCustomList()
    end
end

--- Moves `key` up (-1) or down (+1) in its column
---@param key string
---@param delta integer
local function MoveVertical(key, delta)
    local i, j = Find(key)
    if not i then
        return
    end
    local items = AlniMenuDB.layout[i].items
    -- the next one that shows in edit mode
    local to = j + delta
    while items[to] and not (ENTRIES[items[to]] and ENTRIES[items[to]].button) do
        to = to + delta
    end
    if to < 1 or to > #items then
        return
    end
    items[j], items[to] = items[to], items[j]
    Changed()
end

--- Moves `key` a column left (-1) or right (+1), between categories
---@param key string
---@param delta integer
local function MoveColumn(key, delta)
    local layout = AlniMenuDB.layout
    local i, j = Find(key)
    local to = i and i + delta
    if not to or to < 1 or to > #layout then
        return
    end
    table.remove(layout[i].items, j)
    layout[i].gaps[key] = nil
    table.insert(layout[to].items, key)
    Changed()
end

local function ToggleGap(key)
    local i = Find(key)
    if not i then
        return
    end
    local gaps = AlniMenuDB.layout[i].gaps
    gaps[key] = not gaps[key] or nil
    Changed()
end

local function MoveCategory(i, delta)
    local layout = AlniMenuDB.layout
    local to = i + delta
    if to < 1 or to > #layout then
        return
    end
    layout[i], layout[to] = layout[to], layout[i]
    Changed()
end

--- Deletes category `i`. Its buttons become unused, ones that must stay go to Game Menu.
---@param i integer
local function DeleteCategory(i)
    local layout = AlniMenuDB.layout
    if #layout <= 1 or layout[i].fixed then
        return
    end
    local removed = table.remove(layout, i)
    for _, key in ipairs(removed.items) do
        if ENTRIES[key].always then
            table.insert(GameMenuCategory().items, key)
        else
            AlniMenuDB.buttons[key] = false   -- now unused
        end
    end
    Changed()
end

--- Shows or hides category `i` in the menu (not the Game Menu one)
---@param i integer
---@param shown boolean
local function SetCategoryShown(i, shown)
    local category = AlniMenuDB.layout[i]
    if not category or category.fixed then
        return
    end
    category.hidden = not shown or nil
    Changed()
end

local function AddCategory()
    table.insert(AlniMenuDB.layout, { name = "New Category", items = {}, gaps = {} })
    Changed()
end

--- Puts button or widget `key` at the end of category `i` (default: Game Menu), switched on
---@param key string
---@param i integer?
local function AddToCategory(key, i)
    local category = i and AlniMenuDB.layout[i] or GameMenuCategory()
    table.insert(category.items, key)
    AlniMenuDB.buttons[key] = true
    Changed()
end

--- Adds a new instance of `multiple` widget `key` to category `i`
---@param key string
---@param i integer?
local function AddInstance(key, i)
    local entryKey = NewInstance(key)
    ns.RefreshEntryButton(entryKey)
    if ENTRIES[entryKey] and ENTRIES[entryKey].button then
        AddToCategory(entryKey, i)
    end
end

--- Takes `key` out of the menu. The + on a category offers it again; an instance of a `multiple` widget is deleted.
---@param key string
local function RemoveFromMenu(key)
    local entry = ENTRIES[key]
    if entry and entry.instance then
        AlniMenuDB.instances[key] = nil
        AlniMenuDB.buttons[key] = nil
        ns.RemoveEntry(key)
        Changed()
        return
    end
    local i, j = Find(key)
    if not i then
        return
    end
    table.remove(AlniMenuDB.layout[i].items, j)
    AlniMenuDB.layout[i].gaps[key] = nil
    AlniMenuDB.buttons[key] = false
    Changed()
end

-- How the + lists group the buttons, whatever the layout. Buttons in none go under Other
local ADD_GROUPS = {
    { items = { "options", "shop", "addons", "editmode", "support", "macros", "reload", "logout", "exit", "blizzard",
                "close" } },
    { name = "Character", items = { "character", "reputation", "currency", "spellbook", "talents", "professions",
                                    "profession1", "profession2", "cooking", "achievements" } },
    { name = "Adventure", items = { "questlog", "adventure", "travelerslog", "calendar", "housing" } },
    { name = "Social", items = { "guild", "groupfinder", "pvp" } },
    { name = "Collections", items = { "mounts", "appearances" } },
}

--- The + on category `i`: the buttons and widgets not in the menu, and a new custom button
---@param owner Frame
---@param i integer
local function ShowAddMenu(owner, i)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        return
    end
    -- buttons under their ADD_GROUPS group
    local home = {}
    local groups, order = {}, {}
    local function Group(name)
        if not groups[name] then
            groups[name] = {}
            table.insert(order, name)
        end
        return groups[name]
    end
    for _, group in ipairs(ADD_GROUPS) do
        local name = group.name or GAME_MENU_NAME
        Group(name)
        for _, key in ipairs(group.items) do
            home[key] = name
        end
    end
    for _, key in ipairs(ns.UnusedKeys()) do
        if ENTRIES[key].button then
            table.insert(Group(ENTRIES[key].custom and "Your buttons" or home[key] or "Other"), key)
        end
    end

    local widgets = {}
    for _, key in ipairs(WIDGETS) do
        local def = WIDGET_DEFS[key]
        if def.multiple then
            table.insert(widgets, { text = def.text, add = function() AddInstance(key, i) end })
        elseif ENTRIES[key].button and not Find(key) then
            table.insert(widgets, { text = ns.Label(key), add = function() AddToCategory(key, i) end })
        end
    end

    MenuUtil.CreateContextMenu(owner, function(_, root)
        for _, name in ipairs(order) do
            if #groups[name] > 0 then
                local sub = root:CreateButton(name)
                for _, key in ipairs(groups[name]) do
                    sub:CreateButton(ns.Label(key), function() AddToCategory(key, i) end)
                end
            end
        end
        if #widgets > 0 then
            local sub = root:CreateButton("Widget")
            for _, widget in ipairs(widgets) do
                sub:CreateButton(widget.text, widget.add)
            end
        end
        root:CreateDivider()
        root:CreateButton("New custom button...", function() ns.EditCustomButton(nil, i) end)
    end)
end

--- The Layouts list: load a built-in or saved layout, or save this one
---@param owner Frame
local function ShowLayoutMenu(owner)
    local function Ask(label, data)
        StaticPopup_Show("ALNIMENU_LOAD_LAYOUT", label, nil, data)
    end
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        return Ask("Default", { name = "default" })
    end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        for _, layout in ipairs(LAYOUT_ORDER) do
            root:CreateButton(layout.label, function() Ask(layout.label, { name = layout.name }) end)
        end
        if #AlniMenuDB.layouts > 0 then
            root:CreateDivider()
        end
        for _, saved in ipairs(AlniMenuDB.layouts) do
            local name = saved.name
            local sub = root:CreateButton(name)
            sub:CreateButton("Load", function() Ask(name, { saved = name }) end)
            sub:CreateButton("Rename", function() StaticPopup_Show("ALNIMENU_RENAME_LAYOUT", name, nil, name) end)
            sub:CreateButton(DELETE or "Delete", function()
                StaticPopup_Show("ALNIMENU_DELETE_LAYOUT", name, nil, name)
            end)
        end
        root:CreateDivider()
        root:CreateButton("Save current layout...", function() StaticPopup_Show("ALNIMENU_SAVE_LAYOUT") end)
        if ns.CanShareLayouts and ns.CanShareLayouts() then
            root:CreateButton("Export this layout...", ns.ExportLayout)
            root:CreateButton("Import a layout...", ns.ImportLayout)
        end
    end)
end

--- The bar of controls over `entry`'s button, made on first use
---@param key string
---@return Frame
local function EditBar(key)
    local entry = ENTRIES[key]
    if entry.editBar then
        return entry.editBar
    end

    local bar = CreateFrame("Frame", nil, menu)
    bar:SetAllPoints(entry.button)
    bar:SetFrameLevel(entry.button:GetFrameLevel() + 5)
    bar:EnableMouse(true)   -- keeps clicks off the button underneath

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", 4, -4)
    bg:SetPoint("BOTTOMRIGHT", -4, 4)
    bg:SetColorTexture(0, 0, 0, 0.75)

    if not entry.always then
        bar.check = CreateFrame("CheckButton", nil, bar, "UICheckButtonTemplate")
        bar.check:SetSize(24, 24)
        bar.check:SetPoint("LEFT", 6, 0)
        bar.check:SetScript("OnClick", function(self)
            AlniMenuDB.buttons[key] = self:GetChecked() and true or false
            Changed()
        end)
        ns.ControlTooltip(bar.check, "Show in the menu")
    end

    -- right to left
    bar.right = IconButton(bar, ICON.right, 18, "Move to the next column", function() MoveColumn(key, 1) end)
    bar.right:SetPoint("RIGHT", -8, 0)
    bar.left  = IconButton(bar, ICON.left, 18, "Move to the previous column", function() MoveColumn(key, -1) end)
    bar.left:SetPoint("RIGHT", bar.right, "LEFT", 0, 0)
    bar.down  = IconButton(bar, ICON.down, 14, "Move down", function() MoveVertical(key, 1) end)
    bar.down:SetPoint("RIGHT", bar.left, "LEFT", -2, 0)
    bar.up    = IconButton(bar, ICON.up, 14, "Move up", function() MoveVertical(key, -1) end)
    bar.up:SetPoint("RIGHT", bar.down, "LEFT", -2, 0)
    bar.gap   = IconButton(bar, ICON.gap, 14, "Gap above: a space between this button and the one above",
        function() ToggleGap(key) end)
    bar.gap:SetPoint("RIGHT", bar.up, "LEFT", -4, 0)

    -- custom buttons: edit, others: rename (widgets: neither)
    local leftmost = bar.gap
    if not entry.widget then
        bar.edit = IconButton(bar, ICON.edit, 16,
            entry.custom and "Edit or delete this button" or "Rename this button",
            function()
                if entry.custom then
                    ns.EditCustomButton(key)
                else
                    ns.RenameButton(key)
                end
            end)
        bar.edit:SetPoint("RIGHT", leftmost, "LEFT", -4, 0)
        leftmost = bar.edit
    end
    if not entry.always then
        bar.remove = IconButton(bar, ICON.delete, 16, "Remove from the menu", function() RemoveFromMenu(key) end)
        bar.remove:SetPoint("RIGHT", leftmost, "LEFT", -4, 0)
        leftmost = bar.remove
    end

    -- small, full name in the tooltip
    bar.label = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.label:SetPoint("LEFT", 32, 0)
    bar.label:SetPoint("RIGHT", leftmost, "LEFT", -4, 0)
    bar.label:SetJustifyH("LEFT")
    bar.label:SetWordWrap(false)
    bar.label:SetText(ns.Label(key))
    ns.Lib:AddTooltip(bar, function() return ns.Label(key) end)

    entry.editBar = bar
    return bar
end

--- Brings `key`'s bar up to date with where it is now
---@param key string
---@param column integer
---@param index integer
---@param count integer
---@param unused boolean
local function UpdateEditBar(key, column, index, count, unused)
    local entry = ENTRIES[key]
    local bar = EditBar(key)
    local layout = AlniMenuDB.layout
    local enabled = ns.IsEnabled(key)
    bar.label:SetTextColor(enabled and 1 or 0.5, enabled and 1 or 0.5, enabled and 1 or 0.5)

    if bar.check then
        bar.check:SetChecked(enabled and not unused)
        SetUsable(bar.check, not unused)
    end
    bar.label:SetText(ns.Label(key))
    SetUsable(bar.up, not unused and index > 1)
    SetUsable(bar.down, not unused and index < count)
    SetUsable(bar.left, column > 1)
    SetUsable(bar.right, not unused and column < #layout)
    bar.gap:SetShown(not unused)
    local gap = not unused and layout[column].gaps[key]
    bar.gap:SetNormalTexture(gap and ICON.nogap or ICON.gap)
    bar:Show()
end

--- The heading over edit column `i`, made on first use
---@param i integer
---@return Frame
local function EditHeading(i)
    menu.editHeadings = menu.editHeadings or {}
    local head = menu.editHeadings[i]
    if head then
        return head
    end

    head = CreateFrame("Frame", nil, menu)
    head:SetSize(EDIT_W, 26)

    head.show = CreateFrame("CheckButton", nil, head, "UICheckButtonTemplate")
    head.show:SetSize(24, 24)
    head.show:SetPoint("LEFT", 0, 0)
    head.show:SetScript("OnClick", function(self) SetCategoryShown(head.index, self:GetChecked()) end)
    ns.ControlTooltip(head.show, "Show in the menu")

    head.name = ns.Lib:CreateEditBox(head, {
        width          = EDIT_W - 156,
        maxLetters     = 32,
        onEnterPressed = function(text)
            if not editing then
                return
            end
            local category = AlniMenuDB.layout[head.index]
            if category and not category.fixed and text ~= "" then
                category.name = text
            end
            Changed()
        end,
    })
    head.name:SetPoint("LEFT", 30, 0)
    -- leaving the box keeps what was typed, like pressing Enter
    head.name:HookScript("OnEditFocusLost", function(self)
        if not editing then
            return
        end
        local category = AlniMenuDB.layout[head.index]
        if category and not category.fixed and self:GetText() ~= "" and self:GetText() ~= category.name then
            category.name = self:GetText()
            Changed()
        end
    end)

    head.delete = IconButton(head, ICON.delete, 16, "Delete this category (its buttons leave the menu)",
        function() DeleteCategory(head.index) end)
    head.delete:SetPoint("RIGHT", -4, 0)
    head.right = IconButton(head, ICON.right, 18, "Move this column right",
        function() MoveCategory(head.index, 1) end)
    head.right:SetPoint("RIGHT", head.delete, "LEFT", -2, 0)
    head.left = IconButton(head, ICON.left, 18, "Move this column left",
        function() MoveCategory(head.index, -1) end)
    head.left:SetPoint("RIGHT", head.right, "LEFT", 0, 0)
    head.add = TextButton(head, "+ Add", "Add to this category", function() ShowAddMenu(head.add, head.index) end)
    head.add:SetPoint("RIGHT", head.left, "LEFT", -4, 0)

    head.label = head:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    head.label:SetPoint("CENTER")

    -- the Game Menu category's name, which can't be changed
    head.fixedName = head:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    head.fixedName:SetPoint("LEFT", 8, 0)

    menu.editHeadings[i] = head
    return head
end

-- Along the bottom in edit mode: layouts on the left, leaving edit mode on the right
local FOOTER_MIN = 90 + 8 + 2 * 80 + 8   -- the narrowest it fits in

local function EditFooter()
    if menu.editFooter then
        return menu.editFooter
    end
    local footer = CreateFrame("Frame", nil, menu)
    footer:SetHeight(24)

    local layouts
    layouts = ns.Lib:CreateButton(footer, {
        text        = "Layouts",
        width       = 90,
        onClick     = function() ShowLayoutMenu(layouts) end,
        tooltip     = "Layouts",
        tooltipText = "Load Default, Original, Compact or one you saved, or save this one.",
    })
    layouts:SetPoint("LEFT")
    local done = ns.Lib:CreateButton(footer, {
        text    = "Done",
        width   = 80,
        onClick = function() ns.SetEditing(false, true) end,
    })
    done:SetPoint("RIGHT")
    local cancel = ns.Lib:CreateButton(footer, {
        text        = CANCEL or "Cancel",
        width       = 80,
        onClick     = function() ns.SetEditing(false) end,
        tooltip     = CANCEL or "Cancel",
        tooltipText = "Leaves edit mode without saving the changes.",
    })
    cancel:SetPoint("RIGHT", done, "LEFT", -8, 0)

    menu.editFooter = footer
    return footer
end

--------------------------------------------------
-- Laying it out
--------------------------------------------------

--- Places `keys` down from `top` at `x`, with gaps. Returns the keys placed and the bottom.
---@param keys string[]
---@param gaps table
---@param visible function
---@param x number
---@param top number
---@return string[]
---@return number
local function LayoutColumn(keys, gaps, visible, x, top)
    local y = top
    local placed = {}
    for _, key in ipairs(keys) do
        local entry = ENTRIES[key]
        if visible(key) then
            if #placed > 0 and gaps[key] then
                y = y - SECTION_GAP
            end
            table.insert(placed, key)
            if entry.profession then
                -- the profession learned there may have changed
                local _, spellID = entry.profession()
                entry.button:SetAttribute("spell", spellID)
                entry.button:SetText(ns.Label(key))
            end
            -- widgets can be shorter, but not in edit mode, where the controls go
            local h = (not editing and entry.rowHeight) or BUTTON_H
            if entry.rowHeight then
                entry.button:SetHeight(h)
            end
            entry.button:ClearAllPoints()
            entry.button:SetPoint("TOPLEFT", menu, "TOPLEFT", x, y)
            entry.button:Show()
            y = y - h
        end
    end
    return placed, y
end

--- In edit mode every button this client has shows
---@param key string
---@return boolean
local function Exists(key)
    return ENTRIES[key].button ~= nil
end

--- Lays out the columns and fits the window. Normal mode: categories with something to show. Edit mode: all, plus
--- Unused. Out of combat only.
function DoLayout()
    if not menu then
        return
    end

    -- start from nothing
    for _, entry in pairs(ENTRIES) do
        local b = entry.button
        if b then
            b:Hide()
            b:SetWidth(editing and EDIT_W or BUTTON_W)
            b:GetFontString():SetAlpha(editing and 0 or 1)
            -- badges are only updated outside edit mode
            if editing and b.newLabel then
                b.newLabel:Hide()
            end
            if editing and b.alert then
                b.alert:Hide()
            end
            if entry.widget then
                b:SetAlpha(editing and 0 or 1)
            end
        end
        if entry.editBar then
            entry.editBar:Hide()
        end
    end
    for _, heading in ipairs(menu.headings or {}) do
        heading:Hide()
    end
    for _, head in ipairs(menu.editHeadings or {}) do
        head:Hide()
    end
    if menu.editFooter then
        menu.editFooter:Hide()
    end
    menu.headings = menu.headings or {}

    local layout = AlniMenuDB.layout
    local columns = {}
    local hasReturn = false   -- Return to Game showing in the menu
    local hasBlizzard = false -- Blizzard Menu showing in the menu
    local showAll = editing or debugView   -- every category, and Unused
    for i, category in ipairs(layout) do
        if showAll or (not category.hidden and HasShownIn(category)) then
            table.insert(columns, { category = category, index = i })
        end
    end
    if debugView and not editing then
        -- Unused wraps into columns no taller than the tallest category
        local rows = MIN_UNUSED_ROWS
        for _, column in ipairs(columns) do
            local n = 0
            for _, key in ipairs(column.category.items) do
                if Exists(key) then
                    n = n + 1
                end
            end
            rows = math.max(rows, n)
        end
        local unused = {}
        for _, key in ipairs(ns.UnusedKeys()) do
            if Exists(key) then
                table.insert(unused, key)
            end
        end
        local first = true
        repeat
            local chunk = {}
            for i = 1, rows do
                if #unused == 0 then
                    break
                end
                table.insert(chunk, table.remove(unused, 1))
            end
            table.insert(columns, { unused = true, first = first, items = chunk, index = #layout + 1 })
            first = false
        until #unused == 0
    end

    if debugView and not editing then
        -- one of each widget not in the layout, and a preview (never saved) of the `multiple` ones
        local items = {}
        for _, key in ipairs(WIDGETS) do
            if WIDGET_DEFS[key].multiple then
                WidgetEntry(key, WIDGET_DEFS[key])
                ns.RefreshEntryButton(key)
            end
            if ENTRIES[key] and ENTRIES[key].button and not Find(key) then
                table.insert(items, key)
            end
        end
        table.insert(columns, { widgets = true, items = items })
    end

    local headed = showAll or #columns > 1
    local headingH = editing and 32 or HEADING_H
    local top    = -TOP - (headed and headingH or 0)
    local bottom = top - (editing and BUTTON_H or 0)   -- empty columns still get a row

    local columnW = editing and EDIT_W or BUTTON_W
    for c, column in ipairs(columns) do
        local x = SIDE + (c - 1) * (columnW + COLUMN_GAP)
        local keys = column.items or column.category.items
        local gaps = column.category and column.category.gaps or {}

        if editing then
            local head = EditHeading(c)
            head.index = column.index
            head:ClearAllPoints()
            head:SetPoint("BOTTOMLEFT", menu, "TOPLEFT", x, top + 4)
            local fixed = not column.unused and column.category.fixed
            head.name:SetShown(not column.unused and not fixed)
            head.show:SetShown(not column.unused and not fixed)
            head.fixedName:SetShown(fixed and true or false)
            head.left:SetShown(not column.unused)
            head.right:SetShown(not column.unused)
            head.add:SetShown(not column.unused)
            head.delete:SetShown(not column.unused and not fixed)
            head.label:SetShown(column.unused and true or false)
            if column.unused then
                head.label:SetText(column.first and "Unused" or "")
            elseif fixed then
                head.fixedName:SetText(column.category.name)
                SetUsable(head.left, column.index > 1)
                SetUsable(head.right, column.index < #layout)
            else
                if not head.name:HasFocus() then
                    head.name:SetText(column.category.name)
                end
                local shown = not column.category.hidden
                head.show:SetChecked(shown)
                head.name:SetTextColor(shown and 1 or 0.5, shown and 1 or 0.5, shown and 1 or 0.5)
                SetUsable(head.left, column.index > 1)
                SetUsable(head.right, column.index < #layout)
                SetUsable(head.delete, #layout > 1)
            end
            head:Show()
        elseif headed then
            local heading = menu.headings[c]
            if not heading then
                heading = menu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                menu.headings[c] = heading
            end
            if column.widgets then
                heading:SetText("Widgets")
            else
                heading:SetText(column.unused and (column.first and "Unused" or "") or column.category.name)
            end
            heading:ClearAllPoints()
            heading:SetPoint("BOTTOM", menu, "TOPLEFT", x + BUTTON_W / 2, top + 4)
            heading:Show()
        end

        local placed, y = LayoutColumn(keys, gaps, showAll and Exists or IsShown, x, top)
        for i, key in ipairs(placed) do
            if editing then
                UpdateEditBar(key, column.index, i, #placed, column.unused)
            else
                UpdateBadge(ENTRIES[key])
                if key == "close" then
                    hasReturn = true
                end
                if key == "blizzard" then
                    hasBlizzard = true
                end
            end
        end
        bottom = math.min(bottom, y)
    end

    -- close X: when there's no Return to Game, while editing, and always in Basic (it has a slot for it)
    local theme = menu:GetTheme()
    local cornerX = theme == "basic" or theme == "panel"
    local showX = theme == "basic" or editing or not hasReturn
    menu.closeX:SetShown(showX)
    menu.closeX:ClearAllPoints()
    if cornerX then
        menu.closeX:SetPoint("TOPRIGHT", 1, 0)
    else
        menu.closeX:SetPoint("TOPRIGHT", -6, -6)
    end
    -- Blizzard Menu button: when the menu has none, and while editing
    menu.blizz:SetShown(editing or not hasBlizzard)
    if menu.bug then
        menu.bug:ClearAllPoints()
        menu.bug:SetPoint("RIGHT", menu.blizz:IsShown() and menu.blizz or menu.gear, "LEFT", -4, 0)
    end
    menu.gear:ClearAllPoints()
    if showX then
        menu.gear:SetPoint("RIGHT", menu.closeX, "LEFT", -2, 0)
    elseif cornerX then
        -- in the title bar
        menu.gear:SetPoint("TOPRIGHT", -6, -1)
    else
        menu.gear:SetPoint("TOPRIGHT", -12, -12)
    end

    -- never narrower than one column, even with nothing to show
    local width = 2 * SIDE + math.max(#columns, 1) * columnW + math.max(#columns - 1, 0) * COLUMN_GAP
    -- a + after the last heading for a new category
    if editing then
        if not menu.newCategory then
            menu.newCategory = IconButton(menu, ICON.gap, 16, "New category", AddCategory)
            menu.newCategory:SetFrameLevel(menu:GetFrameLevel() + 20)
        end
        menu.newCategory:ClearAllPoints()
        menu.newCategory:SetPoint("LEFT", menu, "TOPLEFT", width - SIDE + 6, top + 17)
        menu.newCategory:Show()
        width = width + 26
    elseif menu.newCategory then
        menu.newCategory:Hide()
    end
    if editing then
        local footer = EditFooter()
        width = math.max(width, FOOTER_MIN + 2 * SIDE)
        footer:SetWidth(width - 2 * SIDE)
        footer:ClearAllPoints()
        footer:SetPoint("TOPLEFT", menu, "TOPLEFT", SIDE, bottom - 16)
        footer:Show()
        bottom = bottom - 16 - 24
    end
    menu:SetSize(width, -bottom + BOTTOM)
end

--- DoLayout, printing errors to chat (WoW hides them unless scriptErrors is on)
function Layout()
    local ok, err = xpcall(DoLayout, function(e)
        return tostring(e) .. (debugstack and ("\n" .. debugstack(2, 4, 0)) or "")
    end)
    if not ok then
        print("|cff33ff99" .. ADDON_NAME .. ":|r layout error: " .. tostring(err))
    end
end

--- Whether any of `category`'s buttons shows right now
---@param category table
---@return boolean
HasShownIn = function(category)
    for _, key in ipairs(category.items) do
        if IsShown(key) then
            return true
        end
    end
    return false
end

--------------------------------------------------
-- Window
--------------------------------------------------

local function BuildMenu()
    menu = ns.Lib:CreateDialog({
        name          = "AlniMenuFrame",
        title         = L("MAINMENU_BUTTON", "Game Menu"),
        width         = BUTTON_W + 2 * SIDE,   -- fitted by Layout
        height        = 300,
        theme         = AlniMenuDB.theme,
        strata        = "DIALOG",
        noCloseButton = true,  -- as the Game Menu; its own close X is below
    })

    for _, entry in pairs(ENTRIES) do
        entry.button = CreateMenuButton(entry)
    end

    -- the gear: edit mode on and off
    local gear = IconButton(menu, ICON.gear, 20, "Edit layout", function() ns.SetEditing(not editing) end)
    gear:SetPoint("TOPRIGHT", -12, -12)
    gear:SetFrameLevel(menu:GetFrameLevel() + 20)
    menu.gear = gear

    -- the way out to the Game Menu, left of the gear (shown by Layout)
    local blizz = CreateFrame("Button", nil, menu)
    blizz:SetSize(16, 20)
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("UI-HUD-MicroMenu-GameMenu-Up") then
        blizz:SetNormalAtlas("UI-HUD-MicroMenu-GameMenu-Up")
        blizz:SetPushedAtlas("UI-HUD-MicroMenu-GameMenu-Down")
    else
        blizz:SetNormalTexture("Interface\\Buttons\\UI-MicroButton-MainMenu-Up")
        blizz:SetPushedTexture("Interface\\Buttons\\UI-MicroButton-MainMenu-Down")
    end
    blizz:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    blizz:SetPoint("RIGHT", gear, "LEFT", -4, 0)
    blizz:SetFrameLevel(menu:GetFrameLevel() + 20)
    blizz:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        ns.HideMenu()
        ShowBlizzardMenu()
    end)
    ns.Lib:AddTooltip(blizz, "Blizzard Menu")
    menu.blizz = blizz

    -- the version, bottom left
    local getMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local version = menu:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    version:SetPoint("BOTTOMLEFT", 14, 12)
    version:SetText(strtrim((getMetadata(ADDON_NAME, "Version") or "") .. " " .. RELEASE))
    menu.version = version

    -- the close X, for when Return to Game is not in the menu
    local closeX = CreateFrame("Button", nil, menu, "UIPanelCloseButton")
    closeX:SetFrameLevel(menu:GetFrameLevel() + 20)
    closeX:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
        ns.HideMenu()
    end)
    menu.closeX = closeX

    -- the debug view's switch, only while debugging (DEBUG in Core.lua)
    if ns.DEBUG then
        local bug = IconButton(menu, "Interface\\HelpFrame\\HelpIcon-Bug", 22,
            "Debug view: every button and every marker", function()
                debugView = not debugView
                Layout()
            end)
        -- placed by Layout, left of the other corner buttons
        bug:SetFrameLevel(menu:GetFrameLevel() + 20)
        menu.bug = bug
    end

    -- closing the menu ends edit mode, without saving
    menu:HookScript("OnHide", function()
        if editing then
            editing = false
            EscCloses(true)
            StaticPopup_Hide("ALNIMENU_LOAD_LAYOUT")
            Discard()
        end
    end)

    -- Esc closes it, like any addon window (not in edit mode, see EscCloses)
    table.insert(UISpecialFrames, "AlniMenuFrame")
end

--------------------------------------------------
-- Showing and hiding
--------------------------------------------------

function ns.ShowMenu()
    -- not before PLAYER_LOGIN, when the layout is ready
    if InCombatLockdown() or not ns.ready then
        return false
    end
    if not menu then
        BuildMenu()
    end
    if refreshButtons then
        RefreshButtons()
    end
    Layout()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
    menu:Show()
    return true
end

--- Hides the menu; true if it was showing
---@return boolean
function ns.HideMenu()
    if not (menu and menu:IsShown()) then
        return false
    end
    if InCombatLockdown() then
        return false
    end
    menu:Hide()
    return true
end

--- Turns edit mode on or off. Off keeps the changes only with `save` (Done).
---@param on boolean
---@param save boolean?
function ns.SetEditing(on, save)
    if InCombatLockdown() then
        return
    end
    if on and not editing then
        Snapshot()
    end
    if not on and editing then
        -- a category name still being typed goes in first (and is undone with the rest on Cancel)
        for _, head in ipairs(menu and menu.editHeadings or {}) do
            head.name:ClearFocus()
        end
        StaticPopup_Hide("ALNIMENU_LOAD_LAYOUT")
        if save then
            saved = nil
        else
            Discard()
        end
    end
    editing = on and true or false
    EscCloses(not editing)
    if not (menu and menu:IsShown()) then
        ns.ShowMenu()
    else
        Layout()
    end
end

--- Switches the menu to the theme in AlniMenuDB
function ns.ApplyTheme()
    if not menu then
        return
    end
    menu:SetTheme(AlniMenuDB.theme)
    if menu:IsShown() then
        Layout()
    end
end

--- Lays the open menu out again
function ns.ApplyLayout()
    if menu and menu:IsShown() and not InCombatLockdown() then
        Layout()
    end
end

-- Saved layouts: AlniMenuDB.layouts = { { name, layout, buttons } }, from the Layouts list. `buttons`: which were on.

local function FindSaved(name)
    for i, saved in ipairs(AlniMenuDB.layouts) do
        if saved.name == name then
            return i, saved
        end
    end
end

--- Gives saved layouts that share a name (old or hand-edited data) their own: "Name 2", "Name 3"...
function ns.FixSavedLayouts()
    -- damaged saved data: drop anything that isn't a saved layout
    for i = #AlniMenuDB.layouts, 1, -1 do
        local saved = AlniMenuDB.layouts[i]
        if type(saved) ~= "table" or type(saved.layout) ~= "table" then
            table.remove(AlniMenuDB.layouts, i)
        end
    end
    local taken = {}
    for _, saved in ipairs(AlniMenuDB.layouts) do
        saved.name = type(saved.name) == "string" and saved.name ~= "" and saved.name or "Layout"
        taken[saved.name] = (taken[saved.name] or 0) + 1
    end
    local used = {}
    for _, saved in ipairs(AlniMenuDB.layouts) do
        if used[saved.name] then
            local n, name = 2, saved.name
            while taken[name .. " " .. n] or used[name .. " " .. n] do
                n = n + 1
            end
            saved.name = name .. " " .. n
        end
        used[saved.name] = true
    end
end

--- Adds `saved` ({ name, layout, buttons }) to the saved layouts, replacing one with the same name
---@param saved table
function ns.StoreLayout(saved)
    local i = FindSaved(saved.name)
    if i then
        AlniMenuDB.layouts[i] = saved
    else
        table.insert(AlniMenuDB.layouts, saved)
    end
end

--- Whether there is a saved layout called `name`
---@param name string
---@return boolean
function ns.HasSavedLayout(name)
    return FindSaved(name) ~= nil
end

--- Saves the current layout as `name`
---@param name string
function ns.SaveLayout(name)
    local buttons = {}
    for _, category in ipairs(AlniMenuDB.layout) do
        for _, key in ipairs(category.items) do
            buttons[key] = ns.IsEnabled(key)
        end
    end
    ns.StoreLayout({ name = name, layout = Copy(AlniMenuDB.layout), buttons = buttons })
end

function ns.DeleteLayout(name)
    local i = FindSaved(name)
    if i then
        table.remove(AlniMenuDB.layouts, i)
    end
end

--- Puts a saved layout in place. Its separators come back as new ones.
---@param saved table
local function UseSaved(saved)
    local layout = Copy(saved.layout)
    local on = {}
    for _, category in ipairs(layout) do
        for j, key in ipairs(category.items) do
            local widget = InstanceOf(key)
            if widget then
                local new = NewInstance(widget)
                if category.gaps[key] then
                    category.gaps[key], category.gaps[new] = nil, true
                end
                on[new] = saved.buttons[key]
                category.items[j] = new
            else
                on[key] = saved.buttons[key]
            end
        end
    end
    AlniMenuDB.layout = layout
    for key, entry in pairs(ENTRIES) do
        if not entry.always then
            if on[key] ~= nil then
                AlniMenuDB.buttons[key] = on[key]
            elseif not entry.custom then
                AlniMenuDB.buttons[key] = false
            end
        end
    end
end

--- Loads a built-in layout (`data.name`) or a saved one (`data.saved`). In edit mode, kept only with Done.
---@param data table
function ns.LoadLayout(data)
    if InCombatLockdown() then
        print("|cff33ff99" .. ADDON_NAME .. ":|r not in combat.")
        return
    end
    -- only from edit mode, so Cancel can undo it
    if not editing then
        return
    end
    if data.saved then
        local _, saved = FindSaved(data.saved)
        if not saved then
            return
        end
        UseSaved(saved)
    elseif LAYOUTS[data.name] then
        AlniMenuDB.layout = ns.DefaultLayout(LAYOUTS[data.name])
        SetButtonsFrom(LAYOUTS[data.name])
        -- separators get a new instance each
        for _, category in ipairs(AlniMenuDB.layout) do
            for j, key in ipairs(category.items) do
                if WIDGET_DEFS[key] and WIDGET_DEFS[key].multiple then
                    local new = NewInstance(key)
                    if category.gaps[key] then
                        category.gaps[key], category.gaps[new] = nil, true
                    end
                    AlniMenuDB.buttons[new] = true
                    category.items[j] = new
                end
            end
        end
    else
        return
    end
    ns.CheckLayout()
    -- separators made for it need a button
    if menu then
        for key in pairs(ENTRIES) do
            ns.RefreshEntryButton(key)
        end
    end
    ns.ApplyLayout()
end

StaticPopupDialogs.ALNIMENU_LOAD_LAYOUT = {
    text         = "Replace your menu layout with the %s layout?",
    button1      = ACCEPT or "Accept",
    button2      = CANCEL or "Cancel",
    OnAccept     = function(_, data) ns.LoadLayout(data) end,
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
}

StaticPopupDialogs.ALNIMENU_DELETE_LAYOUT = {
    text         = "Delete the saved layout %s?",
    button1      = DELETE or "Delete",
    button2      = CANCEL or "Cancel",
    OnAccept     = function(_, name) ns.DeleteLayout(name) end,
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
}

local function SaveFromPopup(popup)
    local box = popup.GetEditBox and popup:GetEditBox() or popup.editBox
    local name = strtrim(box:GetText())
    if name == "" then
        return
    end
    if FindSaved(name) then
        StaticPopup_Show("ALNIMENU_REPLACE_LAYOUT", name, nil, name)
    else
        ns.SaveLayout(name)
    end
end

StaticPopupDialogs.ALNIMENU_REPLACE_LAYOUT = {
    text         = "Replace the saved layout %s?",
    button1      = "Replace",
    button2      = CANCEL or "Cancel",
    OnAccept     = function(_, name) ns.SaveLayout(name) end,
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
}

--- Renames saved layout `old` to `new`. Not to an empty name or one already taken.
---@param old string
---@param new string
function ns.RenameLayout(old, new)
    new = strtrim(new or "")
    local _, saved = FindSaved(old)
    if not saved or new == old then
        return
    end
    if new == "" then
        return
    end
    if FindSaved(new) then
        print("|cff33ff99" .. ADDON_NAME .. ":|r there is already a layout called \"" .. new .. "\".")
        return
    end
    saved.name = new
end

--- The edit box of a popup
---@param popup Frame
---@return EditBox
local function PopupBox(popup)
    return popup.GetEditBox and popup:GetEditBox() or popup.editBox
end

--- Enables a popup's first button only while its box has a name in it
---@param popup Frame
local function NeedName(popup)
    local button = popup.GetButton1 and popup:GetButton1() or popup.button1
    if button then
        button:SetEnabled(strtrim(PopupBox(popup):GetText()) ~= "")
    end
end

StaticPopupDialogs.ALNIMENU_RENAME_LAYOUT = {
    text                   = "Rename %s to:",
    button1                = "Rename",
    button2                = CANCEL or "Cancel",
    hasEditBox             = true,
    maxLetters             = 32,
    OnShow                 = function(self, old)
        PopupBox(self):SetText(old)
        PopupBox(self):HighlightText()
        NeedName(self)
    end,
    OnAccept               = function(self, old) ns.RenameLayout(old, PopupBox(self):GetText()) end,
    EditBoxOnTextChanged   = function(self) NeedName(self:GetParent()) end,
    EditBoxOnEnterPressed  = function(self)
        local popup = self:GetParent()
        if strtrim(self:GetText()) == "" then
            return
        end
        ns.RenameLayout(popup.data, self:GetText())
        popup:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout                = 0,
    whileDead              = true,
    hideOnEscape           = true,
}

StaticPopupDialogs.ALNIMENU_SAVE_LAYOUT = {
    text                   = "Save the current layout as:",
    button1                = SAVE or "Save",
    button2                = CANCEL or "Cancel",
    hasEditBox             = true,
    maxLetters             = 32,
    OnShow                 = function(self) NeedName(self) end,
    OnAccept               = SaveFromPopup,
    EditBoxOnTextChanged   = function(self) NeedName(self:GetParent()) end,
    EditBoxOnEnterPressed  = function(self)
        local popup = self:GetParent()
        if strtrim(self:GetText()) == "" then
            return
        end
        SaveFromPopup(popup)
        popup:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout                = 0,
    whileDead              = true,
    hideOnEscape           = true,
}
