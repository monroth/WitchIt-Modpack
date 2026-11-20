-- No mod names a local after a Lua built-in: further down in that file the built-in is the local
-- (11-17: UIKit's server list called its own select(state, data) for select(2, ...) and stopped).
local BUILTINS = {}
for _, name in ipairs({'select', 'type', 'pairs', 'ipairs', 'next', 'tostring', 'tonumber', 'print', 'error',
    'assert', 'pcall', 'xpcall', 'load', 'loadfile', 'dofile', 'require', 'rawget', 'rawset', 'rawequal', 'rawlen',
    'setmetatable', 'getmetatable', 'unpack', 'string', 'table', 'math', 'io', 'os', 'coroutine', 'utf8', 'debug'}) do
    BUILTINS[name] = true
end
local found = {}
local files = io.popen('find candidate/runtime-source candidate/anium -name "*.lua" -not -path "*/tests/*"')
for path in files:lines() do
    local n = 0
    for line in io.lines(path) do
        n = n + 1
        local code = line:gsub('%-%-.*$', '')
        local names = code:match('^%s*local%s+function%s+([%w_]+)') or code:match('^%s*local%s+([%w_,%s]+)=')
        for name in (names or ''):gmatch('[%w_]+') do
            if BUILTINS[name] then found[#found + 1] = path .. ':' .. n .. ': local ' .. name end
        end
    end
end
files:close()
assert(#found == 0, 'locals named after Lua built-ins:\n' .. table.concat(found, '\n'))
print('PASS no local shadows a Lua built-in')
