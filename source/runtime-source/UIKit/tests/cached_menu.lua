-- Real package world_end and widget ownership, with MenuUIManager's cached screens.
local original_dofile=dofile
local hooks,events,I={},{},nil
local R={native={on_save=function()end,on_input=function()end,load_asset=function(path)return path end}}
local V=dofile('candidate/runtime-source/WitchItRuntime/Scripts/values.lua');R.values,R.text=V.values,V.text
function R.post(path,fn) hooks[path]=hooks[path] or {};table.insert(hooks[path],fn) end
function R.pre(path,fn) hooks['pre:'..path]=hooks['pre:'..path] or {};table.insert(hooks['pre:'..path],fn) end
function R.on(event,fn)events[event]=fn end
function R.find_all()return {}end
function R.valid(value)return value~=nil end
local function emit(path,...)
    for _,fn in ipairs(hooks['pre:'..path] or {}) do fn(...) end
    for _,fn in ipairs(hooks[path] or {}) do fn(...) end
end
local serial=0
local function node(kind,name,outer)
    serial=serial+1
    local w={id=serial,kind=kind,name=name or tostring(serial),outer=outer,children={},nav={}}
    function w.children:ForEach(fn)
        for index,child in ipairs(self)do
            fn({get=function()return index end},{get=function()return child end})
        end
    end
    function w:GetAddress()return self.id end
    function w:GetFName()return self.name end
    function w:GetClass()return {GetFName=function()return self.kind end}end
    function w:IsA(class)return class=='/Script/UMG.UserWidget' and self.kind=='screen' end
    function w:GetOuter()return self.outer end
    function w:GetParent()return self.parent end
    function w:GetAllChildren()return self.children end
    function w:GetChildAt(index)return self.children[index+1]end
    function w:AddChild(child)
        assert(not child.parent,'Cached rows must keep their native slots attached')
        self.children[#self.children+1]=child;child.parent=self
        child.Slot={Padding={Left=7,Top=3,Right=9,Bottom=5},Size={Value=1,SizeRule=0},IsA=function() return true end}
        function child.Slot:SetPadding(value)self.Padding=value end
        function child.Slot:SetSize(value)self.Size=value end
        function child.Slot:SetHorizontalAlignment()end
        function child.Slot:SetVerticalAlignment()end
    end
    function w:RemoveFromParent()
        for i,child in ipairs(self.parent.children)do
            if child==self then table.remove(self.parent.children,i);break end
        end
        self.parent=nil
    end
    function w:GetOwningPlayer()return {}end
    function w:GetVisibility()return self.visibility or 0 end
    function w:ForceLayoutPrepass()end
    function w:GetDesiredSize()return {X=100,Y=40}end
    function w:SetRenderTranslation(value)self.translation=value end
    function w:SetNavigationRuleExplicit(direction,target)self.nav[direction]=target end
    function w:SetAutoWrapText()end
    function w:SetText(value)self.text=value end
    return w
end
FName=function(value)return value end
FText=function(value)return value end
StaticConstructObject=function(kind,outer,name)return node(kind,name,outer)end
StaticFindObject=function(path)
    if path=='/Script/UMG.Default__WidgetBlueprintLibrary' then
        return {Create=function(_,screen)
            local button=node('WB_Button_C',nil,screen)
            button.Label=node('text');button.ButtonRef=node('button')
            return button
        end}
    end
    return path
end
-- Load real package, widgets and navigation; unrelated views need no engine model.
dofile=function(path)
    if path:match('/widgets.lua$') or path:match('/actions.lua$') or path:match('/navigation.lua$') then return original_dofile(path) end
    return function(_,_,_,internals)I=internals end
end
local U=original_dofile('candidate/runtime-source/UIKit/package.lua')(R,{on_session=function()end})
dofile=original_dofile
local cases={
    {'/Game/UserInterface/Play/WB_Custommatch.WB_Custommatch_C','Button_Create','Match Rules\u{A0}+',false},
    {'/Game/UserInterface/WB_IngameMenu.WB_IngameMenu_C','Settings','Match Rules\u{A0}+',true},
    {'/Game/UserInterface/CreativeMode/WB_CreativeIngameMenu.WB_CreativeIngameMenu_C','Settings','Match Rules\u{A0}+',true},
    {'/Game/UserInterface/WB_MainMenu.WB_MainMenu_C','Settings','Mods',true},
}
local clicked
for _,case in ipairs(cases)do
    local screen=node('screen');screen.WidgetTree={IsA=function() return false end,GetOuter=function() return screen end}   -- (as the game's: its outer is the screen)
    local parent=node('panel',nil,screen)
    if not case[4] then
        case.back=node('native',nil,screen);case.back.Text='Back';parent:AddChild(case.back)
        case.rules=node('native',nil,screen);case.rules.Text='Game Rules';parent:AddChild(case.rules)
    end
    local anchor=node('WB_Button_C',nil,screen);parent:AddChild(anchor)
    screen[case[2]]=anchor
    if case[4] then parent:AddChild(node('native',nil,screen)) end
    case.screen,case.parent=screen,parent
    case.native_count=#parent.children
    U.menu_entry(case[1],case[2],case[3],function(origin)clicked=origin end)
    emit(case[1]..':Construct',screen)
    for index,child in ipairs(parent.children) do if child==anchor then case.anchorIndex=index end end
    case.row=parent.children[case.anchorIndex+1];case.button=case.row:GetChildAt(0)
    case.slot=case.row.Slot
end
for cycle=1,3 do
    events.world_end()
    assert(next(I.screens)~=nil,'Cached menu screens keep their UIKit state across world teardown')
    for _,case in ipairs(cases)do
        local screen,parent=case.screen,case.parent
        local wrapper=setmetatable({},{__index=screen})
        emit(case[1]..':Construct',wrapper)
        emit(case[1]..':Construct',wrapper)
        assert(#parent.children==case.native_count+1,'Cached Construct after world_end must reuse the sole menu row')
        assert(parent.children[case.anchorIndex+1]==case.row and case.row.Slot==case.slot,
            'Reuse preserves the row right under its anchor, with its slot')
        assert(I.state(wrapper).menus[case[3]]==case.button,'Lua state rediscovers the same native button')
        if case.rules then
            assert(parent.children[1]==case.back and parent.children[2]==case.rules and parent.children[3]==screen.Button_Create,
                'Custom Match keeps Back, native Game Rules and Create Game before the single Match Rules + entry')
            assert(case.rules.Text=='Game Rules','The native Game Rules button keeps its own caption')
        end
        assert(case.screen[case[2]].Slot.Padding.Bottom==5,'The anchor keeps its own padding')
        assert(case.screen[case[2]].nav[3]==case.button and case.button.ButtonRef.nav[2]==case.screen[case[2]],
            'Reused button retains explicit navigation including its inner control')
        clicked=nil
        emit(I.path('WB_BaseControl','ButtonClicked'),case.button)
        assert(clicked==case.button,'Reused button has a current action and reports itself as the origin')
    end
end
for _,case in ipairs(cases)do
    emit('/Script/UMG.UserWidget:Destruct',case.screen)
    assert(#case.parent.children==case.native_count,'Live Destruct removes the rediscovered owned row')
    assert(case.screen[case[2]].Slot.Padding.Bottom==5,'Live Destruct restores original nonzero padding')
    assert(I.actions[case.button.id]==nil,'Live Destruct releases the rediscovered click action')
    emit(case[1]..':Construct',case.screen)
    assert(#case.parent.children==case.native_count+1,'Construct following live Destruct adds one row')
end
print('PASS cached Custom Match, pause, Creative and Mods reuse across three world teardowns; clicks, placement, navigation and live Destruct')
