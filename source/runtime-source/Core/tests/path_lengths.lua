-- Every shipped file's path from ue4ss/ stays short: the updater stages a mod under
-- ue4ss/.witchit-updater/stage/<source>~<mod>/ in the game folder, and Windows refuses paths of
-- 260 characters or more (a default Steam folder takes about 75 of them).
local longest,name=0,''
local p=io.popen("cd candidate/runtime-source && find . -type f -not -path '*/tests/*'")
for f in p:lines() do
    local path='ue4ss/Mods/'..f:gsub('^%./','')
    if #path>longest then longest,name=#path,path end
end
p:close()
assert(longest<=100,'path too long for the updater on Windows ('..longest..'): '..name)
print('PASS shipped paths at most 100 characters (longest '..longest..')')
