-- Rule documents: a game mode, its native rules, and extra rules per mod.
--   {format='MatchRulesPlusPlus', version=2, mode=<GameMode class path>,
--    native={match={{id=,values={}}}, skills=…, mods=…, powerups=…},
--    extras={<package id>={…}, …}}   (every mod's rules section: Core's rules, this mod's too)
-- Documents from files, codes and other players are reduced to this shape once, by clean().
return function(R,schema,crc32)
    local D={}
    local FORMAT='MatchRulesPlusPlus'
    local index={}
    -- A group of the game's rules (also an ability a mod registered: a skill type of its own).
    function D.add_group(group)
        index[group.category]=index[group.category] or {}
        index[group.category][group.id]=group
        group.byName,group.byNativeName={},{}
        for _,row in ipairs(group.rows) do
            group.byName[row.name],group.byNativeName[row.name:lower()]=row,row
        end
    end
    for _,group in ipairs(schema.groups) do D.add_group(group) end
    D.index=index

    function D.clone(value)
        if type(value)~='table' then return value end
        local out={}
        for key,item in pairs(value) do out[key]=D.clone(item) end
        return out
    end
    local values=R.values
    local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
    function D.checked(value,row)
        if row.kind=='bool' then
            assert(type(value)=='boolean','Expected a checkbox value: '..row.name)
        else
            assert(finite(value),'Expected a number: '..row.name)
            assert(row.kind~='int' or value==math.floor(value),'Expected a whole number: '..row.name)
        end
        return value
    end
    -- A mod's section is kept as given (names with plain values); Core checks each rule's value
    -- when it takes the section.
    local function cleanExtras(source)
        assert(type(source)=='table','Invalid extra rules')
        local out={}
        for key,value in pairs(source) do
            assert(type(key)=='string' and #key<=128,'Invalid extra rule name')
            assert(type(value)=='boolean' or finite(value) or type(value)=='string' and #value<=256,'Invalid extra rule value')
            out[key]=value
        end
        return out
    end
    function D.clean(p)
        assert(type(p)=='table' and p.format==FORMAT,'Unsupported preset version')
        -- Version 1 kept native rules in `collections` and only this mod's extras.
        if p.version==1 then p={format=FORMAT,version=2,mode=p.mode,native=p.collections,extras={MatchRulesPlusPlus=p.extras}} end
        assert(p.version==2,'Unsupported preset version')
        assert(type(p.mode)=='string' and #p.mode>0 and #p.mode<512,'Missing game mode')
        assert(type(p.native)=='table' and type(p.extras)=='table','Incomplete preset')
        local out={format=FORMAT,version=2,mode=p.mode,native={},extras={}}
        for category in pairs(p.native) do assert(schema.collections[category],'Unknown rule collection') end
        for category in pairs(schema.collections) do
            local rows,seen=p.native[category],{}
            assert(type(rows)=='table' and #rows<=32,'Invalid rule collection')
            local count=0
            for key in pairs(rows) do
                count=count+1
                assert(type(key)=='number' and key%1==0 and key>=1 and key<=#rows,'Invalid rule list')
            end
            assert(count==#rows,'Incomplete rule list')
            out.native[category]={}
            for _,entry in ipairs(rows) do
                local group=index[category][entry.id]
                assert(group and not seen[entry.id],'Unknown or repeated rule group')
                assert(type(entry.values)=='table','Missing rule values')
                seen[entry.id]=true
                local row={id=entry.id,values={}}
                for name,value in pairs(entry.values) do
                    row.values[name]=D.checked(value,assert(group.byName[name],'Unknown rule property'))
                end
                out.native[category][#out.native[category]+1]=row
            end
            table.sort(out.native[category],function(a,b) return a.id<b.id end)
        end
        for id,section in pairs(p.extras) do
            assert(type(id)=='string' and #id<=64,'Invalid extra rules')
            out.extras[id]=cleanExtras(section)
        end
        return out
    end
    -- What differs from a to b, by the page it is on: {{title, rows = {{label, from, to}}}} in the
    -- pages' order (no value: the game's own, shown as "default"). A mod's rule shown on a game page
    -- (page 'skill:<type>', 'powerup:<type>', 'general', ...) is listed with that page; a mod's own
    -- rules under the mod's name. label(name): a game name for players; name(id): a mod's name;
    -- specs(id): its rules (Core's).
    local PAGES={general={'match',1},hunters={'match',2},witches={'match',3}}
    function D.diff(a,b,label,name,specs)
        local sections,byKey={},{}
        local function section(key,title)
            if not byKey[key] then byKey[key]={title=title,rows={}};sections[#sections+1]=byKey[key] end
            return byKey[key]
        end
        local function value(doc,category,id,row)
            for _,entry in ipairs(doc.native[category] or {}) do if entry.id==id then return entry.values[row] end end
        end
        local function show(v)
            if v==nil then return 'default' end
            if type(v)=='number' then return (string.format('%.2f',v):gsub('0+$',''):gsub('%.$','')) end
            if type(v)=='boolean' then return v and 'on' or 'off' end
            return tostring(v)
        end
        local function title(group) return group.label or label(group.property) end
        for _,group in ipairs(schema.groups) do
            for _,row in ipairs(group.rows) do
                local x,y=value(a,group.category,group.id,row.name),value(b,group.category,group.id,row.name)
                if x~=y then
                    local s=section(group.category..':'..group.id,title(group))
                    s.rows[#s.rows+1]={label=label(row.name),from=show(x),to=show(y)}
                end
            end
        end
        local ids={}
        for id in pairs(a.extras) do ids[#ids+1]=id end
        for id in pairs(b.extras) do if not a.extras[id] then ids[#ids+1]=id end end
        table.sort(ids)
        for _,id in ipairs(ids) do
            local mine,theirs=a.extras[id] or {},b.extras[id] or {}
            for _,spec in ipairs(specs(id)) do
                if mine[spec.key]~=theirs[spec.key] then
                    local kind,number=tostring(spec.page):match('^(%a+):(%d+)$')
                    local where=PAGES[spec.page] or kind and {kind=='skill' and 'skills' or 'powerups',tonumber(number)}
                    local group=where and D.index[where[1]] and D.index[where[1]][where[2]]
                    local s=group and section(group.category..':'..group.id,title(group)) or section('mod:'..id,name(id))
                    s.rows[#s.rows+1]={label=spec.label,from=show(mine[spec.key]),to=show(theirs[spec.key])}
                end
            end
        end
        return sections
    end

    -- Portable codes: MRPP2:<base64 of the JSON document>:<crc32>.
    local function crc(bytes) return string.format('%08x',crc32(bytes)) end
    D.LIMIT=36864
    function D.encode(doc)
        local bytes=R.json.encode(D.clean(doc))
        assert(#bytes<=D.LIMIT,'Preset exceeds 36 KiB')
        return 'MRPP2:'..R.base64.encode(bytes)..':'..crc(bytes)
    end
    function D.decode(code)
        assert(type(code)=='string' and #code<=49168,'Rules code exceeds size limit')
        code=code:match('^%s*(.-)%s*$')
        local bytes,sum=code:match('^MRPP[12]:([^:]+):(%x%x%x%x%x%x%x%x)$')
        assert(bytes,'Unsupported or corrupt rules code')
        local ok,raw=pcall(R.base64.decode,bytes)
        assert(ok,'Corrupt rules code')
        bytes=raw
        assert(#bytes<=D.LIMIT and crc(bytes)==sum:lower(),'Corrupt code: checksum mismatch')
        -- Native values can sit outside the sliders: fields take typed numbers, and saved
        -- rules files hold them. Types and extra rules are still checked.
        return D.clean(R.json.decode(bytes))
    end

    -- Native rule records. read() is the one place that turns them into document rows.
    local function kindField(kind) return kind=='bool' and 'BoolValue' or kind=='int' and 'IntValue' or 'FloatValue' end
    function D.read(rules,category)
        local def=schema.collections[category]
        local rows={}
        for _,record in ipairs(values(rules[def.field])) do
            local group=index[category][record[def.type]]
            -- (a skill type of a mod not installed here stays out)
            if group then
                local entry={id=group.id,values={}}
                for _,param in ipairs(values(record[def.params])) do
                    local row=group.byNativeName[param.Name:ToString():lower()]
                    if row then entry.values[row.name]=param[kindField(row.kind)] end
                end
                rows[#rows+1]=entry
            end
        end
        return rows
    end
    local function spawnRules(outer)
        return StaticFindObject('/Script/Engine.Default__GameplayStatics'):SpawnObject(
            StaticFindObject('/Game/Blueprints/Match/GameRules/B_GameRules.B_GameRules_C'),outer)
    end
    function D.nativeRules(outer)
        local rules=spawnRules(outer)
        rules:ResetAll()
        return rules
    end
    -- Build a native B_GameRules object holding the document's native rules.
    function D.materialize(doc,outer)
        local buffer=D.nativeRules(outer)
        for category,def in pairs(schema.collections) do
            local array=buffer[def.field]
            -- (rules kept of an ability no mod here registers any more - its mod removed - are not this game's:
            -- left out; live VM2 11-21, Nitro Hook's rules kept, ExampleMod taken away, choosing a mode stopped the mod)
            local rows={}
            for _,row in ipairs(doc.native[category]) do
                if index[category][row.id] then rows[#rows+1]=row
                else R.log('MatchRulesPlusPlus','Kept rules of %s %s left out: no mod here has it',category,tostring(row.id)) end
            end
            for i,row in ipairs(rows) do
                array[i]=nil
                local record=array[i]
                record[def.type]=row.id
                local params,keys=record[def.params],{}
                for name in pairs(row.values) do keys[#keys+1]=name end
                table.sort(keys)
                for j,name in ipairs(keys) do
                    params[j]=nil
                    local param=params[j]
                    param.Name=FName(name)
                    param.FloatValue,param.IntValue,param.BoolValue=0,0,false
                    param[kindField(index[category][row.id].byName[name].kind)]=row.values[name]
                end
            end
        end
        -- Skills, modifiers and powerups are registered through their native setters.
        local result=D.nativeRules(outer)
        result.MatchRules=buffer.MatchRules
        for _,category in ipairs({'skills','mods','powerups'}) do
            local def=schema.collections[category]
            for _,record in ipairs(values(buffer[def.field])) do result[def.setter](result,record) end
        end
        return result
    end
    return D
end
