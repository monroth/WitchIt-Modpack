local started,later
-- Missing asset completions must never hold package or hook installation.
local originalDofile=dofile
local root='candidate/runtime-source/'
local R={saved_root='/saved/',settings=function(_,d) return d end,json={decode=function() return {} end},native={on_asset=function() error('Startup must not await assets') end,
    file_read=function() return nil end,
    file_list=function() return {'BaseWorldPlus','Core','CreativeSwitches','EditorTweaks','EffectKit','FillAPotPlus','MapMarkers',
        'MatchRulesPlusPlus','Pause','PrivateCosmetics','UIKit','WindowKit','WitchItRuntime','WorldKit'} end},
    prepare_directory=function() end,log=function(_,text) if text=='Started' then started=true end end,call=function(fn,...) return fn(...) end,
    hooks_later=function(on) later=on end,install_next=function() return false end,hooks_waiting=function() return 0 end,installs_total=function() return 0 end}
local loaded,frame={},nil
function ExecuteInGameThreadAfterFrames(frames,fn) assert(frames==1);frame=fn end
function dofile(path)
    if path:match('Scripts/runtime.lua$') then return function() return R end end
    if path:match('/manifest.lua$') then return originalDofile(path) end
    if path:match('order.lua$') then return originalDofile(path) end
    local id=path:match('/([^/]+)/package.lua$')
    assert(id,path)
    return function(r,c,u)
        assert(r==R)
        if id~='Core' then assert(c=='Core') end
        if id~='Core' and id~='UIKit' then assert(u=='UIKit') end
        loaded[#loaded+1]=id;return id
    end
end
originalDofile(root..'WitchItRuntime/Scripts/main.lua')
-- The start runs in slices, frame after frame, with hooks held back until it ends.
assert(#loaded==0)
local frames=0
while frame do local f=frame;frame=nil;f();frames=frames+1;assert(frames<100) end
assert(started and later==false,'The start ends and lets hooks go in at once again')
-- Core and UIKit first; every other mod after the mods it needs (and after `after` ones), by name.
assert(loaded[1]=='Core' and loaded[2]=='UIKit' and #loaded==13,table.concat(loaded,','))
local at={};for i,id in ipairs(loaded) do at[id]=i end
for i,id in ipairs(loaded) do
    local m=originalDofile(root..id..'/manifest.lua')
    for _,need in ipairs(m.needs or {}) do assert(at[need]<i,id..' before '..need) end
    for _,other in ipairs(m.after or {}) do assert(not at[other] or at[other]<i,id..' before '..other) end
end
assert(R.manifests.FillAPotPlus.name=='Fill a Pot+','The runtime keeps every mod\'s manifest')
do local held=dofile;dofile=originalDofile;dofile(root..'Core/tests/lib/effects.lua')(R,{});dofile=held end
local modules={}
function dofile(path)
    local name=path:match('([^/]+)%.lua$')
    if name=='math' then return {} end
    if name=='codec' then return function() return {} end end
    return function(S) assert(S.R==R);modules[#modules+1]=name end
end
R.packages.MapMarkers={record=function() end,colour=originalDofile(root..'MapMarkers/colour.lua')}   -- (the loader above kept each package's name)
originalDofile(root..'FillAPotPlus/package.lua')(R,{map={module=function() end},mods={require=function() end}}, {})
assert(table.concat(modules,',')=='scope,rules,rejoin,featured,ground,abilities,possession,divination,cauldron_rules,indicator,respawn,plates,gameplay,results,maps,voting,world,preview,editor,progress,hud,events')
local document={}
modules={}
function dofile(path)
    local name=path:match('([^/]+)%.lua$')
    if name=='document' then return {new=function() return document end,roles={}} end
    if name=='catalog' or name=='policy' or name=='palette' then return {} end
    return function(r,c,u) assert(r==R);modules[#modules+1]=name end
end
R.post=R.post or function() end
assert(originalDofile(root..'PrivateCosmetics/package.lua')(R,{on_session=function() end}, {})==document)
assert(table.concat(modules,',')=='equipment,wardrobe')
dofile=originalDofile
print('PASS immediate Runtime, FAP and PrivateCosmetics startup without asset completions')
