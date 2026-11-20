-- EffectKit: Niagara parameters by type, streams kept while aimed, bursts at their interval.
function FName(s) return s end
local now, spawned = 0, {}
local function component()
    local c = {set = {}, off = {}, active = false}
    function c:SetVariableFloat(k, v) self.set[k] = {'float', v} end
    function c:SetVariableBool(k, v) self.set[k] = {'bool', v} end
    function c:SetVariableLinearColor(k, v) self.set[k] = {'color', v} end
    function c:SetVariableVec3(k, v) self.set[k] = {'vec', v} end
    function c:SetVariableVec2(k, v) self.set[k] = {'vec2', v} end
    function c:SetVariableMaterial(k, v) self.set[k] = {'material', v} end
    function c:SetEmitterEnable(k, on) self.off[k] = not on end
    function c:Activate() self.active = true end
    function c:K2_SetWorldLocationAndRotation(at) self.at = at end
    function c:K2_DestroyComponent() self.dead = true end
    return c
end
local libs = {
    NiagaraFunctionLibrary = {SpawnSystemAtLocation = function(_, _, _, at, _, _, destroy)
        local c = component(); c.at = at; c.auto = destroy; spawned[#spawned + 1] = c; return c end},
    GameplayStatics = {GetTimeSeconds = function() return now end},
    KismetMathLibrary = {MakeRotFromZ = function(_, v) return v end},
}
function StaticFindObject(path) return libs[path:match('Default__(.+)')] end
local ends = {}
local R = {valid = function(o) return type(o) == 'table' and not o.dead and o or nil end,
    native = {load_asset = function() return {} end}, on = function(e, fn) ends[e] = fn end}
local E = dofile('candidate/runtime-source/EffectKit/package.lua')(R, {})

local c = E.niagara({}, {}, {at = {X = 1, Y = 2, Z = 3}, params = {Rate = 2, On = true, Tint = {R = 1, G = 0, B = 0, A = 1}, Aim = {X = 0, Y = 0, Z = 1}, Size = {X = 4, Y = 4}, Look = '/Game/M.M'}, off = {'Dot'}})
assert(c.set.Rate[1] == 'float' and c.set.On[1] == 'bool' and c.set.Tint[1] == 'color' and c.set.Aim[1] == 'vec' and c.set.Size[1] == 'vec2' and c.set.Look[1] == 'material', 'Each parameter goes by its type')
assert(c.off.Dot and c.active and c.auto, 'Emitters left off, then started; gone when it finishes')
print('PASS EffectKit Niagara parameters by type')

spawned = {}
local stream = E.pointers({path = 'p', params = {Color = {R = 1, G = 1, B = 0, A = 1}}, rate = function(x) return {SpawnRate = 10 * x} end})
stream:aim('a:1', {}, {X = 0, Y = 0, Z = 0}, {X = 0, Y = 0, Z = 100}, .5)
stream:aim('b:2', {}, {X = 0, Y = 0, Z = 0}, {X = 100, Y = 0, Z = 0}, 1); stream:done()
assert(#spawned == 2 and not spawned[1].auto and spawned[1].set.SpawnRate[2] == 5, 'A stream is kept, its rate by closeness')
stream:aim('a:1', {}, {X = 5, Y = 0, Z = 0}, {X = 0, Y = 0, Z = 100}, .5); stream:done()
assert(#spawned == 2 and spawned[1].at.X == 5 and spawned[2].dead, 'Aimed again it moves; not aimed it goes')
stream:close('a:'); assert(spawned[1].dead, 'Closed by a part of its key')
spawned = {}
local reaching = E.pointers({path = 'p', reach = {speed = function(c) return 300 + 700 * c end, drag = .5}})
for _, c in ipairs({0, 1}) do
    reaching:aim('r', {}, {X = 0, Y = 0, Z = 0}, {X = 0, Y = 300, Z = 400}, c)
    local v, life = spawned[1].set.Speed[2], spawned[1].set.Lifetime[2]
    assert(math.abs(v * (1 - math.exp(-.5 * life)) / .5 - 500) < 1e-6, 'A reach ends its particles at the target, slow or fast')
    assert(c == 1 and v == 1000 or c == 0 and v == 312.5, 'Its speed by closeness (at least what reaches the target)')
end
print('PASS EffectKit streams kept while aimed')

spawned = {}
local bursts = E.pointers({path = 'p', params = {IsProp = false}, toward = 'Target', every = function() return 1 end})
for _, t in ipairs({0, .5, 1.1, 1.6, 2.2}) do now = t; bursts:aim('w', {}, {X = 0, Y = 0, Z = 0}, {X = 9, Y = 0, Z = 0}, 0); bursts:done() end
assert(#spawned == 3 and spawned[1].set.Target[2].X == 9 and spawned[1].auto, 'A burst at its interval, toward the target')
print('PASS EffectKit bursts at their interval')
