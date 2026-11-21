return function(R, C, U)
    local dir = debug.getinfo(1,'S').source:match('^@(.+[\\/])')
    -- Lives, once (audit 11-20: 99 and 5 were written in several files): "infinite" is INFINITE_LIVES,
    -- and the game's heart row shows at most HEARTS (more shows as a number).
    local S = {INFINITE_LIVES=99,HEARTS=5,dir=dir,R=R, C=C, U=U, codec=dofile(dir..'codec.lua')(R.json,R.packages.MapMarkers.colour.PINK), calc=dofile(dir..'math.lua'),
        MM=assert(R.packages.MapMarkers,'Fill a Pot+ needs MapMarkers')}
    S.O = '/Game/Blueprints/Gamemodes/ObjectiveMode/'
    S.CR = '/Game/Blueprints/Gamemodes/CreativeMode/'
    S.CORE = '/Game/Blueprints/Core/'
    S.MATCH = '/Game/Blueprints/Match/'
    dofile(dir..'scope.lua')(S)
    dofile(dir..'facts.lua')(S)   -- (the game's facts this mode asks, each from one place: round, team, lives, replication indices)
    -- This mode's guests need this mod.
    C.mods.require(function(options) return S.selected(options) end)
    -- Maps with Fill a Pot+ markers belong to this mode's map list.
    C.map.module(S.codec.ID,{mode=true,selected=function(options) return S.selected(options) end,
        -- A hosted Fill a Pot match chosen as this mode is this mode's session
        -- (never a vanilla one: the session's mode says so - audit 11-20).
        plays=function(s) return s.gs~=nil and s.gs:GetClass():GetFName():ToString()=='B_ObjectiveGameState_C' and s.mode~='vanilla' end,
        -- The map's settings (S.map) in the map record, once - for a map with this mode's markers.
        save=function() if #S.markers()>0 then return S.codec.VERSION,S.codec.encodeMap(S.map) end end,
        -- A Fill a Pot+ session may play any map of its pools next.
        needs=function()
            local all,pools={},S.catalogue()
            for _,pool in ipairs({pools.official,pools.featured,pools.custom}) do
                for _,row in ipairs(pool) do for id in pairs(C.catalog.manifest(row.file).needs) do all[id]=true end end
            end
            return all
        end})
    -- The blocks of each marker kind: MapMarkers' green screen when placed; the cauldron and rune
    -- stone blocks of older maps stay markers.
    local static='/Game/Blueprints/StaticProps/Placeable/StaticProps/'
    S.carriers = {
        {S.MM.GREEN_SCREEN, static..'BP_WitchCauldron.BP_WitchCauldron_C'},
        {S.MM.GREEN_SCREEN, S.MM.RUNE_STONE},
    }
    S.names = {'Fill a Pot cauldron','Witch respawn point'}
    S.F,S.L = C.MAP,C.LAYOUT
    -- The game's prop list (S_PropList): a wanted kind's copies.
    S.COPIES='MeshList_3_9A021886472783B7C6D4C1A40C1D892E'
    function S.path(folder, name, method) return folder..name..'.'..name..'_C'..(method and ':'..method or '') end
    S.text, S.values = R.text, R.values
    function S.asset(path) return R.native.load_asset(path) end
    function S.new(path, outer) return StaticConstructObject(S.asset(path),outer) end
    function S.distance(a,b) return (a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2 end
    function S.classpath(class) return class:GetFullName():match('^%S+ (.+)$') end
    function S.players() return S.values(C.session().gs.PlayerArray) end
    function S.manager() return C.session().gi.ObjectiveMatchManager end
    -- Markers are MapMarkers kinds (editor.lua) saved as this mode's record (codec.lua).
    S.MM.record({id=S.codec.ID,version=S.codec.VERSION,decode=S.codec.decode,encode=S.codec.encode})
    -- The Fill a Pot+ marker on a block (info), nil for any other block.
    function S.marker(actor)
        local info,def=S.MM.marker(actor)
        if def and def.record==S.codec.ID then return info end
    end
    function S.markers() return S.MM.markers(S.codec.ID) end
    for _,name in ipairs({'rules','rejoin','featured','ground','abilities','possession','divination','cauldron_rules','indicator','respawn','plates','gameplay','results','maps','voting','world','preview','editor','progress','hud','events'}) do
        dofile(dir..name..'.lua')(S)
    end
    return S
end
