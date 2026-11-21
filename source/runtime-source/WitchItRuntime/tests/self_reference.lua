-- No mod defines a local with an expression whose functions use that same name: inside its own
-- definition the name is still the global (nil), so the function fails when it runs (Creative Tools'
-- group undo, 11-10..11-19: "attempt to index a nil value (global 'GR')"). Declare it first.
local files = io.popen('find candidate/runtime-source candidate/anium -name "*.lua" -not -path "*/tests/*"')
local found = {}
for path in files:lines() do
    local text = io.open(path):read('a'):gsub('%-%-[^\n]*', '')
    for name, rest in text:gmatch('local%s+([%a_][%w_]*)%s*=%s*()') do
        local i, depth = rest, 0
        while i <= #text do
            local c = text:sub(i, i)
            if c == '(' or c == '{' or c == '[' then depth = depth + 1
            elseif c == ')' or c == '}' or c == ']' then depth = depth - 1
            elseif c == '\n' and depth <= 0 then break end
            i = i + 1
        end
        local expr = text:sub(rest, i)
        if expr:find('function', 1, true) and (' ' .. expr):find('[^%w_.]' .. name .. '%s*[.:%[]') then
            found[#found + 1] = path .. ': ' .. name
        end
    end
end
files:close()
assert(#found == 0, 'a local used inside its own definition (declare it first): ' .. table.concat(found, ', '))
print('PASS no local is used inside its own definition')
