-- The native Game Rules pages: reading the rules in force, staging a document for the
-- next match, Creative playtests, painting the pages and recording edits made on them.
return function(M)
    local R,C,U,D=M.R,M.C,M.U,M.doc
    local hooks,settings,schema=M.hooks,M.settings,M.schema
    local RULEUI,CREATIVE=M.RULEUI,M.CREATIVE
    local editorRules,activeCreative=nil,false

    -- A document of the rules in force: the running match's, or the next match's.
    -- Guests read the host's published rules. `effective` holds every value the
    -- native subsystems use, for painting pages that show defaults too.
    -- (mode: the game mode the rules are of, when the options already show another - Core's memory)
    function M.capture(fromNext,source,options,forMode)
        local s=C.session()
        if C.guest(s) and M.hostView then return D.clone(M.hostView.document) end
        local mode
        if source then mode=M.pathOf(source.GameModeClass)
        elseif (s.role=='host' or C.guest(s)) and R.valid(s.gs) and (not s.is_creative or M.playing()) and not fromNext then
            source,mode=s.gs,M.pathOf(s.gs.GameModeClass)
        else
            options=options or M.nextOptions()
            source,mode=options:GetGameRules(),forMode or M.pathOf(options.GameMode)
        end
        -- (every mod's rules: Core's rules sections)
        local doc={format='MatchRulesPlusPlus',version=2,mode=mode,native={},extras=C.saved_rules.collect(),effective={}}
        for category in pairs(schema.collections) do doc.native[category]=D.read(source,category) end
        for _,group in ipairs(schema.groups) do
            local effective={}
            local parameters=M.params(group)
            if parameters then doc.effective[group.category..':'..group.id]=effective end
            for _,row in ipairs(parameters and group.rows or {}) do
                local value=parameters[row.name]
                -- Modifiers other than Move or Damage are off in Fill a Pot, all are off in Impostor.
                if group.category=='mods' and row.name=='IsEnabled' and
                    (mode:find('B_ImpostorGameMode_C',1,true) or mode:find('B_ObjectiveGameMode_C',1,true) and group.id~=1) then value=false end
                effective[row.name]=value
            end
        end
        return doc
    end
    -- The rules of the game live in the options a match is hosted with (options.GameRules, as the
    -- game keeps them): rules of their own when they differ from the game's reset rules.
    local function native(rules)
        local out={}
        for category in pairs(schema.collections) do out[category]=D.read(rules,category) end
        return R.json.encode(out)
    end
    function M.custom(options) return native(options:GetGameRules())~=native(D.nativeRules(options)) end
    -- The one writer of a match options' rules (audit C10): the rules, no file to load, and whether
    -- they are custom - written together, always.
    local function setRules(options,rules,custom)
        options.GameRules,options.GameRulesToLoad,options.IsUsingCustomRules=rules,'',custom
    end
    -- Put a document's rules in the next match's options.
    function M.stage(doc,options)
        if not M.editable() then R.log(M.PKG,'Rules not staged: only the host can select rules');U.message('Rules','Only the host can select rules in this session.');return end
        options=options or M.nextOptions()
        if doc.mode~=M.pathOf(options.GameMode) then R.log(M.PKG,'Rules not staged: they are for %s, the options are for %s',tostring(doc.mode),tostring(M.pathOf(options.GameMode)));U.message('Rules','Select the preset’s game mode first.');return end
        R.log(M.PKG,'Rules staged for the next match (mode %s)',tostring(doc.mode))
        setRules(options,D.materialize(doc,options),true)
        return true
    end
    -- Hosting from the main menu recomputes IsUsingCustomRules from the menu world's rule
    -- subsystems (B_WitchHuntFunctionLibrary.AreAnyRulesCurrentlyEnabled), which rules put in the
    -- options never touch: the options hosted say what their rules are, and the next match's
    -- (copied into every later match) take them.
    hooks.pre('/Game/Blueprints/Core/B_GameInstance.B_GameInstance_C:HostGame',function(gi)
        local used,upcoming=gi.UsedMatchOptions,gi.NextMatchOptions
        if not M.custom(used) then return end
        for _,options in ipairs({used,upcoming}) do
            setRules(options,used.GameRules,true)
        end
    end)

    -- Creative playtests apply the next match's rules live and restore the editor's rules after.
    local function publishCollections(gs,rules)
        gs:FlushNetDormancy()
        for _,def in pairs(schema.collections) do
            gs[def.field]=rules[def.field]
            M.library('NetPushModelHelpers'):MarkPropertyDirtyFromRepIndex(gs,def.rep,FName(def.field))
            gs['OnRep_'..def.field](gs)
        end
        gs:ForceNetUpdate()
    end
    -- Only scalar rule values survive Play Test's native collection lifetime.
    local function saveEditor() editorRules=M.capture(false,C.session().gs) end
    function M.creativeApply(doc)
        local s=C.session()
        if not s.is_creative or s.role~='host' then return end
        if not editorRules then saveEditor() end
        R.log(M.PKG,'Playtest: the next match\'s rules apply live')
        activeCreative=true
        publishCollections(s.gs,D.materialize(doc,s.gi))
        M.refreshEffects()
    end
    function M.stopCreative()
        if not activeCreative then return end
        R.log(M.PKG,'Playtest over: the editor\'s rules are back')
        activeCreative=false
        M.cleanupAbandoned()
        if editorRules then
            publishCollections(C.session().gs,D.materialize(editorRules,C.session().gi))
            editorRules=nil
        end
        M.refreshEffects()
        M.publishView()
    end
    function M.useNativeRules(options)
        options=options or M.nextOptions()
        setRules(options,D.nativeRules(options),false)
        if activeCreative then M.stopCreative() else M.refreshEffects() end
        M.publishView()
    end
    hooks.pre(CREATIVE..'B_CreativeGameMode.B_CreativeGameMode_C:BeginPlayTest',function()
        if M.editable() and M.custom(M.nextOptions()) then saveEditor() end
    end)
    hooks.playtest(function(s)
        if s.role~='host' then return end
        if not s.is_playtest then M.stopCreative();return end
        if M.custom(M.nextOptions()) then M.creativeApply(D.clean(M.capture(true)));M.publishView() end
    end)
    R.on('world_end',function() editorRules,activeCreative=nil,false end)

    -- The four native pages. Painting never captures or applies rules.
    local pages={
        {asset='WB_MatchRules.WB_MatchRules_C',refresh='RefreshMatchRules',category='match',
            slider='OnParamSliderRealValueChanged',apply='ApplyChanges'},
        {asset='SkillRules/WB_SkillRules.WB_SkillRules_C',refresh='RefreshSkillRuleUI',category='skills',
            typeField='CurrentSkillType',slider='OnParamSliderRealValueChanged',apply='ApplyRules'},
        {asset='Mods/WB_ModConfigure.WB_ModConfigure_C',refresh='RefreshModifierUI',category='mods',
            typeField='CurrentModType',slider='OnFloatParamSliderRealValueChanged',apply='ApplyRules'},
        {asset='PowerupRules/WB_PowerupConfigure.WB_PowerupConfigure_C',refresh='RefreshPowerupUI',category='powerups',
            typeField='CurrentPowerupType',slider='OnFloatParamSliderRealValueChanged',apply='ApplyRules'},
    }
    -- The schema group a page control belongs to; match rules number their controls.
    local function groupOf(page,widget,control)
        local id=page.typeField and widget[page.typeField] or control.Index
        return D.index[page.category][id],id
    end
    -- A guest's edits on these pages: their own rules, for a code. They never reach the match.
    local function guestEntry(doc,category,id)
        for _,entry in ipairs(doc.native[category]) do
            if entry.id==id then return entry end
        end
    end
    local function guestValue(category,id,name)
        local mine=M.view=='mine' and settings.guestRules
        local entry=mine and guestEntry(mine,category,id)
        return entry and entry.values[name]
    end
    local function setGuestValue(category,id,name,value)
        local doc=M.guestEdited()
        local entry=guestEntry(doc,category,id)
        if not entry then
            entry={id=id,values={}}
            doc.native[category][#doc.native[category]+1]=entry
        end
        entry.values[name]=value
        M.persist()
    end
    for _,page in ipairs(pages) do
        local path=RULEUI..page.asset..':'..page.refresh
        hooks.pre(path,function() M.filling=true end)
        -- (painting ends with the refresh, also when it fails: audit 11-20, an error left it on and every
        -- rule edit was ignored)
        hooks.post(path,function(widget) R.finally(function()
                local s=C.session()
                if s.role=='offline' then return end
                -- Creative authoring paints the detached next-match rules, not the running world.
                local draftValues
                if s.role=='host' and s.is_creative and not M.playing() then
                    draftValues={}
                    for _,entry in ipairs(D.read(M.nextOptions():GetGameRules(),page.category)) do draftValues[entry.id]=entry.values end
                end
                local paint={}
                for _,control in ipairs(R.values(widget.UIElements)) do
                    if R.valid(control) then
                        local kind=control:GetClass():GetFName():ToString()
                        local isBool=kind=='WB_CheckBoxWithEditableLabel_C'
                        if isBool or kind=='WB_SliderWithEditableLabel_C' then
                            local group,id=groupOf(page,widget,control)
                            local metadata=isBool and control.BoolParameter or control.FloatParameter
                            -- (a control the schema does not know: the game paints it)
                            local row=group and group.byNativeName[R.text(metadata.Name):lower()]
                            local value
                            if not row then
                            elseif draftValues then
                                value=draftValues[id] and draftValues[id][row.name]
                                if value==nil then
                                    if isBool then value=control.DefaultBoolValue else value=control.DefaultFloatValue end
                                end
                            elseif C.guest(s) then
                                local effective=M.hostView and M.hostView.document.effective
                                value=guestValue(page.category,id,row.name)
                                local hostRow=effective and effective[page.category..':'..id]
                                if value==nil and hostRow then value=hostRow[row.name] end
                                if value==nil then value=M.params(group)[row.name] end
                            else value=M.params(group)[row.name] end
                            if value~=nil then paint[#paint+1]={control=control,value=value,bool=isBool} end
                        end
                    end
                end
                for _,item in ipairs(paint) do
                    if not item.bool then
                        item.control:SetRealValue(item.value)
                        widget[page.slider](widget,item.control,item.control.RealValue)
                    end
                end
                for _,item in ipairs(paint) do
                    if item.bool then
                        item.control:SetIsCheckedWithoutEvent(item.value)
                        item.control:CheckDefaultToUpdateUI()
                        widget:OnCheckBoxValueChanged(item.control,item.value)
                    end
                    if s.role=='host' and M.playing() and not s.gm.IsLiveRuleEditingAllowed then item.control:SetIsEnabled(false) end
                    -- A guest edits their own rules only: the match's are shown as they are.
                    if C.guest(s) then item.control:SetIsEnabled(M.view=='mine') end
                end
        end,function() M.filling=false end) end)
    end
    -- Guests of a modded host never change rules locally; the host's rules arrive by replication.
    local function guest() return C.guest() or nil end
    hooks.pre(RULEUI..'WB_MatchRules.WB_MatchRules_C:ApplyChanges',guest)
    for _,name in ipairs({'UpdateMatchRules','UpdateSkillRules','UpdateModRules','UpdatePowerupRules','ResetAllRules'}) do
        hooks.pre(M.CORE..'B_GameState.B_GameState_C:'..name,guest)
    end
    for _,path in ipairs({
        RULEUI..'WB_MatchRules.WB_MatchRules_C:Apply Rules',
        RULEUI..'SkillRules/WB_SkillRules.WB_SkillRules_C:ApplyRules',
        RULEUI..'Mods/WB_ModConfigure.WB_ModConfigure_C:ApplyRules',
        RULEUI..'PowerupRules/WB_PowerupConfigure.WB_PowerupConfigure_C:ApplyRules',
        M.TABS..':ResetAllToDefault',
        RULEUI..'WB_SaveLoadGameRules.WB_SaveLoadGameRules_C:ResetRules'
    }) do
        hooks.pre(path,guest)
        hooks.post(path,function()
            local s=C.session()
            if M.filling or not M.editable() then return end
            if s.is_creative and M.playing() and not s.gm.IsLiveRuleEditingAllowed then C.state(M.PKG,'Rules apply','not applied live - live rule editing is off in the playtest');return end
            if s.is_creative and M.playing() then M.creativeApply(D.clean(M.capture(true))) end
            M.publishView()
        end)
    end
    -- A guest's reset in "My rules" takes their own rules back to the match's: a page's reset that
    -- page's group, Reset all every group (the game's pages then paint the host's rules again). In
    -- the match's view a reset changes nothing (the game's own is held back above).
    local function mineView() return C.guest() and M.view=='mine' end
    local function dropGuest(category,id)
        local doc=settings.guestRules
        if not (mineView() and doc) then return end
        for i,entry in ipairs(doc.native[category]) do if entry.id==id then table.remove(doc.native[category],i);break end end
        M.persist()
    end
    for _,page in ipairs(pages) do
        if page.typeField then
            local event=page.category=='skills' and 'BndEvt__WB_SkillRules_Button_Reset_K2Node_ComponentBoundEvent_1_Clicked__DelegateSignature'
                or 'BndEvt__WB_ModConfigure_Button_Reset_K2Node_ComponentBoundEvent_1_Clicked__DelegateSignature'
            hooks.pre(RULEUI..page.asset..':'..event,function(widget) dropGuest(page.category,widget[page.typeField]) end)
        end
    end
    hooks.pre(M.TABS..':ResetAllToDefault',function(screen)
        if not mineView() then return end
        settings.guestRules=nil;M.persist()
        local shown=screen.RulesSwitcher:GetActiveWidget()
        R.next_frame(function() if R.valid(shown) then shown:Init() end end)
    end)
    -- Live editing during a Creative playtest applies each changed value immediately.
    for _,page in ipairs(pages) do
        for _,event in ipairs({page.slider,'OnCheckBoxValueChanged'}) do
            hooks.post(RULEUI..page.asset..':'..event,function(widget,sender,value)
                local s=C.session()
                local guest=C.guest(s)
                if M.filling or not guest and (not M.editable() or not s.is_creative or not M.playing() or not s.gm.IsLiveRuleEditingAllowed) then
                    if not M.filling then C.state(M.PKG,'Live rule edit','not applied - '..(not M.editable() and 'not the host' or not s.is_creative and 'applies from the next match' or not M.playing() and 'the editor is not in a playtest' or 'live rule editing is off')) end
                    return
                end
                if not R.valid(sender) then return end
                local group,id=groupOf(page,widget,sender)
                local metadata=event=='OnCheckBoxValueChanged' and sender.BoolParameter or sender.FloatParameter
                local row=group and group.byNativeName[R.text(metadata.Name):lower()]
                if not row then return end
                if guest then if M.view=='mine' then setGuestValue(page.category,id,row.name,value) end;return end
                if M.params(group)[row.name]==value then return end
                M.filling=true
                R.finally(function() widget[page.apply](widget) end,function() M.filling=false end)
                M.creativeApply(D.clean(M.capture(true)))
                M.publishView()
            end)
        end
    end
    -- Each game mode's own rules of the game (Core's memory, rules per mode): the next match's
    -- rules of that mode, or the game's own. (The mods' own rules are kept per mode by Core's rules.)
    C.memory.register(M.PKG..'.native',{
        save=function(options,mode) return M.custom(options) and D.clean(M.capture(true,nil,options,mode)) or false end,
        -- (Core keeps the records by mode: the record handed is this mode's - the mode is Core's word, not
        -- checked again here; a record kept before 11-20 could carry another mode's name)
        load=function(doc,options)
            R.log('Match Rules ++','Rules of the game mode: %s',doc and 'its own' or 'the game\'s')
            if doc then doc.mode=M.pathOf(options.GameMode);M.stage(doc,options) else M.useNativeRules(options) end
        end})
    local saveScreen=RULEUI..'WB_SaveLoadGameRules.WB_SaveLoadGameRules_C:Construct'
    hooks.post(saveScreen,function(page)
        if not M.editable() then return end
        local child=page.WB_SaveLoadScreen
        if child.FileEditingAllowed then return end
        local options=M.nextOptions()
        setRules(options,D.materialize(M.capture(true),options),options.IsUsingCustomRules)
        child.FileToSave=options.GameRules
        child.FileEditingAllowed=true;page.FileEditingAllowed=true;child:SetUITexts()
        local name=R.text(child.InitialEntryName)
        local present=false
        child.SaveEntries:ForEach(function(key) if R.text(key:get())==name then present=true end end)
        if not present then child:CreateNewSaveEntry(name,{});child:CheckForTooManySavegames() end
    end)
end
