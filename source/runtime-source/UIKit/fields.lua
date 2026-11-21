-- Text fields that tell their changes, in the game's search bar look (U.input).
-- A watched field's value is looked at after each key press or click (typing ends with Enter or a
-- click elsewhere) and a change is told once; nothing is looked at otherwise. Kits with fields of
-- their own watch them the same way (I.watch, I.check_fields, I.search_look).
return function(R, C, U, I)
    local library = '/Script/UMG.Default__WidgetBlueprintLibrary'
    local ENTER = R.codes.ENTER
    -- widget -> {read, last, on_change}; dropped when the widget is gone (not a weak table: each UObject
    -- comes as a new userdata, a weak key goes at the next collection, user 11-20 colour picker)
    local watched = {}
    function I.watch(widget, read, on_change)
        if on_change then watched[widget] = {read = read, last = read(), on_change = on_change} end
    end
    function I.check_fields()
        for widget, field in pairs(watched) do
            if R.valid(widget) then
                local value = field.read()
                if value ~= field.last then field.last = value; field.on_change(value) end
            else
                watched[widget] = nil
            end
        end
    end
    local entered   -- (when an Enter last ended typing in a mod's field)
    R.native.on_input(function(code)
        if next(watched) == nil then return end
        R.next_frame(I.check_fields)
        -- Typing ends with Enter: the keyboard goes back to the game.
        if code == ENTER then
            for widget in pairs(watched) do
                if R.valid(widget) and (widget:HasAnyUserFocus() or widget:HasFocusedDescendants()) then
                    I.object(library):SetFocusToGameViewport()
                    entered = true
                    R.after(300, function() entered = false end)   -- (only that press: its chat event comes at once)
                    break
                end
            end
        end
    end)
    -- The Enter that ended typing in a mod's field is that field's: it does not open the game's chat as well
    -- (user 11-21; the game types a chat message on Enter - B_PlayerController's TypeChatMessage, found by a probe).
    R.pre('/Game/Blueprints/Player/B_PlayerController.B_PlayerController_C:TypeChatMessage', function()
        if entered then entered = false; return true end
    end)
    -- The game's search bar look for a field: its frame (a border, put into parent) and its
    -- field's style with the font of the labels around it. The templates go before anything
    -- takes their place (a size box holds one child).
    function I.search_look(parent)
        local bar = I.cooked(parent, 'WB_SearchBar')
        bar:SetVisibility(1)
        local style, look = bar.TextField.WidgetStyle, bar.WidgetTree.RootWidget
        local brush, padding = look.Background, look.Padding
        I.remove(bar)
        local labels = I.cooked(parent, 'WB_CheckBoxWithLabel')
        local font = labels.DescriptiveLabelText.Font
        I.remove(labels)
        local frame = I.native(parent, 'Border')
        frame:SetBrush(brush)
        frame:SetPadding(padding)
        return frame, style, font
    end
    -- A text field: the game's search bar field in its frame (as tall as a button); returns the
    -- field, set(text) and the frame. opts: value, hint, on_change(text), initial (takes the focus
    -- first), tooltip, enabled.
    function U.input(parent, opts)
        local widget = StaticConstructObject(I.object('/Script/UMG.EditableTextBox'), I.owner(parent).screen.WidgetTree)
        local frame, style, font = I.search_look(parent)
        style.TextStyle.Font = font   -- (this engine keeps a field's font in its text style)
        widget.WidgetStyle = style
        I.attach(frame, widget)
        widget:SetHintText(FText(opts.hint or ''))
        local function read() return I.string(widget:GetText()) end
        local function set(value) widget:SetText(FText(value)); I.watch(widget, read, opts.on_change) end
        set(opts.value or '')
        I.options(widget, opts)
        local id, state = I.id(widget), I.owner(widget)
        I.actions[id] = {widget = widget, initial = opts.initial}; state.actions[id] = true
        return widget, set, frame
    end
end
