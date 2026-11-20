local function strict(values)
    return setmetatable(values, {__index=function(_,key) error('Undeclared shared API: '..key) end})
end
local hooks={}
local R=strict({codes={LEFT_MOUSE=1,RIGHT_MOUSE=2,SHIFT=16,CTRL=17,ALT=18,ENTER=13,ESCAPE=27,DELETE=46},pre=function(path,fn) hooks[path]=fn end,post=function(path,fn) hooks[path]=fn end,
    on=function() end,key=function() end,valid=function(value) return value~=nil end,find_all=function() return {} end,
    settings=function(_,defaults) return defaults end,native={on_save=function() end,on_input=function() end},json={},
    options=function() end,save_settings=function() end,picture=function() return {} end})
local V=dofile('candidate/runtime-source/WitchItRuntime/Scripts/values.lua');R.values,R.text=V.values,V.text
local C=strict({HOST_WIDGET='/Game/UserInterface/Information/WB_EarlyVersionWatermark.WB_EarlyVersionWatermark_C',PIXEL_FONT='/Game/UserInterface/Fonts/PixelFont.PixelFont',mods={on_change=function()end},memory={on=function() return true end,set=function() end},on_session=function() end,catalog={view={},dimmed=function() end},
    rules={on_change=function() end,on_declare=function() end,editable=function() return true end,specs=function() return {} end,packages=function() return {} end,shown=function() end,set=function() end}})
local U=dofile('candidate/runtime-source/UIKit/package.lua')(R,C)
for _, name in ipairs({'text','section','scroll','button','checkbox','slider','combo',
    'remove','input','row','navigate','menu_entry','rules_tab','rules_view','open_rules','message','question','flow','fill','place_after','label','error_line','rule_rows','match_column','match_rows','colour_place','on_colour_place','colour_changed','on_colour_change','on_press','on_any_press','under'}) do assert(type(U[name])=='function',name) end
local count=0; for _ in pairs(U) do count=count+1 end
assert(type(U.parts)=='table' and count==33,'UIKit exports only ARCH.md helpers')
assert(next(hooks),'bootstrap registers event-driven hooks')
print('UIKit fixed-API bootstrap passed')
