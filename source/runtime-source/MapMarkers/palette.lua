-- The marker kinds in Creative's Utility palette (category 6), after the game's own blocks: each
-- shows as its carrier block under its kind's title, description and icon. Picking one marks the
-- blocks about to be placed; picking anything else takes the mark off them. A placed marker keeps
-- its kind through the game's prefab colour (copy and paste, saved prefabs): X 70, Y 65, Z 256 + code.
return function(R,C,M)
    local aliases,list={},{}   -- palette item -> kind; kinds in code order
    local function ordered()
        list={}
        for code=1,64 do local def=M.kindByCode(code);if def then list[#list+1]=def end end
        return list
    end
    M.onEditor.post(M.path(M.CR,'WB_PropCollectionWidgetCreative','GetStructureTileViewDatas'),function(w,out,focus)
        if w.SelectedPropCategory~=6 then return end
        aliases={}
        C.state('MapMarkers','Marker palette',#ordered()..' marker kinds in the Utility category')
        local items,flags=M.values(out:get()),M.values(focus:get())
        -- (each as the palette filters its own: the search text in the kind's title, "only switchable")
        local search=w.SearchBar.TextField:GetText():ToString():lower()
        for _,def in ipairs(ordered()) do
            local class=M.asset(def.carriers[1])
            local category={};w:IsPropOrStructureInCategory(class,category)
            if category.IsInCategory and def.title:lower():find(search,1,true) then
                local result={}
                w.TileViewManager:GetPropButtonData(0,true,false,class,w,{},result)
                local data=result.Data
                aliases[data:GetFullName()]=def;items[#items+1]=data;flags[#flags+1]=false
            end
        end
        w.CurrentCategoryPropsCount=w.CurrentCategoryPropsCount+#list;out:set(items);focus:set(flags)
    end)
    M.onEditor.post('/Game/UserInterface/UIElements/WB_SearchBar.WB_SearchBar_C:GetItemName',function(_,item,out)
        if not R.valid(item) then return end
        local def=aliases[item:GetFullName()];if def then out:set(def.title) end
    end)
    M.onEditor.post('/Game/UserInterface/PropCollection/B_PropButtonData.B_PropButtonData_C:Compare',function(item,other,out)
        if not R.valid(other) then return end
        local a,b=aliases[item:GetFullName()],aliases[other:GetFullName()]
        if a or b then out:set(a~=nil and a==b) end
    end)
    -- The block's picture in its tooltip is the carrier's (set as the tooltip is built): the kind's
    -- icon instead, as in the palette.
    local tooltips={}
    R.on('world_end',function() tooltips={} end)
    M.onEditor.post('/Game/UserInterface/PropCollection/WB_StructureTooltip.WB_StructureTooltip_C:Construct',function(tooltip)
        local def=tooltips[tooltip:GetAddress()]
        if not def then return end
        M.icon(tooltip.StructureImage,def)
    end)
    M.onEditor.post('/Game/UserInterface/PropCollection/WB_PropButton.WB_PropButton_C:GetTooltip',function(w,out)
        local def=aliases[w.ItemData:GetFullName()]
        local tooltip=out:get()
        if def and R.valid(tooltip) then
            tooltip.Name:SetText(FText(def.title))
            tooltip.Description:SetText(FText(def.description))
            tooltips[tooltip:GetAddress()]=def
        end
    end)
    local function paletteIcon(tile)
        local def=aliases[tile.ItemData:GetFullName()]
        if not def then return end
        M.icon(tile.GridButton.Icon,def)
    end
    M.onEditor.post('/Game/UserInterface/UIElements/MenuTileView/WB_TileViewButton.WB_TileViewButton_C:SetButtonParameters',function(tile)
        if R.valid(tile.ItemData) then paletteIcon(tile) end
    end)
    M.onEditor.post('/Game/UserInterface/UIElements/WB_GridButton.WB_GridButton_C:SetIconImage',function(grid)
        local tree=grid:GetOuter()
        if not tree:IsA('/Script/UMG.WidgetTree') then return end
        local tile=tree:GetOuter()
        if tile:IsA('/Game/UserInterface/UIElements/MenuTileView/WB_TileViewButton.WB_TileViewButton_C') and R.valid(tile.ItemData) then paletteIcon(tile) end
    end)
    -- A marker of def as placed: its defaults, then what the kind fills in that it lacks.
    local function placed(def,info)
        info=def.defaults(info or {kind=def.name,authored=true})
        if def.created then def.created(info) end
        return info
    end
    M.onEditorHost.post('/Game/UserInterface/PropCollection/WB_PropButton.WB_PropButton_C:Clicked',function(w)
        local picked=aliases[w.ItemData:GetFullName()]
        R.log('MapMarkers','Palette block picked: %s',picked and 'marker '..tostring(picked.title) or 'an ordinary block')
        for _,actor in ipairs(M.values(w:GetOwningPlayer().ActorsToPlace)) do
            if picked then
                local info=placed(picked)
                M.stamp(actor,info);M.look(actor,info)
            else
                local info,def=M.marker(actor)
                if info then
                    M.unstamp(actor,def);M.unlook(actor)
                    if def.cleared then def.cleared(actor) end
                end
            end
        end
    end)
    M.onEditor.post(M.path(M.CR,'B_CreativePlayerController','GetPrefabInfo'),function(_,actor,_,_,_,_,_,colour)
        if not R.valid(actor) then return end
        local _,def=M.marker(actor)
        if def and def.code then colour:set({X=70,Y=65,Z=256+def.code}) end
    end)
    M.onEditorHost.post(M.path(M.CR,'B_CreativePlayerController','PlaceActor'),function(pc,class,_,_,_,_,_,_,colour,indices,out)
        local actor=out:get()
        if not R.valid(actor) then return end
        local info,def=M.marker(actor)
        if not def and colour.X==70 and colour.Y==65 then def=M.kindByCode(colour.Z-256) end
        if def and M.carries(def,actor) then
            R.log('MapMarkers','Marker placed: %s',tostring(def.title))
            info=placed(def,info)
            M.stamp(actor,info);M.look(actor,info)
        else info=nil end
        M.changed(actor,info)
    end)
    R.on('world_end',function() aliases={} end)
end
