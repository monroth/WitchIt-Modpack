-- The manifest follows from the map: needed modules, modes, foreign data kept as it came.
local codec=dofile('candidate/runtime-source/Core/mapdata.lua')
local json=dofile('candidate/runtime-source/WitchItRuntime/Scripts/json.lua')
local function block(records)
    local bytes=codec.join('\1',records);local arr={}
    for i=1,#bytes do arr[i]=bytes:byte(i) end
    return {SavedMaterialIndices={ForEach=function(_,fn) for i,v in ipairs(arr) do fn(i,{get=function() return v end}) end end},
        GetFullName=function() return 'block' end}
end
local blocks={}
local R={json=json,native={},events={}}
R.on=function(e,fn) R.events[e]=fn end
R.find_all=function() return blocks end
R.log=function() end
R.native.on_save=function(fn) R.save=fn end
R.native.map_record_set=function(bytes) R.written=bytes end
R.native.map_record_take=function() return R.reading end
dofile('candidate/runtime-source/Core/tests/lib/mods.lua')(R)
local M=dofile('candidate/runtime-source/Core/map.lua')(R,{})
M.module('monroth.fap',{mode=true,selected=function(o) return o=='plus' end})
M.module('anium.groups',{optional=true,save=function() return 1,'{"g":1}' end})
-- A loaded map with data of a module not installed here, which the map needs as a mode.
R.reading=codec.list({manifest={version=1,data=json.encode({needs={['anium.imp']=1},modes={'anium.imp'}})},
    ['anium.imp']={version=1,data='imp data'}})
R.events.layout_loaded({layout_id='x.pl'})
blocks={block({['monroth.fap']={version=1,data='{"kind":"respawn"}'}}),block({['anium.imp']={version=2,data='m'}})}
R.save({phase='entry'})
local _,whole=codec.read_list(R.written)
local manifest=json.decode(whole.manifest.data)
assert(whole['anium.imp'].data=='imp data','data of a module not installed here stays')
assert(whole['anium.groups'].data=='{"g":1}','an optional module still saves its data')
assert(manifest.needs['monroth.fap']==1 and manifest.needs['anium.imp']==2 and manifest.needs['anium.groups']==nil,'needs: used modules, highest version, not optional ones')
assert(table.concat(manifest.modes,',')=='anium.imp,monroth.fap','modes: installed mode modules and the map\'s own unknown ones')
assert(M.selected('monroth.fap','plus') and not M.selected('monroth.fap','vanilla') and not M.selected('anium.groups','plus'))
-- A map without any module data gets no map record.
blocks={};M.loaded={};R.events.world_end()
M.module('anium.groups',{optional=true})
R.save({phase='entry'})
assert(R.written=='','no module data, no map record')
print('PASS map manifest: needs, modes, optional and foreign module data')
