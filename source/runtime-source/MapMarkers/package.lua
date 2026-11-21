-- MapMarkers: marker blocks of a map. A mod registers the records its markers are saved in
-- (M.record) and its kinds of marker (M.kind); MapMarkers puts the kinds into Creative's Utility
-- palette, marks a placed block with its kind's record, gives markers their look, keeps them
-- through copy and paste (the game's prefab colour), and hosts their settings in the edit
-- screen (panel.lua). The marker blocks themselves are ordinary placeable blocks of the game.
local dir=debug.getinfo(1,'S').source:match('^@(.+[\\/])')
return function(R,C,U)
    local M={colour=dofile(dir..'colour.lua')}
    local records,kinds,codes={},{},{}   -- record id -> spec; kind name -> def; prefab code -> def
    local known={}   -- block address -> {info, def} or false (M.marker)
    local CR='/Game/Blueprints/Gamemodes/CreativeMode/'
    local function path(folder,name,method) return folder..name..'.'..name..'_C'..(method and ':'..method or '') end
    local values=R.values
    local function asset(p) return R.native.load_asset(p) end
    M.values,M.asset,M.path,M.CR=values,asset,path,CR
    -- A kind's icon on an image of the game's (its tint, else white).
    function M.icon(image,def) image:SetBrushFromTexture(asset(def.icon),false);image:SetColorAndOpacity(def.tint or {R=1,G=1,B=1,A=1}) end

    -- Where markers are edited: Creative outside Playtest (the host places and changes them).
    local function editing(s) return s.mode=='creative' and R.valid(s.gs) and not s.is_playtest end
    function M.editing() return editing(C.session()) end
    function M.host() return C.owns() end
    M.onEditor=C.scoped(editing)
    M.onEditorHost=C.scoped(function(s) return editing(s) and C.owns(s) end)

    -- spec: id (the map record), version, decode(data) -> info (info.kind: a kind's name) or nil,
    -- encode(info) -> data.
    function M.record(spec) records[spec.id]=spec end
    -- def: name (info.kind), record (its record id), carriers (block class paths: the first is the
    -- one placed - the game's green screen, plain where the mod is missing - the others older
    -- markers' blocks that stay markers), code (prefab code:
    -- fixed, saved prefabs keep it; without one the kind is not in the palette), title, description, icon (texture), tint, defaults(info) ->
    -- info, created(info) (fills in what a placed marker lacks), look(actor, info, L),
    -- fields(P) (its settings, panel.lua), depends(info, other) (its look shows something of
    -- another marker, other, or of the map's other blocks, other nil: look.lua's M.changed),
    -- cleared(actor) (its block stops being this marker), together (while one is selected in the
    -- editor every marker of the kind is outlined, and its panel tells how many).
    function M.kind(def) kinds[def.name]=def;if def.code then codes[def.code]=def end;known={} end
    -- Is the block one of def's carriers?
    function M.carries(def,actor)
        for _,path in ipairs(def.carriers) do if actor:IsA(path) then return true end end
        return false
    end
    -- The block placed for markers: the green screen, a plain block that does nothing in the game.
    M.GREEN_SCREEN='/Game/Blueprints/StaticProps/Placeable/StaticProps/BP_Greenscreen.BP_Greenscreen_C'
    -- (the rune stone: the carrier of older maps' markers, Fill a Pot+'s respawns and World edits' teleporters)
    M.RUNE_STONE='/Game/Blueprints/StaticProps/Placeable/StaticProps/BP_WitchRuneStone01.BP_WitchRuneStone01_C'
    function M.kindOf(info) return info and kinds[info.kind] end
    function M.kindByCode(code) return codes[code] end

    -- The marker on a block: info, its kind; nil for any other block. A block's answer is kept until
    -- its saved data changes (stamped here, or applied by the game: loaded, pasted, received) or it
    -- ends: the editor asks for every block often (each move), and reading a block's data is slow.
    local function read(actor)
        local carrier=false
        for _,def in pairs(kinds) do if M.carries(def,actor) then carrier=true;break end end
        if not carrier then return end
        local found=C.map.records(actor)
        for id,spec in pairs(records) do
            local r=found[id]
            local info=r and spec.decode(r.data)
            local def=info and kinds[info.kind]
            if def and M.carries(def,actor) then
                return info,def
            end
        end
    end
    local function copy(v)
        if type(v)~='table' then return v end
        local out={};for key,value in pairs(v) do out[key]=copy(value) end
        return out
    end
    function M.marker(actor)
        local address=actor:GetAddress()
        local k=known[address]
        if k==nil then
            local info,def=read(actor)
            k=info and {info,def} or false
            known[address]=k
        end
        -- (a copy: the kept answer changes only through M.stamp - audit C19, a caller changed the kept one)
        if k then return copy(k[1]),k[2] end
    end
    local function forget(actor) known[actor:GetAddress()]=nil end
    R.post('/Game/Blueprints/StaticProps/Placeable/BP_PlaceableActor.BP_PlaceableActor_C:InitMaterialsBySavedIndices',forget)
    R.on('actor_end',forget)
    R.on('world_end',function() known={} end)
    R.on('layout_loaded',function() known={} end)
    -- Every marker in the level (of one record when given): {actor, info, def, position}.
    function M.markers(record)
        local rows,seen={},{}
        for _,def in pairs(kinds) do
            if not record or def.record==record then
                for _,path in ipairs(def.carriers) do
                    if not seen[path] then
                        seen[path]=true
                        for _,actor in ipairs(R.find_all(path)) do
                            local info,kind=M.marker(actor)
                            -- (the aiming preview is no marker of the map)
                            if info and not actor.IsPreview and (not record or kind.record==record) and not seen[actor:GetAddress()] then
                                seen[actor:GetAddress()]=true
                                rows[#rows+1]={actor=actor,info=info,def=kind,position=actor:K2_GetActorLocation()}
                            end
                        end
                    end
                end
            end
        end
        return rows
    end
    -- Save info as the block's marker (its kind's record).
    function M.stamp(actor,info)
        local def=kinds[info.kind];local spec=records[def.record]
        C.map.write(actor,spec.id,spec.version,spec.encode(info))
        forget(actor)
    end
    function M.unstamp(actor,def) C.map.write(actor,def.record);forget(actor) end
    -- How many markers of each record a map file holds: counted as the game reads the file, kept
    -- with it (C.catalog), so a map list knows without opening the map.
    local COUNTS='mapmarkers.counts'
    local function count(_,success,path,props,workshop,statics,lights,switches,prefabs)
        if not success then return end
        local n={}
        local function scan(rows)
            rows:ForEach(function(_,value)
                local bytes={}
                value:get().MaterialIndices:ForEach(function(_,byte) bytes[#bytes+1]=string.char(byte:get()) end)
                local _,found=C.map.split(table.concat(bytes))
                for id in pairs(found or {}) do if records[id] then n[id]=(n[id] or 0)+1 end end
            end)
        end
        scan(statics:get())
        prefabs:get():ForEach(function(_,value) scan(value:get().Structures) end)
        C.catalog.keep(R.text(path),COUNTS,n)
    end
    for _,name in ipairs({'LoadPropLayoutFromFile','LoadPropLayoutFromFileCompressed'}) do
        R.post('/Script/PropWitchHuntModule.ProjectVersionBlueprint:'..name,count)
    end
    function M.counts(file) return C.catalog.kept(file,COUNTS) or {} end

    dofile(dir..'look.lua')(R,C,M)
    R.key('mapmarkers.labels','0',function() if M.editing() then M.toggle_labels() end end,
        {label='Marker labels',tip='Show or hide the markers\' labels',context='Creative'})
    dofile(dir..'palette.lua')(R,C,M)
    M.panel=dofile(dir..'panel.lua')(R,C,U,M)
    return M
end
