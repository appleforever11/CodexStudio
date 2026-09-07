#!/bin/bash
set -euo pipefail
encoder=""
webp=""
for directory in /opt/homebrew/bin /usr/local/bin; do
  [[ ! -x "$directory/ffmpeg" ]] || encoder="$directory/ffmpeg"
  [[ ! -x "$directory/img2webp" ]] || webp="$directory/img2webp"
done
[[ -n "$encoder" && -n "$webp" ]] || { echo 'Install FFmpeg and WebP tools to enable experimental animation imports (brew install ffmpeg webp).' >&2; exit 1; }
frames="$(mktemp -d)"
child=""
cleanup() { [[ -z "$child" ]] || kill "$child" 2>/dev/null || true; rm -rf "$frames"; }
trap cleanup EXIT
trap 'exit 143' TERM INT
"$encoder" -nostdin -v error -protocol_whitelist file,pipe -i "$1" -t 12 -vf 'fps=12,scale=960:-2:force_original_aspect_ratio=decrease' -an "$frames/frame-%04d.png" &
child=$!
wait "$child"
child=""
"$webp" -loop 0 -lossy -q 65 -d 83 "$frames"/frame-*.png -o "$2" &
child=$!
wait "$child"
child=""
