-- Rules between players: guests see the game's rules in force (the mods' own rules reach them
-- through Core's rules).
return function(M)
    local R,C,D=M.R,M.C,M.doc

    function M.publishView()
        local s=C.session()
        if s.role~='host' then return end
        C.net.publish('mrpp.rules',{document=M.capture(),live=s.gm.IsLiveRuleEditingAllowed==true})
    end
    C.net.watch('mrpp.rules',function(value)
        if not C.mods.host_mode() then return end   -- (a guest's only: known from joining, not the session's role)
        local ok,result=pcall(function()
            assert(type(value)=='table','Invalid host rules')
            local doc=D.clean(value.document)
            doc.effective={}
            -- (the groups the host has: an ability whose mod is not here stays out)
            assert(type(value.document.effective)=='table','Missing current host rules')
            for key,source in pairs(value.document.effective) do
                local category,id=tostring(key):match('^(%a+):(%d+)$')
                local group=category and D.index[category] and D.index[category][tonumber(id)]
                if group then
                    local effective={}
                    for _,row in ipairs(group.rows) do effective[row.name]=D.checked(source[row.name],row) end
                    doc.effective[key]=effective
                end
            end
            return {document=doc,live=value.live==true}
        end)
        if not ok then R.log(M.PKG,'Host rules unreadable: %s',tostring(result));return end
        C.state(M.PKG,'Host rules',('received (live editing %s)'):format(tostring(result.live)))
        M.hostView=result
    end)
    R.on('world_end',function() M.hostView=nil end)

    -- Offers: a guest offers their own rules to the host, who accepts, views or rejects each.
    -- One offer a player: a new one replaces theirs and goes to the end of the queue.
    M.offers={}
    function M.offer(doc) C.net.request('mrpp.offer',{document=D.clean(doc)}) end
    C.net.on_request('mrpp.offer',function(ps,value)
        local ok,doc=pcall(D.clean,type(value)=='table' and value.document)
        if not ok then R.log(M.PKG,'Ignored an offer: %s',tostring(doc));return end
        local key,name=ps:GetAddress(),R.text(ps:GetPlayerName())
        for i,o in ipairs(M.offers) do if o.key==key then table.remove(M.offers,i);break end end
        R.log(M.PKG,'Rules offered by %s',name)
        M.offers[#M.offers+1]={key=key,name=name,doc=doc}
        M.U.error_line(name..' offers rules: see the Match Rules ++ tab',8,{R=.6,G=.85,B=1,A=1})
        if M.refreshTab then M.refreshTab() end
    end)
    -- The host takes an offer: for the next match, or at once where rules change live.
    function M.accept(i)
        local o=M.offers[i]
        R.log(M.PKG,'Accepting the rules offered by %s',o and o.name or '?')
        if not (o and M.stage(o.doc)) then R.log(M.PKG,'Offer not accepted: the rules could not be staged');return false end
        if C.session().mode~='vanilla' then C.saved_rules.load(o.doc.extras) end
        if M.live() then M.refreshEffects();M.publishView() end
        table.remove(M.offers,i)
        return true
    end
    R.on('world_end',function() M.offers={} end)

    M.hooks.on('match_start',function()
        if C.session().role~='host' then return end
        M.refreshEffects()
        M.publishView()
    end)
    M.hooks.on('round_start',M.publishView)
    M.hooks.session(function(s)
        if s.role=='host' and R.valid(s.gi) and R.valid(s.gs) and s.gs:IsA(StaticFindObject(M.CORE..'B_GameState.B_GameState_C')) then
            M.publishView()
        end
    end)
end
