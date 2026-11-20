-- Native values as Lua values (R.values, R.text).
local V={}
-- An array's values: a TArray, or a Lua table of wrappers (results of hooked functions).
function V.values(array)
    local out={}
    if array.ForEach then array:ForEach(function(_,v) out[#out+1]=v:get() end)
    else for i,v in ipairs(array) do out[i]=(type(v)=='userdata' or type(v)=='table') and v.get and v:get() or v end end
    return out
end
-- An FString, FName or FText as a Lua string.
function V.text(v) return type(v)=='string' and v or v:ToString() end
return V
