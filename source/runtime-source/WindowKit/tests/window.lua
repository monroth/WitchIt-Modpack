FindAllOf=FindAllOf or function() return {} end   -- (no game borders here: the plain outline)
FName=function(v) return v end
-- Compact windows: the corner button where available, opening at the right edge, dragging by
-- holding the left button on the title, closing, and the input mode while a window is open.
local frames,input,wheel,held={},nil,nil,false
local rects={}
local R={codes={LEFT_MOUSE=1,RIGHT_MOUSE=2,SHIFT=16,CTRL=17,ALT=18,ENTER=13,ESCAPE=27,DELETE=46},valid=function(v) if v~=nil and not v.gone then return v end end,
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
    function w:GetDesiredSize() assert(self.measured,'measured before use');return {X=300,Y=200} end
    function w:SetHeightOverride(v) self.height=v end
    function w:SetMaxDesiredHeight(v) self.max_height=v end
    function w:SetOpacity(v) self.opacity=v end
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
local C={session=function() return session end}
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
R.call=R.call or function(f,...) return f(...) end
dofile('candidate/runtime-source/UIKit/mouse.lua')(R,C,U,I)   -- (the mods' one mouse service)
C.CREATIVE_PC='/Game/Blueprints/Gamemodes/CreativeMode/B_CreativePlayerController.B_CreativePlayerController_C'
dofile('candidate/runtime-source/WindowKit/window.lua')(R,C,U,I,W)
-- Presses in this test are a second apart unless a check sets the clock.
local raw_input=input
input=function(code) clock=clock+1;held=true;raw_input(code) end
-- Letting go of the button: the next frame sees it.
local function release() held=false;frame() end

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
buttons['×'].o.on_click()
assert(not w.shown() and modes[#modes]=='restored' and icon.tint.G<1)
-- Not available: no corner button, and an open window closes.
icon.o.on_click();local host=w.icon_widget
available=false;C.changed(session);frame()
assert(not w.shown() and host.gone and w.icon_widget==nil,'outside its place the window and its button go')
-- A world that ends drops the frame's queued work: the next session change still places the button.
available=true;C.changed(session);frames={};C.changed(session);frame()
assert(w.icon_widget and not w.icon_widget.gone,'a session change after a dropped frame places the button')
-- The lock: no ×, no dragging, and the window opens where it was locked.
available=true;C.changed(session);frame();buttons.Hide.o.on_click()
assert(w.lock_button.content.content.opacity<1 and buttons['×'],'an unlocked window has a dim lock and its close button')
local before=#frames
w.lock_button.o.on_click()
assert(w.locked and w.lock_button.content.content.opacity==1 and R.saves>0,'locking lights the lock and remembers the place')
local place=stored.UIKit.windows['Hide objects'];assert(place and place.locked)
buttons['×']=nil;w.refresh();assert(not buttons['×'],'a locked window has no close button')
title=buttons['Hide objects'];title.hovered=true;input(1);assert(W.carried()~=w,'a locked window does not move')
buttons.Hide.o.on_click();assert(not w.shown())
buttons.Hide.o.on_click()
assert(w.slot.position.X==place.x and w.slot.position.Y==place.y and w.slot.anchors.Minimum.X==0,'it opens where it was locked')
w.lock_button.o.on_click();assert(not w.locked and stored.UIKit.windows['Hide objects']==nil,'unlocking forgets the place')
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
-- Sections: a heading pulled out of its window (held, the mouse moved) becomes a window of its
-- own with all under it; it stays apart when the window is built again and when it closes and
-- opens; its × puts it back.
local parts
local tools=W.window{title='Tools',width=300,available=function() return true end,build=function(box)
    parts={box=box,place=W.section(box,{label='Placing'})}
    parts.size=W.section(parts.place,{label='Size'})
end}
tools.open()
local holder=parts.box.children[1];local placing=holder.children[1];local head=placing.children[1]
local heading,arrow=head.children[1],head.children[2]
assert(placing.children[2]==parts.place and heading.kind=='Button' and parts.place.children[1].children[1].children[1].children[1].kind=='Button',
    'a section is a head (heading, fold arrow) and a box under it, a section inside it')
-- The fold arrow hides the content and remembers it; it shows only while the window is unlocked.
arrow.hovered=true;input(1);arrow.hovered=false;release()
assert(parts.place.visibility==1 and stored.UIKit.folded['Tools / Placing'],'the arrow folds the content away')
tools.lock(true);assert(arrow.visibility==1,'a locked window shows no fold arrows')
tools.lock(false);assert(arrow.visibility==0)
arrow.hovered=true;input(1);arrow.hovered=false;release()
assert(parts.place.visibility==0 and not stored.UIKit.folded['Tools / Placing'],'and back')
mouse={X=500,Y=300};heading.hovered=true;input(1);heading.hovered=false
frame();assert(stored.UIKit.windows['Tools / Placing']==nil,'holding the heading still moves nothing')
mouse={X=560,Y=300};frame()
local apart=stored.UIKit.windows['Tools / Placing']
assert(apart and apart.apart and apart.x==500 and apart.y==284,'pulled out: remembered apart, where it came out')
assert(head.visibility==1,'in its own window the head is hidden (the window has its title)')
release()
tools.refresh()
local again=parts.box.children[1].children[1]
assert(again~=placing and again.children[1].visibility==1,'built again, the section goes to its window again')
buttons['×'].o.on_click()
assert(parts.box.children[1].content==again and again.children[1].visibility==0 and stored.UIKit.windows['Tools / Placing']==nil,
    'its × puts it back under its heading and forgets it')
local function heading_of(n) local x=parts.box.children[n].children[1].children[1].children[1];return x end
local function pull_out(heading,x)
    mouse={X=500,Y=300};heading.hovered=true;input(1);heading.hovered=false;mouse={X=x,Y=300};frame();release()
end
-- Unlocked, a section apart goes back when its window closes (the default); locked, it stays.
pull_out(heading_of(1),600)
tools.close();assert(stored.UIKit.windows['Tools / Placing']==nil,'closed: an unlocked section apart goes back')
tools.open();pull_out(heading_of(1),600)
buttons[''].o.on_click()   -- the lock of the section's window, the newest window
tools.close();assert(stored.UIKit.windows['Tools / Placing'].apart,'closing the window keeps its locked sections apart')
tools.open();assert(parts.box.children[1].children[1].children[1].visibility==1,'and opening it brings them out again')
-- A locked window gives no section out.
buttons[''].o.on_click();buttons['×'].o.on_click()   -- unlock the section's window, put the section back
assert(stored.UIKit.windows['Tools / Placing']==nil)
tools.lock(true);pull_out(heading_of(1),700)
assert(stored.UIKit.windows['Tools / Placing']==nil,'a locked window gives no section out')
tools.lock(false)
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
-- The options: two check boxes in Mods > Options.
local options=R.option_groups()[1]
assert(options.id=='WindowKit','under the name of the mod that made it')
local boxes=options.build({},U)
assert(boxes[1].o.value==true and boxes[2].o.value==false,'by default: apart only when locked; not when the window is turned off')
-- With the second on, the corner button only hides a window whose locked sections stay apart.
boxes[2].o.on_change(true)
local tools_icon=W.window{title='Tools2',icon='T2',available=function() return true end,build=function(box)
    parts={box=box,place=W.section(box,{label='Placing'})}
end}
C.changed(session);frame();buttons.T2.o.on_click()
pull_out(heading_of(1),600);buttons[''].o.on_click()
buttons.T2.o.on_click()
assert(tools_icon.state=='hidden' and tools_icon.widget.visibility==1,'the corner button hides it: its sections live on')
buttons.T2.o.on_click();assert(tools_icon.state=='open' and tools_icon.widget.visibility==4,'and shows it again')
boxes[2].o.on_change(false);buttons.T2.o.on_click();assert(not tools_icon.shown(),'without the option it closes')
print('UIKit compact window passed')
