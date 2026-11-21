-- The witches' hot/cold orb (the game's WB_DivineOrb, fed by GetPropClosePercent on the witch's own
-- client): its range as a rule, and EffectKit's wisps in the witches' violet drifting from the
-- witch toward every prop a cauldron wants within reach, each stream by its own distance: at the
-- edge of the range a faint, slow few,
-- closer more, faster, brighter and less transparent, each ending at the prop's surface; right at
-- the prop they leave it all around. A witch's own: hunters have none, and no one else sees them
-- (each machine makes its own).
return function(S)
    local R,C=S.R,S.C
    local E=R.packages.EffectKit
    -- How much: the edge of the range fainter and fewer, close brighter (user 11-20: the steep curve
    -- of 11-17 left them barely seen - gentler now, and a visible floor).
    local function look(closeness)
        local k=closeness^2
        local glow=1.4*(.6+1.4*k)   -- (a bit brighter than in the editor's preview: the game's light)
        return {SpawnRate=2+16*k,Color={R=.45*glow,G=.15*glow,B=glow,A=.4+.6*k}}
    end
    local sparks=E.pointers({path=E.WISPS,rate=look,reach={speed=function(c) return 60+240*c end,drag=E.WISPS_DRAG}})
    -- Too near to drift toward it (touching it, under 30 cm to its surface): wisps leave the prop all
    -- around, fast enough to come out of it.
    local size=0
    local around=E.pointers({path=E.WISPS_AROUND,rate=function(c) local p=look(c);p.Speed=40+size;p.Lifetime=1;return p end})
    -- Where the prop's own surface is nearest the witch, and how far (user 11-20: measured to a sphere round
    -- the prop - much bigger than a long or flat prop - the wisps never reached it and turned to leaving it
    -- while she was still away). The prop's collision itself; without one, its bounds' sphere.
    local MESH='/Script/Engine.StaticMeshComponent'
    local function surface(actor,at)
        local mesh=R.valid(actor:GetComponentByClass(StaticFindObject(MESH)))
        local out={}
        local d=mesh and mesh:GetClosestPointOnCollision(at,out,FName('None'))
        if d and d>=0 then return d,{X=out.X,Y=out.Y,Z=out.Z} end
        local origin,extent={},{}
        actor:GetActorBounds(false,origin,extent,false)
        local r=math.sqrt(extent.X^2+extent.Y^2+extent.Z^2)*.8
        local to=actor:K2_GetActorLocation()
        local dist=math.sqrt(S.distance(at,to))
        local k=math.min(1,r/math.max(dist,1))
        return math.max(0,dist-r),{X=to.X+(at.X-to.X)*k,Y=to.Y+(at.Y-to.Y)*k,Z=to.Z+(at.Z-to.Z)*k}
    end
    -- Each frame of the orb (divination.lua, which looks over the free wanted props for both): the
    -- wisps toward each of near ({prop, d cm}, those within the rule's reach).
    -- (what the wisps do and why, in the log as it changes - live 11-20 a witch beside a wanted prop saw none)
    function S.indicate(pawn,near)
        local rules=S.rules()
        local from=(rules.propSparksFrom or 6)*100
        local witch=C.side(pawn.PlayerState)=='witch'
        C.state('FillAPotPlus','Prop sparks',not rules.propSparks and 'off - the rule is off' or not witch and 'off - not a witch'
            or ('on - wanted props within %d m: %d'):format(from//100,#near))
        if rules.propSparks and witch then
            local at=pawn:K2_GetActorLocation()
            for _,n in ipairs(near) do
                local key,to=tostring(n.prop:GetAddress()),n.prop:K2_GetActorLocation()
                local gap,point=surface(n.prop,at)
                local closeness=math.max(0,1-gap/from)
                if gap<30 then
                    local origin,extent={},{}
                    n.prop:GetActorBounds(false,origin,extent,false)
                    size=math.sqrt(extent.X^2+extent.Y^2+extent.Z^2)*.8
                    around:aim(key,pawn,to,{X=to.X,Y=to.Y,Z=to.Z+100},closeness)
                else sparks:aim(key,pawn,at,point,closeness) end   -- (to the nearest point of its surface)
            end
        end
        sparks:done();around:done()
    end
end
