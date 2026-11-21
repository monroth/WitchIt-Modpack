local dir=debug.getinfo(1,'S').source:match('^@(.+[\\/])')
-- Which custom maps a map list shows. A map made for a mode (its manifest's `modes`) appears
-- only while one of those modes is chosen, also keeping it out of the vanilla modes' lists;
-- a map that needs a module this game does not have is not offered.
--   C.catalog.manifest(file)          the map's manifest, read once while the file stays the same
--   C.catalog.read(file)              read the map with the game's reader now (modules hear it)
--   C.catalog.stamp(file)             what tells the file's versions apart: its size and last bytes
--   C.catalog.keep(file,key,value)    keep a module's value about the map while the file stays the same
--   C.catalog.kept(file,key)          that value (the map is read once a session when there is none)
--   C.catalog.allowed(file,chosen)    whether a list shows the map; chosen(id) tells if mode id is chosen
--   C.catalog.card(w,map,layout,on)   a map list button for these map and layout data
-- A mode module with spec.custom_maps gets a Custom Maps tab even where the game keeps it empty
-- (Fill a Pot, Imposturous): its maps, spec.playable(file) ones only, spec.annotate(file,button);
-- spec.list(w,rows) changes the game's other lists while the mode is chosen; spec.own(file): a map
-- of the mode's own in the game's list, never in a Custom Maps tab.
--   C.catalog.view                    {all=, search=} of the Custom Maps tab: incompatible maps too (dimmed), the search
--   C.catalog.dimmed(data)            whether a map list button shows an incompatible map
--   C.catalog.plays(options)           whether the chosen saved map plays in the options' mode
--   C.catalog.chosen_needs(options)   modules the chosen saved map needs (id -> version)
--   C.catalog.picked() / unpick(o)    the saved map picked from a map list; taken back
--   C.catalog.narrow(w)               the list shows what the view lets through now
-- The map a match plays: Core is the ONE writer of the options' choice and of the game's map to open
-- (user 11-20: 'one map loads, another opens' came from eight writers). Modes ask:
--   C.catalog.choose(options,map,layout,file)  an official map (layout nil) or a saved layout on its
--                                     level; file: the map's file name as the list knows it
--   C.catalog.keep_pick(options)      the player's saved map stays chosen (a game menu cleared the flag)
--   C.catalog.opening(gi,options,next) the game opens the options' map now (next: as the next match's)
--   C.catalog.register(mm,id,map,file,layout,shot,texture)  a mode's own map in the game's lists
-- (choice.lua; install/owners.py refuses a commit where anything else writes them)
return function(R,C)
    local CUSTOM,NAME,MAP_FILE,MAP_NAME=C.LAYOUT.file,C.LAYOUT.name,C.MAP.file,C.MAP.name
    local K={}
    -- Reading a map takes the game's reader over the whole file, so what is known about a map
    -- stays on disk with the stamp of its file: Core's manifest, and what modules keep (K.keep).
    -- A map is read again only when its file changes; maps the game no longer lists are dropped.
    local SAVED='Core/maps.json'
    local stored
    local function disk()
        stored=stored or C.files.read_json(SAVED) or {}
        return stored
    end
    local saving=false
    local function save()
        if saving then return end
        saving=true
        R.next_frame(function() saving=false;C.files.write_json(SAVED,stored) end)
    end
    function K.stamp(file)
        local input=io.open(file,'rb')
        if not input then return nil end
        local size=input:seek('end')
        input:seek('set',math.max(0,size-32))
        local tail=input:read(32) or ''
        input:close()
        return size..':'..tail:gsub('.',function(c) return ('%02x'):format(c:byte()) end)
    end
    -- The entry of a file at its current stamp (a new one when the file changed), or nil.
    local function current(file)
        local stamp=K.stamp(file)
        if not stamp then return nil end
        local entry=disk()[file]
        if not entry or entry.stamp~=stamp then entry={stamp=stamp,data={}};disk()[file]=entry;save() end
        return entry
    end
    local function empty() return {needs={},modes={}} end
    -- The modes' own(file) tests (but mode except's): their own maps, put in the game's lists.
    local function owners(except)
        local out={}
        for _,m in ipairs(C.map.modes()) do local o=C.map.spec(m).own;if m~=except and o then out[#out+1]=o end end
        return out
    end
    local text,values=R.text,R.values
    -- Files checked against their stamp this session, and files read this session.
    local checked,read={},{}
    -- The game's own reader opens the file: modules hear it and keep what they count, and the
    -- native producer keeps the map record for the manifest.
    function K.read(file)
        checked[file],read[file]=true,true
        local entry=current(file)
        if not entry then R.log('Core','Map file %s not readable - no manifest',file);return end
        R.log('Core','Reading map file %s',file)
        entry.data={}
        local records=C.map.read(file)
        local manifest=records and records.manifest
        entry.manifest=manifest and R.json.decode(manifest.data) or empty()
        save()
    end
    local function entry(file)
        if not checked[file] then
            checked[file]=true
            local e=current(file)
            if e and not e.manifest then K.read(file) end
        end
        return disk()[file]
    end
    function K.manifest(file)
        local e=entry(file)
        return e and e.manifest or empty()
    end
    -- What a module keeps about a map: set while the game reads the file (its reader's hooks), or
    -- from the map as loaded; kept(file,key) reads the file once a session when nothing is kept.
    function K.keep(file,key,value)
        local e=current(file)
        if e then e.data[key]=value;save() end
    end
    function K.kept(file,key)
        local e=entry(file)
        if e and e.data[key]==nil and not read[file] then K.read(file);e=disk()[file] end
        return e and e.data[key]
    end
    -- Entries of deleted maps are dropped: those the game's list of maps (all levels) leaves out
    -- and whose file is gone (modules' own maps are not always in the list).
    local function prune(gi)
        local listed={}
        gi.MapManager.LayoutDataByFileName:ForEach(function(k) listed[text(k:get())]=true end)
        for file in pairs(disk()) do
            if not listed[file] and not K.stamp(file) then disk()[file]=nil;save() end
        end
    end
    function K.allowed(file,chosen)
        local manifest=K.manifest(file)
        for id in pairs(manifest.needs) do
            if not C.map.has(id) then return false end
        end
        if #manifest.modes==0 then return true end
        for _,id in ipairs(manifest.modes) do
            if chosen(id) then return true end
        end
        return false
    end
    -- The saved map the player picked from a map list (nil: an official one, or none since the mode
    -- changed). A mode whose menu clears the game's custom choice (Imposturous) keeps it from this;
    -- unpick takes the pick back with the options' choice.
    local picked
    R.pre('/Game/UserInterface/Maps/WB_MapListButton.WB_MapListButton_C:SetSingleMapForNextMatch',function(button)
        local file=text(button.LayoutData[CUSTOM])
        picked=file~='' and file~='None' and file or nil
    end)
    R.post('/Game/UserInterface/Play/WB_Custommatch.WB_Custommatch_C:BndEvt__ComboBox_GameMode_K2Node_ComponentBoundEvent_0_OnSelectionChanged__DelegateSignature',
        function() picked=nil end)
    function K.picked() return picked end
    dofile(dir..'choice.lua')(K,C,function() return picked end,function(file) picked=file end)
    -- Modules the chosen saved map needs (none for an official map).
    function K.chosen_needs(options)
        if not options.CustomMapSelected then return {} end
        local file=text(options.LayoutData[CUSTOM])
        return file~='' and K.manifest(file).needs or {}
    end
    -- Modules the maps of a hosted session need: the chosen map's, and those of every map the
    -- chosen mode may play next (spec.needs of a mode module).
    function K.session_needs(options)
        local all={}
        for id in pairs(K.chosen_needs(options)) do all[id]=true end
        for id in pairs(C.map.mode_needs(options)) do all[id]=true end
        return all
    end
    -- A saved layout changes its file; the next look checks the stamps again.
    R.on('layout_saved',function() checked,read={},{} end)
    local captured
    R.post('/Game/UserInterface/UIElements/MenuTileView/B_MenuTileViewManager.B_MenuTileViewManager_C:GetMapButtonData',
        function(_,_,_,_,_,_,out) captured=out:get() end)
    function K.card(w,map,layout,on)
        captured=nil
        w.TileViewManager:GetMapButtonData(on,w,map,layout,w.MenuState==1,{})
        return captured
    end
    local function chosenMode(options)
        local id=C.map.chosen(options)
        if id then return id,C.map.spec(id) end
    end
    -- What the player narrows the map lists to: all maps (the incompatible ones dimmed and still
    -- selectable) or the compatible ones, and a search: every word in the name or the file name,
    -- in any case and order, as plain text.
    -- In Creative every map opens: no map is incompatible, and the view picks maps of one kind
    -- (genre: nil all, '' the maps of no mode, or a mode's id).
    K.view={all=false,search='',genre=nil}
    local creative=C.creative
    -- Whether the options' chosen saved map plays in their mode (an official map always does;
    -- any map opens in Creative).
    function K.plays(options)
        if not options.CustomMapSelected or creative(options) then return true end
        local file=text(options.LayoutData[CUSTOM])
        if file=='' then return true end
        local id,spec=chosenMode(options)
        return K.allowed(file,function(m) return m==id end) and (not spec or not spec.playable or spec.playable(file))
    end
    function K.creative(w) return creative(w.NextMatchOptions) end
    -- The kinds of maps: {value, label} of the maps of no mode and of each mode (spec.name).
    function K.genres()
        local out={{value='',label='Normal'}}
        for _,id in ipairs(C.map.modes()) do out[#out+1]={value=id,label=C.map.spec(id).name or id} end
        return out
    end
    local function kind(genre,row)
        if genre==nil then return true end
        if genre=='' then return #row.modes==0 end
        for _,id in ipairs(row.modes) do if id==genre then return true end end
        return false
    end
    local dimmed={}
    function K.dimmed(data) return R.valid(data) and dimmed[data:GetAddress()]==true end
    local function words(query)
        local out={}
        for word in query:lower():gmatch('%S+') do out[#out+1]=word end
        return out
    end
    local function found(search,row)
        local hay=(row.name..'\n'..row.file):lower()
        for _,word in ipairs(search) do if not hay:find(word,1,true) then return false end end
        return true
    end
    -- A vanilla server plays no map that needs a module (its records stay unread): no list shows one.
    local function plain(file,vanilla) return not vanilla or next(K.manifest(file).needs)==nil end
    -- The rows of the Custom Maps tab: every saved map; ok: the chosen mode's (id; none: a map of no
    -- mode), playable and for the server it is hosted on, any in Creative.
    local function customRows(w,gi,id,spec,current,anyMode,vanilla)
        local rows={}
        -- Like the game's list: autosaves (a name ending in the manager's suffix) only with the box ticked.
        local suffix=text(gi.MapManager.AutoSaveSuffix)
        local autosaves=w.ShowAutoSave
        -- A mode's own maps (spec.own(file): put in the game's list to be played) are not saved maps.
        local all=owners()
        gi.MapManager.LayoutDataByFileName:ForEach(function(k,v)
            local file=text(k:get())
            for _,own in ipairs(all) do if own(file) then return end end
            local layout=v:get()
            local name=text(layout[NAME])
            if (autosaves or suffix=='' or name:sub(-#suffix)~=suffix) and plain(file,vanilla) then
                local ok=anyMode or K.allowed(file,function(m) return m==id end) and (not spec.playable or spec.playable(file))
                rows[#rows+1]={file=file,name=name,layout=layout,on=file==current,ok=ok,modes=K.manifest(file).modes}
            end
        end)
        table.sort(rows,function(a,b) return a.file<b.file end)
        return rows
    end
    -- The rows a list was built from (by list), and what the view lets through: items and their
    -- focus flags. A layout row gets its card when it is shown: only the game's list keeps a card,
    -- so one the view left out is gone and a new one is made (the game's cards of the Custom tab
    -- are not kept for that reason).
    local shown={}
    local narrow
    local function I(w) return w:GetAddress() end
    narrow=function(w)
        local list=shown[I(w)]
        -- The view narrows the Custom Maps tab only.
        local custom=w.CurrentMapCategory==1
        local all,search=custom and K.view.all,words(custom and K.view.search or '')
        local genre=custom and list.creative and K.view.genre or nil
        local blank=StaticFindObject('/Game/UserInterface/Maps/B_MapButtonData.B_MapButtonData_C'):GetCDO().MapData
        local items,flags={},{}
        for _,row in ipairs(list.rows) do
            if (row.ok or all) and found(search,row) and kind(genre,row) then
                if not R.valid(row.item) then
                    row.item=K.card(w,blank,row.layout,row.on)
                    if list.spec.annotate then list.spec.annotate(row.file,row.item) end
                end
                -- (each list marks its own buttons: a list built after another wiped its marks, audit 11-20)
                dimmed[row.item:GetAddress()]=not row.ok or nil
                items[#items+1]=row.item;flags[#flags+1]=row.on==true
            end
        end
        -- (on change only: a list's counts and why maps are left out)
        C.state('Core','Map list',('%d of %d maps shown (%s, search "%s")'):format(#items,#list.rows,all and 'incompatible ones too' or 'compatible ones only',custom and K.view.search or ''))
        return items,flags
    end
    -- The view changed: the list shows what it lets through of the rows it has (the game's list is
    -- not built again, its focus stays where it is).
    function K.narrow(w) w.MapListTileView:BP_SetListItems((narrow(w))) end
    R.on('world_end',function() shown,dimmed={},{} end)
    -- After the game's list: rows {item or layout, name, file, on (focused), ok (compatible)}.
    -- A mode's spec.list(w,rows) may change the game's rows (Fill a Pot's official maps).
    R.post('/Game/UserInterface/Maps/WB_MapList.WB_MapList_C:GetIndividualItemDataAndFocus',function(w,_,_,out,focus)
        local gi=StaticFindObject('/Script/Engine.Default__GameplayStatics'):GetGameInstance(w)
        prune(gi)
        local options=w.NextMatchOptions
        local id,spec=chosenMode(options)
        spec=spec or {}
        local current=options.CustomMapSelected and text(options.LayoutData[CUSTOM])
        local rows
        local anyMode=creative(options)
        local vanilla=C.mods.vanilla(options)
        -- (with no mode module chosen, the game's own list says whether its mode plays saved maps:
        -- it leaves the Custom tab empty for the modes it excludes by class, as Fill a Pot)
        local custom=id and spec.custom_maps or not id and #values(out:get())>0
        if w.CurrentMapCategory==1 and custom then rows=customRows(w,gi,id,spec,current,anyMode,vanilla)
        else
            rows={}
            -- (a mode's own maps, put in the game's lists, are not shown while another mode is chosen)
            local others=owners(id)
            local flags=values(focus:get())
            for i,item in ipairs(values(out:get())) do
                local file=text(item.LayoutData[CUSTOM])
                local mapFile=text(item.MapData[MAP_FILE])
                local foreign=false
                for _,own in ipairs(others) do if own(file) or own(mapFile) then foreign=true end end
                if not foreign and (file=='' or plain(file,vanilla)) then
                    rows[#rows+1]={item=item,on=flags[i],ok=file=='' or K.allowed(file,function(m) return C.map.selected(m,options) end)}
                end
            end
            if id and spec.list then rows=spec.list(w,rows) end
            for _,row in ipairs(rows) do
                local file=text(row.item.LayoutData[CUSTOM])
                if file~='' then row.name,row.file=text(row.item.LayoutData[NAME]),file
                else row.name,row.file=text(row.item.MapData[MAP_NAME]),text(row.item.MapData[MAP_FILE]) end
            end
        end
        shown[I(w)]={rows=rows,spec=spec,creative=anyMode}
        local items,flags=narrow(w)
        out:set(items);focus:set(flags)
    end)
    return K
end
