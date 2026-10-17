# ChatGPT 26.1013.31256 compatibility review

Inspected the signed application at `/Applications/ChatGPT.app` on October 16,
2026, through its packaged ASAR assets. Native application files were not changed.

The thread scroll layout now calls a shared background component with separate
surface and fade parts. `app-initial-3ccf4886957f.js` emits inert `aria-hidden`
CSS-module `_background_` / `_fade_` nodes; its stylesheet owns the gradient,
so the previous utility-class selectors do not match. Runtime 1.9.25 scopes
the transparency override to that inert background within the thread layout.
The browser fixture includes separate and combined variants, verifies geometry
is retained, and confirms unrelated fade nodes keep their background.

The packaged main-surface, header-edge-scroll, composer-body, composer-surface,
composer-radius, composer-utility-bar and Home rail-placement contracts remain
present. The old home-utility-bar-position marker is absent; existing rail rules
use the current rail-placement marker. No further selector change was justified
by this static review. This is packaged-code evidence, not proof of every live
route or feature-flag combination.

This release also includes the locally completed native mode-label and Home rail
corrections since 0.1.29. The runtime version advances from 1.9.24 to 1.9.25;
Studio installs only newer runtime versions and refreshes its build mirror when
that manifest changes. Keeping 1.9.24 would strand published CSS changes.

Computer Use denied live inspection of `com.openai.codex`; no alternate UI
access route was used. The actual ChatGPT window still needs user verification.
