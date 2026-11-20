-- Editor tweaks: the hide tool in Creative (the host, outside Playtest) over World edits: aim at
-- scenery and hide it (aim.lua, pick.lua), a window with the nearby and the hidden objects
-- (hide_window.lua).
local dir=debug.getinfo(1,'S').source:match('^@(.+[\\/])')
return function(R,C,U)
    local E=assert(R.packages.BaseWorldPlus,'Editor tweaks needs World edits')
    local W=assert(R.packages.WindowKit,'Editor tweaks needs WindowKit')
    local K=assert(R.packages.WorldKit,'Editor tweaks needs WorldKit')
    local Objects=E.Objects
    -- Every hide or show is a step of the one undo (WorldKit's, with the other editors' steps):
    -- undo shows or hides again what that step changed.
    local steps=0
    local function hide(rows,hidden)
        local s=E.ensure_edit()
        if not s then return end
        local changed={}
        for _,row in ipairs(rows) do if (s.data.hidden[E.key(row)]~=nil)~=hidden then changed[#changed+1]=row end end
        if #changed==0 then return end
        steps=steps+1
        K.undo.add('hidden '..steps,function() return function() E.edit_group(changed,not hidden) end end,hidden and 'hide' or 'show')
        E.edit_group(changed,hidden)
    end
    local function undo() K.undo.last(C.session().pc) end
    -- The World edits API with these edits and undo, for the aim and the window.
    local api=setmetatable({edit=function(row,hidden) hide({row},hidden) end,edit_group=hide,undo=undo},{__index=E})
    local Pick=dofile(dir..'pick.lua')(R,Objects,E.Instances)
    E.on_change(Pick.changed)
    local aim=dofile(dir..'aim.lua')(R,Objects,api,Pick)
    dofile(dir..'hide_window.lua')(W,C,Objects,api,aim)
    R.key('bwp.select','Home',aim.toggle,{label='Hide tool aim',tip='Hide tool: aim on/off',context='Creative'})
    R.key('bwp.hide','Insert',aim.hide,{label='Hide aimed object',tip='Hide tool: hide the aimed object',context='Creative'})
    R.key('bwp.undo','PageUp',aim.undo,{label='Hide tool undo',tip='Hide tool: undo the last change (any editor\'s)',context='Creative'})
    R.on('world_end',function() aim.reset();E.Instances.clear() end)
    return api
end
