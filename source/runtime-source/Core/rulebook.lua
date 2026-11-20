-- The mods' rules, in one format and with one owner. A mod declares its rules; Core keeps their
-- values, sends them to guests, saves them with the game's rules files (C.saved_rules), keeps them
-- per game mode (C.memory) and gives them to rules codes. UIKit shows each rule where it belongs.
--
--   C.rules.declare(pkg, specs)   specs: a list of rules of one mod (its package id):
--       key, label, help (a tooltip), kind ('bool', 'number' or 'text'), initial;
--       numbers: min, max (what is accepted: only where a value outside means nothing; none for
--       no limit), sliderMin, sliderMax (the usual range the slider shows), step,
--       integer, infinite (the slider's top means "infinite", stored as 'infinite');
--       text: valid(value) -> whether a value is acceptable;
--       page: where it is shown ('general', 'hunters', 'witches', 'skill:<type>', 'powerup:<type>',
--       'tab' (the mod's own rules tab), 'none' (the mod shows it itself));
--       live: a change applies at once (others from the next match, or at once where the game
--       allows live rule editing).
--   C.rules.get(pkg, key)          the value in force (the host's; a guest's copy of the host's)
--   C.rules.shown(pkg, key)        the value the rules screens show (the host's edits; a guest: the
--                                  host's, or their own rules in "My rules")
--   C.rules.set(pkg, key, value)   a change from a rules screen (the host's, or a guest's own rules)
--   C.rules.editable()             whether the rules screens may change rules now
--   C.rules.mine(on)               a guest's view: their own rules (true) or the match's
--   C.rules.specs(pkg), C.rules.packages(), C.rules.on_change(fn(pkg, key)),
--   C.rules.on_declare(fn(pkg, specs))  (also for mods declared before)
--   C.rules.apply()                the edited rules come into force (a hosted session's start and each match's do it)
--   C.rules.reset(page)            the rules the screens may change back to their initial values: all, or
--                                  those shown on one page ('skill:<type>', 'powerup:<type>', ...)
return function(R, C)
    local B = {}
    local declared = {}    -- pkg -> {list = specs, by = key -> spec}
    local order = {}       -- packages in declaration order
    local edited = {}      -- pkg -> key -> value (the host's)
    local active = {}      -- pkg -> key -> value in force (the host's)
    local remote = {}      -- pkg -> key -> value (a guest's copy of the host's active)
    local draft = {}       -- pkg -> key -> value (a guest's own rules)
    local mine = false
    local listeners, declares = {}, {}

    local function host() return C.session().role ~= 'client' end
    local function changed(pkg, key) for _, fn in ipairs(listeners) do fn(pkg, key) end end

    local function finite(n) return type(n) == 'number' and n == n and math.abs(n) < math.huge end
    -- Is a value acceptable for a rule?
    function B.valid(spec, value)
        if spec.kind == 'bool' then return type(value) == 'boolean' end
        if spec.kind == 'text' then return type(value) == 'string' and (not spec.valid or spec.valid(value)) end
        if spec.infinite and value == 'infinite' then return true end
        return finite(value) and (not spec.min or value >= spec.min) and (not spec.max or value <= spec.max)
            and (not spec.integer or value % 1 == 0)
    end
    -- A section (key -> value) kept to the rules a mod declared, each value acceptable.
    local function clean(pkg, section)
        local out = {}
        local d = declared[pkg]
        if type(section) ~= 'table' or not d then return out end
        for key, value in pairs(section) do
            local spec = d.by[key]
            if spec and B.valid(spec, value) and value ~= spec.initial then out[key] = value end
        end
        return out
    end
    local function value(map, pkg, key)
        local spec = assert(declared[pkg] and declared[pkg].by[key], 'no rule ' .. tostring(pkg) .. '.' .. tostring(key))
        local v = map[pkg] and map[pkg][key]
        if v == nil then return spec.initial end
        return v
    end

    -- The mods' rules in force that differ from their defaults, in the log as they change (host: applied;
    -- guest: as the host sent them) - user 11-20, a log has to say which rules a match ran with.
    local function inForce()
        local map, parts = host() and active or remote, {}
        for _, pkg in ipairs(order) do
            local keys = {}
            for key, v in pairs(map[pkg] or {}) do keys[#keys + 1] = key .. '=' .. tostring(type(v) == 'table' and R.json.encode(v) or v) end
            table.sort(keys)
            if #keys > 0 then parts[#parts + 1] = pkg .. ' {' .. table.concat(keys, ', ') .. '}' end
        end
        C.state('Core', 'Mod rules in force', #parts > 0 and table.concat(parts, '; ') or 'all at their defaults')
    end
    local function publish()
        if host() and C.session().role == 'host' then inForce(); C.net.publish('core.rules', active) end
    end
    C.net.watch('core.rules', function(value)
        if host() then return end
        remote = {}
        for pkg, section in pairs(type(value) == 'table' and value or {}) do remote[pkg] = clean(pkg, section) end
        inForce()
        for pkg in pairs(declared) do changed(pkg) end
    end)

    function B.declare(pkg, specs)
        assert(type(pkg) == 'string' and not declared[pkg], 'rules declared twice: ' .. tostring(pkg))
        local d = {list = specs, by = {}}
        for _, spec in ipairs(specs) do
            assert(type(spec.key) == 'string' and spec.label and spec.kind and spec.initial ~= nil, 'a rule needs key, label, kind, initial')
            assert(B.valid(spec, spec.initial), 'a rule\'s initial value is not acceptable: ' .. pkg .. '.' .. spec.key)
            spec.page = spec.page or 'tab'
            d.by[spec.key] = spec
        end
        declared[pkg] = d
        order[#order + 1] = pkg
        edited[pkg], active[pkg] = {}, {}
        -- Saved with the game's rules files and per game mode, like every mod's rules.
        local owner = {save = function() return B.section(pkg) end, load = function(section) B.load(pkg, section) end}
        C.saved_rules.register(pkg, owner)
        C.memory.register(pkg, owner)
        for _, fn in ipairs(declares) do fn(pkg, specs) end
    end
    function B.on_declare(fn)
        declares[#declares + 1] = fn
        for _, pkg in ipairs(order) do fn(pkg, declared[pkg].list) end
    end

    function B.get(pkg, key) return value(host() and active or remote, pkg, key) end
    function B.shown(pkg, key)
        if host() then return value(edited, pkg, key) end
        return value(mine and draft or remote, pkg, key)
    end
    function B.editable() return host() or mine end
    function B.mine(on) mine = on == true; for pkg in pairs(declared) do changed(pkg) end end
    -- In force at once: a live rule, or any rule where the game lets the host edit rules in play.
    local function liveNow(spec)
        if spec.live then return true end
        local s = C.session()
        return s.role == 'host' and R.valid(s.gm) and s.gm.IsLiveRuleEditingAllowed == true
    end
    function B.set(pkg, key, v)
        local spec = assert(declared[pkg] and declared[pkg].by[key], 'no rule ' .. pkg .. '.' .. key)
        assert(B.valid(spec, v), 'not an acceptable value for ' .. spec.label)
        if v == spec.initial then v = nil end
        if not host() then
            assert(mine, 'a guest changes only their own rules')
            draft[pkg] = draft[pkg] or {}
            draft[pkg][key] = v
            changed(pkg, key)
            return
        end
        edited[pkg][key] = v
        if liveNow(spec) then active[pkg][key] = v; publish() end
        changed(pkg, key)
    end
    function B.apply()
        for pkg in pairs(declared) do
            active[pkg] = {}
            for k, v in pairs(edited[pkg]) do active[pkg][k] = v end
        end
        publish()
        for pkg in pairs(declared) do changed(pkg) end
    end
    -- A mod's rules as a section (non-initial values) and back: files, codes, memory. A guest's
    -- section is their own rules in "My rules", else the host's.
    function B.section(pkg)
        local source = host() and edited or (mine and draft or remote)
        local out = {}
        for k, v in pairs(source[pkg] or {}) do out[k] = v end
        return out
    end
    function B.load(pkg, section)
        if not declared[pkg] then return end
        if not host() then draft[pkg] = clean(pkg, section); changed(pkg); return end
        edited[pkg] = clean(pkg, section)
        for key, spec in pairs(declared[pkg].by) do if liveNow(spec) then active[pkg][key] = edited[pkg][key] end end
        publish()
        changed(pkg)
    end
    function B.reset(page)
        if not B.editable() then return end
        for _, pkg in ipairs(order) do
            for _, spec in ipairs(declared[pkg].list) do
                if page == nil or spec.page == page then B.set(pkg, spec.key, spec.initial) end
            end
        end
    end
    function B.specs(pkg) return declared[pkg] and declared[pkg].list or {} end
    function B.packages() return order end
    function B.on_change(fn) listeners[#listeners + 1] = fn end

    -- A hosted session starts with the edited rules (its team selection already plays by them),
    -- and so does each match; guests get them with each session and round.
    R.on('match_start', function() if host() then B.apply() end end)
    R.on('round_start', publish)
    local hosted
    C.on_session(function(s)
        if s.role == 'host' and s.world ~= hosted then hosted = s.world; B.apply() end
        if s.role == 'host' then publish() end
        if s.role ~= 'client' then remote, draft, mine = {}, {}, false end
    end)
    return B
end
