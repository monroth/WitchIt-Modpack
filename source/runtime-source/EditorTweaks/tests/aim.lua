-- The aim: switching, picking only when the camera moves, blinking by real time, hide and undo.
local dir='candidate/runtime-source/EditorTweaks/'
local frames,now={},0
local R={valid=function(v) return v end,next_frame=function(fn) frames[#frames+1]=fn end}
-- (the runtime's own: a callback's failure is told, not thrown; a valid object or nil)
R.call=R.call or function(fn,...) local ok,v=pcall(fn,...) if ok then return v end;print('[Error] '..tostring(v)) end
R.valid=R.valid or function(v) if v~=nil and (type(v)~='table' or v.IsValid==nil or v:IsValid()) then return v end end
local function frame() local fns=frames;frames={};for _,fn in ipairs(fns) do fn() end end
StaticFindObject=function(path)
    assert(path=='/Script/Engine.Default__GameplayStatics')
    return {GetRealTimeSeconds=function() return now end}
end
local camera={at={X=0,Y=0,Z=0},rot={Pitch=0,Yaw=0}}
camera.GetCameraLocation=function() return camera.at end
camera.GetCameraRotation=function() return camera.rot end
local pc={PlayerCameraManager=camera}
local s={data={hidden={}}}
local actors={}
local function actor(name)
    local a={name=name,bHidden=false,shown={}}
    function a:SetActorHiddenInGame(v) self.bHidden=v;self.shown[#self.shown+1]=v end
    actors['/L.'..name]=a
    return {kind='actor',path='/L.'..name}
end
local rock,tree=actor('Rock'),actor('Tree')
local under,picks=rock,0
local pick={under=function() picks=picks+1;return under end}
local edits,undos={},0
local api={ensure_edit=function() return s,pc end,lookup=function(path) return actors[path] end,
    key=function(row) return row.path end,edit=function(row,hidden) edits[#edits+1]={row=row,hidden=hidden} end,
    undo=function() undos=undos+1 end}
local Objects={label=function(row) return row.path:match('%.(.+)$') end}
-- (the aim's ticks run in WorldKit's loop for the editors, the real one)
R.on=function() end;R.post=function() end;R.log=function(_,f,...) error(string.format(f,...)) end
local WK={};dofile('candidate/runtime-source/WorldKit/objects.lua')(R,{CREATIVE_PC='/Game/Blueprints/Gamemodes/CreativeMode/B_CreativePlayerController.B_CreativePlayerController_C'},WK,dofile('candidate/runtime-source/WorldKit/math.lua'))
R.packages={WorldKit=WK}
local A=dofile(dir..'aim.lua')(R,Objects,api,pick)
local switched,shown=0,{}
A.watch(function() switched=switched+1 end)
A.show(function(text) shown[#shown+1]=text end)

A.toggle()
assert(A.on() and switched==1 and picks==1 and A.label()=='Rock' and shown[#shown]=='Rock')
assert(actors['/L.Rock'].bHidden==true,'the target blinks dark first')
frame();assert(picks==1,'a still camera picks nothing again')
now=.2;frame();assert(actors['/L.Rock'].bHidden==true,'no blink before 350 ms')
now=.36;frame();assert(actors['/L.Rock'].bHidden==false,'blinks back after 350 ms of real time')
camera.rot={Pitch=0,Yaw=10};under=tree;frame()
assert(picks==2 and A.label()=='Tree' and actors['/L.Rock'].bHidden==false,'a moved camera picks again; the old target shows')
now=.8;frame();assert(actors['/L.Tree'].bHidden==true)
A.hide()
assert(edits[1].row==tree and edits[1].hidden==true and actors['/L.Tree'].bHidden==false,'hide takes the target, shown first')
A.undo();assert(undos==1)
A.toggle()
assert(not A.on() and switched==2 and A.label()=='' and #frames<=1)
frame();assert(#frames==0,'off stops ticking')
-- Hide without aim takes what is under the crosshair now.
under=rock;A.hide();assert(edits[2].row==rock)
print('BaseWorldPlus aim passed')
