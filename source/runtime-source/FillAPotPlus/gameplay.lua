return function(S)
    local R,C=S.R,S.C
    local O=S.O
    -- The lives a witch starts a half with (rejoin.lua): the match's rule.
    function S.halfLives(witch)
        if not witch then return 0 end
        local lives=S.rules().lives;return lives=='infinite' and S.INFINITE_LIVES or lives
    end
    -- With a choice of sides, team 1 is the witch side of the first round.
    S.onMatchHost.post(S.path(O,'B_ObjectiveMatchManager','RandomizeTeamAStartsAsWitch'),function(mm)
        C.state('FillAPotPlus','Side choice',S.rules().roleChoice and 'on - team 1 starts as witches' or 'off - the game picks who starts as witches')
        if S.rules().roleChoice then mm.TeamAStartsAsWitch=true end
    end)
    function S.applyGameplay()
        local session=C.session()
        local gm,gs,mm=session.gm,session.gs,S.manager()
        local rules=S.rules()
        C.state('FillAPotPlus','Team requirement',(rules.uncapped or rules.startReady) and ('the mode checks the teams itself (uncapped %s, start when ready %s)'):format(tostring(rules.uncapped),tostring(rules.startReady)) or 'the game\'s own')
        if rules.uncapped or rules.startReady then
            mm.IgnorePlayersPerTeamRequirement=true;mm.RequiredPlayersPerTeam=1000000
            -- (what the players' games read: the team screen's text, and their pause menu, which offers
            -- surrender only above 1 per team)
            C.replicate(gs,'RequiredPlayersPerTeam',S.required(),S.REP.state.REQUIRED_PLAYERS_PER_TEAM)
            if S.round()==0 then gm:TimerStop() end
        end
        S.allowSkills()
        gm.JoinAsHunter=false
        gm.SpectatorPawn=S.asset(S.path(O,'B_ObjectiveSpectator'))
        C.replicate(gs,'MaxLives',S.infinite(rules) and 0 or math.min(S.HEARTS,rules.lives),S.REP.state.MAX_LIVES)
        gs:OnRep_MaxLives()
    end
    -- Play only one round: the end of the first round is the end of the match (the game then
    -- starts a new match: team selection, the map vote).
    S.onMatchHost.pre(S.path(O,'B_ObjectiveGameMode','HandleEndMatchOverride'),function()
        local mm=S.manager()
        C.state('FillAPotPlus','Single round',not S.rules().single and 'off - two rounds' or S.round()~=1 and 'on - the match is already over' or 'on - the first round ends the match')
        if not S.rules().single or S.round()~=1 then return end
        mm.IsMatchOver=true
        -- (players' screens show the match result, not the halftime one, by the game state's round;
        -- the match manager keeps round 1 so the round's winner maps to its team)
        C.replicate(C.session().gs,'CurrentRound',2,S.REP.state.CURRENT_ROUND)
    end)
    for _,method in ipairs({'EnsureInitialize','InitializeOverride','ReceiveBeginPlay','UpdateCustomGameMatchOptions'}) do
        S.onMatchHost.post(S.path(O,'B_ObjectiveGameMode',method),S.applyGameplay)
    end
    -- Everyone (present: not waiting, not leaving if asked) has the property, and someone is there;
    -- player id 0 need not have it when asked (the game's own ready check leaves it out).
    local function ready(property,skipDisconnected,exceptId0)
        local count=0
        for _,ps in ipairs(S.players()) do
            if not S.waiter(ps) and (not skipDisconnected or not ps.IsPendingDisconnect) then
                count=count+1
                if not ps[property] and not (exceptId0 and ps:GetPlayerId()==0) then return false end
            end
        end
        return count>0
    end
    -- Players per team the match needs (the host's Required Players per Team; 0, an empty team,
    -- only with Uncapped teams).
    function S.required()
        local rules=S.rules()
        local options=C.options()
        return math.max(rules.uncapped and 0 or 1,math.tointeger(options.RequiredPlayersPerTeam) or 0)
    end
    -- Where the game's own team check is off (Uncapped teams, or No timer: see applyGameplay) the
    -- mode checks the teams itself: each team has the required players (Uncapped: at least them),
    -- and someone is there (a player with no team is put in one as the match starts).
    S.onMatchHost.post(S.path(O,'B_ObjectiveGameMode','IsPlayerTeamSelectionBalanced'),function(gm,_,out)
        local rules=S.rules()
        if not rules.uncapped and not rules.startReady then
            C.state('FAP','Team check',out:get() and 'passes' or ('refuses - the game\'s own check, needed %s per team'):format(tostring(C.options().RequiredPlayersPerTeam)))
            return
        end
        local count,a,b=0,0,0
        for _,ps in ipairs(S.players()) do
            if not ps.IsPendingDisconnect then
                count=count+1
                if S.team(ps)==1 then a=a+1 elseif S.team(ps)==2 then b=b+1 end
            end
        end
        local n=S.required()
        local ok
        if rules.uncapped then ok=count>0 and a>=n and b>=n else ok=a==n and b==n end
        out:set(ok)
        -- (live 11-20 two witches on one side could not start, after a new start from the menu they could:
        -- why a start is refused, told when it changes)
        C.state('FAP','Team check',ok and 'passes' or ('refuses - teams %d / %d, needed %d per team, uncapped %s, start when ready %s'):format(a,b,n,
            tostring(rules.uncapped),tostring(rules.startReady)))
    end)
    S.onMatchHost.post(S.path(O,'B_ObjectiveGameMode','AreAllPlayersReadyWithTeamSelection'),function(gm,out)
        local all=ready('IsReadyObjectiveTeamSelection',S.rules().startReady)
        C.state('FillAPotPlus','Team selection ready check',all and 'everyone is ready' or 'waiting for a player to be ready (or nobody is present)')
        out:set(all)
    end)
    S.onMatchHost.post(S.path(S.CORE,'B_GameMode','CheckIfAllPlayersAreReady'),function(gm,out)
        local all=ready('IsReady',true,not S.rules().startReady)
        C.state('FillAPotPlus','Start ready check',all and 'everyone is ready' or 'waiting for a player to be ready (or nobody is present)')
        out:set(all)
    end)
    S.onMatchHost.post(S.path(S.CORE,'B_GameMode','RandomizeTeamSelection'),function(gm)
        if not S.rules().uncapped and not S.rules().startReady then return end
        for _,ps in ipairs(S.players()) do
            if not ps.IsPendingDisconnect then
                if S.team(ps)==0 then
                    C.replicate(ps,'Team',2,S.REP.player.TEAM);C.replicate(ps,'SelectedTeam',2,S.REP.player.SELECTED_TEAM)
                    ps.IsWitchTeam=false
                else ps:SetTeamByRoundAndObjectiveTeam() end
            end
        end
    end)
    S.onMatchHost.post(S.path(O,'B_ObjectiveGameMode','HandleStartMatchOverride'),function(gm)
        S.applyGameplay()
        local lives=S.halfLives(true)
        for _,ps in ipairs(S.players()) do
            if C.side(ps)=='witch' and not ps.IsPendingDisconnect and not S.waiter(ps) then
                C.replicate(ps,'Lives',lives,S.REP.player.LIVES);ps.ObjectiveMatchPlayerState.Lives=lives
            end
        end
    end)
    S.onMatchHost.post(S.path(O,'B_ObjectiveGameMode','CheckWitchesAlive'),function(gm,out)
        C.state('FillAPotPlus','Infinite lives',not S.infinite() and 'off - the lives rule is a number' or 'on - witches never run out')
        if not S.infinite() then return end
        local alive=false
        for _,ps in ipairs(S.players()) do
            -- (the witch TEAM, dead witches too - a death changes Team, not IsWitchTeam, which the host keeps right:
            -- C.side is the side a player plays now; audit 11-20, read through C.side a dead witch was left out)
            if ps.IsWitchTeam and not ps.IsPendingDisconnect and not S.waiter(ps) then
                C.replicate(ps,'Lives',S.INFINITE_LIVES,S.REP.player.LIVES);ps.ObjectiveMatchPlayerState.Lives=S.INFINITE_LIVES;alive=true
            end
        end
        if alive then out:set(true) end
    end)
    S.onMatchHost.post(S.path(O,'B_ObjectiveGameMode','GetTotalWitchesLives'),function(gm,out)
        if S.infinite() then out:set(0) end
    end)
    S.onMatchHost.post(S.path(S.CORE,'B_GameMode','CanJoinAsMidgameHunter'),function(gm,out)
        out:set(false)
    end)
    for _,method in ipairs({'ReceivePossessed','HandleClientProcessed'}) do
        S.onMatchHost.post(S.path(O,'B_ObjectiveKillSpectator',method),function(pawn)
            local timer=StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')
            local exists=timer:K2_TimerExists(pawn,'TimerFinished')
            S.log('Respawn wait %s: %s',method,exists and (S.rules().respawn..' s') or 'native timer not set yet')
            if exists then
                timer:K2_ClearTimer(pawn,'TimerFinished')
                if S.rules().respawn==0 then timer:K2_SetTimerForNextTick(pawn,'TimerFinished')
                else timer:K2_SetTimer(pawn,'TimerFinished',S.rules().respawn,false,false,0,0) end
            end
        end)
    end
    local groups,pending,filled={},{},{}
    local onCauldron=false
    local function destroy(p) p:SetActorEnableCollision(false);p:K2_DestroyActor() end
    local function totem(transform)
        local g=StaticFindObject('/Script/Engine.Default__GameplayStatics')
        local p=g:BeginDeferredActorSpawnFromClass(C.session().gm,S.asset(S.path(O,'B_ReviveTotem')),transform,0,nil,0)
        p.WitchInCircleTimeNeeded=S.rules().revive
        g:FinishSpawningActor(p,transform,0)
        return R.valid(p) and not p:IsActorBeingDestroyed() and p or nil
    end
    S.onMatchHost.post(S.path(O,'B_ReviveTotem','ReceiveBeginPlay'),function(p)
        -- A filled cauldron's totem stands on the cauldron, not on ground beside it.
        if not onCauldron and not S.groundTotem(p) then return end
        p.WitchInCircleTimeNeeded=S.rules().revive;pending[#pending+1]=p
    end)
    S.onMatchHost.post(S.path(O,'B_ObjectiveGameMode','SpawnReviveTotem'),function(gm,ps)
        if not R.valid(ps) then return end
        local native=pending;pending={}
        local count=S.rules().totems
        local points={}
        if count==1 then points=native else for _,p in ipairs(native) do destroy(p) end end
        if count>1 then
            local starts=S.values(gm.AllWitchRespawnPoints)
            for i=#starts,2,-1 do local j=math.random(i);starts[i],starts[j]=starts[j],starts[i] end
            for i=1,math.min(count,#starts) do points[#points+1]=totem(starts[i]:GetTransform()) end
            pending={}
        end
        groups[ps:GetAddress()]={owner=ps,points=points}
        S.log('Revive totems for %s: %d (native %d)',S.text(ps:GetPlayerName()),#points,#native)
        if count==0 and not S.rules().filledRevive then C.session().gs:ResetReviveHelpServer() end
    end)
    function S.reviveChanged(ps)
        S.log('%s %s',S.text(ps:GetPlayerName()),C.dead(ps) and 'died' or 'alive')
        if C.dead(ps) then S.filledCircles();return end
        local firing,spent,owner
        for key,group in pairs(groups) do
            for _,p in ipairs(group.points) do if p.RespawningState==ps then firing=p;spent=key end end
        end
        if spent then
            S.log('Revived on a totem: %s',S.text(ps:GetPlayerName()))
            local group=groups[spent];groups[spent]=nil;owner=group.owner
            for _,p in ipairs(group.points) do if p~=firing then destroy(p) end end
        end
        local own=groups[ps:GetAddress()]
        if own then
            groups[ps:GetAddress()]=nil
            if owner and owner~=ps and C.dead(owner) then
                own.owner=owner;groups[owner:GetAddress()]=own
            else for _,p in ipairs(own.points) do destroy(p) end end
        end
        for key,p in pairs(filled) do if p.RespawningState==ps then filled[key]=nil end end
        S.filledCircles()
    end
    S.onMatchHost.post(S.path(O,'B_ObjectivePlayerState','OnRep_IsDead'),S.reviveChanged)
    function S.filledCircles()
        if not S.rules().filledRevive then return end
        local dead=false
        for _,ps in ipairs(S.players()) do if C.dead(ps) and not ps.IsPendingDisconnect and not S.waiter(ps) then dead=true end end
        if not dead then
            for key,p in pairs(filled) do destroy(p);filled[key]=nil end
            return
        end
        for _,pot in ipairs(S.values(C.session().gs.Cauldrons)) do
            if pot.Filled and not filled[pot:GetAddress()] then
                onCauldron=true
                local p=totem(pot:GetTransform());filled[pot:GetAddress()]=p;pending={}
                onCauldron=false
                S.log('Revive totem on a filled cauldron: %s',p and 'placed' or 'no ground')
                if p then
                    -- The cauldron's origin is inside it; the totem stands, turned like the cauldron,
                    -- on what a ray along the cauldron's up axis meets.
                    local c,u=pot:K2_GetActorLocation(),pot:GetActorUpVector()
                    local function along(d) return {X=c.X+u.X*d,Y=c.Y+u.Y*d,Z=c.Z+u.Z*d} end
                    local hit=R.native.capsule_probe(p,p,along(250),along(-50),1,1)
                    if hit.blocked then
                        local h=hit.position
                        p.RootComponent:SetMobility(2)
                        p:K2_TeleportTo({X=h.X+u.X*80,Y=h.Y+u.Y*80,Z=h.Z+u.Z*80},pot:K2_GetActorRotation())
                    end
                end
            end
        end
    end
    S.onMatchHost.post(S.path(O,'B_ObjectiveCauldron','ActivateLightMulti'),S.filledCircles)
    R.on('world_end',function() groups={};pending={};filled={} end)
end
