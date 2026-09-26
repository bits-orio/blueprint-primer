#!/usr/bin/env bash
# Spike driver: create a save with the bp-spike mod (on_init lays out the test
# rig), then advance it headless with --benchmark so robots actually fly and
# furnaces actually smelt. Prints the BP_SPIKE lines.
set -uo pipefail
FACTORIO=/home/shobhitg/factorio-2.0/bin/x64/factorio
DEV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="${BP_WORK:-$DEV_DIR/../.run/spike}"
mkdir -p "$WORK"
rm -f "$WORK/spike.zip"
"$FACTORIO" --create "$WORK/spike.zip" --mod-directory "$DEV_DIR/mods" --map-gen-seed 1 > "$WORK/create.log" 2>&1 \
  || { tail -30 "$WORK/create.log"; exit 1; }
"$FACTORIO" --benchmark "$WORK/spike.zip" --benchmark-ticks 20100 --mod-directory "$DEV_DIR/mods" > "$WORK/bench.log" 2>&1 \
  || { tail -30 "$WORK/bench.log"; exit 1; }
grep -h BP_SPIKE "$WORK/create.log" "$WORK/bench.log"
