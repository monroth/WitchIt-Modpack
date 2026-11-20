return function(S)
    local R,C=S.R,S.C
    local propPawn='/Game/Blueprints/Player/Pawns/B_PropPawnPhysics.B_PropPawnPhysics_C'
    function S.freeProp(prop,own)
        return prop~=own and not prop.IsControlledByWitch and not R.valid(prop.Witch)
    end
    -- A wanted kind's copies: the game's prop list (a TMap: never replicated, each machine builds
    -- its own when the round loads its props). A guest who rejoins a running round missed that, so
    -- his list lacks the kind or holds no copies: then the world's actors of the kind, found once
    -- (none found yet, while the copies still replicate: looked for again every 2 s).
    local found={}
    local function copies(gs,class)
        if gs.Proplist:Contains(class) then
            local list=S.values(gs.Proplist:Find(class):get()[S.COPIES])
            if #list>0 then return list end
        end
        local key,now=class:GetAddress(),os.clock()
        local f=found[key]
        if not f or #f.list==0 and now-f.at>2 then f={list=R.find_all(S.classpath(class)),at=now};found[key]=f end
        return f.list
    end
    local hidden={}   -- an orb hidden by the rule (address) -> its own visibility
    R.on('world_end',function() found,hidden={},{} end)
    S.onMatch.post('/Game/UserInterface/ObjectiveMode/WB_ObjectiveHudExtension.WB_ObjectiveHudExtension_C:GetPropClosePercent',function(widget)
        -- (the orb's range is a rule: Prop indicator range)
        local range=(S.rules().propIndicator or 20)*100
        if widget.MaxDistanceSq~=range*range then widget.MaxDistanceSq=range*range end
        local pawn=R.valid(widget:GetOwningPlayerPawn())
        if not pawn then return 0 end
        local own=pawn:IsA(propPawn) and pawn.ControllingProp or nil
        local origin=pawn:K2_GetActorLocation()
        local maximum=widget.MaxDistanceSq
        local closest=maximum
        -- (and every free wanted prop near enough for the wisps: indicator.lua)
        local near,reach={},((S.rules().propSparksFrom or 6)*100)^2
        local gs=C.session().gs
        for _,pot in ipairs(S.values(gs.Cauldrons)) do
            local class=pot.WantedProp
            if pot.Active and not pot.Filled and R.valid(class) then
                for _,actor in ipairs(copies(gs,class)) do
                    if R.valid(actor) and S.freeProp(actor,own) then
                        local d=S.distance(origin,actor:K2_GetActorLocation())
                        closest=math.min(closest,d)
                        if d<reach then near[#near+1]={prop=actor,d=math.sqrt(d)} end
                    end
                end
            end
        end
        S.indicate(pawn,near)
        -- (the orb switched off by the rule: not on the screen at all, user 11-20; the sparks are their own rule)
        local orb=R.valid(widget.WB_DivineOrb)
        C.state('FillAPotPlus','Divination Orb',S.rules().divinationOrb==false and 'hidden - the rule is off' or 'shown')
        if S.rules().divinationOrb==false then
            if orb and orb:GetVisibility()~=1 then hidden[orb:GetAddress()]=orb:GetVisibility();orb:SetVisibility(1) end
            return 0
        end
        if orb and hidden[orb:GetAddress()] then orb:SetVisibility(hidden[orb:GetAddress()]);hidden[orb:GetAddress()]=nil end
        return 1-math.sqrt(closest/maximum)
    end)
end
