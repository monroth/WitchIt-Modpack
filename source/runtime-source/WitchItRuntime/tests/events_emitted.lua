-- Every runtime event a mod listens to (R.on('name')) is emitted somewhere: a listener of an event
-- nothing sends never runs (11-19: WorldKit listened to actor_begin after its emit was reverted).
local files = io.popen('find candidate/runtime-source candidate/anium -name "*.lua" -not -path "*/tests/*"')
local heard, sent = {}, {}
for path in files:lines() do
    local text = io.open(path):read('a')
    for name in text:gmatch("R%.on%(%s*['\"]([%w_]+)['\"]") do heard[name] = heard[name] or path end
    for name in text:gmatch("emit%(%s*['\"]([%w_]+)['\"]") do sent[name] = true end
    -- (the runtime also emits from a table of game functions to event names: {K2_PostLogin='player_joined'})
    if path:find('WitchItRuntime/Scripts/runtime.lua', 1, true) then
        for name in text:gmatch("[%w_]+%s*=%s*'([%l_]+)'") do sent[name] = true end
    end
end
files:close()
local missing = {}
for name, path in pairs(heard) do if not sent[name] then missing[#missing + 1] = name .. ' (' .. path .. ')' end end
table.sort(missing)
assert(#missing == 0, 'listened to but never emitted: ' .. table.concat(missing, ', '))
print('PASS every event listened to is emitted')
