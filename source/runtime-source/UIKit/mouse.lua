-- The mods' mouse presses, in one place: a press of the left button goes to the one control under
-- the mouse that takes presses (the innermost: a fold arrow in a window, not the window), then to
-- what watches every press (a window coming up, an open list closing).
-- U.on_press(widget, fn(), opts): fn at a press on the widget. opts.area: the widget is found by the
-- mouse's place on it (a box the engine does not hit-test, as the colour picker's), else by the
-- engine's hover (which knows what covers it). A widget gone is dropped.
-- U.on_any_press(fn()): fn at every press, after the control's.
-- U.under(widget, area): is the mouse on this widget, shown?
return function(R, C, U, I)
    local LEFT = R.codes.LEFT_MOUSE
    local layout = '/Script/UMG.Default__WidgetLayoutLibrary'
    local targets, watchers = {}, {}
    -- Shown: it and every widget around it visible (a closed window, a folded section: not shown).
    local function shown(w)
        for _ = 1, 40 do
            if not R.valid(w) then return true end
            if not w:IsVisible() then return false end
            w = w:GetParent()
        end
        return true
    end
    local function mouse()
        local player = R.valid(C.session().pc)
        return player and I.object(layout):GetMousePositionOnViewport(player)
    end
    local function rect(w) return R.native.widget_rect(w) end
    function U.under(widget, area)
        if not (R.valid(widget) and shown(widget)) then return false end
        if not area then return widget:IsHovered() end
        local m, r = mouse(), rect(widget)
        return m ~= nil and m.X >= r.left and m.X <= r.right and m.Y >= r.top and m.Y <= r.bottom
    end
    function U.on_press(widget, fn, opts)
        targets[#targets + 1] = {widget = widget, fn = fn, area = opts and opts.area}
    end
    function U.on_any_press(fn) watchers[#watchers + 1] = fn end
    R.native.on_input(function(code)
        if code ~= LEFT then return end
        local best, size
        for i = #targets, 1, -1 do
            local t = targets[i]
            if not R.valid(t.widget) then table.remove(targets, i)
            elseif U.under(t.widget, t.area) then
                local r = rect(t.widget)
                local s = (r.right - r.left) * (r.bottom - r.top)
                if not best or s < size then best, size = t, s end
            end
        end
        if best then R.call(best.fn) end
        for _, fn in ipairs(watchers) do R.call(fn) end
    end)
end
