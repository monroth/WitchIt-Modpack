local kept={}
local dir='candidate/runtime-source/FillAPotPlus/'
local hooks={}
local function array(rows)
 return {GetArrayNum=function() return #rows end,ForEach=function(_,fn)
  for i,row in ipairs(rows) do fn(i,{get=function() return row end}) end
 end}
end
local function out(value) return {get=function() return value end} end
local json=dofile('candidate/runtime-source/WitchItRuntime/Scripts/json.lua')
local codec=dofile(dir..'codec.lua')(json,dofile('candidate/runtime-source/MapMarkers/colour.lua').PINK)
local mapdata=dofile('candidate/runtime-source/Core/mapdata.lua')
local function marker(kind)
 local bytes=mapdata.join('',{[codec.ID]={version=codec.VERSION,data=codec.encode(codec.defaults({kind=kind}))}})
 local values={};for i=1,#bytes do values[i]=bytes:byte(i) end
 return {PrimaryAssetId={PrimaryAssetName=kind==1 and 'Pot' or 'Respawn'},MaterialIndices=array(values)}
end
local file='untouched.pl'
local S_read   -- (Core's on_read listener: maps.lua's)
local S={path=function(folder,name,method) return tostring(folder)..name..':'..method end,dir=dir,F={},L={file='file',name='name'},codec=codec,text=function(v) return v end,
 carriers={{'/Game/Pot.Pot_C'},{'/Game/Respawn.Respawn_C'}},
 R={post=function(path,fn) hooks[path]=fn end,pre=function() end,on=function() end,next_frame=function(fn) fn() end},
 C={map={split=mapdata.split,spec=function() return {} end,on_read=function(fn) S_read=fn end},catalog={manifest=function() return {needs={},modes={}} end,keep=function(f,k,v) kept[f..'/'..k]=v end,kept=function(f,k) return kept[f..'/'..k] end},session=function() return {gi={UsedMatchOptions={CustomMapSelected=true,LayoutData={file=file,name='Custom'}}}} end}}
dofile('candidate/runtime-source/FillAPotPlus/tests/lib/scope.lua')(S)
dofile(dir..'maps.lua')(S)
local props={}
for i=1,4 do for _=1,2 do props[#props+1]={PrimaryAssetId={PrimaryAssetName='Prop'..i}} end end
local read=hooks['/Script/PropWitchHuntModule.ProjectVersionBlueprint:LoadPropLayoutFromFileCompressed']
read({},false,file) -- Native refusal must not inspect absent output arrays.
assert(S.currentMap().info==nil)
read({},true,file,out(array(props)),nil,out(array({marker(1),marker(1)})),nil,nil,
 out(array({{Structures=array({marker(1),marker(2)})}})))
-- The cauldrons to win come from the map record, once (Core hands it after the read).
S_read(file,{[codec.ID]={version=codec.VERSION,data=codec.encodeMap({target=1,secret=false,event=false})}})
local info=S.currentMap().info
assert(info.pots==3 and info.respawns==1 and info.classes==4 and info.target==1)
assert(S.playable(info))
assert(kept[file..'/FillAPotPlus'].pots==3,'The counts are kept in Core\'s catalogue')
assert(kept[file..'/FillAPotPlus.target']==1,'the target is kept apart, from the map record')
print('FillAPotPlus native read-only metadata checks passed')
