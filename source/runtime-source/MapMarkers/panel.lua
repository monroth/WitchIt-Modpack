-- The settings of the selected markers (all of one kind) in the edit screen's World settings tab,
-- made of the game's own controls. The panel is the same for every kind; the kind fills it
-- (def.panel): colour (true: a colour section with the colour and seven swatches, without a title of its
-- own; the colour is announced as a colour place, U.colour_place: a mod with a colour window, Creative
-- Tools, puts its button by it; user 11-20: no picker of its own, no Auto), top(P) (above the colour section), colourFields(P) (after the swatches),
-- fields(P) (after the colour section), check()
-- -> title, text (the "Check map problems" button). P: the panel's helpers below.
return function(R,C,U,M)
    local colour=M.colour
    -- (UIKit's colour conversions, as the panel keeps a colour: {H,S,V} and {R,G,B,A})
    local edit=M.CR..'PlacementAndEditUI/'
    local tabs,tiles,el=edit..'Tabs/',edit..'TileAndListviews/','/Game/UserInterface/UIElements/'
    local path=M.path
    local text_of=R.text
    local panel,swatches,grids,controls=nil,{},{},{}
    -- The panel's controls act through UIKit's records of controls (the game's control events);
    -- a panel built again leaves its old controls without actions.
    local function action(widget,record) controls[#controls+1]=widget:GetAddress();return U.parts.action(widget,record) end
    local function clear()
        swatches,grids={},{}
        for _,id in ipairs(controls) do U.parts.actions[id]=nil end
        controls={}
        if panel then
            if R.valid(panel.root) then panel.root:RemoveFromParent() end
            panel=nil
        end
    end
    local function paintSwatch(tile)
        local row=swatches[tile:GetAddress()]
        if not row then return end
        local grid=tile.GridButton
        grids[grid:GetAddress()]=tile
        local icon=grid.Icon
        local size={X=icon.Brush.ImageSize.X,Y=icon.Brush.ImageSize.Y}
        icon:SetBrush(M.asset('/Script/UMG.Default__Image').Brush)
        icon.Brush.ImageSize.X=size.X;icon.Brush.ImageSize.Y=size.Y
        icon:SetDesiredSizeOverride(size)
        for _,widget in ipairs({tile,grid,grid.Button}) do widget:SetColorAndOpacity({R=1,G=1,B=1,A=1}) end
        icon:SetColorAndOpacity(row.colour)
    end
    local function build(w)
        clear()
        local selected={}
        for _,actor in ipairs(M.values(w:GetOwningPlayer().SelectedActors)) do
            if R.valid(actor) then
                local info=M.marker(actor)
                if not info then return end
                selected[#selected+1]={actor=actor,info=info}
            end
        end
        if #selected==0 then return end
        local first=selected[1].info
        for _,row in ipairs(selected) do if row.info.kind~=first.kind then return end end
        local def=M.kindOf(first);local spec=def.panel
        if not spec then return end   -- (a kind with its own editor)
        local host=M.host()
        local P={w=w,first=first,selected=selected,host=host}
        local function native(kind,parent)
            local widget=StaticConstructObject(M.asset('/Script/UMG.'..kind),w.WidgetTree)
            if parent then parent:AddChild(widget) end
            return widget
        end
        local function cooked(folder,name,parent)
            local widget=StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary'):Create(w,
                M.asset(path(folder,name)),w:GetOwningPlayer())
            parent:AddChild(widget);return widget
        end
        local function box(parent,width,height)
            local widget=native('SizeBox',parent)
            widget:SetWidthOverride(width);widget:SetHeightOverride(height)
            return widget
        end
        local function auto(parent,child)
            local slot=parent:AddChild(child)
            slot:SetSize({Value=1,SizeRule=0});slot:SetVerticalAlignment(1)
        end
        local function space(parent,width) auto(parent,box(nil,width,1)) end
        local function text(parent,value,size)
            local widget=native('TextBlock',parent)
            local font=widget.Font;font.Size=size or 14;widget:SetFont(font)
            widget:SetText(FText(value));return widget
        end
        P.native,P.cooked,P.box,P.auto,P.space,P.text,P.el=native,cooked,box,auto,space,text,el
        local root=native('VerticalBox',w.TransformBox:GetParent())
        panel={widget=w,root=root}
        P.root=root
        local sliders,choices,repaints={},{},{}
        local showcase
        local function swatch(tile,c,index)
            local data=StaticConstructObject(M.asset(path(tiles,'B_LightColorButtonData')),w)
            data.Color={X=c.R,Y=c.G,Z=c.B};data.Parent=w
            data.IsInitial=false;data.IsSelected=false
            tile.ItemData=data;tile.ParentWidget=w;tile.Color=data.Color
            tile.bIsFocusable=index~=nil;tile:SetIsEnabled(host or index==nil)
            swatches[tile:GetAddress()]={colour=c}
            tile:SetButtonParameters();paintSwatch(tile)
            if index then choices[#choices+1]={widget=tile,index=index} end
        end
        local function sync()
            for _,row in ipairs(sliders) do row.set(row.read()) end
            if showcase then
                local tile=showcase
                local c=first.colour
                tile.Color={X=c.R,Y=c.G,Z=c.B};tile.ItemData.Color=tile.Color
                swatches[tile:GetAddress()].colour=c
                tile:SetButtonParameters();paintSwatch(tile)
                U.colour_changed(tile)   -- (a colour window showing it follows)
                for _,choice in ipairs(choices) do
                    local on,p=true,colour.PALETTE[choice.index]
                    for _,row in ipairs(selected) do
                        on=on and math.abs(row.info.colour.R-p.R)<1e-6
                            and math.abs(row.info.colour.G-p.G)<1e-6 and math.abs(row.info.colour.B-p.B)<1e-6
                    end
                    choice.widget.ItemData.IsSelected=on;choice.widget.GridButton.bSelected=on
                end
            end
            for _,fn in ipairs(repaints) do fn() end
        end
        P.sync=sync
        -- fn() after every change (a kind's own parts of the panel).
        function P.repaint(fn) repaints[#repaints+1]=fn end
        -- value: the new value, or fn(old) -> new value for each marker.
        -- (only the host places and changes markers)
        local function change(key,value)
            if not M.host() then return end
            for _,row in ipairs(selected) do
                local before={};for k,v in pairs(row.info) do before[k]=v end
                if type(value)=='function' then row.info[key]=value(row.info[key]) else row.info[key]=value end
                M.stamp(row.actor,row.info);M.look(row.actor,row.info)
                -- (what depended on the marker as it was, and depends on it now)
                M.changed(row.actor,before);M.changed(row.actor,row.info)
            end
        end
        P.change=change
        -- The panel again, next frame (a change that changes which fields there are).
        function P.rebuild() R.next_frame(function() if R.valid(w) then build(w) end end) end
        local function button(parent,label,width,click)
            local frame=box(parent,width,36)
            local scale=native('ScaleBox',frame);scale:SetStretch(2);scale:SetStretchDirection(1)
            local widget=cooked(el,'WB_TabButton',scale)
            widget.LabelText=FText(label);widget.Label:SetText(widget.LabelText)
            widget:SetActiveState(false);widget:SetIsEnabled(host);widget.bIsFocusable=true
            action(widget,{click=click})
            return widget
        end
        P.button=button
        -- A control's action: record {click, check, select, ...} by the game's events below.
        P.action=action
        local function numericLayout(control,withTrack,withReset)
            local label=control.DescriptiveLabelText
            local labelScale=label:GetParent();local grid=labelScale:GetParent()
            local extras={}
            for _,child in ipairs(M.values(grid:GetAllChildren())) do extras[text_of(child:GetFName())]=child end
            grid:ClearChildren()
            for col=0,3 do grid:SetColumnFill(col,0) end
            local frame=box(nil,446,40);local slot=grid:AddChildToGrid(frame,0,0)
            slot:SetHorizontalAlignment(1);slot:SetVerticalAlignment(1)
            local row=native('HorizontalBox',frame)
            local labelBox=box(nil,withTrack and (withReset and 148 or 180) or 298,32);auto(row,labelBox);labelBox:AddChild(labelScale)
            label:SetJustification(2);labelScale:SetStretch(2);labelScale:SetStretchDirection(1)
            space(row,8)
            for _,child in ipairs({extras.ValueFill,control.DefaultValueIndicator}) do
                child:SetVisibility(1);grid:AddChildToGrid(child,0,2)
            end
            if withTrack then
                local track=box(nil,110,40);auto(row,track);track:AddChild(control.ValueSlider);space(row,8)
            else
                control.ValueSlider:SetVisibility(1);control.ValueSlider:SetIsEnabled(false)
                grid:AddChildToGrid(control.ValueSlider,0,2)
            end
            local input=box(nil,140,40);input:SetMinDesiredWidth(140);auto(row,input)
            local overlay=native('Overlay',input)
            extras.ValueText:SetVisibility(1)
            for _,child in ipairs({control.InputField,extras.ValueText,extras.ValueFocusButton}) do
                local childSlot=overlay:AddChild(child);childSlot:SetHorizontalAlignment(0);childSlot:SetVerticalAlignment(0)
            end
            local reset=control.ResetButton:GetParent()
            if withReset then
                space(row,4);auto(row,reset)
            else
                reset:SetVisibility(1);grid:AddChildToGrid(reset,0,1)
            end
        end
        -- default: the value the native reset arrow restores; without one the arrow is hidden.
        local function slider(parent,label,lo,hi,step,suffix,read,write,layout,default)
            local frame=box(parent,446,40)
            frame.Slot:SetHorizontalAlignment(2);frame.Slot:SetVerticalAlignment(1)
            frame.Slot:SetPadding({Left=10,Right=10,Top=0,Bottom=0})
            local widget=cooked(el,'WB_SliderWithEditableLabel',frame)
            widget.DescriptiveLabel=FText(label);widget.DescriptiveLabelText:SetText(widget.DescriptiveLabel)
            widget.MinimumValue=lo;widget.MaximumValue=hi;widget.StepSize=step
            widget.bRoundToIntegers=step>=1;widget.bTimeValueInSeconds=false;widget.UIMultiplyFactor=1
            widget.ValueSuffix=FText(suffix);widget.DefaultFloatValue=default or read()
            widget.bIsFocusable=true;widget:SetIsEnabled(host)
            if layout then
                local font=widget.DescriptiveLabelText.Font;font.Size=14;widget.DescriptiveLabelText:SetFont(font)
                widget.TextFocusColor=widget.TextColor;widget:ChangeTextColor(widget.TextColor)
                numericLayout(widget,layout=='radius',default~=nil)
            end
            local record={}
            local function set(value)
                record.value=value;record.painting=true;widget:SetRealValue(value)
                if default then widget:CheckDefaultToUpdateUI()
                else widget.ResetButton:SetVisibility(1);widget.DefaultValueIndicator:SetVisibility(1) end
                record.painting=false
            end
            record.commit=function(value)
                value=tonumber((text_of(value):gsub('%s*[%a°%%]+%s*$','')))
                if not value or value~=value or math.abs(value)==math.huge then set(record.value);return end
                value=math.max(lo,math.min(hi,value))
                if step>=1 then value=math.floor(value/step+.5)*step end
                if value~=record.value then write(value);sync() end
            end
            record.slide=function(value) record.commit(tostring(lo+(hi-lo)*value)) end
            record.drag=function() record.commit(tostring(widget.RealValue)) end
            record.reset=function() record.commit(tostring(default)) end
            action(widget,record);sliders[#sliders+1]={set=set,read=read};set(read())
            return widget
        end
        P.slider=slider
        function P.number(parent,key,label,lo,hi,step,suffix,layout,default)
            return slider(parent,label,lo,hi,step,suffix or '',function() return first[key] end,
                function(value) change(key,value) end,layout or 'number',default)
        end
        -- A checkbox of the game's: read() -> whether it is ticked, write(value) on a change.
        function P.checkbox(parent,label,read,write)
            local frame=box(parent,446,40)
            frame.Slot:SetHorizontalAlignment(2);frame.Slot:SetVerticalAlignment(1)
            frame.Slot:SetPadding({Left=10,Right=10,Top=0,Bottom=0})
            local widget=cooked(el,'WB_CheckBoxWithLabel',frame)
            widget.DescriptiveLabel=FText(label);widget.DescriptiveLabelText:SetText(widget.DescriptiveLabel)
            widget.bIsFocusable=true;widget:SetIsEnabled(host)
            local record={}
            local function set(value)
                record.value=value;record.painting=true;widget:SetIsCheckedWithoutEvent(value);record.painting=false
            end
            record.check=function()
                local value=widget.CheckBox:IsChecked()
                if value~=record.value then record.value=value;write(value);sync() end
            end
            action(widget,record);sliders[#sliders+1]={set=set,read=read};set(read())
            return widget
        end
        P.content=root
        if spec.top then spec.top(P) end
        local content=root
        if spec.colour then
            local tab=cooked(tabs,'WB_LightColorTab',root)
            for _,child in ipairs(M.values(tab.WidgetTree.RootWidget:GetAllChildren())) do
                if text_of(child:GetFName())=='TextBlock_38' then child:SetVisibility(1) end
            end
            for _,field in ipairs({'BrightnessBox','SpotLightAngleBox','WB_CastShadowsCheckboxAreaButton',
                'WB_DirectionalLightCheckboxAreaButton','LightGroupPreviewInfo'}) do tab[field]:SetVisibility(1) end
            showcase=tab.ShowcaseColorButton;swatch(showcase,first.colour)
            content=tab.ColorShowcaseBox:GetParent()
            P.content=content
            local row=native('HorizontalBox',content)
            row.Slot:SetHorizontalAlignment(2);row.Slot:SetPadding({Left=10,Right=10,Top=0,Bottom=0})
            for index=1,7 do
                local frame=box(nil,40,36);auto(row,frame)
                local scale=native('ScaleBox',frame);scale:SetStretch(2);scale:SetStretchDirection(1)
                local tile=cooked(tiles,'WB_LightColorButton',scale)
                swatch(tile,colour.PALETTE[index],index);tile:SetToolTipText(FText(colour.NAMES[index]))
                action(tile,{click=function()
                    change('colour',colour.PALETTE[index]);sync()
                end})
            end
            for i,choice in ipairs(choices) do
                if i>1 then choice.widget:SetNavigationRuleExplicit(0,choices[i-1].widget) end
                if i<#choices then choice.widget:SetNavigationRuleExplicit(1,choices[i+1].widget) end
            end
            if spec.colourFields then spec.colourFields(P) end
            -- (any colour: wherever a mod offers a colour window for a colour place)
            if host then
                U.colour_place({widget=showcase,title=def.title..' colour',
                    get=function() local c=first.colour;return {R=c.R,G=c.G,B=c.B} end,
                    set=function(c)
                        change('colour',{R=c.R,G=c.G,B=c.B,A=1})
                        -- (the panel may have been built again since: only its own squares are painted)
                        if R.valid(showcase) and swatches[showcase:GetAddress()] then sync() end
                    end})
            end
        end
        P.content=content
        -- Markers that go together (def.together, all outlined while one is selected): how many.
        if def.together then
            local n=0
            for _,row in ipairs(M.markers(def.record)) do if row.info.kind==first.kind then n=n+1 end end
            text(root,'On this map: '..n).Slot:SetHorizontalAlignment(2)
        end
        if spec.fields then spec.fields(P) end
        if spec.check then
            button(root,'Check map problems',200,function() U.message(spec.check()) end)
        end
        sync()
    end
    R.post(path(el..'MenuTileView/','WB_TileViewButton','SetButtonParameters'),paintSwatch)
    R.post(path(el,'WB_GridButton','SetIconImage'),function(grid)
        local tile=grids[grid:GetAddress()];if tile then paintSwatch(tile) end
    end)
    -- The selected markers' name in the edit screen: their kind's title (and how many).
    M.onEditor.post(path(tabs,'WB_TargetActorDisplay','UpdateName'),function(widget)
        if not R.valid(widget.TargetActor) then return end
        local info,def=M.marker(widget.TargetActor)
        if not info or not def.panel or widget.TargetActor.IsPreview then return end
        local count=0
        for _,actor in ipairs(M.values(widget.OwningCreativePlayerController.SelectedActors)) do
            if not R.valid(actor) then return end
            local other=M.marker(actor);if not other or other.kind~=info.kind then return end
            count=count+1
        end
        widget.TargetName:SetText(FText(def.title..(widget.IsHeader and count>1 and ' ('..count..')' or '')))
    end)
    -- The edit screen's picture of a selected marker (its header, the collapsed screen, a group's
    -- preview) is its kind's icon, as in the palette.
    -- (The game draws that picture from a preview of the block once it is ready, setting the
    -- button's icon then: the kind's icon is set at that moment too.)
    local previews={}   -- grid button address -> def of the marker it pictures
    local function picture(grid,def)
        M.icon(grid.Icon,def)
    end
    M.onEditor.post('/Game/UserInterface/PropCollection/WB_PropButton.WB_PropButton_C:SetupAsPreviewButton',function(button,actor)
        local key=button.GridButton:GetAddress()
        previews[key]=nil
        if not R.valid(actor) then return end
        local info,def=M.marker(actor)
        if not info or not def.icon then return end
        previews[key]=def;picture(button.GridButton,def)
    end)
    M.onEditor.post(path(el,'WB_GridButton','SetIconImage'),function(grid)
        local def=previews[grid:GetAddress()];if def then picture(grid,def) end
    end)
    R.on('world_end',function() previews={} end)
    -- A marker's block is not a material: the material section is not offered for markers alone.
    M.onEditor.post(path(tabs,'WB_WorldSettingsTab','UpdateContentTabsVisibility'),function(tab)
        local list=M.values(tab.MaterialStructures)
        if #list==0 then return end
        for _,actor in ipairs(list) do if not R.valid(actor) or not M.marker(actor) then return end end
        tab.WB_MaterialChangeTab:SetVisibility(1)
    end)
    R.post('/Script/UMG.UserWidget:Destruct',function(widget)
        if panel and widget:GetAddress()==panel.widget:GetAddress() then clear() end
    end)
    -- The panel follows the edit screen: built with its World settings tab, off outside the editor.
    for _,method in ipairs({'UpdateWorldsettingsTabContent','UpdateContentTabsVisibility'}) do
        M.onEditor.post(path(tabs,'WB_WorldSettingsTab',method),build)
    end
    for _,method in ipairs({'UpdateNonCollapsedUI','Maximize'}) do
        M.onEditor.post(path(edit,'WB_PlaceAndEditUI',method),function(w) build(w.WorldSettingsTab) end)
    end
    C.on_playtest(function() if not M.editing() then clear() end end)
    -- The edit screen outlives worlds with our panel on it: the next build takes it off.
    R.on('world_end',function() swatches={};grids={} end)
    return {build=build,clear=clear}
end
