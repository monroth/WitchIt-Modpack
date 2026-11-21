-- Scope of Fill a Pot+. Gameplay hooks register through these registrars only;
-- plain R hooks are reserved for menus that choose the mode before a match.
return function(S)
    function S.log(fmt,...) S.R.log('FAP',fmt,...) end
    local C=S.C
    local function inMatch(s) return s.mode==S.codec.ID end
    local function inMode(s) return s.mode==S.codec.ID or s.mode=='creative' end
    local function editing(s) return s.mode=='creative' and not s.is_playtest end   -- (Core's playtest flag, refreshed at every toggle - audit 11-20)
    local function host(s) return C.owns(s) end
    function S.inMatch() return inMatch(C.session()) end
    function S.active() return inMode(C.session()) end
    function S.editing() return editing(C.session()) end
    function S.host() return host(C.session()) end
    S.onMatch = C.scoped(inMatch,'match')
    S.onMatchHost = C.scoped(function(s) return inMatch(s) and host(s) end,'match host')
    S.onModeHost = C.scoped(function(s) return inMode(s) and host(s) end,'match or editor host')
end
