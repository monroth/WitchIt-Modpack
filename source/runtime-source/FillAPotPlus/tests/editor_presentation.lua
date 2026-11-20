local dir='candidate/runtime-source/FillAPotPlus/'
local hooks,events,objects={},{},{}
local function path(folder,name,event) return folder..name..'.'..name..'_C'..(event and ':'..event or '') end
-- (an event's looks are drawn in the frame after it: the frame passes with the event here)
local frames={}
local function frame() local list=frames;frames={};for _,fn in ipairs(list) do fn() end end
local function fire(event,...)
    for _,fn in ipairs(hooks[event] or {}) do fn(...) end
    frame()
end
local function copy(value)
    if type(value)~='table' then return value end
    local result={};for k,v in pairs(value) do result[k]=copy(v) end;return result
end
local function slot()
    return {SetSize=function(self,v) self.size=v end,SetPadding=function(self,v) self.padding=v end,
        SetVerticalAlignment=function(self,v) self.vertical=v end,SetHorizontalAlignment=function(self,v) self.horizontal=v end}
end
local function node(kind)
    local w={kind=kind,children={},Font={Size=20},Brush={ImageSize={X=60,Y=60}},bVisible=true}
    objects[#objects+1]=w;w.id=#objects
    function w:GetAddress() return self.id end
    function w:GetFullName() return self.kind..' '..self.id end
    function w:GetOuter() return self.outer end
    function w:IsA(class)
        return self.kind==class or class:find('WB_TileViewButton',1,true)~=nil and self.kind=='tile'
    end
    function w:GetFName() return self.name or self.kind end
    function w:GetParent() return self.parent end
    function w:AddChild(child)
        child:RemoveFromParent();self.children[#self.children+1]=child;child.parent=self;child.Slot=slot();return child.Slot
    end
    function w:AddChildToGrid(child) return self:AddChild(child) end
    function w:RemoveFromParent()
        for i,c in ipairs(self.parent and self.parent.children or {}) do if c==self then table.remove(self.parent.children,i);break end end
        self.parent=nil
    end
    function w:ClearChildren() for _,c in ipairs(self.children) do c.parent=nil end;self.children={} end
    function w:GetAllChildren() return self.children end
    function w:SetColumnFill() end
    function w:SetWidthOverride(v) self.width=v end
    function w:SetMinDesiredWidth(v) self.minWidth=v end
    function w:SetHeightOverride(v) self.height=v end
    function w:SetStretch(v) self.stretch=v end
    function w:SetStretchDirection(v) self.direction=v end
    function w:SetText(v) self.text=v end
    function w:SetFont(v) self.Font=v end
    function w:SetVisibility(v) self.visibility=v end
    function w:SetIsEnabled(v) self.enabled=v end
    function w:SetJustification(v) self.justification=v end
    function w:SetActiveState(v) self.active=v end
    function w:SetNavigationRuleExplicit() end
    function w:SetToolTipText(v) self.tooltip=v end
    function w:SetColorAndOpacity(v) self.colour=copy(v) end
    function w:SetBrush(v) self.Brush=copy(v) end
    function w:SetBrushFromTexture(v) self.texture=v end
    function w:SetDesiredSizeOverride(v) self.desired=copy(v) end
    function w:ChangeTextColor(v) self.labelColour=v end
    function w:SetOptionIndex(v) self.SelectedOptionIndex=v end
    function w:SetIsCheckedWithoutEvent(v) self.checked=v end
    function w:IsChecked() return self.checked end
    -- Native: the reset arrow shows while the value differs from the default.
    function w:CheckDefaultToUpdateUI() self.ResetButton:SetVisibility(self.RealValue~=self.DefaultFloatValue and 0 or 1) end
    function w:SetRealValue(v)
        self.RealValue=v
        self.ResetButton:SetVisibility(0)
        fire(path('/Game/UserInterface/UIElements/','WB_SliderWithEditableLabel','ChangeRealValue'),self)
    end
    return w
end
local pc={SelectedActors={},CurrentPlayMode=1,IsLocalController=function() return true end,IsValid=function() return true end}
local session={pc=pc,role='host',mode='creative',is_creative=true,gs={IsPlayTestMode=false}}
local R={native={on_input=function() end,key_down=function() return false end}}
local V=dofile('candidate/runtime-source/WitchItRuntime/Scripts/values.lua');R.values,R.text=V.values,V.text
function R.next_frame(fn) frames[#frames+1]=fn;return function() end end
function R.call(fn,...) return fn(...) end
R.native.on_asset=function(path,ready) ready(path);return function() end end
function R.post(event,fn) hooks[event]=hooks[event] or {};table.insert(hooks[event],fn) end
function R.on(event,fn) events[event]=events[event] or {};table.insert(events[event],fn) end
function R.valid(o) return type(o)=='table' and not o.dead end
local playtestFns={}
local S={R=R,C={on_playtest=function(fn) playtestFns[#playtestFns+1]=fn end,session=function() return session end},U={message=function() end},dir=dir,
    CR='/Game/Blueprints/Gamemodes/CreativeMode/',codec=dofile(dir..'codec.lua')(dofile('candidate/runtime-source/WitchItRuntime/Scripts/json.lua')),calc=dofile(dir..'math.lua'),
    names={'Fill a Pot cauldron','Witch respawn point'},carriers={{'pot'},{'respawn'}}}
S.path=path;S.values=function(v) return v end;S.text=tostring
S.map=S.codec.mapOf();function S.setMap(k,v) S.map[k]=v end;S.RAYS_HIGH=51.5;function S.rays() end   -- (world.lua's: the map's settings, once)
function R.pre() end
function R.key() end
dofile(dir..'tests/lib/scope.lua')(S)
-- MapMarkers (the real one) hosts the markers: its palette, looks and panel; its records here are
-- the test's (each block keeps its info).
R.json=dofile('candidate/runtime-source/WitchItRuntime/Scripts/json.lua')
R.native.load_asset=function(p) return p end
dofile('candidate/runtime-source/Core/tests/lib/effects.lua')(R,S.C)
S.C.HOST_WIDGET,S.C.PIXEL_FONT='/Game/UserInterface/Information/WB_EarlyVersionWatermark.WB_EarlyVersionWatermark_C','/Game/UserInterface/Fonts/PixelFont.PixelFont'
S.C.CREATIVE_PC='/Game/Blueprints/Gamemodes/CreativeMode/B_CreativePlayerController.B_CreativePlayerController_C'
R.packages=R.packages or {};R.packages.WorldKit=dofile('candidate/runtime-source/WorldKit/package.lua')(R,S.C)
S.U.parts=dofile('candidate/runtime-source/UIKit/tests/lib/actions.lua')(R)
-- (the panel's colour is announced as a colour place, UIKit's; here it is recorded)
local places={}
S.U.colour_place=function(p) places[#places+1]=p end
local colourChanges=0
S.U.colour_changed=function() colourChanges=colourChanges+1 end
S.U.rgb=function(h,s,v) h=(h%360)/60;local i,f=math.floor(h),h-math.floor(h);local p,q,t=v*(1-s),v*(1-s*f),v*(1-s*(1-f))
    local c=({{v,t,p},{q,v,p},{p,v,t},{p,q,v},{t,p,v},{v,p,q}})[i+1];return c[1],c[2],c[3] end
S.U.hsv=function(r,g,b) local hi,lo=math.max(r,g,b),math.min(r,g,b);local d,h=hi-lo,0
    if d>1e-9 then if hi==r then h=60*(((g-b)/d)%6) elseif hi==g then h=60*((b-r)/d+2) else h=60*((r-g)/d+4) end end
    return h,hi>1e-9 and d/hi or 0,hi end   -- (UIKit's conversions)
local MM=dofile('candidate/runtime-source/MapMarkers/package.lua')(R,S.C,S.U)
S.MM=MM
MM.values=S.values
local palette6=MM.colour.PALETTE
local imageDefaults={Brush={ImageSize={X=32,Y=32},DrawAs=1}}
S.asset=function(p) return p=='/Script/UMG.Default__Image' and imageDefaults or p end
MM.asset=S.asset
S.new=function(p) return node(p) end
S.transform=function(_,position,scale) return {Translation=position,Scale3D=scale or {X=1,Y=1,Z=1}} end
MM.transform=S.transform
local stamps=0
function S.stamp(actor,info)
    stamps=stamps+1
    actor.info=copy(info)
end
S.marker=function(actor) return actor.info and copy(actor.info) end
S.distance=function(a,b) return (a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2 end
local function actor(kind,radius)
    local a=node('actor');a.info=S.codec.defaults({kind=kind,radius=radius,colour=palette6[6]})
    a.components={};a.position={X=100,Y=200,Z=300};a.scale={X=4,Y=4,Z=4}
    function a:K2_GetActorLocation() return self.position end
    function a:K2_GetComponentsByClass() return self.components end
    function a:AddComponentByClass(class,manual,transform)
        local c=node(class);self.components[#self.components+1]=c;c.owner=self;c.transform=copy(transform);c.manual=manual
        function c:GetOwner() return self.owner end
        function c:K2_DestroyComponent(owner) assert(owner==self.owner);assert(not self.dead);self.dead=true end
        function c:SetMobility(v) self.mobility=v end
        function c:SetAbsolute(a,b,d) self.absolute={a,b,d} end
        function c:SetComponentTickEnabled() end
        function c:K2_AttachToComponent() end
        function c:SetWidgetSpace(v) self.space=v end
        function c:SetDrawAtDesiredSize() end
        function c:SetPivot() end
        function c:SetWidget(w) self.widget=w end
        function c:SetCollisionEnabled(v) self.collision=v end
        function c:SetCollisionObjectType() end
        function c:SetCollisionResponseToAllChannels() end
        function c:GetCollisionEnabled() return self.collision or 0 end
        function c:SetGenerateOverlapEvents(v) self.overlap=v end
        function c:SetSphereRadius(v) self.radius=v end
        function c:SetHiddenInGame(v) self.hidden=v end
        function c:SetCastShadow() end
        function c:SetStaticMesh() end
        function c:SetVectorParameterValueOnMaterials() end
        function c:SetDecalMaterial() end
        function c:SetBoxExtent() end
        function c:K2_SetText(v) self.text=v end
        function c:SetWorldSize() end
        function c:SetHorizontalAlignment() end
        return c
    end
    return a
end
local pot,other,respawn=actor(1,1000),actor(1,5000),actor(2,2500)
S.markers=function() return {{actor=pot,info=copy(pot.info)},{actor=other,info=copy(other.info)}} end
S.propGroups=function() return {} end
S.eligible=function() return {} end
local function cooked(class)
    local kind=class:match('%.(.+)_C$');local w=node(kind)
    w.WidgetTree={}
    if kind=='WB_LightColorTab' then
        w.WidgetTree={RootWidget=node('VerticalBox')}
        local title=node('TextBlock');title.name='TextBlock_38';title.nativeStyle=true;w.WidgetTree.RootWidget:AddChild(title)
        local content=node('VerticalBox');w.WidgetTree.RootWidget:AddChild(content)
        w.ColorShowcaseBox=node('HorizontalBox');content:AddChild(w.ColorShowcaseBox)
        w.ShowcaseColorButton=cooked(path(S.CR..'PlacementAndEditUI/TileAndListviews/','WB_LightColorButton'))
        w.ColorShowcaseBox:AddChild(w.ShowcaseColorButton)
        for _,field in ipairs({'BrightnessBox','SpotLightAngleBox','WB_CastShadowsCheckboxAreaButton',
            'WB_DirectionalLightCheckboxAreaButton','LightGroupPreviewInfo'}) do w[field]=node('unused') end
    elseif kind=='WB_LightColorButton' then
        w.GridButton=node('grid');w.GridButton.Icon=node('Image');w.GridButton.Button=node('Button')
        function w:SetButtonParameters()
            self.GridButton.Icon.Brush.ResourceObject='unrenderable-light-material'
            fire(path('/Game/UserInterface/UIElements/MenuTileView/','WB_TileViewButton','SetButtonParameters'),self)
        end
    elseif kind=='WB_SliderWithEditableLabel' then
        local grid=node('GridPanel');local scale=node('ScaleBox');grid:AddChild(scale)
        w.DescriptiveLabelText=node('TextBlock');scale:AddChild(w.DescriptiveLabelText)
        w.TextColor={R=1,G=1,B=1,A=1}
        w.ValueSlider=node('Slider');grid:AddChild(w.ValueSlider)
        w.InputField=node('EditableTextBox');grid:AddChild(w.InputField)
        w.DefaultValueIndicator=node('indicator');grid:AddChild(w.DefaultValueIndicator)
        local reset=node('reset');grid:AddChild(reset);w.ResetButton=node('Button');reset:AddChild(w.ResetButton)
        for _,name in ipairs({'ValueText','ValueFill','ValueFocusButton'}) do local child=node(name);child.name=name;grid:AddChild(child) end
    elseif kind=='WB_TabButton' then w.Label=node('TextBlock')
    elseif kind=='WB_CheckBoxWithLabel' then
        w.DescriptiveLabelText=node('TextBlock');w.CheckBox={IsChecked=function() return w.checked end}
        function w:SetIsCheckedWithoutEvent(v) self.checked=v end
    end
    return w
end
FText=tostring;FName=tostring
StaticConstructObject=function(class) return node(class:match('%.(.+)$')) end
StaticFindObject=function(p)
    if p:match('WidgetBlueprintLibrary$') then return {Create=function(_,_,class) return cooked(class) end} end
    return {CreateDynamicMaterialInstance=function() return {SetVectorParameterValue=function() end,SetScalarParameterValue=function() end} end}
end
MM.stamp=S.stamp
MM.marker=function(actor) if actor.info then local info=copy(actor.info);return info,MM.kindOf(info) end end
dofile(dir..'editor.lua')(S)
-- World edits' teleporters are the other kinds in the palette.
S.C.map={module=function() end}
dofile('candidate/runtime-source/BaseWorldPlus/teleporters.lua')(R,S.C,S.U,MM)
local edit=S.CR..'PlacementAndEditUI/'
local function pcEvent(name) fire(path(S.CR,'B_CreativePlayerController',name),pc) end
local function spheres(a)
    local list={};for _,c in ipairs(a.components) do if not c.dead and c.kind=='/Script/Engine.SphereComponent' then list[#list+1]=c end end;return list
end
pc.SelectedActors={pot,other,respawn};pcEvent('SelectMultiple')
local ring=spheres(pot)[1];local ring2=spheres(other)[1]
assert(ring.radius==1000 and ring2.radius==5000 and #spheres(respawn)==0)
assert(ring.manual==false and ring.transform.Translation.X==0 and ring.transform.Scale3D.X==1)
assert(ring.absolute[1]==false and ring.absolute[2] and ring.absolute[3] and ring.hidden==false and ring.collision==0 and ring.overlap==false)
assert(ring.colour==nil,'keep native default wire colour; never tint the three-circle outline')
pc.SelectedActors={pot,other};local parent=node('content');local transform=node('TransformBox');parent:AddChild(transform)
local tab=node('WorldSettingsTab');tab.TransformBox=transform;tab.WidgetTree={}
function tab:GetOwningPlayer() return pc end
local function open() fire(path(edit..'Tabs/','WB_WorldSettingsTab','UpdateWorldsettingsTabContent'),tab) end
local function find(kind,label)
    for i=#objects,1,-1 do local w=objects[i]
        if w.kind==kind and (not label or w.DescriptiveLabel==label or w.LabelText==label) then return w end
    end
end
open();assert(stamps==0,'painting native controls must not write marker bytes')
local light=find('WB_LightColorTab');assert(light.WidgetTree.RootWidget.children[1].nativeStyle)
assert(light.WidgetTree.RootWidget.children[1].visibility==1 and light.BrightnessBox.visibility==1,'the colour section has no title (user)')
-- (user) the cauldrons to win come before the colour section; the wanted kinds count is with the wanted props.
local win=find('WB_SliderWithEditableLabel','Cauldrons to win')
local order={};for i,c in ipairs(win.parent.parent.children) do order[c]=i end
assert(order[win.parent] and order[win.parent]<order[light],'cauldrons to win above the colours')
assert(not find('WB_ComboBoxWithLabel'),'cauldron colour uses swatches, never the truncated dropdown')
local showcase=light.ShowcaseColorButton
assert(showcase.GridButton.Icon.Brush.ResourceObject==nil and showcase.GridButton.Icon.colour.R==1)
assert(showcase.GridButton.Icon.desired.X==60 and imageDefaults.Brush.ImageSize.X==32,'copy the brush, preserve native Icon size, never mutate defaults')
local radius=find('WB_SliderWithEditableLabel','Prop exclusion radius')
assert(radius.parent.width==446 and radius.parent.height==40 and radius.ValueSlider.parent.width==110)
assert(radius.InputField.parent.parent.width==140 and radius.TextFocusColor==radius.TextColor)
assert(radius.ResetButton.visibility==0 and radius.DefaultFloatValue==2500 and radius.ValueSuffix==' UU','The radius keeps its native reset arrow (user)')
local commit=path('/Game/UserInterface/UIElements/','WB_SliderWithEditableLabel','BndEvt__WB_SliderWithEditableLabel_InputField_K2Node_ComponentBoundEvent_3_OnEditableTextBoxCommittedEvent__DelegateSignature')
fire(commit,radius,'3400 UU')
assert(pot.info.radius==3400 and other.info.radius==3400 and ring.radius==3400 and ring2.radius==3400)
assert(not ring.dead and ring.visibility==true,'markerLook must not hide or recreate the selection outline')
local before=stamps;fire(commit,radius,'3400 UU');assert(stamps==before,'one edit despite native duplicate producers')
fire(path('/Game/UserInterface/UIElements/','WB_SliderWithEditableLabel','BndEvt__WB_SliderWithEditableLabel_ResetButton_K2Node_ComponentBoundEvent_1_OnButtonClickedEvent__DelegateSignature'),radius)
assert(pot.info.radius==2500 and radius.ResetButton.visibility==1,'The reset arrow restores the default radius')
fire(commit,radius,'3400 UU');before=stamps
fire(commit,radius,'invalid');assert(stamps==before and radius.RealValue==3400)
fire(commit,radius,'10001');assert(radius.RealValue==10000 and ring.radius==10000,'retain pre-rework input clamping')
fire(commit,radius,'3400')
local pink
for _,w in ipairs(objects) do if w.tooltip=='Pink' then pink=w end end
fire(path(edit..'TileAndListviews/','WB_LightColorButton','Clicked'),pink)
assert(pot.info.colour.G==.2 and other.info.colour.G==.2)
assert(not find('WB_TabButton','Auto'),'no Auto button (user 11-20)')
-- Any colour: the panel announces its colour (a colour window, Creative Tools', sets it for every selected one).
local place=places[#places];assert(place and place.widget==showcase and place.title=='Fill a Pot cauldron colour')
place.set({R=.1,G=.6,B=.3});assert(pot.info.colour.G==.6 and other.info.colour.G==.6)
local now=place.get();assert(now.G==.6)
session.role='client';before=stamps;fire(commit,radius,'8000');assert(stamps==before,'guests cannot author host markers')
session.role='host'
local header={TargetActor=pot,TargetName=node('TextBlock'),IsHeader=true,OwningCreativePlayerController=pc}
fire(path(edit..'Tabs/','WB_TargetActorDisplay','UpdateName'),header)
assert(header.TargetName.text=='Fill a Pot cauldron (2)','reuse the native header with the marker name and selection count')
open();before=stamps;fire(commit,radius,'9000');assert(stamps==before,'detached controls lose their actions when the selection panel rebuilds')
assert(#parent.children==2,'reopen replaces the old panel')
session.gs.IsPlayTestMode=true
session.is_playtest=true;for _,fn in ipairs(playtestFns) do fn(session) end;frame()
assert(ring.dead and ring2.dead)
assert(#parent.children==1,'playtest removes the Creative property block')
session.gs.IsPlayTestMode=false;session.is_playtest=false;for _,fn in ipairs(playtestFns) do fn(session) end;frame()
assert(spheres(pot)[1].radius==3400)
pc.SelectedActors={};pcEvent('DeselectMultipleActors');assert(#spheres(pot)==0 and #spheres(other)==0)
open();assert(#parent.children==1,'no custom panel for an empty selection')
local out={value={},get=function(self) return self.value end,set=function(self,v) self.value=v end}
local flags={value={},get=out.get,set=out.set}
local palette={SelectedPropCategory=6,CurrentCategoryPropsCount=0,TileViewManager={GetPropButtonData=function(_,_,_,_,_,_,_,result) result.Data=node('data') end},
    IsPropOrStructureInCategory=function(_,_,out) out.IsInCategory=true end,
    SearchBar={TextField={GetText=function() return {ToString=function() return '' end} end}}}
fire(path(S.CR,'WB_PropCollectionWidgetCreative','GetStructureTileViewDatas'),palette,out,flags)
local tile=node('tile');tile.GridButton=node('grid');tile.GridButton.Icon=node('Image')
local tree=node('/Script/UMG.WidgetTree');tree.outer=tile;tile.GridButton.outer=tree
local setup=path('/Game/UserInterface/UIElements/MenuTileView/','WB_TileViewButton','SetButtonParameters')
local async=path('/Game/UserInterface/UIElements/','WB_GridButton','SetIconImage')
for kind,item in ipairs(out.value) do
    tile.ItemData=item;fire(setup,tile)
    assert(tile.GridButton.Icon.texture:find(kind==1 and 'BP_WitchCauldron_C' or 'CollectionUtilityIconWitchStart',1,true))
    assert(tile.GridButton.Icon.colour.R==(kind==3 and 0 or 1))
    tile.GridButton.Icon.texture='native-carrier';fire(async,tile.GridButton)
    assert(tile.GridButton.Icon.texture~='native-carrier','async native loading must preserve the restored brush')
end
tile.ItemData=node('ordinary');fire(setup,tile);tile.GridButton.Icon.texture='ordinary';fire(async,tile.GridButton)
assert(tile.GridButton.Icon.texture=='ordinary','recycled tiles must stop painting FAP icons')
tile.ItemData=out.value[2];fire(setup,tile)
local recycled=node('grid');recycled.id=tile.GridButton.id;recycled.Icon=node('Image')
local light=node('tile');light.ItemData=node('light-data')
local lightTree=node('/Script/UMG.WidgetTree');lightTree.outer=light;recycled.outer=lightTree;light.GridButton=recycled
tile.ItemData=nil;tile.dead=true
recycled.Icon.texture='light-swatch';fire(async,recycled)
assert(recycled.Icon.texture=='light-swatch','a reused grid address belongs to its current native widget tree')
local pending,spawned={},0
R.native.on_asset=function(path,ready)
    local load={path=path,ready=ready};pending[#pending+1]=load
    return function() load.cancelled=true end
end
R.native.spawn_local=function(class,owner,position,initialize)
    assert(class=='resident-island-class');spawned=spawned+1
    local visual={SetActorEnableCollision=function() end,SetActorTickEnabled=function() end,SetReplicates=function() end,
        K2_GetComponentsByClass=function() return {} end,
        K2_AttachToActor=function(self,parent) self.parent=parent end,K2_DestroyActor=function(self) self.dead=true end}
    initialize(visual);return visual
end
local portal=actor(1,0);portal.info={kind='entrance',look=1,pairId=1,twoWay=false,colour=palette6[1]}
MM.look(portal,portal.info);frame()
assert(spawned==0,'cold portal class must finish loading before spawning')
portal.info.look=0;MM.look(portal,portal.info);frame()
assert(pending[1].cancelled,'changing the look cancels its unfinished asset callback')
portal.info.look=1;MM.look(portal,portal.info);frame()
pending[2].ready('resident-island-class');assert(spawned==1)
for _,fn in ipairs(events.actor_end) do fn(portal) end
assert(pending[2].cancelled,'marker EndPlay releases its asset callback')
session.mode='vanilla';pc.SelectedActors={pot};pcEvent('SelectActor');assert(#spheres(pot)==0)
for _,fn in ipairs(events.world_end) do fn() end
print('PASS pre-rework Creative swatches/rows, silent paint, multi-edit, colour place, radius rings, playtest/deselection, palette brushes/tints, async load and pooled-tile release')
