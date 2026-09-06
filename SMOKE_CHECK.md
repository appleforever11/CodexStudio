# Codex Studio smoke check

Run the relevant automated commands in [AGENTS.md](AGENTS.md), then exercise the affected scenarios below when runtime verification is required. Use the project's staged app rather than a bare GUI executable. Preserve user data and existing installations.

1. Stage a development bundle using the existing script; record the actual path and bundle version.
2. Inspect Canvas, Explore, release filtering, Favorites, Live editor, and Settings at ordinary and narrow window sizes. Check sidebar/footer reachability and image clipping.
3. Change a preview control and refresh the catalog: verify the draft survives. Restore temporary preview choices.
4. For changes to Apply/Restore, use a deliberate test theme and verify the actual Codex result and restoration. Do not exercise these external app mutations for an unrelated documentation or layout check.
5. For runtime-source edits, verify the packaged/installed runtime identity before testing; a cached runtime can hide changes.

Record date, Git revision plus any dirty state, bundle path/version, relevant test result, interactions actually observed, and any blocker. Use sanitized screenshots where useful. A process/signature check alone is not UI proof.
