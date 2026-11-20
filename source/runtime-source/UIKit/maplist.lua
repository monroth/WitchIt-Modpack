-- The Custom Maps tab's own controls: a search over the maps' names and file names, and a box
-- that shows incompatible maps too, dimmed and still selectable; in Creative (every map opens) a
-- choice of the kind of maps instead: all, normal, or a mode's (C.catalog.view; Core narrows the list).
return function(R, C, U, I)
    local list = '/Game/UserInterface/Maps/WB_MapList.WB_MapList_C'
    local view = C.catalog.view
    local function narrow(w) if R.valid(w) then C.catalog.narrow(w) end end
    -- The game's small checkbox (the autosave box's class) tells its changes through its box's event.
    local small = '/Game/UserInterface/UIElements/WB_CheckBoxWithLabelSmall.WB_CheckBoxWithLabelSmall_C'
    local boxes = {}   -- widget address -> on_change(checked)
    R.post(small..':BndEvt__WB_CheckBoxWithLabelSmall_CheckBox_223_K2Node_ComponentBoundEvent_1_OnCheckBoxComponentStateChanged__DelegateSignature',
        function(box) local fn = boxes[I.id(box)]; if fn then fn(box.MyCheckBox:IsChecked()) end end)
    -- A row of their own above the maps, only on the Custom Maps tab: the search field taking the
    -- width, the box after it. The maps and what follows them move down (re-added in order with
    -- their slots: a vertical box only appends).
    local rows = {}   -- map list address -> {row, box, kinds}
    local function show(w)
        local own = rows[I.id(w)]
        if not own or not R.valid(own.row) then return end
        own.row:SetVisibility(w.CurrentMapCategory == 1 and 0 or 1)
        local creative = C.catalog.creative(w)
        own.box:SetVisibility(creative and 1 or 0)
        own.kinds:SetVisibility(creative and 0 or 1)
    end
    R.post(list..':Construct', function(w)
        local state = I.state(w)
        if state.maplist then return end
        state.maplist = true
        local maps = w.MapListTileView:GetParent()
        local column = maps:GetParent()
        local row = I.native(column, 'HorizontalBox')
        local after = I.move_after(maps, nil, row, true)
        local game = w.CheckBoxAutoSave
        row.Slot:SetPadding(after[1].slot.padding)
        local _, _, frame = U.input(row, {hint = 'Search maps', value = view.search, on_change = function(text)
            view.search = text; narrow(w)
        end})
        U.fill(frame); frame.Slot:SetVerticalAlignment(2)
        local box = I.cooked(row, nil, game:GetClass())
        box.LabelText = FText('Show incompatible maps')
        box.MyCheckBox:SetIsChecked(view.all)
        boxes[I.id(box)] = function(on) view.all = on; narrow(w) end
        box.Slot:SetPadding({Left = 24, Top = 0, Right = 0, Bottom = 0}); box.Slot:SetVerticalAlignment(2)
        local choices = {{value = 'all', label = 'All maps'}}
        for _, genre in ipairs(C.catalog.genres()) do choices[#choices + 1] = genre end
        -- (no label: the choice itself fills the fixed width, wide enough for its longest option)
        local kinds = I.native(row, 'SizeBox')
        kinds:SetWidthOverride(330)
        kinds.Slot:SetPadding({Left = 24, Top = 0, Right = 0, Bottom = 0}); kinds.Slot:SetVerticalAlignment(2)
        U.combo(kinds, {options = choices, value = view.genre or 'all', on_change = function(value)
            view.genre = value ~= 'all' and value or nil; narrow(w)
        end})
        rows[I.id(w)] = {row = row, box = box, kinds = kinds}
        show(w)
    end)
    -- The game shows which tab is chosen here (opening the list and each tab change); so does the row.
    R.post(list..':UpdateTabVisualsBySelection', show)
    -- A map the chosen mode cannot play, shown with the box ticked.
    for _, asset in ipairs({'WB_MapButton', 'WB_MapListButton'}) do
        R.post('/Game/UserInterface/Maps/'..asset..'.'..asset..'_C:SetIndividualParameters', function(tile)
            tile:SetRenderOpacity(C.catalog.dimmed(tile.ItemData) and .45 or 1)
        end)
    end
end
