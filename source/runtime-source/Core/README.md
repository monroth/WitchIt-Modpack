# Core rewrite

Core receives R and returns the C table in ARCH.md. It installs no widgets and has no gameplay effects by itself. Session references are cleared on world departure and rebound by world/controller/game events.

`C.net` uses the existing controller RPC pair with `WIR3:` frames. Reliable native RPC ordering carries bounded chunks; there are no ACKs, readiness messages, retries, or periodic jobs. Publication replaces the latest value for a topic and invokes local watchers on the publishing host. Late joiners receive the current map once. Native controllers supply request sender identity. World departure clears publications and partial chunks; watch subscriptions survive. Values must be JSON-compatible. Chunked packets are limited to 512 KiB before hex framing.

`C.mods.identity`, `peers`, and `message` are ordinary local facts. `status()` returns installed/next-launch package choices, local/host identity, compatibility messages, hosting settings, hotkeys/defaults, updater results, and restart/rehost flags. UIKit writes enable switches into package manifests and hosting choices through Core settings, saves them, then calls status to reflect the change. `request('check'|'latest'|'exact', optional_host_packages)` performs an explicit updater action; private installations use local rebuild/install. Only public IDs are advertised or sent to the updater.

CreateSession fixes the hosting policy and required package versions for the session. Checked VanillaServer suppresses gameplay extensions unless Fill a Pot+ is selected. Otherwise every installed, enabled public gameplay package is required; an empty set stays vanilla. UpdateSession preserves that decision. Changing VanillaServer requires rehosting.

File paths are `PackageId/relative/path`, rooted at `Saved/WitchItRuntime`; `saved_root(pkg)` exposes the package root. Preset and layout schemas/imports belong to their feature owners. Layout events originate at successful physical native save and completed reader/application boundaries.

Integration and live verification are recorded in evidence/rwint/reply.md.

`rules.lua` (`C.saved_rules`) keeps mods' rules beside the native Save/Load files: one `Core/rules/<name>.json` per file, one section per registered mod. Rules codes carry the same sections.
