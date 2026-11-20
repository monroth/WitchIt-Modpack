return function(R, C, U, I)
    -- A page in the game's Settings switcher, as large as the game's own pages: the page, its body.
    local function settings_page(switcher)
        local page = I.native(switcher, 'ScaleBox')
        page:SetStretch(2)
        local bounds = I.native(page, 'SizeBox')
        bounds:SetWidthOverride(1380)
        bounds:SetHeightOverride(720)
        return page, U.section(bounds, {})
    end
    -- A tab button of the game's tab bar (its class and place, as the Game tab's).
    local function tab_button(screen, bar, label, on_click)
        local button = U.button(bar, {class=screen.TabButton_Game:GetClass(), label=label, on_click=on_click})
        I.slot_apply(button.Slot, I.slot_values(screen.TabButton_Game.Slot))
        return button
    end
    local settings_class = '/Game/UserInterface/Settings/WB_SettingsTabs.WB_SettingsTabs_C'
    local directory = debug.getinfo(1, 'S').source:match('^@(.+[\\/])')..'../'
    local policy = C.mods.config
    I.mod_pages = dofile(directory..'UIKit/modscreen.lua')(R, C, U, I)
    -- The first mod failure of a run, as a window in the main menu: in a match it would
    -- take the controls.
    local failure
    local function showFailure()
        if not failure then return end
        -- (one file to send: the logs and the mods' settings - user 11-20)
        U.question('Mod error',failure,function(yes)
            if yes then U.message('Bug report','Saved to:\n'..C.save_report()..'\n\nSend this file to the modpack author.') end
        end)
        failure=nil
    end
    R.on('failure',function()
        local id=next(C.mods.failed)
        failure=(R.manifests[id] and R.mod_name(id) or 'A mod')..' stopped working. Restart the game.\n\nSave a bug report to send to the modpack author?'
        local gi=C.session().gi
        if gi and not gi.IsCurrentlyInMatch then R.next_frame(showFailure) end
    end)
    -- (a join Core refused before it began - the mods differ: told at once)
    R.pre('/Game/Blueprints/Core/B_GameInstance.B_GameInstance_C:JoinFromServerList', function()
        if C.mods.refusal then
            local reason=C.mods.refusal;C.mods.refusal=nil
            R.next_frame(function() U.message('Could not join',reason) end)
        end
    end)
    R.post('/Game/UserInterface/WB_MainMenu.WB_MainMenu_C:Construct', function()
        if C.mods.refusal then
            local reason=C.mods.refusal;C.mods.refusal=nil
            R.next_frame(function() U.message('Could not join',reason) end)
        end
        R.next_frame(showFailure)
    end)
    -- The Mods screen (one state, audit D14): mods = {phase, record}: 'asked' (the Settings menu is on
    -- its way) or 'open' (shown); a change to another menu ends either (an ask left behind would build
    -- the Mods screen into the game's own Settings opened later).
    local mods
    local function opened() return mods and mods.phase == 'open' and mods.record or nil end
    local options_tab   -- (below: the Settings' Mods tab)
    local function build(record, screen)
        record.screen, record.hidden = screen, {}
        local function title(widget)
            if widget:IsA(I.object('/Script/UMG.TextBlock')) then
                if I.string(widget:GetText())=='Settings' then return widget end
            elseif widget:IsA(I.object('/Script/UMG.PanelWidget')) then
                for _,child in ipairs(I.values(widget:GetAllChildren())) do local found=title(child);if found then return found end end
            end
        end
        record.title=title(screen.WidgetTree.RootWidget)
        if record.title then record.title:SetText(FText('Mods')) end
        local switcher = screen.SettingsSwitcher
        record.previous = switcher:GetActiveWidget()
        local page, root = settings_page(switcher)
        record.page = page
        local function checkbox(parent,opts,width)
            width=width or 950
            local cells=U.row(parent,{width-52,52})
            U.text(cells[1],{text=opts.label,width=width-64})
            opts.box=true
            local widget,set=U.checkbox(cells[2],opts)
            widget.DescriptiveLabelText:GetParent():SetVisibility(1)
            local glyph=widget.CheckBox;local grid=glyph:GetParent()
            for column=0,2 do grid:SetColumnFill(column,0) end
            glyph.Slot:SetColumn(0);glyph.Slot:SetPadding({Left=0,Top=0,Right=0,Bottom=0})
            glyph.Slot:SetHorizontalAlignment(1);glyph.Slot:SetVerticalAlignment(2)
            cells[2]:SetHeightOverride(48)
            return widget,set
        end
        local function separator(parent)
            local box=I.native(parent,'SizeBox');box:SetHeightOverride(1)
            I.native(box,'Image'):SetOpacity(.2)
        end
        local tabbar = screen.TabButton_Game:GetParent()
        for _, widget in ipairs(I.values(tabbar:GetAllChildren())) do
            record.hidden[#record.hidden + 1] = {widget=widget, visibility=widget:GetVisibility()}
            widget:SetVisibility(1)
        end
        record.hidden[#record.hidden + 1] = {widget=screen.Button_Apply, visibility=screen.Button_Apply:GetVisibility()}
        screen.Button_Apply:SetVisibility(1)
        local tabs = I.mod_pages(root, checkbox, separator)
        record.tabs = {}
        local function show_tab(chosen)
            for index, tab in ipairs(tabs) do
                tab[2]:GetParent():SetVisibility(index == chosen and 0 or 1)
                record.tabs[index]:SetActiveState(index == chosen)
            end
        end
        for index, tab in ipairs(tabs) do
            record.tabs[index] = tab_button(screen, tabbar, tab[1], function() show_tab(index) end)
        end
        show_tab(1)
    end
    local function finish(manager)
        local record = mods and mods.record
        if not record or manager.CurrentMenuState ~= 11 then return end
        local screen = I.menu_screen(manager, 11)
        if not screen then return end
        if mods.phase == 'asked' then
            mods.phase = 'open'
            build(record, screen)
        end
        screen.SettingsSwitcher:SetActiveWidget(record.page)
        I.focus(record.tabs[1], screen)
    end
    local function close()
        local record = opened()
        mods = nil
        if not record then return end
        if record.title then record.title:SetText(FText('Settings')) end
        for _, entry in ipairs(record.hidden) do entry.widget:SetVisibility(entry.visibility) end
        for _, tab in ipairs(record.tabs) do
            I.actions[I.id(tab)] = nil
            I.remove(tab)
        end
        record.screen.SettingsSwitcher:SetActiveWidget(record.previous)
        I.remove(record.page)
        I.restore_after_close(record.saved)
    end
    U.menu_entry('WB_MainMenu', 'Settings', 'Mods', function(origin)
        local manager = I.object('/Script/Engine.Default__GameplayStatics'):GetGameInstance(origin).MenuUIManager
        local saved = I.snapshot(origin)
        mods = {phase = 'asked', record = {saved=saved}}
        I.change_menu(manager,11,function() finish(manager) end)
    end)
    -- The main menu tells what waits for a restart: mods switched on or off, or downloaded ones.
    R.post('/Game/UserInterface/WB_MainMenu.WB_MainMenu_C:Construct',function(screen)
        local state=I.state(screen)
        if not state.update_notice then state.update_notice=select(2,U.text(screen.Settings:GetParent(),{text='',width=400})) end
        local status=C.mods.status()
        local kind=status.update and status.update.kind
        state.update_notice(status.restart_required and 'Restart the game to apply changes.'
            or kind=='downloaded' and 'Mods downloaded. Restart the game to use them.' or kind=='updated' and 'Mods updated.' or '')
    end)
    R.post(I.path('B_MenuUIManager', 'ChangeMenu', I.managers), function(manager)
        if manager.CurrentMenuState == 11 then finish(manager) elseif mods then close() end
    end)
    R.post(settings_class..':FocusStoredWidget', function(screen)
        options_tab(screen)
        finish(I.object('/Script/Engine.Default__GameplayStatics'):GetGameInstance(screen).MenuUIManager)
    end)
    R.post(settings_class..':GetInitialFocusWidget', function(screen, out)
        finish(I.object('/Script/Engine.Default__GameplayStatics'):GetGameInstance(screen).MenuUIManager)
        if opened() then out:set(opened().tabs[1]) end
    end)
    -- The game's Settings get a last tab, Mods: every mod's options under its name (R.options).
    -- Picking it shows its page; picking a game tab leaves it. (The Mods screen above reuses this
    -- screen with the game's tabs hidden, this one too.)
    function options_tab(screen)
        if opened() and opened().screen == screen then return end
        local state = I.state(screen)
        if state.options_tab and R.valid(state.options_tab.button) then return end
        local tabbar, switcher = screen.TabButton_Game:GetParent(), screen.SettingsSwitcher
        local page, body = settings_page(switcher)
        local options = U.scroll(body, {height=684})
        -- The mods' groups in the order of their names.
        local groups = {}
        for _, group in ipairs(R.option_groups()) do groups[#groups + 1] = group end
        local function heading(group) return group.title or R.mod_name(group.id) end
        table.sort(groups, function(a, b) return heading(a) < heading(b) end)
        if #groups == 0 then U.text(U.section(options, {}), {text='No mod options yet.'}) end
        local controls = {}
        for _, group in ipairs(groups) do
            local rows = U.section(options, {})
            U.text(rows, {text=heading(group), heading=true})
            for _, control in ipairs(group.build(rows, U)) do controls[#controls + 1] = control end
        end
        U.navigate(controls, options)
        local tabs, tabClass = I.values(tabbar:GetAllChildren()), screen.TabButton_Game:GetClass()
        local button = tab_button(screen, tabbar, 'Mods', function()
            for _, tab in ipairs(tabs) do if R.valid(tab) and tab:IsA(tabClass) then tab:SetActiveState(false) end end
            state.options_tab.button:SetActiveState(true)
            switcher:SetActiveWidget(page)
        end)
        state.options_tab = {button=button, page=page}
    end
    R.post(settings_class..':Construct', options_tab)
    R.post(settings_class..':SetActiveSettingsTab', function(screen)
        if opened() then screen.SettingsSwitcher:SetActiveWidget(opened().page);return end
        local tab = I.state(screen).options_tab
        if tab and R.valid(tab.button) then tab.button:SetActiveState(false) end
    end)
    R.post('/Game/UserInterface/CreativeMode/WB_CreativeGame.WB_CreativeGame_C:Construct', function(screen)
        local state = I.state(screen)
        if not state.creative_vanilla then
            local widget, set = U.checkbox(screen.CheckBox_Public:GetParent(), {
                label='Vanilla server', value=policy.CreativeVanillaServer, default=C.mods.VANILLA.creative.default,
                on_change=function(value) C.mods.set_vanilla('creative', value) end})
            widget.Slot:SetPadding(screen.CheckBox_Public.Slot.Padding)
            state.creative_vanilla = {widget=widget, set=set}
        end
        state.creative_vanilla.set(policy.CreativeVanillaServer)
    end)
    local custom = I.play..'WB_Custommatch.WB_Custommatch_C'
    local function custom_match(screen)
        local state = I.state(screen)
        if not state.vanilla then
            -- It also chooses the mode (a mode module's, such as Fill a Pot+ on Fill a Pot, is played
            -- on a server that is not vanilla): a change of mode, which Core's memory follows.
            -- Turned on, it takes back a chosen map that needs a module (the mode's default instead).
            local widget, set = U.checkbox(screen.CheckBox_DisableStartTimer:GetParent(), {
                label='Vanilla server', value=policy.VanillaServer, default=C.mods.VANILLA.match.default,
                on_change=function(value)
                    C.memory.switch(screen, function() C.mods.set_vanilla('match', value) end)
                    local options = screen.NextMatchOptions
                    if value and next(C.catalog.chosen_needs(options)) then
                        C.catalog.unpick(options)
                        screen:SetGameModeDefaultValues(false)
                    end
                    screen:UpdateWidgetVisibility()
                end})
            state.vanilla = {widget=widget, set=set}
        end
        local session = C.session()
        -- A saved map the chosen mode does not play (left by another screen or mode: the screens share
        -- the options) is taken back for the mode's own default.
        local options = screen.NextMatchOptions
        if not screen.InGame and options.CustomMapSelected and not C.catalog.plays(options) then
            C.catalog.unpick(options)
            screen:SetGameModeDefaultValues(false)
            screen:UpdateWidgetVisibility()
        end
        state.vanilla.widget:SetIsEnabled(session.role ~= 'host')
        if session.role == 'host' then state.vanilla.set(session.is_vanilla_session) else state.vanilla.set(policy.VanillaServer) end
    end
    for _, event in ipairs({'Construct', 'LoadCustomMatchOptions', 'UpdateWidgetVisibility',
        'BndEvt__ComboBox_GameMode_K2Node_ComponentBoundEvent_0_OnSelectionChanged__DelegateSignature'}) do
        R.post(custom..':'..event, function(screen)
            custom_match(screen)
        end)
    end
    C.on_session(function()
        for _, screen in ipairs(R.find_all(custom)) do custom_match(screen) end
    end)
    I.resets[#I.resets + 1] = function() mods = nil end
end
