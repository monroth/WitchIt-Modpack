-- The mouse and the camera in the level: traces into it, the point in the middle of the screen, and
-- the clicks in the level an editor claims (K.claimWorld). Also the blank host widget the screen
-- helpers draw on.
return function(R, C, K)
    local valid, M = K.valid, K.M
    local libs = {}
    function K.libs()
        libs.layout = libs.layout or StaticFindObject("/Script/UMG.Default__WidgetLayoutLibrary")
        libs.system = libs.system or StaticFindObject("/Script/Engine.Default__KismetSystemLibrary")
        libs.math = libs.math or StaticFindObject("/Script/Engine.Default__KismetMathLibrary")
        libs.statics = libs.statics or StaticFindObject("/Script/Engine.Default__GameplayStatics")
        return libs
    end

    -- ---------------------------------------------------------------- widgets made by hand
    local fontObj = nil
    function K.font(size)
        if fontObj == nil then fontObj = K.class(C.PIXEL_FONT) or false end
        if fontObj then return { FontObject = fontObj, TypefaceFontName = FName("Font"), Size = size } end
    end
    function K.construct(name, outer)
        local c = StaticFindObject("/Script/UMG." .. name)
        if not valid(c) then return nil end
        return R.valid(StaticConstructObject(c, outer))
    end
    -- A game widget emptied of its own texts, as a full-screen canvas: widget, tree, root.
    local HOST_CLASS = C.HOST_WIDGET
    function K.hostWidget(pc)
        local w = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary"):Create(pc, K.class(HOST_CLASS), pc)
        local tree = w.WidgetTree
        local root = tree.RootWidget
        root:ClearChildren()   -- removes the "Witch It Beta Version" texts of the host widget
        return w, tree, root
    end

    -- ---------------------------------------------------------------- the shield
    -- A see-through button over the whole screen with a label at the top: {widget, button, text}.
    -- A hint at the top of the screen (what a click in the level does now); it takes no clicks.
    function K.hint(pc, label)
        local w, tree, root = K.hostWidget(pc)
        if not w then return nil end
        local frame, tb = K.construct("Border", tree), K.construct("TextBlock", tree)
        if not (frame and tb) then return nil end
        tb:SetFont(K.font(16))
        tb:SetColorAndOpacity({ SpecifiedColor = { R = 1, G = 0.85, B = 0.35, A = 1 }, ColorUseRule = 0 })
        tb:SetText(FText(label or ""))
        frame:SetBrushColor({ R = 0, G = 0, B = 0, A = 0.6 })
        frame:SetPadding({ Left = 10, Top = 4, Right = 10, Bottom = 4 })
        frame:SetContent(tb)
        local slot = root:AddChildToCanvas(frame)
        slot:SetAutoSize(true)
        slot:SetAnchors({ Minimum = { X = 0.5, Y = 0 }, Maximum = { X = 0.5, Y = 0 } })
        slot:SetAlignment({ X = 0.5, Y = 0 })
        slot:SetPosition({ X = 0, Y = 64 })
        w:SetVisibility(3)   -- (hit-test invisible: the clicks go on)
        w:AddToViewport(100)
        return { widget = w, text = tb }
    end
    -- Clicks in the level for editors: at the press of the game's click (its Fire input) an editor that
    -- claims it (claim() true: its tool is armed, or its handle is under the mouse) takes it instead
    -- of the game's selection, until the button is let go. No shield over the screen, no mouse lock:
    -- every other click is the game's, and clicks on windows are the windows'.
    local claims = {}
    function K.claimWorld(claim) claims[#claims + 1] = claim end
    -- A press where block() holds (the mouse over a window of the mods) is no one's in the level: the
    -- game neither selects nor deselects with it, and no editor takes it (live 11-20: a click on the
    -- colour window deselected the object whose colour it was).
    local blocks = {}
    function K.blockWorld(block) blocks[#blocks + 1] = block end
    -- Whose the press now is (one fact, audit D10): 'blocked' (over a window of the mods), 'held' (an
    -- editor claimed it), nil (the game's, or the button is up).
    local owner = nil
    -- (held until the button is up on the mouse itself: the game does not always send the release,
    -- e.g. while the brush paints, and a stroke stayed open until the tool was left, live VM2 11-20)
    function K.worldPressed()
        if owner == 'held' and not R.native.key_down(R.codes.LEFT_MOUSE) then owner = nil end
        return owner == 'held'
    end
    local FIRE = C.CREATIVE_PC .. ":InpActEvt_Fire_K2Node_InputActionEvent_"
    local pressed_at = -1
    -- Each press of the click that reaches the level has a number; an editor asks newPress(tag) and
    -- gets true once per press while it is held (audit 11-20: each tool kept its own "was the button
    -- down" and copied it by hand when the gizmo held the click). takePress(tag) counts the press held
    -- now as taken (by that editor; no tag: by every one - the gizmo holds it).
    local presses, seen, taken = 0, {}, -1
    function K.newPress(tag)
        if not K.worldPressed() or taken == presses or seen[tag] == presses then return false end
        seen[tag] = presses
        return true
    end
    function K.takePress(tag) if tag then seen[tag] = presses else taken = presses end end
    -- Is the press held now taken by every editor (the gizmo holds it, until it is let go)?
    function K.taken() return taken == presses and K.worldPressed() end
    local function fire()
        -- (the button down: a press; up: its release)
        if R.native.key_down(R.codes.LEFT_MOUSE) then
            -- (both Fire events come for one press: it is decided once. A press later than that is a new
            -- one, the button was let go in between: what the last press held or blocked is over even
            -- when its release never came - live 11-20 a blocked press without a release swallowed every
            -- later click in the level: nothing could be placed or selected)
            if owner and os.clock() - pressed_at < 0.05 then return true end
            pressed_at, owner = os.clock(), nil
            for _, block in ipairs(blocks) do
                if block() then owner = 'blocked'; return true end
            end
            presses = presses + 1
            for _, claim in ipairs(claims) do
                if claim() then owner = 'held'; return true end
            end
        elseif owner then owner = nil; return true end
    end
    R.pre(FIRE .. "7", fire)
    R.pre(FIRE .. "8", fire)
    R.on("world_end", function() owner = nil end)

    -- ---------------------------------------------------------------- traces
    -- A line trace a -> b ({X,Y,Z}): { x,y,z, nx,ny,nz } where it hits, or nil.
    function K.trace(pc, a, b, ignore)
        local L = K.libs()
        local hit = {}
        local c0 = { R = 0, G = 0, B = 0, A = 0 }
        if not L.system:LineTraceSingle(pc, a, b, 0, false, ignore or {}, 0, hit, true, c0, c0, 0.0) then return nil end
        local l, n = hit.ImpactPoint, hit.ImpactNormal
        return { x = l.X, y = l.Y, z = l.Z, nx = n.X, ny = n.Y, nz = n.Z }
    end
    -- The ray under the mouse: start, direction.
    function K.mouseRay(pc)
        local L = K.libs()
        local mp = L.layout:GetMousePositionOnViewport(pc)
        local sc = L.layout:GetViewportScale(pc)
        local wl, wd = {}, {}
        if not pc:DeprojectScreenPositionToWorld(mp.X * sc, mp.Y * sc, wl, wd) then return nil end
        return { X = wl.X, Y = wl.Y, Z = wl.Z }, { X = wd.X, Y = wd.Y, Z = wd.Z }
    end
    function K.traceMouse(pc)
        local s, d = K.mouseRay(pc)
        if not s then return nil end
        return K.trace(pc, s, { X = s.X + d.X * 200000, Y = s.Y + d.Y * 200000, Z = s.Z + d.Z * 200000 })
    end
    -- The surface in the middle of the screen (or 6 m in front of the camera).
    function K.screenPoint(pc)
        local cam = pc.PlayerCameraManager
        local l, r = cam:GetCameraLocation(), cam:GetCameraRotation()
        local f = M.axes({ Pitch = r.Pitch, Yaw = r.Yaw, Roll = 0 })
        local from = M.v3(l.X, l.Y, l.Z)
        local h = K.trace(pc, from, M.vadd(from, M.vmul(f, 20000)))
        return h and M.v3(h.x, h.y, h.z) or M.vadd(from, M.vmul(f, 600))
    end
end
