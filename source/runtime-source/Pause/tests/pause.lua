-- The pause: the host's key stops the round timer and tells everyone through the game; the next
-- round's timer start keeps it stopped; the key again resumes it. Not in Creative, not as a guest.
local hooks,keys,entries,events,boxes={},{},{},{},{}
local R={native={},valid=function(v) return v end,log=function() end,
    pre=function() end,post=function(p,f) hooks[p]=f end,on=function() end,after=function() return function() end end,
    key=function(id,_,f) keys[id]=f end,settings=function(_,d) return d end,save_settings=function() end}
dofile('candidate/runtime-source/Core/tests/lib/mods.lua')(R)
local notices=0
local gs={SendGameMessageMulticast=function() notices=notices+1 end,IsA=function() return false end}
local gm={TimerIsCounting=true}
local session={role='host',mode='Objective',gs=gs,gm=gm}
local C={state=function() end,session=function() return session end,on_session=function() end}
C.scoped=function(applies) return {pre=function() end,on=function(e,f) events[e]=function(...) if applies(session) then return f(...) end end end,
    post=function(p,f) hooks[p]=function(...) if applies(session) then return f(...) end end end} end
local U={menu_entry=function(...) entries[#entries+1]={...} end,checkbox=function(_,o) boxes[o.label]=o;return {} end}
FText=function(s) return s end;FName=function(s) return s end
dofile('candidate/runtime-source/Pause/package.lua')(R,C,U)
local timerStart=hooks['/Game/Blueprints/Core/B_GameMode.B_GameMode_C:TimerStart']
keys['pause.timer']();assert(not gm.TimerIsCounting and notices==1,'the key pauses and tells everyone')
gm.TimerIsCounting=true;timerStart(gm);assert(not gm.TimerIsCounting,'a new round stays paused')
keys['pause.timer']();assert(gm.TimerIsCounting and notices==2,'the key again resumes')
assert(entries[1][3]=='Pause timer' and entries[1][6]()==true,'the host has the menu entry')
session.mode='creative';keys['pause.timer']();assert(gm.TimerIsCounting and notices==2,'not in Creative')
session.mode='Objective';session.role='client';assert(entries[1][6]()==false,'not for a guest')
-- The option: the game tells a player left, and the timer stops by itself (off by default).
session.role='host';gm.TimerIsCounting=true
R.option_groups()[1].build({},U)
assert(not next(boxes['Pause when a player leaves'].value and {1} or {}),'off by default')
for _,o in pairs(boxes) do assert(not o.label:find('time limit'),'no rejoin time limit any more') end
events.player_left({});assert(gm.TimerIsCounting,'off: a player leaving changes nothing')
boxes['Pause when a player leaves'].on_change(true)
events.player_left({});assert(not gm.TimerIsCounting and notices==3,'on: the timer stops and everyone is told')
events.player_left({});assert(not gm.TimerIsCounting and notices==3,'already paused: it stays paused')
keys['pause.timer']();assert(gm.TimerIsCounting,'the host resumes it as usual')
print('PASS pause')
