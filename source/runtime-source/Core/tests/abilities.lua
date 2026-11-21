-- Core's allowed abilities: the host's lists are the game's own plus what mods asked; asking
-- nothing changes nothing; withdrawing gives the game's lists back; classes that load later count.
local function object(path) return {path=path,GetAddress=function(self)return self.path end,GetFullName=function(self) return 'BlueprintGeneratedClass '..self.path end,GetCDO=function(self) self.cdo=self.cdo or {} return self.cdo end} end
local function array(items)
 local rows={}
 for i,v in ipairs(items) do rows[i]=v end
 function rows:ForEach(fn) for i=1,#self do local v=self[i];fn(i,{get=function()return v end}) end end
 function rows:Empty() for i=#self,1,-1 do self[i]=nil end end
 return rows
end
local hook,chicken,train,nitro=object('Hook'),object('Chicken'),object('Train'),object('Nitro')
StaticFindObject=function() return nil end
local gs={AllowedHunterSkills=array{hook,chicken},AllowedWitchSkills=array{},UnlistedSkills=array{},updated=0,GetAddress=function()return 'gs1' end}
function gs:SkillsUpdated() self.updated=self.updated+1 end
function gs:FlushNetDormancy() self.woken=true end
function gs:ForceNetUpdate() self.sent=true end
local gm={AllowedHunterPickups=array{},AllowedWitchPickups=array{}}
local session={role='host',gs=gs,gm=gm}
local loaded={Hook=hook,Chicken=chicken,Train=train}
local waiting,events={},{}
FText=function(s) return 'text:'..s end
FindFirstOf=function() return nil end
local R={valid=function(v)return v end,log=function()end,on=function(e,fn)events[e]=fn end,post=function()end,
 native={load_asset=function(p)return loaded[p] end,on_asset=function(p,fn)waiting[p]=fn end}}
local V=dofile('candidate/runtime-source/WitchItRuntime/Scripts/values.lua');R.values,R.text=V.values,V.text
local C={state=function() end,session=function()return session end,on_session=function() end,net={publish=function() end,watch=function() end},mods={host_mode=function() end}}
dofile('candidate/runtime-source/Core/game.lua')(R,C)   -- (the subsystem paths)
local A=dofile('candidate/runtime-source/Core/abilities.lua')(R,C)
local function names() local t={} for i,v in ipairs(gs.AllowedHunterSkills) do t[i]=v.path end return table.concat(t,',') end

A.apply();assert(names()=='Hook,Chicken' and gs.updated==0,'Nothing asked: nothing changes')
A.allow('fap',{AllowedHunterSkills={'Hook','Train'}})
assert(names()=='Hook,Chicken,Train' and gs.updated==1,'The game\'s own plus the asked, each once')
local early={}
A.on_register(function(spec,kind) early[#early+1]=spec.class..':'..kind end)
A.register({class='Nitro',team='hunter',name='Nitro Hook'})
local late={}
A.on_register(function(spec,kind) late[#late+1]=spec.class..':'..kind end)
assert(early[1]=='Nitro:'..A.type_of('Nitro') and late[1]==early[1],'Every listener hears of each ability once, registered before or after')
assert(waiting.Nitro,'A class not loaded yet is waited for')
loaded.Nitro=nitro;waiting.Nitro(nitro)
assert(names()=='Hook,Chicken,Train,Nitro' and nitro.cdo.SkillName=='text:Nitro Hook','A registered ability: allowed and named once loaded')
A.allow('fap',nil)
assert(names()=='Hook,Chicken,Nitro','Withdrawn: the game\'s lists and the registered ability')
session={role='client',gs=gs};gs.updated=0;A.apply();assert(gs.updated==1 and names()=='Hook,Chicken,Nitro','A guest\'s own game sets its lists too (the game does not send them; user 11-21)')
session={role='host',gs=gs,gm=gm,mode='vanilla'};gs.updated=0;A.apply();assert(gs.updated==0,'A vanilla session keeps the game\'s own lists: no player without mods gets a mod\'s class')
print('PASS Core abilities: game lists kept, asks added once, late classes, registered names, withdraw')
