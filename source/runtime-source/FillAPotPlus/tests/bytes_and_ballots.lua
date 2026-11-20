local dir=debug.getinfo(1,'S').source:match('^@(.+[\\/])')..'../'
local json=dofile(dir..'../WitchItRuntime/Scripts/json.lua')
local codec=dofile(dir..'codec.lua')(json,dofile('candidate/runtime-source/MapMarkers/colour.lua').PINK)
local calc=dofile(dir..'math.lua')
local path='/Game/Props/Barrel.Barrel_C'
local pot=codec.defaults({kind=1,radius=0,excluded={[path]=true}})
local decoded=assert(codec.decode(codec.encode(pot)))
assert(decoded.kind==1 and decoded.radius==0 and decoded.excluded[path])
assert(codec.encode(decoded)==codec.encode(pot),'a decoded marker encodes the same')
assert(codec.decode('{"kind":"respawn"}').kind==2)
assert(not codec.encode(pot):find('target'),'a cauldron no longer carries the map settings')
-- The map's settings: once, in the map record; Secret and Event off unless the map allows them.
local m=codec.decodeMap(nil)
assert(m.target==3 and m.secret==false and m.event==false,'a map without its record takes the defaults')
local back=codec.decodeMap(codec.encodeMap({target=4,secret=true,event=false}))
assert(back.target==4 and back.secret==true and back.event==false,'the map settings are kept')
assert(codec.mapOf({target=0}).target==1,'at least one cauldron to win')
assert(codec.decode('{"kind":"something new"}')==nil,'an unknown kind is not a marker')
local converted=codec.decode('{"kind":"cauldron"}')
assert(converted.radius==2500 and converted.colour.G==.2,'a bare cauldron takes the defaults')
assert(codec.decode('{"kind":"entrance"}')==nil,'teleporters are World edits markers')
local pools={vanilla={},official={},featured={},custom={}}
for i=1,14 do
    local row={file='world'..i,name='Map '..i}
    local pool=i<5 and pools.vanilla or i<9 and pools.official or pools.custom
    pool[#pool+1]=row
end
local function first() return 1 end
local rows=calc.selectOffers(pools.vanilla[1],pools,first)
assert(#rows==5)
local seen={}
for _,row in ipairs(rows) do assert(not seen[row.file]);seen[row.file]=true;assert(tonumber(row.file:match('%d+'))<9,'saved maps are not offered') end
assert(calc.winner({0,4,4},3,first)==2)
local short=calc.selectOffers(nil,{vanilla={{file='one'}},official={},custom={}},first)
assert(#short==1)
print('bytes_and_ballots: passed')

local seen={}
local palette=dofile('candidate/runtime-source/MapMarkers/colour.lua').PALETTE
for _,c in ipairs(palette)do
 local rgb=string.pack('<fff',c.R,c.G,c.B);assert(not seen[rgb]);seen[rgb]=true
end
assert(#palette==7)
print('PASS seven distinct colours')
