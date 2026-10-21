#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
OUT=${1:?Supply the completed capture directory}
PREFIX=${2:-MountainStill-v1.3.8-full}
mkdir -p "$OUT/clips"
SOURCE="$OUT/native.ogv"
if [ ! -f "$SOURCE" ]; then SOURCE="$OUT/native.avi"; fi
ffmpeg -hide_banner -y -i "$SOURCE" -vf fps=30 -c:v libx264 -preset slow -crf 25 -maxrate 340k -bufsize 680k -pix_fmt yuv420p -g 150 -force_key_frames 'expr:gte(t,n_forced*150)' -c:a aac -b:a 32k -ac 1 -f segment -segment_time 150 -segment_start_number 1 -reset_timestamps 1 -segment_format mp4 -segment_format_options movflags=+faststart "$OUT/clips/$PREFIX-%02d.mp4" > "$OUT/encode.log" 2>&1
python3 "$HERE/build_clip_manifest.py" "$OUT"
