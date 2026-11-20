-- Teleporters by markers: an entrance block and an exit block with the same number make a
-- teleporter in any match the host runs and in Creative's Playtest (the host's teleporter zones
-- replicate to guests). The markers are MapMarkers kinds saved as the map record
-- `monroth.teleport` (version 1), as JSON:
--   {"kind":"entrance"|"exit","colour":[r,g,b],"look":1,"pair":7,"two_way":false}
-- In memory: info.kind 'entrance' or 'exit', colour {R,G,B,A}, look 0..4, pairId, twoWay.
return function(R,C,U,MM)
    local ID,VERSION='monroth.teleport',1
    local ZONE='/Game/Blueprints/StaticProps/B_TeleporterZone.B_TeleporterZone_C'
    -- Placed on MapMarkers' green screen; rune stones of older maps stay teleporters.
    local CARRIERS={MM.GREEN_SCREEN,MM.RUNE_STONE}
    local LOOKS={'None','Island portal','Tower pad','Doorway','Colored rune'}
    R.native.load_asset(ZONE)
    -- A map with teleporters needs World edits to play.
    C.map.module(ID,{})
    local function defaults(info)
        local pink=MM.colour.PINK
        info.colour=info.colour or {R=pink.R,G=pink.G,B=pink.B,A=pink.A}
        -- A new teleporter shows where it stands; a chosen None stays.
        info.look=info.look or 1
        info.twoWay=info.twoWay==true
        return info
    end
    MM.record({id=ID,version=VERSION,
        decode=function(data)
            local d=R.json.decode(data)
            if type(d)~='table' or (d.kind~='entrance' and d.kind~='exit') then return end
            local c=d.colour
            return defaults({kind=d.kind,colour=c and {R=c[1],G=c[2],B=c[3],A=1},look=d.look,pairId=d.pair,twoWay=d.two_way})
        end,
        encode=function(info)
            return R.json.encode({kind=info.kind,colour={info.colour.R,info.colour.G,info.colour.B},look=info.look,pair=info.pairId,two_way=info.kind=='entrance' and info.twoWay or nil})
        end})
    local function markers() return MM.markers(ID) end
    -- Two-way is the pair's, kept on its entrance only (audit 11-20: both ends held it and the build
    -- took either): an exit asks its entrance.
    local function twoWay(info)
        if info.kind=='entrance' then return info.twoWay end
        for _,row in ipairs(markers()) do
            if row.info.kind=='entrance' and row.info.pairId==info.pairId then return row.info.twoWay end
        end
        return false
    end
    -- The first number with no marker of this kind yet.
    local function nextPair(kind)
        local used={}
        for _,row in ipairs(markers()) do if row.info.kind==kind and row.info.pairId then used[row.info.pairId]=true end end
        local id=1
        while used[id] do id=id+1 end
        return id
    end
    -- The look: the chosen one, and in the editor a box to select it by and its number above it.
    local function look(actor,info,L)
        local p=L.at
        if info.look==1 then
            -- (every machine's own; in the editor a click anywhere on the portal selects it)
            L.asset('/Game/Blueprints/Unused/ObjectiveMode/B_WitchPortalVisualOnly.B_WitchPortalVisualOnly_C',function(class)
                L.spawn(function(init) return R.native.spawn_local(class,actor,p,function(a) init(a);a:SetActorTickEnabled(false) end) end)
            end)
        elseif info.look==2 then
            local name=info.kind=='entrance' and 'NS_TowerPortalEntrance' or 'NS_TowerPortalExit'
            L.niagara('/Game/Effects/Tower/'..name..'.'..name)
        elseif info.look==3 then
            local root='/Game/Environment/WitchHouse/WitchPortal/'
            local mat=info.kind=='entrance' and 'MI_WitchPortalTwistEntry' or 'MI_WitchPortalTwistExit'
            L.mesh(root..'SM_WitchPortal.SM_WitchPortal',nil,root..mat..'.'..mat)
        elseif info.look==4 then
            L.mesh('/Game/Environment/WitchForest/SM_RuneRayCircle.SM_RuneRayCircle',nil,
                '/Game/Environment/WitchForest/MI_RuneRaysGreen.MI_RuneRaysGreen')
        end
        if MM.editing() and not actor.IsPreview then
            local selector=L.part('BoxComponent',{X=p.X,Y=p.Y,Z=p.Z+75})
            selector:SetBoxExtent({X=50,Y=50,Z=75},false);selector:SetCollisionObjectType(0)
            selector:SetCollisionResponseToAllChannels(0);selector:SetCollisionEnabled(1)
            local text=L.part('TextRenderComponent',{X=p.X,Y=p.Y,Z=p.Z+115})
            text:K2_SetText(FText('Teleporter '..tostring(info.pairId)..(twoWay(info) and ' ↔' or info.kind=='entrance' and ' →' or ' ←')))
            text:SetWorldSize(18);text:SetHorizontalAlignment(1)
        end
    end
    -- What is wrong with the level's teleporters (warnings) and its complete pairs.
    local function check()
        local warnings,pairs_={},{}
        for _,row in ipairs(markers()) do
            local id=row.info.pairId
            local pair=pairs_[id] or {entrance={},exit={}};pairs_[id]=pair
            pair[row.info.kind][#pair[row.info.kind]+1]=row
        end
        local complete={}
        for id,pair in pairs(pairs_) do
            if #pair.entrance~=1 or #pair.exit~=1 then warnings[#warnings+1]='Teleporter '..id..' needs one entrance and one exit.'
            else complete[#complete+1]={entrance=pair.entrance[1],exit=pair.exit[1]} end
        end
        return warnings,complete
    end
    local function explanation()
        local warnings,complete=check()
        local lines={}
        for _,why in ipairs(warnings) do lines[#lines+1]='Map warning: '..why end
        lines[#lines+1]='Teleporters: '..#complete..' numbered pair(s).'
        return 'Map check',table.concat(lines,'\n')
    end
    local panel={colour=true,check=explanation,
        colourFields=function(P)
            local first=P.first
            local pair=P.text(P.content,'Teleporter number: '..first.pairId);pair.Slot:SetHorizontalAlignment(2)
            for _,spec in ipairs({{'−',-1},{'+',1}}) do
                P.button(P.content,spec[1],446,function()
                    P.change('pairId',math.max(1,math.min(4294967295,first.pairId+spec[2])))
                    pair:SetText(FText('Teleporter number: '..first.pairId))
                end)
            end
            local check=P.cooked(P.el,'WB_CheckBoxWithEditableLabel',P.box(P.content,446,36))
            check.DescriptiveLabel=FText('Two-way');check.DescriptiveLabelText:SetText(check.DescriptiveLabel)
            check:SetIsCheckedWithoutEvent(twoWay(first));check:SetIsEnabled(P.host)
            P.action(check,{check=function()
                local value=check.CheckBox:IsChecked()
                if value==twoWay(first) then return end
                -- (set on the pair's entrance; both ends show it)
                for _,row in ipairs(markers()) do
                    if row.info.pairId==first.pairId then
                        if row.info.kind=='entrance' then
                            local before={};for k,v in pairs(row.info) do before[k]=v end
                            row.info.twoWay=value;MM.stamp(row.actor,row.info)
                            MM.changed(row.actor,before);MM.changed(row.actor,row.info)   -- (the zones follow)
                        end
                        MM.look(row.actor,row.info)
                    end
                end
            end})
            local choice=P.cooked(P.el,'WB_ComboBoxWithLabel',P.box(P.content,446,40))
            choice.DescriptiveLabel=FText('Look');choice.DescriptiveLabelText:SetText(choice.DescriptiveLabel)
            choice.Options:Empty()
            for index,label in ipairs(LOOKS) do choice.Options[index]=FText(label) end
            choice:SetOptionIndex(first.look);choice:SetIsEnabled(P.host)
            -- The native row keeps a third of its width empty and pads the combo; the dropdown follows the combo.
            local combo=choice.ComboboxSizeSwitcher;local grid=combo:GetParent()
            grid:SetColumnFill(0,.35);grid:SetColumnFill(1,.65);grid:SetColumnFill(2,0)
            combo.Slot:SetPadding({Left=8,Right=0,Top=0,Bottom=0})
            P.action(choice,{select=function()
                if choice.SelectedOptionIndex~=first.look then P.change('look',choice.SelectedOptionIndex) end
            end})
        end}
    -- Teleporters show in any session but a vanilla one (guests too: the zones the host makes act).
    local function active(s) return s.mode~='vanilla' and s.mode~='none' end
    local icon='/Game/UserInterface/CreativeMode/CollectionUtilityIconWitchStart.CollectionUtilityIconWitchStart'
    for _,kind in ipairs({
        {name='entrance',code=3,title='Teleporter entrance',tint={R=0,G=.65,B=1,A=1},
            description='Teleports players to the exit with the same number. Select to change the number and look.'},
        {name='exit',code=4,title='Teleporter exit',tint={R=1,G=.65,B=0,A=1},
            description='Players arrive in front of this marker, facing its direction. Pair with an entrance with the same number.'}}) do
        kind.record,kind.carriers,kind.icon,kind.active,kind.panel=ID,CARRIERS,icon,active,panel
        kind.defaults=defaults
        kind.created=function(info) info.pairId=info.pairId or nextPair(info.kind) end
        kind.look=look
        MM.kind(kind)
    end

    -- The zones: an entrance sends players to its exit (and back when two-way). The host makes
    -- them as the layout of a match loads and as Playtest starts; they go with the level, or
    -- when Playtest ends.
    local zones={}
    local function clear() for _,z in ipairs(zones) do if R.valid(z) then z:K2_DestroyActor() end end;zones={} end
    local function build()
        clear()
        local s=C.session()
        local function zone(entry,exit)
            local dest=exit.position
            local z=R.native.spawn(ZONE,s.gm,entry.position,function(a)
                a:SetReplicates(true);a:SetReplicateMovement(true);a.bAlwaysRelevant=true;a:SetActorEnableCollision(false)
            end)
            local target=z.TargetLocation
            target.RelativeLocation={X=dest.X,Y=dest.Y,Z=dest.Z+92}
            target.RelativeRotation={Pitch=0,Yaw=exit.actor:K2_GetActorRotation().Yaw,Roll=0}
            target:SetAbsolute(true,true,false);target:SetIsReplicated(true)
            z.Zone:SetBoxExtent({X=100,Y=100,Z=125},false)
            R.native.teleporter_exit(z,exit.actor)
            z:SetActorEnableCollision(true);z.Zone:SetGenerateOverlapEvents(true);z:ForceNetUpdate()
            zones[#zones+1]=z
            return z
        end
        local _,complete=check()
        for _,pair in ipairs(complete) do
            local a,b=pair.entrance,pair.exit
            MM.look(a.actor,a.info);MM.look(b.actor,b.info)
            local entrance=zone(a,b)
            if a.info.twoWay then R.native.teleporter_pair(entrance,zone(b,a)) end
        end
    end
    local host=C.scoped(function(s) return active(s) and s.role~='client' end)
    host.on('layout_loaded',function() if not C.session().is_creative then build() end end)
    local CR='/Game/Blueprints/Gamemodes/CreativeMode/'
    host.post(CR..'B_CreativePlayerController.B_CreativePlayerController_C:ChangePlayerMode',function(pc)
        if pc.CurrentPlayMode==3 and C.session().gs.IsPlayTestMode then build() else clear() end
    end)
    host.playtest(function(s) if s.is_playtest and s.pc.CurrentPlayMode==3 then build() end end)
    R.pre(CR..'B_CreativeGameMode.B_CreativeGameMode_C:EndPlayTest',clear)
    R.on('world_end',function() zones={} end)
end
