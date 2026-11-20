-- Which actors hide whole: one table in objects.lua decides it, lists them and names effects.
local O=dofile('candidate/runtime-source/BaseWorldPlus/objects.lua')
-- (an actor of class, made from the classes after it: IsA by the path's class name)
local function actor(class,...)
    local chain={[class]=true};for _,parent in ipairs({...}) do chain[parent]=true end
    return {GetFullName=function() return class..' /Game/Maps/X.X:PersistentLevel.A' end,
        IsA=function(_,path) return chain[path:match('[%./]([^%./]+)$')]==true end}
end
for _,class in ipairs({'StaticMeshActor','NiagaraActor','Emitter','PointLight','SpotLight','RectLight','AmbientSound',
    'B_Palm01_C','B_Palm07_C','B_SpringPad_C'}) do
    assert(O.allowed(actor(class)),class..' hides whole')
end
assert(O.allowed(actor('B_SpringPadMushroom_C','B_SpringPad_C')),'a class made from a whole one hides whole (a mushroom spring pad)')
for _,class in ipairs({'B_Door_C','B_Palm06_C','BP_PlaceableStaticProp_C','B_TeleporterZone_C'}) do
    assert(not O.allowed(actor(class)),class..' hides one component at a time')
end
assert(#O.classes==14 and #O.effects==6,'every whole class is listed for nearby; effects are the aim-by-position ones')
for _,path in ipairs(O.effects) do
    local listed=false;for _,c in ipairs(O.classes) do if c==path then listed=true end end
    assert(listed,'an effect is also a whole class')
end
-- A hidden object keeps its place: physics stops while hidden and comes back on show.
local function component(name,physics)
    local c={BodyInstance={bSimulatePhysics=physics,CollisionEnabled=3},AttachChildren={},bVisible=true,bHiddenInGame=false}
    function c:GetFullName() return 'BoxComponent /Game/Maps/X.X:PersistentLevel.Pad.'..name end
    function c:IsA(class) return class=='/Script/Engine.PrimitiveComponent' end
    function c:SetSimulatePhysics(v) self.BodyInstance.bSimulatePhysics=v end
    function c:SetCollisionEnabled(v) assert(not self.BodyInstance.bSimulatePhysics or v~=0,'physics stops before collision goes');self.BodyInstance.CollisionEnabled=v end
    function c:SetVisibility(v) self.bVisible=v end
    function c:SetHiddenInGame(v) self.bHiddenInGame=v end
    return c
end
local box,trigger=component('Box',true),component('Trigger',false)
box.AttachChildren={{get=function() return trigger end}}
local pad={bHidden=false,bActorEnableCollision=true,RootComponent=box}
function pad:SetActorHiddenInGame(v) self.bHidden=v end
function pad:SetActorEnableCollision(v) assert(not box.BodyInstance.bSimulatePhysics or v,'physics stops before collision goes');self.bActorEnableCollision=v end
local saved=O.capture(pad)
O.hide(saved);assert(pad.bHidden and not pad.bActorEnableCollision and not box.BodyInstance.bSimulatePhysics)
O.restore(saved);assert(not pad.bHidden and pad.bActorEnableCollision and box.BodyInstance.bSimulatePhysics and not trigger.BodyInstance.bSimulatePhysics)
-- One part hidden alone: the same.
local part=O.componentCapture(box)
O.componentSet(part,true);assert(box.bHiddenInGame and box.BodyInstance.CollisionEnabled==0 and not box.BodyInstance.bSimulatePhysics)
O.componentSet(part,false);assert(not box.bHiddenInGame and box.BodyInstance.CollisionEnabled==3 and box.BodyInstance.bSimulatePhysics)
print('BaseWorldPlus whole-hidden classes passed')
