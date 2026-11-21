-- World edits: the edits a map makes to its base world (hidden scenery, source geometry), saved
-- in the layout and applied with it for everyone in the session (the host sends them to its
-- guests), teleporters by marker blocks (teleporters.lua), and World Properties on every Creative map
-- (world_properties.lua). Editing the hidden set goes
-- through the API returned here (Editor tweaks' hide tool).
local dir=debug.getinfo(1,'S').source:match('^@(.+[\\/])')
local Objects=dofile(dir..'objects.lua')
local Instances=dofile(dir..'instances.lua')
local Geometry=dofile(dir..'geometry.lua')
local Store=dofile(dir..'store.lua')
return function(R,C,U)
    local files=Store.new(R)
    dofile(dir..'teleporters.lua')(R,C,U,assert(R.packages.MapMarkers,'World edits needs MapMarkers'))
    dofile(dir..'world_properties.lua')(R,C)
    do
        local leaves=dofile(dir..'leaf_assets.lua')
        R.log('BaseWorldPlus','Loading %d leaf assets of the base world (each load is logged by the runtime)',#leaves)
        for _,path in ipairs(leaves) do R.native.load_asset(path) end
    end
    -- World edits never touch a vanilla session.
    local hooks=C.scoped(function(s) return s.mode~='vanilla' end)
    -- A modded Creative session's edits of the world reach guests through this mod.
    C.mods.require(C.creative)
    local state,host_value,return_data
    local function log(fmt,...) R.log('BaseWorldPlus',fmt,...) end
    local own_copy
    -- The edits a guest plays: those the host sent, or the guest's own copy of the shipped map.
    local function resolve(value) return value.data or own_copy(value.source,value.world) end
    -- A map shipped in a mod's folder is on every guest's disk too (its mod is the host's
    -- version): the host names it and its edits' checksum, and each guest reads them there.
    local mods=dir:match('^(.*[\\/])[^\\/]+[\\/]$')
    local function shipped(layout) if layout and layout:sub(1,#mods)==mods then return layout:sub(#mods+1) end end
    local function checksum(text)
        local h=2166136261
        for i=1,#text,4096 do
            for _,b in ipairs({text:byte(i,i+4095)}) do h=((h~b)*16777619)&0xffffffff end
        end
        return h
    end
    local read={}   -- path..checksum -> the edits read from a guest's own copy
    own_copy=function(source,world)
        local key=source.path..':'..source.sum
        if read[key] then return read[key] end
        local records=C.map.read(mods..source.path)
        local record=records and records[Store.ID]
        if not record or checksum(record.data)~=source.sum then
            log('World edits of %s differ from the host\'s copy',source.path);return nil
        end
        read[key]=files.decode(record.data,world)
        return read[key]
    end
    local world_id=C.level
    local function lookup(path) return R.valid(StaticFindObject(path)) end
    local row_key=Store.key

    local function restore_one(s,key)
        local r=s.originals[key];if not r then return end
        if R.valid(r.object) then
            if r.row.kind=='actor' then Objects.restore(r.original)
            elseif r.row.kind=='component' then Objects.componentSet(r.original,false)
            else Instances.set(r.object,r.row,false) end
        end
        s.originals[key]=nil
    end
    local function clear()
        if not state then return end
        local s=state;state=nil
        for key in pairs(s.originals) do restore_one(s,key) end
        for _,actor in ipairs(s.spawned) do if R.valid(actor) then R.native.destroy(actor) end end
        if #s.spawned>0 then R.native.release_source_actors() end
    end
    local function apply_one(s,key,row)
        if s.originals[key] then return end
        local object=lookup(row.path)
        if not object then log('Object missing: %s',row.path);return end
        local original
        if row.kind=='actor' then
            if not Objects.allowed(object) then log('Object is not scenery: %s',row.path);return end
            original=Objects.capture(object)
        elseif row.kind=='component' then
            object=Objects.component(object,row.component)
            if not object then log('Component missing: %s %s',row.path,row.component);return end
            original=Objects.componentCapture(object)
        end
        s.originals[key]={row=row,object=object,original=original}
        if row.kind=='actor' then Objects.hide(original);log('Scenery hidden: %s',object:GetFullName())
        elseif row.kind=='component' then Objects.componentSet(original,true)
        else Instances.set(object,row,true) end
    end
    -- Guests receive the edits through Core's transport.
    -- (the state's kinds: none, applied (data), unread (a record kept as it came, no data) - only an
    -- applied state has edits to send; audit 11-20: an unread one failed here at every save)
    local function publish()
        if not (state and state.host and state.data) then return end
        -- {layout, world, and the shipped copy's source or the edits themselves}
        C.net.publish('bwp.world',{layout=state.layout,world=state.data.world,source=state.source,data=not state.source and state.data or nil})
    end
    -- Restored source actors are the map's, not the layout's: the editor cannot change or save
    -- them, so while editing they do not collide (clicks reach what is behind an invisible wall);
    -- in Playtest and matches they do.
    local MM=R.packages.MapMarkers
    local function collide(s)
        local on=not MM.editing()
        for _,actor in ipairs(s.spawned) do if R.valid(actor) then actor:SetActorEnableCollision(on) end end
    end
    C.on_playtest(function() if state then collide(state) end end)
    local function replace(info,data,source)
        clear()
        local s={world=info.world,layout=info.layout_id,host=info.host,data=data,originals={},
            spawned={},is_playtest=C.session().is_playtest,source=source}
        state=s
        local count=0;for _ in pairs(data.hidden) do count=count+1 end
        log('Apply world=%s host=%s hidden=%d geometry=%d',data.world,tostring(info.host),count,data.geometry and #data.geometry.actors or 0)
        for key,row in pairs(data.hidden) do apply_one(s,key,row) end
        Geometry.restore(R,s,function() return state==s end,function() collide(s);publish() end)
    end
    -- The host edits the world in Creative, outside Playtest.
    local function ensure_edit()
        local c=C.session()
        C.state('BaseWorldPlus','World editing',C.guest(c) and 'off - only the host edits' or c.mode~='creative' and 'off - not in Creative'
            or c.is_playtest and 'off - in a playtest' or not (R.valid(c.world) and R.valid(c.pc)) and 'off - no world or player yet'
            or state and state.unread and 'off - this map\'s saved world edits could not be read' or 'on')
        if C.guest(c) or c.mode~='creative' or c.is_playtest then return end
        if not R.valid(c.world) or not R.valid(c.pc) then return end
        if state and state.unread then return end
        if not state then
            replace({world=c.world,layout_id='',host=true,is_playtest=false},
                {version=1,world=world_id(c.world),hidden={}})
        end
        return state,c.pc
    end
    -- After each change of the hidden set (fn(state) for each listener).
    local listeners={}
    local function changed(s)
        s.source=nil   -- (edited: no longer the shipped copy)
        publish()
        for _,fn in ipairs(listeners) do fn(s) end
    end
    -- One key of the hidden set: row hides it, nil shows it.
    local function set(s,key,row)
        s.data.hidden[key]=row
        if row then apply_one(s,key,row) else restore_one(s,key) end
    end
    -- Hide or show rows (the editor keeps its undo: WorldKit's).
    local function edit_group(rows,hidden)
        local s=state;local any=false
        for _,row in ipairs(rows) do
            local key=row_key(row)
            if (s.data.hidden[key]~=nil)~=hidden then any=true;set(s,key,hidden and row or nil) end
        end
        if any then changed(s) end
    end
    local function edit(row,hidden) edit_group({row},hidden) end

    -- Nearest scenery actors and foliage instances, nearest first.
    local function inventory(limit)
        local list={};local pc=C.session().pc
        local origin=pc.PlayerCameraManager:GetCameraLocation()
        local function add(row,position)
            local dx,dy,dz=position.X-origin.X,position.Y-origin.Y,position.Z-origin.Z
            list[#list+1]={row=row,distance=dx*dx+dy*dy+dz*dz}
        end
        for _,class in ipairs(Objects.classes) do for _,a in ipairs(R.find_all(class)) do
            if a:HasAnyFlags(Objects.LOADED) then add(Objects.row(a),a:K2_GetActorLocation()) end
        end end
        for _,c in ipairs(R.find_all('/Script/Engine.InstancedStaticMeshComponent')) do
            if c:HasAnyFlags(Objects.LOADED) then
                for index=0,c:GetInstanceCount()-1 do
                    add(Instances.row(c,index,Objects.path(c)),Instances.transform(c,index,true).Translation)
                end
            end
        end
        table.sort(list,function(a,b) return a.distance<b.distance end)
        local rows={}
        for i=1,math.min(#list,limit) do rows[i]=list[i].row end
        return rows
    end
    hooks.on('layout_loaded',function(info)
        if not R.valid(info.world) then return end
        if not info.host then
            local value=host_value
            local data=value and value.layout==info.layout_id and resolve(value)
            if data and data.world==world_id(info.world) then replace(info,data)
            else
                C.state('BaseWorldPlus','Host world edits',not value and 'none from the host for this layout' or value.layout~=info.layout_id and 'not applied - they are for another layout' or not data and 'not applied - could not be read' or 'not applied - they are for another world')
                clear()
            end
            return
        end
        local data=return_data
        local name=world_id(info.world)
        local record=C.map.loaded[Store.ID]
        local source=not data and record and shipped(info.layout_id)
        source=source and {path=source,sum=checksum(record.data)} or nil
        if not data and record then
            -- Map data comes from any author: an unreadable record is kept, not applied.
            local ok,result=pcall(files.decode,record.data,name)
            if not ok then
                clear();state={world=info.world,layout=info.layout_id,host=true,unread=record,originals={},spawned={}}
                C.net.publish('bwp.world',false)
                log('World edits could not be read: %s',result)
                U.message(nil,'Some saved world edits could not be read. They stay in the map as they are.')
                return
            end
            data=result
            if not data then return end
        end
        replace(info,data or {version=1,world=name,hidden={}},source)
    end)
    -- The host's edits wait for the session: until the host's mode arrives a guest's session
    -- counts as vanilla, and the host sends its topics in no fixed order.
    local function client_world()
        local c=C.session()
        if C.owns(c) then return end
        local value=host_value
        C.state('BaseWorldPlus','Host world edits',c.mode=='vanilla' and 'not applied - a vanilla session' or not value and 'none from the host' or 'received')
        if c.mode=='vanilla' or not value then clear();return end
        if not c.world or world_id(c.world)~=value.world then return end
        local data=resolve(value)
        if not data then C.state('BaseWorldPlus','Host world edits','not applied - this machine\'s copy of the map differs from the host\'s');clear();return end
        if state and state.data==data then return end
        replace({world=c.world,layout_id=value.layout,host=false,is_playtest=c.is_playtest},data)
    end
    C.net.watch('bwp.world',function(value)
        if value and value.data then Store.validate(value.data) end
        host_value=value
        client_world()
    end)
    hooks.on('layout_saved',function(info)
        if state and state.host and not info.autosave then state.layout=info.layout_id;state.source=nil;publish() end
    end)
    -- Saving a layout carries its world edits inside it; an unread record stays as it came.
    C.map.module(Store.ID,{save=function()
        -- Not editing this map (a vanilla session, or the edits never applied): they stay as they came.
        if not state then local r=C.map.loaded[Store.ID];if r then return r.version,r.data end;return end
        if not state.host then return end
        if state.unread then return state.unread.version,state.unread.data end
        local d=state.data
        if next(d.hidden)==nil and not d.geometry then return end
        return Store.VERSION,files.encode(d)
    end})
    local creative='/Game/Blueprints/Gamemodes/CreativeMode/B_CreativeGameMode.B_CreativeGameMode_C:'
    hooks.pre(creative..'EndPlayTest',function() if state then return_data=state.data end end)
    hooks.post(creative..'EndPlayTest',function()
        if return_data then
            local c=C.session()
            replace({world=c.world,layout_id=state and state.layout or '',host=C.owns(c),is_playtest=false},return_data)
        end
        return_data=nil
    end)
    hooks.post(creative..'NewLayout',function()
        clear();C.net.publish('bwp.world',false)
    end)
    -- Entering a vanilla session removes every edit.
    C.on_session(function(c)
        if c.mode=='vanilla' then clear() end
        client_world()
    end)
    R.on('world_end',function() state,host_value,return_data=nil,nil,nil end)
    -- Editing, for the editors (Editor tweaks): the host in Creative outside Playtest.
    -- ensure_edit() -> state, pc (nil when it cannot edit); state.data.hidden: key -> row.
    -- edit(row, hidden) and edit_group(rows, hidden) hide or show (only what changes).
    -- inventory(n): the n nearest scenery rows. on_change(fn(state)): after each change.
    -- Objects and Instances: what can be hidden and how (objects.lua, instances.lua).
    return {ensure_edit=ensure_edit,edit=edit,edit_group=edit_group,inventory=inventory,
        lookup=lookup,key=row_key,on_change=function(fn) listeners[#listeners+1]=fn end,
        Objects=Objects,Instances=Instances}
end
