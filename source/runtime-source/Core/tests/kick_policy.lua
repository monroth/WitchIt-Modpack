-- Actual Core session + transport callbacks; reliable RPCs can precede local BeginPlay.
local J=dofile('candidate/runtime-source/WitchItRuntime/Scripts/json.lua')
local make=dofile('candidate/runtime-source/Core/package.lua')
local PC='/Game/Blueprints/Player/B_PlayerController.B_PlayerController_C:'
local SHORT='/Script/Engine.PlayerController:ServerShortTimeout'
local LOADED='/Script/Engine.PlayerController:ServerNotifyLoadedWorld'
local POSSESSED='/Script/Engine.PlayerController:ServerAcknowledgePossession'
local CREATIVE='/Game/Blueprints/Gamemodes/CreativeMode/B_CreativePlayerController.B_CreativePlayerController_C'
local MENU='/Game/UserInterface/WB_MainMenu.WB_MainMenu_C:Construct'
local CREATE='/Script/OnlineSubsystemBlueprints.OnlineSessionSubsystemCreateSession:CreateSession'
local now,timers,kicks,notices=0,{},{},{}
function FName(s) return s end
function FText(s) return s end
function WitchItNativeUpdater() end
function WitchItNativeUpdateFile() return true end
local gm={}
local gs={GetClass=function() return {GetFName=function() return {ToString=function() return 'B_GameState_C' end} end} end}
function gs:SendGameMessageMulticast(text,target,kind)
 assert(target=='' and kind==12,'Use the native nameless announcement, without player chat filtering')
 notices[#notices+1]={text=text,at=now}
end
function gs:SendChatMessageMulticast(text,ps,channel,recipients)
 assert(channel==0 and type(recipients)=='table')
 self.mismatchChat={text=text,ps=ps}
end
local gp={}
function gp:GetGameInstance(context) return context.gi or context end
function gp:GetGameMode(context) return context.gm end
function gp:GetGameState() return gs end
function StaticFindObject(path)
 if path:find('GameplayStatics',1,true) then return gp end
 if path:find('KismetSystemLibrary',1,true) then return {GetProjectSavedDirectory=function() return '/unused' end} end
 assert(path=='/Script/PropWitchHuntModule.Default__ProjectVersionBlueprint')
 return {GetProjectVersion=function() return '1.8.0' end,KickPlayer=function(_,mode,pc,reason)
  assert(mode==gm);kicks[#kicks+1]={pc=pc,reason=reason};pc.kicked=true;return true
 end}
end
local function advance(ms)
 now=now+ms
 for _,t in ipairs(timers) do
  if not t.cancelled and not t.fired and t.at<=now then t.fired=true;t.fn() end
 end
end
local function runtime()
 local r={package_ids={'Core','UIKit','FillAPotPlus','MatchRulesPlusPlus','BaseWorldPlus','PrivateCosmetics'},prepare_directory=function() end,json=J,base64=dofile('candidate/runtime-source/WitchItRuntime/Scripts/base64.lua'),native={on_save=function() end,on_update=function() end},hooks={},events={},config={Core={VanillaServer=false,KickAfterSeconds=20}}}
 local function register(key,fn) r.hooks[key]=r.hooks[key] or {};table.insert(r.hooks[key],fn) end
 function r.pre(path,fn) register('pre'..path,fn) end
 function r.observe(path,fn) register('pre'..path,fn) end
 function r.post(path,fn) register('post'..path,fn) end
 function r.on(event,fn) r.events[event]=r.events[event] or {};table.insert(r.events[event],fn) end
 function r.emit(event,...) for _,fn in ipairs(r.events[event] or {}) do fn(...) end end
 function r.call(phase,path,...) for _,fn in ipairs(r.hooks[phase..path] or {}) do fn(...) end end
 function r.valid(x) return x and x.valid~=false and x or nil end
 function r.settings(id,defaults)
  r.config[id]=r.config[id] or {}
  for k,v in pairs(defaults) do if r.config[id][k]==nil then r.config[id][k]=v end end
  return r.config[id]
 end
 function r.after(ms,fn)
  local t={at=now+ms,fn=fn};timers[#timers+1]=t
  return function() t.cancelled=true end
 end
 function r.log() end
 dofile('candidate/runtime-source/Core/tests/lib/mods.lua')(r)
 return r
end
local function instance(host)
 local r=runtime()
 local gi={IsCurrentlyInMatch=true,NextMatchOptions={GetAddress=function() return 77 end,GameMode={GetFName=function() return {ToString=function() return 'B_HideAndSeekGameMode_C' end} end}}}
 gi.UsedMatchOptions=gi.NextMatchOptions
 local world={gi=gi,gm=host and gm or nil,GetFullName=function() return 'World /Game/Maps/Test.Test' end}
 function world:GetOuter() return {GetFName=function() return {ToString=function() return '/Game/Maps/Test' end} end} end
 local c=make(r)
 -- Match Rules ++ says a modded session needs it (its package registers this).
 r.test_owner='MatchRulesPlusPlus';c.mods.require(function() return true end);r.test_owner='Core'
 r.emit('world_begin',world)
 return r,c,world,gi
end
local hr,hc,hw,hgi=instance(true)
for _,method in ipairs({'Initialize','ShowHUD','ShowTeamSelectionObjective','ShowObjectiveResult'}) do
 local path='/Game/Blueprints/UserInterface/B_IngameUIManager.B_IngameUIManager_C:'..method
 assert(not hr.hooks['pre'..path], 'Session subscribers must not precede native UI functions')
 if method=='ShowObjectiveResult' then assert(not hr.hooks['post'..path]) end
end
-- Session facts can settle after BeginPlay without changing the controller.
-- Keep the historical guest UI refresh, after the cooked function completes.
local uiPC={GetWorld=function() return hw end}
function gp:GetPlayerController() return uiPC end
-- (the runtime follows the local player; Core's session takes it from there)
function hr.local_player() return hw,uiPC end
hgi.IsCurrentlyInMatch=false;hr.emit('world_begin',hw)
assert(hc.session().role=='offline')
hgi.IsCurrentlyInMatch=true
hr.call('post','/Game/Blueprints/UserInterface/B_IngameUIManager.B_IngameUIManager_C:ShowHUD',{})
assert(hc.session().role=='host' and hc.session().pc==uiPC)
local entries,advert={},{}
function entries:Contains() return false end
function entries:Add(k,v) advert[k]=v end
hr.call('pre',CREATE,{},hgi,{},'Game',{Settings=entries})
-- (what the host advertises: its identity)
local function identity() return J.decode(advert.WitchItModpack.Data.AsString) end
assert(not identity().vanilla)
local function connection(address,client)
 local pc={PlayerState={},gm=gm,gi=hgi,NetConnection={CurrentNetSpeed=20000,Driver={MaxClientRate=100000,MaxInternetClientRate=100000}},queued={}}
 function pc.NetConnection:IsValid() return true end
 function pc.NetConnection:GetAddress() return address end
 function pc:GetAddress() return address end
 function pc:HasAuthority() return true end
 function pc:IsA(class) assert(class==CREATIVE);return self.creative==true end
 function pc:IsLocalPlayerController() return false end
 function pc:GetWorld() return {IsValid=function() return true end,GetFullName=function() return 'World /Game/Maps/Test.Test' end} end
 function pc.PlayerState:GetOwner() return pc end
 function pc.PlayerState:GetPlayerName() return 'Guest '..address end
 function pc:ClientSetWasKicked(reason) assert(reason=='None');self.kickNotice=true end
 function pc:ClientSetRevisionNumber(text)
  if client then
   if self.delay then self.queued[#self.queued+1]=text else client.r.call('post',PC..'ClientSetRevisionNumber',client.pc,text) end
  end
 end
 function pc:flush()
  self.delay=false;local pending=self.queued;self.queued={}
  for _,text in ipairs(pending) do client.r.call('post',PC..'ClientSetRevisionNumber',client.pc,text) end
 end
 return pc
end
local function guest(address)
 local r,c,w,gi=instance(false)
 local pc={gi=gi}
 function pc:GetAddress() return address+100 end
 function pc:HasAuthority() return false end
 function pc:IsLocalPlayerController() return true end
 function pc:GetWorld() return w end
 local g={r=r,c=c,pc=pc}
 local remote=connection(address,g);g.remote=remote
 function pc:ExecuteConsoleCommandFromClient(text) hr.call('post',PC..'ExecuteConsoleCommandFromClient',remote,text) end
 return g
end
local function joined(pc) hr.emit('player_joined',pc.PlayerState) end
-- the engine reports each loaded world by package name, the transition map too
local function loaded(pc,final) hr.call('post',LOADED,pc,final and '/Game/Maps/Test' or '/Game/Maps/Transition') end
local function ready(pc) hr.call('post',SHORT,pc) end
local function left(pc) hr.emit('player_left',pc.PlayerState) end
-- A player without mods never sees a modded server (it is hidden from vanilla searches), so a
-- guest without an answer is never warned or kicked (user 11-15: the notice and kick are outdated).
local vanilla=connection(1)
joined(vanilla);loaded(vanilla,false);hr.call('post',POSSESSED,vanilla,{});ready(vanilla);loaded(vanilla,true);advance(60000)
assert(not vanilla.kicked and #timers==0 and #notices==0 and #kicks==0)
-- The host asks a guest on login (its identity); the guest answers with its list; a fitting
-- list subscribes the guest and replays the current values.
local g=guest(2)
local advertEntries={}
function advertEntries:Contains(key) return key=='WitchItModpack' end
function advertEntries:Find() return {get=function() return {Data={AsString=advert.WitchItModpack.Data.AsString}} end} end
g.r.call('pre','/Script/OnlineSubsystemBlueprints.OnlineSessionSubsystemJoinSession:JoinSession',{},g.pc.gi,{},'Game',{Session={SessionSettings={Settings=advertEntries}}})
local received={}
g.c.net.watch('world.test',function(value) received[#received+1]=value end)
hc.net.publish('world.test','first')
joined(g.remote)
assert(not g.remote.kicked and #received==1 and received[1]=='first','login asks, the answer subscribes and replays')
ready(g.remote);advance(20000);assert(not g.remote.kicked and #kicks==0 and #notices==0)
-- A travel (halftime: the transition map too) clears world channels; the host asks again when the
-- guest reports the host's world, and the answer restores exactly one current snapshot.
hr.emit('world_end');hr.emit('world_end');hr.emit('world_begin',hw)
g.r.emit('world_end');g.r.emit('world_begin',g.pc:GetWorld())
assert(g.c.session().pc==nil)
hc.net.publish('world.test','second')
loaded(g.remote,false);assert(#received==1,'the transition map is not the host world')
loaded(g.remote,true)
assert(not g.remote.kicked and #received==2 and received[2]=='second' and #notices==0)
hc.net.publish('world.test','update')
assert(#received==3 and received[3]=='update','The controller remains subscribed to subsequent publications')
-- Received incompatibility is refused immediately, with older-side and missing-package details.
g.r.emit('local_player',g.pc)
local wrong={};for id,v in pairs(identity().packages) do wrong[id]=v end
wrong.fillapotplus='0.0.1';wrong.matchrulesplusplus='99.0.0';wrong.baseworldplus=nil
g.c.net.request('core.inventory',wrong)
assert(#kicks==1 and g.remote.kicked and #timers==0)
local reason=kicks[1].reason
-- A Hide and Seek host on a stock map requires the rules package only, not Fill a Pot+ or Editor tweaks.
assert(reason:find('Host must update Match Rules +',1,true) and not reason:find('Fill a Pot+',1,true) and not reason:find('Editor tweaks',1,true))
assert(g.c.mods.refusal==reason,'Old owning-client refusal survives the disconnect')
assert(gs.mismatchChat.ps==g.remote.PlayerState and gs.mismatchChat.text:find(reason,1,true),'Modded mismatch chat retains its existing behavior')
g.r.call('post',MENU);assert(g.c.mods.refusal==reason,'Menu reset retains the refusal for UIKit')
-- A guest that joined without seeing the session advert (invite, rejoin) answers the same question.
local silent=guest(13);joined(silent.remote);ready(silent.remote)
advance(30000);assert(not silent.remote.kicked)
-- Creative: nothing is announced or scheduled for any guest, possessed or not.
hgi.UsedMatchOptions={GetAddress=function() return 78 end,GameMode={GetFName=function() return {ToString=function() return 'B_CreativeGameMode_C' end} end}}
hr.call('pre',CREATE,{},hgi,{},'Game',{Settings=entries})
local creative=connection(11);creative.creative=true;joined(creative)
loaded(creative,true);ready(creative);hr.call('post',POSSESSED,creative,nil);hr.call('post',POSSESSED,creative,{});advance(30000)
assert(#timers==0 and #notices==0 and not creative.kicked)
local creativeKnown=guest(12);creativeKnown.remote.creative=true;joined(creativeKnown.remote)
creativeKnown.r.call('pre','/Script/OnlineSubsystemBlueprints.OnlineSessionSubsystemJoinSession:JoinSession',
 {},creativeKnown.pc.gi,{},'Game',{Session={SessionSettings={Settings=advertEntries}}})
creativeKnown.r.emit('local_player',creativeKnown.pc)
hr.call('post',POSSESSED,creativeKnown.remote,{})
assert(not creativeKnown.remote.kicked and #notices==0)
-- (user) A modded server is listed only where Core runs: it says another game version (the game's
-- and a mark), so vanilla searches and lists leave it out; back to the game's own for a vanilla server.
local map={VersionNumber={Data={Type=6,AsString='1.8.0'},AdvertisementType=3,ID=7},GameMode={Data={Type=6,AsString='Fill a Pot'},AdvertisementType=3,ID=8}}
-- (user 10-07) a mod's mode is listed under the mod's name
hr.test_owner='FillAPotPlus';hc.map.module('fapp',{mode=true,selected=function() return true end});hr.test_owner='Core'
local listed={}
function listed:Contains(k) return map[k]~=nil end
function listed:Find(k) return {get=function() return map[k] end} end
function listed:Add(k,v) map[k]=v end
function listed:Remove(k) map[k]=nil end
hr.config.Core.VanillaServer=false;hr.config.Core.CreativeVanillaServer=false;hr.call('pre',CREATE,{},hgi,{},'Game',{Settings=listed})
assert(not J.decode(map.WitchItModpack.Data.AsString).vanilla and map.VersionNumber.Data.AsString=='1.8.0+WitchItPlus' and map.VersionNumber.ID==7 and map.WitchItModpack,'a modded server is left out of vanilla searches')
assert(map.PS5Exclusive.Data.AsBool==true and map.XBLExclusive.Data.AsBool==true,'(user) and the vanilla game does not join it, also through a friend')
assert(map.GameMode.Data.AsString==hr.mod_name('FillAPotPlus') and map.GameMode.ID==8,'the mod\'s mode under its name')
hr.config.Core.VanillaServer=true;hr.config.Core.CreativeVanillaServer=true;hr.call('pre',CREATE,{},hgi,{},'Game',{Settings=listed})
assert(map.VersionNumber.Data.AsString=='1.8.0' and map.WitchItModpack==nil and map.PS5Exclusive.Data.AsBool==false,'a vanilla server is listed as before')
local params={VersionNumber=true,PS5Exclusive=true,XBLExclusive=true,IsCustom=true}
local search={SearchParams={Remove=function(_,k) params[k]=nil end}}
hr.call('pre','/Script/OnlineSubsystemBlueprints.OnlineSessionSubsystemFindSessions:FindSessions',{},{},{},search)
assert(params.VersionNumber==nil and params.PS5Exclusive==nil and params.XBLExclusive==nil and params.IsCustom,'Core searches find modded servers too')
-- The list: a modded server's version counts as the game's own (native frame of the observed call).
local VERSION='CurrentServer.Session.SessionSettings.Settings[VersionNumber].Data.AsString'
local frame={[VERSION]='1.8.0+WitchItPlus'}
local savedNative=hr.native.frame
hr.native.frame=function(_,path,value) if value~=nil then frame[path]=value;return true end return frame[path] end
local FOUND='/Game/UserInterface/Play/WB_ServerListBase.WB_ServerListBase_C:HandleServerFoundEOS'
hr.call('pre',FOUND,{})
assert(frame[VERSION]=='1.8.0','a modded server is listed')
frame[VERSION]='1.7.9';hr.call('pre',FOUND,{})
assert(frame[VERSION]=='1.7.9','a server of another game version stays as the game sees it')
-- Joining a modded server: its console-only marks go first (list, password, invite, friend).
local S='SearchResult.Session.SessionSettings.Settings'
-- (the advert of a host with this game's own mods: this instance's identity)
local same=J.encode((assert(hc.mods.identity,'the host instance hosted')))
frame={[S..'[WitchItModpack]']=true,[S..'[WitchItModpack].Data.AsString']=same,[S..'[PS5Exclusive].Data.AsBool']=true,[S..'[XBLExclusive].Data.AsBool']=true}
local JOIN='/Game/Blueprints/Core/B_GameInstance.B_GameInstance_C:JoinFromServerList'
hr.call('pre',JOIN,hgi)
assert(frame[S..'[PS5Exclusive].Data.AsBool']==false and frame[S..'[XBLExclusive].Data.AsBool']==false,'a modded player joins a modded server')
assert(hc.mods.refusal==nil,'the same mods: joined')
-- A host requiring a mod this game lacks (user 11-20: a Steam join failed without a word): refused here, with the reason.
local other=J.decode(same);other.packages.examplemod='0.1.0';other.required.examplemod='0.1.0';other.require_modpack=true
frame[S..'[WitchItModpack].Data.AsString']=J.encode(other)
local skipped=false
for _,fn in ipairs(hr.hooks['pre'..JOIN]) do if fn(hgi)==true then skipped=true end end
assert(skipped and hc.mods.refusal and hc.mods.refusal:find('Example mod',1,true),'a join with other mods is refused before it starts, and why')
hc.mods.refusal=nil
frame={[S..'[PS5Exclusive].Data.AsBool']=true};hr.call('pre',JOIN,hgi)
assert(frame[S..'[PS5Exclusive].Data.AsBool']==true,'a really console-only server stays as the game sees it')
hr.native.frame=savedNative
print('PASS native gameplay/load announcement/countdown, immediate mismatch/refusal, per-world snapshots, cancellation and host/vanilla/setting scope')
