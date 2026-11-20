-- What can be hidden and how: whole scenery actors, single components of any placed
-- actor, and single foliage instances (instances.lua).
local M={}
-- The engine's flag of the objects a level brought (RF_WasLoaded): the level's own scenery.
M.LOADED=0x80000
-- Actors hidden whole: looks, collision, and their lights, sounds and effects. Effects have
-- nothing to hit; the aim finds them by their position.
local whole={
    {'/Script/Engine.StaticMeshActor'},
    {'/Script/Niagara.NiagaraActor',effect=true},
    {'/Script/Engine.Emitter',effect=true},
    {'/Script/Engine.PointLight',effect=true},
    {'/Script/Engine.SpotLight',effect=true},
    {'/Script/Engine.RectLight',effect=true},
    {'/Script/Engine.AmbientSound',effect=true},
    {'/Game/Environment/Island/B_Palm01.B_Palm01_C'},
    {'/Game/Environment/Island/B_Palm02.B_Palm02_C'},
    {'/Game/Environment/Island/B_Palm03.B_Palm03_C'},
    {'/Game/Environment/Island/B_Palm04.B_Palm04_C'},
    {'/Game/Environment/Island/B_Palm05.B_Palm05_C'},
    {'/Game/Environment/Island/B_Palm07.B_Palm07_C'},
    -- Spring pads built into a map (IslandsDawn): the creative tools cannot remove them.
    {'/Game/Blueprints/Skills/B_SpringPad.B_SpringPad_C'},
}
M.classes,M.effects={},{}
for _,row in ipairs(whole) do
    M.classes[#M.classes+1]=row[1]
    if row.effect then M.effects[#M.effects+1]=row[1] end
end
function M.path(o) return o:GetFullName():match('^%S+ (.+)$'):gsub('UEDPIE_%d+_','') end
-- Native arrays arrive either as TArray (ForEach) or, from function results, as Lua tables.
function M.values(a)
    local out={}
    if a.ForEach then a:ForEach(function(_,v) out[#out+1]=v:get() end)
    else for i,v in ipairs(a) do out[i]=v:get() end end
    return out
end
-- Scenery actors (of these classes or made from them: a mushroom spring pad is a spring pad)
-- are hidden whole; any other placed actor is hidden one component at a time.
function M.allowed(a)
    for _,path in ipairs(M.classes) do if a:IsA(path) then return true end end
    return false
end
function M.row(a) return {kind='actor',path=M.path(a)} end
function M.componentRow(a,c) return {kind='component',path=M.path(a),component=c:GetFName():ToString()} end
function M.component(actor,name)
    for _,c in ipairs(M.values(actor:K2_GetComponentsByClass(StaticFindObject('/Script/Engine.PrimitiveComponent')))) do
        if c:GetFName():ToString()==name then return c end
    end
end
local function title(name)
    return name:gsub('^SM_',''):gsub('^NS_',''):gsub('^BP_',''):gsub('^B_',''):gsub('(%l)(%u)','%1 %2'):gsub('_',' ')
end
function M.label(row)
    if row.kind=='instance' then return title(row.mesh:match('%.([^%.]+)$'))..' ['..row.index..']' end
    local actor=title(row.path:match('PersistentLevel%.(.+)$') or row.path)
    if row.kind=='component' then return actor..' · '..row.component end
    return actor
end
-- A hidden object keeps its place: a part that simulates physics (a spring pad's box) stops
-- while hidden, or with collision off it would fall through the ground and out of the world.
local function simulates(c) return c:IsA('/Script/Engine.PrimitiveComponent') and c.BodyInstance.bSimulatePhysics==true end
function M.capture(a)
    local s={actor=a,hidden=a.bHidden,collision=a.bActorEnableCollision,effects={},physics={}}
    local seen={}
    local function visit(c)
        local path=M.path(c)
        if seen[path] then return end
        seen[path]=true
        local r={component=c}
        if c:IsA('/Script/Engine.AudioComponent') then r.volume=c.VolumeMultiplier
        elseif c:IsA('/Script/Engine.LightComponent') then r.visible=c.bVisible
        elseif c:IsA('/Script/Engine.ParticleSystemComponent') or c:IsA('/Script/Niagara.NiagaraComponent') then
            r.visible=c.bVisible;r.active=c:IsActive()
        end
        if r.volume~=nil or r.visible~=nil then s.effects[#s.effects+1]=r end
        if simulates(c) then s.physics[#s.physics+1]=c end
        for _,child in ipairs(M.values(c.AttachChildren)) do visit(child) end
    end
    visit(a.RootComponent)
    return s
end
function M.hide(s)
    for _,c in ipairs(s.physics) do c:SetSimulatePhysics(false) end
    s.actor:SetActorHiddenInGame(true);s.actor:SetActorEnableCollision(false)
    for _,r in ipairs(s.effects) do local c=r.component
        if r.active~=nil then c:Deactivate() end
        if r.visible~=nil then c:SetVisibility(false,false) end
        if r.volume~=nil then c:SetVolumeMultiplier(0) end
    end
end
function M.restore(s)
    for _,r in ipairs(s.effects) do local c=r.component
        if r.volume~=nil then c:SetVolumeMultiplier(r.volume) end
        if r.visible~=nil then c:SetVisibility(r.visible,false) end
        if r.active then c:Activate(false) end
    end
    s.actor:SetActorHiddenInGame(s.hidden);s.actor:SetActorEnableCollision(s.collision)
    for _,c in ipairs(s.physics) do c:SetSimulatePhysics(true) end
end
-- c: a primitive component (M.component finds only those).
function M.componentCapture(c)
    local body=c.BodyInstance
    return {component=c,visible=c.bVisible,hidden=c.bHiddenInGame,collision=body.CollisionEnabled,physics=body.bSimulatePhysics==true}
end
function M.componentSet(s,hide)
    local c=s.component
    if hide and s.physics then c:SetSimulatePhysics(false) end
    c:SetVisibility(not hide and s.visible,false)
    c:SetHiddenInGame(hide or s.hidden,false)
    c:SetCollisionEnabled(hide and 0 or s.collision)
    if not hide and s.physics then c:SetSimulatePhysics(true) end
end
return M
