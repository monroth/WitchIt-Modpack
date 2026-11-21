-- With the Unlock abilities and power-ups rule Fill a Pot+ asks Core to allow every ability and
-- power-up (the Train included); without it, or outside the mode, it asks for nothing.
local asked='none'
local sessions
local S={R={},C={state=function() end,abilities={allow=function(owner,lists) assert(owner=='FillAPotPlus');asked=lists end},
 on_session=function(fn) sessions=fn end,rules={on_change=function() end}},editing=function()return false end,onMatch={session=function() end}}
local active=true
S.active=function()return active end
local rules={extras=false}
S.rules=function()return rules end
S.R.find_all=S.R.find_all or function() return {} end
dofile('candidate/runtime-source/Core/game.lua')(S.R,S.C)   -- (Core's ability paths)
dofile('candidate/runtime-source/FillAPotPlus/abilities.lua')(S)
S.allowSkills();assert(asked==nil,'Without the rule nothing is asked')
rules.extras=true;S.allowSkills()
assert(#asked.AllowedHunterSkills==7 and asked.AllowedHunterSkills[7]:find('B_TrainSkill'),'The Train is allowed')
assert(#asked.AllowedWitchSkills==6 and #asked.AllowedWitchPickups==4 and #asked.AllowedHunterPickups==4)
active=false;sessions();assert(asked==nil,'Outside Fill a Pot+ the ask is withdrawn')
print('PASS FAP+ unlock: asks Core for all abilities with the rule, nothing without it or outside the mode')
