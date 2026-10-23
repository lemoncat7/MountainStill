#!/bin/bash
# Run only after isolated performance measurements finish.
set -u
BASE="$(cd "$(dirname "$0")/.." && pwd)"
export XDG_DATA_HOME="$BASE/quality-qa/soak-data"
export XDG_CONFIG_HOME="$BASE/quality-qa/soak-config"
export XDG_CACHE_HOME="$BASE/quality-qa/soak-cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
cd "$BASE"
python3 -c 'import json,hashlib,pathlib; r=pathlib.Path("quality-v1312"); x=json.load(open("quality-qa/runtime-freeze.json"))["files"]; assert all(hashlib.sha256((r/p).read_bytes()).hexdigest()==h for p,h in x.items()); print("Frozen runtime/config64 verified")' || exit 98
find quality-v1312/scripts -type f \( -name '*.gd' -o -name '*.gdshader' \) -print0 | sort -z | xargs -0 sha256sum > quality-qa/soak-source-before.sha256
timeout 3900 godot --headless --verbose --path quality-v1312 --script "$BASE/quality-qa/soak_integrated.gd" -- --duration=3600 --out="$BASE/quality-qa/soak-integrated.json" > quality-qa/soak-integrated.log 2>&1
status=$?
printf '%s\n' "$status" > quality-qa/soak-integrated.exit
find quality-v1312/scripts -type f \( -name '*.gd' -o -name '*.gdshader' \) -print0 | sort -z | xargs -0 sha256sum > quality-qa/soak-source-after.sha256
cmp quality-qa/soak-source-before.sha256 quality-qa/soak-source-after.sha256 || exit 99
python3 -c 'import json,hashlib,pathlib; r=pathlib.Path("quality-v1312"); x=json.load(open("quality-qa/runtime-freeze.json"))["files"]; assert all(hashlib.sha256((r/p).read_bytes()).hexdigest()==h for p,h in x.items()); print("Frozen runtime/config64 verified")' || exit 99
exit "$status"
