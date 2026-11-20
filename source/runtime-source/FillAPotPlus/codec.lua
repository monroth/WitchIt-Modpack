-- Fill a Pot+ map data (version 2), JSON.
--   On a carrier block, the record `monroth.fap`: one marker -
--     {"kind":"cauldron","colour":[r,g,b],"down":32,"up":32,"radius":2500,"excluded":["/Game/...C",...]}
--     {"kind":"respawn"}
--   In the map record, the record `monroth.fap`: the map's own settings, once (user 11-20: the new format) -
--     {"target":3,"secret":false,"event":false}
--     (target: the cauldrons to win; secret, event: Secret and Event props may be wanted)
-- (Teleporters are World edits' markers.) In memory a marker is info: kind 1 (cauldron) or 2
-- (respawn point), colour {R,G,B,A}, excluded as a set.
return function(json,pink)
    local M={ID='monroth.fap',VERSION=2}
    local KINDS={'cauldron','respawn'}
    local kindOf={};for i,k in ipairs(KINDS) do kindOf[k]=i end

    function M.defaults(info)
        info.colour=info.colour or {R=pink.R,G=pink.G,B=pink.B,A=pink.A}
        info.down,info.up=info.down or 32,info.up or 32
        info.radius=info.radius or 2500
        info.excluded=info.excluded or {}
        return info
    end
    -- Record data -> info, or nil for a record this version does not know.
    function M.decode(data)
        local d=json.decode(data)
        local kind=type(d)=='table' and kindOf[d.kind]
        if not kind then return end
        local c=d.colour
        local excluded={};for _,path in ipairs(d.excluded or {}) do excluded[path]=true end
        return M.defaults({kind=kind,colour=c and {R=c[1],G=c[2],B=c[3],A=1},down=d.down,up=d.up,radius=d.radius,excluded=excluded})
    end
    function M.encode(info)
        local d={kind=KINDS[info.kind]}
        if info.kind==1 then
            local paths={};for path in pairs(info.excluded) do paths[#paths+1]=path end
            table.sort(paths)
            d.down,d.up,d.radius,d.excluded=info.down,info.up,info.radius,paths
            d.colour={info.colour.R,info.colour.G,info.colour.B}
        end
        return json.encode(d)
    end
    -- The map's settings from the map record's data (nil: a map without them - the defaults).
    function M.decodeMap(data) return M.mapOf(data and json.decode(data)) end
    function M.mapOf(d)
        if type(d)~='table' then d={} end
        local target=tonumber(d.target)
        return {target=target and math.max(1,math.floor(target)) or 3,secret=d.secret==true,event=d.event==true}
    end
    function M.encodeMap(m) return json.encode({target=m.target,secret=m.secret,event=m.event}) end
    return M
end
