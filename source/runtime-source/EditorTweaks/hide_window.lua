-- The hide window (Creative host, outside Playtest): aim, hide, undo, the nearby scenery with
-- Hide each, the hidden objects with Show each, and Show all. It is built again when the
-- hidden set or the aim changes.
-- api: ensure_edit, edit, edit_group, inventory, key, on_change (see package.lua). aim: aim.lua.
return function(W, C, Objects, api, aim)
    local NEARBY = 12
    local function editing()
        local c = C.session()
        return C.owns(c) and c.mode == 'creative' and not c.is_playtest
    end
    local function line(list, row, label, action)
        local row_widgets = W.flow(list)
        W.fill(W.text(row_widgets, {text = Objects.label(row), wrap = false}))
        W.button(row_widgets, {label = label, on_click = action})
    end
    local window
    window = W.window{title = 'Hide objects', icon = 'Hide', tint = {R = .02, G = .05, B = .045}, width = 440,
        available = editing,
        build = function(box, w)
            local s = api.ensure_edit()
            if not s then W.text(box, {text = 'Hiding is off for this map.'}); return end

            local aiming = W.flow(box)
            W.checkbox(aiming, {label = 'Aim', value = aim.on(), columns = true,
                on_change = function(on) if on ~= aim.on() then aim.toggle() end end})
            local _, name = W.text(aiming, {text = aim.label(), wrap = false})
            aim.show(name)
            local actions = W.flow(box)
            W.button(actions, {label = 'Hide', on_click = aim.hide})
            W.button(actions, {label = 'Undo', on_click = aim.undo})

            local header = W.flow(box)
            W.fill(W.text(header, {text = 'Nearby', heading = true}))
            W.button(header, {label = 'Refresh', on_click = function() w.refresh() end})
            local near = W.scroll(box, {height = 200})
            for _, row in ipairs(api.inventory(NEARBY)) do
                if not s.data.hidden[api.key(row)] then
                    line(near, row, 'Hide', function() aim.release(); api.edit(row, true) end)
                end
            end

            local hidden = {}
            for _, row in pairs(s.data.hidden) do hidden[#hidden + 1] = row end
            table.sort(hidden, function(a, b) return Objects.label(a) < Objects.label(b) end)
            W.text(box, {text = 'Hidden: '..#hidden, heading = true})
            local list = W.scroll(box, {height = 160})
            for _, row in ipairs(hidden) do
                line(list, row, 'Show', function() aim.release(); api.edit(row, false) end)
            end
            W.button(box, {label = 'Show all', enabled = #hidden > 0,
                on_click = function() aim.release(); api.edit_group(hidden, false) end})
        end,
        on_close = function() aim.show(nil) end}
    api.on_change(function() window.refresh() end)
    aim.watch(function() window.refresh() end)
    return window
end
