-- One undo for every editor: an action is one step (nested actions too); another editor's part is
-- asked once per key and step and put back last-in first; a world end forgets the steps.
local ends
local hooks,frames={},{}
local pres={}
local R={log=function() end,pre=function(p,f) pres[p]=f end,on=function(e,f) if e=='world_end' then local before=ends;ends=function() if before then before() end;f() end end end,
    post=function(p,f) hooks[p]=f end,next_frame=function(f) frames[#frames+1]=f end}
-- (the runtime's own: a callback's failure is told, not thrown; a valid object or nil)
R.finally=R.finally or function(fn,after,...) local r=table.pack(xpcall(fn,debug.traceback,...)) after() if not r[1] then error(r[2],0) end return table.unpack(r,2,r.n) end   -- (the runtime's)
R.call=R.call or function(fn,...) local ok,v=pcall(fn,...) if ok then return v end;print('[Error] '..tostring(v)) end
R.native=R.native or {load_asset=function(p) return StaticFindObject(p) end}
R.native.on_input=R.native.on_input or function() end
R.native.key_down=R.native.key_down or function() return false end
R.valid=R.valid or function(v) if v~=nil and (type(v)~='table' or v.IsValid==nil or v:IsValid()) then return v end end
local pc={IsLocalController=function() return true end,IsValid=function() return true end}
local session={is_creative=true,pc=pc}
local C={session=function() return session end}
StaticFindObject=function() return nil end
C.CREATIVE_PC='/Game/Blueprints/Gamemodes/CreativeMode/B_CreativePlayerController.B_CreativePlayerController_C'
local K=dofile('candidate/runtime-source/WorldKit/package.lua')(R,C)
local reverted={}
local value='a'
local function change(to,key)
    K.undo.add(key or 'value',function() local before=value;return function() value=before;reverted[#reverted+1]=before end end)
    value=to
end
-- What shows the next undo hears every change of the steps at once (user 11-20: the label lagged a step).
local told={};K.undo.on_change(function() told[#told+1]=K.undo.top() or 'none' end)
K.undo.begin('rename');change('b');K.undo.begin('inner');change('c');K.undo.finish();K.undo.finish()
assert(K.undo.count()==1 and K.undo.top()=='rename','nested actions are one step')
assert(#told==1 and told[1]=='rename','told once, when the step is added')
change('d')
assert(K.undo.count()==2,'a change outside an action is a step of its own')
K.undo.begin('nothing');K.undo.finish()
assert(K.undo.count()==2,'an action that changed nothing is no step')
assert(K.undo.last({})=='change' and value=='c')
local label,left=K.undo.last({})
assert(label=='rename' and left==0 and value=='a' and #reverted==2,'one revert per key and step: the state before the step')
assert(K.undo.last({})==nil,'nothing more to undo')
assert(told[#told]=='none','told when the last step is undone: nothing left')
K.undo.begin('two');change('x','one');change('y','other');K.undo.finish()
value='z';K.undo.last({})
assert(reverted[#reverted]=='a','parts are put back last-in first')
change('q');ends();assert(K.undo.count()==0,'a new level forgets the steps')
-- The selection: the game's select functions tell a change once a frame, for the local player only.
local told=0
K.on_selection(function(p) assert(p==pc);told=told+1 end)
local cp='/Game/Blueprints/Gamemodes/CreativeMode/B_CreativePlayerController.B_CreativePlayerController_C:'
hooks[cp..'SelectActor'](pc);hooks[cp..'DeselectSingleActor'](pc)
hooks[cp..'SelectMultiple']({IsLocalController=function() return false end})
assert(#frames==1,'one telling per frame');frames[1]();assert(told==1)
-- Selecting many: each new object is marked once and the game's SelectMultiple runs once (it
-- marks every selected object again, so one call per object would cost the square).
local game={marks=0,selected={}}
local function actor(n) return {n=n,GetAddress=function() return n end,IsValid=function() return true end,IsA=function() return false end} end
local function arr(t) return setmetatable({GetArrayNum=function() return #t end},{__index=function(_,i) return t[i] end}) end
local gpc={}
function gpc:SelectActor(a) game.marks=game.marks+1;a.marked=true end
function gpc:SelectMultiple(a) self.list[#self.list+1]=a;for _,x in ipairs(self.list) do self:SelectActor(x) end end
function gpc:DeselectMultipleActors() self.list={} end
gpc.list={}
setmetatable(gpc,{__index=function(t,k) if k=='SelectedActors' then return arr(rawget(t,'list')) end end,
    __newindex=function(t,k,v) if k=='SelectedActors' then rawset(t,'list',v) else rawset(t,k,v) end end})
local many={};for i=1,300 do many[i]=actor(i) end
K.selectMany(gpc,many,false)
local all=true;for _,a in ipairs(many) do all=all and a.marked==true end
assert(all and #gpc.list==300,'every object is selected')
assert(game.marks<=2*300,'marks stay linear: '..game.marks)
local more={actor(301),many[1]};K.selectMany(gpc,more,true)
assert(#gpc.list==301,'adding keeps the selection and skips the selected')
-- The player's own editing with the game is a step too (user 11-20: the undo named an old action of the tools).
local CTRL='/Game/Blueprints/Gamemodes/CreativeMode/B_CreativePlayerController.B_CreativePlayerController_C:'
R.values=R.values or function(t) return t end
local placed={}
local gp={PlacedActors=setmetatable({},{__index=function(_,i) return placed[i] end})}
function gp.PlacedActors:GetArrayNum() return #placed end
local function named(n) local a=actor(n);a.GetFullName=function() return 'BP_Barrel /Game/Level.Level:PersistentLevel.B_'..n end;return a end
local before=K.undo.count()
pres[CTRL..'PlaceActorServer'](gp);placed[#placed+1]=named(501);hooks[CTRL..'PlaceActorServer'](gp)
assert(K.undo.count()==before+1 and K.undo.top()=='place','the palette\'s place is a step: undo names it')
K.undo.begin('brush stroke');K.undo.finish()
pres[CTRL..'DuplicateMultipleServer'](gp);placed[#placed+1]=named(502);hooks[CTRL..'DuplicateMultipleServer'](gp)
assert(K.undo.top()=='copy','the game\'s copy after a tool\'s step: the copy is the last')
print('PASS WorldKit undo and selection')
