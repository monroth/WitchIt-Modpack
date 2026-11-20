-- The game's rules pages light the tile of each skill, power-up and modifier with rules of its
-- own. The game asks the rules in force; the tiles here follow the rules the screens show: a
-- guest's own rules ("My rules") lit where they differ from the host's, any other view where they
-- differ from the game's (the game's own answer), the mods' rules on that page included.
return function(M)
    local R,C=M.R,M.C
    local hooks,settings=M.hooks,M.settings
    local UI='/Game/UserInterface/GameRules/'
    local function same(a,b) return a.R==b.R and a.G==b.G and a.B==b.B and a.A==b.A end
    -- Does a mod's rule on this page differ from what it is compared with?
    local function modRules(page,against)
        for _,pkg in ipairs(C.rules.packages()) do
            for _,spec in ipairs(C.rules.specs(pkg)) do
                if spec.page==page and C.rules.shown(pkg,spec.key)~=against(pkg,spec) then return true end
            end
        end
        return false
    end
    -- A guest's own value differs from the host's in force.
    local function guestDiffers(category,id)
        local doc,host=settings.guestRules,M.hostView and M.hostView.document.effective[category..':'..id]
        for _,entry in ipairs(doc and doc.native[category] or {}) do
            if entry.id==id then
                for name,value in pairs(entry.values) do if not host or host[name]~=value then return true end end
            end
        end
        return false
    end
    for _,tile in ipairs({{'WB_SkillTileButton','SkillType','skills','skill'},{'WB_PowerupTileButton','Powerup','powerups','powerup'},
        {'WB_ModTileButton','Modifier','mods',nil}}) do
        local name,field,category,kind=tile[1],tile[2],tile[3],tile[4]
        hooks.post(UI..name..'.'..name..'_C:GetBorderColor',function(button,color)
            local id=button[field]
            local page=kind and kind..':'..tostring(id)
            local lit
            if C.session().role=='client' and M.view=='mine' then
                lit=guestDiffers(category,id) or page~=nil and modRules(page,function(pkg,spec) return C.rules.get(pkg,spec.key) end)
            else
                lit=same(color:get(),button.ActiveRuleColor) or page~=nil and modRules(page,function(_,spec) return spec.initial end)
            end
            color:set(lit and button.ActiveRuleColor or button.NoRuleActiveColor)
        end)
    end
end
