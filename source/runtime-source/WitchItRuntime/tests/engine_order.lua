local scripts='candidate/runtime-source/WitchItRuntime/Scripts/'
local callbacks,notifies,queue,intercepts={},{},{},{}
local objects={}
local valid={IsValid=function() return true end}
local next_address=0
valid.GetAddress=function(self) return self.address end
local function object(t) next_address=next_address+1;t=t or {};t.address=t.address or next_address;return setmetatable(t,{__index=valid}) end
local function param(value)
 local u=io.tmpfile();u:close()
 debug.setmetatable(u,{__index={type=function() return 'RemoteUnrealParam' end,
  get=function() return value end,set=function(_,v) value=v end}})
 return u
end
function StaticFindObject(path) return objects[path] or {IsValid=function() return false end} end
objects['/Script/Engine.Default__KismetSystemLibrary']=object({GetProjectSavedDirectory=function() return '/tmp/wir-rewrite-engine-order' end})
objects['/Script/Engine.Default__GameplayStatics']=object({GetGameState=function() return object({GetClass=function() return {GetFName=function() return {ToString=function() return 'B_CreativeGameState_C' end} end} end,IsPlayTestMode=true}) end,
 GetGameMode=function() return object() end})
function WitchItNativePrimitives() return function(op,...)
 if op=='intercept' then local path,fn=...;intercepts[path]=fn
 elseif op=='input' then callbacks.input=...
 elseif op=='source_actors' then
  local world,count,row=...;local args=table.pack(row(1))
  assert(args.n==16 and args[6]==1 and args[14]==9 and args[15]=='Mesh')
  return {['1']=world}
 end
 return 1
end end
local saved,loaded
function WitchItNativeProducerAttach(save,load) saved,loaded=save,load;return true end
function WitchItNativeFunctionSchema() return {count=2,['out:2']=true,return_name='ReturnValue'} end
function RegisterHook(path,pre,post) callbacks[path]={pre=pre,post=post} end
function NotifyOnNewObject(path,fn) notifies[path]=fn end
function ExecuteInGameThreadAfterFrames(_,fn) queue[#queue+1]=fn;return #queue end
ExecuteInGameThreadWithDelay=ExecuteInGameThreadAfterFrames
function CancelDelayedAction() end -- A published executor may still drain once.
function FindAllOf() return {} end
for _,event in ipairs({'LoadMapPre','LoadMapPost','InitGameStatePost','BeginPlayPre','BeginPlayPost','EndPlayPre'}) do
 _G['Register'..event..'Hook']=function(fn) callbacks[event]=fn end
end
local R=dofile(scripts..'runtime.lua')()
local announced={}
R.on('failure',function(why) announced[#announced+1]=why end)
-- Native automatic skill countdown calls HandleStartMatch directly. Manual
-- Ready additionally calls StartGame; only OnMatchStartedMulti covers both,
-- including the second half and each client's reliable multicast receipt.
local objective='/Game/Blueprints/Gamemodes/ObjectiveMode/B_ObjectiveGameState.B_ObjectiveGameState_C'
objects[objective]=object({GetCDO=function(self) return self end})
objects[objective..':OnMatchStartedMulti']=object({GetFunctionFlags=function() return 0 end})
assert(notifies[objective]()==true,'a class whose hooks are in ends its new-object notification')
local starts={}
R.on('match_start',function(gs) starts[#starts+1]='match:'..gs.half end)
R.on('round_start',function(gs) starts[#starts+1]='round:'..gs.half end)
for _,half in ipairs({'countdown-host-1','countdown-client-1','ready-host-2','ready-client-2'}) do
 callbacks[objective..':OnMatchStartedMulti'].pre(param(object({half=half})))
 assert(starts[#starts-1]=='match:'..half and starts[#starts]=='round:'..half)
end
assert(#starts==8 and not callbacks[objective..':OnGameStartedMulti'],
 'Manual Ready must not deliver a second round_start after the half multicast')
assert(R.settings('FreshHostingPolicy',{VanillaServer=true}).VanillaServer,'Fresh hosting preference is checked')
R.prepare_directory('SavedHostingPolicy')
assert(R.native.file_write('/tmp/wir-rewrite-engine-order/WitchItRuntime/SavedHostingPolicy/settings.json','{"VanillaServer":false}'))
assert(R.settings('SavedHostingPolicy',{VanillaServer=true}).VanillaServer==false,'A saved unchecked preference overrides the checked default')
local native='/Script/Test.Class:Factory'
objects['/Script/Test.Class']=object({GetCDO=function(self) return self end})
objects[native]=object({GetFunctionFlags=function() return 0x400 end})
local out=param('before')
R.pre(native,function(self,input,output) assert(input=='input');output:set('pre') end)
R.post(native,function(self,result,input,output) assert(result=='result' and input=='input');output:set('post') end)
callbacks[native].pre(param(object()),param('input'),out);assert(out:get()=='pre')
local rewritten=param('input')
R.pre(native,function(self,input,output)
 assert(self:IsValid() and input==rewritten and output==out)
 input:set('private-set.png')
end,true)
callbacks[native].pre(param(object()),rewritten,out)
assert(rewritten:get()=='private-set.png','Raw PRE must rewrite the engine input, alongside ordinary value callbacks')
assert(callbacks[native].post(param(object()),param('result'),param('input'),out)==nil);assert(out:get()=='post')
R.post(native,function() return false end)
R.post(native,function() end)
assert(callbacks[native].post(param(object()),param('result'),param('input'),out)==false)
local late='/Game/Test.Late_C:Construct'
R.pre(late,function(self,flag) assert(flag==true);return true end)
assert(not callbacks[late])
objects['/Game/Test.Late_C']=object({GetCDO=function(self) return self end})
objects[late]=object({GetFunctionFlags=function() return 0 end})
assert(notifies['/Game/Test.Late_C']()==true);assert(intercepts[late](object(),true)==true)
local function check_intercept_error(path)
 local fail,hits=true,0
 R.pre(path,function()
  hits=hits+1
  if fail then error('wardrobe click reproduction') end
  return true
 end)
 local callback=assert(intercepts[path])
 assert(callback(object(),true)==false,'A failed PRE callback leaves the native function running')
 fail=false
 assert(intercepts[path]==callback and callback(object(),true)==true and hits==2,
  'The same intercept must keep handling clicks after an error')
end
-- PRE installed with the function, and PRE added after a POST already installed it.
objects['/Game/Test.Click_C']=object({GetCDO=function(self) return self end})
for _,name in ipairs({'Early','Late'}) do
 local path='/Game/Test.Click_C:'..name
 objects[path]=object({GetFunctionFlags=function() return 0 end})
 if name=='Late' then R.post(path,function() end) end
 check_intercept_error(path)
end
local world=object()
callbacks.LoadMapPost(nil,param(world))
local fired=0
R.after(1,function() fired=fired+1 end)
R.after(1,function() fired=fired+10 end,true)
local stop=R.next_frame(function() fired=fired+100 end);stop()
callbacks.LoadMapPre()
for _,fn in ipairs(queue) do fn() end
assert(fired==10,'Travel must suppress cancelled, already-published work')
local hits=0
-- R.owner: the mod whose file made the call, past the runtime and the APIs that ask for their caller.
R.manifests={Alpha={name='Alpha mod'},UIKit={name='UIKit'}}
local api=load("return function(R) return R.owner('UIKit') end",'@G:/Mods/WitchItRuntime/Scripts/../../UIKit/api.lua')()
local alpha=load("return function(R,api) return R.owner(),api(R),R.mod_name(R.owner()) end",'@G:/Mods/WitchItRuntime/Scripts/../../Alpha/package.lua')()
local own,asked,name=alpha(R,api)
assert(own=='Alpha' and asked=='Alpha' and name=='Alpha mod','a call names its mod; an API names the mod that called it')
assert(not pcall(R.owner),'a call no mod made has no owner')
R.manifests.tests={name='Test'} -- (this file's folder stands for a mod)
R.key('test.action','Ctrl+K',function() hits=hits+1 end,{label='Test action'})
local controller=object({IsA=function() return true end,IsLocalPlayerController=function() return true end,GetWorld=function() return world end})
callbacks.BeginPlayPost(param(controller))
callbacks.LoadMapPost(nil,param(object({address=world:GetAddress()})))
callbacks.input(75,2);assert(hits==1,'LoadMap completion through a fresh world wrapper must retain its local controller')
local captured
local stop_capture=R.capture_hotkey(function(code,mask) captured={code,mask} end)
callbacks.input(75,2);assert(hits==1 and captured[1]==75 and captured[2]==2)
stop_capture()
local keys=R.settings('WitchItRuntime',{})
assert(R.set_hotkey('test.action','Disabled'));callbacks.input(75,2);assert(hits==1)
assert(R.set_hotkey('test.action',R.hotkeys()[1].default));callbacks.input(75,2);assert(hits==2)
assert(not pcall(R.key,'test.bad','F5',function() end,{label='x'}),'a mod shortcut cannot take F5')
-- (the game's own F5 action, made rebindable, keeps its key; a mod shortcut still cannot be moved to it)
assert(pcall(R.key,'test.f5','F5',function() end,{label='Editor: F5',game=true}),'the game\'s F5 action has F5')
assert(R.set_hotkey('test.f5','F6') and R.set_hotkey('test.f5','F5'),'and can go back to it')
assert(not R.set_hotkey('test.action','F5'),'a mod shortcut is refused F5')
R.native.source_actors({{source='s',class='c',role='r',transform={1,2,3,4,5,6,7,8,9},components={{name='Mesh'}},state='v'}},world,{v={}})
local info
R.on('layout_loaded',function(v) info=v end)
callbacks.LoadMapPost(nil,param(world))
loaded('return','actual.pl',false,'Map','World')
assert(info==nil,'A failed read is no loaded layout')
loaded('return','actual.pl',true,'Map','World')
assert(info.world==world and info.layout_id=='actual.pl' and info.is_playtest==nil,'Creative and playtest are the session\'s to say, not the event\'s')
-- Travel EndPlay reaches ordinary actors before GameState, without LoadMap on
-- seamless travel. Session/UI callbacks can run between those actor callbacks.
local widget_class='/Game/Test.Widget_C'
objects[widget_class]=object({IsChildOf=function(_,class) return class==objects['/Script/UMG.UserWidget'] end})
objects['/Script/Engine.Actor']=object()
objects['/Script/UMG.UserWidget']=object()
objects['/Script/UMG.Default__WidgetBlueprintLibrary']=object({GetAllWidgetsOfClass=function(_,w)
 assert(not w.expired,'Widget queries must never receive the departed world')
end})
world.GetAddress=function(self) assert(not self.expired,'Native object expired');return self.address end
local ended=0
R.on('world_end',function() ended=ended+1;assert(#R.find_all(widget_class)==0) end)
local ordinary=object({IsA=function() return false end,GetWorld=function() return world end})
callbacks.EndPlayPre(param(ordinary),param(0))
assert(ended==0,'Destroying an actor does not end its world')
local travelled=0
R.next_frame(function() travelled=travelled+1 end)
R.after(1,function() travelled=travelled+10 end,true)
callbacks.EndPlayPre(param(ordinary),param(1)) -- LevelTransition
assert(ended==1,'The first transition EndPlay must release the world, before GameState')
world.expired=true
assert(#R.find_all(widget_class)==0) -- Online session update during teardown.
callbacks.input(75,2);assert(hits==2,'The departed local controller must also be released')
local game_state=object({IsA=function() return true end,GetWorld=function() return world end})
callbacks.EndPlayPre(param(game_state),param(1))
assert(ended==1,'Later transition EndPlay must not repeat world_end')
for _,fn in ipairs(queue) do fn() end
assert(travelled==10,'Seamless travel cancels world work and retains explicit surviving work')
local next_world=object()
callbacks.InitGameStatePost(param(object({GetWorld=function() return next_world end})))
R.find_all(widget_class)
callbacks.LoadMapPre()
assert(ended==2,'LoadMap travel still releases the new world')
callbacks.LoadMapPost(nil,param(next_world))
callbacks.EndPlayPre(param(ordinary),param(4)) -- Quit
assert(ended==3,'Quit releases the world too')
-- UI observations run after the cooked UI body. Even a failing local-player
-- subscriber cannot abort that body; results need no controller observation.
local uiClass='/Game/Blueprints/UserInterface/B_IngameUIManager.B_IngameUIManager_C'
objects[uiClass]=object({GetCDO=function(self) return self end})
for _,method in ipairs({'Initialize','ShowHUD','ShowTeamSelectionObjective','ShowObjectiveResult'}) do
 local path=uiClass..':'..method
 objects[path]=object({GetFunctionFlags=function() return 0 end})
end
notifies[uiClass]()
for _,method in ipairs({'Initialize','ShowHUD','ShowTeamSelectionObjective','ShowObjectiveResult'}) do
 assert(not intercepts[uiClass..':'..method],'UI observation must not intercept native UI execution')
end
assert(not callbacks[uiClass..':ShowObjectiveResult'])
local uiWorld=object()
local uiPC=object({IsA=function() return true end,IsLocalPlayerController=function() return true end,GetWorld=function() return uiWorld end})
objects['/Script/Engine.Default__GameplayStatics'].GetPlayerController=function() return uiPC end
local nativeRan=false
R.on('local_player',function() assert(nativeRan);error('session subscriber reproduction') end)
-- This models the native body followed by its registered script POST callback.
nativeRan=true
local after=false
R.on('local_player',function() after=true end)
callbacks[uiClass..':ShowTeamSelectionObjective'].pre(param(object()))
assert(nativeRan and after,'A failed callback leaves the callbacks after it running')
assert(#announced==1 and announced[1]:find('wardrobe click reproduction',1,true),'Only the first failure of a run is announced')
assert(R.call(function(a) return a end,7)==7,'A callback keeps its result')
local F=dofile(scripts..'files.lua')()
local path='/tmp/wir-rewrite-engine-order/atomic.json'
F.write(path,'first');F.write(path,'second');assert(F.read(path)=='second')
local found=false;for _,name in ipairs(F.list('/tmp/wir-rewrite-engine-order')) do if name=='atomic.json' then found=true end end;assert(found)
assert(#F.list('/tmp/wir-rewrite-engine-order/missing')==0)
os.remove(path);os.execute("rm -rf '/tmp/wir-rewrite-engine-order'")
