-- The player's match settings between launches (Core's RememberSettings, one switch for every mod).
-- Each game mode of Custom Match keeps what its screen shows: its controls' values, its map, and every
-- mod's rules (owners registered here); Creative keeps its own. The first time a screen opens in a
-- launch it is as last hosted; switching the mode keeps the old mode and brings back the new one's.
-- Off, everything kept is forgotten and nothing is kept.
--   C.memory.on()                 whether settings are remembered
--   C.memory.keep(key,value)      keep a screen's own choice (while on); C.memory.kept(key)
--   C.memory.register(id,owner)   a mod's rules of a mode: owner.save(options,mode) -> rules (mode: the game
--                                 mode's path the record is for - the options may already show the next one), owner.load(rules or nil,
--                                 options): options, the match options the screen's mode is kept from and brought to
--   C.memory.shown_by(control,fn)  a game's control a mod hides and shows its option itself:
--                                 fn(w) -> whether the mod's control stands in for it on screen w
--   C.memory.switch(w,change)     the Custom Match screen's mode changes by a mod's control: change()
--                                 makes it; the old mode is kept and the new one brought back
return function(R,C)
    local config=C.mods.config
    local M={}
    local LAYOUT,MAP=C.LAYOUT.file,C.MAP.file
    -- Each control of a screen and the option it sets. A control the screen hides for the mode is
    -- not kept, so a hidden value (Tournament in Fill a Pot) never comes back.
    local CONTROLS={
        match={CheckBox_EnableIdleKick='EnableIdleKick',CheckBox_LiveRuleEditing='IsLiveGameRuleEditingAllowed',
            CheckBox_Public='IsPublic',CheckBox_RecordingMode='IsRecordingMode',CheckBox_ShowAlliedWitches='ShowAllyWitches',
            CheckBox_SpecatorsCanSeeWitches='SpectatorsCanSeeWitches',CheckBox_DisableStartTimer='DisableStartMatchTimer',
            CheckBox_TournamentMode='IsTournamentMode',Slider_TournamentHunters='TournamentHuntersCount',
            Slider_HideTime='HideTime',Slider_SearchTime='SeekTime',Slider_MaxPlayers='MaxPlayers',
            Slider_HunterRatio='MaxRandomHuntersPercental',Slider_RequiredPlayersPerTeam='RequiredPlayersPerTeam',
            Slider_WitchLives='WitchLives',ComboBox_TeamChoice='TeamSwitchingOption',Slider_ImpostorTasks='ImpostorTasks',
            Slider_ImpostorCooldown='ImpostorTransformCooldown',Slider_ImpostorWitches='ImpostorWitchAmount'},
        creative={CheckBox_Public='IsPublicCreative',Slider_MaxPlayers='MaxPlayers'},
    }
    local text=R.text
    local standins={}   -- game control -> fn(w): a mod's control shows its option instead
    function M.shown_by(control,fn) standins[control]=fn end
    function M.on() return config.RememberSettings==true end
    -- The record, always whole (a saved one may lack its modes: only Creative kept, or an empty table not
    -- written back by the settings file; live VM1 11-20 'Core stopped working' choosing a mode).
    local function kept()
        config.remembered=config.remembered or {}
        config.remembered.modes=config.remembered.modes or {}
        return config.remembered
    end
    function M.keep(key,value) if M.on() then kept()[key]=value;R.save_settings('Core') end end
    function M.kept(key) return M.on() and config.remembered and config.remembered[key] or nil end
    R.options(function(rows,U)
        -- (user 11-20: the box did not say it is the one for each mode's own rules)
        return {(U.checkbox(rows,{label='Remember each mode',value=M.on(),
            tooltip='Each game mode keeps its own Custom Match settings and Match Rules ++ rules, also after a restart. Off: every mode starts with the game\'s own.',on_change=function(on)
            config.RememberSettings=on
            if not on then config.remembered=nil end
            R.save_settings('Core')
        end}))}
    end)
    local owners={}
    function M.register(id,owner) owners[id]=owner end
    -- A mode: the game's mode and the mod mode its options choose (Fill a Pot and Fill a Pot+ are two).
    local function path(options) return options.GameMode:GetFullName():match('(%S+)$') end
    function M.mode_key(options)
        local chosen=C.map.chosen(options)
        return path(options)..(chosen and '+'..chosen or '')
    end
    -- old: the record this one replaces (the same mode's): a control not shown at this moment keeps the
    -- value it had there (live 11-20: kept as the screen was left, the controls were already hidden and
    -- the Fill a Pot+ record lost all but two of its values - the screen then opened with the game's own).
    -- mode: the game mode's path the record is for (live 11-20: kept as the mode changes, the options
    -- already held the new mode, and Match Rules ++ marked Fill a Pot+'s rules Hunt a Hag's).
    local function snapshot(which,w,options,old,mode)
        -- (Creative's mode is the game's own, and its map and saved layout are the ones just picked in its
        -- list before its screen opens: only a Custom Match record keeps a mode, a map and a layout)
        local match=which=='match'
        local record={mode=match and (mode or path(options)) or nil,vanilla=config[C.mods.VANILLA[which].key],map=match and text(options.MapData[MAP]) or nil,fields={},rules={}}
        if match and options.CustomMapSelected then record.layout=text(options.LayoutData[LAYOUT]) end
        for control,name in pairs(CONTROLS[which]) do
            if w[control]:IsVisible() or standins[control] and standins[control](w) then record.fields[name]=options[name]
            elseif old and old.fields then record.fields[name]=old.fields[name] end
        end
        if which=='match' then for id,owner in pairs(owners) do record.rules[id]=owner.save(options,record.mode) end end
        return record
    end
    -- record nil: a mode never kept (its controls as the game sets them, the mods' rules their defaults).
    local function bring(which,gi,options,record)
        record=record or {fields={},rules={}}
        if record.vanilla~=nil then C.mods.set_vanilla(which,record.vanilla) end
        for _,name in pairs(CONTROLS[which]) do
            if record.fields[name]~=nil then options[name]=record.fields[name] end
        end
        local manager=gi.MapManager
        local map=which=='match' and record.map and manager.MapDataByFileName:Contains(record.map) and manager.MapDataByFileName:Find(record.map):get()
        local layout
        if which=='match' and record.layout then
            -- (saved maps are known once the game reads their folder)
            manager:SetLayoutDataByFileName()
            if manager.LayoutDataByFileName:Contains(record.layout) then
                layout=manager.LayoutDataByFileName:Find(record.layout):get()
            end
        end
        if map or layout then C.catalog.choose(options,map or options.MapData,layout) end
        if which=='match' then for id,owner in pairs(owners) do owner.load(record.rules[id],options) end end
    end
    local function target(which,gi) return which=='creative' and gi.CreativeMatchOptions or gi.NextMatchOptions end
    local GP=StaticFindObject('/Script/Engine.Default__GameplayStatics')
    local screens={}
    -- Hosting: the mode as hosted, and which was hosted last.
    R.pre('/Game/Blueprints/Core/B_GameInstance.B_GameInstance_C:HostGame',function(gi)
        if not M.on() then return end
        local which=gi.UsedMatchOptions:GetAddress()==gi.CreativeMatchOptions:GetAddress() and 'creative' or 'match'
        local w=R.valid(screens[which])
        if not w then return end
        local options=target(which,gi)
        local store=kept()
        if which=='creative' then store.creative=snapshot(which,w,options,store.creative)
        else local key=M.mode_key(options);store.modes[key]=snapshot(which,w,options,store.modes[key]);store.last=key end
        R.save_settings('Core')
    end)
    -- The first time a screen opens this launch: the mode last hosted, as hosted.
    local restored={}
    local function restore(which,w)
        if restored[which] or not M.on() or not config.remembered then return end
        restored[which]=true
        local store=kept()
        local record=which=='creative' and store.creative or store.last and store.modes[store.last]
        if not record then return end
        local gi=GP:GetGameInstance(w)
        local options=target(which,gi)
        local mode=which=='match' and R.valid(R.native.load_asset(record.mode))
        if mode then options:SetGameMode(mode) end
        bring(which,gi,options,record)
        -- (user 11-20: the screen opened with the game's defaults; the log tells what was brought)
        R.log('Core','Remembered %s (%s): hide %s, search %s, rules editing %s, idle kick %s',which,tostring(store.last),
            tostring(options.HideTime),tostring(options.SeekTime),tostring(options.IsLiveGameRuleEditingAllowed),tostring(options.EnableIdleKick))
    end
    -- Play's Creative button uses NextMatchOptions as a scratch buffer for its map list (it copies
    -- Creative's options over it; CloseMapList sets Hide and Seek): the Custom Match draft waits in
    -- the game's CustomMatchOptions meanwhile. (CopyMatchOptions omits SpectatorsCanSeeWitches.)
    local away=false
    -- Leaving the Custom Match screen for another menu keeps what it shows now (its mode's record),
    -- also without hosting or a change of mode (set below, with the screen's mode handling).
    local keep_screen
    local function copy(to,from)
        to:CopyMatchOptions(from)
        to.SpectatorsCanSeeWitches=from.SpectatorsCanSeeWitches
    end
    R.pre('/Game/UserInterface/Play/WB_Play.WB_Play_C:BndEvt__CreativeMode_K2Node_ComponentBoundEvent_1_Clicked__DelegateSignature',function(w)
        if not M.on() then return end
        local gi=GP:GetGameInstance(w)
        copy(gi.CustomMatchOptions,gi.NextMatchOptions)
        away=true
    end)
    R.pre('/Game/Blueprints/UserInterface/B_MenuUIManager.B_MenuUIManager_C:ChangeMenu',function(ui,state)
        -- (not while Creative borrows the next match's options: they are its scratch then)
        if not away then keep_screen() end
        if not away or state~=7 and state~=9 and state~=1 then return end
        away=false
        local gi=GP:GetGameInstance(ui)
        if M.on() then copy(gi.NextMatchOptions,gi.CustomMatchOptions) end
    end)
    local custom='/Game/UserInterface/Play/WB_Custommatch.WB_Custommatch_C:'
    -- The game's own loader shows every option of the screen but these two: their boxes stay as
    -- built, unchecked, while the options (what is hosted) are on.
    -- (controls named; their options are CONTROLS's - audit 11-20: the pairs were written again here)
    local UNSHOWN={'CheckBox_SpecatorsCanSeeWitches','CheckBox_DisableStartTimer'}
    local shown   -- the mode the screen's list shows
    local function showing(w) shown=text(w.ComboBox_GameMode.SelectedOption) end
    R.post(custom..'LoadCustomMatchOptions',function(w)
        showing(w)
        if not M.on() then return end
        for _,box in ipairs(UNSHOWN) do w[box]:SetIsCheckedWithoutEvent(w.NextMatchOptions[CONTROLS.match[box]]==true) end
    end)
    local current   -- {key, mode, screen}: the mode the Custom Match screen shows
    local function ours(w) return not w.InGame and M.on() end
    R.pre(custom..'Construct',function(w)
        if w.InGame then return end
        screens.match=w
        restore('match',w)
    end)
    R.post(custom..'Construct',function(w)
        if ours(w) then
            local o=w.NextMatchOptions
            current={key=M.mode_key(o),mode=path(o),screen=w:GetAddress()}
            R.log('Core','Custom Match shows %s: hide %s, search %s, rules editing %s, idle kick %s',current.key,
                tostring(o.HideTime),tostring(o.SeekTime),tostring(o.IsLiveGameRuleEditingAllowed),tostring(o.EnableIdleKick))
        end
    end)
    -- What the screen shows, kept for the mode it shows.
    local function keep(w)
        if not current or current.screen~=w:GetAddress() then return end
        local record=snapshot('match',w,w.NextMatchOptions,kept().modes[current.key],current.mode)
        kept().modes[current.key]=record
        R.save_settings('Core')
    end
    -- The screen shows the options' mode now: its own values come back over the game's defaults; a
    -- new mode is loaded into the screen (loading writes the defaults again: they come back the same,
    -- no second load; live 11-19 it looped).
    -- The game writes Hide and Seek's times for the map whenever the screen updates (SetHideAndSeekTimes,
    -- also after a mode's own were brought back: Hide Time 55 showed 25, live VM2 11-19): while a mode
    -- is being brought back (this frame), its own times go back into the options and their sliders.
    local bringing
    local TIMES={'Slider_HideTime','Slider_SearchTime'}
    R.post(custom..'SetHideAndSeekTimes',function(w)
        if not (bringing and ours(w)) then return end
        for _,slider in ipairs(TIMES) do
            local name=CONTROLS.match[slider]
            local v=bringing.fields[name]
            if v~=nil then w.NextMatchOptions[name]=v;w[slider]:SetRealValue(v) end
        end
    end)
    local function arrive(w)
        local options=w.NextMatchOptions
        local key,back=M.mode_key(options),current and current.screen==w:GetAddress()
        local new=not (back and current.key==key)
        current={key=key,mode=path(options),screen=w:GetAddress()}
        if not back then return end   -- (a screen being built: restore() brought the mode last hosted)
        bring('match',GP:GetGameInstance(w),options,kept().modes[key])
        if new then
            bringing=kept().modes[key];R.next_frame(function() bringing=nil end)
            showing(w);w:LoadCustomMatchOptions()
            -- (the rules screens show and change the menu world's rule values, one set for every mode: the
            -- mode's own rules brought into the options go into them too, the game's own way - user 11-20:
            -- gravity stayed the last mode's, a switched-off spell came back on)
            w:LoadGameRules()
        end
    end
    -- The game writes a mode's defaults into the options whenever a mode is chosen (in this one place):
    -- before, the mode shown is kept; after, the chosen mode's own come back.
    R.pre(custom..'SetGameModeDefaultValues',function(w) if ours(w) then keep(w) end end)
    R.post(custom..'SetGameModeDefaultValues',function(w) if ours(w) then arrive(w) end end)
    -- Loading options selects their mode in the list again, which the game handles as a choice (its
    -- defaults again): a choice of the mode the list already shows changes nothing.
    local CHANGE=custom..'BndEvt__ComboBox_GameMode_K2Node_ComponentBoundEvent_0_OnSelectionChanged__DelegateSignature'
    R.pre(CHANGE,function(w) if ours(w) and text(w.ComboBox_GameMode.SelectedOption)==shown then return true end end)
    -- The Vanilla server box chooses the mod mode (no defaults of the game's): kept and brought the same.
    function M.switch(w,change)
        local on=ours(w)
        if on then keep(w) end
        change()
        if on then arrive(w) end
    end
    keep_screen=function() local w=R.valid(screens.match);if w then keep(w) end end
    -- The screens are the world's: a menu screen of the world left behind is not the one shown (live
    -- 11-20: leaving a match, the lobby's old Custom Match screen was kept, and its rules read from
    -- the match's ending world stopped Core).
    R.on('world_end',function() screens,current={},nil end)
    R.pre('/Game/UserInterface/CreativeMode/WB_CreativeGame.WB_CreativeGame_C:Construct',function(w)
        screens.creative=w
        restore('creative',w)
    end)
    return M
end
