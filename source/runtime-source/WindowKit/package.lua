-- WindowKit: compact windows over the game world for the mods' tools (Creative Tools, the marker
-- editors, the hide tool): windows with a corner button, lock, size and stacking; sections that
-- come out into windows of their own; compact controls (switches, number fields, choices that
-- open over the window). Built on UIKit's controls and building blocks; UIKit knows nothing of it.
local dir=debug.getinfo(1,'S').source:match('^@(.+[\\/])')
return function(R, C, U)
    local W, I = {}, U.parts
    dofile(dir..'controls.lua')(R, C, U, I, W)
    dofile(dir..'window.lua')(R, C, U, I, W)
    -- Plain controls inside windows are UIKit's.
    W.text, W.flow, W.fill, W.scroll, W.checkbox, W.remove = U.text, U.flow, U.fill, U.scroll, U.checkbox, U.remove
    return W
end
