-- A map is read with the game's reader once while its file stays the same, across sessions;
-- what modules keep about it lives in the same entry; entries of deleted maps are dropped.
local json=dofile('candidate/runtime-source/WitchItRuntime/Scripts/json.lua')
local file,other=os.tmpname(),os.tmpname()
local function put(path,bytes) local f=assert(io.open(path,'wb'));f:write(bytes);f:close() end
put(file,'plain layout one');put(other,'another layout')
local disk,reads,listed={},0,{}
local names={}   -- file -> the layout's name (the game's saved maps)
local NAME,FILE='LayoutName_8_C5C516E347406BABDAF0F59A6150BC5A','FileName_6_F3CC8069497D007AD2E96A9AE00D2700'
local cardHook,cards=nil,0
local K,list
local modes,specs,chosen={},{},nil   -- mode modules, their specs, the chosen one
local vanilla=false
local plain=file..'~plain-map';put(plain,'a map with markers')   -- needs a module (listed after file)
local function session()
    local frames={}
    local V=dofile('candidate/runtime-source/WitchItRuntime/Scripts/values.lua')
    local R={values=V.values,text=V.text,json=json,valid=function(o) if o and not o.gone then return o end end,on=function() end,pre=function() end,next_frame=function(fn) frames[#frames+1]=fn end,
        post=function(path,fn)
            if path:find('GetIndividualItemDataAndFocus') then list=fn end
            if path:find('GetMapButtonData') then cardHook=fn end
        end,
        native={map_record_take=function(f) return f end}}
    local C={files={read_json=function(rel) return disk[rel] and json.decode(disk[rel]) end,
            write_json=function(rel,v) disk[rel]=json.encode(v) end},
        map={read_list=function(f)
                if f==plain then return nil,{manifest={data='{"needs":{"markers":1},"modes":[]}'}} end
                return nil,{manifest={data='{"needs":{},"modes":["fap"]}'}} end,
            modes=function() return modes end,spec=function(id) return specs[id] end,
            selected=function(id) return id==chosen end,chosen=function() return chosen end,has=function() return true end},
        mods={vanilla=function() return vanilla end}}
    dofile('candidate/runtime-source/Core/game.lua')(R,C)
    -- The game's reader: a module hears it and keeps its count.
    local reader={GetCDO=function() return {} end,LoadPropLayoutFromFile=function(_,path) reads=reads+1;K.keep(path,'module',reads) end}
    local game={MapManager={AutoSaveSuffix='',LayoutDataByFileName={ForEach=function(_,fn)
        for _,f in ipairs(listed) do fn({get=function() return f end},{get=function() return {[NAME]=names[f] or f,[FILE]=f} end}) end end}}}
    StaticFindObject=function(path)
        if path:find('GameplayStatics') then return {GetGameInstance=function() return game end} end
        return reader
    end
    -- (C.map.read: the game's reader opens the file, then its record)
    C.map.read=function(f) reader:LoadPropLayoutFromFile(f);local _,r=C.map.read_list(f);return r end
    K=dofile('candidate/runtime-source/Core/catalog.lua')(R,C)
    return function() for _,fn in ipairs(frames) do fn() end end
end
local flush=session()
assert(K.manifest(file).modes[1]=='fap' and reads==1)
assert(K.kept(file,'module')==1,'The module kept its count while the game read the file')
K.manifest(file);K.kept(file,'module');assert(reads==1,'Once per session')
assert(K.kept(other,'module')==2);flush()
flush=session()
assert(K.manifest(file).modes[1]=='fap' and K.kept(file,'module')==1 and reads==2,'A new session takes both from disk')
assert(K.kept(file,'missing')==nil and reads==3,'Nothing kept: the map is read once')
assert(K.kept(file,'missing')==nil and reads==3,'... and only once a session')
put(file,'plain layout two, longer')
flush=session()
K.manifest(file);assert(reads==4 and K.kept(file,'module')==4,'A changed file is read again')
-- The list: a map the game no longer lists and whose file is gone loses its entry.
os.remove(other);listed={file}
local function box(v) return {get=function() return v end,set=function(_,x) v=x end} end
list({CurrentMapCategory=0,NextMatchOptions={},GetAddress=function() return 7 end},nil,nil,box({}),box({}))
flush()
local saved=json.decode(disk['Core/maps.json'])
assert(saved[file] and not saved[other],'Deleted maps leave the cache')
-- The list: maps of a mode not chosen are left out unless all are asked for (then dimmed); the
-- search takes every word, in any case, from the name or the file name.
local tiles={}
-- A card is made for a map when it is shown (the game's own function, its card out).
local w={CurrentMapCategory=1,NextMatchOptions={},GetAddress=function() return 8 end,MenuState=0,ShowAutoSave=false,
    MapListTileView={BP_SetListItems=function(_,items) tiles=items end},
    TileViewManager={GetMapButtonData=function(_,on,_,_,layout)
        cards=cards+1
        local n=cards
        cardHook(nil,nil,nil,nil,nil,nil,{get=function() return {LayoutData=layout,GetAddress=function() return n end} end})
    end}}
local function titles(items)
    local out={}
    for _,item in ipairs(items) do out[#out+1]=item.LayoutData[NAME]..(K.dimmed(item) and '*' or '') end
    return table.concat(out,',')
end
-- The game builds the list; a change of the view narrows the shown rows without a new build.
-- The game's own Custom tab: filled for most modes (its cards are not used), empty for its Fill a Pot.
local gameList={'a game card'}
local function shown()
    local out=box(gameList)
    list(w,nil,nil,out,box({}))
    local built=titles(out:get())
    K.narrow(w)
    assert(titles(tiles)==built,'Narrowing again shows what the build showed')
    return built
end
listed={file,plain};names[file],names[plain]='Town Night','Plain'
local got=shown();assert(got=="Plain","A map of a mode not chosen is left out: "..got)
K.view.all=true
got=shown();assert(got=='Town Night*,Plain','All maps: the incompatible one is dimmed: '..got)
K.view.search='NIGHT  town'
assert(shown()=='Town Night*','Every word, any case and order')
K.view.search=plain:match('[^/]+$'):upper()
assert(shown()=='Plain','The file name is searched too')
K.view.search='%a';assert(shown()=='','Plain text, not a pattern')
K.view.search='night';K.narrow(w);assert(titles(tiles)=='Town Night*','The view narrows the rows of the last build')
K.view.search='';K.narrow(w)
local made=cards
K.view.search='night';K.narrow(w);K.view.search='';K.narrow(w)
assert(cards==made,'A map shown once keeps its card')
-- Only the game's list keeps a card: one the view left out may be gone, and is made again.
K.view.search='night';K.narrow(w)
for _,item in ipairs(tiles) do item.gone=true end
K.view.search='';local was=cards;K.narrow(w)
assert(cards==was+1,'A gone card is made again: '..(cards-was))
K.view.all=false;K.view.search='';local before=cards;shown()
assert(cards==before+1,'A new build makes cards only for the maps it shows: '..(cards-before))
-- Creative opens every map: none is dimmed, and the view picks one kind (all, no mode, a mode's).
w.NextMatchOptions={GameMode={GetFName=function() return {ToString=function() return 'B_CreativeGameMode_C' end} end}}
K.view.all,K.view.search=false,''
assert(shown()=='Town Night,Plain','Creative: every map, none dimmed')
K.view.genre='';K.narrow(w);assert(titles(tiles)=='Plain','Normal: maps of no mode')
K.view.genre='fap';K.narrow(w);assert(titles(tiles)=='Town Night','A mode: its maps')
K.view.genre=nil
-- A game mode whose Custom tab the game keeps empty (its Fill a Pot) plays no saved map.
w.NextMatchOptions={};K.view.all=true;gameList={}
assert(shown()=='','No saved maps where the game plays none')
gameList={'a game card'};K.view.all=false
-- A vanilla server plays no map that needs a module: no list shows it, Creative's neither.
w.NextMatchOptions={};vanilla=true
local got=shown();assert(got=='','Vanilla: a map that needs a module is left out: '..got)
K.view.all=true;assert(shown()=='Town Night*','... also with all maps shown')
w.NextMatchOptions={GameMode={GetFName=function() return {ToString=function() return 'B_CreativeGameMode_C' end} end}}
assert(shown()=='Town Night','... and in Creative')
-- The official tab: a mode's own maps (put in the game's list) only while that mode is chosen.
local MAP_FILE,MAP_NAME='FileName_10_98BC71FF40A2DA9A28FA21B92157D6D9','InterfaceName_12_C1C05170469A93A0C7D243A1F45D7B13'
local function official(name) return {MapData={[MAP_FILE]=name,[MAP_NAME]=name},LayoutData={[NAME]='',[FILE]=''},GetAddress=function() return 'o:'..name end} end
modes,specs={'fap'},{fap={own=function(f) return f=='FAPB:bundled' end}}
w.NextMatchOptions={};w.CurrentMapCategory=0;vanilla=false;K.view.all=false
local game=box({official('Snowbreeze'),official('FAPB:bundled')})
local function names() local o={} for _,it in ipairs(tiles) do o[#o+1]=it.MapData[MAP_NAME] end return table.concat(o,',') end
list(w,nil,nil,game,box({false,false}));K.narrow(w)
assert(names()=='Snowbreeze','Another mode chosen: the mode\'s own map is left out: '..names())
chosen='fap';game=box({official('Snowbreeze'),official('FAPB:bundled')})
list(w,nil,nil,game,box({false,false}));K.narrow(w)
assert(names()=='Snowbreeze,FAPB:bundled','Its mode chosen: shown')
os.remove(file);os.remove(plain)
print('PASS map catalogue: read once per version of the file, module values kept, deleted maps dropped')
