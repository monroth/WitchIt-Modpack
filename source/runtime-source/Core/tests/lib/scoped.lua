-- Core's real scopes (Core/scope.lua) over a test's own R and C.session.
return function(R,C)
    C.saved_rules={register=function() end,collect=function() return {} end,load=function() end}
    R.on=R.on or function() end
    R.valid=R.valid or function(v) return v end
    R.find_all=R.find_all or function() return {} end
    -- (as Core's C.options: the match's options in a match, else the menu's next)
    C.options=C.options or function(s) local gi=(s or C.session()).gi;return gi and (gi.IsCurrentlyInMatch and gi.UsedMatchOptions or gi.NextMatchOptions) or nil end
    -- (as Core's C.owns / C.guest: the machine that runs the match, and a guest)
    C.owns=C.owns or function(s) return (s or C.session()).role~='client' end
    C.guest=C.guest or function(s) return (s or C.session()).role=='client' end
    C.on_session=C.on_session or function() end
    -- (as Core's C.session_of: a test's mods all at its host)
    C.session_of=C.session_of or function() return C.session() end
    -- The runtime's mod facts as a test sees them: the calling mod is the test's (R.test_owner).
    R.manifests=R.manifests or {}
    R.owner=R.owner or function() return R.test_owner or 'Test' end
    R.mod_name=R.mod_name or function(id) local m=R.manifests[id];return m and m.name or id end
    R.options=R.options or function() end
    C.mods=C.mods or {}
    C.mods.require=C.mods.require or function() end
    C.mods.forced=C.mods.forced or function() return false end
    -- (as Core's: a test's guest is a client session)
    C.mods.host_mode=C.mods.host_mode or function() return C.session().role=='client' and 'test' or nil end
    C.chosen_mode=C.chosen_mode or function() end
    C.choose_mode=C.choose_mode or function() end
    C.scoped=dofile('candidate/runtime-source/Core/scope.lua')(R,C)
end
