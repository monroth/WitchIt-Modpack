local post, pre, queue, serial = {}, {}, {}, 100
local live={}
local R={log=function() end,post=function(path,fn) post[path]=fn end,pre=function(path,fn) pre[path]=fn end,
    valid=function(x) return x~=nil end,find_all=function(path) return live[path] or {} end}
dofile('candidate/runtime-source/Core/tests/lib/mods.lua')(R)
R.next_frame=function(fn) local item={fn=fn};queue[#queue+1]=item;return function()item.fn=nil end end
local function drain()
    local work=queue;queue={}
    for _,item in ipairs(work) do if type(item)=='function' then item() elseif item.fn then item.fn() end end
end
local function array(items)
    items.ForEach=function(self,fn) for i,value in ipairs(self) do fn({get=function() return i end},{get=function() return value end}) end end
    return items
end
local function node(id)
    local self={id=id,children=array({})}
    function self:GetAddress() return self.id end
    function self:GetFName() return self.name or tostring(self.id) end
    function self:GetParent() return self.parent end
    function self:GetAllChildren() return self.children end
    function self:AddChild(child) self.children[#self.children+1]=child; child.parent=self end
    function self:SetIsEnabled(value) self.enabled=value end
    function self:RemoveFromParent()
        for i,child in ipairs(self.parent.children) do if child.id==self.id then table.remove(self.parent.children,i); break end end
    end
    function self:GetClass() return 'class' end
    function self:GetVisibility() return self.visibility or 0 end
    function self:SetVisibility(value) self.visibility=value end
    self.RenderTransform={Translation={X=0,Y=0}}
    self.Slot={Padding={Left=0,Top=0,Right=0,Bottom=0},SetPadding=function(slot,value) slot.Padding=value end}
    function self:ForceLayoutPrepass() end
    function self:GetDesiredSize() return {X=100,Y=40} end
    function self:GetCachedGeometry() return {size={X=100,Y=self.allocated or 40}} end
    function self:SetRenderTranslation(value) self.translation=value end
    function self:SetNavigationRuleExplicit() end
    function self:HasFocusedDescendants() return false end
    function self:GetOwningPlayer() return {} end
    return self
end
local states={}
local session
local function state(screen)
    if not states[screen.id] then states[screen.id]={screen=screen,actions={},menus={},tabs={}} end
    return states[screen.id]
end
local I={resets={},destructors={},play='/Game/UserInterface/Play/',managers='/Game/Blueprints/UserInterface/',screens=states,
    id=function(w) return w:GetAddress() end,state=state,string=function(x) return x end,object=function(path) return path end,
    values=function(items) local copy={}; for i,v in ipairs(items) do copy[i]=v end; return copy end,
    array=function(target,values) for i=#target,1,-1 do target[i]=nil end; for i,v in ipairs(values) do target[i]=v end end,
    path=function(asset,event,folder) return (folder or '/Game/UserInterface/UIElements/')..asset..'.'..asset..'_C:'..event end,
    slot_values=function(slot) local p=slot.Padding;return {padding={Left=p.Left,Top=p.Top,Right=p.Right,Bottom=p.Bottom}} end,
    slot_apply=function(slot,value) slot:SetPadding(value.padding) end,
    initial=function(parent) return parent.children[1] end,focus=function(widget) widget.focused=true end,snapshot=function(origin)
        return {pc=origin and origin:GetOwningPlayer() or session.pc,gi=session.gi}
    end,
    restore_after_close=function(saved) queue[#queue+1]=function() assert(saved.pc==session.pc) end end}
local function child(parent) serial=serial+1; local widget=node(serial); parent:AddChild(widget); return widget end
I.native=function(parent,kind,name) local widget=child(parent);widget.name=name;return widget end
I.caption=function(widget,value) widget.LabelText=value end
I.menu_screen=function(manager,state)   -- (as widgets.lua's)
    local screen;manager.MenuStateWidgets:ForEach(function(k,v) if k:get()==state then screen=v:get() end end);return screen and R.valid(screen) and screen or nil
end
local U={scroll=child,section=child,button=function(parent,opts) local widget=child(parent);widget.click=opts.on_click; return widget end}
function U.place_after(widget,anchor)   -- (as widgets.lua's: the widget right after its anchor)
    local list=anchor.parent.children
    for i,c in ipairs(list) do if c==widget then table.remove(list,i);break end end
    for i,c in ipairs(list) do if c==anchor then table.insert(list,i+1,widget);break end end
end
local rules=I.play..'GameRules/WB_GameRulesTabs.WB_GameRulesTabs_C'
local screen=node(1); screen.RulesSwitcher=node(2); screen.Buttons=array({node(3)}); screen.RuleTabs=array({node(4)})
local bar=node(5); bar:AddChild(screen.Buttons[1]); screen.TabButton_Mods=screen.Buttons[1]
function screen:UpdateTabButtonStyles() self.styles=(self.styles or 0)+1 end
function screen:SetActiveTab(page) self.RulesSwitcher.active=page end
function screen.RulesSwitcher:GetActiveWidget() return self.active end
local manager={CurrentMenuState=9,MenuStateWidgets=array({}),MenuStateClasses={}}
function manager.MenuStateClasses:ForEach(fn)
    fn({get=function() return 30 end},{get=function() return {GetFName=function() return 'WB_GameRulesTabs_C' end,GetFullName=function() return rules end} end})
end
session={gi={MenuUIManager=manager,IngameUIManager={OpenSubordinateMenu=function(_,flag) assert(flag==true) end}},pc={IsA=function() return false end}}
dofile('candidate/runtime-source/UIKit/navigation.lua')(R,{state=function() end,session=function() error('widget navigation must not read session facts') end},U,I)
function screen:GetOwningPlayer() return session.pc end
local object=I.object
I.object=function(path)
    if path=='/Script/UMG.Default__SlateBlueprintLibrary' then return {GetLocalSize=function(_,geometry)return geometry.size end} end
    if path=='/Script/Engine.Default__GameplayStatics' then return {GetGameInstance=function(_,context) assert(context==screen);return session.gi end} end
    return object(path)
end
local built=0
local first=U.rules_tab('first',function(parent) built=built+1; child(parent) end)
U.rules_tab('second',function(parent) built=built+1; child(parent) end)
local insideChange=false
function manager:ChangeMenu(target)
    assert(not insideChange,'Menu construction must not reenter a ChangeMenu hook')
    insideChange=true
    if pre[I.path('B_MenuUIManager','ChangeMenu',I.managers)](self,target) then
        insideChange=false;return
    end
    -- Construct occurs before CurrentMenuState and the cache become usable.
    post[rules..':Construct'](screen)
    self.CurrentMenuState=target
    self.MenuStateWidgets={ForEach=function(_,fn) fn({get=function() return 30 end},{get=function() return screen end}) end}
    post[I.path('B_MenuUIManager','ChangeMenu',I.managers)](self)
    insideChange=false
end
U.open_rules(screen,first)
assert(built==0 and manager.CurrentMenuState==9,'Opening rules waits for the next frame')
drain()
assert(built==2 and #screen.Buttons==3 and #screen.RuleTabs==3)
assert(screen.RulesSwitcher.active==states[1].tabs[first].page)
assert(states[1].tabs[first].rows.children[1].focused,'The explicit rules destination owns focus after the native menu transition completes')
post[rules..':Construct'](setmetatable({id=1},{__index=screen}))
assert(built==2,'cached Construct through a new wrapper must not duplicate tabs')
local focused
post[rules..':GetInitialFocusWidget'](screen,{set=function(_,widget) focused=widget end})
assert(focused==states[1].tabs[first].rows.children[1])
local closed=0
function session.gi.IngameUIManager:CloseSubordinateMenu() closed=closed+1 end
manager:ChangeMenu(99) -- Guest native Back chooses Custom Match, not the originating lobby.
assert(manager.CurrentMenuState==30 and closed==0,'Consume the native request before constructing the wrong destination')
drain()
assert(manager.CurrentMenuState==9 and closed==1,'The next frame returns to the origin and closes the owned subordinate menu')
assert(#queue==1,'Input restores after the completed close')
drain()
U.open_rules(screen,first);drain()
manager:ChangeMenu(9) -- Creative Back already names the original menu, but still needs close/input restoration.
assert(manager.CurrentMenuState==9 and closed==1,'Native Back must complete directly without a Lua-issued second transition')
assert(#queue==1,'Same-destination Back restores input after native cleanup, without queuing another ChangeMenu')
drain()
local menu=node(40); menu.Settings=node(41); local column=node(42); column:AddChild(menu.Settings); column:AddChild(node(43))
column.children[2].Slot.Padding={Left=1,Top=2,Right=3,Bottom=4}
local function opened(path,x) pre[path..':Construct'](x);return post[path..':Construct'](x) end
U.menu_entry('WB_MainMenu','Settings','Mods',function() end)
local function construct(x) pre['/Game/UserInterface/WB_MainMenu.WB_MainMenu_C:Construct'](x);post['/Game/UserInterface/WB_MainMenu.WB_MainMenu_C:Construct'](x) end
construct(menu); construct(setmetatable({id=40},{__index=menu}))
local row=column.children[2];local button=states[40].menus.Mods
assert(#column.children==3 and row.children[1]==button and column.children[1]==menu.Settings and column.children[3].id==43,
    'the row stands right under its anchor; the native rows follow it')
assert(column.children[3].Slot.Padding.Bottom==4 and column.children[3].Slot.Padding.Left==1,'a moved native row keeps its slot values')
assert(not row.translation and not button.translation,'nothing is moved by a render offset')
local pause=node(50);pause.Settings=node(51);local pauseColumn=node(52)
pauseColumn:AddChild(pause.Settings)
local collapsed=node(53);collapsed.visibility=1;pauseColumn:AddChild(collapsed)
local resume=node(54);pauseColumn:AddChild(resume)
U.menu_entry('/Game/UserInterface/WB_IngameMenu.WB_IngameMenu_C','Settings','Match Rules +',function()end)
opened('/Game/UserInterface/WB_IngameMenu.WB_IngameMenu_C',pause)
assert(pauseColumn.children[2].children[1]==states[50].menus['Match Rules +'] and pauseColumn.children[3]==collapsed and pauseColumn.children[4]==resume,
    'collapsed native rows keep their place after the row; the game shows them where they belong')
local creative=node(60);creative.Settings=node(61);local creativeColumn=node(62)
creativeColumn:AddChild(creative.Settings)
creative.LayoutEditor=node(63);creative.LayoutEditor.visibility=2;creativeColumn:AddChild(creative.LayoutEditor)
U.menu_entry('/Game/UserInterface/CreativeMode/WB_CreativeIngameMenu.WB_CreativeIngameMenu_C','Settings','Match Rules +',function()end,'LayoutEditor')
opened('/Game/UserInterface/CreativeMode/WB_CreativeIngameMenu.WB_CreativeIngameMenu_C',creative)
assert(creative.LayoutEditor.visibility==1,'the row takes the hidden caption\'s blank space (PROBE16)')
creative.LayoutEditor.visibility=0
post['/Game/UserInterface/CreativeMode/WB_CreativeIngameMenu.WB_CreativeIngameMenu_C:GetInitialFocusWidget'](creative)
assert(creative.LayoutEditor.visibility==0,'a caption the game shows stays shown')
local absent=node(64);absent.Settings=node(65);local absentColumn=node(66);absentColumn:AddChild(absent.Settings)
U.menu_entry('/Game/UserInterface/WB_Test.WB_Test_C','Settings','Host only',function()end,nil,function() return false end)
opened('/Game/UserInterface/WB_Test.WB_Test_C',absent)
assert(#absentColumn.children==1,'a session without the row never adds it')
local toggled=false
local timer=node(67);timer.Settings=node(68);local timerColumn=node(69);timerColumn:AddChild(timer.Settings)
U.menu_entry('/Game/UserInterface/WB_Timer.WB_Timer_C','Settings','Pause',function() toggled=not toggled end,nil,nil,function() return toggled and 'Resume' or 'Pause' end)
opened('/Game/UserInterface/WB_Timer.WB_Timer_C',timer)
local timerButton=I.state(timer).menus['Pause']
timerButton.click(timerButton)
assert(toggled and timerButton.LabelText=='Resume','the row shows its current state')

for _,cleanup in ipairs(I.destructors) do cleanup(states[1]) end
states[1]=nil;post[rules..':Construct'](screen)
assert(#screen.Buttons==3 and #screen.RuleTabs==3 and built==4,'cached reconstruction must restore native tab arrays before adding ours')
I.change_menu(manager,9)
for _, reset in ipairs(I.resets) do reset() end
manager.CurrentMenuState=99;drain();assert(manager.CurrentMenuState==99,'travel cancels unfinished navigation')
-- (user 11-05) More tabs than the row holds: seven show, two arrows move the window.
for i=3,8 do U.rules_tab('more'..i,function(parent) child(parent) end) end
post[rules..':Construct'](screen)
assert(#screen.Buttons==9,'nine tabs')
local arrows=I.state(screen).tab_arrows
assert(arrows and #arrows==2,'arrows appear past seven tabs')
local function shown() local n=0;for _,b in ipairs(screen.Buttons) do if b.visibility==0 then n=n+1 end end;return n end
assert(shown()==7 and screen.Buttons[1].visibility==0 and screen.Buttons[9].visibility==1,'the first seven show')
arrows[2].click();arrows[2].click();arrows[2].click()
assert(shown()==7 and screen.Buttons[1].visibility==1 and screen.Buttons[9].visibility==0,'> moves to the last ones, not past them')
arrows[1].click();assert(screen.Buttons[2].visibility==0 and screen.Buttons[9].visibility==1,'< moves back')
print('UIKit cached-menu and shared-tab engine-order checks passed')
