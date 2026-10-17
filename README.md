# AlniMenu

Replaces the Game Menu that Esc opens with a customizable one.

Use the gear to show, hide and move buttons, or add your own macro buttons. In combat or with Shift+Esc you get the normal Game Menu.

## Commands

- `/alnimenu` - Open or close the menu
- `/alnimenu edit` - Edit mode

## Adding a widget

Other addons can add widgets to the menu. A small addon with a clock, a simpler version of AlniMenu's own (`AlniMenu/Plugins/Clock.lua` also has a date tooltip and opens the game's clock window on click):

`MyClock.toc`

```
## Interface: 120105
## Title: My Clock
## Notes: A clock widget for AlniMenu.
## Dependencies: AlniMenu

MyClock.lua
```

`MyClock.lua`

```lua
if not (AlniMenu and AlniMenu.RegisterWidget) then
    return
end

AlniMenu.RegisterWidget("MyClock_Clock", {
    text = "Clock",
    create = function(row)
        -- update every second while the menu is open
        row:SetScript("OnShow", function()
            row:SetText(row.name)
            row.ticker = C_Timer.NewTicker(1, function() row:SetText(row.name) end)
        end)
        row:SetScript("OnHide", function()
            if row.ticker then
                row.ticker:Cancel()
            end
        end)
    end,
    update = function(row)
        row.label:SetText(row.name .. " " .. date("%H:%M:%S"))
    end,
})
```

It then shows up under Widget, in the + on each category in edit mode. If your addon does more than add a widget, use `## OptionalDeps: AlniMenu` instead.

- `text` - the name in the + list and in the menu
- `create(row)` - builds the widget in its row. `row.label` is a centered text, `row.lib` is AlnUI, `row.settings`
  is a table saved for the widget
- `update(row)` - shows `row.name` (the name, or what the player renamed it to) in `row.label`
- `height` - row height outside edit mode, if it isn't a button's
- `multiple` - can be added more than once, like separators
- `shown()` - whether it shows right now (hide it when it does not apply)

`AlniMenu.HideMenu()` closes the menu, for widgets that open another window.

Use a key only your addon uses. AlniMenu's own widgets are in `AlniMenu/Plugins/`, one file each.

## Total RP 3

With Total RP 3 installed, its toolbar is also a widget. Total RP 3 is not needed otherwise.
