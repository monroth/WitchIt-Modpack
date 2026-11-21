-- The controls of a window: the game's controls made compact (a button hugs its caption), a
-- switch, a number field in the game's search bar frame, and a choice that opens over the window.
-- Fields tell their changes (on_change).
return function(R, C, U, I, W)
    local LEFT_BUTTON = R.codes.LEFT_MOUSE
    -- A button hugs its caption: a smaller caption and little room around it, in the game's frame.
    local FONT, PAD = 19, {Left = 10, Top = 4, Right = 10, Bottom = 4}
    function W.button(parent, opts)
        local widget, set = U.button(parent, opts)
        local font = widget.Label.Font
        font.Size = FONT
        widget.Label:SetFont(font)
        widget.Label:GetParent().Slot:SetPadding(PAD)
        return widget, set
    end
    -- A switch: a game button that shows its state the way the game shows an active tab. A click
    -- turns it; opts: label, value, on_change(value), wrap, tooltip, enabled. set(value, label)
    -- changes both quietly.
    function W.toggle(parent, opts)
        local value = opts.value == true
        local widget, caption
        widget, caption = W.button(parent, {label = opts.label, tooltip = opts.tooltip, enabled = opts.enabled, wrap = opts.wrap, on_click = function()
            value = not value
            widget:SetActiveState(value)
            if opts.on_change then opts.on_change(value) end
        end})
        widget:SetActiveState(value)
        return widget, function(on, label)
            value = on == true
            widget:SetActiveState(value)
            if label then caption(label) end
        end
    end

    W.picture = R.picture   -- (a picture from a PNG file: the runtime's)
    -- An icon button: the game's button with a picture instead of a caption, lit like an active
    -- tab while on. opts: image (a texture), size (px, default 30), tooltip, on_click, active.
    -- set(on) lights it or not; its picture (an Image) third.
    function W.icon(parent, opts)
        local widget = W.button(parent, {label = '', tooltip = opts.tooltip, on_click = opts.on_click})
        local tree = I.owner(parent).screen.WidgetTree
        local box = StaticConstructObject(I.object('/Script/UMG.SizeBox'), tree)
        box:SetWidthOverride(opts.size or 30); box:SetHeightOverride(opts.size or 30)
        local image = StaticConstructObject(I.object('/Script/UMG.Image'), tree)
        if opts.image then image:SetBrushFromTexture(opts.image, false) end
        box:SetContent(image)
        widget.MyButton:SetContent(box)
        widget:SetActiveState(opts.active == true)
        return widget, function(on) widget:SetActiveState(on == true) end, image
    end
    -- A row of a form: its label in a column of one width, right-aligned, then the value cell
    -- (returned; it takes the rest of the row).
    local LABEL_WIDTH = 150
    function W.row(parent, label, tooltip)
        local row = I.native(parent, 'HorizontalBox')
        local cell = I.native(row, 'SizeBox')
        cell:SetWidthOverride(LABEL_WIDTH)
        local text = U.text(cell, {text = label or '', wrap = false, tooltip = tooltip})
        text:SetJustification(2)   -- ETextJustify::Right
        text.Slot:SetHorizontalAlignment(3); text.Slot:SetVerticalAlignment(2)
        local value = U.fill(I.native(row, 'HorizontalBox'))
        value.Slot:SetPadding({Left = 10, Top = 1, Right = 0, Bottom = 1})
        return value
    end
    -- One of a few: game buttons side by side, the chosen one lit. opts: options {label, value},
    -- value, on_change(value). set(value) lights another quietly.
    function W.segments(parent, opts)
        local row, buttons = I.native(parent, 'HorizontalBox'), {}
        local value = opts.value
        local function paint() for v, b in pairs(buttons) do b:SetActiveState(v == value) end end
        for _, o in ipairs(opts.options) do
            buttons[o.value] = U.fill((W.button(row, {label = o.label, tooltip = o.tooltip, on_click = function()
                if o.value == value then return end
                value = o.value; paint()
                if opts.on_change then opts.on_change(o.value) end
            end})))
        end
        paint()
        return row, function(v) value = v; paint() end
    end

    -- Fields tell their changes (opts.on_change(value)) the way UIKit's do (I.watch); a number
    -- field is also looked at every frame while the mouse drags it.
    local watch = I.watch
    W.check_fields = I.check_fields
    W.numbers = {}   -- the number fields (widget -> true; dropped when gone; not weak: see UIKit fields)
    local dragging = false
    local function follow()
        -- (a failing look ends the drag too: audit 11-20, it left the field never polled again)
        local ok, err = pcall(W.check_fields)
        if ok and R.native.key_down(LEFT_BUTTON) then R.next_frame(follow) else dragging = false end
        if not ok then error(err, 0) end
    end
    -- A number field (the engine's spin box) in the search bar's frame: drag it sideways to change
    -- the value, click it to type one, the wheel over it steps it (window.lua). It tells changes
    -- like the text fields; the spin box's own events are engine delegates Lua cannot bind.
    -- opts: value, step (default 1), min, max, digits (after the point, default 0), tint {R,G,B}
    -- (the fill while dragging; default the heading colour), on_change(value), plain (the number on the
    -- right and no corner arrows: Tools 5's fields, prototype2.html - user 11-20), unit (its unit inside
    -- the field, after the number).
    function W.number(parent, opts)
        local frame, style, font = I.search_look(parent)
        local widget = StaticConstructObject(I.object('/Script/UMG.SpinBox'), I.owner(parent).screen.WidgetTree)
        -- (Its font and style go in before it reaches a window on screen: set later, they stay unseen.)
        widget.Font = font
        -- As wide as its longest value and a margin (the spin box alone is as wide as nothing).
        local function shown(v) return string.format('%.'..(opts.digits or 0)..'f', v) end
        widget.MinDesiredWidth = (math.max(#shown(opts.max or 999), #shown(opts.min or 0)) + 2) * font.Size * .6
        local clear, tint = {R = 0, G = 0, B = 0, A = 0}, opts.tint or {R = .66, G = .47, B = 1}
        local spin = widget.WidgetStyle
        for _, brush in ipairs({'BackgroundBrush', 'HoveredBackgroundBrush', 'ActiveBackgroundBrush', 'InactiveFillBrush'}) do
            spin[brush].TintColor = {SpecifiedColor = clear, ColorUseRule = 0}
        end
        for _, brush in ipairs({'ActiveFillBrush', 'HoveredFillBrush'}) do
            spin[brush].TintColor = {SpecifiedColor = {R = tint.R, G = tint.G, B = tint.B, A = .35}, ColorUseRule = 0}
        end
        spin.ForegroundColor = style.ForegroundColor
        if opts.plain then
            spin.ArrowsImage.TintColor = {SpecifiedColor = clear, ColorUseRule = 0}
            widget.Justification = 2
        end
        widget.WidgetStyle = spin
        widget:SetForegroundColor(style.ForegroundColor)
        if opts.unit then
            -- (the field holds the number and its unit: the number leaves the unit room on its right)
            local inside = I.native(frame, 'Overlay')
            I.attach(inside, widget)
            widget.Slot:SetHorizontalAlignment(0); widget.Slot:SetVerticalAlignment(2)
            widget.Slot:SetPadding({Left = 0, Top = 0, Right = 6 + font.Size * .6 * #opts.unit, Bottom = 0})
            local unit = StaticConstructObject(I.object('/Script/UMG.TextBlock'), I.owner(parent).screen.WidgetTree)
            unit.Font = font
            I.attach(inside, unit)
            unit:SetText(FText(opts.unit)); unit:SetColorAndOpacity(style.ForegroundColor)
            unit.Slot:SetHorizontalAlignment(3); unit.Slot:SetVerticalAlignment(2)
        else I.attach(frame, widget) end
        widget:SetDelta(opts.step or 1)
        widget:SetAlwaysUsesDeltaSnap(false)
        widget:SetMinFractionalDigits(0)
        widget:SetMaxFractionalDigits(opts.digits or 0)
        if opts.min then widget:SetMinValue(opts.min) end
        if opts.max then widget:SetMaxValue(opts.max) end
        local function read() return widget:GetValue() end
        -- (Set without a change: the field keeps a 32-bit float, read back as it is kept.)
        local function set(value) widget:SetValue(value); watch(widget, read, opts.on_change) end
        set(opts.value or 0)
        I.options(widget, opts)
        W.numbers[widget] = true
        -- (a press on it: its value is looked at each frame while the mouse drags it)
        U.on_press(widget, function() if not dragging then dragging = true; R.next_frame(follow) end end)
        return widget, set
    end
    -- A list of rows by key: set(items) builds only the rows new to it, takes out the rows gone and
    -- has each kept row change itself (row.update(item)); the rows stand in the items' order. Nothing
    -- else in the window is built again. opts: key(item), build(box, item) -> row {update(item)}.
    function W.list(parent, opts)
        local box = I.native(parent, 'VerticalBox')
        local rows, order = {}, {}
        local list = {}
        function list.set(items)
            local wanted, seen = {}, {}
            for _, item in ipairs(items) do
                local key = opts.key(item)
                wanted[#wanted + 1], seen[key] = key, true
                local r = rows[key]
                if r and R.valid(r.holder) then
                    if r.row.update then r.row.update(item) end
                else
                    local holder = I.native(box, 'SizeBox')
                    rows[key] = {holder = holder, row = opts.build(holder, item) or {}}
                end
            end
            for key, r in pairs(rows) do
                if not seen[key] then I.remove(r.holder); rows[key] = nil end
            end
            local same = #wanted == #order
            for i = 1, #wanted do if not same then break end; same = wanted[i] == order[i] end
            if not same then
                -- (the kept rows move, not built again)
                box:ClearChildren()
                for _, key in ipairs(wanted) do box:AddChild(rows[key].holder) end
            end
            order = wanted
        end
        return box, list
    end
    -- Hover: fn(true) when the mouse comes over a widget, fn(false) when it leaves. While such a
    -- widget is shown the mouse's place is read each frame; the widgets are asked only when it moved.
    local hovers = {}   -- {widget, fn, on} (a list: a weak table loses its keys, each UObject comes as a new userdata)
    local watching, last = false, nil
    local function look()
        local player, any = R.valid(C.session().pc), false
        if player then
            local m = I.object('/Script/UMG.Default__WidgetLayoutLibrary'):GetMousePositionOnViewport(player)
            local moved = not last or m.X ~= last.X or m.Y ~= last.Y
            last = {X = m.X, Y = m.Y}
            for i = #hovers, 1, -1 do if not R.valid(hovers[i].widget) then table.remove(hovers, i) end end
            for _, h in ipairs(hovers) do
                do
                    any = true
                    if moved then
                        local on = h.widget:IsHovered()
                        if on ~= h.on then h.on = on; h.fn(on) end
                    end
                end
            end
        end
        if any then R.next_frame(look) else watching, last = false, nil end
    end
    function W.on_hover(widget, fn)
        hovers[#hovers + 1] = {widget = widget, fn = fn, on = false}
        if not watching then watching = true; R.next_frame(look) end
    end
    -- A choice: a game button showing the value; a click opens the options right under it as game
    -- buttons, the chosen one lit, over the window on the window's own canvas (nothing below moves).
    -- The game's combo box opens its list on the game's own screen, under any window and behind a
    -- backdrop. A pick, the button again or a press anywhere else closes it.
    -- opts: label (beside it, in the left half), options {label, value}, value, on_change(value);
    -- image, size, tooltip, list_width: a picture button instead (below).
    local opened   -- the choice whose options are showing: {close, list, head}
    function W.choice(parent, opts)
        local row = I.native(parent, 'HorizontalBox')
        if opts.label then U.fill(U.text(row, {text = opts.label, wrap = false})) end
        local column = U.fill(I.native(row, 'VerticalBox'))
        local screen = I.owner(column).screen
        local value, list, caption, head = opts.value, nil, nil, nil
        local function name(v)
            for _, o in ipairs(opts.options) do if o.value == v then return o.label end end
            return tostring(v)
        end
        local function set(v) value = v; caption(name(v)) end
        local function close()
            if list then I.remove(list); list = nil end
            if opened and opened.close == close then opened = nil end
        end
        local function open()
            -- Under the button, as wide as it or as its longest option (a button that hugs a short
            -- value), at the window's scale (the button's drawn height over its own; its width may be
            -- stretched).
            local rect = R.native.widget_rect(head)
            head:ForceLayoutPrepass()
            local scale = (rect.bottom - rect.top) / head:GetDesiredSize().Y
            local width = opts.image and (opts.list_width or 260) * scale or rect.right - rect.left
            list = I.native(screen.WidgetTree.RootWidget, 'ScaleBox')
            list:SetStretch(7)   -- EStretch::UserSpecified
            list:SetUserSpecifiedScale(scale)
            list.Slot:SetAutoSize(true)
            list.Slot:SetPosition({X = rect.left, Y = rect.bottom})
            local sized = I.native(list, 'SizeBox')
            sized:SetMinDesiredWidth(width / scale)
            local options = I.native(sized, 'VerticalBox')
            for _, o in ipairs(opts.options) do
                local option = W.button(options, {label = o.label, on_click = function()
                    close()
                    if o.value ~= value then set(o.value); if opts.on_change then opts.on_change(o.value) end end
                end})
                option:SetActiveState(o.value == value)
            end
            if opened then opened.close() end
            opened = {close = close, list = list, head = head}
        end
        -- (opts.image: a small picture button instead of the value - lit while not the first option -,
        -- its tooltip the value; the options as wide as opts.list_width)
        if opts.image then
            local light
            head, light = W.icon(column, {image = opts.image, size = opts.size, tooltip = opts.tooltip,
                on_click = function() if list then close() else open() end end})
            caption = function(text) light(value ~= opts.options[1].value); head:SetToolTipText(FText((opts.tooltip or '')..text)) end
            set(value)
            return row, set
        end
        head, caption = W.button(column, {label = '', on_click = function() if list then close() else open() end end})
        -- The game's drop-down arrow after the value, inside the button.
        local inner, line = head.Label:GetParent(), StaticConstructObject(I.object('/Script/UMG.HorizontalBox'), screen.WidgetTree)
        -- The value at the left, a small arrow at the right end, as in the game's own lists.
        head.Label:SetJustification(0)
        head.Label.Slot:SetHorizontalAlignment(0)
        line:AddChild(inner)
        inner.Slot:SetSize({SizeRule = 1, Value = 1})
        inner.Slot:SetHorizontalAlignment(0)
        inner.Slot:SetPadding(PAD)
        local mark = W.arrow(line)
        mark.Slot:SetVerticalAlignment(2)
        mark.Slot:SetPadding({Left = 0, Top = 0, Right = 10, Bottom = 0})
        head.MyButton:SetContent(line)
        line.Slot:SetHorizontalAlignment(0)
        set(value)
        return row, set
    end
    -- A press outside the open options and their button closes them.
    U.on_any_press(function()
        local o = opened
        if o and not U.under(o.list) and not U.under(o.head) then o.close() end
    end)

end
