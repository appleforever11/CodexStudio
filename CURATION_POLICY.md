# Codex Studio theme curation policy

Codex Studio's curated library contains human-created artwork with a traceable source and redistribution status. AI-generated imagery and procedurally mass-produced gallery filler are not accepted.

## Required package records

Every newly curated theme directory must contain:

- `theme.json` — the runtime theme and deterministic interface palette;
- `background.jpg`, `background.png`, or `background.webp` — the rights-cleared artwork presentation;
- `catalog.json` — structured artwork metadata with `schemaVersion: 1`, `aiGenerated: false`, creator, source URL, institution, collection, category, and rights status;
- `LICENSE.txt` — a human-readable record of the same provenance, including the original image URL and retrieval date.

The app only grants the Curated badge when `catalog.json` states that the work is not AI-generated, the rights status is Public Domain or CC0, a source URL is present, and `LICENSE.txt` exists. The build script applies the same gate before copying a pack into a release app bundle or DMG. A pack with `localOnly: true` is excluded by default; a deliberate maintainer override may include it in a user-directed offline release while retaining its provenance and attribution record.

## Allowed automation

Deterministic image cropping, resizing, palette extraction, contrast adjustment, and Codex interface-token generation are allowed. These operations may present the artwork as a desktop theme, but they must not invent a new image, erase authorship, or imply that Codex Studio created the underlying artwork.

## Legacy themes

Legacy or user-imported themes may remain usable in a private local library. Until their artwork provenance and redistribution rights are verified, they are labeled `Local · Provenance unverified` and are excluded from release builds.
