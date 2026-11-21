-- Lines of text on the screen over the game: a label in a corner (U.label), a red line at the top
-- for a moment when something failed (U.error_line), and the key help: the shortcuts that work
-- here, a column at the top centre, switched by its key (off at the start).
return function(R, C, U, I)
    local HOST = C.HOST_WIDGET
    local font
    local function construct(kind, tree) return StaticConstructObject(I.object('/Script/UMG.'..kind), tree) end
    -- A text in a dark frame anchored to a point of the screen: anchor {x, y} (0..1), pos {X, Y},
    -- size (font), z (layer). Returns {widget, text, set(text), colour({R,G,B,A}), remove()}.
    function U.label(pc, opts)
        local w = I.object('/Script/UMG.Default__WidgetBlueprintLibrary'):Create(pc, R.native.load_asset(HOST), pc)
        local tree = w.WidgetTree
        local root = tree.RootWidget
        root:ClearChildren()   -- (the host widget's own "Beta Version" texts)
        local frame, text = construct('Border', tree), construct('TextBlock', tree)
        font = font or R.native.load_asset(C.PIXEL_FONT)
        text:SetFont({FontObject = font, TypefaceFontName = FName('Font'), Size = opts.size or 13})
        text:SetColorAndOpacity({SpecifiedColor = {R = .9, G = .9, B = .95, A = 1}, ColorUseRule = 0})
        frame:SetBrushColor({R = .01, G = .012, B = .016, A = .85})
        frame:SetPadding({Left = 8, Top = 3, Right = 8, Bottom = 3})
        frame:SetContent(text)
        frame:SetVisibility(3)
        local slot = root:AddChildToCanvas(frame)
        local a = opts.anchor
        slot:SetAutoSize(true)
        slot:SetAnchors({Minimum = {X = a.x, Y = a.y}, Maximum = {X = a.x, Y = a.y}})
        slot:SetAlignment({X = a.x, Y = a.y})
        slot:SetPosition(opts.pos)
        w:SetVisibility(3)
        w:AddToViewport(opts.z or 120)
        local L = {widget = w, text = text}
        function L.set(value) text:SetText(FText(value)) end
        function L.colour(c) text:SetColorAndOpacity({SpecifiedColor = c, ColorUseRule = 0}) end
        function L.remove() if R.valid(w) then w:RemoveFromParent() end end
        L.set(opts.text or '')
        return L
    end

    -- A red line at the top of the screen for a few seconds (the first line of msg).
    local errors, shown = nil, 0
    function U.error_line(msg, seconds, colour)
        local pc = R.valid(C.session().pc)
        local line = tostring(msg):gsub('\n.*', '')
        if not pc then R.log('UIKit', 'Error line not shown (no local player): %s', line); return end
        R.log('UIKit', 'Error line shown: %s', line)
        if #line > 160 then line = line:sub(1, 157)..'...' end
        if not (errors and R.valid(errors.widget)) then
            errors = U.label(pc, {anchor = {x = .5, y = 0}, pos = {X = 0, Y = 110}, size = 14, z = 970})
        end
        errors.colour(colour or {R = 1, G = .45, B = .4, A = 1})
        errors.set(line)
        errors.widget:SetVisibility(3)
        shown = shown + 1
        local this, label = shown, errors
        R.after((seconds or 6) * 1000, function()
            if shown == this and R.valid(label.widget) then label.widget:SetVisibility(1) end
        end)
    end

    -- The key help line: where this player is (a context the shortcuts name), and the line.
    local on, help = false, nil
    local function place()
        local s = C.session()
        if s.is_creative then return 'Creative' end
        -- A mode of a mod (C.map): the session's, or the one it plays; named after its mod.
        local spec = C.map.spec(s.mode)
        if spec then return spec.name end
        for _, id in ipairs(C.map.modes()) do
            spec = C.map.spec(id)
            if spec.plays and spec.plays(s) then return spec.name end
        end
    end
    -- A column at the right edge, one shortcut a line as the game's own key hints: its name, then its
    -- keys as the game's key pictures (user 11-20: in one line most did not fit).
    local function show()
        if help and R.valid(help) then help:RemoveFromParent() end
        help = nil
        local where, pc = place(), R.valid(C.session().pc)
        C.state('UIKit', 'Key help', not on and 'hidden - switched off (key 5)' or not where and 'hidden - no mode here has shortcuts'
            or not pc and 'hidden - no local player' or 'shown for ' .. where)
        if not (on and where and pc) then return end
        local w = I.object('/Script/UMG.Default__WidgetBlueprintLibrary'):Create(pc, R.native.load_asset(HOST), pc)
        local root = w.WidgetTree.RootWidget
        root:ClearChildren()   -- (the host widget's own "Beta Version" texts)
        local frame, column = construct('Border', w.WidgetTree), construct('VerticalBox', w.WidgetTree)
        frame:SetBrushColor({R = .01, G = .012, B = .016, A = .6})
        frame:SetPadding({Left = 12, Top = 8, Right = 12, Bottom = 8})
        frame:SetContent(column)
        local slot = root:AddChildToCanvas(frame)
        slot:SetAutoSize(true)
        -- (top centre: the right edge holds the tool windows and the game's own hints, live VM1 11-20)
        slot:SetAnchors({Minimum = {X = .5, Y = 0}, Maximum = {X = .5, Y = 0}})
        slot:SetAlignment({X = .5, Y = 0})
        slot:SetPosition({X = 0, Y = 90})
        -- (columns of at most 8 lines side by side: one column ran off the bottom of the screen, live VM1 11-20)
        local columns, lines = construct('HorizontalBox', w.WidgetTree), 0
        frame:SetContent(columns)
        for _, row in ipairs(R.hotkeys()) do
            if row.current ~= 'Disabled' and row.context and row.context:find(where, 1, true) then
                if lines % 8 == 0 then
                    column = I.native(columns, 'VerticalBox')
                    column.Slot:SetPadding({Left = lines > 0 and 24 or 0, Top = 0, Right = 0, Bottom = 0})
                end
                lines = lines + 1
                local line = I.native(column, 'HorizontalBox')
                line.Slot:SetHorizontalAlignment(2)   -- (right)
                local name = U.text(line, {text = row.label, wrap = false})
                name.Slot:SetVerticalAlignment(2)
                name.Slot:SetPadding({Left = 0, Top = 0, Right = 10, Bottom = 0})
                for _, key in ipairs(R.chord_keys(row.current) or {}) do
                    local icon = I.cooked(line, 'WB_ControllerIcon', R.native.load_asset(I.KEY_ICON))
                    icon:SetBoundKey({KeyName = FName(key)})
                end
            end
        end
        w:SetVisibility(3)
        w:AddToViewport(20000)   -- (over the tool windows and the game's palette: shown on purpose; 950 was still under them, live VM1 11-20)
        help = w
    end
    R.key('ui.help_line', '5', function() on = not on; show() end,
        {label = 'Key help', tip = 'Show or hide the shortcuts that work here, at the right edge of the screen', context = 'Creative, Fill a Pot+ and Imposturous'})
    C.on_session(function() R.next_frame(show) end)
    R.on('hotkeys', show)
    R.on('world_end', function() help, errors = nil, nil end)
end
