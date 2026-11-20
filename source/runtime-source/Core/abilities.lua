-- Abilities (and power-ups) a match allows. The game sets four lists for each match (the game
-- state's AllowedHunterSkills / AllowedWitchSkills, the game mode's AllowedHunterPickups /
-- AllowedWitchPickups); the skill choice offers what they hold. Mods do not write them: they ask
-- here, and the host's lists become the game's own plus what the mods asked for. Nothing asked:
-- nothing changes (Core changes nothing of the game by itself).
--   C.abilities.allow(owner, lists)  lists: {AllowedHunterSkills={class paths}, ...}, nil to stop
--   C.abilities.register(spec)       a mod's own ability: spec.class (path), spec.team ('hunter' or
--                                    'witch'), spec.name (text), spec.icon (a texture path),
--                                    spec.description (text), spec.base (the skill type whose rules
--                                    it starts from, e.g. 2 for the Hook): allowed in every match,
--                                    shown by the game with its name and icon, with a rules page of
--                                    its own (its own skill type in the game's table of skill rules).
--   C.abilities.type_of(class)      its own skill type (its rules page: C.rules page 'skill:<type>')
--   C.abilities.on_register(fn(spec, type))  each registered ability (also those registered before)
--   C.abilities.params(type)        the game's rules of a skill type now (its row of the game's table)
return function(R, C)
    local A = {}
    local LISTS = {AllowedHunterSkills = 'gs', AllowedWitchSkills = 'gs', AllowedHunterPickups = 'gm', AllowedWitchPickups = 'gm'}
    local asked = {}       -- owner -> lists
    local abilities = {}   -- class path -> spec
    local registered = {}  -- fn(spec, type), for each ability registered
    local native = nil     -- the game's own lists of this match: {state = address, lists = {key = {objects}}}

    local function holder(session, key) return LISTS[key] == 'gs' and session.gs or session.gm end
    -- A class that is not loaded yet loads now; once it is there the lists are set again.
    local waiting = {}
    local function class_of(path)
        local class = R.valid(R.native.load_asset(path))
        if not class and not waiting[path] then
            waiting[path] = true
            R.native.on_asset(path, function(loaded, why)
                waiting[path] = nil
                if loaded then A.apply() else R.log('Core', 'Allowed class %s not loaded: %s', path, tostring(why)) end
            end)
        end
        return class
    end
    -- (a vanilla session is the game's own: its lists are never touched, so a player without mods
    -- never gets a class only a mod has)
    local function hosting(s) return s.role == 'host' and not s.is_vanilla_session and R.valid(s.gs) and R.valid(s.gm) end

    -- What the host's lists hold now: the game's own (kept from before the first change of this
    -- match) and every class asked for, each once.
    function A.apply()
        local s = C.session()
        if not hosting(s) then return end
        local any = next(asked) ~= nil or next(abilities) ~= nil
        local state = s.gs:GetAddress()
        if not native or native.state ~= state then
            if not any then return end
            native = {state = state, lists = {}}
            for key in pairs(LISTS) do native.lists[key] = R.values(holder(s, key)[key]) end
        end
        local wanted = {}
        for key in pairs(LISTS) do wanted[key] = {} end
        local function add(key, class)
            if not class then return end
            for _, have in ipairs(wanted[key]) do if have:GetAddress() == class:GetAddress() then return end end
            wanted[key][#wanted[key] + 1] = class
        end
        for key, objects in pairs(native.lists) do for _, class in ipairs(objects) do add(key, class) end end
        for _, lists in pairs(asked) do
            for key, paths in pairs(lists) do
                assert(LISTS[key], 'not an allowed list: ' .. tostring(key))
                for _, path in ipairs(paths) do add(key, class_of(path)) end
            end
        end
        for path, spec in pairs(abilities) do
            add(spec.team == 'witch' and 'AllowedWitchSkills' or 'AllowedHunterSkills', class_of(path))
        end
        for key in pairs(LISTS) do
            local array = holder(s, key)[key]
            array:Empty()
            for i, class in ipairs(wanted[key]) do array[i] = class end
        end
        s.gs:SkillsUpdated()
    end

    function A.allow(owner, lists)
        asked[owner] = lists
        A.apply()
    end

    -- An ability's own skill type: the same on every machine (from its class path), above the game's.
    local function type_of(path)
        local h = 0
        for i = 1, #path do h = (h * 31 + path:byte(i)) % 1000003 end
        return 128 + h % 120
    end
    A.type_of = type_of
    -- The game's table of skill rules (the skill parameters subsystem's Skills: type -> parameters)
    -- gets a row for each registered ability: a copy of its base's parameters with its own class.
    local SUBSYSTEM = C.subsystem_paths.skills   -- (game.lua's)
    local function add_row(subsystem, spec, class)
        local kind = type_of(spec.class)
        local base
        subsystem.Skills:ForEach(function(k, v) if k:get() == (spec.base or 2) then base = v:get() end end)
        if not R.valid(base) then R.log('Core', 'Ability %s: no skill type %s to start from', spec.class, tostring(spec.base)); return end
        local params = StaticConstructObject(base:GetClass(), subsystem)
        base:GetClass():ForEachProperty(function(p)
            local name = p:GetFName():ToString()
            pcall(function() params[name] = base[name] end)
        end)
        params.SkillClass = class
        params.IsListed = true
        if spec.description then params.ToolTip = FText(spec.description) end
        subsystem.Skills:Add(kind, params)
    end
    function A.params(kind)
        local found
        C.subsystem('skills').Skills:ForEach(function(k, v) if k:get() == kind then found = v:get() end end)
        return R.valid(found)
    end
    function A.on_register(fn)
        registered[#registered + 1] = fn
        for _, spec in pairs(abilities) do fn(spec, type_of(spec.class)) end
    end
    local function rows()
        local subsystem = R.valid(FindFirstOf(SUBSYSTEM:match('%.([^.]+)$')))
        if not subsystem then return end
        for path, spec in pairs(abilities) do
            local class = R.valid(StaticFindObject(path))
            if class then add_row(subsystem, spec, class) end
        end
    end
    R.post(SUBSYSTEM .. ':InitializeDefaultSkills', function() rows() end)

    -- The game shows a skill's name and icon from its class defaults.
    local function label(spec, class)
        local cdo = class:GetCDO()
        cdo.SkillType = type_of(spec.class)
        cdo.SkillOverrideType = type_of(spec.class)
        if spec.name then cdo.SkillName = FText(spec.name) end
        if spec.icon and spec.icon:match('%.png$') then
            cdo.SkillIcon = R.picture(spec.icon)   -- (a PNG file of the mod)
        elseif spec.icon then
            R.native.on_asset(spec.icon, function(texture, why)
                if texture then cdo.SkillIcon = texture else R.log('Core', 'Ability icon %s not loaded: %s', spec.icon, tostring(why)) end
            end)
        end
    end
    function A.register(spec)
        assert(type(spec.class) == 'string' and (spec.team == 'hunter' or spec.team == 'witch'), 'an ability needs its class path and team')
        abilities[spec.class] = spec
        for _, fn in ipairs(registered) do fn(spec, type_of(spec.class)) end
        -- (its class may load later: once it is there it gets its name and the lists are set again)
        R.native.on_asset(spec.class, function(class, why)
            if not class then R.log('Core', 'Ability %s not loaded: %s', spec.class, tostring(why)); return end
            label(spec, class)
            rows()
            A.apply()
        end)
    end

    -- The game sets its lists for each match: they are set again at its start and each round's.
    R.on('match_start', function() A.apply() end)
    R.on('round_start', function() A.apply() end)
    R.on('world_end', function() native = nil end)
    return A
end
