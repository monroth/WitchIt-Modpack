-- UIKit's control records and their game events (UIKit/actions.lua) for a test's own R: the parts
-- a kit takes from U.parts. Screens are not tracked here (one owner state for every widget).
return function(R)
    local I={actions={},elements='/Game/UserInterface/UIElements/'}
    function I.id(widget) return widget:GetAddress() end
    function I.owner() return {actions={}} end
    function I.path(asset,event,folder) return (folder or I.elements)..asset..'.'..asset..'_C:'..event end
    dofile('candidate/runtime-source/UIKit/actions.lua')(R,nil,nil,I)
    return I
end
