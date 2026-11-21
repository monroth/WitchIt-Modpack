# Runtime rewrite

`Scripts/main.lua` enters the game thread once and injects the same ordinary R/C/U tables into Core, UIKit, FillAPotPlus, MatchRulesPlusPlus, BaseWorldPlus, then optional PrivateCosmetics. Package switches apply next launch. Errors remain visible in the engine log.

`R.valid` returns the normalized valid UObject or nil. Hook inputs are unwrapped; reflected OUT arguments remain writable `get`/`set` parameters. Native POST callbacks preserve the SDK's return-value argument after self. Blueprint PRE forwards the scalar/object arguments used by the retained call sites through the existing producer interceptor.

Actor, widget, and GameInstance queries use the current world. Other UObject queries are finite and filtered to that world. Class-construction notifications install hooks only; they do not run feature/UI initialization. One-shot work is cancelled at world departure, including already-published callbacks; `R.after(ms, fn, true)` survives it.

Native leaves: `spawn(class, world, placement, initialize)`, `spawn_local`, `destroy`, `on_asset(path, callback)`, `load_asset(path)`, `retain`, `capsule_probe(context, ignored, start, finish, radius, half_height)`, `on_overlap`, `on_input`, `on_pointer`, `skin_rpc`, clipboard get/set, `preset_names(widget, offset)`, `objective_pool`, `read_bytes`, `source_actors`, `release_source_levels`, teleporter pair/exit, and file read/write/list. Native subscriptions return cancel functions. Placement uses X/Y/Z, Yaw/Pitch/Roll, and ScaleX/Y/Z. Initial skin tuples use `{type='Skin', name=...}`. Features normally observe `layout_saved`/`layout_loaded`; Runtime attaches the native save/load callback pair once.

Settings live at `Saved/WitchItRuntime/PackageId/settings.json`. Runtime owns the shortcut inventory, conflict checks and overrides. R.hotkeys() returns id/mod/label/default/current rows; R.set_hotkey(id,chord) edits them, and R.capture_hotkey(fn) temporarily captures input exclusively. F5 is reserved. UIKit owns presentation; feature callbacks own their tool/mode conditions.

Run from the worktree root:

```
python3 candidate/runtime-source/WitchItRuntime/tests/run.py
```

The runner uses the installed Lua 5.4 interpreter library to compile every owned Lua file and execute three small engine-order tests. It does not certify live engine behavior.

Packages load immediately in manifest order. `load_asset` returns a resident object or loads it through the native primitive; `spawn` accepts a class object or class path. Menu changes issued by UIKit run through `R.next_frame`, outside Blueprint hooks. Wardrobe preview skins use `on_asset` and apply on the next frame.
