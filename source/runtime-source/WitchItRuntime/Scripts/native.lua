return function(R)
    local raw=WitchItNativePrimitives()
    local N={}
    local saves={}
    local function subscription(op,...)
        local id=raw(op,...)
        return function() raw('cancel',id) end
    end
    function N.intercept(path,fn) return subscription('intercept',path,fn) end
    function N.observe(path,fn) return subscription('observe',path,fn) end
    function N.on_asset(path,fn) return subscription('await_asset',path,fn) end
    function N.on_save(fn) saves[#saves+1]=fn end
    function N.on_input(fn) return subscription('input',fn) end
    function N.on_update(fn) return subscription('await_update',fn) end
    function N.load_asset(path)
        local resident=R.valid(StaticFindObject(path))
        if resident then return resident end
        -- (a load the game has to do now, and the game's call it was asked from: user 11-20, a load that never
        -- finished stopped the game and no log said which - told before and after, for every mod)
        R.log('WitchItRuntime','Loading %s (in %s)',path,R.current_hook or 'no hook')
        local loaded=raw('load_asset',path)
        R.log('WitchItRuntime','Loaded %s: %s',path,loaded and 'ok' or 'missing')
        return loaded
    end
    -- An actor of the match (the host's: the authority's spawn), or, spawn_local, one of this
    -- machine's own (a guest too).
    local function spawner(op)
        return function(class,world,p,initialize)
            if type(class)=='string' then class=raw('load_class',class,world) end
            local init=initialize and function(actor) initialize(actor);return true end or nil
            return raw(op,class,world,p.X,p.Y,p.Z,p.Yaw or 0,p.Pitch or 0,p.Roll or 0,
                p.ScaleX or 1,p.ScaleY or 1,p.ScaleZ or 1,init)
        end
    end
    N.spawn,N.spawn_local=spawner('spawn'),spawner('spawn_local')
    function N.destroy(actor) return raw('destroy',actor) end
    -- Forget restored source actors (after destroying them): a new restore spawns its own.
    function N.release_source_actors() return raw('release_source_levels') end
    -- fn() once no class this runtime asked for is loading (at once when none is). Creating many
    -- actors while one loads can hang the game (the loader holds a lock those creations wait for).
    function N.on_idle(fn) return subscription('await_idle',fn) end
    -- Inside an intercept of object's call: its parameters by a path ("Param.Member.Map[Key].Member",
    -- a map's key an FName): read (a bool or a string there, true for anything else there, nil when
    -- it is not), or with a bool or a string, write it.
    function N.frame(object,path,value) return raw('frame',object,path,value) end
    -- Is this key (a virtual key code; 1 the left mouse button) held now?
    function N.key_down(code) return raw('key_down',code) end
    -- Where a widget was last drawn: its left, top, right and bottom in viewport units.
    function N.widget_rect(widget)
        local l,t,r,b=raw('widget_rect',widget)
        return {left=l,top=t,right=r,bottom=b}
    end
    function N.capsule_probe(context,ignored,a,b,radius,height)
        local blocked,penetrating,x,y,z,nx,ny,nz=raw('respawn_probe',context,ignored,a.X,a.Y,a.Z,b.X,b.Y,b.Z,radius,height)
        return {blocked=blocked,penetrating=penetrating,position=blocked and {X=x,Y=y,Z=z},normal=blocked and {X=nx,Y=ny,Z=nz}}
    end
    function N.skin_rpc(pawn,ids)
        if ids then
            local parts={};for i,id in ipairs(ids) do parts[i]=id.type..':'..id.name end
            return raw('skin_rpc',pawn,table.concat(parts,'|'))
        end
        local result={}
        for kind,name in raw('skin_rpc',pawn):gmatch('([^:|]+):([^|]+)') do result[#result+1]={type=kind,name=name} end
        return result
    end
    -- The map record (MAPDATA.md): handed to the next layout write, taken from a read layout.
    function N.map_record_set(bytes) return WitchItNativeMapRecord('set',bytes) end
    function N.map_record_take(file) return WitchItNativeMapRecord('take',file) end
    function N.clipboard_get() return WitchItNativeClipboard('read') end
    function N.clipboard_set(bytes) return WitchItNativeClipboard('write',bytes) end
    -- Layout saves and loads, as the native producer sees them (the game's own functions).
    --   save(phase,autosave,name,target,success): 'entry', then 'complete' with the written file.
    --   load(phase,target,success,name,world): 'return' once the layout is read and applied.
    function N.save_load(save,load)
        assert(WitchItNativeProducerAttach(function(phase,autosave,name,target,success)
            local event={phase=phase,autosave=autosave,target_path=target,complete=phase=='complete',success=success}
            for _,fn in ipairs(saves) do fn(event) end
            save(phase,autosave,name,target,success)
            return true
        end,function(phase,target,success,name,world)
            load(phase,target,success,name,world)
            return true
        end),'Save/load callbacks could not attach')
    end
    function N.teleporter_pair(a,b) return raw('teleporter_pair',a,b) end
    function N.teleporter_exit(zone,exit) return raw('teleporter_exit',zone,exit) end
    function N.source_actors(rows,world,states)
        local result,why=raw('source_actors',world,#rows,function(i)
            local row=rows[i];local t=row.transform
            local names={};for _,component in ipairs(row.components or {}) do names[#names+1]=component.name end
            local values={row.source,row.class,row.role,row.parent and row.parent.source or '',row.parent and row.parent.component or ''}
            for j=1,9 do values[5+j]=t[j] end
            values[15]=table.concat(names,'|');values[16]=R.json.encode(states[row.state],1250000)
            return table.unpack(values,1,16)
        end)
        if not result then return nil,why end
        local actors={};local i=1
        while result[tostring(i)] do actors[i]=result[tostring(i)];i=i+1 end
        return actors
    end
    return N
end
