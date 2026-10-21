#!/usr/bin/env bash
# Run in a real native desktop terminal. This is not a headless capture.
set -uo pipefail
PROJECT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
OUT=${1:?Supply a new absolute output directory}
case "$OUT" in /*) ;; *) echo 'Output directory must be absolute' >&2; exit 2;; esac
[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] || { echo 'Run this in the native desktop terminal' >&2; exit 2; }
mkdir -p "$OUT"
for file in earned-save.json earned-save.json.bak native.ogv; do
  [ ! -e "$OUT/$file" ] || { echo "Refusing existing $OUT/$file" >&2; exit 3; }
done
"${GODOT_BIN:-godot}" --path "$PROJECT" --resolution 1200x320 --fixed-fps 60 --write-movie "$OUT/native.ogv" --script tests/show_complete_player_journey.gd -- --output="$OUT" > "$OUT/native.log" 2>&1
status=$?
printf '%s\n' "$status" > "$OUT/exit-code.txt"
exit "$status"
