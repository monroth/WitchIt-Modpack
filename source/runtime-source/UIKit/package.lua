return function(R, C)
    local U, I = {}, {actions = {}, screens = {}, resets = {}, destructors = {}}
    -- (shared by the kit's files and WindowKit: the game's key picture, the room above a heading)
    I.KEY_ICON = '/Game/UserInterface/ControllerIcons/WB_ControllerIcon.WB_ControllerIcon_C'
    I.HEADING_GAP = 10
    local directory = debug.getinfo(1, 'S').source:match('^@(.+[\\/])')
    I.elements = '/Game/UserInterface/UIElements/'
    I.play = '/Game/UserInterface/Play/'
    I.managers = '/Game/Blueprints/UserInterface/'
    function I.path(asset, event, folder)
        return (folder or I.elements)..asset..'.'..asset..'_C:'..event
    end
    function I.id(widget) return widget:GetAddress() end
    function I.object(path) return StaticFindObject(path) end
    I.string, I.values = R.text, R.values
    function I.array(array, values)
        array:Empty()
        for index, value in ipairs(values) do array[index] = value end
    end
    -- A screen's state goes with its actions.
    local function drop(id, state)
        for address in pairs(state.actions) do I.actions[address] = nil end
        I.screens[id] = nil
    end
    -- A screen's state, by its address; one left at that address by a screen gone since (without its
    -- Destruct reaching us) is another screen's: a new state.
    function I.state(screen)
        local id = I.id(screen)
        local state = I.screens[id]
        if state and not R.valid(state.screen) then drop(id, state); state = nil end
        if not state then state = {screen = screen, actions = {}, menus = {}, tabs = {}}; I.screens[id] = state end
        return state
    end
    function I.forget(screen)
        local id = I.id(screen)
        local state = I.screens[id]
        if state then
            for _, cleanup in ipairs(I.destructors) do cleanup(state) end
            drop(id, state)
        end
    end
    for _, module in ipairs({'actions', 'widgets', 'mouse', 'fields', 'dialogs', 'navigation', 'screens', 'browser', 'keybindings', 'labels', 'maplist', 'rules', 'colour'}) do
        dofile(directory..module..'.lua')(R, C, U, I)
    end
    -- The building blocks of UIKit's controls (owner screens, game widgets, actions, removal), for
    -- kits that make controls of their own on top of it (WindowKit).
    U.parts = I
    R.post('/Script/UMG.UserWidget:Destruct', function(screen)
        I.forget(screen)
    end)
    R.on('world_end', function()
        -- Menu screens are cached across worlds and keep the widgets added to them, so
        -- their state stays; adding again would duplicate rows. Screens that died with
        -- the world are forgotten without touching their (possibly gone) children.
        for id, state in pairs(I.screens) do
            if not R.valid(state.screen) then drop(id, state) end
        end
        for _, reset in ipairs(I.resets) do reset() end
    end)
    C.on_session(function(session)
        if not (session.gi and session.pc) then return end
        local message=C.mods.take_message()
        if message then R.next_frame(function() U.message('Modpack mismatch',message) end) end
    end)
    R.native.on_save(function(event)
        if event.complete and event.success==false and C.session().pc then
            R.next_frame(function() U.message('Save failed','The game could not finish saving the layout. Check the saved layout before continuing.') end)
        end
    end)
    return U
end
