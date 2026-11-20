local M={}
function M.key(row)
    return row.kind..':'..row.path..(row.component and '|'..row.component or '')..(row.index and '|'..row.index or '')
end
function M.validate(d)
    assert(d.version==1 and type(d.world)=='string'and type(d.hidden)=='table','unknown world edits file')
    local hidden={}
    for _,r in pairs(d.hidden)do
        assert(type(r.path)=='string'and r.path:match('^/Game/'),'invalid object path')
        assert(r.kind=='actor'or r.kind=='component'or r.kind=='instance','unknown object edit')
        if r.kind=='component'then assert(type(r.component)=='string','missing component name')end
        if r.kind=='instance'then
            assert(type(r.mesh)=='string'and math.type(r.index)=='integer'and r.index>=0,'invalid saved instance')
            for name,axes in pairs({Translation={'X','Y','Z'},Rotation={'X','Y','Z','W'},Scale3D={'X','Y','Z'}})do
                for _,axis in ipairs(axes)do assert(type(r.transform[name][axis])=='number','invalid saved transform')end
            end
        end
        hidden[M.key(r)]=r
    end
    d.hidden=hidden
    -- Edits of base-world teleporters are gone (a vanilla teleporter is hidden and a placed one used instead).
    d.portals=nil
    if d.geometry then
        local g=d.geometry
        assert(g.format=='FAPP_SOURCE_GEOMETRY'and g.version==3 and type(g.actors)=='table'and type(g.states)=='table','invalid source geometry')
        assert(g.binding.folder==d.world,'geometry world differs')
        for _,r in ipairs(g.actors)do
            assert(r.restore=='actor'and(r.role=='authority'or r.role=='local')and type(r.class)=='string','invalid source actor')
            assert(type(r.source)=='string'and type(g.states[r.state])=='table'and #r.transform==9,'incomplete source actor')
        end
    end
    return d
end
-- World edits travel inside the layout as the map record's `monroth.bwp` data (MAPDATA.md).
-- With source geometry they reach about 1 MB.
M.ID,M.VERSION='monroth.bwp',1
local LIMIT=4194304-65536
function M.new(R)
    local S={}
    -- Record data -> world edits for this world, nil for edits of another world.
    function S.decode(bytes,world)
        local d=M.validate(R.json.decode(bytes,LIMIT))
        if d.world==world then return d end
    end
    function S.encode(d)
        if d.geometry then d.geometry.binding.folder=d.world end
        return R.json.encode(d,LIMIT)
    end
    return S
end
return M
