-- Colour places: a colour of a panel that a mod's colour window may edit. The mod with the colour
-- announces it (U.colour_place(place)) as it builds the panel; a mod with a colour window (Creative
-- Tools) hears it (U.on_colour_place(fn)) and puts its button by it. Without such a mod nothing is
-- added. place = {widget (the colour's own square), title, get() -> {R, G, B} (its strength in its
-- size), set({R, G, B}), strength = nil or {max, label, scale, fmt, step}: how strong it may be, as typed}.
return function(R, C, U)
    local listeners = {}
    function U.on_colour_place(fn) listeners[#listeners + 1] = fn end
    function U.colour_place(place) for _, fn in ipairs(listeners) do R.call(fn, place) end end
    -- The colour of a place changed (U.colour_changed(widget), by the mod whose colour it is): a colour
    -- window showing it follows (U.on_colour_change(fn(widget))).
    local changes = {}
    function U.on_colour_change(fn) changes[#changes + 1] = fn end
    function U.colour_changed(widget) for _, fn in ipairs(changes) do R.call(fn, widget) end end
end
