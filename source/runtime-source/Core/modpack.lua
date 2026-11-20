-- Modpack facts shared by hosting, joining and the server browser, from the mods' manifests:
-- the mods that must match between host and guest (manifest `sync`) by their wire id (the mod's id
-- in lower case), their names, advert parsing and version comparison.
return function(json,manifests)
    local P={wires={},packageOf={}}
    for id,manifest in pairs(manifests) do
        -- (Core is always listed: its presence marks a modpack client; its version need not match)
        if manifest.sync or id=='Core' then P.wires[id]=id:lower();P.packageOf[id:lower()]=id end
    end
    -- A modded server's name starts with this mark (vanilla lists never show one; Core's do).
    P.PREFIX='[MODDED] '
    function P.clean_name(name)
        while name:sub(1,#P.PREFIX)==P.PREFIX do name=name:sub(#P.PREFIX+1) end
        return name
    end
    -- A wire id's mod name; a mod not installed here goes by its wire id.
    function P.wire_name(wire)
        local manifest=manifests[P.packageOf[wire]]
        return manifest and manifest.name or wire
    end
    local wireName=P.wire_name
    -- -1, 0 or 1 for two x.y.z versions or builds (x.y.z-nightly.<stamp>): nightlies by their
    -- stamp, below the release of their base (as sources.lua orders them).
    function P.compare(a,b)
        local aa,bb={},{}
        for n in a:gmatch('%d+') do aa[#aa+1]=tonumber(n) end
        for n in b:gmatch('%d+') do bb[#bb+1]=tonumber(n) end
        for i=1,4 do
            local x,y=aa[i] or math.huge,bb[i] or math.huge
            if x~=y then return x<y and -1 or 1 end
        end
        return 0
    end
    -- What a guest must change to match the required packages, or nil.
    function P.mismatch(required,guest)
        local reasons={}
        for id,version in pairs(required) do
            if not guest[id] then reasons[#reasons+1]='Guest must enable '..wireName(id)..' '..version..'.'
            elseif guest[id]~=version then
                local side=P.compare(guest[id],version)<0 and 'Guest' or 'Host'
                reasons[#reasons+1]=side..' must update '..wireName(id)..' (host '..version..', guest '..guest[id]..').'
            end
        end
        table.sort(reasons);return #reasons>0 and table.concat(reasons,' ') or nil
    end
    -- A {wire id = version or build} map of mods (those not installed here too).
    function P.public_map(value)
        if type(value)~='table' then return false end
        local count=0
        for id,version in pairs(value) do
            if type(id)~='string' or not id:match('^[a-z0-9]+$') or #id>64 or type(version)~='string' or #version>32
                or not version:match('^%d+%.%d+%.%d+$') and not version:match('^%d+%.%d+%.%d+%-nightly%.%d+$') then return false end
            count=count+1
        end
        return count<=64
    end
    -- A host's advert, or nil when it is not a readable protocol 3 advert.
    function P.parse_advert(bytes)
        local ok,v=pcall(json.decode,bytes)
        if not ok or type(v)~='table' or v.protocol~=3 or not P.public_map(v.packages) or not v.packages.core
            or not P.public_map(v.required) or type(v.vanilla)~='boolean' or type(v.require_modpack)~='boolean' then return nil end
        for id,version in pairs(v.required) do if id=='core' or v.packages[id]~=version then return nil end end
        if v.sources~=nil and (type(v.sources)~='string' or #v.sources>900) then return nil end
        return v
    end
    -- A modded server says it is PS5 only and Xbox only at once (mods.lua: the vanilla game on PC
    -- does not join it). A really console-only server is one that says so without the modpack advert.
    P.EXCLUSIVE={'PS5Exclusive','XBLExclusive'}
    function P.console_only(data)
        local entries=data.ExtraSettings
        if entries:Contains(FName('WitchItModpack')) then return false end
        for _,name in ipairs(P.EXCLUSIVE) do
            local key=FName(name)
            if entries:Contains(key) and entries:Find(key):get().Data.AsBool then return true end
        end
        return false
    end
    return P
end
