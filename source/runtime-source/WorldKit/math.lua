-- Vectors {X,Y,Z}, rotations {Pitch,Yaw,Roll} (degrees, the engine's conventions), 3x3 matrices
-- {X,Y,Z} (columns: the local axes in the world) and transforms as plain tables. Never keep the
-- structs the game returns: their memory can be gone a moment later; copy them into these.
local rad, deg = math.rad, math.deg
local function v3(x, y, z) return { X = x, Y = y, Z = z } end
local function vcopy(v) return v3(v.X, v.Y, v.Z) end
local function vadd(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
local function vsub(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
local function vmul(a, s) return v3(a.X * s, a.Y * s, a.Z * s) end
local function vmul3(a, b) return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z) end
local function vdot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
local function vcross(a, b) return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
local function vlen(a) return math.sqrt(vdot(a, a)) end
local function vnorm(a) local l = vlen(a); if l < 1e-9 then return v3(0, 0, 1) end; return vmul(a, 1 / l) end
local function axes(r)
    local SP, CP = math.sin(rad(r.Pitch)), math.cos(rad(r.Pitch))
    local SY, CY = math.sin(rad(r.Yaw)), math.cos(rad(r.Yaw))
    local SR, CR = math.sin(rad(r.Roll)), math.cos(rad(r.Roll))
    return v3(CP * CY, CP * SY, SP),
        v3(SR * SP * CY - CR * SY, SR * SP * SY + CR * CY, -SR * CP),
        v3(-(CR * SP * CY + SR * SY), CY * SR - CR * SP * SY, CR * CP)
end
local function fromAxes(X, Y, Z)
    local pitch = deg(math.atan(X.Z, math.sqrt(X.X * X.X + X.Y * X.Y)))
    local yaw = deg(math.atan(X.Y, X.X))
    local _, sy = axes({ Pitch = pitch, Yaw = yaw, Roll = 0 })
    local roll = deg(math.atan(vdot(Z, sy), vdot(Y, sy)))
    return { Pitch = pitch, Yaw = yaw, Roll = roll }
end
-- 3x3 matrices {X=col1, Y=col2, Z=col3} (columns = local axes in world)
local function mFromRot(r) local X, Y, Z = axes(r); return { X = X, Y = Y, Z = Z } end
local function mToRot(m) return fromAxes(m.X, m.Y, m.Z) end
local function mApply(m, v) return vadd(vadd(vmul(m.X, v.X), vmul(m.Y, v.Y)), vmul(m.Z, v.Z)) end
local function mMul(a, b) return { X = mApply(a, b.X), Y = mApply(a, b.Y), Z = mApply(a, b.Z) } end
local function mT(m) return { X = v3(m.X.X, m.Y.X, m.Z.X), Y = v3(m.X.Y, m.Y.Y, m.Z.Y), Z = v3(m.X.Z, m.Y.Z, m.Z.Z) } end
local MI = { X = v3(1, 0, 0), Y = v3(0, 1, 0), Z = v3(0, 0, 1) }
local function mBetween(a, b)
    a, b = vnorm(a), vnorm(b)
    local c = vdot(a, b)
    if c > 0.99999 then return MI end
    if c < -0.99999 then
        local p = math.abs(a.X) < 0.9 and v3(1, 0, 0) or v3(0, 1, 0)
        local ax = vnorm(vcross(a, p))
        local function rot(v) return vsub(vmul(ax, 2 * vdot(ax, v)), v) end
        return { X = rot(MI.X), Y = rot(MI.Y), Z = rot(MI.Z) }
    end
    local v = vcross(a, b)
    local k = 1 / (1 + c)
    local function rot(x) local vx = vcross(v, x); return vadd(vadd(x, vx), vmul(vcross(v, vx), k)) end
    return { X = rot(MI.X), Y = rot(MI.Y), Z = rot(MI.Z) }
end
local function mirrorRot(r, axis)
    local X, Y, Z = axes(r)
    local function m(v)
        if axis == "X" then return v3(-v.X, v.Y, v.Z) elseif axis == "Y" then return v3(v.X, -v.Y, v.Z) end
        return v3(v.X, v.Y, -v.Z)
    end
    return fromAxes(m(X), vmul(m(Y), -1), m(Z))
end
local function quat(r)
    local h = math.pi / 360
    local SP, CP = math.sin(r.Pitch * h), math.cos(r.Pitch * h)
    local SY, CY = math.sin(r.Yaw * h), math.cos(r.Yaw * h)
    local SR, CR = math.sin(r.Roll * h), math.cos(r.Roll * h)
    return { X = CR * SP * SY - SR * CP * CY, Y = -CR * SP * CY - SR * CP * SY, Z = CR * CP * SY - SR * SP * CY, W = CR * CP * CY + SR * SP * SY }
end
local function transform(loc, rot, scale)
    return { Rotation = quat(rot), Translation = { X = loc.X, Y = loc.Y, Z = loc.Z }, Scale3D = { X = scale.X, Y = scale.Y, Z = scale.Z } }
end
return {v3 = v3, vcopy = vcopy, vadd = vadd, vsub = vsub, vmul = vmul, vmul3 = vmul3, vdot = vdot, vcross = vcross, vlen = vlen, vnorm = vnorm, axes = axes, fromAxes = fromAxes, mFromRot = mFromRot, mToRot = mToRot, mApply = mApply, mMul = mMul, mT = mT, mBetween = mBetween, mirrorRot = mirrorRot, MI = MI, quat = quat, transform = transform}
