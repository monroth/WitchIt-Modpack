return function(S)
    local R,C,U = S.R,S.C,S.U
    local PKG='FillAPotPlus'
    -- The criteria a winner is decided by, and their order (a text rule: a list of all six; the
    -- ones left out: a list of fewer).
    -- Each one: its key, its name, and the game's reason number the result screen shows - one table
    -- (audit 11-20: the keys were in four tables and their count written as 6).
    local CRITERIA = {{key='wins',label='Halves won',reason=1},{key='pots',label='Full cauldrons',reason=7},
        {key='lives',label='Witch lives remaining',reason=4},{key='kills',label='Hunter kills',reason=6},
        {key='time',label='Time',reason=2},{key='props',label='Delivered props',reason=5}}
    local criteria = {}
    for _,c in ipairs(CRITERIA) do criteria[c.key]=c.label end
    local function order(value)
        local rows, seen = {},{}
        for k in value:gmatch('[^,]+') do
            if not criteria[k] or seen[k] then return end
            seen[k]=true; rows[#rows+1]=k
        end
        if #rows==#CRITERIA then return rows end
    end
    local function off(value)
        local set,count={},0
        for k in value:gmatch('[^,]+') do
            if not criteria[k] or set[k] then return end
            set[k]=true;count=count+1
        end
        if count<#CRITERIA then return set end
    end
    -- Fill a Pot+'s rules (Core's rules). 'custom': on the Custom Match screen; 'own': its tab.
    -- Live ones apply at once; the others from the next match.
    local function number(key,label,lo,hi,step,initial,slider,extra)
        local spec={key=key,label=label,kind='number',min=lo,max=hi,step=step,initial=initial,page='none',
            sliderMin=slider and slider[1],sliderMax=slider and slider[2],integer=step>=1}
        for k,v in pairs(extra or {}) do spec[k]=v end
        return spec
    end
    local function bool(key,label,initial,extra)
        local spec={key=key,label=label,kind='bool',initial=initial,page='none'}
        for k,v in pairs(extra or {}) do spec[k]=v end
        return spec
    end
    local specs={
        number('lives','Witch Lives',1,255,1,4,{1,10},{infinite=true,help='Slide to ∞ for unlimited lives, or type 1–255.'}),
        bool('uncapped','Uncapped teams',false,{help='Teams may have more players than the Required Players per Team.'}),
        bool('single','Play only one round',false),
        bool('extras','Unlock abilities and power-ups',false),
        bool('divinationOrb','Divination Orb',true,{live=true,help='Off: the orb in the HUD never shows how close a wanted prop is.'}),
        number('propIndicator','Prop indicator range (m)',.1,nil,1,20,{5,60},{live=true}),
        bool('propSparks','Sparks toward the wanted prop',false,{live=true}),
        number('propSparksFrom','Sparks toward the wanted prop from (m)',.1,nil,.5,6,{1,20},{live=true}),
        number('targetOffset','Extra cauldrons to win',-10,nil,1,0,{-2,2},{live=true}),
        number('respawn','Witch respawn delay (s)',0,nil,.5,5,{0,60},{live=true}),
        number('totems','Revive totems per dead witch',0,nil,1,1,{0,5},{help='One revival uses all totems for that witch. Living witches revive a random dead teammate.'}),
        bool('filledRevive','Revive at filled cauldrons',false,{help='Stand at a full cauldron to revive a random dead teammate.'}),
        number('revive','Revival time (s)',.01,nil,.5,3,{.5,30},{live=true,help='Two witches revive twice as fast.'}),
        number('potTime','Time added per filled cauldron (s)',0,nil,5,120,{0,600},{live=true,help='The game adds 2 minutes for each filled cauldron.'}),
        bool('scoutPowerup','Power-up at a scouted cauldron',false,{live=true,help='When a witch first finds out which prop a cauldron wants, a witch power-up appears over it.'}),
        {key='order',label='Winner priority',kind='text',initial='wins,time,pots,lives,props,kills',page='none',valid=function(v) return order(v)~=nil end},
        {key='off',label='Criteria left out',kind='text',initial='props,kills',page='none',valid=function(v) return off(v)~=nil end},
    }
    C.rules.declare(PKG,specs)
    local TAB_KEYS={'extras','divinationOrb','propIndicator','propSparks','propSparksFrom','targetOffset','respawn','totems','filledRevive','revive','potTime','scoutPowerup'}
    -- The host's own choices that are no match rules are the game's options themselves, read when
    -- asked (audit 11-20: they were copied into a table at hosting and patched by hand after): Team
    -- Choice the host sets (also from the in-game menu, which edits the next match's options), and
    -- "No timer" this match runs with. Guests get them from the host.
    local pref = R.settings('FillAPotPlus',{})
    local function hostState()
        local gi=C.session().gi
        return {roleChoice=gi.NextMatchOptions.TeamSwitchingOption==1,startReady=gi.UsedMatchOptions.DisableStartMatchTimer==true}
    end
    -- The criteria a match decides by, in their order.
    function S.ranked(rules)
        local skip,rows=off(rules.off or '') or {},{}
        for _,k in ipairs(order(rules.order)) do if not skip[k] then rows[#rows+1]=k end end
        return rows
    end
    -- The host's own choice, kept apart from the match rules: a player who drops may come back.
    function S.rejoin() return pref.rejoin~=false end
    R.options(function(rows,U)
        return {(U.checkbox(rows,{label='Allow rejoining',value=S.rejoin(),
            tooltip='Disconnected players may come back: a player who drops returns to their team with the lives they had. Players who arrive during a match watch until the next one.',
            on_change=function(v) pref.rejoin=v;R.save_settings('FillAPotPlus') end}))}
    end)
    S.criteria,S.CRITERIA = criteria,CRITERIA
    local remoteState
    local custom = '/Game/UserInterface/Play/WB_Custommatch.WB_Custommatch_C:'
    -- The mode's name in sessions is the mod's.
    local label = R.mod_name(R.owner())
    -- Fill a Pot+ is Fill a Pot on a server that is not vanilla (the Vanilla server box off).
    function S.selected(options)
        return R.valid(options.GameMode)~=nil and options.GameMode:GetFName():ToString()=='B_ObjectiveGameMode_C' and not C.mods.vanilla(options)
    end
    -- The rules in force (Core's), with the Custom Match screen's choices this match runs with.
    function S.rules()
        local out={}
        for _,spec in ipairs(specs) do out[spec.key]=C.rules.get(PKG,spec.key) end
        local chosen=S.host() and hostState() or remoteState or {roleChoice=true,startReady=false}
        out.roleChoice,out.startReady=chosen.roleChoice,chosen.startReady
        return out
    end
    -- Guests get the host's choices (the rules reach them through Core).
    function S.publishRules()
        if S.host() then C.net.publish('fap.state',hostState()) end
    end
    C.net.watch('fap.state',function(value) if not S.host() and type(value)=='table' then remoteState=value end end)
    C.rules.on_change(function(pkg,key)
        if pkg==PKG and key=='targetOffset' and S.host() and S.inMatch() then S.target() end
    end)
    local function applyLabel()
        local session = C.session()
        session.gm.DisplayName=FName(label)
        C.replicate(session.gs,'GamemodeDisplayName',FName(label),19)
        session.gi.SessionManager.SessionIsDirty=true
        session.gi.SessionManager:UpdateSessionProperties()
    end
    R.pre(custom..'ForceObjectiveMap',function(w)
        local options=w.NextMatchOptions
        -- The game puts its objective map in: this mode keeps a saved map it plays (one it does not
        -- play is taken back), or its map cycle.
        if not S.selected(options) then return end
        if options.CustomMapSelected and not C.catalog.plays(options) then C.catalog.unpick(options) end
        if options.CustomMapSelected or S.text(options.MapData[S.F.file])=='RandomMapCycle' then return true end
    end)
    -- Hosted with 0 players per team without Uncapped teams: the game's own team check then wants
    -- exactly 0 in each team - no Ready, the match never starts (user 11-20, "You need 0 players per
    -- team"). An empty team is only for Uncapped teams: else 1.
    R.pre('/Game/Blueprints/Core/B_GameInstance.B_GameInstance_C:HostGame',function(gi)
        local options=gi.UsedMatchOptions
        if not S.selected(options) or S.rules().uncapped then return end
        if (math.tointeger(options.RequiredPlayersPerTeam) or 0)<1 then options.RequiredPlayersPerTeam=1 end
    end)
    -- The game takes Required Players per Team from its own slider (hidden in this mode: the mode's
    -- field shows it): in this mode it holds 0 (an empty team, S.required) to 8; elsewhere the game's range.
    local requiredRange
    R.pre(custom..'UpdateWidgetVisibility',function(w)
        local slider=w.Slider_RequiredPlayersPerTeam
        requiredRange=requiredRange or {slider.MinimumValue,slider.MaximumValue}
        if not S.selected(w.NextMatchOptions) then slider.MinimumValue,slider.MaximumValue=requiredRange[1],requiredRange[2];return end
        slider.MinimumValue,slider.MaximumValue=0,8
        -- Native objective visibility also clears the active custom layout.
        for _,control in ipairs(S.values(w.AllControlsShow)) do
            control:SetVisibility(0);control.bIsFocusable=true
        end
        for _,control in ipairs(S.values(w.ObjectiveControlsHide)) do
            control:SetVisibility(1);control.bIsFocusable=false
        end
        w.Slider_MaxPlayers.MaximumValue=16
        return true
    end)
    local views={}
    local function shown(key) return C.rules.shown(PKG,key) end
    local function change(key,value) C.rules.set(PKG,key,value) end
    local function build(parent,scroll)
        local controls,paint=U.rule_rows(parent,PKG,TAB_KEYS)
        local buttons,boxes={},{}
        local function caption(i,k) return 'Winner priority '..i..': '..S.criteria[k] end
        local function used(k) return not off(shown('off'))[k] end
        local function repaint()
            for i,k in ipairs(order(shown('order'))) do buttons[i](caption(i,k));boxes[i](used(k)) end
        end
        for rank,key in ipairs(order(shown('order'))) do
            local line=U.flow(parent)
            local widget,set=U.button(line,{label=caption(rank,key),
                tooltip='Click each criterion from most to least important. Ties use the next criterion; infinite lives are ignored.',on_click=function()
                    local rows=order(shown('order'));local moved=table.remove(rows,rank);rows[#rows+1]=moved
                    change('order',table.concat(rows,','))
                    repaint()
                end})
            U.fill(widget)
            local box,check=U.checkbox(line,{columns=true,label='',tooltip='Decide by this criterion',value=true,on_change=function(v)
                local k=order(shown('order'))[rank]
                local rows={}
                for name in pairs(off(shown('off'))) do if name~=k then rows[#rows+1]=name end end
                if not v then rows[#rows+1]=k end
                -- (at least one criterion decides)
                if #rows<6 then change('off',table.concat(rows,',')) end
                repaint()
            end})
            buttons[rank],boxes[rank]=set,check
            controls[#controls+1]=widget;controls[#controls+1]=box
        end
        repaint()
        U.navigate(controls,scroll)
        return function()
            paint()
            repaint()
        end
    end
    U.rules_tab('match_rules',build)
    S.onMatchHost.on('round_start',function(gs)
        local mm=S.manager()
        local manager=mm:GetAddress()
        if not S.match or S.match.manager~=manager or mm.CurrentRound<=1 then
            S.match={manager=manager,rounds={}}
        end
        S.publishRules();applyLabel()
    end)
    -- The game's "No timer for starting match" does nothing in Fill a Pot; in Fill a Pot+ it
    -- removes the team countdown: the match starts when everyone is ready. It is read from the
    -- options this match runs with, so a change in Next Match Settings applies to the next match.
    S.onMatchHost.session(function(session)
        if R.valid(session.gs) then S.publishRules();applyLabel() end
    end)
    C.on_session(function(session) if session.is_creative then S.match=nil end end)
    R.on('world_end',function()
        remoteState=nil
        -- The Custom Match screen is cached across worlds; keep the rows it still shows.
        for id,view in pairs(views) do if not R.valid(view.box) then views[id]=nil end end
    end)
    function S.endMatch() S.match=nil;S.publishRules() end
    -- The Plus rows show when the options the screen edits are Plus.
    -- Off a vanilla server the screen is Fill a Pot's with Fill a Pot+'s own: its Witch lives where the
    -- game's stands, and a second column at the right of the game's rows below it (Team Choice,
    -- Uncapped teams, Play only one round). In any other mode the game's rows are as the game has them.
    -- The game's Required Players per Team and Team Choice: this mode shows their options itself.
    for _,control in ipairs({'Slider_RequiredPlayersPerTeam','ComboBox_TeamChoice'}) do
        C.memory.shown_by(control,function(w) return S.selected(w.NextMatchOptions) end)
    end
    local function customRules(w)
        local id=w:GetAddress()
        local view=views[id]
        local selected=S.selected(w.NextMatchOptions)
        local list=w.ComboBox_GameMode
        -- (made only once the mode is chosen on this screen: another mode's screen stays as the game made it)
        if not view and not selected then list.SelectedOptionLabel:SetText(list.SelectedOption);return end
        if not view then
            local parent=w.Slider_WitchLives:GetParent()
            -- The second column (UIKit's, made first: the rows placed after Witch Lives stand above it).
            local own=U.parts.native(U.match_column(w),'VerticalBox')
            -- (where the game's own Witch Lives stands, as on Fill a Pot)
            local box=U.section(parent,{})
            U.place_after(box,w.Slider_WitchLives)
            -- Required Players per Team, where the game's own stands: its usual 1 to 3 on the slider,
            -- any of 0 (an empty team: S.required) to 8 typed (16 players at most).
            local required=U.section(w.Slider_RequiredPlayersPerTeam:GetParent(),{})
            U.place_after(required,w.Slider_RequiredPlayersPerTeam)
            local requiredRow,setRequired=U.slider(required,{label='Required Players per Team',kind='int',min=1,max=3,input_min=0,input_max=8,
                value=math.tointeger(w.NextMatchOptions.RequiredPlayersPerTeam) or 1,
                tooltip='Slide from 1 to 3, or type any number from 0 to 8.',
                on_commit=function(v) w.NextMatchOptions.RequiredPlayersPerTeam=v;w:LoadCustomMatchOptions() end})
            local lives,paintLives=U.rule_rows(box,PKG,{'lives'})
            -- (their fields as wide as a number needs: the cell less a margin at the right)
            for _,row in ipairs({requiredRow,lives[1]}) do
                local slot=row.InputField.Slot;local p=slot.Padding
                slot:SetHorizontalAlignment(0);slot:SetPadding({Left=p.Left,Top=p.Top,Right=120,Bottom=p.Bottom})
            end
            local column=own
            -- The game's Team Choice, which in this mode is the side the first team takes in the first
            -- round: the game's option (0 Random, 1 Free: the players choose; as measured live, the
            -- game's list shows them in another order), the game's own control following it.
            local sides={{value=0,label='Random'},{value=1,label='Choice'}}
            local _,setSide=U.combo(column,{label='First Round Side',options=sides,value=w.NextMatchOptions.TeamSwitchingOption,
                on_change=function(v) w.NextMatchOptions.TeamSwitchingOption=v;w:LoadCustomMatchOptions();S.sideChanged() end})
            local choices,paintChoices=U.rule_rows(column,PKG,{'uncapped','single'})
            view={box=box,required=required,setRequired=setRequired,setSide=setSide,right=own,
                paint=function() paintLives();paintChoices() end};views[id]=view
            for _,c in ipairs(choices) do lives[#lives+1]=c end
            U.navigate(lives)
        end
        view.paint()
        view.box:SetVisibility(selected and 0 or 1)
        view.required:SetVisibility(selected and 0 or 1)
        view.setRequired(math.tointeger(w.NextMatchOptions.RequiredPlayersPerTeam) or 1)
        view.setSide(w.NextMatchOptions.TeamSwitchingOption)
        view.right:SetVisibility(selected and 0 or 1)
        if selected then
            for _,control in ipairs({w.Slider_WitchLives,w.Slider_RequiredPlayersPerTeam}) do control:SetVisibility(1) end
        end
        -- The list shows the mode's name: Fill a Pot+ off a vanilla server. Only the caption: the
        -- game knows its modes by the chosen option's text, which stays its own.
        list.SelectedOptionLabel:SetText(selected and FText(label) or list.SelectedOption)
    end
    for _,method in ipairs({'Construct','LoadCustomMatchOptions','UpdateWidgetVisibility','UpdateLayoutComboBox'}) do
        R.post(custom..method,customRules)
    end
    -- A choice of mode: leaving Fill a Pot+ for another (maps.lua: its maps are not other modes'), and the screen's rows.
    R.post(custom..'BndEvt__ComboBox_GameMode_K2Node_ComponentBoundEvent_0_OnSelectionChanged__DelegateSignature',function(w)
        if not w.InGame then S.modeChanged(S.selected(w.NextMatchOptions),w.NextMatchOptions) end
        customRules(w)
    end)
    R.post('/Script/UMG.UserWidget:Destruct',function(w) views[w:GetAddress()]=nil end)
    for _,method in ipairs({'Initialize','HandleEndMatchOverride'}) do
        S.onMatchHost.post(S.path(S.O,'B_ObjectiveGameMode',method),applyLabel)
    end
    -- (the server list's mode name is Core's: it advertises the chosen mode module's name, audit 11-20)
    -- In Fill a Pot the game always lets players pick a team. Team Choice (First Round Side), also
    -- from the in-game menu, decides whether the first team starts as witches and the logos say so.
    function S.sideChanged()
        if not (S.inMatch() and S.host()) then return end
        local mm=S.manager()
        if mm.CurrentRound==0 then mm:RandomizeTeamAStartsAsWitch() end
        S.publishRules();S.refreshHUD()
    end
end
