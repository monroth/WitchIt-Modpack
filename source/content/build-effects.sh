#!/usr/bin/env bash
# Builds EffectKit's effects pack (runtime-source/EffectKit/Paks): each effects/<NS_Name>.txt makes
# /Game/EffectKit/<NS_Name> from an engine template ("template <path>"), gives it user parameters
# ("user <name> <float|vec2|color|material> <default>"; "bindmaterial <renderer> <name>": the renderer
# draws with that user material), adds modules ("add <emitter> <module class path>") and sets its objects' properties as text ("set <object
# inside the asset> TAB <property path> TAB <value>", with the editor tool WitProps of
# WitchIt/Plugins/WitFxTools); then each is cooked alone and all are packed. Lightweight
# (stateless) emitters and materials the game has (a stand-in of the same path in the project, not
# packed: the game's own is used): nothing needs a shader of its own. The stand-ins:
# content/standins.py, run in the editor once.
set -euo pipefail
HERE=$(cd -- "$(dirname -- "$0")" && pwd)
PROJECT=${WITCHIT_PROJECT:-/mnt/SATA-1/Temp/WitchIt-claude/ue-project/WitchIt}
ROOT=${UNREAL_ENGINE:-/mnt/SATA-1/UnrealEngine-5.7}
ENGINE=$ROOT/Engine/Binaries/Linux/UnrealEditor-Cmd
RETOC=${RETOC:-/mnt/SATA-1/Temp/WitchitData/recon/assets/tools/retoc-src/target/release/retoc}
OUT=$HERE/../runtime-source/EffectKit/Paks
rsync -a --exclude Saved --exclude Intermediate --exclude DerivedDataCache --exclude Binaries "$HERE/WitchIt/" "$PROJECT/"
"$ROOT/Engine/Build/BatchFiles/Linux/Build.sh" WitchItEditor Linux Development -Project="$PROJECT/WitchIt.uproject" -waitmutex >/dev/null
WORK=$(mktemp -d -p "$(dirname "$PROJECT")")
trap 'rm -rf "$WORK"' EXIT
run() { "$ENGINE" "$PROJECT/WitchIt.uproject" "$@" -unattended -nullrhi -nosplash -nop4 > "$WORK/run.log" 2>&1 || { tail -n 20 "$WORK/run.log"; exit 1; }; }
mkdir -p "$WORK/WitchIt/Content/EffectKit"
for def in "$HERE"/effects/NS_*.txt; do
    name=$(basename "$def" .txt) asset=/Game/EffectKit/$name
    template=$(awk '$1=="template"{print $2}' "$def")
    cat > "$WORK/make.py" <<PY
import unreal
lib, tools = unreal.EditorAssetLibrary, unreal.AssetToolsHelpers.get_asset_tools()
if lib.does_asset_exist('$asset'): lib.delete_asset('$asset')
lib.save_loaded_asset(tools.duplicate_asset('$name', '/Game/EffectKit', unreal.load_asset('$template')))
PY
    run -run=pythonscript -script="$WORK/make.py"
    python3 - "$def" "$asset.$name" > "$WORK/edits.txt" <<'PY'
import sys
for line in open(sys.argv[1]):
    if line.startswith('user '): print('#user', sys.argv[2], line[5:].strip())
    elif line.startswith('add '):
        emitter, module = line[4:].split()
        print('#add', sys.argv[2] + ':' + emitter, module)
    elif line.startswith('dump '): print('#dump', sys.argv[2] + ':' + line[5:].strip())
    elif line.startswith('bindmaterial '):
        renderer, name = line[13:].split()
        print('#bindmaterial', sys.argv[2] + ':' + renderer, name)
    elif line.startswith('set '):
        target, prop, value = line[4:].rstrip('\n').split('\t')
        print(sys.argv[2] + ':' + target, prop, value, sep='\t')
PY
    run -run=WitProps -edits="$WORK/edits.txt"
    run -run=cook -targetplatform=Linux -unversioned -cooksinglepackagenorefs -package=$asset
    cp "$PROJECT"/Saved/Cooked/Linux/WitchIt/Content/EffectKit/$name.* "$WORK/WitchIt/Content/EffectKit/"
    echo "built $name"
done
mkdir -p "$OUT" && rm -f "$OUT"/EffectKit_P.*
"$RETOC" to-zen --version UE5_7 "$WORK" "$OUT/EffectKit_P.utoc" >/dev/null
ls -l "$OUT"
