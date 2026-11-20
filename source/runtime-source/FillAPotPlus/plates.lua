-- Pressure plates in a Fill a Pot+ match (the host's; the plate's state reaches everyone through
-- the game): a prop presses them too, a witch in a prop's shape and a thrown prop alike (user 11-14,
-- option 1: the doors stay a puzzle, and props can be carried through them). The game's plate counts
-- witches and hunters only, so a witch carrying a prop could not open the doors on the way to a cauldron.
return function(S)
    local R=S.R
    local path='/Game/Blueprints/StaticProps/Placeable/Utility/BP_PressurePlateSwitch.BP_PressurePlateSwitch_C'
    local prop='/Game/Blueprints/Props/Bases/B_StaticMeshProp.B_StaticMeshProp_C'
    local function isProp(actor) return R.valid(actor)~=nil and actor:IsA(StaticFindObject(prop)) end
    -- The plate's box notices whatever enters it (the game's box ignores props); the tests below
    -- still decide who presses it.
    S.onMatchHost.on('round_start',function()
        for _,plate in ipairs(R.find_all(path)) do
            local box=R.valid(plate.CollisionBox)
            if box then box:SetCollisionResponseToAllChannels(1);box:SetGenerateOverlapEvents(true) end
        end
    end)
    -- (the game's own test: a witch or a hunter, on a plate not already down)
    S.onMatchHost.post(path..':TestSwitchActivationCondition',function(w,actor,activate)
        if isProp(actor) and not w.Activated then activate:set(true) end
    end)
    -- A prop leaving the plate: the game tries to raise it only when a witch or a hunter leaves;
    -- after a prop too (the next frame, once the overlap is over).
    S.onMatchHost.post(path..':BndEvt__BP_PressurePlateSwitch_CollisionBox_K2Node_ComponentBoundEvent_1_ComponentEndOverlapSignature__DelegateSignature',function(w,_,actor)
        if isProp(actor) then R.next_frame(function() if R.valid(w) and w.Activated then w:TryToReset() end end) end
    end)
    -- The plate rises when no witch or hunter is on it: not while a prop still is.
    S.onMatchHost.pre(path..':TryToReset',function(w)
        local on={}
        w.CollisionBox:GetOverlappingActors(on,StaticFindObject(prop))
        for _,a in ipairs(on) do if isProp(a.get and a:get() or a) then return true end end
    end)
end
