-- Native rebuild/ShowHUD order and host/guest presentation; no text-list widgets.
local hooks,events,watchers={},{},{}
local function hook(path,fn) hooks[path]=hooks[path] or {};table.insert(hooks[path],fn) end
local function fire(path,...) for _,fn in ipairs(hooks[path] or {}) do fn(...) end end
local serial=0
local function node()
    serial=serial+1
    local o={address=serial,children={},SlotPadding={},RenderTransform={},Slot={LayoutData={
        Anchors={Minimum={X=0,Y=0},Maximum={X=0,Y=0}},Alignment={X=0,Y=0},
        Offsets={Left=10,Top=20,Right=40,Bottom=40}}}}
    function o:GetAddress() return self.address end
    function o:AddChild(child)
        if child.parent then child:RemoveFromParent() end
        table.insert(self.children,child);child.parent=self
        return {SetHorizontalAlignment=function() end,SetVerticalAlignment=function() end}
    end
    function o:RemoveFromParent()
        for i,v in ipairs(self.parent.children) do if v==self then table.remove(self.parent.children,i);break end end
        self.parent=nil
    end
    function o:AddChildToUniformGrid(child,row,column)
        local slot=self:AddChild(child);child.row=row;child.column=column;return slot
    end
    function o:GetParent() return self.parent end
    function o:GetAllChildren() return self.children end
    function o:GetChildAt(i) return self.children[i+1] end
    function o:ClearChildren() for _,child in ipairs(self.children) do child.parent=nil end;self.children={} end
    function o:SetRenderScale(v) self.scale=v end
    function o:SetRenderTranslation(v) self.translation=v end
    function o:SetRenderTransformPivot(v) self.pivot=v end
    function o:SetSlotPadding(v) self.padding=v end
    function o:ForceLayoutPrepass() end
    function o:GetDesiredSize() return {X=self.width or 40,Y=self.height or 40} end
    function o:SetMinDesiredSlotWidth(v) self.minWidth=v end
    function o:SetVisibility(v) self.visibility=v end
    function o:SetJustification(v) self.justification=v end
    function o:SetText(v) self.text=v end
    for _,field in ipairs({'Font','ColorAndOpacity','ShadowColorAndOpacity','ShadowOffset'}) do
        o['Set'..field]=function(self,v) self[field]=v end
    end
    o.Slot.SetLayout=function(self,v) self.LayoutData=v end
    o.Slot.SetAutoSize=function(self,v) self.auto=v end
    return o
end
local gs={CurrentRound=1,State=0,CauldronTarget=3,FilledCauldronColors={}}
local mm={CurrentRound=1}
local rules={lives=10,startReady=true,uncapped=true}
local ps={Team=0,Lives=10,ObjectiveTeam=1,IsReady=false,IsReadyObjectiveTeamSelection=false}
local players={ps}
local ui={}
local session={role='host',gs=gs,mode='monroth.fap'}
local published,created={},{}
local S={INFINITE_LIVES=99,HEARTS=5,O='objective/',CORE='core/',ceiling=3,U=setmetatable({},{__index=function() error('text-list HUD must be deleted') end})}
S.R={native={},post=hook,valid=function(v) return v and not v.dead and v end,
    on=function(e,fn) events[e]=events[e] or {};table.insert(events[e],fn) end}
S.C={state=function() end,side=function(ps) local t=ps and ps.Team;return t==0 and "witch" or t==1 and "hunter" or nil end,session=function() return session end,net={
    watch=function(topic,fn) watchers[topic]=watchers[topic] or {};table.insert(watchers[topic],fn) end,
    publish=function(topic,value) published[topic]=value end}}
dofile('candidate/runtime-source/FillAPotPlus/tests/lib/scope.lua')(S)
S.rules=function() return rules end
local required=0
S.required=function() return required end
S.players=function() return players end
S.manager=function() return mm end
S.waiter=function() return false end
S.participant=function() return true end
S.values=function(v) return v end
S.path=function(folder,name,method) return folder..name..(method and ':'..method or '') end
S.new=function(path) local w=node();created[#created+1]={path=path,widget=w};return w end
local replication
S.R.native.on_replication=function(fn) replication=fn end
local bars=0;S.progressBar=function() bars=bars+1 end
FText=function(v) return v end
local layout={GetViewportSize=function() return {X=1920,Y=1080} end,GetViewportScale=function() return 1 end}
StaticFindObject=function(path)
    if path:find('WidgetLayoutLibrary',1,true) then return layout end
    return {GetGameInstance=function() return {IngameUIManager=ui} end}
end
dofile('candidate/runtime-source/FillAPotPlus/hud.lua')(S)
local life=node();life.VerticalBox_0=node()
life.GetOwningPlayer=function() return {PlayerState=ps} end
local top,image,canvas=node(),node(),node()
top.WidgetTree={RootWidget=canvas};canvas:AddChild(image);life.VerticalBox_0:AddChild(top)
local lifePath='/Game/UserInterface/ObjectiveMode/WB_LifeBlock.WB_LifeBlock_C:'
fire(lifePath..'Construct',life)
assert(#created==0,'Construct precedes HUDUserWidget publication')
local health={Font={},ColorAndOpacity={},ShadowColorAndOpacity={},ShadowOffset={}}
ui.HUDUserWidget={HealthBar={Health=health}}
local w=node();w.WidgetTree={};w.CauldronBlock=node();w.WB_CauldronProgress=node();w.WB_LifeBlock=life
local parent=node();parent:AddChild(w.CauldronBlock);ui.HUDUserWidget.ObjectiveHud=w
local objective='/Game/UserInterface/ObjectiveMode/WB_ObjectiveHudExtension.WB_ObjectiveHudExtension_C:'
-- A native WB_CauldronBlock card (PROBE13): CanvasPanel > Overlay > {Border, VerticalBox >
-- {icon row, name TextBlock}}.
local names={}
local function card()
    local block,canvas,overlay,column=node(),node(),node(),node()
    block.WidgetTree={RootWidget=canvas}
    canvas:AddChild(overlay);overlay:AddChild(node());overlay:AddChild(column)
    local icons=node();column:AddChild(icons);icons.Slot.Padding={Left=0,Top=0,Right=0,Bottom=0}
    icons.Slot.SetPadding=function(self,v) self.Padding=v end
    block.icons=icons
    local name=node();column:AddChild(name);names[#names+1]=name
    name.Slot.SetPadding=function(self,v) self.Padding=v end
    return block
end
local function rebuild(count,hud)
    hud=hud or w
    hud.CauldronBlock:ClearChildren()
    for _=1,count do hud.CauldronBlock:AddChild(card()) end
    fire(objective..'RefreshCauldronBlock',hud)
end
rebuild(5)
assert(parent.translation.Y==0 and #created==1)
local counter=created[1].widget
assert(counter:GetParent()==canvas and counter.text=='10' and counter.visibility==4)
assert(counter.Font==health.Font and counter.ShadowOffset==health.ShadowOffset)
assert(counter.Slot.LayoutData.Offsets.Left==-22 and counter.Slot.LayoutData.Offsets.Top==40)
assert(counter.Slot.LayoutData.Alignment.X==.5 and counter.Slot.auto)
rebuild(6);assert(parent.translation.Y==-60 and #w.CauldronBlock.children==6)
rebuild(7);assert(#w.CauldronBlock.children==7)
parent.height=1000;rebuild(10)
local grid=w.CauldronBlock.children[1]
assert(grid.padding.Left==12 and grid.padding.Right==0 and grid.padding.Bottom==10 and parent.pivot.X==1)
-- The first seven cards stay in the right column; the next column grows to the left (user).
assert(grid.children[1].row==0 and grid.children[1].column==1)
assert(grid.children[7].row==6 and grid.children[7].column==1)
assert(grid.children[8].row==0 and grid.children[8].column==0)
assert(parent.scale.Y==.75)
assert(names[#names].Slot.Padding.Left==-37 and names[#names].Slot.Padding.Right==37,'the name is centred under the prop icon (user)')
-- A long name (PROBE17: Cherrywood Wardrobe, 230.7) moves its column's icons left.
local longCard=grid.children[10];names[#names].width=230;longCard.width=230
S.refreshHUD()
assert(names[#names].Slot.Padding.Left==0 and longCard.icons.Slot.Padding.Right==7,'a long name stays centred under the prop icon')
assert(grid.children[9].icons.Slot.Padding.Right==7,'a long name moves its whole column (user)')
assert(grid.children[1].icons.Slot.Padding.Right==0,'the other column stays')
assert(grid.minWidth==242,'columns take the widest card')
names[#names].width=40;longCard.width=nil;S.refreshHUD()
assert(grid.minWidth==242,'a shorter new name never moves the left column (PROBE17)')
-- A replacement HUD (respawn, second half) gets its own columns; the old grid is never read (PROBE13).
local grid1=w.CauldronBlock.children[1];grid1.dead=true;parent.dead=true
local w2=node();w2.WidgetTree={};w2.CauldronBlock=node();w2.WB_CauldronProgress=node();w2.WB_LifeBlock=life
local parent2=node();parent2:AddChild(w2.CauldronBlock);parent2.height=1000
rebuild(10,w2)
assert(#w2.CauldronBlock.children==1 and w2.CauldronBlock.children[1].children[1].column==1,'the replacement HUD is rebuilt into columns')
parent.dead=nil
local built=#created
for _=1,10 do S.refreshHUD() end
assert(#created==built,'ordinary state changes reuse the native tree')
ps.Lives=5;S.refreshHUD();assert(counter.visibility==2)
ps.Lives=7;S.refreshHUD();assert(counter.text=='7' and counter.visibility==4)
rules.lives='infinite';S.refreshHUD();assert(life.visibility==1 and counter.visibility==2)
rules.lives=10;ps.Team=1;S.refreshHUD();assert(life.visibility==1)
ps.Team=0
local status=node();status.BalanceTeamSelection=node()
status.Get_BalanceTeamSelection_Text_0=function() return 'native balance' end
ui.TeamSelectionObjectiveWidget=status
fire('/Game/Blueprints/UserInterface/B_IngameUIManager.B_IngameUIManager_C:ShowTeamSelectionObjective',ui)
assert(status.BalanceTeamSelection.text=='Waiting for ready players')
ps.IsReady=true;S.refreshHUD();assert(status.BalanceTeamSelection.text=='Starting match')
-- The merged readiness option permits an empty team and checks every player.
gs.CurrentRound=0;mm.CurrentRound=0;ps.ObjectiveTeam=0
ps.IsReadyObjectiveTeamSelection=true
S.refreshHUD();assert(status.BalanceTeamSelection.text=='Starting match')
S.waiter=function() return true end;S.participant=function() return false end
ps.IsReadyObjectiveTeamSelection=false
S.refreshHUD();assert(status.BalanceTeamSelection.text=='Waiting for players')
S.waiter=function() return false end;S.participant=function() return true end
rules.startReady=false;ps.ObjectiveTeam=1;required=1
S.refreshHUD();assert(status.BalanceTeamSelection.text=='Waiting for a player on each team')
rules.startReady=true;gs.CurrentRound=1;mm.CurrentRound=1
gs.State=2;S.refreshHUD();assert(status.BalanceTeamSelection.text=='')
rules.startReady=false;rules.uncapped=false;S.refreshHUD();assert(status.BalanceTeamSelection.text=='native balance')
gs.CurrentRound=2;mm.CurrentRound=2;gs.CauldronTarget=2;S.ceiling=nil
S.refreshHUD();S.refreshHUD()
assert(S.hudPolicy().ceiling==3,'second-half ceiling survives repeated events')
-- A filled cauldron sends the host's HUD message again, with the colours in fill order.
gs.FilledCauldronColors={{R=1,G=0,B=0}};S.refreshHUD()
assert(#published['fap.hud'].filled==1 and published['fap.hud'].filled[1].R==1,'a fill reaches guests')
gs.FilledCauldronColors={{R=1,G=0,B=0},{R=0,G=0,B=1}};S.refreshHUD()
assert(#published['fap.hud'].filled==2 and published['fap.hud'].filled[2].B==1)
gs.CurrentRound=1;mm.CurrentRound=1
session.role='client'
local function message(topic,value) for _,fn in ipairs(watchers[topic]) do fn(value) end end
session.role='client'
message('fap.hud',{round=1,infinite=true,ceiling=3,reason='Waiting for players'})
assert(life.visibility==1 and status.BalanceTeamSelection.text=='Waiting for players')
-- Host metadata can precede activation; the session's change to the mode (events.lua) then
-- paints the retained HUD.
session.mode='vanilla';message('fap.hud',{round=1,infinite=false,ceiling=3,reason='Starting match'})
session.mode='monroth.fap';S.refreshHUD()
assert(life.visibility==0 and status.BalanceTeamSelection.text=='Starting match')
-- A guest can show its native lobby before the activation snapshot arrives.
session.mode='vanilla'
local coldStatus=node();coldStatus.BalanceTeamSelection=node()
coldStatus.Get_BalanceTeamSelection_Text_0=function() return 'native balance' end
ui.TeamSelectionObjectiveWidget=coldStatus
fire('/Game/Blueprints/UserInterface/B_IngameUIManager.B_IngameUIManager_C:ShowTeamSelectionObjective',ui)
assert(coldStatus.BalanceTeamSelection.text==nil,'inactive Plus never paints native UI')
message('fap.hud',{round=1,infinite=false,ceiling=3,reason='Waiting for ready players'})
assert(coldStatus.BalanceTeamSelection.text==nil)
session.mode='monroth.fap';S.refreshHUD()
assert(coldStatus.BalanceTeamSelection.text=='Waiting for ready players')
local previous=bars;session.mode='vanilla';S.refreshHUD();assert(bars==previous)
session.mode='creative';S.refreshHUD();assert(bars==previous)
session.mode='monroth.fap'
for _,fn in ipairs(events.world_end) do fn() end
assert(S.hudPolicy()==nil)
print('PASS old native cards, 5/6/7/10 pots, seven-row overflow, DPI fit, heart counter, status and guest facts')
