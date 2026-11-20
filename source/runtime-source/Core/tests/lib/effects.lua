-- EffectKit for a test's mocks: the real library (it calls the engine only when asked to draw).
return function(R, C)
    R.packages = R.packages or {}
    R.on = R.on or function() end
    R.packages.EffectKit = dofile('candidate/runtime-source/EffectKit/package.lua')(R, C)
    return R.packages.EffectKit
end
