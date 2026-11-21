-- The hide window: what each list holds and what each control does.
local dir='candidate/runtime-source/EditorTweaks/'
local session={role='host',mode='creative',is_playtest=false}
local C={owns=function(s) return (s or session).role~='client' end,guest=function(s) return (s or session).role=='client' end,session=function() return session end}
-- A U double that records the controls a build makes.
local built,opts
local function control(kind,o) built[#built+1]={kind=kind,o=o};return built[#built],function() end end
local U={
    window=function(o) opts=o;return {refresh=function() opts.refreshes=(opts.refreshes or 0)+1 end} end,
    flow=function() return {} end,fill=function(w) return w end,scroll=function() return {} end,
    text=function(_,o) return control('text',o) end,button=function(_,o) return control('button',o) end,
    checkbox=function(_,o) return control('checkbox',o) end,
}
local function find(kind,label)
    for _,c in ipairs(built) do if c.kind==kind and (c.o.label==label or c.o.text==label) then return c.o end end
end
local rows={}
local function row(name) rows[name]={path='/L.'..name};return rows[name] end
local s={data={hidden={}}}
local edits,groups={},{}
local listeners={}
local api={ensure_edit=function() return s end,key=function(r) return r.path end,
    edit=function(r,hidden) edits[#edits+1]={r=r,hidden=hidden} end,
    edit_group=function(rs,hidden) groups[#groups+1]={rs=rs,hidden=hidden} end,
    inventory=function() return {rows.Rock,rows.Lamp} end,
    on_change=function(fn) listeners[#listeners+1]=fn end}
local aim={on=false,released=0}
local A={on=function() return aim.on end,label=function() return '' end,toggle=function() aim.on=not aim.on end,
    hide=function() aim.hid=true end,undo=function() aim.undid=true end,release=function() aim.released=aim.released+1 end,
    watch=function(fn) aim.watch=fn end,show=function(set) aim.shown=set end}
local Objects={label=function(r) return r.path:match('%.(.+)$') end}
row('Rock');row('Lamp');row('Wood')
s.data.hidden['/L.Wood']=rows.Wood
dofile(dir..'hide_window.lua')(U,C,Objects,api,A)
built={};opts.build({},{refresh=function() end})

assert(find('checkbox','Aim') and find('button','Hide').on_click==A.hide and find('button','Undo').on_click==A.undo)
assert(find('text','Nearby').heading and find('text','Hidden: 1').heading)
-- Nearby lists what is not hidden, each with Hide; Hidden lists each hidden row with Show.
local hides,shows={},{}
for _,c in ipairs(built) do
    if c.kind=='button' and c.o.label=='Hide' and c.o.on_click~=A.hide then hides[#hides+1]=c.o end
    if c.kind=='button' and c.o.label=='Show' then shows[#shows+1]=c.o end
end
assert(#hides==2 and #shows==1)
hides[1].on_click();assert(edits[1].r==rows.Rock and edits[1].hidden==true and aim.released==1)
shows[1].on_click();assert(edits[2].r==rows.Wood and edits[2].hidden==false)
local all=find('button','Show all');assert(all.enabled==true)
all.on_click();assert(groups[1].rs[1]==rows.Wood and groups[1].hidden==false,'Show all is one group, one undo step')
find('checkbox','Aim').on_change(true);assert(aim.on==true)
assert(aim.shown~=nil,'the aimed name goes to the window while it is built')
opts.on_close();assert(aim.shown==nil,'a closed window shows no aimed name')
-- A change of the hidden set and a switch of the aim rebuild the window.
listeners[1]();aim.watch();assert(opts.refreshes==2)
-- Only for a Creative host outside Playtest.
assert(opts.available());session.role='client';assert(not opts.available())
session.role='host';session.is_playtest=true;assert(not opts.available())
print('BaseWorldPlus hide window passed')
