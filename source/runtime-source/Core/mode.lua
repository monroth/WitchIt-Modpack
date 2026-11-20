-- The single answer to "which mode is this session in". Every package scope reads it.
-- map: Core's map modules, whose mode modules say whether this session is theirs (spec.plays(s));
-- hostMode is the mode the host published, as seen by a client.
return function(s,map,hostMode)
    if s.role~='offline' and s.is_vanilla_session then return 'vanilla' end
    if s.is_creative then return s.is_vanilla_session and 'vanilla' or 'creative' end
    if s.role=='offline' then return 'none' end
    if s.role=='client' then return hostMode or 'vanilla' end
    for _,id in ipairs(map and map.modes() or {}) do
        local spec=map.spec(id)
        if spec.plays and spec.plays(s) then return id end
    end
    return s.mode_id or 'none'
end
