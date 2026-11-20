local before,after
function RegisterBeginPlayPreHook(fn)before=fn end
function RegisterBeginPlayPostHook(fn)after=fn end
local options={CustomMapSelected=false,IsCreativeMode=true,MapData={builtin=true,file='Featured'}}
function StaticFindObject()return {GetGameInstance=function()return {UsedMatchOptions=options}end}end
local session={is_vanilla_session=false}
local S={R={valid=function(v)return v end,on=function()end},C={session=function()return session end},F={builtin='builtin',file='file'},text=function(v)return v end}
dofile('candidate/runtime-source/FillAPotPlus/featured.lua')(S)
local function actor(class)return {Role=3,EnablePropLayouts=true,GetClass=function()return {GetFName=function()return {ToString=function()return class end}end}end}end
local picker=actor('B_RandomPropLayoutPicker_C')
before(picker);assert(picker.Role==1) -- native authority-only cleanup is bypassed here.
local nested=actor('B_RandomPropLayoutPicker_C');before(nested);after(nested);assert(nested.Role==3)
after(picker);assert(picker.Role==3)
local gm=actor('B_CreativeGameMode_C');before(gm);assert(not gm.EnablePropLayouts)
options.MapData.builtin=false;options.MapData.file='/Game/Maps/GameMaps/UserMaps/Stronghold'
before(picker);assert(picker.Role==1);after(picker);assert(picker.Role==3)
for _,disable in ipairs({function()session.is_vanilla_session=true end,function()session.is_vanilla_session=nil end,
 function()options.CustomMapSelected=true end,function()options.IsCreativeMode=false end,
 function()options.MapData.file='/Game/Maps/Other' end})do
 session.is_vanilla_session=false;options.CustomMapSelected=false;options.IsCreativeMode=true
 options.MapData.file='/Game/Maps/GameMaps/UserMaps/Stronghold'
 disable();before(picker);assert(picker.Role==3);after(picker);assert(picker.Role==3)
 gm.EnablePropLayouts=true;before(gm);assert(gm.EnablePropLayouts)
end
session.is_vanilla_session=false;options.MapData.builtin=true
before(picker);assert(picker.Role==1);after(picker);assert(picker.Role==3)
print('PASS Featured-world props use the non-vanilla session decision before Creative state discovery, with native role restored')
