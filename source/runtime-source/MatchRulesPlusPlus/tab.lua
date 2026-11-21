-- The Match Rules ++ tab in Game Rules: rules between players, as codes and offers (the extra
-- rules themselves are on the game's own pages: placed.lua). A guest sees the match's rules (as they are) or their own rules (which
-- they edit, keep between launches, and may offer to the host); the host sees the offers.
return function(M)
    local R,C,U,D=M.R,M.C,M.U,M.doc
    local settings=M.settings
    -- settings.guestRules: a guest's own rules of the game (their mods' rules are Core's rules in
    -- "My rules"). They reach the match only when the host accepts them.
    M.view=M.view or 'match'
    local function guest() return C.guest() end
    local function setView(which)
        M.view=which
        C.rules.mine(guest() and which=='mine')
    end
    setView(M.view)
    -- The rules shown, every mod's included: a guest's view, or the host's own.
    local function rules()
        local doc
        if guest() then doc=D.clone(M.view=='mine' and settings.guestRules or M.capture())
        else doc=D.clean(M.capture(true)) end
        doc=doc or D.clean(M.capture())
        doc.extras=C.saved_rules.collect()
        return doc
    end
    -- A guest's own rules of the game, made on their first change.
    function M.guestEdited()
        settings.guestRules=settings.guestRules or D.clean(M.capture())
        return settings.guestRules
    end
    -- A guest changes the mods' rule tabs only while looking at rules of their own.
    local tab=U.rules_tab(M.TABS,function(parent,scroll)
        local _,status=U.text(parent,{text=''})
        local refresh
        local controls={}
        -- A guest's view: the match's rules or their own.
        local view,paintView=U.combo(parent,{label='Show',options={{label='Match rules',value='match'},{label='My rules',value='mine'}},
            value=M.view,on_change=function(value) setView(value);refresh() end})
        controls[#controls+1]=view
        controls[#controls+1]=U.button(parent,{label='Export rules as code',on_click=function()
            R.log(M.PKG,'Exporting the rules as a code');R.native.clipboard_set(D.encode(rules()));status('Rules code copied.')
        end})
        controls[#controls+1]=U.button(parent,{label='Import rules from code',on_click=function()
            -- The native read fails when the clipboard holds no text.
            local read,code=pcall(R.native.clipboard_get)
            if not read then R.log(M.PKG,'Import: the clipboard holds no text');U.message('Import rules','Copy a rules code first.');return end
            local ok,doc=pcall(D.decode,code)
            if not ok then R.log(M.PKG,'Import refused: %s',M.problem(doc));U.message('Import rules',M.problem(doc));return end
            R.log(M.PKG,'Importing rules from a code (%s)',guest() and 'into my rules' or 'for the next match')
            if guest() then
                settings.guestRules=doc;M.persist();setView('mine')
                C.saved_rules.load(doc.extras)
                status('Rules imported into your rules.')
            elseif M.stage(doc) then
                C.saved_rules.load(doc.extras)
                status('Rules selected for the next match.')
            end
            refresh()
        end})
        local copy=U.button(parent,{label='Copy the match rules to my rules',on_click=function()
            setView('match')
            local match=C.saved_rules.collect()
            settings.guestRules=D.clean(M.capture());M.persist();setView('mine')
            C.saved_rules.load(match)
            status('Your rules are now the match rules.');refresh()
        end})
        local offer=U.button(parent,{label='Offer my rules to the host',on_click=function()
            local doc=D.clone(M.guestEdited());doc.extras=C.saved_rules.collect()
            R.log(M.PKG,'Offering my rules to the host')
            M.offer(doc);status('Your rules were offered to the host.')
        end})
        controls[#controls+1]=copy;controls[#controls+1]=offer
        -- The host: the players' offers, the first first.
        local offers=U.section(parent,{})
        U.navigate(controls,scroll)
        local function showOffers()
            offers:ClearChildren()
            if guest() then return end
            for i,o in ipairs(M.offers) do
                U.text(offers,{text=o.name..' offers rules'})
                local row=U.flow(offers)
                U.button(row,{label='Accept',on_click=function()
                    if M.accept(i) then status('Rules of '..o.name..' accepted.') end;refresh()
                end})
                U.button(row,{label=o.open and 'Hide' or 'View',on_click=function() o.open=not o.open;refresh() end})
                U.button(row,{label='Reject',on_click=function() table.remove(M.offers,i);refresh() end})
                -- What the offer changes, by page, in the tab (it scrolls with it): offered value, now.
                if o.open then
                    local sections=D.diff(rules(),o.doc,M.label,R.mod_name,C.rules.specs)
                    if #sections==0 then U.text(offers,{text='The same as yours.'}) end
                    for _,section in ipairs(sections) do
                        U.text(offers,{text=section.title,heading=true})
                        for _,r in ipairs(section.rows) do U.text(offers,{text=r.label..':  '..r.to..'   (now '..r.from..')'}) end
                    end
                end
            end
        end
        -- The screen can outlive a session, so the tab reads the role each time it opens.
        refresh=function()
            local g=guest()
            for _,widget in ipairs({view,copy,offer}) do widget:SetVisibility(g and 0 or 1) end
            paintView(M.view)
            showOffers()
        end
        M.refreshTab=refresh
        return refresh
    end,{guest=true})
    -- Custom Match and the host's in-game menu have a native Match Rules + button (AdvancedOptions),
    -- which opens this tab's screen. Only Creative's menu needs a row.
    local function open(origin) U.open_rules(origin,tab) end
    U.menu_entry('/Game/UserInterface/CreativeMode/WB_CreativeIngameMenu.WB_CreativeIngameMenu_C','Settings','Match Rules +',open,'LayoutEditor')
    -- The game shows its button to the host of a Tweakable match only; a guest of such a match
    -- reaches the rules from its own row. The flag lives on the server, so the host publishes it.
    U.menu_entry('/Game/UserInterface/WB_IngameMenu.WB_IngameMenu_C','Settings','Match Rules +',open,nil,
        function() return guest() and M.hostView~=nil and M.hostView.live end)
    R.key('mrpp.rules','F7',function() U.open_rules(nil,tab) end,
        {label='Rules tab',tip='Open the rules tab',context='Custom Match, lobby, Creative'})
end
