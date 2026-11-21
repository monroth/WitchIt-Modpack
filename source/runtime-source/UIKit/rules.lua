-- Every mod's rules (C.rules) where they belong, under the mod's name: on the game's Match page
-- (General, Hunters, Witches), on an ability's or a power-up's page, or on the mod's own rules tab.
-- They show the rules the screens show (C.rules.shown) and can be changed while C.rules.editable();
-- in a vanilla session they are hidden (mods' rules do not apply there).
--   U.rule_rows(parent, pkg, keys)  the rows of some rules of a mod, for a screen of its own (rows
--                                   of that screen's kind); returns its controls and a repaint function
--   U.match_column(w, after)        the Custom Match screen's second column (w: the screen), beside
--                                   the rows below its widget named after (default Slider_WitchLives)
--   U.match_rows(pkg, keys, selected, after)  a mod's rules in such a column, shown while
--                                   selected(options) holds for the options the screen edits
return function(R, C, U, I)
    local RULEUI = '/Game/UserInterface/Play/GameRules/'
    -- The mods' rule tabs can be changed when the rules can (the host, or a guest's own rules).
    U.rules_view(function() return C.rules.editable() end)
    local TABS = RULEUI .. 'WB_GameRulesTabs.WB_GameRulesTabs_C'

    local function row(parent, pkg, spec)
        local function change(value) C.rules.set(pkg, spec.key, value) end
        if spec.kind == 'bool' then
            return U.checkbox(parent, {label = spec.label, tooltip = spec.help,
                value = C.rules.shown(pkg, spec.key), default = spec.initial, on_change = change})
        elseif spec.kind == 'number' then
            return U.slider(parent, {label = spec.label, tooltip = spec.help, min = spec.sliderMin or spec.min,
                max = spec.sliderMax or spec.max, step = spec.step, kind = spec.integer and 'int' or nil,
                input_min = spec.min or -math.huge, input_max = spec.max or math.huge, infinite = spec.infinite,
                default = spec.initial, value = C.rules.shown(pkg, spec.key), on_commit = change})
        end
    end
    -- Rows of a mod's rules; paint() shows the current values and whether they can be changed.
    function U.rule_rows(parent, pkg, keys)
        local controls, setters = {}, {}
        local wanted = {}
        for _, key in ipairs(keys) do wanted[key] = true end
        for _, spec in ipairs(C.rules.specs(pkg)) do
            if wanted[spec.key] then
                local widget, set = row(parent, pkg, spec)
                if widget then controls[#controls + 1] = widget; setters[spec.key] = set end
            end
        end
        local function paint()
            for key, set in pairs(setters) do set(C.rules.shown(pkg, key)) end
            for _, widget in ipairs(controls) do if R.valid(widget) then widget:SetIsEnabled(C.rules.editable()) end end
        end
        return controls, paint
    end

    -- The rules of every mod for a place, in the order the mods declared them.
    local function rulesAt(place)
        local out = {}
        for _, pkg in ipairs(C.rules.packages()) do
            local keys = {}
            for _, spec in ipairs(C.rules.specs(pkg)) do if spec.page == place then keys[#keys + 1] = spec.key end end
            if #keys > 0 then out[#out + 1] = {pkg = pkg, keys = keys} end
        end
        return out
    end
    -- A list of the game's pages gets our rows once per place (a skill page reuses its list for
    -- every skill: other rows replace them).
    local built = {}   -- list address -> {place, widgets, paints}
    local function show(b)
        local vanilla = C.session().mode == 'vanilla'
        for _, w in ipairs(b.widgets) do if R.valid(w) then w:SetVisibility(vanilla and 1 or 0) end end
        if not vanilla then for _, paint in ipairs(b.paints) do paint() end end
    end
    -- (title: the game's own section title over the list; the mods' headings look like it. ref: the
    -- page's first section (Global: its title and list), seen as the page opens; every section's names
    -- end where its title ends)
    local function place(list, where, title, ref)
        if not (list and R.valid(list)) then return end
        local key = list:GetAddress()
        local b = built[key]
        local first = b and b.widgets[1]
        local parent = first and R.valid(first) and first:GetParent()
        if not (b and b.place == where and parent and R.valid(parent) and parent:GetAddress() == key) then
            if b then for _, w in ipairs(b.widgets) do U.remove(w) end end
            b = {place = where, widgets = {}, paints = {}}
            built[key] = b
            for _, group in ipairs(rulesAt(where)) do
                -- (on one line, its right edge where the game's title ends, as "Global" and "Hunters" stand;
                -- live 11-20: a column measured before it was drawn was narrow, the name broke in three lines
                -- at the left edge)
                local holder = list
                if title then
                    holder = I.native(list, 'SizeBox')
                    holder.Slot:SetHorizontalAlignment(1)   -- (left)
                    -- (measured on the first section: a section below the page's fold has no size until it
                    -- is scrolled to, live 11-20: under Witches the subtitle stayed at the left edge; the
                    -- title is drawn a few frames after the page fills: tried each frame until it is)
                    local tries = 0
                    local function fit()
                        if not (R.valid(holder) and R.valid(ref.title) and R.valid(ref.list)) then return end
                        local t, l = R.native.widget_rect(ref.title), R.native.widget_rect(ref.list)
                        if t.right > t.left and l.right > l.left then holder:SetWidthOverride(t.right - l.left); return end
                        tries = tries + 1
                        if tries < 60 then R.next_frame(fit) end
                    end
                    fit()
                end
                local heading = U.text(holder, {text = R.mod_name(group.pkg), heading = true, like = title, wrap = false})
                if title then
                    -- (a subtitle under the game's section title: its colour and font, smaller; user 11-20)
                    heading:SetJustification(2)   -- (ETextJustify::Right)
                    local font = heading.Font
                    font.Size = math.floor(font.Size * .6)
                    heading:SetFont(font)
                end
                b.widgets[#b.widgets + 1] = holder ~= list and holder or heading
                local controls, paint = U.rule_rows(list, group.pkg, group.keys)
                for _, w in ipairs(controls) do b.widgets[#b.widgets + 1] = w end
                b.paints[#b.paints + 1] = paint
            end
        end
        -- (live 11-20 a guest's skill page had none of the mods' rows: which rows a page got, and the mode)
        C.state('UIKit', 'Rules page ' .. tostring(where), C.session().mode == 'vanilla' and 'mods\' rules hidden - a vanilla session'
            or ('mods with rules here: %d'):format(#rulesAt(where)))
        show(b)
    end
    C.rules.on_change(function()
        for _, b in pairs(built) do if b.widgets[1] and R.valid(b.widgets[1]) then show(b) end end
    end)
    -- (the section titles are in the page's tree but no variables of it: found by name in the tree, as
    -- the game names them; read as properties they were nothing, and their font crashed the game, VM2 11-19)
    local function titles(w)
        local found, panel = {}, I.object('/Script/UMG.PanelWidget')
        local function walk(widget)
            found[widget:GetFName():ToString()] = widget
            if widget:IsA(panel) then for _, child in ipairs(I.values(widget:GetAllChildren())) do walk(child) end end
        end
        walk(w.WidgetTree.RootWidget)
        return found
    end
    R.post(RULEUI .. 'WB_MatchRules.WB_MatchRules_C:RefreshMatchRules', function(w)
        local t = titles(w)
        local ref = {title = t.GlobalText, list = w.GlobalSliderList}
        place(w.GlobalSliderList, 'general', t.GlobalText, ref)
        place(w.HunterSliderList, 'hunters', t.HunterText, ref)
        place(w.WitchSliderList, 'witches', t.WitchText, ref)
    end)
    R.post(RULEUI .. 'SkillRules/WB_SkillRules.WB_SkillRules_C:RefreshSkillRuleUI', function(w)
        place(w.ParamSliderList, 'skill:' .. tostring(w.CurrentSkillType))
    end)
    R.post(RULEUI .. 'PowerupRules/WB_PowerupConfigure.WB_PowerupConfigure_C:RefreshPowerupUI', function(w)
        place(w.ParamSliderList, 'powerup:' .. tostring(w.CurrentPowerupType))
    end)
    -- The game's reset buttons reset the mods' rules too: Reset all every rule, a skill's or a power-up's
    -- page its own (not on a vanilla server: the mods' rules do not apply there).
    local function reset(page)
        if C.session().mode ~= 'vanilla' then R.log('UIKit', 'Reset rules: %s', page or 'all'); C.rules.reset(page)
        else R.log('UIKit', 'Reset rules of the mods skipped: a vanilla session') end
    end
    R.post(TABS .. ':ResetAllToDefault', function() reset(nil) end)
    R.post(RULEUI .. 'SkillRules/WB_SkillRules.WB_SkillRules_C:BndEvt__WB_SkillRules_Button_Reset_K2Node_ComponentBoundEvent_1_Clicked__DelegateSignature',
        function(w) reset('skill:' .. tostring(w.CurrentSkillType)) end)
    R.post(RULEUI .. 'PowerupRules/WB_PowerupConfigure.WB_PowerupConfigure_C:BndEvt__WB_ModConfigure_Button_Reset_K2Node_ComponentBoundEvent_1_Clicked__DelegateSignature',
        function(w) reset('powerup:' .. tostring(w.CurrentPowerupType)) end)
    -- A mod with rules for its own tab gets one, named after it.
    C.rules.on_declare(function(pkg, specs)
        local keys = {}
        for _, spec in ipairs(specs) do if spec.page == 'tab' then keys[#keys + 1] = spec.key end end
        if #keys == 0 then return end
        U.rules_tab(TABS, function(parent, scroll)
            local controls, paint = U.rule_rows(parent, pkg, keys)
            U.navigate(controls, scroll)
            return paint
        end, {label = R.mod_name(pkg)})
    end)
    -- The Custom Match screen's second column: at the right of the game's rows below a row (Witch
    -- Lives unless named), from the top; one per row it starts at. The game's rows below stand in a first column from then on, in every mode (as
    -- wide as before, they look as they did; a change of mode moves none of them). The column itself
    -- takes no clicks: the rows of the mode chosen do.
    local CUSTOM = '/Game/UserInterface/Play/WB_Custommatch.WB_Custommatch_C:'
    local columns = {}
    function U.match_column(w, after)
        after = after or 'Slider_WitchLives'
        local id = w:GetAddress() .. after
        if columns[id] and R.valid(columns[id]) then return columns[id] end
        local anchor = w[after]
        local parent = anchor:GetParent()
        local overlay = I.native(parent, 'Overlay'); U.place_after(overlay, anchor)
        local left, right = I.native(overlay, 'VerticalBox'), I.native(overlay, 'SizeBox')
        -- (alignments: 0 fill, 1 left or top, 3 right)
        left.Slot:SetHorizontalAlignment(0); left.Slot:SetVerticalAlignment(1)
        right:SetWidthOverride(700); right.Slot:SetHorizontalAlignment(3); right.Slot:SetVerticalAlignment(1)
        local column = I.native(right, 'VerticalBox')
        right:SetVisibility(4); column:SetVisibility(4)   -- (self hit-test invisible: their rows take clicks)
        I.move_after(overlay, left)
        columns[id] = column
        return column
    end
    function U.match_rows(pkg, keys, selected, after)
        local views = {}
        local function show(w)
            local id = w:GetAddress()
            local view = views[id]
            if not (view and R.valid(view.box)) then
                local box = I.native(U.match_column(w, after), 'VerticalBox')
                local controls, paint = U.rule_rows(box, pkg, keys)
                U.navigate(controls)
                view = {box = box, paint = paint}; views[id] = view
            end
            local on = selected(w.NextMatchOptions)
            C.state('UIKit', 'Custom Match rules of ' .. tostring(pkg), on and 'shown' or 'hidden - another mode is chosen')
            view.box:SetVisibility(on and 0 or 1)
            if on then view.paint() end
        end
        for _, method in ipairs({'Construct', 'LoadCustomMatchOptions', 'UpdateWidgetVisibility', 'UpdateLayoutComboBox',
            'BndEvt__ComboBox_GameMode_K2Node_ComponentBoundEvent_0_OnSelectionChanged__DelegateSignature'}) do
            R.post(CUSTOM .. method, show)
        end
    end
end
