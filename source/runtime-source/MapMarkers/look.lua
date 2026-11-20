-- A marker's look: its block's own parts are hidden and its kind draws the marker (def.look) out
-- of parts added to the block, and actors of its own (L.spawn). In the editor every marker shows its look; a kind with def.active(s)
-- shows it in those sessions too (a teleporter in a match). Elsewhere, Creative's Playtest among
-- them, the block stays hidden with no look (the game's own objects stand there). Parts load their
-- assets when they come.
return function(R,C,M)
    local looks,kept={},{}   -- block address -> its look; block address -> a part its look leaves alone
    local together,outline   -- (the kinds outlined together, below)
    -- A part's place: a point in the world, and its turn: yaw, pitch and roll in the world, or with
    -- no yaw the block's own turn (all three axes, as the object of a match takes it) and then the
    -- pitch and roll given.
    local function quat(yaw,pitch,roll)
        local y,p,r=math.rad(yaw)/2,math.rad(pitch or 0)/2,math.rad(roll or 0)/2
        local sy,cy,sp,cp,sr,cr=math.sin(y),math.cos(y),math.sin(p),math.cos(p),math.sin(r),math.cos(r)
        return {X=cr*sp*sy-sr*cp*cy,Y=-cr*sp*cy-sr*cp*sy,Z=cr*cp*sy-sr*sp*cy,W=cr*cp*cy+sr*sp*sy}
    end
    local function transform(actor,point,scale,yaw,pitch,roll)
        local t=actor:GetTransform()
        t.Translation=point;t.Scale3D=scale or {X=1,Y=1,Z=1}
        if yaw then t.Rotation=quat(yaw,pitch,roll)
        else
            local a,b=t.Rotation,quat(0,pitch,roll)   -- (the block's turn, then the part's own)
            t.Rotation={W=a.W*b.W-a.X*b.X-a.Y*b.Y-a.Z*b.Z,X=a.W*b.X+a.X*b.W+a.Y*b.Z-a.Z*b.Y,
                Y=a.W*b.Y-a.X*b.Z+a.Y*b.W+a.Z*b.X,Z=a.W*b.Z+a.X*b.Y-a.Y*b.X+a.Z*b.W}
        end
        return t
    end
    M.transform=transform
    -- Does a marker of this kind show its look here: in the editor, or in a session its kind is active in.
    function M.shown(def) return M.editing() or def.active~=nil and def.active(C.session()) end
    -- Only primitive parts collide (a decal or a light has no collision).
    local PRIMITIVE='/Script/Engine.PrimitiveComponent'
    local function solid(c) return c:IsA(M.asset(PRIMITIVE)) end
    local function component(actor,class,point,scale,yaw,pitch,roll)
        local full=class:find('/',1,true) and class or '/Script/'..(class=='NiagaraComponent' and 'Niagara.' or 'Engine.')..class
        local c=actor:AddComponentByClass(M.asset(full),
            true,M.transform(actor,point,scale,yaw,pitch,roll),false)
        c:SetMobility(2);c:SetComponentTickEnabled(false)
        -- The parts hang on the block: they go with it however it moves or turns (the game's gizmo,
        -- several blocks at once, the editors' own tools, the aiming preview).
        c:K2_AttachToComponent(actor.RootComponent,FName('None'),1,1,1,false)
        if solid(c) then c:SetCollisionEnabled(0);c:SetGenerateOverlapEvents(false) end
        if class=='StaticMeshComponent' then c:SetCastShadow(false) end
        return c
    end
    -- A part the editor's pointer meets (its object trace), and nothing else: no player, camera or
    -- other trace (an object trace takes no notice of the channels).
    local function clickable(c) c:SetCollisionEnabled(1);c:SetCollisionResponseToAllChannels(0) end
    -- A look's collision: the hidden block parts none, the look's parts their own. (Selecting and
    -- unselecting a block sets every mesh of it solid or not: after that, again.)
    local function settle(look)
        for _,row in ipairs(look.original) do row.part:SetCollisionEnabled(0) end
        for _,part in ipairs(look) do
            if look.clicks[part] then clickable(part) elseif solid(part) then part:SetCollisionEnabled(0) end
        end
    end
    local function drop(look,actor)
        for _,cancel in ipairs(look.loads) do cancel() end
        for _,part in ipairs(look) do part:K2_DestroyComponent(actor) end
        for _,a in ipairs(look.actors) do if R.valid(a) then a:K2_DestroyActor() end end
    end
    -- A part the looks of this block leave visible (a kind's own helper, such as a radius sphere).
    function M.keep(actor,part) kept[actor:GetAddress()]=part end
    -- A marker's label (def.label(info): its text) above it while labels are on: a widget on the
    -- screen at its place, so it faces the camera by itself.
    local HOST=C.HOST_WIDGET
    M.labels=false
    -- Give the block the look of its marker (again after a change).
    local function draw(actor,info)
        local def=M.kindOf(info)
        if not def.look then return end   -- (a kind its own editor draws)
        local key=actor:GetAddress()
        local old=looks[key]
        if old then drop(old,actor) end
        local list={original=old and old.original or {},loads={},actors={},clicks={},info=info};looks[key]=list
        if not old then
            for _,part in ipairs(M.values(actor:K2_GetComponentsByClass(M.asset('/Script/Engine.PrimitiveComponent')))) do
                if not kept[key] or part:GetAddress()~=kept[key]:GetAddress() then
                    list.original[#list.original+1]={part=part,visible=part.bVisible,collision=part:GetCollisionEnabled()}
                    part:SetVisibility(false,false)   -- (unseen, and not met either: settle)
                end
            end
        end
        if not M.shown(def) then settle(list);return end
        local p=actor:K2_GetActorLocation()
        local L={at=p,list=list}
        -- A widget on the screen at a height above the marker (z), pivot: its point there.
        local function screen(make,z,pivot)
            local pc=C.session().pc
            local w=StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary'):Create(pc,M.asset(HOST),pc)
            w.WidgetTree.RootWidget=make(w.WidgetTree)
            local part=L.part('/Script/UMG.WidgetComponent',{X=p.X,Y=p.Y,Z=p.Z+z},nil,0)
            part:SetWidgetSpace(1);part:SetDrawAtDesiredSize(true);part:SetPivot(pivot);part:SetWidget(w)
        end
        -- A picture (texture) in a colour, size by size, on the screen above the marker, as the game
        -- shows its objects (a cauldron's sign in a match: 64).
        function L.icon(texture,c,z,size)
            screen(function(tree)
                local image=StaticConstructObject(M.asset('/Script/UMG.Image'),tree)
                image:SetDesiredSizeOverride({X=size,Y=size})
                L.asset(texture,function(value) image:SetBrushFromTexture(value,false) end)
                image:SetColorAndOpacity({R=c.R,G=c.G,B=c.B,A=1})
                return image
            end,z,{X=.5,Y=.5})
        end
        function L.label(text,c) screen(function(tree)
            local words=StaticConstructObject(M.asset('/Script/UMG.TextBlock'),tree)
            local font=words.Font;font.Size=16;words:SetFont(font)
            words:SetText(FText(text))
            words:SetColorAndOpacity({SpecifiedColor={R=c.R,G=c.G,B=c.B,A=1},ColorUseRule=0})
            words:SetShadowOffset({X=1,Y=1});words:SetShadowColorAndOpacity({R=0,G=0,B=0,A=.9})
            words:SetJustification(1)
            return words
        end,150,{X=.5,Y=1}) end
        function L.asset(path,ready) list.loads[#list.loads+1]=R.native.on_asset(path,ready) end
        -- In the editor a mesh part is what a click on the marker meets.
        local editing=M.editing() and not actor.IsPreview
        function L.part(class,position,scale,yaw,pitch,roll)
            local c=component(actor,class,position or p,scale,yaw,pitch,roll);list[#list+1]=c
            if editing and (class=='StaticMeshComponent' or class=='BoxComponent') then list.clicks[c]=true;clickable(c) end
            return c
        end
        -- A mesh tinted with the marker's colour (its 'Color' parameter).
        function L.mesh(path,scale,mat)
            local c=L.part('StaticMeshComponent',p,scale)
            local function tint() R.packages.EffectKit.paint(c,info.colour) end
            L.asset(path,function(value) c:SetStaticMesh(value);tint() end)
            if mat then L.asset(mat,function(value) c:SetMaterial(0,value);tint() end) end
            return c
        end
        -- A Niagara system of the look (its user parameters: params).
        function L.niagara(path,params)
            local c=L.part('NiagaraComponent')
            L.asset(path,function(value) c:SetAsset(value,true);R.packages.EffectKit.params(c,params);c:Activate(true) end)
            return c
        end
        -- An actor of the look (a kind's real object): make(init) spawns it with init(actor) run
        -- before it starts; it is this machine's only, without collision, goes with the look and
        -- moves with the block (the aiming preview, a drag).
        -- In the editor a click on it selects the marker (its meshes again on the block, below).
        function L.spawn(make)
            local a=make(function(made) made:SetReplicates(false) end)
            if not a then return end
            a:SetActorEnableCollision(false)
            a:K2_AttachToActor(actor,FName('None'),1,1,1,false)
            if editing then
                -- (each visible mesh again on the block, unseen and fastened to the mesh, wherever it
                -- goes: the pointer's triangles, below; a mesh with no simple shape also gets its box,
                -- which the game's pointer meets first)
                for _,mesh in ipairs(M.values(a:K2_GetComponentsByClass(M.asset('/Script/Engine.StaticMeshComponent')))) do
                    local model=mesh.StaticMesh
                    if mesh:IsVisible() and model:IsValid() then
                        local copy=L.part('StaticMeshComponent',p,nil,0);copy:SetStaticMesh(model)
                        copy:K2_AttachToComponent(mesh,FName('None'),2,2,2,false);copy:SetVisibility(false,false)
                        local body=model.BodySetup
                        local shapes=body:IsValid() and body.AggGeom
                        if not (shapes and (body.CollisionTraceFlag==3 or #M.values(shapes.BoxElems)+#M.values(shapes.SphereElems)
                            +#M.values(shapes.SphylElems)+#M.values(shapes.ConvexElems)>0)) then
                            local lo,hi={},{}
                            mesh:GetLocalBounds(lo,hi)
                            local box=L.part('BoxComponent',p,nil,0)
                            box:K2_AttachToComponent(mesh,FName('None'),2,2,2,false)
                            box:K2_SetRelativeLocation({X=(lo.X+hi.X)/2,Y=(lo.Y+hi.Y)/2,Z=(lo.Z+hi.Z)/2},false,{},false)
                            -- (at least 1 cm thick: a flat mesh, a rune's plane, has none)
                            box:SetBoxExtent({X=math.max(1,(hi.X-lo.X)/2),Y=math.max(1,(hi.Y-lo.Y)/2),Z=math.max(1,(hi.Z-lo.Z)/2)},false)
                        end
                    end
                end
            end
            list.actors[#list.actors+1]=a
            return a
        end
        if def.look then def.look(actor,info,L) end
        if M.labels and def.label and M.editing() then L.label(def.label(info),info.colour or def.tint) end
        settle(list)
        if together[info.kind] then outline(actor,true) end
    end
    -- Kinds whose markers go together (def.together): while one of them is selected in the editor,
    -- every marker of its kind has the game's selection outline.
    local SELECTED=253   -- (the custom depth stencil the game's selection outline is drawn with)
    together={}    -- kind name -> true while its markers are outlined
    function outline(actor,on)
        local parts=M.values(actor:K2_GetComponentsByClass(M.asset(PRIMITIVE)))
        local look=looks[actor:GetAddress()]
        for _,a in ipairs(look and look.actors or {}) do
            if R.valid(a) then for _,c in ipairs(M.values(a:K2_GetComponentsByClass(M.asset(PRIMITIVE)))) do parts[#parts+1]=c end end
        end
        for _,c in ipairs(parts) do c:SetRenderCustomDepth(on);if on then c:SetCustomDepthStencilValue(SELECTED) end end
    end
    local function regroup()
        local pc=C.session().pc
        local now,selected={},{}
        if M.editing() and R.valid(pc) and pc.CurrentPlayMode<=2 then
            for _,actor in ipairs(M.values(pc.SelectedActors)) do
                if R.valid(actor) and not actor.IsPreview then
                    selected[actor:GetAddress()]=true
                    local info,def=M.marker(actor)
                    if info and def.together then now[info.kind]=true end
                end
            end
        end
        for _,row in ipairs(M.markers()) do
            local kind=row.info.kind
            if now[kind] then outline(row.actor,true)
            elseif together[kind] and not selected[row.actor:GetAddress()] then outline(row.actor,false) end
        end
        together=now
    end
    -- (after the game's own selection outline has changed: WorldKit tells it once a frame)
    R.packages.WorldKit.on_selection(regroup)
    -- Playtest begins or ends: the selection's outlines, and every marker drawn again, with its
    -- look or without (M.shown).
    C.on_playtest(function()
        R.next_frame(regroup)
        for _,row in ipairs(M.markers()) do M.look(row.actor,row.info) end
    end)
    -- Looks are drawn a frame after they are asked for, all of that frame together, each block once
    -- (a layout's blocks arrive and load in one go): a kind's look sees the batch's number
    -- (M.batch) to work out what the whole map has once per batch, not once per marker.
    local pending,batch,drawing={},nil,nil
    M.batch=0
    local function flush()
        batch=nil
        local list=pending;pending={}
        drawing={};M.batch=M.batch+1
        -- (each look on its own: one that fails leaves the others drawn)
        for key,row in pairs(list) do
            if R.valid(row.actor) then drawing[key]=true;R.call(draw,row.actor,row.info) end
        end
        drawing=nil
    end
    function M.look(actor,info)
        local key=actor:GetAddress()
        if drawing and drawing[key] then return end   -- (drawn in this batch, with the whole map)
        pending[key]={actor=actor,info=info}
        if not batch then batch=R.next_frame(flush) end
    end
    -- The block is no marker any more: its own parts come back.
    function M.unlook(actor)
        local key=actor:GetAddress();local old=looks[key]
        pending[key]=nil
        if not old then return end
        drop(old,actor)
        for _,row in ipairs(old.original) do row.part:SetVisibility(row.visible,false);row.part:SetCollisionEnabled(row.collision) end
        looks[key]=nil
    end

    -- Labels on and off (the key in the editor): every marker is drawn again.
    function M.toggle_labels()
        M.labels=not M.labels
        for _,row in ipairs(M.markers()) do M.look(row.actor,row.info) end
    end
    R.on('world_end',function() M.labels=false end)
    -- A block placed, moved, changed or taken away in the editor (other: its marker, nil for a block
    -- that is no marker): the markers whose look depends on it (def.depends(info, other)) are drawn
    -- again.
    function M.changed(actor,other)
        if not M.editing() then return end
        for _,row in ipairs(M.markers()) do
            if row.def.depends and (not actor or row.actor:GetAddress()~=actor:GetAddress()) and row.def.depends(row.info,other) then
                M.look(row.actor,row.info)
            end
        end
    end
    -- Blocks moved, placed or taken away in the editor (WorldKit tells it once a frame): a moved
    -- marker is drawn again where it went, and the markers that depend on other blocks once; a
    -- layout shows its markers.
    R.packages.WorldKit.on_changed(function(moved,added)
        if not M.editing() then return end
        local others=added
        for _,actor in ipairs(moved) do
            local info=M.marker(actor)
            if info then M.look(actor,info);M.changed(actor,info) else others=true end
        end
        if others then M.changed(nil,nil) end
    end)
    M.onEditor.on('layout_loaded',function()
        for _,row in ipairs(M.markers()) do M.look(row.actor,row.info) end
    end)
    -- A marker block that arrives (placed, loaded or replicated to a guest), or is there when the
    -- session's mode becomes known, gets its look: in the editor, or in a session its kind is
    -- active in. Never in a vanilla session.
    local placeable='/Game/Blueprints/StaticProps/Placeable/BP_PlaceableStaticProp.BP_PlaceableStaticProp_C'
    C.scoped(function(s) return s.mode~='vanilla' and s.mode~='none' end).actors(placeable..':InitMaterialsBySavedIndices',placeable,function(actor)
        local info,def=M.marker(actor)
        if info and M.shown(def) then M.look(actor,info) end
    end)
    for _,method in ipairs({'SelectForEditing','UnselectFromEditing'}) do
        M.onEditor.post('/Game/Blueprints/StaticProps/Placeable/BP_PlaceableActor.BP_PlaceableActor_C:'..method,function(actor)
            local look=looks[actor:GetAddress()];if look then settle(look) end
        end)
    end
    -- The editor's pointer meets the simple shapes of what is placed (a box round a sign, a hull):
    -- on a marker it meets what is seen, the shapes' triangles (both ways: a flat mesh, a rune, may
    -- show its back), and through a marker's empty space it goes on to what is behind.
    local pickable={'/Game/Blueprints/StaticProps/Placeable/BP_PlaceableActor.BP_PlaceableActor_C',
        '/Game/Blueprints/Props/Bases/B_StaticMeshProp.B_StaticMeshProp_C'}
    local function nearest(pc,ignore,from,to,best)
        local hits={}
        StaticFindObject('/Script/Engine.Default__KismetSystemLibrary'):LineTraceMultiForObjects(pc,from,to,{3,1,0},true,
            ignore,0,hits,true,{R=0,G=0,B=0,A=0},{R=0,G=0,B=0,A=0},0)
        for _,row in ipairs(hits) do
            local hit=row:get();local part=hit.Component:Get();local owner=part:GetOwner()
            local p=hit.ImpactPoint
            local d=(p.X-best.from.X)^2+(p.Y-best.from.Y)^2+(p.Z-best.from.Z)^2
            if d<best.d and not part:IsA('/Script/Engine.BoxComponent') then   -- (a look's box only catches the game's pointer)
                for _,class in ipairs(pickable) do
                    if owner:IsA(class) then best.d,best.actor=d,owner;break end
                end
            end
        end
    end
    M.onEditor.post(M.path(M.CR,'B_CreativePlayerController','TransformTrace'),function(pc,pawn,picked,axis)
        local actor=picked:get()
        if axis:get()~=4 or not R.valid(actor) or not looks[actor:GetAddress()] then return end   -- (4: no gizmo arrow)
        local from,to={},{}
        pc:GetMouseTraceStartAndEndPoints(300000,from,to)
        local best={from=from,d=math.huge}
        nearest(pc,{pawn},from,to,best);nearest(pc,{pawn},to,from,best)
        -- (a look with no surface to meet, a respawn point's ghost, keeps the game's pick: its box)
        if best.actor then picked:set(best.actor) end
    end)
    -- A block that ends takes its look with it (a deleted marker, the aiming preview).
    R.on('actor_end',function(actor,reason)
        local key=actor:GetAddress();local look=looks[key]
        if look then
            for _,cancel in ipairs(look.loads) do cancel() end
            for _,a in ipairs(look.actors) do if R.valid(a) then a:K2_DestroyActor() end end
        end
        looks[key],kept[key],pending[key]=nil,nil,nil
        -- (deleted in the editor: 0, destroyed)
        if reason==0 and actor:IsA(placeable) and not actor.IsPreview then M.changed(actor,look and look.info or M.marker(actor)) end
    end)
    R.on('world_end',function()
        for _,look in pairs(looks) do for _,cancel in ipairs(look.loads) do cancel() end end
        looks,kept,pending,batch,together={},{},{},nil,{}
    end)
end
