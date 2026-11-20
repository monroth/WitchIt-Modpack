local pre,post,events,queue={},{},{},{}
local field='MeshList_3_9A021886472783B7C6D4C1A40C1D892E'
local function array(rows)
 function rows:ForEach(fn)for i=1,#self do local v=self[i];fn(i,{get=function()return v end})end end
 return rows
end
local function prop(id)
 local p={IsFreezed=true,StartAwake=false,IsSleeping=true}
 function p:GetAddress()return id end
 function p:GetClass()return 'class' end
 function p:K2_GetActorLocation()return {X=1,Y=2,Z=3}end
 function p:K2_GetActorRotation()return {Pitch=4,Yaw=5,Roll=6}end
 function p:GetActorScale3D()return {X=2,Y=3,Z=4}end
 for _,fn in ipairs({'SetReplicates','SetUncontrolledByWitch','AutoSetInitialPhysicsState','PutToSleep',
  'HandleSleepServer','WakeFromSleep','HandleWakeServer','UpdateFromFrozenState','FlushNetDormancy','ForceNetUpdate','SetActorTickEnabled'})do
  p[fn]=function(self,value)self[fn..'Called']=value==nil or value end
 end
 return p
end
local original=prop(1)
local meshes=array{original};local gs={AllProps=array{original},Proplist={Contains=function() return true end,Find=function()return {get=function()return {[field]=meshes}end}end}}
local session={gm='gm',gs=gs,mode='monroth.fap',role='host'}
local S={COPIES=field,C={session=function()return session end},R={native={}}}
local R=S.R
function R.valid(v)return v end
function R.post(path,fn)post[path]=fn end
function R.on(event,fn)events[event]=fn end
function R.next_frame(fn)queue[#queue+1]=fn end
dofile('candidate/runtime-source/FillAPotPlus/tests/lib/scope.lua')(S)
function RegisterEndPlayPreHook(fn)pre.destroy=fn end
local restored,spawns
spawns=0
function R.native.spawn(class,gm,pose,init)
 spawns=spawns+1
 assert(class=='class' and gm=='gm' and pose.X==1 and pose.Yaw==5 and pose.ScaleZ==4)
 restored=prop(10+spawns);init(restored)
 assert(restored.InitialIsSleeping and restored.IsFreezed and not restored.StartAwake)
 return restored
end
dofile('candidate/runtime-source/FillAPotPlus/possession.lua')(S)
local pawn='/Game/Blueprints/Player/Pawns/B_PropPawnPhysics.B_PropPawnPhysics_C:'
local body={ControllingProp=original,PropTemplate=original}
local function destroy(p,reason)pre.destroy(p,{get=function()return reason end})end
local function drain()while #queue>0 do table.remove(queue,1)()end end
session.role='client';post[pawn..'PropPossessed'](body);destroy(original,0);drain();assert(spawns==0)
session.role='host';body.ControllingProp=prop(2);post[pawn..'OnRep_ControllingProp'](body);destroy(body.ControllingProp,0);drain();assert(spawns==0)
body.ControllingProp=original
post[pawn..'OnRep_ControllingProp'](body)
original.K2_GetActorLocation=function()error('must preserve first accepted pose')end
post[pawn..'PropPossessed'](body)
destroy(original,0);assert(spawns==0);drain()
assert(spawns==1 and gs.AllProps[1]==restored and meshes[1]==restored)
assert(restored.PutToSleepCalled and restored.HandleSleepServerCalled and restored.UpdateFromFrozenStateCalled)
local first=restored
destroy(first,0);drain();assert(spawns==1,'unpossessed replacement must not return')
-- Travel destroys originals without spawning replacements.
original=prop(3);gs.AllProps[1]=original;meshes[1]=original
body.ControllingProp=original;body.PropTemplate=original
post[pawn..'PropPossessed'](body);destroy(original,1);drain();assert(spawns==1)
session.mode='vanilla';post[pawn..'PropPossessed'](body);destroy(original,0);drain();assert(spawns==1)
print('PASS accepted map possession returns saved pose, scale, physics and native pool slots only after destruction')
