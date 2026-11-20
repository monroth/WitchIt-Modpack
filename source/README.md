# Witch It+ mods — source

Source code of the Witch It+ mods, as built for nightly 202611200651 (commit f324dba8).

- `runtime-source/` — the Lua mods: WitchItRuntime and Core (with UI Kit), Fill a Pot+, Match Rules ++, Editor tweaks,
  World edits (BaseWorldPlus), Map Markers, Pause, WindowKit, WorldKit, EffectKit. Each mod's tests are in its `tests/`.
- `consumer/` — the native part loaded by our UE4SS build.
- `content/` — the sources of the effects pak (EffectKit) and its build script.

Our UE4SS changes: https://github.com/monroth/RE-UE4SS-Witchit (branch `witchit`).
