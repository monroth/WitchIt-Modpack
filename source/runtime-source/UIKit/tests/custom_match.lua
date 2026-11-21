-- Real UIKit/FAP callbacks, in registration order, including nested native mode updates.
local hooks, queue, listeners, settings, saves = {}, {}, {}, {}, 0
local custom='/Game/UserInterface/Play/WB_Custommatch.WB_Custommatch_C:'
local selection='BndEvt__ComboBox_GameMode_K2Node_ComponentBoundEvent_0_OnSelectionChanged__DelegateSignature'
local function emit(path,...)
    if path:sub(-10)==':Construct' then for _,fn in ipairs(hooks['pre:'..path] or {}) do fn(...) end end
    for _,fn in ipairs(hooks[path] or {}) do fn(...) end
end
local function drain()
    while #queue>0 do local pending=queue;queue={};for _,fn in ipairs(pending) do fn() end end
end
local R={log=function() end,native={}}
function R.post(path,fn) hooks[path]=hooks[path] or {};table.insert(hooks[path],fn) end
function R.pre(path,fn) if path:sub(-10)==':Construct' then hooks['pre:'..path]=hooks['pre:'..path] or {};table.insert(hooks['pre:'..path],fn) end end
function R.on() end
function R.find_all() return {} end
function R.valid(value) return value end
function R.next_frame(fn) queue[#queue+1]=fn end
function R.settings(pkg,defaults)
    if not settings[pkg] then settings[pkg]=defaults end
    return settings[pkg]
end
function R.save_settings() saves=saves+1 end
function FText(value) return value end
local serial,states=0,{}
local function node()
    serial=serial+1
    local w={id=serial,children={},Slot={Padding={Left=8,Top=4,Right=8,Bottom=4}},visibility=0}
    function w.Slot:SetPadding(value) self.Padding=value end
    function w:GetAddress() return self.id end
    function w:GetFName() return self.name or tostring(self.id) end
    function w:GetParent() return self.parent end
    function w:GetClass() return {GetFName=function() return {ToString=function() return 'class' end} end} end
    function w:GetChildrenCount() return #self.children end
    function w:GetVisibility() return self.visibility end
    function w:GetAllChildren() return self.children end
    function w:AddChild(child) self.children[#self.children+1]=child;child.parent=self end
    function w:RemoveFromParent()
        for i,child in ipairs(self.parent.children) do if child==self then table.remove(self.parent.children,i);break end end
    end
    w.RenderTransform={Translation={X=0,Y=0}}
    w.Slot=w.Slot or {Padding={Top=0,Bottom=0}}
    function w:ForceLayoutPrepass() end
    function w:GetDesiredSize() return {X=100,Y=40} end
    function w:SetRenderTranslation(value) self.translation=value end
    function w:SetNavigationRuleExplicit() end
    function w:SetVisibility(value) self.visibility=value end
    function w:SetIsEnabled(value) self.enabled=value end
    function w:SetWidthOverride(value) self.width=value end
    function w.Slot:SetHorizontalAlignment() end
    function w.Slot:SetVerticalAlignment() end
    return w
end
local I={play='/Game/UserInterface/Play/',managers='',resets={},destructors={}}
function I.id(w) return w.id end
function I.string(value) return value end
function I.state(w)
    states[w.id]=states[w.id] or {screen=w,menus={},tabs={}}
    return states[w.id]
end
function I.values(values) local out={};for i,v in ipairs(values) do out[i]=v end;return out end
function I.path(asset,event) return asset..':'..event end
function I.move_after(anchor,into,except,with)   -- (as widgets.lua's: the children after anchor, moved to into)
    local parent,after,found=anchor.parent,{},false
    for _,child in ipairs(I.values(parent.children)) do
        if with and child==anchor then found=true end
        if found and child~=except then after[#after+1]={widget=child,slot={padding=child.Slot.Padding}} end
        if child==anchor then found=true end
    end
    for _,moved in ipairs(after) do moved.widget:RemoveFromParent();(into or parent):AddChild(moved.widget) end
    return after
end
function I.slot_values(slot) local p=slot.Padding;return {padding={Left=p.Left,Top=p.Top,Right=p.Right,Bottom=p.Bottom}} end
function I.slot_apply() end
function I.native(parent,kind,name) local w=node();w.name=name;parent:AddChild(w);return w end
local U={}
function U.button(parent,opts) local w=node();parent:AddChild(w);w.opts=opts;return w end
function U.section(parent) local w=node();parent:AddChild(w);return w end
local placed,side
function U.combo(parent,opts) local w=node();parent:AddChild(w);w.opts=opts;side=w;return w,function(v) w.value=v end end
function U.place_after(widget,anchor)
    if anchor.rows then placed=placed or {widget=widget,anchor=anchor} end   -- (the screen's rows: not the menu's buttons)
    local list=anchor.parent.children
    for i,child in ipairs(list) do if child==widget then table.remove(list,i);break end end
    for i,child in ipairs(list) do if child==anchor then table.insert(list,i+1,widget);break end end
end
U.parts=I
U.slider=function(parent,opts) return U.checkbox(parent,opts) end
U.navigate=function(rows)
    for _,widget in ipairs(rows) do
        assert(type(widget)=='table' and widget.GetAddress,'Navigation accepts widgets, never a widget setter')
    end
end
function U.checkbox(parent,opts)
    local w=node();parent:AddChild(w);w.opts=opts;w.InputField=node()
    local function set(value) w.checked=value end
    set(opts.value);return w,set
end
local session={role='offline',is_vanilla_session=true,gi={}}
local C={state=function() end,memory={shown_by=function() end,on=function() return true end,set=function() end,register=function() end,switch=function(_,change) change() end},session=function() return session end,on_session=function(fn) listeners[#listeners+1]=fn end,
    files={read_json=function() return {} end},net={watch=function() end}}
C.mods={on_change=function()end,require=function() end,VANILLA={match={key='VanillaServer',default=true},creative={key='CreativeVanillaServer',default=false}},set_vanilla=function(which,value) C.mods.config[which=='creative' and 'CreativeVanillaServer' or 'VanillaServer']=value;R.save_settings('Core') end,
    config=R.settings('Core',{VanillaServer=true,CreativeVanillaServer=false})}
function C.mods.vanilla() return C.mods.config.VanillaServer==true end
dofile('candidate/runtime-source/UIKit/navigation.lua')(R,C,U,I)
dofile('candidate/runtime-source/UIKit/screens.lua')(R,C,U,I)
local plus={}
function C.chosen_mode(o) return plus[o:GetAddress()] end
function C.choose_mode(o,id,on) if on then plus[o:GetAddress()]=id elseif plus[o:GetAddress()]==id then plus[o:GetAddress()]=nil end end
local S={R=R,C=C,U=U,O='Objective/',MATCH='Match/',F={file='file'},text=I.string,values=I.values,codec={ID='monroth.fap'}}
dofile('candidate/runtime-source/FillAPotPlus/tests/lib/scope.lua')(S)
function S.path(folder,name) return folder..name end
function S.asset(path) return path end
function S.host() return false end
function S.modeChanged() end
dofile('candidate/runtime-source/Core/tests/lib/mods.lua')(R)
R.test_owner='FillAPotPlus'   -- (the mode's name is its mod's)
dofile('candidate/runtime-source/Core/tests/lib/rules.lua')(S.R,S.C)
dofile('candidate/runtime-source/UIKit/rules.lua')(R,C,U,I)
dofile('candidate/runtime-source/FillAPotPlus/rules.lua')(S)
U.menu_entry('WB_Custommatch','Button_Create','Match Rules +',function() end)
local screen=node()
function R.find_all(path) return path==custom:sub(1,-2) and {screen} or {} end
local bar,rows=node(),node()
screen.Button_Create=node();bar:AddChild(screen.Button_Create)
screen.CheckBox_DisableStartTimer=node();rows:AddChild(screen.CheckBox_DisableStartTimer)
screen.ComboBox_TeamChoice=node();rows:AddChild(screen.ComboBox_TeamChoice)
screen.ComboBox_TeamChoice.DescriptiveLabelText={text='Team Choice',GetText=function(self) return self.text end,SetText=function(self,v) self.text=v end}
screen.Slider_RequiredPlayersPerTeam=node();rows:AddChild(screen.Slider_RequiredPlayersPerTeam)
screen.Slider_WitchLives=node();screen.Slider_WitchLives.rows=true;rows:AddChild(screen.Slider_WitchLives)
screen.CheckBox_IdleKick=node();rows:AddChild(screen.CheckBox_IdleKick)
local function gameMode(name) return {GetFName=function() return {ToString=function() return name end} end} end
screen.ComboBox_GameMode={SelectedOption='Fill a Pot (Experimental)',SelectedOptionLabel={SetText=function(self,v) self.text=v end}}
screen.NextMatchOptions={MapData={file='RandomMapCycle'},GetAddress=function() return 1000 end,GameMode=gameMode('B_HideAndSeekGameMode_C')}
for _,method in ipairs({'SetGameModeDefaultValues','UpdateWidgetVisibility','UpdateLayoutComboBox','LoadCustomMatchOptions'}) do
    screen[method]=function(self) emit(custom..method,self) end
end
local made=false
local function check(plus)
    local state=I.state(screen)
    assert(state.vanilla.widget.visibility==0,'The Vanilla row is always there: on Fill a Pot it chooses Fill a Pot+')
    assert(S.selected(screen.NextMatchOptions)==plus,'Fill a Pot+ is Fill a Pot off a vanilla server')
    assert(screen.ComboBox_GameMode.SelectedOptionLabel.text==(plus and 'Fill a Pot+' or 'Fill a Pot (Experimental)'),
        'The list shows Fill a Pot+ by name; the option the game reads stays its own')
    assert(screen.ComboBox_GameMode.SelectedOption=='Fill a Pot (Experimental)')
    -- Fill a Pot+'s own choices in a second column, the game's rows below its Witch lives in the
    -- first; any other mode has the game's rows where they were.
    local team,idle=screen.ComboBox_TeamChoice,screen.CheckBox_IdleKick
    -- (the column is made the first time Fill a Pot+ is chosen on the screen; before, the game's rows as made)
    assert(not made and idle.parent==rows or idle.parent.parent and idle.parent.parent.parent==rows,'The game\'s rows in the first column')
    if plus then made=true;assert(idle.parent.parent.parent==rows,'Fill a Pot+ chosen: its column made') end
    assert(team.parent==rows,'The game\'s Team Choice never moves')
    if plus then
        assert(side.opts.label=='First Round Side' and side.opts.options[1].label=='Random' and side.opts.options[1].value==0 and side.opts.options[2].label=='Choice' and side.opts.options[2].value==1,
            'Off a vanilla server: First Round Side in the second column, the game\'s choices (the game shows no Team Choice in Fill a Pot)')
    end
    assert(state.menus['Fill a Pot+ rules']==nil,'FAP settings belong in the rules tab only')
    assert(state.menus['Match Rules +'].visibility==0,'MR+ remains available')
end
emit(custom..'Construct',screen);drain();check(false)
assert(not placed,'Another mode\'s screen stays as the game made it: nothing of Fill a Pot+ until it is chosen')
local checkbox=I.state(screen).vanilla.widget
screen.NextMatchOptions.GameMode=gameMode('B_ObjectiveGameMode_C');checkbox.opts.on_change(false);drain();check(true)
assert(placed and placed.anchor==screen.Slider_WitchLives,'Fill a Pot+ rows stand where the game\'s Witch Lives stands')
local required
for _,child in ipairs(rows.children) do for _,row in ipairs(child.children) do if row.opts and row.opts.label=='Required Players per Team' then required=row end end end
assert(required and required.opts.min==1 and required.opts.max==3 and required.opts.input_min==0 and required.opts.input_max==8
    and required.opts.tooltip:find('0 to 8',1,true),'Fill a Pot+ Required Players: the slider 1 to 3, typed 0 to 8, told in its tooltip')
required.opts.on_commit(7);assert(screen.NextMatchOptions.RequiredPlayersPerTeam==7,'... into the game\'s own option')
-- (back as it started: the box on, Hide and Seek)
settings.Core.VanillaServer=true;checkbox.checked=true;screen.NextMatchOptions.GameMode=gameMode('B_HideAndSeekGameMode_C');emit(custom..selection,screen);drain()
assert(checkbox.checked and checkbox.enabled and checkbox.opts.default==true,'Fresh preference starts checked')
assert(checkbox.opts.tooltip==nil,'No custom tooltip on the native row')
local function select(mode,plus)
    screen.NextMatchOptions.GameMode=gameMode(mode)
    emit(custom..selection,screen)
    drain();check(plus)
end
select('B_ObjectiveGameMode_C',false);assert(checkbox.checked,'Mode changes cannot change the preference')
checkbox.opts.on_change(false);check(true)
select('B_HideAndSeekGameMode_C',false)
assert(not checkbox.checked and not settings.Core.VanillaServer and saves>0,'Remembered false is preserved')
settings.Core.VanillaServer=true
session.gi.GetAddress=function()return 1 end
session.role='host';session.is_vanilla_session=false
for _,fn in ipairs(listeners) do fn(session) end
assert(not checkbox.enabled and not checkbox.checked,'Hosting paints the locked session policy')
session.is_vanilla_session=true
for _,fn in ipairs(listeners) do fn(session) end
assert(not checkbox.enabled and checkbox.checked)
session.role='offline'
for _,fn in ipairs(listeners) do fn(session) end
assert(checkbox.enabled and checkbox.checked,'Leaving hosting restores the saved preference')
settings.Core.VanillaServer=false
select('B_ObjectiveGameMode_C',true)
emit(custom..'LoadCustomMatchOptions',screen);drain();check(true)
local count=#bar.children
emit(custom..'Construct',screen);drain();check(true)
assert(#bar.children==count and I.state(screen).vanilla.widget==checkbox,'Cached Construct adds no duplicates')
print('PASS shared Custom Match visibility after nested mode updates/load, default/remembered choice, hosting lock, tooltip removal and cached construction')
settings.Core.VanillaServer=true

local creative='/Game/UserInterface/CreativeMode/WB_CreativeGame.WB_CreativeGame_C:Construct'
local dialog=node()
local creative_rows=node()
dialog.CheckBox_Public=node();creative_rows:AddChild(dialog.CheckBox_Public)
session.role='offline'
emit(creative,dialog)
local choice=I.state(dialog).creative_vanilla.widget
assert(choice.parent==creative_rows and choice.opts.label=='Vanilla server','Creative checkbox shares the native option rows')
assert(choice.Slot.Padding==dialog.CheckBox_Public.Slot.Padding,'Creative row uses native row spacing')
assert(not choice.checked and choice.opts.default==false and settings.Core.VanillaServer,'Creative defaults off independently of Custom Match')
choice.opts.on_change(true)
assert(settings.Core.CreativeVanillaServer and settings.Core.VanillaServer,'Creative choice preserves Custom Match')
settings.Core.VanillaServer=false
local before=saves
choice.opts.on_change(false)
assert(not settings.Core.CreativeVanillaServer and not settings.Core.VanillaServer and saves==before+1,'Creative saves only its own preference')
choice.opts.on_change(true)
emit(creative,dialog)
assert(#creative_rows.children==2 and choice.checked,'Reopening cached Creative dialog restores choice without another row')
local another=node();another.CheckBox_Public=node();node():AddChild(another.CheckBox_Public)
emit(creative,another)
assert(I.state(another).creative_vanilla.widget.checked,'New Creative dialog restores the saved choice')
print('PASS Creative native row, separate default and saved preference, cached and new dialog construction')
