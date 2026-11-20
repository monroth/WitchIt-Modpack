-- The session mode decision: one function, every case a package scope relies on. A mod's mode is
-- the mode module that says the session plays it.
local modeOf=dofile('candidate/runtime-source/Core/mode.lua')
local function state(class)
 return {GetClass=function() return {GetFName=function() return {ToString=function() return class end} end} end}
end
local present=true
local modules={['mod.mode']={plays=function(s) return s.gs:GetClass():GetFName():ToString()=='B_ObjectiveGameState_C' end}}
local map={modes=function() return present and {'mod.mode'} or {} end,spec=function(id) return modules[id] end}
local objective=state('B_ObjectiveGameState_C')
local function session(fields)
 local s={role='host',is_vanilla_session=false,is_creative=false,gs=objective,mode_id='B_ObjectiveGameMode_C'}
 for k,v in pairs(fields) do s[k]=v end
 return s
end
-- Host of a modded server.
assert(modeOf(session{},map)=='mod.mode','A mode module plays the session it says it plays')
assert(modeOf(session{gs=state('B_GameState_C'),mode_id='B_HideAndSeekGameMode_C'},map)=='B_HideAndSeekGameMode_C',
 'A match the module does not play is the native mode')
present=false
assert(modeOf(session{},map)=='B_ObjectiveGameMode_C','A module that is not there is no mode')
present=true
-- Vanilla server always wins, for every role except offline menus.
for _,role in ipairs({'host','client'}) do
 assert(modeOf(session{role=role,is_vanilla_session=true},map,'mod.mode')=='vanilla','A vanilla session overrides any mode or host publication')
end
-- Creative.
assert(modeOf(session{is_creative=true,gs=state('B_CreativeGameState_C')},map)=='creative','Modded Creative enables the editor tools')
assert(modeOf(session{role='offline',is_creative=true,is_vanilla_session=true},map)=='vanilla','Offline Creative respects the session decision')
assert(modeOf(session{role='offline',is_creative=true,is_vanilla_session=false},map)=='creative')
-- Clients follow the host's publication; before it arrives they assume vanilla.
assert(modeOf(session{role='client'},map)=='vanilla','Guests wait for the host publication')
assert(modeOf(session{role='client'},map,'mod.mode')=='mod.mode','Guests follow the host')
assert(modeOf(session{role='client'},map,'B_ObjectiveGameMode_C')=='B_ObjectiveGameMode_C')
-- Menus outside a match.
assert(modeOf(session{role='offline'},map)=='none','The main menu is in no mode')
print('PASS session mode: a mod mode by the module\'s word, vanilla wins, Creative tools, guests follow the host')
