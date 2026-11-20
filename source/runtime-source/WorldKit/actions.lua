-- Changing a Creative level with the game's own creative functions (the results are ordinary
-- objects, the map stays vanilla): move, copy, place, delete; and ONE undo for every editor.
return function(R, C, K, M)
    local valid, v3 = K.valid, M.v3

    -- ---------------------------------------------------------------- undo
    -- One step per action: the transforms objects had before, the objects it created (undo deletes
    -- them), the objects it deleted (undo places them again), and what other editors add to it
    -- (K.undo.add: groups, hidden scenery ...). 50 steps.
    local U = { stack = {}, cur = nil, depth = 0, paused = false }
    K.undo = {}
    -- fn() after the steps changed (one added, one undone): what shows the next undo follows at once
    -- (user 11-20: after a brush stroke "nothing to undo", after undoing it "Undo brush stroke").
    local heard = {}
    function K.undo.on_change(fn) heard[#heard + 1] = fn end
    local function changed() for _, fn in ipairs(heard) do R.call(fn) end end
    local function empty(e) return #e.order == 0 and #e.created == 0 and #e.deleted == 0 and #e.extras == 0 end
    -- An action: everything between begin and finish is one step (they nest).
    function K.undo.begin(label)
        if U.paused then return end
        U.depth = U.depth + 1
        if U.depth == 1 then U.cur = { label = label or "change", moves = {}, order = {}, created = {}, deleted = {}, extras = {}, keys = {}, t = os.clock() } end
    end
    function K.undo.finish()
        if U.paused or U.depth == 0 then return end
        U.depth = U.depth - 1
        if U.depth > 0 then return end
        local e = U.cur
        U.cur = nil
        if not e or empty(e) then return end
        local top = U.stack[#U.stack]
        -- typing / dragging exact values: one step for the whole edit of one object
        if top and top.label == e.label and e.label == "exact" and os.clock() - top.t < 3 and #e.order == 1 and #top.order == 1
            and e.order[1] == top.order[1] and #e.extras == 0 then top.t = os.clock(); return end
        U.stack[#U.stack + 1] = e
        if #U.stack > 50 then table.remove(U.stack, 1) end
        changed()
    end
    -- fn(step) inside the current action, or as a step of its own.
    local function record(fn)
        if U.paused then return end
        local own = U.depth == 0
        if own then K.undo.begin("change") end
        R.finally(fn, function() if own then K.undo.finish() end end, U.cur)
    end
    -- Another editor's part of this step: make() -> revert() is asked once per key and step (the
    -- state before the step's first change of that kind); undo calls revert(pc).
    function K.undo.add(key, make, label)
        if U.paused then return end
        local own = U.depth == 0
        if own then K.undo.begin(label or "change") end
        local e = U.cur
        R.finally(function()
            if e.keys[key] then return end
            local revert = make()
            if revert then e.keys[key] = true; e.extras[#e.extras + 1] = revert end
        end, function() if own then K.undo.finish() end end)
    end
    function K.undo.count() return #U.stack end
    -- The game's editing functions called by these tools (not the player's own editing, below).
    local own = 0
    local function game(fn, ...) own = own + 1; return R.finally(fn, function() own = own - 1 end, ...) end
    -- What the next undo takes back (its label), nil when nothing.
    function K.undo.top() local e = U.stack[#U.stack]; return e and e.label end
    local function moved(a)
        record(function(e)
            local p = K.fullName(a)
            if p and not e.moves[p] then
                e.moves[p] = { K.getLoc(a), K.getRot(a), K.getScale(a) }
                e.order[#e.order + 1] = p
            end
        end)
    end
    local function created(a)
        record(function(e) local p = K.fullName(a); if p then e.created[#e.created + 1] = p end end)
    end
    local function deleted(a)
        record(function(e)
            local cp = a:GetClass():GetFullName():match("^%S+%s+(.+)$")
            local d = { path = K.fullName(a), cls = cp, loc = K.getLoc(a), rot = K.getRot(a), scale = K.getScale(a), mat = K.isA(a, K.PLACEABLE) and R.values(a.SavedMaterialIndices) or nil, o = {} }
            -- (what the game's place function takes again; an object without one of them has none)
            for _, k in ipairs({ "Activated", "StartAwake", "IsFreezed", "BreaksAfterUse" }) do
                local v = a[k]; if type(v) == "boolean" then d.o[k] = v end
            end
            if K.isA(a, K.LIGHT) then local c = a.Color; d.o.color = { c.X, c.Y, c.Z } end
            e.deleted[#e.deleted + 1] = d
        end)
    end

    -- ---------------------------------------------------------------- moving
    -- Not selected by you: the game's server function UpdateActorTransformServer. Selected by you:
    -- what the game does while you drag them: the selected objects hang on the first selected one
    -- (the anchor), so the anchor is moved first, then every other selected object is put where it
    -- belongs (its new place, or back where it was), and the game's UpdateSelectedActorsTransforms
    -- sends the changes. The selection is never dropped (dropping + re-picking it lost it).
    -- list: { {actor, loc, rot, scale}, ... } (nil keeps that part). Returns how many moved.
    local quietUntil = 0
    function K.moveMany(pc, list)
        local sel = K.selection(pc)
        local selSet = {}
        for _, a in ipairs(sel) do selSet[tostring(K.addrOf(a))] = true end
        local selJobs, otherJobs = {}, {}
        for _, t in ipairs(list) do
            local a = t[1]
            if valid(a) then
                moved(a)
                local j = { a = a, T = M.transform(t[2] or K.getLoc(a), t[3] or K.getRot(a), K.limitScale(a, t[4] or K.getScale(a))) }
                if selSet[tostring(K.addrOf(a))] then selJobs[tostring(K.addrOf(a))] = j else otherJobs[#otherJobs + 1] = j end
            end
        end
        local n = 0
        for _, j in ipairs(otherJobs) do game(pc.UpdateActorTransformServer, pc, j.a, j.T); n = n + 1 end
        if next(selJobs) then
            local orig = {}
            for _, a in ipairs(sel) do orig[tostring(K.addrOf(a))] = M.transform(K.getLoc(a), K.getRot(a), K.getScale(a)) end
            local function place(a)
                local k = tostring(K.addrOf(a))
                a:K2_SetActorTransform((selJobs[k] and selJobs[k].T) or orig[k], false, {}, true)
                if selJobs[k] then n = n + 1 end
            end
            if valid(sel[1]) then place(sel[1]) end
            for i = 2, #sel do if valid(sel[i]) then place(sel[i]) end end
            game(pc.UpdateSelectedActorsTransforms, pc)
            K.quietSelection(0.3)
        end
        return n
    end
    function K.move(pc, a, loc, rot, scale) return K.moveMany(pc, { { a, loc, rot, scale } }) > 0 end
    -- The game reselects while a moved selection settles: editors that follow the selection wait.
    function K.quietSelection(seconds) quietUntil = math.max(quietUntil, os.clock() + seconds) end
    function K.selectionQuiet() return os.clock() < quietUntil end

    -- ---------------------------------------------------------------- copies, new objects, deleting (host)
    function K.copy(pc, model, loc, rot, scale)
        if not K.isHost(pc) then return nil, "only the host can make copies" end
        if not valid(model) then return nil, "the original is gone" end
        game(pc.DuplicateMultipleServer, pc, { model }, false)
        local arr = pc.PlacedActors
        local new = arr:GetArrayNum() > 0 and arr[arr:GetArrayNum()] or nil
        if not valid(new) or K.addrOf(new) == K.addrOf(model) then return nil, "copy failed (actor limit reached?)" end
        created(new)
        K.move(pc, new, loc, rot, scale)
        return new
    end
    -- Editors that keep objects hear the ones about to be deleted (fn(list)): their part of the step.
    local deleting = {}
    function K.on_deleting(fn) deleting[#deleting + 1] = fn end
    function K.delete(pc, list)
        local alive = {}
        for _, a in ipairs(list) do if valid(a) then alive[#alive + 1] = a end end
        if #alive == 0 then return end
        for _, fn in ipairs(deleting) do fn(alive) end
        for _, a in ipairs(alive) do deleted(a) end
        game(pc.DeleteMultipleServer, pc, alive)
    end
    -- A NEW object of a class, with the game's own creative function. Only classes the game can
    -- save and load (they have an asset id), so the map stays vanilla.
    -- o: act, awake, frozen, breaks, color {r,g,b}, mat (material indices).
    function K.spawn(pc, clsPath, loc, rot, scale, o)
        o = o or {}
        if not K.isHost(pc) then return nil, "only the host can place objects" end
        if type(clsPath) ~= "string" then return nil, "unknown object type" end
        local cls = K.class(clsPath)
        if not cls then return nil, "this object type is not in the game (" .. clsPath .. ")" end
        local idName = StaticFindObject("/Script/Engine.Default__KismetSystemLibrary"):GetPrimaryAssetIdFromClass(cls).PrimaryAssetName:ToString()
        if idName == "" or idName == "None" then return nil, "cannot be saved in a map by the game (not placed)" end
        local before = pc.PlacedActors:GetArrayNum()
        local col = o.color or { 1, 1, 1 }
        game(pc.PlaceActorServer, pc, cls, M.transform(loc, rot, scale), true, o.act == true, o.awake == true, o.frozen == true, o.breaks == true,
            { X = col[1], Y = col[2], Z = col[3] })
        local arr = pc.PlacedActors
        local new = arr:GetArrayNum() > before and arr[arr:GetArrayNum()] or nil
        if not valid(new) then return nil, "not placed (object limit reached?)" end
        created(new)
        if o.mat and #o.mat > 0 then C.map.set_bytes(new, o.mat); new:InitMaterialsBySavedIndices() end
        return new
    end

    -- The player's own editing with the game (the palette's place, its copy, its Delete, its gizmo
    -- and Transform panel) is a step of the one undo too: the undo names the last action, whoever made
    -- it (user 11-20: it named an old action of the tools, and Z undid that).
    local CTRL = C.CREATIVE_PC .. ":"
    local function players() return own == 0 and U.depth == 0 and not U.paused end
    local adding
    for fn, label in pairs({ PlaceActorServer = "place", DuplicateMultipleServer = "copy" }) do
        R.pre(CTRL .. fn, function(pc)
            if players() then adding = { pc = pc, before = pc.PlacedActors:GetArrayNum() }; K.undo.begin(label) end
        end)
        R.post(CTRL .. fn, function(pc)
            local a = adding
            if not a or a.pc ~= pc then return end
            adding = nil
            local arr = pc.PlacedActors
            for i = a.before + 1, arr:GetArrayNum() do if valid(arr[i]) then created(arr[i]) end end
            K.undo.finish()
        end)
    end
    -- (the player's Delete: the game's HandleDelete deletes the selection; ProbeEdit live VM2 11-20 — a hook on
    -- DeleteMultipleServer did not take it, live VM1)
    R.pre(CTRL .. "HandleDelete", function(pc)
        if not players() then return end
        local alive = {}
        for _, a in ipairs(K.selection(pc)) do if valid(a) then alive[#alive + 1] = a end end
        if #alive == 0 then return end
        K.undo.begin("delete")
        for _, fn in ipairs(deleting) do fn(alive) end
        for _, a in ipairs(alive) do deleted(a) end
        K.undo.finish()
    end)
    -- The player's drag with the game's gizmo: where the selection stood when the button went down, and
    -- what of it moved when the game ends the drag (StopModifyingAndDraggingActor, ProbeEdit live VM2
    -- 11-20; UpdateSelectedActorsTransforms is called for many other reasons: 48 false steps).
    local stood
    local function pose(a) return { K.getLoc(a), K.getRot(a), K.getScale(a) } end
    for _, n in ipairs({ "7", "8" }) do
        R.pre(CTRL .. "InpActEvt_Fire_K2Node_InputActionEvent_" .. n, function(pc)
            if not (players() and R.native.key_down(R.codes.LEFT_MOUSE)) then return end
            stood = {}
            for _, a in ipairs(K.selection(pc)) do local p = K.fullName(a); if p then stood[p] = pose(a) end end
        end)
    end
    local function same(x, y) return math.abs(x - y) < 0.01 end
    R.post(CTRL .. "StopModifyingAndDraggingActor", function(pc)
        local before = stood
        stood = nil
        if not (before and players()) then return end
        local moved = {}
        for _, a in ipairs(K.selection(pc)) do
            local p = K.fullName(a)
            local was, now = p and before[p], pose(a)
            if was and not (same(was[1].X, now[1].X) and same(was[1].Y, now[1].Y) and same(was[1].Z, now[1].Z)
                and same(was[2].Pitch, now[2].Pitch) and same(was[2].Yaw, now[2].Yaw) and same(was[2].Roll, now[2].Roll)
                and same(was[3].X, now[3].X) and same(was[3].Y, now[3].Y) and same(was[3].Z, now[3].Z)) then moved[#moved + 1] = { p, was } end
        end
        if #moved == 0 then return end
        K.undo.begin("move")
        record(function(e) for _, m in ipairs(moved) do if not e.moves[m[1]] then e.moves[m[1]] = m[2]; e.order[#e.order + 1] = m[1] end end end)
        K.undo.finish()
    end)
    R.on('world_end', function() adding, own, stood = nil, 0, nil end)

    -- An object undo placed again has a new name (the game names what it places): editors that keep
    -- objects by name hear fn(old, new) and follow it (Creative Tools' groups: undoing a delete kept
    -- the object out of its group).
    local renamed = {}
    function K.on_renamed(fn) renamed[#renamed + 1] = fn end
    -- Undo the last step: label, steps left; or nil, why.
    function K.undo.last(pc)
        local e = table.remove(U.stack)
        if not e then return nil, "nothing to undo" end
        U.paused = true
        R.finally(function()   -- (undo stays usable after a failure, which then goes on)
            local alive = {}
            for _, p in ipairs(e.created) do local a = K.resolve(p); if a then alive[#alive + 1] = a end end
            if #alive > 0 then pc:DeselectMultipleActors(K.selection(pc)); K.delete(pc, alive) end
            for _, d in ipairs(e.deleted) do
                local new = K.spawn(pc, d.cls, d.loc, d.rot, d.scale,
                    { act = d.o.Activated, awake = d.o.StartAwake, frozen = d.o.IsFreezed, breaks = d.o.BreaksAfterUse, color = d.o.color, mat = d.mat })
                local name = new and K.fullName(new)
                if name and d.path and name ~= d.path then for _, fn in ipairs(renamed) do fn(d.path, name) end end
            end
            local list = {}
            for _, p in ipairs(e.order) do
                local a, t = K.resolve(p), e.moves[p]
                if a and t then list[#list + 1] = { a, t[1], t[2], t[3] } end
            end
            if #list > 0 then K.moveMany(pc, list) end
            for i = #e.extras, 1, -1 do e.extras[i](pc) end
        end, function() U.paused = false; changed() end)
        return e.label, #U.stack
    end
    -- A new level: its objects are gone.
    R.on('world_end', function() U.stack, U.cur, U.depth, U.paused = {}, nil, 0, false; changed() end)
end
