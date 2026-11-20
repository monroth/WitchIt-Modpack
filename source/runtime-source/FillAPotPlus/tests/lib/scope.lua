-- Core's C.scoped test double plus the real Fill a Pot+ scope.
-- Tests choose the mode through session.mode.
return function(S)
    S.codec=S.codec or {ID='monroth.fap'}
    dofile('candidate/runtime-source/Core/tests/lib/scoped.lua')(S.R,S.C)
    dofile('candidate/runtime-source/FillAPotPlus/scope.lua')(S)
    -- Map trace lines read native option fields the doubles do not model.
    S.log=function() end
end
