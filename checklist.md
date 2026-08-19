# chotki — build checklist

Ordering principle: **de-risk before you invest, and keep the port cheap.**

Two things get proven before features are built on them. First, that a notification with actions actually delivers from an ad-hoc-signed bundle. Second, that `core/` compiles and tests on Linux — because a portable core that is never built on another platform is not portable, it is only intended to be.

Marked **[manual]** where a step needs a human — a decision, a system permission, or an account.

---

## Phase 0 — Prerequisites

- [x] Verify SwiftUI + UserNotifications compile against Command Line Tools only. Confirmed 2026-08-19, SDK 15.5, MenuBarExtra probe built clean. Xcode not needed.
- [x] Verify orthocal.info is reachable and returns usable JSON for both reckonings. Confirmed 2026-08-19.
- [x] Choose project location and split personal context out of the repo.
- [x] `brew install gh` (2.97.0), `gh auth login`. Done 2026-08-19.
- [x] Git identity set repo-locally. Done 2026-08-19.
- [ ] **[manual]** Confirm which reckoning your parish keeps. Julian is the default, so for most Orthodox this is confirmation rather than a change.
- [x] `git init`, first commit, pushed to https://github.com/Orthobro83/chotki (public, MIT). Done 2026-08-19.

## Phase 1 — Foundations, and two spikes

Both spikes come first. Do not build on an unproven assumption.

- [x] SwiftPM workspace: `core/` package, `macos/` executable depending on it. Done 2026-08-19.
- [x] `macos/build-app.sh` — bundle, `Info.plist`, bundle ID `info.chotki.app`, `LSUIElement` true. Done 2026-08-19.
- [x] Ad-hoc code signing, verified by `codesign --verify`. Done 2026-08-19.
- [x] **SPIKE A PASSED** 2026-08-19. Authorization granted, notification delivered, and the "Mark complete" action called back through the core `Notifier` protocol. Ad-hoc signing is sufficient; no Developer ID needed for personal use.
- [x] **[manual]** Notification permission granted. Done 2026-08-19.
- [x] **SPIKE B PASSED** 2026-08-19. `core/` builds and tests on `swift:6.1` Linux in 43s. A `portability-guard` job greps `core/` for Apple-only imports and was verified to fail when an `import AppKit` was planted.
- [x] Eight-pointed cross drawn programmatically as a template `NSImage` — no asset pipeline, correct inversion in dark menu bars. Done 2026-08-19.
- [~] Launch at login implemented via `SMAppService` behind the core `LaunchAtLogin` protocol. **[manual]** Not yet exercised — click the toggle in the spike popover to confirm.

Proof: **met 2026-08-19.** All four CI jobs green (core-Linux, core-macOS, portability-guard, macOS app bundle). Notification with a working action round-tripped. Launch at login still to be exercised by hand.

## Phase 2 — Core: store and recurrence engine

No interface in this phase. Semantics first, and every line of it portable.

- [ ] Storage behind a repository protocol. GRDB as the macOS implementation.
- [ ] Migrations, the four tables from design.md.
- [ ] Recurrence expansion across a date range, intersected with activation periods.
- [ ] The three-way edit: this day only / this and future / whole series.
- [ ] Pause and resume as activation-period operations.
- [ ] JSON export for backup.
- [ ] Test suite covering:
  - [ ] Monthly on the 31st, in a 30-day month, and in February
  - [ ] Both DST transitions — a 06:30 task must stay 06:30
  - [ ] 29 February, and a rule created on it
  - [ ] A rule enabled today generating no history before its first activation
  - [ ] A paused stretch scoring as skipped, never as missed
- [ ] CI runs this suite on macOS AND Linux. Both must be green.

Proof: the suite passes on both platforms.

## Phase 3 — Core: liturgical layer

- [ ] `Jurisdiction` setting: name, reckoning, endpoint. Default Julian.
- [ ] orthocal client for both endpoints, using Foundation networking only.
- [ ] 14-day prefetch into `LiturgicalDay`, background refresh.
- [ ] Cache-first reads. Offline fallback shows cached content marked as cached — never a spinner, never an error where text should be.
- [ ] Liturgical recurrence types: fast days, seasons, great feasts.
- [ ] Cache invalidation on jurisdiction change.
- [ ] Tests run against recorded fixtures, not the live API, so CI is offline and deterministic.

Proof: correct fast level for 13 Jan 2027 under each reckoning (New = strict fast, Old = fast-free). Full function with the network off. Green on Linux.

## Phase 4 — Core: scheduling

- [ ] In-process scheduler: computes what is due, when to warn, when to repeat.
- [ ] 10-minute lead for timed rules.
- [ ] Hourly repeat for untimed rules, capped at four.
- [ ] Quiet hours, default 21:30–06:30.
- [ ] `Notifier` protocol with an actions capability flag, so a platform without action support degrades to a plain notification rather than losing the reminder.
- [ ] Cancel pending notifications for an occurrence on completion; reschedule on rule edit, pause, or archive.
- [ ] Tested with an injected clock — no sleeping, no real time, runs headless in CI.

Proof: a simulated month of ticks produces the right notifications at the right moments, on Linux, with no desktop present.

## Phase 5 — macOS interface

- [ ] Popover, 380–420pt, three-tab chrome.
- [ ] Month grid with fast and feast shading, today marked.
- [ ] Today's list with completion.
- [ ] Add and edit sheets, including note and source fields.
- [ ] Rule library with per-rule toggles, grouped by category, nothing on by default.
- [ ] Right-click quick menu.
- [ ] Optional old-style date line.
- [ ] macOS `Notifier` implementation wired to the core scheduler.

Proof: a rule can be taken on, kept, edited, paused, and resumed entirely through the interface; completing from a banner clears the pending reminders.

## Phase 6 — Core + interface: progress

- [ ] Scoring over activation-intersected occurrences.
- [ ] 30-day weighting with decay.
- [ ] Per-rule streaks.
- [ ] Prose summary generator — which rules slipped, on which weekdays, whether a pattern is visible.
- [ ] Report view, detachable into a window.
- [ ] Setting to hide the number and keep prose only.

Proof: a paused stretch leaves the score unmoved; a rule enabled today reports no prior misses.

## Phase 7 — Reading tab and polish

- [ ] Commemoration, tone, readings with passage text.
- [ ] Cached-state marker.
- [ ] Bundled public-domain patristic texts (Nicene & Post-Nicene Fathers), one per day.
- [ ] First-run onboarding: pick two or three rules, not twelve.
- [ ] Prayer rope counter — 33/50/100 presets, click or spacebar.
- [ ] **[manual]** Walk a clean install end to end, from first launch to first kept rule.

Proof: clean install to first kept rule, walked end to end.

## Later — the port

Not scheduled. Listed so the shape is known while macOS is being built.

- Windows: WinUI or Win32 tray, ICO icon, toast notifications with actions, `LaunchAtLogin` via registry Run key.
- Linux: GTK tray via StatusNotifierItem, libnotify, `.desktop` autostart entry. GNOME needs a shell extension for any tray app — a platform limitation, not something the stack choice can fix.
- Everything in `core/` is expected to be reused unchanged. Anything that is not, is a bug in the core/UI boundary.
