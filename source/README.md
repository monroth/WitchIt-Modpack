# Witch It+ mods — source

Source code of the Witch It+ mods, as built for nightly 202611210204 (commit e3915ad8).

- `runtime-source/` — the Lua mods: Fill a Pot+, Match Rules ++, Editor tweaks, World edits (BaseWorldPlus), Pause,
  WindowKit, EffectKit. Each mod's tests are in its `tests/`.
- `content/` — the sources of the effects pak (EffectKit) and its build script.

The base libraries (WitchItRuntime and Core, UI Kit, Map Markers, WorldKit) and the native part: [WitchIt-Core](https://github.com/monroth/WitchIt-Core).
