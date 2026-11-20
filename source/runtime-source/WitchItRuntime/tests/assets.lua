local calls,complete={},nil
local resident,loaded={},{}
function StaticFindObject(path) return path=='/Script/UMG.Image' and resident or nil end
function WitchItNativePrimitives()
    return function(op,...)
        calls[#calls+1]={op,...}
        if op=='await_asset' then local args={...};complete=args[2] end
        if op=='load_asset' or op=='load_class' then return loaded end
        return 12
    end
end
local N=dofile('candidate/runtime-source/WitchItRuntime/Scripts/native.lua')({valid=function(v) return v end})
assert(N.load_asset('/Script/UMG.Image')==resident and #calls==0)
assert(N.load_asset('/Game/ColdAsset')==loaded and calls[1][1]=='load_asset')
N.spawn('/Game/ColdClass',{},{});
assert(calls[2][1]=='load_class' and calls[3][1]=='spawn' and calls[3][2]==loaded)
local received
local cancel=N.on_asset('/Game/PreviewSkin',function(asset) received=asset end)
assert(calls[4][1]=='await_asset' and received==nil)
complete(loaded);assert(received==loaded)
cancel();assert(calls[5][1]=='cancel' and calls[5][2]==12)
print('PASS resident lookup, direct cold loads/spawns and optional async skin completion')
