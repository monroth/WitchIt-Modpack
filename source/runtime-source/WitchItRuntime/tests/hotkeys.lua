local base='candidate/runtime-source/WitchItRuntime/Scripts/'
local settings={hotkeys={['mrpp.rules']='F10',['fap.pause']='Ctrl+Hyphen',['bwp.undo']='Disabled'}}
local input,saves=nil,0
local R={json=dofile(base..'json.lua'),native={}}
function R.call(fn,...) return fn(...) end
function R.settings(_,defaults) for k,v in pairs(defaults) do if settings[k]==nil then settings[k]=v end end;return settings end   -- (as the runtime: defaults fill what a saved file lacks)
function R.save_settings()saves=saves+1 end
function R.native.on_input(fn)input=fn end
FName=function(s) return s end
-- The keyboard: which virtual keys are down (Ctrl: either side); a text field may have the keyboard.
local down={}
function R.native.key_down(code) return down[code]==true end
local player={IsInputKeyDown=function(_,key) return down[key.KeyName]==true end}
local field={focus=false,HasKeyboardFocus=function(self) return self.focus end}
FindAllOf=function(class) if class=='EditableTextBox' then return {field} end end
local changes=0
local function install()dofile(base..'keys.lua')(R,function()return player end,function(e) if e=='hotkeys' then changes=changes+1 end end)end
install()
local called=0
dofile('candidate/runtime-source/Core/tests/lib/mods.lua')(R)
-- Each key is made by its mod: the list names the mod from its manifest.
R.test_owner='FillAPotPlus';R.key('fap.pause','F8',function()called=called+1 end,{label='Pause or resume the round timer'})
R.test_owner='MatchRulesPlusPlus';R.key('mrpp.rules','F7',function()end,{label='Open Match Rules ++'})
R.test_owner='EditorTweaks';R.key('bwp.undo','PageUp',function()error('disabled')end,{label='Hide tool: undo last hide'})
input(189,2);assert(called==1,'A saved chord wins over the default')
input(33,0) -- PageUp is disabled
assert(settings.hotkeys['mrpp.rules']=='F10' and settings.hotkeys['bwp.undo']=='Disabled')
assert(R.set_hotkey('fap.pause','F11') and saves==1)
install();assert(settings.hotkeys['fap.pause']=='F11' and saves==1,'Startup never rewrites saved hotkeys')
R.key('fap.pause','F8',function()called=called+1 end,{label='Pause or resume the round timer'})
-- The spare slot: a second chord for the same action, saved apart.
assert(R.set_hotkey('fap.pause','Ctrl+F9',2) and settings.spare['fap.pause']=='Ctrl+F9' and changes>0,'a change is told')
input(120,2);assert(called==2,'the spare chord works too')
local rows={};for _,r in ipairs(R.hotkeys()) do rows[r.id]=r end
assert(rows['fap.pause'].current=='F11' and rows['fap.pause'].spare=='Ctrl+F9')
assert(R.set_hotkey('fap.pause','Disabled',2) and settings.spare['fap.pause']==nil)
-- The same chord where the two never meet (other contexts) is allowed.
local edited=0
R.key('cto.group','G',function() edited=edited+1 end,{label='Group',context='Creative'})
R.key('imp.test','G',function() end,{label='Test panel',context='Imposturous match'})
assert(R.set_hotkey('imp.test','G'),'another context may use the same key')
-- A letter does nothing while a text field has the keyboard, and acts otherwise, in a menu too.
field.focus=true;input(71,0);assert(edited==0,'a letter typed into a text field does nothing')
field.focus=false;input(71,0);assert(edited==1,'a letter with no text field typing does the action')
down[71]=true;assert(R.key_held('cto.group'));down[71]=nil;assert(not R.key_held('cto.group'))
-- A key press as a chord: what the Key Bindings list writes, and what the shortcuts read back.
assert(R.chord(71,2)=='Ctrl+G' and R.chord(57,0)=='9' and R.chord(33,1)=='Shift+PageUp' and R.chord(189,0)=='Hyphen')
assert(R.chord(250,0)==nil,'a nameless key is no chord')
-- The mouse's side buttons are keys too (button 4 and 5).
local thumb=0;R.key('cto.thumb','ThumbMouseButton',function() thumb=thumb+1 end,{label='Thumb'})
input(5,0);assert(thumb==1 and R.chord(6,0)=='ThumbMouseButton2' and R.chord_keys('ThumbMouseButton')[1]=='ThumbMouseButton','mouse button 4 works as a key')
-- A modifier alone is a chord of its own: either side's key, whatever the mask says.
assert(R.chord(162,2)=='Ctrl' and R.chord(165,4)=='Alt')
assert(R.set_hotkey('imp.test','Alt'));local tested=0
R.key('imp.ctrl','Ctrl',function() tested=tested+1 end,{label='Ctrl test',context='Imposturous match'})
input(163,2);input(17,2);assert(tested==2,'Ctrl alone (either side) does its action')
local keys=R.chord_keys('Ctrl+Alt+G');assert(keys[1]=='LeftControl' and keys[2]=='LeftAlt' and keys[3]=='G','pictures: modifiers, then the key')
assert(R.chord_keys('Alt')[1]=='LeftAlt' and #R.chord_keys('Alt')==1 and R.chord_keys('Disabled')==nil)
down[17]=true;assert(R.key_held('imp.ctrl'),'either side counts as held');down[17]=nil
for _,code in ipairs({71,57,33,189,113,32}) do assert(R.set_hotkey('cto.group',R.chord(code,2)),'every chord reads back') end
-- Two shortcuts on one key (a frame key and its add key, both Shift): held together, a conflict shown.
R.key('cto.frame','Shift',function() end,{label='Frame'});R.key('cto.add','Shift',function() end,{label='Add'})
assert(R.hotkey_conflicts()['cto.frame'][1] and R.hotkey_conflicts()['cto.add'][1])
assert(R.set_hotkey('cto.add','V') and not R.hotkey_conflicts()['cto.add'],'no conflict once apart')
assert(R.set_hotkey('cto.add','Shift'),'a shared key is allowed')
down[16]=true;assert(R.key_held('cto.frame') and R.key_held('cto.add'));down[16]=nil
-- The game's own key made rebindable shares its default with any shortcut; moved, it conflicts as any.
R.set_hotkey('cto.add','V')
R.key('editor.group','Shift',function() end,{label='Editor: group',game=true})
assert(not R.hotkey_conflicts()['cto.frame'] and not R.hotkey_conflicts()['editor.group'],'the game\'s key on its default is shared')
assert(R.set_hotkey('editor.group','V') and R.hotkey_conflicts()['editor.group'] and R.hotkey_conflicts()['cto.add'],'moved onto a shortcut: a conflict')
print('PASS saved hotkeys win over defaults; disabled, conflict and saving rules')
