# Changelog

All notable changes to Pifagor Switcher are documented here.

## v0.2.0 - 2026-04-28

Reliability-focused live correction release.

- Added conservative live correction after a short 160ms idle pause.
- Added a separate high-confidence live threshold to avoid aggressive replacements.
- Added cancellation of pending live checks on Backspace, word boundary, Enter, Escape, cursor movement, mouse clicks, and app changes.
- Hardened the detector against technical tokens: URLs, emails, paths, snake_case, kebab-case, camelCase, and acronyms.
- Added known-word and known-prefix protection for live typing, including developer and marketing terms like GitHub.
- Added a Live autocorrection setting, enabled by default.
- Expanded diagnostics with live correction state and the last correction skip reason.

## v0.1.0 - 2026-04-28

Initial public tester release.

- Native macOS menu-bar app for local RU/EN layout switching.
- Conservative wrong-layout correction for the last word before Enter.
- Manual phrase correction with double Control.
- Selected text correction with double Control or double Shift.
- App and URL rules for input source switching.
- App correction modes: normal, manual-only, and disabled.
- Local adaptive lexicon with ignored words, learned corrections, import, and export.
- Double-capital correction like `WOrd -> Word` and `ПРивет -> Привет`.
- Permission onboarding for Accessibility and Input Monitoring.
- Diagnostics window for permissions, event tap state, current layout, app mode, and conflicts.
- Pifagor Apps branding, app icon, and menu-bar icon.
