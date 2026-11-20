local pre, post, queue, restored = {}, {}, {}, {}
local pc={bShowMouseCursor=false,mode='IM_GameOnly',GetAddress=function() return 1 end}
local function widget(id)
    return {GetAddress=function() return id end,SetUserFocus=function() restored[#restored+1]=id end,SetKeyboardFocus=function() end}
end
local original=widget(2)
local session={pc=pc,gi={MenuUIManager={CurrentMenuState=8,MenuStateWidgets={ForEach=function(_,fn) fn({get=function() return 8 end},{get=function() return original end}) end}}},is_creative=true}
local R={pre=function(path,fn) pre[path]=fn end,post=function(path,fn) post[path]=fn end,valid=function(x) return x~=nil end}
function R.next_frame(fn)
    local job={fn=fn}; queue[#queue+1]=job
    return function() job.fn=nil end
end
local function frame()
    local jobs=queue; queue={}
    for _, job in ipairs(jobs) do if job.fn then job.fn() end end
end
local function path(asset,event,folder) return folder..asset..'.'..asset..'_C:'..event end
local umg='/Script/UMG.WidgetBlueprintLibrary:SetInputMode_'
local library={}
function library:SetInputMode_GameOnly(controller,flush)
    assert(flush==false); pre[umg..'GameOnly'](self,controller,flush); controller.mode='IM_GameOnly'
end
function library:SetInputMode_UIOnlyEx(controller,focus,lock,flush)
    assert(flush==false); pre[umg..'UIOnlyEx'](self,controller,focus,lock,flush); controller.mode='IM_UIOnly'
end
function library:SetInputMode_GameAndUIEx(controller,focus,lock,hide,flush)
    assert(flush==false); pre[umg..'GameAndUIEx'](self,controller,focus,lock,hide,flush); controller.mode='IM_GameAndUI'
end
function library:SetFocusToGameViewport() restored[#restored+1]='viewport' end
local I={resets={},managers='/Game/Blueprints/UserInterface/',path=path,id=function(w) return w:GetAddress() end,string=function(t) return t end}
I.object=function(name)
    if name=='/Script/Engine.Default__GameplayStatics' then return {GetGameInstance=function(_,context) assert(context==pc or context==original);return session.gi end} end
    if name:find('Default__WidgetBlueprintLibrary',1,true) then return library end
    if name:find('Default__BpInputSettingsLibrary',1,true) then return {GetInputMode=function() return pc.mode end} end
    return {GetNameByValue=function(_,value) return value end}
end
function original:GetOwningPlayer() return pc end
function R.find_all() return {pc} end
function pc:IsLocalController() return true end
local current,serial
serial=10
function session.gi.MenuUIManager:ShowMessageDialog(title,text)
    serial=serial+1; current=widget(serial)
    library:SetInputMode_UIOnlyEx(pc,current,0,false); pc.bShowMouseCursor=true
end
session.gi.IngameUIManager={TopMostFocusedWidget=original,ShowQuestionDialog=function(_,...)
    assert(select('#',...)==7,'ShowQuestionDialog takes six inputs and its out parameter (NATIVE.md)')
    session.gi.MenuUIManager:ShowMessageDialog()
    -- Native OpenScreen adds the dialog hidden; the caller makes it visible.
    current.visibility=2;function current:SetVisibility(v) self.visibility=v end
    select(7,...).QuestionDialog=current
end}
FText=function(t) return t end
local U={}
dofile('candidate/runtime-source/UIKit/dialogs.lua')(R,{session=function() return {is_creative=true} end},U,I)
local saved=I.snapshot(original)
assert(saved.pc==pc and saved.mode=='IM_GameOnly')
local menu_close=post[path('B_MenuUIManager','CloseDialog',I.managers)]
local screen_close=post[path('B_IngameUIManager','CloseScreen',I.managers)]
U.message('First','Message'); local first=current
U.message('Second','Nested'); local second=current
menu_close({},second)
-- Native work later in the close body must not cancel the completed-return restoration.
library:SetInputMode_GameOnly(pc,false)
frame()
assert(pc.mode=='IM_UIOnly' and restored[#restored]==11,'nested close restores the first dialog')
menu_close({},first); frame()
assert(pc.mode=='IM_GameOnly' and pc.bShowMouseCursor==false and restored[#restored]=='viewport')
local answer
U.question('Question','Continue?',function(value) answer=value end)
assert(current.visibility==0,'The question dialog is made visible')
pre[path('WB_QuestionDialog','OnApply','/Game/UserInterface/Information/')](current)
screen_close({},current)
assert(answer==nil,'answer callback follows native close')
frame(); assert(answer==true and pc.mode=='IM_GameOnly')
-- In a hosted match OpenScreen sets no input mode; the answer still reaches the caller (LIVE10).
local showQuestion=session.gi.IngameUIManager.ShowQuestionDialog
session.gi.IngameUIManager.ShowQuestionDialog=function(_,...)
    serial=serial+1;current=widget(serial);function current:SetVisibility(v) self.visibility=v end
    select(7,...).QuestionDialog=current
end
answer=nil
local asker=widget(99);function asker:GetOwningPlayer() return pc end
library:SetInputMode_UIOnlyEx(pc,asker,0,false)
U.question('Question','Delete?',function(value) answer=value end,asker)
pre[path('WB_QuestionDialog','OnApply','/Game/UserInterface/Information/')](current)
screen_close({},current);frame()
assert(answer==true,'A match question answers without an input-mode change')
assert(restored[#restored]==99,'Focus returns to the asking widget after a match question')
session.gi.IngameUIManager.ShowQuestionDialog=showQuestion
library:SetInputMode_GameOnly(pc,false)
-- Closing a lower dialog first rebases the remaining dialog's return target.
U.message('Lower',''); local lower=current
U.message('Upper',''); local upper=current
menu_close({},lower); frame()
assert(pc.mode=='IM_UIOnly')
menu_close({},upper); frame()
assert(pc.mode=='IM_GameOnly')
-- One input stack with the tool windows (audit B5): a window opened over a dialog keeps the input
-- when the dialog closes under it, and letting the window go gives back what was before both.
U.message('Under',''); local under=current
library:SetInputMode_UIOnlyEx(pc,under,0,false)
local window=I.hold(I.snapshot())
library:SetInputMode_GameAndUIEx(pc,nil,0,false,false)
menu_close({},under); frame()
assert(pc.mode=='IM_GameAndUI','a dialog closing under an open window leaves the window its input')
I.release(window,'now')
assert(pc.mode=='IM_GameOnly','the window let go: the input from before the dialog')
for _, reset in ipairs(I.resets) do reset() end
print('UIKit native dialog close-order checks passed')
