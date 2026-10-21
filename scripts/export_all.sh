#!/usr/bin/env bash
# Official Godot 4.6.3 export templates must be installed for this editor.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -z "${GODOT_BIN:-}" ]]; then
  if [[ -x "$ROOT/../godot-tools/godot-env.sh" ]]; then
    GODOT_BIN="$ROOT/../godot-tools/godot-env.sh"
  elif command -v godot >/dev/null 2>&1; then
    GODOT_BIN="$(command -v godot)"
  else
    printf 'Set GODOT_BIN to your Godot 4.6.3 executable.\n' >&2
    exit 1
  fi
fi
mkdir -p "$ROOT/builds"/{windows,macos,linux,logs}
check_log() {
  if grep -Eq '^SCRIPT ERROR:|Parse Error:|^ERROR:' "$1"; then
    printf 'Build stopped: inspect %s\n' "$1" >&2
    exit 1
  fi
}
"$GODOT_BIN" --headless --path "$ROOT" --editor --import 2>&1 | tee "$ROOT/builds/logs/import.log"
check_log "$ROOT/builds/logs/import.log"
"$GODOT_BIN" --headless --path "$ROOT" --export-release 'Windows x86_64' "$ROOT/builds/windows/MountainStill.exe" 2>&1 | tee "$ROOT/builds/logs/windows.log"
check_log "$ROOT/builds/logs/windows.log"
"$GODOT_BIN" --headless --path "$ROOT" --export-release 'macOS Universal' "$ROOT/builds/macos/MountainStill-macOS.zip" 2>&1 | tee "$ROOT/builds/logs/macos.log"
check_log "$ROOT/builds/logs/macos.log"
"$GODOT_BIN" --headless --path "$ROOT" --export-release 'Linux x86_64' "$ROOT/builds/linux/MountainStill.x86_64" 2>&1 | tee "$ROOT/builds/logs/linux.log"
check_log "$ROOT/builds/logs/linux.log"
chmod +x "$ROOT/builds/linux/MountainStill.x86_64"
python3 "$ROOT/tools/package_builds.py"
printf '\nBuilds and archives are in %s/builds\n' "$ROOT"
printf 'Windows is unsigned. macOS is ad-hoc signed, without Developer ID or notarization. Neither target has been executed here.\n'
