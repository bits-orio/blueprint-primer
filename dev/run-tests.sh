#!/usr/bin/env bash
# Headless test runner for Blueprint Primer.
#
# For each mod set (base only, then base + quality + space-age) it builds an
# isolated mod directory under .run/tests/<set>/mods holding symlinks to the
# mod and to dev/mods/bp-test, creates a fresh save (bp-test's on_init lays
# out the rig and runs the contract cases), then advances it with --benchmark
# so robots fly and furnaces smelt before the delivery checks.
#
#   usage: dev/run-tests.sh [base|space-age ...]     (no args = both sets)
#
#   BP_MOD_SRC=<dir>   test another copy of the mod instead of the repo root
#   BP_TEST_TICKS=<n>  benchmark length (must pass bp-test's CHECK_TICK)
#   FACTORIO=<path>    the Factorio binary: 2.1.17 by default on this branch,
#                      /home/shobhitg/factorio-2.0/bin/x64/factorio for 2.0.77
#
# Factorio refuses a mod whose info.json names another major.minor than its
# own. When the binary's differs from info.json's factorio_version, the run
# dir gets COPIES of the mod and bp-test with factorio_version patched to the
# binary's, instead of symlinks; the repo's info.json is never touched.
#
# Exit status is non-zero on any BP_TEST FAIL, any Lua/engine error in the
# logs, a failed Factorio run, or a missing BP_TEST DONE marker.
set -uo pipefail

FACTORIO="${FACTORIO:-/home/shobhitg/factorio-2.1/bin/x64/factorio}"
DEV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$DEV_DIR/.." && pwd)"
MOD_SRC="${BP_MOD_SRC:-$REPO}"
TEST_MOD="$DEV_DIR/mods/bp-test"
RUN_DIR="$REPO/.run/tests"
TICKS="${BP_TEST_TICKS:-15100}"

SETS=("$@")
if [ ${#SETS[@]} -eq 0 ]; then SETS=(base space-age); fi

# "2.0" from "Version: 2.0.77 (build ...)".
ENGINE_VERSION="$("$FACTORIO" --version 2>/dev/null | sed -nE 's/^Version: ([0-9]+\.[0-9]+)\..*/\1/p' | head -n 1)"

mod_version() { # <mod dir>
  sed -nE 's/.*"factorio_version": *"([^"]+)".*/\1/p' "$1/info.json"
}

# A symlink when the mod already targets this engine, else a patched copy
# (without the repo's run dir, git data and never-shipped folders).
stage_mod() { # <source dir> <destination>
  if [ -z "$ENGINE_VERSION" ] || [ "$(mod_version "$1")" = "$ENGINE_VERSION" ]; then
    ln -s "$1" "$2"
    return
  fi
  mkdir -p "$2"
  rsync -a --exclude .git --exclude .run --exclude dev --exclude docs --exclude tools "$1/" "$2/"
  sed -i -E "s/(\"factorio_version\": *\")[^\"]+\"/\1$ENGINE_VERSION\"/" "$2/info.json"
}

write_mod_list() { # <mods dir> <dlc enabled: true|false>
  cat > "$1/mod-list.json" <<EOF
{
  "mods": [
    { "name": "base", "enabled": true },
    { "name": "elevated-rails", "enabled": $2 },
    { "name": "quality", "enabled": $2 },
    { "name": "space-age", "enabled": $2 },
    { "name": "BlueprintPrimer", "enabled": true },
    { "name": "bp-test", "enabled": true }
  ]
}
EOF
}

# A private write-data directory keeps these runs off the player's own
# Factorio lock file, config and logs, so tests can run while the game is open.
write_config() { # <set dir>
  mkdir -p "$1/userdata"
  cat > "$1/config.ini" <<EOF
[path]
read-data=__PATH__executable__/../../data
write-data=$1/userdata
EOF
}

prepare_set() { # <set name> <set dir>
  local dlc=false
  [ "$1" = "space-age" ] && dlc=true
  rm -rf "$2/mods"
  mkdir -p "$2/mods"
  stage_mod "$MOD_SRC" "$2/mods/BlueprintPrimer"
  stage_mod "$TEST_MOD" "$2/mods/bp-test"
  write_mod_list "$2/mods" "$dlc"
  write_config "$2"
}

# Engine and script errors, but not our own BP_TEST lines (a FAIL detail may
# legitimately contain the word "error").
engine_errors() { # <log files...>
  grep -h -v "BP_TEST" "$@" | grep -E "Error|error while|stack traceback|Failed to load mods" || true
}

launch() { # <set name> <set dir>; runs --create then --benchmark
  local name="$1" dir="$2"
  local save="$dir/test.zip" cfg="$dir/config.ini"
  rm -f "$save" "$dir/create.log" "$dir/bench.log" "$dir/results.txt"
  touch "$dir/bench.log"
  "$FACTORIO" --config "$cfg" --create "$save" --mod-directory "$dir/mods" --map-gen-seed 1 \
    > "$dir/create.log" 2>&1 || { echo "[$name] --create failed"; return 1; }
  "$FACTORIO" --config "$cfg" --benchmark "$save" --benchmark-ticks "$TICKS" --mod-directory "$dir/mods" \
    > "$dir/bench.log" 2>&1 || { echo "[$name] --benchmark failed"; return 1; }
}

evaluate() { # <set name> <set dir> <launch status>; prints a summary
  local name="$1" dir="$2" status="$3"
  local logs=("$dir/create.log" "$dir/bench.log")
  grep -h "BP_TEST" "${logs[@]}" | sed -E 's/^.*BP_TEST /BP_TEST /' > "$dir/results.txt"
  local pass fail errors
  pass=$(grep -c "^BP_TEST PASS" "$dir/results.txt")
  fail=$(grep -c "^BP_TEST FAIL" "$dir/results.txt")
  errors=$(engine_errors "${logs[@]}")
  echo "[$name] pass=$pass fail=$fail   (logs: $dir)"
  grep "^BP_TEST FAIL" "$dir/results.txt" | sed "s/^/  [$name] /"
  if [ "$fail" -gt 0 ]; then status=1; fi
  if [ -n "$errors" ]; then echo "$errors" | head -20 | sed "s/^/  [$name] ERROR: /"; status=1; fi
  if ! grep -q "^BP_TEST DONE" "$dir/results.txt"; then echo "  [$name] missing BP_TEST DONE"; status=1; fi
  if [ "$status" -ne 0 ] && [ "$fail" -eq 0 ]; then tail -n 15 "${logs[@]}" | sed "s/^/  [$name] /"; fi
  return "$status"
}

run_set() { # <set name>
  local dir="$RUN_DIR/$1" status=0
  prepare_set "$1" "$dir"
  launch "$1" "$dir" || status=1
  evaluate "$1" "$dir" "$status"
}

overall=0
echo "Factorio $ENGINE_VERSION: $FACTORIO"
for set in "${SETS[@]}"; do
  case "$set" in
    base|space-age) run_set "$set" || overall=1 ;;
    *) echo "unknown set: $set (expected base or space-age)"; overall=1 ;;
  esac
done
if [ $overall -eq 0 ]; then echo "ALL PASS"; else echo "FAILED"; fi
exit $overall
