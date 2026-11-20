-- Match Rules ++: extra match rules, and rules as a code. Rules apply only after an
-- explicit selection; opening a page only reads them.
local dir=debug.getinfo(1,'S').source:match('^@(.+[\\/])')
return function(R,C,U)
    local schema=dofile(dir..'schema.lua')
    local D=dofile(dir..'document.lua')(R,schema,C.report.crc32)
    local M={R=R,C=C,U=U,schema=schema,doc=D}
    -- An ability a mod registered has rules of the game too: a group of its own skill type, with
    -- the rows of the ability it starts from (so they are saved, shared and shown like the game's).
    C.abilities.on_register(function(spec,kind)
        if D.index.skills[kind] then return end
        local base=assert(D.index.skills[spec.base or 2],'no skill type to start from')
        local group={category='skills',id=kind,label=spec.name,rows=base.rows}
        schema.groups[#schema.groups+1]=group
        D.add_group(group)
    end)
    -- The game's rules of a group now (nil: an ability whose class is not loaded yet).
    function M.params(group)
        if group.property then return C.subsystem(group.category)[group.property] end
        return C.abilities.params(group.id)
    end
    M.PKG='MatchRulesPlusPlus'
    M.CORE='/Game/Blueprints/Core/'
    M.RULEUI='/Game/UserInterface/Play/GameRules/'
    M.TABS=M.RULEUI..'WB_GameRulesTabs.WB_GameRulesTabs_C'
    M.PROP='/Game/Blueprints/Props/Bases/B_StaticMeshProp.B_StaticMeshProp_C'
    M.PAWN='/Game/Blueprints/Player/Pawns/'
    M.CREATIVE='/Game/Blueprints/Gamemodes/CreativeMode/'
    local settings=R.settings(M.PKG,{name='My-rules'})
    M.settings=settings
    function M.persist() R.save_settings(M.PKG) end
    -- State shared by the modules below.
    M.hostView=nil       -- a guest's copy of the host's published rules
    M.filling=false      -- native rule pages are being painted by code, not edited

    -- Scope: Match Rules ++'s extra rules and its hooks on native rules and gameplay never touch a
    -- vanilla session (M.hooks); the rules of the game are exchanged there too (user 11-16: views,
    -- codes and offers; the extra rules stay off).
    M.hooks=C.scoped(function(s) return s.mode~='vanilla' end)
    -- A modded session's guests play its rules: they need this mod as the host has it.
    C.mods.require(function() return true end)
    function M.editable() return C.session().role~='client' end
    -- Where the game edits rules during play (a Tweakable match, a Creative play test with
    -- live editing), the host's changes apply at once; anywhere else from the next match.
    function M.live()
        local s=C.session()
        return s.role=='host' and s.mode~='vanilla' and M.playing() and s.gm.IsLiveRuleEditingAllowed==true
    end
    function M.playing()
        local s=C.session()
        return not s.is_creative or s.gs.IsPlayTestMode==true
    end
    -- The options the rules screen edits. In a match: the next match's. In the main menu:
    -- the Custom Match screen's own options object, which hosting copies into the match
    -- (the same object Fill a Pot+ marks as Plus).
    local customMatch='/Game/UserInterface/Play/WB_Custommatch.WB_Custommatch_C'
    function M.nextOptions()
        local gi=C.session().gi
        if gi.IsCurrentlyInMatch then return gi.NextMatchOptions end
        local menu=R.find(customMatch)
        return menu and menu.NextMatchOptions or gi.CustomMatchOptions
    end
    function M.ownerAllowed(pawn)
        local s=C.session()
        return M.extrasHost() or s.role=='client' and s.mode~='vanilla' and M.playing() and pawn:IsLocallyControlled()
    end
    -- This mod's extra rules (Core's rules): those changed from the game's own, in force here.
    -- (asked every tick by every pawn: made again only when the rules or the session changed)
    local extras,extrasKey
    C.rules.on_change(function(pkg) if pkg==M.PKG then extras=nil end end)
    R.on('world_end',function() extras=nil end)
    function M.extras()
        local s=C.session()
        local playing=s.role~='offline' and s.mode~='vanilla' and M.playing()
        local key=s.role..'|'..s.mode..'|'..tostring(playing)
        if extras and key==extrasKey then return extras end
        local out={}
        if playing then
            for _,spec in ipairs(C.rules.specs(M.PKG)) do
                local value=C.rules.get(M.PKG,spec.key)
                if value~=spec.initial then out[spec.key]=value end
            end
        end
        extras,extrasKey=out,key
        return out
    end
    -- The host applies the extra rules; each player's own pawn takes them on its machine too.
    function M.extrasHost()
        local s=C.session()
        return s.role=='host' and s.mode~='vanilla' and M.playing()
    end

    function M.library(name) return StaticFindObject('/Script/Engine.Default__'..name) end
    function M.pathOf(value) return value:GetFullName():match('(%S+)$') end
    local names={B_ObjectiveGameMode_C='Fill a Pot',B_HideAndSeekGameMode_C='Hide and Seek',B_SeekGameMode_C='Hide and Seek',
        B_MobificationGameMode_C='Mobification',IsListed='Available',IsLIsted='Available',IsEnabled='Enabled',
        GlobalMatchParameters='General',HunterMatchParameters='Hunters',WitchMatchParameters='Witches',
        HealAmmount='Healing',ManaRegenMultiplicator='Mana regeneration',MoveOrDamage='Move or take damage',
        PowerBall='Power ball',FlyingEye='Flying eye',JumpScare='Jump scare',IsInMatch='In match',Scale='Size',
        Pitch='Sound pitch',VoicePitch='Voice pitch',AirControl='Air control',GravityScale='Gravity',
        OverHealReductionMultiplier='Overheal decay',ExtraSpeedMultiplier='Prop speed',LastProps='Recent props'}
    function M.label(name)
        local words=name:gsub('^B_',''):gsub('GameMode_C$',''):gsub('(%l)(%u)','%1 %2'):gsub('_',' '):lower()
        return names[name] or words:sub(1,1):upper()..words:sub(2)
    end
    -- Error text for players: the assertion message without its source position.
    function M.problem(why)
        local message=tostring(why):gsub('^.-:%d+:%s*','')
        if message:find('attempt to',1,true) then return 'The preset contains invalid rules.' end
        return message
    end
    -- The extra rules are Core's rules of this mod, on the game's pages where their kind is.
    local pages={GlobalSliderList='general',HunterSliderList='hunters',WitchSliderList='witches'}
    local rules={}
    for _,spec in ipairs(schema.extras) do
        local page=pages[spec.place] or type(spec.place)=='number' and 'skill:'..spec.place or spec.place
        rules[#rules+1]={key=spec.key,label=spec.label,kind=spec.kind=='bool' and 'bool' or 'number',initial=spec.initial,
            min=spec.min,max=spec.max,step=spec.step,integer=spec.integer,sliderMin=spec.sliderMin,sliderMax=spec.sliderMax,page=page,help=spec.help}
    end
    C.rules.declare(M.PKG,rules)
    for _,name in ipairs({'effects','decoys','pages','sharing','tab','marks'}) do dofile(dir..name..'.lua')(M) end
    C.rules.on_change(function(pkg) if pkg==M.PKG and M.refreshEffects then M.refreshEffects() end end)
    return {clean=D.clean,encode=D.encode,decode=D.decode,capture=M.capture,stage=M.stage,schema=schema.groups}
end
