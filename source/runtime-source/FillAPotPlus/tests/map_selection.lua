local dir=debug.getinfo(1,'S').source:match('^@(.+[\\/])')..'../'
local hooks={}
local spec={}
local function map()
    local rows={}
    return {rows=rows,Add=function(_,key,value) rows[key]=value end,
        Find=function(_,key) return {get=function() return assert(rows[key],'missing native map key: '..key) end} end,
        ForEach=function(_,fn) for key,value in pairs(rows) do
            fn({get=function() return key end},{get=function() return value end})
        end end}
end
local mm={MapDataByFileName=map(),LayoutDataByFileName=map(),CustomMapTextureImages=map(),
    SmallMapList={},BigMapList={},QuickmatchMapList={},RandomMapCycle={file='RandomMapCycle'}}
function mm:GetAddress()return 1 end
local options={plus=true,CustomMapSelected=false,MapData={file='Stock'}}
local gi={MapManager=mm,NextMatchOptions=options}
local S={preferences={},dir=dir,F={file='file',name='name',objective='objective',builtin='builtin',preview='preview'},
    L={file='file',name='name',map='map',type='type',screenshot='screenshot'},
    R={log=function() end,post=function(path,fn) hooks[path]=fn end,pre=function() end,on=function() end,valid=function() return false end},
    C={state=function() end,files={read_json=function() return {} end},session=function() return {gi=gi} end,
        map={spec=function() return spec end,on_read=function() end},
        catalog={manifest=function() return {needs={},modes={}} end,allowed=function() return true end,
            kept=function(_,key) if key=='FillAPotPlus.target' then return 3 end return {pots=5,respawns=2,classes=8} end,   -- (a map's counts, as read from its file; its target, from its map record)

            card=function(_,map,layout,on) return {MapData=map,LayoutData=layout,selected=on,GetAddress=function(self) return self end} end}}}
function S.path(folder,name,method) return tostring(folder)..name..':'..method end
function S.selected(o) return o.plus end
S.codec={ID='monroth.fap'}
function S.text(value) return value end
function S.values(values) return values end
S.calc={quantity=function(info) return (info.target or 3)..'/'..info.pots end}
function S.asset() return {GetCDO=function() return {LayoutData={}} end} end
function S.new() return {LayoutData={},MapData={}} end
function FName(value) return value end
function FText(value) return value end
function StaticFindObject() return {LoadImageFromDisk=function() end,GetGameInstance=function()return gi end} end
dofile('candidate/runtime-source/FillAPotPlus/tests/lib/scope.lua')(S)
S.C.MAP,S.C.LAYOUT=S.F,S.L
dofile('candidate/runtime-source/Core/choice.lua')(S.C.catalog,S.C,function() end,function() end)   -- (Core's one writer of the choice)
dofile(dir..'maps.lua')(S)
function S.baseMap() return {file='Stock',name='Stock'} end
local pools=S.catalogue()
local row=pools.official[1]
S.selectMap(options,row)
S.modeChanged(false,options)
assert(not options.CustomMapSelected,'other modes never load a modpack layout')
-- Returning to Fill a Pot+ restores nothing: the player's next pick is the map (user, 11-04).
options.LayoutData={file='Castle/Copy_Castle01_test.pl'};options.CustomMapSelected=true
S.modeChanged(true,options)
assert(options.CustomMapSelected and options.LayoutData.file=='Castle/Copy_Castle01_test.pl')
local factory='/Game/UserInterface/UIElements/MenuTileView/B_MenuTileViewManager.B_MenuTileViewManager_C:GetMapButtonData'
local w={NextMatchOptions=options,CurrentMapCategory=0,MenuState=0,TileViewManager={}}
function w.TileViewManager:GetMapButtonData(selected,owner,mapData,layoutData,editing)
    local item={MapData=mapData,LayoutData=layoutData,selected=selected,GetAddress=function(self) return self end}
    hooks[factory](self,nil,nil,nil,nil,nil,{get=function() return item end})
end
local stock={MapData={file='Stock',objective=true},GetAddress=function(self)return self end}
local out={value={stock},get=function(self) return self.value end,set=function(self,v) self.value=v end}
-- Core's list: the game's rows through the mode's spec.list.
local function build()
    local rows={}
    for i,item in ipairs(out.value) do rows[i]={item=item,ok=true} end
    local items={}
    for i,row in ipairs(spec.list(w,rows)) do items[i]=row.item end
    out.value=items
end
build()
assert(out.value[#out.value].MapData==mm.RandomMapCycle,'Random must exist even when native list omits it')
local count=#out.value
build()
assert(#out.value==count,'Random must appear exactly once')
S.R.valid=function(value)return value end
local quantityPath='/Game/UserInterface/Maps/WB_MapButton.WB_MapButton_C:'
for _,data in ipairs({stock,out.value[2]}) do
    local widget={ItemData=data}
    local text={set=function(self,value)self.value=value end}
    hooks[quantityPath..'GetQuantityText'](widget,text)
    assert(text.value=='3/5','stock and bundled cauldron quantities replace native player counts')
    assert(hooks[quantityPath..'GetPlayernumberText'](widget)=='3/5','native return getter receives the same metadata')
    for _,asset in ipairs({'WB_MapButton','WB_MapListButton'}) do
        local visible={set=function(self,value)self.value=value end}
        hooks['/Game/UserInterface/Maps/'..asset..'.'..asset..'_C:GetQuantityVisibility'](widget,visible)
        assert(visible.value==true,'native cards show known cauldron quantities')
    end
    options.plus=false
    assert(hooks[quantityPath..'GetPlayernumberText'](widget)==nil,'vanilla keeps native player counts')
    options.plus=true
end
local random={ItemData=out.value[#out.value]}
assert(hooks[quantityPath..'GetPlayernumberText'](random)=='','Random hides native player ranges')
local visible={set=function(self,value)self.value=value end}
hooks[quantityPath..'GetQuantityVisibility'](random,visible)
assert(visible.value==false,'Random has no quantity badge')
print('PASS native layout rescan across mode switches and missing/duplicate Random cards')
