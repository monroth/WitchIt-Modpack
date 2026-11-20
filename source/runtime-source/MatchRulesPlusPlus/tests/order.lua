removed={}
-- Run from the worktree root. Small call-order model, not live engine acceptance.
local base='candidate/runtime-source/'
local json=dofile(base .. 'WitchItRuntime/Scripts/json.lua')
-- The previous runtime's parser is used only as a JSON library here. The fixed R API
-- takes ordinary Lua arrays; adapt its old encoder marker in this test environment.
local oldEncode=json.encode
local function markArrays(value)
    if type(value)~='table' then return end
    if #value>0 then json.array(value) end
    for _,child in pairs(value) do markArrays(child) end
end
json.encode=function(value) markArrays(value); return oldEncode(value) end
local hooks, before, events, watches, requests, keys, timers={}, {}, {}, {}, {}, {}, {}
local saved, files, published, buttons, inputs, checks={}, {}, {}, {}, {}, {}
local builds, scans, opens={}, 0, 0
local startup, listings, failWrite=true, 0, false
local prepared, combos={}, {}
local serial=0
local function instance(fields)
    serial=serial+1
    fields=fields or {}
    local id=serial
    fields.GetAddress=function() return id end
    fields.HasAuthority=function() return true end
    return fields
end
local function array(make)
    local data={}
    local methods={ForEach=function(_,fn)
        for i,v in ipairs(data) do fn(i,{get=function() return v end}) end
    end}
    return setmetatable({}, {__index=function(_,k) return type(k)=='number' and data[k] or methods[k] end,
        __newindex=function(_,k,v) data[k]=v==nil and make() or v end})
end
local defs={
    MatchRules={'MatchRuleType_2_7A33ED664F8C0FBEE1C782B8057AEA07','UIParameters_6_D7D219FA47CFCDF8FCA3DB9DBCF39E11'},
    SkillRules={'SkillType_2_5808B66B468AC4EC8E4F7096273ED505','SkillParameters_6_41DDEB6C424E37EF4C61239795AF12B0'},
    GameModifiers={'ModifierType_2_FEC4E34148D09164EA058CBDDCBE4C7F','UIParameters_6_270A78AB4625673AD2C87194A200889D'},
    PowerupRules={'PowerupType_5_07F0F6FF44288141C9331F8C816DF5AF','PowerupParameters_6_855163784BFC03D7EC9FB8B8D2C10128'}
}
local function rules()
    local r={}
    function r:ResetAll()
        for field, def in pairs(defs) do self[field]=array(function() return {[def[2]]=array(function() return {} end)} end) end
    end
    r:ResetAll()
    for method,field in pairs({AddSkillRule='SkillRules',AddGameModifier='GameModifiers',AddPowerupRule='PowerupRules'}) do
        r[method]=function(self,record)
            local n=0; self[field]:ForEach(function() n=n+1 end); self[field][n+1]=record
        end
    end
    return r
end
local gameModePath='/Game/Blueprints/Gamemodes/HideAndSeek/B_HideAndSeekGameMode.B_HideAndSeekGameMode_C'
local modeClass={GetFullName=function() return 'BlueprintGeneratedClass ' .. gameModePath end}
local options={GameMode=modeClass, GameRules=rules(), SeekTime=240, CustomMapSelected=false,
    MapData={NeedsExtraTime_43_B354AF0A49DCBA90CE3CC7A6C2FEF251=true}}
function options:GetGameRules() return self.GameRules end
local gs=rules()
gs.SeekTime=240; gs.GameModeClass=modeClass
function gs:FlushNetDormancy() end
function gs:ForceNetUpdate() end
function gs:IsA() return true end
for field in pairs(defs) do gs['OnRep_' .. field]=function() end end
local gm=instance({MapVoteTimeNeeded=true, IsLiveRuleEditingAllowed=true})
local state={role='host', world={}, gs=gs, gm=gm, gi={IsCurrentlyInMatch=true,NextMatchOptions=options,UsedMatchOptions=options}, is_vanilla_session=false}
local subs={}
local timerState={elapsed=0,paused=false,active=true}
local spawnedRules={}
local libs={GameplayStatics={SpawnObject=function() local r=rules();spawnedRules[#spawnedRules+1]=r;return r end, GetTimeSeconds=function() return timerState.now or 0 end, GetGameInstance=function() return state.gi end, GetGameState=function() return gs end},
    SubsystemBlueprintLibrary={GetWorldSubsystem=function(_,_,cls) return subs[cls] end},
    NetPushModelHelpers={MarkPropertyDirtyFromRepIndex=function(_,_,rep) assert(rep==44 or rep==46 or rep>=32 and rep<=37) end},
    KismetSystemLibrary={
        K2_GetTimerElapsedTime=function() return timerState.elapsed end,
        K2_IsTimerPaused=function() return timerState.paused end,
        K2_IsTimerActive=function() return timerState.active end,
        K2_ClearTimer=function() timerState.active=false end,
        K2_SetTimer=function(_,_,_,remaining,a,b,c,d)
            assert(a==false and b==false and c==0 and d==0); timerState.remaining=remaining; timerState.active=true
        end,
        K2_PauseTimer=function() timerState.paused=true end
    }}
function StaticFindObject(path) return libs[path:match('Default__(.+)')] or path end
function FName(name) return {ToString=function() return name end} end
local function register(table_,name,fn) table_[name]=table_[name] or {}; table.insert(table_[name],fn) end
local R={finally=function(fn,after,...) local r=table.pack(pcall(fn,...));after();if not r[1] then error(r[2],0) end;return table.unpack(r,2,r.n) end,next_frame=function(fn) fn() end,json=json, base64=dofile(base .. 'WitchItRuntime/Scripts/base64.lua'), native={}, valid=function(o) return type(o)=='table' and not o.dead end,
    post=function(path,fn) register(hooks,path,fn) end, pre=function(path,fn) register(before,path,fn) end,
    on=function(event,fn) register(events,event,fn) end, key=function(id,_,fn) keys[id]=fn end,
    after=function(ms,fn) local row={ms=ms,fn=fn}; timers[#timers+1]=row; return function() row.cancelled=true end end,
    settings=function(_,defaults) for k,v in pairs(defaults) do if saved[k]==nil then saved[k]=v end end;return saved end,
    save_settings=function() end,
    prepare_directory=function(path) assert(startup,'Directory preparation during a button click');prepared[path]=true end,
    find_all=function() scans=scans+1; return {} end, log=function() end}
local V=dofile('candidate/runtime-source/WitchItRuntime/Scripts/values.lua');R.values,R.text=V.values,V.text
-- Mode as Core decides it from the session fields this test changes.
local function session()
    state.mode=state.is_vanilla_session and state.role~='offline' and 'vanilla' or state.is_creative and 'creative' or 'B_HideAndSeekGameMode_C'
    return state
end
local playtestFns={}
local C={report=dofile('candidate/runtime-source/Core/report.lua')({native={}}),memory={on=function() return true end,register=function() end},session=session, on_playtest=function(fn) playtestFns[#playtestFns+1]=fn end,on_session=function(fn) events.session={fn} end,
    files={read_json=function(p) return files[p] end,
        write_json=function(p,v) if failWrite then return nil,'disk full' end;files[p]=v;return true end,
        remove=function(p) files[p]=nil;removed[p]=true;return true end,
        list=function(p)
            assert(startup,'Directory listing during a button click');listings=listings+1
            local rows={}
            for path in pairs(files) do
                if path:sub(1,#p)==p and not path:sub(#p+1):find('/') then rows[#rows+1]=path:sub(#p+1) end
            end
            return rows
        end},
    net={publish=function(topic,v) published[topic]=v end, watch=function(topic,fn) watches[topic]=fn end,
        request=function(topic,v) requests.sent={topic,v} end, on_request=function(topic,fn) requests[topic]=fn end}}
dofile(base..'Core/tests/lib/scoped.lua')(R,C)
-- Core's rules (the mods' rules) and its registry of rules sections, as Core has them.
local ruleOwners={}
C.saved_rules={register=function(id,o) ruleOwners[id]=o end,
    collect=function() local v={};for id,o in pairs(ruleOwners) do v[id]=o.save() end;return v end,
    load=function(v,except) for id,o in pairs(ruleOwners) do if id~=except then o.load(v[id]) end end end}
C.mods=C.mods or {};C.mods.config=C.mods.config or {}
C.state=C.state or function() end
C.rules=dofile(base..'Core/rulebook.lua')(R,C)
dofile(base..'Core/game.lua')(R,C)
local MRPP='MatchRulesPlusPlus'
local guestRow
local U={rules_view=function() end,rules_tab=function(_,fn) builds.rules=fn;return {} end, menu_entry=function(_,_,label,_,_,visible) if label=='Match Rules +' then guestRow=visible end end, mod_options=function() end,
    open_rules=function() opens=opens+1 end, message=function(_,text) U_lastMessage=text end,
    question=function(_,text,answer) U_lastQuestion=text;answer(true) end,
    row=function(_,widths) local cells={};for i in ipairs(widths) do cells[i]={} end;return cells end}
local presetNameField
for _, kind in ipairs({'text','scroll','button','checkbox','slider','combo','input','section','flow'}) do
    U[kind]=function(_,opts)
        opts=opts or {}
        local value=opts.value
        local w={GetParent=function() return _ end,RemoveFromParent=function() end,SetUserFocus=function()end,SetKeyboardFocus=function()end,SetVisibility=function() end,SetActiveState=function() end,SetIsEnabled=function() end,ClearChildren=function() end,GetText=function()return value end,SetText=function(_,v)value=v end}
        if kind=='input' then presetNameField=w end
        if kind=='button' then buttons[opts.label]=opts.on_click end
        if kind=='slider' then inputs[opts.label]=opts end
        if kind=='checkbox' then checks[opts.label]=opts end
        if kind=='combo' then combos[opts.label]=opts end
        return w, function() end
    end
end
U.remove=function()end
U.error_line=function()end
U.on_close=function()end
U.navigate=function()end
function FText(value)return value end
saved.name='Test-rules'
files['MatchRulesPlusPlus/presets/Old.json']={kept='old'}
-- An ability a mod registered (skill type 200, starting from the Hook's rules).
local nitroParams={}
C.abilities={on_register=function(fn) fn({class='/Game/Example/B_Nitro.B_Nitro_C',name='Nitro Hook',base=2},200) end,
    params=function(kind) assert(kind==200);return nitroParams end}
dofile('candidate/runtime-source/Core/tests/lib/effects.lua')(R,C)
local api=dofile(base .. 'MatchRulesPlusPlus/package.lua')(R,C,U)
startup=false
local count=0
for _, group in ipairs(api.schema) do
    local path=group.category=='match' and '/Game/Blueprints/Match/GameRules/MatchRules/B_MatchParametersSubsystem.B_MatchParametersSubsystem_C'
        or group.category=='skills' and '/Game/Blueprints/Skills/B_SkillParametersSubsystem.B_SkillParametersSubsystem_C'
        or group.category=='mods' and '/Game/Blueprints/Match/GameRules/GameModifiers/B_ModParametersSubsystem.B_ModParametersSubsystem_C'
        or '/Game/Blueprints/Match/GameRules/PowerupRules/B_PowerupParametersSubsystem.B_PowerupParametersSubsystem_C'
    subs[path]=subs[path] or {}
    local params=group.property and {} or nitroParams
    if group.property then subs[path][group.property]=params end
    for _,row in ipairs(group.rows) do
        count=count+1
        if row.kind=='bool' then params[row.name]=false else params[row.name]=0 end
    end
end
assert(#api.schema==30 and count==188,'The game\'s 29 groups and the registered ability\'s own, with the Hook\'s rows')
local nitro=api.schema[30]
assert(nitro.id==200 and nitro.label=='Nitro Hook' and nitro.byName.PullStrength,'A registered ability\'s rules are a group of its skill type')
local CORE='/Game/Blueprints/Core/'
local PROP='/Game/Blueprints/Props/Bases/B_StaticMeshProp.B_StaticMeshProp_C'
local PAWN='/Game/Blueprints/Player/Pawns/B_Hunter.B_Hunter_C'
local function call(path,self,native,...)
    -- (as the runtime: every PRE runs; one that stops the call stops it)
    local stopped=false
    for _,fn in ipairs(before[path] or {}) do if fn(self,...) then stopped=true end end
    if stopped then return 'consumed' end
    local was=state and state.is_playtest
    if native then native() end
    for _,fn in ipairs(hooks[path] or {}) do fn(self,...) end
    -- (Core tells Playtest's changes after the game's own calls)
    if state and state.is_playtest~=was then for _,fn in ipairs(playtestFns) do fn(state) end end
end
local function out(value) return {get=function() return value end, set=function(_,v) value=v end} end
local nativeMenu={AdvancedOptions={SetVisibility=function(self,v) self.visibility=v end,RemoveFromParent=function() error('Native rule editor removed') end},
    NextMatchSettings={RemoveFromParent=function() error('Native next-match settings removed') end}}
call('/Game/UserInterface/WB_IngameMenu.WB_IngameMenu_C:Construct',nativeMenu,function() end)
local pawn=instance({CharacterMovement=instance({GravityScale=6,AirControl=.2}),IsLocallyControlled=function() return true end})
call(PAWN .. ':InitializeRules',pawn)
assert(pawn.CharacterMovement.GravityScale==6 and scans==0)
keys['mrpp.rules'](); assert(opens==1 and scans==0)
local doc={format='MatchRulesPlusPlus',version=2,mode=gameModePath,native={match={{id=1,values={GlobalGravity=400,EnableWardrobe=true}}},skills={{id=13,values={Cooldown=1}}},mods={},powerups={}},
    extras={MatchRulesPlusPlus={mapSizeTimeFactor=30,hunterGravity=2,hunterAirControl=.4,staminaRecharge=10,pickupMin=7,pickupJitter=0,roundDelay=3,cooldownMin=.4,keepAbandoned=true},
        OtherMod={speed=2,label='x',enabled=true}}}
local copy=api.decode(api.encode(doc)); assert(copy.extras.MatchRulesPlusPlus.roundDelay==3,'A code keeps every mod\'s rules section')
assert(copy.extras.OtherMod.speed==2 and copy.extras.OtherMod.enabled,'Other mods keep their own extra rules section')
assert(not pcall(api.decode,api.encode(doc):sub(1,-2)..'x'))
local old=api.clean({format='MatchRulesPlusPlus',version=1,mode=gameModePath,collections=doc.native,extras={roundDelay=3}})
assert(old.version==2 and old.native.match[1].id==1 and old.extras.MatchRulesPlusPlus.roundDelay==3,'Version 1 documents are upgraded at the input boundary')
assert(api.stage(doc)); assert(options.IsUsingCustomRules and gs.SeekTime==240)
local stagedRules=options.GameRules
local liveBefore=gm.IsLiveRuleEditingAllowed;gm.IsLiveRuleEditingAllowed=false
C.saved_rules.load(doc.extras)
assert(C.rules.shown(MRPP,'hunterGravity')==2 and C.rules.get(MRPP,'hunterGravity')==1,'A selected document brings its extra rules for the next match')
gm.IsLiveRuleEditingAllowed=liveBefore
call(PAWN .. ':InitializeRules',pawn); assert(pawn.CharacterMovement.GravityScale==6)
call(CORE .. 'B_SeekGameMode.B_SeekGameMode_C:InitializeSeekTime',gm,function()
    for field in pairs(defs) do gs[field]=options.GameRules[field] end
end)
C.rules.apply()   -- (the match's start)
call(PAWN .. ':InitializeRules',pawn); assert(pawn.CharacterMovement.GravityScale==12)
call(PAWN .. ':InitializeRules',pawn); assert(pawn.CharacterMovement.GravityScale==12)
call(PAWN .. ':InitializeRules',pawn,function() pawn.CharacterMovement.GravityScale=7 end)
assert(pawn.CharacterMovement.GravityScale==14)
local replacement=instance({CharacterMovement=instance({GravityScale=9,AirControl=.1}),IsLocallyControlled=function() return true end})
call(PAWN .. ':InitializeRules',replacement); assert(replacement.CharacterMovement.GravityScale==18)
local cooldown=out(.1)
call('/Game/Blueprints/Skills/B_SkillParametersSubsystem.B_SkillParametersSubsystem_C:GetSkillCooldown',{},nil,1,1,cooldown)
assert(cooldown:get()==.4)
local delay=out(22)
call(CORE .. 'B_SeekGameMode.B_SeekGameMode_C:GetRoundEndTimerUntilRestart',gm,nil,delay); assert(delay:get()==29)
local spawn=out(40)
call(CORE .. 'B_GameMode.B_GameMode_C:GetPickupSpawnDelay',gm,nil,spawn); assert(spawn:get()==7)
local prop=instance({IsControlledByWitch=false,DissolvePropServer=function() error('should rearm, not dissolve') end})
call(PROP .. ':StartDestroyCountdown',prop); assert(not timerState.active)
gm.IsLiveRuleEditingAllowed=false
builds.rules({GetOwningPlayer=function()return{}end})
local pages={}
for _,spec in ipairs(C.rules.specs(MRPP)) do pages[spec.key]=spec.page end
assert(pages.roundDelay=='general' and pages.witchGravity=='witches' and pages.hunterGravity=='hunters' and pages.trapSlow=='skill:5' and pages.detectionSparks=='powerup:4','The extra rules are declared on their pages')
-- The tab: rules as a code, and sliders that change nothing until moved.
assert(options.GameRules==stagedRules,'Opening the tab selects nothing')
local clipboard;R.native.clipboard_set=function(text) clipboard=text end
buttons['Export rules as code']();assert(clipboard:sub(1,6)=='MRPP2:','Export puts a code on the clipboard')
local named=api.decode(api.encode(doc));named.extras.MatchRulesPlusPlus.roundDelay=40
R.native.clipboard_get=function() return api.encode(named) end
buttons['Import rules from code']()
assert(options.GameRules~=stagedRules and C.rules.shown(MRPP,'roundDelay')==40,'An imported code is selected for the next match, its extra rules too')
C.rules.set(MRPP,'roundDelay',22)
assert(C.rules.section(MRPP).roundDelay==nil,'The game value leaves the rule out')
-- Where the game edits rules live, a moved slider is in force at once, like the native pages.
gm.IsLiveRuleEditingAllowed=true
C.rules.set(MRPP,'roundDelay',45)
assert(C.rules.get(MRPP,'roundDelay')==45,'A live match applies extra rules at once')
assert(published['core.rules'].MatchRulesPlusPlus.roundDelay==45,'Guests get the live change')
local liveDelay=out(22)
call(CORE .. 'B_SeekGameMode.B_SeekGameMode_C:GetRoundEndTimerUntilRestart',gm,nil,liveDelay); assert(liveDelay:get()==45)
-- A hunter with a Cannonball has the skill's air control; the extra rule is for the others.
local cannonPawn=instance({CharacterMovement=instance({GravityScale=6,AirControl=.05}),IsLocallyControlled=function() return true end})
local cannon=instance({GetOwner=function() return cannonPawn end})
local CANNON='/Game/Blueprints/Skills/Hunter/Cannonball/B_CannonballSkill.B_CannonballSkill_C:'
call(PAWN .. ':InitializeRules',cannonPawn)
assert(cannonPawn.CharacterMovement.AirControl==.4,'A hunter without Cannonball takes the extra air control')
call(CANNON .. 'InitializeRules',cannon,function() cannonPawn.CharacterMovement.AirControl=.3 end)
assert(cannonPawn.CharacterMovement.AirControl==.3,'Cannonball keeps its own air control')
call(CANNON .. 'OnSkillDownMulti',cannon);call(PAWN .. ':InitializeRules',cannonPawn)
assert(cannonPawn.CharacterMovement.AirControl==.3,'Later events leave the skill\'s air control')
-- Native BeginPlayTest sets its flag between PRE and POST; stop clears it before POST.
local creative='/Game/Blueprints/Gamemodes/CreativeMode/B_CreativeGameMode.B_CreativeGameMode_C:'
state.is_creative=true; state.is_playtest=false; gs.IsPlayTestMode=false
-- Creative authoring edits a draft even when native live-match editing is off.
-- Painting must keep the native control enabled without selecting any document.
local control=instance({Index=1,FloatParameter={Name=FName('GlobalGravity')},DefaultFloatValue=980,enabled=true,
    GetClass=function() return {GetFName=function() return FName('WB_SliderWithEditableLabel_C') end} end,
    SetRealValue=function(self,value) self.RealValue=value end,
    SetIsEnabled=function(self,value) self.enabled=value end})
local page={UIElements=array(function() end),OnParamSliderRealValueChanged=function() end}
page.UIElements[1]=control
local refresh='/Game/UserInterface/Play/GameRules/WB_MatchRules.WB_MatchRules_C:RefreshMatchRules'
local selection=saved.selected
gm.IsLiveRuleEditingAllowed=false
call(refresh,page)
assert(control.enabled and saved.selected==selection,'Creative authoring is not a live match edit')
assert(control.RealValue==400,'Creative authoring paints the detached next-match draft')
local authoredRules=options.GameRules
options.GameRules=rules() -- Native ResetAll clears the draft, not the running world.
call(refresh,page)
assert(control.RealValue==980 and saved.selected==selection,
    'Native Reset paints the control default instead of reapplying the active-world value')
options.GameRules=authoredRules
gs.IsPlayTestMode=true
call(refresh,page)
assert(not control.enabled,'An active playtest keeps its native live-edit restriction')
gs.IsPlayTestMode=false;control.enabled=true;state.is_creative=false
call(refresh,page)
assert(not control.enabled,'An ordinary active match keeps its native live-edit restriction')
control.enabled=true;state.role='client';state.is_creative=true
call(refresh,page)
assert(not control.enabled,'A guest sees the match rules as they are')
state.role='host';gm.IsLiveRuleEditingAllowed=true
local editorArray=gs.MatchRules
local function globalGravity(rows)
    local value
    rows:ForEach(function(_,entry)
        entry:get()[defs.MatchRules[2]]:ForEach(function(_,param)
            local p=param:get()
            if p.Name:ToString()=='GlobalGravity' then value=p.FloatValue end
        end)
    end)
    return value
end
local editorGravity=globalGravity(editorArray)
prop.DissolvePropServer=function() prop.dissolved=true end
call(creative .. 'BeginPlayTest',gm,function() gs.IsPlayTestMode=true; state.is_playtest=true end)
assert(gs.MatchRules~=editorArray)
-- Native collection discards Lua-only objects while Play Test is running.
for _,value in ipairs(spawnedRules) do
    if value~=options.GameRules then
        for field in pairs(defs) do value[field]=nil end
        setmetatable(value,{__index=function(_,field)
            assert(not defs[field],'Native object expired');return nil
        end})
    end
end
call(creative .. 'EndPlayTest',gm,function() gs.IsPlayTestMode=false; state.is_playtest=false end)
assert(globalGravity(gs.MatchRules)==editorGravity and prop.dissolved,
    'Stopping Play Test reconstructs its native baseline from scalar values after native GC')
call(PAWN .. ':InitializeRules',pawn,function() pawn.CharacterMovement.GravityScale=6 end)
assert(pawn.CharacterMovement.GravityScale==6)
state.is_creative=false
local new=json.decode(json.encode(doc)); new.extras.MatchRulesPlusPlus.hunterGravity=3
assert(api.stage(new)); assert(pawn.CharacterMovement.GravityScale==6,'Rules for the next match change nothing in play')
state.is_vanilla_session=true
local seek=gs.SeekTime
call(CORE .. 'B_SeekGameMode.B_SeekGameMode_C:InitializeSeekTime',gm); assert(gs.SeekTime==seek)
assert(api.stage(doc),'(user 11-16) the rules of the game are exchanged in a vanilla session too')
local vanillaPaths={
 CORE..'B_GameState.B_GameState_C:UpdateMatchRules',
 CORE..'B_GameState.B_GameState_C:UpdateSkillRules',
 CORE..'B_GameState.B_GameState_C:UpdateModRules',
 CORE..'B_GameState.B_GameState_C:UpdatePowerupRules',
 CORE..'B_GameState.B_GameState_C:ResetAllRules',
 '/Game/UserInterface/Play/GameRules/WB_MatchRules.WB_MatchRules_C:ApplyChanges',
 '/Game/UserInterface/Play/GameRules/WB_MatchRules.WB_MatchRules_C:Apply Rules',
 '/Game/UserInterface/Play/GameRules/SkillRules/WB_SkillRules.WB_SkillRules_C:ApplyRules',
 '/Game/UserInterface/Play/GameRules/Mods/WB_ModConfigure.WB_ModConfigure_C:ApplyRules',
 '/Game/UserInterface/Play/GameRules/PowerupRules/WB_PowerupConfigure.WB_PowerupConfigure_C:ApplyRules',
 '/Game/UserInterface/Play/GameRules/WB_GameRulesTabs.WB_GameRulesTabs_C:ResetAllToDefault',
 '/Game/UserInterface/Play/GameRules/WB_SaveLoadGameRules.WB_SaveLoadGameRules_C:ResetRules'
}
for _,role in ipairs({'host','client'}) do
 state.role=role
 for _,page in ipairs({
  'WB_MatchRules.WB_MatchRules_C:RefreshMatchRules',
  'SkillRules/WB_SkillRules.WB_SkillRules_C:RefreshSkillRuleUI',
  'Mods/WB_ModConfigure.WB_ModConfigure_C:RefreshModifierUI',
  'PowerupRules/WB_PowerupConfigure.WB_PowerupConfigure_C:RefreshPowerupUI'
 }) do
  local widget={nativeValue=17,enabled=true}
  call('/Game/UserInterface/Play/GameRules/'..page,widget,function()
   widget.nativeValue=23
  end)
  assert(widget.nativeValue==23 and widget.enabled,'Vanilla native rule controls retain their own values and enabled state')
 end
 for _,path in ipairs(vanillaPaths) do
  local nativeCalls=0
  call(path,gm,function() nativeCalls=nativeCalls+1 end)
  assert(nativeCalls==1,'Vanilla native rules must execute unchanged: '..path)
 end
end
state.role='host'
state.is_vanilla_session=false
for _,fn in ipairs(events.round_start) do fn() end
state.role='client'
watches['mrpp.rules'](json.decode(json.encode(published['mrpp.rules'])))
assert(guestRow(),'A guest of a Tweakable match gets the rules row')
state.role='host';gm.IsLiveRuleEditingAllowed=false
for _,fn in ipairs(events.round_start) do fn() end
state.role='client'
watches['mrpp.rules'](json.decode(json.encode(published['mrpp.rules'])))
assert(not guestRow(),'A guest of any other match does not')
state.role='host';gm.IsLiveRuleEditingAllowed=true
for _,fn in ipairs(events.round_start) do fn() end
state.role='client'
watches['mrpp.rules'](published['mrpp.rules'])
watches['core.rules'](published['core.rules'])
local owningReplacement=instance({CharacterMovement=instance({GravityScale=11,AirControl=.1}),IsLocallyControlled=function() return true end})
call(PAWN .. ':InitializeRules',owningReplacement)
assert(owningReplacement.CharacterMovement.GravityScale==22)
-- A guest edits their own rules (kept between launches): nothing reaches the match until the
-- host accepts them; copying the match rules takes those again.
local rulesBefore=options.GameRules
local guestTab=builds.rules({GetOwningPlayer=function()return{}end})
guestTab()
combos['Show'].on_change('mine')
local inForce=published['core.rules'].MatchRulesPlusPlus.roundDelay
C.rules.set(MRPP,'roundDelay',46)
buttons['Export rules as code']()
assert(api.decode(clipboard).extras.MatchRulesPlusPlus.roundDelay==46,'A guest exports the rules they changed')
assert(options.GameRules==rulesBefore,'A guest changes no rules of the match')
local nativeSlider='/Game/UserInterface/Play/GameRules/WB_MatchRules.WB_MatchRules_C:OnParamSliderRealValueChanged'
call(nativeSlider,page,function() end,control,1234)
buttons['Export rules as code']()
local function exportedGravity()
    for _,entry in ipairs(api.decode(clipboard).native.match) do
        if entry.id==control.Index then return entry.values.GlobalGravity end
    end
end
assert(exportedGravity()==1234,'A guest exports the native rules they moved')
control.RealValue=nil;call(refresh,page)
assert(control.RealValue==1234,'The native page shows the guest\'s own value')
assert(options.GameRules==rulesBefore,'A guest\'s native edit changes nothing of the match')
assert(C.rules.shown(MRPP,'roundDelay')==46 and C.rules.get(MRPP,'roundDelay')==inForce,'A guest\'s own rules stay theirs')
-- The tiles of the rules pages light by the rules shown: a guest's own against the host's, the mods'
-- rules on that page counted.
local ACTIVE,IDLE={R=.6,G=.3,B=1,A=1},{R=1,G=1,B=1,A=1}
local function lit(t)
    local color=out(IDLE)
    call('/Game/UserInterface/GameRules/WB_SkillTileButton.WB_SkillTileButton_C:GetBorderColor',{SkillType=5,ActiveRuleColor=ACTIVE,NoRuleActiveColor=IDLE},nil,color)
    return color:get()==ACTIVE
end
assert(not lit(),'A skill page the guest left as the host has it is not lit')
C.rules.set(MRPP,'trapDelay',1)
assert(lit(),'A guest\'s own rule on the Trap page lights the Trap tile')
C.rules.set(MRPP,'trapDelay',.25)
assert(not lit(),'Back as the host has it: not lit')
-- Offering them: the host gets one offer a player, accepts, views or rejects it.
buttons['Offer my rules to the host']()
assert(requests.sent[1]=='mrpp.offer','The offer goes to the host')
local offered=requests.sent[2]
-- Reset all in "My rules" takes the guest's own rules back to the match's.
local shownPage={Init=function(self) self.inited=true end}
call('/Game/UserInterface/Play/GameRules/WB_GameRulesTabs.WB_GameRulesTabs_C:ResetAllToDefault',{RulesSwitcher={GetActiveWidget=function() return shownPage end}},function() error('the game reset a guest\'s rules') end)
buttons['Export rules as code']()
assert(exportedGravity()~=1234,'Reset all drops the guest\'s native edits')
assert(shownPage.inited,'and the page shown paints the match\'s rules again')
buttons['Copy the match rules to my rules']();buttons['Export rules as code']()
assert(exportedGravity()~=1234,'Copying the match rules drops the guest\'s native edits')
assert(api.decode(clipboard).extras.MatchRulesPlusPlus.roundDelay==inForce,'Copying returns to the rules being played')
assert(call(CORE .. 'B_GameState.B_GameState_C:UpdateMatchRules',{},function() error('guest applied') end)=='consumed')
-- The host's queue: one offer a player, a new one at the end; View lists what differs.
state.role='host'
local texts={}
local text=U.text;U.text=function(parent,opts) texts[#texts+1]=opts.text;return text(parent,opts) end
local function player(id,name) return {GetAddress=function() return id end,GetPlayerName=function() return name end} end
requests['mrpp.offer'](player('a','Alice'),offered);requests['mrpp.offer'](player('b','Bob'),offered);requests['mrpp.offer'](player('a','Alice'),offered)
requests['mrpp.offer'](player('c','Eve'),{document='junk'})
texts={};builds.rules({GetOwningPlayer=function()return{}end})()
local lines={}
for _,t in ipairs(texts) do if t:find('offers rules',1,true) then lines[#lines+1]=t end end
assert(#lines==2 and lines[1]=='Bob offers rules' and lines[2]=='Alice offers rules','Offers queue by arrival; a new offer replaces the player\'s own at the end; junk is dropped')
texts={};buttons['View']()
local shown=table.concat(texts,'\n')
assert(shown:find('General',1,true) and shown:find('Time between rounds (s):  ',1,true),'View lists what differs in the tab, under the page it is on')
U.text=text;state.role='client'
for _,fn in ipairs(events.world_end) do fn() end
state.role='host'; state.is_vanilla_session=true
call(PAWN .. ':InitializeRules',replacement,function() replacement.CharacterMovement.GravityScale=11 end)
assert(replacement.CharacterMovement.GravityScale==11)
-- Main menu: rules go to the Custom Match options, which hosting carries into the match.
local custom={GameMode=modeClass,GameRules=rules()}
function custom:GetGameRules() return self.GameRules end
state.role='offline';state.is_vanilla_session=false
local menuOptions={GameMode=modeClass,GameRules=rules()}
function menuOptions:GetGameRules() return self.GameRules end
state.gi={IsCurrentlyInMatch=false,NextMatchOptions=options,CustomMatchOptions=custom,UsedMatchOptions=custom}
R.find=function(path) if path:find('WB_Custommatch',1,true) then return {NextMatchOptions=menuOptions} end end
local before,customBefore=options.GameRules,custom.GameRules
assert(api.stage(doc) and menuOptions.IsUsingCustomRules==true and options.GameRules==before and custom.GameRules==customBefore,
    'Main-menu selection edits the options of the open Custom Match screen, which hosting copies')
-- Native Create recomputes the flag from the menu world (false) and copies the screen's options
-- into UsedMatchOptions; HostGame must leave their rules in force.
custom.GameMode=modeClass;custom.IsUsingCustomRules=false;custom.GameRules=menuOptions.GameRules
options.IsUsingCustomRules=false
call('/Game/Blueprints/Core/B_GameInstance.B_GameInstance_C:HostGame',state.gi)
assert(custom.IsUsingCustomRules==true and custom.GameRulesToLoad=='','Hosting keeps the rules selected for the next match')
assert(options.IsUsingCustomRules==true,'Later matches copy the next-match options, which keep the rules too')
print('PASS: inventory, portable codes, native allocation, selection, early TIME1, delivered physics, native OUT edits, timer aging, Creative stop/restore, UI painting, unique saves, offers/proposals, owning replacements, next-match staging, Vanilla/guest protection, travel')
-- A registered ability's rules of the game are captured with the game's.
nitroParams.PullStrength=2500
local captured=api.capture(true)
assert(captured.effective['skills:200'] and captured.effective['skills:200'].PullStrength==2500,'Its rules now are captured with the game\'s')
print('PASS: a registered ability\'s rules are a group of their own, captured like the game\'s')
