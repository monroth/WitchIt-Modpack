-- World Properties (the blue sphere: fog, sun, sky, music) on every Creative map (TODO 48, user 11-20).
-- A map made with it plays the same without the mods: the sphere behaves as the game's own (user 11-20:
-- only changes that need no mod to open and play the map). From the game's scripts:
-- - the palette offers it on the empty map template only (WB_PropButton:GetIsButtonEnabled asks the
--   creative game state's IsEmptyMapTemplate): here it is offered on any map (one per map stays the
--   palette's own rule; its tooltip no longer says "only on custom template maps");
-- - as it begins play it takes the level's fog, sun and sky as its defaults; its fog step then sets
--   the fog colour again, which also paints the volumetric fog's albedo in that colour: left as the
--   game does it (put back with the mods only, the map looked other than without them);
-- - its music number 0 is "no seek music"; a negative number leaves the music alone: a sphere the
--   player places now starts at -1.
return function(R,C)
    local WP='/Game/Blueprints/StaticProps/Placeable/Utility/BP_WorldProperties.BP_WorldProperties_C'
    local CR='/Game/Blueprints/Gamemodes/CreativeMode/B_CreativePlayerController.B_CreativePlayerController_C'
    local creative=C.scoped(function(s) return s.mode=='creative' end)
    local modded=C.scoped(function(s) return s.mode~='vanilla' end)
    local function isWP(class) return R.valid(class) and class:GetFullName():find('BP_WorldProperties_C',1,true)~=nil end

    creative.post('/Game/UserInterface/PropCollection/WB_PropButton.WB_PropButton_C:GetIsButtonEnabled',function(button,out)
        local data=R.valid(button.ItemData)
        if data and isWP(data.StructureClass) then C.state('BaseWorldPlus','World Properties block','offered on every Creative map');out:set(true) end
    end)
    -- Its tooltip said "Only on custom template maps. Only use one.": the first part is no longer so.
    creative.post('/Game/UserInterface/PropCollection/WB_PropButton.WB_PropButton_C:GetTooltip',function(button,out)
        local data,tooltip=R.valid(button.ItemData),R.valid(out:get())
        if data and tooltip and isWP(data.StructureClass) then tooltip.Description:SetText(FText('Only use one.')) end
    end)

    -- A sphere placed from the palette now (not one a layout brings: its music is the author's).
    local placing=false
    creative.pre(CR..':PlaceActorServer',function(_,class) placing=isWP(class) end)
    creative.post(CR..':PlaceActorServer',function() placing=false end)
    modded.pre(WP..':InitMusic',function(wp) if placing then wp.MusicIndex=-1 end end)
end
