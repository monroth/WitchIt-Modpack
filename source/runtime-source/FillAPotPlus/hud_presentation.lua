-- Host rules and waiting text; guests display the same facts, including late joins.
return function(S)
    local R,C=S.R,S.C
    local policy,remote
    local function reason(gs,mm,rules)
        if not rules.uncapped and not rules.startReady then return end
        if S.round()>0 and gs.State~=0 then return '' end
        local count,a,b,unselected,unready=0,0,0,false,false
        for _,ps in ipairs(S.players()) do
            if not ps.IsPendingDisconnect and not S.waiter(ps) then
                count=count+1
                if S.team(ps)==1 then a=a+1 elseif S.team(ps)==2 then b=b+1 else unselected=true end
                local ready=S.round()==0 and ps.IsReadyObjectiveTeamSelection or S.round()>0 and ps.IsReady
                if not ready then unready=true end
            end
        end
        if count==0 then return 'Waiting for players' end
        if unselected and S.round()==0 and not rules.startReady then return 'Waiting for players to choose a team' end
        local n=rules.uncapped and S.required() or 1
        if a<n or b<n then return n>1 and ('Waiting for '..n..' players on each team') or 'Waiting for a player on each team' end
        return unready and 'Waiting for ready players' or 'Starting match'
    end
    function S.hudPolicy() return S.host() and policy or remote end
    function S.updateHUDPolicy()
        if not S.host() then return end
        local gs,mm,rules=C.session().gs,S.manager(),S.rules()
        local ceiling=S.ceiling or gs.CauldronTarget
        if policy and S.shownRound()==2 then ceiling=math.max(ceiling,policy.ceiling) end
        -- The filled cauldrons' colours, in fill order: a guest's game calls nothing when the
        -- replicated list changes, so guests draw the progress bar from this message.
        local filled={}
        for i,c in ipairs(S.values(gs.FilledCauldronColors)) do filled[i]={R=c.R,G=c.G,B=c.B} end
        local wanted={round=S.shownRound(),infinite=S.infinite(rules),
            reason=reason(gs,mm,rules),ceiling=ceiling,target=gs.CauldronTarget,filled=filled}
        if policy then
            local same=#policy.filled==#filled
            for _,key in ipairs({'round','infinite','reason','ceiling','target'}) do
                if policy[key]~=wanted[key] then same=false end
            end
            for i,c in ipairs(filled) do
                local o=policy.filled[i]
                if not o or o.R~=c.R or o.G~=c.G or o.B~=c.B then same=false end
            end
            if same then return end
        end
        C.state('FillAPotPlus','HUD waiting text',wanted.reason==nil and 'the game\'s own' or wanted.reason=='' and 'none (match running)' or wanted.reason)
        policy=wanted;C.net.publish('fap.hud',policy)
    end
    C.net.watch('fap.hud',function(value)
        if not C.mods.host_mode() then return end   -- (a guest's only: the host never takes its own - see voting.lua)
        remote=value;S.refreshHUD()
    end)
    R.on('world_end',function() policy=nil;remote=nil end)
end
