-- Compact windows over the game world, made of the game's own controls (WindowKit's controls
-- work inside them) at a reduced scale: a purple outline like the game's dialogs around a
-- background tinted per window, and a title bar: the title to drag the window by (hold the left
-- button on it), a lock and a close button (×). A locked window stays where it is, has no ×, and
-- opens there again, also after a restart. A small corner button in the window's colour opens
-- and closes it where it is available. While a window is open the mouse clicks the window; the
-- game plays on. Lua cannot make a widget class, so each window lives on a cleared game widget.
-- The scale is a layout scale (a scale box), so pop-ups such as a combo's list open in place.
-- A window's sections (U.section: a heading and what is built under it) can be pulled out into
-- windows of their own: hold the heading and move the mouse. The section's window takes all of
-- it, its own sections included; its × puts it back. Sections that stand apart are remembered
-- (by default only those whose window is locked). A locked window gives none out.
-- Windows stack: locked ones under the others, in the order they were locked; of the others the
-- one last touched is on top. All windows lie on one layer, each on its own host, so the order
-- is only a number per window.
return function(R, C, U, I, W)
    -- The game's small drop-down arrow in a box of its size (a choice's, a section's fold): box, arrow.
    function W.arrow(parent)
        local mark = I.native(parent, 'SizeBox')
        mark:SetWidthOverride(14); mark:SetHeightOverride(9)
        local arrow = I.native(mark, 'Image')
        arrow:SetBrushFromTexture(R.native.load_asset('/Game/UserInterface/UIElements/T_DropDownArrow.T_DropDownArrow'), false)
        return mark, arrow
    end
    local host_class = C.HOST_WIDGET
    local library = '/Script/UMG.Default__WidgetBlueprintLibrary'
    local layout = '/Script/UMG.Default__WidgetLayoutLibrary'
    local OUTLINE = {R = .42, G = .3, B = .78, A = 1}
    local MARGIN, GAP, ICON, ICON_SCALE = 16, 10, 34, .72
    local BODY_RESERVE = 70   -- the title bar and the frame's padding, unscaled
    local USER_SCALE = 7   -- EStretch::UserSpecified (6 is ScaleBySafeZone in this engine)
    local LOCK = '/Game/UserInterface/Play/T_Lock_D.T_Lock_D'   -- the game's own lock icon
    -- Creative's mouse wheel (its fly speed); while a window is carried the wheel scales it.
    local WHEEL = C.CREATIVE_PC .. ':'
        ..'InpAxisKeyEvt_MouseWheelAxis_K2Node_InputAxisKeyEvent_0'
    local SCALE_STEP, SCALE_MIN, SCALE_MAX = .08, .3, 1.6
    local SCALE = .66   -- a window's own size (opts.scale overrides)
    local DOUBLE_CLICK = .35   -- seconds of real time between two presses on a title
    local LEFT_BUTTON = R.codes.LEFT_MOUSE
    local PULL = 24   -- how far (px) the mouse moves with a heading held before its section comes out
    local windows, open, saved = {}, {}, nil
    local layer, layer_root   -- the windows' layer on the viewport (one per world)
    local TOP, touches = 1000000, 0   -- unlocked windows stack above every locked one, by last touch
    local pulled = {}   -- sections pulled out in this session (they stay apart until put back)
    -- A window's state (w.state): 'closed', 'open' or 'hidden' (turned off with its corner button while
    -- sections of it stay apart: what it built lives on in them). At most one open window is carried
    -- (dragged): carried.
    local carried, release_wheel   -- the window being dragged; the wheel's intercept while windows are open
    -- (saved: the windows' hold on the input, UIKit's input stack, while any window is open)
    -- Sections built now, by id (the latest build of each), and the windows of sections apart;
    -- a section's body -> the section (to find the section a section is in).
    local sections, apart, bodies = {}, {}, setmetatable({}, {__mode = 'k'})
    local paint_folds   -- (below, with the sections)
    -- Per window id: {scale} as set with the wheel, {x, y, locked} where a locked window stands,
    -- and {x, y, apart} for a section standing apart.
    -- Options (Mods > Options > Windows): a section stays apart only when its window is locked
    -- (default); it stays when its window is turned off with its corner button (default no).
    local store = R.settings('UIKit', {windows = {}, folded = {}, locks = 0})
    -- (store.folded: section id -> folded (true) or unfolded (false) by the player; store.locks: how
    -- many locks so far, a locked window's place in the stack)
    local function needs_lock() return store.apart_needs_lock ~= false end
    local function outlives() return store.apart_outlives == true end
    -- The windows' look (user 11-20, to compare in the game before choosing): the game's panel - its
    -- frame and background as the game's own panels wear them (the colour panel's look), the window's
    -- colour a light shade over it - or the windows' own (default): the frame as an outline round
    -- a body of the window's colour.
    local function game_look() return store.game_look == true end
    R.options(function(rows)
        local function option(key, label, tip, value)
            return (U.checkbox(rows, {label = label, tooltip = tip, value = value,
                on_change = function(on) store[key] = on; R.save_settings('UIKit') end}))
        end
        return {option('apart_needs_lock', 'Pull out when locked', 'A section is pulled out of a tool window into a window of its own only while that window is locked.', needs_lock()),
            option('apart_outlives', 'Keep pulled-out windows', 'Windows pulled out of a tool window stay open when it closes.', outlives()),
            option('game_look', 'Game panel look', 'Tool windows wear the frame and background of the game\'s own panels (open them again to see it).', game_look())}
    end, 'Tool windows')

    local function construct(tree, kind) return StaticConstructObject(I.object('/Script/UMG.'..kind), tree) end
    -- The game's own frame (its UI frame texture, as a border of the game draws it), looked for once a
    -- world among the game's borders; a window wears it around its tinted body. None shown: the
    -- plain outline.
    local frame_brush, frame_colour, frame_looked
    local function game_frame()
        if frame_looked then return frame_brush, frame_colour end
        frame_looked = true
        -- (a border without a picture has no resource object: asking an empty object its name reads
        -- address 0 in UE4SS and ends the game, which no pcall catches; live 11-19, the Tools click)
        for _, border in ipairs(FindAllOf('Border') or {}) do
            local picture = R.valid(border) and R.valid(border.Background.ResourceObject)
            if picture and picture:GetFName():ToString() == 'T_UIFrame' then frame_brush, frame_colour = border.Background, border.BrushColor; break end
        end
        return frame_brush, frame_colour
    end
    -- The local player of the current world (Core sets it once the world has one).
    local function pc() return R.valid(C.session().pc) end
    -- A game widget used as a blank host: its own texts are removed, ours go on its canvas. The
    -- host is made to ignore the mouse; our controls take clicks, the empty canvas does not.
    local function blank()
        local player = pc()
        local widget = I.object(library):Create(player, R.native.load_asset(host_class), player)
        local root = widget.WidgetTree.RootWidget
        root:ClearChildren()
        widget:SetVisibility(4)
        root:SetVisibility(4)
        return widget, root
    end
    -- A corner button's host, on the viewport at z.
    local function host(z)
        local widget, root = blank()
        widget:AddToViewport(z)
        return widget, root
    end
    -- A window's host, over the whole layer; its slot there orders it.
    local function window_host()
        if not R.valid(layer) then
            layer, layer_root = blank()
            layer:AddToViewport(880)
        end
        local widget, root = blank()
        local slot = layer_root:AddChildToCanvas(widget)
        slot:SetAnchors({Minimum = {X = 0, Y = 0}, Maximum = {X = 1, Y = 1}})
        slot:SetOffsets({Left = 0, Top = 0, Right = 0, Bottom = 0})
        return widget, root, slot
    end
    -- A window's place in the stack.
    local function depth(w) return w.locked and (w.rank or 0) or TOP + (w.touched or 0) end
    local function stack(w) if w.layer_slot then w.layer_slot:SetZOrder(depth(w)) end end
    -- A scale box at a fixed scale on the host's canvas; content goes inside it.
    local function scaled(tree, root, scale)
        local box = construct(tree, 'ScaleBox')
        box:SetStretch(USER_SCALE)
        box:SetUserSpecifiedScale(scale)
        local slot = root:AddChildToCanvas(box)
        slot:SetAutoSize(true)
        return box, slot
    end
    local function corner(slot, x, y)
        slot:SetAnchors({Minimum = {X = 1, Y = 0}, Maximum = {X = 1, Y = 0}})
        slot:SetAlignment({X = 1, Y = 0})
        slot:SetPosition({X = -x, Y = y})
    end
    local function free(slot, x, y)
        slot:SetAnchors({Minimum = {X = 0, Y = 0}, Maximum = {X = 0, Y = 0}})
        slot:SetAlignment({X = 0, Y = 0})
        slot:SetPosition({X = x, Y = y})
    end
    -- Windows not placed by hand stand side by side from the right edge, under the corner buttons,
    -- and to the left of any window placed by hand (moved or locked) that they would cover.
    -- A window's size as laid out now (measured on the spot: a new window has none yet).
    local function measured(w) w.box:ForceLayoutPrepass(); return w.box:GetDesiredSize() end
    local function arrange()
        local player = pc()
        local view = player and I.object(layout):GetViewportSize(player)
        local dpi = player and I.object(layout):GetViewportScale(player)
        local placed = {}
        -- (A window being carried is not in the way: the others stay where they are.)
        for _, w in ipairs(open) do
            if w.moved and carried ~= w and w.state == 'open' then
                local p, size = w.slot:GetPosition(), measured(w)
                placed[#placed + 1] = {l = p.X, t = p.Y, r = p.X + size.X, b = p.Y + size.Y}
            end
        end
        local x, top = MARGIN, MARGIN + ICON + GAP
        for _, w in ipairs(open) do
            if not w.moved and w.state == 'open' then
                local size = measured(w)
                local width, height = w.width * w.scale, size.Y
                if view then
                    local right = view.X / dpi
                    repeat
                        local l = right - x - width
                        local blocked
                        for _, r in ipairs(placed) do
                            if l < r.r and l + width > r.l and top < r.b and top + height > r.t then blocked = r end
                        end
                        if blocked then x = right - blocked.l + GAP end
                    until not blocked
                end
                corner(w.slot, x, top)
                x = x + width + GAP
            end
        end
        -- The corner buttons read left to right in the windows' order (placed from the right edge).
        local bx = MARGIN
        for i = #windows, 1, -1 do
            local w = windows[i]
            if w.icon_slot then
                corner(w.icon_slot, bx, MARGIN)
                w.icon_box:ForceLayoutPrepass()
                bx = bx + w.icon_box:GetDesiredSize().X + 6
            end
        end
    end
    -- The window being dragged now, or nil.
    function W.carried() return carried end
    -- Is the mouse over a window shown or over a corner button (not over the level)?
    -- (by the window's rectangle: a scale or size box is never hovered, and a picture or a picker in a
    -- window does not take the mouse from the game: a click on it deselected in Creative, live 11-20)
    function W.under_mouse()
        local player = pc()
        local mouse = player and I.object(layout):GetMousePositionOnViewport(player)
        local function over(widget)
            if not (mouse and R.valid(widget)) then return false end
            local r = R.native.widget_rect(widget)
            return mouse.X >= r.left and mouse.X <= r.right and mouse.Y >= r.top and mouse.Y <= r.bottom
        end
        for _, w in ipairs(windows) do
            if w.state == 'open' and over(w.box) then return true end
            if over(w.icon_box) then return true end
        end
        return false
    end
    -- The mouse wheel while windows are open: it scales a window being dragged, steps the number
    -- field under the mouse, and otherwise goes to the game. (Its value comes from the player's
    -- input: the intercept passes no float parameters.)
    local function wheel(player)
        local steps = player:GetInputAnalogKeyState({KeyName = FName('MouseWheelAxis')})
        if steps == 0 then return false end
        if carried then carried.zoom(steps); return true end
        for widget in pairs(W.numbers) do
            if R.valid(widget) and widget:IsHovered() then
                -- (the field's own step and range: a copy kept beside them went stale, audit 11-20)
                local value = widget:GetValue() + widget:GetDelta() * steps
                value = math.min(widget:GetMaxValue(), math.max(widget:GetMinValue(), value))
                widget:SetValue(value)
                W.check_fields()
                return true
            end
        end
        return false
    end
    local function input(on)
        local player = pc()
        if not player then return end
        if on and not saved then
            saved = I.hold(I.snapshot())
            I.object(library):SetInputMode_GameAndUIEx(player, nil, 0, false, false)
            player.bShowMouseCursor = true
            release_wheel = R.native.intercept(WHEEL, wheel)
        elseif not on and saved then
            I.release(saved, 'now')
            saved = nil
            release_wheel()
            release_wheel = nil
        end
    end
    -- A game button in the window's colour: same font, shape and texture. The window's colour
    -- is a dark background shade; the button's frame takes a brighter one, and a much brighter
    -- one while lit (its window is open). The caption keeps the game's colours: the button binds
    -- them itself.
    local BUTTON_TINT, LIT = 6, 2.5
    local function coloured(button, colour, on)
        local c = colour
        local k = on and LIT / math.max(c.R, c.G, c.B) or BUTTON_TINT
        button.MyButton:SetBackgroundColor({R = c.R * k, G = c.G * k, B = c.B * k, A = 1})
    end

    -- opts: id (for what is remembered; default the title), title, tint {R,G,B}, width (px before
    -- scaling), scale (scale_of(): the size to open at, read as it opens), icon (corner button text), available()
    -- (where the window and its button exist), build(content, window), on_close().
    -- Whether a section stands apart (in a window of its own): pulled out and kept - locked, pulled this
    -- session, or with no locks needed. One rule for the window asking and the section being built
    -- (audit 11-20: written twice).
    function W.stays_apart(id)
        local place = store.windows[id]
        return place ~= nil and place.apart == true and (place.locked or pulled[id] or not needs_lock()) or false
    end
    function W.window(opts)
        local colour = opts.tint or {R = .03, G = .03, B = .05}
        -- A window with no title of its own is titled with the name of the mod that makes it (a
        -- section's window: its window's mod, made where no mod's code is running).
        local mod = opts.mod or R.mod_name(R.owner('WindowKit', 'UIKit'))
        opts.title = opts.title or mod
        local w = {opts = opts, id = opts.id or opts.title, width = opts.width or 380, scale = opts.scale or SCALE, mod = mod, state = 'closed'}
        -- The windows stand in the order of their mods' names (a mod's own in the order it makes them).
        local at = #windows + 1
        for i, other in ipairs(windows) do if mod < other.mod then at = i; break end end
        table.insert(windows, at, w)
        local function remember()
            local p = w.slot:GetPosition()
            local record = w.scale ~= (opts.scale or SCALE) and {scale = w.scale} or nil
            if w.locked or opts.apart then
                record = record or {}
                record.x, record.y, record.locked, record.apart = p.X, p.Y, w.locked or nil, opts.apart
                record.rank = w.locked and w.rank or nil
            end
            store.windows[w.id] = record
            R.save_settings('UIKit')
        end
        -- The body: no taller than the screen under the corner buttons at the window's scale;
        -- a longer content scrolls.
        local function fit()
            local player = pc()
            local view = I.object(layout):GetViewportSize(player).Y / I.object(layout):GetViewportScale(player)
            w.body:SetMaxDesiredHeight((view - (MARGIN + ICON + GAP) - MARGIN) / w.scale - BODY_RESERVE)
        end
        -- The wheel while carried: the window grows or shrinks around the point held.
        function w.zoom(steps)
            local scale = math.max(SCALE_MIN, math.min(SCALE_MAX, w.scale * (1 + SCALE_STEP * steps)))
            local k = scale / w.scale
            w.scale = scale
            w.box:SetUserSpecifiedScale(scale)
            fit()
            w.grab = {X = w.grab.X * k, Y = w.grab.Y * k}
        end
        -- The end of a drag: the wheel goes back to the game, the size is kept.
        local function drop()
            if carried ~= w then return end
            carried = nil
            remember()
        end

        -- From the right-edge anchor to a free position under the same top-left corner.
        local function unanchor()
            if w.moved then return end
            local player = pc()
            local size = I.object(layout):GetViewportSize(player)
            local dpi = I.object(layout):GetViewportScale(player)
            local p = w.slot:GetPosition()
            free(w.slot, size.X / dpi + p.X - w.width * w.scale, p.Y)
            w.moved = true
            arrange()
        end
        -- Moving: the window follows the mouse every frame until the button is released.
        local function moving()
            if carried ~= w then return end
            if not R.native.key_down(LEFT_BUTTON) then drop(); return end
            local player = pc()
            if player then
                local mouse = I.object(layout):GetMousePositionOnViewport(player)
                w.slot:SetPosition({X = mouse.X - w.grab.X, Y = mouse.Y - w.grab.Y})
            end
            R.next_frame(moving)
        end
        -- Dragging: the left mouse button pressed over the title starts it; releasing it ends it.
        -- grab: where the mouse holds the window (default: where it is over it now).
        local function carry(grab)
            if not pc() then return end
            unanchor()
            local mouse = I.object(layout):GetMousePositionOnViewport(pc())
            local p = w.slot:GetPosition()
            w.grab = grab or {X = mouse.X - p.X, Y = mouse.Y - p.Y}
            carried = w
            moving()
        end
        w.carry = carry
        -- Touched (opened, pressed on, unlocked): on top of the unlocked windows.
        function w.raise()
            touches = touches + 1
            w.touched = touches
            stack(w)
        end

        -- The sections this window shows apart close with it and with each new build of it (the
        -- build opens those it builds again); they stay apart.
        local function close_apart()
            for id, section in pairs(sections) do
                if section.owner == w then
                    sections[id] = nil
                    if apart[id] then apart[id].close() end
                end
            end
        end
        w.close_apart = close_apart
        -- Does the section of this window with this heading stand apart (in a window of its own,
        -- now or when it is built)? Its owner then builds it even where it would not show it.
        function w.apart(label) return W.stays_apart(w.id..' / '..label) end

        -- The title bar (built again when the lock changes; the content stays).
        local function title_bar()
            if w.bar then I.remove(w.bar) end
            local bar = U.flow(w.top)
            w.bar = bar
            -- The title is a button without its plate: it reads as text and takes the drag.
            w.title = U.fill(W.button(bar, {label = opts.title}))
            U.on_press(w.title, function() w.press() end)
            w.title.MyButton:SetBackgroundColor({R = 0, G = 0, B = 0, A = 0})
            -- The lock: the game's lock icon in a game button, bright when locked, dim when open.
            w.lock_button = W.button(bar, {label = '', on_click = function() w.lock(not w.locked) end})
            local icon = construct(w.widget.WidgetTree, 'Image')
            icon:SetBrushFromTexture(R.native.load_asset(LOCK), false)
            icon:SetOpacity(w.locked and 1 or .35)
            local square = construct(w.widget.WidgetTree, 'SizeBox')
            square:SetWidthOverride(28); square:SetHeightOverride(28)
            square:SetContent(icon)
            w.lock_button.MyButton:SetContent(square)
            if not w.locked then
                W.button(bar, {label = '×', on_click = function()
                    if opts.dismiss then opts.dismiss() end
                    w.close()
                end})
            end
        end
        local function fill()
            w.content = construct(w.widget.WidgetTree, 'VerticalBox')
            w.inner:SetContent(w.content)
            I.own(w.inner, w.content)
            w.top, w.bar = I.native(w.content, 'SizeBox'), nil
            title_bar()
            w.body = I.native(w.content, 'SizeBox')
            fit()
            local scroll = I.scroll_box(w.body)
            close_apart()
            opts.build(I.native(scroll, 'VerticalBox'), w)
        end
        function w.shown() return w.state ~= 'closed' end
        function w.open()
            if w.shown() or not opts.available() or not pc() then return end
            local widget, root, layer_slot = window_host()
            I.state(widget).window = w
            w.widget, w.layer_slot, w.state = widget, layer_slot, 'open'
            local tree = widget.WidgetTree
            local place = store.windows[w.id]
            -- (a section's window opens at its window's size as it is now: opts.scale_of)
            w.scale = place and place.scale or opts.scale_of and opts.scale_of() or opts.scale or SCALE
            local box, slot = scaled(tree, root, w.scale)
            local size, outline, inner = construct(tree, 'SizeBox'), construct(tree, 'Border'), construct(tree, 'Border')
            size:SetWidthOverride(w.width)
            local frame, frame_tint = game_frame()
            if frame and game_look() then
                outline:SetBrush(frame); outline:SetBrushColor(frame_tint)
                outline:SetPadding({Left = 16, Top = 10, Right = 16, Bottom = 16})
                inner:SetBrushColor({R = colour.R, G = colour.G, B = colour.B, A = .18})
                inner:SetPadding({Left = 6, Top = 4, Right = 6, Bottom = 6})
            else
                if frame then outline:SetBrush(frame); outline:SetBrushColor({R = 1, G = 1, B = 1, A = 1})
                else outline:SetBrushColor(OUTLINE) end
                outline:SetPadding({Left = 3, Top = 3, Right = 3, Bottom = 3})
                inner:SetBrushColor({R = colour.R, G = colour.G, B = colour.B, A = .92})
                inner:SetPadding({Left = 12, Top = 8, Right = 12, Bottom = 12})
            end
            outline:SetContent(inner)
            size:SetContent(outline)
            box:SetContent(size)
            w.inner, w.slot, w.box = inner, slot, box
            w.locked, w.moved, w.rank = place ~= nil and place.locked == true, false, place and place.rank
            if place and place.x then free(slot, place.x, place.y); w.moved = true end
            w.raise()
            fill()
            open[#open + 1] = w
            arrange()
            input(true)
            if w.paint_icon then w.paint_icon() end
        end
        function w.close()
            drop()
            -- Closed, its sections that are apart only for now go back (unlocked, when locks are needed).
            for id, section in pairs(sections) do
                if section.owner == w and apart[id] and apart[id].shown() and needs_lock() and not apart[id].locked then
                    apart[id].opts.dismiss()
                end
            end
            close_apart()
            if w.state == 'closed' then return end
            local widget = w.widget
            w.widget, w.content, w.inner, w.slot, w.box, w.title, w.layer_slot, w.state = nil, nil, nil, nil, nil, nil, nil, 'closed'
            I.forget(widget)
            widget:RemoveFromParent()
            for i, other in ipairs(open) do if other == w then table.remove(open, i); break end end
            arrange()
            if #open == 0 then input(false) end
            if w.paint_icon then w.paint_icon() end
            if opts.on_close then opts.on_close() end
        end
        function w.toggle() if w.shown() then w.close() else w.open() end end
        -- Locked: no ×, no dragging, and the window opens at this place again.
        function w.lock(on)
            if not w.shown() then return end
            drop()
            if on then unanchor() end
            w.locked = on
            -- Locked: above the windows locked before it, under all unlocked ones. Unlocked: on top.
            if on then store.locks = store.locks + 1; w.rank = store.locks else w.rank = nil; w.raise() end
            stack(w)
            remember()
            title_bar()
            paint_folds()
        end
        -- A press on the title starts a drag; a second press soon after (a double click) gives the
        -- window its own size back.
        function w.press()
            if w.state ~= 'open' or w.locked or carried == w then return end
            local now = I.object('/Script/Engine.Default__GameplayStatics'):GetRealTimeSeconds(pc())
            if w.pressed_at and now - w.pressed_at <= DOUBLE_CLICK then
                w.pressed_at = nil
                w.scale = opts.scale or SCALE
                w.box:SetUserSpecifiedScale(w.scale)
                fit()
                remember()
                arrange()
                return
            end
            w.pressed_at = now
            carry()
        end
        -- Builds the content again from the current state (after an action changed it).
        function w.refresh()
            if not w.shown() then return end
            I.remove(w.content)
            fill()
        end

        -- Turned off with its corner button while sections of it stay apart (the option): the window
        -- only hides, so what it built lives on in them; the button shows it again.
        local function keeps_apart()
            if not outlives() then return false end
            for id, section in pairs(sections) do
                if section.owner == w and apart[id] and apart[id].shown() and (not needs_lock() or apart[id].locked) then return true end
            end
            return false
        end
        local function hide(on)
            w.state = on and 'hidden' or 'open'
            w.widget:SetVisibility(on and 1 or 4)
            if not on then w.raise() end
            arrange()
            if w.paint_icon then w.paint_icon() end
        end
        local function corner_click()
            if w.state == 'hidden' then hide(false)
            elseif w.shown() and keeps_apart() then hide(true)
            else w.toggle() end
        end
        -- The corner button: exists only where the window is available; one size for every window.
        local function place_icon()
            local wanted = opts.icon and opts.available() and pc() ~= nil
            local present = w.icon_widget and R.valid(w.icon_widget)
            if wanted and not present then
                local widget, root = host(870)
                w.icon_widget = widget
                local box
                box, w.icon_slot = scaled(widget.WidgetTree, root, ICON_SCALE)
                w.icon_box = box
                local button = U.button(box, {label = opts.icon, on_click = corner_click})
                w.paint_icon = function() coloured(button, colour, w.state == 'open') end
                w.paint_icon()
                arrange()
            elseif not wanted and present then
                I.forget(w.icon_widget)
                w.icon_widget:RemoveFromParent()
                w.icon_widget, w.icon_slot, w.icon_box, w.paint_icon = nil, nil, nil, nil
                arrange()
            end
            if not opts.available() then w.close() end
        end
        -- Session changes arrive in the middle of world loading; widgets are made a frame later
        -- (place_icon only brings the button to what the session wants, so repeats do nothing).
        C.on_session(function() R.next_frame(place_icon) end)
        return w
    end

    -- A section's own window: what the section's window built goes into it; its × puts the section
    -- back. One window per section id, made the first time the section comes out.
    local function apart_window(section)
        local id, owner = section.id, section.owner
        if not apart[id] then
            apart[id] = W.window{id = id, mod = owner.mod, title = section.title, tint = owner.opts.tint, width = owner.width,
                scale = owner.opts.scale, scale_of = function() return owner.scale end, apart = true, available = owner.opts.available,
                build = function(box)
                    local current = sections[id]
                    if current then current.head:SetVisibility(1); box:AddChild(current.section) end
                    paint_folds()
                end,
                dismiss = function()
                    store.windows[id], pulled[id] = nil, nil
                    R.save_settings('UIKit')
                    local current = sections[id]
                    if current then current.head:SetVisibility(0); current.holder:SetContent(current.section) end
                    paint_folds()
                end}
        end
        return apart[id]
    end
    -- A section of a window: a heading and a box for what goes under it (returned), in a holder
    -- that keeps its place there; its heading can pull it out. A section remembered apart goes to
    -- its own window as it is built. opts.label names it within its window; without one it is a
    -- plain group (UIKit's section). opts.folded: shown folded until the player unfolds it.
    local fold, shown_in, pull   -- (below)
    -- A button without a plate or padding: it can be hovered (a text or border cannot).
    local function plain_button(parent)
        local button = I.native(parent, 'Button')
        button:SetBackgroundColor({R = 0, G = 0, B = 0, A = 0})
        local style = button.WidgetStyle
        style.NormalPadding, style.PressedPadding = {Left = 0, Top = 0, Right = 0, Bottom = 0}, {Left = 0, Top = 0, Right = 0, Bottom = 0}
        button.WidgetStyle = style
        return button
    end
    function W.section(parent, opts)
        if not (opts and opts.label) then return U.section(parent, opts) end
        local owner = assert(I.owner(parent).window, 'a section with a heading belongs in a window')
        local section = {id = owner.id..' / '..opts.label, title = opts.label, owner = owner}
        section.holder = I.native(parent, 'SizeBox')
        section.section = I.native(section.holder, 'VerticalBox')
        section.parent = bodies[parent]
        -- The head: the heading, to pull the section out by, and the fold arrow at the right.
        section.head = I.native(section.section, 'HorizontalBox')
        section.heading = plain_button(section.head)
        section.heading.Slot:SetSize({SizeRule = 1, Value = 1})
        local text = U.text(section.heading, {text = opts.label, heading = true})
        text.Slot:SetHorizontalAlignment(0)
        text.Slot:SetPadding({Left = 0, Top = 0, Right = 0, Bottom = 0})
        section.fold = plain_button(section.head)
        U.on_press(section.fold, function()
            store.folded[section.id] = not section.folded
            R.save_settings('UIKit')
            fold(section, store.folded[section.id])
        end)
        U.on_press(section.heading, function()
            if not shown_in(section).locked then pull(section, I.object(layout):GetMousePositionOnViewport(pc())) end
        end)
        section.fold.Slot:SetVerticalAlignment(2)
        local mark
        mark, section.arrow = W.arrow(section.fold)
        mark.Slot:SetPadding({Left = 6, Top = I.HEADING_GAP, Right = 6, Bottom = 0})
        section.arrow:SetRenderTransformPivot({X = .5, Y = .5})
        section.body = I.native(section.section, 'VerticalBox')
        local body = section.body
        bodies[body] = section
        sections[section.id] = section
        local folded = store.folded[section.id]
        if folded == nil then folded = opts.folded == true end   -- (opts.folded: folded until the player opens it)
        fold(section, folded)
        local place = store.windows[section.id]
        local stays = W.stays_apart(section.id)
        if place and place.apart and not stays then store.windows[section.id] = nil end
        if stays then
            local window = apart_window(section)
            if window.shown() then window.refresh() else window.open() end
        end
        paint_folds()
        return body, function(visible) section.holder:SetVisibility(visible and 0 or 1) end
    end
    -- Folded: the content is hidden, the arrow points sideways.
    function fold(section, folded)
        section.folded = folded
        section.body:SetVisibility(folded and 1 or 0)
        section.arrow:SetRenderTransformAngle(folded and -90 or 0)
    end
    -- The window a section's head is shown in: that of the nearest section around it standing
    -- apart, or its own window. Its fold arrow shows only while that window is not locked.
    function shown_in(section)
        local around = section.parent
        while around do
            if apart[around.id] and apart[around.id].shown() then return apart[around.id] end
            around = around.parent
        end
        return section.owner
    end
    function paint_folds()
        for _, section in pairs(sections) do
            if R.valid(section.fold) then section.fold:SetVisibility(shown_in(section).locked and 1 or 0) end
        end
    end
    -- Pulling a heading: once the mouse has moved far enough with the button held, the section
    -- comes out into its own window, held by its title where the mouse is.
    function pull(section, from)
        if not R.native.key_down(LEFT_BUTTON) or not R.valid(section.heading) then return end
        local mouse = I.object(layout):GetMousePositionOnViewport(pc())
        if math.abs(mouse.X - from.X) + math.abs(mouse.Y - from.Y) < PULL then
            R.next_frame(function() pull(section, from) end)
            return
        end
        local grab = {X = 60, Y = 16}
        store.windows[section.id] = {apart = true, x = mouse.X - grab.X, y = mouse.Y - grab.Y}
        pulled[section.id] = true
        local window = apart_window(section)
        carried = window   -- (in nobody's way while it opens under the mouse)
        window.open()
        -- (it did not open - not available here: nothing to carry)
        if not window.shown() then carried = nil; return end
        window.carry(grab)
    end

    -- Any press of the left button: the window under the mouse (the topmost there) comes up, unless
    -- it is locked. (A press on a title, a fold arrow or a heading is that control's: U.on_press.)
    U.on_any_press(function()
        local player, touched = pc(), nil
        if not player then return end
        local mouse = I.object(layout):GetMousePositionOnViewport(player)
        for _, w in ipairs(open) do
            if w.state == 'open' then
                local r = R.native.widget_rect(w.box)
                if mouse.X >= r.left and mouse.X <= r.right and mouse.Y >= r.top and mouse.Y <= r.bottom
                    and (not touched or depth(w) > depth(touched)) then touched = w end
            end
        end
        if touched and not touched.locked then touched.raise() end
    end)
    -- Widgets in the viewport go with the world; so do our records of them.
    R.on('world_end', function()
        for _, w in ipairs(windows) do
            w.widget, w.content, w.inner, w.slot, w.box, w.layer_slot, w.state = nil, nil, nil, nil, nil, nil, 'closed'
            w.icon_widget, w.icon_slot, w.icon_box, w.paint_icon = nil, nil, nil, nil
        end
        if release_wheel then release_wheel() end
        open, saved, sections, carried, release_wheel, layer, layer_root = {}, nil, {}, nil, nil, nil, nil
        frame_brush, frame_colour, frame_looked = nil, nil, false
    end)
end
