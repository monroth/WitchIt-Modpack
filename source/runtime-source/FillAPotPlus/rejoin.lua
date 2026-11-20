-- Rejoin in a Fill a Pot+ match the host runs (S: the helpers, S.rejoin() the host's choice,
-- S.halfLives). A player who drops keeps their place until the match ends: the match
-- waits for them, and coming back they take their team and lives again. A player who arrives
-- during the match (or one who may not rejoin) watches until the next round: S.waiter(ps).
return function(S)
    local R,C=S.R,S.C
    -- A record per player id of this match: r.state - 'away' (left), 'back' (came back, its role
    -- being restored), 'possessed' (a witch back in a body: the game takes the life of the rejoin
    -- next, then the kept lives go back), 'spectating' (admitted as a spectator); r.kept: the match
    -- keeps the place (and waits) until the player is restored (audit D3: one state, not four flags).
    local records,waiters={},{}
    function S.waiter(ps) return waiters[ps:GetAddress()] end
    function S.participant(ps)
        -- The manager resolves UniqueNetId, before the account fields arrive.
        local out={}
        S.manager():GetObjectiveMatchPlayerState(ps,out)
        local mps=R.valid(out.ObjectiveMatchPlayerState)
        if mps and (mps.ObjectiveTeam==1 or mps.ObjectiveTeam==2) then return mps,S.text(mps.PlayerId),mps end
        return nil,nil,mps
    end
    local function waiting(witch)
        for _,r in pairs(records) do if r.kept and (witch==nil or r.witch==witch) then return true end end
        return false
    end
    local function witchTeam(mm)
        local team={};mm:GetWinnerForRound(mm.CurrentRound==1,team)
        return team.WinnerTeam
    end
    local function startHalf(mps,witch)
        mps.Lives=S.halfLives(witch);mps.IsDead=false;mps.HealthPercental=1
    end
    S.onMatchHost.pre(S.path(S.O,'B_ObjectiveGameMode','UnregisterPlayerOverride'),function(gm,pc)
        if not R.valid(pc) then return end
        local ps,mm=pc.PlayerState,S.manager()
        if not R.valid(ps) or mm.CurrentRound==0 or mm.IsMatchOver then return end
        local mps,id=S.participant(ps)
        if not mps or S.waiter(ps) then return end
        local witch=mps.ObjectiveTeam==witchTeam(mm)
        local lives=(ps.SelectedTeam==0)==witch and ps.Lives or S.halfLives(witch)
        local r={mps=mps,witch=witch,state='away',
            team=mps.ObjectiveTeam,kept=S.rejoin() and (not witch or lives>0)}
        records[id]=r
        S.log('Left %s: %s, lives %s, place kept %s',S.text(ps:GetPlayerName()),witch and 'witch' or 'hunter',lives,
            r.kept and 'yes' or 'no')
        -- Native UnregisterPlayerOverride saves the additive score exactly once.
    end)
    S.onMatchHost.post(S.path(S.O,'B_ObjectiveGameMode','StartNewGameOverride'),function(gm,restartByPlayerJoin)
        local mm=S.manager()
        if restartByPlayerJoin then return end
        if mm.CurrentRound~=2 or mm.IsMatchOver then return end
        -- The native half transition advances the roster before travelling, but
        -- HandleStartMatchOverride initializes only connected PlayerStates.
        local team=witchTeam(mm)
        mm.Players:ForEach(function(_,value)
            local mps=value:get()
            if mps.ObjectiveTeam==1 or mps.ObjectiveTeam==2 then startHalf(mps,mps.ObjectiveTeam==team) end
        end)
        for _,r in pairs(records) do
            if r.kept then r.witch=r.team==team end
        end
    end)
    S.onMatchHost.post(S.path(S.O,'B_ObjectivePlayerState','SaveDataToMatchPlayerState'),function(ps)
        local mm=S.manager()
        local mps=R.valid(ps.ObjectiveMatchPlayerState)
        if not mps or mm.CurrentRound~=2 then return end
        -- Halftime reuses GameState; a pending player keeps the previous
        -- SelectedTeam. Native deaths change Team, leaving SelectedTeam intact.
        -- Keep additive scores, but not a previous role's reserve or health.
        if mps.ObjectiveTeam==1 or mps.ObjectiveTeam==2 then
            local witch=mps.ObjectiveTeam==witchTeam(mm)
            if (ps.SelectedTeam==0)~=witch then startHalf(mps,witch) end
        end
    end)
    for _,method in ipairs({'IsMatchDead','IsMatchIntact'}) do
        S.onMatchHost.post(S.path(S.O,'B_ObjectiveMatchManager',method),function(mm,gs,out)
            if waiting() then out:set(method=='IsMatchIntact') end
        end)
    end
    S.onMatchHost.post(S.path(S.O,'B_ObjectiveMatchManager','CanTeamSurrender'),function(mm,_,gs,out)
        if waiting() then out:set(false) end
    end)
    S.onMatchHost.post(S.path(S.CORE,'B_GameMode','GetHuntersCount'),function(gm,out)
        if waiting(false) then out:set(math.max(1,out:get())) end
    end)
    S.onMatchHost.post(S.path(S.O,'B_ObjectiveGameMode','CheckWitchesAlive'),function(gm,out)
        if waiting(true) then out:set(true) end
    end)
    local function quarantine(ps)
        C.replicate(ps,'ObjectiveTeam',0,50);C.replicate(ps,'Team',2,21);C.replicate(ps,'SelectedTeam',2,22)
        C.replicate(ps,'Lives',0,49);C.replicate(ps,'IsDead',false,24)
        C.replicate(ps,'IsTeamInitialized',false,52)
        ps.IsWitchTeam=false;ps.WantsToSpectate=true;ps.GrantExpForThisRound=false;ps.StartExpTime=0
        ps:OnRep_Team();ps:OnRep_SelectedTeam()
    end
    local function newWaiter(ps)
        local state=S.new(S.path(S.O,'B_ObjectiveMatchPlayerState'),ps)
        state:Initialize(ps:GetPlayerName());state.ScoreStatManager.PlayerState=ps
        state.ObjectiveTeam=0;state.IsDead=false
        waiters[ps:GetAddress()]=state
        return state
    end
    S.onMatchHost.pre(S.path(S.O,'B_ObjectiveGameMode','K2_PostLogin'),function(gm,pc)
        if not R.valid(pc) or S.manager().CurrentRound==0 then return end
        local ps=pc.PlayerState
        if not R.valid(ps) then return end
        local mps,id,native=S.participant(ps)
        local rejoin=S.rejoin()
        local parent=StaticFindObject(S.path(S.CORE,'B_GameMode','K2_PostLogin'))
        parent(gm,pc)
        pc.IsBeingKickedDueMatchHasStarted=false;pc.IsRejoiningMatch=false
        if mps and rejoin then
            local r=records[id] or {mps=mps,team=mps.ObjectiveTeam}
            records[id]=r;r.pc=pc
            ps.ObjectiveMatchPlayerState=mps
            ps:InitializeFromMatchPlayerState();r.witch=C.side(ps)=='witch';r.lives=mps.Lives
            -- Active-round native selection offers no Ready action. The roster
            -- attachment is complete; let the native controller respawn it.
            r.state='back';pc.RejoinInitialized=false;pc.IsRejoiningMatch=true
            S.log('Rejoined %s: %s, lives %s',S.text(ps:GetPlayerName()),r.witch and 'witch' or 'hunter',r.lives)
        else
            -- (a player whose place was kept, back as a spectator - rejoin since switched off: the match
            -- stops waiting for them; audit 11-20, it waited for the whole match)
            if mps and id and records[id] then records[id].kept=false end
            -- An unassigned roster entry can survive a previous lobby. Remember
            -- this admission on its native identity, across halftime PlayerStates.
            if native then
                local key=S.text(native.PlayerId)
                records[key]=records[key] or {}
                records[key].state='spectating'
            end
            S.log('Joined %s as a spectator until the next round (%s)',S.text(ps:GetPlayerName()),
                mps and 'rejoin off' or 'not in this match')
            ps.ObjectiveMatchPlayerState=waiters[ps:GetAddress()] or newWaiter(ps)
            quarantine(ps)
            local pawn=R.native.spawn(S.path(S.O,'B_ObjectiveSpectator'),gm,gm:K2_GetActorLocation())
            pc:Possess(pawn)
        end
        return true
    end)
    S.onMatchHost.post(S.path(S.O,'B_ObjectiveMatchManager','GetObjectiveMatchPlayerState'),function(mm,ps,out)
        if not R.valid(ps) then return end
        local state=S.waiter(ps)
        local native=R.valid(out:get())
        local record=native and records[S.text(native.PlayerId)]
        -- Halftime waiters are unassigned. A selected lobby team can still be
        -- awaiting native roster insertion when the first player advances.
        if not state and ps.ObjectiveTeam==0 and mm.CurrentRound>0
            and (not native or record and record.state=='spectating') then
            state=newWaiter(ps);quarantine(ps)
        end
        if state then out:set(state) end
    end)
    S.onMatchHost.post(S.path(S.O,'B_ObjectiveMatchManager','IsPlayerInMatch'),function(mm,ps,out)
        if R.valid(ps) and S.waiter(ps) then out:set(false) end
    end)
    local function restored(ps,id,r)
        records[id]=nil
        r.mps.Lives=r.lives;C.replicate(ps,'Lives',r.lives,49)
        S.log('Restored %s: lives %s',S.text(ps:GetPlayerName()),r.lives)
    end
    S.onMatchHost.post('/Script/Engine.Controller:Possess',function(pc)
        local ps=pc.PlayerState
        if not R.valid(ps) then return end
        local _,id=S.participant(ps);local r=id and records[id]
        if not r or r.pc~=pc or r.state~='back' then return end
        -- Witch rejoin subtracts a life AFTER Possess, then marks Lives dirty.
        if r.witch and r.lives>0 then r.state='possessed' else restored(ps,id,r) end
    end)
    -- A rejoined witch's Lives are marked dirty (replication index 49) once the game has taken
    -- the life of the rejoin: then the kept lives go back. Every replicated field passes here.
    local LIVES=49
    S.onMatchHost.post('/Script/Engine.NetPushModelHelpers:MarkPropertyDirtyFromRepIndex',function(_,ps,index)
        if index~=LIVES or not R.valid(ps) then return end
        for id,r in pairs(records) do
            if r.state=='possessed' and r.pc.PlayerState==ps then restored(ps,id,r);return end
        end
    end)
    S.onMatchHost.post(S.path(S.O,'B_ObjectiveGameMode','GetPlayerPlayTime'),function(gm,ps,out)
        if R.valid(ps) and S.waiter(ps) then out:set(0) end
    end)
    -- The match ends: nobody waits any more; the watching players play the next match.
    S.onMatchHost.post(S.path(S.O,'B_ObjectiveMatchManager','TearDown'),function()
        records={}
        for _,ps in ipairs(S.players()) do
            if S.waiter(ps) then ps.WantsToSpectate=false;ps.GrantExpForThisRound=true end
        end
        waiters={}
    end)
    R.on('world_end',function() waiters={} end)
end
