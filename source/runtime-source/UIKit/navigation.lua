return function(R, C, U, I)
    local rules = I.play..'GameRules/'
    local class = rules..'WB_GameRulesTabs.WB_GameRulesTabs_C'
    local declarations = {}
    -- The Game Rules screen a mod opened (one state, audit D13): nav = {phase, record}; phase 'opening'
    -- (asked, the menu not there yet), 'open' (open from another menu: leaving it goes back there),
    -- 'closing' (the game's own Back goes back; the input comes back when it is there). nil: none.
    local nav
    local cancelTransition
    -- The row each native panel carries, by panel address and caption. A cached screen
    -- keeps its rows after Lua forgets the screen, so this table outlives every world.
    local rows={}
    -- ChangeMenu may run InitializeGameModes; never nest it inside a hook.
    function I.change_menu(manager, target, done)
        if cancelTransition then cancelTransition() end
        cancelTransition=R.next_frame(function()
            cancelTransition=nil
            if not R.valid(manager) then return end
            manager:ChangeMenu(target,true)
            if done then done() end
        end)
    end
    local function class_path(id)
        if id:sub(1, 1) == '/' then return id:gsub(':.*$', '') end
        local folder = id == 'WB_MainMenu' and '/Game/UserInterface/' or I.play
        return folder..id..'.'..id..'_C'
    end
    local function navigation(widget,direction,target)
        widget:SetNavigationRuleExplicit(direction,target)
        local inner=widget.ButtonRef
        if R.valid(inner) then inner:SetNavigationRuleExplicit(direction,target) end
    end
    -- A menu row right under the anchor row of a native screen; on_click receives the clicked
    -- button. The native rows after the anchor move after it with the same slot values, so the
    -- menu's own layout places everything, whatever the game shows or hides later.
    -- room names a hidden native widget whose blank space the row takes, for a menu
    -- with no spare height (Creative, PROBE16). when, if given, says whether this session has
    -- the row; caption, if given, gives its current label.
    function U.menu_entry(screen_id, anchor, text, on_click, room, when, caption)
        local path = class_path(screen_id)
        local function click(button)
            on_click(button)
            if caption then I.caption(button,caption()) end
        end
        -- Its caption, the room it takes and keyboard steps to the rows shown around it.
        local function refresh(screen)
            local button=I.state(screen).menus[text]
            if not button then return end
            if caption then I.caption(button,caption()) end
            local blank=room and screen[room]
            if blank and blank:GetVisibility()==2 then blank:SetVisibility(1) end
            local template,row=screen[anchor],button:GetParent()
            navigation(template,3,button);navigation(button,2,template)
            local found=false
            for _,child in ipairs(I.values(template:GetParent():GetAllChildren())) do
                if found and child:GetVisibility()~=1 then navigation(button,3,child);navigation(child,2,button);break end
                if I.id(child)==I.id(row) then found=true end
            end
        end
        local function construct(screen)
            if when and not when() then return end
            local state=I.state(screen)
            -- A cached screen returns with a new wrapper.
            state.screen=screen
            if state.menus[text] then refresh(screen);return end
            local template=screen[anchor]
            local parent=template:GetParent()
            local key=I.id(parent)..text
            for _,row in ipairs(I.values(parent:GetAllChildren())) do
                if I.id(row)==rows[key] then
                    local button=row:GetChildAt(0)
                    I.own(parent,row);I.own(row,button)
                    I.action(button,{click=click})
                    state.menus[text]=button
                    refresh(screen);return
                end
            end
            local row=I.native(parent,'SizeBox')
            rows[key]=I.id(row)
            local button=U.button(row,{class=template:GetClass(),label=text,on_click=click})
            I.slot_apply(row.Slot,I.slot_values(template.Slot))
            state.menus[text]=button
            U.place_after(row,template)
            refresh(screen)
        end
        -- Rows move before the screen's Construct: the game then sets its rows' texts (Creative's
        -- UpdateButtonTexts) on them where they stand (a row added again takes its designed text).
        R.pre(path..':Construct', construct)
        R.post(path..':Construct', refresh)
        -- Native visibility can change before focus returns: keyboard steps follow it.
        R.post(path..':GetInitialFocusWidget',function(screen) refresh(screen) end)
        for _, screen in ipairs(R.find_all(path)) do construct(screen) end
    end
    -- More tabs than the row holds: it shows a window of them and two arrows move it.
    local VISIBLE_TABS=7
    local function paint_tabs(screen)
        local state=I.state(screen)
        local buttons=I.values(screen.Buttons)
        if #buttons<=VISIBLE_TABS then return end
        if not state.tab_arrows then
            state.tab_first=1
            local bar=screen.TabButton_Mods:GetParent()
            local function step(by)
                return function()
                    state.tab_first=math.max(1,math.min(state.tab_first+by,#I.values(screen.Buttons)-VISIBLE_TABS+1))
                    paint_tabs(screen)
                end
            end
            state.tab_arrows={U.button(bar,{label='<',on_click=step(-1)}),U.button(bar,{label='>',on_click=step(1)})}
        end
        for index,button in ipairs(buttons) do
            button:SetVisibility(index>=state.tab_first and index<state.tab_first+VISIBLE_TABS and 0 or 1)
        end
    end
    -- Whether the mods' rule tabs can be changed now (U.rules_view(fn): Match Rules ++ says, by
    -- who is looking at which rules); a tab about the viewer's own choices (declaration.guest) can.
    local editable = function() return true end
    function U.rules_view(fn) editable = fn end
    local function show(tab, declaration)
        if tab.refresh then tab.refresh() end
        tab.rows:SetIsEnabled(declaration.guest or editable())
    end
    local function add_tab(screen, declaration)
        local state = I.state(screen)
        local built = state.tabs[declaration]
        if built then
            show(built, declaration)
            return
        end
        if not state.rule_arrays then state.rule_arrays={buttons=I.values(screen.Buttons),pages=I.values(screen.RuleTabs)} end
        local scroll = U.scroll(screen.RulesSwitcher, {})
        local rows = U.section(scroll, {})
        local button = U.button(screen.TabButton_Mods:GetParent(), {label = declaration.label,
            on_click = function()
                screen:SetActiveTab(scroll)
                show(state.tabs[declaration], declaration)
            end})
        I.slot_apply(button.Slot, I.slot_values(screen.TabButton_Mods.Slot))
        local tab = {page = scroll, rows = rows, button = button}
        state.tabs[declaration] = tab
        local buttons, pages = I.values(screen.Buttons), I.values(screen.RuleTabs)
        buttons[#buttons + 1], pages[#pages + 1] = button, scroll
        I.array(screen.Buttons, buttons)
        I.array(screen.RuleTabs, pages)
        -- A build can return a function that repaints the tab each time it opens.
        tab.refresh = declaration.build(rows,scroll)
        show(tab, declaration)
        screen:UpdateTabButtonStyles()
        paint_tabs(screen)
    end
    local function construct(screen)
        for _, declaration in ipairs(declarations) do add_tab(screen, declaration) end
    end
    -- A mod's tab in the game's Game Rules, named after the mod; U.open_rules(origin, tab) opens it.
    function U.rules_tab(screen_id, build, opts)
        local declaration = {id = screen_id, label = opts and opts.label or R.mod_name(R.owner('UIKit')), build = build, guest = opts and opts.guest}
        -- The mods' tabs stand in the order of their names, as the mods are listed everywhere.
        local at = #declarations + 1
        for i, other in ipairs(declarations) do if declaration.label < other.label then at = i; break end end
        table.insert(declarations, at, declaration)
        for _, screen in ipairs(R.find_all(class)) do add_tab(screen, declaration) end
        return declaration
    end
    local function finish(manager)
        if not (nav and nav.phase == 'opening') or manager.CurrentMenuState ~= nav.record.target then return end
        local pending = nav.record
        local screen = I.menu_screen(manager, pending.target)
        if not screen then return end
        construct(screen)
        local page = pending.page
        for declaration, tab in pairs(I.state(screen).tabs) do
            if declaration == page then
                screen:SetActiveTab(tab.page)
                I.focus(I.initial(tab.rows) or tab.button,screen)
            end
        end
        nav = pending.own and {phase = 'open', record = pending} or nil
    end
    function U.open_rules(origin, page)
        local saved = I.snapshot(origin)
        local pc, gi = saved.pc, saved.gi
        local manager, target, family = gi.MenuUIManager, nil, {}
        manager.MenuStateClasses:ForEach(function(key, value)
            local widget_class = value:get()
            if R.valid(widget_class) then
                local name = I.string(widget_class:GetFName())
                if widget_class:GetFullName():find('/Game/UserInterface/Play/GameRules/', 1, true) then family[key:get()] = true end
                if name == 'WB_GameRulesTabs_C' then target = key:get() end
            end
        end)
        assert(target, 'Native Game Rules menu is unavailable')
        local pending = nav and nav.phase == 'open' and nav.record or {target=target, previous=manager.CurrentMenuState,
            saved=saved, family=family, manager=manager, ingame=gi.IngameUIManager, own=manager.CurrentMenuState ~= target}
        nav = {phase = 'opening', record = pending}
        pending.page = page
        if manager.CurrentMenuState ~= target then
            pending.subordinate = not pc:IsA(I.object('/Game/Blueprints/Player/B_MenuPlayerController.B_MenuPlayerController_C'))
            if pending.subordinate then
                gi.IngameUIManager:OpenSubordinateMenu(true)
            end
            I.change_menu(manager,target,function() finish(manager) end)
        else finish(manager) end
    end
    local function active(screen)
        local state = I.screens[I.id(screen)]
        if not state then return end
        local address = I.id(screen.RulesSwitcher:GetActiveWidget())
        for _, tab in pairs(state.tabs) do
            if I.id(tab.page) == address then
                return I.initial(tab.rows, true) or I.initial(tab.rows) or tab.button
            end
        end
    end
    R.post(class..':Construct', construct)
    R.post(class..':GetInitialFocusWidget', function(screen, out)
        local widget = active(screen)
        if widget then out:set(widget) end
    end)
    R.post(class..':HandleRefocus', function(screen)
        local widget = active(screen)
        if widget and not widget:HasFocusedDescendants() then I.focus(widget, screen) end
    end)
    R.pre(I.path('B_MenuUIManager', 'ChangeMenu', I.managers), function(manager, target)
        if nav and nav.phase == 'open' and not nav.record.family[target] then
            local record = nav.record
            nav = nil
            -- Native Back owns this transition and its synchronous asset loads.
            -- Keep its return context until the native cleanup has completed.
            if target == record.previous then nav = {phase = 'closing', record = record}; return end
            I.change_menu(manager,record.previous,function()
                if record.subordinate then record.ingame:CloseSubordinateMenu() end
                I.restore_after_close(record.saved)
            end)
            return true
        end
    end)
    R.post(I.path('B_MenuUIManager', 'ChangeMenu', I.managers), function(manager)
        finish(manager)
        -- (closing waits until the menu is back where it was: the native Back may get there in more
        -- than one change; a new opening replaces it)
        if nav and nav.phase == 'closing' and manager.CurrentMenuState == nav.record.previous then
            local record = nav.record
            nav = nil
            I.restore_after_close(record.saved)
        end
    end)
    I.destructors[#I.destructors+1]=function(state)
        if state.rule_arrays then
            I.array(state.screen.Buttons,state.rule_arrays.buttons)
            I.array(state.screen.RuleTabs,state.rule_arrays.pages)
        end
    end
    I.resets[#I.resets + 1] = function() if cancelTransition then cancelTransition();cancelTransition=nil end;nav = nil end
end
