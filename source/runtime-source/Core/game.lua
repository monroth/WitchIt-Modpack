-- Small facts of the game every mod needs, in one place.
--   C.subsystem(name, context)        a world subsystem of the game by name: 'match' (match rules),
--                                     'skills' (abilities' rules), 'powerups', 'mods' (game modifiers);
--                                     context: an object of the world (the session's world by default)
--   C.replicate(object, field, value, rep)  set a replicated property so every client gets it now
--                                     (push model: marked dirty by its replication index); value nil
--                                     keeps the current value (only marks it)
--   C.MAP, C.LAYOUT                   the fields of the game's map and layout records (MapData,
--                                     LayoutData) by their cooked names
--   C.creative(options)               whether match options host Creative
--   C.CREATIVE_PC                     the Creative player controller's class path (one place for every kit)
--   C.HOST_WIDGET, C.PIXEL_FONT       the blank game widget the kits draw on, and the game's pixel font
--   C.starts(team)                    the map's start blocks of 'hunter' or 'witch' (not the editor's aiming preview)
--   C.skill_class(team,name), C.pickup_class(team,name)  an ability's or power-up's class path ('Hunter'/'Witch')
return function(R, C)
    C.MAP = {file = 'FileName_10_98BC71FF40A2DA9A28FA21B92157D6D9', name = 'InterfaceName_12_C1C05170469A93A0C7D243A1F45D7B13',
        objective = 'UsedInObjectiveMode_16_14EC3F034A60C0E1B05A6499D0923C6F', builtin = 'IsBuiltInCustomMap_24_B260140C4981E09A0400EBBB5AF787AD',
        preview = 'PreviewImage_6_3020A08A433639F165C92FA2C9A4ED43', layouts = 'ObjectiveLayouts_54_B3B7A59246226E47D79F4E94921D6024'}
    C.LAYOUT = {file = 'FileName_6_F3CC8069497D007AD2E96A9AE00D2700', name = 'LayoutName_8_C5C516E347406BABDAF0F59A6150BC5A',
        map = 'MapName_10_67B8E5E54A16D786C60266AF5B396E36', type = 'LayoutType_3_723A46B84CDA3855FEC9D49D6379A874',
        screenshot = 'ScreenshotFile_15_EAD1980E4D724129C57CEE95149A80DD'}
    C.HOST_WIDGET = '/Game/UserInterface/Information/WB_EarlyVersionWatermark.WB_EarlyVersionWatermark_C'
    C.PIXEL_FONT = '/Game/UserInterface/Fonts/PixelFont.PixelFont'
    C.CREATIVE_PC = '/Game/Blueprints/Gamemodes/CreativeMode/B_CreativePlayerController.B_CreativePlayerController_C'
    local STARTS={hunter='/Game/Blueprints/StaticProps/Placeable/Utility/BP_HunterPlayerStart.BP_HunterPlayerStart_C',
        witch='/Game/Blueprints/StaticProps/Placeable/Utility/BP_WitchPlayerStart.BP_WitchPlayerStart_C'}
    function C.starts(team)
        local out={}
        for _,a in ipairs(R.find_all(STARTS[team])) do if not a.IsPreview then out[#out+1]=a end end
        return out
    end
    -- (where the game keeps them: one rule for every mod - audit 11-20, two mods spelled it, with the
    -- Flying Eye's folder each their own way)
    local SKILL_FOLDER={FlyingEye='Eye'}
    function C.skill_class(team,name)
        return '/Game/Blueprints/Skills/'..team..'/'..(SKILL_FOLDER[name] or name)..'/B_'..name..'Skill.B_'..name..'Skill_C'
    end
    function C.pickup_class(team,name) return '/Game/Blueprints/Pickups/B_'..team..'Pickup'..name..'.B_'..team..'Pickup'..name..'_C' end
    function C.creative(options) return R.valid(options.GameMode) ~= nil and options.GameMode:GetFName():ToString() == 'B_CreativeGameMode_C' end
    local SUBSYSTEMS = {
        match = '/Game/Blueprints/Match/GameRules/MatchRules/B_MatchParametersSubsystem.B_MatchParametersSubsystem_C',
        skills = '/Game/Blueprints/Skills/B_SkillParametersSubsystem.B_SkillParametersSubsystem_C',
        mods = '/Game/Blueprints/Match/GameRules/GameModifiers/B_ModParametersSubsystem.B_ModParametersSubsystem_C',
        powerups = '/Game/Blueprints/Match/GameRules/PowerupRules/B_PowerupParametersSubsystem.B_PowerupParametersSubsystem_C',
    }
    local function find(path) return StaticFindObject(path) end
    function C.subsystem(name, context)
        return find('/Script/Engine.Default__SubsystemBlueprintLibrary'):GetWorldSubsystem(context or C.session().world, StaticFindObject(assert(SUBSYSTEMS[name], 'no subsystem ' .. tostring(name))))
    end
    C.subsystem_paths = SUBSYSTEMS
    function C.replicate(object, field, value, rep)
        -- (an actor is woken and sent now; a component goes with its actor)
        local actor = object:IsA(find('/Script/Engine.Actor')) and object or object:GetOwner()
        actor:FlushNetDormancy()
        if value ~= nil then object[field] = value end
        find('/Script/Engine.Default__NetPushModelHelpers'):MarkPropertyDirtyFromRepIndex(object, rep, FName(field))
        actor:ForceNetUpdate()
    end
end
