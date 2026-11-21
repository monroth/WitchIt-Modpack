-- Map data in .pl files (MAPDATA.md): records in the tail of a block's bytes.
--   block bytes = game bytes | records | u32 tail size | "WIP1"
--   record      = u8 id size | id | u8 version | u32 data size | data
-- Records are {[id]={version=,data=}}. Pure functions over byte strings.
local M={}
local FOOTER='WIP1'
local function valid_id(id) return #id>=1 and #id<=32 and not id:find('[^a-z0-9._-]') end
M.valid_id=valid_id

-- Records sorted by id, without a footer (also the data of the map record).
function M.list(records)
    local ids={}
    for id in pairs(records) do assert(valid_id(id),'bad record id');ids[#ids+1]=id end
    table.sort(ids)
    local parts={}
    for i,id in ipairs(ids) do
        local r=records[id]
        parts[i]=string.pack('<s1BI4',id,r.version,#r.data)..r.data
    end
    return table.concat(parts)
end

-- Block bytes -> game bytes, records; nil and the reason for a broken tail.
function M.split(bytes)
    if #bytes<8 or bytes:sub(-4)~=FOOTER then return bytes,{} end
    local size=string.unpack('<I4',bytes,#bytes-7)
    if size<8 or size>#bytes then return nil,'tail size out of range' end
    local at,stop,records=#bytes-size+1,#bytes-8,{}
    while at<=stop do
        if at+1>stop then return nil,'truncated record' end
        local n=bytes:byte(at)
        local id=bytes:sub(at+1,at+n)
        if not valid_id(id) or records[id] then return nil,'bad or repeated record id' end
        at=at+1+n
        if at+4>stop then return nil,'truncated record' end
        local version,length=string.unpack('<BI4',bytes,at)
        at=at+5
        if at+length-1>stop then return nil,'truncated record data' end
        records[id]={version=version,data=bytes:sub(at,at+length-1)}
        at=at+length
    end
    return bytes:sub(1,#bytes-size),records
end

-- Game bytes and records -> block bytes; no records, no tail.
function M.join(game,records)
    if next(records)==nil then return game end
    local body=M.list(records)
    return game..body..string.pack('<I4',#body+8)..FOOTER
end

-- The data of the map record -> records.
function M.read_list(body) return M.split(body..string.pack('<I4',#body+8)..FOOTER) end

return M
