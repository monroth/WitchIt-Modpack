-- Gameplay effects of the extra rules: physics and movement patches,
-- powerup pacing, round delay, cooldown floor, cauldron target, spring pads and abandoned props.
-- Every patched field keeps its native base so a later change or removal restores it.
return function(M)
    -- The game's own values, as the schema declares them (each rule's initial): the one place they are
    -- written (audit 11-20: the effects repeated 22, 20, 30, 10 and 5).
    local GAME={}
    for _,spec in ipairs(M.schema.extras) do GAME[spec.key]=spec.initial end
    local R,C=M.R,M.C
    local hooks=M.hooks
    local CORE,PROP,PAWN=M.CORE,M.PROP,M.PAWN
    local POTATO='/Game/Blueprints/Skills/Hunter/Potato/B_PotatoSkill.B_PotatoSkill_C'
    local FLY='/Game/Blueprints/Skills/Witch/Fly/B_FlySkill.B_FlySkill_C'
    local CANNON='/Game/Blueprints/Skills/Hunter/Cannonball/B_CannonballSkill.B_CannonballSkill_C'
    local PAD='/Game/Blueprints/Skills/B_SpringPad.B_SpringPad_C'
    local originals,abandoned={},{}
    local restoring=false
    local function record(o)
        local key=o:GetAddress()
        local row=originals[key]
        if not row then row={object=o,fields={}};originals[key]=row end
        return row
    end
    -- Set o[name] to value (or base*value when multiply), remembering the native base.
    -- value nil (or a factor of 1) returns the field to its base and forgets it.
    local function field(o,name,value,multiply)
        local row=originals[o:GetAddress()]
        local old=row and row.fields[name]
        if not old and (value==nil or multiply and value==1) then return end
        local current=o[name]
        if not old then old={base=current};record(o).fields[name]=old end
        if old.last~=nil and current~=old.last then old.base=current end
        local target=value==nil and old.base or multiply and old.base*value or value
        if current~=target then o[name]=target end
        old.last=target
        if value==nil or multiply and value==1 then record(o).fields[name]=nil end
    end
    local propFields={Force='propForce',AirForce='propAirForce',MaxSpeed='propMaxSpeed',JumpForce='propJumpForce',ExtraSpeedMultiplier='propSpeed'}
    local function patchProp(prop,owner)
        if restoring or not M.extrasHost() and not owner then return end
        if owner then record(prop).pawn=owner end
        local e=M.extras()
        for name,key in pairs(propFields) do field(prop,name,e[key],true) end
        local row=originals[prop:GetAddress()]
        local factor=e.propMass
        if factor and factor~=1 then
            row=row or record(prop)
            row.mass=row.mass or prop.Mesh:GetMass()
            prop.Mesh:SetMassOverrideInKg(FName('None'),row.mass*factor,true)
        elseif row and row.mass then
            row.mass=nil
            prop:UpdateMass()
        end
    end
    local function patchPawn(pawn,team)
        if restoring or not M.ownerAllowed(pawn) then return end
        local e,row=M.extras(),originals[pawn:GetAddress()]
        local fly=row and R.valid(row.fly) and row.fly
        local cannon=row and R.valid(row.cannon) and row.cannon
        local movement=pawn.CharacterMovement
        if not (fly and fly.IsSkillActive) and not (cannon and cannon.IsStomping) then
            field(movement,'GravityScale',e[team..'Gravity'],true)
        end
        -- A Cannonball sets its hunter's air control from its own rule (InitializeRules): that is the skill's.
        field(movement,'AirControl',not cannon and e[team..'AirControl'] or nil,false)
        if originals[movement:GetAddress()] then record(pawn).movementKey=movement:GetAddress() end
        if cannon then
            local movementRow=originals[movement:GetAddress()]
            local gravity=movementRow and movementRow.fields.GravityScale
            if gravity then field(cannon,'GravityScale',gravity.base*(M.extras().hunterGravity or 1),false) end
        end
    end
    local function patchPotato(skill)
        if restoring then return end
        local owner=skill:GetOwner()
        if R.valid(owner) and M.ownerAllowed(owner) then field(skill,'StaminaRecharge',M.extras().staminaRecharge,false) end
    end
    -- A pad fires on every machine, so each one scales its own copy.
    local function patchPad(pad)
        if restoring then return end
        local factor=M.extras().padImpulse
        field(pad,'ImpulseCharacter',factor,true)
        field(pad,'ImpulsePhysicalObject',factor,true)
    end
    hooks.post(PAD..':ReceiveBeginPlay',patchPad)
    -- The bounce area under Witch Forest is no pad: it computes each launch toward a point.
    hooks.post('/Game/Features/Experimental/BounceToPointVolume/BounceToPoint.BounceToPoint_C:CalculateVelocity',function(_,_,_,_,velocity)
        local factor=M.extras().padImpulse
        if not factor then return end
        local value=velocity:get()
        velocity:set({X=value.X*factor,Y=value.Y*factor,Z=value.Z*factor})
    end)
    for _,team in ipairs({'Hunter','Witch'}) do
        for _,event in ipairs({'InitializeRules','ReceiveBeginPlay'}) do
            hooks.post(PAWN..'B_'..team..'.B_'..team..'_C:'..event,function(pawn) patchPawn(pawn,team:lower()) end)
        end
    end
    for _,event in ipairs({'InitializeRules','ReceiveBeginPlay'}) do hooks.post(POTATO..':'..event,patchPotato) end
    for _,event in ipairs({'ReceiveBeginPlay','UpdateScaledSpeed','UpdateMass'}) do
        hooks.post(PROP..':'..event,function(prop)
            local row=originals[prop:GetAddress()]
            local pawn=row and row.pawn
            local owner=R.valid(pawn) and pawn:IsLocallyControlled() and pawn.ControllingProp==prop and pawn or nil
            if not M.extrasHost() and not owner then return end
            if event=='UpdateMass' and row then row.mass=nil end
            patchProp(prop,owner)
        end)
    end
    for _,event in ipairs({'SwitchProp','OnRep_ControllingProp'}) do
        hooks.post(PAWN..'B_PropPawnPhysics.B_PropPawnPhysics_C:'..event,function(pawn)
            if restoring or not M.ownerAllowed(pawn) then return end
            local prop=pawn.ControllingProp
            if R.valid(prop) then patchProp(prop,pawn) end
        end)
    end
    local function skillEvent(skill,team,name)
        if restoring then return end
        local owner=skill:GetOwner()
        if not R.valid(owner) or not M.ownerAllowed(owner) then return end
        record(owner)[name]=skill
        patchPawn(owner,team)
    end
    for _,event in ipairs({'ReleaseFlying','SetFlying','InitializeRules'}) do
        hooks.post(FLY..':'..event,function(skill) skillEvent(skill,'witch','fly') end)
    end
    for _,event in ipairs({'InitializeRules','OnSkillDownMulti','OnSkillUpMulti','HandleStomp'}) do
        hooks.post(CANNON..':'..event,function(skill) skillEvent(skill,'hunter','cannon') end)
    end

    -- Visuals that keep the game's sizes and times when a rule changes them (the game's own
    -- blueprints leave them fixed), and the witch jump a slow resets to a constant.
    local function subsystem(category) return C.subsystem(category) end
    local CHICKEN='/Game/Blueprints/Skills/Hunter/Chicken/B_Chicken.B_Chicken_C'
    local DETECTION='/Game/Blueprints/Pickups/PickupActorSpawns/B_PickupChicken.B_PickupChicken_C'
    -- A chicken's (a skill's, or the Hunter Detection power-up's) detection radius against the one
    -- its hemisphere and alarm were made for.
    local sonar={}
    hooks.post(CHICKEN..':TearUp',function(chicken)
        local parameters=chicken:IsA(StaticFindObject(DETECTION)) and subsystem('powerups').HunterDetection or subsystem('skills').Chicken
        local radius=chicken:GetCheckRadius()
        local ratio=radius/parameters:GetClass():GetCDO().CheckRadius
        sonar[chicken:GetAddress()]=ratio~=1 and ratio or nil
        if ratio~=1 then chicken.NS_ChickenAlarm:SetFloatParameter(FName('UnrealScale'),2*radius) end
    end)
    -- (the hemisphere's timeline sets its size on every update while it plays)
    hooks.post(CHICKEN..':SonarScale__UpdateFunc',function(chicken)
        local ratio=sonar[chicken:GetAddress()]
        if not ratio then return end
        local s=chicken.VisualSphere.RelativeScale3D
        chicken.VisualSphere:SetRelativeScale3D({X=s.X*ratio,Y=s.Y*ratio,Z=s.Z*ratio})
    end)
    hooks.on('actor_end',function(actor) sonar[actor:GetAddress()]=nil end)
    -- A mushroom's effect fades by a lifetime of its own (9 s); it gets the mushroom's.
    local MUSHROOM='/Game/Blueprints/Skills/Witch/Elixir/B_MushroomArea.B_MushroomArea_C'
    for _,event in ipairs({'InitializeRules','TearUp'}) do
        hooks.post(MUSHROOM..':'..event,function(area)
            if area.LifeTime>0 then area.MushroomVisuals:SetFloatParameter(FName('LifeTime'),area.LifeTime) end
        end)
    end
    -- A slow ends with the witch's jump set to a constant: back to the jump of the rules.
    local WITCH=PAWN..'B_Witch.B_Witch_C'
    local slowed={}
    local function restoreJump(pawn)
        local key=pawn:GetAddress()
        if slowed[key] then return end
        local function check()
            if not R.valid(pawn) then slowed[key]=nil;return end
            if pawn.SlowTime>0 then slowed[key]=R.after(pawn.SlowTime*1000+100,check);return end
            slowed[key]=nil
            pawn.CharacterMovement.JumpZVelocity=pawn.DefaultJumpHeight*subsystem('match').WitchMatchParameters.JumpHeightMultiplier
        end
        slowed[key]=R.after(pawn.SlowTime*1000+100,check)
    end
    hooks.post(WITCH..':Slow',restoreJump)
    hooks.post(WITCH..':InitializeRules',function(pawn) if pawn.SlowTime>0 then restoreJump(pawn) end end)
    -- A trap flies at its blueprint's InitialSpeed: the rule's multiple of it.
    hooks.pre('/Game/Blueprints/Skills/Hunter/Trap/B_TrapProjectile.B_TrapProjectile_C:TearUp',function(trap)
        field(trap,'InitialSpeed',M.extras().trapThrowSpeed,true)
    end)
    -- A trap starts its vacuum 0.25 s after it first hits something (a fixed Delay of its blueprint):
    -- at the rule's delay instead. The game's own late call is skipped and the mod makes it.
    local TRAP='/Game/Blueprints/Skills/Hunter/Trap/B_TrapProjectile.B_TrapProjectile_C'
    local starting={}
    hooks.post(TRAP..':StopHitDetectionAndMakeHeavy',function(trap)
        local delay=M.extras().trapDelay
        if not delay or not trap:HasAuthority() then return end
        local key=trap:GetAddress()
        starting[key]=false
        R.after(delay*1000,function()
            if not R.valid(trap) or starting[key]~=false or not trap.IsSucking then return end
            starting[key]=true;trap:StartVacuum();starting[key]='started'
        end)
    end)
    -- (only the mod's call starts it: the game's, before or after it, is skipped)
    hooks.pre(TRAP..':StartVacuum',function(trap)
        local state=starting[trap:GetAddress()]
        if state==false or state=='started' then return true end
    end)
    hooks.on('actor_end',function(actor) starting[actor:GetAddress()]=nil end)
    -- A slowed witch runs and flies at 0.75 of her speed and jumps 450 (the game's constants): the
    -- rule's multiple of her speed and of the rules' jump instead (every machine moves her).
    hooks.post(WITCH..':TickMovementSpeed',function(pawn)
        local slow=M.extras().trapSlow
        if not slow or pawn.SlowTime<=0 then return end
        local movement=pawn.CharacterMovement
        movement.MaxWalkSpeed=pawn.MaxWalkSpeed*slow;movement.MaxFlySpeed=movement.MaxWalkSpeed
        movement.JumpZVelocity=pawn.DefaultJumpHeight*subsystem('match').WitchMatchParameters.JumpHeightMultiplier*slow
    end)
    -- A trap drains a witch's mana at the game's rate (GAME.manaDrain a second): the rule's rate instead.
    for _,pawnClass in ipairs({'B_Witch.B_Witch_C','B_PropPawnPhysics.B_PropPawnPhysics_C'}) do
        hooks.post(PAWN..pawnClass..':TickManaDrainDebuff',function(pawn)
            local rate=M.extras().manaDrain
            if not rate or rate==GAME.manaDrain or pawn.ManaDrainDebuff<=0 or not M.extrasHost() then return end
            local tracking={};C.session().gs:HasTrackingStarted(tracking)
            if not tracking.HasTrackingStarted then return end
            local mana=pawn.B_ManaComponent
            local dt=StaticFindObject('/Script/Engine.Default__GameplayStatics'):GetWorldDeltaSeconds(pawn)
            mana:SetCurrentMana(math.max(0,mana.CurrentMana+(20-rate)*dt))
        end)
    end

    -- Stamina costs of the hunter's skills. A hunter's stamina is its potato's (the game's only
    -- stamina, shown by the stamina bar); with stamina off or no potato a skill costs nothing.
    local HUNTER='/Game/Blueprints/Skills/Hunter/'
    local SKILLS={Chicken='chickenStamina',Hook='hookStamina',Cannonball='cannonStamina',Garlic='garlicStamina',
        Trap='trapStamina',PowerBall='powerballStamina',Melee='meleeStamina',Train='trainStamina'}
    local POTATO_SKILL=HUNTER..'Potato/B_PotatoSkill.B_PotatoSkill_C'
    local function costOf(skill)
        local name=skill:GetClass():GetFName():ToString():match('^B_(%w+)Skill_C$')
        local key=name and SKILLS[name]
        local cost=key and M.extras()[key]
        if not cost or cost<=0 or not subsystem('match').HunterMatchParameters.StaminaEnabled then return nil end
        local owner=R.valid(skill:GetOwner())
        local potato=owner and R.valid(owner.PrimarySkill)
        if not potato or not potato:IsA(StaticFindObject(POTATO_SKILL)) then return nil end
        return cost,potato
    end
    -- (CanActivate is a native event: its answer is replaced by returning one, not passed in)
    local function gate(skill)
        local cost,potato=costOf(skill)
        -- (a Cannonball's landing asks again; it was paid for when it started)
        if cost and skill:GetClass():GetFName():ToString()=='B_CannonballSkill_C' and skill.IsStomping then return end
        if cost then
            local name=skill:GetClass():GetFName():ToString():match('^B_(%w+)Skill_C$') or '?'
            -- (a skill the rule makes cost stamina: on change only)
            C.state(M.PKG,'Hunter '..name..' skill',potato.Stamina<cost and 'refused - not enough stamina for the rule\'s cost' or 'allowed')
        end
        if cost and potato.Stamina<cost then return false end
    end
    hooks.post(HUNTER..'B_BaseHunterSkill.B_BaseHunterSkill_C:CanActivate',gate)
    for _,leaf in ipairs({'Melee/B_MeleeSkill.B_MeleeSkill_C','PowerBall/B_PowerBallSkill.B_PowerBallSkill_C'}) do
        hooks.post(HUNTER..leaf..':CanActivate',gate)
    end
    -- Paid on the server, once an activation (a skill's own and its parents' hooks may both run).
    local paid={}
    local function pay(skill)
        local owner=R.valid(skill:GetOwner())
        if not owner or not owner:HasAuthority() then return end
        local cost,potato=costOf(skill)
        if not cost then return end
        local now=StaticFindObject('/Script/Engine.Default__GameplayStatics'):GetTimeSeconds(skill)
        if paid[skill:GetAddress()]==now then return end
        paid[skill:GetAddress()]=now
        -- (the potato is a component: written and marked for replication, like the game's own spend)
        C.replicate(potato,'Stamina',math.max(0,potato.Stamina-cost),2)
    end
    hooks.post(HUNTER..'B_BaseHunterSkill.B_BaseHunterSkill_C:HandleSkillActivated',pay)
    for _,leaf in ipairs({'Cannonball/B_CannonballSkill.B_CannonballSkill_C','Chicken/B_ChickenSkill.B_ChickenSkill_C'}) do
        hooks.post(HUNTER..leaf..':HandleSkillActivated',pay)
    end
    -- A charged melee hit goes past HandleSkillActivated.
    hooks.post(HUNTER..'Melee/B_MeleeSkill.B_MeleeSkill_C:ExecuteHitServer',function(skill,charged)
        if charged then pay(skill) end
    end)
    hooks.on('actor_end',function(actor) paid[actor:GetAddress()]=nil end)

    local function distance(a,b)
        local p,q=a:K2_GetActorLocation(),b:K2_GetActorLocation()
        return math.sqrt((p.X-q.X)^2+(p.Y-q.Y)^2+(p.Z-q.Z)^2)
    end
    -- Every hunter sees, from each chicken (a skill's, or Hunter Detection's on a hunter's head),
    -- EffectKit's wisps in the chicken's gold drifting toward each witch it finds and ending at
    -- her: fainter and fewer at the edge of its reach, more and brighter closer (witches see none).
    -- (user 11-20: barely seen - three times as bright as they were, and opaque and more at the edge)
    local E=R.packages.EffectKit
    local sparks=E.pointers({path=E.WISPS,reach={speed=function(c) return 90+360*c end,drag=E.WISPS_DRAG},
        rate=function(closeness)
            local k=closeness*closeness
            local glow=3*1.4*(.4+1.6*k)
            return {SpawnRate=6+16*k,Color={R=1*glow,G=.62*glow,B=.12*glow,A=.75+.25*k}}
        end})
    local chickens={}
    hooks.post(CHICKEN..':TearUp',function(chicken) chickens[chicken:GetAddress()]=chicken end)
    hooks.on('actor_end',function(actor)
        chickens[actor:GetAddress()]=nil
        sparks:close(actor:GetAddress())
    end)
    -- (and the witches' decoys: a chicken shouts at them too - without sparks a decoy was given away, user 11-21)
    local WITCHES={PAWN..'B_Witch.B_Witch_C',PAWN..'B_PropPawnPhysics.B_PropPawnPhysics_C','/Game/Blueprints/Skills/Witch/Decoy/B_DecoyWitch.B_DecoyWitch_C','/Game/Blueprints/Skills/Witch/Decoy/B_DecoyProp.B_DecoyProp_C'}
    local function stream(key,chicken,witch,closeness)
        local from,to=chicken:K2_GetActorLocation(),witch:K2_GetActorLocation()
        -- (a chicken on a hunter's head starts it at the chest and 1.5 m ahead: not in front of the eyes)
        if chicken:IsA(StaticFindObject(DETECTION)) then
            local dx,dy,dz=to.X-from.X,to.Y-from.Y,to.Z-from.Z
            local length=math.max(1,math.sqrt(dx*dx+dy*dy+dz*dz))
            local ahead=math.min(150,length*.5)
            from={X=from.X+dx/length*ahead,Y=from.Y+dy/length*ahead,Z=from.Z-60+dz/length*ahead}
        end
        -- (they end at the witch's surface, whatever she is now: the radius of her bounds)
        local origin,extent={},{}
        witch:GetActorBounds(false,origin,extent,false)
        local size=math.sqrt(extent.X^2+extent.Y^2+extent.Z^2)*.8
        local dx,dy,dz=from.X-to.X,from.Y-to.Y,from.Z-to.Z
        local k=math.min(1,size/math.max(1,math.sqrt(dx*dx+dy*dy+dz*dz)))
        sparks:aim(key,chicken,from,{X=to.X+dx*k,Y=to.Y+dy*k,Z=to.Z+dz*k},closeness)
    end
    hooks.post(PAWN..'B_Hunter.B_Hunter_C:TickHUD',function(hunter)
        local extras=M.extras()
        -- (what they do and why, in the log as it changes - live 11-20 a guest saw none)
        local n=0;for _ in pairs(chickens) do n=n+1 end
        C.state(M.PKG,'Chicken sparks',not (extras.chickenSparks or extras.detectionSparks) and 'off - the rules are off'
            or ('on (skill %s, Hunter Detection %s) - chickens out: %d'):format(tostring(extras.chickenSparks==true),tostring(extras.detectionSparks==true),n))
        if (extras.chickenSparks or extras.detectionSparks) and next(chickens) then
            -- Whom a chicken shouts at: every witch in any body (a pawn of a witch player) and the witches' decoys -
            -- a prop decoy shows a prop of its own (its Prop).
            local targets={}
            for _,pawn in ipairs(R.find_all('/Script/Engine.Pawn')) do
                if R.valid(pawn) and C.side(R.valid(pawn.PlayerState))=='witch' then targets[#targets+1]=pawn end
            end
            for _,d in ipairs(R.find_all(WITCHES[3])) do targets[#targets+1]=d end
            for _,d in ipairs(R.find_all(WITCHES[4])) do local prop=R.valid(d) and R.valid(d.Prop);targets[#targets+1]=prop or d end
            for key,chicken in pairs(chickens) do
                if not R.valid(chicken) then chickens[key]=nil
                -- (each kind of chicken has its own rule: the skill's and Hunter Detection's)
                elseif not (chicken:IsA(StaticFindObject(DETECTION)) and extras.detectionSparks or not chicken:IsA(StaticFindObject(DETECTION)) and extras.chickenSparks) then
                else
                    local radius=chicken:GetCheckRadius()
                    -- (what it finds, by distance within its radius - user 11-21: a witch turned prop and a prop decoy's
                    -- prop were not among the actors touching its sphere)
                    -- (in the log as it changes: what touches its sphere, and which targets are in its radius)
                    local touching,inRadius={},{}
                    local found={};chicken.Sphere:GetOverlappingActors(found,nil)
                    local touched={}
                    for _,a in ipairs(found) do
                        a=R.valid(a)
                        if a then touched[a:GetAddress()]=true;touching[#touching+1]=a:GetFullName():match('^(%S+)') end
                    end
                    for _,a in ipairs(targets) do if R.valid(a) then inRadius[#inRadius+1]=a:GetClass():GetFName():ToString()..(distance(chicken,a)<=radius and ' (in)' or ' (out)') end end
                    table.sort(touching);table.sort(inRadius)
                    C.state(M.PKG,'Chicken '..key,('radius %.0fm; touching: %s; witches and decoys: %s'):format(radius/100,table.concat(touching,', '),table.concat(inRadius,', ')))
                    for _,actor in ipairs(targets) do
                        if R.valid(actor) and (touched[actor:GetAddress()] or distance(chicken,actor)<=radius) then
                            stream(key..':'..actor:GetAddress(),chicken,actor,math.max(0,1-distance(chicken,actor)/radius))
                        end
                    end
                end
            end
        end
        -- (a witch out of every chicken's reach, or the rule off: its stream goes)
        sparks:done()
    end)

    -- A power-up's lifetime: the game's own for 0; else this long until it goes (on every machine: the
    -- countdown it shows reads its life span).
    hooks.post('/Game/Blueprints/MagicRelicts/B_MagicRelict.B_MagicRelict_C:ReceiveBeginPlay',function(relict)
        local life=M.extras().powerupLifetime
        if life and life>0 then relict:SetLifeSpan(life) end
    end)
    hooks.post(CORE..'B_GameMode.B_GameMode_C:GetPickupSpawnDelay',function(gm,out)
        local e=M.extras()
        -- (the two rules go together: either changed sets the delay, from the game's own values)
        if M.extrasHost() and (e.pickupMin or e.pickupJitter) then
            local least,extra=e.pickupMin or GAME.pickupMin,e.pickupJitter or GAME.pickupJitter
            out:set(least+(extra>0 and math.random(0,extra-1) or 0))
        end
    end)
    hooks.post(CORE..'B_SeekGameMode.B_SeekGameMode_C:GetRoundEndTimerUntilRestart',function(gm,out)
        local delay=M.extras().roundDelay
        if M.extrasHost() and delay and delay~=GAME.roundDelay then out:set(math.max(delay,gm.MapVoteTimeNeeded and 29 or 1)) end
    end)
    hooks.post(C.subsystem_paths.skills..':GetSkillCooldown',function(_,_,_,out)
        local minimum=M.extras().cooldownMin
        if minimum and out:get()<minimum then out:set(minimum) end
    end)
    -- Abandoned props: the native dissolve timer, re-armed for the selected lifetime.
    local timerName='DissolvePropServer'
    local function rearm(prop,row,lifetime)
        local lib=M.library('KismetSystemLibrary')
        local now=M.library('GameplayStatics'):GetTimeSeconds(prop)
        if row.lifetime=='never' then
            row.elapsed=row.elapsed+(row.paused and 0 or now-row.sampled)
        else
            row.elapsed=row.elapsed+lib:K2_GetTimerElapsedTime(prop,timerName)
            row.paused=lib:K2_IsTimerPaused(prop,timerName)
        end
        row.sampled,row.lifetime=now,lifetime
        lib:K2_ClearTimer(prop,timerName)
        if lifetime~='never' then
            lib:K2_SetTimer(prop,timerName,math.max(.001,lifetime-row.elapsed),false,false,0,0)
            if row.paused then lib:K2_PauseTimer(prop,timerName) end
        end
    end
    hooks.post(PROP..':StartDestroyCountdown',function(prop)
        local lifetime=M.extras().keepAbandoned and 'never' or M.extras().possessionLifetime or GAME.possessionLifetime
        if not M.extrasHost() or lifetime==GAME.possessionLifetime or prop.IsControlledByWitch then return end
        local row={object=prop,elapsed=0,lifetime=GAME.possessionLifetime}
        abandoned[prop:GetAddress()]=row
        rearm(prop,row,lifetime)
    end)
    for _,event in ipairs({'StopDestroyCountdown','DissolvePropServer'}) do
        hooks.post(PROP..':'..event,function(prop) abandoned[prop:GetAddress()]=nil end)
    end
    function M.cleanupAbandoned()
        local old=abandoned
        local n=0;for _ in pairs(old) do n=n+1 end
        if n>0 then R.log(M.PKG,'Match over: %d abandoned props dissolved',n) end
        abandoned={}
        for _,row in pairs(old) do
            if R.valid(row.object) and not row.object.IsControlledByWitch then row.object:DissolvePropServer() end
        end
    end
    hooks.on('match_end',function() if C.session().role=='host' then M.cleanupAbandoned() end end)
    -- Forgetting an ending actor is bookkeeping, needed in every session.
    R.on('actor_end',function(actor)
        local key=actor:GetAddress()
        local row=originals[key]
        if row and row.movementKey then originals[row.movementKey]=nil end
        originals[key],abandoned[key]=nil,nil
    end)

    -- Re-apply every effect after a change of selection: restore all bases, then let
    -- the native rule initializers and the patches above run once again.
    local actors={
        {path=PAWN..'B_Hunter.B_Hunter_C',method='InitializeRules'},
        {path=PAWN..'B_Witch.B_Witch_C',method='InitializeRules'},
        {path=PAWN..'B_PropPawnPhysics.B_PropPawnPhysics_C',method='RulesUpdated'},
        {path=M.CREATIVE..'B_CreativePropPawnPhysics.B_CreativePropPawnPhysics_C',method='RulesUpdated'}
    }
    for team,skills in pairs({Hunter={'Potato','Melee','Chicken','Hook','Cannonball','Garlic','Trap','PowerBall','Train'},
        Witch={'Decoy','Mushroom','Fly','JumpScare','Possess','FlyingEye'}}) do
        for _,name in ipairs(skills) do
            actors[#actors+1]={path=C.skill_class(team,name),method='InitializeRules'}
        end
    end
    function M.refreshEffects()
        -- (restoring only while the originals go back, also when one of them fails: audit 11-20, an error
        -- left it on and every later patch was skipped)
        restoring=true
        do
            local keys={}
            for key in pairs(M.extras()) do keys[#keys+1]=key end
            table.sort(keys)
            R.log(M.PKG,'Applying the extra rules (%s): %s',C.session().role,#keys>0 and table.concat(keys,', ') or 'none differ from the game')
        end
        R.finally(function()
            for key,row in pairs(originals) do
                originals[key]=nil
                local o=row.object
                if R.valid(o) then
                    for name,old in pairs(row.fields) do
                        if o[name]==old.last then o[name]=old.base end
                    end
                    if row.mass then o:UpdateMass() end
                end
            end
        end,function() restoring=false end)
        local role=C.session().role
        if role=='host' or role=='client' then
            for _,pad in ipairs(R.find_all(PAD)) do patchPad(pad) end
            for _,path in ipairs({FLY,CANNON}) do
                for _,skill in ipairs(R.find_all(path)) do
                    skillEvent(skill,path==FLY and 'witch' or 'hunter',path==FLY and 'fly' or 'cannon')
                end
            end
            for _,spec in ipairs(actors) do
                for _,actor in ipairs(R.find_all(spec.path)) do
                    local owner=spec.method=='InitializeRules' and spec.path:find('/Skills/',1,true) and actor:GetOwner() or actor
                    if role=='host' or R.valid(owner) and owner:IsLocallyControlled() then
                        actor[spec.method](actor)
                        if spec.method=='RulesUpdated' and M.ownerAllowed(actor) then
                            local prop=actor.ControllingProp
                            if R.valid(prop) then patchProp(prop,actor) end
                        end
                    end
                end
            end
            for _,prop in ipairs(R.find_all(PROP)) do patchProp(prop) end
        end
        local lifetime=M.extras().keepAbandoned and 'never' or M.extras().possessionLifetime or 5
        for key,row in pairs(abandoned) do
            local prop=row.object
            if R.valid(prop) and not prop.IsControlledByWitch then
                rearm(prop,row,lifetime)
                if lifetime==GAME.possessionLifetime then abandoned[key]=nil end
            else abandoned[key]=nil end
        end
        if M.extrasHost() and lifetime~=GAME.possessionLifetime then
            local lib=M.library('KismetSystemLibrary')
            for _,prop in ipairs(R.find_all(PROP)) do
                if not prop.IsControlledByWitch and not abandoned[prop:GetAddress()] and
                    (lib:K2_IsTimerActive(prop,timerName) or lib:K2_IsTimerPaused(prop,timerName)) then
                    local row={object=prop,elapsed=0,lifetime=GAME.possessionLifetime}
                    abandoned[prop:GetAddress()]=row
                    rearm(prop,row,lifetime)
                end
            end
        end
    end
    -- Entering a vanilla session returns every patched object to its native values.
    C.on_session(function(s)
        if s.mode=='vanilla' and (next(originals) or next(abandoned)) then M.refreshEffects() end
    end)
    -- Retired actors are discarded by their native lifetime. Never read them on travel.
    R.on('world_end',function()
        originals,abandoned={},{}
    end)
end
