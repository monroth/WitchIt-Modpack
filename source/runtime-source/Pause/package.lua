-- Pause, for the host only (guests need nothing; the game replicates the effect): the host stops
-- and resumes the round timer of any match (a key and the in-game menu), and, if the host wants it,
-- the timer stops by itself when the game tells a player left. Its settings are in Mods.
return function(R,C,U)
    local CORE='/Game/Blueprints/Core/'
    local function hosting(s) return s.role=='host' and s.mode~='vanilla' and s.mode~='creative' and s.mode~='none' end

    -- The host's settings.
    local settings=R.settings('Pause',{autoPause=false})
    R.options(function(rows,U)
        return {(U.checkbox(rows,{label='Pause when a player leaves',value=settings.autoPause,
            tooltip='The round timer stops when a player leaves a match you host. Resume it with the pause key or the in-game menu.',
            on_change=function(v) settings.autoPause=v;R.save_settings('Pause') end}))}
    end)

    -- Pause: the round timer stops until the host resumes it, also across the next round's start.
    local paused,counting=false,nil
    local function pause()
        local s=C.session()
        if not hosting(s) then return end
        if not paused then counting=s.gm.TimerIsCounting end
        paused=not paused;s.gm.TimerIsCounting=not paused and counting~=false
        local message=FText(paused and 'Round timer paused' or 'Round timer resumed')
        s.gs:SendGameMessageMulticast(message,message,10)
    end
    R.key('pause.timer','F8',pause,{label='Pause timer',tip='Pause or resume the round timer',context='A match you host'})
    U.menu_entry('/Game/UserInterface/WB_IngameMenu.WB_IngameMenu_C','Settings','Pause timer',pause,nil,
        function() return hosting(C.session()) end,function() return paused and 'Resume timer' or 'Pause timer' end)
    -- While paused, what the game asks of its timer is what it gets on resume (audit 11-20: the value
    -- taken at the pause came back over a start or stop made meanwhile - a round start, Fill a Pot+).
    C.scoped(hosting).post(CORE..'B_GameMode.B_GameMode_C:TimerStart',function(gm)
        if paused then counting=true;gm.TimerIsCounting=false end
    end)
    C.scoped(hosting).post(CORE..'B_GameMode.B_GameMode_C:TimerStop',function()
        if paused then counting=false end
    end)
    -- The game tells a player left (its logout): with the option on, the timer stops.
    C.scoped(hosting).on('player_left',function()
        if settings.autoPause and not paused then pause() end
    end)
    R.on('world_end',function() paused,counting=false,nil end)
    -- (a session that is no longer one the host pauses lets go of the pause: audit 11-20, it stayed on with
    -- no key or menu left to resume it)
    C.on_session(function(s) if paused and not hosting(s) then paused,counting=false,nil end end)
end
