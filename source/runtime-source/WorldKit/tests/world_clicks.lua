-- Clicks in the level for editors (no shield, no mouse lock): the game's click goes to an editor
-- that claims it at the press, held until the release; any other click is the game's.
local pre, ends = {}, nil
local down = false
local R = {codes={LEFT_MOUSE=1,RIGHT_MOUSE=2,SHIFT=16,CTRL=17,ALT=18,ENTER=13,ESCAPE=27,DELETE=46},pre = function(path, fn) pre[path:match('_(%d+)$')] = fn end, on = function(e, f) if e == 'world_end' then ends = f end end,
    native = {key_down = function(code) return code == 1 and down end}}
local K = {valid = function(o) return o ~= nil end, M = {}}
dofile('candidate/runtime-source/WorldKit/mouse.lua')(R, {CREATIVE_PC = '/Game/Blueprints/Gamemodes/CreativeMode/B_CreativePlayerController.B_CreativePlayerController_C'}, K)
local wanted = false
K.claimWorld(function() return wanted end)
local function press() down = true; return pre['7']() end
local function release() down = false; return pre['8']() end
assert(press() == nil and not K.worldPressed() and release() == nil, 'nothing armed: the click is the game\'s')
wanted = true
assert(press() == true and K.worldPressed(), 'an editor that claims it takes the press')
wanted = false
assert(release() == true and not K.worldPressed(), 'and its release, also when it stopped claiming meanwhile')
wanted = true
assert(press() == true);ends();assert(not K.worldPressed(), 'a new level lets go')
-- The game sends no release (the brush painting, live VM2 11-20): let go on the mouse itself is let go.
ends();wanted = true;assert(press() == true and K.worldPressed());down = false
assert(not K.worldPressed(), 'the button up on the mouse: not pressed, with no release from the game')
-- A press over a window (blocked) whose release never comes: the next press is a new one and the
-- game's (live 11-20 every later click in the level was swallowed: nothing could be placed).
ends();wanted = false
local over = true
K.blockWorld(function() return over end)
local clock = os.clock
local now = 0;os.clock = function() return now end
assert(press() == true, 'a press over a window is no one\'s in the level');down = false
over = false;now = 1
assert(press() == nil, 'the next press, its release missed, is the game\'s again')
os.clock = clock
print('PASS clicks in the level: claimed at the press until the release, else the game\'s')
