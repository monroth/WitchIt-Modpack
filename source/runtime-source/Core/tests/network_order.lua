local J=dofile('candidate/runtime-source/WitchItRuntime/Scripts/json.lua')
local make=dofile('candidate/runtime-source/Core/net.lua')
local function level(world) return world and world:GetFullName():match('([^%.:]+)$') or nil end   -- (as Core's C.level)
local function runtime()
 local r={json=J,base64=dofile('candidate/runtime-source/WitchItRuntime/Scripts/base64.lua'),hooks={},events={}}
 function r.post(path,fn) r.hooks[path]=fn end
 function r.on(event,fn) local was=r.events[event];r.events[event]=was and function(...) was(...);fn(...) end or fn end
 function r.log() end
 r.timers={}
 function r.after(ms,fn) local t={ms=ms,fn=fn};r.timers[#r.timers+1]=t;return function() t.cancelled=true end end
 return r
end
local hr,cr=runtime(),runtime()
local hostpc={PlayerState={PlayerId=7},NetConnection={CurrentNetSpeed=100000}}
local clientpc={}
function hostpc:GetAddress() return 7 end
function hostpc:HasAuthority() return true end
function hostpc:IsLocalPlayerController() return false end
function clientpc:GetAddress() return 8 end
function clientpc:HasAuthority() return false end
function clientpc:IsLocalPlayerController() return true end
local hc={level=level,session=function() return {role='host'} end}
local cc={level=level,session=function() return {role='client',pc=clientpc,is_vanilla_session=false} end}
local hn,ht=make(hr,hc)
local cn=make(cr,cc)
local prefix='/Game/Blueprints/Player/B_PlayerController.B_PlayerController_C:'
function hostpc:ClientSetRevisionNumber(text) cr.hooks[prefix..'ClientSetRevisionNumber'](clientpc,text) end
function clientpc:ExecuteConsoleCommandFromClient(text) hr.hooks[prefix..'ExecuteConsoleCommandFromClient'](hostpc,text) end
hn.publish('map',{name='first'})
hn.publish('map',{name='latest',payload=string.rep('x',5000)})
ht.add(hostpc);ht.replay(hostpc)
local seen
cn.watch('map',function(value) seen=value end)
assert(seen.name=='latest' and #seen.payload==5000,'Late join must see the latest complete value')
local sender
hn.on_request('vote',function(ps,value) sender=ps;assert(value.choice==2) end)
cn.request('vote',{choice=2});assert(sender==hostpc.PlayerState,'Sender comes from the native controller')
hn.watch('map',function(value) if value.name=='old' then hn.publish('map',{name='new'}) end end)
hn.publish('map',{name='old'});assert(seen.name=='new','Reentrant publication must not resend an older value')
ht.remove(hostpc);hn.publish('map',{name='gone'});assert(seen.name=='new')
cr.events.world_end()
local called=false;cn.watch('map',function() called=true end);assert(not called,'Travel clears cached world data')
hr.hooks[prefix..'ExecuteConsoleCommandFromClient'](hostpc,'WIR4:1:1:1:vote:AA==')
assert(J.decode(J.encode({1,2,3}))[3]==3)

-- Long messages are paced; short ones pass them; a newer value replaces one in flight.
local delivered=0
local deliver=hostpc.ClientSetRevisionNumber
function hostpc:ClientSetRevisionNumber(text) delivered=delivered+1;deliver(self,text) end
local function flush() while #hr.timers>0 do local t=table.remove(hr.timers,1);if not t.cancelled then t.fn() end end end
ht.add(hostpc)
local big
cn.watch('big',function(value) big=value end)
hn.publish('big',{n=1,payload=string.rep('a',100000)})
assert(delivered==12 and #hr.timers==1 and hr.timers[1].ms==112,'A long message starts with one burst paced to the rate')
hn.publish('map',{name='small'})
assert(seen.name=='small' and big==nil,'A short message passes a long one in flight')
hn.publish('big',{n=2,payload=string.rep('b',100000)})
flush()
assert(big.n==2 and #big.payload==100000,'The newest long value arrives whole')
local count=delivered
hn.publish('big',{n=3,payload=string.rep('c',100000)});ht.remove(hostpc);flush()
assert(delivered==count+12 and big.n==2,'A departed peer receives nothing more')

-- Acknowledgements: at most 96 chunks on their way unacknowledged; a silent peer gets nothing
-- more until it acknowledges.
ht.add(hostpc)
local forward=clientpc.ExecuteConsoleCommandFromClient
local acks=0
function clientpc:ExecuteConsoleCommandFromClient(text) if text:sub(1,6)=='WIR4A:' then acks=acks+1 end end
delivered=0;hr.timers={}
hn.publish('big',{n=4,payload=string.rep('d',300000)})
local function step() local t=table.remove(hr.timers,1);if not t.cancelled then t.fn() end;return t end
local last
while delivered<96 do last=step() end
assert(delivered==96 and acks==4,'Acknowledged every 24 chunks')
while #hr.timers>0 do step() end
assert(delivered==96,'A full window waits for acknowledgements, however long')
-- Acknowledging peers keep it going without waits.
clientpc.ExecuteConsoleCommandFromClient=forward
ht.remove(hostpc);ht.add(hostpc);hr.timers={};delivered=0
hn.publish('big',{n=5,payload=string.rep('e',300000)})
while #hr.timers>0 do step() end
assert(big.n==5,'With acknowledgements the long value arrives')

-- (user 11-16) A guest of a vanilla session asks the host only after the host has sent it something
-- (a vanilla host never gets mod data); then the rules can be offered there too.
local vanilla=true
local vc={level=level,session=function() return {role='client',pc=clientpc,is_vanilla_session=vanilla} end}
local vr=runtime();local vn=make(vr,vc)
local asked=0
local send=clientpc.ExecuteConsoleCommandFromClient
function clientpc:ExecuteConsoleCommandFromClient(text) asked=asked+1 end
vn.request('offer',{x=1});assert(asked==0,'not before the host spoke')
vr.hooks[prefix..'ClientSetRevisionNumber'](clientpc,'WIR4:1:1:1:hello:'..vr.base64.encode(J.encode({a=1})))
vn.request('offer',{x=1});assert(asked>0,'after the host spoke')
vr.events.world_end();asked=0;vn.request('offer',{x=1});assert(asked==0,'a new world: not before the host speaks again')
clientpc.ExecuteConsoleCommandFromClient=send
-- (live 11-20) A value the host sends for its level waits on a guest still in the travel level, and is handed
-- over on arriving there: the travel level's end no longer takes it away.
local function world(name) return {GetFullName=function() return 'World /Game/Maps/'..name..'.'..name end} end
local hostWorld,guestWorld=world('Graveyard'),world('TravelMap')
local lr,gr=runtime(),runtime()
lr.valid=function(v) return v end;gr.valid=function(v) return v end
local hostpc2,guestpc2={},{}
function hostpc2:GetAddress() return 17 end
function hostpc2:HasAuthority() return true end
function hostpc2:IsLocalPlayerController() return false end
function guestpc2:GetAddress() return 18 end
function guestpc2:HasAuthority() return false end
function guestpc2:IsLocalPlayerController() return true end
local ln,lt=make(lr,{level=level,session=function() return {role='host',world=hostWorld} end})
local gn,gt=make(gr,{level=level,session=function() return {role='client',pc=guestpc2,world=guestWorld,is_vanilla_session=false} end})
function hostpc2:ClientSetRevisionNumber(text) gr.hooks[prefix..'ClientSetRevisionNumber'](guestpc2,text) end
local mode
gn.watch('core.mode',function(value) mode=value end)
lt.add(hostpc2);ln.publish('core.mode','monroth.fap')
assert(mode==nil,'not handed over in the travel level')
gr.events.world_end();guestWorld=nil
assert(mode==nil)
guestWorld=world('Graveyard');gt.arrived(guestWorld)
assert(mode=='monroth.fap','handed over on arriving in the host\'s level')
mode=nil;gt.arrived(guestWorld);assert(mode==nil,'handed over once')
ln.publish('core.mode','creative');assert(mode=='creative','in the host\'s level at once')
print('PASS network: latest values, requests, pacing, acknowledged window')
