local base='candidate/runtime-source/'
local Store=dofile(base..'BaseWorldPlus/store.lua')
local mapdata=dofile(base..'Core/mapdata.lua')
local R={json=dofile(base..'WitchItRuntime/Scripts/json.lua')}
local files=Store.new(R)
-- A bundled map's world edits travel in its map record (MAPDATA.md); a map without edits has none.
local pipe=io.popen([[python3 -c "
import sys,glob;sys.path.insert(0,'tooling/LayoutExporter');import mapdata as m
from switch_links import unpack
from pathlib import Path
for f in sorted(glob.glob('candidate/runtime-source/FillAPotPlus/bundled-maps/*/*.pl')):
    g,r=m.split(m.parse(unpack(Path(f).read_bytes()))['sections']['blocks'][0]['bytes'])
    print(Path(f).stem, r['map'][1].hex() if 'map' in r else '00')"]])
local count,edits=0,0
for stem,hex in pipe:read('*a'):gmatch('(%S+) (%x+)') do
 local body=hex:gsub('%x%x',function(x) return string.char(tonumber(x,16)) end)
 local _,records=mapdata.read_list(body)
 local record=records and records[Store.ID]
 if record then
  local raw=record.data
  local world=R.json.decode(raw,4194304).world
  local data=assert(files.decode(raw,world))
  assert(data.hidden and data.portals==nil)
  assert(files.decode(raw,'SomewhereElse')==nil,'edits of another world are not applied')
  edits=edits+1
 end
 count=count+1
end
pipe:close()
assert(count==38 and edits>=13,count..' maps, '..edits..' with edits')
print('PASS: '..count..' bundled maps, '..edits..' with world edits in the map record')
