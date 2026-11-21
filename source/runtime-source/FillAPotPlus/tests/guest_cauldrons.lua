-- A guest gives replicated cauldrons the Fill a Pot+ look even when they replicated
-- before the host's mode arrived (user 11-08: some guests saw no filled cauldron, teleports as
-- stones): Core's scope.actors applies to arriving actors and to those already there.
local base='candidate/runtime-source/FillAPotPlus/'
local post,watch,listeners={},{},{}
local function changed(s) for _,fn in ipairs(listeners) do fn(s) end end
local R={log=function() end,}
function R.post(path,fn)post[path]=post[path] or {};table.insert(post[path],fn)end
function R.pre()end
function R.on()end
function R.valid(v)return v end
local pot={looked=0,location={X=1,Y=2,Z=3}}
function pot:K2_GetActorLocation()return self.location end
function pot:IsA(c)return c=='O/B_ObjectiveCauldron'end
local pots={}
local markers={}
function R.find_all(c)
 if c=='O/B_ObjectiveCauldron' then return pots end
 assert(c=='/Game/Blueprints/StaticProps/Placeable/BP_PlaceableStaticProp.BP_PlaceableStaticProp_C');return markers
end
local session={role='client',mode='vanilla'}
local S={R=R,O='O/',CORE='Core/',MATCH='Match/'}
S.C={state=function() end,session=function()return session end,on_playtest=function()end,on_session=function(fn)listeners[#listeners+1]=fn;fn(session)end,
    net={watch=function(topic,fn)watch[topic]=fn end,publish=function()end},map={on_load=function()end}}
S.codec=dofile(base..'codec.lua')(dofile('candidate/runtime-source/WitchItRuntime/Scripts/json.lua'),{})
function S.path(folder,name,method)return folder..name..(method and ':'..method or '')end
dofile(base..'tests/lib/scope.lua')(S)
function S.asset()end
function S.distance(a,b)return math.abs(a.X-b.X)+math.abs(a.Y-b.Y)+math.abs(a.Z-b.Z)end
dofile(base..'world.lua')(S)
function S.potAppearance(p)p.looked=p.looked+1 end
function S.marker(a)return a.info end
function S.markerLook(a)a.looked=a.looked+1 end
local placeable='/Game/Blueprints/StaticProps/Placeable/BP_PlaceableStaticProp.BP_PlaceableStaticProp_C'
local function block(info) return {looked=0,info=info,IsA=function(_,c) return c==placeable end} end
local plain=block({kind=1})
markers={plain}
-- The host's cauldron rows arrive first, before the cauldron and the mode.
watch['fap.cauldrons']{{position={X=1,Y=2,Z=3},info={}}}
-- The cauldron replicates while the guest's session still counts as vanilla: the gated hook stays silent.
pots[1]=pot
for _,fn in ipairs(post['/Script/Engine.Actor:OnRep_Owner'] or {}) do fn(pot) end
assert(pot.looked==0)
-- The host's mode arrives.
session={role='client',mode='monroth.fap'};changed(session)
assert(pot.looked==1,'A cauldron that replicated before the mode gets its look when the mode arrives')
assert(plain.looked==0,'a cauldron marker shows its look only in the editor (MapMarkers)')
changed(session);assert(pot.looked==1,'Only the change into the match applies the look')
print('Guest cauldron look after a late mode passed')
