-- Real Plus mode selection and login/gameplay callbacks. A native continuation
-- must receive the original controller and OUT values in every vanilla mode.
local base='candidate/runtime-source/FillAPotPlus/'
local pre,post={},{}
local function add(list,path,fn)
    list[path]=list[path] or {};table.insert(list[path],fn)
end
local R={native={},packages={}}
function R.pre(path,fn)add(pre,path,fn)end
function R.post(path,fn)add(post,path,fn)end
function R.on()end
function R.key()end
function R.valid(v)return v end
local pref
function R.settings(_,defaults)pref=defaults;pref.importedRules=true;return pref end
function R.save_settings()end
local options={GetAddress=function()return 17 end}
local session={role='host',mode='vanilla',gi={UsedMatchOptions=options},gs={}}
local S={INFINITE_LIVES=99,HEARTS=5,R=R,O='O/',CORE='Core/',MATCH='Match/',codec={}}
S.C={memory={shown_by=function() end,on=function() return true end,register=function() end},session=function()return session end,on_playtest=function()end,on_session=function()end,
    files={read_json=function()end},net={watch=function()end,publish=function()end}}
S.U={rules_tab=function()end,menu_entry=function()end}
function S.path(folder,name,method)return folder..name..(method and ':'..method or '')end
dofile(base..'tests/lib/scope.lua')(S)
function S.manager()error('Vanilla hooks must not read the Plus match manager')end
function S.C.replicate()error('Vanilla hooks must not write gameplay state')end
function S.new()error('Vanilla hooks must not allocate waiter state')end
function R.native.spawn()error('Vanilla hooks must not spawn a spectator')end
function R.after()error('Vanilla hooks must not start reconnect deadlines')end
function StaticFindObject()error('Vanilla login must not substitute the parent login')end
local gm={}
function gm:StartNewGame()error('Plus must not restart a vanilla round')end
function gm:HandleEndMatch()error('Plus must not end a vanilla match')end
session.gm=gm
dofile('candidate/runtime-source/Core/tests/lib/rules.lua')(S.R,S.C)
dofile(base..'rules.lua')(S)
dofile(base..'gameplay.lua')(S)
-- (rejoin.lua, not under test here, tells the watching players.)
function S.waiter() end
-- events.lua calls these neighbours; they are not under test here.
function S.refreshHUD() error('Vanilla must not refresh the Plus HUD') end
dofile(base..'events.lua')(S)
local function callbacks(list,path,...)
    for _,fn in ipairs(list[path] or {})do
        assert(fn(...)==nil,'Vanilla native execution must not be consumed or overridden: '..path)
    end
end
local ps={ObjectiveTeam=0,Team=2,Lives=0,IsReady=false}
function ps:GetAddress()return 31 end
local pc={PlayerState=ps}
local function unchanged(path,...)
    local out={}
    function out:get()return self.value end
    function out:set()error('Vanilla OUT parameters must retain their native values: '..path)end
    for _,value in ipairs({false,true,0,7})do
        out.value=value
        callbacks(post,path,...,out)
        assert(out.value==value)
    end
end
local calls=0
-- Every mode Core can report other than 'monroth.fap': nothing Plus may run in any of them.
for _,mode in ipairs({'vanilla','none','creative','B_HideAndSeekGameMode_C','B_ObjectiveGameMode_C'})do
    session.mode=mode
    -- A saved Plus preference is a menu memory; it never selects Plus for a running match.
    for _,savedPlus in ipairs({false,true})do
        pref.plusMode=savedPlus
        assert(not S.inMatch() and S.active()==(mode=='creative'),'Only Creative enables the Plus editor tools')
        for _,returning in ipairs({false,true})do
            ps.ObjectiveTeam=returning and 1 or 0
            ps.Team=returning and 0 or 2
            ps.Lives=returning and 4 or 0
            ps.ObjectiveMatchPlayerState=returning and {ObjectiveTeam=1,Lives=4} or nil
            local roster=ps.ObjectiveMatchPlayerState
            local path=S.path(S.O,'B_ObjectiveGameMode','K2_PostLogin')
            callbacks(pre,path,gm,pc)
            -- Native continuation: the real PRE must leave this call reachable,
            -- with exactly the same controller. Native owns its own join policy.
            local function nativeLogin(self,controller)
                assert(self==gm and controller==pc);calls=calls+1
            end
            nativeLogin(gm,pc)
            callbacks(post,path,gm,pc)
            callbacks(pre,S.path(S.O,'B_ObjectiveGameMode','UnregisterPlayerOverride'),gm,pc)
            assert(ps.ObjectiveMatchPlayerState==roster and not S.waiter(ps))
            assert(ps.ObjectiveTeam==(returning and 1 or 0) and ps.Lives==(returning and 4 or 0))
            assert(not ps.WantsToSpectate and pc.IsRejoiningMatch==nil and pc.IsBeingKickedDueMatchHasStarted==nil)
        end
        for _,method in ipairs({'IsMatchIntact','IsMatchDead'})do
            unchanged(S.path(S.O,'B_ObjectiveMatchManager',method),{},session.gs)
        end
        unchanged(S.path(S.O,'B_ObjectiveMatchManager','CanTeamSurrender'),{},1,session.gs)
        unchanged(S.path(S.O,'B_ObjectiveMatchManager','GetObjectiveMatchPlayerState'),{},ps)
        unchanged(S.path(S.O,'B_ObjectiveMatchManager','IsPlayerInMatch'),{},ps)
        for _,method in ipairs({'GetHuntersCount','CheckIfAllPlayersAreReady','CanJoinAsMidgameHunter'})do
            unchanged(S.path(S.CORE,'B_GameMode',method),gm)
        end
        for _,method in ipairs({'CheckWitchesAlive','AreAllPlayersReadyWithTeamSelection'})do
            unchanged(S.path(S.O,'B_ObjectiveGameMode',method),gm)
        end
        unchanged(S.path(S.O,'B_ObjectiveGameMode','IsPlayerTeamSelectionBalanced'),gm,2)
        unchanged(S.path(S.O,'B_ObjectiveGameMode','GetPlayerPlayTime'),gm,ps)
        unchanged(S.path(S.O,'B_ObjectiveGameMode','StartNewGameOverride'),gm,true)
        unchanged(S.path(S.O,'B_ObjectiveGameMode','StartNewGameOverride'),gm,false)
        callbacks(post,S.path(S.O,'B_ObjectivePlayerState','SaveDataToMatchPlayerState'),ps)
        callbacks(post,'/Script/Engine.Controller:Possess',pc)
        callbacks(post,'/Script/Engine.NetPushModelHelpers:MarkPropertyDirtyFromRepIndex',{},ps,49)
        callbacks(post,S.path(S.O,'B_ObjectiveMatchManager','TearDown'),{})
    end
end
assert(calls==20)
-- Ordinary native Fill a Pot on a modded server: Core reports the native mode, not Plus.
session.mode='B_ObjectiveGameMode_C';pref.plusMode=false
assert(not S.active() and not S.inMatch())
callbacks(pre,S.path(S.O,'B_ObjectiveGameMode','K2_PostLogin'),gm,pc)
print('PASS vanilla login/rejoin preserves native continuation, roster, readiness and OUT values; ordinary Fill a Pot stays outside Plus')
