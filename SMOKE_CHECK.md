# Codex Studio smoke check

Run the relevant automated commands in [AGENTS.md](AGENTS.md), then exercise the affected scenarios below when runtime verification is required. Use the project's staged app rather than a bare GUI executable. Preserve user data and existing installations.

1. Stage a development bundle using the existing script; record the actual path and bundle version.
2. Inspect Canvas, Explore, release filtering, Favorites, Live editor, and Settings at ordinary and narrow window sizes. Check sidebar/footer reachability and image clipping.
3. Change a preview control and refresh the catalog: verify the draft survives. Restore temporary preview choices.
4. For changes to Apply/Restore, use a deliberate test theme and verify the actual Codex result and restoration. Do not exercise these external app mutations for an unrelated documentation or layout check.
5. For runtime-source edits, verify the packaged/installed runtime identity before testing; a cached runtime can hide changes.

Record date, Git revision plus any dirty state, bundle path/version, relevant test result, interactions actually observed, and any blocker. Use sanitized screenshots where useful. A process/signature check alone is not UI proof.

Workspace appearance checks (1.9.14+):
- Compare left glass and right summary, including sticky headers, with light and dark artwork.
- Settings > General and Live editor: adjust each surface independently, Apply,
  Undo, and verify a failed apply restores the prior settings. Preview controls
  must survive library refresh. Check the card at narrow widths.
- Scroll away while content arrives, confirm the same text stays visible, and
  use Return to latest. Focus the composer and switch chats; reading protection
  must not fight either action. Repeat with normal and reverse scroll layouts.
- Search, open a result, inspect loaded-text highlighting, then Back to results.
  Preserve native project/excerpt metadata; missing dates must stay missing.
- Toggle Reading view twice, then pause/reapply the theme. Owned controls,
  highlights, response tags, and listeners must clean up without duplicates.
- Before a major regression recovery, verify the pinned restore manifest.
  Record both the restored runtime and the subsequent active version; never
  replay the backup's old process IDs.
