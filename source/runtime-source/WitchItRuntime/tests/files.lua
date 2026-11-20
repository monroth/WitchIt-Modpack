-- Local storage checks: process creation is confined to startup directory preparation.
local source='candidate/runtime-source/WitchItRuntime/Scripts/files.lua'
local F=dofile(source)()
local directory=os.tmpname();assert(os.remove(directory))
local execute,popen=os.execute,io.popen
local shells=0
os.execute=function(...) shells=shells+1;return execute(...) end
assert(F.mkdir(directory));assert(shells==1)
assert(F.mkdir(directory));assert(shells==1,'Existing directories need no shell')
os.execute=function() error('Write spawned a process') end
io.popen=os.execute
local path=directory..'/settings.json'
assert(F.write(path,'first'));assert(F.write(path,'second'))
assert(F.read(path)=='second','Repeated settings saves must replace the destination')
local ok,why=F.write(directory..'/missing/preset.json','missing')
assert(not ok and why,'Missing parents must return an error without spawning a process')
os.execute,io.popen=execute,popen
assert(os.remove(path));assert(os.remove(directory))

-- The Windows branch asks the native part, never a shell.
local exists,denied=false,false
shells=0
local handle={close=function() return true end}
local env=setmetatable({package={config='\\'},
 WitchItNativeFiles=function(op,path)
  if op=='list' then return 'b.pl\na.pl\n' end
  assert(op=='mkdir' and path=='C:/Saved/presets');shells=shells+1;exists=true;return true
 end,
 io={open=function()
  if denied then return nil,'permission denied',13 end
  if not exists then return nil,'not found',2 end
  return handle
 end},
 os={execute=function() error('Windows spawned a shell') end,remove=function() return true end}}, {__index=_G})
local W=assert(loadfile(source,'t',env))()()
assert(W.mkdir('C:/Saved/presets'));assert(W.mkdir('C:/Saved/presets'));assert(shells==1)
denied=true
assert(not W.mkdir('C:/Saved/presets'));assert(shells==1,'Access errors must not launch mkdir')
assert(not W.write('C:/Saved/presets/settings.json','bytes'));assert(shells==1)
local names=W.list('C:/Saved');assert(#names==2 and names[1]=='a.pl' and names[2]=='b.pl')
print('PASS storage: startup-only mkdir, shell-free writes/errors, repeated replacement, Windows folders by the native part')
