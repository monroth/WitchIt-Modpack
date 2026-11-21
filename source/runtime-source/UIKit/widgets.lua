return function(R, C, U, I)
    local library = '/Script/UMG.Default__WidgetBlueprintLibrary'
    local owners, children, parents = {}, {}, {}
    -- After world_end, keep ownership only for widgets of screens that are still known.
    I.resets[#I.resets + 1] = function()
        local kept = {}
        for _, state in pairs(I.screens) do kept[state] = true end
        for id, state in pairs(owners) do
            if not kept[state] then owners[id], children[id], parents[id] = nil, nil, nil end
        end
        for parent, list in pairs(children) do
            for id in pairs(list) do if not owners[id] then list[id] = nil end end
            if next(list) == nil then children[parent] = nil end
        end
    end
    -- A widget's screen: the user widget its outers lead to, alive now (never one remembered: a screen
    -- can go without its Destruct reaching us and another take its address; live 11-19).
    function I.owner(parent)
        local node = parent
        while not node:IsA(I.object('/Script/UMG.UserWidget')) do node = node:GetOuter() end
        return I.state(node)
    end
    function I.attach(parent, widget)
        parent:AddChild(widget)
        return I.own(parent, widget)
    end
    function I.own(parent, widget)
        local id, state = I.id(widget), I.owner(parent)
        owners[id] = state
        state.widgets = state.widgets or {}
        state.widgets[id] = true
        local parent_id = I.id(parent)
        children[parent_id] = children[parent_id] or {}
        children[parent_id][id] = widget
        parents[id] = parent_id
        return widget
    end
    function I.remove(widget)
        if not R.valid(widget) then return end
        local id = I.id(widget)
        for _, child in pairs(children[id] or {}) do I.remove(child) end
        local state = owners[id]
        if state then state.actions[id], state.widgets[id] = nil, nil end
        if parents[id] and children[parents[id]] then children[parents[id]][id] = nil end
        I.actions[id], owners[id], children[id], parents[id] = nil, nil, nil, nil
        widget:RemoveFromParent()
    end
    I.destructors[#I.destructors + 1] = function(state)
        local roots={}
        -- (a widget of this screen whose record went with another screen's or the world's: not this one's
        -- to remove any more; live VM1 11-20, widgets.lua:51 after Key Bindings)
        for id in pairs(state.widgets or {}) do
            local list = children[parents[id]]
            if not state.widgets[parents[id]] and list and list[id] then roots[#roots+1]=list[id] end
        end
        for _,widget in ipairs(roots) do I.remove(widget) end
        for id in pairs(state.widgets or {}) do
            if parents[id] and children[parents[id]] then children[parents[id]][id] = nil end
            owners[id], children[id], parents[id] = nil, nil, nil
        end
    end
    function I.initial(parent, focused)
        local id = I.id(parent)
        if I.actions[id] and (not focused or parent:HasKeyboardFocus() or parent:HasFocusedDescendants()) then return parent,I.actions[id].initial end
        local first
        for _, child in pairs(children[id] or {}) do
            local found,preferred = I.initial(child, focused)
            if preferred then return found,true end
            first=first or found
        end
        return first
    end
    function I.native(parent, kind, name)
        local state = I.owner(parent)
        return I.attach(parent, StaticConstructObject(I.object('/Script/UMG.'..kind), state.screen.WidgetTree, name and FName(name)))
    end
    function I.cooked(parent, asset, class)
        local state = I.owner(parent)
        class = class or R.native.load_asset(I.path(asset, ''):sub(1, -2))
        local widget = I.object(library):Create(state.screen, class, state.screen:GetOwningPlayer())
        return I.attach(parent, widget)
    end
    -- A slot's place in its panel: padding, alignment, and the size of a box's slot (a scroll box's
    -- slot has none).
    local function sized(slot)
        return slot:IsA(I.object('/Script/UMG.VerticalBoxSlot')) or slot:IsA(I.object('/Script/UMG.HorizontalBoxSlot'))
    end
    function I.slot_values(slot)
        return {padding={Left=slot.Padding.Left,Top=slot.Padding.Top,Right=slot.Padding.Right,Bottom=slot.Padding.Bottom},
            size=sized(slot) and {Value=slot.Size.Value,SizeRule=slot.Size.SizeRule} or nil, horizontal=slot.HorizontalAlignment, vertical=slot.VerticalAlignment}
    end
    function I.slot_apply(slot, values)
        slot:SetPadding(values.padding)
        if values.size and sized(slot) then slot:SetSize(values.size) end
        slot:SetHorizontalAlignment(values.horizontal); slot:SetVerticalAlignment(values.vertical)
    end
    function I.focus(widget, screen)
        widget:SetUserFocus(screen:GetOwningPlayer())
        widget:SetKeyboardFocus()
    end
    local function label(widget, text, field)
        local value = FText(text or '')
        if field == 'Label' then widget.LabelText = value else widget.DescriptiveLabel = value end
        widget[field or 'DescriptiveLabelText']:SetText(value)
    end
    local function options(widget, opts)
        if opts.tooltip then widget:SetToolTipText(FText(opts.tooltip)) end
        if opts.enabled ~= nil then widget:SetIsEnabled(opts.enabled) end
    end
    I.options = options
    function U.text(parent, opts)
        local template = I.cooked(parent, 'WB_CheckBoxWithLabel')
        template:SetVisibility(1)
        -- A SizeBox accepts one child. Copy the attached cooked style before
        -- replacing its template, then attach the finished text to the empty slot.
        local widget = StaticConstructObject(I.object('/Script/UMG.TextBlock'), I.owner(parent).screen.WidgetTree)
        widget:SetFont(template.DescriptiveLabelText.Font)
        widget:SetColorAndOpacity(template.DescriptiveLabelText.ColorAndOpacity)
        -- A heading opens a group: room above it (set before the text reaches the screen).
        if opts.heading then widget.Margin = {Left = 0, Top = I.HEADING_GAP, Right = 0, Bottom = 0} end
        I.remove(template)
        I.attach(parent, widget)
        widget.WrapTextAt = opts.wrap == false and 0 or opts.width or 1000
        widget:SetAutoWrapText(opts.wrap ~= false)
        -- A heading: the name of the section under it, in the game's accent colour; like: as that text of
        -- the game's own looks (a section title of the screen it joins).
        if opts.like then
            widget:SetFont(opts.like.Font)
            widget:SetColorAndOpacity(opts.like.ColorAndOpacity)
            widget:SetShadowColorAndOpacity(opts.like.ShadowColorAndOpacity)
            widget:SetShadowOffset(opts.like.ShadowOffset)
        elseif opts.heading then
            widget:SetColorAndOpacity({SpecifiedColor = {R = .66, G = .47, B = 1, A = 1}, ColorUseRule = 0})
        end
        -- A note: smaller and dimmer, under the controls it explains.
        if opts.note then
            local font = widget.Font
            font.Size = math.floor(font.Size * .75)
            widget:SetFont(font)
            widget:SetColorAndOpacity({SpecifiedColor = {R = .62, G = .62, B = .68, A = 1}, ColorUseRule = 0})
        end
        widget:SetJustification(opts.like and opts.like.Justification or 0)
        local function set(value) widget:SetText(FText(value)) end
        set(opts.text or opts.label or '')
        options(widget, opts)
        return widget, set
    end
    function U.row(parent, widths)
        local row = I.native(parent, 'HorizontalBox')
        local cells = {}
        for index, width in ipairs(widths) do
            cells[index] = I.native(row, 'SizeBox')
            cells[index]:SetWidthOverride(width)
            cells[index]:SetClipping(1)
            cells[index].Slot:SetHorizontalAlignment(0);cells[index].Slot:SetVerticalAlignment(1)
        end
        return cells, row
    end
    function U.navigate(rows, scroll)
        for index, widget in ipairs(rows) do
            local record = I.record(widget)
            if record then record.scroll = scroll end
            for _, direction in ipairs({{2, rows[index-1]}, {3, rows[index+1]}}) do
                if direction[2] then
                    widget:SetNavigationRuleExplicit(direction[1], direction[2])
                    for _,key in ipairs({'FocusableWidget','CheckBox','ValueSlider','ButtonRef'}) do
                        local inner=widget[key]
                        if R.valid(inner) then inner:SetNavigationRuleExplicit(direction[1],direction[2]);break end
                    end
                end
            end
        end
    end
    function U.section(parent, opts)
        opts = opts or {}
        local widget = I.native(parent, 'VerticalBox')
        if opts.label then U.text(widget, {text = opts.label, heading = true}) end
        return widget, function(visible) widget:SetVisibility(visible and 0 or 1) end
    end
    -- The game's own scroll bars: the bar style of a scroll box of the game (its thumb drawn from a
    -- texture), looked for once a world; ours take it before they are drawn. None found: the engine's.
    local bars, bars_looked
    I.resets[#I.resets + 1] = function() bars, bars_looked = nil, false end
    local function game_bars()
        if bars_looked then return bars end
        bars_looked = true
        for _, box in ipairs(FindAllOf('ScrollBox') or {}) do
            if R.valid(box.WidgetBarStyle.NormalThumbImage.ResourceObject) then bars = box.WidgetBarStyle; break end
        end
        return bars
    end
    -- A scroll box with the game's bars.
    function I.scroll_box(parent)
        local widget = I.native(parent, 'ScrollBox')
        local style = game_bars()
        if style then widget.WidgetBarStyle = style end
        return widget
    end
    function U.scroll(parent, opts)
        opts = opts or {}
        if opts.height then
            parent = I.native(parent, 'SizeBox')
            parent:SetHeightOverride(opts.height)
        end
        local widget = I.scroll_box(parent)
        widget:SetAlwaysShowScrollbar(true)
        return widget, function(target)
            if target then widget:ScrollWidgetIntoView(target, true, 0, 0) else widget:ScrollToStart() end
        end
    end
    function I.caption(widget, value)
        label(widget, value, 'Label')
        if I.string(widget:GetClass():GetFName()) == 'WB_Button_C' then widget.Text = FText(value) end
    end
    function U.button(parent, opts)
        local widget = I.cooked(parent, 'WB_TabButton', opts.class)
        local function set(value) I.caption(widget, value) end
        set(opts.label)
        widget.Label:SetAutoWrapText(opts.wrap == true)
        options(widget, opts)
        I.action(widget, {click = opts.on_click})
        return widget, set
    end
    -- A checkbox row is of its screen's kind: the game's plain rows on Custom Match and the Creative
    -- host screen, rows with a reset button elsewhere (rules pages, Settings). The callers never
    -- choose. opts.columns (the label and the box at the two ends of a narrow row) and opts.box (the
    -- box alone, its label placed by the caller) are plain rows by their shape.
    local PLAIN_SCREENS = {WB_Custommatch_C = true, WB_CreativeGame_C = true}
    function U.checkbox(parent, opts)
        local plain = opts.columns or opts.box or PLAIN_SCREENS[I.string(I.owner(parent).screen:GetClass():GetFName())]
        local widget = I.cooked(parent, plain and 'WB_CheckBoxWithLabel' or 'WB_CheckBoxWithEditableLabel')
        label(widget, opts.box and '' or opts.label)
        if opts.columns then
            -- columns: the label and the box in a column each, the label at the left and the box at
            -- the right end, for a narrow row of its own (otherwise they share one grid cell and the
            -- label covers the box and takes its clicks); the label lets clicks through.
            local text = widget.DescriptiveLabelText
            text:SetAutoWrapText(false)
            text:SetVisibility(3)
            local cell = text:GetParent()
            cell:SetStretch(0)
            local grid = widget.CheckBox:GetParent()
            while cell:GetParent():GetAddress() ~= grid:GetAddress() do cell = cell:GetParent() end
            for column, part in ipairs({cell, widget.CheckBox}) do
                part.Slot:SetRow(0); part.Slot:SetColumn(column - 1); part.Slot:SetColumnSpan(1)
                part.Slot:SetHorizontalAlignment(column == 1 and 1 or 3); part.Slot:SetVerticalAlignment(2)
            end
            grid:SetColumnFill(0, 1); grid:SetColumnFill(1, 0); grid:SetColumnFill(2, 0)
        end
        widget.DefaultBoolValue = opts.default == nil and opts.value or opts.default
        options(widget, opts)
        local record = I.action(widget, {value = opts.value, change = opts.on_change})
        local function set(value)
            record.value = value
            widget:SetIsCheckedWithoutEvent(value)
        end
        set(opts.value)
        record.check = function()
            local value = widget.CheckBox:IsChecked()
            if value ~= record.value then
                record.value = value
                if record.change then record.change(value) end
            end
        end
        return widget, set
    end
    function U.slider(parent, opts)
        local lo, hi, step = opts.min, opts.max, opts.step or (opts.kind == 'int' and 1 or .1)
        local widget = I.cooked(parent, 'WB_SliderWithEditableLabel')
        label(widget, opts.label)
        widget.MinimumValue, widget.MaximumValue, widget.StepSize = lo, hi, step
        widget.bRoundToIntegers, widget.UIMultiplyFactor = opts.kind == 'int', 1
        widget.bTimeValueInSeconds, widget.ValueSuffix = false, FText(opts.suffix or '')
        local default = opts.default == nil and opts.value or opts.default
        widget.DefaultFloatValue = default == 'infinite' and hi or default
        widget.DefaultValueIndicator:SetValue((widget.DefaultFloatValue - lo) / (hi - lo))
        options(widget, opts)
        local record = I.action(widget, {value = opts.value})
        -- The slider covers the usual range; the field takes anything from input_min to input_max.
        local function shown()
            if record.value == 'infinite' then return '∞' end
            return (string.format('%.2f', record.value):gsub('%.?0+$', ''))
        end
        local function paint()
            record.painting = true
            widget:SetRealValue(record.value == 'infinite' and hi or math.max(lo, math.min(hi, record.value)))
            widget:CheckDefaultToUpdateUI()
            widget.InputField:SetText(FText(shown()))
            record.painting = false
        end
        local function parse(value, dragging)
            if opts.infinite and (value == 'infinite' or tostring(value):lower():match('^%s*inf%s*$') or value == '∞') then return 'infinite' end
            local number = tonumber(value)
            if not number or number ~= number or math.abs(number) == math.huge then return end
            if dragging then
                number = math.max(lo, math.min(hi, lo + math.floor((number - lo) / step + .5) * step))
                if opts.infinite and number >= hi then return 'infinite' end
            end
            if number < (opts.input_min or lo) or number > (opts.input_max or hi) then return end
            if opts.kind == 'int' and number % 1 ~= 0 then return end
            return number
        end
        local function set(value) record.value = value; paint() end
        record.edit = function(value, dragging)
            local parsed = parse(value, dragging)
            if parsed ~= nil and parsed ~= record.value then
                record.value = parsed
                if opts.on_change then opts.on_change(parsed) end
                if opts.on_commit then opts.on_commit(parsed) end
            end
            paint()
        end
        record.slide = function(value) record.edit(lo + (hi - lo) * value, true) end
        record.drag = function() record.edit(widget.RealValue, true) end
        record.commit = function(text) record.edit(I.string(text), false) end
        record.reset = function() record.edit(default, false) end
        record.repaint = function()
            if not widget.InputField:HasFocusedDescendants() then
                widget.InputField:SetText(FText(shown()))
            end
        end
        paint()
        return widget, set
    end
    function U.combo(parent, opts)
        local widget = I.cooked(parent, 'WB_ComboBoxWithLabel')
        local texts, indices = {}, {}
        for index, option in ipairs(opts.options) do
            texts[index], indices[option.value] = FText(option.label), index - 1
        end
        I.array(widget.Options, texts)
        label(widget, opts.label)
        -- No label: the choice alone fills the control (the game's grid: label, choice, end).
        if not opts.label then
            widget.DescriptiveLabelText:GetParent():SetVisibility(1)
            local grid = widget.ComboboxSizeSwitcher:GetParent()
            grid:SetColumnFill(0, 0); grid:SetColumnFill(1, 1); grid:SetColumnFill(2, 0)
        end
        options(widget, opts)
        local record = I.action(widget, {value = opts.value})
        local function set(value)
            record.value = value
            widget:SetOptionIndex(indices[value])
        end
        record.select = function()
            local option = opts.options[widget.SelectedOptionIndex + 1]
            if option.value ~= record.value then
                record.value = option.value
                if opts.on_change then opts.on_change(option.value) end
            end
        end
        record.show = function() widget:SetOptionIndex(indices[record.value]) end
        set(opts.value)
        return widget, set
    end
    -- A combo shown again (its screen cached by the game) starts at its first option: it shows its value.
    R.post(I.path('WB_ComboBoxWithLabel', 'Construct'), function(widget)
        local record = I.record(widget)
        if record and record.show then record.show() end
    end)
    -- A row whose controls take the width of their text.
    function U.flow(parent) return I.native(parent, 'HorizontalBox') end
    -- A widget added to anchor's panel goes right after anchor: the children after anchor move
    -- behind it, each keeping its slot (a vertical or horizontal box only appends).
    -- The children after anchor (and anchor too: with) move, slots kept, to the end of into (default
    -- their parent), except one: what was added last comes before them.
    function I.move_after(anchor, into, except, with)
        local parent, after, found = anchor:GetParent(), {}, false
        for _, child in ipairs(I.values(parent:GetAllChildren())) do
            if with and I.id(child) == I.id(anchor) then found = true end
            if found and not (except and I.id(child) == I.id(except)) then after[#after + 1] = {widget = child, slot = I.slot_values(child.Slot)} end
            if I.id(child) == I.id(anchor) then found = true end
        end
        into = into or parent
        for _, moved in ipairs(after) do
            moved.widget:RemoveFromParent(); into:AddChild(moved.widget); I.slot_apply(moved.widget.Slot, moved.slot)
        end
        return after
    end
    function U.place_after(widget, anchor) I.move_after(anchor, nil, widget) end
    -- The menu screen the menu manager shows for a menu state (number).
    function I.menu_screen(manager, state)
        local screen
        manager.MenuStateWidgets:ForEach(function(key, value) if key:get() == state then screen = value:get() end end)
        return R.valid(screen)
    end
    -- The row's main cell takes the remaining width (a name before its buttons); what does not fit
    -- is cut at its edge, not drawn under the buttons.
    function U.fill(widget) widget.Slot:SetSize({SizeRule = 1, Value = 1}); widget:SetClipping(1); return widget end
    R.post(I.path('WB_BaseControl', 'OnFocusReceived'), function(widget)
        local record = I.record(widget)
        if not record then return end
        if record.scroll then record.scroll:ScrollWidgetIntoView(widget, true, 0, 0) end
    end)
    U.remove=I.remove
end
