# Witch It+ mods

A mod source for the [Witch It+ launcher](https://github.com/monroth/WitchIt-Plus).
`witchit-mods.json` lists the mods and their versions; each version is a release `<id>-v<version>`.

## Mods

| Mod | What it does |
|---|---|
| Fill a Pot+ | More Fill a Pot: new maps, Creative compatibility, new features and vanilla bug fixes. |
| Match Rules++ | Extra match rules beside the game's own, easy sharing of rules, and yes, bug fixes too. |
| World edits | Hidden scenery, teleporters and map geometry of custom maps. |
| Editor tweaks | A tool to actually hide scenery in Creative, for World edits. |
| Pause | The host pauses and resumes the round timer. |
| Core | Library: the runtime, its native part and the updater. Everything needs it. |
| UIKit | Library: the mods' menus, settings and shortcuts. |
| Map markers, WorldKit, WindowKit | Libraries of the Creative tools. If you want extra UI for your Creative tools, or to add new and exciting objects to your map, the tools for that are right here. |
| EffectKit | Library of effects: particles, streams toward targets, colours of objects. |

## Making your own source

A source is a public GitHub repository (or a private one, with a read-only token) with
`witchit-mods.json` in its root:

```json
{"mods": {"my-mod": {
  "name": "My Mod",
  "description": "One sentence.",
  "tags": ["gameplay", "host"],
  "sync": false,
  "folders": ["MyMod"],
  "versions": {
    "1.0.0": {"sha256": "<sha256 of my-mod.zip>",
              "needs": {"monroth/WitchIt-Modpack:core": ">=0.4"}}
  }}}}
```

- **Archive:** `my-mod.zip`, paths starting at `ue4ss/` (`ue4ss/Mods/MyMod/manifest.lua`, …), only
  inside the mod's own `folders`.
- **Release:** tag `my-mod-v1.0.0`, asset `my-mod.zip`; its sha256 in the index.
- **Versions:** `N.N.N` are releases; `N.N.N-nightly.<number>` nightlies; anything else an alpha
  (chosen only by hand).
- **Needs:** `id` (same source) or `owner/repo:id`; conditions `1.2.0`, `1.2.*`, `>=1.0`,
  `<=1.*`, space-separated.
- **Tags:** what it is — `gameplay`, `maps`, `creative`, `utility`, `technical` (a library); where
  it runs — `host`, `client`. `sync: true` means every player in a match needs the host's version.
- **Your mod's code:** see [the mod guide](PUBLISHING-MODS.md) (manifest, package, runtime).

Players add `your-name/your-repo` on the launcher's **Sources** page.

You can use this repository as an example of a source with a correct `witchit-mods.json` and releases.

## Source

The source of these mods is in [`source/`](source). They are built with our UE4SS: [monroth/RE-UE4SS-Witchit@ebae54ca](https://github.com/monroth/RE-UE4SS-Witchit/tree/ebae54ca938e36ee1a898d11b66149489dbfb670).
