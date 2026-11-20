return function(S)
    local R,C=S.R,S.C
    local preview
    local witch='/Game/Blueprints/Player/Pawns/B_Witch.B_Witch_C'
    local propPawn='/Game/Blueprints/Player/Pawns/B_PropPawnPhysics.B_PropPawnPhysics_C'
    local function now() return StaticFindObject('/Script/Engine.Default__GameplayStatics'):GetTimeSeconds(C.session().world) end
    local function draw(p)
        local actor=p.native
        actor.Stacks=p.stacks;actor.Active=p.active;actor.Filled=p.stacks==2
        actor.WantedProp=p.active and p.wanted and p.wanted.class or nil
        actor.VisualCirclelFill=p.active and 1 or p.progress/4
        actor.WitchInCircleTime=p.active and 4 or p.progress
        actor.DecalMaterial:SetScalarParameterValue(FName('Fill'),actor.VisualCirclelFill)
        actor.RuneRays:SetScalarParameterValueOnMaterials(FName('Fill'),actor.VisualCirclelFill)
        actor.Fluid.RelativeLocation.Z=-90+45*p.stacks
        actor.Fluid:SetAbsolute(true,false,false);actor.Fluid:SetAbsolute(false,false,false)
        actor:OnRep_Stacks()
        if p.active then actor:UpdateWantedPropMulti() end
        if p.stacks==2 then actor:ActivateLightMulti() end
        p.ui.WB_CauldronFillstate.Stacks=p.stacks
    end
    local function assign(s,p)
        local used={}
        for _,other in ipairs(s.pots) do if other.wanted then used[other.wanted.path]=true end end
        local candidates={}
        for _,group in ipairs(p.pool) do
            if not used[group.path] and group.path~=p.last then candidates[#candidates+1]=group end
        end
        p.wanted=#candidates>0 and candidates[math.random(#candidates)] or nil
    end
    local function feedback(s)
        local pawn=s.pc:K2_GetPawn()
        local position=pawn:K2_GetActorLocation()
        local own=pawn:IsA(propPawn) and pawn.ControllingProp or nil
        local closest=4000000
        for _,p in ipairs(s.pots) do
            if p.active and p.wanted then
                for _,prop in ipairs(p.wanted.props) do
                    if R.valid(prop.actor) and S.freeProp(prop.actor,own) then closest=math.min(closest,S.distance(position,prop.actor:K2_GetActorLocation())) end
                end
            end
        end
        if s.orb then s.orb.Percentage=S.calc.closePercent(closest,4000000) end
    end
    local function returnWitch(s,delivery)
        local pawn,prop=delivery.pawn,delivery.prop
        if R.valid(prop) then prop:SetActorHiddenInGame(delivery.hidden) end
        if R.valid(pawn) then
            pawn.IsRespawn=delivery.respawn;pawn:SetActorHiddenInGame(false);pawn:SetActorEnableCollision(true)
            if s.pc.CurrentPlayMode==3 then
                s.pc:Possess(pawn)
                local t=delivery.transform
                for _,point in ipairs(s.starts) do
                    local destination=S.ground(point.actor)
                    if destination then t=S.transform(point.actor,destination.witch);break end
                end
                pawn:SetWitch(t)
            else pawn:MultiSwitchBack() end
            pawn:K2_DestroyActor()
        elseif s.pc.CurrentPlayMode==3 then s.pc:RespawnPlayerPawnServer(0) end
        delivery.camera:K2_DestroyActor();s.delivery=nil
    end
    local function deliver(s,p,other)
        if s.delivery or not p.active or not p.wanted or p.stacks==2 then return end
        local pawn=s.pc:K2_GetPawn()
        if not pawn:IsA(propPawn) then return end
        local prop=pawn.ControllingProp
        if prop:GetAddress()~=other:GetAddress() or not prop.IsControlledByWitch or prop:GetClass():GetAddress()~=p.wanted.class:GetAddress() then return end
        local d={pawn=pawn,prop=prop,hidden=prop.bHidden,respawn=pawn.IsRespawn,transform=pawn:GetTransform()}
        d.camera=R.native.spawn(S.path(S.O,'B_CauldronPawn'),s.pc,p.position,function(a)
            a.Instigator=pawn;a:SetReplicates(false);a:SetActorEnableCollision(false)
        end)
        s.delivery=d
        pawn.IsRespawn=false;pawn:OnKilledMulti();pawn:SetActorHiddenInGame(true);pawn:SetActorEnableCollision(false)
        prop:SetActorHiddenInGame(true);s.pc:Possess(d.camera)
        d.cancel=R.after(3000,function() returnWitch(s,d) end)
        p.last=p.wanted.path;p.wanted=nil;p.active=false;p.progress=0;p.at=now();p.stacks=p.stacks+1
        if p.cancel then p.cancel();p.cancel=nil end
        p.native:ResetUIMulti()
        if p.stacks<2 then assign(s,p) end
        draw(p);feedback(s)
    end
    local function settle(p)
        local time=now()
        p.progress=math.max(0,math.min(4,p.progress+(time-p.at)*(p.count>0 and p.count or -1)))
        p.at=time
    end
    local function schedule(s,p)
        if p.cancel then p.cancel();p.cancel=nil end
        if p.active or p.stacks==2 or not p.wanted or p.count==0 then return end
        p.cancel=R.after(math.max(1,math.ceil((4-p.progress)/p.count*1000)),function()
            p.cancel=nil;settle(p);p.progress=4;p.active=true;draw(p);feedback(s)
            local pawn=s.pc:K2_GetPawn()
            if pawn:IsA(propPawn) then
                local prop=pawn.ControllingProp
                if R.valid(prop) and p.native.PropCheckSphere:IsOverlappingActor(prop) then deliver(s,p,prop) end
            end
        end)
    end
    function S.stopPreview()
        local s=preview
        if not s then return end
        preview=nil
        for _,p in ipairs(s.pots) do if p.cancel then p.cancel() end end
        if s.delivery then s.delivery.cancel();returnWitch(s,s.delivery) end
        for _,actor in ipairs(s.actors) do actor:K2_DestroyActor() end
        for _,row in ipairs(s.markers) do if R.valid(row.actor) then row.actor:SetActorHiddenInGame(row.hidden) end end
        if s.overlay then s.overlay:RemoveFromParent() end
    end
    function S.startPreview()
        if preview then return end
        local session=C.session()
        local _,_,pots,starts=S.checkMap()
        local s={pc=session.pc,pots=pots,starts=starts,actors={},markers={},byPot={}}
        -- (no cauldron: not a Fill a Pot map - nothing of it, user 11-20: its screen covered the Playtest of
        -- other modes, and its markers stay as they were placed)
        if #pots==0 then preview=s;return end
        -- A cauldron's marker gives its place to the game's cauldron made there (out of sight with the actors
        -- of its look); every other marker stays as placed (user 11-20: nothing invisible in Playtest - the
        -- respawn points' ghosts were hidden since 11-12, unasked).
        for _,row in ipairs(S.markers()) do if row.info.kind==1 then
            local attached={};row.actor:GetAttachedActors(attached,true,true)
            local actors={row.actor}
            for _,w in ipairs(attached) do actors[#actors+1]=type(w)=='userdata' and w.get and w:get() or w end
            for _,a in ipairs(actors) do
                if R.valid(a) then s.markers[#s.markers+1]={actor=a,hidden=a.bHidden};a:SetActorHiddenInGame(true) end
            end
        end end
        preview=s
        local create=StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary')
        s.overlay=create:Create(s.pc,S.asset('/Game/UserInterface/UIElements/WB_TooltipTextContent.WB_TooltipTextContent_C'),s.pc)
        local canvas=S.new('/Script/UMG.CanvasPanel',s.overlay.WidgetTree);s.overlay.WidgetTree.RootWidget=canvas
        if S.rules().divinationOrb~=false then   -- (not with the orb switched off by its rule)
            s.orb=create:Create(s.pc,S.asset('/Game/UserInterface/ObjectiveMode/WB_DivineOrb.WB_DivineOrb_C'),s.pc)
            local slot=canvas:AddChildToCanvas(s.orb)
            slot:SetAnchors({Minimum={X=1,Y=1},Maximum={X=1,Y=1}});slot:SetAlignment({X=.5,Y=1})
            slot:SetPosition({X=-140,Y=-175});slot:SetSize({X=96,Y=96})
            s.orb:SetVisibility(4);s.orb.Percentage=0
        end
        s.overlay:AddToViewport(1000);s.overlay:SetAnchorsInViewport({Minimum={X=0,Y=0},Maximum={X=1,Y=1}})
        s.overlay:SetVisibility(4)
        for _,p in ipairs(pots) do
            p.progress=0;p.count=0;p.at=now();p.stacks=0;p.witches={};p.active=false
            -- The game's cauldron, solid as in a match; its own circle and prop spheres tell this
            -- preview who comes (their events, below), instead of the match's logic.
            p.native=R.native.spawn(S.path(S.O,'B_ObjectiveCauldron'),s.pc,p.position,function(a)
                a.Color=p.info.colour;a.MaxStacks=2;a:SetReplicates(false);a:SetActorTickEnabled(false)
                s.byPot[a:GetAddress()]=p   -- (its spheres can meet a witch as it comes)
            end)
            p.native:SetActorTickEnabled(false)
            s.actors[#s.actors+1]=p.native
            p.ui=create:Create(s.pc,S.asset('/Game/UserInterface/ObjectiveMode/WB_CauldronUI.WB_CauldronUI_C'),s.pc)
            p.native.Widget:SetWidget(p.ui);p.native.Widget:SetOwnerPlayer(s.pc.Player)
            local colour={SpecifiedColor=p.info.colour,ColorUseRule=0}
            p.ui.Cauldron=p.native;p.ui.Color=colour;p.ui.Team=s.pc.PlayerState.Team
            p.ui.WB_RequiredPropIcon.Cauldron=p.native;p.ui.WB_RequiredPropIcon.Color=colour
            S.potAppearance(p.native,p.info)
            p.actor:SetActorHiddenInGame(true)
            assign(s,p)
            draw(p)
        end
    end
    -- The preview cauldrons' own overlap events: a witch in the circle, a prop at the cauldron.
    -- (The game calls them past a PRE hook; their match logic finds no match in Creative.)
    local CAULDRON=S.path(S.O,'B_ObjectiveCauldron')..':BndEvt__'
    local function circle(begin)
        return function(pot,_,other)
            local p=preview and preview.byPot[pot:GetAddress()]
            if not p then return end
            if R.valid(other) and other:IsA(witch) then
                settle(p);p.witches[other:GetAddress()]=begin and true or nil
                p.count=0;for _ in pairs(p.witches) do p.count=p.count+1 end
                schedule(preview,p);draw(p);feedback(preview)
            end
        end
    end
    S.onModeHost.post(CAULDRON..'WitchCheckSphere_K2Node_ComponentBoundEvent_1_ComponentBeginOverlapSignature__DelegateSignature',circle(true))
    S.onModeHost.post(CAULDRON..'WitchCheckSphere_K2Node_ComponentBoundEvent_2_ComponentEndOverlapSignature__DelegateSignature',circle(false))
    S.onModeHost.post(CAULDRON..'CheckSphere_K2Node_ComponentBoundEvent_0_ComponentBeginOverlapSignature__DelegateSignature',function(pot,_,other)
        local p=preview and preview.byPot[pot:GetAddress()]
        if not p then return end
        if R.valid(other) then deliver(preview,p,other) end
    end)
    S.onModeHost.post(S.path(S.CR,'B_CreativePlayerController','ChangePlayerMode'),function(pc)
        if pc.CurrentPlayMode==3 and C.session().gs.IsPlayTestMode then S.startPreview() else S.stopPreview() end
    end)
    S.onModeHost.playtest(function(s) if s.is_playtest and s.pc.CurrentPlayMode==3 then S.startPreview() end end)
    R.pre(S.path(S.CR,'B_CreativeGameMode','EndPlayTest'),S.stopPreview)
    R.on('world_end',function() preview=nil end)
end
