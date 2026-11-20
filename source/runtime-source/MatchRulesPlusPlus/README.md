# MatchRulesPlusPlus rewrite

`package.lua` is the `(R, C, U)` entry point. The complete decoded native inventory
is embedded beside its collection metadata: 29 groups and 181 properties.

The native four tabs and native Save/Load remain the normal rules interface. The
Match Rules ++ tab adds rules as a code (export, import) and extra rules as plain
sliders, each starting at the game's own value.

Rules last for one launch unless `Keep match rules between launches` is on in Options; kept rules wait for the next match and enter the native options when Custom Match first opens. A host's slider or import applies to the next match. A guest's edits on every tab stay local:
they only feed Export, and Pull rules from host returns to the rules being played.
Creative playtests retain their selected rules and restore the pre-playtest native
collections on stop. There is no recurring Lua work.

Physics uses the current delivered instance's baseline for host and local owning
prediction. It sends no actor rows across peers. Exact equality to a separately
captured host baseline is not asserted. Extra cauldrons to win is a Fill a Pot+ rule;
Plus Objective targets are left to FAP. The missing same-host FAP handoff and
other integration details are recorded in `evidence/rw/api-requests.md`.

Run `lua5.4 candidate/runtime-source/MatchRulesPlusPlus/tests/order.lua` from the
worktree root. The small model exercises actual PRE/native/POST order, early
match initialization, playtest stop, native timer aging and replacement instances.
It uses the existing runtime JSON parser as a test dependency. These checks do
not replace the two-account live acceptance described by the specification.
