#!/usr/bin/env bash
# Launch a graphical client on the GUI smoke world, isolated from the player's
# own config/saves (private write-data under .run/gui). Prints the X window id.
#   usage: dev/run-gui.sh [space-age]
#   BP_WORLD=<dev mod>   the world mod to load (default bp-gui-smoke)
#   BP_SIZE=<WxH>        client window size (default 1600x900)
set -uo pipefail
FACTORIO="${FACTORIO:-/home/shobhitg/factorio-2.0/bin/x64/factorio}"
DEV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$DEV_DIR/.." && pwd)"
RUN="$REPO/.run/gui"
DLC=false; [ "${1:-}" = "space-age" ] && DLC=true
rm -rf "$RUN/mods" "$RUN/smoke.zip"; mkdir -p "$RUN/mods" "$RUN/userdata"
ln -s "$REPO" "$RUN/mods/BlueprintPrimer"
WORLD="${BP_WORLD:-bp-gui-smoke}"
ln -s "$DEV_DIR/mods/$WORLD" "$RUN/mods/$WORLD"
cat > "$RUN/mods/mod-list.json" <<JSON
{ "mods": [
  { "name": "base", "enabled": true }, { "name": "elevated-rails", "enabled": $DLC },
  { "name": "quality", "enabled": $DLC }, { "name": "space-age", "enabled": $DLC },
  { "name": "BlueprintPrimer", "enabled": true }, { "name": "$WORLD", "enabled": true } ] }
JSON
cat > "$RUN/config.ini" <<INI
[path]
read-data=__PATH__executable__/../../data
write-data=$RUN/userdata
[graphics]
full-screen=false
INI
"$FACTORIO" --config "$RUN/config.ini" --create "$RUN/smoke.zip" --mod-directory "$RUN/mods" --map-gen-seed 1 > "$RUN/create.log" 2>&1 \
  || { tail -20 "$RUN/create.log"; exit 1; }
nohup "$FACTORIO" --config "$RUN/config.ini" --mod-directory "$RUN/mods" --load-game "$RUN/smoke.zip" \
  --window-size "${BP_SIZE:-1600x900}" > "$RUN/client.log" 2>&1 &
echo $! > "$RUN/pid"; echo "pid=$(cat "$RUN/pid")"
