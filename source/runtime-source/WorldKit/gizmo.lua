--[[
  WorldKit gizmo: K.newGizmo(opts) for an editor's own points.

  The editor gives a list of "handles" (points they use: the custom contact point, the first copy of Copies, the
  fixed curve points, the measuring points ...). The gizmo is drawn on the screen (like the other markers) at
  the picked handle:
    red / green / blue arrows   drag = move along X / Y / Z (the object's own axes where the point belongs to it)
    middle dot                  drag = slide it over the surface under the mouse
    rings (handles that turn)   drag = turn around the handle's own X (red) / Y (green) / Z (blue)
    white arrow                 the handle's front (+X) - which way it faces
  Clicking another handle's dot picks it. With "Click in the level moves the point" on, a click anywhere else
  puts the picked handle there. Its clicks are claimed from the game's (WorldKit's claimed world clicks) only over its parts.

  handle = { id, pos = {X,Y,Z}, frame = rotator or nil, label,
             move = function(newPos), turn = function(newRotator), done = function() }
  opts: snap() -> step (cm), angle (degrees) for dragging (0: free); click() -> true when a click in
  the level moves the picked point.
  Returns { update(pc, handles) -> marks, reset(), dragging(), active() }.
]]
return function(R, Core, K)
function K.newGizmo(opts)
local U, M = K, K.M
local v3, vadd, vsub, vmul, vdot, vcross, vlen, vnorm = M.v3, M.vadd, M.vsub, M.vmul, M.vdot, M.vcross, M.vlen, M.vnorm
local mFromRot, mToRot = M.mFromRot, M.mToRot

local G = { active = nil, drag = nil, wasDown = false, hover = nil, changed = false, off = false }
local RED, GRN, BLU = { R = 1, G = 0.25, B = 0.25, A = 1 }, { R = 0.25, G = 1, B = 0.35, A = 1 }, { R = 0.3, G = 0.55, B = 1, A = 1 }
local HOT, WHITE, GREY = { R = 1, G = 0.95, B = 0.2, A = 1 }, { R = 1, G = 1, B = 1, A = 1 }, { R = 0.75, G = 0.75, B = 0.8, A = 1 }
local AXES = { { "x", v3(1, 0, 0), RED }, { "y", v3(0, 1, 0), GRN }, { "z", v3(0, 0, 1), BLU } }
local RING_SEG = 20

local WLL
local function mousePx(pc)
    WLL = WLL or StaticFindObject("/Script/UMG.Default__WidgetLayoutLibrary")
    local mp = WLL:GetMousePositionOnViewport(pc)
    local sc = WLL:GetViewportScale(pc)
    return mp.X * sc, mp.Y * sc
end
local function screen(pc, p)
    local out = {}
    if pc:ProjectWorldLocationToScreen(p, out, false) then return out.X, out.Y end
end
local function camLoc(pc)
    local c = pc.PlayerCameraManager:GetCameraLocation()
    return v3(c.X, c.Y, c.Z)
end
local function segDist(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local L2 = dx * dx + dy * dy
    local t = L2 > 0 and math.max(0, math.min(1, ((px - ax) * dx + (py - ay) * dy) / L2)) or 0
    local qx, qy = ax + dx * t, ay + dy * t
    return math.sqrt((px - qx) ^ 2 + (py - qy) ^ 2)
end
-- rotate v around unit axis n by angle th (radians)
local function rotAround(v, n, th)
    local c, s = math.cos(th), math.sin(th)
    return vadd(vadd(vmul(v, c), vmul(vcross(n, v), s)), vmul(n, vdot(n, v) * (1 - c)))
end
local function perp(n)
    local u = vnorm(vcross(n, math.abs(n.Z) < 0.9 and v3(0, 0, 1) or v3(1, 0, 0)))
    return u, vcross(n, u)
end
local function ringPts(p, n, r)
    local u, w = perp(n)
    local out = {}
    for i = 0, RING_SEG do
        local a = i / RING_SEG * 2 * math.pi
        out[#out + 1] = vadd(p, vadd(vmul(u, math.cos(a) * r), vmul(w, math.sin(a) * r)))
    end
    return out
end
local function frameAxes(rot)
    local m = mFromRot(rot)
    return { m.X, m.Y, m.Z }
end
local function planeHit(pc, p, n)
    local s, d = U.mouseRay(pc)
    if not s then return nil end
    local den = vdot(d, n)
    if math.abs(den) < 0.03 then return nil end
    local t = vdot(vsub(p, s), n) / den
    if t <= 0 then return nil end
    return vadd(s, vmul(d, t))
end
local function snapStep() local step = opts.snap(); return math.max(0, step) end
local function snapAng() local _, angle = opts.snap(); return math.max(0, angle) end

-- the parts of the gizmo at handle h (world positions); size = constant on the screen
local function parts(pc, h)
    local cam = camLoc(pc)
    local L = 100
    if cam then L = math.max(20, vlen(vsub(h.pos, cam)) * 0.12) end
    local P = { L = L, axes = {}, rings = {} }
    local A = h.axes and frameAxes(h.axes) or nil   -- the object's own axes (X = its front) when the handle has them
    for i, a in ipairs(AXES) do
        local dir = A and A[i] or a[2]
        P.axes[#P.axes + 1] = { id = a[1], dir = dir, tip = vadd(h.pos, vmul(dir, L)), color = a[3] }
    end
    if h.frame and h.turn then
        local F = frameAxes(h.frame)
        for i, a in ipairs(AXES) do P.rings[#P.rings + 1] = { id = "r" .. a[1], n = F[i], pts = ringPts(h.pos, F[i], L * 0.7), color = a[3] } end
        P.front = vadd(h.pos, vmul(F[1], L * 0.5))
    end
    return P
end

-- which part of the picked handle is under the mouse (px): "free", "x", "rx" ... or nil
local function pick(pc, h, P, mx, my)
    local cx, cy = screen(pc, h.pos)
    if not cx then return nil end
    if math.sqrt((mx - cx) ^ 2 + (my - cy) ^ 2) < 11 then return "free" end
    local best, bd = nil, 9
    for _, a in ipairs(P.axes) do
        local tx, ty = screen(pc, a.tip)
        if tx then local d = segDist(mx, my, cx, cy, tx, ty); if d < bd then best, bd = a.id, d end end
    end
    for _, r in ipairs(P.rings) do
        local px, py
        for _, q in ipairs(r.pts) do
            local x, y = screen(pc, q)
            if x and px then local d = segDist(mx, my, px, py, x, y); if d < bd then best, bd = r.id, d end end
            px, py = x, y
        end
    end
    return best
end

local function startDrag(pc, h, P, part, mx, my)
    local d = { part = part, id = h.id, p0 = v3(h.pos.X, h.pos.Y, h.pos.Z), m0x = mx, m0y = my, L = P.L }
    if part == "x" or part == "y" or part == "z" then
        for _, a in ipairs(P.axes) do if a.id == part then d.dir = a.dir end end
        local ax, ay = screen(pc, d.p0)
        local bx, by = screen(pc, vadd(d.p0, vmul(d.dir, P.L)))
        if not (ax and bx) then return nil end
        d.sx, d.sy = bx - ax, by - ay
    elseif part:sub(1, 1) == "r" then
        for _, r in ipairs(P.rings) do if r.id == part then d.n = r.n end end
        d.frame0 = { Pitch = h.frame.Pitch, Yaw = h.frame.Yaw, Roll = h.frame.Roll }
        local q = planeHit(pc, d.p0, d.n)
        if not q then return nil end
        d.v0 = vsub(q, d.p0)
    end
    return d
end

local function dragTo(pc, h, mx, my)
    local d = G.drag
    if d.part == "free" then
        local hit = U.traceMouse(pc)
        if hit then h.move(v3(hit.x, hit.y, hit.z)); h.pos = v3(hit.x, hit.y, hit.z) end
    elseif d.dir then
        local s2 = d.sx * d.sx + d.sy * d.sy
        if s2 < 1 then return end
        local t = ((mx - d.m0x) * d.sx + (my - d.m0y) * d.sy) / s2 * d.L
        local st = snapStep()
        if st > 0 then t = math.floor(t / st + 0.5) * st end   -- moves in whole steps along the arrow
        local np = vadd(d.p0, vmul(d.dir, t))
        h.move(np); h.pos = np
    elseif d.n then
        local q = planeHit(pc, d.p0, d.n)
        if not q then return end
        local v = vsub(q, d.p0)
        if vlen(v) < 1e-3 or vlen(d.v0) < 1e-3 then return end
        local th = math.atan(vdot(d.n, vcross(d.v0, v)), vdot(d.v0, v))
        local sa = snapAng()
        if sa > 0 then th = math.rad(math.floor(math.deg(th) / sa + 0.5) * sa) end
        local F = frameAxes(d.frame0)
        local X, Y, Z = rotAround(F[1], d.n, th), rotAround(F[2], d.n, th), rotAround(F[3], d.n, th)
        local r = mToRot({ X = X, Y = Y, Z = Z })
        h.turn(r); h.frame = r
    end
    G.changed = true
end

local function marks(pc, h, P, out)
    local function dot(key, p, col, size) out[#out + 1] = { key = "gz" .. key, pos = p, color = col, size = size, kind = "dot" } end
    local function line(key, a, b, col, size) out[#out + 1] = { key = "gz" .. key, a = a, b = b, color = col, size = size, kind = "line" } end
    local hot = (G.drag and G.drag.part) or G.hover
    for _, a in ipairs(P.axes) do
        local c = hot == a.id and HOT or a.color
        line("ax" .. a.id, h.pos, a.tip, c, 4)
        dot("at" .. a.id, a.tip, c, 11)
    end
    for _, r in ipairs(P.rings) do
        local c = hot == r.id and HOT or r.color
        for i = 2, #r.pts do line(r.id .. i, r.pts[i - 1], r.pts[i], c, 3) end
    end
    if P.front then line("front", h.pos, P.front, WHITE, 4); dot("fronttip", P.front, WHITE, 8) end
    dot("mid", h.pos, hot == "free" and HOT or WHITE, 14)
end

-- every frame. handles: list (see top); pressed: left mouse on the mod's shield (nil: no shield).
-- returns: marks to draw, consumed (the click was the gizmo's), finished (a drag / set just ended)
local function update(pc, handles, pressed)
    local out = {}
    local byId = {}
    for _, h in ipairs(handles or {}) do byId[h.id] = h end
    if G.active and not byId[G.active] then G.active = nil end
    -- (put away by its panel's x - user 11-21: no point is picked until a dot is clicked)
    if not G.active and not G.off and handles and handles[1] then G.active = handles[1].id end
    local h = G.active and byId[G.active]
    if G.drag and h and G.drag.id == h.id and G.drag.pos then h.pos = G.drag.pos end
    -- (its handle gone during a drag: the drag ends as a drag ends - its handle told, the change finished;
    -- audit 11-20, it was dropped silently and the next drag reported this one's change)
    if not h then
        local finished = false
        if G.drag then
            finished, G.changed = G.changed, false
            local old = G.drag.handle
            G.drag = nil
            if old and old.done then old.done() end
        end
        -- (put away: a click on a point's dot picks it again)
        local consumed = false
        if G.off and handles then
            local mx, my = mousePx(pc)
            G.near = nil
            for _, o in ipairs(handles) do
                local x, y = screen(pc, o.pos)
                if mx and x and math.sqrt((mx - x) ^ 2 + (my - y) ^ 2) < 12 then G.near = o.id end
            end
            if pressed == true and not G.wasDown and G.near then G.active, G.off, consumed = G.near, false, true end
        end
        G.wasDown = pressed == true
        return out, consumed, finished
    end
    local mx, my = mousePx(pc)
    local P = parts(pc, h)
    local consumed, finished = false, false
    local down = pressed == true
    if G.drag then
        consumed = true
        if down and mx then
            dragTo(pc, h, mx, my)
            G.drag.pos = h.pos
            P = parts(pc, h)
        elseif not down then
            G.drag = nil; finished = G.changed; G.changed = false
            if h.done then h.done() end
        end
    else
        G.hover = mx and pick(pc, h, P, mx, my) or nil
        -- (another handle's dot under the mouse: a click picks it)
        G.near = nil
        for _, o in ipairs(handles) do
            local x, y = screen(pc, o.pos)
            if mx and x and o.id ~= G.active and math.sqrt((mx - x) ^ 2 + (my - y) ^ 2) < 12 then G.near = o.id end
        end
        if down and not G.wasDown and mx then
            if G.hover then
                G.drag = startDrag(pc, h, P, G.hover, mx, my)
                if G.drag then G.drag.handle = h end
                consumed = G.drag ~= nil   -- (no drag began: the press is not the gizmo's)
            else
                -- another handle's dot: pick it (or, a handle that is only a choice, choose it: picked())
                if G.near then
                    local o = byId[G.near]
                    if o and o.picked then o.picked() else G.active = G.near end
                    consumed, finished = true, o ~= nil and o.picked ~= nil
                end
                if not consumed and opts.click() then   -- click in the level: the picked point goes there
                    local hit = U.traceMouse(pc)
                    if hit then
                        h.move(v3(hit.x, hit.y, hit.z)); h.pos = v3(hit.x, hit.y, hit.z)
                        if h.done then h.done() end
                        consumed, finished = true, true
                    end
                end
            end
        end
    end
    G.wasDown = down
    marks(pc, h, P, out)
    for _, o in ipairs(handles) do   -- the other handles: small rings round their dots so they look clickable
        if o.id ~= G.active then out[#out + 1] = { key = "gzo" .. o.id, pos = o.pos, color = GREY, size = 9, kind = "dot" } end
    end
    return out, consumed, finished
end

local function reset() G.active, G.drag, G.hover, G.near, G.wasDown, G.off = nil, nil, nil, nil, false, false end
-- Put the gizmo away: no point picked, none moves, until a point's dot is clicked (its panel's x, user 11-21).
local function dismiss() G.active, G.drag, G.hover, G.near, G.off = nil, nil, nil, nil, true end
local function dragging() return G.drag ~= nil end
-- Whether a click in the level now is the gizmo's (a handle part or another handle's dot under the
-- mouse, a drag on, or "click in the level moves the point" with a point picked).
local function wants() return G.drag ~= nil or G.hover ~= nil or G.near ~= nil or (G.active ~= nil and opts.click()) end
return { update = update, reset = reset, dismiss = dismiss, dismissed = function() return G.off end, dragging = dragging, wants = wants, active = function() return G.active end }
end
end
