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
mode="${3:-preview}"
if [[ "$mode" == original ]]; then
  filter='fps=15'
  duration=4
  quality=95
  delay=67
else
  filter='fps=12,scale=960:-2:force_original_aspect_ratio=decrease'
  duration=12
  quality=65
  delay=83
fi
"$encoder" -nostdin -v error -protocol_whitelist file,pipe -i "$1" -t "$duration" -vf "$filter" -an "$frames/frame-%04d.png" &
child=$!
wait "$child"
child=""
all=("$frames"/frame-*.png)
for count in "${#all[@]}" 30 15; do
  [[ "$count" -le "${#all[@]}" ]] || continue
  "$webp" -loop 0 -lossy -q "$quality" -d "$delay" "${all[@]:0:$count}" -o "$2" &
  child=$!
  wait "$child"
  child=""
  bytes=$(stat -f %z "$2")
  [[ "$bytes" -le 10485760 ]] && exit 0
  [[ "$mode" == original ]] || break
done
rm -f "$2"
echo 'This animation cannot fit the 10 MB renderer limit at its original resolution. Choose Preview or another wallpaper.' >&2
exit 1
