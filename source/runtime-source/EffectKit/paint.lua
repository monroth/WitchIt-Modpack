-- Colours of meshes and decals, flat unlit colours, and 3D dots.
return function(R, C, E)
    local function find(path) return StaticFindObject(path) end
    local function asset(path) return R.valid(R.native.load_asset(path)) end
    local function set(mid, param, color, scalars)
        mid:SetVectorParameterValue(FName(param), color)
        for name, value in pairs(scalars or {}) do mid:SetScalarParameterValue(FName(name), value) end
    end
    function E.decal(decal, material, color, opts)
        opts = opts or {}
        local mid = find('/Script/Engine.Default__KismetMaterialLibrary'):CreateDynamicMaterialInstance(decal, material, FName('None'), 0)
        set(mid, opts.param or 'Color', color, opts.scalars)
        decal:SetDecalMaterial(mid)
        return mid
    end
    function E.paint(component, color, opts)
        opts = opts or {}
        local param = opts.param or 'Color'
        if not opts.material then
            -- (the engine makes each slot's instance itself)
            component:SetVectorParameterValueOnMaterials(FName(param), {X = color.R, Y = color.G, Z = color.B})
            for name, value in pairs(opts.scalars or {}) do component:SetScalarParameterValueOnMaterials(FName(name), value) end
            return {}
        end
        local mids = {}
        for slot = 0, component:GetNumMaterials() - 1 do
            mids[#mids + 1] = component:CreateDynamicMaterialInstance(slot, opts.material, FName('None'))
            set(mids[#mids], param, color, opts.scalars)
        end
        return mids
    end

    -- Flat: the engine's widget pass-through material (unlit: a texture times a tint), fed white.
    function E.unlit(component, color)
        component:SetCastShadow(false)
        local mid = component:CreateDynamicMaterialInstance(0, asset('/Engine/EngineMaterials/Widget3DPassThrough_Opaque.Widget3DPassThrough_Opaque'), FName('None'))
        mid:SetTextureParameterValue(FName('SlateUI'), asset('/Engine/EngineResources/WhiteSquareTexture.WhiteSquareTexture'))
        mid:SetVectorParameterValue(FName('TintColorAndOpacity'), {R = color.R, G = color.G, B = color.B, A = 1})
        return mid
    end

    E.colors = {
        pink = {R = 1, G = .15, B = .75, A = 1}, blue = {R = .15, G = .45, B = 1, A = 1},
        green = {R = .2, G = 1, B = .35, A = 1}, yellow = {R = 1, G = .85, B = .1, A = 1},
    }
    local function spawnDot()
        local statics = find('/Script/Engine.Default__GameplayStatics')
        local xf = {Rotation = {X = 0, Y = 0, Z = 0, W = 1}, Translation = {X = 0, Y = 0, Z = -100000}, Scale3D = {X = .05, Y = .05, Z = .05}}
        local a = R.valid(statics:BeginDeferredActorSpawnFromClass(C.session().world, find('/Script/Engine.StaticMeshActor'), xf, 1, nil, 0))
        if not a then return end
        statics:FinishSpawningActor(a, xf, 0)
        a:SetActorEnableCollision(false)
        local c = a.StaticMeshComponent
        c:SetMobility(2)
        c:SetStaticMesh(asset('/Engine/BasicShapes/Sphere.Sphere'))
        c:SetCollisionEnabled(0)
        return {actor = a, component = c}
    end
    function E.dots()
        local D = {level = nil, dots = {}, used = {}}
        function D:begin(level)
            if self.level ~= level then self.dots, self.level = {}, level end   -- (another level's are gone with it)
            self.used = {}
        end
        function D:dot(key, at, color, size)
            local d = self.dots[key]
            if d and not R.valid(d.actor) then d = nil end
            if not d then d = spawnDot(); if not d then return end; self.dots[key] = d end
            self.used[key] = true
            local s = (size or 5) / 100
            d.actor:K2_TeleportTo(at, {Pitch = 0, Yaw = 0, Roll = 0})
            d.actor:SetActorScale3D({X = s, Y = s, Z = s})
            d.actor:SetActorHiddenInGame(false)
            if d.color ~= color then
                if d.mid then d.mid:SetVectorParameterValue(FName('TintColorAndOpacity'), {R = color.R, G = color.G, B = color.B, A = 1})
                else d.mid = E.unlit(d.component, color) end
                d.color = color
            end
        end
        function D:finish()
            for key, d in pairs(self.dots) do
                if not self.used[key] and R.valid(d.actor) then d.actor:SetActorHiddenInGame(true) end
            end
        end
        function D:clear()
            for _, d in pairs(self.dots) do if R.valid(d.actor) then d.actor:K2_DestroyActor() end end
            self.dots = {}
        end
        return D
    end
end
