-- Objects changed: told once a frame, however many changes, with the objects moved and whether
-- objects of the level came or went (any way, in Creative); a new level drops what was waiting.
local post, on, queue = {}, {}, {}
local R = {post = function(p, f) post[p:match(':(.+)$')] = f end, on = function(e, f) local was = on[e]; on[e] = was and function(...) was(...); f(...) end or f end,
    next_frame = function(f) queue[#queue + 1] = f end}
-- (the runtime's own: a callback's failure is told, not thrown; a valid object or nil)
R.call=R.call or function(fn,...) local ok,v=pcall(fn,...) if ok then return v end;print('[Error] '..tostring(v)) end
R.valid=R.valid or function(v) if v~=nil and (type(v)~='table' or v.IsValid==nil or v:IsValid()) then return v end end
local function frame() local q = queue; queue = {}; for _, f in ipairs(q) do f() end end
local K = {}
local session = {is_creative = true, pc = {IsValid = function() return true end}}
StaticFindObject = function(path) return {IsValid = function() return true end, path = path} end
dofile('candidate/runtime-source/WorldKit/objects.lua')(R, {session = function() return session end, CREATIVE_PC = '/Game/Blueprints/Gamemodes/CreativeMode/B_CreativePlayerController.B_CreativePlayerController_C'}, K, dofile('candidate/runtime-source/WorldKit/math.lua'))
local function actor(n, kind) return {IsValid = function() return true end, GetAddress = function() return n end,
    GetFullName = function() return 'Actor /Game/Level.Level:PersistentLevel.Object_' .. n end,
    IsA = function(_, c) return kind ~= nil and c.path:find(kind, 1, true) ~= nil end} end
local told = {}
K.on_changed(function(moved, added) told[#told + 1] = {moved = moved, added = added} end)
local a, b = actor(1), actor(2)
post.UpdateActorTransformServer(nil, a); post.UpdateActorTransformServer(nil, a); post.UpdateActorTransformServer(nil, b)
assert(#told == 0 and #queue == 1, 'nothing yet, one frame waited for')
frame()
assert(#told == 1 and #told[1].moved == 2 and not told[1].added, 'once: both moved (a once), nothing added')
on.actor_begin(actor(3, 'BP_PlaceableActor')); on.actor_end(actor(4, 'B_StaticMeshProp'), 0); frame()
assert(#told == 2 and #told[2].moved == 0 and told[2].added, 'an object placed, a prop deleted (any way): added')
on.actor_begin(actor(5)); on.actor_end(actor(6, 'B_StaticMeshProp'), 1); frame()
assert(#told == 2 and #queue == 0, 'not an object of the level, or gone with the level: nothing')
session.is_creative = false; on.actor_begin(actor(7, 'BP_PlaceableActor')); frame()
assert(#told == 2, 'outside Creative: nothing')
session.is_creative = true
post.UpdateActorTransformServer(nil, a); on.world_end(); frame()
assert(#told == 3 and #told[3].moved == 0, 'a new level drops the old one\'s objects')
-- A deleted object is gone for the editors at once (the engine still finds it for a while, live 11-20).
local deleted = actor(9, 'BP_PlaceableActor')
on.actor_end(deleted, 0)
assert(K.gone(deleted) and not K.gone(actor(10, 'BP_PlaceableActor')), 'a deleted object is gone, another is not')

print('PASS objects changed: once a frame, moved and added')
