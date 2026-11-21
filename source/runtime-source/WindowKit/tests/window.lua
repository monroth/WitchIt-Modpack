FindAllOf=FindAllOf or function() return {} end   -- (no game borders here: the plain outline)
FName=function(v) return v end
FText=FText or function(t) return t end
-- Compact windows: the corner button where available, opening at the right edge, dragging by
-- holding the left button on the title, closing, and the input mode while a window is open.
local frames,input,wheel,held={},nil,nil,false
local rects={}
local R={log=function() end,codes={LEFT_MOUSE=1,RIGHT_MOUSE=2,SHIFT=16,CTRL=17,ALT=18,ENTER=13,ESCAPE=27,DELETE=46},valid=function(v) if v~=nil and not v.gone then return v end end,
    next_frame=function(fn) frames[#frames+1]=fn;return function() end end,
    native={load_asset=function(path) return path end,on_input=function(fn) input=fn end,
        key_down=function(code) assert(code==1);return held end,
        -- Where each window's box is on screen (none is under the mouse unless a check says so).
        widget_rect=function(w) return rects[w] or {left=-1,top=-1,right=-1,bottom=-1} end,
        intercept=function(path,fn) wheel=fn;return function() wheel=nil end end},
    on=function() end,saves=0}
dofile('candidate/runtime-source/Core/tests/lib/mods.lua')(R)
R.test_owner='WindowKit'
local stored={}

function R.settings(pkg,defaults) stored[pkg]=stored[pkg] or defaults;return stored[pkg] end
function R.save_settings() R.saves=R.saves+1 end
local function frame() local fns=frames;frames={};for _,fn in ipairs(fns) do fn() end end
local function widget(kind)
    local w={kind=kind,children={}}
    function w:SetContent(c) self.content=c end
    function w:AddChild(c) self.children[#self.children+1]=c;return c end
    function w:ClearChildren() self.children={} end
    function w:SetVisibility(v) self.visibility=v end
    function w:AddToViewport(z) self.z=z end
    function w:RemoveFromParent() self.gone=true end
    function w:SetWidthOverride(v) self.width=v end
    function w:SetRenderTransformPivot(v) self.pivot=v end
    function w:SetRenderScale(v) self.scale=v end
    function w:SetRenderTransformAngle(v) self.angle=v end
    function w:SetBrushColor(v) self.colour=v end
    function w:SetPadding() end
    function w:SetStretch(v) self.stretch=v end
    function w:SetUserSpecifiedScale(v) self.user_scale=v end
    function w:SetBrushFromTexture(t) self.texture=t end
    function w:ForceLayoutPrepass() self.measured=true end
    function w:GetDesiredSize() assert(self.measured,'measured before use');return {X=300,Y=self.heightFn and self.heightFn() or 200} end
    function w:SetHeightOverride(v) self.height=v end
    function w:SetMaxDesiredHeight(v) self.max_height=v end
    function w:SetOpacity(v) self.opacity=v end
    function w:SetToolTipText(v) self.tip=v end
    function w:SetColorAndOpacity(v) self.tint=v end
    function w:IsHovered() return self.hovered end
    function w:IsVisible() return true end
    function w:GetParent() return nil end
    function w:SetBackgroundColor(v) self.background=v end
    w.WidgetStyle={}
    function w:AddChildToCanvas(c)
        local slot={child=c}
        function slot:SetAnchors(v) self.anchors=v end
        function slot:SetAlignment(v) self.alignment=v end
        function slot:SetAutoSize() end
        function slot:SetPosition(v) self.position={X=v.X,Y=v.Y} end
        function slot:GetPosition() return self.position end
        function slot:SetOffsets(v) self.offsets=v end
        function slot:SetZOrder(v) self.z=v end
        return slot
    end
    return w
end
local player={bShowMouseCursor=false}
local session={pc=player}
local C={state=function() end,session=function() return session end}
function C.on_session(fn) C.changed=fn end
local mouse={X=0,Y=0}
local clock=0
local modes={}
local objects={
    ['/Script/UMG.Default__WidgetBlueprintLibrary']={
        Create=function() local h=widget('host');h.WidgetTree={RootWidget=widget('canvas'),host=h};return h end,
        SetInputMode_GameAndUIEx=function() modes[#modes+1]='game and ui' end},
    ['/Script/Engine.Default__GameplayStatics']={GetRealTimeSeconds=function() return clock end},
    ['/Script/UMG.Default__WidgetLayoutLibrary']={
        GetMousePositionOnViewport=function() return {X=mouse.X,Y=mouse.Y} end,
        GetViewportSize=function() return {X=1920,Y=1080} end,GetViewportScale=function() return 1 end},
}
StaticConstructObject=function(class,tree) local c=widget(class);c.host=tree and tree.host;return c end
local states={}
local I={object=function(path) return objects[path] or path end,state=function(w) states[w]=states[w] or {};return states[w] end,
    owner=function(p) return states[p.host] end,numbers={},check_fields=function() end,own=function() end,
    forget=function() end,remove=function(w) w.gone=true end,
    native=function(parent,kind)
        local c=widget(kind);c.host=parent.host;parent:AddChild(c)
        local function nop() end
        c.Slot={SetSize=nop,SetVerticalAlignment=nop,SetHorizontalAlignment=nop,SetPadding=nop}
        return c
    end,
    snapshot=function() return {} end,id=function(w) return w end,path=function(a,e) return a..':'..e end,hold=function(s) return s end,release=function() modes[#modes+1]='restored' end}
I.scroll_box=function(parent) return I.native(parent,'ScrollBox') end   -- (UIKit's: a scroll box with the game's bars)
local buttons={}
local U={}
function U.button(parent,o)
    local b=widget('button');b.o=o;b.Slot={SetSize=function() end}
    b.Slot.SetVerticalAlignment=function() end;b.Slot.SetPadding=function() end
    b.MyButton={SetBackgroundColor=function(_,c) b.tint=c end,SetContent=function(_,c) b.content=c end}
    function b:IsHovered() return self.hovered end
    function b:IsVisible() return true end
    function b:GetParent() return nil end
    buttons[o.label]=b
    return b,function(text) b.caption=text end
end
function U.text(_,o) local t=widget('text');t.text=o.text;t.Slot={SetHorizontalAlignment=function() end,SetPadding=function() end};return t end
function U.flow(p) local f=widget('flow');f.host=p.host;return f end
function U.fill(w) return w end
local options
function U.checkbox(_,o) local c=widget('checkbox');c.o=o;return c end
local W={button=U.button,numbers={},check_fields=function() end,ARROW='arrow'}
W.icon=function(parent,o) local b=U.button(parent,{label=o.tooltip});b.lit=o.active;return b end   -- (controls.lua's game icon button)
R.call=R.call or function(f,...) return f(...) end
dofile('candidate/runtime-source/UIKit/mouse.lua')(R,C,U,I)   -- (the mods' one mouse service)
C.CREATIVE_PC='/Game/Blueprints/Gamemodes/CreativeMode/B_CreativePlayerController.B_CreativePlayerController_C'
dofile('candidate/runtime-source/WindowKit/looks.lua')(R,C,U,I,W)   -- (W.bare: the frame's small buttons)
W.tile=function(parent,o) local b=U.button(parent,{label=o.tooltip});b.lit=o.active;return b end   -- (a lit frame button: looks.lua's tile)
W.icons='icons/';R.picture=R.picture or function(f) return {file=f} end
dofile('candidate/runtime-source/WindowKit/window.lua')(R,C,U,I,W)
-- Presses in this test are a second apart unless a check sets the clock.
local raw_input=input
input=function(code) clock=clock+1;held=true;raw_input(code) end
-- Letting go of the button: the next frame sees it.
local function release() held=false;frame() end
-- A press on one of the frame's small buttons (w.parts.*).
local function click(part) part.hovered=true;input(1);part.hovered=false end

local available,builds=true,0
local w=W.window{title='Hide objects',icon='Hide',tint={R=.02,G=.05,B=.045},width=440,
    available=function() return available end,build=function() builds=builds+1 end}
C.changed(session);frame()
local icon=buttons.Hide
assert(icon and icon.tint.G>icon.tint.R and icon.tint.G<1,'the corner button exists where available, in the window colour')
icon.o.on_click()
assert(w.shown() and builds==1 and modes[1]=='game and ui' and player.bShowMouseCursor,'the corner button opens the window, with the mouse')
assert(icon.tint.G>1,'the corner button is lit in the window colour while it is open')
assert(w.slot.anchors.Minimum.X==1 and w.slot.position.X==-16,'a new window stands at the right edge')
-- Drag: the left button pressed with the title under the mouse starts it; the window follows
-- the mouse; letting go of the button stops it.
local title=buttons['Hide objects']
mouse={X=1700,Y=80};input(1);assert(W.carried()~=w,'a press elsewhere moves nothing')
title.hovered=true;input(1)
assert(W.carried()==w and w.slot.anchors.Minimum.X==0,'a press on the title picks the window up')
local start={X=w.slot.position.X,Y=w.slot.position.Y}
mouse={X=1500,Y=300};frame()
assert(w.slot.position.X==start.X-200 and w.slot.position.Y==start.Y+220,'the window follows the mouse')
release()
assert(W.carried()~=w and #frames==0,'letting go puts it down')
mouse={X=0,Y=0};frame();assert(w.slot.position.X==start.X-200,'a put-down window stays')
-- Close: the × button; the input mode comes back; the corner button shows it closed.
click(w.parts.close)
assert(not w.shown() and modes[#modes]=='restored' and icon.tint.G<1)
-- Not available: no corner button, and an open window closes.
icon.o.on_click();local host=w.icon_widget
available=false;C.changed(session);frame()
assert(not w.shown() and host.gone and w.icon_widget==nil,'outside its place the window and its button go')
-- A world that ends drops the frame's queued work: the next session change still places the button.
available=true;C.changed(session);frames={};C.changed(session);frame()
assert(w.icon_widget and not w.icon_widget.gone,'a session change after a dropped frame places the button')
-- The frame's state buttons at the top right: close, lock and anchor; locking or anchoring leaves only the
-- chosen one (lit), the same again gives all three back.
available=true;C.changed(session);frame();buttons.Hide.o.on_click()
assert(w.parts.close and w.parts.lock and w.parts.anchor and not w.locked,'a normal window shows close, lock and anchor')
click(w.parts.lock)
assert(w.locked and not w.anchored and w.pinned=='lock' and w.parts.lock and not w.parts.close and not w.parts.anchor,'locking leaves only the lock')
assert(R.saves>0,'and remembers the place')
local place=stored.UIKit.windows['Hide objects'];assert(place and place.locked and not place.anchored)
w.refresh();assert(not w.parts.close,'a locked window has no close button')
title=buttons['Hide objects'];title.hovered=true;input(1);assert(W.carried()~=w,'a locked window does not move');title.hovered=false
buttons.Hide.o.on_click();assert(not w.shown())
buttons.Hide.o.on_click()
assert(w.slot.position.X==place.x and w.slot.position.Y==place.y and w.slot.anchors.Minimum.X==0 and w.pinned=='lock','it opens where it was locked')
click(w.parts.lock)
assert(not w.locked and w.parts.close and w.parts.lock and w.parts.anchor and stored.UIKit.windows['Hide objects']==nil,'the lock again: all three back, the place forgotten')
click(w.parts.anchor)
assert(w.anchored and w.locked and w.pinned=='anchor' and w.parts.anchor and not w.parts.lock and not w.parts.close,'anchoring leaves only the anchor')
place=stored.UIKit.windows['Hide objects'];assert(place.anchored and place.locked)
w.lock(false);assert(w.anchored,'unlocking does not undo an anchor')
click(w.parts.anchor);assert(not w.locked and not w.anchored and w.parts.close and w.parts.lock,'the anchor again: back to normal')
local none=W.window{title='No anchor',anchor=false,fold_up=false,available=function() return true end,build=function() end}
none.open();assert(not none.parts.anchor and not none.parts.fold_up and none.parts.lock and not none.parts.fold_down and not none.parts.focus,'what a window does not opt into has no button');none.close()
-- The window and its corner button scale through a scale box (pop-ups open in place).
assert(w.slot.child.stretch==7 and w.slot.child.user_scale==.66)
-- A new window does not open over a window placed by hand: it stands to its left.
local other=W.window{title='Second',icon='Two',width=300,scale=1,available=function() return true end,build=function() end}
C.changed(session);frame()
if not w.shown() then w.open() end
w.lock(true)
local lockedLeft=w.slot.position.X                      -- free position: its left edge
buttons.Two.o.on_click();frame()
local otherLeft=1920+other.slot.position.X-300           -- right-anchored offset to its left edge
assert(otherLeft+300<=lockedLeft or otherLeft>=lockedLeft+300,'the new window does not cover the locked one')
w.lock(false)
-- The wheel while the title is held scales this window only; the size is kept for next time.
local scaleBefore=w.scale
title=buttons['Hide objects'];title.hovered=true;input(1)
assert(W.carried()==w and wheel,'the wheel is taken while windows are open')
local spinning={GetInputAnalogKeyState=function(_,key) assert(key.KeyName=='MouseWheelAxis');return 1 end}
assert(wheel(spinning)==true and w.scale>scaleBefore and w.slot.child.user_scale==w.scale,'the wheel scales the window and does not reach the game')
assert(other.scale==1,'other windows keep their size')
release();assert(W.carried()~=w and wheel(spinning)==false,'after letting go the wheel goes to the game')
-- Over a number field the wheel steps it, within its limits.
local field={value=4,hovered=true};function field:IsHovered() return self.hovered end
function field:GetValue() return self.value end;function field:SetValue(v) self.value=v end
-- (the field's own step and range, as the spin box holds them)
function field:GetDelta() return 2 end;function field:GetMinValue() return -1e30 end;function field:GetMaxValue() return 5 end
W.numbers[field]=true
assert(wheel(spinning)==true and field.value==5,'the wheel steps the number under the mouse, up to its max')
field.hovered=false;assert(wheel(spinning)==false and field.value==5,'a number not under the mouse stays');W.numbers[field]=nil
local grown=w.scale
buttons.Hide.o.on_click();buttons.Hide.o.on_click()
assert(w.scale==grown and stored.UIKit.windows['Hide objects'].scale==grown,'it opens at the size it was given')
-- A double click on the title gives the window its own size back and forgets the stored one.
title=buttons['Hide objects']
clock=100;title.hovered=true;input(1);release()
clock=100.2;input(1)
assert(w.scale==.66 and w.slot.child.user_scale==.66 and W.carried()~=w and stored.UIKit.windows['Hide objects']==nil,
    'a double click resets the size')
clock=200;input(1);release();clock=201;input(1);assert(W.carried()==w,'two presses far apart are two drags');release()
-- Sections are plain headed groups now (user 11-21): a heading and a box with a fold arrow, no pulling out.
buttons['Hide objects'].hovered=false
local parts
local tools=W.window{title='Tools',width=300,available=function() return true end,build=function(box)
    parts={box=box,place=W.section(box,{label='Placing'})}
    parts.size=W.section(parts.place,{label='Size'})
end}
tools.open()
local placing=parts.box.children[1].children[1];local head=placing.children[1];local arrow=head.children[1]
assert(placing.children[2]==parts.place and head.kind=='HorizontalBox' and arrow.kind=='Button' and parts.place.children[1].children[1].children[1].children[1].kind=='Button',
    'a section is a head (heading, fold arrow) and a box under it, a section inside it')
-- The fold arrow hides the content and remembers it, locked or not.
arrow.hovered=true;input(1);arrow.hovered=false
assert(parts.place.visibility==1 and stored.UIKit.folded['Tools / Placing'],'the arrow folds the content away')
tools.lock(true);assert(parts.place.visibility==1);tools.lock(false)
arrow.hovered=true;input(1);arrow.hovered=false
assert(parts.place.visibility==0 and stored.UIKit.folded['Tools / Placing']==false,'and back')
-- Holding a heading and moving the mouse pulls nothing out: no pull-out of sections remains.
mouse={X=500,Y=300};head.hovered=true;input(1);head.hovered=false;mouse={X=700,Y=300};frame();release()
assert(stored.UIKit.windows['Tools / Placing']==nil and #W.opened(tools)==0 and tools.apart==nil and W.pull==nil and not W.stays_apart('Tools / Placing'),
    'a heading pulled with the mouse comes out of nothing')
-- Pages pulled out (a tool's tile, a tab): a click on such a control is done on letting go; the mouse
-- moving with the button held brings its page out into a window of its own (remembered apart, kept
-- while locked), which its x puts back.
do
    local tile=widget('button');local clicks,built,backs=0,0,0
    local owner
    local function page(box) built=built+1 end
    local function back() backs=backs+1 end
    owner=W.window{title='Tools3',width=300,fold_down=true,focus=true,available=function() return true end,build=function()
        for _,key in ipairs(W.outs(owner)) do if not W.out(owner,key) then W.pullout(owner,key,'A',page,back).open() end end
    end}
    owner.open()
    W.pullable(tile,function() clicks=clicks+1 end,function(m) W.pull_page(owner,'tile:A','A',page,back,m) end)
    mouse={X=10,Y=10};tile.hovered=true;input(1);tile.hovered=false
    assert(clicks==0,'a press is not yet a click');release()
    assert(clicks==1 and not W.out(owner,'tile:A'),'let go: the click')
    mouse={X=10,Y=10};tile.hovered=true;input(1);tile.hovered=false;mouse={X=100,Y=10};frame()
    local out=W.out(owner,'tile:A')
    assert(out and out.shown() and built==1 and backs==1 and clicks==1,'moved with the button held: its page is out, no click')
    local place=stored.UIKit.windows['Tools3 / out: tile:A']
    assert(place and place.apart and place.x==40 and place.y==-6,'remembered apart, where it came out');release()
    owner.refresh();assert(built==2,'refreshed with its window')
    click(out.parts.close)
    assert(not W.out(owner,'tile:A') and stored.UIKit.windows['Tools3 / out: tile:A']==nil and backs==2,'its x puts it back')
    mouse={X=10,Y=10};tile.hovered=true;input(1);tile.hovered=false;mouse={X=100,Y=10};frame();release()
    owner.close();assert(stored.UIKit.windows['Tools3 / out: tile:A']==nil,'closed, an unfixed page out goes back')
    owner.open();mouse={X=10,Y=10};tile.hovered=true;input(1);tile.hovered=false;mouse={X=100,Y=10};frame();release()
    click(W.out(owner,'tile:A').parts.lock)
    owner.close();assert(stored.UIKit.windows['Tools3 / out: tile:A']==nil and not W.out(owner,'tile:A'),'a locked page is not kept: only an anchored one stays')
    owner.open();mouse={X=10,Y=10};tile.hovered=true;input(1);tile.hovered=false;mouse={X=100,Y=10};frame();release()
    local kept=W.out(owner,'tile:A');click(kept.parts.anchor)
    assert(kept.anchored and stored.UIKit.windows['Tools3 / out: tile:A'].anchored and kept.parts.fold_down and kept.parts.focus,'anchored: remembered; a page of a tool window has the owner\'s frame buttons')
    owner.close()
    assert(not owner.shown() and W.out(owner,'tile:A')==kept and kept.shown() and #W.opened(owner)==1,'an anchored page stays open when its owner closes')
    assert(stored.UIKit.windows['Tools3 / out: tile:A'].apart,'and at its place')
    owner.refresh();assert(built>=3,'a page left out is still built again with the owner\'s refresh')
    owner.open();assert(W.out(owner,'tile:A')==kept and #W.opened(owner)==1,'the owner opening again does not open it twice')
    owner.close();click(kept.parts.anchor);click(kept.parts.close)
    assert(#W.outs(owner)==0 and #W.opened(owner)==0)
end
-- Stacking: locked windows under the others, in the order they were locked; the touched one on top.
local function z(win) return win.layer_slot.z end
local a=W.window{title='A',available=function() return true end,build=function() end}
local b=W.window{title='B',available=function() return true end,build=function() end}
a.open();b.open()
assert(z(b)>z(a),'the newest window is on top')
rects[a.box]={left=0,top=0,right=100,bottom=100};mouse={X=50,Y=50};input(1);release()
assert(z(a)>z(b),'a touched window comes up')
a.lock(true);b.lock(true)
assert(z(a)<z(b) and z(b)<z(tools),'locked windows lie under the others, in the order they were locked')
rects[b.box]={left=0,top=0,right=100,bottom=100};input(1);release()
assert(z(a)<z(b),'touching a locked window changes nothing')
b.lock(false);assert(z(b)>z(tools),'unlocked, it comes on top')
a.lock(false);rects={}
-- The options: one check box in Mods > Options (the section and page pull-out options are gone).
local options=R.option_groups()[1]
assert(options.id=='WindowKit','under the name of the mod that made it')
local boxes=options.build({},U)
assert(#boxes==1 and boxes[1].o.value==false,'by default the windows wear their own look')
boxes[1].o.on_change(true);assert(stored.UIKit.game_look==true);boxes[1].o.on_change(false)
-- Fold (user 11-21): only the title line stays. Up keeps the top edge, down keeps the bottom edge; both work
-- locked or anchored, are remembered with the window's place, and a second click unfolds.
do
    local heads,bodies,foots=0,0,0
    local f=W.window{title='Folds',width=300,scale=1,fold_down=true,available=function() return true end,
        head=function() heads=heads+1 end,build=function() bodies=bodies+1 end,foot=function(bar) foots=foots+1;local _=bar end}
    f.open();f.box.heightFn=function() return f.body.visibility==1 and 40 or 240 end
    assert(f.parts.fold_up and f.parts.fold_down and heads==1 and bodies==1 and foots==1 and f.head and f.foot,'fold up at the top, fold down in the bottom bar, the head and foot built')
    local y0=f.slot.position.Y
    click(f.parts.fold_up)
    assert(f.folded=='up' and f.body.visibility==1 and f.head.visibility==1 and f.foot.visibility==1,'folded up: the body, head and bottom bar are away')
    assert(f.slot.position.Y==y0,'folded up keeps the top edge')
    assert(stored.UIKit.windows['Folds'].fold=='up' and stored.UIKit.windows['Folds'].x==nil,'remembered, with no place of its own')
    click(f.parts.fold_up);assert(not f.folded and f.body.visibility==0 and f.slot.position.Y==y0 and stored.UIKit.windows['Folds']==nil,'a second click unfolds')
    -- down: the bottom edge (y + height) stays
    local bottom=y0+240
    click(f.parts.fold_down)
    assert(f.folded=='down' and f.moved and f.slot.position.Y+40==bottom,'folded down: the title line comes down to where the bottom was')
    local place=stored.UIKit.windows['Folds'];assert(place.fold=='down' and place.y==f.slot.position.Y,'remembered with its place')
    f.close();f.open();f.box.heightFn=function() return f.body.visibility==1 and 40 or 240 end
    assert(f.folded=='down' and f.body.visibility==1 and f.slot.position.Y+40==bottom,'opens folded down where it was')
    click(f.parts.fold_up)
    assert(not f.folded and f.slot.position.Y+240==bottom,'unfolded, the bottom edge is still where it was')
    -- locked and anchored windows fold too
    f.lock(true);f.fold('up');assert(f.folded=='up' and f.locked,'a locked window folds');f.fold('up');f.lock(false)
    f.anchor(true);f.fold('down');assert(f.folded=='down' and f.anchored,'an anchored window folds');f.fold('down');f.anchor(false)
    f.close()
    -- a window without fold_down has no bottom bar
    local g=W.window{title='Grows',available=function() return true end,build=function() end}
    g.open();assert(g.parts.fold_up and not g.parts.fold_down and not g.foot,'no fold down, no bottom bar, unless asked');g.close()
end
-- Focus (user 11-21): a tool window opens focused unless it was left unfocused this session; one lit at a time;
-- again, none; with focus_on_touch a click in the window focuses it.
do
    local log={}
    local function on_focus(on,win) log[#log+1]=win.id..(on and '+' or '-') end
    local t1=W.window{title='T1',focus=true,on_focus=on_focus,available=function() return true end,build=function() end}
    local t2=W.window{title='T2',focus=true,on_focus=on_focus,available=function() return true end,build=function() end}
    local plain=W.window{title='Plain',available=function() return true end,build=function() end}
    t1.open()
    assert(W.focused()==t1 and log[1]=='T1+','a tool window opens focused the first time')
    t2.open();plain.open()
    assert(W.focused()==t2 and log[2]=='T1-' and log[3]=='T2+' and t1.parts.focus and not plain.parts.focus,'the one opened last takes it; only tool windows have the button')
    click(t2.parts.focus);assert(W.focused()==nil and log[4]=='T2-','the lit one again: none is focused')
    click(t1.parts.focus);assert(W.focused()==t1,'a click lights it')
    plain.focus(true);assert(W.focused()==t1,'a window without the option cannot take it')
    t2.close();t2.open();assert(W.focused()==t1,'left unfocused, it opens again unfocused')
    t1.close();assert(W.focused()==nil,'a window closing gives its focus up')
    t1.open();assert(W.focused()==t1,'left focused, it opens again focused')
    t1.close();t2.close();plain.close()
end
-- An anchored window is not closed by its owner closing (general: pages out of a tool window, tested above); a
-- fixed window stacks under the others like a locked one.
print('UIKit compact window passed')
