-- Marker looks: only primitive parts get collision (a decal has none), and one look that fails
-- leaves the other markers of the batch drawn.
FName=function(s) return s end
local frames,errors={},{}
local R={next_frame=function(fn) frames[#frames+1]=fn;return function() end end,valid=function(v) return v end,
    post=function() end,call=function(fn,...) local ok,e=pcall(fn,...);if not ok then errors[#errors+1]=e end end,on=function() end,
    native={on_asset=function() return function() end end},packages={WorldKit={on_selection=function() end,on_changed=function(fn) changedFn=fn end}}}
local hooks={post=function() end,on=function() end}
local C={session=function() return {} end,scoped=function() return {actors=function() end,post=function() end,on=function() end} end,on_playtest=function() end}
local serial=0
local function part(class)
    class=class:match('([^.]+)$')
    serial=serial+1
    local c={class=class,id=serial}
    function c:SetMobility() end
    function c:SetComponentTickEnabled() end
    function c:K2_AttachToComponent(parent) self.parent=parent end
    function c:IsA(path) return path=='/Script/Engine.PrimitiveComponent' and self.class~='DecalComponent' end
    if class~='DecalComponent' then
        function c:SetCollisionEnabled(v) self.collision=v end
        function c:SetGenerateOverlapEvents() end
        function c:SetCastShadow() end
        function c:SetVisibility() end
    end
    return c
end
local function actor()
    serial=serial+1
    local a={id=serial,parts={},RootComponent={root=true}}
    function a:GetAddress() return self.id end
    function a:K2_GetActorLocation() return {X=0,Y=0,Z=0} end
    function a:K2_GetActorRotation() return {Yaw=0} end
    function a:GetTransform() return {Rotation={X=0,Y=0,Z=0,W=1}} end
    function a:K2_GetComponentsByClass() return {} end
    function a:AddComponentByClass(class) local c=part(class);self.parts[#self.parts+1]=c;return c end
    return a
end
local kinds={
    -- (active here: drawn outside the editor, as a teleporter in a match)
    cauldron={active=function() return true end,look=function(a,info,L) L.part('StaticMeshComponent');L.part('DecalComponent') end},
    broken={active=function() return true end,look=function() error('this look fails') end},
    editorOnly={look=function(a,info,L) L.part('StaticMeshComponent') end},
}
local editing=false
local M={asset=function(p) return p end,values=function(t) return t end,
    kindOf=function(info) return kinds[info.kind] end,editing=function() return editing end,markers=function() return {} end,
    onEditor=hooks,path=function() return '' end,marker=function() end}
dofile('candidate/runtime-source/Core/tests/lib/effects.lua')(R,C)
dofile('candidate/runtime-source/MapMarkers/look.lua')(R,C,M)
local pot,bad=actor(),actor()
M.look(pot,{kind='cauldron'});M.look(bad,{kind='broken'})
for _,fn in ipairs(frames) do fn() end
assert(#pot.parts==2,'the cauldron\'s look is drawn, the other look failing in the same batch')
-- (user) Outside the editor, Playtest among them, a kind not active there shows no look.
frames={}
local hidden=actor();M.look(hidden,{kind='editorOnly'});for _,fn in ipairs(frames) do fn() end
assert(#hidden.parts==0,'no marker look in Playtest')
local mesh,decal=pot.parts[1],pot.parts[2]
assert(mesh.parent==pot.RootComponent and decal.parent==pot.RootComponent,'the parts hang on the block: they go with it however it moves')
assert(mesh.collision==0 and decal.collision==nil,'the mesh gets no collision set; the decal is left alone (it has none)')
assert(#errors==1 and tostring(errors[1]):find('this look fails'),'the failing look is reported, alone')
print('PASS marker looks: decal parts, one failing look leaves the others')
