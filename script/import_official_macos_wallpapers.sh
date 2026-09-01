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
SOURCE_PAGE="https://512pixels.net/projects/default-mac-wallpapers-in-5k/"
RETRIEVED_AT="${CODEX_STUDIO_RETRIEVED_AT:-$(date +%F)}"
REFRESH="${CODEX_STUDIO_REFRESH_OFFICIAL_WALLPAPERS:-false}"
WORK_DIR="$(mktemp -d /tmp/codexstudio-official-wallpapers.XXXXXX)"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$CACHE_DIR"

# The archive preserves the official Apple release artwork while making the
# historical files available without requiring old macOS installers. These
# packs remain local-only because the underlying artwork is Apple-copyrighted.
while IFS='|' read -r pack_id os_version release_name artwork_title asset_name image_url; do
  [[ -n "$pack_id" ]] || continue
  source_pack="$THEME_PACKS_DIR/$pack_id"
  cache_pack="$CACHE_DIR/$pack_id"
  [[ -d "$source_pack" ]] || {
    echo "Theme pack is missing: $source_pack" >&2
    exit 1
  }

  mkdir -p "$cache_pack"
  if [[ "$REFRESH" == "true" || ! -s "$cache_pack/background.jpg" ]]; then
    source_file="$WORK_DIR/$asset_name"
    converted_file="$WORK_DIR/$pack_id.jpg"
    curl -L --fail --retry 3 --silent --show-error "$image_url" -o "$source_file"
    sips -s format jpeg -s formatOptions 84 -Z 2400 "$source_file" --out "$converted_file" >/dev/null
    mv "$converted_file" "$cache_pack/background.jpg"
  fi

  python3 - "$source_pack" "$cache_pack" "$pack_id" "$os_version" "$release_name" "$artwork_title" "$image_url" "$SOURCE_PAGE" "$RETRIEVED_AT" <<'PY'
import json
import os
import sys

source_pack, cache_pack, pack_id, os_version, release_name, artwork_title, image_url, source_page, retrieved_at = sys.argv[1:]

theme_path = os.path.join(source_pack, "theme.json")
with open(theme_path, "r", encoding="utf-8") as handle:
    theme = json.load(handle)

theme["id"] = pack_id
theme["name"] = release_name
theme["author"] = "Apple Inc. / original wallpaper creators"
theme["description"] = f"The official Apple wallpaper associated with {release_name}, presented as a local-only Codex direction."
theme["category"] = "macOS Era"
theme["collection"] = f"macOS · {release_name} {os_version}"
theme["image"] = "background.jpg"
theme["preview"] = "background.jpg"

catalog = {
    "schemaVersion": 1,
    "aiGenerated": False,
    "localOnly": True,
    "artist": "Apple Inc. / original wallpaper creators",
    "artworkID": f"apple-macos-{os_version}",
    "artworkTitle": artwork_title,
    "category": "macOS Era",
    "collection": f"macOS Era · {release_name} {os_version}",
    "institution": "Apple Inc. (archived by 512 Pixels)",
    "rightsStatus": "Apple copyrighted — local-only",
    "sourceURL": source_page,
    "imageURL": image_url,
    "retrievedAt": retrieved_at,
    "summary": f"The official Apple wallpaper associated with {release_name}, archived by 512 Pixels and stored locally for personal use in Codex Studio.",
    "transformation": "Deterministic downscale to 2400px, JPEG encoding, and interface palette mapping only.",
    "distribution": "Not for redistribution without permission from Apple and any respective creators or owners.",
}

license_text = f"""Codex Studio local-only artwork provenance record

Artwork: {artwork_title}
Release: {release_name} {os_version}
Creator / rights holder: Apple Inc. and the original wallpaper creators
Archive record: {source_page}
Image URL: {image_url}
Rights status: Apple copyrighted — local-only; not for redistribution without permission
Retrieved: {retrieved_at}

AI-generated imagery: No.
Codex Studio transformation: deterministic downscale to 2400px, JPEG encoding, and interface palette mapping only.
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

  echo "Prepared local Apple wallpaper: $release_name $os_version"
done <<'ENTRIES'
macos-cheetah-night-grid|10.0|Cheetah|Cheetah & Puma Aqua arcs|10-0_10-1-6k.jpg|https://media.512pixels.net/downloads/macos-wallpapers-6k/10-0_10-1-6k.jpg
macos-puma-desert-bloom|10.1|Puma|Cheetah & Puma Aqua arcs|10-0_10-1-6k.jpg|https://media.512pixels.net/downloads/macos-wallpapers-6k/10-0_10-1-6k.jpg
macos-jaguar-amazon-green|10.2|Jaguar|Jaguar Aqua trails|10-2-6k.jpg|https://media.512pixels.net/downloads/macos-wallpapers-6k/10-2-6k.jpg
macos-panther-ink-cut|10.3|Panther|Panther Aqua curves|10-3-6k.jpg|https://media.512pixels.net/downloads/macos-wallpapers-6k/10-3-6k.jpg
macos-tiger-amber-storm|10.4|Tiger|Tiger Aqua bloom|10-4-6k.jpg|https://media.512pixels.net/downloads/macos-wallpapers-6k/10-4-6k.jpg
macos-leopard-quiet-menagerie|10.5|Leopard|Leopard galaxy field|10-5-6k.jpg|https://media.512pixels.net/downloads/macos-wallpapers-6k/10-5-6k.jpg
macos-snow-leopard-polar-light|10.6|Snow Leopard|Snow Leopard starscape|10-6-6k.jpg|https://media.512pixels.net/downloads/macos-wallpapers-6k/10-6-6k.jpg
macos-lion-sunlit-pride|10.7|Lion|Lion Andromeda galaxy|10-7-6k.jpg|https://media.512pixels.net/downloads/macos-wallpapers-6k/10-7-6k.jpg
macos-mountain-lion-high-range|10.8|Mountain Lion|Mountain Lion Andromeda galaxy|10-8-6k.jpg|https://media.512pixels.net/downloads/macos-wallpapers-6k/10-8-6k.jpg
macos-mavericks-deep-tide|10.9|Mavericks|Mavericks wave|10-9-6k.jpg|https://media.512pixels.net/downloads/macos-wallpapers-6k/10-9-6k.jpg
macos-yosemite-glacier-valley|10.10|Yosemite|Yosemite mountain valley|10-10-6k.jpg|https://media.512pixels.net/downloads/macos-wallpapers-6k/10-10-6k.jpg
macos-el-capitan-granite|10.11|El Capitan|El Capitan granite ridge|10-11-6k.jpg|https://media.512pixels.net/downloads/macos-wallpapers-6k/10-11-6k.jpg
macos-sierra-blue-lake|10.12|Sierra|Sierra mountain lake|10-12-6k.jpg|https://media.512pixels.net/downloads/macos-wallpapers-6k/10-12-6k.jpg
macos-high-sierra-snow-forest|10.13|High Sierra|High Sierra mountain range|10-13-6k.jpg|https://media.512pixels.net/downloads/macos-wallpapers-6k/10-13-6k.jpg
macos-mojave-desert-field|10.14|Mojave|Mojave desert day|10-14-Day-6k.jpg|https://media.512pixels.net/downloads/macos-wallpapers-6k/10-14-Day-6k.jpg
macos-catalina-night-island|10.15|Catalina|Catalina island day|10-15-Day-6k.jpg|https://media.512pixels.net/downloads/macos-wallpapers-6k/10-15-Day-6k.jpg
macos-big-sur-coastal-film|11|Big Sur|Big Sur colorful day|11-Big-Sur-Color-Day-6k.jpg|https://media.512pixels.net/downloads/macos-wallpapers-6k/11-Big-Sur-Color-Day-6k.jpg
macos-monterey-water-signal|12|Monterey|Monterey graphic light|12-Monterey-Light.jpg|https://media.512pixels.net/downloads/macos-wallpapers-6k/12-Monterey-Light.jpg
macos-ventura-marine-layer|13|Ventura|Ventura graphic light|13-Ventura-Light.jpg|https://media.512pixels.net/downloads/macos-wallpapers-6k/13-Ventura-Light.jpg
macos-sonoma-field-grid|14|Sonoma|Sonoma graphic light|14-Sonoma-Light.jpg|https://media.512pixels.net/downloads/macos-wallpapers-6k/14-Sonoma-Light.jpg
macos-sequoia-redwood-atlas|15|Sequoia|Sequoia light|15-Sequoia-Light-6K.jpg|https://media.512pixels.net/downloads/macos-wallpapers-6k/15-Sequoia-Light-6K.jpg
macos-tahoe-clear-water|26|Tahoe|Tahoe light|26-Tahoe-Light-6K.png|https://media.512pixels.net/downloads/macos-wallpapers-6k/26-Tahoe-Light-6K.png
macos-golden-gate-amber-bridge|27|Golden Gate|Golden Gate light|27-Golden-Gate.png|https://media.512pixels.net/downloads/macos-wallpapers-6k/27-Golden-Gate.png
ENTRIES
