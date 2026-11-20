-- Teleporters by markers (World edits): the converted bundled map's records read as a pair; the
-- kinds keep the prefab codes 3 and 4; a new marker takes the first free number; the host makes a
-- zone per complete pair when a match's layout loads (and one back for two-way).
local json=dofile('candidate/runtime-source/WitchItRuntime/Scripts/json.lua')
local hooks,events={},{}
local spec,kinds,rows={},{},{}
local MM={colour=dofile('candidate/runtime-source/MapMarkers/colour.lua'),record=function(s) spec=s end,kind=function(d) kinds[d.name]=d end,
    markers=function() return rows end,look=function() end,editing=function() return false end}
local session={role='host',mode='monroth.fap'}
local C={session=function() return session end,map={module=function() end}}
C.scoped=function(applies) return {
    on=function(e,f) events[e]=function(...) if applies(session) then f(...) end end end,
    post=function(p,f) hooks[p]=f end,playtest=function() end} end
local zones,pairs_={},0
local R={json=json,native={load_asset=function() end,teleporter_exit=function() end,teleporter_pair=function() pairs_=pairs_+1 end},
    pre=function() end,on=function() end,valid=function(v) return v end}
R.native.spawn=function(_,_,at,init)
    local z={TargetLocation={SetAbsolute=function() end,SetIsReplicated=function() end},
        Zone={SetBoxExtent=function() end,SetGenerateOverlapEvents=function() end},
        SetActorEnableCollision=function() end,ForceNetUpdate=function() end,K2_DestroyActor=function() end,at=at}
    init({SetReplicates=function() end,SetReplicateMovement=function() end,SetActorEnableCollision=function() end})
    zones[#zones+1]=z;return z
end
dofile('candidate/runtime-source/Core/tests/lib/effects.lua')(R,C)
dofile('candidate/runtime-source/BaseWorldPlus/teleporters.lua')(R,C,{},MM)
assert(spec.id=='monroth.teleport' and kinds.entrance.code==3 and kinds.exit.code==4,'record and prefab codes')
-- The converted map's two markers.
local pipe=io.popen([[python3 -c "
import sys;sys.path.insert(0,'tooling/LayoutExporter');import mapdata as m
from switch_links import unpack
p=m.parse(unpack(open('candidate/runtime-source/FillAPotPlus/bundled-maps/LibraryInsideNight/LibaryNight01.pl','rb').read()))
for row in p['sections']['blocks']:
    r=m.split(row['bytes'])[1].get('monroth.teleport')
    if r: print(r[1].decode())"]])
local actor=function(yaw) return {K2_GetActorRotation=function() return {Yaw=yaw} end} end
for line in pipe:read('*a'):gmatch('[^\n]+') do
    local info=assert(spec.decode(line))
    rows[#rows+1]={actor=actor(90),info=info,position={X=#rows,Y=0,Z=0}}
end
pipe:close()
assert(#rows==2 and rows[1].info.pairId==1 and rows[2].info.pairId==1,'the pair of the converted map')
local new={kind='entrance'};kinds.entrance.created(new);assert(new.pairId==2,'a new entrance takes the next free number')
events.layout_loaded({is_creative=false})
assert(#zones==1 and pairs_==0,'one zone for a one-way pair')
zones={};rows[1].info.twoWay=true;events.layout_loaded({is_creative=false})
assert(#zones==2 and pairs_==1,'two-way: a zone back, paired')
session.mode='vanilla';events.layout_loaded({is_creative=false});assert(#zones==2,'never in a vanilla session')
print('PASS teleporters')
