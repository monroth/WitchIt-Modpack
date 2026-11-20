local base=arg and arg[1] or 'candidate/runtime-source/'
local hooks,files={},{}
local R={prepare_directory=function() end,pre=function() end,post=function(path,fn) hooks[path:match(':(.+)$')]=fn end}
local session={mode='none',role='offline'}
local C={files={write_json=function(rel,value) files[rel]=value end,read_json=function(rel) return files[rel] end}}
function C.scoped(applies)
    return {post=function(path,fn) R.post(path,function(...) if applies(session) then return fn(...) end end) end}
end
local rules=dofile(base..'Core/rules.lua')(R,C)
local stored,loaded='saved',{}
rules.register('Mod',{save=function() return stored end,load=function(value) loaded[#loaded+1]=value or 'defaults' end})
hooks.OnSaved({},'Fun')
assert(files['Core/rules/Fun.json'].Mod=='saved','Saving writes each mod\'s section under the native name')
hooks.SaveFileLoaded({},{ToString=function() return 'Fun' end})
assert(loaded[1]=='saved','Loading gives each mod its section')
hooks.SaveFileLoaded({},'Old')
assert(loaded[2]=='defaults','A native file with no mod rules loads the defaults')
hooks.ResetRules({})
assert(loaded[3]=='defaults','Reset loads the defaults')
files['Core/rules/Removed.json']={Gone={kept=true},Mod='old'}
hooks.SaveFileLoaded({},'Removed')
assert(loaded[4]=='old','A section of a removed mod is ignored')
hooks.OnSaved({},'Removed')
assert(files['Core/rules/Removed.json'].Gone.kept and files['Core/rules/Removed.json'].Mod=='saved','Saving over a file keeps a removed mod\'s section')
session.role='client'
hooks.OnSaved({},'Guest')
assert(not files['Core/rules/Guest.json'],'Guests do not save')
session.role='host';session.mode='vanilla'
hooks.OnSaved({},'Vanilla')
assert(not files['Core/rules/Vanilla.json'],'A vanilla session stays vanilla')
print('PASS: mods\' rules are saved and loaded beside the native rules files')
