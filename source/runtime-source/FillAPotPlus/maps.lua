return function(S)
    local R,C=S.R,S.C
    local F,L=S.F,S.L
    local definitions=dofile(S.dir..'bundles.lua')
    -- The game calls both its Grunewald levels Grunewald Library; Fill a Pot+ tells them apart (by the
    -- level's file, the game's own key - live VM2 11-20: /Game/Maps/GameMaps/Library/LibraryHalloween is the
    -- night town, Fill a Pot's own map; .../Library the day one).
    local stockNames={LibraryHalloween='Grunewald at Night',Library='Grunewald at Day'}
    function S.stockName(map)
        local file=S.text(map[F.file])
        return stockNames[file:match('([^/]+)$')] or S.text(map[F.name])
    end
    -- What a map holds for Fill a Pot (pots, respawns, ...): Core's catalogue keeps it while the
    -- file stays the same, counted when the game's reader reads the file or from the map as loaded.
    local KEY,TARGET='FillAPotPlus','FillAPotPlus.target'
    -- (the cauldrons to win are the map record's, kept apart: the game reads a map file without Core
    -- too, and then only the blocks are counted)
    local function counts(file)
        local kept=C.catalog.kept(file,KEY)
        if not kept then return nil end
        local info={}
        for k,v in pairs(kept) do info[k]=v end
        info.target=C.catalog.kept(file,TARGET)
        return info
    end
    C.map.on_read(function(file,records)
        local r=records[S.codec.ID]
        C.catalog.keep(file,TARGET,S.codec.decodeMap(r and r.data).target)
    end)
    local reader='/Script/PropWitchHuntModule.ProjectVersionBlueprint:'
    local function readMetadata(_,success,path,props,workshop,statics,lights,switches,prefabs)
        if not success then return end
        props,statics,prefabs=props:get(),statics:get(),prefabs:get()
        local info={pots=0,respawns=0,classes=0}
        local function scan(rows)
            rows:ForEach(function(_,value)
                local row=value:get();local bytes={}
                row.MaterialIndices:ForEach(function(_,byte) bytes[#bytes+1]=string.char(byte:get()) end)
                local _,records=C.map.split(table.concat(bytes))
                local r=records and records[S.codec.ID]
                local marker=r and S.codec.decode(r.data)
                local name=S.text(row.PrimaryAssetId.PrimaryAssetName):gsub('_C$','')
                local carried=false
                for _,path in ipairs(marker and S.carriers[marker.kind] or {}) do
                    if name==path:match('%.(.+)$'):gsub('_C$','') then carried=true end
                end
                if not carried then return end
                if marker.kind==1 then info.pots=info.pots+1
                elseif marker.kind==2 then info.respawns=info.respawns+1 end
            end)
        end
        scan(statics)
        prefabs:ForEach(function(_,value) scan(value:get().Structures) end)
        local counts={}
        props:ForEach(function(_,value)
            local name=S.text(value:get().PrimaryAssetId.PrimaryAssetName)
            counts[name]=(counts[name] or 0)+1
            if name~='' and counts[name]==2 then info.classes=info.classes+1 end
        end)
        C.catalog.keep(S.text(path),KEY,info)
    end
    for _,name in ipairs({'LoadPropLayoutFromFile','LoadPropLayoutFromFileCompressed'}) do R.post(reader..name,readMetadata) end
    local bundled,byId={},{}
    -- Bundled maps by id or layout file; file paths compare without case or slash style.
    local function key(file) return (file:gsub('\\','/'):lower()) end
    local function bundle(file) return byId[key(file)] end
    local manager
    local buttonClass='/Game/UserInterface/Maps/B_MapButtonData.B_MapButtonData_C'
    local function leaf(value) return value:gsub('\\','/'):match('([^/]+)$') end
    function S.baseMap(level)
        local result
        C.session().gi.MapManager.MapDataByFileName:ForEach(function(_,v)
            local map=v:get();local file=S.text(map[F.file])
            if file==level or leaf(file)==leaf(level) then result=map end
        end)
        return result
    end
    -- The game's own Fill a Pot maps: five cauldrons, three to fill (one place).
    S.STOCK={pots=5,target=3,stock=true}
    function S.registerBundles()
        local gi=C.session().gi
        local mm=gi.MapManager
        if manager==mm:GetAddress() then return end
        manager=mm:GetAddress();bundled={};byId={}
        S.log('Registering %d bundled maps (loading their pictures from disk)',#definitions)
        for _,d in ipairs(definitions) do
            local file=S.dir..'bundled-maps/'..d.key..'.pl'
            local id='FAPB:'..d.key
            local holder=S.new(buttonClass,gi)
            holder.MapData=S.baseMap(d.world)
            holder.MapData[F.file]=FName(id)
            local name=d.name or S.text(holder.MapData[F.name])   -- (else the game's own name of that level)
            holder.MapData[F.name]=FText(name)
            holder.MapData[F.objective]=true;holder.MapData[F.builtin]=false
            holder.LayoutData[L.name]=name;holder.LayoutData[L.file]=file
            holder.LayoutData[L.map]=leaf(d.world);holder.LayoutData[L.type]=1
            holder.LayoutData[L.screenshot]=S.dir..'bundled-maps/'..d.preview
            local texture=StaticFindObject('/Script/PropWitchHuntModule.Default__ImageLoader'):
                LoadImageFromDisk(gi,holder.LayoutData[L.screenshot])
            if R.valid(texture) then holder.MapData[F.preview]=texture else S.log('Bundled map %s: picture %s not loaded - the game\'s own picture',d.key,tostring(holder.LayoutData[L.screenshot])) end
            if not R.valid(holder.MapData) then S.log('Bundled map %s: level %s not found',d.key,d.world) end
            C.catalog.register(mm,id,holder.MapData,file,holder.LayoutData,holder.LayoutData[L.screenshot],R.valid(texture))
            -- (a map of a featured level is on the Featured tab, the others on the Official one)
            -- (its cauldrons and respawns: counted from its file like any map - audit 11-20: they were
            -- written again in bundles.lua)
            local row={file=file,id=id,world=d.world,name=name,def=d,info=counts(file),kind='bundle',featured=d.world:find('/UserMaps/',1,true)~=nil}
            bundled[#bundled+1]=row;byId[key(id)]=row;byId[key(file)]=row
        end
    end
    function S.mapData(row)
        return C.session().gi.MapManager.MapDataByFileName:Find(row.id or row.file):get()
    end
    local EVENTS,LAYOUTS='MapLayouts_48_AE297EC34B13F1944AB59AA0ADAD72B1','Layouts_19_A000B3E94244355BDF441A9F8E04F536'
    -- A copy of a map's data whose layout list (list(data): the list's entry) holds one of its layouts
    -- at random (copied before Empty: FSoftWorldReference remains an opaque native value); nil: none.
    local function pinned(gi,data,list)
        local layouts=list(data)[LAYOUTS]
        local count=layouts:GetArrayNum()
        if count==0 then return nil end
        local selected=layouts[math.random(count)]
        local stage=S.new(buttonClass,gi);stage.MapData=data
        local target=list(stage.MapData)[LAYOUTS]
        target:Empty();target[1]=selected
        return stage.MapData
    end
    function S.pinStock(row)
        local gi=C.session().gi
        local holder=S.new(buttonClass,gi)
        holder.MapData=S.mapData(row)
        local events=holder.MapData[EVENTS]
        local keys={}
        events:ForEach(function(k) keys[#keys+1]=k:get() end)
        for _,key in ipairs(keys) do
            local function entry(data) return data[EVENTS]:Find(key):get() end
            local copy=pinned(gi,holder.MapData,entry)
            if copy then events:Add(key,entry(copy)) end
        end
        holder.MapData=pinned(gi,holder.MapData,function(data) return data[F.layouts] end) or holder.MapData
        return holder.MapData
    end
    function S.layoutData(row)
        S.registerBundles()
        return C.session().gi.MapManager.LayoutDataByFileName:Find(row.file):get()
    end
    function S.playable(info)
        return not info or (info.pots>=3 and info.respawns>0 and info.classes>=info.pots+1)
    end
    function S.catalogue()
        S.registerBundles()
        local pools={vanilla={},official={},featured={},custom={}}
        for _,row in ipairs(bundled) do table.insert(row.featured and pools.featured or pools.official,row) end
        local mm=C.session().gi.MapManager
        local seen={}
        for _,key in ipairs({'SmallMapList','BigMapList','QuickmatchMapList'}) do
            for _,map in ipairs(S.values(mm[key])) do
                local file=S.text(map[F.file])
                if map[F.objective] and not map[F.builtin] and file~='RandomMapCycle' and not seen[file] then
                    seen[file]=true
                    pools.vanilla[#pools.vanilla+1]={file=file,name=S.stockName(map),kind='stock',info=S.STOCK}
                end
            end
        end
        mm.LayoutDataByFileName:ForEach(function(k,v)
            local layout=v:get();local file=S.text(k:get())
            local ownFile=S.text(layout[L.file])
            if not ownFile:find('[\\/]') and file:find('[\\/]') then layout[L.file]=file end
            if not bundle(file) and S.playable(counts(file)) and C.catalog.allowed(file,function(id) return id==S.codec.ID end) then
                pools.custom[#pools.custom+1]={file=file,name=S.text(layout[L.name]),kind='custom',info=counts(file)}
            end
        end)
        table.sort(pools.custom,function(a,b) return a.name==b.name and a.file<b.file or a.name<b.name end)
        C.state('FillAPotPlus','Map pools',('%d game, %d official, %d featured, %d custom maps'):format(#pools.vanilla,#pools.official,#pools.featured,#pools.custom))
        return pools
    end
    function S.currentMap()
        local options=C.options()
        if options.CustomMapSelected then
            local file=S.text(options.LayoutData[L.file])
            return bundle(file) or {file=file,name=S.text(options.LayoutData[L.name]),kind='custom',info=counts(file)}
        end
        local file=S.text(options.MapData[F.file])
        return {file=file,name=S.stockName(options.MapData),kind='stock',info=S.STOCK}
    end
    function S.selectMap(options,row)
        if row.kind=='stock' then C.catalog.choose(options,S.mapData(row))
        else
            local layout=S.layoutData(row)
            C.catalog.choose(options,S.baseMap(row.world or S.text(layout[L.map])),layout)
        end
    end
    local function bundleEntry(_,gi)
        if R.valid(gi) and S.selected(gi.NextMatchOptions) then S.registerBundles() end
    end
    R.post(S.path(S.MATCH,'B_MapManager','Initialize'),bundleEntry)
    R.post(S.path(S.MATCH,'B_MapManager','SetLayoutDataByFileName'),function(mm)
        manager=nil
        if not S.selected(C.session().gi.NextMatchOptions) then return end
        S.registerBundles()
    end)
    local quantities={}
    local function describe(info)
        local label=S.calc.quantity(info)
        return {label=label,details='Cauldrons to win / total: '..label..
            (info.stock and '\nOriginal Fill a Pot map' or info.respawns and '\nWitch respawn markers: '..info.respawns or '')}
    end
    local function card(w,row,current)
        local layout=row.kind=='stock' and S.asset(buttonClass):GetCDO().LayoutData or S.layoutData(row)
        local data=C.catalog.card(w,S.mapData(row),layout,current)
        quantities[data:GetAddress()]=row.info and describe(row.info) or nil
        return data
    end
    -- Core builds this mode's Custom Maps tab; Fill a Pot+ says which maps play and labels them.
    local spec=C.map.spec(S.codec.ID)
    spec.custom_maps=true
    function spec.playable(file) return S.playable(counts(file)) end
    -- The modpack's maps are on the Official Maps tab.
    function spec.own(file) return bundle(file)~=nil end
    function spec.annotate(file,button) local info=counts(file);quantities[button:GetAddress()]=info and describe(info) or nil end
    -- The official maps tab: the game's maps with their cauldron counts, then the modpack's maps
    -- and the random cycle.
    function spec.list(w,rows)
        -- (the game's tabs: 0 Official, 1 Custom Maps (Core's), 2 Featured)
        if w.CurrentMapCategory==1 then return rows end
        local out={}
        local current=w.NextMatchOptions.CustomMapSelected and S.text(w.NextMatchOptions.LayoutData[L.file])
            or S.text(w.NextMatchOptions.MapData[F.file])
        local function add(item,selected) out[#out+1]={item=item,on=selected,ok=true} end
        -- The Featured tab: the modpack's maps of featured levels only.
        local featuredTab=w.CurrentMapCategory==2
        for _,row in ipairs(featuredTab and {} or rows) do
            local file=S.text(row.item.MapData[F.file])
            if file~='RandomMapCycle' and not bundle(file) then
                if row.item.MapData[F.objective] then quantities[row.item:GetAddress()]=describe(S.STOCK) end
                row.item.MapData[F.name]=FText(S.stockName(row.item.MapData))
                add(row.item,file==current)
            end
        end
        for _,row in ipairs(bundled) do
            if row.featured==featuredTab then
                local selected=row.file==current or row.id==current
                add(card(w,row,selected),selected)
            end
        end
        if w.MenuState==0 and not featuredTab then
            local random=S.new(buttonClass,C.session().gi)
            random.MapData=C.session().gi.MapManager.RandomMapCycle;random.MapData[F.objective]=true
            local data=C.catalog.card(w,random.MapData,S.asset(buttonClass):GetCDO().LayoutData,current=='RandomMapCycle')
            quantities[data:GetAddress()]={label='',details=''}
            add(data,current=='RandomMapCycle')
        end
        return out
    end
    local function quantity(w)
        if not S.selected(StaticFindObject('/Script/Engine.Default__GameplayStatics'):GetGameInstance(w).NextMatchOptions) then return end
        local data=w.ItemData
        return R.valid(data) and quantities[data:GetAddress()] or nil
    end
    R.post('/Game/UserInterface/Maps/WB_MapButton.WB_MapButton_C:GetQuantityText',function(w,out)
        local value=quantity(w)
        if value then out:set(FText(value.label)) end
    end)
    R.post('/Game/UserInterface/Maps/WB_MapButton.WB_MapButton_C:GetPlayernumberText',function(w)
        local value=quantity(w)
        if value then return FText(value.label) end
    end)
    for _,asset in ipairs({'WB_MapButton','WB_MapListButton'}) do
        R.post('/Game/UserInterface/Maps/'..asset..'.'..asset..'_C:GetQuantityVisibility',function(w,out)
            local value=quantity(w)
            if value then out:set(value.label~='') end
        end)
    end
    R.post('/Game/UserInterface/Maps/WB_MapListButton.WB_MapListButton_C:GetTooltip',function(w,out)
        local value=quantity(w)
        local tip=out:get()
        if not value or not R.valid(tip) then return end
        tip.Playernumber=FText(value.label);tip.Instructions=FText(value.details)
        tip.PlayernumberText:SetText(FText(value.label));tip.PlayernumberText:SetVisibility(4)
        tip.MapCycleInstructions:SetText(FText(value.details));tip.MapCycleInstructions:SetVisibility(4)
    end)
    R.post('/Game/UserInterface/Maps/WB_MapListButton.WB_MapListButton_C:SetSingleMapForNextMatch',function(w)
        local gi=StaticFindObject('/Script/Engine.Default__GameplayStatics'):GetGameInstance(w)
        if not S.selected(gi.NextMatchOptions) then return end
        local row=bundle(S.text(w.ItemData.MapData[F.file]))
        if row then S.selectMap(gi.NextMatchOptions,row) end
    end)
    -- Leaving Fill a Pot+ drops a modpack map: other modes never load our layouts.
    S.modeChanged=function(plus,options)
        C.state('FillAPotPlus','Bundled maps in the list',plus and 'shown (the mode is chosen)' or 'dropped - the mode is not chosen')
        if plus then return end
        local picked=options.CustomMapSelected and bundle(S.text(options.LayoutData[L.file]))
        local row=bundle(S.text(options.MapData[F.file]))
        if picked then C.catalog.choose(options,S.baseMap(picked.world))
        elseif row then C.catalog.choose(options,S.baseMap(row.world),options.CustomMapSelected and options.LayoutData or nil) end
    end
    R.post(S.path(S.MATCH,'B_MapManager','GetSpecificMapOrCustomMapFromFileName'),function(mm,file,foundMap,foundLayout,map,layout)
        if not S.selected(C.session().gi.NextMatchOptions) then C.state('FillAPotPlus','Bundled map lookup','left to the game - another mode is chosen');return end
        S.registerBundles()
        local row=bundle(S.text(file))
        if row then
            foundMap:set(false);foundLayout:set(true);map:set(S.baseMap(row.world));layout:set(S.layoutData(row))
        end
    end)
    R.post(S.path(S.MATCH,'B_MapManager','UpdateNextMapFromCustomMapCycle'),function(mm,options)
        if not R.valid(options) or not S.selected(options) then return end
        S.registerBundles()
        local row=bundle(S.text(options.MapData[F.file]))
        if options.CustomMapSelected then row=bundle(S.text(options.LayoutData[L.file])) end
        if row then S.selectMap(options,row) end
    end)
    R.pre(S.path(S.CORE,'B_GameInstance','OpenMatchByOptions'),function(gi)
        if not R.valid(gi) then return end
        if not S.selected(gi.UsedMatchOptions) or not S.host() then return end
        S.registerBundles()
        local options=gi.UsedMatchOptions
        -- A picked layout decides; MapData can still name an earlier pick (user 11-04).
        local row
        if options.CustomMapSelected then row=bundle(S.text(options.LayoutData[L.file]))
        else row=bundle(S.text(options.MapData[F.file])) end
        if not options.CustomMapSelected and S.text(options.MapData[F.file])=='RandomMapCycle' then
            local pools=S.catalogue();local candidates={}
            for _,pool in ipairs({pools.vanilla,pools.official}) do for _,v in ipairs(pool) do candidates[#candidates+1]=v end end
            row=candidates[math.random(#candidates)]
        end
        S.log('Opening the match map: %s',row and tostring(row.name or row.file) or 'the game\'s own choice')
        if row then S.selectMap(options,row);C.catalog.opening(gi,options) end
    end)
    local function observe(info)
        local markers=S.markers();local pots,starts=0,0
        for _,row in ipairs(markers) do
            if row.info.kind==1 then pots=pots+1 elseif row.info.kind==2 then starts=starts+1 end
        end
        local classes=0
        for _,group in pairs(S.propGroups(S.categories())) do if #group.props>=2 then classes=classes+1 end end
        C.catalog.keep(info.layout_id,KEY,{pots=pots,respawns=starts,classes=classes})
        C.catalog.keep(info.layout_id,TARGET,S.map.target)
    end
    S.onModeHost.on('layout_saved',observe);S.onModeHost.on('layout_loaded',observe)
    R.on('world_end',function() manager=nil;bundled={};byId={};quantities={} end)
    -- Map cycles: the game hides its Create Map Cycle button in Fill a Pot. In Fill a Pot+ a button
    -- of the same class and caption stands in its place and calls the game's own click.
    local LIST='/Game/UserInterface/Maps/WB_MapList.WB_MapList_C:'
    local stand={}
    local function cycleButton(w)
        local native=w.CreateMapCycle
        local id=w:GetAddress()
        local own=R.valid(stand[id])
        local plus=S.selected(w.NextMatchOptions)
        if plus and not own then
            -- (beside the game's own, which its binding keeps collapsed in Fill a Pot)
            own=S.U.button(native:GetParent(),{class=native:GetClass(),label=S.text(native.Text),on_click=function()
                w:BndEvt__WB_MapList_CreateMapCycle_K2Node_ComponentBoundEvent_5_Clicked__DelegateSignature()
            end})
            stand[id]=own
        end
        if own then own:SetVisibility(plus and w.MenuState==0 and 0 or 1) end
    end
    R.post(LIST..'InitializeMenu',cycleButton)
    R.post(LIST..'SetMenuState',cycleButton)
end
