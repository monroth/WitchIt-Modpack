return function(S)
    local R,C=S.R,S.C
    local pointClass=S.path(S.O,'B_ObjectiveWitchRespawnPoint')
    local starts={'/Game/Blueprints/StaticProps/Placeable/Utility/BP_WitchPlayerStart.BP_WitchPlayerStart_C',
        '/Game/Blueprints/Player/PlayerStarts/B_WitchPlayerStart.B_WitchPlayerStart_C'}
    local attempts={}
    function S.prepareRespawns()
        local s=C.session()
        local points=S.values(s.gm.AllWitchRespawnPoints)
        if #points>0 then return points end
        points=R.find_all(pointClass)
        local options=C.options(s)
        if #points==0 and not options.CustomMapSelected and not options.MapData[S.F.builtin] then
            for _,path in ipairs(starts) do
                local candidates=R.find_all(path)
                if #candidates>0 then
                    for _,start in ipairs(candidates) do
                        local p,r=start:K2_GetActorLocation(),start:K2_GetActorRotation()
                        points[#points+1]=R.native.spawn(pointClass,s.gm,{X=p.X,Y=p.Y,Z=p.Z,Yaw=r.Yaw},function(a)
                            a:SetReplicates(true);a.bAlwaysRelevant=true
                        end)
                    end
                    break
                end
            end
        end
        s.gm.AllWitchRespawnPoints=points
        return points
    end
    S.onMatchHost.pre(S.path(S.O,'B_ObjectiveGameMode','SpawnReviveTotem'),function() S.prepareRespawns() end)
    -- (an observer, as before 11-21: with a pre hook nothing ran at all on the cauldron's call)
    local tries=0   -- (the game's tries for a witch's respawn: it tries every frame until one works)
    S.onMatchHost.observe(S.path(S.O,'B_ObjectiveGameMode','RespawnWitch'),function(gm)
        local points=S.prepareRespawns()
        local attempt={points=points,poses={}}
        attempts[#attempts+1]=attempt
        local safe={}
        for _,point in ipairs(points) do
            local destination=S.ground(point)
            if destination then
                local p,r,scale=point:K2_GetActorLocation(),point:K2_GetActorRotation(),point:GetActorScale3D()
                attempt.poses[#attempt.poses+1]={actor=point,position={X=p.X,Y=p.Y,Z=p.Z},
                    rotation={Pitch=r.Pitch,Yaw=r.Yaw,Roll=r.Roll},scale={X=scale.X,Y=scale.Y,Z=scale.Z},
                    moved=S.distance(p,destination.witch)>.0001}
                point.RootComponent:SetMobility(2);point:SetActorScale3D({X=1,Y=1,Z=1})
                if attempt.poses[#attempt.poses].moved then
                    point:K2_TeleportTo(destination.witch,{Pitch=0,Yaw=r.Yaw,Roll=0})
                end
                safe[#safe+1]=point
            end
        end
        gm.AllWitchRespawnPoints=safe
        -- The game respawns a witch only at a point no hunter is within 30 m of, and tries again every frame
        -- until there is one: on a small map with the hunters about, never (user 11-21: a witch waited for
        -- minutes). With no such point, a random one: the game is given it 50 m up (clear of every hunter) and
        -- the witch is put down on it right after.
        local hunters=R.find_all('/Game/Blueprints/Player/Pawns/B_Hunter.B_Hunter_C')
        local function free(point)
            local p=point:K2_GetActorLocation()
            for _,h in ipairs(hunters) do if R.valid(h) and S.distance(p,h:K2_GetActorLocation())<3000*3000 then return false end end   -- (S.distance is squared, as the game's VSizeSquared < 9 000 000)
            return true
        end
        local any=false
        for _,point in ipairs(safe) do if free(point) then any=true;break end end
        -- (what the game will weigh, in the log as it changes: each point's nearest hunter and who the hunters are -
        -- live 11-21 a witch never respawned although a point looked free)
        local near,names={},{}
        for _,point in ipairs(safe) do
            local p,best=point:K2_GetActorLocation(),math.huge
            for _,h in ipairs(hunters) do if R.valid(h) then best=math.min(best,S.distance(p,h:K2_GetActorLocation())) end end
            near[#near+1]=('%.0f'):format(math.sqrt(best)/100)
        end
        for _,h in ipairs(hunters) do if R.valid(h) then local ps=R.valid(h.PlayerState);names[#names+1]=h:GetClass():GetFName():ToString()..(ps and (' '..R.text(ps:GetPlayerName())) or ' (no player)') end end
        tries=tries+1
        if tries%120==1 then S.log('Witch respawn try %d - nearest hunter per point (m): %s; hunters: %s',tries,table.concat(near,' '),table.concat(names,', ')) end
        if not any and #safe>0 then
            local point=safe[math.random(#safe)]
            local p,r=point:K2_GetActorLocation(),point:K2_GetActorRotation()
            attempt.down={position={X=p.X,Y=p.Y,Z=p.Z},rotation={Pitch=0,Yaw=r.Yaw,Roll=0},actor=point}
            point.RootComponent:SetMobility(2);point:K2_TeleportTo({X=p.X,Y=p.Y,Z=p.Z+5000},{Pitch=0,Yaw=r.Yaw,Roll=0})
            gm.AllWitchRespawnPoints={point}
            S.log('Witch respawn: every point has a hunter within 30 m - a random one')
        else
            S.log('Witch respawn: %d of %d points on ground',#safe,#points)
        end
    end)
    S.onMatchHost.post(S.path(S.O,'B_ObjectiveGameMode','RespawnWitch'),function(gm,controller)
        local attempt=table.remove(attempts)
        if attempt.down then
            local d=attempt.down
            d.actor:K2_TeleportTo(d.position,d.rotation)
            local pawn=R.valid(controller) and R.valid(controller:K2_GetPawn())
            if pawn then pawn:K2_TeleportTo(d.position,d.rotation) end
            S.log('Witch respawn: put down at the random point (%s)',pawn and 'done' or 'no witch spawned')
        end
        for _,row in ipairs(attempt.poses) do
            row.actor:SetActorScale3D(row.scale)
            if row.moved then row.actor:K2_TeleportTo(row.position,row.rotation) end
        end
        gm.AllWitchRespawnPoints=attempt.points
    end)
    function S.groundTotem(totem)
        local destination=S.ground(totem)
        if not destination then S.log('Revive totem removed: no safe ground near it');totem:SetActorEnableCollision(false);totem:K2_DestroyActor();return false end
        totem.RootComponent:SetMobility(2);totem:SetActorScale3D({X=1,Y=1,Z=1})
        totem:K2_TeleportTo(destination.marker,{Pitch=0,Yaw=totem:K2_GetActorRotation().Yaw,Roll=0})
        return true
    end
    R.on('world_end',function() attempts={};tries=0 end)
end
