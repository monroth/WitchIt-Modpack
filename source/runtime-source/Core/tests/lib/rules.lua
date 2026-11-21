-- Core's rules for a test's mocks: the real service, with what it needs filled in when missing.
return function(R, C)
    C.saved_rules = C.saved_rules or {register = function() end, collect = function() return {} end, load = function() end}
    C.memory = C.memory or {on = function() return false end, register = function() end}
    C.mods = C.mods or {}
    C.mods.config = C.mods.config or {}
    C.net = C.net or {publish = function() end, watch = function() end}
    C.on_session = C.on_session or function() end
    C.memory.register = C.memory.register or function() end
    C.saved_rules.register = C.saved_rules.register or function() end
    C.net.watch = C.net.watch or function() end
    C.net.publish = C.net.publish or function() end
    R.on = R.on or function() end
    R.save_settings = R.save_settings or function() end
    R.valid = R.valid or function(v) return v end
    C.state = C.state or function() end
    C.rules = dofile('candidate/runtime-source/Core/rulebook.lua')(R, C)
    return C.rules
end
