-- Scopes: hooks and events that act only while applies(session) is true, so a package's
-- gameplay code stays out of sessions that are not its own.
return function(R, C)
    return function(applies)
        local function gate(fn)
            return function(...) if applies(C.session()) then return fn(...) end end
        end
        return {
            pre = function(path, fn, raw) R.pre(path, gate(fn), raw) end,
            observe = function(path, fn) R.observe(path, gate(fn)) end,
            post = function(path, fn) R.post(path, gate(fn)) end,
            on = function(event, fn) R.on(event, gate(fn)) end,
            session = function(fn) C.on_session(gate(fn)) end,
            playtest = function(fn) C.on_playtest(gate(fn)) end,
            -- Every actor of class while the scope applies: each one the event at path brings
            -- (its first argument), and those already there when the scope starts to apply,
            -- such as actors a guest received before it learned the host's mode.
            actors = function(path, class, fn)
                R.post(path, function(actor)
                    if applies(C.session()) and R.valid(actor) and actor:IsA(class) then fn(actor) end
                end)
                local applied = false
                C.on_session(function(s)
                    local now = applies(s)
                    if now and not applied then
                        for _, actor in ipairs(R.find_all(class)) do fn(actor) end
                    end
                    applied = now
                end)
            end,
        }
    end
end
