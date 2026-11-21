# Witch It+ mods — source

Source code of the Witch It+ mods, as built for nightly 202611210204 (commit e3915ad8).

- `runtime-source/` — the Lua mods: WitchItRuntime and Core, UI Kit, Fill a Pot+, Match Rules ++, Editor tweaks,
  World edits (BaseWorldPlus), Map Markers, Pause, WindowKit, WorldKit, EffectKit. Each mod's tests are in its `tests/`.
- `consumer/` — the native part loaded by our UE4SS build.
- `content/` — the sources of the effects pak (EffectKit) and its build script.
