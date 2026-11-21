-- The mods' shortcuts in the game's Key Bindings list: after the game's rows, per mod its name
-- and its shortcuts two to a line; a slot shows its keys as the game's pictures and widens for
-- several; a slot click waits for a key; a modifier let go alone is the chord; Delete empties a
-- slot; Esc leaves it; a refusal shows on its line, between the two shortcuts.
FText=function(s) return s end;FName=function(s) return s end
local hooks,pre,frames,input,capture={}, {}, {}, nil, nil
local chords,refuse,down,conflicts={},nil,{},{}
local rows={
    {id='bwp.hide',mod='Editor tweaks',label='Hide the aimed object',context='Creative',current='Insert',spare='Disabled'},
    {id='anium.group',mod='Creative Tools',label='Group the selection',tip='Groups the selected objects',context='Creative',current='G',spare='Disabled'},
    {id='anium.undo',mod='Creative Tools',label='Undo',context='Creative',current='Z',spare='Disabled'},
    {id='editor.mode',mod='Creative Tools',label='Place / edit',context='Creative',current='Tab',spare='Disabled',game=true},
}
local R={log=function() end,codes={LEFT_MOUSE=1,RIGHT_MOUSE=2,SHIFT=16,CTRL=17,ALT=18,ENTER=13,ESCAPE=27,DELETE=46},valid=function(v) return v end,
    post=function(path,fn) hooks[path]=fn end,pre=function(path,fn) pre[path]=fn end,on=function() end,
    next_frame=function(fn) frames[#frames+1]=fn end,
    native={on_input=function(fn) input=fn end,load_asset=function(p) return p end,key_down=function(code) return down[code] end},
    hotkeys=function() return rows end,
    capture_hotkey=function(fn) capture=fn;return function() if capture==fn then capture=nil end end end,
    chord=function(code,mask) if code==162 then return 'Ctrl' end;return (mask==2 and 'Ctrl+' or '')..string.char(code) end,
    chord_keys=function(chord)
        if chord=='Disabled' then return nil end
        local keys={};for part in chord:gmatch('[^+]+') do keys[#keys+1]=part=='Ctrl' and 'LeftControl' or part end;return keys
    end,
    hotkey_conflicts=function() return conflicts end,
    -- (as the runtime: the chord is set where R.hotkeys() reads it)
    set_hotkey=function(id,chord,index) if refuse then return false,refuse end;chords[#chords+1]={id,chord,index}
        for _,row in ipairs(rows) do if row.id==id then if index==1 then row.current=chord else row.spare=chord end end end
        return true end}
local function frame() local fns=frames;frames={};for _,fn in ipairs(fns) do fn() end end
local function widget(kind)
    local w={kind=kind,children={}}
    function w:SetText(t) self.text=t end
    function w:SetVisibility(v) self.visibility=v end
    w.BackgroundColor={R=1,G=1,B=1,A=1}
    function w:SetBackgroundColor(c) self.color=c end
    function w:GetAddress() return self end
    function w:IsHovered() return self.hovered end
    function w:IsVisible() return true end
    function w:GetParent() return nil end
    function w:SetContent(c) self.content=c end
    function w:SetToolTipText(t) self.tooltip=t end
    function w:SetBoundKey(k) self.key=k.KeyName end
    function w:AddChild(c) self.children[#self.children+1]=c end
    function w:ClearChildren() self.children={} end
    function w:SetWidthOverride(v) self.WidthOverride=v end
    function w:GetVisibility() return self.visibility or 0 end
    w.Slot={SetRow=function(s,r) s.Row=r end,SetColumn=function(s,c) s.Column=c end,
        SetHorizontalAlignment=function(s,v) s.h=v end,SetVerticalAlignment=function(s,v) s.v=v end,SetPadding=function(s,p) s.p=p end}
    return w
end
local grid=widget('grid')
-- The game's rows: two columns; three rows end at row 1, left.
local gameNames,gameKeys={'Jump','Crouch','Taunt 1'},{'SpaceBar','C','One'}
for i=1,3 do
    local row=widget('game row');grid.children[i]=row;row.Slot.Row=(i-1)//2;row.Slot.Column=(i-1)%2
    row.BindingName={GetText=function() return gameNames[i] end}
    row.Binding_0={icon={BoundKey={KeyName=gameKeys[i]}},Button=widget('button')};row.Binding_1={icon={BoundKey={KeyName='None'}},Button=widget('button')}
end
function widget_visibility(w) return w.visibility end
function grid:GetChildrenCount() return #self.children end
function grid:GetChildAt(i) return self.children[i+1] end
StaticConstructObject=function() return widget('parts') end
local search,kindChoice
local U={text=function(parent,o) local t=widget('text');parent:AddChild(t);t.text=o.text;t.heading=o.heading;t.note=o.note;return t end,
    input=function(parent,o) search=o;local frame=widget('frame');parent:AddChild(frame);return widget('field'),function() end,frame end,
    combo=function(parent,o) kindChoice=o;return widget('combo') end,fill=function(w) return w end}
local screens={}
local I={object=function(p) return p end,id=function(w) return w end,owner=function() return {screen={WidgetTree={}}} end,
    string=function(v) return v end,screens=screens,
    state=function(w) screens[w]=screens[w] or {screen=w};return screens[w] end,
    slot_values=function(slot) return {v=slot.v} end,slot_apply=function(slot,v) slot.v=v.v end,
    native=function(parent,kind) local made=widget(kind);parent:AddChild(made);function made:RemoveFromParent() end;return made end,
    cooked=function(parent,asset)
        local made=widget(asset);parent:AddChild(made)
        if asset=='WB_KeyBinding' then
            local line=widget('line');made.BindingName=widget('text');line:AddChild(made.BindingName)
            function made.BindingName:GetParent() return line end;made.line=line
            for i=0,1 do
                local size=widget('size');size.WidthOverride=46
                made['Binding_'..i]={Button=widget('button'),WaitForInputFrame=widget('frame'),icon=widget('icon'),WidgetTree={RootWidget=size}}
            end
        end
        return made
    end}
-- (the mods' one mouse service: a press goes to the control under the mouse)
R.call=function(f,...) return f(...) end
R.native.widget_rect=function() return {left=0,top=0,right=10,bottom=10} end
dofile('candidate/runtime-source/UIKit/mouse.lua')(R,{session=function() return {pc={}} end},U,I)
dofile('candidate/runtime-source/UIKit/keybindings.lua')(R,{},U,I)
local list={KeyBindingsGrid=grid}
hooks['/Game/UserInterface/Settings/WB_KeyBindingList.WB_KeyBindingList_C:InitializeBindingWidgets'](list)

local mine={};for i=4,#grid.children do mine[#mine+1]=grid.children[i] end
local function at(w) return w.Slot.Row..','..w.Slot.Column end
assert(mine[1].text=='Creative Tools' and mine[1].heading and at(mine[1])=='2,0','after the game\'s rows, a mod\'s name on a line of its own')
local group,undo=mine[2],mine[3]
assert(at(group)=='3,0' and at(undo)=='3,1','its shortcuts two to a line as the game\'s (user 11-20)')
assert(mine[4].text=="Game's own keys" and mine[4].note and at(mine[4])=='4,0' and at(mine[5])=='5,0',
    'the game\'s keys a mod makes rebindable: after its own shortcuts, under a small heading of their own (user 11-20)')
assert(group.BindingName.text=='Group the selection' and group.BindingName.tooltip=='Groups the selected objects\nWorks in: Creative','a short line; on hover what it does in full and where')
local key,spare=group.Binding_0,group.Binding_1
assert(key.icon.key=='G' and key.icon.visibility==3 and spare.icon.visibility==1,'its key as the game\'s key picture, an empty spare')
assert(mine[6].text=='Editor tweaks' and at(mine[6])=='6,0' and at(mine[7])=='7,0','the next mod starts a line of its own')
local function click(slot) slot.Button.hovered=true;input(1);slot.Button.hovered=false end
-- A click waits (in the game's frame); the click itself is not the key. A chord's keys show as pictures, modifiers first.
click(spare)
assert(spare.WaitForInputFrame.visibility==3 and capture==nil,'the slot waits')
frame();assert(capture,'from the next press on')
capture(71,2)
local parts=spare.Button.content
assert(chords[1][2]=='Ctrl+G' and chords[1][3]==2 and #parts.children==2 and parts.children[1].key=='LeftControl'
    and parts.children[2]==spare.icon and spare.icon.key=='G','the pressed chord: the modifier\'s picture, then the key\'s')
assert(spare.WidgetTree.RootWidget.WidthOverride==92 and spare.WaitForInputFrame.visibility==2,'the slot widens for two keys')
-- A modifier held waits for its key; let go alone, it is the chord.
click(key);frame();down[162]=true;capture(162,2);frame()
assert(#chords==1,'a held modifier waits')
down[162]=nil;frame()
assert(chords[2][2]=='Ctrl' and key.icon.key=='LeftControl' and key.WidgetTree.RootWidget.WidthOverride==46,'let go alone, the modifier is the key')
-- Delete empties a slot; Esc leaves it; a refused chord says why in the action's name.
click(spare);frame();capture(46,0)
assert(chords[3][2]=='Disabled' and spare.icon.visibility==1 and spare.WidgetTree.RootWidget.WidthOverride==46,'Delete empties it')
click(spare);frame();capture(27,0)
assert(#chords==3 and capture==nil and spare.WaitForInputFrame.visibility==2,'Esc leaves it as it was')
-- A key the game uses, or another shortcut's: allowed, both slots red; apart again, not red.
click(key);frame();capture(67,0)
assert(key.icon.key=='C' and key.Button.color.G<.5 and grid.children[2].Binding_0.Button.color.G<.5,'the game\'s Crouch key: both red')
conflicts={['anium.undo']={[1]=true}};click(key);frame();capture(71,0)
assert(key.Button.color.G==1 and grid.children[2].Binding_0.Button.color.G==1 and undo.Binding_0.Button.color.G<.5,'apart from the game: back; another shortcut\'s conflict: red')
conflicts={}
refuse='F5 belongs to the game.'
click(key);frame();capture(90,0)
local message=group.line.children[2]
assert(key.icon.key=='G' and message.note and message.text=='F5 belongs to the game.','a refusal is told on its line')
local undoMessage=undo.line.children[2]
assert(#undo.line.children==2,'each shortcut its own line and message')
refuse='Choose a key.'
click(undo.Binding_0);frame();capture(71,0)
assert(undoMessage.text=='Choose a key.','another shortcut\'s refusal shows on its own line')
refuse=nil
click(key);assert(message.text=='','the next click clears it')
-- The search beside Back: matching lines close up two to a line; a mod's name above its shortcuts shown.
local screen={}
local column=widget('column');local back=widget('back');column:AddChild(back)
function back:RemoveFromParent() for i,c in ipairs(column.children) do if c==back then table.remove(column.children,i) end end end
function back:GetParent() return column end
screen.Button_Back=back
hooks['/Game/UserInterface/Settings/WB_KeyBindings.WB_KeyBindings_C:Construct'](screen)
local bar=column.children[1]
assert(bar.children[1]==back and bar.children[2].kind=='frame' and bar.children[3].kind=='SizeBox','Back, the search, then what it searches by')
local game=grid.children
search.on_change('und')
assert(game[1].visibility==2 and at(game[1])=='0,1','a hidden line holds the right column when no shown line does')
assert(game[1].visibility%3~=0 and game[2].visibility%3~=0 and game[3].visibility%3~=0,'game lines that do not match are hidden')
assert(mine[1].visibility%3==0 and at(mine[1])=='0,0' and at(undo)=='1,0' and group.visibility%3~=0 and mine[4].visibility%3~=0 and mine[6].visibility%3~=0,
    'the matching shortcut under its mod\'s name, from the top')
kindChoice.on_change('mod');search.on_change('witch')
assert(game[1].visibility%3==0 and at(game[1])=='0,0' and at(game[3])=='1,0' and mine[1].visibility%3~=0,'by mod: the game\'s own lines are Witch It\'s')
kindChoice.on_change('key');search.on_change('1')
assert(game[3].visibility%3==0 and at(game[3])=='0,0' and game[1].visibility%3~=0 and game[2].visibility%3~=0,'by key: 1 is the One key, not every name with a 1')
search.on_change('c')
assert(game[2].visibility%3==0 and game[1].visibility%3~=0,'one letter is that key')
search.on_change('')
assert(at(game[1])=='0,0' and at(game[2])=='0,1' and at(game[3])=='1,0' and at(mine[1])=='2,0' and at(undo)=='3,1' and at(mine[6])=='6,0',
    'an empty search shows every line where it was')
-- The list leaves the screen while a slot waits: nothing waits any more. The screen goes: Back returns.
frame();pre['/Script/UMG.UserWidget:Destruct'](list);assert(capture==nil,'a closed list leaves no slot waiting')
pre['/Script/UMG.UserWidget:Destruct'](screen);assert(column.children[2]==back,'Back returns to its own place')
print('UIKit key bindings passed')
