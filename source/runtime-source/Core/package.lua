local dir=debug.getinfo(1,'S').source:match('^@(.+[\\/])')
return function(R)
    local C={}
    local gp=StaticFindObject('/Script/Engine.Default__GameplayStatics')
    local current={role='offline',mode='none',is_creative=false,is_playtest=false,is_vanilla_session=true}
    local listeners={}
    local transport   -- (Core's side of the mod data channel: net.lua, made below)
    -- The session as a mod sees it (owner: the mod; nil - the caller, from the stack). A synced mod a guest has and
    -- its host does not plays as on a vanilla server there - the same as the host's Vanilla server box: each mod
    -- already does nothing that a vanilla session must not have (user 11-21: nothing is taken from a guest).
    local views={}
    function C.session_of(owner)
        if current.role~='client' or not owner or not C.mods or C.mods.host_has(owner) then return current end
        local view=views[owner]
        if not view then
            view={}
            for k,v in pairs(current) do view[k]=v end
            view.is_vanilla_session,view.mode=true,'vanilla'
            views[owner]=view
            C.state(owner,'Session','vanilla here - the host has no '..R.mod_name(owner))
        end
        return view
    end
    -- (the mod asking: the nearest mod on the stack past Core; Core's own call - none past it - is Core's.
    -- Live 11-21 R.owner('Core') alone stopped Core at start: Core asks too, and no mod was past it.)
    local function asker() local ok,id=pcall(R.owner,'Core');return ok and id or 'Core' end
    function C.session() return C.session_of(asker()) end
    -- Which side of the match this machine is, from the session's role (audit 11-20: spelled ad hoc in every mod).
    -- C.owns(s): the machine runs the match - the host, or offline (Creative editing alone); C.guest(s): a guest
    -- of someone else's. Not 'the host' alone: a mod that means only a hosted match asks role=='host'. s: a
    -- session, the current one by default. (An object's own authority - an actor's HasAuthority - is another
    -- question, asked of the object.)
    function C.owns(s) return (s or current).role~='client' end
    function C.guest(s) return (s or current).role=='client' end
    -- A world's level name (the last part of its full name), nil for no world: the one spelling of it for
    -- every mod and the log (audit 11-20: two mods asked the world's FName and Core its full name).
    function C.level(world) return world and R.valid(world) and world:GetFullName():match('([^%.:]+)$') or nil end
    -- A player's side now: 'witch', 'hunter', or nil (a spectator, no player). The one source of it for every
    -- mod - the game's Team, which it replicates to every machine (its other flags are not: live 11-20 a
    -- guest's IsWitchTeam still said hunter after the sides changed).
    function C.side(ps)
        local team=R.valid(ps) and ps.Team
        return team==0 and 'witch' or team==1 and 'hunter' or nil
    end
    -- The match options in force: those this match runs with while in a match, else the menu's next match's
    -- (audit 11-20: Core and the mods each picked between them). s: a session, the current one by default.
    -- Menu code that edits the next match's options asks gi.NextMatchOptions itself.
    function C.options(s)
        local gi=(s or current).gi
        return gi and R.valid(gi.IsCurrentlyInMatch and gi.UsedMatchOptions or gi.NextMatchOptions) or nil
    end
    -- Whether a player is dead: the game's replicated flag, on every machine (audit 11-20: asked as the flag,
    -- as the pawn's class and as the team). Not the same as the side - a death changes Team (C.side) - nor as the
    -- spectator pawn: a watcher is not dead, and the dead witch's body is a pawn of its own class.
    function C.dead(ps) return R.valid(ps) and ps.IsDead and true or false end
    -- The log (user 11-20: one log anyone sends must say why something did not happen). C.state(owner, what,
    -- text): a feature's state with its reason, written when it changes - never each frame.
    local states={}
    function C.state(owner,what,text)
        local key=owner..'\0'..what
        if states[key]==text then return end
        states[key]=text
        R.log(owner,'%s: %s',what,tostring(text))
    end
    function C.on_session(fn)
        local owner=asker()
        local function told() fn(C.session_of(owner)) end
        listeners[#listeners+1]=told;told(current)
    end
    -- Creative's Playtest on or off, on the host and the guests: fn(session) after each change.
    local playtest_listeners,playtest={},false
    function C.on_playtest(fn) playtest_listeners[#playtest_listeners+1]=fn end
    local function className(object) return object:GetClass():GetFName():ToString() end
    local modeOf=dofile(dir..'mode.lua')
    local function refresh(world,pc)
        local s={world=world,pc=pc,is_vanilla_session=not C.mods or C.mods.vanilla_session(),is_official=C.mods~=nil and C.mods.official_session()}
        if world then
            s.gm=R.valid(gp:GetGameMode(world));s.gs=R.valid(gp:GetGameState(world))
            s.gi=R.valid(gp:GetGameInstance(world))
        end
        s.role='offline'
        if s.gi and s.gi.IsCurrentlyInMatch then s.role=s.gm and 'host' or s.pc and 'client' or 'offline' end
        s.is_creative=s.gs~=nil and className(s.gs)=='B_CreativeGameState_C'
        s.is_playtest=s.is_creative and s.gs.IsPlayTestMode==true
        if s.gi then
            local options=C.options(s)
            local mode=options and R.valid(options.GameMode)
            if mode then s.mode_id=mode:GetFName():ToString() end
        end
        s.mode=modeOf(s,C.map,C.mods and C.mods.host_mode())
        current,views=s,{}
        -- (the session as every mod's scope sees it: role, mode and where the mode came from)
        local source=s.role=='client' and (s.is_vanilla_session and 'a vanilla server' or 'the host, when joined')
            or s.role=='host' and 'this game' or 'no server'
        C.state('Core','Session',('%s, mode %s (%s), level %s'):format(s.role,s.mode,source,
            C.level(world) or '-'))
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
    -- (with the state of this moment: every mod's states, the session, what this server or its host said of itself and
    -- the match options - user 11-21: a rare problem cannot be logged ahead, it is looked at when it happens)
    function C.save_report()
        local lines={('Saved %s'):format(os.date('%Y-%m-%d %H:%M:%S')),''}
        local s=current
        lines[#lines+1]=('Session: role %s, mode %s, level %s, vanilla %s, official %s, creative %s, playtest %s'):format(
            tostring(s.role),tostring(s.mode),tostring(C.level(s.world)),tostring(s.is_vanilla_session),tostring(s.is_official),tostring(s.is_creative),tostring(s.is_playtest))
        if C.mods then
            lines[#lines+1]='This server says (hosting): '..(C.mods.identity and R.json.encode(C.mods.identity) or 'nothing - not hosting')
            lines[#lines+1]='The host said (joined): '..tostring(C.mods.host_mode() or 'no host')
        end
        local options=s.gi and C.options(s)
        if options then
            local o={}
            for _,name in ipairs({'IsPublic','UsePassword','MaxPlayers','HideTime','SeekTime','RequiredPlayersPerTeam','WitchLives','TeamSwitchingOption','IsTournamentMode','IsLiveGameRuleEditingAllowed','CustomMapSelected'}) do
                o[#o+1]=name..'='..tostring(options[name])
            end
            lines[#lines+1]='Match options: '..table.concat(o,', ')
        end
        -- The game's own objects as they are now - every field of each (user 11-21: the first report held only what
        -- the mods knew; the fault was in the game's online session, which it did not show). Objects: the game
        -- instance and its match manager, the game state and mode, this player's controller and state, and every
        -- online session object, the game's session and the online subsystems.
        local function value(v)
            local t=type(v)
            if t~='userdata' then return tostring(v) end
            for _,how in ipairs({'ToString','GetFullName','GetArrayNum'}) do
                local ok,out=pcall(function() return v[how](v) end)
                if ok and out~=nil then return how=='GetArrayNum' and ('array of '..tostring(out)) or tostring(out) end
            end
            return tostring(v)
        end
        local function dump(label,object)
            if not R.valid(object) then lines[#lines+1]=label..': none';return end
            lines[#lines+1]=''
            lines[#lines+1]=label..': '..object:GetFullName()
            local class=object:GetClass()
            while R.valid(class) do
                class:ForEachProperty(function(p)
                    local name=p:GetFName():ToString()
                    local ok,v=pcall(function() return value(object[name]) end)
                    lines[#lines+1]=('  %s = %s'):format(name,(ok and v or 'unreadable'):sub(1,300))
                end)
                local ok,super=pcall(function() return class:GetSuperStruct() end)
                class=ok and super or nil
                if R.valid(class) and class:GetFName():ToString()=='Object' then break end
            end
        end
        local gi=R.valid(s.gi)
        dump('Game instance',gi)
        -- (the game instance's own helpers for sessions, servers and Steam joins: each with all its fields)
        if gi then
            for _,field in ipairs({'SessionManager','SteamBeaconManager','SessionSearch','NewMasterServerManager','ServerStatManager','ServerQuestInterface','TournamentManager'}) do
                local ok,o=pcall(function() return gi[field] end)
                if ok then dump('Game instance '..field,o) end
            end
        end
        dump('Match manager',gi and gi.ObjectiveMatchManager)
        dump('Game state',s.gs)
        dump('Game mode',s.gm)
        dump('Player controller',s.pc)
        dump('Player state',R.valid(s.pc) and s.pc.PlayerState)
        -- (and every live object of the game whose class is about sessions, online play, Steam or EOS - found by
        -- name over all objects, so nothing has to be guessed ahead)
        local found={}
        ForEachUObject(function(o)
            local ok,name=pcall(function() return o:GetClass():GetFName():ToString() end)
            if ok and name and (name:find('Session') or name:find('Online') or name:find('Steam') or name:find('EOS') or name:find('Presence') or name:find('Lobby'))
                and not o:GetFName():ToString():find('^Default__') and not name:find('Function') and not name:find('Property') and not name:find('Class$') then
                found[#found+1]=o
            end
        end)
        lines[#lines+1]=''
        lines[#lines+1]=('Online objects: %d'):format(#found)
        for i,o in ipairs(found) do if i<=60 then dump('Online '..i,o) end end
        -- (the game's own answers about its session and its sign-in: these live behind functions, not fields - the
        -- online session subsystem and the identity subsystem, asked as the game asks them)
        local function deep(v,depth)
            if type(v)=='table' and depth<=3 then
                local parts={}
                for k,inner in pairs(v) do parts[#parts+1]=tostring(k)..'='..deep(inner,depth+1) end
                table.sort(parts)
                return '{'..table.concat(parts,', ')..'}'
            end
            local plain=value(v)
            if type(v)~='userdata' or depth>3 then return plain end
            -- (an object the game hands back: every field of it)
            local okC,class=pcall(function() return v:GetClass() end)
            if okC and R.valid(class) and R.valid(v) then
                local parts={}
                while R.valid(class) and class:GetFName():ToString()~='Object' do
                    class:ForEachProperty(function(p)
                        local name=p:GetFName():ToString()
                        local ok,inner=pcall(function() return deep(v[name],depth+1) end)
                        parts[#parts+1]=name..'='..(ok and inner or 'unreadable')
                    end)
                    local okS,super=pcall(function() return class:GetSuperStruct() end)
                    class=okS and super or nil
                end
                return '{'..table.concat(parts,', ')..'}'
            end
            local okS,struct=pcall(function() return v:GetStruct() end)
            if not (okS and R.valid(struct)) then return plain end
            local parts={}
            struct:ForEachProperty(function(p)
                local name=p:GetFName():ToString()
                local ok,inner=pcall(function() return deep(v[name],depth+1) end)
                parts[#parts+1]=name..'='..(ok and inner or 'unreadable')
            end)
            return '{'..table.concat(parts,', ')..'}'
        end
        local function ask(label,object,fn,...)
            if not R.valid(object) then return end
            local args=table.pack(...)
            local ok,result=pcall(function() return object[fn](object,table.unpack(args,1,args.n)) end)
            lines[#lines+1]=('%s %s: %s'):format(label,fn,ok and deep(result,0):sub(1,4000) or ('failed - '..tostring(result)))
        end
        lines[#lines+1]=''
        local okSub,sessionSubsystem=pcall(FindFirstOf,'OnlineSessionSubsystem')
        sessionSubsystem=okSub and sessionSubsystem or nil
        -- (the game names its session itself: the game instance's CurrentOnlineSessionName - live 11-21 'GameSession'
        -- answered 'no session' while one ran)
        local current=R.valid(s.gi) and s.gi.CurrentOnlineSessionName:ToString() or ''
        lines[#lines+1]='Session name in use: '..current
        for _,name in ipairs({current,'GameSession','PartySession'}) do
            ask('Session '..name,sessionSubsystem,'GetSessionState',FName(name))
            ask('Session '..name,sessionSubsystem,'GetNamedSession',FName(name))
            ask('Session '..name,sessionSubsystem,'GetSessionSettings',FName(name))
        end
        ask('Sessions',sessionSubsystem,'GetNumSessions')
        local okId,identity=pcall(FindFirstOf,'OnlineIdentitySubsystem')
        identity=okId and identity or nil
        ask('Sign-in',identity,'GetLoginStatus',0)
        ask('Sign-in',identity,'GetUniquePlayerId',0)
        -- (each server the server list found, with everything it says of itself)
        local okList,lists=pcall(FindAllOf,'WB_ServerListBase_C')
        for _,list in ipairs(okList and lists or {}) do
            local okS,servers=pcall(function() return R.values(list.FoundServers) end)
            for i,data in ipairs(okS and servers or {}) do
                local told={}
                pcall(function() data.ExtraSettings:ForEach(function(k,v)
                    local d=v:get().Data
                    told[#told+1]=k:get():ToString()..'='..(d.Type==6 and R.text(d.AsString) or tostring(d.AsInt)..'/'..tostring(d.AsBool))
                end) end)
                table.sort(told)
                local okN,name=pcall(function() return R.text(data:GetServerName()) end)
                lines[#lines+1]=('Listed server %d: %s - %s'):format(i,okN and name or '?',table.concat(told,', '))
            end
        end
        -- Probes: Lua files in Saved/WitchItRuntime/probes run now, in this game as it is, and what they return goes
        -- in the report (user 11-21: a rare state cannot be logged ahead - a probe is written while it lasts, and
        -- this button runs it, no restart). A probe is function(R, C) -> text.
        for _,name in ipairs(R.native.file_list(R.saved_root..'probes') or {}) do
            if name:match('%.lua$') then
                local ok,result=pcall(function() return dofile(R.saved_root..'probes/'..name)(R,C) end)
                lines[#lines+1]=''
                lines[#lines+1]='Probe '..name..(ok and ':' or ' failed:')
                lines[#lines+1]=tostring(result)
            end
        end
        lines[#lines+1]=''
        lines[#lines+1]='States of every mod now:'
        local keys={}
        for key in pairs(states) do keys[#keys+1]=key end
        table.sort(keys)
        for _,key in ipairs(keys) do lines[#lines+1]=key:gsub('%z',' / ')..': '..tostring(states[key]) end
        return C.report.save(dir..'../',table.concat(lines,'\n'))
    end
    C.saved_rules=dofile(dir..'rules.lua')(R,C)
    local net;net,transport=dofile(dir..'net.lua')(R,C)
    C.net=net
    C.abilities=dofile(dir..'abilities.lua')(R,C)
    -- (the level each world is, in the log: which map a match went on to, e.g. after a surrender)
    R.on('world_begin',function(world)
        R.log('Core','World begin %s',C.level(world) or '?')
        refresh(world,nil)
        transport.arrived(world)
    end)
    R.on('local_player',function(pc) refresh(pc:GetWorld(),pc) end)
    -- (the game marks the session in a match after a guest's player can already be there: the session is told again
    -- then - live 11-21 a guest stayed offline the whole match once the host's mode message, which used to retell it,
    -- was gone)
    R.post('/Game/Blueprints/Core/B_GameInstance.B_GameInstance_C:SetIsCurrentlyInMatch',function() refresh(current.world,current.pc) end)
    -- (back in the main menu: off the server, what waited for a level is nobody's. Not by the role - at a world's
    -- begin a guest's player is not there yet and the role reads offline, and travel passes a map between: live
    -- VM2 11-21 the host's mode and rules for Stoneage were dropped on arriving there, the match was vanilla)
    R.post('/Game/UserInterface/WB_MainMenu.WB_MainMenu_C:Construct',function() transport.left() end)
    R.on('world_end',function()
        R.log('Core','World end role=%s mode=%s',current.role,current.mode)
        refresh(nil,nil)
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
