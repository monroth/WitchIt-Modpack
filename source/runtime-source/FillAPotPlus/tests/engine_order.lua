local dir=debug.getinfo(1,'S').source:match('^@(.+[\\/])')..'../'
local hooks,events,keys,pre={},{},{},{}
local R={native={},packages={}}
function R.post(path,fn) hooks[path]=fn end
function R.pre(path,fn) pre[path]=fn end
function R.on(event,fn)
    events[event]=events[event] or {};table.insert(events[event],fn)
end
function R.key(id,_,fn) keys[id]=fn end
function R.valid(value) return type(value)=='table' end
local rules={uncapped=true,startReady=true,lives=10,respawn=0,totems=1,revive=3}
local witch={Team=0,ObjectiveTeam=1,IsWitchTeam=true,IsReady=true,IsReadyObjectiveTeamSelection=true,ObjectiveMatchPlayerState={}}
local spectator={Team=2,ObjectiveTeam=0,IsReady=false,IsReadyObjectiveTeamSelection=false}
local players={witch,spectator}
local gm={TimerIsCounting=true}
function gm:TimerStop() self.TimerIsCounting=false end
function gm:SendGameMessageMulticast() self.notices=(self.notices or 0)+1 end
local gs={State=2}
function gs:OnRep_MaxLives() end
function gs:SendGameMessageMulticast()gm.notices=(gm.notices or 0)+1 end
local mm={CurrentRound=1}
local session={role='host',gm=gm,gs=gs,mode='monroth.fap',gi={UsedMatchOptions={RequiredPlayersPerTeam=0}}}
local S={INFINITE_LIVES=99,HEARTS=5,R=R,CRITERIA={{key='wins',reason=1},{key='pots',reason=7},{key='lives',reason=4},{key='kills',reason=6},{key='time',reason=2},{key='props',reason=5}},C={state=function() end,side=function(ps) local t=ps and ps.Team;return t==0 and "witch" or t==1 and "hunter" or nil end,session=function() return session end},O='O/',CORE='Core/',U={menu_entry=function()end}}
function S.path(folder,name,method) return folder..name..(method and ':'..method or '') end
dofile(dir..'tests/lib/scope.lua')(S)
function S.rules() return rules end
function S.manager() return mm end
function S.players() return players end
local waiter
function S.waiter(ps) return ps==waiter end
function S.C.replicate(object,key,value) object[key]=value end
function S.allowSkills() end
function S.asset(path) return path end
function FText(text) return text end
local timer={exists=true}
function timer:K2_TimerExists() return self.exists end
function timer:K2_ClearTimer() self.cleared=true end
function timer:K2_SetTimerForNextTick() assert(self.cleared);self.nexttick=true end
function timer:K2_SetTimer(_,_,delay) self.delay=delay end
function StaticFindObject() return timer end
dofile(dir..'gameplay.lua')(S)
local result={}
function result:set(v) self.value=v end
hooks['O/B_ObjectiveGameMode:EnsureInitialize'](gm)
assert(mm.RequiredPlayersPerTeam==1000000 and gs.RequiredPlayersPerTeam==0 and gs.MaxLives==5)
hooks['O/B_ObjectiveGameMode:IsPlayerTeamSelectionBalanced'](gm,nil,result)
assert(result.value==true,'No required players permits an empty team')
hooks['O/B_ObjectiveGameMode:AreAllPlayersReadyWithTeamSelection'](gm,result)
assert(result.value==false,'Unready spectators block team selection')
hooks['Core/B_GameMode:CheckIfAllPlayersAreReady'](gm,result)
assert(result.value==false) -- native readiness runs before POST; spectators still count.
spectator.IsReady=true
hooks['Core/B_GameMode:CheckIfAllPlayersAreReady'](gm,result)
assert(result.value==true)
spectator.WantsToSpectate=true
spectator.IsReadyObjectiveTeamSelection=true
hooks['O/B_ObjectiveGameMode:AreAllPlayersReadyWithTeamSelection'](gm,result)
assert(result.value==true,'Everyone ready starts with an empty team')
session.gi.UsedMatchOptions.RequiredPlayersPerTeam=1
hooks['O/B_ObjectiveGameMode:IsPlayerTeamSelectionBalanced'](gm,nil,result)
assert(result.value==false,'One required player per team: both teams must have players')
rules.startReady=false
-- Native spectators still count. Only a quarantined newcomer is exempt.
function witch:GetPlayerId() return 0 end
function spectator:GetPlayerId() return 7 end
local teamReady=hooks['O/B_ObjectiveGameMode:AreAllPlayersReadyWithTeamSelection']
local loaded=hooks['Core/B_GameMode:CheckIfAllPlayersAreReady']
waiter={Team=2,ObjectiveTeam=0,WantsToSpectate=true,IsReady=false,IsReadyObjectiveTeamSelection=false}
players={witch,waiter}
for _,startReady in ipairs({false,true}) do
    rules.startReady=startReady
    result.value=false;teamReady(gm,result)
    assert(result.value==true,'A waiter cannot block team readiness with either start rule')
    result.value=false;loaded(gm,result)
    assert(result.value==true,'A waiter cannot block lobby/halftime load readiness')
    witch.IsReadyObjectiveTeamSelection=false;teamReady(gm,result)
    assert(result.value==false,'Ordinary players must still press Ready')
    witch.IsReadyObjectiveTeamSelection=true
    witch.IsReady=false;loaded(gm,result)
    assert(result.value==not startReady,'Preserve the native player-id-0 exemption outside Ready mode')
    witch.IsReady=true
    players={waiter};teamReady(gm,result);assert(result.value==false)
    loaded(gm,result);assert(result.value==false,'Waiters alone never start a round')
    players={witch,spectator,waiter}
    spectator.IsReady=false;spectator.IsReadyObjectiveTeamSelection=false
    teamReady(gm,result);assert(result.value==false,'Ordinary spectators still count in team readiness')
    loaded(gm,result);assert(result.value==false,'Ordinary spectators still count in load readiness')
    spectator.IsPendingDisconnect=true
    teamReady(gm,result)
    assert(result.value==startReady,'Native team readiness includes pending disconnects outside Ready mode')
    loaded(gm,result);assert(result.value==true,'Native load readiness skips pending disconnects')
    spectator.IsPendingDisconnect=false;spectator.IsReady=true;spectator.IsReadyObjectiveTeamSelection=true
    players={witch,waiter}
end
session.role='client';result.value='native';teamReady(gm,result);loaded(gm,result)
assert(result.value=='native','Client ready gates stay native')
session.role='host';session.mode='creative'
teamReady(gm,result);loaded(gm,result);assert(result.value=='native','Creative ready gates stay native')
session.mode='monroth.fap';players={witch,spectator};waiter=nil
rules.startReady=true
hooks['O/B_ObjectiveGameMode:HandleStartMatchOverride'](gm)
assert(witch.Lives==10 and witch.ObjectiveMatchPlayerState.Lives==10)
rules.lives='infinite'
for _=1,150 do
    witch.Lives=witch.Lives-1 -- native death decrements before calling CheckWitchesAlive.
    hooks['O/B_ObjectiveGameMode:CheckWitchesAlive'](gm,result)
    assert(result.value==true and witch.Lives==99)
end
hooks['O/B_ObjectiveGameMode:GetTotalWitchesLives'](gm,result)
assert(result.value==0,'Infinite reserve never contributes to scoring')
rules.lives=255;result.value='native'
hooks['O/B_ObjectiveGameMode:EnsureInitialize'](gm)
hooks['O/B_ObjectiveGameMode:HandleStartMatchOverride'](gm)
assert(gs.MaxLives==5 and witch.Lives==255,'Typed finite lives retain the engine cap and full player count')
hooks['O/B_ObjectiveGameMode:GetTotalWitchesLives'](gm,result)
assert(result.value=='native','Finite scoring stays native')
hooks['O/B_ObjectiveKillSpectator:ReceivePossessed']({})
assert(timer.nexttick)
session.mode='creative';result.value='native'
hooks['Core/B_GameMode:CheckIfAllPlayersAreReady'](gm,result)
assert(result.value=='native')
-- Native result order: round opens, nested kill callbacks, native round save, winner query.
local published
S.C.net={publish=function(_,value) published=value end,watch=function() end}
S.U={};session.mode='monroth.fap';S.MATCH='Match/'
function S.order(text) local a={};for v in text:gmatch('[^,]+') do a[#a+1]=v end;return a end
function S.ranked(rules) return S.order(rules.order) end
S.match={rounds={}};rules.order='wins,pots,lives,kills,time,props';rules.lives='infinite'
mm.TeamAStartsAsWitch=true;mm.SurrenderedTeam=0
function witch:GetAddress() return 1 end
local hunter={Team=1,ObjectiveTeam=2,IsReady=true,ObjectiveMatchPlayerState={}}
players[2]=hunter
local victimController={PlayerState=witch}
local victimPawn={GetController=function() return victimController end}
local handler={GetOwner=function() return victimPawn end}
local killer={PlayerState=hunter}
local damage='/Game/Blueprints/Player/Components/B_DamageHandler.B_DamageHandler_C:'
dofile(dir..'results.lua')(S)
for _,fn in ipairs(events.round_start)do fn(gs)end
pre[damage..'Kill'](handler)
pre['/Game/Blueprints/Player/B_PlayerController.B_PlayerController_C:ServerHandleLastHit'](killer)
pre['/Game/Blueprints/Player/B_PlayerController.B_PlayerController_C:ServerHandleLastHit'](killer)
pre[damage..'RemoveTeamAndSetDead'](handler)
hooks[damage..'Kill'](handler)
assert(S.match.rounds[1].kills==1)
local pot={Stacks=1,MaxStacks=2,GetAddress=function() return 3 end}
S.countStacks(pot);pot.Stacks=2;S.countStacks(pot);S.countStacks(pot)
assert(S.match.rounds[1].props==2 and S.match.rounds[1].pots==1)
hooks['O/B_ObjectiveMatchManager:AddRoundState'](mm,{Playtime=30,WitchLivesLeft=99,WinnerTeam=0})
mm.CurrentRound=2
for _,fn in ipairs(events.round_start)do fn(gs)end
S.countStacks(pot)
hooks['O/B_ObjectiveMatchManager:AddRoundState'](mm,{Playtime=30,WitchLivesLeft=1,WinnerTeam=0})
local reason={value=1,set=result.set,get=function(self) return self.value end}
hooks['O/B_ObjectiveMatchManager:GetWinnerTeam'](mm,gs,result,reason)
assert(result.value==2 and reason.value==6 and published.reason=='kills')
mm.SurrenderedTeam=1;result.value='native'
hooks['O/B_ObjectiveMatchManager:GetWinnerTeam'](mm,gs,result,reason)
assert(result.value=='native' and published.normal==false)
print('engine_order: passed')
