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
- [x] Launch at login via `SMAppService` behind the core `LaunchAtLogin` protocol. Verified 2026-08-19 — registered and confirmed in `sfltool dumpbtm` and login items.

Proof: **met in full 2026-08-19.** All four CI jobs green. Notification with a working action round-tripped. Launch at login registered and verified.

> **Known issue, deferred to Phase 7.** The bundle is currently registered for launch-at-login from `/Volumes/2TB/...`. If the external drive is not mounted at login, the app will not start. The build output belongs in `/Applications` for daily use; the repo location is for development only.

## Phase 2 — Core: store and recurrence engine

No interface in this phase. Semantics first, and every line of it portable.

- [x] Storage behind a `Store` protocol. `InMemoryStore` and `SQLiteStore` (raw SQLite C API — GRDB dropped, see design.md). Done 2026-08-19.
- [x] Versioned migrations; `rule`, `activation`, `occurrence` tables with a `UNIQUE(rule_id, date)` constraint making one-deviation-per-day structural. `liturgical_day` lands in Phase 3. Done 2026-08-19.
- [x] `RecurrenceEngine` — pure, deterministic, storage-free. Done 2026-08-19.
- [x] `EditPlanner` returns an `EditPlan` of mutations, applied atomically by `SQLiteStore.apply`. Done 2026-08-19.
- [x] Pause is inclusive of the day it happens; resume opens a fresh stretch and the gap is unscored. Done 2026-08-19.
- [x] `exportJSON` / `importJSON`, round-trip tested across both stores. Done 2026-08-19.
- [ ] Test suite covering:
  - [x] Monthly on the 31st clamps to the last day — all 12 months produce exactly one occurrence
  - [x] Both DST transitions, every day of March/October/November, in three time zones. Nonexistent times refused rather than silently shifted
  - [x] Leap day, including the full Gregorian century rule
  - [x] A rule taken on today invents no history behind it
  - [x] A paused stretch is absent from the due set entirely
- [x] CI runs the suite on macOS and Linux. 51 tests. Done 2026-08-19.

Proof: **met 2026-08-19.** 51 tests green on macOS and Linux.

## Phase 3 — Core: liturgical layer

- [x] `Jurisdiction` — name plus reckoning, defaulting to Julian, with a non-authoritative list of common jurisdictions. Done 2026-08-19.
- [x] `OrthocalClient` behind an `HTTPFetching` seam, `FoundationNetworking` imported conditionally for Linux. Done 2026-08-19.
- [x] `LiturgicalService.refresh` fetches the window and skips what is already held. Done 2026-08-19.
- [x] Cache-first, with an in-memory snapshot so `LiturgicalDayProvider` stays **synchronous** — the recurrence engine never awaits. `refresh` never throws; failure sets `isOffline` for the interface to reflect. Done 2026-08-19.
- [x] Liturgical recurrence types: fast days, seasons, great feasts — gated on `ObservanceSettings`, done 2026-08-19 in Phase 2.
- [x] `LiturgicalService` conforms to `LiturgicalDayProvider`, driving liturgical recurrences from cached data. Done 2026-08-19.
- [x] **Improved on the plan:** switching re-targets rather than deleting. A cached Julian day stays a correct Julian day, so switching back costs no requests. `clearLiturgicalCache` remains for a manual refresh. Done 2026-08-19.
- [x] Ten recorded fixtures in the test bundle. The suite makes no network request. Done 2026-08-19.

Proof: **met 2026-08-19.** 13 Jan 2027 decodes fast-free (Leavetaking of the Nativity) on the Old Calendar and a fast on the New. Offline refresh returns nothing, throws nothing, and cached days still answer. 71 tests green on macOS and Linux.

> Discovered building this: the API takes a **civil** date in the URL but reports the date in the requested reckoning in the body — `/api/julian/2027/1/13/` answers with 31 December 2026. The cache is keyed on the civil date; keying on the reported date would misfile every Old Calendar day by thirteen days.

## Phase 4 — Core: scheduling

- [x] `Scheduler` — pure, no sleeping, no platform. Done 2026-08-19.
- [x] 10-minute lead for timed rules, exempt from quiet hours by design. Done 2026-08-19.
- [x] Up to four reminders for untimed rules, spread across the waking day by default; `ReminderPolicy.hourly` keeps the original cadence. Done 2026-08-19.
- [x] Quiet hours, default 21:30–06:30, applied to unsolicited repetition only. Done 2026-08-19.
- [x] `Notifier` protocol with `supportsActions`, defined in Phase 1 and driven by the scheduler. Done 2026-08-19.
- [x] `cancellationIDs` covers every reminder armed for a day; completed, late, skipped, cancelled, moved and archived all silence it. Done 2026-08-19.
- [x] `Clock` protocol with `FixedClock`; the whole suite runs in milliseconds with no desktop. Done 2026-08-19.

Proof: **met 2026-08-19.** A simulated August produces 31 morning reminders, 5 Sunday Liturgy reminders, 124 untimed reminders, and not one inside the quiet window. 112 tests green on macOS and Linux.

## Phase 4b — Education (core done, interface pending)

- [x] `GlossaryEntry`, `Glossary` index, category browsing, ranked search. 49 entries covering everything the app displays. Done 2026-08-19.
- [x] `Glossary.scan` — longest-match, word-boundary, non-overlapping term detection over arbitrary text. Done 2026-08-19.
- [x] Cross-references tested to resolve, so the pane can never show a dead link. Done 2026-08-19.
- [ ] Education pane: slides over from wherever a term was tapped, with a way back.
- [ ] Browse by category and search within the pane.
- [ ] Terms rendered as tappable in the reading tab, the calendar, and the day's fast description.
- [ ] **[manual]** Have a priest read the glossary content. It is introductory, not authoritative.

## Phase 4c — Reminder controls (core done, interface pending)

- [x] Master switch for notifications. Done 2026-08-19.
- [x] Per-rule enable/disable, independent of whether the rule is scored. Done 2026-08-19.
- [x] Lead times: at the time, 10 / 30 minutes, 1 / 2 hours, the evening before. Done 2026-08-19.
- [x] Several leads on one rule, each with its own id; cancellation covers all of them. Done 2026-08-19.
- [x] Schema migration v3, with the upgrade path tested against a database built as version 2. Done 2026-08-19.
- [ ] Settings interface for the master switch and the default lead.
- [ ] Per-rule reminder controls in the add and edit sheets.

## Phase 5 — macOS interface

- [ ] Popover, 380–420pt, three-tab chrome.
- [ ] Month grid with fast and feast shading, today marked.
- [ ] Today's list with completion.
- [ ] Add and edit sheets, including note and source fields.
- [ ] Rule library with per-rule toggles, grouped by category, nothing on by default.
- [ ] Observance settings: fasting and feasts each hidden / shown / observed, three plain options with no justification prompt.
- [ ] Fasting shown as description, never instruction — "the calendar marks this as a strict fast", never "do not eat…".
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
