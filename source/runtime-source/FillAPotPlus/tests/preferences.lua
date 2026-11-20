-- Fill a Pot+ rules (Core's rules), the rules tab, Custom Match visibility and the per-match rule
-- snapshot. The session mode itself is decided by Core.
local stored={uncapped=true,respawn=7,lives='infinite',order='pots,wins,lives,kills,time,props'}
local pref,saves,published,roundStart=nil,0
local ruleOwners={}
local S={R={},C={memory={shown_by=function() end,on=function() return true end,register=function() end},mods={config={rules={FillAPotPlus=stored}}}},U={},CORE='',O='',MATCH='',codec={ID='monroth.fap'},F={file='file'}}
function S.R.settings(_,defaults)
 if not pref then pref={};for k,v in pairs(defaults)do pref[k]=v end end
 return pref
end
function S.R.save_settings()saves=saves+1 end
local pre,post={},{}
function S.R.pre(path,fn)pre[path]=fn end
function S.R.post(path,fn)post[path]=post[path] or {};table.insert(post[path],fn)end
local events={}
function S.R.on(event,fn)if event=='round_start' then roundStart=fn else events[event]=fn end end
function S.R.valid(v)return v end
S.C.net={watch=function()end,publish=function(_,value)published=value end}
function S.C.on_session()end
-- (Core's Vanilla server setting of the options)
local vanillaServer=true
S.C.mods={vanilla=function() return vanillaServer end}
local function is_plus(o) return S.selected(o) end
local function gameMode(name) return {GetFName=function() return {ToString=function() return name end} end} end
local session={role='host',mode='vanilla',gs={}}
function S.C.session()return session end
function S.path()return ''end
function S.text(value)return value end
function S.values(v)return v end
function S.asset()return 'objective'end
function FText(v)return v end
function FName(v)return v end
local build
function S.U.rules_tab(id,fn)assert(id=='match_rules');build=fn end
dofile('candidate/runtime-source/FillAPotPlus/tests/lib/scope.lua')(S)
S.C.saved_rules={register=function(id,value) ruleOwners[id]=value end}
S.C.state=S.C.state or function() end
S.C.rules=dofile('candidate/runtime-source/Core/rulebook.lua')(S.R,S.C)
local PKG='FillAPotPlus'
local function shown(key) return S.C.rules.shown(PKG,key) end
local function load()dofile('candidate/runtime-source/FillAPotPlus/rules.lua')(S)end
local rowKeys={}
function S.U.rule_rows(_,pkg,keys) assert(pkg==PKG);local controls={};for i,k in ipairs(keys) do rowKeys[k]=true;controls[i]={InputField={Slot={Padding={Left=0,Top=0,Right=0,Bottom=0},SetHorizontalAlignment=function()end,SetPadding=function()end}}} end;return controls,function() end end
load()
local owner=ruleOwners[PKG]
assert(shown('uncapped')==false and shown('lives')==4,'Rules start at their defaults (Core\'s memory brings kept ones back)')
owner.load(stored)
assert(shown('uncapped')==true and shown('respawn')==7 and shown('lives')=='infinite' and shown('order')==stored.order,'A kept section loads whole')
assert(saves==0,'Loading never rewrites the settings file')
owner.load({order='wins,wins,pots'})
assert(shown('order')=='wins,time,pots,lives,props,kills','An invalid order falls back to the default')
owner.load(stored)
print('PASS FAP rules load as kept; an invalid order falls back')

-- Rules tab and Custom Match rows.
local rows={}
local controlsParent={}
local function widget()
 return {SetVisibility=function()end,GetParent=function()return controlsParent end,
  InputField={Slot={Padding={Left=0,Top=0,Right=0,Bottom=0},SetHorizontalAlignment=function()end,SetPadding=function()end}}}
end
function controlsParent:SetVisibility()end
function controlsParent:GetAllChildren() return {} end
for _,kind in ipairs({'section','slider','checkbox','combo','text','button','dropdown'})do
 S.U[kind]=function(_,opts)
  local key=opts and (opts.label or opts.text)
  if key then rows[key]=opts end
  return widget(),function(value)if opts then opts.label=value end end
 end
end
function S.U.navigate()end
function S.U.flow()return widget()end
function S.U.fill(w)return w end
function S.U.place_after()end
function S.U.match_column()return widget()end
-- (UIKit's building blocks: any part, doing nothing; the rows' arrangement is custom_match.lua's)
local function anything() return setmetatable({},{__index=function() return anything() end,__call=function() return anything() end}) end
S.U.parts=setmetatable({values=function(v) return v end},{__index=function() return anything() end})
build({})
local customUI={GetAddress=function()return 20 end,ComboBox_TeamChoice={GetParent=function() return nil end,GetVisibility=function() return 1 end,DescriptiveLabelText={GetText=function() return 'Team Choice' end,SetText=function()end}},NextMatchOptions={GetAddress=function()return 18 end,MapData={file='RandomMapCycle'}},Slider_WitchLives=widget(),Slider_RequiredPlayersPerTeam=widget(),
 ComboBox_GameMode={SelectedOption='Fill a Pot (Experimental)',SelectedOptionLabel={SetText=function(self,v) self.text=v end}}}
for _,fn in ipairs(post['/Game/UserInterface/Play/WB_Custommatch.WB_Custommatch_C:Construct'])do fn(customUI)end
assert(not rowKeys.uncapped,'Another mode\'s screen gets none of Fill a Pot+\'s rows (made only once it is chosen)')
customUI.NextMatchOptions.GameMode={IsValid=function() return true end,GetFName=function() return {ToString=function() return 'B_ObjectiveGameMode_C' end} end}
vanillaServer=false
for _,fn in ipairs(post['/Game/UserInterface/Play/WB_Custommatch.WB_Custommatch_C:Construct'])do fn(customUI)end
vanillaServer=true
assert(rowKeys.uncapped and rowKeys.single and rowKeys.lives and rowKeys.extras and rowKeys.respawn,'The Custom Match screen and the tab show the rules')
local specs={};for _,spec in ipairs(S.C.rules.specs(PKG)) do specs[spec.key]=spec end
assert(specs.lives.infinite and specs.lives.min==1 and specs.lives.sliderMax==10 and specs.lives.max==255 and specs.lives.integer)
assert(specs.lives.initial==4 and specs.respawn.initial==5 and specs.revive.initial==3,'The rules reset to the game\'s values')
S.C.rules.set(PKG,'order','wins,time,pots,lives,props,kills');S.C.rules.apply()
rows={};build({})
local frozen=S.C.rules.get(PKG,'order')
local first=rows['Winner priority 1: Halves won']
first.on_click();assert(shown('order')=='time,pots,lives,props,kills,wins')
first.on_click();assert(shown('order')=='pots,lives,props,kills,wins,time','Repeated click moves the current criterion, preserving the permutation')
assert(first.label=='Winner priority 1: Full cauldrons','Order labels follow the edited order')
assert(S.C.rules.get(PKG,'order')==frozen,'Clicks change the next match\'s rules, never the ones in force')
rows={};build({})
assert(rows['Winner priority 1: Full cauldrons'],'Reopening shows the edited order')
-- The criteria Fill a Pot has are on; delivered props and hunter kills are off.
local r={order=shown('order'),off=shown('off')}
assert(r.off=='props,kills' and table.concat(S.ranked(r),',')=='pots,lives,wins,time')
r.order='wins,time,pots,lives,props,kills'
assert(table.concat(S.ranked(r),',')=='wins,time,pots,lives','The default decides as Fill a Pot does')
print('PASS rules tab rows, reset defaults and winner order editing')

-- Custom Match: Fill a Pot+ is Fill a Pot on a server that is not vanilla.
local controls={}
for i=1,3 do controls[i]={SetVisibility=function(self,v)self.visibility=v end} end
local options={GetAddress=function()return 19 end,GameMode=gameMode('B_ObjectiveGameMode_C'),MapData={file='RandomMapCycle'}}
local w={GetAddress=function()return 21 end,NextMatchOptions=options,AllControlsShow=controls,ObjectiveControlsHide={controls[2]},
 Slider_MaxPlayers={},Slider_RequiredPlayersPerTeam={MinimumValue=1,MaximumValue=3,GetParent=function() return controlsParent end},ComboBox_GameMode={SelectedOption='Fill a Pot (Experimental)',SelectedOptionLabel={SetText=function(self,v) self.text=v end}},Slider_WitchLives=widget(),ComboBox_TeamChoice={SetVisibility=function()end,GetVisibility=function() return 0 end,GetParent=function() return nil end,SetOptionIndex=function(self,i) self.index=i end,DescriptiveLabelText={GetText=function() return 'Team Choice' end,SetText=function()end}}}
local custom='/Game/UserInterface/Play/WB_Custommatch.WB_Custommatch_C:'
local function loadMenu()for _,fn in ipairs(post[custom..'LoadCustomMatchOptions'])do fn(w)end end
assert(pre[custom..'UpdateWidgetVisibility'](w)==nil and controls[1].visibility==nil,'Unselected options stay native')
w.InGame=true;session.mode='vanilla';loadMenu()
w.InGame=false;loadMenu()
assert(not is_plus(options),'Fill a Pot on a vanilla server is the game\'s own')
vanillaServer=false;assert(is_plus(options),'... and on a server that is not vanilla, Fill a Pot+')
-- The game's objective map gives way only to a saved map this mode plays.
S.C.catalog=S.C.catalog or {};S.C.catalog.plays=function(o) return o.playsHere==true end
S.C.catalog.unpick=function(o) o.CustomMapSelected=false end
options.CustomMapSelected=true;options.playsHere=false;options.MapData={file='/Game/Maps/Snowbreeze'}
assert(pre[custom..'ForceObjectiveMap'](w)==nil and not options.CustomMapSelected,'A saved map of another mode is taken back for the game\'s map')
options.CustomMapSelected=true
options.playsHere=true
assert(pre[custom..'ForceObjectiveMap'](w)==true,'A saved map this mode plays stays chosen')
options.CustomMapSelected=false;options.playsHere=nil;options.MapData={file='RandomMapCycle'}
assert(pre[custom..'UpdateWidgetVisibility'](w)==true)
assert(controls[1].visibility==0 and controls[1].bIsFocusable)
assert(controls[2].visibility==1 and not controls[2].bIsFocusable)
assert(w.Slider_MaxPlayers.MaximumValue==16)
assert(w.Slider_RequiredPlayersPerTeam.MinimumValue==0 and w.Slider_RequiredPlayersPerTeam.MaximumValue==8,'The game\'s own Required Players holds 0 to 8 in Fill a Pot+')
-- The player picks another mode: it is no longer Fill a Pot+, and its maps go (maps.lua).
local pick=custom..'BndEvt__ComboBox_GameMode_K2Node_ComponentBoundEvent_0_OnSelectionChanged__DelegateSignature'
local left;S.modeChanged=function(plus) left=not plus end
options.GameMode=gameMode('B_HideAndSeekGameMode_C')
for _,fn in ipairs(post[pick])do fn(w)end
assert(not is_plus(options) and left,'Another mode is not Fill a Pot+')
vanillaServer=true
print('PASS Fill a Pot+ is Fill a Pot off a vanilla server; visibility owns only UI controls')

-- Live UE4SS manager wrappers can compare unequal while addressing the same manager.
session.role='host';session.mode='monroth.fap'
session.gi={SessionManager={UpdateSessionProperties=function()end},NextMatchOptions={TeamSwitchingOption=1},UsedMatchOptions={DisableStartMatchTimer=false}};session.gm={}
local manager={address=100,round=1}
function S.manager()return {CurrentRound=manager.round,GetAddress=function()return manager.address end}end
function S.C.replicate(object,key,value)object[key]=value end
roundStart();local firstMatch=S.match
firstMatch.rounds[1]={done=true}
manager.round=2;S.C.rules.set(PKG,'order','time,wins,pots,lives,kills,props');S.C.rules.apply()
roundStart();roundStart()
assert(S.match==firstMatch and firstMatch.rounds[1].done and firstMatch.rules==nil,'Halftime and repeated start retain first-half facts; the rules are the ones in force (no copy, audit 11-20)')
manager.address=101;roundStart();assert(S.match~=firstMatch,'A different native manager begins a different match')
firstMatch=S.match;manager.round=1;roundStart();assert(S.match~=firstMatch,'A new match on the same native manager clears the preceding rounds')
session.mode='vanilla';firstMatch=S.match;manager.address=102;roundStart()
assert(S.match==firstMatch,'Round starts outside Plus never touch the Plus match record')
print('PASS native match-manager identity survives fresh wrappers at halftime; vanilla rounds are ignored')

-- Rules files and codes: bad values from another player fall back to the defaults.
session.mode='plus'
owner.load({respawn=-1,order='wins,wins',lives='many',revive=7,totems=1.5,plusMode=true,roleChoice=false,startReady='yes'})
assert(shown('respawn')==5 and shown('order')=='wins,time,pots,lives,props,kills' and shown('lives')==4 and shown('totems')==1)
owner.load({respawn=1e9});assert(shown('respawn')==1e9,'A large value is taken: only a meaningless one is refused');owner.load({revive=7})
assert(shown('revive')==7,'A valid rule is taken')
owner.load({lives='infinite'})
assert(shown('lives')=='infinite' and shown('revive')==3,'A load replaces the rules')
local section=owner.save()
assert(section.lives=='infinite' and section.plusMode==nil and section.roleChoice==nil and section.startReady==nil,'Menu choices are no rules')
session.role='client'
S.C.rules.mine(true)
owner.load({lives=3})
assert(owner.save().lives==3,'A guest\'s imported rules stay their own')
S.C.rules.mine(false)
assert(owner.save().lives~=3,'The match rules are the host\'s')
session.role='host'
print('PASS rules files and codes reach FAP+ checked, and leave menu choices alone')
