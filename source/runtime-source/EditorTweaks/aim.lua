-- Aim: while on, the scenery actor under the crosshair blinks (only its visibility, so the
-- crosshair keeps hitting it) every 350 ms of real time; the target is picked again only when
-- the camera moved. Hide takes the target, Undo brings back the last change.
-- api: ensure_edit, edit, undo, lookup, key (see package.lua). pick: pick.lua.
return function(R, Objects, api, pick)
    local A = {}
    local BLINK = .35
    local aim = {on = false}
    local watchers, display = {}, nil
    local function tell() for _, fn in ipairs(watchers) do fn() end end

    -- Whether World edits hides the aimed object: asked each blink (audit 11-20: a copy taken when it was
    -- aimed at put back a stale state after an edit).
    local function edited()
        local s = api.ensure_edit()
        return s ~= nil and aim.target ~= nil and s.data.hidden[api.key(aim.target)] ~= nil
    end
    local function blink(dark)
        if aim.dark == dark then return end
        aim.dark = dark
        local actor = aim.actor
        if actor and R.valid(actor) then actor:SetActorHiddenInGame(dark or edited()) end
    end
    local function target(row)
        blink(false)
        aim.target, aim.actor = row, nil
        if row and row.kind == 'actor' then
            local actor = api.lookup(row.path)
            if actor then aim.actor = actor end
        end
        if display then display(A.label()) end
    end
    local function stop()
        target(nil)
        aim.on, aim.view = false, nil
        tell()
    end
    -- (each frame while on, in WorldKit's loop for the editors)
    local function tick()
        if not aim.on then return false end
        local s, pc = api.ensure_edit()
        if not s then stop(); return false end
        local camera = pc.PlayerCameraManager
        local o, r = camera:GetCameraLocation(), camera:GetCameraRotation()
        local view = string.format('%.1f %.1f %.1f %.2f %.2f', o.X, o.Y, o.Z, r.Pitch, r.Yaw)
        if view ~= aim.view then
            aim.view = view
            local row = pick.under(pc, s)
            if (row and api.key(row)) ~= (aim.target and api.key(aim.target)) then target(row) end
        end
        local now = StaticFindObject('/Script/Engine.Default__GameplayStatics'):GetRealTimeSeconds(pc)
        if now >= (aim.next_blink or 0) then aim.next_blink = now + BLINK; blink(not aim.dark) end
        return true
    end
    local wake = R.packages.WorldKit.during(tick)

    function A.on() return aim.on end
    function A.label() return aim.on and aim.target and Objects.label(aim.target) or '' end
    -- fn() runs when the aim switches on or off.
    function A.watch(fn) watchers[#watchers + 1] = fn end
    -- The one place that shows the target's name (nil: none), set while it exists.
    function A.show(set) display = set end
    function A.toggle()
        if aim.on then stop(); return end
        if not api.ensure_edit() then R.log('EditorTweaks','Hide tool aim not started: no edit session on this map'); return end
        R.log('EditorTweaks','Hide tool aim on')
        aim.on, aim.view, aim.next_blink = true, nil, 0
        tell()
        if tick() then wake() end
    end
    -- Before an edit: the target shows again and is picked anew.
    function A.release() target(nil); aim.view = nil end
    function A.hide()
        local s, pc = api.ensure_edit()
        if not s then R.log('EditorTweaks','Hide refused: no edit session on this map'); return end
        local row = aim.on and aim.target or pick.under(pc, s)
        if not row then R.log('EditorTweaks','Hide: nothing under the aim'); return end
        R.log('EditorTweaks','Hide %s', tostring(Objects.label(row)))
        A.release()
        api.edit(row, true)
    end
    function A.undo()
        if not api.ensure_edit() then R.log('EditorTweaks','Undo refused: no edit session on this map'); return end
        R.log('EditorTweaks','Undo the last change')
        A.release()
        api.undo()
    end
    -- The world ends: its actors are gone.
    function A.reset() aim, display = {on = false}, nil end
    return A
end
