-- The Mods screen's pages (screens.lua opens it): General (playing together, safe mode, failures,
-- logs) and Mods (what is installed: version, whether it runs, what it does; a report link).
-- Switching mods on and off, versions, sources and presets are the launcher's (user 11-16).
return function(R, C, U, I)
    local function save() R.save_settings('Core') end
    local failures = C.mods.failed   -- mod -> why it stopped (this launch)
    local function page(root, fill)
        local scroll = U.scroll(root, {height = 684})
        fill(U.section(scroll, {}))
        return scroll
    end

    return function(root, checkbox, separator)
        local config = C.mods.config
        local general = page(root, function(body)
            if #C.mods.updates > 0 then
                U.text(body, {text = 'Updates in the Witch It+ launcher: '..table.concat(C.mods.updates, ', '), note = true})
                separator(body)
            end
            U.text(body, {text = 'When something is wrong', heading = true})
            checkbox(body, {label = 'Safe mode: next start without mods', value = config.safe_mode == true,
                on_change = function(v) config.safe_mode = v; R.log('UIKit', 'Safe mode for the next start: %s', v and 'on' or 'off'); save() end})
            if next(failures) then
                for id, why in pairs(failures) do U.text(body, {text = R.mod_name(id)..' stopped: '..why, note = true}) end
            else U.text(body, {text = 'No mod failed this launch.', note = true}) end
            local tools = U.flow(body)
            U.button(tools, {label = 'Save logs for a report', on_click = function()
                R.log('UIKit', 'Saving logs for a report')
                U.message('Bug report', 'Logs saved to:\n'..C.save_report()..'\n\nTell us what you saw and attach this file.')
            end})
            U.button(tools, {label = 'Open the mods folder', on_click = function() R.log('UIKit', 'Opening the mods folder'); os.execute('start "" "ue4ss\\Mods"') end})
            U.button(tools, {label = 'Open the logs folder', on_click = function() R.log('UIKit', 'Opening the logs folder'); os.execute('start "" "ue4ss"') end})
        end)
        local mods = page(root, function(body)
            local header = U.row(body, {500, 250, 250, 200})
            -- (every mod here is on: one switched off in the launcher is not in the game at all)
            for i, title in ipairs({'Mod', 'Version', '', ''}) do U.text(header[i], {text = title, note = true}) end
            local rows = C.mods.status().packages
            table.sort(rows, function(a, b) return a.name < b.name end)
            for _, row in ipairs(rows) do
                local cells = U.row(body, {500, 250, 250, 200})
                U.text(cells[1], {text = row.name})
                U.text(cells[2], {text = row.version})
                if failures[row.id] then U.text(cells[3], {text = 'Failed'}) end
                local about = (R.manifests[row.id] or {}).description
                if about and about ~= '' then U.text(body, {text = about, note = true}) end
                -- A problem with it: its repository's issues in the browser.
                if row.source then
                    U.button(cells[4], {label = 'Report', tooltip = 'Opens github.com/'..row.source..'/issues: tell what happened (and attach the logs saved on the General page).',
                        on_click = function() R.log('UIKit', 'Opening the issues page of %s', row.source); os.execute('start "" "https://github.com/'..row.source..'/issues"') end})
                end
                separator(body)
            end
        end)
        return {{'General', general}, {'Mods', mods}}
    end
end
