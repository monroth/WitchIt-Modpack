-- WorldKit: what the editors of a Creative level share: the creative player and its selection,
-- the level's changes and one loop for their work each frame, where objects are and the sizes the game allows (objects.lua), changing the level with the
-- game's own functions and ONE undo for every editor (actions.lua), the mouse in the level and the
-- clicks in the level an editor claims (mouse.lua), marks drawn over the level (marks.lua), and the math (math.lua).
-- (3D dots and flat colours are EffectKit's.)
local dir=debug.getinfo(1,'S').source:match('^@(.+[\\/])')
return function(R,C)
    local M=dofile(dir..'math.lua')
    local K={M=M}
    dofile(dir..'objects.lua')(R,C,K,M)
    dofile(dir..'actions.lua')(R,C,K,M)
    dofile(dir..'mouse.lua')(R,C,K)
    dofile(dir..'marks.lua')(R,C,K)
    dofile(dir..'gizmo.lua')(R,C,K)
    return K
end
