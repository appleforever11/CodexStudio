#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEME_PACKS_DIR="$ROOT_DIR/Resources/ThemePacks"
USER_HOME="${HOME:-}"
if [[ -z "$USER_HOME" ]]; then
  echo "The user's home directory could not be resolved." >&2
  exit 1
fi

CACHE_DIR="${CODEX_STUDIO_THEME_CACHE_DIR:-$USER_HOME/Library/Application Support/CodexStudio/ThemePacks}"
ARCHIVE_REF="${CODEX_STUDIO_MOBILE_ARCHIVE_REF:-master}"
ARCHIVE_TREE_URL="${CODEX_STUDIO_MOBILE_ARCHIVE_TREE_URL:-https://api.github.com/repos/SniperGER/iOS-Wallpapers/git/trees/$ARCHIVE_REF?recursive=1}"
ARCHIVE_RAW_ROOT="${CODEX_STUDIO_MOBILE_ARCHIVE_RAW_ROOT:-https://raw.githubusercontent.com/SniperGER/iOS-Wallpapers/$ARCHIVE_REF}"
ARCHIVE_PAGE="https://github.com/SniperGER/iOS-Wallpapers"
APPLE_WWDC_PAGE="https://developer.apple.com/wwdc26/wallpaper/"
RETRIEVED_AT="${CODEX_STUDIO_RETRIEVED_AT:-$(date +%F)}"
REFRESH="${CODEX_STUDIO_REFRESH_OFFICIAL_MOBILE_WALLPAPERS:-false}"
WORK_DIR="$(mktemp -d /tmp/codexstudio-official-mobile.XXXXXX)"
FORMATTER="$WORK_DIR/format_mobile_wallpaper"
TREE_FILE="$WORK_DIR/tree.json"
MANIFEST_FILE="$WORK_DIR/candidates.tsv"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$THEME_PACKS_DIR" "$CACHE_DIR"

curl -L --fail --retry 3 --silent --show-error "$ARCHIVE_TREE_URL" -o "$TREE_FILE"
swiftc -O -framework AppKit "$ROOT_DIR/script/format_mobile_wallpaper.swift" -o "$FORMATTER"

# The archive contains multiple device-size exports of the same wallpaper. Pick
# the largest still for each distinct artwork within each platform, while
# excluding motion assets and thumbnail/default/poster derivatives. The source
# archive says these stills were extracted from Apple firmware; iOS 16+ layered
# wallpapers are represented by the archive's documented static composition.
python3 - "$TREE_FILE" "$MANIFEST_FILE" "$ARCHIVE_RAW_ROOT" "$ARCHIVE_PAGE" "$APPLE_WWDC_PAGE" <<'PY'
import hashlib
import json
import os
import re
import sys
import unicodedata
from pathlib import Path
from urllib.parse import quote

tree_file, manifest_file, raw_root, archive_page, apple_page = sys.argv[1:]
tree = json.load(open(tree_file, "r", encoding="utf-8"))

allowed_extensions = {".heic", ".jpg", ".jpeg", ".png"}

def normalized_key(path: str) -> str:
    stem = Path(path).stem
    stem = re.sub(r"-marble-[0-9]+w-[0-9]+h(?:@[0-9]+x)?~(?:iphone|ipad)$", "", stem, flags=re.I)
    stem = re.sub(r"-[0-9]+w-[0-9]+h(?:@[0-9]+x)?~(?:iphone|ipad)$", "", stem, flags=re.I)
    stem = re.sub(r"-[0-9]+h(?:@[0-9]+x)?~(?:iphone|ipad)$", "", stem, flags=re.I)
    stem = re.sub(r"@[0-9]+x~(?:iphone|ipad)$", "", stem, flags=re.I)
    stem = re.sub(r"~(?:iphone|ipad)$", "", stem, flags=re.I)
    stem = re.sub(r"-[0-9]+w-[0-9]+h$", "", stem, flags=re.I)
    return stem or Path(path).stem

def source_area(path: str) -> int:
    stem = Path(path).stem
    match = re.search(r"([0-9]+)w-([0-9]+)h", stem)
    if match:
        return int(match.group(1)) * int(match.group(2))
    device = path.split("/")[1]
    fallback = {
        '3.5" @1x': (320, 480),
        '3.5" @2x': (640, 960),
        '4.0"': (640, 1136),
        '4.7"': (750, 1334),
        '5.4"': (1080, 2340),
        '5.5"': (1080, 1920),
        '5.8"': (1125, 2436),
        '6.1" @2x': (828, 1792),
        '6.1" @3x': (1170, 2532),
        '6.5"': (1242, 2688),
        '6.7"': (1290, 2796),
        '8.3"': (1488, 2266),
        '9.7" @1x': (768, 1024),
        '9.7" @2x': (1536, 2048),
        '10.2"': (1620, 2160),
        '10.5"': (1668, 2224),
        '10.9"': (1640, 2360),
        '11.0"': (1668, 2388),
        '12.9"': (2048, 2732),
    }
    width, height = fallback.get(device, (1, 1))
    return width * height

def slug(value: str) -> str:
    value = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode("ascii")
    value = re.sub(r"[^A-Za-z0-9]+", "-", value).strip("-").lower()
    return value[:56] or "wallpaper"

def display_name(value: str) -> str:
    value = re.sub(r"^\d+\.", "", value)
    value = value.replace("_", " ").replace("-", " ")
    value = re.sub(r"\bWWDC(?=\d)", "WWDC ", value, flags=re.I)
    value = re.sub(r"\biOS(?=\d)", "iOS ", value, flags=re.I)
    value = re.sub(r"\biPadOS(?=\d)", "iPadOS ", value, flags=re.I)
    words = []
    replacements = {
        "ios": "iOS",
        "ipados": "iPadOS",
        "wwdc": "WWDC",
        "ef": "EF",
        "hero": "Hero",
    }
    for word in re.split(r"\s+", value.strip()):
        if not word:
            continue
        words.append(replacements.get(word.lower(), word[:1].upper() + word[1:].lower()))
    return " ".join(words) or "Apple Wallpaper"

candidates = {}
for item in tree.get("tree", []):
    path = item.get("path", "")
    if item.get("type") != "blob" or "/Stills/" not in path:
        continue
    if not (path.startswith("iPhone/") or path.startswith("iPad/")):
        continue
    if Path(path).suffix.lower() not in allowed_extensions:
        continue
    filename = Path(path).name.lower()
    if any(token in filename for token in ("thumbnail", "default", "poster")):
        continue
    parts = path.split("/")
    if len(parts) < 5:
        continue
    platform = "iOS" if parts[0] == "iPhone" else "iPadOS"
    key = normalized_key(path)
    group_key = (platform, key)
    previous = candidates.get(group_key)
    score = (source_area(path), int(item.get("size", 0)), path)
    if previous is None or score > previous[0]:
        candidates[group_key] = (score, item, platform, parts[1], parts[2], key)

with open(manifest_file, "w", encoding="utf-8") as handle:
    for _, item, platform, device, version, key in sorted(candidates.values(), key=lambda row: (row[2], row[4], row[5], row[3])):
        source_path = item["path"]
        pack_id = f"{platform.lower()}-{slug(key)}-{hashlib.sha256((platform + '|' + key).encode()).hexdigest()[:8]}"
        image_url = raw_root.rstrip("/") + "/" + quote(source_path, safe="/:@-_.~")
        fields = [pack_id, platform, version, device, source_path, display_name(key), image_url, archive_page, "SniperGER archive"]
        handle.write("\t".join(fields) + "\n")

direct = [
    ("ios-27-celosia-iphone", "iOS", "iOS 27", "iPhone", "Apple Developer WWDC26 wallpaper · iPhone", "Celosia · iPhone", "https://developer.apple.com/wwdc26/wallpaper/images/iphone/large_2x.jpg", apple_page, "Apple Developer"),
    ("ipados-27-celosia-ipad", "iPadOS", "iPadOS 27", "iPad", "Apple Developer WWDC26 wallpaper · iPad", "Celosia · iPad", "https://developer.apple.com/wwdc26/wallpaper/images/ipad/large_2x.jpg", apple_page, "Apple Developer"),
]
with open(manifest_file, "a", encoding="utf-8") as handle:
    for row in direct:
        handle.write("\t".join(row) + "\n")

print(f"Selected {len(candidates)} distinct archive stills plus {len(direct)} current Apple-hosted platform assets.")
PY

if [[ "${CODEX_STUDIO_MOBILE_DRY_RUN:-false}" == "true" ]]; then
  echo "Dry run only; no source metadata or image derivatives were written."
  exit 0
fi

# The importer owns the ios-* and ipados-* namespaces. If a future archive
# refresh changes a deduplicated id, move only the old generated packs out of
# the active source/cache into a dated Trash folder instead of leaving stale
# aliases in the gallery or permanently deleting user data.
VALID_ID_FILE="$WORK_DIR/valid-ids"
cut -f1 "$MANIFEST_FILE" | sort -u > "$VALID_ID_FILE"
TRASH_ROOT="$USER_HOME/.Trash/Codex Studio stale mobile import $RETRIEVED_AT"
for mobile_root in "$THEME_PACKS_DIR" "$CACHE_DIR"; do
  while IFS= read -r -d '' stale_pack; do
    stale_id="$(basename "$stale_pack")"
    if ! grep -Fqx "$stale_id" "$VALID_ID_FILE"; then
      mkdir -p "$TRASH_ROOT/$(basename "$mobile_root")"
      mv "$stale_pack" "$TRASH_ROOT/$(basename "$mobile_root")/$stale_id"
    fi
  done < <(find "$mobile_root" -mindepth 1 -maxdepth 1 -type d \( -name 'ios-*' -o -name 'ipados-*' \) -print0)
done

write_metadata() {
  local source_pack="$1"
  local cache_pack="$2"
  local pack_id="$3"
  local platform="$4"
  local platform_version="$5"
  local device_class="$6"
  local source_path="$7"
  local display_name_value="$8"
  local image_url="$9"
  local source_page="${10}"
  local source_kind="${11}"

  python3 - "$source_pack" "$cache_pack" "$pack_id" "$platform" "$platform_version" "$device_class" "$source_path" "$display_name_value" "$image_url" "$source_page" "$source_kind" "$RETRIEVED_AT" <<'PY'
import hashlib
import json
import os
import sys

source_pack, cache_pack, pack_id, platform, platform_version, device_class, source_path, display_name, image_url, source_page, source_kind, retrieved_at = sys.argv[1:]

palette_sets = [
    {"background": "#07131D", "panel": "#102432", "panelAlt": "#173B4A", "accent": "#58D5E8", "accentAlt": "#B4F5F5", "secondary": "#286277", "highlight": "#8EE7EF", "text": "#F2FCFF", "muted": "#9DBCC6", "line": "rgba(88,213,232,0.32)"},
    {"background": "#160C1D", "panel": "#29152F", "panelAlt": "#45203E", "accent": "#F28BC4", "accentAlt": "#FFD0E9", "secondary": "#8D4679", "highlight": "#F7B1D7", "text": "#FFF5FB", "muted": "#C6A8BB", "line": "rgba(242,139,196,0.32)"},
    {"background": "#15110A", "panel": "#292014", "panelAlt": "#49351D", "accent": "#F2B95D", "accentAlt": "#FFE7A8", "secondary": "#936A2F", "highlight": "#F5CA82", "text": "#FFF9ED", "muted": "#C4B294", "line": "rgba(242,185,93,0.32)"},
    {"background": "#0D1020", "panel": "#171B34", "panelAlt": "#273266", "accent": "#8EA6FF", "accentAlt": "#D9E0FF", "secondary": "#4E61B3", "highlight": "#B5C3FF", "text": "#F5F7FF", "muted": "#A5AFD0", "line": "rgba(142,166,255,0.32)"},
    {"background": "#08170F", "panel": "#10291C", "panelAlt": "#1B4730", "accent": "#62D7A5", "accentAlt": "#C3F6DD", "secondary": "#307A5A", "highlight": "#90E9BE", "text": "#F0FFF7", "muted": "#9FC2AE", "line": "rgba(98,215,165,0.32)"},
    {"background": "#160B0B", "panel": "#2A1614", "panelAlt": "#4C2520", "accent": "#FF8B69", "accentAlt": "#FFD1C3", "secondary": "#9C4E3D", "highlight": "#FFB19C", "text": "#FFF7F3", "muted": "#CBA9A0", "line": "rgba(255,139,105,0.32)"},
]
palette = palette_sets[int(hashlib.sha256(pack_id.encode()).hexdigest()[:8], 16) % len(palette_sets)]
appearance = "dark" if any(token in display_name.lower() for token in ("dark", "night")) else ("light" if "light" in display_name.lower() else "auto")

if source_kind == "Apple Developer":
    rights_holder = "Apple Inc."
    institution = "Apple Inc."
    source_summary = f"Official Apple {platform} wallpaper published on Apple's WWDC26 wallpaper page, adapted as a local-only Mac direction."
else:
    rights_holder = "Apple Inc. and the respective wallpaper creators"
    institution = "Apple Inc. (archived by SniperGER)"
    source_summary = f"Official Apple {platform} wallpaper artwork preserved in the SniperGER iOS-Wallpapers archive, adapted as a local-only Mac direction."

transformation = "Deterministic center crop to a 2400×1500 16:10 Mac canvas, JPEG encoding, and interface palette mapping only; the original mobile proportions are not displayed directly."
theme = {
    "schemaVersion": 1,
    "id": pack_id,
    "name": display_name,
    "author": rights_holder,
    "description": f"{source_summary} First associated with {platform_version} on {device_class}.",
    "category": platform,
    "collection": f"{platform} · {platform_version}",
    "appearance": appearance,
    "image": "background.jpg",
    "preview": "background.jpg",
    "art": {"focusX": 0.5, "focusY": 0.5, "safeArea": "left", "taskMode": "ambient"},
    "colors": palette,
}
catalog = {
    "schemaVersion": 1,
    "aiGenerated": False,
    "localOnly": True,
    "artist": rights_holder,
    "artworkID": f"apple-{platform.lower()}-{pack_id}",
    "artworkTitle": display_name,
    "category": platform,
    "collection": f"{platform} · {platform_version}",
    "institution": institution,
    "rightsStatus": "Apple copyrighted — local-only",
    "sourceURL": source_page,
    "imageURL": image_url,
    "sourcePath": source_path,
    "platform": platform,
    "platformVersion": platform_version,
    "deviceClass": device_class,
    "retrievedAt": retrieved_at,
    "summary": source_summary,
    "transformation": transformation,
    "distribution": "Not for redistribution without permission from Apple and any respective creators or owners.",
}
license_text = f"""Codex Studio local-only artwork provenance record

Artwork: {display_name}
Platform: {platform} ({platform_version})
Device source: {device_class}
Original archive path: {source_path}
Creator / rights holder: {rights_holder}
Source record: {source_page}
Image URL: {image_url}
Rights status: Apple copyrighted — local-only; not for redistribution without permission
Retrieved: {retrieved_at}

AI-generated imagery: No.
Codex Studio transformation: {transformation}
"""

for destination in (source_pack, cache_pack):
    os.makedirs(destination, exist_ok=True)
    with open(os.path.join(destination, "theme.json"), "w", encoding="utf-8") as handle:
        json.dump(theme, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    with open(os.path.join(destination, "catalog.json"), "w", encoding="utf-8") as handle:
        json.dump(catalog, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    with open(os.path.join(destination, "LICENSE.txt"), "w", encoding="utf-8") as handle:
        handle.write(license_text)
PY
}

prepare_pack() {
  local pack_id="$1"
  local platform="$2"
  local platform_version="$3"
  local device_class="$4"
  local source_path="$5"
  local display_name_value="$6"
  local image_url="$7"
  local source_page="$8"
  local source_kind="$9"
  [[ -n "$pack_id" ]] || return 0
  source_pack="$THEME_PACKS_DIR/$pack_id"
  cache_pack="$CACHE_DIR/$pack_id"
  write_metadata "$source_pack" "$cache_pack" "$pack_id" "$platform" "$platform_version" "$device_class" "$source_path" "$display_name_value" "$image_url" "$source_page" "$source_kind"

  cached_image_url="$(/usr/bin/plutil -extract imageURL raw -o - "$cache_pack/catalog.json" 2>/dev/null || true)"
  if [[ "$REFRESH" == "true" || ! -s "$cache_pack/background.jpg" || "$cached_image_url" != "$image_url" ]]; then
    source_file="$WORK_DIR/source-$pack_id"
    output_file="$cache_pack/.background-$BASHPID.tmp.jpg"
    curl -L --fail --retry 3 --silent --show-error "$image_url" -o "$source_file"
    "$FORMATTER" "$source_file" "$output_file"
    mv "$output_file" "$cache_pack/background.jpg"
    rm -f "$source_file"
    touch "$WORK_DIR/converted-$pack_id"
  fi
}

DOWNLOAD_JOBS="${CODEX_STUDIO_MOBILE_DOWNLOAD_JOBS:-6}"
case "$DOWNLOAD_JOBS" in
  ''|*[!0-9]*|0) DOWNLOAD_JOBS=6 ;;
esac
[[ "$DOWNLOAD_JOBS" -le 8 ]] || DOWNLOAD_JOBS=8

total="$(wc -l < "$MANIFEST_FILE" | tr -d ' ')"
processed=0
batch_count=0
batch_pids=()
while IFS=$'\t' read -r pack_id platform platform_version device_class source_path display_name_value image_url source_page source_kind; do
  [[ -n "$pack_id" ]] || continue
  prepare_pack "$pack_id" "$platform" "$platform_version" "$device_class" "$source_path" "$display_name_value" "$image_url" "$source_page" "$source_kind" &
  batch_pids+=("$!")
  batch_count=$((batch_count + 1))
  if [[ "$batch_count" -ge "$DOWNLOAD_JOBS" ]]; then
    batch_failed=0
    for batch_pid in "${batch_pids[@]}"; do
      wait "$batch_pid" || batch_failed=1
    done
    [[ "$batch_failed" -eq 0 ]] || exit 1
    processed=$((processed + batch_count))
    echo "Prepared $processed/$total mobile Apple wallpaper packs."
    batch_count=0
    batch_pids=()
  fi
done < "$MANIFEST_FILE"

if [[ "$batch_count" -gt 0 ]]; then
  batch_failed=0
  for batch_pid in "${batch_pids[@]}"; do
    wait "$batch_pid" || batch_failed=1
  done
  [[ "$batch_failed" -eq 0 ]] || exit 1
  processed=$((processed + batch_count))
  echo "Prepared $processed/$total mobile Apple wallpaper packs."
fi

downloaded="$(find "$WORK_DIR" -maxdepth 1 -type f -name 'converted-*' -print | wc -l | tr -d ' ')"
echo "Prepared $total local-only iOS/iPadOS wallpaper packs; $downloaded source images converted into 2400×1500 Mac canvases."
echo "Source metadata: $THEME_PACKS_DIR/ios-* and $THEME_PACKS_DIR/ipados-*"
echo "Local cache: $CACHE_DIR"
