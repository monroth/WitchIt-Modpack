-- What is under the crosshair: the first thing the camera ray meets among blocking geometry,
-- lights, sounds and effects (a 60 cm sphere each) and mesh triangles.
-- Effects and meshes come from a list made once per edit state and again after a change;
-- a sphere test leaves few instances for the exact test.
return function(R, Objects, Instances)
    local P = {}
    local REACH, EFFECT = 50000, 60

    local function candidates(s)
        if s.pick_list then return s.pick_list end
        local list = {effects = {}, instances = {}, meshes = {}}
        for _, class in ipairs(Objects.effects) do
            for _, a in ipairs(R.find_all(class)) do
                if a:HasAnyFlags(Objects.LOADED) then
                    list.effects[#list.effects + 1] = {actor = a, at = a:K2_GetActorLocation()}
                end
            end
        end
        for _, c in ipairs(R.find_all('/Script/Engine.InstancedStaticMeshComponent')) do
            local mesh = c:HasAnyFlags(Objects.LOADED) and R.valid(c.StaticMesh)
            if mesh and Instances.supported(Objects.path(mesh)) then
                local path = Objects.path(mesh)
                local radius = Instances.radius(path)
                for i = 0, c:GetInstanceCount() - 1 do
                    local t = Instances.transform(c, i, true)
                    local sc = t.Scale3D
                    local scale = math.max(math.abs(sc.X), math.abs(sc.Y), math.abs(sc.Z))
                    list.instances[#list.instances + 1] =
                        {c = c, i = i, mesh = path, t = t, at = t.Translation, r = radius * scale}
                end
            end
        end
        for _, c in ipairs(R.find_all('/Script/Engine.StaticMeshComponent')) do
            local mesh = c:HasAnyFlags(Objects.LOADED) and R.valid(c.StaticMesh)
            local a = mesh and R.valid(c:GetOwner())
            if a and a:HasAnyFlags(Objects.LOADED) and not c:IsA('/Script/Engine.InstancedStaticMeshComponent')
                and c.bVisible and not c.bHiddenInGame and not a.bHidden then
                local path = Objects.path(mesh)
                if Instances.supported(path) then
                    local t = c:K2_GetComponentToWorld()
                    local sc = t.Scale3D
                    local scale = math.max(math.abs(sc.X), math.abs(sc.Y), math.abs(sc.Z))
                    list.meshes[#list.meshes + 1] = {c = c, actor = a, mesh = path, t = t,
                        at = t.Translation, r = Instances.radius(path) * scale}
                end
            end
        end
        s.pick_list = list
        return list
    end
    -- The list is made again after the hidden set changes.
    function P.changed(s) s.pick_list = nil end

    function P.under(pc, s)
        Instances.load(s.world:GetFName():ToString())
        local camera = pc.PlayerCameraManager
        local origin, rotation = camera:GetCameraLocation(), camera:GetCameraRotation()
        local pitch, yaw = math.rad(rotation.Pitch), math.rad(rotation.Yaw)
        local ray = {X = math.cos(pitch) * math.cos(yaw), Y = math.cos(pitch) * math.sin(yaw), Z = math.sin(pitch)}
        local finish = {X = origin.X + ray.X * REACH, Y = origin.Y + ray.Y * REACH, Z = origin.Z + ray.Z * REACH}
        local hit, colour = {}, {R = 0, G = 0, B = 0, A = 0}
        local blocked = StaticFindObject('/Script/Engine.Default__KismetSystemLibrary'):LineTraceSingle(
            pc, origin, finish, 0, true, {}, 0, hit, true, colour, colour, 0)
        local best, row = blocked and hit.Distance or REACH, nil
        if blocked then
            -- FHitResult.Component is reflected as FWeakObjectPtr.
            local c = R.valid(hit.Component:Get())
            local a = c and R.valid(c:GetOwner())
            if a and a:HasAnyFlags(Objects.LOADED) then
                if c:IsA('/Script/Engine.InstancedStaticMeshComponent') and hit.Item >= 0 then
                    row = Instances.row(c, hit.Item, Objects.path(c))
                elseif Objects.allowed(a) then row = Objects.row(a)
                else row = Objects.componentRow(a, c) end
            end
        end
        -- Distance along the ray to a sphere, or nil when the ray misses it.
        local function sphere(at, r)
            local dx, dy, dz = at.X - origin.X, at.Y - origin.Y, at.Z - origin.Z
            local along = dx * ray.X + dy * ray.Y + dz * ray.Z
            local off = dx * dx + dy * dy + dz * dz - along * along
            if off > r * r or along + r < 0 then return end
            return math.max(0, along - math.sqrt(r * r - off))
        end
        local list = candidates(s)
        for _, e in ipairs(list.effects) do
            local distance = sphere(e.at, EFFECT)
            if distance and distance < best and R.valid(e.actor) then best, row = distance, Objects.row(e.actor) end
        end
        for _, n in ipairs(list.instances) do
            local near = sphere(n.at, n.r)
            if near and near < best then
                local distance = Instances.ray({mesh = n.mesh, worldTransform = n.t}, origin, ray, best)
                if distance then best, row = distance, Instances.row(n.c, n.i, Objects.path(n.c)) end
            end
        end
        for _, n in ipairs(list.meshes) do
            local near = sphere(n.at, n.r)
            if near and near < best and R.valid(n.c) and R.valid(n.actor) then
                local distance = Instances.ray({mesh = n.mesh, worldTransform = n.t}, origin, ray, best)
                if distance then
                    best = distance
                    if Objects.allowed(n.actor) then row = Objects.row(n.actor)
                    else row = Objects.componentRow(n.actor, n.c) end
                end
            end
        end
        return row
    end
    return P
end
