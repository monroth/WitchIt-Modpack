-- Non-colliding meshes use the same exact ray test as instances, and obey trace occlusion.
local mesh={name='/Game/M.M'}
local function actor(whole)
    return {whole=whole,bHidden=false,HasAnyFlags=function() return true end}
end
local function component(a,x,instanced)
    return {StaticMesh=mesh,bVisible=true,bHiddenInGame=false,a=a,x=x,instanced=instanced,
        HasAnyFlags=function() return true end,GetOwner=function(self) return self.a end,
        IsA=function(self) return self.instanced end,
        K2_GetComponentToWorld=function(self) return {Translation={X=self.x,Y=0,Z=0},Rotation={X=0,Y=0,Z=0,W=1},Scale3D={X=1,Y=1,Z=1}} end,
        GetInstanceCount=function() return 0 end}
end
local a,b=actor(true),actor(false)
local first,second=component(a,20),component(b,10)
local components={first,second,component(a,5,true)}
local R={valid=function(v) return v end,find_all=function(cls)
    if cls=='/Script/Engine.StaticMeshComponent' then return components end
    return {}
end}
local Objects={effects={},path=function(o) return o.name or 'component' end,
    allowed=function(o) return o.whole end,row=function(o) return {kind='actor',actor=o} end,
    componentRow=function(o,c) return {kind='component',actor=o,component=c} end}
local Instances={load=function() end,supported=function() return true end,radius=function() return 2 end,
    ray=function(r,origin,ray,limit) local d=r.worldTransform.Translation.X; if d<=limit then return d end end}
local hitDistance
StaticFindObject=function() return {LineTraceSingle=function(_,pc,origin,finish,ch,complex,ignore,draw,hit)
    if hitDistance then hit.Distance=hitDistance;hit.Component={Get=function() return nil end};return true end
    return false
end} end
local camera={GetCameraLocation=function() return {X=0,Y=0,Z=0} end,GetCameraRotation=function() return {Pitch=0,Yaw=0} end}
local P=dofile('candidate/runtime-source/EditorTweaks/pick.lua')(R,Objects,Instances)
local state={world={GetFName=function() return {ToString=function() return 'test' end} end}};local row=P.under({PlayerCameraManager=camera},state)
assert(row.kind=='component' and row.component==second)
hitDistance=8;assert(P.under({PlayerCameraManager=camera},state)==nil)
hitDistance=nil;second.bVisible=false;P.changed(state);row=P.under({PlayerCameraManager=camera},state)
assert(row.kind=='actor' and row.actor==a)
a.bHidden=true;P.changed(state);assert(P.under({PlayerCameraManager=camera},state)==nil)
print('EditorTweaks mesh picking OK')
