-- Map data in layouts (MAPDATA.md). Records on blocks belong to modules; the map record
-- holds each module's data for the whole map and the manifest Core derives from them.
--   C.map.records(actor)                    -> {[id]={version=,data=}} of one block
--   C.map.write(actor,id,version,data)      one record of a block; nil data removes it
--   C.map.module(id,spec)                   spec.save() returns version,data for the whole map, or nil;
--                                           spec.mode with spec.selected(options): the module is a mode,
--                                           spec.plays(session): this session plays it (its session mode);
--                                           spec.package/spec.name: the mod that registered it, its name;
--                                           spec.optional: maps play without it (editor data)
--   C.map.has(id), C.map.selected(id,options)
--   C.map.on_load(fn)                       fn(records,manifest) for each loaded layout
--   C.map.loaded                            the records of the layout loaded last
--   C.map.read(file)                        the records of a layout file on disk (nil when it has none)
--   C.map.on_read(fn)                       fn(file,records) for each layout file read so (its map record's
--                                           records: a module's whole-map data, as on_load gives it)
--   C.map.set_bytes(actor,list)             a block's whole byte list (materials and records) - the ONE
--                                           writer of SavedMaterialIndices (replicated)
local dir=debug.getinfo(1,'S').source:match('^@(.+[\\/])')
return function(R,C)
    local codec=dofile(dir..'mapdata.lua')
    local M={loaded={},manifest={needs={},modes={}},split=codec.split,read_list=codec.read_list}
    local modules,listeners,readers={},{},{}
    local blocks='/Game/Blueprints/StaticProps/Placeable/BP_PlaceableStaticProp.BP_PlaceableStaticProp_C'

    local function bytes(actor)
        local parts={}
        actor.SavedMaterialIndices:ForEach(function(_,v) parts[#parts+1]=string.char(v:get()) end)
        return table.concat(parts)
    end
    function M.records(actor)
        local _,records=codec.split(bytes(actor))
        return assert(records,'broken map data on '..actor:GetFullName())
    end
    function M.write(actor,id,version,data)
        local game,records=codec.split(bytes(actor))
        assert(game,'broken map data on '..actor:GetFullName())
        records[id]=data and {version=version,data=data} or nil
        local joined=codec.join(game,records)
        local array={};for i=1,#joined do array[i]=joined:byte(i) end
        -- The byte array replicates; guests see the change at once.
        M.set_bytes(actor,array)
    end
    -- (audit 11-20: WorldKit's undo wrote the list itself, unreplicated: guests kept the old bytes)
    function M.set_bytes(actor,array)
        C.replicate(actor,'SavedMaterialIndices',array,10)
    end
    -- The mod that registers a module owns it; a mode's name in lists is the mod's name.
    function M.module(id,spec)
        assert(codec.valid_id(id) and id~='map' and not id:find('^core%.'),'module id '..id)
        spec.package=R.owner('Core')
        spec.name=R.mod_name(spec.package)
        modules[id]=spec
    end
    function M.on_load(fn) listeners[#listeners+1]=fn end
    function M.on_read(fn) readers[#readers+1]=fn end
    function M.has(id) return modules[id]~=nil end
    function M.spec(id) return modules[id] end
    function M.modes()
        local ids={};for id,spec in pairs(modules) do if spec.mode then ids[#ids+1]=id end end
        table.sort(ids);return ids
    end
    -- Modules the maps of the chosen mode may need (spec.needs()).
    function M.mode_needs(options)
        local all={}
        for id,spec in pairs(modules) do
            if spec.mode and spec.needs and spec.selected(options) then for need in pairs(spec.needs()) do all[need]=true end end
        end
        return all
    end
    -- The mode module the options choose (nil: none).
    function M.chosen(options) for _,id in ipairs(M.modes()) do if modules[id].selected(options) then return id end end end
    function M.selected(id,options) local spec=modules[id];return spec~=nil and spec.mode==true and spec.selected(options)==true end
    -- Whether a map using this module's records needs it to play; unknown modules keep the map's word.
    local function needed(id)
        if modules[id] then return not modules[id].optional end
        return M.manifest.needs[id]~=nil
    end

    -- The manifest follows from the map: a module is needed when its records are on a
    -- block or in the map record; a needed mode module is one of the map's modes.
    local function map_record()
        local whole,needs={},{}
        -- Data of modules not installed here stays as it came.
        for id,r in pairs(M.loaded) do
            if id~='manifest' and not modules[id] then whole[id]=r;if needed(id) then needs[id]=r.version end end
        end
        for id,spec in pairs(modules) do
            local version,data
            if spec.save then version,data=spec.save() end
            if data then whole[id]={version=version,data=data};if needed(id) then needs[id]=version end end
        end
        for _,actor in ipairs(R.find_all(blocks)) do
            for id,r in pairs(M.records(actor)) do
                if id~='map' and needed(id) and (not needs[id] or needs[id]<r.version) then needs[id]=r.version end
            end
        end
        local modes={}
        local was={};for _,id in ipairs(M.manifest.modes) do was[id]=true end
        for id in pairs(needs) do
            if modules[id] and modules[id].mode or not modules[id] and was[id] then modes[#modes+1]=id end
        end
        table.sort(modes)
        if next(whole)==nil and next(needs)==nil then return '' end
        whole.manifest={version=1,data=R.json.encode({needs=needs,modes=modes})}
        return codec.list(whole)
    end
    R.native.on_save(function(event)
        if event.phase=='entry' then R.native.map_record_set(map_record()) end
    end)
    R.on('layout_loaded',function(info)
        local body=R.native.map_record_take(info.layout_id) or ''
        local _,records=codec.read_list(body)
        M.loaded=assert(records,'broken map record in '..info.layout_id)
        M.manifest=records.manifest and R.json.decode(records.manifest.data) or {needs={},modes={}}
        R.log('Core','Map record %d bytes, modes %s',#body,table.concat(M.manifest.modes,','))
        for _,fn in ipairs(listeners) do fn(M.loaded,M.manifest,info) end
    end)
    -- The game's own reader opens the file; the native producer keeps its map record.
    local library='/Script/PropWitchHuntModule.Default__ProjectVersionBlueprint'
    function M.read(file)
        local input=io.open(file,'rb')
        if not input then R.log('Core','Map file %s cannot be opened',file);return nil end
        local header=input:read(8) or ''
        input:close()
        local reader=StaticFindObject(library)
        if #header==8 and string.unpack('<I8',header)==0x222222229e2a83c1 then
            reader:LoadPropLayoutFromFileCompressed(file,{},{},{},{},{},{},{})
        else reader:LoadPropLayoutFromFile(file,{},{},{},{},{},{},{}) end
        local _,records=codec.read_list(R.native.map_record_take(file) or '')
        if records then for _,fn in ipairs(readers) do fn(file,records) end end
        return records
    end
    R.on('world_end',function() M.loaded,M.manifest={},{needs={},modes={}} end)
    return M
end
