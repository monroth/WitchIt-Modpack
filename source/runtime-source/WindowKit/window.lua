-- Compact windows over the game world, made of the game's own controls (WindowKit's controls
-- work inside them) at a reduced scale: a purple outline like the game's dialogs around a
-- background tinted per window, and a frame of small controls (user 11-21):
--   top left   fold up (only the title line stays, the top edge where it was), and the focus mark
--              of a tool window (it lights: the in-world marks are this window's page's; only one
--              window is focused at a time, none by itself)
--   the title  to drag the window by (hold the left button on it)
--   top right  x (close), lock, anchor: choosing lock or anchor hides the other two; the chosen one
--              again gives all three back. Locked: the window stays where it is, has no x, and opens
--              there again, also after a restart. Anchored: the same, and its owner closing does not
--              close it (a page pulled out of the Tools window stays open when Tools closes)
--   bottom     a thin bar: fold down at its left (only the title line stays, the bottom edge where
--              it was), the window's own foot (opts.foot) at its right
-- A small corner button in the window's colour opens and closes it where it is available. While a
-- window is open the mouse clicks the window; the game plays on. Lua cannot make a widget class, so
-- each window lives on a cleared game widget. The scale is a layout scale (a scale box), so pop-ups
-- such as a combo's list open in place.
-- A tool's page can be pulled out of its window into a window of its own (W.pullable, W.pull_page:
-- hold the tile and move the mouse); its x puts it back. Pages that stay out are the anchored ones.
-- Windows stack: locked and anchored ones under the others, in the order they were fixed; of the
-- others the one last touched is on top. All windows lie on one layer, each on its own host, so the
-- order is only a number per window.
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
    local PULL = 24   -- how far (px) the mouse moves with a tile held before its page comes out
    local windows, open, saved = {}, {}, nil
    local layer, layer_root   -- the windows' layer on the viewport (one per world)
    local TOP, touches = 1000000, 0   -- unfixed windows stack above every locked or anchored one, by last touch
    local pulled = {}   -- pages pulled out in this session (they stay out until put back)
    local focused   -- the one tool window whose page the marks in the world are of (none by itself)
    -- (each tool window's focus as it was last left, this session: a window opened again has it again; never
    -- left yet: on - user 11-21)
    local focus_left = {}
    -- A window's state (w.state): 'closed' or 'open'. At most one open window is carried (dragged): carried.
    local carried, release_wheel   -- the window being dragged; the wheel's intercept while windows are open
    -- (saved: the windows' hold on the input, UIKit's input stack, while any window is open)
    -- Pages pulled out of a window (a tool's tile, a tab: W.pull_page), by id: {window, owner, back}.
    local outs, OUT = {}, ' / out: '
    -- Per window id: {scale} as set with the wheel, {x, y, locked, anchored, fold} where a fixed or folded
    -- window stands, and {x, y, apart} for a page standing out.
    local store = R.settings('UIKit', {windows = {}, folded = {}, locks = 0})
    -- (store.folded: section id -> folded (true) or unfolded (false) by the player; store.locks: how
    -- many windows were fixed so far, a fixed window's place in the stack)
    -- The windows' look (user 11-20, to compare in the game before choosing): the game's panel - its
    -- frame and background as the game's own panels wear them (the colour panel's look), the window's
    -- colour a light shade over it - or the windows' own (default): the frame as an outline round
    -- a body of the window's colour.
    local function game_look() return store.game_look == true end
    R.options(function(rows)
        return {(U.checkbox(rows, {label = 'Game panel look', tooltip = 'Tool windows wear the frame and background of the game\'s own panels (open them again to see it).', value = game_look(),
            on_change = function(on) store.game_look = on; R.save_settings('UIKit') end}))}
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

    -- A small control of the window's frame (user 11-21): a bare button holding a glyph (or the game's lock
    -- picture), dim, bright while lit.
    local DIM, BRIGHT = {R = .62, G = .56, B = .78, A = 1}, {R = .97, G = .95, B = 1, A = 1}
    local function frame_button(bar, tip, lit, on_click, glyph)
        -- (the game's own square button, lit as the game lights an active one - user 11-21: the plain glyphs were
        -- hard to see, the focus above all; × is the game's button with its caption, as before)
        local button
        if glyph == '×' then
            button = W.button(bar, {label = '×', tooltip = tip})
        else
            local picture = glyph and R.picture(W.icons .. glyph .. '.png') or R.native.load_asset(LOCK)
            -- (one button whether lit or not, so nothing moves when it lights - user 11-21; lit: the game's square tinted
            -- bright and the picture yellow, not the game's lit state, a tab lit more on top than below)
            local image
            button, _, image = W.icon(bar, {image = picture, size = 28, tooltip = tip})   -- (as big as the × button, user 11-21)
            if lit then
                button.MyButton:SetBackgroundColor({R = 1.9, G = 1.5, B = .5, A = 1})
                if image then image:SetColorAndOpacity({R = 1, G = .9, B = .25, A = 1}) end
            end
        end
        button.Slot:SetVerticalAlignment(2)
        button.Slot:SetPadding({Left = 2, Top = 0, Right = 2, Bottom = 0})
        U.on_press(button, on_click)   -- (on the press, as every frame control: a title's drag must not wait)
        return button
    end

    -- opts: id (for what is remembered; default the title), title, tint {R,G,B}, width (px before
    -- scaling), scale (scale_of(): the size to open at, read as it opens), icon (corner button text), available()
    -- (where the window and its button exist), build(content, window), on_close(); and the frame's controls:
    -- fold_up (default yes), fold_down (no: only for a window that does not grow downward), anchor (default yes),
    -- focus (no: only for tool windows; on_focus(on, window) tells when it lights or goes out), head(box, window)
    -- (a part above the body that does not scroll), foot(bar, window) (the bottom bar's right side).
    -- Whether a page stands out (in a window of its own): pulled out and kept - anchored, or pulled this
    -- session. One rule for the window asking and the page being built (audit 11-20: written twice).
    function W.stays_apart(id)
        local place = store.windows[id]
        return place ~= nil and place.apart == true and (place.anchored == true or pulled[id] == true) or false
    end
    -- The window whose page the marks in the world are of, or nil.
    function W.focused() return focused end
    function W.window(opts)
        local colour = opts.tint or {R = .03, G = .03, B = .05}
        -- A window with no title of its own is titled with the name of the mod that makes it.
        local mod = opts.mod or R.mod_name(R.owner('WindowKit', 'UIKit'))
        opts.title = opts.title or mod
        local w = {opts = opts, id = opts.id or opts.title, width = opts.width or 380, scale = opts.scale or SCALE, mod = mod, state = 'closed', parts = {}}
        -- The windows stand in the order of their mods' names (a mod's own in the order it makes them).
        local at = #windows + 1
        for i, other in ipairs(windows) do if mod < other.mod then at = i; break end end
        table.insert(windows, at, w)
        local function remember()
            local p = w.slot:GetPosition()
            if w.fit then w.fit() end   -- (moved or zoomed: the body fits the screen under its new top)
            local record = w.scale ~= (opts.scale or SCALE) and {scale = w.scale} or nil
            if w.locked or opts.apart or w.folded then
                record = record or {}
                record.fold, record.locked, record.anchored, record.apart = w.folded, w.locked or nil, w.anchored or nil, opts.apart
                record.open_height = w.folded == 'down' and w.open_height or nil   -- (opened again by it after a restart)
                record.rank = w.locked and w.rank or nil
                -- (a window folded down stands where its title line is now: its bottom edge is the place)
                if w.locked or opts.apart or w.folded == 'down' then record.x, record.y = p.X, p.Y end
            end
            store.windows[w.id] = record
            R.save_settings('UIKit')
        end
        -- The body: no taller than the screen under the corner buttons at the window's scale, less what
        -- stands above and under it (head, bottom bar); a longer content scrolls.
        local function fit()
            local player = pc()
            local view = I.object(layout):GetViewportSize(player).Y / I.object(layout):GetViewportScale(player)
            local used = BODY_RESERVE
            for _, part in ipairs({w.head or false, w.foot or false}) do
                if part then part:ForceLayoutPrepass(); used = used + part:GetDesiredSize().Y end
            end
            -- (from where the window's top is now, not the screen's top: live VM2 11-21 a long Explorer placed
            -- lower ran off the bottom of the screen)
            local at = w.slot and w.slot:GetPosition()
            local top = math.max(MARGIN + ICON + GAP, at and at.Y or 0)
            w.body:SetMaxDesiredHeight(math.max(120, (view - top - MARGIN) / w.scale - used))
        end
        w.fit = fit
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
        -- A window going out of focus (closed, or another one lit) tells its owner.
        local function unfocus()
            if focused ~= w then return end
            focused = nil
            if opts.on_focus then opts.on_focus(false, w) end
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
        -- Touched (opened, pressed on, unlocked): on top of the unfixed windows.
        function w.raise()
            touches = touches + 1
            w.touched = touches
            stack(w)
        end

        -- The title bar (built again when the state changes; the content stays): fold up and focus at
        -- the left, the title, then close / lock / anchor at the right.
        local function title_bar()
            if w.bar then I.remove(w.bar) end
            local bar = U.flow(w.top)
            w.bar = bar
            for _, k in ipairs({'fold_up', 'focus', 'close', 'lock', 'anchor'}) do w.parts[k] = nil end
            -- (folded, the button gives the fold back: its arrow points the way the window opens)
            if opts.fold_up ~= false or w.folded then
                w.parts.fold_up = frame_button(bar, w.folded and 'Unfold' or 'Fold up', w.folded == 'up', function() w.fold('up') end,
                    w.folded == 'up' and 'fold_down' or 'fold_up')
            end
            -- (the window's help: a "?" in the title bar - user 11-21, its own row under the content was height for nothing)
            if w.help_text then
                w.parts.help = frame_button(bar, w.help_text, false, function() end, 'help')
            end
            if opts.focus then
                w.parts.focus = frame_button(bar, focused == w and 'Focused' or 'Focus', focused == w, function() w.focus(focused ~= w) end, 'focus')
            end
            -- The title is a button without its plate: it reads as text and takes the drag.
            w.title = U.fill(W.button(bar, {label = opts.title}))
            U.on_press(w.title, function() w.press() end)
            w.title.MyButton:SetBackgroundColor({R = 0, G = 0, B = 0, A = 0})
            -- (lock, anchor, then × at the very right, where the game puts it - user 11-21)
            if not w.pinned or w.pinned == 'lock' then
                w.parts.lock = frame_button(bar, 'Lock', w.pinned == 'lock', function() w.lock(w.pinned ~= 'lock') end)
            end
            if opts.anchor ~= false and (not w.pinned or w.pinned == 'anchor') then
                w.parts.anchor = frame_button(bar, 'Anchor', w.pinned == 'anchor', function() w.anchor(w.pinned ~= 'anchor') end, 'anchor')
            end
            if not w.pinned then
                w.parts.close = frame_button(bar, 'Close', false, function()
                    if opts.dismiss then opts.dismiss() end
                    w.close()
                end, '×')
            end
        end
        -- The thin bar at the bottom: fold down at the left, the window's own foot at the right.
        local function foot_bar()
            local bar = U.flow(w.foot)
            w.parts.fold_down = nil
            if opts.fold_down then w.parts.fold_down = frame_button(bar, 'Fold down', false, function() w.fold('down') end, 'fold_down') end
            if opts.foot then
                U.fill(U.text(bar, {text = '', wrap = false}))
                opts.foot(bar, w)
            end
        end
        local function apply_fold()
            local v = w.folded and 1 or 0   -- (1: collapsed)
            w.body:SetVisibility(v)
            if w.head then w.head:SetVisibility(v) end
            if w.foot then w.foot:SetVisibility(v) end
        end
        local function fill()
            w.content = construct(w.widget.WidgetTree, 'VerticalBox')
            w.inner:SetContent(w.content)
            I.own(w.inner, w.content)
            w.top, w.bar = I.native(w.content, 'SizeBox'), nil
            title_bar()
            w.head = opts.head and I.native(w.content, 'VerticalBox') or nil
            if w.head then opts.head(w.head, w) end
            w.body = I.native(w.content, 'SizeBox')
            local scroll = I.scroll_box(w.body)
            opts.build(I.native(scroll, 'VerticalBox'), w)
            w.foot = (opts.fold_down or opts.foot) and I.native(w.content, 'SizeBox') or nil
            if w.foot then foot_bar() end
            fit()
            apply_fold()
        end
        function w.shown() return w.state ~= 'closed' end
        function w.open()
            if w.shown() then return end
            if not opts.available() or not pc() then
                C.state('WindowKit', 'Window ' .. tostring(w.id), 'not opened - ' .. (not opts.available() and 'not available in this session' or 'no local player'))
                return
            end
            R.log('WindowKit', 'Opening window %s (creates its widgets)', tostring(w.id))
            C.state('WindowKit', 'Window ' .. tostring(w.id), 'open')
            local widget, root, layer_slot = window_host()
            I.state(widget).window = w
            w.widget, w.layer_slot, w.state = widget, layer_slot, 'open'
            local tree = widget.WidgetTree
            local place = store.windows[w.id]
            -- (a page's window opens at its owner's size as it is now: opts.scale_of)
            w.scale = place and place.scale or opts.scale_of and opts.scale_of() or opts.scale or SCALE
            local box, slot = scaled(tree, root, w.scale)
            local size, outline, inner = construct(tree, 'SizeBox'), construct(tree, 'Border'), construct(tree, 'Border')
            size:SetWidthOverride(w.width)
            local frame, frame_tint = game_frame()
            if frame and game_look() then
                outline:SetBrush(frame); outline:SetBrushColor(frame_tint)
                outline:SetPadding({Left = 16, Top = 10, Right = 16, Bottom = 16})
                inner:SetBrushColor({R = colour.R, G = colour.G, B = colour.B, A = .9})   -- (the game's counters showed through, VM2 11-20)
                inner:SetPadding({Left = 6, Top = 4, Right = 6, Bottom = 6})
            else
                if frame then outline:SetBrush(frame); outline:SetBrushColor({R = 1, G = 1, B = 1, A = 1})
                else outline:SetBrushColor(OUTLINE) end
                outline:SetPadding({Left = 3, Top = 3, Right = 3, Bottom = 3})
                inner:SetBrushColor({R = colour.R, G = colour.G, B = colour.B, A = .98})   -- (the game's counters showed through, VM2 11-20)
                inner:SetPadding({Left = 12, Top = 8, Right = 12, Bottom = 12})
            end
            outline:SetContent(inner)
            size:SetContent(outline)
            box:SetContent(size)
            w.inner, w.slot, w.box = inner, slot, box
            w.pinned = place and (place.anchored and 'anchor' or place.locked and 'lock') or nil
            w.locked, w.anchored, w.folded = w.pinned ~= nil, w.pinned == 'anchor', place and place.fold or nil
            w.open_height = place and place.open_height or w.open_height
            w.moved, w.rank = false, place and place.rank
            if place and place.x then free(slot, place.x, place.y); w.moved = true end
            w.raise()
            fill()
            open[#open + 1] = w
            arrange()
            input(true)
            if w.paint_icon then w.paint_icon() end
            if opts.focus and focus_left[w.id] ~= false then w.focus(true) end
        end
        function w.close()
            drop()
            unfocus()
            -- Closed, its pages that are out go back with it - except the anchored ones: they stay open.
            for _, out in pairs(outs) do
                if out.owner == w and out.window.shown() and not out.window.anchored then
                    out.window.opts.dismiss()
                    out.window.close()
                end
            end
            if w.state == 'closed' then return end
            R.log('WindowKit', 'Closing window %s', tostring(w.id))
            C.state('WindowKit', 'Window ' .. tostring(w.id), 'closed')
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
        -- The state of the frame's three choices: nil (all three shown), 'lock' or 'anchor' (only that
        -- one shown, lit). Fixed (locked or anchored): no x, no dragging, and the window opens at this
        -- place again; anchored, its owner closing does not close it.
        function w.pin(kind)
            if not w.shown() then return end
            drop()
            if kind then unanchor() end
            local was = w.locked
            w.pinned, w.locked, w.anchored = kind, kind ~= nil, kind == 'anchor'
            -- Fixed: above the windows fixed before it, under all unfixed ones. Unfixed: on top.
            if kind and not was then store.locks = store.locks + 1; w.rank = store.locks
            elseif not kind then w.rank = nil; w.raise() end
            stack(w)
            remember()
            title_bar()
        end
        function w.lock(on) if on then w.pin('lock') elseif w.pinned == 'lock' then w.pin(nil) end end
        function w.anchor(on) if on then w.pin('anchor') elseif w.pinned == 'anchor' then w.pin(nil) end end
        -- Folded: only the title line stays. Up: the top edge stays where it was (the window is placed by
        -- its top). Down: the bottom edge stays - the title line comes down to where the bottom was, and
        -- back up when unfolded. Called again (with either side) it unfolds.
        function w.fold(side)
            if not w.shown() then return end
            drop()
            local to = not w.folded and side or nil
            local down = to == 'down' or w.folded == 'down'
            if down then unanchor() end
            local before = measured(w).Y
            if to == 'down' then w.open_height = before end   -- (its full height, to open to again)
            w.folded = to
            apply_fold()
            if down then
                -- (opening up from the bottom: by the full height it had, not one measured down there, where the
                -- room under it cut the body to a sliver - user 11-21, a spiral window opened as a strip)
                local p = w.slot:GetPosition()
                local after = to == 'down' and measured(w).Y or (w.open_height or measured(w).Y)
                w.slot:SetPosition({X = p.X, Y = p.Y + before - after})
            end
            title_bar()
            remember()
            arrange()
        end
        -- The tool window whose page the marks in the world are of: this one lit, any other out; called
        -- again (false) none is. A window never takes it by itself.
        function w.focus(on)
            if not (w.shown() and opts.focus) or (focused == w) == on then return end
            local was = focused
            focused = on and w or nil
            focus_left[w.id] = on
            if was and was ~= w and on then focus_left[was.id] = false end
            if was then
                if was ~= w then was.paint() end
                if was.opts.on_focus then was.opts.on_focus(false, was) end
            end
            title_bar()
            if on and opts.on_focus then opts.on_focus(true, w) end
        end
        w.paint = function() if w.shown() then title_bar() end end
        -- The help shown on the title bar's "?" (set as the content is built; changed: the bar again).
        function w.help(text)
            if text == w.help_text then return end
            w.help_text = text
            if w.shown() then title_bar() end
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
        -- Builds the content again from the current state (after an action changed it); the pages
        -- out of it are built again too, also when it is closed.
        function w.refresh()
            if w.shown() then
                I.remove(w.content)
                fill()
            end
            for _, out in pairs(outs) do if out.owner == w and out.window.shown() then out.window.refresh() end end
        end

        -- The corner button: exists only where the window is available; one size for every window.
        local function place_icon()
            local wanted = opts.icon and opts.available() and pc() ~= nil
            local present = w.icon_widget and R.valid(w.icon_widget)
            if opts.icon then
                C.state('WindowKit', 'Corner button ' .. tostring(w.id), wanted and 'shown' or 'hidden - ' .. (not opts.available() and 'the window is not available in this session' or 'no local player'))
            end
            if wanted and not present then
                local widget, root = host(870)
                w.icon_widget = widget
                local box
                box, w.icon_slot = scaled(widget.WidgetTree, root, ICON_SCALE)
                w.icon_box = box
                local button = U.button(box, {label = opts.icon, on_click = w.toggle})
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

    -- A section of a window: a heading with a fold arrow at its right and a box for what goes under it
    -- (returned, with a function that shows or hides the whole section). Without opts.label it is a plain
    -- group (UIKit's section). opts.folded: shown folded until the player unfolds it (the arrow remembers).
    function W.section(parent, opts)
        if not (opts and opts.label) then return U.section(parent, opts) end
        local owner = assert(I.owner(parent).window, 'a section with a heading belongs in a window')
        local id = owner.id..' / '..opts.label
        local holder = I.native(parent, 'SizeBox')
        local section = I.native(holder, 'VerticalBox')
        local head = I.native(section, 'HorizontalBox')
        local text = U.fill(U.text(head, {text = opts.label, heading = true}))
        text.Slot:SetHorizontalAlignment(0)
        text.Slot:SetPadding({Left = 0, Top = 0, Right = 0, Bottom = 0})
        local fold = W.bare(head)
        fold.Slot:SetVerticalAlignment(2)
        local mark, arrow = W.arrow(fold)
        mark.Slot:SetPadding({Left = 6, Top = I.HEADING_GAP, Right = 6, Bottom = 0})
        arrow:SetRenderTransformPivot({X = .5, Y = .5})
        local body = I.native(section, 'VerticalBox')
        local function folded(on)
            body:SetVisibility(on and 1 or 0)
            arrow:SetRenderTransformAngle(on and -90 or 0)
        end
        local on = store.folded[id]
        if on == nil then on = opts.folded == true end   -- (opts.folded: folded until the player opens it)
        U.on_press(fold, function()
            on = not on
            store.folded[id] = on
            R.save_settings('UIKit')
            folded(on)
        end)
        folded(on)
        return body, function(visible) holder:SetVisibility(visible and 0 or 1) end
    end

    -- A control that gives its page out (user 11-20: a tool's tile, a tab): a press on it is a click, done
    -- when the button is let go, unless the mouse first moves PULL px with the button held: then
    -- on_pull(mouse) and no click.
    function W.pullable(widget, on_click, on_pull)
        U.on_press(widget, function()
            local function watch(from)
                if not R.native.key_down(LEFT_BUTTON) then return on_click and on_click() end
                local mouse = I.object(layout):GetMousePositionOnViewport(pc())
                from = from or mouse
                if math.abs(mouse.X - from.X) + math.abs(mouse.Y - from.Y) >= PULL then return on_pull(mouse) end
                R.next_frame(function() watch(from) end)
            end
            watch()
        end)
    end
    -- The window of a page of owner, made once per key: title, build(box, window) (the latest given is used),
    -- back() when it is put back (its x). Its place is remembered: kept while anchored.
    function W.pullout(owner, key, title, build, back)
        local id = owner.id .. OUT .. key
        local out = outs[id]
        if not out then
            out = {owner = owner}
            out.window = W.window{id = id, mod = owner.mod, title = title, tint = owner.opts.tint, width = owner.width,
                scale = owner.opts.scale, scale_of = function() return owner.scale end, apart = true, available = owner.opts.available,
                fold_down = owner.opts.fold_down, focus = owner.opts.focus, on_focus = owner.opts.on_focus, focus_on_touch = owner.opts.focus_on_touch,   -- (a page is a tool window too)
                build = function(box, window) out.page(box, window) end,
                dismiss = function()
                    store.windows[id], pulled[id] = nil, nil
                    R.save_settings('UIKit')
                    if out.back then out.back() end
                end}
            outs[id] = out
        end
        out.page, out.back = build, back
        return out.window
    end
    -- The window of that page when it is out (shown), else nil.
    function W.out(owner, key)
        local out = outs[owner.id .. OUT .. key]
        return out and out.window.shown() and out.window or nil
    end
    -- The windows of owner's pages that are out now (anchored ones stay while owner is closed).
    function W.opened(owner)
        local list = {}
        for _, out in pairs(outs) do if out.owner == owner and out.window.shown() then list[#list + 1] = out.window end end
        return list
    end
    -- The keys of owner's pages that stand apart (to be opened again as it is built); stale places go.
    function W.outs(owner)
        local list, prefix = {}, owner.id .. OUT
        for id in pairs(store.windows) do
            if id:sub(1, #prefix) == prefix then
                if W.stays_apart(id) then list[#list + 1] = id:sub(#prefix + 1) else store.windows[id] = nil end
            end
        end
        table.sort(list)
        return list
    end
    -- A page comes out: its window opens under the mouse and is carried by it.
    function W.pull_page(owner, key, title, build, back, mouse)
        local id, grab = owner.id .. OUT .. key, {X = 60, Y = 16}
        R.log('WindowKit', 'Page %s pulled out into a window of its own', id)
        store.windows[id] = {apart = true, x = mouse.X - grab.X, y = mouse.Y - grab.Y}
        pulled[id] = true
        local window = W.pullout(owner, key, title, build, back)
        carried = window
        window.open()
        if not window.shown() then carried = nil; return end
        window.carry(grab)
        if back then back() end
    end

    -- Any press of the left button: the window under the mouse (the topmost there) comes up, unless
    -- it is fixed. (A press on a title, a frame button or a fold arrow is that control's: U.on_press.)
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
        -- (opts.focus_on_touch(): a click anywhere in a tool window makes it the focus - a setting, user 11-21)
        if touched and touched.opts.focus and touched.opts.focus_on_touch and touched.opts.focus_on_touch() then touched.focus(true) end
    end)
    -- Widgets in the viewport go with the world; so do our records of them.
    R.on('world_end', function()
        for _, w in ipairs(windows) do
            w.widget, w.content, w.inner, w.slot, w.box, w.layer_slot, w.state = nil, nil, nil, nil, nil, nil, 'closed'
            w.icon_widget, w.icon_slot, w.icon_box, w.paint_icon = nil, nil, nil, nil
        end
        if release_wheel then release_wheel() end
        open, saved, carried, release_wheel, layer, layer_root, focused = {}, nil, nil, nil, nil, nil, nil
        frame_brush, frame_colour, frame_looked = nil, nil, false
    end)
end
