-- Fill a Pot+ markers in the editor (MapMarkers kinds): cauldrons (their look, colour, wanted
-- props) and witch respawn points (a ghost capsule where witches stand). A selected cauldron shows
-- its prop exclusion radius as the game's wire sphere.
return function(S)
    local R,C,U,MM=S.R,S.C,S.U,S.MM
    local radii={}
    local CR=S.CR
    local function pots() local n=0;for _,row in ipairs(S.markers()) do if row.info.kind==1 then n=n+1 end end;return n end
    -- The cauldron's panel: the cauldrons to win (the map's), its colour, rune depth and height, and
    -- the wanted props (how many kinds may be wanted, exclusion radius, include / exclude per kind).
    local cauldronPanel={colour=true,
        check=function() return 'Map check',S.mapExplanation() end,
        top=function(P)
            P.slider(P.content,'Cauldrons to win',1,math.max(1,pots()),1,'',function() return S.map.target end,
                function(value) S.setMap('target',value) end,'number')
        end,
        fields=function(P)
            local first,selected,host=P.first,P.selected,P.host
            P.number(P.content,'down','Rune depth below',0,2000,1,' UU');P.number(P.content,'up','Rune height above',0,2000,1,' UU')
            local pots=pots()
            local groups=S.propGroups();local sorted={}
            for _,group in pairs(groups) do sorted[#sorted+1]=group end
            table.sort(sorted,function(a,b) return a.name==b.name and a.path<b.path or a.name<b.name end)
            -- Wanted props, apart from the colour: a line, the exclusion radius, the allowed kinds, then the prop kinds.
            local list=P.native('VerticalBox',P.root)
            local line=P.box(list,446,2)
            P.native('Image',line):SetColorAndOpacity({R=1,G=1,B=1,A=.25})
            P.text(list,'Wanted props')
            local wanted=P.text(list,'Eligible prop kinds: —')
            P.number(list,'radius','Prop exclusion radius',0,10000,100,' UU','radius',2500)
            -- Which kinds of props may be wanted besides Common ones: the wanted props are counted again.
            for _,row in ipairs({{'secret','Allow secret props'},{'event','Allow event props'}}) do
                local key,label=row[1],row[2]
                P.checkbox(list,label,function() return S.map[key] end,function(value)
                    S.setMap(key,value);P.rebuild()
                end)
            end
            local page,typeRows=1,{}
            local paintTypes
            for i=1,4 do
                local row=P.native('HorizontalBox',list)
                local scale=P.native('ScaleBox',P.box(row,358,40));scale:SetStretch(2);scale:SetStretchDirection(1)
                local label=P.text(scale,'',12)
                local toggle=P.button(row,'Exclude',88,function()
                    local group=sorted[(page-1)*4+i]
                    if not first.excluded[group.path] then
                        local count=0;for _ in pairs(first.excluded) do count=count+1 end
                        if count==64 then S.log('Exclude refused: 64 prop kinds already excluded');U.message('Excluded props','Choose up to 64 prop kinds.');return end
                    end
                    first.excluded[group.path]=not first.excluded[group.path] or nil
                    S.MM.stamp(selected[1].actor,first);P.sync()
                end)
                typeRows[i]={row=row,label=label,button=toggle}
            end
            local nav=P.native('HorizontalBox',list)
            local previous=P.button(nav,'Previous',100,function() page=page-1;paintTypes() end)
            local status=P.text(P.box(nav,246,36),'',12)
            local nextButton=P.button(nav,'Next',100,function() page=page+1;paintTypes() end)
            paintTypes=function()
                local pool=S.eligible({info=first,position=selected[1].actor:K2_GetActorLocation()},groups)
                local eligible={};for _,group in ipairs(pool) do eligible[group.path]=true end
                wanted:SetText(FText('Eligible prop kinds: '..#pool..' (needs '..(pots+1)..') '..(#pool>=pots+1 and '✓' or '✗')))
                for i,row in ipairs(typeRows) do
                    local group=sorted[(page-1)*4+i];row.row:SetVisibility(group and 0 or 1)
                    if group then
                        local distance=math.huge
                        for _,prop in ipairs(group.props) do distance=math.min(distance,S.distance(selected[1].actor:K2_GetActorLocation(),prop.position)^.5) end
                        local excluded=first.excluded[group.path]==true
                        row.label:SetText(FText((group.path:match('%.(.+)$') or group.name)..'\n'..#group.props..' copies; nearest '..string.format('%.0f UU',distance)..'; '
                            ..(excluded and 'excluded' or eligible[group.path] and 'eligible' or 'ineligible')))
                        row.label:SetToolTipText(FText(group.path..'\n'..group.name))
                        row.button.LabelText=FText(excluded and 'Include' or 'Exclude');row.button.Label:SetText(row.button.LabelText)
                        row.button:SetIsEnabled(host and (excluded or eligible[group.path]==true))
                    end
                end
                local pages=math.max(1,math.ceil(#sorted/4))
                status:SetText(FText('Page '..page..'/'..pages..' · '..#sorted..' types'))
                previous:SetIsEnabled(host and page>1);nextButton:SetIsEnabled(host and page<pages)
            end
            P.repaint(paintTypes)
        end}
    MM.kind({name=1,code=1,record=S.codec.ID,carriers=S.carriers[1],title=S.names[1],
        description='Place at least three cauldrons. Select one to choose its colour and wanted props. Use Playtest to check the map.',
        icon='/Game/UserInterface/PropCollection/PlacableActorIcons/BP_WitchCauldron_C.BP_WitchCauldron_C',
        defaults=S.codec.defaults,panel=cauldronPanel,
        look=function(actor,info,L)
            local key=actor:GetAddress()
            if radii[key] then radii[key]:SetSphereRadius(info.radius,false) end
            L.mesh('/Game/ObjectiveModeContent/SM_Cauldron01.SM_Cauldron01',{X=1.2,Y=1.2,Z=1.2})
            L.mesh('/Game/ObjectiveModeContent/SM_CauldronFluid.SM_CauldronFluid')
            -- (the game's stretch, 2.2, for the top; down to the runes' depth: S.rays)
            S.rays(L.mesh('/Game/ObjectiveModeContent/SM_PotRuneRays.SM_PotRuneRays',{X=1.28,Y=1.28,Z=2.2}),S.RAYS_HIGH*2.2,info.down)
            -- (the cauldron's sign on the screen, in its colour, as in a match)
            L.icon('/Game/ObjectiveModeContent/T_ObjectiveFillStatusActive.T_ObjectiveFillStatusActive',info.colour,90,64)
            -- (the runes' box as in a match: from the depth below to the height above - user 11-20, it was
            -- centred on the cauldron, so Rune depth below 0 still drew 16 cm under it, through a roof)
            local at=actor:K2_GetActorLocation()
            local decal=L.part('DecalComponent',{X=at.X,Y=at.Y,Z=at.Z+(info.up-info.down)/2},nil,nil,-90)
            decal.DecalSize={X=(info.down+info.up)/2,Y=256,Z=256}
            L.asset('/Game/ObjectiveModeContent/M_CauldronDecal.M_CauldronDecal',function(value)
                R.packages.EffectKit.decal(decal,value,info.colour,{scalars={Fill=1}})
            end)
        end})
    MM.kind({name=2,code=2,record=S.codec.ID,carriers=S.carriers[2],title=S.names[2],
        description='Place on the ground: the capsule shows witch spawn; revive totems sit on the surface. Keep ordinary player starts for match start.',
        icon='/Game/UserInterface/CreativeMode/CollectionUtilityIconWitchStart.CollectionUtilityIconWitchStart',
        defaults=S.codec.defaults,together=true,panel={check=function() return 'Map check',S.mapExplanation() end},
        look=function(actor) S.ghost(actor) end,cleared=S.clearGhost})

    -- The selected cauldrons' exclusion radius: the game's wire sphere (left alone by their look).
    local function selection(pc)
        if not R.valid(pc) then return end
        local selected={}
        if S.editing() and pc:IsLocalController() and pc.CurrentPlayMode<=2 then
            for _,actor in ipairs(S.values(pc.SelectedActors)) do
                if R.valid(actor) and not actor.IsPreview then
                    local info=S.marker(actor)
                    if info and info.kind==1 then selected[actor:GetAddress()]={actor=actor,info=info} end
                end
            end
        end
        for key,sphere in pairs(radii) do
            if not selected[key] then sphere:K2_DestroyComponent(sphere:GetOwner());radii[key]=nil end
        end
        for key,row in pairs(selected) do
            if not radii[key] then
                -- Native SphereComponent draws the original three wire circles, with its default colour.
                local sphere=row.actor:AddComponentByClass(S.asset('/Script/Engine.SphereComponent'),false,
                    {Translation={X=0,Y=0,Z=0},Rotation={X=0,Y=0,Z=0,W=1},Scale3D={X=1,Y=1,Z=1}},false)
                radii[key]=sphere;MM.keep(row.actor,sphere)
                sphere:SetCollisionEnabled(0);sphere:SetGenerateOverlapEvents(false)
                sphere:SetMobility(2);sphere:SetAbsolute(false,true,true)
                sphere:SetVisibility(true,false);sphere:SetHiddenInGame(false,false)
            end
            radii[key]:SetSphereRadius(row.info.radius,false)
        end
    end
    -- (WorldKit tells a change of the selection once a frame)
    R.packages.WorldKit.on_selection(selection)
    C.on_playtest(function() R.next_frame(function() selection(C.session().pc) end) end)
    R.on('actor_end',function(actor) radii[actor:GetAddress()]=nil end)
    R.on('world_end',function() radii={} end)
end
