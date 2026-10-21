#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
OUT="$ROOT/builds/updater-release"
mkdir -p "$OUT" "$ROOT/builds/logs"
run() {
  local log="$1"; shift
  "$GODOT_BIN" --headless --path "$ROOT" "$@" > "$ROOT/builds/logs/$log.log" 2>&1
  if grep -Eq '^SCRIPT ERROR:|Parse Error:|^ERROR:' "$ROOT/builds/logs/$log.log"; then cat "$ROOT/builds/logs/$log.log"; return 1; fi
}
run import --editor --import
run windows --export-release 'Windows x86_64' "$OUT/MountainStill.exe"
run macos --export-release 'macOS Universal' "$OUT/MountainStill-macOS.zip"
for platform in windows macos; do
  preset='Windows x86_64'; [[ "$platform" == macos ]] && preset='macOS Universal'
  run "${platform}-content" --export-pack "$preset" "$OUT/${platform}-content.zip"
  python3 "$ROOT/tools/verify_export_dependencies.py" "$OUT/${platform}-content.zip"
  run "${platform}-pck" --script res://tools/build_update_pack.gd -- "$OUT/${platform}-content.zip" "$OUT/MountainStill-${platform}.pck"
done
python3 "$ROOT/tools/write_update_manifest.py" "$OUT"
sha256sum "$OUT"/MountainStill* > "$OUT/SHA256SUMS.txt"
echo "Built locally only: $OUT"
