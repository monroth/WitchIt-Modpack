local loadedRules   -- (how often the screen loaded the options' rules into the menu world)
-- Remembered match settings: each mode of Custom Match keeps what its screen shows (controls, map,
-- the mods' rules), Creative its own; the first open in a launch is as last hosted; switching the
-- mode keeps the old one and brings back the new one; off, nothing is kept or restored.
local base=arg and arg[1] or 'candidate/runtime-source/'
local hooks,saves={},0
local config={RememberSettings=true}
local function key(path) return path:match('([^.]+_C):')..':'..path:match(':(.+)$') end
local events={}
local R={log=function() end,on=function(name,fn) events[name]=fn end,pre=function(path,fn) hooks[key(path)]=fn end,post=function(path,fn) hooks['post '..key(path)]=fn end,
    save_settings=function() saves=saves+1 end,valid=function(o) return o end,
    native={load_asset=function(path) return {path=path} end}}
local V=dofile('candidate/runtime-source/WitchItRuntime/Scripts/values.lua');R.values,R.text=V.values,V.text
dofile('candidate/runtime-source/Core/tests/lib/mods.lua')(R)
local picked
-- (a mod mode the options choose when the server is not vanilla, as Fill a Pot+)
local C={mods={config=config,VANILLA={match={key='VanillaServer',default=true},creative={key='CreativeVanillaServer',default=false}},set_vanilla=function(which,value) config[which=='creative' and 'CreativeVanillaServer' or 'VanillaServer']=value end},catalog={pick=function(file) picked=file end},
    map={chosen=function() if config.VanillaServer==false then return 'monroth.fap' end end},
}
dofile('candidate/runtime-source/Core/game.lua')(R,C)
dofile('candidate/runtime-source/Core/choice.lua')(C.catalog,C,function() return picked end,function(file) picked=file end)
local function name(v) return {ToString=function() return v end} end
local function options()
    local o={GameRules='',IsUsingCustomRules=false,MaxPlayers=10,HideTime=25,IsPublic=true,IsTournamentMode=false,IsPublicCreative=false,CustomMapSelected=false,IsCreativeMode=false,DisableStartMatchTimer=false,SpectatorsCanSeeWitches=false,
        MapData={FileName_10_98BC71FF40A2DA9A28FA21B92157D6D9=name('/Game/Maps/Default')},
        LayoutData={FileName_6_F3CC8069497D007AD2E96A9AE00D2700=name('')},
        GameMode={GetFullName=function() return 'BlueprintGeneratedClass /Game/Modes/Seek.Seek_C' end}}
    local kinds={MaxPlayers='IntProperty',HideTime='IntProperty',IsPublic='BoolProperty',CustomMapSelected='BoolProperty',
        IsCreativeMode='BoolProperty',DisableStartMatchTimer='BoolProperty',SpectatorsCanSeeWitches='BoolProperty',MapData='StructProperty',GameRulesToLoad='StrProperty'}
    function o:GetClass() return {ForEachProperty=function(_,fn)
        for n,k in pairs(kinds) do fn({GetFName=function() return name(n) end,GetClass=function() return {GetFName=function() return name(k) end} end}) end
    end} end
    function o:GetAddress() return tostring(self) end
    function o:SetGameMode(mode) self.GameMode={GetFullName=function() return 'BlueprintGeneratedClass '..mode.path end} end
    function o:CopyMatchOptions(source)
        for k,v in pairs(source) do
            if type(v)~='function' and k~='SpectatorsCanSeeWitches' then self[k]=v end
        end
    end
    return o
end
local function map(entries) return {Contains=function(_,key) return entries[key]~=nil end,
    Find=function(_,key) assert(entries[key],'Find throws on a missing key');return {get=function() return entries[key] end} end} end
local scans=0
local gi={NextMatchOptions=options(),MapManager={MapDataByFileName=map({['/Game/Maps/Town']={tag='town',FileName_10_98BC71FF40A2DA9A28FA21B92157D6D9=name('/Game/Maps/Town')}}),
    LayoutDataByFileName=map({['C:/maps/mine.pl']={tag='mine',FileName_6_F3CC8069497D007AD2E96A9AE00D2700=name('C:/maps/mine.pl')}}),
    SetLayoutDataByFileName=function() scans=scans+1 end}}
-- Match options are SaveGame objects, not world contexts; a widget can resolve the instance.
StaticFindObject=function() return {GetGameInstance=function(_,context)
    if context.GetClass then return nil end
    return gi
end} end
gi.CreativeMatchOptions=options();gi.UsedMatchOptions=options();gi.CustomMatchOptions=options()
-- A screen: each control (any name) visible unless named hidden.
local function screenOf(hidden,extra)
    return setmetatable(extra or {},{__index=function(w,control)
        if not control:match('^CheckBox_') and not control:match('^Slider_') and not control:match('^ComboBox_') then return nil end
        local c={IsVisible=function() return not hidden[control] end,SetIsCheckedWithoutEvent=function() end}
        function c:SetRealValue(v) self.value=v end
        rawset(w,control,c);return c
    end})
end
local rules={value=nil}
local owner={save=function() return rules.value end,load=function(v) rules.value=v end}
local M=dofile(base..'Core/memory.lua')(R,C)
M.register('Mod',owner)
-- The game handling a choice of mode in the screen's list (live 11-19, ProbeCustomMatch): the mode set,
-- then SetGameModeDefaultValues writes that mode's defaults (HideTime 60); the game does not load the
-- options itself. Loading options selects their mode in the list again: a choice the game handles too.
local change='WB_Custommatch_C:BndEvt__ComboBox_GameMode_K2Node_ComponentBoundEvent_0_OnSelectionChanged__DelegateSignature'
local DEFAULTS='WB_Custommatch_C:SetGameModeDefaultValues'
local function handle(w,o,path)
    if hooks[change] and hooks[change](w) then return end
    o:SetGameMode({path=path})
    if hooks[DEFAULTS] then hooks[DEFAULTS](w) end
    o.HideTime=60
    if hooks['post '..DEFAULTS] then hooks['post '..DEFAULTS](w) end
end
local function custom(o,hidden)
    local list={}
    local w
    local function shown() return o.GameMode and o.GameMode:GetFullName():match('(%S+)$') or '' end
    w=screenOf(hidden or {},{InGame=false,NextMatchOptions=o,GetAddress=function() return 'screen' end,ComboBox_GameMode=list,
        -- (loading writes the mode's defaults itself before showing the options, live 11-19, and selects
        -- the mode in the list: a choice the game handles too)
        LoadCustomMatchOptions=function()
            if hooks[DEFAULTS] then hooks[DEFAULTS](w) end
            o.HideTime=60
            if hooks['post '..DEFAULTS] then hooks['post '..DEFAULTS](w) end
            -- (showing the options, the screen writes the map's Hide and Seek times again, live 11-19)
            w.Slider_HideTime.value=o.HideTime
            o.HideTime=60;w.Slider_HideTime.value=60
            local times=hooks['post WB_Custommatch_C:SetHideAndSeekTimes'];if times then times(w) end
            list.SelectedOption=shown()
            handle(w,o,shown())
            hooks['post WB_Custommatch_C:LoadCustomMatchOptions'](w)
        end,
        -- (the options' rules into the menu world's rule values: counted, the test asks it happened)
        LoadGameRules=function() loadedRules=(loadedRules or 0)+1 end})
    return w
end
-- Hosting keeps the hosted mode: shown controls, the map, the mod mode, the mods' rules.
local hiddenNow={CheckBox_TournamentMode=true}
local w=custom(gi.NextMatchOptions,hiddenNow)
hooks['WB_Custommatch_C:Construct'](w)
local o=gi.NextMatchOptions
o.MaxPlayers,o.HideTime,o.IsPublic,o.IsTournamentMode=6,60,false,true
o.MapData.FileName_10_98BC71FF40A2DA9A28FA21B92157D6D9=name('/Game/Maps/Town')
o.CustomMapSelected=true;o.LayoutData.FileName_6_F3CC8069497D007AD2E96A9AE00D2700=name('C:/maps/mine.pl')
config.VanillaServer=false;rules.value={lives=3}
gi.UsedMatchOptions=o
hooks['B_GameInstance_C:HostGame'](gi)
local key='/Game/Modes/Seek.Seek_C+monroth.fap'
local record=config.remembered.modes[key]
assert(config.remembered.last==key and record.fields.MaxPlayers==6 and record.layout=='C:/maps/mine.pl' and record.vanilla==false,'Hosting keeps the mode as hosted')
assert(record.fields.IsTournamentMode==nil,'A value the screen hides is not kept')
-- A control not shown at the moment of keeping keeps the value it had (live 11-20: the record lost all
-- but two values, kept as the screen was left with its controls hidden).
hiddenNow.Slider_HideTime=true;o.HideTime=1
hooks['B_GameInstance_C:HostGame'](gi)
assert(config.remembered.modes[key].fields.HideTime==60,'a control hidden right now keeps its kept value')
hiddenNow.Slider_HideTime=nil;o.HideTime=60
assert(record.rules.Mod.lives==3,'The mods\' rules are kept with the mode')
-- The next launch: empty options, default rules; Custom Match opens as hosted.
gi.NextMatchOptions=options();rules.value=nil;config.VanillaServer=true
M=dofile(base..'Core/memory.lua')(R,C);M.register('Mod',owner)
hooks['WB_Custommatch_C:Construct'](custom(gi.NextMatchOptions))
o=gi.NextMatchOptions
assert(o.MaxPlayers==6 and o.HideTime==60 and o.IsPublic==false and o.IsTournamentMode==false,'The shown fields come back; the hidden one stays as the game starts it')
assert(C.map.chosen(o)=='monroth.fap' and rules.value.lives==3,'The mod mode and the mods\' rules come back')
assert(o.MapData.tag=='town' and o.LayoutData.tag=='mine' and o.CustomMapSelected and picked=='C:/maps/mine.pl' and scans==1,'The map comes back, picked, the saved maps read first')
-- The two boxes the game's loader leaves unchecked show the options.
local boxes={CheckBox_SpecatorsCanSeeWitches={},CheckBox_DisableStartTimer={}}
for _,b in pairs(boxes) do function b:SetIsCheckedWithoutEvent(v) self.checked=v end end
o.DisableStartMatchTimer=true
boxes.ComboBox_GameMode={SelectedOption='Seek'}
hooks['post WB_Custommatch_C:LoadCustomMatchOptions'](setmetatable(boxes,{__index={NextMatchOptions=o}}))
assert(boxes.CheckBox_DisableStartTimer.checked==true and boxes.CheckBox_SpecatorsCanSeeWitches.checked==false)
-- Switching the mode: the game writes the new mode's defaults while handling it, between the hooks.
local frames={}
R.next_frame=function(fn) frames[#frames+1]=fn end
local function frame() local now=frames;frames={};for _,fn in ipairs(now) do fn() end end
local mo=options();gi.NextMatchOptions=mo
local mw=custom(mo)
hooks['WB_Custommatch_C:Construct'](mw);hooks['post WB_Custommatch_C:Construct'](mw)
local function choose(path) mw.ComboBox_GameMode.SelectedOption=path;handle(mw,mo,path);frame() end
local function switchTo(path) choose(path);choose(path) end   -- (the second: the same mode chosen again)
mo.HideTime=11;rules.value={a=1}
switchTo('/Game/Modes/Objective.Objective_C')
assert(rules.value==nil,'A mode never kept has the mods\' default rules')
mo.HideTime=99;rules.value={b=2}
switchTo('/Game/Modes/Seek.Seek_C')
assert(mo.HideTime==11 and rules.value.a==1,'Hide and Seek gets its own back')
assert(mw.Slider_HideTime.value==11,'... and its screen shows it, over the map\'s times the screen writes (live 11-19: 55 showed 25)')
for _=1,3 do switchTo('/Game/Modes/Objective.Objective_C');switchTo('/Game/Modes/Seek.Seek_C') end
assert(mo.HideTime==11 and rules.value.a==1,'Back and forth any number of times: each mode keeps its own, never the game\'s defaults')
switchTo('/Game/Modes/Objective.Objective_C');assert(mo.HideTime==99 and rules.value.b==2)
-- The Vanilla server box chooses a mod mode (Fill a Pot+ off a vanilla server): a change of mode too.
-- (The box came back off with the mode last hosted.)
assert(config.VanillaServer==false)
M.switch(mw,function() config.VanillaServer=true end)
assert(rules.value==nil and config.VanillaServer==true,'The mode on a vanilla server, never kept, starts from the defaults')
rules.value={c=3};mo.HideTime=44
M.switch(mw,function() config.VanillaServer=false end)
assert(mo.HideTime==99 and rules.value.b==2,'Off a vanilla server: the mod mode\'s own come back')
M.switch(mw,function() config.VanillaServer=true end)
assert(mo.HideTime==44 and rules.value.c==3 and config.VanillaServer==true,'... and the vanilla one keeps its own, the box with it')
-- Leaving the screen for another menu keeps its mode's record as shown, without hosting.
mo.HideTime=55;hooks['B_MenuUIManager_C:ChangeMenu']({},1)
local key;for k,v in pairs(config.remembered.modes) do if v.fields.HideTime==55 then key=k end end
assert(key,'Left without hosting: the mode keeps what the screen showed')
-- Creative keeps its own.
local cw=screenOf({},{})
hooks['WB_CreativeGame_C:Construct'](cw)
gi.CreativeMatchOptions.MaxPlayers=4;gi.UsedMatchOptions=gi.CreativeMatchOptions
gi.CreativeMatchOptions.CustomMapSelected=true;gi.CreativeMatchOptions.LayoutData={FileName_6_F3CC8069497D007AD2E96A9AE00D2700=name('C:/maps/mine.pl')}
hooks['B_GameInstance_C:HostGame'](gi)
assert(config.remembered.creative.fields.MaxPlayers==4 and config.remembered.creative.fields.HideTime==nil,'Creative keeps its own options')
assert(config.remembered.creative.mode==nil,'Creative keeps no game mode: the game sets its own (a kept one once opened Creative as Fill a Pot)')
assert(config.remembered.creative.map==nil,'Creative keeps no map: it is the one picked in its list just before (a kept one replaced the pick, 11-18)')
assert(config.remembered.creative.layout==nil,'Creative keeps no saved layout either: a kept one replaced the layout just picked (the map of the click before, 11-18)')
-- Creative's map list borrows NextMatchOptions: the Custom Match draft waits and comes back once.
local play={}
mo.MaxPlayers,mo.HideTime,mo.SpectatorsCanSeeWitches=9,7,true
hooks['WB_Play_C:BndEvt__CreativeMode_K2Node_ComponentBoundEvent_1_Clicked__DelegateSignature'](play)
mo.MaxPlayers,mo.SpectatorsCanSeeWitches=4,false
hooks['B_MenuUIManager_C:ChangeMenu']({},1)
assert(mo.MaxPlayers==9 and mo.HideTime==7 and mo.SpectatorsCanSeeWitches,'Back from Creative: the draft is there again')
for _,v in pairs(config.remembered.modes) do assert(v.fields.MaxPlayers~=4,'Creative\'s scratch never lands in a mode\'s record') end
mo.HideTime=8;hooks['B_MenuUIManager_C:ChangeMenu']({},9)
assert(mo.HideTime==8,'Restored only once')
-- A Creative record kept with a mode or a layout (older builds) never sets Creative's mode or map on
-- the next launch: the layout picked in its list just before stays.
config.remembered.creative.mode='/Game/Modes/Objective.Objective_C';config.remembered.creative.layout='C:/maps/mine.pl'
gi.CreativeMatchOptions.LayoutData={tag='clicked'}
M=dofile(base..'Core/memory.lua')(R,C)
local set=false;function gi.CreativeMatchOptions:SetGameMode() set=true end
hooks['WB_CreativeGame_C:Construct'](screenOf({},{}))
assert(not set,'Creative keeps the game\'s own mode')
assert(gi.CreativeMatchOptions.LayoutData.tag=='clicked','Creative keeps the layout just picked (not the one hosted before)')
-- A saved record without its modes (only Creative kept, or the empty table not written back): choosing a
-- mode keeps and brings without failing (live VM1 11-20: 'Core stopped working').
config.remembered={creative={fields={},rules={}}}
switchTo('/Game/Modes/Objective.Objective_C')
assert(type(config.remembered.modes)=='table','the record is whole again')

-- A world ended: the menu screen of the world left behind is no longer kept when a menu changes
-- (live 11-20: leaving a match kept the lobby's old screen and its rules read from the ending world).
local before=saves
events.world_end()
hooks['B_MenuUIManager_C:ChangeMenu']({},1)
assert(saves==before,'after the world ended no screen of it is kept')

assert(loadedRules and loadedRules>0,'a mode switch loads the mode\'s rules into the rule screens (LoadGameRules)')
print('PASS remembered settings: per mode (controls, map, mod mode, mods\' rules), first open as last hosted, switching keeps each mode, Creative its own, draft kept away')
