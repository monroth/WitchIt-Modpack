local path='candidate/runtime-source/BaseWorldPlus/instances.lua'
local original=dofile
local count=0
local fake={['/Game/Test.Test']={vertices={{3,0,0},{0,1,0},{0,0,1}},indices={0,1,2}}}
dofile=function(p)
    if p:find('/pick_meshes/pool/',1,true) then count=count+1;return fake['/Game/Test.Test'] end
    if p:find('/pick_meshes/',1,true) then count=count+1;return {['/Game/Test.Test']='mesh-id'} end
    return original(p)
end
local open=io.open
io.open=function(p,m) if p:find('/pick_meshes/',1,true) then return {close=function() end} end return open(p,m) end
local M=original(path)
assert(count==0 and not M.supported('/Game/Test.Test'))
M.load('UEDPIE_0_First');assert(count==1 and M.supported('/Game/Test.Test'))
M.load('First');assert(count==1)
assert(M.radius('/Game/Test.Test')==3 and count==2)
assert(M.radius('/Game/Test.Test')==3 and count==2)
M.load('Second');assert(count==3)
M.clear();assert(not M.supported('/Game/Test.Test'))
M.load('Second');assert(count==4)
M.load('../invalid');assert(count==4 and not M.supported('/Game/Test.Test'))
dofile=original
io.open=open
-- Exercise the generated index and shared mesh on disk as well as the loader fixture.
M.load('ReefoftheDrownedPotato')
local seaweed='/Game/Environment/Interior/Tower/Vistas/SM_Seaweed01.SM_Seaweed01'
assert(M.supported(seaweed) and M.radius(seaweed)>0)
M.clear();assert(not M.supported(seaweed))
print('Lazy world mesh loading OK')
