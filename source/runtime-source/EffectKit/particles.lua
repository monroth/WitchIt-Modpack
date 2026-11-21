-- Niagara systems and streams of particles toward targets. The mod's own systems are in its pak
-- (Paks/EffectKit_P, built by content/build-effects.sh): SPARK_STREAM, glowing sparks along the
-- component's Z, User.Color (HDR: it glows) and User.SpawnRate; WISPS, soft wisps drifting along Z on swirling
-- paths, fading in and out, User.Color (its alpha: how faint), User.SpawnRate, User.Speed and
-- User.Lifetime (a pointer's reach sets those two and User.Drag), drawn with the game's possession dot;
-- WISPS_AROUND, the same leaving a point in every direction
-- (where a target is too near to drift toward).
return function(R, C, E)
    E.SPARK_STREAM = '/Game/EffectKit/NS_SparkStream.NS_SparkStream'
    E.WISPS = '/Game/EffectKit/NS_Wisps.NS_Wisps'
    E.WISPS_AROUND = '/Game/EffectKit/NS_WispsAround.NS_WispsAround'
    E.WISPS_DRAG = 0.1   -- (NS_Wisps' own drag; a pointer's reach sets User.Drag to its own)
    local function find(path) return StaticFindObject(path) end
    function E.params(component, params)
        for name, value in pairs(params or {}) do
            local key = FName(name)
            if type(value) == 'number' then component:SetVariableFloat(key, value)
            elseif type(value) == 'boolean' then component:SetVariableBool(key, value)
            elseif type(value) == 'string' then component:SetVariableMaterial(key, R.native.load_asset(value))
            elseif value.R then component:SetVariableLinearColor(key, value)
            elseif value.Z == nil then component:SetVariableVec2(key, value)
            else component:SetVariableVec3(key, value) end
        end
    end
    local ZERO = {Pitch = 0, Yaw = 0, Roll = 0}
    function E.niagara(context, system, opts)
        opts = opts or {}
        local library = find('/Script/Niagara.Default__NiagaraFunctionLibrary')
        local component
        if opts.attach then
            component = library:SpawnSystemAttached(system, opts.attach, FName('None'), opts.at or {X = 0, Y = 0, Z = 0},
                opts.rotation or ZERO, 1, not opts.keep, false, 0, true)
        else
            component = library:SpawnSystemAtLocation(context, system, opts.at, opts.rotation or ZERO, {X = 1, Y = 1, Z = 1},
                not opts.keep, false, 0, true)
        end
        component = R.valid(component)
        C.state('EffectKit', 'Niagara spawn', component and 'working' or 'failed - the game made no particle component')
        if not component then return end
        E.params(component, opts.params)
        for _, emitter in ipairs(opts.off or {}) do component:SetEmitterEnable(FName(emitter), false) end
        component:Activate(true)
        return component
    end
    function E.remove(component)
        if R.valid(component) then component:K2_DestroyComponent(component) end
    end

    function E.pointers(look)
        local P, live = {}, {}
        local function close(key) local s = live[key]; live[key] = nil; if s then E.remove(s.component) end end
        local function system()
            local asset = R.valid(R.native.load_asset(look.path))
            C.state('EffectKit', 'Effect ' .. look.path, asset and 'loaded' or 'not loaded - the EffectKit pak is missing, no effect is drawn')
            return asset
        end
        function P:aim(key, context, from, to, closeness)
            local s = live[key]
            if look.every then
                s = s or {}
                live[key] = s
                s.seen = true
                local now = find('/Script/Engine.Default__GameplayStatics'):GetTimeSeconds(context)
                if s.last and now - s.last < look.every(closeness) then return end
                local asset = system()
                if not asset then return end
                s.last = now
                local params = {}
                for name, value in pairs(look.params or {}) do params[name] = value end
                if look.toward then params[look.toward] = to end
                E.niagara(context, asset, {at = from, params = params, off = look.off})
                return
            end
            if not s or not R.valid(s.component) then
                local asset = system()
                if not asset then return end
                s = {component = E.niagara(context, asset, {at = from, params = look.params, off = look.off, keep = true})}
                if not s.component then return end
                live[key] = s
            end
            s.seen = true
            local rotation = find('/Script/Engine.Default__KismetMathLibrary'):MakeRotFromZ({X = to.X - from.X, Y = to.Y - from.Y, Z = to.Z - from.Z})
            s.component:K2_SetWorldLocationAndRotation(from, rotation, false, {}, false)
            if look.rate then E.params(s.component, look.rate(closeness)) end
            if look.reach then
                -- Each particle ends at the target: with drag k one starting at v covers v (1 - e^-kt) / k
                -- in t seconds, at most v / k (so v is at least a bit over d k).
                local d = math.max(1, math.sqrt((to.X - from.X) ^ 2 + (to.Y - from.Y) ^ 2 + (to.Z - from.Z) ^ 2) - (look.reach.stop or 0))
                local k = look.reach.drag
                local v = math.max(look.reach.speed(closeness), d * k * 1.25)
                E.params(s.component, {Speed = v, Lifetime = -math.log(1 - d * k / v) / k, Drag = k})
            end
        end
        function P:done()
            for key, s in pairs(live) do if not s.seen then close(key) else s.seen = false end end
        end
        function P:close(part) for key in pairs(live) do if key:find(part, 1, true) then close(key) end end end
        function P:clear() for key in pairs(live) do close(key) end end
        R.on('world_end', function() live = {} end)
        return P
    end
end
