local hooks,pre,events,timers={},{},{},{}
local R={native={}}
-- Like Runtime, several callbacks on one path all run, in registration order.
function R.post(path,fn)
    local previous=hooks[path]
    hooks[path]=previous and function(...)previous(...);return fn(...)end or fn
end
function R.pre(path,fn)pre[path]=fn end
function R.on(event,fn)events[event]=fn end
function R.valid(v)return v and not v.invalid and v or nil end
function R.after(ms,fn,survive)
    local t={ms=ms,fn=fn,survive=survive};timers[#timers+1]=t
    return function()t.cancelled=true end
end
local mm={CurrentRound=1,Players={},IsMatchOver=false,TeamAStartsAsWitch=false}
function mm:GetAddress()return 100 end
function mm:GetWinnerForRound(first,out)
    local witchTeam=self.TeamAStartsAsWitch and 1 or 2
    out.WinnerTeam=first and witchTeam or 3-witchTeam
end
function mm.Players:ForEach(fn)
    for key,value in pairs(self) do
        if type(value)=='table' then fn({get=function()return key end},{get=function()return value end}) end
    end
end
function mm:RemovePlayerWhenMatchNotStarted(ps)
    if self.CurrentRound<=0 then self.Players[ps.netId]=nil end
end
-- Cooked manager lookup uses UniqueNetId, not asynchronously filled account fields.
function mm:GetObjectiveMatchPlayerState(ps,out)
    out.ObjectiveMatchPlayerState=mm.Players[ps.netId]
    if hooks['O/B_ObjectiveMatchManager:GetObjectiveMatchPlayerState'] then
        hooks['O/B_ObjectiveMatchManager:GetObjectiveMatchPlayerState'](self,ps,{
            get=function()return out.ObjectiveMatchPlayerState end,
            set=function(_,v)out.ObjectiveMatchPlayerState=v end})
    end
end
local gm={ends=0}
function gm:CheckEndMatchWitchesDead()end
function gm:HandleEndMatch()self.ends=self.ends+1 end
function gm:K2_GetActorLocation()return {}end
local session={role='host',gs={State=2},gm=gm,mode='monroth.fap'}
function session.gs:IsA()return false end
local rules={}
local players={}
local S={INFINITE_LIVES=99,HEARTS=5,R=R,C={state=function() end,side=function(ps) local t=ps and ps.Team;return t==0 and "witch" or t==1 and "hunter" or nil end,session=function()return session end},O='O/',CORE='Core/'}
function S.path(folder,name,method)return folder..name..(method and ':'..method or '')end
function S.text(v)return v end
function S.manager()return mm end
-- Core's C.scoped test double; the match is the host's Fill a Pot match (package.lua's scope).
dofile('candidate/runtime-source/Core/tests/lib/scoped.lua')(R,S.C)
local function inMatch(s) return s.mode=='monroth.fap' and s.role~='client' end
S.onMatchHost=S.C.scoped(inMatch)
function S.inMatch() return inMatch(session) end
function S.log() end
function S.host() return session.role~='client' end
dofile('candidate/runtime-source/FillAPotPlus/facts.lua')(S)
-- The lives a witch starts a half with: here the mode's rule (Fill a Pot+ tells it).
function S.halfLives(witch) return witch and (rules.lives=='infinite' and 99 or rules.lives) or 0 end
function S.players()return players end
function S.rules()return rules end
function S.rejoin()return rules.rejoin~=false end
function S.C.replicate(ps,key,value,index)
    ps[key]=value
    local notify=hooks['/Script/Engine.NetPushModelHelpers:MarkPropertyDirtyFromRepIndex']
    if notify then notify({},ps,index) end
end
function S.new()
    return {ScoreStatManager={},Initialize=function(self,id)self.PlayerId=id end}
end
function R.native.spawn()return {}end
function StaticFindObject(path)
    if path=='/Script/Engine.Default__GameplayStatics' then
        return {GetGameState=function(_,ps)return {CurrentRound=ps.nativeRound} end}
    end
    assert(path=='Core/B_GameMode:K2_PostLogin')
    return function(_,pc)pc.parentCalls=(pc.parentCalls or 0)+1 end
end
local address=0
local function player(id,team,lives)
    address=address+1
    local currentAddress=address
    local ps={netId=id,nativeRound=mm.CurrentRound,ProductUserId='',OnlineSystemAccountName='',ObjectiveTeam=0,Team=2,IsReady=false}
    function ps:GetAddress()return currentAddress end
    function ps:IsA()return false end
    function ps:GetPlayerName()return 'same display name' end
    function ps:OnRep_Team()end
    function ps:OnRep_SelectedTeam()end
    function ps:InitializeFromMatchPlayerState()
        local m=self.ObjectiveMatchPlayerState
        self.ObjectiveTeam=m.ObjectiveTeam;self.Team=mm.roleForTeam and mm.roleForTeam(m.ObjectiveTeam) or team
        -- Native attachment sets Team; IsWitchTeam is initialized by the pawn.
        self.IsWitchTeam=false;self.SelectedTeam=self.Team
        self.Lives=m.Lives;self.IsDead=m.IsDead
    end
    local pc={PlayerState=ps}
    ps.PlayerController=pc
    function pc:Possess(pawn)self.Pawn=pawn;hooks['/Script/Engine.Controller:Possess'](self)end
    return ps,pc
end
dofile('candidate/runtime-source/FillAPotPlus/rejoin.lua')(S)
local login=pre['O/B_ObjectiveGameMode:K2_PostLogin']
local depart=pre['O/B_ObjectiveGameMode:UnregisterPlayerOverride']
-- World end clears Core's GI before the native game mode unregisters players.
-- The existing Plus scope boundary must run before asking for that manager.
local manager=S.manager
S.manager=function()error('No game instance remains after world end')end
session.mode='vanilla'
depart(gm,{PlayerState={}})
session.mode='monroth.fap'
S.manager=manager
local ready=hooks['/Game/Blueprints/Player/B_PlayerState:OnRep_IsReady']
local function out(v)return {value=v,set=function(self,x)self.value=x end}end
-- Host Ready advances the round before another selected lobby player has
-- been inserted into Players. A missing lookup is not late admission.
local selected=player('selected-lobby',0,2)
selected.ObjectiveTeam=1
local beforeInsert={};mm:GetObjectiveMatchPlayerState(selected,beforeInsert)
assert(not beforeInsert.ObjectiveMatchPlayerState and not S.waiter(selected)
    and selected.ObjectiveTeam==1 and not selected.WantsToSpectate,
    'Native roster insertion must retain a selected lobby participant')
mm.Players[selected.netId]={PlayerId=selected.netId,ObjectiveTeam=1,Lives=2}
assert(S.participant(selected)==mm.Players[selected.netId])
for index,case in ipairs({{0,7,false},{0,255,false},{0,3,true},{0,0,true},{1,0,false}})do
    mm.IsMatchOver=false
    local team,lives,dead=table.unpack(case)
    local id='EOS|native-'..index
    mm.TeamAStartsAsWitch=team~=0
    local m={PlayerId=id,ObjectiveTeam=2,Lives=lives,IsDead=dead,score=11}
    mm.Players[id]=m
    local early=player(id,team,lives)
    assert(S.participant(early)==m,'Fresh login resolves native roster before account fields or attachment exist')
    local ps,pc=player(id,team,lives)
    ps.ObjectiveMatchPlayerState=m;ps:InitializeFromMatchPlayerState()
    ps.ProductUserId='different-product';ps.OnlineSystemAccountName='different-platform'
    assert(S.participant(ps)==m,'Native identity is independent of account strings')
    mm:RemovePlayerWhenMatchNotStarted(ps) -- Objective K2_OnLogout route, before UnregisterPlayerOverride.
    assert(mm.Players[id]==m and m.ObjectiveTeam==2,'Active-match removal does not reset native roster/team')
    assert(depart,'Departure must run before direct native UnregisterPlayerOverride')
    depart(gm,pc)
    local eligible=team==1 or lives>0
    assert(#timers==0,'No time limit: no deadline')
    -- Native unregister marks pending, saves once, and asks integrity before returning.
    ps.IsPendingDisconnect=true;m.score=m.score+5
    local intact=out(false)
    hooks['O/B_ObjectiveMatchManager:IsMatchIntact'](mm,session.gs,intact)
    assert(intact.value==eligible,'The kept place is there before native forfeit checks')
    local matchDead,surrender=out(true),out(true)
    hooks['O/B_ObjectiveMatchManager:IsMatchDead'](mm,session.gs,matchDead)
    hooks['O/B_ObjectiveMatchManager:CanTeamSurrender'](mm,0,session.gs,surrender)
    assert(matchDead.value==not eligible and surrender.value==not eligible)
    events.world_end() -- Native manager and reconnect records survive world reload.
    local joined,newpc=player(id,team,lives)
    assert(joined.ObjectiveMatchPlayerState==nil and joined.ProductUserId=='')
    assert(login(gm,newpc)==true and newpc.parentCalls==1)
    assert(not S.waiter(joined) and joined.ObjectiveMatchPlayerState==m)
    assert(joined.ObjectiveTeam==2 and joined.Team==team and joined.Lives==lives)
    assert(not joined.IsReady,'Active-round reconnect has no native Ready action')
    assert(newpc.IsRejoiningMatch and not newpc.RejoinInitialized,'Roster attachment starts native reconnect without Ready')
    newpc:Possess({})
    -- Native witch branch subtracts AFTER nested Possess, then marks Lives dirty.
    if team==0 and lives>0 then
        m.Lives=m.Lives-1;S.C.replicate(joined,'Lives',m.Lives,49)
    end
    assert(joined.Lives==lives and m.Lives==lives,'Rejoin preserves lives including the 255 cap')
    assert(m.score==16,'Native score save occurs exactly once')
end
-- The guest can be absent while StartNewGameOverride advances to half 2.
-- Native HandleStartMatchOverride initializes PlayerArray, excluding this guest.
for _,startsAsWitch in ipairs({false,true}) do
    for objectiveTeam=1,2 do
        mm.CurrentRound=1;mm.TeamAStartsAsWitch=startsAsWitch
        mm.IsMatchOver=false;rules.lives=4
        local witchTeam=startsAsWitch and 1 or 2
        local wasWitch=objectiveTeam==witchTeam
        local oldLives=wasWitch and 1 or 0
        local id='half-'..tostring(startsAsWitch)..'-'..objectiveTeam
        local m={PlayerId=id,ObjectiveTeam=objectiveTeam,Lives=oldLives,IsDead=false,HealthPercental=.25,score=17}
        mm.Players[id]=m
        local ps,pc=player(id,wasWitch and 0 or 1,oldLives)
        ps.ObjectiveMatchPlayerState=m;ps:InitializeFromMatchPlayerState()
        depart(gm,pc)
        events.world_end()
        mm.CurrentRound=2
        hooks['O/B_ObjectiveGameMode:StartNewGameOverride'](gm,true)
        assert(m.Lives==oldLives,'Restart by a player join is not a half transition')
        hooks['O/B_ObjectiveGameMode:StartNewGameOverride'](gm,false)
        local currentLives=wasWitch and 0 or 4
        assert(m.Lives==currentLives and not m.IsDead and m.HealthPercental==1,
            'Absent native roster receives the new half life reserve and health')
        assert(#timers==0,'A dropped player\'s place has no time limit')
        local witchAlive=out(false)
        hooks['O/B_ObjectiveGameMode:CheckWitchesAlive'](gm,witchAlive)
        assert(witchAlive.value==not wasWitch,'Grace tracks the current half role while the guest is away')
        mm.roleForTeam=function(t)return t==3-witchTeam and 0 or 1 end
        local joined,newpc=player(id,2,0)
        login(gm,newpc)
        assert(joined.Team==(wasWitch and 1 or 0) and joined.ObjectiveTeam==objectiveTeam)
        newpc:Possess({})
        if not wasWitch then m.Lives=m.Lives-1;S.C.replicate(joined,'Lives',m.Lives,49) end
        assert(joined.Lives==currentLives and m.Lives==currentLives,
            'Reconnect restores the current native half, never departure lives')
        assert(m.score==17)
        mm.roleForTeam=nil
    end
end
mm.CurrentRound=1
-- A hard-kill just before halftime can reach native Unregister only after
-- the manager advances. Its PlayerState still belongs to the old half/world.
for _,wasWitch in ipairs({false,true}) do
    mm.CurrentRound=1;mm.TeamAStartsAsWitch=wasWitch;mm.IsMatchOver=false
    local id='late-half-save-'..tostring(wasWitch)
    local oldLives=wasWitch and 1 or 0
    local m={PlayerId=id,ObjectiveTeam=1,Lives=oldLives,IsDead=false,score=23}
    mm.Players[id]=m
    local ps,pc=player(id,wasWitch and 0 or 1,oldLives)
    ps.ObjectiveMatchPlayerState=m;ps:InitializeFromMatchPlayerState()
    mm.CurrentRound=2;ps.nativeRound=2 -- Same GameState advances while this pending role stays old.
    hooks['O/B_ObjectiveGameMode:StartNewGameOverride'](gm,false)
    local currentLives=wasWitch and 0 or rules.lives
    assert(m.Lives==currentLives,'All roster entries advance before disconnect recognition')
    depart(gm,pc)
    -- The native logout saves additive scores once, then copies old half fields.
    m.score=m.score+5;m.Lives=oldLives;m.IsDead=true;m.HealthPercental=.2
    hooks['O/B_ObjectivePlayerState:SaveDataToMatchPlayerState'](ps)
    assert(m.Lives==currentLives and not m.IsDead and m.HealthPercental==1 and m.score==28,
        'An old half native save cannot overwrite the new half reserve or health')
    local alive=out(false)
    hooks['O/B_ObjectiveGameMode:CheckWitchesAlive'](gm,alive)
    assert(alive.value==not wasWitch,'Delayed native logout holds the current half role')
    mm.roleForTeam=function()return wasWitch and 1 or 0 end
    local joined,newpc=player(id,2,0);login(gm,newpc);newpc:Possess({})
    if not wasWitch then m.Lives=m.Lives-1;S.C.replicate(joined,'Lives',m.Lives,49) end
    assert(joined.Lives==currentLives and m.Lives==currentLives)
    -- A current-half dead participant's native save remains authoritative.
    m.Lives=0;m.IsDead=true;m.HealthPercental=0;joined.Team=2 -- Native death spectates, SelectedTeam keeps this half's role.
    hooks['O/B_ObjectivePlayerState:SaveDataToMatchPlayerState'](joined)
    assert(m.Lives==0 and m.IsDead and m.HealthPercental==0,'Same-half native deaths are never reset')
    mm.roleForTeam=nil
end
mm.CurrentRound=1;mm.TeamAStartsAsWitch=false
-- No native roster member: detached spectator even with somebody else's display name.
local newcomer,pc=player('newcomer',2,0)
newcomer.IsReady=true;newcomer.IsReadyObjectiveTeamSelection=true
login(gm,pc)
assert(newcomer.IsReady and newcomer.IsReadyObjectiveTeamSelection,'Initial quarantine preserves native readiness')
assert(pc.parentCalls==1 and S.waiter(newcomer) and pc.Pawn)
assert(newcomer.ObjectiveTeam==0 and newcomer.Team==2 and newcomer.Lives==0 and newcomer.WantsToSpectate)
assert(mm.Players.newcomer==nil,'Spectator never enters native match roster')
-- OnRep runs after native readiness notification. Waiting does not undo it.
for _=1,3 do
    newcomer.IsReady=true;newcomer.IsReadyObjectiveTeamSelection=true
    if ready then ready(newcomer) end
    assert(newcomer.IsReady and newcomer.IsReadyObjectiveTeamSelection,'Ready notification must not unready a waiter')
    assert(S.waiter(newcomer) and newcomer.Team==2 and newcomer.ObjectiveTeam==0)
    assert(not pc.IsRejoiningMatch,'Ready never arms a newcomer as a reconnect')
end
-- Native team RPCs are inert mid-match (controller dump:165 and :200).
local function selectTeam(team)
    if mm.CurrentRound<=0 then
        newcomer.ObjectiveTeam=team;newcomer.ObjectiveMatchPlayerState.ObjectiveTeam=team
        newcomer.IsReadyObjectiveTeamSelection=false
    end
    local post=hooks['O/B_ObjectivePlayerController:SetObjectiveTeam']
    if post then post(pc) end
end
selectTeam(1);selectTeam(2)
local toggle=hooks['O/B_ObjectivePlayerController:SetReadyObjectiveTeamSelection']
if toggle then toggle(pc) end -- Native toggle is also inert while CurrentRound>0.
assert(newcomer.IsReadyObjectiveTeamSelection,'Mid-match Ready RPC must not re-quarantine the waiter')
assert(newcomer.ObjectiveTeam==0 and newcomer.Team==2 and newcomer.IsReady,'Native mid-match team lock preserves readiness')
-- An unassigned native row is also not a participant.
mm.Players.unassigned={PlayerId='unassigned',ObjectiveTeam=0}
local unassigned=player('unassigned',2,0)
assert(S.participant(unassigned)==nil)
-- No time limit: the place stays until the match ends; teardown forgets it.
local ps,leaving=player('expiry',1,0)
local m={PlayerId='expiry',ObjectiveTeam=2,Lives=0,IsDead=false}
mm.Players.expiry=m;ps.ObjectiveMatchPlayerState=m;ps:InitializeFromMatchPlayerState()
local host=player('host',0,10);host.ObjectiveTeam=1;host.Team=0
players={host,newcomer}
depart(gm,leaving)
assert(#timers==0 and not mm.IsMatchOver,'Nobody is dropped by a clock')
local intact=out(false);hooks['O/B_ObjectiveMatchManager:IsMatchIntact'](mm,nil,intact)
assert(intact.value,'The match waits for the player')
hooks['O/B_ObjectiveMatchManager:TearDown'](mm)
local after=out(false);hooks['O/B_ObjectiveMatchManager:IsMatchIntact'](mm,nil,after)
assert(after.value==false,'The match end forgets the kept place')
assert(not S.waiter(newcomer) and not newcomer.WantsToSpectate and newcomer.GrantExpForThisRound,
    'TearDown releases waiters for the next match')
mm.CurrentRound=0;selectTeam(1)
assert(newcomer.ObjectiveTeam==1,'Former waiter may select a team in the new match')
mm.CurrentRound=1
local travelling,traveller=player('traveller',2,0)
login(gm,traveller);assert(S.waiter(travelling))
events.world_end();assert(not S.waiter(travelling),'World end drops world-local waiter addresses')
-- Halftime replaces PlayerState without PostLogin. ReceiveBeginPlay obtains its
-- attachment from the surviving manager before native readiness is evaluated.
local nextWorld=player('traveller',2,0)
local attached={};mm:GetObjectiveMatchPlayerState(nextWorld,attached)
assert(attached.ObjectiveMatchPlayerState and S.waiter(nextWorld),
    'Native halftime lookup must supply a detached waiter state in the new world')
assert(nextWorld.WantsToSpectate and nextWorld.ObjectiveTeam==0 and mm.Players.traveller==nil)
assert(not nextWorld.IsReady,'A halftime waiter remains unready without blocking the next start')
-- A guest who left the previous lobby can retain an unassigned native row.
-- This was the live failure: its valid lookup defeated missing-row inference.
local stale={PlayerId='prior-lobby',ObjectiveTeam=0}
mm.Players['prior-lobby']=stale
local late,latepc=player('prior-lobby',2,0)
login(gm,latepc);assert(S.waiter(late) and mm.Players['prior-lobby']==stale)
events.world_end()
local half2=player('prior-lobby',2,0)
local half2out={};mm:GetObjectiveMatchPlayerState(half2,half2out)
assert(S.waiter(half2) and half2out.ObjectiveMatchPlayerState~=stale and not half2.IsReady,
    'A late guest with a valid unassigned row remains a waiter through halftime')
local ordinary=player('unassigned',2,0)
local ordinaryout={};mm:GetObjectiveMatchPlayerState(ordinary,ordinaryout)
assert(not S.waiter(ordinary) and ordinaryout.ObjectiveMatchPlayerState==mm.Players.unassigned,
    'An ordinary lobby spectator still requires Ready after halftime')
hooks['O/B_ObjectiveMatchManager:TearDown'](mm)
events.world_end()
local nextMatch=player('prior-lobby',2,0)
mm:GetObjectiveMatchPlayerState(nextMatch,{})
assert(not S.waiter(nextMatch),'TearDown clears late admission with the match')
local count=#timers
for _,mode in ipairs({'client','inactive','lobby'}) do
    session.role=mode=='client' and 'client' or 'host'
    session.mode=mode=='inactive' and 'vanilla' or 'monroth.fap';mm.CurrentRound=mode=='lobby' and 0 or 1
    assert(login(gm,leaving)==nil)
    depart(gm,leaving);assert(#timers==count,'Reconnect only changes host active Plus matches')
end
print('PASS rejoin: native identity, both logout routes, no time limit, travel, readiness, teams/lives/score, and waiter readiness/team lock/release')
mm.CurrentRound=1;mm.IsMatchOver=false;session.mode='monroth.fap';session.role='host'
local newcomer,newpc=player('new-watcher',0,4)
assert(login(gm,newpc)==true and not newpc.IsBeingKickedDueMatchHasStarted and S.waiter(newcomer),'A newcomer always watches')
rules.rejoin=false
local id='disabled-rejoin'
mm.Players[id]={PlayerId=id,ObjectiveTeam=2,Lives=7,IsDead=false}
local returning,pc=player(id,0,7)
assert(login(gm,pc)==true and S.waiter(returning) and returning.ObjectiveTeam==0)
assert(not pc.IsRejoiningMatch,'Disabled rejoin keeps the returning player outside the roster')
events.world_end()
local disabledHalf2=player(id,0,7)
mm:GetObjectiveMatchPlayerState(disabledHalf2,{})
assert(S.waiter(disabledHalf2) and disabledHalf2.ObjectiveTeam==0,
    'Disabled rejoin remains spectating at halftime despite its assigned native row')
print('PASS optional newcomer spectating and reconnect enable policy retain identity/quarantine')
