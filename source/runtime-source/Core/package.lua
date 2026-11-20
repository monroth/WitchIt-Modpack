local dir=debug.getinfo(1,'S').source:match('^@(.+[\\/])')
return function(R)
    local C={}
    local gp=StaticFindObject('/Script/Engine.Default__GameplayStatics')
    local current={role='offline',mode='none',is_creative=false,is_playtest=false,is_vanilla_session=true}
    local listeners={}
    local hostMode,publishedMode
    local transport   -- (Core's side of the mod data channel: net.lua, made below)
    function C.session() return current end
    -- A player's side now: 'witch', 'hunter', or nil (a spectator, no player). The one source of it for every
    -- mod - the game's Team, which it replicates to every machine (its other flags are not: live 11-20 a
    -- guest's IsWitchTeam still said hunter after the sides changed).
    function C.side(ps)
        local team=R.valid(ps) and ps.Team
        return team==0 and 'witch' or team==1 and 'hunter' or nil
    end
    -- The log (user 11-20: one log anyone sends must say why something did not happen). C.state(owner, what,
    -- text): a feature's state with its reason, written when it changes - never each frame.
    local states={}
    function C.state(owner,what,text)
        local key=owner..'\0'..what
        if states[key]==text then return end
        states[key]=text
        R.log(owner,'%s: %s',what,tostring(text))
    end
    function C.on_session(fn) listeners[#listeners+1]=fn;fn(current) end
    -- Creative's Playtest on or off, on the host and the guests: fn(session) after each change.
    local playtest_listeners,playtest={},false
    function C.on_playtest(fn) playtest_listeners[#playtest_listeners+1]=fn end
    local function className(object) return object:GetClass():GetFName():ToString() end
    local modeOf=dofile(dir..'mode.lua')
    local function refresh(world,pc)
        local s={world=world,pc=pc,is_vanilla_session=not C.mods or C.mods.vanilla_session()}
        if world then
            s.gm=R.valid(gp:GetGameMode(world));s.gs=R.valid(gp:GetGameState(world))
            s.gi=R.valid(gp:GetGameInstance(world))
        end
        s.role='offline'
        if s.gi and s.gi.IsCurrentlyInMatch then s.role=s.gm and 'host' or s.pc and 'client' or 'offline' end
        s.is_creative=s.gs~=nil and className(s.gs)=='B_CreativeGameState_C'
        s.is_playtest=s.is_creative and s.gs.IsPlayTestMode==true
        if s.gi then
            local options=R.valid(s.gi.IsCurrentlyInMatch and s.gi.UsedMatchOptions or s.gi.NextMatchOptions)
            local mode=options and R.valid(options.GameMode)
            if mode then s.mode_id=mode:GetFName():ToString() end
        end
        if world and s.role=='offline' then transport.left() end
        s.mode=modeOf(s,C.map,hostMode)
        current=s
        -- (the session as every mod's scope sees it: role, mode and where the mode came from)
        local source=s.role=='client' and (s.is_vanilla_session and 'a server without the modpack' or hostMode and 'the host' or 'not yet sent by the host')
            or s.role=='host' and 'this game' or 'no server'
        C.state('Core','Session',('%s, mode %s (%s), level %s'):format(s.role,s.mode,source,
            world and R.valid(world) and world:GetFullName():match('([^%.:]+)$') or '-'))
        if s.role=='host' and s.mode~=publishedMode then publishedMode=s.mode;C.net.publish('core.mode',s.mode) end
        for _,fn in ipairs(listeners) do fn(current) end
        -- (a world that ends takes its Playtest with it: no change to tell)
        if not world then playtest=false
        elseif s.is_playtest~=playtest then
            playtest=s.is_playtest
            for _,fn in ipairs(playtest_listeners) do fn(current) end
        end
    end
    C.scoped=dofile(dir..'scope.lua')(R,C)
    dofile(dir..'game.lua')(R,C)
    C.files=dofile(dir..'files.lua')(R)
    C.report=dofile(dir..'report.lua')(R)
    C.map=dofile(dir..'map.lua')(R,C)
    C.catalog=dofile(dir..'catalog.lua')(R,C)
    function C.save_report() return C.report.save(dir..'../') end
    C.saved_rules=dofile(dir..'rules.lua')(R,C)
    local net;net,transport=dofile(dir..'net.lua')(R,C)
    C.net=net
    C.abilities=dofile(dir..'abilities.lua')(R,C)
    C.net.watch('core.mode',function(value)
        if current.role=='host' then return end
        hostMode=value;refresh(current.world,current.pc)
    end)
    -- (the level each world is, in the log: which map a match went on to, e.g. after a surrender)
    R.on('world_begin',function(world)
        R.log('Core','World begin %s',world and world:GetFullName():match('([^%.:]+)$') or '?')
        refresh(world,nil)
        transport.arrived(world)
    end)
    R.on('local_player',function(pc) refresh(pc:GetWorld(),pc) end)
    R.on('world_end',function()
        R.log('Core','World end role=%s mode=%s',current.role,current.mode)
        hostMode,publishedMode=nil,nil;refresh(nil,nil)
    end)
    R.post('/Game/Blueprints/Core/B_GameMode.B_GameMode_C:Initialize',function(gm) refresh(gm:GetWorld(),current.pc) end)
    local CREATIVE='/Game/Blueprints/Gamemodes/CreativeMode/'
    for _,path in ipairs({'B_CreativeGameState.B_CreativeGameState_C:TogglePlayTestMultiCast','B_CreativeGameState.B_CreativeGameState_C:OnRep_IsPlayTestMode',
        'B_CreativeGameMode.B_CreativeGameMode_C:BeginPlayTest','B_CreativeGameMode.B_CreativeGameMode_C:EndPlayTest'}) do
        R.post(CREATIVE..path,function(object) refresh(object:GetWorld(),current.pc) end)
    end
    for _,method in ipairs({'Initialize','ShowHUD','ShowTeamSelectionObjective'})do
        -- (the game's HUD is up: the session's game state is there now; the world and player are the
        -- runtime's, followed at the same events - audit 11-20: Core found them a second time)
        R.post('/Game/Blueprints/UserInterface/B_IngameUIManager.B_IngameUIManager_C:'..method,function()
            refresh(R.local_player())
        end)
    end
    -- The game's pause menu, on Exit (Surrender), first takes the match's custom-match mark away (as for
    -- leaving to the main menu) and only then asks whether to surrender; a surrender keeps the player in
    -- the match without the mark: no Next Match Settings, the next match not the one chosen, a second
    -- surrender out to the main menu (user 11-20, found on VM2 in WB_IngameMenu). The mark as the menu
    -- opened goes back when the answer is a surrender.
    local markAtMenu
    R.post('/Game/UserInterface/WB_IngameMenu.WB_IngameMenu_C:Construct',function(menu)
        local gi=R.valid(StaticFindObject('/Script/Engine.Default__GameplayStatics'):GetGameInstance(menu))
        markAtMenu=gi and gi.IsCustomMatch
    end)
    R.pre('/Game/Blueprints/Gamemodes/ObjectiveMode/B_ObjectivePlayerController.B_ObjectivePlayerController_C:SurrenderServer',function(pc)
        local gi=R.valid(StaticFindObject('/Script/Engine.Default__GameplayStatics'):GetGameInstance(pc))
        if gi and markAtMenu~=nil then gi.IsCustomMatch=markAtMenu end
    end)
    R.on('world_end',function() markAtMenu=nil end)
    -- The game's own connection failures, with their engine type, for both host and guest.
    -- The game's Blueprint overrides them, so the hooks go on its class.
    for _,event in ipairs({'HandleNetworkError','HandleTravelError'}) do
        R.post('/Game/Blueprints/Core/B_GameInstance.B_GameInstance_C:'..event,function(_,kind,server)
            R.log('Core','%s type=%s server=%s',event,tostring(kind),tostring(server))
        end)
    end
    -- Who ended a connection, on either side: the kick and return-to-menu calls.
    local function shown(value)
        local ok,text=pcall(function() return value:ToString() end)
        return ok and text or tostring(value)
    end
    for _,path in ipairs({'/Game/Blueprints/UserInterface/B_MenuUIManager.B_MenuUIManager_C:ShowMessageDialog',
        '/Script/Engine.PlayerController:ClientWasKicked',
        '/Script/Engine.PlayerController:ClientReturnToMainMenuWithTextReason',
        '/Game/Blueprints/Player/B_PlayerController.B_PlayerController_C:ClientSetWasKicked',
        '/Script/PropWitchHuntModule.ProjectVersionBlueprint:KickPlayer'}) do
        R.post(path,function(_,...)
            local parts={}
            for i=1,select('#',...) do parts[i]=shown((select(i,...))) end
            R.log('Core','%s %s',path:match('([^:]+)$'),table.concat(parts,' '))
        end)
    end
    C.mods=dofile(dir..'mods.lua')(R,C,transport,function() refresh(current.world,current.pc) end)
    C.memory=dofile(dir..'memory.lua')(R,C)
    C.rules=dofile(dir..'rulebook.lua')(R,C)
    return C
end
