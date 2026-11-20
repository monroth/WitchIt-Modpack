-- Core's rules: declared once, values checked, the host's edits in force from the next match (live
-- ones at once), sent to guests, a guest's own rules apart, sections for files and codes.
local events,watched,published,owners,memory={},{},{},{},{}
local session={role='host',gm={IsLiveRuleEditingAllowed=false}}
local R={log=function() end,on=function(e,fn) events[e]=fn end,save_settings=function() end,valid=function(v) return v end}
local C={session=function() return session end,
 mods={config={}},
 memory={on=function() return true end,register=function(id,o) memory[id]=o end},
 saved_rules={register=function(id,o) owners[id]=o end},
 net={publish=function(t,v) published[t]=v end,watch=function(t,fn) watched[t]=fn end},
 on_session=function(fn) events.session=fn end}
C.state=C.state or function() end
local B=dofile('candidate/runtime-source/Core/rulebook.lua')(R,C)
B.declare('Mod',{
 {key='on',label='On',kind='bool',initial=false},
 {key='n',label='N',kind='number',min=0,max=10,step=1,integer=true,initial=3},
 {key='fast',label='Fast',kind='number',min=0,max=5,step=.5,initial=1,live=true},
 {key='lives',label='Lives',kind='number',min=1,max=10,step=1,integer=true,initial=4,infinite=true},
 {key='order',label='Order',kind='text',initial='a,b',valid=function(v) return v=='a,b' or v=='b,a' end}})
assert(owners.Mod and memory.Mod,'Registered for rules files and per-mode memory')
assert(not pcall(B.declare,'Mod',{}),'Declared once')
assert(not pcall(B.set,'Mod','n',11) and not pcall(B.set,'Mod','n',2.5) and not pcall(B.set,'Mod','order','c'),'Values checked')
B.set('Mod','n',7);assert(B.shown('Mod','n')==7 and B.get('Mod','n')==3,'An edit waits for the next match')
B.set('Mod','fast',2);assert(B.get('Mod','fast')==2,'A live rule applies at once')
B.set('Mod','lives','infinite');assert(B.shown('Mod','lives')=='infinite')
events.match_start();assert(B.get('Mod','n')==7,'The match starts with the edits')
assert(published['core.rules'].Mod.n==7,'Guests get the rules in force')
session.gm.IsLiveRuleEditingAllowed=true;B.set('Mod','n',5);assert(B.get('Mod','n')==5,'Live rule editing: at once')
local section=owners.Mod.save();assert(section.n==5 and section.on==nil,'A section holds the changed values')
owners.Mod.load({n=2,bogus=1,on='x'});assert(B.shown('Mod','n')==2 and B.shown('Mod','on')==false,'Loading keeps acceptable values only')
owners.Mod.load(nil);assert(B.shown('Mod','n')==3,'Nothing loaded: defaults')
-- A guest: the host's rules, or their own in "My rules".
session={role='client'}
watched['core.rules']({Mod={n=9,on=true},Other={x=1}})
assert(B.get('Mod','n')==9 and B.shown('Mod','n')==9 and not B.editable(),'A guest sees and plays the host\'s rules')
assert(not pcall(B.set,'Mod','n',1),'A guest changes nothing of the match')
B.mine(true);assert(B.editable() and B.shown('Mod','n')==3,'Their own rules start at the defaults')
B.set('Mod','n',4);assert(B.shown('Mod','n')==4 and B.get('Mod','n')==9 and owners.Mod.save().n==4,'Their own rules stay theirs')
B.set('Mod','on',true);B.reset('skill:5');assert(B.shown('Mod','n')==4 and B.shown('Mod','on')==true,'A page\'s reset leaves other pages\' rules')
B.reset();assert(B.shown('Mod','n')==3 and B.shown('Mod','on')==false and B.get('Mod','n')==9,'Reset all: their own rules back to the defaults, the match\'s untouched')
B.mine(false);B.reset();assert(B.get('Mod','n')==9,'A guest\'s reset in the match\'s view changes nothing')
print('PASS Core rules: declare, check, next match and live, guests, own rules, sections, resets')
