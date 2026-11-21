-- The runtime's mod facts for a test's own R, from the real manifests in the source tree: R.manifests,
-- R.values/R.text, R.mod_name, R.options/R.option_groups, and R.owner = the test's chosen mod (R.test_owner, default Core).
return function(R)
    local V=dofile('candidate/runtime-source/WitchItRuntime/Scripts/values.lua');R.values,R.text=V.values,V.text
    R.manifests={}
    for _,root in ipairs({'candidate/runtime-source/','candidate/anium/'}) do
        local list=io.popen('ls '..root)
        for id in list:lines() do
            local file=io.open(root..id..'/manifest.lua','rb')
            if file then file:close();R.manifests[id]=dofile(root..id..'/manifest.lua') end
        end
        list:close()
    end
    R.test_owner=R.test_owner or 'Core'
    function R.owner() return R.test_owner end
    function R.mod_name(id) local m=R.manifests[id];return m and m.name or id end
    local groups={}
    function R.options(build) groups[#groups+1]={id=R.owner(),build=build} end
    function R.option_groups() return groups end
    return R
end
