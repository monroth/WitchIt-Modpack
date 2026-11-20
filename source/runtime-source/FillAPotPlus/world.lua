return function(S)
    local R,C=S.R,S.C
    local problem=nil
    local objects={}
    local appearances={}
    local function hideMarker(actor)
        actor:SetReplicates(true);actor.bAlwaysRelevant=true;actor.NetDormancy=1
        actor:SetActorHiddenInGame(true);actor:SetActorEnableCollision(false)
        actor:FlushNetDormancy();actor:ForceNetUpdate()
    end
    -- The map's settings (codec: target, secret, event), kept here once (user 11-20, the new format):
    -- the host's from the map record of the loaded map, a guest's as the host publishes them; the
    -- editor changes them (S.setMap) and the map record saves them (package.lua).
    S.map=S.codec.mapOf()
    local function publish() if S.host() then C.net.publish('fap.map',S.map) end end
    C.map.on_load(function(records) local r=records[S.codec.ID];S.map=S.codec.decodeMap(r and r.data);publish() end)
    C.net.watch('fap.map',function(value) if not S.host() then S.map=S.codec.mapOf(value) end end)
    R.on('world_end',function() S.map=S.codec.mapOf() end)
    function S.setMap(key,value) S.map[key]=value;publish() end
    function S.settings() return S.map end
    -- The prop categories cauldrons may want on this map: Common (0), and Secret (1) and Event (3)
    -- when the map allows them.
    function S.categories()
        return {[0]=true,[1]=S.map.secret,[3]=S.map.event}
    end
    function S.propGroups(categories)
        categories=categories or S.categories()
        local groups={}
        local system=StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')
        for _,actor in ipairs(R.find_all('/Game/Blueprints/Props/Bases/B_StaticMeshProp.B_StaticMeshProp_C')) do
            if categories[actor:GetClass():GetCDO().PropCategory] then
                local class=actor:GetClass();local path=S.classpath(class)
                local group=groups[path]
                if not group then
                    group={path=path,class=class,name=S.text(system:GetClassDisplayName(class)),props={}}
                    groups[path]=group
                end
                group.props[#group.props+1]={actor=actor,position=actor:K2_GetActorLocation()}
            end
        end
        return groups
    end
    -- The props a cauldron never asks for: the game's own (its class defaults) and the ones the marker
    -- excludes - one answer for the editor's count and the spawned cauldron (audit 11-20: two copies).
    function S.avoided(info,groups)
        local names={}
        local defaults=S.asset(S.path(S.O,'B_ObjectiveCauldron')):GetCDO()
        for _,name in ipairs(S.values(defaults.PropClassesToAvoid)) do names[#names+1]=S.text(name) end
        for path in pairs(info.excluded) do if groups[path] then names[#names+1]=groups[path].name end end
        return names
    end
    function S.eligible(row,groups)
        local eligible={}
        local avoid={}
        for _,name in ipairs(S.avoided(row.info,groups)) do avoid[name]=true end
        for _,group in pairs(groups) do
            local allowed=#group.props>=2 and not row.info.excluded[group.path] and not avoid[group.name]
            for _,prop in ipairs(group.props) do
                if S.distance(row.position,prop.position)<=row.info.radius^2 then allowed=false end
            end
            if allowed then eligible[#eligible+1]=group end
        end
        table.sort(eligible,function(a,b) return a.path<b.path end)
        return eligible
    end
    function S.checkMap(rows)
        rows=rows or S.markers()
        local failures,warnings,pots,starts={},{},{},{}
        local groups=S.propGroups(S.categories())
        for _,row in ipairs(rows) do
            local d=row.info
            if d.kind==1 then pots[#pots+1]=row
            elseif d.kind==2 then
                row.destination=S.ground(row.actor)
                if row.destination then starts[#starts+1]=row
                else warnings[#warnings+1]='A witch respawn point has no safe position.' end
            end
        end
        if #pots<3 then failures[#failures+1]='Place at least 3 cauldrons.' end
        -- (never the witch starts instead: too predictable, user 11-19)
        if #starts==0 then failures[#failures+1]='Add a witch respawn point.' end
        for i,row in ipairs(pots) do
            row.pool=S.eligible(row,groups)
            if #row.pool<#pots+1 then failures[#failures+1]='Cauldron '..i..' needs '..(#pots+1)..' eligible prop kinds, with two copies of each outside its radius.' end
            for j=i+1,#pots do
                if S.distance(row.position,pots[j].position)<1 then failures[#failures+1]='Two cauldrons overlap.' end
            end
        end
        return failures,warnings,pots,starts,groups
    end
    function S.mapExplanation(errors,warnings,pots,starts,groups)
        if not errors then errors,warnings,pots,starts,groups=S.checkMap() end
        local copies,kinds=0,0
        for _,group in pairs(groups) do copies=copies+#group.props;kinds=kinds+1 end
        -- Problems first: the details below can be longer than the dialog.
        local lines={}
        for _,why in ipairs(errors) do lines[#lines+1]='Map problem: '..why end
        for _,why in ipairs(warnings) do lines[#lines+1]='Map warning: '..why end
        lines[#lines+1]=#errors==0 and 'Ready to play.' or 'Fix the map problems before playing.'
        lines[#lines+1]=''
        local categories=S.categories()
        local kindsOf=(categories[1] or categories[3]) and 'wanted-kind props' or 'common props'
        lines[#lines+1]='Map: '..copies..' '..kindsOf..', '..kinds..' prop types; cauldrons='..#pots..'; witch respawn points='..#starts
        for i,row in ipairs(pots) do
            local colour=row.info.colour
            -- (which kinds and why: the cauldron's panel)
            local pool=S.eligible(row,groups)
            lines[#lines+1]=string.format('Cauldron %d (%.3f, %.3f, %.3f): wanted props %d/%d %s',i,colour.R,colour.G,colour.B,#pool,#pots+1,#pool>=#pots+1 and '✓' or '✗')
        end
        return table.concat(lines,'\n')
    end
    -- The rune rays (SM_PotRuneRays) reach down as far as the runes do (the cauldron's Rune depth below,
    -- user 11-20): the mesh runs from 14.9 below its origin to 51.5 above (live VM2 11-20), so as the game
    -- stretches it the rays hung ~33 cm under any cauldron and showed under a thin roof. Their top stays;
    -- their bottom is the runes' depth: deep on uneven ground, shallow on a thin roof.
    S.RAYS_LOW,S.RAYS_HIGH=14.9,51.5
    function S.rays(component,top,down)
        local s=(top+down)/(S.RAYS_LOW+S.RAYS_HIGH)
        local scale,at=component.RelativeScale3D,component.RelativeLocation
        component:SetRelativeScale3D({X=scale.X,Y=scale.Y,Z=s})
        component:K2_SetRelativeLocation({X=at.X,Y=at.Y,Z=-down+S.RAYS_LOW*s},false,{},false)
    end
    function S.potAppearance(pot,info)
        pot.Color=info.colour
        pot.Cauldron:SetMobility(2)
        local mesh=S.asset('/Game/ObjectiveModeContent/SM_Cauldron01.SM_Cauldron01')
        pot.Cauldron:SetStaticMesh(mesh);pot.Cauldron:SetMaterial(0,mesh:GetMaterial(0))
        pot.Cauldron:SetRelativeScale3D({X=1.2,Y=1.2,Z=1.2})
        pot:Init()
        local rays=pot.RuneRays
        S.rays(rays,rays.RelativeLocation.Z+S.RAYS_HIGH*rays.RelativeScale3D.Z,info.down)
        local decal=pot.Decal
        local size=decal.DecalSize;size.X=(info.down+info.up)/2;decal.DecalSize=size
        decal.RelativeLocation.Z=(info.up-info.down)/2
        local al,ar,asc=decal.bAbsoluteLocation,decal.bAbsoluteRotation,decal.bAbsoluteScale
        decal:SetAbsolute(not al,ar,asc);decal:SetAbsolute(al,ar,asc)
    end
    function S.target()
        local session=C.session()
        if session.is_creative then return end
        local count=session.gs.Cauldrons:GetArrayNum()
        if count==0 then return end
        local base=S.settings().target
        local mm=S.manager()
        local offset=S.rules().targetOffset
        S.ceiling=math.max(1,math.min(count,255,base+offset))
        local target=S.ceiling
        if mm.CurrentRound==2 then
            local first=mm.RoundStates[1]
            target=math.min(first.TotalCauldronsFilled+1,target)
        end
        C.replicate(session.gs,'CauldronTarget',target,46)
        S.log('Target round=%d cauldrons=%d layout=%d offset=%d ceiling=%d target=%d',
            mm.CurrentRound,count,base,offset,S.ceiling,target)
        S.refreshHUD()
    end
    local function convertPot(row)
        local s=C.session();local g=StaticFindObject('/Script/Engine.Default__GameplayStatics')
        local t=row.actor:GetTransform()
        local pot=g:BeginDeferredActorSpawnFromClass(s.gm,S.asset(S.path(S.O,'B_ObjectiveCauldron')),t,1,nil,2)
        pot:SetReplicates(true);pot.bAlwaysRelevant=true;pot.NetDormancy=1;pot:SetOwner(row.actor)
        pot.Color=row.info.colour;pot.MinPropDistance=row.info.radius
        pot.PropClassesToAvoid=S.avoided(row.info,S.propGroups())
        g:FinishSpawningActor(pot,t,2)
        pot.GameState=s.gs;pot.Gamemode=s.gm
        pot.MinPropSphere:SetSphereRadius(row.info.radius,false)
        S.potAppearance(pot,row.info)
        hideMarker(row.actor)
        pot:FlushNetDormancy();pot:ForceNetUpdate()
        return pot
    end
    -- Loading a saved layout destroys the hunter starts the carriage carries (child actors
    -- of B_Carriage_C on Castle) and spawns free copies on the road, so hunters stayed
    -- behind (user 11-04, PROBE19). The carriage's components survive: rebuild their starts
    -- and drop the free copies.
    local carriagePath='/Game/Features/Experimental/CastleDoorSequence/B_Carriage.B_Carriage_C'
    local function restoreCarriageStarts()
        local carriages=R.find_all(carriagePath)
        if #carriages==0 then return end
        local childClass=StaticFindObject('/Script/Engine.ChildActorComponent')
        local rebuilt=0
        for _,carriage in ipairs(carriages) do
            for _,wrapped in ipairs(carriage:K2_GetComponentsByClass(childClass)) do
                local component=wrapped:get()
                if R.valid(component) and not R.valid(component.ChildActor) and R.valid(component.ChildActorClass) then
                    component:SetChildActorClass(component.ChildActorClass);rebuilt=rebuilt+1
                end
            end
        end
        if rebuilt==0 then return end
        local removed=0
        -- Witch It's starts are placeable props, not engine PlayerStarts.
        for _,start in ipairs(C.starts('hunter')) do
            if not R.valid(start:GetAttachParentActor()) then start:K2_DestroyActor();removed=removed+1 end
        end
        S.log('Carriage starts: rebuilt %d, removed %d free copies',rebuilt,removed)
    end
    local function convertLayout()
        restoreCarriageStarts()
        for _,actor in ipairs(objects) do if R.valid(actor) then actor:K2_DestroyActor() end end
        objects={}
        local rows=S.markers()
        if #rows==0 then problem=nil;return end
        local failures,warnings,pots,starts,groups=S.checkMap(rows)
        problem=failures[1]
        if problem then S.U.message('Map problems',S.mapExplanation(failures,warnings,pots,starts,groups));return end
        local looks={}
        for _,row in ipairs(pots) do
            objects[#objects+1]=convertPot(row)
            local p=row.position
            looks[#looks+1]={position={X=p.X,Y=p.Y,Z=p.Z},info=row.info}
        end
        C.net.publish('fap.cauldrons',looks)
        local s=C.session();local points={}
        for _,row in ipairs(starts) do
            local destination=row.destination
            local g=StaticFindObject('/Script/Engine.Default__GameplayStatics')
            local t=S.transform(row.actor,destination.witch)
            local point=g:BeginDeferredActorSpawnFromClass(s.gm,S.asset(S.path(S.O,'B_ObjectiveWitchRespawnPoint')),t,1,nil,2)
            point:SetReplicates(true);point:SetOwner(row.actor);g:FinishSpawningActor(point,t,2)
            objects[#objects+1]=point;points[#points+1]=point;hideMarker(row.actor)
        end
        if #points>0 then s.gm.AllWitchRespawnPoints=points end
        s.gs.Proplist:Empty();s.gs.ValidProps:Empty();s.gs:LoadPropsAndCauldrons()
        S.target()
    end
    S.onMatchHost.post(S.path(S.CORE,'B_GameMode','LoadPropLayoutFromSaveGame'),convertLayout)
    S.onModeHost.on('layout_loaded',function(info)
        if C.session().is_playtest then S.startPreview() end
    end)
    S.onMatchHost.post(S.path(S.CORE,'B_GameMode','HandleShouldGameStart'),function(gm,out)
        if problem then out:set(false) end
    end)
    S.onMatchHost.on('round_start',S.target)
    -- A guest joining a running round restarts it natively, which puts the native target
    -- back without a round_start (user 11-04: 3 instead of 7).
    -- Only then: every other restart reaches round_start, and a join after the match has
    -- ended starts a new match, whose RoundStates can be empty.
    S.onMatchHost.post(S.path(S.O,'B_ObjectiveGameMode','StartNewGameOverride'),function(_,byJoin)
        if byJoin and not S.manager().IsMatchOver then S.target() end
    end)
    S.onModeHost.post(S.path(S.O,'B_ReviveTotem','RevieWitch'),function(pot,found)
        if not found:get() then return end
        local destination=S.ground(pot)
        found:set(destination~=nil)
        if destination then pot:K2_TeleportTo(destination.witch,pot:K2_GetActorRotation()) end
    end)
    local function clientPot(pot)
        local p=pot:K2_GetActorLocation()
        for _,row in ipairs(appearances) do
            if S.distance(p,row.position)<1 then
                S.potAppearance(pot,row.info)
                return
            end
        end
    end
    C.net.watch('fap.cauldrons',function(rows)
        if S.host() then return end
        appearances=rows
        for _,pot in ipairs(R.find_all(S.path(S.O,'B_ObjectiveCauldron'))) do clientPot(pot) end
    end)
    -- A guest's cauldron gets its look from the host's rows, whenever the cauldron arrives.
    S.onMatch.actors('/Script/Engine.Actor:OnRep_Owner',S.path(S.O,'B_ObjectiveCauldron'),function(pot)
        if not S.host() then clientPot(pot) end
    end)
    -- The game's own pool of wanted props (its prop lists, made when a round loads its props)
    -- holds Common props only. Once it is made, the kinds of the other categories this map allows,
    -- with two copies or more, join it; the cauldrons then pick them and keep their copies away
    -- from the cauldron as for any prop.
    S.onModeHost.post(S.path(S.O,'B_ObjectiveGameState','GeneratePropArrays'),function(gs)
        local categories=S.categories()
        if not (categories[1] or categories[3]) then return end
        local copies,classes={},{}
        gs.AllProps:ForEach(function(_,v)
            local prop=v:get();local category=prop.PropCategory
            if category~=0 and categories[category] then
                local class=prop:GetClass();local key=class:GetAddress()
                copies[key]=copies[key] or {};table.insert(copies[key],prop);classes[key]=class
            end
        end)
        local valid=S.values(gs.ValidProps);local added=0
        for key,list in pairs(copies) do
            if #list>=2 and not gs.Proplist:Contains(classes[key]) then
                gs.Proplist:Add(classes[key],{});valid[#valid+1]=classes[key];added=added+1
            else copies[key]=nil end
        end
        -- (a new entry's copies are written into it in place)
        gs.Proplist:ForEach(function(k,v)
            local list=copies[k:get():GetAddress()]
            if list then v:get()[S.COPIES]=list end
        end)
        gs.ValidProps=valid
        S.log('Wanted props: %d kinds of the allowed categories join the pool',added)
    end)
    R.on('world_end',function() appearances={}; problem=nil;objects={};S.ceiling=nil end)
end
