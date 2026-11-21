return function()
    local F={}
    local windows=package.config:sub(1,1)=='\\'
    -- In the game the native part lists and makes folders: a shell would open a cmd window.
    -- (Tests run outside the game, on Linux, with a shell.)
    local function shell(s) return "'"..s:gsub("'","'\\''").."'" end
    function F.read(path)
        local f,why,code=io.open(path,'rb')
        if not f then if code==2 then return nil end;return nil,why end
        local bytes=assert(f:read('*a'))
        assert(f:close())
        return bytes
    end
    -- Startup only: prepare known save directories before any UI callbacks can write.
    function F.mkdir(path)
        local probe=path..'/.directory.tmp'
        local f,why,code=io.open(probe,'wb')
        if not f then
            if code~=2 then return nil,why end
            if windows then WitchItNativeFiles('mkdir',path) else assert(os.execute('mkdir -p -- '..shell(path))) end
            f,why=io.open(probe,'wb');if not f then return nil,why end
        end
        assert(f:close());return os.remove(probe)
    end
    function F.write(path,bytes)
        local temporary=path..'.tmp'
        local f,why=io.open(temporary,'wb');if not f then return nil,why end
        assert(f:write(bytes))
        assert(f:flush())
        assert(f:close())
        -- Bundled Lua uses MoveFileExA(REPLACE_EXISTING | WRITE_THROUGH) on Windows.
        return os.rename(temporary,path)
    end
    function F.remove(path) return os.remove(path) end
    function F.list(path)
        local bytes
        if windows then bytes=WitchItNativeFiles('list',path) else
            local pipe=assert(io.popen('if [ -d '..shell(path)..' ]; then find '..shell(path).." -mindepth 1 -maxdepth 1 -printf '%f\\0'; fi"))
            bytes=pipe:read('*a');pipe:close()
        end
        local result={}
        for name in bytes:gmatch(windows and '[^\n]+' or '[^%z]+') do result[#result+1]=name end
        table.sort(result);return result
    end
    return F
end
