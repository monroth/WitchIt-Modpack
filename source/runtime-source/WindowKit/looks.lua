-- The looks of a window's controls by what they are (user 11-20: every tab, switch and action was the same
-- purple game button, though each meant something else; prototype2.html gives each kind its own look):
--   W.tab     a tab: plain text, the open one bright with a bar under it
--   W.tile    a tool in a list: its name on a row, the chosen one on a lit plate
--   W.action  a second action: its name on a dark plate (the page's main action alone stays the game's
--             own purple button, W.button)
-- Each returns the widget and set(on, label): lit or not, and a new name.
return function(R, C, U, I, W)
    local DIM, BRIGHT = {R = .62, G = .56, B = .78, A = 1}, {R = .97, G = .95, B = 1, A = 1}
    local ACCENT = {R = .66, G = .47, B = 1, A = 1}
    -- (prototype2.html's colours: a second action dark with a purple edge, the chosen tool lit with a light edge)
    -- (user 11-20 "still a site of the 90s": prototype2.html's own colours, each kind as it has it)
    local PLATE, PLATE_EDGE = {R = .165, G = .098, B = .341, A = 1}, {R = .435, G = .314, B = .722, A = 1}   -- (.btn)
    local TAB, TAB_EDGE = {R = .086, G = .059, B = .149, A = 1}, {R = .227, G = .165, B = .388, A = 1}       -- (.tab)
    local TAB_ON, TAB_ON_EDGE = {R = .24, G = .137, B = .47, A = 1}, {R = .616, G = .451, B = .918, A = 1}   -- (.tab.on)
    local TILE, TILE_EDGE = {R = .31, G = .15, B = .6, A = .55}, {R = .616, G = .451, B = .918, A = .55}     -- (.t)
    local TILE_ON, TILE_ON_EDGE = {R = .48, G = .27, B = .84, A = 1}, {R = .957, G = .843, B = .478, A = 1}  -- (.t.on)
    -- (the page's main action: the one bright button - live VM2 11-20 the game's lit button stayed dark inside)
    local MAIN, MAIN_EDGE = {R = .55, G = .31, B = .88, A = 1}, {R = .79, G = .65, B = 1, A = 1}           -- (.primary)
    local NONE = {R = 0, G = 0, B = 0, A = 0}
    local function colour(c) return {SpecifiedColor = c, ColorUseRule = 0} end
    -- (opts.apart: its page is out in a window of its own - the name stays, faint)
    local function faint(c, apart) return apart and {R = c.R, G = c.G, B = c.B, A = .4} or c end
    -- A button without the game's plate or padding: it takes the mouse, it draws nothing itself.
    function W.bare(parent)
        local button = I.native(parent, 'Button')
        button:SetBackgroundColor(NONE)
        local style = button.WidgetStyle
        style.NormalPadding, style.PressedPadding = {Left = 0, Top = 0, Right = 0, Bottom = 0}, {Left = 0, Top = 0, Right = 0, Bottom = 0}
        button.WidgetStyle = style
        return button
    end
    -- A plate with rounded corners and an edge (user 11-20: plain filled boxes looked like a site of the 90s).
    local function plate_of(parent, tab)
        local plate = I.native(parent, 'Border')
        plate.Background.DrawAs = 4   -- (a rounded box)
        local o = plate.Background.OutlineSettings
        o.CornerRadii = tab and {X = 8, Y = 8, Z = 0, W = 0} or {X = 6, Y = 6, Z = 6, W = 6}   -- (a tab: round on top)
        o.RoundingType = 0
        o.Width = 2
        return plate
    end
    local function paint(plate, fill, edge)
        plate:SetBrushColor(fill)
        plate.Background.OutlineSettings.Color = colour(edge)
    end
    -- kind: 'tab' | 'tile' | 'action'; opts: label, tooltip, on_click, active
    local function make(kind, parent, opts)
        local button = W.bare(parent)
        if opts.tooltip then button:SetToolTipText(FText(opts.tooltip)) end
        local plate = plate_of(button, kind == 'tab')
        plate:SetPadding(kind == 'tab' and {Left = 16, Top = 5, Right = 16, Bottom = 5}
            or kind == 'tile' and {Left = 6, Top = 6, Right = 6, Bottom = 6}
            or kind == 'main' and {Left = 22, Top = 7, Right = 22, Bottom = 7} or {Left = 12, Top = 5, Right = 12, Bottom = 5})
        local column = I.native(plate, 'VerticalBox')
        -- (a tile with a picture: the picture alone, its name in the tooltip - prototype2's tool tiles)
        local text, picture
        if opts.image then
            local size = I.native(column, 'SizeBox')
            size:SetWidthOverride(opts.size or 34); size:SetHeightOverride(opts.size or 34)
            picture = I.native(size, 'Image')
            picture:SetBrushFromTexture(opts.image, false)
        else text = U.text(column, {text = opts.label or '', wrap = false}) end
        local function set(on, label)
            if label and text then text:SetText(FText(label)) end
            if kind == 'tab' then
                text:SetColorAndOpacity(colour(faint(on and BRIGHT or DIM, opts.apart)))
                paint(plate, on and TAB_ON or TAB, on and TAB_ON_EDGE or TAB_EDGE)
            elseif kind == 'tile' then
                if text then text:SetColorAndOpacity(colour(faint(on and BRIGHT or DIM, opts.apart))) end
                if picture then picture:SetColorAndOpacity(faint(opts.gold and on and {R = 1, G = .85, B = .2, A = 1} or {R = 1, G = 1, B = 1, A = on and 1 or .75}, opts.apart)) end
                paint(plate, on and TILE_ON or TILE, on and TILE_ON_EDGE or TILE_EDGE)
            elseif kind == 'main' then
                text:SetColorAndOpacity(colour(BRIGHT))
                paint(plate, MAIN, MAIN_EDGE)
            else
                text:SetColorAndOpacity(colour(BRIGHT))
                paint(plate, PLATE, PLATE_EDGE)
            end
        end
        set(opts.active == true)
        -- (in a row: centred on its height; in a column: at the left, as wide as its name - a tile the column's width)
        local slot = button.Slot
        slot:SetVerticalAlignment(2)
        slot:SetHorizontalAlignment(kind == 'tile' and 0 or 1)
        -- (opts.on_pull(mouse): pulled out - the click then comes on letting go, W.pullable)
        if opts.on_pull then W.pullable(button, opts.on_click, opts.on_pull)
        elseif opts.on_click then U.on_press(button, opts.on_click) end
        return button, set
    end
    function W.tab(parent, opts) return make('tab', parent, opts) end
    function W.tile(parent, opts) return make('tile', parent, opts) end
    function W.action(parent, opts) return make('action', parent, opts) end
    function W.main(parent, opts) return make('main', parent, opts) end
end
