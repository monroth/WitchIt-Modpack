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
    local config=R.settings('Core',{VanillaServer=M.VANILLA.match.default,CreativeVanillaServer=M.VANILLA.creative.default,RememberSettings=true})
    function M.set_vanilla(which,value) config[M.VANILLA[which].key]=value;R.save_settings('Core') end
    local private=false
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
            if manifest.private then private=true end
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
        -- (a mod's file is <Mod>/<file>.lua or <Mod>/Scripts/<file>.lua - live 11-20 a Creative Tools failure was
        -- told as 'A mod': its folder was taken for Scripts)
        local id=tostring(why):match('(%w+)[/\\]Scripts[/\\][%w_]+%.lua:%d+') or tostring(why):match('(%w+)[/\\][%w_]+%.lua:%d+')
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
        M.message=message
    end
    function M.take_message() if fresh then fresh=false;return M.message end end
    local hosting=false
    local remote
    -- Whether this session is vanilla: what the host advertises (hosting: its own identity).
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
            M.refusal=reason..'\nThe Server List can download the host\'s mods.'
            return true
        end
        for _,name in ipairs(EXCLUSIVE) do
            if R.native.frame(gi,settings..'['..name..'].Data.AsBool') then R.native.frame(gi,settings..'['..name..'].Data.AsBool',false) end
        end
    end)
    -- The server list shows a server of the game's own version only: a modded one counts as that.
    R.observe('/Game/UserInterface/Play/WB_ServerListBase.WB_ServerListBase_C:HandleServerFoundEOS',function(w)
        local path='CurrentServer.Session.SessionSettings.Settings[VersionNumber].Data.AsString'
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
        hosting=true;remote=nil
        -- Both hosting dialogs put the options being hosted in UsedMatchOptions before HostGame.
        local options=gp:GetGameInstance(subsystem).UsedMatchOptions
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
        identity={protocol=3,packages=packages,required=required,vanilla=next(required)==nil,
            require_modpack=next(required)~=nil,sources=M.host_sources()}
        M.identity=identity;changed()
        advertise(settings,options)
    end)
    R.pre(SESSION..'OnlineSessionSubsystemUpdateSession:UpdateSession',function(_,subsystem,name,settings)
        if not hosting then return end
        advertise(settings,gp:GetGameInstance(subsystem).UsedMatchOptions)
    end)
    R.pre(SESSION..'OnlineSessionSubsystemJoinSession:JoinSession',function(_,subsystem,pc,name,result)
        hosting=false
        local entries=result.Session.SessionSettings.Settings
        remote=nil;notice(nil)
        if entries:Contains(FName('WitchItModpack')) then
            remote=parse_advert(R.text(entries:Find(FName('WitchItModpack')):get().Data.AsString))
            if not remote then notice(M.INCOMPATIBLE) end
        end
        if remote then notice(mismatch(remote.required,packages)) end
        changed()
    end)
    R.post('/Game/UserInterface/WB_MainMenu.WB_MainMenu_C:Construct',function()
        hosting,remote=false,nil;notice(nil)
        clear_peers()
        changed()
    end)
    C.net.watch('core.identity',function(value,pc)
        if hosting then return end
        local parsed=parse_advert(R.json.encode(value))
        if not parsed then notice(M.INCOMPATIBLE);return end
        remote=parsed
        changed()
        notice(mismatch(parsed.required,packages))
        -- The host's question arrives on the controller to answer on.
        if not parsed.vanilla and pc then T.request(pc,'core.inventory',packages) end
    end)
    C.net.on_request('core.inventory',function(ps,value)
        if not hosting or not R.valid(ps) or not public_map(value) or not value.core then return end
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
        if not pc:HasAuthority() and pc:IsLocalPlayerController() and text:sub(1,#KICK)==KICK then M.refusal=text:sub(#KICK+1) end
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
    function M.relaunch(join,staged)
        config.join=join;config.join.at=os.time();R.save_settings('Core')
        R.log('Core','Restarting to join %s (menu %s, %s)',tostring(join.name),tostring(join.menu),staged and 'mods staged' or 'no download')
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
    function M.prepare_host(host,done)
        if private then done({missing={'(this is a private build: use the local rebuild and install process)'}});return end
        local wanted=M.read_sources(host.sources)
        local list={}
        for source in pairs(wanted) do list[#list+1]=source end
        local function prepare()
            local have=installed_mods()
            local prepared={missing={},mods={},changes=false,host=host}
            local covered={}
            for source,ids in pairs(wanted) do
                local read=decode(home..'sources/'..source:gsub('/','~',1)..'.json')
                local index=read and read.index and read.index.mods or {}
                for id,version in pairs(ids) do
                    local m=index[id];local entry=m and m.versions and m.versions[version]
                    local key=source..':'..id
                    if not entry then prepared.missing[#prepared.missing+1]=id..' '..version
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
                    prepared.missing[#prepared.missing+1]=P.wire_name(wire)..' '..version
                end
            end
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
        if not prepared.changes then report(false,'The host’s versions are already installed; restart the game to use them.');return end
        run({request='apply',mods=prepared.mods,handoff=restart==true,origin={host=prepared.host and prepared.host.name or ''}})
        report(true,'Downloading. Restart the game to use the new versions.')
    end
    return M
end
