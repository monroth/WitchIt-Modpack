local dir=debug.getinfo(1,'S').source:match('^@(.+[\\/])')
return function(R,C,T,changed)
    local M={}
    -- A host whose Core this one cannot read (its mods cannot be told, so not downloaded).
    M.INCOMPATIBLE="The host's Witch It+ Core is incompatible with yours, so its mods cannot be downloaded."
    local P=dofile(dir..'modpack.lua')(R.json,R.manifests)
    local wires,packageOf=P.wires,P.packageOf
    local mismatch,public_map,parse_advert=P.mismatch,P.public_map,P.parse_advert
    M.wires,M.wire_name,M.parse_advert,M.clean_name,M.console_only=wires,P.wire_name,parse_advert,P.clean_name,P.console_only
    local installed,packages={},{}
    -- The Vanilla server boxes (Custom Match, Creative): their defaults and their one writer (audit
    -- 11-20: UIKit's boxes and Core's memory wrote the settings themselves, the defaults repeated).
    M.VANILLA={match={key='VanillaServer',default=true},creative={key='CreativeVanillaServer',default=false}}
    local config=R.settings('Core',{VanillaServer=M.VANILLA.match.default,CreativeVanillaServer=M.VANILLA.creative.default,RememberSettings=true,RulesPerMode=true})
    function M.set_vanilla(which,value) config[M.VANILLA[which].key]=value;R.save_settings('Core') end
    -- A mod's build, what must match: the updater's version of the record holding its manifest (a
    -- nightly's carries its stamp; the manifest only the base), else the manifest's (a local build).
    -- The updater's folder: its record of what is installed and the sources it has read.
    local home=dir..'../../.witchit-updater/'
    local function decode(path)
        local file=io.open(path,'rb');if not file then return nil end
        local ok,value=pcall(R.json.decode,file:read('a'));file:close()
        return ok and type(value)=='table' and value or nil
    end
    local function installed_mods() local list=decode(home..'installed-mods.json');return list and type(list.mods)=='table' and list.mods or {} end
    local builds,sources={},{}   -- mod folder -> the installed version; -> the GitHub repository it came from
    for _,m in pairs(installed_mods()) do
        for _,path in ipairs(type(m.files)=='table' and m.files or {}) do
            local id=type(path)=='string' and path:match('^ue4ss/Mods/([^/]+)/manifest%.lua$')
            if id and type(m.version)=='string' then builds[id]=m.version end
            if id and type(m.source)=='string' and m.source:match('^[%w%-%._]+/[%w%-%._]+$') then sources[id]=m.source end
        end
    end
    for _,id in ipairs(R.package_ids) do
        local path=dir..'../'..id..'/manifest.lua'
        local file=io.open(path,'rb')
        if file then
            file:close();local manifest=dofile(path)
            local infrastructure=id=='Core' or id=='UIKit'
            local enabled=infrastructure or manifest.enabled~=false
            -- (a record whose base is not the manifest's is stale: the folder was replaced by hand)
            local version=builds[id] and builds[id]:match('^[^-]+')==manifest.version and builds[id] or manifest.version
            installed[#installed+1]={id=id,name=R.mod_name(id),version=version,enabled=enabled,required=infrastructure,source=sources[id]}
            if wires[id] and enabled then packages[wires[id]]=version end
        end
    end
    -- This start, for the launcher (it offers the earlier versions of a mod that fails after a
    -- change): each mod's version and the mods that failed, by id -> the error's first line.
    M.failed={}
    local function write_start()
        local versions={}
        for _,row in ipairs(installed) do versions[row.id]=row.version end
        local file=io.open(home..'started.json','wb')
        if file then file:write(R.json.encode({at=os.time(),versions=versions,failed=M.failed}));file:close() end
    end
    write_start()
    R.on('failure',function(why)
        -- The mod at fault: the first line of the error and its trace naming a mod's folder (live VM2 11-21 a
        -- Match Rules ++ failure was told as 'A mod': the runtime's own Scripts folder further down the trace was
        -- taken first, and it has no manifest).
        local id
        for line in tostring(why):gmatch('[^\n]+') do
            for part in line:gmatch('[^/\\:]+') do if R.manifests[part] then id=part end end
            if id then break end
        end
        M.failed[R.manifests[id] and id or '?']=tostring(why):gsub('\n.*','')
        write_start()
    end)
    -- What the launcher left for the game: the mods with updates waiting (their names), read once.
    local notice=decode(home..'launcher.json')
    M.updates=notice and type(notice.updates)=='table' and notice.updates or {}
    local gp=StaticFindObject('/Script/Engine.Default__GameplayStatics')
    local identity={protocol=3,packages=packages,required={},vanilla=true,require_modpack=false}
    M.identity=identity   -- (what this host advertises; replaced on each hosting)
    -- The join's mod mismatch: Core keeps it and whether it was shown (audit 11-20: UIKit kept its own copy
    -- to tell a new one). take_message() gives a new one once, for the screen to show.
    local fresh=false
    local function notice(message)
        if message~=M.message then fresh=message~=nil end
        if message~=M.message then R.log('Core','Join mod check: %s',message or 'the host\'s mods match') end
        M.message=message
    end
    function M.take_message() if fresh then fresh=false;return M.message end end
    local hosting=false
    -- An official server (the game's own, run by its makers): what the server tells of itself when joined - a
    -- dedicated server that is not a player's custom one (live 11-21: Europe-09 said IsDedicated=true and had no
    -- IsCustom; a player's server says IsCustom=true, IsDedicated=false; neither runs anti-cheat).
    local official=false
    function M.official_session() return official end
    local remote
    -- Whether this session is vanilla: what the host advertises (hosting: its own identity).
    -- Whether the host of this session has mod id - a synced one (a mod that is not synced is each player's own:
    -- the host never tells of it). Read by Core's session views (C.session_of).
    function M.host_has(id)
        local wire=wires[id]
        return wire==nil or remote~=nil and remote.packages[wire]~=nil
    end
    -- The host's mode, as it said when this game joined (nil: not a guest, or a vanilla server).
    function M.host_mode() return not hosting and remote and remote.mode or nil end
    function M.vanilla_session() if hosting then return identity.vanilla end return not remote or remote.vanilla end
    local peers={}
    M.config=config
    local function compatibility(p)
        local message
        if identity.vanilla then message=nil
        elseif p.packages then message=mismatch(identity.required,p.packages) end
        p.message=message
    end
    local function enforcing()
        return hosting and not identity.vanilla   -- (always: no option to let other mods in, user 11-20)
    end
    -- A guest whose mods differ from the host's (a player without mods never sees a modded server).
    -- (a kick's text to the guest it refuses: its prefix once, sent and read)
    local KICK='WIR2:K:'
    local function kick(p)
        if p.kicked or not enforcing() then return end
        p.kicked=true
        R.log('Core','Kick %s',p.name)
        local reason=p.message
        p.pc:ClientSetRevisionNumber(KICK..reason)
        gp:GetGameState(p.pc):SendChatMessageMulticast(FText(p.name..': '..reason),p.pc.PlayerState,0,{})
        local lib=StaticFindObject('/Script/PropWitchHuntModule.Default__ProjectVersionBlueprint')
        lib:KickPlayer(gp:GetGameMode(p.pc),p.pc,FText(reason))
    end
    -- Each world asks its guests again (a guest kept through a travel answers on his new controller).
    local function clear_peers() peers={} end
    local function peer(pc)
        local key=pc:GetAddress()
        local p=peers[key]
        if not p then
            local connection=pc.NetConnection
            local name=pc.PlayerState:GetPlayerName()
            p={pc=pc,transport=connection,name=R.text(name)}
            peers[key]=p;compatibility(p)
        end
        return p
    end
    -- The handshake: the host asks each guest once per world by sending its identity (on
    -- login, or on world load for a guest that travelled in); the guest answers every question
    -- with its list of packages; the host keeps, refuses or kicks on that list.
    local function ask(p)
        if p.asked or identity.vanilla then return end
        p.asked=true
        T.send(p.pc,'core.identity',identity)
    end
    local function correct_rate(p)
        local connection=p.transport
        if connection.CurrentNetSpeed~=20000 then return end
        local driver=connection.Driver
        local cap=math.min(100000,driver.MaxClientRate,driver.MaxInternetClientRate)
        if cap>20000 then connection.CurrentNetSpeed=cap end
    end
    local PREFIX=P.PREFIX
    local clean_name=P.clean_name
    -- A modded server says another game version: the game version and this mark. A vanilla
    -- player's search asks for the game's own version and the server list shows that version only,
    -- so no vanilla player finds it; Core's searches ask for any version and show the marked one
    -- as the game's own (below). It also says it is PS5 only and Xbox only at once: the vanilla game
    -- on PC refuses to join such a server, also through a friend; a modded player's join takes the
    -- marks off first (below).
    local MARK='+WitchItPlus'
    local EXCLUSIVE=P.EXCLUSIVE
    local versionOf=StaticFindObject('/Script/PropWitchHuntModule.Default__ProjectVersionBlueprint')
    local function game_version() return R.text(versionOf:GetProjectVersion()) end
    -- (options: the match options hosted; a mod's mode is listed under the mod's name, user 10-07)
    local function advertise(settings,options)
        identity.require_modpack=not identity.vanilla
        local entries=settings.Settings
        -- (a vanilla session whose advert carries none of our marks is left as the game made it: the advert
        -- itself says whether it is marked - audit 11-20, a flag kept beside it)
        if identity.vanilla and not entries:Contains(FName('WitchItModpack')) then return end
        local key=FName('SessionName')
        if entries:Contains(key) then
            local old=entries:Find(key):get();local name=R.text(old.Data.AsString)
            local desired=(identity.vanilla and '' or PREFIX)..clean_name(name)
            if desired~=name then entries:Add(key,{Data={Type=6,AsString=desired},AdvertisementType=3,ID=old.ID}) end
        end
        local modded=not identity.vanilla
        if modded then
            entries:Add(FName('WitchItModpack'),{Data={Type=6,AsString=R.json.encode(identity)},AdvertisementType=3,ID=0})
        elseif entries:Contains(FName('WitchItModpack')) then entries:Remove(FName('WitchItModpack')) end
        for _,name in ipairs(EXCLUSIVE) do entries:Add(FName(name),{Data={Type=9,AsBool=modded},AdvertisementType=3,ID=0}) end
        local mode=FName('GameMode')
        if modded and options and entries:Contains(mode) then
            for _,id in ipairs(C.map.modes()) do
                local spec=C.map.spec(id)
                if spec.selected and spec.selected(options) then
                    local old=entries:Find(mode):get()
                    entries:Add(mode,{Data={Type=6,AsString=spec.name},AdvertisementType=old.AdvertisementType,ID=old.ID})
                    break
                end
            end
        end
        local version=FName('VersionNumber')
        if entries:Contains(version) then
            local old=entries:Find(version):get()
            entries:Add(version,{Data={Type=6,AsString=game_version()..(modded and MARK or '')},AdvertisementType=old.AdvertisementType,ID=old.ID})
        end
    end
    -- Core's searches ask for any version and console-only servers too (the modded servers'); a
    -- really console-only server is one that says so without the modpack advert (the list leaves
    -- it out: C.mods.console_only).
    R.pre('/Script/OnlineSubsystemBlueprints.OnlineSessionSubsystemFindSessions:FindSessions',function(_,subsystem,user,search)
        if not R.valid(search) then return end
        search.SearchParams:Remove(FName('VersionNumber'))
        for _,name in ipairs(EXCLUSIVE) do search.SearchParams:Remove(FName(name)) end
    end)
    -- Joining a modded server: its console-only marks go before the game looks. Every join passes
    -- here: the list, a password, an invite, a friend.
    -- A host whose mods this game does not match is not joined: the reason is told at once (M.refusal,
    -- shown by UIKit) - user 11-20: a join through Steam failed without a word (the host's own refusal
    -- comes only once connected, and that join never got so far).
    R.pre('/Game/Blueprints/Core/B_GameInstance.B_GameInstance_C:JoinFromServerList',function(gi)
        local settings='SearchResult.Session.SessionSettings.Settings'
        if not R.native.frame(gi,settings..'[WitchItModpack]') then return end
        local host=parse_advert(R.native.frame(gi,settings..'[WitchItModpack].Data.AsString') or '')
        local reason=not host and M.INCOMPATIBLE or mismatch(host.required,packages)
        if reason then
            R.log('Core','Join refused here: %s',reason)
            M.refusal={text=reason,host=host}   -- (UIKit offers the host's mods: user 11-21)
            return true
        end
        for _,name in ipairs(EXCLUSIVE) do
            if R.native.frame(gi,settings..'['..name..'].Data.AsBool') then R.native.frame(gi,settings..'['..name..'].Data.AsBool',false) end
        end
    end)
    -- The server list shows a server of the game's own version only: a modded one counts as that.
    R.observe('/Game/UserInterface/Play/WB_ServerListBase.WB_ServerListBase_C:HandleServerFoundEOS',function(w)
        local path='CurrentServer.Session.SessionSettings.Settings[VersionNumber].Data.AsString'
        -- (every server a search finds, in the log: user 11-21 the host's was in no list)
        R.log('Core','Server found: %s (version %s, modded %s)',tostring(R.native.frame(w,'CurrentServer.Session.SessionSettings.Settings[SessionName].Data.AsString')),
            tostring(R.native.frame(w,path)),tostring(R.native.frame(w,'CurrentServer.Session.SessionSettings.Settings[WitchItModpack]')~=nil))
        local own=game_version()
        if R.native.frame(w,path)==own..MARK then R.native.frame(w,path,own) end
    end)
    local SESSION='/Script/OnlineSubsystemBlueprints.'
    -- Hosting these options: the setting that decides (Creative's or the other modes'), and whether
    -- the server is vanilla.
    local function setting(options)
        return C.creative(options) and 'CreativeVanillaServer' or 'VanillaServer'
    end
    -- When a mod must match on guests: each mod says it (C.mods.require(when)): when(options) of a
    -- modded session's hosted options.
    local requirements={}
    function M.require(when) requirements[#requirements+1]={id=R.owner('Core'),when=when} end
    function M.vanilla(options) return config[setting(options)]==true end
    R.pre(SESSION..'OnlineSessionSubsystemCreateSession:CreateSession',function(_,subsystem,pc,name,settings)
        hosting,remote,official=true,nil,false
        -- Both hosting dialogs put the options being hosted in UsedMatchOptions before HostGame.
        local options=gp:GetGameInstance(subsystem).UsedMatchOptions
        -- (what is hosted, in the log: user 11-21 a guest found the server in no list)
        R.log('Core','Hosting a session: public %s, password %s, mode %s, vanilla server %s',tostring(options.IsPublic),
            tostring(options.UsePassword),tostring(R.valid(options.GameMode) and options.GameMode:GetFName():ToString()),tostring(M.vanilla(options)))
        local required={}
        if not M.vanilla(options) then
            -- The mods that say so, and the mods whose map modules the session's maps need.
            local function need(id) local wire=wires[id];if wire and packages[wire] then required[wire]=packages[wire] end end
            for _,r in ipairs(requirements) do if r.when(options) then need(r.id) end end
            for id in pairs(C.catalog.session_needs(options)) do
                local spec=C.map.spec(id)
                if spec then need(spec.package) end
            end
        end
        -- (the mode too: a guest takes it once, on joining, for the whole session - user 11-21: it was sent again on
        -- every map, and a guest that missed it played the match as vanilla)
        local mode=C.map.chosen(options) or R.valid(options.GameMode) and options.GameMode:GetFName():ToString() or nil
        identity={protocol=3,packages=packages,required=required,vanilla=next(required)==nil,mode=mode,
            require_modpack=next(required)~=nil,sources=M.host_sources()}
        M.identity=identity;changed()
        advertise(settings,options)
    end)
    -- (the online session as a server is made: still the last one's or none - to check that a quick re-host after
    -- leaving made a match with no session, user 11-21; the cure waits for this to be proven)
    R.pre('/Game/Blueprints/Core/B_GameInstance.B_GameInstance_C:HostGame',function()
        local subsystem=R.valid(FindFirstOf('OnlineSessionSubsystem'))
        if not subsystem then return end
        R.log('Core','Hosting: the online session before it is %s (0 none, 7 being removed), sessions %s',
            tostring(subsystem:GetSessionState(FName('GameSession'))),tostring(subsystem:GetNumSessions()))
    end)
    -- Every step of the game's online session, joining and invites, on every machine, in the log as it happens
    -- (user 11-21: these faults come once in a hundred matches and cannot be made again on purpose - one time must
    -- tell everything): the call, its arguments, the role, the session's name and how many sessions there are.
    local function sessions()
        local subsystem=R.valid(FindFirstOf('OnlineSessionSubsystem'))
        return subsystem and tostring(subsystem:GetNumSessions()) or '?'
    end
    local function said(v)
        if type(v)~='userdata' then return tostring(v) end
        for _,how in ipairs({'ToString','GetFullName'}) do
            local ok,out=pcall(function() return v[how](v) end)
            if ok and out~=nil then return tostring(out) end
        end
        return tostring(v)
    end
    local GI='/Game/Blueprints/Core/B_GameInstance.B_GameInstance_C:'
    local SM='/Game/Blueprints/Match/B_SessionManager.B_SessionManager_C:'
    local steps={}
    for _,fn in ipairs({'DestroySessionCaller','HandleTravelError','JoinFromServerList','JoinQuickMatchCustomGame','JoinQuickMatchUsingNewServerBrowser',
        'JoinQuickMatchUsingSessionFind','JoinSessionFromInvite','SessionInviteAccepted','ShowSessionLockedMessage','RegisterSession','UnregisterSession',
        'OnCreateSessionComplete_8BB34145411B8BA94B10A59EFF71E0CF','OnCreateSessionComplete_BED0C0C544BDA84E192C8B8C5BB82F72',
        'OnDestroySessionComplete_24DC469A4EBBEE2F2FB50CB0893FEC02','OnDestroySessionComplete_D7D987824E029A67C28C27A7944576BA','OnDestroySessionComplete_F48D3023411050490BA5D192B95E2377',
        'OnDestroySessionComplete_FA9075FE47ED7DF7A837BC8B69A6DEB7','OnDestroySessionComplete_FA9075FE47ED7DF7A837BC8B6D11725B','OnDestroySessionComplete_FA9075FE47ED7DF7A837BC8BC027921D',
        'OnFindSessionsComplete_DE2BE46F4484E3CC5050769BC42D5D32','OnFindSessionsComplete_DE990FDB4B0DC5A886D13582C2A33E2F','OnJoinSessionComplete_CB75E000453710ACAA45C2ADD0B80AC6'}) do steps[#steps+1]=GI..fn end
    for _,fn in ipairs({'DestroyOnlineSession','EndOnlineSession','StartOnlineSession','UpdateSessionProperties','RegisterPlayerToSession','UnregisterPlayerFromSession',
        'SendCurrentSessionInfo','OnDestroySessionComplete_3A9EE90449D09BFAC83E6C9F99AC1DE8','OnDestroySessionComplete_9955D3F2405DD6FD99DDC2850641DF1E',
        'OnEndSessionComplete_64CE9DA44A206F0283C61FB45E0662EB','OnStartSessionComplete_D646C4F343728FB964A45EA8EB46F8A9','OnUpdateSessionComplete_826D75FB4D5254C3DBF6FB9F75F4A431'}) do steps[#steps+1]=SM..fn end
    steps[#steps+1]='/Game/Blueprints/Core/B_GameMode.B_GameMode_C:OnDestroySessionComplete_BC6CE1BA4A9064285EE44985FF9B06B2'
    steps[#steps+1]='/Game/Blueprints/Core/B_GameMode.B_GameMode_C:OnCallFailed_BC6CE1BA4A9064285EE44985FF9B06B2'
    for _,path in ipairs(steps) do
        R.post(path,function(_,...)
            local args={}
            for i=1,select('#',...) do args[#args+1]=said((select(i,...))):sub(1,120) end
            local s=C.session()
            local gi=R.valid(s.gi)
            R.log('Core','Online step %s(%s) - role %s, level %s, session name %s, sessions %s',(path:match(':([%w_]+)$'):gsub('_%x+$','')),
                table.concat(args,', '),tostring(s.role),tostring(C.level(s.world)),gi and gi.CurrentOnlineSessionName:ToString() or '?',sessions())
        end)
    end
    -- (every start, end and removal of an online session, with the map and the role, in the log - user 11-21: a
    -- host was found with no online session while its match went on, and when it went was unknown)
    for _,step in ipairs({'StartSession','EndSession','DestroySession'}) do   -- (creating one is logged as 'Hosting a session')
        R.pre(SESSION..'OnlineSessionSubsystem'..step..':'..step,function(_,subsystem,a,b)
            local s=C.session()
            local name=type(a)=='userdata' and pcall(function() return a:ToString() end) and a:ToString() or type(b)=='userdata' and pcall(function() return b:ToString() end) and b:ToString() or '?'
            R.log('Core','Online session %s (%s) - role %s, level %s',step,tostring(name),tostring(s.role),tostring(C.level(s.world)))
        end)
    end
    R.pre(SESSION..'OnlineSessionSubsystemUpdateSession:UpdateSession',function(_,subsystem,name,settings)
        if not hosting then return end
        advertise(settings,gp:GetGameInstance(subsystem).UsedMatchOptions)
    end)
    R.pre(SESSION..'OnlineSessionSubsystemJoinSession:JoinSession',function(_,subsystem,pc,name,result)
        hosting=false
        local entries=result.Session.SessionSettings.Settings
        -- (everything the joined server tells of itself: to learn what marks an official server - user 11-21,
        -- the anti-cheat launch did not, private cosmetics worked there)
        local told={}
        entries:ForEach(function(key,value)
            local data=value:get().Data
            told[#told+1]=key:get():ToString()..'='..(data.Type==6 and R.text(data.AsString) or tostring(data.AsInt)..'/'..tostring(data.AsBool))
        end)
        table.sort(told)
        R.log('Core','Joining a server: %s',table.concat(told,', '))
        local function flag(name) return entries:Contains(FName(name)) and entries:Find(FName(name)):get().Data.AsBool==true end
        official=flag('IsDedicated') and not flag('IsCustom')
        R.log('Core','Server joined: %s',official and 'official' or 'a player\'s')
        remote=nil;notice(nil)
        if entries:Contains(FName('WitchItModpack')) then
            remote=parse_advert(R.text(entries:Find(FName('WitchItModpack')):get().Data.AsString))
            if not remote then notice(M.INCOMPATIBLE) end
        end
        if remote then R.log('Core','The host plays %s (for this whole session)',tostring(remote.vanilla and 'vanilla' or remote.mode));notice(mismatch(remote.required,packages)) end
        changed()
    end)
    R.post('/Game/UserInterface/WB_MainMenu.WB_MainMenu_C:Construct',function()
        hosting,remote,official=false,nil,false;notice(nil)
        clear_peers()
        changed()
    end)
    C.net.watch('core.identity',function(value,pc)
        if hosting then return end
        local parsed=parse_advert(R.json.encode(value))
        if not parsed then R.log('Core','Host identity unreadable (incompatible Core)');notice(M.INCOMPATIBLE);return end
        remote=parsed
        changed()
        notice(mismatch(parsed.required,packages))
        -- The host's question arrives on the controller to answer on.
        if not parsed.vanilla and pc then T.request(pc,'core.inventory',packages) end
    end)
    C.net.on_request('core.inventory',function(ps,value)
        if not hosting or not R.valid(ps) or not public_map(value) or not value.core then
            if hosting then R.log('Core','A guest\'s modpack answer was unreadable or has no Core: ignored') end
            return
        end
        local pc=R.valid(ps:GetOwner());if not pc or pc:IsLocalPlayerController() then return end
        local p=peer(pc);p.packages=value
        compatibility(p)
        R.log('Core','Modpack from %s: %s',p.name,p.message and 'mismatch' or 'ok')
        if p.message then kick(p) end
        if not identity.vanilla and not p.kicked then
            T.add(pc)
            T.replay(pc)
            correct_rate(p)
        end
    end)
    -- The match as a join or a leave found it, for the log.
    local function moment(pc)
        local gs=C.session().gs
        return string.format('state=%s round=%s kicked=%s',gs and tostring(gs.State),gs and tostring(gs.CurrentRound),
            tostring(pc.IsBeingKickedDueMatchHasStarted))
    end
    local function login(ps)
        if not hosting or not R.valid(ps) then return end
        local pc=R.valid(ps:GetOwner())
        if not pc or pc:IsLocalPlayerController() then return end
        local p=peer(pc)
        R.log('Core','Join %s %s',p.name,moment(pc))
        ask(p)
    end
    R.on('player_joined',login)
    R.on('player_left',function(ps)
        if not R.valid(ps) then return end
        local pc=R.valid(ps:GetOwner());if not pc then return end
        local p=peers[pc:GetAddress()];if p then R.log('Core','Left %s %s',p.name,moment(pc)) end
        peers[pc:GetAddress()]=nil
        T.remove(pc)
    end)
    local creative_pc=C.CREATIVE_PC
    -- (the controller's own authority below - the server's copy of a guest's controller - not the session's role: audit 11-20)
    local function ready(pc,possessed)
        if not hosting or not R.valid(pc) or not pc:HasAuthority() or pc:IsLocalPlayerController() or identity.vanilla then return end
        -- Creative's game-message widget is constructed by the possessed spectator.
        -- Its initial null-pawn acknowledgement is an unpossession, not that event.
        if pc:IsA(creative_pc)~=possessed then return end
        local p=peer(pc)
        if p.kicked then return end
        if not p.loaded then p.loaded=true;R.log('Core','World loaded by %s (modpack %s)',p.name,p.packages and 'known' or 'not yet') end
        if p.packages and not p.message then correct_rate(p) end
        ask(p)
    end
    R.post('/Script/Engine.PlayerController:ServerShortTimeout',function(pc) ready(pc,false) end)
    -- A guest kept through a travel (halftime) reports each world it has loaded, the transition map
    -- too; the engine's RPC carries the package name alone (no final-destination flag), so the
    -- world is ours when it names the host's current one, as the engine itself checks.
    R.post('/Script/Engine.PlayerController:ServerNotifyLoadedWorld',function(pc,worldPackage)
        local name=worldPackage and (worldPackage.ToString and worldPackage:ToString() or tostring(worldPackage))
        local world=R.valid(pc:GetWorld())
        if name and world and world:GetFullName():find(' '..name..'.',1,true) then ready(pc,false) end
    end)
    R.post('/Script/Engine.PlayerController:ServerAcknowledgePossession',function(pc,pawn)
        if R.valid(pawn) then ready(pc,true) end
    end)
    R.post('/Game/Blueprints/Player/B_PlayerController.B_PlayerController_C:ClientSetRevisionNumber',function(pc,text)
        text=R.text(text)
        if not pc:HasAuthority() and pc:IsLocalPlayerController() and text:sub(1,#KICK)==KICK then M.refusal={text=text:sub(#KICK+1)} end
    end)
    R.on('world_end',clear_peers)
    -- Whether a mod is on from the next start (its manifest as it is on disk now).
    local function next_enabled(row) return row.required or dofile(dir..'../'..row.id..'/manifest.lua').enabled~=false end
    local installed_update
    function M.status()
        local rows={};local restart=false
        for _,row in ipairs(installed) do
            local next_enabled=next_enabled(row)
            rows[#rows+1]={id=row.id,name=row.name,version=row.version,enabled=row.enabled,next_enabled=next_enabled,required=row.required,source=row.source}
            if row.enabled~=next_enabled then restart=true end
        end
        local bytes=WitchItNativeUpdater('status')
        local update=bytes and R.json.decode(bytes)
        -- An installed update is told on the start it happened: the notice is kept for this game
        -- and taken from the updater's folder.
        if update and update.kind=='updated' then installed_update=update;WitchItNativeUpdater('ack') end
        return {packages=rows,restart_required=restart,update=update or installed_update}
    end
    -- Joining a server with other mods: the game restarts with them (the updater starts it again
    -- once this one has exited; the start activates the downloaded mods) and goes back to the server.
    -- What to join is kept until then: the server's name and the menu its list was opened with.
    -- staged: the mods are downloaded and the updater applies them as this game exits (it then
    -- starts the game itself); otherwise a plain restart.
    -- join nil: only a restart (a join Core refused: the player joins again as they did).
    function M.relaunch(join,staged)
        if join then config.join=join;config.join.at=os.time();R.save_settings('Core') end
        R.log('Core','Restarting%s (menu %s, %s)',join and ' to join '..tostring(join.name) or '',tostring(join and join.menu),staged and 'mods staged' or 'no download')
        WitchItNativeUpdater(staged and 'relaunch-after-update' or 'relaunch')
        local world=C.session().world
        StaticFindObject('/Script/Engine.Default__KismetSystemLibrary'):QuitGame(world,nil,0,false)
    end
    -- The server to join after such a restart (only soon after it), until it is joined.
    function M.pending_join()
        local join=config.join
        return join and os.time()-(join.at or 0)<=600 and join or nil
    end
    function M.take_join() config.join=nil;R.save_settings('Core') end
    local menu
    R.pre('/Game/Blueprints/UserInterface/B_MenuUIManager.B_MenuUIManager_C:ChangeMenu',function(_,state) menu=state end)
    function M.menu() return menu end
    -- Where a host's mods come from, for the players joining it: a line a repository,
    -- "owner/repo: id@version, id@version" (builds of the host's own are left out; a long list is cut).
    -- (from the mods as loaded - the versions the identity carries; the updater's file may already name
    -- newer ones that are not running yet, audit 11-20)
    function M.host_sources()
        local by={}
        for _,m in ipairs(installed) do
            if m.source and m.source~='local' then by[m.source]=by[m.source] or {};table.insert(by[m.source],m.id..'@'..m.version) end
        end
        local lines={}
        for source,items in pairs(by) do table.sort(items);lines[#lines+1]=source..': '..table.concat(items,', ') end
        table.sort(lines)
        return table.concat(lines,'\n'):sub(1,900)
    end
    -- A host's lines read back: source -> {id -> version}.
    function M.read_sources(text)
        local out={}
        for line in (type(text)=='string' and text or ''):gmatch('[^\n]+') do
            local source,items=line:match('^([%w%-%._]+/[%w%-%._]+): (.+)$')
            if source then
                for id,version in items:gmatch('([%w%._%-]+)@([%w%._%-]+)') do
                    out[source]=out[source] or {};out[source][id]=version
                end
            end
        end
        return out
    end
    local function run(request)
        WitchItNativeUpdateFile('request',R.json.encode(request))
        WitchItNativeUpdater('check')
    end
    -- Taking a host's mods: its exact versions (the host plays them, so they hold together), read
    -- from its sources' indexes. done(prepared): prepared.missing lists what cannot be had (then
    -- nothing is taken); prepared.mods the versions to download; prepared.changes whether any differs.
    -- Only the mods the host requires in its session are taken (user 11-21: a mode's mod only when that mode
    -- is hosted - each mod says when, C.mods.require); the rest of its lines are its own business.
    function M.prepare_host(host,done)
        local wanted={}
        for source,ids in pairs(M.read_sources(host.sources)) do
            for id,version in pairs(ids) do
                local wire=wires[id]
                if wire and (host.required or {})[wire] then wanted[source]=wanted[source] or {};wanted[source][id]=version end
            end
        end
        local list={}
        for source in pairs(wanted) do list[#list+1]=source end
        R.log('Core','Reading the host\'s mod sources: %s',#list>0 and table.concat(list,', ') or 'none listed')
        local function prepare()
            local have=installed_mods()
            local prepared={missing={},blocked={},mods={},changes=false,host=host}   -- (blocked: wire ids that cannot be had)
            local covered={}
            for source,ids in pairs(wanted) do
                local read=decode(home..'sources/'..source:gsub('/','~',1)..'.json')
                local index=read and read.index and read.index.mods or {}
                for id,version in pairs(ids) do
                    local m=index[id];local entry=m and m.versions and m.versions[version]
                    local key=source..':'..id
                    if not entry then prepared.missing[#prepared.missing+1]=id..' '..version;prepared.blocked[wires[id]]=true
                    else
                        local folders=entry.folders or m.folders or {}
                        for _,f in ipairs(folders) do covered[f]=true end
                        prepared.mods[key]={source=source,id=id,version=version,sha256=entry.sha256,folders=folders}
                        if not (have[key] and have[key].version==version) then prepared.changes=true end
                    end
                end
            end
            -- Every mod the host requires (Core need not match) is the same here already or comes from its lines.
            for wire,version in pairs(host.required or {}) do
                local folder=packageOf[wire]
                if wire~='core' and packages[wire]~=version and not (folder and covered[folder]) then
                    prepared.missing[#prepared.missing+1]=P.wire_name(wire)..' '..version;prepared.blocked[wire]=true
                end
            end
            R.log('Core','Host mods: %d to download, %d missing%s',(function() local n=0;for _ in pairs(prepared.mods) do n=n+1 end;return n end)(),#prepared.missing,
                #prepared.missing>0 and ' ('..table.concat(prepared.missing,', ')..')' or '')
            done(prepared)
        end
        run({request='fetch',sources=list})
        R.native.on_update(prepare)
    end
    -- Download what prepare_host found (the game's other mods stay); report(ok, why) once it has
    -- started (restart: the game restarts with them).
    -- While a download runs: {done=, total=, mod=} (nil when none runs).
    function M.progress()
        local bytes=WitchItNativeUpdater('progress')
        return bytes and R.json.decode(bytes)
    end
    function M.take_host(prepared,report,restart)
        R.log('Core','Taking the host\'s mods: %s',prepared.changes and 'downloading' or 'already installed')
        if not prepared.changes then report(false,'The host’s versions are already installed; restart the game to use them.');return end
        run({request='apply',mods=prepared.mods,handoff=restart==true,origin={host=prepared.host and prepared.host.name or ''}})
        report(true,'Downloading. Restart the game to use the new versions.')
    end
    return M
end
