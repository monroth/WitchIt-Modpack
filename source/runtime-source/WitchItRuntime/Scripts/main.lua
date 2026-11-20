local scripts=debug.getinfo(1,'S').source:match('^@(.+[\\/])')
local mods=scripts..'../../'
ExecuteInGameThreadAfterFrames(1,function()
    local R=dofile(scripts..'runtime.lua')()
    -- The packages: every folder with a package.lua and a manifest.lua. Core and UIKit first, then
    -- in the order their needs allow (order.lua).
    local found={}
    for _,name in ipairs(R.native.file_list(mods)) do
        local package=io.open(mods..name..'/package.lua','rb')
        if package then
            package:close()
            local ok,manifest=pcall(dofile,mods..name..'/manifest.lua')
            if ok and type(manifest)=='table' then found[name]=manifest end
        end
    end
    -- Safe mode (Core's setting): only Core and UIKit, so the game starts whatever a mod does.
    local safe=R.settings('Core',{}).safe_mode==true   -- (the runtime's settings reader: one path)
    R.manifests=found
    local order,skipped=dofile(scripts..'order.lua')(found,{'Core','UIKit'})
    if safe then order={};R.log('WitchItRuntime','Safe mode: only Core and UIKit') end
    for id,why in pairs(skipped) do R.log('WitchItRuntime','Not loaded %s: %s',id,why) end
    R.package_ids={'Core','UIKit'}
    for _,id in ipairs(order) do R.package_ids[#R.package_ids+1]=id end
    R.packages={}
    local function load_package(id,...)
        R.prepare_directory(id)
        local result=dofile(mods..id..'/package.lua')(...)
        R.packages[id]=result
        R.log('WitchItRuntime','Loaded %s',id);return result
    end
    -- The start goes in slices of about 10 ms a frame, one right after another: the game keeps
    -- drawing its title screen, with a line in its corner that tells how far it is.
    R.hooks_later(true)
    local C,U,label
    local loaded,spin=0,0
    local function work()
        if loaded<#R.package_ids then
            loaded=loaded+1
            local id=R.package_ids[loaded]
            if id=='Core' then C=load_package('Core',R)
            elseif id=='UIKit' then U=load_package('UIKit',R,C)
            else R.call(load_package,id,R,C,U) end
            return true
        end
        return R.install_next()
    end
    local function show()
        if not (U and U.label) then return end
        -- The start crosses from the game's first world to its title screen: the line goes with
        -- the world and comes back in the next one.
        if label and not R.valid(label.text) then label=nil end
        if not label then
            local pc=R.valid(FindFirstOf('PlayerController'))
            if not pc then return end
            label=U.label(pc,{anchor={x=0,y=1},pos={X=24,Y=-24},size=14,z=990})
        end
        local left=#R.package_ids-loaded+R.hooks_waiting()
        local all=#R.package_ids+R.installs_total()
        local share=math.floor((all-left)/math.max(all,1)*20+.5)
        spin=spin%4+1
        label.set(('Witch It+  loading mods  [%s%s]  %s'):format(('#'):rep(share),('.'):rep(20-share),({'|','/','-','\\'})[spin]))
    end
    local function slice()
        local t=os.clock()
        repeat
            if not work() then
                R.hooks_later(false)
                if label and R.valid(label.widget) then label.remove() end
                R.log('WitchItRuntime','Started')
                return
            end
        until os.clock()-t>.010
        R.call(show)
        ExecuteInGameThreadAfterFrames(1,slice)
    end
    slice()
end)
