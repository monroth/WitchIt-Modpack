return function(S)
    local R,C=S.R,S.C
    local originals={}
    local pawn='/Game/Blueprints/Player/Pawns/B_PropPawnPhysics.B_PropPawnPhysics_C:'
    local function capture(body)
        local prop=R.valid(body.ControllingProp)
        if not prop or prop:GetAddress()~=body.PropTemplate:GetAddress() or prop.IsDecoy or prop.SpawnedFromPropPawnPhysics then return end
        local key=prop:GetAddress()
        if originals[key] then originals[key].active=true;return end
        local p,r,scale=prop:K2_GetActorLocation(),prop:K2_GetActorRotation(),prop:GetActorScale3D()
        originals[key]={active=true,class=prop:GetClass(),pose={X=p.X,Y=p.Y,Z=p.Z,Pitch=r.Pitch,Yaw=r.Yaw,Roll=r.Roll,
            ScaleX=scale.X,ScaleY=scale.Y,ScaleZ=scale.Z},
            frozen=prop.IsFreezed,awake=prop.StartAwake,sleeping=prop.IsSleeping}
    end
    S.onMatchHost.post(pawn..'OnRep_ControllingProp',capture)
    S.onMatchHost.post(pawn..'PropPossessed',capture)
    -- The engine end-play hook is global; restoring a prop belongs to a hosted Plus match.
    RegisterEndPlayPreHook(function(actor,reason)
        actor=R.valid(actor)
        if not actor then return end
        reason=reason:get()
        local key=actor:GetAddress()
        local original=originals[key];originals[key]=nil
        if not original or not original.active or reason~=0 or not S.inMatch() or not S.host() then return end
        local gs=C.session().gs
        R.next_frame(function()
            local prop=R.native.spawn(original.class,C.session().gm,original.pose,function(a)
                a:SetReplicates(true);a.bAlwaysRelevant=true;a.NetDormancy=1
                a.SpawnedFromPropPawnPhysics=false
                a.IsFreezed=original.frozen;a.StartAwake=original.awake;a.InitialIsSleeping=original.sleeping
            end)
            prop:SetUncontrolledByWitch()
            prop.IsFreezed=original.frozen;prop.StartAwake=original.awake
            prop:AutoSetInitialPhysicsState()
            if original.sleeping then prop:PutToSleep();prop:HandleSleepServer()
            else prop:WakeFromSleep();prop:HandleWakeServer() end
            if original.frozen then prop:UpdateFromFrozenState() end
            prop:FlushNetDormancy();prop:ForceNetUpdate()
            prop.AliveTime=0;prop.IsFadingIn=true;prop:SetActorTickEnabled(true)
            -- The game's lists of props: the new one where the old one was, or at the end once the
            -- game has taken the old one out (the lists change between the two frames).
            local function put(array)
                local at
                array:ForEach(function(i,value)
                    local old=value:get()
                    if not R.valid(old) or old:GetAddress()==key then at=at or i end
                end)
                array[at or array:GetArrayNum()+1]=prop
            end
            put(gs.AllProps)
            -- (a kind the game's prop list does not hold - not every placed kind is in it - has no copies
            -- list to join: live host 11-20, "Map key not found" stopped the rest)
            if gs.Proplist:Contains(original.class) then put(gs.Proplist:Find(original.class):get()[S.COPIES]) end
            original.active=false;originals[prop:GetAddress()]=original
        end)
    end)
    R.on('world_end',function() originals={} end)
end
