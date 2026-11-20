local hooks,pre,events={},{},{}
local pointClass='Objective/B_ObjectiveWitchRespawnPoint'
local function point(z,unsafe)
 local p={position={X=1,Y=2,Z=z},rotation={Pitch=10,Yaw=20,Roll=30},scale={X=2,Y=3,Z=4},unsafe=unsafe,
  RootComponent={SetMobility=function()end}}
 function p:K2_GetActorLocation()return self.position end
 function p:K2_GetActorRotation()return self.rotation end
 function p:GetActorScale3D()return self.scale end
 function p:SetActorScale3D(v)self.scale=v end
 function p:K2_TeleportTo(v,r)self.position=v;self.rotation=r;return true end
 function p:SetActorEnableCollision(v)self.collision=v end
 function p:K2_DestroyActor()self.destroyed=true end
 return p
end
local safe,unsafe=point(80),point(80,true)
local gm={AllWitchRespawnPoints={}}
local options={CustomMapSelected=false,MapData={builtin=false}}
local session={gm=gm,gi={UsedMatchOptions=options},mode='monroth.fap',role='host'}
local found={[pointClass]={safe,unsafe}}
local S={R={},C={session=function()return session end},O='Objective/',F={builtin='builtin'},
 path=function(folder,name,method)return folder..name..(method and ':'..method or '')end,
 values=function(v)return v end,
 distance=function(a,b)return (a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2 end,
 ground=function(p)if not p.unsafe then return {witch={X=5,Y=6,Z=98},marker={X=5,Y=6,Z=80}}end end}
S.R.post=function(p,fn)hooks[p]=fn end
S.R.pre=function(p,fn)pre[p]=fn end
S.R.observe=S.R.pre
S.R.on=function(p,fn)events[p]=fn end
S.R.find_all=function(path)local rows={};for i,p in ipairs(found[path] or {})do rows[i]=p end;return rows end
dofile('candidate/runtime-source/FillAPotPlus/tests/lib/scope.lua')(S)
S.R.native={spawn=function(_,_,pose,init)
 local p=point(pose.Z);p.SetReplicates=function()end;init(p);return p
end}
dofile('candidate/runtime-source/FillAPotPlus/respawn.lua')(S)
local respawn='Objective/B_ObjectiveGameMode:RespawnWitch'
pre['Objective/B_ObjectiveGameMode:SpawnReviveTotem']()
assert(#gm.AllWitchRespawnPoints==2,'discover points when native totem spawning consumes them')
pre[respawn](gm)
assert(#gm.AllWitchRespawnPoints==1 and safe.position.Z==98 and safe.scale.Z==1 and safe.rotation.Pitch==0)
-- The native respawn body reads only this safe temporary array.
hooks[respawn](gm)
assert(#gm.AllWitchRespawnPoints==2 and safe.position.Z==80 and safe.scale.Z==4 and safe.rotation.Pitch==10)
gm.AllWitchRespawnPoints={unsafe};pre[respawn](gm);assert(#gm.AllWitchRespawnPoints==0);hooks[respawn](gm)
local totem=point(120);assert(S.groundTotem(totem) and totem.position.Z==80 and totem.scale.Z==1)
assert(not S.groundTotem(unsafe) and unsafe.destroyed and unsafe.collision==false)
-- Only official maps get fallback points from native player starts.
found[pointClass]={};gm.AllWitchRespawnPoints={}
found['/Game/Blueprints/Player/PlayerStarts/B_WitchPlayerStart.B_WitchPlayerStart_C']={point(96)}
S.prepareRespawns();assert(#gm.AllWitchRespawnPoints==1)
gm.AllWitchRespawnPoints={};options.CustomMapSelected=true;S.prepareRespawns();assert(#gm.AllWitchRespawnPoints==0)
session.mode='vanilla';pre[respawn](gm);assert(#gm.AllWitchRespawnPoints==0)
session.mode='monroth.fap';session.role='client';pre[respawn](gm);assert(#gm.AllWitchRespawnPoints==0)
print('PASS consumption-time point discovery, official-only starts, temporary safe respawn poses and totem grounding')
