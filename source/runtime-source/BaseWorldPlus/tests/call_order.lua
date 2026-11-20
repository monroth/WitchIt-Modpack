local dir=debug.getinfo(1,'S').source:match('^@(.+[\\/])')..'../'
local function clone(v)
 if type(v)~='table'then return v end
 local out={};for k,x in pairs(v)do out[k]=clone(x)end;return out
end
local function empty()return {ForEach=function()end}end
local world_path='/Game/Maps/GameMaps/TowerIsland/TowerIsland.TowerIsland'
local world={GetFullName=function()return 'World '..world_path end,GetFName=function()return {ToString=function()return 'TowerIsland' end}end}
local path=world_path..':PersistentLevel.Rock'
local audio={VolumeMultiplier=.7,AttachChildren=empty()}
function audio:GetFullName()return 'AudioComponent '..path..'.Audio'end
function audio:IsA(cls)return cls=='/Script/Engine.AudioComponent'end
function audio:SetVolumeMultiplier(v)self.VolumeMultiplier=v end
local root={AttachChildren={ForEach=function(_,fn)fn(1,{get=function()return audio end})end}}
function root:GetFullName()return 'SceneComponent '..path..'.Root'end
function root:IsA()return false end
local actor={bHidden=false,bActorEnableCollision=true,RootComponent=root}
function actor:GetFullName()return 'StaticMeshActor '..path end
function actor:IsA(cls)return cls=='/Script/Engine.StaticMeshActor'end
function actor:GetWorld()return world end
function actor:SetActorHiddenInGame(v)self.bHidden=v end
function actor:SetActorEnableCollision(v)self.bActorEnableCollision=v end
local camera={GetCameraLocation=function()return {X=0,Y=0,Z=0}end}
local gm={LoadedLayoutFullPath='/maps/original.pl'}
local session={role='host',world=world,gm=gm,pc={PlayerCameraManager=camera},is_creative=true,is_playtest=false,is_vanilla_session=false}
local hooks,events,commands,keys,queue,watch,writes={},{},{},{},{},nil,{}
local disk,encoded={},{};local serial=0
local json={}
function json.encode(v)serial=serial+1;local id='json'..serial;encoded[id]=clone(v);return id end
function json.decode(bytes)assert(encoded[bytes],'bad JSON');return clone(encoded[bytes])end
local published,publications=nil,0
local R={native={on_input=function() end,key_down=function() return false end},json=json,valid=function(v)return v end,log=function()end,
 pre=function(p,f)hooks['pre '..p]=f end,post=function(p,f)hooks[p]=f end,
 on=function(e,f)local prev=events[e];events[e]=prev and function(...)prev(...);f(...)end or f end,key=function(id,_,f)keys[id]=f end,
 next_frame=function(f)queue[#queue+1]=f end,
 find_all=function()return {}end}
-- (the runtime's own: a callback's failure is told, not thrown; a valid object or nil)
R.finally=R.finally or function(fn,after,...) local r=table.pack(xpcall(fn,debug.traceback,...)) after() if not r[1] then error(r[2],0) end return table.unpack(r,2,r.n) end   -- (the runtime's)
R.call=R.call or function(fn,...) local ok,v=pcall(fn,...) if ok then return v end;print('[Error] '..tostring(v)) end
R.valid=R.valid or function(v) if v~=nil and (type(v)~='table' or v.IsValid==nil or v:IsValid()) then return v end end
local function drain()while #queue>0 do table.remove(queue,1)()end end
R.native.load_asset=function(path)return path end
R.native.file_read=function(p)return disk[p]end
R.native.file_write=function(p,bytes)writes[#writes+1]=p;disk[p]=bytes;return true end
R.native.on_save=function(f)R.save=f end
R.native.on_load=function(f)R.load=f end
-- Mode as Core decides it from the session fields this test changes.
local function current()
 session.mode=session.is_vanilla_session and 'vanilla' or session.is_creative and 'creative' or 'none'
 return session
end
local bwp
local C={session=current,on_playtest=function()end,on_session=function(f)C_changed=f end,
 map={loaded={},module=function(id,spec)if id=='monroth.bwp' then bwp=spec end end},
 net={publish=function(_,v)published=clone(v);publications=publications+1 end,watch=function(_,f)watch=f end}}
dofile('candidate/runtime-source/Core/tests/lib/scoped.lua')(R,C)
local messages={};local hideWindow={toggles=0,refreshes=0}
local U={message=function(_,text)messages[#messages+1]=text end,
 window=function(opts) hideWindow.opts=opts
  return {toggle=function() hideWindow.toggles=hideWindow.toggles+1 end,refresh=function() hideWindow.refreshes=hideWindow.refreshes+1 end} end}
RegisterConsoleCommandHandler=function(name,fn)commands[name]=fn end
StaticFindObject=function(p)if p==path then return actor end end
local row={kind='actor',path=path}
local data={version=1,world='TowerIsland',hidden={first=row}}
local function record(value)C.map.loaded={['monroth.bwp']={version=1,data=value}}end
record(json.encode(data))
-- World edits, and Editor tweaks (the hide tool) over it.
C.CREATIVE_PC='/Game/Blueprints/Gamemodes/CreativeMode/B_CreativePlayerController.B_CreativePlayerController_C'
R.packages={WindowKit=U,WorldKit=dofile('candidate/runtime-source/WorldKit/package.lua')(R,C)}
dofile('candidate/runtime-source/Core/tests/lib/effects.lua')(R,C)
U.parts=dofile('candidate/runtime-source/UIKit/tests/lib/actions.lua')(R)
R.packages.MapMarkers=dofile('candidate/runtime-source/MapMarkers/package.lua')(R,C,U)
R.packages.BaseWorldPlus=dofile(dir..'package.lua')(R,C,U)
local tweaks=dofile(dir..'../EditorTweaks/package.lua')(R,C,U)
local info={world=world,layout_id='original',host=true,is_creative=true,is_playtest=false}
events.layout_loaded(info)
assert(actor.bHidden and not actor.bActorEnableCollision and audio.VolumeMultiplier==0)
assert(publications==1,'A layout publishes its completed scenery once')
drain()   -- (WorldKit tells its editors of the loaded layout on the next frame)
assert(publications==1)
-- Shipping PrintString does not display authoring feedback. Use the local native
-- game-message widget, without broadcasting the host's current selection.
local notices={}
FText=function(value)return value end
session.gi={IngameUIManager={GameMessagesWidget={AddGameMessage=function(_,source,target,kind)
 assert(target=='' and kind==12);notices[#notices+1]=source
end}}}
camera.GetCameraRotation=function()return {Pitch=0,Yaw=0}end
local find=StaticFindObject
StaticFindObject=function(p)
 if p=='/Script/Engine.Default__KismetSystemLibrary'then return {LineTraceSingle=function()return false end}end
 if p=='/Script/Engine.Default__GameplayStatics'then return {GetRealTimeSeconds=function()return 0 end}end
 return find(p)
end
-- Home switches the aim on (the aimed object blinks while it ticks) and off; the window follows.
assert(hideWindow.opts.available())
keys['bwp.select']();assert(publications==1 and #queue==1,'aim on ticks on the next frame')
keys['bwp.select']();drain();assert(#queue==0,'aim off stops ticking')
session.role='client';assert(not hideWindow.opts.available());keys['bwp.select']();assert(#queue==0)
session.role='host';session.is_vanilla_session=true;keys['bwp.select']();assert(#queue==0)
session.is_vanilla_session=false
StaticFindObject=find
-- EndPlayTest reloads the same document inside its call, before the POST hook.
local creative='/Game/Blueprints/Gamemodes/CreativeMode/B_CreativeGameMode.B_CreativeGameMode_C:'
hooks['pre '..creative..'EndPlayTest'](gm)
session.is_playtest=true
actor.bHidden=false;actor.bActorEnableCollision=true
events.layout_loaded(info)
hooks[creative..'EndPlayTest'](gm)
assert(actor.bHidden and audio.VolumeMultiplier==0)
session.is_playtest=false
tweaks.edit(row,false);drain()
assert(not actor.bHidden and actor.bActorEnableCollision and audio.VolumeMultiplier==.7)
tweaks.undo();drain();assert(actor.bHidden)
-- Clear shows every hidden object; one undo hides them all again, published once each way.
do
 local before=publications
 tweaks.edit_group({row},false);drain();assert(not actor.bHidden and publications==before+1)
 tweaks.undo();drain();assert(actor.bHidden and publications==before+2,'one undo step for the whole clear')
end
-- A save while Editor tweaks does not edit this map (vanilla session) keeps the map's edits as they came.
do
 local was=session.is_vanilla_session;session.is_vanilla_session=true;events.world_end()
 local v,d=bwp.save();assert(v==1 and d==C.map.loaded['monroth.bwp'].data,'edits survive a save in a vanilla session')
 session.is_vanilla_session=was;events.layout_loaded(info)
end
-- A save carries the edits of that moment in the map record.
local version,saved=bwp.save()
assert(version==1 and next(json.decode(saved).hidden),'the hidden object goes into the layout')
events.layout_saved{layout_id='save-as'}
assert(published.layout=='save-as')
events.layout_saved{layout_id='save-as_AutoSave',autosave=true}
assert(published.layout=='save-as','an autosave keeps the published layout')
-- A snapshot applies immediately in the loaded guest world.
events.world_end();session.role='client';actor.bHidden=false;actor.bActorEnableCollision=true;audio.VolumeMultiplier=.7
watch{layout='guest-layout',world=data.world,data=data}
assert(actor.bHidden)
events.layout_loaded{world=world,layout_id='guest-layout',host=false,is_creative=false}
assert(actor.bHidden)
watch(false)
assert(not actor.bHidden and actor.bActorEnableCollision and audio.VolumeMultiplier==.7)
-- The host's edits can arrive before the host's mode: they wait for it.
events.world_end();session.is_vanilla_session=true;C_changed(current())
watch{layout='guest-layout',world=data.world,data=data}
assert(not actor.bHidden,'A vanilla session shows no edits')
session.is_vanilla_session=false;C_changed(current())
assert(actor.bHidden,'Edits that arrived before the host mode apply once it arrives')
watch(false);assert(not actor.bHidden)
-- Unread data never gets replaced by empty edits on Save As.
session.role='host';gm.LoadedLayoutFullPath='/maps/broken.pl';drain()
record('invalid')
events.layout_loaded{world=world,layout_id='broken',host=true,is_creative=true}
local kept,same=bwp.save()
assert(kept==1 and same=='invalid' and #messages>0,'unread edits stay in the map as they came')
record(json.encode(data))
-- Vanilla hosts cannot activate companions or make new edits, including Creative.
events.world_end();session.is_vanilla_session=true;gm.LoadedLayoutFullPath='/maps/original.pl'
for _,creative in ipairs({false,true}) do
 session.is_creative=creative
 events.layout_loaded{world=world,layout_id='original',host=true,is_creative=creative}
 keys['bwp.hide']();keys['bwp.undo']();tweaks.edit(row,true);drain();assert(not actor.bHidden and actor.bActorEnableCollision)
end
session.is_vanilla_session=false;events.layout_loaded(info);assert(actor.bHidden)
session.is_vanilla_session=true;C_changed(current());assert(not actor.bHidden)
session.role='client';watch{layout='original',data=data};events.layout_loaded{world=world,layout_id='original',host=false,is_creative=true}
assert(not actor.bHidden,'Vanilla guests ignore companions')
-- Component setters preserve explicit false on show, and hide a visible part.
local Objects=dofile(dir..'objects.lua')
local part={bVisible=true,bHiddenInGame=false,BodyInstance={CollisionEnabled=3}}
function part:SetVisibility(v,children)assert(children==false);self.bVisible=v end
function part:SetHiddenInGame(v,children)assert(children==false);self.bHiddenInGame=v end
function part:SetCollisionEnabled(v)self.BodyInstance.CollisionEnabled=v end
local original=Objects.componentCapture(part)
Objects.componentSet(original,true);assert(not part.bVisible and part.bHiddenInGame and part.BodyInstance.CollisionEnabled==0)
Objects.componentSet(original,false);assert(part.bVisible and not part.bHiddenInGame and part.BodyInstance.CollisionEnabled==3)
-- ISM matrix decomposition loses rotation at zero scale. Undo uses saved scalars.
local Instances=dofile(dir..'instances.lua')
local transforms={{Translation={X=1,Y=2,Z=3},Rotation={X=.2,Y=.3,Z=.4,W=.5},Scale3D={X=1,Y=2,Z=3}},
 {Translation={X=4,Y=5,Z=6},Rotation={X=0,Y=0,Z=0,W=1},Scale3D={X=1,Y=1,Z=1}}}
local component={StaticMesh={GetFullName=function()return 'StaticMesh /Game/Rock.Rock'end}}
function component:GetInstanceTransform(i,out)
 local t=clone(transforms[i+1]);for k,v in pairs(t)do out[k]=v end;return true
end
function component:UpdateInstanceTransform(i,t,worldspace,render,teleport)
 assert(worldspace==false and render and teleport);transforms[i+1]=clone(t)
 if t.Scale3D.X==0 then transforms[i+1].Rotation={X=0,Y=0,Z=0,W=1}end
 return true
end
local instance=Instances.row(component,0,'/Game/Component')
Instances.set(component,instance,true);assert(transforms[1].Scale3D.X==0 and transforms[2].Translation.X==4)
Instances.set(component,instance,false);assert(transforms[1].Rotation.X==.2 and transforms[1].Scale3D.Y==2)
-- Connected groups restore directly, then schedule the next group once.
local Geometry=dofile(dir..'geometry.lua')
local a={source='a',class='/Game/Leaf.Leaf_C',role='local',references={'b'}}
local b={source='b',class='/Script/Engine.StaticMeshActor',role='local'}
local waiting,restored={},0
R.native.on_asset=function(p,f)waiting[p]=f end
R.native.on_idle=function(fn) fn();return function() end end
R.native.source_actors=function(rows)assert(#rows==2);restored=restored+1;return {}end
local s={host=true,world=world,spawned={},data={geometry={format='FAPP_SOURCE_GEOMETRY',version=3,actors={a,b},states={}}}}
local done=false
Geometry.restore(R,s,function()return true end,function()done=true end)
assert(restored==1)
drain()
assert(restored==1 and done and #queue==0)
print('BaseWorldPlus call order checks passed')
