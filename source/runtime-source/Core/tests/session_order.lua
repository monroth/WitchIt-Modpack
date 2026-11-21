local J=dofile('candidate/runtime-source/WitchItRuntime/Scripts/json.lua')
local hooks,events,watch,requests,settings,timers={},{},{},{},{},{}
local R={package_ids={'Core','UIKit','FillAPotPlus','MatchRulesPlusPlus','BaseWorldPlus','PrivateCosmetics'},log=function() end,json=J,base64=dofile('candidate/runtime-source/WitchItRuntime/Scripts/base64.lua')}
local V=dofile('candidate/runtime-source/WitchItRuntime/Scripts/values.lua');R.values,R.text=V.values,V.text
function R.settings(pkg,defaults) if not settings[pkg] then settings[pkg]=defaults end;return settings[pkg] end
function R.valid(o) return o and o.valid~=false and o or nil end
function R.pre(path,fn) hooks['pre'..path]=fn end
function R.observe(path,fn) hooks['pre'..path]=fn end
function R.post(path,fn) hooks['post'..path]=fn end
function R.on(event,fn) events[event]=fn end
function R.after(ms,fn) local t={ms=ms,fn=fn};timers[#timers+1]=t;return function() t.cancelled=true end end
R.manifests={Core={name='Core',sync=true},UIKit={name='UIKit'},FillAPotPlus={name='Fill a Pot+',sync=true},
 MatchRulesPlusPlus={name='Match Rules ++',sync=true},BaseWorldPlus={name='World edits',sync=true},
 PrivateCosmetics={name='Private Cosmetics',private=true}}
function R.owner() return R.test_owner end
function R.mod_name(id) return R.manifests[id] and R.manifests[id].name or id end
function FName(s) return s end
function FText(s) return s end
function WitchItNativeUpdater() end
function WitchItNativeUpdateFile() return true end
local mode='B_HideAndSeekGameMode_C'
local options={GameMode={GetFName=function() return {ToString=function() return mode end} end}}
local gi={NextMatchOptions=options,UsedMatchOptions=options}
local kicks=0
function StaticFindObject(path)
 if path:find('GameplayStatics',1,true) then return {GetGameInstance=function() return gi end} end
 return {KickPlayer=function() kicks=kicks+1 end}
end
local policy
-- The hosted maps need Fill a Pot+ and Editor tweaks data.
local C={net={},level=function() return 'test' end,catalog={session_needs=function() return {['monroth.fap']=true,['monroth.bwp']=true} end},
 map={chosen=function() end,spec=function(id) return ({['monroth.fap']={package='FillAPotPlus'},['monroth.bwp']={package='BaseWorldPlus'}})[id] end}}
dofile('candidate/runtime-source/Core/game.lua')(R,C)
-- Plus is a choice made on a MatchOptions object, never a saved preference.
function C.net.publish(topic,value) end
function C.net.watch(topic,fn) watch[topic]=fn end
function C.net.on_request(topic,fn) requests[topic]=fn end
local sent=0
function C.net.request(topic,value) assert(topic=='core.inventory' and value.core);sent=sent+1 end
function C.session() return {role='host',gm={},gs={SendChatMessageMulticast=function() end}} end
local replays=0
local T={request=function(_,topic,value) C.net.request(topic,value) end,add=function() end,remove=function() end,replay=function() replays=replays+1 end,send=function() end}
local M;M=dofile('candidate/runtime-source/Core/mods.lua')(R,C,T,function() policy=M.vanilla_session() end)
-- What the mods say about themselves (their packages register these).
R.test_owner='MatchRulesPlusPlus';M.require(function() return true end)
-- (Fill a Pot+ is Fill a Pot on a server that is not vanilla)
R.test_owner='FillAPotPlus';M.require(function(o) return o.GameMode:GetFName():ToString()=='B_ObjectiveGameMode_C' and not M.vanilla(o) end)
R.test_owner='BaseWorldPlus';M.require(function(o) return o.GameMode:GetFName():ToString()=='B_CreativeGameMode_C' end)
local function map()
 local m={values={SessionName={Data={AsString='Server'},ID=5}},writes=0}
 function m:Contains(k) return self.values[k]~=nil end
 function m:Find(k) return {get=function() return self.values[k] end} end
 function m:Add(k,v) self.writes=self.writes+1;self.values[k]=v end
 function m:Remove(k) self.values[k]=nil end
 function m:ForEach(fn) for k,v in pairs(self.values) do fn({get=function() return {ToString=function() return k end} end},{get=function() return v end}) end end
 return m
end
local SESSION='/Script/OnlineSubsystemBlueprints.'
local create=hooks['pre'..SESSION..'OnlineSessionSubsystemCreateSession:CreateSession']
local update=hooks['pre'..SESSION..'OnlineSessionSubsystemUpdateSession:UpdateSession']
local entries=map();local output={Settings=entries}
create({},gi,{},'name',output)
assert(policy and entries.writes==0,'Checked vanilla leaves advertisements untouched')
settings.Core.VanillaServer=false;assert(policy)
update({},gi,'name',output);assert(policy and entries.writes==0,'Checkbox changes wait for rehosting')
create({},gi,{},'name',output)
local fixed=M.identity
for _,id in ipairs({'fillapotplus','matchrulesplusplus','baseworldplus'}) do assert(fixed.required[id]==fixed.packages[id]) end
assert(not policy and not fixed.required.core and not fixed.required.PrivateCosmetics)
settings.Core.VanillaServer=true;gi.IsCurrentlyInMatch=true;gi.UsedMatchOptions={};gi.NextMatchOptions.CustomMapSelected=true
M.status();update({},gi,'name',output);update({},gi,'name',output)
assert(M.identity==fixed and not policy and entries.values.SessionName.Data.AsString=='[M] Server')
assert(J.encode(fixed)==entries.values.WitchItModpack.Data.AsString,'Updates retain the exact session advert')
gi.UsedMatchOptions=options
settings.Core.VanillaServer=true
mode='B_ObjectiveGameMode_C';create({},gi,{},'name',output)
assert(policy and not entries.values.WitchItModpack and entries.values.SessionName.Data.AsString=='Server','Fill a Pot on a vanilla server is the game\'s own')
settings.Core.VanillaServer=false
mode='B_ObjectiveGameMode_C';create({},gi,{},'name',output)
assert(not policy and M.identity.required.fillapotplus,'Fill a Pot on a server that is not vanilla is Fill a Pot+')
mode='B_HideAndSeekGameMode_C';events.world_end();update({},gi,'name',output)
assert(not policy and M.identity.required.fillapotplus,'Travel and mode changes keep the session policy')
local pc={PlayerState={},NetConnection={CurrentNetSpeed=20000,Driver={MaxClientRate=100000,MaxInternetClientRate=100000}}}
function pc:GetAddress() return 7 end
function pc:IsLocalPlayerController() return false end
function pc:GetWorld() return {IsValid=function() return true end,GetFullName=function() return 'World /Game/Maps/Test.Test' end} end
function pc:HasAuthority() return true end
function pc:IsA(class)
 assert(class=='/Game/Blueprints/Gamemodes/CreativeMode/B_CreativePlayerController.B_CreativePlayerController_C')
 return false
end
function pc:ClientSetWasKicked() end
function pc.PlayerState:GetOwner() return pc end
function pc.PlayerState:GetPlayerName() return 'Guest' end
function pc.NetConnection:GetAddress() return 9 end
events.player_joined(pc.PlayerState)
assert(replays==0,'Login does not subscribe a controller to world snapshots')
hooks['post/Script/Engine.PlayerController:ServerNotifyLoadedWorld'](pc,'/Game/Maps/Test')
assert(replays==0,'Final-world load does not restore world snapshots')
requests['core.inventory'](pc.PlayerState,M.identity.packages)
assert(pc.NetConnection.CurrentNetSpeed==100000)
assert(replays==1,'An explicit inventory supplies the current world snapshot')
assert(kicks==0 and #timers==0,'The same mods: no kick')
gi.UsedMatchOptions={};update({},gi,'name',output)
assert(not policy and pc.NetConnection.CurrentNetSpeed==100000 and M.identity.required.baseworldplus,'Removing current content keeps fixed requirements and compatibility')
events.player_left(pc.PlayerState)
-- Vanilla login and inventory can record peer facts, but must never subscribe
-- gameplay snapshots, change the connection rate, schedule a kick or kick.
settings.Core.VanillaServer=true;gi.UsedMatchOptions=options
local replayCount,timerCount=replays,#timers
for _,nativeMode in ipairs({'B_ObjectiveGameMode_C','B_HideAndSeekGameMode_C'}) do
 mode=nativeMode;create({},gi,{},'name',{Settings=map()})
 assert(policy,'Ordinary native modes remain vanilla')
 pc.NetConnection.CurrentNetSpeed=20000
 events.player_joined(pc.PlayerState)
 hooks['post/Script/Engine.PlayerController:ServerNotifyLoadedWorld'](pc,'/Game/Maps/Test')
 requests['core.inventory'](pc.PlayerState,{core='0.0.1'})
 assert(replays==replayCount and #timers==timerCount and kicks==0 and pc.NetConnection.CurrentNetSpeed==20000,
  'Vanilla login/inventory must not apply modded session policies')
 events.player_left(pc.PlayerState)
end
mode='B_HideAndSeekGameMode_C'
local join=hooks['pre'..SESSION..'OnlineSessionSubsystemJoinSession:JoinSession']
entries.values.WitchItModpack={Data={AsString=J.encode({protocol=1})}}
join({},gi,{},'name',{Session={SessionSettings={Settings=entries}}})
assert(policy and M.message:find('Core is incompatible with yours',1,true))

watch['core.identity'](M.identity)
assert(sent==0,'Identity replies do not cause another inventory request')
local unlockOnly=dofile('candidate/runtime-source/Core/mods.lua')(R,C,T,function() end)
assert(not J.encode(unlockOnly.identity):find('PrivateCosmetics',1,true),'Private packages are never advertised')

-- Creative's dialog assigns CreativeMatchOptions to UsedMatchOptions before HostGame.
-- NextMatchOptions can still name an unrelated Custom Match mode.
local creative={GameMode={GetFName=function() return {ToString=function() return 'B_CreativeGameMode_C' end} end}}
assert(settings.Core.CreativeVanillaServer==false and settings.Core.VanillaServer==true,'Separate fresh defaults')
mode='B_ObjectiveGameMode_C'
gi.CreativeMatchOptions=creative;gi.UsedMatchOptions=gi.CreativeMatchOptions
local creative_out={Settings=map()}
create({},gi,{},'name',creative_out)
assert(not policy,'Creative uses its unchecked default despite stale Custom Match options')
for _,id in ipairs({'fillapotplus','matchrulesplusplus','baseworldplus'}) do assert(M.identity.required[id]==M.identity.packages[id]) end
assert(creative_out.Settings.values.WitchItModpack and creative_out.Settings.values.SessionName.Data.AsString=='[M] Server')
settings.Core.VanillaServer=false
settings.Core.CreativeVanillaServer=true
local creative_fixed=M.identity
gi.UsedMatchOptions={}
update({},gi,'name',creative_out)
assert(not policy and M.identity==creative_fixed,'Creative preference changes and travel wait for rehosting')
gi.UsedMatchOptions=creative
create({},gi,{},'name',creative_out)
assert(policy and next(M.identity.required)==nil and not creative_out.Settings.values.WitchItModpack,
 'Checked Creative stays vanilla even with stale Plus selection and unchecked Custom Match')
assert(creative_out.Settings.values.SessionName.Data.AsString=='Server')
settings.Core.VanillaServer=true
gi.NextMatchOptions=creative;gi.UsedMatchOptions=options;mode='B_HideAndSeekGameMode_C'
create({},gi,{},'name',creative_out)
assert(policy,'Custom Match reads UsedMatchOptions despite stale Creative NextMatchOptions')
settings.Core.VanillaServer=false
create({},gi,{},'name',creative_out)
assert(not policy,'Unchecked Custom Match is independent of checked Creative')
gi.NextMatchOptions=options;gi.UsedMatchOptions=options

-- Exercise actual inventory selection without changing installed files.
local open=io.open
local load=dofile
local excluded,disabled={},{}
io.open=function(path,...) if excluded[path:match('/([^/]+)/manifest.lua$')] then return nil end;return open(path,...) end
dofile=function(path)
 local value=load(path);if disabled[path:match('/([^/]+)/manifest.lua$')] then value.enabled=false end;return value
end
settings.Core.VanillaServer=false
for _,id in ipairs({'FillAPotPlus','MatchRulesPlusPlus','BaseWorldPlus'}) do disabled[id]=true end
for _,case in ipairs({{}, {BaseWorldPlus=true}, {FillAPotPlus=true,MatchRulesPlusPlus=true,BaseWorldPlus=true}}) do
 excluded=case
 local bare;bare=load('candidate/runtime-source/Core/mods.lua')(R,C,T,function() policy=bare.vanilla_session() end)
 for _,selected in ipairs({options,creative}) do
  gi.UsedMatchOptions=selected;settings.Core.CreativeVanillaServer=false
  local out={Settings=map()};hooks['pre'..SESSION..'OnlineSessionSubsystemCreateSession:CreateSession']({},gi,{},'name',out)
  assert(policy and next(bare.identity.required)==nil and out.Settings.writes==0,'Disabled or absent gameplay packages leave unchecked hosting vanilla')
 end
end
gi.UsedMatchOptions=options
excluded={BaseWorldPlus=true};disabled={FillAPotPlus=true}
local partial;partial=load('candidate/runtime-source/Core/mods.lua')(R,C,T,function() policy=partial.vanilla_session() end)
-- Only the loaded mods say when they are needed: here Match Rules ++.
R.test_owner='MatchRulesPlusPlus';partial.require(function() return true end)
local out={Settings=map()};hooks['pre'..SESSION..'OnlineSessionSubsystemCreateSession:CreateSession']({},gi,{},'name',out)
assert(not policy and J.encode(partial.identity.required)==J.encode({matchrulesplusplus='0.6.0'}),'Only installed and enabled public gameplay packages are required')
io.open=open;dofile=load
print('Core fixed session policy, advertisements, inventory and compatibility checks passed')
