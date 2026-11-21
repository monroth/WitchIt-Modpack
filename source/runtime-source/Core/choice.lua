-- The map a match plays: the ONE writer of the match options' choice (the official map or the saved
-- layout on its level, and their flags) and of the map the game opens. Everything else asks Core
-- (C.catalog.choose / unpick / keep_pick / opening / register); install/owners.py refuses any other writer.
-- (user 11-20: "I load one map and another one opens" came from eight writers in five mods)
-- picked(): the saved map the player picked (Core keeps it: a game menu may clear the options' flag);
-- remember(file or nil) sets it - choose does, so the two never part (audit 11-20).
return function(K,C,picked,remember)
    local MAP_FILE,LAYOUT_FILE=C.MAP.file,C.LAYOUT.file
    local function text(v) return v and (type(v)=='string' and v or v:ToString()) or '' end
    function K.choose(options,map,layout,file)
        C.state('Core','Chosen map',('%s%s'):format(layout and 'saved map ' or 'official map ',layout and text(layout[LAYOUT_FILE]) or file or tostring(map and text(map[MAP_FILE]) or '?')))
        options.MapData=map
        if file then options.MapData[MAP_FILE]=FName(file) end
        if layout then options.LayoutData=layout end
        options.CustomMapSelected=layout~=nil
        remember(layout and text(layout[LAYOUT_FILE]) or nil)
        options.SelectedLayout=-1;options.UseCustomLayouts=false
    end
    function K.unpick(options) remember(nil);options.CustomMapSelected=false end
    -- (only while the options still hold that very map)
    function K.keep_pick(options) if picked() and text(options.LayoutData[LAYOUT_FILE])==picked() then options.CustomMapSelected=true end end
    function K.opening(gi,options,next)
        gi.CurrentOpenedMap=options.MapData
        if next then gi.NextMapToOpen=options.MapData[MAP_FILE] else gi.CurrentOpenedRandomMap=options.MapData[MAP_FILE] end
    end
    function K.register(mm,id,map,file,layout,shot,texture)
        if texture then mm.CustomMapTextureImages:Add(shot,texture) end
        mm.MapDataByFileName:Add(id,map);mm.LayoutDataByFileName:Add(file,layout)
    end
end
