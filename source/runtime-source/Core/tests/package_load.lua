-- Load every gameplay package whole, in its real module order, against a permissive
-- engine stand-in. Catches registrations of functions that are defined later
-- (C.scoped rejects them) and other load-order mistakes no module test can see.
local root='candidate/runtime-source/'
local function stand_in()
    return setmetatable({},{
        __index=function(_,key) if type(key)=='string' then return stand_in() end end,
        __call=function() return stand_in() end,
        __concat=function(a,b) return tostring(a)..tostring(b) end,
        __tostring=function() return 'stand-in' end})
end
StaticFindObject=function() return stand_in() end
FName=function(v) return v end
FText=function(v) return v end
RegisterConsoleCommandHandler=function() end
RegisterBeginPlayPreHook=function() end
RegisterBeginPlayPostHook=function() end
RegisterEndPlayPreHook=function() end
local hooks=0
local settings={}
local R={packages={WindowKit=stand_in()},package_ids={'Core','UIKit','WindowKit','EffectKit','FillAPotPlus','MatchRulesPlusPlus','BaseWorldPlus','PrivateCosmetics'},json=dofile(root..'WitchItRuntime/Scripts/json.lua'),base64=dofile(root..'WitchItRuntime/Scripts/base64.lua'),native=stand_in(),saved_root='/saved/'}
function R.pre(_,fn) assert(type(fn)=='function');hooks=hooks+1 end
function R.observe(_,fn) assert(type(fn)=='function');hooks=hooks+1 end
function R.post(_,fn) assert(type(fn)=='function');hooks=hooks+1 end
function R.on(_,fn) assert(type(fn)=='function') end
function R.key(_,_,fn) assert(type(fn)=='function') end
function R.settings(pkg,defaults)
    if not settings[pkg] then settings[pkg]={};for k,v in pairs(defaults or {}) do settings[pkg][k]=v end end
    return settings[pkg]
end
function R.save_settings() end
function R.prepare_directory() end
function R.valid(v) return v end
function R.log() end
function R.after() return function() end end
function R.next_frame() return function() end end
function R.find_all() return {} end
R.native.load_asset=function() return stand_in() end
R.native.on_asset=function() return function() end end
R.native.on_save=function() end
R.native.on_load=function() end
R.native.file_read=function() end
local session={role='offline',mode='none',is_vanilla_session=true}
local C={report=dofile('candidate/runtime-source/Core/report.lua')({native={}}),session=function() return session end,on_playtest=function()end,on_session=function(fn) fn(session) end,
    memory={shown_by=function() end,on=function() return true end,register=function() end},
    files={read_json=function() end,write_json=function() return true end,list=function() return {} end,saved_root=function(p) return '/saved/'..p end},
    net={watch=function() end,publish=function() end,on_request=function() end,request=function() end},
    abilities={allow=function() end,register=function() end,type_of=function() return 200 end,on_register=function() end,params=function() end},
    rules={declare=function() end,get=function() end,mine=function() end,specs=function() return {} end,on_change=function() end,on_declare=function() end,shown=function() end,set=function() end,editable=function() return true end},
    map={spec=function() return {} end,module=function() end,on_load=function() end,on_read=function() end,records=function() return {} end,write=function() end,split=function(b) return b,{} end}}
dofile(root..'Core/tests/lib/scoped.lua')(R,C)
dofile(root..'Core/game.lua')(R,C)
local U=stand_in()
for _,id in ipairs({'EffectKit','WorldKit','MapMarkers','Pause','FillAPotPlus','MatchRulesPlusPlus','BaseWorldPlus'}) do
    R.packages[id]=dofile(root..id..'/package.lua')(R,C,U)
end
assert(hooks>=245,'Every package registered all of its hooks')
print('PASS Pause, Fill a Pot+, Match Rules + and World edits load whole in their real module order')
