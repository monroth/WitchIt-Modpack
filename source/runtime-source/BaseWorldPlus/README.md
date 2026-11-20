World edits: the edits a map makes to its base world, saved in the layout as the map record
`monroth.bwp` and applied with it for everyone in the session (the host publishes `bwp.world`;
guests apply what it sends and never read host files):

- hidden scenery: whole scenery actors (with their lights, sounds and effects), single components
  of other placed actors, single foliage instances;
- source geometry: actors of the original level rebuilt in the layout (`R.native.source_actors`).

Edits of base-world teleporters are gone: hide the vanilla teleporter and place one instead.

Editing goes through the API this package returns (see the end of `package.lua`); the hide tool
is the Editor tweaks package (`../EditorTweaks`).

Tests: `tests/objects.lua`, `tests/companions.lua` (all bundled maps carry readable edits),
`tests/call_order.lua` (World edits with Editor tweaks over it), run by `evidence/vote/run_tests.py`.
