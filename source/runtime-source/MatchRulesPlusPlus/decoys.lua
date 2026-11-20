-- Dead witches throw decoys (the Decoy skill's rule here, user 11-20; it was Fill a Pot+'s): a witch
-- killed, while the game shows her death (her body is B_ObjectiveKillSpectator, no skills), uses the
-- witch's two skill keys as a living witch uses the Decoy skill (B_DecoySkill): the movement skill's
-- (ActivateSkill) a running witch decoy in her own outfit, the utility skill's (ActivateUtilitySkill)
-- a prop decoy. As the skill does, while the key is held the decoy goes where she looks (her camera's
-- point, every 0.1 s, as the skill's own Delay 0.1); let go, it is released (CurrentState 2) and the
-- decoy's own blueprint keeps it ActiveTimeAfterRelease, then fades it (user 11-20: a dead witch only
-- started it, a living one steers it). She asks the host, which spawns and moves them (decoys
-- replicate); a cooldown of the rule's from each throw. (Only a killed witch gets that body: hunters
-- are never it.)
return function(M)
    local R,C=M.R,M.C
    local hooks=M.hooks
    local GP=StaticFindObject('/Script/Engine.Default__GameplayStatics')
    local MATH=StaticFindObject('/Script/Engine.Default__KismetMathLibrary')
    local SYSTEM=StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')
    -- (live 11-20: the dead witch's body; the B_ObjectiveSpectator assumed before is the spectators')
    local GHOST='/Game/Blueprints/Gamemodes/ObjectiveMode/B_ObjectiveKillSpectator.B_ObjectiveKillSpectator_C'
    -- (the other modes - Hide and Seek, user 11-20: a killed player watches as the game's plain spectator,
    -- like anyone watching; it counts while the game has the player dead)
    local WATCHER='/Game/Blueprints/Player/Pawns/B_Spectator.B_Spectator_C'
    local DECOY='/Game/Blueprints/Skills/Witch/Decoy/'
    local PC='/Game/Blueprints/Player/B_PlayerController.B_PlayerController_C:'
    local COOLDOWN=8   -- (the cooldown rule's own value: the schema's initial)
    for _,spec in ipairs(M.schema.extras) do if spec.key=='deadDecoyCooldown' then COOLDOWN=spec.initial end end
    local function log(...) R.log('Match Rules ++',...) end
    local function asset(path) return R.native.load_asset(path) end
    local function ghostOf(pc)
        local pawn=R.valid(pc) and R.valid(pc:K2_GetPawn())
        if not pawn then return nil end
        if pawn:IsA(asset(GHOST)) then return pawn end
        local ps=R.valid(pc.PlayerState)
        if ps and ps.IsDead and pawn:IsA(asset(WATCHER)) then return pawn end
    end
    local function cooldown() return M.extras().deadDecoyCooldown or COOLDOWN end
    local function v(x,y,z) return {X=x,Y=y,Z=z} end

    -- ---------------------------------------------------------------- the dead witch (her own game)
    -- Where she looks: her camera's ray to the skill's range, its hit (point, surface normal) or its end.
    local function aim(pc)
        local cam=pc.PlayerCameraManager
        local from,rot=cam:GetCameraLocation(),cam:GetCameraRotation()
        local f=MATH:GetForwardVector(rot)
        local range=asset(DECOY..'B_DecoySkill.B_DecoySkill_C'):GetCDO().DecoyRange
        local to=v(from.X+f.X*range,from.Y+f.Y*range,from.Z+f.Z*range)
        local hit={}
        local c0={R=0,G=0,B=0,A=0}
        if SYSTEM:LineTraceSingle(pc,from,to,0,false,{pc:K2_GetPawn()},0,hit,true,c0,c0,0.0) then
            local p,n=hit.ImpactPoint,hit.ImpactNormal
            return {at=v(p.X,p.Y,p.Z),normal=v(n.X,n.Y,n.Z)}
        end
        return {at=to,normal=v(0,0,1)}
    end
    local held,thrown   -- the kind held now ('witch' / 'prop'); when the last throw began
    -- Her skill bar (user 11-20: as a living witch's): the HUD's two skill slots (WB_HUDSkill) are
    -- given a Decoy skill object each - the slot then draws the game's own Decoy icon, the key under
    -- it as bound (its action icon), greyed with the seconds left while the throw cools down. (A living
    -- pawn puts its own skills there as it is possessed; a dead witch's body puts none.)
    local SKILL=DECOY..'B_DecoySkill.B_DecoySkill_C'
    local icons   -- {movement, utility} skill objects in the slots, or nil
    local function slots()
        local gi=C.session().gi
        local ui=gi and R.valid(gi.IngameUIManager)
        local hud=ui and R.valid(ui.HUDUserWidget)
        return hud and R.valid(hud.MovementSkillIcon),hud and R.valid(hud.UtilitySkillIcon)
    end
    local function left(ghost) return thrown and math.max(0,cooldown()-(GP:GetTimeSeconds(ghost)-thrown)) or 0 end
    -- (the seconds left, while they run: a quarter second at a time, nothing once cooled)
    local ticking=false   -- (one count running at a time)
    local function count()
        ticking=false
        local ghost=icons and ghostOf(R.valid(C.session().pc))
        if not ghost then return end
        local rest=left(ghost)
        for _,skill in ipairs(icons) do if R.valid(skill) then skill.currentCooldown=rest end end
        if rest>0 then ticking=true;R.after(250,count) end
    end
    local function cool() if not ticking then count() end end
    local function hideIcons()
        if not icons then return end
        local mine={};for _,skill in ipairs(icons) do if R.valid(skill) then mine[skill:GetAddress()]=true end end
        for _,slot in ipairs({slots()}) do
            local skill=R.valid(slot.Skill)
            if skill and mine[skill:GetAddress()] then slot.Skill=nil end
        end
        icons=nil
    end
    -- (live 11-20 the host's dead witch threw, but saw no icons, cooldown or steering: each step in the log)
    local function showIcons(ghost)
        local movement,utility=slots()
        log('Decoy icons: movement slot %s, utility slot %s',tostring(movement~=nil),tostring(utility~=nil))
        if not (movement and utility) then return end
        local class=asset(SKILL)
        icons={StaticConstructObject(class,ghost),StaticConstructObject(class,ghost)}
        movement.Skill,utility.Skill=icons[1],icons[2]
        -- (live 11-20 the slots were found and given the skills, yet nothing showed: the HUD hides the skill
        -- bar of a dead player - every widget from the slot up to the HUD is shown, and what was hidden is told)
        local hidden={}
        for _,slot in ipairs({movement,utility}) do
            local w=slot
            while R.valid(w) do
                local vis=w:GetVisibility()
                if vis==1 or vis==2 then hidden[#hidden+1]=w:GetFName():ToString()..'='..vis;w:SetVisibility(3) end
                w=w:GetParent()
            end
        end
        log('Decoy icons shown; hidden before: %s',#hidden>0 and table.concat(hidden,', ') or 'none')
        cool()
    end
    -- Her own possession: a dead witch's body with the rule on shows the slots, anything else not.
    hooks.post('/Script/Engine.PlayerController:ClientRestart',function(pc,pawn)
        if not (R.valid(pc) and pc:IsLocalController()) then return end
        hideIcons()
        if M.extras().deadDecoys and ghostOf(pc) then showIcons(ghostOf(pc)) end
    end)
    -- (a slot's skill can be thrown when it has cooled: the game asks CanActivate to draw it in colour)
    hooks.post('/Game/Blueprints/Skills/B_BaseSkill.B_BaseSkill_C:CanActivate',function(skill)
        if not icons then return end
        for _,mine in ipairs(icons) do
            if R.valid(mine) and mine:GetAddress()==skill:GetAddress() then return (tonumber(mine.currentCooldown) or 0)<=0 end
        end
    end)
    local heldKey   -- the key the throw was pressed with: it is let go when that key is up
    local function release()
        if not held then return end
        log('Decoy released after %.1f s',GP:GetTimeSeconds(R.valid(C.session().pc))-(thrown or 0))
        held=nil
        C.net.request('mrpp.decoy',{release=true})
    end
    -- (while held: the point she looks at, every 0.1 s; her death over, it is let go)
    local function steer()
        if not held then return end
        local pc=R.valid(C.session().pc)
        if not ghostOf(pc) then return release() end
        if not (heldKey and pc:IsInputKeyDown(heldKey)) then return release() end
        local a=aim(pc);a.kind=held
        C.net.request('mrpp.decoy',a)
        R.after(100,steer)
    end
    local function press(kind,key)
        if not M.extras().deadDecoys or held then return end
        local pc=R.valid(C.session().pc)
        local ghost=ghostOf(pc)
        if not ghost then return end
        local now=GP:GetTimeSeconds(ghost)
        if thrown and now-thrown<cooldown() then return end
        thrown,held,heldKey=now,kind,key
        if not icons then showIcons(ghost) else cool() end
        local a=aim(pc);a.kind=kind;a.throw=true
        log('Decoy key: a %s decoy, key %s',kind,key and R.text(key.KeyName) or 'unknown')
        C.net.request('mrpp.decoy',a)
        R.after(100,steer)
    end
    -- (the game's own press events, with the key they came from; the decoy is let go when that key is up,
    -- read while it is steered - live 11-20 the event taken for the release came with the press: let go at once)
    hooks.post(PC..'InpActEvt_ActivateSkill_K2Node_InputActionEvent_4',function(_,key) press('witch',key) end)
    hooks.post(PC..'InpActEvt_ActivateUtilitySkill_K2Node_InputActionEvent_2',function(_,key) press('prop',key) end)
    R.on('world_end',function() held,thrown,icons,ticking=nil,nil,nil,false end)

    -- ---------------------------------------------------------------- the host
    local function spawn(class,ghost,at,yaw,handling,owner,scale)
        local xf=MATH:MakeTransform(at,{Pitch=0,Yaw=yaw,Roll=0},{X=scale,Y=scale,Z=scale})
        local actor=GP:BeginDeferredActorSpawnFromClass(ghost,class,xf,handling,owner,1)
        if not R.valid(actor) then return nil end
        actor.Instigator=ghost
        return actor,xf
    end
    -- Each dead witch's decoy now (player state address -> {decoy, prop, ghost}), and her last throw.
    local live,last={},{}
    -- The point a decoy goes to, as the skill sets it: a witch decoy the point raised by her height
    -- (96 times the player size), a prop decoy the point off the surface by 200.
    local function target(decoy,kind,a)
        if kind=='prop' then
            decoy.TargetLocation=v(a.at.X+a.normal.X*200,a.at.Y+a.normal.Y*200,a.at.Z+a.normal.Z*200)
            C.replicate(decoy,'TargetLocation',nil,11)
        else
            local size=C.subsystem('match',decoy).WitchMatchParameters.PlayerSizeMultiplier
            decoy.TargetLocation=v(a.at.X,a.at.Y,a.at.Z+96*size)
        end
    end
    -- Released: the decoy's own blueprint keeps it ActiveTimeAfterRelease and fades it; the prop made
    -- for a prop decoy goes with it.
    local function letGoOf(key)
        local d=live[key]
        live[key]=nil
        if not (d and R.valid(d.decoy)) then return end
        d.decoy.CurrentState=2
        if d.prop then
            local prop=d.prop
            R.after((d.decoy.ActiveTimeAfterRelease+2)*1000,function() if R.valid(prop) then prop:K2_DestroyActor() end end)
        end
    end
    local function throw(ps,ghost,value)
        local at=ghost:K2_GetActorLocation();local yaw=ghost:K2_GetActorRotation().Yaw
        local d={ghost=ghost:GetAddress(),kind=value.kind}
        if value.kind=='prop' then
            local props={}
            for _,p in ipairs(R.values(C.session().gm.CommonProps)) do props[#props+1]=p end
            local source
            for _=1,15 do local p=R.valid(props[math.random(math.max(1,#props))]);if p then source=p;break end end
            if not source then return end
            local decoy,xf=spawn(asset(DECOY..'B_DecoyProp.B_DecoyProp_C'),ghost,at,yaw,1,ghost,1)
            if not decoy then return end
            decoy=GP:FinishSpawningActor(decoy,xf,2)
            -- (its blueprint makes the prop only for a prop witch's own decoy: made here)
            local prop,pxf=spawn(source:GetClass(),ghost,at,yaw,1,decoy,1)
            if not prop then decoy:K2_DestroyActor();return end
            prop.StartAwake=true;prop.IsFreezed=false;prop.IsPreviewProp=false
            prop=GP:FinishSpawningActor(prop,pxf,2)
            prop:SetActorScale3D(source:GetActorScale3D())
            decoy.Prop=prop;C.replicate(decoy,'Prop',nil,10);decoy:OnRep_Prop()
            d.decoy,d.prop=decoy,prop
        else
            local size=C.subsystem('match',ghost).WitchMatchParameters.PlayerSizeMultiplier
            local decoy,xf=spawn(asset(DECOY..'B_DecoyWitch.B_DecoyWitch_C'),ghost,at,yaw,2,ghost,size)
            if not decoy then return end
            d.decoy=GP:FinishSpawningActor(decoy,xf,1)
        end
        target(d.decoy,d.kind,value)
        live[ps:GetAddress()]=d
        log('Dead witch %s threw a %s decoy',R.text(ps:GetPlayerName()),d.kind)
    end
    local function point(value)
        local function vec(t) return type(t)=='table' and tonumber(t.X) and tonumber(t.Y) and tonumber(t.Z) end
        return vec(value.at) and vec(value.normal)
    end
    -- One request topic: a throw (throw), where she looks while held (at, normal), or the release.
    C.net.on_request('mrpp.decoy',function(ps,value)
        if not (M.extrasHost() and M.extras().deadDecoys and R.valid(ps) and type(value)=='table') then return end
        local key=ps:GetAddress()
        if value.release then return letGoOf(key) end
        if not point(value) or (value.kind~='witch' and value.kind~='prop') then return end
        local ghost=ghostOf(ps:GetOwner())
        if not ghost then return letGoOf(key) end
        local d=live[key]
        if value.throw then
            local now=GP:GetTimeSeconds(ghost)
            if last[key] and now-last[key]<cooldown()-.5 then return end
            last[key]=now
            letGoOf(key)
            return throw(ps,ghost,value)
        end
        if d and d.kind==value.kind and R.valid(d.decoy) then target(d.decoy,d.kind,value)
        elseif not d or d.steered~=false then
            log('Decoy steer not applied: decoy %s, kind %s / %s',tostring(d and R.valid(d.decoy) and true),tostring(d and d.kind),tostring(value.kind))
            if d then d.steered=false end
        end
    end)
    -- Her death over (the body gone): her decoy is let go as at a release.
    R.on('actor_end',function(actor)
        local address=actor:GetAddress()
        for key,d in pairs(live) do if d.ghost==address then letGoOf(key) end end
    end)
    R.on('world_end',function() live,last={},{} end)
end
