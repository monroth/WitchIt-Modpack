-- World teardown can leave a valid parent with expired native children.
local original_dofile=dofile
local hooks,events,I={},{},nil
local R={post=function(path,fn)hooks[path]=fn end,on=function(event,fn)events[event]=fn end,
 native={on_save=function()end},valid=function(value)return not (value and value.dead) and value or nil end}
local C={on_session=function()end}
local cleaned,resets=0,0
local package=original_dofile('candidate/runtime-source/UIKit/package.lua')
dofile=function(path)
 return function(_,_,_,internals)
  I=internals
  if path:match('widgets.lua$') then
   I.destructors[#I.destructors+1]=function(state)
    state.child:RestoreNativeState();cleaned=cleaned+1
   end
   I.resets[#I.resets+1]=function()resets=resets+1 end
  end
 end
end
package(R,C)
dofile=original_dofile
local function screen(id)return {GetAddress=function()return id end}end
local live=screen(1)
local state=I.state(live)
state.child={RestoreNativeState=function()end}
state.actions[11]=true;I.actions[11]=true
hooks['/Script/UMG.UserWidget:Destruct'](live)
assert(cleaned==1 and I.screens[1]==nil and I.actions[11]==nil,
 'ordinary widget destruction restores native state and releases actions')
local retiring=screen(2)
state=I.state(retiring)
state.child=setmetatable({},{__index=function()error('Native object expired')end})
I.actions[22]=true
state.actions[22]=true
local cached=screen(3);I.state(cached).actions[33]=true;I.actions[33]=true
retiring.dead=true
events.world_end()
assert(cleaned==1 and resets==1 and I.screens[2]==nil and I.actions[22]==nil,
 'world teardown forgets dead screens without dereferencing their native children')
assert(I.screens[3] and I.actions[33],'a cached screen that survives the world keeps its state')
-- Later native Destruct callbacks have no stale state left to clean.
hooks['/Script/UMG.UserWidget:Destruct'](retiring)
assert(cleaned==1)
print('PASS UIKit destruction restores live widgets; world teardown only releases references')
