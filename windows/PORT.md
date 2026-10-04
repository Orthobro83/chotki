# Windows migration roadmap

2026-10-03. Target: Windows 11 x86_64. Current stage: native Win32 Home/calendar/reading milestone
implemented and compiled as AMD64. Current macOS is the design and behavior
reference; full parity is the release gate and ARM64 remains deferred. See README.md for the observed tooling and the
mandatory architecture command. Keep all Windows sources and platform glue here.

## Current rule milestone

The native editor now reaches all eight core recurrence forms, time/reminder
choices, note/provenance and priest attribution. Scoped edits/removals call
EditPlanner and apply one store transaction. Home exposes the rule action menu;
Custom library supports creation, editing, pause/resume, archive/re-take and
set-aside. Native control tests verify recurrence/metadata round trips, validation
and past occurrence preservation. Home/calendar and direct prayer/reading routes now have a separate verified
milestone below. Notification delivery, onboarding, tray and complete
visual/accessibility parity remain outstanding; the feature gates below are still the full inventory.

## Settings and record milestone

Names/clear, clock style, Progress figure, church/unnamed fallback, independent
calendar reckoning, fasting/feast observance and the old-style-date preference
now persist through core settings. Reckoning changes save the scoring cutoff
without rewriting occurrence history. Calendar settings now select the core service and Home annotations. Rich text,
calendar glossary links and full visual/input acceptance remain open.

Native backup dialogs export the portable JSON record and merge restores.
SQLite imports now run in one locked transaction, also preserving the existing
scoped-edit transaction guarantee. A failed import rolls back its earlier writes.
Local daily backups retain ten dated copies and leave other files alone. A Win32
timer plus foreground/resume events drive day rollover through core, retaining
past selection and deferring date changes while an editor is open. Synthetic
review files live in a separate temporary directory and are removed on exit.
Notification/quiet-hours, sound, startup/taskbar/tray and onboarding controls
remain outstanding alongside their service implementations.

## Home/calendar/reading milestone

Home now follows the Mac's grouped sidebar, calendar browsing/selection,
parchment cards and focused original artwork. Native owner-drawn controls use
DPI-scaled geometry, the shared palette and warm radial backdrop, with licensed
XCharter regular/bold/italic cuts. Compare against a fresh synthetic macOS render,
not the older screenshots directory. The Mac render's August fixture has only a
Julian cached day while its default settings use the new calendar; its missing
calendar title/annotations are fixture coverage, not the product specification.
The Windows public fixture separately exercises asynchronous arrival and caching.

Detached calendar work posts back to the native message loop. Cache-first reading
uses the existing core ordering/content. Gospel and other cards open their own
bands; morning/evening select complete sequences. Native tests verify independent
open, expansion and completion, programmatic-scroll rejection, deliberate-end
completion and stood-down preservation. Actual HTTPS retrieval and SQLite cache
population also pass independently of the synthetic fetcher.

Remaining parity work includes full rich text and glossary detours, inline reading
layout, keyboard/mouse and UI Automation accessibility, responsive layouts beyond
Home, measured card expansion and automatic reveal, subject-focused artwork
motion/reduced motion, rope presentation/sounds, and appointed-kathisma selection
and completion. Current Psalter exposes all psalms and the day's appointment as
text; that does not close the appointed-kathisma interaction gate. Platform
services and packaging gates below remain mandatory.

## Source review

`core/Package.swift` uses Swift tools 6.0, a ChotkiCore library, copied resources,
and a CSQLite system-library target. Its Apple minimum-version declarations do
not themselves exclude Windows. Source imports are Foundation, conditional
FoundationNetworking, and CSQLite; the UI frameworks are already outside core.

| Reviewed source | Reuse or migration implication |
|---|---|
| Model/AppSettings.swift, Rule.swift, CalendarDate.swift | Reuse settings, backward-compatible decoding, affiliation and civil-date behavior |
| Practice/Practice.swift, DayRollover.swift | Reuse due-day calculation, pause/dispensation behavior, load repairs and progress cutoff at yesterday |
| Recurrence/RecurrenceEngine.swift, EditPlanner.swift | Reuse recurrence and scoped edits; do not create a Windows rule model |
| Store/Store.swift, SQLiteStore.swift, InMemoryStore.swift | Reuse database semantics, migrations, settings and JSON merge backup; supply Windows SQLite development files |
| CSQLite/module.modulemap and shim.h | Current shim includes sqlite3.h and links sqlite3; Windows needs matching include/library search paths and x86_64 binaries |
| Liturgical/HTTPFetching.swift, LiturgicalService.swift | Networking already splits FoundationNetworking conditionally; wire cache loading, async refresh AND UI redraw |
| Scheduling/Scheduler.swift, ReminderTicker.swift | Reuse notification decisions, stale suppression, snooze and withdrawal; Windows supplies delivery and timer |
| Platform/Notifier.swift, LaunchAtLogin.swift | Existing seams for Windows notification actions and startup registration |
| Prayers/PrayerScreen.swift, PrayerSequence.swift, Readings/, Glossary/, Presentation/ | Reuse prayer counts, destinations, texts, glossary, geometry, reading order and formatting |
| Content/BundledFile.swift and copied Resources | Verify SwiftPM resource lookup in both debug and packaged Windows layouts |
| Sound/BellTone.swift and WAV.swift | Reuse synthesized tones; replace AVAudioPlayer playback |
| macos/AppModel.swift | Port orchestration and state bindings; SwiftUI ObservableObject/Published and platform callbacks need replacement |
| macos/ChotkiApp.swift, MainWindow.swift, RootView.swift | Rewrite AppKit lifecycle, main window and menu-bar companion as Windows window/tray surfaces |
| macos/SettingsStorage.swift, ReminderDriver.swift | Replace paths, old Mac preference migration and timer lifecycle; preserve core-backed settings and daily backups |
| macos/ReadingEnd.swift, RuleCardInteraction.swift | Rebuild actual mouse/keyboard and deliberate-scroll completion handling; pictures alone cannot verify these |
| macos/MacNotifier.swift, MacLaunchAtLogin.swift, SoundPlayer.swift | Replace Apple notifications, ServiceManagement and AVFoundation adapters |
| .github/workflows/ci.yml | Current core gates cover Linux/macOS, not Windows; README's Windows claim is not evidence of a Windows test pass |

The macOS UI cannot be directly compiled for Windows: it imports SwiftUI,
AppKit, AVFoundation, UserNotifications and ServiceManagement. Reuse Swift core
and rewrite the interface. Preserve current rule, settings and occurrence
records in imports, exports and database migrations.

## Ordered work and exit gates

1. **Close environment gaps.** Supply x86_64 Swift runtime DLLs and SQLite
   headers/import library/DLL. These dependencies are supplied; the compiler
   variables and native backend allow compilation. Match runtime DLLs to the
   6.4 SDK. Use additive synchronization into C:\workspace-build.
   Prove the guarded bootstrap compiles, has PE 0x8664, and runs. Build
   ChotkiCore with the same target, then compile tests explicitly with
   `swift build --triple x86_64-unknown-windows-msvc --build-system native --build-tests`
   plus a guest-local scratch path. Run that compiled suite through the test
   runner with `--skip-build` and the same triple/backend/scratch path. Exercise
   SQLite, resource loading, dates/time zones, networking fixtures and migration
   tests. Do not infer Windows compatibility from Linux CI.
2. **Prove the GUI choice with one real screen.** Start with Swift and native
   Win32 APIs or SwiftWin32, keeping direct reuse of ChotkiCore. Draw the actual
   Home screen with synthetic rules, scrolling, image, text and completion
   controls. Verify keyboard focus, mouse events, right-click actions, resizing,
   DPI scaling, accessibility and async refresh. Compare SwiftWin32 with
   Swift/WinRT + WinUI 3 only if this spike exposes limits. Pin the selected
   dependency/version and its packaging requirements after it passes. The current
   spike uses direct Win32 through a C bridge. Accessibility, resizing and
   physical input remain exit gates.
3. **Build application orchestration and storage.** Use core types and services,
   translating AppModel's observation/bindings and navigation into the selected
   GUI. Create user data at `%LOCALAPPDATA%\Chotki` and backups beside it, with a
   separate synthetic review mode. Wire cold launch versus reactivation,
   single-process ownership of the database, day rollover and sleep/resume.
   Fetch calendar data and redraw after arrival. Preserve one-time onboarding
   and welcome, with cold-launch rope/cross animation and reduced-motion bypass.
4. **Port all feature surfaces.** Implement Home/calendar, Library/custom rules,
   editor/scoped changes, prayers/rope, all readings/Psalter, glossary, Progress
   and Settings. Preserve desktop sidebar and tray companion, detached Progress
   report, taskbar visibility preference and every route/action. Inventory below
   is the starting parity checklist; compare actual current source controls
   before declaring any screen complete.
5. **Implement Windows services.** Fill Notifier and LaunchAtLogin, including
   action callbacks, snooze, cancellation and denied notification state. Drive
   ReminderTicker with a Windows timer and resume handling. Supply WAV playback,
   file dialogs, tray icon, application icon and keyboard shortcuts. Adapt Mac
   Dock wording to Windows taskbar/tray behavior without losing capability.
6. **Package and verify x86_64 delivery.** Package the executable, architecture-
   matched Swift/SQLite/GUI runtime DLLs, resources, fonts, artwork and content
   licenses. Choose ZIP or installer after the GUI spike determines runtime and
   notification identity requirements. Verify PE architecture for native app
   components, launch from a clean installation without development PATH, and
   test install/upgrade/uninstall while preserving user data. Add an explicit
   x86_64 Windows CI build/test gate; keep Linux/macOS tests passing.

## Feature parity gates

- Home: week/month navigation, selected-day state, feasts/fasts, arrival of
  calendar data, completion toggles, direct destinations, separate expansion
  control, Add placard opening Library, and all right-click rule actions.
- Rules: kept/kept late/reset/stand down for a day, pause/resume, archive/re-take,
  custom library and new custom rule, all recurrence/time/reminder controls,
  scoped edit/remove, attribution that survives spiritual-father name changes.
- Prayers: morning/evening selection, rope count and reset, keyboard repeat
  guard, per-knot tick/chime, full texts, linked glossary, return without losing
  count or reading place, and correct automatic/manual completion.
- Reading: separate scripture bands, saint life with source/license, departed
  prayer, Akathist, Psalter and appointed kathisma. A rule opens its own section.
  Completion requires deliberate user scrolling to the end; disclosure,
  programmatic navigation and absent content do not mark a rule. Preserve
  stood-down and dispensed days.
- Progress: prose before optional number, ending yesterday, per-rule reporting,
  detached report, still artwork, quotation and caption, encouraging tone.
- Settings: name/first-run state, spiritual father and attribution, church/OCA
  unnamed fallback, reckoning/tradition/observances, old-style dates, clock,
  reminder quiet hours and lead times, sounds, startup, taskbar/tray, backup
  export/merge restore and automatic backup retention.
- Content/design: current shared 365-image rotation and focal metadata, subject-
  focused drift on Home, stationary Progress art, original bundled texts and
  license/source footers, glossary links on every text surface, matching
  typefaces/palette, reduced motion, mouse wheel and scrollbars.
- Both desktop surfaces: navigation, state changes, notifications and attention
  pulse must work in the main window and tray companion. A correct screenshot
  is only layout evidence; drive physical mouse/keyboard interaction separately.

## Verification limits and risks

The initial window and seven navigation surfaces compile with ChotkiCore. They
cover a subset of actions; all 477 core tests now pass on Windows x86_64, while
the broader parity inventory remains outstanding. Synthetic control checks exercise native
button messages, not physical keyboard/mouse input. An ARM64 VM running an
x86_64 app exercises Windows emulation; retain a later real x86_64 Windows 11
acceptance check. The GUI spike must establish main-loop/Swift concurrency
integration before building every screen. Never open or copy live data.

## Primary toolkit references

- [Swift Windows prerequisites](https://www.swift.org/install/windows/manual/)
- [SwiftWin32](https://github.com/compnerd/swift-win32): Win32 wrappers, SwiftPM
  support, and documented extra manifest/resource deployment steps.
- [Swift/WinRT](https://github.com/thebrowsercompany/swift-winrt): WinRT
  projection to evaluate for a WinUI 3 approach.

These are candidates to test, not a claim that Chotki's complete UI already
works with either toolkit. Do not substitute their default build examples for
this project's mandatory x86_64 command.
