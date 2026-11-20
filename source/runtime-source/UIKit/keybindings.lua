-- The mods' shortcuts (R.key) in the game's own Key Bindings list, after the game's keys: per mod
-- its name and its shortcuts in the game's own row widget, two to a line as the game's (the action,
-- where it works on hover, a key and a spare); the game's own keys a mod makes rebindable under a
-- small heading of their own after its shortcuts (user 11-20). A slot shows its chord as the game's key pictures,
-- modifiers first; a slot widens for a chord of several keys. A click on a slot waits for a key, in
-- the game's own waiting frame: the next key press (with Ctrl, Shift, Alt held) is the slot's chord;
-- a modifier let go with no other key is the chord alone. Delete empties the slot; Esc or a mouse
-- click leaves it as it was. A key that another shortcut uses where this one works, or that is one
-- of the game's own keys, is allowed and shows red (the player decides).
-- A search beside Back narrows the list as it is typed: by the action's name, by its mod (the
-- game's own keys are Witch It's) or by a key it is bound to; the lines shown close up.
return function(R, C, U, I)
    local LIST = '/Game/UserInterface/Settings/WB_KeyBindingList.WB_KeyBindingList_C:InitializeBindingWidgets'
    local ROW = '/Game/UserInterface/Settings/WB_KeyBinding.WB_KeyBinding_C'
    local DELETE, ESCAPE = R.codes.DELETE, R.codes.ESCAPE
    local MODIFIERS = {[16] = true, [17] = true, [18] = true, [160] = true, [161] = true,
        [162] = true, [163] = true, [164] = true, [165] = true}
    local slots, waiting, list_id = {}, nil, nil, nil
    -- The list's lines in order: {widget, heading, mod, name, keys()}; the search and its kind.
    local entries, query, by = {}, '', 'name'
    local DIGITS = {['0'] = 'Zero', ['1'] = 'One', ['2'] = 'Two', ['3'] = 'Three', ['4'] = 'Four',
        ['5'] = 'Five', ['6'] = 'Six', ['7'] = 'Seven', ['8'] = 'Eight', ['9'] = 'Nine'}
    local function found(text, wanted) return text:lower():find(wanted, 1, true) ~= nil end
    -- A key matches as written: one letter or digit is that key, longer text a part of a key's name.
    local function key_matches(keys, wanted)
        local exact = DIGITS[wanted] and DIGITS[wanted]:lower() or wanted
        for _, key in ipairs(keys) do
            local name = key:lower()
            if name == exact or #wanted > 1 and name:find(wanted, 1, true) then return true end
        end
        return false
    end
    local function shown(entry)
        if query == '' then return true end
        local wanted = query:lower()
        if by == 'mod' then return found(entry.mod, wanted) end
        if by == 'key' then return key_matches(entry.keys(), wanted) end
        return found(entry.name, wanted)
    end
    -- The lines that match, two to a line as the game shows its own (user 11-20); a heading (a mod's
    -- name, its game keys' title) on a line of its own, shown above its shortcuts shown.
    local function arrange()
        local visible, any = {}, {}
        for i, entry in ipairs(entries) do
            if not entry.heading and R.valid(entry.widget) then
                visible[i] = shown(entry)
                if visible[i] then any[entry.mod] = true; any[entry.mod .. '/' .. tostring(entry.group)] = true end
            end
        end
        local row, column, right, spare = 0, 0, false, nil
        for i, entry in ipairs(entries) do
            if R.valid(entry.widget) then
                local on = visible[i]
                if entry.heading then on = any[entry.group and entry.mod .. '/' .. entry.group or entry.mod] end
                entry.widget:SetVisibility(on and entry.visibility or 1)
                if on then
                    local whole = entry.heading
                    if whole and column == 1 then row, column = row + 1, 0 end
                    entry.widget.Slot:SetRow(row)
                    entry.widget.Slot:SetColumn(column)
                    right = right or column == 1
                    if whole or column == 1 then row, column = row + 1, 0 else column = 1 end
                elseif not entry.heading then spare = spare or entry end
            end
        end
        -- The grid keeps its two columns: a line hidden (not collapsed) holds the right one.
        if not right and spare then
            spare.widget:SetVisibility(2)
            spare.widget.Slot:SetRow(0)
            spare.widget.Slot:SetColumn(1)
        end
    end
    local function bound(row)
        local keys = {}
        for index = 0, 1 do
            local key = I.string(row['Binding_' .. index].icon.BoundKey.KeyName)
            if key ~= '' and key ~= 'None' then keys[#keys + 1] = key end
        end
        return keys
    end
    local function chords(id)
        for _, key in ipairs(R.hotkeys()) do
            if key.id == id then
                local keys = {}
                for _, chord in ipairs({key.current, key.spare}) do
                    for _, name in ipairs(R.chord_keys(chord) or {}) do keys[#keys + 1] = name end
                    for part in tostring(chord or ''):gmatch('[^+]+') do keys[#keys + 1] = part end
                end
                return keys
            end
        end
        return {}
    end
    -- A slot's chord, as the runtime has it now (index 1: the key, 2: the spare) - the one truth; the
    -- slot keeps none (audit 11-20: a cached chord went stale when the key changed elsewhere).
    local function chordOf(slot)
        for _, row in ipairs(R.hotkeys()) do
            if row.id == slot.id then return (slot.index == 1 and row.current or row.spare) or 'Disabled' end
        end
        return 'Disabled'
    end
    -- A slot shows its chord: a game key picture per key, the slot as wide as they need.
    local function caption(slot, chord)
        slot.shown = chord
        slot.parts:ClearChildren()
        local keys = R.chord_keys(chord) or {}
        for i, key in ipairs(keys) do
            local icon = i == #keys and slot.icon or I.cooked(slot.parts, 'WB_ControllerIcon', R.native.load_asset(I.KEY_ICON))
            if icon == slot.icon then slot.parts:AddChild(icon) end
            icon:SetBoundKey({KeyName = FName(key)})
        end
        slot.icon:SetVisibility(#keys > 0 and 3 or 1)
        if #keys == 0 then slot.parts:AddChild(slot.icon) end
        slot.size:SetWidthOverride(slot.width * math.max(1, #keys))
    end
    -- Keys in conflict show red: a mod's slot whose chord another mod's slot uses where both work,
    -- or whose single key is one of the game's own keys, and those game keys' slots.
    local RED = {R = 1, G = .25, B = .25, A = 1}
    local function tint(button, red)
        if not R.valid(button) then return end
        local state = I.state(button)
        if not state.normal then local c = button.BackgroundColor; state.normal = {R = c.R, G = c.G, B = c.B, A = c.A} end
        button:SetBackgroundColor(red and RED or state.normal)
    end
    local function paint()
        local game = {}   -- engine key name -> the game's slot buttons
        for _, entry in ipairs(entries) do
            if entry.mod == 'Witch It' and R.valid(entry.widget) then
                for index = 0, 1 do
                    local b = entry.widget['Binding_' .. index]
                    local key = I.string(b.icon.BoundKey.KeyName)
                    if key ~= '' and key ~= 'None' then game[key] = game[key] or {}; table.insert(game[key], b.Button) end
                end
            end
        end
        local conflicts, red = R.hotkey_conflicts(), {}
        for _, slot in ipairs(slots) do
            local chord = chordOf(slot)
            if slot.shown ~= chord then caption(slot, chord) end
            local keys = R.chord_keys(chord) or {}
            local clash = conflicts[slot.id] and conflicts[slot.id][slot.index]
            if #keys == 1 and game[keys[1]] then
                clash = true
                for _, b in ipairs(game[keys[1]]) do red[b:GetAddress()] = true end
            end
            tint(slot.button, clash)
        end
        for _, buttons in pairs(game) do for _, b in ipairs(buttons) do tint(b, red[b:GetAddress()]) end end
    end
    local function stop()
        if not waiting then return end
        waiting.release()
        if R.valid(waiting.slot.frame) then waiting.slot.frame:SetVisibility(2) end
        waiting = nil
    end
    local wait   -- (below: a slot waits for its key)
    R.post(LIST, function(list)
        stop()
        slots, list_id = {}, I.id(list)
        local grid = list.KeyBindingsGrid
        -- The game's own lines, in their order.
        entries = {}
        local game = {}
        for index = 0, grid:GetChildrenCount() - 1 do game[#game + 1] = grid:GetChildAt(index) end
        table.sort(game, function(a, b)
            if a.Slot.Row ~= b.Slot.Row then return a.Slot.Row < b.Slot.Row end return a.Slot.Column < b.Slot.Column end)
        for _, row in ipairs(game) do
            entries[#entries + 1] = {widget = row, visibility = row:GetVisibility(), mod = 'Witch It',
                name = I.string(row.BindingName:GetText()), keys = function() return bound(row) end}
        end
        -- The grid is uniform, two columns: after the game's last row, a heading starts a line of its
        -- own (left), the shortcuts under it two to a line as the game's rows.
        local last = grid:GetChildAt(grid:GetChildrenCount() - 1).Slot
        local row, column = last.Row + 1, 0
        local function placed(widget, heading)
            if heading and column == 1 then row, column = row + 1, 0 end
            -- A shortcut's row sits in its cell as the game's rows do.
            if not heading then
                widget.Slot:SetHorizontalAlignment(last.HorizontalAlignment)
                widget.Slot:SetVerticalAlignment(last.VerticalAlignment)
            end
            widget.Slot:SetRow(row)
            widget.Slot:SetColumn(column)
            if heading or column == 1 then row, column = row + 1, 0 else column = 1 end
            return widget
        end
        local rows = R.hotkeys()
        -- Per mod: its own shortcuts, then the game's keys it makes rebindable.
        table.sort(rows, function(a, b)
            if a.mod ~= b.mod then return a.mod < b.mod end
            if (a.game or false) ~= (b.game or false) then return not a.game end
            return a.id < b.id
        end)
        local mod, group, message
        local function heading(text, small, of)
            local w = placed((U.text(grid, {text = text, heading = true, note = small})), true)
            entries[#entries + 1] = {widget = w, visibility = w:GetVisibility(), heading = true, mod = mod, group = of}
        end
        for _, key in ipairs(rows) do
            if key.mod ~= mod then mod, group = key.mod, nil; heading(mod) end
            if key.game and group ~= 'game' then group = 'game'; heading("Game's own keys", true, 'game') end
            local shortcut = placed(I.cooked(grid, 'WB_KeyBinding', R.native.load_asset(ROW)))
            local id = key.id
            entries[#entries + 1] = {widget = shortcut, visibility = shortcut:GetVisibility(), mod = mod, name = key.label,
                group = key.game and 'game' or nil, keys = function() return chords(id) end}
            shortcut.BindingName:SetText(FText(key.label))
            shortcut.BindingName:SetToolTipText(FText((key.tip and key.tip .. '\n' or '') .. 'Works in: ' .. key.context))
            -- The line's message: after its slots.
            message = U.text(shortcut.BindingName:GetParent(), {text = '', note = true, wrap = false})
            message.Slot:SetVerticalAlignment(2)
            for index, chord in ipairs({key.current, key.spare}) do
                local button = shortcut['Binding_' .. (index - 1)]
                -- The key pictures side by side in the slot's button.
                local parts = StaticConstructObject(I.object('/Script/UMG.HorizontalBox'), I.owner(grid).screen.WidgetTree)
                button.Button:SetContent(parts)
                local size = button.WidgetTree.RootWidget
                local slot = {id = key.id, index = index, message = message,
                    button = button.Button, frame = button.WaitForInputFrame, icon = button.icon, parts = parts,
                    size = size, width = size.WidthOverride}
                caption(slot, chord)
                slots[#slots + 1] = slot
                U.on_press(slot.button, function() if not waiting then wait(slot) end end)
            end
        end
        paint()
        if query ~= '' then arrange() end
    end)
    -- The search row: Back, the search field, and what it searches by (bottom right).
    local SCREEN = '/Game/UserInterface/Settings/WB_KeyBindings.WB_KeyBindings_C'
    R.post(SCREEN .. ':Construct', function(screen)
        local state = I.state(screen)
        state.screen = screen
        if state.search then return end
        -- A new screen starts with no search, as the game's screens start.
        query, by = '', 'name'
        arrange()
        local back = screen.Button_Back
        local column = back:GetParent()
        local slot = I.slot_values(back.Slot)
        local bar = I.native(column, 'HorizontalBox')
        I.slot_apply(bar.Slot, slot)
        bar.Slot:SetHorizontalAlignment(0)
        back:RemoveFromParent(); bar:AddChild(back)
        back.Slot:SetVerticalAlignment(2)
        local field, set, frame = U.input(bar, {value = query, hint = 'Search', on_change = function(text)
            query = text; arrange()
        end})
        U.fill(frame)
        frame.Slot:SetPadding({Left = 24, Top = 0, Right = 24, Bottom = 0}); frame.Slot:SetVerticalAlignment(2)
        local kind = I.native(bar, 'SizeBox')
        kind:SetWidthOverride(260)
        kind.Slot:SetVerticalAlignment(2)
        U.combo(kind, {value = by, options = {{value = 'name', label = 'By name'}, {value = 'mod', label = 'By mod'},
            {value = 'key', label = 'By key'}}, on_change = function(value) by = value; arrange() end})
        state.search = {bar = bar, back = back, column = column, slot = slot, field = field}
    end)

    -- The slot takes a chord: the shortcut's own, or the reason it is refused in its name.
    local function take(slot, chord)
        stop()
        local ok, why = R.set_hotkey(slot.id, chord, slot.index)
        if ok then caption(slot, chord); paint() else slot.message:SetText(FText(why)) end
    end
    -- A click on a slot: it waits for a key (from the next press on: this click is not its key).
    -- A modifier waits for the key it goes with; let go alone, it is the chord itself (watched
    -- every frame while it is held).
    function wait(slot)
        stop()
        slot.message:SetText(FText(''))
        slot.frame:SetVisibility(3)
        waiting = {slot = slot, release = function() end}
        local function held(code)
            if not waiting or waiting.slot ~= slot or waiting.modifier ~= code then return end
            if R.native.key_down(code) then R.next_frame(function() held(code) end); return end
            take(slot, R.chord(code, 0))
        end
        R.next_frame(function()
            if not waiting or waiting.slot ~= slot then return end
            waiting.release = R.capture_hotkey(function(code, mask)
                if code == 1 or code == 2 or code == 4 or code == ESCAPE then stop(); return end
                if MODIFIERS[code] then
                    if not waiting.modifier then waiting.modifier = code; held(code) end
                    return
                end
                local chord = code == DELETE and 'Disabled' or R.chord(code, mask)
                if chord then take(slot, chord) end
            end)
        end)
    end
    -- The list leaves the screen: no slot waits any more. The screen goes: Back returns to its own
    -- place before the search row is removed with the screen.
    R.pre('/Script/UMG.UserWidget:Destruct', function(widget)
        if list_id and I.id(widget) == list_id then stop(); slots, list_id = {}, nil end
        local state = I.screens[I.id(widget)]
        local search = state and state.search
        if search and R.valid(search.back) then
            search.back:RemoveFromParent(); search.column:AddChild(search.back)
            I.slot_apply(search.back.Slot, search.slot)
            state.search = nil
        end
    end)
    R.on('world_end', function() stop(); slots, list_id = {}, nil end)
end
