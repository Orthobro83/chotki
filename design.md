# chotki — Design

A menu bar app for keeping an Orthodox prayer rule, and honestly measuring whether it is kept.

Status: design complete. No code written yet.
Started 2026-08-19.

## The problem

A calendar app tells you what is scheduled. It does not tell you what you actually kept, and mixing a prayer rule into a work calendar buries it. The product insight: the value is not the schedule, it is the honest record of consistency over months — recorded in a way that does not turn the practice into a scoreboard.

The rule is expected to be built up piecemeal over a long period, with tasks arriving from other people. Nothing may assume a fixed or complete set of tasks.

## Fixed facts

- Single user, single machine. Local storage only, no account, no sync, no telemetry.
- macOS 13+ first (MenuBarExtra requires it). Swift 6.1.2. Windows and Linux planned.
- Xcode is NOT installed and is NOT needed. Command Line Tools SDK 15.5 compiles SwiftUI + UserNotifications cleanly (verified 2026-08-19 with a MenuBarExtra probe target). Build with SwiftPM, assemble the .app bundle by script, sign ad-hoc.
- Repository: https://github.com/Orthobro83/chotki — public, MIT, branch `main`. Personal context lives in `context.local.md`, which is gitignored and must never be committed.
- Liturgical data source: `orthocal.info` — free public JSON API, no key. `/api/julian/YYYY/M/D/` for Old Calendar, `/api/gregorian/YYYY/M/D/` for New. Returns tone, commemorations, feast level, fast level, abstentions, and full scripture passage text. It is the only network call the app makes.

## Calendar facts (settled 2026-08-19, worth not re-deriving)

- Julian vs Gregorian reckoning does NOT affect days of the week. Wednesday is Wednesday in every jurisdiction. The Wed/Fri fast rhythm never moves.
- Nearly all Orthodox churches, New Calendar included, compute Pascha on the Julian reckoning. So the movable cycle — Pascha, Great Lent, Pentecost, Apostles' Fast — is IDENTICAL for Old and New Calendar churches. Only fixed feasts differ, by 13 days.
- Consequence: disagreement between reckonings is concentrated around Nativity and Theophany, not scattered through the year. Verified example — Wednesday 13 Jan 2027 is a strict fast on the New Calendar and fast-free (Leavetaking of the Nativity) on the Old.
- Adherents by reckoning, nominal: Julian ~110M (Russian ~100M, Serbian ~8M, Georgian ~3.5M, Jerusalem, Polish) against Revised Julian ~47M (Romanian ~18M, Greek ~10M, Ukrainian OCU ~7M, Bulgarian ~6M, Constantinople, Antiochian, Cypriot, Albanian). Figures are soft, but the Russian Church alone outweighs all Revised Julian churches combined, so the ordering is robust.
- The app always DISPLAYS civil Gregorian dates — the same grid as a wall calendar. Reckoning is a lookup layer, never a display layer.

## Decisions

### Platform and portability

- 2026-08-19 — macOS first with SwiftUI, Windows and Linux to follow. Chosen over Tauri and Electron for time-to-usable; the portability cost is paid by the core/UI split below rather than by the framework.
- 2026-08-19 — `core/` is a pure SwiftPM package importing ONLY Foundation and SQLite. No AppKit, no SwiftUI, no UserNotifications, no SMAppService, no Apple-only API of any kind. Swift compiles on Windows and Linux; SwiftUI does not. This is what makes the port a UI rewrite rather than an app rewrite.
- 2026-08-19 — Core test suite runs on Linux in CI from Phase 2, before any Linux app exists. Portability that is not tested rots silently; this makes an Apple-only import fail loudly the day it is added.
- 2026-08-19 — Platform services sit behind protocols DEFINED in core and IMPLEMENTED per platform: `Notifier` (show a notification, offer actions), `LaunchAtLogin`, `TrayPresenter`.
- 2026-08-19 — Scheduling lives in core, not in the OS. The app is tray-resident and always running, so an in-process scheduler decides WHEN and the platform `Notifier` only SHOWS. This is portable, testable without a running desktop, and removes any dependency on `UNUserNotificationCenter` scheduling behaviour.
- 2026-08-19 — GRDB is acceptable for the macOS build but sits behind a repository protocol, so the storage layer can be swapped if GRDB proves awkward on Windows.
- 2026-08-19 — No date FORMATTING in core. Core returns dates and values; presentation belongs to the UI layer, which differs per platform anyway.

### Product

- 2026-08-19 — Named `chotki` (the prayer rope).
- 2026-08-19 — Default reckoning is Julian, on adherent numbers rather than on any one jurisdiction. Fully configurable.
- 2026-08-19 — Jurisdiction is a setting `{ name, reckoning, endpoint }`; every date-aware surface reads through it. Switching invalidates the cache and refetches; no other code reacts.
- 2026-08-19 — Nothing ships switched on. Bundled rules are a library taken from one at a time. First launch invites two or three, not twelve.
- 2026-08-19 — Enabling a template COPIES it into the user's rule. It does not stay linked. A rule written from scratch is structurally identical to one taken from the library.
- 2026-08-19 — Every rule carries an optional `note` and `source` — who suggested it and why. Rules arrive from other people over months; their origin matters later.
- 2026-08-19 — Tasks carry a LIST of activation periods, not an on/off flag. This one structure gives enable-later, pause-without-penalty, resume, and seasonal rules for free.
- 2026-08-19 — Pausing excludes those days from scoring (`skipped`), never counts them as missed. Deleting archives and preserves history. Nothing the user actually did is ever destroyed.
- 2026-08-19 — Scoring counts only occurrences whose due time has passed AND that fall inside an activation period. Weighted to the last 30 days; older days decay but never vanish. `completedLate` scores partial, not zero.
- 2026-08-19 — The progress report leads with prose, then the figure. A setting hides the number entirely. No red, no "failed", no broken-streak shaming. This is a deliberate constraint — see `context.local.md`.
- 2026-08-19 — Untimed tasks nag hourly, bounded by quiet hours (default 21:30–06:30) and a cap of four, then go quiet and land in the report.
- 2026-08-19 — Notifications carry mark-complete and snooze actions. Completing from the banner matters more for adherence than the score does. Linux notification daemons vary in action support, so the UI must degrade to a plain notification without losing the reminder.
- 2026-08-19 — Store all-day dates as calendar dates, never timestamps. A timestamp shifts a day under DST and the bug surfaces months later.
- 2026-08-19 — Editing/deleting a repeating rule always offers three choices: this day only, this and future, whole series. This determines the schema; retrofitting it is a rewrite.
- 2026-08-19 — Reading tab prefetches 14 days ahead and caches. The app never blocks on the network and never shows a spinner where text should be.
- 2026-08-19 — Saint quotes ship as a bundled local file of public-domain patristic text (Nicene & Post-Nicene Fathers). Philokalia translations are still in copyright; scraping is brittle and unnecessary.

## Repository layout

    core/            pure SwiftPM package — Foundation + SQLite only
      Model/         Rule, Activation, Occurrence, LiturgicalDay
      Recurrence/    expansion, activation intersection, the three-way edit
      Scoring/       weighting, streaks, prose summary generation
      Liturgical/    orthocal client, cache, jurisdiction
      Scheduling/    in-process scheduler; Notifier protocol
      Platform/      LaunchAtLogin, TrayPresenter protocols
    macos/           SwiftUI menu bar app — the only Apple-specific code
    .github/         CI: build + test core on macOS AND Linux

## Data model

Four tables, SQLite.

    Rule
      id, title, note, source
      recurrence      -- daily | weekly(days) | monthly(day)
                      -- | liturgical(season | fastDay | feast)
      timeOfDay: Time?   -- nil means "anytime today"
      category, createdAt, archivedAt

    Activation         -- many per rule; this is the pause mechanism
      ruleId, from: Date, to: Date?    -- nil `to` means currently in force

    Occurrence         -- written ONLY on deviation from default
      ruleId, date: CalendarDate
      status: completed | completedLate | skipped | moved | cancelled
      completedAt: Date?

    LiturgicalDay      -- cache, keyed by (date, reckoning)
      date, reckoning, fastLevel, fastException, abstentions
      feastLevel, commemorations, readings, fetchedAt

Everything else is computed. A day with no Occurrence row and a covering Activation is simply due — or, once its time has passed, missed. Absence is the default state, not a record.

## Interface

- Left click opens the popover (380–420pt wide). Right click gives a quick menu: mark next task done, snooze, open progress, quit.
- Menu bar icon is an eight-pointed Orthodox cross supplied as a TEMPLATE image so macOS inverts it in both menu bar appearances. Windows will need an ICO; Linux needs themed icons and, on GNOME, a shell extension — a platform limitation, not a stack choice.
- Three tabs. **Rule** — month grid plus today's list. **Reading** — the day's commemoration and scripture. **Progress** — the report, which can also open detached into a proper window.
- Palette: deep charcoal ground, byzantine gold for today and for completion, muted violet for fasting seasons, ochre red for liturgy days. Restraint is the point; ornament reads as kitsch at 12pt.
- Optional secondary date line — "19 August · 6 August o.s." — so a parish bulletin and a wall calendar can be reconciled at a glance.

## Out of scope for v1

- iCloud or cross-device sync. Store is local; backup is JSON export.
- Any network call other than orthocal. No analytics, no account, no telemetry.
- A mobile companion.
- Notarisation and store distribution. Ad-hoc signed.
- Multiple profiles or households.

## Open questions

- Quiet hours default 21:30–06:30 — should the window shift if morning prayers are set earlier?
- Should a great feast propose a Liturgy task automatically, or wait behind a prompt?
