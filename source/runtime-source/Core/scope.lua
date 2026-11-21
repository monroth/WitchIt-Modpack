-- Scopes: hooks and events that act only while applies(session) is true, so a package's
-- gameplay code stays out of sessions that are not its own.
return function(R, C)
    return function(applies,name)
        -- (the log says when this scope's hooks start and stop acting, and why: the session's mode and role,
        -- named by the file that made it unless told)
        name=name or (debug.getinfo(2,'S').source:match('([^/\\]+)%.lua$') or '?')
        local owner=debug.getinfo(2,'S').source:match('([^/\\]+)[/\\][^/\\]+%.lua$') or 'Core'
        local function session() return C.session_of(owner) end
        C.on_session(function()
            local s=session()
            local on=applies(s)
            C.state(owner,'Scope '..name,(on and 'acting' or 'not acting')..' - mode '..tostring(s.mode)..', '..tostring(s.role))
        end)
        local function gate(fn)
            return function(...) if applies(session()) then return fn(...) end end
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
                    if applies(session()) and R.valid(actor) and actor:IsA(class) then fn(actor) end
                end)
                local applied = false
                C.on_session(function()
                    local now = applies(session())
                    if now and not applied then
                        for _, actor in ipairs(R.find_all(class)) do fn(actor) end
                    end
                    applied = now
                end)
            end,
        }
    end
end
