local M={}
-- Rows that reference one another restore together: by parent, by reference path, and by an
-- existing actor a row names in its state's `external` that is another row (same class, within
-- 5 units: the companion may name it by another path; matched natively the same way).
function M.groups(rows,states)
    local by,root={},{}
    for i,r in ipairs(rows) do by[r.source],root[i]=i,i end
    local function find(i)
        while root[i]~=i do
            root[i]=root[root[i]]
            i=root[i]
        end
        return i
    end
    local function link(i,path)local j=by[path];if j then root[find(i)]=find(j)end end
    for i,r in ipairs(rows)do
        if r.parent then link(i,r.parent.source)end
        for _,path in ipairs(r.references or {})do link(i,path)end
        local external=states and states[r.state] and states[r.state].external or {}
        for path,target in pairs(external)do
            if not by[path] then
                local t=target.transform
                for j,o in ipairs(rows)do
                    local u=o.transform
                    if o.class==target.class and(t[1]-u[1])^2+(t[2]-u[2])^2+(t[3]-u[3])^2<=25 then root[find(i)]=find(j)end
                end
            end
        end
    end
    local result,index={},{}
    for i,r in ipairs(rows) do
        local k=find(i)
        if not index[k] then
            index[k]=#result+1
            result[#result+1]={}
        end
        local group=result[index[k]]
        group[#group+1]=r
    end
    return result
end
function M.restore(R,s,current,done)
    local d=s.data.geometry
    if not d or #d.actors==0 then done();return end
    R.log('BaseWorldPlus','Restoring %d source geometry actors, a few groups a frame',#d.actors)
    local groups=M.groups(d.actors,d.states);local at=1
    -- Groups once no class is loading (creating actors meanwhile can hang the game), as many as fit in
    -- 12 ms of a frame (one group a frame made Sunset Halls' 170 actors take some 5 s of loading).
    local BUDGET=.012
    local step
    local function next_group() R.native.on_idle(step) end
    step=function()
        if not current()then return end
        local started=os.clock()
        repeat
            local group=groups[at]
            if not group then done();return end
            local rows={}
            for _,row in ipairs(group)do
                if s.host or row.role=='local'then rows[#rows+1]=row end
            end
            if #rows>0 then
                local actors,why=R.native.source_actors(rows,s.world,d.states)
                assert(actors,why or 'source actor group could not be restored')
                for _,a in ipairs(actors)do s.spawned[#s.spawned+1]=a end
            end
            at=at+1
        until os.clock()-started>=BUDGET
        R.next_frame(next_group)
    end
    next_group()
end
return M
