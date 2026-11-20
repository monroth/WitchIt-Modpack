-- EffectKit: what the mods draw in the world, in one place. Each machine draws its own; nothing
-- here is sent to other players, and nothing is drawn unless a mod asks.
--   E.niagara(context, system, opts)  a Niagara system (an object): at opts.at (opts.rotation), or
--       attached to opts.attach; opts.params (as E.params); opts.off: emitters left off; opts.keep:
--       kept when it finishes (destroy it with E.remove). The component.
--   E.params(component, params)  Niagara user parameters by name: a number, a boolean, a colour
--       {R,G,B,A}, a vector {X,Y} or {X,Y,Z}, or a material (its path)
--   E.remove(component)
--   E.pointers(look)  particles from points toward targets, more the closer: each frame
--       P:aim(key, context, from, to, closeness 0..1) for each one wanted, then P:done() (the
--       others go); P:close(part) ends those whose key holds part, P:clear() all.
--       look: path (a Niagara system), params, off; a stream (kept, turned toward the target, its
--       rate(closeness) -> params each frame; reach {speed(closeness) -> cm/s, drag, stop}: its
--       User.Speed and a User.Lifetime that ends each particle stop cm before the target, slowed by
--       the effect's drag) or bursts (every(closeness) -> seconds between
--       single ones, toward: the vector parameter the target goes in).
--   E.paint(mesh, color, opts)  the colour of a mesh (every material slot): opts.material: a
--       dynamic instance of it (else its own); opts.param: the colour's parameter ('Color');
--       opts.scalars {name = value}. The instances made.
--   E.decal(decal, material, color, opts)  a decal: an instance of material (opts as E.paint)
--   E.unlit(component, color)  a mesh in one flat colour: not lit, no shadow
--   E.dots()  3D dots: D:begin(level) D:dot(key, at, color, size cm) D:finish() D:clear()
--   E.colors  pink, blue, green, yellow
local dir = debug.getinfo(1, 'S').source:match('^@(.+[\\/])')
return function(R, C)
    local E = {}
    dofile(dir .. 'particles.lua')(R, C, E)
    dofile(dir .. 'paint.lua')(R, C, E)
    return E
end
