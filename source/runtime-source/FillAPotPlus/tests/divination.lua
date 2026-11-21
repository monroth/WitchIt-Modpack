local hook
local function prop(x,controlled,witch)return {IsControlledByWitch=controlled,Witch=witch,K2_GetActorLocation=function()return {X=x,Y=0,Z=0}end}end
local own=prop(0,false)
local controlled=prop(1,true)
local assigned=prop(2,false,{})
local free=prop(50,false)
local props={own,controlled,assigned,free}
local field='MeshList_3_9A021886472783B7C6D4C1A40C1D892E'
local gs={Cauldrons={{Active=true,Filled=false,WantedProp='class'}},Proplist={Contains=function()return true end,
 Find=function()return {get=function()return {[field]=props}end}end}}
local session={gs=gs,mode='monroth.fap',role='client'}
local S={COPIES="MeshList_3_9A021886472783B7C6D4C1A40C1D892E",R={valid=function(v)return v end,post=function(_,fn)hook=fn end},C={state=function() end,side=function(ps) local t=ps and ps.Team;return t==0 and "witch" or t==1 and "hunter" or nil end,session=function()return session end},
 values=function(v)return v end,distance=function(a,b)return (a.X-b.X)^2 end,
 rules=function() return {propIndicator=1,propSparksFrom=1} end,indicate=function(_,near) told=near end}
dofile('candidate/runtime-source/FillAPotPlus/tests/lib/scope.lua')(S)
dofile('candidate/runtime-source/FillAPotPlus/divination.lua')(S)
local pawn={IsA=function()return true end,ControllingProp=own,K2_GetActorLocation=function()return {X=0,Y=0,Z=0}end}
local widget={MaxDistanceSq=10000,GetOwningPlayerPawn=function()return pawn end}
assert(hook(widget)==.5)
assert(#told==1 and told[1].prop and told[1].d,'the wisps get every free wanted prop within their reach')
free.IsControlledByWitch=true;assert(hook(widget)==0)
session.mode='vanilla';assert(hook(widget)==nil)
print('PASS divination excludes own possessed prop, other controlled props and assigned witch props')
