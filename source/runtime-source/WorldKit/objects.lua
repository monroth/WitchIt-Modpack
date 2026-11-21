-- The objects of a Creative level as the editors see them: the local creative player, what it has
-- selected, where an object is (place, turn, size, its box) and the sizes the game allows.
return function(R, C, K, M)
    local v3, vadd, vsub, vmul, vmul3, vlen, mFromRot, mApply, mT =
        M.v3, M.vadd, M.vsub, M.vmul, M.vmul3, M.vlen, M.mFromRot, M.mApply, M.mT
    local function valid(o) return R.valid(o) ~= nil end
    K.valid = valid
    function K.addrOf(o) return o:GetAddress() end
    local function num(v, d) v = tonumber(v); if not v or v ~= v or v == math.huge or v == -math.huge then return d or 0 end; return v end
    K.num = num
    -- Classes by path, loaded when needed (false: not in the game).
    local classes = {}
    function K.class(path)
        if classes[path] == nil then
            local c = StaticFindObject(path)
            if not valid(c) then c = R.native.load_asset(path) end
            classes[path] = valid(c) and c or false
        end
        return classes[path] or nil
    end
    function K.isA(a, path) local c = K.class(path); return c ~= nil and a:IsA(c) end
    local P = "/Game/Blueprints/StaticProps/Placeable/"
    K.WORLD_PROPERTIES = P .. "Utility/BP_WorldProperties.BP_WorldProperties_C"
    K.LIGHT = P .. "Utility/BP_PlaceableLight.BP_PlaceableLight_C"
    K.PLACEABLE = P .. "BP_PlaceableActor.BP_PlaceableActor_C"
    K.PROP = "/Game/Blueprints/Props/Bases/B_StaticMeshProp.B_StaticMeshProp_C"
    -- The level: Core's session world, told apart from the worlds before it by a count of world
    -- ends (a new world can get the old one's address; then nothing noticed the change and editors
    -- kept freed widgets). nil while there is no world: editors then leave all objects alone.
    local worlds = 0
    R.on('world_end', function() worlds = worlds + 1 end)
    function K.level()
        local w = C.session().world
        if valid(w) then return w end
    end
    function K.levelKey()
        local w = K.level()
        return w and tostring(w:GetAddress()) .. "#" .. worlds
    end
    -- The local player's creative controller (nil outside Creative), from Core's session.
    function K.pc()
        local s = C.session()
        if s.is_creative and valid(s.pc) then return s.pc end
    end
    function K.playtest() return C.session().is_playtest == true end
    -- (the local controller's authority = the session's role (C.owns) for the local player; kept as the controller's because
    -- CreativeToolsPlus's tests, being edited elsewhere, double C without C.owns - move to C.owns() when they do - audit 11-20)
    function K.isHost(pc) return pc:HasAuthority() end
    -- What pc has selected (the level's world properties never count).
    function K.selection(pc)
        local out = {}
        local arr = pc.SelectedActors
        for i = 1, arr:GetArrayNum() do
            local a = arr[i]
            if valid(a) and not K.isA(a, K.WORLD_PROPERTIES) then out[#out + 1] = a end
        end
        return out
    end
    -- fn(pc) after the local player's selection changed (once a frame however many changes; the
    -- game's own select and deselect functions tell it, and a change of play mode, which changes
    -- what is shown selected).
    local listeners, told = {}, false
    function K.on_selection(fn) listeners[#listeners + 1] = fn end
    R.on("world_end", function() told = false end)   -- (the frame it waited for went with the world)
    local function tell()
        told = false
        local pc = K.pc()
        if pc then for _, fn in ipairs(listeners) do fn(pc) end end
    end
    local controller = C.CREATIVE_PC .. ":"
    for _, fn in ipairs({ "SelectActor", "SelectMultiple", "DeselectSingleActor", "DeselectMultipleActors", "ChangePlayerMode" }) do
        R.post(controller .. fn, function(pc)
            if told or #listeners == 0 then return end
            if pc:IsLocalController() then told = true; R.next_frame(tell) end
        end)
    end
    -- fn(moved, added) once a frame after objects of the level changed: moved, the objects moved,
    -- turned or sized (the game's UpdateActorTransformServer); added, true when an object of the
    -- level came or went in Creative, by whatever way (placed, copied, deleted, undone, a layout
    -- loaded): the editors that list objects count them again.
    local watchers, moved, added, waiting = {}, {}, false, false
    function K.on_changed(fn) watchers[#watchers + 1] = fn end
    R.on("world_end", function() moved, added, waiting = {}, false, false end)
    local function changed()
        local list, any = {}, added
        for _, a in pairs(moved) do if valid(a) then list[#list + 1] = a end end
        moved, added, waiting = {}, false, false
        for _, fn in ipairs(watchers) do fn(list, any) end
    end
    local function note(a, structural)
        if a then moved[tostring(K.addrOf(a))] = a end
        if structural then added = true end
        if not waiting then waiting = true; R.next_frame(changed) end
    end
    R.post(controller .. "UpdateActorTransformServer", function(_, a) if valid(a) then note(a) end end)
    local function counted(a) return K.pc() and (K.isA(a, K.PLACEABLE) or K.isA(a, K.PROP)) end
    R.on("actor_begin", function(a) if counted(a) then note(nil, true) end end)
    -- An object deleted is gone at once for the editors, though the engine still finds it for a while
    -- (until its memory is collected): kept by its name (unique to it) until the level ends.
    local gone = {}
    function K.gone(a) local p = K.fullName(a); return p ~= nil and gone[p] == true end
    R.on("actor_end", function(a, reason)
        if reason == 0 and counted(a) then
            local p = K.fullName(a); if p then gone[p] = true end
            note(nil, true)
        end
    end)
    R.on("world_end", function() gone = {} end)
    -- One loop for the editors' work each frame, run only while an editor has some: K.during(step)
    -- gives wake(); after a wake step() runs each frame until it returns false (a new level stops
    -- every step: wake again for the new one).
    local active, looping = {}, false
    local function loop()
        looping = false
        local now = {}
        for step in pairs(active) do now[#now + 1] = step end
        for _, step in ipairs(now) do
            -- (a failing step stops; the runtime logs it as any mod's failure)
            if not R.call(step) then active[step] = nil end
        end
        if next(active) and not looping then looping = true; R.next_frame(loop) end
    end
    function K.during(step)
        return function()
            active[step] = true
            if not looping then looping = true; R.next_frame(loop) end
        end
    end
    R.on("world_end", function() active, looping = {}, false end)
    -- Select many objects at once (add: to the selection, else instead of it): each through the game's own
    -- SelectMultiple, as a Shift+click does. (Live VM2 11-21: with only the last through it and the rest put in
    -- the selection list directly, the list was whole but the game's move moved only the clicked one and the
    -- last - it moves what SelectMultiple set up. It marks every selected object again on each call, so a few
    -- hundred take a moment; a moving group takes all of its objects.)
    function K.selectMany(pc, list, add)
        local all, seen = {}, {}
        if add then
            for _, a in ipairs(K.selection(pc)) do all[#all + 1] = a; seen[tostring(K.addrOf(a))] = true end
        else
            pc:DeselectMultipleActors(K.selection(pc))
        end
        local fresh = {}
        for _, a in ipairs(list) do
            local k = tostring(K.addrOf(a))
            if valid(a) and not seen[k] then seen[k] = true; fresh[#fresh + 1] = a end
        end
        if #fresh == 0 then return end
        for _, a in ipairs(fresh) do pc:SelectMultiple(a); all[#all + 1] = a end
        -- (user 11-21: a group of 15 showed all selected but the game moved only a few - how many the game's own
        -- list holds after this, against how many were meant)
        local held = pc.SelectedActors:GetArrayNum()
        if held ~= #all then R.log('WorldKit', 'Select many: %d meant, the game holds %d', #all, held) end
        -- (the game puts its gizmo on the first selected only when no drag is on: a selection made
        -- during the click that started it, as a group's, would stay without one)
        R.next_frame(function() if valid(pc) then pc:UpdateGizmoVisibility() end end)
    end
    -- The object's path in its level (its name across selections and undo), and back.
    function K.fullName(a)
        return a:GetFullName():match("^%S+%s+(.+)$")
    end
    function K.resolve(path)
        if type(path) ~= "string" then return nil end
        return R.valid(StaticFindObject(path))
    end
    function K.nameOf(a)
        return (a:GetClass():GetFName():ToString():gsub("^BP_", ""):gsub("^B_", ""):gsub("_C$", ""))
    end

    function K.getLoc(a) local l = a:K2_GetActorLocation(); return v3(num(l.X), num(l.Y), num(l.Z)) end
    function K.getRot(a) local r = a:K2_GetActorRotation(); return { Pitch = num(r.Pitch), Yaw = num(r.Yaw), Roll = num(r.Roll) } end
    function K.getScale(a) local s = a:GetActorScale3D(); return v3(num(s.X, 1), num(s.Y, 1), num(s.Z, 1)) end
    -- The object's box in the world: centre, half size.
    function K.bounds(a)
        local o, e = {}, {}
        a:GetActorBounds(false, o, e, false)
        return v3(o.X, o.Y, o.Z), v3(e.X, e.Y, e.Z)
    end
    -- The box around several objects: centre, lowest corner, highest corner.
    function K.groupBox(list)
        local mn, mx = v3(1e18, 1e18, 1e18), v3(-1e18, -1e18, -1e18)
        for _, a in ipairs(list) do
            local o, e = K.bounds(a)
            mn = v3(math.min(mn.X, o.X - e.X), math.min(mn.Y, o.Y - e.Y), math.min(mn.Z, o.Z - e.Z))
            mx = v3(math.max(mx.X, o.X + e.X), math.max(mx.Y, o.Y + e.Y), math.max(mx.Z, o.Z + e.Z))
        end
        if #list == 0 then mn, mx = v3(0, 0, 0), v3(0, 0, 0) end
        return vmul(vadd(mn, mx), 0.5), mn, mx
    end
    -- The object's own box (in its own space, before its size): lowest and highest corner. Each mesh
    -- box goes through the mesh's own place / turn / size in the world, then back into the object's
    -- space (meshes turned inside the object - planks - made the box lie the wrong way before).
    function K.localBounds(a)
        local mn, mx
        do
            local comps = a:K2_GetComponentsByClass(K.class("/Script/Engine.StaticMeshComponent"))
            local al, ar, as = K.getLoc(a), mFromRot(K.getRot(a)), K.getScale(a)
            local arT = mT(ar)
            -- (a function's array result comes as a Lua table, a property's as the engine's array: R.values takes both)
            for _, comp in ipairs(R.values(comps)) do
                if valid(comp) then
                    local lo, hi = {}, {}
                    comp:GetLocalBounds(lo, hi)
                    local bmn, bmx = v3(lo.X, lo.Y, lo.Z), v3(hi.X, hi.Y, hi.Z)
                    if comp:IsVisible() and vlen(vsub(bmx, bmn)) > 0.01 then
                        local l, r, sc = comp:K2_GetComponentLocation(), comp:K2_GetComponentRotation(), comp:K2_GetComponentScale()
                        local cl, cr, cs = v3(l.X, l.Y, l.Z), mFromRot({ Pitch = r.Pitch, Yaw = r.Yaw, Roll = r.Roll }), v3(sc.X, sc.Y, sc.Z)
                        do
                            for _, x in ipairs({ bmn.X, bmx.X }) do for _, y in ipairs({ bmn.Y, bmx.Y }) do for _, z in ipairs({ bmn.Z, bmx.Z }) do
                                local w = vadd(cl, mApply(cr, vmul3(v3(x, y, z), cs)))
                                local q = mApply(arT, vsub(w, al))
                                q = v3(q.X / (math.abs(as.X) > 1e-6 and as.X or 1), q.Y / (math.abs(as.Y) > 1e-6 and as.Y or 1), q.Z / (math.abs(as.Z) > 1e-6 and as.Z or 1))
                                mn = mn and v3(math.min(mn.X, q.X), math.min(mn.Y, q.Y), math.min(mn.Z, q.Z)) or q
                                mx = mx and v3(math.max(mx.X, q.X), math.max(mx.Y, q.Y), math.max(mx.Z, q.Z)) or q
                            end end end
                        end
                    end
                end
            end
        end
        if mn and vlen(vsub(mx, mn)) < 0.01 then mn = nil end
        if not mn then
            local o, e = K.bounds(a)
            local l, s = K.getLoc(a), K.getScale(a)
            local function d(v, k) return v / (math.abs(s[k]) > 1e-6 and s[k] or 1) end
            mn = v3(d(o.X - e.X - l.X, "X"), d(o.Y - e.Y - l.Y, "Y"), d(o.Z - e.Z - l.Z, "Z"))
            mx = v3(d(o.X + e.X - l.X, "X"), d(o.Y + e.Y - l.Y, "Y"), d(o.Z + e.Z - l.Z, "Z"))
        end
        return mn, mx
    end
    -- A point of the object's own space in the world.
    function K.toWorld(a, p) return vadd(K.getLoc(a), mApply(mFromRot(K.getRot(a)), vmul3(p, K.getScale(a)))) end

    -- The sizes the game allows an object (the creative editor's rules): min, max (nil: any), and
    -- whether it only scales evenly. K.limits(): whether the game's limits hold (the editor's setting,
    -- read when asked - audit 11-20: it was a copy kept in step by hand); by default they do.
    function K.limits() return true end
    -- (the game's own rule, asked: B_CreativePlayerController.DetermineClampActorScale clamps a scale
    -- for an object - the smallest from 0, the largest from a huge one; audit B28: its numbers were copied)
    local HUGE = 1e9
    function K.sizeLimits(a)
        if not K.limits() or not (K.isA(a, K.PROP) or K.isA(a, K.PLACEABLE)) then return nil end
        local pc = K.pc()
        local lo, hi = {}, {}
        pc:DetermineClampActorScale(a, 0, lo)
        pc:DetermineClampActorScale(a, HUGE, hi)
        -- (props scale only evenly)
        return lo.ClampedScale, hi.ClampedScale, K.isA(a, K.PROP)
    end
    function K.limitScale(a, s)
        local lo, hi, uniform = K.sizeLimits(a)
        if not lo then
            if K.isA(a, K.PROP) then local u = s.X; return v3(u, u, u) end   -- hideable props only scale evenly
            return s
        end
        local function c(v) return math.max(lo, math.min(hi, v)) end
        if uniform then local u = c(s.X); return v3(u, u, u) end
        return v3(c(s.X), c(s.Y), c(s.Z))
    end
end
