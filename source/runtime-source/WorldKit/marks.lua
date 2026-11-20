-- Marks: bright dots and lines drawn on the screen over the level (seen through walls), at 3D points
-- projected again on every update.
return function(R, C, K)
    local valid = K.valid
    function K.newMarks()
        local M = { level = nil, w = nil, root = nil, items = {}, want = {} }
        local function ensure(pc)
            local level = K.levelKey()
            if M.level ~= level then M.level, M.w, M.items = level, nil, {} end
            if M.w and valid(M.w) then return true end
            local w, tree, root = K.hostWidget(pc)
            if not w then return false end
            w:SetVisibility(3)
            w:AddToViewport(110)
            M.w, M.tree, M.root, M.items = w, tree, root, {}
            return true
        end
        local function item(key, kind)
            local it = M.items[key]
            if it then return it end
            local outer, inner = K.construct("Border", M.tree), K.construct("Border", M.tree)
            if not (outer and inner) then return nil end
            for _, b in ipairs({ outer, inner }) do
                b:SetVisibility(3)
                b.Background.DrawAs = 4                       -- rounded box
                b.Background.OutlineSettings.RoundingType = 1  -- round ends = circle
            end
            outer:SetPadding({ Left = 2, Top = 2, Right = 2, Bottom = 2 })
            outer:SetContent(inner)
            local slot = M.root:AddChildToCanvas(outer)
            it = { outer = outer, inner = inner, slot = slot, kind = kind, shown = true }
            M.items[key] = it
            return it
        end
        -- list of { key, pos={X,Y,Z}, color, size(px), kind="dot" } or { key, a=pos, b=pos, color, size, kind="line" }
        function M:set(list) self.want = list or {} end
        local function finite(v) return type(v) == "number" and v == v and v > -1e7 and v < 1e7 end
        local function project(pc, p)
            local out = {}
            if pc:ProjectWorldLocationToScreen(p, out, false) and finite(out.X) and finite(out.Y) then return out.X, out.Y end
        end
        -- keep a line inside an area around the screen (Liang-Barsky); points far off screen made huge widgets
        local function clip(ax, ay, bx, by, x0, y0, x1, y1)
            local t0, t1, dx, dy = 0, 1, bx - ax, by - ay
            for _, e in ipairs({ { -dx, ax - x0 }, { dx, x1 - ax }, { -dy, ay - y0 }, { dy, y1 - ay } }) do
                local pp, q = e[1], e[2]
                if pp == 0 then
                    if q < 0 then return nil end
                else
                    local r = q / pp
                    if pp < 0 then if r > t1 then return nil elseif r > t0 then t0 = r end
                    else if r < t0 then return nil elseif r < t1 then t1 = r end end
                end
            end
            return ax + t0 * dx, ay + t0 * dy, ax + t1 * dx, ay + t1 * dy
        end
        function M:update(pc)
            if not pc then return end
            if #self.want == 0 and not self.w then return end
            if not ensure(pc) then return end
            local layout = K.libs().layout
            local sc = layout:GetViewportScale(pc)
            local v = layout:GetViewportSize(pc)
            local vw, vh = v.X, v.Y
            -- (a mark already on screen whose place, size and the camera did not change stays as drawn:
            -- nothing is projected or moved while the view stands still)
            local cam = pc.PlayerCameraManager
            local cl, cr = cam:GetCameraLocation(), cam:GetCameraRotation()
            local view = table.concat({ cl.X, cl.Y, cl.Z, cr.Pitch, cr.Yaw, cr.Roll, vw, vh, sc }, " ")
            local still = view == self.view
            self.view = view
            local function same(a, b) return a and b and a.X == b.X and a.Y == b.Y and a.Z == b.Z end
            local used = {}
            for _, m in ipairs(self.want) do
                local it = item(m.key, m.kind)
                if it and still and it.shown and it.size == m.size and (m.kind == "line" and same(it.a, m.a) and same(it.b, m.b) or m.kind ~= "line" and same(it.pos, m.pos)) then
                    used[m.key] = true
                    if it.color ~= m.color then it.color = m.color; it.inner:SetBrushColor(m.color) end
                elseif it then
                    it.size, it.pos, it.a, it.b = m.size, m.pos, m.a, m.b
                    local okDraw = false
                    if m.kind == "line" then
                        local ax, ay = project(pc, m.a)
                        local bx, by = project(pc, m.b)
                        if ax and bx then ax, ay, bx, by = clip(ax, ay, bx, by, -vw, -vh, 2 * vw, 2 * vh) end
                        if ax and bx then
                            ax, ay, bx, by = ax / sc, ay / sc, bx / sc, by / sc
                            local len = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
                            local th = m.size or 3
                            if len > 1 then
                                do
                                    it.slot:SetSize({ X = len, Y = th + 2 })
                                    it.slot:SetPosition({ X = (ax + bx) / 2 - len / 2, Y = (ay + by) / 2 - (th + 2) / 2 })
                                    it.outer:SetRenderTransformPivot({ X = 0.5, Y = 0.5 })
                                    it.outer:SetRenderTransformAngle(math.deg(math.atan(by - ay, bx - ax)))
                                    it.outer:SetPadding({ Left = 0, Top = 1, Right = 0, Bottom = 1 })
                                end
                                okDraw = true
                            end
                        end
                    else
                        local x, y = project(pc, m.pos)
                        if x and (x < -vw or x > 2 * vw or y < -vh or y > 2 * vh) then x = nil end
                        if x then
                            local s = m.size or 10
                            it.slot:SetSize({ X = s + 4, Y = s + 4 })
                            it.slot:SetPosition({ X = x / sc - (s + 4) / 2, Y = y / sc - (s + 4) / 2 })
                            okDraw = true
                        end
                    end
                    if okDraw then
                        used[m.key] = true
                        if it.color ~= m.color then
                            it.color = m.color
                            it.inner:SetBrushColor(m.color)
                            it.outer:SetBrushColor({ R = 0, G = 0, B = 0, A = 0.75 })
                        end
                        if not it.shown then it.shown = true; it.outer:SetVisibility(3) end
                    end
                end
            end
            for k, it in pairs(self.items) do
                if not used[k] and it.shown then it.shown = false; it.outer:SetVisibility(1) end
            end
        end
        function M:clear()
            self.want = {}
            for _, it in pairs(self.items) do if it.shown then it.shown = false; it.outer:SetVisibility(1) end end
        end
        return M
    end
end
