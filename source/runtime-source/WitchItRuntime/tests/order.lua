-- Load order: needs first, `after` when present, then by name; and why a package whose needs are
-- missing does not load. No list of mods in the runtime.
local order=dofile('candidate/runtime-source/WitchItRuntime/Scripts/order.lua')
local list,skipped=order({
    FillAPotPlus={needs={'MapMarkers'},after={'Rejoin'}},BaseWorldPlus={needs={'MapMarkers'}},MapMarkers={needs={'UIKit'}},
    Rejoin={needs={'UIKit'}},WindowKit={},Zeta={needs={'WindowKit'}},Alpha={},Broken={needs={'Nothing'}},Off={enabled=false}},{'Core','UIKit'})
local s=table.concat(list,',')
assert(s=='Alpha,MapMarkers,BaseWorldPlus,Rejoin,FillAPotPlus,WindowKit,Zeta',s)
assert(skipped.Broken=='needs Nothing' and not skipped.Off)
-- `after` only waits for a package that is there.
list=order({FillAPotPlus={needs={'MapMarkers'},after={'Rejoin'}},MapMarkers={}},{'Core','UIKit'})
assert(table.concat(list,',')=='MapMarkers,FillAPotPlus')
print('PASS order')
