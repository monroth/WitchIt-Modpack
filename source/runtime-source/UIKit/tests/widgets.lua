local hooks, changes, next_id = {}, {}, 0
local retained=0
local text_root
local inputs,frames={}, {}
local function pressed(code) for _,fn in ipairs(inputs) do fn(code) end end
local function frame() local fns=frames;frames={};for _,fn in ipairs(fns) do fn() end end
local R = {log=function() end,pre=function() end,codes={LEFT_MOUSE=1,RIGHT_MOUSE=2,SHIFT=16,CTRL=17,ALT=18,ENTER=13,ESCAPE=27,DELETE=46},post=function(path, fn) hooks[path]=fn end, valid=function(x) if x ~= nil and not x.expired then return x end end,
    next_frame=function(fn) frames[#frames+1]=fn end, native={on_input=function(fn) inputs[#inputs+1]=fn end,key_down=function() return false end,widget_rect=function() return {left=1000,top=300,right=1100,bottom=320} end,load_asset=function(path) return path end,retain=function(object) text_root=object;retained=retained+1;return function() retained=retained-1 end end}}
local function path(asset, event) return '/Game/UserInterface/UIElements/'..asset..'.'..asset..'_C:'..event end
local function event(asset, name, widget, ...) local fn=hooks[path(asset,name)]; if fn then fn(widget, ...) end end
local function node(class)
    next_id=next_id+1
    local widget={id=next_id,class=class,children={}}
    function widget:GetAddress() return self.id end
    function widget:IsA(kind) return kind == '/Script/UMG.UserWidget' and self.class == 'screen' end
    function widget:GetOuter() return self.outer end
    function widget:GetParent() return self.parent end
    function widget:SetStretch(value) self.stretch=value end
    function widget:SetColumnFill(column,value) self.fills=self.fills or {};self.fills[column]=value end
    function widget:GetClass() return {GetFName=function() return self.class end} end
    function widget:SetText(text) self.text=text end
    function widget:GetText()return self.text end
    function widget:HasAnyUserFocus()return self.focused==true end
    function widget:HasFocusedDescendants()return false end
    function widget:SetHintText(text)self.hint=text end
    function widget:SetFont(font) self.font=font end
    function widget:SetColorAndOpacity(colour) self.colour=colour end
    function widget:SetValue(value) self.value=value end
    function widget:SetVisibility(value) self.visibility=value end
    function widget:SetAutoWrapText(value) self.wrap=value end
    function widget:SetJustification() end
    function widget:SetAlwaysShowScrollbar() end
    function widget:HasFocusedDescendants() return false end
    function widget:HasKeyboardFocus() return false end
    function widget:RemoveFromParent()
        for i,child in ipairs(self.outer and self.outer.children or {}) do if child==self then table.remove(self.outer.children,i);break end end
    end
    function widget:SetIsCheckedWithoutEvent(value) self.checked=value end
    function widget:SetRealValue(value) self.RealValue=value; event('WB_SliderWithEditableLabel','ChangeRealValue',self) end
    function widget:CheckDefaultToUpdateUI() event('WB_SliderWithEditableLabel','CheckDefaultToUpdateUI',self) end
    function widget:SetOptionIndex(index) self.SelectedOptionIndex=index end
    function widget:SetActiveState(on) self.active=on end
    function widget:SetBrushFromTexture(texture) self.texture=texture end
    function widget:SetBrush(brush) self.brush=brush end
    function widget:SetPadding(padding) self.padding=padding end
    function widget:SetHintText(text) self.hint=text end
    function widget:ForceLayoutPrepass() end
    function widget:GetDesiredSize() return {X=120,Y=40} end
    function widget:IsHovered() return self.hovered end
    function widget:SetUserSpecifiedScale(v) self.user_scale=v end
    function widget:SetWidthOverride(v) self.width=v end
    function widget:SetHeightOverride(v) self.height=v end
    function widget:SetMinDesiredHeight(v) self.min_height=v end
    function widget:SetClipping(v) self.clipping=v end
    function widget:SetContent(c) self.content=c;c.Slot=c.Slot or {SetVerticalAlignment=function() end,SetPadding=function() end,SetHorizontalAlignment=function() end} end
    function widget:GetOwningPlayer() return {} end
    function widget:AddChild(child)
        if self.class=='/Script/UMG.SizeBox' and #self.children>0 then return end
        self.children[#self.children+1]=child
        child.outer=self
        -- The engine binds cooked child properties when attaching, before UIKit reads them.
        local function slot() return {SetRow=function(s,v)s.Row=v end,SetColumn=function(s,v)s.Column=v end,SetColumnSpan=function(s,v)s.Span=v end,
            SetHorizontalAlignment=function(s,v)s.Horizontal=v end,SetVerticalAlignment=function(s,v)s.Vertical=v end,
            SetSize=function(s,v)s.Size=v end,SetPadding=function(s,v)s.Padding=v end,
            SetAutoSize=function(s,v)s.Auto=v end,SetPosition=function(s,v)s.Position=v end} end
        child.Slot=child.Slot or slot()
        local grid=node('grid');local cell=node('scale');cell.parent=grid;cell.Slot=slot()
        child.DescriptiveLabelText=node('text'); child.DescriptiveLabelText.parent=cell; child.Label=node('text');child.Label.Font={Size=24};child.Label.Slot={SetHorizontalAlignment=function(s,v) s.h=v end}
        child.Label.parent=node('scale');child.Label.parent.Slot=slot(); child.MyButton={SetContent=function(_,c) child.content=c;c.Slot={SetHorizontalAlignment=function(s,v) s.h=v end} end}
        child.CheckBox={IsChecked=function() return child.checked end,GetParent=function() return grid end,Slot=slot()}
        child.InputField=node('text');child.TextField={WidgetStyle={TextStyle={},look='search field'}};child.WidgetTree={RootWidget={Background='frame',Padding={}}}; child.InputField.WidgetStyle={look='game field'}; child.DefaultValueIndicator=node('slider')
        child.Options={Empty=function(array) for k in pairs(array) do if type(k)=='number' then array[k]=nil end end end}
    end
    return widget
end
FName=function(value) return value end
FText=function(value) return value end
local screen=node('screen'); screen.WidgetTree={RootWidget=node('canvas')}; screen.WidgetTree.RootWidget.outer=screen
local parent=node('panel'); parent.outer=screen
local state={screen=screen,actions={}}
local I={actions={},screens={},resets={},destructors={},path=path,id=function(w) return w:GetAddress() end,
    state=function() return state end,string=function(value) return value end,
    array=function(array,values) array:Empty(); for i,v in ipairs(values) do array[i]=v end end}
I.object=function(name)
    if name == '/Script/UMG.Default__WidgetBlueprintLibrary' then return {Create=function(_,_,class)
        return node(class)
    end} end
    return name
end
StaticConstructObject=function(class) return node(class) end
local U={}
dofile('candidate/runtime-source/UIKit/actions.lua')(R,{},U,I)
dofile('candidate/runtime-source/UIKit/widgets.lua')(R,{},U,I)
dofile('candidate/runtime-source/UIKit/fields.lua')(R,{},U,I)
-- WindowKit's controls on top (a window's choice, fields that tell changes, switches).
local W={}
R.call=R.call or function(f,...) return f(...) end
dofile('candidate/runtime-source/UIKit/mouse.lua')(R,{session=function() return {} end},U,I)   -- (the mods' one mouse service)
dofile('candidate/runtime-source/WindowKit/controls.lua')(R,{},U,I,W)
local first_text=U.text(parent,{text='First'})
local cell=I.native(parent,'SizeBox')
local caption=U.text(cell,{text='Auto-update'})
assert(#cell.children==1 and cell.children[1]==caption,
    'a single-child row cell contains its text after the cooked style template is removed')
assert(retained==0,'text construction copies native styling without retaining a template')
local row=U.text(parent,{text='Cauldron 10: 99 / 100',wrap=false})
assert(row.wrap==false and row.WrapTextAt==0)
assert(first_text.wrap==true and first_text.WrapTextAt==1000)
first_text:RemoveFromParent();first_text.expired=true
U.text(parent,{text='Second'})
assert(retained==0,'rebuilding text does not reuse a detached template')
local button=U.button(parent,{label='Press',on_click=function() changes[#changes+1]='clicked' end})
event('WB_BaseControl','ButtonClicked',{GetAddress=function() return button.id end})
assert(changes[1]=='clicked','fresh native wrapper must route by address')
local plain=U.checkbox(parent,{editable=false,label='Vanilla server',value=false})
assert(plain.CheckBox:GetParent().fills==nil,'a fixed-label checkbox keeps the game\'s own layout (dialog rows line up with the game\'s)')
local check,set_check=U.checkbox(parent,{editable=false,columns=true,label='Flag',value=false,on_change=function(v) changes[#changes+1]=v end})
local grid=check.CheckBox:GetParent()
assert(grid.fills[0]==1 and grid.fills[1]==0 and check.CheckBox.Slot.Column==1 and check.DescriptiveLabelText.parent.Slot.Column==0
    and check.DescriptiveLabelText.parent.Slot.Horizontal==1 and check.CheckBox.Slot.Horizontal==3
    and check.DescriptiveLabelText.visibility==3,'columns: label at the left, box at the right end, label lets clicks through')
set_check(true)
assert(#changes==1,'silent repaint must not edit')
check.checked=false
event('WB_CheckBoxWithLabel','SetIsChecked',check)
event('WB_CheckBoxWithLabel','BndEvt__CheckBox_K2Node_ComponentBoundEvent_0_OnCheckBoxComponentStateChanged__DelegateSignature',check)
assert(#changes==2 and changes[2]==false,'two native producers must mean one edit')
local slider,set_slider=U.slider(parent,{label='Count',min=1,max=100,input_max=255,kind='int',value=3,infinite=true,on_change=function(v) changes[#changes+1]=v end})
set_slider(4)
assert(#changes==2,'reentrant SetRealValue must be silent')
local slider_record=I.actions[slider.id]
slider_record.commit('NaN'); assert(slider.InputField.text=='4')
slider_record.commit('2.5'); assert(slider.InputField.text=='4')
slider_record.commit('inf'); assert(changes[3]=='infinite' and slider.InputField.text=='∞')
slider_record.reset(); assert(changes[4]==3)
slider_record.slide(1);assert(slider.InputField.text=='∞' and slider.RealValue==100)
slider_record.commit('100');assert(slider.InputField.text=='100' and changes[#changes]==100)
slider_record.commit('255');assert(slider.InputField.text=='255' and changes[#changes]==255)
slider_record.commit('256');assert(slider.InputField.text=='255')
slider_record.reset();assert(slider.InputField.text=='3')
local edits=#changes
local combo,set_combo=U.combo(parent,{label='Choice',options={{label='One',value='one'},{label='Two',value='two'}},value='one',on_change=function(v) changes[#changes+1]=v end})
set_combo('two'); assert(#changes==edits)
combo.SelectedOptionIndex=0
event('WB_ComboBoxOverlay','SetOption',{BaseWidget=combo,GetAddress=function() return 900 end},'One',0)
assert(changes[edits+1]=='one','read committed BaseWidget after native overlay selection')
local scroll={ScrollWidgetIntoView=function(self,target)self.target=target end}
local function navigationTarget(w)w.SetNavigationRuleExplicit=function(self,dir,target)self.nav=self.nav or {};self.nav[dir]=target end end
navigationTarget(button);navigationTarget(check);navigationTarget(slider)
navigationTarget(button.CheckBox);navigationTarget(check.CheckBox);navigationTarget(slider.CheckBox)
U.navigate({button,check,slider},scroll)
assert(check.CheckBox.nav[2]==button and check.CheckBox.nav[3]==slider,'native inner checkbox follows visible row order')
event('WB_BaseControl','OnFocusReceived',check)
assert(scroll.target==check,'native focus scrolls the owned row into view')
local name=U.input(parent,{initial=true,value='Named preset',hint='Preset name'})
assert(name:GetText()=='Named preset' and I.initial(parent)==name,'preset name receives initial native focus ahead of buttons')
assert(name.WidgetStyle and name.WidgetStyle.look=='search field','a text field takes the game search bar look')
-- A text field tells a change once, after a key press (typing ends); setting it says nothing.
local typed={}
local field,set_field=U.input(parent,{value='a',on_change=function(v) typed[#typed+1]=v end})
field:SetText('ab');pressed(13);frame()
assert(typed[1]=='ab' and #typed==1,'a typed change is told after the key press')
pressed(13);frame();assert(#typed==1,'once')
set_field('c');pressed(13);frame();assert(#typed==1,'setting it is no change')
-- A switch: a game button lit while on; a click turns it and tells; set changes it quietly.
local turned
local switch,set_switch=W.toggle(parent,{label='Snap',value=false,on_change=function(v) turned=v end})
assert(switch.active==false)
I.actions[switch.id].click();assert(turned==true and switch.active==true,'a click turns it on')
set_switch(false,'Snap off');assert(turned==true and switch.active==false and switch.Label.text=='Snap off','set changes it quietly')
I.remove(combo)
assert(not I.actions[combo.id] and not state.actions[combo.id])
for _, cleanup in ipairs(I.destructors) do cleanup(state) end
assert(retained==0,'screen teardown releases the text style')
assert(#parent.children==0,"screen teardown must remove injected widget roots")
for _, reset in ipairs(I.resets) do reset() end
print('UIKit widget engine-order checks passed')
