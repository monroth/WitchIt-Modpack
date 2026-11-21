return function(R, C, U, I)
    local list = I.play..'WB_ServerList.WB_ServerList_C'
    local row = I.play..'WB_ServerRow.WB_ServerRow_C'
    local mods = C.mods
    local unreadable = C.mods.INCOMPATIBLE
    -- The modpack advert of a listed server, and whether the server carries one at all.
    local function advertisement(data)
        local entries, key = data.ExtraSettings, FName('WitchItModpack')
        if not entries:Contains(key) then return nil, entries:Contains(FName('WitchItModpackSession')) end
        local bytes = I.string(entries:Find(key):get().Data.AsString)
        if #bytes > 16384 then return nil, true end
        return mods.parse_advert(bytes), true
    end
    local function describe(host)
        local local_versions, lines, compatible = {}, {}, true
        for _, package in ipairs(mods.status().packages) do
            local wire = mods.wires[package.id]
            if wire and package.enabled then local_versions[wire] = package.version end
        end
        -- The mods the host requires in its session (user 11-21: only those - a mod of this player's the host does
        -- not have plays as on a vanilla server here, nothing to show).
        local all = {}
        for wire in pairs(host.required) do if wire ~= 'core' then all[#all + 1] = wire end end
        table.sort(all)
        if #all == 0 then lines[1] = {text = 'No mods needed.'} end
        for _, id in ipairs(all) do
            local remote, own = host.packages[id], local_versions[id]
            local required = host.required[id]
            local name = mods.wire_name(id)
            -- A mod that matches is just named; a difference shows both sides on one line (user 11-21), red until
            -- the host's sources are read, then yellow if it can be downloaded (choose()).
            if own == remote then lines[#lines + 1] = {text = name..' '..own}
            else
                lines[#lines + 1] = {text = name..' '..(remote or 'none')..', yours '..(own or 'none'), red = true, differs = true, wire = id}
                if required then compatible = false end
            end
        end
        return lines, compatible
    end
    local rowViews={}
    local function row_state(widget)
        local data=widget.ServerRowDataObject
        for _,owner in pairs(I.screens) do
            local state=owner.browser
            -- The list can close while a search is still reporting rows.
            if state and R.valid(state.screen) then
                for _,found in ipairs(I.values(state.screen.FoundServers)) do
                    if I.id(found)==I.id(data) then return state end
                end
            end
        end
    end
    local function enable_row(record)
        local widget=record.widget;local state=row_state(widget)
        if state and state.modded then
            widget.SelectServer:SetIsEnabled(true);record.overridden=true
        elseif record.overridden then
            widget.SelectServer:SetIsEnabled(widget:Get_SelectServer_bIsEnabled_0());record.overridden=false
        end
    end
    -- The list's rows are pooled widgets the game may also drop without releasing them: a row gone
    -- is forgotten here.
    local function refresh_rows()
        for id,record in pairs(rowViews)do
            if R.valid(record.widget) then enable_row(record) else rowViews[id]=nil end
        end
    end
    R.post(row..':SetWidgetValues',function(widget)
        local record=rowViews[I.id(widget)] or {widget=widget}
        rowViews[I.id(widget)]=record;enable_row(record)
    end)
    -- In the Modded tab every server is modded: names go without the mark.
    R.post(row..':GetServerName',function(widget)
        local state=row_state(widget)
        if state and state.modded then return FText(mods.clean_name(I.string(widget.ServerRowDataObject:GetServerName()))) end
    end)
    R.post(row..':BP_OnEntryReleased',function(widget)
        local record=rowViews[I.id(widget)]
        if record and record.overridden then widget.SelectServer:SetIsEnabled(widget:Get_SelectServer_bIsEnabled_0()) end
        rowViews[I.id(widget)]=nil
    end)
    R.pre('/Script/UMG.UserWidget:Destruct',function(widget)rowViews[I.id(widget)]=nil end)
    I.resets[#I.resets+1]=function()rowViews={}end
    local function join(state)
        local data, gi = state.selected, I.object('/Script/Engine.Default__GameplayStatics'):GetGameInstance(state.screen)
        local entries, key = data.ExtraSettings, FName('IsPasswordProtected')
        local locked = entries:Contains(key) and entries:Find(key):get().Data.AsBool
        R.log('UIKit', 'Join %s: %s', mods.clean_name(I.string(data:GetServerName())), locked and 'asking the password' or 'joining')
        state.notice(locked and '' or 'Joining…')
        if locked then gi.MenuUIManager:ShowPasswordDialog(data.OnlineSession)
        else gi:JoinFromServerList(data.OnlineSession) end
    end
    -- Taking a host's mods: read them, ask, download (how far, while it runs), then restart the game - and
    -- join it again when join is given ({name, menu}). Nothing is taken unless every mod the host requires
    -- can be had. notice(text): where progress is told. The one window for every way in (user 11-21: the
    -- Modded tab's Join, a server clicked in the game's own tabs, a join Core refused - an invite, a friend,
    -- a password - each said it its own way): what differs is said here, the same lines as the Modded tab's.
    -- (The only timer: once a second while the download runs, never after.)
    function I.offer_host_mods(host, notice, join)
        local differ = {}
        for _, line in ipairs(describe(host)) do if line.differs then differ[#differ + 1] = line.text end end
        local reasons = table.concat(differ, '\n')
        local again = join and ' and join '..join.name or ''
        local function take(prepared)
            C.mods.take_host(prepared, function(ok, why)
                if not ok then R.log('UIKit', 'Host mods not downloaded: %s', tostring(why)); U.message('Mods', why); return end
                R.log('UIKit', 'Downloading the host\'s mods')
                notice('Downloading the host’s mods…')
                local running = true
                local function show()
                    if not running then return end
                    local p = C.mods.progress()
                    if p and p.total and p.total > 0 then
                        notice('Downloading the host’s mods: '..math.min(p.done + 1, p.total)..' of '..p.total..'…')
                    end
                    R.after(1000, show)
                end
                R.after(1000, show)
                R.native.on_update(function()
                    running = false
                    local update = C.mods.status().update
                    local kind = update and update.kind
                    R.log('UIKit', 'Download finished: %s', tostring(kind))
                    notice('')
                    if kind ~= 'downloaded' and kind ~= 'current' then U.message('Mods', 'The mods could not be downloaded.'); return end
                    U.question('Mods', 'The host’s mods are ready. Restart the game now'..again..'?', function(yes)
                        if yes then C.mods.relaunch(join, kind == 'downloaded')
                        else U.message('Mods', 'The host’s mods are used from the next start of the game.') end
                    end)
                end)
            end, true)
        end
        notice('Reading the host’s mods…')
        R.log('UIKit', 'Join: other mods than the host; reading the host’s')
        C.mods.prepare_host(host, function(prepared)
            notice('')
            R.log('UIKit', 'Join: host’s mods read; cannot be had: %s', #prepared.missing > 0 and table.concat(prepared.missing, ', ') or 'none')
            if #prepared.missing > 0 then
                U.message('Mods', 'These mods of the host cannot be downloaded, so the game cannot join it:\n'..table.concat(prepared.missing, '\n'))
                return
            end
            local from = host.sources and host.sources ~= '' and '\n\nThe host’s mods:\n'..host.sources or ''
            U.question('Mods', reasons..from..'\n\nDownload the host’s mods and restart the game'..again..'?', function(yes)
                if yes then take(prepared) end
            end)
        end)
    end
    local function ask_and_join(state)
        I.offer_host_mods(state.host, state.notice, {name = state.host.name, menu = C.mods.menu()})
    end
    local function clear(state)
        state.selected, state.host = nil, nil
        state.info({{text = 'Select a server to see its mods.'}})
        state.join:SetIsEnabled(false)
    end
    local function choose(state, data)
        local host = advertisement(data)
        if host then host.name = mods.clean_name(I.string(data:GetServerName())) end
        state.selected, state.host = data, host
        R.log('UIKit', 'Server selected: %s (%s)', tostring(host and host.name), host and 'modpack advert read' or 'no readable modpack advert')
        -- (each mod a white line "name version"; a red one, the host's version and yours, where they differ)
        local rows, compatible = {{text = mods.clean_name(I.string(data:GetServerName()))}, {text = ''}}, false
        if host then
            local lines
            lines, compatible = describe(host)
            for _, line in ipairs(lines) do rows[#rows + 1] = line end
        else rows[#rows + 1] = {text = unreadable} end
        state.info(rows)
        state.compatible = compatible
        state.join:SetIsEnabled(host ~= nil)
        -- (user 11-21: a difference that can be downloaded yellow, one that cannot red - the host's sources tell)
        local differs = false
        for _, row in ipairs(rows) do differs = differs or row.differs end
        if host and differs then
            C.mods.prepare_host(host, function(prepared)
                if state.selected ~= data then return end
                for _, row in ipairs(rows) do
                    if row.differs then row.red = prepared.blocked[row.wire] == true; row.yellow = not row.red end
                end
                state.info(rows)
            end)
        end
    end
    local function results(state)
        local selected
        for _, data in ipairs(I.values(state.screen.FoundServers)) do
            if state.selected and I.id(state.selected) == I.id(data) then selected=data end
        end
        if selected then choose(state, selected) else clear(state) end
        refresh_rows()
        -- Back after a restart for a server's mods: join it as soon as the list has it.
        if state.joining then
            for _, data in ipairs(I.values(state.screen.FoundServers)) do
                if mods.clean_name(I.string(data:GetServerName())) == state.joining.name then
                    state.joining = nil
                    C.mods.take_join()
                    choose(state, data)
                    if state.compatible then join(state) end
                    return
                end
            end
        end
    end
    R.post(list..':ServerPassesCurrentFilter',function(screen,data,out)
        if mods.console_only(data) then out:set(false);return end
        local owner=I.screens[I.id(screen)]
        if owner and owner.browser and owner.browser.modded then
            local _,present=advertisement(data)
            out:set(out:get() and present)
        end
    end)
    -- The servers looked for (the game's filter tab or Modded, and the order) are remembered
    -- (Core's remembered settings) and back the first time the list opens in a launch.
    local function keep(screen, state)
        C.memory.keep('servers', {filter=screen.CurrentFilter, modded=state.modded==true, sort=screen.SortMode, reverse=screen.ReverseSort})
    end
    local function construct(screen)
        local state = I.state(screen)
        if state.browser then return end
        state.browser = {screen=screen}
        state = state.browser
        local root = screen.WidgetTree.RootWidget
        local body = screen.ServerListView
        while I.id(body:GetParent()) ~= I.id(root) do body = body:GetParent() end
        state.body = body
        local offsets, anchors = body.Slot:GetOffsets(), body.Slot:GetAnchors()
        state.wide = {Left=offsets.Left, Top=offsets.Top, Right=offsets.Right, Bottom=offsets.Bottom}
        state.narrow = {Left=offsets.Left, Top=offsets.Top,
            Right=offsets.Right + (anchors.Maximum.X > anchors.Minimum.X and 460 or -460), Bottom=offsets.Bottom}
        local panel = I.native(root, 'Border')
        state.panel = panel
        -- (the panel wears the list's own frame: the nearest Border around the list, as the game
        -- draws it; a plain dark plate only where the list has none)
        local border, frame = I.object('/Script/UMG.Border'), screen.ServerListView
        while R.valid(frame) and I.id(frame) ~= I.id(root) and not frame:IsA(border) do frame = frame:GetParent() end
        if R.valid(frame) and frame:IsA(border) then panel:SetBrush(frame.Background);panel:SetBrushColor(frame.BrushColor)
        else panel:SetBrushColor({R=.025,G=.035,B=.05,A=.97}) end
        panel:SetPadding({Left=18,Top=16,Right=18,Bottom=16})
        panel.Slot:SetAnchors({Minimum={X=1,Y=.28},Maximum={X=1,Y=.90}})
        panel.Slot:SetOffsets({Left=-450,Top=0,Right=440,Bottom=0})
        panel.Slot:SetZOrder(20)
        local content = U.section(panel, {})
        local info = U.scroll(content, {height=450})
        local info_rows = U.section(info, {})
        local lines = {}
        function state.info(rows)
            for _, widget in ipairs(lines) do I.remove(widget) end
            lines = {}
            for _, row in ipairs(rows) do
                -- (a mod one line, never two - user 11-21: a longer one is cut at the panel's edge, whole when pointed at)
                local widget = U.text(info_rows, {text = row.text, width = 400, wrap = false})
                widget:SetClipping(1)
                widget:SetToolTipText(FText(row.text))
                if row.red then widget:SetColorAndOpacity({SpecifiedColor = {R = 1, G = .3, B = .3, A = 1}, ColorUseRule = 0})
                elseif row.yellow then widget:SetColorAndOpacity({SpecifiedColor = {R = 1, G = .85, B = .3, A = 1}, ColorUseRule = 0}) end
                lines[#lines + 1] = widget
            end
        end
        state.join = U.button(content, {label='Join', on_click=function()
            if state.compatible then join(state) else ask_and_join(state) end
        end})
        local _, notice = U.text(content, {text='',width=400})
        state.notice = notice
        function state.open()
            state.modded = true
            state.internal = true
            R.finally(function() screen:ChangeFilter(0) end, function() state.internal = nil end)
            screen.ServerListView:SetVisibility(0)
            body.Slot:SetOffsets(state.narrow)
            panel:SetVisibility(0)
            state.tab:SetActiveState(true)
            results(state)
        end
        state.tab = U.button(screen.Button_Filter_All:GetParent(), {class=screen.Button_Filter_All:GetClass(), label='Modded', on_click=function()
            state.open();keep(screen, state)
        end})
        I.slot_apply(state.tab.Slot, I.slot_values(screen.Button_Filter_All.Slot))
        panel:SetVisibility(1)
        clear(state)
    end
    I.destructors[#I.destructors + 1] = function(state)
        if state.browser then
            state.browser.modded=false;refresh_rows()
            state.browser.body.Slot:SetOffsets(state.browser.wide)
            state.screen.ServerListView:SetVisibility(0)
        end
    end
    local restored=false
    local function restore(screen)
        if restored then return end
        restored=true
        local kept=C.memory.kept('servers')
        if not kept then return end
        screen.SortMode, screen.ReverseSort = kept.sort, kept.reverse
        local state=I.screens[I.id(screen)].browser
        if kept.modded then state.open() elseif kept.filter~=screen.CurrentFilter then screen:ChangeFilter(kept.filter) end
    end
    R.post(list..':Construct', function(screen)
        construct(screen);restore(screen)
        local join = C.mods.pending_join()
        if join then
            local state = I.screens[I.id(screen)].browser
            state.joining = join;state.open()
        end
    end)
    -- After a restart for a server's mods, the menus go straight to the server list: on the main
    -- menu and on every change of menu after it (a notice on the way takes the first one), until
    -- the list has taken the join.
    -- (only once the game is signed in online: a search before that finds nothing)
    local online = false
    local function instance(object) return I.object('/Script/Engine.Default__GameplayStatics'):GetGameInstance(object) end
    local function back(gi, state)
        local join = C.mods.pending_join()
        if not join or not join.menu or state == join.menu then return end
        if not online then
            local connected = {}; gi.Connectivity:IsConnectedTo(1, connected)
            online = connected.IsConnected == true
            if not online then return end
        end
        R.log('UIKit', 'Back to the server list (menu %s) to join %s', tostring(join.menu), tostring(join.name))
        R.after(300, function() if R.valid(gi) then gi.MenuUIManager:ChangeMenu(join.menu, true) end end)
    end
    for _, event in ipairs({'EOSLoginCompleted', 'BackendLoginCompleted'}) do
        R.post('/Game/Blueprints/Core/B_GameInstance.B_GameInstance_C:'..event, function(gi)
            online = true
            back(gi)
        end)
    end
    R.post('/Game/UserInterface/WB_MainMenu.WB_MainMenu_C:Construct', function(w) back(instance(w)) end)
    R.post('/Game/Blueprints/UserInterface/B_MenuUIManager.B_MenuUIManager_C:ChangeMenu', function(manager, state)
        back(instance(manager), state)
    end)
    -- The server list's events, for the list our browser is on.
    local function browser(screen) local state = I.screens[I.id(screen)]; return state and state.browser end
    R.post(list..':SortBy', function(screen) local b = browser(screen); if b then keep(screen, b) end end)
    R.post(list..':AddServersSorted', function(screen) local b = browser(screen); if b then results(b) end end)
    R.post(list..':RemoveAllServers', function(screen) local b = browser(screen); if b then clear(b) end end)
    R.post(list..':UpdateTabButtonStyles', function(screen)
        local b = browser(screen); if b then b.tab:SetActiveState(b.modded == true) end
    end)
    R.post(list..':ChangeFilter', function(screen)
        local state = browser(screen)
        if not state or state.internal then return end
        state.modded = false
        refresh_rows()
        state.panel:SetVisibility(1)
        state.tab:SetActiveState(false)
        screen.ServerListView:SetVisibility(0)
        state.body.Slot:SetOffsets(state.wide)
        keep(screen, state)
    end)
    for _, event in ipairs({'ClickedServer', 'ProceedJoin', 'BndEvt__Button_534_K2Node_ComponentBoundEvent_280_OnButtonClickedEvent__DelegateSignature'}) do
        R.pre(row..':'..event, function(widget)
            local data, state = widget.ServerRowDataObject, row_state(widget)
            -- (everything a clicked server tells of itself: to learn what marks an official one - user 11-21)
            local told = {}
            data.ExtraSettings:ForEach(function(key, value)
                local d = value:get().Data
                told[#told + 1] = key:get():ToString()..'='..(d.Type == 6 and I.string(d.AsString) or tostring(d.AsInt)..'/'..tostring(d.AsBool))
            end)
            table.sort(told)
            R.log('UIKit', 'Server clicked: %s - %s', I.string(data:GetServerName()), table.concat(told, ', '))
            if state and state.modded then choose(state, data); return true end
            local host, present = advertisement(data)
            if not present then return end
            if not host then R.log('UIKit', 'Join blocked: the modpack advert cannot be read'); U.message('Mods', unreadable); return true end
            local _, compatible = describe(host)
            if not compatible then
                -- (the host's mods offered at once, as the Modded tab's Join does - user 11-21: here only a list came)
                R.log('UIKit', 'Join: mods differ from the host\'s - offering its mods')
                host.name = mods.clean_name(I.string(data:GetServerName()))
                I.offer_host_mods(host, function(t) if t ~= '' then R.log('UIKit', 'Join: %s', t) end end, {name = host.name, menu = C.mods.menu()})
                return true
            end
        end)
    end
end
