-- Two cauldron rules of a Fill a Pot+ match (the host's): the time a filled cauldron adds to the
-- round (the game's own adds 2 minutes: the rule adds or takes the difference), and a witch
-- power-up over a cauldron when a witch first finds out which prop it wants.
return function(S)
    local R,C=S.R,S.C
    local GAME=120
    S.onMatchHost.post(S.path(S.O,'B_ObjectiveGameState','OnCauldronFilledMulti'),function()
        local change=(tonumber(S.rules().potTime) or GAME)-GAME
        C.state('FillAPotPlus','Filled cauldron time',change==0 and 'the game\'s own 2 minutes' or ('%+d s from the rule'):format(change))
        if change==0 then return end
        local gm=C.session().gm
        local before=gm.TimerRemainingSeconds
        gm.TimerRemainingSeconds=math.max(1,before+change)
        S.log('Filled cauldron: timer %.0f -> %.0f s',before,gm.TimerRemainingSeconds)
    end)
    -- A witch scouts a cauldron by standing in its circle: the cauldron then becomes active and
    -- picks the prop it wants (again after each fill).
    S.onMatchHost.post(S.path(S.O,'B_ObjectiveCauldron','GenerateNewWantedProp'),function(pot)
        C.state('FillAPotPlus','Scout power-up',not S.rules().scoutPowerup and 'off - the rule is off' or 'on')
        if not S.rules().scoutPowerup or not pot.Active then return end
        local s=C.session()
        -- As the game's own drops: only while power-ups drop and only the kinds the rules enable.
        if not C.subsystem('match').GlobalMatchParameters.EnableBuffDrops then C.state('FillAPotPlus','Scout power-up','no power-up - power-up drops are off in the match rules');return end
        local powerups=C.subsystem('powerups')
        local kinds={}
        for _,kind in ipairs(S.values(s.gm.AllowedWitchPickups)) do
            local found={};powerups:GetPowerupParameters(kind:GetCDO().PowerupRuleType,found)
            if found.PowerupParameters.IsEnabled then kinds[#kinds+1]=kind end
        end
        if #kinds==0 then C.state('FillAPotPlus','Scout power-up','no power-up - every witch power-up is disabled in the rules');return end
        C.state('FillAPotPlus','Scout power-up','on')
        -- (over the cauldron: always in reach, never in a wall beside it)
        local at=pot:K2_GetActorLocation()
        R.native.spawn(kinds[math.random(#kinds)],s.gm,{X=at.X,Y=at.Y,Z=at.Z+150})
        S.log('Scouted cauldron: a power-up over it')
    end)
end
