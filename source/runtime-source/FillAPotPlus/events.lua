-- Native events that several Fill a Pot+ modules react to, and every change of what the HUD shows
-- (S.refreshHUD paints it from the state): written down in one place.
return function(S)
    local R,C=S.R,S.C
    local cauldron=S.path(S.O,'B_ObjectiveCauldron')
    local objectivePlayer=S.path(S.O,'B_ObjectivePlayerState')
    local objectiveState=S.path(S.O,'B_ObjectiveGameState')
    local player='/Game/Blueprints/Player/B_PlayerState.B_PlayerState_C'
    local dirty='/Script/Engine.NetPushModelHelpers:MarkPropertyDirtyFromRepIndex'
    -- Replication indices (facts.lua): cauldron Stacks and Filled are written every tick.
    -- Every replicated field in the game passes here, so the index is compared before anything else.
    local REP=S.REP
    local hostFields={[REP.cauldron.STACKS]=true,[REP.player.IS_DEAD]=true}
    local hudFields={[REP.cauldron.STACKS]=true,[REP.cauldron.FILLED]=true,[REP.state.CAULDRON_TARGET]=true,
        [REP.state.MAX_LIVES]=true,[REP.player.LIVES]=true,[REP.state.FILLED_CAULDRON_COLORS]=true}
    S.onMatchHost.post(dirty,function(_,object,index)
        if not hostFields[index] or not R.valid(object) then return end
        if index==REP.cauldron.STACKS and object:IsA(cauldron) then S.countStacks(object) end
        if index==REP.player.IS_DEAD and object:IsA(objectivePlayer) then S.reviveChanged(object) end
    end)
    S.onMatch.post(dirty,function(_,object,index)
        if not hudFields[index] or not R.valid(object) then return end
        if object:IsA(cauldron) and (index==REP.cauldron.STACKS or index==REP.cauldron.FILLED)
            or object:IsA(objectiveState) and (index==REP.state.CAULDRON_TARGET or index==REP.state.MAX_LIVES or index==REP.state.FILLED_CAULDRON_COLORS)
            or object:IsA(player) and index==REP.player.LIVES then S.refreshHUD() end
    end)
    S.onMatchHost.post(S.path(S.O,'B_ObjectiveMatchManager','TearDown'),S.endMatch)
    -- What the HUD shows changes with these too (a guest learns the replicated fields above from
    -- the game's OnRep calls, and the host's waiting text from its HUD message), and with the
    -- rules, a new round and the session (a guest learns the mode after its HUD exists).
    for class,methods in pairs({
        [objectiveState]={'OnRep_MaxLives','OnGameStartedMulti','OnMatchStartedMulti','OnCauldronFilledMulti','LoadPropsAndCauldrons'},
        [cauldron]={'OnRep_Stacks'},
        [objectivePlayer]={'InitializeFromMatchPlayerState','SetTeamByRoundAndObjectiveTeam','OnRep_IsReadyObjectiveTeamSelection','OnRep_IsDead'},
        [S.path(S.CORE,'B_GameState')]={'OnPlayerJoinedMulti','OnPlayerLeftMulti','OnPlayerChangedTeamMulti'},
        [S.path(S.O,'B_ObjectiveGameMode')]={'StartNewGameOverride'},
        [S.path(S.O,'B_ObjectiveMatchManager')]={'TearDown'},
        ['/Script/Engine.Controller']={'Possess'}}) do
        for _,method in ipairs(methods) do S.onMatch.post(class..':'..method,S.refreshHUD) end
    end
    S.onMatch.on('round_start',S.refreshHUD)
    S.onMatch.session(S.refreshHUD)
    C.rules.on_change(function(pkg) if pkg=='FillAPotPlus' then S.refreshHUD() end end)
end
